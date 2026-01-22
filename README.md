# Tinker Agent

Run Tinker agents in any Docker container with Ruby.

## Setup

1. Create `Dockerfile.sandbox` in your project root (copy your existing Dockerfile).
2. Add the following lines to `Dockerfile.sandbox`:

```dockerfile
# --- TINKER AGENT SETUP ---
ARG TINKER_VERSION=main
RUN curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/${TINKER_VERSION}/bin/install-agent.sh | bash

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "-c", "curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/${TINKER_VERSION:-main}/setup-agent.rb | ruby"]
```

## Configuration (tinker.env.rb)

Agents are configured via a `tinker.env.rb` file in your project root. This Ruby file allows you to define configuration and secrets (using heredocs).

**Do not commit `tinker.env.rb` to git!** Add it to your `.gitignore`.

Example `tinker.env.rb`:

```ruby
{
  project_id: 2,
  rails_ws_url: "wss://tinkerai.win/cable",
  rails_api_url: "https://tinker.tinkerai.win/api/v1",

  # Git Identity
  git: {
    user_name: "Tinker Agent",
    user_email: "agent@example.com"
  },

  # GitHub Auth (App or Token)
  github: {
    method: "app",
    app_client_id: "Iv23liFDGt4FWGJSHAS",
    app_installation_id: "102387777",
    app_private_key_path: "/absolute/path/to/key.pem"
  },

  # Agent Specific Config
  agents: {
    worker: {
      mcp_api_key: "...",
      container_name: "tinker-worker"
    },
    planner: {
      mcp_api_key: "...",
      container_name: "tinker-planner"
    }
  },

  # Environment Variables Injection
  # Simple strings or Heredocs supported
  dot_env: <<~ENV
    PORT=3200
    DB_HOST=localhost
    SECRET_KEY_BASE=very_secret
    OPENAI_API_KEY=sk-...
  ENV
}
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENT_TYPE` | ✅ | `worker`, `planner`, `reviewer`, or `researcher` |
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
        curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/bin/install-agent.sh | bash &&
        curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/setup-agent.rb | ruby
      "
```

## Attaching to Running Agent

```bash
docker exec -it <container> tmux attach -t agent-wrapper
```

Press `Ctrl+B` then `D` to detach.

## License

MIT
