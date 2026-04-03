# Ubiquitous Control Plane: F# Agent Architecture & Service Mandate

**Date**: 2026-03-27 11:30 CEST
**Author**: Gemini (Cybernetic Architect)
**Status**: INITIATED
**Framework**: SIL-6 Biomorphic Mesh + Zenoh v1.0.0 + MCP

---

## 1. Executive Summary
To ensure 100% fractal transparency and immediate post-boot control, every container image in the Indrajaal ecosystem MUST incorporate a native F# Monitoring & Control Agent (MCA). This agent serves as the "Nervous System Extension" within the container substrate, bridging internal service states to the global Zenoh data bus and providing a standardized MCP interface for agent swarm orchestration.

---

## 2. MCA Architecture (The Sidecar Pattern)

### 2.1 Core Components
- **Zenoh Bridge**: Native Zenoh v1.0.0 client binding for ultra-low latency signaling.
- **MCP Handler**: JSON-RPC layer providing standardized tools for container management.
- **Health Pulse**: Periodic heartbeat emitting CPU, Memory, and IO metrics.
- **Process Supervisor**: Interface to monitor and restart internal container services (e.g., Prometheus, Elixir).

### 2.2 Implementation Strategy: F# Sentinel Satellite
The MCA is implemented as a lightweight, statically compiled F# binary (`SentinelSatellite.exe`) embedded within the NixOS container image. 

**Boot Sequence**:
1. **L0 (Kernel)**: NixOS container boots.
2. **L1 (Init)**: The MCA starts as the first process (via Tini).
3. **L2 (Signal)**: MCA publishes `[BOOT_READY]` to `indrajaal/mesh/node/{id}/status`.
4. **L3 (Control)**: MCA starts primary workload (e.g., Postgres) and monitors health.

---

## 3. Mandatory Service Control & MCP Access

### 3.1 Standardized MCP Tools
Every MCA MUST expose the following tools to the Agent Swarm:
- `container_status`: Get real-time health and process tree.
- `service_restart`: Force restart of internal services.
- `log_stream`: Subscribe to internal service logs over Zenoh.
- `smriti_lookup`: Query the container's authoritative zettel for its "Living Blueprint."
- `resource_throttle`: Adjust internal cgroup limits (if permitted).

### 3.2 Control Data Plane
The MCA possesses ALL control information required to run the container, sourced directly from Smriti:
- Configuration paths (`/etc/prometheus/prometheus.yml`, etc.)
- Environment variables.
- Secret injection handles.

---

## 4. Smriti-Enabled Orchestration (SEO) Mandate
To ensure eternal evolvability, the F# scripts used to create and manage containers MUST save all operational data to Smriti and the documentation.

### 4.1 Knowledge Capture Requirements
For every container lifecycle event (Creation, Mutation, Deletion), the system MUST record:
- Exact configuration snapshots (Nix Flakes, Dockerfiles).
- Detailed build and ignition steps.
- Stability metrics and active FMEA issue status.
- Full SIL-6 criteria compliance checklist.

### 4.2 Agent Cognitive Protocol
Gemini and all participating agents SHALL retrieve all information on how to create, run, observe, and evolve containers exclusively from the Smriti Knowledge Base. Manual inference or guessing of container parameters is a violation of Axiom 7 (Holon State Sovereignty).

---

## 5. Observability Container Hardening (T23.1.6)
The `indrajaal-obs-prod` container will be the first to receive the UCP retrofit.
- **Current Issue**: Missing config volumes.
- **UCP Fix**: The MCA will verify the existence of `prometheus.yml`, `otel-config.yaml`, and `grafana.ini` before allowing the services to start, emitting an `[ERR_CONFIG_MISSING]` signal to Zenoh if parity fails.

---

## 🧬 [AGENT_RECREATION_GENOME]
**Purpose**: Rebuilding the F# Monitoring & Control Agent (MCA).
**Recovery**: 
- Project: `lib/cepaf/src/Cepaf.Sentinel.Satellite/`
- Pattern: F# + Zenoh.Net + MCP.Protocol
- Logic: `while true do { collect_metrics(); publish_zenoh(); listen_mcp(); }`
[/AGENT_RECREATION_GENOME]

---

**END OF UCP ARCHITECTURAL SPECIFICATION**
