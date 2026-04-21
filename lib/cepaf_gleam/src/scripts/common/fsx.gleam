//// scripts/common/fsx — filesystem helpers for gleam-run scripts.
////
//// SC-SCRIPT-GLEAM-001. Uses `simplifile` for clean Result semantics.
//// Scripts MUST write outputs under `data/script-output/<category>/<name>/<stamp>/`.

import gleam/result
import simplifile
import scripts/common/paths

fn err_to_string(_: simplifile.FileError) -> String {
  "fs error"
}

/// Ensure a directory path exists (recursive).
pub fn ensure_dir(p: String) -> Result(Nil, String) {
  case simplifile.is_directory(p) {
    Ok(True) -> Ok(Nil)
    _ ->
      simplifile.create_directory_all(p)
      |> result.map_error(err_to_string)
  }
}

/// Prepare the run directory for a script invocation and return its path.
///
///   run_dir("probe", "public_interface", "20260421-100000")
///   → "/<root>/data/script-output/probe/public_interface/20260421-100000"
pub fn run_dir(category: String, name: String, stamp: String) -> Result(String, String) {
  let dir = paths.output_dir(category, name, stamp)
  use _ <- result.try(ensure_dir(dir))
  use _ <- result.try(ensure_dir(dir <> "/artifacts"))
  Ok(dir)
}

/// Write a UTF-8 string to `<dir>/<file>`; creates parent dirs.
pub fn write_file(dir: String, file: String, body: String) -> Result(Nil, String) {
  use _ <- result.try(ensure_dir(dir))
  let full = dir <> "/" <> file
  simplifile.write(to: full, contents: body)
  |> result.map_error(err_to_string)
}
