# Tinker Public

Pre-built binaries and skills for the Tinker agent system.

## Quick Start (Any Project)

Add Tinker agents to any repository with **ONE file**:

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/run-tinker-agent.rb -o run-tinker-agent.rb
chmod +x run-tinker-agent.rb

# Create credentials file
echo "GH_TOKEN=your-github-token" > .agent.env

# Run an agent
./run-tinker-agent.rb worker
```

That's it! The script:
1. Builds a Docker image (downloads skills & binaries from this repo)
2. Mounts your project into the container
3. Runs the agent with full git access

## Usage

```bash
# Start an agent
./run-tinker-agent.rb worker
./run-tinker-agent.rb planner
./run-tinker-agent.rb reviewer
./run-tinker-agent.rb orchestrator

# Attach to running agent
./run-tinker-agent.rb attach worker

# Stop agent
docker stop tinker-worker
```

## Configuration (.agent.env)

```bash
# Required: GitHub access for git operations
GH_TOKEN=your-github-token

# Or use GitHub App (preferred for organizations)
GITHUB_APP_CLIENT_ID=your-client-id
GITHUB_APP_INSTALLATION_ID=your-installation-id
GITHUB_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem

# Optional: Connect to Tinker backend
RAILS_WS_URL=wss://your-tinker-instance/cable
PROJECT_ID=1
```

## Requirements

- Docker
- Ruby
- Git (with remote configured)

## What's Downloaded

The Docker image fetches from this repo at build time:
- `bin/agent-bridge` - Go binary for Claude ↔ Tinker communication
- `skills/*` - Reusable agent skills (git-workflow, worker-workflow, etc.)

## Skills Included

- **git-workflow**: Branch management, commits, PRs
- **worker-workflow**: Task execution, coordination
- **reviewer-workflow**: PR review, code quality
- **memory**: Knowledge sharing across sessions
- **orchestrator-workflow**: Agent coordination
- **ticket-management**: Creating and managing tickets
- And more...

## License

MIT - see [LICENSE](LICENSE)

## Related

- [tinker](https://github.com/RoM4iK/tinker) - Main Tinker system
