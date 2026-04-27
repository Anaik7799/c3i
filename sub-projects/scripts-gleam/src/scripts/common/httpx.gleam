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
/// GET that works for binary bodies too (PNG, PDF, etc). Returns byte
/// length in `r.body_bytes` via encoding to base64 — but simpler: return an
/// empty `body` field and the real size in `detail`.
pub fn head(url: String, timeout_ms: Int) -> HttpResult {
  case request.to(url) {
    Error(_) -> HttpResult(0, "", False, "invalid url: " <> url)
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Get)
      let cfg =
        httpc.configure()
        |> httpc.timeout(timeout_ms)
      case httpc.dispatch_bits(cfg, request.set_body(req, <<>>)) {
        Error(_) -> HttpResult(0, "", False, "send error: " <> url)
        Ok(resp) -> {
          let r: Response(BitArray) = resp
          let size = bit_size(r.body) / 8
          HttpResult(
            r.status,
            "",
            r.status >= 200 && r.status < 300,
            int_to_string(size) <> " bytes",
          )
        }
      }
    }
  }
}

@external(erlang, "erlang", "bit_size")
fn bit_size(bits: BitArray) -> Int

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String

/// POST a body string to `url` (Content-Type: application/json, 30 s timeout).
pub fn post(url: String, body: String) -> HttpResult {
  post_with_timeout(url, body, 30_000)
}

/// POST with a caller-supplied timeout in milliseconds.
pub fn post_with_timeout(url: String, body: String, timeout_ms: Int) -> HttpResult {
  case request.to(url) {
    Error(_) -> HttpResult(0, "", False, "invalid url: " <> url)
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_body(body)
      let cfg =
        httpc.configure()
        |> httpc.timeout(timeout_ms)
      case httpc.dispatch(cfg, req) {
        Error(_) -> HttpResult(0, "", False, "send error: " <> url)
        Ok(resp) -> {
          let r: Response(String) = resp
          HttpResult(r.status, r.body, r.status >= 200 && r.status < 300, "ok")
        }
      }
    }
  }
}

pub fn body_contains(r: HttpResult, want: String) -> Bool {
  case want {
    "" -> True
    s -> string.contains(r.body, s)
  }
}
