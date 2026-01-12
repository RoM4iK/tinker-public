#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
# Handle potential clock skew in containers
echo 'Acquire::Check-Date "false";' > /etc/apt/apt.conf.d/99no-check-date

apt-get update && apt-get install -y \
    git curl tmux sudo unzip wget

# Install Node.js (required for Claude CLI)
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

# Install Claude CLI
npm install -g @anthropic-ai/claude-code

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list
apt-get update && apt-get install gh -y

# Setup User
# We want to run as the same UID as the host user (passed via build arg)
# to ensure we can edit mounted files.
USER_ID=${USER_ID:-1000}
GROUP_ID=${GROUP_ID:-1000}
AGENT_USER="claude"

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

# Fix permissions
sudo chown -R ${AGENT_USER}:${GROUP_NAME} ${AGENT_HOME} || echo "⚠️ Failed to chown home"

# Fix permissions of the current directory (project root)
# This ensures the agent can write CLAUDE.md and .mcp.json
sudo chown ${AGENT_USER}:${GROUP_NAME} $(pwd) || echo "⚠️ Failed to chown project root"

# Execute command as agent user
exec sudo -E -u ${AGENT_USER} env "HOME=${AGENT_HOME}" "\$@"
EOF

chmod +x /entrypoint.sh
