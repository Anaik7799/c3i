/// TUI renderer for c3i terminal interface (SC-GLM-UI-001, SC-GLM-UI-004).
/// Renders ANSI terminal output using cockpit/visuals.gleam primitives.
/// Supports the same command set as Wisp API (SC-GLM-UI-007).
/// Render target: 16ms per frame (60fps terminal refresh — AOR-GLM-UI-008).
///
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-004, SC-GLM-UI-007
import cepaf_gleam/cockpit/visuals
import cepaf_gleam/ui/domain.{
  type HealthStatus, type Page, type RenderContext, type TelemetryPoint,
  Critical, Dashboard, Degraded, Healthy, Unknown, page_to_label,
}
import gleam/int
import gleam/list
import gleam/string

/// Render a full TUI frame for the given context.
pub fn render_frame(ctx: RenderContext) -> String {
  let header = render_header(ctx)
  let health_line = render_health(ctx.health)
  let zenoh_line = render_zenoh_status(ctx.zenoh_connected)
  let telemetry = render_telemetry(ctx.telemetry)
  let nav = render_navigation(ctx.page)

  string.join([header, health_line, zenoh_line, "", telemetry, "", nav], "\n")
}

/// Top header bar with page title and timestamp.
fn render_header(ctx: RenderContext) -> String {
  let title = page_to_label(ctx.page)
  let bar = string.repeat("─", 60)
  visuals.with_color("┌" <> bar <> "┐", "cyan")
  <> "\n"
  <> visuals.with_color("│ c3i " <> title, "cyan")
  <> string.repeat(" ", 55 - string.length(title))
  <> visuals.with_color("│", "cyan")
  <> "\n"
  <> visuals.with_color("└" <> bar <> "┘", "cyan")
}

/// Health status line with color coding.
fn render_health(status: HealthStatus) -> String {
  case status {
    Healthy -> visuals.with_color("  HEALTH: OK", "green")
    Degraded(reason) ->
      visuals.with_color("  HEALTH: DEGRADED — " <> reason, "yellow")
    Critical(reason) ->
      visuals.with_color("  HEALTH: CRITICAL — " <> reason, "red")
    Unknown -> visuals.with_color("  HEALTH: UNKNOWN", "magenta")
  }
}

/// Zenoh connection status.
fn render_zenoh_status(connected: Bool) -> String {
  case connected {
    True -> visuals.with_color("  ZENOH: CONNECTED", "green")
    False -> visuals.with_color("  ZENOH: DISCONNECTED", "red")
  }
}

/// Telemetry sparkline from recent data points.
fn render_telemetry(points: List(TelemetryPoint)) -> String {
  case points {
    [] -> "  TELEMETRY: (no data)"
    _ -> {
      let values = list.map(points, fn(p) { p.value })
      let sparkline = visuals.render_sparkline(values)
      "  TELEMETRY: "
      <> sparkline
      <> " ("
      <> int.to_string(list.length(points))
      <> " pts)"
    }
  }
}

/// Navigation bar showing available pages.
fn render_navigation(current: Page) -> String {
  let pages = [
    Dashboard, domain.Planning, domain.Immune, domain.Knowledge, domain.Zenoh,
    domain.Verification,
  ]
  let tabs =
    list.map(pages, fn(p) {
      let label = page_to_label(p)
      case p == current {
        True -> visuals.with_color("[" <> label <> "]", "cyan")
        False -> " " <> label <> " "
      }
    })
  "  " <> string.join(tabs, " | ")
}
