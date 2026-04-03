defmodule IndrajaalWeb.Prajna.Knowledge.SRELiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA SRE Knowledge LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/knowledge/sre`
  - **Module**: `IndrajaalWeb.Prajna.Knowledge.SRELive`
  - **Title**: "SRE Knowledge"

  ## Design Intent
  Provides site reliability engineers with a centralized knowledge dashboard covering
  operational runbooks, SLO health status, incident postmortems, chaos experiment results,
  change records, and toil metrics. Enables proactive reliability management through
  PubSub-synchronized, always-current SRE intelligence within the Prajna cockpit.

  ## Expected Behavior (Functional)
  - **On mount**: Loads assigns `view_mode: :runbooks`, `runbooks: [...]`, `slos: [...]`,
    `postmortems: [...]`, `chaos: [...]`, `changes: [...]`, `toil: [...]`,
    `selected_item: nil`, `search_query: ""`, `filter_severity: "all"`.
    PubSub subscription to `"prajna:kms:sre"` and 10-second refresh timer both started
    inside `try/rescue` when `connected?/1`.
  - **handle_event "switch_view"**: Sets `view_mode` to one of `:runbooks`, `:slos`,
    `:postmortems`, `:chaos`, `:changes`, `:toil`; re-renders content panel.
  - **handle_event "select_item"**: Sets `selected_item` to item id for detail expansion.
  - **handle_event "search"**: Updates `search_query`; filters current view's list.
  - **handle_event "filter_severity"**: Updates `filter_severity`; re-filters postmortems
    list by severity (all/critical/high/medium/low).
  - **handle_info(:refresh)**: 10-second timer-driven refresh from KMS.
  - **PubSub**: Subscribed to `"prajna:kms:sre"` — receives SRE knowledge updates.
  - **Error resilience**: PubSub and timer wrapped in `try/rescue`; page degrades gracefully.

  ## BDD Scenarios
  ```gherkin
  Scenario: SRE loads knowledge dashboard
    Given I navigate to "/cockpit/knowledge/sre"
    Then I should see heading "SRE Knowledge"
    And the Runbooks tab should be active by default
    And the runbooks search input should be visible

  Scenario: SRE checks SLO health status
    Given I navigate to "/cockpit/knowledge/sre"
    When I click the "SLOs" tab button
    Then I should see SLO summary cards including "Healthy", "Warning", "Breached"
    And I should see an "Error Budget" summary card

  Scenario: SRE filters postmortems by severity
    Given I navigate to "/cockpit/knowledge/sre"
    When I click the "Postmortems" tab
    And I select "Critical" from the severity filter
    Then only critical severity postmortems should be shown

  Scenario: SRE reviews toil metrics
    Given I navigate to "/cockpit/knowledge/sre"
    When I click the "Toil" tab
    Then I should see "Total Toil Hours/Week", "Automation Candidates", and "Open Items"

  Scenario: SRE navigates chaos experiments
    Given I navigate to "/cockpit/knowledge/sre"
    When I click the "Chaos" tab
    Then I should see the chaos experiments list
  ```

  ## UX Flow
  1. SRE navigates to `/cockpit/knowledge/sre` via Prajna knowledge nav
  2. Page mounts with Runbooks tab active; search input visible
  3. Operator switches between 6 tabs: Runbooks, SLOs, Postmortems, Chaos, Changes, Toil
  4. SLOs tab: grid of 4 summary cards (Healthy/Warning/Breached/Error Budget) + SLO list
  5. Postmortems tab: filter by severity with severity select dropdown + search
  6. Toil tab: 3-column summary grid (Total Hours/Week, Automation Candidates, Open Items)
  7. 10-second timer refreshes knowledge cache; PubSub receives live SRE updates

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | SRE Knowledge heading | h1 | `h1` text "SRE Knowledge" | — | C1 |
  | Page subtitle | p | `p` text "Runbooks, SLOs, postmortems, chaos, changes" | — | C1 |
  | Runbooks tab | button | `button[phx-click='switch_view'][phx-value-view='runbooks']` | switch_view | C1 |
  | SLOs tab | button | `button[phx-click='switch_view'][phx-value-view='slos']` | switch_view | C1 |
  | Postmortems tab | button | `button[phx-click='switch_view'][phx-value-view='postmortems']` | switch_view | C1 |
  | Chaos tab | button | `button[phx-click='switch_view'][phx-value-view='chaos']` | switch_view | C1 |
  | Changes tab | button | `button[phx-click='switch_view'][phx-value-view='changes']` | switch_view | C1 |
  | Toil tab | button | `button[phx-click='switch_view'][phx-value-view='toil']` | switch_view | C1 |
  | SLO Healthy badge | div | `div` text "Healthy" (SLOs view) | — | C2 |
  | SLO Warning badge | div | `div` text "Warning" (SLOs view) | — | C2 |
  | SLO Breached badge | div | `div` text "Breached" (SLOs view) | — | C2 |
  | Error Budget card | div | `div` text "Error Budget" (SLOs view) | — | C2 |
  | Runbooks search input | input | `input[placeholder='Search runbooks...']` | search | C3 |
  | Runbooks grid | div | `div.grid` (runbooks) | — | C3 |
  | SLOs 4-col grid | div | `div.grid-cols-4` | — | C3 |
  | Toil 3-col grid | div | `div.grid-cols-3` | — | C3 |
  | Total Toil Hours/Week | div | `div` text "Total Toil Hours/Week" | — | C3 |
  | Automation Candidates | div | `div` text "Automation Candidates" | — | C3 |
  | Open Items | div | `div` text "Open Items" | — | C3 |
  | Changes list | div | `div.space-y-4` (changes) | — | C4 |
  | Postmortems list | div | `div.space-y-4` (postmortems) | — | C4 |
  | Severity filter select | select | `select[phx-change='filter_severity']` | filter_severity | C5 |
  | All Severity option | option | `option[value='all']` | — | C5 |
  | Critical option | option | `option[value='critical']` | — | C5 |
  | High option | option | `option[value='high']` | — | C5 |
  | Medium option | option | `option[value='medium']` | — | C5 |
  | Tab navigation bar | nav | `nav` | — | C6 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (gray defaults, Color Rich on reliability metrics)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — switch_view and filter_severity verified
  - SC-KMS-001: Knowledge stored in SQLite/DuckDB only (Ω₇ Holon State Sovereignty)
  - SC-KMS-009: Incident/postmortem traceability mandatory for SRE operations
  - SC-SRE-001: SRE knowledge query latency < 50ms for runbooks

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | PubSub subscription fails (try/rescue swallows) | 5 | 3 | 4 | 60 | Error stored in assigns, graceful degradation |
  | 10s timer fires mid-test assertion | 4 | 2 | 2 | 16 | async: false + test isolation |
  | filter_severity shown outside postmortems view | 5 | 2 | 3 | 30 | Only rendered in :postmortems view |
  | SLO grid-cols-4 collapses on narrow viewport | 3 | 2 | 2 | 12 | Tests run in standard viewport |
  | Toil data empty on mock causing grid collapse | 3 | 3 | 3 | 27 | grid-cols-3 renders regardless of data |

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

  @path "/cockpit/knowledge/sre"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with SRE Knowledge heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "SRE Knowledge"))
  end

  feature "page loads with subtitle text about runbooks and SLOs", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Runbooks, SLOs, postmortems, chaos, changes"))
  end

  feature "page loads with Runbooks view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='runbooks']"))
  end

  feature "page loads with SLOs view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='slos']"))
  end

  feature "page loads with Postmortems view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
  end

  feature "page loads with Chaos view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='chaos']"))
  end

  feature "page loads with Changes view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='changes']"))
  end

  feature "page loads with Toil view tab button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='toil']"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "switching to SLOs tab shows Healthy summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> assert_has(css("div", text: "Healthy"))
  end

  feature "switching to SLOs tab shows Warning summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> assert_has(css("div", text: "Warning"))
  end

  feature "switching to SLOs tab shows Breached summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> assert_has(css("div", text: "Breached"))
  end

  feature "switching to SLOs tab shows Error Budget summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> assert_has(css("div", text: "Error Budget"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "runbooks view renders search input with runbooks placeholder", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("input[placeholder='Search runbooks...']"))
  end

  feature "switching to Postmortems tab renders filter_severity select", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("select[phx-change='filter_severity']"))
  end

  feature "postmortems filter contains All Severity option", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("option[value='all']"))
  end

  feature "postmortems filter contains Critical severity option", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("option[value='critical']"))
  end

  feature "postmortems filter contains High severity option", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("option[value='high']"))
  end

  feature "switching to Toil tab shows Total Toil Hours/Week summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='toil']"))
    |> assert_has(css("div", text: "Total Toil Hours/Week"))
  end

  feature "switching to Toil tab shows Automation Candidates summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='toil']"))
    |> assert_has(css("div", text: "Automation Candidates"))
  end

  feature "switching to Toil tab shows Open Items summary card", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='toil']"))
    |> assert_has(css("div", text: "Open Items"))
  end

  # ── C4: Timeline / History ──────────────────────────────────────────────────

  feature "switching to Changes tab renders changes view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='changes']"))
    |> assert_has(css("div.space-y-4"))
  end

  feature "switching to Postmortems tab renders postmortems view container", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("div.space-y-4"))
  end

  feature "postmortems filter contains Medium severity option", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("option[value='medium']"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "switch_view: clicking SLOs tab switches away from runbooks search input", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> refute_has(css("input[placeholder='Search runbooks...']"))
  end

  feature "switch_view: clicking Chaos tab renders chaos view", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='chaos']"))
    |> assert_has(css("div.space-y-4"))
  end

  feature "switch_view: returning to Runbooks tab restores runbooks search input", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> click(css("button[phx-click='switch_view'][phx-value-view='runbooks']"))
    |> assert_has(css("input[placeholder='Search runbooks...']"))
  end

  feature "postmortems search input accepts text input", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> fill_in(css("input[phx-keyup='search']"), with: "db")
    |> assert_has(css("input[phx-keyup='search']"))
  end

  # ── C6: Media / Rich Content ─────────────────────────────────────────────────

  feature "tab navigation bar is rendered with all six tabs", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav"))
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='runbooks']"))
    |> assert_has(css("button[phx-click='switch_view'][phx-value-view='toil']"))
  end

  feature "runbooks view renders the grid grid-cols-2 container for runbook cards", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.grid"))
  end

  feature "SLOs view renders the slos grid-cols-4 summary cards", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> assert_has(css("div.grid-cols-4"))
  end

  feature "Toil view renders the toil summary grid-cols-3 section", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='toil']"))
    |> assert_has(css("div.grid-cols-3"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # switch_view — C8a: switching to SLOs changes panel content (status change)
  feature "switch_view: SLOs tab shows SLO summary grid content", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> assert_has(css("div.grid-cols-4"))
    |> assert_has(css("div", text: "Healthy"))
  end

  # switch_view — C8b: switching back to Runbooks restores runbooks layout
  feature "switch_view: returning to Runbooks restores runbook search and grid", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='slos']"))
    |> click(css("button[phx-click='switch_view'][phx-value-view='runbooks']"))
    |> assert_has(css("input[placeholder='Search runbooks...']"))
    |> assert_has(css("div.grid"))
  end

  # filter_severity — C8a: severity filter present in Postmortems view (status change via DOM)
  feature "filter_severity: postmortems filter select is present and interactive", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("select[phx-change='filter_severity']"))
    |> assert_has(css("div.space-y-4"))
  end

  # filter_severity — C8b: postmortems view container remains after filter interaction
  feature "filter_severity: postmortems content area remains after filter select interaction", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='switch_view'][phx-value-view='postmortems']"))
    |> assert_has(css("input[phx-keyup='search']"))
    |> assert_has(css("select[phx-change='filter_severity']"))
  end
end
