# frozen_string_literal: true

require "fileutils"

module TinkerAgent
  module Docker
    def self.check_dockerfile!
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

    def self.build_image(config)
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
          "-t", Config.image_name(config),
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
  end
end
