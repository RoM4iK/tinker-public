#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent - Run inside any Docker container with Ruby
#
# This script sets up and runs a Tinker agent. It:
# 1. Generates MCP config from environment variables
# 2. Verifies system prompt (agent banner) exists at /etc/tinker/system-prompt.txt
# 3. Downloads and runs agent-bridge
#
# Requirements (install in your container):
#   - Ruby 3.x
#   - Node.js 20+
#   - tmux
#   - git, curl, gh (GitHub CLI)
#   - claude CLI: npm install -g @anthropic-ai/claude-code
#
# Environment variables:
#   AGENT_TYPE        - worker|planner|reviewer|orchestrator|researcher
#   PROJECT_ID        - Your Tinker project ID
#   RAILS_WS_URL      - WebSocket URL (wss://tinker.example.com/cable)
#   RAILS_API_URL     - API URL (https://tinker.example.com/api/v1)
#   RAILS_API_KEY     - MCP API key for this agent type
#   GH_TOKEN          - GitHub token (or use GitHub App auth)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/tinker-agent.rb | ruby

require "json"
require "fileutils"
require "open-uri"
require "openssl"
require "net/http"
require "uri"
require "base64"
require "time"

TINKER_VERSION = ENV["TINKER_VERSION"] || "main"
TINKER_RAW_URL = "https://raw.githubusercontent.com/RoM4iK/tinker-public/#{TINKER_VERSION}"

# Valid agent types
VALID_AGENT_TYPES = %w[planner worker reviewer orchestrator researcher]

def check_env!
  required = %w[AGENT_TYPE PROJECT_ID RAILS_WS_URL]
  missing = required.select { |var| ENV[var].to_s.empty? }

  unless missing.empty?
    puts "❌ Missing environment variables: #{missing.join(', ')}"
    puts ""
    puts "Required:"
    puts "  AGENT_TYPE     - worker|planner|reviewer|orchestrator|researcher"
    puts "  PROJECT_ID     - Your Tinker project ID"
    puts "  RAILS_WS_URL   - WebSocket URL (wss://tinker.example.com/cable)"
    puts ""
    puts "Optional:"
    puts "  RAILS_API_URL  - API URL for MCP tools"
    puts "  RAILS_API_KEY  - MCP API key"
    puts "  GH_TOKEN       - GitHub token"
    exit 1
  end

  agent_type = ENV["AGENT_TYPE"]
  unless VALID_AGENT_TYPES.include?(agent_type)
    puts "❌ Invalid AGENT_TYPE: #{agent_type}"
    puts "   Valid types: #{VALID_AGENT_TYPES.join(', ')}"
    exit 1
  end
end

def fetch_agent_id!
  rails_api_url = ENV["RAILS_API_URL"]
  rails_api_key = ENV["RAILS_API_KEY"]
  
  unless rails_api_url && !rails_api_url.empty? && rails_api_key && !rails_api_key.empty?
    puts "❌ RAILS_API_URL or RAILS_API_KEY not set"
    puts "   Agent ID is required for the bridge to connect"
    exit 1
  end

  # Fetch agent ID from Rails API using api_key
  uri = URI("#{rails_api_url}/whoami")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  
  request = Net::HTTP::Get.new(uri)
  request["X-API-Key"] = rails_api_key
  request["Accept"] = "application/json"
  
  begin
    puts "🔍 Fetching agent ID from #{rails_api_url}/whoami..."
    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      agent_id = data["agent_id"] || data["id"]
      
      if agent_id && !agent_id.to_s.empty?
        ENV["AGENT_ID"] = agent_id.to_s
        puts "✅ Agent ID fetched: #{agent_id}"
      else
        puts "❌ Could not find agent_id in API response"
        puts "   Response: #{response.body}"
        exit 1
      end
    else
      puts "❌ Failed to fetch agent ID: #{response.code} #{response.message}"
      puts "   Response: #{response.body}"
      exit 1
    end
  rescue => e
    puts "❌ Error fetching agent ID: #{e.message}"
    puts "   #{e.class}: #{e.backtrace.first}"
    exit 1
  end
end

def setup_mcp_config!
  # MCP config is project-specific and should be provided by the Dockerfile
  # or mounted at runtime. This script only checks if it exists.
  
  agent_type = ENV["AGENT_TYPE"]
  rails_api_url = ENV["RAILS_API_URL"]
  rails_api_key = ENV["RAILS_API_KEY"]
  
  # Load existing config if present
  existing_config = {}
  if File.exist?(".mcp.json")
    begin
      existing_config = JSON.parse(File.read(".mcp.json"))
      puts "✅ Found existing .mcp.json, merging configuration..."
    rescue JSON::ParserError
      puts "⚠️  Existing .mcp.json is invalid, starting fresh"
    end
  end
  
  # Ensure mcpServers key exists
  existing_config["mcpServers"] ||= {}

  if rails_api_url && !rails_api_url.empty? && rails_api_key && !rails_api_key.empty?
    # Install tinker-mcp locally to ensure we can run it with node (bypassing shebang issues)
    tools_dir = File.expand_path("~/tinker-tools")
    FileUtils.mkdir_p(tools_dir)
    
    puts "📦 Installing tinker-mcp..."
    # Redirect output to avoid cluttering logs, unless it fails
    unless system("npm install --prefix #{tools_dir} tinker-mcp > /dev/null 2>&1")
      puts "❌ Failed to install tinker-mcp"
    end
    
    script_path = "#{tools_dir}/node_modules/tinker-mcp/dist/index.js"

    tinker_server_config = {
      "command" => "node",
      "args" => [script_path],
      "env" => {
        "RAILS_API_URL" => rails_api_url,
        "RAILS_API_KEY" => rails_api_key
      }
    }
    
    # Add/Update tinker server config
    existing_config["mcpServers"]["tinker-#{agent_type}"] = tinker_server_config
    
    File.write(".mcp.json", JSON.pretty_generate(existing_config))
    puts "📝 Updated .mcp.json with tinker-#{agent_type} server (using tinker-mcp)"
  else
    # Only write if we don't have existing config
    if existing_config["mcpServers"].empty?
      File.write(".mcp.json", JSON.generate({ "mcpServers" => {} }))
      puts "ℹ️  No MCP API credentials - MCP tools disabled"
    else
      puts "ℹ️  No MCP API credentials - keeping existing config"
    end
  end
end

def setup_claude_config!
  home_claude_json = File.expand_path("~/.claude.json")

  if File.exist?(home_claude_json)
    puts "🔧 Configuring claude.json..."
    begin
      claude_config = JSON.parse(File.read(home_claude_json))
      
      # Add bypass permission at top level
      claude_config["bypassPermissionsModeAccepted"] = true
      
      File.write(home_claude_json, JSON.pretty_generate(claude_config))
      puts "✅ claude.json configured with bypass permissions"
    rescue JSON::ParserError
      puts "⚠️  claude.json is invalid, skipping configuration"
    end
  else
    puts "⚠️  claude.json not found at #{home_claude_json}"
  end
end

def setup_system_prompt!
  if File.exist?("/etc/tinker/system-prompt.txt")
    puts "✅ System prompt available at /etc/tinker/system-prompt.txt"
  else
    puts "❌ /etc/tinker/system-prompt.txt not found!"
    exit 1
  end
end

def setup_skills!
  skills = ENV["SKILLS"].to_s.split(",")
  return if skills.empty?

  skills_dir = ".claude/skills"
  puts "🧠 Installing #{skills.size} skills to #{skills_dir}..."
  FileUtils.mkdir_p(skills_dir)
  
  skills.each do |skill|
    puts "   - #{skill}"
    
    # Try local copy first (dev mode, or if copied into image)
    # Check both PWD/tinker-public/skills or PWD/skills (depending on how image was built)
    local_paths = [
      File.join(Dir.pwd, "tinker-public", "skills", skill, "SKILL.md"),
      File.join(Dir.pwd, "skills", skill, "SKILL.md"),
      "/tmp/skills/#{skill}/SKILL.md" # For legacy mounts
    ]
    
    skill_content = nil
    
    local_paths.each do |path|
      if File.exist?(path)
        skill_content = File.read(path)
        puts "     (from local: #{path})"
        break
      end
    end
    
    url = "#{TINKER_RAW_URL}/skills/#{skill}/SKILL.md"

    begin
      unless skill_content
        skill_content = URI.open(url).read
      end
      
      # Write to .claude/skills/[skill]/SKILL.md with proper structure
      skill_dir = File.join(skills_dir, skill)
      FileUtils.mkdir_p(skill_dir)
      File.write(File.join(skill_dir, "SKILL.md"), skill_content)
    rescue OpenURI::HTTPError, Errno::ENOENT => e
      puts "⚠️  Failed to download skill #{skill}: #{e.message}"
    end
  end
  
  puts "✅ Skills installed"
end

def setup_github_auth!
  app_id = ENV["GITHUB_APP_ID"] || ENV["GITHUB_APP_CLIENT_ID"]
  
  # Check for private key in typical locations
  # 1. In the home directory (copied by entrypoint)
  # 2. In /tmp (mounted by docker)
  private_key_path = [
    File.expand_path("~/.github-app-privkey.pem"),
    "/tmp/github-app-privkey.pem"
  ].find { |path| File.exist?(path) }

  if app_id && ENV["GITHUB_APP_INSTALLATION_ID"] && private_key_path
    puts "🔐 Configuring GitHub App authentication..."

    # Create helper script
    helper_content = <<~RUBY
      #!/usr/bin/env ruby
      require 'openssl'
      require 'json'
      require 'net/http'
      require 'uri'
      require 'base64'
      require 'time'

      PRIVATE_KEY_PATH = "#{private_key_path}"

      def generate_jwt(app_id)
        private_key = OpenSSL::PKey::RSA.new(File.read(PRIVATE_KEY_PATH))
        payload = {
          iat: Time.now.to_i - 60,
          exp: Time.now.to_i + 480, # 8 minutes to handle clock skew
          iss: app_id
        }
        header = { alg: 'RS256', typ: 'JWT' }
        segments = [
          Base64.urlsafe_encode64(header.to_json, padding: false),
          Base64.urlsafe_encode64(payload.to_json, padding: false)
        ]
        signing_input = segments.join('.')
        signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_input)
        segments << Base64.urlsafe_encode64(signature, padding: false)
        segments.join('.')
      end

      def get_installation_token(jwt, installation_id)
        uri = URI("https://api.github.com/app/installations/\#{installation_id}/access_tokens")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer \#{jwt}"
        request['Accept'] = 'application/vnd.github+json'
        
        response = http.request(request)
        data = JSON.parse(response.body)
        
        unless response.is_a?(Net::HTTPSuccess)
          STDERR.puts "❌ Error getting installation token: \#{response.code} \#{response.message}"
          STDERR.puts "   Response: \#{response.body}"
          exit 1
        end

        { token: data['token'], expires_at: Time.parse(data['expires_at']) }
      end

      def find_or_create_cached_token(app_id, installation_id)
        cache_file = '/tmp/github-app-token-cache'
        cached_token = read_cached_token(cache_file)
        return cached_token if cached_token

        jwt = generate_jwt(app_id)
        token_data = get_installation_token(jwt, installation_id)
        File.write(cache_file, token_data.to_json)
        token_data[:token]
      end

      def read_cached_token(cache_file)
        return nil unless File.exist?(cache_file)
        cache = JSON.parse(File.read(cache_file))
        return if cache['token'].nil? || cache['expires_at'].nil?
        return cache['token'] if Time.parse(cache['expires_at']) > Time.now + 300
        nil
      rescue
      end

      app_id = ENV['GITHUB_APP_CLIENT_ID'] || ENV['GITHUB_APP_ID']
      installation_id = ENV['GITHUB_APP_INSTALLATION_ID']

      puts find_or_create_cached_token(app_id, installation_id)
    RUBY

    # Install helper via sudo to /usr/local/bin
    helper_path = "/usr/local/bin/git-auth-helper"
    File.write("/tmp/git-auth-helper", helper_content)
    system("sudo mv /tmp/git-auth-helper #{helper_path}")
    system("sudo chmod +x #{helper_path}")

    # Configure git
    system("git config --global credential.helper '!f() { test \"$1\" = get && echo \"protocol=https\" && echo \"host=github.com\" && echo \"username=x-access-token\" && echo \"password=$(#{helper_path})\"; }; f'")
    
    # Configure gh CLI wrapper for auto-refresh
    real_gh_path = "/usr/bin/gh"
    if File.exist?(real_gh_path)
      wrapper_path = "/usr/local/bin/gh"
      wrapper_content = <<~BASH
        #!/bin/bash
        # Auto-refresh GitHub token using git-auth-helper
        export GH_TOKEN=$(#{helper_path})
        exec #{real_gh_path} "$@"
      BASH
      
      File.write("/tmp/gh-wrapper", wrapper_content)
      system("sudo mv /tmp/gh-wrapper #{wrapper_path}")
      system("sudo chmod +x #{wrapper_path}")
      puts "✅ GitHub App authentication configured (with auto-refresh)"
    else
      puts "⚠️  Could not find 'gh' at #{real_gh_path}, skipping wrapper"
    end

  elsif ENV["GH_TOKEN"] && !ENV["GH_TOKEN"].empty?
    system("echo '#{ENV['GH_TOKEN']}' | gh auth login --with-token 2>/dev/null")
    puts "🔐 GitHub authentication configured"
  else
    puts "⚠️  No GH_TOKEN or GitHub App config - GitHub operations may fail"
  end
end

def setup_git_config!
  # Configure identity if provided
  if ENV["GIT_USER_NAME"] && !ENV["GIT_USER_NAME"].empty?
    system("git config --global user.name \"#{ENV['GIT_USER_NAME']}\"")
    puts "✅ Git user.name configured"
  end

  if ENV["GIT_USER_EMAIL"] && !ENV["GIT_USER_EMAIL"].empty?
    system("git config --global user.email \"#{ENV['GIT_USER_EMAIL']}\"")
    puts "✅ Git user.email configured"
  end

  # Force HTTPS instead of SSH to ensure our token auth works
  # This fixes "Permission denied (publickey)" when the repo uses git@github.com remote
  system("git config --global url.\"https://github.com/\".insteadOf \"git@github.com:\"")
  puts "✅ Git configured to force HTTPS for GitHub"
end

def download_agent_bridge!
  # Detect architecture
  arch = `uname -m`.strip
  if arch == "x86_64"
    arch = "amd64"
  elsif arch == "aarch64" || arch == "arm64"
    arch = "arm64"
  else
    puts "❌ Unsupported architecture: #{arch}"
    exit 1
  end

  bridge_url = "#{TINKER_RAW_URL}/bin/agent-bridge-linux-#{arch}"
  bridge_tmux_url = "#{TINKER_RAW_URL}/bin/agent-bridge-tmux"
  target_dir = "/usr/local/bin"

  # Check if binaries are mounted at /tmp (dev mode)
  if File.exist?("/tmp/agent-bridge")
    puts "🔧 Installing mounted agent-bridge..."
    system("sudo cp /tmp/agent-bridge #{target_dir}/agent-bridge")
    system("sudo chmod +x #{target_dir}/agent-bridge")
  else
    puts "📥 Downloading agent-bridge for linux-#{arch}..."
    system("sudo curl -fsSL #{bridge_url} -o #{target_dir}/agent-bridge")
    system("sudo chmod +x #{target_dir}/agent-bridge")
  end

  if File.exist?("/tmp/agent-bridge-tmux")
    puts "🔧 Installing mounted agent-bridge-tmux..."
    system("sudo cp /tmp/agent-bridge-tmux #{target_dir}/agent-bridge-tmux")
    system("sudo chmod +x #{target_dir}/agent-bridge-tmux")
  else
    system("sudo curl -fsSL #{bridge_tmux_url} -o #{target_dir}/agent-bridge-tmux")
    system("sudo chmod +x #{target_dir}/agent-bridge-tmux")
  end

  puts "✅ agent-bridge installed to #{target_dir}"
  
  # Patch agent-bridge-tmux to force INSIDE_TMUX=1
  # Note: This is now fixed in the repo, but we keep this for backward compatibility
  # with older agent-bridge-tmux scripts if cached
  puts "🔧 Patching agent-bridge-tmux to force INSIDE_TMUX=1..."
  
  # Read the file (we can read /usr/local/bin files usually)
  content = File.read("#{target_dir}/agent-bridge-tmux")
  
  # Replace the command if not already present
  unless content.include?("export INSIDE_TMUX=1")
    new_content = content.gsub(
      "&& agent-bridge\"", 
      "&& export INSIDE_TMUX=1 && agent-bridge\""
    )
    
    # Write to temp file
    File.write("/tmp/agent-bridge-tmux-patched", new_content)
    
    # Move to destination with sudo
    system("sudo mv /tmp/agent-bridge-tmux-patched #{target_dir}/agent-bridge-tmux")
    system("sudo chmod +x #{target_dir}/agent-bridge-tmux")
  end
  
  return target_dir
end

def run_agent!(bin_dir)
  agent_type = ENV["AGENT_TYPE"]
  puts ""
  puts "🚀 Starting #{agent_type} agent..."
  puts "   Press Ctrl+B then D to detach from tmux"
  puts ""

  # Build environment variables to pass to agent-bridge-tmux
  # We need to explicitly export AGENT_ID if it was fetched
  env_vars = {}
  env_vars["AGENT_ID"] = ENV["AGENT_ID"] if ENV["AGENT_ID"]
  
  # Run agent-bridge-tmux which handles tmux session and status bar
  exec(env_vars, "#{bin_dir}/agent-bridge-tmux")
end

# Main
puts "🤖 Tinker Agent Setup"
puts "====================="
puts ""

check_env!
fetch_agent_id!
setup_mcp_config!
setup_claude_config!
setup_system_prompt!
setup_skills!
setup_github_auth!
setup_git_config!
bin_dir = download_agent_bridge!
run_agent!(bin_dir)