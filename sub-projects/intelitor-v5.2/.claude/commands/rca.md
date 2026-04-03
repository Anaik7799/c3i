---
description: 5-Level Root Cause Analysis with Zenoh telemetry and Sentinel health correlation
allowed-tools: Read, Grep, Glob, Bash(git:*), mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query, mcp__sentinel-zenoh__test_fsharp_logs
argument-hint: [error-description|file:line]
---

# 5-Level Root Cause Analysis (TPS Jidoka Methodology)

Apply Jidoka 5-Why analysis with live system telemetry from Zenoh/Sentinel MCP.

## Analysis Framework:

### Level 1: Symptom
- What error/failure occurred?
- Where did it manifest? (file:line)
- Sentinel health at time of failure: `sentinel(action: "health")`

### Level 2: Immediate Cause
- What code directly caused the symptom?
- What was the expected vs actual behavior?
- FFI bridge state: `zenoh_query(action: "metrics")` — any anomalies?

### Level 3: Contributing Factors
- What conditions enabled this to happen?
- Are there missing validations or guards?
- Threat correlation: `sentinel(action: "threats")` — related threats active?
- F# test failures: `test_fsharp_logs(count: 10)` — related F# errors?

### Level 4: Systemic Issues
- Is this a pattern that exists elsewhere?
- Does this violate any SC-* constraints?
- Zenoh invariant check: `zenoh_query(action: "verify")` — invariant violations?

### Level 5: Root Cause
- What fundamental issue allowed this to occur?
- What process/practice change prevents recurrence?
- Map to STAMP constraint family for prevention

## Mathematical Foundation

**Causal Chain Probability**: $P(root) = \prod_{i=1}^{5} P(cause_i | cause_{i-1})$

**Bayesian Belief Update**: $P(H|E) = \frac{P(E|H) \cdot P(H)}{P(E)}$ — update hypothesis given evidence

**FMEA Risk Priority**: $RPN = S \times O \times D$ where $S$ = severity, $O$ = occurrence, $D$ = detection

**Defect Density**: $\rho_{defect} = \frac{\text{defects found}}{\text{KLOC inspected}}$

## Output:
- RCA summary with all 5 levels
- Affected files and lines
- Live telemetry correlation (Sentinel + Zenoh)
- STAMP constraint mapping
- Recommended fixes with code snippets
- Prevention measures (tests, constraints, monitoring)
- FMEA: Severity × Occurrence × Detection = RPN
