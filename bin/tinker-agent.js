#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');

const launcherPath = path.join(__dirname, '..', 'run-tinker-agent.rb');
const result = spawnSync('ruby', [launcherPath, ...process.argv.slice(2)], {
  stdio: 'inherit',
  cwd: process.cwd()
});

process.exit(result.status || 0);
