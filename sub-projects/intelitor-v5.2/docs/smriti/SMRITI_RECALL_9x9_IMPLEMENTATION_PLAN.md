# SMRITI Recall Feature Implementation Plan (9x9 Fractal)
**Version**: 2.0.0-BIO-9x9 | **Status**: DRAFT | **Date**: 2026-01-13
**Source**: "Recall" SaaS Capabilities -> SMRITI Architecture
**Framework**: 9-Level Fractal x 9-Degree Interaction Matrix (SC-9x9)
**Compliance**: SIL-6 Biomorphic + Existential Safety

---

## 1.0 Executive Vision: The Cosmic Cognition

This document expands the SMRITI/Recall integration plan to the full **9x9 Fractal Verification Matrix** defined in `GEMINI.md` Section 96.0. This ensures that the "Cognitive Membrane" we are building is not just operational (L1-L7) but **Evolutionary** (L8) and **Existentially Robust** (L9).

### 1.1 The 9x9 Matrix Definition

**Vertical Axis: The 9 Fractal Levels (Scale)**
1.  **L1 Atomic**: Functions, Types.
2.  **L2 Component**: Modules, Pipelines.
3.  **L3 Holon**: Agents, OODA.
4.  **L4 Container**: Services, APIs.
5.  **L5 Node**: Resources, OS.
6.  **L6 Mesh**: Replication, Consensus.
7.  **L7 Federation**: Global Ontology, Trust.
8.  **L8 Ecosystem**: User Experience, External APIs, Community.
9.  **L9 Universe**: Deep Time, Entropy, Heat Death.

**Horizontal Axis: The 9 Interaction Degrees (Capabilities)**
1.  **C1 Signal**: Input/Output.
2.  **C2 Control**: Governance.
3.  **C3 Data**: Persistence.
4.  **C4 Semantic**: Meaning.
5.  **C5 Social**: Collaboration.
6.  **C6 Economic**: Cost/Resource.
7.  **C7 Legal**: Security/Compliance.
8.  **C8 Evolution**: Self-Improvement/Refactoring.
9.  **C9 Existential**: Survival/Restoration.

---

## 2.0 Feature 1: Universal Sensory Ingest ("The Senses")

**Recall Feature**: Frictionless Capture (Web, PDF, Video).
**SMRITI Organ**: **`SMRITI.Senses`**

### 2.1 9-Level Implementation Specification

| Level | Component | Implementation Detail |
| :--- | :--- | :--- |
| **L1** | **Extractors** | `fetch_url/1`, `parse_pdf/1` (Rust NIF), `transcribe/1` (Whisper/yt-dlp). |
| **L2** | **Pipeline** | `IngestionGenStage`: Backpressure-managed flow. Sanitization -> Hashing -> vectorization. |
| **L3** | **SensoryAgent**| OODA Loop: Detects content type, assigns priority (P0-P4), schedules processing. |
| **L4** | **Interfaces** | `smriti-capture` CLI, Browser Extension Bridge (localhost:4000), `POST /api/capture`. |
| **L5** | **Storage** | `data/blobs/` (CAS), `holons.db` (Metadata). SSD-optimized write buffers. |
| **L6** | **Gossip** | Zenoh topic `smriti/senses/new`. "Archivist" nodes pin raw blobs to IPFS. |
| **L7** | **Provenance** | Digital Signatures on all ingest. "Source of Truth" verification against Federation blacklist. |
| **L8** | **Ecosystem** | **Public API Gateway**: Allowing external tools (e.g., Slack bot, Obsidian plugin) to feed SMRITI. |
| **L9** | **Universe** | **The Ark**: Raw ingests are marked for long-term preservation in `Indrajaal.Ark` (M-DISC ready). |

### 2.2 9-Degree Interaction Analysis

*   **C8 Evolution**: The extractors must self-update. If `yt-dlp` breaks, the system detects the failure pattern and attempts to `mix deps.update` or fetch a patched binary (L8 interaction).
*   **C9 Existential**: If the internet vanishes, does the knowledge remain? Yes. L9 implementation ensures `raw_content` is stored, not just links. **SC-SMRITI-L9-001**: "No Link Rot".

---

## 3.0 Feature 2: Cognitive Distillation ("The Digestion")

**Recall Feature**: AI Summarization, Key Points.
**SMRITI Organ**: **`SMRITI.Cognition`**

### 3.1 9-Level Implementation Specification

| Level | Component | Implementation Detail |
| :--- | :--- | :--- |
| **L1** | **Prompts** | `PromptRegistry` (Versioned). `v1` (Haiku), `v2` (Sonnet), `v3` (Opus). |
| **L2** | **Distiller** | Map-Reduce logic for infinite context windows. Chunking strategy based on semantic boundaries. |
| **L3** | **Refiner** | `KnowledgeAgent` parses AI output into `TodoHolon`, `CodeHolon`, `ConceptHolon`. |
| **L4** | **Model Bridge**| `OpenRouterClient`. Simplex validation of JSON output. Rate limiting. |
| **L5** | **Cache** | Semantic Caching. `hash(prompt + content)`. Disk-persisted ETS table. |
| **L6** | **Consensus** | Tri-Cameral Review (Claude/GPT/Gemini) for P0 content. Majority vote on "Facts". |
| **L7** | **Ontology** | Global Concept Alignment. "Does 'Elixir' mean the language or the potion?" Federation decides. |
| **L8** | **User Loop** | **RLHF Interface**: Users can upvote/downvote summaries. System fine-tunes system prompts based on feedback. |
| **L9** | **Universe** | **Wisdom Distillation**: Once a year, compress all summaries into a "Yearly Codex" (PDF/A) for deep time storage. |

### 3.2 9-Degree Interaction Analysis

*   **C8 Evolution**: The system analyzes which prompts yield the most "Useful" Holons (measured by subsequent access/linking) and auto-optimizes the prompt text (Genetic Algorithm on Prompts).
*   **C9 Existential**: If AI models become unavailable, can the system still function? Yes, fallback to basic keyword extraction (L1) and manual summarization (L8).

---

## 4.0 Feature 3: Semantic Weaving ("The Neural Net")

**Recall Feature**: Auto-linking, Knowledge Graph.
**SMRITI Organ**: **`SMRITI.Weaver`**

### 4.1 9-Level Implementation Specification

| Level | Component | Implementation Detail |
| :--- | :--- | :--- |
| **L1** | **Math** | Cosine Similarity (Nx), Jaccard Index (MapSet), Aho-Corasick (Rust). |
| **L2** | **Weaver** | `GraphBuilder` GenServer. Async link discovery post-ingest. |
| **L3** | **Linker** | `KnowledgeAgent` promotes "Soft Links" (AI suggested) to "Hard Links" (User confirmed). |
| **L4** | **API/UI** | `/api/graph/neighborhood`. Cytoscape.js visualizer in Cockpit. |
| **L5** | **Index** | `HNSW` Vector Index (LanceDB or sqlite-vss). Periodic re-indexing. |
| **L6** | **Discovery** | "Serendipity Protocol". Node A queries Mesh for "Concepts related to X" that A doesn't know. |
| **L7** | **Topology** | Small-World Network Analysis. Detect "Knowledge Silos" and alert Federation. |
| **L8** | **UX** | **"The Rabbit Hole"**: A UI mode that guides users through semantic paths (User Journey). |
| **L9** | **Universe** | **Graph Invariant**: Ensure the Knowledge Graph is a DAG (Directed Acyclic Graph) at the macro scale to prevent circular reasoning logic loops in AI agents. |

### 4.2 9-Degree Interaction Analysis

*   **C8 Evolution**: The graph structure influences code generation. Denser graph = Better RAG context = Better Code.
*   **C9 Existential**: The Graph MUST be serializable to a flat format (e.g., RDF N-Quads) to survive database corruption. `smriti-export --format rdf`.

---

## 5.0 Feature 4: Active Resilience (Spaced Repetition) ("The Immune System")

**Recall Feature**: Quizzes, Reviews.
**SMRITI Organ**: **`SMRITI.Immune`**

### 5.1 9-Level Implementation Specification

| Level | Component | Implementation Detail |
| :--- | :--- | :--- |
| **L1** | **Algo** | `SM2_Algorithm` (Elixir). Calculates `next_review_at`. |
| **L2** | **Scheduler** | `ReviewScheduler`. Priority Queue based on Holon Criticality. |
| **L3** | **Examiner** | `ExaminerAgent`. Runs Tests (Code), Checks URLs (Docs), Queries AI (Facts). |
| **L4** | **Dashboard** | "Amnesia Score". Widget showing % of unverified knowledge. |
| **L5** | **Repair** | Auto-healing scripts (git revert, cache clear) triggered on failure. |
| **L6** | **Pressure** | "Rot Gossip". Nodes broadcast Holon failures. Low-reputation Holons are pruned from Mesh. |
| **L7** | **Apoptosis** | **SC-SMRITI-SRS-001**. Systematic deletion of rotting non-critical knowledge. |
| **L8** | **Gamification** | **"Gardener Score"**: Reward users/agents for verifying Holons. Leaderboard. |
| **L9** | **Universe** | **The Filter**: Only Holons that survive N years of SRS are candidates for the "Golden Ark" (L9 Archive). |

### 5.2 9-Degree Interaction Analysis

*   **C8 Evolution**: High failure rates in a specific Domain trigger a "Refactoring Request". The system evolves away from brittle knowledge.
*   **C9 Existential**: Defines "Truth". Only verified knowledge is preserved. Unverified knowledge is entropy.

---

## 6.0 9x9 Implementation Roadmap

### Phase 1: The Biological Substrate (L0-L5)
*   **Goal**: Functional equivalence to Recall (Single User).
*   **Tasks**:
    1.  [ ] **L0**: Schema Upgrade (Vectors, SRS, Hash).
    2.  [ ] **L1**: Implement Extractors and SM2.
    3.  [ ] **L2**: Build Pipelines (Ingest, Distill).
    4.  [ ] **L3**: Deploy Agents (Sensory, Knowledge, Examiner).
    5.  [ ] **L4**: CLI & API endpoints.
    6.  [ ] **L5**: Resource config (Nix) & Local Vector Store.

### Phase 2: The Social Organism (L6-L7)
*   **Goal**: Distributed Intelligence (Multi-Node).
*   **Tasks**:
    1.  [ ] **L6**: Zenoh Gossip for Ingest/Rot.
    2.  [ ] **L6**: Tri-Cameral Consensus implementation.
    3.  [ ] **L7**: Federation Ontology & Provenance Signing.

### Phase 3: The Cosmic Imperative (L8-L9)
*   **Goal**: Evolution & Immortality.
*   **Tasks**:
    1.  [ ] **L8**: External API Gateway & Browser Extension.
    2.  [ ] **L8**: RLHF Feedback Loops.
    3.  [ ] **L9**: The Ark Integration (M-DISC Export).
    4.  [ ] **L9**: Deep Time Summarization (Yearly Codex).

---

## 7.0 Verification Strategy (SC-9x9)

Every feature MUST pass the **Diagonal Verification**:
1.  **L1/C1**: Does the function emit telemetry?
2.  **L2/C2**: Does the component respect governance limits?
3.  **L3/C3**: Does the agent persist state correctly?
4.  **L4/C4**: Does the container expose semantic meaning via API?
5.  **L5/C5**: Does the node participate in social discovery?
6.  **L6/C6**: Is the mesh economically viable (token cost)?
7.  **L7/C7**: Is the federation legally compliant (security)?
8.  **L8/C8**: Does the ecosystem evolve based on usage?
9.  **L9/C9**: Can the system survive total collapse and reboot?

*Approved by SMRITI Cybernetic Architect*
