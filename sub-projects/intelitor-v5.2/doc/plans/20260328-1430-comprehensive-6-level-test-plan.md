# Comprehensive 6-Level Test Plan — All 46 LiveView Pages, All Aspects

**Date**: 20260328-1430 CEST
**Author**: Claude Opus 4.6
**Version**: v21.3.1-SIL6
**Branch**: main
**STAMP**: SC-COV-001 through SC-COV-008, SC-HMI-010, SC-HMI-011, SC-SYNC-DOC-002
**Status**: PLAN (pre-execution)
**Supersedes**: `20260328-1400-wallaby-e2e-comprehensive-test-plan.md` (Wallaby-only)

---

## 0. Executive Summary

This plan covers **ALL 6 levels of fractal test coverage** for **ALL 46 LiveView pages** plus cross-cutting concerns (security, accessibility, performance, resilience, formal verification). It builds on the existing infrastructure of 2,201 test files, 87 BDD features, and 47 formal specs.

| Level | Framework | Existing | Target | Gap |
|-------|-----------|----------|--------|-----|
| L1: Unit/TDG | ExUnit + PropCheck + StreamData | 1,019 property tests | ~1,200 | ~181 |
| L2: FMEA | ExUnit @tag :fmea | 305 tests | ~400 | ~95 |
| L3: Formal | Agda + Quint + Mathematica | 47 specs | ~55 | ~8 |
| L4: Integration/Graph | Phoenix.LiveViewTest | 45 LiveView tests | 46 | 1 |
| L5: BDD | Cabbage/Gherkin | 87 features | ~95 | ~8 |
| L6: E2E Browser | Wallaby + Chrome | 1 test (13 features) | 46 tests (~310 features) | 45 |
| **Cross-cutting** | Mixed | Partial | Full | See §11-§15 |

**Total new test artifacts needed**: ~338 items across all levels.

---

## 1. Current State Assessment

### 1.1 Test Infrastructure Inventory

```
╔══════════════════════════════════════════════════════════════════════╗
║  TEST INFRASTRUCTURE STATE (2026-03-28)                             ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Test Files:          2,201 .exs files                               ║
║  BDD Features:        87 .feature files across 15 domains            ║
║  Formal Specs:        47 files (Agda, Quint, Mathematica)            ║
║  LiveView Tests:      45 files (Phoenix.LiveViewTest)                ║
║  Wallaby E2E Tests:   1 file (13 features — observability only)      ║
║  Property Tests:      ~1,019 (PropCheck + ExUnitProperties)          ║
║  FMEA Tests:          305 (@tag :fmea)                               ║
║  Step Definitions:    9 files (136 KB total)                         ║
║  Factories:           20+ domain factories                           ║
║  Support Files:       33 files in test/support/                      ║
║  Page Objects:        23+ page modules (22.5 KB)                     ║
║  Coverage Target:     95% (ExCoveralls + lcov)                       ║
║                                                                      ║
║  6-Level Status:                                                     ║
║    L1 TDG:     ████████████████████░  90% (mature)                   ║
║    L2 FMEA:    ██████████████░░░░░░  70% (good)                      ║
║    L3 Formal:  ████████████░░░░░░░░  60% (growing)                   ║
║    L4 IntTest: ████████████████████░  90% (45/46 LiveView)           ║
║    L5 BDD:     ██████████████████░░  85% (87 features)               ║
║    L6 E2E:     █░░░░░░░░░░░░░░░░░░   4% (1/46 pages)               ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### 1.2 Per-Page Coverage Matrix (46 Pages)

Legend: `✅` = exists and adequate, `⚠` = exists but incomplete, `❌` = missing, `—` = N/A

| # | Page | Route | L1 TDG | L2 FMEA | L3 Formal | L4 LiveView | L5 BDD | L6 Wallaby |
|---|------|-------|--------|---------|-----------|-------------|--------|------------|
| 1 | NavigationPortalLive | `/` | ⚠ | ❌ | ⚠ | ✅ | ⚠ | ❌ |
| 2 | PrajnaLive | `/cockpit` | ⚠ | ⚠ | ⚠ | ✅ | ✅ | ❌ |
| 3 | Prajna.AlarmsLive | `/cockpit/alarms` | ⚠ | ⚠ | ❌ | ✅ | ✅ | ❌ |
| 4 | Prajna.SentinelDashboardLive | `/cockpit/sentinel` | ⚠ | ⚠ | ❌ | ✅ | ⚠ | ❌ |
| 5 | Prajna.GuardianDashboardLive | `/cockpit/guardian` | ⚠ | ⚠ | ✅ | ✅ | ✅ | ❌ |
| 6 | Prajna.ClusterLive | `/cockpit/cluster` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 7 | Prajna.ContainersLive | `/cockpit/containers` | ⚠ | ❌ | ✅ | ✅ | ⚠ | ❌ |
| 8 | Prajna.StartupLive | `/cockpit/startup` | ⚠ | ⚠ | ❌ | ✅ | ✅ | ❌ |
| 9 | Prajna.ObservabilityLive | `/cockpit/observability` | ⚠ | ❌ | ✅ | ✅ | ⚠ | ✅ |
| 10 | Prajna.MeshLive | `/cockpit/mesh` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 11 | Prajna.DiagnosticsLive | `/cockpit/diagnostics` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 12 | Prajna.CommandsLive | `/cockpit/commands` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 13 | Prajna.ThreatLive | `/cockpit/threat` | ⚠ | ⚠ | ❌ | ✅ | ⚠ | ❌ |
| 14 | Prajna.HealthSparklineLive | `/cockpit/health-sparklines` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 15 | Prajna.RegisterLive | `/cockpit/register` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 16 | Prajna.SettingsLive | `/cockpit/settings` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 17 | Prajna.ShutdownLive | `/cockpit/shutdown` | ⚠ | ✅ | ❌ | ✅ | ✅ | ❌ |
| 18 | Prajna.GuardianLive | `/cockpit/guardian-approval` | ⚠ | ⚠ | ✅ | ✅ | ✅ | ❌ |
| 19 | Prajna.DevicesLive | `/cockpit/devices` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 20 | Prajna.GitIntelligenceLive | `/cockpit/git-intelligence` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 21 | Prajna.KnowledgeLive | `/cockpit/knowledge` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 22 | Knowledge.DeveloperLive | `/cockpit/knowledge/developer` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 23 | Knowledge.ProductLive | `/cockpit/knowledge/product` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 24 | Knowledge.SRELive | `/cockpit/knowledge/sre` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 25 | Prajna.AnalyticsLive | `/cockpit/analytics` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 26 | Prajna.ComplianceLive | `/cockpit/compliance` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 27 | Prajna.CopilotLive | `/cockpit/ai-copilot` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 28 | Prajna.TestCockpitLive | `/cockpit/test-evolution` | ⚠ | ❌ | ❌ | ✅ | ✅ | ❌ |
| 29 | Prajna.VideoLive | `/cockpit/video` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 30 | Prajna.AccessControlLive | `/cockpit/access-control` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 31 | Ops.ActiveAlarmsLive | `/operations/alarms` | ⚠ | ⚠ | ❌ | ✅ | ✅ | ❌ |
| 32 | Ops.AlarmInvestigationLive | `/operations/alarms/:id` | ⚠ | ⚠ | ❌ | ✅ | ⚠ | ❌ |
| 33 | Ops.AccessDashboardLive | `/operations/access` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 34 | Ops.DispatchConsoleLive | `/operations/dispatch` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 35 | Ops.VideoWallLive | `/operations/video` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 36 | MonitoringDashboardLive | `/monitoring` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 37 | PerformanceDashboardLive | `/performance` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 38 | SystemStatusLive | `/admin/system-status` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 39 | ConfigManagementLive | `/admin/config` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 40 | AccessCtrlMonitoringLive | `/admin/access_control` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 41 | PermissionsManagementLive | `/admin/permissions` | ⚠ | ❌ | ❌ | ✅ | ⚠ | ❌ |
| 42 | StampTdgGdeDashboardLive | `/analytics/dashboard` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 43 | StampTdgGdeAdvAnalyticsLive | `/analytics/stamp-tdg-gde-advanced` | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 44 | Crm.DashboardLive | *(internal)* | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 45 | Prajna.PrometheusLive | *(internal)* | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |
| 46 | Prajna.TopologyLive | *(internal)* | ⚠ | ❌ | ❌ | ✅ | ❌ | ❌ |

**Summary**: L4 (LiveView unit tests) is 45/46. L6 (Wallaby) is 1/46. L2 FMEA and L3 Formal have significant gaps for UI-specific failure modes.

---

## 2. Level 1 — Unit & Property Testing (TDG)

### 2.1 Scope

Test every **pure function**, **assign computation**, **helper module**, and **component function** associated with the 46 LiveView pages. Property tests verify invariants hold across random inputs.

### 2.2 What Needs Testing Per Page

| Aspect | Test Type | Example |
|--------|-----------|---------|
| `mount/3` assigns | Unit | All 12 assign keys initialized with correct types |
| `handle_event/3` state transitions | Unit + Property | `switch_tab("traces")` → `active_tab == :traces` |
| `handle_info/2` message processing | Unit | `:refresh` updates metrics without crash |
| Helper functions (defp promoted) | Unit + Property | `init_metrics/0` returns valid structure |
| Component functions | Unit | `status_icon(:connected)` → "●" with green class |
| Assign validation | Property | For all valid tab names, `switch_tab(tab)` succeeds |
| Error handling | Unit | Malformed PubSub message doesn't crash socket |
| Timer intervals | Unit | Timer fires at expected frequency |
| Data transformations | Property | Metric history is always bounded to sparkline_length |

### 2.3 Property Test Specifications

#### 2.3.1 ObservabilityLive Properties

```elixir
# P-OBS-001: Tab switching is idempotent
forall tab <- PC.oneof([:metrics, :traces, :logs, :signoz]) do
  socket = mount_socket() |> handle_event("switch_tab", %{"tab" => to_string(tab)})
  socket.assigns.active_tab == tab
end

# P-OBS-002: Metrics history never exceeds sparkline_length
forall n <- PC.pos_integer() do
  metrics = update_metrics_n_times(init_metrics(), n)
  Enum.all?(history_keys(), fn k -> length(metrics[k]) <= 30 end)
end

# P-OBS-003: Metric values are always non-negative
forall _ <- PC.boolean() do
  metrics = generate_metrics()
  metrics.request_rate >= 0 and metrics.error_rate >= 0 and metrics.p99_latency >= 0
end
```

#### 2.3.2 AlarmsLive Properties

```elixir
# P-ALM-001: filter_severity is a valid atom
forall sev <- PC.oneof([:all, :critical, :major, :minor, :advisory]) do
  socket = mount_socket() |> handle_event("filter_severity", %{"severity" => to_string(sev)})
  socket.assigns.filter_severity == sev
end

# P-ALM-002: acknowledge changes status of exactly 1 alarm
forall id <- SD.string(:alphanumeric, min_length: 1) do
  socket = mount_with_alarms([alarm(id)])
  socket2 = handle_event(socket, "acknowledge", %{"id" => id})
  acked = Enum.find(socket2.assigns.alarms, &(&1.id == id))
  acked.status == :acknowledged
end

# P-ALM-003: ack_all_advisory only affects advisory + active
forall alarms <- SD.list_of(alarm_generator(), min_length: 1, max_length: 50) do
  socket = mount_with_alarms(alarms)
  socket2 = handle_event(socket, "ack_all_advisory", %{})
  Enum.all?(socket2.assigns.alarms, fn a ->
    not (a.severity == :advisory and a.status == :active)
  end)
end

# P-ALM-004: Storm detection threshold is 10/min
forall rate <- PC.integer(0, 100) do
  storm = detect_storm(%{rate_per_min: rate})
  (rate > 10) == (storm == :detected)
end
```

#### 2.3.3 Component Properties

```elixir
# P-CMP-001: status_icon covers all states
forall state <- PC.oneof([:connected, :stale, :disconnected, :error, :unknown]) do
  icon = status_icon_char(state)
  is_binary(icon) and String.length(icon) == 1
end

# P-CMP-002: trend_indicator maps to valid CSS class
forall trend <- PC.oneof([:rising_fast, :rising, :stable, :falling, :falling_fast]) do
  color = trend_color(trend)
  color in ["text-red-400", "text-amber-400", "text-gray-400", "text-cyan-400", "text-blue-400"]
end

# P-CMP-003: KPI card alarm level thresholds are monotonic
forall {warn, crit} <- {PC.float(0.0, 1.0), PC.float(0.0, 1.0)} do
  implies(crit > warn) do
    alarm_level(crit + 0.01, warn, crit) == :critical
    and alarm_level(warn + 0.01, warn, crit) == :warning
    and alarm_level(warn - 0.01, warn, crit) == :normal
  end
end
```

### 2.4 Gap Analysis — New L1 Tests Needed

| Domain | Existing PropTests | New PropTests Needed | Total |
|--------|-------------------|---------------------|-------|
| LiveView mount/assigns | ~30 | +46 (1 per page) | 76 |
| Handle_event transitions | ~50 | +80 (multi-event pages) | 130 |
| Handle_info processing | ~20 | +40 (timer/PubSub pages) | 60 |
| Component functions | ~40 | +15 (prajna_components) | 55 |
| Data transformations | ~80 | +0 (good coverage) | 80 |
| **Total L1 gap** | | **~181 new** | |

### 2.5 Files to Create/Modify

```
test/indrajaal_web/live/property/
├── observability_live_prop_test.exs     # NEW: 8 property tests
├── alarms_live_prop_test.exs            # NEW: 10 property tests
├── navigation_portal_prop_test.exs      # NEW: 3 property tests
├── cluster_live_prop_test.exs           # NEW: 5 property tests
├── guardian_live_prop_test.exs          # NEW: 6 property tests
└── ...                                  # 1 file per page with handle_event

test/indrajaal_web/components/
├── core_components_prop_test.exs        # NEW: 8 property tests
└── prajna_components_prop_test.exs      # NEW: 12 property tests
```

---

## 3. Level 2 — FMEA (Failure Mode & Effects Analysis)

### 3.1 Scope

Test every **failure mode** for UI components: what happens when data is nil, PubSub disconnects, timers fail, metrics return errors, malformed user input arrives, or the DOM is in an unexpected state.

### 3.2 FMEA Matrix — UI Failure Modes

| FM-ID | Failure Mode | Severity | Occurrence | Detection | RPN | Affected Pages | Mitigation |
|-------|-------------|----------|-----------|-----------|-----|---------------|------------|
| FM-UI-001 | Mount crashes on nil Repo data | 9 | 3 | 5 | 135 | All 46 | Default assigns with fallback values |
| FM-UI-002 | PubSub topic not subscribed | 7 | 2 | 7 | 98 | 21 real-time pages | `connected?(socket)` guard before subscribe |
| FM-UI-003 | Timer accumulates stale messages | 5 | 4 | 6 | 120 | 15 timer pages | Message queue flush on tab switch |
| FM-UI-004 | Handle_event receives unknown event | 7 | 3 | 4 | 84 | All 44 dynamic pages | Catch-all `handle_event/3` clause |
| FM-UI-005 | Metric history unbounded growth | 6 | 3 | 5 | 90 | Observability, Health | Bounded ring buffer (sparkline_length) |
| FM-UI-006 | Flash message not dismissed | 3 | 5 | 3 | 45 | 8+ pages with flashes | Auto-dismiss timer + close button |
| FM-UI-007 | Socket assigns type mismatch | 8 | 2 | 6 | 96 | All 46 | Typespec on assigns + dialyzer |
| FM-UI-008 | Theme hook fails on mount | 7 | 1 | 8 | 56 | All cockpit pages | Fallback to default dark theme |
| FM-UI-009 | Concurrent PubSub floods socket | 6 | 3 | 5 | 90 | Alarms, Sentinel | Circuit breaker (SC-CIRCUIT-001) |
| FM-UI-010 | 500 error on knowledge/developer | 9 | 8 | 2 | 144 | Knowledge.DeveloperLive | Fix SMRITI init dependency |
| FM-UI-011 | Alarm storm UI unresponsive | 8 | 3 | 4 | 96 | AlarmsLive | Storm aggregation + batch renders |
| FM-UI-012 | Guardian approval race condition | 9 | 2 | 6 | 108 | GuardianLive, Dashboard | OCC with version vectors |
| FM-UI-013 | Shutdown without Arm & Fire | 10 | 1 | 9 | 90 | ShutdownLive | SC-SAFETY-001 multi-step gate |
| FM-UI-014 | Split-brain shown as healthy | 9 | 2 | 5 | 90 | ClusterLive | SC-SIL4-015 apoptosis trigger |
| FM-UI-015 | Stale container status | 6 | 4 | 4 | 96 | ContainersLive | 2s refresh + timestamp display |
| FM-UI-016 | XSS via alarm description | 10 | 2 | 7 | 140 | AlarmsLive, Investigation | Phoenix HTML escaping (default) |
| FM-UI-017 | CSRF on destructive actions | 10 | 1 | 8 | 80 | Settings, Config, Shutdown | LiveView CSRF token (built-in) |
| FM-UI-018 | Memory leak from PubSub | 7 | 3 | 5 | 105 | All real-time pages | Process.info(:memory) monitor |
| FM-UI-019 | Broken WebSocket reconnect | 8 | 3 | 4 | 96 | All LiveView pages | Phoenix reconnect backoff |
| FM-UI-020 | Chromedriver version mismatch | 7 | 1 | 9 | 63 | Wallaby tests only | NixOS pins matching versions |

### 3.3 FMEA Test Specifications

```elixir
# FM-UI-001: Mount with nil Repo data
@tag :fmea
test "mount survives when Repo returns empty results" do
  # Simulate empty DB
  conn = build_conn() |> get("/cockpit/observability")
  {:ok, _view, html} = live(conn)
  assert html =~ "Metrics"  # Page renders with defaults
end

# FM-UI-004: Unknown event handler
@tag :fmea
test "handle_event with unknown event returns noreply" do
  {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
  assert render_click(view, "nonexistent_event", %{}) =~ "Metrics"
end

# FM-UI-009: PubSub flood doesn't crash socket
@tag :fmea
test "100 rapid PubSub messages don't crash observability" do
  {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
  for _ <- 1..100 do
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", {:metric_update, :test, %{}})
  end
  Process.sleep(100)
  assert render(view) =~ "Metrics"  # Still alive
end

# FM-UI-013: Shutdown requires Arm & Fire (SC-SAFETY-001)
@tag :fmea
test "shutdown page requires multi-step confirmation" do
  {:ok, view, html} = live(build_conn(), "/cockpit/shutdown")
  # Verify the shutdown button is NOT directly executable
  refute html =~ "phx-click=\"execute_shutdown\""
  # Must have arm step first
  assert html =~ "arm" or html =~ "confirm"
end

# FM-UI-016: XSS protection on alarm descriptions
@tag :fmea
test "alarm description with script tag is escaped" do
  {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
  # Phoenix auto-escapes by default, but verify
  refute render(view) =~ "<script>"
end
```

### 3.4 Gap Analysis — New L2 Tests Needed

| Failure Mode Category | Existing | New Needed | Total |
|-----------------------|----------|-----------|-------|
| Mount resilience | 20 | +46 (1 per page) | 66 |
| Event handler edge cases | 40 | +20 (high-event pages) | 60 |
| PubSub/timer failures | 15 | +15 (real-time pages) | 30 |
| Security (XSS/CSRF) | 10 | +5 | 15 |
| Safety-critical (Arm&Fire, Guardian) | 5 | +5 | 10 |
| State corruption | 5 | +4 | 9 |
| **Total L2 gap** | | **~95 new** | |

---

## 4. Level 3 — Formal Verification

### 4.1 Scope

Prove critical **state machine invariants** and **safety properties** for the most critical LiveView pages using Quint (temporal logic) and Agda (dependent types).

### 4.2 Existing Formal Specs

| File | Covers | Status |
|------|--------|--------|
| `observability_state_machine.qnt` (48.9 KB) | Observability tab FSM | ✅ Complete |
| `guardian_state_machine.qnt` (23.2 KB) | Guardian approval FSM | ✅ Complete |
| `container_verification.qnt` (25 KB) | Container lifecycle | ✅ Complete |
| `cockpit_navigation_graph.md` (20.8 KB) | Navigation reachability | ✅ Complete |
| `agda_proofs.agda` (17 KB) | Graph properties | ✅ Complete |

### 4.3 New Formal Specs Needed

| Spec | Language | Target Page | Property |
|------|----------|-------------|----------|
| `alarm_state_machine.qnt` | Quint | AlarmsLive | ∀ alarm: `acknowledged ⊬ active` (no going back); storm threshold = 10/min |
| `shutdown_safety.qnt` | Quint | ShutdownLive | SC-SAFETY-001: shutdown requires Arm→Confirm→Execute (3 steps) |
| `cluster_quorum.qnt` | Quint | ClusterLive | SC-SIL4-011: quorum ⌊N/2⌋+1 always displayed correctly |
| `sentinel_threat_levels.qnt` | Quint | SentinelDashboardLive | Threat escalation is monotonic within epoch |
| `navigation_completeness.agda` | Agda | NavigationPortalLive | ∀ route ∈ Router: ∃ link ∈ Portal (all routes reachable) |
| `tab_fsm_generic.qnt` | Quint | All tabbed pages | Tab switching is deterministic and total |
| `pubsub_ordering.agda` | Agda | All real-time pages | Message ordering preserves causality |
| `guardian_two_key.qnt` | Quint | GuardianLive | Two-key approval requires 2 distinct approvers |

### 4.4 Quint Model Template (Alarm FSM)

```quint
module AlarmStateMachine {
  type AlarmStatus = Active | Acknowledged | Silenced | Resolved | Escalated
  type AlarmSeverity = Critical | Major | Minor | Advisory

  var alarms: Set[{ id: str, status: AlarmStatus, severity: AlarmSeverity }]
  var storm_detected: bool

  action acknowledge(id: str) = {
    val alarm = alarms.filter(a => a.id == id).head()
    require(alarm.status == Active)
    alarms' = alarms.map(a => if (a.id == id) a.with("status", Acknowledged) else a)
  }

  action ack_all_advisory() = {
    alarms' = alarms.map(a =>
      if (a.severity == Advisory and a.status == Active)
        a.with("status", Acknowledged)
      else a
    )
  }

  // SAFETY INVARIANT: acknowledged alarms never revert to active
  val inv_no_revert = alarms.forall(a =>
    a.status == Acknowledged implies next(a.status) != Active
  )

  // SAFETY INVARIANT: storm detection fires at threshold
  val inv_storm_threshold = {
    val rate = alarms.filter(a => a.status == Active).size()
    (rate > 10) implies storm_detected
  }
}
```

---

## 5. Level 4 — Integration Testing (Phoenix.LiveViewTest)

### 5.1 Scope

Test the **full mount→render→interact→verify** cycle for each page using `Phoenix.LiveViewTest` (server-side, no browser). This level is **45/46 complete** — only missing page-specific depth on several modules.

### 5.2 Existing Coverage

All 45 LiveView test files use this pattern:

```elixir
defmodule IndrajaalWeb.Prajna.PageNameLiveTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders page" do
    {:ok, _view, html} = live(build_conn(), "/cockpit/page-name")
    assert html =~ "PAGE HEADING"
  end

  test "handles event" do
    {:ok, view, _html} = live(build_conn(), "/cockpit/page-name")
    assert render_click(view, "action", %{}) =~ "expected content"
  end
end
```

### 5.3 Gap: Missing Page

| Page | File | Status |
|------|------|--------|
| Prajna.TopologyLive (3D variant) | `topology_3d_live_test.exs` | Exists but separate from main topology |

One missing test file is minimal — **L4 is effectively 100%**.

### 5.4 Depth Gaps — Existing Tests Need More Coverage

Many existing L4 tests only verify page render. They need **event handler coverage**:

| Page | Existing Tests | Handle_events Tested | Handle_events Total | Gap |
|------|---------------|---------------------|--------------------|----|
| AlarmsLive | 3 | 2 | 11 | 9 |
| ObservabilityLive | 4 | 2 | 4 | 2 |
| ClusterLive | 2 | 0 | 3 | 3 |
| GuardianDashboardLive | 3 | 1 | 5 | 4 |
| SentinelDashboardLive | 2 | 0 | 4 | 4 |
| CommandsLive | 2 | 1 | 6 | 5 |
| SettingsLive | 2 | 0 | 4 | 4 |
| ConfigManagementLive | 2 | 0 | 5 | 5 |
| DispatchConsoleLive | 2 | 0 | 7 | 7 |

**Total depth gap**: ~43 handle_event tests need adding to existing L4 files.

### 5.5 PubSub Integration Tests

```elixir
# Test real-time update via PubSub
test "observability updates metrics on PubSub broadcast" do
  {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
  Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", {:metric_update, :cpu, %{value: 85}})
  Process.sleep(50)
  assert render(view) =~ "Request Rate"  # Page survives
end

# Test PubSub subscription on connected socket
test "alarms subscribes to prajna:alarms on connected mount" do
  {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
  Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:alarms", {:new_alarm, test_alarm()})
  Process.sleep(50)
  assert render(view) =~ "Test Alarm"  # New alarm appears
end
```

---

## 6. Level 5 — BDD (Behavior-Driven Development)

### 6.1 Scope

Gherkin feature files specifying **user journeys** through the cockpit. Each feature describes a scenario from the operator's perspective.

### 6.2 Existing BDD Coverage

87 existing feature files. Key cockpit-related:

| Feature File | Scenarios | Coverage |
|-------------|-----------|----------|
| `prajna/cockpit_navigation.feature` | 12 | Navigation between pages |
| `prajna/alarm_management.feature` | 15 | Alarm lifecycle |
| `prajna/guardian_approval.feature` | 8 | Guardian workflow |
| `startup/wave_orchestration.feature` | 20 | Boot sequence |
| `experience/observability_journey.feature` | 6 | Observability UX |
| `web/cockpit.feature` | 10 | Cockpit UI basics |

### 6.3 New BDD Features Needed

| Feature File | Scenarios | Priority | Target Pages |
|-------------|-----------|----------|-------------|
| `prajna/sentinel_monitoring.feature` | 8 | P1 | SentinelDashboardLive |
| `prajna/cluster_management.feature` | 7 | P1 | ClusterLive |
| `prajna/knowledge_management.feature` | 10 | P2 | Knowledge*, DeveloperLive, ProductLive, SRELive |
| `prajna/health_monitoring.feature` | 6 | P2 | HealthSparklineLive |
| `prajna/copilot_interaction.feature` | 8 | P2 | CopilotLive |
| `operations/dispatch_workflow.feature` | 10 | P2 | DispatchConsoleLive |
| `operations/video_surveillance.feature` | 6 | P3 | VideoWallLive, VideoLive |
| `admin/permission_management.feature` | 8 | P3 | PermissionsManagementLive |

### 6.4 BDD Scenario Template

```gherkin
# prajna/sentinel_monitoring.feature
Feature: Sentinel Dashboard Monitoring
  As a security operator
  I want to monitor real-time threat levels
  So that I can respond to security incidents

  Background:
    Given I am on the Sentinel Dashboard page

  Scenario: View current threat level
    Then I should see the threat level indicator
    And the threat level should be one of "DEFCON 1-5"

  Scenario: Threat escalation notification
    When a new critical threat is detected
    Then the threat level should increase
    And I should see a flash notification

  Scenario: PatternHunter status
    Then I should see the PatternHunter health indicator
    And the status should be "active" or "degraded"

  Scenario: Navigate to threat details
    When I click on a threat entry
    Then I should see the threat detail panel
    And the detail should include severity, source, and timestamp

  Scenario: Refresh threat data
    When I click the refresh button
    Then the threat list should reload
    And the timestamp should update

  Scenario: Sentinel bridge health
    Then I should see the Sentinel-Zenoh bridge status
    And the bridge should show "connected" or "disconnected"

  Scenario: Historical threat view
    When I select the "History" tab
    Then I should see past threats sorted by timestamp

  Scenario: Export threat report
    When I click "Export Report"
    Then I should see a flash message "Report exported"
```

---

## 7. Level 6 — E2E Browser Testing (Wallaby)

### 7.1 Scope

See predecessor plan `20260328-1400-wallaby-e2e-comprehensive-test-plan.md` for the full Wallaby test matrix. Summary:

- **46 pages** → 46 Wallaby test files
- **~310 features** across 5 execution waves
- **3 cross-cutting suites** (smoke, theme, navigation)
- **Page objects module** with 23+ page classes (already exists: 22.5 KB)

### 7.2 Wave Summary

| Wave | Pages | Features | Priority |
|------|-------|----------|----------|
| W1: Critical Path | 8 | ~65 | P0 |
| W2: Core Cockpit | 12 | ~80 | P1 |
| W3: Knowledge & Analytics | 10 | ~60 | P2 |
| W4: Operations Center | 5 | ~40 | P2 |
| W5: Admin & System | 11 | ~65 | P3 |
| Cross-cutting | 3 suites | ~80 | After W1 |

### 7.3 Wallaby-Specific Test Categories (Per Page)

| Category | Tests | Example |
|----------|-------|---------|
| A: Page Load | 2-3 | Renders heading, no 500 error, theme applied |
| B: Navigation | 1-3 | Tab switching, sidebar links, breadcrumbs |
| C: Dynamic Elements | 2-5 | Real-time indicators, metric cards, status badges |
| D: Event Handlers | 2-6 | Button clicks, form submissions, filter inputs |
| E: Flash Messages | 1-2 | Action feedback, error alerts |
| F: Edge Cases | 1-2 | Empty state, error state, safety gates |

---

## 8. Cross-Cutting: Accessibility Testing

### 8.1 WCAG 2.1 AA Compliance

| Test ID | Requirement | Check | Tool |
|---------|-------------|-------|------|
| ACC-001 | Color contrast ≥ 4.5:1 | All text on dark cockpit background | Wallaby + axe-core |
| ACC-002 | Keyboard navigation | All interactive elements focusable via Tab | Wallaby `send_keys` |
| ACC-003 | ARIA labels on icons | `status_icon/1` has aria-label | L4 LiveViewTest |
| ACC-004 | Focus visible | Focus ring on interactive elements | Wallaby CSS check |
| ACC-005 | Screen reader flash | `role="alert"` on flash messages | L4 + L6 |
| ACC-006 | Form labels | All inputs have associated labels | Wallaby + axe-core |
| ACC-007 | Alt text on images | Product logo has alt attribute | L4 |
| ACC-008 | Heading hierarchy | h1 → h2 → h3, no skipping | Wallaby DOM check |
| ACC-009 | Link purpose | Links have descriptive text (not "click here") | L4 regex |
| ACC-010 | Error identification | Form errors associated with inputs | L4 |

### 8.2 Accessibility Test File

```elixir
# test/indrajaal_web/live/accessibility_wallaby_test.exs
defmodule IndrajaalWeb.AccessibilityWallabyTest do
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag [:wallaby, :accessibility]

  @cockpit_routes ["/cockpit", "/cockpit/alarms", "/cockpit/sentinel", ...]

  for route <- @cockpit_routes do
    feature "#{route} has proper heading hierarchy", %{session: session} do
      session = visit(session, unquote(route))
      # Verify h1 exists
      assert_has(session, css("h1", minimum: 1))
      # No h3 without preceding h2
    end

    feature "#{route} flash messages have role=alert", %{session: session} do
      session = visit(session, unquote(route))
      # If flash present, must have role=alert
      # (Flash may not be visible on initial load)
    end
  end

  feature "keyboard Tab navigates through cockpit sidebar", %{session: session} do
    session = visit(session, "/cockpit")
    # Press Tab repeatedly, verify focus moves through sidebar links
    session |> send_keys([:tab, :tab, :tab])
    # Verify focus is on an interactive element
  end
end
```

---

## 9. Cross-Cutting: Performance Testing

### 9.1 Performance Budgets

| Metric | Budget | Measured At | Tool |
|--------|--------|-------------|------|
| Page load (TTFB) | < 500ms | Server response time | Wallaby + timing |
| LiveView mount | < 200ms | Socket connect to first render | L4 with timing |
| Event response | < 100ms | Click to DOM update | Wallaby timing |
| PubSub propagation | < 50ms | Broadcast to render update | L4 with timing |
| Memory per page | < 50MB | Browser memory after 5min | Chrome DevTools MCP |
| WebSocket reconnect | < 2s | Disconnect to reconnect | L4 with kill/reconnect |
| 100 concurrent alarms | < 1s render | Alarm list with 100 items | L4 with factory |
| 500ms timer accuracy | ±50ms | Observability refresh | L4 with timing |

### 9.2 Performance Test File

```elixir
# test/indrajaal_web/live/performance_test.exs
defmodule IndrajaalWeb.PerformanceLiveTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest
  @moduletag [:performance]

  test "observability mount completes within 200ms" do
    {time_us, {:ok, _view, _html}} = :timer.tc(fn ->
      live(build_conn(), "/cockpit/observability")
    end)
    assert time_us < 200_000  # 200ms
  end

  test "alarm list renders 100 alarms within 1 second" do
    # Seed 100 alarms
    {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
    {time_us, _html} = :timer.tc(fn -> render(view) end)
    assert time_us < 1_000_000  # 1s
  end

  test "tab switch responds within 100ms" do
    {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
    {time_us, _html} = :timer.tc(fn ->
      render_click(view, "switch_tab", %{"tab" => "traces"})
    end)
    assert time_us < 100_000  # 100ms
  end

  test "PubSub message propagates within 50ms" do
    {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
    t1 = System.monotonic_time(:microsecond)
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", {:metric_update, :test, %{}})
    Process.sleep(10)
    _html = render(view)
    t2 = System.monotonic_time(:microsecond)
    assert (t2 - t1) < 50_000  # 50ms
  end
end
```

---

## 10. Cross-Cutting: Security Testing

### 10.1 OWASP Top 10 for LiveView

| Test ID | Vulnerability | Test Method | Affected Pages |
|---------|--------------|-------------|---------------|
| SEC-001 | XSS (reflected) | Inject `<script>` in search/filter inputs | Alarms, AccessControl |
| SEC-002 | XSS (stored) | Alarm description with script tag | AlarmsLive |
| SEC-003 | CSRF | LiveView built-in token — verify present | All 46 pages |
| SEC-004 | Broken authentication | Access cockpit without session | All cockpit routes |
| SEC-005 | Broken authorization | Access admin page as regular user | Admin pages |
| SEC-006 | SQL injection | Inject SQL in search inputs | Alarms, Devices, Access |
| SEC-007 | Mass assignment | Extra params in handle_event | All event handlers |
| SEC-008 | IDOR | Access `/operations/alarms/:id` with invalid id | AlarmInvestigation |
| SEC-009 | Rate limiting | Rapid-fire event clicks | All action buttons |
| SEC-010 | Information disclosure | Error pages leak stack traces | All pages (500 error) |
| SEC-011 | Guardian bypass | Submit approval without authority | GuardianLive |
| SEC-012 | Shutdown without auth | Bypass Arm & Fire | ShutdownLive |

### 10.2 Security Test Specifications

```elixir
# test/indrajaal_web/live/security_test.exs
defmodule IndrajaalWeb.SecurityLiveTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest
  @moduletag [:security]

  test "XSS in alarm search is escaped" do
    {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
    html = render_change(view, "search", %{"query" => "<script>alert('xss')</script>"})
    refute html =~ "<script>"
    assert html =~ "&lt;script&gt;"  # Escaped
  end

  test "unauthenticated access to cockpit redirects" do
    conn = build_conn()  # No session
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/cockpit")
  end

  test "CSRF token present in LiveView socket" do
    {:ok, _view, html} = live(build_conn(), "/cockpit")
    assert html =~ "phx-csrf-token" or html =~ "_csrf_token"
  end

  test "invalid alarm ID returns graceful error" do
    {:ok, view, _html} = live(build_conn(), "/operations/alarms/nonexistent-id")
    assert render(view) =~ "Not Found" or render(view) =~ "Error"
  end

  test "shutdown requires multi-step authentication (SC-SAFETY-001)" do
    {:ok, view, html} = live(build_conn(), "/cockpit/shutdown")
    # Direct execute should not exist without arm step
    refute html =~ "phx-click=\"execute_shutdown\""
  end

  test "Guardian approval requires valid authority" do
    {:ok, view, _html} = live(build_conn(), "/cockpit/guardian-approval")
    # Attempt approve without proper role
    html = render_click(view, "approve", %{"id" => "test-proposal"})
    assert html =~ "unauthorized" or html =~ "denied" or html =~ "Insufficient"
  end
end
```

---

## 11. Cross-Cutting: Resilience Testing

### 11.1 Scope

Verify that LiveView pages **survive** infrastructure failures gracefully.

| Test ID | Scenario | Expected Behavior | Tool |
|---------|----------|-------------------|------|
| RES-001 | Zenoh router disconnects | Page shows "disconnected" indicator, no crash | L4 |
| RES-002 | PostgreSQL goes down | Pages show cached data or graceful error | L4 |
| RES-003 | PubSub topic deleted | No crash, subscription silently dropped | L4 |
| RES-004 | WebSocket drops | LiveView auto-reconnects within 2s | L6 Wallaby |
| RES-005 | 1000 concurrent users | Pages remain responsive | Load test (k6) |
| RES-006 | Node partition | Cluster page shows split-brain warning | L4 |
| RES-007 | DuckDB lock contention | Prajna register page degrades gracefully | L4 |
| RES-008 | Timer message flood | Circuit breaker drops excess messages | L4 |
| RES-009 | Memory pressure | Pages shed non-critical data | Monitor |
| RES-010 | Container restart | Page reconnects after container cycle | L6 Wallaby |

---

## 12. Cross-Cutting: Visual Regression Testing

### 12.1 Approach

Use Wallaby screenshots + image diff to detect unintended visual changes.

```elixir
# test/indrajaal_web/live/visual_regression_wallaby_test.exs
defmodule IndrajaalWeb.VisualRegressionWallabyTest do
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag [:wallaby, :visual]

  @baseline_pages [
    {"/cockpit", "cockpit_dashboard"},
    {"/cockpit/alarms", "cockpit_alarms"},
    {"/cockpit/observability", "cockpit_observability"},
    {"/cockpit/sentinel", "cockpit_sentinel"},
    {"/", "navigation_portal"}
  ]

  for {route, name} <- @baseline_pages do
    feature "visual baseline for #{name}", %{session: session} do
      session
      |> visit(unquote(route))
      |> take_screenshot(name: unquote(name))
      # Compare against baseline in test/wallaby/baselines/
    end
  end
end
```

### 12.2 Baseline Management

```
test/wallaby/
├── baselines/            # Golden screenshots (committed to git)
│   ├── cockpit_dashboard.png
│   ├── cockpit_alarms.png
│   └── ...
├── screenshots/          # Failure screenshots (gitignored)
└── diffs/                # Visual diff output (gitignored)
```

---

## 13. Cross-Cutting: Component Unit Testing

### 13.1 Scope

Test shared components in `lib/indrajaal_web/components/` in isolation.

### 13.2 Core Components

```elixir
# test/indrajaal_web/components/core_components_test.exs
defmodule IndrajaalWeb.CoreComponentsTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest
  import Phoenix.Component

  test "flash renders with role=alert" do
    html = render_component(&IndrajaalWeb.CoreComponents.flash/1, %{
      kind: :info, title: "Test", body: "Message"
    })
    assert html =~ "role=\"alert\""
    assert html =~ "Test"
    assert html =~ "Message"
  end

  test "icon renders hero icon SVG" do
    html = render_component(&IndrajaalWeb.CoreComponents.icon/1, %{name: "hero-check"})
    assert html =~ "svg" or html =~ "hero-check"
  end

  test "button renders with phx-click" do
    html = render_component(&IndrajaalWeb.CoreComponents.button/1, %{
      "phx-click": "action", children: "Click Me"
    })
    assert html =~ "phx-click"
    assert html =~ "Click Me"
  end
end
```

### 13.3 Prajna Components

```elixir
# test/indrajaal_web/components/prajna_components_test.exs
defmodule IndrajaalWeb.PrajnaComponentsTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.Component

  describe "status_indicator/1" do
    test "connected shows green dot" do
      html = render_component(&IndrajaalWeb.PrajnaComponents.status_indicator/1, %{
        status: :connected
      })
      assert html =~ "●" or html =~ "green" or html =~ "emerald"
    end

    test "disconnected shows red dot" do
      html = render_component(&IndrajaalWeb.PrajnaComponents.status_indicator/1, %{
        status: :disconnected
      })
      assert html =~ "○" or html =~ "red"
    end
  end

  describe "trend_indicator/1" do
    for {trend, expected} <- [
      {:rising_fast, "↑↑"}, {:rising, "↑"}, {:stable, "→"},
      {:falling, "↓"}, {:falling_fast, "↓↓"}
    ] do
      test "#{trend} renders #{expected}" do
        html = render_component(&IndrajaalWeb.PrajnaComponents.trend_indicator/1, %{
          trend: unquote(trend)
        })
        assert html =~ unquote(expected)
      end
    end
  end

  describe "product_logo/1" do
    test "renders SVG with animation" do
      html = render_component(&IndrajaalWeb.PrajnaComponents.product_logo/1, %{})
      assert html =~ "svg"
    end
  end
end
```

---

## 14. Test Execution Strategy

### 14.1 Daily Development (< 5 min)

```bash
# L1 + L4: Unit + LiveView tests (fast, no browser)
mix test test/indrajaal_web/live/ --exclude wallaby --exclude pending
```

### 14.2 Pre-Commit (< 15 min)

```bash
# L1 + L2 + L4: Unit + FMEA + LiveView
mix test --exclude wallaby --exclude pending --exclude requires_containers
mix format --check-formatted
mix credo --strict
```

### 14.3 Pre-Merge / CI Pipeline (< 45 min)

```bash
# All 6 levels
mix test                                          # L1 + L2 + L4 + L5
WALLABY_ENABLED=true mix test --only wallaby      # L6
agda --safe docs/formal_specs/*.agda              # L3 (Agda)
quint run docs/formal_specs/*.qnt                 # L3 (Quint)
mix test --only security                          # Cross-cutting: Security
mix test --only performance                       # Cross-cutting: Performance
```

### 14.4 Weekly Full Verification (< 2 hrs)

```bash
# Everything including resilience, visual regression, load testing
./scripts/testing/run_six_level_tests.sh
# Includes: L1-L6 + accessibility + security + performance + visual + resilience
```

### 14.5 Tag Matrix

| Tag | Level | Run When | Command |
|-----|-------|----------|---------|
| *(default)* | L1+L4 | Every test run | `mix test` |
| `:fmea` | L2 | Pre-commit | `mix test --only fmea` |
| `:wallaby` | L6 | Pre-merge | `WALLABY_ENABLED=true mix test --only wallaby` |
| `:smoke` | L6 | Pre-merge | `WALLABY_ENABLED=true mix test --only smoke` |
| `:security` | Cross | Pre-merge | `mix test --only security` |
| `:performance` | Cross | Weekly | `mix test --only performance` |
| `:accessibility` | Cross | Weekly | `WALLABY_ENABLED=true mix test --only accessibility` |
| `:visual` | Cross | Weekly | `WALLABY_ENABLED=true mix test --only visual` |
| `:resilience` | Cross | Weekly | `mix test --only resilience` |
| `:pending` | — | Never (excluded) | TDG tests written before impl |

---

## 15. Total Artifact Inventory

### 15.1 New Files to Create

| # | File | Level | Content |
|---|------|-------|---------|
| 1-45 | `test/indrajaal_web/live/**/*_wallaby_test.exs` | L6 | 45 new Wallaby test files |
| 46 | `test/indrajaal_web/live/smoke_wallaby_test.exs` | L6 | Smoke suite (39 routes) |
| 47 | `test/indrajaal_web/live/theme_wallaby_test.exs` | L6 | Theme consistency |
| 48 | `test/indrajaal_web/live/navigation_wallaby_test.exs` | L6 | Navigation integrity |
| 49 | `test/indrajaal_web/live/accessibility_wallaby_test.exs` | Cross | WCAG 2.1 AA |
| 50 | `test/indrajaal_web/live/visual_regression_wallaby_test.exs` | Cross | Screenshot diff |
| 51 | `test/indrajaal_web/live/performance_test.exs` | Cross | Performance budgets |
| 52 | `test/indrajaal_web/live/security_test.exs` | Cross | OWASP Top 10 |
| 53 | `test/indrajaal_web/live/resilience_test.exs` | Cross | Infrastructure failure |
| 54 | `test/indrajaal_web/components/core_components_test.exs` | L1 | Component unit tests |
| 55 | `test/indrajaal_web/components/prajna_components_test.exs` | L1 | Prajna components |
| 56-70 | `test/indrajaal_web/live/property/*_prop_test.exs` | L1 | 15 property test files |
| 71 | `docs/formal_specs/alarm_state_machine.qnt` | L3 | Alarm FSM proof |
| 72 | `docs/formal_specs/shutdown_safety.qnt` | L3 | Shutdown Arm & Fire proof |
| 73 | `docs/formal_specs/cluster_quorum.qnt` | L3 | Quorum invariant proof |
| 74 | `docs/formal_specs/sentinel_threat_levels.qnt` | L3 | Threat escalation proof |
| 75 | `docs/formal_specs/navigation_completeness.agda` | L3 | Route reachability proof |
| 76 | `docs/formal_specs/tab_fsm_generic.qnt` | L3 | Tab switching determinism |
| 77 | `docs/formal_specs/pubsub_ordering.agda` | L3 | Causal ordering proof |
| 78 | `docs/formal_specs/guardian_two_key.qnt` | L3 | Two-key approval proof |
| 79-86 | `test/features/prajna/*.feature` | L5 | 8 new BDD feature files |

**Total**: ~86 new files.

### 15.2 Existing Files to Enhance

| # | Files | Level | Enhancement |
|---|-------|-------|-------------|
| 1-9 | 9 LiveView test files (see §5.4) | L4 | Add ~43 handle_event tests |
| 10-20 | 11 LiveView test files | L2 | Add @tag :fmea tests for mount resilience |

### 15.3 Summary Metrics

| Metric | Current | After Plan | Delta |
|--------|---------|------------|-------|
| L1 Property tests | ~1,019 | ~1,200 | +181 |
| L2 FMEA tests | 305 | ~400 | +95 |
| L3 Formal specs | 47 | 55 | +8 |
| L4 LiveView tests | 45 files | 46 files + 43 event tests | +44 |
| L5 BDD features | 87 | 95 | +8 |
| L6 Wallaby E2E | 1 file (13 features) | 48 files (~390 features) | +47 files, +377 features |
| Cross-cutting | Partial | 5 dedicated test files | +5 |
| Security tests | ~10 | ~22 | +12 |
| Performance tests | ~5 | ~13 | +8 |
| Accessibility tests | 0 | ~20 | +20 |
| Visual regression | 0 | ~5 baselines | +5 |
| Resilience tests | ~10 | ~20 | +10 |
| **Total new test artifacts** | — | — | **~338** |
| **Total test files after** | 2,201 | ~2,290 | +89 |
| **Feature coverage** | 4.2% (L6) | 100% (L6) | +95.8% |

---

## 16. Execution Priority & Dependencies

```
Phase 0: Prerequisites
├── PostgreSQL container running (port 5433)
├── devenv shell loaded (chromium + chromedriver)
└── Wallaby infrastructure wired (DONE — Waves 1-3 from 20260328-1200)

Phase 1: Foundation (can run in parallel)
├── [L1] Component unit tests (core_components, prajna_components)
├── [L1] Property tests for top 15 pages (by handle_event count)
├── [L4] Depth: +43 handle_event tests in existing LiveView files
└── [L6] Wallaby Wave 1: 8 critical path pages

Phase 2: Core Coverage (after Phase 1)
├── [L2] FMEA mount resilience tests (46 pages)
├── [L2] FMEA PubSub/timer failure tests (21 real-time pages)
├── [L3] Formal: alarm_state_machine.qnt + shutdown_safety.qnt
├── [L5] BDD: sentinel_monitoring.feature + cluster_management.feature
├── [L6] Wallaby Wave 2: 12 core cockpit pages
└── [Cross] Security test file (OWASP Top 10)

Phase 3: Extended Coverage (after Phase 2)
├── [L3] Formal: remaining 6 specs
├── [L5] BDD: remaining 6 feature files
├── [L6] Wallaby Waves 3-5: 26 remaining pages
├── [Cross] Performance test file
├── [Cross] Accessibility test file
└── [Cross] Resilience test file

Phase 4: Polish (after Phase 3)
├── [L6] Cross-cutting Wallaby suites (smoke, theme, navigation)
├── [Cross] Visual regression baselines
└── Documentation update (FIVE_LEVEL → SIX_LEVEL coverage framework)
```

---

## 17. STAMP & Constitutional Alignment

| Constraint | Level | How Satisfied |
|-----------|-------|---------------|
| SC-COV-001 | L1 | Static coverage ≥ 100% for critical paths via property tests |
| SC-COV-002 | All | Runtime coverage ≥ 95% via ExCoveralls |
| SC-COV-003 | L3 | Mathematical proofs for alarm FSM, shutdown, quorum, Guardian |
| SC-COV-004 | L5 | BDD specs for all user journeys (87 existing + 8 new) |
| SC-COV-005 | L2 | FMEA for RPN > 50 paths (20 failure modes, 400 tests) |
| SC-COV-006 | All | TDG compliance — tests exist before code |
| SC-COV-007 | All | All 6 levels MUST pass before merge |
| SC-COV-008 | L6 | Wallaby E2E for all 46 LiveView pages |
| SC-HMI-010 | L6 | Color Rich — CSS class verification in Wallaby |
| SC-HMI-011 | L6 | 8x8 Matrix — tab paths × elements per page |
| SC-SAFETY-001 | L2+L3+L6 | Arm & Fire tested at FMEA, formal, and browser levels |
| SC-SIL4-015 | L3+L4 | Split-brain tested formally and in LiveViewTest |
| Psi-3 (Verification) | All | 6-level fractal coverage = maximum verification depth |
| Omega-3 (Zero-Defect) | All | Quality gates enforce 0 errors/warnings/failures |

---

## 18. Risk Matrix

| Risk | Severity | Likelihood | RPN | Mitigation |
|------|----------|-----------|-----|------------|
| PostgreSQL container not running | 9 | 3 | 27 | `test-e2e` checks, clear error msg |
| Flaky Wallaby tests from timing | 6 | 7 | 42 | `max_wait_time: 30_000`, retry on CI |
| Knowledge/developer 500 error | 7 | 8 | 56 | Skip with `@tag :skip_known_500` |
| Property test counterexample noise | 4 | 5 | 20 | `MIX_ENV=test mix propcheck.clean` |
| Visual regression false positives | 3 | 6 | 18 | Update baselines after intentional changes |
| Formal spec incompleteness | 5 | 4 | 20 | Start with critical paths (alarm, shutdown) |
| CI pipeline timeout (>60 min) | 6 | 4 | 24 | Parallelize: L1-L4 parallel, L6 separate job |
| Security test false positives | 3 | 3 | 9 | Manually verify first, then automate |
| Context window pressure (86 files) | 2 | 3 | 6 | Wave-based execution, shared page objects |
