# Tinker Public

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A distribution repository for the Tinker agent system - providing pre-built binaries, reusable skills, and installation scripts for easy onboarding.

## Quick Start

Bootstrap a new repository with the Tinker agent system:

```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/install.rb)"
```

This will:
- Download the `agent-bridge` binary for your platform
- Install reusable skills (git-workflow, worker-workflow, etc.)
- Create configuration files
- Set up the directory structure

## What's Included

### 1. Agent Bridge Binary

Pre-built Go binaries for multiple platforms:
- `linux-amd64` (default)
- `linux-arm64`
- `darwin-amd64` (macOS Intel)
- `darwin-arm64` (macOS Apple Silicon)

### 2. Skills

Reusable agent skills that can be installed into any Tinker project:
- **git-workflow**: Branch management, commits, PRs, stacking
- **worker-workflow**: Task execution, coordination, escalation
- **researcher-workflow**: Codebase analysis, proposal generation
- **review-workflow**: PR review, code quality checks
- **memory**: Knowledge sharing across sessions
- **memory-consolidation**: Background memory hygiene
- **retrospective**: Post-ticket learning documents
- **proposal-execution**: Executing approved proposals
- **ticket-management**: Creating and managing tickets
- **orchestrator-workflow**: Agent coordination and assignment

### 3. MCP Bridge

JavaScript/TypeScript MCP server for Model Context Protocol communication.

## Installation Options

### Full Install (Recommended)

```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/install.rb)"
```

### Agent Bridge Only

```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/download-bridge.rb)"
```

### Skills Only

Skills are downloaded as raw content from GitHub:

```bash
# Download a single skill
mkdir -p .claude/skills/git-workflow
curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/skills/git-workflow/SKILL.md \
  -o .claude/skills/git-workflow/SKILL.md
```

Or run the installer with only skills:

```bash
INSTALL_BRIDGE=false ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/install.rb)"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VERSION` | `main` | Git ref (branch/tag) to download from |
| `INSTALL_DIR` | `.claude` | Installation directory |
| `INSTALL_SKILLS` | `true` | Whether to install skills |
| `INSTALL_BRIDGE` | `true` | Whether to download agent-bridge |
| `OUTPUT_DIR` | `.` | Output directory for bridge-only download |

## Build from Source

### Agent Bridge

```bash
# Clone main repository
git clone https://github.com/RoM4iK/tinker.git
cd tinker

# Build for current platform
go build -o agent-bridge agent-bridge.go

# Or use the build script (multi-platform)
ruby tinker-public/scripts/build-bridge.rb
```

### MCP Bridge

```bash
cd mcp-bridge
npm install
npm run build
```

## Directory Structure

```
tinker-public/
├── bin/                    # Pre-built binaries
│   ├── agent-bridge        # Linux amd64 (default)
│   ├── agent-bridge-linux-arm64
│   ├── agent-bridge-darwin-arm64
│   └── ...
├── skills/                 # Reusable skills
│   ├── git-workflow/
│   ├── worker-workflow/
│   ├── researcher-workflow/
│   └── ...
├── scripts/                # Installation scripts (Ruby)
│   ├── install.rb
│   ├── download-bridge.rb
│   └── build-bridge.rb
└── README.md
```

## Migration Guide for Existing Repositories

If you already have a Tinker setup with locally-built binaries:

1. **Stop building locally:**
   Remove any build steps that build `agent-bridge` locally.

2. **Update your installation:**
   ```bash
   ruby -e "$(curl -fsSL https://raw.githubusercontent.com/RoM4iK/tinker-public/main/scripts/install.rb)"
   ```

3. **Update your PATH:**
   Ensure the `.claude/bin` directory is in your PATH:
   ```bash
   export PATH="$PATH:$(pwd)/.claude/bin"
   ```

4. **Update your config:**
   Verify your `.claude/config.json` points to the correct binary locations.

5. **Remove old binaries:**
   Delete any locally-built binaries from your repository.

## Configuration

The installer creates `.claude/config.json` if it doesn't exist:

```json
{
  "skills": [
    ".claude/skills/*/SKILL.md"
  ],
  "mcpServers": {
    "tinker": {
      "command": "node",
      "args": ["mcp-bridge/dist/index.js"],
      "env": {
        "RAILS_URL": "http://localhost:3000",
        "TINKER_PROJECT_ID": "1"
      }
    }
  }
}
```

## Contributing

This is a distribution repository. For contributing to the core Tinker system, please see the main [tinker repository](https://github.com/RoM4iK/tinker).

To sync changes from the main tinker repo:

```bash
# In the main tinker repository
bin/sync-tinker-public        # Sync skills and scripts
bin/sync-tinker-public --push # Sync and push to GitHub
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related Repositories

- [tinker](https://github.com/RoM4iK/tinker) - Main Tinker agent system
- [tinker-public](https://github.com/RoM4iK/tinker-public) - This repository
