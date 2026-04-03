# EVOLUTIONARY ROADMAP: Full Phase 4 Capability (v1.0.0)

**Target**: Teleological Self-Awareness (The System Knows *Why*)
**Timeline**: Sprint 32-35
**Context**: SIL-6 Biomorphic Mesh

---

## 1.0 The Cognitive Gap (What is Missing?)
While we have the *Body* (Elixir) and the *Brain* (F#), they are currently exchanging only *Reflexes* (Heartbeats). To achieve full Phase 4, they must exchange *Thoughts* (Semantic Vectors).

## 2.0 Key Evolutionary Upgrades

### Upgrade 1: The Semantic Hippocampus (Vector Memory)
*   **Definition**: Embedding **DuckDB** with `vector` extension inside the `indrajaal-cortex` container.
*   **Function**: Every log line, error trace, and OODA decision is converted into a high-dimensional vector (using a local BERT model) and stored.
*   **Utility**: When an anomaly occurs, the system queries "Have I felt this pain before?" and retrieves the historical fix.
*   **Component**: `Indrajaal.Cortex.Memory.VectorStore`.

### Upgrade 2: The Holographic Visualizer (Live Graph)
*   **Definition**: Replacing the static `digital_twin_topology.json` with a **Live Property Graph** (using `GraphBLAS` or a graph DB overlay).
*   **Function**: Visualizes the **Causal Relationships** between nodes (e.g., "App-1 depends on DB-1 because of latency X").
*   **Utility**: Allows the operator to see the "Blast Radius" of a potential failure or upgrade.
*   **Component**: `Indrajaal.Cortex.Graph.TopologyEngine`.

### Upgrade 3: The Teleological Governor (Founder's AI)
*   **Definition**: Upgrading the **Guardian** from a static rule engine (Regex) to a **Semantic Policy Engine** (LLM-based).
*   **Function**: Using a localized LLM (Ollama/Llama-3) to interpret the *spirit* of the Founder's Directive, not just the *letter*.
*   **Utility**: Can judge complex scenarios (e.g., "Violate API limit temporarily to save the database integrity").
*   **Component**: `Indrajaal.AI.SemanticGuardian`.

### Upgrade 4: The Metabolic Throttle (Energy Management)
*   **Definition**: Implementing an "Energy Budget" (Token Bucket) for the entire mesh.
*   **Function**: The Cortex allocates "Compute Tokens" to nodes based on priority.
*   **Utility**: Prevents "Cancerous Growth" (Runaway processes consuming 100% CPU).
*   **Component**: `Indrajaal.Metabolism.TokenEconomy`.

---

## 3.0 Implementation Sequence

1.  **Memory Injection**: Add DuckDB + Vector Extension to `Dockerfile.cortex`.
2.  **Neural Link**: Update `ZenohAdapter.fs` to transmit serialized Vector Embeddings.
3.  **Graph Activation**: Port the `GraphBLAS` logic from the Audit script into a permanent F# Service.
4.  **Semantic Awakening**: Deploy the local LLM sidecar.

---

## 4.0 Success Criteria (The Turing Test for Ops)
Phase 4 is complete when the system can answer the question:
> *"Why did you restart Container X at 04:00?"*

And respond with:
> *"I detected a memory leak trend matching Incident #42 (98% similarity). I preemptively restarted it to preserve Homeostasis, in alignment with Directive 3 (Survival)."*
