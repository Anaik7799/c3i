# Pi Evolution Verification Protocol (SC-PI-EVO)

## Mandate
**Every feature implementation MUST verify Pi symbiosis integration. No feature is complete without Pi bridge validation.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-EVO-001 | Every new Gleam module MUST check Pi bridge compatibility | HIGH |
| SC-PI-EVO-002 | Every feature MUST run pi_integration_test.gleam after completion | CRITICAL |
| SC-PI-EVO-003 | Every feature adding tools MUST update pi_tools.gleam federation | HIGH |
| SC-PI-EVO-004 | Every feature adding events MUST update pi_agent.gleam bridge | HIGH |
| SC-PI-EVO-005 | Every feature MUST publish OTel spans via pi_zenoh.gleam | HIGH |
| SC-PI-EVO-006 | Dashboard MUST be updated with new KPIs after feature completion | MEDIUM |
| SC-PI-EVO-007 | Journal entry MUST document Pi symbiosis impact of feature | HIGH |
| SC-PI-EVO-008 | ZK MUST be ingested after feature completion | CRITICAL |

## Verification Checklist (per feature)
After EVERY feature implementation, verify:
1. `gleam build` — 0 errors (includes Pi bridge modules)
2. `gleam test -- --module pi_integration` — all tests pass
3. Pi bridge modules still compile (pi_agent, pi_zenoh, pi_tools, pi_session, pi_provider)
4. Tool count matches expected (currently 44 registered, 87 potential)
5. Event bridge maps new events if applicable
6. Dashboard at http://vm-1.tail55d152.ts.net:8090/pi-symbiosis-dashboard.html updated
7. ZK ingested via `sa-plan-daemon ingest-docs`

## AOR Rules
| ID | Rule |
|----|------|
| AOR-PI-EVO-001 | ALWAYS run Pi integration tests after feature work |
| AOR-PI-EVO-002 | NEVER mark a feature complete without Pi bridge verification |
| AOR-PI-EVO-003 | ALWAYS update pi_tools.gleam when adding new MCP tools |
| AOR-PI-EVO-004 | ALWAYS update pi_agent.gleam when adding new AG-UI events |
| AOR-PI-EVO-005 | ALWAYS ingest to ZK after feature completion |

## Integration with Existing Protocols
- Extends SC-GLM-UI-001 (triple-interface mandate) to include Pi bridge
- Extends SC-WIRE-001 (wiring guard) to cover Pi types
- Extends SC-MUDA-001 (zero waste) — unused Pi bridge code = waste
- Extends SC-TPS-001 (Jidoka) — auto-test includes Pi integration
