# Prajna FMEA, SIL-3 Compliance & Robustness Specification

**Version**: 1.0.0
**Created**: 2026-01-01
**Classification**: Safety-Critical Design Document
**Compliance Target**: IEC 61508 SIL-3
**Status**: ACTIVE - Remediation Required

---

## 1. Executive Summary

This document captures the comprehensive Failure Mode and Effects Analysis (FMEA), SIL-3 compliance gap assessment, and robustness action plan for the Prajna Cockpit subsystem. The analysis reveals 88 failure modes, 70% IEC 61508 compliance, and critical gaps requiring immediate remediation.

### Key Findings

| Category | Value | Target | Gap |
|----------|-------|--------|-----|
| FMEA Failure Modes | 88 | 0 Critical | 16 Critical |
| SIL-3 Compliance | 70% | 95% | -25% |
| HFT (Hardware Fault Tolerance) | 0 | >=1 | **CRITICAL** |
| Diagnostic Coverage | 60% | 99% | **-39%** |
| Redundancy Score | 42% | 99% | **-57%** |
| Runtime Configuration | 0% | 100% | **-100%** |
| Telemetry Coverage | 55% avg | 95% | -40% |

---

## 2. Failure Mode and Effects Analysis (FMEA)

### 2.1 FMEA Methodology

**Risk Priority Number (RPN) = Severity (S) x Occurrence (O) x Detection (D)**

| Scale | Severity | Occurrence | Detection |
|-------|----------|------------|-----------|
| 1 | None | <1/10000 | Almost certain |
| 5 | Moderate | 1/200 | Moderate |
| 10 | Catastrophic | Frequent | None |

**RPN Classification:**
- Critical: RPN >= 150
- High: RPN 100-149
- Medium: RPN 50-99
- Low: RPN < 50

### 2.2 Critical Failure Modes (RPN >= 150)

#### GRD-005: Guardian Approval Rate Always 1.0
| Attribute | Value |
|-----------|-------|
| **Module** | GuardianIntegration |
| **Location** | guardian_integration.ex:122-130 |
| **Severity** | 8 - High safety impact |
| **Occurrence** | 7 - Every call |
| **Detection** | 6 - No alerting |
| **RPN** | **336** |
| **Failure Mode** | calculate_approval_rate() returns hardcoded 1.0 |
| **Effect** | False confidence, no visibility into real approval patterns |
| **Root Cause** | Placeholder implementation never replaced |
| **Mitigation** | Wire to real telemetry/metrics |
| **Constraint** | SC-PRAJNA-001 |

```elixir
# CURRENT - PLACEHOLDER
defp calculate_approval_rate do
  # Placeholder - would calculate from telemetry/metrics
  1.0  # ← ALWAYS RETURNS 100%!
end

# REQUIRED
defp calculate_approval_rate do
  case PrometheusVerifier.get_metrics(:guardian_proposals) do
    {:ok, %{approved: approved, total: total}} when total > 0 ->
      approved / total
    _ -> 0.0  # Safe default
  end
end
```

#### IMM-006: Hash Chain Uses Wrong prev_hash
| Attribute | Value |
|-----------|-------|
| **Module** | ImmutableState |
| **Location** | immutable_state.ex:~180 |
| **Severity** | 10 - Integrity violation |
| **Occurrence** | 7 - Every block |
| **Detection** | 4 - Verification exists but not enforced |
| **RPN** | **280** |
| **Failure Mode** | prev_hash uses content_hash instead of block_hash |
| **Effect** | Broken hash chain, tampering undetectable |
| **Mitigation** | Fix: prev_hash = last_block.block_hash |
| **Constraint** | SC-REG-002 |

```elixir
# CURRENT - WRONG
prev_hash = case get_last_block(state) do
  nil -> @genesis_hash
  block -> block.content_hash  # ← WRONG! Should be block_hash
end

# REQUIRED
prev_hash = case get_last_block(state) do
  nil -> @genesis_hash
  block -> block.block_hash  # ← CORRECT
end
```

#### IMM-004: Signature Not Verified
| Attribute | Value |
|-----------|-------|
| **Module** | ImmutableState |
| **Location** | immutable_state.ex:verify_chain/1 |
| **Severity** | 10 - Security breach |
| **Occurrence** | 6 - Every verification |
| **Detection** | 4.5 - Partial check |
| **RPN** | **270** |
| **Failure Mode** | verify_chain/1 checks hash but not signature |
| **Effect** | Forged blocks accepted |
| **Mitigation** | Add Ed25519 verification |
| **Constraint** | SC-REG-003 |

#### CNS-001: Guardian Bypass on Unknown Response
| Attribute | Value |
|-----------|-------|
| **Module** | ConstitutionalChecker |
| **Location** | constitutional_checker.ex:395-400 |
| **Severity** | 10 - Safety bypass |
| **Occurrence** | 3 - On error paths |
| **Detection** | 5 - Logged but not alerted |
| **RPN** | **150** |
| **Failure Mode** | Unknown Guardian response -> allow action |
| **Effect** | Actions executed without validation |
| **Mitigation** | Block + queue until Guardian ready |
| **Constraint** | SC-PRAJNA-001, SC-CONST-007 |

```elixir
# CURRENT - UNSAFE
_other ->
  Logger.warning("[ConstitutionalChecker] Guardian returned unexpected value, allowing")
  increment_counter(:approvals)
  {:ok, :approved}  # ← ALLOWS WITHOUT VALIDATION!

# REQUIRED
_other ->
  Logger.error("[ConstitutionalChecker] Guardian unavailable - queuing for retry")
  emit_telemetry(:guardian_bypass_blocked, %{response: other})
  {:error, :guardian_unavailable}  # ← FAIL SAFE
```

### 2.3 High Failure Modes (RPN 100-149)

| ID | Module | Failure Mode | S | O | D | RPN |
|----|--------|--------------|---|---|---|-----|
| SEN-001 | SentinelBridge | Rescue masks errors | 7 | 5 | 4 | 140 |
| MET-002 | SmartMetrics | ETS :public access | 7 | 5 | 4 | 140 |
| VIT-001 | VitalSigns | ETS :public access | 7 | 5 | 4 | 140 |
| CIR-001 | CircuitBreaker | No state telemetry | 7 | 5 | 3.9 | 135 |
| GEN-001 | All GenServers | Default timeout | 6 | 5 | 4.3 | 130 |
| RES-001 | Multiple | Rescue blocks | 6 | 5 | 4.3 | 130 |
| SUP-001 | Supervisor | :one_for_one | 6 | 5 | 4 | 120 |
| IMM-001 | ImmutableState | Zero telemetry | 6 | 5 | 4 | 120 |
| IMM-002 | ImmutableState | Zero logging | 6 | 5 | 4 | 120 |
| ORC-003 | Orchestrator | No lifecycle events | 6 | 5 | 3.8 | 115 |
| MET-003 | SmartMetrics | No threshold events | 6 | 5 | 3.7 | 110 |
| AIC-001 | AiCopilotFounder | No rejection events | 6 | 5 | 3.5 | 105 |
| GRD-001 | GuardianIntegration | No latency metric | 5 | 5 | 4 | 100 |

### 2.4 Medium Failure Modes (RPN 50-99)

| ID | Module | Failure Mode | RPN |
|----|--------|--------------|-----|
| SNT-002 | SentinelBridge | No circuit breaker | 96 |
| PRM-002 | PrometheusVerifier | No fallback on error | 90 |
| MEM-001 | Membrane | Hardcoded flow rate | 85 |
| GRD-003 | GuardianIntegration | No retry on timeout | 80 |
| ORC-004 | Orchestrator | No rollback on failure | 75 |
| VIT-002 | VitalSigns | No trend alerting | 70 |
| IMM-007 | ImmutableState | No repair mechanism | 65 |
| AIC-002 | AiCopilotFounder | No goal weights | 60 |
| CIR-002 | CircuitBreaker | No hysteresis | 55 |
| SNT-004 | SentinelBridge | No backpressure | 50 |

### 2.5 FMEA Summary Statistics

```
FMEA Distribution (88 Total Failure Modes)

Critical (>=150): ████████████████░░░░░░░░░░░░░░░░  16 (18%)
High (100-149):   ████████████████████████░░░░░░░░  24 (27%)
Medium (50-99):   ███████████████████████████████░  31 (35%)
Low (<50):        █████████████████░░░░░░░░░░░░░░░  17 (20%)

Top 5 RPN:
  GRD-005 (336) - approval_rate always 1.0
  IMM-006 (280) - hash chain wrong prev_hash
  IMM-004 (270) - signature not verified
  GRD-006 (225) - veto_count always 0
  IMM-008 (210) - merkle root drops odd
```

---

## 3. IEC 61508 SIL-3 Compliance Gap Matrix

### 3.1 Compliance Summary

| Category | Compliant | Partial | Non-Compliant | Score |
|----------|-----------|---------|---------------|-------|
| Design Rigor | 14 | 1 | 0 | 93% |
| Implementation | 14 | 1 | 0 | 93% |
| Validation | 8 | 2 | 0 | 80% |
| Redundancy | 5 | 3 | 4 | **42%** |
| V&V Independence | 1 | 1 | 1 | **33%** |
| Documentation | 8 | 2 | 1 | 73% |
| **OVERALL** | **38** | **10** | **6** | **70%** |

### 3.2 Critical SIL-3 Requirements

#### 3.2.1 Hardware Fault Tolerance (HFT) - IEC 61508-2 7.4.3.1.2
| Metric | Current | Required | Status |
|--------|---------|----------|--------|
| HFT | 0 | >=1 | **NON-COMPLIANT** |
| Architecture | Single Guardian | 2oo3 Voting | **GAP** |

**Evidence:**
- Guardian is single Elixir process
- No diverse implementation (Rust NIF)
- No hardware voter

**Required Architecture:**
```
              ┌─────────────────┐
              │  HARDWARE VOTER │
              │     (2oo3)      │
              └───────┬─────────┘
           ┌──────────┼──────────┐
           ▼          ▼          ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ Guardian │ │ Guardian │ │ Guardian │
    │ (Elixir) │ │ (Rust)   │ │ (Elixir) │
    │ Primary  │ │ Diverse  │ │ Backup   │
    └──────────┘ └──────────┘ └──────────┘
```

#### 3.2.2 Safe Failure Fraction (SFF) - IEC 61508-2 7.4.3.1.3
| Metric | Current | Required | Status |
|--------|---------|----------|--------|
| SFF | ~75% | >=99% | **NON-COMPLIANT** |

**Gap Analysis:**
- Dangerous undetected failures: 25%
- Safe failures: 60%
- Dangerous detected: 15%

**Required Improvements:**
1. Diagnostic coverage increase (60% -> 99%)
2. Self-test routines on startup
3. Continuous integrity checks

#### 3.2.3 Diagnostic Coverage (DC) - IEC 61508-2 7.4.3.1.4
| Metric | Current | Required | Status |
|--------|---------|----------|--------|
| DC | ~60% | >=99% | **NON-COMPLIANT** |

**Module DC Analysis:**
| Module | DC | Target | Gap |
|--------|-----|--------|-----|
| ImmutableState | 0% | 99% | -99% |
| ConstitutionalChecker | 20% | 99% | -79% |
| Orchestrator | 40% | 99% | -59% |
| SmartMetrics | 60% | 99% | -39% |
| VitalSigns | 80% | 99% | -19% |
| Membrane | 95% | 99% | -4% |

#### 3.2.4 Signature Algorithm - IEC 61508-2 7.4.7.3
| Metric | Current | Required | Status |
|--------|---------|----------|--------|
| Algorithm | HMAC-SHA512 | Ed25519 | **NON-COMPLIANT** |

**Issue:** HMAC is symmetric - cannot prove non-repudiation

```elixir
# CURRENT - HMAC (Symmetric)
defp sign(data) do
  :crypto.mac(:hmac, :sha512, @signing_key, data)
end

# REQUIRED - Ed25519 (Asymmetric)
defp sign(data, private_key) do
  :crypto.sign(:eddsa, :sha512, data, [private_key, :ed25519])
end

defp verify(data, signature, public_key) do
  :crypto.verify(:eddsa, :sha512, data, signature, [public_key, :ed25519])
end
```

#### 3.2.5 Independent V&V - IEC 61508-1 7.9
| Metric | Current | Required | Status |
|--------|---------|----------|--------|
| V&V | Internal only | 3rd party | **NON-COMPLIANT** |

**Required:**
- Engage TUV Rheinland or equivalent
- Separate verification team
- Independent test cases

### 3.3 Detailed Gap Mapping

| IEC 61508 Clause | Requirement | Status | Evidence | Fix |
|------------------|-------------|--------|----------|-----|
| 7.4.2.3 | Watchdog | NON-COMPLIANT | No hardware watchdog | GPIO integration |
| 7.4.3.1.2 | HFT >= 1 | NON-COMPLIANT | Single Guardian | 2oo3 voting |
| 7.4.3.1.3 | SFF >= 99% | PARTIAL | ~75% | Diagnostic routines |
| 7.4.3.1.4 | DC >= 99% | PARTIAL | ~60% | Self-test expansion |
| 7.4.3.2.3 | Diverse redundancy | NON-COMPLIANT | Single impl | Rust NIF |
| 7.4.7.3 | Crypto integrity | NON-COMPLIANT | HMAC | Ed25519 |
| 7.4.9.5 | Proof test interval | NON-COMPLIANT | None | Document procedures |
| 7.9 | Independent V&V | NON-COMPLIANT | Internal | 3rd party |

---

## 4. Data Flow Integrity Analysis

### 4.1 Critical Data Flows

#### Flow 1: Command Execution Path (CRITICAL)

```
┌─────────┐   ┌─────────────┐   ┌───────────────────────┐   ┌──────────┐
│  User   │──▶│ Orchestrator│──▶│ ConstitutionalChecker │──▶│ Guardian │
└─────────┘   └─────────────┘   └───────────────────────┘   └──────────┘
                                          │                       │
                                          ▼                       │
                                 ┌────────────────┐              │
                                 │ [BYPASS BUG!]  │◀─────────────┘
                                 │ Lines 395-400  │
                                 └────────────────┘
                                          │
                                          ▼
                              ┌───────────────────────┐
                              │ ImmutableState.record │
                              │   [NEVER CALLED!]     │
                              └───────────────────────┘
```

**Issues:**
1. Guardian bypass on unknown response (lines 395-400)
2. ImmutableState.record() never called - no audit trail
3. No end-to-end message authentication

#### Flow 2: Health Propagation Path (HIGH)

```
┌──────────┐   ┌────────────────┐   ┌──────────────┐   ┌───────────┐
│ Sentinel │──▶│ SentinelBridge │──▶│ SmartMetrics │──▶│ Dashboard │
└──────────┘   └────────────────┘   └──────────────┘   └───────────┘
                     │
                     ▼
              ┌─────────────┐
              │ 30s DELAY!  │
              │ Too slow    │
              │ for threats │
              └─────────────┘
```

**Issues:**
1. 30-second sync interval too slow
2. No emergency fast-path for critical threats
3. Rescue block masks real errors

### 4.2 Integrity Gaps

| ID | Gap | Location | Severity | Fix |
|----|-----|----------|----------|-----|
| GAP-001 | No E2E authentication | All flows | CRITICAL | Add HMAC chain |
| GAP-002 | Guardian bypass | constitutional_checker.ex:395 | CRITICAL | Block + queue |
| GAP-003 | HMAC vs Ed25519 | immutable_state.ex:243 | HIGH | Asymmetric |
| GAP-004 | Simulated budget | prometheus_verifier.ex:271 | HIGH | Wire real API |

---

## 5. Telemetry Observability Gaps

### 5.1 Coverage by Module

| Module | Events | Coverage | Status |
|--------|--------|----------|--------|
| Membrane | 9 | 95% | EXCELLENT |
| VitalSigns | 7 | 85% | GOOD |
| SentinelBridge | 5 | 70% | MODERATE |
| SmartMetrics | 4 | 60% | NEEDS WORK |
| GuardianIntegration | 3 | 50% | NEEDS WORK |
| CircuitBreaker | 2 | 40% | POOR |
| Orchestrator | 1 | 20% | POOR |
| PrometheusVerifier | 1 | 20% | POOR |
| AiCopilotFounder | 0 | 0% | **CRITICAL** |
| ImmutableState | 0 | 0% | **CRITICAL** |
| ConstitutionalChecker | 0 | 0% | **CRITICAL** |

### 5.2 Required Telemetry Events

#### ImmutableState (Priority: P0)
```elixir
# Must add these 8 events
[:prajna, :immutable_state, :block_created]
[:prajna, :immutable_state, :chain_verified]
[:prajna, :immutable_state, :verification_failed]
[:prajna, :immutable_state, :signature_verified]
[:prajna, :immutable_state, :hash_mismatch]
[:prajna, :immutable_state, :merkle_root_computed]
[:prajna, :immutable_state, :corruption_detected]
[:prajna, :immutable_state, :recovery_attempted]
```

#### ConstitutionalChecker (Priority: P0)
```elixir
# Must add these 5 events
[:prajna, :constitutional, :invariant_checked]
[:prajna, :constitutional, :invariant_violated]
[:prajna, :constitutional, :guardian_bypassed]  # CRITICAL!
[:prajna, :constitutional, :amendment_applied]
[:prajna, :constitutional, :rollback_triggered]
```

#### Orchestrator (Priority: P1)
```elixir
# Must add these 4 events
[:prajna, :orchestrator, :command_armed]
[:prajna, :orchestrator, :command_confirmed]
[:prajna, :orchestrator, :command_expired]
[:prajna, :orchestrator, :audit_logged]
```

---

## 6. Configurability Requirements

### 6.1 Current State: 0% Runtime Configuration

| Module | Hardcoded Constants | Required: Application.get_env |
|--------|---------------------|-------------------------------|
| SentinelBridge | @sync_interval_ms = 30_000 | Yes |
| SmartMetrics | @staleness_threshold_ms = 5_000 | Yes |
| CircuitBreaker | @telemetry_threshold = 100 | Yes |
| CircuitBreaker | @critical_threshold = 200 | Yes |
| CircuitBreaker | @emergency_threshold = 500 | Yes |
| VitalSigns | @check_interval = 5_000 | Yes |
| VitalSigns | @history_size = 60 | Yes |
| Orchestrator | @audit_max_entries = 1_000 | Yes |
| Orchestrator | @command_timeout = 30_000 | Yes |
| ImmutableState | @signing_key = ... | Env/Secrets |
| Membrane | @flow_check_interval = 1_000 | Yes |
| PrometheusVerifier | @max_budget = 0.95 | Yes |

### 6.2 Required Configuration Structure

```elixir
# config/config.exs
config :indrajaal, Indrajaal.Cockpit.Prajna,
  # SentinelBridge
  sentinel_sync_interval_ms: 30_000,
  sentinel_emergency_interval_ms: 100,

  # SmartMetrics
  staleness_threshold_ms: 5_000,

  # CircuitBreaker
  circuit_breaker: [
    telemetry_threshold: 100,
    critical_threshold: 200,
    emergency_threshold: 500,
    hysteresis_margin: 10
  ],

  # VitalSigns
  vital_signs: [
    check_interval: 5_000,
    history_size: 60,
    trend_window: 10
  ],

  # Orchestrator
  orchestrator: [
    audit_max_entries: 1_000,
    command_timeout: 30_000,
    armed_command_ttl: 30_000,
    persist_audit_to_duckdb: true
  ],

  # ImmutableState
  immutable_state: [
    signing_algorithm: :ed25519,
    signing_key_env: "PRAJNA_SIGNING_KEY",
    verify_on_read: true,
    repair_on_corruption: true
  ],

  # Membrane
  membrane: [
    flow_check_interval: 1_000,
    pressure_threshold: 0.8
  ],

  # PrometheusVerifier
  prometheus: [
    max_budget_ratio: 0.95,
    api_rate_source: :real  # vs :simulated
  ]
```

### 6.3 Implementation Pattern

```elixir
defmodule Indrajaal.Cockpit.Prajna.SentinelBridge do
  # BEFORE - Hardcoded
  @sync_interval_ms 30_000

  # AFTER - Configurable
  defp sync_interval_ms do
    Application.get_env(:indrajaal, __MODULE__, [])
    |> Keyword.get(:sync_interval_ms, 30_000)
  end

  defp emergency_interval_ms do
    Application.get_env(:indrajaal, __MODULE__, [])
    |> Keyword.get(:emergency_interval_ms, 100)
  end
end
```

---

## 7. Robustness Action Plan

### 7.1 P0 - Critical (Blocks SIL-3 Certification)

| ID | Issue | RPN | Fix | Effort | Owner |
|----|-------|-----|-----|--------|-------|
| P0-1 | ImmutableState.record() never called | 280 | Wire to Orchestrator.execute/confirm | 2d | Backend |
| P0-2 | Guardian HFT=0 | 336 | Add 2oo3 voting (Elixir + Rust) | 5d | Safety |
| P0-3 | Guardian bypass (lines 395-400) | 270 | Block + queue pattern | 1d | Backend |
| P0-4 | HMAC instead of Ed25519 | 270 | Replace signing module | 2d | Security |
| P0-5 | Hash chain wrong prev_hash | 280 | Fix to use block_hash | 0.5d | Backend |
| P0-6 | Budget check simulated | 225 | Wire to real API headers | 1d | Backend |
| P0-7 | Zero runtime configuration | N/A | Add Application.get_env | 3d | Backend |

**P0 Total: ~14.5 days**

### 7.2 P1 - High (Required for SIL-3 Operations)

| ID | Issue | RPN | Fix | Effort | Owner |
|----|-------|-----|-----|--------|-------|
| P1-1 | SentinelBridge 30s sync | 200 | Add emergency 100ms path | 1d | Backend |
| P1-2 | Armed commands no TTL | 175 | Add 30s TTL + cleanup | 1d | Backend |
| P1-3 | SmartMetrics silent fail | 168 | Add telemetry + backoff | 1d | Backend |
| P1-4 | Audit log in-memory | 160 | Persist to DuckDB | 2d | Backend |
| P1-5 | GenServer default timeout | 150 | Add explicit 5000ms | 1d | Backend |
| P1-6 | ETS :public access | 140 | Switch to :protected | 1d | Backend |
| P1-7 | CircuitBreaker no telemetry | 135 | Add state events | 0.5d | Backend |
| P1-8 | Rescue masks errors | 130 | Pattern match + handle | 2d | Backend |
| P1-9 | Merkle :discard drops odds | 210 | Use :repeat | 0.5d | Backend |
| P1-10 | :one_for_one strategy | 120 | Use :rest_for_one | 1d | Backend |

**P1 Total: ~12 days**

### 7.3 P2 - Medium (Operational Excellence)

| ID | Issue | Fix | Effort | Owner |
|----|-------|-----|--------|-------|
| P2-1 | Placeholder metrics | Wire to real telemetry | 2d | Backend |
| P2-2 | No self-test routines | Add startup diagnostics | 3d | Safety |
| P2-3 | No proof test docs | Create IEC 61508 procedures | 2d | QA |
| P2-4 | No hardware watchdog | Add GPIO integration hooks | 2d | Platform |
| P2-5 | ImmutableState 0 telemetry | Add 8+ event types | 1d | Backend |
| P2-6 | No independent V&V | Prepare for 3rd party audit | 5d | QA |
| P2-7 | No diverse redundancy docs | Create Simplex spec | 2d | Arch |

**P2 Total: ~17 days**

### 7.4 Total Remediation Effort

| Priority | Items | Days | Team |
|----------|-------|------|------|
| P0 | 7 | 14.5 | Backend + Safety |
| P1 | 10 | 12 | Backend |
| P2 | 7 | 17 | Mixed |
| **Total** | **24** | **43.5** | **All** |

---

## 8. SIL-3 Certification Path

### 8.1 Current vs Target State

```
Metric          Current         Target (SIL-3)     Gap
────────────────────────────────────────────────────────
HFT             0               >= 1               CRITICAL
SFF             ~75%            >= 99%             -24%
DC              ~60%            >= 99%             -39%
Crypto          HMAC            Ed25519+RS         Major
Guardian        Single          Diverse 2oo3       CRITICAL
Watchdog        None            Hardware GPIO      Major
V&V             Internal        3rd Party          CRITICAL
Compliance      70%             >= 95%             -25%
```

### 8.2 Implementation Phases

| Phase | Weeks | Focus | Deliverables |
|-------|-------|-------|--------------|
| 1 | 1-2 | P0 Fixes | ImmutableState wiring, bypass fix, Ed25519 |
| 2 | 3-4 | Diverse Guardian | 2oo3 voting with Rust NIF |
| 3 | 5-6 | P1 Fixes | Timeouts, telemetry, supervision |
| 4 | 7-8 | V&V Preparation | Proof test docs, audit readiness |
| 5 | 9-10 | Hardware Integration | Watchdog, E-Stop GPIO |

### 8.3 Certification Timeline

```
Week 1-2:   P0 Critical Fixes      ████████░░░░░░░░░░░░░░░░░░░░░░░░
Week 3-4:   Diverse Guardian       ░░░░░░░░████████░░░░░░░░░░░░░░░░
Week 5-6:   P1 High Fixes          ░░░░░░░░░░░░░░░░████████░░░░░░░░
Week 7-8:   V&V Preparation        ░░░░░░░░░░░░░░░░░░░░░░░░████████
Week 9-10:  Hardware Integration   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░████
Week 11-12: Safety Case            ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██
```

---

## 9. STAMP Constraints (New)

### 9.1 SC-PRAJNA (Prajna Safety Constraints)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-PRAJNA-001 | All commands through Guardian pre-approval | CRITICAL |
| SC-PRAJNA-002 | Founder's Directive validation mandatory | CRITICAL |
| SC-PRAJNA-003 | State changes via ImmutableState.record() | CRITICAL |
| SC-PRAJNA-004 | Sentinel health integration required | HIGH |
| SC-PRAJNA-005 | PROMETHEUS proof-token for mutations | HIGH |
| SC-PRAJNA-006 | Constitutional invariants checked | CRITICAL |
| SC-PRAJNA-007 | Two-step commit for destructive actions | HIGH |
| SC-PRAJNA-008 | Diverse Guardian (2oo3) for SIL-3 | CRITICAL |
| SC-PRAJNA-009 | Ed25519 signatures mandatory | HIGH |
| SC-PRAJNA-010 | Runtime configuration mandatory | MEDIUM |

### 9.2 AOR-PRAJNA (Prajna Agent Operating Rules)

| ID | Rule |
|----|------|
| AOR-PRAJNA-001 | Guardian gate - commands MUST pass validation |
| AOR-PRAJNA-002 | Founder alignment - AI recommendations MUST align |
| AOR-PRAJNA-003 | State logging - mutations MUST log to register |
| AOR-PRAJNA-004 | Sentinel sync - SmartMetrics sync every 30s |
| AOR-PRAJNA-005 | Two-step commit - destructive actions require |
| AOR-PRAJNA-006 | Never bypass Guardian on error |
| AOR-PRAJNA-007 | Wire ImmutableState.record() to all mutations |
| AOR-PRAJNA-008 | Use Application.get_env for all thresholds |

---

## 10. Related Documents

| Document | Purpose |
|----------|---------|
| journal/2026-01/20260101-1700-prajna-5order-fmea-sil3-deep-analysis.md | Journal entry |
| docs/plans/20260101-prajna-biomorphic-integration-plan.md | Sprint plan |
| docs/architecture/PRAJNA_5_LEVEL_SPECIFICATION.md | Architecture spec |
| docs/safety/NIF_SAFETY_FRAMEWORK.md | NIF safety controls |
| IEC 61508:2010 Parts 1-7 | SIL-3 requirements |

---

## 11. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-01 | Claude Opus 4.5 | Initial FMEA & SIL-3 analysis |

---

## 12. Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Safety Engineer | | | |
| System Architect | | | |
| Quality Lead | | | |
