#!/usr/bin/env bash
set -euo pipefail

SRC_ENV="${SRC_ENV:-${HOME}/.env}"
[ -n "${1:-}" ]
REMOTE="${1}"
DEST_ENV="${DEST_ENV:-.env}"

tmp_remote="${DEST_ENV}.tmp.$$"
ssh "${REMOTE}" "umask 077 && cat > '${tmp_remote}' && mv '${tmp_remote}' '${DEST_ENV}'" < "${SRC_ENV}"
ssh "${REMOTE}" "chmod 600 '${DEST_ENV}'"
