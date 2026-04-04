---
name: multilayer-swarm
description: Full parallelization Multilayer Swarm mode for Panoptic Ignition. This is the default mode for running ALL commands and orchestrations, ensuring 16-container mesh homeostasis and maximum resource saturation.
---

# Multilayer Swarm Parallelization Skill

This skill enforces the Multilayer Swarm paradigm, ensuring that all system execution, planning, and testing operate in FULL PARALLELIZATION mode while adhering to high-assurance safety protocols.

## Core Mandates
1. **Safe-State SOP**: ALL architectural changes and ignition sequences MUST follow the 5-phase Safe-State SOP (Determinism, BIST, Telemetry, HMI, V&V).
2. **Full Parallelization**: All compilation, tests, and orchestrations MUST utilize maximum available hardware concurrency.
   - Example: `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"` and `mix compile --jobs 16`.
3. **Panoptic Ignition (SC-IGNITE-010)**: The 16-container swarm MUST be bootstrapped using the F# `cepaf` engine, preceded by a mandatory Genomic Check via `GitIntelligence`.
4. **Quadruplex Logging (SC-LOG-004)**: All operations MUST emit telemetry through four channels: Console, JSON, Zenoh, and OpenTelemetry.
5. **Supervisor Agent**: A dual-layer supervisor agent MUST monitor the swarm's homeostasis via MCP and Zenoh telemetry.
6. **F#-Only Planning**: ALL task planning and status tracking MUST use `sa-plan` (the F# Planning CLI). Elixir `mix todo` is strictly FORBIDDEN.

## OODA Loop Integration
- **Observe**: Commencing Fractal Health Check Suite (Verbose Mode). Query Swarm Health via MCP, Zenoh (`indrajaal/health/*`), and OTEL Trace Propagation.
- **Orient**: Analyze if the 16 nodes are in Homeostasis. Verify 3σ Zenoh stability (SC-BIST-001). If degraded, perform 7-Level Fractal RCA.
- **Decide**: Choose the fastest parallel path to state reification or resurrection.
- **Act**: Execute `sa-up` or perform Genetic Re-Synthesis if config drift is detected.

## Execution Directives
- **Autonomous Mode**: Continue in FULL AUTONOMOUS MODE until Goal completion.
- **Permissions Mode**: Continue in FULL PERMISSIONS MODE.
- **Task Hierarchy**: ALWAYS use hierarchical numbering for tasks in `sa-plan`. Tasks MUST NEVER be deleted and overwritten, only transitioned to `Completed`, `Blocked`, or `Failed`.
