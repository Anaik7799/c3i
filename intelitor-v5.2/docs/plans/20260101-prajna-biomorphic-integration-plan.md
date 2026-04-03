# Plan: Prajna Biomorphic Integration & Grand Unification

**Created**: 20260101-1200 CEST
**Last Updated**: 20260101-1700 CEST
**Status**: IN PROGRESS
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA) + STAMP + OODA
**SIL Target**: IEC 61508 SIL-3
**Current Compliance**: 70%

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260101-1200 CEST | CREATED | Initial 5-level breakdown for P0/P1 tasks | Gemini (Cybernetic Architect) |
| 20260101-1700 CEST | MAJOR UPDATE | Added FMEA findings, SIL-3 gaps, P0/P1/P2 robustness actions | Claude Opus 4.5 |

## Executive Summary
This plan details the "Grand Unification" of the Indrajaal system, specifically focusing on the biomorphic integration of the Prajna Cockpit, the Safety Guardian, the Knowledge Engine (IKE), and the underlying F# Plasma Engine (CEPAF#). The goal is to achieve a self-regulating, safety-critical, and intelligent system that adheres to the Founder's Covenant.

**2026-01-01 Update**: Deep 5-order impact analysis revealed 88 FMEA failure modes, 70% SIL-3 compliance, and critical gaps requiring immediate remediation. This plan now includes P0/P1/P2 robustness actions.

## FMEA Summary (88 Failure Modes)

| Priority | Count | Top RPN Items |
|----------|-------|---------------|
| Critical (>=150) | 16 | GRD-005 (336), IMM-006 (280), IMM-004 (270) |
| High (100-149) | 24 | SEN-001 (140), MET-002 (140), CIR-001 (135) |
| Medium (50-99) | 31 | Various configuration and telemetry gaps |
| Low (<50) | 17 | Minor improvements |

## SIL-3 Gap Summary

| Category | Current | Target | Gap |
|----------|---------|--------|-----|
| HFT | 0 | >=1 | **CRITICAL** |
| SFF | ~75% | >=99% | -24% |
| DC | ~60% | >=99% | -39% |
| Redundancy | 42% | 99% | **-57%** |
| V&V Independence | 33% | 95% | **-62%** |
| **Overall** | **70%** | **95%** | **-25%** |

---

## 5-Level Detailed Plan

### 30.0 - Prajna Biomorphic Integration (Priority: P0)
**Objective**: Fully integrate Prajna Cockpit with Safety Guardian, Knowledge Engine, and Founder's Directive.

#### 30.1 - Guardian-Cockpit Bridge (Priority: P0)
**Goal**: Ensure all Cockpit actions are vetted by the Guardian.
##### 30.1.1 - Safety Interface Implementation (Priority: P0)
###### 30.1.1.1 - Implement GuardianIntegration Module (Priority: P0)
- 30.1.1.1.1 - Define `submit_proposal/1` contract [DONE]
- 30.1.1.1.2 - Implement Telemetry emission for safety checks [DONE]
- 30.1.1.1.3 - Wire to `Indrajaal.Safety.Guardian` (Simplex Architecture) [PENDING]
###### 30.1.1.2 - Wire Orchestrator to Guardian (Priority: P0)
- 30.1.1.2.1 - Update `Prajna.Orchestrator` to call `GuardianIntegration.submit_proposal/1` before execution [PENDING]
- 30.1.1.2.2 - Handle `{:veto, reason, fallback}` responses gracefully [PENDING]

#### 30.2 - Founder's Directive Enforcement (Priority: P0)
**Goal**: Embed the Founder's Covenant into the AI decision loop.
##### 30.2.1 - Directive Logic Implementation (Priority: P0)
###### 30.2.1.1 - Implement AiCopilotFounder Module (Priority: P0)
- 30.2.1.1.1 - Implement Goal 1: Symbiotic Survival check [DONE]
- 30.2.1.1.2 - Implement Goal 2: Sentience Pursuit check [DONE]
- 30.2.1.1.3 - Implement Goal 3: Power Accumulation check [DONE]
###### 30.2.1.2 - Wire AI Copilot to Founder Directive (Priority: P0)
- 30.2.1.2.1 - Update `Prajna.AiCopilot` to filter suggestions via `AiCopilotFounder.validate_recommendation/1` [PENDING]

#### 30.3 - Immutable State Register (Priority: P0 - UPGRADED)
**Goal**: Create a tamper-proof log of all high-level system mutations.
**FMEA Finding**: ImmutableState.record() is NEVER CALLED (RPN=280)
##### 30.3.1 - Register Implementation (Priority: P0)
###### 30.3.1.1 - Implement ImmutableState Module (Priority: P0)
- 30.3.1.1.1 - Define Block structure (hash, prev_hash, signature) [DONE]
- 30.3.1.1.2 - Integrate with `DuckDBStore` for persistence [DONE]
- 30.3.1.1.3 - Implement cryptographic hashing (SHA256/Ed25519) [DONE]
###### 30.3.1.2 - Wire ImmutableState to Mutations (Priority: P0) **[NEW]**
- 30.3.1.2.1 - Call `ImmutableState.record/1` in `Orchestrator.execute_command/2` [PENDING]
- 30.3.1.2.2 - Call `ImmutableState.record/1` in `Orchestrator.confirm_command/2` [PENDING]
- 30.3.1.2.3 - Add telemetry events for block creation [PENDING]
###### 30.3.1.3 - Fix Hash Chain (RPN=280) (Priority: P0) **[NEW]**
- 30.3.1.3.1 - Fix prev_hash to use `block_hash` not `content_hash` [PENDING]
- 30.3.1.3.2 - Add chain verification on startup [PENDING]
###### 30.3.1.4 - Replace HMAC with Ed25519 (RPN=270) (Priority: P0) **[NEW]**
- 30.3.1.4.1 - Implement `:crypto.sign(:eddsa, ...)` signing [PENDING]
- 30.3.1.4.2 - Implement `:crypto.verify(:eddsa, ...)` verification [PENDING]
- 30.3.1.4.3 - Add signature verification in `verify_chain/1` [PENDING]

#### 30.4 - Biomorphic Dashboard & Fractal Observability (Priority: P1)
**Goal**: Visualize the system as a living organism.
##### 30.4.1 - Dashboard Metrics Pipeline (Priority: P1)
###### 30.4.1.1 - Agent Metabolism Tracking (Priority: P1)
- 30.4.1.1.1 - Capture Agent CPU/Memory/Context usage [PENDING]
- 30.4.1.1.2 - Aggregate into "Metabolic Rate" metric [PENDING]
###### 30.4.1.2 - Fractal UI Implementation (Priority: P1)
- 30.4.1.2.1 - Update Console Dashboard to show Global/Cluster/Local views [PENDING]
- 30.4.1.2.2 - Implement "Thinking" state visualization for Agents [PENDING]

---

### 32.0 - P0 FMEA Critical Fixes (Priority: P0) **[NEW SECTION]**
**Objective**: Remediate all Critical FMEA items (RPN >= 150) blocking SIL-3.
**Total Effort**: 14.5 days

#### 32.1 - Guardian Bypass Fix (RPN=270) (Priority: P0)
**Goal**: Prevent actions when Guardian unavailable.
**Location**: constitutional_checker.ex:395-400
##### 32.1.1 - Block on Unknown Response (Priority: P0)
###### 32.1.1.1 - Remove Bypass Logic (Priority: P0)
- 32.1.1.1.1 - Replace `{:ok, :approved}` fallback with `{:error, :guardian_unavailable}` [PENDING]
- 32.1.1.1.2 - Add queuing for retry when Guardian becomes available [PENDING]
- 32.1.1.1.3 - Add telemetry event `[:prajna, :constitutional, :guardian_bypassed]` [PENDING]

#### 32.2 - Placeholder Metrics Fix (RPN=336, 225) (Priority: P0)
**Goal**: Wire placeholder metrics to real telemetry.
##### 32.2.1 - GuardianIntegration Metrics (Priority: P0)
###### 32.2.1.1 - Fix calculate_approval_rate/0 (RPN=336) (Priority: P0)
- 32.2.1.1.1 - Query PrometheusVerifier for real approval/rejection counts [PENDING]
- 32.2.1.1.2 - Calculate actual rate from telemetry aggregates [PENDING]
###### 32.2.1.2 - Fix get_veto_count/0 (RPN=225) (Priority: P0)
- 32.2.1.2.1 - Query Guardian for real veto statistics [PENDING]
- 32.2.1.2.2 - Add caching with 5s TTL for performance [PENDING]

#### 32.3 - PrometheusVerifier Budget Fix (RPN=180) (Priority: P0)
**Goal**: Wire API budget check to real rate limit headers.
**Location**: prometheus_verifier.ex:271-275
##### 32.3.1 - Real API Integration (Priority: P0)
###### 32.3.1.1 - Remove Simulated Budget (Priority: P0)
- 32.3.1.1.1 - Replace `simulate_api_usage/0` with real X-RateLimit header parsing [PENDING]
- 32.3.1.1.2 - Store rate limit state in GenServer [PENDING]
- 32.3.1.1.3 - Add fallback to conservative estimate on missing headers [PENDING]

#### 32.4 - Runtime Configuration (Priority: P0)
**Goal**: Replace hardcoded values with Application.get_env.
**Current**: 0% runtime config | **Target**: 100%
##### 32.4.1 - SentinelBridge Config (Priority: P0)
- 32.4.1.1 - Replace @sync_interval_ms with Application.get_env [PENDING]
- 32.4.1.2 - Add emergency_interval_ms config option [PENDING]
##### 32.4.2 - CircuitBreaker Config (Priority: P0)
- 32.4.2.1 - Replace @telemetry_threshold with Application.get_env [PENDING]
- 32.4.2.2 - Replace @critical_threshold with Application.get_env [PENDING]
- 32.4.2.3 - Replace @emergency_threshold with Application.get_env [PENDING]
##### 32.4.3 - Orchestrator Config (Priority: P0)
- 32.4.3.1 - Replace @audit_max_entries with Application.get_env [PENDING]
- 32.4.3.2 - Replace @command_timeout with Application.get_env [PENDING]
- 32.4.3.3 - Add @armed_command_ttl config [PENDING]
##### 32.4.4 - ImmutableState Config (Priority: P0)
- 32.4.4.1 - Move @signing_key to environment variable [PENDING]
- 32.4.4.2 - Add signing_algorithm config (Ed25519) [PENDING]

---

### 33.0 - P1 FMEA High Fixes (Priority: P1) **[NEW SECTION]**
**Objective**: Remediate High FMEA items (RPN 100-149) for operational safety.
**Total Effort**: 12 days

#### 33.1 - SentinelBridge Fast Path (RPN=200) (Priority: P1)
**Goal**: Add emergency sync path for rapid threats.
##### 33.1.1 - Emergency Interval (Priority: P1)
- 33.1.1.1 - Add emergency_sync/0 function with 100ms interval [PENDING]
- 33.1.1.2 - Trigger on threat severity >= :critical [PENDING]
- 33.1.1.3 - Return to normal interval after threat resolved [PENDING]

#### 33.2 - Armed Command TTL (RPN=175) (Priority: P1)
**Goal**: Prevent immortal armed commands.
**Location**: orchestrator.ex
##### 33.2.1 - TTL Implementation (Priority: P1)
- 33.2.1.1 - Add @armed_command_ttl = 30_000 (configurable) [PENDING]
- 33.2.1.2 - Add cleanup GenServer tick every 5s [PENDING]
- 33.2.1.3 - Emit telemetry on command expiration [PENDING]

#### 33.3 - Audit Log Persistence (RPN=160) (Priority: P1)
**Goal**: Persist audit log to DuckDB.
##### 33.3.1 - DuckDB Integration (Priority: P1)
- 33.3.1.1 - Create audit_log DuckDB table [PENDING]
- 33.3.1.2 - Wire log_audit/1 to DuckDBStore.insert [PENDING]
- 33.3.1.3 - Add retention policy (30 days) [PENDING]

#### 33.4 - GenServer Timeouts (RPN=150) (Priority: P1)
**Goal**: Add explicit timeouts to all GenServer.call.
##### 33.4.1 - Timeout Audit (Priority: P1)
- 33.4.1.1 - Audit all GenServer.call sites [PENDING]
- 33.4.1.2 - Add explicit 5000ms timeout parameter [PENDING]
- 33.4.1.3 - Add :timeout handling in callers [PENDING]

#### 33.5 - ETS Access Control (RPN=140) (Priority: P1)
**Goal**: Switch ETS tables from :public to :protected.
##### 33.5.1 - SmartMetrics ETS (Priority: P1)
- 33.5.1.1 - Change to :protected access [PENDING]
- 33.5.1.2 - Add accessor functions [PENDING]
##### 33.5.2 - VitalSigns ETS (Priority: P1)
- 33.5.2.1 - Change to :protected access [PENDING]
- 33.5.2.2 - Add accessor functions [PENDING]

#### 33.6 - Merkle Root Fix (RPN=210) (Priority: P1)
**Goal**: Fix odd element handling in Merkle tree.
**Location**: immutable_state.ex
##### 33.6.1 - Element Handling (Priority: P1)
- 33.6.1.1 - Replace :discard with :repeat for odd elements [PENDING]
- 33.6.1.2 - Add test for odd-length block chains [PENDING]

#### 33.7 - Supervision Strategy (RPN=120) (Priority: P1)
**Goal**: Switch to :rest_for_one for critical path.
##### 33.7.1 - Supervisor Update (Priority: P1)
- 33.7.1.1 - Analyze child dependency graph [PENDING]
- 33.7.1.2 - Reorder children for :rest_for_one [PENDING]
- 33.7.1.3 - Update supervisor strategy [PENDING]

#### 33.8 - Telemetry Coverage (Priority: P1)
**Goal**: Add telemetry to modules with 0% coverage.
##### 33.8.1 - ImmutableState Telemetry (Priority: P1)
- 33.8.1.1 - Add 8 telemetry event types [PENDING]
- 33.8.1.2 - Add handlers for alerting [PENDING]
##### 33.8.2 - ConstitutionalChecker Telemetry (Priority: P1)
- 33.8.2.1 - Add 5 telemetry event types [PENDING]
- 33.8.2.2 - Add guardian_bypassed alert handler [PENDING]
##### 33.8.3 - CircuitBreaker Telemetry (Priority: P1)
- 33.8.3.1 - Add state transition events [PENDING]
- 33.8.3.2 - Add threshold breach events [PENDING]

---

### 34.0 - P2 Operational Excellence (Priority: P2) **[NEW SECTION]**
**Objective**: Achieve operational excellence for SIL-3 certification.
**Total Effort**: 17 days

#### 34.1 - Self-Test Routines (Priority: P2)
**Goal**: Add startup and periodic diagnostics per IEC 61508.
##### 34.1.1 - Startup Diagnostics (Priority: P2)
- 34.1.1.1 - Verify hash chain integrity on start [PENDING]
- 34.1.1.2 - Verify Guardian availability on start [PENDING]
- 34.1.1.3 - Verify Sentinel connectivity on start [PENDING]
##### 34.1.2 - Periodic Diagnostics (Priority: P2)
- 34.1.2.1 - Add hourly integrity check [PENDING]
- 34.1.2.2 - Add daily proof test run [PENDING]

#### 34.2 - Proof Test Documentation (Priority: P2)
**Goal**: Create IEC 61508 proof test procedures.
##### 34.2.1 - Documentation (Priority: P2)
- 34.2.1.1 - Document Guardian proof test [PENDING]
- 34.2.1.2 - Document ImmutableState proof test [PENDING]
- 34.2.1.3 - Document Sentinel proof test [PENDING]

#### 34.3 - Hardware Watchdog Hooks (Priority: P2)
**Goal**: Prepare for hardware watchdog integration.
##### 34.3.1 - GPIO Integration (Priority: P2)
- 34.3.1.1 - Define watchdog kick interface [PENDING]
- 34.3.1.2 - Add E-Stop GPIO hooks [PENDING]
- 34.3.1.3 - Document hardware requirements [PENDING]

#### 34.4 - Independent V&V Preparation (Priority: P2)
**Goal**: Prepare for third-party safety assessment.
##### 34.4.1 - Audit Readiness (Priority: P2)
- 34.4.1.1 - Compile safety case document [PENDING]
- 34.4.1.2 - Prepare traceability matrix [PENDING]
- 34.4.1.3 - Document test coverage [PENDING]

---

### 35.0 - SIL-3 Certification Path (Priority: P0-P2) **[NEW SECTION]**
**Objective**: Achieve IEC 61508 SIL-3 certification.
**Current**: 70% | **Target**: 95%

#### 35.1 - Diverse Guardian (HFT>=1) (Priority: P0)
**Goal**: Implement 2oo3 voting with diverse Guardian.
**Effort**: 5 days
##### 35.1.1 - Rust NIF Guardian (Priority: P0)
- 35.1.1.1 - Implement Guardian logic in Rust [PENDING]
- 35.1.1.2 - Create Rustler NIF binding [PENDING]
- 35.1.1.3 - Implement diversity verification [PENDING]
##### 35.1.2 - 2oo3 Voter (Priority: P0)
- 35.1.2.1 - Implement voting logic [PENDING]
- 35.1.2.2 - Add disagreement handling [PENDING]
- 35.1.2.3 - Add telemetry for voting results [PENDING]

#### 35.2 - Diagnostic Coverage (DC>=99%) (Priority: P1)
**Goal**: Increase diagnostic coverage from 60% to 99%.
##### 35.2.1 - Module Coverage (Priority: P1)
- 35.2.1.1 - Add diagnostics to ImmutableState (0%->99%) [PENDING]
- 35.2.1.2 - Add diagnostics to ConstitutionalChecker (20%->99%) [PENDING]
- 35.2.1.3 - Add diagnostics to Orchestrator (40%->99%) [PENDING]

---

### 31.0 - Knowledge Engine (IKE) Synchronization (Priority: P1)
**Objective**: Ensure Elixir (Runtime) and F# (Ingestion) share a single source of truth.

#### 31.1 - Cross-Language Bridge (Priority: P1)
##### 31.1.1 - Shared Storage Access (Priority: P1)
###### 31.1.1.1 - DuckDB Schema Alignment (Priority: P1)
- 31.1.1.1.1 - Verify F# Plasma schemas match Elixir Ecto schemas [PENDING]
- 31.1.1.1.2 - Create migration consistency check script [PENDING]

---

## Success Criteria

1. **Safety**: 100% of Prajna commands pass through Guardian (verified by test `test/indrajaal/cockpit/prajna/guardian_integration_test.exs`).
2. **Compliance**: 100% of AI suggestions vetted by Founder's Directive (verified by `test/indrajaal/cockpit/prajna/ai_copilot_founder_test.exs`).
3. **Observability**: Dashboard updates every 30s with correct "Metabolic Rate".
4. **Integrity**: Immutable Register successfully chains 100+ blocks in DuckDB.
5. **FMEA**: 0 Critical items (RPN >= 150) remaining. **[NEW]**
6. **SIL-3**: >=95% IEC 61508 compliance. **[NEW]**
7. **Telemetry**: 95% coverage across all modules. **[NEW]**
8. **Configuration**: 100% runtime configurable. **[NEW]**

---

## Risk Assessment (5-Level RCA)

### Original Risks
- **Risk**: Guardian latency too high for real-time UI.
    - **Mitigation**: Implement caching for frequent safe operations (Fast Path).
- **Risk**: F#/Elixir DuckDB lock contention.
    - **Mitigation**: Use `WAL` mode and separate read/write connections where possible.

### New FMEA Risks (2026-01-01)
- **Risk**: ImmutableState.record() never called (RPN=280)
    - **RCA Level 1**: Wire missing in Orchestrator
    - **RCA Level 2**: Initial implementation incomplete
    - **RCA Level 3**: No integration test enforcing
    - **RCA Level 4**: Test coverage gap
    - **RCA Level 5**: Process gap - no wiring checklist
    - **Mitigation**: P0-1 - Wire to Orchestrator mutations

- **Risk**: Guardian bypass on unknown response (RPN=270)
    - **RCA Level 1**: Fallback returns :approved
    - **RCA Level 2**: Defensive coding for availability
    - **RCA Level 3**: Wrong fail-safe default
    - **RCA Level 4**: Safety review gap
    - **RCA Level 5**: Process gap - no FMEA during design
    - **Mitigation**: P0-3 - Block + queue pattern

- **Risk**: Single Guardian (HFT=0)
    - **RCA Level 1**: No redundancy
    - **RCA Level 2**: SIL-2 design, not SIL-3
    - **RCA Level 3**: Certification target unclear
    - **RCA Level 4**: Architecture gap
    - **RCA Level 5**: Requirements gap
    - **Mitigation**: P0-2 - Diverse Guardian with 2oo3 voting

---

## Priority Summary

| Priority | Items | Effort | Focus |
|----------|-------|--------|-------|
| P0 | 32 | 14.5d | SIL-3 blockers |
| P1 | 28 | 12d | Operational safety |
| P2 | 15 | 17d | Excellence |
| **Total** | **75** | **43.5d** | **Full remediation** |

---

## Related Documents

- docs/architecture/PRAJNA_FMEA_SIL3_ROBUSTNESS.md
- journal/2026-01/20260101-1700-prajna-5order-fmea-sil3-deep-analysis.md
- docs/safety/NIF_SAFETY_FRAMEWORK.md
- IEC 61508:2010 Parts 1-7
