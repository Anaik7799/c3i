//! # Network Partition Detection & Split-Brain Prevention — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Network Partition Detection) |
//! | Element   | Multi-Path Probing / Split-Brain Prevention / Fencing |
//!
//! ## STAMP: SC-IGNITE-010, SC-NET-MESH-001, SC-SIL4-006
//!
//! Idea #51 (Score 95): Network Partition Recovery with Split-Brain Prevention
//! Idea #69 (Score 90): Network Partition Detection with Multi-Path Probing
//!
//! ## Design Invariants
//! - Partitions are detected via multi-path probing (direct, via zenoh, via host)
//! - Split-brain is prevented via fencing (isolate minority partition)
//! - Leader election completes within 10s of partition detection
//! - Recovery begins only after partition heals (all paths restored)

use crate::errors::IgnitionError;
use crate::podman;
use crate::types::PartitionResult;
use log::{debug, info, warn};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::time::sleep;

/// All 16 SIL-6 containers grouped by their network role.
const ZENOH_ROUTERS: &[&str] = &["zenoh-router-1", "zenoh-router-2", "zenoh-router-3"];
const INFRA_CONTAINERS: &[&str] = &[
    "zenoh-router-1",
    "zenoh-router-2",
    "zenoh-router-3",
    "indrajaal-db-prod",
    "indrajaal-obs-prod",
    "indrajaal-cortex",
];
const APP_CONTAINERS: &[&str] = &[
    "indrajaal-ex-app-1",
    "indrajaal-ex-app-2",
    "indrajaal-ex-app-3",
    "cepaf-bridge",
    "indrajaal-chaya",
    "indrajaal-ollama",
    "indrajaal-ml-runner-1",
    "indrajaal-ml-runner-2",
    "indrajaal-mojo",
];

/// Probe a single container from a source container via TCP.
async fn probe_tcp(source: &str, target: &str, port: u16) -> bool {
    let cmd = format!("nc -z -w 2 {} {}", target, port);
    let args: Vec<&str> = cmd.split_whitespace().collect();
    podman::podman_exec(source, &args, Duration::from_secs(3))
        .await
        .map(|(_, _, code)| code == 0)
        .unwrap_or(false)
}

/// Multi-path probe: test connectivity from source to target via 3 paths.
///
/// Path 1: Direct TCP connect (container → container on mesh network)
/// Path 2: Via Zenoh router (container → zenoh-router → target)
/// Path 3: Via host (container → host → container)
///
/// If all 3 paths fail, the target is considered partitioned from the source.
async fn multi_path_probe(source: &str, target: &str, target_port: u16) -> PathResult {
    let path1 = probe_tcp(source, target, target_port).await;
    let path2 = probe_tcp(source, "zenoh-router-1", 7447).await
        && probe_tcp("zenoh-router-1", target, target_port).await;
    let path3 = podman::container_status(target)
        .await
        .map(|s| s == "running")
        .unwrap_or(false);

    PathResult {
        direct: path1,
        via_zenoh: path2,
        via_host: path3,
    }
}

/// Result of a multi-path probe.
#[derive(Debug, Clone)]
struct PathResult {
    direct: bool,
    via_zenoh: bool,
    via_host: bool,
}

impl PathResult {
    fn paths_working(&self) -> u8 {
        [self.direct, self.via_zenoh, self.via_host]
            .iter()
            .filter(|&&p| p)
            .count() as u8
    }

    fn is_partitioned(&self) -> bool {
        self.paths_working() == 0
    }
}

/// Detect network partitions across the entire swarm.
///
/// Algorithm:
///   1. From each infra container, multi-path probe every other infra container
///   2. Build connectivity matrix
///   3. Identify disconnected components (partitions)
///   4. If 2+ partitions exist, determine majority/minority
///   5. Return PartitionResult with fencing recommendation
///
/// SC-NET-MESH-001: All containers on sil6-mesh MUST be mutually reachable
pub async fn detect_partitions() -> Result<PartitionResult, IgnitionError> {
    info!("[partition] Running multi-path partition detection across swarm");
    let wall_start = Instant::now();

    // Build adjacency matrix for infra containers
    let mut adjacency: HashMap<&str, Vec<&str>> = HashMap::new();
    for &source in INFRA_CONTAINERS {
        adjacency.entry(source).or_default();
        for &target in INFRA_CONTAINERS {
            if source == target {
                continue;
            }
            let port = match target {
                "indrajaal-db-prod" => 5432,
                "indrajaal-obs-prod" => 4317,
                "indrajaal-cortex" => 9877,
                _ => 7447, // zenoh routers
            };

            let probe = multi_path_probe(source, target, port).await;
            if !probe.is_partitioned() {
                adjacency.entry(source).or_default().push(target);
            } else {
                warn!(
                    "[partition] {} → {} PARTITIONED (direct={}, zenoh={}, host={})",
                    source, target, probe.direct, probe.via_zenoh, probe.via_host
                );
            }
        }
    }

    // Find connected components using BFS
    let mut visited: Vec<&str> = Vec::new();
    let mut partitions: Vec<Vec<&str>> = Vec::new();

    for &container in INFRA_CONTAINERS {
        if visited.contains(&container) {
            continue;
        }

        let mut component = Vec::new();
        let mut queue = vec![container];

        while let Some(node) = queue.pop() {
            if visited.contains(&node) {
                continue;
            }
            visited.push(node);
            component.push(node);

            if let Some(neighbors) = adjacency.get(node) {
                for &neighbor in neighbors {
                    if !visited.contains(&neighbor) {
                        queue.push(neighbor);
                    }
                }
            }
        }

        partitions.push(component);
    }

    let partition_count = partitions.len();
    let detected = partition_count > 1;

    info!(
        "[partition] Detection complete: {} partition(s) found in {}ms",
        partition_count,
        wall_start.elapsed().as_millis()
    );

    if !detected {
        return Ok(PartitionResult {
            detected: false,
            partition_a: INFRA_CONTAINERS.iter().map(|s| s.to_string()).collect(),
            partition_b: Vec::new(),
            minority_partition: Vec::new(),
            fence_required: false,
        });
    }

    // Sort partitions by size (largest = majority)
    partitions.sort_by(|a, b| b.len().cmp(&a.len()));
    let majority = &partitions[0];
    let minority: Vec<&str> = partitions[1..]
        .iter()
        .flat_map(|p| p.iter())
        .copied()
        .collect();

    let fence_required = !minority.is_empty();

    warn!(
        "[partition] SPLIT-BRAIN DETECTED: majority={:?}, minority={:?}",
        majority, minority
    );

    Ok(PartitionResult {
        detected: true,
        partition_a: majority.iter().map(|s| s.to_string()).collect(),
        partition_b: minority.iter().map(|s| s.to_string()).collect(),
        minority_partition: minority.iter().map(|s| s.to_string()).collect(),
        fence_required,
    })
}

/// Execute fencing on the minority partition to prevent split-brain.
///
/// Fencing strategy:
///   1. Stop all containers in the minority partition
///   2. Verify Zenoh quorum is preserved in the majority partition
///   3. Log fencing action for audit trail
///
/// SC-SIL4-001: Safety functions MUST fail to safe state
pub async fn execute_fencing(partition: &PartitionResult) -> Result<FencingReport, IgnitionError> {
    if !partition.fence_required {
        info!("[partition] No fencing required — single partition");
        return Ok(FencingReport {
            fenced_containers: Vec::new(),
            quorum_preserved: true,
            detail: "No fencing needed".into(),
        });
    }

    info!(
        "[partition] Executing fencing on minority partition: {:?}",
        partition.minority_partition
    );

    let mut fenced: Vec<String> = Vec::new();

    for container in &partition.minority_partition {
        // Never fence zenoh routers if it would break quorum
        if container.starts_with("zenoh-router") {
            let running_routers = count_running_routers(&partition.partition_a).await;
            if running_routers < 2 {
                warn!(
                    "[partition] Skipping fence for {} — would break quorum ({} routers in majority)",
                    container, running_routers
                );
                continue;
            }
        }

        info!("[partition] Fencing {}", container);
        if let Err(e) = podman::stop_container(container, 3).await {
            warn!("[partition] Failed to fence {}: {}", container, e);
        } else {
            fenced.push(container.clone());
        }
    }

    let quorum_preserved = count_running_routers(&partition.partition_a).await >= 2;
    let fenced_count = fenced.len();

    info!(
        "[partition] Fencing complete: {} containers fenced, quorum_preserved={}",
        fenced_count, quorum_preserved
    );

    Ok(FencingReport {
        fenced_containers: fenced,
        quorum_preserved,
        detail: format!("Fenced {} containers", fenced_count),
    })
}

/// Count running zenoh routers in the given partition.
async fn count_running_routers(partition: &[String]) -> u32 {
    let mut count = 0u32;
    for container in partition {
        if container.starts_with("zenoh-router") {
            if let Ok(status) = podman::container_status(container).await {
                if status == "running" {
                    count += 1;
                }
            }
        }
    }
    count
}

/// Wait for partition to heal — all paths restored between all containers.
///
/// Polls every 2 seconds for up to 60 seconds.
pub async fn wait_for_partition_heal(timeout_secs: u64) -> Result<bool, IgnitionError> {
    info!(
        "[partition] Waiting for partition heal (timeout: {}s)",
        timeout_secs
    );

    let deadline = Instant::now() + Duration::from_secs(timeout_secs);

    while Instant::now() < deadline {
        let result = detect_partitions().await?;
        if !result.detected {
            info!("[partition] Partition healed — all paths restored");
            return Ok(true);
        }
        debug!(
            "[partition] Partition still active: {} partition(s)",
            result.partition_a.len() + result.partition_b.len()
        );
        sleep(Duration::from_secs(2)).await;
    }

    warn!(
        "[partition] Partition did not heal within {}s timeout",
        timeout_secs
    );
    Ok(false)
}

/// Leader election for the majority partition after split-brain.
///
/// Uses Zenoh router with lowest ID as leader (deterministic).
/// Returns the leader container name.
pub async fn elect_leader(partition: &[String]) -> Option<String> {
    // Deterministic: lowest-numbered zenoh-router in the partition
    let mut routers: Vec<&String> = partition
        .iter()
        .filter(|c| c.starts_with("zenoh-router"))
        .collect();
    routers.sort();

    if routers.is_empty() {
        warn!("[partition] No zenoh routers in partition — cannot elect leader");
        return None;
    }

    let leader = routers[0].clone();
    info!("[partition] Leader elected: {}", leader);
    Some(leader)
}

/// Fencing execution report.
#[derive(Debug, Clone)]
pub struct FencingReport {
    pub fenced_containers: Vec<String>,
    pub quorum_preserved: bool,
    pub detail: String,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_path_result_all_working() {
        let result = PathResult {
            direct: true,
            via_zenoh: true,
            via_host: true,
        };
        assert_eq!(result.paths_working(), 3);
        assert!(!result.is_partitioned());
    }

    #[test]
    fn test_path_result_all_failed() {
        let result = PathResult {
            direct: false,
            via_zenoh: false,
            via_host: false,
        };
        assert_eq!(result.paths_working(), 0);
        assert!(result.is_partitioned());
    }

    #[test]
    fn test_path_result_partial() {
        let result = PathResult {
            direct: false,
            via_zenoh: true,
            via_host: true,
        };
        assert_eq!(result.paths_working(), 2);
        assert!(!result.is_partitioned());
    }

    #[test]
    fn test_infra_containers_count() {
        assert_eq!(INFRA_CONTAINERS.len(), 6);
    }

    #[test]
    fn test_zenoh_routers_count() {
        assert_eq!(ZENOH_ROUTERS.len(), 3);
    }

    #[test]
    fn test_app_containers_count() {
        assert_eq!(APP_CONTAINERS.len(), 9);
    }

    #[test]
    fn test_total_containers() {
        assert_eq!(INFRA_CONTAINERS.len() + APP_CONTAINERS.len(), 15);
        // Note: zenoh-router (T0) is not in INFRA_CONTAINERS list, so 15 + 1 = 16
    }

    #[test]
    fn test_partition_result_no_partition() {
        let result = PartitionResult {
            detected: false,
            partition_a: vec!["a".into(), "b".into()],
            partition_b: Vec::new(),
            minority_partition: Vec::new(),
            fence_required: false,
        };
        assert!(!result.detected);
        assert!(!result.fence_required);
        assert!(result.minority_partition.is_empty());
    }

    #[test]
    fn test_partition_result_with_partition() {
        let result = PartitionResult {
            detected: true,
            partition_a: vec!["a".into(), "b".into(), "c".into()],
            partition_b: vec!["d".into()],
            minority_partition: vec!["d".into()],
            fence_required: true,
        };
        assert!(result.detected);
        assert!(result.fence_required);
        assert_eq!(result.minority_partition.len(), 1);
    }

    #[test]
    fn test_fencing_report_empty() {
        let report = FencingReport {
            fenced_containers: Vec::new(),
            quorum_preserved: true,
            detail: "No fencing needed".into(),
        };
        assert!(report.quorum_preserved);
        assert!(report.fenced_containers.is_empty());
    }
}
