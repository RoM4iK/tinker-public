# frozen_string_literal: true

module TinkerAgent
  module Agent
    def self.run(agent_type, config, agent_configs)
      unless agent_configs.keys.include?(agent_type)
        puts "❌ Unknown agent type: #{agent_type}"
        puts "   Available: #{agent_configs.keys.join(', ')}"
        exit 1
      end

      agent_def = agent_configs[agent_type]
      agent_config = config.dig("agents", agent_type) || {}
      container_name = agent_config["container_name"] || agent_def[:name]

      puts "🚀 Starting #{agent_type} agent..."

      # Stop existing container if running
      system("docker", "rm", "-f", container_name, err: File::NULL, out: File::NULL)

      # Write banner to a persistent temp file (not auto-deleted)
      banner_path = "/tmp/tinker-agent-banner-#{agent_type}.txt"
      File.write(banner_path, agent_def[:banner])

      docker_cmd = build_docker_command(container_name, agent_type, config, agent_config, agent_def, banner_path)

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

    def self.attach(agent_type, config, agent_configs)
      unless agent_configs.keys.include?(agent_type)
        puts "❌ Unknown agent type: #{agent_type}"
        exit 1
      end

      agent_def = agent_configs[agent_type]
      agent_config = config.dig("agents", agent_type) || {}
      container_name = agent_config["container_name"] || agent_def[:name]

      running = `docker ps --filter name=^#{container_name}$ --format '{{.Names}}'`.strip

      if running.empty?
        puts "⚠️  #{agent_type} agent is not running. Auto-starting..."
        Docker.build_image(config)
        run(agent_type, config, agent_configs)
        sleep 3
      end

      puts "📎 Attaching to #{agent_type} agent..."
      
      user = detect_agent_user(container_name)
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

    private

    def self.build_docker_command(container_name, agent_type, config, agent_config, agent_def, banner_path)
      docker_cmd = [
        "docker", "run", "-d",
        "--name", container_name,
        "--network", "host",
        "--restart", "unless-stopped",
        "--tmpfs", "/rails/tmp",
        "--tmpfs", "/rails/log"
      ]

      # Inject custom environment variables from config
      # Merge global env with agent-specific env (agent-specific takes precedence)
      merged_env = {}
      merged_env.merge!(config["env"]) if config["env"]
      merged_env.merge!(agent_config["env"]) if agent_config["env"]
      
      if merged_env.any?
        merged_env.each do |k, v|
          docker_cmd += ["-e", "#{k}=#{v}"]
        end
        global_count = config["env"]&.size || 0
        agent_count = agent_config["env"]&.size || 0
        if agent_count > 0
          puts "🌿 Injected #{global_count} global + #{agent_count} agent-specific env vars"
        else
          puts "🌿 Injected #{global_count} custom env vars from config"
        end
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

      add_github_auth!(docker_cmd, config)
      add_git_config!(docker_cmd, config)
      add_development_mounts!(docker_cmd)

      local_setup_script = File.join(File.dirname(__FILE__), "..", "..", "setup-agent.rb")
      
      if File.exist?(local_setup_script)
        docker_cmd += [Config.image_name(config), "ruby", "/tmp/setup-agent.rb"]
      else
        docker_cmd += [Config.image_name(config)]
      end

      docker_cmd
    end

    def self.add_github_auth!(docker_cmd, config)
      github = config["github"] || {}
      
      if github["method"] == "app"
        key_path = File.expand_path(github["app_private_key_path"].to_s)

        unless File.exist?(key_path) && !File.directory?(key_path)
          puts "❌ Error: GitHub App private key not found at: #{key_path}"
          puts "   Please check 'app_private_key_path' in tinker.env.rb"
          exit 1
        end

        docker_cmd.concat([
          "-e", "GITHUB_APP_CLIENT_ID=#{github['app_client_id']}",
          "-e", "GITHUB_APP_INSTALLATION_ID=#{github['app_installation_id']}",
          "-v", "#{key_path}:/tmp/github-app-privkey.pem:ro"
        ])
        puts "🔐 Using GitHub App authentication"
      elsif github["token"]
        docker_cmd.concat(["-e", "GH_TOKEN=#{github['token']}"])
        puts "🔑 Using GitHub token authentication"
      else
        puts "❌ Error: No GitHub authentication configured"
        puts "   Please configure 'github' in tinker.env.rb"
        exit 1
      end
    end

    def self.add_git_config!(docker_cmd, config)
      return unless (git_config = config["git"])
      
      docker_cmd.concat(["-e", "GIT_USER_NAME=#{git_config['user_name']}"]) if git_config["user_name"]
      docker_cmd.concat(["-e", "GIT_USER_EMAIL=#{git_config['user_email']}"]) if git_config["user_email"]
    end

    def self.add_development_mounts!(docker_cmd)
      # Check for local setup-agent.rb (for development)
      local_setup_script = File.join(File.dirname(__FILE__), "..", "..", "setup-agent.rb")
      
      # Check for local agent-bridge binaries (for development)
      arch = `uname -m`.strip
      linux_arch = (arch == "x86_64") ? "amd64" : "arm64"
      linux_bridge = File.join(Dir.pwd, "tinker-public", "bin", "agent-bridge-linux-#{linux_arch}")
      
      local_bridge_default = File.join(Dir.pwd, "bin", "agent-bridge")
      local_tmux = File.join(File.dirname(__FILE__), "..", "..", "bin", "agent-bridge-tmux")
      
      if File.exist?(local_setup_script)
        puts "🔧 Using local setup-agent.rb for development"
        docker_cmd.concat(["-v", "#{File.expand_path(local_setup_script)}:/tmp/setup-agent.rb:ro"])
      end

      if File.exist?(linux_bridge)
        puts "🔧 Using local linux binary: #{linux_bridge}"
        docker_cmd.concat(["-v", "#{linux_bridge}:/tmp/agent-bridge:ro"])
      elsif File.exist?(local_bridge_default)
        # Check if it's a binary or script
        is_script = File.read(local_bridge_default, 4) == "#!/b"
        if is_script
          puts "⚠️  bin/agent-bridge is a host wrapper script. Please run 'bin/build-bridge' to generate linux binaries."
        else
          puts "🔧 Using local agent-bridge binary"
          docker_cmd.concat(["-v", "#{local_bridge_default}:/tmp/agent-bridge:ro"])
        end
      end
      
      if File.exist?(local_tmux)
        docker_cmd.concat(["-v", "#{File.expand_path(local_tmux)}:/tmp/agent-bridge-tmux:ro"])
      end
    end

    def self.detect_agent_user(container_name)
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
      
      user
    end
  end
end
