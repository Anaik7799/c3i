/// TUI view for Zenoh Mesh plane (SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007
import cepaf_gleam/cockpit/visuals
import cepaf_gleam/ui/lustre/zenoh_mesh.{type ZenohModel}
import cepaf_gleam/zenoh/domain.{Connected, Connecting, Disconnected}
import gleam/int
import gleam/list
import gleam/string

pub fn render(model: ZenohModel) -> String {
  let header = visuals.with_color("  ZENOH MESH", "cyan")
  let status = render_status(model)
  let stats = render_stats(model)
  let subs = render_subscriptions(model.subscriptions)
  string.join([header, status, stats, "", subs], "\n")
}

fn render_status(model: ZenohModel) -> String {
  let status_text = case model.health.status {
    Connected -> visuals.with_color("CONNECTED", "green")
    Disconnected -> visuals.with_color("DISCONNECTED", "red")
    Connecting -> visuals.with_color("CONNECTING", "yellow")
    domain.Error(msg) -> visuals.with_color("ERROR: " <> msg, "red")
  }
  "  Status: " <> status_text <> "  Session: " <> model.health.session_id
}

fn render_stats(model: ZenohModel) -> String {
  "  Pub: "
  <> int.to_string(model.health.messages_published)
  <> "  Recv: "
  <> int.to_string(model.health.messages_received)
  <> "  Errors: "
  <> int.to_string(model.health.error_count)
  <> "  Reconnects: "
  <> int.to_string(model.health.reconnect_count)
}

fn render_subscriptions(topics: List(String)) -> String {
  "  Subscriptions ("
  <> int.to_string(list.length(topics))
  <> "):"
  <> "\n"
  <> {
    topics
    |> list.take(8)
    |> list.map(fn(t) { "    " <> visuals.with_color(t, "blue") })
    |> string.join("\n")
  }
}
