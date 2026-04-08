//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/podman/uds_client</module></identity>
////   <fractal-topology><layer>L4_SYSTEM</layer></fractal-topology>
////   <compliance><stamp-controls>SC-CNT-001, SC-CU-001</stamp-controls></compliance>
//// </c3i-module>
////
//// Gleam Podman UDS Client (Biomorphic Motor Control).
//// Connects directly to /run/podman/podman.sock via Erlang :gen_tcp local.

import gleam/bit_array
import gleam/dynamic
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import gleam/result

pub type PodmanConnection {
  PodmanConnection(socket_path: String)
}

/// Create a new connection to the local Podman UDS.
pub fn new(path: String) -> PodmanConnection {
  PodmanConnection(socket_path: path)
}

/// Execute a raw HTTP request over the UDS.
/// Note: Podman API is REST over UDS.
pub fn request(
  conn: PodmanConnection,
  method: String,
  path: String,
  body: String,
) -> Result(String, String) {
  // Use FFI to perform the actual UDS byte stream exchange
  uds_http_call(conn.socket_path, method, path, body)
}

@external(erlang, "cepaf_gleam_ffi", "podman_uds_request")
fn uds_http_call(
  path: String,
  method: String,
  endpoint: String,
  body: String,
) -> Result(String, String)

/// Higher-level: List containers via UDS.
pub fn list_containers(conn: PodmanConnection) -> Result(json.Json, String) {
  case request(conn, "GET", "/v5.0.0/libpod/containers/json", "") {
    Ok(resp) -> Ok(json.string(resp)) // In production, parse actual JSON
    Error(e) -> Error(e)
  }
}
