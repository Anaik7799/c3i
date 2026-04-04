---
name: fmea
description: Failure Mode and Effects Analysis (FMEA) with live Sentinel threat correlation
---
---

# FMEA Command (IEC 61508 / ISO 26262)

Perform Failure Mode and Effects Analysis with live threat data from Sentinel MCP.

## Usage
```
/fmea lib/indrajaal/safety/sentinel.ex
/fmea Indrajaal.Cockpit.Prajna.GuardianIntegration
/fmea "immune system"
```

## FMEA Scores
- **Severity (S)**: 1-10 (10 = catastrophic / Founder's Directive threat)
- **Occurrence (O)**: 1-10 (10 = certain)
- **Detection (D)**: 1-10 (10 = undetectable)
- **RPN**: S × O × D (>200 = critical, >100 = high, >50 = medium)

## Failure Mode Categories (STPA)
- **Omission**: Not executed when expected
- **Commission**: Executed when not expected
- **Value**: Wrong output
- **Timing**: Early/late execution (>50ms = SIL-6 violation)
- **Stuck**: Continuous incorrect operation

## Steps
1. Read target: $ARGUMENTS
2. List all functions and state transitions
3. Identify failure modes for each
4. Score S, O, D for each mode
5. **Live threat correlation**:
   - Query active threats: `sentinel(action: "threats")` — correlate with identified failure modes
   - Health context: `sentinel(action: "health")` — current system health affects Occurrence scores
   - FFI metrics: `zenoh_query(action: "metrics")` — latency anomalies affect Timing modes
6. Calculate RPN with live data adjustment
7. Recommend mitigations for RPN > 50
8. Map to STAMP constraint family

## RPN Thresholds (SC-BIO-EXT)
| RPN Range | Risk Level | Action |
|-----------|------------|--------|
| 200+ | CRITICAL | Immediate fix, Guardian approval |
| 100-199 | HIGH | Sprint priority, architect review |
| 50-99 | MEDIUM | Backlog, planned fix |
| <50 | LOW | Monitor, optional improvement |

## Mathematical Foundation

**Risk Priority Number**:

$$\text{RPN} = S \times O \times D, \quad S, O, D \in [1, 10]$$

**Pareto Optimality** (mitigate highest RPN first):

$$\text{Mitigate}(m) \iff \text{RPN}(m) = \max_i \text{RPN}(f_i) \wedge \text{RPN}(m) > 50$$

**Failure Rate** (exponential distribution):

$$\lambda = \frac{1}{\text{MTTF}}, \quad P(\text{fail before } t) = 1 - e^{-\lambda t}$$

**System Failure** (series reliability):

$$P(\text{system fail}) = 1 - \prod_{i=1}^{n}(1 - P_i)$$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-BIO-EXT-001 | PatternHunter pre-error detection < 10ms |
| SC-BIO-EXT-002 | SymbioticDefense threat response < 100ms |
| SC-BIO-EXT-009 | Regenerative healing from SQLite/DuckDB |
| SC-IMMUNE-001 | Sentinel monitors system health |
| SC-IMMUNE-004 | PatternHunter detects pre-error signatures |
| SC-IMMUNE-009 | Weighted multi-factor threat scoring |
| SC-EMR-057 | Emergency stop < 5s |
| SC-EMR-060 | Rollback capability |
| SC-SIL6-001 | PFH < 10⁻¹² |
| SC-SIL6-006 | 2oo3 voting MANDATORY |

## Output
- Failure mode table with RPN scores
- Live threat correlation from Sentinel
- Pareto chart of highest risks
- Mitigation recommendations
- STAMP constraint mapping
- Fractal layer impact (L0-L7)
