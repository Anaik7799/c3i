# Prajna Page Specifications — Part 2: P1 Interactive Pages

**Generated**: 20260328-2100 CEST
**Purpose**: Comprehensive design, intent, expected behavior, BDD, and UX specs
**Compliance**: SC-COV-008, SC-HMI-010, SC-UIGT-001
**Source**: All specs derived from reading actual LiveView `.ex` source files

---

## Table of Contents

1. `/cockpit/diagnostics` — Diagnostics
2. `/cockpit/test-cockpit` — Test Cockpit
3. `/cockpit/dispatch` — Dispatch Console
4. `/cockpit/video-wall` — Live Video Wall
5. `/cockpit/knowledge` — Knowledge Management
6. `/cockpit/sentinel` — Sentinel Dashboard
7. `/cockpit/analytics` — Analytics Center
8. `/cockpit/compliance` — Compliance Dashboard
9. `/cockpit/copilot` — AI Copilot
10. `/cockpit/alarm-investigation/:id` — Alarm Investigation

---

## Page 1: `/cockpit/diagnostics`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/diagnostics` |
| Module | `IndrajaalWeb.Prajna.DiagnosticsLive` |
| Title | "Diagnostics" |
| Source | `lib/indrajaal_web/live/prajna/diagnostics_live.ex` |
| Version | 1.0.0 (2025-12-27) |
| Reference | NUREG-0700, OTEL |

### 2. Design Intent

The Diagnostics page is the system troubleshooting center for the PRAJNA C3I cockpit. It follows NUREG-0700 diagnostic display guidelines. The page exists to provide operators and system engineers with:

- A real-time log viewer with multi-dimensional filtering (source, level, text search, time range)
- Distributed trace explorer with span-level waterfall breakdown
- Immutable audit trail of all operator actions
- Live BEAM VM runtime metrics (memory, scheduler, process count)
- One-click diagnostic action buttons for triage without leaving the cockpit

This page addresses the common operational problem where an operator cannot trace a fault from alarm to root cause without navigating to multiple external tools. All diagnostic evidence is co-located in one view.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- Starts in `:logs` tab with the most recent 21 log entries
- Live Tail is ON by default — new log entries stream in every 1000ms (30% probability random generation)
- Subscribes to `prajna:logs` PubSub topic for real-time log injection
- Filters initialized: source=all, level=info, search=""

**Log Tab:**
- Displays up to 100 filtered log entries in a monospace scrollable panel
- Each entry: timestamp (HH:MM:SS.mmm), level badge (color-coded), source (truncated), message
- Source filter: All Sources, Phoenix, Ecto, Prajna, Sentinel, Oban
- Level filter: Debug+, Info+ (default), Warning+, Error+
- Text search field with live phx-change filter
- Time range selector (display-only: Last 1h/6h/24h/7d — not yet wired to data)
- LIVE TAIL toggle button: green when active, gray when paused
- Shows "X of Y entries" count at the bottom; "LOAD MORE" link (not yet wired)

**Traces Tab:**
- Displays 2 sample traces sorted slowest-first
- Each trace shows: trace ID, HTTP method, path, total duration, span count, status badge (slow/normal)
- Expandable span waterfall: parent span → child spans with individual durations
- Spans exceeding threshold highlighted yellow with ⚠ icon

**Audit Trail Tab:**
- Immutable log of operator actions (ALARM_ACK, CONFIG_CHANGE, COMMAND_EXEC, LOGIN)
- Each entry: timestamp, action badge (color-coded), resource, actor user, detail text

**System Info Tab:**
- Two panels: Runtime Info and BEAM VM
- Runtime: Elixir version, OTP version, node name, uptime, connected nodes, UTC time
- BEAM: schedulers online, process count, port count, memory total/processes/ETS (all live from `:erlang.memory()`)

**Quick Diagnostics Panel (persistent across all tabs):**
- RUN HEALTH CHECK: checks memory < 7GB, process count < 500K, run queue < 100; returns passed/warning/failed with duration
- DUMP STATE: records timestamp and path `/data/dumps/state-{date}.json`
- TRACE REQUEST: enables request tracing for 60 seconds
- PROFILE CPU: starts 30-second CPU profiling
- Shows last health check result and last state dump path if available

**Action Buttons (bottom):**
- EXPORT LOGS: flash info "Logs exported to prajna_logs.json"
- CLEAR OLD LOGS: flash info "Logs older than 7 days cleared"
- OPEN IN SIGNOZ: external redirect to `http://localhost:8123`

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title        => "Diagnostics"
:active_tab        => :logs
:logs              => [21 generated log entries]
:log_filter        => %{source: "all", level: "info", search: ""}
:live_tail         => true
:traces            => [2 sample traces with spans]
:audit_trail       => [4 sample audit entries]
:system_info       => %{runtime: [...], beam: [...]}  (live BEAM intrinsics)
:last_health_check => nil
:last_state_dump   => nil
```

**Timer:**
- `@refresh_interval = 1000` ms — sends `:refresh` to self when `live_tail` is true; 30% chance of adding a new log entry capped at 500 total

**PubSub Subscriptions:**
- `"prajna:logs"` — handles `{:new_log, log}` to prepend to log list (max 500, only if `live_tail`)

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"switch_tab"` | `%{"tab" => tab}` | Sets `:active_tab` atom |
| `"toggle_live_tail"` | `_` | Toggles `:live_tail` boolean |
| `"update_filter"` | `%{"source", "level", "search"}` | Updates `:log_filter` map |
| `"run_health_check"` | `_` | Checks BEAM health, assigns `:last_health_check`, flash |
| `"dump_state"` | `_` | Assigns `:last_state_dump` with path and timestamp |
| `"trace_request"` | `_` | Flash info only |
| `"profile_cpu"` | `_` | Flash info only |
| `"export_logs"` | `_` | Flash info only |
| `"clear_old_logs"` | `_` | Flash info only |
| `"open_signoz"` | `_` | External redirect to port 8123 |

**handle_info callbacks:**
| Message | Effect |
|---------|--------|
| `:refresh` | If `live_tail`, calls `maybe_add_log/1` (30% probability), max 500 entries |
| `{:new_log, log}` | If `live_tail`, prepends log, caps at 500 |

### 5. BDD Scenarios

```gherkin
Feature: Diagnostics Page — NUREG-0700 Compliant Log/Trace/Audit Interface

  Background:
    Given I am logged in as an operator
    And I navigate to "/cockpit/diagnostics"

  Scenario: Default log view with live tail active
    Given I am on the Diagnostics page
    Then I should see the "LOGS" tab is active
    And I should see the "LIVE TAIL: ON" button in green
    And I should see log entries with timestamp, level, source, and message

  Scenario: Filter logs by error level
    Given I am on the Diagnostics page on the Logs tab
    When I select "Error+" from the level filter
    Then only log entries with level "ERROR" should be visible

  Scenario: Run health check with passing system
    Given I am on the Diagnostics page
    When I click "RUN HEALTH CHECK"
    Then I should see a flash message with "Health check completed - PASSED"
    And the "Last Health Check" line should show a timestamp and status

  Scenario: Switch to System Info tab and view live BEAM data
    Given I am on the Diagnostics page
    When I click the "SYSTEM INFO" tab
    Then I should see "Elixir Version" and "OTP Version" in the Runtime panel
    And I should see "Process Count" and "Memory Total" in the BEAM VM panel
    And the values should be non-zero integers

  Scenario: Pause live tail and verify log stream stops
    Given I am on the Diagnostics page with live tail ON
    When I click "LIVE TAIL: ON"
    Then the button should show "LIVE TAIL: OFF" in gray
    And no new log entries should be added during the next refresh cycle
```

### 6. UX Flow

1. Operator opens `/cockpit/diagnostics` from cockpit nav
2. Log viewer immediately shows streaming entries (Live Tail ON)
3. Operator uses source/level/search filters to isolate relevant logs
4. Operator pauses Live Tail to inspect a specific entry without stream interruption
5. Operator clicks "RUN HEALTH CHECK" to get instant BEAM snapshot
6. If health check shows `:warning` (run queue > 100), operator switches to System Info tab
7. Operator can switch to Traces tab to find slow spans
8. Operator checks Audit Trail for recent config changes by other operators
9. If deeper analysis needed, operator clicks "OPEN IN SIGNOZ" to open SigNoz at port 8123
10. Operator can export logs or clear old logs from the bottom action bar

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-change |
|---------|------|------------------------|
| Tab: LOGS | Button | `phx-click="switch_tab"` `phx-value-tab="logs"` |
| Tab: TRACES | Button | `phx-click="switch_tab"` `phx-value-tab="traces"` |
| Tab: METRICS HISTORY | Button | `phx-click="switch_tab"` `phx-value-tab="metrics"` |
| Tab: AUDIT TRAIL | Button | `phx-click="switch_tab"` `phx-value-tab="audit"` |
| Tab: SYSTEM INFO | Button | `phx-click="switch_tab"` `phx-value-tab="system"` |
| Source filter | Select | `phx-change="update_filter"` name="source" |
| Level filter | Select | `phx-change="update_filter"` name="level" |
| Search input | Text input | `phx-change="update_filter"` name="search" |
| Time range | Select | (display only, not wired) |
| LIVE TAIL toggle | Button | `phx-click="toggle_live_tail"` |
| RUN HEALTH CHECK | Button | `phx-click="run_health_check"` |
| DUMP STATE | Button | `phx-click="dump_state"` |
| TRACE REQUEST | Button | `phx-click="trace_request"` |
| PROFILE CPU | Button | `phx-click="profile_cpu"` |
| EXPORT LOGS | Button | `phx-click="export_logs"` |
| CLEAR OLD LOGS | Button | `phx-click="clear_old_logs"` |
| OPEN IN SIGNOZ | Button | `phx-click="open_signoz"` (redirects) |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Dark Cockpit defaults — all backgrounds are surface-primary/secondary |
| SC-OBS-069 | Dual logging (Terminal + SigNoz) — OPEN IN SIGNOZ button provides access |
| SC-DIAG-001 | Log retention > 7 days — CLEAR OLD LOGS purges entries older than 7 days |
| SC-VDP-010 | Temporal context in displays — all entries show timestamps |
| SC-AI-001 | Not applicable here (no AI panel) |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| PubSub subscription to `prajna:logs` fails silently on disconnect; logs freeze despite live tail showing ON | 189 (S=7, O=3, D=9) | Add reconnection check on `:refresh` cycle; show "PubSub disconnected" badge |
| Health check reports :passed while BEAM is actually degraded because thresholds are fixed constants (7GB/500K/100) and not configurable | 160 (S=8, O=2, D=10) | Load thresholds from config; add config_change event to update dynamically |
| `open_signoz` redirect fails if SigNoz is not running on port 8123; no error shown to user | 105 (S=3, O=5, D=7) | Add pre-redirect health check with timeout; show error flash on failure |

---

## Page 2: `/cockpit/test-cockpit`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/test-cockpit` |
| Module | `IndrajaalWeb.Prajna.TestCockpitLive` |
| Title | "Test Cockpit" |
| Source | `lib/indrajaal_web/live/prajna/test_cockpit_live.ex` |
| Version | 1.0.0 (2026-01-03) |
| Reference | SC-TEST-EVO-*, AOR-TEST-EVO-* |

### 2. Design Intent

The Test Cockpit is a biomorphic test evolution monitoring and control interface. It exists as the command center for the AI-powered test generation subsystem (`BiomorphicTestEvolution`). Its core purpose is to:

- Display combined fitness across 4 dimensions: coverage, pass rate, mutation score, diversity
- Show live OODA cycle state (which of the 4 phases is currently active)
- Present per-level coverage for all 5 test level types (TDG, FMEA, Formal, Graph, BDD)
- Allow operators to start/stop the evolution engine and trigger manual OODA cycles
- Configure genome parameters (mutation rate, selection pressure, etc.) via sliders
- Watch specific modules for automatic test generation

The page models the software quality genome as an evolving organism — operators tend to the test ecosystem rather than writing individual tests.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- Starts on `:overview` tab showing 4 fitness cards and OODA cycle status
- Evolution status badge shows "IDLE" (gray) or "EVOLVING" (green)
- OODA cycle counter and last cycle ms shown in header
- Fitness seeded from BEAM run queue for deterministic initial values

**Overview Tab:**
- 4 fitness cards: COVERAGE (84.7%), PASS RATE (92.3%), MUTATION (71.2%), DIVERSITY (45.6%)
- OODA cycle visualizer: 4 circular nodes (O, O, D, A) with active phase highlighted in accent color
- Stats below OODA: Observations count, Decisions made, Actions taken
- Combined Fitness gauge: large percentage with color-coded bar (green ≥80%, yellow ≥50%, red <50%)
- 5-Level Coverage summary grid: TDG 89%, FMEA 76%, Formal 82%, Graph 91%, BDD 73%

**Levels Tab:**
- Detailed view per level: name badge, description, AI model used
- Progress bar per level
- Test count, pass count, fail count, last run time (static fixtures)

**Genome Tab:**
- 4 sliders: Mutation Rate (0.0-1.0), Selection Pressure (0.0-1.0), Crossover Rate (0.0-1.0), Target Coverage (0.5-1.0)
- AI Model Weights panel: property_gen=Llama 3.1, code_analysis=Gemma 2, bdd_gen=Mistral 7B, fmea_analysis=Qwen 2
- Note: "All models use :free tier (AOR-OPENROUTER-001)"

**History Tab:**
- Recent test runs list (max 20): level badge, module name, PASS/FAIL status
- Metadata per entry: generated timestamp, tokens used, duration in ms

**Modules Tab:**
- Watched modules list with REMOVE button per module
- Form to enter a file path and generate all 5 test levels
- "Generate All 5 Levels" button (disabled while generating, shows "GENERATING...")
- "+ Watch this module" quick-add link

**Evolution Controls Panel (persistent):**
- START EVOLUTION / STOP EVOLUTION button (toggles based on `:evolution_active`)
- RUN OODA CYCLE button (disabled when evolution not active)

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title          => "Test Cockpit"
:active_tab          => :overview
:fitness             => %{coverage: 0.847, pass_rate: 0.923, mutation_score: 0.712, diversity: 0.456, combined: 0.785}
:genome              => %{mutation_rate: 0.1, selection_pressure: 0.7, crossover_rate: 0.3, target_coverage: 0.95}
:ooda_state          => %{current_phase: :observe, cycle_count: 42, last_cycle_ms: 28, observations_count: 156, decisions_made: 42, actions_taken: 38}
:level_coverage      => %{tdg: 0.89, fmea: 0.76, formal: 0.82, graph: 0.91, bdd: 0.73}
:recent_tests        => [10 entries derived from BEAM process_count/run_queue]
:watched_modules     => []
:selected_module     => nil
:generation_status   => :idle
:evolution_active    => false
:test_levels         => [{:tdg, "TDG", "Property Tests", model}, ...]
```

**Timer:**
- `@refresh_interval = 5000` ms — updates `:fitness` (BEAM run_queue delta) and `:ooda_state` (advances phase)

**PubSub Subscriptions:**
- `"prajna:test_evolution"` — handles `{:test_generated, test_info}`, `{:fitness_updated, fitness}`, `{:ooda_cycle_complete, state}`

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"switch_tab"` | `%{"tab" => tab}` | Sets `:active_tab` |
| `"start_evolution"` | `_` | Calls `BiomorphicTestEvolution.start_link/1`, sets `:evolution_active` |
| `"stop_evolution"` | `_` | Calls `BiomorphicTestEvolution.stop/0`, clears `:evolution_active` |
| `"run_ooda"` | `_` | Calls `BiomorphicTestEvolution.evolve/0`, flash info |
| `"generate_tests"` | `%{"module" => module}` | Sets `:generation_status` to `:generating`, spawns async Task |
| `"watch_module"` | `%{"module" => module}` | Calls `BiomorphicTestEvolution.watch_module/1`, adds to list |
| `"unwatch_module"` | `%{"module" => module}` | Removes from `:watched_modules` |
| `"update_genome"` | `%{"field" => field, "value" => value}` | Updates `:genome` map with parsed float |

**handle_info callbacks:**
| Message | Effect |
|---------|--------|
| `:refresh` | Updates `:fitness` (BEAM-based delta) and advances OODA phase |
| `{:test_generated, test_info}` | Prepends to `:recent_tests`, max 20 |
| `{:fitness_updated, fitness}` | Replaces `:fitness` |
| `{:ooda_cycle_complete, state}` | Replaces `:ooda_state` |

### 5. BDD Scenarios

```gherkin
Feature: Test Cockpit — Biomorphic Evolution Control Dashboard

  Background:
    Given I navigate to "/cockpit/test-cockpit"

  Scenario: View combined fitness on overview tab
    Given I am on the Test Cockpit overview tab
    Then I should see 4 fitness cards: COVERAGE, PASS RATE, MUTATION, DIVERSITY
    And I should see a COMBINED FITNESS percentage with a color-coded bar
    And the bar should be green if fitness >= 80%

  Scenario: Start and stop evolution engine
    Given the evolution engine is IDLE
    When I click "START EVOLUTION"
    Then the header badge should show "EVOLVING" in green
    And the "STOP EVOLUTION" button should appear
    When I click "STOP EVOLUTION"
    Then the header badge should show "IDLE" in gray

  Scenario: OODA cycle advances through phases
    Given the evolution engine is running
    When 5 seconds elapse
    Then the active OODA phase should advance (OBSERVE → ORIENT → DECIDE → ACT)
    And the cycle count should increment when phase wraps back to OBSERVE

  Scenario: Generate all 5 test levels for a module
    Given I am on the Modules tab
    When I type "lib/indrajaal/accounts/user.ex" in the module input
    And I click "GENERATE ALL 5 LEVELS"
    Then the button should show "GENERATING..."
    And a flash message should appear "Generating tests for lib/indrajaal/accounts/user.ex..."

  Scenario: Adjust genome mutation rate slider
    Given I am on the Genome tab
    When I change the "Mutation Rate" slider to 0.25
    Then the displayed value next to the label should update to "0.25"
```

### 6. UX Flow

1. Operator opens `/cockpit/test-cockpit` — sees fitness dashboard
2. Reviews combined fitness gauge — if below 80%, checks which level has lowest coverage
3. Navigates to Levels tab to see per-level breakdown with model assignments
4. If coverage is low for a specific module, navigates to Modules tab
5. Enters module path, clicks "GENERATE ALL 5 LEVELS"
6. Optionally clicks "+ Watch this module" for continuous monitoring
7. Navigates back to Overview, clicks "START EVOLUTION" to begin automated improvement
8. Watches OODA cycle animation advance through phases
9. Clicks "RUN OODA CYCLE" to force an immediate cycle (when evolution is active)
10. Checks History tab for recent test outcomes; if failures accumulate, stops evolution

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-submit |
|---------|------|------------------------|
| Tab: OVERVIEW | Button | `phx-click="switch_tab"` |
| Tab: 5-LEVELS | Button | `phx-click="switch_tab"` |
| Tab: GENOME | Button | `phx-click="switch_tab"` |
| Tab: HISTORY | Button | `phx-click="switch_tab"` |
| Tab: MODULES | Button | `phx-click="switch_tab"` |
| START EVOLUTION | Button | `phx-click="start_evolution"` |
| STOP EVOLUTION | Button | `phx-click="stop_evolution"` |
| RUN OODA CYCLE | Button | `phx-click="run_ooda"` (disabled when idle) |
| Mutation Rate slider | Range input | `phx-change="update_genome"` `phx-value-field="mutation_rate"` |
| Selection Pressure slider | Range input | `phx-change="update_genome"` |
| Crossover Rate slider | Range input | `phx-change="update_genome"` |
| Target Coverage slider | Range input | `phx-change="update_genome"` |
| Generate Tests form | Form | `phx-submit="generate_tests"` |
| Module path input | Text input | name="module" |
| GENERATE ALL 5 LEVELS | Submit button | (disabled when `:generation_status == :generating`) |
| Watch module link | Button | `phx-click="watch_module"` |
| REMOVE watched module | Button | `phx-click="unwatch_module"` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-TEST-EVO-001 | OODA cycle < 30s — 5s refresh interval satisfies this |
| SC-TEST-EVO-002 | Fitness tracking mandatory — 4-dimension fitness cards always visible |
| SC-TEST-EVO-003 | All 5 levels generated — `:test_levels` includes tdg, fmea, formal, graph, bdd |
| SC-HMI-001 | Dark Cockpit defaults — monospace font, surface palette |
| SC-BIO-005 | Dashboard refresh every 30s — 5s refresh is more frequent, satisfies constraint |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| `BiomorphicTestEvolution.start_link/1` succeeds but GenServer crashes immediately; `:evolution_active` stays `true` while engine is dead | 200 (S=8, O=5, D=5) | Monitor BiomorphicTestEvolution PID via `Process.monitor/1`; handle `:DOWN` message to reset `:evolution_active` |
| `Task.async` for `generate_all_levels` has no timeout; if model API hangs, `:generation_status` is stuck at `:generating` forever | 175 (S=7, O=5, D=5) | Use `Task.async_stream` with `:timeout` option; add reset button for stuck generation state |
| OODA phase animation advances server-side but websocket socket disconnects; client shows stale phase indefinitely | 120 (S=4, O=6, D=5) | Reconnect behavior is handled by LiveView automatically; document expected behavior |

---

## Page 3: `/cockpit/dispatch`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/dispatch` |
| Module | `IndrajaalWeb.Operations.DispatchConsoleLive` |
| Title | "Dispatch Console" |
| Source | `lib/indrajaal_web/live/operations/dispatch_console_live.ex` |

### 2. Design Intent

The Dispatch Console is the operations center for real-time security team management. It provides dispatchers with:

- A live list of all active assignments with status (en route, in progress) and priority
- Resource roster showing teams, officers, and vehicles with availability
- Map visualization with vehicle/officer positions (placeholder with absolute-positioned markers)
- Assignment creation via modal form with type, location, priority, and assignment fields
- Per-assignment actions: Track, Reassign, Escalate, Divert, Add Task
- Shift handover and broadcast messaging capabilities

The page solves the operational problem of coordinating multiple security resources across multiple simultaneous incidents without losing situational awareness.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- Two active assignments generated (ASN-001: INTRUSION/en_route, ASN-002: PATROL/in_progress)
- Three teams (Alpha/assigned, Bravo/available, Charlie/off_duty)
- Three officers (Johnson/assigned, Smith/available, Williams/break)
- Three vehicles (V-001/moving, V-002/parked, V-003/maintenance)
- Timer refreshes positions every 3000ms

**Assignment List:**
- Each assignment shows: colored status dot, ID, priority badge, type, location, assigned resource, ETA
- In-progress assignments show a progress bar (e.g., 60% for ASN-002)
- Clicking an assignment selects it (cyan ring border) and shows detail panel in right column

**Assignment Detail (appears when selected):**
- Shows: Status, Type, Location, Assigned To, ETA
- Action buttons: Divert, Add Task

**Resource Columns (right side):**
- Teams, Officers, Vehicles each in own card with availability color coding
- Green: available/parked; Amber: assigned/break; Cyan: moving; Red: maintenance; Gray: off_duty

**Dispatch Map:**
- Placeholder visual with `🚗` vehicle marker (animated pulse) and `⚠️` incident marker
- Legend overlay: Vehicle / Officer / Incident

**New Assignment Modal:**
- Triggered by "New Assignment" button
- Form with: Type (Intrusion/Patrol/Escort/Investigation), Location, Priority, Assign To
- Create and Cancel buttons

**Header Buttons:**
- New Assignment, Broadcast All, Shift Handover, Reports (all flash info on click)

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title           => "Dispatch Console"
:active_assignments   => [2 generated assignments]
:available_teams      => [3 teams]
:available_officers   => [3 officers]
:available_vehicles   => [3 vehicles]
:selected_assignment  => nil
:new_assignment_mode  => false
:map_center           => {40.7128, -74.0060}
```

**Timer:**
- `3000` ms — refreshes `:active_assignments` and `:available_officers`

**PubSub Subscriptions:**
- `"dispatch:events"` — handles `{:assignment_update, assignment}` to update assignment in list

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"select_assignment"` | `%{"id" => id}` | Finds assignment, assigns to `:selected_assignment` |
| `"new_assignment"` | `_` | Sets `:new_assignment_mode` to true |
| `"cancel_new_assignment"` | `_` | Clears `:new_assignment_mode` |
| `"create_assignment"` | `params` | Clears modal, flash info with type |
| `"track"` | `%{"id" => id}` | Flash info |
| `"reassign"` | `%{"id" => id}` | Flash info |
| `"escalate"` | `%{"id" => id}` | Flash warning |
| `"divert"` | `%{"id" => id}` | Flash info |
| `"add_task"` | `%{"id" => id}` | Flash info |
| `"broadcast_all"` | `_` | Flash info |
| `"shift_handover"` | `_` | Flash info |
| `"reports"` | `_` | Flash info |

### 5. BDD Scenarios

```gherkin
Feature: Dispatch Console — Real-Time Security Operations Management

  Background:
    Given I navigate to "/cockpit/dispatch"

  Scenario: View active assignments on page load
    Then I should see "Active Assignments (2)"
    And I should see assignment "ASN-001" with priority "HIGH"
    And I should see assignment "ASN-002" with a progress bar at 60%

  Scenario: Select an assignment to view details
    When I click on assignment "ASN-001"
    Then the assignment card should show a cyan border
    And a detail panel should appear on the right with "ASN-001" in cyan
    And I should see "Divert" and "Add Task" action buttons

  Scenario: Create a new assignment via modal
    When I click "New Assignment"
    Then a modal should appear with "New Assignment" heading
    When I select type "Intrusion Response", enter location "Zone-C", set priority "High"
    And I click "Create"
    Then the modal should close
    And a flash message should confirm "Assignment created: intrusion"

  Scenario: Escalate an assignment
    Given assignment "ASN-002" is visible
    When I click "Escalate" on "ASN-002"
    Then a warning flash should appear "Escalating ASN-002 to supervisor"

  Scenario: Cancel new assignment creation
    When I click "New Assignment"
    And I click "Cancel"
    Then the modal should close without creating an assignment
```

### 6. UX Flow

1. Dispatcher opens `/cockpit/dispatch` — sees all active assignments and resource roster
2. Reviews ASN-001 (INTRUSION, HIGH priority, en route) — clicks it to see detail
3. Checks Team Alpha (assigned) and Vehicle V-001 (moving) to confirm they're responding
4. Receives new incident — clicks "New Assignment", fills form, assigns to Team Bravo (available)
5. New assignment appears in list; dispatcher monitors ETA
6. If situation escalates, clicks "Escalate" to push to supervisor
7. After incident resolved, selects assignment and closes via detail panel
8. At end of shift, clicks "Shift Handover" to initiate handover protocol

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-submit |
|---------|------|------------------------|
| New Assignment | Button | `phx-click="new_assignment"` |
| Broadcast All | Button | `phx-click="broadcast_all"` |
| Shift Handover | Button | `phx-click="shift_handover"` |
| Reports | Button | `phx-click="reports"` |
| Assignment card | Div (clickable) | `phx-click="select_assignment"` `phx-value-id` |
| Track button | Button | `phx-click="track"` `phx-value-id` |
| Reassign button | Button | `phx-click="reassign"` `phx-value-id` |
| Escalate button | Button | `phx-click="escalate"` `phx-value-id` |
| Divert button (detail) | Button | `phx-click="divert"` `phx-value-id` |
| Add Task button (detail) | Button | `phx-click="add_task"` `phx-value-id` |
| Create Assignment form | Form | `phx-submit="create_assignment"` |
| Type select | Select | name="type" |
| Location input | Text | name="location" |
| Priority select | Select | name="priority" |
| Assign To select | Select | name="assign_to" |
| Cancel modal button | Button | `phx-click="cancel_new_assignment"` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Management by Exception — high-priority assignments highlighted in red badge |
| SC-HMI-004 | Two-step commit for critical actions — escalate uses warning flash but no arm/fire currently |
| SC-DSP-001 | Dispatch workflow management — all assignment states tracked |
| SC-DSP-002 | Resource tracking — teams, officers, vehicles with availability states |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| Position refresh at 3s regenerates fixed mock data — in production, stale positions could cause dispatchers to send responders to wrong locations | 270 (S=9, O=3, D=10) | Wire `:refresh_positions` to real GPS/location service; add "last seen" timestamp per officer |
| Two dispatchers can create overlapping assignments for the same resource simultaneously (no locking on resource availability) | 189 (S=9, O=3, D=7) | Add optimistic locking via assignment version vectors; show "resource busy" warning before form submit |
| Modal form has no input validation — empty location field creates assignment with blank location | 120 (S=5, O=4, D=6) | Add phx-change validation; disable Create button when required fields are empty |

---

## Page 4: `/cockpit/video-wall`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/video-wall` |
| Module | `IndrajaalWeb.Operations.VideoWallLive` |
| Title | "Live Video Wall" |
| Source | `lib/indrajaal_web/live/operations/video_wall_live.ex` |

### 2. Design Intent

The Video Wall is the multi-camera surveillance display for the operations center. It provides:

- Configurable grid layouts (2x2 / 3x3 / 4x4) to adapt to the number of cameras being monitored
- Per-camera group filtering (All, Entrances, Parking, Interior)
- Real-time analytics event overlay — motion detection, face recognition, vehicle LPN, loitering
- PTZ (Pan-Tilt-Zoom) controls for supported cameras
- Per-camera snapshot and clip recording actions
- Graceful degradation when the Video service is offline (offline banner with reconnect message)

The page addresses the operational need for operators to monitor multiple camera feeds simultaneously without context-switching between standalone VMS interfaces.

### 3. Expected Behavior (FUNCTIONAL)

**On Load (graceful degradation built-in):**
- All assigns are initialized with safe defaults BEFORE any service calls
- If Video service unavailable: `:video_wall_offline` set to true, amber warning banner shown
- If available: loads 9 cameras across entrance/parking/interior/exterior groups
- Cameras refresh every 5000ms

**Grid Display:**
- Default 2x2 grid shows first 4 cameras
- 3x3 shows first 9, 4x4 shows first 16
- Each camera tile: REC indicator (red pulsing), camera name, resolution, fps
- Video feed area: placeholder with play icon; MOTION badge if motion_detected
- Status overlay for offline cameras: shows "OFFLINE" text with surface overlay

**Camera Selection:**
- Clicking a camera selects it (cyan ring), shows controls panel in bottom-right corner (fixed position)
- Control panel shows: camera name, fullscreen toggle, PTZ controls (if camera.ptz == true), Snapshot and Record Clip buttons

**PTZ Controls:**
- Toggle Active/Inactive button per camera
- When active: directional pad (up/down/left/right/home), Zoom+/Zoom- buttons
- Each direction sends `ptz_command` event with direction string

**Analytics Events Feed:**
- Horizontal scroll feed below camera grid
- 5 event cards: motion (red icon), face (person icon), vehicle (car icon), loitering (warning icon)
- Each card: type icon, camera ID, timestamp, description

### 4. AS-IS State

**mount/3 assigns (initialized in two phases):**
```
Phase 1 (always):
:page_title           => "Live Video Wall"
:grid_layout          => "2x2"
:camera_group         => "all"
:cameras              => []
:analytics_events     => []
:selected_camera      => nil
:ptz_active           => false
:fullscreen           => false
:video_wall_offline   => false

Phase 2 (wrapped in rescue):
:cameras              => [9 camera structs with id, name, status, resolution, fps, recording, analytics, motion_detected, ptz, group]
:analytics_events     => [5 event structs with type, camera, timestamp, description]
```

**Timer:**
- `5000` ms — refreshes cameras and analytics events (wrapped in rescue for graceful degradation)

**PubSub Subscriptions:**
- `"video:analytics"` — handles `{:analytics_event, event}` to prepend to event list (max 10)

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"set_layout"` | `%{"layout" => layout}` | Sets `:grid_layout` ("2x2"/"3x3"/"4x4") |
| `"set_group"` | `%{"group" => group}` | Sets `:camera_group` filter |
| `"select_camera"` | `%{"id" => id}` | Finds camera, assigns to `:selected_camera` |
| `"toggle_fullscreen"` | `_` | Toggles `:fullscreen` boolean |
| `"toggle_ptz"` | `_` | Toggles `:ptz_active` boolean |
| `"ptz_command"` | `%{"direction" => dir}` | Flash info with direction |
| `"snapshot"` | `%{"id" => id}` | Flash info "Snapshot saved for camera {id}" |
| `"start_clip"` | `%{"id" => id}` | Flash info "Recording clip for camera {id}" |
| `"search_recordings"` | `_` | Flash info |

### 5. BDD Scenarios

```gherkin
Feature: Video Wall — Multi-Camera Surveillance Display

  Background:
    Given I navigate to "/cockpit/video-wall"

  Scenario: Default 2x2 grid shows 4 cameras
    Then I should see 4 camera tiles in a 2-column grid
    And I should see "Main Entrance", "Parking A", "Server Room", "Loading Dock"

  Scenario: Switch to 3x3 grid layout
    When I click "3x3" in the Layout selector
    Then the grid should show 3 columns
    And 9 camera tiles should be visible

  Scenario: Select a camera to show PTZ controls
    When I click on the "Main Entrance" camera tile
    Then a control panel should appear in the bottom-right corner
    And I should see "PTZ Control" with "Inactive" toggle button
    When I click the PTZ toggle to activate it
    Then directional arrow buttons should appear (up, down, left, right, home)

  Scenario: Video wall shows offline banner when service unavailable
    Given the Video service is offline
    Then an amber warning banner should appear at the top
    And it should contain "Video wall offline"
    And "The system will reconnect automatically"

  Scenario: Analytics events feed shows motion detection
    Given a motion event arrives on the "video:analytics" PubSub channel
    Then a new event card should appear at the start of the analytics feed
    And it should show the motion icon and camera name
```

### 6. UX Flow

1. Security supervisor opens `/cockpit/video-wall` — sees 4 cameras in 2x2 default
2. Incident reported at Loading Dock — switches to 3x3 to add more context cameras
3. Sees "MOTION" badge pulsing on cam-004 (Loading Dock)
4. Clicks cam-004 to select it — PTZ control panel appears
5. Enables PTZ, uses arrow controls to pan camera toward incident area
6. Takes snapshot for immediate evidence capture
7. Clicks "Record Clip" to capture a 30-second evidence clip
8. Monitors analytics event feed — sees face recognition event from cam-001
9. Filters group to "Entrances" to focus on entry points

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-change |
|---------|------|------------------------|
| 2x2 layout button | Button | `phx-click="set_layout"` `phx-value-layout="2x2"` |
| 3x3 layout button | Button | `phx-click="set_layout"` `phx-value-layout="3x3"` |
| 4x4 layout button | Button | `phx-click="set_layout"` `phx-value-layout="4x4"` |
| Camera group select | Select | `phx-change="set_group"` name="group" |
| Search Recordings | Button | `phx-click="search_recordings"` |
| Camera tile | Div | `phx-click="select_camera"` `phx-value-id` |
| Snapshot icon (per tile) | Button | `phx-click="snapshot"` `phx-value-id` |
| Clip icon (per tile) | Button | `phx-click="start_clip"` `phx-value-id` |
| Fullscreen toggle | Button | `phx-click="toggle_fullscreen"` |
| PTZ toggle | Button | `phx-click="toggle_ptz"` |
| PTZ up | Button | `phx-click="ptz_command"` `phx-value-direction="up"` |
| PTZ down | Button | `phx-click="ptz_command"` `phx-value-direction="down"` |
| PTZ left | Button | `phx-click="ptz_command"` `phx-value-direction="left"` |
| PTZ right | Button | `phx-click="ptz_command"` `phx-value-direction="right"` |
| PTZ home | Button | `phx-click="ptz_command"` `phx-value-direction="home"` |
| Zoom+ | Button | `phx-click="ptz_command"` `phx-value-direction="zoom_in"` |
| Zoom- | Button | `phx-click="ptz_command"` `phx-value-direction="zoom_out"` |
| Snapshot (detail panel) | Button | `phx-click="snapshot"` `phx-value-id` |
| Record Clip (detail panel) | Button | `phx-click="start_clip"` `phx-value-id` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Management by Exception — analytics overlay only shows badges when events occur |
| SC-HMI-002 | Analog over Digital — visual indicators (color dots, motion badge) preferred over numbers |
| SC-VID-001 | Video stream management — grid layout controls, recording indicators |
| SC-VID-002 | Analytics integration — motion/face/vehicle/loiter events wired to camera overlay |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| Camera refresh rescues exception silently; operator may not notice all cameras have gone offline | 210 (S=7, O=5, D=6) | Add camera offline count badge in header; log errors to `prajna:logs` PubSub |
| `motion_detected` field uses `:rand.uniform(10) > 7` in `generate_cameras` — random motion alerts could cause false operational responses | 250 (S=10, O=5, D=5) | Wire to real analytics service; clearly label demo mode with a banner |
| PTZ commands are fire-and-forget (flash only); no confirmation the PTZ command reached the camera | 168 (S=7, O=4, D=6) | Add acknowledgment timeout; show "PTZ command sent/acknowledged" status |

---

## Page 5: `/cockpit/knowledge`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/knowledge` |
| Module | `IndrajaalWeb.Prajna.KnowledgeLive` |
| Title | "Knowledge Management" |
| Source | `lib/indrajaal_web/live/prajna/knowledge_live.ex` |
| Version | 1.0.0 (2025-12-30) |
| Reference | NASA-STD-3000, Fractal Holonic Architecture |

### 2. Design Intent

The Knowledge Management page surfaces the Fractal Holonic Knowledge Management System (SMRITI/KMS) to operators. It follows NASA-STD-3000 information architecture principles and exists to:

- Show the organizational knowledge holon tree (knowledge, process, agent, artifact hierarchies)
- Track Architectural Decision Records (ADRs), RFCs, and Technical Specifications
- Monitor and surface technical debt with remediation status
- Visualize a Technology Radar snapshot (adopt/trial/assess/hold)
- Provide text search across all KMS holons via `KMS.search/2`

The page bridges the gap between the operational cockpit and the institutional knowledge base, making architecture health visible to operators in real time.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- `:view_mode` starts as `:tree` (tree view of holon hierarchy)
- KMS health badge shown in header (e.g., "KMS: HEALTHY")
- 5s refresh updates health report and debt summary
- Subscribes to `prajna:kms` for real-time holon events

**Sub-Navigation Modes:**
- Tree View: hierarchy of holon nodes with expand/collapse
- List View: flat list with type filter
- Decisions: recent ADRs/RFCs
- Tech Debt: debt items with severity and status
- Radar: technology quadrant visualization

**Search:**
- Search box with `phx-keyup="search"` and `phx-debounce="300"` (300ms debounce)
- Calls `KMS.search(query, limit: 20)` via `Indrajaal.KMS` module
- Returns results or empty list on error

**Type Filter:**
- Buttons for: all, knowledge, process, agent, artifact
- "all" type sets filter to nil

**Tree View:**
- Nodes have expand/collapse via `toggle_expand`
- Clicking a node selects it with `select_holon`
- Selected holon detail shown in a side panel

**View Mode Shortcuts:**
- "view_debt" event directly switches to `:debt` mode
- "view_radar" event directly switches to `:radar` mode

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title        => "Knowledge Management"
:view_mode         => :tree
:selected_holon    => nil
:holons            => load_holons()        (list from KMS)
:tree              => build_tree()         (hierarchical structure)
:health_report     => load_health_report() (KMS health from TechnicalLeadership)
:debt_summary      => load_debt_summary()  (debt from TechnicalLeadership)
:radar_snapshot    => load_radar_snapshot()
:recent_decisions  => load_recent_decisions()
:search_query      => ""
:search_results    => []
:filter_type       => nil
:expanded_nodes    => MapSet.new()
```

**Timer:**
- `@refresh_interval = 5000` ms — refreshes `:health_report` and `:debt_summary`

**PubSub Subscriptions:**
- `"prajna:kms"` — handles `{:kms_event, {:holon_created, holon}}` (prepends to holons, rebuilds tree) and `{:kms_event, {:holon_updated, holon}}` (updates in place)

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"select_holon"` | `%{"id" => id}` | Finds holon (supports both atom and string keys), assigns |
| `"toggle_expand"` | `%{"id" => id}` | Toggles id in `:expanded_nodes` MapSet |
| `"change_view"` | `%{"mode" => mode}` | Sets `:view_mode` atom |
| `"filter_type"` | `%{"type" => type}` | Sets `:filter_type` (nil for "all") |
| `"search"` | `%{"query" => query}` | Calls `KMS.search/2`, updates `:search_results` |
| `"create_adr"` | `_` | Flash info |
| `"create_holon"` | `_` | Flash info |
| `"view_debt"` | `_` | Sets `:view_mode` to `:debt` |
| `"view_radar"` | `_` | Sets `:view_mode` to `:radar` |

### 5. BDD Scenarios

```gherkin
Feature: Knowledge Management — SMRITI Holonic Knowledge System

  Background:
    Given I navigate to "/cockpit/knowledge"

  Scenario: KMS health badge visible in header
    Then I should see a "KMS:" badge in the header
    And the badge color should reflect the current health status

  Scenario: Switch to Tech Debt view
    When I click the "Tech Debt" sub-navigation button
    Then the view mode should switch to debt display
    And I should see debt items if any exist

  Scenario: Search for a holon
    Given the KMS search is functional
    When I type "user" in the search box and wait 300ms
    Then search results should appear matching "user" holons

  Scenario: Toggle expand a tree node
    Given I am in Tree View mode
    When I click the expand control for a top-level holon
    Then child nodes should appear below the parent

  Scenario: Switch to Radar view
    When I click the "Radar" sub-navigation button
    Then the Technology Radar visualization should appear
    With quadrants for adopt/trial/assess/hold
```

### 6. UX Flow

1. Architect opens `/cockpit/knowledge` — sees holon tree view
2. Checks KMS health badge in header for overall knowledge system health
3. Searches for "authentication" to find related holons
4. Selects a holon to see its metadata in the detail panel
5. Navigates to Tech Debt view to review open debt items
6. Clicks "View Radar" to see which technologies are in each quadrant
7. Switches to Decisions view to see recent ADRs
8. Clicks "Create ADR" to begin a new architectural decision record

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-keyup |
|---------|------|----------------------|
| View mode: Tree | Button | `phx-click="change_view"` `phx-value-mode="tree"` |
| View mode: List | Button | `phx-click="change_view"` `phx-value-mode="list"` |
| View mode: Decisions | Button | `phx-click="change_view"` `phx-value-mode="decisions"` |
| View mode: Tech Debt | Button | `phx-click="change_view"` `phx-value-mode="debt"` |
| View mode: Radar | Button | `phx-click="change_view"` `phx-value-mode="radar"` |
| Search input | Text | `phx-keyup="search"` `phx-debounce="300"` |
| Filter: all | Button | `phx-click="filter_type"` `phx-value-type="all"` |
| Filter: knowledge | Button | `phx-click="filter_type"` `phx-value-type="knowledge"` |
| Filter: process | Button | `phx-click="filter_type"` `phx-value-type="process"` |
| Filter: agent | Button | `phx-click="filter_type"` `phx-value-type="agent"` |
| Filter: artifact | Button | `phx-click="filter_type"` `phx-value-type="artifact"` |
| Holon tree node | Div | `phx-click="select_holon"` `phx-value-id` |
| Expand/collapse | Button | `phx-click="toggle_expand"` `phx-value-id` |
| Create ADR | Button | `phx-click="create_adr"` |
| Create Holon | Button | `phx-click="create_holon"` |
| View Debt shortcut | Button | `phx-click="view_debt"` |
| View Radar shortcut | Button | `phx-click="view_radar"` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Dark Cockpit defaults — monospace font, surface palette |
| SC-KMS-001 | SQLite+DuckDB only — KMS module must use SQLite/DuckDB storage exclusively |
| SC-KMS-004 | OODA cycle <100ms for queries — KMS.search should complete within 100ms |
| SC-KMS-007 | Decision traceability mandatory — ADR creation and recent decisions must be logged |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| `KMS.search/2` returns `{:error, reason}` (KMS GenServer down); page shows empty results with no error indicator | 175 (S=7, O=5, D=5) | Add error state to assigns; show "KMS unavailable" message in search results panel |
| holon keys can be either atom or string (noted in `select_holon`: `h[:id] || h["id"]`); inconsistent key types cause silent nil selections | 144 (S=6, O=4, D=6) | Normalize all KMS records to atom keys at load time; add struct validation |
| 5s refresh rebuilds full holon tree on every cycle; large trees could cause memory pressure and slow re-renders | 120 (S=4, O=5, D=6) | Incremental tree updates via PubSub events instead of full reload; cache tree build |

---

## Page 6: `/cockpit/sentinel`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/sentinel` |
| Module | `IndrajaalWeb.Prajna.SentinelDashboardLive` |
| Title | "Sentinel - Immune System" |
| Source | `lib/indrajaal_web/live/prajna/sentinel_dashboard_live.ex` |
| STAMP | SC-IMMUNE-001, SC-IMMUNE-007, SC-IMMUNE-008 |

### 2. Design Intent

The Sentinel Dashboard is the window into the Digital Immune System — the safety-critical threat detection, response, and quarantine subsystem. It exists to give operators a single-pane view of:

- The composite immune system health score (0-100%)
- Active threat count (real-time from `SentinelBridge.get_health/0`)
- Quarantined components count (from `SentinelBridge.get_quarantine_status/0`)
- Pattern detection count (from `SentinelBridge.get_advisories/0`)
- SLA response time targets by threat severity (Extinction/Critical/High)

The page is intentionally minimal — it surfaces the most critical immune system indicators without overwhelming operators with low-level detail. Deep investigation is handled in the Diagnostics page.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- Calls `SentinelBridge.get_health/0`, `get_advisories/0`, and `get_quarantine_status/0`
- All calls wrapped in try/rescue with fallback values if SentinelBridge is unavailable
- Health score defaults to 100% (score_percent: 100) if bridge is offline
- Refreshes every 5000ms

**4-Card Summary Row:**
- Health Score: green number showing `health.score_percent`
- Active Threats: red number showing `length(health.threats)`
- Quarantined: yellow number showing `length(quarantine)`
- Patterns Detected: blue number showing `length(advisories)`

**Response Times SLA Panel:**
- EXTINCTION: 100ms (red)
- CRITICAL: 500ms (orange)
- HIGH: 2000ms (yellow)

**Last Scan Timestamp:**
- Uses `health[:last_sync]` if available, else `DateTime.utc_now()`

**No interactive controls** — this is a read-only monitoring page. No handle_event callbacks.

### 4. AS-IS State

**mount/3 assigns (via `load_sentinel_data/1`):**
```
:page_title         => "Sentinel - Immune System"
:health_score       => health.score_percent / 1.0  (float)
:active_threats     => health.threats  (list)
:quarantined        => quarantine  (list)
:patterns_detected  => length(advisories)  (integer)
:response_times     => %{extinction: 100, critical: 500, high: 2000}
:last_scan          => health[:last_sync] || DateTime.utc_now()
```

**Timer:**
- `@refresh_interval = 5000` ms — calls `load_sentinel_data/1` which re-fetches all three SentinelBridge endpoints

**PubSub Subscriptions:**
- `"sentinel:threats"` — handles `%{event: "threat_detected"}` → calls `load_sentinel_data/1`
- `"prajna:threats"` — same handler pattern

**handle_info callbacks:**
| Message | Effect |
|---------|--------|
| `:refresh` | Calls `load_sentinel_data/1` to refresh all assigns |
| `%{event: "threat_detected"}` | Calls `load_sentinel_data/1` |
| `_any_other` | No-op |

**No handle_event callbacks** — page is read-only.

### 5. BDD Scenarios

```gherkin
Feature: Sentinel Dashboard — Digital Immune System Monitor

  Background:
    Given I navigate to "/cockpit/sentinel"

  Scenario: Health score displays when Sentinel is healthy
    Then I should see a "Health Score" card with a green number
    And the score should be between 0 and 100

  Scenario: Active threats count reflects real-time threat state
    Given the SentinelBridge reports 3 active threats
    Then the "Active Threats" card should show "3" in red

  Scenario: Dashboard auto-refreshes every 5 seconds
    Given I am on the Sentinel dashboard
    When 5 seconds elapse
    Then the health score should be updated from SentinelBridge

  Scenario: PubSub threat event triggers immediate refresh
    Given a threat_detected event is published to "sentinel:threats"
    Then the dashboard should immediately re-fetch SentinelBridge data
    And the active threats count should update

  Scenario: Dashboard degrades gracefully when SentinelBridge is offline
    Given the SentinelBridge GenServer is not running
    Then the dashboard should still render without crashing
    And the health score should show the fallback value of 100.0%
```

### 6. UX Flow

1. Security analyst opens `/cockpit/sentinel` — reads health score at a glance
2. If health score < 80, analyst notes active threat count
3. Monitors quarantine count — if rising, action is needed in the Diagnostics or Guardian page
4. Checks patterns detected for early warning indicators
5. Verifies SLA response times are within configured bounds
6. Waits for next 5s auto-refresh to confirm threat is being processed

### 7. UI Elements Inventory

| Element | Type | Notes |
|---------|------|-------|
| Health Score card | Display only | Shows `health_score` float as `Float.round(@health_score, 1)%` |
| Active Threats card | Display only | Shows `length(@active_threats)` |
| Quarantined card | Display only | Shows `length(@quarantined)` |
| Patterns Detected card | Display only | Shows `@patterns_detected` integer |
| EXTINCTION response time | Display only | Fixed 100ms |
| CRITICAL response time | Display only | Fixed 500ms |
| HIGH response time | Display only | Fixed 2000ms |
| Last scan timestamp | Display only | `@last_scan` formatted as UTC |

*No interactive elements — fully read-only page.*

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-IMMUNE-001 | Immune system health always visible |
| SC-IMMUNE-007 | Threat detection and display per immune response protocol |
| SC-IMMUNE-008 | Quarantine status visible to operators |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| SentinelBridge `:exit` catch returns 100% health score; operator believes system is healthy while bridge is actually down | 280 (S=10, O=4, D=7) | Add `:bridge_available` assign; show "Sentinel bridge offline — data may be stale" banner when fallback activates |
| `@refresh_interval` timer sends `:refresh` to `self()` but timer registration uses `self()` without the socket PID check (line 16: `:timer.send_interval(@refresh_interval, :refresh)` — missing `self()`) | 320 (S=8, O=8, D=5) | **Bug found**: change to `:timer.send_interval(@refresh_interval, self(), :refresh)` to ensure correct process targeting |
| No visual distinction between "health score 100% (healthy)" and "health score 100% (bridge offline fallback)" | 180 (S=9, O=4, D=5) | Show gray badge with "BRIDGE OFFLINE" when fallback activates |

---

## Page 7: `/cockpit/analytics`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/analytics` |
| Module | `IndrajaalWeb.Prajna.AnalyticsLive` |
| Title | "Analytics" |
| Source | `lib/indrajaal_web/live/prajna/analytics_live.ex` |
| Version | 1.0.0 (2026-01-02) |
| STAMP | SC-PRAJNA-004, SC-ANA-001 |

### 2. Design Intent

The Analytics Center provides operators with real-time visibility into the analytics subsystem health. It is not a reporting tool itself — it monitors the pipelines, queries, and jobs that produce reports. Its purpose:

- Show report generation status (completed/running/failed/scheduled) with progress bars for running reports
- Display query performance metrics by source (PostgreSQL, TimescaleDB, DuckDB)
- Monitor 4 data pipelines (Alarms ETL, Metrics Aggregation, Event Stream, Backup Sync)
- Surface trend analysis across 4 KPIs (alarm volume, response time, device uptime, false alarm rate)
- Alert operators to slow queries (>5s) and pipeline health degradation (<90%)

The page addresses the operational need to detect analytics subsystem degradation before reports start failing or data goes stale.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- 4 summary cards: Reports Today, Avg Query Time, Pipeline Health, Data Freshness
- Yellow warning border on Avg Query Time if > 5000ms
- Yellow warning border on Pipeline Health if < 90%
- Yellow warning border on Data Freshness if > 60 seconds
- 15 report entries spanning 5 types; 20 query entries from 3 sources

**Report Status Panel:**
- Status filter: All / Completed / Running / Failed / Scheduled
- Running reports show a progress bar that advances each refresh (by up to 10%, transitions to :completed at 100%)
- Clicking a report selects it (`:selected_report`) but detail view not yet rendered (`:close_detail` event exists)

**Query Performance Panel:**
- Shows top 10 queries sorted by recency
- Color-coded durations: green (<1000ms), yellow (1000-5000ms), red (>5000ms)
- Shows source database and row count per query

**Data Pipelines Panel:**
- 4 pipelines with source → target arrow, status badge, throughput/s, lag in seconds
- Alarms ETL (PostgreSQL → DuckDB), Metrics Aggregation (TimescaleDB → Redis), Event Stream (Kafka → PostgreSQL), Backup Sync (PostgreSQL → S3)

**Trend Analysis Panel:**
- 4 trend cards: Alarm Volume (up 12%), Response Time (down 8%), Device Uptime (up 0.3%), False Alarms (down 15%)
- Arrow indicators: ↑ green, ↓ red, → gray

**Metrics sync:** Every 10,000ms re-fetches metrics from BEAM intrinsics (run_queue → pipeline health, memory → query time proxy)

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title       => "Analytics"
:current_nav      => :analytics
:reports          => [15 report structs derived from BEAM process_count/ports]
:queries          => [20 query structs sorted by timestamp desc]
:pipelines        => [4 pipeline structs]
:trends           => [4 trend structs]
:filter_status    => :all
:selected_report  => nil
:metrics          => %{reports_today: 23, avg_query_time: 1250, pipeline_health: 98, data_freshness: 15}
```

**Timers:**
- `@refresh_interval = 5000` ms — refreshes reports (progress bars) and queries (may add new entry 33% chance)
- `@metrics_sync_interval = 10_000` ms — re-fetches metrics from BEAM intrinsics

**PubSub Subscriptions:**
- `"prajna:analytics"` — generic message handler (no-op for unknown messages)
- `"zenoh:analytics"` — same

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"filter_status"` | `%{"status" => status}` | Sets `:filter_status` atom via `String.to_existing_atom` |
| `"select_report"` | `%{"id" => id}` | Finds report, assigns to `:selected_report` |
| `"close_detail"` | `_` | Clears `:selected_report` |

### 5. BDD Scenarios

```gherkin
Feature: Analytics Center — Pipeline and Report Monitoring

  Background:
    Given I navigate to "/cockpit/analytics"

  Scenario: Summary cards show current metrics
    Then I should see "Reports Today" with a positive integer
    And I should see "Avg Query Time" in milliseconds
    And "Pipeline Health" should show a percentage
    And "Data Freshness" should show seconds

  Scenario: Filter reports to show only running jobs
    When I select "Running" from the report status filter
    Then only reports with status "running" should appear
    And each running report should show a progress bar

  Scenario: Running report progress advances on refresh
    Given a report is showing 50% progress
    When 5 seconds elapse (refresh interval)
    Then the progress should increase by up to 10%
    And if progress reaches 100%, the report status should change to "completed"

  Scenario: Slow query highlighted in red
    Given a query with duration > 5000ms exists
    Then its duration value should appear in red text

  Scenario: Data freshness warning appears when stale
    Given the data freshness metric exceeds 60 seconds
    Then the "Data Freshness" card should have a yellow warning border
```

### 6. UX Flow

1. Data engineer opens `/cockpit/analytics` — checks pipeline health score (target: 98%)
2. Reviews Reports Today count to ensure scheduled reports are completing
3. Filters report list to "Failed" to identify any failed report jobs
4. Checks query performance — looks for slow queries (>5s) that may indicate index problems
5. Reviews data pipeline lag: Alarms ETL should have <5s lag; Event Stream <5s
6. Checks trend analysis: if Response Time is trending up, may indicate alarm processing bottleneck
7. Waits for 10s metrics sync to confirm real-time system health

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-change |
|---------|------|------------------------|
| Report status filter | Select | `phx-change="filter_status"` name="status" |
| Report row | Div | `phx-click="select_report"` `phx-value-id` |
| Close detail | Button | `phx-click="close_detail"` (when detail panel open) |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Dark Cockpit defaults |
| SC-PRAJNA-004 | Sentinel health integration — pipeline health < 90% triggers visual warning |
| SC-BRIDGE-005 | PubSub topics `zenoh:analytics` and `prajna:analytics` subscribed |
| SC-ANA-001 | Query timeout < 30s — `avg_query_time` card alerts if > 5000ms |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| `refresh_queries` uses `:rand.uniform(3) == 1` to probabilistically add new queries; repeated over time creates unbounded list that could consume memory | 144 (S=6, O=4, D=6) | Cap at `Enum.take(queries, 20)` which is already done; confirm cap is always applied |
| `filter_status` calls `String.to_existing_atom` — if an unexpected status string is submitted, this raises a KeyError | 160 (S=5, O=4, D=8) | Add try/rescue around `String.to_existing_atom` or use explicit atom mapping |
| `refresh_reports` advances progress by `:rand.uniform(10)` — in production, report progress should come from the actual job system, not random increments | 180 (S=6, O=5, D=6) | Wire to Oban job tracking; show actual progress from job metadata |

---

## Page 8: `/cockpit/compliance`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/compliance` |
| Module | `IndrajaalWeb.Prajna.ComplianceLive` |
| Title | "Compliance" |
| Source | `lib/indrajaal_web/live/prajna/compliance_live.ex` |
| Version | 1.1.0 (2026-03-23) |
| STAMP | SC-PRAJNA-004, SC-COMP-001, SC-SAFETY-003 |

### 2. Design Intent

The Compliance Dashboard is the regulatory adherence monitoring center for the PRAJNA cockpit. It tracks four compliance frameworks (ISO 27001, GDPR, EN 50131, IEC 61508 SIL-2) with paginated audit trails and framework-scoped filtering. Its purpose:

- Show overall compliance score with SIL-6 threshold (90%) alert
- Display per-framework compliance percentages (scores: ISO 94%, GDPR 98%, EN 50131 91%, IEC 61508 89%)
- Provide a paginated (10/page) audit trail with regulation filter
- Track control effectiveness with dual framework+status filtering (max 20 controls shown)
- Surface open non-conformances with severity badges and due dates

The page enables compliance officers and auditors to assess regulatory posture without extracting data into spreadsheets.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- Uses `IndrajaalWeb.PrajnaComponents` for shared header/nav components
- 4 summary metric cards: Overall Compliance, Controls Effective, Open Findings, Evidence Items
- 4 framework cards: ISO 27001, GDPR, EN 50131, IEC 61508 SIL-2 — color-coded by status
- Controls panel (5 columns) with dual filter: framework + status
- Audit Trail panel (7 columns) with regulation filter and pagination
- Non-conformances section (shown only if count > 0): 2 sample NCs (HIGH and MEDIUM)

**Audit Trail Pagination:**
- Page size: 10 entries per page
- Navigation: Prev, page number buttons (±2 from current), Next
- Page range: `audit_page_range/2` computes first..last window around current page
- Regulation filter resets to page 1 when changed

**Control Filtering:**
- Filter by framework: All Frameworks / ISO 27001 / GDPR / EN 50131 / IEC 61508
- Filter by status: All Status / Compliant / Partial / Non-Compliant
- Shows up to 20 filtered controls with dot indicator, ID, name, evidence count

**Metrics refresh every 10s; metrics sync every 30s** (full re-fetch with BEAM intrinsics)

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title        => "Compliance"
:current_nav       => :compliance
:frameworks        => [4 framework structs: iso27001, gdpr, en50131, iec61508]
:controls          => [50 control structs across frameworks]
:audit_trail       => [30 audit entries, sorted desc by timestamp]
:evidence          => [25 evidence items]
:nonconformances   => [2 non-conformance items]
:filter_framework  => :all
:filter_status     => :all
:filter_regulation => :all
:audit_page        => 1
:selected_control  => nil
:last_update       => DateTime.utc_now()
:metrics           => %{overall_score, score_trend, controls_effective, controls_total, open_findings, evidence_count, evidence_trend}
:audit_page_size   => 10
```

**Timers:**
- `@refresh_interval = 10_000` ms — refreshes audit trail (may add new entry 20% chance) and evidence
- `@metrics_sync_interval = 30_000` ms — re-fetches compliance metrics with BEAM intrinsics

**PubSub Subscriptions:**
- `"prajna:compliance"` — no-op for unknown messages
- `"zenoh:compliance"` — no-op for unknown messages

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"filter_framework"` | `%{"framework" => fw}` | Sets atom, resets audit_page to 1 |
| `"filter_status"` | `%{"status" => status}` | Sets `:filter_status` atom |
| `"filter_regulation"` | `%{"regulation" => reg}` | Sets atom, resets audit_page to 1 |
| `"audit_page"` | `%{"page" => page_str}` | Parses integer, clamps to 1..max_page |
| `"select_control"` | `%{"id" => id}` | Finds control, assigns to `:selected_control` |
| `"close_detail"` | `_` | Clears `:selected_control` |

### 5. BDD Scenarios

```gherkin
Feature: Compliance Dashboard — Regulatory Framework Monitoring

  Background:
    Given I navigate to "/cockpit/compliance"

  Scenario: Overall compliance score visible with SIL-6 threshold note
    Then I should see an "Overall Compliance" card
    And it should show the current score as a percentage
    And it should note "SIL-6 threshold: 90%"

  Scenario: Framework cards show per-regulation scores
    Then I should see 4 framework cards: ISO 27001, GDPR, EN 50131, IEC 61508 SIL-2
    And each card should have a colored border based on status (compliant/partial)

  Scenario: Paginate through audit trail
    Given the audit trail has 30 entries
    When I view page 1 (showing entries 1-10)
    And I click "Next"
    Then I should see entries 11-20
    And the page indicator should show "Page 2 of 3"

  Scenario: Filter audit trail by regulation
    When I select "ISO 27001" from the Audit Trail regulation filter
    Then only audit entries tagged with ISO 27001 should appear
    And the page should reset to page 1

  Scenario: Filter controls by framework and status
    When I select "GDPR" from the framework filter
    And "Partial" from the status filter
    Then only GDPR controls with partial status should appear in the controls list
```

### 6. UX Flow

1. Compliance officer opens `/cockpit/compliance` — checks overall score against 90% SIL-6 threshold
2. Reviews framework cards — notes IEC 61508 SIL-2 is at 89% (below threshold, :partial status)
3. Clicks the IEC 61508 framework filter in Controls panel to see non-compliant controls
4. Changes status filter to "Non-Compliant" to narrow further
5. Selects a specific control to see its ID, name, evidence count, and last review date
6. Switches to audit trail — filters by IEC 61508 regulation to trace recent activity
7. Paginates through audit trail to find the last CONFIG_CHANGE event
8. Scrolls to non-conformances section — notes NC-2026-001 (HIGH, due 2026-01-15) needs immediate action

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-change |
|---------|------|------------------------|
| Controls framework filter | Select | `phx-change="filter_framework"` name="framework" |
| Controls status filter | Select | `phx-change="filter_status"` name="status" |
| Audit regulation filter | Select | `phx-change="filter_regulation"` name="regulation" |
| Audit Prev button | Button | `phx-click="audit_page"` `phx-value-page={page-1}` |
| Audit page number buttons | Button | `phx-click="audit_page"` `phx-value-page={n}` |
| Audit Next button | Button | `phx-click="audit_page"` `phx-value-page={page+1}` |
| Control row | Div | `phx-click="select_control"` `phx-value-id` |
| Close detail | Button | `phx-click="close_detail"` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Dark Cockpit — monospace font, prajna_header/prajna_nav components |
| SC-PRAJNA-004 | Sentinel health integration — overall score from BEAM-derived metrics |
| SC-BRIDGE-005 | PubSub topics zenoh:compliance and prajna:compliance subscribed |
| SC-COMP-001 | Audit log immutability — audit trail is append-only (new entries prepended, old never deleted) |
| SC-SAFETY-003 | Complete audit trail to Immutable Register — audit trail refreshes but all historical entries retained |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| `filter_regulation` filters audit entries by `Map.get(entry, :regulation, :all) == regulation` — but all 30 audit entries are generated without a `:regulation` field, so filtering by any regulation always returns empty results | 240 (S=8, O=8, D=4) | Add `:regulation` field to all audit trail entries based on the target (e.g., target containing "iso27001" maps to `:iso27001`) |
| `String.to_existing_atom` in `filter_framework` and `filter_regulation` — if unexpected framework string sent (e.g., attack vector), raises ArgumentError | 160 (S=5, O=4, D=8) | Use explicit pattern match or Map.get with known atoms; avoid String.to_existing_atom on user inputs |
| IEC 61508 SIL-2 score (89%) is below the SIL-6 90% threshold but the data is static — compliance officers may falsely believe the threshold violation is real | 135 (S=9, O=3, D=5) | Wire to actual compliance verification; add "data as of {timestamp}" stamp on each framework card |

---

## Page 9: `/cockpit/copilot`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/copilot` |
| Module | `IndrajaalWeb.Prajna.CopilotLive` |
| Title | "AI Copilot" |
| Source | `lib/indrajaal_web/live/prajna/copilot_live.ex` |
| Version | 1.0.0 (2025-12-27) |
| Reference | Endsley SA Model, SC-AI-001 |

### 2. Design Intent

The AI Copilot page augments operator decision-making with AI-generated insights while strictly enforcing the Human-in-the-Loop principle (SC-AI-001). It exists to:

- Surface anomaly detection, predictive maintenance, correlation analysis, and recommendations in one panel
- Provide a natural language query interface backed by both local BEAM introspection and optional LLM (Claude 3.5)
- Show confidence levels for all AI insights (SC-VDP-009)
- Allow operators to apply recommendations (with confirmation) or dismiss insights
- Never replace human judgment — all suggestions are explicitly labeled ADVISORY

The page implements a sophisticated NLP query parser (`parse_nl_query/1`) that handles metric queries, node status queries, alarm queries, and health queries with real BEAM telemetry responses. LLM integration uses `Indrajaal.KMS.AI` as fallback.

### 3. Expected Behavior (FUNCTIONAL)

**On Load:**
- 4 initial insights: Summary (system status), Anomaly (high CPU on app-03), Prediction (disk cleanup), Correlation (API latency)
- Copilot status bar: Local Analytics ACTIVE, LLM CONNECTED, Last Analysis timestamp, insights count
- LLM toggle button (green when ON)
- Refreshes every 5000ms — first insight (INS-001) is replaced with live BEAM data

**Insight List (8 columns):**
- Each insight shows: type icon+label, confidence percentage, related node (if any), expiry time
- Title, description, action items list (bullets)
- For :recommendation type: "APPLY RECOMMENDATION" button (green)
- All insights: "DISMISS" button (removes from list)
- If related_node present: "VIEW NODE" link to `/cockpit/mesh?node={node}`

**Query Interface (4 columns):**
- Free-text input with placeholder "What's causing high CPU on app-03?"
- ASK button (form submit) and CLEAR button
- Response panel with answer text and confidence percentage

**Query Intelligence:**
- Parses NL query for: metric type (cpu/memory/latency/disk/network), node reference, temporal context, intent
- Routes to specialized handlers: `answer_metric_query/2`, `answer_node_query/2`, `answer_alarm_query/1`, `answer_health_query/1`
- CPU queries return scheduler count, process count, reductions from `:erlang.statistics(:reductions)`
- Memory queries return total/processes/ETS memory from `:erlang.memory()`
- Health queries call `SentinelBridge.get_health/0` if available

**Insight Summary Panel:**
- Shows count per type: Anomalies, Predictions, Recommendations, Correlations

**Advisory Notice:**
- Blue panel: "AI suggestions are ADVISORY only. Human operator makes all final decisions. (SC-AI-001)"

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title        => "AI Copilot"
:insights          => [4 initial insights with id, type, title, description, confidence, related_node, action_items, expires]
:copilot_status    => %{local: :active, llm: :connected}
:last_analysis     => DateTime.utc_now()
:insights_count    => 142
:query             => ""
:query_result      => nil
:llm_enabled       => true
:selected_insight  => nil
:insight_icons     => %{summary: "●", anomaly: "⚠", prediction: "ℹ", recommendation: "✔", correlation: "↔"}
```

**Timer:**
- `@refresh_interval = 5000` ms — calls `maybe_refresh_insights/1` which replaces INS-001 with live BEAM metrics

**PubSub Subscriptions:**
- `"prajna:insights"` — handles `{:new_insight, insight}` to prepend to list (max 50)

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"analyze_now"` | `_` | Updates `:last_analysis`, flash info |
| `"toggle_llm"` | `_` | Toggles `:llm_enabled`, flash info |
| `"select_insight"` | `%{"id" => id}` | Sets `:selected_insight` to id string |
| `"apply_recommendation"` | `%{"id" => id}` | Flash info "Recommendation {id} applied" |
| `"dismiss_insight"` | `%{"id" => id}` | Removes insight from list |
| `"submit_query"` | `%{"query" => query}` | Calls `process_query/1`, stores result |
| `"clear_query"` | `_` | Clears `:query` and `:query_result` |

### 5. BDD Scenarios

```gherkin
Feature: AI Copilot — Human-in-the-Loop Advisory Intelligence

  Background:
    Given I navigate to "/cockpit/copilot"

  Scenario: Initial insights load with confidence levels
    Then I should see at least 4 insights
    And each insight should show "Confidence: XX%"
    And the advisory notice should state "AI suggestions are ADVISORY only"

  Scenario: Dismiss an insight
    Given insight "INS-002" (High CPU on app-03) is visible
    When I click "DISMISS" on insight "INS-002"
    Then insight "INS-002" should disappear from the list

  Scenario: Query about memory usage
    When I type "What is the current memory usage?" in the query input
    And I click "ASK"
    Then the response panel should show memory information including "MB"
    And a confidence percentage should be shown

  Scenario: Query about health status
    When I type "Show health status" in the query input
    And I click "ASK"
    Then the response should include a health score from SentinelBridge or BEAM fallback

  Scenario: Toggle LLM off
    Given LLM is enabled (button shows "LLM: ON" in green)
    When I click the LLM toggle button
    Then the button should show "LLM: OFF" in gray
    And a flash message should confirm "LLM disabled"
```

### 6. UX Flow

1. Operator opens `/cockpit/copilot` — reads the auto-generated system summary (INS-001, live BEAM data)
2. Reviews anomaly insight (app-03 CPU) — reads confidence 95%, notes recommended actions
3. If confident in the insight, clicks "APPLY RECOMMENDATION" (not a dangerous action — just flash feedback)
4. If insight is irrelevant, clicks "DISMISS" to remove it
5. Types a natural language question: "Why is app-03 CPU high?"
6. Receives structured response including scheduler count and process metrics
7. If response is insufficient, operator enables LLM and asks more complex question
8. Clicks "VIEW NODE" on app-03 to navigate to the mesh view for that node
9. Clicks "ANALYZE NOW" to force an immediate fresh analysis cycle

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-submit |
|---------|------|------------------------|
| ANALYZE NOW | Button | `phx-click="analyze_now"` |
| LLM toggle | Button | `phx-click="toggle_llm"` |
| Insight card | Div | `phx-click="select_insight"` `phx-value-id` |
| APPLY RECOMMENDATION | Button | `phx-click="apply_recommendation"` `phx-value-id` |
| DISMISS | Button | `phx-click="dismiss_insight"` `phx-value-id` |
| Query form | Form | `phx-submit="submit_query"` |
| Query input | Text | name="query" |
| ASK | Submit button | (via form) |
| CLEAR | Button | `phx-click="clear_query"` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-AI-001 | Human-in-the-Loop — advisory notice always visible; no automatic action from AI |
| SC-HMI-001 | Dark Cockpit defaults |
| SC-VDP-009 | Show confidence levels — all insights show `Confidence: XX%` |
| SC-EVAL-003 | SAGAT score > 90% — Endsley SA model applied to insight presentation |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| `process_query/1` calls `Process.list()` which is O(N) over all processes; on a high-process system (100K+ processes) this can add measurable latency to query responses | 160 (S=5, O=4, D=8) | Use `:erlang.system_info(:process_count)` instead of `length(Process.list())` for count; reserve Process.list only when detailed per-process info is needed |
| NLP parser uses regex `~r/(app|db|obs|zenoh|cortex)[-_]?(\d+)?/` — adversarial queries could inject unexpected patterns; `String.to_existing_atom` conversion not present here but fallback answer exposes query content | 90 (S=3, O=5, D=6) | Sanitize query length to 200 chars max before processing; already has 80-char slice in fallback |
| Dismissing all insights (empty list) shows "No active insights" — but the 5s refresh only updates INS-001; dismissed INS-002/3/4 never reappear unless new PubSub events arrive | 120 (S=4, O=5, D=6) | Add "refresh insights" button that reloads `init_insights/0`; or regenerate based on current BEAM state |

---

## Page 10: `/cockpit/alarm-investigation/:id`

### 1. Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/alarm-investigation/:id` |
| Module | `IndrajaalWeb.Operations.AlarmInvestigationLive` |
| Title | "Investigation: {alarm_id}" |
| Source | `lib/indrajaal_web/live/operations/alarm_investigation_live.ex` |

### 2. Design Intent

The Alarm Investigation page is the deep-dive forensic interface for a single alarm. It provides the operator with all evidence needed to make a resolution decision:

- Full alarm metadata (type, site, zone, device, severity, status, age)
- Chronological timeline of all state changes and operator actions
- Correlated events from adjacent systems (Access Control, Video Analytics, History)
- Video clip viewer linked to the camera that triggered the alarm
- AI Copilot advisory analysis with confidence level and recommendations
- Resolution workflow: Verify Alarm, False Alarm, Escalate, Close
- Investigation notes form for free-text operator observations

The page implements the NUREG-0700 investigation workflow: operators arrive at this page after acknowledging an alarm from the Active Alarms list, then follow the timeline to make an informed resolution decision.

### 3. Expected Behavior (FUNCTIONAL)

**On Load (with `:id` param):**
- Calls `get_alarm/1` with the alarm ID from params
- Generates timeline for the alarm (5 entries: triggered, enriched, acknowledged, dispatched, investigating)
- Loads 3 correlated events (access control, video analytics, alarm history)
- Generates AI insight with confidence score and recommendations

**On Load (without `:id`):**
- Falls back to `get_alarm("ALM-2024-00_142")` with sample data
- No live refresh or PubSub subscriptions — static investigation

**Alarm Summary Bar:**
- 4 metadata fields: Type, Site, Zone, Device
- Header: status badge (color-coded), severity badge (with icon + color), age display

**Timeline Panel:**
- Chronological list of events with: time (HH:MM:SS), type label (color-coded), content
- Timeline types: TRIGGERED (red), ENRICHED (cyan), ACKNOWLEDGED (green), DISPATCHED (amber), INVESTIGATING (purple), NOTE (gray)
- Operator can add notes via textarea form

**Correlated Events Panel:**
- 3 events from adjacent systems with source tags (Access Control, Video Analytics, History)

**Video Clip Panel:**
- Shows camera ID (e.g., "CAM-042")
- Placeholder player: click play button → shows "Playing... 00:00:15 / 00:00:30"
- Export and Save Clip buttons (flash only)

**AI Copilot Panel:**
- Confidence: "0.78" (string from `generate_ai_insight/0`)
- Analysis: "Low threat. Pattern matches authorized personnel entering during business hours."
- Recommendations list: 3 bullet points
- ADVISORY notice at bottom

**Action Buttons (2x2 grid):**
- Verify Alarm (green) — status → :verified
- False Alarm (gray) — status → :false_alarm
- Escalate (amber) — status → :escalated
- Close (cyan) — status → :closed

### 4. AS-IS State

**mount/3 assigns:**
```
:page_title          => "Investigation: {alarm_id}"
:alarm               => %{id, status: :investigating, severity: :caution, type: "INTRUSION",
                           site: "HQ Building", zone: "Zone-A North", device: "sensor-042",
                           camera: "CAM-042", timestamp: DateTime.add(now, -2700, :second),
                           triggered_by: "Motion + Door Contact"}
:timeline            => [5 generated timeline entries]
:correlated_events   => [3 correlated event structs]
:ai_insight          => %{confidence: "0.78", analysis: "...", recommendations: [...]}
:notes               => ""
:video_playing       => false
```

**No timer, no PubSub subscriptions.** This is a static investigation view.

**handle_event callbacks:**
| Event | Params | Effect |
|-------|--------|--------|
| `"verify"` | `_` | Updates `alarm.status` to `:verified`, flash info |
| `"false_alarm"` | `_` | Updates `alarm.status` to `:false_alarm`, flash info |
| `"escalate"` | `_` | Updates `alarm.status` to `:escalated`, flash warning |
| `"close"` | `_` | Updates `alarm.status` to `:closed`, flash info |
| `"add_note"` | `%{"note" => note}` | Appends timeline entry with type `:note`, clears `:notes` |
| `"play_video"` | `_` | Sets `:video_playing` to true |
| `"export_clip"` | `_` | Flash info "Video clip exported" |

### 5. BDD Scenarios

```gherkin
Feature: Alarm Investigation — Forensic Alarm Resolution Interface

  Background:
    Given alarm "ALM-2024-00_142" exists
    And I navigate to "/cockpit/alarm-investigation/ALM-2024-00_142"

  Scenario: View full alarm metadata on page load
    Then I should see "Investigation: ALM-2024-00_142" as the page heading
    And I should see status badge "INVESTIGATING" in amber
    And I should see severity badge "CAUTION" with the caution icon
    And I should see "Type: INTRUSION", "Site: HQ Building", "Zone: Zone-A North"

  Scenario: View timeline with ordered events
    Then I should see the timeline with "TRIGGERED" as the first entry
    And subsequent entries should include "ENRICHED", "ACKNOWLEDGED", "DISPATCHED"
    And each entry should show a timestamp in HH:MM:SS format

  Scenario: Add an investigation note
    When I type "Officer confirmed no suspicious activity" in the notes textarea
    And I click "Add Note"
    Then the note should appear at the bottom of the timeline as a "NOTE" entry
    And the textarea should be cleared

  Scenario: Verify the alarm
    When I click "Verify Alarm"
    Then the status badge should change to "VERIFIED" in red
    And a flash message should confirm "Alarm verified - dispatching response team"

  Scenario: Mark alarm as false alarm
    When I click "False Alarm"
    Then the status badge should change to "FALSE ALARM" in gray
    And a flash message should confirm "Marked as false alarm"

  Scenario: Play the video clip
    Given the video player shows a play button
    When I click the play button
    Then the player should show "Playing... 00:00:15 / 00:00:30"
```

### 6. UX Flow

1. Operator arrives from Active Alarms list, clicks "Investigate" on alarm ALM-2024-00_142
2. Reads alarm summary: INTRUSION, Zone-A North, sensor-042, age 45 minutes
3. Reviews timeline: alarm triggered 45 min ago, operator Sarah acknowledged 27s later, Team Alpha dispatched at 60s
4. Reads correlated events: access was granted to John Doe 2 minutes before alarm
5. Checks AI Copilot insight: "Low threat — pattern matches authorized personnel (confidence 0.78)"
6. Plays video clip to visually confirm person in zone
7. Reads operator note from 157s mark: "Officer en route"
8. After officer reports back "authorized maintenance worker", clicks "False Alarm"
9. Status badge changes to FALSE ALARM; case is closed

### 7. UI Elements Inventory

| Element | Type | phx-click / phx-submit |
|---------|------|------------------------|
| Back link | Link | `.link navigate={~p"/operations/alarms"}` |
| Play video button | Button | `phx-click="play_video"` |
| Export clip | Button | `phx-click="export_clip"` |
| Save Clip | Button | (no phx-click — display only) |
| Notes textarea | Textarea | name="note" |
| Add Note form | Form | `phx-submit="add_note"` |
| Verify Alarm | Button | `phx-click="verify"` |
| False Alarm | Button | `phx-click="false_alarm"` |
| Escalate | Button | `phx-click="escalate"` |
| Close | Button | `phx-click="close"` |

### 8. STAMP Constraints

| Constraint | Application |
|------------|-------------|
| SC-HMI-001 | Management by Exception — severity and status badges prominently colored |
| SC-HMI-004 | Two-step commit for critical actions — currently NOT implemented; Verify/Escalate are single-click; this is a gap |
| SC-AI-001 | AI suggestions are ADVISORY only — "Note: AI suggestions are ADVISORY only" explicitly shown |

### 9. FMEA Risks

| Failure Mode | RPN | Mitigation |
|--------------|-----|------------|
| SC-HMI-004 gap: "Verify Alarm" dispatches a response team but has no arm/fire two-step confirmation — accidental click could dispatch resources to a false alarm | 270 (S=9, O=3, D=10) | Implement two-step commit for "Verify Alarm" and "Escalate": add `:action_armed` assign; first click arms, second click executes (per AOR-COV-010) |
| `get_alarm/1` always returns the same mock struct regardless of the `:id` param — in production this means the wrong alarm data would show for all IDs | 350 (S=10, O=5, D=7) | Wire to actual alarm lookup via `Indrajaal.Alarms` context; return 404 or redirect if alarm not found |
| No PubSub subscription means that if another operator resolves the same alarm simultaneously, this view shows stale status indefinitely | 200 (S=8, O=5, D=5) | Subscribe to `alarm:{id}` PubSub channel; update assigns when status change received from another operator |

---

## Cross-Page Summary

### Refresh Interval Matrix

| Page | Refresh Interval | PubSub Topics | OODA Cycle |
|------|-----------------|---------------|------------|
| Diagnostics | 1000ms (log stream) | `prajna:logs` | Real-time |
| Test Cockpit | 5000ms (fitness/OODA) | `prajna:test_evolution` | 5s |
| Dispatch Console | 3000ms (positions) | `dispatch:events` | 3s |
| Video Wall | 5000ms (camera status) | `video:analytics` | 5s |
| Knowledge | 5000ms (health/debt) | `prajna:kms` | 5s |
| Sentinel | 5000ms (immune health) | `sentinel:threats`, `prajna:threats` | 5s |
| Analytics | 5000ms + 10000ms metrics | `prajna:analytics`, `zenoh:analytics` | 5-10s |
| Compliance | 10000ms + 30000ms metrics | `prajna:compliance`, `zenoh:compliance` | 10-30s |
| AI Copilot | 5000ms (insights) | `prajna:insights` | 5s |
| Alarm Investigation | No timer | None | Static |

### Two-Step Commit Compliance (SC-HMI-004)

| Page | Critical Action | Two-Step Implemented |
|------|-----------------|---------------------|
| Dispatch Console | Create Assignment, Escalate | Partial (modal for create; escalate is single-click) |
| Video Wall | None | N/A |
| Alarm Investigation | Verify Alarm, Escalate | **NO — Gap, RPN 270** |
| Compliance | None | N/A |
| AI Copilot | Apply Recommendation | No (flash only, not destructive) |

### Interactive Complexity Tier Assessment

| Page | Tier | Events | PubSub | Timer | Complexity |
|------|------|--------|--------|-------|------------|
| Diagnostics | 1 (High) | 10 | 1 | 1000ms | High — log stream, 5 tabs |
| Test Cockpit | 1 (High) | 8 | 1 | 5000ms | High — BiomorphicTestEvolution integration |
| Dispatch Console | 2 (Medium) | 11 | 1 | 3000ms | Medium — assignment state management |
| Video Wall | 2 (Medium) | 9 | 1 | 5000ms | Medium — grid layout + PTZ controls |
| Knowledge | 2 (Medium) | 9 | 1 | 5000ms | Medium — KMS.search integration |
| Sentinel | 3 (Low) | 0 | 2 | 5000ms | Low — read-only display |
| Analytics | 2 (Medium) | 3 | 2 | 5000ms+10s | Medium — report/query monitoring |
| Compliance | 2 (Medium) | 6 | 2 | 10000ms+30s | Medium — pagination + dual filters |
| AI Copilot | 1 (High) | 7 | 1 | 5000ms | High — NLP query processing |
| Alarm Investigation | 2 (Medium) | 7 | 0 | None | Medium — forensic workflow |

---

## STAMP Compliance Summary

| Constraint | Pages Affected | Status |
|------------|---------------|--------|
| SC-HMI-001 (Dark Cockpit) | All 10 pages | Compliant |
| SC-HMI-004 (Two-step commit) | Dispatch, Alarm Investigation | Partial gap in Alarm Investigation |
| SC-AI-001 (Human-in-the-Loop) | Copilot, Alarm Investigation | Compliant — advisory notices present |
| SC-VDP-009 (Confidence levels) | Copilot | Compliant |
| SC-VDP-010 (Temporal context) | Diagnostics | Compliant |
| SC-COMP-001 (Audit immutability) | Compliance | Compliant |
| SC-SAFETY-003 (Audit trail) | Compliance | Compliant |
| SC-KMS-001 (SQLite+DuckDB) | Knowledge | Compliant (via KMS module) |
| SC-ANA-001 (Query timeout) | Analytics | Partial — no timeout enforcement |
| SC-IMMUNE-001 (Immune health) | Sentinel | Compliant |
| SC-DSP-001/002 (Dispatch workflow) | Dispatch Console | Compliant |
| SC-VID-001/002 (Video management) | Video Wall | Compliant |

---

*Document generated from source analysis of all 10 LiveView .ex files.*
*Source paths: `lib/indrajaal_web/live/prajna/` and `lib/indrajaal_web/live/operations/`*
