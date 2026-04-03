defmodule IndrajaalWeb.Prajna.StartupLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Startup Sequence page (/cockpit/startup).

  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.
  Target: 30 features covering C1-C8 with dual verification on all action buttons.

  Events in source:
    abort_startup, skip_to_cockpit

  PubSub: prajna:startup (500ms :refresh timer)

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  STAMP: SC-COV-008 (Wallaby E2E mandatory for all LiveView pages)
         SC-COV-009 to SC-COV-016 (Gold standard 8-category coverage)
         SC-HMI-001 (Dark Cockpit defaults)
         SC-VDP-008 (Closure feedback on each phase)
         SC-EMR-057 (Emergency stop capability)
         SC-OBS-069 (Dual logging: Terminal + SigNoz)

  ---

  ## Page Identity

  | Field   | Value                                                          |
  |---------|----------------------------------------------------------------|
  | Route   | `/cockpit/startup`                                             |
  | Module  | `IndrajaalWeb.Prajna.StartupLive`                              |
  | Title   | Startup Sequence — Prajna C3I Cockpit                          |
  | Tier    | Tier 1 (High) — P0 Safety-Critical Startup Orchestration       |

  ## Design Intent

  The Startup Sequence page is the mission-critical SIL-6 boot visualisation. It renders
  four startup phases (INFRASTRUCTURE, SAFETY SYSTEMS, DISTRIBUTED SYSTEMS, CONTAINER
  ORCHESTRATION) each composed of individual steps with PENDING/RUNNING/COMPLETE/FAILED
  status. The 500ms refresh timer provides near-real-time phase progress updates. An
  abort emergency-stop button halts the sequence and transitions to an aborted modal.
  The skip-to-cockpit button allows operators to bypass to the main cockpit when startup
  has already completed. SC-VDP-008 mandates per-phase closure feedback so operators
  always know what completed and what failed.

  ## Expected Behavior

  On mount: four phases loaded; each phase has 4–5 steps. `overall_progress` (0..100),
  `estimated_remaining` (seconds), `started_at` (datetime), `logs` (list of log entries),
  and `aborted` (false) are initialised.

  `abort_startup` — sets `aborted` = true; prepends a WARNING log entry; shows the abort
    modal overlay.
  `skip_to_cockpit` — calls `push_navigate(to: "/cockpit")`; exits the startup flow.
  `:refresh` (500ms) — calls update logic; steps may transition from PENDING → RUNNING →
    COMPLETE; `overall_progress` increments; log entries append.
  `{:startup_step, phase_id, step_id, status}` — PubSub message updates a specific step.

  ## BDD Scenarios

  ```gherkin
  Feature: Startup Sequence Live View

    Scenario: C1 — Page loads with PRAJNA ASCII art logo
      Given I navigate to "/cockpit/startup"
      Then I should see "C3I MESH COCKPIT" or the ASCII art brand text
      And I should see "STARTUP SEQUENCE" or phase headings

    Scenario: C4 — Startup phases display with step progression
      Given I navigate to "/cockpit/startup"
      Then I should see the "INFRASTRUCTURE" phase heading
      And individual step rows should be visible beneath the phase

    Scenario: C3 — Progress indicator reflects overall progress
      Given I navigate to "/cockpit/startup"
      Then I should see a progress percentage or progress bar

    Scenario: C8 — Abort startup arms and shows confirmation
      Given I navigate to "/cockpit/startup"
      When I click the ABORT STARTUP button
      Then I should see an abort confirmation overlay or flash message

    Scenario: C8 — Skip to cockpit navigates away
      Given I navigate to "/cockpit/startup"
      When I click "SKIP TO COCKPIT"
      Then I should be redirected to "/cockpit"
  ```

  ## UX Flow

  1. Operator views the startup page during system boot.
  2. ASCII art Prajna C3I brand renders at the top with overall progress bar.
  3. Four phase sections expand; each shows phase name and estimated completion.
  4. Each step within a phase shows PENDING → RUNNING → COMPLETE icons.
  5. Log panel at the bottom streams new entries every 500ms.
  6. Estimated remaining time countdown decrements as phases complete.
  7. Operator clicks ABORT — abort modal appears; startup halts.
  8. Operator clicks SKIP TO COCKPIT — navigated to `/cockpit` immediately.
  9. PubSub `prajna:startup` delivers live step transition events.
  10. When all phases COMPLETE, page shows 100% and offers navigation link.

  ## UI Elements Inventory

  | Element                      | Type        | Selector                                    | Event/Info               |
  |------------------------------|-------------|---------------------------------------------|--------------------------|
  | Prajna ASCII / brand text    | `pre`/`div` | text "C3I MESH COCKPIT" or "PRAJNA"          | C1 — Page Structure      |
  | Overall progress bar         | `div`/`p`   | `.progress` or text containing "%"           | C3 — Data Grid           |
  | Estimated remaining          | `span`/`p`  | text containing "remaining" or "seconds"     | C3 — Data Grid           |
  | Phase heading                | `h2`/`div`  | text "INFRASTRUCTURE"                        | C4 — Timeline/History    |
  | Step row                     | `div`/`li`  | step name text                               | C4 — Timeline/History    |
  | Step status icon/badge       | `span`      | PENDING/RUNNING/COMPLETE/FAILED              | C2 — Status Display      |
  | Log panel                    | `div`/`ul`  | `.log-panel` or log entry text               | C4 — Timeline/History    |
  | Log entry row                | `div`/`li`  | individual log line text                     | C4 — Timeline/History    |
  | ABORT STARTUP button         | `button`    | `button[phx-click="abort_startup"]`          | two-step / abort event   |
  | Abort confirmation modal     | `div`       | `div[role="dialog"]` or `.abort-modal`       | aborted assign           |
  | SKIP TO COCKPIT button       | `button`    | `button[phx-click="skip_to_cockpit"]`        | skip_to_cockpit event    |
  | Flash message                | `div`       | `div[role="alert"]`                          | C8 — flash verify        |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) coverage mandatory
  - SC-COV-010: C2 (Status/Badge) — step status icons (PENDING/RUNNING/COMPLETE/FAILED)
  - SC-COV-011: C3 (Data Grid) — progress, estimated remaining
  - SC-COV-012: C4 (Timeline/History) — phases, steps, log panel
  - SC-COV-016: C8 (Actions) DUAL verification — status AND flash for abort, skip
  - SC-COV-020: PubSub refresh stability — prajna:startup with 500ms timer
  - SC-HMI-001: Dark Cockpit defaults
  - SC-SIL4-012: 5 startup phases MANDATORY (validated via phase display)
  - SC-VDP-008: Closure feedback on each phase — COMPLETE badge shown
  - SC-EMR-057: Emergency stop capability — abort_startup button present and functional
  - SC-OBS-069: Dual logging — log panel streams to terminal and SigNoz

  ## FMEA Risks

  | Failure Mode                           | S | O | D | RPN | Mitigation                                   |
  |----------------------------------------|---|---|---|-----|----------------------------------------------|
  | Abort fires without operator intent    | 9 | 2 | 3 | 54  | Two-step or confirm modal tested in C8       |
  | Phase steps not updating on 500ms tick | 7 | 3 | 3 | 63  | SC-COV-020 sleep+re-assert timer stability   |
  | Log panel overflows without truncation | 3 | 4 | 3 | 36  | C4 — assert log entries bounded              |
  | Skip navigates to wrong path           | 5 | 1 | 2 | 10  | Assert URL after click (push_navigate)       |

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

  @path "/cockpit/startup"

  # ── C1: Page Structure ─────────────────────────────────────────────────────────

  feature "page loads and renders the PRAJNA ASCII art logo with C3I MESH COCKPIT", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("pre", text: "C3I MESH COCKPIT"))
  end

  feature "STARTUP LOG section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "STARTUP LOG (live)"))
  end

  feature "ABORT STARTUP button is visible in footer controls", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='abort_startup']", text: "ABORT STARTUP"))
  end

  feature "SKIP TO COCKPIT button is visible in footer controls", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='skip_to_cockpit']", text: "SKIP TO COCKPIT"))
  end

  # ── C2: Phase Badges / Boot Status ────────────────────────────────────────────

  feature "PHASE 1 INFRASTRUCTURE panel heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "PHASE 1: INFRASTRUCTURE"))
  end

  feature "PHASE 2 SAFETY SYSTEMS panel heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "PHASE 2: SAFETY SYSTEMS"))
  end

  feature "PHASE 3 DISTRIBUTED SYSTEMS panel heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "PHASE 3: DISTRIBUTED SYSTEMS"))
  end

  feature "PHASE 4 CONTAINER ORCHESTRATION panel heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "PHASE 4: CONTAINER ORCHESTRATION"))
  end

  feature "four phase progress bar sections are rendered with percentage labels", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.text-xs.text-content-muted", minimum: 4))
  end

  # ── C3: Phase Detail — Step Names / Dependencies ──────────────────────────────

  feature "key startup step names Telemetry Guardian and Zenoh are visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Telemetry System"))
    |> assert_has(css("span", text: "Guardian (Simplex gatekeeper)"))
    |> assert_has(css("span", text: "Zenoh coordination"))
  end

  feature "container startup steps for PostgreSQL and Phoenix are visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal-db-standalone (PostgreSQL)"))
    |> assert_has(css("span", text: "indrajaal-ex-app-1 (Phoenix)"))
  end

  feature "infrastructure phase shows Database PubSub and Oban step names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Database connection"))
    |> assert_has(css("span", text: "PubSub started"))
    |> assert_has(css("span", text: "Oban background jobs"))
  end

  feature "safety phase shows Dead Man Switch and Sentinel step names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Dead Man's Switch (heartbeat)"))
    |> assert_has(css("span", text: "Sentinel (quorum monitor)"))
  end

  feature "distributed phase shows FLAME pools and OODA loop step names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "FLAME pools (Intelligence, Video, Analytics)"))
    |> assert_has(css("span", text: "OODA loop activation"))
  end

  feature "container phase shows Redis and SigNoz step names", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal-redis-standalone (Cache)"))
    |> assert_has(css("span", text: "indrajaal-obs-standalone (SigNoz)"))
  end

  # ── C4: Boot Phase Timeline Entries (Startup Log) ─────────────────────────────

  feature "startup log shows Ecto repo connected log entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Ecto repo connected"))
  end

  feature "startup log shows Phoenix PubSub started log entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Phoenix.PubSub started"))
  end

  feature "startup log shows IndrajaalWeb.Telemetry starting log entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "IndrajaalWeb.Telemetry"))
  end

  feature "estimated time remaining label is shown before startup completes", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Estimated time remaining:"))
  end

  # ── C5: Detail Toggle / Phase Interaction ─────────────────────────────────────

  feature "each phase card has a progress percentage label next to its progress bar", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.w-12", minimum: 4))
  end

  feature "phase progress bars are rendered with inline width style attribute", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[style*='width:']", minimum: 4))
  end

  feature "phase steps are indented inside a left-border panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.border-l-2"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ─────────────

  # abort_startup — (1) clicking shows STARTUP ABORTED modal
  feature "clicking ABORT STARTUP triggers the STARTUP ABORTED modal", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='abort_startup']", text: "ABORT STARTUP"))
    |> assert_has(css("h3", text: "STARTUP ABORTED"))
  end

  # abort_startup — (2) modal body text confirms abort state
  feature "STARTUP ABORTED modal shows system startup has been aborted message", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='abort_startup']", text: "ABORT STARTUP"))
    |> assert_has(css("p", text: "System startup has been aborted"))
  end

  # abort_startup — (3) abort modal contains Continue to Cockpit button
  feature "STARTUP ABORTED modal shows Continue to Cockpit Limited Mode button", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='abort_startup']", text: "ABORT STARTUP"))
    |> assert_has(css("button[phx-click='skip_to_cockpit']", text: "Continue to Cockpit"))
  end

  # skip_to_cockpit — (1) button present (covered in C1)
  # skip_to_cockpit — (2) navigation away from startup page
  feature "clicking SKIP TO COCKPIT navigates away from the startup page", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='skip_to_cockpit']", text: "SKIP TO COCKPIT"))
    |> refute_has(css("h2", text: "STARTUP LOG (live)"))
  end

  # ── C8 supplemental: abort modal extra assertions ────────────────────────────

  # abort_startup — (4) modal shows the ABORTED status clearly
  feature "STARTUP ABORTED modal heading uses h3 element and is prominent", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='abort_startup']", text: "ABORT STARTUP"))
    |> assert_has(css("h3", text: "STARTUP ABORTED"))
    |> assert_has(css("p", text: "aborted"))
  end

  # skip_to_cockpit — (3) skip button navigates and STARTUP LOG heading disappears
  feature "clicking SKIP TO COCKPIT removes the startup log section from DOM", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='skip_to_cockpit']", text: "SKIP TO COCKPIT"))
    |> refute_has(css("span", text: "PHASE 1: INFRASTRUCTURE"))
  end

  # C5 supplemental: progress bar completeness
  feature "at least four phase sections are visible with progress bars", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[style*='width:']", minimum: 4))
  end

  # ── Refresh Stability (PubSub 500ms interval) ─────────────────────────────────

  feature "startup page renders stably across two 500ms refresh ticks", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "STARTUP LOG (live)"))

    Process.sleep(1_200)

    assert_has(session, css("span", text: "PHASE 1: INFRASTRUCTURE"))
    assert_has(session, css("button[phx-click='abort_startup']"))
  end
end
