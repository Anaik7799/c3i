# SMRITI: The "Recall" & Identity Refactoring Master Plan

**Date**: 2026-01-13
**Status**: DRAFT
**Version**: 1.0.0
**Target System**: Indrajaal v21.3.0-SIL6

---

## 1.0 Executive Summary

This document outlines the strategic roadmap for two massive concurrent initiatives:
1.  **The "Recall" Capability**: Transforming the KMS from a static repository into a temporal, omniscient memory system (similar to Rewind.ai but for the *entire* DevOps/System lifecycle).
2.  **Identity Refactoring**: Renaming the legacy "ZKMS" (Zettelkasten KMS) to **"SMRITI"** (Sanskrit: *Memory/Mindfulness*) across the polyglot stack (Elixir, F#, Python, Bash, Docker, K8s).

To execute this safely, we utilize a **Two-Level Supervisor Architecture** to manage context pressure and ensure SIL-6 compliance.

---

## 2.0 The "Recall" Capability: 9x9 Fractal Analysis

"Recall" is defined as the system's ability to reconstruct any past state or context with high fidelity. It moves beyond *storage* to *experiential reconstruction*.

### 2.1 The 9 Levels of Recall Detail (Vertical Depth)

| Level | Name | Definition | Implementation Target |
| :--- | :--- | :--- | :--- |
| **L1** | **Signal** | Raw inputs (Keystrokes, Logs, HTTP Requests, Zenoh Messages). | `ZenohEvolutionPublisher` (Raw Stream) |
| **L2** | **Data** | Structured events (JSON, SQL Rows) with timestamps. | `data/kms/telemetry.duckdb` (TimeSeries) |
| **L3** | **Information** | Contextualized events (e.g., "User compiled module X"). | `Smriti.Event` (Elixir/F# Structs) |
| **L4** | **Knowledge** | Linked entities. "Module X depends on Y, which was failing." | `data/kms/smriti.db` (Graph/SQLite) |
| **L5** | **Pattern** | Recurring behaviors (e.g., "Builds fail on Tuesdays"). | `Smriti.Analytics` (PatternHunter) |
| **L6** | **Intent** | *Why* an action occurred (derived from commit msgs, prompts). | `Smriti.Intent` (Vector Embeddings) |
| **L7** | **Implication** | Side effects of actions (1st-5th order effects). | `Smriti.ImpactAnalyzer` (Graph Traversal) |
| **L8** | **Evolution** | How the system *changed* due to the action (Diffs). | `Smriti.Evolution.Tracker` (Lineage) |
| **L9** | **Existential** | The "Narrative" of the system's life. | `Smriti.CaptainLog` (Natural Language) |

### 2.2 The 9 Dimensions of Interaction (Horizontal Breadth)

| Dim | Name | Scope | Integration Strategy |
| :--- | :--- | :--- | :--- |
| **D1** | **CLI/Shell** | All terminal commands and outputs. | Shell Wrapper / `history` hook integration. |
| **D2** | **IDE/Code** | File edits, cursor movement, lsp actions. | VS Code / Emacs plugin hooks -> Zenoh. |
| **D3** | **Browser/Docs** | Documentation viewed, external research. | Browser Extension / Proxy logs. |
| **D4** | **Mesh/Agent** | Inter-agent Zenoh gossip. | `Smriti.Subscriber` (promiscuous mode). |
| **D5** | **System/OS** | CPU, RAM, Disk I/O, Process list. | `system_monitor` -> Telemetry. |
| **D6** | **Network** | API calls, Latency, Bandwidth. | OpenTelemetry Spans -> Smriti. |
| **D7** | **Social** | Chat logs (Slack/Discord), Emails. | Webhook Ingestors. |
| **D8** | **Temporal** | "Time Travel" navigation. | UI Slider / `smriti-recall --time "2h ago"`. |
| **D9** | **Predictive** | "Next likely action". | Transformer model trained on L1-L8 data. |

### 2.3 Implementation Strategy: The "Hippocampus" Pipeline

1.  **Acquisition (Sensors)**: Lightweight agents (Elixir/Rust) tapping D1-D7.
2.  **Buffering (Short-Term Memory)**: Zenoh streams (`smriti/senses/**`). High throughput, low latency.
3.  **Consolidation (Sleep Cycle)**:
    *   **Batch Processing**: Every 10 minutes (or 100MB).
    *   **Vectorization**: `Indrajaal.AI.Embeddings` creates vectors for Intent (L6).
    *   **Graphing**: `SmritiEdgeGenerator` links events to Holons (L4).
4.  **Storage (Long-Term Memory)**:
    *   **Facts**: SQLite (`smriti.db`).
    *   **Events**: DuckDB (`recall.duckdb`).
    *   **Vectors**: `sqlite-vss` or separate vector store.

---

## 3.0 Two-Level Supervisor Strategy

To prevent **Context Overload** (Token exhaustion) and **API Overload** (Rate limits) during this massive migration/feature-add, we employ a strict supervisory hierarchy.

### 3.1 Level 1: The Strategy Supervisor (Strategic)
*   **Role**: Manages the Global State and the 10x10 Plan.
*   **Context**: Holds the `MASTER_PLAN.md` and `PROJECT_TODOLIST.md`.
*   **Rules**:
    *   Never reads source code directly unless necessary for planning.
    *   Delegates *one* Phase (e.g., "Rename Docs") to L2 at a time.
    *   Verifies L2's completion via `sa-verify` scripts.

### 3.2 Level 2: The Execution Supervisor (Tactical)
*   **Role**: Executes atomic file operations.
*   **Context**: Reads *only* the files needed for the current Batch (max 10 files).
*   **Rules**:
    *   **Batch Limit**: Max 10 file mutations per turn.
    *   **Validation**: Must run `mix compile` (Elixir) or `dotnet build` (F#) after *every* batch.
    *   **Rollback**: If compilation fails, strictly roll back using `git checkout`.
    *   **Reporting**: Returns a structured JSON summary to L1.

---

## 4.0 The "Smriti" Renaming Plan (10x10 Matrix)

**Objective**: Rename `ZKMS` -> `SMRITI` (Case-preserving: `zkms` -> `smriti`, `ZKMS` -> `SMRITI`, `Zkms` -> `Smriti`).

| Phase | Focus Area | Description | Risk |
| :--- | :--- | :--- | :--- |
| **P1** | **Documentation** | Update `docs/` folder structure and content. | Low |
| **P2** | **Configuration** | Update `mix.exs`, `devenv.nix`, `config/`, Env Vars. | High |
| **P3** | **Elixir Lib** | Rename `lib/indrajaal/zkms` -> `smriti` & Module names. | Critical |
| **P4** | **Elixir Tests** | Rename `test/indrajaal/zkms` -> `smriti` & Update refs. | Critical |
| **P5** | **F# Shared** | Rename `Cepaf.Zkms.Shared` -> `Cepaf.Smriti.Shared`. | Critical |
| **P6** | **F# API** | Rename `Cepaf.Zkms.Api` -> `Cepaf.Smriti.Api`. | Critical |
| **P7** | **F# Client** | Rename `Cepaf.Zkms.Client` -> `Cepaf.Smriti.Client`. | Medium |
| **P8** | **Scripts** | Update `scripts/zkms` -> `scripts/smriti` & `.fsx` files. | High |
| **P9** | **Data/Schema** | Rename `data/kms` -> `data/smriti` & SQL tables. | High |
| **P10** | **Verify** | Full system build, test suite, and E2E verification. | Critical |

### 4.1 Detailed Breakdown (Sample for P3 - Elixir Lib)

1.  **Identify**: Find all files in `lib/indrajaal/zkms`.
2.  **Move**: Rename directory `lib/indrajaal/zkms` -> `lib/indrajaal/smriti`.
3.  **Batch 1**: Rename Modules `Indrajaal.ZKMS.*` -> `Indrajaal.Smriti.*` in `smriti/`.
4.  **Batch 2**: Update references in `lib/indrajaal/application.ex` (Supervisor).
5.  **Batch 3**: Update references in `lib/indrajaal/web/`.
6.  **Batch 4**: Update references in `lib/indrajaal/cortex/`.
7.  **Compile**: Verify Elixir compilation.
8.  **Format**: Run `mix format`.
9.  **Credo**: Run `mix credo`.
10. **Commit**: `refactor(smriti): Rename ZKMS lib to Smriti`.

---

## 5.0 Next Steps

1.  **Approve**: User confirms this plan.
2.  **Initialize**: I will create the `docs/smriti` directory (Phase 1).
3.  **Execute**: I will proceed with Phase 1 (Documentation Renaming) using the 2-Level Supervisor constraint.

**Action Required**: Please confirm if I should proceed with **Phase 1 (Documentation)** of the Smriti Renaming Plan.
