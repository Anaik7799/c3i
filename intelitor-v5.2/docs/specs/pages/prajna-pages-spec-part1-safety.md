# Prajna Page Specifications — Part 1: P0 Safety-Critical Pages

**Generated**: 20260328-2100 CEST
**Purpose**: Comprehensive design, intent, expected behavior, BDD, and UX specs for each LiveView page
**Compliance**: SC-COV-008, SC-HMI-010, SC-UIGT-001
**Source**: Extracted from actual .ex LiveView source files — all AS-IS sections reflect real code
**Pages covered**: 8 P0 safety-critical pages
**Version**: 1.0.0

---

## Table of Contents

1. [Commands — `/cockpit/commands`](#1-commands--cockpitcommands)
2. [Shutdown — `/cockpit/shutdown`](#2-shutdown--cockpitshutdown)
3. [Guardian — `/cockpit/guardian`](#3-guardian--cockpitguardian)
4. [Alarms — `/cockpit/alarms`](#4-alarms--cockpitalarms)
5. [Threat — `/cockpit/threat`](#5-threat--cockpitthreat)
6. [Cluster — `/cockpit/cluster`](#6-cluster--cockpitcluster)
7. [Active Alarms — `/cockpit/active-alarms`](#7-active-alarms--cockpitactive-alarms)
8. [Settings — `/cockpit/settings`](#8-settings--cockpitsettings)

---

## 1. Commands — `/cockpit/commands`

### 1.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/commands` |
| Module | `IndrajaalWeb.Prajna.CommandsLive` |
| Source | `lib/indrajaal_web/live/prajna/commands_live.ex` |
| Page Title | "Command Center" |
| Reference Standards | MIL-STD-1472H, NUREG-0700 |
| Version | 1.0.0 |

### 1.2 Design Intent

The Command Center implements the MIL-STD-1472H two-step commit (Arm then Fire) pattern to prevent accidental execution of safety-critical system operations. Mode confusion is the leading cause of accidents in high-stress operator environments (Redmill & Rajan, 1997). The page provides a cognitive barrier against errors via:

- Visual and behavioral distinction between critical (two-step) and standard (immediate) commands
- Timeout-based auto-cancel at 300 seconds to prevent stale armed commands
- Animated countdown display to create operator urgency awareness
- Command history for auditability

Three command categories map to safety risk levels:
- **Critical**: restart, shutdown, power_off, isolate, hibernate, emergency_stop — require Arm + confirmation code entry
- **Standard**: power_on, health_check, clear_alarms, resume_network — execute immediately
- **Scaling**: scale_flame_up, scale_flame_down, set_load_balancer — execute immediately

### 1.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- Operator sees target selection panel with 5 pre-configured targets (app-01 through app-05)
- Default selected target is `app-01`
- Three command panels displayed: Critical Commands (red border), Standard Commands, Scaling
- Empty command history panel on right side
- Navigation tabs show COMMANDS as active
- Footer shows keyboard shortcuts: [A] Arm, [C] Confirm, [X] Cancel, [Esc] Cancel

**Critical command flow:**
1. Operator clicks a critical command button (e.g., RESTART)
2. Page transitions to confirmation modal — full-page overlay replaces command grid
3. Modal shows: target, command name, armed-by identity, armed-at timestamp, countdown timer
4. Yellow warning box displays command-specific risk text
5. Confirmation code is shown to operator (e.g., "A7" derived from target + command length)
6. Operator types confirmation code into text input
7. CONFIRM button enables only when typed code matches expected code
8. On confirm: flash `:info`, command enters history as `:executing`, modal closes
9. After 2000ms simulated delay: history entry updates from `:executing` to `:success`
10. If countdown reaches 0: auto-cancel fires, armed_command cleared, modal closes

**Standard/scaling command flow:**
1. Operator clicks standard command
2. History entry added immediately with `:success` status and 1.2s simulated duration
3. Flash `:info` message confirms execution

**Command history:**
- Displays last 10 entries in right sidebar
- Each entry shows: status icon (colored), timestamp (HH:MM:SS), target, command name, status badge

### 1.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval 1000           # 1s tick for countdown
@arm_timeout_seconds 300         # 5-minute armed command TTL

@critical_commands [:restart, :shutdown, :power_off, :isolate, :hibernate, :emergency_stop]
@standard_commands [:power_on, :health_check, :clear_alarms, :resume_network]
@scaling_commands [:scale_flame_up, :scale_flame_down, :set_load_balancer]
```

**mount/3 assigns:**
```elixir
:page_title          => "Command Center"
:armed_command       => nil
:arm_countdown       => 0
:selected_target     => "app-01"
:targets             => available_targets()   # 5 static entries
:command_history     => []
:confirmation_code   => ""
:show_confirmation   => false
:command_icons       => %{...}   # 13 unicode icons
:status_icons        => %{...}   # 6 state icons
:critical_commands   => @critical_commands
:standard_commands   => @standard_commands
:scaling_commands    => @scaling_commands
```

**PubSub subscriptions (connected only):**
- `"prajna:commands"`

**Timers (connected only):**
- `:timer.send_interval(1000, self(), :tick)` — countdown decrement

**handle_info callbacks:**
```elixir
:tick                                  # Decrement arm_countdown; auto-cancel at 0
{:command_result, cmd_id, result}      # Update history entry status (success/failed)
```

**handle_event callbacks:**
```elixir
"select_target"       %{"target" => target}    # Sets selected_target
"arm_command"         %{"command" => command}   # Critical: shows confirmation modal; Standard: executes
"update_confirmation" %{"code" => code}         # Updates confirmation_code input
"confirm_command"     {}                        # Executes armed command if code matches
"cancel_command"      {}                        # Clears armed_command, hides modal
```

**Confirmation code generation:**
```elixir
# Code = first letter of target (uppercase) + (command string length mod 10)
# Example: target="app-01", command=:restart (7 chars) → "A7"
defp generate_expected_code(%{target: target, command: command})
```

**Available targets (static list):**
```
app-01: supervisor, healthy
app-02: controller, healthy
app-03: controller, caution
app-04: controller, healthy
app-05: worker, healthy
```

### 1.5 BDD Scenarios

```gherkin
Feature: Command Center Two-Step Commit
  Background:
    Given I navigate to "/cockpit/commands"
    And the page loads with "Command Center" title

  Scenario: ARM-001 — Standard command executes immediately
    When I click the "HEALTH CHECK" standard command button
    Then I see a flash message "HEALTH CHECK executed successfully"
    And the command history shows one entry with status "SUCCESS"
    And no confirmation modal appears

  Scenario: ARM-002 — Critical command requires two-step confirm
    When I click the "RESTART" critical command button
    Then the confirmation modal appears with title "COMMAND ARMED - CONFIRM EXECUTION"
    And I see the target "app-01" displayed
    And I see a countdown timer starting at "5:00"
    And I see a yellow warning about connection draining

  Scenario: ARM-003 — Invalid confirmation code blocks execution
    Given the "RESTART" command is armed on target "app-01"
    When I type "XX" in the confirmation code field
    Then the CONFIRM button remains disabled
    And no command is added to history

  Scenario: ARM-004 — Correct confirmation code executes command
    Given the "RESTART" command is armed on target "app-01"
    When I type the correct confirmation code in the input
    Then the CONFIRM button becomes enabled
    And I click the CONFIRM button
    Then a flash message "Command restart executing on app-01" appears
    And the modal closes
    And the history shows "RESTART" with status "EXECUTING"
    And after 2 seconds the history status updates to "SUCCESS"

  Scenario: ARM-005 — Cancel clears armed state
    Given the "SHUTDOWN" command is armed on target "app-02"
    When I click the "Cancel" button
    Then the confirmation modal disappears
    And the command grid is shown again
    And no history entry was added
```

### 1.6 UX Flow

**Standard command execution:**
```
Landing → Select Target (optional) → Click Standard Command → Flash confirmation → History updated
```

**Critical command execution:**
```
Landing
  → Select Target
  → Click Critical Command (red panel)
  → Confirmation modal appears (full-page replacement)
     → Read warning text
     → Note confirmation code displayed
     → Type confirmation code into input
     → CONFIRM button activates
     → Click CONFIRM
  → Flash info message
  → History entry appears as EXECUTING
  → 2s later → History entry updates to SUCCESS
  → Command grid returns
```

**Expired arm timeout:**
```
Confirmation modal
  → Watch countdown decrease
  → At 0:00 → Auto-cancel fires
  → Modal closes without execution
  → No history entry added
```

### 1.7 UI Elements Inventory

**Navigation bar:**
- `PRAJNA C3I` (link to `/cockpit`)
- `COMMAND CENTER` (text label)
- Animated armed-command status ("COMMAND ARMED - 4:59") — shown only when armed
- Clock display (UTC HH:MM:SS)

**Navigation tabs:**
- OVERVIEW (`/cockpit`), MESH (`/cockpit/mesh`), ALARMS (`/cockpit/alarms`), COMMANDS (active), AI COPILOT, CONTAINERS

**Target selection panel (heading "SELECT TARGET"):**
- 5 target buttons — `phx-click="select_target"` `phx-value-target={target.id}`
- Each shows: target name + colored status dot (green=healthy, yellow=caution)

**Critical commands panel (heading "CRITICAL COMMANDS (Two-Step Required)", red border):**
- 6 buttons in 3-column grid — `phx-click="arm_command"` `phx-value-command={cmd}`
- RESTART, SHUTDOWN, POWER OFF, ISOLATE, HIBERNATE, EMERGENCY STOP

**Standard commands panel (heading "STANDARD COMMANDS (Immediate)"):**
- 4 buttons in 4-column grid — `phx-click="arm_command"` `phx-value-command={cmd}`
- POWER ON, HEALTH CHECK, CLEAR ALARMS, RESUME NETWORK

**Scaling panel (heading "SCALING"):**
- 3 buttons in 3-column grid — `phx-click="arm_command"` `phx-value-command={cmd}`
- SCALE FLAME UP, SCALE FLAME DOWN, SET LOAD BALANCER

**Command history sidebar (heading "COMMAND HISTORY (Last 10)"):**
- Scrollable list; each row: status icon, timestamp, target, command name, status badge

**Confirmation modal (replaces grid when show_confirmation=true):**
- Yellow-bordered panel, title "COMMAND ARMED - CONFIRM EXECUTION"
- Target/Command/Armed-by/Armed-at/Expires-in details grid
- Warning text box (yellow background)
- Confirmation code label and text input — `phx-keyup="update_confirmation"` `phx-value-code={...}`
- CONFIRM button — `phx-click="confirm_command"` (disabled until code matches)
- Cancel button — `phx-click="cancel_command"`

**Footer (fixed bottom):**
- Keyboard hints: [A] Arm, [C] Confirm, [X] Cancel, [Esc] Cancel
- Compliance label: "Two-Step Commit: MIL-STD-1472H Compliant | SC-HMI-004"

### 1.8 STAMP Constraints

| Constraint | Description | How This Page Complies |
|------------|-------------|----------------------|
| SC-HMI-004 | Two-step commit UI for destructive actions | Critical commands always arm first, require code confirmation |
| SC-MIL-001 to SC-MIL-004 | Feedback latency requirements | Flash messages appear synchronously; history updates within 2s |
| SC-VDP-008 | Closure feedback on command completion | History entry transitions from EXECUTING to SUCCESS/FAILED |
| SC-EMR-057 | Emergency stop capability | EMERGENCY STOP in critical commands list |
| SC-SAFETY-001 | Guardian pre-approval for mutations | NOTE: current implementation does NOT call Guardian.validate — gap identified |

### 1.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Confirmation code displayed in plain text allows replay attack | 7 | 4 | 6 | 168 | Code should be one-time-use per session; current derivation is deterministic from target+command |
| Armed command expires while operator is typing — silent discard | 6 | 5 | 7 | 210 | Visual countdown helps but operator may not notice; add audible alert near expiry |
| Guardian pre-approval bypass — commands execute without Guardian.validate | 9 | 8 | 3 | 216 | Wire all command execution paths through Guardian before production use |

---

## 2. Shutdown — `/cockpit/shutdown`

### 2.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/shutdown` |
| Module | `IndrajaalWeb.Prajna.ShutdownLive` |
| Source | `lib/indrajaal_web/live/prajna/shutdown_live.ex` |
| Page Title | "System Shutdown" |
| Reference Standards | NASA-STD-3000, MIL-STD-1472H |
| Version | 1.0.0 |

### 2.2 Design Intent

Provides a controlled, observable shutdown of the PRAJNA C3I system following NASA-STD-3000 shutdown/emergency sequence principles. The page visualizes a 5-phase shutdown sequence with per-step progress, live log stream, and abort/force controls. Operators can:

- Configure shutdown mode (graceful/quick) and drain timeout before initiating
- Observe each phase completing in real time
- Abort a graceful shutdown while it is running
- Execute a force immediate shutdown (second two-step within the page) when graceful is insufficient

The header turns red when shutdown is active — a strong visual signal that the system is in a critical state. SC-EMR-057 requires emergency stop capability; the force shutdown path provides this with a two-step arm-then-confirm sequence.

### 2.3 Expected Behavior (FUNCTIONAL)

**Pre-shutdown state (default):**
- Yellow warning panel explaining consequences
- Mode selector: Graceful (default) or Quick
- Drain timeout selector: 15s, 30s (default), 60s
- Single large red "INITIATE SHUTDOWN SEQUENCE" button

**Active shutdown:**
- Header background turns red; "SHUTDOWN IN PROGRESS" animated label
- Shutdown info bar shows: initiated-by identity, started-at timestamp, mode + drain timeout
- 5 phase panels each with: phase name, progress bar, step list with status icons
- Step states progress: pending (gray) → in_progress (blue animated) → completed (green) → failed (red)
- Shutdown log panel shows timestamped messages (most recent first)
- Estimated time remaining countdown
- Control buttons: "FORCE IMMEDIATE SHUTDOWN" (arm) and "ABORT SHUTDOWN"

**Abort:**
- Any time during active shutdown (while not force-confirm visible)
- Immediately sets `aborted: true`, `shutdown_active: false`
- Flash `:warning` message
- Aborted state shows dedicated panel with "RETURN TO COCKPIT" link

**Force shutdown (two-step within this page):**
- Click "FORCE IMMEDIATE SHUTDOWN" → sets `force_confirm: true`
- Inline confirm dialog replaces the two buttons
- "CONFIRM" triggers force_shutdown_confirm → flash `:error` (data loss warning)
- "CANCEL" hides the dialog and restores the two main buttons

**Shutdown sequence simulation:**
- Phases advance via `:advance_shutdown` internal messages every 500ms
- Each step has 40% probability of completing per tick
- Progress is computed as completed_steps / total_steps × 100
- Log entries auto-generate based on step completions

### 2.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval 500   # Phase advancement timer (500ms)

@phases [               # 5 phases, 4 steps each = 20 total steps
  %{id: :draining,    name: "PHASE 1: CONNECTION DRAINING",    steps: [block_new, notify_ws, drain_req, endpoint]},
  %{id: :jobs,        name: "PHASE 2: BACKGROUND JOBS",        steps: [pause_oban, complete_jobs, persist_jobs]},
  %{id: :state,       name: "PHASE 3: STATE PRESERVATION",     steps: [cockpit_snap, metric_export, audit_final, cubdb_sync]},
  %{id: :distributed, name: "PHASE 4: DISTRIBUTED TEARDOWN",   steps: [flame_drain, cluster_leave, zenoh_close, tailscale]},
  %{id: :containers,  name: "PHASE 5: CONTAINER SHUTDOWN",     steps: [app_stop, obs_stop, redis_stop, db_stop]}
]
```

**mount/3 assigns:**
```elixir
:page_title          => "System Shutdown"
:shutdown_active     => false
:phases              => @phases                    # All steps pending
:logs                => []
:started_at          => nil
:estimated_remaining => 0
:mode                => :graceful
:drain_timeout       => 30
:aborted             => false
:force_confirm       => false
:initiated_by        => nil
:status_icons        => %{completed: "✓", in_progress: "●", pending: "○", failed: "✗"}
```

**PubSub subscriptions:** None

**Timers:** None on mount — timer created dynamically when shutdown initiated via `Process.send_after/3`

**handle_info callbacks:**
```elixir
:advance_shutdown    # Advances phase steps (40% completion chance per step per tick); re-schedules itself while active and not aborted
```

**handle_event callbacks:**
```elixir
"initiate_shutdown"     {}                         # Starts shutdown: sets shutdown_active, created_at, begins phase advancement
"abort_shutdown"        {}                         # Halts sequence: aborted=true, shutdown_active=false
"force_shutdown_arm"    {}                         # Shows inline confirm dialog: force_confirm=true
"force_shutdown_confirm"{}                         # Executes force halt: flash :error
"force_shutdown_cancel" {}                         # Hides confirm dialog: force_confirm=false
"update_mode"          %{"mode" => mode}           # Sets shutdown mode atom
"update_timeout"       %{"timeout" => timeout}     # Sets drain_timeout integer
```

### 2.5 BDD Scenarios

```gherkin
Feature: System Shutdown Sequence
  Background:
    Given I navigate to "/cockpit/shutdown"
    And the page title is "System Shutdown"

  Scenario: SHD-001 — Pre-shutdown configuration displayed
    Then I see the yellow warning panel
    And I see a "Shutdown Mode" selector defaulting to "Graceful"
    And I see a "Drain Timeout" selector defaulting to 30 seconds
    And I see the "INITIATE SHUTDOWN SEQUENCE" red button

  Scenario: SHD-002 — Initiating shutdown changes header and begins phases
    When I click "INITIATE SHUTDOWN SEQUENCE"
    Then the header background turns red
    And I see "SHUTDOWN IN PROGRESS" in the header
    And I see "PHASE 1: CONNECTION DRAINING" with progress bar
    And I see "Initiating graceful shutdown..." in the shutdown log

  Scenario: SHD-003 — Phases advance automatically
    Given shutdown is active
    When 3 seconds elapse
    Then at least one step shows status "completed" (green checkmark)
    And the phase progress bar percentage is greater than 0

  Scenario: SHD-004 — Abort halts sequence
    Given shutdown is active
    When I click "ABORT SHUTDOWN"
    Then I see a flash warning "Shutdown aborted - system resuming normal operation"
    And I see the "SHUTDOWN ABORTED" panel
    And I see a "RETURN TO COCKPIT" link

  Scenario: SHD-005 — Force shutdown two-step from active shutdown
    Given shutdown is active
    When I click "FORCE IMMEDIATE SHUTDOWN"
    Then an inline confirm dialog appears: "Confirm force shutdown?"
    And I see CONFIRM and CANCEL buttons
    When I click CONFIRM
    Then I see a flash error about immediate halt and data loss
```

### 2.6 UX Flow

```
Landing (pre-shutdown)
  → Read warning
  → Choose mode (Graceful/Quick) — optional
  → Choose drain timeout — optional
  → Click "INITIATE SHUTDOWN SEQUENCE"
  → Header turns red: "SHUTDOWN IN PROGRESS"
  → Watch phases advance (5 phases, ~20 steps)
  → Read shutdown log messages
  → (Option A) Wait for all phases to complete → "Shutdown complete"
  → (Option B) Click "ABORT SHUTDOWN" → aborted state → return to cockpit
  → (Option C) Click "FORCE IMMEDIATE SHUTDOWN" → arm → confirm → immediate halt
```

### 2.7 UI Elements Inventory

**Header (dynamic background):**
- Normal: `bg-surface-secondary`
- Active: `bg-red-900`
- `PRAJNA C3I` link to `/cockpit`
- Status label: "SHUTDOWN IN PROGRESS" (red, when active) or "SYSTEM SHUTDOWN"
- Clock display

**Pre-shutdown form panel (shown when `not shutdown_active and not aborted`):**
- Yellow warning panel heading "⚠ System Shutdown"
- `select` (mode) — `phx-change="update_mode"` name="mode" — options: graceful, quick
- `select` (timeout) — `phx-change="update_timeout"` name="timeout" — options: 15, 30, 60
- `button` "INITIATE SHUTDOWN SEQUENCE" — `phx-click="initiate_shutdown"`

**Active shutdown display (shown when `shutdown_active and not aborted`):**
- Info bar: initiated_by, started_at, mode + drain_timeout
- 5 phase panels each containing:
  - Phase name, progress bar (green/blue/red/gray), percentage
  - Step list (○ pending, ● in-progress, ✓ completed, ✗ failed)
  - Steps with `:count` show remaining count in parentheses
- Shutdown log panel (scrollable, 10 entries visible)
- Estimated time remaining label OR "Shutdown complete"
- Control area (when `not force_confirm`):
  - `button` "⊘ FORCE IMMEDIATE SHUTDOWN" — `phx-click="force_shutdown_arm"`
  - `button` "ABORT SHUTDOWN" — `phx-click="abort_shutdown"`
- Force confirm area (when `force_confirm`):
  - Inline red panel: "Confirm force shutdown?"
  - `button` "CONFIRM" — `phx-click="force_shutdown_confirm"`
  - `button` "CANCEL" — `phx-click="force_shutdown_cancel"`

**Aborted state panel:**
- "SHUTDOWN ABORTED" heading
- `a` link "RETURN TO COCKPIT" → `/cockpit`

**Footer (fixed bottom):**
- Keyboard hints: [A] Abort, [F] Force Shutdown, [Esc] Cancel
- "SC-EMR-057 | SC-EMR-060 Compliant"

### 2.8 STAMP Constraints

| Constraint | Description | How This Page Complies |
|------------|-------------|----------------------|
| SC-HMI-001 | Dark Cockpit defaults | Dark surface classes throughout; header turns red for active shutdown |
| SC-EMR-057 | Emergency stop < 5 seconds | Force shutdown path provides immediate halt capability |
| SC-EMR-060 | Rollback capability | Abort path halts sequence and returns system to normal operation |
| SC-VDP-008 | Closure feedback on each phase | Per-step status icons and phase progress bars provide real-time feedback |
| SC-SIL4-013 | 6 shutdown phases mandatory | NOTE: current implementation has 5 phases — potential gap |

### 2.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Phase advancement is simulation only — no real system shutdown occurs | 9 | 9 | 5 | 405 | Wire `initiate_shutdown` to actual CEPAF orchestrator via Zenoh |
| Force shutdown bypasses connection draining — data loss | 8 | 5 | 4 | 160 | Force path intentional per design; display explicit data loss warning ✓ |
| Abort during Phase 4 (distributed teardown) leaves Zenoh subscriptions open | 7 | 4 | 7 | 196 | Implement compensation actions on abort per SC-EMR-060 |

---

## 3. Guardian — `/cockpit/guardian`

### 3.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/guardian` |
| Module | `IndrajaalWeb.Prajna.GuardianLive` |
| Source | `lib/indrajaal_web/live/prajna/guardian_live.ex` |
| Page Title | "Guardian - Approval Interface" |
| Reference Standards | SC-GDE-001, SC-PRAJNA-001, SC-PRAJNA-005 |
| Version | 1.0.0 (created 2026-03-23) |

### 3.2 Design Intent

The Guardian Approval Interface provides human-in-the-loop oversight for all safety-critical state mutations proposed by autonomous agents. Every AI agent that wants to mutate system state must submit a proposal to the Guardian. Human operators see these proposals here and make approve/veto decisions. The page enforces:

- **SC-PRAJNA-005 two-step commit**: clicking Approve or Veto arms an intent; a second CONFIRM click executes it
- **Constitutional alignment display**: each proposal shows Ψ₀–Ψ₅ alignment checks
- **Audit trail**: all decisions are recorded and visible in the immutable register sidebar
- **Priority filtering**: P0 (critical) proposals visually distinguished from P1/P2
- **Circuit breaker visibility**: Guardian's circuit breaker state (closed/half_open/open) shown in header

### 3.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- Three sample proposals pre-loaded (GDE-447 P1, GDE-448 P0, GDE-449 P2)
- Stats row shows: PENDING count (amber when >0), APPROVED (green), VETOED (red), APPROVAL RATE %
- Proposals list is filterable by priority (All/P0/P1/P2)
- Circuit breaker badge in top-right shows `CB: CLOSED` (green)
- Audit trail shows 3 historical decisions

**Proposal approval flow (two-step):**
1. Operator sees proposal in list — title, description, proposer, impact score, age
2. Clicks "APPROVE" → sets `confirm_action: {:approve, id}`
3. Yellow confirmation bar appears above the main grid
4. Confirmation bar reads: "Approve proposal GDE-xxx? Action is irreversible and will be logged."
5. Operator clicks "CONFIRM" → `execute_approve/2` runs:
   - Removes proposal from pending list
   - Creates audit trail entry with decision `:approved`
   - Broadcasts `{:decision, id, :approved}` on `guardian:decisions` PubSub
   - Flash `:info` "Proposal GDE-xxx approved and recorded"
6. Operator clicks "CANCEL" → clears `confirm_action`, no change

**Proposal veto flow (two-step):**
- Same as approval but with "VETO" button → `{:veto, id}` → flash `:warning`

**Proposal detail:**
- Click on a proposal row → sets `selected_proposal`
- Right sidebar shows: ID, proposer, impact score, STAMP ref, constitutional checks (Ψ₀–Ψ₅)
- Each constitutional check shows pass/fail with colored icon
- "CLOSE" button clears selection

**Auto-refresh:**
- Every 5000ms: calls `Indrajaal.Safety.Guardian.status()` to update circuit breaker state
- Handles `{:new_proposal, proposal}` PubSub to prepend new proposals
- Handles `{:proposal_decided, %{id, decision}}` PubSub to reflect external decisions

### 3.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval 5_000      # Guardian status polling interval
@audit_max 50                # Maximum audit trail entries retained
```

**mount/3 assigns:**
```elixir
:page_title           => "Guardian - Approval Interface"
:current_nav          => :guardian
:pending_proposals    => init_proposals()      # 3 seeded proposals
:audit_trail          => init_audit_trail()    # 3 historical entries
:circuit_breaker      => :closed
:proposals_approved   => 0
:proposals_vetoed     => 0
:selected_proposal    => nil
:confirm_action       => nil                   # {:approve, id} | {:veto, id} | nil
:filter_priority      => :all
:last_update          => DateTime.utc_now()
```

**PubSub subscriptions (connected only):**
- `"guardian:proposals"`
- `"guardian:decisions"`
- `"prajna:guardian"`

**Timers (connected only):**
- `:timer.send_interval(5000, self(), :refresh)`

**handle_info callbacks:**
```elixir
:refresh                                           # Polls Guardian.status(), updates circuit_breaker + last_update
{:new_proposal, proposal}                          # Prepends normalized proposal to pending_proposals
{:proposal_decided, %{id: id, decision: decision}} # Removes proposal, creates audit entry, updates counters
_msg                                               # Ignored (catch-all)
```

**handle_event callbacks:**
```elixir
"select_proposal"   %{"id" => id}        # Sets selected_proposal to matching proposal map
"close_proposal"    {}                   # Clears selected_proposal and confirm_action
"request_approve"   %{"id" => id}        # Sets confirm_action: {:approve, id} — step 1 of two-step
"request_veto"      %{"id" => id}        # Sets confirm_action: {:veto, id} — step 1 of two-step
"cancel_confirm"    {}                   # Clears confirm_action
"confirm_action"    {}                   # Executes approve or veto based on confirm_action
"filter_priority"   %{"priority" => p}   # Sets filter_priority atom (:all, :p0, :p1, :p2)
```

**Seeded proposals (init_proposals):**
```
GDE-447: P1, impact=18, proposer=code-evolution-agent, all Ψ pass
GDE-448: P0, impact=32, proposer=safety-validator, Ψ₃ fails
GDE-449: P2, impact=12, proposer=kms-agent, all Ψ pass
```

**Guardian status fetch:**
```elixir
# Calls Indrajaal.Safety.Guardian.status() and .alive?()
# Catches all exceptions — returns %{circuit_breaker: :unknown} on failure
```

### 3.5 BDD Scenarios

```gherkin
Feature: Guardian Approval Interface
  Background:
    Given I navigate to "/cockpit/guardian"
    And 3 pending proposals are visible

  Scenario: GRD-001 — Proposal detail shows constitutional alignment
    When I click on proposal "GDE-448"
    Then the PROPOSAL DETAIL sidebar appears
    And I see "Ψ₃ Verification" with a red ✗ (fail)
    And I see "Ψ₀ Existence" with a green ✓ (pass)
    And I see impact score "32" in red bold

  Scenario: GRD-002 — Approve two-step commit
    When I click "APPROVE" on proposal "GDE-447"
    Then the yellow confirmation bar appears at top
    And I see "Approve proposal GDE-447? Action is irreversible"
    When I click "CONFIRM"
    Then proposal "GDE-447" disappears from the pending list
    And the APPROVED counter increments by 1
    And an audit trail entry for GDE-447 (approved) is added

  Scenario: GRD-003 — Veto two-step commit
    When I click "VETO" on proposal "GDE-448"
    And the confirmation bar shows "Veto proposal GDE-448?"
    When I click "CONFIRM"
    Then proposal "GDE-448" is removed
    And the VETOED counter increments by 1
    And the APPROVAL RATE recalculates

  Scenario: GRD-004 — Cancel does not execute action
    When I click "APPROVE" on proposal "GDE-449"
    And the confirmation bar appears
    When I click "CANCEL"
    Then the confirmation bar disappears
    And proposal "GDE-449" remains in the list
    And the APPROVED counter is unchanged

  Scenario: GRD-005 — Priority filter shows only P0 proposals
    When I select "P0 Critical" in the priority filter dropdown
    Then only proposal "GDE-448" (P0) is visible
    And proposals GDE-447 and GDE-449 are hidden
```

### 3.6 UX Flow

```
Landing
  → Stats bar (Pending/Approved/Vetoed/Rate)
  → Scan proposals list (optional: apply priority filter)
  → Click a proposal row → Detail panel opens on right
     → Review constitutional alignment
     → Review impact score (red if ≥ 30)
     → Review STAMP references
  → Decision:
     → APPROVE: yellow confirm bar → CONFIRM → proposal removed, audit logged
     → VETO: yellow confirm bar → CONFIRM → proposal removed, audit logged
     → CANCEL: confirm bar dismissed
  → Audit trail updates on right sidebar (last 12 entries)
```

### 3.7 UI Elements Inventory

**Standard Prajna header (component `<.prajna_header>`):**
- Health score calculated from circuit breaker state and pending proposal count
- Uptime, node count, alarm count (= pending proposal count)

**Standard Prajna nav (component `<.prajna_nav current={:guardian}>`):**
- Guardian tab is active

**Header row:**
- `h1` "Guardian Approval Interface"
- Circuit breaker badge — colored by state: green (closed), amber (half_open), red (open)
- Last update timestamp

**Stats row (4 cards):**
- PENDING count (amber if > 0)
- APPROVED count (green)
- VETOED count (red)
- APPROVAL RATE %

**Confirmation dialog (shown when `confirm_action != nil`):**
- Yellow-bordered panel with action description
- `button` "CONFIRM" — `phx-click="confirm_action"` (amber background)
- `button` "CANCEL" — `phx-click="cancel_confirm"`

**Proposals list (col-span-7):**
- Heading "PENDING PROPOSALS"
- `select` priority filter — `phx-change="filter_priority"` name="priority"
- Proposal rows (each clickable `phx-click="select_proposal"` `phx-value-id={proposal.id}`):
  - Priority badge (P0=red, P1=orange, P2=blue)
  - Title, description
  - Agent, impact score, age
  - `button` "APPROVE" — `phx-click="request_approve"` `phx-value-id={proposal.id}`
  - `button` "VETO" — `phx-click="request_veto"` `phx-value-id={proposal.id}`

**Proposal detail panel (col-span-5, shown when `selected_proposal != nil`):**
- Heading "PROPOSAL DETAIL"
- `button` "CLOSE" — `phx-click="close_proposal"`
- ID, proposer, impact score, STAMP refs
- Constitutional alignment: Ψ₀–Ψ₅ with pass/fail icons

**Audit trail panel:**
- Last 12 entries: timestamp, APPROVED/VETOED badge, proposal ID, actor

**Constraints badge (text):**
- "SC-PRAJNA-001 | SC-PRAJNA-005 | SC-GDE-001 | SC-SAFETY-003"

### 3.8 STAMP Constraints

| Constraint | Description | How This Page Complies |
|------------|-------------|----------------------|
| SC-PRAJNA-001 | Guardian pre-approval for planning mutations | All mutations require proposal submission and operator decision |
| SC-PRAJNA-005 | Two-step commit for destructive actions | APPROVE/VETO require a second CONFIRM click |
| SC-SAFETY-001 | Guardian pre-approval required | This page IS the guardian approval mechanism |
| SC-SAFETY-003 | Complete audit trail to Immutable Register | Audit entries created on every decision; PubSub broadcast to guardian:decisions |
| SC-GDE-001 | Guardian validation required | Circuit breaker state and proposal queue are the guardian validation surface |
| SC-HMI-001 | Dark Cockpit | Dark surface classes throughout |

### 3.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Proposals initialized from seed data — not from real Guardian GenServer queue | 8 | 8 | 4 | 256 | Wire to `Indrajaal.Safety.Guardian` proposal queue via PubSub on mount |
| Audit trail is in-memory only — lost on process restart | 7 | 6 | 3 | 126 | Persist audit entries to DuckDB via ImmutableState (SC-SMRITI-142) |
| Guardian circuit_breaker state fetch fails silently — shows :unknown badge | 5 | 5 | 6 | 150 | Add visual alarm in header when circuit_breaker == :unknown |

---

## 4. Alarms — `/cockpit/alarms`

### 4.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/alarms` |
| Module | `IndrajaalWeb.Prajna.AlarmsLive` |
| Source | `lib/indrajaal_web/live/prajna/alarms_live.ex` |
| Page Title | "Alarm Center" |
| Reference Standards | Signal Detection Theory (d-prime), Laux 1993 |
| Version | 2.0.0 (updated 2026-01-02) |

### 4.2 Design Intent

The Alarm Center implements Signal Detection Theory (SDT/d-prime) principles to minimize alarm fatigue while ensuring critical events are never missed. The page applies salience-based filtering (0–100 score) and correlation to reduce noise. It is the primary operational alarm management interface with:

- Three-tier refresh architecture: 2s display refresh, 5s SmartMetrics sync, 30s Sentinel health sync
- Storm detection at a 10 alarms/minute threshold
- Bulk acknowledgment for advisory-level alarms
- AI-powered insights displayed per alarm
- Sentinel health integration (SC-PRAJNA-004) — health score visible in header
- Integration with SmartMetrics for telemetry publishing
- Bidirectional Zenoh alarm event handling (zenoh:alarms PubSub topic)

### 4.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- Prajna header and nav shown (nav tab :alarms active)
- Severity counts bar shows critical/warning/caution/advisory totals
- Storm status card: "NO STORM" (green) or "STORM ACTIVE" (amber, animated)
- Alarm list filtered by default: severity=:all, status=:active, timerange=:last_24h
- Each alarm row: severity icon + badge, alarm description, site, device, timestamp, AI insight
- Action buttons per alarm: ACK, SILENCE, ESCALATE
- Sentinel health panel in right sidebar (status, score, threat count, quarantine count)
- Workflow status panel
- Alarm trends panel (sparklines)

**Filtering:**
- Severity filter buttons: All, Critical, Warning, Caution, Advisory, Normal
- Status filter: Active, Acknowledged, All
- Time range filter: Last 1h, Last 24h, Last 7d
- Search: text input matches against alarm description and source
- Filters apply client-side (in-memory) on every render

**Alarm acknowledgment:**
- ACK button on individual alarm: sets status to :acknowledged + flash :info
- "ACK ALL ADVISORY" bulk action: acknowledges all active advisories + flash :info
- Count of acknowledged alarms included in flash message

**Storm handling:**
- When storm_status == :storm: animated warning banner appears
- "ACKNOWLEDGE STORM" button available

**Sentinel integration:**
- Synced every 30 seconds via `:sync_sentinel` handle_info
- Falls back to init_sentinel_health() if SentinelBridge process not found

### 4.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval        2000    # Display refresh
@metrics_sync_interval   5000    # SmartMetrics sync
@sentinel_sync_interval  30_000  # Sentinel health sync
@storm_threshold_per_minute 10
```

**mount/3 assigns:**
```elixir
:page_title           => "Alarm Center"
:current_nav          => :alarms
:alarms               => init_alarms()
:filter_severity      => :all
:filter_status        => :active
:filter_timerange     => :last_24h
:search_query         => ""
:selected_alarm       => nil
:severity_icons       => %{...}   # 5 unicode icons
:storm_status         => :normal
:storm_metrics        => init_storm_metrics()
:correlation_metrics  => init_correlation_metrics()
:workflow_status      => init_workflow_status()
:severity_counts      => init_severity_counts()
:alarm_trends         => generate_trends()
:sentinel_health      => init_sentinel_health()
:alarm_kpis           => init_alarm_kpis()
```

**PubSub subscriptions (connected only):**
- `"prajna:alarms"`
- `"prajna:metrics"`
- `"zenoh:alarms"`

**Timers (connected only):**
- `:timer.send_interval(2000, self(), :refresh)`
- `:timer.send_interval(5000, self(), :sync_metrics)`
- `:timer.send_interval(30000, self(), :sync_sentinel)`

**handle_info callbacks:**
```elixir
:refresh                            # Updates alarm ages, severity_counts, storm_status
:sync_metrics                       # Syncs to SmartMetrics, publishes to zenoh:alarms, updates alarm_kpis
:sync_sentinel                      # Fetches SentinelBridge health → updates sentinel_health
{:new_alarm, alarm}                 # Prepends alarm to list, updates storm_metrics
{:metric_updated, _id, _metric}     # No-op (acknowledged pattern)
{:zenoh_alarm_event, event}         # Logs debug message (currently no state change)
```

**handle_event callbacks:**
```elixir
"filter_severity"     %{"severity" => severity}      # Sets filter_severity atom
"filter_status"       %{"status" => status}          # Sets filter_status atom
"search"              %{"query" => query}            # Sets search_query
"acknowledge"         %{"id" => id}                  # Sets alarm status :acknowledged + flash
"silence"             %{"id" => id, "duration" => d} # Flash info only (no state change)
"escalate"            %{"id" => id}                  # Flash warning only
"select_alarm"        %{"id" => id}                  # Sets selected_alarm id
"ack_all_advisory"    {}                             # Bulk ack all active advisories + flash
"acknowledge_storm"   {}                             # Sets storm_metrics.acknowledged=true + flash
"export_report"       {}                             # Flash info about export path
```

### 4.5 BDD Scenarios

```gherkin
Feature: Alarm Center
  Background:
    Given I navigate to "/cockpit/alarms"

  Scenario: ALM-001 — Severity counts displayed in header
    Then I see severity count badges for Critical, Warning, Caution, Advisory
    And the badge values are numeric

  Scenario: ALM-002 — Severity filter narrows alarm list
    Given the alarm list shows alarms of multiple severities
    When I click the "CRITICAL" filter button
    Then only alarms with severity "critical" are shown
    When I click "ALL"
    Then all alarms are shown again

  Scenario: ALM-003 — Acknowledge individual alarm
    Given an active alarm "ALM-001" is visible
    When I click the "ACK" button for alarm "ALM-001"
    Then a flash message "Alarm ALM-001 acknowledged" appears
    And the alarm status changes to "acknowledged"

  Scenario: ALM-004 — Bulk acknowledge advisory alarms
    Given there are 3 active advisory alarms
    When I click "ACK ALL ADVISORY"
    Then a flash message "3 advisory alarms acknowledged" appears
    And all advisory alarms show status :acknowledged

  Scenario: ALM-005 — Sentinel health refreshes every 30 seconds
    Given the Sentinel health panel shows score "94%"
    When 30 seconds elapse (sync_sentinel timer fires)
    Then the Sentinel health panel refreshes from SentinelBridge
    And the score reflects the current Sentinel state
```

### 4.6 UX Flow

```
Landing
  → Prajna header (health score from Sentinel)
  → Severity summary counts (click to filter)
  → Apply filters: severity / status / timerange / search
  → Scan alarm list (severity icon, description, site, device, age)
  → Per-alarm actions:
     → ACK: immediate acknowledgment
     → SILENCE 1h: suppresses for duration
     → ESCALATE: escalates to supervisor
  → Bulk actions:
     → ACK ALL ADVISORY
     → Export Report
  → Right sidebar:
     → Sentinel health panel (30s auto-refresh)
     → Storm detection panel
     → Workflow status panel
     → Alarm trends sparklines
```

### 4.7 UI Elements Inventory

**Prajna header (component):** health_score from sentinel, alarm_count from severity_counts

**Prajna nav (component):** active tab = :alarms

**Severity counts row (filter buttons):**
- CRITICAL, WARNING, CAUTION, ADVISORY, NORMAL, ALL — `phx-click="filter_severity"` `phx-value-severity={sev}`

**Storm banner (shown when storm_status == :storm):**
- Animated warning indicator
- `button` "ACKNOWLEDGE STORM" — `phx-click="acknowledge_storm"`

**Alarm list:**
- Search input — `phx-keyup="search"` `phx-value-query`
- Status filter select — `phx-change="filter_status"`
- Time range filter select — `phx-change` (implied)
- Per-alarm row — `phx-click="select_alarm"` `phx-value-id`
  - Severity icon (unicode, colored)
  - Alarm description + site + device + age + occurrences
  - AI insight (italic cyan, prefixed "AI:")
  - `button` "ACK" — `phx-click="acknowledge"` `phx-value-id`
  - `button` "SILENCE 1h" — `phx-click="silence"` `phx-value-id` `phx-value-duration="1h"`
  - `button` "ESCALATE" — `phx-click="escalate"` `phx-value-id`

**Bulk actions:**
- `button` "ACK ALL ADVISORY" — `phx-click="ack_all_advisory"`
- `button` "EXPORT REPORT" — `phx-click="export_report"`

**Right sidebar:**
- Sentinel health panel (status, score, threat count, quarantine count, response SLA)
- Storm detection panel (status, suppressed count, threshold, last storm)
- Workflow status panel
- Alarm trends panel (sparkline per severity over time)

### 4.8 STAMP Constraints

| Constraint | Description | Compliance Status |
|------------|-------------|------------------|
| SC-HMI-001 | Dark Cockpit defaults | Dark surface classes; colored anomalies only |
| SC-VDP-015 | Score-based popup threshold | Salience scoring architecture referenced in design |
| SC-VDP-003 | Redundancy Gain for high salience | AI insight shown alongside visual severity icon |
| SC-EVAL-004 | False alarm rate < 5% | Correlation engine in architecture diagram; implementation TBD |
| SC-PRAJNA-004 | Sentinel health integration | SentinelBridge.get_health() called every 30s |
| SC-BRIDGE-005 | PubSub for zenoh:alarms | Subscribed; zenoh_alarm_event handler present |

### 4.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Storm detection uses in-memory metrics only — restarted process loses storm history | 6 | 5 | 5 | 150 | Persist storm_metrics to SQLite |
| zenoh_alarm_event handler is a no-op — real Zenoh alarm events are silently discarded | 7 | 6 | 4 | 168 | Implement full event handling: map to alarm struct, prepend to list |
| silence/escalate events produce only flash messages — no actual state change | 8 | 7 | 3 | 168 | Wire to alarm domain service for real silence/escalation |

---

## 5. Threat — `/cockpit/threat`

### 5.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/threat` |
| Module | `IndrajaalWeb.Prajna.ThreatLive` |
| Source | `lib/indrajaal_web/live/prajna/threat_live.ex` |
| Page Title | "Threat Dashboard" |
| Reference Standards | SC-IMMUNE-001, SC-PRAJNA-004 |
| Version | 1.0.0 (created 2026-03-23) |

### 5.2 Design Intent

The Real-Time Threat Dashboard provides security situational awareness via the Sentinel Digital Immune System. Threats detected by PatternHunter and other Sentinel subsystems are surfaced here with severity classification from low to extinction-level. The page provides:

- Live threat feed via PubSub subscriptions to `prajna:threats`, `zenoh:threats`, `sentinel:threats`
- 5-tier severity classification: extinction (purple), critical (red), high (orange), medium (yellow), low (blue)
- RPN (Risk Priority Number) display per threat for FMEA-aware triage
- Threat acknowledgment and dismissal workflow
- Sentinel health panel with score, threat count, quarantine count
- Threat type breakdown visualization
- Two timer loops: 5s display refresh, 30s Sentinel sync

### 5.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- 5 sample threats seeded (1 critical, 2 high, 1 medium, 1 low)
- Stats row: 5 cards (EXTINCTION, CRITICAL, HIGH, MEDIUM, ACTIVE TOTAL)
- Threats sorted by severity (extinction first)
- Filter buttons: ALL, EXTINCTION, CRITICAL, HIGH, MEDIUM, LOW
- Status dropdown: Active (default), Acknowledged, All
- Severity icons: ☢ extinction, ⛔ critical, ⚠ high, ℹ medium, · low
- "LIVE" indicator (green animated pulse) in top right

**Threat detail panel:**
- Click threat row → selected_threat assigned
- Right panel shows: ID, description, source, type, detected datetime, mitigation advice
- Two action buttons: ACKNOWLEDGE (green), DISMISS (gray)
- CLOSE button returns to list-only view

**Acknowledgment:**
- Per-threat "ACK" button in list row → status :acknowledged → flash :info
- "ACK ALL" button → all active threats acknowledged → flash :info with count
- Acknowledged threats styled with green badge, remain visible

**Dismissal:**
- DISMISS in detail panel → removes threat entirely from list → flash :info
- Recomputes threat_stats after removal

**Sentinel sync:**
- Every 30s via `:sync_sentinel` → calls `SentinelBridge.get_health()`
- Falls back to init_sentinel_health() if process not found

### 5.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval     5_000    # Display stats refresh
@sentinel_sync_interval 30_000 # Sentinel health sync
@max_history          100      # Threat history cap
```

**mount/3 assigns:**
```elixir
:page_title         => "Threat Dashboard"
:current_nav        => :sentinel
:threats            => init_threats()         # 5 seeded threats
:threat_history     => []
:filter_severity    => :all
:filter_status      => :active
:selected_threat    => nil
:sentinel_health    => init_sentinel_health() # score_percent: 94
:threat_stats       => init_threat_stats()    # extinction:0, critical:1, high:2, medium:1, low:1, active:4
:last_update        => DateTime.utc_now()
```

**PubSub subscriptions (connected only):**
- `"prajna:threats"`
- `"zenoh:threats"`
- `"sentinel:threats"`

**Timers (connected only):**
- `:timer.send_interval(5000, self(), :refresh)`
- `:timer.send_interval(30000, self(), :sync_sentinel)`

**handle_info callbacks:**
```elixir
:refresh                          # Updates last_update, recomputes threat_stats
:sync_sentinel                    # Fetches SentinelBridge health
{:new_threat, threat}             # Normalizes and prepends threat; updates history and stats
{:threat_resolved, threat_id}     # Sets threat status :resolved; recomputes stats
_msg                              # Ignored (catch-all)
```

**handle_event callbacks:**
```elixir
"filter_severity"     %{"severity" => sev}   # Sets filter_severity atom
"filter_status"       %{"status" => status}  # Sets filter_status atom
"select_threat"       %{"id" => id}          # Sets selected_threat to matching threat map
"close_detail"        {}                     # Clears selected_threat
"acknowledge_threat"  %{"id" => id}          # Sets threat status :acknowledged; clears selected_threat; flash
"dismiss_threat"      %{"id" => id}          # Removes threat from list; recomputes stats; flash
"acknowledge_all"     {}                     # Sets all :active threats to :acknowledged; flash with count
```

**Seeded threats (init_threats):**
```
THR-001: critical, intrusion, PatternHunter, RPN=189, active
THR-002: high, resource_exhaustion, SmartMetrics, RPN=96, active
THR-003: medium, performance_degradation, Sentinel, RPN=45, active
THR-004: high, timeout, GuardianKernel, RPN=112, acknowledged
THR-005: low, certificate_expiry, KMS, RPN=28, active
```

**Threat filtering order:**
- Severity filter AND status filter applied
- Sorted by severity_order (extinction=0 through low=4)

### 5.5 BDD Scenarios

```gherkin
Feature: Real-Time Threat Dashboard
  Background:
    Given I navigate to "/cockpit/threat"
    And 5 threats are visible

  Scenario: THR-001 — Severity stats displayed correctly
    Then the CRITICAL counter shows 1
    And the HIGH counter shows 2
    And the ACTIVE TOTAL shows 4

  Scenario: THR-002 — Severity filter works
    When I click the "CRITICAL" filter button
    Then only THR-001 is shown in the list
    And THR-002 is not visible

  Scenario: THR-003 — Threat detail opens on click
    When I click on threat "THR-001"
    Then the CRITICAL THREAT detail panel appears on the right
    And I see description "Unauthorized access attempt detected on /api/admin"
    And I see mitigation "Block IP 192.168.1.150, review access logs"
    And I see ACKNOWLEDGE and DISMISS buttons

  Scenario: THR-004 — Acknowledge threat via list ACK button
    When I click the "ACK" button for "THR-001"
    Then a flash "Threat THR-001 acknowledged" appears
    And THR-001 shows the "acknowledged" green badge

  Scenario: THR-005 — Dismiss threat removes it from list
    Given I click on "THR-003" to open the detail panel
    When I click "DISMISS"
    Then "THR-003" is removed from the threat list
    And the ACTIVE TOTAL count decreases by 1
```

### 5.6 UX Flow

```
Landing
  → Header: health score from Sentinel, alarm_count from threat_stats.active_count
  → Severity stats (5 cards)
  → Apply filters: severity / status
  → Scan threat list (severity icon, description, source, type, age, RPN)
  → Per-threat:
     → ACK: immediately acknowledges
     → Click row: opens detail panel
        → Review mitigation advice
        → Click ACKNOWLEDGE or DISMISS
  → ACK ALL: clears all active threats at once
  → Right sidebar:
     → Sentinel health (30s auto-refresh)
     → Threat type breakdown bar chart
```

### 5.7 UI Elements Inventory

**Prajna header (component):** health_score = sentinel_health.score_percent, alarm_count = threat_stats.active_count

**Prajna nav (component):** active tab = :sentinel

**Header row:**
- `h1` "Real-Time Threat Dashboard"
- "Last update: HH:MM:SS UTC" with green animated "LIVE" indicator

**Severity stats (5 cards):** EXTINCTION (purple), CRITICAL (red), HIGH (orange), MEDIUM (yellow), ACTIVE TOTAL

**Filter bar:**
- 6 severity filter buttons — `phx-click="filter_severity"` `phx-value-severity={sev}`
- Status filter `select` — `phx-change="filter_status"` options: active, acknowledged, all

**Threat list (col-span-8):**
- Heading "ACTIVE THREATS" + count + "ACK ALL" button — `phx-click="acknowledge_all"`
- Threat rows — `phx-click="select_threat"` `phx-value-id`
  - Severity icon (color-coded) + severity label
  - Description, source, type, age
  - RPN badge (red if >= 50)
  - Status badge (active=red, acknowledged=green, resolved=gray)
  - `button` "ACK" — `phx-click="acknowledge_threat"` `phx-value-id`

**Threat detail panel (col-span-4, when selected_threat != nil):**
- Severity-colored heading + `button` "CLOSE" — `phx-click="close_detail"`
- ID, description, source, type, detected timestamp, mitigation (amber)
- `button` "ACKNOWLEDGE" — `phx-click="acknowledge_threat"` `phx-value-id`
- `button` "DISMISS" — `phx-click="dismiss_threat"` `phx-value-id`

**Sentinel health panel:**
- Status (color: healthy=green, degraded=amber, critical=red), score %, threat count, quarantine count, response SLA

**Threat type breakdown panel:**
- Top 6 types with horizontal bar proportional to count

### 5.8 STAMP Constraints

| Constraint | Description | Compliance Status |
|------------|-------------|------------------|
| SC-IMMUNE-001 | Sentinel monitors system health | SentinelBridge.get_health() integrated with 30s sync |
| SC-IMMUNE-004 | PatternHunter pre-error detection < 10ms | Threats from PatternHunter appear in feed; latency enforced by Sentinel layer |
| SC-PRAJNA-004 | Sentinel health integration required | sentinel_health displayed and refreshed every 30s |
| SC-BRIDGE-005 | PubSub for zenoh:threats | Subscribed to zenoh:threats channel |
| SC-HMI-001 | Dark Cockpit | Dark surfaces; color-coded threats |

### 5.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Extinction-level threats treated same as critical in display — no differentiated alarm | 9 | 4 | 5 | 180 | Add audio alert + full-screen red flash for extinction-level threats |
| Dismiss permanently removes threat from view — no archive for forensics | 6 | 5 | 6 | 180 | Move dismissed threats to threat_history; add "View History" panel |
| All 3 PubSub channels subscribed but new_threat handler normalizes to same struct — channel provenance lost | 4 | 7 | 7 | 196 | Tag threat.channel field to track which channel originated each threat |

---

## 6. Cluster — `/cockpit/cluster`

### 6.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/cluster` |
| Module | `IndrajaalWeb.Prajna.ClusterLive` |
| Source | `lib/indrajaal_web/live/prajna/cluster_live.ex` |
| Page Title | "Cluster Management" |
| Reference Standards | NASA-STD-3000, Tailscale DNS, libcluster |
| Version | 1.0.0 |

### 6.2 Design Intent

The Cluster Management page provides operators with distributed system awareness following NASA-STD-3000 principles for multi-node control. It displays:

- **Sentinel quorum status**: current/required ratio, strategy (standalone vs cluster), split-brain detection
- **Cluster nodes**: real BEAM node list via `Node.list()` + local node, each with role (leader/follower/candidate), health, uptime, heartbeat, FLAME pool counts
- **FLAME pools**: Intelligence, Video, Analytics pools with utilization % and scale +2/-2 controls
- **Capability router**: backend priority chain showing Process → Container → K8s → Proxmox
- **Gossip log**: last 10 cluster events

The page actually calls real system APIs: `Indrajaal.Distributed.DistributedMesh.health_check/0`, `Indrajaal.Cockpit.Prajna.SentinelBridge.get_health/0`, and `Node.list()`. It degrades gracefully when these are unavailable.

### 6.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- Sentinel status bar at top: quorum ratio, strategy, DNS provider, split-brain status, last-check age
- Quorum badge: green check if met, red X if not
- Split-brain: red "DETECTED" if true, green "NO" if false
- Cluster nodes panel (left): local node always shown as leader; remote BEAM nodes listed as followers
- FLAME pools panel (right): 3 pools with utilization bars and scale buttons
- Capability router: shows backend chain
- Gossip log: time-ordered cluster events

**Auto-refresh (2s):**
- Calls `DistributedMesh.health_check()` — if OK, maps BEAM nodes to health status
- Calls `SentinelBridge.get_health()` — updates quorum_met and split_brain from health_score/threats
- Randomizes FLAME pool utilization ±3% per tick

**Node operations (flash only — no real action):**
- ADD NODE → flash :info "Add node wizard opened"
- REMOVE NODE (requires selection) → flash :warning "Node [id] removal requires confirmation"
- FORCE LEADER ELECTION → sets last_election timestamp + flash :info

**FLAME pool scaling (flash only):**
- SCALE +2 / SCALE -2 → flash :info "Scaling [pool] pool +2/-2"

### 6.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval 2000   # 2s node/pool/sentinel refresh
```

**mount/3 assigns:**
```elixir
:page_title          => "Cluster Management"
:sentinel            => init_sentinel_status()       # Real: Node.list() + SentinelBridge
:nodes               => init_cluster_nodes()         # Real: Node.list() + local node
:flame_pools         => init_flame_pools()           # Static: 3 pools
:capability_router   => init_capability_router()     # Static: 4 backends
:selected_node       => nil
:last_election       => nil
:gossip_log          => init_gossip_log()            # Static: 5 seeded entries
:node_role_icons     => %{leader: "★", follower: "●", candidate: "○"}
```

**PubSub subscriptions (connected only):**
- `"prajna:cluster"`

**Timers (connected only):**
- `:timer.send_interval(2000, self(), :refresh)`

**handle_info callbacks:**
```elixir
:refresh                         # refresh_nodes, refresh_sentinel, refresh_flame_pools
{:cluster_event, event}          # Prepends event to gossip_log (max 50 entries)
```

**handle_event callbacks:**
```elixir
"select_node"       %{"id" => id}                          # Sets selected_node
"force_election"    {}                                     # Sets last_election=DateTime.utc_now(); flash
"add_node"          {}                                     # Flash only
"remove_node"       %{"id" => id}                          # Flash warning
"scale_pool"        %{"pool" => pool, "direction" => dir}  # Flash only
"toggle_autoscale"  {}                                     # Flash only
```

**Actual system calls (with safe_call guard):**
- `Indrajaal.Distributed.DistributedMesh.health_check/0` — for node health
- `Indrajaal.Cockpit.Prajna.SentinelBridge.get_health/0` — for quorum/split-brain

### 6.5 BDD Scenarios

```gherkin
Feature: Cluster Management
  Background:
    Given I navigate to "/cockpit/cluster"

  Scenario: CLU-001 — Local node always shown as leader
    Then the cluster nodes list shows the current BEAM node
    And it is labeled "LEADER"
    And its status is "HEALTHY"

  Scenario: CLU-002 — Quorum status reflects actual BEAM cluster
    When running in standalone mode
    Then quorum shows "1/1 ✓" (green)
    And "Split-brain: NO" is shown

  Scenario: CLU-003 — Select node enables remove button
    Given the REMOVE NODE button is disabled
    When I click on a node row for node "app-01"
    Then the node row is highlighted
    And the REMOVE NODE button becomes enabled

  Scenario: CLU-004 — FLAME pool utilization updates every 2 seconds
    Given Intelligence Pool shows utilization "72%"
    When 2 seconds elapse (refresh timer fires)
    Then the utilization percentage has changed by up to ±3%
    And the progress bar width reflects the new value

  Scenario: CLU-005 — Force election creates flash confirmation
    When I click "FORCE LEADER ELECTION"
    Then a flash message "Leader election initiated" appears
    And the last_election timestamp is set to now
```

### 6.6 UX Flow

```
Landing
  → Scan sentinel status bar (quorum, split-brain, strategy)
  → Cluster nodes grid:
     → Click node row to select (enables REMOVE button)
     → Review: IP, uptime, heartbeat, FLAME pools active
  → FLAME pools grid:
     → Observe real-time utilization bars
     → Scale pool up or down (+2/-2)
  → Capability router: note current routing path
  → Gossip log: scan recent cluster events
  → Action buttons: ADD NODE, REMOVE NODE (selected), FORCE ELECTION
```

### 6.7 UI Elements Inventory

**Header bar:**
- `PRAJNA C3I` link, "CLUSTER MANAGEMENT" label, clock

**Navigation tabs:** OVERVIEW, MESH, ALARMS, COMMANDS, AI COPILOT, CONTAINERS, CLUSTER (active)

**Sentinel status bar:**
- Quorum badge (green/red) — current/required + check/X
- Strategy text
- DNS provider text
- Split-brain status (red "DETECTED" / green "NO")
- "Last check: Ns ago"

**Cluster Nodes panel (col-span-6):**
- Heading "CLUSTER NODES" + `button` "ADD NODE" — `phx-click="add_node"`
- Scrollable node list (max 400px height); each node row — `phx-click="select_node"` `phx-value-id`
  - Role icon (★ leader, ● follower, ○ candidate) + hostname + "(LEADER)" if leader
  - Status badge (HEALTHY/DEGRADED/UNREACHABLE)
  - IP, uptime, heartbeat lag, FLAME pools active/total

**FLAME Pools panel (col-span-6):**
- Heading "FLAME POOLS" + `button` "AUTO-SCALE: ON" — `phx-click="toggle_autoscale"`
- Per pool: name, current/max nodes, utilization bar (green/yellow/red), SCALE +2 + SCALE -2 buttons
  - SCALE: `phx-click="scale_pool"` `phx-value-pool` `phx-value-direction`

**Capability Router panel (col-span-6):**
- Backend list: 1. Process (local), 2. Container (Podman), 3. Kubernetes (K8s), 4. Proxmox (VM)
- Each: availability check (green ✓ / gray ○)
- "Current routing: Process -> Container (failover ready)"

**Gossip Log panel (col-span-6):**
- Last 10 entries: [HH:MM:SS] message (colored by event type)

**Action buttons (below grid):**
- `button` "ADD NODE" — `phx-click="add_node"`
- `button` "REMOVE NODE" — `phx-click="remove_node"` `phx-value-id={selected_node}` — disabled when nil
- `button` "FORCE LEADER ELECTION" — `phx-click="force_election"`
- `button` "VIEW GOSSIP LOG" — no phx-click (static button)

**Footer:** [A] Add Node, [R] Remove Node, [E] Force Election, [S] Scale Pool | Tailscale DNS | libcluster

### 6.8 STAMP Constraints

| Constraint | Description | Compliance Status |
|------------|-------------|------------------|
| SC-HMI-001 | Dark Cockpit defaults | Dark surfaces throughout |
| SC-CLUSTER-001 | Quorum visibility mandatory | Quorum current/required shown in sentinel status bar |
| SC-CLUSTER-002 | Split-brain detection < 5s | 2s refresh reads SentinelBridge; threshold met in practice |
| SC-VDP-008 | Closure feedback on node operations | Flash messages confirm all node operations |
| SC-QUORUM-001 | Two-out-of-three voting mandatory | Quorum display present; voting logic is in Guardian layer |

### 6.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Node add/remove/force_election are flash-only — no real cluster operation triggered | 8 | 8 | 4 | 256 | Wire to CEPAF orchestrator commands via Zenoh (SC-OP-001) |
| FLAME pool scale events are flash-only — no actual FLAME pool scaling | 7 | 8 | 5 | 280 | Wire to FLAME.Pool.scale/2 with Guardian pre-approval |
| Gossip log only receives PubSub :cluster_event — no integration with real BEAM gossip | 6 | 7 | 6 | 252 | Subscribe to real libcluster membership events; integrate with :net_kernel |

---

## 7. Active Alarms — `/cockpit/active-alarms`

### 7.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/active-alarms` |
| Module | `IndrajaalWeb.Operations.ActiveAlarmsLive` |
| Source | `lib/indrajaal_web/live/operations/active_alarms_live.ex` |
| Page Title | "Active Alarms - Operations Center" |
| Storm Threshold | 10 alarms/minute |
| Version | (no explicit version in module) |

### 7.2 Design Intent

The Operations Center Active Alarms page is the primary alarm triage screen for security and operations staff. Unlike the Prajna Alarms page (which is a Prajna cockpit view), this page is in the Operations context and represents the front-line alarm response interface with:

- Real-time alarm feed with severity-based background coloring and animated critical icons
- Per-alarm checkboxes for batch acknowledgment
- AI Copilot inline insights per alarm
- Alarm pipeline status visualization (Ingestion → Severity → Correlation → Storm → Notification → Workflow)
- Storm detection panel with configurable threshold (10/min)
- 24-hour trend sparkline
- Alarm metrics: processing rate, avg response time, SLA

Severity classifications follow a 4-tier model: critical → warning → caution → advisory (no "extinction" level — this page targets operational security staff, not system-level threats).

### 7.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- 5 sample alarms displayed (2 caution, 2 advisory, 1 warning)
- Summary bar at top: Critical (0), Warning (1), Caution (2), Advisory (5), Total (8) as clickable filter buttons
- Search input accepts text matching alarm message or source
- Pipeline status bar shows all 6 stages as OK
- Batch acknowledge button hidden when no alarms selected
- Storm detection: NO STORM, 0 suppressed

**Alarm rows (real-time feed):**
- `bg-red-900/20` for critical, `bg-red-900/10` for warning, transparent for others
- Checkbox — `phx-click="toggle_select"` for batch selection
- Severity icon (animated pulse for critical), source, message
- Site, device, age, occurrences
- AI insight (italic cyan) when present
- ACK button, SILENCE 1h button, ESCALATE button

**Batch workflow:**
- Select checkboxes → "ACK Selected (N)" button appears in header
- Click "ACK Selected" → all selected alarms acknowledged + selection cleared + flash

**Sidebar widgets:**
- Alarm Trends: 24h stacked bar chart (critical=red, warning=orange-red, caution=amber, advisory=cyan)
- Storm Detection: status, suppressed count, threshold config, "Configure" button
- Performance metrics: processing rate, avg response, SLA, unacked count
- Bulk Actions: "ACK All Advisory", "Export Report", "Configure Thresholds"

### 7.4 AS-IS State

**Module constants:**
```elixir
@refresh_interval 2_000    # 2s auto-refresh (uses Process.send_after, not :timer.send_interval)
@storm_threshold  10
```

**mount/3 assigns:**
```elixir
:page_title         => "Active Alarms - Operations Center"
:alarms             => generate_sample_alarms()     # 5 static alarms
:filter_severity    => :all
:filter_status      => :active
:filter_time        => "24h"
:search_text        => ""
:selected_alarms    => MapSet.new()
:pipeline_status    => generate_pipeline_status()   # 6 stages, all OK
:storm_active       => false
:storm_suppressed   => 0
:summary            => calculate_summary([])        # Starts with static base values
:trend_data         => generate_trend_data()        # Random 24h data
:last_updated       => DateTime.utc_now()
:storm_threshold    => 10
```

**PubSub subscriptions (connected only):**
- `"alarms:active"`
- `"alarms:pipeline"`

**Timer pattern:** `Process.send_after(self(), :refresh, 2000)` on connect; re-schedules itself in handle_info

**handle_info callbacks:**
```elixir
:refresh                       # Regenerates sample alarms + summary + last_updated; reschedules
{:alarm_update, alarm}         # Prepends alarm to list (max 100); no @impl true annotation
```

**handle_event callbacks:**
```elixir
"filter_severity"    %{"severity" => severity}    # Sets filter_severity atom
"filter_status"      %{"status" => status}        # Sets filter_status atom
"search"             %{"search" => text}          # Sets search_text
"acknowledge"        %{"id" => id}                # Flash only (no state change)
"acknowledge_all"    %{"severity" => severity}    # Flash only
"escalate"           %{"id" => id}                # Flash warning
"silence"            %{"id" => id, "duration" => d} # Flash info
"toggle_select"      %{"id" => id}                # Toggle alarm id in selected_alarms MapSet
"batch_acknowledge"  {}                           # Clears selected_alarms; flash with count
```

**NOTE on acknowledge:** The individual "acknowledge" handler produces only a flash message and does not change alarm status in the assigns — the alarm list is regenerated each :refresh cycle, resetting any local state changes. This is a known design gap.

### 7.5 BDD Scenarios

```gherkin
Feature: Active Alarms Operations Center
  Background:
    Given I navigate to "/cockpit/active-alarms"
    And 5 alarms are visible in the real-time feed

  Scenario: ACT-001 — Severity summary bar shows correct counts
    Then I see "Warning: 1" in orange-red
    And "Caution: 2" in amber
    And "Advisory: 5" (includes base + loaded alarms)

  Scenario: ACT-002 — Clicking severity filter narrows feed
    When I click "Warning: 1" in the summary bar
    Then only alarm "ALM-005" (FIRE / warning) is visible
    And the other 4 alarms are hidden

  Scenario: ACT-003 — Batch select and acknowledge
    Given I check the checkbox for "ALM-001"
    And I check the checkbox for "ALM-002"
    Then I see "ACK Selected (2)" button
    When I click "ACK Selected (2)"
    Then flash "2 alarms acknowledged" appears
    And the checkboxes are cleared

  Scenario: ACT-004 — Search filters by message text
    When I type "smoke" in the search input
    Then only alarm "ALM-005" (Smoke detector activated) is shown

  Scenario: ACT-005 — AI insight displayed per alarm
    Then alarm "ALM-001" shows cyan italic text "AI: Consider load balancing to app-04 (31% CPU)"
    And alarm "ALM-003" shows no AI insight text
```

### 7.6 UX Flow

```
Landing
  → Read summary bar (Critical/Warning/Caution/Advisory/Total counts)
  → Optional: apply filter by clicking severity badge
  → Optional: type in search input
  → Scan alarm list:
     → Check checkboxes for batch work
     → Per alarm: ACK / SILENCE 1h / ESCALATE
  → Batch: "ACK Selected (N)" appears when items selected
  → Right sidebar:
     → 24h trend sparklines
     → Storm detection status
     → Performance metrics
     → Bulk actions (ACK All Advisory / Export / Configure)
```

### 7.7 UI Elements Inventory

**Header:**
- `h1` "Active Alarms" + "Last updated: HH:MM:SS"
- `link` "Back to Cockpit" → `/cockpit`

**Summary bar:**
- `button` "⚠ Critical: N" (red) — `phx-click="filter_severity"` `phx-value-severity="critical"`
- `button` "⊘ Warning: N" (red-300) — `phx-click="filter_severity"` `phx-value-severity="warning"`
- `button` "⚠ Caution: N" (amber) — `phx-click="filter_severity"` `phx-value-severity="caution"`
- `button` "ℹ Advisory: N" (cyan) — `phx-click="filter_severity"` `phx-value-severity="advisory"`
- `button` "Total: N" — `phx-click="filter_severity"` `phx-value-severity="all"`
- `input` search — `phx-keyup="search"` `phx-value-search`

**Pipeline status bar:**
- 6 stages: Ingestion → Severity → Correlation → Storm → Notification → Workflow
- Each: check/X icon + stage name + value (rate or %)
- Storm banner (when storm_active): "⚠ Storm Active: N suppressed" (amber, animated)

**Alarm list (2/3 width):**
- "Real-Time Feed" heading + "ACK Selected (N)" button (when selected_alarms.size > 0) — `phx-click="batch_acknowledge"`
- Per alarm row:
  - `input` checkbox — `phx-click="toggle_select"` `phx-value-id`
  - Severity icon + text
  - Source | Message
  - Site, device, age, occurrences
  - AI insight (italic cyan)
  - `button` "ACK" — `phx-click="acknowledge"` `phx-value-id`
  - `button` "SILENCE 1h" — `phx-click="silence"` `phx-value-id` `phx-value-duration="1h"`
  - `button` "ESCALATE" — `phx-click="escalate"` `phx-value-id`

**Right sidebar:**
- Alarm Trends: stacked bar per hour (0–23), colored by severity
- Storm Detection: status badge, suppressed count, threshold, "Configure" button (no phx-click)
- Performance: processing rate, avg response, SLA, unacked count
- Bulk Actions: "ACK All Advisory" — `phx-click="acknowledge_all"` `phx-value-severity="advisory"`, "Export Report", "Configure Thresholds" (last two have no phx-click)

### 7.8 STAMP Constraints

| Constraint | Description | Compliance Status |
|------------|-------------|------------------|
| SC-HMI-001 | Management by Exception (gray defaults, colored anomalies) | Gray background; only alarm rows colored by severity |
| SC-HMI-002 | Analog indicators (trend arrows, sparklines) | 24h trend sparklines in sidebar |
| SC-HMI-003 | Staleness decay (visual degradation after 5s) | Not implemented — all alarms show same styling regardless of age |
| SC-HMI-005 | Critical prominence (pulsing red for critical) | Critical icon uses `animate-pulse` class |
| SC-AI-001 | AI suggestions are ADVISORY only | AI insights shown in italic with "AI:" prefix, no action binding |

### 7.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Individual ACK handler is flash-only — acknowledged state reset on next 2s refresh | 8 | 9 | 5 | 360 | Store acknowledged IDs in socket assigns; apply filter during regeneration |
| generate_sample_alarms() always returns same 5 alarms — real alarm feed never displayed | 9 | 9 | 3 | 243 | Integrate with Indrajaal.Alarms domain for real alarm data |
| SC-HMI-003 staleness decay not implemented | 4 | 6 | 8 | 192 | Add CSS opacity decay or visual indicator for alarms older than 5s |

---

## 8. Settings — `/cockpit/settings`

### 8.1 Page Identity

| Field | Value |
|-------|-------|
| Route | `/cockpit/settings` |
| Module | `IndrajaalWeb.Prajna.SettingsLive` |
| Source | `lib/indrajaal_web/live/prajna/settings_live.ex` |
| Page Title | "Settings" |
| Reference Standards | NUREG-0700, MIL-STD-1472H |
| Version | 1.0.0 |

### 8.2 Design Intent

The Settings page provides centralized configuration management for the PRAJNA C3I cockpit following NUREG-0700 guidelines. It is the configuration surface for four distinct domains:

1. **Display Preferences** — theme selection (Dark Cockpit, Light, High Contrast, System Auto), refresh rate, sparkline length, timezone. Theme changes are pushed immediately to the client JS hook via `push_event("set_theme", ...)`.

2. **Alarm Thresholds** — per-metric warning/caution levels for CPU, memory, disk, latency, and staleness period. Used to parameterize the alarm generation pipeline.

3. **AI Copilot** — LLM provider/model selection, analysis interval, max insights, insight TTL. Includes a toggle for enabling/disabling LLM integration.

4. **Safety Envelope** — protected parameters (max FLAME nodes, max RAM/CPU per node, heartbeat interval, Dead Man's Switch status) requiring two-key authorization (SC-CONFIG-002). The envelope is read-only by default; modifying it requires entering two successive authorization codes.

An "unsaved changes" indicator appears in the header when any setting has been changed but not yet saved. Save persists theme to the user account if authenticated.

### 8.3 Expected Behavior (FUNCTIONAL)

**On page load:**
- Current theme read from `socket.assigns[:theme]` (set by ThemeHook on_mount) — defaults to :dark
- Display preferences initialized from current theme
- All four setting panels displayed in a 2×2 grid
- Footer shows keyboard shortcuts: [S] Save, [R] Reset, [E] Export, [I] Import
- Safety Envelope shows read-only values with "MODIFY ENVELOPE" button

**Theme change:**
- Select different theme in dropdown → `push_event("set_theme", %{theme: theme_js})` sent to client hook immediately
- "Unsaved changes" indicator appears in header
- Click SAVE CHANGES → theme persisted to user account (if authenticated), flash :info

**Alarm threshold change:**
- Change any numeric input → `update_threshold` event → thresholds map merged → unsaved_changes=true

**AI Copilot:**
- Toggle LLM button → flips `llm_enabled`
- Provider/model/interval/max_insights/insight_ttl — all send `update_ai`

**Safety envelope (two-key flow):**
1. Click "MODIFY ENVELOPE (requires authorization)" → `envelope_edit_mode=true`, `envelope_auth_step=1`
2. Two-key form appears: "Enter authorization code 1/2:"
3. Type code + VERIFY → if code == "1234" → `envelope_auth_step=2`, flash :info "First authorization accepted"
4. Next code entry required for step 2 (same form, step shown as 2/2)
5. Click CANCEL at any time → `envelope_edit_mode=false`, `envelope_auth_step=0`

**Global actions:**
- SAVE CHANGES: persists theme to user account (Task.start async); flash :info; `unsaved_changes=false`
- RESET TO DEFAULTS: reinitializes all four domains to defaults; `unsaved_changes=false`; flash :info
- EXPORT CONFIG: flash :info "Configuration exported to prajna_config.json"
- IMPORT CONFIG: flash :info "Select configuration file to import"

### 8.4 AS-IS State

**mount/3 assigns:**
```elixir
:page_title            => "Settings"
:display_prefs         => %{theme: ..., refresh_rate: "500", sparkline_length: "20", timezone: "Europe/Berlin"}
:alarm_thresholds      => %{cpu_warning: 90, cpu_caution: 75, mem_warning: 90, mem_caution: 80,
                             disk_warning: 85, disk_caution: 70, latency_warning: 100, latency_caution: 50, staleness: 5}
:ai_settings           => %{llm_enabled: true, provider: "openrouter", model: "claude-3.5-sonnet",
                             analysis_interval: 10, max_insights: 50, insight_ttl: 300}
:safety_envelope       => %{max_flame_nodes: 10, max_ram_per_node: 4, max_cpu_per_node: 80,
                             heartbeat_interval: 10, dms_enabled: true}
:unsaved_changes       => false
:envelope_edit_mode    => false
:envelope_auth_step    => 0
```

**PubSub subscriptions:** None

**Timers:** None

**handle_event callbacks:**
```elixir
"update_display"         params                     # Merges atomized params into display_prefs; push_event if "theme" key
"update_threshold"       params                     # Merges into alarm_thresholds
"update_ai"              params                     # Merges into ai_settings
"toggle_llm"             {}                         # Flips ai_settings.llm_enabled
"save_changes"           {}                         # Async Theme persist to user account; flash :info
"reset_defaults"         {}                         # Reinitializes all 4 domains; unsaved_changes=false
"export_config"          {}                         # Flash :info only
"import_config"          {}                         # Flash :info only
"modify_envelope"        {}                         # envelope_edit_mode=true, envelope_auth_step=1
"envelope_auth"          %{"code" => code}          # If "1234": step→2 + flash; else: flash :error
"cancel_envelope_edit"   {}                         # envelope_edit_mode=false, envelope_auth_step=0
```

**push_event:** `"set_theme"` → `%{theme: theme_js}` — sent to client ThemeHook on theme change
- `"high_contrast"` → maps to `"high-contrast"` for JS

**Theme options:**
- `dark` → Dark Cockpit
- `light` → Light
- `high_contrast` → High Contrast
- `system` → System (Auto)

### 8.5 BDD Scenarios

```gherkin
Feature: PRAJNA Settings
  Background:
    Given I navigate to "/cockpit/settings"

  Scenario: SET-001 — Theme change is applied immediately
    When I select "High Contrast" in the Theme dropdown
    Then a push_event "set_theme" is sent to the client
    And the "Unsaved changes" indicator appears in the header

  Scenario: SET-002 — Save changes persists theme
    Given I have selected the "light" theme
    And "Unsaved changes" is shown
    When I click "SAVE CHANGES"
    Then I see flash "Settings saved successfully"
    And "Unsaved changes" disappears

  Scenario: SET-003 — Reset defaults clears all changes
    Given I have changed CPU warning to 80
    And "Unsaved changes" is shown
    When I click "RESET TO DEFAULTS"
    Then CPU warning reverts to 90
    And "Unsaved changes" disappears
    And flash "Settings reset to defaults" appears

  Scenario: SET-004 — Safety envelope requires two-key auth
    When I click "MODIFY ENVELOPE (requires authorization)"
    Then I see "Enter authorization code 1/2:"
    And a password input field appears
    When I type "9999" and click VERIFY
    Then flash "Invalid authorization code" appears
    And envelope_auth_step remains 1

  Scenario: SET-005 — Correct first code advances to step 2
    Given I click "MODIFY ENVELOPE"
    When I type "1234" and click VERIFY
    Then flash "First authorization accepted. Enter second code." appears
    And the form shows "Enter authorization code 2/2:"
```

### 8.6 UX Flow

```
Landing
  → 4 panels visible: Display, Thresholds, AI Copilot, Safety Envelope
  → Modify any setting → "Unsaved changes" indicator appears
  → Theme dropdown: select → immediate JS hook update
  → AI toggle: click → LLM enabled/disabled
  → Safety envelope:
     → Click "MODIFY ENVELOPE"
     → Enter authorization code 1/2 (correct: "1234")
     → Enter authorization code 2/2
     → Edit envelope values (when fully authorized)
  → SAVE CHANGES → persisted; flash confirmation
  → RESET TO DEFAULTS → all settings restored; "Unsaved changes" cleared
  → EXPORT CONFIG → flash (stub)
  → IMPORT CONFIG → flash (stub)
```

### 8.7 UI Elements Inventory

**Header bar:**
- `PRAJNA C3I` link to `/cockpit`
- "SETTINGS" label
- "Unsaved changes" (yellow, shown when `unsaved_changes=true`)
- Clock display

**Navigation tabs:** OVERVIEW, MESH, ALARMS, COMMANDS, AI COPILOT, CONTAINERS, SETTINGS (active, blue border)

**Display Preferences panel (top-left):**
- Heading "DISPLAY PREFERENCES"
- `select` Theme — `phx-change="update_display"` name="theme" — options: dark, light, high_contrast, system
- `select` Refresh Rate — `phx-change="update_display"` name="refresh_rate" — options: 500, 1000, 2000, 5000
- `select` Sparkline Length — `phx-change="update_display"` name="sparkline_length" — options: 10, 20, 30
- `select` Time Zone — `phx-change="update_display"` name="timezone" — options: Europe/Berlin, UTC, America/New_York

**Alarm Thresholds panel (top-right):**
- Heading "ALARM THRESHOLDS"
- CPU Warning/Caution: `input` type=number — `phx-change="update_threshold"` name="cpu_warning"/"cpu_caution"
- Memory Warning/Caution: `input` — `phx-change="update_threshold"` name="mem_warning"/"mem_caution"
- Latency Warning/Caution: `input` — `phx-change="update_threshold"` name="latency_warning"/"latency_caution"
- Staleness: `input` — `phx-change="update_threshold"` name="staleness"

**AI Copilot panel (bottom-left):**
- Heading "AI COPILOT"
- LLM Integration toggle `button` — `phx-click="toggle_llm"`
- `select` Provider — `phx-change="update_ai"` name="provider" — openrouter, anthropic, openai
- `select` Model — `phx-change="update_ai"` name="model" — claude-3.5-sonnet, claude-3-opus, gpt-4o
- `input` Analysis Interval — `phx-change="update_ai"` name="analysis_interval"
- `input` Max Insights — `phx-change="update_ai"` name="max_insights"
- `input` Insight TTL — `phx-change="update_ai"` name="insight_ttl"

**Safety Envelope panel (bottom-right, yellow border):**
- Heading "SAFETY ENVELOPE" + "Two-Key Required" label
- Yellow warning box: "Changes require Two-Key authorization (SC-CONFIG-002)"
- Read-only mode (when `not envelope_edit_mode`):
  - Max FLAME Nodes, Max RAM per Node, Max CPU per Node, Heartbeat Interval, Dead Man's Switch status
  - `button` "MODIFY ENVELOPE (requires authorization)" — `phx-click="modify_envelope"`
- Edit mode (when `envelope_edit_mode`):
  - "Enter authorization code N/2:"
  - `form` `phx-submit="envelope_auth"`: `input` type=password name="code" + VERIFY `button`
  - `button` "CANCEL" — `phx-click="cancel_envelope_edit"`

**Global actions:**
- `button` "SAVE CHANGES" — `phx-click="save_changes"` — disabled when `not unsaved_changes`
- `button` "RESET TO DEFAULTS" — `phx-click="reset_defaults"`
- `button` "EXPORT CONFIG" — `phx-click="export_config"`
- `button` "IMPORT CONFIG" — `phx-click="import_config"`

**Footer:** [S] Save, [R] Reset, [E] Export, [I] Import | "NUREG-0700 | MIL-STD-1472H Compliant"

### 8.8 STAMP Constraints

| Constraint | Description | Compliance Status |
|------------|-------------|------------------|
| SC-HMI-001 | Dark Cockpit defaults | Default theme is dark; page uses dark surfaces |
| SC-CONFIG-001 | Changes require confirmation | Save button with "unsaved changes" indicator |
| SC-CONFIG-002 | Safety envelope requires two-key auth | Two-step code entry enforced before envelope can be edited |
| SC-VDP-008 | Closure feedback on all changes | Flash messages on save, reset, export, import |
| SC-HMI-010 | Color Rich profile selection | Theme selector supports dark, light, high_contrast, system profiles |

### 8.9 FMEA Risks

| Failure Mode | Severity (S) | Occurrence (O) | Detection (D) | RPN | Mitigation |
|--------------|:---:|:---:|:---:|:---:|-----------|
| Envelope authorization code hardcoded as "1234" — security trivially bypassed | 9 | 9 | 2 | 162 | Replace with real TOTP or KMS-backed challenge/response per SC-CONFIG-002 |
| Export/import are stub flash messages — configuration not actually serialized | 5 | 7 | 6 | 210 | Implement JSON serialization of all 4 settings domains to file |
| Theme persistence via `User.update_theme` — only works for authenticated users; guest sessions always lose theme on page reload | 4 | 6 | 7 | 168 | Store theme in session for unauthenticated users via `put_session` |

---

## Appendix A: Cross-Page Summary Matrix

| Page | Route | Timer Intervals | PubSub Topics | Two-Step? | Sentinel Integration |
|------|-------|----------------|---------------|-----------|---------------------|
| Commands | `/cockpit/commands` | 1000ms (tick) | prajna:commands | Yes (code entry) | No |
| Shutdown | `/cockpit/shutdown` | 500ms (dynamic) | None | Yes (force shutdown) | No |
| Guardian | `/cockpit/guardian` | 5000ms | guardian:proposals, guardian:decisions, prajna:guardian | Yes | Via Guardian.status() |
| Alarms | `/cockpit/alarms` | 2000ms / 5000ms / 30000ms | prajna:alarms, prajna:metrics, zenoh:alarms | No | Yes (30s sync) |
| Threat | `/cockpit/threat` | 5000ms / 30000ms | prajna:threats, zenoh:threats, sentinel:threats | No | Yes (30s sync) |
| Cluster | `/cockpit/cluster` | 2000ms | prajna:cluster | No | Via SentinelBridge |
| Active Alarms | `/cockpit/active-alarms` | 2000ms | alarms:active, alarms:pipeline | No | No |
| Settings | `/cockpit/settings` | None | None | Yes (envelope auth) | No |

## Appendix B: Common Implementation Gaps

The following gaps were identified by reading actual source code — these are not speculative:

| Gap | Pages Affected | STAMP Ref | Priority |
|-----|---------------|-----------|----------|
| Command execution not wired to Guardian.validate | Commands | SC-GDE-001, SC-SAFETY-001 | P0 |
| Shutdown phases are simulated — no real orchestrator call | Shutdown | SC-EMR-057 | P0 |
| Proposals seeded statically — not from real Guardian queue | Guardian | SC-PRAJNA-001 | P0 |
| Audit trail in-memory only — not persisted to DuckDB | Guardian | SC-SAFETY-003 | P0 |
| Individual alarm ACK is flash-only — state reset on next refresh | Active Alarms | SC-ALARM-001 | P1 |
| Alarm data is static sample — not from Indrajaal.Alarms domain | Active Alarms, Alarms | SC-ALARM-001 | P1 |
| Safety envelope auth code hardcoded "1234" | Settings | SC-CONFIG-002 | P0 |
| Cluster node/pool operations are flash-only — no real calls | Cluster | SC-OP-001 | P1 |
| FLAME pool scaling not wired to FLAME.Pool | Cluster | SC-FLAME-001 | P1 |
| silence/escalate events are flash-only in Alarms and Active Alarms | Both alarm pages | SC-ALARM-003 | P2 |

## Appendix C: SC-COV Coverage Checklist

Per SC-COV-008 through SC-COV-020, each P0 page must satisfy:

| Coverage Category | Required | Commands | Shutdown | Guardian | Alarms | Threat | Cluster | ActiveAlarms | Settings |
|-------------------|---------|----------|----------|----------|--------|--------|---------|-------------|----------|
| C1 Page Structure | Mandatory | Spec present | Spec present | Spec present | Spec present | Spec present | Spec present | Spec present | Spec present |
| C2 Status/Badge | Mandatory | Status icons | Phase status | CB badge, priority | Severity counts | Severity stats | Quorum/health | Summary bar | Unsaved indicator |
| C3 Data Grid | Mandatory | Command history | Phase/step grid | Proposals list | Alarm list | Threat list | Node/pool grid | Alarm feed | Threshold grid |
| C4 Timeline/History | Where applicable | Command history | Shutdown log | Audit trail | Alarm trends | Threat history | Gossip log | Trend sparklines | N/A |
| C5 Interactive | Form-bearing pages | Code input | Mode/timeout selects | Filter select | Filter controls | Filter controls | N/A | Search/checkboxes | All 4 form panels |
| C8 Actions (dual verify) | Mandatory | ARM+CONFIRM | INITIATE+ABORT+FORCE | APPROVE+CONFIRM | ACK per alarm | ACK/DISMISS | ADD/REMOVE/ELECT | ACK/BATCH ACK | SAVE/RESET |
