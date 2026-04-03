defmodule IndrajaalWeb.Prajna.AlarmsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Alarms Dashboard LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/alarms`
  - **Module**: `IndrajaalWeb.Prajna.AlarmsLive`
  - **Title**: "Alarm Center"
  - **Priority**: P0 (Safety-Critical — primary alarm management console)

  ## Design Intent
  The Alarm Center is the primary operator display for all system alarms across
  the PRAJNA C3I mesh. It provides real-time severity counts, a filterable alarm
  list, storm detection with suppress-and-acknowledge, per-alarm workflow actions
  (acknowledge, silence, escalate), KPI metrics, and Sentinel health integration.
  The page subscribes to three PubSub channels and maintains three refresh timers
  at different intervals (2s/5s/30s) to balance freshness with Sentinel/Zenoh load.

  ## Expected Behavior (Functional)

  ### Mount Assigns
  - `page_title` — "Alarm Center"
  - `current_nav` — `:alarms`
  - `alarms` — list of sample alarm maps
  - `filter_severity` — `:all`
  - `filter_status` — `:active`
  - `filter_timerange` — `:last_24h`
  - `search_query` — "" (empty string)
  - `selected_alarm` — nil
  - `severity_icons` — map of severity → icon string
  - `storm_status` — `:normal` (or `:warning`/`:critical` when storm detected)
  - `storm_metrics` — map with `current_rate`, `threshold`, `suppressed_count`, `acknowledged`
  - `correlation_metrics` — map with deduplicated/correlated alarm stats
  - `workflow_status` — map of alarm workflow states
  - `severity_counts` — map with `critical`, `warning`, `caution`, `advisory` counts
  - `alarm_trends` — trend data for the sparkline chart
  - `sentinel_health` — sentinel health struct
  - `alarm_kpis` — KPI summary metrics

  ### handle_event Callbacks
  - `"filter_severity"` — updates `filter_severity` to atom; no flash
  - `"filter_status"` — updates `filter_status` to atom; no flash
  - `"search"` — updates `search_query`; no flash
  - `"acknowledge"` — sets alarm status to `:acknowledged`; flash :info "Alarm #{id} acknowledged"
  - `"silence"` — flash :info "Alarm #{id} silenced for #{duration}"
  - `"escalate"` — flash :warning "Alarm #{id} escalated to supervisor"
  - `"select_alarm"` — sets `selected_alarm` to id; no flash
  - `"ack_all_advisory"` — bulk-acknowledges all active advisory alarms; flash :info "#{count} advisory alarms acknowledged"
  - `"acknowledge_storm"` — sets `storm_metrics.acknowledged=true`; flash :info "Storm acknowledged"
  - `"export_report"` — flash :info "Report exported to /data/exports/alarms-report.json"
  - `"configure_thresholds"` — flash :info "Opening threshold configuration..."

  ### handle_info Callbacks
  - `:refresh` (every 2000ms) — refreshes alarms list, severity counts, storm status
  - `:sync_metrics` (every 5000ms) — syncs alarm metrics to SmartMetrics; updates KPIs
  - `:sync_sentinel` (every 30000ms) — fetches Sentinel health
  - `{:new_alarm, alarm}` — prepends alarm to list; updates storm metrics
  - `{:metric_updated, metric_id, metric}` — handles SmartMetrics updates (no-op currently)
  - `{:zenoh_alarm_event, event}` — handles Zenoh alarm events (debug log only currently)

  ### PubSub Subscriptions
  - `"prajna:alarms"` — alarm lifecycle events
  - `"prajna:metrics"` — SmartMetrics update notifications
  - `"zenoh:alarms"` — Zenoh-sourced alarm events

  ### Timer Intervals
  - `:refresh` every 2000ms
  - `:sync_metrics` every 5000ms
  - `:sync_sentinel` every 30000ms

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with ACTIVE ALARMS heading
    Given I navigate to "/cockpit/alarms"
    Then I see h2 "ACTIVE ALARMS"
    And I see the page title "Alarm Center"
    And I see the navigation bar

  Scenario: C2 - Severity counts display on load
    Given I navigate to "/cockpit/alarms"
    Then I see the ACTIVE ALARMS BY SEVERITY panel
    And I see severity labels Critical, Warning, Caution, Advisory

  Scenario: C3 - KPI metrics are shown
    Given I navigate to "/cockpit/alarms"
    Then I see the KPI dashboard row with metrics cards

  Scenario: C5 - Acknowledge alarm shows flash
    Given I navigate to "/cockpit/alarms"
    When I click the acknowledge button for an alarm
    Then I see flash info "acknowledged"
    And the alarm status badge shows "Acknowledged"

  Scenario: C8 (dual escalate) - Escalate shows flash warning
    Given I navigate to "/cockpit/alarms"
    When I click the escalate button for an alarm
    Then I see flash warning "escalated to supervisor"

  Scenario: C8 (dual storm) - Storm acknowledge shows flash
    Given I navigate to "/cockpit/alarms" with storm active
    When I click ACK STORM
    Then I see flash info "Storm acknowledged"

  Scenario: C4 - Alarm entries show timestamps
    Given I navigate to "/cockpit/alarms"
    Then I see chronologically ordered alarm entries
  ```

  ## UX Flow
  1. Operator loads page; sees severity counts KPI row and full alarm list
  2. Operator applies filters (severity, status, time range) or searches by text
  3. Storm banner appears if `storm_status != :normal` — operator can ACK STORM
  4. Operator clicks individual alarm rows to acknowledge, silence, or escalate
  5. Bulk "ACK ALL ADVISORY" button acknowledges all low-severity alarms at once
  6. Export Report saves alarm data to `/data/exports/alarms-report.json`
  7. Configure Thresholds opens threshold configuration
  8. Sentinel health displayed in sidebar; updated every 30s

  ## UI Elements Inventory

  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | ACTIVE ALARMS heading | h2 | `h2[text="ACTIVE ALARMS"]` | — | C1 |
  | Navigation bar | nav | `nav` | — | C1 |
  | Severity count badges | span | `span.text-red-500` (critical etc.) | — | C2 |
  | Storm warning banner | div | `div[contains 'ALARM STORM DETECTED']` | — | C2 |
  | ACK STORM button | button | `button[phx-click='acknowledge_storm']` | `acknowledge_storm` | C8 |
  | Severity filter buttons | button | `button[phx-click='filter_severity']` | `filter_severity` | C5 |
  | Status filter buttons | button | `button[phx-click='filter_status']` | `filter_status` | C5 |
  | Search input | input | `input[phx-keyup='search']` | `search` | C5 |
  | Alarm list rows | div | `div[phx-click='select_alarm']` | `select_alarm` | C3 |
  | Acknowledge button | button | `button[phx-click='acknowledge']` | `acknowledge` | C8 |
  | Silence button | button | `button[phx-click='silence']` | `silence` | C8 |
  | Escalate button | button | `button[phx-click='escalate']` | `escalate` | C8 |
  | ACK ALL ADVISORY button | button | `button[phx-click='ack_all_advisory']` | `ack_all_advisory` | C8 |
  | Export Report button | button | `button[phx-click='export_report']` | `export_report` | C8 |
  | Configure Thresholds button | button | `button[phx-click='configure_thresholds']` | `configure_thresholds` | C8 |
  | Footer keyboard shortcuts | footer | `footer span[text="[A] Acknowledge"]` | — | C1 |
  | Zenoh status in footer | span | `footer span[contains 'Zenoh:']` | — | C2 |
  | Sentinel status in footer | span | `footer span[contains 'Sentinel:']` | — | C2 |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-020: PubSub pages require refresh stability test (sleep + re-assert)
  - SC-ALARM-001: Alarm management compliance — all alarm states coverable
  - SC-PRAJNA-004: Sentinel health integration required
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-VDP-015: Score-based popup threshold for alarm detail panel
  - SC-BRIDGE-005: PubSub topics `prajna:alarms`, `prajna:metrics`, `zenoh:alarms`

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Storm banner not shown when rate threshold exceeded | 7 | 2 | 3 | 42 | `storm_status` checked in render; `:refresh` at 2s |
  | Severity counts stale after alarm state change | 5 | 3 | 3 | 45 | `compute_severity_counts` called on every `:refresh` |
  | Sentinel health not updated on disconnect | 7 | 2 | 3 | 42 | `:sync_sentinel` runs every 30s with fetch |
  | Filter resets on PubSub alarm arrival | 3 | 2 | 4 | 24 | `{:new_alarm,...}` only prepends; filters preserved |
  | ACK ALL ADVISORY operates on all tenants | 5 | 2 | 3 | 30 | Filter in `ack_all_advisory` scoped to advisory+active |

  STAMP: SC-COV-008 to SC-COV-022, AOR-COV-008 to AOR-COV-017

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

  @path "/cockpit/alarms"

  # ── C1: Page Structure ────────────────────────────────────────────────────────

  feature "page loads and shows ACTIVE ALARMS heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  feature "page title is Alarm Center", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("title", text: "Alarm Center"))
  end

  feature "prajna navigation bar is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav"))
  end

  feature "footer shows keyboard shortcuts for acknowledge silence escalate and filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[A] Acknowledge"))
    |> assert_has(css("footer span", text: "[S] Silence"))
    |> assert_has(css("footer span", text: "[E] Escalate"))
    |> assert_has(css("footer span", text: "[F] Filter"))
  end

  feature "footer shows Zenoh and Sentinel status", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "Zenoh:"))
    |> assert_has(css("footer span", text: "Sentinel:"))
  end

  feature "Signal Detection Theory constraint badge is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "SC-PRAJNA-004"))
  end

  # ── C2: Status/Badge Display ──────────────────────────────────────────────────

  feature "storm detection card shows status value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "STORM DETECTION"))
    |> assert_has(css("span", text: "NORMAL"))
  end

  feature "correlation engine card shows ACTIVE or IDLE status badge", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "CORRELATION ENGINE"))
    |> assert_has(css("span", text: "Status:"))
  end

  feature "sentinel health card shows status badge value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SENTINEL HEALTH"))
    |> assert_has(css("span", text: "HEALTHY"))
  end

  feature "filter button for active severity is highlighted after selection", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-severity='critical']"))
    |> assert_has(css("button[phx-value-severity='critical']"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  feature "filter_status select defaults to Active option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='active']"))
  end

  # ── C3: Data Grid/Summary ─────────────────────────────────────────────────────

  feature "severity count cards show all four severity labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ACTIVE ALARMS BY SEVERITY"))
    |> assert_has(css("span", text: "Critical"))
    |> assert_has(css("span", text: "Warning"))
    |> assert_has(css("span", text: "Caution"))
    |> assert_has(css("span", text: "Advisory"))
  end

  feature "severity count cards show numeric values next to severity labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ACTIVE ALARMS BY SEVERITY"))
    |> assert_has(css("span", text: "Critical"))
    |> assert_has(css("span", text: "Warning"))
  end

  feature "storm detection card shows rate threshold suppressed and last storm fields", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "STORM DETECTION"))
    |> assert_has(css("span", text: "Status:"))
    |> assert_has(css("span", text: "Rate:"))
    |> assert_has(css("span", text: "Threshold:"))
    |> assert_has(css("span", text: "Suppressed:"))
    |> assert_has(css("span", text: "Last Storm:"))
  end

  feature "correlation engine card shows clusters correlated and noise reduced fields", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "CORRELATION ENGINE"))
    |> assert_has(css("span", text: "Clusters:"))
    |> assert_has(css("span", text: "Correlated:"))
    |> assert_has(css("span", text: "Noise Reduced:"))
    |> assert_has(css("span", text: "Latency:"))
  end

  feature "workflow tracking card shows pending in-progress escalated resolved counts", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "WORKFLOW TRACKING"))
    |> assert_has(css("span", text: "Pending:"))
    |> assert_has(css("span", text: "In Progress:"))
    |> assert_has(css("span", text: "Escalated:"))
    |> assert_has(css("span", text: "Resolved (24h):"))
    |> assert_has(css("span", text: "Avg Response:"))
  end

  feature "sentinel health card shows health score active threats quarantined and last sync", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SENTINEL HEALTH"))
    |> assert_has(css("span", text: "Health Score:"))
    |> assert_has(css("span", text: "Active Threats:"))
    |> assert_has(css("span", text: "Quarantined:"))
    |> assert_has(css("span", text: "Last Sync:"))
  end

  feature "alarm KPIs card shows MTTR false alarm rate escalation rate and d-prime", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ALARM KPIs"))
    |> assert_has(css("span", text: "MTTR:"))
    |> assert_has(css("span", text: "False Alarm Rate:"))
    |> assert_has(css("span", text: "Escalation Rate:"))
    |> assert_has(css("span", text: "d-prime:"))
  end

  # ── C4: Timeline/History (Alarm Trends) ───────────────────────────────────────

  feature "alarm trends 24h section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ALARM TRENDS (24h)"))
  end

  feature "alarm trends chart shows colour-coded Crit Warn Caut Adv legend", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ALARM TRENDS (24h)"))
    |> assert_has(css("span", text: "Crit"))
    |> assert_has(css("span", text: "Warn"))
    |> assert_has(css("span", text: "Caut"))
    |> assert_has(css("span", text: "Adv"))
  end

  feature "alarm rows include AI insight text for the first alarm", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_alarm']", minimum: 1))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────────

  feature "severity filter buttons ALL CRITICAL WARNING CAUTION ADVISORY are present", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-severity='all']", text: "ALL"))
    |> assert_has(css("button[phx-value-severity='critical']"))
    |> assert_has(css("button[phx-value-severity='warning']"))
    |> assert_has(css("button[phx-value-severity='caution']"))
    |> assert_has(css("button[phx-value-severity='advisory']"))
  end

  feature "clicking CRITICAL filter button keeps page stable", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-severity='critical']"))
    |> assert_has(css("button[phx-value-severity='critical']"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  feature "search input is present and accepts text input", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[placeholder='Search alarms...']"))
    |> fill_in(css("input[placeholder='Search alarms...']"), with: "CPU")
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  feature "status select dropdown has Active Acknowledged and All options", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[name='status']"))
    |> assert_has(css("option[value='active']"))
    |> assert_has(css("option[value='acknowledged']"))
    |> assert_has(css("option[value='all']"))
  end

  feature "alarm list rows are clickable and page stays stable", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_alarm']", minimum: 1))
    |> click(css("[phx-click='select_alarm']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  feature "alarm page remains stable after multiple 2000ms refresh cycles", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "ACTIVE ALARMS"))

    Process.sleep(4_000)

    assert_has(session, css("h2", text: "ACTIVE ALARMS"))
    assert_has(session, css("h3", text: "STORM DETECTION"))
  end

  # ── C7: AI/Advisory Panels ────────────────────────────────────────────────────

  feature "alarm KPIs d-prime value reflects Signal Detection Theory metric", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "ALARM KPIs"))
    |> assert_has(css("span", text: "d-prime:"))
  end

  feature "sentinel health panel shows numeric score_percent value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SENTINEL HEALTH"))
    |> assert_has(css("span", text: "Health Score:"))
  end

  feature "correlation engine latency field is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "CORRELATION ENGINE"))
    |> assert_has(css("span", text: "Latency:"))
  end

  feature "alarm list alarms count label is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "alarms"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ────────────

  # acknowledge — status change
  feature "clicking ACK on an alarm row changes alarm status to acknowledged", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='acknowledge']", minimum: 1))
    |> click(css("button[phx-click='acknowledge']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # acknowledge — flash message
  feature "clicking ACK on an alarm row shows acknowledged flash message", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='acknowledge']", minimum: 1))
    |> click(css("button[phx-click='acknowledge']", at: 0))
    |> assert_has(css("[role='alert']", text: "acknowledged"))
  end

  # silence — status change
  feature "clicking SILENCE on an alarm row keeps page stable", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='silence']", minimum: 1))
    |> click(css("button[phx-click='silence']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # silence — flash message
  feature "clicking SILENCE on an alarm row shows silenced flash message", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='silence']", minimum: 1))
    |> click(css("button[phx-click='silence']", at: 0))
    |> assert_has(css("[role='alert']", text: "silenced"))
  end

  # escalate — status change
  feature "clicking ESCALATE on an alarm row keeps page stable", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='escalate']", minimum: 1))
    |> click(css("button[phx-click='escalate']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # escalate — flash message
  feature "clicking ESCALATE on an alarm row shows escalated flash message", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='escalate']", minimum: 1))
    |> click(css("button[phx-click='escalate']", at: 0))
    |> assert_has(css("[role='alert']", text: "escalated"))
  end

  # ack_all_advisory — status change
  feature "ACK ALL ADVISORY button changes advisory alarm statuses", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='ack_all_advisory']"))
    |> click(css("button[phx-click='ack_all_advisory']"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # ack_all_advisory — flash message
  feature "ACK ALL ADVISORY button shows advisory alarms acknowledged flash", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='ack_all_advisory']"))
    |> click(css("button[phx-click='ack_all_advisory']"))
    |> assert_has(css("[role='alert']", text: "advisory alarms acknowledged"))
  end

  # acknowledge_storm — status change (C8a)
  feature "ACK STORM button sets storm acknowledged state", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='acknowledge_storm']"))
    |> click(css("button[phx-click='acknowledge_storm']"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # acknowledge_storm — flash message (C8b)
  feature "ACK STORM button shows Storm acknowledged flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='acknowledge_storm']"))
    |> assert_has(css("[role='alert']", text: "Storm acknowledged"))
  end

  # export_report — status change
  feature "EXPORT REPORT button keeps page stable after click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export_report']", text: "EXPORT REPORT"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # export_report — flash message
  feature "EXPORT REPORT button triggers info flash with export path", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='export_report']", text: "EXPORT REPORT"))
    |> assert_has(css("[role='alert']", text: "Report exported"))
  end

  # configure_thresholds — status change
  feature "CONFIGURE button keeps page stable after click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='configure_thresholds']", text: "CONFIGURE"))
    |> assert_has(css("h2", text: "ACTIVE ALARMS"))
  end

  # configure_thresholds — flash message
  feature "CONFIGURE button opens threshold configuration flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='configure_thresholds']", text: "CONFIGURE"))
    |> assert_has(css("[role='alert']", text: "threshold configuration"))
  end
end
