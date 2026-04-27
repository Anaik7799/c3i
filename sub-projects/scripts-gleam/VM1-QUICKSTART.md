# VM1 Quick Start — sys commands on vm-1

This directory has the full `sys` workspace capabilities replicated from
WSL. Structure differs (Gleam at root, not under `scripts/`), but all
commands work.

## Running commands

Source Nix, then use `nix develop --command`:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix.sh
cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam/scripts
nix develop ../ --command gleam run -m sys_scripts -- doctor
```

**Commands**: doctor, fmt, test, deploy, check, inventory, secrets, help

**Skills** (8 total under `.pi/skills/`): use `/skill:<name>` in pi

- fp-refactor, hyper-mgmt, nix-lang-master, nixos-architect,
  nixos-k8s, nixpkgs-contributor, pi-mono-agent, podman-master

**Plans**: see `plans/*.md` for 5-level deployment breakdown.

## Quick verification

```bash
nix develop ../ --command gleam run -m sys_scripts -- doctor
# Expect: 10/10 toolchains OK

nix develop ../ --command gleam run -m sys_scripts -- inventory list
# Expect: JSON with 3 hosts + 2 hypervisors
```

## Note on `sys check` / `sys test`

These expect `Cargo.toml` + `scripts/gleam.toml` (WSL layout). On
vm-1, run checks manually:

```bash
gleam format --check src test
gleam test
```

Full environment documented in `README.md` + `AGENTS.md`.
