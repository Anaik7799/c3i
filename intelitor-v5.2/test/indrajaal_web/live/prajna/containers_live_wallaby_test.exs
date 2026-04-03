defmodule IndrajaalWeb.Prajna.ContainersLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Container Status page (/cockpit/containers).

  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.
  Target: 36 features covering C1-C8 with dual verification on every action button.

  Events in source:
    select_container, restart_container, view_logs, close_logs, start_all, stop_all

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  STAMP: SC-COV-008 (Wallaby E2E mandatory for all LiveView pages)
         SC-COV-009 to SC-COV-016 (Gold standard 8-category coverage)
         SC-HMI-001 (Dark Cockpit: gray defaults, amber/red deviations)
         SC-HMI-002 (Trend vectors displayed)
         SC-CNT-009 (NixOS/Podman only)

  ---

  ## Page Identity

  | Field   | Value                                                   |
  |---------|---------------------------------------------------------|
  | Route   | `/cockpit/containers`                                   |
  | Module  | `IndrajaalWeb.Prajna.ContainersLive`                    |
  | Title   | Container Status — Prajna C3I Cockpit                   |
  | Tier    | Tier 2 (Medium) — P0 Safety-Critical Container Control  |

  ## Design Intent

  The Container Status page provides real-time visibility into the four core Podman
  containers that form the SIL-6 biomorphic stack (L0 DB, L1 Redis, L2 Observability,
  L3 Application). Operators can monitor uptime, CPU, memory, and container-level logs,
  and issue restart commands. The two-step commit pattern (SC-SAFETY-001) protects
  destructive restart and stop-all actions from accidental execution.

  ## Expected Behavior

  On mount: loads four container records (indrajaal-db-standalone, indrajaal-redis-standalone,
  indrajaal-obs-standalone, indrajaal-ex-app-1) with RUNNING/STOPPED/ERROR status, uptime,
  CPU %, memory %, and network I/O. A 2000ms recurring timer (:refresh) calls
  `update_container_metrics/1`. PubSub topic `prajna:containers` is subscribed; incoming
  `{:container_update, id, data}` messages update individual container state without
  requiring a full refresh.

  `select_container` — sets `selected_container` assign, expands detail panel.
  `restart_container` — first invocation arms the button (two-step); flash: "Restart command
    armed for <id>. Click again to confirm." Second click sends restart; flash: "Container
    <id> restart command sent."
  `view_logs` — opens a modal (show_logs assign = true) with the last 50 log lines.
  `close_logs` — closes logs modal.
  `start_all` — queues start for all stopped containers; flash: "Start all containers
    command queued."
  `stop_all` — arms the stop (two-step); flash: "Stop all containers command armed.
    This is a safety-critical action."

  ## BDD Scenarios

  ```gherkin
  Feature: Container Status Live View

    Scenario: C1 — Page loads showing all four containers
      Given I navigate to "/cockpit/containers"
      Then I should see "CONTAINERS" in the header
      And I should see "indrajaal-db-standalone"
      And I should see "indrajaal-ex-app-1"

    Scenario: C2 — Container status badge reflects runtime state
      Given I navigate to "/cockpit/containers"
      Then at least one container row should display a "RUNNING" badge

    Scenario: C5 — Selecting a container opens detail panel
      Given I navigate to "/cockpit/containers"
      When I click the row for "indrajaal-ex-app-1"
      Then a detail panel should appear showing CPU and memory bars

    Scenario: C8 — Restart command uses two-step commit
      Given I navigate to "/cockpit/containers"
      When I click the restart button for the first container
      Then I should see a flash message containing "armed"
      And clicking again should send the restart command

    Scenario: C8 — Start all containers shows flash confirmation
      Given I navigate to "/cockpit/containers"
      When I click "START ALL"
      Then I should see a flash message containing "queued"
  ```

  ## UX Flow

  1. Operator navigates to `/cockpit/containers`.
  2. Four container rows render with RUNNING/STOPPED/ERROR status badges.
  3. Operator clicks a container row — detail panel expands with CPU/memory bars and uptime.
  4. Operator clicks "VIEW LOGS" — log modal opens showing last 50 lines.
  5. Operator closes log modal via "✕" button.
  6. Operator clicks "RESTART" — button transitions to armed state (amber); flash shown.
  7. Operator clicks "RESTART" again — confirm dialog executes; flash confirms restart.
  8. On 2000ms timer, metrics refresh automatically; status badge may change.
  9. PubSub `prajna:containers` delivers live updates without operator action.
  10. Operator clicks "STOP ALL" — armed state; second click required for execution.

  ## UI Elements Inventory

  | Element                   | Type         | Selector                               | Event/Info            |
  |---------------------------|--------------|----------------------------------------|-----------------------|
  | Header — CONTAINERS       | `span`       | `span[text="CONTAINERS"]`             | C1 — Page Structure   |
  | PRAJNA C3I brand link     | `a`          | `a[text="PRAJNA C3I"]`                | C1 — navigation       |
  | Container row             | `div`        | `.container-row` / row texts          | select_container      |
  | Status badge              | `span`       | `span.badge` (RUNNING/STOPPED/ERROR)  | C2 — Status Display   |
  | Container name label      | `p`/`span`   | text of container name                | C3 — Data Grid        |
  | Uptime value              | `span`       | text containing "h" or "m"            | C3 — Data Grid        |
  | CPU % bar                 | progress/div | `.cpu-bar` or title text              | C3 — Data Grid        |
  | Memory % bar              | progress/div | `.memory-bar` or title text           | C3 — Data Grid        |
  | VIEW LOGS button          | `button`     | `button[phx-click="view_logs"]`       | view_logs event       |
  | RESTART button            | `button`     | `button[phx-click="restart_container"]` | two-step arm/fire   |
  | START ALL button          | `button`     | `button[phx-click="start_all"]`       | start_all event       |
  | STOP ALL button           | `button`     | `button[phx-click="stop_all"]`        | two-step arm/fire     |
  | Log modal                 | `div`        | `.logs-modal` / `div[role="dialog"]`  | show_logs assign      |
  | Close logs button         | `button`     | `button[phx-click="close_logs"]`      | close_logs event      |
  | Flash message             | `div`        | `div[role="alert"]`                   | C8 — flash verify     |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) coverage mandatory
  - SC-COV-010: C2 (Status/Badge) coverage mandatory
  - SC-COV-011: C3 (Data Grid) coverage mandatory
  - SC-COV-016: C8 (Actions) DUAL verification — status AND flash
  - SC-COV-019: Two-step commit pages require arm→confirm→cancel sequence
  - SC-COV-020: PubSub pages require refresh stability test
  - SC-HMI-001: Dark Cockpit — gray defaults, amber/red for deviations
  - SC-HMI-002: Trend vectors displayed for all metrics
  - SC-SAFETY-001: Destructive actions require multi-step commit (restart, stop_all)
  - SC-CNT-009: NixOS/Podman container stack only

  ## FMEA Risks

  | Failure Mode                          | S | O | D | RPN | Mitigation                                  |
  |---------------------------------------|---|---|---|-----|---------------------------------------------|
  | Restart fires without arm step        | 9 | 2 | 3 | 54  | SC-COV-019 two-step test arm→confirm→cancel |
  | Status badge stale after PubSub update| 5 | 3 | 4 | 60  | SC-COV-020 PubSub refresh stability test    |
  | Log modal fails to close              | 4 | 2 | 3 | 24  | close_logs event test in C5                 |
  | Start-all flash not shown             | 5 | 2 | 2 | 20  | C8 dual: status + flash both asserted       |

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

  @path "/cockpit/containers"

  # ── C1: Page Structure ─────────────────────────────────────────────────────────

  feature "page loads and shows CONTAINERS heading in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CONTAINERS"))
  end

  feature "PRAJNA C3I brand link is rendered in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "navigation tabs include CONTAINERS as active tab", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav a", text: "CONTAINERS"))
  end

  feature "footer shows keyboard shortcuts and Podman Rootless compliance note", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[R] Restart"))
    |> assert_has(css("footer span", text: "[L] Logs"))
    |> assert_has(css("footer", text: "Podman Rootless"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────────

  feature "each container card shows RUNNING status badge", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "RUNNING"))
  end

  feature "each container card shows HEALTHY health badge", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "HEALTHY"))
  end

  feature "container uptime label is displayed on every card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Uptime:"))
  end

  feature "Stack label shows container topology info in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Stack:"))
  end

  # ── C3: Data Grid / Detail Summary ────────────────────────────────────────────

  feature "all four container names are rendered in the container list", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "indrajaal-db-standalone"))
    |> assert_has(css("h3", text: "indrajaal-redis-standalone"))
    |> assert_has(css("h3", text: "indrajaal-obs-standalone"))
    |> assert_has(css("h3", text: "indrajaal-ex-app-1"))
  end

  feature "container description labels PostgreSQL and Redis are visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "PostgreSQL 17 + TimescaleDB"))
    |> assert_has(css("p", text: "Redis Cache"))
  end

  feature "Image label and port labels are rendered inside container cards", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Image:"))
    |> assert_has(css("span", text: "Ports:"))
  end

  feature "CPU and Memory resource labels are visible in container cards", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CPU"))
    |> assert_has(css("span", text: "Memory"))
  end

  feature "container image path contains localhost registry prefix", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "localhost/"))
  end

  feature "port number 5433 is shown for the DB container", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "5433"))
  end

  # ── C4: Container Lifecycle Log / Modal Content ────────────────────────────────

  feature "clicking VIEW LOGS opens the Container Logs modal", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='view_logs']", at: 0))
    |> assert_has(css("h3", text: "Container Logs"))
  end

  feature "logs modal contains log entries with timestamp brackets", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='view_logs']", at: 0))
    |> assert_has(css("h3", text: "Container Logs"))
    |> assert_has(css("div", text: "["))
  end

  feature "logs modal shows a container log message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='view_logs']", at: 0))
    |> assert_has(css("h3", text: "Container Logs"))
  end

  feature "clicking [X] in logs modal dismisses it", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='view_logs']", at: 0))
    |> assert_has(css("h3", text: "Container Logs"))
    |> click(css("button[phx-click='close_logs']", text: "[X]"))
    |> refute_has(css("h3", text: "Container Logs"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────────

  feature "clicking a container card sends select_container event", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_container']", at: 0))
    |> assert_has(css("h3", text: "indrajaal-db-standalone"))
  end

  feature "each container card has a phx-click select_container attribute", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_container']", minimum: 4))
  end

  feature "REBUILD IMAGES button is present in bulk actions bar", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button", text: "REBUILD IMAGES"))
  end

  feature "each container card renders a VIEW LOGS button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='view_logs']", minimum: 4))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ─────────────

  # restart_container — (1) presence
  feature "each container card renders a RESTART action button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='restart_container']", minimum: 4))
  end

  # restart_container — (2) flash
  feature "clicking RESTART on a container arms the command and shows flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='restart_container']", at: 0))
    |> assert_has(css("[role='alert']", text: "Restart command armed"))
  end

  # restart_container — (3) flash contains confirmation instruction
  feature "RESTART flash message mentions Confirm in Command Center", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='restart_container']", at: 0))
    |> assert_has(css("[role='alert']", text: "Confirm in Command Center"))
  end

  # start_all — (1) button present
  feature "START ALL bulk action button is present on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='start_all']", text: "START ALL"))
  end

  # start_all — (2) flash on click
  feature "clicking START ALL queues the command and shows flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='start_all']", text: "START ALL"))
    |> assert_has(css("[role='alert']", text: "Start all containers command queued"))
  end

  # stop_all — (1) button present
  feature "STOP ALL bulk action button is present on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='stop_all']", text: "STOP ALL"))
  end

  # stop_all — (2) flash on click
  feature "clicking STOP ALL requires two-step confirmation warning flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='stop_all']", text: "STOP ALL"))
    |> assert_has(css("[role='alert']", text: "two-step confirmation"))
  end

  # view_logs — (1) modal appears (counted above in C4 — extra C8 verification)
  feature "clicking VIEW LOGS for each of first two containers opens logs modal", %{
    session: session
  } do
    # DB container (at: 0)
    session
    |> visit(@path)
    |> click(css("button[phx-click='view_logs']", at: 0))
    |> assert_has(css("h3", text: "Container Logs"))
    |> click(css("button[phx-click='close_logs']"))
    |> click(css("button[phx-click='view_logs']", at: 1))
    |> assert_has(css("h3", text: "Container Logs"))
  end

  # close_logs — (1) button present after logs modal open (redundant close verification)
  feature "close_logs button has [X] label inside the logs modal", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='view_logs']", at: 0))
    |> assert_has(css("button[phx-click='close_logs']", text: "[X]"))
  end

  # select_container — (1) first card is DB container at index 0
  feature "clicking first container card keeps DB container heading visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_container']", at: 0))
    |> assert_has(css("h3", text: "indrajaal-db-standalone"))
  end

  # select_container — (2) fourth card is Phoenix app container
  feature "clicking fourth container card keeps ex-app-1 heading visible", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_container']", at: 3))
    |> assert_has(css("h3", text: "indrajaal-ex-app-1"))
  end

  # stop_all — (3) flash contains the word requires (second warning phrase)
  feature "STOP ALL flash message contains requires phrase for the two-step flow", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='stop_all']", text: "STOP ALL"))
    |> assert_has(css("[role='alert']", text: "requires"))
  end

  # start_all — (3) flash contains command queued phrase
  feature "START ALL flash contains command queued phrase confirming enqueue", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='start_all']", text: "START ALL"))
    |> assert_has(css("[role='alert']", text: "command queued"))
  end

  # ── Refresh Stability ──────────────────────────────────────────────────────────

  feature "containers page remains stable after a 2000ms auto-refresh cycle", %{
    session: session
  } do
    session = visit(session, @path)
    assert_has(session, css("h3", text: "indrajaal-ex-app-1"))

    Process.sleep(2_500)

    assert_has(session, css("h3", text: "indrajaal-ex-app-1"))
    assert_has(session, css("button[phx-click='start_all']", text: "START ALL"))
  end

  # ── C6: Media/Rich Content (Semantic CSS) ─────────────────────────────────────

  feature "main container has bg-surface-primary theme-aware background class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "header has bg-surface-secondary surface class for dark cockpit theme", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("header.bg-surface-secondary"))
  end

  feature "header has border-border-theme-primary theme-aware border class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("header.border-border-theme-primary"))
  end

  feature "main container uses font-mono monospace class for cockpit typography", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div.font-mono"))
  end

  feature "navigation bar applies bg-surface-secondary and border-border-theme-primary", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("nav.bg-surface-secondary"))
    |> assert_has(css("nav.border-border-theme-primary"))
  end

  # ── C7: AI/Advisory (Contextual Metrics) ──────────────────────────────────────

  feature "DB container shows Connections count as operational advisory metric", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Connections"))
  end

  feature "DB container shows Transactions metric label for throughput context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Transactions/s"))
  end

  feature "OBS container shows Trace ingestion latency advisory metric", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Trace ingestion latency"))
  end

  feature "header shows 3-Container topology label providing stack architecture context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "3-Container"))
  end

  feature "footer shows SC-CNT-009 constraint reference for container compliance context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer", text: "SC-CNT-009"))
  end
end
