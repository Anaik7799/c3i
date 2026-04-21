//// scripts/common/httpx — small HTTP helper for probes.
////
//// SC-SCRIPT-GLEAM-001. Wraps gleam_httpc with a uniform result type.

import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/string

pub type HttpResult {
  HttpResult(code: Int, body: String, ok: Bool, detail: String)
}

pub fn get(url: String) -> HttpResult {
  case request.to(url) {
    Error(_) -> HttpResult(0, "", False, "invalid url: " <> url)
    Ok(req) -> {
      let req = request.set_method(req, http.Get)
      case httpc.send(req) {
        Error(_) -> HttpResult(0, "", False, "send error: " <> url)
        Ok(resp) -> {
          let r: Response(String) = resp
          HttpResult(r.status, r.body, r.status == 200, "ok")
        }
      }
    }
  }
}

/// Check if `want` is a substring of response body; empty `want` = accept anything.
pub fn body_contains(r: HttpResult, want: String) -> Bool {
  case want {
    "" -> True
    s -> string.contains(r.body, s)
  }
}
