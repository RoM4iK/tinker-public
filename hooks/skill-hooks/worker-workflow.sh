#!/bin/bash
# Skill Hook: worker-workflow Knowledge Injection
# Fetches project-specific worker agent patterns and conventions

set -e

SKILL_NAME="worker-workflow"

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

# Project-Specific Worker Workflow Knowledge
${response}

EOF
  fi
fi

exit 0
