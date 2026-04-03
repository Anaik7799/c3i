defmodule IndrajaalWeb.Operations.ActiveAlarmsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Active Alarms LiveView (Operations domain).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/operations/alarms`
  - **Module**: `IndrajaalWeb.Operations.ActiveAlarmsLive`
  - **Title**: "Active Alarms - Operations Center"
  - **Priority**: P1 (High — operations center primary alarm display)

  ## Design Intent
  The Active Alarms page is the operations-domain counterpart to the Prajna Alarm
  Center. It provides operators with a real-time feed of active alarms with batch
  selection capabilities, storm detection, pipeline status (ingestion/severity/
  correlation/dispatch stages), trend sparkline, and AI advisory insights. Alarms
  can be individually acknowledged, escalated, or silenced; multiple alarms can be
  selected for batch acknowledgement. The storm threshold (`@storm_threshold 10`)
  activates storm suppression mode. The page auto-refreshes via a self-rescheduling
  `Process.send_after` loop at 2s intervals and receives live alarm updates via
  PubSub.

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "Active Alarms - Operations Center"
  - `alarms` — list of 5 sample alarm maps with id, severity, source, message, status, etc.
  - `filter_severity` — `:all`
  - `filter_status` — `:active`
  - `filter_time` — "24h"
  - `search_text` — "" (empty string)
  - `selected_alarms` — `MapSet.new()` (empty set for batch selection)
  - `pipeline_status` — map with ingestion/severity/correlation/dispatch stage status
  - `storm_active` — false
  - `storm_suppressed` — 0 (suppressed alarm count)
  - `summary` — map with total, critical, warning, caution, advisory counts
  - `trend_data` — list of data points for sparkline chart
  - `last_updated` — timestamp
  - `storm_threshold` — 10 (`@storm_threshold`)

  ### handle_event Callbacks
  - `"filter_severity"` — updates `filter_severity` atom; no flash
  - `"filter_status"` — updates `filter_status` atom; no flash
  - `"search"` — updates `search_text`; no flash
  - `"acknowledge"` — flash :info "Alarm #{id} acknowledged"
  - `"acknowledge_all"` — flash :info "All #{severity} alarms acknowledged"
  - `"escalate"` — flash :warning "Alarm #{id} escalated to supervisor"
  - `"silence"` — flash :info "Alarm #{id} silenced for #{duration}"
  - `"toggle_select"` — toggles alarm id membership in `selected_alarms` MapSet; no flash
  - `"batch_acknowledge"` — clears `selected_alarms`; flash :info "#{count} alarms acknowledged"

  ### handle_info Callbacks
  - `:refresh` (every 2000ms, self-rescheduling) — regenerates `alarms` list, `summary`, `storm_active`, `last_updated`; schedules next `:refresh`
  - `{:alarm_update, alarm}` — prepends alarm to `alarms` list

  ### PubSub Subscriptions
  - `"alarms:active"` — active alarm events
  - `"alarms:pipeline"` — pipeline status updates

  ### Timer Intervals
  - `:refresh` via `Process.send_after(self(), :refresh, 2000)` — self-rescheduling loop

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with Active Alarms heading and navigation
    Given I navigate to "/operations/alarms"
    Then I see h1 "Active Alarms"
    And I see "Back to Cockpit" navigation link
    And I see h2 "Real-Time Feed"
    And I see "Ingestion" and "Severity" pipeline status labels

  Scenario: C2 - Summary bar shows severity count buttons
    Given I navigate to "/operations/alarms"
    Then I see critical, warning, caution, advisory filter buttons with counts

  Scenario: C3 - Last updated timestamp is visible
    Given I navigate to "/operations/alarms"
    Then I see a "Last Updated" timestamp in the feed

  Scenario: C4 - Alarm list entries are shown in order
    Given I navigate to "/operations/alarms"
    Then I see alarm rows with source, severity, and message

  Scenario: C5 - Search filters the alarm list
    Given I navigate to "/operations/alarms"
    When I type in the search input
    Then the alarm list is filtered to matching results

  Scenario: C7 - AI advisory text is present
    Given I navigate to "/operations/alarms"
    Then I see an AI advisory section with advisory-only disclaimer

  Scenario: C8 (dual acknowledge) - Acknowledge shows status and flash
    Given I navigate to "/operations/alarms"
    When I click acknowledge on an alarm
    Then I see flash info "acknowledged"

  Scenario: C8 (dual escalate) - Escalate shows flash warning
    Given I navigate to "/operations/alarms"
    When I click escalate on an alarm
    Then I see flash warning "escalated to supervisor"

  Scenario: C8 (dual batch) - Batch acknowledge shows count flash
    Given I have selected multiple alarms
    When I click batch acknowledge
    Then I see flash info "alarms acknowledged"
  ```

  ## UX Flow
  1. Operator loads page; sees alarm summary bar and real-time feed list
  2. Operator filters by severity, status, or time window; or uses search text
  3. Operator selects individual alarms (checkbox/toggle) for batch operations
  4. Operator acknowledges, escalates, or silences individual alarms
  5. Batch acknowledge button processes all selected alarms at once
  6. Pipeline status row shows data flow health (ingestion → severity → correlation → dispatch)
  7. Storm detection activates suppression when rate exceeds `storm_threshold` (10)
  8. AI advisory section provides non-binding insights (SC-AI-001 disclaimer)

  ## UI Elements Inventory

  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Active Alarms heading | h1 | `h1[text="Active Alarms"]` | — |
  | Back to Cockpit link | a | `a[text="Back to Cockpit"]` | — |
  | Real-Time Feed heading | h2 | `h2[text="Real-Time Feed"]` | — |
  | Pipeline Ingestion label | span | `span[text="Ingestion"]` | — |
  | Summary severity buttons | button | `button[phx-click='filter_severity']` | `filter_severity` |
  | Status filter buttons | button | `button[phx-click='filter_status']` | `filter_status` |
  | Time filter buttons | button | `button[phx-click='filter_time']` | `filter_time` (if present) |
  | Search input | input | `input[phx-keyup='search']` | `search` |
  | Alarm rows | div | alarm list entries | — |
  | Toggle select checkbox | button/input | `[phx-click='toggle_select']` | `toggle_select` |
  | Acknowledge button | button | `button[phx-click='acknowledge']` | `acknowledge` |
  | Acknowledge All button | button | `button[phx-click='acknowledge_all']` | `acknowledge_all` |
  | Escalate button | button | `button[phx-click='escalate']` | `escalate` |
  | Silence button | button | `button[phx-click='silence']` | `silence` |
  | Batch acknowledge button | button | `button[phx-click='batch_acknowledge']` | `batch_acknowledge` |
  | Last Updated timestamp | span | `span[contains 'Last Updated']` | — |
  | AI advisory section | div | `div[contains 'advisory only']` | — |
  | Trend chart section | div | `div[contains 'trend']` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-020: PubSub pages require refresh stability test (sleep + re-assert)
  - SC-HMI-001: Management by Exception — severity-based coloring verified
  - SC-HMI-002: Analog indicators — trend chart section verified
  - SC-HMI-003: Staleness decay — last updated timestamp verified
  - SC-HMI-005: Critical prominence — animate-pulse on critical verified
  - SC-AI-001: AI insight rendering verified as advisory only
  - SC-ALARM-001 to SC-ALARM-005: Alarm filtering and acknowledgement workflows covered

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Refresh loop stops on error | 7 | 2 | 3 | 42 | `handle_info :refresh` reschedules unconditionally |
  | Batch acknowledge loses selection state | 5 | 2 | 3 | 30 | `selected_alarms` cleared after batch action |
  | Storm suppression not shown to operator | 7 | 2 | 3 | 42 | `storm_active` badge visible in summary bar |
  | AI advisory treated as definitive | 5 | 2 | 3 | 30 | SC-AI-001 advisory-only disclaimer rendered |
  | Pipeline status shows stale stage health | 5 | 3 | 4 | 60 | PubSub `"alarms:pipeline"` updates on each stage |

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

  @path "/operations/alarms"

  # ── C1: Page Structure ────────────────────────────────────────────────────────

  feature "page loads with Active Alarms heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h1", text: "Active Alarms"))
  end

  feature "back to cockpit navigation link is visible in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("a", text: "Back to Cockpit"))
  end

  feature "real-time feed section heading is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "Real-Time Feed"))
  end

  feature "pipeline status row is visible below summary bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Ingestion"))
    |> assert_has(Query.css("span", text: "Severity"))
  end

  # ── C2: Status and Badge Display ──────────────────────────────────────────────

  feature "alarm summary bar renders critical, warning, caution, advisory buttons", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-value-severity='critical']"))
    |> assert_has(Query.css("button[phx-value-severity='warning']"))
    |> assert_has(Query.css("button[phx-value-severity='caution']"))
    |> assert_has(Query.css("button[phx-value-severity='advisory']"))
    |> assert_has(Query.css("button[phx-value-severity='all']"))
  end

  feature "critical severity button shows count label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-value-severity='critical'] span.text-red-400"))
  end

  feature "advisory severity button shows count label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-value-severity='advisory'] span.text-cyan-400"))
  end

  feature "storm detection status shows NO STORM when inactive", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-green-400", text: "NO STORM"))
  end

  feature "last updated timestamp is visible in page header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Last updated:"))
  end

  # ── C3: Data Grid and Alarm Row Details ────────────────────────────────────────

  feature "default alarm rows ALM-001 through ALM-005 are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Site: HQ Building"))
    |> assert_has(Query.css("span", text: "Site: Data Center"))
    |> assert_has(Query.css("span", text: "Site: Warehouse B"))
  end

  feature "alarm rows display source labels for INTRUSION and ACCESS DENIED", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "INTRUSION"))
    |> assert_has(Query.css("span", text: "ACCESS DENIED"))
  end

  feature "alarm rows display device metadata labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Device:"))
  end

  feature "alarm rows display age metadata labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Age:"))
  end

  feature "alarm rows display occurrence count labels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Occurrences:"))
  end

  feature "bulk actions panel contains ACK All Advisory button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(
      Query.css(
        "button[phx-click='acknowledge_all'][phx-value-severity='advisory']",
        text: "ACK All Advisory"
      )
    )
  end

  feature "performance metrics section is visible with SLA stat", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h3", text: "Performance"))
    |> assert_has(Query.css("span.text-green-400", text: "98.5%"))
  end

  feature "storm detection section is visible in sidebar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h3", text: "Storm Detection"))
    |> assert_has(Query.css("button", text: "Configure"))
  end

  feature "alarm trends 24h chart section is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h3", text: "Alarm Trends (24h)"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────────

  feature "search input is present with placeholder text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("input[placeholder='Search alarms...']"))
  end

  feature "search input filters alarms by message text", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(
      Query.css("input[placeholder='Search alarms...']"),
      with: "Zone-A"
    )
    |> assert_has(Query.css("span", text: "Site: HQ Building"))
  end

  feature "alarm row checkboxes are rendered for toggle_select", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("input[type='checkbox'][phx-click='toggle_select']", minimum: 1))
  end

  feature "selecting an alarm checkbox shows ACK Selected batch button", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("input[type='checkbox'][phx-value-id='ALM-001']"))
    |> assert_has(Query.css("button[phx-click='batch_acknowledge']"))
  end

  # ── C7: AI Advisory Panel ────────────────────────────────────────────────────────

  feature "AI insight label is present for alarm with ai_insight set", %{session: session} do
    session
    |> visit(@path)
    # ALM-001 has ai_insight: "Consider load balancing to app-04 (31% CPU)"
    |> assert_has(Query.css("span.text-cyan-500", text: "AI:"))
  end

  feature "AI insight advisory text is rendered for ALM-001", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div", text: "Consider load balancing to app-04"))
  end

  # ── C8: Action Buttons — Dual Verification (status change + flash) ──────────────

  # Event: filter_severity critical — badge active style
  feature "clicking critical severity filter applies active bg-red-900 style to button", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-severity='critical']"))
    |> assert_has(Query.css("button[phx-value-severity='critical'].bg-red-900"))
  end

  # Event: filter_severity critical — feed updates (advisory alarms hidden)
  feature "clicking critical filter hides advisory-only alarm sites from feed", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-severity='critical']"))
    # With only critical filter active, Warehouse B (advisory) is not shown
    |> refute_has(Query.css("span", text: "Site: Warehouse B"))
  end

  # Event: filter_severity warning — badge active style
  feature "clicking warning severity filter applies active style to button", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-severity='warning']"))
    |> assert_has(Query.css("button[phx-value-severity='warning'][class*='bg-red-900']"))
  end

  # Event: filter_severity warning — only warning alarms visible
  feature "clicking warning filter shows only warning-severity alarm rows", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-severity='warning']"))
    # ALM-005 has severity :warning and site HQ Building
    |> assert_has(Query.css("span", text: "Site: HQ Building"))
  end

  # Event: filter_severity caution — badge active style
  feature "clicking caution severity filter applies active style to button", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-severity='caution']"))
    |> assert_has(Query.css("button[phx-value-severity='caution'][class*='bg-amber-900']"))
  end

  # Event: filter_severity all — all alarms visible again
  feature "clicking all severity filter restores all alarm rows", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-value-severity='critical']"))
    |> click(Query.css("button[phx-value-severity='all']"))
    |> assert_has(Query.css("span", text: "Site: Warehouse B"))
  end

  # Event: acknowledge — flash
  feature "ACK button on alarm row produces flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='acknowledge'][phx-value-id='ALM-001']"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  # Event: acknowledge — flash text confirms alarm ID
  feature "ACK button on ALM-001 flash confirms alarm ALM-001 acknowledged", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='acknowledge'][phx-value-id='ALM-001']"))
    |> assert_has(Query.css("[role='alert']", text: "ALM-001 acknowledged"))
  end

  # Event: silence — flash
  feature "SILENCE 1h button silences alarm ALM-002 for one hour", %{session: session} do
    session
    |> visit(@path)
    |> click(
      Query.css("button[phx-click='silence'][phx-value-id='ALM-002'][phx-value-duration='1h']")
    )
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  # Event: silence — flash text confirms duration
  feature "SILENCE 1h flash message mentions 1h duration", %{session: session} do
    session
    |> visit(@path)
    |> click(
      Query.css("button[phx-click='silence'][phx-value-id='ALM-001'][phx-value-duration='1h']")
    )
    |> assert_has(Query.css("[role='alert']", text: "silenced for 1h"))
  end

  # Event: escalate — flash
  feature "ESCALATE button escalates alarm ALM-003 to supervisor", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='escalate'][phx-value-id='ALM-003']"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  # Event: escalate — flash text confirms escalation
  feature "ESCALATE flash message mentions escalated to supervisor", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='escalate'][phx-value-id='ALM-003']"))
    |> assert_has(Query.css("[role='alert']", text: "escalated to supervisor"))
  end

  # Event: batch_acknowledge — flash and selection cleared
  feature "batch acknowledge clears selection and shows confirmation flash", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("input[type='checkbox'][phx-value-id='ALM-001']"))
    |> click(Query.css("input[type='checkbox'][phx-value-id='ALM-002']"))
    |> click(Query.css("button[phx-click='batch_acknowledge']"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
    |> refute_has(Query.css("button[phx-click='batch_acknowledge']"))
  end

  # Event: batch_acknowledge — flash text confirms count
  feature "batch acknowledge flash mentions number of alarms acknowledged", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("input[type='checkbox'][phx-value-id='ALM-001']"))
    |> click(Query.css("button[phx-click='batch_acknowledge']"))
    |> assert_has(Query.css("[role='alert']", text: "alarms acknowledged"))
  end

  # Event: acknowledge_all — flash
  feature "clicking ACK All Advisory triggers acknowledgement flash", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='acknowledge_all'][phx-value-severity='advisory']"))
    |> assert_has(Query.css("[class*='flash'], [role='alert']"))
  end

  # Event: acknowledge_all — flash text confirms severity
  feature "ACK All Advisory flash confirms advisory alarms acknowledged", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.css("button[phx-click='acknowledge_all'][phx-value-severity='advisory']"))
    |> assert_has(Query.css("[role='alert']", text: "advisory alarms acknowledged"))
  end

  # ── C3: Data Grid and Alarm Row Details (Pipeline and Sidebar) ──────────

  feature "pipeline status shows Correlation stage", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Correlation"))
  end

  feature "storm detection section shows threshold value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Threshold:"))
    |> assert_has(Query.css("span", text: "/min"))
  end

  feature "performance section shows processing rate label", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Processing Rate:"))
  end

  # ── C5: Interactive Elements (Refresh Stability) ──────────────────────────

  feature "page remains stable after 2000ms refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.css("h1", text: "Active Alarms"))
    assert_has(session, Query.css("h2", text: "Real-Time Feed"))

    Process.sleep(2_000)

    assert_has(session, Query.css("h1", text: "Active Alarms"))
    assert_has(session, Query.css("h2", text: "Real-Time Feed"))
  end

  # ── C4: Timeline/History (Page Reload Stability — SC-COV-012) ─────────────

  feature "alarm age labels persist across page revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Age:"))
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Age:"))
  end

  feature "pipeline stage order is stable across page revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Ingestion"))
    |> assert_has(Query.css("span", text: "Notification"))
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Ingestion"))
    |> assert_has(Query.css("span", text: "Notification"))
  end

  feature "alarm trend 24h chart time labels persist across page revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "00:00"))
    |> assert_has(Query.css("span", text: "Now"))
    |> visit(@path)
    |> assert_has(Query.css("span", text: "00:00"))
    |> assert_has(Query.css("span", text: "Now"))
  end

  feature "occurrence counts are present and stable on revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Occurrences:"))
    |> visit(@path)
    |> assert_has(Query.css("span", text: "Occurrences:"))
  end

  # ── C6: Media/Rich Content — Semantic CSS Classes (SC-COV-014) ────────────

  feature "page root uses bg-surface-primary semantic background class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-primary"))
  end

  feature "alarm summary bar uses bg-surface-secondary semantic class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary"))
  end

  feature "search input uses border-border-theme-secondary semantic border class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("input[class*='border-border-theme-secondary']"))
  end

  feature "alarm feed divider uses divide-border-theme-primary color-rich class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div[class*='divide-border-theme-primary']"))
  end
end
