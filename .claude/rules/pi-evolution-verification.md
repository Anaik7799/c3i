# Pi Evolution Verification Protocol (SC-PI-EVO)

## Mandate
**Every feature implementation MUST verify Pi symbiosis integration. No feature is complete without Pi bridge validation.**

This protocol is append-aligned with `CLAUDE.md` and Pi integration mandates (SC-PI, SC-PI-AUTO, SC-PI-RUNTIME, SC-GLM-ZEN, SC-WIRE-001).

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-EVO-001 | Every new Gleam module MUST check Pi bridge compatibility | HIGH |
| SC-PI-EVO-002 | Every feature MUST run `pi_integration` tests after completion | CRITICAL |
| SC-PI-EVO-003 | Every feature adding tools MUST update `pi_tools.gleam` federation | HIGH |
| SC-PI-EVO-004 | Every feature adding events MUST update `pi_agent.gleam`/`pi_claude_code.gleam` bridge mapping | HIGH |
| SC-PI-EVO-005 | Every feature MUST publish OTel spans via `pi_zenoh.gleam` for Pi state changes | HIGH |
| SC-PI-EVO-006 | Pi KPI dashboard MUST be updated after feature completion | MEDIUM |
| SC-PI-EVO-007 | Journal entry MUST document Pi symbiosis impact | HIGH |
| SC-PI-EVO-008 | ZK MUST be ingested after feature completion | CRITICAL |
| SC-PI-EVO-009 | L0/privileged Pi tool ops MUST be Guardian-gated with audit trail | CRITICAL |
| SC-PI-EVO-010 | Pi LLM calls MUST remain behind C3I circuit breakers (no bypass) | CRITICAL |

## Verification Checklist (per feature)
After EVERY feature implementation, verify:

1. **Pi build gate**
   - `cd sub-projects/pi-mono && npm run build`
2. **Gleam build gate**
   - `cd lib/cepaf_gleam && gleam build`
3. **Pi integration tests**
   - `cd lib/cepaf_gleam && gleam test -- --module pi_integration`
4. **Bridge modules compile and remain wired**
   - `bridge/pi_agent.gleam`
   - `bridge/pi_zenoh.gleam`
   - `bridge/pi_tools.gleam`
   - `bridge/pi_session.gleam`
   - `bridge/pi_provider.gleam`
   - `bridge/pi_claude_code.gleam`
5. **Federation parity check**
   - Tool federation target: **93 total** (6 Claude + 14 Pi + 73 C3I MCP), unless intentionally changed and documented.
6. **Event bridge parity check**
   - Pi↔AG-UI mapping parity validated (current baseline: 29 Pi events ↔ 32 AG-UI events).
7. **Protocol/safety checks**
   - MoZ request/response path preserved
   - AG-UI + A2UI payload validation intact
   - Smriti.db persistence path intact (production; JSONL local-only)
8. **UI parity checks**
   - Pi web-ui remains embed-safe in Lustre SSR
   - Pi TUI remains split-screen attachable
9. **Dashboard + observability**
   - Update Pi dashboard metrics artifact
   - Verify OTel spans + Zenoh publication for Pi state changes
10. **Knowledge closeout**
   - Journal entry completed
   - ZK ingest executed

## AOR Rules
| ID | Rule |
|----|------|
| AOR-PI-EVO-001 | ALWAYS run Pi integration tests after feature work |
| AOR-PI-EVO-002 | NEVER mark a feature complete without Pi bridge verification |
| AOR-PI-EVO-003 | ALWAYS update `pi_tools.gleam` when adding new MCP tools |
| AOR-PI-EVO-004 | ALWAYS update `pi_agent.gleam` / `pi_claude_code.gleam` when adding AG-UI/Pi events |
| AOR-PI-EVO-005 | ALWAYS ingest resulting docs to ZK after feature completion |

## Integration with Existing Protocols
- Extends SC-GLM-UI-001 (triple-interface mandate) to include Pi bridge
- Extends SC-WIRE-001 (wiring guard) to cover Pi types and messages
- Extends SC-MUDA-001 (zero waste) — unused Pi bridge code is waste
- Extends SC-TPS-001 (Jidoka) — auto-test includes Pi integration
- Extends SC-GLM-ZEN-001..003 and SC-ZMOF-* transport/telemetry expectations
