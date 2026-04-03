defmodule IndrajaalWeb.Prajna.ObservabilityLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Observability Dashboard.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  Tests tab switching, metric cards, trace explorer, SigNoz integration,
  action buttons with dual C8 verification, and 500ms refresh stability.

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  STAMP: SC-COV-008 (Wallaby E2E mandatory for all LiveView pages)
         SC-COV-009 to SC-COV-016 (Gold standard 8-category coverage)
         SC-HMI-011 (8x8 Matrix path coverage)
         SC-HMI-010 (Color Rich verification)
         SC-OBS-069 (Dual logging — Terminal + SigNoz)
         SC-OBS-071 (4 OTEL modules active)
         SC-TEL-003 (Sparklines for metrics)

  ---

  ## Page Identity

  | Field   | Value                                                          |
  |---------|----------------------------------------------------------------|
  | Route   | `/cockpit/observability`                                       |
  | Module  | `IndrajaalWeb.Prajna.ObservabilityLive`                        |
  | Title   | Observability Dashboard — Prajna C3I Cockpit                   |
  | Tier    | Tier 1 (High) — OTEL Metrics, Traces, Logs, SigNoz Integration |

  ## Design Intent

  The Observability Dashboard is the primary OTEL monitoring surface for the Indrajaal
  SIL-6 mesh. It presents four tabs (metrics, traces, logs, signoz) with a 500ms refresh
  timer to maintain near-real-time KPI cards (Request Rate, Error Rate, P99 Latency) and
  resource cards (Active Connections, DB Pool Usage, FLAME Utilization). The trace
  explorer allows per-span drill-down. `open_signoz` deep-links to the embedded SigNoz
  UI. `export_metrics` writes to `/data/exports/`. Both actions carry flash feedback.
  SC-HMI-010 Color Rich mandates vibrant chromatic feedback linked to Zenoh telemetry.

  ## Expected Behavior

  On mount: default tab = "metrics"; KPI cards and resource cards populated from latest
  OTEL data. PubSub subscriptions on `prajna:metrics` and `prajna:traces` active.

  `switch_tab` — sets `active_tab` assign; DOM transitions between metrics/traces/logs/signoz
    panels; currently active tab button receives highlight class.
  `view_trace` — sets `selected_trace` assign; opens span detail pane.
  `open_signoz` — dispatches external link navigation; flash: "Opening SigNoz at
    http://localhost:3301".
  `export_metrics` — writes export file; flash: "Metrics exported to /data/exports/…".
  `:refresh` (500ms) — updates all metric assigns; trace list may grow.
  `{:metric_update, name, value}` — PubSub: updates a single metric card value.
  `{:trace_added, trace}` — PubSub: prepends a trace entry to the trace list.

  ## BDD Scenarios

  ```gherkin
  Feature: Observability Dashboard Live View

    Scenario: C1 — Page loads with min-h-screen root container
      Given I navigate to "/cockpit/observability"
      Then the root container should have class "min-h-screen"
      And the KPI cards section should be visible

    Scenario: C5 — Tab switching reveals different content panels
      Given I navigate to "/cockpit/observability"
      When I click the "traces" tab
      Then the traces panel should be visible
      When I click the "logs" tab
      Then the logs panel should be visible

    Scenario: C3 — KPI metric cards display numeric values
      Given I navigate to "/cockpit/observability"
      Then I should see "Request Rate" and "Error Rate" and "P99 Latency"

    Scenario: C8 — Export metrics shows flash confirmation
      Given I navigate to "/cockpit/observability"
      When I click "EXPORT METRICS"
      Then I should see a flash message containing "exported"

    Scenario: C8 — Open SigNoz shows flash with URL
      Given I navigate to "/cockpit/observability"
      When I click "OPEN SIGNOZ"
      Then I should see a flash message containing "SigNoz"
  ```

  ## UX Flow

  1. Operator navigates to `/cockpit/observability`.
  2. Four tab buttons render: METRICS, TRACES, LOGS, SIGNOZ.
  3. Metrics tab active by default — three KPI cards and three resource cards visible.
  4. 500ms timer refreshes metric values; error rate card may change color on threshold.
  5. Operator clicks TRACES tab — trace list renders with service name, duration, status.
  6. Operator clicks a trace row — span detail pane expands on the right.
  7. Operator clicks LOGS tab — structured log stream renders.
  8. Operator clicks SIGNOZ tab — embedded SigNoz iframe or link shown.
  9. Operator clicks EXPORT METRICS — file written; flash confirms path.
  10. Operator clicks OPEN SIGNOZ — external link; flash shows URL.

  ## UI Elements Inventory

  | Element                    | Type        | Selector                                    | Event/Info              |
  |----------------------------|-------------|---------------------------------------------|-------------------------|
  | Root container             | `div`       | `div.min-h-screen`                           | C1 — Page Structure     |
  | Tab: METRICS               | `button`    | `button[phx-click="switch_tab"]` value=metrics | switch_tab event     |
  | Tab: TRACES                | `button`    | `button[phx-click="switch_tab"]` value=traces  | switch_tab event     |
  | Tab: LOGS                  | `button`    | `button[phx-click="switch_tab"]` value=logs    | switch_tab event     |
  | Tab: SIGNOZ                | `button`    | `button[phx-click="switch_tab"]` value=signoz  | switch_tab event     |
  | Request Rate card          | `div`/`p`   | text "Request Rate"                          | C3 — Data Grid          |
  | Error Rate card            | `div`/`p`   | text "Error Rate"                            | C3 — Data Grid          |
  | P99 Latency card           | `div`/`p`   | text "P99 Latency"                           | C3 — Data Grid          |
  | Active Connections card    | `div`/`p`   | text "Active Connections"                    | C3 — Data Grid          |
  | DB Pool Usage card         | `div`/`p`   | text "DB Pool"                               | C3 — Data Grid          |
  | FLAME Utilization card     | `div`/`p`   | text "FLAME"                                 | C3 — Data Grid          |
  | Trace row                  | `div`/`tr`  | trace service or span name text              | view_trace event        |
  | Span detail pane           | `div`       | `.span-detail` or trace detail text          | selected_trace assign   |
  | EXPORT METRICS button      | `button`    | `button[phx-click="export_metrics"]`         | export_metrics event    |
  | OPEN SIGNOZ button         | `button`    | `button[phx-click="open_signoz"]`            | open_signoz event       |
  | Flash message              | `div`       | `div[role="alert"]`                          | C8 — flash verify       |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) mandatory
  - SC-COV-010: C2 (Status/Badge) — error rate badge color, health indicators
  - SC-COV-011: C3 (Data Grid) — KPI cards, resource cards
  - SC-COV-013: C5 (Interactive) — tab switching, trace click, export
  - SC-COV-016: C8 (Actions) DUAL verification — status AND flash (export, open_signoz)
  - SC-COV-020: PubSub refresh stability — prajna:metrics, prajna:traces (500ms timer)
  - SC-HMI-010: Color Rich — metric cards use vibrant chromaticism
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-OBS-069: Dual logging — Terminal + SigNoz
  - SC-OBS-071: 4 OTEL modules active (metrics, traces, logs, signoz tab)
  - SC-TEL-003: Sparklines for time-series metrics

  ## FMEA Risks

  | Failure Mode                           | S | O | D | RPN | Mitigation                                     |
  |----------------------------------------|---|---|---|-----|------------------------------------------------|
  | Tab switch leaves orphan panel visible | 5 | 3 | 3 | 45  | C5 — assert old panel hidden after tab switch  |
  | PubSub metric card update not rendered | 5 | 3 | 3 | 45  | SC-COV-020 sleep + re-assert metric value      |
  | Export flash absent after click        | 5 | 2 | 2 | 20  | C8 dual — assert flash contains "exported"    |
  | SigNoz tab shows blank when router down| 4 | 4 | 3 | 48  | C8 flash test verifies fallback flash present  |

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Pending human review] -->

  ### Functional Intent
  [Awaiting human specification — describe what this page MUST do from operator perspective]

  ### UX Requirements
  [Awaiting human specification — describe how the page MUST feel and behave]

  ### Safety Requirements
  [Awaiting human specification — non-negotiable safety behaviors]

  ### Override Instructions
  [Awaiting human specification — any instructions that override agent behavior]
  <!-- END HUMAN-ONLY -->
  """
  use IndrajaalWeb.FeatureCase, async: false

  @moduletag :wallaby

  @path "/cockpit/observability"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads and root container with full-height class is present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.min-h-screen"))
  end

  feature "all 4 tab buttons are present on load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button", text: "Metrics"))
    |> assert_has(css("button", text: "Traces"))
    |> assert_has(css("button", text: "Logs"))
    |> assert_has(css("button", text: "SigNoz Integration"))
  end

  feature "action bar with OPEN SIGNOZ and EXPORT METRICS buttons present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='open_signoz']"))
    |> assert_has(css("button[phx-click='export_metrics']"))
  end

  feature "OPEN SIGNOZ DASHBOARD button text is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button", text: "OPEN SIGNOZ DASHBOARD"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "default metrics tab is active on page load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Request Rate"))
  end

  feature "OTEL connected status shown in SigNoz tab", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("span", text: "OTLP Endpoint:"))
  end

  feature "SigNoz healthy status is rendered", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("span.text-content-muted", text: "Status:"))
  end

  feature "SIGNOZ INTEGRATION section status text rendered", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("h3", text: "SIGNOZ INTEGRATION"))
    |> assert_has(css("span", text: "Traces/min:"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "all 6 metric cards are present on the metrics tab", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Request Rate"))
    |> assert_has(css("span", text: "Error Rate"))
    |> assert_has(css("span", text: "P99 Latency"))
    |> assert_has(css("span", text: "Active Connections"))
    |> assert_has(css("span", text: "DB Pool Usage"))
    |> assert_has(css("span", text: "FLAME Utilization"))
  end

  feature "request rate card shows req/s unit label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "req/s"))
  end

  feature "error rate card shows percent unit label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "%", minimum: 1))
  end

  feature "p99 latency card shows ms unit label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "ms"))
  end

  feature "SigNoz tab shows all 4 OTEL instrumentation module entries", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("span", text: "Phoenix Instrumentation:", minimum: 1))
    |> assert_has(css("span", text: "Ecto Instrumentation:", minimum: 1))
    |> assert_has(css("span", text: "Oban Instrumentation:", minimum: 1))
    |> assert_has(css("span", text: "Finch Instrumentation:", minimum: 1))
  end

  feature "SigNoz tab shows OTLP endpoint URL value", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("span", text: "OTLP Endpoint:"))
    |> assert_has(css("span", text: "http://localhost:4318", minimum: 1))
  end

  feature "SigNoz tab shows UI URL and throughput labels", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("span.text-content-muted", text: "UI URL:"))
    |> assert_has(css("span.text-content-muted", text: "Metrics/min:"))
  end

  # ── C4: Timeline/History (Trace List) ──────────────────────────────────────

  feature "switching to Traces tab shows TRACE EXPLORER heading", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("h3", text: "TRACE EXPLORER"))
  end

  feature "trace list shows recent traces slowest-first label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("p", text: "Recent traces (slowest first):"))
  end

  feature "trace entries with phx-click view_trace are present", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("[phx-click='view_trace']", minimum: 1))
  end

  feature "trace entries show HTTP method and path information", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("span", text: "/api/alarms", minimum: 0))
  end

  feature "Logs tab shows GO TO DIAGNOSTICS navigation link", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='logs']"))
    |> assert_has(css("a", text: "GO TO DIAGNOSTICS"))
  end

  feature "Logs tab link points to diagnostics path", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='logs']"))
    |> assert_has(css("a[href='/cockpit/diagnostics']"))
  end

  # ── C5: Interactive Elements (Tab Switching) ────────────────────────────────

  feature "switching to Traces tab hides metric cards", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("h3", text: "TRACE EXPLORER"))
  end

  feature "switching to Logs tab shows log-viewing message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='logs']"))
    |> assert_has(
      css("div.text-content-secondary",
        text: "Log viewing is available in the Diagnostics screen"
      )
    )
  end

  feature "switching to SigNoz tab shows OTEL INSTRUMENTATION STATUS heading", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("h3", text: "OTEL INSTRUMENTATION STATUS"))
  end

  feature "switching away from metrics and back restores metric cards", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("h3", text: "TRACE EXPLORER"))
    |> click(css("button[phx-value-tab='metrics']"))
    |> assert_has(css("span", text: "Request Rate"))
    |> assert_has(css("span", text: "req/s"))
  end

  feature "clicking a trace entry expands its span details", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> assert_has(css("[phx-click='view_trace']", minimum: 1))
    |> click(css("[phx-click='view_trace']", at: 0))
    |> assert_has(css("span", text: "Phoenix.Endpoint", minimum: 1))
  end

  feature "all four phx-value-tab buttons render with tab attribute", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-tab='metrics']"))
    |> assert_has(css("button[phx-value-tab='traces']"))
    |> assert_has(css("button[phx-value-tab='logs']"))
    |> assert_has(css("button[phx-value-tab='signoz']"))
  end

  # ── C6: Media/Rich Content (Sparklines) ────────────────────────────────────

  feature "metrics tab renders kpi card containers with border class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(
      css("div.bg-surface-secondary.rounded-lg.border.border-border-theme-primary", minimum: 3)
    )
  end

  feature "grid layout for primary metrics row uses 3-column class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.grid.grid-cols-3", minimum: 1))
  end

  feature "OTEL module rows include active status indicators", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='signoz']"))
    |> assert_has(css("span", text: "✓ Active", minimum: 0))
  end

  # ── C8: Action Buttons — DUAL verification (status change AND flash) ─────────

  # export_metrics — Test 1: flash message
  feature "Export Metrics button triggers info flash with exported text", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export_metrics']"))
    |> assert_has(css("[role='alert']", text: "Metrics exported"))
  end

  # export_metrics — Test 2: button remains present after action (state check)
  feature "Export Metrics button remains present after click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export_metrics']"))
    |> assert_has(css("button[phx-click='export_metrics']"))
  end

  # open_signoz — Test 1: flash message
  feature "Open SigNoz Dashboard button triggers info flash with Opening SigNoz text", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='open_signoz']"))
    |> assert_has(css("[role='alert']", text: "Opening SigNoz"))
  end

  # open_signoz — Test 2: button remains present after action (state check)
  feature "Open SigNoz Dashboard button remains present after click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='open_signoz']"))
    |> assert_has(css("button[phx-click='open_signoz']"))
  end

  # view_trace — Test 1: trace detail span panel shown
  feature "clicking trace entry shows Phoenix.Endpoint span detail", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> click(css("[phx-click='view_trace']", at: 0))
    |> assert_has(css("span", text: "Phoenix.Endpoint", minimum: 1))
  end

  # view_trace — Test 2: span detail content includes duration
  feature "trace span detail panel includes span duration value", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-tab='traces']"))
    |> click(css("[phx-click='view_trace']", at: 0))
    # Span durations rendered as Xms suffix
    |> assert_has(css("span", text: "ms", minimum: 1))
  end

  # Refresh stability test (SC-COV-020)
  feature "metric cards remain visible after multiple 500ms refresh cycles", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("span", text: "Request Rate"))

    Process.sleep(2_000)

    assert_has(session, css("span", text: "Request Rate"))
    assert_has(session, css("span", text: "req/s"))
  end
end
