# Integration Test Plan — 62 Remaining Modules (100% Coverage)

**Date**: 2026-04-10
**STAMP**: SC-WIRE-001, SC-SIL4-001, SC-GLM-TST-001
**Prerequisite**: Live swarm (17 containers running)

## Current State
- Unit tests: 3,576 passed, 0 failures
- Unit coverage: 210/272 modules (77%)
- Remaining: 62 modules (16 actors + 14 views + 32 other)

## The 62 Modules

### Category A: OTP Actors (16) — Need `gleam run` integration
| Module | Test Approach |
|--------|--------------|
| agents/cortex | Start actor, send ProcessIntent, verify response |
| agents/briefing | Start actor, send CronTick, verify no crash |
| agents/leadership | Start actor, send CheckLease, verify role |
| agents/workspace | Start actor, send TriageDailyFlow, verify dispatch |
| agents/shell_runner | Start actor, send ExecuteCommand, verify result |
| agents/skill_loader | Start actor, send LoadSkill, verify response |
| gateway/gchat | Start actor, verify GatewayState created |
| gateway/whatsapp | Start actor, verify GatewayState created |
| bridge/zenoh_mcp | Start actor, verify MoZ bridge active |
| immune/mara | Start actor with config, verify no crash |
| immune/system | Start actor, verify threat assessment |
| substrate/database | Start actor, verify connection |
| podman/manager | Start mesh, verify container list |
| telemetry/otel | Start span, verify export |
| observability/zenoh_otel_ingestor | Start ingestor, verify subscription |
| zenoh/lifecycle | Start zenoh session, verify connection |

### Category B: View Functions (14) — Need parent module for model
| Module | Test: Call view()/render()/handle_req() |
|--------|---------------------------------------|
| ui/lustre/chat_history | view() → verify Element |
| ui/lustre/fmea | view() → verify Element |
| ui/lustre/inference | view() → verify Element |
| ui/lustre/pipeline_trace | view() → verify Element |
| ui/lustre/planning_view | view(model) → verify Element |
| ui/lustre/shell | render_page() → verify Element |
| ui/lustre/voice | view() → verify Element |
| ui/tui/chat_history_view | render() → verify String |
| ui/tui/inference_view | render() → verify String |
| ui/tui/pipeline_trace_view | render() → verify String |
| ui/tui/voice_view | render() → verify String |
| ui/web/shell | render_page() → verify Element |
| ui/wisp/chat_history_api | handle_req() → verify JSON |
| ui/wisp/pipeline_trace_api | handle_req() → verify JSON |

### Category C: Infrastructure (32) — Need real connections
| Module | Test Approach |
|--------|--------------|
| db/sqlite | open(":memory:") → verify connection |
| db/duckdb | execute on in-memory DB |
| podman/containers | list_containers with live podman |
| podman/networks | list_networks with live podman |
| podman/volumes | list_volumes with live podman |
| planning/cli | run(["status"]) → verify output |
| planning/manager | list_tasks_remote → verify list |
| planning/repository | ensure_db_exists → verify file |
| planning/task | create with test input |
| planning/domain | (type-only module, no functions) |
| mcp/protocol | (type-only module, no functions) |
| substrate/boot | execute_boot → verify state |
| substrate/cli | up() → verify containers |
| substrate/homeostasis | check quorum with live zenoh |
| telemetry/exporter | export_span to collector |
| testing/coverage | check_coverage_compliance |
| testing/gemini_verification | verify pipeline |
| ui/visual_reasoning | calculate_click_point |
| ui/wisp/cockpit_api | nodes_json with test data |
| ui/wisp/immune_api | immune_status_json |
| ui/wisp/kms_api | catalog_json |
| ui/wisp/knowledge_api | knowledge_graph_json |
| ui/wisp/markdown_api | entry_to_markdown_json |
| ui/wisp/mcp_api | status_json |
| ui/wisp/metabolic_api | status_json |
| ui/wisp/planning_api | list_tasks_json |
| ui/wisp/substrate_api | status_json |
| ui/wisp/telemetry_api | status_json |
| ui/wisp/zenoh_api | zenoh_health_json |
| web/server | record_connection |
| agui/zenoh_bus | publish_event (needs Zenoh session) |
| knowledge/repository | ensure_triple_store |

## Test Execution Order

### Phase 1: View functions (14 modules) — no infrastructure needed
Call view()/render() with no-arg constructors. These should work in unit tests.

### Phase 2: Wisp APIs (11 modules) — need domain types constructed
Create test data, call *_json() functions. Should work in unit tests.

### Phase 3: DB/Planning (6 modules) — need SQLite in-memory
Open ":memory:" DB, run operations.

### Phase 4: Podman/Substrate (5 modules) — need live swarm
Test against running 17-container mesh.

### Phase 5: OTP Actors (16 modules) — need BEAM runtime
Start actors with test configs, send messages, verify responses.
