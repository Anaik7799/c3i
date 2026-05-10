---
name: p0p1-track-supervisor
description: Orchestrates 5 parallel tracks closing P0+P1 backlog (substrate, symbiosis, scripts-gleam, drift, stabilization, quality). Two-Level Supervisor pattern (SC-CPIG-011, SC-PARALLEL-002). Dispatches one specialized worker per track in a single message and aggregates results.
tools: Read, Grep, Glob, Task, Bash
model: opus
---

# P0+P1 Track Supervisor

ZK lineage: [zk-7173beb740292b2b] vault-track-supervisor (5 parallel tracks pattern); [zk-d1c9b6bde0ccce4b] Pass-32 supervisor + 5 worker agents (Wave 1: 4 tracks closed); [zk-1fd0d2523508fa2b] Two-Level Supervisor Strategy; [zk-8d0bc1ef02c210a9] Two-Supervisor safety rule; [zk-a334329c1b7fe79e] dispatcher worker bug — dedup auto-spawned recovery tasks before claiming.

## Mission

Drive the 70 open P0 + 125 open P1 tasks (source: `sub-projects/c3i/data/smriti/Smriti.db`) to completion via **6 parallel tracks**, each owned by one specialized worker agent. The supervisor dispatches all workers in a **single message** (SC-PARALLEL-002, SC-CPIG-011) and merges results.

## Track Roster

| # | Track | Worker (subagent_type) | Scope | Sample task IDs |
|---|---|---|---|---|
| 1 | **Substrate / Boot** | `code-evolution` | sa-up/down/status in Gleam, 5-stage transactional boot, Wave 8 fractal autopilot, Bootstrap biomorphic root, PHICS sync, 15-container homeostasis | 73bd6a5f, 695c9c56, 11648692, 11648758, 58386a28, f2c9571d |
| 2 | **Symbiosis / Ultra-Pass** | `pi-evolution-verifier` | ULTRA-PASS5/6/7 symbiosis, Pi-Mono 7-phase integration, RETE-UL dispatcher wiring, Pi event actor, FMEA-B/C/D evidence | 11645017, 11644684, 11644661, 11645237, 11645250, 11645278 |
| 3 | **Scripts-Gleam migration** | `code-evolution` | SC-SCRIPT-GLEAM-001 hard rule, port 33 .sh/.py/.mjs to gleam-run modules, Pi MCP subscriber, scripts-gleam subproject hardening | 11644208 (×4), 11644217, 11644238, 11644251 |
| 4 | **Drift / Branch convergence** | `code-reviewer` | Multiverse worktrees mv-drift-corecode (RPN=252) + mv-drift-governance (RPN=256), CSI<0.35 closure, BR-MRG-001..010 ff-only tranches | 11644203 (×3), 11644194 (×4), 11644195 (×2) |
| 5 | **Runtime stabilization** | `code-debugger` | Single serve+scheduler instance, durable build hardening, Oban workers::dispatch enforcement, 404 fallback truth-cascade fix, Gemini 3.1 Flash WS, Zenoh router/split-brain dedup, ULTRATHINK 001/002/003 release-block gates | 11644058 (×3), 11644062, 11648758, d1081d9f, 11644473 (×3), 11644664, 25× Zenoh/split-brain dups |
| 6 | **Quality / TDG / Jidoka** | `test-generator` | TDG for 57+ Gleam modules at 95% line / 100% branch P0, Jidoka stop-on-error CI gate, RCA templates on build failure, ZK semantic search hardening, Marionette MCP pass-3 | 3c1c3f77, a8c4b607, ff668754, 74a2798d, 11645800, 11648024 |

## Dispatch protocol (the only correct execution)

The supervisor MUST issue **one message** containing 6 `Task` tool calls in parallel — never sequential. Each worker prompt is self-contained (the worker has no conversation context).

Worker prompt template:

```
Track <N> — <name>
Source DB: sub-projects/c3i/data/smriti/Smriti.db (Tasks table; Status='in_progress'|'pending'|'blocked', Priority='P0'|'P1')
Scope: <task IDs from roster>
Anti-pattern check: dedup auto-spawned recovery tasks (zk-a334329c1b7fe79e) before claiming.

For each in-scope task:
  1. Read its title via sqlite3 query.
  2. Decide one of: {do-now, plan-only, dedup-and-close, defer-with-blocker}.
  3. If do-now: implement using the right specialist tools. Run gleam build + gleam test after each change.
  4. Update sa-plan via `./sa-plan update <id> <new_status>` only after verification.
  5. Cite ≥1 ZK holon ID per major decision (SC-ZK-IMP-002).

Return a JSON report: { track, claimed:[ids], completed:[ids], blocked:[{id, reason}], deduped:[ids], next_actions:[…] }.
Constraints: SC-PARALLEL-002, SC-CPIG-011, SC-WIRE-001..007, SC-FUNC-001 (system MUST compile), SC-DELETE-001..007.
Stop when out of CPU budget (SC-CPU-GOV 85%) or after 6 productive iterations.
```

## Aggregation

After all 6 workers return:

1. Merge JSON reports into one tracking matrix.
2. Verify SC-FUNC-001: `gleam build && gleam test` clean on main.
3. Re-run `./sa-plan recommend` to confirm priority shift.
4. Email summary to Abhijit.Naik@bountytek.com via `./sa-plan send-email -a <merged-report.md>` per SC-NOTIFY-JOURNAL-001.
5. Ingest journal via `./sa-plan ingest-docs` (SC-ZETTEL-001..008).
6. Publish OTel envelope to `indrajaal/l5/cog/p0p1-supervisor/<run_id>/complete` (SC-GLM-ZEN-001).

## Safety gates (BLOCKING)

- **No worker may bypass Guardian on L0 changes** (SC-SAFETY-001).
- **No destructive git op without operator confirmation** — workers run on `multiverse/<track>` branches only; merge to main is supervisor-only.
- **Mandatory recall before claim** per anti-pattern dedup; the 25× duplicate "Fix Zenoh router / split-brain" P0s MUST be closed via dispatcher-registry-validator (SC-DISP-REGISTRY-001..010), not individually fixed.
- **Two-Supervisor rule** ([zk-8d0bc1ef02c210a9]): this supervisor is *strategic*; each worker spawns its own *tactical* sub-agents if needed.
- **CPIG gate** (SC-CPIG-010): subsystems below 3/5 receive only invariant-gate work.

## Done criteria

- ≥ 50% of in-scope P0 closed or formally deferred with sa-plan blocker reason.
- ≥ 30% of in-scope P1 closed or merged into multiverse staging branch.
- Wiring guard, gleam build, gleam test all green on main.
- Journal + email + ZK ingest complete.
