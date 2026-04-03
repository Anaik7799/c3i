# Gold Standard Wallaby E2E Plan — All Web Pages to Alarm Investigation Quality

**Date**: 20260328-1600 CEST
**Author**: Claude Opus 4.6
**Version**: v21.3.1-SIL6
**Branch**: main
**STAMP**: SC-COV-008, AOR-COV-006, SC-HMI-011, SC-SAFETY-001, SC-AI-001
**Compliance**: SC-SYNC-DOC-002 (journal mandatory for every plan)

---

## 1. Gold Standard Definition — The 8 Test Categories

The `alarm_investigation_live_wallaby_test.exs` (48 features, 431 lines) defines 8 mandatory test categories that every LiveView page's Wallaby E2E test MUST cover:

| Category | Description | alarm_investigation Examples | Min Features |
|----------|-------------|----------------------------|--------------|
| **C1: Page Structure** | Headings, navigation links, section presence | h1 "Investigation:", "Back to Active Alarms" link | 2-4 |
| **C2: Status/Badge Display** | Dynamic badges, severity indicators, state labels | "INVESTIGATING" badge, "CAUTION" severity | 2-4 |
| **C3: Data Grid/Summary** | Key-value data display, labels with values | Type=INTRUSION, Site=HQ Building, Zone, Device | 4-8 |
| **C4: Timeline/History** | Ordered event entries, chronological data | TRIGGERED, ENRICHED, ACKNOWLEDGED, DISPATCHED entries | 3-6 |
| **C5: Interactive Elements** | Forms, textareas, submission with DOM change | Notes textarea + "Add Note" → NOTE entry appears | 3-6 |
| **C6: Media/Rich Content** | Video playback, charts, SVG, external links | play_video → "Playing...", export_clip → flash | 3-6 |
| **C7: AI/Advisory Panels** | AI recommendations, confidence, disclaimers | AI Copilot Insight, Confidence, "ADVISORY only" | 2-4 |
| **C8: Action Buttons** | Each button tested for BOTH status change AND flash | Verify→VERIFIED+flash, False Alarm→FALSE_ALARM+flash | 4-16 |

**Key Quality Rules:**
1. Every `handle_event` clause MUST have at least one feature testing it
2. Every action button tested TWICE: once for status badge change, once for flash message
3. Two-step commit flows (SC-SAFETY-001) need arm→confirm→cancel test sequences
4. PubSub-driven pages need a "refresh stability" feature (sleep past interval, re-assert)
5. All selectors derived from actual HEEx source (source-first, no guessing)

---

## 2. Current State Assessment

### 2.1 Existing Wallaby E2E Files

| Tier | Pages | Avg Features | Description |
|------|-------|-------------|-------------|
| **Gold (40+)** | 2 | 48 | alarm_investigation (48), copilot (48) |
| **Silver (25-39)** | 5 | 29 | diagnostics (32), analytics (30), commands (25), mesh (25), task_board (26) |
| **Bronze (15-24)** | 12 | 18 | Most Prajna pages |
| **Skeleton (<15)** | 14 | 13 | video (11), active_alarms (12), access_control (12), etc. |
| **Missing (0)** | 14 | 0 | Navigation portal, admin pages, CRM, knowledge sub-pages, etc. |

### 2.2 Pages Missing Wallaby E2E Entirely (14 gaps)

| Page | Route | handle_events | Priority |
|------|-------|--------------|----------|
| NavigationPortalLive | `/` | 0 | P2 |
| PrajnaLive (Dashboard) | `/cockpit` | 5 | P1 |
| MonitoringDashboardLive | `/monitoring` | 0 | P2 |
| PerformanceDashboardLive | `/performance` | 0 | P2 |
| SystemStatusLive | `/admin/system-status` | 3 | P1 |
| ConfigManagementLive | `/admin/config` | 7 | P1 |
| PermissionsManagementLive | `/admin/permissions` | 0 | P3 |
| AccessControlMonitoringLive | `/admin/access_control` | 0 | P3 |
| StampTdgGdeDashboardLive | `/analytics/dashboard` | 1 | P2 |
| StampTdgGdeAdvancedAnalyticsLive | `/analytics/stamp-tdg-gde-advanced` | 0 | P2 |
| Knowledge.DeveloperLive | `/cockpit/knowledge/developer` | 5 | P2 |
| Knowledge.ProductLive | `/cockpit/knowledge/product` | 4 | P2 |
| Knowledge.SRELive | `/cockpit/knowledge/sre` | 4 | P2 |
| Crm.DashboardLive | (unrouted) | 2 | P3 |

---

## 3. Per-Page Gold Standard Plan

### 3.1 Wave 1 — Safety-Critical Pages (P0, 8 pages, ~320 features)

These pages have two-step commit flows (SC-SAFETY-001) or safety-critical actions.

#### 3.1.1 CommandsLive — `/cockpit/commands` (Current: 25 → Target: 45)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C1 | 0 (covered) | Command Center heading present |
| C2 | +2 | Target status badge, armed indicator |
| C3 | +3 | Target selector grid values, command history entries |
| C4 | +3 | Command result log entries (success, failure, timeout) |
| C5 | +2 | Confirmation text input, update_confirmation event |
| C6 | 0 | No media content |
| C7 | 0 | No AI panel |
| C8 | +10 | **ARM/FIRE PROTOCOL**: arm_command → armed badge + flash, confirm_command → executed + flash, cancel_command → cancelled + flash. Each of 5 target types: select_target → target displayed |

**New features needed: +20 (25→45)**

#### 3.1.2 ShutdownLive — `/cockpit/shutdown` (Current: 20 → Target: 42)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C1 | 0 (covered) | |
| C2 | +2 | Mode badge (graceful/force), phase indicator |
| C3 | +3 | Timeout display, mode selector values |
| C4 | +4 | Phase progress entries (each shutdown phase) |
| C5 | +2 | update_mode select, update_timeout input |
| C8 | +11 | **ARM/FIRE**: initiate_shutdown → phase started + flash, abort_shutdown → aborted + flash, force_shutdown_arm → ARMED badge, force_shutdown_confirm → force executing + flash, force_shutdown_cancel → cancelled + flash. Each tested for BOTH status AND flash |

**New features needed: +22 (20→42)**

#### 3.1.3 GuardianLive — `/cockpit/guardian-approval` (Current: 44 → Target: 52)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C2 | +2 | Proposal priority badges (P0-P3 colors) |
| C4 | +2 | Audit trail entries after approve/veto |
| C8 | +4 | **TWO-STEP COMMIT**: request_approve → confirmation modal, confirm_action → approved + flash, request_veto → veto modal, cancel_confirm → modal dismissed. Filter by priority |

**New features needed: +8 (44→52)**

#### 3.1.4 AlarmsLive — `/cockpit/alarms` (Current: 20 → Target: 48)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C1 | 0 (covered) | |
| C2 | +2 | Storm status badge, filter active indicator |
| C3 | +4 | Severity counts grid (Critical/Warning/Caution/Advisory values) |
| C4 | +3 | Workflow tracking entries (Pending, In Progress, Escalated, Resolved) |
| C5 | +2 | Search input fill_in + submit, status select change |
| C7 | +2 | Sentinel health panel, KPI metrics (MTTR, d-prime) |
| C8 | +15 | filter_severity→filtered list, filter_status→filtered, search→results, acknowledge→flash, silence→flash, escalate→flash, select_alarm→detail shown, ack_all_advisory→flash, acknowledge_storm→flash, export_report→flash, configure_thresholds→modal. Each action for status + flash |

**New features needed: +28 (20→48)**

#### 3.1.5 ThreatLive — `/cockpit/threat` (Current: 22 → Target: 42)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C2 | +2 | Severity filter active indicator, threat count badge |
| C3 | +3 | Threat detail panel values (source, timestamp, confidence) |
| C4 | +2 | Threat timeline entries |
| C8 | +13 | filter_severity→filtered, filter_status→filtered, select_threat→detail panel, close_detail→panel closed, acknowledge_threat→flash+status, dismiss_threat→flash+status, acknowledge_all→flash. Each for status AND flash |

**New features needed: +20 (22→42)**

#### 3.1.6 ClusterLive — `/cockpit/cluster` (Current: 20 → Target: 44)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C2 | +2 | Quorum status badge, autoscale indicator |
| C3 | +3 | Node list with roles, pool size display |
| C5 | +2 | Scale pool input, add_node form |
| C8 | +17 | select_node→detail shown, force_election→flash+new leader, add_node→node added+flash, remove_node→node removed+flash, scale_pool→scaled+flash, toggle_autoscale→toggled+flash. Each for status AND flash |

**New features needed: +24 (20→44)**

#### 3.1.7 ActiveAlarmsLive — `/operations/alarms` (Current: 12 → Target: 44)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C1 | +2 | Operations Center heading, navigation breadcrumb |
| C2 | +3 | Severity filter badges, active count badge, filter indicator |
| C3 | +4 | Alarm list table rows with severity, source, timestamp, status |
| C5 | +3 | Search input, status select, batch toggle checkboxes |
| C8 | +20 | filter_severity→filtered, filter_status→filtered, search→results, acknowledge→flash+status, acknowledge_all→flash, escalate→flash+status, silence→flash+status, toggle_select→checkbox toggled, batch_acknowledge→batch flash. Each for status AND flash |

**New features needed: +32 (12→44)**

#### 3.1.8 AccessDashboardLive — `/operations/access` (Current: varies → Target: 42)

| Cat | Features to Add | Details |
|-----|----------------|---------|
| C1 | +2 | Access Control Dashboard heading, zone map section |
| C2 | +2 | Zone status badges, access point indicators |
| C3 | +4 | Access point detail values, event log entries |
| C5 | +2 | Point selection, zone filter |
| C8 | +16 | select_point→detail shown, grant_access→flash+status, revoke_access→flash+status, lockdown_zone→LOCKED badge+flash, unlock_all→unlocked+flash, close_detail→panel closed. Each for status AND flash |

**New features needed: ~26**

---

### 3.2 Wave 2 — High-Interaction Pages (P1, 10 pages, ~280 features)

#### 3.2.1 SettingsLive — `/cockpit/settings` (Current: 16 → Target: 46)

11 handle_events. Each needs status+flash verification:
- update_display, update_threshold, update_ai, toggle_llm, save_changes, reset_defaults, export_config, import_config, modify_envelope, envelope_auth, cancel_envelope_edit
- **Envelope auth is two-step commit (SC-SAFETY-001)**

**New features needed: +30 (16→46)**

#### 3.2.2 DiagnosticsLive — `/cockpit/diagnostics` (Current: 32 → Target: 48)

10 handle_events + tab switching:
- switch_tab (4 tabs), toggle_live_tail, update_filter, run_health_check, dump_state, trace_request, profile_cpu, export_logs, clear_old_logs, open_signoz

**New features needed: +16 (32→48)**

#### 3.2.3 TestCockpitLive — `/cockpit/test-evolution` (Current: varies → Target: 44)

8 handle_events + 4 PubSub topics:
- switch_tab, start_evolution→running+flash, stop_evolution→stopped+flash, run_ooda→cycle complete+flash, generate_tests→generated+flash, watch_module, unwatch_module, update_genome
- PubSub stability: test_generated, fitness_updated, ooda_cycle_complete

**New features needed: ~30**

#### 3.2.4 DispatchConsoleLive — `/operations/dispatch` (Current: 14 → Target: 48)

12 handle_events (highest in system):
- select_assignment, new_assignment, cancel_new_assignment, create_assignment, track, reassign, escalate, divert, add_task, broadcast_all, shift_handover, reports

**New features needed: +34 (14→48)**

#### 3.2.5 VideoWallLive — `/operations/video` (Current: varies → Target: 44)

9 handle_events + video-specific:
- set_layout (4 layouts), set_group, select_camera→stream panel, toggle_fullscreen, toggle_ptz→PTZ controls shown, ptz_command→camera moved+flash, snapshot→flash, start_clip→recording+flash, search_recordings

**New features needed: ~30**

#### 3.2.6 CopilotLive — `/cockpit/ai-copilot` (Current: 48 — ALREADY GOLD)

Already at gold standard. No changes needed.

#### 3.2.7 KnowledgeLive — `/cockpit/knowledge` (Current: 15 → Target: 44)

9 handle_events:
- select_holon, toggle_expand, change_view (graph/list/tree), filter_type, search, create_adr, create_holon, view_debt, view_radar

**New features needed: +29 (15→44)**

#### 3.2.8 ContainersLive — `/cockpit/containers` (Current: varies → Target: 40)

6 handle_events:
- select_container→detail panel, restart_container→flash+restarting status, view_logs→log panel opened, close_logs→panel closed, start_all→all started+flash, stop_all→all stopped+flash

**New features needed: ~25**

#### 3.2.9 MeshLive — `/cockpit/mesh` (Current: 25 → Target: 42)

5 handle_events:
- select_node→detail panel, clear_selection→panel closed, restart_node→flash+restarting, isolate_node→flash+ISOLATED badge, drain_node→flash+DRAINING badge

**New features needed: +17 (25→42)**

#### 3.2.10 ConfigManagementLive — `/admin/config` (NEW, Target: 44)

7 handle_events + tab switching:
- switch_tab (config/flags/integrations), search, filter_config, update_config→flash, toggle_flag→toggled+flash, test_integration→flash, sync_integration→flash

**New features needed: 44 (new file)**

---

### 3.3 Wave 3 — Standard Interactive Pages (P2, 12 pages, ~380 features)

#### 3.3.1 PrajnaLive (Dashboard) — `/cockpit` (NEW, Target: 38)

5 handle_events + 4 PubSub topics:
- C1: PRAJNA heading, navigation panel, MESH NODES section, ACTIVE ALARMS
- C3: Quick metrics sparklines, container status grid
- C4: Recent logs entries
- C7: AI COPILOT panel, OODA cycle status
- PubSub stability: metrics/alarms/insights/ooda topics refresh

**New features needed: 38 (new file)**

#### 3.3.2 ObservabilityLive — `/cockpit/observability` (Current: 13 → Target: 38)

4 handle_events + tab switching:
- switch_tab (Metrics/Traces/Logs/SigNoz), view_trace→span detail, open_signoz→flash, export_metrics→flash
- 6 metric cards, dynamic refresh stability

**New features needed: +25 (13→38)**

#### 3.3.3 AccessControlLive — `/cockpit/access-control` (Current: 12 → Target: 38)

6 handle_events:
- filter_action, filter_resource, filter_timerange, search, select_permission→detail panel, close_detail

**New features needed: +26 (12→38)**

#### 3.3.4 DevicesLive — `/cockpit/devices` (Current: 18 → Target: 38)

6 handle_events:
- filter_status, filter_type, search, select_device→detail panel, close_detail, toggle_view (grid/list)

**New features needed: +20 (18→38)**

#### 3.3.5 VideoLive — `/cockpit/video` (Current: 11 → Target: 34)

3 handle_events:
- filter_status, select_stream→detail panel, close_detail

**New features needed: +23 (11→34)**

#### 3.3.6 AnalyticsLive — `/cockpit/analytics` (Current: 30 → Target: 40)

3 handle_events:
- filter_status, select_report→detail panel, close_detail

**New features needed: +10 (30→40)**

#### 3.3.7 ComplianceLive — `/cockpit/compliance` (Current: varies → Target: 40)

6 handle_events:
- filter_framework, filter_status, filter_regulation, audit_page→page changed, select_control→detail, close_detail

**New features needed: ~25**

#### 3.3.8 HealthSparklineLive — `/cockpit/health-sparklines` (Current: 32 → Target: 40)

2 handle_events + 3 PubSub topics:
- select_node→node detail, set_threshold→threshold updated
- SVG sparkline rendering, node matrix, PubSub stability

**New features needed: +8 (32→40)**

#### 3.3.9 Knowledge.DeveloperLive — `/cockpit/knowledge/developer` (NEW, Target: 32)

5 handle_events:
- switch_view, select_item→detail, search, filter_status, use_pattern→flash

**New features needed: 32 (new file)**

#### 3.3.10 Knowledge.ProductLive — `/cockpit/knowledge/product` (NEW, Target: 30)

4 handle_events:
- switch_view, select_item→detail, search, filter_status

**New features needed: 30 (new file)**

#### 3.3.11 Knowledge.SRELive — `/cockpit/knowledge/sre` (NEW, Target: 30)

4 handle_events:
- switch_view, select_item→detail, search, filter_severity

**New features needed: 30 (new file)**

#### 3.3.12 SystemStatusLive — `/admin/system-status` (NEW, Target: 34)

3 handle_events + 3 PubSub topics:
- set_view (multi-view), restart_container→flash, view_logs→log panel
- PubSub: system_health, container_metrics, agent_status

**New features needed: 34 (new file)**

---

### 3.4 Wave 4 — Read-Only/Passive Pages (P2-P3, 11 pages, ~220 features)

These pages have 0 handle_events but still need C1-C4 + C7 coverage.

#### 3.4.1 SentinelDashboardLive — `/cockpit/sentinel` (Current: varies → Target: 28)

0 handle_events, 2 PubSub topics:
- C1: Sentinel heading, Immune System section
- C3: Threat feed entries, health metrics
- C4: Threat timeline with PubSub-driven updates
- PubSub stability: sentinel:threats, prajna:threats

**New features needed: ~20**

#### 3.4.2 GuardianDashboardLive — `/cockpit/guardian` (Current: 14 → Target: 24)

0 handle_events, 1 PubSub:
- C1: Guardian Governance heading
- C3: Constitutional health metrics, governance status

**New features needed: +10 (14→24)**

#### 3.4.3 RegisterLive — `/cockpit/register` (Current: 17 → Target: 26)

0 handle_events, 1 PubSub:
- C1: Immutable Register heading
- C3: Block count, hash chain display, RS parity status

**New features needed: +9 (17→26)**

#### 3.4.4 GitIntelligenceLive — `/cockpit/git-intelligence` (Current: 18 → Target: 30)

0 handle_events, 3 PubSub topics:
- C3: KPI cards (commit rate, health, threat count)
- PubSub stability: git_intelligence, health, threat topics
- Refresh interval test (3s refresh)

**New features needed: +12 (18→30)**

#### 3.4.5 TopologyLive — `/cockpit/topology` (Current: 16 → Target: 24)

0 handle_events, 1 PubSub:
- C1: Holographic Visualizer heading
- C6: SVG canvas rendering, node elements

**New features needed: +8 (16→24)**

#### 3.4.6 PrometheusLive — `/cockpit/prometheus` (Current: 18 → Target: 26)

0 handle_events, timer-driven:
- C1: PROMETHEUS Verification heading, SIL-6 badge
- C3: Verification metrics, constraint counts

**New features needed: +8 (18→26)**

#### 3.4.7 NavigationPortalLive — `/` (NEW, Target: 20)

0 handle_events:
- C1: Route category grid headings
- C3: All category links present and correct
- Link navigation: click category → correct page loads

**New features needed: 20 (new file)**

#### 3.4.8 MonitoringDashboardLive — `/monitoring` (NEW, Target: 22)

0 handle_events, 1 PubSub:
- C1: System Monitoring heading
- C3: Active Alarms count, Processing Rate, Average Latency, System Health
- C4: Recent High-Priority Alarms, System Alerts
- Refresh stability

**New features needed: 22 (new file)**

#### 3.4.9 PerformanceDashboardLive — `/performance` (NEW, Target: 20)

0 handle_events, 1 PubSub:
- C1: Performance Dashboard heading
- C3: BEAM Memory, Schedulers, Processes, System Status
- Refresh stability

**New features needed: 20 (new file)**

#### 3.4.10 StampTdgGdeDashboardLive — `/analytics/dashboard` (NEW, Target: 24)

1 handle_event, 4 PubSub topics:
- C1: STAMP/TDG/GDE Dashboard heading
- C3: STAMP metrics, TDG metrics, GDE metrics
- PubSub stability: 4 topics refresh

**New features needed: 24 (new file)**

#### 3.4.11 StampTdgGdeAdvancedAnalyticsLive — `/analytics/stamp-tdg-gde-advanced` (NEW, Target: 20)

0 handle_events:
- C1: Advanced Analytics heading
- C3: Analytical sections present

**New features needed: 20 (new file)**

---

### 3.5 Wave 5 — Deferred/Unrouted (P3, 2 pages, ~30 features)

#### 3.5.1 PermissionsManagementLive — `/admin/permissions` (NEW, Target: 16)

All handle_events commented out — test mount + section presence only.

#### 3.5.2 AccessControlMonitoringLive — `/admin/access_control` (NEW, Target: 14)

Read-only — test mount + section presence.

---

## 4. Feature Count Summary

| Wave | Pages | New Features | Upgraded Features | Total Target |
|------|-------|-------------|-------------------|-------------|
| W1: Safety-Critical | 8 | 0 new files | +200 to existing | ~360 |
| W2: High-Interaction | 10 | 1 new file (config) | +211 to existing + 44 new | ~440 |
| W3: Standard Interactive | 12 | 5 new files | +112 to existing + 164 new | ~392 |
| W4: Read-Only/Passive | 11 | 5 new files | +47 to existing + 106 new | ~264 |
| W5: Deferred | 2 | 2 new files | +30 new | ~30 |
| **TOTAL** | **43** | **13 new files** | **+570 upgrades + 344 new** | **~1,486** |

### Current vs Target

| Metric | Current | Target | Delta |
|--------|---------|--------|-------|
| Wallaby E2E files | ~33 | 46 | +13 |
| Total features | ~605 | ~1,486 | +881 |
| Avg features/page | 18.3 | 34.5 | +16.2 |
| Pages at gold (40+) | 2 | 18 | +16 |
| Pages at silver (25-39) | 5 | 15 | +10 |
| Pages below bronze (<15) | 14 | 0 | -14 |
| Missing pages | 14 | 0 | -14 |

---

## 5. Execution Strategy

### 5.1 Agent Deployment (11 parallel agents)

| Agent | Assignment | Files | Est. Features |
|-------|-----------|-------|--------------|
| A1 | W1: CommandsLive + ShutdownLive (ARM/FIRE) | 2 | 87 |
| A2 | W1: AlarmsLive + ActiveAlarmsLive | 2 | 92 |
| A3 | W1: GuardianLive + ThreatLive + ClusterLive | 3 | 138 |
| A4 | W1: AccessDashboardLive + W2: MeshLive | 2 | 68 |
| A5 | W2: SettingsLive + DiagnosticsLive | 2 | 94 |
| A6 | W2: DispatchConsoleLive + VideoWallLive | 2 | 92 |
| A7 | W2: TestCockpitLive + KnowledgeLive + ContainersLive | 3 | 109 |
| A8 | W2: ConfigManagementLive (NEW) + W3: SystemStatusLive (NEW) | 2 | 78 |
| A9 | W3: ObservabilityLive + AccessControlLive + DevicesLive + VideoLive | 4 | 134 |
| A10 | W3: Knowledge sub-pages (3 NEW) + ComplianceLive + HealthSparklineLive + AnalyticsLive | 6 | 172 |
| A11 | W4: All passive pages (11 files, 5 NEW) + W5: Deferred (2 NEW) | 13 | 284 |

### 5.2 Source-First Protocol (MANDATORY)

Before writing ANY Wallaby selector, agents MUST:

```
1. Read lib/indrajaal_web/live/{namespace}/{page}_live.ex
2. Extract ALL handle_event clause names
3. Extract ALL HEEx selectors (phx-click, phx-value-*, data-role, id)
4. Extract ALL flash messages (put_flash calls)
5. Extract ALL assign keys used in template conditionals
6. THEN write feature blocks using ACTUAL selectors
```

### 5.3 Quality Gate Per File

Each Wallaby test file MUST pass:

- [ ] Covers ALL 8 categories (C1-C8) applicable to the page
- [ ] Every `handle_event` has at least one feature
- [ ] Every action button tested for BOTH status change AND flash message
- [ ] Two-step commit flows test arm→confirm AND arm→cancel paths
- [ ] PubSub-driven pages have refresh stability test
- [ ] `@moduletag :wallaby` and `async: false` present
- [ ] Uses `IndrajaalWeb.FeatureCase`
- [ ] STAMP constraints listed in @moduledoc
- [ ] Feature count >= 20 for interactive pages, >= 14 for passive pages

---

## 6. Template: Gold Standard Test Structure

```elixir
defmodule IndrajaalWeb.{Namespace}.{Page}LiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the {Page} LiveView page.

  Tests the full interaction lifecycle including:
  - C1: Page structure (headings, navigation, sections)
  - C2: Status/badge display (dynamic indicators)
  - C3: Data grid/summary (key-value pairs, labels)
  - C4: Timeline/history (chronological entries)
  - C5: Interactive elements (forms, inputs, submissions)
  - C6: Media/rich content (video, charts, SVG)
  - C7: AI/advisory panels (recommendations, disclaimers)
  - C8: Action buttons (status change + flash verification)

  Run with: WALLABY_ENABLED=true mix test --only wallaby

  STAMP: SC-COV-008 (Wallaby E2E mandatory for all LiveView pages)
         SC-HMI-011 (8x8 Matrix path coverage)
         {additional SC-* constraints specific to page}
  """
  use IndrajaalWeb.FeatureCase, async: false

  @moduletag :wallaby
  @default_path "{route}"

  # ── C1: Page Structure ──────────────────────────────────────────────
  feature "page heading is present", %{session: session} do ... end
  feature "navigation link is present", %{session: session} do ... end

  # ── C2: Status/Badge Display ────────────────────────────────────────
  feature "status badge shows current state", %{session: session} do ... end

  # ── C3: Data Grid/Summary ──────────────────────────────────────────
  feature "label X shows value Y", %{session: session} do ... end

  # ── C4: Timeline/History ───────────────────────────────────────────
  feature "timeline shows recent entries", %{session: session} do ... end

  # ── C5: Interactive Elements ───────────────────────────────────────
  feature "form submission updates DOM", %{session: session} do ... end

  # ── C6: Media/Rich Content ─────────────────────────────────────────
  feature "media element renders correctly", %{session: session} do ... end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────────
  feature "AI advisory disclaimer present", %{session: session} do ... end

  # ── C8: Action Buttons (status + flash) ────────────────────────────
  feature "clicking {action} changes status to {STATUS}", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='{event}']"))
    |> assert_has(css("span", text: "{STATUS}"))
  end

  feature "clicking {action} triggers {message} flash", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='{event}']"))
    |> assert_has(css("[role='alert']", text: "{message}"))
  end
end
```

---

## 7. Companion Test Levels (L1-L5 Gap Fill)

For each page upgraded to gold standard Wallaby (L6), ensure companion coverage:

| Level | Gap Pages | Action |
|-------|-----------|--------|
| L1 (Property) | Threat, Guardian, Copilot, Git Intelligence, Register, Startup, Sentinel, Knowledge sub-pages | Create `*_prop_test.exs` with dual PropCheck+StreamData |
| L2 (FMEA) | System Status, Devices, Video, Active Alarms, Alarm Investigation, Git Intelligence, Register, Startup, Sentinel | Create `*_fmea_test.exs` with RPN scoring |
| L5 (BDD) | Containers, Test Cockpit, Config Management, all admin pages, Knowledge sub-pages | Create `.feature` + step definitions |
| L3 (Quint) | Git Intelligence, Copilot interaction | Create temporal logic specs |

---

## 8. Verification

```bash
# Count all Wallaby features after completion
grep -r "feature " test/indrajaal_web/live/**/*wallaby_test.exs | wc -l
# Target: >= 1,400

# Count Wallaby test files
find test -name "*wallaby_test.exs" | wc -l
# Target: >= 46

# Compile check
MIX_ENV=test mix compile --warnings-as-errors

# Run all Wallaby tests (requires devenv shell)
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 \
  POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
  DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
  NO_TIMEOUT=true PATIENT_MODE=enabled \
  ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
  MIX_ENV=test mix test --only wallaby
```

---

## 9. Success Criteria

| Criterion | Threshold |
|-----------|-----------|
| All LiveView pages have Wallaby E2E | 46/46 (100%) |
| All interactive pages have >= 30 features | 100% |
| All passive pages have >= 14 features | 100% |
| All handle_events covered by at least 1 feature | 100% |
| All action buttons tested for status + flash | 100% |
| All two-step commit flows test arm/confirm/cancel | 100% |
| All PubSub pages have refresh stability test | 100% |
| Compilation: 0 errors | Mandatory |
| Average features per page | >= 30 |
| Total Wallaby features | >= 1,400 |
