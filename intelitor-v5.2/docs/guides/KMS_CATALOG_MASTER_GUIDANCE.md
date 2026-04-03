# KMS CATALOG: MASTER GUIDANCE & LIFECYCLE MANAGEMENT
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Project**: Indrajaal KMS (Backstage Re-platforming)
**Compliance**: SIL-6 Biomorphic Fractal Mesh

---

## 1.0 THE PHILOSOPHY: FROM METADATA TO CONTROL PLANE
Traditional developer portals like Backstage are passive "Phonebooks" for services. The **Indrajaal KMS Catalog** is an **Active Control Plane**. 

*   **Verifiable**: Every entry is cryptographically signed via the Unified Checkpoint Registry (UCR).
*   **Aware**: It knows the live status of Podman/K8s pods via the Runtime Binder.
*   **Resilient**: It is distributed across the Mesh via Zenoh federation.

---

## 2.0 ARCHITECTURAL FOUNDATION
The system is built on an **8-Degree Integration Plan**, moving from simple types to global mesh replication.

1.  **Domain**: Strict F# types for Entities.
2.  **Harvester**: Automated `catalog-info.yaml` discovery.
3.  **Graph**: Explicit materialization of `dependsOn` and `ownedBy` relationships.
4.  **Runtime**: Binding live container state to static metadata.
5.  **Scaffolder**: Golden-path service generation using F# templates.
6.  **Indexer**: TechDocs indexing into the KMS Vector Store.
7.  **Scorecard**: Automated architectural quality grading.
8.  **Mesh**: Distributed state replication via Zenoh.

---

## 3.0 GETTING STARTED (ENVIRONMENT BOOT)

### 3.1 Development Mode (Level 1)
Use the local setup script to boot the Catalog Daemon alongside your databases.
```bash
elixir scripts/env/dev-start.exs
```
*   This starts the `kms-catalog` container.
*   It mounts `./data/kms` so your local CLI tools and the containerized daemon share the same state.

### 3.2 Testing Mode (Level 2)
Verify the distributed behavior using the 3-node testing cluster.
```bash
podman-compose -f podman-compose-testing.yml up -d
```
*   KMS Catalog is reachable at `172.31.0.40`.

### 3.3 Fractal Mesh Mode (Level 5)
Deploy to the full biomorphic mesh with Zenoh enabled.
```bash
podman-compose -f podman-compose-fractal-mesh.yml up -d
```

---

## 4.0 THE DEVELOPER WORKFLOW

### 4.1 Create: The Scaffolder
Standardize your architecture by generating services from templates.
```bash
# List templates
sa-scaffold list

# Run a template
sa-scaffold run go-service --params '{"name":"auth-v2", "owner":"security"}'
```

### 4.2 Register: The Harvester
The system automatically scans repositories for `catalog-info.yaml`. To manually trigger or validate:
```bash
sa-catalog validate ./my-repo/catalog-info.yaml
sa-catalog register https://github.com/org/repo/blob/main/catalog-info.yaml
```

### 4.3 Discover: Unified Search
Search across the Catalog (Metadata), TechDocs (Content), and Vectors (Semantic).
```bash
sa-search query "user authentication"
sa-docs read user-service
```

---

## 5.0 THE SAFETY LAYER (UCR & AUDIT)
Every mutation (Ingest, Scaffold, Rename) generates a **Checkpoint**.

1.  **Creation**: `CheckpointAdapter` hashes the entity.
2.  **Lineage**: The `previous_hash` ensures state cannot be tampered with.
3.  **Verification**: The `sa-catalog verify <ref>` command compares current SQLite state against the immutable UCR ledger.

---

## 6.0 THE OBSERVABILITY LAYER (RUNTIME BINDING)
The Catalog provides a "Single Pane of Glass" for both static and dynamic state.

*   **Metadata**: "This service should be owned by Team A."
*   **Runtime**: "This service is currently running 3 Pods in the `prod` namespace."
*   **Drift Detection**: If Metadata exists but Runtime does not, the **Compliance Score** (Degree 7) drops automatically.

```bash
# View live pod status for an entity
sa-k8s pods --entity component:default/my-service
```

---

## 7.0 COCKPIT GUI
For non-CLI users, the **Desktop Cockpit** (Avalonia/F#) provides:
*   **Visual Graph**: An interactive map of your microservices.
*   **Status Indicators**: Green/Red lights based on real-time binding.
*   **Wizard**: A step-by-step UI for the Scaffolder.

```bash
# Start the Cockpit
dotnet run --project lib/cepaf/src/Cepaf.Cockpit/Cepaf.Cockpit.fsproj
```

---

## 8.0 COMMAND CHEAT SHEET

| Command | Description |
| :--- | :--- |
| `sa-catalog list` | List all software entities. |
| `sa-catalog show <ref>` | View metadata and vital signs. |
| `sa-catalog graph <ref>` | Show dependencies in CLI format. |
| `sa-scaffold run <temp>` | Create a new project. |
| `sa-docs search "<q>"` | Semantic search through markdown docs. |
| `sa-k8s pods --entity <e>` | Check live Kubernetes health. |
| `sa-cost show <ref>` | View cloud spend for a service. |
| `sa-catalog errors` | View YAML parsing/ingestion failures. |

---

## 9.0 Related Documents
- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- KMS_CATALOG_DEVELOPER_GUIDE.md - Developer workflows
- SIL6_MESH_CLI_USER_GUIDE.md - Mesh operations
- OPERATIONAL_RUNBOOK.md - Operating procedures

---
**Guidance Compiled By**: Gemini Cybernetic Architect
**System Integrity**: VERIFIED SIL-6
