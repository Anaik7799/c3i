# PLAN: MCP Total Integration (M-TIP) v21.3.0

**Classification**: L5-SPINE (Strategic Evolution)
**Status**: ACTIVE
**Framework**: SOPv5.11 + SIL-6 + Fast OODA
**Target**: 100% System Exposure via MCP

---

## 1.0 Executive Summary
This plan orchestrates the evolution of Indrajaal into a fully **Agent-Accessible Organism**. Every function, metric, and control surface will be exposed via the Model Context Protocol (MCP), enabling Claude/Gemini to perceive and actuate the entire system with granular precision.

### 1.1 The "Unified Intelligence Plane"
We will transition from isolated MCP servers to a **Unified MCP Router** that dispatches requests to:
1.  **Logic Plane (Elixir)**: Domain Contexts, Business Logic.
2.  **Cortex Plane (F#)**: Orchestration, OODA, Heuristics.
3.  **Memory Plane (KMS)**: State, Knowledge, Vector Search.

---

## 2.0 Architecture: The Fractal MCP Layer

### 2.1 Unified Server (`Indrajaal.MCP.UnifiedServer`)
A single entry point (Port 9999) that routes requests based on namespace:
- `indrajaal.*` -> Domain Handlers
- `prajna.*` -> Cockpit/Safety Handlers
- `cepaf.*` -> F# Bridge Handlers
- `kms.*` -> KMS Server

### 2.2 F# Bridge (`Cepaf.Mcp`)
A lightweight JSON-RPC server embedded in the F# runtime, communicating with Elixir via Stdio (Port).
- Exposes: `Podman`, `Mesh`, `OODA`, `Telemetry`.

---

## 3.0 Implementation Plan (5-Level)

### 3.1 - L1: Foundation (Protocol & Transport)
- **3.1.1** - Implement `Indrajaal.MCP.Foundation` (Protocol, Registry, Auth).
- **3.1.2** - Implement F# `Cepaf.Mcp.Protocol` (Types, Serialization).

### 3.2 - L2: Domain Exposure (Elixir)
- **3.2.1** - Create `Indrajaal.MCP.Domains.*` handlers for all 15 domains.
- **3.2.2** - Use Metaprogramming to auto-generate tool definitions from Ash Resources.

### 3.3 - L3: Cortex Exposure (F#)
- **3.3.1** - Implement `Cepaf.Mcp.Server` loop.
- **3.3.2** - Map `Cepaf.Modules.Podman` to `cepaf.podman.*` tools.
- **3.3.3** - Map `Cepaf.Mesh.Ooda` to `cepaf.ooda.*` tools.

### 3.4 - L4: Safety & Observability
- **3.4.1** - Enforce **Guardian Pre-Flight** for all Write operations.
- **3.4.2** - Stream all MCP Tool calls to **Zenoh** (`indrajaal/telemetry/mcp`).

### 3.5 - L5: Evolutionary Loop
- **3.5.1** - Enable **Agent-Self-Modification** (Agents can call `mcp_deploy` to update themselves, subject to 2oo3 voting).

---

## 4.0 Success Criteria
1.  **Coverage**: >90% of public functions exposed as Tools.
2.  **Latency**: Tool overhead < 10ms.
3.  **Safety**: 100% of destructive acts blocked without Guardian Token.
4.  **Polyglot**: Seamless Elixir <-> F# tool calling.

---

## 5.0 User Guide (Agent Perspective)

### 5.1 Discovery
```bash
mcp call tools/list
```

### 5.2 Invocation
```bash
# Elixir Domain
mcp call indrajaal_accounts_create_user --email "agent@system.local"

# F# Cortex
mcp call cepaf_mesh_status

# Cross-Plane Coordination
mcp call prajna_guardian_propose --action "reboot_mesh"
```
