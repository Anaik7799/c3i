# Clustering & Observability Verification Plan (SOPv5.11)

**Date**: 2025-12-16 16:00 CEST
**Subject**: Verification of Robust Distributed Clustering & Observability
**Framework**: SOPv5.11 + STAMP + TDG + Cybernetic OODA
**Target**: 100% Coverage & Operational Robustness

---

## 1.0 Executive Summary

This plan defines the rigorous verification process for the newly implemented **Robust Distributed Clustering System**. It leverages the **SOPv5.11 Cybernetic Framework** to ensure not just code correctness, but operational resilience, safety compliance (STAMP), and observability integration.

**Goal**: Validate that the system operates as a cohesive, self-aware "Cybernetic Organism" capable of dynamic scaling, self-healing, and deep observability.

---

## 2.0 Test-Driven Generation (TDG) Strategy

We will apply **Test-Driven Generation** to the new infrastructure components. Since the implementation is complete, we perform **Verification-Driven Validation (VDV)** to ensure 100% coverage.

### 2.1 Elixir Code Coverage (Unit/Integration)
| Component | Coverage Goal | Test File |
| :--- | :--- | :--- |
| `ClusterInstrumentation` | 100% | `test/indrajaal/observability/cluster_instrumentation_test.exs` |
| `TokenRevocationCache` | 100% | `test/indrajaal/authentication/token_revocation_cache_test.exs` |
| `libcluster` Config | 100% | Verified via Integration Test |

### 2.2 Operational Script Verification (System Tests)
| Script | Scenario | Verification Method |
| :--- | :--- | :--- |
| `start_cluster.sh` | Clean Start | Process Check + Health API (200 OK) |
| `start_cluster.sh` | Port Conflict | Expect Exit Code 1 + Error Log |
| `scale.sh` | Scale Up (Add Node) | `Node.list()` contains new node |
| `scale.sh` | Scale Down (Remove) | `Node.list()` removes node |
| `remote_console.sh` | Connectivity | Successful `iex` session |

---

## 3.0 Cybernetic & OODA Loop Verification

We authenticate the **Cybernetic Nature** of the system by testing its feedback loops.

### 3.1 Loop 1: The Observability Loop
*   **Observe**: Telemetry events (`:nodeup`, `:nodedown`).
*   **Orient**: `ClusterInstrumentation` logs structured metadata.
*   **Decide**: (Future) Auto-scaler logic.
*   **Act**: Metrics emitted to SigNoz.
*   **TEST**: Start/Stop a node -> Verify specific log lines and metric emission in `test.log`.

### 3.2 Loop 2: The Security Loop
*   **Observe**: `revoke_token(jti)` called on Node A.
*   **Orient**: `TokenRevocationCache` identifies distributed intent.
*   **Decide**: Broadcast via `Phoenix.PubSub`.
*   **Act**: Node B receives message -> Updates local ETS.
*   **TEST**: Revoke on Node A -> Verify `revoked?(jti)` is true on Node B.

---

## 4.0 STAMP Safety Constraint Validation

| ID | Constraint | Test Case |
| :--- | :--- | :--- |
| **SC-OPS-001** | Preflight Checks | Run `start_cluster.sh` with blocked port. Assert failure. |
| **SC-OPS-003** | Process Death | `kill -9 <PID>`. Verify script detects and cleans up. |
| **SC-NET-001** | Name Resolution | Verify node names match `*@127.0.0.1` or `*@*.ts.net`. |
| **SC-OBS-001** | Log Persistence | Verify `data/logs/cluster/*.log` are created and populated. |

---

## 5.0 Execution Plan (SOPv5.11 Phases)

### Phase 1: Unit Testing (TDG) - ✅ COMPLETED
1.  **Create/Update Tests**: Implemented `cluster_instrumentation_test.exs` and updated `token_revocation_cache_test.exs` for distributed cases.
2.  **Execute**: `mix test` confirmed 100% pass rate.
    - Verified `TokenRevocationCache` broadcasts to PubSub.
    - Verified `ClusterInstrumentation` attaches handlers and polls metrics.
    - Verified `test_helper.exs` robustly starts distributed node with Tailscale/Local detection.

### Phase 2: Operational Verification (Scripts)
1.  **Manual/Scripted Run**: Execute `scripts/cluster/start_cluster.sh`.
2.  **Scaling Test**: Run `scripts/cluster/scale.sh start 3`.
3.  **Verification**: Check cluster mesh via `remote_console.sh`.

### Phase 3: Failure Mode Analysis (Chaos)
1.  **Zombie Test**: Force kill a beam process. Verify monitor script reacts.
2.  **Network Test**: (Simulated) Verify behavior when nodes disconnect.

---

**Signed**: Gemini (Cybernetic Architect)
