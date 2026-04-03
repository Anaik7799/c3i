# Plan: Immune System Completion (Mara & Antibody)

**Created**: 20260101-1230 CEST
**Status**: PARTIALLY COMPLETE (Sprint 51: Mara auto-block + Guardian Antibody integration implemented)
**Framework**: SOPv5.11 + STAMP (SC-IMMUNE) + OODA
**Author**: Gemini (Cybernetic Architect)

## Executive Summary
This plan details the implementation of the "Active Immune Response" layer of the Indrajaal system. While **Sentinel** (T-Cell) performs monitoring and identification, **Mara** (Simulation/Chaos) proactively tests resilience, and **Antibody** (Effector) neutralizes specific threats. This completes the biological metaphor of the system's defense mechanism.

## 5-Level Detailed Plan

### 30.7 - Mara Immune Module (Chaos & Resilience) (Priority: P1)
**Objective**: Proactively test system resilience via controlled chaos injection (Red Teaming).
**STAMP**: SC-IMMUNE-004 (Chaos Injection Safety), SC-TEST-002 (Resilience Verification)

#### 30.7.1 - Mara Core Implementation
**Goal**: Create the `Indrajaal.Safety.Mara` GenServer.
##### 30.7.1.1 - Scaffolding & State
- 30.7.1.1.1 - Define `Indrajaal.Safety.Mara` module structure.
- 30.7.1.1.2 - Implement `start_link` and `init`.
- 30.7.1.1.3 - Define state: `active_scenarios`, `history`, `config`.

##### 30.7.1.2 - Chaos Scenarios
- 30.7.1.2.1 - Implement `:process_kill` scenario (random worker termination).
- 30.7.1.2.2 - Implement `:latency_injection` scenario (sleep injection).
- 30.7.1.2.3 - Implement `:resource_stress` scenario (memory/cpu pressure).

#### 30.7.2 - Sentinel Integration
**Goal**: Ensure Mara coordinates with Sentinel (to avoid false positives or cascading failures).
##### 30.7.2.1 - Safety Handshake
- 30.7.2.1.1 - Implement `request_permission/1` call to Guardian/Sentinel.
- 30.7.2.1.2 - Ensure `SC-IMMUNE-004` (No chaos during critical load).

##### 30.7.2.2 - Recovery Validation
- 30.7.2.2.1 - Implement `monitor_recovery/2` to verify system self-healing.
- 30.7.2.2.2 - Log success/failure to Zenoh (Training data).

### 30.8 - Antibody Module (Threat Neutralization) (Priority: P1)
**Objective**: Targeted neutralization of specific threats identified by Sentinel.
**STAMP**: SC-IMMUNE-005 (Targeted Response), SC-ACT-001 (Actuator Limits)

#### 30.8.1 - Antibody Lifecycle Manager
**Goal**: Implement `Indrajaal.Safety.Antibody` module.
##### 30.8.1.1 - Lifecycle Phases
- 30.8.1.1.1 - **Search**: Poll Sentinel for `active_threats`.
- 30.8.1.1.2 - **Bind**: Attach to specific threat signature (e.g., specific PID or IP).
- 30.8.1.1.3 - **Opsonize**: Tag threat for cleanup (mark in Registry/ETS).
- 30.8.1.1.4 - **Die**: Terminate Antibody process after task completion (Ephemeral).

#### 30.8.2 - Neutralization Strategies
**Goal**: specific logic for different threat types.
##### 30.8.2.1 - Process Neutralization
- 30.8.2.1.1 - Implement `suspend_process/1` (Soft kill).
- 30.8.2.1.2 - Implement `kill_process/1` (Hard kill).

##### 30.8.2.2 - Traffic Neutralization
- 30.8.2.2.1 - Implement `block_ip/1` (via Phoenix/Plug).
- 30.8.2.2.2 - Implement `rate_limit_user/1`.

## Success Criteria
1.  **Mara**: Can execute a `:process_kill` simulation, verify the supervisor restarted the process, and log the "Resilience Score". [Updated Sprint 51: Mara auto-block with Guardian integration implemented in `lib/indrajaal/cockpit/prajna/immune/mara.ex`]
2.  **Antibody**: Can accept a Threat ID from Sentinel, locate the source, and execute a `suspend` action without crashing the node. [Updated Sprint 51: Antibody lifecycle (search/bind/opsonize/die) implemented in `lib/indrajaal/cockpit/prajna/immune/antibody.ex` with AntibodySupervisor]
3.  **Safety**: Guardian blocks Mara if system load > 80%. [Updated Sprint 51: Guardian approval token required for Antibody "Bind" phase]

## Risk Assessment
- **Risk**: Mara kills critical kernel process.
    - **Mitigation**: Sentinel `is_kernel_process?` check reused in Mara.
- **Risk**: Antibody "auto-immune" reaction (attacking healthy components).
    - **Mitigation**: Require Guardian approval token for Antibody "Bind" phase. [Updated Sprint 51: Guardian approval gate implemented and enforced]
