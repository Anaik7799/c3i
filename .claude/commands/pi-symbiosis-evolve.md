# Pi-Mono Symbiosis Evolution Command

## Trigger
When user says `/pi-symbiosis-evolve` or requests Pi integration work.

## Pipeline

### Phase 1: Observe (OODA-O)
```bash
# Check Pi-mono build status
cd sub-projects/pi-mono && npm run check 2>&1 | tail -5

# Check Gleam Pi bridge
cd lib/cepaf_gleam && gleam build 2>&1 | grep -E "pi_|bridge/"

# Check current tool federation count
cd lib/cepaf_gleam && gleam test -- --module pi_claude_code 2>&1 | tail -3

# Search ZK for Pi patterns
sa-plan-daemon knowledge-search "pi-mono symbiosis bridge"
```

### Phase 2: Orient (OODA-O)
- Read pi_claude_code.gleam for current state
- Read pi_tools.gleam for tool federation
- Read pi_agent.gleam for event mapping
- Build fractal-criticality matrix (L0-L7 × components × RETE-UL/ruliology × STAMP × FMEA/FEMA)
- Compare against Claude Code's current capabilities

### Phase 3: Decide (OODA-D)
Based on observation:
- If new Claude Code tools detected → update tool federation
- If new AG-UI events → update event bridge
- If Pi packages updated → verify bridge compatibility
- If tests failing → fix before proceeding

### Phase 4: Act (OODA-A)
1. Execute remediation in criticality order (P0→P3)
2. Update bridge modules as needed
3. Run full test suite
4. Update HTML dashboard metrics
5. Capture screenshots
6. Write journal entry + matrix artifact
7. Email results with Tailscale links

### Phase 5: Verify (OODA-V)
```bash
cd lib/cepaf_gleam && gleam build  # 0 errors, 0 warnings
cd lib/cepaf_gleam && gleam test   # 0 failures
curl -s http://localhost:4200/pi-symbiosis | head -5  # Dashboard accessible
```

## Constraints
- SC-PI-001..010: All Pi STAMP constraints
- SC-PI-AUTO-001..008: Automation constraints
- SC-ARCH-SPLIT: Rust ops / Gleam UI boundary
- SC-MUDA-001: Zero warnings
