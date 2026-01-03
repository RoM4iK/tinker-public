#!/usr/bin/env ruby
# frozen_string_literal: true

# Build Agent Bridge for multiple platforms
# Requires Go to be installed
#
# Usage:
#   ruby build-bridge.rb              # Build all platforms
#   ruby build-bridge.rb --current    # Build current platform only

require "fileutils"
require "optparse"

class BridgeBuilder
  SCRIPT_DIR = File.expand_path(__dir__)
  PROJECT_ROOT = File.expand_path("..", SCRIPT_DIR)
  TINKER_ROOT = File.expand_path("../..", SCRIPT_DIR)
  OUTPUT_DIR = File.join(PROJECT_ROOT, "bin")
  SOURCE_FILE = File.join(TINKER_ROOT, "agent-bridge.go")

  PLATFORMS = [
    { goos: "linux", goarch: "amd64", name: "agent-bridge" },
    { goos: "linux", goarch: "arm64", name: "agent-bridge-linux-arm64" },
    { goos: "linux", goarch: "arm", name: "agent-bridge-linux-arm" },
    { goos: "darwin", goarch: "amd64", name: "agent-bridge-darwin-amd64" },
    { goos: "darwin", goarch: "arm64", name: "agent-bridge-darwin-arm64" }
  ].freeze

  def initialize(options = {})
    @current_only = options[:current_only]
    @version = detect_version
  end

  def run
    puts "Building agent-bridge v#{@version}..."
    puts ""

    validate_requirements
    FileUtils.mkdir_p(OUTPUT_DIR)

    platforms = @current_only ? [current_platform] : PLATFORMS

    platforms.each do |platform|
      build_platform(platform)
    end

    puts ""
    puts "Build complete! Binaries available in #{OUTPUT_DIR}"
    list_binaries
  end

  private

  def detect_version
    Dir.chdir(TINKER_ROOT) do
      version = `git describe --tags --always --dirty 2>/dev/null`.strip
      version.empty? ? "dev" : version
    end
  end

  def validate_requirements
    unless system("which go > /dev/null 2>&1")
      abort "❌ Go is not installed. Please install Go first."
    end

    unless File.exist?(SOURCE_FILE)
      abort "❌ Source file not found: #{SOURCE_FILE}"
    end
  end

  def current_platform
    os = case RUBY_PLATFORM
    when /linux/i then "linux"
    when /darwin/i then "darwin"
    else abort "❌ Unsupported OS: #{RUBY_PLATFORM}"
    end

    arch = case `uname -m`.strip
    when "x86_64" then "amd64"
    when "aarch64", "arm64" then "arm64"
    when "armv7l" then "arm"
    else abort "❌ Unsupported architecture"
    end

    name = (os == "linux" && arch == "amd64") ? "agent-bridge" : "agent-bridge-#{os}-#{arch}"
    { goos: os, goarch: arch, name: name }
  end

  def build_platform(platform)
    goos = platform[:goos]
    goarch = platform[:goarch]
    name = platform[:name]

    puts "Building for #{goos}/#{goarch}..."

    output_path = File.join(OUTPUT_DIR, name)

    env = {
      "GOOS" => goos,
      "GOARCH" => goarch,
      "CGO_ENABLED" => "0"
    }

    ldflags = "-s -w -X main.Version=#{@version}"
    cmd = ["go", "build", "-ldflags=#{ldflags}", "-o", output_path, SOURCE_FILE]

    success = system(env, *cmd)

    if success
      generate_checksum(output_path)
      puts "  ✅ Built #{name}"
    else
      puts "  ❌ Failed to build #{name}"
    end
  end

  def generate_checksum(path)
    checksum_path = "#{path}.sha256"

    if system("which sha256sum > /dev/null 2>&1")
      Dir.chdir(File.dirname(path)) do
        system("sha256sum #{File.basename(path)} > #{File.basename(checksum_path)}")
      end
    elsif system("which shasum > /dev/null 2>&1")
      Dir.chdir(File.dirname(path)) do
        system("shasum -a 256 #{File.basename(path)} > #{File.basename(checksum_path)}")
      end
    end
  end

  def list_binaries
    puts ""
    Dir.glob(File.join(OUTPUT_DIR, "agent-bridge*")).sort.each do |path|
      next if path.end_with?(".sha256")

      size = File.size(path)
      size_mb = (size / 1024.0 / 1024.0).round(1)
      puts "  #{File.basename(path)} (#{size_mb} MB)"
    end
  end
end

# Parse command line options
options = { current_only: false }

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("--current", "Build for current platform only") do
    options[:current_only] = true
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Run if executed directly
BridgeBuilder.new(options).run if __FILE__ == $PROGRAM_NAME
