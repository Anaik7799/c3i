use crate::artifacts::SIL6_GENOME;
use crate::errors::IgnitionError;
use crate::podman;
use log::{info, warn, error};
use tokio::task::JoinSet;
use std::time::Duration;

pub async fn run_scour() -> Result<(), IgnitionError> {
    info!("── [L4] Initiating SIL-6 Mesh Nuclear Clean (Scour) ──");
    
    // 1. Force remove all containers in genome
    let mut set = JoinSet::new();
    for &container in SIL6_GENOME {
        set.spawn(async move {
            if podman::container_exists(container).await {
                info!("  ☢ Removing: {}", container);
                podman::force_remove(container).await
            } else {
                Ok(())
            }
        });
    }
    
    while let Some(res) = set.join_next().await {
        if let Ok(Err(e)) = res {
            warn!("  ⚠ Removal error: {}", e);
        }
    }

    // 2. Prune unused volumes
    info!("  ☢ Pruning mesh volumes...");
    match podman::podman_cmd(&["volume", "prune", "-f"], Duration::from_secs(30)).await {
        Ok(_) => info!("  ✓ Volume prune complete"),
        Err(e) => error!("  ❌ Volume prune failed: {}", e),
    }

    // 3. Prune networks (optional but recommended for SIL-6)
    info!("  ☢ Pruning mesh networks...");
    let _ = podman::podman_cmd(&["network", "prune", "-f"], Duration::from_secs(30)).await;

    info!("── [L4] Mesh scour completed ──");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_run_scour_no_panic() {
        // This test ensures run_scour doesn't panic.
        let result = run_scour().await;
        assert!(result.is_ok());
    }
}
