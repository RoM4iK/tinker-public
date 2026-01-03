#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent Runner
# Usage: ./run-tinker-agent.rb [worker|planner|reviewer|orchestrator]
#        ./run-tinker-agent.rb attach [agent-type]

require "fileutils"

TINKER_PUBLIC_URL = "https://raw.githubusercontent.com/RoM4iK/tinker-public/main"
DOCKERFILE_NAME = "Dockerfile.tinker"

# Agent configurations
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
    puts "  ANTHROPIC_API_KEY=your-api-key"
    puts "  GH_TOKEN=your-github-token  # or use GitHub App"
    puts ""
    puts "See: #{TINKER_PUBLIC_URL}/README.md"
    exit 1
  end

  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    ENV[key] = value if key && value
  end
end

def ensure_dockerfile
  dockerfile = File.join(Dir.pwd, DOCKERFILE_NAME)
  return if File.exist?(dockerfile)

  puts "📥 Downloading #{DOCKERFILE_NAME}..."
  system("curl", "-fsSL", "#{TINKER_PUBLIC_URL}/#{DOCKERFILE_NAME}", "-o", dockerfile)
  unless File.exist?(dockerfile)
    puts "❌ Failed to download Dockerfile"
    exit 1
  end
  puts "✅ Downloaded #{DOCKERFILE_NAME}"
end

def build_docker_image
  user_id = `id -u`.strip
  group_id = `id -g`.strip

  puts "🏗️  Building Docker image..."
  
  success = system(
    "docker", "build",
    "--build-arg", "USER_ID=#{user_id}",
    "--build-arg", "GROUP_ID=#{group_id}",
    "-t", "tinker-agent-sandbox",
    "-f", DOCKERFILE_NAME,
    "."
  )
  
  unless success
    puts "❌ Failed to build Docker image"
    exit 1
  end
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

  container_name = config[:name]
  system("docker", "rm", "-f", container_name, err: File::NULL) rescue nil

  docker_cmd = [
    "docker", "run", "-d", "--rm",
    "--name", container_name,
    "--network=host",
    "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
    "-e", "DISABLE_TELEMETRY=true",
    "-e", "IS_SANDBOX=1",
    "-e", "GIT_REMOTE_URL=#{git_remote}",
    "-e", "AGENT_TYPE=#{agent_type}",
    "-e", "PROJECT_ID=#{project_id}",
    "-e", "RAILS_WS_URL=#{rails_ws_url}",
    "-v", "#{ENV['HOME']}/.claude.json:/tmp/cfg/claude.json:ro",
    "-v", "#{ENV['HOME']}/.claude:/tmp/cfg/claude_dir:ro"
  ]

  # GitHub authentication
  if ENV["GITHUB_APP_CLIENT_ID"] && ENV["GITHUB_APP_INSTALLATION_ID"] && ENV["GITHUB_APP_PRIVATE_KEY_PATH"]
    docker_cmd += [
      "-e", "GITHUB_APP_CLIENT_ID=#{ENV['GITHUB_APP_CLIENT_ID']}",
      "-e", "GITHUB_APP_INSTALLATION_ID=#{ENV['GITHUB_APP_INSTALLATION_ID']}",
      "-e", "GITHUB_APP_PRIVATE_KEY_PATH=/home/claude/.github-app-privkey.pem",
      "-v", "#{ENV['GITHUB_APP_PRIVATE_KEY_PATH']}:/tmp/github-app-privkey.pem:ro"
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
    sudo chown -R claude:claude /workspace 2>/dev/null || true
    
    # Create CLAUDE.md
    cat > /workspace/CLAUDE.md << 'BANNER'
    #{config[:prompt]}
    
    Use the MCP tools (get_ticket, transition_ticket, etc.) to interact with Tinker.
    BANNER
    
    echo "📝 Created CLAUDE.md"
    echo ""
    echo "💡 Attach with: docker exec -it #{container_name} tmux attach -t agent"
    echo ""
    
    cd /workspace
    exec agent-bridge-tmux
  SCRIPT

  docker_cmd += ["tinker-agent-sandbox", "/bin/sh", "-c", startup_cmd]
  exec(*docker_cmd)
end

def attach_to_agent(agent_type)
  config = AGENT_CONFIGS[agent_type]
  unless config
    puts "❌ Unknown agent type: #{agent_type}"
    exit 1
  end

  container_name = config[:name]
  running = `docker ps --filter name=#{container_name} --format '{{.Names}}'`.strip

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
  puts "Usage: #{$PROGRAM_NAME} [worker|planner|reviewer|orchestrator]"
  puts "       #{$PROGRAM_NAME} attach [agent-type]"
  exit 1
end

load_env_file

command = ARGV[0].downcase

if command == "attach"
  agent_type = ARGV[1]&.downcase
  abort "Usage: #{$PROGRAM_NAME} attach [agent-type]" unless agent_type
  attach_to_agent(agent_type)
else
  ensure_dockerfile
  build_docker_image
  run_agent(command)
end
