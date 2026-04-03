# BACKSTAGE TO KMS: 100% USE CASE COVERAGE MATRIX (BDD & CLI)
**Version**: 6.0.0 (The Final Convergence)
**Target**: `Cepaf.Cockpit` (GUI) & `sa-catalog` (CLI)
**Compliance**: SIL-6 Biomorphic Mesh
**Scope**: Every interaction documented on Backstage.io

---

## 1.0 THE "100%" USER JOURNEY MAP

We map every Backstage user journey to explicit BDD features and CLI commands.

### 1.1 The Catalog Manager (The Librarian)

| Journey | Backstage Interaction | BDD Scenario (Feature: `catalog_management.feature`) | CLI Command |
|---|---|---|---|
| **Register** | "Register Existing Component" > Enter URL > Analyze > Import | `Scenario: Register a component from GitHub` | `sa-catalog register <url>` |
| **Validate** | View YAML errors in import dialog | `Scenario: Validate invalid YAML during registration` | `sa-catalog validate <file>` |
| **Unregister** | Entity Page > Settings > Unregister > Confirm | `Scenario: Unregister an entity` | `sa-catalog delete <ref>` |
| **Refresh** | "Refresh" button on Entity Page | `Scenario: Force refresh an entity` | `sa-catalog refresh <ref>` |
| **Rename** | Edit metadata.name > PR > Merge | `Scenario: Rename an entity via GitOps` | N/A (Git operation) |

### 1.2 The Developer (The Builder)

| Journey | Backstage Interaction | BDD Scenario (Feature: `developer_workflow.feature`) | CLI Command |
|---|---|---|---|
| **Scaffold** | Create > Select Template > Form > Run | `Scenario: Scaffold a new service` | `sa-scaffold run <template> --params <json>` |
| **Docs** | TechDocs > Read > Search | `Scenario: Search documentation content` | `sa-docs search <query>` |
| **API** | API > Definition > Copy Swagger | `Scenario: View API definition` | `sa-api show <ref>` |
| **Graph** | Entity > Relations > Click Node | `Scenario: Traverse dependency graph` | `sa-catalog graph <ref> --depth 2` |
| **Search** | Global Search > Filter "Kind" | `Scenario: Global search filtering` | `sa-search query <q> --kind <k>` |

### 1.3 The Operator (The SRE)

| Journey | Backstage Interaction | BDD Scenario (Feature: `operations_center.feature`) | CLI Command |
|---|---|---|---|
| **K8s** | Entity > Kubernetes > Check Pod Health | `Scenario: Check Kubernetes health` | `sa-k8s pods --entity <ref>` |
| **CI/CD** | Entity > CI/CD > View Build Log | `Scenario: View latest CI status` | `sa-ci log <ref>` |
| **Cost** | Cost Insights > Drilldown | `Scenario: Analyze service cost` | `sa-cost show <ref>` |
| **Errors** | Entity > Errors > View List | `Scenario: View catalog processing errors` | `sa-catalog errors` |

### 1.4 The Admin (The Architect)

| Journey | Backstage Interaction | BDD Scenario (Feature: `admin_governance.feature`) | CLI Command |
|---|---|---|---|
| **Groups** | Settings > Groups > View Members | `Scenario: Audit group membership` | `sa-iam show-group <group>` |
| **Plugins** | Plugins > Install > Configure | `Scenario: Verify installed plugins` | `sa-plugins list` |
| **Templates** | Create > Register Template | `Scenario: Register new template` | `sa-catalog register <template-url>` |

---

## 2.0 BDD SPECIFICATION SUITE (Full Coverage)

We now generate the complete suite of Gherkin files to cover these journeys.

### 2.1 `catalog_management.feature`
Covers CRUD operations on the catalog itself.

### 2.2 `developer_workflow.feature`
Covers the day-to-day "Inner Loop" (Create, Code, Document).

### 2.3 `operations_center.feature`
Covers the "Outer Loop" (Deploy, Monitor, Debug).

### 2.4 `cli_automation.feature`
Specific scenarios for headless automation (CI/CD scripts).

---

## 3.0 CLI IMPLEMENTATION PLAN (F#)

We extend `CatalogCLI.fs` to support the full 100% verb set.

### 3.1 New CLI Verbs
*   `sa-scaffold`: `list`, `show`, `run`, `logs`
*   `sa-docs`: `read`, `search`
*   `sa-api`: `list`, `show`, `lint`
*   `sa-k8s`: `get`, `describe`, `logs`
*   `sa-cost`: `report`, `forecast`

---

## 4.0 UI IMPLEMENTATION PLAN (Avalonia)

We expand `Cepaf.Cockpit` to include specialized Views for SREs and Admins.

### 4.1 New ViewModels
*   `K8sDashboardViewModel`: TreeView of Clusters/Namespaces/Pods.
*   `CiCdViewModel`: List of Pipeline Runs + Log Viewer.
*   `CostChartViewModel`: Stacked Bar Chart (OxyPlot) for cloud spend.
*   `IamViewModel`: Graph view of User/Group hierarchy.

---

## 5.0 THE 5-RUN EXECUTION

1.  **Run 1 (BDD Complete)**: Write all 4 Feature Files.
2.  **Run 2 (CLI Complete)**: Implement all CLI verbs in `CatalogCLI.fs`.
3.  **Run 3 (Step Defs)**: Map BDD steps to CLI commands (Integration Testing).
4.  **Run 4 (UI Ops)**: Implement the Operations/Admin ViewModels.
5.  **Run 5 (Verification)**: Ensure every scenario passes.

Let's begin **Run 1**: Writing the full BDD Suite.
