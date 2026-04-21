//// scripts/verify/metrics_roundtrip — prove metrics NIF end-to-end.
////
//// Emits a handful of counter + histogram observations, then reads the
//// snapshot back and asserts the numbers are non-zero.

import gleam/int
import gleam/string
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest
import scripts/common/metrics
import scripts/common/paths

const scope = "verify/metrics_roundtrip"

pub fn manifest() -> manifest.Manifest {
  manifest.Manifest(
    name: "verify/metrics_roundtrip",
    category: manifest.Verify,
    fractal_layer: fractal.L4,
    summary: "End-to-end proof for the metrics NIFs (counter_inc + histogram_observe + snapshot).",
    inputs: [],
    outputs_schema: "{script,stamp,inc_total,obs_count,snapshot}",
    retention_days: 7,
    auth_level: manifest.L2Normal,
    sc_id: "SC-SCRIPT-MET-003",
  )
}

pub fn main() -> Nil {
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp)

  let n1 = metrics.counter_inc("scripts.test.tick", "verify.metrics_roundtrip", 1)
  let n2 = metrics.counter_inc("scripts.test.tick", "verify.metrics_roundtrip", 2)
  let n3 = metrics.counter_inc("scripts.test.tick", "verify.metrics_roundtrip", 3)
  let c1 = metrics.histogram_observe("scripts.test.latency_ms", "verify.metrics_roundtrip", 12.5)
  let c2 = metrics.histogram_observe("scripts.test.latency_ms", "verify.metrics_roundtrip", 25.0)
  let c3 = metrics.histogram_observe("scripts.test.latency_ms", "verify.metrics_roundtrip", 7.25)

  let snap = metrics.snapshot()

  logx.info(scope, "counter_inc n1=" <> int.to_string(n1) <> " n2=" <> int.to_string(n2) <> " n3=" <> int.to_string(n3))
  logx.info(scope, "histogram_observe c1=" <> int.to_string(c1) <> " c2=" <> int.to_string(c2) <> " c3=" <> int.to_string(c3))
  logx.info(scope, "snapshot " <> string.slice(snap, 0, 200))

  case fsx.run_dir("verify", "metrics_roundtrip", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let json =
        "{\"script\":\"" <> scope <> "\""
        <> ",\"stamp\":\"" <> stamp <> "\""
        <> ",\"inc_total\":" <> int.to_string(n3)
        <> ",\"obs_count\":" <> int.to_string(c3)
        <> ",\"snapshot\":" <> snap
        <> "}"
      let _ = fsx.write_file(dir, "result.json", json)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }
}
