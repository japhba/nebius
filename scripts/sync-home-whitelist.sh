#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
WHITELIST="${WHITELIST:-${REPO_DIR}/home-whitelist.txt}"
source "${STATE_FILE}"

FILES_FROM="$(mktemp)"
trap 'rm -f "${FILES_FROM}"' EXIT
grep -Ev '^[[:space:]]*($|#)' "${WHITELIST}" > "${FILES_FROM}"

rsync -az --files-from="${FILES_FROM}" "${HOME}/" "${SSH_USER}@${PUBLIC_IP}:~/"
