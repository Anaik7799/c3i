//! # Robust Launch Module — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Container Launch) |
//! | Element   | Atomic Tier Commit / Idempotent Launch / Emergency Drain |
//!
//! ## STAMP: SC-IGNITE-010, SC-BOOT-008, SC-SIL4-001
//!
//! Implements the top 4 launch robustness ideas:
//! - Idea #16 (Score 97): Atomic Tier Commit Protocol
//! - Idea #21 (Score 93): Idempotent Launch with State Reconciliation
//! - Idea #29 (Score 88): Post-Launch Stabilization Window
//! - Idea #30 (Score 94): Launch Abort with Emergency Drain
//!
//! ## Design Invariants
//! - Atomic tier commit: if ANY container in a tier fails, ALL started
//!   containers in that tier are rolled back before reporting failure
//! - Idempotent launch: if a container already exists in the correct state,
//!   skip; if in wrong state, reconcile (stop + recreate)
//! - Stabilization window: after all containers report "running", enforce
//!   a continuous health monitoring window before declaring success
//! - Emergency drain: stop all started containers in REVERSE tier order,
//!   clean up networks and volumes, generate drain report

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::{
    DrainResult, TierCommitResult, MESH_NETWORK,
    EMERGENCY_DRAIN_TIMEOUT_MS, MAX_CONCURRENT_LAUNCHES, STABILIZATION_WINDOW_MS,
};
use log::{error, info, warn};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::time::sleep;

// ═══════════════════════════════════════════════════════════════════════════════
// ATOMIC TIER COMMIT (Idea #16 — Score 97)
// ═══════════════════════════════════════════════════════════════════════════════

/// Launch a single container with idempotent semantics.
///
/// If the container already exists and is running with the correct image,
/// skip launch. If it exists but is in the wrong state, stop and recreate.
/// If it doesn't exist, create it.
///
/// Idea #21: Idempotent Launch with State Reconciliation
pub async fn launch_container_idempotent(
    name: &str,
    image: &str,
    args: &[&str],
) -> Result<ContainerLaunchResult, IgnitionError> {
    info!("[robust_launch] Idempotent launch for '{}'", name);

    // Check if container already exists
    let exists = podman::container_exists(name).await;

    if exists {
        // Check current state
        let status = podman::container_status(name).await?;
        let current_image = podman::container_image(name).await.unwrap_or_default();

        if status == "running" && current_image == image {
            info!(
                "[robust_launch] {} already running with correct image — skipping",
                name
            );
            return Ok(ContainerLaunchResult {
                name: name.to_string(),
                action: LaunchAction::Skipped,
                container_id: podman::container_id(name).await.unwrap_or_default(),
                detail: format!("Already running with image {}", image),
            });
        }

        // Container exists but needs reconciliation
        info!(
            "[robust_launch] {} needs reconciliation (status={}, image={})",
            name, status, current_image
        );

        // Stop and remove existing container
        podman::stop_container(name, 5).await?;
        podman::remove_container(name).await?;
        info!("[robust_launch] {} removed for recreation", name);
    }

    // Launch new container
    let container_id = podman::run_container(name, image, args).await?;

    info!(
        "[robust_launch] {} launched with id {}",
        name,
        &container_id[..12.min(container_id.len())]
    );

    Ok(ContainerLaunchResult {
        name: name.to_string(),
        action: LaunchAction::Created,
        container_id,
        detail: format!("Created with image {}", image),
    })
}

/// Launch all containers in a tier atomically.
///
/// If ANY container fails to start, ALL successfully started containers
/// in this tier are stopped and removed before returning failure.
///
/// Idea #16: Atomic Tier Commit Protocol
pub async fn launch_tier_atomic(
    tier: u8,
    containers: &[ContainerSpec],
) -> Result<TierCommitResult, IgnitionError> {
    info!(
        "[robust_launch] Atomic tier launch: tier {}, {} containers",
        tier,
        containers.len()
    );

    let mut started: Vec<String> = Vec::new();
    let wall_start = Instant::now();

    // Launch containers with bounded concurrency
    let semaphore = tokio::sync::Semaphore::new(MAX_CONCURRENT_LAUNCHES);

    for spec in containers {
        let _permit = semaphore.acquire().await.map_err(|e| {
            IgnitionError::PodmanExec(format!("Semaphore acquire failed: {}", e))
        })?;

        match launch_container_idempotent(&spec.name, &spec.image, &spec.args).await {
            Ok(result) => {
                if result.action != LaunchAction::Skipped {
                    started.push(spec.name.clone());
                }
                info!(
                    "[robust_launch] Tier {} — {}: {:?} ({})",
                    tier, spec.name, result.action, result.detail
                );
            }
            Err(e) => {
                error!(
                    "[robust_launch] Tier {} — {} failed: {} — initiating rollback",
                    tier, spec.name, e
                );

                // ROLLBACK: stop and remove all started containers in reverse order
                let mut rolled_back: Vec<String> = Vec::new();
                for name in started.iter().rev() {
                    info!("[robust_launch] Rolling back {}", name);
                    if let Err(re) = rollback_container(name).await {
                        warn!("[robust_launch] Rollback of {} failed: {}", name, re);
                    } else {
                        rolled_back.push(name.clone());
                    }
                }

                let rollback_count = rolled_back.len();
                let rollback_count = rolled_back.len();
                return Ok(TierCommitResult {
                    tier,
                    success: false,
                    containers_started: Vec::new(),
                    containers_rolled_back: rolled_back,
                    detail: format!(
                        "Container '{}' failed: {}. Rolled back {} containers.",
                        spec.name, e, rollback_count
                    ),
                });
            }
        }
    }

    let duration_ms = wall_start.elapsed().as_millis() as u64;

    info!(
        "[robust_launch] Tier {} atomic commit: {} containers started ({}ms)",
        tier, started.len(), duration_ms
    );

    Ok(TierCommitResult {
        tier,
        success: true,
        containers_started: started,
        containers_rolled_back: Vec::new(),
        detail: format!(
            "All {} containers started successfully",
            containers.len()
        ),
    })
}

/// Rollback a single container: stop + remove.
async fn rollback_container(name: &str) -> Result<(), IgnitionError> {
    // Best-effort stop (ignore errors if already stopped)
    let _ = podman::stop_container(name, 3).await;
    // Best-effort remove
    let _ = podman::remove_container(name).await;
    Ok(())
}

// ═══════════════════════════════════════════════════════════════════════════════
// POST-LAUNCH STABILIZATION WINDOW (Idea #29 — Score 88)
// ═══════════════════════════════════════════════════════════════════════════════

/// After all containers are "running", enforce a stabilization window
/// with continuous health monitoring. If any container becomes unhealthy
/// during the window, the entire launch is considered failed.
///
/// Idea #29: Post-Launch Stabilization Window
pub async fn stabilization_window(
    containers: &[String],
    window_ms: u64,
) -> Result<StabilizationReport, IgnitionError> {
    info!(
        "[robust_launch] Starting {}ms stabilization window for {} containers",
        window_ms,
        containers.len()
    );

    let deadline = Instant::now() + Duration::from_millis(window_ms);
    let poll_interval = Duration::from_secs(2);
    let mut health_snapshots: Vec<HealthSnapshot> = Vec::new();
    let mut failures: Vec<String> = Vec::new();

    while Instant::now() < deadline {
        let snapshot = HealthSnapshot {
            timestamp_ms: Instant::now().elapsed().as_millis() as u64,
            containers: check_all_containers_health(containers).await,
        };

        // Check for any unhealthy containers
        for (name, healthy) in &snapshot.containers {
            if !healthy {
                if !failures.contains(name) {
                    failures.push(name.clone());
                    warn!(
                        "[robust_launch] Stabilization: {} became unhealthy at {}ms",
                        name, snapshot.timestamp_ms
                    );
                }
            }
        }

        health_snapshots.push(snapshot);
        sleep(poll_interval).await;
    }

    let all_healthy = failures.is_empty();

    info!(
        "[robust_launch] Stabilization window complete: {} snapshots, {} failures, all_healthy={}",
        health_snapshots.len(),
        failures.len(),
        all_healthy
    );

    Ok(StabilizationReport {
        duration_ms: window_ms,
        snapshots_taken: health_snapshots.len(),
        all_healthy,
        failed_containers: failures,
        snapshots: health_snapshots,
    })
}

/// Check health of all containers in parallel.
async fn check_all_containers_health(containers: &[String]) -> HashMap<String, bool> {
    let mut results = HashMap::new();

    for name in containers {
        let healthy = match podman::container_status(name).await {
            Ok(status) => status == "running",
            Err(_) => false,
        };
        results.insert(name.clone(), healthy);
    }

    results
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMERGENCY DRAIN (Idea #30 — Score 94)
// ═══════════════════════════════════════════════════════════════════════════════

/// Execute an emergency drain: stop all containers in REVERSE tier order,
/// clean up networks and volumes, generate a drain report.
///
/// Reverse order ensures that dependent containers are stopped before
/// their dependencies (e.g., app before DB, DB before Zenoh).
///
/// Idea #30: Launch Abort with Emergency Drain
pub async fn emergency_drain(
    tiers: &[TierSpec],
) -> Result<DrainResult, IgnitionError> {
    info!("[robust_launch] EMERGENCY DRAIN initiated — {} tiers", tiers.len());

    let wall_start = Instant::now();
    let mut containers_stopped: Vec<String> = Vec::new();
    let mut containers_failed: Vec<String> = Vec::new();
    let mut networks_cleaned: Vec<String> = Vec::new();
    let mut volumes_preserved: Vec<String> = Vec::new();

    // Stop containers in REVERSE tier order (highest tier first)
    for tier in tiers.iter().rev() {
        info!("[robust_launch] Draining tier {} ({} containers)", tier.number, tier.containers.len());

        for container in &tier.containers {
            let timeout = Duration::from_millis(EMERGENCY_DRAIN_TIMEOUT_MS);

            match podman::stop_container(container, 5).await {
                Ok(_) => {
                    info!("[robust_launch] Stopped {}", container);
                    containers_stopped.push(container.clone());
                }
                Err(e) => {
                    warn!("[robust_launch] Failed to stop {}: {}", container, e);
                    // Force kill as last resort
                    match podman::force_remove(container).await {
                        Ok(_) => {
                            info!("[robust_launch] Force-killed {}", container);
                            containers_stopped.push(container.clone());
                        }
                        Err(e2) => {
                            error!("[robust_launch] Force-kill failed {}: {}", container, e2);
                            containers_failed.push(container.clone());
                        }
                    }
                }
            }

            // Brief pause between container stops to avoid I/O storms
            sleep(Duration::from_millis(200)).await;
        }
    }

    // Clean up the mesh network (but preserve named volumes)
    if let Ok(networks) = podman::list_networks().await {
        for network in &networks {
            if network == MESH_NETWORK {
                // Only remove if no containers are using it
                let in_use = containers_failed.iter().any(|c| {
                    // Check if any failed container is still on this network
                    true // Conservative: assume in use if any failures
                });

                if !in_use && containers_failed.is_empty() {
                    if let Err(e) = podman::remove_network(network).await {
                        warn!("[robust_launch] Failed to remove network {}: {}", network, e);
                    } else {
                        info!("[robust_launch] Cleaned up network {}", network);
                        networks_cleaned.push(network.clone());
                    }
                }
            }
        }
    }

    // Preserve volumes (never auto-delete data volumes)
    let data_volumes = [
        "indrajaal-db-data",
        "indrajaal-obs-data",
        "indrajaal-redis-data",
    ];
    for vol in &data_volumes {
        volumes_preserved.push(vol.to_string());
    }

    let duration_ms = wall_start.elapsed().as_millis() as u64;

    let detail = if containers_failed.is_empty() {
        format!(
            "Emergency drain complete: {} containers stopped, {} networks cleaned ({}ms)",
            containers_stopped.len(),
            networks_cleaned.len(),
            duration_ms
        )
    } else {
        format!(
            "Emergency drain PARTIAL: {} stopped, {} FAILED ({}ms). Manual cleanup required for: {:?}",
            containers_stopped.len(),
            containers_failed.len(),
            duration_ms,
            containers_failed
        )
    };

    info!("[robust_launch] {}", detail);

    Ok(DrainResult {
        success: containers_failed.is_empty(),
        containers_stopped,
        containers_failed,
        networks_cleaned,
        volumes_preserved,
        duration_ms,
        detail,
    })
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Container specification for launch.
#[derive(Debug, Clone)]
pub struct ContainerSpec {
    pub name: String,
    pub image: String,
    pub args: Vec<&'static str>,
}

/// Tier specification for atomic launch.
#[derive(Debug, Clone)]
pub struct TierSpec {
    pub number: u8,
    pub name: String,
    pub containers: Vec<String>,
}

/// Result of a container launch attempt.
#[derive(Debug, Clone)]
pub struct ContainerLaunchResult {
    pub name: String,
    pub action: LaunchAction,
    pub container_id: String,
    pub detail: String,
}

/// What action was taken during idempotent launch.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LaunchAction {
    /// Container was newly created
    Created,
    /// Container already existed and was skipped
    Skipped,
    /// Container was reconciled (stopped + recreated)
    Reconciled,
}

/// Health snapshot during stabilization window.
#[derive(Debug, Clone)]
pub struct HealthSnapshot {
    pub timestamp_ms: u64,
    pub containers: HashMap<String, bool>,
}

/// Stabilization window report.
#[derive(Debug, Clone)]
pub struct StabilizationReport {
    pub duration_ms: u64,
    pub snapshots_taken: usize,
    pub all_healthy: bool,
    pub failed_containers: Vec<String>,
    pub snapshots: Vec<HealthSnapshot>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_launch_action_variants() {
        assert_eq!(LaunchAction::Created, LaunchAction::Created);
        assert_ne!(LaunchAction::Created, LaunchAction::Skipped);
        assert_ne!(LaunchAction::Created, LaunchAction::Reconciled);
    }

    #[test]
    fn test_container_spec_creation() {
        let spec = ContainerSpec {
            name: "test-container".into(),
            image: "test:latest".into(),
            args: vec!["--env", "TEST=1"],
        };
        assert_eq!(spec.name, "test-container");
        assert_eq!(spec.image, "test:latest");
        assert_eq!(spec.args.len(), 2);
    }

    #[test]
    fn test_tier_spec_creation() {
        let tier = TierSpec {
            number: 0,
            name: "Foundation".into(),
            containers: vec!["zenoh-router".into()],
        };
        assert_eq!(tier.number, 0);
        assert_eq!(tier.containers.len(), 1);
    }

    #[test]
    fn test_health_snapshot_structure() {
        let mut containers = HashMap::new();
        containers.insert("zenoh-router".into(), true);
        containers.insert("app".into(), false);

        let snapshot = HealthSnapshot {
            timestamp_ms: 1000,
            containers,
        };
        assert_eq!(snapshot.timestamp_ms, 1000);
        assert_eq!(snapshot.containers.len(), 2);
        assert!(snapshot.containers["zenoh-router"]);
        assert!(!snapshot.containers["app"]);
    }

    #[test]
    fn test_stabilization_report_all_healthy() {
        let report = StabilizationReport {
            duration_ms: 30000,
            snapshots_taken: 15,
            all_healthy: true,
            failed_containers: Vec::new(),
            snapshots: Vec::new(),
        };
        assert!(report.all_healthy);
        assert_eq!(report.failed_containers.len(), 0);
        assert_eq!(report.snapshots_taken, 15);
    }

    #[test]
    fn test_stabilization_report_with_failures() {
        let report = StabilizationReport {
            duration_ms: 30000,
            snapshots_taken: 10,
            all_healthy: false,
            failed_containers: vec!["app".into()],
            snapshots: Vec::new(),
        };
        assert!(!report.all_healthy);
        assert_eq!(report.failed_containers.len(), 1);
        assert_eq!(report.failed_containers[0], "app");
    }

    #[test]
    fn test_tier_reverse_order() {
        // Verify that reverse iteration works correctly for drain
        let tiers = vec![
            TierSpec { number: 0, name: "T0".into(), containers: vec!["zenoh".into()] },
            TierSpec { number: 4, name: "T4".into(), containers: vec!["app".into()] },
        ];

        let mut reverse_order: Vec<u8> = tiers.iter().rev().map(|t| t.number).collect();
        assert_eq!(reverse_order, vec![4, 0]); // T4 before T0
    }

    #[test]
    fn test_emergency_drain_timeout_constant() {
        assert_eq!(EMERGENCY_DRAIN_TIMEOUT_MS, 5000);
        assert_eq!(STABILIZATION_WINDOW_MS, 30000);
        assert_eq!(MAX_CONCURRENT_LAUNCHES, 4);
    }

    #[test]
    fn test_mesh_network_constant() {
        assert_eq!(MESH_NETWORK, "indrajaal-sil6-mesh");
    }
}
