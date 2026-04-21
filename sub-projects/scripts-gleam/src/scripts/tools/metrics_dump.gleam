//// scripts/tools/metrics_dump — snapshot the in-process metrics NIF state.
////
//// Pairs with `scripts/common/metrics`. Writes `{counters, histograms}` to
//// `data/script-output/tools/metrics_dump/<stamp>/result.json` AND publishes
//// the snapshot on Zenoh `indrajaal/metrics/scripts/_snapshot` with high
//// priority so downstream scrapers can pull an up-to-the-second view.

import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/metrics
import scripts/common/paths
import scripts/common/zenoh

const scope = "tools/metrics_dump"

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "tools/metrics_dump",
    category: mfst.Tools,
    fractal_layer: fractal.L4,
    summary: "Dump in-process counters + histograms; publish to Zenoh for scrapers.",
    inputs: [],
    outputs_schema: "{counters, histograms}",
    retention_days: 7,
    auth_level: mfst.L2Normal,
    sc_id: "SC-SCRIPT-MET-002",
  )
}

pub fn main() -> Nil {
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp)
  let snap = metrics.snapshot()
  let _ =
    zenoh.put_with(
      "indrajaal/metrics/scripts/_snapshot",
      snap,
      zenoh.InteractiveHigh,
      zenoh.Drop,
    )
  case fsx.run_dir("tools", "metrics_dump", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let _ = fsx.write_file(dir, "result.json", snap)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }
}
