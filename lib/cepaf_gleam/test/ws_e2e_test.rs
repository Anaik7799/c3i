use std::net::TcpStream;
use tungstenite::stream::MaybeTlsStream;
use tungstenite::{client_tls_with_config, Connector, Message};

fn main() {
    println!("=== C3I WebSocket E2E Test (Rust) ===\n");

    let tls = native_tls::TlsConnector::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .unwrap();

    let tcp = TcpStream::connect("127.0.0.1:4100").unwrap();
    tcp.set_read_timeout(Some(std::time::Duration::from_secs(10))).ok();

    let (mut ws, resp) = client_tls_with_config(
        "wss://localhost:4100/ws/planning",
        tcp,
        None,
        Some(Connector::NativeTls(tls)),
    )
    .expect("WS connect failed");

    let p1 = resp.status() == 101;
    println!("1. UPGRADE: {} -- {}", resp.status(), p(p1));

    let j = rx(&mut ws);
    let p2 = g(&j, "type") == "connected";
    println!("2. CONNECTED: type={} -- {}", g(&j, "type"), p(p2));
    println!("   status: {}", &g(&j, "status")[..g(&j, "status").len().min(80)]);

    ws.send(Message::Text("ping".into())).unwrap();
    let j = rx(&mut ws);
    let t = g(&j, "type");
    let s1 = j["seq"].as_i64().unwrap_or(0);
    let p3 = t == "heartbeat" || t == "update";
    println!("3. PING: type={} seq={} -- {}", t, s1, p(p3));

    ws.send(Message::Text("ping".into())).unwrap();
    let j = rx(&mut ws);
    let s2 = j["seq"].as_i64().unwrap_or(0);
    let p4 = s2 > s1;
    println!("4. PING #2: seq={} -- {}", s2, p(p4));

    ws.send(Message::Text("zenoh".into())).unwrap();
    let j = rx(&mut ws);
    let has = j["results"].as_str().map(|r| r.len() > 10).unwrap_or(false);
    let p5 = g(&j, "type") == "search" && g(&j, "query") == "zenoh" && has;
    println!("5. SEARCH: query={} results={} -- {}", g(&j, "query"), has, p(p5));

    ws.send(Message::Text("blocked".into())).unwrap();
    let j = rx(&mut ws);
    let has2 = j["results"].as_str().map(|r| r.len() > 10).unwrap_or(false);
    let p6 = has2;
    println!("6. SEARCH #2: query='blocked' results={} -- {}", has2, p(p6));

    ws.close(None).ok();
    let n = [p1, p2, p3, p4, p5, p6].iter().filter(|x| **x).count();
    println!(
        "\n=== {} -- {}/6 passed ===",
        if n == 6 { "ALL PASSED" } else { "SOME FAILED" },
        n
    );
    if n < 6 {
        std::process::exit(1);
    }
}

fn rx(ws: &mut tungstenite::WebSocket<MaybeTlsStream<TcpStream>>) -> serde_json::Value {
    ws.read()
        .ok()
        .and_then(|m| m.to_text().ok().map(|s| s.to_string()))
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}
fn g(j: &serde_json::Value, k: &str) -> String {
    j[k].as_str().unwrap_or("").into()
}
fn p(v: bool) -> &'static str {
    if v { "PASS" } else { "FAIL" }
}
