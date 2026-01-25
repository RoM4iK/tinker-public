#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# Skill Injection Hook
# Fetches skill-specific knowledge from Rails API and outputs it for Claude's PreToolUse/PostToolUse hook

PROJECT_ID = ENV['PROJECT_ID']
RAILS_API_URL = ENV['RAILS_API_URL']
RAILS_API_KEY = ENV['RAILS_API_KEY']
DEBUG_LOG = "/tmp/skill-injection.log"

# Determine Skill Name from various sources
# 1. ARGV[0] if provided
# 2. JSON input from stdin (hook payload)
SKILL_NAME = ARGV[0]

def log_debug(message)
  timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
  File.open(DEBUG_LOG, 'a') { |f| f.puts "[#{timestamp}] #{message}" }
end

def return_allow(context = nil)
  output = {
    hookSpecificOutput: {
      permissionDecision: "allow"
    }
  }

  if context && !context.empty?
    output[:hookSpecificOutput][:additionalContext] = context
    log_debug("Approved with additonal context (length: #{context.length})")
  else
    log_debug("Approved without context")
  end

  puts JSON.generate(output)
  exit 0
end

log_debug("--- Starting skill injection hook ---")
log_debug("ARGV: #{ARGV.inspect}")
log_debug("ENV['PROJECT_ID']: #{PROJECT_ID.inspect}")
log_debug("ENV['RAILS_API_URL']: #{RAILS_API_URL.inspect}")

if SKILL_NAME.to_s.empty?
  # Try to read from STDIN
  begin
    input_str = STDIN.read
    log_debug("STDIN content length: #{input_str.length}")
    log_debug("STDIN plain: #{input_str}")
    
    input = JSON.parse(input_str)
    
    # 1. Check if tool_input contains 'skill_name' or similar
    # If the tool is named "Skill", we probably pass the skill name as argument
    tool_input = input["tool_input"] || {}
    skill_name_derived = tool_input["skill_name"] || tool_input["name"] || tool_input["skill"]
    
    if skill_name_derived
      log_debug("Derived skill name from tool input: #{skill_name_derived}")
    end

    # 2. Derive from tool_name if not found in input
    unless skill_name_derived
      tool_name = input["tool_name"]
      log_debug("Tool name: #{tool_name}")
      case tool_name
      when "git" 
        skill_name_derived = "git-workflow"
      when "create_ticket", "update_ticket", "list_tickets", "get_ticket"
        skill_name_derived = "ticket-management"
      when "store_memory", "list_memories", "search_memory"
        skill_name_derived = "memory"
      end
      if skill_name_derived
         log_debug("Mapped tool '#{tool_name}' to skill '#{skill_name_derived}'")
      end
    end

    # Use a variable instead of constant assignment
    current_skill_name = skill_name_derived
  rescue => e
    log_debug("Error parsing STDIN: #{e.message}")
    # Ignore stdin errors
  end
end

current_skill_name ||= SKILL_NAME
log_debug("Final resolved skill name: #{current_skill_name.inspect}")

if current_skill_name.to_s.empty?
  # No skill name provided or derived, allow but no context
  log_debug("No skill name found, exiting with allow")
  return_allow
end

if PROJECT_ID.nil? || RAILS_API_URL.nil? || RAILS_API_KEY.nil?
  # Missing config, allow but no context
  log_debug("Missing required environment variables, exiting with allow")
  return_allow
end

begin
  uri = URI("#{RAILS_API_URL}/internal/knowledge/skill_hint")
  query_params = { skill_name: current_skill_name, project_id: PROJECT_ID }
  uri.query = URI.encode_www_form(query_params)
  
  log_debug("Fetching from API: #{uri}")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  # Set shorter timeouts to avoid blocking Claude
  http.open_timeout = 2
  http.read_timeout = 2

  request = Net::HTTP::Get.new(uri)
  request['X-API-Key'] = RAILS_API_KEY
  request['Accept'] = 'text/plain'
  
  response = http.request(request)
  log_debug("API Response code: #{response.code}")
  
  if response.is_a?(Net::HTTPSuccess) && !response.body.strip.empty?
    content = response.body.strip
    log_debug("Received content length: #{content.length}")
    return_allow("# Skill Knowledge: #{current_skill_name}\n#{content}")
  else
    log_debug("Empty response or non-success code")
    return_allow
  end
rescue => e
  # Network error or other exception, fail safe and allow
  log_debug("Exception during API call: #{e.message}")
  log_debug(e.backtrace.join("\n"))
  return_allow
end
