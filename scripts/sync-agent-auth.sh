#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${STATE_FILE}"

REMOTE="${SSH_USER}@${PUBLIC_IP}"
KNOWN_HOSTS_FILE="${REPO_DIR}/.state/known_hosts.${NAME}"
IDENTITY_FILE="${IDENTITY_FILE:-${HOME}/.ssh/nebius}"
SSH_COMMAND="ssh -F /dev/null -i ${IDENTITY_FILE} -o IdentitiesOnly=yes -o IdentityAgent=none -o ProxyCommand=none -o HostKeyAlias=${NAME} -o UserKnownHostsFile=${KNOWN_HOSTS_FILE} -o StrictHostKeyChecking=yes"

"${REPO_DIR}/scripts/wait-dev-box-ready.sh" >/dev/null
${SSH_COMMAND} "${REMOTE}" 'mkdir -p ~/.codex ~/.claude'
rsync -azL -e "${SSH_COMMAND}" "${REPO_DIR}/templates/CLAUDE.md" "${REMOTE}:~/.claude/CLAUDE.md"
rsync -azL -e "${SSH_COMMAND}" "${HOME}/.claude/settings.json" "${HOME}/.claude/.credentials.json" "${REMOTE}:~/.claude/"
rsync -azL -e "${SSH_COMMAND}" "${HOME}/.codex/auth.json" "${HOME}/.codex/config.toml" "${REMOTE}:~/.codex/"
${SSH_COMMAND} "${REMOTE}" 'rm -f ~/.codex/AGENTS.md && ln -s ~/.claude/CLAUDE.md ~/.codex/AGENTS.md && chmod 700 ~/.codex ~/.claude && chmod 600 ~/.codex/auth.json ~/.codex/config.toml ~/.claude/.credentials.json'
