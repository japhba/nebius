#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
WHITELIST="${WHITELIST:-${REPO_DIR}/home-whitelist.txt}"
source "${STATE_FILE}"

KNOWN_HOSTS_FILE="${REPO_DIR}/.state/known_hosts.${NAME}"
IDENTITY_FILE="${IDENTITY_FILE:-${HOME}/.ssh/nebius}"
SSH_COMMAND="ssh -F /dev/null -i ${IDENTITY_FILE} -o IdentitiesOnly=yes -o IdentityAgent=none -o ProxyCommand=none -o HostKeyAlias=${NAME} -o UserKnownHostsFile=${KNOWN_HOSTS_FILE} -o StrictHostKeyChecking=yes"

FILES_FROM="$(mktemp)"
trap 'rm -f "${FILES_FROM}"' EXIT
grep -Ev '^[[:space:]]*($|#)' "${WHITELIST}" > "${FILES_FROM}"

"${REPO_DIR}/scripts/wait-dev-box-ready.sh" >/dev/null
rsync -az -e "${SSH_COMMAND}" --files-from="${FILES_FROM}" "${HOME}/" "${SSH_USER}@${PUBLIC_IP}:~/"
${SSH_COMMAND} "${SSH_USER}@${PUBLIC_IP}" 'sudo /usr/local/sbin/nebius-dev-refresh-shell.sh'
