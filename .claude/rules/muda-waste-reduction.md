# Muda (Waste Reduction) Protocol
**Status**: MANDATORY
**Scope**: Entire SIL-6 Biomorphic Mesh Codebase
**Date**: 2026-04-04
# 1. Core Philosophy (Lean Engineering)
"Muda" is the Japanese term for waste. In the context of the Indrajaal c3i system, we strictly practice Muda to maintain the system's anti-fragile nature, minimize the attack surface, and optimize the OODA loop latency.
# 2. The 7 Wastes of Software Engineering
Every system change MUST be evaluated against these wastes:
1.  **Overproduction**: Writing "just-in-case" code. Only implement features strictly mandated by the current `PROJECT_TODOLIST.md` task.
2.  **Waiting**: Synchronous blocking calls. Use async streams, `tokio::select!`, or Gleam OTP `actor` isolation.
3.  **Transport**: Unnecessary data serialization/deserialization. Use the Zenoh-MCP-OTel Fractal Backplane (ZMOF) to avoid point-to-point HTTP hops.
4.  **Extra Processing**: Redundant parsing. Cache parsed rule scripts (e.g., `OnceLock` in Rust) or pre-compute dependency graphs.
5.  **Inventory**: Unused variables, dead code, unused imports, or redundant dependencies. These MUST be purged immediately. A codebase with warnings is considered degraded.
6.  **Motion**: Fragmented logic. Unify scattered procedural checks into declarative rules (e.g., Unified Decision Brain).
7.  **Defects**: Bugs and regressions. Prevented by strict adherence to the Triple-Interface Mandate and SC-CMP-025 (Zero Warnings).
# 3. Mandatory Actions (SC-MUDA-001)
-   **Zero Warnings Gate**: The system SHALL prevent compilation with ANY warnings. All unused imports, variables, and unreachable patterns MUST be removed before committing.
-   **Dead Code Elimination**: Periodically audit for and remove unused private functions or unused exported module functions.
-   **Inefficiency Audits**: Replace inefficient operations (e.g., `list.length(l) > 0`) with optimal variants (e.g., `l != []`).
-   **Continuous Cleanup**: When modifying a file, actively practice Muda on its contents. If you see waste, eliminate it.