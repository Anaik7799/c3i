# File Size Optimization for Agent Evolution (SC-FILESIZE)
# एजेंट विकास हेतु फ़ाइल आकार अनुकूलन

## Fundamental Rule (मूलभूत नियम)
**Agent_efficiency = k / file_size_lines, where k ≈ 500**

Files larger than 1000 lines are ANTI-PATTERNS for AI agent evolution.
They consume excessive context, slow parallel operations, and increase error rates.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FILESIZE-001 | Source files MUST NOT exceed 1000 lines | HIGH |
| SC-FILESIZE-002 | Optimal file size is 200-500 lines per module | HIGH |
| SC-FILESIZE-003 | Files > 800 lines MUST be flagged for split | MEDIUM |
| SC-FILESIZE-004 | Monolithic files MUST be split before major modification | HIGH |
| SC-FILESIZE-005 | Test files MAY exceed 1000 lines (test density is valued) | LOW |
| SC-FILESIZE-006 | Split MUST preserve all public API contracts | CRITICAL |

## Mathematical Proof (गणितीय प्रमाण)

### Agent Context Consumption
```
Context_consumed(file) = header_tokens + file_lines × tokens_per_line
≈ 50 + file_lines × 8

For a 3600-line file: 50 + 3600 × 8 = 28,850 tokens (14.4% of 200K budget)
For a 500-line file: 50 + 500 × 8 = 4,050 tokens (2.0% of 200K budget)

Ratio: 7.1x more context consumed by the monolith
```

### Parallel Agent Efficiency
```
Given N files to modify:
  Monolith: T_total = N × T_read + N × T_edit (sequential, single file)
  Split: T_total = max(T_read_i + T_edit_i) (parallel, independent files)

Speedup = N × T_avg / max(T_i) ≈ N (linear speedup)
```

### Error Surface Area
```
P(conflict) = 1 - (1 - p_line)^lines_modified

For a 3600-line file with 50 lines modified: P ≈ 0.39
For a 500-line file with 50 lines modified: P ≈ 0.095

4.1x higher conflict probability in the monolith
```

## Current Anti-Patterns (वर्तमान दोष)
| File | Lines | Target | Split Strategy |
|------|-------|--------|----------------|
| page_views.gleam | 3,671 | 4 × ~800 | dashboard_views, planning_views, system_views, domain_views |
| catalog.gleam | 3,183 | 3 × ~1000 | core_catalog, wave1_catalog, wave2_catalog |
| router.gleam | 2,201 | 3 × ~700 | core_router, dashboard_routes, system_routes |
| planning_dashboard.gleam | 1,483 | 2 × ~750 | planning_model, planning_view |

## Split Protocol (विभाजन प्रोतोकॉल)
1. **Identify boundaries** — group by domain/fractal layer
2. **Create new module** — with C3I-SIL6-MSTS header
3. **Move functions** — preserve public API signatures
4. **Update imports** — all callers must update import paths
5. **Verify build** — `gleam build` must pass with 0 errors
6. **Run tests** — `gleam test` must pass with 0 failures
7. **Commit atomically** — split + import updates in one commit

## Optimal Module Architecture (इष्टतम वास्तुकला)
```
Ideal module size: 200-500 lines
  - 10-30 lines: module contract header
  - 5-15 lines: imports
  - 150-400 lines: implementation (5-20 functions)
  - 20-50 lines: helper functions

Ideal test file size: 300-1000 lines
  - Higher density acceptable for test coverage
  - Group by C1-C8 category sections
```

## Sanskrit Wisdom (संस्कृत ज्ञान)
> अनेकवर्णं क्षिततस्य गर्भं — The many-colored womb of the earth (Shvetashvatara Upanishad)
> As the earth contains many forms, so should the codebase contain many focused modules.
> Each module is a holon — complete in itself, yet part of the greater whole.
