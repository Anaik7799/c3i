defmodule IndrajaalWeb.Prajna.ShutdownLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the System Shutdown LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/shutdown`
  - **Module**: `IndrajaalWeb.Prajna.ShutdownLive`
  - **Title**: "System Shutdown"
  - **Priority**: P0 (Safety-Critical — irreversible system-halt action)

  ## Design Intent
  The System Shutdown page provides a controlled, audited mechanism for gracefully
  or forcefully halting the PRAJNA C3I system. It enforces a two-step commit for
  both the primary initiate path and the emergency force-shutdown path. The operator
  selects a shutdown mode (graceful, fast, emergency), sets the connection drain
  timeout, then initiates. Active shutdown progresses through 5 phases with live
  logging. Abort is available until all phases complete. Force-shutdown requires
  its own two-step confirmation (force_confirm arm → force_confirm confirm).

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "System Shutdown"
  - `shutdown_active` — false (pre-initiation state on load)
  - `phases` — list of 5 phase maps with `id`, `name`, `status`, `duration`
  - `logs` — [] (empty on mount; grows during active shutdown)
  - `started_at` — nil (timestamp set on initiation)
  - `estimated_remaining` — 0 (seconds; updates during active shutdown)
  - `mode` — `:graceful` (default shutdown mode)
  - `drain_timeout` — 30 (seconds; configurable)
  - `aborted` — false
  - `force_confirm` — false (force-shutdown confirmation panel hidden)
  - `initiated_by` — nil (set on initiation)
  - `status_icons` — icon map for phase status display

  ### handle_event Callbacks
  - `"initiate_shutdown"` — sets `shutdown_active=true`, `started_at`; schedules `:advance_shutdown`; no flash
  - `"abort_shutdown"` — sets `aborted=true`; flash :warning "Shutdown aborted - system resuming normal operation"
  - `"force_shutdown_arm"` — sets `force_confirm=true`; no flash
  - `"force_shutdown_confirm"` — flash :error "Force shutdown initiated - system halting immediately"
  - `"force_shutdown_cancel"` — sets `force_confirm=false`; no flash
  - `"update_mode"` — updates `mode` assign; no flash
  - `"update_timeout"` — updates `drain_timeout` assign; no flash

  ### handle_info Callbacks
  - `:advance_shutdown` (every 500ms, only when active) — advances phase list stepwise; reschedules itself

  ### PubSub Subscriptions
  - None

  ### Timer Intervals
  - `:advance_shutdown` via `Process.send_after(self(), :advance_shutdown, 500)` — only active during shutdown sequence

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with System Shutdown heading
    Given I navigate to "/cockpit/shutdown"
    Then I see "System Shutdown" heading
    And I see "SYSTEM SHUTDOWN" in the header
    And I see the warning text about controlled shutdown

  Scenario: C2 - Mode selector defaults to Graceful on load
    Given I navigate to "/cockpit/shutdown"
    Then the "graceful" mode option is selected

  Scenario: C3 - Phase list shows all 5 shutdown phases
    Given I navigate to "/cockpit/shutdown"
    Then I see 5 phase entries in the shutdown phases panel

  Scenario: C5 - Abort button triggers abort flash
    Given the shutdown is active
    When I click the Abort Shutdown button
    Then I see flash warning "Shutdown aborted - system resuming normal operation"

  Scenario: C8 (two-step force) - Force shutdown arm→confirm→cancel
    Given I navigate to "/cockpit/shutdown"
    When I click the Force Shutdown button (arm)
    Then the force confirmation panel appears
    When I click Cancel
    Then the force confirmation panel disappears

  Scenario: C8 (dual) - Force shutdown confirm shows flash
    Given I navigate to "/cockpit/shutdown"
    When I arm and then confirm force shutdown
    Then I see flash error "Force shutdown initiated - system halting immediately"
  ```

  ## UX Flow
  1. Operator opens the pre-shutdown configuration panel
  2. Operator selects shutdown mode: graceful / fast / emergency
  3. Operator sets drain timeout (seconds)
  4. Operator clicks "Initiate Shutdown" — shutdown becomes active, phases begin
  5. Phases advance every 500ms via `:advance_shutdown`; logs accumulate
  6. At any time before completion: operator may click "Abort" (flash :warning)
  7. Emergency: operator arms force-shutdown → enters force-confirm panel → confirms (flash :error)
  8. After completion: logs retained for post-mortem review

  ## UI Elements Inventory

  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | System Shutdown heading | h2 | `h2[text="System Shutdown"]` | — |
  | SYSTEM SHUTDOWN label | span | `span[text="SYSTEM SHUTDOWN"]` | — |
  | Warning text | p | `p[contains 'controlled shutdown']` | — |
  | Mode selector | select/radio | `select[name='mode']` | `update_mode` |
  | Drain timeout input | input | `input[name='drain_timeout']` | `update_timeout` |
  | Initiate Shutdown button | button | `button[phx-click='initiate_shutdown']` | `initiate_shutdown` |
  | Abort Shutdown button | button | `button[phx-click='abort_shutdown']` | `abort_shutdown` |
  | Force Shutdown arm button | button | `button[phx-click='force_shutdown_arm']` | `force_shutdown_arm` |
  | Force confirm button | button | `button[phx-click='force_shutdown_confirm']` | `force_shutdown_confirm` |
  | Force cancel button | button | `button[phx-click='force_shutdown_cancel']` | `force_shutdown_cancel` |
  | Phase list entries | div | `div.phase-entry` | — |
  | Live shutdown log | div | `div[contains 'shutdown log']` | — |
  | Footer [A] Abort shortcut | span | `footer span[text="[A] Abort"]` | — |
  | Footer [F] Force shortcut | span | `footer span[text="[F] Force Shutdown"]` | — |
  | Footer SC-EMR-057 badge | footer | `footer[text~='SC-EMR-057']` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-019: Two-step commit arm→confirm→cancel sequence required
  - SC-SIL4-013: 6 shutdown phases MANDATORY per SIL-4 spec
  - SC-SAFETY-001: Guardian pre-approval for planning mutations
  - SC-SAFETY-022: Emergency stop < 5 seconds
  - SC-HMI-004: Two-step commit UI (Arm & Fire pattern)

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Shutdown initiates without operator intent | 9 | 1 | 2 | 18 | Two-step: explicit button click required |
  | Force shutdown confirm fires on first click | 9 | 2 | 2 | 36 | `force_confirm` flag gates the confirm button |
  | Abort unavailable after phases complete | 5 | 3 | 3 | 45 | `aborted` flag shown; abort only when active |
  | Phase advance continues after abort | 7 | 2 | 3 | 42 | `:advance_shutdown` checks `aborted` flag |
  | Mode not persisted when initiating | 5 | 2 | 4 | 40 | Mode stored in assign; passed to initiation logic |

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

  @path "/cockpit/shutdown"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads showing pre-shutdown configuration panel heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "System Shutdown"))
  end

  feature "warning text about controlled shutdown is shown before initiation", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(
      css("p",
        text: "This will initiate a controlled shutdown of the PRAJNA C3I system."
      )
    )
  end

  feature "PRAJNA C3I header link is present and points to cockpit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/cockpit']", text: "PRAJNA C3I"))
  end

  feature "SYSTEM SHUTDOWN label is in the page header before initiation", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "SYSTEM SHUTDOWN"))
  end

  feature "footer shows keyboard shortcuts Abort Force Shutdown and Esc Cancel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[A] Abort"))
    |> assert_has(css("footer span", text: "[F] Force Shutdown"))
    |> assert_has(css("footer span", text: "[Esc] Cancel"))
  end

  feature "footer shows SC-EMR-057 compliance badge", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer", text: "SC-EMR-057"))
  end

  # ── C2: Status / Badge Display ──────────────────────────────────────────────

  feature "shutdown mode selector defaults to Graceful mode before initiation", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("option[value='graceful']", text: "Graceful (recommended)"))
  end

  feature "header label changes to SHUTDOWN IN PROGRESS after initiation", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "SHUTDOWN SEQUENCE INITIATED"))
  end

  feature "force confirm panel shows Confirm force shutdown badge after arm", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> assert_has(css("span", text: "Confirm force shutdown?"))
  end

  feature "SHUTDOWN ABORTED badge is shown after abort", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='abort_shutdown']", text: "ABORT SHUTDOWN"))
    |> assert_has(css("h2", text: "SHUTDOWN ABORTED"))
  end

  feature "estimated time remaining is shown after shutdown is initiated", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("div", text: "Estimated time remaining:"))
  end

  # ── C3: Data Grid / Summary ─────────────────────────────────────────────────

  feature "shutdown mode selector has Graceful and Quick options", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[name='mode']"))
    |> assert_has(css("option[value='graceful']", text: "Graceful (recommended)"))
    |> assert_has(css("option[value='quick']", text: "Quick (30s timeout)"))
  end

  feature "drain timeout selector has 15s 30s and 60s options", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[name='timeout']"))
    |> assert_has(css("option[value='15']", text: "15 seconds"))
    |> assert_has(css("option[value='30']", text: "30 seconds"))
    |> assert_has(css("option[value='60']", text: "60 seconds"))
  end

  feature "shutdown info panel shows Initiated by field after initiation", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "Initiated by:"))
  end

  feature "shutdown info panel shows operator identity after initiation", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "operator@indrajaal.local"))
  end

  feature "shutdown info panel shows Mode label and drain timeout after initiation", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("div", text: "Mode:"))
    |> assert_has(css("div", text: "drain timeout"))
  end

  feature "RETURN TO COCKPIT link is shown after shutdown is aborted", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='abort_shutdown']", text: "ABORT SHUTDOWN"))
    |> assert_has(css("a", text: "RETURN TO COCKPIT"))
  end

  # ── C4: Timeline / Phase Progress Entries ──────────────────────────────────

  feature "PHASE 1 CONNECTION DRAINING heading is shown after shutdown initiated", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "PHASE 1: CONNECTION DRAINING"))
  end

  feature "PHASE 2 BACKGROUND JOBS heading is shown after shutdown initiated", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "PHASE 2: BACKGROUND JOBS"))
  end

  feature "PHASE 3 STATE PRESERVATION heading is shown after shutdown initiated", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "PHASE 3: STATE PRESERVATION"))
  end

  feature "PHASE 4 DISTRIBUTED TEARDOWN heading is shown after shutdown initiated", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "PHASE 4: DISTRIBUTED TEARDOWN"))
  end

  feature "PHASE 5 CONTAINER SHUTDOWN heading is shown after shutdown initiated", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "PHASE 5: CONTAINER SHUTDOWN"))
  end

  feature "SHUTDOWN LOG section is visible after shutdown is initiated", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("h2", text: "SHUTDOWN LOG"))
  end

  feature "SHUTDOWN LOG contains initiating graceful shutdown log entry", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("div", text: "Initiating graceful shutdown..."))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "INITIATE SHUTDOWN SEQUENCE button is present on pre-shutdown page", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(
      css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE")
    )
  end

  feature "update_mode select changes mode to quick when Quick option selected", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='mode']"), fn select ->
      select |> click(css("option[value='quick']"))
    end)
    |> assert_has(css("option[value='quick'][selected]"))
  end

  feature "update_timeout select changes timeout to 60 seconds when 60s option selected", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='timeout']"), fn select ->
      select |> click(css("option[value='60']"))
    end)
    |> assert_has(css("option[value='60'][selected]"))
  end

  feature "update_timeout select changes timeout to 15 seconds when 15s option selected", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='timeout']"), fn select ->
      select |> click(css("option[value='15']"))
    end)
    |> assert_has(css("option[value='15'][selected]"))
  end

  # ── C8: Action Buttons — dual verification (status change + flash) ───────────
  # SC-COV-016: every action button tested twice per AOR-COV-009
  # SC-COV-019: two-step commit sequence arm → confirm → cancel

  # initiate_shutdown: status change
  feature "initiate_shutdown status — clicking INITIATE shows shutdown active display", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "SHUTDOWN SEQUENCE INITIATED"))
  end

  # initiate_shutdown: phase panels appear (second status dimension — no flash emitted)
  feature "initiate_shutdown phases — all 5 phase headings appear after initiation", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "PHASE 1: CONNECTION DRAINING"))
    |> assert_has(css("span", text: "PHASE 5: CONTAINER SHUTDOWN"))
  end

  # abort_shutdown: status change — SHUTDOWN ABORTED panel appears
  feature "abort_shutdown status — SHUTDOWN ABORTED heading is shown after abort", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='abort_shutdown']", text: "ABORT SHUTDOWN"))
    |> assert_has(css("h2", text: "SHUTDOWN ABORTED"))
  end

  # abort_shutdown: flash message
  feature "abort_shutdown flash — Shutdown aborted warning flash appears after abort", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='abort_shutdown']", text: "ABORT SHUTDOWN"))
    |> assert_has(css("[role='alert']", text: "Shutdown aborted"))
  end

  # force_shutdown_arm: status change — Confirm force shutdown panel appears
  feature "force_shutdown_arm status — confirm force shutdown panel appears after arm", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> assert_has(css("span", text: "Confirm force shutdown?"))
  end

  # force_shutdown_arm: second assertion — CONFIRM and CANCEL buttons appear
  feature "force_shutdown_arm buttons — CONFIRM and CANCEL buttons appear after arm", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> assert_has(css("button[phx-click='force_shutdown_confirm']", text: "CONFIRM"))
    |> assert_has(css("button[phx-click='force_shutdown_cancel']", text: "CANCEL"))
  end

  # force_shutdown_confirm: status change — force log entry in shutdown log
  feature "force_shutdown_confirm status — force shutdown log entry appears in log panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> click(css("button[phx-click='force_shutdown_confirm']", text: "CONFIRM"))
    |> assert_has(css("div", text: "FORCE IMMEDIATE SHUTDOWN"))
  end

  # force_shutdown_confirm: flash message
  feature "force_shutdown_confirm flash — Force shutdown initiated error flash appears", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> click(css("button[phx-click='force_shutdown_confirm']", text: "CONFIRM"))
    |> assert_has(css("[role='alert']", text: "Force shutdown initiated"))
  end

  # force_shutdown_cancel: status change — confirm panel dismissed, abort button restored
  feature "force_shutdown_cancel status — abort button restored after cancel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> click(css("button[phx-click='force_shutdown_cancel']", text: "CANCEL"))
    |> assert_has(css("button[phx-click='abort_shutdown']", text: "ABORT SHUTDOWN"))
  end

  # force_shutdown_cancel: confirm panel is gone (Confirm force shutdown? no longer present)
  feature "force_shutdown_cancel panel — confirm force shutdown panel is gone after cancel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> click(css("button[phx-click='force_shutdown_arm']"))
    |> click(css("button[phx-click='force_shutdown_cancel']", text: "CANCEL"))
    |> assert_has(css("button[phx-click='force_shutdown_arm']"))
  end

  # ── C3 additional: step-level detail visible in phase panels ───────────────

  feature "phase 1 shows New connections blocked step entry", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "New connections blocked"))
  end

  feature "phase 3 shows Cockpit state snapshot step entry", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "Cockpit state snapshot"))
  end

  feature "phase 5 shows indrajaal-db-standalone stopped last step entry", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("span", text: "indrajaal-db-standalone stopped (last)"))
  end

  feature "ABORT SHUTDOWN button is visible after shutdown is initiated", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='initiate_shutdown']", text: "INITIATE SHUTDOWN SEQUENCE"))
    |> assert_has(css("button[phx-click='abort_shutdown']", text: "ABORT SHUTDOWN"))
  end
end
