# Design & Implementation Approach: OpenClaw CLI Ultrathink Strategy

**Version**: 2.0.0
**Date**: 2026-04-08
**Classification**: IMPLEMENTATION STRATEGY / SIL-6

## 1. Overview
This document specifies the strict implementation strategy for the OpenClaw CLI capabilities, evaluated through the lens of the **Ultrathink Evolutionary Mandate (SC-ULTRA-001)**. It mandates that we do not merely port TypeScript to Rust, but fundamentally redesign the capabilities to leverage the Zenoh-Native CRDT State Backplane and Zero-IP routing.

## 2. Implementation Strategy: The Rust Authoritative Daemon

The `sa-plan-daemon` (`src/cli.rs`) serves as the strict entry point.

### 2.1 The Cryptographic Secret Gateway (`sa-plan secrets`)
*   **Design**: Rust implementation utilizing `ring` or `rust-crypto` for symmetric encryption of the SQLite payload.
*   **Implementation Steps**:
    1.  Create `src/security/crypto.rs` to handle AES-256-GCM encryption/decryption of the `Value` column in the `UserPreferences` table.
    2.  Implement `Zeroize` traits on all in-memory structs handling API keys to satisfy **SC-CLI-010**.
    3.  `sa-plan secrets set <key>` reads the value from `stdin` (via `rpassword` crate) to prevent the secret from appearing in the user's `~/.bash_history`.

### 2.2 Zero-IP Node Pairing (`sa-plan nodes` & `sa-plan pair`)
*   **Design**: Eliminating the need for static IPs for companion apps.
*   **Implementation Steps**:
    1.  `sa-plan pair` generates an ECDSA keypair and outputs the public key as a QR code (using `qrcode` crate) to the terminal.
    2.  The remote node scans the QR, joins the Zenoh mesh using standard peer discovery, and authenticates its payloads by signing them with the private key.
    3.  The daemon maintains an allowed list of public keys in `Smriti.db`. If a Zenoh payload on `indrajaal/l6/sensors/**` fails signature verification, it is dropped silently (FMEA Mitigation).

### 2.3 Continuous Formal Verification for HITL (`sa-plan approvals`)
*   **Design**: Implementing the OODA Halt mechanism in the Gleam Cortex.
*   **Implementation Steps**:
    1.  Extend `CortexState` in Gleam to include an `AwaitingApproval(id: String, timeout_ms: Int)` variant.
    2.  When the Cortex attempts an `exec` action via Zenoh MoZ, the Rust `mcp_sys.rs` evaluates the command against a strict regex blacklist.
    3.  If matched, Rust returns an `IgnitionError::ApprovalRequired(id)`.
    4.  Gleam transitions to `AwaitingApproval`, dispatches a Telegram intent with the `id`, and spins.
    5.  User runs `sa-plan approvals approve <id>` (or replies via Telegram), which emits an `ApprovalGranted` intent to Zenoh.
    6.  Gleam resumes and re-dispatches the command with an attached cryptographic proof of approval.

## 3. Evolutionary Rollout
1.  **Phase 1 (Security Foundation)**: Implement `Zeroize` and encrypted SQLite storage for secrets. All existing mock tokens are migrated to this secure vault.
2.  **Phase 2 (HITL Mechanics)**: Implement the OODA Halt state in Gleam and the `approvals` CLI in Rust.
3.  **Phase 3 (Zero-IP Topology)**: Implement the QR code generation and ECDSA validation for external sensor nodes.
