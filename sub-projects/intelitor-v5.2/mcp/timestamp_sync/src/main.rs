//! MCP Server for Timestamp Sync
//!
//! Provides MCP (Model Context Protocol) tools for timestamp synchronization.
//!
//! Version: v21.3.2-SIL6

use serde::{Deserialize, Serialize};
use serde_json::json;
use std::fs;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

// ═══════════════════════════════════════════════════════════════════════════════
// DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DriftStatus {
    pub drift_seconds: i64,
    pub drift_level: String,
    pub sync_count: u64,
    pub ntp_synced: bool,
    pub system_ts: i64,
    pub model_ts: i64,
    pub timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MCPToolResult {
    pub success: bool,
    pub tool: String,
    pub result: serde_json::Value,
    pub timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MCPToolDefinition {
    pub name: String,
    pub description: String,
    pub input_schema: serde_json::Value,
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const STATE_DIR: &str = "/home/an/.local/share/indrajaal-timestamp-sync";
const STATE_FILE: &str =
    "/home/an/.local/share/indrajaal-timestamp-sync/data/state/timestamp-state.json";
const PID_FILE: &str = "/home/an/.local/share/indrajaal-timestamp-sync/timestamp-daemon.pid";

// Thresholds
const MAX_DRIFT: i64 = 5;
const DRIFT_WARNING: i64 = 2;
const DRIFT_CRITICAL: i64 = 10;

// ═══════════════════════════════════════════════════════════════════════════════
// MCP TOOLS
// ═══════════════════════════════════════════════════════════════════════════════

fn get_system_timestamp() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn get_current_timestamp() -> String {
    chrono::Utc::now().to_rfc3339()
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
    false
}

fn classify_drift(abs_drift: i64) -> String {
    if abs_drift > DRIFT_CRITICAL {
        "critical".to_string()
    } else if abs_drift > MAX_DRIFT {
        "warning".to_string()
    } else if abs_drift > DRIFT_WARNING {
        "minor".to_string()
    } else {
        "nominal".to_string()
    }
}

fn load_state() -> Option<serde_json::Value> {
    if !std::path::Path::new(STATE_FILE).exists() {
        return None;
    }

    fs::read_to_string(STATE_FILE)
        .ok()
        .and_then(|c| serde_json::from_str(&c).ok())
}

fn is_daemon_running() -> bool {
    if let Ok(pid_str) = fs::read_to_string(PID_FILE) {
        if let Ok(pid) = pid_str.trim().parse::<u32>() {
            // Check if process exists (Linux)
            return Command::new("ps")
                .args(["-p", &pid.to_string()])
                .output()
                .map(|o| o.status.success())
                .unwrap_or(false);
        }
    }
    false
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP TOOL IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn tool_get_drift_status() -> MCPToolResult {
    let state = load_state();
    let system_ts = get_system_timestamp();
    let (model_ts, sync_count, drift) = if let Some(ref s) = state {
        (
            s.get("model_timestamp")
                .and_then(|v| v.as_i64())
                .unwrap_or(system_ts),
            s.get("sync_count").and_then(|v| v.as_u64()).unwrap_or(0),
            s.get("system_to_model_drift")
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
        )
    } else {
        (system_ts, 0, 0)
    };

    let abs_drift = drift.abs();

    MCPToolResult {
        success: true,
        tool: "get_drift_status".to_string(),
        result: json!({
            "drift_seconds": drift,
            "abs_drift": abs_drift,
            "drift_level": classify_drift(abs_drift),
            "sync_count": sync_count,
            "system_ts": system_ts,
            "model_ts": model_ts,
            "system_ts_iso": chrono::DateTime::from_timestamp(system_ts, 0)
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_default(),
            "model_ts_iso": chrono::DateTime::from_timestamp(model_ts, 0)
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_default(),
            "ntp_synced": get_ntp_status(),
            "thresholds": {
                "max_drift": MAX_DRIFT,
                "drift_warning": DRIFT_WARNING,
                "drift_critical": DRIFT_CRITICAL
            }
        }),
        timestamp: get_current_timestamp(),
    }
}

fn tool_daemon_status() -> MCPToolResult {
    let running = is_daemon_running();
    let pid = if running {
        fs::read_to_string(PID_FILE)
            .ok()
            .map(|s| s.trim().to_string())
    } else {
        None
    };

    MCPToolResult {
        success: true,
        tool: "daemon_status".to_string(),
        result: json!({
            "running": running,
            "pid": pid,
            "state_dir": STATE_DIR,
            "state_file": STATE_FILE
        }),
        timestamp: get_current_timestamp(),
    }
}

fn tool_force_sync() -> MCPToolResult {
    let system_ts = get_system_timestamp();

    // Update state file to force sync
    let state = json!({
        "last_sync": system_ts,
        "last_sync_iso": get_current_timestamp(),
        "opencode_session_start": system_ts,
        "model_timestamp": system_ts,
        "system_to_model_drift": 0,
        "sync_count": 0,
        "sync_source": "MCP Force Sync",
        "drift_level": "nominal"
    });

    if let Some(parent) = std::path::Path::new(STATE_FILE).parent() {
        let _ = fs::create_dir_all(parent);
    }

    let write_result = fs::write(STATE_FILE, serde_json::to_string_pretty(&state).unwrap());

    MCPToolResult {
        success: write_result.is_ok(),
        tool: "force_sync".to_string(),
        result: json!({
            "system_ts": system_ts,
            "model_ts": system_ts,
            "drift": 0,
            "drift_level": "nominal",
            "message": if write_result.is_ok() {
                "State reset to nominal drift"
            } else {
                "Failed to update state file"
            }
        }),
        timestamp: get_current_timestamp(),
    }
}

fn tool_get_telemetry() -> MCPToolResult {
    let state = load_state();
    let system_ts = get_system_timestamp();

    let (model_ts, drift, drift_level, sync_count) = if let Some(ref s) = state {
        (
            s.get("model_timestamp")
                .and_then(|v| v.as_i64())
                .unwrap_or(system_ts),
            s.get("system_to_model_drift")
                .and_then(|v| v.as_i64())
                .unwrap_or(0),
            s.get("drift_level")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown")
                .to_string(),
            s.get("sync_count").and_then(|v| v.as_u64()).unwrap_or(0),
        )
    } else {
        (system_ts, 0, "nominal".to_string(), 0)
    };

    MCPToolResult {
        success: true,
        tool: "get_telemetry".to_string(),
        result: json!({
            "telemetry": {
                "drift_seconds": drift,
                "drift_level": drift_level,
                "sync_count": sync_count,
                "ntp_synced": get_ntp_status(),
                "system_ts": system_ts,
                "model_ts": model_ts,
                "timestamp": get_current_timestamp(),
                "trace_id": format!("{:016x}", system_ts as u64)
            },
            "sources": {
                "zenoh_topic_status": "indrajaal/telemetry/timestamp-sync/status",
                "zenoh_topic_alerts": "indrajaal/telemetry/timestamp-sync/alerts",
                "fractal_log": format!("{}/logs/fractal.log", STATE_DIR),
                "otel_traces": format!("{}/logs/otel_traces.jsonl", STATE_DIR)
            }
        }),
        timestamp: get_current_timestamp(),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP PROTOCOL
// ═══════════════════════════════════════════════════════════════════════════════

fn get_tools() -> Vec<MCPToolDefinition> {
    vec![
        MCPToolDefinition {
            name: "get_drift_status".to_string(),
            description: "Get current timestamp drift status between system and model".to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {},
                "required": []
            }),
        },
        MCPToolDefinition {
            name: "daemon_status".to_string(),
            description: "Check if the timestamp sync daemon is running".to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {},
                "required": []
            }),
        },
        MCPToolDefinition {
            name: "force_sync".to_string(),
            description: "Force a timestamp sync by resetting the state to current time"
                .to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {},
                "required": []
            }),
        },
        MCPToolDefinition {
            name: "get_telemetry".to_string(),
            description: "Get full telemetry including Zenoh topics and log locations".to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {},
                "required": []
            }),
        },
    ]
}

fn handle_request(input: &str) -> String {
    let request: serde_json::Value = match serde_json::from_str(input) {
        Ok(v) => v,
        Err(e) => {
            return format!(
                r#"{{"error": "Invalid JSON: {}", "json_error": "{}"}}"#,
                e, input
            )
        }
    };

    let method = request.get("method").and_then(|v| v.as_str()).unwrap_or("");

    match method {
        "tools/list" => json!({
            "jsonrpc": "2.0",
            "id": request.get("id"),
            "result": {
                "tools": get_tools()
            }
        })
        .to_string(),

        "tools/call" => {
            let params = request.get("params");
            let tool_name = params
                .and_then(|p| p.get("name"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            let result = match tool_name {
                "get_drift_status" => tool_get_drift_status(),
                "daemon_status" => tool_daemon_status(),
                "force_sync" => tool_force_sync(),
                "get_telemetry" => tool_get_telemetry(),
                _ => MCPToolResult {
                    success: false,
                    tool: tool_name.to_string(),
                    result: json!({"error": "Unknown tool"}),
                    timestamp: get_current_timestamp(),
                },
            };

            json!({
                "jsonrpc": "2.0",
                "id": request.get("id"),
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": serde_json::to_string_pretty(&result).unwrap_or_default()
                        }
                    ]
                }
            })
            .to_string()
        }

        _ => json!({
            "jsonrpc": "2.0",
            "id": request.get("id"),
            "error": {
                "code": -32601,
                "message": format!("Method not found: {}", method)
            }
        })
        .to_string(),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

fn main() {
    println!("Indrajaal Timestamp Sync MCP Server v21.3.2-SIL6");
    println!("Listening for MCP requests...");

    loop {
        use std::io::{BufRead, BufReader};

        let mut input = String::new();
        let stdin = std::io::stdin();
        let mut handle = stdin.lock();

        if handle.read_line(&mut input).is_ok() {
            let input = input.trim();
            if input.is_empty() {
                continue;
            }

            let response = handle_request(input);
            println!("{}", response);
        }
    }
}
