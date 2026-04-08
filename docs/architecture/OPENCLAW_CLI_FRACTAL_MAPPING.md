# Architectural Specification: OpenClaw CLI Fractal Integration

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: SYSTEM ARCHITECTURE
**Compliance**: SC-MCP-001, SC-COG-001, SC-ZMOF-001

## 1. Introduction
This document defines the architectural integration of the OpenClaw CLI feature set into the Indrajaal Personal OS. Based on a deep audit of the OpenClaw source code, we have identified key operational capabilities (Nodes, Secrets, Exec Approvals, Pairing) that will be native to our SIL-6 Biomorphic Mesh via the `sa-plan` tool.

## 2. CLI Capability Matrix & Fractal Mapping

We map OpenClaw CLI commands to our native `sa-plan-daemon` and Gleam actors to ensure they follow our Zenoh-first, highly-available architecture.

| OpenClaw CLI Feature | Indrajaal Mapping (`sa-plan`) | Fractal Layer | SIL-6 Constraint |
| :--- | :--- | :--- | :--- |
| `secrets` | `sa-plan secrets` | L3 (Transaction) | SC-SEC-042 (Secure Credential Management via `Smriti.db`) |
| `exec-approvals` | `sa-plan approvals` | L5 (Cognitive) | SC-AGT-019 (Human-in-the-loop for P0 commands) |
| `channels` | `sa-plan channels` | L7 (Federation) | SC-COM-001 (Gateway Configuration) |
| `models` | `sa-plan models` | L5 (Cognitive) | SC-COG-001 (LLM Provider Switching) |
| `pairing` / `qr` | `sa-plan pair` | L7 (Federation) | SC-SEC-041 (Secure Device Onboarding) |
| `nodes` (camera/screen) | `sa-plan nodes` | L6 (Ecosystem) | SC-ZMOF-001 (Distributed Sensor Nodes via Zenoh) |
| `webhooks` | `sa-plan webhooks` | L7 (Federation) | SC-COM-002 (Inbound Stimuli Registration) |
| `config` / `profile` | `sa-plan config` | L4 (Motor) | SC-DAT-040 (System State Versioning) |

## 3. Operational & Usage Layers

### 3.1 Secrets & Configuration Management
The `secrets` and `config` commands will replace raw SQL queries for updating `Smriti.db`. The Rust daemon will expose administrative endpoints over Zenoh to securely inject OAuth tokens (e.g., Google Workspace) and API keys (e.g., Telegram, OpenRouter).

### 3.2 Human-In-The-Loop (HITL) Execution Approvals
OpenClaw's `exec-approvals` maps perfectly to our need for safety in autonomous operations.
*   **Workflow**: When the Gleam Cortex decides to execute a destructive `exec` command, it will pause the OODA loop and emit an `ApprovalRequest` via Telegram/GChat.
*   **CLI Verification**: The user can approve the action on mobile, or use `sa-plan approvals approve <id>` locally.

### 3.3 Distributed Nodes (Sensors & Actuators)
OpenClaw's `nodes` (camera, screen) functionality extends our mesh. We will deploy lightweight Zenoh clients (written in Rust or Gleam) on auxiliary devices (e.g., Raspberry Pi cameras, laptops). These nodes publish sensor data to `indrajaal/l6/sensors/**`, which the Cortex can observe.

## 4. Substrate Independence
All CLI features will be implemented purely in Rust (`sa-plan-daemon/src/cli.rs`) and will communicate over Zenoh to distributed components. No feature will bypass the safety kernel or manipulate state files directly without a database transaction.
