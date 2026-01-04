# Tinker Public

Run Claude-based AI agents in any project.

## Quick Start

```bash
# 1. Get the Dockerfile template
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/Dockerfile.sandbox.template \
  -o Dockerfile.sandbox

# 2. Get the config template
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/tinker.env.example.json \
  -o tinker.env.json

# 3. Edit tinker.env.json with your config

# 4. Add to .gitignore (contains secrets)
echo "tinker.env.json" >> .gitignore

# 5. Run an agent
npx tinker-agent worker
```

## Usage

```bash
# Start agents (no install needed)
npx tinker-agent worker
npx tinker-agent planner
npx tinker-agent reviewer
npx tinker-agent orchestrator
npx tinker-agent researcher

# Attach to running agent
npx tinker-agent attach worker

# Stop agent
docker stop myproject-worker
```

## Configuration (tinker.env.json)

```json
{
  "project_id": 1,
  "rails_ws_url": "wss://tinkerai.win/cable",
  "rails_api_url": "https://tinkerai.win/api/v1",

  "git": {
    "user_name": "Tinker Agent",
    "user_email": "tinker-agent@example.com"
  },

  "github": {
    "method": "app",
    "app_client_id": "Iv1.abc123",
    "app_installation_id": "12345678",
    "app_private_key_path": "/path/to/private-key.pem"
  },

  "agents": {
    "worker": {
      "mcp_api_key": "your-mcp-api-key",
      "container_name": "myproject-worker"
    }
  }
}
```

## Requirements

- Docker
- Ruby
- Node.js (for npx)

## What's in This Repo

- `bin/agent-bridge` - Go binary for Claude ↔ Tinker communication
- `bin/agent-bridge-tmux` - tmux wrapper script
- `skills/*` - Reusable agent skills
- `Dockerfile.sandbox.template` - Template for project Dockerfile
- `tinker.env.example.json` - Example config
- `run-tinker-agent.rb` - Launcher script (called via npx)

## Skills Included

- **git-workflow**: Branch management, commits, PRs
- **worker-workflow**: Task execution, coordination
- **reviewer-workflow**: PR review, code quality
- **memory**: Knowledge sharing across sessions
- **orchestrator-workflow**: Agent coordination
- **researcher-workflow**: Research and proposals
- **ticket-management**: Creating and managing tickets
- And more...

## How It Works

1. `npx tinker-agent worker` downloads & runs the launcher
2. Launcher reads `tinker.env.json` from current directory
3. Builds Docker image using your `Dockerfile.sandbox`
4. Runs container with your project mounted
5. Inside container:
   - Downloads skills from this repo
   - Starts Claude in tmux via agent-bridge
   - Connects to Tinker backend WebSocket

## License

MIT - see [LICENSE](LICENSE)

## Related

- [tinker](https://github.com/RoM4iK/tinker) - Main Tinker system
