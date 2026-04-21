//// scripts/common/validate — typed I/O schema validation.
////
//// Addresses scalability dimension #10 (typed I/O schema). Validates:
////   * CLI args against a script's manifest.inputs (required flags present)
////   * A JSON result blob against a sketched `outputs_schema` (keys exist)
////
//// The sketch is deliberately minimal — we treat `outputs_schema` as a list
//// of comma/space-separated top-level key names rather than a full JSON-Schema
//// parser. This keeps the hard rule (no shell / no external schema tooling)
//// intact while still rejecting common drift.

import gleam/list
import gleam/string
import scripts/common/args as cargs
import scripts/common/errors
import scripts/common/manifest as mfst

/// Check that every `required: True` flag in the manifest is present.
pub fn inputs(m: mfst.Manifest, a: cargs.Args) -> Result(Nil, errors.ScriptError) {
  let required = list.filter(m.inputs, fn(f) { f.required })
  let missing =
    list.filter_map(required, fn(f) {
      case cargs.flag(a, f.name, "") {
        "" -> Ok(f.name)
        _ -> Error(Nil)
      }
    })
  case missing {
    [] -> Ok(Nil)
    xs ->
      Error(errors.ConfigError(
        "missing required flag(s): " <> string.join(xs, ","),
      ))
  }
}

/// Extract top-level key tokens from an `outputs_schema` string of the shape
/// "{key1, key2, key3:[...], ...}". Non-alphanumeric characters are skipped.
fn schema_keys(schema: String) -> List(String) {
  // Rough parser: split on commas, trim braces, colons, spaces.
  schema
  |> string.replace(each: "{", with: "")
  |> string.replace(each: "}", with: "")
  |> string.split(on: ",")
  |> list.map(fn(p) {
    let trimmed = string.trim(p)
    case string.split_once(trimmed, on: ":") {
      Ok(#(k, _)) -> string.trim(k)
      Error(_) -> trimmed
    }
  })
  |> list.filter(fn(k) { k != "" })
}

/// Check that every top-level key the schema advertises appears at least once
/// in the produced JSON text. Does not parse — substring-checks only so it
/// cannot spuriously reject well-formed variants.
pub fn outputs(
  m: mfst.Manifest,
  result_json: String,
) -> Result(Nil, errors.ScriptError) {
  let keys = schema_keys(m.outputs_schema)
  let missing =
    list.filter(keys, fn(k) { !string.contains(result_json, "\"" <> k <> "\"") })
  case missing {
    [] -> Ok(Nil)
    xs ->
      Error(errors.Permanent(
        "output missing expected keys: " <> string.join(xs, ","),
      ))
  }
}
