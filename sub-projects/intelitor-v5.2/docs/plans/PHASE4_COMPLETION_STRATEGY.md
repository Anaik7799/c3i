# STRATEGY: Phase 4 Completion (Criticality-Based)

**Classification**: L5-EVOLUTIONARY (Tactical Execution)
**Target**: Full Teleological Self-Awareness
**Status**: APPROVED

---

## 1.0 P0: The Teleological Governor (The Brain)
**Why**: This is the "Bicameral Mind". It connects the F# Cortex to OpenRouter, enabling High-Level Reasoning.
**Criticality**: **CRITICAL**. Without this, Phase 4 is empty infrastructure.

### Execution Tasks:
1.  **OpenRouter Client**: Replace `ZenohAdapter` stub with `Cepaf.Knowledge.OpenRouter`.
2.  **Secret Injection**: Inject `OPENROUTER_API_KEY` into Cortex container via `sa-up.fsx`.
3.  **Guardian Link**: Wire `Indrajaal.Safety.Guardian` (Elixir) to query `Indrajaal.Cortex` (F#) for "Strategic Approval" before critical acts (e.g., Delete Database).

## 2.0 P1: The Semantic Hippocampus (The Memory)
**Why**: Intelligence requires Context. The system must remember past failures to avoid repeating them.
**Criticality**: **HIGH**. Required for "Learning".

### Execution Tasks:
1.  **DuckDB Injection**: Add `DuckDB.NET.Data.Full` to `Indrajaal.Cortex.csproj`.
2.  **Vector Schema**: Create `vectors` table (UUID, Embedding, Metadata).
3.  **Recall Loop**: Implement `VectorStore.query(embedding)` in F#.

## 3.0 P2: The Metabolic Throttle (The Energy)
**Why**: AI models are expensive (Tokens). We must prevent "Cognitive Runaway".
**Criticality**: **MEDIUM**. Necessary for cost control, but system functions without it.

### Execution Tasks:
1.  **Token Bucket**: Implement `TokenBucket.fs`.
2.  **Cost Monitor**: Track OpenRouter usage per-holon.

## 4.0 P3: The Holographic Visualizer (The Eye)
**Why**: Humans need to see what the AI is thinking.
**Criticality**: **LOW**. The machine works without visualization.

### Execution Tasks:
1.  **GraphBLAS**: Add library.
2.  **Topology Stream**: Publish graph updates to Zenoh.

---

## 5.0 The "Golden Spike" (Completion Criteria)
Phase 4 is COMPLETE when:
1.  We can ask the system: "Why is the database load high?"
2.  The Cortex queries Memory (P1).
3.  The Cortex consults OpenRouter (P0).
4.  The Cortex replies: "Historical pattern matches 'Index Scan' (98%). Suggest adding index X."
