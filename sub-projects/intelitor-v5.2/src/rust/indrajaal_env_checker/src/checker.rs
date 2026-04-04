use crate::config::{CheckerConfig, Severity};
use regex::Regex;
use std::path::PathBuf;
use std::sync::OnceLock;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CheckMode {
    Strict,
    Warning,
    Info,
}

impl Default for CheckMode {
    fn default() -> Self {
        CheckMode::Strict
    }
}

impl std::str::FromStr for CheckMode {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "strict" => Ok(CheckMode::Strict),
            "warning" => Ok(CheckMode::Warning),
            "info" => Ok(CheckMode::Info),
            _ => Err(format!("Unknown check mode: {}", s)),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ViolationType {
    MissingFnu,
    WrongFormat,
    Deprecated,
}

#[derive(Debug, Clone)]
pub struct CheckResult {
    pub file: PathBuf,
    pub line: usize,
    pub column: usize,
    pub violation_type: ViolationType,
    pub severity: Severity,
    pub message: String,
    pub current_value: String,
    pub expected_value: String,
    pub rule_id: String,
}

static FNU_PATTERN: OnceLock<Regex> = OnceLock::new();

fn get_fnu_pattern() -> &'static Regex {
    FNU_PATTERN.get_or_init(|| Regex::new(r"ELIXIR_ERL_OPTIONS\s*=").unwrap())
}

static PATTERNS: OnceLock<Vec<(Regex, &'static str, &'static str)>> = OnceLock::new();

fn get_patterns() -> &'static Vec<(Regex, &'static str, &'static str)> {
    PATTERNS.get_or_init(|| {
        vec![
            // Double-quoted
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 16""#,
                "Missing +fnu flag",
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 16:16 \+SDio 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16""#,
                "Missing +fnu flag",
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 16 \+A 32""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 16 +A 32""#,
                "Missing +fnu flag",
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 10:10""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 10:10""#,
                "Missing +fnu flag",
            ),
            // Single-quoted
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS='\+S 16'"#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS='+fnu +S 16'"#,
                "Missing +fnu flag",
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS='\+S 16:16 \+SDio 16'"#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS='+fnu +S 16:16 +SDio 16'"#,
                "Missing +fnu flag",
            ),
            // Elixir tuple
            (
                Regex::new(r#""ELIXIR_ERL_OPTIONS", "\+S 16""#).unwrap(),
                r#""ELIXIR_ERL_OPTIONS", "+fnu +S 16""#,
                "Missing +fnu flag",
            ),
            (
                Regex::new(r#""ELIXIR_ERL_OPTIONS", "\+S 16:16 \+SDio 16""#).unwrap(),
                r#""ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16""#,
                "Missing +fnu flag",
            ),
            // Map syntax
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS => "\+S 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS => "+fnu +S 16""#,
                "Missing +fnu flag",
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS => "\+S 16:16 \+SDio 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS => "+fnu +S 16:16 +SDio 16""#,
                "Missing +fnu flag",
            ),
            // System.put_env
            (
                Regex::new(r#"System\.put_env\("ELIXIR_ERL_OPTIONS", "\+S 16"\)"#).unwrap(),
                r#"System.put_env("ELIXIR_ERL_OPTIONS", "+fnu +S 16")"#,
                "Missing +fnu flag",
            ),
            // Export patterns
            (
                Regex::new(r#"export ELIXIR_ERL_OPTIONS="\+S 16""#).unwrap(),
                r#"export ELIXIR_ERL_OPTIONS="+fnu +S 16""#,
                "Missing +fnu flag",
            ),
            // ENV patterns (Dockerfile)
            (
                Regex::new(r#"ENV ELIXIR_ERL_OPTIONS="\+S 16""#).unwrap(),
                r#"ENV ELIXIR_ERL_OPTIONS="+fnu +S 16""#,
                "Missing +fnu flag",
            ),
            // Nix patterns
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS\s*=\s*"\+S 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS = "+fnu +S 16""#,
                "Missing +fnu flag",
            ),
        ]
    })
}

pub struct FileChecker {
    config: CheckerConfig,
}

impl FileChecker {
    pub fn new(config: &CheckerConfig) -> Self {
        Self {
            config: config.clone(),
        }
    }

    pub fn check_content(
        &self,
        content: &str,
        file: &PathBuf,
        mode: &CheckMode,
    ) -> Vec<CheckResult> {
        let mut results = Vec::new();

        if !get_fnu_pattern().is_match(content) {
            return results;
        }

        for (pattern, replacement, message) in get_patterns() {
            if pattern.is_match(content) {
                for line_num in 0.. {
                    if let Some(caps) = pattern.find_iter(content).nth(line_num) {
                        let current = caps.as_str();
                        let expected = *replacement;
                        let line = content[..caps.start()].matches('\n').count() + 1;
                        let col = caps.start()
                            - content[..caps.start()]
                                .rfind('\n')
                                .map(|i| i + 1)
                                .unwrap_or(0);

                        results.push(CheckResult {
                            file: file.clone(),
                            line,
                            column: col,
                            violation_type: ViolationType::MissingFnu,
                            severity: Severity::Critical,
                            message: message.to_string(),
                            current_value: current.to_string(),
                            expected_value: expected.to_string(),
                            rule_id: "SC-UTF8-001".to_string(),
                        });
                    } else {
                        break;
                    }
                }
            }
        }

        results
    }

    pub fn check_file(&self, file: &PathBuf, mode: &CheckMode) -> Vec<CheckResult> {
        if let Ok(content) = std::fs::read_to_string(file) {
            self.check_content(&content, file, mode)
        } else {
            vec![]
        }
    }
}

impl Default for FileChecker {
    fn default() -> Self {
        Self::new(&CheckerConfig::default())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_checker() -> FileChecker {
        FileChecker::new(&CheckerConfig::default())
    }

    #[test]
    fn test_detects_missing_fnu() {
        let checker = test_checker();
        let content = r#"ELIXIR_ERL_OPTIONS="+S 16""#;
        let results =
            checker.check_content(content, &PathBuf::from("test.exs"), &CheckMode::Strict);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].violation_type, ViolationType::MissingFnu);
    }

    #[test]
    fn test_allows_fnu() {
        let checker = test_checker();
        let content = r#"ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16""#;
        let results =
            checker.check_content(content, &PathBuf::from("test.exs"), &CheckMode::Strict);
        assert_eq!(results.len(), 0);
    }

    #[test]
    fn test_detects_single_quoted() {
        let checker = test_checker();
        let content = r#"ELIXIR_ERL_OPTIONS='+S 16'"#;
        let results = checker.check_content(content, &PathBuf::from("test.sh"), &CheckMode::Strict);
        assert_eq!(results.len(), 1);
    }
}
