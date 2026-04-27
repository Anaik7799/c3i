# Patrol/Marionette ↔ C3I Full Symbiosis Matrix
*Generated 2026-04-26 — task 116469699362989555 — deep-pass review*

This document maps every Patrol/Marionette concept to a C3I substrate, fractal
layer, component, spec, and state machine. It is the canonical reference for
SC-PATROL-MCP-001..012 and is cross-linked from `.claude/rules/patrol-mcp-zenoh.md`.

---

## 0. Source-of-truth packages (verified 2026-04-26)

| Package | Version | License | Role |
|---|---|---|---|
| `patrol` | 4.5.0 (existing dev_dep) | BSD-3 | Test framework |
| `patrol_cli` | 4.3.1 (transitive) | BSD-3 | CLI driver |
| `patrol_mcp` | **0.1.3** (corrected from 0.2.0) | Apache-2.0 | MCP orchestrator |
| `marionette_flutter` | 0.5.0 | Apache-2.0 | Runtime probe |
| `marionette_mcp` | 0.5.0 | Apache-2.0 | MCP introspector |

`patrol_mcp` env: `PROJECT_ROOT`, `PATROL_FLAGS`, `SHOW_TERMINAL`, `PATROL_FLUTTER_COMMAND` (FVM-aware).

---

## 1. Setup plane

| Concern | Location | Status |
|---|---|---|
| Toolchain | `devenv.nix` → `pkgs.flutter` (3.41.6) | ✅ bumped from `flutter332` |
| Project deps | `pubspec.yaml` (regular: `marionette_flutter ^0.5.0`; dev: `patrol ^4.5.0`, `patrol_mcp ^0.1.3`) | ✅ |
| MCP launcher | `sub-projects/sutra/fluffychat/tool/run-patrol` (executable) | ✅ FVM env passthrough added |
| Project MCP servers | `sub-projects/sutra/fluffychat/.mcp.json` | ✅ |
| Global MCP servers | `.claude/settings.json` → `mcpServers.{patrol,marionette}` | ✅ |
| Android native | `android/app/src/androidTest/java/.../MainActivityTest.java` (`PatrolJUnitRunner`) | ✅ |
| Gradle wiring | `android/app/build.gradle.kts` → `testInstrumentationRunner = pl.leancode.patrol.PatrolJUnitRunner` + orchestrator | ✅ |
| Driver entrypoint | `test_driver/integration_driver.dart` | ✅ |
| Patrol config | `patrol.yaml` (package_name, app_name) | ✅ |
| Test entrypoint | `integration_test/patrol_test.dart` | ✅ |
| Binding swap | `lib/main.dart` — `MarionetteBinding.ensureInitialized()` under `kDebugMode && !DISABLE_MARIONETTE` | ✅ test-conflict-safe |
| Test opt-out flag | `--dart-define=DISABLE_MARIONETTE=true` injected by `tool/run-patrol` and the bridge `run` mode | ✅ |

**Symbiosis with devenv**: MCP launcher re-execs into `devenv shell` if not already inside, so Claude Code can spawn the server even when launched outside the shell.

---

## 2. Control plane (commands, lifecycle)

```
operator → /patrol-marionette-test
    │
    ├── (optional) /agent patrol-test-agent
    │
    ▼
Claude Code harness
    │  spawns stdio MCP children
    ├──→ patrol_mcp        (long-lived; one Patrol session per project)
    └──→ marionette_mcp    (long-lived; one VM-Service connection per app)
            │
            ▼
PostToolUse hook ─[matcher mcp__(patrol|marionette)__.*]─→ patrol-zenoh-bridge.sh hook
            │
            ▼
        Zenoh REST (PUT)
            │
            ▼ (subscribers)
   cortex / dashboard / pi-mono / session_metrics
```

State machine — Patrol session:
```
created → running → (passing|failing) → quitting → terminated
                     │
                     └── on fail: screenshot + native-tree → quit
```

State machine — Marionette session:
```
disconnected → connect → connected
   ▲              │
   └────────── disconnect / app exit
              │
   connected ──→ tap | enter_text | scroll_to | screenshot | logs | hot_reload
```

---

## 3. Data plane (Zenoh topics + envelope)

| Topic | Producer | Consumers |
|---|---|---|
| `indrajaal/l5/test/patrol/<run_id>/start` | bridge / patrol_mcp run | dashboard, cortex |
| `indrajaal/l5/test/patrol/<run_id>/screenshot` | patrol_mcp screenshot | dashboard, ZK ingest |
| `indrajaal/l5/test/patrol/<run_id>/native-tree` | patrol_mcp native-tree | cortex (failure RCA) |
| `indrajaal/l5/test/patrol/<run_id>/status` | patrol_mcp status | dashboard live tile |
| `indrajaal/l5/test/patrol/<run_id>/passed\|failed` | bridge close | session_metrics, email |
| `indrajaal/l5/test/patrol/<run_id>/quit` | patrol_mcp quit | session_metrics |
| `indrajaal/l5/test/marionette/<sid>/connect` | marionette_mcp | dashboard |
| `indrajaal/l5/test/marionette/<sid>/{tap,enter_text,scroll_to,screenshot,logs,hot_reload}` | marionette_mcp | dashboard, cortex |

Envelope (canonical):
```json
{ "at":"<iso>", "source":"claude-code", "urn":"urn:c3i:test:<server>:<id>",
  "run_id":"<id>", "phase":"<phase>", "platform":"android|chrome|linux",
  "test_target":"integration_test/patrol_test.dart",
  "duration_ms": 0, "payload": { /* tool_input + tool_response */ } }
```

Reuses the SC-SCHED-TELE-MANDATORY URN grammar so existing subscribers (and the Rust `sched_telemetry.rs` envelope contract) work without change.

---

## 4. UI plane

| C3I UI | Patrol/Marionette tie-in |
|---|---|
| **Dashboard** (Lustre L4) | New tile group "Tests" subscribes to `indrajaal/l5/test/**` and renders run summaries + screenshots gallery |
| **Cockpit weather bar** (L5) | When any failed envelope appears, weather degrades to "Bright" until a `passed` envelope clears it |
| **Pi symbiosis page** (L7) | Patrol/Marionette tools count toward federated tool total (currently 93 → 106 once exposed via Pi) |
| **TUI split-screen** | Test stream rendered alongside dashboard (existing pattern in `ui/tui/split_screen.gleam`) |
| **Verification page** (L0/L4) | Aggregates `indrajaal/l5/test/patrol/**` results into PROMETHEUS proof set |
| **Agentic UI evolve** | `/c3i-page-evolution` skill calls Marionette MCP during the discovery phase to anchor selectors before writing widget tests |

---

## 5. Agentic UI plane (Lustre/Wisp/TUI tripartite)

The triple-interface mandate (SC-GLM-UI-001) extends naturally:

| Interface | Test driver | MCP integration |
|---|---|---|
| **Lustre web (4100)** | Wallaby + Patrol web (Chrome) | `mcp__patrol__run device=chrome` |
| **Wisp REST (4100)** | curl + Patrol web for browser-side flows | reuses chrome runner |
| **TUI (ANSI)** | gleeunit + Patrol Linux desktop | `mcp__patrol__run device=linux` |
| **Mobile (FluffyChat)** | Patrol Android | `mcp__patrol__run device=android` |
| **Live debug** | Marionette VM-Service | `mcp__marionette__*` (any platform) |

A2UI components proposed by agents are validated by `mcp__patrol__native-tree` against a known component catalog — closes the "agent fabricated a non-existent component" anti-pattern.

---

## 6. Testing pyramid alignment

```
              ┌──────────────────────────┐
              │ /patrol-marionette-test  │  E2E (mcp__patrol__run)
              │ android · linux · chrome │
              └──────────────────────────┘
            ┌───────────────────────────────┐
            │  Marionette live-app probes   │  Integration (mcp__marionette__*)
            │  hot_reload + tap + tree      │
            └───────────────────────────────┘
        ┌─────────────────────────────────────┐
        │  Wallaby (LiveView) + Gleam tests   │  Component
        │  3,354+ existing assertions         │
        └─────────────────────────────────────┘
    ┌───────────────────────────────────────────┐
    │ flutter_test widget tests                  │  Unit/widget
    │ + Dart Matrix SDK tests vs sutra          │
    └───────────────────────────────────────────┘
```

C1-C8 gold standard (SC-MATH-COV-001) maps to:
- C1 page structure → `mcp__patrol__native-tree` count ≥ 5
- C7 AI advisory → `mcp__marionette__get_logs` E2E Zenoh publish verified
- C8 action button → Patrol assertion + Guardian approval gate

---

## 7. Fractal-layer × Patrol/Marionette × C3I component matrix

| Layer | Function | Marionette tools | Patrol tools | C3I component (existing) | Spec / state machine |
|---|---|---|---|---|---|
| **L0 Constitutional** | Safety gates around test execution | n/a | `quit` (graceful) | Guardian (Rust planning_daemon) | TLA+ `LeaderElection.tla` |
| **L1 Atomic / Debug** | Per-widget probe | `tap`, `enter_text`, `scroll_to`, `take_screenshots`, `get_logs`, `hot_reload`, `get_interactive_elements`, `connect` | `screenshot`, `native-tree` | `l1_atomic_debug.gleam` | Marionette state machine §2 |
| **L2 Component** | Reusable form/grid testing | live introspect | `run` per file | `l2_component.gleam`, A2UI catalog | `a2ui/schema.gleam` |
| **L3 Transaction** | Test run as transaction | `connect` opens scope | `run`/`status`/`quit` | `l3_transaction.gleam` | URN `urn:c3i:test:patrol:<run>` |
| **L4 System** | Multi-app / multi-platform orchestration | n/a | parallel `run` per device | `l4_system.gleam` (boot DAG, system view) | DAG: chrome ‖ linux ‖ android |
| **L5 Cognitive** | Agent ReAct loop authoring tests | all | all | `agents/cortex.gleam`, `bridge/pi_*` | OODA cycle §1 of agent spec |
| **L6 Ecosystem** | Mesh of test envelopes | hook → Zenoh | hook → Zenoh | Zenoh router (TCP 7447), `circulatory system` | SC-ZMOF-001 |
| **L7 Federation** | Test results federated to Telegram/GChat/Email | n/a | `passed/failed` triggers email | `gateway/{telegram,gchat,whatsapp}.gleam` | gateway broadcast spec |

---

## 8. Fractal components × tool surfaces

| C3I fractal component | Patrol surface | Marionette surface | Symbiosis hook |
|---|---|---|---|
| **State management** | `mcp__patrol__status` JSON | `mcp__marionette__get_interactive_elements` | bridge → Zenoh |
| **Health monitoring** | `passed/failed` count | `get_logs` keyword scan | dashboard weather bar |
| **Recovery mechanism** | `quit` + restart | `hot_reload` | RETE rule `UIWsReconnect` |
| **Boundary / interface** | `run` accepts target+device only | `connect uri=` | URN strict format |
| **Parent/child comm** | MCP stdio | MCP stdio | hook async 5s |
| **Zenoh + OTel observability** | bridge envelopes | bridge envelopes | OTel envelope §3 |
| **AG-UI / A2UI compliance** | `native-tree` validates A2UI catalog | `get_interactive_elements` validates same | catalog allowlist |
| **STAMP control** | SC-PATROL-MCP-001..012 | same | this rule file |
| **RETE-UL / ruliology decision** | new `evaluate_test_outcome` rule | n/a | Rust planning_daemon `rule_engine.rs` (proposed P2) |
| **FMEA / FEMA risk** | iOS 360s timeout (P2) | binding conflict (mitigated) | analysis.html FMEA table |

---

## 9. Specs (TLA+ / Allium / state machines)

| Spec file | Existing? | Update needed |
|---|---|---|
| `specs/allium/ignition.allium` | yes | append `entity TestSession` + `rule TestPassedClearsAndon` |
| `specs/tla/LeaderElection.tla` | yes (HA) | unchanged |
| `specs/tla/TestPipeline.tla` | **NEW (P2)** | model patrol-run + zenoh publish + dashboard reaction |
| `specs/quint/marionette_session.qnt` | **NEW (P3)** | model session lifecycle: idle → connected → busy → idle |

State machine (Patrol run, formal):
```
States    = { Created, Running, Passed, Failed, Quitting, Terminated }
Init      ⇒ state = Created
Transitions:
  Created  --start_published-->  Running
  Running  --status_passed-->    Passed
  Running  --status_failed-->    Failed
  Passed   --quit-->             Quitting
  Failed   --screenshot+tree-->  Quitting
  Quitting --terminated-->       Terminated
Invariants:
  ¬(Failed ∧ ¬screenshot_emitted)         -- SC-PATROL-MCP-008
  passed_envelope ⇒ session_metrics_row    -- SC-PATROL-MCP-009
```

---

## 10. Symbiosis with existing subsystems

| Subsystem | Symbiosis | Action required |
|---|---|---|
| **cortex (rust planning_daemon)** | Subscribes to `indrajaal/l5/test/**`, picks up failures into FMEA pipeline (`fmea.rs`) | Add subscriber + topic to genome |
| **Pi-mono runtime** | Patrol/Marionette tool federation through `pi_tools.gleam` | Add 13 tool definitions; bumps federated count 93→106 |
| **Sentinel/Immune** | A failed test on production-like data is a threat signal | Subscribe `failed` envelopes; raise `indrajaal/sentinel/threats` |
| **Zettelkasten** | Each run summary + screenshots ingested as `organism` holon | `sa-plan-daemon ingest-docs` already handles `docs/cache/patrol/<run_id>/` |
| **session_metrics** | New rows: `tool_calls += patrol/marionette count`, `cost_usd` unchanged | Schema already supports |
| **OODA leveling** | Test-failure ⇒ Decide phase prioritizes rule `UICockpitEscalate` | Already in rule engine |
| **CPU governor** | Long Patrol web runs (Playwright) heavy; respect `governor wait` | Bridge wraps with `governed_exec` (TODO P2) |
| **HA leader election** | Tests run on whichever node holds the lease | Patrol MCP child stays bound to one node |
| **Wallaby** | Existing 31-page LiveView E2E; web Patrol layered above for fluffychat-on-web | Independent; both publish to Zenoh |
| **scripts-gleam orchestrator** | Feature-evolution pack auto-generated for every Patrol feature | Already fires via `/feature-evolution` |

---

## 11. Setup × call × data flow trace (concrete one-shot example)

```
0  Operator: /patrol-marionette-test integration_test/patrol_test.dart android
1  Skill: marionette_mcp.connect(uri="ws://127.0.0.1:8181/ws")
       → PostToolUse hook → Zenoh PUT indrajaal/l5/test/marionette/m1/connect
2  Skill: marionette_mcp.get_interactive_elements()
       → returns [Key('login_button'), Key('home_screen'), ...]
       → Zenoh PUT .../m1/get_tree
3  Agent edits integration_test/patrol_test.dart with new selectors
4  Skill: patrol_mcp.run(target=..., device=android)
       → spawns `patrol test --dart-define=DISABLE_MARIONETTE=true ...`
       → Zenoh PUT indrajaal/l5/test/patrol/p1/start
5  Polls patrol_mcp.status until terminal; mirrors to Zenoh
6  patrol_mcp.screenshot at each checkpoint → Zenoh + docs/cache/patrol/p1/
7  On pass: patrol_mcp.quit; bridge publishes /passed
   On fail: patrol_mcp.native-tree → marionette_mcp.get_logs → publish /failed
8  Stop hook ingests journal + screenshots to ZK; emails summary
```

---

## 12. Symbiosis gaps — backlog

| Gap | Layer | Priority | Tracking |
|---|---|---|---|
| Cortex subscriber for `indrajaal/l5/test/**` | L5/L6 | P2 | new sa-plan task |
| Pi-mono federation of 13 MCP tools | L7 | P2 | `pi_tools.gleam` + tests |
| TLA+ `TestPipeline.tla` model | L0 | P2 | `specs/tla/` |
| Allium `entity TestSession` + rules | L0 | P2 | `specs/allium/ignition.allium` |
| Dashboard "Tests" tile group | L4 | P2 | `ui/lustre/dashboard.gleam` |
| RETE rule `evaluate_test_outcome` | L5 | P2 | `rule_engine.rs` |
| `governed_exec` wrap on Patrol runs | L4 | P2 | bridge script |
| iOS / macOS / Windows targets | L4 | P3 | future |
| Quint `marionette_session.qnt` | L0 | P3 | future |
| Sentinel threat path on repeated failures | L0 | P3 | future |

---

## 13. Conclusion

Patrol MCP and Marionette MCP integrate cleanly into every C3I plane:
**setup** is two `dart pub global activate` + a `flutter pub get`; the
**control plane** is a single PostToolUse matcher; the **data plane** rides
the existing Zenoh backplane under a new `l5/test/**` namespace; the **UI**
gets a new tile group; **agentic UI** authoring becomes deterministic
(Marionette discovers, Patrol verifies); **testing** spans Android + Linux
desktop + Chrome from one Dart suite; every **fractal layer** L0-L7 has a
clear hook; **specs** receive minimal additions (one Allium entity, one
TLA+ model). The 12 STAMP constraints + URN envelope guarantee these new
flows are first-class citizens of the SIL-6 Biomorphic Mesh.
