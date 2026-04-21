//// scripts/common/guardian — L0 constitutional approval gate.
////
//// Addresses scalability dimension #6 (security & safety). Before any script
//// performs a privileged act (destructive write, L0 change, external
//// publication, credential use), it MUST call `guardian.approve(scope, reason)`
//// which sends an MCP-over-Zenoh request to the Guardian and awaits a binary
//// decision.
////
//// In dev environments where no Guardian is online, the default timeout of
//// 3 seconds results in `Error(Denied(...))` — the safe default (deny-on-silence).

import scripts/common/errors.{type ScriptError}
import scripts/common/mcp

pub type Decision {
  Approved(reason: String)
  Rejected(reason: String)
}

/// Request Guardian approval for a named scope + reason. The MCP tool is
/// `guardian.approve`; if a Guardian is registered it will respond with a
/// payload beginning with `approved|` or `rejected|`. All other responses
/// are treated as rejection.
pub fn approve(
  scope: String,
  reason: String,
  timeout_ms: Int,
) -> Result(Decision, ScriptError) {
  let args =
    "{\"scope\":\"" <> scope <> "\",\"reason\":\"" <> reason <> "\"}"
  case mcp.invoke("guardian.approve", args, timeout_ms) {
    Error(mcp.Timeout) ->
      Error(errors.Denied("guardian silent after " <> integer(timeout_ms) <> "ms — safe default = deny"))
    Error(mcp.CallFailed(d)) -> Error(errors.Denied("guardian call failed: " <> d))
    Ok(body) -> classify(body)
  }
}

fn classify(body: String) -> Result(Decision, ScriptError) {
  case body {
    "approved|" <> rest -> Ok(Approved(rest))
    "rejected|" <> rest -> Ok(Rejected(rest))
    _ -> Ok(Rejected("unrecognized guardian response: " <> body))
  }
}

@external(erlang, "erlang", "integer_to_binary")
fn integer(n: Int) -> String
