#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${STATE_FILE}"

REMOTE="${SSH_USER}@${PUBLIC_IP}"
KNOWN_HOSTS_FILE="${REPO_DIR}/.state/known_hosts.${NAME}"
IDENTITY_FILE="${IDENTITY_FILE:-${HOME}/.ssh/nebius}"
SSH_COMMAND="ssh -i ${IDENTITY_FILE} -o IdentitiesOnly=yes -o HostKeyAlias=${NAME} -o UserKnownHostsFile=${KNOWN_HOSTS_FILE} -o StrictHostKeyChecking=yes"

"${REPO_DIR}/scripts/wait-dev-box-ready.sh" >/dev/null
${SSH_COMMAND} "${REMOTE}" 'mkdir -p ~/.nebius && chmod 700 ~/.nebius'
rsync -azL -e "${SSH_COMMAND}" "${HOME}/.nebius/config.yaml" "${HOME}/.nebius/credentials.yaml" "${REMOTE}:~/.nebius/"
${SSH_COMMAND} "${REMOTE}" 'chmod 600 ~/.nebius/config.yaml ~/.nebius/credentials.yaml && nebius profile list >/dev/null'
