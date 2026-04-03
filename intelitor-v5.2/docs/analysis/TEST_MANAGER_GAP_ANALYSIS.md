# Test Manager Deep Analysis: Distributed Systems Verification
**Date**: 2026-01-05
**Context**: Benchmark against Jepsen, Testkube, Chaos Mesh
**Objective**: Define `Indrajaal.TestManager` Architecture

## 1.0 Industry Landscape (The "Internet" Benchmark)

### 1.1 Jepsen (Consistency Verification)
*   **Structure**: Controller Node (Clojure) + DB Nodes.
*   **Ontology**: `Test` (Generator + Checker + Nemesis).
*   **Key Feature**: "History" - a linearizable log of operations to prove correctness.
*   **Gap**: We lack a formal "History" validator that links inputs to outputs across the mesh.

### 1.2 Testkube (Kubernetes Native)
*   **Structure**: CRDs (Custom Resources) store Test Definitions.
*   **Ontology**: `Test` -> `Execution` -> `Artifacts` (Logs/Files).
*   **Key Feature**: Decoupling. The definition includes the *configuration* (Git revision, Env vars).
*   **Gap**: Our current runners mix configuration with execution logic.

### 1.3 Chaos Mesh (Resilience)
*   **Structure**: Workflow Engine (DAG).
*   **Ontology**: `Experiment` -> `Schedule` -> `Effect`.
*   **Key Feature**: Verification of "Steady State" before/after chaos.
*   **Gap**: Our Chaos Monkey is imperative; it needs to be declarative and tracked.

---

## 2.0 5-Level Deep Analysis (Indrajaal Test Manager)

### Level 1: Surface (Storage & Schema)
*   **Current**: Flat `test_runs` table.
*   **Requirement**: A **Relational Ontology**.
    *   `TestDefinition` (The invariant/logic).
    *   `SystemConfiguration` (The topology/env).
    *   `TestExecution` (The instance).
    *   `TelemetrySnapshot` (The logs/metrics at T=x).
    *   `CodeMutation` (The git hash/diff applied).

### Level 2: Flow (Data & Control)
*   **Current**: Shell scripts print to stdout; Logger scrapes it.
*   **Requirement**: **Bi-Directional Context**.
    *   The Test Manager must inject a `TraceID` into the runtime.
    *   The Runtime (App/DB) must emit telemetry tagged with that `TraceID`.
    *   The Manager correlates the two to determine "Verdict".

### Level 3: Semantic (Ontology & Meaning)
*   **Current**: Pass/Fail boolean.
*   **Requirement**: **Qualitative Verdicts**.
    *   `Pass` (Ideal).
    *   `Degraded` (Passed but KPI dropped).
    *   `Improvement` (Passed and KPI rose - Evolutionary gain).
    *   `Regression` (Failed due to code change).

### Level 4: Systemic (Evolutionary Impact)
*   **Current**: Snapshot views.
*   **Requirement**: **Trend Analysis**.
    *   The Manager must query historical runs to answer: "Did this code fix actually solve the root cause?"
    *   It must link `CodeCorrection` entities to `TestResult` delta.

### Level 5: Cybernetic (Feedback Loop)
*   **Current**: Human reads logs.
*   **Requirement**: **Automated Governance**.
    *   If `Regression` detected -> Auto-Rollback (SC-SIL6-026).
    *   If `Improvement` detected -> Update Baseline KPIs.

---

## 3.0 The `Indrajaal.TestManager` Specification

### 3.1 The Ontology (Schema)
```sql
TABLE test_definitions (id, name, type, stamp_constraints)
TABLE system_configs (id, topology_hash, env_vars, container_versions)
TABLE code_mutations (id, git_hash, description, changed_files)
TABLE test_executions (id, def_id, config_id, mutation_id, start_time, end_time, verdict)
TABLE telemetry_signals (id, execution_id, level, source, signal_data)
TABLE kpi_metrics (id, execution_id, name, value, baseline_delta)
```

### 3.2 Features
1.  **Context Injection**: Passes `TEST_EXECUTION_ID` to Podman containers.
2.  **Log Harvesting**: Scrapes Zenoh/JSON logs and associates them with the ID.
3.  **Baseline Comparison**: Calculates `evolutionary_impact` score.
