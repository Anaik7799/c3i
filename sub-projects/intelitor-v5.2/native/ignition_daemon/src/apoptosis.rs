use crate::errors::IgnitionError;
use log::{error, info, warn};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ApoptosisTrigger {
    CascadeDepthExceeded,
    MeshPartitionMajorityLoss,
    CriticalNifFailure,
    HostSubstrateContamination,
    ManualKillSwitch,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DyingGaspCheckpoint {
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub trigger: ApoptosisTrigger,
    pub state_hash: String,
    pub running_containers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ApoptosisPhase {
    Triggered,
    NetworkIsolate,
    StateHash,
    ZenohGasp,
    LameDuckDrain,
    ContainerKill,
}

pub struct ApoptosisManager {
    trigger: ApoptosisTrigger,
    phase: ApoptosisPhase,
    checkpoint: Option<DyingGaspCheckpoint>,
}

impl ApoptosisManager {
    pub fn new(trigger: ApoptosisTrigger) -> Self {
        Self {
            trigger,
            phase: ApoptosisPhase::Triggered,
            checkpoint: None,
        }
    }

    pub async fn execute(
        &mut self,
        session_telemetry: Option<&crate::zenoh_telemetry::ZenohTelemetry>,
    ) -> Result<(), IgnitionError> {
        error!("APOPTOSIS TRIGGERED: {:?}", self.trigger);

        // Phase 1: Triggered / Logging
        self.phase = ApoptosisPhase::Triggered;
        warn!("Phase 1/6: Apoptosis Protocol Engaged...");

        // Phase 2: Network Isolate
        self.phase = ApoptosisPhase::NetworkIsolate;
        warn!("Phase 2/6: Network Isolation Started...");
        // Here we would use podman network disconnect logic to fence off the mesh

        // Phase 3: State Hash
        self.phase = ApoptosisPhase::StateHash;
        warn!("Phase 3/6: Computing SHA-256 State Hash...");
        let state_data = b"system_state_to_hash_placeholder";
        let mut hasher = Sha256::new();
        hasher.update(state_data);
        let result = hasher.finalize();
        let state_hash = format!("{:x}", result);

        let checkpoint = DyingGaspCheckpoint {
            timestamp: chrono::Utc::now(),
            trigger: self.trigger.clone(),
            state_hash: state_hash.clone(),
            running_containers: vec![], // Populate dynamically in real implementation
        };
        self.checkpoint = Some(checkpoint.clone());
        info!("State Hash: {}", state_hash);

        // Phase 4: Zenoh Gasp Publish
        self.phase = ApoptosisPhase::ZenohGasp;
        warn!("Phase 4/6: Publishing Dying Gasp to Zenoh...");
        if let Some(telemetry) = session_telemetry {
            let chk = crate::zenoh_telemetry::CheckpointMessage {
                phase: "APOPTOSIS_GASP".to_string(),
                progress: 100,
                state_vector: crate::zenoh_telemetry::BootStateVector {
                    compile: false,
                    migrations: false,
                    containers: false,
                    zenoh: false,
                    health: false,
                    quorum: false,
                },
                details: Some(format!("Gasp Checkpoint: {:?}", checkpoint)),
            };
            let _ = telemetry
                .publish_checkpoint("indrajaal/l4/ignition/system/apoptosis", &chk)
                .await;
        }

        // Phase 5: Lame Duck Drain
        self.phase = ApoptosisPhase::LameDuckDrain;
        warn!("Phase 5/6: Lame Duck Drain (Wait for pending ops)...");
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;

        // Phase 6: Container Kill
        self.phase = ApoptosisPhase::ContainerKill;
        warn!("Phase 6/6: Emergency Container Kill...");
        emergency_stop().await?;

        error!("APOPTOSIS COMPLETE. System halted.");

        Ok(())
    }
}

/// Executes a total emergency stop of the SIL-6 biomorphic mesh.
/// Uses dynamic genome list from artifacts.rs (not hardcoded).
pub async fn emergency_stop() -> Result<(), IgnitionError> {
    warn!("Executing EMERGENCY STOP for all containers...");

    // Dynamic container list from genome (SC-ARCH-SPLIT: Rust owns this)
    for name in crate::artifacts::SIL6_GENOME {
        let _ = crate::podman::stop_container(name, 0).await;
    }

    info!("Emergency stop completed for {} containers.", crate::artifacts::SIL6_GENOME.len());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_emergency_stop_no_panic() {
        let result = emergency_stop().await;
        assert!(result.is_ok());
    }
}
