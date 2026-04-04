//! # Seven-Level RCA
//!
//! L1-L7 Root Cause Analysis mapping.
//! Track E: EVO-10 - 7-Level Root Cause Analysis

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RcaLevel {
    L1AtomicDebug,
    L2Component,
    L3Transaction,
    L4System,
    L5Cognitive,
    L6Ecosystem,
    L7Federation,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RcaResult {
    pub level: RcaLevel,
    pub issue_pattern: String,
    pub description: String,
    pub suggested_action: String,
}

pub fn analyze_error(error_log: &str) -> RcaResult {
    if error_log.contains("NIF compilation") || error_log.contains("glibc") {
        RcaResult {
            level: RcaLevel::L1AtomicDebug,
            issue_pattern: "NIF/Binary mismatch".to_string(),
            description: "Binary incompatibility detected at the lowest level.".to_string(),
            suggested_action: "Rebuild NIFs with correct libc target.".to_string(),
        }
    } else if error_log.contains("port already in use") || error_log.contains("connection refused")
    {
        RcaResult {
            level: RcaLevel::L2Component,
            issue_pattern: "Component isolation failure".to_string(),
            description: "A component failed to bind to its expected network interface."
                .to_string(),
            suggested_action: "Check port bindings and component state.".to_string(),
        }
    } else if error_log.contains("transaction timeout") {
        RcaResult {
            level: RcaLevel::L3Transaction,
            issue_pattern: "Transaction timeout".to_string(),
            description: "A state mutation transaction timed out.".to_string(),
            suggested_action: "Check database locks and Zenoh router load.".to_string(),
        }
    } else if error_log.contains("container") || error_log.contains("podman") {
        RcaResult {
            level: RcaLevel::L4System,
            issue_pattern: "Container Orchestration failure".to_string(),
            description: "Container lifecycle failed.".to_string(),
            suggested_action: "Review podman logs and resource limits.".to_string(),
        }
    } else if error_log.contains("model drift") || error_log.contains("LLM") {
        RcaResult {
            level: RcaLevel::L5Cognitive,
            issue_pattern: "Cognitive failure".to_string(),
            description: "Ollama or Cortex model failed to respond correctly.".to_string(),
            suggested_action: "Check ML runner health and memory.".to_string(),
        }
    } else if error_log.contains("split brain") || error_log.contains("quorum") {
        RcaResult {
            level: RcaLevel::L6Ecosystem,
            issue_pattern: "Ecosystem quorum loss".to_string(),
            description: "Mesh failed to reach consensus.".to_string(),
            suggested_action: "Check network partitions and Zenoh topology.".to_string(),
        }
    } else {
        RcaResult {
            level: RcaLevel::L7Federation,
            issue_pattern: "Unknown/Federation issue".to_string(),
            description: "Issue spans multiple mesh instances or is unidentified.".to_string(),
            suggested_action: "Engage Guardian / Level 7 debugging.".to_string(),
        }
    }
}
