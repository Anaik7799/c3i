---
description: Verify Pi symbiosis integration — run after every feature
---

# Pi Symbiosis Verification

Run the complete Pi x C3I symbiosis verification suite.

## Steps

1. **Build verification**:
   ```bash
   cd /home/an/dev/ver/c3i/lib/cepaf_gleam && gleam build
   ```
   Must compile with 0 errors including all 5 Pi bridge modules.

2. **Pi integration tests**:
   ```bash
   gleam test -- --module pi_integration
   ```
   Must pass all 55+ tests across 14 groups.

3. **Full regression**:
   ```bash
   gleam test
   ```
   Must pass 8700+ tests with 0 failures.

4. **Bridge module inventory**:
   Verify these files exist and compile:
   - `bridge/pi_agent.gleam` (L6, event bridge)
   - `bridge/pi_zenoh.gleam` (L6, Zenoh publisher)
   - `bridge/pi_tools.gleam` (L3, tool federation)
   - `bridge/pi_session.gleam` (L3, session bridge)
   - `bridge/pi_provider.gleam` (L5, provider bridge)

5. **KPI update**:
   Update dashboard at `docs/presentations/pi-symbiosis-dashboard.html` with latest metrics.

6. **ZK ingest**:
   ```bash
   cd /home/an/dev/ver/c3i && ./sub-projects/c3i/target/release/sa-plan-daemon ingest-docs
   ```

7. **Email notification**:
   ```bash
   sa-plan-daemon send-email --to Abhijit.Naik@bountytek.com --subject "Pi Verify: [result]" --body "[summary]"
   ```

## Success Criteria
- gleam build: 0 errors
- Pi integration tests: 55+ passed, 0 failures
- Full tests: 8700+ passed, 0 failures
- Bridge modules: 5/5 present and compiling
- ZK: ingested
- Dashboard: updated
