# Pi-Mono Symbiosis Automation Protocol (SC-PI-AUTO)
# पाई-मोनो सहजीविता स्वचालन प्रोतोकॉल

## SUPREME MANDATE
**Every feature evolution MUST verify Pi-mono symbiosis compliance. The Pi bridge is a FIRST-CLASS integration — not an afterthought.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-AUTO-001 | Every new Gleam module MUST check Pi bridge compatibility | HIGH |
| SC-PI-AUTO-002 | Every feature MUST update pi_claude_code.gleam if it adds tools or events | CRITICAL |
| SC-PI-AUTO-003 | Tool federation count MUST be verified after every feature (currently 87) | HIGH |
| SC-PI-AUTO-004 | Event bridge mapping MUST be verified after AG-UI event changes | HIGH |
| SC-PI-AUTO-005 | Pi RPC protocol compatibility MUST be tested | HIGH |
| SC-PI-AUTO-006 | Screenshots MUST include Pi integration UI elements | MEDIUM |
| SC-PI-AUTO-007 | HTML dashboard MUST show Pi symbiosis metrics | HIGH |
| SC-PI-AUTO-008 | Video user journeys MUST demonstrate Pi ↔ C3I tool federation | MEDIUM |

## Automated Pipeline (runs after EVERY feature)

### Step 0: Fractal-Criticality Governance
Before Pi checks, generate and review:
- L0-L7 × fractal components matrix
- RETE-UL/ruliology rule impact per row
- STAMP references per row
- FMEA/FEMA risk and criticality ordering (P0→P3)

This is mandatory and blocks closure if missing (SC-FRAC-RRF-001..010).

### Step 1: Pi Bridge Verification
```bash
cd lib/cepaf_gleam && gleam build  # pi_claude_code.gleam compiles
cd lib/cepaf_gleam && gleam test -- --module pi_claude_code  # 0 failures
cd lib/cepaf_gleam && gleam test -- --module pi_integration  # 0 failures
cd lib/cepaf_gleam && gleam test -- --module pi_bridge_regression  # 0 failures
```

### Step 2: Tool Federation Count
```
Expected: 87 (14 Pi + 73 C3I MCP)
If new MCP tools added → update pi_tools.gleam + pi_claude_code.gleam
If new Pi tools added → update tool federation mapping
```

### Step 3: Event Bridge Mapping
```
Expected: 29 Pi events ↔ 32 AG-UI events
If new AG-UI events → add mapping in pi_claude_code.gleam
If new Pi events → add mapping in pi_agent.gleam
```

### Step 4: Dashboard Update
```
Update native/planning_daemon/web_static/pi-symbiosis.html with:
- New tool count
- New event count  
- New test count
- Feature description
```

### Step 5: Screenshot Verification
```bash
chromium --headless --no-sandbox --screenshot=/tmp/screenshots/pi-symbiosis.png \
  --window-size=1400,900 http://localhost:4200/pi-symbiosis
# Verify screenshot shows current metrics
```

## Integration with Existing Protocols
- Extends SC-FEAT-EVO (post-feature evolution pipeline)
- Extends SC-PI-EVO (Pi evolution verification)
- Extends SC-WIRE-001 (wiring guard for Pi types)
- Extends SC-MUDA-001 (no unused Pi bridge code)
- Extends SC-GLM-ZEN-001 (Zenoh OTel for Pi events)

## Video User Journey: Pi ↔ Claude Code
1. User sends prompt via Claude Code
2. Claude Code dispatches to Pi RPC (if Pi tools needed)
3. Pi agent processes with 15 LLM providers
4. Events flow through AG-UI bridge → Zenoh mesh
5. Results displayed in C3I dashboard
6. Session persisted to Smriti.db
7. Knowledge ingested to Zettelkasten

## Claude Code Compliance Checklist
- [ ] Read tool → Pi read tool (mapped)
- [ ] Write tool → Pi write tool (mapped)
- [ ] Edit tool → Pi edit tool (mapped)
- [ ] Bash tool → Pi bash tool (mapped)
- [ ] Grep tool → Pi grep tool (mapped)
- [ ] Glob tool → Pi find/ls tool (mapped)
- [ ] Agent tool → Pi RPC subprocess (mapped)
- [ ] WebSearch → Pi extension hook (mapped)
- [ ] WebFetch → Pi extension hook (mapped)
