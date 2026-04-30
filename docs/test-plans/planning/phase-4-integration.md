# Phase 4 — Integration (L1, L3, L4, L5)

## Scope

End-to-end inside the BEAM process: NIF → SQLite → Wisp router → Mist → WsHandler → JS.

## Test cases

1. **NIF↔SQLite round-trip**: insert row via Rust binding → read via Gleam `plan_list`. Compare counts.
2. **Router parity**: `GET /api/v1/plan/status` ≡ `WS first frame.status` ≡ `SSE first event.status` (DAG-Q).
3. **Hot-reload survives WS**: `gleam build` modify → `curl /api/v1/reload` → assert WS connections still alive.
4. **Tabulator render fidelity**: 3 grids fed from NIF, all `.tabulator-row` count == NIF list length.
5. **Pi symbiosis**: `gleam test pi_integration` — confirms 93 federated tools (6 Claude + 14 Pi + 73 C3I) and 29↔32 event bridge (SC-PI-EVO-002).
6. **OTel span emission**: every state change publishes to `indrajaal/otel/spans/planning/{op}` (SC-GLM-ZEN-001) — verify via `zenoh_test_observer.gleam`.
7. **RETE-UL UI domain rules fire**: simulate `task_count_blocked = 11` → assert `UICockpitEscalate` triggers `cockpit_mode = bright`.
8. **Gemma fallback chain**: simulate Gemma 3 timeout → expect Gemma 4 → NIF → static (SC-PI-AUTO-005).
9. **Apoptosis on freshness dead**: freshness > 300 s → cockpit emergency, pings rejected.
10. **Pi runtime circuit breaker**: 3 failures in 60 s → opens (SC-PI-RUNTIME-002), fallback engages.

## Exit criteria

- All 10 cases green.
- Latency budget: WS round-trip < 200 ms p99.
- ΣRPN reduction ≥ 18 % vs baseline.
