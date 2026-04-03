# BACKSTAGE TO KMS: DEEP FEATURE MAPPING & ARCHITECTURE
**Version**: 2.1.0
**Target**: `Indrajaal.KMS` (F# Implementation)
**Scope**: Full feature parity with Backstage.io
**Depth**: 7 Levels of Granularity

---

## 1.0 THE 7-LEVEL FEATURE DECOMPOSITION

We analyze Backstage features from high-level capability down to storage bytes, mapping each to the Indrajaal KMS equivalent.

### 1.1 Core Catalog (The Brain)

| L1: Category | L2: Feature | L3: Component | L4: Operation | L5: Data Point | L6: Logic/Rule | L7: KMS Storage (SQLite) |
|---|---|---|---|---|---|---|
| **Catalog** | **Entity Model** | Domain Definition | Definition | `kind` | `Enum(Component|API|...)` | `holons.type` (VARCHAR) |
| | | Identity | Identification | `metadata.uid` | UUID v4 Generator | `holons.id` (TEXT PK) |
| | | Naming | Addressing | `metadata.namespace` | Default='default' | `holons.fqun` (TEXT UNIQUE) |
| | | | | `metadata.name` | Regex `[a-z0-9-]+` | Substring of FQUN |
| | **Metadata** | Taxonomy | Tagging | `metadata.tags` | List<String> | `holons.payload.tags` (JSON) |
| | | Decoration | Annotation | `metadata.annotations` | Map<String,String> | `holons.payload.annotations` |
| | | Hypermedia | Linking | `metadata.links` | List<{url, title, icon}> | `holons.payload.links` |
| | **Graph** | Ownership | Owner Linking | `spec.owner` | Ref -> Group/User | `edges` (relation='ownedBy') |
| | | Hierarchy | System Linking | `spec.system` | Ref -> System | `edges` (relation='partOf') |
| | | Dependency | Service Linking | `spec.dependsOn` | List<Ref> | `edges` (relation='dependsOn') |
| | | Interface | API Linking | `spec.providesApis` | List<Ref> | `edges` (relation='providesApi') |
| | **Ingestion** | GitOps | Discovery | `catalog-info.yaml` | Recursive Scan | N/A (Ephemeral Process) |
| | | Processing | Validation | `apiVersion` | "backstage.io/v1alpha1" | `holons.payload.api_version` |

### 1.2 Scaffolder (The Factory)

| L1: Category | L2: Feature | L3: Component | L4: Operation | L5: Data Point | L6: Logic/Rule | L7: KMS Storage |
|---|---|---|---|---|---|---|
| **Scaffolder** | **Templates** | Schema | Definition | `kind: Template` | Entity Filtering | `holons.type='template'` |
| | | Parameterization | Input Form | `spec.parameters` | JSON Schema Draft-7 | `holons.payload.parameters` |
| | | Execution | Steps | `spec.steps` | Ordered List | `holons.payload.steps` |
| | **Actions** | Fetch | Cloning | `fetch:template` | Git Clone + Render | N/A (Runtime) |
| | | Publish | Pushing | `publish:github` | Git Commit + Push | N/A (Runtime) |
| | | Register | Cataloging | `catalog:register` | HTTP POST /catalog | `holons` (Insert) |

### 1.3 TechDocs (The Library)

| L1: Category | L2: Feature | L3: Component | L4: Operation | L5: Data Point | L6: Logic/Rule | L7: KMS Storage |
|---|---|---|---|---|---|---|
| **TechDocs** | **Docs-as-Code** | Source | Location | `backstage.io/techdocs-ref` | 'dir:.' or 'url:...' | `holons.payload.annotations` |
| | **Rendering** | MkDocs | Build | `mkdocs.yaml` | Container Execution | N/A (Artifact) |
| | **Storage** | Persistence | Caching | Generated HTML | S3/GCS/Local | `blob_store` (Future) |
| | **Search** | Indexing | Retrieval | Full Text | TF-IDF / Vector | `holon_vectors` |

### 1.4 Kubernetes (The Nervous System)

| L1: Category | L2: Feature | L3: Component | L4: Operation | L5: Data Point | L6: Logic/Rule | L7: KMS Storage |
|---|---|---|---|---|---|---|
| **Runtime** | **Discovery** | Mapping | Label Match | `backstage.io/kubernetes-id` | Label Selector | `holons.vital_signs` |
| | **State** | Status | Inspection | `status.phase` | Running/Failed | `holons.vital_signs.health` |
| | **Topology** | Hierarchy | Tree View | Pod -> ReplicaSet -> Deploy | Parent/Child | `edges` (relation='runtime') |

---

## 2.0 THE 8-DEGREE INTEGRATION PLAN (Refined)

### Degree 1: Domain Isomorphism (F#)
Create a strict F# type system that represents the union of Backstage Entities and Indrajaal Holons.
*   **Action**: `Cepaf.KmsCatalog.Domain.fs`
*   **Result**: Compile-time guarantee of catalog schema validity.

### Degree 2: The Universal Harvester (F#)
A configurable ingestion engine that supports:
1.  **Git**: GitHub, GitLab, BitBucket.
2.  **Filesystem**: Local `catalog-info.yaml` (for Monorepos).
3.  **Processors**: Custom logic to enrich entities during ingestion.
*   **Action**: `Cepaf.KmsCatalog.Ingestor.fs`

### Degree 3: The Topological Graph Builder (F#)
Logic to materialize the implicit relationships in YAML into explicit Graph Edges in SQLite.
*   **Action**: `Cepaf.KmsCatalog.Graph.fs`
*   **Logic**: `(Entity A) --[owner]--> (Group B)` implies `INSERT INTO edges...`

### Degree 4: The Runtime Symbiont (F#)
A bidirectional link between Catalog and Infrastructure.
*   **Action**: `Cepaf.KmsCatalog.Runtime.fs`
*   **Logic**: Query Podman/K8s -> Find matching Holon -> Update `vital_signs` -> Calculate Health.

### Degree 5: The Template Engine (F#)
A replacement for Backstage's Node.js Scaffolder using **Scriban**.
*   **Action**: `Cepaf.KmsCatalog.Scaffolder.fs`
*   **Logic**: `Render(template_dir, params) -> Output(target_dir)`.

### Degree 6: The Knowledge Indexer (F#)
TechDocs integration via Markdown parsing and Vector embedding.
*   **Action**: `Cepaf.KmsCatalog.TechDocs.fs`
*   **Logic**: Parse `*.md` -> Split Chunks -> Embedding API -> `holon_vectors`.

### Degree 7: The Compliance Sentinel (F#)
Automated "Scorecards" running as background agents.
*   **Action**: `Cepaf.KmsCatalog.Scorecard.fs`
*   **Logic**: `Score = (HasOwner * 0.3) + (HasDocs * 0.2) + (CI_Passing * 0.5)`.

### Degree 8: Mesh Federation (F#)
Replicating the catalog across the SIL-6 Mesh using Zenoh.
*   **Action**: `Cepaf.KmsCatalog.Federation.fs`
*   **Logic**: `Pub(Entity) -> Sub(Edge Nodes) -> Local Cache`.

---

## 3.0 HARDENING STRATEGY (5 RUNS)

We execute the implementation in 5 progressively stricter "Runs".

1.  **Run 1 (Types)**: Define the immutable Domain Logic. (Done)
2.  **Run 2 (IO)**: Implement robust YAML parsing with error recovery. (Done)
3.  **Run 3 (Persistence)**: Transactional SQLite storage for Holons/Edges. (Done)
4.  **Run 4 (Reality)**: Bind Runtime state (Podman) to Metadata. (Done)
5.  **Run 5 (Expansion)**: Add Scaffolding, TechDocs, and Scorecards. (**CURRENT GOAL**)

---

## 4.0 IMPLEMENTATION ARCHITECTURE

We will now generate the missing F# modules to complete the 8-Degree Plan.

### 4.1 Module: `Scaffolder.fs`
*   **Dependencies**: `Scriban` (Template Engine).
*   **Function**: Reads `Template` entities, prompts for parameters (mocked), renders files.

### 4.2 Module: `TechDocs.fs`
*   **Dependencies**: `Markdig` (Markdown Parser).
*   **Function**: Scans repository for `mkdocs.yaml`, extracts content for indexing.

### 4.3 Module: `Scorecard.fs`
*   **Function**: Policy engine evaluating entities against rules.

### 4.4 Module: `KubernetesBridge.fs`
*   **Function**: Specialized runtime binder for K8s clusters (simulated for SIL-6).

