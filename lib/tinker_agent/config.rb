# frozen_string_literal: true

require "json"

module TinkerAgent
  module Config
    def self.load
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
      
      # Normalize per-agent env hashes
      if config["agents"].is_a?(Hash)
        config["agents"].each do |agent_key, agent_config|
          agent_key = agent_key.to_s
          if agent_config.is_a?(Hash) && agent_config["env"].is_a?(Hash)
            agent_config["env"] = agent_config["env"].transform_keys(&:to_s)
          elsif agent_config.is_a?(Hash) && agent_config[:env].is_a?(Hash)
            agent_config["env"] = agent_config[:env].transform_keys(&:to_s)
          end
        end
      end

      # Normalize symbols to strings for consistency via JSON round-trip
      JSON.parse(JSON.generate(config))
    end

    def self.image_name(config)
      if config["project_id"]
        "tinker-sandbox-#{config['project_id']}"
      else
        "tinker-sandbox"
      end
    end
  end
end
