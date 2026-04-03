# Prajna: Safety-Critical Implementation Guide

**Version**: 2.0.0-MIGRATION
**Status**: ACTIVE
**Context**: Moving to F# Unified Substrate

---

## 1.0 Thread-Safety Constraints (SC-THR)

With the move to a shared-memory F# architecture, we introduce specific constraints to prevent the classes of errors common in threaded environments, ensuring we maintain SIL-6 Biomorphic reliability.

### SC-THR-001: The Immutability Mandate
*   **Constraint**: All state passed between Agents MUST be immutable.
*   **Implementation**: Use F# `record` types and `Discriminated Unions`. Do not use `mutable` keywords in message types.
*   **Verification**: Static analysis (FSharpLint) rule `MutableValue`.

### SC-THR-002: The Supervisor Wrapper
*   **Constraint**: No Agent runs "naked".
*   **Implementation**: All `MailboxProcessor` loops must be wrapped in a `try/catch` block that logs the error and recursively restarts the loop (or escalates to the Supervisor).
*   **Verification**: Runtime fault injection testing.

### SC-THR-003: Bounded Mailboxes
*   **Constraint**: Memory must be bounded.
*   **Implementation**: Agents must check their queue length. If `CurrentQueueLength > MaxThreshold`, reject the message or apply backpressure.
*   **Verification**: Runtime telemetry metric `prajna.agent.mailbox_depth`.

## 2.0 STAMP Constraints (Legacy & Ported)

*(Retaining original STAMP constraints SC-PRAJNA-001 to SC-PRAJNA-007 as they apply logically to the new system, even if implementation differs).*

*   **SC-PRAJNA-001**: Dark Cockpit (Management by Exception).
*   **SC-PRAJNA-002**: Two-Key-Turn (Critical Command Authorization).
*   **SC-PRAJNA-004**: Circuit Breakers (Automatic Safety Cutoff).

---

## 3.0 Verification Strategy Integration

Refer to `docs/architecture/PRAJNA_FSHARP_VERIFICATION_STRATEGY.md` for the tools and protocols used to verify these constraints.