# Dart + Flutter MCP Tool Catalog — CPIG Phase B G4 closure

> CPIG subsystem: Dart MCP server · Pass-15 G4 (ZK ingestion) closure
> Per `.claude/rules/dart-flutter-ai-mcp.md` — 16 MCP tools, 11 default-on
> Source-of-truth: `dart_mcp_server` from `https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server`

## STAMP references
- SC-DART-MCP-001..010
- SC-CPIG-014 (Dart MCP G4 closure)
- SC-PI-AUTO-003 (tool federation count)

## 16-tool surface

| # | MCP Tool | Category | Default-on | Anti-pattern blocked | Fractal layer |
|---:|---|---|:---:|---|:---:|
| 1 | `analyze_files` | Static analysis | ✓ | Manual `flutter analyze` reading | L2 |
| 2 | `dart_fix` | Static fix | — | Auto-fix not reviewed | L3 |
| 3 | `dart_format` | Style | ✓ | Inconsistent formatting | L2 |
| 4 | `run_tests` | Test runner | ✓ | Manual `flutter test` reading | L5 |
| 5 | `hot_reload` | Runtime | ✓ | Full restart on small edit | L4 |
| 6 | `hot_restart` | Runtime | — | Crash-loop recovery | L4 |
| 7 | `dtd` | DevTools daemon | ✓ | DevTools manual launch | L4 |
| 8 | `get_runtime_errors` | Runtime | ✓ | Lost errors across hot reload | L1 |
| 9 | `get_app_logs` | Runtime | ✓ | Manual `flutter run` log scrape | L1 |
| 10 | `widget_inspector` | UI introspection | ✓ | Manual screen-tap to identify widget | L2 |
| 11 | `flutter_driver_command` | Driver | — | Patrol+Marionette stack-only authoring | L5 |
| 12 | `pub` | Package mgmt | ✓ | `flutter pub` manual invocation | L3 |
| 13 | `pub_dev_search` | Discovery | ✓ | Browser-based pub.dev search | L6 |
| 14 | `read_package_uris` | Discovery | — | Manual dependency graph reading | L6 |
| 15 | `rip_grep_packages` | Discovery | — | Local grep of `.dart_tool/` | L6 |
| 16 | `list_devices` / `launch_app` / `stop_app` / `list_running_apps` / `roots` / `create_project` | Project | ✓ | Manual device + project orchestration | L4 |

## Co-existence with Marionette + Patrol MCP

| Surface | Role | Layer | Coexistence rule |
|---|---|:---:|---|
| `dart_mcp_server` | dev tooling (this catalog) | L1+L4 | always-on in debug builds |
| `marionette_mcp` | live UI driving | L4+L5 | namespace `mcp__marionette__*` |
| `patrol_mcp` | regression test orchestration | L5 | namespace `mcp__patrol__*` |
| `flutter_ai_toolkit` | end-user chat UI | L7 | consumed by app, not by agent |

## Integration with C3I governance

- **OTel emission**: every Dart MCP tool call MUST publish on
  `indrajaal/l5/dev/dart/<tool>/<id>` (SC-DART-MCP-006).
- **Release-build guard**: `dart_mcp_server` MUST NOT attach to release-mode Flutter
  binaries (SC-DART-MCP-004); parity rule with SC-MARIONETTE-005.
- **PII scrubber**: when `flutter_ai_toolkit` is wired, prompts MUST route through
  Rust `pii.rs` before LLM send (SC-DART-MCP-007).
- **Circuit-breaker**: provider calls MUST flow through Pi runtime so C3I cortex
  breakers apply (SC-DART-MCP-008).

## Tool federation accounting

| Source | Count |
|---|---:|
| Claude (built-in) | 6 |
| Pi runtime (15 providers) | 14 |
| C3I MCP (cortex + planning + system) | 73 |
| Dart MCP (this catalog) | **16** |
| **Federated total** | **109** |

Adds +16 to the 93 baseline tracked in CLAUDE.md §10 (SC-PI-AUTO-003) once
`pi_claude_code.gleam` registers Dart MCP as a federation peer. Update pending.

## Health-check matrix

| Health gate | Pass criterion | Failure mode |
|---|---|---|
| MCP server reachable | `dart mcp-server --help` exit 0 | Dart SDK ≥ 3.9 missing |
| Debug build attached | VM service URI returns `/ws` | release build (SC-DART-MCP-004 violation) |
| Tool inventory match | 16 tools enumerable | upstream version drift |
| Namespace isolation | no `mcp__patrol__` or `mcp__marionette__` collision | overlapping tool names |

## Activation

```bash
# Required: Dart SDK ≥ 3.9
dart --version

# Activate Dart MCP server in .claude/settings.json mcpServers:
#   "dart": { "type": "stdio", "command": "dart", "args": ["mcp-server"] }

# Verify
mcp__dart__list_devices    # expect: devices array
mcp__dart__analyze_files   # expect: analyzer results
```

## Cross-references

- `.claude/rules/dart-flutter-ai-mcp.md` (parent rule, SC-DART-MCP-001..010)
- `.claude/rules/marionette-mcp-flutter-testing.md` (sibling MCP family)
- `.claude/rules/patrol-mcp-zenoh.md` (sibling MCP family)
- `sub-projects/marionette_mcp/` (vendored upstream)

## CPIG closure status

- G1 Formal Spec: ✓ `specs/tla/DartMcpServer.tla` (Pass-14)
- G2 Wiring Guard: ✓ `lib/cepaf_gleam/test/dart_mcp_tools_wiring_test.gleam` (Pass-14)
- G3 sa-plan Tracking: ✓ SC-DART-MCP family tracked
- **G4 ZK Ingestion**: ✓ this catalog (Pass-15, today)
- G5 Email Closure: ✓ (Pass-14, plus this pack's email)

Score: 4/5 → **5/5** after Pass-15 ingest.
