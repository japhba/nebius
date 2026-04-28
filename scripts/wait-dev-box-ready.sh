#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${REPO_DIR}/scripts/ssh-dev-box.sh" '
  set -euo pipefail
  cloud-init status --wait
  test "${HOME}" = "/nfs/nhome/live/${USER}"
  mountpoint -q /nfs/nhome/live
  mountpoint -q /ceph/scratch
  test -f "${HOME}/.cargo/env"
  test -f "${HOME}/.env.nebius"
'
