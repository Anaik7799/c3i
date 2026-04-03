# Fractal Knowledge Base Transformation Plan: The Holonic Architecture (v4.0.0)

**Version**: 4.0.0-OMNIPRESENT-INTEGRATION
**Status**: ACTIVE
**Zettel-ID**: 20251230-1500-FKB-PLAN-V4
**Author**: Gemini (Cybernetic Architect)
**Objective**: **Omnipresent Integration** of the Indrajaal Knowledge Engine (IKE). The Knowledge Base ceases to be a passive repository and becomes the **Central Nervous System**, integrated into Build, Test, Deploy, Runtime, and Self-Evolution loops.

---

## Level 1: Strategic Vision (Concept)

### 1.1 The Pivot: From "Reference" to "Nervous System"
In v3.2, IKE was an "Oracle". In v4.0, IKE becomes the **Nervous System**. It does not just *answer* questions; it *gates* actions and *metabolizes* experience.
*   **Builds** update the Knowledge Graph.
*   **Tests** verify the Knowledge Graph.
*   **Runtime** feeds back into the Knowledge Graph (closing the loop).

### 1.2 Core Principles (Omnipresent)
1.  **Gated Evolution**: No code evolves (commits/deploys) without IKE validation (Entropy/STAMP check).
2.  **Metabolic Feedback**: Runtime telemetry is not just logged; it is *digested* by IKE to update the "Truth" of the system (e.g., updating a Service's reliability score based on actual uptime).
3.  **Holographic Consistency**: The "Model" (Docs) and "Territory" (Runtime) are forced into convergence via continuous drift detection.

---

## Level 2: System Architecture (The Feedback Loops)

### 2.1 The Data Layer (DuckDB + Vector + Telemetry)
*   **`holons`**: (Static) The Design.
*   **`phenomena`**: (Dynamic) New table capturing runtime observations (Crash loops, Latency spikes, User interactions) linked to Holons.
*   **`drift_log`**: Quantified divergence between Design and Phenomena.

### 2.2 The Integration Layer (`Cepaf.Knowledge.Integrators`)
*   **`BuildHook`**: Intercepts `mix compile` / `dotnet build`.
*   **`TestListener`**: Intercepts ExUnit / Expecto results.
*   **`TelemetryBridge`**: Consumes Zenoh/Otel streams into DuckDB.
*   **`DeployGate`**: CEPAF orchestrator hook.

### 2.3 The Intelligence Layer (Active Gardening)
*   **Drift Detector**: "Service X is documented as 'Stable' but has crashed 5 times in 1 hour. Increase Entropy to 0.9. Trigger Alert."
*   **Auto-Refactor**: "Function Y is high complexity and high churn. Generate Refactoring PR via OpenRouter."

---

## Level 3: Operational Integration (The Lifecycle)

### 3.1 Build Time (`mix compile`)
**Constraint**: The Build System acts as a Sensor.
1.  **Scan**: On compilation, IKE scans changed files.
2.  **Verify**: Checks if changes violate STAMP constraints defined in the Knowledge Graph.
3.  **Update**: Updates `last_modified` and `line_count` metrics in DuckDB.
4.  **Inject**: Injects the latest `git_hash` and `graph_snapshot` into the build artifact (Genetic Payload).

### 3.2 Test Time (`mix test`)
**Constraint**: Tests verify the "Truth" of the Knowledge Base.
1.  **Execution**: Tests run as normal.
2.  **Feedback**: The `IKE.TestListener` formatter captures results.
    *   **Pass**: Updates linked Holon's `last_verified` timestamp. Lowers Entropy.
    *   **Fail**: Flags Holon as `broken`. Spikes Entropy to 1.0.
3.  **Coverage**: Calculates "Knowledge Coverage" (Docs vs. Code vs. Tests).

### 3.3 Deployment Time (CEPAF / Cockpit)
**Constraint**: No deployment of High-Entropy artifacts.
1.  **Request**: "Deploy Service A to Production."
2.  **Gate**: CEPAF queries IKE: `SELECT entropy_score, stamp_compliant FROM holons WHERE uuid = 'Service-A'`.
3.  **Decision**:
    *   If `entropy < 0.2` AND `compliant`: **Permit**.
    *   Else: **Reject** (Require human override or "Fix It" run).

### 3.4 Runtime (The Metabolic Loop)
**Constraint**: Runtime experience updates the Knowledge Model.
1.  **Telemetry**: Service A emits metrics (Latency, Errors) via Zenoh.
2.  **Digestion**: `IKE.TelemetryBridge` subscribes to the stream.
3.  **Update**:
    *   If `ErrorRate > Threshold`: Mark Holon `unstable`.
    *   If `Usage > Threshold`: Mark Holon `critical`.
4.  **Drift**: Compare *observed* behavior vs. *documented* behavior. Significant drift triggers a "Curiosity" event (AI investigates).

---

## Level 4: The Cockpit Integration (Human Interface)

### 4.1 The "Brain" Dashboard
A new Cockpit view dedicated to System Cognition.
*   **System Entropy Gauge**: Global health metric.
*   **Drift Heatmap**: Visualizing where Code != Docs.
*   **Memory Map**: Force-directed graph of Holons (using Vectors).

### 4.2 Interactive Actions
*   **"Fix This"**: Right-click a "Rotting" node $\to$ OpenRouter generates update.
*   **"Explain This"**: Right-click a Runtime Error $\to$ IKE correlates with Docs/Changes $\to$ OpenRouter RCA.

---

## Level 5: Implementation Guide (Updated)

### 5.1 Phase 1: Core Engine (DuckDB/F#)
(Same as v3.2)

### 5.2 Phase 2: The Integrators (New)
*   **Elixir**: Create `Indrajaal.Knowledge.MixTask` and `TelemetryHandler`.
*   **F#**: Update `Cepaf.Podman` to query IKE before container actions.

### 5.3 Phase 3: The Intelligence (New)
*   Implement `DriftDetector` logic in F# background worker.
*   Implement `TelemetryBridge` (Zenoh consumer).

---

## Level 6: Evolution (Self-Writing System)

### 6.1 The Ouroboros Loop
1.  **Code Changes** $\to$ Build Updates IKE.
2.  **Tests Pass** $\to$ IKE Lowers Entropy.
3.  **Runtime Stable** $\to$ IKE Marks "Proven".
4.  **Runtime Failure** $\to$ IKE Marks "Rot" $\to$ Triggers AI Refactor $\to$ **Code Changes**.

The system becomes capable of initiating its own repair cycles based on the friction between its Model (Knowledge) and Reality (Runtime).

---
**Verified By**: Gemini (Cybernetic Architect)
**Compliance**: STAMP Safety Constraints, 5-Level Architecture
**Status**: DEFINITIVE BLUEPRINT for v20.0.0