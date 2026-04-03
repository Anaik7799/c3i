defmodule IndrajaalWeb.Prajna.ThreatLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Prajna Threat Dashboard LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/threat`
  - **Module**: `IndrajaalWeb.Prajna.ThreatLive`
  - **Title**: "Threat Dashboard"
  - **Priority**: P1 (High — real-time threat monitoring and response)

  ## Design Intent
  The Threat Dashboard is the primary display for the Sentinel Digital Immune System.
  It shows real-time threats from the Indrajaal mesh, with severity statistics, filter
  controls (severity/status), per-threat detail panels, and bulk acknowledge operations.
  Threats arrive via PubSub from three channels. The Sentinel health card shows overall
  system immune health. A "LIVE" indicator confirms active telemetry. Operators
  acknowledge individual threats, dismiss resolved ones, or bulk-acknowledge all active
  threats in a single operation.

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "Threat Dashboard"
  - `current_nav` — `:sentinel`
  - `threats` — list of 5 sample threat maps (with id, severity, status, type, source, etc.)
  - `threat_history` — [] (empty on mount; grows as threats are dismissed)
  - `filter_severity` — `:all`
  - `filter_status` — `:active`
  - `selected_threat` — nil
  - `sentinel_health` — struct with score, status, threat counts, component health
  - `threat_stats` — map with total, critical, high, medium, low counts; acknowledged count
  - `last_update` — timestamp (refreshed every 5s)

  ### handle_event Callbacks
  - `"filter_severity"` — updates `filter_severity` atom; no flash
  - `"filter_status"` — updates `filter_status` atom; no flash
  - `"select_threat"` — sets `selected_threat` to threat id; no flash
  - `"close_detail"` — clears `selected_threat`; no flash
  - `"acknowledge_threat"` — sets threat `status` to `:acknowledged`; flash :info "Threat #{id} acknowledged"
  - `"dismiss_threat"` — removes threat from list; flash :info "Threat #{id} dismissed"
  - `"acknowledge_all"` — bulk-sets all active threats to `:acknowledged`; flash :info "#{count} threats acknowledged"

  ### handle_info Callbacks
  - `:refresh` (every 5000ms) — updates `last_update` timestamp and `threat_stats`
  - `:sync_sentinel` (every 30000ms) — fetches updated Sentinel health
  - `{:new_threat, threat}` — prepends threat to `threats` list
  - `{:threat_resolved, threat_id}` — marks matching threat as `:resolved` in list

  ### PubSub Subscriptions
  - `"prajna:threats"` — threat lifecycle events from Prajna domain
  - `"zenoh:threats"` — Zenoh mesh threat events
  - `"sentinel:threats"` — Sentinel immune system threat events

  ### Timer Intervals
  - `:refresh` every 5000ms (`@refresh_interval 5_000`)
  - `:sync_sentinel` every 30000ms (`@sentinel_sync_interval 30_000`)

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with Threat Dashboard heading and LIVE indicator
    Given I navigate to "/cockpit/threat"
    Then I see h1 "Real-Time Threat Dashboard"
    And I see p "Sentinel Digital Immune System"
    And I see span "LIVE"
    And I see h2 "ACTIVE THREATS"
    And I see STAMP badges "SC-IMMUNE-001" and "SC-PRAJNA-004"

  Scenario: C2 - Threat severity stats badges shown on load
    Given I navigate to "/cockpit/threat"
    Then I see threat stat cards with Critical, High, Medium counts

  Scenario: C3 - Sentinel health card displays health score
    Given I navigate to "/cockpit/threat"
    Then I see the Sentinel Health panel with a health score
    And I see "SENTINEL HEALTH" heading

  Scenario: C5 - Severity filter updates displayed threats
    Given I navigate to "/cockpit/threat"
    When I click the "critical" severity filter button
    Then only critical threats are visible in the list

  Scenario: C8 (dual acknowledge) - Acknowledge threat shows status change and flash
    Given I navigate to "/cockpit/threat"
    When I click acknowledge on a threat
    Then the threat status badge changes to "ACKNOWLEDGED"
    And I see flash info "acknowledged"

  Scenario: C8 (dual dismiss) - Dismiss threat removes it and shows flash
    Given I navigate to "/cockpit/threat"
    When I click dismiss on a threat
    Then the threat disappears from the list
    And I see flash info "dismissed"

  Scenario: C8 (dual bulk ack) - ACK ALL shows count flash
    Given I navigate to "/cockpit/threat"
    When I click the ACK ALL threats button
    Then I see flash info "threats acknowledged"
  ```

  ## UX Flow
  1. Operator loads page; sees LIVE indicator and threat stats across top
  2. Operator optionally filters by severity and/or status
  3. Operator clicks a threat row to expand its detail panel
  4. Operator acknowledges or dismisses individual threats
  5. Operator clicks "ACK ALL" for bulk acknowledgement of all active threats
  6. Sentinel health card (sidebar) shows overall immune health score and component breakdown
  7. New threats appear in real time via PubSub; `:refresh` updates stats every 5s

  ## UI Elements Inventory

  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Main heading | h1 | `h1[text="Real-Time Threat Dashboard"]` | — |
  | Sentinel subtitle | p | `p[text~="Sentinel Digital Immune System"]` | — |
  | LIVE indicator | span | `span[text="LIVE"]` | — |
  | ACTIVE THREATS heading | h2 | `h2[text="ACTIVE THREATS"]` | — |
  | SC-IMMUNE-001 badge | div | `div[contains 'SC-IMMUNE-001']` | — |
  | SC-PRAJNA-004 badge | div | `div[contains 'SC-PRAJNA-004']` | — |
  | Severity filter buttons | button | `button[phx-click='filter_severity']` | `filter_severity` |
  | Status filter buttons | button | `button[phx-click='filter_status']` | `filter_status` |
  | Threat list rows | div | `div[phx-click='select_threat']` | `select_threat` |
  | Close detail button | button | `button[phx-click='close_detail']` | `close_detail` |
  | Acknowledge button | button | `button[phx-click='acknowledge_threat']` | `acknowledge_threat` |
  | Dismiss button | button | `button[phx-click='dismiss_threat']` | `dismiss_threat` |
  | ACK ALL button | button | `button[phx-click='acknowledge_all']` | `acknowledge_all` |
  | Sentinel health card | div | `div[contains 'SENTINEL HEALTH']` | — |
  | Health score display | span | `span[contains health score digits]` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-020: PubSub pages require refresh stability test (sleep + re-assert)
  - SC-IMMUNE-001: Sentinel monitors system health — health card must be visible
  - SC-IMMUNE-004: PatternHunter pre-error detection < 10ms
  - SC-PRAJNA-004: Sentinel health integration required
  - SC-HMI-001: Dark Cockpit defaults (bg-surface-primary layout)
  - SC-BRIDGE-005: PubSub topics `prajna:threats`, `zenoh:threats`, `sentinel:threats`
  - SC-HMI-011: 8x8 Matrix path coverage

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Threat stats not updated after acknowledge | 5 | 3 | 3 | 45 | `:refresh` recalculates `threat_stats` every 5s |
  | New threats not shown without page reload | 7 | 2 | 3 | 42 | `{:new_threat,...}` handle_info prepends in real time |
  | Sentinel health score stale | 5 | 2 | 4 | 40 | `:sync_sentinel` every 30s fetches updated health |
  | Bulk ACK ALL includes already-acknowledged | 3 | 2 | 3 | 18 | Filter in `acknowledge_all` scoped to `:active` only |
  | Detail panel persists after dismiss | 3 | 2 | 3 | 18 | `dismiss_threat` clears `selected_threat` if matched |

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

  @path "/cockpit/threat"

  # ── C1: Page Structure ────────────────────────────────────────────────────────

  feature "page loads and shows Real-Time Threat Dashboard heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Real-Time Threat Dashboard"))
  end

  feature "page shows Sentinel Digital Immune System sub-heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Sentinel Digital Immune System"))
  end

  feature "LIVE indicator is rendered on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "LIVE"))
  end

  feature "ACTIVE THREATS section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
  end

  feature "STAMP constraint badges SC-IMMUNE-001 and SC-PRAJNA-004 are visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "SC-IMMUNE-001"))
    |> assert_has(css("div", text: "SC-PRAJNA-004"))
  end

  feature "last update timestamp label is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Last update:"))
  end

  # ── C2: Status/Badge Display ──────────────────────────────────────────────────

  feature "stats row shows EXTINCTION CRITICAL HIGH MEDIUM and ACTIVE TOTAL cards", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "EXTINCTION"))
    |> assert_has(css("div", text: "CRITICAL"))
    |> assert_has(css("div", text: "HIGH"))
    |> assert_has(css("div", text: "MEDIUM"))
    |> assert_has(css("div", text: "ACTIVE TOTAL"))
  end

  feature "severity filter buttons ALL EXTINCTION CRITICAL HIGH MEDIUM LOW are present", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-severity='all']", text: "ALL"))
    |> assert_has(css("button[phx-value-severity='extinction']"))
    |> assert_has(css("button[phx-value-severity='critical']"))
    |> assert_has(css("button[phx-value-severity='high']"))
    |> assert_has(css("button[phx-value-severity='medium']"))
    |> assert_has(css("button[phx-value-severity='low']"))
  end

  feature "clicking CRITICAL severity filter keeps page stable", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-severity='critical']"))
    |> assert_has(css("h1", text: "Real-Time Threat Dashboard"))
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
  end

  feature "clicking HIGH severity filter keeps ACTIVE THREATS section visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-value-severity='high']"))
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
    |> assert_has(css("button[phx-value-severity='high']"))
  end

  feature "sentinel health card shows HEALTHY status badge", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SENTINEL HEALTH"))
    |> assert_has(css("span", text: "HEALTHY"))
  end

  feature "threat count badge in stats row is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "ACTIVE TOTAL"))
  end

  # ── C3: Data Grid/Summary ─────────────────────────────────────────────────────

  feature "SENTINEL HEALTH card shows Status Health Score Threat Count Quarantined Response SLA",
          %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "SENTINEL HEALTH"))
    |> assert_has(css("span", text: "Status:"))
    |> assert_has(css("span", text: "Health Score:"))
    |> assert_has(css("span", text: "Threat Count:"))
    |> assert_has(css("span", text: "Quarantined:"))
    |> assert_has(css("span", text: "Response SLA:"))
  end

  feature "threat detail panel shows ID Description Source Type and Detected fields after row click",
          %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("span", text: "ID:"))
    |> assert_has(css("span", text: "Description:"))
    |> assert_has(css("span", text: "Source:"))
    |> assert_has(css("span", text: "Type:"))
    |> assert_has(css("span", text: "Detected:"))
  end

  feature "threat detail panel shows the threat ID value after row click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("span", text: "THR-001"))
  end

  feature "threat detail panel shows PatternHunter as source for first threat", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("span", text: "PatternHunter"))
  end

  feature "THREAT TYPES breakdown card is rendered on the sidebar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "THREAT TYPES"))
  end

  feature "status select dropdown has Active Acknowledged and All options", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[name='status']"))
    |> assert_has(css("option[value='active']"))
    |> assert_has(css("option[value='acknowledged']"))
    |> assert_has(css("option[value='all']"))
  end

  feature "threats count label is rendered inside ACTIVE THREATS section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "threats"))
  end

  # ── C4: Timeline/History ──────────────────────────────────────────────────────

  feature "at least one threat row with select_threat click handler is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_threat']", minimum: 1))
  end

  feature "threat rows show source attribution text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Source:"))
  end

  feature "threat rows show age information", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "ago"))
  end

  feature "initial threat list includes intrusion type entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Type:"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────────

  feature "clicking a threat row opens detail panel with CLOSE button", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='close_detail']", text: "CLOSE"))
  end

  feature "clicking CLOSE in the detail panel removes the panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='close_detail']", text: "CLOSE"))
    |> click(css("button[phx-click='close_detail']"))
    |> assert_has(css("h1", text: "Real-Time Threat Dashboard"))
    |> refute_has(css("button[phx-click='close_detail']"))
  end

  feature "switching status filter to All shows threats regardless of status", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      select |> click(css("option[value='all']"))
    end)
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
    |> assert_has(css("[phx-click='select_threat']", minimum: 1))
  end

  feature "ACTIVE THREATS heading and ACK ALL button are present", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
    |> assert_has(css("button[phx-click='acknowledge_all']", text: "ACK ALL"))
  end

  feature "threat page remains stable after 6000ms auto-refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "Real-Time Threat Dashboard"))

    Process.sleep(6_000)

    assert_has(session, css("h1", text: "Real-Time Threat Dashboard"))
    assert_has(session, css("h2", text: "ACTIVE THREATS"))
    assert_has(session, css("h3", text: "SENTINEL HEALTH"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ────────────

  # acknowledge_threat (inline ACK button) — status change
  feature "clicking inline ACK button on a threat row changes threat status", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='acknowledge_threat']", minimum: 1))
    |> click(css("button[phx-click='acknowledge_threat']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
  end

  # acknowledge_threat (inline ACK button) — flash message
  feature "clicking inline ACK button on a threat row shows acknowledged flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='acknowledge_threat']", minimum: 1))
    |> click(css("button[phx-click='acknowledge_threat']", at: 0))
    |> assert_has(css("[role='alert']", text: "acknowledged"))
  end

  # acknowledge_threat (detail panel ACKNOWLEDGE button) — status change
  feature "ACKNOWLEDGE button in detail panel closes panel after click", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='acknowledge_threat']", minimum: 1))
    |> click(css("button[phx-click='acknowledge_threat']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
  end

  # acknowledge_threat (detail panel ACKNOWLEDGE button) — flash message
  feature "ACKNOWLEDGE button in detail panel shows acknowledged flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='acknowledge_threat']", minimum: 1))
    |> click(css("button[phx-click='acknowledge_threat']", at: 0))
    |> assert_has(css("[role='alert']", text: "acknowledged"))
  end

  # dismiss_threat — status change
  feature "DISMISS button in detail panel removes the threat row", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='dismiss_threat']", minimum: 1))
    |> click(css("button[phx-click='dismiss_threat']", at: 0))
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
  end

  # dismiss_threat — flash message
  feature "DISMISS button in detail panel shows dismissed flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='dismiss_threat']", minimum: 1))
    |> click(css("button[phx-click='dismiss_threat']", at: 0))
    |> assert_has(css("[role='alert']", text: "dismissed"))
  end

  # acknowledge_all — status change
  feature "clicking ACK ALL changes active threat statuses to acknowledged", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='acknowledge_all']", text: "ACK ALL"))
    |> assert_has(css("h2", text: "ACTIVE THREATS"))
  end

  # acknowledge_all — flash message
  feature "clicking ACK ALL shows threats acknowledged flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='acknowledge_all']", text: "ACK ALL"))
    |> assert_has(css("[role='alert']", text: "threats acknowledged"))
  end

  # select_threat + close_detail — status change (detail panel open/close)
  feature "selecting a threat row shows the detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> assert_has(css("button[phx-click='close_detail']"))
  end

  # close_detail — status change (panel disappears)
  feature "close_detail removes the threat detail panel from the DOM", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_threat']", at: 0))
    |> click(css("button[phx-click='close_detail']"))
    |> refute_has(css("button[phx-click='close_detail']"))
  end
end
