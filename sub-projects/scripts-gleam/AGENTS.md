# `sys` project agent notes

This repo lives under `C:\dev\elixir\sys`. The parent folder name is historical — the project is not necessarily Elixir-only; treat it as a polyglot workspace governed by the global rules in `~/.pi/agent/AGENTS.md`.

## Rules that apply here

- **All scripting in Gleam.** No bash / PowerShell / Python / Node scripts. See `/skill:gleam-scripting`.
- **Application code** is TypeScript + fp-ts, Gleam, or Rust — load the matching skill at task start.
- Any multi-step automation goes into `./scripts/` as a Gleam project.

## Toolchain — Nix devshell

All toolchains (Gleam 1.15, Erlang/OTP 27, Rust 1.95, Node 22, pnpm 10,
rebar3 3.27, Elixir 1.17) are provided by `./flake.nix`. pi's `bash` tool
is wired to auto-source `/mnt/c/dev/elixir/sys/.pi/shell-init.sh` on every
invocation, which puts Nix on PATH. For commands that need the full
devshell PATH, use:

```bash
nix develop --command <cmd>
# or the helper defined in shell-init.sh:
in-shell <cmd>
```

If you install direnv (`direnv allow` once), `cd` into the repo
automatically enters the devshell.

## Scripts — Gleam

All workspace automation is in `./scripts/` as a Gleam project targeting
Erlang. Entry point:

```bash
in-shell gleam run -m sys_scripts -- <command>    # doctor | fmt | test | help
```

See `scripts/README.md` for the command catalogue and how to add new ones.

## Operating notes for pi sessions

- **Inline `$VAR` expansion is broken** through pi's `bash` tool over WSL:
  assignments like `x=foo; echo $x` come back empty because the Windows
  → WSL command line loses shell-metacharacter fidelity. Always write
  commands to a shell script file (one-shots under `.pi/bootstrap/`,
  committed automation under `scripts/`) and invoke via `bash <path>`.
- **Stdout is not captured** reliably through the same layer; redirect
  to a file and read it back:
  ```bash
  some-command > /mnt/c/dev/elixir/sys/.pi/last-output.txt 2>&1
  ```
  Then use the `read` tool on the file.
- `.pi/bootstrap/` contains one-shot bash scripts that installed Nix and
  scaffolded `scripts/`. They are gitignored; everything beyond bootstrap
  must be Gleam.

## Repo layout

```
sys/
  flake.nix / flake.lock     # Nix devshell (see below)
  .envrc                     # direnv: `use flake`
  AGENTS.md                  # this file
  docs/                      # prose: plans, inventories, design notes
  nix-configs/               # declarative NixOS configs for hosts/VMs
    hosts/ k3s/ modules/
  Cargo.toml / Cargo.lock    # Rust workspace
  crates/                    # Rust app code
    sysctl/                  # placeholder CLI (thiserror + clap + proptest)
  rust-toolchain.toml        # pins stable + clippy/rustfmt/rust-analyzer
  scripts/                   # Gleam automation (ALL shell-type work)
  .pi/                       # pi-agent project config
    settings.json  shell-init.sh
    skills/                  # 8 project-scoped skills (auto-loaded)
    bootstrap/*.sh           # one-shot setup scripts (gitignored logs)
```

Per-area READMEs: [`docs/`](docs/README.md),
[`nix-configs/`](nix-configs/README.md),
[`scripts/`](scripts/README.md),
[`.pi/skills/`](.pi/skills/).

## Git remote

The repo has a **local bare remote** at `/root/git/sys.git` inside WSL,
registered as `origin`. This gives us `git push` with zero network
assumptions. Swap to a real remote with:

```bash
git remote set-url origin git@github.com:<you>/sys.git
git push -u origin main            # first push
# after this, pushes go to GitHub; the local bare stays unused but
# remains a valid backup (re-wire as `local` if you want both).
```

The bare repo's contents are the canonical history; nothing in
`/root/git/sys.git` is derived state we need to preserve beyond the
packed git objects.

## Env so far

- Host: Windows 10/11 + WSL2 Ubuntu 22.04 LTS (distro name `Ubuntu-22.04`,
  default).
- pi `shellPath`: `C:\Windows\System32\bash.exe` (global
  `~/.pi/agent/settings.json`).
- pi `shellCommandPrefix`: `source /mnt/c/dev/elixir/sys/.pi/shell-init.sh`
  (project `.pi/settings.json`).
- Running as `root` inside WSL.
