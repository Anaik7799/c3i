# Marionette MCP — Implementation Status (as-built)

> Task `116480247290237220`. Honest inventory of what is built, what is in flight, and the LOC + file ownership per item.

## 1. Built (✅)

| Artefact | Path | LOC | STAMP |
|---|---|---:|---|
| Upstream clone (5 packages) | `sub-projects/marionette_mcp/` | (vendored) | — |
| Allium formal spec | `specs/allium/marionette_mcp.allium` | 379 | (formal source of truth) |
| Rule | `.claude/rules/marionette-mcp-flutter-testing.md` | 186+ | SC-MARIONETTE-001..012 |
| Agent | `.claude/agents/marionette-explorer.md` | 112+ | (16-tool allowlist) |
| Skill | `.claude/commands/marionette-explore.md` | 73+ | — |
| Settings hooks | `.claude/settings.json` (SessionStart probe + PostToolUse SC-MARIONETTE-003 guard) | (in-place) | SC-MARIONETTE-003 |
| Pass-2 deep journal | `docs/journal/20260428-032106-marionette-mcp-integration.md` | 443 | SC-JNL-001..006 |
| FluffyChat 200-test catalog | `sub-projects/sutra/fluffychat/integration_test/marionette/CATALOG.md` | (200 rows) | SC-PATROL-MCP-005 |
| FluffyChat manifest | `.../marionette/manifest.json` | 1 | — |
| FluffyChat runner | `.../marionette/marionette_runner.dart` | 1 | — |
| FluffyChat README | `.../marionette/README.md` | 1 | — |
| Pass-3 task page index | `docs/journal/task-116480247290237220/index.html` | (1 page) | SC-FEAT-EVO-005 |
| Pass-3 deck | `.../task-116480247290237220/deck.html` | (13 slides) | SC-FEAT-EVO-009 |
| Pass-3 test plan | `.../task-116480247290237220/test-plan.md` | (P0–P9) | SC-FEAT-EVO-006 |
| Pass-3 gap analysis | `.../task-116480247290237220/gap-analysis.md` | (8+10 gaps) | — |
| Pass-3 links registry | `.../task-116480247290237220/task-116480247290237220-links.json` | 1 | SC-FEAT-EVO-010 |
| Pass-3 hand-coded SVGs | `.../diagrams/01..06.svg` | 6 | SC-FEAT-EVO-009 |
| Pass-3 hand SVG → PNG | `.../diagrams/01..06.png` | 6 | (chromium-headless) |
| Pass-3 Graphviz `.dot` | `.../diagrams/g1..g4.dot` | 4 | (dot 12.2.1) |
| Pass-3 Graphviz `.svg` + `.png` | `.../diagrams/g1..g4.{svg,png}` | 8 | — |
| sa-plan parent task | `116480247290237220` | (in_progress) | SC-TODO-001 |
| sa-plan child tasks (A1–A8 + B1–B2) | `116480384653721215..669139257` | 10 | SC-TODO-001 |
| Scheduler jobs (`zk_maintain`, `embed_refresh`, `health_check`) | scheduler queue | 3 (executed) | — |
| ZK ingest | smriti.db (34 new holons in this pass) | — | SC-IKE-001 |
| Email | SMTP (6 attachments) | — | SC-NOTIFY-005 |

## 2. In flight (🟡 — partial, traceable)

| Item | Owner | Blockers |
|---|---|---|
| Math gate FMEA RPN ≤ 200 | safety-validator | 1 row at 216, mitigated; need Hamming detector to reduce O |
| Multi-platform parity runs | patrol-test-agent | needs CI runner (A4) |
| `LoggingLogCollector` in FluffyChat | marionette-explorer first run | A1 |

## 3. Not yet started (🟥 — task-tracked)

| Task | Title | sa-plan ID |
|---|---|---|
| A1 | Wire `LoggingLogCollector` in FluffyChat `lib/main.dart` | 116480384653721215 |
| A2 | TLA+ stub `MarionetteSession.tla` | 116480384655260627 |
| A3 | Mirror rule to `.gemini/rules/` | 116480384656289636 |
| A4 | CI runner via `marionette_cli` | 116480384657772451 |
| A5 | FluffyChat `MARIONETTE_EXTENSIONS.md` | 116480384660190110 |
| A6 | `dart pub global activate marionette_mcp marionette_cli` | 116480384663218124 |
| A7 | Rust `evaluate_marionette()` + 10 GRL rules | 116480384665043766 |
| A8 | Apalache CI gate | 116480384666522091 |
| B1 | Lustre dashboard tile | 116480384667760652 |
| B2 | Selector-drift Hamming detector | 116480384669139257 |

## 4. Code touched in pass 1+2+3

```
sub-projects/marionette_mcp/                                       (NEW — vendored, 5 packages)
specs/allium/marionette_mcp.allium                                 (NEW — 379 LOC)
.claude/rules/marionette-mcp-flutter-testing.md                    (NEW — extended in pass 2)
.claude/agents/marionette-explorer.md                              (NEW)
.claude/commands/marionette-explore.md                             (NEW)
.claude/settings.json                                              (EDIT — +2 hooks)
docs/journal/20260428-032106-marionette-mcp-integration.md         (NEW — 443 LOC)
docs/journal/task-116480247290237220/                              (NEW — directory)
  index.html                                                       (NEW)
  deck.html                                                        (NEW)
  test-plan.md                                                     (NEW)
  gap-analysis.md                                                  (NEW)
  goals.md                                                         (this pass — NEW)
  spec.md                                                          (this pass — NEW)
  design.md                                                        (this pass — NEW)
  implementation.md                                                (this pass — NEW)
  sre.md                                                           (this pass — NEW)
  journal.md                                                       (NEW — copy of pass-2 deep journal)
  task-116480247290237220-links.json                               (NEW)
  diagrams/01..06.svg + .png                                       (NEW — 12 files)
  diagrams/g1..g4.{dot,svg,png}                                    (NEW — 12 files)
sub-projects/sutra/fluffychat/integration_test/marionette/         (NEW — directory)
  CATALOG.md                                                       (NEW — 200 tests)
  manifest.json                                                    (NEW)
  marionette_runner.dart                                           (NEW)
  README.md                                                        (NEW)
```

Total: ~50 net-new files, ~3,500 LOC of governance + spec + diagrams + tests.

## 5. Code NOT touched (intentionally preserved)

- `.claude/rules/patrol-mcp-zenoh.md` — kept as-is to avoid blast-radius on existing patrol agent.
- `.claude/agents/patrol-test-agent.md` — unchanged; complementary to new explorer agent.
- `sub-projects/sutra/fluffychat/lib/main.dart` — pending A1 (logCollector wiring).
- `sub-projects/c3i/native/planning_daemon/src/rule_engine.rs` — pending A7 (`evaluate_marionette()`).

## 6. Verification of claims in this document

```bash
# Counts
find sub-projects/marionette_mcp/packages -maxdepth 2 -name pubspec.yaml | wc -l   # → 5
wc -l specs/allium/marionette_mcp.allium                                            # → 379
wc -l .claude/rules/marionette-mcp-flutter-testing.md                               # → 186+
ls docs/journal/task-116480247290237220/diagrams/*.png | wc -l                      # → 10
./sub-projects/c3i/target/release/sa-plan-daemon status | grep -c Marionette        # → 11
./sub-projects/c3i/target/release/sa-plan-daemon job-list                           # → 4 jobs
```
