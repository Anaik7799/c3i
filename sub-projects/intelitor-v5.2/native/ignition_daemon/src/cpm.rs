use crate::dag::DependencyGraph;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct TaskTiming {
    pub early_start: u64,
    pub early_finish: u64,
    pub late_start: u64,
    pub late_finish: u64,
    pub float: u64,
    pub is_critical: bool,
}

pub struct CpmResult {
    pub timings: HashMap<String, TaskTiming>,
    pub critical_path: Vec<String>,
    pub total_duration: u64,
}

pub fn calculate_cpm(
    dg: &DependencyGraph,
    task_durations: &HashMap<String, u64>,
) -> Result<CpmResult, String> {
    if dg.has_cycle() {
        return Err("Cannot calculate CPM on a graph with cycles".into());
    }

    let topo = dg.toposort()?;

    // Forward Pass
    let mut early_start = HashMap::new();
    let mut early_finish = HashMap::new();

    for task in &topo {
        let duration = task_durations.get(task).copied().unwrap_or(0);
        let mut es = 0;

        if let Some(&node_idx) = dg.node_indices.get(task) {
            use petgraph::visit::EdgeRef;
            for edge in dg
                .graph
                .edges_directed(node_idx, petgraph::Direction::Incoming)
            {
                let pred_idx = edge.source();
                let pred_name = &dg.graph[pred_idx];
                if let Some(&pred_ef) = early_finish.get(pred_name) {
                    es = es.max(pred_ef);
                }
            }
        }

        early_start.insert(task.clone(), es);
        early_finish.insert(task.clone(), es + duration);
    }

    let total_duration = *early_finish.values().max().unwrap_or(&0);

    // Backward Pass
    let mut late_start = HashMap::new();
    let mut late_finish = HashMap::new();

    for task in topo.iter().rev() {
        let duration = task_durations.get(task).copied().unwrap_or(0);
        let mut lf = total_duration;

        if let Some(&node_idx) = dg.node_indices.get(task) {
            use petgraph::visit::EdgeRef;
            let mut has_successors = false;
            for edge in dg
                .graph
                .edges_directed(node_idx, petgraph::Direction::Outgoing)
            {
                has_successors = true;
                let succ_idx = edge.target();
                let succ_name = &dg.graph[succ_idx];
                if let Some(&succ_ls) = late_start.get(succ_name) {
                    lf = lf.min(succ_ls);
                }
            }
            if !has_successors {
                lf = total_duration;
            }
        }

        late_finish.insert(task.clone(), lf);
        late_start.insert(task.clone(), lf.saturating_sub(duration));
    }

    // Calculate float and determine critical path
    let mut timings = HashMap::new();
    let mut critical_path = Vec::new();

    for task in &topo {
        let es = early_start[task];
        let ef = early_finish[task];
        let ls = late_start[task];
        let lf = late_finish[task];

        let float = ls.saturating_sub(es);
        let is_critical = float == 0;

        if is_critical {
            critical_path.push(task.clone());
        }

        timings.insert(
            task.clone(),
            TaskTiming {
                early_start: es,
                early_finish: ef,
                late_start: ls,
                late_finish: lf,
                float,
                is_critical,
            },
        );
    }

    Ok(CpmResult {
        timings,
        critical_path,
        total_duration,
    })
}
