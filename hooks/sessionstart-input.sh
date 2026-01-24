#!/bin/bash
# Tinker Knowledge Injection Hook
# This script fetches agent-specific knowledge articles from the Rails API
# and injects them into Claude's context at session start.
#
# Environment Variables Required:
#   AGENT_TYPE     - worker|planner|reviewer|researcher
#   PROJECT_ID     - Your Tinker project ID
#   RAILS_API_URL  - API URL (e.g., https://tinker.example.com/api/v1)
#   RAILS_API_KEY  - MCP API key for authentication
#
# Output: Plain text formatted as Claude context (knowledge articles)

set -e

# Validate required environment variables
if [[ -z "${AGENT_TYPE}" ]]; then
  echo "# Warning: AGENT_TYPE not set, skipping knowledge injection" >&2
  exit 0
fi

if [[ -z "${PROJECT_ID}" ]]; then
  echo "# Warning: PROJECT_ID not set, skipping knowledge injection" >&2
  exit 0
fi

if [[ -z "${RAILS_API_URL}" ]]; then
  echo "# Warning: RAILS_API_URL not set, skipping knowledge injection" >&2
  exit 0
fi

if [[ -z "${RAILS_API_KEY}" ]]; then
  echo "# Warning: RAILS_API_KEY not set, skipping knowledge injection" >&2
  exit 0
fi

# Construct API endpoint URL
API_ENDPOINT="${RAILS_API_URL}/internal/knowledge/injection"
QUERY_PARAMS="agent_type=${AGENT_TYPE}&project_id=${PROJECT_ID}"

# Fetch knowledge articles from Rails API
# The endpoint returns plain text formatted for Claude consumption
if response=$(curl -s \
  --fail \
  --header "X-API-Key: ${RAILS_API_KEY}" \
  --header "Accept: text/plain" \
  "${API_ENDPOINT}?${QUERY_PARAMS}"); then

  # Only output if we got content
  if [[ -n "${response}" ]]; then
    echo "${response}"
  fi
else
  # Silently fail - don't break agent startup if API is unavailable
  echo "# Note: Unable to fetch knowledge articles from ${API_ENDPOINT}" >&2
fi

exit 0
