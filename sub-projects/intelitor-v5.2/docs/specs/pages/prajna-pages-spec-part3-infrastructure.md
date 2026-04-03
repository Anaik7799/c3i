# Prajna Page Specifications — Part 3: P2 Infrastructure & P3 Admin Pages
**Generated**: 20260328-2100 CEST
**Purpose**: Comprehensive design, intent, expected behavior, BDD, and UX specs
**Compliance**: SC-COV-008, SC-HMI-010, SC-UIGT-001

---

## Table of Contents

### P2 Infrastructure (11 pages)
1. [Containers](#1-containers)
2. [Devices](#2-devices)
3. [Mesh](#3-mesh)
4. [Startup](#4-startup)
5. [Observability](#5-observability)
6. [Register](#6-register)
7. [Git Intelligence](#7-git-intelligence)
8. [Topology](#8-topology)
9. [Prometheus](#9-prometheus)
10. [Access Control](#10-access-control)
11. [Video](#11-video)

### P3 Admin (7 pages)
12. [Prajna Dashboard](#12-prajna-dashboard)
13. [Guardian Dashboard](#13-guardian-dashboard)
14. [Health Sparkline](#14-health-sparkline)
15. [Zenoh Mesh Health](#15-zenoh-mesh-health)
16. [Knowledge: Developer](#16-knowledge-developer)
17. [Knowledge: Product](#17-knowledge-product)
18. [Knowledge: SRE](#18-knowledge-sre)

### Additional Operations/Admin (3 pages)
19. [Operations Access Dashboard](#19-operations-access-dashboard)
20. [STAMP/TDG/GDE Dashboard](#20-stamptdggde-dashboard)
21. [Navigation Portal](#21-navigation-portal)

---

## P2 INFRASTRUCTURE PAGES

---

## 1. Containers

### 1.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/containers` |
| Module | `IndrajaalWeb.Prajna.ContainersLive` |
| File | `lib/indrajaal_web/live/prajna/containers_live.ex` |
| Page Title | "Container Mesh" |
| Tier | P2 Infrastructure |

### 1.2 Design Intent
The Containers page provides a live operations view of the 4-container standalone stack (db, redis, obs, app). It follows the NASA-STD-3000 Dark Cockpit principle: silent when healthy, loud when degraded. Operators need to see container health at a glance, inspect live metrics, read recent logs, and initiate restart operations through a two-step Guardian-gated commit. The page bridges the gap between `podman ps` and the Zenoh telemetry bus by consuming both BEAM intrinsic metrics and PubSub events from the container orchestrator.

### 1.3 Expected Behavior (Functional)

**Data Displayed:**
- 4 container cards: `indrajaal-db-prod` (PostgreSQL), `indrajaal-redis` (Redis cache), `indrajaal-obs-prod` (Observability stack), `indrajaal-ex-app-1` (Phoenix app)
- Per card: status badge (healthy/degraded/offline/starting), CPU%, memory MB, uptime, port list, restart count
- For `:app` container specifically: real BEAM metrics from `:erlang.memory()`, `:erlang.statistics(:run_queue)`, `:erlang.system_info(:process_count)`
- For other containers: synthetic metrics with small random jitter each refresh
- Log modal overlay: last 50 log lines with per-level CSS classes (error=red, warning=yellow, info=green, debug=gray)
- Status icons via `@status_icons` map; health icons via `@health_icons` map

**Interactions:**
- Select container card → highlights selected, shows detail sidebar
- "View Logs" button → opens log modal overlay for selected container
- "Close Logs" → dismisses modal
- "Restart Container" → arms restart command, redirects to Command Center (two-step, does NOT execute directly)
- "Start All" / "Stop All" → arms bulk operations, requires Guardian confirmation
- Auto-refresh every 2 seconds via `:timer.send_interval(2000, self(), :refresh)`
- PubSub `prajna:containers` channel: merges `{:container_update, id, data}` into containers map

### 1.4 AS-IS State (from source)

**mount/3 assigns:**
```
containers: %{db: %{...}, redis: %{...}, obs: %{...}, app: %{...}}
selected_container: nil
show_logs: false
logs: []
current_view: :overview
status_icons: %{healthy: "●", degraded: "◑", offline: "○", starting: "◐"}
health_icons: %{high: "▲", medium: "►", low: "▼"}
```

**handle_event:**
- `select_container` → `assign(:selected_container, id)`
- `restart_container` → arms command, redirect to `/cockpit/commands`
- `view_logs` → `assign(:show_logs, true)`, `assign(:logs, load_logs(id))`
- `close_logs` → `assign(:show_logs, false)`
- `start_all` / `stop_all` → puts flash warning (arm pattern)

**handle_info:**
- `:refresh` → recomputes all container metrics, replaces assigns
- `{:container_update, id, data}` → merges data into containers map via `update_in`

**Timer:** 2s interval (`@refresh_interval 2_000`)

**PubSub:** `prajna:containers`

### 1.5 BDD Scenarios

```gherkin
Feature: Container Mesh LiveView

  Background:
    Given I am on "/cockpit/containers"
    And the 4-container stack is running

  Scenario: C1-CNT-01 Page structure loads with all containers
    Then I should see "Container Mesh"
    And I should see "indrajaal-db-prod"
    And I should see "indrajaal-ex-app-1"
    And I should see "indrajaal-obs-prod"
    And I should see status indicators for all containers

  Scenario: C2-CNT-02 Status badges reflect container health
    When the app container is healthy
    Then its status badge should show "●" (filled circle)
    And the badge should have a green CSS class

  Scenario: C3-CNT-03 Selecting a container shows detail
    When I click on "indrajaal-ex-app-1"
    Then I should see the detail sidebar
    And I should see BEAM process count
    And I should see memory usage in MB

  Scenario: C4-CNT-04 Log modal opens and closes
    Given I have selected "indrajaal-ex-app-1"
    When I click "View Logs"
    Then I should see the log overlay
    And log lines should have color-coded severity classes
    When I click "Close Logs"
    Then the log overlay should be dismissed

  Scenario: C5-CNT-05 Refresh updates metrics
    Given I am on the containers page
    When 2 seconds elapse
    Then the metrics should refresh automatically
    And timestamps should be updated
```

### 1.6 UX Flow

1. Land on page → 4 container cards in 2×2 grid, each showing status dot, name, key metrics
2. Visually scan for any degraded (◑) or offline (○) status indicators
3. Click a container card → detail sidebar slides in with full metrics
4. Click "View Logs" → modal overlays with scrollable log feed, color-coded by level
5. Dismiss logs → return to grid view
6. To restart: click "Restart" on card → flash confirms arm → redirected to Command Center for Guardian confirmation

### 1.7 UI Elements Inventory

| Element | Type | phx-click / phx-submit | Notes |
|---------|------|------------------------|-------|
| Container card | Div | `select_container` + `phx-value-id` | Highlights selection |
| Restart button | Button | `restart_container` + `phx-value-id` | Arms, redirects to commands |
| View Logs button | Button | `view_logs` + `phx-value-id` | Opens modal |
| Close Logs button | Button | `close_logs` | Dismisses modal |
| Start All button | Button | `start_all` | Flash warning |
| Stop All button | Button | `stop_all` | Flash warning |
| Status dot | Span | — | CSS class from `@status_icons` |
| Health bar | Div | — | Width % from metric value |
| Log line | Div | — | CSS class from log level |

### 1.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-001 | Dark Cockpit: silence = health, status dots only when anomaly |
| SC-HMI-004 | Two-step commit for restart operations |
| SC-CNT-001 | Container health visible within 2s of status change |
| SC-SAFETY-001 | Destructive operations (stop/restart) gated by Guardian |
| SC-MON-001 | Metrics refresh every 30s minimum (actual: 2s) |
| SC-ZENOH-003 | PubSub channel must be subscribed on connected? |

### 1.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| App container shows stale BEAM metrics after restart | 7 | 4 | 5 | 140 | Reset metric state on `{:container_update, :app, _}` |
| Log modal blocks page refresh, operators miss alert | 6 | 3 | 4 | 72 | Auto-close modal after 60s inactivity |
| Restart fires without Guardian confirmation | 9 | 2 | 2 | 36 | Two-step enforced in router/controller |
| PubSub topic mismatch causes silent stale data | 7 | 3 | 6 | 126 | Add staleness indicator (SC-HMI-003) |

---

## 2. Devices

### 2.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/devices` |
| Module | `IndrajaalWeb.Prajna.DevicesLive` |
| File | `lib/indrajaal_web/live/prajna/devices_live.ex` |
| Page Title | "Device Health Matrix" |
| Tier | P2 Infrastructure |

### 2.2 Design Intent
The Devices page gives operators a unified health matrix of all 30 physical security devices in the mesh (cameras, card readers, controllers, sensors). The page solves the operator's problem of scanning dozens of field devices for degraded units without navigating per-device dashboards. It supports both grid (thumbnail) and list (table) view modes. Multi-dimensional filtering (status × type × site × search) enables rapid triage. A detail modal gives full device context without leaving the page.

### 2.3 Expected Behavior (Functional)

**Data Displayed:**
- 30 synthetic devices across 4 types: camera (8), reader (8), controller (8), sensor (6)
- Per device: id, name, type, status (online/offline/degraded), location, IP, firmware, last_seen, uptime %, health_score
- 5-metric summary bar: total_devices, online_count, degraded_count, offline_count, avg_uptime
- Grid mode: icon grid, color-coded status dots
- List mode: sortable table with all key fields
- Detail modal: full device profile with health_score gauge

**Interactions:**
- Filter by status (online/offline/degraded/all)
- Filter by type (camera/reader/controller/sensor/all)
- Search by name (debounce 300ms)
- Toggle view mode (grid/list)
- Click device → opens detail modal
- Close detail → dismisses modal

**Timers:** 5s refresh (`:timer.send_interval(5000, :refresh)`), 10s metrics sync (`:timer.send_interval(10_000, :sync_metrics)`)

**PubSub:** `prajna:devices`, `zenoh:devices`

**BEAM intrinsics used:**
- `:erlang.system_info(:port_count)` → total device proxy count
- `:erlang.statistics(:run_queue)` → degraded count proxy
- `:erlang.memory(:total)` → offline proxy

### 2.4 AS-IS State (from source)

**mount/3 assigns:**
```
devices: [30 device maps with type/status/location/ip/firmware/last_seen/uptime/health_score]
filter_status: :all
filter_type: :all
filter_site: :all
search_query: ""
selected_device: nil
view_mode: :grid
metrics: %{total: 30, online: N, degraded: N, offline: N, avg_uptime: N}
```

**handle_event:**
- `filter_status` → `assign(:filter_status, atom)`
- `filter_type` → `assign(:filter_type, atom)`
- `search` → `assign(:search_query, value)` (debounce 300ms)
- `select_device` → `assign(:selected_device, device_map)`
- `close_detail` → `assign(:selected_device, nil)`
- `toggle_view` → toggles `:view_mode` between `:grid` and `:list`

**handle_info:**
- `:refresh` → regenerates device list with new synthetic data
- `:sync_metrics` → recomputes metrics summary from current device list
- `{:devices_update, data}` → merges data into devices

### 2.5 BDD Scenarios

```gherkin
Feature: Device Health Matrix LiveView

  Scenario: C1-DEV-01 Grid shows all device types
    Given I navigate to "/cockpit/devices"
    Then I should see "Device Health Matrix"
    And I should see device cards for cameras, readers, controllers, sensors
    And I should see the metrics summary bar

  Scenario: C2-DEV-02 Status filter reduces displayed devices
    When I select filter "offline"
    Then only offline devices should be visible
    And the device count shown should decrease

  Scenario: C3-DEV-03 Search filters by device name
    When I type "cam-01" in the search field
    Then only devices matching "cam-01" should appear

  Scenario: C4-DEV-04 Detail modal shows full profile
    When I click on device "cam-01"
    Then I should see a modal with IP address
    And I should see firmware version
    And I should see health score
    When I click "Close"
    Then the modal should be dismissed

  Scenario: C5-DEV-05 View mode toggle switches layout
    When I click the list view toggle
    Then the layout should switch to table format
    When I click the grid view toggle
    Then the layout should switch back to grid format
```

### 2.6 UX Flow

1. Land → metrics summary bar shows counts at a glance
2. Default grid view: color-coded tiles (green=online, amber=degraded, red=offline)
3. Filter panel on left: status dropdown, type dropdown, search input
4. Spot degraded units → click tile → modal opens with full device profile
5. Review IP, firmware, uptime, health score
6. Dismiss modal → continue scanning grid
7. Switch to list view for tabular comparison

### 2.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| Status filter select | Select | `filter_status` | Triggers on phx-change |
| Type filter select | Select | `filter_type` | Triggers on phx-change |
| Search input | Input | `search` | phx-keyup, phx-debounce="300" |
| Grid view button | Button | `toggle_view` + `phx-value-mode=grid` | Switches layout |
| List view button | Button | `toggle_view` + `phx-value-mode=list` | Switches layout |
| Device card / row | Div/TR | `select_device` + `phx-value-id` | Opens modal |
| Close detail button | Button | `close_detail` | Dismisses modal |
| Status badge | Span | — | Color from status |
| Health score gauge | Div | — | Width % from health_score |

### 2.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-DEV-001 | Device status refresh interval ≤ 5s |
| SC-DEV-002 | All connected devices visible in matrix |
| SC-HMI-002 | Analog representation (health gauges) preferred over digital |
| SC-HMI-003 | Staleness decay: last_seen timestamp visible per device |
| SC-MON-003 | Domain metrics (device domain) displayed |

### 2.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Device list grows beyond 30, grid becomes unusable | 5 | 3 | 3 | 45 | Paginate at 50 devices; virtual scroll |
| Search debounce too long, operator frustration | 3 | 4 | 5 | 60 | 300ms is acceptable; document expectation |
| `zenoh:devices` topic silent → stale data displayed | 7 | 3 | 6 | 126 | Staleness indicator on each tile (SC-HMI-003) |
| Modal blocks real-time updates on degraded device | 6 | 3 | 4 | 72 | Modal pulls live data, not cached |

---

## 3. Mesh

### 3.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/mesh` |
| Module | `IndrajaalWeb.Prajna.MeshLive` |
| File | `lib/indrajaal_web/live/prajna/mesh_live.ex` |
| Page Title | "Mesh Topology" |
| Tier | P2 Infrastructure |

### 3.2 Design Intent
The Mesh page implements Ecological Interface Design (EID, Burns & Hajdukiewicz) for the Zenoh mesh topology. Rather than raw node tables, it renders a tree-layout visualization (gateway → supervisor → controllers → workers) that maps spatial position to functional hierarchy. Operators can see at a glance how nodes relate, which are degraded, and which alarms are active. The constraint SC-EID-001 mandates that the display surface conveys relational structure, not just state.

### 3.3 Expected Behavior (Functional)

**Data Displayed:**
- 6 nodes: gateway (root), supervisor, 3 controllers, 1 worker
- Per node: role, zone, IP address, status (online/degraded/offline), CPU%, memory%, network KB/s, latency ms
- Sparkline of recent latency trend (10 points)
- Active alarm count and most recent alarm message (from SentinelBridge)
- Tree layout: root at top, branches below
- Node status icons via `@role_icons`, `@status_icons`, `@trend_icons` maps

**Interactions:**
- Click node → populates right-panel node detail
- "Clear Selection" button → clears detail panel
- "Restart Node" → arms operation (two-step, redirects to Command Center)
- "Isolate Node" → arms isolation command
- "Drain Node" → arms drain command

**Timer:** 2s refresh

**PubSub:** `prajna:mesh`

**SentinelBridge:** alarm_count and advisory message sourced from `SentinelBridge.get_status()`

### 3.4 AS-IS State (from source)

**mount/3 assigns:**
```
nodes: [6 node maps with role/zone/ip/status/cpu/memory/network/latency/sparkline/alarms]
selected_node: nil
connections: [{source_id, target_id}, ...]  (tree edges)
view_mode: :tree
role_icons: %{gateway: "◈", supervisor: "◉", controller: "●", worker: "○"}
status_icons: %{online: "▲", degraded: "►", offline: "▼"}
trend_icons: %{up: "↑", stable: "→", down: "↓"}
```

**handle_event:**
- `select_node` → `assign(:selected_node, node_map)`
- `clear_selection` → `assign(:selected_node, nil)`
- `restart_node` → arms + flash + redirect hint
- `isolate_node` → arms + flash
- `drain_node` → arms + flash

**handle_info:**
- `:refresh` → regenerates node metrics with jitter, updates sparklines
- `{:mesh_update, data}` → merges node updates

### 3.5 BDD Scenarios

```gherkin
Feature: Mesh Topology LiveView

  Scenario: C1-MESH-01 Tree layout renders all nodes
    Given I navigate to "/cockpit/mesh"
    Then I should see "Mesh Topology"
    And I should see the gateway node at the top
    And I should see supervisor and controller nodes below it

  Scenario: C2-MESH-02 Status icons reflect node health
    When the supervisor node is degraded
    Then its status icon should be "►" (degraded indicator)
    And it should have an amber color class

  Scenario: C3-MESH-03 Node selection shows detail panel
    When I click on the gateway node
    Then the right panel should show gateway details
    And I should see CPU%, memory%, network metrics
    And I should see the latency sparkline

  Scenario: C4-MESH-04 Sentinel alarm count visible
    Given SentinelBridge reports 3 active alarms for the gateway
    When I view the gateway node card
    Then I should see "3 alarms" indicator

  Scenario: C5-MESH-05 Clear selection removes detail panel
    Given I have selected a node
    When I click "Clear Selection"
    Then the detail panel should be empty
```

### 3.6 UX Flow

1. Land → tree diagram with gateway at apex, branches below
2. Scan icons: ▲=healthy, ►=degraded, ▼=offline
3. Click a node of interest → detail panel expands on right
4. Review: role, zone, IP, resource bars, latency sparkline, alarm badge
5. If action needed: click Restart/Isolate/Drain → armed state → navigate to Command Center
6. Clear selection → return to full tree scanning mode

### 3.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Node card | Div | `select_node` + `phx-value-id` | Highlights selected |
| Clear Selection | Button | `clear_selection` | Clears detail panel |
| Restart Node | Button | `restart_node` + `phx-value-id` | Arms, redirects |
| Isolate Node | Button | `isolate_node` + `phx-value-id` | Arms isolation |
| Drain Node | Button | `drain_node` + `phx-value-id` | Arms drain |
| Status icon | Span | — | From `@status_icons` map |
| CPU/memory bar | Div | — | Width % from metric |
| Latency sparkline | SVG | — | 10-point polyline |
| Alarm badge | Span | — | Red badge if alarms > 0 |

### 3.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-EID-001 | Ecological Interface Design — topology conveys relational structure |
| SC-HMI-001 | Dark Cockpit — icons illuminate only on anomaly |
| SC-SAFETY-001 | Two-step commit for node operations |
| SC-MON-002 | Infrastructure metrics (CPU/mem/net) displayed |
| SC-MESH-001 | All mesh nodes visible in single view |

### 3.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| SentinelBridge unavailable → alarm_count shows 0 (false negative) | 8 | 3 | 5 | 120 | Default to "unknown" badge if SentinelBridge returns error |
| Node sparkline data overflows memory after long uptime | 4 | 2 | 3 | 24 | Cap sparkline at 10 points |
| "Drain Node" misfired on wrong node (user confusion) | 7 | 3 | 4 | 84 | Require node name in confirmation dialog |

---

## 4. Startup

### 4.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/startup` |
| Module | `IndrajaalWeb.Prajna.StartupLive` |
| File | `lib/indrajaal_web/live/prajna/startup_live.ex` |
| Page Title | "System Startup" |
| Tier | P2 Infrastructure |

### 4.2 Design Intent
The Startup page is the boot-time HMI. It shows the 4-phase startup sequence (Infrastructure → Safety → Distributed → Containers) as a progress tracker, displaying phase status, step-level icons, overall progress percentage, and estimated remaining time. An ASCII art PRAJNA logo renders in `<pre>` to mark the system identity during boot. The page provides an abort path and a "skip to cockpit" option for partial-boot scenarios. It is the only page that consumes `prajna:startup` PubSub messages.

### 4.3 Expected Behavior (Functional)

**Data Displayed:**
- ASCII art PRAJNA logo in `<pre>` block
- 4 phases with names and step lists
- Per phase: overall status badge (pending/running/complete/failed), steps with individual status icons
- Global progress bar (0–100%) updated each `:refresh` tick
- `estimated_remaining` countdown in seconds
- `started_at` timestamp
- Abort warning modal (shown when `aborted == true`)

**Interactions:**
- "Abort Startup" → sets `aborted: true`, shows warning modal
- "Skip to Cockpit" / "Continue to Cockpit (Limited Mode)" → navigate to `/prajna`
- Auto-advance startup simulation each 500ms `:refresh` tick (advances step states)

**Timer:** 500ms refresh (`@refresh_interval 500`)

**PubSub:** `prajna:startup` — receives `{:startup_step, phase_id, step_id, status}`

### 4.4 AS-IS State (from source)

**mount/3 assigns:**
```
phases: [4 phase maps, each with id/name/status/steps list]
logs: ["[INFO] Starting Indrajaal v21.3.0-SIL6...", ...]
started_at: DateTime.utc_now()
estimated_remaining: 120  (seconds)
overall_progress: 0
aborted: false
status_icons: %{pending: "○", running: "◐", complete: "●", failed: "✗"}
```

**handle_event:**
- `abort_startup` → `assign(:aborted, true)`
- `skip_to_cockpit` → `push_navigate(socket, to: "/prajna")`

**handle_info:**
- `:refresh` → advances startup simulation (increments progress, marks steps complete)
- `{:startup_step, phase_id, step_id, status}` → updates specific step in phases list

### 4.5 BDD Scenarios

```gherkin
Feature: Startup Sequence Monitor

  Scenario: C1-STA-01 ASCII art logo renders
    Given I navigate to "/cockpit/startup"
    Then I should see the PRAJNA ASCII art logo in a pre block
    And I should see "System Startup"

  Scenario: C2-STA-02 Phase progress advances over time
    Given the page is loaded
    When 500ms elapses
    Then the overall_progress value should increase
    And at least one step should show "running" status

  Scenario: C3-STA-03 Abort shows warning modal
    When I click "Abort Startup"
    Then I should see the abort warning modal
    And I should see "Continue to Cockpit (Limited Mode)" option

  Scenario: C4-STA-04 Skip to cockpit navigates away
    When I click "Skip to Cockpit"
    Then I should be navigated to "/prajna"

  Scenario: C5-STA-05 PubSub step update reflects in UI
    When a startup_step event arrives for phase 2, step 1, status complete
    Then phase 2 step 1 should show the "●" (complete) icon
```

### 4.6 UX Flow

1. System starts → browser auto-navigates to `/cockpit/startup`
2. ASCII PRAJNA logo renders → phase tracker below it
3. Each 500ms: progress bar advances, steps tick from ○ → ◐ → ●
4. If step fails: ✗ icon, phase halts, error logged
5. Completion: all 4 phases show ●, progress=100%, auto-redirect to `/prajna`
6. Operator may click "Skip to Cockpit" at any time for emergency access

### 4.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| PRAJNA logo | Pre | — | ASCII art in `<pre>` block |
| Phase status badge | Span | — | CSS class from status |
| Step status icon | Span | — | From `@status_icons` map |
| Overall progress bar | Div | — | Width from `@overall_progress` % |
| Abort Startup button | Button | `abort_startup` | Shows modal |
| Skip to Cockpit button | Button | `skip_to_cockpit` | Navigates to /prajna |
| Continue Limited button | Button | `skip_to_cockpit` | In modal, same handler |
| Log tail | Div | — | Recent log lines |

### 4.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-BOOT-001 | State vector verified before each stage |
| SC-BOOT-004 | Boot transactional with rollback support |
| SC-BOOT-005 | Boot time < 120s (target 60s) |
| SC-HMI-001 | Dark Cockpit: progress icons, minimal chrome |
| SC-VER-001 | Startup verification before app ready |

### 4.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| 500ms refresh causes high CPU during boot stress | 5 | 3 | 4 | 60 | Throttle to 1s after phase 2 complete |
| Startup halts with no visible error | 8 | 2 | 3 | 48 | Failed steps must show ✗ icon + log entry |
| Skip to Cockpit used prematurely → broken UI | 6 | 4 | 5 | 120 | Show capability warning in limited mode banner |

---

## 5. Observability

### 5.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/observability` |
| Module | `IndrajaalWeb.Prajna.ObservabilityLive` |
| File | `lib/indrajaal_web/live/prajna/observability_live.ex` |
| Page Title | "Observability" |
| Tier | P2 Infrastructure |

### 5.2 Design Intent
The Observability page is the OTEL telemetry HMI. It surfaces three types of observability data — metrics, traces, and logs — plus an embedded SigNoz link. Each tab is a different LTS state with its own data set. The page solves the problem of operators having to leave the Prajna cockpit to check Grafana or SigNoz for performance issues: key KPIs (request rate, error rate, p99 latency) are surfaced directly in the cockpit with SVG sparklines and threshold-based colorization. The OTEL status widget shows which of the 4 instrumentation modules (Phoenix, Ecto, Oban, Finch) are loaded via `Code.ensure_loaded?`.

### 5.3 Expected Behavior (Functional)

**Data Displayed:**
- 4 tabs: Metrics, Traces, Logs, SigNoz
- Metrics tab: 3 KPI cards (request_rate, error_rate, p99_latency) with 30-point sparklines; 3 resource cards (active_connections, db_pool_used, flame_utilization)
- Traces tab: slowest traces first, expandable span tree, duration badge, status code
- Logs tab: structured log stream (level, timestamp, message, node)
- SigNoz tab: embedded link + status summary
- OTEL status widget: 4 modules shown with `Code.ensure_loaded?` live check
- Node count badge: N/total_nodes in mesh

**Interactions:**
- `switch_tab` → changes active tab, shows corresponding panel
- `view_trace` → expands trace span tree
- `open_signoz` → opens SigNoz URL in new tab
- `export_metrics` → flash confirmation (stub)

**Timer:** 500ms refresh (`@refresh_interval 500`)

**PubSub:** `prajna:metrics`, `prajna:traces`

### 5.4 AS-IS State (from source)

**mount/3 assigns:**
```
active_tab: :metrics
metrics: %{request_rate: N, error_rate: N, p99_latency: N, sparklines: [...]}
traces: [trace maps with id/duration/spans/status]
otel_status: %{phoenix: bool, ecto: bool, oban: bool, finch: bool}
signoz_status: :ok | :unavailable
sparkline_length: 30
otel_modules: 4
node_count: N
total_nodes: N
trace_tick: 0
```

**handle_event:**
- `switch_tab` → `assign(:active_tab, atom)`
- `view_trace` → toggles trace expand state
- `open_signoz` → push_event for JS window.open
- `export_metrics` → put_flash

**handle_info:**
- `:refresh` → appends new metric point to sparklines (pop front, push back), increments trace_tick
- `{:metrics_update, metrics}` → merges live metrics
- `{:trace_update, trace}` → prepends trace

### 5.5 BDD Scenarios

```gherkin
Feature: Observability LiveView

  Scenario: C1-OBS-01 Metrics tab shows KPI cards
    Given I navigate to "/cockpit/observability"
    Then I should see "Observability"
    And I should see request_rate card
    And I should see error_rate card
    And I should see p99_latency card
    And each card should have a sparkline

  Scenario: C2-OBS-02 OTEL module status displays correctly
    When Phoenix instrumentation is loaded
    Then the OTEL status widget should show "phoenix: ✓"

  Scenario: C3-OBS-03 Tab switching shows correct panel
    When I click the "Traces" tab
    Then the metrics panel should be hidden
    And the traces list should be visible

  Scenario: C4-OBS-04 Sparklines update on refresh
    Given I am on the metrics tab
    When 500ms elapses
    Then the sparkline data should have a new rightmost point

  Scenario: C5-OBS-05 PubSub metrics update live
    When a metrics_update PubSub message arrives with p99_latency: 95
    Then the p99_latency card should show 95ms
    And if 95 > threshold, the card border should be red
```

### 5.6 UX Flow

1. Land on Metrics tab → KPI cards with real-time sparklines
2. Threshold breach: card border turns red automatically
3. Switch to Traces tab → sorted by slowest first
4. Click a trace → span tree expands
5. Switch to Logs tab → structured log stream
6. Switch to SigNoz tab → link + status, click to open in new tab
7. OTEL status widget always visible (bottom of page)

### 5.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Metrics tab | Button | `switch_tab` + `phx-value-tab=metrics` | Active highlight |
| Traces tab | Button | `switch_tab` + `phx-value-tab=traces` | |
| Logs tab | Button | `switch_tab` + `phx-value-tab=logs` | |
| SigNoz tab | Button | `switch_tab` + `phx-value-tab=signoz` | |
| KPI card | Div | — | Threshold-colored border |
| Sparkline | SVG polyline | — | 30-point, no JS library |
| Trace row | Div | `view_trace` + `phx-value-id` | Expands spans |
| Open SigNoz | Button | `open_signoz` | push_event for new tab |
| Export Metrics | Button | `export_metrics` | Flash stub |

### 5.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-001 | Dark Cockpit: threshold exceeded → color alarm |
| SC-MON-001 | Metrics refresh at 500ms (well within 30s requirement) |
| SC-OBS-071 | 4 OTEL modules (Phoenix, Ecto, Oban, Finch) all instrumented |
| SC-OBS-069 | Dual Log (Term + Zenoh) visible in logs tab |
| SC-ZENOH-003 | PubSub subscriptions on `prajna:metrics` and `prajna:traces` |

### 5.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Sparkline buffer grows unbounded | 5 | 3 | 3 | 45 | Fixed at 30 points (pop front on append) |
| OTEL module check via Code.ensure_loaded? returns stale result | 4 | 2 | 4 | 32 | Re-check on each :refresh tick |
| SigNoz URL unavailable → tab shows nothing | 5 | 4 | 4 | 80 | Show connection error state in SigNoz tab |
| p99 threshold misconfigured → no red border on breach | 7 | 2 | 5 | 70 | Assert threshold values in config test |

---

## 6. Register

### 6.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/register` |
| Module | `IndrajaalWeb.Prajna.RegisterLive` |
| File | `lib/indrajaal_web/live/prajna/register_live.ex` |
| Page Title | "Immutable Register" |
| Tier | P2 Infrastructure |

### 6.2 Design Intent
The Register page exposes the ImmutableRegister SHA3-256 hash chain to operators. It is a read-only audit surface: no user actions mutate state. Its purpose is dual — compliance verification (is the chain valid?) and forensic inspection (what are the most recent blocks?). The page calls `ImmutableRegister.verify/0`, `ImmutableRegister.stats/0`, `ImmutableRegister.head/0`, and `ImmutableRegister.get_full_state/0` on each refresh cycle. The 4 KPI cards map directly to the four safety properties: chain integrity, block count, Reed-Solomon parity, and latest hash fingerprint.

### 6.3 Expected Behavior (Functional)

**Data Displayed:**
- 4 KPI cards: Chain Status (VALID/BROKEN/UNKNOWN), Block Count (integer), RS Parity (OK/FAIL), Latest Hash (truncated hex)
- "Recent Blocks" list: last N blocks with timestamp, type, actor, hash snippet
- `last_verified` timestamp
- When chain is uninitialized: "Chain initialized - awaiting blocks" placeholder

**Interactions:**
- None (read-only page — no handle_event callbacks)

**Timer:** 10s refresh (`@refresh_interval 10_000`)

**PubSub:** none

### 6.4 AS-IS State (from source)

**mount/3 assigns:**
```
chain_valid: :unknown | :valid | :broken
block_count: 0
latest_hash: nil | binary
rs_parity_ok: :unknown | true | false
recent_blocks: []
last_verified: DateTime.utc_now()
```

**handle_info:**
- `:refresh` → calls ImmutableRegister.verify/stats/head/get_full_state, updates all assigns

**No handle_event** (read-only)

### 6.5 BDD Scenarios

```gherkin
Feature: Immutable Register LiveView

  Scenario: C1-REG-01 Page structure loads correctly
    Given I navigate to "/cockpit/register"
    Then I should see "Immutable Register"
    And I should see 4 KPI cards
    And I should see the Recent Blocks section

  Scenario: C2-REG-02 Chain status badge shown
    When ImmutableRegister.verify returns :valid
    Then Chain Status card should show "VALID"
    And the badge should have a green CSS class

  Scenario: C3-REG-03 Broken chain shows critical alert
    When ImmutableRegister.verify returns :broken
    Then Chain Status card should show "BROKEN"
    And the badge should have a red CSS class

  Scenario: C4-REG-04 Block count increments over time
    Given the register has 5 blocks
    When a new block is appended externally
    And 10 seconds elapse for refresh
    Then block_count should show 6

  Scenario: C5-REG-05 Read-only — no action buttons present
    Given I navigate to "/cockpit/register"
    Then I should NOT see any phx-click buttons
    And the page should be purely informational
```

### 6.6 UX Flow

1. Land → 4 KPI cards across top
2. Scan Chain Status: green=VALID, red=BROKEN
3. Check Block Count for total register depth
4. Verify RS Parity for storage integrity
5. Inspect Latest Hash for fingerprint audit
6. Scroll to Recent Blocks: review last N mutations with actor and hash
7. Page auto-refreshes every 10s — no interaction required

### 6.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Chain Status card | Div | — | Color-coded badge |
| Block Count card | Div | — | Integer value |
| RS Parity card | Div | — | OK/FAIL badge |
| Latest Hash card | Div | — | Truncated hex string |
| Recent block row | Div | — | timestamp, type, actor, hash |
| Last Verified | Span | — | DateTime stamp |

### 6.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-REG-001 | All state mutations via cryptographically-signed append-only blocks |
| SC-REG-002 | Hash chain integrity verified on each refresh |
| SC-SAFETY-012 | Ψ₃ (Verification) — hash chain integrity |
| SC-SMRITI-141 | Lineage chain unbroken |
| Ψ₂ | Evolutionary Continuity: history preserved in register |

### 6.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| ImmutableRegister not started → all KPIs show :unknown | 6 | 3 | 3 | 54 | Supervisor ensures ImmutableRegister starts before this page |
| Chain shows BROKEN after hash collision (cosmic ray) | 9 | 1 | 1 | 9 | RS parity provides secondary verification |
| recent_blocks empty on fresh boot misleads operator | 3 | 5 | 5 | 75 | Show "Awaiting first block" placeholder explicitly |

---

## 7. Git Intelligence

### 7.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/git-intelligence` |
| Module | `IndrajaalWeb.Prajna.GitIntelligenceLive` |
| File | `lib/indrajaal_web/live/prajna/git_intelligence_live.ex` |
| Title | Git Intelligence Dashboard |
| Tier | P2 Infrastructure |

### 7.2 Design Intent

Closes the LiveView consumption gap in the F#→Zenoh→Elixir pipeline. The F# GitIntelligence subsystem publishes 14 Zenoh topics; the GitZenohSubscriber GenServer bridges those into ETS and Phoenix PubSub. This page renders the resulting telemetry for operators in real-time: Git Health Score (GHS), ICP commit adoption rate, biomorphic health, threat levels, vital signs, and Founder alignment signals.

### 7.3 Expected Behavior (Functional)

- Mount: reads ETS via `GitZenohSubscriber.get_metrics/0` (safe fallback to `%{}` on failure)
- Refresh timer (3 000ms): re-reads ETS via `GitZenohSubscriber.get_metrics/0` and `get_stats/0`
- PubSub `git_intelligence`: incoming events prepended to `recent_events` (max 20 items)
- PubSub `git_intelligence:health`: GHS and ICP adoption updated inline without full re-read
- PubSub `git_intelligence:threat`: threat level updated; event prepended to feed
- GHS is displayed as percentage with color-coded progress bar (green ≥80%, yellow ≥60%, orange ≥40%, red <40%)
- Threat level shown with color (none=green, low=blue, medium=yellow, high=orange, critical=red, emergency=red+pulse)
- No user-triggered events (read-only monitoring page)

### 7.4 AS-IS State

From `lib/indrajaal_web/live/prajna/git_intelligence_live.ex`:

- `@refresh_interval_ms 3_000` (3 second polling)
- PubSub subscriptions: `git_intelligence`, `git_intelligence:health`, `git_intelligence:threat`
- Assigns: `ghs` (float), `ghs_at` (timestamp), `icp_adoption` (float), `biomorphic_health` (map), `threat_level` (string), `vital_signs` (map), `founder_alignment` (map), `recent_events` (list, max 20), `subscriber_stats` (map), `last_refresh` (DateTime)
- Layout: header with last-refresh timestamp, 4-column KPI row (GHS, ICP Adoption, Threat Level, +1), biomorphic health section, recent events feed, subscriber stats
- GHS display: number rendered as percentage (`ghs * 100` with 1 decimal), with horizontal bar
- No `handle_event/3` clauses (pure display page)
- Errors in ETS reads silently fall back to previous values

### 7.5 BDD Scenarios

```gherkin
Feature: Git Intelligence Dashboard

  Scenario: C1-GIT-01 Page structure renders on load
    Given I navigate to "/cockpit/git-intelligence"
    Then I should see the heading "Git Intelligence Dashboard"
    And I should see a "Git Health Score" KPI card
    And I should see an "ICP Adoption" KPI card

  Scenario: C2-GIT-02 GHS progress bar reflects score
    Given the system has GHS = 0.75
    When I navigate to "/cockpit/git-intelligence"
    Then the GHS card should show "75.0%"
    And the progress bar should be yellow (0.6 ≤ GHS < 0.8)

  Scenario: C3-GIT-03 Threat level changes color
    Given GitIntelligence reports threat_level = "high"
    When the page receives the PubSub update
    Then the threat card should display "high" in orange

  Scenario: C3-GIT-04 Recent events feed prepends new events
    Given the page has 5 recent events
    When a new git_intelligence PubSub event arrives
    Then the feed should show 6 events with the newest at top

  Scenario: C3-GIT-05 Refresh timer updates last_refresh timestamp
    Given the page is mounted and connected
    When 3 seconds elapse
    Then the "Last refresh" timestamp in the header should update
```

### 7.6 UX Flow

1. Land → 4 KPI cards at top: GHS%, ICP Adoption%, Threat Level, Subscriber Stats
2. GHS bar gives instant visual health signal (color + width)
3. Biomorphic health section: map of sub-scores if populated
4. Vital signs section: map of subsystem vitals
5. Founder alignment section: alignment scores
6. Recent events feed: scrollable list of last 20 ETS/PubSub events with timestamps
7. Page auto-refreshes every 3s — entirely read-only, no operator interaction

### 7.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| GHS card | Div | — | Color-coded text + bar |
| ICP Adoption card | Div | — | Float × 100 as percentage |
| Threat Level card | Div | — | Animated pulse on "emergency" |
| Biomorphic Health section | Div | — | Map keys/values |
| Vital Signs section | Div | — | Map keys/values |
| Founder Alignment section | Div | — | Map keys/values |
| Recent Events feed | Ul/Li | — | Last 20, prepend-only |
| Subscriber Stats section | Div | — | ETS table diagnostics |
| Last Refresh timestamp | Span | — | Updates every 3s |

### 7.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-BRIDGE-001 | Message buffer FIFO — recent_events maintained in order |
| SC-BRIDGE-003 | Latency budget 50ms — ETS reads must complete within budget |
| SC-IMMUNE-001 | Sentinel threat escalation displayed via threat_level assign |
| SC-BIO-EXT-001 | PatternHunter pre-error detection < 10ms reflected in vitals |
| SC-HMI-002 | Trend vectors displayed (GHS bar + color gradients) |
| SC-HMI-010 | Color Rich — health colors tied to Zenoh metabolic telemetry |

### 7.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| GitZenohSubscriber not started → all assigns show defaults (0.0/empty) | 5 | 3 | 4 | 60 | try/rescue in safe_get_metrics returns %{} — page loads without crash |
| ETS table stale if F# GitIntelligence not publishing | 4 | 4 | 5 | 80 | Last-refresh timestamp visible — operator can detect stale data |
| Threat level stuck at "none" if PubSub bridge drops | 7 | 2 | 4 | 56 | 3s refresh timer re-reads ETS regardless of PubSub |
| recent_events grows unbounded in memory | 3 | 2 | 3 | 18 | `Enum.take(list, 19)` cap enforced in each handle_info |

---

## 8. Topology

### 8.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/topology` |
| Module | `IndrajaalWeb.Prajna.TopologyLive` |
| File | `lib/indrajaal_web/live/prajna/topology_live.ex` |
| Title | Holographic Visualizer (The Eye) |
| Tier | P2 Infrastructure |

### 8.2 Design Intent

Provides an L5 (Cluster) layer real-time visualisation of the system topology using the GraphBLAS engine via `Indrajaal.Graph.TopologyServer`. Operators see nodes laid out in a circular arrangement with SVG edges, centrality-scaled node radius, and a raw adjacency matrix tensor view. The goal is to surface cycle detection and high-centrality nodes (potential single points of failure) before they cause incidents.

### 8.3 Expected Behavior (Functional)

- Mount: calls `TopologyServer.get_state/0` synchronously to get `nodes`, `edges`, `matrix`, `has_cycle`, `centrality`
- `calculate_circle_layout/3` places N nodes equidistantly on a circle of radius 200 centered at (250,250)
- PubSub `topology:updates`: receives `{:topology_update, state}` → recalculates layout and updates all assigns
- PubSub: `{:correction_applied, payload}` → flash info message `"Cortex Correction Applied: ..."`
- No timer; driven purely by PubSub from TopologyServer
- SVG graph: nodes are circles with radius `20 + centrality_score × 20`; red fill if centrality > 0.5, blue otherwise
- Centrality table: per-node score with CRITICAL/NOMINAL badge (threshold 0.5)
- Adjacency matrix: raw `inspect/2` of the matrix tuple in a monospace pre block (green text on black)
- No handle_event/3 — read-only display

### 8.4 AS-IS State

From `lib/indrajaal_web/live/prajna/topology_live.ex`:

- Assigns: `nodes` (list of strings), `edges` (list of `{s,t}` index tuples), `matrix` (opaque term), `has_cycle` (bool), `centrality` (list of floats), `node_coords` (list of `{x,y}` floats)
- SVG canvas: 500×500, edges drawn as `<line>` with arrowhead markers, nodes as `<circle>` + `<text>` labels
- Layout: 2-column grid — SVG left, analytics panel right
- Analytics panel: Cycle Detected (red/green), Node Count, Centrality table
- Adjacency Matrix: full-width pre block below 2-col grid
- No user interaction events defined

### 8.5 BDD Scenarios

```gherkin
Feature: Topology Holographic Visualizer

  Scenario: C1-TOPO-01 Page loads with SVG graph visible
    Given I navigate to "/cockpit/topology"
    Then I should see the heading "Holographic Visualizer (The Eye)"
    And I should see an SVG element with topology map

  Scenario: C2-TOPO-02 Cycle detection badge reflects state
    Given the topology has a cycle
    When the page renders
    Then the "Cycle Detected" stat should show "true" in red

  Scenario: C3-TOPO-03 High-centrality node rendered in red
    Given node "zenoh-router" has centrality score 0.72
    When the page renders
    Then that node circle should have red fill

  Scenario: C3-TOPO-04 PubSub topology update redraws graph
    Given the page is mounted
    When TopologyServer publishes a {:topology_update, new_state} event
    Then the node count should update to match new_state.nodes

  Scenario: C3-TOPO-05 Cortex correction shows flash message
    Given the page is mounted
    When a {:correction_applied, payload} message arrives
    Then I should see a flash info message "Cortex Correction Applied"
```

### 8.6 UX Flow

1. Land → SVG force-directed (circle) topology map rendered immediately from TopologyServer state
2. Node radius encodes centrality — large red nodes are high-risk
3. Check "Cycle Detected" badge in analytics panel — any cycle is an architectural hazard
4. Scan centrality table for CRITICAL-rated nodes
5. Review adjacency matrix tensor for detailed connectivity
6. Page redraws automatically when TopologyServer emits `{:topology_update, state}`

### 8.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| SVG Topology Map | SVG | — | Circular layout, arrowhead edges |
| Cycle Detected stat | Div | — | Red = cycle present |
| Node Count stat | Div | — | Integer |
| Centrality table | Table | — | Per-node score + CRITICAL/NOMINAL badge |
| Adjacency Matrix pre | Pre | — | Raw inspect output, monospace green |

### 8.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-GRAPH-001 | Graph operations — TopologyServer drives graph state |
| SC-GRAPH-004 | Cycle detection via GraphBLAS |
| SC-SIL4-008 | DAG validation: has_cycle=true is a safety violation to investigate |
| SC-BOOT-008 | DAG acyclic verified — topology page surfaces violations visually |
| SC-HMI-002 | Trend vectors — centrality scores displayed per node |

### 8.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| TopologyServer.get_state/0 raises (not started) → mount crashes | 7 | 3 | 2 | 42 | No rescue in mount; TopologyServer supervisor must ensure availability |
| Zero nodes returned → SVG empty, misleads operator | 5 | 3 | 5 | 75 | Show "No topology data" placeholder when nodes list is empty |
| calculate_circle_layout with n=0 → division by zero | 8 | 2 | 2 | 32 | Guard `n > 0` before angle_step calculation |
| Centrality list shorter than nodes list → Enum.at returns nil → Float.round crash | 7 | 2 | 3 | 42 | Ensure GraphBLAS always returns matching-length centrality list |

---

## 9. Prometheus

### 9.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/prometheus` |
| Module | `IndrajaalWeb.Prajna.PrometheusLive` |
| File | `lib/indrajaal_web/live/prajna/prometheus_live.ex` |
| Title | PROMETHEUS Verification |
| Tier | P2 Infrastructure |

### 9.2 Design Intent

Provides operators a window into the PROMETHEUS Formal Verification Engine — the gatekeeper that ensures all mutations pass SIL-6 proofs before activation. Displays total verification count, average latency, constraint health (active/total ratio), the list of active STAMP constraints, and a ledger of recent verification events from the Immutable Register.

### 9.3 Expected Behavior (Functional)

- Mount: assigns static initial state (verification_count=0, hardcoded active_constraints list, empty recent_activity)
- Timer `:update_stats` (1 000ms): intended to poll real data from verification engine (current implementation increments a counter — stub)
- No PubSub subscriptions yet (comment in source: "In a real impl, we would subscribe to Phoenix.PubSub here")
- Active constraints table: hardcoded three constraints — SC-PROM-001, SC-PROM-004, SC-GVF-003 — each shown with green VERIFIED badge
- Verification ledger: empty in current implementation (recent_activity list is never populated)
- 3-column header metrics: Total Verifications (counter), Average Latency (4.2ms hardcoded), Constraint Health (length/242)
- SIL-6 status indicator: green pulsing dot + "SIL-6: HOMEOSTASIS" in header

### 9.4 AS-IS State

From `lib/indrajaal_web/live/prajna/prometheus_live.ex`:

- `@impl handle_info :update_stats` clause NOT present in the read source — timer is configured but no handler shown (stub)
- Assigns: `verification_count` (integer, starts 0), `last_proof` (nil), `active_constraints` (list of 3 maps with id/status/description), `recent_activity` (empty list)
- Layout: full-width max-7xl container with top header, 3 KPI cards, active constraints card, verification ledger card
- No `handle_event/3` clauses
- Average latency "4.2ms" hardcoded; constraint total "242" hardcoded
- Page title: "PROMETHEUS Verification" with `◈` icon in purple

### 9.5 BDD Scenarios

```gherkin
Feature: PROMETHEUS Formal Verification Dashboard

  Scenario: C1-PROM-01 Page structure renders on load
    Given I navigate to "/cockpit/prometheus"
    Then I should see the heading "PROMETHEUS"
    And I should see a "Total Verifications" metric card
    And I should see a "SIL-6: HOMEOSTASIS" status indicator

  Scenario: C2-PROM-02 Active constraints shown as VERIFIED
    When I navigate to "/cockpit/prometheus"
    Then I should see constraint "SC-PROM-001" with badge "VERIFIED"
    And I should see constraint "SC-PROM-004" with badge "VERIFIED"
    And I should see constraint "SC-GVF-003" with badge "VERIFIED"

  Scenario: C2-PROM-03 Constraint health ratio displayed
    When I navigate to "/cockpit/prometheus"
    Then I should see "3/242" in the Constraint Health card

  Scenario: C3-PROM-04 Verification count increments over time
    Given I navigate to "/cockpit/prometheus"
    When 2 seconds elapse
    Then the Total Verifications count should be greater than 0

  Scenario: C3-PROM-05 Verification ledger section is visible
    When I navigate to "/cockpit/prometheus"
    Then I should see a "Verification Ledger (Immutable Register)" section
```

### 9.6 UX Flow

1. Land → header with purple `◈` icon, SIL-6 homeostasis indicator
2. Scan 3 KPI cards: total verifications, average latency (target <10ms), constraint health
3. Active Constraints section: each constraint in STAMP format with green VERIFIED badge
4. Verification Ledger: intended to show immutable register entries for each verification event
5. Page auto-refreshes via 1s timer (counter increments only in current stub implementation)

### 9.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Total Verifications card | Div | — | Integer counter |
| Average Latency card | Div | — | Hardcoded 4.2ms |
| Constraint Health card | Div | — | `length/242` format |
| SIL-6 status dot | Div | — | Green pulsing circle |
| Active constraint row | Div | — | STAMP ID + description + VERIFIED badge |
| Verification Ledger section | Div | — | Empty list in current impl |

### 9.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-PROM-001 | Proof Requirement — all mutations must pass before activation |
| SC-PROM-004 | DAG Acyclicity — topology must remain acyclic |
| SC-GVF-003 | OpenRouter Exclusivity — external model access constraint |
| SC-VER-002 | Verification failure halts system |
| SC-VER-004 | Verification < 100ms |

### 9.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Counter increments but no real data — misleads operator about true verification count | 6 | 5 | 4 | 120 | Stub implementation must be replaced with real VerificationEngine query |
| Average latency hardcoded 4.2ms — hides actual performance degradation | 7 | 5 | 5 | 175 | Wire to real OTEL span duration metrics |
| Verification ledger empty — no audit trail visible | 5 | 5 | 4 | 100 | Integrate with ImmutableRegister.list_recent/1 |
| SIL-6 badge always shows HOMEOSTASIS — no alarm on breach | 9 | 3 | 5 | 135 | Wire badge to real SIL-4 health check result |

---

## 10. Access Control

### 10.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/access-control` |
| Module | `IndrajaalWeb.Prajna.AccessControlLive` |
| File | `lib/indrajaal_web/live/prajna/access_control_live.ex` |
| Title | Access Control Center |
| Tier | P2 Infrastructure |

### 10.2 Design Intent

Real-time permission audit and policy effectiveness monitoring for the RBAC/ABAC access control subsystem. Provides security operators with a live audit trail, policy effectiveness metrics, grant pattern visualization, role hierarchy status, and anomaly detection. Bridges to Sentinel via PubSub for threat advisory integration.

### 10.3 Expected Behavior (Functional)

- Mount: initializes permissions, policies, grant_patterns, audit_trail from private `init_*` helpers; anomalies empty; filter defaults (all, all, last_1h)
- Refresh timer (5 000ms): reloads permissions, refreshes audit_trail, re-runs `detect_anomalies/1`
- Metrics sync timer (10 000ms): calls `fetch_access_metrics/0` → updates metrics assign (SmartMetrics integration deferred)
- PubSub `prajna:access_control` and `zenoh:access_control`: `{:pubsub, :permission_change, data}` updates permissions list and prepends to audit_trail
- Filter events: `filter_action`, `filter_resource`, `filter_timerange` → update filter assigns (String.to_existing_atom)
- Search event: `search` → updates `search_query` assign (used client-side filter)
- `select_permission` → loads matching permission into `selected_permission` for detail panel
- `close_detail` → sets `selected_permission` to nil
- Anomaly detection: when anomalies list has > 0 items, card border turns red
- Denials count > 50 → yellow warning border on denials card

### 10.4 AS-IS State

From `lib/indrajaal_web/live/prajna/access_control_live.ex`:

- `@refresh_interval 5000`, `@metrics_sync_interval 10_000`
- PubSub: `prajna:access_control`, `zenoh:access_control`
- Assigns: `permissions`, `policies`, `grant_patterns`, `audit_trail`, `anomalies`, `filter_action` (:all), `filter_resource` (:all), `filter_timerange` (:last_1h), `search_query`, `selected_permission` (nil), `metrics`
- Layout: 4-column metrics row, 2-column main grid (audit trail left, policies right), optional detail panel
- Filter controls: action select (all/grant/deny/revoke), timerange select (last_15m/last_1h/last_24h)
- Audit trail: max 20 entries shown after filter
- SmartMetrics note in source: "integration deferred to Sprint 31"

### 10.5 BDD Scenarios

```gherkin
Feature: Access Control Center

  Scenario: C1-ACC-01 Page structure renders on load
    Given I navigate to "/cockpit/access-control"
    Then I should see the heading "Access Control Center"
    And I should see 4 metric cards
    And I should see the "Real-Time Audit Trail" panel

  Scenario: C2-ACC-02 Denials threshold triggers warning border
    Given the system has 75 access denials in the last hour
    When the metrics refresh
    Then the "Access Denials" card should have a yellow border

  Scenario: C2-ACC-03 Anomaly detection turns card red
    Given anomaly detection finds a suspicious pattern
    When the :refresh message arrives
    Then the "Anomalies Detected" card should have a red border

  Scenario: C5-ACC-04 Filter by action updates audit trail
    When I select "Denials" from the action filter
    Then the audit trail should show only deny-action entries

  Scenario: C5-ACC-05 Clicking a permission opens detail panel
    Given the permission list has entries
    When I click on a permission row
    Then a detail panel should appear with permission details
    When I click "close_detail"
    Then the detail panel should be dismissed
```

### 10.6 UX Flow

1. Land → 4 KPI cards: Active Permissions, Policy Effectiveness %, Access Denials (1h), Anomalies Detected
2. Spot yellow/red alert borders on KPI cards for threshold breaches
3. Audit trail panel (left): filter by action type and time range; scan recent entries
4. Policies panel (right): review active policies and effectiveness scores
5. Click on a permission row → detail panel opens with full RBAC/ABAC context
6. Close detail → return to main view
7. Page auto-refreshes every 5s; metrics every 10s

### 10.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| Active Permissions card | Div | — | Integer metric |
| Policy Effectiveness card | Div | — | Percentage |
| Access Denials (1h) card | Div | — | Yellow border if >50 |
| Anomalies Detected card | Div | — | Red border if >0 |
| Action filter select | Select | `filter_action` | all/grant/deny/revoke |
| Time range filter select | Select | `filter_timerange` | last_15m/last_1h/last_24h |
| Resource filter select | Select | `filter_resource` | all + resource types |
| Search input | Input | `search` | Debounce recommended |
| Audit trail row | Div | `select_permission` | phx-value-id |
| Close detail button | Button | `close_detail` | Dismisses side panel |

### 10.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-001 | Dark Cockpit — gray default surface colors |
| SC-PRAJNA-004 | Sentinel health integration via SentinelBridge |
| SC-BRIDGE-005 | PubSub topics: `zenoh:access_control` |
| SC-SEC-044 | Security-sensitive data handling — no credentials in assigns |
| SC-AUTH-001 | Authentication audit trail maintained |
| SC-AUTHZ-001 | Authorization policy effectiveness tracked |

### 10.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| init_permissions returns stub data — operator has false confidence | 6 | 4 | 4 | 96 | Replace with real RBAC domain queries before P0 deployment |
| detect_anomalies always returns [] — threats invisible | 8 | 3 | 5 | 120 | Wire detect_anomalies to real pattern matching engine |
| String.to_existing_atom on unknown filter value crashes | 7 | 2 | 2 | 28 | Guard with `String.to_atom` or validate input set |
| Audit trail capped at 20 entries — misses high-volume attacks | 5 | 3 | 4 | 60 | Paginate or load more on demand |

---

## 11. Video

### 11.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/video` |
| Module | `IndrajaalWeb.Prajna.VideoLive` |
| File | `lib/indrajaal_web/live/prajna/video_live.ex` |
| Title | Video Analytics Center |
| Tier | P2 Infrastructure |

### 11.2 Design Intent

Real-time video stream health and AI detection analytics dashboard. Provides operators with a per-stream grid (active/degraded/offline), AI detection accuracy, frame drop and latency monitoring, and inference performance metrics. Has full graceful degradation: if the video service is unavailable at mount, an error banner is shown and all assigns initialize to safe empty values.

### 11.3 Expected Behavior (Functional)

- Mount: wraps all initialization in try/rescue; on failure assigns `error: "Video service is currently unavailable"` and empty lists
- Refresh timer (2 000ms): refreshes stream status and detections via private helpers
- Metrics sync timer (5 000ms): calls `fetch_video_metrics/0` (SmartMetrics integration deferred)
- PubSub `prajna:video` and `zenoh:video`: subscribed but no specific handler (catches with `handle_info(_msg, socket)` passthrough)
- `filter_status`: updates `filter_status` assign (all/active/degraded/offline)
- `select_stream`: finds stream by ID → assigns to `selected_stream` for detail panel
- `close_detail`: sets `selected_stream` to nil
- Latency threshold: avg_latency > 100ms → yellow warning border on latency card
- Frame drops threshold: frame_drops > 10 → yellow warning border on frame drops card
- Error banner: shown when `@error` is not nil; yellow warning styling

### 11.4 AS-IS State

From `lib/indrajaal_web/live/prajna/video_live.ex`:

- `@refresh_interval 2000`, `@metrics_sync_interval 5000`
- PubSub: `prajna:video`, `zenoh:video`
- Assigns: `video_streams`, `detections`, `filter_status` (:all), `filter_type` (:all), `selected_stream` (nil), `metrics`, `error` (nil or string)
- Layout: 5-column metrics row (Active Streams, Avg Latency, Detection Rate/min, Accuracy %, Frame Drops), 3-column grid (streams panel, detections panel, inference panel)
- Stream grid: 3-col within the streams panel; each stream tile has `📹` emoji, stream name, status dot
- SC-VID-001: stream latency < 100ms enforced via yellow border warning

### 11.5 BDD Scenarios

```gherkin
Feature: Video Analytics Center

  Scenario: C1-VID-01 Page structure renders on load
    Given I navigate to "/cockpit/video"
    Then I should see the heading "Video Analytics Center"
    And I should see 5 metric cards

  Scenario: C2-VID-02 Error banner shown when video service unavailable
    Given the video service throws an exception during mount
    When I navigate to "/cockpit/video"
    Then I should see an error banner "Video service is currently unavailable"

  Scenario: C2-VID-03 Latency threshold triggers yellow border
    Given the video metrics show avg_latency = 150ms
    When the metrics sync refreshes
    Then the "Avg Latency" card should have a yellow border

  Scenario: C5-VID-04 Filter dropdown changes stream list
    When I select "Degraded" from the status filter
    Then only degraded streams should appear in the streams panel

  Scenario: C5-VID-05 Clicking a stream tile opens detail panel
    Given the video_streams list has at least one stream
    When I click on a stream tile
    Then a detail panel should appear with stream details
    When I click "close_detail"
    Then the detail panel should be dismissed
```

### 11.6 UX Flow

1. Land → optional error banner if video service unavailable
2. 5 KPI cards: Active Streams, Avg Latency (yellow if >100ms), Detection Rate/min, Accuracy%, Frame Drops (yellow if >10)
3. Streams panel (1/3 col): grid of stream tiles with status dot; filter by status
4. Detections panel (1/3 col): recent AI detection events
5. Inference panel (1/3 col): AI model performance metrics
6. Click stream tile → detail panel shows stream health detail
7. Page auto-refreshes every 2s (streams/detections) and 5s (metrics)

### 11.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| Error banner | Div | — | Yellow warning; shown when @error truthy |
| Active Streams card | Div | — | Integer |
| Avg Latency card | Div | — | Yellow if >100ms |
| Detection Rate card | Div | — | Events per minute |
| Accuracy card | Div | — | Percentage |
| Frame Drops card | Div | — | Yellow if >10 |
| Status filter select | Select | `filter_status` | all/active/degraded/offline |
| Stream tile | Div | `select_stream` | phx-value-id; status dot color |
| Close detail button | Button | `close_detail` | Dismisses stream detail panel |

### 11.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-001 | Dark Cockpit default styling |
| SC-PRAJNA-004 | Sentinel health integration required |
| SC-BRIDGE-005 | PubSub topics: `zenoh:video` |
| SC-VID-001 | Stream latency < 100ms (enforced via yellow border alert) |
| SC-VIDEO-001 | Video MCP handler integration |

### 11.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Video service unavailable at mount → graceful degradation with error banner | 4 | 3 | 1 | 12 | try/rescue in mount already handles this |
| init_streams returns stub data — no real camera feeds | 5 | 4 | 4 | 80 | Wire to real video pipeline before operational deployment |
| Latency threshold check uses stale 5s sync interval — burst spikes missed | 5 | 3 | 4 | 60 | Reduce metrics sync interval or listen directly on PubSub |
| filter_type assign unused in current render — dead assign | 2 | 5 | 3 | 30 | Remove or implement filter_type handler to avoid confusion |

---

## P3 ADMIN PAGES

---

## 12. Prajna Dashboard

### 12.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit` and `/cockpit/dashboard` |
| Module | `IndrajaalWeb.PrajnaLive` |
| File | `lib/indrajaal_web/live/prajna_live.ex` |
| Title | PRAJNA C3I Cockpit |
| Tier | P3 Admin (primary entry point) |

### 12.2 Design Intent

Primary operational dashboard implementing NASA-STD-3000 Dark Cockpit philosophy for single-glance system awareness. Every metric displayed has a threshold — silence means safe. Operators scan: health score, safety system status, mesh node grid, active alarms, AI copilot insights, container health, and OODA cycle status. Critical commands require arm→confirm two-step commit. Version 2.0.0.

### 12.3 Expected Behavior (Functional)

- Mount: initializes nodes, containers, alarms, insights, safety, ooda from private `init_*` helpers; `armed_command` nil; `command_countdown` 300
- Refresh timer (500ms): runs `update_metrics/1`, `update_ooda/1`, `update_command_countdown/1`
- PubSub via `Messaging` module: `:metrics`, `:alarms`, `:insights`, `:ooda` channels
- `{:metric_updated, node_id, type, value}` → `update_metrics/1`
- `{:alarm_raised, alarm_id, level, message}` → `update_alarms/1`
- `{:insight_generated, type, content, confidence}` → `update_insights/0`
- `{:ooda_phase_changed, phase, cycle_ms}` → updates OODA phase assign
- `ack_alarm` event: marks alarm.acknowledged = true
- `dismiss_insight` event: removes insight from list
- `arm_command` event: sets `armed_command` map (node, command, armed_at, armed_by), starts 300-tick countdown
- `confirm_command` event: executes command (simulated), clears armed_command, flash info
- `cancel_command` event: clears armed_command
- Demo data: 5 fixed nodes (@demo_nodes), 3 containers (@demo_containers)

### 12.4 AS-IS State

From `lib/indrajaal_web/live/prajna_live.ex`:

- `@refresh_interval 500` (500ms — fastest in the system)
- Assigns: `health_score` (94), `uptime`, `started_at`, `nodes`, `containers`, `alarms`, `insights`, `safety`, `ooda`, `armed_command` (nil), `command_countdown` (300)
- Layout: `<.prajna_header>` (health_score, uptime, node_count, total_nodes, alarm_count), `<.prajna_nav>` (current nav), safety status bar, mesh node grid, alarm panel, insights panel, OODA cycle display
- Two-step commit: arm_command → confirm_command or cancel_command pattern (SC-HMI-004)
- Safety struct: guardian, dms, envelope, sentinel, sentinel_total, violations fields

### 12.5 BDD Scenarios

```gherkin
Feature: PRAJNA C3I Main Dashboard

  Scenario: C1-DASH-01 Page structure renders on load
    Given I navigate to "/cockpit"
    Then I should see the prajna header with health score
    And I should see the navigation tabs
    And I should see the safety status bar

  Scenario: C2-DASH-02 Health score displayed prominently
    When I navigate to "/cockpit"
    Then I should see health score "94" in the header

  Scenario: C5-DASH-03 Two-step command arm and confirm
    Given I am on the dashboard
    When I click "arm_command" for node "app-01" command "restart"
    Then the armed command panel should appear with countdown
    When I click "confirm_command"
    Then I should see a flash "Command executed"
    And the armed command panel should be dismissed

  Scenario: C5-DASH-04 Cancel command cancels armed state
    Given an armed command is active
    When I click "cancel_command"
    Then the armed command panel should be dismissed
    And no command should have been executed

  Scenario: C8-DASH-05 Acknowledge alarm removes alert state
    Given there is an active unacknowledged alarm
    When I click "ack_alarm" for that alarm
    Then the alarm should show as acknowledged
```

### 12.6 UX Flow

1. Land → header with health score % + uptime + node count + alarm count
2. Safety status bar: Guardian / DMS / Envelope / Sentinel status at a glance
3. Mesh node grid: per-node CPU / Memory / Latency with color coding
4. Active alarms panel: click `ack_alarm` to acknowledge
5. AI Copilot insights panel: click `dismiss_insight` to dismiss
6. OODA cycle display: current phase + cycle time in ms
7. For critical commands: click arm → review countdown → confirm or cancel
8. Page refreshes every 500ms — fastest refresh in the system

### 12.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Prajna header | Component | — | health_score, uptime, node_count |
| Prajna nav | Component | — | Tab switching |
| Safety status bar | Component | — | guardian/dms/envelope/sentinel |
| Mesh node grid | Component | — | Per-node metrics |
| Alarm row | Div | `ack_alarm` | phx-value-id={alarm.id} |
| Insight card | Div | `dismiss_insight` | phx-value-id={insight.id} |
| Arm command button | Button | `arm_command` | phx-value-node, phx-value-command |
| Confirm command button | Button | `confirm_command` | Only shown when armed |
| Cancel command button | Button | `cancel_command` | Only shown when armed |

### 12.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-001 | Dark Cockpit — gray/blue default, amber/red for deviations |
| SC-HMI-002 | Trend vectors — health score and OODA cycle time trends |
| SC-HMI-003 | Staleness visual decay after 5s (metric freshness indicators) |
| SC-HMI-004 | Two-step commit UI for arm_command → confirm_command |
| SC-HMI-008 | Contrast ratio minimum 4.5:1 |
| SC-PRF-050 | Updates < 50ms latency (500ms timer interval) |

### 12.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Demo nodes/containers — not real production data | 7 | 5 | 4 | 140 | Replace @demo_nodes with real TopologyServer.get_nodes/0 |
| armed_command never expires without confirm/cancel → stuck UI | 5 | 3 | 4 | 60 | command_countdown decrements every 500ms — at 0, auto-cancel |
| 500ms refresh with no PubSub rate-limiting → high BEAM load | 4 | 3 | 3 | 36 | Profile under load; consider reducing to 1s if healthy |
| ack_alarm only marks local assign — no persistence | 6 | 4 | 4 | 96 | Wire to real Alarm.acknowledge/1 domain call |

---

## 13. Guardian Dashboard

### 13.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/guardian` |
| Module | `IndrajaalWeb.Prajna.GuardianDashboardLive` |
| File | `lib/indrajaal_web/live/prajna/guardian_dashboard_live.ex` |
| Title | Guardian - Governance Center |
| Tier | P3 Admin |

### 13.2 Design Intent

Provides operators visibility into Guardian governance — the constitutional gatekeeper that approves or vetoes all system mutations. Tracks proposals approved, proposals vetoed, pending operations awaiting decision, and circuit breaker state. The circuit breaker (closed/half-open/open) protects against cascading governance failures.

### 13.3 Expected Behavior (Functional)

- Mount: initializes all counts to 0, empty lists, `circuit_breaker: :closed`
- Refresh timer (5 000ms): calls `refresh_data/1` which currently only updates `last_update` timestamp
- No PubSub subscriptions in current implementation
- No `handle_event` clauses — read-only display
- Circuit breaker color: closed=green, half_open=yellow, open=red, unknown=gray
- Recent Decisions panel: currently shows "No recent decisions" placeholder

### 13.4 AS-IS State

From `lib/indrajaal_web/live/prajna/guardian_dashboard_live.ex`:

- `@impl handle_info :refresh` only updates `last_update` (stub implementation — no real Guardian queries)
- Assigns: `proposals_approved` (0), `proposals_vetoed` (0), `pending_operations` ([]), `circuit_breaker` (:closed), `recent_decisions` ([]), `last_update` (DateTime)
- Layout: 4-column KPI grid (Approved=green, Vetoed=red, Pending=yellow, Circuit Breaker=color), Recent Decisions panel, last_update timestamp footer
- STAMP: SC-PRAJNA-001, SC-CONST-007, SC-GDE-001

### 13.5 BDD Scenarios

```gherkin
Feature: Guardian Governance Dashboard

  Scenario: C1-GUARD-01 Page structure renders on load
    Given I navigate to "/cockpit/guardian"
    Then I should see the heading "Guardian - Governance Center"
    And I should see 4 KPI cards

  Scenario: C2-GUARD-02 Approved count shown in green
    When I navigate to "/cockpit/guardian"
    Then the "Approved" card should show "0" in green

  Scenario: C2-GUARD-03 Circuit breaker state color coded
    Given circuit_breaker is :closed
    When the page renders
    Then the Circuit Breaker card should show ":closed" in green text

  Scenario: C3-GUARD-04 Last update refreshes every 5 seconds
    Given I navigate to "/cockpit/guardian"
    When 5 seconds elapse
    Then the "Last update" timestamp should have advanced

  Scenario: C3-GUARD-05 No recent decisions placeholder shown
    When I navigate to "/cockpit/guardian"
    Then I should see text "No recent decisions" in the decisions panel
```

### 13.6 UX Flow

1. Land → 4 KPI cards: Approved (green), Vetoed (red), Pending (yellow), Circuit Breaker (color coded)
2. Circuit breaker state is the critical safety indicator — open state means governance is blocked
3. Recent Decisions panel: scrollable history of Guardian approve/veto events
4. Last update timestamp confirms data freshness (5s refresh)
5. No operator interaction — pure monitoring dashboard

### 13.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Approved card | Div | — | Integer, green text |
| Vetoed card | Div | — | Integer, red text |
| Pending card | Div | — | `length(pending_operations)`, yellow text |
| Circuit Breaker card | Div | — | Color via cb_color/1 helper |
| Recent Decisions panel | Div | — | Currently shows placeholder |
| Last update footer | Span | — | Formatted datetime |

### 13.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-PRAJNA-001 | Guardian pre-approval required for planning mutations |
| SC-CONST-007 | Constitutional integrity monitored |
| SC-GDE-001 | Guardian validation required — this page displays the result |
| SC-GDE-002 | Shadow testing mandatory — circuit breaker tracks test failures |
| SC-GDE-003 | Rollback capability — vetoed proposals trigger rollback |

### 13.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| All counters start at 0 and never update — stub implementation | 7 | 5 | 4 | 140 | Wire refresh_data/1 to real Guardian.get_stats/0 |
| Circuit breaker stuck at :closed even when Guardian is failing | 9 | 3 | 5 | 135 | Subscribe to `guardian:state` PubSub topic |
| recent_decisions always empty — no audit trail visible | 6 | 5 | 4 | 120 | Load from Guardian decision log or Immutable Register |
| No PubSub subscription — page deaf to real-time Guardian events | 7 | 5 | 3 | 105 | Add subscribe to `guardian:decisions` channel |

---

## 14. Health Sparkline

### 14.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/health-sparklines` |
| Module | `IndrajaalWeb.Prajna.HealthSparklineLive` |
| File | `lib/indrajaal_web/live/prajna/health_sparkline_live.ex` |
| Title | System Health — Sparklines |
| Tier | P3 Admin |

### 14.2 Design Intent

Provides a 60-second rolling window visual health trend for all nodes using native SVG sparklines (no JavaScript charting dependency). Operators can spot degradation before threshold breach through pattern recognition. Covers CPU, Memory, Queue Depth, and Response Latency with per-node breakdown and aggregate view. Alert thresholds are configurable per metric.

### 14.3 Expected Behavior (Functional)

- Mount: initializes `metric_history` (60-point rolling buffer), `node_metrics`, `system_summary`, `selected_node` (:aggregate), `alert_thresholds`
- Refresh timer (5 000ms): `advance_history/1` pushes synthetic data point into rolling window
- Metrics sync timer (30 000ms): `fetch_live_metrics/0` → updates `node_metrics` and recomputes `system_summary`
- PubSub `prajna:metrics`: `{:metrics_update, metrics}` → `push_metrics_sample/2` into rolling window
- PubSub `zenoh:health`: `{:node_health, node_id, health}` → `Map.update` on node_metrics
- PubSub `prajna:health`: caught by `handle_info(_msg, socket)` passthrough
- `select_node` event: switches `selected_node` assign between `:aggregate` and node IDs
- `set_threshold` event: parses float threshold for named metric → updates `alert_thresholds` map
- SVG sparklines: `@sparkline_points 60`, `@sparkline_width 200`, `@sparkline_height 40`; rendered as SVG polyline using `IndrajaalWeb.PrajnaComponents`
- System summary: health_score (%) and trend indicator (improving/stable/degrading)
- Trend badge: color-coded label based on trend enum

### 14.4 AS-IS State

From `lib/indrajaal_web/live/prajna/health_sparkline_live.ex`:

- `@refresh_interval 5_000`, `@metrics_interval 30_000`, `@sparkline_points 60`, `@sparkline_width 200`, `@sparkline_height 40`
- PubSub: `prajna:metrics`, `zenoh:health`, `prajna:health`
- Assigns: `metric_history`, `node_metrics`, `system_summary`, `selected_node` (:aggregate), `alert_thresholds`, `last_update`, `sparkline_width`, `sparkline_height`
- `import IndrajaalWeb.PrajnaComponents` for sparkline rendering helpers
- Layout: prajna_header + prajna_nav, header row with trend badge + health %, 4-column system summary cards, node selector tabs, per-metric sparkline rows
- System summary cards for 4 metrics: rendered with metric_key, label, unit params

### 14.5 BDD Scenarios

```gherkin
Feature: System Health Sparklines Dashboard

  Scenario: C1-SPARK-01 Page structure renders on load
    Given I navigate to "/cockpit/health-sparklines"
    Then I should see the heading "System Health — Sparklines"
    And I should see 4 system summary cards
    And I should see SVG sparkline charts

  Scenario: C2-SPARK-02 Health score and trend badge visible
    When I navigate to "/cockpit/health-sparklines"
    Then I should see a "Health" percentage value
    And I should see a trend badge (Improving/Stable/Degrading)

  Scenario: C3-SPARK-03 Rolling window advances on refresh
    Given the page is mounted and connected
    When 5 seconds elapse
    Then the last_update timestamp should have advanced
    And the sparkline data should have a new point prepended

  Scenario: C5-SPARK-04 Select node switches sparkline view
    Given the page shows aggregate metrics
    When I click "select_node" with node "app-01"
    Then the sparklines should show metrics for node app-01 only

  Scenario: C5-SPARK-05 Set threshold updates alert configuration
    When I submit "set_threshold" for metric "cpu" with value "85"
    Then the cpu alert threshold should be 85.0
    And sparkline threshold line should update
```

### 14.6 UX Flow

1. Land → prajna header + nav, trend badge (improving/stable/degrading) + health score %
2. 4 summary cards (CPU, Memory, Queue Depth, Response Latency) with current values
3. Node selector tabs: aggregate + individual node IDs
4. Sparkline rows: 60-point SVG polyline per metric; rolling left as time advances
5. Threshold lines overlaid on sparklines; alert if current exceeds threshold
6. Set threshold input per metric → immediate reconfiguration
7. Page data advances every 5s; full metrics sync every 30s

### 14.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| Trend badge | Span | — | improving/stable/degrading color |
| Health score | Span | — | Percentage, color-coded |
| System summary card | Div | — | 4 metrics with label + unit |
| Node selector tab | Button | `select_node` | phx-value-node="aggregate"|"app-01" etc. |
| Sparkline SVG | SVG | — | 200×40 native SVG polyline |
| Threshold input | Input | `set_threshold` | phx-value-metric, float value |
| Last update label | Span | — | HH:MM:SS UTC |

### 14.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-MON-001 | Metrics refresh every 30s (30s sync timer) |
| SC-MON-002 | Infrastructure metrics complete (CPU/Memory/Queue/Latency) |
| SC-MON-004 | Safety metrics mandatory (threshold breach detection) |
| SC-MON-005 | Dashboard data available at all times |
| SC-PRF-050 | Response < 50ms (SVG rendering must complete within budget) |
| SC-BRIDGE-005 | PubSub topics: prajna:metrics, zenoh:health |
| SC-HMI-001 | Dark Cockpit — surface-primary background, font-mono |

### 14.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| advance_history generates synthetic data — not real BEAM metrics | 5 | 4 | 4 | 80 | Wire fetch_live_metrics to :erlang.memory(), :erlang.statistics/1 |
| 60 sparkline points × 4 metrics × N nodes — potential memory growth | 4 | 3 | 4 | 48 | Fixed 60-point ring buffer; ensure advance_history drops oldest |
| SVG polyline with empty metric_history crashes renderer | 5 | 3 | 3 | 45 | Guard: render empty rect if history empty |
| set_threshold with invalid float silently ignored — confuses operator | 3 | 3 | 5 | 45 | Flash error message on Float.parse :error branch |

---

## 15. Zenoh Mesh Health

### 15.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/zenoh/mesh-health` (inferred from navigation portal) |
| Module | Not found in codebase |
| File | File does not exist — `lib/indrajaal_web/live/zenoh/` directory absent |
| Title | Zenoh Mesh Health |
| Tier | P3 Admin |

### 15.2 Design Intent

Intended to provide real-time Zenoh mesh connectivity health monitoring: session state, router reachability, subscriber counts, topic publication rates, and inter-node latency. Per SC-ZENOH-007, Zenoh health must be included in the `/health` endpoint; this page extends that to a full visual dashboard for operators.

### 15.3 Expected Behavior (Functional — Designed Intent)

- Mount: queries ZenohTelemetrySubscriber or NIF bridge for session state
- Timer (10 000ms expected): polls Zenoh router reachability and session metrics
- PubSub: subscribes to `zenoh:mesh` or `zenoh:health` for live updates
- Displays: session_id, router endpoint, connected (boolean), subscriptions count, publications_per_sec
- Per-topic health table: key expression, last_received, message_rate, subscriber_count
- Node reachability matrix: which nodes can reach which via Zenoh
- No user-triggered mutations — read-only monitoring

### 15.4 AS-IS State

File `lib/indrajaal_web/live/zenoh/zenoh_mesh_health_live.ex` **does not exist** in the codebase. The `/zenoh/mesh-health` route is referenced in the navigation portal but has no implementation. This is a known gap in the P3 Admin page coverage.

### 15.5 BDD Scenarios

```gherkin
Feature: Zenoh Mesh Health Dashboard (Designed Intent)

  Scenario: C1-ZENOH-01 Page structure renders on load
    Given the /zenoh/mesh-health route is implemented
    When I navigate to "/zenoh/mesh-health"
    Then I should see the heading "Zenoh Mesh Health"
    And I should see a session status indicator

  Scenario: C2-ZENOH-02 Connected status shown in green
    Given Zenoh router is reachable
    When I navigate to "/zenoh/mesh-health"
    Then the session status should show "connected" in green

  Scenario: C2-ZENOH-03 Disconnected state shows alert
    Given Zenoh router is unreachable
    When I navigate to "/zenoh/mesh-health"
    Then the session status should show "disconnected" in red

  Scenario: C3-ZENOH-04 Per-topic publication rates displayed
    Given Zenoh is publishing to 14+ topics
    When the page refreshes
    Then each topic should show its message rate per second

  Scenario: C3-ZENOH-05 Node reachability matrix rendered
    Given the mesh has 4 containers
    When the page renders
    Then a 4×4 reachability matrix should be visible
```

### 15.6 UX Flow (Designed)

1. Land → session status card (connected/disconnected), router endpoint, session ID
2. Per-topic health table: 14+ Zenoh topics with last_received timestamp and rate
3. Node reachability matrix: color-coded grid showing which nodes can communicate
4. Subscription count and publication rate KPIs
5. Auto-refresh (expected 10s interval)

### 15.7 UI Elements Inventory (Designed)

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Session status card | Div | — | connected/disconnected |
| Router endpoint | Span | — | `tcp/zenoh-router:7447` |
| Topic health row | Div | — | Per topic rate + last seen |
| Reachability matrix | Table | — | N×N boolean grid |
| Subscriptions count | Div | — | Integer |
| Publications/sec | Div | — | Float |

### 15.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-ZENOH-001 | Zenoh NIF MUST be loaded on ALL nodes |
| SC-ZENOH-002 | Zenoh router MUST be reachable from ALL app nodes |
| SC-ZENOH-003 | ZenohTelemetrySubscriber MUST be connected |
| SC-ZENOH-007 | Zenoh health included in /health endpoint — page extends this |
| SC-ZENOH-008 | Container MUST NOT start if Zenoh unavailable |

### 15.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Page does not exist — operators have no Zenoh mesh visibility | 7 | 5 | 1 | 35 | Implement ZenohMeshHealthLive as P1 task |
| Route registered but no LiveView module → 500 error | 8 | 5 | 1 | 40 | Remove route or implement module |
| Zenoh NIF unavailable → page crashes on mount | 7 | 2 | 2 | 28 | try/rescue with graceful error banner |

---

## 16. Knowledge: Developer

### 16.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/knowledge/developer` |
| Module | `IndrajaalWeb.Prajna.Knowledge.DeveloperLive` |
| File | `lib/indrajaal_web/live/prajna/knowledge/developer_live.ex` |
| Title | Developer Knowledge |
| Tier | P3 Admin |

### 16.2 Design Intent

Developer-centric knowledge management following cognitive load theory for optimal engineering decision making. Provides developers with: code-to-knowledge links (file ↔ holon mappings), decision records (ADRs, RFCs, Tech Specs), design patterns library with usage statistics, debug session history, and code review insights. Backed by the KMS Developer module (SQLite/DuckDB).

### 16.3 Expected Behavior (Functional)

- Mount: loads all four data categories from `Indrajaal.KMS.Developer`; sets view_mode :decisions, filter_status :all, search_query "", selected_item nil
- Refresh timer (10 000ms): reloads decisions and patterns
- PubSub `prajna:kms:developer`: `{:developer_event, event}` → reloads decisions
- `switch_view` event: switches between :decisions, :patterns, :debug, :links
- `select_item` event: loads item by type (decision/pattern/debug) + id → assigns `selected_item`; type prepended to map
- `search` event (debounce 300ms): updates `search_query` assign; used to filter all views
- `filter_status` event: updates `filter_status` (all/proposed/accepted/deprecated); decisions view only
- `use_pattern` event: calls `Developer.use_pattern(id)` → flash info + reload patterns, or flash error
- Detail panel: shown in aside when `selected_item` is non-nil; displays decision fields or pattern example_code
- Decision status colors: proposed=blue, accepted=green, deprecated=yellow, superseded=gray

### 16.4 AS-IS State

From `lib/indrajaal_web/live/prajna/knowledge/developer_live.ex`:

- `@refresh_interval 10_000`
- PubSub: `prajna:kms:developer`
- Assigns: `view_mode` (:decisions), `decisions`, `patterns`, `debug_sessions`, `code_links`, `selected_item` (nil), `search_query` (""), `filter_status` (:all)
- Layout: header, 4-tab nav, 2-panel flex (main content + optional aside detail panel)
- Decisions view: filter controls (status select + search input), decision list with status badge, title, context excerpt, type, date
- Patterns view: 2-col grid, each card has name, category, description excerpt, usage count, Use Pattern button
- Debug view: list of sessions with issue_title, root_cause, resolved badge, tags
- Links view: list of file_path, holon_count, link_type

### 16.5 BDD Scenarios

```gherkin
Feature: Developer Knowledge Dashboard

  Scenario: C1-DEV-01 Page structure renders on load
    Given I navigate to "/cockpit/knowledge/developer"
    Then I should see the heading "Developer Knowledge"
    And I should see 4 view tabs: Decisions, Patterns, Debug Sessions, Code Links

  Scenario: C5-DEV-02 Switch to Patterns view
    When I click the "Patterns" tab
    Then I should see a 2-column grid of pattern cards

  Scenario: C5-DEV-03 Filter decisions by status
    Given I am on the Decisions view
    When I select "Accepted" from the status filter
    Then only accepted decisions should be shown

  Scenario: C5-DEV-04 Select an item opens detail panel
    Given decisions are loaded
    When I click on a decision row
    Then a detail panel should appear on the right
    And I should see the decision context, decision, and consequences fields

  Scenario: C8-DEV-05 Use Pattern records usage
    Given I am on the Patterns view
    When I click "Use Pattern" on a pattern
    Then I should see a flash info "Pattern usage recorded"
    And the pattern usage_count should increment
```

### 16.6 UX Flow

1. Land → Decisions tab active, filter controls (status + search) at top, decision list below
2. Switch to Patterns for code pattern library with usage counts
3. Switch to Debug Sessions for historical incident learnings
4. Switch to Code Links for file ↔ holon mapping overview
5. Click any item → detail panel slides in from right
6. Use Pattern button on pattern card → increments usage_count and flashes confirmation
7. Search input (300ms debounce) filters the active view in real-time

### 16.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| Decisions tab | Button | `switch_view` | phx-value-view="decisions" |
| Patterns tab | Button | `switch_view` | phx-value-view="patterns" |
| Debug Sessions tab | Button | `switch_view` | phx-value-view="debug" |
| Code Links tab | Button | `switch_view` | phx-value-view="links" |
| Status filter select | Select | `filter_status` | all/proposed/accepted/deprecated |
| Search input | Input | `search` | phx-keyup, debounce 300 |
| Decision row | Div | `select_item` | phx-value-id, phx-value-type="decision" |
| Pattern card | Div | `select_item` | phx-value-id, phx-value-type="pattern" |
| Use Pattern button | Button | `use_pattern` | phx-value-id |
| Debug session row | Div | `select_item` | phx-value-type="debug" |

### 16.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-001 | Dark Cockpit defaults |
| SC-KMS-001 | SQLite+DuckDB only for KMS storage |
| SC-KMS-007 | Decision traceability mandatory (ADR/RFC linked to decisions) |
| SC-DEV-001 | <50ms query latency for Developer KMS queries |

### 16.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Developer.list_decisions/0 returns {:error, reason} → empty list silently | 4 | 3 | 5 | 60 | Assign returns [] on error — add banner for empty-due-to-error vs. genuinely empty |
| String.to_existing_atom on unknown filter value → ArgumentError | 7 | 2 | 2 | 28 | Accept only known atom values; guard with `when status in [:all, :proposed, :accepted, :deprecated]` |
| use_pattern with unknown ID → :error → flash error | 3 | 2 | 1 | 6 | Already handled with {:error, _} clause |
| 10s refresh clobbers selected_item focus while operator reads detail | 3 | 4 | 5 | 60 | Refresh only updates list assigns, not selected_item |

---

## 17. Knowledge: Product

### 17.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/knowledge/product` |
| Module | `IndrajaalWeb.Prajna.Knowledge.ProductLive` |
| File | `lib/indrajaal_web/live/prajna/knowledge/product_live.ex` |
| Title | Product Knowledge |
| Tier | P3 Admin |

### 17.2 Design Intent

Product management knowledge hub providing visibility into the product development lifecycle: feature backlog with status/priority, release history, customer feedback triage, experiment outcomes, KPI dashboard, and roadmap planning. Backed by KMS Product module. Features a graceful fallback on KMS failure with a yellow warning banner, allowing the page to remain operational even without KMS connectivity.

### 17.3 Expected Behavior (Functional)

- Mount: full try/rescue/catch in mount/3; on failure assigns `kms_error` message and empty lists
- Refresh timer (15 000ms): reload features and releases
- PubSub `prajna:kms:product`: `{:product_event, event}` → reload features
- `switch_view` event: switches between :features, :releases, :feedback, :experiments, :kpis, :roadmap
- `select_item` event: loads item by type and id into `selected_item`
- `search` event (debounce 300ms): updates search_query for filter across all views
- `filter_status` event: updates filter_status for features view
- KPI progress bar: `progress_percent/1` helper computes (current/target * 100)
- Roadmap: `group_by_quarter/1` groups roadmap items by their Q label
- Feature status colors: proposed=blue, approved=cyan, in_progress=yellow, shipped=green, deprecated=gray
- Priority icons: critical=🔴, high=🟠, medium=🟡, low=🟢

### 17.4 AS-IS State

From `lib/indrajaal_web/live/prajna/knowledge/product_live.ex`:

- `@refresh_interval 15_000` (15s — slowest KMS refresh)
- PubSub: `prajna:kms:product`
- Assigns: `kms_error` (nil or string), `features`, `releases`, `feedback`, `experiments`, `kpis`, `roadmap`, `view_mode` (:features), `search_query`, `filter_status` (:all), `selected_item` (nil)
- Error banner: yellow warning shown when `@kms_error` is not nil
- 6 tabs: Features, Releases, Feedback, Experiments, KPIs, Roadmap

### 17.5 BDD Scenarios

```gherkin
Feature: Product Knowledge Dashboard

  Scenario: C1-PROD-01 Page structure renders on load
    Given I navigate to "/cockpit/knowledge/product"
    Then I should see 6 view tabs: Features, Releases, Feedback, Experiments, KPIs, Roadmap

  Scenario: C2-PROD-02 KMS error banner shown on failure
    Given the KMS Product module throws an exception
    When I navigate to "/cockpit/knowledge/product"
    Then I should see a yellow warning banner with the error message
    And the page should still render (not crash)

  Scenario: C5-PROD-03 Switch to KPIs view
    When I click the "KPIs" tab
    Then I should see KPI cards with progress bars

  Scenario: C5-PROD-04 Switch to Roadmap view
    When I click the "Roadmap" tab
    Then items should be grouped by quarter

  Scenario: C5-PROD-05 Priority icons visible on feature cards
    Given features are loaded with different priorities
    When I view the Features tab
    Then each feature should show its priority icon (🔴🟠🟡🟢)
```

### 17.6 UX Flow

1. Land → optional yellow error banner if KMS unavailable
2. Features tab (default): priority icons, status colors, feature list with search/filter
3. Releases tab: release history timeline
4. Feedback tab: customer feedback items sorted by priority
5. Experiments tab: A/B test and experiment outcomes
6. KPIs tab: KPI cards with progress bars (current/target)
7. Roadmap tab: items grouped by quarter
8. Click any item → detail panel with full data
9. Page refreshes every 15s (slowest in the KMS suite)

### 17.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| KMS error banner | Div | — | Yellow; shown when kms_error not nil |
| Features tab | Button | `switch_view` | phx-value-view="features" |
| Releases tab | Button | `switch_view` | phx-value-view="releases" |
| Feedback tab | Button | `switch_view` | phx-value-view="feedback" |
| Experiments tab | Button | `switch_view` | phx-value-view="experiments" |
| KPIs tab | Button | `switch_view` | phx-value-view="kpis" |
| Roadmap tab | Button | `switch_view` | phx-value-view="roadmap" |
| Status filter select | Select | `filter_status` | all/proposed/approved/in_progress/shipped |
| Search input | Input | `search` | phx-keyup, debounce 300 |
| Feature/item row | Div | `select_item` | phx-value-id, phx-value-type |
| KPI progress bar | Div | — | Width computed by progress_percent/1 |

### 17.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-KMS-001 | SQLite+DuckDB only for KMS storage |
| SC-HMI-001 | Dark Cockpit defaults |
| SC-HMI-010 | Color Rich — priority icons + feature status colors |

### 17.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| KMS module not started → error banner shown but empty data | 4 | 3 | 1 | 12 | Graceful fallback already implemented via try/rescue |
| 15s refresh on slow KMS → stale data during incident | 4 | 3 | 4 | 48 | Reduce to 5s or add manual refresh button for operators |
| progress_percent/1 with target=0 → division by zero | 7 | 2 | 2 | 28 | Guard: if target == 0, return 0 |
| group_by_quarter/1 with nil quarter field → key error | 5 | 3 | 3 | 45 | Default nil quarter to "Unscheduled" group |

---

## 18. Knowledge: SRE

### 18.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/cockpit/knowledge/sre` |
| Module | `IndrajaalWeb.Prajna.Knowledge.SRELive` |
| File | `lib/indrajaal_web/live/prajna/knowledge/sre_live.ex` |
| Title | SRE Knowledge |
| Tier | P3 Admin |

### 18.2 Design Intent

Site Reliability Engineering knowledge hub for operational excellence. Provides SRE practitioners with: runbooks for incident response, SLO status with error budget tracking, postmortem history, chaos engineering experiment outcomes, change management log, and toil quantification. SLO view is the primary safety indicator — breached SLOs require immediate operator attention.

### 18.3 Expected Behavior (Functional)

- Mount: try/rescue with graceful fallback; loads all 6 data categories from `Indrajaal.KMS.SRE`
- Refresh timer (10 000ms): reloads runbooks and SLOs
- PubSub `prajna:kms:sre`: `{:sre_event, event}` → reload runbooks
- `switch_view` event: switches between :runbooks, :slos, :postmortems, :chaos, :changes, :toil
- `select_item` event: loads item by type and id
- `search` event (debounce 300ms): updates search_query
- `filter_severity` event: updates filter_severity (all/critical/high/medium/low)
- SLO view: 4 summary cards (healthy count, warning count, breached count, error budget remaining)
- SLO bar: color-coded progress bar (healthy=green, warning=yellow, breached=red)
- Toil view: 3 summary cards (total_toil_hours, automation_candidates, open_items)
- Severity colors: critical=red, high=orange, medium=yellow, low=green

### 18.4 AS-IS State

From `lib/indrajaal_web/live/prajna/knowledge/sre_live.ex`:

- `@refresh_interval 10_000`
- PubSub: `prajna:kms:sre`
- Assigns: `runbooks`, `slos`, `postmortems`, `chaos_experiments`, `changes`, `toil_items`, `view_mode` (:runbooks), `search_query`, `filter_severity` (:all), `selected_item` (nil)
- 6 tabs: Runbooks, SLOs, Postmortems, Chaos, Changes, Toil
- SLO colors: healthy=`bg-green-500`, warning=`bg-yellow-500`, breached=`bg-red-500`

### 18.5 BDD Scenarios

```gherkin
Feature: SRE Knowledge Dashboard

  Scenario: C1-SRE-01 Page structure renders on load
    Given I navigate to "/cockpit/knowledge/sre"
    Then I should see 6 view tabs: Runbooks, SLOs, Postmortems, Chaos, Changes, Toil

  Scenario: C2-SRE-02 SLO status cards show health distribution
    When I click the "SLOs" tab
    Then I should see 4 summary cards: Healthy, Warning, Breached, Error Budget

  Scenario: C2-SRE-03 Breached SLO bar shown in red
    Given an SLO is in breached status
    When I view the SLOs tab
    Then that SLO's progress bar should be red

  Scenario: C5-SRE-04 Filter runbooks by severity
    Given I am on the Runbooks view
    When I select "Critical" from the severity filter
    Then only critical runbooks should be shown

  Scenario: C5-SRE-05 Toil view shows summary metrics
    When I click the "Toil" tab
    Then I should see total_toil_hours, automation_candidates, and open_items cards
```

### 18.6 UX Flow

1. Land → Runbooks tab with severity filter and search
2. Check SLOs tab — breached count is the most critical indicator
3. Postmortems tab: historical incidents with timeline and action items
4. Chaos tab: experiment results showing system resilience
5. Changes tab: recent change log for correlation during incidents
6. Toil tab: quantified toil with automation candidate count
7. Click any item → detail panel with full structured data
8. Page refreshes every 10s

### 18.7 UI Elements Inventory

| Element | Type | phx-click / phx-change | Notes |
|---------|------|------------------------|-------|
| Runbooks tab | Button | `switch_view` | phx-value-view="runbooks" |
| SLOs tab | Button | `switch_view` | phx-value-view="slos" |
| Postmortems tab | Button | `switch_view` | phx-value-view="postmortems" |
| Chaos tab | Button | `switch_view` | phx-value-view="chaos" |
| Changes tab | Button | `switch_view` | phx-value-view="changes" |
| Toil tab | Button | `switch_view` | phx-value-view="toil" |
| Severity filter select | Select | `filter_severity` | all/critical/high/medium/low |
| Search input | Input | `search` | phx-keyup, debounce 300 |
| Runbook/SLO/item row | Div | `select_item` | phx-value-id, phx-value-type |
| SLO progress bar | Div | — | Color: green/yellow/red by status |
| SLO summary card | Div | — | healthy/warning/breached/error_budget counts |
| Toil summary card | Div | — | total_toil_hours/automation_candidates/open_items |

### 18.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-KMS-001 | SQLite+DuckDB only |
| SC-SRE-001 | SRE Knowledge — site reliability constraints |
| SC-HMI-001 | Dark Cockpit defaults |
| SC-HMI-010 | Color Rich — SLO status bars tied to health state |

### 18.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| SRE KMS unavailable at mount → graceful fallback with empty data | 4 | 3 | 1 | 12 | try/rescue already implemented |
| SLO breach not surfaced if KMS query fails → false safety | 8 | 3 | 5 | 120 | Separate SLO health check via direct DB query, not KMS module |
| SLO error_budget_remaining as float → display format undefined | 3 | 3 | 4 | 36 | Standardize as percentage integer in KMS schema |
| Chaos experiment data could confuse operators if labeled ambiguously | 4 | 3 | 4 | 48 | Require status: :passed | :failed | :aborted in schema |

---

## ADDITIONAL OPERATIONS/ADMIN PAGES

---

## 19. Operations Access Dashboard

### 19.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/operations/access-dashboard` |
| Module | `IndrajaalWeb.Operations.AccessDashboardLive` |
| File | `lib/indrajaal_web/live/operations/access_dashboard_live.ex` |
| Title | Physical Access Control |
| Tier | Additional Operations |

### 19.2 Design Intent

Physical access control operations center for monitoring entry points, managing credentials, and responding to access events in real time. Models 5 access points (Main Entrance, Parking Gate A, Server Room, Loading Dock, Executive Floor) with grant/deny metrics, tailgating detection, anti-passback violations, credential summary, and schedule overview. Includes operator actions: grant_access, revoke_access, lockdown_zone, unlock_all.

### 19.3 Expected Behavior (Functional)

- Mount: generates synthetic initial data via private `generate_*` helpers; 5 hardcoded access points
- Refresh timer (2 000ms): regenerates metrics and events with `generate_*` helpers (simulated randomness)
- PubSub `access:events`: subscribed (no specific handler in current implementation)
- `select_point` event: loads access point into `selected_point` for detail view
- `grant_access`, `revoke_access` events: operate on `selected_point`; put_flash + broadcast
- `lockdown_zone`, `unlock_all` events: zone-wide operations with flash feedback
- `close_detail` event: clears `selected_point`
- Metrics: grants=1234+rand(50), denials=23+rand(10), tailgating=rand(5), anti_passback=2+rand(3)
- Credentials summary: total=2456, active=2341, active_pct=95, suspended=45, expired=70
- 3-column layout: access point grid (2 cols), sidebar with credentials/schedules/quick actions

### 19.4 AS-IS State

From `lib/indrajaal_web/live/operations/access_dashboard_live.ex`:

- `:timer.send_interval(2000, :refresh_metrics)` (not `:refresh` — distinct message atom)
- PubSub: `access:events`
- Assigns: `metrics` (grants/denials/tailgating/anti_passback), `access_points` (5 hardcoded), `recent_events`, `credentials_summary`, `active_schedules`, `selected_point` (nil)
- All data via private `generate_*` functions (synthetic/random)
- Layout: header, 4 metrics cards across top, 3-column grid (access points list + right sidebar)

### 19.5 BDD Scenarios

```gherkin
Feature: Operations Physical Access Control Dashboard

  Scenario: C1-OPS-01 Page structure renders on load
    Given I navigate to "/operations/access-dashboard"
    Then I should see 4 metrics cards at the top
    And I should see a list of 5 access points

  Scenario: C2-OPS-02 Metrics show grants and denials
    When I navigate to "/operations/access-dashboard"
    Then I should see "Access Grants" with a non-zero value
    And I should see "Access Denials" with a value

  Scenario: C5-OPS-03 Select access point shows detail panel
    When I click on "Server Room" access point
    Then a detail panel should appear with that point's data
    And I should see grant_access and revoke_access buttons

  Scenario: C8-OPS-04 Grant access action triggers flash
    Given I have selected an access point
    When I click "grant_access"
    Then I should see a flash info message
    And the access point status should update

  Scenario: C8-OPS-05 Lockdown zone triggers warning flash
    When I click "lockdown_zone"
    Then I should see a flash warning about the lockdown
```

### 19.6 UX Flow

1. Land → 4 metrics cards: Access Grants, Access Denials, Tailgating Alerts, Anti-Passback
2. Access points list (left 2 cols): each point with status, last event, grant rate
3. Click access point → detail panel shows camera feed placeholder + recent events + action buttons
4. Sidebar (right col): Credentials Summary, Active Schedules, Quick Actions (lockdown/unlock)
5. Metrics refresh every 2s — values fluctuate with synthetic randomness

### 19.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Access Grants card | Div | — | Randomized metric |
| Access Denials card | Div | — | Randomized metric |
| Tailgating Alerts card | Div | — | Randomized metric |
| Anti-Passback card | Div | — | Randomized metric |
| Access point row | Div | `select_point` | phx-value-id |
| Grant Access button | Button | `grant_access` | Only in detail panel |
| Revoke Access button | Button | `revoke_access` | Only in detail panel |
| Lockdown Zone button | Button | `lockdown_zone` | Sidebar quick action |
| Unlock All button | Button | `unlock_all` | Sidebar quick action |
| Close Detail button | Button | `close_detail` | Dismisses detail panel |

### 19.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-HMI-004 | Two-step commit for lockdown_zone (destructive action) |
| SC-SAFETY-001 | Guardian pre-approval for zone lockdown |
| SC-PHICS-003 | Guardian approval for destructive commands |
| SC-PHICS-001 | Commands logged to Immutable Register |

### 19.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| All data is synthetic — no real access control integration | 7 | 5 | 3 | 105 | Wire to real AccessControl domain module before deployment |
| lockdown_zone has no two-step commit — destructive action one click | 9 | 5 | 3 | 135 | Implement arm→confirm pattern per SC-HMI-004, SC-SAFETY-001 |
| 2s refresh creates rapid metric flickering — poor readability | 3 | 4 | 3 | 36 | Add CSS transition or debounce render updates |
| grant_access with no selected_point → crash | 6 | 2 | 2 | 24 | Guard: check selected_point not nil before executing |

---

## 20. STAMP/TDG/GDE Dashboard

### 20.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/admin/stamp-tdg-gde` |
| Module | `IndrajaalWeb.StampTdgGdeDashboardLive` |
| File | `lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex` |
| Title | STAMP/TDG/GDE Governance Dashboard |
| Tier | Additional Admin |

### 20.2 Design Intent

Unified governance dashboard presenting the health of three interconnected safety systems: STAMP (constraint compliance), TDG (test-driven generation quality), and GDE (goal-driven evolution progress). Aggregates metrics across all three pillars into a single operator view with compliance percentages, STPA/UCA counts, violation tracking, and feature flag management for controlled rollouts.

### 20.3 Expected Behavior (Functional)

- Mount: assigns hardcoded baseline values (overall_health=91.2, stamp_compliance=92.5, tdg_coverage=89.3, gde_progress=87.1)
- Refresh timer via `Process.send_after/3` (5 000ms, self-rescheduling): `:refresh_metrics`
- PubSub: `stamp_metrics`, `tdg_metrics`, `gde_metrics`, `alerts`
- `:refresh_metrics` handle_info: calls private metrics updaters
- `{:stampupdate, _}`, `{:tdgupdate, _}`, `{:gde_update, _}`: PubSub domain updates
- `{:alert, _}`: PubSub alert events
- `export_report` event: triggers report generation (stubbed)
- `toggle_flag` event: toggles feature flag state in `feature_flags` map
- `manage_rollout` event: for percentage-based rollout management
- Performance impact section: compilation overhead %, test suite overhead %, memory overhead %

### 20.4 AS-IS State

From `lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex`:

- Uses `Process.send_after/3` (not `:timer.send_interval/3`) for self-rescheduling
- PubSub: `stamp_metrics`, `tdg_metrics`, `gde_metrics`, `alerts`
- Assigns: `overall_health` (91.2), `stamp_compliance` (92.5), `tdg_coverage` (89.3), `gde_progress` (87.1), `stpa_count`, `uca_count`, `violation_count`, `cast_count`, `feature_flags`
- Layout: 4 health cards, 2×2 detailed metrics grid (STAMP Safety, TDG Quality, GDE Goals, Active Alerts), performance impact section, feature flag toggles with Chart hook
- Feature flags: rendered with `phx-hook="Chart"` for time-series sparklines

### 20.5 BDD Scenarios

```gherkin
Feature: STAMP/TDG/GDE Governance Dashboard

  Scenario: C1-GOV-01 Page structure renders on load
    Given I navigate to "/admin/stamp-tdg-gde"
    Then I should see 4 health score cards
    And I should see a 2x2 metrics grid

  Scenario: C2-GOV-02 Health scores visible
    When I navigate to "/admin/stamp-tdg-gde"
    Then I should see "Overall Health" with value near 91.2
    And I should see "STAMP Compliance" near 92.5

  Scenario: C5-GOV-03 Toggle feature flag changes state
    Given I see a feature flag in the dashboard
    When I click "toggle_flag" for that flag
    Then the flag state should toggle between enabled/disabled

  Scenario: C5-GOV-04 Export report triggers flash
    When I click "export_report"
    Then I should see a flash message about report generation

  Scenario: C3-GOV-05 Metrics refresh via self-scheduling timer
    Given the dashboard is mounted
    When 5 seconds elapse
    Then the metrics should have refreshed
```

### 20.6 UX Flow

1. Land → 4 colored health cards: Overall (%), STAMP Compliance (%), TDG Coverage (%), GDE Progress (%)
2. 2×2 grid with STAMP Safety detail, TDG Quality detail, GDE Goals detail, Active Alerts
3. Performance impact section: overhead percentages for compile/test/memory
4. Feature flags section: toggles per flag with optional Chart sparklines
5. Export Report button triggers governance report generation

### 20.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Overall Health card | Div | — | Float percentage |
| STAMP Compliance card | Div | — | Float percentage |
| TDG Coverage card | Div | — | Float percentage |
| GDE Progress card | Div | — | Float percentage |
| STAMP Safety detail | Div | — | stpa_count, uca_count |
| TDG Quality detail | Div | — | coverage metrics |
| GDE Goals detail | Div | — | gde_progress, cast_count |
| Active Alerts detail | Div | — | violation_count |
| Export Report button | Button | `export_report` | Governance report |
| Feature flag toggle | Button | `toggle_flag` | phx-value-flag |
| Rollout manager | Button | `manage_rollout` | Percentage rollout |

### 20.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-STAMP-001 | STAMP constraint tracking — this page displays STAMP compliance |
| SC-GDE-001 | Guardian validation — GDE progress monitored here |
| SC-COV-006 | TDG compliance mandatory — TDG coverage tracked here |
| SC-TPS-001 | Toyota Production System — Jidoka quality gate tracking |

### 20.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Hardcoded initial values (91.2%) — never update from real metrics | 7 | 5 | 4 | 140 | Wire :refresh_metrics to real STAMP/TDG/GDE query modules |
| Process.send_after self-scheduling fails if process dies → no more updates | 5 | 2 | 4 | 40 | Add exponential backoff or use :timer.send_interval |
| feature_flags phx-hook="Chart" requires JS hook registration | 4 | 3 | 3 | 36 | Verify Chart hook registered in app.js before deploy |
| PubSub subscriptions to stub topics → silent; no real events arrive | 5 | 4 | 5 | 100 | Wire real publishers before operational use |

---

## 21. Navigation Portal

### 21.1 Page Identity
| Field | Value |
|-------|-------|
| Route | `/admin/navigation` |
| Module | `IndrajaalWeb.NavigationPortalLive` |
| File | `lib/indrajaal_web/live/navigation_portal_live.ex` |
| Title | Indrajaal Navigation Portal |
| Tier | Additional Admin |

### 21.2 Design Intent

Comprehensive system navigation index providing operators and developers with a single-page directory of all 71 routes, 19 services, 17 F# projects, and 12 infrastructure endpoints. Serves as the canonical route reference and service discovery hub. Displays version, node name, route categories with status badges, F# project group breakdown, service plane architecture, and infrastructure endpoints.

### 21.3 Expected Behavior (Functional)

- Mount: no timer, no PubSub subscriptions — static reference page
- Assigns: `route_categories`, `service_planes`, `fsharp_groups`, `infra_endpoints`, `version` ("v21.3.0-SIL6"), `node_name` (from `node()`), `total_routes` (71), `total_services` (19), `total_fsharp` (17), `current_time`
- No `handle_event/3` or `handle_info/2` clauses
- Route categories (7): C3I Cockpit (30), Operations Center (4), Analytics (4), Administration (4), Health Probes (4), Assurance (3), API Reference (8)
- Service planes (4): 4 planes with 19 services total
- F# groups (4): 4 groups with 17 projects total
- Infrastructure endpoints (12): all system endpoints
- STAMP: SC-PORTAL-001 (all routes linked), SC-PORTAL-002 (all routes return HTTP 200)

### 21.4 AS-IS State

From `lib/indrajaal_web/live/navigation_portal_live.ex`:

- `@version "v21.3.0-SIL6"` module attribute
- 4 module-level constant maps: `@service_planes`, `@fsharp_groups`, `@infra_endpoints`, `@route_categories`
- mount assigns `node_name: node()` (runtime Erlang node atom)
- No dynamic data — all content is compile-time constants or mount-time BEAM intrinsics
- Purely informational; no user actions

### 21.5 BDD Scenarios

```gherkin
Feature: Navigation Portal

  Scenario: C1-NAV-01 Page structure renders on load
    Given I navigate to "/admin/navigation"
    Then I should see the version "v21.3.0-SIL6"
    And I should see the total_routes count "71"
    And I should see route category sections

  Scenario: C1-NAV-02 All 7 route categories displayed
    When I navigate to "/admin/navigation"
    Then I should see "C3I Cockpit" category with 30 routes
    And I should see "API Reference" category with 8 routes

  Scenario: C1-NAV-03 Node name shows Erlang node identity
    When I navigate to "/admin/navigation"
    Then I should see the Erlang node name (non-empty)

  Scenario: C1-NAV-04 F# project groups displayed
    When I navigate to "/admin/navigation"
    Then I should see 4 F# project groups with 17 total projects

  Scenario: C1-NAV-05 Infrastructure endpoints listed
    When I navigate to "/admin/navigation"
    Then I should see 12 infrastructure endpoints
```

### 21.6 UX Flow

1. Land → version badge + node name + summary counts (71 routes, 19 services, 17 F# projects)
2. Route categories section: 7 categories with route counts and individual route links
3. Service planes section: 4 planes with 19 services
4. F# project groups: 4 groups with 17 projects
5. Infrastructure endpoints: 12 endpoints with URLs
6. Page is static — no interaction, no refresh
7. Acts as developer/operator quick reference

### 21.7 UI Elements Inventory

| Element | Type | phx-click | Notes |
|---------|------|-----------|-------|
| Version badge | Span | — | `@version` compile-time constant |
| Node name | Span | — | `node()` Erlang atom |
| Total routes counter | Span | — | 71 |
| Route category section | Div | — | Per-category route list |
| Route link | A | — | href to route path |
| Service plane card | Div | — | Service name + endpoint |
| F# project entry | Div | — | Project name + description |
| Infrastructure endpoint row | Div | — | Endpoint URL |

### 21.8 STAMP Constraints

| Constraint | Applicability |
|------------|---------------|
| SC-PORTAL-001 | All routes linked — 71 routes must appear in categories |
| SC-PORTAL-002 | All routes return HTTP 200 — navigation portal as smoke test reference |
| SC-HMI-001 | Dark Cockpit styling |
| SC-CI-003 | Test results published — portal verifies all routes present |

### 21.9 FMEA Risks

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| @route_categories outdated when new routes added — stale reference | 5 | 4 | 5 | 100 | Automate route_categories from router.ex via compile-time macro |
| total_routes hardcoded as 71 — incorrect after route changes | 4 | 5 | 5 | 100 | Compute total_routes at mount from length of @route_categories flatten |
| Node name shows wrong node in multi-node cluster | 3 | 2 | 4 | 24 | node() is always correct for current node — no fix needed |
| A href links not verified as HTTP 200 during build — dead links | 5 | 3 | 5 | 75 | Add Wallaby smoke test verifying all links in portal return 200 |

---

## Summary Statistics

| Category | Pages | Total BDD Scenarios |
|----------|-------|---------------------|
| P2 Infrastructure | 11 | 55 |
| P3 Admin | 7 | 35 |
| Additional Operations/Admin | 3 | 15 |
| **Total** | **21** | **105** |

## Coverage Compliance

| Constraint | Status |
|------------|--------|
| SC-COV-008 (Wallaby E2E for all LiveView pages) | Spec complete — implementation pending |
| SC-HMI-010 (Color Rich chromatic feedback) | Documented per page (HMI-010 referenced where applicable) |
| SC-UIGT-001 (Navigation digraph covers all pages as vertices) | All 21 pages covered as vertices in spec |
| SC-COV-004 (BDD specs for all user journeys) | 5 BDD scenarios per page = 105 total |
