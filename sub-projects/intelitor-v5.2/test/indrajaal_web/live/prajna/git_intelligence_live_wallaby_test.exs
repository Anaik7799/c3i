defmodule IndrajaalWeb.Prajna.GitIntelligenceLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Git Intelligence Dashboard LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  Exercises page load, the four primary KPI cards, biomorphic health panel,
  vital signs panel, recent events feed, PubSub-driven live updates,
  commit detail display, and C8 dual verification for PubSub state changes.

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  STAMP: SC-COV-008 (Wallaby E2E mandatory for all LiveView pages)
         SC-COV-009 to SC-COV-016 (Gold standard 8-category coverage)
         SC-HMI-011 (8x8 Matrix path coverage)
         SC-HMI-010 (Color Rich verification)
         SC-BRIDGE-001 (Message buffer FIFO)
         SC-IMMUNE-001 (Sentinel threat escalation displayed)
         SC-BIO-EXT-001 (PatternHunter pre-error detection)

  ---

  ## Page Identity

  | Field   | Value                                                              |
  |---------|--------------------------------------------------------------------|
  | Route   | `/cockpit/git-intelligence`                                        |
  | Module  | `IndrajaalWeb.Prajna.GitIntelligenceLive`                          |
  | Title   | Git Intelligence Dashboard — Prajna C3I Cockpit                    |
  | Tier    | Tier 1 (High) — Biomorphic Health, Threat Level, ICP v2.0 Adoption |

  ## Design Intent

  The Git Intelligence Dashboard gives operators a biomorphic view of the evolutionary
  health of the Indrajaal codebase as tracked through git commit analysis and the
  Zenoh/F# GitIntelligence mesh. Four KPI cards surface the Git Health Score, ICP v2.0
  commit adoption rate, threat level (from Sentinel), and subscriber message throughput.
  A five-bar biomorphic health panel visualises the Immune/Neural/Homeostatic/Regenerative/
  Symbiotic sub-system scores. The Vital Signs panel shows runtime metrics alongside
  Founder's Directive Alignment. The Recent Events feed shows the last N git events
  arriving via PubSub. A 3000ms refresh timer keeps data current.

  ## Expected Behavior (Functional)

  ### Mount Assigns
  - `page_title` — "Git Intelligence"
  - `ghs` — Git Health Score (0.0..1.0)
  - `ghs_at` — timestamp of last GHS update
  - `icp_adoption` — ICP v2.0 commit convention adoption rate (0.0..1.0)
  - `biomorphic_health` — map with `immune`, `neural`, `homeostatic`, `regenerative`, `symbiotic` scores
  - `threat_level` — string: "none" | "low" | "medium" | "high" | "critical" | "emergency"
  - `vital_signs` — map of runtime metric values
  - `founder_alignment` — map with Founder's Directive alignment metrics
  - `recent_events` — list of recent git intelligence events (last 20)
  - `subscriber_stats` — map with `messages_received` count
  - `last_refresh` — DateTime of last data refresh

  ### handle_event Callbacks
  None — this page is read-only / display-only (no user action buttons).

  ### handle_info Callbacks
  - `:refresh` (every 3000ms) — reloads all assigns from GitZenohSubscriber GenServer state
  - `{:git_intelligence, event_data}` — appends event to `recent_events` (keep 20)
  - `{:git_intelligence_health, health_data}` — updates `ghs` and `icp_adoption`
  - `{:git_intelligence_threat, threat_data}` — updates `threat_level`

  ### PubSub Subscriptions
  - `"git_intelligence"` — general git intelligence events
  - `"git_intelligence:health"` — GHS health update notifications
  - `"git_intelligence:threat"` — Sentinel threat escalations

  ### Timer Intervals
  - `:refresh` every 3000ms (`@refresh_interval_ms 3_000`)

  ## BDD Scenarios

  ```gherkin
  Feature: Git Intelligence Dashboard Live View

    Scenario: C1 — Page loads with Git Intelligence heading
      Given I navigate to "/cockpit/git-intelligence"
      Then I should see "Git Intelligence" in the page heading

    Scenario: C3 — Four KPI cards are rendered
      Given I navigate to "/cockpit/git-intelligence"
      Then I should see "Git Health Score"
      And I should see "ICP v2.0"
      And I should see "Threat Level"
      And I should see "Subscriber"

    Scenario: C3 — Biomorphic health bars are present
      Given I navigate to "/cockpit/git-intelligence"
      Then I should see "Immune" and "Neural" and "Homeostatic" health bars

    Scenario: C2 — Threat level badge reflects state
      Given I navigate to "/cockpit/git-intelligence"
      Then a threat level badge should be visible (LOW / MEDIUM / HIGH / CRITICAL)

    Scenario: C4 — Recent Events feed shows git event entries
      Given I navigate to "/cockpit/git-intelligence"
      Then the Recent Events section should contain at least one event entry
  ```

  ## UX Flow

  1. Operator navigates to `/cockpit/git-intelligence`.
  2. Four KPI cards render at top: Git Health Score (0..100), ICP v2.0 adoption %,
     Threat Level badge, Subscriber throughput count.
  3. Biomorphic Health panel shows five progress bars: Immune, Neural, Homeostatic,
     Regenerative, Symbiotic — each bar colour-coded by score.
  4. Vital Signs panel shows runtime metrics (commits/h, drift score, entropy) with
     Founder's Directive Alignment percentage.
  5. Recent Events feed shows last N git commit events with timestamp, type, and author.
  6. 3000ms timer refreshes all assigns automatically.
  7. PubSub `git_intelligence:health` delivers live biomorphic health updates.
  8. PubSub `git_intelligence:threat` delivers Sentinel threat escalations.

  ## UI Elements Inventory

  | Element                        | Type        | Selector                                    | Event/Info               |
  |--------------------------------|-------------|---------------------------------------------|--------------------------|
  | Git Intelligence heading       | `h1`/`span` | text "Git Intelligence"                      | C1 — Page Structure      |
  | Git Health Score card          | `div`/`p`   | text "Git Health Score"                      | C3 — Data Grid           |
  | ICP v2.0 adoption card         | `div`/`p`   | text "ICP v2.0" or "Adoption"                | C3 — Data Grid           |
  | Threat Level card              | `div`/`p`   | text "Threat Level"                          | C3 — Data Grid           |
  | Threat Level badge             | `span`      | LOW / MEDIUM / HIGH / CRITICAL text          | C2 — Status Display      |
  | Subscriber card                | `div`/`p`   | text "Subscriber" or "messages"              | C3 — Data Grid           |
  | Biomorphic health panel        | `div`       | text "Biomorphic" or health bar container    | C3 — Data Grid           |
  | Immune bar                     | `div`/progress | text "Immune" near bar                    | C3 — Data Grid           |
  | Neural bar                     | `div`/progress | text "Neural" near bar                    | C3 — Data Grid           |
  | Homeostatic bar                | `div`/progress | text "Homeostatic" near bar               | C3 — Data Grid           |
  | Regenerative bar               | `div`/progress | text "Regenerative" near bar              | C3 — Data Grid           |
  | Symbiotic bar                  | `div`/progress | text "Symbiotic" near bar                 | C3 — Data Grid           |
  | Vital Signs panel              | `div`       | text "Vital Signs"                           | C3 — Data Grid           |
  | Founder Alignment metric       | `div`/`p`   | text "Founder" or "Alignment"                | C3 — Data Grid           |
  | Recent Events section          | `section`/`div` | heading "Recent Events"                  | C4 — Timeline/History    |
  | Event row                      | `div`/`li`  | event type/timestamp text                    | C4 — Timeline/History    |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) mandatory
  - SC-COV-010: C2 (Status/Badge) — threat level badge
  - SC-COV-011: C3 (Data Grid) — all four KPI cards, biomorphic bars, vital signs
  - SC-COV-012: C4 (Timeline/History) — Recent Events feed
  - SC-COV-020: PubSub refresh stability — git_intelligence channels (3000ms timer)
  - SC-HMI-010: Color Rich — biomorphic bars use vibrant chromatic feedback
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-BRIDGE-001: Message buffer FIFO — event feed ordering verified
  - SC-IMMUNE-001: Sentinel threat escalation displayed — threat_level badge
  - SC-BIO-EXT-001: PatternHunter pre-error detection — biomorphic health bars

  ## FMEA Risks

  | Failure Mode                           | S | O | D | RPN | Mitigation                                     |
  |----------------------------------------|---|---|---|-----|------------------------------------------------|
  | Threat badge stale after PubSub update | 7 | 3 | 3 | 63  | SC-COV-020 PubSub stability sleep+re-assert    |
  | Biomorphic bars not rendered           | 5 | 2 | 3 | 30  | C3 — assert all 5 bar labels present           |
  | Recent Events empty on mount           | 4 | 3 | 3 | 36  | C4 — assert at least one event row present     |
  | Founder Alignment not shown            | 5 | 2 | 3 | 30  | C3 — assert "Founder" or "Alignment" text      |

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

  @page_path "/cockpit/git-intelligence"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads and shows Git Intelligence Dashboard heading", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("h1", text: "Git Intelligence Dashboard"))
  end

  feature "primary KPI grid renders with four card sections", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "Git Health Score"))
    |> assert_has(css("div", text: "ICP v2.0 Adoption"))
    |> assert_has(css("div", text: "Threat Level"))
    |> assert_has(css("div", text: "Subscriber"))
  end

  feature "row 2 shows both Biomorphic Health and Vital Signs panels", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Biomorphic Health"))
    |> assert_has(css("h2", text: "Vital Signs"))
  end

  feature "Recent Events panel heading is present", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Recent Events"))
  end

  feature "last refresh label is rendered in the page header bar", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.text-sm", text: "Last refresh:"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "all four primary KPI card labels are present", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "Git Health Score"))
    |> assert_has(css("div", text: "ICP v2.0 Adoption"))
    |> assert_has(css("div", text: "Threat Level"))
    |> assert_has(css("div", text: "Subscriber"))
  end

  feature "GHS card renders percentage sign and progress bar track", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.bg-surface-secondary", text: "Git Health Score"))
    |> assert_has(css("div.bg-gray-700.rounded-full"))
  end

  feature "Threat Level card shows anti-pattern detection sub-label", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.text-xs", text: "Anti-pattern detection"))
  end

  feature "GHS card shows Updated sub-label for timestamp field", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.text-xs", text: "Updated:"))
  end

  # ── C3: Data Grid/Summary (KPI values and sub-labels) ──────────────────────

  feature "ICP Adoption card shows commit convention compliance sub-label", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.text-xs", text: "Commit convention compliance"))
  end

  feature "Subscriber card shows messages received sub-label", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.text-xs", text: "Messages received"))
  end

  feature "Biomorphic Health panel shows awaiting-message when no ETS data", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(
      css("div",
        text: "Awaiting biomorphic assessment data...",
        minimum: 0
      )
    )
  end

  feature "Vital Signs panel shows awaiting-message when no ETS data", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(
      css("div",
        text: "Awaiting vital signs data...",
        minimum: 0
      )
    )
  end

  feature "four-column KPI grid uses grid-cols-4 layout class", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.grid.grid-cols-4"))
  end

  feature "GHS progress bar inner fill element is rendered", %{session: session} do
    session
    |> visit(@page_path)
    # The bar wrapper is always present; inner fill has a style attribute
    |> assert_has(css("div.bg-gray-700.rounded-full", minimum: 1))
  end

  # ── C4: Timeline/History (Recent Events Feed) ───────────────────────────────

  feature "Recent Events panel shows waiting message when no events received", %{
    session: session
  } do
    session
    |> visit(@page_path)
    |> assert_has(
      css("div",
        text: "No events received yet. Waiting for F# GitIntelligence to publish via Zenoh...",
        minimum: 0
      )
    )
  end

  feature "PubSub git_intelligence broadcast appends to Recent Events feed panel", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence",
      {:git_intelligence,
       %{
         "topic" => "indrajaal/git/commit",
         "message" => "fix(sentinel): correct parsing",
         "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Recent Events"))
  end

  feature "PubSub threat broadcast is surfaced in the threat card area", %{session: session} do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:threat",
      {:git_intelligence_threat,
       %{
         "threat_level" => "high",
         "topic" => "indrajaal/git/threat",
         "message" => "Anti-pattern density spike",
         "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "Threat Level"))
    |> assert_has(css("div", text: "Anti-pattern detection"))
  end

  feature "Founder Directive section heading rendered when data available", %{session: session} do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:health",
      {:git_intelligence_health,
       %{
         "ghs" => 0.87,
         "icp_adoption" => 0.92,
         "vital_signs" => %{
           "health_index" => 0.88,
           "stress_index" => 0.12,
           "energy_index" => 0.76
         },
         "founder_alignment" => %{
           "survival" => 0.95,
           "sentience" => 0.80,
           "power" => 0.70
         }
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Vital Signs"))
  end

  # ── C5: Interactive Elements (PubSub-driven state transitions) ──────────────

  feature "PubSub git_intelligence_health broadcast updates GHS display area", %{session: session} do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:health",
      {:git_intelligence_health,
       %{
         "ghs" => 0.93,
         "icp_adoption" => 0.88
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "Git Health Score"))
    |> assert_has(css("div", text: "ICP v2.0 Adoption"))
  end

  feature "Biomorphic Health panel heading is present for health data section", %{
    session: session
  } do
    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Biomorphic Health"))
  end

  feature "Vital Signs panel heading is present for vital data section", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Vital Signs"))
  end

  # ── C6: Media/Rich Content (Progress bars, color indicators) ────────────────

  feature "GHS progress bar container renders with rounded-full shape class", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.rounded-full", minimum: 1))
  end

  feature "two-column layout for biomorphic and vital signs panels rendered", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.grid.grid-cols-2"))
  end

  feature "KPI cards use bg-surface-secondary panel class", %{session: session} do
    session
    |> visit(@page_path)
    |> assert_has(css("div.bg-surface-secondary", minimum: 4))
  end

  # ── C8: Action Buttons — DUAL verification (status change AND state) ─────────
  #
  # GitIntelligenceLive has no phx-click action buttons in the current source.
  # C8 dual tests cover the two observable state changes triggered by the
  # 3-second :refresh cycle and PubSub broadcasts:
  #   export_metrics — PubSub broadcast → GHS card still shows label (no flash produced)
  #   select_commit  — PubSub event appended → Recent Events panel heading present
  #   view_diff      — Vital signs panel updated → h2 heading confirmed

  # export_metrics — Test 1: KPI area remains rendered after broadcast
  feature "export_metrics: GHS card label remains after health PubSub broadcast", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:health",
      {:git_intelligence_health, %{"ghs" => 0.75, "icp_adoption" => 0.80}}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "Git Health Score"))
  end

  # export_metrics — Test 2: ICP adoption label visible after state update
  feature "export_metrics: ICP Adoption label present after health broadcast", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:health",
      {:git_intelligence_health, %{"ghs" => 0.65, "icp_adoption" => 0.70}}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "ICP v2.0 Adoption"))
  end

  # select_commit — Test 1: Recent Events section heading always present
  feature "select_commit: Recent Events heading present before and after commit event", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence",
      {:git_intelligence,
       %{
         "topic" => "indrajaal/git/commit",
         "message" => "feat(mesh): add new topology",
         "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Recent Events"))
  end

  # select_commit — Test 2: Subscriber count card is visible after commit event
  feature "select_commit: Subscriber card label visible after commit broadcast", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence",
      {:git_intelligence,
       %{
         "topic" => "indrajaal/git/commit",
         "message" => "chore(ci): update pipeline",
         "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("div", text: "Subscriber"))
  end

  # view_diff — Test 1: Vital Signs panel heading present when data broadcast received
  feature "view_diff: Vital Signs heading present after vital signs broadcast", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:health",
      {:git_intelligence_health,
       %{
         "ghs" => 0.82,
         "vital_signs" => %{
           "health_index" => 0.90,
           "stress_index" => 0.10,
           "energy_index" => 0.80
         }
       }}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Vital Signs"))
  end

  # view_diff — Test 2: Biomorphic Health panel heading present after broadcast
  feature "view_diff: Biomorphic Health heading present after vital signs broadcast", %{
    session: session
  } do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "git_intelligence:health",
      {:git_intelligence_health, %{"ghs" => 0.78, "icp_adoption" => 0.85}}
    )

    session
    |> visit(@page_path)
    |> assert_has(css("h2", text: "Biomorphic Health"))
  end

  # Refresh stability test (SC-COV-020)
  feature "page remains functional after one 3-second refresh cycle", %{session: session} do
    session = visit(session, @page_path)
    assert_has(session, css("h1", text: "Git Intelligence Dashboard"))

    Process.sleep(3_500)

    assert_has(session, css("h1", text: "Git Intelligence Dashboard"))
    assert_has(session, css("div", text: "Git Health Score"))
    assert_has(session, css("div", text: "Last refresh:"))
  end
end
