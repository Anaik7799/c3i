# GRL Rules Directory

Externalized Grule Rule Language (GRL) files for the RETE-UL rule engine.

## Current Status

All 52 rules across 13 domains are currently **embedded** in `src/rule_engine.rs` as Rust string constants, cached via `OnceLock<Vec<Rule>>` for <1ms evaluation.

This directory is for future externalization — loading rules from files at startup instead of embedding them in the binary. This enables:
- Operator-tunable rules without recompilation
- Environment-specific rule sets (dev/staging/prod)
- A/B testing of rule changes
- Dynamic rule injection via Zenoh

## Domains

| Domain | File | Rules | API |
|--------|------|-------|-----|
| OODA Decide | `ooda.grl` | 7 | `evaluate_decision()` |
| Preflight Gate | `preflight.grl` | 4 | `evaluate_preflight()` |
| Recovery Selection | `recovery.grl` | 6 | `evaluate_recovery()` |
| Health Consensus | `health.grl` | 4 | `evaluate_health_consensus()` |
| Cascade Containment | `cascade.grl` | 3 | `evaluate_cascade()` |
| Partition Fencing | `partition.grl` | 3 | `evaluate_partition()` |
| Launch Tier Gate | `launch.grl` | 3 | `evaluate_launch_tier()` |
| CPU Governor | `governor.grl` | 3 | `evaluate_governor()` |
| Verify Compliance | `verify.grl` | 3 | `evaluate_verify()` |
| Build Staleness | `build.grl` | 3 | `evaluate_build()` |
| Apoptosis Grace | `apoptosis.grl` | 4 | `evaluate_apoptosis()` |
| RCA Escalation | `rca.grl` | 4 | `evaluate_rca()` |
| Hysteresis Config | `hysteresis.grl` | 3 | `evaluate_hysteresis()` |

## Usage (future)

```bash
# Use default embedded rules
./sa-up ooda --cycles 10

# Use custom rules from directory
./sa-up ooda --cycles 10 --rules-dir ./rules/

# Override single domain
./sa-up ooda --cycles 10 --rules-file preflight=./custom_preflight.grl
```

## GRL Syntax Reference

```grl
rule "Rule Name" salience 100 {
    when
        Fact.Key == true && Fact.Other == false
    then
        Fact.Decision = "ActionName";
        Fact.Reason = "Why this action was chosen";
}
```

- **salience**: Priority (higher = evaluated first). Range 1-1000.
- **when**: Boolean condition over facts.
- **then**: Fact mutations (set Decision + Reason).
- Engine: rust-rule-engine v1.20.1 (RETE-UL with Alpha/Beta Memory Indexing)
