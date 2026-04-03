# BACKSTAGE TO KMS: GUI & CLI CONVERGENCE MATRIX (7 LEVELS)
**Version**: 4.0.0 (Cockpit Integrated)
**Architecture**: SIL-6 Biomorphic Mesh
**Scope**: 100% Backstage Feature Parity + Cockpit UI/CLI Integration

---

## 1.0 THE UNIFIED FEATURE LIST (GUI & CLI)

We decompose Backstage features and map them to Indrajaal's **Cockpit (Avalonia/F#)** and **CLI (F#)**.

### 1.1 Core Catalog Experience

| L1: Product Feature | L2: UI Capability | L3: CLI Command | L4: F# Module | L5: Data Structure | L6: Logic/Rule | L7: SQLite Storage |
|---|---|---|---|---|---|---|
| **Entity List** | Grid/Table View | `sa-catalog list` | `Cockpit.Catalog.List` | `ObservableCollection<Entity>` | Filter/Sort | `holons` (JSON) |
| **Entity Detail** | Detail Page | `sa-catalog show <ref>` | `Cockpit.Catalog.Detail` | `EntityViewModel` | Relation Traversal | `holons` + `edges` |
| **Relationships** | Graph Visualization | `sa-catalog graph <ref>` | `Cockpit.Graph.Viz` | `GraphLayout` | Force Directed | `edges` |
| **Create** | Wizard/Form | `sa-scaffold run` | `Cockpit.Scaffolder.Wizard` | `JsonSchemaForm` | Schema Validation | `holons` (template) |
| **Register** | URL Import Dialog | `sa-catalog register` | `Cockpit.Catalog.Import` | `UrlValidator` | Regex Check | `holons` (Insert) |

### 1.2 Developer Portal Experience

| L1: Product Feature | L2: UI Capability | L3: CLI Command | L4: F# Module | L5: Data Structure | L6: Logic/Rule | L7: SQLite Storage |
|---|---|---|---|---|---|---|
| **TechDocs** | Markdown Reader | `sa-docs read <ref>` | `Cockpit.TechDocs.Reader` | `FlowDocument` | Markdown->XAML | `holon_vectors` |
| **Search** | Search Bar + Results | `sa-search query <q>` | `Cockpit.Search.Bar` | `SearchResultItem` | Fuzzy Match | `fts5` |
| **Cost** | Cost Dashboard | `sa-cost report` | `Cockpit.Cost.Chart` | `OxyPlot.Series` | Aggregation | `holons` (metric) |
| **API** | Swagger UI | `sa-api render <ref>` | `Cockpit.Api.Swagger` | `OpenApiDocument` | Spec Parsing | `blobs` |

### 1.3 Infrastructure Experience

| L1: Product Feature | L2: UI Capability | L3: CLI Command | L4: F# Module | L5: Data Structure | L6: Logic/Rule | L7: SQLite Storage |
|---|---|---|---|---|---|---|
| **Kubernetes** | Cluster Status View | `sa-k8s pods` | `Cockpit.K8s.Dashboard` | `PodViewModel` | Label Match | `vital_signs` |
| **Podman** | Container List | `sa-podman ps` | `Cockpit.Podman.List` | `ContainerRow` | CLI Parse | `vital_signs` |
| **Log Stream** | Live Console | `sa-logs tail <ref>` | `Cockpit.Logs.Stream` | `LogLine` | Buffer/Ring | `task_logs` |

---

## 2.0 THE 8-DEGREE INTEGRATION PLAN (UI/CLI Focus)

This plan integrates the backend logic (previous runs) into the user-facing **Cockpit**.

### Degree 1: CLI Catalog Commands (F#)
**Objective**: Expose the Catalog Domain via the `sa` CLI tool.
*   **Action**: `Cepaf.KmsCatalog.CLI.fs`
*   **Commands**: `list`, `show`, `graph`, `register`.

### Degree 2: Cockpit Catalog UI (Avalonia)
**Objective**: Create a DataGrid view for Entities in the Desktop App.
*   **Action**: `Cepaf.Cockpit/CatalogView.fs`
*   **Components**: Search bar, Kind filter, Owner filter, Entity Table.

### Degree 3: The Graph Visualizer (Avalonia)
**Objective**: Render the dependency graph visually.
*   **Action**: `Cepaf.Cockpit/GraphView.fs`
*   **Library**: `Avalonia.Controls.Graph` (or custom canvas drawing).

### Degree 4: Scaffolding Wizard (UI/CLI)
**Objective**: Interactive form for creating new components.
*   **Action**: `Cepaf.Cockpit/ScaffolderWizard.fs`
*   **Logic**: Dynamically generate UI inputs based on the Template's `spec.parameters` (JSON Schema).

### Degree 5: TechDocs Reader (UI)
**Objective**: Native Markdown rendering within the Cockpit.
*   **Action**: `Cepaf.Cockpit/TechDocsView.fs`
*   **Logic**: Render Markdown directly to Avalonia FlowDocument.

### Degree 6: Runtime Dashboard (K8s/Podman)
**Objective**: Live view of running resources linked to entities.
*   **Action**: `Cepaf.Cockpit/RuntimeView.fs`
*   **Logic**: Poll `RuntimeBinder` and update UI via Reactive Bindings (Elmish/ReactiveUI).

### Degree 7: Cost & API Insights (UI)
**Objective**: Charts for costs, Swagger UI for APIs.
*   **Action**: `Cepaf.Cockpit/InsightsView.fs`
*   **Library**: `OxyPlot` for charts.

### Degree 8: Unified Search (Global Bar)
**Objective**: Ctrl+P style global search.
*   **Action**: `Cepaf.Cockpit/GlobalSearch.fs`
*   **Logic**: Query `Search.fs` backend, display mixed results (Entities + Docs).

---

## 3.0 HARDENING STRATEGY (5 RUNS)

1.  **Run 1 (CLI Foundation)**: Implement the core CLI verbs (`list`, `show`) connecting to the Catalog Domain.
2.  **Run 2 (UI Foundation)**: Build the basic Avalonia View Models for the Catalog.
3.  **Run 3 (Scaffolder)**: Implement the Interactive CLI and UI Wizard for Templates.
4.  **Run 4 (Visuals)**: Implement Graph and TechDocs rendering.
5.  **Run 5 (Runtime)**: Connect the Live Dashboard (K8s/Podman) to the UI.

---

## 4.0 IMPLEMENTATION ARCHITECTURE (F#)

We will now generate the F# modules for the **CLI** and **Cockpit UI Integration**.

### 4.1 Module: `CatalogCLI.fs` (Degree 1)
*   **Role**: Command-line interface logic.
*   **Dependencies**: `System.CommandLine`.

### 4.2 Module: `CatalogViewModels.fs` (Degree 2)
*   **Role**: MVVM/Elmish state for the UI.
*   **Dependencies**: `Avalonia`, `ReactiveUI`.

### 4.3 Module: `ScaffolderWizard.fs` (Degree 4)
*   **Role**: Dynamic form generation.

### 4.4 Module: `RuntimeDashboard.fs` (Degree 6)
*   **Role**: Live status monitoring view.

