use crate::checker::CheckResult;
use anyhow::{Context, Result};
use regex::Regex;
use std::fs;
use std::path::PathBuf;

pub struct ConfigFixer {
    patterns: Vec<(Regex, String)>,
}

impl ConfigFixer {
    pub fn new() -> Self {
        let patterns = vec![
            // Double-quoted patterns
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 16""#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 16:16 \+SDio 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16""#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 16 \+A 32""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 16 +A 32""#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 10:10""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 10:10""#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS="\+S 10:10 \+SDio 10""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS="+fnu +S 10:10 +SDio 10""#.to_string(),
            ),
            // Single-quoted patterns
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS='\+S 16'"#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS='+fnu +S 16'"#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS='\+S 16:16 \+SDio 16'"#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS='+fnu +S 16:16 +SDio 16'"#.to_string(),
            ),
            // Elixir tuple patterns
            (
                Regex::new(r#""ELIXIR_ERL_OPTIONS", "\+S 16""#).unwrap(),
                r#""ELIXIR_ERL_OPTIONS", "+fnu +S 16""#.to_string(),
            ),
            (
                Regex::new(r#""ELIXIR_ERL_OPTIONS", "\+S 16:16 \+SDio 16""#).unwrap(),
                r#""ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16""#.to_string(),
            ),
            (
                Regex::new(r#""ELIXIR_ERL_OPTIONS", '\+S 16'"#).unwrap(),
                r#""ELIXIR_ERL_OPTIONS", '+fnu +S 16'"#.to_string(),
            ),
            (
                Regex::new(r#"'ELIXIR_ERL_OPTIONS', "\+S 16""#).unwrap(),
                r#"'ELIXIR_ERL_OPTIONS', "+fnu +S 16""#.to_string(),
            ),
            // Map syntax
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS => "\+S 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS => "+fnu +S 16""#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS => "\+S 16:16 \+SDio 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS => "+fnu +S 16:16 +SDio 16""#.to_string(),
            ),
            // System.put_env patterns
            (
                Regex::new(r#"System\.put_env\("ELIXIR_ERL_OPTIONS", "\+S 16"\)"#).unwrap(),
                r#"System.put_env("ELIXIR_ERL_OPTIONS", "+fnu +S 16")"#.to_string(),
            ),
            (
                Regex::new(r#"System\.put_env\("ELIXIR_ERL_OPTIONS", "\+S 16:16 \+SDio 16"\)"#)
                    .unwrap(),
                r#"System.put_env("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")"#.to_string(),
            ),
            // Export patterns
            (
                Regex::new(r#"export ELIXIR_ERL_OPTIONS="\+S 16""#).unwrap(),
                r#"export ELIXIR_ERL_OPTIONS="+fnu +S 16""#.to_string(),
            ),
            (
                Regex::new(r#"export ELIXIR_ERL_OPTIONS="\+S 16:16 \+SDio 16""#).unwrap(),
                r#"export ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16""#.to_string(),
            ),
            // ENV patterns (Dockerfile, Nix)
            (
                Regex::new(r#"ENV ELIXIR_ERL_OPTIONS="\+S 16""#).unwrap(),
                r#"ENV ELIXIR_ERL_OPTIONS="+fnu +S 16""#.to_string(),
            ),
            (
                Regex::new(r#"ENV ELIXIR_ERL_OPTIONS="\+S 16:16 \+SDio 16""#).unwrap(),
                r#"ENV ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16""#.to_string(),
            ),
            // Nix patterns
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS\s*=\s*"\+S 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS = "+fnu +S 16""#.to_string(),
            ),
            (
                Regex::new(r#"ELIXIR_ERL_OPTIONS\s*=\s*"\+S 16:16 \+SDio 16""#).unwrap(),
                r#"ELIXIR_ERL_OPTIONS = "+fnu +S 16:16 +SDio 16""#.to_string(),
            ),
        ];

        Self { patterns }
    }

    pub fn fix_file(&self, violation: &CheckResult) -> Result<()> {
        let content = fs::read_to_string(&violation.file)
            .with_context(|| format!("Failed to read file: {:?}", violation.file))?;

        let mut new_content = content.clone();
        let mut made_fix = false;

        for (pattern, replacement) in &self.patterns {
            if pattern.is_match(&new_content) {
                new_content = pattern
                    .replace_all(&new_content, replacement.as_str())
                    .to_string();
                made_fix = true;
            }
        }

        if made_fix {
            fs::write(&violation.file, &new_content)
                .with_context(|| format!("Failed to write file: {:?}", violation.file))?;
        }

        Ok(())
    }

    pub fn fix_content(&self, content: &str) -> String {
        let mut new_content = content.to_string();

        for (pattern, replacement) in &self.patterns {
            if pattern.is_match(&new_content) {
                new_content = pattern
                    .replace_all(&new_content, replacement.as_str())
                    .to_string();
            }
        }

        new_content
    }

    pub fn can_fix(&self, violation: &CheckResult) -> bool {
        let content = fs::read_to_string(&violation.file).ok().unwrap_or_default();

        self.patterns
            .iter()
            .any(|(pattern, _)| pattern.is_match(&content))
    }
}

impl Default for ConfigFixer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fix_double_quoted() {
        let fixer = ConfigFixer::new();
        let content = r#"ELIXIR_ERL_OPTIONS="+S 16""#;
        let fixed = fixer.fix_content(content);
        assert!(fixed.contains("+fnu"));
        assert!(fixed.contains("+S 16"));
    }

    #[test]
    fn test_fix_single_quoted() {
        let fixer = ConfigFixer::new();
        let content = r#"ELIXIR_ERL_OPTIONS='+S 16:16 +SDio 16'"#;
        let fixed = fixer.fix_content(content);
        assert!(fixed.contains("+fnu"));
        assert!(fixed.contains("+S 16:16 +SDio 16"));
    }

    #[test]
    fn test_no_double_fix() {
        let fixer = ConfigFixer::new();
        let content = r#"ELIXIR_ERL_OPTIONS="+fnu +S 16""#;
        let fixed = fixer.fix_content(content);
        assert_eq!(fixed, content);
    }
}
