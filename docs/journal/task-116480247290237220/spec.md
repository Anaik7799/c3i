# Marionette MCP — Functional + Non-Functional Specification

> Task `116480247290237220`. Higher-level spec accompanying the formal Allium model at `specs/allium/marionette_mcp.allium`. Pattern: hyperscaler-grade FRD/NFRD + interface contract.

## 1. Functional requirements

| FR | Statement | Trace |
|---|---|---|
| FR-1 | Agent MUST be able to attach to a running debug Flutter app via VM Service URI. | `connect(uri)` |
| FR-2 | Agent MUST be able to detach cleanly. | `disconnect()` |
| FR-3 | Agent MUST be able to enumerate live interactive widgets (key, text, type, bounds). | `get_interactive_elements()` |
| FR-4 | Agent MUST be able to issue tap, double-tap, long-press, swipe, pinch-zoom, scroll-to, press-back. | gesture tools |
| FR-5 | Agent MUST be able to type into a field (by key) or into the focused element. | `enter_text` |
| FR-6 | Agent MUST be able to capture base64-PNG screenshots ≤ `maxScreenshotSize`. | `take_screenshots` |
| FR-7 | Agent MUST be able to drain captured logs since last reload. | `get_logs` |
| FR-8 | Agent MUST be able to hot-reload while preserving session state. | `hot_reload` |
| FR-9 | Agent MUST be able to enumerate and call app-registered VM extensions. | `list_custom_extensions`, `call_custom_extension` |
| FR-10 | Operator MUST be able to invoke `/marionette-explore <app> <flow>`. | skill |
| FR-11 | The system MUST publish OTel-style envelopes for each test phase on Zenoh. | SC-MARIONETTE-012 |
| FR-12 | The rule engine MUST be able to subscribe to `indrajaal/l5/test/marionette/**`. | SC-FRAC-RRF + RETE-UL |
| FR-13 | The CI runner MUST be able to drive any FR-1..FR-9 capability via `marionette_cli`. | SC-MARIONETTE-008 |

## 2. Non-functional requirements

| NFR | Category | Statement | SLO / Threshold |
|---|---|---|---|
| NFR-1 | Performance | `get_interactive_elements` round-trip on a 100-widget screen | p50 < 200 ms · p95 < 500 ms |
| NFR-2 | Performance | `take_screenshots` (1600×1600) | p50 < 400 ms |
| NFR-3 | Performance | MCP tool dispatch overhead | < 30 ms |
| NFR-4 | Performance | Zenoh publish latency | p99 < 100 ms (SC-ZENOH-004) |
| NFR-5 | Reliability | Per-session failure path always captures evidence before disconnect | 100% (Allium invariant) |
| NFR-6 | Reliability | Discovery-first hook fires for every gesture/text call | 100% (PostToolUse) |
| NFR-7 | Security | No invocation in release builds | enforced via `kDebugMode` |
| NFR-8 | Security | Marionette VM port not exposed beyond loopback in CI | docker/podman default + firewall |
| NFR-9 | Observability | Every test run emits ≥ 3 envelopes (start + outcome + quit) | Allium `ZenohEventCoverage` |
| NFR-10 | Coverage | Shannon H over 16-tool distribution | ≥ 2.5 bits |
| NFR-11 | Coverage | CCM (weighted coverage of {tap, gesture, text, capture, custom_ext}) | ≥ 0.90 |
| NFR-12 | Compliance | All A-gaps tracked with sa-plan task IDs | 10/10 (this pass) |
| NFR-13 | Sustainability | Evidence cache size growth | < 100 MB / 1000 runs (drop screenshot on backpressure, Rule 184) |
| NFR-14 | Federation | Rule reusable across Flutter sub-projects with zero changes | by inspection |
| NFR-15 | Auditability | Every state mutation captured in Smriti.db `session_metrics` | SC-LOG-001 |

## 3. Interface specification

### 3.1 MCP tool interface (16 tools, see Allium §3 for parameter types)

Stable. Versioned by upstream `marionette_mcp` package SemVer. Pinned at ^0.5.0 (FluffyChat `pubspec.yaml`).

### 3.2 Zenoh envelope schema (immutable)

```jsonc
{
  "at":          "ISO-8601 UTC timestamp",
  "source":      "claude-code | pi-runtime | gemini-cli | marionette_cli",
  "urn":         "urn:c3i:test:marionette:<app>:<TID>",
  "run_id":      "uuid-v4",
  "session_id":  "uuid-v4",
  "phase":       "start | screenshot | passed | failed | quit | violation",
  "platform":    "android | linux | chrome | macos | windows | ios",
  "test_target": "<file>:<TID>",
  "duration_ms": "integer",
  "payload":     { /* tool-specific */ }
}
```

Versioning: append-only fields under `payload`. Required keys never removed without a bump of the URN scheme version.

### 3.3 Hook contract

`PostToolUse` matcher `mcp__patrol__.*|mcp__marionette__.*` MUST:
1. Publish the envelope to `indrajaal/l5/test/marionette/<run_id>/<phase>` (delegated to `patrol-zenoh-bridge.sh`).
2. Maintain `/tmp/marionette-discovery-${SESSION}.flag` per Allium `DiscoveryFirstMandate`.

`SessionStart` MUST:
1. Probe `dart pub global list` for `marionette_mcp` and `marionette_cli`.
2. Surface the upstream-clone presence at `sub-projects/marionette_mcp/.git`.

### 3.4 Allium → code mapping

| Allium artefact | Code location |
|---|---|
| `entity MarionetteSession` | runtime state in `marionette_flutter` binding |
| `entity TestRun` | `docs/cache/marionette/<run_id>/` |
| `value type Envelope` | hook payload + `patrol-zenoh-bridge.sh` |
| `rule DiscoveryFirstMandate` | PostToolUse flag-file hook |
| `rule ReleaseModeBlock` | `lib/main.dart:60` `kDebugMode` guard |
| `rule FailurePathCapture` | marionette-explorer agent OODA pattern |
| `contract MarionetteMcpServer` | `sub-projects/marionette_mcp/packages/marionette_mcp/` |
| `contract MarionetteBinding` | `sub-projects/marionette_mcp/packages/marionette_flutter/` |
| `invariant ZenohEventCoverage` | `patrol-zenoh-bridge.sh hook` |

## 4. Out-of-spec (for clarity)

- Production telemetry pipelines (handled by SC-ZMOF-001 separately).
- Patrol regression scheduling (handled by `.claude/agents/patrol-test-agent.md`).
- Multimodal vision review (handled by `tool/patrol-multimodal-review.sh`).
- Pi-mono session orchestration (handled by `bridge/pi_runtime.gleam`).

## 5. Versioning & change control

- Spec version: 1.0.0 (this document).
- Breaking changes trigger `sa-plan add` task with `[Marionette spec breaking]` prefix.
- Allium `weed` tool MUST detect divergence between this spec and code (P8.5).
