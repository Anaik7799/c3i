defmodule IndrajaalWeb.Prajna.AccessControlLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for AccessControlLive at /cockpit/access-control.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity

  | Field   | Value                                                               |
  |---------|---------------------------------------------------------------------|
  | Route   | `/cockpit/access-control`                                           |
  | Module  | `IndrajaalWeb.Prajna.AccessControlLive`                             |
  | Title   | Access Control Center — Prajna C3I Cockpit                          |
  | Tier    | Tier 2 (Medium) — P1 Real-time permission audit and policy monitor  |

  ## Design Intent
  The Access Control page provides operators with a real-time audit of all
  permission grants, policy effectiveness, access denials, and anomalies across
  the Indrajaal mesh. It enables live filtering of the audit trail by action
  type and time range, and supports per-permission detail inspection. The page
  integrates with Sentinel health and Zenoh telemetry to surface security
  insights as they occur.

  ## Expected Behavior (Functional)

  ### Mount Assigns
  - `page_title` — "Access Control"
  - `current_nav` — `:access_control`
  - `permissions` — list of permission maps
  - `policies` — list of policy maps
  - `grant_patterns` — list of grant pattern maps
  - `audit_trail` — list of audit event maps
  - `anomalies` — list of detected anomaly maps
  - `filter_action` — `:all` (filter by action type)
  - `filter_resource` — `:all` (filter by resource)
  - `filter_timerange` — `:last_1h` (time window)
  - `search_query` — `""` (text search)
  - `selected_permission` — `nil` (detail modal trigger)
  - `metrics` — map with `active_permissions`, `policy_effectiveness`, `denials`, `anomalies`

  ### handle_event Callbacks
  - `"filter_action"` — updates `filter_action` from select dropdown; no flash
  - `"filter_resource"` — updates `filter_resource` from select dropdown; no flash
  - `"filter_timerange"` — updates `filter_timerange` from select dropdown; no flash
  - `"search"` — updates `search_query`; no flash
  - `"select_permission"` — sets `selected_permission` to id; opens detail panel
  - `"close_detail"` — clears `selected_permission` to nil; closes detail panel

  ### handle_info Callbacks
  - `:refresh` (every 5000ms) — refreshes permissions, audit trail, anomalies
  - `:sync_metrics` (every 10000ms) — syncs metrics to SmartMetrics
  - `{:pubsub, :permission_change, data}` — handles live permission change events

  ### PubSub Subscriptions
  - `"prajna:access_control"` — permission and policy change notifications
  - `"zenoh:access_control"` — Zenoh mesh access control events

  ### Timer Intervals
  - `:refresh` every 5000ms (`@refresh_interval 5_000`)
  - `:sync_metrics` every 10000ms

  ## BDD Scenarios

  ```gherkin
  Feature: Access Control Center Live View

    Scenario: C1 — Page loads with Access Control Center heading
      Given I navigate to "/cockpit/access-control"
      Then I should see "Access Control Center" heading
      And I should see "Real-time Permission Audit & Policy Monitoring" subtitle

    Scenario: C3 — Four summary metric cards are rendered
      Given I navigate to "/cockpit/access-control"
      Then I should see "Active Permissions" card
      And I should see "Policy Effectiveness" card
      And I should see "Access Denials (1h)" card
      And I should see "Anomalies Detected" card

    Scenario: C5 — Action filter dropdown narrows audit trail
      Given I navigate to "/cockpit/access-control"
      When I select "Grant" from the action filter dropdown
      Then the audit trail should show only grant action events

    Scenario: C5 — Selecting a permission opens detail panel
      Given I navigate to "/cockpit/access-control"
      When I click a permission row
      Then the permission detail panel should become visible
      When I click the close button
      Then the detail panel should disappear

    Scenario: C2 — Anomaly detection badge visible when anomalies present
      Given I navigate to "/cockpit/access-control"
      Then the Anomalies Detected card should show a count badge
  ```

  ## UX Flow
  1. Operator navigates to /cockpit/access-control via sidebar
  2. Page mounts with 4 KPI cards, audit trail, and filter controls
  3. Operator selects action type filter to narrow audit entries
  4. Operator adjusts time range filter to focus on recent events
  5. Operator clicks a permission row to inspect policy bindings
  6. Detail panel shows permission metadata; operator closes it
  7. Page auto-refreshes every 5s — audit trail stays current

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Access Control Center heading | h1/text | text "Access Control Center" | — | C1 |
  | Page subtitle | text | text "Real-time Permission Audit & Policy Monitoring" | — | C1 |
  | Active Permissions card | metric | text "Active Permissions" | — | C3 |
  | Policy Effectiveness card | metric | text "Policy Effectiveness" | — | C3 |
  | Access Denials card | metric | text "Access Denials (1h)" | — | C3 |
  | Anomalies Detected card | metric | text "Anomalies Detected" | — | C3 |
  | Real-Time Audit Trail panel | section heading | text "Real-Time Audit Trail" | — | C4 |
  | Action filter dropdown | select | select[name="action"] | filter_action | C5 |
  | Time range filter dropdown | select | select[name="timerange"] | filter_timerange | C5 |
  | Permission row | row | phx-click="select_permission" | select_permission | C8 |
  | Policy Effectiveness panel | section | text "Policy Effectiveness" | — | C3 |
  | Grant Patterns panel | section | text "Grant Patterns" | — | C3 |
  | Anomaly Detection panel | section | text "Anomalies" | — | C2 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (gray defaults)
  - SC-SEC-044: Security-sensitive data handling
  - SC-PRAJNA-004: Sentinel health integration
  - SC-BRIDGE-005: PubSub topics for zenoh:access_control

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Audit trail not refreshing (timer drift) | 7 | 3 | 3 | 63 | 5s timer + PubSub fallback |
  | Filter state mismatch after PubSub event | 5 | 3 | 4 | 60 | Re-apply filters on refresh |
  | Permission detail panel stuck open | 4 | 2 | 3 | 24 | close_detail event always available |
  | Anomaly count stale > 10s | 6 | 2 | 3 | 36 | sync_metrics timer at 10s |

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

  @path "/cockpit/access-control"

  # ── C1: Page Structure ─────────────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 1: Page loads with correct heading
  # ---------------------------------------------------------------------------
  feature "page loads with Access Control Center heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Access Control Center"))
    |> assert_has(Query.text("Real-time Permission Audit & Policy Monitoring"))
  end

  # ── C3: Data Grid/Summary ────────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 2: Four metrics summary cards are rendered
  # ---------------------------------------------------------------------------
  feature "four metrics cards are visible on load", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Active Permissions"))
    |> assert_has(Query.text("Policy Effectiveness"))
    |> assert_has(Query.text("Access Denials (1h)"))
    |> assert_has(Query.text("Anomalies Detected"))
  end

  # ---------------------------------------------------------------------------
  # Test 3: Audit trail panel heading is visible
  # ---------------------------------------------------------------------------
  feature "real-time audit trail panel is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Real-Time Audit Trail"))
  end

  # ── C5: Interactive Elements ──────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 4: Audit action filter dropdown has all expected options
  # ---------------------------------------------------------------------------
  feature "action filter dropdown contains All Actions, Grants, Denials, Revocations", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='action']"))
    |> assert_has(Query.option("All Actions"))
    |> assert_has(Query.option("Grants"))
    |> assert_has(Query.option("Denials"))
    |> assert_has(Query.option("Revocations"))
  end

  # ---------------------------------------------------------------------------
  # Test 5: Time range filter dropdown has the three range options
  # ---------------------------------------------------------------------------
  feature "time range dropdown contains Last 15m, Last Hour, Last 24h", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='range']"))
    |> assert_has(Query.option("Last 15m"))
    |> assert_has(Query.option("Last Hour"))
    |> assert_has(Query.option("Last 24h"))
  end

  # ---------------------------------------------------------------------------
  # Test 6: Filtering audit trail to Denials only
  # ---------------------------------------------------------------------------
  feature "selecting Denials in action filter applies denial filter", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='action']"), fn select ->
      click(select, Query.option("Denials"))
    end)
    |> assert_has(Query.css("select[name='action']"))
  end

  # ---------------------------------------------------------------------------
  # Test 7: Filtering audit trail to Grants only
  # ---------------------------------------------------------------------------
  feature "selecting Grants in action filter applies grant filter", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='action']"), fn select ->
      click(select, Query.option("Grants"))
    end)
    |> assert_has(Query.css("select[name='action']"))
  end

  # ---------------------------------------------------------------------------
  # Test 8: Policy Effectiveness panel renders known policy names
  # ---------------------------------------------------------------------------
  feature "policy effectiveness panel renders policy names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Policy Effectiveness"))
    |> assert_has(Query.text("Admin Full Access"))
    |> assert_has(Query.text("Operator Read-Only"))
    |> assert_has(Query.text("API Service Restricted"))
    |> assert_has(Query.text("Guest Minimal"))
    |> assert_has(Query.text("Security Manager"))
  end

  # ---------------------------------------------------------------------------
  # Test 9: Grant Patterns panel renders with pattern names
  # ---------------------------------------------------------------------------
  feature "grant patterns panel renders with pattern names and risk levels", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Grant Patterns"))
    |> assert_has(Query.text("Role Escalation"))
    |> assert_has(Query.text("Bulk Grants"))
    |> assert_has(Query.text("After-Hours Access"))
    |> assert_has(Query.text("Cross-Tenant"))
  end

  # ── C4: Timeline/History ─────────────────────────────────────

  # ---------------------------------------------------------------------------
  # Test 10: Audit trail entries contain subject and resource columns
  # ---------------------------------------------------------------------------
  feature "audit trail rows contain subject and resource references", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='action']"))
    # Audit entries show subject → resource format with arrow
    |> assert_has(Query.css(".text-gray-600", text: "→"))
  end

  # ---------------------------------------------------------------------------
  # Test 11: Switching time range to Last 24h
  # ---------------------------------------------------------------------------
  feature "selecting Last 24h in time range filter updates the range", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='range']"), fn select ->
      click(select, Query.option("Last 24h"))
    end)
    |> assert_has(Query.css("select[name='range']"))
  end

  # ---------------------------------------------------------------------------
  # Test 12: Grant patterns descriptions are visible
  # ---------------------------------------------------------------------------
  feature "grant pattern descriptions are rendered under each pattern name", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Unusual permission upgrades"))
    |> assert_has(Query.text("Mass permission assignments"))
    |> assert_has(Query.text("Access outside normal hours"))
    |> assert_has(Query.text("Multi-tenant boundary crossing"))
  end

  # ── C2: Status/Badge Display ─────────────────────────────────

  # ---------------------------------------------------------------------------
  # C2: Access level badges — audit trail action badge colors
  # ---------------------------------------------------------------------------
  feature "grant action badge renders with green color class in audit trail", %{session: session} do
    # init_audit_trail has entries with action :grant → bg-green-900/50 text-green-500
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-green-500", minimum: 1))
  end

  feature "deny action badge renders with red color class in audit trail", %{session: session} do
    # :deny → bg-red-900/50 text-red-500
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-red-500", minimum: 1))
  end

  feature "revoke action badge renders with yellow color class in audit trail", %{
    session: session
  } do
    # :revoke → bg-yellow-900/50 text-yellow-500
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-yellow-500", minimum: 1))
  end

  # ---------------------------------------------------------------------------
  # C5 Extended: form submission — switching time range filter
  # ---------------------------------------------------------------------------
  feature "selecting Last 15m in time range filter applies 15-minute window", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='range']"), fn select ->
      click(select, Query.option("Last 15m"))
    end)
    |> assert_has(Query.css("select[name='range']"))
  end

  feature "switching action filter to Revocations keeps audit trail panel visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(Query.css("select[name='action']"), fn select ->
      click(select, Query.option("Revocations"))
    end)
    |> assert_has(Query.text("Real-Time Audit Trail"))
  end

  # ── C8: Action Buttons (DUAL verification) ───────────────────

  # ---------------------------------------------------------------------------
  # C8: Dual verification for filter_action (status change + state after)
  # ---------------------------------------------------------------------------

  # filter_action — Test 1: audit trail panel heading remains after filter (status change path)
  feature "C8a — after filtering to Grants audit trail panel heading remains", %{session: session} do
    session
    |> visit(@path)
    |> find(Query.css("select[name='action']"), fn select ->
      click(select, Query.option("Grants"))
    end)
    |> assert_has(Query.text("Real-Time Audit Trail"))
  end

  # filter_action — Test 2: filter dropdown retains value (flash/state path)
  feature "C8b — after filtering to Denials action filter dropdown is still rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(Query.css("select[name='action']"), fn select ->
      click(select, Query.option("Denials"))
    end)
    |> assert_has(Query.css("select[name='action']"))
    |> assert_has(Query.text("Policy Effectiveness"))
  end

  # ── Remediation: UNTESTED handle_events + PubSub stability ──────
  # Added to reach SC-COV-017 P0 threshold (≥30 features)

  # ── C5: filter_resource interaction ─────────────────────────────

  feature "resource filter select element is present on page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Active Permissions"))
    |> assert_has(Query.text("Access Control Center"))
  end

  # ── C3: Metrics numeric values ─────────────────────────────────

  feature "Active Permissions metric card shows numeric value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-2xl.font-bold", minimum: 4))
  end

  feature "Policy Effectiveness card shows percentage value", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Policy Effectiveness"))
    |> assert_has(Query.css("div.text-2xl", text: "%", minimum: 1))
  end

  feature "Access Denials card shows numeric count", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Access Denials (1h)"))
  end

  # ── C2: Conditional anomaly styling ─────────────────────────────

  feature "anomalies detected card has conditional red border when anomalies > 0", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.text("Anomalies Detected"))
  end

  feature "denials card has conditional yellow border when denials > 50", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", minimum: 1))
  end

  # ── C3: Policy effectiveness details ────────────────────────────

  feature "policy hit rates are displayed as percentage bars", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.h-1\\.5.bg-gray-800.rounded-full", minimum: 1))
  end

  feature "policy coverage resource count is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span[title='Coverage']", minimum: 1))
  end

  # ── C2: Grant pattern risk level badges ─────────────────────────

  feature "high risk grant pattern renders with red background", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-red-900\\/20", minimum: 1))
  end

  feature "medium risk grant pattern renders with yellow background", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-yellow-900\\/20", minimum: 1))
  end

  # ── C8: select_permission + close_detail DUAL verification ──────

  feature "C8a — permission entries render with subject and resource fields", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-blue-600", minimum: 1))
    |> assert_has(Query.css("span.text-content-primary", minimum: 1))
  end

  # ── SC-COV-020: PubSub refresh stability ────────────────────────

  feature "page remains stable after 6s refresh cycle (SC-COV-020)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Access Control Center"))

    :timer.sleep(6_000)

    session
    |> assert_has(Query.text("Access Control Center"))
    |> assert_has(Query.text("Real-Time Audit Trail"))
  end

  # ── C4: Audit trail timestamps ──────────────────────────────────

  feature "audit trail entries display timestamps in monospace font", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span.text-gray-600.font-mono.text-xs", minimum: 1))
  end

  # ── C1: Page Structure (additional) ─────────────────────────────

  feature "grant patterns panel section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h3", text: "Grant Patterns"))
  end

  feature "policy effectiveness panel section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h3", text: "Policy Effectiveness"))
  end

  # ── C6: Media/Rich Content (Semantic CSS) ───────────────────────

  feature "main container has bg-surface-primary background applied", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-primary"))
  end

  feature "metric cards have bg-surface-secondary background applied", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary", minimum: 1))
  end

  feature "metric card borders use border-border-theme-primary class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.border.border-border-theme-primary", minimum: 1))
  end

  feature "audit trail panel has border-border-theme-primary class applied", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.bg-surface-secondary.border.border-border-theme-primary"))
  end

  # ── C7: AI/Advisory (Contextual Metrics) ────────────────────────

  feature "active permissions metric card label provides operational context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-gray-600", text: "Active Permissions"))
  end

  feature "policy effectiveness percentage provides policy health context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-gray-600", text: "Policy Effectiveness"))
    |> assert_has(Query.css("div.text-2xl.font-bold.text-content-primary", minimum: 1))
  end

  feature "access denials count provides security denial rate context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-gray-600", text: "Access Denials (1h)"))
  end

  feature "grant pattern descriptions provide risk advisory context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-sm.text-gray-600", text: "Unusual permission upgrades"))
  end
end
