---
description: Digital Immune System validation — Sentinel, PatternHunter, SymbioticDefense via MCP + tests
allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_sub, mcp__sentinel-zenoh__zenoh_query, Bash(mix:*), Bash(MIX_ENV=test:*), Read, Grep, Glob
argument-hint: [check|test|status|watch] [module]
---

# Immune System Validation (SC-IMMUNE-001 to SC-IMMUNE-010)

Validates the Digital Immune System (T-Cell architecture) using MCP Sentinel + Zenoh telemetry.

## Usage
```
/immune check          # Full immune system health via MCP Sentinel
/immune test           # Run immune system Elixir tests
/immune status         # Sentinel + PatternHunter + SymbioticDefense status
/immune watch          # Real-time threat monitoring via Zenoh subscription
```

## Check (MCP-Native)
1. Health assessment: `sentinel(action: "health")`
   - Health score (0-100, SC-IMMUNE-001)
   - Circuit breaker state (SC-IMMUNE-002)
   - Memory alert status (SC-IMMUNE-003)
2. Threat scan: `sentinel(action: "threats")`
   - Active threats with severity
   - Founder's Directive status (SC-FOUNDER-007)
3. FFI verification: `zenoh_query(action: "verify")`
   - 12 formal invariants
   - Bridge connectivity

## Test (Elixir Test Suite)
```bash
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true PATIENT_MODE=enabled \
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_ENV=test mix test test/indrajaal/safety/ --trace
```

## Watch (Zenoh Real-Time)
1. Subscribe: `zenoh_sub(action: "subscribe", key: "indrajaal/sentinel/**")`
2. Poll threats: `zenoh_sub(action: "poll", id: "{id}", limit: 20)`
3. Correlate with health: `sentinel(action: "health")`
4. Report escalation: green → yellow → orange → red → black

## Modules
| Module | Path | MCP Check | Constraints |
|--------|------|-----------|-------------|
| Guardian | `lib/indrajaal/safety/guardian.ex` | sentinel(health) | SC-CONST-007, SC-GDE-001 |
| Sentinel | `lib/indrajaal/safety/sentinel.ex` | sentinel(health) | SC-IMMUNE-001 to SC-IMMUNE-010 |
| PatternHunter | `lib/indrajaal/safety/pattern_hunter.ex` | sentinel(threats) | SC-IMMUNE-003, SC-BIO-EXT-001 |
| SymbioticDefense | `lib/indrajaal/safety/symbiotic_defense.ex` | sentinel(threats) | SC-FOUNDER-007 |

## Validation Checklist (STAMP)
- [ ] Health scoring: 0-100 numeric (SC-IMMUNE-001)
- [ ] Circuit breaker: triggers >10% error rate (SC-IMMUNE-002)
- [ ] Memory alerts: >80% sustained >5min (SC-IMMUNE-003)
- [ ] Quarantine: isolate before terminate (SC-IMMUNE-004)
- [ ] Recovery: max 3 attempts before escalation (SC-IMMUNE-005)
- [ ] DuckDB logging: all immune actions (SC-IMMUNE-006)
- [ ] Guardian notification: CRITICAL threats (SC-IMMUNE-007)
- [ ] Founder's Directive: IMMEDIATE response (SC-IMMUNE-008)
- [ ] Threat scoring: weighted multi-factor (SC-IMMUNE-009)
- [ ] False positive rate: <5% (SC-IMMUNE-010)

## Mathematical Foundation

**5-Level Markov Chain** (defense escalation state machine):

States: $\mathcal{S} = \{$normal, elevated, guarded, high, critical$\}$

Transition matrix $Q$ with rates $\lambda_{ij}$:

$$\pi_i(t+1) = \sum_j \pi_j(t) \cdot Q_{ji}$$

**Threat Scoring**: $T_{score} = \sum_{i} w_i \cdot f_i$ where $f_i \in \{$severity, occurrence, detection$\}$

**MTTF**: $\text{MTTF} = \frac{1}{\lambda_{normal \to elevated}}$ — mean time between escalations

**False Positive Rate**: $FPR = \frac{FP}{FP + TN} < 0.05$ (SC-IMMUNE-010)

## Known P0 Issues (Criticality Analysis)
1. **Sentinel Error Rate**: Non-numeric results possible
2. **Sentinel Guardian Gap**: Protection gap when Guardian unavailable
3. **SymbioticDefense Recovery**: Mechanism non-functional
4. **PatternHunter Memory**: Detection logic inverted
