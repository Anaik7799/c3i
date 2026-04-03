# Z-KMS: The Holographic Knowledge Zettelkasten
## Specification, Design, and Implementation Strategy for a Bio-Morphic Knowledge Engine

**Date**: 2026-01-09
**Architecture**: F# (Giraffe/HTMX) + KMS (DuckDB/SQLite/Vector) + Elixir (Ingestion)
**Context**: Indrajaal v21.3.0

---

## 1. Executive Summary

We aim to transform the static KMS (Knowledge Management System) into a dynamic, web-based **Zettelkasten** (Slip-box). This is not merely a documentation viewer; it is a **Holographic Cognitive Surface** where:
1.  **Humans** navigate knowledge via graph topology and serendipitous discovery.
2.  **Agents** (Claude/Gemini) perform RAG (Retrieval-Augmented Generation) to ground their reasoning.
3.  **The System** introspects its own "State of Truth" to detect drift (Entropy) and trigger self-evolution.

The system will utilize the **F# Web Stack** (Giraffe + HTMX) for high-performance, type-safe rendering, utilizing the existing data substrates (DuckDB/SQLite) created by the Elixir Core.

---

## 2. 8-Level Fractal Analysis

We analyze the Z-KMS across 8 levels of abstraction to ensure it serves all constituents (Human, Agent, System).

### L1: Atomic (The Zettel / The Holon)
*   **Concept**: An atomic unit of knowledge (a Note, a Function, a Requirement).
*   **Implementation**: A Markdown file front-loaded with YAML metadata, or a code block extracted from source.
*   **Bio-morphic Trait**: **DNA**. Every Zettel contains a unique ID (`holon_uuid`) and a cryptographic hash of its content.

### L2: Molecular (The Synapse / The Link)
*   **Concept**: The connection between two atoms.
*   **Implementation**: Bidirectional Links (`[[wiki-links]]`), Semantic Similarity (Vector Cosine Distance), and Structural References (Function calls).
*   **Bio-morphic Trait**: **Neural Pathway**. Links strengthen with traversal (usage metrics).

### L3: Organism (The Cluster / The Topic)
*   **Concept**: Emergent grouping of related Zettels.
*   **Implementation**: Dynamic clustering using GraphBLAS/Community Detection algorithms stored in DuckDB.
*   **Bio-morphic Trait**: **Organ System**. "Authentication" or "Safety" are organs composed of many cellular Zettels.

### L4: Habitat (The Graph / The Context)
*   **Concept**: The navigational space where users/agents explore.
*   **Implementation**: A Force-Directed Graph visualization (Cytoscape.js) rendered via F# Web.
*   **Bio-morphic Trait**: **Spatial Memory**. Users navigate via topology ("It's near the Auth cluster") rather than just hierarchy.

### L5: Ecosystem (The Interface / The Dashboard)
*   **Concept**: The interaction layer for Humans.
*   **Implementation**: **F# Giraffe** server rendering server-side HTML, enhanced with **HTMX** for "SPA-like" fluidity without JS bloat.
*   **Bio-morphic Trait**: **Sensory Cortex**. High-bandwidth visual interface.

### L6: Biosphere (The Agent Interface)
*   **Concept**: The API for AI interaction.
*   **Implementation**: MCP (Model Context Protocol) endpoints (`read_zettel`, `search_vectors`) exposed to Claude/Gemini.
*   **Bio-morphic Trait**: **Telepathy**. Agents "read minds" by querying the Z-KMS vector store directly.

### L7: Evolutionary (Time / Entropy)
*   **Concept**: The lifecycle of knowledge.
*   **Implementation**: **IKE (Indrajaal Knowledge Engine)** calculates "Entropy Scores" based on recency, drift (code vs docs), and test failures.
*   **Bio-morphic Trait**: **Metabolism**. Old, incorrect notes "rot" (visualized as decaying colors); fresh, verified notes "glow".

### L8: Gaia (Self-Correction / Feedback)
*   **Concept**: The loop where the system edits itself.
*   **Implementation**: The **OODA Loop**. If Z-KMS detects a "High Entropy" cluster (confusing docs), it triggers an Agent Job to refactor or clarify.
*   **Bio-morphic Trait**: **Homeostasis**. The system actively maintains the coherence of its own knowledge.

---

## 3. Architecture & Design

### 3.1 The Tech Stack: The "Granite" Stack
We choose **F# + Giraffe + HTMX + SQLite/DuckDB** for maximum performance, type safety, and low latency.

*   **Web Server**: **F# Giraffe** (ASP.NET Core). Functional, fast, runs in the `infra-f#-cepa` track.
*   **View Engine**: **Giraffe.ViewEngine**. HTML defined as F# code (Type-safe HTML).
*   **Interactivity**: **HTMX**. Hypermedia-driven interactions (transclusions, live search) without React/Vue complexity.
*   **Graph Viz**: **Cytoscape.js**. Initialized via HTMX events.
*   **Data Layer**:
    *   **SQLite**: Direct read of `data/kms/holons.db` (The Register).
    *   **DuckDB**: OLAP queries for "Entropy" and "Usage" analytics.
    *   **FileSystem**: Direct read of `docs/` and `lib/` (The Source).

### 3.2 Data Flow Architecture

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  Source Code │─────▶│  IKE (Elixir)│─────▶│  Holon DB    │
│  & Markdown  │      │  (Ingestor)  │      │ (SQLite/Duck)│
└──────────────┘      └──────────────┘      └──────┬───────┘
                                                   │
                                            (Read-Only Access)
                                                   ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│ Human User   │◀────▶│ F# Web App   │◀────▶│ Vector Store │
│ (Browser)    │      │ (Giraffe)    │      │ (Embeddings) │
└──────────────┘      └──────┬───────┘      └──────────────┘
                             │
                      ┌──────▼───────┐
                      │ Agent (AI)   │
                      │ (via MCP)    │
                      └──────────────┘
```

---

## 4. Implementation Strategy

### 4.1 Phase 1: The Reader (Read-Only Zettelkasten)
**Goal**: Visualize existing Markdown and Code as Zettels.

1.  **F# Domain Model**:
    ```fsharp
    type Zettel = {
        Id: Guid
        Title: string
        Content: string // Markdown
        Tags: string list
        Backlinks: Guid list
        Entropy: float
    }
    ```
2.  **KMS Repository**:
    *   Implement `KmsReader` in F# to query `holons.db`.
    *   Implement `MarkdownParser` (using `Markdig`) to render HTML.
3.  **Web Routes**:
    *   `GET /`: The Graph View (Cytoscape).
    *   `GET /z/{id}`: The Zettel View (with backlinks sidebar).
    *   `GET /search?q=...`: HTMX-powered live search.

### 4.2 Phase 2: The Integrator (Code as Knowledge)
**Goal**: Make the codebase browsable as a Knowledge Graph.

1.  **Code Ingestion**: Use `IKE` (Elixir) to parse `ex` and `fs` files.
2.  **Mapping**:
    *   Module = Zettel.
    *   Function = Sub-Zettel (Fragment).
    *   Imports/Calls = Links.
3.  **Visualization**:
    *   When viewing a Concept (e.g., "Authentication"), show the *implementation* files linked to it alongside the documentation.

### 4.3 Phase 3: The Evolutionary (Entropy & Agents)
**Goal**: The system highlights where it is rotting.

1.  **Entropy Calculation**:
    *   DuckDB query: `SELECT drift_score, last_updated FROM metrics WHERE holon_id = ?`.
    *   UI: Color-code nodes (Green = Fresh, Red = Rotting).
2.  **Agent Action**:
    *   "Refactor" Button on Zettel UI.
    *   Triggers `sa-refactor` (F#) which delegates to OpenRouter.

---

## 5. Usage Scenarios

### 5.1 Human Usage (The Explorer)
*   **Scenario**: Developer needs to understand "How does Auth work?"
*   **Action**: Opens Z-KMS. Searches "Auth".
*   **Result**: Sees a graph cluster. Clicks central node "Authentication Overview".
*   **Insight**: Sidebar shows **Backlinks** (who uses Auth?) and **Code Links** (where is it implemented?). The node color is Green (Verified).

### 5.2 Agent Usage (The Scholar)
*   **Scenario**: Gemini needs to fix a bug in `SagaManager`.
*   **Action**: Calls MCP `kms_read_context("SagaManager")`.
*   **Result**: Receives not just the file content, but the *Design Rationale* (from `docs/`) and *Test History* (from DuckDB) linked to that module.
*   **Outcome**: The fix respects the architectural constraints because the Agent "saw" the constraint documents.

### 5.3 System Usage (The Gardener)
*   **Scenario**: System detects `SagaManager.ex` has changed 50 times but `SAGA_DESIGN.md` hasn't changed in 6 months.
*   **Action**: IKE raises `DriftScore` to 0.9.
*   **Result**: The Zettel turns Bright Red on the dashboard.
*   **Automated Response**: A "Documentation Drift" ticket is auto-generated in `PROJECT_TODOLIST.md`.

---

## 6. Project Integration Plan

To implement this without disrupting the current mesh:

1.  **Create Project**: `lib/cepaf/src/Cepaf.Smriti/` (F# Project).
2.  **Define Dockerfile**: `Dockerfile.smriti` (Based on .NET 10).
3.  **Compose**: Add `smriti` service to `podman-compose-fractal.yml`.
4.  **Ingestion**: Enhance `lib/indrajaal/kms/ingestor.ex` to output standardized Zettel metadata to SQLite.

This approach transforms the documentation from a "Graveyard of Text" into a **Living Nervous System**.
