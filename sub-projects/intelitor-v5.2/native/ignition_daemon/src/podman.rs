//! # Podman Command Execution Layer
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Container Runtime Interface) |
//! | Element   | Podman CLI wrapper |
//!
//! ## STAMP: SC-CNT-001 to SC-CNT-019
//!
//! All podman commands use `tokio::process::Command` with explicit timeouts.
//! Source mapping: PanopticIgnition.fs (podman build/start/exec/inspect),
//!                 capture-ignition.sh (podman stop/rm/logs)

use crate::errors::IgnitionError;
use log::{debug, warn};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use std::time::Duration;
use tokio::process::Command;
use tokio::time::timeout;

/// Execute a podman command with timeout.
/// Returns (stdout, stderr, exit_code).
///
/// STAMP: SC-CNT-009 (container health monitoring)
/// Source: PanopticIgnition.fs — all podman interactions
pub async fn podman_cmd(
    args: &[&str],
    timeout_dur: Duration,
) -> Result<(String, String, i32), IgnitionError> {
    debug!("podman {}", args.join(" "));

    let result = timeout(timeout_dur, async {
        let output = Command::new("podman")
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output()
            .await
            .map_err(|e| IgnitionError::PodmanExec(format!("Failed to execute podman: {}", e)))?;

        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let code = output.status.code().unwrap_or(-1);

        Ok::<_, IgnitionError>((stdout, stderr, code))
    })
    .await
    .map_err(|_| {
        IgnitionError::Timeout(format!("podman {} timed out after {:?}", args.join(" "), timeout_dur))
    })??;

    Ok(result)
}

/// Spawn a podman command asynchronously for stream parsing.
/// Returns a tokio::process::Child with piped stderr.
/// Task 8.1: Async Stream Parsing (Rank 3)
pub fn podman_spawn(args: &[&str]) -> Result<tokio::process::Child, IgnitionError> {
    debug!("podman spawn {}", args.join(" "));
    
    Command::new("podman")
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| IgnitionError::PodmanExec(format!("Failed to spawn podman: {}", e)))
}

/// Execute a command inside a running container.
/// Source: PanopticIgnition.fs:289 (pg_isready), capture-ignition.sh:204 (nc -z)
///
/// STAMP: SC-BOOT-006 (container health check)
/// AOR-SWARM-VERIFY-007: ALWAYS use podman exec for in-container commands
pub async fn podman_exec(
    container: &str,
    cmd: &[&str],
    timeout_dur: Duration,
) -> Result<(String, String, i32), IgnitionError> {
    let mut args = vec!["exec", container];
    args.extend_from_slice(cmd);
    podman_cmd(&args, timeout_dur).await
}

/// Inspect a container field.
/// Source: PanopticIgnition.fs:261 (Health.Status), capture-ignition.sh:218 (State.Running)
pub async fn podman_inspect(
    container: &str,
    format: &str,
) -> Result<String, IgnitionError> {
    let (stdout, _, code) = podman_cmd(
        &["inspect", container, "--format", format],
        Duration::from_secs(5),
    )
    .await?;

    if code != 0 {
        return Err(IgnitionError::ContainerNotFound(container.to_string()));
    }
    Ok(stdout)
}

/// Check if a container exists (any state).
pub async fn container_exists(name: &str) -> bool {
    // podman container exists is good, but let's be double sure with ps --all
    let (stdout, _, _) = podman_cmd(
        &["ps", "--all", "--format", "{{.Names}}"],
        Duration::from_secs(3),
    )
    .await
    .unwrap_or_default();
    
    stdout.lines().any(|n| n.trim() == name || n.trim() == format!("/{}", name))
}

/// Check if an image exists.
/// Source: PanopticIgnition.fs:156 (imageExists)
/// SC-IGNITE-002: Architectural control checks
pub async fn image_exists(name: &str) -> bool {
    podman_cmd(
        &["image", "exists", name],
        Duration::from_secs(3),
    )
    .await
    .map(|(_, _, code)| code == 0)
    .unwrap_or(false)
}

/// Verify cryptographic image digest before launch (Robustness Rank 4)
pub async fn verify_image(name: &str) -> Result<String, IgnitionError> {
    let (stdout, _, code) = podman_cmd(
        &["image", "inspect", name, "--format", "{{.Digest}}"],
        Duration::from_secs(5),
    ).await?;
    if code != 0 || stdout.trim().is_empty() {
        return Err(IgnitionError::LaunchFailed(format!("Image {} missing or invalid digest", name)));
    }
    Ok(stdout.trim().to_string())
}

/// Get container status: "running", "exited", "created", etc.
pub async fn container_status(name: &str) -> Result<String, IgnitionError> {
    podman_inspect(name, "{{.State.Status}}").await
}

/// Get container exit code.
pub async fn container_exit_code(name: &str) -> Result<i32, IgnitionError> {
    let code_str = podman_inspect(name, "{{.State.ExitCode}}").await?;
    code_str
        .parse::<i32>()
        .map_err(|e| IgnitionError::ParseError(format!("Exit code parse: {}", e)))
}

/// Get container IP on a specific network.
pub async fn container_ip(name: &str) -> Result<String, IgnitionError> {
    podman_inspect(
        name,
        "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}",
    )
    .await
}

/// Force remove a container.
/// Source: PanopticIgnition.fs:465 (cleanStaleContainers)
pub async fn force_remove(name: &str) -> Result<(), IgnitionError> {
    let _ = podman_cmd(&["rm", "-f", name], Duration::from_secs(10)).await;
    Ok(())
}

/// Stop a container with graceful timeout.
/// Source: ContainerLifecycleManager.fs:555 (StopContainer)
pub async fn stop_container(name: &str, timeout_secs: u32) -> Result<(), IgnitionError> {
    let t = format!("{}", timeout_secs);
    let (_, _, code) = podman_cmd(
        &["stop", "-t", &t, name],
        Duration::from_secs((timeout_secs + 5) as u64),
    )
    .await?;

    if code != 0 {
        warn!("podman stop {} returned code {}, force killing", name, code);
        let _ = podman_cmd(&["kill", name], Duration::from_secs(5)).await;
    }
    Ok(())
}

/// Get container logs (last N lines).
pub async fn container_logs(name: &str, tail: u32) -> Result<String, IgnitionError> {
    let tail_str = format!("{}", tail);
    let (stdout, stderr, _) = podman_cmd(
        &["logs", "--tail", &tail_str, name],
        Duration::from_secs(10),
    )
    .await?;

    // podman logs outputs to stderr for some containers
    if stdout.is_empty() { Ok(stderr) } else { Ok(stdout) }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerStats {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "CPUPercentage")]
    pub cpu_pct: String,
    #[serde(rename = "MemoryPercentage")]
    pub mem_pct: String,
}

/// Get stats for all containers via `podman stats --no-stream --format json`.
pub async fn get_all_stats() -> Result<Vec<ContainerStats>, IgnitionError> {
    let (stdout, _, code) = podman_cmd(
        &["stats", "--no-stream", "--format", "json"],
        Duration::from_secs(5),
    )
    .await?;

    if code != 0 {
        return Ok(vec![]);
    }

    if stdout.trim().is_empty() {
        return Ok(vec![]);
    }

    // Podman stats JSON can be a list or individual objects per line depending on version
    let stats: Vec<ContainerStats> = if stdout.starts_with('[') {
        serde_json::from_str(&stdout).unwrap_or_default()
    } else {
        stdout.lines()
            .filter_map(|l| serde_json::from_str(l).ok())
            .collect()
    };

    Ok(stats)
}

/// Check if a network exists.
pub async fn network_exists(name: &str) -> bool {
    podman_cmd(
        &["network", "exists", name],
        Duration::from_secs(3),
    )
    .await
    .map(|(_, _, code)| code == 0)
    .unwrap_or(false)
}

/// Check if DNS is enabled on a network.
pub async fn network_dns_enabled(name: &str) -> Result<bool, IgnitionError> {
    let result = podman_inspect_network(name, "{{.DNSEnabled}}").await?;
    Ok(result.trim() == "true")
}

/// Inspect a network field.
pub async fn podman_inspect_network(
    name: &str,
    format: &str,
) -> Result<String, IgnitionError> {
    let (stdout, _, code) = podman_cmd(
        &["network", "inspect", name, "--format", format],
        Duration::from_secs(5),
    )
    .await?;

    if code != 0 {
        return Err(IgnitionError::NetworkNotFound(name.to_string()));
    }
    Ok(stdout)
}
