# SIL-6 Homeostasis Activation Plan (v21.3.0)

**Version**: 1.0.0
**Date**: 2026-01-08
**Architect**: Gemini Cybernetic Architect
**Status**: IN_PROGRESS

## 1. Executive Summary
This document defines the activation protocol for **SIL-6 Homeostasis Mode**, transforming Indrajaal into a biomorphic, fractal, and self-healing system. It introduces **Distributed Saga Orchestration** (BASE consistency) to manage complex workflows and utilizes **F# Cortex** for cognitive oversight.

## 2. 7-Layer Fractal Architecture

| Layer | Component | SIL-6 Enhancement | Implication |
|---|---|---|---|
| **L7 (Federation)** | `sa-sil6-boot.fsx` | Transactional Boot Sequence | Deterministic startup with rollback capabilities. |
| **L6 (Mesh)** | `indrajaal-zenoh` | Neural Nervous System (TCP/7447) | <10ms latency for control signals across the cluster. |
| **L5 (Interface)** | `SagaMonitor` (F#) | Cognitive Observability | Real-time tracking of distributed transactions in the Cortex. |
| **L4 (Safety)** | `Guardian` | Saga Initiation Gate | Safety checks applied before any Saga starts. |
| **L3 (Cognition)** | `Cepaf.Podman` | Infrastructure Cognition | F# binary rebuilt with Transaction awareness. |
| **L2 (Metabolism)** | `SagaManager` (Elixir) | Compensating Transactions | Failure in Step N triggers undo(N)..undo(1). |
| **L1 (Memory)** | `kms_sagas` | Persistent State | Audit trail of every transaction step (Pending/Committed/Failed). |
| **L0 (Substrate)** | `podman-compose` | Datadog + NixOS | Full telemetry export and immutable container runtime. |

## 3. Distributed Transaction Strategy (Sagas)
We utilize the **Orchestration-based Saga Pattern** for robustness and observability.

- **Consistency**: BASE (Basically Available, Soft state, Eventual consistency).
- **Failure Handling**:
    - **Transient**: Automatic retry with exponential backoff.
    - **Permanent**: Compensating Transactions (Rollback) executed in reverse order.
- **State**: Persisted in `kms_sagas` table (Postgres).

## 4. Implementation Plan

### 4.1 Infrastructure (L0)
- Add `indrajaal-zenoh` to `podman-compose-3container.yml`.
- Configure `indrajaal-otel` for Datadog export.

### 4.2 Data (L1)
- Migration: `create_kms_sagas` table.

### 4.3 Logic (L2)
- Elixir GenServer: `Indrajaal.Transactions.SagaManager`.
- Supervision Tree: Add `SagaManager`.

### 4.4 Cortex (L3)
- F# Module: `Cepaf.Podman.Transactions.SagaMonitor`.
- Rebuild `Cepaf.Podman.dll`.

### 4.5 Boot & Verify (L7)
- `sa-sil6-boot.fsx`: The master bootloader.
- `verify_sil6_saga.exs`: Functional test suite.

## 5. Risk Assessment (FMEA)
- **Risk**: Partial failure during Saga execution.
    - **Mitigation**: `kms_sagas` persists state; recovery process resumes or rolls back on restart.
- **Risk**: Cortex/Logic Desync.
    - **Mitigation**: Zenoh heartbeat ensures L2 and L3 share state awareness.

## 6. Verification
Run `mix run scripts/testing/verify_sil6_saga.exs` to confirm:
1. Successful Saga execution.
2. Failed Saga triggering rollback.
3. Telemetry emission.
