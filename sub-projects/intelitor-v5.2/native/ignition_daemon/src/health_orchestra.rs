//! # Health Orchestra — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (FPPS 5-Method Consensus) |
//! | Element   | Health / Consensus / Voting |
//!
//! ## FPPS 5-Method Architecture
//! ```text
//! Method 1: Running        ──╮
//! Method 2: PortOpen       ──┤
//! Method 3: ServiceEndpoint──┤──→ Vote(≥3/5) ──→ Consensus
//! Method 4: QuorumVote     ──┤
//! Method 5: DigitalTwin    ──╯
//! ```
//!
//! All 5 methods run concurrently via `tokio::join!`. A container is considered
//! healthy only when `HEALTH_CONSENSUS_THRESHOLD` (3) or more methods agree.
//!
//! ## STAMP
//! - SC-SIL4-006: 2oo3 voting MANDATORY for safety-critical decisions
//! - SC-VAL-003: FPPS consensus required for health validation
//! - SC-BOOT-006: All containers MUST pass health check before boot completes
//! - Omega-5: Validation Consensus — 5-Method FPPS MUST agree
//!
//! ## Source Mapping
//! - HealthCoordinator.fs:255-286 (FPPS 5-point consensus, threshold definitions)
//! - PanopticIgnition.fs:722-981 (genome definitions, container ports)
//! - capture-ignition.sh:158-175 (health check type dispatch)
//!
//! ## FMEA Coverage
//! | FM | Mode | RPN | Mitigation |
//! |----|------|-----|------------|
//! | FM-01 | Container not running | 56 | method_running fails gracefully → passed=false |
//! | FM-02 | Port unreachable | 54 | method_port_open returns passed=false |
//! | FM-03 | Service probe timeout | 48 | 3s inner timeout, no panic |
//! | FM-04 | Zenoh mesh partition | 48 | method_quorum_vote fails → 1 of 5 down |
//! | FM-05 | Digital twin mismatch | 32 | method_digital_twin returns detail in result |

use crate::errors::IgnitionError;
use crate::health;
use crate::podman;
use crate::types::*;
use log::{debug, info, warn};
use std::time::{Duration, Instant};

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

/// Run FPPS 5-method consensus health check on a single container.
///
/// All 5 methods execute concurrently via `tokio::join!` for minimum latency.
/// The overall result is determined by counting the number of methods that
/// return `passed: true`. If `agreed >= HEALTH_CONSENSUS_THRESHOLD` (3/5),
/// `consensus_reached` is `true`.
///
/// # STAMP
/// - SC-SIL4-006: 2oo3 voting MANDATORY for safety-critical decisions
/// - SC-VAL-003: FPPS consensus required
/// - Omega-5: 5-Method FPPS MUST agree
///
/// # Arguments
/// - `container`: Container name (e.g. `"indrajaal-ex-app-1"`)
/// - `primary_port`: The container's primary service port for the PortOpen method
/// - `service_check`: The type-specific health check for the ServiceEndpoint method
pub async fn check_consensus(
    container: &str,
    primary_port: u16,
    service_check: &HealthCheckType,
) -> HealthConsensus {
    debug!(
        "[Orchestra] Starting FPPS 5-method consensus for {} (port {})",
        container, primary_port
    );

    // Run all 5 methods concurrently — SC-SIL4-006: parallel voting
    let (r1, r2, r3, r4, r5) = tokio::join!(
        method_running(container),
        method_port_open(container, primary_port),
        method_service_endpoint(container, service_check),
        method_quorum_vote(container),
        method_digital_twin(container, primary_port),
    );

    let methods = vec![r1, r2, r3, r4, r5];
    let total = methods.len() as u32;
    let agreed = methods.iter().filter(|m| m.passed).count() as u32;
    let consensus_reached = agreed >= HEALTH_CONSENSUS_THRESHOLD;
    let overall_status = compute_status(agreed, total);

    if consensus_reached {
        info!(
            "[Orchestra] {} consensus REACHED: {}/{} methods passed → {:?}",
            container, agreed, total, overall_status
        );
    } else {
        warn!(
            "[Orchestra] {} consensus NOT reached: {}/{} methods passed (need {}) → {:?}",
            container, agreed, total, HEALTH_CONSENSUS_THRESHOLD, overall_status
        );
        // Log which methods failed to aid diagnosis
        for m in &methods {
            if !m.passed {
                warn!(
                    "[Orchestra]   FAIL  {:?} ({}ms): {}",
                    m.method, m.latency_ms, m.detail
                );
            } else {
                debug!(
                    "[Orchestra]   PASS  {:?} ({}ms): {}",
                    m.method, m.latency_ms, m.detail
                );
            }
        }
    }

    HealthConsensus {
        container_name: container.to_string(),
        methods,
        agreed,
        total,
        consensus_reached,
        overall_status,
    }
}

/// Run FPPS consensus health check on ALL 16 SIL-6 genome containers in parallel.
///
/// Spawns one `check_consensus` task per container and collects results.
/// Uses `futures::future::join_all` semantics via manual `tokio::spawn` + join
/// to maximize throughput without blocking the runtime.
///
/// # STAMP
/// - SC-IGNITE-008: sil6Genome MUST cover all 16 containers
/// - SC-SWARM-001: Full parallelization MUST be default
/// - SC-BOOT-006: All containers pass health check
pub async fn check_all_containers() -> Vec<HealthConsensus> {
    let containers = genome_containers();
    info!(
        "[Orchestra] Starting FPPS consensus for all {} genome containers",
        containers.len()
    );

    // Spawn concurrent tasks for all 16 containers
    let mut handles = Vec::with_capacity(containers.len());

    for (name, port, check_type) in containers {
        let handle = tokio::spawn(async move { check_consensus(&name, port, &check_type).await });
        handles.push(handle);
    }

    // Collect results, substituting a safe Unknown consensus on join failure
    let mut results = Vec::with_capacity(handles.len());
    for handle in handles {
        match handle.await {
            Ok(consensus) => results.push(consensus),
            Err(join_err) => {
                warn!("[Orchestra] Task join error: {}", join_err);
                // Produce a minimal failed consensus record so the caller is
                // never left with a shorter-than-expected result set.
                results.push(HealthConsensus {
                    container_name: "unknown".to_string(),
                    methods: vec![],
                    agreed: 0,
                    total: 0,
                    consensus_reached: false,
                    overall_status: HealthStatus::Unknown,
                });
            }
        }
    }

    let passed = results.iter().filter(|c| c.consensus_reached).count();
    info!(
        "[Orchestra] All-container check complete: {}/{} containers healthy",
        passed,
        results.len()
    );

    results
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 1: RUNNING
// ═══════════════════════════════════════════════════════════════════════════════

/// Method 1: Container Running check.
///
/// Uses `podman inspect .State.Status` via `crate::health::check_running`.
/// A container that is `"running"` passes; any other state (created, exited,
/// paused, dead) is treated as not-running.
///
/// # Failure modes
/// - Container does not exist → `Err` → `passed: false`
/// - Container in non-running state → `Ok(false)` → `passed: false`
async fn method_running(container: &str) -> HealthMethodResult {
    let start = Instant::now();
    let result = health::check_running(container).await;
    let latency_ms = start.elapsed().as_millis() as u64;

    match result {
        Ok(true) => {
            debug!("[Orchestra/M1] {} running ✓ ({}ms)", container, latency_ms);
            HealthMethodResult {
                method: HealthMethod::Running,
                passed: true,
                latency_ms,
                detail: "container state=running".to_string(),
            }
        }
        Ok(false) => {
            debug!(
                "[Orchestra/M1] {} not running ({}ms)",
                container, latency_ms
            );
            HealthMethodResult {
                method: HealthMethod::Running,
                passed: false,
                latency_ms,
                detail: "container state != running".to_string(),
            }
        }
        Err(e) => {
            debug!(
                "[Orchestra/M1] {} error ({}ms): {}",
                container, latency_ms, e
            );
            HealthMethodResult {
                method: HealthMethod::Running,
                passed: false,
                latency_ms,
                detail: format!("inspect error: {}", e),
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 2: PORT OPEN
// ═══════════════════════════════════════════════════════════════════════════════

/// Method 2: TCP Port Open check.
///
/// Probes the container's primary port from inside the container using
/// `nc -z localhost {port}`. A 3-second timeout prevents blocking.
///
/// Containers with `primary_port == 0` (e.g. ml-runner-1/2 which have no
/// declared service port) automatically pass this check — their service
/// presence is verified by other methods.
///
/// # Failure modes
/// - Port not listening → `nc -z` exits non-zero → `passed: false`
/// - Podman exec fails (container not running) → `passed: false`
async fn method_port_open(container: &str, port: u16) -> HealthMethodResult {
    let start = Instant::now();

    // Containers with no declared port (e.g. pure worker containers) skip
    // the TCP probe and are granted a pass for this method so they are not
    // penalised for a port they deliberately do not expose.
    if port == 0 {
        let latency_ms = start.elapsed().as_millis() as u64;
        debug!(
            "[Orchestra/M2] {} port=0, skipping TCP probe ({}ms)",
            container, latency_ms
        );
        return HealthMethodResult {
            method: HealthMethod::PortOpen,
            passed: true,
            latency_ms,
            detail: "port=0: no service port declared (worker container)".to_string(),
        };
    }

    let result = health::check_port(container, port, Duration::from_secs(3)).await;
    let latency_ms = start.elapsed().as_millis() as u64;

    match result {
        Ok(true) => {
            debug!(
                "[Orchestra/M2] {} port {} open ✓ ({}ms)",
                container, port, latency_ms
            );
            HealthMethodResult {
                method: HealthMethod::PortOpen,
                passed: true,
                latency_ms,
                detail: format!("port {} accepting connections", port),
            }
        }
        Ok(false) => {
            debug!(
                "[Orchestra/M2] {} port {} closed ({}ms)",
                container, port, latency_ms
            );
            HealthMethodResult {
                method: HealthMethod::PortOpen,
                passed: false,
                latency_ms,
                detail: format!("port {} not reachable", port),
            }
        }
        Err(e) => {
            debug!(
                "[Orchestra/M2] {} port {} error ({}ms): {}",
                container, port, latency_ms, e
            );
            HealthMethodResult {
                method: HealthMethod::PortOpen,
                passed: false,
                latency_ms,
                detail: format!("port probe error: {}", e),
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 3: SERVICE ENDPOINT
// ═══════════════════════════════════════════════════════════════════════════════

/// Method 3: Service Endpoint check.
///
/// Dispatches a type-specific probe based on the container's `HealthCheckType`:
///
/// | Variant | Probe |
/// |---------|-------|
/// | `PgIsReady` | `pg_isready -U postgres` inside container |
/// | `Http(url)` | `curl -sf {url}` with 5s timeout |
/// | `TcpPort(p)` | `nc -z localhost {p}` inside container |
/// | `Running` | `podman inspect .State.Status` |
///
/// This method is deliberately independent of Method 2 (PortOpen): the two
/// can disagree (e.g. port listening but HTTP 500) giving the consensus a
/// richer signal.
async fn method_service_endpoint(container: &str, check: &HealthCheckType) -> HealthMethodResult {
    let start = Instant::now();

    let result = match check {
        HealthCheckType::PgIsReady => {
            health::check_postgres(container, Duration::from_secs(5)).await
        }
        HealthCheckType::Http(url) => health::check_http(url, Duration::from_secs(5)).await,
        HealthCheckType::TcpPort(port) => {
            health::check_port(container, *port, Duration::from_secs(3)).await
        }
        HealthCheckType::Running => health::check_running(container).await,
    };

    let latency_ms = start.elapsed().as_millis() as u64;
    let check_label = check_type_label(check);

    match result {
        Ok(true) => {
            debug!(
                "[Orchestra/M3] {} service ({}) ✓ ({}ms)",
                container, check_label, latency_ms
            );
            HealthMethodResult {
                method: HealthMethod::ServiceEndpoint,
                passed: true,
                latency_ms,
                detail: format!("{} probe passed", check_label),
            }
        }
        Ok(false) => {
            debug!(
                "[Orchestra/M3] {} service ({}) failed ({}ms)",
                container, check_label, latency_ms
            );
            HealthMethodResult {
                method: HealthMethod::ServiceEndpoint,
                passed: false,
                latency_ms,
                detail: format!("{} probe failed", check_label),
            }
        }
        Err(e) => {
            debug!(
                "[Orchestra/M3] {} service ({}) error ({}ms): {}",
                container, check_label, latency_ms, e
            );
            HealthMethodResult {
                method: HealthMethod::ServiceEndpoint,
                passed: false,
                latency_ms,
                detail: format!("{} error: {}", check_label, e),
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 4: QUORUM VOTE
// ═══════════════════════════════════════════════════════════════════════════════

/// Method 4: Quorum Vote — Zenoh mesh connectivity check.
///
/// Verifies that the container can reach the Zenoh router at port 7447 from
/// inside the container network. A reachable Zenoh router implies the container
/// is a live participant in the mesh, which is a strong signal of correct
/// network configuration and mesh membership.
///
/// Uses `podman exec <container> sh -c "nc -z zenoh-router 7447"`.
/// This is the canonical mesh-level health signal per AOR-SWARM-VERIFY-004.
///
/// # STAMP
/// - SC-ZENOH-002: Zenoh router MUST be reachable from ALL app nodes
/// - AOR-SWARM-VERIFY-004: ALWAYS include Zenoh mesh visibility check
/// - SC-SIL4-006: Quorum-based decision
async fn method_quorum_vote(container: &str) -> HealthMethodResult {
    let start = Instant::now();

    let result = podman::podman_exec(
        container,
        &[
            "sh",
            "-c",
            &format!("nc -z zenoh-router {} 2>/dev/null", ZENOH_PORT),
        ],
        Duration::from_secs(5),
    )
    .await;

    let latency_ms = start.elapsed().as_millis() as u64;

    match result {
        Ok((_, _, 0)) => {
            debug!(
                "[Orchestra/M4] {} zenoh mesh reachable ✓ ({}ms)",
                container, latency_ms
            );
            HealthMethodResult {
                method: HealthMethod::QuorumVote,
                passed: true,
                latency_ms,
                detail: format!("zenoh-router:{} reachable from container", ZENOH_PORT),
            }
        }
        Ok((_, stderr, code)) => {
            debug!(
                "[Orchestra/M4] {} zenoh mesh unreachable (code={}, {}ms): {}",
                container,
                code,
                latency_ms,
                stderr.trim()
            );
            HealthMethodResult {
                method: HealthMethod::QuorumVote,
                passed: false,
                latency_ms,
                detail: format!("zenoh-router:{} unreachable (nc exit {})", ZENOH_PORT, code),
            }
        }
        Err(e) => {
            // Container may not be running — exec failure is a strong failure signal
            debug!(
                "[Orchestra/M4] {} quorum exec error ({}ms): {}",
                container, latency_ms, e
            );
            HealthMethodResult {
                method: HealthMethod::QuorumVote,
                passed: false,
                latency_ms,
                detail: format!("exec error: {}", e),
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METHOD 5: DIGITAL TWIN
// ═══════════════════════════════════════════════════════════════════════════════

/// Method 5: Digital Twin state verification.
///
/// Reads container metadata via `podman inspect` and checks two properties:
///
/// 1. `.State.Running` == `"true"` — the container is in running state
/// 2. Port binding present in `.NetworkSettings.Ports` — the expected service
///    port has an active host binding, confirming the container was started
///    with the correct port mapping.
///
/// For containers with `expected_port == 0` (worker containers without a
/// declared service port), only the running state is checked.
///
/// This method acts as a digital-twin cross-check: it reads the _expected_
/// configuration and verifies the _actual_ runtime state matches.
///
/// # STAMP
/// - SC-FUNC-008: Digital Twin MUST reflect actual state
/// - Psi-3 (Verification Capability): state is verifiable
async fn method_digital_twin(container: &str, expected_port: u16) -> HealthMethodResult {
    let start = Instant::now();

    // Inspect running state and port bindings in a single podman call.
    // Format: "<running> <ports_json>"
    let inspect_result =
        podman::podman_inspect(container, "{{.State.Running}} {{.NetworkSettings.Ports}}").await;

    let latency_ms = start.elapsed().as_millis() as u64;

    match inspect_result {
        Err(e) => {
            debug!(
                "[Orchestra/M5] {} inspect failed ({}ms): {}",
                container, latency_ms, e
            );
            HealthMethodResult {
                method: HealthMethod::DigitalTwin,
                passed: false,
                latency_ms,
                detail: format!("inspect failed: {}", e),
            }
        }
        Ok(output) => {
            let output = output.trim();

            // Field 1: running state — must start with "true"
            let is_running = output.starts_with("true");

            if !is_running {
                debug!(
                    "[Orchestra/M5] {} not running per inspect ({}ms): {:?}",
                    container, latency_ms, output
                );
                return HealthMethodResult {
                    method: HealthMethod::DigitalTwin,
                    passed: false,
                    latency_ms,
                    detail: format!("State.Running=false (inspect: {:?})", output),
                };
            }

            // Field 2: port binding (only checked when a service port is expected)
            if expected_port == 0 {
                debug!(
                    "[Orchestra/M5] {} running, no port required ✓ ({}ms)",
                    container, latency_ms
                );
                return HealthMethodResult {
                    method: HealthMethod::DigitalTwin,
                    passed: true,
                    latency_ms,
                    detail: "State.Running=true, port=0 (worker)".to_string(),
                };
            }

            // Check that the expected port string appears somewhere in the output.
            // `podman inspect` renders ports as e.g. `map[4000/tcp:[{0.0.0.0 4000}]]`
            let port_str = format!("{}/tcp", expected_port);
            let port_present =
                output.contains(&port_str) || output.contains(&expected_port.to_string());

            if port_present {
                debug!(
                    "[Orchestra/M5] {} running + port {} ✓ ({}ms)",
                    container, expected_port, latency_ms
                );
                HealthMethodResult {
                    method: HealthMethod::DigitalTwin,
                    passed: true,
                    latency_ms,
                    detail: format!("State.Running=true, port {}/tcp bound", expected_port),
                }
            } else {
                debug!(
                    "[Orchestra/M5] {} running but port {} missing ({}ms): {:?}",
                    container, expected_port, latency_ms, output
                );
                HealthMethodResult {
                    method: HealthMethod::DigitalTwin,
                    passed: false,
                    latency_ms,
                    detail: format!(
                        "State.Running=true but port {}/tcp not in NetworkSettings",
                        expected_port
                    ),
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSENSUS COMPUTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute the overall health status from the number of agreeing methods.
///
/// | agreed | status |
/// |--------|--------|
/// | 5/5 | Healthy |
/// | 3-4/5 | Degraded |
/// | 1-2/5 | Unhealthy |
/// | 0/5 | Unreachable |
///
/// # STAMP
/// - SC-VAL-003: FPPS consensus thresholds
/// - SC-SIL4-006: Safety-critical threshold enforcement
fn compute_status(agreed: u32, total: u32) -> HealthStatus {
    if total == 0 {
        return HealthStatus::Unknown;
    }
    match agreed {
        n if n == total => HealthStatus::Healthy, // 5/5
        3 | 4 => HealthStatus::Degraded,          // 3/5 or 4/5
        1 | 2 => HealthStatus::Unhealthy,         // 1/5 or 2/5
        0 => HealthStatus::Unreachable,           // 0/5
        _ => HealthStatus::Unknown,
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GENOME CONTAINER LIST
// ═══════════════════════════════════════════════════════════════════════════════

/// Return the complete SIL-6 genome container list with primary ports and
/// health check types.
///
/// Contains all 16 containers from `sil6Genome` in `PanopticIgnition.fs`.
///
/// # STAMP
/// - SC-IGNITE-008: sil6Genome MUST cover all 16 containers across 3 variants
/// - SC-SWARM-VERIFY-010: ContainerCategory MUST classify all 16 containers
///
/// # Layout
/// | Container | Port | CheckType |
/// |-----------|------|-----------|
/// | zenoh-router | 7447 | TcpPort(7447) |
/// | indrajaal-db-prod | 5433 | PgIsReady |
/// | indrajaal-obs-prod | 4317 | TcpPort(4317) |
/// | zenoh-router-1/2/3 | 7447 | TcpPort(7447) |
/// | indrajaal-ex-app-1/2/3 | 4000 | Http |
/// | cepaf-bridge | 9876 | TcpPort(9876) |
/// | indrajaal-cortex | 9877 | TcpPort(9877) |
/// | indrajaal-chaya | 4002 | TcpPort(4002) |
/// | indrajaal-ollama | 11434 | TcpPort(11434) |
/// | indrajaal-mojo | 11436 | TcpPort(11436) |
/// | indrajaal-ml-runner-1/2 | 0 | Running |
fn genome_containers() -> Vec<(String, u16, HealthCheckType)> {
    vec![
        // ── Tier 1: Zenoh Control Plane ────────────────────────────────────
        (
            "zenoh-router".to_string(),
            ZENOH_PORT,
            HealthCheckType::TcpPort(ZENOH_PORT),
        ),
        // ── Tier 2: Database Layer ─────────────────────────────────────────
        (
            "indrajaal-db-prod".to_string(),
            POSTGRES_EXTERNAL_PORT,
            HealthCheckType::PgIsReady,
        ),
        // ── Tier 3: Observability Layer ────────────────────────────────────
        (
            "indrajaal-obs-prod".to_string(),
            OTEL_GRPC_PORT,
            HealthCheckType::TcpPort(OTEL_GRPC_PORT),
        ),
        // ── Tier 4: Quorum Routers (SharedImage: zenoh-router) ────────────
        (
            "zenoh-router-1".to_string(),
            ZENOH_PORT,
            HealthCheckType::TcpPort(ZENOH_PORT),
        ),
        (
            "zenoh-router-2".to_string(),
            ZENOH_PORT,
            HealthCheckType::TcpPort(ZENOH_PORT),
        ),
        (
            "zenoh-router-3".to_string(),
            ZENOH_PORT,
            HealthCheckType::TcpPort(ZENOH_PORT),
        ),
        // ── Tier 5: Cognitive Layer ────────────────────────────────────────
        (
            "indrajaal-cortex".to_string(),
            CORTEX_PORT,
            HealthCheckType::TcpPort(CORTEX_PORT),
        ),
        (
            "cepaf-bridge".to_string(),
            BRIDGE_PORT,
            HealthCheckType::TcpPort(BRIDGE_PORT),
        ),
        // ── Tier 6: Seed App + Digital Twin + Ollama ──────────────────────
        (
            "indrajaal-ex-app-1".to_string(),
            PHOENIX_PORT,
            HealthCheckType::Http(format!("http://localhost:{}/health", PHOENIX_PORT)),
        ),
        (
            "indrajaal-chaya".to_string(),
            CHAYA_PORT,
            HealthCheckType::TcpPort(CHAYA_PORT),
        ),
        (
            "indrajaal-ollama".to_string(),
            OLLAMA_PORT,
            HealthCheckType::TcpPort(OLLAMA_PORT),
        ),
        // ── Tier 7: HA Replicas + ML Runners + Mojo ───────────────────────
        // SharedImage containers: ex-app-2, ex-app-3 share indrajaal-ex-app-1 image
        (
            "indrajaal-ex-app-2".to_string(),
            PHOENIX_PORT,
            HealthCheckType::Http(format!("http://localhost:{}/health", PHOENIX_PORT)),
        ),
        (
            "indrajaal-ex-app-3".to_string(),
            PHOENIX_PORT,
            HealthCheckType::Http(format!("http://localhost:{}/health", PHOENIX_PORT)),
        ),
        // ML runners: SharedImage from indrajaal-ollama; no declared service port
        (
            "indrajaal-ml-runner-1".to_string(),
            0,
            HealthCheckType::Running,
        ),
        (
            "indrajaal-ml-runner-2".to_string(),
            0,
            HealthCheckType::Running,
        ),
        // Mojo compute: PulledFromRegistry modular/max-serving
        (
            "indrajaal-mojo".to_string(),
            MOJO_PORT,
            HealthCheckType::TcpPort(MOJO_PORT),
        ),
    ]
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Return a short human-readable label for a `HealthCheckType` for use in log
/// messages and detail strings.
fn check_type_label(check: &HealthCheckType) -> String {
    match check {
        HealthCheckType::PgIsReady => "pg_isready".to_string(),
        HealthCheckType::Running => "running-state".to_string(),
        HealthCheckType::TcpPort(p) => format!("tcp:{}", p),
        HealthCheckType::Http(url) => {
            // Abbreviate long URLs: keep scheme + host + path, drop query
            let abbreviated = url.split('?').next().unwrap_or(url);
            format!("http({})", abbreviated)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // ── compute_status ───────────────────────────────────────────────────────

    #[test]
    fn test_compute_status_all_pass() {
        assert_eq!(compute_status(5, 5), HealthStatus::Healthy);
    }

    #[test]
    fn test_compute_status_four_pass() {
        assert_eq!(compute_status(4, 5), HealthStatus::Degraded);
    }

    #[test]
    fn test_compute_status_three_pass() {
        assert_eq!(compute_status(3, 5), HealthStatus::Degraded);
    }

    #[test]
    fn test_compute_status_two_pass() {
        assert_eq!(compute_status(2, 5), HealthStatus::Unhealthy);
    }

    #[test]
    fn test_compute_status_one_pass() {
        assert_eq!(compute_status(1, 5), HealthStatus::Unhealthy);
    }

    #[test]
    fn test_compute_status_none_pass() {
        assert_eq!(compute_status(0, 5), HealthStatus::Unreachable);
    }

    #[test]
    fn test_compute_status_zero_total() {
        assert_eq!(compute_status(0, 0), HealthStatus::Unknown);
    }

    // ── consensus_reached threshold ──────────────────────────────────────────

    #[test]
    fn test_consensus_threshold_constant() {
        // HEALTH_CONSENSUS_THRESHOLD must be 3 (2oo3 with two spares = 3oo5)
        assert_eq!(HEALTH_CONSENSUS_THRESHOLD, 3);
    }

    #[test]
    fn test_consensus_reached_at_threshold() {
        // 3/5 methods pass → consensus MUST be reached
        let agreed = 3u32;
        assert!(agreed >= HEALTH_CONSENSUS_THRESHOLD);
    }

    #[test]
    fn test_consensus_not_reached_below_threshold() {
        // 2/5 methods pass → consensus MUST NOT be reached
        let agreed = 2u32;
        assert!(agreed < HEALTH_CONSENSUS_THRESHOLD);
    }

    // ── genome_containers ────────────────────────────────────────────────────

    #[test]
    fn test_genome_containers_count() {
        // SC-IGNITE-008: sil6Genome MUST cover all 16 containers
        let containers = genome_containers();
        assert_eq!(
            containers.len(),
            16,
            "genome_containers must return exactly 16 entries"
        );
    }

    #[test]
    fn test_genome_containers_no_duplicate_names() {
        let containers = genome_containers();
        let mut names: Vec<&str> = containers.iter().map(|(n, _, _)| n.as_str()).collect();
        let original_len = names.len();
        names.sort_unstable();
        names.dedup();
        assert_eq!(
            names.len(),
            original_len,
            "genome_containers must not contain duplicate container names"
        );
    }

    #[test]
    fn test_genome_contains_all_zenoh_routers() {
        let containers = genome_containers();
        let zenoh_names: Vec<&str> = containers
            .iter()
            .filter_map(|(n, _, _)| {
                if n.starts_with("zenoh-router") {
                    Some(n.as_str())
                } else {
                    None
                }
            })
            .collect();
        // SC-SWARM-VERIFY-014: ZenohRouter category MUST include router + -1 + -2 + -3
        assert_eq!(zenoh_names.len(), 4, "expected 4 zenoh-router entries");
    }

    #[test]
    fn test_genome_contains_all_app_nodes() {
        let containers = genome_containers();
        let app_names: Vec<&str> = containers
            .iter()
            .filter_map(|(n, _, _)| {
                if n.starts_with("indrajaal-ex-app") {
                    Some(n.as_str())
                } else {
                    None
                }
            })
            .collect();
        // SC-SWARM-VERIFY-011: ElixirApp category MUST include app-1, app-2, app-3
        // (chaya is counted separately)
        assert_eq!(app_names.len(), 3, "expected 3 indrajaal-ex-app-* entries");
    }

    #[test]
    fn test_ml_runners_have_zero_port() {
        let containers = genome_containers();
        for (name, port, _) in &containers {
            if name.starts_with("indrajaal-ml-runner") {
                assert_eq!(
                    *port, 0,
                    "ml-runner {} should have port=0 (no service port)",
                    name
                );
            }
        }
    }

    #[test]
    fn test_db_uses_pg_isready() {
        let containers = genome_containers();
        let db = containers
            .iter()
            .find(|(n, _, _)| n == "indrajaal-db-prod")
            .expect("indrajaal-db-prod must be in genome");
        assert!(
            matches!(db.2, HealthCheckType::PgIsReady),
            "DB container must use PgIsReady check"
        );
    }

    #[test]
    fn test_app_nodes_use_http_check() {
        let containers = genome_containers();
        for (name, _, check) in &containers {
            if name.starts_with("indrajaal-ex-app") {
                assert!(
                    matches!(check, HealthCheckType::Http(_)),
                    "{} must use Http health check",
                    name
                );
            }
        }
    }

    // ── check_type_label ─────────────────────────────────────────────────────

    #[test]
    fn test_check_type_label_pg() {
        assert_eq!(check_type_label(&HealthCheckType::PgIsReady), "pg_isready");
    }

    #[test]
    fn test_check_type_label_running() {
        assert_eq!(check_type_label(&HealthCheckType::Running), "running-state");
    }

    #[test]
    fn test_check_type_label_tcp() {
        assert_eq!(
            check_type_label(&HealthCheckType::TcpPort(7447)),
            "tcp:7447"
        );
    }

    #[test]
    fn test_check_type_label_http_no_query() {
        let url = "http://localhost:4000/health".to_string();
        let label = check_type_label(&HealthCheckType::Http(url));
        assert_eq!(label, "http(http://localhost:4000/health)");
    }

    #[test]
    fn test_check_type_label_http_strips_query() {
        let url = "http://localhost:4000/health?verbose=true".to_string();
        let label = check_type_label(&HealthCheckType::Http(url));
        // Query string must be stripped
        assert!(!label.contains('?'), "label must not contain query string");
        assert!(label.contains("http://localhost:4000/health"));
    }
}
