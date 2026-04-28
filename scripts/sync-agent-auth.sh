#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${STATE_FILE}"

REMOTE="${SSH_USER}@${PUBLIC_IP}"

ssh "${REMOTE}" 'mkdir -p ~/.codex ~/.claude'
rsync -azL "${HOME}/.claude/CLAUDE.md" "${HOME}/.claude/settings.json" "${HOME}/.claude/.credentials.json" "${REMOTE}:~/.claude/"
rsync -azL "${HOME}/.codex/auth.json" "${HOME}/.codex/config.toml" "${REMOTE}:~/.codex/"
ssh "${REMOTE}" 'rm -f ~/.codex/AGENTS.md && ln -s ~/.claude/CLAUDE.md ~/.codex/AGENTS.md && chmod 700 ~/.codex ~/.claude && chmod 600 ~/.codex/auth.json ~/.codex/config.toml ~/.claude/.credentials.json'
