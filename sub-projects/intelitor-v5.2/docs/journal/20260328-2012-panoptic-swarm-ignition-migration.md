# Panoptic Swarm Ignition Migration Plan

**Date**: 20260328-2012 CEST
**Status**: IN_PROGRESS
**Author**: Gemini (Cybernetic Architect)
**Reference Plan**: `doc/plans/20260328-1800-panoptic-swarm-ignition-plan.md`

## 1. Objective
To migrate all container declarative and generative configurations from legacy Elixir scripts and static YAML files into a mathematically verified F# orchestrator (`cepaf`). This ensures "Genetic Re-Synthesis" of the swarm with 100% adherence to architectural control checks across all fractal layers.

## 2. Fractal Migration Strategy (L0-L7)

### L7: Federation (Mesh Topology)
- **Current**: Statically defined in `podman-compose-cluster.yml` and `lib/indrajaal/deployment/config.ex`.
- **Target**: `Cepaf.Knowledge.Topology` and `Cepaf.Config.MeshConfig`.
- **Migration**: F# logic will parse `Topology` records to generate Zenoh router connections and Tailscale peer configurations. ADTs in F# will verify that the graph is connected and lacks orphaned nodes.

### L6: Cluster (Consensus & Distribution)
- **Current**: EPMD and Distribution ports (4369, 9100+) manually mapped in YAML.
- **Target**: `Cepaf.Config.ComposeGenerator`.
- **Migration**: The F# generator will compute non-overlapping port ranges for HA clusters (3-node app clusters) and verify EPMD availability.

### L5: Node (Resource Allocation)
- **Current**: Hardcoded limits in YAML files.
- **Target**: `Cepaf.Metabolic.MetabolicTools`.
- **Migration**: Resource limits (CPU/RAM) will be derived from the system's "Metabolic" state. F# will inject `ELIXIR_ERL_OPTIONS` and `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` based on detected host core counts.

### L4: Container (Isolation & Podman)
- **Current**: Multiple `podman-compose-*.yml` files with variations in security levels.
- **Target**: `Cepaf.Podman.Domain.Specs` and `Cepaf.Podman.Api.Containers`.
- **Migration**: F# will use a "Security Profile" ADT (Secure, Dev, Open) to generate Podman specs. This enforces `localhost/` registry usage and `read-only` filesystems as type-level constraints.

### L3: Holon (Data Sovereignty & Persistence)
- **Current**: Volume mounts for SQLite/DuckDB in `data/`.
- **Target**: `Cepaf.Database.HolonDatabase`.
- **Migration**: F# will verify that volume source paths exist and do not shadow critical container directories (Axiom 0.2). It will use BLAKE3 hashes to ensure configuration file integrity.

### L2: Component (Services & Networking)
- **Current**: `depends_on` and network aliases in YAML.
- **Target**: `Cepaf.Podman.Api.Networks`.
- **Migration**: F# will construct a Directed Acyclic Graph (DAG) of service dependencies. Services like `indrajaal-app` will only be signaled to start after `indrajaal-db` passes the F# `HealthProbe`.

### L1: Function (Execution & Environment)
- **Current**: `.env` and `rel/env.sh.eex` for environment variables.
- **Target**: `Cepaf.Config.ConfigBridge`.
- **Migration**: Critical variables like `NO_TIMEOUT` and `PATIENT_MODE` will be strictly typed in F# and injected during the `Act` phase of the ignition OODA loop.

### L0: Runtime (Code Integrity)
- **Current**: Mix compilation checks.
- **Target**: `Cepaf.Config.ComposeGenerator` (compiled F#).
- **Migration**: The generation logic itself becomes a verified component. Any syntax error in the configuration generator is caught at F# compile-time, preventing the "unobserved error" state in production YAML.

## 3. High-Fidelity Observability
- **Zenoh**: The F# daemon will publish `[Thinking]` strings to `indrajaal/ignition/thinking` and status to `indrajaal/ignition/progress`.
- **OTel**: Every container start/stop will emit a span with metadata about the fractal layer check that authorized it.
- **MCP**: A new `swarm_ignition` tool will be added to the Sentinel MCP to allow fractal RCA on boot failures.

## 4. Risks and Mitigations
- **Volume Shadowing**: F# path resolution will block empty host volumes from masking config.
- **Port Collision**: Mathematical uniqueness check across all 14 container definitions.
- **State Drift**: The Immutable Register will store hashes of all generated configs.
