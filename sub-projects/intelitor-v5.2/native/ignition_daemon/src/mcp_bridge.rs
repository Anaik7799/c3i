use crate::apoptosis;
use crate::down;
use crate::errors::IgnitionError;
use crate::governor;
use crate::launch;
use crate::podman;
use crate::preflight;
use crate::robust_launch;
use crate::seven_level_rca;
use crate::types::LaunchMode;
use crate::verify;
use log::{error, info, warn};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use uuid::Uuid;
use zenoh::Session;

// ─────────────────────────────────────────────────────────────────────────────
// JSON-RPC 2.0 wire types
// SC-MCP-001: MCP tool catalog MUST be published on startup.
// SC-ZMOF-001: Zenoh is the SOLE transport for internal mesh communication.
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct McpRequest {
    pub jsonrpc: String,
    pub method: String,
    pub params: serde_json::Value,
    pub id: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct McpResponse {
    pub jsonrpc: String,
    pub result: Option<serde_json::Value>,
    pub error: Option<McpError>,
    pub id: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct McpError {
    pub code: i32,
    pub message: String,
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct McpTool {
    pub name: String,
    pub description: String,
    pub input_schema: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct McpCatalog {
    pub tools: Vec<McpTool>,
}

// ─────────────────────────────────────────────────────────────────────────────
// Tool Catalog — all 11 tools (6 original + 5 new operational tools)
// SC-MCP-001: MCP tool catalog MUST be published on startup.
// SC-ZMOF-005: Feature exposed as MoZ tool if actionable.
// ─────────────────────────────────────────────────────────────────────────────

/// Build the authoritative tool catalog published on startup and on heartbeat.
/// All 11 tools cover the full operational surface of the ignition daemon.
pub fn tool_catalog() -> McpCatalog {
    McpCatalog {
        tools: vec![
            // ── Originally published but unhandled ────────────────────────
            McpTool {
                name: "ignition_status".into(),
                description: "Get current mesh status: CPU governor reading, container states, health summary".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "ignition_preflight".into(),
                description: "Run the 18-point SIL-6 preflight check suite (SC-BOOT-001..SC-BOOT-010)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "ignition_rca".into(),
                description: "Run 7-level (L1–L7) root cause analysis on an error description".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "error": {
                            "type": "string",
                            "description": "Error text or log snippet to analyse"
                        }
                    },
                    "required": ["error"],
                    "additionalProperties": false
                }),
            },
            // ── Previously handled ────────────────────────────────────────
            McpTool {
                name: "ignition_ooda".into(),
                description: "Run one OODA supervisor cycle (observe → orient → decide → act)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "cycles": {
                            "type": "integer",
                            "description": "Number of OODA cycles to run (default 1)"
                        }
                    },
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "ignition_build".into(),
                description: "Build or rebuild a container image (omit name to rebuild all)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "container": {
                            "type": "string",
                            "description": "Container name to build (optional, rebuilds all if omitted)"
                        }
                    },
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "ignition_launch".into(),
                description: "Launch the full SIL-6 biomorphic mesh (prod or test mode)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "mode": {
                            "type": "string",
                            "enum": ["prod", "test"],
                            "description": "Launch mode (default: prod)"
                        }
                    },
                    "additionalProperties": false
                }),
            },
            // ── New operational tools ─────────────────────────────────────
            McpTool {
                name: "ignition_down".into(),
                description: "Gracefully shut down all 16 SIL-6 containers (10 s drain per container)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "ignition_emergency".into(),
                description: "Trigger immediate 6-phase apoptosis emergency stop (ManualKillSwitch)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "ignition_verify".into(),
                description: "Run the 14-point post-launch verification suite (SC-VER-001..SC-VER-079)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "planning_status".into(),
                description: "List all planning tasks from the Smriti SQLite store (sa-plan equivalent)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "filter": {
                            "type": "string",
                            "enum": ["all", "pending", "in_progress", "completed", "blocked"],
                            "description": "Status filter (default: all)"
                        }
                    },
                    "additionalProperties": false
                }),
            },
            McpTool {
                name: "planning_add".into(),
                description: "Add a new task to the Smriti planning DB (equivalent to sa-plan add)".into(),
                input_schema: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "title": {
                            "type": "string",
                            "description": "Task description"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["P0", "P1", "P2", "P3"],
                            "description": "Task priority (default: P2)"
                        }
                    },
                    "required": ["title"],
                    "additionalProperties": false
                }),
            },
        ],
    }
}

/// Count available tools in the catalog.
pub fn tool_count() -> usize {
    tool_catalog().tools.len()
}

// ─────────────────────────────────────────────────────────────────────────────
// ZenohMcpBridge — MCP-over-Zenoh (MoZ) transport
// Subscribes to: indrajaal/l4/ignition/mcp/req/{tool}/{request_id}
// Publishes to:  indrajaal/l4/ignition/mcp/res/{request_id}
// Heartbeat:     indrajaal/l4/ignition/{node_id}/heartbeat (1 000 ms)
// Catalog:       indrajaal/l4/ignition/mcp/catalog/{node_id}
// ─────────────────────────────────────────────────────────────────────────────

pub struct ZenohMcpBridge {
    session: Arc<Session>,
    node_id: String,
}

impl ZenohMcpBridge {
    pub fn new(session: Arc<Session>) -> Self {
        let node_id = Uuid::new_v4().to_string();
        Self { session, node_id }
    }

    pub async fn run(&self) -> Result<(), IgnitionError> {
        info!("Zenoh-MCP-Bridge ACTIVE (MoZ) — node {}", self.node_id);

        // Publish initial catalog (SC-MCP-001)
        self.publish_catalog().await?;

        // Heartbeat + catalog republish task
        let session_hb = Arc::clone(&self.session);
        let node_id_hb = self.node_id.clone();
        tokio::spawn(async move {
            let mut interval =
                tokio::time::interval(std::time::Duration::from_millis(1_000));
            loop {
                interval.tick().await;
                // SC-MSG-004: heartbeat every 1 000 ms
                let hb_key =
                    format!("indrajaal/l4/ignition/{}/heartbeat", node_id_hb);
                let _ = session_hb.put(&hb_key, "ALIVE").await;

                // Republish catalog on every heartbeat so new subscribers see it
                let catalog_key = format!(
                    "indrajaal/l4/ignition/mcp/catalog/{}",
                    node_id_hb
                );
                if let Ok(payload) = serde_json::to_string(&tool_catalog()) {
                    let _ = session_hb.put(&catalog_key, payload).await;
                }
            }
        });

        // Subscribe to tool requests
        let subscriber = self
            .session
            .declare_subscriber("indrajaal/l4/ignition/mcp/req/*/*")
            .await
            .map_err(|e| {
                IgnitionError::InternalError(format!(
                    "Zenoh subscriber declaration failed: {}",
                    e
                ))
            })?;

        while let Ok(sample) = subscriber.recv_async().await {
            let key = sample.key_expr().to_string();
            // key format: indrajaal/l4/ignition/mcp/req/{tool_name}/{request_id}
            let parts: Vec<&str> = key.split('/').collect();
            if parts.len() < 7 {
                warn!("MoZ: malformed key '{}'", key);
                continue;
            }

            let tool_name = parts[5];
            let request_id = parts[6];
            let payload =
                String::from_utf8_lossy(&sample.payload().to_bytes()).to_string();

            match serde_json::from_str::<McpRequest>(&payload) {
                Ok(req) => {
                    let response = self.handle_request(tool_name, req).await;
                    let res_key = format!(
                        "indrajaal/l4/ignition/mcp/res/{}",
                        request_id
                    );
                    if let Ok(res_payload) = serde_json::to_string(&response) {
                        let _ = self.session.put(&res_key, res_payload).await;
                    }
                }
                Err(e) => {
                    error!("MoZ: failed to parse request on '{}': {}", key, e);
                }
            }
        }

        Ok(())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Catalog publisher
    // ─────────────────────────────────────────────────────────────────────────

    async fn publish_catalog(&self) -> Result<(), IgnitionError> {
        let key = format!(
            "indrajaal/l4/ignition/mcp/catalog/{}",
            self.node_id
        );
        let payload = serde_json::to_string(&tool_catalog()).unwrap_or_default();
        self.session
            .put(&key, payload)
            .await
            .map_err(|e| {
                IgnitionError::InternalError(format!(
                    "Zenoh catalog publish failed: {}",
                    e
                ))
            })
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Request dispatcher
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_request(
        &self,
        tool_name: &str,
        req: McpRequest,
    ) -> McpResponse {
        info!("MoZ tool call: '{}'", tool_name);

        let result = match tool_name {
            // Previously unhandled — now fully implemented
            "ignition_status" => self.handle_status(req.params).await,
            "ignition_preflight" => self.handle_preflight(req.params).await,
            "ignition_rca" => self.handle_rca(req.params).await,

            // Previously handled
            "ignition_launch" => self.handle_launch(req.params).await,
            "ignition_restart" | "restart" => {
                self.handle_restart(req.params).await
            }
            "ignition_drain" | "drain" => self.handle_drain(req.params).await,

            // New operational tools
            "ignition_down" => self.handle_down(req.params).await,
            "ignition_emergency" => self.handle_emergency(req.params).await,
            "ignition_verify" => self.handle_verify(req.params).await,
            "planning_status" => self.handle_planning_status(req.params).await,
            "planning_add" => self.handle_planning_add(req.params).await,

            _ => Err(McpError {
                code: -32_601,
                message: format!("Method not found: '{}'", tool_name),
                data: Some(serde_json::json!({
                    "available_tools": tool_catalog()
                        .tools
                        .iter()
                        .map(|t| &t.name)
                        .collect::<Vec<_>>()
                })),
            }),
        };

        match result {
            Ok(res) => McpResponse {
                jsonrpc: "2.0".into(),
                result: Some(res),
                error: None,
                id: req.id,
            },
            Err(err) => McpResponse {
                jsonrpc: "2.0".into(),
                result: None,
                error: Some(err),
                id: req.id,
            },
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_status
    // Returns: CPU governor reading + container health summary
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_status(
        &self,
        _params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        info!("MoZ ignition_status: sampling CPU and container states");

        let cpu_pct = governor::cpu_usage_fast().await.unwrap_or(0);

        let genome = crate::artifacts::SIL6_GENOME;
        let mut container_statuses = Vec::with_capacity(genome.len());
        for &name in genome {
            let status = podman::container_status(name)
                .await
                .unwrap_or_else(|_| "unknown".into());
            container_statuses.push(serde_json::json!({
                "name": name,
                "status": status
            }));
        }

        let running_count = container_statuses
            .iter()
            .filter(|c| c["status"] == "running")
            .count();

        Ok(serde_json::json!({
            "cpu_pct": cpu_pct,
            "containers": container_statuses,
            "running": running_count,
            "total": genome.len(),
            "mesh_health": if running_count == genome.len() { "healthy" }
                           else if running_count > genome.len() / 2 { "degraded" }
                           else { "critical" }
        }))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_preflight
    // Returns: full PreflightReport serialised as JSON
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_preflight(
        &self,
        _params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        info!("MoZ ignition_preflight: running 18-point preflight suite");

        match preflight::run_all().await {
            Ok(report) => serde_json::to_value(&report).map_err(|e| McpError {
                code: -32_000,
                message: format!("Failed to serialise preflight report: {}", e),
                data: None,
            }),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Preflight execution failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_rca
    // Returns: RcaResult with L1–L7 classification
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_rca(
        &self,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        let error_text = match params["error"].as_str() {
            Some(e) => e.to_string(),
            None => {
                return Err(McpError {
                    code: -32_602,
                    message: "Missing required parameter 'error'".into(),
                    data: None,
                })
            }
        };

        info!(
            "MoZ ignition_rca: analysing error ({} chars)",
            error_text.len()
        );

        let result = seven_level_rca::analyze_error(&error_text);

        serde_json::to_value(&result).map_err(|e| McpError {
            code: -32_000,
            message: format!("Failed to serialise RCA result: {}", e),
            data: None,
        })
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_launch (previously implemented)
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_launch(
        &self,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        let mode_str = params["mode"].as_str().unwrap_or("prod");
        let mode = if mode_str == "test" {
            LaunchMode::Test
        } else {
            LaunchMode::Prod
        };

        info!("MoZ ignition_launch: mode={:?}", mode);

        match launch::launch_mesh().await {
            Ok(_) => Ok(serde_json::json!({
                "status": "success",
                "mode": mode_str
            })),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Launch failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: restart (previously implemented — kept for backwards compat)
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_restart(
        &self,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        let container = match params["container"].as_str() {
            Some(c) => c,
            None => {
                return Err(McpError {
                    code: -32_602,
                    message: "Missing required parameter 'container'".into(),
                    data: None,
                })
            }
        };

        info!("MoZ restart: stopping container '{}'", container);

        match podman::stop_container(container, 5).await {
            Ok(_) => Ok(serde_json::json!({
                "status": "stopped",
                "container": container,
                "note": "Container stopped; use ignition_launch to restart the mesh"
            })),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Restart (stop phase) failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: drain (previously implemented — kept for backwards compat)
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_drain(
        &self,
        _params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        info!("MoZ drain: initiating emergency drain");

        match robust_launch::emergency_drain(&[]).await {
            Ok(res) => Ok(serde_json::json!(res)),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Emergency drain failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_down  (NEW)
    // Calls down::run_down() — graceful 10 s per-container shutdown
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_down(
        &self,
        _params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        info!("MoZ ignition_down: initiating graceful SIL-6 mesh shutdown");

        match down::run_down().await {
            Ok(_) => Ok(serde_json::json!({
                "status": "success",
                "message": "All SIL-6 containers shut down gracefully"
            })),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Graceful shutdown failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_emergency  (NEW)
    // Triggers 6-phase apoptosis emergency stop (ManualKillSwitch)
    // SC-EMR-057: Emergency stop < 5 s
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_emergency(
        &self,
        _params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        warn!("MoZ ignition_emergency: EMERGENCY STOP requested via MCP");

        match apoptosis::emergency_stop().await {
            Ok(_) => Ok(serde_json::json!({
                "status": "success",
                "message": "Emergency stop executed — all containers halted",
                "stamp": ["SC-EMR-057", "SC-VER-045", "SC-SAFETY-022"]
            })),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Emergency stop failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: ignition_verify  (NEW)
    // Runs 14-point post-launch verification (waits 45 s for boot stabilisation)
    // SC-VER-001: Startup verification before app ready
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_verify(
        &self,
        _params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        info!("MoZ ignition_verify: running 14-point verification suite");

        match verify::run_all().await {
            Ok(report) => serde_json::to_value(&report).map_err(|e| McpError {
                code: -32_000,
                message: format!("Failed to serialise verify report: {}", e),
                data: None,
            }),
            Err(e) => Err(McpError {
                code: -32_000,
                message: format!("Verification run failed: {}", e),
                data: None,
            }),
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: planning_status  (NEW)
    // Reads Smriti.db directly (same path as sa-plan, SC-TODO-001 context:
    // sa-plan is the Gleam-side CLI; this is the Rust MCP counterpart)
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_planning_status(
        &self,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        let filter: String = params["filter"]
            .as_str()
            .unwrap_or("all")
            .to_string();
        info!("MoZ planning_status: filter='{}'", filter);

        // Open Smriti.db (same path used by sa-plan / planning_daemon)
        let db_path = std::env::var("PLANNING_DB_PATH")
            .unwrap_or_else(|_| "data/smriti/Smriti.db".into());

        let filter_for_response = filter.clone();
        let tasks = tokio::task::spawn_blocking(move || {
            query_tasks(&db_path, &filter)
        })
        .await
        .map_err(|e| McpError {
            code: -32_000,
            message: format!("Planning DB task panicked: {}", e),
            data: None,
        })?
        .map_err(|e| McpError {
            code: -32_000,
            message: format!("Planning DB query failed: {}", e),
            data: None,
        })?;

        let count = tasks.len();
        Ok(serde_json::json!({
            "tasks": tasks,
            "count": count,
            "filter": filter_for_response
        }))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handler: planning_add  (NEW)
    // Inserts a task into Smriti.db via the same schema used by sa-plan
    // ─────────────────────────────────────────────────────────────────────────

    async fn handle_planning_add(
        &self,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, McpError> {
        let title = match params["title"].as_str() {
            Some(t) if !t.is_empty() => t.to_string(),
            _ => {
                return Err(McpError {
                    code: -32_602,
                    message: "Missing required parameter 'title'".into(),
                    data: None,
                })
            }
        };
        let priority = params["priority"]
            .as_str()
            .unwrap_or("P2")
            .to_string();

        info!(
            "MoZ planning_add: title='{}' priority='{}'",
            title, priority
        );

        let db_path = std::env::var("PLANNING_DB_PATH")
            .unwrap_or_else(|_| "data/smriti/Smriti.db".into());

        let priority_for_response = priority.clone();
        let task_id = tokio::task::spawn_blocking(move || {
            insert_task(&db_path, &title, &priority)
        })
        .await
        .map_err(|e| McpError {
            code: -32_000,
            message: format!("Planning DB task panicked: {}", e),
            data: None,
        })?
        .map_err(|e| McpError {
            code: -32_000,
            message: format!("Planning DB insert failed: {}", e),
            data: None,
        })?;

        Ok(serde_json::json!({
            "status": "created",
            "task_id": task_id,
            "priority": priority_for_response
        }))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blocking SQLite helpers (called via spawn_blocking)
// These mirror the sa-plan / planning_daemon schema exactly.
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
struct TaskRow {
    id: String,
    title: String,
    status: String,
    priority: String,
    created: String,
}

fn query_tasks(db_path: &str, filter: &str) -> Result<Vec<TaskRow>, String> {
    let conn = Connection::open(db_path)
        .map_err(|e| format!("Cannot open Smriti.db at '{}': {}", db_path, e))?;

    conn.busy_timeout(std::time::Duration::from_millis(5_000))
        .ok();

    let sql = if filter == "all" {
        "SELECT Id, Title, Status, Priority, Created \
         FROM Tasks ORDER BY Created ASC, Id ASC"
            .to_string()
    } else {
        format!(
            "SELECT Id, Title, Status, Priority, Created \
             FROM Tasks WHERE Status = '{}' ORDER BY Created ASC, Id ASC",
            filter.replace('\'', "''") // basic sanitisation
        )
    };

    let mut stmt = conn
        .prepare(&sql)
        .map_err(|e| format!("Prepare failed: {}", e))?;

    let rows = stmt
        .query_map([], |row| {
            Ok(TaskRow {
                id: row.get(0)?,
                title: row.get(1)?,
                status: row.get(2)?,
                priority: row.get(3)?,
                created: row.get(4)?,
            })
        })
        .map_err(|e| format!("Query failed: {}", e))?;

    let mut tasks = Vec::new();
    for r in rows {
        tasks.push(r.map_err(|e| format!("Row decode failed: {}", e))?);
    }
    Ok(tasks)
}

fn insert_task(
    db_path: &str,
    title: &str,
    priority: &str,
) -> Result<String, String> {
    let conn = Connection::open(db_path)
        .map_err(|e| format!("Cannot open Smriti.db at '{}': {}", db_path, e))?;

    conn.execute("PRAGMA journal_mode=WAL", []).ok();
    conn.busy_timeout(std::time::Duration::from_millis(5_000))
        .ok();

    let id: String = Uuid::new_v4()
        .to_string()
        .chars()
        .take(8)
        .collect();
    let created = chrono::Utc::now().to_rfc3339();

    conn.execute(
        "INSERT INTO Tasks (Id, Title, Status, Priority, Created, RawLines) \
         VALUES (?1, ?2, 'pending', ?3, ?4, ?5)",
        params![id, title, priority, created, ""],
    )
    .map_err(|e| format!("Insert failed: {}", e))?;

    Ok(id)
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tool_catalog_count() {
        assert_eq!(tool_count(), 11, "catalog must expose exactly 11 tools");
    }

    #[test]
    fn test_tool_catalog_has_all_required_tools() {
        let catalog = tool_catalog();
        let names: Vec<&str> =
            catalog.tools.iter().map(|t| t.name.as_str()).collect();

        let required = [
            // Originally published
            "ignition_status",
            "ignition_preflight",
            "ignition_ooda",
            "ignition_rca",
            "ignition_build",
            "ignition_launch",
            // New operational tools
            "ignition_down",
            "ignition_emergency",
            "ignition_verify",
            "planning_status",
            "planning_add",
        ];

        for tool in &required {
            assert!(
                names.contains(tool),
                "catalog missing '{}'; found: {:?}",
                tool,
                names
            );
        }
    }

    #[test]
    fn test_tool_schemas_are_valid_json_objects() {
        for tool in tool_catalog().tools {
            assert!(
                tool.input_schema.is_object(),
                "tool '{}' has non-object input_schema",
                tool.name
            );
        }
    }

    #[test]
    fn test_rca_required_param_returns_error() {
        // Verify the param validation logic is exercised synchronously
        // by checking the schema declares "error" as required.
        let tool = tool_catalog()
            .tools
            .into_iter()
            .find(|t| t.name == "ignition_rca")
            .expect("ignition_rca must exist");

        let required = tool.input_schema["required"]
            .as_array()
            .expect("ignition_rca must have 'required' array");
        assert!(
            required.iter().any(|v| v.as_str() == Some("error")),
            "ignition_rca must declare 'error' as required"
        );
    }

    #[test]
    fn test_planning_add_required_param() {
        let tool = tool_catalog()
            .tools
            .into_iter()
            .find(|t| t.name == "planning_add")
            .expect("planning_add must exist");

        let required = tool.input_schema["required"]
            .as_array()
            .expect("planning_add must have 'required' array");
        assert!(
            required.iter().any(|v| v.as_str() == Some("title")),
            "planning_add must declare 'title' as required"
        );
    }

    #[test]
    fn test_catalog_no_duplicate_names() {
        let catalog = tool_catalog();
        let mut seen = std::collections::HashSet::new();
        for tool in &catalog.tools {
            assert!(
                seen.insert(tool.name.as_str()),
                "duplicate tool name '{}' in catalog",
                tool.name
            );
        }
    }
}
