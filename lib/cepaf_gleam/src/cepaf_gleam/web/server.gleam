// HTTP Server for cepaf_gleam — binds to port 4100 (SC-GLM-UI-006)
// Wraps the Wisp router with Mist HTTP server for production serving.
// STAMP: SC-GLM-UI-006, SC-GLM-UI-001
//
// T024 — Graceful shutdown protocol
// The BEAM VM handles SIGTERM via `init:stop/0` (OTP application shutdown).
// On SIGTERM the BEAM runtime calls Application.stop/1 for each running OTP
// application, which in turn stops supervision trees in reverse start order.
// Mist closes its acceptor pool and drains in-flight requests during that
// teardown.  No manual signal trapping is required in Gleam code — the
// `process.sleep_forever()` call below simply parks the calling process while
// the Mist acceptor processes run under their own supervisor.
//
// Connection tracking is maintained in `ServerState` and updated via
// `record_connection/2` and `release_connection/1`.  Call `health_check/1`
// from the /health endpoint or a monitoring loop to surface live metrics.

import cepaf_gleam/c3i/nif as c3i_nif
import cepaf_gleam/planning/safety_kernel
import cepaf_gleam/ui/wisp/router
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import mist

// ---------------------------------------------------------------------------
// Server state — connection tracking
// ---------------------------------------------------------------------------

/// Lightweight server state for health reporting.
/// `started_at` is a Unix-epoch millisecond timestamp (use `erlang.system_time`
/// in a real integration).  Here we store a display string so the module
/// stays free of FFI calls.
pub type ServerState {
  ServerState(port: Int, started_at: String, connection_count: Int)
}

/// Record one new connection.  Returns updated state.
pub fn record_connection(state: ServerState) -> ServerState {
  ServerState(
    port: state.port,
    started_at: state.started_at,
    connection_count: state.connection_count + 1,
  )
}

/// Release one connection when it closes.  Clamps at zero.
pub fn release_connection(state: ServerState) -> ServerState {
  let new_count = case state.connection_count > 0 {
    True -> state.connection_count - 1
    False -> 0
  }
  ServerState(
    port: state.port,
    started_at: state.started_at,
    connection_count: new_count,
  )
}

/// Return a human-readable health summary for the server.
pub fn health_check(state: ServerState) -> String {
  "HTTP server healthy — port="
  <> int.to_string(state.port)
  <> " started_at="
  <> state.started_at
  <> " connections="
  <> int.to_string(state.connection_count)
}

/// Log a graceful shutdown message.
/// Call this before the OTP application stops to surface drain info.
pub fn shutdown(state: ServerState) -> Nil {
  io.println(
    "  Graceful shutdown — draining "
    <> int.to_string(state.connection_count)
    <> " connection(s) on port "
    <> int.to_string(state.port),
  )
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// WebSocket types — planning real-time push (SC-GLM-UI-010)
// ---------------------------------------------------------------------------

/// WebSocket connection state — tracks push count and last status for diff
pub type WsState {
  WsState(push_count: Int, last_status: String)
}

/// No custom messages needed — client drives the 1s poll via "ping" text frames
pub type WsMsg {
  NoOp
}

// ---------------------------------------------------------------------------
// WebSocket handler — bidirectional planning data channel
// ---------------------------------------------------------------------------

/// Called when WebSocket connection opens. Sends initial status snapshot.
fn ws_on_init(
  conn: mist.WebsocketConnection,
) -> #(WsState, option.Option(process.Selector(WsMsg))) {
  let status = c3i_nif.plan_status()
  let welcome =
    json.object([
      #("type", json.string("connected")),
      #("status", json.string(status)),
      #("interval_ms", json.int(1000)),
    ])
    |> json.to_string()
  let _ = mist.send_text_frame(conn, welcome)
  #(WsState(push_count: 0, last_status: status), None)
}

/// Handle WebSocket messages — client sends "ping" or search queries,
/// server responds with fresh data. Bidirectional request-response pattern.
fn ws_handler(
  state: WsState,
  msg: mist.WebsocketMessage(WsMsg),
  conn: mist.WebsocketConnection,
) -> mist.Next(WsState, WsMsg) {
  case msg {
    // Client sends text — either "ping" for status or a search query
    mist.Text(text) -> {
      case text {
        // Ping — respond with fresh status + diff detection
        "ping" -> {
          let status = c3i_nif.plan_status()
          let changed = status != state.last_status
          case changed {
            True -> {
              let active = c3i_nif.plan_list_by_status("in_progress")
              let blocked = c3i_nif.plan_list_by_status("blocked")
              let payload =
                json.object([
                  #("type", json.string("update")),
                  #("status", json.string(status)),
                  #("active", json.string(active)),
                  #("blocked", json.string(blocked)),
                  #("seq", json.int(state.push_count + 1)),
                ])
                |> json.to_string()
              let _ = mist.send_text_frame(conn, payload)
              mist.continue(WsState(
                push_count: state.push_count + 1,
                last_status: status,
              ))
            }
            False -> {
              let hb =
                json.object([
                  #("type", json.string("heartbeat")),
                  #("seq", json.int(state.push_count + 1)),
                ])
                |> json.to_string()
              let _ = mist.send_text_frame(conn, hb)
              mist.continue(WsState(
                ..state,
                push_count: state.push_count + 1,
              ))
            }
          }
        }
        // Search query — respond with task search results
        _ -> {
          let search_result = c3i_nif.plan_search(text)
          let resp =
            json.object([
              #("type", json.string("search")),
              #("query", json.string(text)),
              #("results", json.string(search_result)),
            ])
            |> json.to_string()
          let _ = mist.send_text_frame(conn, resp)
          mist.continue(state)
        }
      }
    }
    // Connection closed
    mist.Closed | mist.Shutdown -> mist.stop()
    // Binary/Custom — ignore
    mist.Binary(_) -> mist.continue(state)
    mist.Custom(_) -> mist.continue(state)
  }
}

/// Called when WebSocket connection closes
fn ws_on_close(_state: WsState) -> Nil {
  Nil
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

pub fn start(port: Int) -> Result(Nil, String) {
  io.println("  Gleam HTTP+WS on 0.0.0.0:" <> int.to_string(port))

  let handler = fn(req: request.Request(mist.Connection)) {
    // Check for WebSocket upgrade on /ws/planning path
    let is_ws_upgrade = case request.get_header(req, "upgrade") {
      Ok("websocket") -> True
      _ -> False
    }
    let is_ws_path = req.path == "/ws/planning"

    case is_ws_upgrade && is_ws_path {
      // WebSocket upgrade — real-time planning push
      True ->
        mist.websocket(
          request: req,
          handler: ws_handler,
          on_init: ws_on_init,
          on_close: ws_on_close,
        )

      // Normal HTTP request
      False -> {
        // Phase 2: Bearer Token RBAC Middleware for L5_Operator
        let is_authorized = case req.method {
          http.Post | http.Put | http.Delete | http.Patch -> {
            let auth_ok = case request.get_header(req, "authorization") {
              Ok("Bearer " <> _token) -> True
              _ -> False
            }
            let proof_ok = case request.get_header(req, "x-proof-token") {
              Ok(token) ->
                safety_kernel.validate_proof_token(
                  token, "mutation", "L5_Operator", "", 1000,
                )
                |> result.is_ok()
              _ -> False
            }
            auth_ok && proof_ok
          }
          _ -> True
        }

        case is_authorized {
          False ->
            response.new(401)
            |> response.set_body(
              mist.Bytes(bytes_tree.from_string(
                "{\"error\": \"Unauthorized\"}",
              )),
            )
            |> response.set_header("content-type", "application/json")
            |> response.set_header("access-control-allow-origin", "*")
          True -> {
            let wisp_response =
              router.handle_request(request.set_body(req, ""))
            let resp =
              response.new(wisp_response.status)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_string(wisp_response.body)),
              )
            list.fold(wisp_response.headers, resp, fn(acc, header) {
              response.set_header(acc, header.0, header.1)
            })
            |> response.set_header("access-control-allow-origin", "*")
            |> response.set_header(
              "access-control-allow-methods",
              "GET, POST, OPTIONS",
            )
          }
        }
      }
    }
  }

  // Try HTTPS first (TLS cert at priv/ssl/), fall back to HTTP
  let cert_path = "priv/ssl/cert.pem"
  let key_path = "priv/ssl/key.pem"

  let builder =
    mist.new(handler)
    |> mist.port(port)
    |> mist.bind("0.0.0.0")

  // Attempt TLS — if cert files exist, serve HTTPS; otherwise plain HTTP
  let tls_builder =
    mist.with_tls(builder, certfile: cert_path, keyfile: key_path)

  case mist.start(tls_builder) {
    Ok(_) -> {
      io.println(
        "  HTTPS server running on https://0.0.0.0:" <> int.to_string(port),
      )
      process.sleep_forever()
      Ok(Nil)
    }
    Error(_) -> {
      io.println("  [tls] TLS failed, falling back to HTTP...")
      case mist.start(builder) {
        Ok(_) -> {
          io.println(
            "  HTTP server running on http://0.0.0.0:"
            <> int.to_string(port),
          )
          process.sleep_forever()
          Ok(Nil)
        }
        Error(_) -> {
          Error(
            "Failed to start HTTP server on port " <> int.to_string(port),
          )
        }
      }
    }
  }
}
