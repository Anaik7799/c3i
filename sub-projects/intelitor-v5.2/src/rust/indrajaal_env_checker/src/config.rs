use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckerConfig {
    /// SIL-6 compliance level (1-6)
    pub sil_level: u8,

    /// Whether to fail on violations
    pub fail_on_violation: bool,

    /// Additional patterns to check
    pub additional_patterns: Vec<String>,

    /// Patterns to skip
    pub skip_patterns: Vec<String>,

    /// Recommended ELIXIR_ERL_OPTIONS value
    pub recommended_options: String,

    /// Environment variable patterns
    pub env_patterns: HashMap<String, String>,

    /// Severity mapping
    pub severity_rules: HashMap<String, Severity>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Severity {
    Info,
    Warning,
    Error,
    Critical,
}

impl Default for CheckerConfig {
    fn default() -> Self {
        Self {
            sil_level: 6,
            fail_on_violation: true,
            additional_patterns: vec![],
            skip_patterns: vec![
                "comprehensive_preflight_system.exs".to_string(),
                "tdg_container_compliance_tests.exs".to_string(),
            ],
            recommended_options: "+fnu +S 16:16 +SDio 16".to_string(),
            env_patterns: [
                (
                    "ELIXIR_ERL_OPTIONS".to_string(),
                    "+fnu +S 16:16 +SDio 16".to_string(),
                ),
                ("MIX_JOBS".to_string(), "16".to_string()),
                ("SKIP_ZENOH_NIF".to_string(), "0".to_string()),
            ]
            .into_iter()
            .collect(),
            severity_rules: [
                ("MISSING_FNU".to_string(), Severity::Critical),
                ("WRONG_FORMAT".to_string(), Severity::Error),
                ("DEPRECATED".to_string(), Severity::Warning),
            ]
            .into_iter()
            .collect(),
        }
    }
}

impl CheckerConfig {
    /// Load configuration from file or environment
    pub fn load() -> Result<Self, Box<dyn std::error::Error>> {
        // Check for config file
        let config_paths = vec![
            PathBuf::from(".indrajaal-env-checker.toml"),
            PathBuf::from(".indrajaal-env-checker.json"),
            dirs::config_dir()
                .map(|p| p.join("indrajaal-env-checker.toml"))
                .unwrap_or_default(),
        ];

        for path in config_paths {
            if path.exists() {
                let content = fs::read_to_string(&path)?;
                if path.extension().and_then(|s| s.to_str()) == Some("json") {
                    return Ok(serde_json::from_str(&content)?);
                } else {
                    return Ok(toml::from_str(&content)?);
                }
            }
        }

        // Check environment variables
        let mut config = CheckerConfig::default();

        if let Ok(sil) = env::var("INDRAJAAL_SIL_LEVEL") {
            if let Ok(level) = sil.parse() {
                config.sil_level = level;
            }
        }

        if let Ok(fail) = env::var("INDRAJAAL_FAIL_ON_VIOLATION") {
            config.fail_on_violation = fail.to_lowercase() != "false";
        }

        Ok(config)
    }

    /// Save configuration to file
    pub fn save(&self, path: &PathBuf) -> Result<(), Box<dyn std::error::Error>> {
        let content = toml::to_string_pretty(self)?;
        fs::write(path, content)?;
        Ok(())
    }

    /// Get recommended options for a given context
    pub fn recommended_for(&self, context: &str) -> String {
        match context {
            "compile" => "+fnu +S 16:16 +SDio 16".to_string(),
            "test" => "+fnu +S 16:16 +SDio 16".to_string(),
            "container" => "+fnu +S 10:10".to_string(),
            "development" => "+fnu +S 4:4".to_string(),
            _ => self.recommended_options.clone(),
        }
    }
}

// Platform-specific directory helper
mod dirs {
    use std::path::PathBuf;

    pub fn config_dir() -> Option<PathBuf> {
        #[cfg(target_os = "linux")]
        {
            std::env::var("XDG_CONFIG_HOME")
                .ok()
                .map(PathBuf::from)
                .or_else(|| {
                    std::env::var("HOME")
                        .ok()
                        .map(|h| PathBuf::from(h).join(".config"))
                })
        }
        #[cfg(target_os = "macos")]
        {
            std::env::var("HOME")
                .ok()
                .map(|h| PathBuf::from(h).join("Library").join("Application Support"))
        }
        #[cfg(target_os = "windows")]
        {
            std::env::var("APPDATA").ok().map(PathBuf::from)
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = CheckerConfig::default();
        assert_eq!(config.sil_level, 6);
        assert!(config.fail_on_violation);
        assert_eq!(config.recommended_options, "+fnu +S 16:16 +SDio 16");
    }

    #[test]
    fn test_recommended_for() {
        let config = CheckerConfig::default();
        assert_eq!(config.recommended_for("compile"), "+fnu +S 16:16 +SDio 16");
        assert_eq!(config.recommended_for("test"), "+fnu +S 16:16 +SDio 16");
        assert_eq!(config.recommended_for("container"), "+fnu +S 10:10");
    }
}
