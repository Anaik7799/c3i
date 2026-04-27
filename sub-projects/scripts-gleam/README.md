# sys

Polyglot workspace managed declaratively with **Nix**, with all system
automation written in **Gleam**. Application code lives in Gleam, Rust,
or TypeScript subprojects under their respective trees.

| Tree | Language | Purpose |
|------|----------|---------|
| [`scripts/`](scripts/) | Gleam | ALL workspace automation (build, test, fmt, deploy, …). Entry point: `gleam run -m sys_scripts -- <cmd>`. |
| [`crates/`](crates/) | Rust | Rust applications/CLIs. Workspace at root `Cargo.toml`, lints in `[workspace.lints]`. |
| [`nix-configs/`](nix-configs/) | Nix | Declarative NixOS configurations for hosts & K3s nodes. Exposed as `nixosConfigurations.<name>` in `flake.nix`. |
| [`docs/`](docs/) | Markdown | Long-form plans, inventories, design notes. |
| [`.pi/`](.pi/) | (config) | pi-agent project config: settings, shell wiring, 8 skills. |

## Quick start

This repo targets **WSL2 Ubuntu 22.04 LTS** with **Nix** as the only
required host tool. From a fresh clone:

```bash
# 1. direnv is already hooked (see AGENTS.md); it auto-enters the devshell.
#    If you don't use direnv, run it manually:
nix develop

# 2. Smoke-test the toolchain
gleam run -m sys_scripts -- doctor

# 3. Run every test suite (Gleam + Rust, auto-detected)
gleam run -m sys_scripts -- test

# 4. Preview a NixOS host deployment (evaluation only, no build)
gleam run -m sys_scripts -- deploy plan nixos nix-k8s-master
```

## Toolchain

Pinned by [`flake.nix`](flake.nix) + [`rust-toolchain.toml`](rust-toolchain.toml):

| Tool | Version |
|------|---------|
| Gleam | 1.15.4 |
| Erlang/OTP | 27 |
| Rust | stable (1.95+) |
| Node | 22 LTS |
| pnpm | 10 |
| rebar3 | 3.27 |
| Nix | 2.34 |

Everything else (direnv, ripgrep, fd, just, jq, kubectl via NixOS
guests) is pulled from the same flake lock.

## Rules of engagement

This repo is governed by `AGENTS.md` — see it for the full set. TL;DR:

- **All scripting is Gleam.** No bash / PowerShell / Python / Node
  scripts committed beyond the one-shot `.pi/bootstrap/*.sh` files
  that installed Nix in the first place (chicken-and-egg). Anything
  new goes in `scripts/` as a Gleam subcommand.
- **No panics, no nulls, no `any`.** Use `Option`/`Result`/`Either`
  per language. Rust workspace denies `unwrap_used`/`expect_used`/
  `panic` in library code.
- **Pure core, effectful shell.** IO lives at the edges; domains are
  referentially transparent. Property tests (`qcheck`, `proptest`)
  for every pure module.

## Status & roadmap

| Area | State | Next |
|------|-------|------|
| Nix devshell | ✅ | — |
| `gleam run -m sys_scripts -- doctor / fmt / test / deploy` | ✅ | more subcommands as they're needed |
| NixOS modules (base + k3s server/agent) + 3 host configs | ✅ eval-clean | Phase 1: `hardware-configuration.nix` + real SSH keys |
| `sysctl` Rust CLI | ✅ placeholder | real subcommands (e.g. `sysctl skills list`) |
| K3s cluster on nas-1 | ⏳ design done | Phase 1 VM install |
| GKE migration | ⏳ | Phase 4 (see [`docs/nixos-k8s-plan.md`](docs/nixos-k8s-plan.md)) |

## Git

Currently pushed to a **local bare repo** at `/root/git/sys.git`
(inside WSL). Swap to a real remote whenever:

```bash
git remote set-url origin git@github.com:<you>/sys.git
git push -u origin main
```

## Further reading

- [`AGENTS.md`](AGENTS.md) — rules, layout, runtime quirks (for AI agents and humans)
- [`docs/`](docs/) — design docs and hardware inventory
- [`scripts/README.md`](scripts/README.md) — how to add a new automation command
- [`.pi/skills/README.md`](.pi/skills/README.md) — installed skills + authoring workflow
