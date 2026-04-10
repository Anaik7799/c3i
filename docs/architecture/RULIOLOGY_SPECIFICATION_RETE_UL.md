# Ruliology Specification: RETE-UL Rule Engine (L5-Cognitive)
**Version**: 1.0.0
**Date**: 2026-04-10
**Mandate**: SC-COG-001, SC-ZMOF-001, SC-RUL-001

This document defines the formal "Ruliology" (Rule-based logic) governing the Indrajaal SIL-6 Mesh. The system employs a 13-domain RETE-UL rule engine implemented in Rust, providing <1ms deterministic decision making for mesh homeostasis.

## 1. Architectural Role
Ruliology resides at **L5-Cognitive**. It acts as the "Pre-Frontal Cortex" of the `ignition_daemon`, evaluating observations from L4 (System) and L6 (Ecosystem) to trigger deterministic actions before escalating to LLM advisors.

## 2. Rule Domains (13 Domains, 52 Rules)

| ID | Domain | Purpose | Key Decision |
|:---|:---|:---|:---|
| **D1** | **OODA Supervisor** | Mesh Homeostasis loop | `EmergencyStop`, `BootMesh`, `Restart` |
| **D2** | **Preflight Gate** | Boot sequence verification | `BlockBoot`, `WarnAndProceed`, `Pass` |
| **D3** | **Recovery Playbook** | Prioritized failure mitigation | `NifCompilation`, `CascadeContainment` |
| **D4** | **Health Consensus** | FPPS 5-method agreement | `Reached`, `Degraded`, `NotReached` |
| **D5** | **Cascade Containment**| Failure propagation control | `Apoptosis`, `IsolateTier`, `Monitor` |
| **D6** | **Partition Fencing** | Split-brain management | `FenceMajority`, `FenceMinority` |
| **D7** | **Launch Tier Gating** | Wave-parallel boot control | `HaltPipeline`, `ContinueWithWarning` |
| **D8** | **CPU Governor** | Resource load balancing | `Wait`, `HeavyThrottle`, `FullSpeed` |
| **D9** | **Verify Compliance** | SIL-6 assurance assessment | `Compliant`, `Degraded`, `NonCompliant` |
| **D10**| **Build Staleness** | Image lifecycle management | `Rebuild`, `Skip` |
| **D11**| **Apoptosis Grace** | Termination timing control | `Immediate`, `Fast2s`, `Graceful10s` |
| **D12**| **RCA Escalation** | Fractal layer fault mapping | `L1`, `L4`, `L6`, `L7_LLM` |
| **D13**| **Hysteresis Config** | Sensitivity adaptation | `Aggressive`, `Conservative`, `Default` |

## 3. Implementation Details (Rust)
- **Engine**: `rust_rule_engine` v1.20.1
- **Language**: GRL (Generic Rule Language)
- **Performance**: rules are parsed once via `OnceLock` and cached. Evaluation SLA < 1ms.
- **Source**: `sub-projects/c3i/native/ignition_daemon/src/rule_engine.rs`

## 4. Formal Invariants
- **SC-RUL-001**: Every OODA cycle MUST execute D1 rules.
- **SC-RUL-002**: Rules with higher Salience MUST be evaluated first.
- **SC-RUL-003**: The "No Action" rule MUST have the lowest salience in every domain.
- **SC-RUL-004**: If `RCA.Decision == "L7_LLM"`, the daemon MUST trigger an inference request to the Cognitive Layer.

## 5. Formal Verification (TLA+)
The rule transitions are modeled in `ChatPipeline.tla` and `Ignition.allium`, ensuring that no rule sequence leads to a deadlock state where the mesh is running but degraded without action.
