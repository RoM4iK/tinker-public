#!/usr/bin/env ruby
# frozen_string_literal: true

# Tinker Agent Runner
# Usage: npx tinker-agent [worker|planner|reviewer|researcher]
#        npx tinker-agent attach [agent-type]
#
# Requirements:
#   - Docker
#   - Ruby
#   - Dockerfile.sandbox in project root
#   - tinker.env.rb in project root (gitignored)

require_relative "lib/tinker_agent/config"
require_relative "lib/tinker_agent/docker"
require_relative "lib/tinker_agent/agent"
require_relative "agents"

def show_usage
  puts "Tinker Agent Runner"
  puts ""
  puts "Usage: npx tinker-agent [worker|planner|reviewer|researcher]"
  puts "       npx tinker-agent attach [agent-type]"
  puts ""
  puts "Setup:"
  puts "  1. Create Dockerfile.sandbox (see https://github.com/RoM4iK/tinker-public/blob/main/README.md)"
  puts "  2. Create tinker.env.rb (see https://github.com/RoM4iK/tinker-public/blob/main/README.md)"
  puts "  3. echo 'tinker.env.rb' >> .gitignore"
  puts "  4. npx tinker-agent worker"
  exit 1
end

# Main
show_usage if ARGV.empty?

command = ARGV[0].downcase

if command == "attach"
  agent_type = ARGV[1]&.downcase
  abort "Usage: npx tinker-agent attach [agent-type]" unless agent_type
  config = TinkerAgent::Config.load
  TinkerAgent::Agent.attach(agent_type, config, AGENT_CONFIGS)
else
  config = TinkerAgent::Config.load
  TinkerAgent::Docker.build_image(config)
  TinkerAgent::Agent.run(command, config, AGENT_CONFIGS)
end
