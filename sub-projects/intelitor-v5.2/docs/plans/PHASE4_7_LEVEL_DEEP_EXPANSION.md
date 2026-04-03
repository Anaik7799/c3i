# MASTER PLAN: Phase 4 Evolutionary Awakening (7-Level Fractal Detail)

**Classification**: L7-KOSMOS (Sovereign Specification)
**Target**: Full Phase 4 Capability (Teleological Self-Awareness)
**Compliance**: SIL-6 / PROMETHEUS / Axiom 0

---

## 1.0 Upgrade 1: The Semantic Hippocampus (Vector Memory)

### 1.1 7-Level Decomposition
*   **L1 (Cellular)**: `DuckDB.NET` library integration with `parquet` storage format.
*   **L2 (Component)**: `VectorStore` F# Module handling Embedding generation (via ONNX) and cosine similarity search.
*   **L3 (Integration)**: `Zenoh` topic `indrajaal/memory/recall` for query/response.
*   **L4 (Operational)**: Volume persistence `fractal-cortex-memory` ensuring knowledge survives restarts.
*   **L5 (Metabolic)**: "Sleep Cycle" (Compaction) runs every 24h to merge WAL logs.
*   **L6 (Evolutionary)**: "Dreaming" - The system replays logs during low-load to generate new insights.
*   **L7 (Strategic)**: "Wisdom" - Long-term trend analysis guiding architectural pivots.

### 1.2 Impact Analysis
*   **Substrate**: High Disk I/O (Write-heavy). Requires NVMe.
*   **Logic**: Introduces non-deterministic latency (Search time). Must be async.
*   **Safety**: Memory corruption could lead to hallucinations. **Mitigation**: Merkle Tree verification of memory blocks.

---

## 2.0 Upgrade 2: The Holographic Visualizer (Live Graph)

### 2.1 7-Level Decomposition
*   **L1 (Cellular)**: `GraphBLAS` linear algebra kernels for $O(1)$ traversal.
*   **L2 (Component)**: `TopologyEngine` F# Service maintaining the Adjacency Matrix.
*   **L3 (Integration)**: Ingests `podman events` and `zenoh heartbeat` to update edges.
*   **L4 (Operational)**: Visualized in `indrajaal-liveview` via WebGL/Three.js.
*   **L5 (Metabolic)**: "Pulse Propagation" - Visualizing the 100ms heartbeat flow.
*   **L6 (Evolutionary)**: "Ghost Graph" - Simulating network changes before applying them.
*   **L7 (Strategic)**: "Bottleneck Identification" - Automatically highlighting single points of failure.

### 2.2 Impact Analysis
*   **Substrate**: High Memory (Matrix storage).
*   **Logic**: Complex state synchronization.
*   **Safety**: Incorrect topology could lead to partitioned clusters. **Mitigation**: 2oo3 Voting on Topology state.

---

## 3.0 Upgrade 3: The Teleological Governor (Semantic Guardian)

### 3.1 7-Level Decomposition
*   **L1 (Cellular)**: `Microsoft.ML.OnnxRuntime` running a quantized Llama-3-8B.
*   **L2 (Component)**: `SemanticPolicyEngine` F# Actor.
*   **L3 (Integration)**: Intercepts `indrajaal/control/proposal` messages.
*   **L4 (Operational)**: Runs in a dedicated "Sidecar" to prevent CPU starvation of the Core Cortex.
*   **L5 (Metabolic)**: "Attention Span" - Limited context window management.
*   **L6 (Evolutionary)**: "Ethics Drift" monitoring. Ensuring the model doesn't diverge from the Founder.
*   **L7 (Strategic)**: "Judgement" - The ability to say "No" to a valid command because it violates the *spirit* of the law.

### 3.2 Impact Analysis
*   **Substrate**: Massive CPU/GPU requirement.
*   **Logic**: Non-deterministic outputs.
*   **Safety**: AI Hallucination risk. **Mitigation**: **Simplex Architecture**. The AI proposes, but a deterministic Regex Kernel (The Old Guardian) has final veto power on safety-critical actions.

---

## 4.0 Upgrade 4: The Metabolic Throttle (Energy Economy)

### 4.1 7-Level Decomposition
*   **L1 (Cellular)**: `TokenBucket` algorithm implementation.
*   **L2 (Component)**: `EconomyManager` F# Service issuing "Compute Credits".
*   **L3 (Integration)**: Agents must include a `PaymentToken` in every Zenoh request.
*   **L4 (Operational)**: "Bankruptcy" handling. What happens when a critical service runs out of credits? (Emergency Loan).
*   **L5 (Metabolic)**: "Inflation" control. Adjusting token generation based on total system load.
*   **L6 (Evolutionary)**: "Wealth Distribution". Prioritizing evolutionary tasks when surplus energy exists.
*   **L7 (Strategic)**: "Cost Cap". Hard limit on cloud spend (if running in cloud).

### 4.2 Impact Analysis
*   **Substrate**: Low impact.
*   **Logic**: High complexity. Distributed consensus on balances.
*   **Safety**: Deadlock risk if tokens run out. **Mitigation**: "Vital Organs" (Heartbeat, Sentinel) have infinite credit lines.

---

## 5.0 Criticality-Based Execution Plan

### P0: Foundation (The Brain)
1.  **Memory Injection**: Add DuckDB to Cortex. (Low Risk / High Value).
2.  **Neural Link**: Proto-buffers for Vector exchange.

### P1: Perception (The Eyes)
3.  **Graph Engine**: Implement GraphBLAS Matrix.
4.  **Topology Sync**: Connect Podman Events to Graph.

### P2: Control (The Hands)
5.  **Throttle**: Implement Token Bucket.
6.  **Economy**: Activate credit checks.

### P3: Wisdom (The Soul)
7.  **Semantic Engine**: Deploy ONNX Model.
8.  **Constitutional Tuning**: Fine-tune the Governor.

---

## 6.0 Success Metrics (The 7-Level Check)
The upgrade is successful ONLY if:
1.  **L1**: Code compiles.
2.  **L2**: Components initialize.
3.  **L3**: Messages flow.
4.  **L4**: Containers run stable.
5.  **L5**: Heartbeat is < 100ms.
6.  **L6**: Evolution is possible.
7.  **L7**: The system refuses an unsafe order for the *right reason*.
