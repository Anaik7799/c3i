---
paths: lib/indrajaal/safety/sentinel.ex, lib/indrajaal/safety/pattern_hunter.ex, lib/indrajaal/safety/symbiotic_defense.ex
---
# Immune System Rules (v21.2.1-SIL6)
The Digital Immune System provides T-Cell-like protection for the Indrajaal holon.
# STAMP Constraints (SC-IMMUNE-*)
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-IMMUNE-001 | Sentinel health scoring MUST use 0-100 scale | CRITICAL | Unit Test |
| SC-IMMUNE-002 | Circuit breaker triggers at >10% error rate | CRITICAL | Property Test |
| SC-IMMUNE-003 | Memory alerts at sustained >80% for >5 minutes | HIGH | Integration Test |
| SC-IMMUNE-004 | Quarantine MUST isolate before termination | CRITICAL | State Machine |
| SC-IMMUNE-005 | Recovery attempts limited to 3 before escalation | HIGH | Counter Verify |
| SC-IMMUNE-006 | All immune actions logged to DuckDB | HIGH | Audit Trail |
| SC-IMMUNE-007 | Guardian notification required for CRITICAL threats | CRITICAL | Event Verify |
| SC-IMMUNE-008 | Founder's Directive threats get IMMEDIATE response | INFINITE | Priority Check |
| SC-IMMUNE-009 | Threat scoring uses weighted multi-factor formula | HIGH | Algorithm Test |
| SC-IMMUNE-010 | False positive rate MUST be <5% | HIGH | Statistical Test |
# AOR Rules
> AOR-IMMUNE-001 to AOR-IMMUNE-004 — defined in CLAUDE.md §9.0
> Key: Sentinel health check before critical ops, kernel process protection, PatternHunter baseline calibration, RPN >= 50 → Guardian
> Extended: AOR-IMMUNE-005: Recovery path: Restart → Reconfigure → Rollback → Manual
# Module Specifications
# Sentinel (`sentinel.ex`)
```elixir
# Required callbacks
@callback calculate_health(metrics :: map()) :: 0..100
@callback should_quarantine?(pid :: pid(), health :: integer()) :: boolean()
@callback attempt_recovery(pid :: pid(), strategy :: atom()) :: {:ok, pid()} | {:error, term()}
```
**Critical Functions**:
- `start_monitoring/1` - Begin T-Cell observation of a process
- `get_health_score/1` - Retrieve current health (0-100)
- `quarantine/2` - Isolate a misbehaving process
- `initiate_recovery/2` - Attempt to restore health
# PatternHunter (`pattern_hunter.ex`)
```elixir
# Detection patterns
@patterns [
memory_leak: %{threshold: 0.8, duration: 300_000},
cpu_spike: %{threshold: 0.9, duration: 60_000},
message_queue_growth: %{threshold: 1000, rate: 100}
]
```
**Critical Functions**:
- `hunt_patterns/0` - Scan for known threat patterns
- `analyze_memory/1` - Deep memory analysis for leaks
- `calculate_threat_score/1` - Weighted threat assessment
# SymbioticDefense (`symbiotic_defense.ex`)
```elixir
# Threat levels
@threat_levels [
:green,      # Normal operation
:yellow,     # Elevated monitoring
:orange,     # Active mitigation
:red,        # Critical response
:black       # Founder's Directive threat (SC-FOUNDER-007)
]
```
**Critical Functions**:
- `assess_system_threat/0` - Global threat assessment
- `coordinate_response/2` - Multi-module defense coordination
- `protect_founder_directive/0` - Supreme priority protection
# Testing Requirements
1. **Unit Tests**: Each immune function requires individual tests
2. **Property Tests**: Health scoring, threat calculation
3. **Integration Tests**: Full escalation path verification
4. **Chaos Tests**: Deliberate failure injection
5. **Coverage Target**: 95% minimum for immune system modules
# Known Issues (from Criticality Analysis)
# P0 Critical Issues
- Sentinel: Error rate calculation may produce non-numeric results
- Sentinel: Guardian protection gap when Guardian unavailable
- SymbioticDefense: Recovery mechanism currently non-functional
- PatternHunter: Memory leak detection logic inverted
# Required Fixes
1. Add numeric guards to all health calculations
2. Implement Guardian unavailability fallback
3. Complete recovery mechanism implementation
4. Correct memory pattern detection logic