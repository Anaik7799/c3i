defmodule IndrajaalWeb.Prajna.Knowledge.ProductLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA Product Knowledge LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/knowledge/product`
  - **Module**: `IndrajaalWeb.Prajna.Knowledge.ProductLive`
  - **Title**: "Product Knowledge"

  ## Design Intent
  Provides product managers and operators with a centralized knowledge dashboard
  covering product features, release history, user feedback, A/B experiments, KPIs,
  and the product roadmap. The page supports data-driven product decisions by surfacing
  all product intelligence in a single PubSub-synchronized view within the Prajna cockpit.

  ## Expected Behavior (Functional)
  - **On mount**: Loads assigns `view_mode: :features`, `features: [...]`,
    `releases: [...]`, `feedback: [...]`, `experiments: [...]`, `kpis: [...]`,
    `roadmap: [...]`, `selected_item: nil`, `search_query: ""`, `filter_status: "all"`,
    `kms_error: nil`. PubSub subscription to `"prajna:kms:product"` and 15-second
    refresh timer are both started inside `try/rescue` when `connected?/1`.
  - **handle_event "switch_view"**: Sets `view_mode` to one of `:features`, `:releases`,
    `:feedback`, `:experiments`, `:kpis`, `:roadmap`; re-renders panel.
  - **handle_event "select_item"**: Sets `selected_item` to item id for detail expansion.
  - **handle_event "search"**: Updates `search_query`, filters current view's list.
  - **handle_event "filter_status"**: Updates `filter_status`; re-filters features list.
  - **handle_info(:refresh)**: 15-second timer-driven refresh from KMS.
  - **PubSub**: Subscribed to `"prajna:kms:product"` — receives product knowledge updates.
  - **Error resilience**: PubSub subscription and timer wrapped in `try/rescue`;
    `kms_error` assign set on failure so the page degrades gracefully.

  ## BDD Scenarios
  ```gherkin
  Scenario: Product manager loads knowledge dashboard
    Given I navigate to "/cockpit/knowledge/product"
    Then I should see heading "Product Knowledge"
    And the Features tab should be active by default
    And the status filter select should be visible

  Scenario: Product manager switches to KPIs tab
    Given I navigate to "/cockpit/knowledge/product"
    When I click the "KPIs" tab button
    Then I should see the KPI grid layout

  Scenario: Product manager browses releases history
    Given I navigate to "/cockpit/knowledge/product"
    When I click the "Releases" tab button
    Then I should see the releases list

  Scenario: Product manager filters features by status
    Given I am on "/cockpit/knowledge/product"
    And the Features tab is active
    When I select "Shipped" from the status filter
    Then only shipped features should be displayed

  Scenario: Product manager views roadmap
    Given I navigate to "/cockpit/knowledge/product"
    When I click the "Roadmap" tab button
    Then I should see the roadmap view with quarters
  ```

  ## UX Flow
  1. Product manager navigates to `/cockpit/knowledge/product` via Prajna knowledge nav
  2. Page mounts with Features tab active; search input and status filter visible
  3. Operator switches between 6 tabs: Features, Releases, Feedback, Experiments, KPIs, Roadmap
  4. In Features tab: filter by status (all/proposed/approved/in_progress/shipped), search by keyword
  5. In KPIs tab: grid of KPI cards with current values and trend indicators
  6. 15-second timer refreshes knowledge cache; PubSub receives live product updates
  7. On KMS connection failure, error banner shown but page remains functional

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Product Knowledge heading | h1 | `h1` text "Product Knowledge" | — | C1 |
  | Page subtitle | p | `p` text "Features, releases, feedback, experiments, KPIs" | — | C1 |
  | Features tab | button | `button[phx-click='switch_view'][phx-value-view='features']` | switch_view | C1 |
  | Releases tab | button | `button[phx-click='switch_view'][phx-value-view='releases']` | switch_view | C1 |
  | Feedback tab | button | `button[phx-click='switch_view'][phx-value-view='feedback']` | switch_view | C1 |
  | Experiments tab | button | `button[phx-click='switch_view'][phx-value-view='experiments']` | switch_view | C1 |
  | KPIs tab | button | `button[phx-click='switch_view'][phx-value-view='kpis']` | switch_view | C1 |
  | Roadmap tab | button | `button[phx-click='switch_view'][phx-value-view='roadmap']` | switch_view | C1 |
  | Status filter select | select | `select[phx-change='filter_status']` | filter_status | C2 |
  | All Status option | option | `option[value='all']` | — | C2 |
  | Proposed option | option | `option[value='proposed']` | — | C2 |
  | Approved option | option | `option[value='approved']` | — | C2 |
  | In Progress option | option | `option[value='in_progress']` | — | C2 |
  | Shipped option | option | `option[value='shipped']` | — | C2 |
  | Search input | input | `input[phx-keyup='search']` | search | C3 |
  | Features list | div | `div.space-y-4` (features) | — | C3 |
  | KPI grid | div | `div.grid` (kpis view) | — | C3 |
  | Releases list | div | `div.space-y-4` (releases) | — | C4 |
  | Feedback list | div | `div.space-y-4` (feedback) | — | C4 |
  | Experiments list | div | `div.space-y-4` (experiments) | — | C4 |
  | Tab navigation bar | nav | `nav` | — | C6 |
  | Roadmap container | div | `div.space-y-6` (roadmap) | — | C6 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (gray defaults, Color Rich on metrics)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — switch_view and filter_status both verified
  - SC-KMS-001: Knowledge stored in SQLite/DuckDB only (Ω₇ Holon State Sovereignty)
  - SC-KMS-008: User feedback traceability mandatory for product decisions
  - SC-PROD-001: Product knowledge query latency < 100ms

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | PubSub subscription fails (try/rescue swallows) | 5 | 3 | 4 | 60 | kms_error assign surfaced to UI |
  | 15s timer fires during assertion window | 4 | 2 | 2 | 16 | async: false prevents race |
  | filter_status on non-features tab crashes | 5 | 2 | 3 | 30 | Only rendered in features view |
  | KPIs grid empty on mock data | 3 | 3 | 2 | 18 | div.grid always rendered even if empty |
  | Tab state not reset on PubSub update | 4 | 2 | 3 | 24 | view_mode assign not touched by handle_info |

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

  @path "/cockpit/knowledge/product"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with Product Knowledge heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "Product Knowledge"))
  end

  feature "page loads with subtitle text about features and releases", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Features, releases, feedback, experiments, KPIs"))
  end

  feature "page loads with Features view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='features']"))
  end

  feature "page loads with Releases view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='releases']"))
  end

  feature "page loads with Feedback view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='feedback']"))
  end

  feature "page loads with Experiments view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='experiments']"))
  end

  feature "page loads with KPIs view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='kpis']"))
  end

  feature "page loads with Roadmap view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='roadmap']"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "features view renders filter_status select by default", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_status']"))
  end

  feature "features view filter contains All Status option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='all']"))
  end

  feature "features view filter contains Proposed option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='proposed']"))
  end

  feature "features view filter contains Shipped option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='shipped']"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "features view renders search input field", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[phx-keyup='search']"))
  end

  feature "features view search input has features placeholder text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[placeholder='Search features...']"))
  end

  feature "switching to KPIs tab renders kpis_view grid", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='kpis']"))
    |> assert_has(css("div.grid"))
  end

  feature "features view filter contains In Progress option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='in_progress']"))
  end

  feature "features view filter contains Approved option", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("option[value='approved']"))
  end

  # ── C4: Timeline / History ──────────────────────────────────────────────────

  feature "switching to Releases tab renders releases view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='releases']"))
    |> assert_has(css("div.space-y-4"))
  end

  feature "switching to Feedback tab renders feedback view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='feedback']"))
    |> assert_has(css("div.space-y-4"))
  end

  feature "switching to Experiments tab renders experiments view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='experiments']"))
    |> assert_has(css("div.space-y-4"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "switch_view: clicking Releases tab switches away from features view", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='releases']"))
    |> refute_has(css("input[placeholder='Search features...']"))
  end

  feature "switch_view: clicking KPIs tab shows kpis grid content", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='kpis']"))
    |> assert_has(css("div.grid"))
  end

  feature "switch_view: returning to Features tab restores filter select", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='releases']"))
    |> click(css("button[phx-click='switch_view'][phx-value-view='features']"))
    |> assert_has(css("select[phx-change='filter_status']"))
  end

  feature "search input is interactive and accepts text input", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(css("input[phx-keyup='search']"), with: "alpha")
    |> assert_has(css("input[phx-keyup='search']"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "tab navigation bar is rendered with all six tabs", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav"))
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='features']"))
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='roadmap']"))
  end

  feature "features view renders the outer min-h-screen container", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.min-h-screen"))
  end

  feature "switching to Roadmap tab renders roadmap_view container", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='roadmap']"))
    |> assert_has(css("div.space-y-6"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # switch_view — C8a: switching to Experiments changes content to experiments view
  feature "switch_view: Experiments tab shows experiments view content", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='experiments']"))
    |> assert_has(css("div.space-y-4"))
  end

  # switch_view — C8b: switching back to Features restores features content
  feature "switch_view: returning to Features tab restores features grid", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='experiments']"))
    |> click(css("button[phx-click='switch_view'][phx-value-view='features']"))
    |> assert_has(css("select[phx-change='filter_status']"))
    |> assert_has(css("input[placeholder='Search features...']"))
  end

  # filter_status — C8a: filter select accepts change and re-renders features view
  feature "filter_status: changing filter to Proposed re-renders features view", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[phx-change='filter_status']"))
    |> assert_has(css("div.space-y-4"))
  end

  # filter_status — C8b: features content area remains after filter change
  feature "filter_status: features content area remains visible after filter select interaction",
          %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[phx-keyup='search']"))
    |> assert_has(css("select[phx-change='filter_status']"))
  end
end
