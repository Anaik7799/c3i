//// scripts/common/args — minimal typed argument parser for gleam-run scripts.
////
//// SC-SCRIPT-GLEAM-001. Not runnable on its own.

import gleam/dict.{type Dict}
import gleam/list
import gleam/string

pub type Args {
  Args(flags: Dict(String, String), booleans: Dict(String, Bool))
}

pub fn new() -> Args {
  Args(flags: dict.new(), booleans: dict.new())
}

/// Parse a CLI argv list into (flags, booleans).
///
///   parse(["--base","http://x","--insecure","--out","/tmp"])
///
/// * `--key value` → flags["key"] = value
/// * `--key` (next starts with `--` or is empty) → booleans["key"] = true
pub fn parse(argv: List(String)) -> Args {
  loop(argv, new())
}

fn loop(argv: List(String), acc: Args) -> Args {
  case argv {
    [] -> acc
    [head, ..rest] ->
      case string.starts_with(head, "--") {
        False -> loop(rest, acc)
        True -> {
          let key = string.drop_start(head, 2)
          case rest {
            [next, ..tail] ->
              case string.starts_with(next, "--") {
                True ->
                  loop(rest, Args(..acc, booleans: dict.insert(acc.booleans, key, True)))
                False ->
                  loop(tail, Args(..acc, flags: dict.insert(acc.flags, key, next)))
              }
            [] ->
              Args(..acc, booleans: dict.insert(acc.booleans, key, True))
          }
        }
      }
  }
}

pub fn flag(a: Args, name: String, default: String) -> String {
  case dict.get(a.flags, name) {
    Ok(v) -> v
    Error(_) -> default
  }
}

pub fn bool(a: Args, name: String) -> Bool {
  case dict.get(a.booleans, name) {
    Ok(v) -> v
    Error(_) -> False
  }
}

pub fn keys(a: Args) -> List(String) {
  let flag_keys = dict.keys(a.flags)
  let bool_keys = dict.keys(a.booleans)
  list.append(flag_keys, bool_keys)
}
