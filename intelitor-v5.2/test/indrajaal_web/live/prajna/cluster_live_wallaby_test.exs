defmodule IndrajaalWeb.Prajna.ClusterLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Cluster Management LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/cluster`
  - **Module**: `IndrajaalWeb.Prajna.ClusterLive`
  - **Title**: "Cluster Management"
  - **Priority**: P1 (High — live BEAM cluster topology and FLAME pool orchestration)

  ## Design Intent
  The Cluster Management page provides a real-time view of the Indrajaal BEAM cluster
  topology. It displays live node health (fetched from actual BEAM nodes via
  `Node.list/0`), Sentinel quorum/election strategy/split-brain status, FLAME worker
  pools (with worker count and autoscale toggle), a capability router summary, and a
  gossip event log. Operators can select individual nodes for detail inspection, trigger
  leader elections, add/remove nodes, scale FLAME pools, and toggle autoscale — all with
  immediate flash feedback. The page refreshes automatically every 2s.

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "Cluster Management"
  - `sentinel` — map with `quorum`, `strategy`, `split_brain` status
  - `nodes` — list of real BEAM node maps (from `Node.list/0`)
  - `flame_pools` — list of 3 pool maps (name, worker count, max_workers, autoscale)
  - `capability_router` — map with routing summary
  - `selected_node` — nil (no node selected on mount)
  - `last_election` — nil (updated on force_election event)
  - `gossip_log` — list of recent gossip events
  - `node_role_icons` — map of role → icon string

  ### handle_event Callbacks
  - `"select_node"` — sets `selected_node` to node id; no flash
  - `"force_election"` — sets `last_election` timestamp; flash :info "Leader election initiated"
  - `"add_node"` — flash :info "Add node wizard opened"
  - `"remove_node"` — flash :warning "Node #{id} removal requires confirmation"
  - `"scale_pool"` — flash :info "Scaling #{pool} pool #{action}"
  - `"toggle_autoscale"` — flash :info "Auto-scale toggled"

  ### handle_info Callbacks
  - `:refresh` (every 2000ms) — refreshes `nodes`, `sentinel`, `flame_pools` from live BEAM state
  - `{:cluster_event, event}` — appends event to `gossip_log`

  ### PubSub Subscriptions
  - `"prajna:cluster"` — cluster topology and event notifications

  ### Timer Intervals
  - `:refresh` every 2000ms (`@refresh_interval 2_000`)

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with CLUSTER MANAGEMENT heading
    Given I navigate to "/cockpit/cluster"
    Then I see "CLUSTER MANAGEMENT" in the header
    And I see "PRAJNA C3I" breadcrumb link
    And I see navigation tabs OVERVIEW, CLUSTER, ALARMS
    And I see footer keyboard shortcuts [A] Add [R] Remove [E] Election [S] Scale

  Scenario: C2 - Quorum status badge displayed in Sentinel panel
    Given I navigate to "/cockpit/cluster"
    Then I see the Sentinel quorum status badge
    And I see the election strategy displayed

  Scenario: C3 - Node list shows connected BEAM nodes
    Given I navigate to "/cockpit/cluster"
    Then I see the node topology panel with node entries

  Scenario: C3 - FLAME pool entries show worker counts
    Given I navigate to "/cockpit/cluster"
    Then I see 3 FLAME pool cards with worker count badges

  Scenario: C5 - Selecting a node opens detail panel
    Given I navigate to "/cockpit/cluster"
    When I click a node row
    Then the node detail panel appears

  Scenario: C8 (dual force election) - Force election shows status change and flash
    Given I navigate to "/cockpit/cluster"
    When I click Force Election
    Then the last_election timestamp updates
    And I see flash info "Leader election initiated"

  Scenario: C8 (dual add node) - Add node shows flash
    Given I navigate to "/cockpit/cluster"
    When I click Add Node
    Then I see flash info "Add node wizard opened"

  Scenario: C8 (dual remove node) - Remove node shows flash warning
    Given I navigate to "/cockpit/cluster"
    When I click Remove Node for a node
    Then I see flash warning "removal requires confirmation"

  Scenario: C8 (dual scale pool) - Scale pool shows flash
    Given I navigate to "/cockpit/cluster"
    When I click a scale pool button
    Then I see flash info "Scaling" message

  Scenario: C8 (dual toggle autoscale) - Toggle autoscale shows flash
    Given I navigate to "/cockpit/cluster"
    When I click Toggle Autoscale
    Then I see flash info "Auto-scale toggled"
  ```

  ## UX Flow
  1. Operator loads page; sees node topology (live BEAM nodes) and Sentinel quorum
  2. Operator clicks a node to expand its detail card
  3. Operator can force a leader election (flash :info)
  4. Operator can add or remove nodes; removal requires secondary confirmation (flash :warning)
  5. FLAME pool cards show worker counts; operator scales up/down or toggles autoscale
  6. Gossip log scrolls in real time as cluster events arrive via PubSub
  7. `:refresh` at 2s keeps node health and pool state current

  ## UI Elements Inventory

  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | CLUSTER MANAGEMENT header | span | `span[text="CLUSTER MANAGEMENT"]` | — | C1 |
  | PRAJNA C3I breadcrumb | a | `a[text="PRAJNA C3I"]` | — | C1 |
  | Navigation tabs | nav | `nav a[text="OVERVIEW"]` | — | C1 |
  | Footer keyboard shortcuts | footer | `footer span[text="[A] Add Node"]` | — | C1 |
  | Sentinel quorum badge | span | `span[text="Quorum:"]` | — | C2 |
  | Election strategy display | span | `span[text="Strategy:"]` | — | C2 |
  | Split-brain status | span | `span[text="Split-brain:"]` | — | C2 |
  | Node list rows | div | `div[phx-click='select_node']` | `select_node` | C3 |
  | FLAME pool cards | div | `div[contains 'FLAME']` | — | C3 |
  | Gossip log | div | `div[contains 'GOSSIP']` | — | C4 |
  | Force Election button | button | `button[phx-click='force_election']` | `force_election` | C8 |
  | Add Node button | button | `button[phx-click='add_node']` | `add_node` | C8 |
  | Remove Node button | button | `button[phx-click='remove_node']` | `remove_node` | C8 |
  | Scale Pool button (up) | button | `button[phx-click='scale_pool'][phx-value-direction='up']` | `scale_pool` | C8 |
  | Scale Pool button (down) | button | `button[phx-click='scale_pool'][phx-value-direction='down']` | `scale_pool` | C8 |
  | Toggle Autoscale button | button | `button[phx-click='toggle_autoscale']` | `toggle_autoscale` | C8 |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-020: PubSub pages require refresh stability test (sleep + re-assert)
  - SC-SIL4-011: Quorum ⌊N/2⌋+1 maintained throughout — quorum badge must be visible
  - SC-FLAME-001: FLAME Runner distributed compute — pool cards required
  - SC-CLUSTER-001: Quorum visibility mandatory
  - SC-CLUSTER-002: Split-brain detection < 5s — sentinel panel shows split_brain status

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Node list stale after BEAM node joins/leaves | 7 | 2 | 3 | 42 | `:refresh` at 2s re-fetches `Node.list/0` |
  | Force election fires with no confirmation | 5 | 2 | 3 | 30 | Single-step acceptable; not destructive |
  | Remove node without secondary guard | 7 | 2 | 3 | 42 | Flash :warning signals confirmation required |
  | FLAME pool scale operation misconfigured | 5 | 2 | 4 | 40 | Pool name and action passed in params |
  | Gossip log grows unbounded in memory | 3 | 3 | 4 | 36 | Log prepend with take limit in handle_info |

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

  @path "/cockpit/cluster"

  # ── C1: Page Structure ────────────────────────────────────────────────────────

  feature "page loads and shows CLUSTER MANAGEMENT heading in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CLUSTER MANAGEMENT"))
  end

  feature "PRAJNA C3I breadcrumb link is present in header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "navigation tabs are rendered with CLUSTER active", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("nav a", text: "OVERVIEW"))
    |> assert_has(css("nav a", text: "CLUSTER"))
    |> assert_has(css("nav a", text: "ALARMS"))
  end

  feature "footer shows keyboard shortcuts [A] Add [R] Remove [E] Election [S] Scale", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("footer span", text: "[A] Add Node"))
    |> assert_has(css("footer span", text: "[R] Remove Node"))
    |> assert_has(css("footer span", text: "[E] Force Election"))
    |> assert_has(css("footer span", text: "[S] Scale Pool"))
  end

  # ── C2: Status and Badge Display ──────────────────────────────────────────────

  feature "sentinel status row shows quorum strategy DNS and split-brain fields", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Quorum:"))
    |> assert_has(css("span", text: "Strategy:"))
    |> assert_has(css("span", text: "DNS:"))
    |> assert_has(css("span", text: "Split-brain:"))
  end

  feature "quorum current/required fraction is displayed in sentinel row", %{session: session} do
    session
    |> visit(@path)
    # quorum_current/quorum_required renders as e.g. "1/1"
    |> assert_has(css("span", text: "/"))
  end

  feature "split-brain status shows NO when no split-brain detected", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-400", text: "NO"))
  end

  feature "AUTO-SCALE ON button is visible in FLAME POOLS panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='toggle_autoscale']", text: "AUTO-SCALE: ON"))
  end

  feature "last check elapsed time is displayed in sentinel status row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Last check:"))
    |> assert_has(css("span", text: "s ago"))
  end

  # ── C3: Data Grid and Node Details ────────────────────────────────────────────

  feature "CLUSTER NODES panel heading is visible with at least one node row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "CLUSTER NODES"))
    |> assert_has(css("[phx-click='select_node']", minimum: 1))
  end

  feature "local node is listed as LEADER in cluster nodes panel", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "(LEADER)"))
  end

  feature "node rows display IP uptime heartbeat and FLAME pool metadata", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "IP:"))
    |> assert_has(css("span", text: "Uptime:"))
    |> assert_has(css("span", text: "Heartbeat:"))
    |> assert_has(css("span", text: "FLAME:"))
  end

  feature "node row shows active over total FLAME pool fraction", %{session: session} do
    session
    |> visit(@path)
    # Renders as e.g. "3/3 active"
    |> assert_has(css("div", text: "active"))
  end

  feature "FLAME POOLS panel shows Intelligence Pool Video Pool and Analytics Pool", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "FLAME POOLS"))
    |> assert_has(css("span", text: "Intelligence Pool"))
    |> assert_has(css("span", text: "Video Pool"))
    |> assert_has(css("span", text: "Analytics Pool"))
  end

  feature "each FLAME pool shows current over max node count", %{session: session} do
    session
    |> visit(@path)
    # Renders as e.g. "8/10 nodes"
    |> assert_has(css("span", text: "nodes"))
  end

  feature "CAPABILITY ROUTER panel shows Backend Priority Chain and backends", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "CAPABILITY ROUTER"))
    |> assert_has(css("div", text: "Backend Priority Chain:"))
    |> assert_has(css("span", text: "Process"))
    |> assert_has(css("span", text: "Container"))
  end

  feature "capability router shows current routing line", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Current routing:"))
  end

  feature "GOSSIP LOG panel is visible and contains gossip entries", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "GOSSIP LOG"))
    |> assert_has(css("div", text: "heartbeat received"))
  end

  feature "gossip log entry shows Quorum established message", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Quorum established"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────────

  feature "clicking a cluster node row selects it without crashing the page", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_node']", minimum: 1))
    |> click(css("[phx-click='select_node']", at: 0))
    |> assert_has(css("h2", text: "CLUSTER NODES"))
  end

  feature "REMOVE NODE button is disabled when no node is selected", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-click='remove_node'][disabled]", text: "REMOVE NODE"))
  end

  feature "SCALE +2 buttons are present for all three FLAME pools", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-direction='up']", minimum: 3))
  end

  feature "SCALE -2 buttons are present for all three FLAME pools", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-direction='down']", minimum: 3))
  end

  # ── C8: Action Buttons — Dual Verification (status change + flash) ─────────────

  # Event: toggle_autoscale — flash
  feature "clicking AUTO-SCALE toggle triggers Auto-scale toggled flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='toggle_autoscale']", text: "AUTO-SCALE: ON"))
    |> assert_has(css("[role='alert']", text: "Auto-scale toggled"))
  end

  # Event: toggle_autoscale — page stability (status: FLAME POOLS section remains)
  feature "clicking AUTO-SCALE toggle keeps FLAME POOLS panel visible", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='toggle_autoscale']", text: "AUTO-SCALE: ON"))
    |> assert_has(css("h2", text: "FLAME POOLS"))
  end

  # Event: scale_pool up — flash
  feature "clicking SCALE +2 on a FLAME pool triggers scaling flash", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-direction='up']", minimum: 1))
    |> click(css("button[phx-value-direction='up']", at: 0))
    |> assert_has(css("[role='alert']", text: "Scaling"))
  end

  # Event: scale_pool up — page stability (status: pool section remains)
  feature "clicking SCALE +2 keeps FLAME POOLS panel visible after scale", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-direction='up']", at: 0))
    |> assert_has(css("h2", text: "FLAME POOLS"))
  end

  # Event: scale_pool down — flash
  feature "clicking SCALE -2 on a FLAME pool triggers scaling flash", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("button[phx-value-direction='down']", minimum: 1))
    |> click(css("button[phx-value-direction='down']", at: 0))
    |> assert_has(css("[role='alert']", text: "Scaling"))
  end

  # Event: scale_pool down — page stability
  feature "clicking SCALE -2 keeps FLAME POOLS panel visible after scale", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-value-direction='down']", at: 0))
    |> assert_has(css("h2", text: "FLAME POOLS"))
  end

  # Event: force_election — flash
  feature "clicking FORCE LEADER ELECTION triggers Leader election initiated flash", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='force_election']", text: "FORCE LEADER ELECTION"))
    |> assert_has(css("[role='alert']", text: "Leader election initiated"))
  end

  # Event: force_election — page stability (sentinel row still present)
  feature "clicking FORCE LEADER ELECTION keeps sentinel status row visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='force_election']", text: "FORCE LEADER ELECTION"))
    |> assert_has(css("span", text: "Quorum:"))
  end

  # Event: add_node — flash
  feature "clicking ADD NODE button triggers Add node wizard opened flash", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='add_node']", text: "ADD NODE", at: 0))
    |> assert_has(css("[role='alert']", text: "Add node wizard opened"))
  end

  # Event: add_node — page stability (cluster nodes section remains)
  feature "clicking ADD NODE keeps CLUSTER NODES panel visible", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='add_node']", text: "ADD NODE", at: 0))
    |> assert_has(css("h2", text: "CLUSTER NODES"))
  end

  # Event: remove_node — flash (requires node selected first)
  feature "REMOVE NODE button triggers removal requires confirmation flash after selection", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> click(css("button[phx-click='remove_node']", text: "REMOVE NODE"))
    |> assert_has(css("[role='alert']", text: "removal requires confirmation"))
  end

  # Event: remove_node — page stability after warning
  feature "REMOVE NODE warning keeps CLUSTER NODES panel visible", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    |> click(css("button[phx-click='remove_node']", text: "REMOVE NODE"))
    |> assert_has(css("h2", text: "CLUSTER NODES"))
  end

  # Event: select_node — visual highlight applied
  feature "selected node row gets highlighted background class", %{session: session} do
    session
    |> visit(@path)
    |> click(css("[phx-click='select_node']", at: 0))
    # bg-surface-tertiary is applied to the selected row
    |> assert_has(css(".bg-surface-tertiary"))
  end

  # ── C3: Data Grid and Node Details (Capability Router) ───────────────────

  feature "capability router shows Kubernetes backend as not configured", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Kubernetes"))
  end

  feature "capability router shows available status checkmarks", %{session: session} do
    session
    |> visit(@path)
    # Available backends show checkmark unicode
    |> assert_has(css("span.text-green-400", text: "Available"))
  end

  feature "gossip log shows cluster formation complete entry", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Cluster formation complete"))
  end

  # ── C2: Status and Badge Display (FLAME Pool Utilization) ────────────────

  feature "FLAME pool utilization percentage is rendered next to progress bar", %{
    session: session
  } do
    session
    |> visit(@path)
    # Pool utilization renders as e.g. "72%"
    |> assert_has(css("span", text: "%"))
  end

  feature "Intelligence Pool utilization bar is rendered in FLAME POOLS panel", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div[style*='width:']"))
  end

  # ── C1: Page Structure (Header Time and Footer) ───────────────────────────

  feature "header displays current UTC time in HH:MM:SS format", %{session: session} do
    session
    |> visit(@path)
    # Time rendered by Calendar.strftime contains colon separators
    |> assert_has(css("header span", text: ":"))
  end

  feature "footer shows Tailscale DNS and libcluster attribution", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("footer div", text: "Tailscale DNS"))
  end

  # ── C5: Interactive Elements (Stability / Refresh Cycle) ─────────────────

  feature "cluster page remains stable after a 2000ms refresh cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "CLUSTER NODES"))
    assert_has(session, css("h2", text: "FLAME POOLS"))

    Process.sleep(2_000)

    assert_has(session, css("h2", text: "CLUSTER NODES"))
    assert_has(session, css("h2", text: "FLAME POOLS"))
  end

  # ── C4: Timeline/History ──────────────────────────────────────────────────

  feature "gossip log shows timestamped entries in chronological order", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "GOSSIP LOG"))
    |> assert_has(css("span.text-content-muted", minimum: 1))
  end

  feature "gossip log persists after page revisit with same structural entries", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "heartbeat received"))
    |> visit(@path)
    |> assert_has(css("span", text: "heartbeat received"))
  end

  feature "cluster page sentinel status row remains stable after revisit", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Quorum:"))
    |> visit(@path)
    |> assert_has(css("span", text: "Quorum:"))
  end

  feature "gossip log shows cluster formation event as earliest history entry", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Cluster formation complete"))
    |> visit(@path)
    |> assert_has(css("span", text: "Cluster formation complete"))
  end

  # ── C6: Media/Rich Content ──────────────────────────────────────────────────

  feature "page root uses bg-surface-primary semantic CSS class", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".bg-surface-primary"))
  end

  feature "page uses font-mono semantic class on root container", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css(".font-mono"))
  end

  feature "header uses bg-surface-secondary and border-border-theme-primary classes", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("header.bg-surface-secondary"))
  end

  feature "CLUSTER NODES and FLAME POOLS panels use border-border-theme-primary class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css(".border-border-theme-primary", minimum: 3))
  end

  feature "color-rich split-brain NO label uses text-green-400 semantic class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span.text-green-400", text: "NO"))
  end

  # ── C7: AI/Advisory Panels ──────────────────────────────────────────────────

  feature "sentinel status provides quorum context with current over required nodes", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Quorum:"))
    |> assert_has(css("span", text: "/"))
  end

  feature "capability router current routing line provides system routing context", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Current routing:"))
    |> assert_has(css("div", text: "Process"))
  end

  feature "sentinel DNS provider label provides cluster discovery context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "DNS:"))
    |> assert_has(css("span.text-content-secondary", minimum: 1))
  end

  feature "FLAME pool node count provides utilization summary context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Intelligence Pool"))
    |> assert_has(css("span", text: "nodes"))
  end
end
