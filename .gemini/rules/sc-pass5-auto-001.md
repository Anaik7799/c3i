# SC-PASS5-AUTO-001 — Ultra-Pass-5 Auto-Execute Rule

**STAMP**: SC-PASS5-AUTO-001 (new, pass-5)
**Task**: 116450171390820012, child 116450172208432385
**ZK origin**: [zk-6e88c8749efc66d5], [zk-363b7c521ac3814c]
**Layer**: L4 System (orchestration) · fractal-transitive to L0–L7
**Priority**: P0 (blocking on pass-6+)

## 1. Purpose

Every time a new feature is implemented (>= 10 LOC touched, or new module/handler/NIF/test added, or a task is marked `completed`), the agent MUST execute the **Ultra-Pass-5 pipeline** to produce canonical deliverables and maintain fractal self-similarity across tasks.

## 2. Trigger conditions

1. User says "implement", "add feature", "ship", "evolve", "close task", "next pass".
2. `git diff --stat` shows > 10 lines changed in `lib/**`, `sub-projects/**`, or `native/**`.
3. Any `./sa-plan update <id> completed` for a P0/P1 task.
4. New file in `lib/cepaf_gleam/src/cepaf_gleam/{ui,mcp,bridge,a2ui,fractal}/**`.
5. Any STAMP violation alarm on `indrajaal/l0/const/**` that requires action.

## 3. Mandatory pipeline (fractal, max-parallel)

```
PHASE 0 — RECALL (< 8 s, parallel)
  a. sa-plan-daemon knowledge-search "<keywords>" → must return ≥ 5 holons
  b. Cite ≥ 1 holon ID in first paragraph of every output (SC-RECALL-RAG)

PHASE 1 — PLAN (< 5 s)
  a. ./sa-plan add "<title>" <P0|P1>      (parent task)
  b. For each FMEA row or planned artefact: ./sa-plan add (child, P1)
  c. Resolve TASK_ID + STAMP_SLUG = <date>-<hhmmss>-task-<id>-<feature-slug>

PHASE 2 — ACT (parallel fan-out)
  a. Code edit / evolution (Gleam, Rust, TypeScript as appropriate)
  b. gleam build && gleam test     (must stay green)
  c. Render 5 Graphviz diagrams: control/data/fractal/MSC/state-machine
  d. Capture ≥ 3 headless-chromium screenshots of live pages
  e. (Optional) Record video of 1+ user journey via ffmpeg + CDP

PHASE 3 — REPORT (parallel)
  a. Journal MD   at docs/journal/<slug>-journal.md    (10+ sections, top-of-file HTTPS link)
  b. Analysis HTML at docs/journal/<slug>-analysis.html (KPIs, tables, embedded diagrams)
  c. Slide deck HTML at docs/journal/<slug>-deck.html   (keyboard nav, ≥ 12 slides)
  d. Task links.json at docs/journal/task-<id>-links.json (every artefact)

PHASE 4 — DISSEMINATE (sequential, short)
  a. Mirror all files to sub-projects/c3i/docs/journal/ (daemon CWD)
  b. ./sa-plan ingest-docs                       (ZK)
  c. ./sa-plan send-email --to <user> --attach ...  (with HTTPS link at top)
  d. ./sa-plan sync                              (PROJECT_TODOLIST.md)

PHASE 5 — INGEST (< 20 s)
  a. Verify every URL returns HTTP 200 via curl
  b. Mark child tasks completed where applicable
  c. Log "pass-N complete" holon to ZK
```

## 4. Mandatory deliverable bundle (at minimum)

| # | Artefact | Role | Min size |
|---|---|---|---|
| 1 | `<slug>-journal.md` | Journal (10+ sections) | 15 KB |
| 2 | `<slug>-analysis.html` | Analysis HTML | 12 KB |
| 3 | `<slug>-deck.html` | Slide deck | 10 KB |
| 4 | `<slug>-control-plane.png` | Graphviz: control plane | rendered |
| 5 | `<slug>-data-plane.png` | Graphviz: data plane | rendered |
| 6 | `<slug>-fractal-impact.png` | Graphviz: L0→L7 | rendered |
| 7 | `<slug>-message-sequence.png` | Graphviz: MSC | rendered |
| 8 | `<slug>-state-machine.png` | Graphviz: state machine | rendered |
| 9 | `<slug>-dashboard-{http,https}.png` | Screenshots × 2+ | rendered |
| 10 | `task-<id>-links.json` | Dynamic link index | include all of the above |

Every artefact MUST carry a top-of-file HTTPS link:
```
https://vm-1.tail55d152.ts.net:8443/task-id/<task_id>/<filename>
```

## 5. Anti-patterns (blocking)

1. **No ZK recall** — creating a journal without citing ≥ 1 holon → BLOCK.
2. **No task ID in URLs** — emitting a link that lacks `task-id/<id>/` → BLOCK.
3. **No diagrams** — analysis HTML without embedded `<img src="...png">` → BLOCK.
4. **No email** — pipeline ends without `sa-plan send-email` → BLOCK.
5. **No ZK ingest** — pipeline ends without `sa-plan ingest-docs` → BLOCK.
6. **No sync** — PROJECT_TODOLIST.md out of date → BLOCK.
7. **Silent failures** — not reading alarms on `indrajaal/l4/sched/**` during work → BLOCK.

## 6. Evidence (pass-5 reference implementation)

- Task: `116450171390820012`
- Slug: `20260422-212140-task-116450171390820012-swarm-ignition-ultrapass5`
- Dashboard: https://vm-1.tail55d152.ts.net:8443/task-id/116450171390820012
- Holons spawned: 15 on first ingest, 3 more on continuation → 18 total this pass
- Children: 15 (6 completed during pass, 9 queued for pass-6)
- FMEA RPN delta: ≥ -1,370 (FINDING-A 900→90 alone)
- Emails sent: 2 (initial + continuation)
- Live alarm caught: job 180 `embed_refresh` hung 2h11m → lifeline reset

## 7. Cross-references

- AGENTS.md §Fractal-Layer Alignment
- GEMINI.md §SC-OBS-WIRE-001 (formerly `CLAUDE` doc reference)
- .claude/projects/AGENT_UTILIZATION_RAG_RECALL.md (SC-RECALL-RAG)
- .gemini/agents/feature-evolution-agent.md
- .gemini/agents/pass5-auto-pipeline-agent.md
- .gemini/commands/pass5-auto.md
- docs/journal/20260422-recall-rag-agent-utilization-guide.md

## 8. Enforcement

Compliance audited nightly by coverage-audit-agent. Non-compliance increments `pass5_auto_violation_counter` on `indrajaal/l0/const/violations/**`. Three violations in 24 h triggers a Guardian gate asking the operator to remediate before the next feature can ship.
