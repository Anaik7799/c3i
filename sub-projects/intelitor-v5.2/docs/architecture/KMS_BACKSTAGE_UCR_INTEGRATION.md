# BACKSTAGE TO KMS: UNIFIED CHECKPOINT REGISTRY INTEGRATION
**Version**: 1.0.0
**Architecture**: SIL-6 Biomorphic Mesh
**Safety Level**: Critical

---

## 1.0 THE 5 LEVELS OF INTERACTION

To ensure SIL-6 compliance, every interaction with the Software Catalog is mediated by the **Unified Checkpoint Registry (UCR)**.

| Level | Name | Description | UCR Role |
|---|---|---|---|
| **L1** | **Human (HCI)** | Developers using `sa-catalog` or Cockpit UI. | **Actor Identification**: Every CLI command must carry an authenticated Actor ID. |
| **L2** | **Tool (API)** | Scaffolder, TechDocs, CI/CD Agents. | **Operation Classification**: Actions are typed (`Ingestion`, `Scaffold`). |
| **L3** | **Persistence** | SQLite/DuckDB/Vectors. | **Atomic Gatekeeper**: Writes to SQLite are blocked until UCR confirms the Checkpoint commit. |
| **L4** | **Mesh (Federation)** | Zenoh Replication between nodes. | **State Synchronization**: Replicators exchange *Checkpoints* (Merkle Trees), not just raw data, ensuring integrity. |
| **L5** | **Safety (Guardian)** | Formal Verification & Audit. | **Invariant Checking**: The Guardian continuously tails the UCR ledger to detect anomalies or policy violations. |

---

## 2.0 INTEGRATION ARCHITECTURE

The **Safe Catalog Facade** (`SafeCatalog.fs`) is the new entry point for all state mutations.

### 2.1 The Write Path
1.  **Request**: `Ingestor.fs` parses a YAML.
2.  **Checkpointing**: `CheckpointAdapter.createCheckpoint` hashes the entity.
3.  **Validation**: UCR verifies the signature and lineage (PreviousHash).
4.  **Commit**: UCR appends to the immutable ledger (DuckDB/File).
5.  **Apply**: `HolonMapper.upsertHolon` updates the mutable state (SQLite).

### 2.2 The Read Path
*   Reads are **Optimistic** via SQLite for performance.
*   **Vital Signs**: The `vital_signs` column in SQLite stores the `last_checkpoint_id` to allow quick verification against the ledger.

---

## 3.0 UPDATED 8-DEGREE PLAN (Safety Enhanced)

| Degree | Component | UCR Integration |
|---|---|---|
| **1** | **Domain Types** | Added `CheckpointRecord` and `StateHash` types. |
| **2** | **Ingestor** | Now delegates to `SafeCatalog.ingestEntity` instead of raw `HolonMapper`. |
| **3** | **Graph** | Edge creations (`dependsOn`) generate "Relation Checkpoints". |
| **4** | **Runtime** | Runtime binding events (`RuntimeBinder`) generate "Ephemeral Checkpoints" (Audit trail of drift). |
| **5** | **Scaffolder** | Template execution is a "Transaction" of multiple Checkpoints (Repo create + Catalog register). |
| **6** | **Scorecard** | Score updates are signed events in the UCR. |
| **7** | **Search** | Indexing is triggered by UCR Commit events (Async projection). |
| **8** | **Federation** | Zenoh publishes `CheckpointRecord` structs. Edge nodes verify hashes before applying. |

---

## 4.0 FEATURE LIST & UCR MAPPING

| Backstage Feature | Safety Constraint | Implementation |
|---|---|---|
| **Register Component** | `SC-KMS-005`: No anonymous registration. | `SafeCatalog` enforces Actor ID. |
| **Unregister** | `SC-KMS-006`: Non-destructive delete. | UCR records a `Tombstone` checkpoint; SQLite marks `deleted=true`. |
| **Template Run** | `SC-KMS-007`: Traceability. | Scaffolder links the *Output Entity* ID to the *Template* ID in the Checkpoint. |
| **TechDocs Update** | `SC-KMS-008`: Content Integrity. | Doc hashes are stored in UCR to prevent tampering. |

---

## 5.0 IMPLEMENTATION STATUS

*   **`CheckpointDomain.fs`**: Implemented. Defines the immutable record structure.
*   **`CheckpointAdapter.fs`**: Implemented. Hashing and Factory logic.
*   **`SafeCatalog.fs`**: Implemented. The transaction script wrapping SQLite.
*   **`HolonMapper.fs`**: Adjusted to be the "dumb" storage layer.

This architecture ensures that the Indrajaal Catalog is not just a database, but a **Verifiable Ledger of Software State**.
