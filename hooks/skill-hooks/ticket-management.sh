#!/bin/bash
# Skill Hook: ticket-management Knowledge Injection
# Fetches project-specific ticket creation and management patterns

set -e

SKILL_NAME="ticket-management"

# Validate required environment variables
if [[ -z "${PROJECT_ID}" ]]; then
  exit 0
fi

if [[ -z "${RAILS_API_URL}" ]] || [[ -z "${RAILS_API_KEY}" ]]; then
  exit 0
fi

# Construct API endpoint URL
API_ENDPOINT="${RAILS_API_URL}/internal/knowledge/skill_hint"
QUERY_PARAMS="skill_name=${SKILL_NAME}&project_id=${PROJECT_ID}"

# Fetch skill hint knowledge from Rails API
if response=$(curl -s \
  --fail \
  --header "X-API-Key: ${RAILS_API_KEY}" \
  --header "Accept: text/plain" \
  "${API_ENDPOINT}?${QUERY_PARAMS}"); then

  if [[ -n "${response}" ]]; then
    cat <<EOF

# Project-Specific Ticket Management Knowledge
${response}

EOF
  fi
fi

exit 0
