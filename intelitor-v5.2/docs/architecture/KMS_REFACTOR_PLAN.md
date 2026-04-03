# KMS Refactoring Plan: The "Cortex Shift"

**Version**: 1.0.0
**Date**: 2026-01-08
**Status**: APPROVED
**Mandate**: Move ALL KMS functionality to F# (Cortex). Remove KMS code from Elixir (Substrate).

---

## 1.0 Architectural Directive

The **Knowledge Management System (KMS)** is the "Brain" of the architecture. To achieve **SIL-6** reliability and **Homeostasis**, the Brain must be decoupled from the biological substrate (Elixir/BEAM).

**New Architecture**:
- **Cortex (F#)**: The *sole* owner of KMS data (SQLite/DuckDB). Handles all logic, persistence, vector search, and reasoning.
- **Substrate (Elixir)**: A "dumb" client. It queries the Cortex for state/decisions via a rigid, type-safe IPC channel (Stdio Port).

### 1.1 The "Iron Curtain" Rule
Elixir SHALL NOT access `data/kms/*.db` directly. All file handles to KMS databases MUST be held exclusively by the F# process.

---

## 2.0 STAMP Safety Constraints (SC-KMS-REF)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| **SC-KMS-REF-001** | **Exclusive Ownership**: Only the F# process SHALL hold write locks on KMS databases. | CRITICAL | File Lock Check |
| **SC-KMS-REF-002** | **Indirect Access**: Elixir MUST access KMS data exclusively via the `CepafKmsClient`. Direct Ecto/Exqlite usage is FORBIDDEN. | CRITICAL | Static Analysis |
| **SC-KMS-REF-003** | **Type Safety**: All IPC messages MUST be validated against a shared schema (JSON Schema or rigid F# types). | HIGH | Runtime Check |
| **SC-KMS-REF-004** | **Fallibility**: The Elixir client MUST handle Cortex unavailability gracefully (Circuit Breaker). | CRITICAL | Chaos Testing |
| **SC-KMS-REF-005** | **Atomic Transition**: The migration MUST be atomic per-domain to prevent data corruption. | HIGH | Migration Script |

---

## 3.0 Agent Operating Rules (AOR-KMS)

| ID | Formal Logic | Natural Language |
|----|--------------|------------------|
| **AOR-KMS-001** | $\mathbf{F}(\text{Elixir}, \text{DirectDB})$ | Elixir Agent SHALL NOT write code that opens SQLite connections to KMS. |
| **AOR-KMS-002** | $\mathbf{O}(\text{Logic}, \text{MoveToF#})$ | Business logic for Holons/Todos MUST be ported to F#, not just the SQL queries. |
| **AOR-KMS-003** | $\mathbf{O}(\text{Interface}, \text{Explicit})$ | Every KMS operation MUST have a distinct command in the F# CLI. |

---

## 4.0 Implementation Plan (Homeostasis Preserved)

### Phase 1: Cortex Capability Expansion (F#)
1.  Implement `Kms.Holon`, `Kms.Vector`, `Kms.Event` modules in F#.
2.  Add SQLite/DuckDB access layers in F# (`Microsoft.Data.Sqlite`).
3.  Expose these via `Cepaf.Podman` CLI (e.g., `kms get-holon`, `kms search`).

### Phase 2: The Synapse Bridge (Elixir)
1.  Create `Indrajaal.KMS.Client` (GenServer).
2.  Implement `Indrajaal.KMS.Client.get_holon/1`, etc., wrapping the CLI calls.
3.  Add caching/telemetry to the Client.

### Phase 3: The Lobotomy (Elixir Refactor)
1.  Identify `Indrajaal.KMS` call sites.
2.  Replace `Indrajaal.KMS.SQLite.get_holon/2` with `Indrajaal.KMS.Client.get_holon/1`.
3.  **Verify** functionality after each replacement.

### Phase 4: Verification & Cleanup
1.  Run full test suite.
2.  Delete `lib/indrajaal/kms/sqlite.ex`, `todos.ex`, etc.
3.  Remove Ecto/Exqlite dependencies related to KMS.

---

## 5.0 SIL-6 Extensions
- **Formal Verification**: The F# KMS logic MUST be verified (Quint/Agda) as it is now the "Brain".
- **Immutable Audit**: All F# KMS writes MUST be logged to the Immutable Register.
