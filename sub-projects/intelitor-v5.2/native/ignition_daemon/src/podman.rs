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
        IgnitionError::Timeout(format!(
            "podman {} timed out after {:?}",
            args.join(" "),
            timeout_dur
        ))
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
pub async fn podman_inspect(container: &str, format: &str) -> Result<String, IgnitionError> {
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
    let path = format!("/v4.0.0/libpod/containers/{}/json", name);
    match request("GET", &path, None).await {
        Ok((status, _)) => status == 200,
        _ => false,
    }
}

/// Check if an image exists.
/// Source: PanopticIgnition.fs:156 (imageExists)
/// SC-IGNITE-002: Architectural control checks
pub async fn image_exists(name: &str) -> bool {
    let path = format!("/v4.0.0/libpod/images/{}/exists", urlencoding::encode(name));
    match request("GET", &path, None).await {
        Ok((status, _)) => status == 204 || status == 200,
        _ => false,
    }
}

/// Verify cryptographic image digest before launch (Robustness Rank 4)
pub async fn verify_image(name: &str) -> Result<String, IgnitionError> {
    let (stdout, _, code) = podman_cmd(
        &["image", "inspect", name, "--format", "{{.Digest}}"],
        Duration::from_secs(5),
    )
    .await?;
    if code != 0 || stdout.trim().is_empty() {
        return Err(IgnitionError::LaunchFailed(format!(
            "Image {} missing or invalid digest",
            name
        )));
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
    let path = format!("/v4.0.0/libpod/containers/{}?force=true", name);
    let _ = request("DELETE", &path, None).await;
    Ok(())
}

/// Start a container.
pub async fn start_container(name: &str) -> Result<(), IgnitionError> {
    let path = format!("/v4.0.0/libpod/containers/{}/start", name);
    let (status, body) = request("POST", &path, None).await?;
    if status != 204 && status != 304 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to start container {}: {}",
            name, body
        )));
    }
    Ok(())
}

/// Stop a container with graceful timeout.
/// Source: ContainerLifecycleManager.fs:555 (StopContainer)
pub async fn stop_container(name: &str, timeout_secs: u32) -> Result<(), IgnitionError> {
    let path = format!("/v4.0.0/libpod/containers/{}/stop?t={}", name, timeout_secs);
    let (status, _) = request("POST", &path, None).await?;
    if status != 204 && status != 304 {
        warn!("podman stop {} returned {}, force killing", name, status);
        let kill_path = format!("/v4.0.0/libpod/containers/{}/kill", name);
        let _ = request("POST", &kill_path, None).await;
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
    if stdout.is_empty() {
        Ok(stderr)
    } else {
        Ok(stdout)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerStats {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "CPUPercentage")]
    pub cpu_pct: String,
    #[serde(rename = "MemoryPercentage")]
    pub mem_pct: String,
    #[serde(rename = "MemoryUsage")]
    pub mem_usage: String,
    #[serde(rename = "NetworkIO")]
    pub net_io: String,
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
        stdout
            .lines()
            .filter_map(|l| serde_json::from_str(l).ok())
            .collect()
    };

    Ok(stats)
}

/// Check if a network exists.
pub async fn network_exists(name: &str) -> bool {
    podman_cmd(&["network", "exists", name], Duration::from_secs(3))
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
pub async fn podman_inspect_network(name: &str, format: &str) -> Result<String, IgnitionError> {
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

/// Get the image name of a container.
pub async fn container_image(name: &str) -> Result<String, IgnitionError> {
    podman_inspect(name, "{{.Config.Image}}").await
}

/// Get the ID of a container.
pub async fn container_id(name: &str) -> Result<String, IgnitionError> {
    podman_inspect(name, "{{.Id}}").await
}

/// Remove a container (must be stopped first).
pub async fn remove_container(name: &str) -> Result<(), IgnitionError> {
    let path = format!("/v4.0.0/libpod/containers/{}", name);
    let (status, body) = request("DELETE", &path, None).await?;
    if status != 200 && status != 204 && status != 404 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to remove container {}: exit code {}",
            name, status
        )));
    }
    Ok(())
}

/// Run a new container.
pub async fn run_container(
    name: &str,
    image: &str,
    args: &[&str],
) -> Result<String, IgnitionError> {
    let mut cmd_args = vec!["run", "-d", "--name", name];
    cmd_args.extend_from_slice(args);
    cmd_args.push(image);

    let (stdout, _, code) = podman_cmd(&cmd_args, Duration::from_secs(60)).await?;

    if code != 0 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to run container {}: exit code {}",
            name, code
        )));
    }
    Ok(stdout.trim().to_string())
}

/// List all podman networks.
pub async fn list_networks() -> Result<Vec<String>, IgnitionError> {
    let (stdout, _, code) = podman_cmd(
        &["network", "ls", "--format", "{{.Name}}"],
        Duration::from_secs(5),
    )
    .await?;

    if code != 0 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to list networks: exit code {}",
            code
        )));
    }

    Ok(stdout.lines().map(|l| l.trim().to_string()).collect())
}

/// Remove a podman network.
pub async fn remove_network(name: &str) -> Result<(), IgnitionError> {
    let path = format!("/v4.0.0/libpod/networks/{}", name);
    let (status, _) = request("DELETE", &path, None).await?;
    if status != 200 && status != 204 && status != 404 {
        return Err(IgnitionError::PodmanExec(format!(
            "Failed to remove network {}: exit code {}",
            name, status
        )));
    }
    Ok(())
}

// ═══════════════════════════════════════════════════════════════════════════════
// REST API CLIENT (EVO-1)
// ═══════════════════════════════════════════════════════════════════════════════

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixStream;

pub async fn request(
    method: &str,
    path: &str,
    body: Option<&str>,
) -> Result<(u16, String), IgnitionError> {
    request_with_body(
        method,
        path,
        "application/json",
        body.unwrap_or("").as_bytes(),
    )
    .await
}

pub async fn request_with_body(
    method: &str,
    path: &str,
    content_type: &str,
    body: &[u8],
) -> Result<(u16, String), IgnitionError> {
    let socket_path = std::env::var("XDG_RUNTIME_DIR")
        .unwrap_or_else(|_| "/run/user/1000".to_string())
        + "/podman/podman.sock";
    let mut stream = UnixStream::connect(&socket_path)
        .await
        .map_err(|e| IgnitionError::PodmanExec(format!("UnixStream connect error: {}", e)))?;

    let req = format!("{} {} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Type: {}\r\nContent-Length: {}\r\n\r\n", 
        method, path, content_type, body.len());

    stream
        .write_all(req.as_bytes())
        .await
        .map_err(|e| IgnitionError::PodmanExec(format!("UnixStream write error: {}", e)))?;

    if !body.is_empty() {
        stream.write_all(body).await.map_err(|e| {
            IgnitionError::PodmanExec(format!("UnixStream write body error: {}", e))
        })?;
    }

    let mut resp = Vec::new();
    stream
        .read_to_end(&mut resp)
        .await
        .map_err(|e| IgnitionError::PodmanExec(format!("UnixStream read error: {}", e)))?;

    let mut headers = [httparse::EMPTY_HEADER; 64];
    let mut parsed_resp = httparse::Response::new(&mut headers);

    let body_start = match parsed_resp.parse(&resp) {
        Ok(httparse::Status::Complete(b)) => b,
        _ => {
            return Err(IgnitionError::PodmanExec(
                "Invalid HTTP response".to_string(),
            ))
        }
    };

    let status = parsed_resp.code.unwrap_or(500);

    let mut is_chunked = false;
    for h in parsed_resp.headers.iter() {
        if h.name.eq_ignore_ascii_case("transfer-encoding") {
            if let Ok(val) = std::str::from_utf8(h.value) {
                if val.to_lowercase().contains("chunked") {
                    is_chunked = true;
                }
            }
        }
    }

    let raw_body = &resp[body_start..];
    let body_string = if is_chunked {
        parse_chunked(raw_body)?
    } else {
        String::from_utf8_lossy(raw_body).to_string()
    };

    Ok((status, body_string))
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTAINER LIFECYCLE FSM (mirrors F# ContainerLifecycleManager.fs)
// Source: ContainerLifecycleManager.fs (states, transitions, is_alive predicate)
// SC-CNT-001: Container lifecycle state MUST be tracked
// ═══════════════════════════════════════════════════════════════════════════════

/// Container lifecycle state (mirrors F# ContainerLifecycleManager states).
#[derive(Debug, Clone, PartialEq)]
pub enum ContainerLifecycle {
    NotFound,
    Created,
    Starting,
    Running,
    Stopping,
    Stopped,
    Removing,
    Dead,
}

impl ContainerLifecycle {
    pub fn from_podman_status(status: &str) -> Self {
        match status.to_lowercase().as_str() {
            s if s.contains("running") => ContainerLifecycle::Running,
            s if s.contains("created") => ContainerLifecycle::Created,
            s if s.contains("exited") || s.contains("stopped") => ContainerLifecycle::Stopped,
            s if s.contains("stopping") => ContainerLifecycle::Stopping,
            s if s.contains("removing") => ContainerLifecycle::Removing,
            s if s.contains("dead") => ContainerLifecycle::Dead,
            _ => ContainerLifecycle::NotFound,
        }
    }

    pub fn is_alive(&self) -> bool {
        matches!(
            self,
            ContainerLifecycle::Running | ContainerLifecycle::Starting
        )
    }
}

/// Get lifecycle state for a container.
pub async fn get_lifecycle(name: &str) -> ContainerLifecycle {
    match container_status(name).await {
        Ok(status) => ContainerLifecycle::from_podman_status(&status),
        Err(_) => ContainerLifecycle::NotFound,
    }
}

#[cfg(test)]
mod lifecycle_tests {
    use super::*;

    #[test]
    fn test_lifecycle_from_running() {
        assert_eq!(
            ContainerLifecycle::from_podman_status("running"),
            ContainerLifecycle::Running
        );
        assert_eq!(
            ContainerLifecycle::from_podman_status("Up (running)"),
            ContainerLifecycle::Running
        );
    }

    #[test]
    fn test_lifecycle_from_exited() {
        assert_eq!(
            ContainerLifecycle::from_podman_status("exited"),
            ContainerLifecycle::Stopped
        );
        assert_eq!(
            ContainerLifecycle::from_podman_status("stopped"),
            ContainerLifecycle::Stopped
        );
        assert_eq!(
            ContainerLifecycle::from_podman_status("Exited (0)"),
            ContainerLifecycle::Stopped
        );
    }

    #[test]
    fn test_lifecycle_is_alive() {
        assert!(ContainerLifecycle::Running.is_alive());
        assert!(ContainerLifecycle::Starting.is_alive());
        assert!(!ContainerLifecycle::Stopped.is_alive());
        assert!(!ContainerLifecycle::Dead.is_alive());
        assert!(!ContainerLifecycle::NotFound.is_alive());
        assert!(!ContainerLifecycle::Created.is_alive());
    }
}

fn parse_chunked(body: &[u8]) -> Result<String, IgnitionError> {
    let mut result = Vec::new();
    let mut i = 0;
    while i < body.len() {
        let mut j = i;
        while j < body.len() && body[j] != b'\r' {
            j += 1;
        }
        if j + 1 >= body.len() || body[j + 1] != b'\n' {
            break;
        }
        let size_str = std::str::from_utf8(&body[i..j]).unwrap_or("");
        let size = usize::from_str_radix(size_str.trim(), 16).unwrap_or(0);
        if size == 0 {
            break;
        }
        i = j + 2;
        if i + size <= body.len() {
            result.extend_from_slice(&body[i..i + size]);
        }
        i += size + 2;
    }
    Ok(String::from_utf8_lossy(&result).to_string())
}
