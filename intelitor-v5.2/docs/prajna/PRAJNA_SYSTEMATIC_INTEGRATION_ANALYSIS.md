# INDRAJAAL: Systematic Integration Analysis

**Identity Shift:** Indrajaal → Indrajaal (इन्द्रजाल)
**Goal:** Full biomorphic integration of the system into a fractal organism.

---

## 1.0 The Mental Model Transition (Level 1)

| Old Model (Indrajaal) | New Model (Indrajaal) | Concept |
| :--- | :--- | :--- |
| System | Indrajaal | The Net (The Whole). |
| Component/Module | Holon | A whole part (Jewel in the Net). |
| Health Check | Vital Signs | Continuous physiological signals ($\\Phi$). |
| Database | Long-Term Memory | Storage of genetic and metabolic history. |
| Cache | Working Memory | Transient state reflection. |
| Logger | Salience Stream | Perception of events in the net. |
| Dashboard | Cognitive Cockpit | The user's lens into the net. |

---

## 2.0 Architectural Mapping (Level 2)

### 2.1 The Fractal Interface
Every module in `lib/indrajaal/` (soon `lib/indrajaal/`) is being mapped to a **Holarchy Layer**.

1.  **Tissue Layer (`lib/indrajaal/core`)**: Foundation state (Tenants, Users).
2.  **Organ Layer (`lib/indrajaal/alarms`)**: Specialized functionality (Alarm Processing).
3.  **Neural Layer (`lib/indrajaal/cortex`)**: Intelligence & routing.
4.  **Membrane Layer (`lib/indrajaal/observability`)**: Filtering and sensing.

---

## 3.0 Functional Integration (Level 3)

### 3.1 The Neuro-Symbolic Spine
The `Cortex.Synapse` is the primary integration point. It orchestrates the OODA loop:
*   **Observe**: Collects `VitalSigns` from all jewels in the net.
*   **Orient**: Classifies signal complexity (Simple/Pattern/Cognitive).
*   **Decide**: Routes to the appropriate intelligence tier (Reflex/Cognition).
*   **Act**: Executes `SimplexProposal` through the F# Safety Kernel.


---

## 4.0 Information Model (The Genetic Code)

### 4.1 Unified Schema: The Genetic Payload
To support rapid evolution, messages are self-describing.

```elixir
defmodule Prajna.Bio.GeneticPayload do
  defstruct [
    :id,              # UUID
    :timestamp,       # UTC
    :genome_hash,     # Schema version (e.g., "v2.1-metrics")
    :dna,             # Actual data map
    :markers,         # Immunological tags (e.g., [:suspicious, :high_latency])
    :signature        # Cryptographic proof of origin
  ]
end
```

### 4.2 State Vector: Vital Signs
Every Holon exposes this standardized vector for the UI/Holographic display.

```elixir
defmodule Prajna.Bio.VitalSigns do
  defstruct [
    :health,      # 0.0 - 1.0 (Composite score)
    :stress,      # 0.0 - 1.0 (Queue length / Timeout ratio)
    :energy,      # 0.0 - 1.0 (Resource usage / Limit)
    :age,         # Uptime
    :generation,  # Restart count
    :intent       # Current FSM State atom
  ]
end
```

---

## 5.0 Intelligence Integration (Neuro-Symbolic)

### 5.1 Embedded Intelligence (Spinal)
*   **Location:** Inside the application BEAM node.
*   **Technology:** `Bumblebee` (Elixir) running quantized Transformers (BERT-Tiny).
*   **Function:** Zero-latency classification.
    *   *Input:* Log line.
    *   *Output:* Class (`:security_threat`, `:performance_degradation`, `:noise`).
    *   *Action:* Tag payload with `:markers`.

### 5.2 External Intelligence (Cortical)
*   **Location:** Cloud / Remote API (OpenRouter).
*   **Technology:** Large Context LLMs (Claude 3.5 Sonnet).
*   **Function:** Causal Analysis & Strategic Planning.
    *   *Input:* Aggregated "Episode" (Window of logs + metrics).
    *   *Output:* Natural Language Explanation + Recommended Plan.

---

## 6.0 Resilience & Defense (The Immune System)

### 6.1 The "Self" Model
The system defines "Self" via a whitelist of allowed behaviors and signatures. Anything deviating is "Non-Self" (Antigen).

### 6.2 Antibody Agents
*   **Lifecycle:** Spawn -> Patrol -> Bind -> Mark -> Die.
*   **Behavior:** Subscribe to specific PubSub topics. Apply predicate logic ("Is CPU > 90% AND User = 'System'?").
*   **Effect:** They do NOT kill. They **Mark**. They attach a `:pathogen` tag to the target Holon's membrane.

### 6.3 Killer T-Cells (The Executioners)
*   **Trigger:** When a Holon accumulates critical mass of `:pathogen` tags.
*   **Action:**
    1.  **Isolate:** Cut off input traffic (Membrane reject-all).
    2.  **Snapshot:** Dump state to crash log.
    3.  **Apoptosis:** Send `exit(:kill)`.
    4.  **Regenerate:** Supervisor restarts a clean instance (Next Generation).

---

## 7.0 Implementation Gap Analysis

| Component | Current Status (v1.0) | Target State (v2.0) | Integration Action |
|-----------|-----------------------|---------------------|--------------------|
| **SmartMetrics** | ETS Table + Trends | **Memory Holon** | Wrap ETS read/write in `Membrane` logic. Implement `VitalSigns` trait. |
| **AiCopilot** | Direct LLM Call | **Cortex Interface** | Move behind `Thalamus` router. Add Spinal pre-check. |
| **Orchestrator**| State Machine | **Motor Cortex** | Connect to `SimplexKernel` for command verification. |
| **PubSub** | Raw Messages | **Nervous System** | Wrap messages in `GeneticPayload`. |
| **DarkCockpit** | Static TUI | **Holographic TUI** | Update renderer to consume `VitalSigns` vectors recursively. |

---

## 8.0 Verification Strategy (Formal Methods)

1.  **Quint Model:** Model the "Simplex Kernel" logic. Prove that *no command reaches Actuators without validation*.
2.  **Property Tests:** `PropCheck` to generate random `GeneticPayloads` and ensure the `Membrane` correctly filters/accepts them.
3.  **Chaos Injection:** "Mara" agent to flood the system with valid-looking but malicious packets to test Antibody response time.

This analysis confirms that v2.0 is not a replacement but a **superset** wrapping v1.0 components in a biological control layer.
