//// `doctor` — print environment diagnostics: tool versions, PATH, CWD, OS.
//// Pure logic is in `diagnose/0`; the IO edge is `run/1`.

import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout

pub type Tool {
  Tool(name: String, version_arg: String)
}

pub type Report {
  Report(
    user: String,
    cwd: String,
    path_entries: Int,
    tools: List(#(Tool, Result(String, String))),
  )
}

const tracked_tools: List(Tool) = [
  Tool("gleam", "--version"),
  Tool(
    "erl",
    "-eval \"erlang:display(erlang:system_info(otp_release)), halt().\" -noshell",
  ),
  Tool("rebar3", "--version"),
  Tool("elixir", "--version"),
  Tool("rustc", "--version"),
  Tool("cargo", "--version"),
  Tool("node", "--version"),
  Tool("pnpm", "--version"),
  Tool("nix", "--version"),
  Tool("git", "--version"),
]

pub fn run(_args: List(String)) -> Result(Nil, Nil) {
  let report = diagnose()
  render(report) |> io.println
  Ok(Nil)
}

pub fn diagnose() -> Report {
  let user = envoy.get("USER") |> result.unwrap("<unknown>")
  let cwd = case shellout.command(run: "pwd", with: [], in: ".", opt: []) {
    Ok(out) -> string.trim(out)
    Error(_) -> "<unknown>"
  }
  let path_entries =
    envoy.get("PATH")
    |> result.unwrap("")
    |> string.split(on: ":")
    |> list.filter(fn(s) { s != "" })
    |> list.length

  let tools =
    tracked_tools
    |> list.map(fn(t) { #(t, probe(t)) })

  Report(user:, cwd:, path_entries:, tools:)
}

fn probe(tool: Tool) -> Result(String, String) {
  // shellout splits on spaces, so pass version_arg through `sh -c` to respect
  // embedded quotes (needed for the `erl -eval "..."` incantation).
  let cmd = tool.name <> " " <> tool.version_arg <> " 2>&1"
  case shellout.command(run: "bash", with: ["-c", cmd], in: ".", opt: []) {
    Ok(out) -> Ok(string.trim(out))
    Error(#(_code, err)) -> Error(string.trim(err))
  }
}

pub fn render(report: Report) -> String {
  let header =
    [
      "sys doctor",
      "  user        : " <> report.user,
      "  cwd         : " <> report.cwd,
      "  PATH entries: " <> int.to_string(report.path_entries),
      "",
      "tools:",
    ]
    |> string.join("\n")

  let rows =
    report.tools
    |> list.map(fn(pair) {
      let #(tool, result) = pair
      let label = string.pad_end(tool.name, to: 10, with: " ")
      case result {
        Ok(v) -> "  OK   " <> label <> " " <> truncate(v, 60)
        Error(_) -> "  MISS " <> label
      }
    })
    |> string.join("\n")

  header <> "\n" <> rows
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}
