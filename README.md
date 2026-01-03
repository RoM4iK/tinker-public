# Tinker Public

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Pre-built binaries, reusable skills, and bootstrap scripts for the Tinker agent system.

## Quick Start (New Project)

Add Tinker agents to any repository with just 2 files:

```bash
# Download the bootstrap files
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/run-tinker-agent.rb -o run-tinker-agent.rb
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/Dockerfile.tinker -o Dockerfile.tinker
chmod +x run-tinker-agent.rb

# Run an agent
./run-tinker-agent.rb worker
```

## What's Included

### Skills

Reusable agent skills downloaded at container build time:
- **git-workflow**: Branch management, commits, PRs, stacking
- **worker-workflow**: Task execution, coordination, escalation
- **researcher-workflow**: Codebase analysis, proposal generation
- **review-workflow**: PR review, code quality checks
- **memory**: Knowledge sharing across sessions
- **memory-consolidation**: Background memory hygiene
- **orchestrator-workflow**: Agent coordination and assignment
- **ticket-management**: Creating and managing tickets
- **proposal-execution**: Executing approved proposals
- **retrospective**: Post-ticket learning documents

### Agent Bridge

Pre-built Go binaries for multiple platforms:
- `linux-amd64` (default)
- `linux-arm64`
- `darwin-amd64` (macOS Intel)
- `darwin-arm64` (macOS Apple Silicon)

## Configuration

Create `.agent.env` in your project root:

```bash
# Required: Anthropic API (or compatible)
ANTHROPIC_API_KEY=your-api-key

# Required: GitHub authentication (choose one)
# Option 1: GitHub App (recommended)
GITHUB_APP_CLIENT_ID=your-client-id
GITHUB_APP_INSTALLATION_ID=your-installation-id
GITHUB_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem

# Option 2: Personal Access Token
GH_TOKEN=your-github-token

# Optional: Tinker backend
RAILS_WS_URL=wss://your-tinker-instance/cable
PROJECT_ID=1
```

## Usage

```bash
# Start a worker agent
./run-tinker-agent.rb worker

# Start other agent types
./run-tinker-agent.rb planner
./run-tinker-agent.rb reviewer
./run-tinker-agent.rb orchestrator

# Attach to running agent
./run-tinker-agent.rb attach worker
```

## How It Works

1. `run-tinker-agent.rb` builds a Docker image using `Dockerfile.tinker`
2. The Dockerfile downloads skills and agent-bridge from this repo
3. Your project is copied into the container
4. The agent runs in an isolated sandbox with full git access

## Requirements

- Docker
- Ruby (for the bootstrap script)
- Git repository with remote configured

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related

- [tinker](https://github.com/RoM4iK/tinker) - Main Tinker agent system
