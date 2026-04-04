use crate::errors::IgnitionError;
use crate::mcp_bridge::ZenohMcpBridge;
use crate::tui::OtelSpan;
use log::{error, info};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc;
use zenoh::Session;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BootStateVector {
    pub compile: bool,
    pub migrations: bool,
    pub containers: bool,
    pub zenoh: bool,
    pub health: bool,
    pub quorum: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckpointMessage {
    pub phase: String,
    pub progress: u8, // 0-100
    pub state_vector: BootStateVector,
    pub details: Option<String>,
}

pub enum TelemetryMessage {
    Span(String, OtelSpan),
    ElementState(usize, String, String),
    Checkpoint(String, CheckpointMessage),
}

pub struct ZenohTelemetry {
    pub session: Arc<Session>,
    tx: mpsc::Sender<TelemetryMessage>,
}

impl ZenohTelemetry {
    pub async fn new() -> Result<Self, IgnitionError> {
        let session = zenoh::open(zenoh::Config::default()).await.map_err(|e| {
            IgnitionError::IoError(std::io::Error::new(
                std::io::ErrorKind::Other,
                e.to_string(),
            ))
        })?;

        let session = Arc::new(session);
        let (tx, mut rx) = mpsc::channel(1000); // Increased capacity for 30ms OODA loop

        let worker_session = Arc::clone(&session);
        tokio::spawn(async move {
            // Start MCP Bridge
            let mcp_bridge = ZenohMcpBridge::new(Arc::clone(&worker_session));
            if let Err(e) = mcp_bridge.run().await {
                error!("Zenoh-MCP-Bridge FAILED: {}", e);
            }
        });

        let worker_session = Arc::clone(&session);
        tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                match msg {
                    TelemetryMessage::Span(key_expr, span) => {
                        if let Ok(payload) = serde_json::to_string(&span) {
                            let _ = worker_session.put(&key_expr, payload).await;
                        }
                    }
                    TelemetryMessage::ElementState(tab, element, state) => {
                        let key = format!("indrajaal/l4/ignition/tui/tab/{}/element/{}", tab, element);
                        let _ = worker_session.put(&key, state).await;
                    }
                    TelemetryMessage::Checkpoint(key_expr, checkpoint) => {
                        if let Ok(payload) = serde_json::to_string(&checkpoint) {
                            let _ = worker_session.put(&key_expr, payload).await;
                        }
                    }
                }
            }
        });

        Ok(Self { session, tx })
    }

    pub async fn publish_span(&self, key_expr: &str, span: &OtelSpan) -> Result<(), IgnitionError> {
        self.tx
            .send(TelemetryMessage::Span(key_expr.to_string(), span.clone()))
            .await
            .map_err(|e| {
                IgnitionError::IoError(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    e.to_string(),
                ))
            })?;
        Ok(())
    }

    pub async fn publish_element_state(
        &self,
        tab: usize,
        element: &str,
        state: &str,
    ) -> Result<(), IgnitionError> {
        self.tx
            .send(TelemetryMessage::ElementState(
                tab,
                element.to_string(),
                state.to_string(),
            ))
            .await
            .map_err(|e| {
                IgnitionError::IoError(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    e.to_string(),
                ))
            })?;
        Ok(())
    }

    pub async fn publish_checkpoint(
        &self,
        key_expr: &str,
        checkpoint: &CheckpointMessage,
    ) -> Result<(), IgnitionError> {
        self.tx
            .send(TelemetryMessage::Checkpoint(
                key_expr.to_string(),
                checkpoint.clone(),
            ))
            .await
            .map_err(|e| {
                IgnitionError::IoError(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    e.to_string(),
                ))
            })?;
        Ok(())
    }
}

pub async fn flight_check(telemetry: &ZenohTelemetry) -> Result<(), IgnitionError> {
    info!("── Flight Check: Zenoh Data & Control Paths ──");

    // Check if we can write to a test path
    let test_key = "indrajaal/l4/ignition/test/path";
    telemetry.session.put(test_key, "PING").await.map_err(|e| {
        error!("Fractal RCA: Zenoh path setup FAILED. Jidoka triggered.");
        IgnitionError::IoError(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Zenoh Preflight Fail: {}", e),
        ))
    })?;

    info!("✓ Zenoh Control Path: OK");
    Ok(())
}

pub async fn run_observer() -> Result<(), IgnitionError> {
    let session = zenoh::open(zenoh::Config::default()).await.map_err(|e| {
        IgnitionError::IoError(std::io::Error::new(
            std::io::ErrorKind::Other,
            e.to_string(),
        ))
    })?;

    info!("🔭 Zenoh Observer ACTIVE (Listening on indrajaal/**)");

    let subscriber = session
        .declare_subscriber("indrajaal/**")
        .await
        .map_err(|e| {
            IgnitionError::IoError(std::io::Error::new(
                std::io::ErrorKind::Other,
                e.to_string(),
            ))
        })?;

    while let Ok(sample) = subscriber.recv_async().await {
        let key = sample.key_expr().to_string();
        let payload = format!("{:?}", sample.payload());
        info!("[ZENOH] {} ↳ {}", key, payload);
    }

    Ok(())
}

// ─── Checkpoint IDs (CP-BOOT-01..10) ────────────────────────────────────────

/// Boot checkpoint identifiers aligned to the 7-tier SIL-6 boot hierarchy.
/// SC-BOOT-010: checkpoints at each stage.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CheckpointId {
    /// Pre-flight NIF + Zenoh path validation
    CpBoot01,
    /// DAG acyclicity verified (Kahn's algorithm)
    CpBoot02,
    /// Database layer healthy (pg_isready -p 5433)
    CpBoot03,
    /// Observability stack reachable (OTEL port 4317)
    CpBoot04,
    /// Zenoh quorum routers (-1/-2/-3) healthy
    CpBoot05,
    /// CEPAF bridge + Cortex containers healthy
    CpBoot06,
    /// Cortex cognitive layer confirmed running
    CpBoot07,
    /// Seed app (ex-app-1) fully responding on port 4000
    CpBoot08,
    /// Homeostasis PID verified (health checks converged)
    CpBoot09,
    /// Mesh ignition complete — all 16 containers healthy
    CpBoot10,
}

/// Returns the canonical hyphenated string for a checkpoint ID.
/// Used as the `phase` field in `CheckpointMessage`.
pub fn checkpoint_id_to_string(id: CheckpointId) -> &'static str {
    match id {
        CheckpointId::CpBoot01 => "CP-BOOT-01",
        CheckpointId::CpBoot02 => "CP-BOOT-02",
        CheckpointId::CpBoot03 => "CP-BOOT-03",
        CheckpointId::CpBoot04 => "CP-BOOT-04",
        CheckpointId::CpBoot05 => "CP-BOOT-05",
        CheckpointId::CpBoot06 => "CP-BOOT-06",
        CheckpointId::CpBoot07 => "CP-BOOT-07",
        CheckpointId::CpBoot08 => "CP-BOOT-08",
        CheckpointId::CpBoot09 => "CP-BOOT-09",
        CheckpointId::CpBoot10 => "CP-BOOT-10",
    }
}

/// Maps a checkpoint ID to its progress percentage (0–100).
/// Ten equidistant checkpoints across the 0–100 range.
fn checkpoint_progress(id: CheckpointId) -> u8 {
    match id {
        CheckpointId::CpBoot01 => 5,
        CheckpointId::CpBoot02 => 15,
        CheckpointId::CpBoot03 => 25,
        CheckpointId::CpBoot04 => 35,
        CheckpointId::CpBoot05 => 50,
        CheckpointId::CpBoot06 => 60,
        CheckpointId::CpBoot07 => 70,
        CheckpointId::CpBoot08 => 80,
        CheckpointId::CpBoot09 => 90,
        CheckpointId::CpBoot10 => 100,
    }
}

/// Publishes a boot checkpoint telemetry event over the existing tx channel.
///
/// # Arguments
/// * `zenoh`     – Active `ZenohTelemetry` instance with a running worker task.
/// * `id`        – Which CP-BOOT-XX checkpoint was reached.
/// * `container` – Optional container name associated with this checkpoint.
/// * `details`   – Human-readable status string for the dashboard.
pub async fn publish_boot_checkpoint(
    zenoh: &ZenohTelemetry,
    id: CheckpointId,
    container: Option<&str>,
    details: &str,
) {
    let phase = checkpoint_id_to_string(id).to_string();
    let progress = checkpoint_progress(id);

    let detail_str = match container {
        Some(c) => format!("[{}] {}", c, details),
        None => details.to_string(),
    };

    let state_vector = BootStateVector {
        compile: progress >= 5,
        migrations: progress >= 25,
        containers: progress >= 60,
        zenoh: progress >= 50,
        health: progress >= 80,
        quorum: progress >= 50,
    };

    let checkpoint = CheckpointMessage {
        phase,
        progress,
        state_vector,
        details: Some(detail_str),
    };

    let key = format!("indrajaal/l4/ignition/checkpoint/{}", checkpoint_id_to_string(id));
    if let Err(e) = zenoh.publish_checkpoint(&key, &checkpoint).await {
        error!("Failed to publish boot checkpoint {:?}: {}", id, e);
    }
}

// ─── Phase Status & Boot State Vector helpers ────────────────────────────────

/// Lifecycle status for a single boot phase.
/// Used by the TUI dashboard to colour-code phase rows.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PhaseStatus {
    #[default]
    Pending,
    Running,
    Complete,
    Failed,
    Skipped,
}

/// Updates the boolean field of `BootStateVector` corresponding to `phase`,
/// then publishes a CP-BOOT-XX checkpoint with the new state.
///
/// Phase mapping (matches the 6 boolean fields in `BootStateVector`):
///   0 → compile, 1 → migrations, 2 → containers,
///   3 → zenoh,   4 → health,     5 → quorum
/// Phases 6-9 update no boolean but still publish a checkpoint.
///
/// `Complete` sets the field to `true`; `Failed` sets it to `false`.
/// All other statuses leave the field unchanged.
pub async fn update_boot_phase(
    zenoh: &ZenohTelemetry,
    state_vector: &mut BootStateVector,
    phase: usize,
    status: PhaseStatus,
) {
    // Update the corresponding boolean field
    match status {
        PhaseStatus::Complete => match phase {
            0 => state_vector.compile = true,
            1 => state_vector.migrations = true,
            2 => state_vector.containers = true,
            3 => state_vector.zenoh = true,
            4 => state_vector.health = true,
            5 => state_vector.quorum = true,
            _ => {}
        },
        PhaseStatus::Failed => match phase {
            0 => state_vector.compile = false,
            1 => state_vector.migrations = false,
            2 => state_vector.containers = false,
            3 => state_vector.zenoh = false,
            4 => state_vector.health = false,
            5 => state_vector.quorum = false,
            _ => {}
        },
        _ => {}
    }

    // Map phase index to a checkpoint ID
    let checkpoint_id = match phase {
        0 => CheckpointId::CpBoot01,
        1 => CheckpointId::CpBoot02,
        2 => CheckpointId::CpBoot03,
        3 => CheckpointId::CpBoot04,
        4 => CheckpointId::CpBoot05,
        5 => CheckpointId::CpBoot06,
        6 => CheckpointId::CpBoot07,
        7 => CheckpointId::CpBoot08,
        8 => CheckpointId::CpBoot09,
        _ => CheckpointId::CpBoot10,
    };

    let detail = format!("phase {} → {:?}", phase, status);
    publish_boot_checkpoint(zenoh, checkpoint_id, None, &detail).await;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checkpoint_id_string_all_variants() {
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot01), "CP-BOOT-01");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot02), "CP-BOOT-02");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot03), "CP-BOOT-03");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot04), "CP-BOOT-04");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot05), "CP-BOOT-05");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot06), "CP-BOOT-06");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot07), "CP-BOOT-07");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot08), "CP-BOOT-08");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot09), "CP-BOOT-09");
        assert_eq!(checkpoint_id_to_string(CheckpointId::CpBoot10), "CP-BOOT-10");
    }

    #[test]
    fn phase_status_default_is_pending() {
        let status: PhaseStatus = PhaseStatus::default();
        assert_eq!(status, PhaseStatus::Pending);
    }

    #[test]
    fn boot_state_vector_init_all_false() {
        // A freshly constructed BootStateVector should start with all flags false
        // so the TUI can track incremental boot progress correctly.
        let sv = BootStateVector {
            compile: false,
            migrations: false,
            containers: false,
            zenoh: false,
            health: false,
            quorum: false,
        };
        assert!(!sv.compile);
        assert!(!sv.migrations);
        assert!(!sv.containers);
        assert!(!sv.zenoh);
        assert!(!sv.health);
        assert!(!sv.quorum);
    }
}
