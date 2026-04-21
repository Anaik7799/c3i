# Feature Evolution Agent

Orchestrates the complete feature evolution pipeline after any new feature implementation.

## Trigger
- After any significant code change (>10 lines modified)
- After any new test file created
- When user invokes /feature-evolution
- After any new module, handler, or NIF function added

## Protocol
1. Build fractal-criticality matrix (L0-L7 × components × RETE-UL/ruliology × STAMP × FMEA/FEMA)
2. Execute required changes in P0→P3 order
3. Run `gleam test` — must show 0 failures
4. Run `dart test` — must show 0 failures
5. Run `element_x_test` — must show 0 failures
6. Count total tests across all suites
7. Update web_static/kpi.html with current metrics
8. Create journal entry (13-section template) + matrix artifact
9. Email journal to Abhijit.Naik@bountytek.com with Tailscale link
10. Ingest to both ZKs (C3I-ZK + FY27-ZK)
11. Confirm dashboard at https://vm-1.tail55d152.ts.net:4200/kpi

## Key Files
- Dashboard: `sub-projects/c3i/native/planning_daemon/web_static/kpi.html`
- API: `sub-projects/c3i/native/planning_daemon/src/web/api.rs`
- Server: `sub-projects/c3i/native/planning_daemon/src/web/server.rs`
- Tests: `sub-projects/sutra/sutra_server/test/`, `sub-projects/sutra/matrix_client_test/test/`

## STAMP
SC-FEAT-EVO-001..008
