#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${HOME}/.nebius/path.bash.inc"
source "${STATE_FILE}"

echo "Nebius resources:"
nebius compute instance get "${INSTANCE_ID}" --format json | jq -r '[.metadata.name,.metadata.id,.status.state,.spec.resources.platform,.spec.resources.preset,(.. | objects | .public_ip_address? | objects | .address? // empty)] | @tsv'
if [ -n "${HOME_FS_ID:-}" ]; then nebius compute filesystem get "${HOME_FS_ID}" --format json | jq -r '[.metadata.name,.metadata.id,.status.state,.spec.size_gibibytes,.spec.type] | @tsv'; fi
if [ -n "${SCRATCH_FS_ID:-}" ]; then nebius compute filesystem get "${SCRATCH_FS_ID}" --format json | jq -r '[.metadata.name,.metadata.id,.status.state,.spec.size_gibibytes,.spec.type] | @tsv'; fi

echo
echo "Remote readiness:"
"${REPO_DIR}/scripts/ssh-dev-box.sh" '
  set -euo pipefail
  hostname
  cloud-init status --long
  getent passwd "${USER}"
  df -h "${HOME}" /ceph/scratch
'
