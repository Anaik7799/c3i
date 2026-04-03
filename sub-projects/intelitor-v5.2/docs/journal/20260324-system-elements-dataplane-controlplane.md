# Journal Entry: System Elements - Data Plane vs. Control Plane
**Date**: 2026-03-25
**Author**: Cybernetic Architect (Gemini)
**Context**: Deep dive into the functional division of the 14-Node SIL-6 Architecture.

The Indrajaal architecture uses a strict separation of concerns to ensure that heavy data processing does not interfere with the system's ability to monitor, heal, and route itself. This is achieved through the Control Plane and the Data Plane.

## 1. The Control Plane (Command, Orchestration & Routing)
**Functionality**: The Control Plane makes decisions. It monitors health, routes traffic, enforces safety constraints, and manages the lifecycle of the system. It uses very little CPU/RAM but requires ultra-low latency.

### Core System Elements in the Control Plane:
*   **Zenoh Routers (`zenoh-router-1, 2, 3`)**: The communication backbone. Instead of HTTP, all internal commands and telemetry use this high-speed, zero-copy pub/sub mesh. It ensures messages reach their destination even if a node goes down (via 2oo3 quorum).
*   **F# Cortex (`indrajaal-cortex`)**: The "Executive Brain" for infrastructure. It evaluates system health and decides when to scale up, scale down, or execute apoptosis (safe shutdown).
*   **CEPAF Bridge (`cepaf-bridge`)**: The infrastructure actuator. It translates Cortex decisions into actual Podman commands (start/stop containers) via the host socket.
*   **The Guardian**: An Elixir safety kernel. It intercepts any automated changes proposed by AI agents and validates them against the STAMP safety rules before they are allowed to execute.
*   **Synapse**: The cognitive router. It takes a user prompt and decides: "Is this simple enough for local heuristics, or does it need the massive Mojo compute engine?"

## 2. The Data Plane (Execution, Compute & Storage)
**Functionality**: The Data Plane does the actual work. It executes business logic, renders the UI, processes massive AI inferences, and stores data durably. It requires high bandwidth and heavy CPU/GPU/RAM resources.

### Core System Elements in the Data Plane:
*   **Application Cluster (`indrajaal-ex-app-1, 2, 3`)**: The core Elixir/Phoenix nodes. They serve the web interfaces (Prajna Cockpit), process user HTTP requests, and run the fast, local "Reflex" AI logic using `Nx` and `EXLA`.
*   **Mojo MAX Engine (`indrajaal-mojo`)**: The heavy intelligence node. When the Control Plane routes a complex task here, this node utilizes all available CPU/GPU power to run Large/Small Language Models (like Llama 3) via the Modular MAX framework.
*   **FLAME Satellites (`indrajaal-ml-runner-1, 2`)**: Ephemeral worker nodes. If the main Application Cluster gets bogged down processing heavy streams, it dynamically pushes the work to these satellites to keep the UI responsive.
*   **Persistence (`indrajaal-db-prod`)**: PostgreSQL and TimescaleDB. Stores all standard user data, historical business records, and high-volume time-series metrics.
*   **Holonic Memory (SMRITI)**: Stored in SQLite and DuckDB files (`data/holons/`), this is the immutable state of the system itself—its configuration, evolution history, and AI knowledge vectors.
*   **Observability (`indrajaal-obs-prod`)**: The telemetry sink (Prometheus, Loki, SigNoz). It passively ingests massive amounts of log and trace data from the entire Data Plane, which the Control Plane then analyzes.

## Summary of Interaction
The **Control Plane** uses the **Zenoh** network to tell the **Data Plane** what to do. The **Data Plane** processes the heavy workloads (Mojo/App/FLAME) and dumps the results into **Persistence** (DB/SMRITI) and its metrics into **Observability**, where the **Control Plane** reads them to make its next decision.
