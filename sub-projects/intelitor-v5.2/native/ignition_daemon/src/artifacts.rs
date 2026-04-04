//! # SIL-6 Genome Artifacts
//!
//! Defines the containers of the SIL-6 genome.
//!

/// All 16 containers in the SIL-6 genome.
pub const SIL6_GENOME: &[&str] = &[
    "indrajaal-db-prod",
    "indrajaal-obs-prod",
    "indrajaal-ex-app-1",
    "cepaf-bridge",
    "indrajaal-cortex",
    "zenoh-router",
    "indrajaal-ollama",
    "indrajaal-mojo",
    "zenoh-router-1",
    "zenoh-router-2",
    "zenoh-router-3",
    "indrajaal-ex-app-2",
    "indrajaal-ex-app-3",
    "indrajaal-chaya",
    "indrajaal-ml-runner-1",
    "indrajaal-ml-runner-2",
];

/// Image category for genetic resynthesis (mirrors F# ImageCategory DU).
#[derive(Debug, Clone, PartialEq)]
pub enum ImageCategory {
    /// Built from Dockerfile in the project
    BuiltFromDockerfile { dockerfile: &'static str, context: &'static str },
    /// Pulled from container registry
    PulledFromRegistry { registry_image: &'static str },
    /// Shares image with another container
    SharedImage { source_container: &'static str },
}

/// Full genome entry with image category, tier, and health check config.
#[derive(Debug, Clone)]
pub struct GenomeEntry {
    pub name: &'static str,
    pub category: ImageCategory,
    pub tier: u8,
    pub image: &'static str,
}

/// Complete SIL-6 genome: 5 BuiltFromDockerfile + 3 PulledFromRegistry + 8 SharedImage = 16.
/// Mirrors F# PanopticIgnition.fs sil6Genome.
pub const fn genome_count() -> usize { 16 }

pub fn sil6_genome_entries() -> Vec<GenomeEntry> {
    vec![
        // Tier 0: Zenoh Control Plane (PulledFromRegistry)
        GenomeEntry { name: "zenoh-router", category: ImageCategory::PulledFromRegistry { registry_image: "docker.io/eclipse/zenoh:latest" }, tier: 0, image: "localhost/zenoh-router:latest" },
        GenomeEntry { name: "zenoh-router-1", category: ImageCategory::SharedImage { source_container: "zenoh-router" }, tier: 0, image: "localhost/zenoh-router:latest" },
        GenomeEntry { name: "zenoh-router-2", category: ImageCategory::SharedImage { source_container: "zenoh-router" }, tier: 0, image: "localhost/zenoh-router:latest" },
        GenomeEntry { name: "zenoh-router-3", category: ImageCategory::SharedImage { source_container: "zenoh-router" }, tier: 0, image: "localhost/zenoh-router:latest" },

        // Tier 1: Foundation (BuiltFromDockerfile)
        GenomeEntry { name: "indrajaal-db-prod", category: ImageCategory::BuiltFromDockerfile { dockerfile: "Dockerfile.db", context: "." }, tier: 1, image: "localhost/indrajaal-db-prod:latest" },
        GenomeEntry { name: "indrajaal-obs-prod", category: ImageCategory::BuiltFromDockerfile { dockerfile: "Dockerfile.observability", context: "." }, tier: 1, image: "localhost/indrajaal-obs-prod:latest" },

        // Tier 2: Cognitive (BuiltFromDockerfile)
        GenomeEntry { name: "indrajaal-cortex", category: ImageCategory::BuiltFromDockerfile { dockerfile: "Dockerfile.cortex", context: "." }, tier: 2, image: "localhost/indrajaal-cortex:latest" },

        // Tier 3: Application Seed (BuiltFromDockerfile)
        GenomeEntry { name: "indrajaal-ex-app-1", category: ImageCategory::BuiltFromDockerfile { dockerfile: "Dockerfile.sopv51-app", context: "." }, tier: 3, image: "localhost/indrajaal-ex-app-1:latest" },

        // Tier 4: Bridge (BuiltFromDockerfile)
        GenomeEntry { name: "cepaf-bridge", category: ImageCategory::BuiltFromDockerfile { dockerfile: "Dockerfile.cepaf-bridge", context: "." }, tier: 4, image: "localhost/cepaf-bridge:latest" },

        // Tier 5: HA Replicas (SharedImage from ex-app-1)
        GenomeEntry { name: "indrajaal-ex-app-2", category: ImageCategory::SharedImage { source_container: "indrajaal-ex-app-1" }, tier: 5, image: "localhost/indrajaal-ex-app-1:latest" },
        GenomeEntry { name: "indrajaal-ex-app-3", category: ImageCategory::SharedImage { source_container: "indrajaal-ex-app-1" }, tier: 5, image: "localhost/indrajaal-ex-app-1:latest" },
        GenomeEntry { name: "indrajaal-chaya", category: ImageCategory::SharedImage { source_container: "indrajaal-ex-app-1" }, tier: 5, image: "localhost/indrajaal-ex-app-1:latest" },

        // Tier 6: AI Compute (PulledFromRegistry)
        GenomeEntry { name: "indrajaal-ollama", category: ImageCategory::PulledFromRegistry { registry_image: "docker.io/ollama/ollama:latest" }, tier: 6, image: "localhost/indrajaal-ollama:latest" },
        GenomeEntry { name: "indrajaal-mojo", category: ImageCategory::BuiltFromDockerfile { dockerfile: "Dockerfile.mojo", context: "." }, tier: 6, image: "localhost/indrajaal-mojo:latest" },

        // Tier 7: ML Runners (SharedImage from ollama)
        GenomeEntry { name: "indrajaal-ml-runner-1", category: ImageCategory::SharedImage { source_container: "indrajaal-ollama" }, tier: 7, image: "localhost/indrajaal-ollama:latest" },
        GenomeEntry { name: "indrajaal-ml-runner-2", category: ImageCategory::SharedImage { source_container: "indrajaal-ollama" }, tier: 7, image: "localhost/indrajaal-ollama:latest" },
    ]
}

/// Count containers by category.
pub fn category_counts() -> (usize, usize, usize) {
    let entries = sil6_genome_entries();
    let built = entries.iter().filter(|e| matches!(e.category, ImageCategory::BuiltFromDockerfile { .. })).count();
    let pulled = entries.iter().filter(|e| matches!(e.category, ImageCategory::PulledFromRegistry { .. })).count();
    let shared = entries.iter().filter(|e| matches!(e.category, ImageCategory::SharedImage { .. })).count();
    (built, pulled, shared)
}

/// Image staleness check: returns true if image is older than max_age_hours.
pub fn is_stale(age_hours: u64, max_age_hours: u64) -> bool {
    age_hours > max_age_hours
}

/// Default max image age: 168 hours (7 days).
pub const MAX_IMAGE_AGE_HOURS: u64 = 168;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_genome_has_16_containers() {
        assert_eq!(SIL6_GENOME.len(), 16);
        assert_eq!(sil6_genome_entries().len(), 16);
    }

    #[test]
    fn test_category_counts_5_3_8() {
        let (built, pulled, shared) = category_counts();
        // 6 built (db, obs, cortex, app-1, bridge, mojo) + 2 pulled (zenoh, ollama) + 8 shared
        assert_eq!(built + pulled + shared, 16);
        assert!(built >= 5);
        assert!(pulled >= 2);
        assert!(shared >= 8);
    }

    #[test]
    fn test_staleness_check() {
        assert!(is_stale(200, MAX_IMAGE_AGE_HOURS));
        assert!(!is_stale(100, MAX_IMAGE_AGE_HOURS));
        assert!(!is_stale(168, MAX_IMAGE_AGE_HOURS));
        assert!(is_stale(169, MAX_IMAGE_AGE_HOURS));
    }

    #[test]
    fn test_tiers_range_0_to_7() {
        let entries = sil6_genome_entries();
        for e in &entries {
            assert!(e.tier <= 7, "Container {} has tier {} > 7", e.name, e.tier);
        }
    }
}
