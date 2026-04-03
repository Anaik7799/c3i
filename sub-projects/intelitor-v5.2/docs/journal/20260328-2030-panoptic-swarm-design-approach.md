# Comprehensive Design & Implementation Approach: Panoptic Swarm Ignition

**Date**: 20260328-2030 CEST
**Status**: ACTIVE
**Author**: Gemini (Cybernetic Architect)
**Classification**: SIL-6 BIOMORPHIC INFRASTRUCTURE

## 1. System Overview: The F# Orchestration Plane
The "Panoptic Swarm Ignition" migrates the system's infrastructure logic from imperative shell/Elixir scripts to a declarative, type-safe F# model. This plane governs the "Genome" (container definitions), the "Morphogenesis" (container synthesis), and the "Homeostasis" (ongoing health and scaling).

### 1.1 Core Components
- **Genome Repository (`Artifacts.fs`)**: Contains embedded strings of canonical Dockerfiles and Compose templates.
- **Configuration ADTs (`ComposeTypes.fs`)**: Mathematical models of Services, Networks, Volumes, and Security Profiles.
- **Synthesis Engine (`PanopticIgnition.fs`)**: Verifies substrate integrity and builds missing components.
- **Swarm Controller (`SIL6MeshCLI.fs`)**: Transactional orchestrator using Podman API and Zenoh telemetry.

---

## 2. Fractal Layer Migration & Control Checks

### L0: Runtime (Code & Genome)
- **Migration**: Dockerfiles are moved from project root into F# `module Artifacts`.
- **Control Check**: `verifyArtifact` checks if the disk version has drifted from the embedded "Genome". If `Dockerfile.db` is modified manually, the F# engine detects "Genetic Drift" and triggers a re-synthesis or a halt.

### L1: Function (Execution & Contracts)
- **Migration**: Environment variables (e.g., `POSTGRES_PORT`) are moved from `.env` to F# `EnvironmentConfig.fs`.
- **Control Check**: Type-level enforcement ensures `PortMapping` protocol matches service expectations (e.g., preventing a UDP mapping for a TCP database).

### L2: Component (Service Cohesion)
- **Migration**: `podman-compose.yml` logic is moved to `createSil6FullMesh()` builder.
- **Control Check**: Service dependency validation. F# verifies that `DependsOn` services exist in the `MeshConfig` before allowing YAML generation.

### L3: Holon (Data & State)
- **Migration**: SQLite/DuckDB volume paths are managed via `DatabasePath.fs`.
- **Control Check**: **Volume Shadowing Safeguard (Axiom 0.2)**. F# checks if a host volume source is empty and would shadow critical container config files (like `/etc/nginx/nginx.conf`).

### L4: Container (Isolation & Runtime)
- **Migration**: Orchestration calls to `podman-compose` are replaced by F# `Process.Start` calls with detailed stdout/stderr streaming.
- **Control Check**: Rootless Podman enforcement. F# validates the `PODMAN_USER_NS` and `localhost/` registry prefix for all images.

### L5: Node (Hardware Metabolism)
- **Migration**: Static CPU/RAM limits are moved to `MetabolicTools.fs`.
- **Control Check**: **Metabolic Scaling**. F# detects host CPU count and automatically computes `ELIXIR_ERL_OPTIONS="+S N:N"` and `MIX_OS_DEPS_COMPILE_PARTITION_COUNT`.

### L6: Cluster (Consensus & Quorum)
- **Migration**: 3-node HA cluster setup logic is encoded in `createAppContainer(appNum)`.
- **Control Check**: **2oo3 Voting Gate**. The orchestrator waits for a quorum of nodes to report `service_healthy` over Zenoh before proceeding to the next boot wave.

### L7: Federation (Mesh Invariants)
- **Migration**: Global topology defined in `MeshConfig.fs`.
- **Control Check**: **Founder's Covenant Check**. Guardian verifies that the ignition plan does not violate Ω₀ (Survival/Lineage preservation) by checking the security profile of the proposed mesh.

---

## 3. High-Fidelity Observability (Zenoh + OTel)

- **Zenoh `[Thinking]` Stream**: The F# engine uses `logThinking` to publish its internal decision state (e.g., "Analyzing genome for indrajaal-db-prod...") to `indrajaal/ignition/thinking`.
- **OTel Spans**: Each synthesis stage (GenomicCheck -> NixBuild -> PodmanLoad) creates a nested OTel span, allowing the dashboard to show precise bottleneck analysis.
- **Fractal RCA**: If `Phase 2 (Foundation)` fails, the engine automatically triggers `SevenLevelRCA.analyze` and publishes the report to `indrajaal/ignition/errors`.

---

## 4. Implementation Steps

1.  **Phase 1**: Populate `Artifacts.fs` with all Dockerfile/Compose content.
2.  **Phase 2**: Implement the `ComposeGenerator.fs` to output valid `podman-compose.yml` from F# types.
3.  **Phase 3**: Wire `PanopticIgnition.fs` into the main `cepaf` daemon loop.
4.  **Phase 4**: Add the "Ignition Dashboard" to Prajna LiveView, consuming the Zenoh `indrajaal/ignition/*` topics.
