# SMRITI (ZKMS) & Recall: Deep Analysis and Implementation Strategy
**Date**: 2026-01-13
**Status**: DRAFT
**Version**: 1.0.0
**Target System**: Indrajaal v21.3.0-SIL6

---

## 1.0 Executive Summary

This document extends the architectural vision for **Smriti** (formerly ZKMS), positioning it not merely as a database, but as a **Cognitive Membrane** for the Indrajaal ecosystem. By implementing "Recall" capabilities, Smriti transitions from *storage* to *active memory*.

We analyze this transformation through:
1.  **9x9 Fractal Verification Matrix**: Exploring 9 levels of detail across 9 dimensions of interaction.
2.  **Market & Academic Landscape**: Benchmarking against Rewind.ai, Memex, and Xanadu.
3.  **10x10 Renaming Plan**: A rigorous, safe migration strategy from ZKMS to Smriti.

---

## 2.0 Market & Academic Landscape Analysis

To ensure Smriti is state-of-the-art, we benchmark against historical and contemporary systems.

### 2.1 Academic Foundations
*   **Memex (Vannevar Bush, 1945)**: The foundational concept of associative indexing ("trails"). Smriti implements this via `Smriti.Weaver` (associative links) and Vector Search.
*   **Project Xanadu (Ted Nelson, 1960)**: Concepts of "Transclusion" and "Deep Linking". Smriti implements this via atomic Holon referencing (`smriti:uuid`) where content is included by reference, not copy.
*   **MyLifeBits (Gordon Bell, Microsoft Research, 1998)**: The attempt to digitally capture a lifetime. Smriti adopts the "total capture" philosophy but adds **Apoptosis** (forgetting) to manage entropy, a critical biological feature missing in MyLifeBits.

### 2.2 Commercial State-of-the-Art
*   **Rewind.ai / Limitless**: Records screen and audio.
    *   *Smriti Gap*: Smriti focuses on *System* and *DevOps* lifecycle (Logs, Code, Decisions) rather than just user screen/audio. Smriti is "Rewind for the Cluster".
*   **Obsidian / Logseq / Roam**: Local-first Zettelkasten.
    *   *Smriti Alignment*: Smriti adopts the local-first (SQLite) approach but adds a **Federation Layer** (Zenoh) for multi-node knowledge sharing, which these tools lack natively.
*   **Palantir / Gotham**: Enterprise ontology mapping.
    *   *Smriti Alignment*: Smriti uses a rigorous ontology (Holons/Edges) but remains lightweight and "Biomorphic" rather than rigid and top-down.

---

## 3.0 The 9x9 Recall Feature Matrix

We expand the Recall definition to 9 vertical levels of detail and 9 horizontal dimensions of interaction.

### 3.1 Vertical Levels (Depth of Recall)

| Level | Name | Definition | SMRITI Implementation |
| :--- | :--- | :--- | :--- |
| **L1** | **Signal** | Raw, uninterpreted data streams. | `Zenoh` packet capture, `stdin`/`stdout` streams. |
| **L2** | **Data** | Structured events with schema. | `duckdb` time-series tables, JSON logs. |
| **L3** | **Information** | Contextualized data (Who, What, When). | `Elixir` Structs (`%Event{}`), enriched metadata. |
| **L4** | **Knowledge** | Linked entities and relationships. | `SQLite` Graph (`holons`, `edges` tables). |
| **L5** | **Pattern** | Recurring sequences or anomalies. | `PatternHunter` analytics, cluster detection. |
| **L6** | **Intent** | The goal behind the action. | Vector embeddings (`all-MiniLM-L6-v2`) of prompts/commit msgs. |
| **L7** | **Implication** | Causal chains and side effects. | Impact analysis graph traversal (Dependency walking). |
| **L8** | **Evolution** | Change over time (Diffs). | `VersionVector` history, git-like lineage tracking. |
| **L9** | **Existential** | The narrative arc / "Why". | `CaptainLog` summaries, high-level system narrative. |

### 3.2 Horizontal Dimensions (Scope of Interaction)

| Dim | Name | Scope | Interaction Protocol |
| :--- | :--- | :--- | :--- |
| **D1** | **CLI/Shell** | Terminal history, command output. | Shell hooks (`preexec`/`precmd`) sending to `smriti-ingest`. |
| **D2** | **IDE/Code** | Editor actions, LSP traffic. | VSCode extension pushing edit events to local Smriti API. |
| **D3** | **Browser** | Web research, documentation. | Browser extension capturing visited URLs and metadata. |
| **D4** | **Mesh** | Inter-node communication. | Zenoh middleware "snooping" on control plane traffic. |
| **D5** | **System** | OS resources (CPU, RAM, Disk). | `system_monitor` daemon feeding DuckDB metrics. |
| **D6** | **Network** | HTTP/gRPC calls, latency. | OpenTelemetry spans ingested into Smriti context. |
| **D7** | **Social** | Human-to-human comms (Chat). | Bridge bots (Slack/Discord) archiving decision threads. |
| **D8** | **Temporal** | Time-based navigation. | "Time Slider" UI in Cockpit to rewind system state. |
| **D9** | **Predictive** | Future state anticipation. | LLM inference on L1-L8 data to suggest next actions. |

---

## 4.0 Implementation Architecture: Two-Level Supervisor

To manage the complexity of this "Total Recall" system without overloading the cognitive or API capacity, we use a tiered supervisory model.

### 4.1 L1: Strategic Supervisor (The Architect)
*   **Responsibility**: Maintains the 10x10 Plan.
*   **Behavior**:
    *   Does NOT execute file edits.
    *   Monitors progress of L2 supervisors.
    *   Handles "Out of Context" exceptions.
    *   Validates completion criteria (Tests Green, Docs Updated).

### 4.2 L2: Tactical Supervisor (The Builder)
*   **Responsibility**: Executes atomic batches.
*   **Behavior**:
    *   Operates on max 10 files per context window.
    *   Runs `mix compile` / `dotnet build` after every batch.
    *   Implements the "Hippocampus" pipeline steps.
    *   Reports status up to L1.

---

## 5.0 The "Smriti" Renaming Plan (10x10 Matrix)

This plan ensures a zero-downtime, non-destructive migration from `ZKMS` to `SMRITI`.

| Phase | Description | Key Deliverable | Criticality |
| :--- | :--- | :--- | :--- |
| **P1** | **Documentation** | `docs/smriti/` fully populated. | Low |
| **P2** | **Configuration** | Env vars, `mix.exs`, `devenv.nix`. | High |
| **P3** | **Elixir Lib** | `lib/indrajaal/smriti` refactored. | Critical |
| **P4** | **Elixir Tests** | Test suite migration & verification. | Critical |
| **P5** | **F# Shared** | `Cepaf.Smriti.Shared` types. | Critical |
| **P6** | **F# API** | `Cepaf.Smriti.Api` server. | Critical |
| **P7** | **F# Client** | `Cepaf.Smriti.Client` UI. | Medium |
| **P8** | **Scripts/Tools** | `smriti_ctl`, maintenance scripts. | High |
| **P9** | **Data Migration** | SQL/DuckDB file renaming & schemas. | High |
| **P10** | **Verification** | E2E "Big Bang" test. | Critical |

*(See `PROJECT_TODOLIST.md` for the exploded 100-step detail)*

---

## 6.0 Implications & Risks

1.  **Context Pressure**: Ingesting L1-L9 data generates massive text volumes.
    *   *Mitigation*: **Summarization at Edge**. L2 Supervisors distill logs into L3 Information before sending to the Core.
2.  **Privacy**: "Recall" features can capture sensitive data (Env vars, keys).
    *   *Mitigation*: **PII Scrubbers** at the L1 Ingest layer (Regex/NLP based redaction) before storage.
3.  **Storage Costs**: Storing full history is expensive.
    *   *Mitigation*: **Entropy-Based Pruning (Apoptosis)**. Data at L1/L2 ages out rapidly unless promoted to L4 Knowledge by frequent access or explicit tagging.

---

**Approved By**: SMRITI Cybernetic Architect
