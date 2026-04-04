use crate::artifacts::SIL6_GENOME;
use crate::errors::IgnitionError;
use crate::podman;
use log::{info, warn};
use tokio::task::JoinSet;

pub async fn run_down() -> Result<(), IgnitionError> {
    info!("── [L4] Initiating SIL-6 Mesh Graceful Shutdown ──");
    
    let mut set = JoinSet::new();
    
    for &container in SIL6_GENOME {
        set.spawn(async move {
            info!("  ↓ Stopping: {}", container);
            // 10s graceful timeout before force kill
            podman::stop_container(container, 10).await
        });
    }
    
    let mut errors = 0;
    while let Some(res) = set.join_next().await {
        match res {
            Ok(Err(e)) => {
                warn!("  ⚠ Shutdown error: {}", e);
                errors += 1;
            }
            Err(e) => {
                warn!("  ⚠ Task join error: {}", e);
                errors += 1;
            }
            _ => {}
        }
    }
    
    if errors > 0 {
        warn!("── [L4] Mesh shutdown completed with {} errors ──", errors);
    } else {
        info!("── [L4] Mesh shutdown completed successfully ──");
    }
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_run_down_no_panic() {
        // This test ensures run_down doesn't panic even if podman fails
        // or no containers are running.
        let result = run_down().await;
        assert!(result.is_ok());
    }
}
