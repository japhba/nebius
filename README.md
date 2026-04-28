# Nebius Dev Box

Provisions a single cheap Nebius CPU dev VM for remote coding/orchestration work.

- `2vcpu-8gb` CPU VM by default (~$36/month).
- 300 GiB shared `network_ssd` filesystem mounted as `/nfs/nhome/live`; the VM user's home is `/nfs/nhome/live/$USER`. GPU workers can mount the same filesystem at the same path and see code immediately (~$24/month).
- Separate Nebius shared filesystem mounted as `/ceph/scratch` for caches and large data (`SCRATCH_FS_SIZE_GIB * $0.08/month`; default 1024 GiB ≈ $82/month).
- First boot installs uv, nvm/Node, Codex, Claude Code, Miniconda, `tmux`, `btop`, `nvitop`, and the Nebius CLI via cloud-init.
- Optional one-shot sync of local Codex/Claude credentials, Nebius CLI credentials, and a whitelisted set of home config files after cloud-init has finished. Local `~/.env` is sourced alongside VM-specific cache defaults in `~/.env.nebius`.

Compute stops billing when the VM is stopped. Shared filesystems bill while they exist.

## Setup

Edit [config.env](config.env). It hardcodes the original author's project ID, subnet, username, and SSH key path — change at least these:

- `PROJECT_ID`, `SUBNET_ID` — your Nebius project/subnet.
- `SSH_USER` — the user to create on the VM.
- `SSH_PUBLIC_KEY_FILE` — public key authorized for that user.
- `NAME` — used for resource names and as a `HostKeyAlias`; change it if you want to run more than one box.

Make sure the Nebius CLI is installed and authenticated (`nebius compute instance list` should work).

## Launch

```bash
scripts/launch-dev-box.sh
```

Useful overrides:

```bash
PRESET=4vcpu-16gb scripts/launch-dev-box.sh
SCRATCH_FS_SIZE_GIB=4096 scripts/launch-dev-box.sh
HOME_FS_ID=computefilesystem-... scripts/launch-dev-box.sh   # reuse an existing shared home filesystem
SCRATCH_FS_ID=computefilesystem-... scripts/launch-dev-box.sh   # reuse an existing shared scratch filesystem
SYNC_AUTH=0 scripts/launch-dev-box.sh   # skip copying local Codex/Claude creds to the VM
SYNC_NEBIUS_AUTH=0 scripts/launch-dev-box.sh   # skip copying local Nebius CLI creds to the VM
```

By default the launcher copies local Codex, Claude, and Nebius CLI credentials to the VM. That is convenient for using the CPU box as a GPU-rental orchestrator, but places live auth material on a cloud host. Set `SYNC_AUTH=0` and/or `SYNC_NEBIUS_AUTH=0` to skip those copies.

The launcher writes `.state/${NAME}.env` as soon as each resource is created, so `CONFIRM_DELETE=$NAME scripts/delete-dev-box.sh` can clean up even after a partial launch failure.

## GPU workers

Attach the same `HOME_FS_ID` to GPU VMs with mount tag `nebius-home` and the same `SCRATCH_FS_ID` with mount tag `ceph-scratch`. Mount `nebius-home` at `/nfs/nhome/live` and set the user's home to `/nfs/nhome/live/$USER`; mount `ceph-scratch` at `/ceph/scratch`. With that layout, code edited on the CPU dev box appears on GPU workers immediately, while caches and model files stay on the larger scratch filesystem.

## Lifecycle

```bash
scripts/ssh-dev-box.sh                  # ssh in (resolves current public IP via Nebius CLI)
scripts/status-dev-box.sh               # show Nebius resources plus cloud-init/mount status
scripts/sync-home-whitelist.sh          # rsync paths listed in home-whitelist.txt to the VM
scripts/sync-agent-auth.sh              # re-sync Codex/Claude credentials and templates/CLAUDE.md
scripts/sync-nebius-auth.sh             # re-sync Nebius CLI credentials
scripts/stop-dev-box.sh                 # stop billing for compute (filesystems still bill)
scripts/start-dev-box.sh                # restart; public IP usually changes
CONFIRM_DELETE=$NAME scripts/delete-dev-box.sh   # destroy VM + any filesystems this launcher created
```

The sync scripts wait for `cloud-init status --wait` and verify `/nfs/nhome/live`, `/ceph/scratch`, `.cargo/env`, and `.env.nebius` before copying files. This avoids rsync protocol failures from half-initialized shell startup files.

## SSH and host keys

Public IPs rotate on every restart. To keep ssh sane across that:

- The launcher pre-generates an ed25519 host key under `.state/${NAME}-host_ed25519_key` and ships it to the VM via cloud-init `ssh_keys:`. The matching public key is written to `.state/known_hosts.${NAME}` keyed by the alias `${NAME}`.
- All scripts ssh in with `HostKeyAlias=${NAME}` and `UserKnownHostsFile=.state/known_hosts.${NAME}` under `StrictHostKeyChecking=yes`. IP changes don't trigger host-key warnings, and a wrong server is rejected outright.
- `delete-dev-box.sh` removes the host key and known_hosts file so the next launch starts clean.

To ssh from your own `~/.ssh/config` instead of the bundled script, add an entry like:

```sshconfig
Host mybox
  HostName placeholder
  User <your SSH_USER>
  IdentityFile ~/.ssh/<your key>
  IdentitiesOnly yes
  HostKeyAlias <your NAME>
  UserKnownHostsFile <absolute path to repo>/.state/known_hosts.<your NAME>
  StrictHostKeyChecking yes
  ProxyCommand sh -c 'exec nc $(<absolute path to repo>/scripts/lookup-ip.sh) %p'
```

(Or just use `scripts/ssh-dev-box.sh`.)

## State and secrets

`.state/` is gitignored. It contains `${NAME}.env` (instance/filesystem IDs and last-known IP), the host private key, and the matching `known_hosts` file. Back it up if you don't want to regenerate the host key on rebuild; otherwise treat it as ephemeral.
