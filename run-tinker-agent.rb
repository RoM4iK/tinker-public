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
#   - tinker.env.rb in project root (gitignored)

require "json"
require "fileutils"

# Load agent configs
require_relative "agents"

def image_name(config)
  if config["project_id"]
    "tinker-sandbox-#{config['project_id']}"
  else
    "tinker-sandbox"
  end
end

AGENT_TYPES = AGENT_CONFIGS.keys.freeze

def load_config
  # Support Ruby config for heredocs and comments (tinker.env.rb)
  rb_config_file = File.join(Dir.pwd, "tinker.env.rb")
  
  unless File.exist?(rb_config_file)
    puts "❌ Error: tinker.env.rb not found in current directory"
    puts ""
    puts "Create tinker.env.rb:"
    puts "  {"
    puts "    project_id: 1,"
    puts "    rails_ws_url: '...',"
    puts "    # ..."
    puts "    # Paste your stripped .env content here:"
    puts "    dot_env: <<~ENV"
    puts "      STRIPE_KEY=sk_test_..."
    puts "      OPENAI_KEY=sk-..."
    puts "    ENV"
    puts "  }"
    puts "  echo 'tinker.env.rb' >> .gitignore"
    exit 1
  end

  puts "⚙️  Loading configuration from tinker.env.rb"
  config = eval(File.read(rb_config_file), binding, rb_config_file)
  
  # Convert symbols to strings for easier handling before JSON normalization
  config = config.transform_keys(&:to_s)
  
  # Parse dot_env heredoc if present
  if (dotenv = config["dot_env"])
    config["env"] ||= {}
    # Ensure env is string-keyed
    config["env"] = config["env"].transform_keys(&:to_s)
    
    dotenv.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      k, v = line.split('=', 2)
      next unless k && v
      # Remove surrounding quotes and trailing comments (simple)
      v = v.strip.gsub(/^['"]|['"]$/, '')
      config["env"][k.strip] = v
    end
    
    config.delete("dot_env")
    puts "🌿 Parsed dot_env into #{config['env'].size} environment variables"
  end

  # Normalize symbols to strings for consistency via JSON round-trip
  JSON.parse(JSON.generate(config))
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

def build_docker_image(config)
  check_dockerfile!

  user_id = `id -u`.strip
  group_id = `id -g`.strip

  puts "🏗️  Building Docker image..."

  # Handle .dockerignore.sandbox
  dockerignore_sandbox = ".dockerignore.sandbox"
  dockerignore_original = ".dockerignore"
  dockerignore_backup = ".dockerignore.bak"

  has_sandbox_ignore = File.exist?(dockerignore_sandbox)
  has_original_ignore = File.exist?(dockerignore_original)

  if has_sandbox_ignore
    puts "📦 Swapping .dockerignore with .dockerignore.sandbox..."
    if has_original_ignore
      FileUtils.mv(dockerignore_original, dockerignore_backup)
    end
    FileUtils.cp(dockerignore_sandbox, dockerignore_original)
  end

  success = false
  begin
    success = system(
      "docker", "build",
      "--build-arg", "USER_ID=#{user_id}",
      "--build-arg", "GROUP_ID=#{group_id}",
      "-t", image_name(config),
      "-f", "Dockerfile.sandbox",
      "."
    )
  ensure
    if has_sandbox_ignore
      # Restore original state
      FileUtils.rm(dockerignore_original) if File.exist?(dockerignore_original)
      if has_original_ignore
        FileUtils.mv(dockerignore_backup, dockerignore_original)
      end
      puts "🧹 Restored original .dockerignore"
    end
  end

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
  ]

  # Inject custom environment variables from config
  if (custom_env = config["env"])
    custom_env.each do |k, v|
      docker_cmd += ["-e", "#{k}=#{v}"]
    end
    puts "🌿 Injected #{custom_env.size} custom env vars from config"
  end

  docker_cmd += [
    # Mount Claude config
    "-v", "#{ENV['HOME']}/.claude.json:/tmp/cfg/claude.json:ro",
    "-v", "#{ENV['HOME']}/.claude:/tmp/cfg/claude_dir:ro",
    "-v", "#{banner_path}:/etc/tinker/system-prompt.txt:ro",
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
      puts "   Please check 'app_private_key_path' in tinker.env.rb"
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
    puts "   Please configure 'github' in tinker.env.rb"
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
  # Priority: 
  # 1. Linux binary matching host arch (for proper container execution)
  # 2. Legacy bin/agent-bridge if it's a binary (not script)

  arch = `uname -m`.strip
  linux_arch = (arch == "x86_64") ? "amd64" : "arm64"
  linux_bridge = File.join(Dir.pwd, "tinker-public", "bin", "agent-bridge-linux-#{linux_arch}")
  
  local_bridge_default = File.join(Dir.pwd, "bin", "agent-bridge")
  local_tmux = File.join(File.dirname(__FILE__), "bin", "agent-bridge-tmux")
  
  mounts = []
  if File.exist?(local_setup_script)
    puts "🔧 Using local setup-agent.rb for development"
    mounts += ["-v", "#{File.expand_path(local_setup_script)}:/tmp/setup-agent.rb:ro"]
  end

  if File.exist?(linux_bridge)
    puts "🔧 Using local linux binary: #{linux_bridge}"
    mounts += ["-v", "#{linux_bridge}:/tmp/agent-bridge:ro"]
  elsif File.exist?(local_bridge_default)
    # Check if it's a binary or script
    is_script = File.read(local_bridge_default, 4) == "#!/b"
    if is_script
       puts "⚠️  bin/agent-bridge is a host wrapper script. Please run 'bin/build-bridge' to generate linux binaries."
    else
       puts "🔧 Using local agent-bridge binary"
       mounts += ["-v", "#{local_bridge_default}:/tmp/agent-bridge:ro"]
    end
  end
  
  if File.exist?(local_tmux)
    mounts += ["-v", "#{File.expand_path(local_tmux)}:/tmp/agent-bridge-tmux:ro"]
  end

  docker_cmd += mounts

  if File.exist?(local_setup_script)
    docker_cmd += [image_name(config), "ruby", "/tmp/setup-agent.rb"]
  else
    docker_cmd += [image_name(config)]
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

  agent_def = AGENT_CONFIGS[agent_type]
  agent_config = config.dig("agents", agent_type) || {}
  container_name = agent_config["container_name"] || agent_def[:name]

  running = `docker ps --filter name=^#{container_name}$ --format '{{.Names}}'`.strip

  if running.empty?
    puts "⚠️  #{agent_type} agent is not running. Auto-starting..."
    build_docker_image(config)
    run_agent(agent_type, config)
    sleep 3
  end

  puts "📎 Attaching to #{agent_type} agent..."
  
  # Determine the user to attach as
  # Robust method: find the user running the agent process (tmux or bridge)
  user = `docker exec #{container_name} ps aux | grep "[a]gent-bridge-tmux" | awk '{print $1}' | head -n 1`.strip
  
  if user.empty?
    user = `docker exec #{container_name} ps aux | grep "[t]mux new-session" | awk '{print $1}' | head -n 1`.strip
  end

  if user.empty?
    # Fallback to previous heuristic
    detected_user = `docker exec #{container_name} whoami 2>/dev/null`.strip
    if detected_user == "root" || detected_user.empty?
       uid = Process.uid
       mapped_user = `docker exec #{container_name} getent passwd #{uid} | cut -d: -f1`.strip
       user = mapped_user unless mapped_user.empty?
    else
       user = detected_user
    end
  end
  
  if user.empty?
    # Final Fallback
    user = "rails"
    puts "⚠️  Could not detect agent user, defaulting to '#{user}'"
  end
  
  if user.empty?
    # Fallback: default to rails (standard for this image)
    user = "rails"
    puts "⚠️  Could not detect agent user, defaulting to '#{user}'"
  end

  puts "   User: #{user}"

  # Wait for tmux session to be ready
  10.times do
    if system("docker", "exec", "-u", user, container_name, "tmux", "has-session", "-t", "agent", err: File::NULL, out: File::NULL)
      break
    end
    sleep 1
  end

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
  puts "  2. Create tinker.env.rb (see https://github.com/RoM4iK/tinker-public/blob/main/README.md)"
  puts "  3. echo 'tinker.env.rb' >> .gitignore"
  puts "  4. npx tinker-agent worker"
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
  build_docker_image(config)
  run_agent(command, config)
end
