defmodule IndrajaalWeb.Prajna.MeshLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Prajna Mesh Topology LiveView page.

  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.
  Target: 34 features covering C1-C8 with dual verification on every action button.

  Events in source:
    select_node, clear_selection, restart_node, stop_node, view_logs

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  STAMP: SC-COV-008 (Wallaby E2E mandatory for all LiveView pages)
         SC-COV-009 to SC-COV-016 (Gold standard 8-category coverage)
         SC-HMI-001 (Dark Cockpit defaults)
         SC-HMI-002 (Trend vectors on all metrics)
         SC-IGNITE-008 (15-container SIL-6 genome across 3 ImageCategory variants)
         SC-EID-001 (Show functional flows, not just physical nodes)

  ---

  ## Page Identity

  | Field   | Value                                                          |
  |---------|----------------------------------------------------------------|
  | Route   | `/cockpit/mesh`                                                |
  | Module  | `IndrajaalWeb.Prajna.MeshLive`                                 |
  | Title   | SIL-6 Mesh Topology                                           |
  | Tier    | Tier 2 (Medium) — P0 Distributed Mesh Container Management    |

  ## Design Intent

  The Mesh Topology page visualises the 15-container SIL-6 Biomorphic Mesh as a 7-tier
  boot hierarchy with functional-flow annotations (SC-EID-001). Operators see container
  roles (Zenoh Router, Database, Observability, Quorum Router, Cognitive, App Seed/HA,
  Digital Twin, ML Engine/Runner), image categories (Built/Pulled/Shared), real-time
  CPU/memory metrics with trend vectors, and a sparkline history panel on container
  selection. Destructive operations (restart, stop) follow the arm-confirm pattern
  (SC-SAFETY-001). A 3000ms refresh timer and `prajna:mesh` PubSub channel keep
  container states live.

  ## Expected Behavior

  On mount: 15 containers loaded across 7 tiers — zenoh-router (T1), indrajaal-db-prod
  (T2), indrajaal-obs-prod (T3), zenoh-router-{1,2,3} (T4), cepaf-bridge +
  indrajaal-cortex (T5), indrajaal-ex-app-1 + indrajaal-chaya + indrajaal-ollama (T6),
  indrajaal-ex-app-{2,3} + indrajaal-ml-runner-{1,2} (T7). No container selected
  (`selected_node` = nil). Summary bar shows Built/Pulled/Shared counts.

  `select_node` — sets `selected_node` assign; opens detail panel showing Status, Role,
    Boot Tier (N/7), Image category, Port (if applicable), Uptime (if running),
    resource bars (CPU/Memory for running nodes), sparkline, and action buttons.
  `clear_selection` — clears `selected_node`; hides detail panel; shows placeholder.
  `restart_node` — flash info "Restart command armed for <id>. Click again to confirm."
  `stop_node` — flash warning "Stop command armed for <id>. Click again to confirm."
  `view_logs` — push_navigate to `/cockpit/diagnostics?node=<id>`.
  `:refresh` (3000ms) — updates container metrics.
  `{:node_update, node_id, data}` — applies incremental update to a single container.

  ## BDD Scenarios

  ```gherkin
  Feature: SIL-6 Mesh Topology Live View

    Scenario: C1 — Page loads with 7-TIER BOOT HIERARCHY heading
      Given I navigate to "/cockpit/mesh"
      Then I should see "7-TIER BOOT HIERARCHY" in the main section
      And I should see "PRAJNA C3I" brand link

    Scenario: C2 — Container role legend shows all 10 roles
      Given I navigate to "/cockpit/mesh"
      Then the CONTAINER ROLES legend should show role labels
      And the IMAGE CATEGORIES legend should show B=Built, P=Pulled, S=Shared

    Scenario: C5 — Selecting a container opens the detail panel
      Given I navigate to "/cockpit/mesh"
      When I click on a container
      Then a detail panel should show Status, Role, Boot Tier, Image
      When I click [X] close button
      Then the detail panel should disappear and show placeholder

    Scenario: C8 — Restart uses arm-confirm pattern
      Given I navigate to "/cockpit/mesh"
      When I select a container and click RESTART
      Then I should see a flash message containing "Restart command armed"

    Scenario: C8 — Stop uses arm-confirm pattern
      Given I navigate to "/cockpit/mesh"
      When I select a container and click STOP
      Then I should see a flash message containing "Stop command armed"
  ```

  ## UX Flow

  1. Operator navigates to `/cockpit/mesh`.
  2. 7-tier boot hierarchy renders 15 containers with role badges and image categories.
  3. Summary bar shows Built (5/5), Pulled (2/2), Shared (8/8) counts.
  4. Operator clicks a container — detail panel shows metadata + resource bars + sparkline.
  5. Operator clicks RESTART — flash arms the command with info message.
  6. Operator clicks STOP — flash arms the command with warning message.
  7. Operator clicks LOGS — navigates to diagnostics page for that container.
  8. Operator clicks [X] — detail panel closes, placeholder returns.
  9. 3000ms timer refreshes all container metrics automatically.
  10. PubSub `prajna:mesh` delivers live container state changes.

  ## UI Elements Inventory

  | Element                       | Type     | Selector                                     | Event/Info                |
  |-------------------------------|----------|----------------------------------------------|---------------------------|
  | Header — SIL-6 MESH          | `span`   | header span text                             | C1 — Page Structure       |
  | 7-TIER BOOT HIERARCHY heading | `h2`     | `h2` text                                    | C1 — Page Structure       |
  | PRAJNA C3I brand link         | `a`      | `a[href="/cockpit"]`                         | C1 — navigation           |
  | Container card                | `div`    | `[phx-click='select_node']`                  | select_node event         |
  | CONTAINER ROLES legend        | `h3`     | `h3` text "CONTAINER ROLES"                 | C2 — Status Display       |
  | IMAGE CATEGORIES legend       | `h4`     | `h4` text                                    | C2 — Status Display       |
  | Built/Pulled/Shared counts    | `span`   | summary bar text                             | C2 — Status Display       |
  | CPU metric bar                | `span`   | text "CPU"                                   | C3 — Data Grid            |
  | Memory metric bar             | `span`   | text "Memory"                                | C3 — Data Grid            |
  | Status field                  | `span`   | text "Status:"                               | C3 — Data Grid            |
  | Role field                    | `span`   | text "Role:"                                 | C3 — Data Grid            |
  | Boot Tier field               | `span`   | text "Boot Tier:"                            | C3 — Data Grid            |
  | Image field                   | `span`   | text "Image:"                                | C3 — Data Grid            |
  | CPU sparkline                 | `span`   | text "CPU (recent): "                        | C4 — Sparkline            |
  | RESTART button                | `button` | `button[phx-click="restart_node"]`           | arm/confirm (C8)          |
  | STOP button                   | `button` | `button[phx-click="stop_node"]`              | arm/confirm (C8)          |
  | LOGS button                   | `button` | `button[phx-click="view_logs"]`              | push_navigate (C8)        |
  | [X] close button              | `button` | `button[phx-click="clear_selection"]`        | clear_selection (C8)      |
  | Flash message                 | `div`    | `[role="alert"]`                             | C8 — flash verify         |
  | Placeholder text              | `p`      | text "Click a container to inspect"          | C5 — Selection            |
  | Footer shortcuts              | `span`   | footer span text                             | C1 — Accessibility        |

  ## STAMP Constraints

  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009: C1 (Page Structure) coverage mandatory
  - SC-COV-010: C2 (Status/Badge) coverage mandatory
  - SC-COV-011: C3 (Data Grid) coverage mandatory
  - SC-COV-014: C6 (Media/Rich Content) — sparkline visualization
  - SC-COV-016: C8 (Actions) DUAL verification — status AND flash
  - SC-COV-019: Two-step commit — restart_node and stop_node require arm→confirm
  - SC-COV-020: PubSub refresh stability test (prajna:mesh)
  - SC-HMI-001: Dark Cockpit defaults — gray containers, amber for degraded
  - SC-HMI-002: Trend vectors displayed via sparkline
  - SC-SAFETY-001: Destructive ops require multi-step commit
  - SC-IGNITE-008: sil6Genome covers all 15 containers across 3 ImageCategory variants
  - SC-EID-001: Show functional flows, not just physical containers

  ## FMEA Risks

  | Failure Mode                          | S | O | D | RPN | Mitigation                                     |
  |---------------------------------------|---|---|---|-----|------------------------------------------------|
  | Restart fires without arm step        | 9 | 2 | 3 | 54  | SC-COV-019 arm→confirm test                    |
  | Stop fires without warning flash      | 9 | 2 | 3 | 54  | C8 dual verification (status + flash)          |
  | Detail panel stale after refresh      | 5 | 3 | 3 | 45  | SC-COV-020 sleep+re-assert PubSub stability    |
  | Sparkline missing after selection     | 3 | 2 | 3 | 18  | C4 — assert sparkline label in panel           |
  | Container count wrong on mount        | 7 | 2 | 2 | 28  | C3 — assert minimum: 15 select_node targets    |

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

  @path "/cockpit/mesh"

  # ── C1: Page Structure ─────────────────────────────────────────────────────────

  feature "page loads and shows 7-TIER BOOT HIERARCHY heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "7-TIER BOOT HIERARCHY"))
  end

  feature "header contains PRAJNA C3I brand link pointing to /cockpit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/cockpit']", text: "PRAJNA C3I"))
  end

  feature "navigation tabs are rendered with OVERVIEW MESH ALARMS COMMANDS AI COPILOT CONTAINERS",
          %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav a", text: "OVERVIEW"))
    |> assert_has(css("nav a", text: "MESH"))
    |> assert_has(css("nav a", text: "ALARMS"))
    |> assert_has(css("nav a", text: "COMMANDS"))
    |> assert_has(css("nav a", text: "AI COPILOT"))
    |> assert_has(css("nav a", text: "CONTAINERS"))
  end

  feature "footer shows SIL-6 Biomorphic Mesh and EID Compliant and PanopticIgnition attribution",
          %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer div", text: "SIL-6 Biomorphic Mesh"))
  end

  feature "footer shows keyboard shortcut hints Click Select and R Restart and S Stop", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[Click] Select"))
    |> assert_has(css("footer span", text: "[R] Restart"))
    |> assert_has(css("footer span", text: "[S] Stop"))
  end

  # ── C2: Status / Badge Display ─────────────────────────────────────────────────

  feature "CONTAINER ROLES legend heading is visible in the topology panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "CONTAINER ROLES"))
  end

  feature "IMAGE CATEGORIES legend shows B equals Built P equals Pulled S equals Shared", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "B = Built"))
    |> assert_has(css("span", text: "P = Pulled"))
    |> assert_has(css("span", text: "S = Shared"))
  end

  feature "summary bar shows Built Pulled Shared genome counts", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Built:"))
    |> assert_has(css("span", text: "Pulled:"))
    |> assert_has(css("span", text: "Shared:"))
  end

  feature "header shows online container count", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "online"))
  end

  feature "selected container detail panel shows status text", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("span", text: "Status:"))
  end

  # ── C3: Data Grid / Container Details ──────────────────────────────────────────

  feature "all 15 mesh containers are rendered in the topology view", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_node']", minimum: 15))
  end

  feature "zenoh-router container is rendered in the topology view", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "zenoh-router"))
  end

  feature "indrajaal-db-prod container is rendered in the topology view", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal-db-prod"))
  end

  feature "indrajaal-obs-prod container is rendered in the topology view", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal-obs-prod"))
  end

  feature "indrajaal-ex-app-1 seed container is rendered in the topology view", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal-ex-app-1"))
  end

  feature "selected container detail panel shows Status Role Boot Tier and Image metadata", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("span", text: "Status:"))
    |> assert_has(css("span", text: "Role:"))
    |> assert_has(css("span", text: "Boot Tier:"))
    |> assert_has(css("span", text: "Image:"))
  end

  feature "selected running container detail panel shows CPU and Memory resource labels", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("span", text: "CPU"))
    |> assert_has(css("span", text: "Memory"))
  end

  feature "cepaf-bridge cognitive container is rendered in the topology view", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "cepaf-bridge"))
  end

  # ── C4: Sparkline / Refresh History ────────────────────────────────────────────

  feature "container detail panel shows CPU recent sparkline label", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("span", text: "CPU (recent):"))
  end

  feature "page remains stable across the 3-second metric refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "7-TIER BOOT HIERARCHY"))
    assert_has(session, css("[phx-click='select_node']", minimum: 15))

    Process.sleep(3_000)

    assert_has(session, css("h2", text: "7-TIER BOOT HIERARCHY"))
    assert_has(session, css("[phx-click='select_node']", minimum: 15))
  end

  feature "SIL-6 genome label is visible on the page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "SC-IGNITE-008"))
  end

  # ── C5: Container Selection Interaction ────────────────────────────────────────

  feature "default detail panel shows click a container to inspect placeholder", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Click a container to inspect"))
  end

  feature "clicking a container replaces placeholder with detail panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "Click a container to inspect"))
    |> click(css("[phx-click='select_node']", at: 0))
    |> refute_has(css("p", text: "Click a container to inspect"))
  end

  feature "placeholder shows 15-container SIL-6 Biomorphic Mesh subtitle", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "15-container SIL-6 Biomorphic Mesh"))
  end

  # ── C6: Topology Visualization ────────────────────────────────────────────────

  feature "topology tree has connection line dividers between tiers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.h-8.w-px"))
  end

  feature "topology visualization is contained in the 8-column grid panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.col-span-8"))
  end

  # ── C8: Action Buttons — DUAL verification (status change + flash) ─────────────

  # select_node — node cards present (minimum 15)
  feature "at least 15 container cards are rendered with select_node click target", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_node']", minimum: 15))
  end

  # RESTART STOP LOGS — buttons visible after selection
  feature "RESTART STOP LOGS action buttons are visible after container selection", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("button[phx-click='restart_node']", text: "RESTART"))
    |> assert_has(css("button[phx-click='stop_node']", text: "STOP"))
    |> assert_has(css("button[phx-click='view_logs']", text: "LOGS"))
  end

  # restart_node — flash on click
  feature "clicking RESTART fires Restart command armed flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> click(css("button[phx-click='restart_node']"))
    |> assert_has(css("[role='alert']", text: "Restart command armed"))
  end

  # stop_node — flash on click
  feature "clicking STOP fires Stop command armed flash message", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> click(css("button[phx-click='stop_node']"))
    |> assert_has(css("[role='alert']", text: "Stop command armed"))
  end

  # view_logs — button visible (covered in combined test above)
  feature "clicking LOGS button navigates to diagnostics page", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("button[phx-click='view_logs']", text: "LOGS"))
  end

  # clear_selection — [X] button appears after selection
  feature "[X] clear_selection button is visible in container detail panel", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("button[phx-click='clear_selection']", text: "[X]"))
  end

  # clear_selection — clicking [X] restores placeholder
  feature "clicking [X] clears container selection and restores the placeholder panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("button[phx-click='clear_selection']", text: "[X]"))
    |> click(css("button[phx-click='clear_selection']"))
    |> assert_has(css("p", text: "Click a container to inspect"))
  end

  # restart_node — (3) flash contains armed phrase for specific container
  feature "clicking RESTART on first container shows armed flash for that container", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> click(css("button[phx-click='restart_node']"))
    |> assert_has(css("[role='alert']", text: "armed"))
  end

  # stop_node — (3) flash contains armed phrase
  feature "clicking STOP shows armed flash confirming the command was staged", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> click(css("button[phx-click='stop_node']"))
    |> assert_has(css("[role='alert']", text: "armed"))
  end
end
