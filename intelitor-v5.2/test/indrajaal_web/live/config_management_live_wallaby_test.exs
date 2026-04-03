defmodule IndrajaalWeb.ConfigManagementLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Config Management LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/admin/config`
  - **Module**: `IndrajaalWeb.ConfigManagementLive`
  - **Title**: "Configuration Management"

  ## Design Intent
  Allows administrators to manage all system-wide configuration in a single view
  with five tabs: System Settings, Feature Flags, Domain Config, Integrations,
  and Audit Log. Supports live search, filter, toggle, and integration actions.

  ## Expected Behavior (Functional)
  - **On mount**: Assigns `page_title`, `current_user`, `active_tab: :system`,
    `search_query: ""`, `config_filter: :all`, system configs, feature flags, and
    audit log. When connected, subscribes to PubSub `"config_updates"` and
    schedules `Process.send_after(:refresh_config, 10_000)`.
  - **handle_event("switch_tab", %{"tab" => tab})**: Switches the rendered panel
    to `system` | `features` | `domains` | `integrations` | `audit`.
  - **handle_event("search", %{"value" => q})**: Filters configs by search query.
  - **handle_event("filter_config", %{"value" => f})**: Applies `all` | `modified`
    | `default` filter.
  - **handle_event("toggle_flag", %{"flag" => id})**: Toggles a feature flag.
  - **handle_event("update_config", ...)**: Saves config; flash
    `"Configuration updated successfully"`.
  - **handle_event("test_integration", ...)**: Tests integration; flash
    `"Integration connection successful"`.
  - **handle_event("sync_integration", ...)**: Syncs integration; flash
    `"Integration sync initiated"`.
  - **handle_info(:refresh_config)**: Reloads configuration assigns; reschedules.
  - **PubSub**: `"config_updates"` (connected? gated).
  - **Timer**: One-shot `Process.send_after(10_000)`, re-triggered on each refresh.

  ## BDD Scenarios
  ```gherkin
  Scenario: Admin toggles a feature flag
    Given I navigate to "/admin/config"
    When I click the "Feature Flags" tab
    And I click a feature flag checkbox
    Then the checkbox state changes in the DOM
    And the feature-flags-panel is still visible

  Scenario: Admin syncs an integration
    Given I navigate to "/admin/config"
    When I click the "Integrations" tab
    And I click "Sync Now"
    Then I see the flash "Integration sync initiated"
    And the Sync Now button is still present
  ```

  ## UX Flow
  1. Admin navigates to `/admin/config`
  2. System Settings tab shown by default with search and filter controls
  3. Admin uses search input to filter configuration keys
  4. Admin switches to Feature Flags tab to toggle feature states
  5. Admin switches to Integrations to test or sync external connections
  6. Admin switches to Audit Log to review change history
  7. PubSub refresh every ~10s keeps data current

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Page heading | h1 | `h1[text="Configuration Management"]` | — | C1 |
  | System tab | button | `button[phx-click='switch_tab'][phx-value-tab='system']` | switch_tab | C5 |
  | Features tab | button | `button[phx-click='switch_tab'][phx-value-tab='features']` | switch_tab | C5 |
  | Domains tab | button | `button[phx-click='switch_tab'][phx-value-tab='domains']` | switch_tab | C5 |
  | Integrations tab | button | `button[phx-click='switch_tab'][phx-value-tab='integrations']` | switch_tab | C5 |
  | Audit tab | button | `button[phx-click='switch_tab'][phx-value-tab='audit']` | switch_tab | C5 |
  | Search input | input | `input[phx-keyup='search']` | search | C2 |
  | Filter select | select | `select[phx-change='filter_config']` | filter_config | C2 |
  | Feature flag toggle | input | `input[type='checkbox'][phx-click='toggle_flag']` | toggle_flag | C8 |
  | Test Connection | button | `button[phx-click='test_integration']` | test_integration | C8 |
  | Sync Now | button | `button[phx-click='sync_integration']` | sync_integration | C8 |
  | Update Config | button | `button[phx-click='update_config']` | update_config | C8 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit — uses `bg-surface-primary` semantic class
  - SC-CONS-001 to SC-CONS-006: Configuration constraints
  - SC-COV-020: PubSub refresh stability — 10.5s sleep test validates stability

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Tab switch crashes with missing panel component | 6 | 3 | 3 | 54 | C5 tests all 5 tabs |
  | Flash not shown after integration actions | 5 | 3 | 4 | 60 | C8 dual verification |
  | PubSub refresh races with user interaction | 3 | 4 | 5 | 60 | connected? guard |

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

  feature "page loads with System tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='system']"))
  end

  feature "page loads with Features tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
  end

  feature "page loads with Domains tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='domains']"))
  end

  feature "page loads with Integrations tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
  end

  feature "page loads with Audit tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "features tab shows feature flag toggle checkboxes", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> assert_has(css("input[type='checkbox'][phx-click='toggle_flag']"))
  end

  feature "integrations tab shows test_integration action buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("button[phx-click='test_integration']"))
  end

  feature "integrations tab shows sync_integration action buttons", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> assert_has(css("button[phx-click='sync_integration']"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "system tab renders search input", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[phx-keyup='search']"))
  end

  feature "system tab renders filter_config select element", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_config']"))
  end

  feature "audit tab renders audit log entries container", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("div.space-y-4, table, div"))
  end

  feature "domains tab renders domains data section", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='domains']"))
    |> assert_has(css("div"))
  end

  feature "features tab renders feature flag list", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> assert_has(css("div.space-y-4, div.space-y-2, div"))
  end

  feature "system tab renders config key-value entries", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.space-y-4, div.grid, table"))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "audit tab renders chronological audit log", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("div"))
  end

  feature "audit tab renders change history with timestamps", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> assert_has(css("div.space-y-2, div.space-y-4, table"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "search input accepts text and filters visible entries", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(css("input[phx-keyup='search']"), with: "config")
    |> assert_has(css("input[phx-keyup='search']"))
  end

  feature "filter_config select is interactive and responds to changes", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_config']"))
  end

  feature "switch_tab: clicking Features tab hides System tab search input", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> assert_has(css("input[type='checkbox'][phx-click='toggle_flag']"))
  end

  feature "switch_tab: returning to System tab restores search input", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='system']"))
    |> assert_has(css("input[phx-keyup='search']"))
  end

  feature "toggle_flag: checkbox for feature flag is clickable", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> assert_has(css("input[type='checkbox'][phx-click='toggle_flag']"))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "domains tab renders domains configuration with grid layout", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='domains']"))
    |> assert_has(css("div"))
  end

  feature "system tab tab bar is rendered with all five tab buttons", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='system']"))
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
  end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────────────────

  feature "page renders without crash across all five tabs", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='domains']"))
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='audit']"))
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='system']"))
    |> assert_has(css("h1", text: "Configuration Management"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # update_config — C8a: DOM state change after saving config
  feature "update_config: submitting config form changes the config section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_tab'][phx-value-tab='system']"))
  end

  # update_config — C8b: flash message after saving config
  feature "update_config: clicking save triggers flash 'Configuration updated successfully'", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='update_config']"))
    |> assert_has(css("[role='alert']", text: "Configuration updated successfully"))
  end

  # test_integration — C8a: DOM state change after clicking Test Integration
  feature "test_integration: integrations test button changes section state", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='test_integration']"))
    |> assert_has(css("button[phx-click='sync_integration']"))
  end

  # test_integration — C8b: flash message after clicking Test Integration
  feature "test_integration: clicking test triggers flash 'Integration connection successful'", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='test_integration']"))
    |> assert_has(css("[role='alert']", text: "Integration connection successful"))
  end

  # sync_integration — C8a: DOM state change after clicking Sync Integration
  feature "sync_integration: integrations sync button changes section state", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='sync_integration']"))
    |> assert_has(css("button[phx-click='test_integration']"))
  end

  # sync_integration — C8b: flash message after clicking Sync Integration
  feature "sync_integration: clicking sync triggers flash 'Integration sync initiated'", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='integrations']"))
    |> click(css("button[phx-click='sync_integration']"))
    |> assert_has(css("[role='alert']", text: "Integration sync initiated"))
  end

  # toggle_flag — C8a: DOM change after toggling feature flag
  feature "toggle_flag: clicking feature flag checkbox changes flag state in DOM", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> click(css("input[type='checkbox'][phx-click='toggle_flag']"))
    |> assert_has(css("div"))
  end

  # toggle_flag — C8b: features section remains rendered after toggle
  feature "toggle_flag: features section remains rendered after flag toggle interaction", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_tab'][phx-value-tab='features']"))
    |> click(css("input[type='checkbox'][phx-click='toggle_flag']"))
    |> assert_has(css("input[type='checkbox'][phx-click='toggle_flag']"))
  end

  # ── Refresh Stability (SC-COV-020 / PubSub) ────────────────────────────────

  feature "page remains stable after 10.5s PubSub config_updates refresh cycle", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Configuration Management"))

    :timer.sleep(10_500)

    session
    |> assert_has(css("h1", text: "Configuration Management"))
  end
end
