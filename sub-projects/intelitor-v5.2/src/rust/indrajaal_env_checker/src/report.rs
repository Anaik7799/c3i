use crate::checker::{CheckResult, ViolationType};
use crate::config::Severity;
use colored::*;
use serde::Serialize;
use std::collections::HashSet;
use std::time::SystemTime;

#[derive(Debug, Serialize)]
pub struct Report {
    pub timestamp: String,
    pub total_files_scanned: usize,
    pub files_with_env: usize,
    pub violations: Vec<ReportViolation>,
    pub summary: ReportSummary,
    pub coverage_percentage: f64,
}

#[derive(Debug, Serialize)]
pub struct ReportViolation {
    pub file: String,
    pub line: usize,
    pub violation_type: String,
    pub severity: String,
    pub message: String,
    pub current_value: String,
    pub expected_value: String,
}

#[derive(Debug, Serialize)]
pub struct ReportSummary {
    pub total_violations: usize,
    pub critical_violations: usize,
    pub error_violations: usize,
    pub warning_violations: usize,
    pub info_violations: usize,
    pub unique_files_violated: usize,
}

impl Report {
    pub fn new(violations: Vec<CheckResult>, total_scanned: usize, files_with_env: usize) -> Self {
        let unique_files: HashSet<_> = violations.iter().map(|v| &v.file).collect();
        let coverage = if files_with_env > 0 {
            let compliant = files_with_env - unique_files.len();
            (compliant as f64 / files_with_env as f64) * 100.0
        } else {
            100.0
        };

        let report_violations: Vec<ReportViolation> = violations
            .iter()
            .map(|v| ReportViolation {
                file: v.file.to_string_lossy().to_string(),
                line: v.line,
                violation_type: format!("{:?}", v.violation_type),
                severity: format!("{:?}", v.severity),
                message: v.message.clone(),
                current_value: v.current_value.clone(),
                expected_value: v.expected_value.clone(),
            })
            .collect();

        let summary = ReportSummary {
            total_violations: violations.len(),
            critical_violations: violations
                .iter()
                .filter(|v| matches!(v.severity, Severity::Critical))
                .count(),
            error_violations: violations
                .iter()
                .filter(|v| matches!(v.severity, Severity::Error))
                .count(),
            warning_violations: violations
                .iter()
                .filter(|v| matches!(v.severity, Severity::Warning))
                .count(),
            info_violations: violations
                .iter()
                .filter(|v| matches!(v.severity, Severity::Info))
                .count(),
            unique_files_violated: unique_files.len(),
        };

        Self {
            timestamp: SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .unwrap()
                .as_secs()
                .to_string(),
            total_files_scanned: total_scanned,
            files_with_env,
            violations: report_violations,
            summary,
            coverage_percentage: coverage,
        }
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(self).unwrap_or_default()
    }

    pub fn to_text(&self) -> String {
        let mut output = String::new();

        output.push_str(&format!(
            "{} ELIXIR_ERL_OPTIONS +fnu Compliance Report\n",
            "📋".cyan()
        ));
        output.push_str(&"═".repeat(60));
        output.push('\n');

        output.push_str(&format!("\n{} Summary\n", "📊".cyan()));
        output.push_str(&"─".repeat(40));
        output.push_str(&format!(
            "\n  Files scanned:       {}\n",
            self.total_files_scanned.to_string().white()
        ));
        output.push_str(&format!(
            "  Files with env:      {}\n",
            self.files_with_env.to_string().white()
        ));
        output.push_str(&format!(
            "  Violations:          {}\n",
            self.summary.total_violations.to_string().red()
        ));
        output.push_str(&format!(
            "  Files violated:      {}\n",
            self.summary.unique_files_violated.to_string().yellow()
        ));
        output.push_str(&format!(
            "  Compliance:         {:.1}%\n",
            format!("{:.1}%", self.coverage_percentage).green()
        ));

        if self.summary.total_violations > 0 {
            output.push_str(&format!("\n{} Violations by Severity\n", "⚠️".yellow()));
            output.push_str(&"─".repeat(40));
            output.push_str(&format!(
                "\n  Critical: {}  Error: {}  Warning: {}  Info: {}\n",
                self.summary.critical_violations.to_string().red(),
                self.summary.error_violations.to_string().red(),
                self.summary.warning_violations.to_string().yellow(),
                self.summary.info_violations.to_string().blue()
            ));
        }

        if !self.violations.is_empty()
            && !self
                .violations
                .iter()
                .any(|v| matches!(v.violation_type.as_str(), "WrongFormat" | "Deprecated"))
        {
            output.push_str(&format!("\n{} Files Missing +fnu\n", "❌".red()));
            output.push_str(&"─".repeat(40));

            let mut files: HashSet<_> = HashSet::new();
            for v in &self.violations {
                if files.insert(&v.file) {
                    output.push_str(&format!(
                        "\n  {}:{}\n    Current:   {}\n    Expected:  {}\n",
                        v.file.yellow(),
                        v.line.to_string().white(),
                        v.current_value.red(),
                        v.expected_value.green()
                    ));
                }
            }
        }

        output
    }

    pub fn to_compact(&self) -> String {
        format!(
            "files={} env={} violations={} compliance={:.1}%",
            self.total_files_scanned,
            self.files_with_env,
            self.summary.total_violations,
            self.coverage_percentage
        )
    }

    pub fn to_github_actions(&self) -> String {
        let mut output = String::new();

        for v in &self.violations {
            let severity = match v.severity.as_str() {
                "Critical" => "error",
                "Error" => "error",
                "Warning" => "warning",
                _ => "notice",
            };

            output.push_str(&format!(
                "::{} file={},line={},col=1::{} [{}] {} -> {}\n",
                severity,
                v.file,
                v.line,
                v.violation_type,
                v.message.replace('\n', " "),
                v.current_value,
                v.expected_value
            ));
        }

        if self.summary.total_violations > 0 {
            output.push_str(&format!(
                "\n::notice title=Summary::Scanned {} files, {} violations in {} files, {:.1}% compliance\n",
                self.total_files_scanned,
                self.summary.total_violations,
                self.summary.unique_files_violated,
                self.coverage_percentage
            ));
        } else {
            output.push_str(&format!(
                "\n::notice title=Success::All {} files with ELIXIR_ERL_OPTIONS are compliant (100% +fnu coverage)\n",
                self.files_with_env
            ));
        }

        output
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_report_creation() {
        let violations = vec![CheckResult {
            file: PathBuf::from("test.exs"),
            line: 10,
            column: 5,
            violation_type: ViolationType::MissingFnu,
            severity: Severity::Critical,
            message: "Missing +fnu".to_string(),
            current_value: "+S 16".to_string(),
            expected_value: "+fnu +S 16".to_string(),
            rule_id: "SC-UTF8-001".to_string(),
        }];

        let report = Report::new(violations, 100, 50);
        assert_eq!(report.summary.total_violations, 1);
        assert_eq!(report.summary.critical_violations, 1);
    }

    #[test]
    fn test_report_with_no_violations() {
        let report = Report::new(vec![], 100, 50);
        assert_eq!(report.summary.total_violations, 0);
        assert_eq!(report.coverage_percentage, 100.0);
    }

    #[test]
    fn test_compact_output() {
        let report = Report::new(vec![], 100, 50);
        let compact = report.to_compact();
        assert!(compact.contains("files=100"));
        assert!(compact.contains("compliance=100.0%"));
    }
}
