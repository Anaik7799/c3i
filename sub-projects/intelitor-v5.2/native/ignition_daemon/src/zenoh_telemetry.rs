use zenoh::Session;
use crate::tui::OtelSpan;
use crate::errors::IgnitionError;
use log::{info, error};
use std::sync::Arc;

pub struct ZenohTelemetry {
    pub session: Arc<Session>,
}

impl ZenohTelemetry {
    pub async fn new() -> Result<Self, IgnitionError> {
        let session = zenoh::open(zenoh::Config::default())
            .await
            .map_err(|e| IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string())))?;
        
        Ok(Self {
            session: Arc::new(session),
        })
    }

    pub async fn publish_span(&self, key_expr: &str, span: &OtelSpan) -> Result<(), IgnitionError> {
        let payload = serde_json::to_string(span).unwrap();
        self.session.put(key_expr, payload).await.map_err(|e| {
            IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
        })?;
        Ok(())
    }

    pub async fn publish_element_state(&self, tab: usize, element: &str, state: &str) -> Result<(), IgnitionError> {
        let key = format!("indrajaal/tui/tab/{}/element/{}", tab, element);
        self.session.put(key, state).await.map_err(|e| {
            IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
        })?;
        Ok(())
    }
}

pub async fn flight_check(telemetry: &ZenohTelemetry) -> Result<(), IgnitionError> {
    info!("── Flight Check: Zenoh Data & Control Paths ──");
    
    // Check if we can write to a test path
    let test_key = "indrajaal/test/path";
    telemetry.session.put(test_key, "PING").await.map_err(|e| {
        error!("Fractal RCA: Zenoh path setup FAILED. Jidoka triggered.");
        IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, format!("Zenoh Preflight Fail: {}", e)))
    })?;

    info!("✓ Zenoh Control Path: OK");
    Ok(())
}

pub async fn run_observer() -> Result<(), IgnitionError> {
    let session = zenoh::open(zenoh::Config::default())
        .await
        .map_err(|e| IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string())))?;

    info!("🔭 Zenoh Observer ACTIVE (Listening on indrajaal/**)");

    let subscriber = session.declare_subscriber("indrajaal/**").await.map_err(|e| {
        IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
    })?;

    while let Ok(sample) = subscriber.recv_async().await {
        let key = sample.key_expr().to_string();
        let payload = format!("{:?}", sample.payload());
        info!("[ZENOH] {} ↳ {}", key, payload);
    }

    Ok(())
}
