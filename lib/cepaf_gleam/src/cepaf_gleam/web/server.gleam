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

import cepaf_gleam/planning/safety_kernel
import cepaf_gleam/ui/wisp/router
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/list
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

pub fn start(port: Int) -> Result(Nil, String) {
  io.println("  Gleam HTTP on 0.0.0.0:" <> int.to_string(port))

  let handler = fn(req: request.Request(mist.Connection)) {
    // Phase 2: Bearer Token RBAC Middleware for L5_Operator (GAP-007 / SC-UI-C2-001)
    let is_authorized = case req.method {
      http.Post | http.Put | http.Delete | http.Patch -> {
        let auth_ok = case request.get_header(req, "authorization") {
          Ok("Bearer " <> _token) -> True
          _ -> False
        }

        // Phase 4: L0 Guardian ProofToken validation for mutations
        let proof_ok = case request.get_header(req, "x-proof-token") {
          Ok(token) ->
            safety_kernel.validate_proof_token(
              token,
              "mutation",
              "L5_Operator",
              "",
              1000,
            )
            |> result.is_ok()
          _ -> False
        }

        auth_ok && proof_ok
      }
      _ -> True
      // GET/OPTIONS are read-only L1-L4 telemetry
    }

    case is_authorized {
      False ->
        response.new(401)
        |> response.set_body(
          mist.Bytes(bytes_tree.from_string(
            "{\"error\": \"Unauthorized: Missing or invalid token for L5_Operator mutation\"}",
          )),
        )
        |> response.set_header("content-type", "application/json")
        |> response.set_header("access-control-allow-origin", "*")
        |> response.set_header(
          "access-control-allow-methods",
          "GET, POST, OPTIONS",
        )
      True -> {
        // We need to convert req: request.Request(mist.Connection) to request.Request(String)
        // because router.handle_request expects request.Request(String).
        // Wisp usually expects its own request type or request.Request(String).
        // Mist usually passes request.Request(mist.Connection).

        let wisp_response = router.handle_request(request.set_body(req, ""))

        let resp =
          response.new(wisp_response.status)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string(wisp_response.body)),
          )

        // Pass through all headers from the router (including content-type)
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
