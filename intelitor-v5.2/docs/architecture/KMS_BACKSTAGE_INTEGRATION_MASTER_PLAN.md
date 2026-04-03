# INDRAJAAL KMS-BACKSTAGE CONVERGENCE: MASTER ARCHITECTURE
**Version**: 2.0.0-SIL6
**Target**: `lib/cepaf/src/Cepaf.KmsCatalog` (New Module)
**Language**: F# (net10.0)
**Compliance**: SIL-6, Biomorphic Mesh

---

## 1.0 Product Review: Backstage Software Catalog
**Backstage** provides a centralized system of record for software.
*   **Core Entity**: The `Entity` (Component, API, Resource, etc.).
*   **Source of Truth**: `catalog-info.yaml` stored in Git.
*   **Graph**: Implicit relationships via `owner`, `system`, `dependsOn`.
*   **Gap**: Backstage is a *metadata* store. It does not natively verify if the software is actually *running* or complying with runtime safety constraints (STAMP).

## 2.0 Product Review: Indrajaal KMS
**Indrajaal KMS** (`lib/indrajaal/kms`) is a Holonic Knowledge Engine.
*   **Core Entity**: The `Holon` (UUID, FQUN, Payload, Vital Signs).
*   **Storage**: SQLite (OLTP) + DuckDB (OLAP) + Vectors.
*   **Gap**: Lacks higher-level "Software Catalog" schemas. It treats everything as a generic Holon. It lacks an automated harvester for `catalog-info.yaml`.

## 3.0 The 8-Degree Integration Plan
We will implement the Backstage Model *inside* the Indrajaal KMS using F# for high-assurance data processing.

| Degree | Component | Responsibility | Implementation (F#) |
|---|---|---|---|
| **1** | **Domain Model** | Strict F# Types matching Backstage Entities | `CatalogDomain.fs` |
| **2** | **Ingestor** | YAML Parsing & Validation (GitOps) | `CatalogIngestor.fs` |
| **3** | **Persistence** | Mapping F# Types to KMS SQLite Holons | `HolonMapper.fs` |
| **4** | **Runtime Link** | Binding Podman/K8s State to Catalog Entities | `RuntimeBinder.fs` |
| **5** | **Topology** | Materializing Dependency Graphs (Edges) | `GraphBuilder.fs` |
| **6** | **Scorecard** | Compliance & Quality Scoring | `Scorecard.fs` |
| **7** | **Discovery** | Vector Search & TechDocs Indexing | `SearchIndexer.fs` |
| **8** | **Federation** | Zenoh-based Mesh Replication | `MeshCatalog.fs` |

---

## 4.0 "5 Runs" Hardening Strategy
We will execute the implementation in 5 hardening runs to ensure SIL-6 compliance.

*   **Run 1 (Foundation)**: Define the immutable Domain Logic and Types.
*   **Run 2 (IO & Parsing)**: Implement the robust YAML Ingestor with error recovery.
*   **Run 3 (Data Integrity)**: Implement the SQLite/Holon persistence layer with transaction safety.
*   **Run 4 (Reality Binding)**: Implement the Runtime Binder to detect "Ghost Services".
*   **Run 5 (Distribution)**: Implement the Zenoh Federation layer for mesh availability.

---

## 5.0 Architecture & Impact
*   **L1 (Code)**: New F# Project `Cepaf.KmsCatalog`.
*   **L3 (Component)**: Replaces Node.js Backstage backend with native F# binary.
*   **L6 (Cluster)**: Catalog state is replicated to every Mesh node via Zenoh.
*   **L7 (Federation)**: Global service discovery without central point of failure.

