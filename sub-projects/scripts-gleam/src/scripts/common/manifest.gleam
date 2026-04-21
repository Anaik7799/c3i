//// scripts/common/manifest — typed script metadata contract.
////
//// SC-SCRIPT-REG-001. Every runnable script MUST export `pub fn manifest() -> Manifest`.
//// The registry tool (`scripts/tools/list`) aggregates these into
//// `data/script-output/_index/registry.json` so the wider system can:
////
////   * enumerate available scripts,
////   * show `--help`-style descriptions,
////   * enforce retention per script (SC-SCRIPT-RET-001),
////   * map scripts to fractal layers + SC-* constraints,
////   * generate A2UI / AG-UI surfaces automatically in future passes.

import gleam/int
import gleam/list
import gleam/string
import scripts/common/fractal

pub type Category {
  Probe
  Build
  Ingest
  Registry
  Verify
  Fractal
  Tls
  Pi
  Drift
  Tools
}

pub fn category_tag(c: Category) -> String {
  case c {
    Probe -> "probe"
    Build -> "build"
    Ingest -> "ingest"
    Registry -> "registry"
    Verify -> "verify"
    Fractal -> "fractal"
    Tls -> "tls"
    Pi -> "pi"
    Drift -> "drift"
    Tools -> "tools"
  }
}

pub type AuthLevel {
  L0Constitutional
  L1Trusted
  L2Normal
}

pub fn auth_tag(a: AuthLevel) -> String {
  case a {
    L0Constitutional -> "l0"
    L1Trusted -> "l1"
    L2Normal -> "l2"
  }
}

pub type FlagSpec {
  FlagSpec(name: String, description: String, default: String, required: Bool)
}

pub type Manifest {
  Manifest(
    name: String,
    category: Category,
    fractal_layer: fractal.Layer,
    summary: String,
    inputs: List(FlagSpec),
    outputs_schema: String,
    retention_days: Int,
    auth_level: AuthLevel,
    sc_id: String,
  )
}

fn input_json(f: FlagSpec) -> String {
  "{\"name\":\"" <> f.name
  <> "\",\"description\":\"" <> escape(f.description)
  <> "\",\"default\":\"" <> escape(f.default)
  <> "\",\"required\":" <> case f.required { True -> "true" False -> "false" }
  <> "}"
}

fn escape(s: String) -> String {
  s
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "\"", with: "\\\"")
}

pub fn to_json(m: Manifest) -> String {
  "{\"name\":\"" <> m.name
  <> "\",\"category\":\"" <> category_tag(m.category)
  <> "\",\"fractal_layer\":\"" <> fractal.layer_tag(m.fractal_layer)
  <> "\",\"summary\":\"" <> escape(m.summary)
  <> "\",\"inputs\":[" <> string.join(list.map(m.inputs, input_json), ",")
  <> "],\"outputs_schema\":\"" <> escape(m.outputs_schema)
  <> "\",\"retention_days\":" <> int.to_string(m.retention_days)
  <> ",\"auth_level\":\"" <> auth_tag(m.auth_level)
  <> "\",\"sc_id\":\"" <> m.sc_id
  <> "\"}"
}

