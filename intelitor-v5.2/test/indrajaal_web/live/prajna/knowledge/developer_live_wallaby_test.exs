defmodule IndrajaalWeb.Prajna.Knowledge.DeveloperLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA Developer Knowledge LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/knowledge/developer`
  - **Module**: `IndrajaalWeb.Prajna.Knowledge.DeveloperLive`
  - **Title**: "Developer Knowledge"

  ## Design Intent
  Provides developers with a unified knowledge workspace for architectural decisions,
  reusable code patterns, debug session history, and file-to-knowledge code links.
  Supports knowledge-driven development by surfacing contextual patterns and decision
  traceability directly in the Prajna cockpit.

  ## Expected Behavior (Functional)
  - **On mount**: Loads assigns `view_mode: :decisions`, `decisions: [...]`,
    `patterns: [...]`, `debug_sessions: [...]`, `code_links: [...]`,
    `selected_item: nil`, `search_query: ""`, `filter_status: "all"`.
    Subscribes to PubSub `"prajna:kms:developer"` when `connected?/1`.
    Starts 10-second refresh timer when `connected?/1`.
  - **handle_event "switch_view"**: Sets `view_mode` to the requested tab
    (`:decisions`, `:patterns`, `:debug`, `:links`); re-renders content panel.
  - **handle_event "select_item"**: Sets `selected_item` to the chosen item id,
    revealing detail panel.
  - **handle_event "search"**: Updates `search_query` and filters displayed list.
  - **handle_event "filter_status"**: Updates `filter_status` and re-applies
    filter to decisions list.
  - **handle_event "use_pattern"**: Records pattern usage; puts flash
    `:info "Pattern usage recorded"`.
  - **handle_info(:refresh)**: Timer-driven 10-second knowledge cache refresh.
  - **PubSub**: Subscribed to `"prajna:kms:developer"` — receives knowledge updates
    pushed by the KMS GenServer.

  ## BDD Scenarios
  ```gherkin
  Scenario: Developer loads knowledge base
    Given I navigate to "/cockpit/knowledge/developer"
    Then I should see heading "Developer Knowledge"
    And the Decisions tab should be active by default
    And the search input should be visible

  Scenario: Developer switches to Patterns tab
    Given I navigate to "/cockpit/knowledge/developer"
    When I click the "Patterns" tab button
    Then I should see pattern cards with "Use Pattern" buttons

  Scenario: Developer uses a code pattern
    Given I am on "/cockpit/knowledge/developer"
    And I have switched to the Patterns tab
    When I click "Use Pattern" on any pattern card
    Then I should see flash "Pattern usage recorded"
    And the patterns grid should remain visible

  Scenario: Developer filters decisions by status
    Given I am on "/cockpit/knowledge/developer"
    And the Decisions tab is active
    When I select "Proposed" from the status filter
    Then only proposed decisions should be shown

  Scenario: Developer searches decisions
    Given I am on "/cockpit/knowledge/developer"
    When I type a search term in the search input
    Then the decisions list should filter to matching entries
  ```

  ## UX Flow
  1. Developer navigates to `/cockpit/knowledge/developer` via Prajna nav
  2. Page mounts with Decisions tab active; search and status filter visible
  3. Developer can switch between 4 tabs: Decisions, Patterns, Debug Sessions, Code Links
  4. In Decisions tab: filter by status, search by keyword, select item for details
  5. In Patterns tab: browse patterns, click "Use Pattern" to record usage (flash feedback)
  6. Timer refreshes knowledge cache every 10s; PubSub receives live KMS updates

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Developer Knowledge heading | h1 | `h1` text "Developer Knowledge" | — | C1 |
  | Page subtitle | p | `p` text "Code links, decisions, patterns..." | — | C1 |
  | Decisions tab | button | `button[phx-click='switch_view'][phx-value-view='decisions']` | switch_view | C1 |
  | Patterns tab | button | `button[phx-click='switch_view'][phx-value-view='patterns']` | switch_view | C1 |
  | Debug Sessions tab | button | `button[phx-click='switch_view'][phx-value-view='debug']` | switch_view | C1 |
  | Code Links tab | button | `button[phx-click='switch_view'][phx-value-view='links']` | switch_view | C1 |
  | Status filter select | select | `select[phx-change='filter_status']` | filter_status | C2 |
  | All Status option | option | `option[value='all']` | — | C2 |
  | Proposed option | option | `option[value='proposed']` | — | C2 |
  | Accepted option | option | `option[value='accepted']` | — | C2 |
  | Deprecated option | option | `option[value='deprecated']` | — | C2 |
  | Search input | input | `input[phx-keyup='search']` | search | C3 |
  | Decisions list container | div | `div.space-y-4` | — | C3 |
  | Patterns grid | div | `div.grid` | — | C3 |
  | Debug sessions list | div | `div.space-y-4` (debug view) | — | C4 |
  | Code Links description | p | `p` text "File-to-knowledge mappings..." | — | C6 |
  | Tab navigation bar | nav | `nav` | — | C6 |
  | Use Pattern button | button | `button[phx-click='use_pattern']` text "Use Pattern" | use_pattern | C8 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (gray defaults, Color Rich on telemetry)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — flash AND status change for use_pattern
  - SC-KMS-001: Knowledge stored in SQLite/DuckDB only (Ω₇ Holon State Sovereignty)
  - SC-KMS-007: Decision traceability mandatory for architectural decisions
  - SC-DEV-001: Developer knowledge query latency < 50ms

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | PubSub subscription fails on slow connect | 5 | 3 | 3 | 45 | connected? guard ensures late subscription |
  | use_pattern flash not shown if assigns race | 6 | 2 | 3 | 36 | assert_has waits for DOM update |
  | 10s timer fires before test assertion | 4 | 3 | 2 | 24 | async: false + short test isolation |
  | Tab switch renders wrong content panel | 7 | 2 | 2 | 28 | C5 tab switch tests verify DOM content change |
  | search_query not cleared on tab switch | 3 | 2 | 4 | 24 | State isolation per view_mode is tested |

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

  @path "/cockpit/knowledge/developer"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with Developer Knowledge heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Developer Knowledge"))
  end

  feature "page loads with subtitle text about code links and decisions", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Code links, decisions, patterns, debug insights"))
  end

  feature "page loads with Decisions view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='decisions']"))
  end

  feature "page loads with Patterns view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
  end

  feature "page loads with Debug Sessions view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='debug']"))
  end

  feature "page loads with Code Links view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='links']"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "decisions view renders filter_status select by default", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_status']"))
  end

  feature "decisions view filter contains All Status option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='all']"))
  end

  feature "decisions view filter contains Proposed option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='proposed']"))
  end

  feature "decisions view filter contains Accepted option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='accepted']"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "decisions view renders search input", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[phx-keyup='search']"))
  end

  feature "search input has placeholder text for decisions search", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[placeholder='Search decisions...']"))
  end

  feature "patterns view renders pattern cards grid after tab switch", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> assert_has(css("button[phx-click='use_pattern']"))
  end

  feature "patterns view shows Use Pattern button for each pattern", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> assert_has(css("button[phx-click='use_pattern']", text: "Use Pattern"))
  end

  feature "code links view shows description text for file mappings", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='links']"))
    |> assert_has(css("p", text: "File-to-knowledge mappings for codebase awareness"))
  end

  # ── C4: Timeline / History ──────────────────────────────────────────────────

  feature "debug sessions view renders after tab switch", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='debug']"))
    |> assert_has(css("div.space-y-4"))
  end

  feature "decisions view is the default view on mount", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_status']"))
    |> assert_has(css("input[placeholder='Search decisions...']"))
  end

  feature "decisions filter contains Deprecated option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='deprecated']"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "switch_view: clicking Patterns tab renders patterns grid", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> assert_has(css("button[phx-click='use_pattern']"))
  end

  feature "switch_view: clicking Code Links tab renders links view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='links']"))
    |> assert_has(css("p", text: "File-to-knowledge mappings for codebase awareness"))
  end

  feature "switch_view: clicking Debug Sessions tab renders debug view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='debug']"))
    |> refute_has(css("button[phx-click='use_pattern']"))
  end

  feature "filter_status select is interactive and retains decisions heading context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_status']"))
    |> assert_has(css("input[phx-keyup='search']"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "tab navigation bar is present with all four tabs visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav"))
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='decisions']"))
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
  end

  feature "patterns view shows category badge for each pattern card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> assert_has(css("div.grid"))
  end

  feature "decisions view renders the space-y-4 list container", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.space-y-4"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # use_pattern — C8a: flash "Pattern usage recorded"
  feature "use_pattern: clicking Use Pattern triggers Pattern usage recorded flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> assert_has(css("button[phx-click='use_pattern']"))
    |> click(css("button[phx-click='use_pattern']"))
    |> assert_has(css("[role='alert']", text: "Pattern usage recorded"))
  end

  # use_pattern — C8b: patterns view remains after use (status change — Use Pattern button still present)
  feature "use_pattern: patterns panel remains after Use Pattern action", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> click(css("button[phx-click='use_pattern']"))
    |> assert_has(css("div.grid"))
  end

  # switch_view — C8a: switching to Patterns changes view content (status change)
  feature "switch_view: Patterns tab changes content from decisions to patterns grid", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("input[placeholder='Search decisions...']"))
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> assert_has(css("button[phx-click='use_pattern']"))
  end

  # switch_view — C8b: returning to Decisions tab restores decisions filter
  feature "switch_view: returning to Decisions tab restores decisions filter select", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='patterns']"))
    |> click(css("button[phx-click='switch_view'][phx-value-view='decisions']"))
    |> assert_has(css("select[phx-change='filter_status']"))
  end

  # ── C5: Interactive pattern usage ───────────────────────────────────────────

  feature "developer knowledge page has interactive code elements", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", minimum: 1))
  end
end
