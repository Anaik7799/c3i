# Total Fractal Rust Migration Plan (L0-L7)
**Version:** 4.0.0
**Status:** ACTIVE
**Date:** 2026-04-04

## 1. Objective
Complete the absolute migration of all remaining F# operational, testing, and cognitive functionality into native Rust (`ignition` and `planning_daemon`). This plan maps every remaining `sa-*` script across all 8 fractional (fractal) layers (L0-L7), applying FMEA, criticality, and operational utility constraints.

## 2. Fractional Layer Mapping & Criticality Matrix

| Layer | Component | Legacy F# Tool | Rust Target | Criticality | FMEA (RPN) | Operational Utility |
|:---|:---|:---|:---|:---:|:---:|:---|
| **L0** | Constitutional Safety | `sa-emergency.fsx` | `ignition emergency` | **SIL-6** | 252 | Critical (Apoptosis) - *MIGRATED* |
| **L0** | State Stabilization | `sa-stabilize.fsx` | `ignition stabilize` | **SIL-6** | 225 | High (Halt mutations) |
| **L1** | Atomic NIF | `sa-update-kms-schema` | `ignition kms-update` | **SIL-6** | 196 | High (Schema Migrations) |
| **L2** | Component Health | `sa-health.fsx` | `ignition verify` | **SIL-4** | 168 | High (FPPS Consensus) - *MIGRATED* |
| **L3** | Transaction / DB | `sa-patch-cubdb.fsx` | `ignition patch-db` | Med | 120 | Med (DB Maintenance) |
| **L4** | System Boot | `sa-sil6-boot.fsx` | `ignition full` | **SIL-4** | 180 | High (Execution) - *MIGRATED* |
| **L4** | System Supervisor | `sa-supervisor.fsx` | `ignition ooda` | **SIL-4** | 175 | High (Autonomous loop) - *MIGRATED* |
| **L5** | Cognitive Intent | `sa-plan` | `sa-plan-daemon` | **SIL-6** | 225 | High (Authority) - *MIGRATED* |
| **L5** | Genetic Synthesis | `sa-genotype.fsx` | `ignition genotype` | Med | 140 | High (Genome Mapping) |
| **L6** | Ecosystem / Mesh | `sa-mesh.fsx` | `ignition mesh` | Med | 120 | High (Topology View) |
| **L6** | Deploy | `sa-deploy.fsx` | `ignition deploy` | Med | 130 | Med (Artifact Sync) |
| **L7** | Federation / Multi | `sa-multiverse.fsx` | `ignition multiverse`| Med | 110 | High (Cross-Mesh Sync) |
| **L7** | Global Verification | `sa-verify-fractal`| `ignition verify-all`| **SIL-6** | 160 | High (L0-L7 Audit) |

## 3. Organic Evolutionary Approach
1. **Foundation (`sa-plan-daemon`)**: Decouple L5 cognitive intent into `sa-plan-daemon` using `ignition` as a baseline. (Completed)
2. **Lifecycle (`ignition` Core)**: Port L0 and L4 primitives (`down`, `scour`, `emergency`, `listen`, `logs`). (Completed)
3. **Genetic & Structural Migration (Current Phase)**: Port L5 `sa-genotype`, L6 `sa-mesh`, and L0 `sa-stabilize` to `ignition`.
4. **Federation Migration (Final Phase)**: Port L7 `sa-multiverse` and `sa-verify-fractal`.

## 4. FEMA (Failure Mode and Effects Analysis)
- **FMEA-001 (Config Drift)**: `sa-genotype` failing to map the DNA accurately could lead to container mismatches. *Mitigation*: Ensure `ignition genotype` reads the authoritative `digital_twin.rs` definitions.
- **FMEA-002 (Mesh Partitioning)**: `sa-mesh` reporting inaccurate topology. *Mitigation*: Use direct Zenoh scouting to verify live nodes.
- **FMEA-003 (State Corruption)**: `sa-patch-cubdb` executing during active transactions. *Mitigation*: Ensure DB patching only runs when `MeshState == Offline`.

## 5. Execution Steps for Remaining Components
1. **L5 Genotype**: Implement `src/genotype.rs` in `ignition` to output the current SIL-6 genome and environment variables in JSON or human-readable format.
2. **L6 Mesh**: Implement `src/mesh.rs` in `ignition` to display a tree view of the active Zenoh routers and connected clients.
3. **L0 Stabilize**: Implement `src/stabilize.rs` to broadcast an OODA pause command via Zenoh (`indrajaal/l5/ooda/pause`).
4. **L7 Multiverse**: Implement `src/multiverse.rs` to ping external mesh federations (e.g., ports 7448+).
5. **Bash Wrapper Swap**: Overwrite `sa-genotype.fsx`, `sa-mesh.fsx`, `sa-stabilize.fsx`, and `sa-multiverse.fsx` to call their respective `ignition` subcommands.
