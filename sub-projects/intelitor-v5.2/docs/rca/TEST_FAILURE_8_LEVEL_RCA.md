# 8-Level Fractal RCA: Test Suite Failures
**Date**: 2026-01-11 | **Version**: 21.3.0-SIL6 | **Status**: ACTIVE

## Executive Summary

Test suite experiencing 10 failures with excessive log noise from background services.
Root cause: **Observability systems not adapting to test execution context**.

---

## L0: RUNTIME/CODE LEVEL

### Symptoms
- 346 tests executed, 10 failures, but output dominated by JSON logs
- 57,000+ log lines generated during single test run
- Test output visibility: ~1% (test dots buried in JSON)

### Root Cause
```
RC-L0-001: Static log level configuration
  - config/test.exs sets :info level globally
  - Watchdog, Zenoh services log at :info regardless of test context
  - No awareness of "test mode" execution context

RC-L0-002: No log filtering for non-essential services
  - ZenohSession logs every connection retry
  - Watchdog logs every heartbeat timeout (500ms interval)
  - libcluster logs every DNS lookup failure
```

### Evidence
```elixir
# From test output:
"[Watchdog] Heartbeat timeout for ... (565879ms > 2000ms)"  # Repeated 1000+ times
"[libcluster:k8s_cluster] lookup against indrajaal-headless failed: :nxdomain"  # Every 5s
"[ZenohSession] Connection failed: Unable to connect..."  # Every 1s
```

### Fix: Adaptive Log Level Controller (SC-OBS-DT-001)

---

## L1: FUNCTION LEVEL

### Symptoms
- Heartbeat checks running at 500ms in test mode
- Restart attempts for services that don't need restarting during tests

### Root Cause
```
RC-L1-001: Watchdog parameters not context-aware
  - check_interval: 500ms (same as production)
  - heartbeat_timeout: 2000ms (too aggressive for test)
  - restart_on_failure: true (unnecessary in test)

RC-L1-002: Function contracts not adapted for test execution
  - check_process/4 always escalates failures
  - attempt_restart/2 always tries to restart
  - No bypass for test context
```

### Evidence
```elixir
# lib/indrajaal/cockpit/prajna/watchdog.ex:442
"[Watchdog] Heartbeat timeout for Elixir.Indrajaal.Cockpit.Prajna.Orchestrator"
# This is logged every 500ms during test execution
```

### Fix: Context-Aware Watchdog Parameters (SC-OBS-DT-002)

---

## L2: COMPONENT/MODULE LEVEL

### Symptoms
- ZenohSession attempting connection to unavailable router
- ZenohTelemetrySubscriber retrying subscriptions indefinitely
- AccessControlIntegration crashing on missing key

### Root Cause
```
RC-L2-001: No graceful degradation for missing infrastructure
  - ZenohSession.handle_info/2 logs every retry
  - No exponential backoff with silence
  - No "degraded mode" that stops retrying

RC-L2-002: Component contracts assume full infrastructure
  - AccessControlIntegration expects specific key format
  - Snake_case mismatch: :access_violations_24h vs :accessviolations_24h
  - No defensive coding for incomplete data

RC-L2-003: No component-level observability throttling
  - Each component logs independently
  - No coordination between components
  - Cumulative log volume overwhelms test output
```

### Evidence
```elixir
# KeyError in AccessControlIntegration
%{
  accessviolations_24h: 1,  # Wrong: no underscores
  ...
}
# Expected: :access_violations_24h
```

### Fix: Degraded Mode Controller (SC-OBS-DT-003)

---

## L3: HOLON/AGENT LEVEL

### Symptoms
- Multiple GenServers crashing and restarting during tests
- Prajna subsystem unstable in test context
- Guardian escalation triggered unnecessarily

### Root Cause
```
RC-L3-001: Holon state machines not test-aware
  - Prajna services assume full operational context
  - No "test mode" state in FSM
  - Transitions trigger full production behavior

RC-L3-002: Guardian escalation threshold too sensitive
  - 3 consecutive failures triggers escalation
  - In test mode, all Prajna services "fail" continuously
  - Creates escalation storm

RC-L3-003: Agent lifecycle not coordinated
  - Each agent independently monitors health
  - No central "test mode" coordinator
  - Agents compete for resources
```

### Evidence
```elixir
# Watchdog escalation in test:
"[Watchdog] ESCALATING to Guardian - 0 critical failures, 7 total"
# This shouldn't happen in test mode
```

### Fix: Test Mode Coordinator (SC-OBS-DT-004)

---

## L4: CONTAINER/ISOLATION LEVEL

### Symptoms
- ContainerHealthMonitorTest expecting 11 containers
- Tests fail because podman containers not running
- No mock/stub for container infrastructure

### Root Cause
```
RC-L4-001: Tests require full container stack
  - ContainerHealthMonitorTest checks real containers
  - No test doubles for container layer
  - Fails silently when containers unavailable

RC-L4-002: Container isolation boundary unclear
  - Test code reaches across container boundary
  - No abstraction layer for container status
  - Direct podman calls in test code
```

### Evidence
```elixir
# test/indrajaal/containers/container_health_monitor_test.exs
test "discovers all 11 containers in the Indrajaal stack"
# Fails because containers not running
```

### Fix: Container Mock Layer (SC-OBS-DT-005)

---

## L5: NODE/RUNTIME LEVEL

### Symptoms
- libcluster trying k8s DNS lookups on dev machine
- BEAM scheduler contention from background services
- Memory pressure from log accumulation

### Root Cause
```
RC-L5-001: Cluster topology not test-aware
  - libcluster configured for k8s in test
  - DNS lookups fail continuously
  - Error logs every 5 seconds

RC-L5-002: Node configuration not adaptive
  - Same topology strategy in all environments
  - No "single-node" mode for tests
  - Background polling continues
```

### Evidence
```elixir
# libcluster error every 5s:
"[libcluster:k8s_cluster] lookup against indrajaal-headless failed: :nxdomain"
```

### Fix: Environment-Aware Topology (SC-OBS-DT-006)

---

## L6: CLUSTER/MESH LEVEL

### Symptoms
- Zenoh mesh attempting connection to non-existent router
- No mesh-level coordination for test mode
- Cross-node observability flooding local test

### Root Cause
```
RC-L6-001: Zenoh coordinator not test-aware
  - Tries tcp/zenoh-router:7447 which doesn't exist
  - No fallback to "local only" mode
  - Continuous reconnection attempts

RC-L6-002: Mesh observability not dampened
  - Full mesh telemetry attempted
  - No coordination across "cluster" of 1 node
  - Designed for distributed, runs on single
```

### Evidence
```elixir
"[ZenohSession] Connection failed: Unable to connect to any of [tcp/zenoh-router:7447]!"
```

### Fix: Mesh Mode Controller (SC-OBS-DT-007)

---

## L7: FEDERATION/ECOSYSTEM LEVEL

### Symptoms
- No awareness of execution context at ecosystem level
- All holons attempt full production behavior
- No federation-level test coordination

### Root Cause
```
RC-L7-001: No ecosystem-wide test mode signaling
  - Each holon operates independently
  - No "test federation" protocol
  - Full production behavior assumed

RC-L7-002: No adaptive observability at federation level
  - Directed Telescope not context-aware
  - Same instrumentation depth in all contexts
  - No dynamic focus adjustment
```

### Fix: Federation Test Protocol (SC-OBS-DT-008)

---

## L8: CONSTITUTIONAL/INVARIANT LEVEL

### Symptoms
- Safety constraints (SC-*) evaluated same in test as production
- No relaxation of non-critical constraints during test
- Constitutional checks add overhead in test mode

### Root Cause
```
RC-L8-001: Constitutional invariants not context-stratified
  - Ψ₀-Ψ₅ evaluated fully in test
  - No "test mode" relaxation for non-safety invariants
  - Performance overhead in test

RC-L8-002: STAMP constraints not prioritized by context
  - All 600+ constraints active in test
  - No "test-critical" vs "production-only" classification
  - Constraint violations overwhelm test output
```

### Fix: Contextual Constraint Stratification (SC-OBS-DT-009)

---

## Root Cause Tree

```
TEST FAILURES (10)
├── Container Tests Fail (9/10)
│   └── L4: Containers not running in test environment
│       └── RC-L4-001: No container mocks
│
├── BasicTest Fail (1/10)
│   └── L0: ExUnitProperties test issue (minor)
│
└── LOG NOISE (57,000+ lines)
    ├── L0: Static log level (RC-L0-001)
    ├── L1: Aggressive heartbeat (RC-L1-001)
    ├── L2: No graceful degradation (RC-L2-001)
    ├── L3: Guardian escalation (RC-L3-002)
    ├── L5: libcluster k8s lookups (RC-L5-001)
    └── L6: Zenoh reconnection (RC-L6-001)
```

---

## Solution Architecture: Directed Telescope Observability

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DIRECTED TELESCOPE CONTROLLER                     │
│                        (Context-Aware OODA)                          │
├─────────────────────────────────────────────────────────────────────┤
│  OBSERVE: Execution Context Detection                                │
│    ├── MIX_ENV=test detected?                                       │
│    ├── Container stack available?                                    │
│    ├── Zenoh router reachable?                                       │
│    └── K8s DNS available?                                           │
├─────────────────────────────────────────────────────────────────────┤
│  ORIENT: Context Classification                                      │
│    ├── :full_production    → All systems go                          │
│    ├── :staging            → Reduced telemetry                      │
│    ├── :development        → Local focus                            │
│    ├── :integration_test   → Infrastructure available                │
│    └── :unit_test          → Minimal observability                  │
├─────────────────────────────────────────────────────────────────────┤
│  DECIDE: Observability Profile Selection                            │
│    ├── Log Level Adjustment                                         │
│    ├── Heartbeat Interval Scaling                                   │
│    ├── Retry/Reconnect Policy                                       │
│    ├── Telemetry Sampling Rate                                      │
│    └── STAMP Constraint Priority                                    │
├─────────────────────────────────────────────────────────────────────┤
│  ACT: Dynamic Reconfiguration                                        │
│    ├── Apply log filters                                            │
│    ├── Adjust service parameters                                    │
│    ├── Enable/disable subsystems                                    │
│    └── Signal components                                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## STAMP Constraints (New)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-OBS-DT-001 | Directed Telescope MUST detect execution context | CRITICAL |
| SC-OBS-DT-002 | Log level MUST adapt to context | HIGH |
| SC-OBS-DT-003 | Heartbeat interval MUST scale with context | HIGH |
| SC-OBS-DT-004 | Retry policies MUST include silence periods | MEDIUM |
| SC-OBS-DT-005 | Test mode MUST disable non-essential services | HIGH |
| SC-OBS-DT-006 | Graceful degradation for missing infrastructure | CRITICAL |
| SC-OBS-DT-007 | Log noise < 1000 lines for unit test run | MEDIUM |
| SC-OBS-DT-008 | Test output visibility > 90% | HIGH |

---

## Action Items

1. **Implement DirectedTelescopeController** - Context detection and profile management
2. **Implement AdaptiveLogger** - Dynamic log level and filtering
3. **Implement DegradedModeCoordinator** - Graceful infrastructure unavailability
4. **Fix AccessControlIntegration** - Snake_case key mismatch
5. **Update Watchdog** - Test mode parameters
6. **Update libcluster config** - Environment-aware topology
7. **Update ZenohSession** - Exponential backoff with silence
8. **Add container mocks** - Test doubles for container layer
