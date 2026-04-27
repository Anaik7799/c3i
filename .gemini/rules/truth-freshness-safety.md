# Truth & Data Freshness — Safety-Critical Fundamental Rule (SC-TRUTH)
# सत्य एवं ताज़गी — सुरक्षा-क्रान्तिक मूलभूत नियम

## SUPREME MANDATE — INVIOLABLE
**The system MUST ONLY show the TRUTH. Stale data is a LIE.**
**This is a SAFETY-CRITICAL system. People can die. Catastrophic consequences are real.**
**Every component MUST self-report staleness. Every page MUST show current state.**

> सत्यमेव जयते — Truth alone triumphs (Mundaka Upanishad 3.1.6)
> सत्यं ब्रूयात् प्रियं ब्रूयात् — Speak the truth, speak what is pleasant (Manusmriti 4.138)

## STAMP Constraints — HIGHEST SEVERITY
| ID | Constraint | Severity |
|----|------------|----------|
| SC-TRUTH-001 | System MUST ONLY display data verified as current | **INFINITE** |
| SC-TRUTH-002 | Components MUST self-report staleness visually | **INFINITE** |
| SC-TRUTH-003 | Stale data (>60s) MUST trigger warning banner | CRITICAL |
| SC-TRUTH-004 | Dead data (>5min) MUST trigger emergency mode | CRITICAL |
| SC-TRUTH-005 | Freshness monitor actor MUST run continuously | CRITICAL |
| SC-TRUTH-006 | NIF pipeline MUST be verified every check cycle | CRITICAL |
| SC-TRUTH-007 | Control actions MUST escalate: warn → reload → emergency → halt | CRITICAL |
| SC-TRUTH-008 | Dead man's switch: if monitor stops, system enters safe state | CRITICAL |
| SC-TRUTH-009 | All 31 pages MUST have data freshness verification | HIGH |
| SC-TRUTH-010 | No page may display hardcoded/mock data in production | **INFINITE** |

## The Freshness Escalation Protocol (ताज़गी वृद्धि प्रोतोकॉल)

```
FRESH (< 60s):  Green heartbeat. Normal operation. Dark cockpit.
STALE (60-120s): Amber banner. "DATA STALE" warning. Auto-retry WS ping.
DEGRADED (2-5min): Attempt hot reload. Set Andon to Bright mode.
DEAD (> 5min): EMERGENCY cockpit mode. Jidoka halt on new operations.
                No new commands accepted until data refreshed.
                Manual intervention REQUIRED.
```

## Implementation (कार्यान्वयन)

### Client Side (JS)
- `planning-grid.js`: Staleness monitor checks every 2s
- Visual banner (amber/red) when data stale/dead
- `data-freshness` attribute on all grid containers
- `window.__c3i_staleness()` for external monitoring
- Auto-retry: WS ping when stale, full HTTP refresh when dead

### Server Side (Gleam)
- `ha/freshness_monitor.gleam`: L0_CONSTITUTIONAL actor
- `FreshnessState`: tracks check count, stale count, actions taken
- `ControlAction`: NoAction → WarnLog → AttemptReload → EscalateEmergency → JidokaHalt
- `/api/v1/health/freshness`: endpoint reports pipeline health

### Automated Tests
- `data_freshness_wiring_test.gleam`: 27 tests verify ALL data pipelines
- NIF: plan_status, plan_list, system_health, system_dashboard
- SSR: all 31 views render with live state
- WS: state types constructable, connection tracking works
- Consistency: cross-NIF data matches

## Mathematical Safety Proof (गणितीय सुरक्षा प्रमाण)

```
Let T_display = timestamp when data was last rendered on screen
Let T_source = timestamp when data was last updated at source (Smriti.db)
Let Δ = T_display - T_source (data age)

Safety invariant: Δ < T_threshold (60s)

If Δ ≥ T_threshold:
  P(wrong_decision | stale_data) > P(wrong_decision | fresh_data)
  Risk = Severity × P(wrong_decision | stale_data)
  
  For safety-critical: Severity = CATASTROPHIC
  Therefore: ANY staleness = UNACCEPTABLE RISK
  
  Control action MUST be taken to either:
    1. Refresh the data (reduce Δ to 0)
    2. Alert the operator that data may be stale
    3. Halt operations that depend on stale data
```

## Why This Is Fundamental (यह मूलभूत क्यों)

1. **Lives depend on it**: Wrong container status → wrong restart → cascading failure → outage
2. **Trust depends on it**: If operator sees stale data and acts on it, trust in system is destroyed
3. **Psi-5 (Truthfulness)**: The system MUST NOT deceive. Stale data IS deception.
4. **Omega-0 (Founder)**: The system serves the founder. Lying to the founder = violation.

## Files (फ़ाइलें)
| File | Purpose | Lines |
|------|---------|-------|
| `ha/freshness_monitor.gleam` | L0 safety actor — escalating control actions | 230 |
| `test/data_freshness_wiring_test.gleam` | 27 automated wiring tests | 230 |
| `planning-grid.js` | Client staleness monitor + visual banner | +80 |
| `router.gleam` | `/api/v1/health/freshness` endpoint | +20 |
| `.gemini/rules/truth-freshness-safety.md` | This rule — INVIOLABLE | — |
