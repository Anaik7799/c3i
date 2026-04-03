# Plan: MCP Stabilization and Biomorphic Evolution (v21.3.0)

**Created**: 2026-01-05
**Status**: ACTIVE
**Framework**: SOPv5.11 + SIL-6 Biomorphic Mesh + Fast OODA
**Target**: 100% Realized MCP Architecture (No Mock/Missing Components)

---

## 1.0 Executive Summary
The Audit of the Model Context Protocol (MCP) subsystem revealed a **Critical Genotype-Phenotype Divergence**. While the Documentation claims "Full Implementation," the F# Cortex Bridge (`Cepaf.Mcp`) and its Elixir counterpart (`Indrajaal.MCP.Cepaf`) are missing or empty. This plan orchestrates the **Materialization** of these missing organs to achieve the promised **Unified Intelligence Plane**.

---

## 2.0 Criticality-Based Next Steps (The OODA Queue)

| ID | Task | Priority | Risk | Dependency |
|----|------|----------|------|------------|
| **32.1.0** | **Verify Elixir Foundation** | P0 | Low | None |
| **32.2.0** | **Materialize F# Mcp Core** | P0 | High | 32.1.0 |
| **32.3.0** | **Implement Elixir Bridge** | P0 | Medium | 32.2.0 |
| **32.4.0** | **Wire Port Transport** | P1 | High | 32.3.0 |
| **32.5.0** | **Enable Safety Handlers** | P1 | Medium | 32.4.0 |

---

## 3.0 The 5-Level Detailed Execution Plan

### 3.1 - Level 1: Cellular (Logic & Protocol Integrity)
**Objective**: Ensure the existing Elixir Foundation is solid before building bridges.
- **3.1.1 - Protocol Verification**
    - Action: Execute `test/indrajaal/mcp/foundation/protocol_test.exs` manually if automated tools fail.
    - Standard: Zero failures.
- **3.1.2 - Type Safety Audit**
    - Action: Verify `Indrajaal.MCP.Foundation.Types` covers all F# interoperability needs (Discriminated Unions mapping).
    - Standard: Dialyzer clean.

### 3.2 - Level 2: Component (F# Cortex Materialization)
**Objective**: Create the missing F# MCP server components.
- **3.2.1 - F# Protocol Definition**
    - Action: Create `lib/cepaf/src/Cepaf/Mcp/Protocol.fs` defining JSON-RPC types.
- **3.2.2 - F# Tool Registry**
    - Action: Create `lib/cepaf/src/Cepaf/Mcp/Registry.fs` to expose CEPAF capabilities (Podman, OODA).
- **3.2.3 - F# Server Loop**
    - Action: Create `lib/cepaf/src/Cepaf/Mcp/Server.fs` to handle Stdio I/O.

### 3.3 - Level 3: Integration (The Bridge)
**Objective**: Connect Elixir and F# via a supervised Port.
- **3.3.1 - Elixir Port Handler**
    - Action: Implement `Indrajaal.MCP.Cepaf.Handler` in the empty directory.
    - Logic: Spawn `dotnet run ... --mcp`, handle Stdio streams.
- **3.3.2 - Lifecycle Management**
    - Action: Add `Cepaf.Handler` to `Indrajaal.MCP.Foundation.Supervisor`.
    - Safety: Ensure 30s timeout and graceful termination (SC-MCP-050).

### 3.4 - Level 4: Operational (Mesh Dynamics)
**Objective**: Operationalize the tools in the runtime.
- **3.4.1 - Tool Exposure**
    - Action: Register `cepaf.*` tools in the global registry.
    - Tools: `cepaf.container.list`, `cepaf.ooda.status`, `cepaf.health.check`.
- **3.4.2 - Telemetry Integration**
    - Action: Ensure F# MCP logs flow into the Quadplex Logger (Zenoh).

### 3.5 - Level 5: Evolutionary (Cognitive Feedback)
**Objective**: Enable the system to use these tools for self-improvement.
- **3.5.1 - Recursive OODA**
    - Action: Allow the AI Copilot to call `cepaf.ooda.status` to inspect its own control loop.
- **3.5.2 - Founder's Directive Check**
    - Action: Verify that F# tools enforce SC-FOUNDER-001 before execution.

---

## 4.0 Instructions for Replication (Bulletproof Protocol)

### 4.1 "Start New" Protocol
When initializing the MCP subsystem from scratch:

1.  **Check Genotype**: `cat .mcp.json` to verify configuration.
2.  **Verify Substrate**: `ls -R lib/indrajaal/mcp` and `ls -R lib/cepaf/src/Cepaf/Mcp`.
    *   *IF MISSING*: Trigger **Generation Sequence** (see 3.2 & 3.3).
3.  **Compile Foundation**: `mix compile` (Elixir) and `dotnet build` (F#).
4.  **Ignition**: `mix run --no-halt -e "Indrajaal.MCP.Foundation.Supervisor.start_link()"`
5.  **Verification**: Call `tools/list` via MCP Protocol to confirm `cepaf.*` tools appear.

### 4.2 Prohibited Actions (𝔽)
- **DO NOT** manually spawn the F# process without the Elixir Supervisor. (Violates Lifecycle constraints).
- **DO NOT** commit mock handlers for Safety Critical components (Guardian, Sentinel). (Violates SIL-6).
- **DO NOT** run without `MIX_ENV=dev` or `test` until fully verified.

---

## 5.0 Verification & Success Criteria
- **Coverage**: F# MCP code exists and compiles.
- **Integration**: `cepaf.health.check` returns real data from F# Runtime.
- **Safety**: All tool calls generate Audit Logs in `data/kms`.
