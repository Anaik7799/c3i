# Patrol MCP + Marionette MCP + Zenoh Feedback Loop (SC-PATROL-MCP)

## Mandate
Flutter UI testing in C3I MUST use the dual-MCP stack:
1. **Patrol MCP** (`patrol_mcp`, ^0.x, by LeanCode) — orchestrates declarative Patrol tests across Android, iOS, Web (Chrome/Playwright), macOS, Windows.
2. **Marionette MCP** (`marionette_mcp`, ^0.5.0, by LeanCode) — drives a *running* Flutter app via VM Service for exploratory/authoring sessions on Linux desktop, Web, mobile.

Every MCP tool call MUST publish an OTel-flavored envelope onto Zenoh under
`indrajaal/l5/test/{patrol|marionette}/<urn>/<phase>` so the cortex,
dashboard, and Pi runtime get a closed feedback loop without polling.

## Why both?
| Tool | Role | When |
|------|------|------|
| **Patrol MCP** | Run a written test, get screenshot + native tree + status | Regression / CI |
| **Marionette MCP** | Live introspection of a running app — tap, enter, scroll, screenshot, logs, hot-reload | Test authoring, debugging |

A common workflow is: Marionette to *discover* selectors → write Patrol test → Patrol MCP to *verify* across platforms.

## Patrol MCP — exposed tools
| MCP Tool | Action |
|---|---|
| `mcp__patrol__run` | Execute a Patrol test file (hot-restart capable) |
| `mcp__patrol__screenshot` | Capture device screen (auto-resized 800px) |
| `mcp__patrol__native-tree` | Trimmed native UI hierarchy (Android/iOS) |
| `mcp__patrol__status` | Current session state + recent stdout |
| `mcp__patrol__quit` | Stop the Patrol session |

Env vars: `PATROL_FLAGS`, `PROJECT_ROOT`, `SHOW_TERMINAL`. Launcher: `tool/run-patrol.sh`.

## Marionette MCP — exposed tools
| MCP Tool | Action |
|---|---|
| `mcp__marionette__connect` | Attach to a running app via VM Service URI |
| `mcp__marionette__get_interactive_elements` | List tappable widgets |
| `mcp__marionette__tap` | Tap by key or text |
| `mcp__marionette__enter_text` | Type into a focused field |
| `mcp__marionette__scroll_to` | Scroll until target visible |
| `mcp__marionette__take_screenshots` | Base64 image |
| `mcp__marionette__get_logs` | App log stream |
| `mcp__marionette__hot_reload` | Apply latest code |

`MarionetteBinding.ensureInitialized()` MUST be the *only* binding in `main.dart` (debug-mode only). VM Service URI must be passed at attach time.

## Default Mode: Marionette ON (SC-PATROL-MCP-013)
**Marionette MCP is enabled by default** in every debug build. The default
operator workflow `flutter run -d <platform> --debug` boots into
`MarionetteBinding`, exposing the VM Service for AI-driven introspection
without any extra flags.

Patrol test runs are the *only* path that disables Marionette — they inject
`--dart-define=DISABLE_MARIONETTE=true` automatically via `tool/run-patrol`
and `patrol-zenoh-bridge.sh`, because Patrol's framework initializes its own
binding (per `marionette_flutter` docs: "MarionetteBinding must be the only
binding initialized in the process").

Operators never set `DISABLE_MARIONETTE` manually.

## Pinned versions (latest verified 2026-04-26)
| Package | Version | Source |
|---|---|---|
| `patrol` | ^4.5.0 | pub.dev/packages/patrol |
| `patrol_mcp` | ^0.1.3 | pub.dev/packages/patrol_mcp |
| `marionette_flutter` | ^0.5.0 | pub.dev/packages/marionette_flutter |
| `marionette_mcp` | ^0.5.0 | pub.dev/packages/marionette_mcp |

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PATROL-MCP-001 | All Flutter UI tests MUST be runnable through Patrol MCP `run` tool | CRITICAL |
| SC-PATROL-MCP-002 | Test authoring sessions MUST use Marionette MCP for selector discovery (no manual guessing) | HIGH |
| SC-PATROL-MCP-003 | Every Patrol/Marionette MCP tool call MUST emit a Zenoh event on `indrajaal/l5/test/**` | CRITICAL |
| SC-PATROL-MCP-004 | Zenoh test events MUST follow the OTel envelope (at, source, urn, run_id, phase, payload) | HIGH |
| SC-PATROL-MCP-005 | Triple-platform parity: a feature MUST be verified on Android + Linux + Web before close | CRITICAL |
| SC-PATROL-MCP-006 | `MarionetteBinding` initialization MUST be guarded by `kDebugMode && !DISABLE_MARIONETTE` | CRITICAL |
| SC-PATROL-MCP-007 | Patrol MCP screenshots and native-tree dumps MUST be persisted under `docs/cache/patrol/<run_id>/` | HIGH |
| SC-PATROL-MCP-008 | Failed tests MUST trigger a `mcp__patrol__screenshot` + `mcp__patrol__native-tree` capture before `quit` | CRITICAL |
| SC-PATROL-MCP-009 | Test results (pass/fail/duration) MUST be persisted to `session_metrics` table on session end | HIGH |
| SC-PATROL-MCP-010 | Patrol/Marionette CLI fallback (no MCP) MUST publish identical Zenoh envelopes via `tool/patrol-zenoh-bridge.sh` | HIGH |
| SC-PATROL-MCP-011 | Web tests MUST set `--web-headless --web-video --web-reporter html` in CI | HIGH |
| SC-PATROL-MCP-012 | `iOS` runs MUST use `--full-isolation` to avoid the 360s timeout limitation | MEDIUM |
| SC-PATROL-MCP-013 | Marionette MCP is ON by default in debug builds; only Patrol runs opt out via DISABLE_MARIONETTE | CRITICAL |

## Zenoh Topic Vocabulary (SC-PATROL-MCP-003 / -004)

```
indrajaal/l5/test/patrol/<run_id>/start
indrajaal/l5/test/patrol/<run_id>/screenshot
indrajaal/l5/test/patrol/<run_id>/native-tree
indrajaal/l5/test/patrol/<run_id>/status
indrajaal/l5/test/patrol/<run_id>/passed
indrajaal/l5/test/patrol/<run_id>/failed
indrajaal/l5/test/patrol/<run_id>/quit
indrajaal/l5/test/marionette/<session_id>/connect
indrajaal/l5/test/marionette/<session_id>/tap
indrajaal/l5/test/marionette/<session_id>/enter_text
indrajaal/l5/test/marionette/<session_id>/scroll_to
indrajaal/l5/test/marionette/<session_id>/screenshot
indrajaal/l5/test/marionette/<session_id>/logs
indrajaal/l5/test/marionette/<session_id>/hot_reload
```

Envelope (JSON):
```json
{
  "at": "2026-04-26T07:00:00.000Z",
  "source": "claude-code",
  "urn": "urn:c3i:test:patrol:<project>:<run_id>",
  "run_id": "<uuid>",
  "phase": "passed|failed|screenshot|...",
  "platform": "android|ios|chrome|linux|macos|windows",
  "test_target": "integration_test/patrol_test.dart",
  "duration_ms": 12345,
  "payload": { ...tool-specific... }
}
```

## Anti-Patterns (BLOCKING)
1. **Authoring tests by guessing selectors** — must use `mcp__marionette__get_interactive_elements` first.
2. **Single-platform regression** — Android-only or Web-only is incomplete (SC-PATROL-MCP-005).
3. **Bypassing the bridge** — calling `patrol test` from a shell without telemetry publication.
4. **Running Marionette in release** — VM service is unavailable; binding will throw.
5. **Stale screenshots** — failure path must always recapture before `quit`.

## Integration Cross-References
- SC-PATROL-001..002 (Patrol triple-platform setup) — established by `patrol-testing.md` runbook.
- SC-ZMOF-001 (Zenoh sole transport) — test events ride the same backplane.
- SC-SCHED-TELE-MANDATORY (URN + timeout guard) — patrol runs are subprocesses, must use ProcessRunner via `tool/run-patrol.sh`.
- SC-PI-AUTO-003 (tool federation) — Patrol/Marionette MCP tools count toward the 93+ federated tool target.
- SC-FEAT-EVO-013 (visual evidence) — Patrol screenshots satisfy this requirement.

## OODA Loop with MCP+Zenoh
```
Observe   → mcp__marionette__get_interactive_elements + mcp__patrol__native-tree
Orient    → ZK recall via UserPromptSubmit hook + last test envelope on Zenoh
Decide    → write/edit patrol_test.dart based on discovered selectors
Act       → mcp__patrol__run (publishes start, screenshots, status)
Verify    → consume Zenoh /passed or /failed; if failed, recurse with Marionette
```
