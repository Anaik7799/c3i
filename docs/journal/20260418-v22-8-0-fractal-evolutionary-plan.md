# Full Fractal Evolutionary Plan — C3I v22.8.0

## Context
Session produced 36 commits, 36 agents, 6403 tests (0 failures), 126 RETE-UL rules, 7179 holons (100% embedded). 49 original tasks completed, 65 evolutionary tasks pending. System is live (all APIs GREEN). This plan organizes ALL remaining work as a fractal tree mapped to L0-L7 layers, identifies every holon to evolve, and defines neuromorphic/control/dataflow path updates.

## Fractal Task Tree (65 tasks × 8 layers)

### L0 CONSTITUTIONAL (Safety-Critical — 8 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| CA1/e9314a51 | Emergency Stop button (cockpit, immune, dashboard) | P1 | l0_constitutional.gleam |
| CA7/be0bf63c | Guardian approval UI (bicameral, immune) | P1 | l0_constitutional.gleam |
| OP-1 | Risk-adaptive oversight per endpoint | P1 | request_guard.gleam |
| OP-3 | ZK content integrity (hash verify before injection) | P2 | zk_recall.rs |
| GR-059..063 | SIL-4 STAMP rules runtime evaluation | P1 | guard_rules.gleam |
| SERBAN-1 | Probabilistic shield for guard_grid OODA | P2 | guard_grid.gleam |
| OP-2 | Extension manifest signing (ed25519) | P2 | agents/skill_loader.gleam |
| bed3b86c | IEC 61508 SIL-4 evidence package completion | DONE | iec61508.gleam |

### L1 ATOMIC/DEBUG (Telemetry — 4 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| 164fa36f | Wire NIF into Telemetry SSR + /ws/telemetry | P2 | lustre/telemetry.gleam |
| DB4/4c98d0a8 | NIF call latency display on telemetry page | P2 | lustre/telemetry.gleam |
| MO2/ad8357bc | OTel span viewer on telemetry page | P2 | wisp/telemetry_api.gleam |
| 87e2ee68 | Wire live BEAM scheduler metrics | P2 | lustre/metabolic.gleam |

### L2 COMPONENT (UI Components — 3 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| 5e54acd6 | Wire NIF into MCP SSR + /ws/mcp | P2 | lustre/mcp.gleam |
| 7bee0f96 | Wire NIF into KMS SSR + /ws/kms | P2 | lustre/kms.gleam |
| 6c19c7bc | Wire NIF into ComponentDemo SSR | P3 | lustre/component_demo.gleam |

### L3 TRANSACTION (Planning/State — 8 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| CA4/6306f14e | Task create/update forms via NIF plan_add/update | P1 | lustre/planning.gleam |
| c9fe6bed | Wire NIF into Knowledge SSR + /ws/knowledge | P1 | lustre/knowledge.gleam |
| 60cc4a23 | Wire NIF into Smriti SSR + /ws/smriti | P2 | lustre/smriti.gleam |
| 05f73af0 | Wire NIF into Substrate SSR + /ws/substrate | P2 | lustre/substrate.gleam |
| D5f6a5d3 | ZK search bar on knowledge + smriti pages | P2 | wisp/knowledge_api.gleam |
| 5106b7f4 | Wire NIF into Database SSR + /ws/database | P3 | lustre/database.gleam |
| CE2 | Wire claude_metrics into Stop hook | P1 | settings.json + session_summary.rs |
| CE3 | /api/v1/claude/session endpoint | DONE | router.gleam |

### L4 SYSTEM (Containers/Infrastructure — 8 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| CA2/5e3c05dd | Container restart/stop buttons on podman page | P1 | lustre/podman.gleam |
| CA3/9dca0739 | Hot Reload button on dashboard + config | P1 | lustre/app.gleam |
| a2daa297 | Wire NIF into Podman SSR + /ws/podman | P2 | lustre/podman.gleam |
| 844c2dbc | Wire NIF into Metabolic SSR + /ws/metabolic | P2 | lustre/metabolic.gleam |
| dfb8aebb | Wire NIF into Config SSR + /ws/config | P3 | lustre/config.gleam |
| 6d05e939 | Wire NIF into Git SSR + /ws/git | P3 | lustre/git.gleam |
| OP-5 | sa-plan-daemon cron (6h autonomous OODA) | P2 | main.rs |
| CE4 | sa-plan-daemon claude-stats subcommand | P2 | main.rs |

### L5 COGNITIVE (OODA/Agents — 10 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| 8661297a | Wire NIF into Agents SSR + /ws/agents | P1 | lustre/agents.gleam |
| cdd7f5dd | Wire NIF into Prajna SSR + /ws/prajna | P2 | lustre/prajna.gleam |
| CC6c4fa0 | Manual OODA cycle trigger on cockpit | P2 | lustre/cockpit_view.gleam |
| CA8/3e703a4d | Dark Cockpit mode override switch | P2 | lustre/cockpit_view.gleam |
| 7cf79314 | Alarm acknowledge/dismiss on cockpit | P2 | lustre/cockpit_view.gleam |
| DB3/2d116a22 | OODA cycle trace viewer on agents + prajna | P2 | lustre/agents.gleam |
| CE1 | Wire claude_metrics into SessionStart hook | DONE | settings.json |
| CE5 | Claude context budget tracker | P2 | claude_metrics.gleam |
| CE6 | Autonomous OODA cron scheduler | P2 | session_summary.rs |
| RETE2 | AOR behavioral rules as GRL (15 rules) | P1 | guard_rules.gleam |

### L6 ECOSYSTEM (Mesh/Zenoh — 7 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| fc8763c5 | Wire NIF into Zenoh SSR + /ws/zenoh | P1 | lustre/zenoh_mesh.gleam |
| a3cf5523 | Wire NIF into Bridge SSR + /ws/bridge | P2 | lustre/bridge.gleam |
| 99e96865 | Zenoh topic publish form on zenoh page | P2 | lustre/zenoh_mesh.gleam |
| DB5/86b828eb | Zenoh message inspector live feed | P2 | wisp/zenoh_api.gleam |
| MO1/1b99d173 | Generic /ws/{page} WebSocket handler | P1 | web/server.gleam |
| RETE4 | Ruliology visualization on health-grid | P2 | lustre/health_grid.gleam |
| SERBAN-2 | ML uncertainty buffering for NIF outputs | P3 | ha/health_derivative.gleam |

### L7 FEDERATION (Multi-node — 10 tasks)
| ID | Task | Priority | Holon |
|----|------|----------|-------|
| e3fee326 | Wire NIF into Immune SSR + /ws/immune | P1 | lustre/immune.gleam |
| 90c07f41 | Wire NIF into Verification SSR + /ws/verification | P1 | lustre/verification.gleam |
| e3f4b5dc | Wire NIF into Federation SSR + /ws/federation | P2 | lustre/federation.gleam |
| 519badcd | Wire NIF into HealthGrid SSR + /ws/health-grid | P2 | lustre/health_grid.gleam |
| DB2/13164cb9 | Guard grid 24-cell drill-down | P2 | lustre/health_grid.gleam |
| MO3/80076e18 | Health cascade tree visualization | P2 | lustre/health_grid.gleam |
| f07a2380..6c19c7bc | Remaining 7 P3 SSR views (Holon, Evolution, etc.) | P3 | lustre/*.gleam |
| RETE3 | FMEA failure modes as runtime GRL facts | P2 | guard_rules.gleam |
| RETE5 | Wolfram CA for STAMP/AOR state transitions | P3 | guard_grid.gleam |
| CE7 | /api/v1/system/snapshot unified state | DONE | router.gleam |

## Holons to Evolve (by subsystem)

### Gleam Source Holons (44 files to modify)
| Holon | Current LOC | Evolution Needed |
|-------|------------|-----------------|
| `ui/wisp/router.gleam` | 2649 | +POST planning, +control action endpoints |
| `ui/web/page_views.gleam` | 3671 | +fractal_initial_states wiring |
| `web/server.gleam` | 560 | +generic /ws/{page} handler (MO1) |
| `ha/guard_rules.gleam` | 1457 | +15 AOR rules, +10 FMEA rules |
| `ha/guard_grid.gleam` | 1253 | +ruliology viz, +probabilistic shield |
| `ha/claude_metrics.gleam` | 568 | +context budget, +hook integration |
| `ha/request_guard.gleam` | 350 | +risk-adaptive oversight per endpoint |
| `otp_app.gleam` | 300 | +biomorphic probe integration |
| `agents/cortex.gleam` | 500 | +bridge dispatch, +MoZ planning |
| 22× `lustre/*.gleam` | ~500 each | +NIF live data + /ws/{page} |
| 10× `wisp/*_api.gleam` | ~200 each | +POST handlers for control actions |

### Rust Daemon Holons (5 files to modify/create)
| Holon | Current LOC | Evolution Needed |
|-------|------------|-----------------|
| `main.rs` | 450 | +cron, +claude-stats subcommands |
| `session_summary.rs` | 130 | +production events, +agent failures |
| `recommend.rs` | 60 | +FMEA RPN scoring, +dependency DAG |
| `NEW: cron.rs` | — | Autonomous 6h OODA scheduler |
| `rule_engine.rs` | 961 | +AOR domain, +FMEA domain |

## Neuromorphic Path Updates

### Control Paths (Command Flow)
```
CURRENT:
  Browser POST → router → NIF → Smriti.db (READ-ONLY, no POST handlers)
  
EVOLVED:
  Browser POST /api/v1/planning/tasks → router → NIF plan_add() → Smriti.db
  Browser POST /api/v1/podman/action → router → NIF → Podman API
  Browser POST /api/v1/emergency/trigger → router → Guardian 2oo3 → apoptosis
  Browser POST /api/v1/cockpit/mode → router → dark_cockpit.set_mode()
  Cron (6h) → sa-plan-daemon → fitness + embed + maintain → auto-evolve
```

### Data Paths (Information Flow)
```
CURRENT:
  NIF → router → JSON (30 endpoints) → Browser
  NIF → WS /ws/planning (1s push) → Browser JS
  NIF → WS /ws/dashboard (1s push) → Browser JS

EVOLVED:
  NIF → WS /ws/{page} (generic handler) → ALL 30 pages live
  NIF → health_derivative.update() → predict 60s/300s → alert
  NIF → failure_classifier.classify() → Poisson/Bursty pattern
  NIF → claude_metrics → ETS → /api/v1/claude/session → Claude self-observe
  NIF → guard_grid → 70 rules + 13 CA → cockpit_mode → WS push
```

### Neuromorphic Paths (Learning Flow)
```
CURRENT:
  Claude edits → PostToolUse (build+test) → commit
  Session end → Stop hook → ZK ingest
  Session start → SessionStart hook → ZK recall + recommend

EVOLVED:
  Claude edits → PostToolUse → build+test → claude_metrics.record_*()
  Session end → Stop → session-save (effectiveness score) → ZK ingest
  Session start → session-summary (last session) → recommend (top 3) → ZK recall
  Between sessions → cron 6h → fitness + embed + maintain → auto anti-pattern
  Agent failure → auto-record pattern → ZK anti-pattern holon → next recall
  Production event → session_events table → next SessionStart shows context
```

## Execution Order (5 Sprints)

### Sprint 1: Critical Controls (P1, ~5 tasks)
MO1 (generic WebSocket) + CA1 (emergency stop) + CA2 (container control) + CA3 (hot reload button) + CA4 (task forms)

### Sprint 2: Live Data (P1, ~5 tasks)  
Immune + Zenoh + Verification + Agents + Knowledge NIF wiring

### Sprint 3: RETE-UL Expansion (P1-P2, ~5 tasks)
RETE2 (AOR rules) + RETE3 (FMEA rules) + OP-1 (adaptive oversight)

### Sprint 4: Dashboards + Claude (P2, ~10 tasks)
DB1-DB5 (drill-downs) + CE4-CE6 (Claude self-awareness) + CA5-CA10 (controls)

### Sprint 5: Remaining Pages + Federation (P2-P3, ~25 tasks)
All remaining SSR wiring + RETE4-5 + SERBAN-1-2

## Verification
1. After each sprint: `gleam build` 0 errors, `gleam test` 0 failures
2. Live API check: `curl /api/v1/system/snapshot` returns all subsystems GREEN
3. WebSocket: verify /ws/{page} pushes live data for each wired page
4. Guard rules: `guard_rules.rule_count()` matches expected total (70→95→105)
5. Session continuity: `sa-plan-daemon session-summary` shows accurate last session
6. ZK ingest: all journals + plans ingested, holon count growing
