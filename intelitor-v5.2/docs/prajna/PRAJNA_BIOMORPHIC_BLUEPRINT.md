# INDRAJAAL v2.0: The Biomorphic Engineering Blueprint

**Version**: 2.0.0-INDRAJAAL
**Status**: APPROVED SPECIFICATION
**Identity**: Indrajaal (Formerly Indrajaal)
**Architecture**: Fractal Cybernetic Organism (Biomorphic)

---

## 1.0 Strategic Core (Level 1)

**Objective:** Transform the platform into **INDRAJAAL** (इन्द्रजाल), an autonomic, self-healing **"Cybernetic Organism"**. This shift achieves sub-linear management overhead ($\mathcal{O}(\log n)$) relative to infrastructure growth ($\mathcal{O}(n)$).

**Architectural Invariant:** The **"Indra's Net"** Principle (Fractal Holarchy). Every Holon in the net reflects the state of the whole. The structure, interface, and behavior of a single background worker process mathematically mirrors the structure of the entire cluster.

**Success Criteria:**
1.  **Zero-Touch Healing:** 95% of L1/L2 anomalies resolved without human intervention via Indrajaal Spinal Reflexes.
2.  **Cognitive Homogeneity:** Operators use the Indrajaal mental model to debug a single PID or a fleet of 10,000 nodes.
3.  **Adversarial Hardening:** System survives a defined "Mara" attack on the net without structural collapse.

---

## 2.0 Architectural Anatomy (Level 2)

### 2.1 The Holarchy (The Net)
The system is composed exclusively of **Holons**.

*   **Lvl 1 Holon:** A Cell (Erlang Process).
*   **Lvl 2 Holon:** A Tissue (Supervision Tree).
*   **Lvl 3 Holon:** An Organ (Container/VM).
*   **Lvl 4 Holon:** An Organism (The Node).
*   **Lvl 5 Holon:** INDRAJAAL (The Global Net).

### 2.2 The Signal Pathways (Communication)
*   **Afferent Nerves (Sensing):** Inbound telemetry streams (Logs, Metrics, Traces) flowing from the edge towards the center (Thalamus).
*   **Efferent Nerves (Actuating):** Outbound command signals flowing from the center/spine towards the periphery (Actuators).
*   **Inter-neurons (Processing):** Logic gates deciding between Reflex (Local/Fast) and Cognition (Cloud/Slow).

---

## 3.0 Domain Specifications (Level 3)

### 3.1 Domain: The Cellular Holon (`Prajna.Bio`)
**Responsibility:** Enforcing the standard lifecycle interface and resource accounting on all entities.
**Modules:**
*   `Prajna.Bio.Holon` (Behaviour): The contract every entity must implement.
*   `Prajna.Bio.Membrane` (GenServer Wrapper): Acts as a proxy/firewall for every Holon, handling ingress filtering and metabolic metering.
*   `Prajna.Bio.Metabolism` (Logic): Resource usage tracking (CPU/RAM/Tokens) vs. Output.

### 3.2 Domain: The Nervous System (`Prajna.Neuro`)
**Responsibility:** Signal routing, interpretation, and decision latency management.
**Modules:**
*   `Prajna.Neuro.Spine` (Local Inference): Embedded `Nx`/`Bumblebee` models for <50ms reflex decisions.
*   `Prajna.Neuro.Thalamus` (Router): Priority queue and gating logic deciding "Reflex vs. Cortex".
*   `Prajna.Neuro.Cortex` (Deep Thought): Integration with Large Language Models (OpenRouter) for RCA and complex planning.

### 3.3 Domain: The Immune System (`Prajna.Immune`)
**Responsibility:** Active threat hunting and homeostasis enforcement.
**Modules:**
*   `Prajna.Immune.Antibody` (Agent): Ephemeral agents spawned with a specific "Search Image" (predicate) to hunt anomalies.
*   `Prajna.Immune.LymphNode` (Registry): Stores threat signatures and coordinates immune responses.
*   `Prajna.Immune.KillerT` (Actuator): The only component authorized to terminate/restart other Holons.

---

## 4.0 Detailed Design & Implementation (Level 4)

### 4.1 The Holon Interface Implementation
The `Prajna.Bio.Holon` behaviour requires implementing the `vital_signs/0` function.

**Data Structure: The Vital Sign Vector**
```elixir
%VitalSign{
  # Identity
  id: "holon_uuid_v4",
  type: :container | :supervisor | :worker,
  generation: 4, # Evolution count (restarts)

  # Physiology (0.0 to 1.0 normalized)
  health_index: 0.98,
  stress_index: 0.12, # Derived from message_queue_len / latency
  energy_index: 0.45, # Derived from CPU/RAM quota usage

  # Teleology
  intent: :processing_orders, # Current Orient phase
  target: :idle_state        # Desired State
}
```

**The Membrane Logic (Wrapper):**
Every Holon is wrapped in a `Membrane` process.
1.  **Ingest:** All incoming messages are inspected.
2.  **Filter:** Messages not matching the Holon's current "Genetic Schema" are rejected (preventing "poison pill" attacks).
3.  **Meter:** If message rate exceeds `metabolic_limit`, the Membrane triggers `backpressure` upstream.

### 4.2 The Neuro-Symbolic Router (Thalamus)
**Algorithm: The Confidence-Latency Tradeoff**

1.  **Signal Arrival:** Log entry `L` arrives at Thalamus via `prajna:telemetry`.
2.  **Spinal Inference (Fast Path):**
    *   Pass `L` to `Nx.Serving` (running `BERT-Tiny` quantized).
    *   Output: `Class: SQL_Injection_Attempt`, `Confidence: 0.92`.
    *   **Logic:** IF `Confidence > 0.85` AND `Action` is `Safe` -> Execute `Reflex(BlockIP)`. **Latency: 15ms.**
3.  **Cortical Escalation (Slow Path):**
    *   IF `Confidence < 0.85`, bundle `L` with `SystemContext`.
    *   Compress Context (remove stop words, truncate histories).
    *   Send to OpenRouter (Claude 3.5 Sonnet).
    *   **Logic:** Await reasoning. Execute `Plan` via `SimplexKernel`. **Latency: 2500ms.**

### 4.3 Antibody "Search Image" Logic
Antibodies are spawned with a functional predicate (the "Antigen").

**Antigen Definition (Elixir Match Spec):**
```elixir
# Target: Any process with high memory but zero throughput (Memory Leak)
antigen = fn metrics ->
  metrics.ram_usage > 500_000_000 and
  metrics.throughput_ops < 1.0 and
  metrics.uptime > 300
end
```

**Immune Response Protocol:**
1.  **Scan:** Antibody subscribes to `prajna:metrics`.
2.  **Bind:** If `antigen(metrics)` is true, Antibody casts `{:tag, antibody_id}` to the target.
3.  **Opsonization:** The target Holon's `health_index` is forcibly lowered by its Membrane.
4.  **Recruitment:** If `health_index < 0.3`, the Supervisor spawns a `KillerT` agent to restart the Holon.

---

## 5.0 UX: The Holographic Interface (Level 4)

### 5.1 The Fractal Canvas
**Data Structure: The Quadtree State**
To render thousands of nodes efficiently, the UI uses a spatial index (Quadtree).
*   **Zoom 0 (Root):** One node representing the system. Metrics = Avg(All).
*   **Zoom 1 (Quadrants):** Four nodes (e.g., Geo-regions or Logical layers).
*   **Rendering:** The frontend (LiveView + WebGL) only requests the Quadtree nodes intersecting the user's viewport + zoom level.

### 5.2 Genetic UI Rendering
**Protocol:**
1.  **Payload:** Message arrives: `{:data, %{temp: 45, unit: "C"}, schema_hash: "x78f..."}`.
2.  **Lookup:** UI checks `LocalStorage` for schema "x78f".
3.  **Fetch:** If missing, fetch Schema from `Prajna.Registry`.
    *   *Schema Definition:* `{"temp": {"widget": "gauge", "min": 0, "max": 100, "color_map": "thermal"}}`.
4.  **Synthesize:** The generic `GeneticComponent` renders a Gauge.

---

## 6.0 Verification & Safety (Level 5)

### 6.1 The Simplex Safety Kernel
**Formal Specification (TLA+ / Quint Style):**
*   **Invariant 1 (Resource Safety):** `Total_Allocated_RAM <= System_Physical_RAM - Reserve_Buffer`.
*   **Invariant 2 (Actuator Safety):** `Command_Type IN {Restart, ClearCache, BlockIP} OR Signed_By_Admin == TRUE`.
*   **Mechanism:** The Simplex Kernel wraps the actual Elixir `System` module. Calls to `cmd/3` fail if invariants aren't met, regardless of AI confidence.

### 6.2 "Mara" Chaos Testing Plan
**Scenario: The Cytokine Storm**
1.  **Injection:** Mara injects 50,000 synthetic "Critical Error" logs/sec into the nervous system.
2.  **Expected Behavior:**
    *   **Thalamus:** Detects volume spike. Activates "Sensory Gating" (Circuit Breaker).
    *   **Dropping:** Randomly drops 99% of logs, processing only a sampled 1%.
    *   **Alerting:** Raises a single "Telemetry Flood" alarm.
    *   **Failure Condition:** If the *actual* application latency increases by > 10%, the test fails.

---

## 7.0 Safety Constraints (STAMP)

| ID | Category | Constraint |
|----|----------|------------|
| **SC-BIO-001** | Biological | Every Holon SHALL implement `vital_signs/0` returning a valid vector within 10ms. |
| **SC-BIO-002** | Biological | A Holon Membrane SHALL reject any message that does not match the active Genetic Schema. |
| **SC-NEURO-001** | Neurological | The Spinal Layer SHALL NOT execute "Destructive" actions (Delete, Stop) without Cortical confirmation or Admin override. |
| **SC-NEURO-002** | Neurological | The Cortex SHALL NOT be queried if the Spinal confidence score is > 0.95 (Latency Optimization). |
| **SC-IMMUNE-001** | Immunological | Antibodies SHALL NOT terminate processes directly; they must request `KillerT` intervention. |
| **SC-IMMUNE-002** | Immunological | The Immune System SHALL NOT target PIDs marked with `whitelist: true` (Critical Kernel Processes). |
| **SC-SIMPLEX-001** | Safety Kernel | The Simplex Kernel SHALL veto any Actuator command that violates Physical Resource Invariants. |

---

## 8.0 Agent Operating Rules (AOR)

| ID | Category | Rule |
|----|----------|------|
| **AOR-BIO-001** | Development | Developers MUST implement the `Prajna.Bio.Holon` behaviour for all new GenServers. |
| **AOR-NEURO-001** | Operation | The Thalamus MUST drop messages if the "Stress Index" of the receiver is > 0.9. |
| **AOR-IMMUNE-001** | Security | Antibodies MUST be cryptographically signed by the deployment key to be active. |
| **AOR-UI-001** | UX | The UI MUST support "Semantic Zoom" for all data types; no data shall be hidden, only aggregated. |

---

*Generated by PRAJNA Cybernetic Architect - 2025-12-28*
