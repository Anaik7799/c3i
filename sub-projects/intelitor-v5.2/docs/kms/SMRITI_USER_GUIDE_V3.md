# SMRITI User Guide (v3)

This guide provides instructions for interacting with the SMRITI.

---

## 1. Core Concepts

*   **Holon**: A single unit of knowledge.
*   **Immortality**: The protocol ensuring data survival.
*   **Federation**: The protocol for syncing data between nodes.

---

## 2. Using the `devenv` Commands

The following commands are available in your shell after running `devenv shell`.

| Command | Description |
| :--- | :--- |
| `smriti-status` | View the current health and metrics of the SMRITI. |
| `smriti-ingest <path>` | Ingest all documents from a given path. |
| `smriti-search "<query>"` | Perform a full-text search across the knowledge base. |
| `smriti-verify` | Run the 8-level fractal integration verifier. |
| `smriti-export --format <fmt>` | Export the knowledge base to a specific format (`json`, `markdown`, etc.). |
| `smriti-immortality` | Manually trigger the Immortality Protocol. |

### Example Workflow

1.  **Check the status of the system:**
    ```bash
    smriti-status
    ```

2.  **Ingest new architecture documents:**
    ```bash
    smriti-ingest docs/architecture
    ```

3.  **Search for information on the OODA loop:**
    ```bash
    smriti-search "OODA loop"
    ```

4.  **Manually create a survival backup:**
    ```bash
    smriti-immortality
    ```
---

## 3. Advanced Features

*   **Autonomous Health**: The Knowledge Agent runs automatically, monitoring system health. View its logs to see its actions.
*   **Federated Sync**: If you are running a multi-node cluster, SMRITI instances will automatically sync with each other. Use `smriti-status` to see peer information.
