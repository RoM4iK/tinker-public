#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Public Install Script
# This script bootstraps a new repository with the Tinker agent system
#
# Usage:
#   ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/install.rb)"
#
# Or with options:
#   INSTALL_DIR=.claude VERSION=main ruby install.rb

require "fileutils"
require "net/http"
require "uri"
require "json"

class TinkerInstaller
  VERSION = ENV.fetch("VERSION", "main")
  REPO_BASE = ENV.fetch("REPO_BASE", "https://raw.githubusercontent.com/RoM4iK/tinker-public")
  INSTALL_DIR = ENV.fetch("INSTALL_DIR", ".claude")
  INSTALL_SKILLS = ENV.fetch("INSTALL_SKILLS", "true") == "true"
  INSTALL_BRIDGE = ENV.fetch("INSTALL_BRIDGE", "true") == "true"

  SKILLS = %w[
    git-workflow
    memory
    memory-consolidation
    orchestrator-workflow
    proposal-execution
    researcher-workflow
    retrospective
    review-workflow
    ticket-management
    worker-workflow
  ].freeze

  PLATFORMS = {
    "linux-x86_64" => "linux-amd64",
    "linux-aarch64" => "linux-arm64",
    "linux-arm64" => "linux-arm64",
    "linux-armv7l" => "linux-arm",
    "darwin-x86_64" => "darwin-amd64",
    "darwin-arm64" => "darwin-arm64"
  }.freeze

  def initialize
    @skills_dir = File.join(INSTALL_DIR, "skills")
    @bin_dir = File.join(INSTALL_DIR, "bin")
  end

  def run
    puts "🔧 Tinker Public Installer (#{VERSION})"
    puts ""

    platform = detect_platform
    puts "Detected platform: #{platform}"
    puts ""

    create_directories

    download_bridge(platform) if INSTALL_BRIDGE
    download_skills if INSTALL_SKILLS
    create_config_if_missing

    print_success_message
  end

  private

  def detect_platform
    os = case RUBY_PLATFORM
    when /linux/i then "linux"
    when /darwin/i then "darwin"
    else
      abort "❌ Unsupported OS: #{RUBY_PLATFORM}"
    end

    arch = `uname -m`.strip
    platform_key = "#{os}-#{arch}"

    PLATFORMS[platform_key] || abort("❌ Unsupported platform: #{platform_key}")
  end

  def create_directories
    puts "📁 Creating directories..."
    FileUtils.mkdir_p(@skills_dir)
    FileUtils.mkdir_p(@bin_dir)
  end

  def download_bridge(platform)
    puts "📦 Downloading agent-bridge for #{platform}..."

    binary_name = platform == "linux-amd64" ? "agent-bridge" : "agent-bridge-#{platform}"
    url = "#{REPO_BASE}/#{VERSION}/bin/#{binary_name}"
    output_path = File.join(@bin_dir, "agent-bridge")

    if download_file(url, output_path)
      File.chmod(0o755, output_path)
      puts "✅ Downloaded agent-bridge"
    else
      puts "❌ Failed to download agent-bridge from #{url}"
      puts "   You may need to build it manually from source."
    end
  end

  def download_skills
    puts "📦 Downloading skills..."

    SKILLS.each do |skill|
      skill_url = "#{REPO_BASE}/#{VERSION}/skills/#{skill}/SKILL.md"
      skill_dir = File.join(@skills_dir, skill)
      FileUtils.mkdir_p(skill_dir)

      skill_path = File.join(skill_dir, "SKILL.md")

      if download_file(skill_url, skill_path)
        puts "  ✅ Downloaded #{skill}"
      else
        puts "  ⚠️  Skipped #{skill} (not found)"
      end
    end
  end

  def download_file(url, output_path)
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    case response
    when Net::HTTPSuccess
      File.binwrite(output_path, response.body)
      true
    when Net::HTTPRedirection
      download_file(response["location"], output_path)
    else
      false
    end
  rescue StandardError => e
    puts "  ⚠️  Error downloading #{url}: #{e.message}"
    false
  end

  def create_config_if_missing
    config_file = File.join(INSTALL_DIR, "config.json")

    if File.exist?(config_file)
      puts "ℹ️  Config file already exists at #{config_file}"
      return
    end

    puts "📝 Creating config file..."

    config = {
      skills: [".claude/skills/*/SKILL.md"],
      mcpServers: {
        tinker: {
          command: "node",
          args: ["mcp-bridge/dist/index.js"],
          env: {
            RAILS_URL: "http://localhost:3000",
            TINKER_PROJECT_ID: "1"
          }
        }
      }
    }

    File.write(config_file, JSON.pretty_generate(config))
    puts "✅ Created #{config_file}"
  end

  def print_success_message
    puts ""
    puts "✨ Installation complete!"
    puts ""
    puts "Next steps:"
    puts "  1. Review and update #{INSTALL_DIR}/config.json with your project settings"
    puts "  2. Ensure agent-bridge is in your PATH: export PATH=\"$PATH:$(pwd)/#{@bin_dir}\""
    puts "  3. Start your agent sessions"
    puts ""
    puts "For more information, visit: https://github.com/RoM4iK/tinker-public"
  end
end

# Run if executed directly
TinkerInstaller.new.run if __FILE__ == $PROGRAM_NAME
