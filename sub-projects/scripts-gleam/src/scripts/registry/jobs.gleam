/// Self-describing manifest of all gleam-run jobs registered with sa-plan.
/// Per [zk-a4b982bfc2557082] manifest/0 self-describing pattern.
/// Each entry can be enqueued via:
///   sa-plan job-enqueue --worker gleam_run --args '{"module":"<module_path>"}'

import gleam/io
import gleam/json
import gleam/list
import gleam/string

pub type JobEntry {
  JobEntry(
    id: String,
    module_path: String,
    description: String,
    cron: String,
    priority: Int,
    tags: List(String),
  )
}

pub fn manifest() -> List(JobEntry) {
  [
    JobEntry(
      id: "marionette_health_10m",
      module_path: "scripts/verify/marionette_health",
      description: "Marionette MCP 55-gate Jidoka validator",
      cron: "*/10 * * * *",
      priority: 1,
      tags: ["marionette", "jidoka", "verify"],
    ),
    JobEntry(
      id: "cpig_validator_hourly",
      module_path: "scripts/verify/cpig_validator",
      description: "CPIG drift detector — informational gate audit",
      cron: "0 * * * *",
      priority: 1,
      tags: ["cpig", "drift", "verify"],
    ),
  ]
}

pub fn lookup(id: String) -> Result(JobEntry, Nil) {
  list.find(manifest(), fn(e) { e.id == id })
}

fn encode_entry(e: JobEntry) -> json.Json {
  json.object([
    #("id", json.string(e.id)),
    #("module_path", json.string(e.module_path)),
    #("description", json.string(e.description)),
    #("cron", json.string(e.cron)),
    #("priority", json.int(e.priority)),
    #("tags", json.array(e.tags, json.string)),
  ])
}

pub fn main() -> Nil {
  let entries = manifest()
  let lines =
    list.map(entries, fn(e) { json.to_string(encode_entry(e)) })
  io.println("[")
  let with_comma =
    list.index_map(lines, fn(line, i) {
      case i < list.length(lines) - 1 {
        True -> "  " <> line <> ","
        False -> "  " <> line
      }
    })
  list.each(with_comma, io.println)
  io.println("]")
  let _ = string.length("ok")
  Nil
}
