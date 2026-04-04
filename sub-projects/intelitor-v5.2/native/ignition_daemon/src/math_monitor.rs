//! # Mathematical System Monitor
//! Track E: Wave 3 — 17 mathematical disciplines with health scoring.
//! Source: F# MathematicalSystemMonitor.fs (875 lines)

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MathDiscipline {
    pub name: String,
    pub health: f64,
    pub rpn: u32,
}

pub fn all_disciplines() -> Vec<MathDiscipline> {
    vec![
        MathDiscipline { name: "Control Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Information Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Category Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Graph Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Queueing Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Probability".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Optimization".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Algebra".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Analysis".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Linear Algebra".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Combinatorics".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Set Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Topology".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Statistics".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Number Theory".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Logic".into(), health: 1.0, rpn: 0 },
        MathDiscipline { name: "Game Theory".into(), health: 1.0, rpn: 0 },
    ]
}

pub fn discipline_count() -> usize { 17 }

pub fn overall_health(disciplines: &[MathDiscipline]) -> f64 {
    if disciplines.is_empty() { return 0.0; }
    disciplines.iter().map(|d| d.health).sum::<f64>() / disciplines.len() as f64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_17_disciplines() {
        assert_eq!(all_disciplines().len(), 17);
    }

    #[test]
    fn test_overall_health_perfect() {
        let d = all_disciplines();
        assert!((overall_health(&d) - 1.0).abs() < 0.001);
    }
}
