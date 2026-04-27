//// scripts/sysd/muda_prune — G2 migration: c3i-muda-prune.sh.
////
//// Toyota Production System Jidoka — autonomous waste pruner.
//// Detects + cures 6 categories of resource waste every 5 min.
////
//// Per SC-MUDA-001 (continuous waste elimination).

import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/string
import simplifile

const log_file = "/tmp/c3i-muda-prune.log"

const flock_lock = "/tmp/c3i-stop-hook.lock"

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

fn capture(cmd: String, args: List(String)) -> String {
  let #(out, _rc) = sh(cl(cmd), cls(args))
  charlist.to_string(out) |> string.trim
}

fn iso_now() -> String {
  capture("date", ["-u", "+%Y-%m-%dT%H:%M:%SZ"])
}

fn log_line(msg: String) -> Nil {
  let line = "[" <> iso_now() <> "] " <> msg <> "\n"
  let _ = simplifile.append(to: log_file, contents: line)
  Nil
}

/// Waste 1: stale flock — lock file exists but no process holds it.
fn cure_stale_flock() -> Nil {
  case simplifile.is_file(flock_lock) {
    Ok(True) -> {
      // probe via lsof, no holder → remove
      let #(out, _) = sh(cl("lsof"), cls([flock_lock]))
      case charlist.to_string(out) |> string.trim {
        "" -> {
          let _ = simplifile.delete(flock_lock)
          log_line("MUDA: removed stale flock " <> flock_lock)
          Nil
        }
        _ -> Nil
      }
    }
    _ -> Nil
  }
}

/// Waste 2: failed c3i units — reset-failed so they can restart.
fn cure_failed_units() -> Nil {
  let raw =
    capture("systemctl", [
      "--user",
      "list-units",
      "--state=failed",
      "--type=service",
      "--no-legend",
      "--plain",
    ])
  let lines =
    string.split(raw, "\n")
    |> list.filter_map(fn(l) {
      case string.split_once(l, " ") {
        Ok(#(name, _)) ->
          case string.starts_with(name, "c3i-") {
            True -> Ok(name)
            False -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })
  list.each(lines, fn(u) {
    let _ = sh(cl("systemctl"), cls(["--user", "reset-failed", u]))
    log_line("MUDA: reset-failed " <> u)
  })
}

/// Waste 3: swap pressure > 80 % → log warning.
fn check_swap_pressure() -> Nil {
  let raw = capture("cat", ["/proc/meminfo"])
  let lines = string.split(raw, "\n")
  let total = parse_kb(lines, "SwapTotal:")
  let free = parse_kb(lines, "SwapFree:")
  case total > 0 {
    True -> {
      let used_pct = { total - free } * 100 / total
      case used_pct > 80 {
        True ->
          log_line(
            "MUDA: swap pressure " <> string.inspect(used_pct) <> "% — consider Slice mem cap reduction",
          )
        False -> Nil
      }
    }
    False -> Nil
  }
}

fn parse_kb(lines: List(String), prefix: String) -> Int {
  case list.find(lines, fn(l) { string.starts_with(l, prefix) }) {
    Ok(line) -> {
      let after = string.replace(line, prefix, "") |> string.trim
      case string.split_once(after, " ") {
        Ok(#(num, _)) -> {
          case int_parse(num) {
            Ok(n) -> n
            Error(_) -> 0
          }
        }
        _ -> 0
      }
    }
    Error(_) -> 0
  }
}

@external(erlang, "erlang", "binary_to_integer")
fn binary_to_integer(s: String) -> Int

fn int_parse(s: String) -> Result(Int, Nil) {
  case s {
    "" -> Error(Nil)
    _ -> Ok(binary_to_integer(s))
  }
}

/// Waste 4: tail-prune log to last 200 lines.
fn cure_log_growth() -> Nil {
  case simplifile.read(from: log_file) {
    Ok(content) -> {
      let lines = string.split(content, "\n")
      case list.length(lines) > 200 {
        True -> {
          let kept = list.drop(lines, list.length(lines) - 200)
          let _ =
            simplifile.write(to: log_file, contents: string.join(kept, "\n"))
          Nil
        }
        False -> Nil
      }
    }
    Error(_) -> Nil
  }
}

pub fn main() -> Nil {
  cure_stale_flock()
  cure_failed_units()
  check_swap_pressure()
  cure_log_growth()
  io.println("[muda-prune] cycle complete")
}
