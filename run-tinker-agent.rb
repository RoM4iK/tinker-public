#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent Runner - Single file to add Tinker agents to any project
# Usage: ./run-tinker-agent.rb [worker|planner|reviewer|orchestrator]
#        ./run-tinker-agent.rb attach [agent-type]
#
# Requirements: Docker, Ruby, Git, .agent.env file with credentials

require "fileutils"
require "net/http"
require "uri"

TINKER_PUBLIC_URL = "https://raw.githubusercontent.com/RoM4iK/tinker-public/main"
IMAGE_NAME = "tinker-agent-sandbox"

AGENT_CONFIGS = {
  "worker" => {
    name: "tinker-worker",
    prompt: "You are a Worker agent. Execute assigned tickets, write code, and submit PRs for review."
  },
  "planner" => {
    name: "tinker-planner", 
    prompt: "You are a Planner agent. Discuss features with humans and create detailed tickets."
  },
  "reviewer" => {
    name: "tinker-reviewer",
    prompt: "You are a Reviewer agent. Review PRs, check code quality, and pass/fail audits."
  },
  "orchestrator" => {
    name: "tinker-orchestrator",
    prompt: "You are an Orchestrator agent. Assign work to idle agents and manage ticket lifecycle."
  }
}.freeze

def load_env_file
  env_file = File.join(Dir.pwd, ".agent.env")
  unless File.exist?(env_file)
    puts "❌ Error: .agent.env file not found!"
    puts ""
    puts "Create .agent.env with:"
    puts "  GH_TOKEN=your-github-token"
    puts ""
    puts "Optional:"
    puts "  RAILS_WS_URL=wss://your-tinker-instance/cable"
    puts "  PROJECT_ID=1"
    exit 1
  end

  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    ENV[key] = value if key && value
  end
end

def build_docker_image
  puts "🏗️  Building Docker image from tinker-public..."
  
  user_id = `id -u`.strip
  group_id = `id -g`.strip

  # Create Dockerfile inline - no file needed in target project
  dockerfile_content = <<~DOCKERFILE
    FROM ubuntu:24.04

    ARG USER_ID=1000
    ARG GROUP_ID=1000
    ARG TINKER_PUBLIC_URL=#{TINKER_PUBLIC_URL}

    ENV DEBIAN_FRONTEND=noninteractive

    # Install dependencies
    RUN apt-get update && apt-get install -y \\
        curl git gh sudo tmux nodejs npm jq ca-certificates \\
        && rm -rf /var/lib/apt/lists/*

    # Create claude user
    RUN groupadd -g ${GROUP_ID} claude 2>/dev/null || groupadd claude && \\
        useradd -m -u ${USER_ID} -g claude -s /bin/bash claude && \\
        echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

    # Install Claude CLI
    RUN npm install -g @anthropic-ai/claude-code

    # Download agent-bridge and wrapper from tinker-public
    RUN curl -fsSL ${TINKER_PUBLIC_URL}/bin/agent-bridge -o /usr/local/bin/agent-bridge && \\
        chmod +x /usr/local/bin/agent-bridge && \\
        curl -fsSL ${TINKER_PUBLIC_URL}/bin/agent-bridge-tmux -o /usr/local/bin/agent-bridge-tmux && \\
        chmod +x /usr/local/bin/agent-bridge-tmux

    # Download skills
    RUN mkdir -p /opt/tinker/skills && \\
        for skill in git-workflow memory memory-consolidation orchestrator-workflow \\
                     proposal-execution researcher-workflow retrospective \\
                     review-workflow ticket-management worker-workflow; do \\
            mkdir -p /opt/tinker/skills/\\$skill && \\
            curl -fsSL ${TINKER_PUBLIC_URL}/skills/\\$skill/SKILL.md \\
                -o /opt/tinker/skills/\\$skill/SKILL.md 2>/dev/null || true; \\
        done

    # Workspace will be mounted at runtime
    RUN mkdir -p /workspace && chown claude:claude /workspace
    WORKDIR /workspace
    USER claude
    RUN mkdir -p /home/claude/.claude
  DOCKERFILE

  # Build using stdin Dockerfile (no file needed in project)
  IO.popen([
    "docker", "build",
    "--build-arg", "USER_ID=#{user_id}",
    "--build-arg", "GROUP_ID=#{group_id}",
    "-t", IMAGE_NAME,
    "-f", "-",  # Read Dockerfile from stdin
    "."
  ], "w") do |io|
    io.write(dockerfile_content)
  end

  unless $?.success?
    puts "❌ Failed to build Docker image"
    exit 1
  end
  
  puts "✅ Docker image built"
end

def run_agent(agent_type)
  config = AGENT_CONFIGS[agent_type]
  unless config
    puts "❌ Unknown agent type: #{agent_type}"
    puts "   Available: #{AGENT_CONFIGS.keys.join(', ')}"
    exit 1
  end

  puts "🚀 Starting #{agent_type} agent..."

  project_id = ENV["PROJECT_ID"] || "1"
  rails_ws_url = ENV["RAILS_WS_URL"] || ""
  git_remote = `git remote get-url origin 2>/dev/null`.strip
  project_dir = Dir.pwd

  container_name = config[:name]
  system("docker", "rm", "-f", container_name, err: File::NULL, out: File::NULL)

  docker_cmd = [
    "docker", "run", "-d", "--rm",
    "--name", container_name,
    "--network=host",
    "-e", "DISABLE_TELEMETRY=true",
    "-e", "IS_SANDBOX=1",
    "-e", "GIT_REMOTE_URL=#{git_remote}",
    "-e", "AGENT_TYPE=#{agent_type}",
    "-e", "PROJECT_ID=#{project_id}",
    "-e", "RAILS_WS_URL=#{rails_ws_url}",
    # Mount project directory
    "-v", "#{project_dir}:/workspace",
    # Mount Claude config
    "-v", "#{ENV['HOME']}/.claude.json:/home/claude/.claude.json:ro",
    "-v", "#{ENV['HOME']}/.claude:/home/claude/.claude:ro"
  ]

  # GitHub authentication
  if ENV["GITHUB_APP_CLIENT_ID"] && ENV["GITHUB_APP_INSTALLATION_ID"] && ENV["GITHUB_APP_PRIVATE_KEY_PATH"]
    docker_cmd += [
      "-e", "GITHUB_APP_CLIENT_ID=#{ENV['GITHUB_APP_CLIENT_ID']}",
      "-e", "GITHUB_APP_INSTALLATION_ID=#{ENV['GITHUB_APP_INSTALLATION_ID']}",
      "-e", "GITHUB_APP_PRIVATE_KEY_PATH=/home/claude/.github-app-privkey.pem",
      "-v", "#{ENV['GITHUB_APP_PRIVATE_KEY_PATH']}:/home/claude/.github-app-privkey.pem:ro"
    ]
    puts "🔐 Using GitHub App authentication"
  elsif ENV["GH_TOKEN"]
    docker_cmd += ["-e", "GH_TOKEN=#{ENV['GH_TOKEN']}"]
    puts "🔑 Using GitHub PAT authentication"
  else
    puts "⚠️  Warning: No GitHub authentication configured"
  end

  # Startup script
  startup_cmd = <<~SCRIPT
    set -e
    
    # Setup skills symlink
    mkdir -p /workspace/.claude
    ln -sf /opt/tinker/skills /workspace/.claude/skills 2>/dev/null || true
    
    # Setup git credentials
    if [ -n "$GH_TOKEN" ]; then
      git config --global credential.helper store
      git config --global url."https://${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
      echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || true
    fi
    git config --global --add safe.directory /workspace
    
    # Create CLAUDE.md
    cat > /workspace/CLAUDE.md << 'PROMPT'
#{config[:prompt]}

Use the MCP tools (get_ticket, transition_ticket, etc.) to interact with Tinker.
PROMPT
    
    echo "📝 Agent: #{agent_type}"
    echo "📂 Project: /workspace"
    echo ""
    echo "💡 Attach with: docker exec -it #{container_name} tmux attach -t agent"
    echo ""
    
    cd /workspace
    exec agent-bridge-tmux
  SCRIPT

  docker_cmd += [IMAGE_NAME, "/bin/bash", "-c", startup_cmd]
  
  system(*docker_cmd)
  
  if $?.success?
    puts "✅ Agent started in background"
    puts ""
    puts "   Attach: ./run-tinker-agent.rb attach #{agent_type}"
    puts "   Logs:   docker logs -f #{container_name}"
    puts "   Stop:   docker stop #{container_name}"
  else
    puts "❌ Failed to start agent"
    exit 1
  end
end

def attach_to_agent(agent_type)
  config = AGENT_CONFIGS[agent_type]
  unless config
    puts "❌ Unknown agent type: #{agent_type}"
    exit 1
  end

  container_name = config[:name]
  running = `docker ps --filter name=^#{container_name}$ --format '{{.Names}}'`.strip

  if running.empty?
    puts "❌ #{agent_type} agent is not running"
    puts "   Start with: ./run-tinker-agent.rb #{agent_type}"
    exit 1
  end

  puts "📎 Attaching to #{agent_type} agent..."
  exec("docker", "exec", "-it", container_name, "tmux", "attach", "-t", "agent")
end

# Main
if ARGV.empty?
  puts "Tinker Agent Runner"
  puts ""
  puts "Usage: #{$PROGRAM_NAME} [worker|planner|reviewer|orchestrator]"
  puts "       #{$PROGRAM_NAME} attach [agent-type]"
  puts ""
  puts "Setup: Create .agent.env with GH_TOKEN=your-token"
  exit 1
end

load_env_file

command = ARGV[0].downcase

if command == "attach"
  agent_type = ARGV[1]&.downcase
  abort "Usage: #{$PROGRAM_NAME} attach [agent-type]" unless agent_type
  attach_to_agent(agent_type)
else
  build_docker_image
  run_agent(command)
end
