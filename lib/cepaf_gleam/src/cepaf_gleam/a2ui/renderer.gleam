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
  let aria_label = " aria-label=\"" <> proposal.id <> "\""
  case proposal.component_type {
    "badge" ->
      "<span class=\"badge\" role=\"status\"" <> id_attr <> aria_label <> ">" <> children_html <> "</span>"
    "button" | "action_button" | "emergency_stop" ->
      "<button tabindex=\"0\" role=\"button\"" <> id_attr <> aria_label <> ">" <> children_html <> "</button>"
    "alert" ->
      "<div role=\"alert\" aria-live=\"assertive\"" <> id_attr <> aria_label <> ">" <> children_html <> "</div>"
    "progress" ->
      "<div class=\"progress\" role=\"progressbar\" aria-valuemin=\"0\" aria-valuemax=\"100\" tabindex=\"0\"" <> id_attr <> aria_label <> ">" <> children_html <> "</div>"
    "modal" ->
      "<dialog aria-modal=\"true\" role=\"dialog\"" <> id_attr <> aria_label <> ">" <> children_html <> "</dialog>"
    "data_table" ->
      "<table role=\"table\"" <> id_attr <> aria_label <> ">" <> children_html <> "</table>"
    "sparkline" | "ooda_ring" | "topology" ->
      "<figure role=\"img\"" <> id_attr <> aria_label <> ">" <> children_html <> "</figure>"
    "reasoning" ->
      "<div role=\"log\" aria-live=\"polite\"" <> id_attr <> aria_label <> ">" <> children_html <> "</div>"
    "container_card" ->
      "<article role=\"article\"" <> id_attr <> aria_label <> ">" <> children_html <> "</article>"
    "card_grid" ->
      "<div role=\"group\"" <> id_attr <> aria_label <> ">" <> children_html <> "</div>"
    "section" ->
      "<section role=\"region\"" <> id_attr <> aria_label <> ">" <> children_html <> "</section>"
    _ ->
      "<div data-a2ui-type=\""
      <> proposal.component_type
      <> "\""
      <> id_attr
      <> aria_label
      <> " role=\"region\""
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
    "badge" -> "\u{001b}[36m[" <> proposal.id <> "]\u{001b}[0m"
    "button" | "action_button" -> "\u{001b}[32m< " <> proposal.id <> " >\u{001b}[0m"
    "emergency_stop" -> "\u{001b}[41;37;1m[ EMERGENCY STOP ]\u{001b}[0m"
    "alert" -> "\u{001b}[31;1m! ALERT [" <> proposal.id <> "]\u{001b}[0m"
    "progress" -> "\u{001b}[34m[======    ] \u{001b}[0m" <> proposal.id
    "sparkline" ->
      "\u{001b}[35m\u{2582}\u{2583}\u{2584}\u{2585}\u{2586}\u{2587}\u{2588} \u{001b}[0m" <> proposal.id
    "ooda_ring" -> "\u{001b}[36m( OODA )\u{001b}[0m " <> proposal.id
    "topology" -> "\u{001b}[33m*--*--*\u{001b}[0m " <> proposal.id
    "reasoning" -> "\u{001b}[30;1m> " <> proposal.id <> "\u{001b}[0m"
    "data_table" -> "\u{001b}[37;40m| DataTable | " <> proposal.id <> " |\u{001b}[0m"
    "container_card" -> "\u{001b}[36m+-- " <> proposal.id <> " --+\u{001b}[0m"
    "card_grid" | "section" -> "\u{001b}[1m=== " <> string.uppercase(proposal.id) <> " ===\u{001b}[0m"
    _ -> "[" <> proposal.component_type <> "] " <> proposal.id
  }
  case children_ansi {
    "" -> component_text
    _ -> component_text <> "\n  " <> string.replace(children_ansi, "\n", "\n  ")
  }
}
