//// scripts/common/smriti — typed Smriti (system memory) access.
////
//// SC-SCRIPT-GLEAM-001. Uses the `scripts_nif` Rust NIF (rusqlite bundled)
//// so there is zero coupling to cepaf_gleam's `esqlite` NIF or to any other
//// subsystem. The NIF opens the SQLite file directly.
////
//// Default DB path: `sub-projects/c3i/planning.db` (override via
//// `SCRIPTS_SMRITI_DB` env or explicit argument).

import envoy
import scripts/common/nif

/// Resolve the Smriti DB path, honouring env override.
///
/// The authoritative DB path, as used by `sa-plan` and `planning_daemon::db`,
/// is `sub-projects/c3i/data/smriti/Smriti.db` under the c3i workspace root.
/// All paths stay within `/home/an/dev/ver/c3i/` per project rule.
pub fn default_db_path() -> String {
  case envoy.get("SCRIPTS_SMRITI_DB") {
    Ok(p) -> p
    Error(_) -> {
      let root = case envoy.get("C3I_REPO_ROOT") {
        Ok(v) -> v
        Error(_) -> "/home/an/dev/ver/c3i"
      }
      root <> "/sub-projects/c3i/data/smriti/Smriti.db"
    }
  }
}

/// Read a Smriti preference. Returns `Ok(value)` or `Error(Nil)` if absent.
pub fn get_pref(key: String) -> Result(String, Nil) {
  let #(_, r) = nif.smriti_get_pref(default_db_path(), key)
  case r {
    "" -> Error(Nil)
    s -> Ok(s)
  }
}

/// Write a Smriti preference into a category.
pub fn set_pref(category: String, key: String, value: String) -> String {
  let #(_, msg) = nif.smriti_set_pref(default_db_path(), category, key, value)
  msg
}

/// Read a task row as JSON.
pub fn get_task(id: String) -> Result(String, Nil) {
  let #(_, r) = nif.smriti_get_task(default_db_path(), id)
  case r {
    "" -> Error(Nil)
    s -> Ok(s)
  }
}

/// JSON snapshot of the Smriti connection pool (open connections + paths).
pub fn pool_stats() -> String {
  let #(_, s) = nif.smriti_pool_stats()
  s
}
