#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${HOME}/.nebius/path.bash.inc"
source "${STATE_FILE}"

[ "${CONFIRM_DELETE:-}" = "${NAME}" ]

if [ -n "${HOME_DISK_ID:-}" ]; then
  echo "Old block-home state file detected (${HOME_DISK_ID}); this script only deletes the shared-home layout." >&2
  echo "Delete the old VM/disk/filesystem manually or restore the old deletion logic for this one teardown." >&2
  exit 1
fi

if [ -n "${INSTANCE_ID:-}" ]; then nebius compute instance delete "${INSTANCE_ID}"; fi
if [ "${HOME_FS_CREATED:-0}" = "1" ] && [ -n "${HOME_FS_ID:-}" ]; then nebius compute filesystem delete "${HOME_FS_ID}"; fi
if [ "${SCRATCH_FS_CREATED:-0}" = "1" ] && [ -n "${SCRATCH_FS_ID:-}" ]; then nebius compute filesystem delete "${SCRATCH_FS_ID}"; fi
rm -f "${STATE_FILE}" \
      "${REPO_DIR}/.state/${NAME}-host_ed25519_key" \
      "${REPO_DIR}/.state/${NAME}-host_ed25519_key.pub" \
      "${REPO_DIR}/.state/known_hosts.${NAME}"
