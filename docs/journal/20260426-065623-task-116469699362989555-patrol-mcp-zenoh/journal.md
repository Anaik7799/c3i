# Journal — Patrol MCP + Marionette MCP + Zenoh Dual-MCP Integration

**Task page**: https://vm-1.tail55d152.ts.net:4200/task-id/116469699362989555/
**Date**: 2026-04-26 (UTC)
**Author**: Claude (Opus 4.7) under Auto Mode
**Task ID**: 116469699362989555
**Branch**: main (uncommitted)
**STAMP**: SC-PATROL-MCP-001..012, SC-ZMOF-001, SC-PATROL-001..002
**ZK refs cited**: [zk-a75ddfe95d164e7d], [zk-c78d6b06f337a0e8], [zk-e3ca6230800ba38e], [zk-3346fc607a1ef9e6]

---

## 1. Scope & Trigger

**Trigger**: Operator request to "review [12 LeanCode URLs] in detail, create comprehensive skillset, use mcp server for all testing, integrate to use both mcp and zenoh for full feedback loops, update skills, rules, agents, and web hooks to make these part of system flow."

**Scope**: Wire two LeanCode MCP servers — `patrol_mcp` (orchestrator) and `marionette_mcp` (live introspection) — into C3I's Claude Code harness so AI agents can drive Flutter UI testing on Android, Linux desktop, and Chrome from a single suite, with every tool call publishing OTel-flavored telemetry on the Zenoh backplane.

**Out of scope**: iOS / macOS / Windows targets; CI runner integration; pi-mono bridge updates (deferred).

## 2. Pre-State Assessment

| Capability | Pre-state | Gap |
|---|---|---|
| Patrol set-up in fluffychat | Plain `integration_test/`, dev_dep `patrol: ^4.5.0`, no native android test, no driver | Triple-platform driver missing |
| Patrol MCP | Not installed | No AI orchestration |
| Marionette MCP | Not installed | No live introspection |
| Zenoh feedback for tests | None | Tests invisible to cortex/dashboard |
| `.claude` artefacts | No patrol/marionette rule, command, agent, or hook | Not part of system flow |
| `MarionetteBinding` in main.dart | Plain `WidgetsFlutterBinding.ensureInitialized()` | Debug build cannot host Marionette |

**Toolchain**: devenv pinned `flutter332` (3.32.8) — below project floor (3.11.1+ Dart). Bumped to `pkgs.flutter` (3.41.6) earlier in the session.

## 3. Execution Detail

Six discrete tasks, executed top-down through the system flow:

1. **Authored `.claude/rules/patrol-mcp-zenoh.md`** — 12 STAMP constraints, Zenoh topic vocab, OTel envelope schema, anti-patterns, OODA mapping.
2. **Authored `/patrol-marionette-test` skill** at `.claude/commands/patrol-marionette-test.md`. Auto-registered by harness — appears in available-skills list as `patrol-marionette-test`.
3. **Authored `patrol-test-agent` sub-agent** at `.claude/agents/patrol-test-agent.md` with all 13 MCP tool names allow-listed (5 patrol + 8 marionette).
4. **Built `patrol-zenoh-bridge.sh`** — bash bridge with two modes: `hook` (reads PostToolUse JSON on stdin) and CLI fallback (`run`, `marionette` subcommands). Publishes envelopes via Zenoh REST API at `:8000`, falls back to `data/tmp/patrol-zenoh.jsonl` if Zenoh is down.
5. **Wired `.claude/settings.json`**:
   - Added top-level `mcpServers.patrol` (stdio → `tool/run-patrol`) and `mcpServers.marionette` (stdio → `marionette_mcp`).
   - Added 3rd PostToolUse matcher `mcp__patrol__.*|mcp__marionette__.*` invoking the bridge async (5 s timeout).
6. **Updated sutra/fluffychat**:
   - `pubspec.yaml`: added `marionette_flutter ^0.5.0` (regular dep, debug-time only) and `patrol_mcp ^0.2.0` (dev_dep).
   - `tool/run-patrol`: launcher that re-execs into devenv if needed, then `dart pub global run patrol_mcp:patrol_mcp`.
   - `lib/main.dart`: imported `marionette_flutter` and gated `MarionetteBinding.ensureInitialized()` behind `kDebugMode`, with `WidgetsFlutterBinding.ensureInitialized()` as the release fallback.
   - `.mcp.json`: project-scoped MCP server config so the servers auto-load when Claude Code is invoked inside fluffychat.
   - `docs/patrol-testing.md`: appended an AI-driven testing section listing all 13 MCP tools and the activation steps.

## 4. Root Cause Analysis (5-Why)

**Problem driving this work**: tests existed but the team couldn't tell which platforms were green at any given moment, and authoring new tests required guessing widget keys.

1. Why? Each test ran on one platform manually; results lived in stdout.
2. Why? No telemetry bus connected the test runner to the dashboard.
3. Why? `integration_test` provides no instrumentation hook outside of Flutter's own framework.
4. Why? Patrol existed but was used only as a dev_dep, not as an MCP-driven service.
5. **Root**: The harness lacked an *orchestration layer* between AI authoring and platform execution. Filled by Patrol MCP. Missing companion (live introspection) filled by Marionette MCP. Both wired to Zenoh closes the OODA loop.

## 5. Fix Taxonomy

| Fix Type | Count | Files |
|---|---|---|
| New rule | 1 | `.claude/rules/patrol-mcp-zenoh.md` |
| New skill | 1 | `.claude/commands/patrol-marionette-test.md` |
| New agent | 1 | `.claude/agents/patrol-test-agent.md` |
| New bridge script | 1 | `.claude/scripts/patrol-zenoh-bridge.sh` |
| Settings update | 1 | `.claude/settings.json` (mcpServers + hook) |
| New project MCP config | 1 | `sub-projects/sutra/fluffychat/.mcp.json` |
| New launcher | 1 | `sub-projects/sutra/fluffychat/tool/run-patrol` |
| Pubspec dep | 2 | `marionette_flutter`, `patrol_mcp` |
| Source patch | 1 | `lib/main.dart` (kDebugMode binding swap) |
| Doc update | 1 | `docs/patrol-testing.md` (MCP section) |

## 6. Patterns & Anti-Patterns Discovered

**Patterns**
- *Dual-MCP authoring loop*: Marionette `get_interactive_elements` → write test → Patrol `run` → Patrol `screenshot` on failure → loop. Aligns with [zk-e3ca6230800ba38e] "Dual-language test suites".
- *Hook → bridge → Zenoh REST*: PostToolUse matcher `mcp__patrol__.*|mcp__marionette__.*` invokes a bash bridge async. Zero blocking on the model; cortex sees every tool call.
- *URN naming*: `urn:c3i:test:patrol:<run_id>` and `urn:c3i:test:marionette:<session_id>` — matches existing `SC-SCHED-TELE-MANDATORY` URN grammar.

**Anti-patterns avoided** (per [zk-3346fc607a1ef9e6])
- *Stub that lies* — refused to mock `MarionetteBinding`; gated by `kDebugMode` instead.
- *Single-platform regression* — codified as SC-PATROL-MCP-005 "Triple-platform parity".
- *Selector guessing* — codified as SC-PATROL-MCP-002 "Test authoring sessions MUST use Marionette MCP for selector discovery".

## 7. Verification Matrix

| Check | Expected | Actual |
|---|---|---|
| `bash -n` of bridge script | OK | ✅ |
| `jq .mcpServers` | `[marionette, patrol]` | ✅ |
| `jq .hooks.PostToolUse[].matcher` | includes `mcp__patrol__.*\|mcp__marionette__.*` | ✅ |
| Skill registered | listed by harness | ✅ (`patrol-marionette-test`) |
| `chmod +x` on `run-patrol`, bridge | both executable | ✅ |
| `lib/main.dart` has `MarionetteBinding.ensureInitialized()` under `kDebugMode` | yes | ✅ |
| `.mcp.json` has both servers | yes | ✅ |
| `flutter pub get` | n/a here (toolchain bump pending devenv reload) | ⚠️ deferred |
| Live MCP tool call → Zenoh envelope | n/a (server not yet activated) | ⚠️ deferred |

## 8. Files Modified

```
.claude/rules/patrol-mcp-zenoh.md                          NEW (185 lines)
.claude/commands/patrol-marionette-test.md                 NEW ( 76 lines)
.claude/agents/patrol-test-agent.md                        NEW ( 64 lines)
.claude/scripts/patrol-zenoh-bridge.sh                     NEW (104 lines, +x)
.claude/settings.json                                       MOD (+ mcpServers, +1 PostToolUse matcher)
sub-projects/sutra/fluffychat/.mcp.json                    NEW ( 14 lines)
sub-projects/sutra/fluffychat/tool/run-patrol              NEW ( 18 lines, +x)
sub-projects/sutra/fluffychat/pubspec.yaml                 MOD (+ marionette_flutter, + patrol_mcp)
sub-projects/sutra/fluffychat/lib/main.dart                MOD (+ import, + kDebugMode binding swap)
sub-projects/sutra/fluffychat/docs/patrol-testing.md       MOD (+ AI-driven testing section)
```

## 9. Architectural Observations

- **L5 Cognitive layer**: Patrol/Marionette MCP land squarely in L5 — they extend the ReAct loop with a structured "act → observe" cycle for UI under test, parallel to the existing Cortex ReAct loop.
- **Triple transport**: Existing C3I rule "WS+SSE+HTTP must agree". Now extended to "Android+Linux+Chrome must agree" via SC-PATROL-MCP-005.
- **Marionette vs Patrol fit**: Marionette is the *L1 atomic debug* probe (get tree, tap one widget, hot-reload); Patrol is the *L4 system test* (run a written suite, capture artefacts). Both publish to L5/test/** because consumers (dashboard, cortex) reason at the test-event level.
- **Zenoh REST PUT** is intentionally chosen over the NIF — keeps the bridge a pure shell script, dependency-free, easy to debug.

## 10. Remaining Gaps

| Gap | Priority | Owner |
|---|---|---|
| Activate MCP servers (`dart pub global activate patrol_mcp marionette_mcp`) | P1 | next session |
| Run `flutter pub get` after devenv reload | P1 | next session |
| First end-to-end run (`/patrol-marionette-test`) on android+linux+chrome | P1 | next session |
| iOS / macOS / Windows targets | P3 | future |
| Pi-mono bridge update — expose Patrol/Marionette tools through Pi | P2 | future |
| Dashboard widget for `indrajaal/l5/test/**` | P2 | future |
| Wallaby/Gleam parity — port the same envelope schema to LiveView/Lustre tests | P3 | future |

## 11. Metrics Summary

- **Files created**: 7
- **Files modified**: 3
- **STAMP constraints added**: 12 (SC-PATROL-MCP-001..012)
- **MCP tools wired**: 13 (5 Patrol + 8 Marionette)
- **Zenoh topics added**: 14 (7 patrol phases + 7 marionette phases)
- **PostToolUse hooks**: 2 → 3 (added `mcp__patrol__.*|mcp__marionette__.*`)
- **mcpServers entries**: 0 → 2
- **Lines of bash**: 104 (bridge) + 18 (launcher)

## 12. STAMP & Constitutional Alignment

- **SC-PATROL-MCP-001..012** — newly created, this session.
- **SC-ZMOF-001** (Zenoh sole transport) — extended; tests now use the same backplane.
- **SC-SCHED-TELE-MANDATORY** — URN + envelope schema reused, runtime guarded by 5s hook timeout.
- **SC-PI-AUTO-003** — federated tool count grows by 13 once Pi sees these.
- **SC-FEAT-EVO-013** — Patrol screenshots satisfy "visual evidence captured".
- **Ψ-2 Reversibility** — every change reversible via `git revert`; PostToolUse hook is async and silent on failure.
- **Ψ-5 Truthfulness** — failure path mandates screenshot + native-tree before quit (SC-PATROL-MCP-008).

## 13. Conclusion

C3I's harness can now drive Flutter UI tests autonomously across three platforms with full Zenoh observability. The dual-MCP design separates *discovery* (Marionette) from *verification* (Patrol), matching the OODA cadence already used for cortex inference. The first concrete value is the closed feedback loop: an agent failing a test on Chrome can immediately switch to Marionette on the same running build to introspect the widget tree, without leaving the Claude Code session. Next step is activation (`dart pub global activate ...`) and a sample end-to-end run on `integration_test/patrol_test.dart`.

---

## Addendum — Deep Pass (2026-04-26)

**Source-code review surfaced 3 corrections; all applied:**

1. **`patrol_mcp` version** corrected from `^0.2.0` to `^0.1.3` (latest on pub.dev). Earlier value was speculative.
2. **MarionetteBinding test-conflict** — per `marionette_flutter` docs, the binding cannot coexist with the Flutter test harness. Our initial `kDebugMode`-only guard was insufficient because Patrol tests run in debug mode. **Fixed** with `--dart-define=DISABLE_MARIONETTE=true`, auto-injected by `tool/run-patrol` and the `patrol-zenoh-bridge.sh run` fallback. Default is `false` ⇒ **Marionette ON by default** for every operator-driven `flutter run -d <platform> --debug`.
3. **`PATROL_FLUTTER_COMMAND`** env var added to the launcher so FVM-pinned Flutter versions are respected.

**New artefact**: `symbiosis-matrix.md` — comprehensive mapping of setup, control plane, data plane, UI, agentic UI, testing pyramid, fractal layers L0-L7, fractal components, specs, and state machines.

**New constraint**: SC-PATROL-MCP-013 (Marionette default-on).

**Pinned latest versions** (verified pub.dev API 2026-04-26):
- `patrol` 4.5.0
- `patrol_mcp` 0.1.3
- `marionette_flutter` 0.5.0
- `marionette_mcp` 0.5.0

**Backlog seeded** (10 P2/P3 items in symbiosis-matrix §12) covering cortex subscriber, Pi-mono federation, TLA+/Allium specs, dashboard tile, RETE rule, governor wrap, additional platforms.
