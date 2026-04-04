use crate::errors::IgnitionError;
use log::info;
use zenoh::Session;

pub async fn run_stabilize() -> Result<(), IgnitionError> {
    info!("── [L0] State Stabilization Triggered ──");
    let session = zenoh::open(zenoh::Config::default()).await.map_err(|e| {
        IgnitionError::IoError(std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
    })?;
    
    info!("Broadcasting OODA pause command...");
    let _ = session.put("indrajaal/l5/ooda/pause", "true").await;
    info!("── [L0] Mutations halted, system stabilized ──");
    Ok(())
}
