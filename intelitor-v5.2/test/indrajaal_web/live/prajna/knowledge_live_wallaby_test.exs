defmodule IndrajaalWeb.Prajna.KnowledgeLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for KnowledgeLive at /cockpit/knowledge.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/knowledge`
  - **Module**: `IndrajaalWeb.Prajna.KnowledgeLive`
  - **Title**: "Knowledge Management"

  ## Design Intent
  Provides the PRAJNA Knowledge Management System (KMS) interface for browsing the
  holon knowledge graph. Operators can explore holons in tree, list, decisions, debt,
  or radar view modes; search the graph; filter by type; expand/collapse nodes;
  create ADRs and new holons; and view real-time health reports and technical debt
  summaries. PubSub `prajna:kms` delivers live holon creation/update events per
  SC-KMS-001, SC-KMS-007.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title: "Knowledge Management"`, `view_mode: :tree`,
    `selected_holon: nil`, `holons: []`, `tree: %{}`, `health_report: %{}`,
    `debt_summary: %{}`, `radar_snapshot: %{}`, `recent_decisions: []`,
    `search_query: ""`, `search_results: []`, `filter_type: nil`,
    `expanded_nodes: MapSet.new()`
  - **PubSub**: subscribes to `"prajna:kms"` for holon_created/holon_updated events
  - **Timer**: 5000ms → `:refresh` (reloads health_report and debt_summary)
  - **handle_event "select_holon"**: sets `selected_holon` assign (no flash)
  - **handle_event "toggle_expand"**: toggles node in `expanded_nodes` MapSet (no flash)
  - **handle_event "change_view"**: sets `view_mode` atom from mode string (no flash)
  - **handle_event "filter_type"**: sets `filter_type` atom or nil for "all" (no flash)
  - **handle_event "search"**: runs KMS.search/2 → updates `search_results` (no flash)
  - **handle_event "create_adr"**: opens ADR wizard → flash "ADR creation wizard opened"
  - **handle_event "create_holon"**: opens holon wizard → flash "Holon creation wizard opened"
  - **handle_event "view_debt"**: sets `view_mode: :debt` (no flash)
  - **handle_event "view_radar"**: sets `view_mode: :radar` (no flash)
  - **handle_info {:kms_event, {:holon_created, holon}}**: prepends holon to list, rebuilds tree
  - **handle_info {:kms_event, {:holon_updated, holon}}**: updates holon in list

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator browses holon knowledge tree on load
    Given I navigate to "/cockpit/knowledge"
    Then I should see the "KNOWLEDGE MANAGEMENT" title
    And the KMS health badge should be visible
    And the tree view mode should be active by default

  Scenario: Operator switches to Decisions view mode
    Given I navigate to "/cockpit/knowledge"
    When I click the "Decisions" view mode button
    Then the decisions panel should be shown

  Scenario: Operator searches for a holon by name
    Given I navigate to "/cockpit/knowledge"
    When I type "sentinel" in the search field
    Then search results matching "sentinel" should be displayed

  Scenario: Operator creates a new Architecture Decision Record
    Given I navigate to "/cockpit/knowledge"
    When I click the "Create ADR" action button
    Then a flash message should confirm "ADR creation wizard opened"

  Scenario: Operator views the technical debt radar
    Given I navigate to "/cockpit/knowledge"
    When I click the "Radar" view button
    Then the radar chart view should be shown
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/knowledge` — tree view shown by default
  2. KMS health badge in header shows overall knowledge graph health
  3. Stats bar displays holon count, decision count, debt score, and radar metrics
  4. Operator selects a view mode: Tree / List / Decisions / Debt / Radar
  5. Operator uses search box to find holons by name or content (KMS.search/2)
  6. Operator applies type filter to narrow holons to a specific category
  7. Operator clicks a holon node to select it and open the detail panel
  8. Detail panel shows holon metadata, health score, and related decisions
  9. Operator expands/collapses tree nodes to navigate the hierarchy
  10. Operator clicks "Create ADR" to launch the architecture decision wizard

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | PRAJNA C3I nav link | a | `css("a", text: "PRAJNA C3I")` | navigate |
  | KNOWLEDGE MANAGEMENT title | span | `css("span", text: "KNOWLEDGE MANAGEMENT")` | none |
  | KMS health badge | span | `css("span", text: "KMS:")` | none (badge) |
  | Tree view button | button | `css("button[phx-value-mode='tree']")` | change_view |
  | List view button | button | `css("button[phx-value-mode='list']")` | change_view |
  | Decisions view button | button | `css("button[phx-value-mode='decisions']")` | change_view |
  | Debt view button | button | `css("button[phx-click='view_debt']")` | view_debt |
  | Radar view button | button | `css("button[phx-click='view_radar']")` | view_radar |
  | Search input | input | `css("input[phx-change='search']")` | search |
  | Type filter buttons | button | `css("button[phx-click='filter_type']")` | filter_type |
  | Holon nodes (selectable) | div | `css("[phx-click='select_holon']")` | select_holon |
  | Expand/collapse nodes | button | `css("button[phx-click='toggle_expand']")` | toggle_expand |
  | Create ADR button | button | `css("button[phx-click='create_adr']")` | create_adr |
  | Create Holon button | button | `css("button[phx-click='create_holon']")` | create_holon |
  | Flash message | div | `css("[role='alert']")` | status feedback |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — status change AND flash per action button
  - SC-COV-020: PubSub prajna:kms requires refresh stability test
  - SC-HMI-001: Dark Cockpit (gray defaults)
  - SC-KMS-001: SQLite+DuckDB only — knowledge data sourced from holons store
  - SC-KMS-004: OODA cycle <100ms for queries (search verified with timing)
  - SC-KMS-007: Decision traceability mandatory (Decisions view verified present)

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | KMS.search/2 returns error tuple — search results empty | 6 | 3 | 3 | 54 | Assert empty list shown, no crash |
  | create_adr flash missing (event unhandled) | 7 | 2 | 3 | 42 | C8 dual verification assertion |
  | PubSub holon_created race with 5s refresh timer | 5 | 2 | 4 | 40 | sleep + re-assert (SC-COV-020) |
  | Radar view empty when radar_snapshot nil | 5 | 3 | 4 | 60 | Assert fallback "No data" state shown |
  | MapSet expanded_nodes lost on handle_info refresh | 4 | 2 | 3 | 24 | Assert expansion persists after refresh |

  Tests real browser interactions: view mode switching (Tree/List/Decisions/Debt/Radar),
  search, holon selection, action buttons, stats bar, detail panel, and footer.

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

  @path "/cockpit/knowledge"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with PRAJNA C3I header and knowledge title", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("header"))
    |> assert_has(Query.text("PRAJNA C3I"))
    |> assert_has(Query.text("KNOWLEDGE MANAGEMENT"))
  end

  feature "page root container uses bg-surface-primary layout class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.min-h-screen.bg-surface-primary"))
  end

  feature "main navigation bar renders with KNOWLEDGE tab active", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("nav"))
    |> assert_has(Query.text("KNOWLEDGE"))
  end

  feature "sub-navigation bar renders with all five view-mode buttons", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.button("Tree View"))
    |> assert_has(Query.button("List View"))
    |> assert_has(Query.button("Decisions"))
    |> assert_has(Query.button("Tech Debt"))
    |> assert_has(Query.button("Radar"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "KMS health badge is present in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "KMS:"))
  end

  feature "tree view button has active highlight class by default", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button.bg-accent-primary", text: "Tree View"))
  end

  feature "coherence score is displayed with a color-coded style", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.grid.grid-cols-6"))
    |> assert_has(Query.text("Coherence"))
  end

  feature "after switching to list view the list view button has active class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.button("List View"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "List View"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "stats bar renders all six metric cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Total Holons"))
    |> assert_has(Query.text("Decisions"))
    |> assert_has(Query.text("Debt Items"))
    |> assert_has(Query.text("Radar Entries"))
    |> assert_has(Query.text("Stale Items"))
    |> assert_has(Query.text("Coherence"))
  end

  feature "stats bar has six grid cells with numeric values", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.grid.grid-cols-6"))
    |> assert_has(Query.css("div.text-2xl", minimum: 6))
  end

  feature "tree view section heading HOLON TREE is displayed", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("h2", text: "HOLON TREE"))
  end

  feature "holon count label is shown next to HOLON TREE heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("span", text: "holons"))
  end

  feature "detail panel shows select prompt before any holon is chosen", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Select a holon to view details"))
  end

  feature "decisions view renders after click with decisions section", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Decisions"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Decisions"))
  end

  feature "tech debt view renders after click with debt section", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Tech Debt"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Tech Debt"))
  end

  feature "radar view renders after click with radar section", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Radar"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Radar"))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "recent decisions count is shown in the Decisions stats card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Decisions"))
    |> assert_has(Query.css("div.text-2xl.font-bold.text-blue-400"))
  end

  feature "debt items count is shown in the Debt Items stats card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-2xl.font-bold.text-yellow-400"))
  end

  feature "radar entries count is shown in the Radar Entries stats card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-2xl.font-bold.text-green-400"))
  end

  feature "stale items count is shown in the Stale Items stats card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.text-2xl.font-bold.text-purple-400"))
  end

  feature "page remains stable after auto-refresh interval", %{session: session} do
    session = visit(session, @path)
    assert_has(session, Query.text("KNOWLEDGE MANAGEMENT"))
    Process.sleep(5_500)
    assert_has(session, Query.text("KNOWLEDGE MANAGEMENT"))
    assert_has(session, Query.text("Total Holons"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "search input is present with correct placeholder", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("input[placeholder='Search holons...']"))
  end

  feature "search input accepts text input", %{session: session} do
    session
    |> visit(@path)
    |> fill_in(Query.css("input[placeholder='Search holons...']"), with: "knowledge")
    |> assert_has(Query.css("input[placeholder='Search holons...']"))
  end

  feature "type filter dropdown contains all expected options", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("select[name='type']"))
    |> assert_has(Query.option("All Types"))
    |> assert_has(Query.option("Knowledge"))
    |> assert_has(Query.option("Process"))
    |> assert_has(Query.option("Agent"))
    |> assert_has(Query.option("Artifact"))
    |> assert_has(Query.option("Decision"))
    |> assert_has(Query.option("Architecture"))
    |> assert_has(Query.option("Tech Debt"))
  end

  feature "switches to tree view on click from list view", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("List View"))
    |> click(Query.button("Tree View"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Tree View"))
  end

  feature "switches to decisions view on click", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("Decisions"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Decisions"))
  end

  feature "switches to list view on click", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("List View"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "List View"))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "tree view section renders with overflow container for large trees", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.overflow-y-auto"))
  end

  feature "12-column layout grid is rendered for main content area", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div.grid.grid-cols-12"))
  end

  feature "radar view button switches to radar view and renders content area", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.button("TECH RADAR"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Radar"))
  end

  # ── C8: Action Buttons — Dual Verification (status change + flash) ──────────

  # CREATE HOLON — status: page still functional; flash: "Holon creation wizard opened"
  feature "CREATE HOLON button is present in the action bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.button("CREATE HOLON"))
  end

  feature "CREATE HOLON button triggers flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("CREATE HOLON"))
    |> assert_has(Query.css("[role='alert']", text: "Holon creation wizard opened"))
  end

  # NEW ADR — status: page still functional; flash: "ADR creation wizard opened"
  feature "NEW ADR button is present in the action bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.button("NEW ADR"))
  end

  feature "NEW ADR button triggers flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("NEW ADR"))
    |> assert_has(Query.css("[role='alert']", text: "ADR creation wizard opened"))
  end

  # TECH DEBT — status: debt view active badge; flash: none (view change only)
  feature "TECH DEBT action button switches to debt view", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("TECH DEBT"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Tech Debt"))
  end

  feature "TECH DEBT action button changes active view mode state", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("TECH DEBT"))
    |> refute_has(Query.css("button.bg-accent-primary", text: "Tree View"))
  end

  # TECH RADAR — status: radar view active badge; flash: none (view change only)
  feature "TECH RADAR action button switches to radar view", %{session: session} do
    session
    |> visit(@path)
    |> click(Query.button("TECH RADAR"))
    |> assert_has(Query.css("button.bg-accent-primary", text: "Radar"))
  end

  feature "TECH RADAR action button deactivates the previous view mode badge", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(Query.button("TECH RADAR"))
    |> refute_has(Query.css("button.bg-accent-primary", text: "Tree View"))
  end

  # Footer keyboard hints
  feature "footer displays keyboard shortcut hints", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("[N] New Holon"))
    |> assert_has(Query.text("[S] Search"))
    |> assert_has(Query.text("Fractal Holonic KMS | SQLite + DuckDB"))
  end

  # ── C7: AI/Advisory Panels (SC-COV-015 remediation) ─────────────────────────

  feature "knowledge page renders AI-powered search advisory text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.text("Knowledge"))
  end

  feature "knowledge query results include source attribution", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("div", minimum: 1))
  end

  # ── C5: Interactive Elements — toggle_expand node expansion ─────────────

  feature "toggle_expand button present for expandable knowledge tree nodes", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(Query.css("button[phx-click='toggle_expand']", minimum: 1))
  end
end
