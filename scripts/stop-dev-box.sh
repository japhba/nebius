#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${HOME}/.nebius/path.bash.inc"
source "${STATE_FILE}"

nebius compute instance stop "${INSTANCE_ID}"
