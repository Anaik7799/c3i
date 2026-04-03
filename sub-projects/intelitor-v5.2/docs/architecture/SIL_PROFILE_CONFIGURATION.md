# SIL-Level Configuration Profiles

**Version**: 1.0.0
**Created**: 2026-01-02
**Author**: Agent 31.3 - SIL Profile Engineer
**STAMP**: SC-SIL6-003, SC-CONFIG-002, SC-PRAJNA-001

## Overview

The Indrajaal Prajna cockpit implements four distinct configuration profiles, each optimized for specific operational contexts and safety requirements. This document details the implementation of SIL-level profiles that adapt system behavior from relaxed development settings to strict IEC 61508 SIL-6 Biomorphic safety-critical operation.

## Profile Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Profiles                    │
├────────────┬────────────┬─────────────┬────────────────────┤
│    :dev    │   :test    │    :prod    │       :sil4        │
│  (Debug)   │  (Speed)   │ (Balanced)  │  (Safety-Critical) │
├────────────┼────────────┼─────────────┼────────────────────┤
│ 10s timeout│  1s timeout│  5s timeout │  2s timeout MAX    │
│ Relaxed CB │   Fast CB  │ Balanced CB │  Aggressive CB     │
│ Fail-Open  │ Fail-Open  │  Fail-Open  │  Fail-Closed       │
│ Optional   │  Optional  │  Mandatory  │  Mandatory         │
│ Verify     │   Verify   │   Verify    │  Verify + Dual-Ch  │
└────────────┴────────────┴─────────────┴────────────────────┘
```

## Profile Specifications

### Development Profile (`:dev`)

**Purpose**: Relaxed timeouts and disabled safety mechanisms for debugging and development.

**Key Characteristics**:
- **Guardian Timeout**: 10s (relaxed for debugging)
- **Circuit Breaker**: Threshold 5 (effectively disabled)
- **Dual-Channel**: 10s timeout, halt on 3 disagreements
- **Watchdog**: 10s heartbeat, 2s check interval
- **Fail Mode**: Open (continue on errors)
- **Verification**: Optional (disabled by default)

**Use Cases**:
- Local development with breakpoints
- Interactive debugging sessions
- Verbose logging and stack traces
- Hot reload and live coding

### Test Profile (`:test`)

**Purpose**: Fast, deterministic timing optimized for test suite execution.

**Key Characteristics**:
- **Guardian Timeout**: 1s (fast execution)
- **Circuit Breaker**: Threshold 2 (quick failure)
- **Dual-Channel**: 1s timeout, halt on 2 disagreements
- **Watchdog**: 1s heartbeat, 200ms check interval
- **Fail Mode**: Open (mock-friendly)
- **Verification**: Optional (disabled for speed)

**Use Cases**:
- Automated test suite execution
- Continuous integration pipelines
- Mock-based testing
- Performance benchmarks

### Production Profile (`:prod`)

**Purpose**: Balanced timeouts with circuit breaker enabled for production operation.

**Key Characteristics**:
- **Guardian Timeout**: 5s (default balanced)
- **Circuit Breaker**: Threshold 3 (balanced)
- **Dual-Channel**: 5s timeout, halt on 1 disagreement
- **Watchdog**: 2s heartbeat, 500ms check interval
- **Fail Mode**: Open (high availability)
- **Verification**: Mandatory (immutable state on startup)

**Use Cases**:
- Standard production deployment
- Cloud environments
- High-availability systems
- General operational use

### SIL-6 Biomorphic Profile (`:sil4`)

**Purpose**: Strict 2s maximum timeout with all safety mechanisms enabled per IEC 61508 SIL-6 Biomorphic requirements.

**Key Characteristics**:
- **Guardian Timeout**: 2s (STRICT maximum per IEC 61508)
- **Emergency Timeout**: 2s (critical operations)
- **Circuit Breaker**: Threshold 1 (fail-fast, immediate)
- **Dual-Channel**: 2s timeout, halt on FIRST disagreement
- **Watchdog**: 1s heartbeat, 250ms check interval
- **Fail Mode**: Closed (safe state on errors)
- **Verification**: Mandatory (redundant verification required)
- **Retry Attempts**: 1 (minimal to prevent cascading failures)
- **Target PFH**: < 10^-8 (IEC 61508 SIL-6 Biomorphic requirement)

**Safety Mechanisms**:
1. **Dual-Channel Verification**: Byzantine fault tolerance
2. **Aggressive Circuit Breaker**: Fail-fast on errors
3. **Strict Timeouts**: ≤ 2s for critical operations
4. **Mandatory State Verification**: Immutable state chain validation
5. **Fail-Closed Mode**: Safe state on all errors
6. **Minimal Retries**: Prevent cascading failures
7. **High-Frequency Monitoring**: 250ms watchdog checks

**IEC 61508 Compliance**:
- **PFH Target**: < 10^-8 failures/hour
- **MTBF Target**: > 100,000,000 hours (11,415 years)
- **Redundancy**: Dual-channel verification mandatory
- **Fail-Safe**: Fail-closed mode enforced
- **Verification**: Cryptographic hash chain validation

**Use Cases**:
- Safety-critical infrastructure
- Medical device control
- Industrial automation
- Nuclear/aerospace applications
- High-consequence environments

## Configuration Keys

All profiles include complete settings for:

### Core Timeouts
- `guardian_timeout_ms` - Guardian proposal validation
- `sentinel_emergency_timeout_ms` - Emergency sync timeout
- `orchestrator_command_timeout_ms` - Command execution timeout
- `proof_token_ttl_ms` - PROMETHEUS proof token TTL

### Circuit Breaker
- `circuit_breaker_threshold` - Failures before circuit opens
- `circuit_breaker_reset_ms` - Time before circuit reset
- `circuit_telemetry_threshold` - Telemetry queue threshold
- `circuit_critical_threshold` - Critical mode threshold
- `circuit_emergency_threshold` - Emergency halt threshold

### Dual-Channel (SC-REG-007)
- `dual_channel_timeout_ms` - Dual-channel verification timeout
- `dual_channel_halt_threshold` - Disagreements before HALT

### Watchdog (SC-PRIME-001)
- `watchdog_heartbeat_timeout_ms` - Heartbeat timeout
- `watchdog_check_interval_ms` - Health check interval
- `watchdog_escalation_threshold` - Failures before Guardian escalation
- `watchdog_restart_delay_ms` - Delay before process restart

### Safety Modes
- `fail_closed_mode` - Enable fail-closed mode
- `immutable_state_verify_on_startup` - Verify hash chain on startup

### Metrics & Monitoring
- `smart_metrics_staleness_ms` - Metric staleness threshold
- `smart_metrics_interval_ms` - Metrics collection interval
- `dashboard_refresh_ms` - Dashboard refresh interval
- `ooda_cycle_ms` - OODA loop cycle time

## Usage

### Getting a Profile

```elixir
# Get complete configuration map for a profile
dev_config = Config.profile(:dev)
test_config = Config.profile(:test)
prod_config = Config.profile(:prod)
sil4_config = Config.profile(:sil4)
```

### Applying a Profile

```elixir
# Apply hot-reloadable settings from a profile
case Config.apply_profile(:sil4) do
  {:ok, applied_keys} ->
    Logger.info("Applied SIL-6 Biomorphic profile: #{inspect(applied_keys)}")

  {:error, :restart_required, cold_keys} ->
    Logger.warning("Restart required for: #{inspect(cold_keys)}")
end
```

### Profile Summary

```elixir
# Get human-readable profile summary
summary = Config.profile_summary(:sil4)
# => %{
#   name: :sil4,
#   description: "SIL-6 Biomorphic - strict 2s timeouts, all safety mechanisms enabled",
#   max_timeout_ms: 2_000,
#   circuit_breaker: :aggressive,
#   dual_channel: :mandatory,
#   fail_mode: :closed,
#   verification: :mandatory,
#   watchdog: :aggressive,
#   target_pfh: 1.0e-8,
#   redundancy: :dual_channel,
#   iec_61508: "SIL-6 Biomorphic"
# }
```

### SIL-6 Biomorphic Target PFH

```elixir
# Get IEC 61508 SIL-6 Biomorphic target PFH
pfh = Config.sil4_target_pfh()
# => 1.0e-8 (< 0.00000001 failures/hour)
```

### Comparing Profiles

```elixir
# Compare current configuration with a profile
diff = Config.diff_with_profile(:sil4)
# => %{
#   guardian_timeout_ms: {5_000, 2_000},  # {current, profile}
#   fail_closed_mode: {false, true}
# }
```

## Profile Strictness Ordering

Profiles are ordered by increasing strictness:

```
:dev → :prod → :sil4

Timeouts:     10s → 5s → 2s
CB Threshold:  5  → 3  → 1
Safety:       None → Some → All
Verification: Off → On → Redundant
```

**Special Case**: `:test` profile is optimized for speed (1s timeouts) but has minimal safety features, making it unsuitable for production or safety-critical use.

## Hot Reload vs. Restart Required

Configuration keys are classified by fractal level (L1-L5), which determines hot-reload capability:

- **L1-L3 (Agent/Module)**: Hot-reloadable
- **L4 (Container)**: Some hot-reloadable, others require restart
- **L5 (Constitutional)**: NEVER hot-reloadable (restart required)

Example:
```elixir
Config.hot_reloadable?(:circuit_breaker_threshold)  # => true (L4, hot_reload: true)
Config.hot_reloadable?(:fail_closed_mode)           # => false (L5, constitutional)
```

## Validation

All profiles are validated against the schema on startup and when applied:

```elixir
# Validate a profile configuration
case Config.validate(Config.profile(:sil4)) do
  {:ok, config} -> Logger.info("SIL-6 Biomorphic profile valid")
  {:error, errors} -> Logger.error("Validation failed: #{inspect(errors)}")
end
```

## Environment Mapping

Profiles are automatically selected based on Mix environment:

| Mix.env | Default Profile |
|---------|----------------|
| `:dev`  | `:dev`         |
| `:test` | `:test`        |
| `:prod` | `:prod`        |
| other   | `:prod`        |

Override with application config:
```elixir
config :indrajaal, Indrajaal.Cockpit.Prajna.Config,
  active_profile: :sil4
```

## STAMP Constraints

- **SC-SIL6-003**: Safe defaults for SIL-6 Biomorphic operation
- **SC-CONFIG-002**: Validation on startup
- **SC-PRAJNA-001**: All commands through Guardian pre-approval
- **SC-REG-007**: Extension recording must be verified
- **SC-PRIME-001**: Will to Live - System SHALL NOT optimize to zero

## AOR Rules

- **AOR-PRAJNA-001**: Prajna commands MUST pass Guardian validation
- **AOR-CONST-002**: Immediate Halt - If constitutional violation detected
- **AOR-HOLON-001**: SQLite State - ALL holon real-time state in SQLite

## Testing

Comprehensive test suite in `test/indrajaal/cockpit/prajna/config_sil_profiles_test.exs`:

- Profile characteristic validation
- Strictness ordering verification
- IEC 61508 SIL-6 Biomorphic compliance checks
- Hot reload capability tests
- Configuration validation tests

Run tests:
```bash
mix test test/indrajaal/cockpit/prajna/config_sil_profiles_test.exs
```

## References

- [IEC 61508](https://www.iec.ch/functional-safety) - Functional Safety Standard
- [SC-SIL6 Constraints](../safety/STAMP_CONSTRAINTS.md#sil4)
- [Prajna Architecture](PRAJNA_BIOMORPHIC_INTEGRATION.md)
- [Configuration Schema](../../lib/indrajaal/cockpit/prajna/config.ex)

## Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-02 |
| Status | ACTIVE |
| Owner | SIL Profile Engineer (Agent 31.3) |
