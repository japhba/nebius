#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${STATE_FILE:-${REPO_DIR}/.state/nebius-dev.env}"
source "${HOME}/.nebius/path.bash.inc"
source "${STATE_FILE}"

PUBLIC_IP="$(
  nebius compute instance get "${INSTANCE_ID}" --format json \
    | jq -r '.. | objects | .public_ip_address? | objects | .address? // empty | split("/")[0]' \
    | head -n 1
)"
: "${PUBLIC_IP:?Nebius did not report a public IP for ${INSTANCE_ID}}"

if ! grep -q "^PUBLIC_IP=${PUBLIC_IP}$" "${STATE_FILE}"; then
  tmp_state="$(mktemp)"
  awk -v ip="${PUBLIC_IP}" 'BEGIN{done=0} /^PUBLIC_IP=/{print "PUBLIC_IP=" ip; done=1; next} {print} END{if(!done) print "PUBLIC_IP=" ip}' "${STATE_FILE}" > "${tmp_state}"
  mv "${tmp_state}" "${STATE_FILE}"
fi

KNOWN_HOSTS_FILE="${REPO_DIR}/.state/known_hosts.${NAME}"
IDENTITY_FILE="${IDENTITY_FILE:-${HOME}/.ssh/nebius}"
exec ssh \
  -i "${IDENTITY_FILE}" \
  -o IdentitiesOnly=yes \
  -o "HostKeyAlias=${NAME}" \
  -o "UserKnownHostsFile=${KNOWN_HOSTS_FILE}" \
  -o StrictHostKeyChecking=yes \
  "${SSH_USER}@${PUBLIC_IP}" "$@"
