# Dart + Flutter AI/MCP Integration (SC-DART-MCP)

> Companion to `.claude/rules/marionette-mcp-flutter-testing.md` and `.claude/rules/patrol-mcp-zenoh.md`. Where those govern the *runtime UI* surface, this rule governs the *dev-tooling* MCP surface and the *in-app* AI toolkit. ZK refs: [zk-bb4de67d97f807ac], [zk-3e3c45be5cbff3ba], [zk-15fdb070d421e38b].

## 1. Mandate

Three Dart/Flutter AI surfaces are first-class in C3I:

| Surface | Layer | What it is | URL |
|---|---|---|---|
| **dart_mcp_server** | dev-tooling MCP (covers Dart **and** Flutter) | analyze, fix, format, test, pub, hot-reload, widget-inspector, dtd, runtime errors, app logs | https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server |
| **flutter_ai_toolkit** v1.0.0 | in-app chat-UI package | `LlmChatView`, `FirebaseProvider`/Vertex AI; multiturn, streaming, voice, function-calling | https://docs.flutter.dev/ai/ai-toolkit |
| (Flutter MCP) | unified — there is **no separate** Flutter MCP server | Flutter capabilities ride inside `dart_mcp_server` | https://docs.flutter.dev/ai/mcp-server |

These coexist with `marionette_mcp` (runtime UI) and `patrol_mcp` (test automation) — different fractal layers, no conflict.

## 2. Tool surface — dart_mcp_server (≈22 tools, 11 default-on)

| Category | Tools |
|---|---|
| Static analysis / fix | `analyze_files`, `dart_fix`, `dart_format` |
| Test runner | `run_tests` |
| Runtime (Flutter) | `hot_reload`, `hot_restart`, `dtd`, `get_runtime_errors`, `get_app_logs`, `widget_inspector`, `flutter_driver_command` |
| Pub / packages | `pub`, `pub_dev_search`, `read_package_uris`, `rip_grep_packages` |
| Project | `roots`, `create_project`, `list_devices`, `launch_app`, `stop_app`, `list_running_apps` |
| LSP | hover, signatures, symbols (via Dart Tooling Daemon) |

Activation:
```bash
dart mcp-server          # foreground (stdio)
# .claude/settings.json mcpServers entry: { "dart": { "type": "stdio", "command": "dart", "args": ["mcp-server"] } }
```

Requires Dart 3.9+ (experimental channel ok).

## 3. STAMP constraints

| ID | Constraint | Severity |
|---|---|---|
| SC-DART-MCP-001 | `dart_mcp_server` MUST be configured in `.claude/settings.json` mcpServers as `dart` | HIGH |
| SC-DART-MCP-002 | Read-only Dart tools (`analyze_files`, `dart_format`, `pub`) MUST be allow-listed for low-friction agent use | HIGH |
| SC-DART-MCP-003 | Mutating tools (`dart_fix`, `hot_restart`, `stop_app`) MUST require explicit operator confirmation in production-touching scopes | CRITICAL |
| SC-DART-MCP-004 | `dart_mcp_server` MUST NOT be invoked against a release-mode binary (mirrors SC-MARIONETTE-005) | CRITICAL |
| SC-DART-MCP-005 | Activation status MUST be probed at SessionStart alongside Marionette (`dart_mcp_server`, `marionette_mcp`, `marionette_cli`, `patrol_mcp`) | HIGH |
| SC-DART-MCP-006 | Dart MCP tool calls MUST publish OTel envelopes to `indrajaal/l5/dev/dart/<tool>/<id>` (parallel family to test/marionette) | HIGH |
| SC-DART-MCP-007 | When `flutter_ai_toolkit` is added to a Flutter sub-project, the chosen LLM provider MUST be PII-scrubbed via existing C3I scrubber (SC-SEC-003) | CRITICAL |
| SC-DART-MCP-008 | `flutter_ai_toolkit` MUST NOT bypass C3I cortex circuit-breakers (SC-PI-004) — provider calls flow through the Pi runtime when possible | HIGH |
| SC-DART-MCP-009 | The four MCP servers (`dart`, `patrol`, `marionette`, `flutter_ai_toolkit` consumers) MUST coexist without tool-name collision; namespace prefix `mcp__<server>__` enforces this | CRITICAL |
| SC-DART-MCP-010 | Dart MCP `widget_inspector` results MAY be cached in `docs/cache/dart-mcp/<run_id>/` for replay; cache must respect 100 MB limit | MEDIUM |

## 4. Coexistence with Marionette + Patrol

| Surface | Role | Layer |
|---|---|---|
| `dart_mcp_server` | dev tooling (static + runtime introspection of debug app) | L1 NIF / L4 system |
| `marionette_mcp` | live UI driving (gestures, widget tree, screenshots) | L4 system / L5 cognitive |
| `patrol_mcp` | regression test runner orchestration | L5 cognitive |
| `flutter_ai_toolkit` | end-user chat UI inside a Flutter app | L7 federation (consumer) |

Use them like a Russian doll:
- **Patrol** runs the test → starts a Flutter debug session.
- **Marionette** discovers selectors and drives the running app.
- **dart_mcp_server** runs `analyze_files`, `dart_fix`, `hot_reload` on the same workspace.
- **flutter_ai_toolkit** is what the user *experiences* — and what Marionette tests.

All four MCP servers tolerated simultaneously; tool names auto-namespaced as `mcp__dart__*`, `mcp__marionette__*`, `mcp__patrol__*`. No collision.

## 5. AI toolkit integration (when added to a Flutter sub-project)

For any Flutter app under `sub-projects/` that adopts `flutter_ai_toolkit`:

```dart
// pubspec.yaml additions
dependencies:
  flutter_ai_toolkit: ^1.0.0
  firebase_core: latest
  firebase_ai: latest
```

```dart
// usage — chat surface
LlmChatView(
  provider: FirebaseProvider(
    model: FirebaseAI.vertexAI().generativeModel(model: 'gemini-2.5-flash'),
  ),
)
```

C3I-specific wrapping required:
1. **Provider chooser** — route through Pi runtime (`bridge/pi_runtime.gleam`) so SC-PI-004 circuit-breakers apply.
2. **PII scrubber** — call into existing Rust `pii.rs` before sending prompts (SC-SEC-003).
3. **OTel emit** — publish each prompt/response on `indrajaal/l5/cog/aitoolkit/<session>/<turn>` for audit.
4. **Marionette test coverage** — every `LlmChatView` instance MUST have at least one CATALOG.md row exercising input → response → cite.

## 6. Test plan deltas

Add to `test-plan.md` (separate task; not done in this rule):

- **P1 Unit (dart_mcp)**: `dart_mcp_server` per-tool happy path × 22 tools.
- **P2 Integration**: dart MCP + marionette MCP attached to *same* Flutter process — verify no VM Service contention.
- **P3 E2E**: when `flutter_ai_toolkit` is in app, run `LlmChatView` flow under Marionette.
- **P6 Chaos**: kill `dart_mcp_server` mid-session, verify Marionette + Patrol still work.

## 7. Activation runbook

```bash
# Prereqs
dart --version                                    # ≥ 3.9
flutter --version

# Activate the four MCP servers
dart pub global activate marionette_mcp marionette_cli patrol_mcp   # already tracked as task A6
dart mcp-server --help                            # confirms dart_mcp_server is bundled

# Add to .claude/settings.json mcpServers (this rule's responsibility):
#   "dart": { "type": "stdio", "command": "dart", "args": ["mcp-server"] }

# Verify
mcp__dart__analyze_files                          # should return analysis result
mcp__dart__list_devices                           # should return attached devices

# OTel envelope topic
zenoh-cli sub 'indrajaal/l5/dev/dart/**'           # observe
```

## 8. Cross-references

- `.claude/rules/marionette-mcp-flutter-testing.md` (SC-MARIONETTE-001..012)
- `.claude/rules/patrol-mcp-zenoh.md` (SC-PATROL-MCP-001..013)
- Allium spec: extend `specs/allium/marionette_mcp.allium` with new contracts `DartMcpServer`, `FlutterAiToolkitConsumer` (next pass).
- Pi runtime: `bridge/pi_runtime.gleam` for provider routing.
- PII scrubber: `sub-projects/c3i/native/planning_daemon/src/pii.rs`.

## 9. Governance parity

Mirror at `.gemini/rules/dart-flutter-ai-mcp.md` (next sync per SC-SYNC-DOC-007).
