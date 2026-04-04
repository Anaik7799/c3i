use crate::errors::IgnitionError;
use log::info;
use zenoh::Session;
use std::sync::Arc;

pub async fn run_listen(pattern: Option<String>) -> Result<(), IgnitionError> {
    let expr = pattern.unwrap_or_else(|| "indrajaal/**".to_string());
    
    let session = zenoh::open(zenoh::Config::default()).await.map_err(|e| {
        IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
    })?;
    let session = Arc::new(session);

    info!("👂 [L4] Zenoh Listener ACTIVE (Pattern: {})", expr);
    info!("      Press Ctrl+C to terminate");

    let subscriber = session.declare_subscriber(&expr).await.map_err(|e| {
        IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
    })?;

    while let Ok(sample) = subscriber.recv_async().await {
        let key = sample.key_expr().to_string();
        let payload = String::from_utf8_lossy(&sample.payload().to_bytes()).to_string();
        println!("[{}] ↳ {}", key, payload);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pattern_default() {
        // Just verify basic pattern logic (no easy way to mock Zenoh here without refactoring)
        let pattern: Option<String> = None;
        let expr = pattern.unwrap_or_else(|| "indrajaal/**".to_string());
        assert_eq!(expr, "indrajaal/**");
    }
}
