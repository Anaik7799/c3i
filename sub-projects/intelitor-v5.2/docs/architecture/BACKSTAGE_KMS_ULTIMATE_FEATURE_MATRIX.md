# BACKSTAGE TO KMS: THE ULTIMATE FEATURE MATRIX (7 LEVELS)
**Version**: 3.0.0 (Hardened)
**Architecture**: SIL-6 Biomorphic Mesh
**Scope**: 100% Backstage Website Feature Parity

---

## 1.0 CORE CATALOG FEATURES

| L1: Product Feature | L2: Module | L3: User Capability | L4: System Operation | L5: F# Implementation | L6: Data Structure | L7: SQLite Storage |
|---|---|---|---|---|---|---|
| **Software Catalog** | **Entity Model** | Define Component | Parse `catalog-info.yaml` | `Ingestor.parse` | `CatalogEntity` | `holons` (JSON) |
| | | Define API | Store IDL (OpenAPI) | `ApiExplorer.ingest` | `ApiSpec` | `holons` + `blobs` |
| | | Define System | Group Components | `Graph.linkSystem` | `SystemSpec` | `edges` (partOf) |
| | | Define Domain | Group Systems | `Graph.linkDomain` | `DomainSpec` | `edges` (partOf) |
| | | Define Resource | Track Infrastructure | `Runtime.bindResource` | `ResourceSpec` | `holons` + `vital_signs` |
| | **Discovery** | Search Catalog | Full-text Filter | `Search.query` | `IndexEntry` | `holon_search_index` (FTS5) |
| | | Filter by Owner | Graph Traversal | `Graph.getOwnedBy` | `Edge` | `edges` (ownedBy) |
| | | Filter by Lifecycle | Attribute Filter | `Catalog.filter` | `Lifecycle` | `holons.payload` |
| | **Visualization** | Dependency Graph | View Topology | `Graph.traverse` | `AdjacencyMatrix` | `edges` |
| | | API Explorer | View Swagger UI | `ApiExplorer.render` | `HtmlFragment` | N/A (Generated) |

## 2.0 DEVELOPER PORTAL FEATURES

| L1: Product Feature | L2: Module | L3: User Capability | L4: System Operation | L5: F# Implementation | L6: Data Structure | L7: SQLite Storage |
|---|---|---|---|---|---|---|
| **Scaffolder** | **Templates** | Create Component | Render Template | `Scaffolder.execute` | `TemplateSpec` | `holons` (template) |
| | **Actions** | Publish to Git | Git Commit/Push | `Scaffolder.publish` | `GitAction` | N/A |
| | **Tasks** | View Logs | Stream Output | `TaskLog.stream` | `LogEntry` | `task_logs` |
| **TechDocs** | **Documentation** | Read Docs | Render Markdown | `TechDocs.render` | `DocPage` | `holon_vectors` |
| | **Search** | Search Docs | Semantic Search | `Search.vectorQuery` | `Embedding` | `holon_vectors` |
| **Cost Insights** | **Metrics** | View Cloud Cost | Aggregation | `Cost.calculate` | `CostMetric` | `holons` (metric) |
| **Search Platform** | **Unified Search** | Search Everything | Collate Results | `Search.unified` | `SearchResult` | N/A (Aggregated) |

## 3.0 RUNTIME & INFRASTRUCTURE

| L1: Product Feature | L2: Module | L3: User Capability | L4: System Operation | L5: F# Implementation | L6: Data Structure | L7: SQLite Storage |
|---|---|---|---|---|---|---|
| **Kubernetes** | **Cluster View** | View Pods | K8s API Poll | `K8sBridge.sync` | `PodStatus` | `vital_signs` |
| | **Health** | Check Status | Health Probing | `Runtime.check` | `HealthState` | `vital_signs` |
| **Podman** | **Container View** | View Containers | CLI Inspection | `PodmanBridge.sync` | `ContainerInfo` | `vital_signs` |

---

## 4.0 INTEGRATION PLAN (5 RUNS TO HARDEN)

To achieve this level of fidelity, the F# implementation must be significantly expanded.

### Run 1: Domain Expansion (Completed in Draft, Hardening Now)
**Objective**: Expand `CatalogDomain.fs` to include `Cost`, `Search`, and `Plugin` types.
**Status**: UPGRADING.

### Run 2: Search & Indexing (New Module)
**Objective**: Implement `Search.fs` to handle both FTS (SQLite) and Semantic (Vector) search, unifying Catalog and TechDocs.
**Status**: CREATING.

### Run 3: API & Cost Intelligence (New Modules)
**Objective**: Implement `ApiExplorer.fs` (IDL parsing) and `CostInsights.fs` (Metric aggregation).
**Status**: CREATING.

### Run 4: Runtime Reality Binding (Refining)
**Objective**: Harden `RuntimeBinder.fs` to support multi-cluster K8s and detailed Podman stats.
**Status**: HARDENING.

### Run 5: The Federated Mesh (Completion)
**Objective**: Ensure all these features replicate via Zenoh.
**Status**: INTEGRATING.

---

## 5.0 MAPPING TO INDRAJAAL

| Backstage | Indrajaal F# |
|---|---|
| **Catalog** | `Cepaf.KmsCatalog.Domain` + `Ingestor` |
| **Scaffolder** | `Cepaf.KmsCatalog.Scaffolder` |
| **TechDocs** | `Cepaf.KmsCatalog.TechDocs` |
| **Search** | `Cepaf.KmsCatalog.Search` (New) |
| **Cost Insights** | `Cepaf.KmsCatalog.CostInsights` (New) |
| **Kubernetes** | `Cepaf.KmsCatalog.KubernetesBridge` |
| **API Docs** | `Cepaf.KmsCatalog.ApiExplorer` (New) |

