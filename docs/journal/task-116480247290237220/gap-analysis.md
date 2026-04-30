# Marionette MCP — Gap Analysis: What's Still Missing, What Else Can Be Added

> Companion to `test-plan.md`. Pass-1 + pass-2 + pass-3 (this) covered: vendoring, governance (rule + agent + skill), 2 hooks, formal Allium spec, RETE-UL rules, ruliology classifiers, math gates, FMEA, dataflow + control flow + Zenoh topology + L0–L7 fractal matrix, journal + this publication package.
>
> This file is the honest inventory of *what we still owe*.

## A. Hard gaps (committed, tracked, must close before claiming complete)

| # | Gap | Why it matters | Owner | Tracker |
|---|---|---|---|---|
| A1 | **`LoggingLogCollector` not wired in FluffyChat `lib/main.dart`** | `get_logs` returns the built-in setup hint instead of real Dart `logging` output → SC-MARIONETTE-002 violated; degraded P3/P6 evidence quality | marionette-explorer first run | journal §14 gap #1 |
| A2 | **TLA+ stub `specs/tla/MarionetteSession.tla`** | Allium `DiscoveryBeforeDrive` and `EvidenceForFailure` invariants are runtime-enforced; we need Apalache model-checking under fault injection (P8.3) | constitutional-verifier | journal §14 gap #2 + test-plan P8.3 |
| A3 | **`.gemini/rules/marionette-mcp-flutter-testing.md` mirror** | SC-SYNC-DOC-007 governance parity; Gemini sessions don't get the rule | next sync pass | journal §14 gap #3 |
| A4 | **CI runner via `marionette_cli`** | SC-MARIONETTE-008 mandates CI uses CLI (not raw VM) so envelopes flow on Zenoh; nightly P9 regression has no scheduler yet | build-supervisor | journal §14 gap #4 |
| A5 | **Per-app `MARIONETTE_EXTENSIONS.md`** | SC-MARIONETTE-007 — populate via `list_custom_extensions` on first attach; FluffyChat has none; Element X / Sutra UI variants TBD | first run | journal §14 gap #5 |
| A6 | **Globally-activated `marionette_mcp` + `marionette_cli`** | `dart pub global activate marionette_mcp marionette_cli` — operator action; SessionStart probe will keep flagging until done | operator | journal §14 gap #8 |
| A7 | **Rust `evaluate_marionette()` rule dispatcher** | 10 GRL rules defined in `.claude/rules/...` are docs-only until they execute against `indrajaal/l5/test/marionette/**` events | code-evolution agent | journal §14 gap #6 |
| A8 | **Apalache CI gate** | even with A2 stub, CI must run `apalache check --inv DiscoveryBeforeDrive` | build-supervisor | journal §14 gap #7 |

## B. Soft gaps (nice-to-have, would strengthen the integration)

| # | Gap | Value |
|---|---|---|
| B1 | Marionette dashboard tile on Lustre cockpit | Live KPI: active sessions, pass-rate 24h, anti-pattern violations, last envelope |
| B2 | Selector-drift Hamming detector script | Compare `get_interactive_elements` snapshots run-over-run; emit drift metric |
| B3 | `marionette-explorer` ZK auto-cite | Inject relevant ZK holons into the agent's pre-flight context |
| B4 | Multimodal vision review pass | Pipe each `take_screenshots` through `tool/patrol-multimodal-review.sh` for UX-visual assertions (already exists for Patrol; extend to Marionette) |
| B5 | `marionette_cli help-ai` cached as Claude tool docs | Run once, persist into `.claude/tools-cache/marionette.json` so future agents have current help inline |
| B6 | Per-platform device farm runner | BrowserStack / Genymotion bridge so P5 doesn't need local emulators |
| B7 | Test-result Markov chain | Use the causal graph (CATALOG.md → shared selector edges) to predict next-likely failure when one test breaks |
| B8 | Formal Allium → Gleam codegen | Generate Gleam types/match exhaustiveness from `marionette_mcp.allium` to keep code↔spec drift = 0 |
| B9 | Per-test screencast (not just frames) | `marionette_cli record-video` already supports this; enable per-T-ID instead of per-session |
| B10 | Test pruning oracle | Use Shannon entropy of the live tree to identify redundant tests |

## C. Symbiosis with the rest of the system — what's NOT yet integrated

| Subsystem | Status | What's missing |
|---|---|---|
| **Patrol** | ✓ wired (existing rule + agent + skill) | nothing — Marionette is complementary |
| **Zenoh** | ✓ topic family + envelope schema | reverse advisory channel `indrajaal/l5/test/marionette/advisory/<rule>` not yet emitting (depends on A7) |
| **Smriti.db `session_metrics`** | ✓ Stop hook persists session row | per-test row insertion not yet done — tests are aggregated to session level |
| **Dashboard / Cockpit** | ✗ no Marionette tile yet | B1 above |
| **Pi-mono runtime** | ✓ can call `mcp__marionette__*` via MoZ | bridge tested only conceptually; real Pi RPC walk not run |
| **Gemini CLI** | partial | needs `.gemini/rules/` mirror (A3) and tool allowlist update |
| **OODA / Cortex** | ✓ rule_engine subscription planned | A7 — Rust dispatcher not yet written |
| **Ruliology** | ✓ classifiers documented | event topics not yet subscribed by `ruliology.rs` |
| **FMEA aggregator** | ✓ FMEA table in journal | aggregator service to roll RPN over time not implemented |
| **Build supervisor / CI** | ✗ no Marionette job in CI | A4 + A8 |
| **Allium tend/weed/distill agents** | ✓ spec exists | weed not yet run against `marionette_mcp.allium` (P8.5) |
| **HMI / Dark Cockpit** | ✗ | B1 |
| **Immune / chaos engineering** | partial | P6 chaos tests defined; not yet run by `immune-chaos-agent` |
| **Knowledge management (ZK)** | ✓ Stop hook ingests `.md` files | this pass-3's HTML/JSON should also be ingested (run `sa-plan-daemon ingest-docs` after) |
| **Constitutional verifier** | ✓ Ψ-2 / Ψ-3 hooks via Allium invariants | runtime hook in `evaluate_decision` not tied yet |
| **TPS Jidoka** | ✓ flag-file is the andon cord | autocheckpoint of `dart pub get` after pubspec edits not wired |

## D. What else *could* be added (over-the-horizon ideas)

1. **Marionette over WebSocket** — current MCP is stdio; an SSE/WebSocket transport mode would let a remote operator drive an emulator from the Tailscale dashboard.
2. **Cross-app state probes** — when two FluffyChat sessions are running (sender + receiver), run two `marionette_mcp` connections in parallel; assertions span both.
3. **AI-generated catalog updates** — feed `get_interactive_elements` deltas to Claude; auto-author new T-IDs when a screen gains widgets.
4. **Marionette as a security probe** — drive the app with adversarial inputs and watch `get_logs` for sentinel strings.
5. **Property-based testing layer** — instead of fixed sequences in CATALOG, use Hypothesis-style generators over `Tool` enum; Allium constraints prune invalid sequences.
6. **WASM Marionette** — for PWA / Lustre, port the binding API surface to a JS shim so Lustre pages can be Marionette-driven the same way.
7. **Snapshot diffing on the tree** — assert `get_interactive_elements(post) - get_interactive_elements(pre)` matches the expected delta per test step.
8. **Shadow-mode replay** — record a real user session (via `record-video` + log capture), then replay through Marionette to validate deterministic selectors.
9. **Autonomous drift recovery** — when `MarionetteSelectorDrift` rule fires, agent automatically re-runs `get_interactive_elements`, proposes diff, opens PR.
10. **Marionette extension for Pi-mono UI** — Pi has a Lustre / web-ui; treat it as a Flutter target via WASM bridge; identical agent experience.

## E. Risk-ordered priority for next sprint

```
P0  A1  Wire LoggingLogCollector              (cheap, unlocks P3/P6 evidence)
P0  A6  Activate marionette_mcp + cli         (cheap, unblocks any execution)
P1  A7  Rust evaluate_marionette() dispatcher (medium, unlocks rule_engine reverse channel)
P1  A4  CI runner via marionette_cli          (medium, gates regression)
P2  A2  TLA+ stub                             (medium, P8.3)
P2  A8  Apalache CI gate                      (small, depends on A2)
P2  A3  .gemini/rules mirror                  (small, governance hygiene)
P2  A5  MARIONETTE_EXTENSIONS.md per app      (small, on first run)
P3  B1  Dashboard tile                        (medium-large, CX win)
P3  B2  Selector drift detector               (small, plays into A7)
```

**Recommendation**: do A1 + A6 today (≤30 min combined). The rest is sprintable work for the next 1–2 weeks.

## F. Definition of "complete"

Marionette MCP integration is *complete* when:

1. All A-gaps are closed.
2. P0 → P9 of the test plan all green for FluffyChat.
3. ≥ 1 additional Flutter sub-project has adopted the rule + spec without modification (proves L7 federation).
4. The Lustre dashboard has a live Marionette tile (B1) showing real-session telemetry.
5. `MarionetteSelectorDrift` advisory has fired at least once and the system auto-recovered (validates A7 + B2).
6. A regression-suite KPI rollup graph exists on the dashboard with 30-day history.

Until these 6 hold, mark integration as *operational*, not *complete*.
