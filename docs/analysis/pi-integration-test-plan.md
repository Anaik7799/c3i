# Pi Integration Test Plan (scaffold)

## Scope
- Zenoh publish/subscribe (AG-UI 32 events; spans)
- Guardian gate (destructive tool approval; deny path)
- Smriti session adapter (save/load; fallback detection)
- Model registry sync (resolver → scoped models)
- MCP registry sync (tool count/metadata)
- Circuit breaker (LLM call wrapped; trip/reset span)
- Type validation (AG-UI schema; A2UI allowlist; TypeBox↔ADT bridge)
- UI embedding flags (pi-web-ui SSR; split-screen TUI attach)

## Candidate tests (pi_integration_test.gleam)
1) zenoh_publish_subscribe: publish AG-UI event, observe via test observer.
2) guardian_deny_blocks_tool: simulate destructive tool; expect denial error.
3) smriti_roundtrip: save/load session; assert data integrity; detect fallback flag.
4) model_sync_updates_list: run sync; assert model list changes when resolver differs.
5) mcp_sync_registers_tools: run sync; assert expected tool count/metadata.
6) breaker_trips_and_resets: force failures; expect trip span; then reset.
7) agui_validation_rejects_bad_payload: send invalid payload; expect reject.
8) a2ui_allowlist_blocks_unknown_component: render unknown; expect reject.
9) type_bridge_roundtrip: serialize/deserialize via TypeBox↔ADT; expect equality.
10) ui_embedding_flag: render pi-web-ui under flag; assert SSR-safe.
11) split_screen_attach: invoke TUI attach; assert attach signal emitted.

## Execution
- gleam test -- --module pi_integration
- npm run build (sub-projects/pi-mono) for extension build
- ./scripts/run-split-screen-tests.sh
- Wallaby if LV touched (only if web embedding impacts LV)

## Notes
- Wire Zenoh test observer per existing testing/zenoh_test_observer.gleam.
- Use wiring_guard rules when adding tool/type changes.
