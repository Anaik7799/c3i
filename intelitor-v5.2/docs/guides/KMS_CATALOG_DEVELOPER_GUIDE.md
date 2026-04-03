# DEVELOPER GUIDE: USING THE KMS CATALOG (BACKSTAGE REPLACEMENT)
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Target Audience**: Developers, SREs, Architects
**Prerequisites**: `dotnet`, `sa-catalog` CLI, Access to Mesh
**Compliance**: SIL-6 Biomorphic Fractal Mesh

---

## 1.0 INTRODUCTION
The **Indrajaal KMS Catalog** is your central portal for software management. Unlike Backstage (which is just a metadata view), this Catalog is an active control plane that verifies if your services are actually running, safe, and compliant.

## 2.0 DAILY WORKFLOWS

### 2.1 Starting a New Project (The Golden Path)
Stop copying and pasting old projects. Use the Scaffolder to create verified, compliant services instantly.

**Step 1: List Available Templates**
```bash
sa-scaffold list
# Output:
# - react-ssr-template (React Website)
# - go-microservice (Go Backend)
# - elixir-otp-node (Elixir GenServer)
```

**Step 2: Run the Scaffolder**
You can run this interactively or via flags.
```bash
sa-scaffold run react-ssr-template \
  --params '{"name":"my-new-app", "owner":"team-alpha", "description":"Customer Portal"}'
```
*   **What happens?**
    1.  The system clones the golden template.
    2.  It substitutes variables (name, owner).
    3.  It generates a new Git repository.
    4.  It registers the component in the Catalog automatically.
    5.  It commits the initial `catalog-info.yaml`.

### 2.2 Registering an Existing Service
If you have an existing repo, add it to the catalog so it can be managed.

**Step 1: Add Metadata**
Create a `catalog-info.yaml` in your repo root:
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: legacy-payment-api
  description: Handles Stripe payments
spec:
  type: service
  owner: team-payments
  lifecycle: production
```

**Step 2: Register via CLI**
```bash
sa-catalog register https://github.com/my-org/legacy-payment-api/blob/main/catalog-info.yaml
```
*   **Verification**: The system will immediately check if this YAML is valid. If it passes, it is hashed and stored in the Unified Checkpoint Registry (UCR).

### 2.3 Documentation & Discovery
Stop asking "where are the docs?". They are co-located with the code and indexed here.

**Search for Knowledge**
```bash
sa-docs search "JWT authentication"
# Output:
# - auth-service/docs/tokens.md (Score: 0.95)
# - gateway/docs/api-security.md (Score: 0.82)
```

**Read Docs in Terminal**
```bash
sa-docs read auth-service
# Renders the Markdown docs directly in your terminal or opens the local web view.
```

## 3.0 OPERATIONS & SRE WORKFLOWS

### 3.1 Verifying Runtime Health
The catalog doesn't just say a service *exists*; it tells you if it's *alive*.

```bash
sa-k8s pods --entity component:default/my-new-app
# Output:
# POD NAME             STATUS    RESTARTS   AGE
# my-new-app-x82z      Running   0          2h
```
*   If the service is defined in Git but NOT running in K8s, the Catalog will show a **Drift Warning**.

### 3.2 checking Costs
Before deploying a massive change, check the cost trend of your service.

```bash
sa-cost show component:default/data-pipeline
# Output:
# Daily Cost: $45.20
# Trend: UP (+12% vs last week)
```

## 4.0 DESKTOP COCKPIT (GUI)
For a visual experience, launch the desktop app.

```bash
# Launch the GUI
dotnet run --project lib/cepaf/src/Cepaf.Cockpit/Cepaf.Cockpit.fsproj
```

*   **Catalog Tab**: Filter services by Owner, Tag, or Lifecycle.
*   **Graph Tab**: Visualize dependencies (Who calls my API?).
*   **Create Tab**: A visual wizard for the Scaffolder.

## 5.0 CI/CD INTEGRATION
Integrate the Catalog into your pipelines to enforce standards.

**Example: GitHub Actions / Jenkins Step**
```bash
# Fail the build if the catalog-info.yaml is invalid
sa-catalog validate ./catalog-info.yaml

# Fail the build if compliance score is too low
sa-scorecard check --min-score 80
```

## 6.0 ARCHITECTURAL GOVERNANCE
Architects use the Scorecard to drive improvements across hundreds of services.

**View Compliance Report**
```bash
sa-scorecard report --owner team-alpha
# Output:
# - auth-service: 95/100 (A)
# - legacy-api:   40/100 (F) -> Missing README, Missing Owner, No Docs
```

---

## 8.0 Related Documents
- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- KMS_CATALOG_MASTER_GUIDANCE.md - Lifecycle management and philosophy
- SIL6_MESH_CLI_USER_GUIDE.md - Mesh operations
- OPERATIONAL_RUNBOOK.md - Operating procedures

---
**Summary**:
1.  **Scaffold** new work.
2.  **Register** existing work.
3.  **Search** for answers.
4.  **Monitor** health and cost.
5.  **Score** your quality.

```