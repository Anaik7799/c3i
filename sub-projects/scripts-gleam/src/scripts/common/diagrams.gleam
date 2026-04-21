//// scripts/common/diagrams — reusable graphviz-DOT → PNG + canned diagrams.
////
//// Each runnable script that wants diagrams can call `render_png(…)` directly
//// with its own DOT source, or reuse the canned builders (`fractal_topology`,
//// `data_plane`, `state_machine`, `msg_sequence`, `module_graph`) that produce
//// standard feature-evolution diagrams.

import gleam/erlang/charlist
import gleam/list
import scripts/common/artifact
import scripts/common/fsx

@external(erlang, "scripts_sh_ffi", "run_capture")
fn sh_run_capture(
  cmd: charlist.Charlist,
  args: List(charlist.Charlist),
) -> #(charlist.Charlist, Int)

fn cl(s: String) -> charlist.Charlist {
  charlist.from_string(s)
}

pub type DotPng {
  DotPng(filename: String, rc: Int)
}

/// Write the DOT source to the canonical artifact tree and render PNG via
/// `dot -Tpng`. Returns the PNG filename (leaf) and the dot exit code.
pub fn render_png(
  stamp: String,
  tid: String,
  slug: String,
  dot_source: String,
) -> DotPng {
  let dot_filename = artifact.filename(stamp, tid, artifact.DiagramDot, slug)
  let png_filename = artifact.filename(stamp, tid, artifact.DiagramPng, slug)
  let dot_path = artifact.journal_dir() <> "/" <> dot_filename
  let png_path = artifact.journal_dir() <> "/" <> png_filename
  let _ = fsx.write_file(artifact.journal_dir(), dot_filename, dot_source)
  let #(_out, rc) =
    sh_run_capture(cl("dot"), list.map(["-Tpng", dot_path, "-o", png_path], cl))
  DotPng(filename: png_filename, rc: rc)
}

// ── Canned diagrams — standard feature-evolution visuals ────────────────────

pub fn fractal_topology() -> String {
  "digraph fractal {\n"
  <> "  rankdir=LR;\n  node [shape=box, style=rounded, fontname=\"Helvetica\"];\n"
  <> "  L0 [label=\"L0 Constitutional\"]; L1 [label=\"L1 Atomic\"];\n"
  <> "  L2 [label=\"L2 Component\"]; L3 [label=\"L3 Transaction\"];\n"
  <> "  L4 [label=\"L4 System\"]; L5 [label=\"L5 Cognitive\"];\n"
  <> "  L6 [label=\"L6 Ecosystem\"]; L7 [label=\"L7 Federation\"];\n"
  <> "  L0 -> L1 -> L2 -> L3 -> L4 -> L5 -> L6 -> L7;\n"
  <> "  subgraph cluster_scripts { label=\"scripts-gleam\";\n"
  <> "    common [label=\"common/ (18 modules)\"];\n"
  <> "    nif [label=\"scripts_nif.so (21 NIFs)\"];\n"
  <> "    runnables [label=\"12 runnable scripts\"];\n"
  <> "    common -> nif; common -> runnables;\n"
  <> "  }\n"
  <> "  runnables -> L4; runnables -> L5; runnables -> L6;\n"
  <> "}\n"
}

pub fn data_plane() -> String {
  "digraph dataplane {\n"
  <> "  rankdir=TB;\n  node [shape=box, fontname=\"Helvetica\"];\n"
  <> "  Client [shape=ellipse];\n"
  <> "  subgraph cluster_saplan { label=\"sa-plan-daemon\";\n"
  <> "    Serve [label=\":4200 serve\"];\n"
  <> "    Api [label=\"web/api.rs\\nzenoh/publish · llm/complete · mcp/invoke\"];\n"
  <> "  }\n"
  <> "  subgraph cluster_scripts { label=\"scripts-gleam\";\n"
  <> "    Bridge [label=\"scripts/pi/mcp_bridge\"];\n"
  <> "    Nif [label=\"scripts_nif.so\"];\n"
  <> "    Runner [label=\"gleam run -m ...\"];\n"
  <> "  }\n"
  <> "  Smriti [shape=cylinder, label=\"Smriti.db (WAL, pooled)\"];\n"
  <> "  ZK [shape=cylinder, label=\"ZK (ingested journals)\"];\n"
  <> "  Zenoh [shape=hexagon, label=\"Zenoh mesh\"];\n"
  <> "  Client -> Serve -> Api;\n"
  <> "  Api -> Zenoh [label=\"publish\"];\n"
  <> "  Api -> Zenoh [label=\"request/reply\"];\n"
  <> "  Zenoh -> Bridge [label=\"mcp/request/*\"];\n"
  <> "  Bridge -> Zenoh [label=\"reply_to\"];\n"
  <> "  Runner -> Nif -> Zenoh;\n"
  <> "  Nif -> Smriti;\n"
  <> "  Runner -> ZK [label=\"sa-plan ingest-docs\"];\n"
  <> "}\n"
}

pub fn state_machine() -> String {
  "digraph state {\n"
  <> "  rankdir=LR;\n  node [shape=oval, fontname=\"Helvetica\"];\n"
  <> "  start [shape=point]; start -> Idle;\n"
  <> "  Idle -> BuildNif [label=\"tools/build_nif\"];\n"
  <> "  BuildNif -> Ready [label=\"ok\"];\n"
  <> "  Ready -> Probing [label=\"tools/list\"];\n"
  <> "  Probing -> Running [label=\"verify/*\"];\n"
  <> "  Running -> Retrying [label=\"transient error\"];\n"
  <> "  Retrying -> Running [label=\"backoff+jitter\"];\n"
  <> "  Running -> Emitting [label=\"fractal.span\"];\n"
  <> "  Emitting -> Serving [label=\"pi/mcp_bridge\"];\n"
  <> "  Serving -> Reporting [label=\"result.json\"];\n"
  <> "  Reporting -> Archived [label=\"tools/retain\"];\n"
  <> "  Archived -> Idle;\n"
  <> "}\n"
}

pub fn msg_sequence() -> String {
  "digraph seq {\n"
  <> "  rankdir=LR;\n  node [shape=box, fontname=\"Helvetica\"];\n"
  <> "  Client; SaPlan; Zenoh; Bridge; Smriti;\n"
  <> "  Client -> SaPlan [label=\"1: POST /api/v1/mcp/invoke\"];\n"
  <> "  SaPlan -> Zenoh [label=\"2: put request/tool\"];\n"
  <> "  Zenoh -> Bridge [label=\"3: deliver subscriber\"];\n"
  <> "  Bridge -> Smriti [label=\"4: smriti.*\"];\n"
  <> "  Smriti -> Bridge [label=\"5: row\"];\n"
  <> "  Bridge -> Zenoh [label=\"6: put reply_to\"];\n"
  <> "  Zenoh -> SaPlan [label=\"7: subscriber recv\"];\n"
  <> "  SaPlan -> Client [label=\"8: JSON 200\"];\n"
  <> "}\n"
}

pub fn module_graph() -> String {
  "digraph modules {\n"
  <> "  rankdir=LR;\n  node [shape=box, fontname=\"Helvetica\"];\n"
  <> "  NIF [label=\"scripts_nif.so\"];\n"
  <> "  Loader [label=\"scripts_nif.erl\"];\n"
  <> "  Common [label=\"scripts/common\"];\n"
  <> "  Probe [label=\"scripts/probe\"];\n"
  <> "  Registry [label=\"scripts/registry\"];\n"
  <> "  Verify [label=\"scripts/verify\"];\n"
  <> "  Tools [label=\"scripts/tools\"];\n"
  <> "  Pi [label=\"scripts/pi\"];\n"
  <> "  NIF -> Loader -> Common;\n"
  <> "  Common -> Probe; Common -> Registry; Common -> Verify;\n"
  <> "  Common -> Tools; Common -> Pi;\n"
  <> "}\n"
}

/// Render the full standard five-diagram set; returns the list of produced
/// PNG filenames (leaf) in canonical order.
pub fn render_standard_set(stamp: String, tid: String) -> List(String) {
  let a = render_png(stamp, tid, "fractal-topology", fractal_topology())
  let b = render_png(stamp, tid, "data-plane", data_plane())
  let c = render_png(stamp, tid, "state-machine", state_machine())
  let d = render_png(stamp, tid, "msg-sequence", msg_sequence())
  let e = render_png(stamp, tid, "module-graph", module_graph())
  [a.filename, b.filename, c.filename, d.filename, e.filename]
}
