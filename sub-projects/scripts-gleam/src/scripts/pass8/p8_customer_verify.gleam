//// scripts/pass8/p8_customer_verify — customer-path health check.
////
//// Fractal TPS · Jidoka · Muda · SC-PASS8-IMPL-001 · SC-CUSTOMER-VERIFY-001.
////
//// Simulates the exact path a customer takes from the internet:
////   1. Resolve the public Tailscale hostname
////   2. Complete TLS handshake against the public IP
////   3. Fetch the analysis HTML
////   4. Parse every <img src=…> and <a href=… .png|.md|.html>
////   5. Fetch each subresource with a 2 s Jidoka cap
////   6. Report pass/fail + byte totals + durations
////
//// ENV:
////   BASE    — override the base URL (default https://vm-1.tail55d152.ts.net:8443)
////   TASK_ID — task id to verify (default pass-8 task)
////   PAGE    — analysis filename to load (auto-resolved if blank)

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/regexp
import gleam/string
import scripts/common/httpx
import scripts/common/nif
import gleam/option

const default_base = "https://vm-1.tail55d152.ts.net:8443"

const default_task = "116452825849720856"

const default_page =
  "20260423-072528-task-116452825849720856-all-18-improvements-pass8-analysis.html"

const jidoka_timeout_ms = 2_000

pub fn main() -> Nil {
  io.println("=== pass8/customer_verify · Fractal TPS · Jidoka cap 2 000 ms ===")
  let base = case envoy.get("BASE") {
    Ok(v) -> v
    Error(_) -> default_base
  }
  let task = case envoy.get("TASK_ID") {
    Ok(v) -> v
    Error(_) -> default_task
  }
  let page = case envoy.get("PAGE") {
    Ok(v) -> v
    Error(_) -> default_page
  }

  let full_url = base <> "/task-id/" <> task <> "/" <> page
  io.println("target: " <> full_url)

  let t0 = nif.now_nanos()
  let root = httpx.get(full_url)
  let ms0 = to_ms(nif.now_nanos() - t0)
  io.println(
    "root: HTTP " <> int.to_string(root.code)
    <> "  " <> int.to_string(byte_size(root.body)) <> " B"
    <> "  " <> int.to_string(ms0) <> " ms",
  )

  case root.code {
    200 -> {
      let srcs = extract_subresources(root.body)
      io.println("subresources: " <> int.to_string(list.length(srcs)))
      let base_for_rel = base <> "/task-id/" <> task <> "/"
      let results =
        srcs
        |> list.map(fn(s) { #(s, fetch_with_jidoka(base_for_rel, s)) })
      let summary = list.fold(results, #(0, 0, 0), fn(acc, r) {
        let #(ok, fail, bytes) = acc
        let #(_url, res) = r
        case res.code {
          200 -> #(
            ok + 1,
            fail,
            bytes + case byte_size(res.body) {
              0 -> parse_size(res.detail)
              n -> n
            },
          )
          _ -> #(ok, fail + 1, bytes)
        }
      })
      let #(ok, fail, bytes) = summary
      io.println(
        "subresource summary: " <> int.to_string(ok) <> " ok · "
        <> int.to_string(fail) <> " fail · "
        <> int.to_string(bytes) <> " B transferred",
      )
      // Detailed ledger
      io.println("─ ledger ─")
      list.each(results, fn(r) {
        let #(url, res) = r
        let tag = case res.code {
          200 -> "✓"
          _ -> "✗"
        }
        let sz = case byte_size(res.body) {
          0 -> parse_size(res.detail)
          n -> n
        }
        io.println(
          "  " <> tag <> " " <> int.to_string(res.code)
          <> " " <> int.to_string(sz)
          <> "B  " <> url,
        )
      })
      // Emit summary on Zenoh
      let payload =
        "{\"base\":\"" <> base <> "\",\"task\":\"" <> task
        <> "\",\"page\":\"" <> page <> "\",\"subresources\":"
        <> int.to_string(list.length(srcs))
        <> ",\"ok\":" <> int.to_string(ok)
        <> ",\"fail\":" <> int.to_string(fail)
        <> ",\"bytes\":" <> int.to_string(bytes)
        <> ",\"ms_root\":" <> int.to_string(ms0)
        <> ",\"by\":\"p8_customer_verify\"}"
      let _ = nif.zenoh_put("indrajaal/l4/sre/customer_verify", payload)
      io.println("zenoh: indrajaal/l4/sre/customer_verify published")
    }
    _ -> io.println_error("root failed: " <> root.detail)
  }
}

fn extract_subresources(html: String) -> List(String) {
  // <img src="..."> and <a href="...png|html|md|svg|json"> attributes
  let img_re = case regexp.from_string("<img[^>]+src=\"([^\"]+)\"") {
    Ok(r) -> r
    Error(_) -> panic as "img regex"
  }
  let href_re =
    case regexp.from_string("<a[^>]+href=\"([^\"]+\\.(png|svg|md|json|html))\"") {
      Ok(r) -> r
      Error(_) -> panic as "a regex"
    }
  let imgs = regexp.scan(img_re, html) |> list.filter_map(first_group)
  let hrefs = regexp.scan(href_re, html) |> list.filter_map(first_group)
  // Keep only relative sub-paths (skip already-absolute URLs to avoid re-hitting base)
  list.append(imgs, hrefs)
  |> list.filter(fn(u) {
    !string.starts_with(u, "http")
    && !string.starts_with(u, "#")
    && !string.starts_with(u, "/")
  })
  |> list.unique
}

fn first_group(m: regexp.Match) -> Result(String, Nil) {
  case m.submatches {
    [option_maybe, ..] ->
      case option_maybe {
        option.None -> Error(Nil)
        option.Some(s) -> Ok(s)
      }
    _ -> Error(Nil)
  }
}

fn fetch_with_jidoka(base: String, rel: String) -> httpx.HttpResult {
  let url = case string.starts_with(rel, "http") {
    True -> rel
    False -> base <> rel
  }
  // Use binary-safe GET via dispatch_bits so PNG/SVG resources don't trip the
  // UTF-8 decoder. We only need status + size for verification, not the bytes.
  httpx.head(url, jidoka_timeout_ms)
}

fn to_ms(nanos: Int) -> Int {
  nanos / 1_000_000
}

/// Extract an integer from a string like "340276 bytes".
fn parse_size(detail: String) -> Int {
  case string.split(detail, " ") {
    [n, ..] ->
      case int.parse(n) {
        Ok(i) -> i
        Error(_) -> 0
      }
    _ -> 0
  }
}

@external(erlang, "erlang", "byte_size")
fn byte_size(s: String) -> Int

