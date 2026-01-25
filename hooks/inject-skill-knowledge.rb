#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'fileutils'

# Skill Knowledge Injection Hook (SessionStart)
# Fetches all skill-hint knowledge articles and injects them into SKILL.md files

DEBUG_LOG = "/tmp/skill-injection-session.log"

def log_debug(message)
  timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
  File.open(DEBUG_LOG, 'a') { |f| f.puts "[#{timestamp}] #{message}" }
rescue => e
  # Fallback if log file can't be opened
  warn "Failed to log: #{e.message}"
end

log_debug("--- Starting skill injection SessionStart hook ---")

# 1. Configuration
# We no longer need PROJECT_ID or AGENT_TYPE, they are derived from API Key on server
RAILS_API_URL = ENV['RAILS_API_URL']
RAILS_API_KEY = ENV['RAILS_API_KEY']

# If the hook is running from ~/.claude/hooks, skills are in ~/.claude/skills
SKILLS_DIR = File.expand_path('../skills', File.dirname(__FILE__))

log_debug("Skills Dir: #{SKILLS_DIR}")

if RAILS_API_URL.nil? || RAILS_API_KEY.nil?
  log_debug("Missing required environment variables (RAILS_API_URL, RAILS_API_KEY). Aborting.")
  exit 0
end

# Helper to fetch from API
def fetch_injection_data
  uri = URI("#{RAILS_API_URL}/internal/knowledge/inject")
  log_debug("Fetching from API: #{uri}")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  http.open_timeout = 5
  http.read_timeout = 10

  request = Net::HTTP::Get.new(uri)
  request['X-API-Key'] = RAILS_API_KEY
  request['Accept'] = 'application/json'

  response = http.request(request)
  if response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  else
    log_debug("API Call Failed: #{response.code}")
    nil
  end
rescue => e
  log_debug("Exception fetching API: #{e.message}")
  nil
end

# 2. Fetch Knowledge (Single Call)
data = fetch_injection_data
unless data
  log_debug("Failed to fetch injection data. Exiting.")
  exit 0
end

log_debug("Identify Agent: #{data['agent_type']} (Project: #{data['project_id']})")

# 3. Process Skill Knowledge
skill_articles = data['skill_knowledge'] || []
log_debug("Fetched #{skill_articles.count} skill articles")

# Group Articles by Skill Tag
# Format: { "skill-name" => [article1, article2] }
articles_by_skill = Hash.new { |h, k| h[k] = [] }

skill_articles.each do |article|
  tags = article['tags'] || []
  tags.each do |tag|
    articles_by_skill[tag] << article
  end
end

log_debug("Articles mapped to skills: #{articles_by_skill.keys}")

# 4. Inject into SKILL.md files
START_MARKER = "<!-- KNOWLEDGE_INJECTION_START -->"
END_MARKER = "<!-- KNOWLEDGE_INJECTION_END -->"

Dir.glob(File.join(SKILLS_DIR, '*', 'SKILL.md')).each do |skill_file|
  skill_dir_name = File.basename(File.dirname(skill_file))
  log_debug("Processing skill: #{skill_dir_name}")

  relevant_articles = articles_by_skill[skill_dir_name]
  
  if relevant_articles.empty?
    log_debug("No custom knowledge for #{skill_dir_name}, cleaning up any existing injection.")
    content_to_inject = ""
  else
    log_debug("Found #{relevant_articles.count} articles for #{skill_dir_name}")
    content_to_inject = relevant_articles.map { |a| a['formatted'] }.join("\n\n---\n\n")
  end

  begin
    original_content = File.read(skill_file)
    
    new_content = if original_content.include?(START_MARKER) && original_content.include?(END_MARKER)
      # Replace existing block
      pattern = /#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m
      replacement = "#{START_MARKER}\n\n#{content_to_inject}\n#{END_MARKER}"
      original_content.sub(pattern, replacement)
    else
      # Append block if not exists
      # But only if we have content to inject
      if content_to_inject.empty?
        original_content
      else
        "#{original_content}\n\n#{START_MARKER}\n\n#{content_to_inject}\n#{END_MARKER}"
      end
    end

    if new_content != original_content
      File.write(skill_file, new_content)
      log_debug("Updated #{skill_file}")
    else
      log_debug("No changes for #{skill_file}")
    end

  rescue => e
    log_debug("Error updating #{skill_file}: #{e.message}")
  end
end

# 5. Process Agent Specific Context
additional_context = nil
agent_context_data = data['agent_context']

if agent_context_data && agent_context_data['formatted']
  log_debug("Found agent context")
  additional_context = agent_context_data['formatted']
end

log_debug("--- Injection Complete ---")

# 6. Output SessionStart Decision Control JSON
output = {
  "hookSpecificOutput" => {
    "hookEventName" => "SessionStart"
  }
}

if additional_context
  output["hookSpecificOutput"]["additionalContext"] = additional_context
end

puts JSON.generate(output)
