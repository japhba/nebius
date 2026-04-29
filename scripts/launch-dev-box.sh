#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${REPO_DIR}/config.env}"
[ -f "${CONFIG_FILE}" ] && source "${CONFIG_FILE}"

PROJECT_ID="${PROJECT_ID:-project-e00nrkpdpr00msfn2n009m}"
NAME="${NAME:-nebius-dev}"
REGION="${REGION:-eu-north1}"
SUBNET_ID="${SUBNET_ID:-vpcsubnet-e00t46rgq3cyq57cd2}"
SSH_USER="${SSH_USER:-jbauer}"
SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-$HOME/.ssh/id_ed25519.pub}"

PLATFORM="${PLATFORM:-cpu-e2}"
PRESET="${PRESET:-2vcpu-8gb}"
BOOT_DISK_SIZE_GIB="${BOOT_DISK_SIZE_GIB:-30}"
BOOT_DISK_TYPE="${BOOT_DISK_TYPE:-network_ssd}"
HOME_FS_ID="${HOME_FS_ID:-}"
HOME_FS_SIZE_GIB="${HOME_FS_SIZE_GIB:-300}"
HOME_FS_TYPE="${HOME_FS_TYPE:-network_ssd}"
SCRATCH_FS_ID="${SCRATCH_FS_ID:-}"
SCRATCH_FS_SIZE_GIB="${SCRATCH_FS_SIZE_GIB:-1024}"
SCRATCH_FS_TYPE="${SCRATCH_FS_TYPE:-network_ssd}"

IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu24.04-driverless}"
IMAGE_PARENT_ID="${IMAGE_PARENT_ID:-project-e00public-images}"
NODE_VERSION="${NODE_VERSION:-22}"
CODEX_NPM_PACKAGE="${CODEX_NPM_PACKAGE:-@openai/codex}"
CLAUDE_NPM_PACKAGE="${CLAUDE_NPM_PACKAGE:-@anthropic-ai/claude-code}"
SYNC_AUTH="${SYNC_AUTH:-1}"
SYNC_NEBIUS_AUTH="${SYNC_NEBIUS_AUTH:-1}"

STATE_DIR="${REPO_DIR}/.state"
STATE_FILE="${STATE_DIR}/${NAME}.env"
mkdir -p "${STATE_DIR}"

if [ -e "${STATE_FILE}" ]; then
  echo "State file already exists: ${STATE_FILE}" >&2
  echo "Use scripts/ssh-dev-box.sh, scripts/start-dev-box.sh, or CONFIRM_DELETE=${NAME} scripts/delete-dev-box.sh; set NAME=... for a second box." >&2
  exit 1
fi

INSTANCE_ID=""
HOME_FS_CREATED=0
SCRATCH_FS_CREATED=0
PUBLIC_IP=""
write_state() {
  cat > "${STATE_FILE}" <<EOF
PROJECT_ID=${PROJECT_ID}
NAME=${NAME}
INSTANCE_ID=${INSTANCE_ID}
HOME_FS_ID=${HOME_FS_ID}
HOME_FS_CREATED=${HOME_FS_CREATED}
SCRATCH_FS_ID=${SCRATCH_FS_ID}
SCRATCH_FS_CREATED=${SCRATCH_FS_CREATED}
SSH_USER=${SSH_USER}
PUBLIC_IP=${PUBLIC_IP}
EOF
}

source "${HOME}/.nebius/path.bash.inc"

SSH_PUBLIC_KEY="$(<"${SSH_PUBLIC_KEY_FILE}")"

HOST_KEY_PRIV="${STATE_DIR}/${NAME}-host_ed25519_key"
HOST_KEY_PUB="${HOST_KEY_PRIV}.pub"
KNOWN_HOSTS_FILE="${STATE_DIR}/known_hosts.${NAME}"
if [ ! -f "${HOST_KEY_PRIV}" ]; then
  ssh-keygen -t ed25519 -N '' -C "${NAME}-host" -f "${HOST_KEY_PRIV}" >/dev/null
fi
HOST_KEY_PRIV_CONTENT="$(<"${HOST_KEY_PRIV}")"
HOST_KEY_PUB_CONTENT="$(<"${HOST_KEY_PUB}")"
printf '@cert-authority %s %s\n%s %s\n' \
  "${NAME}" "${HOST_KEY_PUB_CONTENT}" \
  "${NAME}" "${HOST_KEY_PUB_CONTENT}" > "${KNOWN_HOSTS_FILE}".tmp
printf '%s %s\n' "${NAME}" "${HOST_KEY_PUB_CONTENT}" > "${KNOWN_HOSTS_FILE}"
rm -f "${KNOWN_HOSTS_FILE}".tmp

HOST_KEY_PRIV_INDENTED="$(sed 's/^/      /' "${HOST_KEY_PRIV}")"

CLOUD_INIT="$(mktemp)"
trap 'rm -f "${CLOUD_INIT}"' EXIT

cat > "${CLOUD_INIT}" <<EOF
#cloud-config
ssh_keys:
  ed25519_private: |
${HOST_KEY_PRIV_INDENTED}
  ed25519_public: ${HOST_KEY_PUB_CONTENT}
users:
  - default
  - name: ${SSH_USER}
    gecos: ${SSH_USER}
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY}
package_update: true
package_upgrade: false
packages:
  - bash-completion
  - build-essential
  - bzip2
  - ca-certificates
  - curl
  - git
  - jq
  - nvme-cli
  - python3
  - python3-venv
  - rsync
  - tmux
  - unzip
write_files:
  - path: /usr/local/sbin/nebius-dev-refresh-shell.sh
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      set -euo pipefail

      user="${SSH_USER}"
      home_dir="\$(getent passwd "\${user}" | cut -d: -f6)"
      bashrc="\${home_dir}/.bashrc"
      marker_begin="# >>> nebius-dev shell setup >>>"
      marker_end="# <<< nebius-dev shell setup <<<"

      mkdir -p "\${home_dir}"
      touch "\${bashrc}"
      tmp="\$(mktemp)"
      sed "/^\${marker_begin}\$/,/^\${marker_end}\$/d" "\${bashrc}" > "\${tmp}"
      cat "\${tmp}" > "\${bashrc}"
      rm -f "\${tmp}"
      cat >> "\${bashrc}" <<'BASHRC'
      # >>> nebius-dev shell setup >>>
      export PATH="\$HOME/.local/bin:\$PATH"
      if [ -f "\$HOME/miniconda3/etc/profile.d/conda.sh" ]; then . "\$HOME/miniconda3/etc/profile.d/conda.sh"; fi
      if [ -f "\$HOME/.env" ]; then set -a; source "\$HOME/.env"; set +a; fi
      if [ -f "\$HOME/.env.nebius" ]; then set -a; source "\$HOME/.env.nebius"; set +a; fi
      # <<< nebius-dev shell setup <<<
      BASHRC
      chown "\${user}:\${user}" "\${bashrc}"

      cat > /etc/profile.d/nebius-dev.sh <<'PROFILE'
      if [ -d "\$HOME/.local/bin" ]; then export PATH="\$HOME/.local/bin:\$PATH"; fi
      if [ -f "\$HOME/.env" ]; then set -a; . "\$HOME/.env"; set +a; fi
      if [ -f "\$HOME/.env.nebius" ]; then set -a; . "\$HOME/.env.nebius"; set +a; fi
      PROFILE
  - path: /usr/local/sbin/nebius-dev-firstboot.sh
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      set -euo pipefail

      user="${SSH_USER}"
      home_tag="nebius-home"
      scratch_tag="ceph-scratch"
      nhome_root="/nfs/nhome/live"
      remote_home="\${nhome_root}/${SSH_USER}"
      scratch_root="/ceph/scratch"
      scratch_path="\${scratch_root}/${SSH_USER}"

      udevadm settle
      mkdir -p "\${nhome_root}" "\${scratch_root}"
      mountpoint -q "\${nhome_root}" || mount -t virtiofs "\${home_tag}" "\${nhome_root}"
      grep -q "^\${home_tag} " /etc/fstab || printf "%s %s virtiofs defaults,nofail 0 0\n" "\${home_tag}" "\${nhome_root}" >> /etc/fstab
      mkdir -p "\${remote_home}"
      if [ -d "/home/\${user}" ] && [ ! -L "/home/\${user}" ]; then
        rsync -a "/home/\${user}/" "\${remote_home}/"
        rm -rf "/home/\${user}"
      fi
      usermod -d "\${remote_home}" "\${user}"
      chown -R "\${user}:\${user}" "\${remote_home}"

      mountpoint -q "\${scratch_root}" || mount -t virtiofs "\${scratch_tag}" "\${scratch_root}"
      grep -q "^\${scratch_tag} " /etc/fstab || printf "%s %s virtiofs defaults,nofail 0 0\n" "\${scratch_tag}" "\${scratch_root}" >> /etc/fstab
      mkdir -p "\${scratch_path}/"{cache,hf,logs,tmp,venvs}
      chown -R "\${user}:\${user}" "\${scratch_path}"

      sudo -Hu "\${user}" bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
      sudo -Hu "\${user}" bash -lc 'mkdir -p ~/.cargo && touch ~/.cargo/env'
      sudo -Hu "\${user}" bash -lc 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
      sudo -Hu "\${user}" bash -lc 'source ~/.nvm/nvm.sh && nvm install ${NODE_VERSION} && nvm alias default ${NODE_VERSION} && npm install -g ${CODEX_NPM_PACKAGE} ${CLAUDE_NPM_PACKAGE} && mkdir -p ~/.local/bin && for tool in node npm npx codex claude; do ln -sf "\$(command -v "\$tool")" ~/.local/bin/"\$tool"; done'
      sudo -Hu "\${user}" bash -lc 'curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh && bash /tmp/miniconda.sh -b -p "\$HOME/miniconda3" && "\$HOME/miniconda3/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && "\$HOME/miniconda3/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && "\$HOME/miniconda3/bin/conda" config --set auto_activate_base false && "\$HOME/miniconda3/bin/conda" config --add channels conda-forge && "\$HOME/miniconda3/bin/conda" config --set channel_priority strict && "\$HOME/miniconda3/bin/conda" install -y -n base -c conda-forge btop nvitop && "\$HOME/miniconda3/bin/conda" clean -afy && mkdir -p ~/.local/bin && for tool in conda btop nvitop; do ln -sf "\$HOME/miniconda3/bin/\$tool" ~/.local/bin/"\$tool"; done'
      sudo -Hu "\${user}" bash -lc 'curl -fsSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash && mkdir -p ~/.local/bin && ln -sf ~/.nebius/bin/nebius ~/.local/bin/nebius'

      cat > "\${remote_home}/.env.nebius" <<ENVEOF
      CACHE_DIR=/ceph/scratch/${SSH_USER}/cache
      FAST_CACHE_DIR=/ceph/scratch/${SSH_USER}/tmp
      HF_HOME=/ceph/scratch/${SSH_USER}/hf
      HF_XET_HIGH_PERFORMANCE=1
      VENV_LOCAL=/ceph/scratch/${SSH_USER}/venvs
      ENVEOF
      chown "\${user}:\${user}" "\${remote_home}/.env.nebius"
      chmod 600 "\${remote_home}/.env.nebius"

      /usr/local/sbin/nebius-dev-refresh-shell.sh
runcmd:
  - [bash, /usr/local/sbin/nebius-dev-firstboot.sh]
EOF

if [ -z "${HOME_FS_ID}" ]; then
  echo "Creating ${HOME_FS_SIZE_GIB} GiB shared home filesystem..."
  HOME_FS_ID="$(
    nebius compute filesystem create \
      --parent-id "${PROJECT_ID}" \
      --name "${NAME}-home" \
      --size-gibibytes "${HOME_FS_SIZE_GIB}" \
      --type "${HOME_FS_TYPE}" \
      --format json | jq -r '.metadata.id'
  )"
  HOME_FS_CREATED=1
  echo "Home filesystem: ${HOME_FS_ID}"
else
  echo "Using existing shared home filesystem: ${HOME_FS_ID}"
fi
write_state

if [ -z "${SCRATCH_FS_ID}" ]; then
  echo "Creating ${SCRATCH_FS_SIZE_GIB} GiB shared scratch filesystem..."
  SCRATCH_FS_ID="$(
    nebius compute filesystem create \
      --parent-id "${PROJECT_ID}" \
      --name "${NAME}-scratch" \
      --size-gibibytes "${SCRATCH_FS_SIZE_GIB}" \
      --type "${SCRATCH_FS_TYPE}" \
      --format json | jq -r '.metadata.id'
  )"
  SCRATCH_FS_CREATED=1
  echo "Scratch filesystem: ${SCRATCH_FS_ID}"
else
  echo "Using existing shared scratch filesystem: ${SCRATCH_FS_ID}"
fi
write_state

NETWORK_INTERFACES="$(jq -nc --arg subnet "${SUBNET_ID}" '[{name:"eth0",subnet_id:$subnet,ip_address:{},public_ip_address:{}}]')"
FILESYSTEMS="$(jq -nc --arg home_id "${HOME_FS_ID}" --arg scratch_id "${SCRATCH_FS_ID}" '[{attach_mode:"read_write",mount_tag:"nebius-home",existing_filesystem:{id:$home_id}},{attach_mode:"read_write",mount_tag:"ceph-scratch",existing_filesystem:{id:$scratch_id}}]')"

echo "Creating CPU VM ${NAME}..."
INSTANCE_JSON="$(
  nebius compute instance create \
    --parent-id "${PROJECT_ID}" \
    --name "${NAME}" \
    --resources-platform "${PLATFORM}" \
    --resources-preset "${PRESET}" \
    --boot-disk-attach-mode read_write \
    --boot-disk-device-id boot \
    --boot-disk-managed-disk-name "${NAME}-boot" \
    --boot-disk-managed-disk-size-gibibytes "${BOOT_DISK_SIZE_GIB}" \
    --boot-disk-managed-disk-type "${BOOT_DISK_TYPE}" \
    --boot-disk-managed-disk-source-image-family-image-family "${IMAGE_FAMILY}" \
    --boot-disk-managed-disk-source-image-family-parent-id "${IMAGE_PARENT_ID}" \
    --network-interfaces "${NETWORK_INTERFACES}" \
    --filesystems "${FILESYSTEMS}" \
    --cloud-init-user-data "$(<"${CLOUD_INIT}")" \
    --format json
)"
INSTANCE_ID="$(jq -r '.metadata.id' <<< "${INSTANCE_JSON}")"
echo "Instance: ${INSTANCE_ID}"
write_state

echo "Waiting for public IP..."
for _ in $(seq 1 120); do
  INSTANCE_GET="$(nebius compute instance get "${INSTANCE_ID}" --format json)"
  PUBLIC_IP="$(jq -r '.. | objects | .public_ip_address? | objects | .address? // empty | split("/")[0]' <<< "${INSTANCE_GET}" | head -n 1)"
  [ -n "${PUBLIC_IP}" ] && break
  sleep 5
done
: "${PUBLIC_IP:?Nebius did not report a public IP for ${INSTANCE_ID}}"
write_state

echo "Waiting for SSH at ${SSH_USER}@${PUBLIC_IP}..."
SSH_READY=0
for _ in $(seq 1 120); do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 \
       -F /dev/null \
       -i "${SSH_PUBLIC_KEY_FILE%.pub}" \
       -o IdentitiesOnly=yes \
       -o IdentityAgent=none \
       -o ProxyCommand=none \
       -o "HostKeyAlias=${NAME}" \
       -o "UserKnownHostsFile=${KNOWN_HOSTS_FILE}" \
       -o StrictHostKeyChecking=yes \
       "${SSH_USER}@${PUBLIC_IP}" true; then
    SSH_READY=1
    break
  fi
  sleep 5
done
[ "${SSH_READY}" = "1" ]

"${REPO_DIR}/scripts/wait-dev-box-ready.sh"
"${REPO_DIR}/scripts/sync-home-whitelist.sh"

if [ "${SYNC_AUTH}" = "1" ]; then
  "${REPO_DIR}/scripts/sync-agent-auth.sh"
fi

if [ "${SYNC_NEBIUS_AUTH}" = "1" ]; then
  "${REPO_DIR}/scripts/sync-nebius-auth.sh"
fi

echo "Ready: ssh ${SSH_USER}@${PUBLIC_IP}"
