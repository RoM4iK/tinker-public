#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent - Run inside any Docker container with Ruby
#
# This script sets up and runs a Tinker agent. It:
# 1. Generates MCP config from environment variables
# 2. Creates CLAUDE.md with role-specific instructions
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

# Agent banners - role-specific instructions for Claude
AGENT_BANNERS = {
  "planner" => <<~BANNER,
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                       TINKER PLANNER - ROLE ENFORCEMENT                    ║
    ╠════════════════════════════════════════════════════════════════════════════╣
    ║  YOUR ROLE: INTERACTIVE PLANNING AND TICKET CREATION                       ║
    ║  YOUR MODE: CHAT WITH HUMAN - DISCUSS, PLAN, CREATE TICKETS                ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This session is running as the TINKER PLANNER agent in INTERACTIVE CHAT MODE.

    CORE RESPONSIBILITIES:
      ✓ Discuss feature ideas and requirements with the human
      ✓ Break down large features into implementable tickets
      ✓ Write clear ticket descriptions with acceptance criteria
      ✓ Create tickets using create_ticket MCP tool when plans are confirmed
  BANNER

  "worker" => <<~BANNER,
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                        TINKER WORKER - ROLE ENFORCEMENT                    ║
    ╠════════════════════════════════════════════════════════════════════════════╣
    ║  YOUR ROLE: AUTONOMOUS CODE IMPLEMENTATION                                 ║
    ║  YOUR MODE: WORK AUTONOMOUSLY ON ASSIGNED TICKETS                          ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This session is running as the TINKER WORKER agent in AUTONOMOUS MODE.

    CORE RESPONSIBILITIES:
      ✓ Check for assigned tickets using get_my_tickets MCP tool
      ✓ Implement code changes according to ticket specifications
      ✓ Create branches, commits, and pull requests
      ✓ Update ticket status as you progress
  BANNER

  "reviewer" => <<~BANNER,
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                       TINKER REVIEWER - ROLE ENFORCEMENT                   ║
    ╠════════════════════════════════════════════════════════════════════════════╣
    ║  YOUR ROLE: AUTONOMOUS CODE REVIEW                                         ║
    ║  YOUR MODE: REVIEW PULL REQUESTS AND PROVIDE FEEDBACK                      ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This session is running as the TINKER REVIEWER agent in AUTONOMOUS MODE.

    CORE RESPONSIBILITIES:
      ✓ Check for PRs awaiting review
      ✓ Review code quality, tests, and documentation
      ✓ Approve or request changes with clear feedback
  BANNER

  "orchestrator" => <<~BANNER,
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                     TINKER ORCHESTRATOR - ROLE ENFORCEMENT                 ║
    ╠════════════════════════════════════════════════════════════════════════════╣
    ║  YOUR ROLE: AUTONOMOUS WORK COORDINATION                                   ║
    ║  YOUR MODE: ASSIGN TICKETS AND MANAGE WORKFLOW                             ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This session is running as the TINKER ORCHESTRATOR agent in AUTONOMOUS MODE.

    CORE RESPONSIBILITIES:
      ✓ Monitor ticket queue and agent availability
      ✓ Assign tickets to workers based on capacity
      ✓ Track progress and handle blockers
  BANNER

  "researcher" => <<~BANNER
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                      TINKER RESEARCHER - ROLE ENFORCEMENT                  ║
    ╠════════════════════════════════════════════════════════════════════════════╣
    ║  YOUR ROLE: AUTONOMOUS RESEARCH AND ANALYSIS                               ║
    ║  YOUR MODE: INVESTIGATE CODEBASE AND DOCUMENT FINDINGS                     ║
    ╚════════════════════════════════════════════════════════════════════════════╝

    This session is running as the TINKER RESEARCHER agent in AUTONOMOUS MODE.

    CORE RESPONSIBILITIES:
      ✓ Analyze codebase architecture and patterns
      ✓ Research best practices and solutions
      ✓ Document findings in memory for other agents
  BANNER
}

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
  unless AGENT_BANNERS.key?(agent_type)
    puts "❌ Invalid AGENT_TYPE: #{agent_type}"
    puts "   Valid types: #{AGENT_BANNERS.keys.join(', ')}"
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

def setup_claude_md!
  agent_type = ENV["AGENT_TYPE"]
  banner = AGENT_BANNERS[agent_type]

  File.write("CLAUDE.md", banner)
  puts "📝 Created CLAUDE.md with #{agent_type} instructions"
end

def setup_github_auth!
  app_id = ENV["GITHUB_APP_ID"] || ENV["GITHUB_APP_CLIENT_ID"]
  
  if app_id && ENV["GITHUB_APP_INSTALLATION_ID"] && ENV["GITHUB_APP_PRIVATE_KEY_PATH"]
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

      def generate_jwt(app_id, private_key_path)
        private_key = OpenSSL::PKey::RSA.new(File.read(private_key_path))
        payload = {
          iat: Time.now.to_i - 60,
          exp: Time.now.to_i + 600,
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
        { token: data['token'], expires_at: Time.parse(data['expires_at']) }
      end

      def cached_token(app_id, installation_id, key_path)
        cache_file = '/tmp/github-app-token-cache'
        if File.exist?(cache_file)
          cache = JSON.parse(File.read(cache_file))
          expires_at = Time.parse(cache['expires_at'])
          return cache['token'] if expires_at > Time.now + 300
        end
        jwt = generate_jwt(app_id, key_path)
        token_data = get_installation_token(jwt, installation_id)
        File.write(cache_file, token_data.to_json)
        token_data[:token]
      end

      app_id = ENV['GITHUB_APP_CLIENT_ID'] || ENV['GITHUB_APP_ID']
      installation_id = ENV['GITHUB_APP_INSTALLATION_ID']
      key_path = ENV['GITHUB_APP_PRIVATE_KEY_PATH']

      puts cached_token(app_id, installation_id, key_path)
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

  # Run agent-bridge-tmux which handles tmux session and status bar
  exec("#{bin_dir}/agent-bridge-tmux")
end

# Main
puts "🤖 Tinker Agent Setup"
puts "====================="
puts ""

check_env!
setup_mcp_config!
setup_claude_config!
setup_claude_md!
setup_github_auth!
setup_git_config!
bin_dir = download_agent_bridge!
run_agent!(bin_dir)
