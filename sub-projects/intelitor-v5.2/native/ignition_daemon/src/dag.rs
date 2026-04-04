use petgraph::algo::{is_cyclic_directed, toposort};
use petgraph::graph::DiGraph;
use petgraph::visit::{Dfs, EdgeRef, Reversed};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DagConfig {
    pub nodes: Vec<String>,
    pub edges: HashMap<String, Vec<String>>,
}

#[derive(Debug, Clone)]
pub struct DependencyGraph {
    pub graph: DiGraph<String, ()>,
    pub node_indices: HashMap<String, petgraph::graph::NodeIndex>,
}

impl DependencyGraph {
    pub fn new() -> Self {
        Self {
            graph: DiGraph::new(),
            node_indices: HashMap::new(),
        }
    }

    pub fn from_config(config: &DagConfig) -> Result<Self, String> {
        let mut dg = Self::new();
        for node in &config.nodes {
            dg.add_container(node);
        }
        for (node, deps) in &config.edges {
            for dep in deps {
                dg.add_dependency(node, dep);
            }
        }
        if dg.has_cycle() {
            return Err("Cycle detected in DAG configuration".into());
        }
        Ok(dg)
    }

    pub fn load_from_file(path: &str) -> Result<Self, String> {
        let content =
            fs::read_to_string(path).map_err(|e| format!("Failed to read {}: {}", path, e))?;
        let config: DagConfig =
            toml::from_str(&content).map_err(|e| format!("Failed to parse {}: {}", path, e))?;
        Self::from_config(&config)
    }

    pub fn add_container(&mut self, name: &str) {
        if !self.node_indices.contains_key(name) {
            let idx = self.graph.add_node(name.to_string());
            self.node_indices.insert(name.to_string(), idx);
        }
    }

    pub fn add_dependency(&mut self, container: &str, dependency: &str) {
        self.add_container(container);
        self.add_container(dependency);
        let c_idx = self.node_indices[container];
        let d_idx = self.node_indices[dependency];
        // Dependency must be satisfied before container -> edge from dependency to container
        self.graph.add_edge(d_idx, c_idx, ());
    }

    pub fn has_cycle(&self) -> bool {
        is_cyclic_directed(&self.graph)
    }

    pub fn toposort(&self) -> Result<Vec<String>, String> {
        match toposort(&self.graph, None) {
            Ok(indices) => Ok(indices
                .into_iter()
                .map(|idx| self.graph[idx].clone())
                .collect()),
            Err(_) => Err("Cycle detected".into()),
        }
    }

    pub fn calculate_waves(&self) -> Vec<Vec<String>> {
        let mut in_degrees = HashMap::new();
        for idx in self.graph.node_indices() {
            let in_degree = self
                .graph
                .edges_directed(idx, petgraph::Direction::Incoming)
                .count();
            in_degrees.insert(idx, in_degree);
        }

        let mut waves = Vec::new();
        let mut remaining = in_degrees.clone();

        loop {
            let wave_indices: Vec<_> = remaining
                .iter()
                .filter(|(_, &deg)| deg == 0)
                .map(|(&idx, _)| idx)
                .collect();

            if wave_indices.is_empty() {
                break;
            }

            let mut current_wave = Vec::new();
            for idx in wave_indices {
                current_wave.push(self.graph[idx].clone());
                remaining.remove(&idx);
                for edge in self
                    .graph
                    .edges_directed(idx, petgraph::Direction::Outgoing)
                {
                    let target = edge.target();
                    if let Some(deg) = remaining.get_mut(&target) {
                        *deg -= 1;
                    }
                }
            }
            current_wave.sort();
            waves.push(current_wave);
        }

        waves
    }

    pub fn upstream(&self, node: &str) -> Vec<String> {
        let mut result = HashSet::new();
        if let Some(&start_idx) = self.node_indices.get(node) {
            let reversed = Reversed(&self.graph);
            let mut dfs = Dfs::new(reversed, start_idx);
            while let Some(nx) = dfs.next(reversed) {
                if nx != start_idx {
                    result.insert(self.graph[nx].clone());
                }
            }
        }
        let mut sorted: Vec<_> = result.into_iter().collect();
        sorted.sort();
        sorted
    }

    pub fn downstream(&self, node: &str) -> Vec<String> {
        let mut result = HashSet::new();
        if let Some(&start_idx) = self.node_indices.get(node) {
            let mut dfs = Dfs::new(&self.graph, start_idx);
            while let Some(nx) = dfs.next(&self.graph) {
                if nx != start_idx {
                    result.insert(self.graph[nx].clone());
                }
            }
        }
        let mut sorted: Vec<_> = result.into_iter().collect();
        sorted.sort();
        sorted
    }
}
