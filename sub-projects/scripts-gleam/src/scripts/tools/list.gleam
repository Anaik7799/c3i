//// scripts/tools/list — enumerate every runnable script and its manifest.
////
//// SC-SCRIPT-REG-002. Writes a single aggregated index at
//// `data/script-output/_index/registry.json` in addition to the per-run dir.
////
//// Usage:
////   gleam run -m scripts/tools/list

import gleam/int
import gleam/list
import gleam/string
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/paths
import scripts/common/registry_index
import scripts/tools/retain

const scope = "tools/list"

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "tools/list",
    category: mfst.Tools,
    fractal_layer: fractal.L4,
    summary: "Enumerate every runnable script + aggregate manifests into registry.json.",
    inputs: [],
    outputs_schema: "{generated_at, count, scripts:[Manifest]}",
    retention_days: 7,
    auth_level: mfst.L2Normal,
    sc_id: "SC-SCRIPT-REG-002",
  )
}

fn all_manifests() -> List(mfst.Manifest) {
  // Pull the canonical list from the registry_index module, plus the two
  // tools (list + retain) that would otherwise create an import cycle.
  [manifest(), retain.manifest(), ..registry_index.all()]
}

pub fn main() -> Nil {
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp)
  let ms = all_manifests()

  let body =
    "{\"generated_at\":\"" <> stamp <> "\""
    <> ",\"count\":" <> int.to_string(list.length(ms))
    <> ",\"scripts\":[" <> string.join(list.map(ms, mfst.to_json), ",")
    <> "]}"

  // 1) per-run output
  case fsx.run_dir("tools", "list", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let _ = fsx.write_file(dir, "result.json", body)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  // 2) aggregated index for the whole system (SC-SCRIPT-REG-002).
  let idx = paths.output_root() <> "/_index"
  let _ = fsx.ensure_dir(idx)
  let _ = fsx.write_file(idx, "registry.json", body)
  logx.info(scope, "index " <> idx <> "/registry.json")

  list.each(ms, fn(m) {
    logx.info(
      scope,
      "  "
        <> m.name
        <> "  ("
        <> mfst.category_tag(m.category)
        <> ", "
        <> fractal.layer_tag(m.fractal_layer)
        <> ", retain="
        <> int.to_string(m.retention_days)
        <> "d)",
    )
  })
  logx.info(scope, "total=" <> int.to_string(list.length(ms)))
}
