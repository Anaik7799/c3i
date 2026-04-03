# PRAJNA: Architecture Master Document

**Version**: 21.3.0-UNIFIED (Migration In Progress)
**Status**: TRANSITIONAL
**See Also**: `docs/planning/PRAJNA_MIGRATION_PLAN.md`

## ⚠️ ARCHITECTURAL PIVOT IN PROGRESS ⚠️

**Effective 2026-01-15**, the Prajna architecture is pivoting from a Dual-Stack (Elixir+F#) model to a **Unified F# Substrate**.

*   **Legacy Documentation**: Sections referencing Elixir GenServers, Phoenix LiveView, and Ecto are considered **LEGACY** and are being replaced.
*   **Target Architecture**: Refer to `docs/architecture/PRAJNA_UNIFIED_SUBSTRATE_SPEC.md` for the authoritative design of the new system.
*   **Verification Strategy**: Refer to `docs/architecture/PRAJNA_FSHARP_VERIFICATION_STRATEGY.md` for the static/runtime analysis standards.

---

## 1.0 High-Level Goals (Invariant)

The goals of Prajna remain unchanged:
1.  **Biomorphic Control**: Regulate the system like an organism (Homeostasis).
2.  **Safety First**: Deterministic checks (Guardian) before probabilistic actions (AI).
3.  **Digital Twin**: Real-time reflection of system state.

## 2.0 The Unified Substrate (Target State)

### 2.1 The "Brain in a Box"
Instead of microservices, Prajna runs as a single, highly concurrent F# process.
*   **Neurons**: Lightweight F# Agents (`MailboxProcessor`).
*   **Synapses**: Direct memory message passing (Zero Latency).
*   **Nerves**: Zenoh mesh for external communication.

### 2.2 The 100% Analysis Mandate
We enforce strict analysis at build time and runtime.
*   **Static**: F# Compiler (Strict), FSharpLint, ArchUnitNET.
*   **Runtime**: OpenTelemetry Metrics/Tracing, Structured Logging.

*(Remainder of legacy documentation retained for reference during migration...)*