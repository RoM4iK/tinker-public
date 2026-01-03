#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent Bridge Download Script
# Downloads the agent-bridge binary for your platform
#
# Usage:
#   ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/download-bridge.rb)"
#
# Or with options:
#   OUTPUT_DIR=bin VERSION=main ruby download-bridge.rb

require "fileutils"
require "net/http"
require "uri"

class BridgeDownloader
  VERSION = ENV.fetch("VERSION", "main")
  REPO_BASE = ENV.fetch("REPO_BASE", "https://raw.githubusercontent.com/RoM4iK/tinker-public")
  OUTPUT_DIR = ENV.fetch("OUTPUT_DIR", ".")

  PLATFORMS = {
    "linux-x86_64" => "linux-amd64",
    "linux-aarch64" => "linux-arm64",
    "linux-arm64" => "linux-arm64",
    "linux-armv7l" => "linux-arm",
    "darwin-x86_64" => "darwin-amd64",
    "darwin-arm64" => "darwin-arm64"
  }.freeze

  def run
    puts "🔧 Tinker Agent Bridge Downloader"
    puts ""

    platform = detect_platform
    puts "Detected platform: #{platform}"

    download_bridge(platform)
    download_checksum(platform)

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

  def binary_name(platform)
    platform == "linux-amd64" ? "agent-bridge" : "agent-bridge-#{platform}"
  end

  def download_bridge(platform)
    name = binary_name(platform)
    url = "#{REPO_BASE}/#{VERSION}/bin/#{name}"
    output_path = File.join(OUTPUT_DIR, name)

    FileUtils.mkdir_p(OUTPUT_DIR)

    puts "📦 Downloading #{name}..."

    if download_file(url, output_path)
      File.chmod(0o755, output_path)
      puts "✅ Downloaded to: #{output_path}"

      # Create symlink if not the default name
      if name != "agent-bridge"
        symlink_path = File.join(OUTPUT_DIR, "agent-bridge")
        FileUtils.rm_f(symlink_path)
        FileUtils.ln_sf(name, symlink_path)
        puts "🔗 Created symlink: #{symlink_path} -> #{name}"
      end
    else
      abort <<~ERROR
        ❌ Failed to download from #{url}
           You may need to build it manually from source:
           git clone https://github.com/RoM4iK/tinker.git
           cd tinker
           go build -o agent-bridge agent-bridge.go
      ERROR
    end
  end

  def download_checksum(platform)
    name = binary_name(platform)
    url = "#{REPO_BASE}/#{VERSION}/bin/#{name}.sha256"
    output_path = File.join(OUTPUT_DIR, "#{name}.sha256")

    if download_file(url, output_path)
      checksum = File.read(output_path).split.first
      puts "📋 Checksum: #{checksum}"
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
    puts "  ⚠️  Error: #{e.message}"
    false
  end

  def print_success_message
    puts ""
    puts "✨ Done! You can now run: ./agent-bridge"
  end
end

# Run if executed directly
BridgeDownloader.new.run if __FILE__ == $PROGRAM_NAME
