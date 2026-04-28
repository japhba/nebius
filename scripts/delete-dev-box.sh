#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${HOME}/.nebius/path.bash.inc"
source "${STATE_FILE}"

[ "${CONFIRM_DELETE:-}" = "${NAME}" ]

nebius compute instance delete "${INSTANCE_ID}"
nebius compute disk delete "${HOME_DISK_ID}"
nebius compute filesystem delete "${SCRATCH_FS_ID}"
rm -f "${STATE_FILE}" \
      "${REPO_DIR}/.state/${NAME}-host_ed25519_key" \
      "${REPO_DIR}/.state/${NAME}-host_ed25519_key.pub" \
      "${REPO_DIR}/.state/known_hosts.${NAME}"
