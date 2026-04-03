---
description: Code review with MCP intelligence — quality, patterns, architecture, Constitutional alignment
allowed-tools: Read, Grep, Glob, Bash(git diff:*), Bash(git log:*), mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query
argument-hint: [file-path|module|--staged|--branch]
---

# Code Review (SC-CHG-001, SC-FUNC-001)

Comprehensive code review with live Sentinel health context and architectural analysis.

## Usage
```
/review lib/indrajaal/safety/guardian.ex    # Review specific file
/review --staged                            # Review staged changes
/review --branch feature/xyz                # Review branch diff
```

## Review Dimensions
1. **Quality**: Credo patterns, naming, complexity
2. **Safety**: STAMP constraint compliance
3. **Architecture**: Holon boundaries, fractal consistency
4. **Constitutional**: Ψ₀-Ψ₅ invariant preservation
5. **Performance**: SC-PRF-050 latency budget

## Workflow
1. Get diff: `git diff` or `git diff --staged`
2. Check system health: `sentinel(action: "health")`
3. Verify invariants: `zenoh_query(action: "verify")`
4. Analyze each changed file for:
   - STAMP constraint violations
   - Ash resource patterns (SC-ASH-*)
   - Property test coverage (SC-PROP-*)
   - Error patterns (EP-GEN-014, EP-VAR-001)
5. Generate review report with actionable items

## Mathematical Foundation

**Cyclomatic Complexity**: $V(G) = E - N + 2P$ — edges minus nodes plus 2× connected components

**Change Risk**: $R_{change} = \sum_{l=1}^{4} w_l \cdot I_l$ — 4-layer impact score (SC-CHG-002)

**Review Coverage**: $C_{review} = \frac{|reviewed\_hunks|}{|total\_hunks|}$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-CHG-001 | Structured change notes |
| SC-CHG-002 | 4-layer impact analysis |
| SC-FUNC-001 | System MUST compile |
| SC-CREDO-001 | Direct calls (no apply) |
| SC-PROP-023 | PropCheck/StreamData disambiguation |
