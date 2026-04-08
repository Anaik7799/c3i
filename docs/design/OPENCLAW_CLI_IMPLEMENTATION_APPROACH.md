# Design & Implementation Approach: OpenClaw CLI Ecosystem

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: IMPLEMENTATION STRATEGY

## 1. Overview
This document specifies the strategy to incorporate OpenClaw CLI functionality (e.g., node management, human-in-the-loop approvals, secret management, device pairing) into the existing Indrajaal Personal OS `sa-plan` tool.

## 2. Implementation Strategy (Rust Motor Strip)

The `sa-plan-daemon`'s CLI module (`src/cli.rs`) and main router (`src/main.rs`) will be extended. We do not use the OpenClaw TS code directly; instead, we map its operational features to our SIL-6 verified Rust/Zenoh architecture.

### 2.1 Secrets & Config (`sa-plan secrets`, `sa-plan config`)
*   **Current State**: Secrets are manually inserted via raw `sqlite3` commands.
*   **New Design**: Add clap subcommands:
    *   `sa-plan secrets set <key> <value>`
    *   `sa-plan secrets get <key>`
    *   `sa-plan config get-profile`
*   **Implementation**: Rust CLI parses the arguments, opens a local SQLite connection to `Smriti.db` (or makes a Zenoh RPC call if acting as a client), and securely sets the values in the `UserPreferences` table.

### 2.2 Execution Approvals (`sa-plan approvals`)
*   **Current State**: OODA loop runs autonomously or fails. No interactive pause.
*   **New Design**: The Gleam `Cortex` (when using `mcp_sys::exec` or `mcp_file::write`) will check the tool profile. If an approval is required (SC-AGT-019), it enters an `AwaitingApproval` state and sends a notification via Telegram/GChat.
*   **Implementation**:
    *   `sa-plan approvals list` -> Queries `Smriti.db` for pending approval intents.
    *   `sa-plan approvals approve <id>` -> Sends a Zenoh intent (`indrajaal/l5/cog/intent/req`) to resume the Cortex.
    *   `sa-plan approvals deny <id>` -> Aborts the intent.

### 2.3 Channels & Models (`sa-plan channels`, `sa-plan models`)
*   **New Design**: Allow the user to dynamically switch LLM providers or gateway configurations without editing `.env` files.
*   **Implementation**:
    *   `sa-plan models set gemma4` -> Updates `Smriti.db` -> Rust daemon dynamically updates the `LLM_PROVIDER` logic in `openrouter.rs` via a hot-reload or environment update.

### 2.4 Distributed Nodes & Pairing (`sa-plan nodes`, `sa-plan pair`)
*   **New Design**: Support remote devices (e.g., a laptop camera streaming to the mesh).
*   **Implementation**:
    *   `sa-plan pair` generates a secure QR code (using a Rust QR crate) or a pairing token that a remote Zenoh client can use to authenticate with the mesh.
    *   `sa-plan nodes list` queries Zenoh for active publishers under the `indrajaal/l6/sensors/**` namespace.

## 3. Staged Rollout Plan
1.  **Phase 1: Secrets & Configuration**: Replace all raw SQL commands in our workflows with `sa-plan secrets set`.
2.  **Phase 2: Execution Approvals (HITL)**: Implement the pausing logic in Gleam and the `approvals` CLI in Rust. This is a critical safety feature for autonomous agents.
3.  **Phase 3: Channels & Models**: Dynamic hot-swapping of LLM providers.
4.  **Phase 4: Node Pairing**: Multi-device Zenoh authentication for distributed sensors.
