use crate::errors::IgnitionError;
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
    pub progress: u8,
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
        let (tx, mut rx) = mpsc::channel(1000);

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
                        let key = format!("indrajaal/l4/planning/tui/tab/{}/element/{}", tab, element);
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
        let _ = self.tx.send(TelemetryMessage::Span(key_expr.to_string(), span.clone())).await;
        Ok(())
    }
}

pub async fn run_observer() -> Result<(), IgnitionError> {
    let session = zenoh::open(zenoh::Config::default()).await.unwrap();
    info!("🔭 Zenoh Observer ACTIVE (Listening on indrajaal/**)");
    let subscriber = session.declare_subscriber("indrajaal/**").await.unwrap();
    while let Ok(sample) = subscriber.recv_async().await {
        let key = sample.key_expr().to_string();
        let payload = format!("{:?}", sample.payload());
        info!("[ZENOH] {} ↳ {}", key, payload);
    }
    Ok(())
}
