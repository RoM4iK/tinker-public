# Tinker Agent

Run Tinker agents in any Docker container with Ruby.

## Quick Start

```bash
# Inside your Docker container with Ruby installed:
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/tinker-agent.rb | \
  AGENT_TYPE=worker \
  PROJECT_ID=1 \
  RAILS_WS_URL=wss://tinker.example.com/cable \
  RAILS_API_URL=https://tinker.example.com/api/v1 \
  RAILS_API_KEY=your-mcp-api-key \
  GH_TOKEN=your-github-token \
  ruby
```

## Container Requirements

Your Docker container needs:

```dockerfile
# Base: any Linux with Ruby 3.x
FROM ruby:3.4-slim

# Required packages
RUN apt-get update && apt-get install -y \
    git curl tmux nodejs npm

# Claude CLI
RUN npm install -g @anthropic-ai/claude-code

# GitHub CLI (optional but recommended)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENT_TYPE` | ✅ | `worker`, `planner`, `reviewer`, `orchestrator`, or `researcher` |
| `PROJECT_ID` | ✅ | Your Tinker project ID |
| `RAILS_WS_URL` | ✅ | WebSocket URL for agent communication |
| `RAILS_API_URL` | | API URL for MCP tools |
| `RAILS_API_KEY` | | MCP API key (get from Tinker dashboard) |
| `GH_TOKEN` | | GitHub token for git operations |

## Agent Types

| Type | Mode | Purpose |
|------|------|---------|
| `planner` | Interactive | Chat with human, create tickets |
| `worker` | Autonomous | Implement tickets, create PRs |
| `reviewer` | Autonomous | Review PRs, approve/reject |
| `orchestrator` | Autonomous | Assign work to agents |
| `researcher` | Autonomous | Analyze codebase, document findings |

## What the Script Does

1. **Validates requirements** - Checks for Ruby, Node, tmux, git, claude CLI
2. **Creates `.mcp.json`** - Configures MCP tools for the agent type
3. **Creates `CLAUDE.md`** - Role-specific instructions Claude sees on startup
4. **Sets up GitHub auth** - Configures `gh` CLI with your token
5. **Downloads agent-bridge** - Binary that connects to Tinker via WebSocket
6. **Starts tmux session** - With status bar showing connection state

## Example: Docker Compose

```yaml
services:
  tinker-worker:
    image: ruby:3.4-slim
    environment:
      - AGENT_TYPE=worker
      - PROJECT_ID=1
      - RAILS_WS_URL=wss://tinker.example.com/cable
      - RAILS_API_URL=https://tinker.example.com/api/v1
      - RAILS_API_KEY=${WORKER_MCP_KEY}
      - GH_TOKEN=${GITHUB_TOKEN}
    volumes:
      - ./:/app
      - ~/.claude.json:/root/.claude.json:ro
    working_dir: /app
    command: >
      bash -c "
        apt-get update && apt-get install -y git curl tmux nodejs npm &&
        npm install -g @anthropic-ai/claude-code &&
        curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/tinker-agent.rb | ruby
      "
```

## Attaching to Running Agent

```bash
docker exec -it <container> tmux attach -t agent-wrapper
```

Press `Ctrl+B` then `D` to detach.

## License

MIT
