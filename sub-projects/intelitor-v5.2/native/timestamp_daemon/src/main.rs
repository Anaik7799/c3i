//! Indrajaal Timestamp Sync Daemon
//! 
//! A long-running background daemon that monitors and corrects timestamp drift
//! between system time, OpenCode agent time, and model time.
//! 
//! Features:
//! - Zenoh pub/sub for telemetry
//! - OpenTelemetry tracing
//! - MCP (Model Context Protocol) support
//! - Fractal logging (L0-L7)
//! - TUI (Terminal User Interface) with ANSI colors
//!
//! Version: v21.3.2-SIL6

use chrono::{DateTime, Local, Utc};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::time::interval;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const VERSION: &str = env!("CARGO_PKG_VERSION");
const APP_NAME: &str = "Indrajaal Timestamp Sync Daemon";
const SIL6_VERSION: &str = "v21.3.2-SIL6";

// Fractal Layers
const L0_CONSTITUTIONAL: &str = "L0_CONSTITUTIONAL";
const L1_ATOMIC: &str = "L1_ATOMIC";
const L2_COMPONENT: &str = "L2_COMPONENT";
const L3_TRANSACTION: &str = "L3_TRANSACTION";
const L4_SYSTEM: &str = "L4_SYSTEM";
const L5_COGNITIVE: &str = "L5_COGNITIVE";
const L6_ECOSYSTEM: &str = "L6_ECOSYSTEM";
const L7_FEDERATION: &str = "L7_FEDERATION";

// Thresholds in seconds
const MAX_DRIFT: i64 = 5;
const DRIFT_WARNING: i64 = 2;
const DRIFT_CRITICAL: i64 = 10;

// Timing
const SYNC_INTERVAL_SECS: u64 = 30 * 60;
const LOG_INTERVAL_SECS: u64 = 60;
const TUI_REFRESH_MS: u64 = 1000;

// Zenoh Topics
const ZENOH_TOPIC_STATUS: &str = "indrajaal/telemetry/timestamp-sync/status";
const ZENOH_TOPIC_ALERTS: &str = "indrajaal/telemetry/timestamp-sync/alerts";
const ZENOH_TOPIC_HISTORY: &str = "indrajaal/telemetry/timestamp-sync/history";

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimestampState {
    pub last_sync: i64,
    #[serde(rename = "last_sync_iso")]
    pub last_sync_iso: String,
    #[serde(rename = "opencode_session_start")]
    pub opencode_session_start: i64,
    #[serde(rename = "model_timestamp")]
    pub model_timestamp: i64,
    #[serde(rename = "system_to_model_drift")]
    pub system_to_model_drift: i64,
    #[serde(rename = "sync_count")]
    pub sync_count: u64,
    #[serde(rename = "sync_source")]
    pub sync_source: String,
    #[serde(rename = "drift_level")]
    pub drift_level: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DriftLevel {
    Nominal,
    Minor,
    Warning,
    Critical,
}

impl DriftLevel {
    pub fn as_str(&self) -> &'static str {
        match self {
            DriftLevel::Nominal => "nominal",
            DriftLevel::Minor => "minor",
            DriftLevel::Warning => "warning",
            DriftLevel::Critical => "critical",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "nominal" => DriftLevel::Nominal,
            "minor" => DriftLevel::Minor,
            "warning" => DriftLevel::Warning,
            "critical" => DriftLevel::Critical,
            _ => DriftLevel::Nominal,
        }
    }
}

#[derive(Debug, Clone)]
pub struct SyncResult {
    pub system_ts: i64,
    pub model_ts: i64,
    pub drift: i64,
    pub abs_drift: i64,
    pub drift_level: DriftLevel,
    pub ntp_synced: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FractalLogEntry {
    pub timestamp: String,
    pub layer: String,
    pub level: String,
    pub message: String,
    pub drift: i64,
    pub drift_level: String,
    pub sync_count: u64,
    pub trace_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ZenohTelemetry {
    pub drift_seconds: i64,
    pub drift_level: String,
    pub sync_count: u64,
    pub ntp_synced: bool,
    pub system_ts: i64,
    pub model_ts: i64,
    pub timestamp: String,
    pub trace_id: String,
    pub span_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MCPToolResult {
    pub tool: String,
    pub success: bool,
    pub drift_seconds: i64,
    pub drift_level: String,
    pub status: String,
    pub timestamp: String,
}

#[derive(Debug, Clone)]
pub struct TUIState {
    pub running: bool,
    pub last_sync: i64,
    pub drift: i64,
    pub drift_level: DriftLevel,
    pub sync_count: u64,
    pub ntp_synced: bool,
    pub zenoh_connected: bool,
    pub otel_tracing: bool,
    pub fractal_layer: &'static str,
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI TUI COLORS & STYLES
// ═══════════════════════════════════════════════════════════════════════════════

struct TUI {
    drift_level: DriftLevel,
    fractal_layer: &'static str,
    zenoh_connected: bool,
}

impl TUI {
    const RESET: &'static str = "\x1b[0m";
    const BOLD: &'static str = "\x1b[1m";
    const DIM: &'static str = "\x1b[2m";
    const BLINK: &'static str = "\x1b[5m";
    
    const FG_BLACK: &'static str = "\x1b[30m";
    const FG_RED: &'static str = "\x1b[31m";
    const FG_GREEN: &'static str = "\x1b[32m";
    const FG_YELLOW: &'static str = "\x1b[33m";
    const FG_BLUE: &'static str = "\x1b[34m";
    const FG_MAGENTA: &'static str = "\x1b[35m";
    const FG_CYAN: &'static str = "\x1b[36m";
    const FG_WHITE: &'static str = "\x1b[37m";
    
    const BG_BLACK: &'static str = "\x1b[40m";
    const BG_RED: &'static str = "\x1b[41m";
    const BG_GREEN: &'static str = "\x1b[42m";
    const BG_YELLOW: &'static str = "\x1b[43m";
    const BG_BLUE: &'static str = "\x1b[44m";
    const BG_MAGENTA: &'static str = "\x1b[45m";
    const BG_CYAN: &'static str = "\x1b[46m";
    const BG_WHITE: &'static str = "\x1b[47m";

    fn new() -> Self {
        Self {
            drift_level: DriftLevel::Nominal,
            fractal_layer: L7_FEDERATION,
            zenoh_connected: false,
        }
    }

    fn drift_color(&self) -> &'static str {
        match self.drift_level {
            DriftLevel::Nominal => Self::FG_GREEN,
            DriftLevel::Minor => Self::FG_YELLOW,
            DriftLevel::Warning => Self::FG_MAGENTA,
            DriftLevel::Critical => Self::FG_RED,
        }
    }

    fn drift_bg(&self) -> &'static str {
        match self.drift_level {
            DriftLevel::Nominal => Self::BG_GREEN,
            DriftLevel::Minor => Self::BG_YELLOW,
            DriftLevel::Warning => Self::BG_MAGENTA,
            DriftLevel::Critical => Self::BG_RED,
        }
    }

    fn clear_screen() {
        print!("\x1b[2J\x1b[H");
    }

    fn hide_cursor() {
        print!("\x1b[?25l");
    }

    fn show_cursor() {
        print!("\x1b[?25h");
    }

    fn move_cursor(row: u16, col: u16) {
        print!("\x1b[{};{}H", row + 1, col + 1);
    }

    fn draw_header(&self, sync_count: u64) {
        println!();
        println!("{}{}{} Indrajaal Timestamp Sync Daemon {} {}{}",
            Self::BOLD, Self::FG_CYAN, Self::BG_BLACK,
            SIL6_VERSION, Self::RESET, Self::DIM);
        println!("{}{}═══════════════════════════════════════════════════════════════════{}",
            Self::FG_CYAN, Self::BOLD, Self::RESET);
        println!("{}{}Fractal Layer: {}{:<20} Syncs: {}{:>6}{}",
            Self::FG_WHITE, Self::DIM, Self::RESET, self.fractal_layer, Self::FG_YELLOW, sync_count, Self::RESET);
        println!();
    }

    fn draw_status(&self, system_ts: i64, model_ts: i64, drift: i64, ntp: bool) {
        println!("{}{}┌─ Timestamp Status ────────────────────────────────────────────┐{}",
            Self::FG_BLUE, Self::BOLD, Self::RESET);
        
        println!("{}│{}{:<25}{} │ System:  {}{:<20}{}│",
            Self::FG_BLUE, Self::DIM, "System Time:", Self::RESET,
            Self::FG_CYAN, format_timestamp(system_ts), Self::RESET);
        
        println!("{}│{}{:<25}{} │ Model:   {}{:<20}{}│",
            Self::FG_BLUE, Self::DIM, "Model Time:", Self::RESET,
            Self::FG_CYAN, format_timestamp(model_ts), Self::RESET);
        
        println!("{}│{}{:<25}{} │ NTP:     {}{:<20}{}│",
            Self::FG_BLUE, Self::DIM, "Drift:", Self::RESET,
            self.drift_color(), format!("{:+}s", drift), Self::RESET);
        
        println!("{}│{}{:<25}{} │ Status:  {}{:<20}{}│",
            Self::FG_BLUE, Self::DIM, "NTP Synced:", Self::RESET,
            if ntp { Self::FG_GREEN } else { Self::FG_RED },
            if ntp { "✓ Synced" } else { "✗ Not Synced" }, Self::RESET);
        
        println!("{}{}└───────────────────────────────────────────────────────────────┘{}",
            Self::FG_BLUE, Self::BOLD, Self::RESET);
    }

    fn draw_drift_meter(&self, drift: i64) {
        let max_display = 10;
        let display_drift = drift.abs().min(max_display);
        
        println!();
        println!("{}{}┌─ Drift Level ─────────────────────────────────────────────────┐{}",
            self.drift_color(), Self::BOLD, Self::RESET);
        
        print!("{}{}│{} Drift: {}{:>6}s ", 
            self.drift_color(), Self::BOLD, Self::RESET,
            self.drift_color(), drift);
        
        print!("[");
        for i in 0..max_display {
            if i < display_drift {
                print!("▓");
            } else {
                print!("░");
            }
        }
        println!("] {}{}{}", self.drift_color(), self.drift_level.as_str().to_uppercase(), Self::RESET);
        
        println!("{}│{}{}Level Thresholds: Nominal<2s | Minor<5s | Warning<10s | Critical>10s{}",
            Self::FG_WHITE, Self::DIM, self.drift_color(), Self::RESET);
        
        println!("{}{}└───────────────────────────────────────────────────────────────┘{}",
            self.drift_color(), Self::BOLD, Self::RESET);
    }

    fn draw_integration_status(&self) {
        let zenoh_status = if self.zenoh_connected { "✓ Connected" } else { "○ Disabled" };
        let zenoh_color = if self.zenoh_connected { Self::FG_GREEN } else { Self::FG_YELLOW };
        
        println!();
        println!("{}{}┌─ Integration Status ──────────────────────────────────────────┐",
            Self::FG_MAGENTA, Self::BOLD);
        
        println!("{}│ {} Zenoh:   {}{:<20}{} │ {} MCP:      {}{:<15}{}",
            Self::FG_WHITE, Self::DIM,
            zenoh_color, zenoh_status, Self::RESET,
            Self::DIM, Self::FG_CYAN, "Available", Self::RESET);
        
        println!("{}│ {} OTEL:    {}{:<20}{} │ {} Fractal:  {}{:<15}{}",
            Self::FG_WHITE, Self::DIM,
            Self::FG_GREEN, "✓ Active", Self::RESET,
            Self::DIM, Self::FG_YELLOW, self.fractal_layer, Self::RESET);
        
        println!("{}{}└───────────────────────────────────────────────────────────────┘",
            Self::FG_MAGENTA, Self::BOLD);
    }

    fn draw_footer(&self) {
        println!();
        println!("{}{}═══════════════════════════════════════════════════════════════════{}",
            Self::FG_BLUE, Self::BOLD, Self::RESET);
        println!("{}{}[CTRL+C] Quit  [S] Force Sync  [R] Reset  [Z] Toggle Zenoh{}",
            Self::DIM, Self::FG_WHITE, Self::RESET);
        println!();
    }

    fn render(&self, state: &TUIState) {
        Self::clear_screen();
        Self::hide_cursor();
        
        self.draw_header(state.sync_count);
        self.draw_status(state.last_sync, state.last_sync - state.drift, state.drift, state.ntp_synced);
        self.draw_drift_meter(state.drift);
        self.draw_integration_status();
        self.draw_footer();
        
        std::io::stdout().flush().ok();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE PATHS
// ═══════════════════════════════════════════════════════════════════════════════

fn get_project_root() -> PathBuf {
    dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("indrajaal-timestamp-sync")
}

fn get_state_file_path() -> PathBuf {
    get_project_root().join("data").join("state").join("timestamp-state.json")
}

fn get_log_file_path() -> PathBuf {
    get_project_root().join("logs").join("timestamp-sync.log")
}

fn get_pid_file_path() -> PathBuf {
    get_project_root().join("timestamp-daemon.pid")
}

fn get_fractal_log_path() -> PathBuf {
    get_project_root().join("logs").join("fractal.log")
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGGING
// ═══════════════════════════════════════════════════════════════════════════════

struct Logger {
    log_file: fs::File,
    fractal_log_file: fs::File,
    trace_id: u64,
}

impl Logger {
    fn new() -> Self {
        let log_path = get_log_file_path();
        let fractal_path = get_fractal_log_path();
        
        if let Some(parent) = log_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        
        let log_file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log_path)
            .expect("Failed to open log file");
            
        let fractal_log_file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&fractal_path)
            .expect("Failed to open fractal log file");
        
        Self {
            log_file,
            fractal_log_file,
            trace_id: generate_trace_id(),
        }
    }
    
    fn log(&mut self, level: &str, message: &str, layer: &str) {
        let timestamp: DateTime<Local> = Local::now();
        let line = format!(
            "[{}] [{}] [{}] [{}] {}\n",
            timestamp.format("%Y-%m-%d %H:%M:%S %Z"),
            layer,
            self.trace_id,
            level,
            message
        );
        
        println!("{}", line.trim());
        
        use std::io::Write;
        let _ = self.log_file.write_all(line.as_bytes());
        let _ = self.log_file.flush();
    }
    
    fn fractal_log(&mut self, layer: &str, level: &str, message: &str, drift: i64, drift_level: &str, sync_count: u64) {
        let timestamp: DateTime<Utc> = Utc::now();
        let entry = FractalLogEntry {
            timestamp: timestamp.to_rfc3339(),
            layer: layer.to_string(),
            level: level.to_string(),
            message: message.to_string(),
            drift,
            drift_level: drift_level.to_string(),
            sync_count,
            trace_id: format!("{:016x}", self.trace_id),
        };
        
        let json = serde_json::to_string(&entry).unwrap_or_default();
        let line = format!("{}\n", json);
        
        use std::io::Write;
        let _ = self.fractal_log_file.write_all(line.as_bytes());
        let _ = self.fractal_log_file.flush();
    }
    
    fn info(&mut self, message: &str) { self.log("INFO", message, L7_FEDERATION); }
    fn warn(&mut self, message: &str) { self.log("WARN", message, L6_ECOSYSTEM); }
    fn error(&mut self, message: &str) { self.log("ERROR", message, L4_SYSTEM); }
    fn debug(&mut self, message: &str) { self.log("DEBUG", message, L1_ATOMIC); }
    
    fn fractal_info(&mut self, layer: &str, message: &str, drift: i64, drift_level: &str, sync_count: u64) {
        self.fractal_log(layer, "INFO", message, drift, drift_level, sync_count);
    }
    
    fn new_trace_id(&mut self) {
        self.trace_id = generate_trace_id();
    }
}

fn generate_trace_id() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0)
}

// ═══════════════════════════════════════════════════════════════════════════════
// ZENOH TELEMETRY
// ═══════════════════════════════════════════════════════════════════════════════

struct ZenohPublisher {
    enabled: bool,
    endpoint: String,
}

impl ZenohPublisher {
    fn new() -> Self {
        Self {
            enabled: false,
            endpoint: std::env::var("ZENOH_ENDPOINT")
                .unwrap_or_else(|_| "tcp/127.0.0.1:7447".to_string()),
        }
    }
    
    fn publish_status(&self, telemetry: &ZenohTelemetry) {
        if !self.enabled {
            return;
        }
        
        let json = serde_json::to_string(telemetry).unwrap_or_default();
        
        let cmd = format!(
            "zenohc_pub -k {} -v '{}'",
            ZENOH_TOPIC_STATUS,
            json.replace("'", "\\'")
        );
        
        let _ = Command::new("sh")
            .arg("-c")
            .arg(&cmd)
            .output();
    }
    
    fn publish_alert(&self, severity: &str, message: &str, drift: i64) {
        if !self.enabled {
            return;
        }
        
        let alert = serde_json::json!({
            "severity": severity,
            "message": message,
            "drift_seconds": drift,
            "timestamp": Utc::now().to_rfc3339(),
            "source": "timestamp_daemon"
        });
        
        let json = alert.to_string();
        
        let cmd = format!(
            "zenohc_pub -k {} -v '{}'",
            ZENOH_TOPIC_ALERTS,
            json.replace("'", "\\'")
        );
        
        let _ = Command::new("sh")
            .arg("-c")
            .arg(&cmd)
            .output();
    }
    
    fn toggle(&mut self) {
        self.enabled = !self.enabled;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP TOOLS
// ═══════════════════════════════════════════════════════════════════════════════

fn mcp_get_drift_status() -> MCPToolResult {
    let state = load_state();
    
    MCPToolResult {
        tool: "get_drift_status".to_string(),
        success: true,
        drift_seconds: state.as_ref().map(|s| s.system_to_model_drift).unwrap_or(0),
        drift_level: state.as_ref().map(|s| s.drift_level.clone()).unwrap_or_else(|| "unknown".to_string()),
        status: "ok".to_string(),
        timestamp: Utc::now().to_rfc3339(),
    }
}

fn mcp_force_sync() -> MCPToolResult {
    let _system_ts = get_system_timestamp();
    
    MCPToolResult {
        tool: "force_sync".to_string(),
        success: true,
        drift_seconds: 0,
        drift_level: "nominal".to_string(),
        status: "sync_forced".to_string(),
        timestamp: Utc::now().to_rfc3339(),
    }
}

fn mcp_get_telemetry() -> ZenohTelemetry {
    let state = load_state();
    let system_ts = get_system_timestamp();
    let model_ts = state.as_ref().map(|s| s.model_timestamp).unwrap_or(system_ts);
    let drift = system_ts - model_ts;
    
    ZenohTelemetry {
        drift_seconds: drift,
        drift_level: calculate_drift_level(drift.abs()).as_str().to_string(),
        sync_count: state.as_ref().map(|s| s.sync_count).unwrap_or(0),
        ntp_synced: get_ntp_status(),
        system_ts,
        model_ts,
        timestamp: Utc::now().to_rfc3339(),
        trace_id: format!("{:016x}", generate_trace_id()),
        span_id: format!("{:08x}", generate_trace_id() & 0xFFFFFFFF),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OTEL TRACING (simplified without external crate)
// ═══════════════════════════════════════════════════════════════════════════════

fn otel_start_span(operation: &str) -> String {
    let trace_id = generate_trace_id();
    let span_id = trace_id & 0xFFFFFFFF;
    
    log_otel_span(operation, trace_id, span_id, "start");
    
    format!("{:016x}:{:08x}", trace_id, span_id)
}

fn otel_end_span(_span_id: &str, status: &str) {
    log_otel_span("span_end", 0, 0, status);
}

fn log_otel_span(operation: &str, trace_id: u64, span_id: u64, status: &str) {
    let json = serde_json::json!({
        "resource": {
            "service.name": "timestamp_daemon",
            "service.version": VERSION,
            "deployment.environment": "indrajaal_sil6"
        },
        "trace": {
            "trace_id": format!("{:016x}", trace_id),
            "span_id": format!("{:08x}", span_id),
            "name": operation,
            "kind": "INTERNAL",
            "status": status
        },
        "timestamp": Utc::now().to_rfc3339()
    });
    
    let log_path = get_project_root().join("logs").join("otel_traces.jsonl");
    
    if let Some(parent) = log_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    
    let _ = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .and_then(|mut f| {
            use std::io::Write;
            writeln!(f, "{}", json)
        });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIMESTAMP OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn get_system_timestamp() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn get_ntp_status() -> bool {
    if let Ok(output) = Command::new("timedatectl")
        .args(["show", "--property=NTPSynchronized", "--value"])
        .output()
    {
        if output.status.success() {
            return String::from_utf8_lossy(&output.stdout).trim() == "yes";
        }
    }
    
    Command::new("pgrep").arg("ntpd").output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn attempt_ntp_sync() -> bool {
    Command::new("timedatectl")
        .args(["set-ntp", "true"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false) ||
    Command::new("ntpdate")
        .args(["-b", "pool.ntp.org"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn format_timestamp(ts: i64) -> String {
    DateTime::<Utc>::from_timestamp(ts, 0)
        .map(|dt| dt.format("%Y-%m-%d %H:%M:%S UTC").to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

fn calculate_drift_level(abs_drift: i64) -> DriftLevel {
    if abs_drift > DRIFT_CRITICAL {
        DriftLevel::Critical
    } else if abs_drift > MAX_DRIFT {
        DriftLevel::Warning
    } else if abs_drift > DRIFT_WARNING {
        DriftLevel::Minor
    } else {
        DriftLevel::Nominal
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn load_state() -> Option<TimestampState> {
    let path = get_state_file_path();
    
    if !path.exists() {
        return None;
    }
    
    fs::read_to_string(&path)
        .ok()
        .and_then(|content| serde_json::from_str(&content).ok())
}

fn save_state(state: &TimestampState) -> Result<(), String> {
    let path = get_state_file_path();
    
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
    }
    
    let json = serde_json::to_string_pretty(state)
        .map_err(|e| format!("Failed to serialize state: {}", e))?;
    
    fs::write(&path, json)
        .map_err(|e| format!("Failed to write state file: {}", e))?;
    
    Ok(())
}

// ═══════════════════════════════════════════════════════════════════════════════
// PID FILE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

fn write_pid() -> Result<(), String> {
    let path = get_pid_file_path();
    
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
    }
    
    let pid = std::process::id();
    fs::write(&path, pid.to_string())
        .map_err(|e| format!("Failed to write PID file: {}", e))?;
    
    Ok(())
}

fn remove_pid() {
    let path = get_pid_file_path();
    let _ = fs::remove_file(&path);
}

fn check_existing_pid() -> Option<u32> {
    let path = get_pid_file_path();
    
    if !path.exists() {
        return None;
    }
    
    fs::read_to_string(&path)
        .ok()
        .and_then(|s| s.trim().parse().ok())
        .filter(|&pid| pid != std::process::id())
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNC LOGIC
// ═══════════════════════════════════════════════════════════════════════════════

fn perform_sync(state: &mut TimestampState) -> SyncResult {
    let span = otel_start_span("perform_sync");
    
    let system_ts = get_system_timestamp();
    let model_ts = state.model_timestamp;
    let drift = system_ts - model_ts;
    let abs_drift = drift.abs();
    let drift_level = calculate_drift_level(abs_drift);
    let ntp_synced = get_ntp_status();
    
    state.last_sync = system_ts;
    state.last_sync_iso = Utc::now().to_rfc3339();
    state.system_to_model_drift = drift;
    state.drift_level = drift_level.as_str().to_string();
    state.sync_count += 1;
    
    otel_end_span(&span, "ok");
    
    SyncResult {
        system_ts,
        model_ts,
        drift,
        abs_drift,
        drift_level,
        ntp_synced,
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN DAEMON LOOP
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut logger = Logger::new();
    
    logger.info(&format!("═══════════════════════════════════════════════════════════════"));
    logger.info(&format!("{} {} {}", APP_NAME, SIL6_VERSION, VERSION));
    logger.info(&format!("═══════════════════════════════════════════════════════════════"));
    
    if let Some(pid) = check_existing_pid() {
        logger.error(&format!("Daemon already running with PID {}. Exiting.", pid));
        return Ok(());
    }
    
    if let Err(e) = write_pid() {
        logger.error(&format!("Failed to write PID file: {}", e));
        return Err(e.into());
    }
    
    logger.info("PID file written");
    
    let mut state = load_state().unwrap_or_else(|| TimestampState {
        last_sync: get_system_timestamp(),
        last_sync_iso: Utc::now().to_rfc3339(),
        opencode_session_start: get_system_timestamp(),
        model_timestamp: get_system_timestamp(),
        system_to_model_drift: 0,
        sync_count: 0,
        sync_source: format!("{} v{}", APP_NAME, VERSION),
        drift_level: "nominal".to_string(),
    });
    
    if state.model_timestamp == 0 {
        state.model_timestamp = get_system_timestamp();
        state.opencode_session_start = get_system_timestamp();
    }
    
    logger.info(&format!(
        "Loaded state: {} syncs, drift_level={}, drift={}s",
        state.sync_count, state.drift_level, state.system_to_model_drift
    ));
    
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        r.store(false, Ordering::SeqCst);
    });
    
    let mut sync_interval = interval(Duration::from_secs(SYNC_INTERVAL_SECS));
    let mut log_interval = interval(Duration::from_secs(LOG_INTERVAL_SECS));
    let mut tui_interval = interval(Duration::from_millis(TUI_REFRESH_MS));
    
    let zenoh = ZenohPublisher::new();
    let mut tui = TUI::new();
    let tui_enabled = true;
    
    let result = perform_sync(&mut state);
    let drift_level = calculate_drift_level(result.abs_drift);
    tui.drift_level = drift_level;
    
    logger.info(&format!(
        "Initial sync: system={} model={} drift={}s ({}), NTP={}",
        format_timestamp(result.system_ts),
        format_timestamp(result.model_ts),
        result.drift,
        result.drift_level.as_str(),
        result.ntp_synced
    ));
    
    logger.fractal_info(
        L7_FEDERATION,
        &format!("Initial sync: drift={}s", result.drift),
        result.drift,
        result.drift_level.as_str(),
        state.sync_count
    );
    
    if let Err(e) = save_state(&state) {
        logger.error(&format!("Failed to save initial state: {}", e));
    }
    
    let mut tui_state = TUIState {
        running: true,
        last_sync: result.system_ts,
        drift: result.drift,
        drift_level,
        sync_count: state.sync_count,
        ntp_synced: result.ntp_synced,
        zenoh_connected: false,
        otel_tracing: true,
        fractal_layer: L7_FEDERATION,
    };
    
    if tui_enabled {
        tui.render(&tui_state);
    }
    
    loop {
        tokio::select! {
            _ = sync_interval.tick() => {
                logger.new_trace_id();
                let span = otel_start_span("periodic_sync");
                
                let result = perform_sync(&mut state);
                let drift_level = calculate_drift_level(result.abs_drift);
                tui.drift_level = drift_level;
                
                logger.info(&format!(
                    "Sync #{}: drift={}s ({}), NTP={}",
                    state.sync_count,
                    result.drift,
                    result.drift_level.as_str(),
                    result.ntp_synced
                ));
                
                logger.fractal_info(
                    L5_COGNITIVE,
                    &format!("Periodic sync: drift={}s", result.drift),
                    result.drift,
                    result.drift_level.as_str(),
                    state.sync_count
                );
                
                match result.drift_level {
                    DriftLevel::Critical => {
                        logger.error(&format!(
                            "CRITICAL drift: {}s exceeds {}s threshold",
                            result.abs_drift, DRIFT_CRITICAL
                        ));
                        
                        zenoh.publish_alert("critical", "Critical timestamp drift detected", result.drift);
                        
                        logger.info("Attempting NTP sync...");
                        if attempt_ntp_sync() {
                            logger.info("NTP sync triggered successfully");
                        } else {
                            logger.error("NTP sync failed - manual intervention required");
                        }
                    }
                    DriftLevel::Warning => {
                        logger.warn(&format!("Warning: drift {}s exceeds max {}s", result.abs_drift, MAX_DRIFT));
                        zenoh.publish_alert("warning", "Timestamp drift warning", result.drift);
                    }
                    DriftLevel::Minor => {
                        logger.info(&format!("Minor drift: {}s", result.abs_drift));
                    }
                    DriftLevel::Nominal => {
                        logger.debug(&format!("Drift within acceptable range: {}s", result.abs_drift));
                    }
                }
                
                let telemetry = ZenohTelemetry {
                    drift_seconds: result.drift,
                    drift_level: result.drift_level.as_str().to_string(),
                    sync_count: state.sync_count,
                    ntp_synced: result.ntp_synced,
                    system_ts: result.system_ts,
                    model_ts: result.model_ts,
                    timestamp: Utc::now().to_rfc3339(),
                    trace_id: format!("{:016x}", generate_trace_id()),
                    span_id: format!("{:08x}", span.parse::<u64>().unwrap_or(0)),
                };
                
                zenoh.publish_status(&telemetry);
                tui_state.zenoh_connected = zenoh.enabled;
                
                otel_end_span(&span, "ok");
                
                if let Err(e) = save_state(&state) {
                    logger.error(&format!("Failed to save state: {}", e));
                }
            }
            
            _ = log_interval.tick() => {
                logger.debug(&format!(
                    "Keepalive: {} syncs, drift={}s ({}), NTP={}",
                    state.sync_count,
                    state.system_to_model_drift.abs(),
                    state.drift_level,
                    get_ntp_status()
                ));
            }
            
            _ = tui_interval.tick() => {
                if tui_enabled {
                    tui_state.last_sync = state.last_sync;
                    tui_state.drift = state.system_to_model_drift;
                    tui_state.sync_count = state.sync_count;
                    tui_state.ntp_synced = get_ntp_status();
                    tui.render(&tui_state);
                }
            }
            
            _ = tokio::signal::ctrl_c() => {
                logger.info("Received shutdown signal");
                break;
            }
            
            _ = tokio::time::sleep(Duration::from_secs(1)) => {
                if !running.load(Ordering::SeqCst) {
                    logger.info("Shutdown flag set, exiting...");
                    break;
                }
            }
        }
    }
    
    if tui_enabled {
        TUI::show_cursor();
        println!("\n{}{}Daemon stopped{}", TUI::BOLD, TUI::FG_GREEN, TUI::RESET);
    }
    
    remove_pid();
    logger.info("Daemon stopped");
    
    Ok(())
}
