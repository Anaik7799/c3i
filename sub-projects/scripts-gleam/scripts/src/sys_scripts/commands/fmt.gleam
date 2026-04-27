//// `fmt` — format every source tree in the workspace.
//// Currently: gleam. Extend per language as they appear in the repo.

import gleam/io
import shellout

pub fn run(_args: List(String)) -> Result(Nil, Nil) {
  io.println("formatting gleam sources in scripts/")
  case
    shellout.command(
      run: "gleam",
      with: ["format", "src", "test"],
      in: ".",
      opt: [],
    )
  {
    Ok(out) -> {
      io.println(out)
      Ok(Nil)
    }
    Error(#(_code, err)) -> {
      io.println_error(err)
      Error(Nil)
    }
  }
}
