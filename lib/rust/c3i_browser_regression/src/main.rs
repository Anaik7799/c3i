// =============================================================================
// [C3I-SIL6-MSTS] Rust Browser Regression TUI
// Fractal Layer: L1_ATOMIC_DEBUG
// Purpose: Full regression test of all c3i web pages with live Ratatui dashboard.
//          Tests HTTP status, JSON validity, content assertions, response times.
//          Covers all 24+ API endpoints + HTML pages + AG-UI SSE health.
// STAMP: SC-COV-001, SC-UIGT-001, SC-GLM-UI-001, SC-AGUI-001
// =============================================================================

#![deny(warnings, unused_imports, dead_code)]

use c3i_common::telemetry;
use chrono::Local;
use clap::Parser;
use crossterm::{
    event::{self, Event, KeyCode},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Cell, Gauge, Paragraph, Row, Table},
    Terminal,
};
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::io::{self, stdout};
use std::path::PathBuf;
use std::time::{Duration, Instant};

// =============================================================================
// CLI Definition
// =============================================================================

#[derive(Parser)]
#[command(name = "c3i_browser_regression")]
#[command(about = "SIL-6 browser regression suite with live Ratatui TUI")]
struct Cli {
    /// Run without TUI; print results to stdout
    #[arg(long)]
    headless: bool,

    /// Base URL of the C3I server
    #[arg(long, env = "C3I_URL", default_value = "http://localhost:4100")]
    url: String,

    /// Publish results to Zenoh mesh (Phase 4)
    #[arg(long)]
    publish_zenoh: bool,

    /// Write test results as JSON to this file
    #[arg(long)]
    json_output: Option<PathBuf>,

    /// Enable verbose tracing output
    #[arg(short, long)]
    verbose: bool,

    /// Run only tests in this category
    #[arg(long, value_parser = ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "AG-UI", "A2UI"])]
    category: Option<String>,
}

// =============================================================================
// Test Definition
// =============================================================================

#[derive(Clone)]
struct TestCase {
    name: &'static str,
    path: &'static str,
    method: Method,
    category: Category,
    assertions: Vec<Assertion>,
}

#[derive(Clone, Copy)]
enum Method {
    Get,
    #[allow(dead_code)]
    Post,
}

#[derive(Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Category {
    C1PageStructure,
    C2StatusBadge,
    C3DataGrid,
    C4Timeline,
    C5Interactive,
    C6MediaRich,
    C7AiAdvisory,
    C8ActionButton,
    AgUi,
    A2Ui,
}

#[derive(Clone)]
enum Assertion {
    StatusCode(u16),
    ContainsText(&'static str),
    IsValidJson,
    HasJsonField(&'static str),
    ResponseTimeMs(u64),
    ContentTypeHtml,
    #[allow(dead_code)]
    ContentTypeJson,
}

#[derive(Clone, Serialize, Deserialize)]
struct TestResult {
    name: String,
    path: String,
    category: Category,
    status: TestStatus,
    response_time_ms: u64,
    status_code: u16,
    assertions_passed: usize,
    assertions_total: usize,
    error: Option<String>,
}

#[derive(Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum TestStatus {
    Pass,
    Fail,
    #[allow(dead_code)]
    Running,
    #[allow(dead_code)]
    Pending,
}

// =============================================================================
// Test Suite Definition — All c3i Pages & Endpoints
// =============================================================================

fn build_test_suite() -> Vec<TestCase> {
    vec![
        // ── C1: Page Structure (HTML pages) ─────────────────────────
        TestCase {
            name: "Dashboard HTML loads",
            path: "/",
            method: Method::Get,
            category: Category::C1PageStructure,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContentTypeHtml,
                Assertion::ContainsText("INDRAJAAL C3I"),
                Assertion::ContainsText("Dashboard"),
                Assertion::ResponseTimeMs(2000),
            ],
        },
        TestCase {
            name: "Dashboard has nav bar",
            path: "/",
            method: Method::Get,
            category: Category::C1PageStructure,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("Planning"),
                Assertion::ContainsText("Health"),
                Assertion::ContainsText("Verification"),
            ],
        },
        TestCase {
            name: "Planning Cockpit HTML loads",
            path: "/planning",
            method: Method::Get,
            category: Category::C1PageStructure,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContentTypeHtml,
                Assertion::ContainsText("Planning"),
                Assertion::ResponseTimeMs(2000),
            ],
        },

        // ── C2: Status/Badge (Health endpoints) ─────────────────────
        TestCase {
            name: "API Health returns OK",
            path: "/api/health",
            method: Method::Get,
            category: Category::C2StatusBadge,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("status"),
                Assertion::ResponseTimeMs(500),
            ],
        },
        TestCase {
            name: "Safety status returns JSON",
            path: "/api/safety/status",
            method: Method::Get,
            category: Category::C2StatusBadge,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },

        // ── C3: Data Grid (List endpoints) ──────────────────────────
        TestCase {
            name: "Planning tasks list",
            path: "/api/planning/tasks",
            method: Method::Get,
            category: Category::C3DataGrid,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("tasks"),
                Assertion::ResponseTimeMs(500),
            ],
        },
        TestCase {
            name: "Orchestration services list",
            path: "/api/orchestration/status",
            method: Method::Get,
            category: Category::C3DataGrid,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Dashboard state JSON",
            path: "/api/dashboard",
            method: Method::Get,
            category: Category::C3DataGrid,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
            ],
        },

        // ── C4: Timeline (OODA + History) ───────────────────────────
        TestCase {
            name: "OODA status returns cycle data",
            path: "/api/ooda/status",
            method: Method::Get,
            category: Category::C4Timeline,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
                Assertion::HasJsonField("cycle_count"),
            ],
        },
        TestCase {
            name: "OODA history available",
            path: "/api/ooda/history",
            method: Method::Get,
            category: Category::C4Timeline,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },

        // ── C5: Interactive (Mutation endpoints) ────────────────────
        TestCase {
            name: "Safety check endpoint responds",
            path: "/api/safety/status",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Chaya sync returns report",
            path: "/api/chaya/sync",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
            ],
        },
        TestCase {
            name: "Chaya status endpoint",
            path: "/api/chaya/status",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },

        // ── C6: Media/Rich (Visualization endpoints) ────────────────
        TestCase {
            name: "Graph verification with checks",
            path: "/api/graph/verify",
            method: Method::Get,
            category: Category::C6MediaRich,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
                Assertion::HasJsonField("checks"),
            ],
        },
        TestCase {
            name: "Math optimization with waves",
            path: "/api/math/optimize",
            method: Method::Get,
            category: Category::C6MediaRich,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
                Assertion::HasJsonField("containers"),
            ],
        },

        // ── C7: AI/Advisory (Intelligence endpoints) ────────────────
        TestCase {
            name: "Cockpit node intelligence",
            path: "/api/cockpit/nodes",
            method: Method::Get,
            category: Category::C7AiAdvisory,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
            ],
        },

        // ── C8: Action (Verification + Action endpoints) ────────────
        TestCase {
            name: "Verification status check",
            path: "/api/verification/status",
            method: Method::Get,
            category: Category::C8ActionButton,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("page"),
            ],
        },
        TestCase {
            name: "Enforcer/safety status",
            path: "/api/safety/status",
            method: Method::Get,
            category: Category::C8ActionButton,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },

        // ── AG-UI Protocol ──────────────────────────────────────────
        TestCase {
            name: "AG-UI health endpoint",
            path: "/ag-ui/health",
            method: Method::Get,
            category: Category::AgUi,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("protocol"),
                Assertion::HasJsonField("capabilities"),
                Assertion::ContainsText("ag-ui"),
            ],
        },
        TestCase {
            name: "AG-UI SSE stream endpoint",
            path: "/ag-ui/events?thread=regression-test",
            method: Method::Get,
            category: Category::AgUi,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("RUN_STARTED"),
                Assertion::ContainsText("RUN_FINISHED"),
            ],
        },

        // ── PLANNING PAGE: Deep Element Tests ────────────────────────
        // Panel 1: Task Board
        TestCase {
            name: "Planning tasks have task list",
            path: "/api/planning/tasks",
            method: Method::Get,
            category: Category::C3DataGrid,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
                Assertion::HasJsonField("tasks"),
                Assertion::HasJsonField("summary"),
                Assertion::ContainsText("COMPLETED"),
            ],
        },
        TestCase {
            name: "Planning tasks have status summary",
            path: "/api/planning/tasks",
            method: Method::Get,
            category: Category::C2StatusBadge,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("summary"),
                Assertion::ContainsText("pending"),
            ],
        },

        // Panel 2: OODA Cycle
        TestCase {
            name: "OODA has cycle count and latency",
            path: "/api/ooda/status",
            method: Method::Get,
            category: Category::C4Timeline,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::HasJsonField("cycle_count"),
                Assertion::HasJsonField("last_cycle_ms"),
                Assertion::HasJsonField("target_ms"),
                Assertion::HasJsonField("patterns"),
            ],
        },

        // Panel 3: Safety Kernel
        TestCase {
            name: "Safety check endpoint accessible",
            path: "/api/safety/status",
            method: Method::Get,
            category: Category::C2StatusBadge,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },

        // Panel 5: Graph Verification
        TestCase {
            name: "Graph verify has checks and result",
            path: "/api/graph/verify",
            method: Method::Get,
            category: Category::C8ActionButton,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::HasJsonField("checks"),
                Assertion::HasJsonField("all_passed"),
            ],
        },

        // Panel 6: Orchestration Mesh
        TestCase {
            name: "Orchestration has services and quorum",
            path: "/api/orchestration/status",
            method: Method::Get,
            category: Category::C3DataGrid,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::HasJsonField("services"),
                Assertion::HasJsonField("quorum"),
                Assertion::HasJsonField("online"),
            ],
        },

        // Panel 7: Chaya Digital Twin
        TestCase {
            name: "Chaya sync has planning and chaya tasks",
            path: "/api/chaya/sync",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::HasJsonField("planning_tasks"),
                Assertion::HasJsonField("chaya_tasks"),
                Assertion::HasJsonField("orphans"),
                Assertion::HasJsonField("mismatches"),
            ],
        },

        // Panel 8: Startup Optimizer
        TestCase {
            name: "Math optimize has waves and DFA",
            path: "/api/math/optimize",
            method: Method::Get,
            category: Category::C6MediaRich,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::HasJsonField("containers"),
                Assertion::HasJsonField("execution_waves"),
                Assertion::HasJsonField("critical_path_ms"),
                Assertion::HasJsonField("dfa_states"),
            ],
        },

        // Cockpit Dark Mode
        TestCase {
            name: "Cockpit nodes has dark cockpit mode",
            path: "/api/cockpit/nodes",
            method: Method::Get,
            category: Category::C6MediaRich,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::HasJsonField("dark_cockpit"),
                Assertion::HasJsonField("nodes"),
                Assertion::HasJsonField("alarms"),
            ],
        },

        // Planning HTML structure
        TestCase {
            name: "Planning has 8 panel selectors",
            path: "/planning",
            method: Method::Get,
            category: Category::C1PageStructure,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("selectPanel"),
                Assertion::ContainsText("task"),
                Assertion::ContainsText("ooda"),
                Assertion::ContainsText("safety"),
                Assertion::ContainsText("enforcer"),
                Assertion::ContainsText("graph"),
                Assertion::ContainsText("orch"),
                Assertion::ContainsText("chaya"),
                Assertion::ContainsText("startup"),
            ],
        },
        TestCase {
            name: "Planning has AG-UI SSE connection",
            path: "/planning",
            method: Method::Get,
            category: Category::AgUi,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("connectSSE"),
                Assertion::ContainsText("EventSource"),
                Assertion::ContainsText("ag-ui"),
            ],
        },
        TestCase {
            name: "Planning has chat input",
            path: "/planning",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("chat-input"),
                Assertion::ContainsText("sendChat"),
            ],
        },
        TestCase {
            name: "Planning has JS panel loader",
            path: "/planning",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("loadAllPanels"),
                Assertion::ContainsText("loadPanel"),
                Assertion::ContainsText("updatePanelFromData"),
            ],
        },
        TestCase {
            name: "Planning has cockpit mode updater",
            path: "/planning",
            method: Method::Get,
            category: Category::C6MediaRich,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("updateCockpitMode"),
                Assertion::ContainsText("cockpitMode"),
            ],
        },
        TestCase {
            name: "Planning has command palette",
            path: "/planning",
            method: Method::Get,
            category: Category::C7AiAdvisory,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("openPalette"),
                Assertion::ContainsText("closePalette"),
                Assertion::ContainsText("filterCommands"),
            ],
        },
        TestCase {
            name: "Planning has detail view handlers",
            path: "/planning",
            method: Method::Get,
            category: Category::C5Interactive,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::ContainsText("showDetail"),
                Assertion::ContainsText("showTaskDetail"),
            ],
        },

        // ── A2UI Domain APIs ────────────────────────────────────────
        TestCase {
            name: "Verification status API",
            path: "/api/verification/status",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Zenoh mesh health API",
            path: "/api/zenoh/health",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Immune system status API",
            path: "/api/immune/status",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Knowledge graph API",
            path: "/api/knowledge/graph",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Podman containers API",
            path: "/api/podman/containers",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "MCP server status API",
            path: "/api/mcp/status",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "KMS catalog API",
            path: "/api/kms/catalog",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Telemetry status API",
            path: "/api/telemetry/status",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Prajna health API",
            path: "/api/prajna/health",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Substrate status API",
            path: "/api/substrate/status",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
        TestCase {
            name: "Metabolic status API",
            path: "/api/metabolic/status",
            method: Method::Get,
            category: Category::A2Ui,
            assertions: vec![
                Assertion::StatusCode(200),
                Assertion::IsValidJson,
            ],
        },
    ]
}

// =============================================================================
// Test Runner
// =============================================================================

fn run_test(client: &Client, base_url: &str, test: &TestCase) -> TestResult {
    // Dispatch on method — currently only GET is used, but Post is wired for future tests.
    let url = format!("{}{}", base_url, test.path);
    let start = Instant::now();

    let send_result = match test.method {
        Method::Get => client.get(&url).timeout(Duration::from_secs(10)).send(),
        Method::Post => client.post(&url).timeout(Duration::from_secs(10)).send(),
    };

    match send_result {
        Ok(resp) => {
            let elapsed = start.elapsed().as_millis() as u64;
            let status_code = resp.status().as_u16();
            let content_type = resp
                .headers()
                .get("content-type")
                .and_then(|v| v.to_str().ok())
                .unwrap_or("")
                .to_string();
            let body = resp.text().unwrap_or_default();

            let mut passed = 0;
            let total = test.assertions.len();

            for assertion in &test.assertions {
                let ok = match assertion {
                    Assertion::StatusCode(expected) => status_code == *expected,
                    Assertion::ContainsText(text) => body.contains(text),
                    Assertion::IsValidJson => serde_json::from_str::<Value>(&body).is_ok(),
                    Assertion::HasJsonField(field) => serde_json::from_str::<Value>(&body)
                        .map(|v| v.get(field).is_some())
                        .unwrap_or(false),
                    Assertion::ResponseTimeMs(max) => elapsed <= *max,
                    Assertion::ContentTypeHtml => content_type.contains("text/html"),
                    Assertion::ContentTypeJson => content_type.contains("application/json"),
                };
                if ok {
                    passed += 1;
                }
            }

            TestResult {
                name: test.name.to_string(),
                path: test.path.to_string(),
                category: test.category,
                status: if passed == total {
                    TestStatus::Pass
                } else {
                    TestStatus::Fail
                },
                response_time_ms: elapsed,
                status_code,
                assertions_passed: passed,
                assertions_total: total,
                error: if passed < total {
                    Some(format!("{}/{} assertions passed", passed, total))
                } else {
                    None
                },
            }
        }
        Err(e) => TestResult {
            name: test.name.to_string(),
            path: test.path.to_string(),
            category: test.category,
            status: TestStatus::Fail,
            response_time_ms: start.elapsed().as_millis() as u64,
            status_code: 0,
            assertions_passed: 0,
            assertions_total: test.assertions.len(),
            error: Some(format!("Connection error: {}", e)),
        },
    }
}

fn category_name(cat: Category) -> &'static str {
    match cat {
        Category::C1PageStructure => "C1:Structure",
        Category::C2StatusBadge => "C2:Status",
        Category::C3DataGrid => "C3:DataGrid",
        Category::C4Timeline => "C4:Timeline",
        Category::C5Interactive => "C5:Interactive",
        Category::C6MediaRich => "C6:Media",
        Category::C7AiAdvisory => "C7:AI",
        Category::C8ActionButton => "C8:Action",
        Category::AgUi => "AG-UI",
        Category::A2Ui => "A2UI/API",
    }
}

fn category_color(cat: Category) -> Color {
    match cat {
        Category::C1PageStructure => Color::Cyan,
        Category::C2StatusBadge => Color::Yellow,
        Category::C3DataGrid => Color::Blue,
        Category::C4Timeline => Color::Magenta,
        Category::C5Interactive => Color::Green,
        Category::C6MediaRich => Color::White,
        Category::C7AiAdvisory => Color::LightCyan,
        Category::C8ActionButton => Color::LightRed,
        Category::AgUi => Color::LightGreen,
        Category::A2Ui => Color::LightBlue,
    }
}

// =============================================================================
// Category Filter
// =============================================================================

fn category_from_str(s: &str) -> Option<Category> {
    match s {
        "C1" => Some(Category::C1PageStructure),
        "C2" => Some(Category::C2StatusBadge),
        "C3" => Some(Category::C3DataGrid),
        "C4" => Some(Category::C4Timeline),
        "C5" => Some(Category::C5Interactive),
        "C6" => Some(Category::C6MediaRich),
        "C7" => Some(Category::C7AiAdvisory),
        "C8" => Some(Category::C8ActionButton),
        "AG-UI" => Some(Category::AgUi),
        "A2UI" => Some(Category::A2Ui),
        _ => None,
    }
}

// =============================================================================
// TUI Rendering
// =============================================================================

fn render_ui(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    results: &[TestResult],
    total: usize,
    running: bool,
    start_time: Instant,
) -> io::Result<()> {
    terminal.draw(|frame| {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(3), // Header
                Constraint::Length(3), // Progress
                Constraint::Length(5), // Summary
                Constraint::Min(10),   // Results table
                Constraint::Length(3), // Footer
            ])
            .split(frame.area());

        // Header
        let elapsed = start_time.elapsed().as_secs_f64();
        let header = Paragraph::new(Line::from(vec![
            Span::styled(
                " C3I BROWSER REGRESSION ",
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::raw(" | "),
            Span::styled(
                format!("{} tests", total),
                Style::default().fg(Color::White),
            ),
            Span::raw(" | "),
            Span::styled(
                format!("{:.1}s elapsed", elapsed),
                Style::default().fg(Color::Cyan),
            ),
            Span::raw(" | "),
            Span::styled(
                if running { "RUNNING..." } else { "COMPLETE" },
                Style::default()
                    .fg(if running { Color::Yellow } else { Color::Green })
                    .add_modifier(Modifier::BOLD),
            ),
        ]))
        .block(Block::default().borders(Borders::ALL).title(" SIL-6 Regression "));
        frame.render_widget(header, chunks[0]);

        // Progress bar
        let done = results.len();
        let ratio = if total > 0 {
            done as f64 / total as f64
        } else {
            0.0
        };
        let passed = results
            .iter()
            .filter(|r| r.status == TestStatus::Pass)
            .count();
        let failed = results
            .iter()
            .filter(|r| r.status == TestStatus::Fail)
            .count();
        let gauge = Gauge::default()
            .block(Block::default().borders(Borders::ALL).title(" Progress "))
            .gauge_style(
                Style::default().fg(if failed > 0 { Color::Red } else { Color::Green }),
            )
            .ratio(ratio)
            .label(format!(
                "{}/{} done | {} pass | {} fail",
                done, total, passed, failed
            ));
        frame.render_widget(gauge, chunks[1]);

        // Category summary
        let categories = [
            Category::C1PageStructure,
            Category::C2StatusBadge,
            Category::C3DataGrid,
            Category::C4Timeline,
            Category::C5Interactive,
            Category::C6MediaRich,
            Category::C7AiAdvisory,
            Category::C8ActionButton,
            Category::AgUi,
            Category::A2Ui,
        ];
        let cat_spans: Vec<Span> = categories
            .iter()
            .map(|cat| {
                let cat_results: Vec<&TestResult> =
                    results.iter().filter(|r| r.category == *cat).collect();
                let cat_pass = cat_results
                    .iter()
                    .filter(|r| r.status == TestStatus::Pass)
                    .count();
                let cat_total = cat_results.len();
                let color = if cat_total == 0 {
                    Color::DarkGray
                } else if cat_pass == cat_total {
                    Color::Green
                } else {
                    Color::Red
                };
                Span::styled(
                    format!(" {}:{}/{} ", category_name(*cat), cat_pass, cat_total),
                    Style::default().fg(color),
                )
            })
            .collect();
        let summary = Paragraph::new(vec![
            Line::from(cat_spans[..5].to_vec()),
            Line::from(cat_spans[5..].to_vec()),
        ])
        .block(Block::default().borders(Borders::ALL).title(" Category Coverage "));
        frame.render_widget(summary, chunks[2]);

        // Results table
        let header_cells = ["#", "Status", "Cat", "Test", "Path", "Code", "Time", "Assert"]
            .iter()
            .map(|h| {
                Cell::from(*h).style(
                    Style::default()
                        .fg(Color::Yellow)
                        .add_modifier(Modifier::BOLD),
                )
            });
        let header_row = Row::new(header_cells).height(1);

        let rows: Vec<Row> = results
            .iter()
            .enumerate()
            .map(|(i, r)| {
                let status_style = match r.status {
                    TestStatus::Pass => Style::default().fg(Color::Green),
                    TestStatus::Fail => Style::default().fg(Color::Red),
                    TestStatus::Running => Style::default().fg(Color::Yellow),
                    TestStatus::Pending => Style::default().fg(Color::DarkGray),
                };
                let status_text = match r.status {
                    TestStatus::Pass => "PASS",
                    TestStatus::Fail => "FAIL",
                    TestStatus::Running => "RUN",
                    TestStatus::Pending => "...",
                };
                Row::new(vec![
                    Cell::from(format!("{:>2}", i + 1)),
                    Cell::from(status_text).style(status_style),
                    Cell::from(category_name(r.category))
                        .style(Style::default().fg(category_color(r.category))),
                    Cell::from(r.name.clone()),
                    Cell::from(r.path.clone()),
                    Cell::from(format!("{}", r.status_code)),
                    Cell::from(format!("{}ms", r.response_time_ms)),
                    Cell::from(format!("{}/{}", r.assertions_passed, r.assertions_total)),
                ])
            })
            .collect();

        let table = Table::new(
            rows,
            [
                Constraint::Length(3),  // #
                Constraint::Length(5),  // Status
                Constraint::Length(13), // Cat
                Constraint::Length(30), // Test
                Constraint::Length(35), // Path
                Constraint::Length(5),  // Code
                Constraint::Length(7),  // Time
                Constraint::Length(7),  // Assert
            ],
        )
        .header(header_row)
        .block(Block::default().borders(Borders::ALL).title(" Test Results "));
        frame.render_widget(table, chunks[3]);

        // Footer
        let footer_text = if running {
            "Running tests... press 'q' to abort"
        } else {
            "Press 'q' to exit | 'r' to re-run"
        };
        let footer = Paragraph::new(Line::from(vec![
            Span::styled(footer_text, Style::default().fg(Color::DarkGray)),
            Span::raw(" | "),
            Span::styled(
                Local::now().format("%Y-%m-%d %H:%M:%S").to_string(),
                Style::default().fg(Color::DarkGray),
            ),
        ]))
        .block(Block::default().borders(Borders::ALL));
        frame.render_widget(footer, chunks[4]);
    })?;
    Ok(())
}

// =============================================================================
// JSON Output
// =============================================================================

fn write_json_output(path: &PathBuf, results: &[TestResult]) -> Result<(), Box<dyn std::error::Error>> {
    let json = serde_json::to_string_pretty(results)?;
    std::fs::write(path, json)?;
    Ok(())
}

// =============================================================================
// Main
// =============================================================================

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    telemetry::init_tracing(cli.verbose);

    if cli.publish_zenoh {
        // Phase 4 stub — Zenoh publishing will be wired in a future iteration.
        println!("[zenoh] publish_zenoh flag set — Zenoh publishing not yet implemented (Phase 4)");
    }

    let all_tests = build_test_suite();

    // Apply category filter if requested.
    let tests: Vec<TestCase> = if let Some(ref cat_str) = cli.category {
        let filter_cat = category_from_str(cat_str)
            .unwrap_or_else(|| panic!("Unknown category: {}", cat_str));
        all_tests
            .into_iter()
            .filter(|t| t.category == filter_cat)
            .collect()
    } else {
        all_tests
    };

    let total = tests.len();

    if cli.headless {
        let results = run_headless(&cli.url, &tests)?;
        if let Some(ref path) = cli.json_output {
            write_json_output(path, &results)?;
        }
        return Ok(());
    }

    // TUI mode
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout());
    let mut terminal = Terminal::new(backend)?;

    let client = Client::new();
    let mut results: Vec<TestResult> = Vec::new();
    let start_time = Instant::now();

    // Initial render
    render_ui(&mut terminal, &results, total, true, start_time)?;

    // Run tests one by one with live TUI updates
    for test in &tests {
        // Check for quit
        if event::poll(Duration::from_millis(10))? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('q') {
                    break;
                }
            }
        }

        let result = run_test(&client, &cli.url, test);
        results.push(result);
        render_ui(&mut terminal, &results, total, true, start_time)?;
    }

    // Final render
    render_ui(&mut terminal, &results, total, false, start_time)?;

    // Wait for quit
    loop {
        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') => break,
                KeyCode::Char('r') => {
                    results.clear();
                    let rerun_start = Instant::now();
                    render_ui(&mut terminal, &results, total, true, rerun_start)?;
                    for test in &tests {
                        let result = run_test(&client, &cli.url, test);
                        results.push(result);
                        render_ui(&mut terminal, &results, total, true, rerun_start)?;
                    }
                    render_ui(&mut terminal, &results, total, false, rerun_start)?;
                }
                _ => {}
            }
        }
    }

    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;

    // Print summary
    let passed = results.iter().filter(|r| r.status == TestStatus::Pass).count();
    let failed = results.iter().filter(|r| r.status == TestStatus::Fail).count();
    println!(
        "\n{} passed, {} failed out of {} tests",
        passed,
        failed,
        results.len()
    );
    if failed > 0 {
        println!("\nFailed tests:");
        for r in results.iter().filter(|r| r.status == TestStatus::Fail) {
            println!(
                "  FAIL {} — {} ({})",
                r.path,
                r.name,
                r.error.as_deref().unwrap_or("unknown")
            );
        }
    }

    if let Some(ref path) = cli.json_output {
        write_json_output(path, &results)?;
    }

    if failed > 0 {
        std::process::exit(1);
    }

    Ok(())
}

fn run_headless(
    base_url: &str,
    tests: &[TestCase],
) -> Result<Vec<TestResult>, Box<dyn std::error::Error>> {
    let client = Client::new();
    let start = Instant::now();
    let mut passed = 0;
    let mut failed = 0;
    let total = tests.len();
    let mut results = Vec::with_capacity(total);

    println!(
        "C3I Browser Regression — {} tests against {}",
        total, base_url
    );
    println!("{}", "=".repeat(80));

    for (i, test) in tests.iter().enumerate() {
        let result = run_test(&client, base_url, test);
        let status = match result.status {
            TestStatus::Pass => {
                passed += 1;
                "\x1b[32mPASS\x1b[0m"
            }
            TestStatus::Fail => {
                failed += 1;
                "\x1b[31mFAIL\x1b[0m"
            }
            _ => "???",
        };
        println!(
            "[{:>2}/{}] {} {:13} {:30} {:35} {}ms {}/{}",
            i + 1,
            total,
            status,
            category_name(result.category),
            result.name,
            result.path,
            result.response_time_ms,
            result.assertions_passed,
            result.assertions_total,
        );
        if let Some(ref err) = result.error {
            println!("        └─ {}", err);
        }
        results.push(result);
    }

    let elapsed = start.elapsed().as_secs_f64();
    println!("{}", "=".repeat(80));
    println!(
        "{} passed, {} failed, {} total in {:.2}s",
        passed, failed, total, elapsed
    );

    if failed > 0 {
        std::process::exit(1);
    }
    Ok(results)
}

// =============================================================================
// Unit Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_suite_has_minimum_tests() {
        let suite = build_test_suite();
        assert!(
            suite.len() >= 40,
            "expected >= 40 tests, got {}",
            suite.len()
        );
    }

    #[test]
    fn test_categories_all_represented() {
        let suite = build_test_suite();
        let all_categories = [
            Category::C1PageStructure,
            Category::C2StatusBadge,
            Category::C3DataGrid,
            Category::C4Timeline,
            Category::C5Interactive,
            Category::C6MediaRich,
            Category::C7AiAdvisory,
            Category::C8ActionButton,
            Category::AgUi,
            Category::A2Ui,
        ];
        for cat in &all_categories {
            let count = suite.iter().filter(|t| t.category == *cat).count();
            assert!(
                count >= 1,
                "category {:?} has no tests in suite",
                category_name(*cat)
            );
        }
    }

    #[test]
    fn test_category_name_exhaustive() {
        // Verify every Category variant maps to a non-empty string.
        let cases = [
            (Category::C1PageStructure, "C1:Structure"),
            (Category::C2StatusBadge, "C2:Status"),
            (Category::C3DataGrid, "C3:DataGrid"),
            (Category::C4Timeline, "C4:Timeline"),
            (Category::C5Interactive, "C5:Interactive"),
            (Category::C6MediaRich, "C6:Media"),
            (Category::C7AiAdvisory, "C7:AI"),
            (Category::C8ActionButton, "C8:Action"),
            (Category::AgUi, "AG-UI"),
            (Category::A2Ui, "A2UI/API"),
        ];
        for (cat, expected) in &cases {
            assert_eq!(category_name(*cat), *expected);
        }
    }

    #[test]
    fn test_category_color_exhaustive() {
        // Verify every Category variant returns a Color without panicking.
        let variants = [
            Category::C1PageStructure,
            Category::C2StatusBadge,
            Category::C3DataGrid,
            Category::C4Timeline,
            Category::C5Interactive,
            Category::C6MediaRich,
            Category::C7AiAdvisory,
            Category::C8ActionButton,
            Category::AgUi,
            Category::A2Ui,
        ];
        for cat in &variants {
            // category_color must not panic for any variant.
            let _ = category_color(*cat);
        }
    }

    #[test]
    fn test_result_serialization() {
        let result = TestResult {
            name: "Test serialization".to_string(),
            path: "/api/health".to_string(),
            category: Category::C2StatusBadge,
            status: TestStatus::Pass,
            response_time_ms: 42,
            status_code: 200,
            assertions_passed: 3,
            assertions_total: 3,
            error: None,
        };

        // Serialize to JSON string.
        let json = serde_json::to_string(&result).expect("serialization must not fail");
        assert!(json.contains("Test serialization"));
        assert!(json.contains("pass"));
        assert!(json.contains("c2_status_badge"));

        // Round-trip: deserialize back.
        let restored: TestResult =
            serde_json::from_str(&json).expect("deserialization must not fail");
        assert_eq!(restored.name, result.name);
        assert_eq!(restored.status_code, 200);
        assert_eq!(restored.assertions_passed, 3);
        assert!(restored.error.is_none());
    }
}
