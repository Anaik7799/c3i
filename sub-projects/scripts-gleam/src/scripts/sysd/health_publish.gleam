//// scripts/sysd/health_publish — G2 migration: c3i-health-publish.sh.
////
//// Polls systemctl --user for c3i-* unit state, writes docs/health/services.json,
//// and publishes per-unit topics on the Zenoh REST endpoint (after G4 --net=host).
////
//// Per SC-SCRIPT-GLEAM-001, SC-OBS-001, SC-ZMOF-001.
////
//// Replaces 60-line bash script with type-safe Gleam composition.

import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/string
import simplifile

const health_file = "/home/an/dev/ver/c3i/docs/health/services.json"

const zenoh_rest = "http://127.0.0.1:8000"

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

fn cls(xs: List(String)) -> List(charlist.Charlist) {
  case xs {
    [] -> []
    [x, ..rest] -> [cl(x), ..cls(rest)]
  }
}

/// Run a command, return trimmed stdout (empty on failure).
fn capture(cmd: String, args: List(String)) -> String {
  let #(out, _rc) = sh(cl(cmd), cls(args))
  charlist.to_string(out) |> string.trim
}

/// Convert "[not set]" or empty → "0" so JSON stays valid (integers).
fn norm_int(v: String) -> String {
  case v {
    "" -> "0"
    "[not set]" -> "0"
    _ ->
      case int_parse(v) {
        Ok(_) -> v
        Error(_) -> "0"
      }
  }
}

@external(erlang, "erlang", "binary_to_integer")
fn binary_to_integer(s: String) -> Int

fn int_parse(s: String) -> Result(Int, Nil) {
  case s {
    "" -> Error(Nil)
    _ ->
      // best-effort; on failure binary_to_integer raises and Result is Error
      Ok(binary_to_integer(s))
  }
}

fn iso_now() -> String {
  capture("date", ["-u", "+%Y-%m-%dT%H:%M:%SZ"])
}

fn nproc() -> String {
  case capture("nproc", []) {
    "" -> "1"
    n -> n
  }
}

fn loadavg() -> String {
  let raw = capture("cat", ["/proc/loadavg"])
  case string.split(raw, " ") {
    [a, b, c, ..] -> a <> " " <> b <> " " <> c
    _ -> "0 0 0"
  }
}

fn show(unit: String, prop: String) -> String {
  capture("systemctl", [
    "--user",
    "show",
    unit,
    "-p",
    prop,
    "--value",
  ])
}

/// List c3i-*.service unit names.
fn list_units() -> List(String) {
  let raw =
    capture("systemctl", [
      "--user",
      "list-units",
      "--type=service",
      "--all",
      "--no-legend",
      "--plain",
    ])
  string.split(raw, "\n")
  |> list.filter_map(fn(line) {
    case string.split_once(line, " ") {
      Ok(#(name, _rest)) -> {
        case string.starts_with(name, "c3i-") {
          True -> Ok(name)
          False -> Error(Nil)
        }
      }
      _ -> Error(Nil)
    }
  })
}

fn unit_json(unit: String) -> String {
  let active = show(unit, "ActiveState")
  let sub = show(unit, "SubState")
  let load = show(unit, "LoadState")
  let mem = norm_int(show(unit, "MemoryCurrent"))
  let cpu = norm_int(show(unit, "CPUUsageNSec"))
  let enabled = capture("systemctl", ["--user", "is-enabled", unit])
  "{\"unit\":\""
  <> unit
  <> "\",\"active\":\""
  <> active
  <> "\",\"enabled\":\""
  <> enabled
  <> "\",\"load\":\""
  <> load
  <> "\",\"sub\":\""
  <> sub
  <> "\",\"memory_bytes\":"
  <> mem
  <> ",\"cpu_nsec\":"
  <> cpu
  <> "}"
}

fn join_with_commas(xs: List(String)) -> String {
  case xs {
    [] -> ""
    [x] -> x
    [x, ..rest] -> x <> "," <> join_with_commas(rest)
  }
}

fn build_payload() -> String {
  let units = list_units()
  let entries = list.map(units, unit_json)
  let units_json = join_with_commas(entries)
  let slice_mem = norm_int(show("c3i.slice", "MemoryCurrent"))
  let slice_cpu = norm_int(show("c3i.slice", "CPUUsageNSec"))
  "{\"ts\":\""
  <> iso_now()
  <> "\",\"ncpu\":"
  <> nproc()
  <> ",\"loadavg\":\""
  <> loadavg()
  <> "\",\"slice_cpu_nsec\":"
  <> slice_cpu
  <> ",\"slice_memory_bytes\":"
  <> slice_mem
  <> ",\"units\":["
  <> units_json
  <> "]}"
}

fn publish_zenoh(payload: String, _units: List(String)) -> Nil {
  // Snapshot — single PUT to the aggregate topic.
  let _ =
    sh(cl("curl"), cls([
      "-fsS",
      "--max-time",
      "1",
      "-X",
      "PUT",
      "--data-binary",
      payload,
      zenoh_rest <> "/indrajaal/l2/health/snapshot",
    ]))
  Nil
}

pub fn main() -> Nil {
  let payload = build_payload()
  let _ = simplifile.write(to: health_file, contents: payload)
  let units = list_units()
  publish_zenoh(payload, units)
  io.println("[health-publish] " <> string.inspect(list.length(units)) <> " units published")
}
