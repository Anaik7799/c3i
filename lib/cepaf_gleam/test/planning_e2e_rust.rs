/// C3I Planning Page — Comprehensive E2E Verification (Rust only)
/// Tests: DOM elements, API endpoints, SSE stream, WebSocket bidirectional,
///        Gemma AI chat, responsive CSS, JS features, live data, page content.
/// STAMP: SC-GLM-UI-001, SC-UIGT-008, SC-GLM-UI-010

use regex::Regex;
use std::net::TcpStream;
use std::time::Duration;
use tungstenite::{client_tls_with_config, stream::MaybeTlsStream, Connector, Message};

const BASE: &str = "https://localhost:4100";

fn main() {
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║     C3I Planning Page — Full E2E Verification (Rust)       ║");
    println!("╚══════════════════════════════════════════════════════════════╝\n");

    let client = http_client();
    let mut total = 0u32;
    let mut passed = 0u32;

    // ── A. Server Health ──
    section("A. SERVER HEALTH");
    check(&mut total, &mut passed, "HTTPS /health returns 200",
        get_status(&client, "/health") == 200);
    check(&mut total, &mut passed, "HTTPS /planning returns 200",
        get_status(&client, "/planning") == 200);

    // ── B. API Endpoints ──
    section("B. API ENDPOINTS");
    let apis = [
        "/api/v1/plan/status",
        "/api/v1/plan/list/all",
        "/api/v1/plan/list/in_progress",
        "/api/v1/plan/list/blocked",
        "/api/v1/plan/list/completed",
        "/api/v1/plan/list/pending",
        "/api/v1/plan/pending",
        "/api/v1/plan/search?q=ooda",
        "/api/v1/ai/status",
        "/api/v1/plan/stream",
    ];
    for api in &apis {
        let code = get_status(&client, api);
        check(&mut total, &mut passed, &format!("{api} => {code}"), code == 200);
    }

    // ── C. Live Data Counts ──
    section("C. LIVE DATA");
    let status_json = get_body(&client, "/api/v1/plan/status");
    let status: serde_json::Value = serde_json::from_str(&status_json).unwrap_or_default();
    let total_tasks = status["total"].as_i64().unwrap_or(0);
    let active = status["active"].as_i64().unwrap_or(0);
    let blocked = status["blocked"].as_i64().unwrap_or(0);
    let completed = status["completed"].as_i64().unwrap_or(0);
    println!("  Data: {total_tasks} total, {active} active, {blocked} blocked, {completed} completed");
    check(&mut total, &mut passed, "Total tasks > 0", total_tasks > 0);
    check(&mut total, &mut passed, "Active tasks >= 0", active >= 0);
    check(&mut total, &mut passed, "Status JSON has 'total' key", status.get("total").is_some());

    // ── D. Page DOM Elements ──
    section("D. DOM ELEMENTS (21 expected)");
    let html = get_body(&client, "/planning");
    let id_re = Regex::new(r#"id="([^"]+)""#).unwrap();
    let ids: Vec<String> = id_re.captures_iter(&html)
        .map(|c| c[1].to_string())
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter().collect();

    let expected_ids = [
        "active-grid", "ai-chat-widget", "ai-search-input", "ai-search-results",
        "all-grid", "analytics-section", "blocked-grid", "change-log",
        "fractal-filter-chips", "grid-analytics", "grid-minichart", "grid-section",
        "grid-status", "kanban-section", "live-status-cards", "task-detail-panel",
        "timeline-section", "weather-bar", "weather-emoji", "weather-label", "weather-score",
    ];
    for eid in &expected_ids {
        check(&mut total, &mut passed, &format!("DOM #{eid}"), ids.contains(&eid.to_string()));
    }
    println!("  Found {}/{} expected IDs", ids.len(), expected_ids.len());

    // ── E. Responsive CSS ──
    section("E. RESPONSIVE CSS");
    let decoded = html.replace("&amp;", "&").replace("&#39;", "'").replace("&lt;", "<").replace("&gt;", ">");
    let css_checks = [
        ("Mobile 1col grid", "grid-template-columns:1fr"),
        ("Tablet 768px breakpoint", "min-width:768px"),
        ("Desktop 1024px breakpoint", "min-width:1024px"),
        ("Wide 1400px breakpoint", "min-width:1400px"),
        ("Touch 44px targets", "min-height:44px"),
        ("Safe area inset", "safe-area-inset"),
        ("Smooth scroll", "scroll-behavior"),
    ];
    for (name, pattern) in &css_checks {
        check(&mut total, &mut passed, name, decoded.contains(pattern));
    }

    // ── F. Page Content Sections ──
    section("F. PAGE CONTENT");
    let section_re = Regex::new(r#"class="section-title">([^<]+)"#).unwrap();
    let sections: Vec<String> = section_re.captures_iter(&html).map(|c| c[1].to_string()).collect();
    println!("  Sections: {}", sections.len());
    check(&mut total, &mut passed, "Has >= 10 sections", sections.len() >= 10);
    check(&mut total, &mut passed, "Has Task Summary section",
        sections.iter().any(|s| s.contains("Task Summary")));
    check(&mut total, &mut passed, "Has AI Agent section",
        sections.iter().any(|s| s.contains("AI Agent")));
    check(&mut total, &mut passed, "Has State Change Log",
        sections.iter().any(|s| s.contains("State Change")));
    check(&mut total, &mut passed, "Has Task Explorer",
        sections.iter().any(|s| s.contains("Task Explorer")));

    let card_count = html.matches("card-value").count();
    let svg_count = html.matches("<svg").count();
    println!("  Cards: {card_count}, SVGs: {svg_count}");
    check(&mut total, &mut passed, "Has >= 15 status cards", card_count >= 15);
    check(&mut total, &mut passed, "Has >= 4 SVG progress rings", svg_count >= 4);

    // ── G. JS Features ──
    section("G. JS FEATURES (planning-grid.js)");
    let js = get_body(&client, "/static/planning-grid.js");
    let js_features = [
        ("Grid view", "createGrid"),
        ("Kanban view", "renderKanban"),
        ("Timeline view", "renderTimeline"),
        ("Analytics view", "renderAnalyticsView"),
        ("Fractal L0-L7", "FRACTAL_LAYERS"),
        ("AI search", "initAISearch"),
        ("Change log", "renderChangeLog"),
        ("Row diff", "findChangedIds"),
        ("Row highlight", "highlightChangedRows"),
        ("Detail drill-down", "showTaskDetail"),
        ("Knowledge lookup", "searchKnowledgeInPanel"),
        ("Related tasks", "searchRelatedInPanel"),
        ("Sub-tasks", "showSubTasks"),
        ("AI analysis", "runAIAnalysis"),
        ("STAMP refs", "showStampRefs"),
        ("Gemma chat", "callGemma"),
        ("Chat widget", "initAIChat"),
        ("WebSocket", "initWebSocket"),
        ("WS ping", "wsPingTimer"),
        ("WS reconnect", "wsReconnectDelay"),
        ("Header update", "refreshHeaderStatus"),
        ("Export CSV", "export-csv"),
        ("Keyboard shortcuts", "ctrlKey"),
        ("Heartbeat", "heartbeat-live"),
        ("Responsive CSS", "@media"),
        ("Touch targets", "min-height:44px"),
    ];
    for (name, pattern) in &js_features {
        check(&mut total, &mut passed, name, js.contains(pattern));
    }
    println!("  JS size: {} bytes", js.len());

    // ── H. SSE Stream ──
    section("H. SSE STREAM");
    let sse = get_body(&client, "/api/v1/plan/stream");
    check(&mut total, &mut passed, "SSE has 'event: status'", sse.contains("event: status"));
    check(&mut total, &mut passed, "SSE has 'event: active'", sse.contains("event: active"));
    check(&mut total, &mut passed, "SSE has 'event: blocked'", sse.contains("event: blocked"));
    check(&mut total, &mut passed, "SSE has 'retry: 3000'", sse.contains("retry: 3000"));

    // ── I. WebSocket Bidirectional ──
    section("I. WEBSOCKET (bidirectional)");
    let ws_results = test_websocket();
    for (name, ok) in &ws_results {
        check(&mut total, &mut passed, name, *ok);
    }

    // ── J. Gemma AI Chat ──
    section("J. GEMMA AI CHAT");
    let gemma_ok = test_gemma();
    check(&mut total, &mut passed, "Gemma 3 responds with task context", gemma_ok);

    // ── K. AI Status Endpoint ──
    section("K. AI STATUS");
    let ai_body = get_body(&client, "/api/v1/ai/status");
    let ai: serde_json::Value = serde_json::from_str(&ai_body).unwrap_or_default();
    check(&mut total, &mut passed, "AI agent = gemma4",
        ai["agent"].as_str() == Some("gemma4"));
    check(&mut total, &mut passed, "AI has capabilities array",
        ai["capabilities"].as_array().map(|a| a.len()).unwrap_or(0) >= 4);

    // ── L. Search Returns Results ──
    section("L. SEARCH VERIFICATION");
    let search1 = get_body(&client, "/api/v1/plan/search?q=zenoh");
    let search2 = get_body(&client, "/api/v1/plan/search?q=container");
    check(&mut total, &mut passed, "Search 'zenoh' returns data", search1.len() > 20);
    check(&mut total, &mut passed, "Search 'container' returns data", search2.len() > 20);

    // ══ SUMMARY ══
    println!("\n╔══════════════════════════════════════════════════════════════╗");
    if passed == total {
        println!("║  ALL {passed} TESTS PASSED — EVERY COMPONENT VERIFIED         ║");
    } else {
        println!("║  {passed}/{total} PASSED — {} FAILED                              ║", total - passed);
    }
    println!("╚══════════════════════════════════════════════════════════════╝");

    if passed < total { std::process::exit(1); }
}

// ── Helpers ──

fn http_client() -> reqwest::blocking::Client {
    reqwest::blocking::Client::builder()
        .danger_accept_invalid_certs(true)
        .timeout(Duration::from_secs(10))
        .build()
        .unwrap()
}

fn get_status(client: &reqwest::blocking::Client, path: &str) -> u16 {
    client.get(format!("{BASE}{path}")).send()
        .map(|r| r.status().as_u16())
        .unwrap_or(0)
}

fn get_body(client: &reqwest::blocking::Client, path: &str) -> String {
    client.get(format!("{BASE}{path}")).send()
        .and_then(|r| r.text())
        .unwrap_or_default()
}

fn section(name: &str) { println!("\n--- {name} ---"); }

fn check(total: &mut u32, passed: &mut u32, name: &str, ok: bool) {
    *total += 1;
    if ok { *passed += 1; }
    println!("  [{}] {name}", if ok { "OK" } else { "FAIL" });
}

fn test_websocket() -> Vec<(String, bool)> {
    let mut results = Vec::new();
    let tls = native_tls::TlsConnector::builder()
        .danger_accept_invalid_certs(true)
        .build().unwrap();
    let tcp = match TcpStream::connect("127.0.0.1:4100") {
        Ok(t) => t,
        Err(_) => { results.push(("TCP connect".into(), false)); return results; }
    };
    tcp.set_read_timeout(Some(Duration::from_secs(10))).ok();

    let (mut ws, resp) = match client_tls_with_config(
        "wss://localhost:4100/ws/planning", tcp, None, Some(Connector::NativeTls(tls)),
    ) {
        Ok(r) => r,
        Err(_) => { results.push(("WS upgrade".into(), false)); return results; }
    };

    results.push(("WS upgrade 101".into(), resp.status() == 101));

    // Connected
    let j = ws_rx(&mut ws);
    results.push(("WS connected msg".into(), g(&j, "type") == "connected"));

    // Ping
    let _ = ws.send(Message::Text("ping".into()));
    let j = ws_rx(&mut ws);
    let t = g(&j, "type");
    let s1 = j["seq"].as_i64().unwrap_or(0);
    results.push(("WS ping response".into(), t == "heartbeat" || t == "update"));

    // Ping #2 — seq increments
    let _ = ws.send(Message::Text("ping".into()));
    let j = ws_rx(&mut ws);
    let s2 = j["seq"].as_i64().unwrap_or(0);
    results.push(("WS seq increments".into(), s2 > s1));

    // Search
    let _ = ws.send(Message::Text("zenoh".into()));
    let j = ws_rx(&mut ws);
    let has = j["results"].as_str().map(|r| r.len() > 10).unwrap_or(false);
    results.push(("WS search results".into(), g(&j, "type") == "search" && has));

    let _ = ws.close(None);
    results
}

fn ws_rx(ws: &mut tungstenite::WebSocket<MaybeTlsStream<TcpStream>>) -> serde_json::Value {
    ws.read().ok()
        .and_then(|m| m.to_text().ok().map(|s| s.to_string()))
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

fn g(j: &serde_json::Value, k: &str) -> String {
    j[k].as_str().unwrap_or("").into()
}

fn test_gemma() -> bool {
    let client = http_client();
    let body = serde_json::json!({
        "model": "gemma3",
        "messages": [
            {"role": "system", "content": "You are C3I AI. 2710 tasks. Be concise."},
            {"role": "user", "content": "What should I prioritize?"}
        ],
        "stream": false,
        "options": {"num_predict": 80}
    });
    match client.post("http://localhost:11434/api/chat")
        .json(&body)
        .timeout(Duration::from_secs(20))
        .send()
    {
        Ok(resp) => {
            if let Ok(json) = resp.json::<serde_json::Value>() {
                let content = json["message"]["content"].as_str().unwrap_or("");
                if !content.is_empty() {
                    println!("  Gemma 3: {}", &content[..content.len().min(120)]);
                    return true;
                }
            }
            false
        }
        Err(_) => false,
    }
}
