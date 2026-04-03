//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/a2ui/renderer</module></identity>
////   <fractal-topology><layer>L2_COMPONENT</layer></fractal-topology>
////   <compliance><stamp-controls>SC-A2UI-003</stamp-controls></compliance>
//// </c3i-module>
////
//// A2UI renderer — converts validated component proposals to output.
//// Supports 3 render targets: HTML (for Lustre), JSON (for Wisp API), ANSI (for TUI).
//// STAMP: SC-A2UI-003

import cepaf_gleam/a2ui/schema.{type ComponentProposal, proposal_to_json}
import gleam/json
import gleam/list
import gleam/string

/// Render target.
pub type RenderTarget {
  HtmlTarget
  JsonTarget
  AnsiTarget
}

/// Rendered output.
pub type RenderOutput {
  HtmlOutput(html: String)
  JsonOutput(data: json.Json)
  AnsiOutput(text: String)
}

/// Render a component proposal to the specified target.
pub fn render(proposal: ComponentProposal, target: RenderTarget) -> RenderOutput {
  case target {
    HtmlTarget -> HtmlOutput(render_html(proposal))
    JsonTarget -> JsonOutput(render_json(proposal))
    AnsiTarget -> AnsiOutput(render_ansi(proposal))
  }
}

/// Render to HTML string (for Lustre server component injection).
fn render_html(proposal: ComponentProposal) -> String {
  let children_html =
    list.map(proposal.children, render_html) |> string.join("")
  let id_attr = " data-a2ui-id=\"" <> proposal.id <> "\""
  case proposal.component_type {
    "badge" ->
      "<span class=\"badge\""
      <> id_attr
      <> ">"
      <> children_html
      <> "</span>"
    "button" ->
      "<button" <> id_attr <> ">" <> children_html <> "</button>"
    "alert" ->
      "<div role=\"alert\""
      <> id_attr
      <> ">"
      <> children_html
      <> "</div>"
    "progress" ->
      "<div class=\"progress\""
      <> id_attr
      <> ">"
      <> children_html
      <> "</div>"
    "modal" ->
      "<dialog" <> id_attr <> ">" <> children_html <> "</dialog>"
    _ ->
      "<div data-a2ui-type=\""
      <> proposal.component_type
      <> "\""
      <> id_attr
      <> ">"
      <> children_html
      <> "</div>"
  }
}

/// Render to JSON (for Wisp API response).
fn render_json(proposal: ComponentProposal) -> json.Json {
  proposal_to_json(proposal)
}

/// Render to ANSI terminal text (for TUI).
fn render_ansi(proposal: ComponentProposal) -> String {
  let children_ansi =
    list.map(proposal.children, render_ansi) |> string.join("\n")
  let component_text = case proposal.component_type {
    "badge" -> "[" <> proposal.component_type <> ":" <> proposal.id <> "]"
    "alert" ->
      "\u{001b}[31m! ALERT [" <> proposal.id <> "]\u{001b}[0m"
    "progress" -> "[====    ] " <> proposal.id
    "sparkline" -> "\u{25b2}\u{25b3}\u{25b4}\u{25b5}\u{25b6}\u{25b7}\u{25b8} " <> proposal.id
    _ -> "[" <> proposal.component_type <> "] " <> proposal.id
  }
  case children_ansi {
    "" -> component_text
    _ -> component_text <> "\n  " <> children_ansi
  }
}
