# Test Infrastructure Specification: OpenClaw CLI Integration

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: TESTING FRAMEWORK

## 1. Overview
This document specifies the SIL-6 compliant test infrastructure required to validate the new CLI capabilities adapted from OpenClaw into the `sa-plan` tool.

## 2. Test Tiers

### 2.1 Tier 1: Rust CLI Unit Testing
*   **Target**: `cli.rs` in `sa-plan-daemon`.
*   **Framework**: Cargo test with `assert_cmd` or standard I/O capture.
*   **Specific Tests**:
    *   `test_secrets_set_get`: Verify that running `sa-plan secrets set test_key test_val` successfully updates the mock `Smriti.db` and `get` retrieves it.
    *   `test_approvals_list_empty`: Verify that `sa-plan approvals list` returns a clean, formatted table of 0 pending approvals.
    *   `test_models_set`: Verify that updating the model profile reflects immediately in the database state.

### 2.2 Tier 2: Execution Approval (HITL) Workflow Testing
*   **Target**: Gleam `Cortex` $\leftrightarrow$ Rust `sa-plan`.
*   **Framework**: Gleam integration tests and Rust CLI invocation.
*   **Specific Tests**:
    *   `test_exec_pauses_for_approval`: Send a destructive intent (e.g., `rm -rf`) to the Cortex. Assert that the OODA loop halts in `AwaitingApproval` state.
    *   `test_cli_approval_resumes_cortex`: While the Cortex is paused, invoke `sa-plan approvals approve <id>`. Assert that the Cortex resumes, executes the command, and returns the result.

### 2.3 Tier 3: Node Discovery & Pairing Tests
*   **Target**: Zenoh mesh discovery via CLI.
*   **Framework**: Multi-process Zenoh testing in Rust.
*   **Specific Tests**:
    *   `test_node_discovery`: Spawn a dummy Zenoh publisher simulating a remote camera on `indrajaal/l6/sensors/cam1`. Run `sa-plan nodes list`. Verify that `cam1` appears in the CLI output.

## 3. Behavioral Constraints (SC-CLI)
*   **SC-CLI-001**: The `secrets` command MUST NEVER log the secret value to the console or the application logs during a `set` operation.
*   **SC-CLI-002**: `sa-plan approvals` MUST cryptographically verify the user's intent (e.g., requiring the local user context) before releasing a halted OODA loop.
