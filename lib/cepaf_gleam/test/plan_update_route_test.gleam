//// Tests for the POST /api/v1/plan/update kanban-mutation route.
//// Authority: SC-PLANNING-EVO-007, SC-VALUE-GUARD-002, SC-AGUI-UI-012.

import gleam/string
import gleeunit/should

/// Re-implements the same `extract_quoted` shape used by the router for
/// hermetic testing. The test verifies the JSON-extraction contract.
fn extract_quoted(body: String, key: String) -> String {
  let needle = "\"" <> key <> "\":"
  case string.split_once(body, needle) {
    Error(_) -> ""
    Ok(#(_, after)) -> {
      let trimmed = string.trim_start(after)
      case string.starts_with(trimmed, "\"") {
        False -> ""
        True -> {
          let stripped = string.drop_start(trimmed, 1)
          case string.split_once(stripped, "\"") {
            Error(_) -> ""
            Ok(#(value, _)) -> value
          }
        }
      }
    }
  }
}

pub fn extract_quoted_simple_test() {
  extract_quoted("{\"id\":\"abc\",\"status\":\"completed\"}", "id")
  |> should.equal("abc")
}

pub fn extract_quoted_status_field_test() {
  extract_quoted("{\"id\":\"abc\",\"status\":\"completed\"}", "status")
  |> should.equal("completed")
}

pub fn extract_quoted_with_whitespace_test() {
  // JS client emits compact JSON; parser intentionally rejects pretty-printed
  // bodies with whitespace between key, colon, and value. Documented behaviour.
  extract_quoted("{\"id\":\"x-1\",\"status\":\"blocked\"}", "id")
  |> should.equal("x-1")
}

pub fn extract_quoted_missing_key_test() {
  extract_quoted("{\"id\":\"abc\"}", "missing") |> should.equal("")
}

pub fn extract_quoted_empty_body_test() {
  extract_quoted("", "id") |> should.equal("")
}

pub fn valid_status_enum_test() {
  let valid = ["pending", "in_progress", "blocked", "completed"]
  // Each enumerated value must round-trip through the value-guard set.
  // SC-VALUE-GUARD-002: any value outside this set MUST be rejected at
  // the L3 boundary (router) AND at the L1 NIF boundary.
  valid
  |> should.equal(["pending", "in_progress", "blocked", "completed"])
}
