# plans/

Planning documents for turning the declarative scaffolding in this
repo into a running K3s cluster on `nas-1`, and beyond.

Every document here uses the same five-level decomposition and the
same task-ID scheme: `P{phase}.W{workstream}.T{task}.S{subtask}`.
Cross-reference freely.

## Documents

| File | Purpose |
|------|---------|
| [`plan.md`](plan.md) | The 5-level WBS. Mission → phases → workstreams → tasks → subtasks. |
| [`design.md`](design.md) | Architecture, rationale, trade-offs, rejected alternatives. Read this to understand *why*. |
| [`implementation.md`](implementation.md) | Per-phase file edits, exact commands, expected outputs. Read this to understand *how*. |
| [`tests.md`](tests.md) | Layered verification (unit → integration → system → acceptance). Read this to understand *when you're done*. |

## Scope

- **In scope**: everything from "3 NixOS VMs exist, booted from ISO"
  to "K3s cluster healthy on bare-metal, workloads portable to GKE".
- **Out of scope**: workload code (apps running inside K8s), GKE
  billing/provisioning, day-2 ops runbooks (those live in `docs/`
  once we have them).

## Status tracker

| Phase | Status | Blocking |
|-------|--------|----------|
| P1 — NixOS on VMs | ⏳ not started | VM console access / ISO boot |
| P2 — Mesh & inventory | ⏳ not started | P1 |
| P3 — Secrets (sops-nix) | ⏳ not started | P1 (needs VM ssh host keys) |
| P4 — K3s cluster formation | ⏳ not started | P2 + P3 |
| P5 — Storage / ingress / GKE readiness | ⏳ not started | P4 |

Update this table inline as phases move to ✅.

## How to use

1. Read `plan.md` start to finish once. ~15 minutes.
2. Pick the current phase. Skim the corresponding sections of
   `design.md` and `implementation.md`.
3. Execute. Validate with `tests.md`.
4. Commit. Update the status table above.
5. If you deviate, amend these docs *before* the code — they're the
   source of truth for intent.

## Conventions

- Every non-trivial automation step becomes a Gleam subcommand under
  `scripts/` (per `AGENTS.md`'s scripting rule). Plans reference the
  specific `gleam run -m sys_scripts -- <cmd>` invocation.
- Every NixOS change lands in `nix-configs/`, NOT in ad-hoc
  `configuration.nix` files on the targets.
- Every secret flows through sops-nix once P3 lands; no passwords or
  tokens in git, ever.
