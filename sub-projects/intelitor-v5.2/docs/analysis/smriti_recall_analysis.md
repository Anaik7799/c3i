# SMRITI: Comprehensive Recall & Knowledge Management Analysis

**Version**: 1.0.0
**Date**: 2026-01-13
**Status**: APPROVED
**Classification**: ARCHITECTURAL SPECIFICATION

## 1.0 Executive Summary

SMRITI (Sanskrit for "Memory" or "Mindfulness") is the evolution of the ZKMS (Zettelkasten Knowledge Management System). It moves beyond static file storage to a dynamic, "living" memory system for the Indrajaal ecosystem. This document analyzes the "Recall" capabilities required to transform SMRITI into a Tier-1 Cognitive Substrate.

## 2.0 Comparative Landscape Analysis

### 2.1 Commercial Systems
*   **Palantir Foundry**: High-end ontology binding. *Gap*: Closed source, extreme cost.
*   **Mem.ai**: Personal knowledge graph with AI. *Gap*: Non-federated, cloud-dependent.
*   **Databricks**: Lakehouse architecture. *Gap*: Too heavy for edge/holonic deployment.

### 2.2 Academic & Open Source
*   **Logseq/Obsidian**: Local-first, markdown-based. *Pro*: Privacy. *Con*: Lack of active agents.
*   **Solid (Tim Berners-Lee)**: Decentralized data pods. *Pro*: Sovereignty. *Con*: Complexity.
*   **LangChain/LlamaIndex**: AI orchestration. *Pro*: Flexible. *Con*: Not a storage engine.

**SMRITI Positioning**: SMRITI occupies the "Holonic Middle" — distinct from purely local tools (Obsidian) and massive cloud silos (Palantir). It is **Biomorphic** (self-healing), **Federated** (Zenoh-based), and **Agent-Active** (not passive storage).

## 3.0 The 9 Levels of Recall (Fractal Detail)

SMRITI implements "Recall" not just as database retrieval, but as a multi-layered cognitive reconstruction process.

### Level 1: Atomic Recall (The Signal)
*   **Scope**: Raw bytes, ASCII characters, literal tokens.
*   **Implementation**: `grep`, `ripgrep`, exact string match.
*   **Feature**: "Verbatim Trace" — guarantee that input X produces output Y.

### Level 2: Molecular Recall (The Entity)
*   **Scope**: Named Entities (Users, Dates, IP Addresses, UUIDs).
*   **Implementation**: Regex extraction, basic NLP (Spacy/NLTK).
*   **Feature**: "Entity Linking" — auto-connect "User:123" to their Profile Holon.

### Level 3: Holonic Recall (The Context)
*   **Scope**: The Holon itself (Metadata + Content + History).
*   **Implementation**: JSON/Markdown frontmatter, DuckDB structured queries.
*   **Feature**: "Holon Rehydration" — loading the full state of an artifact.

### Level 4: Structural Recall (The Graph)
*   **Scope**: Direct relationships (Parent/Child, Linked-To, Reference-By).
*   **Implementation**: SQLite Graph edges, GraphBLAS matrix operations.
*   **Feature**: "Impact Analysis" — what breaks if I change this?

### Level 5: Systemic Recall (The Pattern)
*   **Scope**: Recurring architectural patterns across the mesh.
*   **Implementation**: FPPS (5-Point Pattern System) applied to memory.
*   **Feature**: "Pattern Recognition" — detecting "Drift" or "Rot" across multiple Holons.

### Level 6: Temporal Recall (The Evolution)
*   **Scope**: Time-series changes, git history, CRDT convergence.
*   **Implementation**: DuckDB time-travel queries, Git commit analysis.
*   **Feature**: "State Rollback" — recalling the system state at $T_{-1}$.

### Level 7: Cognitive Recall (The Meaning)
*   **Scope**: Semantic similarity, intent, vibe.
*   **Implementation**: Vector Embeddings (pgvector/sqlite-vss), LLM RAG.
*   **Feature**: "Vibe Search" — "Show me code that looks fragile."

### Level 8: Social Recall (The Provenance)
*   **Scope**: Who (Agent/User), Why (Intent), Consensus (Votes).
*   **Implementation**: Zenoh federation logs, cryptographic signatures (Sigstore).
*   **Feature**: "Trust Chain" — verify the chain of custody for a decision.

### Level 9: Universal Recall (The Archetype)
*   **Scope**: Long-term preservation, civilization-scale recovery.
*   **Implementation**: The Ark (M-DISC, PDF/A, ASCII, Shell).
*   **Feature**: "Seed Reconstruction" — rebuilding Indrajaal from zero.

## 4.0 The 9 Levels of Interaction (User & Agent)

1.  **Passive**: Read-only dashboard view.
2.  **Reactive**: Search-and-retrieve.
3.  **Curatorial**: Tagging, linking, organizing.
4.  **Generative**: "Draft a memo based on these 3 Holons."
5.  **Dialectic**: "Argue against this architectural decision."
6.  **Predictive**: "Based on past bugs, where will this fail?"
7.  **Autonomic**: System auto-refactors rotting Holons.
8.  **Symbiotic**: Brain-Computer Interface (future) / Neural-Spine escalation.
9.  **Evolutionary**: System re-writes its own Constitution (Founder's Directive).

## 5.0 Implementation Approach: The 2-Supervisor Model

To prevent **Context Press** and **API Overload**, we employ a rigorous 2-Supervisor architecture for all batch processing.

### Supervisor 1: The Gatekeeper (Rate & Budget)
*   **Role**: Enforce Token Limits, API Costs, and Concurrency.
*   **Mechanism**: `GenStage` producer-consumer.
*   **Rule**: "Never exceed 95% of API quota."

### Supervisor 2: The Curator (Quality & Relevance)
*   **Role**: Verify relevance, deduplicate, enforce STAMP constraints.
*   **Mechanism**: `Guardian.validate_proposal/1`.
*   **Rule**: "Never ingest garbage; reject high-entropy inputs."

### Batch Processing Protocol
1.  **Acquisition**: Agents fetch data to `data/ingest_buffer/`.
2.  **Analysis**: Curator Supervisor scans buffer, rejects noise.
3.  **Processing**: Gatekeeper Supervisor dispenses valid chunks to LLMs/Vectors.
4.  **Finalization**: Results committed to SQLite/DuckDB.

## 6.0 Integration with Existing Architectures
*   **Zenoh**: Used for L8 (Social) gossip and syncing.
*   **Ash**: Used for L4 (Structural) resource mapping.
*   **The Ark**: Used for L9 (Universal) backups.
*   **OODA**: SMRITI provides the "Orient" phase data.

This analysis extends the foundational work in `GEMINI.md` (Sections 89.0, 96.0) and concrete implementation in `zkms_integration.ex`.
