//! # Digital Twin — Genotype/Phenotype Model
//!
//! Maps F# genotype (expected state) to phenotype (actual state).
//! EVO-5: Genotype vs Phenotype evaluation

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Genotype {
    pub container_name: String,
    pub expected_image: String,
    pub expected_ports: Vec<u16>,
    pub expected_env: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Phenotype {
    pub container_name: String,
    pub actual_image: String,
    pub actual_ports: Vec<u16>,
    pub actual_env: HashMap<String, String>,
    pub running: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TwinDrift {
    pub container_name: String,
    pub image_drift: bool,
    pub port_drift: Vec<u16>,   // Ports expected but missing or unexpected
    pub env_drift: Vec<String>, // Env keys missing or mismatched
    pub is_aligned: bool,
}

/// Build the full SIL-6 genome with expected images, ports, and env for all 16 containers.
pub fn build_sil6_genotypes() -> Vec<Genotype> {
    vec![
        geno("indrajaal-db-prod", "localhost/indrajaal-db-prod:latest", &[5433], &[("POSTGRES_USER", "postgres")]),
        geno("indrajaal-obs-prod", "localhost/indrajaal-obs-prod:latest", &[4317, 9090, 3000], &[]),
        geno("indrajaal-ex-app-1", "localhost/indrajaal-ex-app-1:latest", &[4000, 4001], &[("MIX_ENV", "prod"), ("ZENOH_ENABLED", "true")]),
        geno("cepaf-bridge", "localhost/cepaf-bridge:latest", &[9876], &[]),
        geno("indrajaal-cortex", "localhost/indrajaal-cortex:latest", &[], &[]),
        geno("zenoh-router", "docker.io/eclipse/zenoh:latest", &[7447], &[]),
        geno("indrajaal-ollama", "docker.io/ollama/ollama:latest", &[11434], &[]),
        geno("indrajaal-mojo", "localhost/indrajaal-mojo:latest", &[11436], &[]),
        geno("zenoh-router-1", "docker.io/eclipse/zenoh:latest", &[7447], &[]),
        geno("zenoh-router-2", "docker.io/eclipse/zenoh:latest", &[7447], &[]),
        geno("zenoh-router-3", "docker.io/eclipse/zenoh:latest", &[7447], &[]),
        geno("indrajaal-ex-app-2", "localhost/indrajaal-ex-app-1:latest", &[4000], &[("MIX_ENV", "prod")]),
        geno("indrajaal-ex-app-3", "localhost/indrajaal-ex-app-1:latest", &[4000], &[("MIX_ENV", "prod")]),
        geno("indrajaal-chaya", "localhost/indrajaal-ex-app-1:latest", &[4002], &[("MIX_ENV", "prod")]),
        geno("indrajaal-ml-runner-1", "docker.io/ollama/ollama:latest", &[], &[]),
        geno("indrajaal-ml-runner-2", "docker.io/ollama/ollama:latest", &[], &[]),
    ]
}

fn geno(name: &str, image: &str, ports: &[u16], env: &[(&str, &str)]) -> Genotype {
    Genotype {
        container_name: name.into(),
        expected_image: image.into(),
        expected_ports: ports.to_vec(),
        expected_env: env.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect(),
    }
}

/// Compute a drift summary across all containers.
pub fn drift_summary(drifts: &[TwinDrift]) -> String {
    let aligned = drifts.iter().filter(|d| d.is_aligned).count();
    let total = drifts.len();
    let drifted: Vec<&str> = drifts.iter()
        .filter(|d| !d.is_aligned)
        .map(|d| d.container_name.as_str())
        .collect();

    if drifted.is_empty() {
        format!("All {}/{} containers aligned with genotype", aligned, total)
    } else {
        format!("{}/{} aligned, {} drifted: [{}]",
            aligned, total, drifted.len(), drifted.join(", "))
    }
}

/// Checkpoint the current twin state as JSON for persistence.
pub fn checkpoint_json(genotypes: &[Genotype], drifts: &[TwinDrift]) -> String {
    serde_json::json!({
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "genotype_count": genotypes.len(),
        "drift_count": drifts.len(),
        "aligned_count": drifts.iter().filter(|d| d.is_aligned).count(),
        "drifted_containers": drifts.iter()
            .filter(|d| !d.is_aligned)
            .map(|d| &d.container_name)
            .collect::<Vec<_>>(),
    }).to_string()
}

pub fn compare_twin(genotype: &Genotype, phenotype: &Phenotype) -> TwinDrift {
    let image_drift = genotype.expected_image != phenotype.actual_image;

    let mut port_drift = Vec::new();
    for p in &genotype.expected_ports {
        if !phenotype.actual_ports.contains(p) {
            port_drift.push(*p);
        }
    }

    let mut env_drift = Vec::new();
    for (k, v) in &genotype.expected_env {
        if phenotype.actual_env.get(k) != Some(v) {
            env_drift.push(k.clone());
        }
    }

    let is_aligned =
        !image_drift && port_drift.is_empty() && env_drift.is_empty() && phenotype.running;

    TwinDrift {
        container_name: genotype.container_name.clone(),
        image_drift,
        port_drift,
        env_drift,
        is_aligned,
    }
}
