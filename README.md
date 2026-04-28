# Nebius Dev Box

This repo provisions a cheap Nebius CPU dev box for code/orchestration:

- `2vcpu-8gb` CPU VM by default.
- 300 GiB persistent `network_ssd` block disk mounted as `/home`.
- Nebius shared filesystem mounted as `/ceph/scratch/jbauer`.
- Codex, Claude Code, Node, uv, git, tmux, rsync, and the Nebius CLI installed by cloud-init.
- Optional local Codex/Claude credential sync after the VM is reachable.
- Whitelisted home-folder sync from this machine via `home-whitelist.txt`; by default this syncs `.gitconfig` and `loracles/`.

The scripts are intended to be public-safe. Generated state and copied credentials are ignored by git.

## Cost Shape

Default always-on monthly cost is roughly:

- CPU VM `2vcpu-8gb`: about `$36/month`.
- Home disk 300 GiB `network_ssd`: about `$21/month`.
- Shared filesystem: `SCRATCH_FS_SIZE_GIB * $0.08/month`.

The default shared filesystem size is 1024 GiB, about `$82/month`. Set `SCRATCH_FS_SIZE_GIB=4096` if you want the shared filesystem to start at the 4 TiB performance scaling unit.

Compute stops billing when the VM is stopped. Disks and shared filesystems bill while they exist.

## Launch

Edit [config.env](config.env) first. It contains the project, VM size, disk sizes, and auth-sync default.

```bash
cd ~/nebius
scripts/launch-dev-box.sh
```

Useful overrides:

```bash
PRESET=4vcpu-16gb scripts/launch-dev-box.sh
SCRATCH_FS_SIZE_GIB=4096 scripts/launch-dev-box.sh
SYNC_AUTH=0 scripts/launch-dev-box.sh
```

After launch:

```bash
scripts/ssh-dev-box.sh
scripts/sync-home-whitelist.sh
scripts/sync-agent-auth.sh
scripts/sync-env-file.sh jbauer@u435d.id.gatsby.ucl.ac.uk
scripts/stop-dev-box.sh
scripts/start-dev-box.sh
```

By default, launch copies local Codex and Claude credentials to the VM. That is convenient, but it also places live auth material on the Nebius host. Set `SYNC_AUTH=0` to skip that step.

For clusters that do not accept SSH `SendEnv`, sync a private env file into the remote home directory:

```bash
SRC_ENV=~/.config/secrets/remote.env scripts/sync-env-file.sh jbauer@u435d.id.gatsby.ucl.ac.uk
```

On the Gatsby cluster this lands in NFS `~/.env`, so other nodes see the same file. Start tools from a shell that sources it:

```bash
set -a; source ~/.env; set +a
codex
```

To delete the VM plus the two persistent storage resources created by the launcher:

```bash
CONFIRM_DELETE=nebius-dev scripts/delete-dev-box.sh
```

## GitHub

This local directory is initialized as a git repo, but the scripts do not push automatically.

To create the public GitHub repo and push after reviewing the files:

```bash
gh repo create japhba/nebius --public --source ~/nebius --remote origin
git -C ~/nebius push -u origin main
```
