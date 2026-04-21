//// scripts/tools/retain — delete script-output run directories older than N days.
////
//// SC-SCRIPT-RET-001. Retention is driven by script manifests: each script
//// declares its own `retention_days`. Any run directory whose age exceeds that
//// value is pruned.
////
//// Usage:
////   gleam run -m scripts/tools/retain
////   gleam run -m scripts/tools/retain -- --keep-days-default 30 --dry-run

import argv
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import scripts/common/args as cargs
import scripts/common/fractal
import scripts/common/fsx
import scripts/common/logx
import scripts/common/manifest as mfst
import scripts/common/nif
import scripts/common/paths
import scripts/common/registry_index
import simplifile

const scope = "tools/retain"

pub fn manifest() -> mfst.Manifest {
  mfst.Manifest(
    name: "tools/retain",
    category: mfst.Tools,
    fractal_layer: fractal.L4,
    summary: "Prune run directories older than each script's manifest.retention_days.",
    inputs: [
      mfst.FlagSpec(
        "keep-days-default",
        "Fallback retention when no manifest is found",
        "30",
        False,
      ),
      mfst.FlagSpec("dry-run", "Show what would be deleted without touching fs", "false", False),
    ],
    outputs_schema: "{stamp,dry_run,default_days,pruned:[{path,age_days}],kept:[{path,age_days}]}",
    retention_days: 7,
    auth_level: mfst.L2Normal,
    sc_id: "SC-SCRIPT-RET-001",
  )
}

fn all_manifests() -> List(mfst.Manifest) {
  // registry_index.all() carries every entry except list (which imports us).
  // That's fine for retention purposes.
  [manifest(), ..registry_index.all()]
}

fn retention_for(manifests: List(mfst.Manifest), relative_name: String, default_days: Int) -> Int {
  // relative_name example: "probe/public_interface"
  case list.find(manifests, fn(m) { m.name == relative_name }) {
    Ok(m) -> m.retention_days
    Error(_) -> default_days
  }
}

fn ns_to_days(ns: Int) -> Int {
  // 86_400_000_000_000 ns / day
  case ns < 86_400_000_000_000 {
    True -> 0
    False -> ns / 86_400_000_000_000
  }
}

pub fn main() -> Nil {
  let a = cargs.parse(argv.load().arguments)
  let dry =
    case cargs.bool(a, "dry-run") {
      True -> True
      False -> False
    }
  let default_days_s = cargs.flag(a, "keep-days-default", "30")
  let default_days = result.unwrap(int.parse(default_days_s), 30)
  let stamp = logx.stamp()
  logx.info(
    scope,
    "start stamp=" <> stamp
      <> " dry_run=" <> case dry { True -> "true" False -> "false" }
      <> " default_days=" <> int.to_string(default_days),
  )

  let now_ns = nif.now_nanos()
  let root = paths.output_root()
  let manifests = all_manifests()

  // Enumerate categories (first level under root) and names (second level).
  let categories = read_dir_or_empty(root)
  let mut_pruned = prune_walk(categories, root, manifests, now_ns, default_days, dry)

  let summary =
    "{\"stamp\":\"" <> stamp
      <> "\",\"dry_run\":" <> case dry { True -> "true" False -> "false" }
      <> ",\"default_days\":" <> int.to_string(default_days)
      <> ",\"pruned\":" <> int.to_string(mut_pruned.pruned_count)
      <> ",\"kept\":" <> int.to_string(mut_pruned.kept_count) <> "}"

  case fsx.run_dir("tools", "retain", stamp) {
    Error(e) -> logx.error(scope, "run_dir: " <> e)
    Ok(dir) -> {
      let _ = fsx.write_file(dir, "result.json", summary)
      let _ = fsx.write_file(dir, "stdout.log", summary <> "\n")
      logx.info(scope, "outputs " <> paths.join(dir, "result.json"))
    }
  }

  logx.info(scope, "SUMMARY " <> summary)
  Nil
}

pub type Counts {
  Counts(pruned_count: Int, kept_count: Int)
}

fn prune_walk(
  categories: List(String),
  root: String,
  manifests: List(mfst.Manifest),
  now_ns: Int,
  default_days: Int,
  dry: Bool,
) -> Counts {
  list.fold(categories, Counts(0, 0), fn(acc, cat) {
    case cat == "_index" {
      True -> acc
      False -> {
        let cat_dir = root <> "/" <> cat
        let names = read_dir_or_empty(cat_dir)
        list.fold(names, acc, fn(inner, name) {
          let name_dir = cat_dir <> "/" <> name
          let stamps = read_dir_or_empty(name_dir)
          let keep_days = retention_for(manifests, cat <> "/" <> name, default_days)
          list.fold(stamps, inner, fn(st_acc, s) {
            let full = name_dir <> "/" <> s
            let age_days = age_of(full, now_ns)
            case age_days > keep_days {
              True -> {
                logx.info(
                  scope,
                  "  PRUNE " <> full <> " age=" <> int.to_string(age_days)
                    <> "d keep=" <> int.to_string(keep_days) <> "d",
                )
                case dry {
                  True -> Nil
                  False -> {
                    let _ = simplifile.delete_all([full])
                    Nil
                  }
                }
                Counts(st_acc.pruned_count + 1, st_acc.kept_count)
              }
              False -> {
                Counts(st_acc.pruned_count, st_acc.kept_count + 1)
              }
            }
          })
        })
      }
    }
  })
}

fn age_of(path: String, now_ns: Int) -> Int {
  // simplifile.file_info gives seconds since epoch; approximate age in days.
  case simplifile.file_info(path) {
    Ok(info) -> {
      let mtime_ns = info.mtime_seconds * 1_000_000_000
      ns_to_days(now_ns - mtime_ns)
    }
    Error(_) -> 0
  }
}

fn read_dir_or_empty(p: String) -> List(String) {
  case simplifile.read_directory(p) {
    Ok(v) -> v
    Error(_) -> []
  }
}

// Silence unused-import warnings — `string` is pulled in for potential future
// formatting helpers.
fn unused_stub() -> String {
  string.lowercase("")
}
