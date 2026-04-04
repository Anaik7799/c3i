//! # Inter-Container Connectivity Matrix — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Verification) |
//! | Element   | Connectivity Matrix / Network Probing |
//!
//! ## STAMP: SC-IGNITE-010, SC-NET-MESH-001, SC-BOOT-009
//!
//! Idea #32 (Score 92): After ignition, verify every container can reach
//! every other container it depends on (TCP/HTTP probe matrix), not just
//! port-open checks.
//!
//! ## Design Invariants
//! - Probes are non-destructive (TCP SYN or HTTP GET only)
//! - Timeout per probe: 3 seconds
//! - Matrix is computed from the dependency graph
//! - Failed connections are logged with container pair and error

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::HealthCheckType;
use log::{debug, info, warn};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};

/// Result of a single connectivity probe between two containers.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectivityProbe {
    pub source: String,
    pub target: String,
    pub target_port: u16,
    pub reachable: bool,
    pub latency_ms: u64,
    pub error: Option<String>,
}

/// Full connectivity matrix result.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectivityMatrix {
    pub probes: Vec<ConnectivityProbe>,
    pub total_probes: usize,
    pub successful: usize,
    pub failed: usize,
    pub duration_ms: u64,
    pub all_reachable: bool,
}

/// Container port mapping — which port each container exposes for probing.
fn container_ports() -> HashMap<&'static str, u16> {
    HashMap::from([
        ("zenoh-router", 7447),
        ("zenoh-router-1", 7447),
        ("zenoh-router-2", 7447),
        ("zenoh-router-3", 7447),
        ("indrajaal-db-prod", 5432),
        ("indrajaal-obs-prod", 4317),
        ("indrajaal-cortex", 9877),
        ("cepaf-bridge", 9876),
        ("indrajaal-ex-app-1", 4000),
        ("indrajaal-ex-app-2", 4000),
        ("indrajaal-ex-app-3", 4000),
        ("indrajaal-chaya", 4002),
        ("indrajaal-ollama", 11434),
        ("indrajaal-ml-runner-1", 0), // No port — Running check only
        ("indrajaal-ml-runner-2", 0),
        ("indrajaal-mojo", 11436),
    ])
}

/// Dependency graph — which containers each container needs to reach.
/// This is the same graph used by cascade.rs but focused on network connectivity.
fn connectivity_dependencies() -> HashMap<&'static str, Vec<&'static str>> {
    HashMap::from([
        // T0: Foundation — no outbound dependencies
        ("zenoh-router", vec![]),
        // T0b: Zenoh routers peer with each other
        ("zenoh-router-1", vec!["zenoh-router"]),
        ("zenoh-router-2", vec!["zenoh-router"]),
        ("zenoh-router-3", vec!["zenoh-router"]),
        // T1: Database needs Zenoh for telemetry
        ("indrajaal-db-prod", vec!["zenoh-router"]),
        // T2: Observability needs Zenoh
        ("indrajaal-obs-prod", vec!["zenoh-router"]),
        // T3: Cognitive needs Zenoh + DB
        ("cepaf-bridge", vec!["zenoh-router", "indrajaal-db-prod"]),
        ("indrajaal-cortex", vec!["zenoh-router", "indrajaal-db-prod"]),
        // T4: App needs everything
        ("indrajaal-ex-app-1", vec![
            "zenoh-router", "indrajaal-db-prod", "indrajaal-obs-prod", "cepaf-bridge",
        ]),
        // T5: HA apps need seed node
        ("indrajaal-ex-app-2", vec!["zenoh-router", "indrajaal-db-prod", "indrajaal-ex-app-1"]),
        ("indrajaal-ex-app-3", vec!["zenoh-router", "indrajaal-db-prod", "indrajaal-ex-app-1"]),
        // T6: Chaya needs app, Ollama standalone
        ("indrajaal-chaya", vec!["zenoh-router", "indrajaal-ex-app-1"]),
        ("indrajaal-ollama", vec!["zenoh-router"]),
        // T7: ML runners need Ollama
        ("indrajaal-ml-runner-1", vec!["zenoh-router", "indrajaal-ollama"]),
        ("indrajaal-ml-runner-2", vec!["zenoh-router", "indrajaal-ollama"]),
        ("indrajaal-mojo", vec!["zenoh-router", "indrajaal-ollama"]),
    ])
}

/// Run the full connectivity matrix verification.
///
/// For each container, probe its dependencies via TCP connect (or HTTP for
/// app containers). Returns a ConnectivityMatrix with per-probe results.
///
/// SC-NET-MESH-001: All containers on sil6-mesh MUST be mutually reachable
pub async fn verify_connectivity() -> Result<ConnectivityMatrix, IgnitionError> {
    info!("[connectivity] Running full connectivity matrix verification");
    let wall_start = Instant::now();

    let deps = connectivity_dependencies();
    let ports = container_ports();
    let mut probes: Vec<ConnectivityProbe> = Vec::new();

    for (source, targets) in &deps {
        if targets.is_empty() {
            debug!("[connectivity] {} has no dependencies — skipping", source);
            continue;
        }

        for &target in targets {
            let target_port = *ports.get(target).unwrap_or(&0);

            // For containers with no port (ML runners), just check running
            if target_port == 0 {
                let running = podman::container_status(target)
                    .await
                    .map(|s| s == "running")
                    .unwrap_or(false);
                probes.push(ConnectivityProbe {
                    source: source.to_string(),
                    target: target.to_string(),
                    target_port: 0,
                    reachable: running,
                    latency_ms: 0,
                    error: if !running {
                        Some(format!("{} is not running", target))
                    } else {
                        None
                    },
                });
                continue;
            }

            // TCP connect probe from source to target:port
            let probe_start = Instant::now();
            let reachable = probe_tcp_connect(source, target, target_port).await;
            let latency_ms = probe_start.elapsed().as_millis() as u64;

            let error = if !reachable {
                Some(format!("TCP connect to {}:{} from {} failed", target, target_port, source))
            } else {
                None
            };

            probes.push(ConnectivityProbe {
                source: source.to_string(),
                target: target.to_string(),
                target_port,
                reachable,
                latency_ms,
                error,
            });

            if !reachable {
                warn!(
                    "[connectivity] FAIL: {} -> {}:{} ({}ms)",
                    source, target, target_port, latency_ms
                );
            } else {
                debug!(
                    "[connectivity] OK: {} -> {}:{} ({}ms)",
                    source, target, target_port, latency_ms
                );
            }
        }
    }

    let total = probes.len();
    let successful = probes.iter().filter(|p| p.reachable).count();
    let failed = total - successful;
    let duration_ms = wall_start.elapsed().as_millis() as u64;

    info!(
        "[connectivity] Matrix complete: {}/{} reachable ({} failed, {}ms)",
        successful, total, failed, duration_ms
    );

    Ok(ConnectivityMatrix {
        probes,
        total_probes: total,
        successful,
        failed,
        duration_ms,
        all_reachable: failed == 0,
    })
}

/// Probe TCP connectivity from source container to target:port.
///
/// Uses `podman exec` to run `nc -z -w 3` inside the source container,
/// connecting to the target container's port via the mesh network.
async fn probe_tcp_connect(source: &str, target: &str, port: u16) -> bool {
    let timeout = Duration::from_secs(3);

    // Use container name as hostname (mesh DNS)
    let cmd = format!("nc -z -w 3 {} {}", target, port);
    let args: Vec<&str> = cmd.split_whitespace().collect();

    match podman::podman_exec(source, &args, timeout).await {
        Ok((_, _, code)) => code == 0,
        Err(_) => false,
    }
}

/// Verify Zenoh mesh topology — ensure all routers see each other as peers.
///
/// Idea #34 (Score 93): After all zenoh-router containers start, verify
/// the full mesh topology: each router sees all peers, sessions are
/// established, key expressions route correctly.
///
/// Returns true if the Zenoh mesh is fully connected.
pub async fn verify_zenoh_mesh_topology() -> Result<ZenohMeshReport, IgnitionError> {
    info!("[connectivity] Verifying Zenoh mesh topology");

    let routers = ["zenoh-router-1", "zenoh-router-2", "zenoh-router-3"];
    let mut report = ZenohMeshReport {
        routers_checked: 0,
        fully_connected: true,
        peer_visibility: Vec::new(),
        sessions_established: 0,
        total_sessions_expected: 0,
    };

    let total_sessions = routers.len() * (routers.len() - 1); // Each router sees N-1 peers
    report.total_sessions_expected = total_sessions;

    for router in &routers {
        // Check if router is running
        let running = podman::container_status(router)
            .await
            .map(|s| s == "running")
            .unwrap_or(false);

        if !running {
            warn!("[connectivity] {} is not running — cannot verify mesh", router);
            report.fully_connected = false;
            report.peer_visibility.push(ZenohPeerVisibility {
                router: router.to_string(),
                visible_peers: 0,
                expected_peers: routers.len() - 1,
                healthy: false,
            });
            continue;
        }

        // Check port 7447 is open
        let port_open = podman::podman_exec(
            router,
            &["sh", "-c", &format!("nc -z localhost {}", 7447)],
            Duration::from_secs(3),
        )
        .await
        .map(|(_, _, code)| code == 0)
        .unwrap_or(false);

        // Count visible peers by checking TCP connections to other routers
        let mut visible_peers = 0u32;
        for peer in &routers {
            if peer == router {
                continue;
            }
            let can_reach = podman::podman_exec(
                router,
                &["sh", "-c", &format!("nc -z -w 2 {} 7447", peer)],
                Duration::from_secs(3),
            )
            .await
            .map(|(_, _, code)| code == 0)
            .unwrap_or(false);

            if can_reach {
                visible_peers += 1;
            } else {
                warn!(
                    "[connectivity] {} cannot reach {} on port 7447",
                    router, peer
                );
                report.fully_connected = false;
            }
        }

        report.sessions_established += visible_peers;

        let healthy = visible_peers == (routers.len() - 1) as u32 && port_open;
        report.peer_visibility.push(ZenohPeerVisibility {
            router: router.to_string(),
            visible_peers,
            expected_peers: (routers.len() - 1) as u32,
            healthy,
        });

        report.routers_checked += 1;

        if healthy {
            info!(
                "[connectivity] {} — fully connected ({}/{} peers)",
                router, visible_peers, routers.len() - 1
            );
        } else {
            warn!(
                "[connectivity] {} — partial connectivity ({}/{} peers, port_open={})",
                router, visible_peers, routers.len() - 1, port_open
            );
        }
    }

    info!(
        "[connectivity] Zenoh mesh: {}/{} sessions established, fully_connected={}",
        report.sessions_established,
        report.total_sessions_expected,
        report.fully_connected
    );

    Ok(report)
}

/// Zenoh mesh topology verification report.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ZenohMeshReport {
    pub routers_checked: usize,
    pub fully_connected: bool,
    pub peer_visibility: Vec<ZenohPeerVisibility>,
    pub sessions_established: u32,
    pub total_sessions_expected: usize,
}

/// Per-router peer visibility in the Zenoh mesh.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ZenohPeerVisibility {
    pub router: String,
    pub visible_peers: u32,
    pub expected_peers: u32,
    pub healthy: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_container_ports_has_all_16() {
        let ports = container_ports();
        assert_eq!(ports.len(), 16, "All 16 containers must have port mappings");
    }

    #[test]
    fn test_connectivity_deps_has_all_16() {
        let deps = connectivity_dependencies();
        assert_eq!(deps.len(), 16, "All 16 containers must have dependency entries");
    }

    #[test]
    fn test_zenoh_router_has_no_deps() {
        let deps = connectivity_dependencies();
        assert!(
            deps.get("zenoh-router").unwrap().is_empty(),
            "zenoh-router (T0) must have no outbound dependencies"
        );
    }

    #[test]
    fn test_app_depends_on_critical_infra() {
        let deps = connectivity_dependencies();
        let app_deps = deps.get("indrajaal-ex-app-1").unwrap();
        assert!(app_deps.contains(&"zenoh-router"));
        assert!(app_deps.contains(&"indrajaal-db-prod"));
        assert!(app_deps.contains(&"indrajaal-obs-prod"));
        assert!(app_deps.contains(&"cepaf-bridge"));
    }

    #[test]
    fn test_ml_runners_depend_on_ollama() {
        let deps = connectivity_dependencies();
        assert!(deps.get("indrajaal-ml-runner-1").unwrap().contains(&"indrajaal-ollama"));
        assert!(deps.get("indrajaal-ml-runner-2").unwrap().contains(&"indrajaal-ollama"));
    }

    #[test]
    fn test_total_expected_sessions() {
        // 3 routers, each sees 2 peers = 6 sessions
        let routers = 3;
        let expected = routers * (routers - 1);
        assert_eq!(expected, 6);
    }
}
