# Deep Analysis: Robust Application Container Creation

**Task**: Review Rust preflight/ignition code, add robust application container creation, compare to F# CEPAF/scripts, and analyze full system implications across all fractal layers.

## 1. Code Comparison: Rust vs. F# vs. Bash Scripts

### 1.1 Bash Scripts (`capture-ignition.sh`)
*   **Approach**: Imperative, highly sequential.
*   **Robustness**: Relies on `set -euo pipefail`. Manually stops/removes containers, explicitly checks for build dependencies (`cargo`, native paths), and executes `podman build` with full `stdout`/`stderr` capture to log files.
*   **Pros**: Excellent observability during build/boot (I/O capture). Explicit pre-validation of the build environment.
*   **Cons**: Fragile, hard to maintain, lacks structured error handling or state recovery.

### 1.2 F# CEPAF (`Cepaf.Modules.Podman`)
*   **Approach**: Functional, declarative, utilizing `podman-compose`.
*   **Robustness**: Wraps `podman-compose` (e.g., `podman-compose -f <file> up -d`) using `IProcessRunner` with `asyncResult` for monadic error handling. It offloads the complexity of container networking, volume mounting, and environment variable injection to the `docker-compose.yml` specification.
*   **Pros**: High resilience because it leverages standard compose specifications. Clean error propagation (ROP pattern).
*   **Cons**: Requires the `podman-compose` Python wrapper, adding a system dependency outside of the compiled binary.

### 1.3 Rust Ignition Daemon (`launch.rs`)
*   **Approach**: Systems-level imperative.
*   **Robustness (Current)**: Currently hardcodes all 55 environment variables, network configurations, and volume mounts into a `Vec<String>` and executes `podman run`. It has a pre-creation check (`container_exists`) to remove stale containers.
*   **Pros**: Zero external dependencies (only needs the `podman` socket/binary). Extremely fast.
*   **Cons**: Hardcoded configuration is brittle. Changes to the container specification require recompiling the ignition daemon. Lacks the declarative simplicity of F#'s `podman-compose` approach.

## 2. Deep Analysis Across Fractal Layers

### L0: Constitutional (System Axioms)
*   **Implication**: Hardcoding container configurations in Rust violates the separation of concerns. The system's genetic makeup (container specs) should ideally be declarative and separate from the orchestrator (Axiom 0.2). Moving towards a robust creation mechanism means the Rust daemon needs to parse declarative definitions (like Compose or custom manifests) rather than embedding them.

### L1: Atomic (Base Primitives)
*   **Implication**: The Rust `podman_cmd` wrapper provides the atomic primitive. To achieve F# parity, this primitive needs to handle asynchronous streaming of I/O (like `capture-ignition.sh`) rather than just returning a final `Result<String, String>`.

### L2: Component (Services)
*   **Implication**: The application container (`indrajaal-ex-app-1`) is the heaviest component. Robust creation means ensuring its dependencies (Postgres, Zenoh) are not just running, but fully initialized (e.g., database schemas migrated) before the application container's main process starts. The Rust implementation needs init-containers or pre-run execution steps.

### L3: Transaction (State Management)
*   **Implication**: During container creation, the state transitions (Creating -> Created -> Starting -> Running) must be atomic. If `podman run` fails halfway, the system must rollback or retry without leaving orphaned volumes or networks. The Rust daemon needs an equivalent to F#'s transactional rollback logic.

### L4: System (Orchestration)
*   **Implication**: This is the core layer. Replacing F# `podman-compose` with pure Rust `podman run` requires the Rust daemon to implement its own dependency graph resolution and wave-based execution (which it currently does via `health_orchestra` and `launch`). Robust creation adds the requirement of validating image checksums and network topologies before launch.

### L5: Cognitive (AI & OODA)
*   **Implication**: The orchestrator must feed its creation state back into the OODA loop. When a container is robustly created, the `Act` phase is complete. The Rust daemon must emit telemetry (OTel spans) detailing the exact creation parameters so the Cortex can evaluate the launch performance.

### L6: Ecosystem (Mesh & Zenoh)
*   **Implication**: Robust container creation implies that the container is immediately wired into the Zenoh backplane. The Rust daemon must verify the `ZENOH_ROUTER_ENDPOINT` is resolvable within the container's network namespace immediately upon creation.

### L7: Federation (Cross-Cluster)
*   **Implication**: Future scaling requires deploying application containers across multiple physical nodes. A robust creation capability in Rust must eventually abstract away from local `podman` to a clustered API or utilize Zenoh to orchestrate launches on remote daemons.

## 3. Proposed Enhancements for Rust `launch.rs`

To achieve "robust application container creation" that surpasses the F# and Bash script capabilities:

1.  **Declarative Parsing**: Instead of hardcoded `vec![]`, parse `.env` files or a unified `ContainerManifest` struct.
2.  **Network & Volume Pre-Provisioning**: Explicitly create and verify networks and volumes before attempting `podman run`.
3.  **I/O Capture**: Implement real-time `stdout`/`stderr` logging to files during the `run` command, mimicking the `capture-ignition.sh` functionality but with Rust's async streams.
4.  **Health-Gated Launch**: Combine the `podman run` command with an immediate health probe to ensure the container doesn't just start, but actually initializes correctly.
