//// scripts_gleam — host module for the c3i gleam-only script application.
////
//// STAMP: SC-SCRIPT-GLEAM-001
////
//// This package exists *only* to host runnable scripts under `scripts/`
//// and shared helpers under `scripts/common/`. It is fully isolated from
//// `cepaf_gleam`, `planning_daemon`, `pi-mono`, and every other system
//// service — deliberately so new script work can proceed without any risk
//// of breaking the main application.
////
//// Runnable scripts are invoked as:
////
////     cd sub-projects/scripts-gleam
////     gleam run -m scripts/<category>/<name> -- [--arg value ...]

import gleam/io

/// Printed when someone runs the package with no module; directs them to the
/// canonical CLI form.
pub fn main() -> Nil {
  io.println(
    "scripts_gleam — use `gleam run -m scripts/<category>/<name>`\n"
    <> "Canonical tree: sub-projects/scripts-gleam/src/scripts/{probe,build,ingest,registry,verify,fractal,tls,pi,drift}\n"
    <> "See README.md + src/scripts/README.md for conventions.",
  )
}
