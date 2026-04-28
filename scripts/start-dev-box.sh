#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${HOME}/.nebius/path.bash.inc"
source "${STATE_FILE}"

nebius compute instance start "${INSTANCE_ID}" >/dev/null

PUBLIC_IP=""
for _ in $(seq 1 120); do
  INSTANCE_GET="$(nebius compute instance get "${INSTANCE_ID}" --format json)"
  PUBLIC_IP="$(jq -r '.. | objects | .public_ip_address? | objects | .address? // empty' <<< "${INSTANCE_GET}" | head -n 1)"
  [ -n "${PUBLIC_IP}" ] && break
  sleep 5
done
: "${PUBLIC_IP:?Nebius did not report a public IP for ${INSTANCE_ID}}"

tmp_state="$(mktemp)"
awk -v ip="${PUBLIC_IP}" 'BEGIN{done=0} /^PUBLIC_IP=/{print "PUBLIC_IP=" ip; done=1; next} {print} END{if(!done) print "PUBLIC_IP=" ip}' "${STATE_FILE}" > "${tmp_state}"
mv "${tmp_state}" "${STATE_FILE}"

echo "Ready: ssh ${SSH_USER}@${PUBLIC_IP}"
