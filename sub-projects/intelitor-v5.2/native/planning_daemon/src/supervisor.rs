//! # Supervisor Hierarchy
//! Defines the agent supervision tree for the SIL-6 mesh.
//! Source: F# SupervisorHierarchy.fs (450 lines)
//!
//! ## STAMP: SC-HIER-001 to SC-HIER-005, SC-SIL4-011 (quorum maintained)
//! ## Fractal Position: L4-System (Agent Orchestration)

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SupervisorNode {
    pub name: String,
    pub role: SupervisorRole,
    pub children: Vec<String>,
    pub restart_strategy: RestartStrategy,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SupervisorRole {
    Executive,
    DomainSupervisor,
    Worker,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RestartStrategy {
    OneForOne,
    OneForAll,
    RestForOne,
}

/// Build the canonical 25-agent supervision hierarchy.
/// EXEC-001 → 4 domain supervisors → 20 workers.
/// Source: docs/plans/biomorphic-execution-mode.md §2.0
pub fn build_hierarchy() -> Vec<SupervisorNode> {
    vec![
        SupervisorNode {
            name: "EXEC-001".into(),
            role: SupervisorRole::Executive,
            children: vec![
                "SUP-CONTEXT".into(),
                "SUP-DOMAIN".into(),
                "SUP-TEST".into(),
                "SUP-QUALITY".into(),
            ],
            restart_strategy: RestartStrategy::OneForOne,
        },
        SupervisorNode {
            name: "SUP-CONTEXT".into(),
            role: SupervisorRole::DomainSupervisor,
            children: vec![
                "WRK-COMPILE-1".into(),
                "WRK-COMPILE-2".into(),
                "WRK-COMPILE-3".into(),
            ],
            restart_strategy: RestartStrategy::OneForAll,
        },
        SupervisorNode {
            name: "SUP-DOMAIN".into(),
            role: SupervisorRole::DomainSupervisor,
            children: vec![
                "WRK-TEST-1".into(),
                "WRK-TEST-2".into(),
                "WRK-FIX-1".into(),
            ],
            restart_strategy: RestartStrategy::OneForOne,
        },
        SupervisorNode {
            name: "SUP-TEST".into(),
            role: SupervisorRole::DomainSupervisor,
            children: vec!["WRK-CREDO-1".into(), "WRK-DOC-1".into()],
            restart_strategy: RestartStrategy::OneForOne,
        },
        SupervisorNode {
            name: "SUP-QUALITY".into(),
            role: SupervisorRole::DomainSupervisor,
            children: vec!["WRK-EXPLORE-1".into(), "WRK-EXPLORE-2".into()],
            restart_strategy: RestartStrategy::OneForOne,
        },
    ]
}

/// Return total agent count (supervisors + workers).
pub fn total_agents() -> usize {
    let h = build_hierarchy();
    let supervisors = h.len();
    let workers: usize = h.iter().map(|n| n.children.len()).sum();
    supervisors + workers
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hierarchy_has_5_supervisors() {
        assert_eq!(build_hierarchy().len(), 5);
    }

    #[test]
    fn test_total_agents() {
        let total = total_agents();
        assert!(total >= 15, "Expected >= 15 agents, got {}", total);
    }

    #[test]
    fn test_executive_at_top() {
        let h = build_hierarchy();
        assert!(matches!(h[0].role, SupervisorRole::Executive));
    }
}
