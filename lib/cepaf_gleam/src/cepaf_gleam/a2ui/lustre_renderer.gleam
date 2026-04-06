import cepaf_gleam/a2ui/schema.{type ComponentProposal}
import cepaf_gleam/ui/lustre/shell
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Render an A2UI ComponentProposal directly into a Lustre Element tree.
pub fn render(proposal: ComponentProposal) -> Element(msg) {
  let children_elements = list.map(proposal.children, render)

  case proposal.component_type {
    "action_button" -> {
      // In a real implementation, we would decode props from proposal.props
      // Since it's currently stored as json.Json (an encoder), we stub it for Phase 1
      let label = "Action"
      let endpoint = "/api/v1/noop"
      let payload = "{}"

      shell.action_button(label, endpoint, payload)
    }
    "card_grid" -> {
      html.div([attribute.class("card-grid")], children_elements)
    }
    "section" -> {
      let title = "Section"
      shell.section(title, children_elements)
    }
    "data_table" -> {
      let headers = []
      let rows = []
      shell.data_table(headers, rows)
    }
    "badge" -> {
      html.span(
        [
          attribute.class("badge"),
          attribute.attribute("data-a2ui-id", proposal.id),
        ],
        children_elements,
      )
    }
    "button" -> {
      html.button(
        [attribute.attribute("data-a2ui-id", proposal.id)],
        children_elements,
      )
    }
    "alert" -> {
      html.div(
        [
          attribute.attribute("role", "alert"),
          attribute.attribute("data-a2ui-id", proposal.id),
        ],
        children_elements,
      )
    }
    "progress" -> {
      html.div(
        [
          attribute.class("progress"),
          attribute.attribute("data-a2ui-id", proposal.id),
        ],
        children_elements,
      )
    }
    "modal" -> {
      html.dialog(
        [attribute.attribute("data-a2ui-id", proposal.id)],
        children_elements,
      )
    }
    _ -> {
      html.div(
        [
          attribute.attribute("data-a2ui-type", proposal.component_type),
          attribute.attribute("data-a2ui-id", proposal.id),
        ],
        children_elements,
      )
    }
  }
}
