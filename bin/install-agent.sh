#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
# Handle potential clock skew in containers
echo 'Acquire::Check-Date "false";' > /etc/apt/apt.conf.d/99no-check-date

apt-get update && apt-get install -y \
    git curl tmux sudo unzip wget

# Install Node.js (required for Claude CLI)
# Check for existing Node installation
NODE_VERSION=""
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d. -f1 | tr -d 'v')
fi

if [ -n "$NODE_VERSION" ] && [ "$NODE_VERSION" -ge 18 ]; then
    echo "Node.js $NODE_VERSION is already installed."
    # Check for npm
    if ! command -v npm &> /dev/null; then
        echo "npm is missing. Installing npm..."
        apt-get install -y npm
    fi
else
    echo "Node.js not found or too old ($NODE_VERSION). Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# Setup User FIRST (before installing Claude)
# We want to run as the same UID as the host user (passed via build arg)
# to ensure we can edit mounted files.
USER_ID=${USER_ID:-1000}
GROUP_ID=${GROUP_ID:-1000}
AGENT_USER="claude"

# Allow UIDs outside the default range (e.g., macOS UIDs like 501)
if [ "$USER_ID" -lt 1000 ]; then
  sed -i 's/^UID_MIN.*/UID_MIN 100/' /etc/login.defs
  sed -i 's/^GID_MIN.*/GID_MIN 100/' /etc/login.defs
fi

# 1. Handle Group
if getent group ${GROUP_ID} >/dev/null 2>&1; then
  # Group exists (e.g. 'node'), use it
  GROUP_NAME=$(getent group ${GROUP_ID} | cut -d: -f1)
else
  # Create group
  if getent group ${AGENT_USER} >/dev/null 2>&1; then
      GROUP_NAME=${AGENT_USER}
  else
      groupadd -g ${GROUP_ID} ${AGENT_USER}
      GROUP_NAME=${AGENT_USER}
  fi
fi

# 2. Handle User
if getent passwd ${USER_ID} >/dev/null 2>&1; then
  # User exists (e.g. 'node'), use it
  AGENT_USER=$(getent passwd ${USER_ID} | cut -d: -f1)
  # Ensure user is in the group (if different)
  usermod -aG ${GROUP_NAME} ${AGENT_USER}
else
  # Create user
  useradd -u ${USER_ID} -g ${GROUP_NAME} -m -s /bin/bash ${AGENT_USER}
fi

# 3. Grant Sudo
echo "${AGENT_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 4. Determine Home Directory
AGENT_HOME=$(getent passwd ${AGENT_USER} | cut -d: -f6)

echo "Installing claude-code as ${AGENT_USER}"

# Install Claude CLI as the agent user
sudo -u ${AGENT_USER} bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

# Add agent user's local bin to system PATH
echo "export PATH=\"${AGENT_HOME}/.local/bin:\$PATH\"" >> /etc/profile.d/claude.sh
chmod +x /etc/profile.d/claude.sh

echo "Installing Github CLI"
# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list
apt-get update && apt-get install gh -y

# Create entrypoint
cat << EOF > /entrypoint.sh
#!/bin/bash
set -e

# Copy config files if they exist in /tmp (mounted volumes)
if [ -f "/tmp/cfg/claude.json" ]; then
  cp /tmp/cfg/claude.json ${AGENT_HOME}/.claude.json || echo "⚠️ Failed to copy claude.json"
fi
if [ -d "/tmp/cfg/claude_dir" ]; then
  rm -rf ${AGENT_HOME}/.claude
  cp -r /tmp/cfg/claude_dir ${AGENT_HOME}/.claude || echo "⚠️ Failed to copy claude_dir"
fi
if [ -f "/tmp/github-app-privkey.pem" ]; then
  cp /tmp/github-app-privkey.pem ${AGENT_HOME}/.github-app-privkey.pem || echo "⚠️ Failed to copy github key"
  chmod 600 ${AGENT_HOME}/.github-app-privkey.pem 2>/dev/null || true
fi

# Fix permissions of home directory
sudo chown -R ${AGENT_USER}:${GROUP_NAME} ${AGENT_HOME} || echo "⚠️ Failed to chown home"

# Fix permissions of the current directory (project root) and key subdirectories
# This ensures the agent can write CLAUDE.md, .mcp.json, and create/modify files
WORKDIR=\$(pwd)
sudo chown -R ${AGENT_USER}:${GROUP_NAME} "\${WORKDIR}" || echo "⚠️ Failed to chown workdir"

# Reset git state if .git exists
if [ -d ".git" ]; then
  echo "🧹 Resetting git state..."
  
  # Remove stale index.lock
  rm -f .git/index.lock

  git config --global --add safe.directory "\${WORKDIR}"
  
  # Reset hard to HEAD
  git reset --hard HEAD || echo "⚠️ Failed to git reset"
  
  # Ensure clean state (optional cleans ignored files too?)
  # git clean -fd || echo "⚠️ Failed to git clean"
fi

# Execute command as agent user
exec sudo -E -u ${AGENT_USER} env "HOME=${AGENT_HOME}" "\$@"
EOF

chmod +x /entrypoint.sh
