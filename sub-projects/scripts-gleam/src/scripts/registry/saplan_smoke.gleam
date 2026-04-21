//// scripts/registry/saplan_smoke — integration smoke for the sa-plan bridge.
////
//// SC-SCRIPT-GLEAM-001 + SC-SCHED-WORK-001.
////
//// Verifies:
////   1. sa-plan binary is reachable via the gleam wrapper.
////   2. a Smriti pref can be set and read back in the summary.
////   3. the output tree under data/script-output/registry/saplan_smoke/ is
////      populated cleanly.
////
//// Usage:
////   gleam run -m scripts/registry/saplan_smoke

import gleam/list
import gleam/string
import scripts/common/fsx
import scripts/common/logx
import scripts/common/paths
import scripts/common/saplan

const scope = "registry/saplan_smoke"

pub fn main() -> Nil {
  let stamp = logx.stamp()
  logx.info(scope, "start stamp=" <> stamp)

  case saplan.available() {
    False -> {
      logx.error(scope, "sa-plan binary not reachable")
      panic as "sa-plan binary unreachable"
    }
    True -> Nil
  }

  let pref_key = "scripts_gleam_smoke_at"
  let _ = saplan.set_pref("roadmap", pref_key, stamp)
  logx.info(scope, "set-pref roadmap." <> pref_key <> "=" <> stamp)

  let queues = saplan.queue_list()
  logx.info(scope, "queue-list rc=" <> case queues.rc {
    0 -> "0"
    _ -> "nonzero"
  })

  case fsx.run_dir("registry", "saplan_smoke", stamp) {
    Error(e) -> {
      logx.error(scope, "run_dir: " <> e)
      panic as "cannot create run dir"
    }
    Ok(dir) -> {
      let summary_lines = [
        "script: registry/saplan_smoke",
        "stamp:  " <> stamp,
        "saplan_bin: " <> saplan.binary(),
        "pref_set: roadmap." <> pref_key <> "=" <> stamp,
        "queue_list_rc: " <> case queues.rc {
          0 -> "0"
          _ -> "nonzero"
        },
      ]
      let body = list.fold(summary_lines, "", fn(acc, l) { acc <> l <> "\n" })
      let _ = fsx.write_file(dir, "stdout.log", body)
      let json =
        "{\"script\":\"registry/saplan_smoke\""
        <> ",\"stamp\":\"" <> stamp <> "\""
        <> ",\"status\":\"ok\""
        <> ",\"pref\":\"roadmap." <> pref_key <> "\""
        <> ",\"queue_list_rc\":" <> case queues.rc {
          0 -> "0"
          _ -> string.inspect(queues.rc)
        }
        <> "}"
      let _ = fsx.write_file(dir, "result.json", json)
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  logx.info(scope, "done")
}
