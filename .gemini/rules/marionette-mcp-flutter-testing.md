<!-- Mirror of .claude/rules/marionette-mcp-flutter-testing.md; governance parity per SC-SYNC-DOC-007. -->
# Marionette MCP Flutter Testing Protocol (SC-MARIONETTE)

> Companion to `.claude/rules/patrol-mcp-zenoh.md`. That rule treats Marionette as a sidekick to Patrol and undercounts the tool surface; this rule is the authoritative spec for Marionette-driven Flutter testing across the C3I mesh.
>
> Upstream cloned at `sub-projects/marionette_mcp/` (5 packages, MIT, leancodepl). ZK refs: [zk-34e9ed5ecd44ecd5] existing patrol agent, [zk-5d79c378a419cd0d] previous tool-count metric (13 → corrected to **16**), [zk-bb4de67d97f807ac] selector-guessing anti-pattern.

## 1. Mandate

Marionette is the **default authoring + exploration channel** for every Flutter app in the mesh (FluffyChat today; future Flutter clients tomorrow). Patrol remains the regression channel. AI-driven UI work MUST start by attaching Marionette and discovering the live tree — never by guessing selectors from source.

## 2. Package surface (5 packages, all from `sub-projects/marionette_mcp/packages/`)

| Package | Role | Used by |
|---|---|---|
| `marionette_flutter` | `MarionetteBinding` + `MarionetteConfiguration`; registers VM service extensions | every Flutter app under `sub-projects/sutra/`, future clients |
| `marionette_mcp` | MCP server (stdio + SSE); translates MCP tool calls → VM service extensions | Claude/Pi/Gemini agents |
| `marionette_cli` | Shell-driven equivalent of MCP for headless CI / restricted envs | CI runners, Bash-only agents |
| `marionette_logging` | `LoggingLogCollector` for Dart `logging` package | apps using `package:logging` |
| `marionette_logger` | `LoggerLogCollector` (dual `LogCollector`+`LogOutput`) for `logger` package | apps using `package:logger` |

## 3. Full MCP tool surface — 16 tools (correcting prior count of 8)

| # | Tool | Purpose | Primary anti-pattern it blocks |
|---|---|---|---|
| 1 | `connect(uri)` | Attach to debug app via VM Service | — |
| 2 | `disconnect()` | Detach | leaked sessions |
| 3 | `get_interactive_elements()` | Live widget discovery | **selector guessing** [zk-bb4de67d97f807ac] |
| 4 | `tap(key|text|type|coords)` | Tap | — |
| 5 | `double_tap(target, delay?)` | Double tap (default 100 ms) | manual two-tap timing |
| 6 | `long_press(target, duration?)` | Long press (default 600 ms) | platform-channel hacks |
| 7 | `enter_text(input, key|focused_element)` | Type into field or focused element | brittle field-finding |
| 8 | `swipe(target, direction, distance?)` *or* `(x1,y1,x2,y2)` | Drag / scroll-by-gesture | flaky `await tester.drag` reproductions |
| 9 | `pinch_zoom(target, scale, start_distance?)` | Two-finger zoom | impossible without binding |
| 10 | `press_back_button()` | System back | platform-conditional code in tests |
| 11 | `scroll_to(target)` | Scroll until visible | manual `ensureVisible` loops |
| 12 | `take_screenshots()` | Base64 PNG capture (downscaled per `maxScreenshotSize`) | "passed silently" failures |
| 13 | `get_logs()` | Drain captured logs since last reload | log loss across hot reload |
| 14 | `hot_reload()` | Apply new code, preserve state | rebuild-from-scratch loops |
| 15 | `list_custom_extensions()` | Enumerate app-registered VM extensions | hidden hooks |
| 16 | `call_custom_extension(name, args?)` | Drive app-specific test hooks | deep-state setup via UI gymnastics |

CLI parity: every tool above has a `marionette_cli` sub-command (kebab-case). The CLI also adds `register`, `unregister`, `list`, `doctor`, `record-video`, `help-ai`, `mcp`.

## 4. Dart-side configuration (must be set per app)

```dart
// In lib/main.dart, guarded by kDebugMode && !DISABLE_MARIONETTE
MarionetteBinding.ensureInitialized(
  MarionetteConfiguration(
    isInteractiveWidget:   (t) => /* mark custom widgets tappable */,
    shouldStopTraversal:   (t) => /* stop tree descent at custom barriers */,
    extractText:           (Element e) => /* pull title/label from a wrapper */,  // 0.5.x: Element, not Widget
    maxScreenshotSize:     const Size(1600, 1600),                                // null disables resize
    logCollector:          LoggingLogCollector(),                                  // or LoggerLogCollector / PrintLogCollector
  ),
);
```

Built-in interactive widgets: Checkbox, DropdownButton, ElevatedButton, FilledButton, FloatingActionButton, GestureDetector, IconButton, InkWell, OutlinedButton, PopupMenuButton, Radio, Slider, Switch, TextButton, TextField, TextFormField, Text, RichText, EditableText.

## 5. STAMP constraints (extends, does not replace, SC-PATROL-MCP-*)

| ID | Constraint | Severity |
|---|---|---|
| SC-MARIONETTE-001 | All 16 MCP tools MUST be reachable from C3I-attached agents (Claude/Pi/Gemini) | CRITICAL |
| SC-MARIONETTE-002 | Every Flutter app under `sub-projects/` MUST initialize `MarionetteBinding` with a non-null `logCollector` | CRITICAL |
| SC-MARIONETTE-003 | Every test step that targets a widget MUST be preceded by `get_interactive_elements` in the same session | CRITICAL |
| SC-MARIONETTE-004 | Failure path MUST capture `take_screenshots` + `get_logs` + `get_interactive_elements` BEFORE `disconnect` | CRITICAL |
| SC-MARIONETTE-005 | `MarionetteBinding` MUST be guarded by `kDebugMode && !DISABLE_MARIONETTE` — never in release | CRITICAL |
| SC-MARIONETTE-006 | `extractText` callback MUST take `Element` (0.5.x); apps still passing `Widget` MUST migrate | HIGH |
| SC-MARIONETTE-007 | Custom VM extensions MUST be enumerated via `list_custom_extensions` and documented in the app's `MARIONETTE_EXTENSIONS.md` | HIGH |
| SC-MARIONETTE-008 | CI MUST use `marionette_cli` (not raw VM Service) so events publish to `indrajaal/l5/test/marionette/**` via the same bridge | HIGH |
| SC-MARIONETTE-009 | `record-video` artefacts MUST be persisted under `docs/cache/marionette/<run_id>/` and referenced from the journal | MEDIUM |
| SC-MARIONETTE-010 | `marionette_mcp` and `marionette_cli` SHOULD be activated globally at session start (`dart pub global activate ...`) — agent-driven hook may run this | HIGH |
| SC-MARIONETTE-011 | `version.g.dart` parity check MUST run before publishing or pinning the local clone — borrow upstream CI gate | MEDIUM |
| SC-MARIONETTE-012 | Marionette events MUST share the SC-PATROL-MCP envelope schema (urn, run_id, phase, payload) — single vocabulary | CRITICAL |

## 6. Default Marionette workflow (mandatory order)

1. **Boot** the app: `flutter run -d <platform> --debug -t integration_test/marionette/marionette_runner.dart` (Marionette ON by default per SC-PATROL-MCP-013).
2. **Connect**: `mcp__marionette__connect(uri)`.
3. **Discover**: `mcp__marionette__get_interactive_elements()` — capture into `docs/cache/marionette/<run_id>/00-tree.json`.
4. **Drive**: tap / long_press / enter_text / swipe / pinch_zoom — each preceded by another `get_interactive_elements` if the screen changed.
5. **Capture**: `take_screenshots()` after every state-changing action; `get_logs()` at the boundary of each test.
6. **Hot-reload** during authoring iteration to converge selectors without losing state.
7. **Custom extensions**: `list_custom_extensions()` once at session start; record into `MARIONETTE_EXTENSIONS.md`.
8. **Disconnect**: always — failure path included.
9. **Publish** on `indrajaal/l5/test/marionette/<run_id>/<phase>` with the OTel envelope.
10. **Persist**: `docs/cache/marionette/<run_id>/{tree.json, screenshots/, logs.txt, video.mp4}`; link from the journal.

## 7. Anti-patterns (BLOCKING)

1. **Tap before discovery** — every test must call `get_interactive_elements` before its first tap/text. Violation = SC-MARIONETTE-003.
2. **Swallowing failures** — passing a test "because it ran" with no screenshot/log assertion. Violation = SC-MARIONETTE-004.
3. **Marionette in release builds** — guard MUST be `kDebugMode && !DISABLE_MARIONETTE`. Violation = SC-MARIONETTE-005.
4. **Selector via grep** — looking up keys by reading widget source instead of attaching. Violation = SC-MARIONETTE-003 + [zk-bb4de67d97f807ac].
5. **Bypassing the CLI in CI** — calling raw VM Service from a shell loop, skipping the Zenoh envelope. Violation = SC-MARIONETTE-008.

## 8. Cross-references

- `.claude/rules/patrol-mcp-zenoh.md` — Patrol+Marionette joint protocol.
- `.claude/agents/marionette-explorer.md` — discovery + authoring agent (this rule's primary executor).
- `.claude/agents/patrol-test-agent.md` — Patrol regression executor.
- `.claude/commands/marionette-explore.md` — operator-invocable workflow.
- `.claude/commands/patrol-marionette-test.md` — joint Patrol+Marionette workflow.
- `sub-projects/marionette_mcp/` — local mirror of upstream (`leancodepl/marionette_mcp`).
- `sub-projects/sutra/fluffychat/integration_test/marionette/CATALOG.md` — 200-test FluffyChat catalog.

## 9. Fractal layer integration (L0 → L7)

| Layer | Marionette role | Concrete artefact |
|---|---|---|
| L0 Constitutional | Discovery-first invariant + debug-mode guard = Ψ-2 (Reversibility) and Ψ-3 (Verification) anchors | SC-MARIONETTE-003, SC-MARIONETTE-005 |
| L1 Atomic / NIF | VM Service extensions registered in `marionette_flutter` (per-tool entrypoints) | `packages/marionette_flutter/lib/src/binding/marionette_binding.dart` |
| L2 Component | `MarionetteConfiguration` (logCollector, maxScreenshotSize, isInteractiveWidget callbacks) | `MarionetteConfiguration` |
| L3 Transaction | Per-test envelope (Envelope value-type) and per-session flag-file state | `/tmp/marionette-discovery-${SESSION}.flag` |
| L4 System | `mcp__marionette__*` tools surfaced as MoZ tools, bridged to Zenoh by `tool/patrol-zenoh-bridge.sh` | `.claude/scripts/patrol-zenoh-bridge.sh` |
| L5 Cognitive | `marionette-explorer` agent + `/marionette-explore` skill drive OODA loops in test authoring | `.claude/agents/marionette-explorer.md` |
| L6 Ecosystem | Zenoh topic family `indrajaal/l5/test/marionette/**` consumable by dashboard, FMEA aggregator, KPI rollup | dashboard live tile (planned) |
| L7 Federation | Multi-app reuse: every Flutter sub-project (FluffyChat, future clients) inherits SC-MARIONETTE-* | this rule + per-app `MARIONETTE_EXTENSIONS.md` |

## 10. RETE-UL GRL rules (L5 cognitive)

These rules join the existing 52 GRL rules in `lib/cepaf_gleam/src/cepaf_gleam/rules/engine.gleam` (domain: test orchestration). Salience values reserve 60–95 (test-tier).

| Rule | Salience | When | Then |
|---|---:|---|---|
| `MarionetteDiscoveryFirst` | 95 | tool ∈ {tap,double_tap,long_press,enter_text,swipe,pinch_zoom,scroll_to,press_back_button} ∧ session.discovery_seen == false | emit warning + log to Zenoh; recommend `get_interactive_elements` |
| `MarionetteReleaseBlock` | 95 | session.build_mode != debug | hard refuse + apoptosis on the binding |
| `MarionetteFailureCapture` | 90 | test.outcome == failed ∧ (screenshots == 0 ∨ logs == 0 ∨ native_tree == ∅) | block disconnect; force capture |
| `MarionetteParityRequired` | 85 | test.tag == "*" ∧ executed_platforms ⊊ {android,linux,chrome} | mark run incomplete; reschedule missing platforms |
| `MarionetteLogCollectorMissing` | 80 | session opens ∧ binding.logCollector == none | emit P2 advisory: degraded `get_logs` payload |
| `MarionetteCustomExtRegistered` | 75 | extensions discovered ∧ MARIONETTE_EXTENSIONS.md missing | open task: document in app/MARIONETTE_EXTENSIONS.md |
| `MarionetteSelectorDrift` | 75 | get_interactive_elements diff vs. baseline > 30% (Hamming) | flag P1 selector drift; pause CATALOG runs for the screen |
| `MarionetteBackpressure` | 70 | Zenoh queue_depth(test/marionette/**) > 100 msgs | drop oldest screenshot frames, keep envelopes |
| `MarionetteFlakeQuarantine` | 65 | same TID failed ≥ 3 times in last 10 runs ∧ deterministic_seed == false | quarantine TID; require RCA before re-enable |
| `MarionetteEntropyFloor` | 60 | weekly Shannon H over 16-tool distribution < 2.5 bits | open task: broaden test mix; surface unused tools |

These rules are evaluated by the Rust rule engine on Zenoh events from `indrajaal/l5/test/marionette/**`.

## 11. Mathematical gates (L3+)

```
H(tool_distribution) = −Σ p_i log2(p_i)        ≥ 2.5 bits          ; Shannon entropy across 16 tools
CCM = Σ(w_i * cov_i) / Σ w_i                   ≥ 0.90              ; weighted coverage of {tap,gesture,text,capture,ext}
RPN = severity × occurrence × detection        action if ≥ 200     ; FMEA per failure mode
D(call_n)   = calls_since_last_discovery       ≤ 0                 ; discovery-first distance
S(run)      = (screenshots>0) ∧ (logs>0) ∧ (failure ⇒ tree≠∅)      ; evidence sufficiency, must hold
```

Weights for CCM: tap=1.0, gesture(double_tap+long_press+swipe+pinch_zoom+press_back+scroll_to)=1.5, text=1.0, capture(screenshot+logs)=2.0, custom_ext(list+call)=1.0.

## 12. Ruliology (Wolfram-style behavioural classification)

| Cellular-rule analogue | Surface | Action |
|---|---|---|
| Rule 30 (chaos) | rolling Shannon entropy on 50-run failure phase sequence > 1.5 bits | pause queue, P0 alert (matches `Rule30_FailureChaos` in ruliology.rs) |
| Rule 110 (complexity emergence) | 3-call sliding window of tools — classify into {regression, exploration, replay, chaos, monitoring} | tag the run; route to right rollup |
| Rule 184 (traffic / backpressure) | Zenoh queue depth on `test/marionette/**` | drop screenshot frames first, keep envelopes |
| Causal graph | nodes=TestRun, edges=shared_selector ∨ shared_extension ∨ shared_fixture | blast-radius analysis on selector drift |

Maps onto existing `native/planning_daemon/src/ruliology.rs` (929 LOC) — no new Rust required, just new event topics to subscribe.

## 13. FMEA (worst rows; full table in journal)

| Failure mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| Selector guess passes test silently | 9 | 6 | 4 | **216** | SC-MARIONETTE-003 + flag-file hook + Hamming drift detector |
| Marionette enabled in release build | 10 | 2 | 7 | **140** | SC-MARIONETTE-005 + `kDebugMode` guard |
| Failed test without screenshot/logs | 8 | 5 | 3 | **120** | SC-MARIONETTE-004 + force-capture before disconnect |
| Single-platform regression slips | 7 | 5 | 4 | 140 | SC-PATROL-MCP-005 + parity rule |
| `get_logs` returns hint instead of logs | 5 | 7 | 3 | 105 | SC-MARIONETTE-002 + `LoggingLogCollector` mandatory |
| Hot-reload clears flag-file → false anti-pattern alarm | 4 | 5 | 3 | 60 | hook keyed on session id, not reload count |

Action threshold: RPN ≥ 200 → **immediate**. Currently 1 row above threshold; mitigated by hook + Hamming detector.

## 14. Formal spec & verification

- Allium behavioural spec: `specs/allium/marionette_mcp.allium` — entities, transitions, contracts, invariants, math constructs, ruliology, RETE-UL bindings (this rule's source of truth).
- Apalache/TLA+ stub (planned): `specs/tla/MarionetteSession.tla` — model-checks `DiscoveryBeforeDrive` and `EvidenceForFailure` invariants under fault injection.
- Verification command (when TLA+ stub lands):
  `dotnet exec apalache check --inv DiscoveryBeforeDrive specs/tla/MarionetteSession.tla`

## 15. Governance parity

Mirror this file at `.gemini/rules/marionette-mcp-flutter-testing.md` (next sync per SC-SYNC-DOC-007).
