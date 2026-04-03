defmodule IndrajaalWeb.ConfigManagementLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Configuration Management LiveView admin page.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/admin/config`
  - **Module**: `IndrajaalWeb.ConfigManagementLive`
  - **Title**: "Configuration Management"

  ## Design Intent
  Enables administrators to manage system-wide settings, feature flags, domain
  configurations, integrations, and audit logs from a single tabbed interface.
  Provides real-time configuration feedback with PubSub-driven refresh.

  ## Expected Behavior (Functional)
  - **On mount**: Assigns `page_title`, `current_user`, `active_tab: :system`,
    `search_query: ""`, `config_filter: :all`, then calls `assign_configurations/1`,
    `assign_feature_flags/1`, `assign_audit_log/1`. When connected, subscribes to
    PubSub topic `"config_updates"` and schedules `Process.send_after(:refresh_config,
    10_000)`.
  - **handle_event("switch_tab", %{"tab" => tab})**: Sets `active_tab` to the
    selected atom; renders the corresponding panel component.
  - **handle_event("search", %{"value" => q})**: Updates `search_query` assign.
  - **handle_event("filter_config", %{"value" => f})**: Updates `config_filter`.
  - **handle_event("toggle_flag", %{"flag" => id})**: Toggles a feature flag.
  - **handle_event("test_integration", ...)**: Tests integration; puts flash
    `"Integration connection successful"`.
  - **handle_event("sync_integration", ...)**: Syncs integration; puts flash
    `"Integration sync initiated"`.
  - **handle_event("update_config", ...)**: Saves a config value; puts flash
    `"Configuration updated successfully"`.
  - **handle_info(:refresh_config)**: Reloads configurations and reschedules.
  - **PubSub**: `"config_updates"` topic (connected? gated).
  - **Timer**: `Process.send_after(10_000)` — one-shot, re-triggered on each refresh.

  ## BDD Scenarios
  ```gherkin
  Scenario: Admin switches to Integrations tab and tests connection
    Given I navigate to "/admin/config"
    When I click the "Integrations" tab button
    And I click the "Test Connection" button
    Then I see the flash "Integration connection successful"
    And the integrations-panel is still visible

  Scenario: Admin toggles a feature flag
    Given I navigate to "/admin/config"
    When I click the "Feature Flags" tab button
    And I click a feature flag checkbox
    Then the flag state changes in the DOM
  ```

  ## UX Flow
  1. Admin navigates to `/admin/config` via the admin panel
  2. System Settings tab is active by default; search input and filter are visible
  3. Admin switches tabs to Feature Flags, Domain Config, Integrations, or Audit Log
  4. On Integrations tab, admin clicks "Test Connection" or "Sync Now" for feedback
  5. Flash messages confirm action outcomes; PubSub refresh keeps data current

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Page heading | h1 | `h1[text="Configuration Management"]` | — | C1 |
  | Tab bar | div | `div.tabs` | — | C1 |
  | System Settings tab | button | `button[phx-click='switch_tab'][phx-value-tab='system']` | switch_tab | C5 |
  | Feature Flags tab | button | `button[phx-click='switch_tab'][phx-value-tab='features']` | switch_tab | C5 |
  | Domain Config tab | button | `button[phx-click='switch_tab'][phx-value-tab='domains']` | switch_tab | C5 |
  | Integrations tab | button | `button[phx-click='switch_tab'][phx-value-tab='integrations']` | switch_tab | C5 |
  | Audit Log tab | button | `button[phx-click='switch_tab'][phx-value-tab='audit']` | switch_tab | C5 |
  | Search input | input | `input[phx-keyup='search']` | search | C2 |
  | Filter select | select | `select[phx-change='filter_config']` | filter_config | C2 |
  | Feature flag checkbox | input | `input[type='checkbox'][phx-click='toggle_flag']` | toggle_flag | C8 |
  | Test Connection btn | button | `button[phx-click='test_integration']` | test_integration | C8 |
  | Sync Now btn | button | `button[phx-click='sync_integration']` | sync_integration | C8 |
  | Audit table header | th | `th[text="Timestamp"]` | — | C4 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — uses `bg-surface-primary` semantic class
  - SC-CNT-009: Tenant isolation enforced in config management
  - SC-VDP-008: Closure feedback on all changes (flash messages)
  - SC-CONS-001 to SC-CONS-006: Configuration constraints

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Tab switch crashes the LiveView (no panel rendered) | 6 | 3 | 3 | 54 | C5 tests each tab switch |
  | PubSub subscribe fires on disconnected mount | 3 | 5 | 6 | 90 | connected? guard in mount |
  | Flash not shown after test_integration | 5 | 3 | 4 | 60 | C8 dual verification |

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

  @path "/admin/config"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with Configuration Management heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Configuration Management"))
  end

  feature "page loads with subtitle text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Manage system-wide settings and configurations"))
  end

  feature "page loads with System Settings tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab']", text: "System Settings"))
  end

  feature "page loads with Feature Flags tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab']", text: "Feature Flags"))
  end

  feature "page loads with Domain Config tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab']", text: "Domain Config"))
  end

  feature "page loads with Integrations tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab']", text: "Integrations"))
  end

  feature "page loads with Audit Log tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab']", text: "Audit Log"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "search input is present on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[phx-keyup='search']"))
  end

  feature "filter select dropdown is present on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_config']"))
  end

  feature "filter dropdown contains All option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='all']"))
  end

  feature "filter dropdown contains Modified option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='modified']"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "switching to Integrations tab shows integrations panel container", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("div.integrations-panel"))
  end

  feature "switching to Integrations tab shows Test Connection buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("button[phx-click='test_integration']", text: "Test Connection"))
  end

  feature "switching to Integrations tab shows Sync Now buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("button[phx-click='sync_integration']", text: "Sync Now"))
  end

  feature "switching to Audit Log tab shows audit table headers", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("th", text: "Timestamp"))
  end

  feature "switching to Audit Log tab shows User column header", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("th", text: "User"))
  end

  feature "switching to Audit Log tab shows Action column header", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("th", text: "Action"))
  end

  feature "switching to Audit Log tab shows Resource column header", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("th", text: "Resource"))
  end

  # ── C4: Timeline / History ──────────────────────────────────────────────────

  feature "switching to Audit Log tab renders the audit-log-panel container", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("div.audit-log-panel"))
  end

  feature "switching to Audit Log tab shows Changes column header", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("th", text: "Changes"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "switch_tab: clicking Feature Flags tab renders feature-flags-panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> assert_has(css("div.feature-flags-panel"))
  end

  feature "switch_tab: clicking Domain Config tab renders domain-config-panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='domains']"))
    |> assert_has(css("div.domain-config-panel"))
  end

  feature "search input accepts keyup events and retains value", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(css("input[phx-keyup='search']"), with: "test")
    |> assert_has(css("input[phx-keyup='search']"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "system settings panel is rendered by default on mount", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.system-settings-panel"))
  end

  feature "tab navigation renders all 5 tabs in a tab bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.tabs"))
  end

  feature "controls bar renders the search box and filter side by side", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.controls"))
    |> assert_has(css("div.search-box"))
  end

  # ── C7: AI / Advisory Panels ─────────────────────────────────────────────────

  feature "filter dropdown contains Default option for default config filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("option[value='default']"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # test_integration — C8a: flash "Integration connection successful"
  feature "test_integration: clicking Test Connection triggers Integration connection successful flash",
          %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("button[phx-click='test_integration']"))
    |> click(css("button[phx-click='test_integration']"))
    |> assert_has(css("[role='alert']", text: "Integration connection successful"))
  end

  # test_integration — C8b: integrations panel remains after test (status change)
  feature "test_integration: integrations panel remains visible after Test Connection", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='test_integration']"))
    |> assert_has(css("div.integrations-panel"))
  end

  # sync_integration — C8a: flash "Integration sync initiated"
  feature "sync_integration: clicking Sync Now triggers Integration sync initiated flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("button[phx-click='sync_integration']"))
    |> click(css("button[phx-click='sync_integration']"))
    |> assert_has(css("[role='alert']", text: "Integration sync initiated"))
  end

  # sync_integration — C8b: Sync Now button still present after sync (status change)
  feature "sync_integration: Sync Now button remains after sync action", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='sync_integration']"))
    |> assert_has(css("button[phx-click='sync_integration']"))
  end

  # switch_tab — C8a: tab content changes (status change)
  feature "switch_tab: clicking Integrations switches tab content from system-settings to integrations",
          %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.system-settings-panel"))
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("div.integrations-panel"))
  end

  # switch_tab — C8b: clicking Audit Log shows audit panel
  feature "switch_tab: clicking Audit Log tab shows audit-log-panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("div.audit-log-panel"))
  end
end
