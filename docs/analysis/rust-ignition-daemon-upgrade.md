# Rust Ignition Daemon: OODA and Podman API Upgrade

**Version:** 0.1.0 (Post EVO-1 to EVO-10 upgrade)
**Date:** 2026-04-04
**Domain:** C3I SIL-6 Biomorphic Mesh
**Component:** `ignition_daemon` (Rust)

## Executive Summary

The Rust Ignition Daemon has undergone a massive architectural shift from a reactive, CLI-scraping utility to a proactive, API-native orchestrator. The upgrade brings the daemon closer to full functional parity with the legacy F# CEPAF Mesh subsystem, implementing the first 10 waves of the Evolutionary (EVO) plan.

This upgrade replaces brittle `Command::new("podman")` calls and regex parsing with structured Podman REST API/MCP integrations via Unix Domain Sockets. It introduces a mathematically sound Dependency Graph (DAG) using `petgraph`, robust state tracking (Digital Twin), root cause analysis (7-Level RCA), and a strict <100ms OODA Supervisor loop.

## Architectural Shifts

### 1. Podman REST API Integration (EVO-1)
**Previous State:** The daemon relied heavily on `Command::new("podman")`, parsing raw stdout strings and exit codes. Build streams were parsed via regex.
**Current State:** 
- **`podman.rs`:** Implemented a lightweight HTTP/1.1 client over `tokio::net::UnixStream` (`/run/user/1000/podman/podman.sock`). Operations like `start_container`, `stop_container`, `container_exists`, and `image_exists` now use native REST calls.
- **`build_stream.rs`:** Direct consumption of Podman's line-delimited JSON streams. Eliminated regex fragility for cache-hit and error detection.
- **Determinism:** API failures yield strongly-typed HTTP status codes (e.g., 404, 409), ensuring accurate FMEA playbook routing.

### 2. OODA Supervisor (EVO-8)
**Previous State:** Reactive health checking. The daemon waited for a container to fail before acting.
**Current State:**
- **`ooda_supervisor.rs`:** A proactive "Brain". Implements the Observe -> Orient -> Decide -> Act loop.
- **Strict Timing:** The loop operates under a strict <100ms budget, enforced by `tokio::time::interval` and instrumented with `tracing` spans to catch latency breaches.
- **Shadow Mode:** `run_shadow_cycle()` allows the daemon to execute the loop and log decisions without taking action, enabling safe verification against the F# brain.

### 3. Stability and Hysteresis (EVO-4)
**Previous State:** Raw boolean health checks. A single dropped packet would cause a health check to fail, triggering immediate recovery.
**Current State:**
- **`hysteresis.rs`:** Introduces `HysteresisController`, a sliding-window state machine.
- **Flapping Mitigation:** Health transitions now require N-consecutive successes or failures (e.g., 3 successes / 2 failures). This effectively dampens transient network noise and prevents false-positive recovery cascades (RPN 192).

### 4. Graph Theory and Critical Path (EVO-7 & EVO-9)
**Previous State:** Hardcoded dependency lists and a rudimentary custom Kahn's algorithm implementation.
**Current State:**
- **`dag.rs`:** Fully utilizes the `petgraph` crate for mathematically proven topological sorting (`toposort`) and cycle detection (`is_cyclic_directed`). 
- **Config-Driven:** The DAG is hydrated from configuration rather than hardcoded.
- **`cpm.rs`:** Introduces the Critical Path Method. Calculates Forward/Backward passes (ES, EF, LS, LF) to determine total duration and slack tasks, unlocking future boot-time optimizations.

### 5. Diagnostics and State (EVO-5 & EVO-10)
- **`digital_twin.rs`:** Maps the expected configuration (`Genotype`) against the actual running container state (`Phenotype`) to detect drift in images, ports, and environment variables.
- **`seven_level_rca.rs`:** A diagnostic engine that categorizes errors across the 7 fractal layers. For example, "NIF compilation" routes to L1 Atomic Debug, while "quorum" issues map to L5 System.

### 6. High-Performance Telemetry and Safety (EVO-3 & EVO-6)
- **`zenoh_telemetry.rs`:** Switched from blocking publishes to a non-blocking `tokio::sync::mpsc` worker pattern.
- **`apoptosis.rs`:** Formalized the 6-phase dying gasp protocol. Incorporates SHA-256 state hashing for cryptographic auditing before triggering emergency stops.

## Subcommand Usage

The CLI (`main.rs`) has been expanded to expose the new capabilities:

```bash
# Build a specific container or all containers via the REST API
ignition build [--container NAME] [--force]

# Run the OODA Supervisor with specified tick interval
ignition ooda [--interval 100ms] [--cycles 100]

# Execute a 7-Level Root Cause Analysis on an error string
ignition rca <issue-description>

# Calculate and display the Critical Path for the boot sequence
ignition cpm

# Check the synchronization status of the Digital Twin
ignition twin

# Synchronize configuration over the Zenoh bridge
ignition config [--sync]
```

## Future Roadmap (EVO-11 & EVO-12)
With the foundational REST API and OODA intelligence in place, the next steps involve:
1. **TUI Integration (EVO-11):** Visualizing the OODA loop decisions, CPM slack times, and RCA reports in the `tui.rs` Ratatui dashboard.
2. **Config Hydration (EVO-12):** Fully replacing hardcoded genome constants with `sil6-genome.toml` parsed via `serde` and `figment`.