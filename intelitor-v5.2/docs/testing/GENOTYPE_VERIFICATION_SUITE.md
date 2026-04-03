# COMPREHENSIVE TEST SUITE: Genotype Fidelity & Determinism

**Classification**: L7-KOSMOS (Identity Assurance)
**Target**: `GENOTYPE_HASH` Propagation
**Criticality**: P0 (System Integrity)

---

## 1.0 The 7-Level Verification Matrix

### L1: Cellular (Computation)
*   **Test**: `ComputeHash_Determinism`
*   **Action**: Run `sa-genotype.fsx` twice on same source.
*   **Expect**: Identical Hashes.
*   **Criticality**: **CRITICAL**. If this fails, the universe is non-deterministic.

### L2: Component (Injection)
*   **Test**: `Docker_Arg_Injection`
*   **Action**: Build container with `GENOTYPE_HASH=test_value`.
*   **Expect**: File `/workspace/GENOTYPE` contains `test_value`.
*   **Criticality**: **HIGH**. Failure means identity loss during birth.

### L3: Integration (Orchestration)
*   **Test**: `Compose_Env_Propagation`
*   **Action**: Run `sa-up.fsx`.
*   **Expect**: `podman inspect` shows `GENOTYPE_HASH` in Config.Env.
*   **Criticality**: **HIGH**. Failure means orchestrator amnesia.

### L4: Operational (Runtime)
*   **Test**: `Runtime_Env_Access`
*   **Action**: `System.get_env("GENOTYPE_HASH")` in Elixir.
*   **Expect**: Valid SHA256 string.
*   **Criticality**: **CRITICAL**. App must know itself.

### L5: Metabolic (Telemetry)
*   **Test**: `Pulse_Identity_Broadcast`
*   **Action**: Inspect Zenoh Heartbeat.
*   **Expect**: Payload includes `"genotype": "..."`.
*   **Criticality**: **MEDIUM**. Cortex needs to know who is talking.

### L6: Evolutionary (Validation)
*   **Test**: `IKE_Registry_Check`
*   **Action**: Compare Container Hash vs IKE `valid_genotypes`.
*   **Expect**: Match = Healthy. Mismatch = Quarantine.
*   **Criticality**: **CRITICAL**. Prevents rogue code execution.

### L7: Strategic (Sovereignty)
*   **Test**: `Founder_Directive_Binding`
*   **Action**: Change 1 byte of Directive. Re-calc Hash.
*   **Expect**: Hash changes -> System refuses to join cluster until re-authorized.
*   **Criticality**: **SUPREME**. The system obeys only its true self.

---

## 2.0 Criticality & Impact Analysis

| Event | Impact Level | Consequence | Mitigation |
| :--- | :--- | :--- | :--- |
| **Hash Collision** | Low | Identity spoofing (impossible with SHA256) | None needed. |
| **Hash Drift** | High | Container restarts reject config | Immutable Logs. |
| **Injection Fail** | Critical | "Unknown" Identity | Safe Mode (Read Only). |
| **Registry Corruption** | Critical | Total System Lockout | 2oo3 Voting on Registry. |

---

## 3.0 Execution Protocol
1.  **Generate**: `dotnet fsi sa-genotype.fsx`
2.  **Inject**: `podman build --build-arg ...`
3.  **Verify**: `sa-verify-all.fsx` (L0 Check)
