---
description: Discover and explain scripts from 87 directories (1,475 scripts)
allowed-tools: Read, Grep, Glob, Bash(wc:*), Bash(head:*)
argument-hint: [keyword|category|path]
---

# Script Discovery (SC-BATCH-001, SC-BATCH-002)

Find and explain automation scripts across 87 directories (1,475 scripts).

## Usage
```
/scripts testing              # Find testing scripts
/scripts "zenoh"               # Search by keyword
/scripts scripts/demo/         # List scripts in directory
/scripts compile               # Find compilation scripts
```

## Script Categories
| Category | Count | Location |
|----------|-------|----------|
| Elixir Testing | 100+ | `scripts/testing/` |
| Elixir Demo | 56 | `scripts/demo/` |
| F# Runtime | 14 | `lib/cepaf/scripts/` |
| Infrastructure | 20+ | `scripts/infrastructure/` |
| Performance | 10+ | `scripts/performance/` |
| SOP v5.11 | 7 | `scripts/sopv511/` |
| Agents | 10+ | `scripts/agents/` |
| GA Release | 5+ | `scripts/ga-release/` |
| Version | 3+ | `scripts/version/` |

## Search Steps
1. Glob for scripts matching keyword: `scripts/**/*{keyword}*`
2. Read first 10 lines of each match for description
3. Categorize by purpose (test, deploy, validate, report)
4. Report with usage instructions

## Mathematical Foundation

**Script Density**: $\rho_s = \frac{|\text{scripts}|}{|\text{directories}|} = \frac{1475}{87} \approx 17$ scripts/directory

**Coverage**: $C_{script} = \frac{|\text{automated workflows}|}{|\text{total workflows}|}$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-BATCH-001 | Max 10 changes per batch |
| SC-BATCH-002 | Elixir scripts ONLY |
| SC-BATCH-005 | Reversible operations |
| SC-CEP-005 | Pre-compiled F# for production |
