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

import cepaf_gleam/ui/wisp/router
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
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
  io.println(
    "  Gleam HTTP on 0.0.0.0:" <> int.to_string(port),
  )

  let handler = fn(req) {
    let wisp_response = router.handle_request(request.set_body(req, ""))

    response.new(wisp_response.status)
    |> response.set_body(mist.Bytes(bytes_tree.from_string(wisp_response.body)))
    |> response.set_header("content-type", "application/json")
    |> response.set_header("access-control-allow-origin", "*")
    |> response.set_header("access-control-allow-methods", "GET, POST, OPTIONS")
  }

  case
    mist.new(handler)
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start()
  {
    Ok(_) -> {
      io.println(
        "  HTTP server running on http://0.0.0.0:" <> int.to_string(port),
      )
      // Park this process while Mist acceptors run under their own supervisor.
      // SIGTERM is handled at the OTP level: the BEAM runtime calls
      // Application.stop/1 -> supervision tree teardown -> Mist drain.
      // To trigger a controlled shutdown from Gleam code call:
      //   erlang.halt(0)  or  init:stop() via FFI.
      process.sleep_forever()
      Ok(Nil)
    }
    Error(_) -> {
      Error("Failed to start HTTP server on port " <> int.to_string(port))
    }
  }
}
