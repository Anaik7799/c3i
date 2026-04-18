# Evolution KPI Tracking & Validation Protocol (SC-EVO-KPI)
# विकास केपीआई अनुवर्तन एवं मान्यता प्रोतोकॉल

## Supreme Mandate (सर्वोच्च आदेश)
**Every proposed evolution MUST have measurable KPIs. Every deployed evolution MUST be periodically validated. Evolutions that don't improve metrics MUST be reverted.**

> परिणामे दुःखम् — If the outcome brings suffering, the action was wrong (Yoga Sutra 2.15)
> यत्र योगेश्वरः कृष्णो — Where there is measurement, there is mastery (Gita 18.78)

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-EVO-KPI-001 | Every evolution MUST define ≥ 3 benchmark KPIs before implementation | HIGH |
| SC-EVO-KPI-002 | KPI baseline MUST be measured BEFORE change | CRITICAL |
| SC-EVO-KPI-003 | KPI post-measurement MUST occur within same session | HIGH |
| SC-EVO-KPI-004 | All KPIs MUST be ingested into Zettelkasten | HIGH |
| SC-EVO-KPI-005 | Periodic validation check every 7 days (or next session) | MEDIUM |
| SC-EVO-KPI-006 | Evolution with negative KPI delta MUST be flagged for review | HIGH |
| SC-EVO-KPI-007 | Operational impact assessment REQUIRED before implementation | HIGH |

## Evolution Proposal Template (विकास प्रस्ताव)

Before implementing ANY evolution, document:

```markdown
## Evolution: [Name]
### Operational Impact Assessment (प्रभाव आकलन)
- **Scope**: Which fractal layers affected? (L0-L7)
- **Risk**: What could break? (FMEA: Severity × Occurrence × Detection)
- **Reversibility**: How to undo? (git revert? config change? server restart?)

### Benchmark KPIs (मानदण्ड)
| KPI | Baseline (Before) | Target (After) | Measurement Method |
|-----|-------------------|----------------|-------------------|
| KPI-1 | X | Y | How to measure |
| KPI-2 | X | Y | How to measure |
| KPI-3 | X | Y | How to measure |

### Post-Implementation Validation (कार्योत्तर मान्यता)
- [ ] KPI-1 measured: actual = ___
- [ ] KPI-2 measured: actual = ___
- [ ] KPI-3 measured: actual = ___
- [ ] Ingested to Zettelkasten: holon ID = ___
- [ ] Next validation date: YYYY-MM-DD
```

## Current KPI Baseline (वर्तमान आधार रेखा — 2026-04-11)

### Build & Test KPIs
| KPI | Value | Unit | Measurement |
|-----|-------|------|-------------|
| gleam build time | 0.18 | seconds | `time gleam build` (incremental) |
| gleam build time (clean) | 2.73 | seconds | `time gleam build` (after rm -rf) |
| gleam test count | 4,050 | tests | `gleam test \| tail -1` |
| gleam test failures | 0 | failures | `gleam test \| tail -1` |
| gleam warnings (src) | 0 | warnings | `gleam build \| grep warning` |
| Shannon Entropy H | 2.67 | bits | coverage_math.gleam |

### Codebase KPIs
| KPI | Value | Unit | Measurement |
|-----|-------|------|-------------|
| Total .gleam src files | 291 | files | `find src -name "*.gleam" \| wc -l` |
| Total .gleam test files | 88 | files | `find test -name "*.gleam" \| wc -l` |
| Total src LOC | 56,003 | lines | `find src -name "*.gleam" \| xargs wc -l` |
| Monolith files (>800 lines) | 5 | files | `find src ... \| awk '$1>800'` |
| Largest file | 3,671 | lines | page_views.gleam |

### Infrastructure KPIs
| KPI | Value | Unit | Measurement |
|-----|-------|------|-------------|
| WebSocket endpoints | 2 | endpoints | /ws/planning, /ws/dashboard |
| API endpoints | 12+ | endpoints | `grep "->.*_json()" router.gleam` |
| Hot reload available | yes | boolean | `curl /api/v1/reload` |
| Server port | 4100 | port | `curl /health` |
| NIF count | 14 | NIFs | c3i_nif.so |
| MCP tools | 73 | tools | sa-plan-daemon + Gleam |

### Claude Productivity KPIs
| KPI | Value | Unit | Measurement |
|-----|-------|------|-------------|
| Rules count | 65 | files | `ls .claude/rules/ \| wc -l` |
| Commands count | 6 | files | `ls .claude/commands/ \| wc -l` |
| Memory files | 13 | files | `ls memory/ \| wc -l` |
| Auto-build hook | active | boolean | settings.json PostToolUse |
| Auto-test hook | active (async) | boolean | settings.json PostToolUse |
| Duplicate rules | 0 | files | rules/rules/ removed |

## Validation Cycle (मान्यता चक्र)

### Per-Session Check (प्रति सत्र)
At session start, verify critical KPIs haven't regressed:
```bash
gleam build 2>&1 | tail -1  # Must show "Compiled in X.XXs"
gleam test 2>&1 | tail -1   # Must show "N passed, 0 failures" where N >= 4050
curl -s https://localhost:4100/health | jq .status  # Must be "ok"
```

### Weekly Validation (साप्ताहिक)
Every 7 days, compare current KPIs against baseline:
1. Run full KPI measurement
2. Compare with baseline in this file
3. Flag any regression (KPI_current < KPI_baseline × 0.95)
4. Update baseline if improvement confirmed
5. Ingest validation report to Zettelkasten

### Evolution Retirement (विकास सेवानिवृत्ति)
If an evolution's KPIs show no improvement after 14 days:
1. Flag for review
2. Assess whether the evolution should be reverted
3. If reverting: `git revert` + update Zettelkasten with "retired" tag
4. If keeping: document why KPIs don't capture the value

## Mathematical Validation (गणितीय मान्यता)
```
∀ evolution E:
  ΔKPIs(E) = KPIs_after - KPIs_before
  
  E is BENEFICIAL iff:
    Σ(weight_i × ΔKPI_i) > 0
    AND ∀ critical_KPI: ΔKPI_critical ≥ 0 (no regression on critical metrics)
  
  E is HARMFUL iff:
    ∃ critical_KPI: ΔKPI_critical < -0.05 (>5% regression)
    
  E is NEUTRAL iff:
    |Σ(weight_i × ΔKPI_i)| < 0.01 (negligible change)
    → Flag for retirement review
```
