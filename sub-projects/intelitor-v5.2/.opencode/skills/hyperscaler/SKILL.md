---
name: hyperscaler
description: allowed-tools: Read, Grep, Glob, WebSearch, mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query
---
---

# Hyperscaler Comparison Command

Compare Indrajaal against hyperscaler reference implementations.

## Usage
```
/hyperscaler observability
/hyperscaler lib/indrajaal/observability/
/hyperscaler "distributed tracing"
```

## Reference Systems

### Google
- Monarch (metrics), Dapper (tracing), Borg (orchestration), Spanner (DB)

### Meta
- Scuba (analytics), Hive (warehouse), TAO (graph), Gorilla (TSDB)

### Netflix
- Atlas (metrics), Edgar (tracing), Hystrix (resilience), Chaos Monkey

### Microsoft
- Azure Monitor, Application Insights, Cosmos DB, Service Fabric

## Comparison Categories
- Metrics collection
- Distributed tracing
- Log aggregation
- Resilience patterns
- Chaos engineering
- Auto-scaling

## Steps
1. Identify Indrajaal components for: $ARGUMENTS
2. Map to hyperscaler equivalents
3. Score feature coverage (1-10)
4. Identify unique advantages
5. Generate adoption roadmap

## Live Baseline
1. Indrajaal health: `sentinel(action: "health")`
2. Zenoh mesh metrics: `zenoh_query(action: "metrics")`
3. Compare against hyperscaler published benchmarks

## Mathematical Foundation

**Amdahl's Law**: $S(n) = \frac{1}{(1-p) + \frac{p}{n}}$ where $p$ = parallelizable fraction, $n$ = nodes

**Scale Factor**: $\eta = \frac{T_{actual}}{T_{linear}}$ — measures scaling efficiency

**Reliability at Scale**: $R_{system} = 1 - (1 - R_{node})^n$ for $n$ redundant nodes

**Latency Budget**: $L_{total} = L_{app} + L_{network} + L_{serialization} < SLA_{p99}$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-PRF-050 | Response < 50ms |
| SC-SIL6-006 | 2oo3 voting MANDATORY |
| SC-EMR-057 | Emergency stop < 5s |

## Output
- Feature matrix comparison
- Maturity score per category
- Live Sentinel health baseline
- Unique Indrajaal advantages
- Pattern adoption recommendations
