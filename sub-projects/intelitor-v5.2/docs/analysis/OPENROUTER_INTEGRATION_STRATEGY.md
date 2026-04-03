# ANALYSIS: OpenRouter Integration Strategy (Hybrid Cortex)

**Classification**: L5-EVOLUTIONARY (Transitional Strategy)
**Target**: Bridging the "Intelligence Gap" before Local LLM availability.
**Context**: SIL-6 Biomorphic Mesh

---

## 1.0 The Hybrid Cognitive Architecture

We define a **Three-Tier Intelligence Model**:

1.  **Tier 1 (Spinal Cord)**: **Elixir Logic**.
    *   **Speed**: < 10ms.
    *   **Nature**: Deterministic, Hardcoded.
    *   **Role**: Reflexes, Safety Interlocks (Guardian).

2.  **Tier 2 (Hindbrain)**: **F# Heuristics**.
    *   **Speed**: < 100ms.
    *   **Nature**: Statistical, Algorithmic.
    *   **Role**: Anomaly Detection, Resource Balancing (OodaSupervisor).

3.  **Tier 3 (Forebrain)**: **OpenRouter AI**.
    *   **Speed**: ~500ms - 2s.
    *   **Nature**: Semantic, Teleological.
    *   **Role**: Strategic Planning, Root Cause Analysis, "Why" answering.

---

## 2.0 The Protocol (7-Level Detail)

### Level 1: Cellular (API Client)
*   **Component**: `Indrajaal.AI.OpenRouterClient` (Elixir) or `Cepaf.AI.OpenRouter` (F#).
*   **Protocol**: HTTPS/JSON.
*   **Security**: API Key stored in `data/kms/secrets.json` (Vault).

### Level 2: Component (The Oracle)
*   **Pattern**: **The Oracle**. Agents do not call OpenRouter directly. They send a `Query` to the `Oracle` GenServer.
*   **Caching**: Semantic Caching (Vector similarity) to save tokens and latency.

### Level 3: Integration (Zenoh)
*   **Topic**: `indrajaal/cortex/query`.
*   **Payload**: `{"context": "...", "prompt": "...", "constraints": [...]}`.

### Level 4: Operational (Rate Limiting)
*   **Throttle**: Strict Token Bucket to prevent billing explosions.
*   **Circuit Breaker**: Fallback to Tier 2 (Heuristics) if Internet is down.

### Level 5: Metabolic (Cost/Benefit)
*   **Metric**: "Intelligence per Dollar".
*   **Optimization**: Use cheaper models (Flash) for routine tasks, smarter models (Pro) for critical RCA.

### Level 6: Evolutionary (Learning)
*   **Feedback**: Successful OpenRouter suggestions are logged to `training_data.parquet` to fine-tune the future Local LLM.

### Level 7: Strategic (The Air Gap)
*   **Safety**: **Simplex Architecture**.
    *   OpenRouter suggests: "Restart database to fix memory leak."
    *   Guardian (Local) checks: "Is restart allowed? Is quorum > 2? Is database corrupted?"
    *   Action: Only executed if Guardian approves. **The Cloud AI never touches the steering wheel directly.**

---

## 3.0 Implementation Roadmap

1.  **Secret Management**: Add OpenRouter Key handling to `sa-up`.
2.  **Client Implementation**: Create the F# Client in `Indrajaal.Cortex`.
3.  **Integration**: Replace the "Mock Adapter" in Phase 4 with the real OpenRouter client.

---

## 4.0 Conclusion
OpenRouter is a viable **Acceleration Vector**. It allows us to build the "Bicameral Mind" logic *now* (Phase 4), while the "Local Fabric" (Hardware) catches up (Phase 5).
