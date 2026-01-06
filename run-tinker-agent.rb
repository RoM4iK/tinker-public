#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent Runner
# Usage: npx tinker-agent [worker|planner|reviewer|orchestrator|researcher]
#        npx tinker-agent attach [agent-type]
#
# Requirements:
#   - Docker
#   - Ruby
#   - Dockerfile.sandbox in project root
#   - tinker.env.json in project root (gitignored)

require "json"

# Load agent configs
require_relative "agents"

IMAGE_NAME = "tinker-sandbox"

AGENT_TYPES = AGENT_CONFIGS.keys.freeze

def load_config
  config_file = File.join(Dir.pwd, "tinker.env.json")

  unless File.exist?(config_file)
    puts "❌ Error: tinker.env.json not found in current directory"
    puts ""
    puts "Create it:"
    puts "  curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/tinker.env.example.json -o tinker.env.json"
    puts "  # Edit with your project config"
    puts "  echo 'tinker.env.json' >> .gitignore"
    exit 1
  end

  JSON.parse(File.read(config_file))
end

def check_dockerfile!
  unless File.exist?("Dockerfile.sandbox")
    puts "❌ Error: Dockerfile.sandbox not found"
    puts ""
    puts "Please create Dockerfile.sandbox by copying your existing Dockerfile"
    puts "and adding the required agent dependencies."
    puts ""
    puts "See https://github.com/RoM4iK/tinker-public/blob/main/README.md for instructions."
    exit 1
  end
end

def build_docker_image
  check_dockerfile!

  user_id = `id -u`.strip
  group_id = `id -g`.strip

  puts "🏗️  Building Docker image..."

  success = system(
    "docker", "build",
    "--build-arg", "USER_ID=#{user_id}",
    "--build-arg", "GROUP_ID=#{group_id}",
    "-t", IMAGE_NAME,
    "-f", "Dockerfile.sandbox",
    "."
  )

  unless success
    puts "❌ Failed to build Docker image"
    exit 1
  end

  puts "✅ Docker image built"
end

def run_agent(agent_type, config)
  unless AGENT_TYPES.include?(agent_type)
    puts "❌ Unknown agent type: #{agent_type}"
    puts "   Available: #{AGENT_TYPES.join(', ')}"
    exit 1
  end

  agent_def = AGENT_CONFIGS[agent_type]
  agent_config = config.dig("agents", agent_type) || {}
  container_name = agent_config["container_name"] || agent_def[:name]

  puts "🚀 Starting #{agent_type} agent..."

  # Stop existing container if running
  system("docker", "rm", "-f", container_name, err: File::NULL, out: File::NULL)

  # Write banner to a persistent temp file (not auto-deleted)
  banner_path = "/tmp/tinker-agent-banner-#{agent_type}.txt"
  File.write(banner_path, agent_def[:banner])

  docker_cmd = [
    "docker", "run", "-d",
    "--name", container_name,
    "--network=host",
    # Mount Claude config
    "-v", "#{ENV['HOME']}/.claude.json:/tmp/cfg/claude.json:ro",
    "-v", "#{ENV['HOME']}/.claude:/tmp/cfg/claude_dir:ro",
    "-v", "#{banner_path}:/tmp/agent-banner.txt:ro",
    "-e", "TINKER_VERSION=main",
    "-e", "SKILLS=#{agent_def[:skills]&.join(',')}",
    "-e", "AGENT_TYPE=#{agent_type}",
    "-e", "PROJECT_ID=#{config['project_id']}",
    "-e", "RAILS_WS_URL=#{config['rails_ws_url']}",
    "-e", "RAILS_API_URL=#{config['rails_api_url']}",
    "-e", "RAILS_API_KEY=#{agent_config['mcp_api_key']}"
  ]

  # Add GitHub auth
  github = config["github"] || {}
  if github["method"] == "app"
    key_path = File.expand_path(github["app_private_key_path"].to_s)

    unless File.exist?(key_path) && !File.directory?(key_path)
      puts "❌ Error: GitHub App private key not found at: #{key_path}"
      puts "   Please check 'app_private_key_path' in tinker.env.json"
      exit 1
    end

    docker_cmd += [
      "-e", "GITHUB_APP_CLIENT_ID=#{github['app_client_id']}",
      "-e", "GITHUB_APP_INSTALLATION_ID=#{github['app_installation_id']}",
      # Path is set dynamically in entrypoint.sh based on user home
      "-v", "#{key_path}:/tmp/github-app-privkey.pem:ro"
    ]
    puts "🔐 Using GitHub App authentication"
  elsif github["token"]
    docker_cmd += ["-e", "GH_TOKEN=#{github['token']}"]
    puts "🔑 Using GitHub token authentication"
  else
    puts "❌ Error: No GitHub authentication configured"
    puts "   Please configure 'github' in tinker.env.json"
    exit 1
  end

  # Add git config
  if (git_config = config["git"])
    docker_cmd += ["-e", "GIT_USER_NAME=#{git_config['user_name']}"] if git_config["user_name"]
    docker_cmd += ["-e", "GIT_USER_EMAIL=#{git_config['user_email']}"] if git_config["user_email"]
  end

  # Check for local setup-agent.rb (for development)
  local_setup_script = File.join(File.dirname(__FILE__), "setup-agent.rb")
  
  # Check for local agent-bridge binaries (for development)
  local_bridge = File.join(Dir.pwd, "bin", "agent-bridge")
  local_tmux = File.join(File.dirname(__FILE__), "bin", "agent-bridge-tmux")
  
  mounts = []
  if File.exist?(local_setup_script)
    puts "🔧 Using local setup-agent.rb for development"
    mounts += ["-v", "#{File.expand_path(local_setup_script)}:/tmp/setup-agent.rb:ro"]
  end

  if File.exist?(local_bridge)
    puts "🔧 Using local agent-bridge binary"
    mounts += ["-v", "#{local_bridge}:/tmp/agent-bridge:ro"]
  end
  
  if File.exist?(local_tmux)
    mounts += ["-v", "#{File.expand_path(local_tmux)}:/tmp/agent-bridge-tmux:ro"]
  end

  docker_cmd += mounts

  if File.exist?(local_setup_script)
    docker_cmd += [IMAGE_NAME, "ruby", "/tmp/setup-agent.rb"]
  else
    docker_cmd += [IMAGE_NAME]
  end

  success = system(*docker_cmd)

  if success
    puts "✅ Agent started in background"
    puts ""
    puts "   Attach: npx tinker-agent attach #{agent_type}"
    puts "   Logs:   docker logs -f #{container_name}"
    puts "   Stop:   docker stop #{container_name}"
  else
    puts "❌ Failed to start agent"
    exit 1
  end
end

def attach_to_agent(agent_type, config)
  unless AGENT_TYPES.include?(agent_type)
    puts "❌ Unknown agent type: #{agent_type}"
    exit 1
  end

  agent_config = config.dig("agents", agent_type) || {}
  container_name = agent_config["container_name"] || "tinker-#{agent_type}"

  running = `docker ps --filter name=^#{container_name}$ --format '{{.Names}}'`.strip

  if running.empty?
    puts "❌ #{agent_type} agent is not running"
    puts "   Start with: npx tinker-agent #{agent_type}"
    exit 1
  end

  puts "📎 Attaching to #{agent_type} agent..."
  
  # Determine the user to attach as
  # First try to detect the user the container is running as
  user = `docker exec #{container_name} whoami 2>/dev/null`.strip
  
  if user.empty?
    # Fallback: try to match host UID
    uid = Process.uid
    user = `docker exec #{container_name} getent passwd #{uid} | cut -d: -f1`.strip
  end
  
  if user.empty?
    # Fallback: default to rails (standard for this image)
    user = "rails"
    puts "⚠️  Could not detect agent user, defaulting to '#{user}'"
  end

  puts "   User: #{user}"

  # Attach to agent session which has the status bar
  # Must run as agent user since tmux server runs under that user
  exec("docker", "exec", "-it", "-u", user, container_name, "tmux", "attach", "-t", "agent")
end

def show_usage
  puts "Tinker Agent Runner"
  puts ""
  puts "Usage: npx tinker-agent [worker|planner|reviewer|orchestrator|researcher]"
  puts "       npx tinker-agent attach [agent-type]"
  puts ""
  puts "Setup:"
  puts "  1. Create Dockerfile.sandbox (see https://github.com/RoM4iK/tinker-public/blob/main/README.md)"
  puts "  2. curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/tinker.env.example.json -o tinker.env.json"
  puts "  3. Edit tinker.env.json with your config"
  puts "  4. echo 'tinker.env.json' >> .gitignore"
  puts "  5. npx tinker-agent worker"
  exit 1
end

# Main
show_usage if ARGV.empty?

command = ARGV[0].downcase

if command == "attach"
  agent_type = ARGV[1]&.downcase
  abort "Usage: npx tinker-agent attach [agent-type]" unless agent_type
  config = load_config
  attach_to_agent(agent_type, config)
else
  config = load_config
  build_docker_image
  run_agent(command, config)
end
