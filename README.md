# Nebius Dev Box

Provisions a single cheap Nebius CPU dev VM for remote coding/orchestration work.

- `2vcpu-8gb` CPU VM by default (~$36/month).
- 300 GiB persistent `network_ssd` block disk mounted as `/home`, so your home directory survives VM rebuilds (~$21/month).
- Nebius shared filesystem mounted as `/ceph/scratch/$USER` for caches and large data (`SCRATCH_FS_SIZE_GIB * $0.08/month`; default 1024 GiB ≈ $82/month).
- First boot installs uv, nvm/Node, Codex, Claude Code, and the Nebius CLI via cloud-init.
- Optional one-shot sync of local Codex/Claude credentials and a whitelisted set of dotfiles after the VM is reachable.

Compute stops billing when the VM is stopped. Disks and the shared filesystem bill while they exist.

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
SYNC_AUTH=0 scripts/launch-dev-box.sh   # skip copying local Codex/Claude creds to the VM
```

By default the launcher copies local Codex and Claude credentials to the VM. That is convenient but places live auth material on a cloud host — set `SYNC_AUTH=0` to skip it.

## Lifecycle

```bash
scripts/ssh-dev-box.sh                  # ssh in (resolves current public IP via Nebius CLI)
scripts/sync-home-whitelist.sh          # rsync paths listed in home-whitelist.txt to the VM
scripts/sync-agent-auth.sh              # re-sync Codex/Claude credentials
scripts/stop-dev-box.sh                 # stop billing for compute (storage still bills)
scripts/start-dev-box.sh                # restart; public IP usually changes
CONFIRM_DELETE=$NAME scripts/delete-dev-box.sh   # destroy VM + disk + shared FS
```

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

`.state/` is gitignored. It contains `${NAME}.env` (instance/disk/FS IDs and last-known IP), the host private key, and the matching `known_hosts` file. Back it up if you don't want to regenerate the host key on rebuild; otherwise treat it as ephemeral.
