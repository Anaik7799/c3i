# Project skills

Skills scoped to this workspace. pi auto-discovers `SKILL.md` files in
every immediate subdirectory and exposes them as `/skill:<name>`.

## Current skills

| Skill | Scope |
|-------|-------|
| `fp-refactor` | TypeScript → fp-ts refactoring patterns |
| `hyper-mgmt` | XCP-ng (XAPI/xe) + Proxmox (qm/pct/pvesm) workflows |
| `nix-lang-master` | Nix expression language patterns |
| `nixos-architect` | NixOS system design (modules, secrets, lifecycle) |
| `nixos-k8s` | Declarative K3s/K8s on NixOS |
| `nixpkgs-contributor` | Contributing to Nixpkgs (packaging, PR standards) |
| `pi-mono-agent` | Extending pi (settings, extensions, templates, themes) |
| `podman-master` | Podman pods, play/generate kube, rootless, v5.7 API |

## Authoring a new skill

Use [`skillfish`](https://skill.fish), already wired into the devshell
via `package.json`:

```bash
# one-shot skill scaffolder (interactive)
pnpm exec skillfish init

# move the generated skill directory into .pi/skills/
mv new-skill/ .pi/skills/new-skill/
```

Then edit `.pi/skills/new-skill/SKILL.md` — the front-matter `name` and
`description` are what pi surfaces when deciding when to load the skill.

## Installing third-party skills

```bash
# skillfish drops into .claude/ by default; check, then relocate:
pnpm exec skillfish search <query>
pnpm exec skillfish add owner/repo
mv .claude/skills/<name> .pi/skills/<name>
rm -rf .claude  # pi doesn't use .claude
git add .pi/skills/<name>
```

(A proper Gleam wrapper around skillfish → `.pi/skills/` is possible
but intentionally skipped — the 3 commands above are short and the
skillfish tool is stable.)

## Not used

We do **not** use skillfish's `bundle`/`install` manifest flow. These
skills are tracked directly in git under `.pi/skills/`; that IS the
source of truth. Reproducibility comes from git, not `skillfish.json`.
