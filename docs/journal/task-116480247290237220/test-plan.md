# Marionette MCP — Phase-wise Test Plan, All Fractal Layers

> Task page: https://vm-1.tail55d152.ts.net:4200/task-id/116480247290237220/
> Companion: `CATALOG.md` (200 functional tests of FluffyChat). This document is *orthogonal*: it covers the **infrastructure, governance, and fractal-symbiosis** verification surface — i.e. what proves Marionette MCP is correctly wired into C3I across L0–L7.
> ZK refs: [zk-bb4de67d97f807ac], [zk-7471e209711463b9], [zk-7c17f7c4dd5b33ed], [zk-760707ed823d9843]

## Coverage matrix — phase × fractal layer

|  | L0 Const. | L1 Atomic | L2 Comp. | L3 Trans. | L4 System | L5 Cog. | L6 Eco. | L7 Fed. |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **P0 Smoke** | ✓ | ✓ | ✓ | – | ✓ | – | – | – |
| **P1 Unit** | ✓ | ✓ | ✓ | ✓ | – | – | – | – |
| **P2 Integration** | ✓ | – | ✓ | ✓ | ✓ | ✓ | – | – |
| **P3 E2E** | – | – | – | ✓ | ✓ | ✓ | ✓ | – |
| **P4 Cross-screen** | – | – | – | ✓ | ✓ | ✓ | ✓ | – |
| **P5 Multi-platform** | – | – | – | ✓ | ✓ | ✓ | ✓ | – |
| **P6 Chaos / FMEA** | ✓ | ✓ | – | ✓ | ✓ | ✓ | ✓ | ✓ |
| **P7 Performance** | – | ✓ | – | ✓ | ✓ | – | ✓ | – |
| **P8 Formal** | ✓ | – | ✓ | ✓ | – | – | – | ✓ |
| **P9 Regression** | – | – | – | ✓ | ✓ | ✓ | ✓ | ✓ |

47 cells filled / 80 = **58.8%** Marionette-relevant fractal coverage; remaining cells are owned by other test channels (Patrol regression, Wallaby E2E for non-Flutter, Rust unit tests, etc.).

---

## P0 — Smoke (≤ 5 tests · ≤ 2 min · pre-merge gate)

Run before any other phase. If P0 fails, stop.

| # | Layer | Test | Tool | Pass |
|---|---|---|---|---|
| P0.1 | L4 | `marionette_mcp` discoverable | `dart pub global list \| grep marionette_mcp` | exit 0 + version printed |
| P0.2 | L4 | `marionette_cli` discoverable | `dart pub global list \| grep marionette_cli` | exit 0 |
| P0.3 | L1 | Upstream clone integrity | `test -f sub-projects/marionette_mcp/packages/marionette_mcp/lib/src/vm_service/vm_service_context.dart` | file present |
| P0.4 | L0 | Allium spec parses | manual `cat specs/allium/marionette_mcp.allium \| head -1` returns `-- allium: 3` | yes |
| P0.5 | L4 | settings.json valid JSON post-edit | `jq empty .claude/settings.json` | exit 0 |

## P1 — Unit (≤ 30 tests · ≤ 5 min · per-package)

Hits each Marionette package in isolation. Reuses upstream `dart test` + `flutter test`.

| # | Layer | Package / target | Test class |
|---|---|---|---|
| P1.1–.6 | L1 | `marionette_flutter` | binding initialization, configuration callbacks, screenshot resize, log store, element matcher precedence, custom-extension registration |
| P1.7–.14 | L1 | `marionette_mcp` | tool registration, parameter validation, VM service round-trip, error mapping (ConnectError/TapError/EnterTextError), version compat probe |
| P1.15–.20 | L1 | `marionette_cli` | sub-command parsing, instance registry, ADB helper, --uri stateless mode, video transport TCP fallback, `help-ai` JSON shape |
| P1.21–.24 | L2 | `marionette_logging` | LoggingLogCollector start/stop, log capture, hot-reload clear |
| P1.25–.28 | L2 | `marionette_logger` | LoggerLogCollector dual interface, MultiOutput integration |
| P1.29–.30 | L0 | `MarionetteBinding` debug-only guard | release-mode build refuses to initialize |

Driver: upstream CI workflow already runs these; mirror locally with `cd sub-projects/marionette_mcp && melos test` (or per-package `dart test` / `flutter test`).

## P2 — Integration (≤ 25 tests · ≤ 10 min · MCP wiring + flag-file guard)

These test the **glue between Marionette and C3I governance**.

| # | Layer | Scenario | Pass criteria |
|---|---|---|---|
| P2.1 | L4 | MCP server boots via `.mcp.json` and exposes 16 tools | `mcp__marionette__list_custom_extensions` returns success when no extensions |
| P2.2 | L3 | SC-MARIONETTE-003 flag-file primed by `connect` | `/tmp/marionette-discovery-${SESSION}.flag` exists |
| P2.3 | L3 | SC-MARIONETTE-003 flag-file primed by `get_interactive_elements` | flag present |
| P2.4 | L0 | SC-MARIONETTE-003 violation: `tap` before any discovery → warning | system message contains "SC-MARIONETTE-003" |
| P2.5 | L3 | flag-file cleared on `disconnect` | file removed |
| P2.6 | L3 | flag-file persists across `hot_reload` | unchanged |
| P2.7 | L4 | SessionStart probe surfaces marionette globals state | systemMessage emitted |
| P2.8–.12 | L5 | `marionette-explorer` agent reads Allium → refuses uncovered actions | refusal logged |
| P2.13–.16 | L4 | `marionette_cli` ↔ MCP tool parity (each kebab-case sub-command produces same result as MCP equivalent) | identical responses |
| P2.17–.20 | L2 | `MarionetteConfiguration` honoured: `maxScreenshotSize` clamps; `isInteractiveWidget` exposes custom widget | screenshot ≤ size; element listed |
| P2.21–.25 | L6 | Zenoh envelope shape matches schema | jsonschema validate passes; required keys present |

## P3 — End-to-end functional (200 tests / `CATALOG.md`)

The 200 catalog tests in `sub-projects/sutra/fluffychat/integration_test/marionette/CATALOG.md`. Phase P3 = run all 200 against a debug FluffyChat. Group ranges per `manifest.json`.

Prerequisite: P0–P2 green. Evidence: `docs/cache/marionette/<run_id>/`.

## P4 — Cross-screen multi-page flows (T189–T196 of CATALOG)

Composite end-to-end flows that span ≥3 screens. Already enumerated in CATALOG. Phase P4 = drive these as a single session per scenario, asserting multi-screen state continuity.

## P5 — Multi-platform parity (SC-PATROL-MCP-005)

Every starred (`*`) test in CATALOG.md MUST run on Android + Linux + Chrome. Counts:

| Platform | Tests scheduled |
|---|---:|
| Android (`A` or `*`) | ~165 |
| Linux (`L` or `*`) | ~180 |
| Chrome / Web (`W` or `*`) | ~155 |

Verification: `marionette_cli record-video` per platform; envelopes on `indrajaal/l5/test/marionette/<run_id>/<phase>` show all 3 `platform=` values for any starred T-ID.

## P6 — Chaos / FMEA injection (8 tests, FMEA-driven)

Each fault corresponds to a row in journal §8.5 FMEA table.

| # | Failure mode | Injection | Expected mitigation fires |
|---|---|---|---|
| P6.1 | Selector guess passes silently | author a tap with a fabricated key, skip discovery | SC-MARIONETTE-003 hook warning; `MarionetteSelectorDrift` rule fires |
| P6.2 | Marionette in release | build app `--release`, attempt connect | `MarionetteReleaseBlock` rule + Dart guard refuses |
| P6.3 | Failed test no evidence | force exception, skip capture | `FailurePathCapture` invariant violated → ZK alert |
| P6.4 | Single-platform regression | run starred test only on Linux | `MarionetteParityRequired` rule; CI fails |
| P6.5 | `get_logs` returns hint | omit `logCollector` | `LogCollectorPresence` advisory P2 |
| P6.6 | Hot-reload during driving | `hot_reload` mid-test | flag-file unchanged; session id stable |
| P6.7 | Backpressure | spam 200 screenshot calls | `MarionetteBackpressure` Rule 184 drops oldest frames |
| P6.8 | Flake quarantine | force same TID to fail 3/10 runs | `MarionetteFlakeQuarantine` rule blocks re-run, opens RCA |

## P7 — Performance (4 tests · L1+L4+L6)

| # | Layer | Test | SLO |
|---|---|---|---|
| P7.1 | L1 | `get_interactive_elements` round-trip | p50 < 200 ms / p95 < 500 ms on a 100-widget screen |
| P7.2 | L1 | `take_screenshots` (1600×1600) | p50 < 400 ms |
| P7.3 | L4 | MCP tool dispatch overhead | < 30 ms per call (excluding device work) |
| P7.4 | L6 | Zenoh publish latency | p99 < 100 ms (matches SC-ZENOH-004) |

Tools: `marionette_cli` with `--time` flag; `time` builtin; `zenoh-cli` to subscribe. Persist as `docs/cache/marionette/perf-<run_id>.csv`.

## P8 — Formal verification (5 obligations)

| # | Obligation | Tool | Status |
|---|---|---|---|
| P8.1 | Allium `DiscoveryBeforeDrive` invariant holds | manual review of spec; runtime enforced by hook | ✓ |
| P8.2 | Allium `EvidenceForFailure` invariant holds | runtime enforced; needs assertion harness | partial |
| P8.3 | TLA+ `MarionetteSession` model checks (Apalache) | `apalache check --inv DiscoveryBeforeDrive` | TODO (gap) |
| P8.4 | RETE-UL salience non-collision (60–95 reserved) | grep rules; visual review | ✓ |
| P8.5 | Allium↔code drift via `weed` | `allium weed specs/allium/marionette_mcp.allium` | TODO |

## P9 — Regression suite (continuous)

Aggregated CI run — all of P0+P2+P3 nightly, P5 weekly, P6 monthly. Owned by build-supervisor. Result published on `indrajaal/l5/test/marionette/regression/<date>` with KPI rollup to dashboard.

## Phase entry / exit gates

```
P0 (smoke)        ── pass ──▶ P1
P1 (unit)         ── pass ──▶ P2
P2 (integration)  ── pass ──▶ P3
P3 (e2e 200)      ── pass ──▶ P4
P4 (cross-screen) ── pass ──▶ P5
P5 (parity)       ── pass ──▶ P6 (chaos)
P6                ── pass ──▶ P7
P7                ── pass ──▶ P8
P8                ── pass ──▶ P9 (regression CI)
```

A phase fails fast on any test below its threshold; parent rolls up RPN to FMEA aggregator.

## Math gates per phase

| Phase | Shannon H ≥ | CCM ≥ | RPN < | Notes |
|---|:--:|:--:|:--:|---|
| P0 | n/a | n/a | 200 | smoke |
| P1 | 2.0 | 0.85 | 200 | per-package |
| P2 | 2.3 | 0.90 | 200 | governance |
| P3 | 2.5 | 0.90 | 200 | full catalog |
| P4 | 2.5 | 0.90 | 200 | composites |
| P5 | 2.5 | 0.90 | 200 | per-platform |
| P6 | n/a | n/a | (allowed to escalate) | chaos |
| P7 | n/a | n/a | 200 | perf |
| P8 | n/a | 1.00 | 100 | formal — strictest |
| P9 | 2.6 | 0.95 | 150 | regression |

## Owner mapping

| Phase | Owner |
|---|---|
| P0–P2 | `marionette-explorer` agent + CI runner |
| P3–P5 | `patrol-test-agent` + `marionette-explorer` (joint) |
| P6 | `safety-validator` agent |
| P7 | `code-reviewer` + manual perf engineer |
| P8 | `constitutional-verifier` agent |
| P9 | `build-supervisor` agent |
