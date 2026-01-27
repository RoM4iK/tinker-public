#!/bin/bash
# GitHub CLI wrapper with permission controls for agents
#
# This wrapper blocks comment-related gh commands for agents (worker, planner, reviewer, researcher)
# Agents should use Tinker's add_comment MCP tool instead
# All other gh commands are allowed

# Real gh binary location (will be moved to /usr/bin/gh.real by setup script)
REAL_GH="/usr/bin/gh.real"

# Fallback locations if gh.real doesn't exist
if [ ! -f "$REAL_GH" ]; then
  if [ -f "/usr/local/bin/gh.real" ]; then
    REAL_GH="/usr/local/bin/gh.real"
  elif [ -f "/usr/bin/gh" ]; then
    REAL_GH="/usr/bin/gh"
  else
    echo "❌ Error: Cannot find gh binary" >&2
    exit 1
  fi
fi

# Check if caller is an agent (read AGENT_TYPE at runtime)
if [ -n "$AGENT_TYPE" ] && [[ "$AGENT_TYPE" =~ ^(worker|planner|reviewer|researcher)$ ]]; then
  # Block comment-related commands for agents
  if [[ "$1" == "comment" ]]; then
    echo "❌ You cannot use 'gh comment' commands as an agent." >&2
    echo "" >&2
    echo "Tinker has its own comment system via the add_comment MCP tool." >&2
    echo "Please use the add_comment tool instead of gh commands." >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  add_comment(ticket_id: 123, content: \"Your comment here\", comment_type: \"note\")" >&2
    exit 1
  elif [[ "$1" == "pr" ]] && [[ "$2" == "comment" ]]; then
    echo "❌ You cannot use 'gh pr comment' commands as an agent." >&2
    echo "" >&2
    echo "Tinker has its own comment system via the add_comment MCP tool." >&2
    echo "Please use the add_comment tool instead of gh commands." >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  add_comment(ticket_id: 123, content: \"Your comment here\", comment_type: \"note\")" >&2
    exit 1
  fi
fi

# Execute real gh binary with all arguments
exec "$REAL_GH" "$@"
