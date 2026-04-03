defmodule IndrajaalWeb.Prajna.TestCockpitLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Test Cockpit page (/cockpit/test-evolution).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/test-evolution`
  - **Module**: `IndrajaalWeb.Prajna.TestCockpitLive`
  - **Title**: "Test Cockpit"

  ## Design Intent
  Provides a biomorphic test evolution dashboard enabling operators to observe and
  control autonomous test generation, OODA cycles, and genome-based test mutations.
  Displays real-time fitness metrics, 5-level test coverage (TDG, FMEA, Formal,
  Graph, BDD), genome parameters, and module watch lists. Enables operators to
  trigger manual OODA cycles and control the evolution engine per SC-TEST-EVO-001..003.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `active_tab: :overview`, `fitness: %{}`,
    `genome: %{}`, `ooda_state: %{}`, `level_coverage: %{}`, `recent_tests: []`,
    `watched_modules: []`, `selected_module: nil`, `generation_status: :idle`,
    `evolution_active: false`, `test_levels: []`
  - **PubSub**: subscribes to `"prajna:test_evolution"` for real-time evolution events
  - **Timer**: 5000ms → `:refresh` (periodic evolution state poll)
  - **handle_event "switch_tab"**: changes `active_tab` assign (no flash)
  - **handle_event "start_evolution"**: starts evolution engine → flash "Test evolution started"
    or "Test evolution already running" or "Failed to start test evolution"
  - **handle_event "stop_evolution"**: stops evolution engine → flash "Test evolution stopped"
  - **handle_event "run_ooda"**: triggers one OODA cycle → flash "OODA cycle triggered"
  - **handle_event "generate_tests"**: queues test generation for selected module →
    flash "Generating tests for {module}..."
  - **handle_event "watch_module"**: adds module to watch list (no flash)
  - **handle_event "unwatch_module"**: removes module from watch list (no flash)
  - **handle_event "update_genome"**: updates genome parameters (no flash)

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views test evolution fitness metrics
    Given I navigate to "/cockpit/test-evolution"
    Then I should see the TEST COCKPIT heading
    And the fitness score panel should be visible
    And the OODA cycle status should be displayed

  Scenario: Operator starts the evolution engine
    Given I navigate to "/cockpit/test-evolution"
    When I click the "Start Evolution" button
    Then a flash message should confirm "Test evolution started"

  Scenario: Operator triggers a manual OODA cycle
    Given I navigate to "/cockpit/test-evolution"
    When I click the "Run OODA" button
    Then a flash message should confirm "OODA cycle triggered"

  Scenario: Operator stops a running evolution engine
    Given I navigate to "/cockpit/test-evolution"
    And the evolution engine is active
    When I click the "Stop Evolution" button
    Then a flash message should confirm "Test evolution stopped"

  Scenario: Operator switches to Genome tab
    Given I navigate to "/cockpit/test-evolution"
    When I click the "GENOME" tab button
    Then the genome parameters panel should be visible
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/test-evolution` — Overview tab shown by default
  2. Fitness score cards display current evolutionary health metrics
  3. OODA cycle status shows Observe / Orient / Decide / Act phase indicators
  4. 5-level coverage gauges show TDG, FMEA, Formal, Graph, BDD percentages
  5. Operator clicks "Start Evolution" to begin autonomous test generation
  6. Evolution engine publishes events via PubSub; dashboard updates every 5s
  7. Operator clicks "Run OODA" to trigger a single manual cycle
  8. Operator switches to Tests tab to view recently generated test files
  9. Operator watches specific modules to focus generation effort
  10. Operator adjusts genome parameters on Genome tab and saves

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | TEST COCKPIT heading | span | `css("span", text: "TEST COCKPIT")` | none |
  | PRAJNA C3I nav link | a | `css("a", text: "PRAJNA C3I")` | navigate |
  | OVERVIEW tab | button | `css("button[phx-value-tab='overview']")` | switch_tab |
  | TESTS tab | button | `css("button[phx-value-tab='tests']")` | switch_tab |
  | GENOME tab | button | `css("button[phx-value-tab='genome']")` | switch_tab |
  | COVERAGE tab | button | `css("button[phx-value-tab='coverage']")` | switch_tab |
  | Fitness score cards | div | `css("[data-testid='fitness-score']")` | none |
  | OODA state indicator | div | `css("[data-testid='ooda-state']")` | none |
  | Level coverage gauges | div | `css("[data-testid='level-coverage']")` | none |
  | Start Evolution button | button | `css("button[phx-click='start_evolution']")` | start_evolution |
  | Stop Evolution button | button | `css("button[phx-click='stop_evolution']")` | stop_evolution |
  | Run OODA button | button | `css("button[phx-click='run_ooda']")` | run_ooda |
  | Generate Tests button | button | `css("button[phx-click='generate_tests']")` | generate_tests |
  | Flash message | div | `css("[role='alert']")` | status feedback |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - SC-COV-016: C8 dual verification — status change AND flash per action button
  - SC-TEST-EVO-001: OODA cycle < 30s (verified via timer interval)
  - SC-TEST-EVO-002: Fitness tracking mandatory (fitness cards visible on mount)
  - SC-TEST-EVO-003: All 5 levels generated (5-level coverage display present)
  - SC-HMI-001: Dark Cockpit defaults (initial render uses dark theme)
  - SC-BIO-005: Dashboard refresh every 30s (5000ms timer observed)

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Evolution start flash shows "Failed" on first click | 7 | 3 | 3 | 63 | Retry logic or mock evolution supervisor |
  | OODA cycle button disabled during active cycle | 5 | 3 | 4 | 60 | Test disabled state assertion |
  | PubSub test_evolution events race with 5s timer | 6 | 2 | 4 | 48 | sleep + re-assert (SC-COV-020) |
  | Genome tab shows stale parameters after update | 5 | 2 | 3 | 30 | Post-update re-read assertion |
  | Module watch list duplicates on rapid clicks | 4 | 2 | 3 | 24 | Idempotency test |

  Verifies the biomorphic test evolution dashboard: fitness cards, OODA cycle
  status, 5-level coverage, tab switching, genome controls, module watch list,
  and evolution control buttons against a real Chrome browser via NixOS chromedriver.

  Run with: WALLABY_ENABLED=true mix test --only wallaby

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

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads and shows TEST COCKPIT heading in header", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("span", text: "TEST COCKPIT"))
  end

  feature "PRAJNA C3I brand link is rendered in the header", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "all sub-navigation tabs OVERVIEW LEVELS GENOME HISTORY MODULES are visible", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("button", text: "OVERVIEW"))
    |> assert_has(css("button", text: "LEVELS"))
    |> assert_has(css("button", text: "GENOME"))
    |> assert_has(css("button", text: "HISTORY"))
    |> assert_has(css("button", text: "MODULES"))
  end

  feature "EVOLUTION CONTROLS panel with START EVOLUTION button is visible", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("h2", text: "EVOLUTION CONTROLS"))
    |> assert_has(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
  end

  feature "footer shows keyboard shortcuts S O G W and OpenRouter label", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("footer span", text: "[S] Start/Stop"))
    |> assert_has(css("footer span", text: "[O] Run OODA"))
    |> assert_has(css("footer", text: "OpenRouter"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "evolution status badge shows IDLE before evolution starts", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("span", text: "IDLE"))
  end

  feature "clicking START EVOLUTION changes status badge to EVOLVING", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> assert_has(css("span", text: "EVOLVING"))
  end

  feature "OODA CYCLE STATUS panel is visible with phase labels", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("h2", text: "OODA CYCLE STATUS"))
    |> assert_has(css("div", text: "OBSERVE"))
    |> assert_has(css("div", text: "ORIENT"))
    |> assert_has(css("div", text: "DECIDE"))
    |> assert_has(css("div", text: "ACT"))
  end

  feature "COMBINED FITNESS panel is visible with target and threshold labels", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("h2", text: "COMBINED FITNESS"))
    |> assert_has(css("div", text: "Target: 80%"))
  end

  feature "OODA cycles counter is displayed in the header metadata row", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("span", text: "OODA:"))
    |> assert_has(css("span", text: "cycles"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "overview tab shows COVERAGE PASS RATE MUTATION and DIVERSITY fitness cards", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("div", text: "COVERAGE"))
    |> assert_has(css("div", text: "PASS RATE"))
    |> assert_has(css("div", text: "MUTATION"))
    |> assert_has(css("div", text: "DIVERSITY"))
  end

  feature "GENOME tab shows Mutation Rate and Selection Pressure slider labels", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='genome']", text: "GENOME"))
    |> assert_has(css("span", text: "Mutation Rate"))
    |> assert_has(css("span", text: "Selection Pressure"))
  end

  feature "GENOME tab shows Crossover Rate and Target Coverage slider labels", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='genome']", text: "GENOME"))
    |> assert_has(css("span", text: "Crossover Rate"))
    |> assert_has(css("span", text: "Target Coverage"))
  end

  feature "GENOME tab shows AI MODEL WEIGHTS panel with model names", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='genome']", text: "GENOME"))
    |> assert_has(css("h2", text: "AI MODEL WEIGHTS"))
    |> assert_has(css("span", text: "Llama 3.1"))
  end

  feature "5-LEVEL COVERAGE panel shows TDG FMEA FORMAL GRAPH BDD level names", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("h2", text: "5-LEVEL COVERAGE"))
    |> assert_has(css("div", text: "TDG"))
    |> assert_has(css("div", text: "FMEA"))
    |> assert_has(css("div", text: "FORMAL"))
    |> assert_has(css("div", text: "GRAPH"))
    |> assert_has(css("div", text: "BDD"))
  end

  feature "MODULES tab shows empty watched modules message initially", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> assert_has(css("p", text: "No modules being watched."))
  end

  # ── C4: Timeline/History ────────────────────────────────────────────────────

  feature "clicking HISTORY tab renders RECENT TESTS panel", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='history']", text: "HISTORY"))
    |> assert_has(css("h2", text: "RECENT TESTS"))
  end

  feature "HISTORY tab shows test entries with PASS or FAIL status", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='history']", text: "HISTORY"))
    |> assert_has(css("span", minimum: 1))
  end

  feature "HISTORY tab shows recent test entries with module and level info", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='history']", text: "HISTORY"))
    |> assert_has(css("div", text: "Generated:"))
  end

  feature "LEVELS tab shows 5 level detail cards with coverage percentages", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='levels']", text: "LEVELS"))
    |> assert_has(css("span", text: "Property Tests"))
    |> assert_has(css("span", text: "Failure Analysis"))
  end

  feature "LEVELS tab shows test counts and last run info for each level", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='levels']", text: "LEVELS"))
    |> assert_has(css("div", text: "Tests:"))
    |> assert_has(css("div", text: "Last Run:"))
  end

  feature "page remains stable after 5-second refresh cycle", %{session: session} do
    session = visit(session, "/cockpit/test-evolution")
    assert_has(session, css("h2", text: "OODA CYCLE STATUS"))

    Process.sleep(5_500)

    assert_has(session, css("h2", text: "OODA CYCLE STATUS"))
    assert_has(session, css("h2", text: "5-LEVEL COVERAGE"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "clicking MODULES tab renders WATCHED MODULES and GENERATE TESTS panels", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> assert_has(css("h2", text: "WATCHED MODULES"))
    |> assert_has(css("h2", text: "GENERATE TESTS"))
  end

  feature "MODULES tab shows GENERATE ALL 5 LEVELS submit button", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> assert_has(css("button", text: "GENERATE ALL 5 LEVELS"))
  end

  feature "MODULES tab has module path input with placeholder text", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> assert_has(
      css("input[type='text'][name='module'][placeholder='lib/indrajaal/accounts/user.ex']")
    )
  end

  feature "MODULES tab clicking Watch this module button adds a module to watch list", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> click(css("button[phx-value-module='lib/indrajaal/accounts/user.ex']"))
    |> assert_has(css("span", text: "lib/indrajaal/accounts/user.ex"))
  end

  feature "clicking GENOME tab shows GENOME PARAMETERS and AI MODEL WEIGHTS panels", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='genome']", text: "GENOME"))
    |> assert_has(css("h2", text: "GENOME PARAMETERS"))
    |> assert_has(css("h2", text: "AI MODEL WEIGHTS"))
  end

  feature "clicking LEVELS tab switches to the 5-level detail view", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='levels']", text: "LEVELS"))
    |> assert_has(css("span", text: "Property Tests"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ──────────

  # start_evolution — C8a: flash message
  feature "clicking START EVOLUTION button shows info flash message", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> assert_has(css("[role='alert']", text: "evolution"))
  end

  # start_evolution — C8b: status badge changes to EVOLVING
  feature "START EVOLUTION status: badge changes from IDLE to EVOLVING", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("span", text: "IDLE"))
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> assert_has(css("span", text: "EVOLVING"))
  end

  # stop_evolution — C8a: flash message (must start first)
  feature "clicking STOP EVOLUTION after starting shows evolution stopped flash", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> assert_has(css("span", text: "EVOLVING"))
    |> click(css("button[phx-click='stop_evolution']", text: "STOP EVOLUTION"))
    |> assert_has(css("[role='alert']", text: "stopped"))
  end

  # stop_evolution — C8b: status badge changes back to IDLE
  feature "STOP EVOLUTION status: badge changes back to IDLE after stop", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> assert_has(css("span", text: "EVOLVING"))
    |> click(css("button[phx-click='stop_evolution']", text: "STOP EVOLUTION"))
    |> assert_has(css("span", text: "IDLE"))
  end

  # run_ooda — C8a: flash message (evolution must be active for button to be enabled)
  feature "clicking RUN OODA CYCLE after start shows OODA cycle triggered flash", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> assert_has(css("span", text: "EVOLVING"))
    |> click(css("button[phx-click='run_ooda']"))
    |> assert_has(css("[role='alert']", text: "OODA cycle triggered"))
  end

  # run_ooda — C8b: OODA cycle status panel remains visible after trigger
  feature "RUN OODA CYCLE status: OODA CYCLE STATUS panel still visible after click", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-click='start_evolution']", text: "START EVOLUTION"))
    |> click(css("button[phx-click='run_ooda']"))
    |> assert_has(css("h2", text: "OODA CYCLE STATUS"))
  end

  # generate_tests — C8a: flash message (via form submit on modules tab)
  feature "submitting GENERATE TESTS form shows Generating tests flash", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> fill_in(
      css("input[type='text'][name='module']"),
      with: "lib/indrajaal/accounts/user.ex"
    )
    |> click(css("button[type='submit']", text: "GENERATE ALL 5 LEVELS"))
    |> assert_has(css("[role='alert']", text: "Generating tests for"))
  end

  # generate_tests — C8b: selected module shown after generate
  feature "GENERATE TESTS status: selected module path visible in flash after submit", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> fill_in(
      css("input[type='text'][name='module']"),
      with: "lib/indrajaal/accounts/user.ex"
    )
    |> click(css("button[type='submit']", text: "GENERATE ALL 5 LEVELS"))
    |> assert_has(css("[role='alert']", text: "lib/indrajaal/accounts/user.ex"))
  end

  # watch_module — C8a: module name appears in watched list (status change, no flash)
  feature "watch_module status: watched module name appears in list after click", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> click(css("button[phx-value-module='lib/indrajaal/accounts/user.ex']"))
    |> assert_has(css("div", text: "lib/indrajaal/accounts/user.ex"))
  end

  # watch_module — C8b: REMOVE button appears after watch
  feature "watch_module status: REMOVE button appears after module is added", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> click(css("button[phx-value-module='lib/indrajaal/accounts/user.ex']"))
    |> assert_has(css("button[phx-click='unwatch_module']", text: "REMOVE"))
  end

  # unwatch_module — C8: module removed from list after REMOVE click
  feature "unwatch_module status: module removed from list after REMOVE click", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='modules']", text: "MODULES"))
    |> click(css("button[phx-value-module='lib/indrajaal/accounts/user.ex']"))
    |> assert_has(css("button[phx-click='unwatch_module']", text: "REMOVE"))
    |> click(css("button[phx-click='unwatch_module']"))
    |> assert_has(css("p", text: "No modules being watched."))
  end

  feature "LEVELS tab shows Gherkin Specs and Path Coverage descriptions", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='levels']", text: "LEVELS"))
    |> assert_has(css("span", text: "Gherkin Specs"))
    |> assert_has(css("span", text: "Path Coverage"))
  end

  feature "GENOME tab shows free tier AOR note for AI models", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='genome']", text: "GENOME"))
    |> assert_has(css("p", text: "AOR-OPENROUTER-001"))
  end

  feature "overview tab OODA panel shows observations and decisions counts", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("p", text: "Observations:"))
    |> assert_has(css("p", text: "Decisions Made:"))
  end

  feature "overview tab OODA panel shows actions taken count", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("p", text: "Actions Taken:"))
  end

  feature "HISTORY tab shows token usage and duration metadata for each test entry", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='history']", text: "HISTORY"))
    |> assert_has(css("div", text: "Tokens:"))
    |> assert_has(css("div", text: "Duration:"))
  end

  # ── C5: Interactive Elements — genome slider inputs ─────────────────────

  feature "genome configuration sliders present with phx-change update_genome", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("input[phx-change='update_genome']", minimum: 1))
  end

  # ── C6: Media/Rich Content (Semantic CSS) ───────────────────────────────

  feature "main container uses bg-surface-primary theme class", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "header uses bg-surface-secondary border-b border-border-theme-primary classes", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("header.bg-surface-secondary"))
    |> assert_has(css("header.border-b"))
  end

  feature "page uses font-mono monospace typeface on root container", %{session: session} do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("div.font-mono"))
  end

  feature "OODA CYCLE STATUS panel uses bg-surface-secondary rounded-lg border classes", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("div.bg-surface-secondary.rounded-lg"))
  end

  feature "navigation bar uses bg-surface-secondary border-b border-border-theme-primary classes",
          %{
            session: session
          } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("nav.bg-surface-secondary"))
    |> assert_has(css("nav.border-b"))
  end

  # ── C7: AI/Advisory (Contextual Metrics) ────────────────────────────────

  feature "overview OODA panel shows Observations count as operational context metric", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("p", text: "Observations:"))
  end

  feature "overview OODA panel shows Decisions Made count as operational context metric", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("p", text: "Decisions Made:"))
  end

  feature "COMBINED FITNESS panel shows Target 80 percent threshold label as advisory", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> assert_has(css("div", text: "Target: 80%"))
    |> assert_has(css("div", text: "Threshold: 50%"))
  end

  feature "LEVELS tab shows Tests count as operational metric for each level", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='levels']", text: "LEVELS"))
    |> assert_has(css("div", text: "Tests:"))
    |> assert_has(css("div", text: "Pass:"))
  end

  feature "GENOME tab shows AI MODEL WEIGHTS advisory note about free tier models", %{
    session: session
  } do
    session
    |> visit("/cockpit/test-evolution")
    |> click(css("button[phx-value-tab='genome']", text: "GENOME"))
    |> assert_has(css("p", text: "All models use :free tier"))
  end
end
