# User Guide: Indrajaal Personal OS Prompt Commands

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: USER GUIDE / OPERATIONAL MANUAL
**Compliance**: SC-ULTRA-001, SC-MATH-COV, SC-HA-001, SC-OPENCLAW

## 1. Overview

This guide details the operational procedures and user journeys for the **Prompt Commands** (`/evolve-sil6` and `/allium`) engineered into the Indrajaal Personal OS. These commands are macros designed to interface with the AI agents (Claude, Gemini, OpenCode) operating within the workspace, forcing them to strictly adhere to the SIL-6 Biomorphic Mesh constraints, the OpenClaw Sensory-Motor architecture, and High Availability (HA) requirements.

## 2. The Master Evolutionary Command: `/evolve-sil6`

### 2.1 Description
`/evolve-sil6` is the master directive for autonomous, mathematically verified system evolution. It instructs the AI agent to enter "Full Autonomous Mode" with maximum parallelization, bypassing incremental permissions to execute a comprehensive sprint goal while maintaining 100% adherence to the system's formal architecture.

### 2.2 Usage
```text
/evolve-sil6 [SPRINT_GOAL]
```

### 2.3 User Journeys & Scenarios

#### Scenario A: Adding a New Subsystem
*   **User Action**: Types `/evolve-sil6 Implement a new Drone Orchestration subagent in Gleam.`
*   **Agent Behavior**:
    1.  **Architecture**: Performs an "Ultrathink Deep Pass." Maps the Drone Orchestrator to the L5 Cognitive layer and L4 Motor layer.
    2.  **Formalization**: Creates `specs/allium/drone_orchestrator.allium` detailing invariant state conditions (e.g., max drone altitude, boundary box).
    3.  **TDG**: Writes Property and Integration tests in Gleam before any production code.
    4.  **Implementation**: Writes the Gleam OTP actor and Rust Motor endpoint.
    5.  **Authority**: Uses `./sa-plan add` to track the tasks, `./sa-plan update` as it progresses.
    6.  **Closure**: Creates a journal entry, runs `./sa-plan sync`, and pushes to git.

#### Scenario B: Refactoring Existing Code for High Availability
*   **User Action**: Types `/evolve-sil6 Refactor the Database interface to use the HA Leader Election lease.`
*   **Agent Behavior**:
    1.  **Analysis**: Reads `LeaderElection.tla` and `ha_seamless_upgrade.allium`.
    2.  **Implementation**: Modifies the Rust Database handler to check for `LeaderLease` before executing writes.
    3.  **Testing**: Updates the E2E chaos test (`ha_upgrade_e2e.sh`) to verify DB write consistency during failover.
    4.  **Closure**: Logs the architectural change, syncs the DB, and pushes.

#### Scenario C: OpenClaw Tool Integration
*   **User Action**: Types `/evolve-sil6 Add a Slack Gateway using the OpenClaw architecture.`
*   **Agent Behavior**:
    1.  **Mapping**: Identifies this as an L7 Federation mapping.
    2.  **Implementation**: Modifies `sa-plan-daemon/src/cortex.rs` to include a Slack branch in the Gateway MCP tool. Implements a `gateway/slack.gleam` supervised actor.
    3.  **Security**: Uses the `Smriti.db` secure Vault for the Slack token.
    4.  **Closure**: Syncs state and logs the implementation.

#### Scenario D: Automated Documentation Notifications (SC-NOTIFY)
*   **User Action**: Types `/evolve-sil6 create a new API endpoint for the task manager and document its usage.`
*   **Agent Behavior**:
    1.  **Execution**: Completes the implementation and creates `docs/API_REFERENCE.md`.
    2.  **Email Notification**: Automatically invokes the `gmail_send_email` MCP tool to send the full Markdown content of `docs/API_REFERENCE.md` to `abhijit.naik@boutytek.com`.
    3.  **Chat Notification**: Automatically invokes the `gateway` MCP tool to send a summary (e.g., "✅ Added new API reference at docs/API_REFERENCE.md. Key features: POST/GET tasks.") to Google Chat or Telegram.
    4.  **Value**: The operator receives passive, real-time intelligence on structural system changes without needing to explicitly check the git history.

### 2.4 Error Handling & Fallbacks
If the agent determines the `[SPRINT_GOAL]` violates a core mandate (e.g., "Bypass Podman sandboxing for speed"), it is instructed to **REFUSE** the command, cite the specific SC-* constraint violated, and await a revised, compliant command.

---

## 3. The Behavioral Specification Command: `/allium`

### 3.1 Description
The `/allium` suite of commands interacts with the Allium v3 behavioral specifications (e.g., `ignition.allium`, `openclaw_advanced.allium`). It is used to generate, verify, or extract mathematical invariants from the system code.

### 3.2 Usage
*   `/allium`: Examine project, offer distillation or spec building.
*   `/allium:tend <req>`: Grow specs from requirements.
*   `/allium:weed <path>`: Detect spec ↔ code drift.
*   `/allium:distill`: Extract specs from existing code.
*   `/allium:propagate`: Generate tests from specifications.
*   `/allium:elicit`: Structured conversation to build spec from scratch.

### 3.3 User Journeys & Scenarios

#### Scenario A: Designing a New Component (Tending)
*   **User Action**: Types `/allium:tend We need a new rate limiter for the Telegram Gateway.`
*   **Agent Behavior**:
    1.  Reads existing specs (`openclaw_perception_acp.allium`).
    2.  Drafts a new `contract RateLimiter` and `invariant max_requests_per_minute` within the Allium file.
    3.  Awaits user approval of the formal math before implementation.

#### Scenario B: Auditing for Architectural Drift (Weeding)
*   **User Action**: Types `/allium:weed lib/cepaf_gleam/src/cepaf_gleam/gateway/telegram.gleam`
*   **Agent Behavior**:
    1.  Reads the Gleam source code.
    2.  Cross-references with `openclaw_perception_acp.allium` and `ha_seamless_upgrade.allium`.
    3.  **Output**: Reports "ALIGNED" or flags divergences (e.g., "Code does not implement the retry backoff specified in the contract").

#### Scenario C: Generating Tests from Math (Propagating)
*   **User Action**: Types `/allium:propagate specs/allium/ha_seamless_upgrade.allium`
*   **Agent Behavior**:
    1.  Parses the `seamless_handover_latency` invariant ($< 50ms$).
    2.  Generates a Gleam Integration test (`test/mesh/ha_handover_latency_test.gleam`) that explicitly measures the clock time during a simulated leader failure.
    3.  Outputs the test file ready for execution.

## 4. Best Practices for Operational Command Usage
1.  **Always specify the "Why"**: When using `/evolve-sil6`, give the agent the context of *why* the goal matters to the larger mesh.
2.  **Trust the Math**: Use `/allium:weed` regularly, especially after a long `/evolve-sil6` sprint, to ensure the AI did not hallucinate logic that drifts from the formal invariants.
3.  **Monitor the Output**: Even in "Full Autonomous Mode", monitor the terminal output for the `[DEBUG HOOK]` traces from the Motor Strip to ensure the Gleam-to-Rust bridge is functioning as designed.
