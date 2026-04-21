//// scripts/common/mcp — typed MCP-over-Zenoh client.
////
//// SC-SCRIPT-GLEAM-001 + pi-mono symbiosis (Pi is the default MCP host).
//// Publishes requests to `indrajaal/mcp/request/<tool>` and awaits the
//// reply on a unique `indrajaal/mcp/reply/scripts/<uuid>` topic, all through
//// the process-wide Zenoh session held by the `scripts_nif` Rust NIF.

import scripts/common/nif

pub type McpError {
  Timeout
  CallFailed(String)
}

/// Invoke an MCP tool. `args_json` must be a valid JSON object.
/// Returns the raw reply payload (typically JSON).
pub fn invoke(
  tool: String,
  args_json: String,
  timeout_ms: Int,
) -> Result(String, McpError) {
  let #(_, body) = nif.mcp_invoke_moz(tool, args_json, timeout_ms)
  case body {
    "" -> Error(CallFailed("empty reply"))
    s -> Ok(s)
  }
}
