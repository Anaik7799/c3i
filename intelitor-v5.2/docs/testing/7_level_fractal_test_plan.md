# 7-Level Fractal Test Plan for SIL-6 Homeostasis

**Version**: 1.0.0
**Architecture**: v21.3.0 Biomorphic Fractal Holon
**Compliance**: SIL-6 (IEC 61508 Extended)

## Overview
This test plan validates the Indrajaal system across 7 fractal levels of abstraction, ensuring robustness, safety, and biomorphic homeostasis. It moves from the microscopic (Cellular) to the macroscopic (Biosphere).

---

## Level 1: Cellular (Unit & Property)
**Scope**: Individual functions, pure logic, data types.
**Objective**: Verify mathematical correctness and invariants.
**Tools**: `ExUnit`, `PropCheck`, `StreamData`.

*   **TC-L1-001**: Verify STAMP constraints on all data structures using Property-Based Testing.
*   **TC-L1-002**: Verify Zenoh message serialization/deserialization (NIF bindings).
*   **TC-L1-003**: Verify CRDT merge logic for distributed state.
*   **TC-L1-004**: Verify F# Cortex type providers against JSON schemas.

## Level 2: Tissue (Component/Module)
**Scope**: Modules, GenServers, Agents, F# Actors.
**Objective**: Verify internal state management and message handling.
**Tools**: `Mox`, `Hammox`, `Expecto` (F#).

*   **TC-L2-001**: Verify `Indrajaal.Safety.Guardian` veto logic against adversarial inputs.
*   **TC-L2-002**: Verify `Indrajaal.Observability.QuadplexLogger` writes to all 4 channels.
*   **TC-L2-003**: Verify F# `Cepaf.Orchestrator` state machine transitions.
*   **TC-L2-004**: Verify Ash Resource validation logic (policies/actions).

## Level 3: Organ (Holon/Service)
**Scope**: Full Elixir Applications (`app`), F# Services (`cortex`), Database (`db`).
**Objective**: Verify service startup, supervision trees, and API contracts.
**Tools**: `mix test --integration`, `Postman`/`Newman`.

*   **TC-L3-001**: Verify `indrajaal-app` supervision tree startup (0 crashes).
*   **TC-L3-002**: Verify `indrajaal-cortex` connects to `indrajaal-db` (TimescaleDB).
*   **TC-L3-003**: Verify `indrajaal-zenoh` routing of messages between peers.
*   **TC-L3-004**: Verify REST/GraphQL API endpoints return correct HTTP codes.

## Level 4: Organ System (Container/Pod)
**Scope**: Docker/Podman Containers, Networking, Volumes.
**Objective**: Verify isolation, resource limits, and persistence.
**Tools**: `sa-test.fsx` (CEPAF), `Testcontainers`.

*   **TC-L4-001**: Verify `indrajaal-app` container mounts `data/` volume correctly (RW).
*   **TC-L4-002**: Verify network isolation (App cannot access Host FS).
*   **TC-L4-003**: Verify restart policies (Auto-restart on crash).
*   **TC-L4-004**: Verify NixOS-based image signatures.

## Level 5: Organism (Node/Cluster)
**Scope**: Single Machine running the full Mesh (3-5 containers).
**Objective**: Verify inter-container communication and homeostasis.
**Tools**: `sa-sil6-homeostasis-boot.fsx`.

*   **TC-L5-001**: Verify SIL-6 Homeostasis Boot Sequence (All checks pass).
*   **TC-L5-002**: Verify "Self-Healing" (Kill `obs`, verify auto-restart).
*   **TC-L5-003**: Verify Zenoh telemetry flow (App -> Zenoh -> Obs -> Cortex).
*   **TC-L5-004**: Verify Metabolic Scaling (Simulate load, check logs).

## Level 6: Population (Mesh/Federation)
**Scope**: Multiple Nodes (Dev -> Test -> Prod).
**Objective**: Verify distributed consensus and replication.
**Tools**: `libcluster`, `Tailscale`.

*   **TC-L6-001**: Verify Distributed Erlang clustering over Tailscale.
*   **TC-L6-002**: Verify Database Replication (Primary -> Replica).
*   **TC-L6-003**: Verify "Split-Brain" recovery (Disconnect network, reconnect).
*   **TC-L6-004**: Verify Federation Protocol (Holon A -> Holon B communication).

## Level 7: Biosphere (Multiverse/Environment)
**Scope**: The complete digital environment, including human operators and AI agents.
**Objective**: Verify long-term evolution, entropy reduction, and UX.
**Tools**: `Livebook`, `Gemini CLI`.

*   **TC-L7-001**: Verify OODA Loop Latency (< 50ms) across the entire system.
*   **TC-L7-002**: Verify "Cognitive Cockpit" visualization matches reality.
*   **TC-L7-003**: Verify AI Agent (Gemini) can query and act on the system via Cortex.
*   **TC-L7-004**: Verify System Entropy Score decreases over time.

---

## Cross-Level: E2E Browser Testing (Wallaby + Chrome via NixOS)

**Scope**: End-to-end browser testing of all Phoenix LiveView pages.
**Objective**: Verify real user interactions — tab switching, flash messages, dynamic metric updates, WebSocket-driven LiveView behavior.
**Tools**: `Wallaby`, `Chrome`/`chromedriver` (via NixOS devenv), `IndrajaalWeb.FeatureCase`.

*   **TC-E2E-001**: Verify all Prajna cockpit tabs render and switch correctly (phx-click events through WebSocket).
*   **TC-E2E-002**: Verify metric cards update dynamically via 500ms `:refresh` timer.
*   **TC-E2E-003**: Verify action buttons trigger flash messages (`role="alert"`).
*   **TC-E2E-004**: Verify trace explorer shows clickable entries with span expansion.
*   **TC-E2E-005**: Verify SigNoz/OTEL integration tab shows all 4 instrumentation modules.

**Run**: `WALLABY_ENABLED=true mix test --only wallaby` or `test-e2e` devenv command.
**Config**: `config/wallaby.exs` (conditionally imported when `WALLABY_ENABLED=true`).
**Infrastructure**: `test/support/feature_case.ex`, `test/support/wallaby_page_objects.ex` (23+ page modules).

---

## Execution Guide

1.  **Unit/Component**: `mix test`
2.  **Integration**: `dotnet fsi sa-test.fsx`
3.  **System/Homeostasis**: `dotnet fsi sa-sil6-homeostasis-boot.fsx`
4.  **E2E Browser**: `test-e2e` (Wallaby + Chrome via NixOS)
