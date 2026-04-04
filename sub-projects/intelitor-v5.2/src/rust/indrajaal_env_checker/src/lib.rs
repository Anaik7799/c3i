pub mod checker;
pub mod config;
pub mod fixer;
pub mod report;

pub use checker::{CheckMode, CheckResult, FileChecker, ViolationType};
pub use config::{CheckerConfig, Severity};
pub use fixer::ConfigFixer;
pub use report::Report;
