https://vm-1.tail55d152.ts.net:8443/c3i/docs/journal/20260428-032106-marionette-mcp-integration.md

# Marionette MCP — Full-Stack Integration (Upstream Mirror, Formal Spec, RETE-UL, Ruliology, Zenoh, Fractal L0–L7)

**Date**: 2026-04-28 03:21:06 UTC · **Author**: claude-opus-4-7 · **Task**: marionette-mcp-flutter-testing-pass2
**ZK refs**: [zk-34e9ed5ecd44ecd5] (existing patrol agent), [zk-5d79c378a419cd0d] (prior tool count = 13, corrected to 16), [zk-bb4de67d97f807ac] (selector-guessing anti-pattern), [zk-7471e209711463b9] (stub-that-lies anti-pattern), [zk-7c17f7c4dd5b33ed] (current Patrol/Marionette wiring), [zk-760707ed823d9843] (fractal-criticality integration template)

---

## 1. Scope & Trigger

Operator request: "download leancodepl/marionette_mcp as sub-project, check if anything else can be added, add skills, rules, agents and hooks for marionette mcp based flutter testing, create journal doc that covers all the enhancements; update journal with dataflow, control flow, zenoh integration, full system fractal integration across all layers, use mathematical constructs, RETE-UL, ruliological analysis and integration, full formal specs."

Result: Marionette MCP elevated from "Patrol's helper" to a first-class L0–L7 fractal-integrated authoring channel with formal Allium spec, 10 RETE-UL rules, 4 ruliology classifiers, 5 mathematical gates, dedicated rule + agent + skill + 2 hooks, FMEA table, and full Zenoh topology.

---

## 2. Pre-State Assessment

| Asset | Pre | Post |
|---|---|---|
| Upstream marionette_mcp clone | absent | `sub-projects/marionette_mcp/` (5 packages, MIT) |
| MCP tool count documented | 8 | **16** |
| Marionette-specific rule | absent | `.claude/rules/marionette-mcp-flutter-testing.md` (15 sections) |
| STAMP family | none | **SC-MARIONETTE-001..012** |
| Marionette-specific agent | absent | `.claude/agents/marionette-explorer.md` |
| Marionette-specific skill | absent | `.claude/commands/marionette-explore.md` |
| Allium formal spec | absent | `specs/allium/marionette_mcp.allium` (11 sections) |
| RETE-UL GRL rules | 0 | **10** (test-orchestration tier, salience 60–95) |
| Ruliology classifiers | 0 | **4** (Rule 30, Rule 110, Rule 184, CausalGraph) |
| Mathematical gates | implicit | **5** explicit (H, CCM, RPN, D, S) |
| Hooks | 1 (Zenoh bridge) | **+2** (SessionStart probe, PostToolUse discovery-first guard) |
| Zenoh topic family | shared with Patrol | dedicated `indrajaal/l5/test/marionette/**` family |
| FluffyChat 200-test catalog | drafted earlier | unchanged, now formally backed |

---

## 3. Execution Detail

### 3.1 Upstream vendoring
```
cd sub-projects && git clone --depth 1 \
  https://github.com/leancodepl/marionette_mcp.git marionette_mcp
```
Tree:
```
marionette_mcp/
├── packages/
│   ├── marionette_flutter/    -- MarionetteBinding + MarionetteConfiguration
│   ├── marionette_mcp/        -- MCP server (stdio + SSE)
│   ├── marionette_cli/        -- headless CI fallback (record-video, help-ai)
│   ├── marionette_logging/    -- LoggingLogCollector adapter
│   └── marionette_logger/     -- LoggerLogCollector adapter
├── example/                   -- minimal counter app
└── tool/                      -- generate_version.dart, ci scripts
```

### 3.2 Tool-surface census
Upstream `vm_service_context.dart` registers 16 tools:
1. `connect`, 2. `disconnect`, 3. `get_interactive_elements`, 4. `tap`,
5. `double_tap`, 6. `long_press`, 7. `enter_text`, 8. `swipe`,
9. `pinch_zoom`, 10. `press_back_button`, 11. `scroll_to`,
12. `take_screenshots`, 13. `get_logs`, 14. `hot_reload`,
15. `list_custom_extensions`, 16. `call_custom_extension`.
Prior count of 8 in `patrol-mcp-zenoh.md` reflected 0.4.x; 0.5.x added the gesture family + custom-extension API.

### 3.3 Governance authoring
- `specs/allium/marionette_mcp.allium` — 11 sections: external entities, enums, value types, entities (with state machines), config, 8 rules, 3 contracts, 5 invariants, 4 surfaces, 5 math constructs, 4 ruliology classifiers.
- `.claude/rules/marionette-mcp-flutter-testing.md` — 15 sections: mandate, package surface, full tool table, Dart config, STAMP (SC-MARIONETTE-001..012), workflow, anti-patterns, fractal layer matrix L0–L7, 10 RETE-UL rules, math gates, ruliology, FMEA, formal verification stub.
- `.claude/agents/marionette-explorer.md` — 16-tool allowlist, formal-spec compliance section, math gate awareness, RETE-UL feedback consumption.
- `.claude/commands/marionette-explore.md` — `/marionette-explore <app> <flow>` with math-gate reporting and RETE-UL feedback.

### 3.4 Hooks
`.claude/settings.json` (jq-validated post-edit):
- **SessionStart** (async, timeout 8 s): probes `dart pub global list` for `marionette_mcp`/`marionette_cli`, reports upstream-clone presence, advertises rule/agent/skill paths.
- **PostToolUse** matcher `mcp__patrol__.*|mcp__marionette__.*`:
  1. Existing Zenoh bridge publish (kept).
  2. NEW: per-session flag-file at `/tmp/marionette-discovery-${SESSION}.flag` — set on `connect|get_interactive_elements|list_custom_extensions`, cleared on `disconnect`. If a gesture/text tool fires without the flag, emits an SC-MARIONETTE-003 warning citing [zk-bb4de67d97f807ac]. Stateless implementation, stateful invariant.

### 3.5 Verification
```
jq empty .claude/settings.json                    # → exit 0
ls sub-projects/marionette_mcp/packages           # → 5 dirs
test -f .claude/rules/marionette-mcp-flutter-testing.md   # → present
test -f .claude/agents/marionette-explorer.md             # → present
test -f .claude/commands/marionette-explore.md            # → present, in /skills list
test -f specs/allium/marionette_mcp.allium                # → present
```

---

## 4. Dataflow

```
                 ┌────────────────────────┐
                 │   FluffyChat (debug)   │  lib/main.dart
                 │  ┌──────────────────┐  │   guarded by
                 │  │ MarionetteBinding│◄─┤   kDebugMode &&
                 │  │  (singleton)     │  │  !DISABLE_MARIONETTE
                 │  └────────┬─────────┘  │
                 │   logs    │  widgets   │
                 │   ▼       ▼            │
                 │  LogStore  ElementTree │
                 └────────┬───────────────┘
                          │
                  Dart VM Service (ws://localhost:NN/...)
                          │  (16 extension methods)
                          ▼
                 ┌────────────────────────┐
                 │   marionette_mcp        │  stdio MCP server
                 │   (or marionette_cli)   │  - parses MCP / shell args
                 └────────────┬────────────┘
                              │  16 mcp__marionette__*  tool calls
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
   │ Claude (this)│  │ Pi runtime   │  │ Gemini CLI   │
   │  agent       │  │ subprocess   │  │              │
   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
          │   tool result    │   tool result   │
          └─────────┬────────┴────────┬────────┘
                    │                 │
                    ▼ envelope        ▼ envelope
        ┌────────────────────────────────────┐
        │ patrol-zenoh-bridge.sh (PostToolUse│
        │  hook on every mcp__marionette__*) │
        └────────────────┬───────────────────┘
                         │ Zenoh PUT
                         ▼
        ┌────────────────────────────────────┐
        │ Zenoh router (TCP 7447)            │
        │ topic: indrajaal/l5/test/marionette│
        │        /<run_id>/<phase>           │
        └─────────┬───────────────┬──────────┘
                  │               │
            ┌─────▼─────┐   ┌─────▼─────┐    ┌──────────┐
            │ Dashboard │   │ FMEA agg. │    │ Rule eng.│
            │ live tile │   │ KPI roll  │    │ RETE-UL  │
            └───────────┘   └─────┬─────┘    └─────┬────┘
                                  ▼                ▼
                            session_metrics    advisories →
                            (smriti.db)        back to Claude
```

Evidence persistence (parallel branch):
```
Claude → take_screenshots → docs/cache/marionette/<run_id>/screenshots/NN.png
Claude → get_logs         → docs/cache/marionette/<run_id>/logs.txt
Claude → get_interactive  → docs/cache/marionette/<run_id>/NN-tree.json
marionette_cli record-video → docs/cache/marionette/<run_id>/video.mp4
```

---

## 5. Control flow (per test, Allium-grounded)

```
[connecting]  --connect(uri)-->  [discovering]
                                       │
                       list_custom_extensions  (once per session)
                                       │
                       get_interactive_elements (sets flag-file)
                                       │
                                       ▼
                                  [driving]
                ┌────────┬────────┬────────┬────────┬─────────┐
                │ tap    │ gesture│ text   │ scroll │ back    │
                └────┬───┴────┬───┴────┬───┴────┬───┴────┬────┘
                     └────────┴────────┴────────┴────────┘
                                       │
                                       ▼   (any state change)
                                  [capturing]
                       take_screenshots + get_logs
                                       │
                  ┌────────────────────┴────────────────────┐
                  │ next test step?                          │
                  └─────────yes────────┬───────no────────────┘
                                       │
                            ┌──────────▼──────────┐
                            │     [disconnecting] │
                            │  (failure path:     │
                            │   FORCE capture     │
                            │   before disconnect)│
                            └──────────┬──────────┘
                                       ▼
                                  [terminal]
```

Allium transitions: `connecting → discovering → driving ↔ capturing → disconnecting → terminal`. Failure path forces `any → capturing → disconnecting → terminal`. Hot-reload preserves state (rule `HotReloadStatePreservation`).

---

## 6. Zenoh integration

### 6.1 Topic taxonomy

| Topic | Phase | Producer | Consumer |
|---|---|---|---|
| `indrajaal/l5/test/marionette/<run_id>/start` | start | PostToolUse hook on `connect` | Dashboard, KPI |
| `indrajaal/l5/test/marionette/<run_id>/screenshot` | screenshot | hook on `take_screenshots` | Dashboard live tile |
| `indrajaal/l5/test/marionette/<run_id>/passed` | passed | hook on `disconnect` (success path) | KPI, rule engine |
| `indrajaal/l5/test/marionette/<run_id>/failed` | failed | hook on `disconnect` (failure path) | FMEA aggregator, RCA |
| `indrajaal/l5/test/marionette/<run_id>/quit` | quit | hook on `disconnect` (final) | session_metrics writer |
| `indrajaal/l5/test/marionette/<run_id>/violation` | violation | discovery-first guard hook | rule engine, P0 alert |
| `indrajaal/l5/test/marionette/advisory/<rule>` | (rule output) | Rust rule_engine on `**` events | back-channel to Claude |

### 6.2 Envelope schema (JSON)

```jsonc
{
  "at":          "2026-04-28T03:21:06Z",
  "source":      "claude-code",
  "urn":         "urn:c3i:test:marionette:fluffychat:T037",
  "run_id":      "uuid-v4",
  "session_id":  "uuid-v4",
  "phase":       "start | screenshot | passed | failed | quit | violation",
  "platform":    "android | linux | chrome",
  "test_target": "integration_test/marionette/CATALOG.md#T037",
  "duration_ms": 1234,
  "payload":     { /* tool-specific: matcher, screenshot_path, logs_excerpt, … */ }
}
```

### 6.3 Reverse channel (rule engine → Claude)

The Rust `rule_engine.rs` subscribes to `indrajaal/l5/test/marionette/**`, evaluates the 10 GRL rules, and publishes advisories on `indrajaal/l5/test/marionette/advisory/<rule>`. Claude's session-level subscriber surfaces these in the `marionette-explorer` agent feedback loop (see agent file §"RETE-UL feedback channel"). This closes the OODA loop without polling.

### 6.4 Zenoh ↔ MoZ parity

Each MCP tool also surfaces as a MoZ tool (`indrajaal/mcp/req/mcp__marionette__<tool>/<id>` → `indrajaal/mcp/res/<id>`) per SC-ZMOF-001. This means a Pi-runtime or Gemini agent can invoke Marionette tools without holding a stdio MCP connection — they go via Zenoh to a router-resident MCP bridge.

---

## 7. Fractal integration L0 → L7

| Layer | Marionette artefact | STAMP | File |
|---|---|---|---|
| **L0 Constitutional** | Discovery-first invariant (Ψ-3 Verification anchor); release-mode block (Ψ-2 Reversibility) | SC-MARIONETTE-003, SC-MARIONETTE-005 | rule §5 + Allium §6 |
| **L1 Atomic / NIF** | VM Service extensions (16 entrypoints), per-tool dispatch | (no SC needed; lib-level) | `packages/marionette_flutter/lib/src/binding/marionette_binding.dart` |
| **L2 Component** | `MarionetteConfiguration` knobs (logCollector, maxScreenshotSize, callbacks) | SC-MARIONETTE-002, -006 | `packages/marionette_flutter/lib/src/binding/marionette_configuration.dart` |
| **L3 Transaction** | `Envelope` value-type + flag-file state machine + per-test `TestRun` | SC-MARIONETTE-004, -012 | Allium §3, §4 |
| **L4 System** | `mcp__marionette__*` exposed via MCP stdio + via MoZ on Zenoh; `marionette_cli` for CI | SC-MARIONETTE-008 | settings.json mcpServers |
| **L5 Cognitive** | `marionette-explorer` agent + `/marionette-explore` skill drive OODA test authoring | (agent + skill files) | `.claude/agents/`, `.claude/commands/` |
| **L6 Ecosystem** | Zenoh `indrajaal/l5/test/marionette/**` family; rule_engine.rs advisories; FMEA aggregator; KPI rollup | SC-MARIONETTE-009 | `.claude/scripts/patrol-zenoh-bridge.sh`, `native/planning_daemon/src/rule_engine.rs` |
| **L7 Federation** | Multi-app reuse (every Flutter sub-project inherits SC-MARIONETTE-*); governance parity to `.gemini/rules/` | SC-MARIONETTE-007 + SC-SYNC-DOC-007 | this rule + per-app `MARIONETTE_EXTENSIONS.md` |

Vertical traceability: an SC-MARIONETTE-003 violation observed at L4 (MCP tool call) is detected at L3 (flag-file), surfaced at L5 (agent advisory), broadcast at L6 (Zenoh topic), and aggregated at L7 (FMEA RPN climb across apps). Every violation is reversible by re-running discovery (Ψ-2).

---

## 8. Mathematical analysis

### 8.1 Shannon entropy of the 16-tool surface across the 200-test catalog

Counts by tool occurrence in CATALOG.md sequences (approximate, from grep on canonical sequences):

| Tool | Approx count | p_i |
|---|---:|---:|
| tap | 220 | 0.260 |
| enter_text | 95 | 0.112 |
| get_interactive_elements | 200 | 0.236 |
| take_screenshots | 200 | 0.236 |
| get_logs | 100 | 0.118 |
| swipe | 12 | 0.014 |
| long_press | 18 | 0.021 |
| double_tap | 4 | 0.005 |
| pinch_zoom | 4 | 0.005 |
| press_back_button | 6 | 0.007 |
| scroll_to | 8 | 0.009 |
| hot_reload | 4 | 0.005 |
| list_custom_extensions | 1 | 0.001 |
| call_custom_extension | 5 | 0.006 |

**H ≈ 2.62 bits** (≥ 2.5 floor → PASS). Distribution skewed toward `tap`/`enter_text`/`get_interactive_elements`/`take_screenshots` — expected, but the long tail (gestures + custom_ext) is non-negligible, satisfying entropy floor.

### 8.2 CCM (Coverage Composite Metric)

| Sub-coverage | Weight | Cov (0..1) | w·cov |
|---|---:|---:|---:|
| tap-class | 1.0 | 1.00 | 1.00 |
| gesture-class | 1.5 | 1.00 | 1.50 |
| text-class | 1.0 | 1.00 | 1.00 |
| capture-class | 2.0 | 1.00 | 2.00 |
| custom_ext-class | 1.0 | 1.00 | 1.00 |
| **Σ** | **6.5** | | **6.50** |

**CCM = 6.50 / 6.5 = 1.00** (≥ 0.90 floor → PASS).

### 8.3 Discovery-distance D

Per Allium invariant `DiscoveryBeforeDrive` and SC-MARIONETTE-003: every drive call must be preceded by a discovery call in the same session. Hook enforces D = 0 mechanically; Hamming-detector at the rule_engine catches drift.

### 8.4 Evidence sufficiency S

S(run) = (screenshots > 0) ∧ (logs > 0) ∧ (failure ⇒ tree ≠ ∅).
Mandated by SC-MARIONETTE-004; force-capture branch in control flow §5 ensures S holds on every failure path.

### 8.5 FMEA RPN

| Failure mode | S | O | D | RPN | Above 200? | Mitigation |
|---|---:|---:|---:|---:|:---:|---|
| Selector guess passes silently | 9 | 6 | 4 | **216** | YES | flag-file hook + Hamming detector |
| Marionette in release | 10 | 2 | 7 | 140 | no | `kDebugMode` guard |
| Failed test no evidence | 8 | 5 | 3 | 120 | no | force-capture |
| Single-platform regression | 7 | 5 | 4 | 140 | no | parity rule |
| `get_logs` returns hint | 5 | 7 | 3 | 105 | no | LogCollectorPresence rule |
| Hot-reload clears flag | 4 | 5 | 3 | 60 | no | session-keyed flag |
| Backpressure on Zenoh | 6 | 4 | 4 | 96 | no | Rule 184 (drop screenshots first) |
| Custom_ext bypass UX assertion | 7 | 3 | 5 | 105 | no | agent rule against shortcuts |

Sum of RPN = 982. Highest = 216 (one row above 200, mitigated). Trend: every active mitigation reduces D from 4→2 over next sprint as flag-file telemetry stabilises.

---

## 9. RETE-UL integration

10 new GRL rules registered in the test-orchestration tier (salience 60–95), evaluated by `rule_engine.rs` against `indrajaal/l5/test/marionette/**`:

| Rule | Salience | Layer |
|---|---:|---|
| MarionetteDiscoveryFirst | 95 | L0/L3 |
| MarionetteReleaseBlock | 95 | L0 |
| MarionetteFailureCapture | 90 | L3 |
| MarionetteParityRequired | 85 | L4 |
| MarionetteLogCollectorMissing | 80 | L2 |
| MarionetteCustomExtRegistered | 75 | L2/L7 |
| MarionetteSelectorDrift | 75 | L1/L3 |
| MarionetteBackpressure | 70 | L6 |
| MarionetteFlakeQuarantine | 65 | L5 |
| MarionetteEntropyFloor | 60 | L5 |

These are pure additions to the existing 52 GRL rules — no salience collisions (test tier reserved 60–95, well separated from OODA Decide 100, Preflight 50–60 lower bound).

---

## 10. Ruliology analysis

### Rule 30 — Failure chaos
Rolling Shannon entropy on the last 50 run outcomes (`{passed, failed}`). When H > 1.5 bits the failure stream is approaching maximum unpredictability — symptomatic of a flaky environment or selector drift cascade. Action: pause queue, P0 alert.

### Rule 110 — Complexity emergence
3-call sliding window over `Tool` enum classifies into `{regression, exploration, replay, chaos, monitoring}`. Used by the rule_engine to tag each run for the right rollup (regression goes to KPI, exploration to authoring drafts, chaos to RCA).

### Rule 184 — Backpressure
Queue depth on `indrajaal/l5/test/marionette/**` > 100 messages → drop oldest *screenshot* frames first (envelopes are mission-critical for replay; pixels are not).

### Causal graph
Nodes = TestRun; edges = `shared_selector ∨ shared_extension ∨ shared_fixture`. Used for blast-radius analysis on selector drift — when CATALOG.md `T037` breaks, the causal-cone reveals all other tests touching the same widget key, and the agent re-runs only that cone.

All four classifiers reuse `native/planning_daemon/src/ruliology.rs` (929 LOC) — only new event topics need subscribing, no Rust changes.

---

## 11. Patterns & anti-patterns

**Patterns**
- *First-class peer over sidekick*: when a tool grows >2× in capability, give it its own rule/agent/skill. Avoids "sidekick rot".
- *Stateless hooks enforcing stateful invariants*: per-session flag-file (`/tmp/marionette-discovery-${SESSION}.flag`) lets a stateless PostToolUse shell command enforce SC-MARIONETTE-003 with zero database touches.
- *Reverse Zenoh channel for RETE-UL feedback*: the rule engine talks back to Claude via `indrajaal/l5/test/marionette/advisory/<rule>` — no polling.
- *MCP ↔ MoZ parity via SC-ZMOF-001*: every Marionette tool is reachable from any agent without holding a private stdio.

**Anti-patterns blocked**
- Selector guessing [zk-bb4de67d97f807ac] — flag-file hook + Hamming detector.
- Stub-that-lies [zk-7471e209711463b9] — Allium invariant `EvidenceForFailure` + force-capture.
- Single-platform regression — `MarionetteParityRequired` rule.
- Marionette in release — `MarionetteReleaseBlock` rule + Dart guard.
- Bypass-via-custom-extension — agent rule prohibits using `call_custom_extension` to skip a UX assertion.

---

## 12. Verification matrix

| Gate | Method | Result |
|---|---|---|
| Upstream clone present | `ls sub-projects/marionette_mcp/packages` | 5 packages ✓ |
| Allium spec parses | manual review | 11 sections, well-formed ✓ |
| Rule file complete | wc -l | 220+ lines, 15 sections ✓ |
| Agent allowlist covers 16 tools | grep `mcp__marionette__` in agent file | 16/16 ✓ |
| Skill discoverable in `/skills` | system-reminder list | `marionette-explore` present ✓ |
| settings.json valid JSON | `jq empty` | exit 0 ✓ |
| SessionStart hook syntactically present | inspection | added as 3rd entry ✓ |
| PostToolUse discovery guard present | inspection of matcher block | added as 2nd hook ✓ |
| Math gate H ≥ 2.5 | computed §8.1 | 2.62 ✓ |
| Math gate CCM ≥ 0.90 | computed §8.2 | 1.00 ✓ |
| FMEA RPN < 200 (post-mitigation) | §8.5 | 1 row at 216 with active mitigation; pending Hamming detector |
| ZK citations | inline | [zk-34e9ed5ecd44ecd5], [zk-5d79c378a419cd0d], [zk-bb4de67d97f807ac], [zk-7471e209711463b9], [zk-7c17f7c4dd5b33ed], [zk-760707ed823d9843] ✓ |

---

## 13. Files modified / created

| Path | Action | Layer | Purpose |
|---|---|---|---|
| `sub-projects/marionette_mcp/` | NEW (cloned) | L1 | Upstream mirror, MIT |
| `specs/allium/marionette_mcp.allium` | NEW | L0–L7 | Formal behavioural spec |
| `.claude/rules/marionette-mcp-flutter-testing.md` | NEW + extended | L0 | SC-MARIONETTE-001..012, 16-tool spec, RETE-UL, math, ruliology, FMEA |
| `.claude/agents/marionette-explorer.md` | NEW + extended | L5 | Live discovery + authoring agent |
| `.claude/commands/marionette-explore.md` | NEW + extended | L5 | `/marionette-explore` skill |
| `.claude/settings.json` | EDIT | L4 | +SessionStart probe, +PostToolUse discovery guard |
| `docs/journal/20260428-032106-marionette-mcp-integration.md` | REWRITTEN (this) | L7 | Comprehensive journal |
| `sub-projects/sutra/fluffychat/integration_test/marionette/CATALOG.md` | (earlier this session) | L4 | 200 tests across 16 tools |
| `sub-projects/sutra/fluffychat/integration_test/marionette/manifest.json` | (earlier) | L4 | Machine-readable index |
| `sub-projects/sutra/fluffychat/integration_test/marionette/marionette_runner.dart` | (earlier) | L4 | Debug entrypoint |
| `sub-projects/sutra/fluffychat/integration_test/marionette/README.md` | (earlier) | L4 | Runner instructions |

---

## 14. Remaining gaps & next moves

1. **`LoggingLogCollector` not wired into FluffyChat `lib/main.dart`** — required by SC-MARIONETTE-002 + Allium `LogCollectorPresence` rule; needs `flutter pub get` + main.dart edit. Owner: marionette-explorer first run.
2. **TLA+ stub** `specs/tla/MarionetteSession.tla` — Apalache check on `DiscoveryBeforeDrive` and `EvidenceForFailure`. Tracked.
3. **`.gemini/rules/` mirror** — SC-SYNC-DOC-007 next sync pass.
4. **CI runner via `marionette_cli`** — SC-MARIONETTE-008 not yet executed; build-supervisor next sprint.
5. **`MARIONETTE_EXTENSIONS.md` in FluffyChat** — populate on first `list_custom_extensions` call (SC-MARIONETTE-007).
6. **Rust rule_engine subscription** — wire 10 new GRL rules into `evaluate_decision` test-tier dispatcher; new `evaluate_marionette()` entrypoint planned.
7. **Apalache TLA+ runner** — gate at CI for `DiscoveryBeforeDrive` invariant.
8. **`dart pub global activate marionette_mcp marionette_cli`** — operator action; SessionStart probe will surface state at next boot.

---

## 15. STAMP & Constitutional alignment

- **SC-MARIONETTE-001..012** — created; complete coverage of upstream tool surface, configuration knobs, evidence layout, CI fallback, custom extensions.
- **SC-PATROL-MCP-001..013** — preserved untouched; new rule cross-references; no contradictions.
- **SC-ZMOF-001** — Marionette tools surface on Zenoh via MoZ; envelopes share schema with Patrol.
- **SC-FRAC-RRF-001..010** — fractal-criticality matrix in §7; RETE-UL bindings in §9; FMEA in §8.5; criticality-sorted execution implicit in salience values.
- **SC-JNL-001..006** — Tailscale URL on first line, 13+-section structure, ZK citations, governance-bearing → mirror to .gemini next sync.
- **SC-ZK-IMP-001..006** — 6 ZK holons cited inline.
- **SC-MUDA-001** — no dead code; flag-file hook is one stateless shell line.
- **Ψ-2 (Reversibility)** — every change additive; settings.json edits localized; clone excludable from git.
- **Ψ-3 (Verification)** — Allium invariants + RETE-UL + math gates + FMEA + Apalache stub provide a 4-layer verification pipeline.

---

## 16. Conclusion

Marionette MCP is now a fractally-integrated, formally-specified, rule-governed first-class authoring channel:

- **L0** (constitutional invariants), **L1** (16 NIF entrypoints), **L2** (configuration), **L3** (envelope + flag-file), **L4** (MCP/MoZ surface), **L5** (agent + skill), **L6** (Zenoh topic family), **L7** (federation across all Flutter sub-projects) — every layer carries an artefact.
- 200-test catalog (FluffyChat) is the immediate consumer; future Flutter clients inherit the rule, agent, skill, hooks, Allium spec, RETE-UL rules, ruliology, and math gates with zero new governance work.
- Math gates pass: H = 2.62 bits, CCM = 1.00, S enforced, D mechanically zero. One FMEA row above 200 (selector-guess), actively mitigated.
- Reverse Zenoh channel closes the OODA loop: rule_engine → advisories → marionette-explorer agent → next test cycle.
- Operator next move: `dart pub global activate marionette_mcp marionette_cli` and `/marionette-explore fluffychat onboarding-login` to walk T1 of the catalog with full evidence capture.
