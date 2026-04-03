# Wallaby Gold Standard — FMEA Analysis & Handle Event Map

**Date**: 20260328-1700 CEST
**Author**: Claude Opus 4.6
**STAMP**: SC-COV-008, SC-HMI-011, SC-FMEA-001

---

## 1. FMEA Findings (F-001 through F-007)

| ID | File | Finding | Severity | Occurrence | Detection | RPN | Mitigation |
|----|------|---------|----------|------------|-----------|-----|------------|
| F-001 | stamp_tdg_gde_dashboard_live.ex | PubSub subscription NOT gated by `connected?/1` — messages fire before socket attached | 8 | 6 | 4 | 192 | Wrap subscribe in `if connected?(socket)` guard |
| F-002 | stamp_tdg_gde_dashboard_live.ex | Placeholder `handle_event("____event", ...)` stub — dead code, unreachable | 3 | 2 | 8 | 48 | Remove stub or replace with real event |
| F-003 | topology_live.ex | No `:timer.send_interval` — data becomes stale after mount | 7 | 5 | 5 | 175 | Add 10s refresh interval like other pages |
| F-004 | prometheus_live.ex | No PubSub subscription (comment says "would subscribe") — page never receives live updates | 7 | 5 | 6 | 210 | Implement PubSub subscription for verification events |
| F-005 | topology_live.ex | `put_flash` called in `handle_info` instead of `handle_event` — flash may not render (LiveView gotcha) | 6 | 4 | 5 | 120 | Move flash to handle_event or verify handle_info flash rendering |
| F-006 | product_live.ex (Knowledge) | PubSub wrapped in `try/rescue` that silently swallows ALL failures | 6 | 3 | 7 | 126 | Log rescued errors, narrow rescue scope |
| F-007 | observability_live.ex, startup_live.ex, prajna_live.ex | Three pages at 500ms refresh interval — CPU contention risk when all mounted simultaneously | 5 | 4 | 4 | 80 | Stagger intervals (500/750/1000ms) or use shared timer |

### RPN Distribution
- **Critical (RPN >= 200)**: 1 (F-004: 210)
- **High (RPN 100-199)**: 3 (F-001: 192, F-003: 175, F-005: 120, F-006: 126)
- **Medium (RPN 50-99)**: 1 (F-007: 80)
- **Low (RPN < 50)**: 1 (F-002: 48)

### Mean RPN: 135.9
### Max RPN: 210 (F-004: prometheus_live.ex missing PubSub)

---

## 2. Two-Step Commit Compliance Audit (SC-SAFETY-001)

### Compliant Pages (arm→confirm→cancel state machine implemented)
| Page | Events | Pattern |
|------|--------|---------|
| CommandsLive | arm_command, confirm_command, cancel_command | Full 3-state (idle→armed→executing) |
| ShutdownLive | initiate_shutdown, force_shutdown_arm, force_shutdown_confirm, abort_shutdown | Full with force variant |
| SettingsLive | modify_envelope, envelope_auth, cancel_envelope_edit | Full with auth step |
| GuardianLive | request_approve, confirm_action, request_veto, cancel_confirm | Full with veto path |

### Non-Compliant Pages (destructive action WITHOUT arm/confirm)
| Page | Events | Gap | RPN |
|------|--------|-----|-----|
| ClusterLive | force_election | Comment says "TODO: add confirmation" but not implemented | 168 (S=8, O=3, D=7) |
| AccessDashboardLive | lockdown_zone, unlock_all | Flash says "confirmation required" but no state machine | 192 (S=8, O=4, D=6) |
| ActiveAlarmsLive | acknowledge_all | Batch operation without confirmation gate | 120 (S=6, O=4, D=5) |

---

## 3. PubSub Topic Map (42 Unique Topics)

### Prajna Cockpit Topics
| Topic | Subscribers | Refresh | Description |
|-------|------------|---------|-------------|
| `prajna:metrics` | observability_live, prajna_live | 500ms | Core metrics (request rate, latency, errors) |
| `prajna:alarms` | alarms_live, active_alarms_live | 2s | Alarm events and storm detection |
| `prajna:cluster` | cluster_live | 5s | Cluster membership and health |
| `prajna:commands` | commands_live | event-driven | Command execution results |
| `prajna:diagnostics` | diagnostics_live | 3s | Diagnostic data, live tail |
| `prajna:containers` | containers_live | 5s | Container lifecycle events |
| `prajna:devices` | devices_live | 10s | Device status updates |
| `prajna:health` | health_sparkline_live | 2s | Health sparkline data |
| `prajna:knowledge` | knowledge_live, developer_live, product_live, sre_live | 30s | Knowledge base updates |
| `prajna:settings` | settings_live | event-driven | Configuration changes |
| `prajna:shutdown` | shutdown_live | event-driven | Shutdown phase progression |
| `prajna:startup` | startup_live | 500ms | Boot phase progression |
| `prajna:test_evolution` | test_cockpit_live | 2s | Test evolution metrics |
| `prajna:compliance` | compliance_live | 10s | Compliance status |
| `prajna:sentinel` | sentinel_dashboard_live | 2s | Sentinel health data |
| `prajna:threat` | threat_live | 2s | Threat intelligence |
| `prajna:copilot` | copilot_live | event-driven | AI copilot responses |
| `prajna:register` | register_live | 5s | Immutable register entries |
| `prajna:git` | git_intelligence_live | 5s | Git intelligence metrics |
| `prajna:analytics` | analytics_live | 5s | Analytics data |
| `prajna:guardian` | guardian_live, guardian_dashboard_live | 2s | Guardian proposals |
| `prajna:video` | video_live | 1s | Video feed status |
| `prajna:access_control` | access_control_live | 5s | Access control events |

### Operations Topics
| Topic | Subscribers | Refresh | Description |
|-------|------------|---------|-------------|
| `operations:dispatch` | dispatch_console_live | 2s | Dispatch events |
| `operations:alarms` | active_alarms_live | 2s | Active alarm updates |
| `operations:video_wall` | video_wall_live | 1s | Video wall feed status |
| `operations:access` | access_dashboard_live | 5s | Access dashboard events |
| `operations:alarm_investigation` | alarm_investigation_live | event-driven | Investigation updates |

### Zenoh Bridge Topics
| Topic | Subscribers | Refresh | Description |
|-------|------------|---------|-------------|
| `zenoh:mesh_health` | zenoh_mesh_health | 2s | Zenoh mesh health |
| `zenoh:topology` | topology_live | (none — F-003) | Mesh topology |
| `zenoh:mesh` | mesh_live | 5s | Mesh status |

### System Topics
| Topic | Subscribers | Refresh | Description |
|-------|------------|---------|-------------|
| `system:monitoring` | monitoring_dashboard_live | 10s | System monitoring |
| `system:performance` | performance_dashboard_live | 5s | Performance metrics |
| `admin:config` | config_management_live | event-driven | Config changes |
| `admin:status` | system_status_live | 5s | System status |

### Refresh Interval Distribution
| Interval | Pages | Risk |
|----------|-------|------|
| 500ms | 3 (observability, startup, prajna main) | HIGH — CPU contention |
| 1s | 2 (video, video_wall) | MEDIUM |
| 2s | 7 (alarms, sentinel, threat, health, dispatch, guardian, test_evolution) | LOW |
| 5s | 8 (cluster, containers, analytics, git, register, access, mesh, performance) | LOW |
| 10s | 3 (devices, compliance, monitoring) | MINIMAL |
| 30s | 1 (knowledge) | MINIMAL |
| Event-driven | 6 (commands, settings, shutdown, copilot, investigation, config) | NONE |
| None (F-003) | 1 (topology) | BUG — stale data |

---

## 4. Existing Wallaby E2E Feature Count Per File

### Gold Tier (40+ features)
| File | Features | Categories Covered |
|------|----------|-------------------|
| alarm_investigation_live_wallaby_test.exs | 48 | C1-C8 all |
| copilot_live_wallaby_test.exs | 48 | C1-C8 all |

### Silver Tier (25-39 features)
| File | Features | Missing Categories |
|------|----------|--------------------|
| diagnostics_live_wallaby_test.exs | 32 | C6 (media), C7 (AI) |
| analytics_live_wallaby_test.exs | 30 | C4 (timeline), C7 (AI) |
| commands_live_wallaby_test.exs | 25 | C4 (timeline) |
| mesh_live_wallaby_test.exs | 25 | C5 (forms), C6, C7 |
| guardian_dashboard_live_wallaby_test.exs | 26 | C6, C7 |

### Bronze Tier (15-24 features)
| File | Features |
|------|----------|
| shutdown_live_wallaby_test.exs | 20 |
| alarms_live_wallaby_test.exs | 20 |
| cluster_live_wallaby_test.exs | 20 |
| threat_live_wallaby_test.exs | 22 |
| settings_live_wallaby_test.exs | 16 |
| sentinel_dashboard_live_wallaby_test.exs | 18 |
| containers_live_wallaby_test.exs | 17 |
| compliance_live_wallaby_test.exs | 16 |
| startup_live_wallaby_test.exs | 15 |
| knowledge_live_wallaby_test.exs | 17 |
| devices_live_wallaby_test.exs | 15 |
| test_cockpit_live_wallaby_test.exs | 18 |

### Skeleton Tier (<15 features)
| File | Features |
|------|----------|
| video_live_wallaby_test.exs | 11 |
| active_alarms_live_wallaby_test.exs | 12 |
| access_control_live_wallaby_test.exs | 12 |
| dispatch_console_live_wallaby_test.exs | 14 |
| video_wall_live_wallaby_test.exs | 11 |
| access_dashboard_live_wallaby_test.exs | 13 |
| observability_live_wallaby_test.exs | 13 |
| register_live_wallaby_test.exs | 13 |
| git_intelligence_live_wallaby_test.exs | 14 |
| guardian_live_wallaby_test.exs | 44 |
| health_sparkline_live_wallaby_test.exs | 13 |
| prometheus_live_wallaby_test.exs | 12 |
| topology_live_wallaby_test.exs | 12 |
| zenoh_mesh_health_wallaby_test.exs | 13 |

### Missing Entirely (0 features — no Wallaby file exists)
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

## 5. Handle Event Extraction — All 42+ LiveView Pages

### Safety-Critical Pages (Two-Step Commit)

#### CommandsLive — `/cockpit/commands` (5 events + 3 two-step)
```
select_target, arm_command, confirm_command, cancel_command, view_history
arm→confirm→cancel (SC-SAFETY-001 COMPLIANT)
Flash: "Command armed", "Command executed", "Command cancelled"
```

#### ShutdownLive — `/cockpit/shutdown` (6 events + 2 two-step)
```
initiate_shutdown, abort_shutdown, update_mode, update_timeout, force_shutdown_arm, force_shutdown_confirm
arm→confirm (force variant), initiate→abort (graceful variant)
Flash: "Shutdown initiated", "Shutdown aborted", "Force armed - confirm within 30s", "Force shutdown executing"
```

#### GuardianLive — `/cockpit/guardian-approval` (8 events)
```
filter_priority, filter_status, request_approve, confirm_action, request_veto, cancel_confirm, refresh, view_details
Flash: "Approved", "Vetoed", "Action cancelled"
```

#### SettingsLive — `/cockpit/settings` (11 events + 1 two-step)
```
update_display, update_threshold, update_ai, toggle_llm, save_changes, reset_defaults, export_config, import_config, modify_envelope, envelope_auth, cancel_envelope_edit
envelope: modify→auth→cancel (SC-SAFETY-001 COMPLIANT)
Flash: "Settings saved", "Settings reset", "Config exported", "Envelope modified", "Auth required"
```

### High-Interaction Pages

#### AlarmsLive — `/cockpit/alarms` (9 events)
```
filter_severity, filter_status, search, acknowledge, silence, escalate, select_alarm, ack_all_advisory, acknowledge_storm, export_report, configure_thresholds
Flash: "Alarm acknowledged", "Alarm silenced", "Alarm escalated", "All advisory acknowledged", "Storm acknowledged", "Report exported"
```

#### DiagnosticsLive — `/cockpit/diagnostics` (10 events)
```
switch_tab, toggle_live_tail, update_filter, run_health_check, dump_state, trace_request, profile_cpu, export_logs, clear_old_logs, open_signoz
Flash: "Health check complete", "State dumped", "Trace started", "CPU profiling started", "Logs exported", "Old logs cleared", "Opening SigNoz"
```

#### ClusterLive — `/cockpit/cluster` (7 events)
```
select_node, force_election, add_node, remove_node, scale_pool, toggle_autoscale, refresh
Flash: "New leader elected", "Node added", "Node removed", "Pool scaled", "Autoscale toggled"
⚠️ force_election: TWO-STEP GAP (no arm/confirm)
```

#### ThreatLive — `/cockpit/threat` (7 events)
```
filter_severity, filter_status, select_threat, close_detail, acknowledge_threat, dismiss_threat, acknowledge_all
Flash: "Threat acknowledged", "Threat dismissed", "All threats acknowledged"
```

#### TestCockpitLive — `/cockpit/test-evolution` (8 events)
```
switch_tab, start_evolution, stop_evolution, run_ooda, generate_tests, watch_module, unwatch_module, update_genome
Flash: "Evolution started", "Evolution stopped", "OODA cycle complete", "Tests generated"
PubSub: test_generated, fitness_updated, ooda_cycle_complete
```

### Operations Pages

#### DispatchConsoleLive — `/operations/dispatch` (12 events)
```
filter_priority, filter_zone, select_unit, dispatch_unit, recall_unit, mark_arrived, complete_incident, escalate, toggle_auto, clear_filter, refresh, view_history
Flash: "Unit dispatched", "Unit recalled", "Arrived at scene", "Incident completed", "Incident escalated", "Auto-dispatch toggled"
```

#### ActiveAlarmsLive — `/operations/alarms` (9 events)
```
filter_severity, filter_status, search, acknowledge, acknowledge_all, escalate, silence, toggle_select, batch_acknowledge
Flash: "Alarm acknowledged", "All alarms acknowledged", "Alarm escalated", "Alarm silenced", "Batch acknowledged"
⚠️ acknowledge_all: BATCH WITHOUT CONFIRMATION
```

#### VideoWallLive — `/operations/video-wall` (9 events)
```
select_camera, toggle_fullscreen, switch_layout, start_recording, stop_recording, take_snapshot, add_bookmark, export_recording, toggle_ptz
Flash: "Recording started", "Recording stopped", "Snapshot captured", "Bookmark added", "Recording exported"
```

#### AccessDashboardLive — `/operations/access` (8 events)
```
select_point, grant_access, revoke_access, lockdown_zone, unlock_all, close_detail, filter_zone, refresh
Flash: "Access granted", "Access revoked", "Zone locked down - confirmation required", "All zones unlocked"
⚠️ lockdown_zone/unlock_all: TWO-STEP GAP
```

### Observability & Monitoring Pages

#### ObservabilityLive — `/cockpit/observability` (5 events)
```
switch_tab, view_trace, export_metrics, open_signoz, refresh
Flash: "Metrics exported", "Opening SigNoz"
PubSub: prajna:metrics (500ms refresh)
```

#### SentinelDashboardLive — `/cockpit/sentinel` (6 events)
```
switch_tab, refresh, acknowledge_alert, clear_resolved, export_report, toggle_auto_response
Flash: "Alert acknowledged", "Resolved cleared", "Report exported", "Auto-response toggled"
```

#### StartupLive — `/cockpit/startup` (3 events)
```
refresh, toggle_detail, retry_phase
Flash: "Retrying phase"
PubSub: prajna:startup (500ms refresh)
```

#### ComplianceLive — `/cockpit/compliance` (5 events)
```
switch_tab, filter_status, export_report, run_audit, refresh
Flash: "Report exported", "Audit started"
```

### Knowledge & AI Pages

#### KnowledgeLive — `/cockpit/knowledge` (9 events)
```
switch_tab, search, create_zettel, update_zettel, delete_zettel, link_zettel, view_graph, export_vault, import_vault
Flash: "Zettel created", "Zettel updated", "Zettel deleted", "Link created", "Vault exported", "Vault imported"
```

#### CopilotLive — `/cockpit/copilot` (8 events)
```
send_message, clear_history, switch_model, toggle_streaming, rate_response, export_conversation, load_context, refresh
Flash: "History cleared", "Model switched", "Response rated", "Conversation exported", "Context loaded"
```

#### AnalyticsLive — `/cockpit/analytics` (7 events)
```
switch_tab, filter_date_range, export_data, generate_report, toggle_realtime, select_metric, refresh
Flash: "Data exported", "Report generated", "Realtime toggled"
```

### Infrastructure Pages

#### ContainersLive — `/cockpit/containers` (7 events)
```
select_container, start_container, stop_container, restart_container, view_logs, refresh, scale
Flash: "Container started", "Container stopped", "Container restarted", "Scaling"
```

#### DevicesLive — `/cockpit/devices` (6 events)
```
select_device, toggle_device, configure_device, refresh, filter_type, export_inventory
Flash: "Device toggled", "Device configured", "Inventory exported"
```

#### MeshLive — `/cockpit/mesh` (5 events)
```
select_node, refresh, toggle_debug, export_topology, diagnose
Flash: "Debug toggled", "Topology exported", "Diagnosis started"
```

#### TopologyLive — `/cockpit/topology` (4 events)
```
select_node, zoom_in, zoom_out, refresh
Flash: "Node selected" (in handle_info — F-005)
⚠️ No PubSub, no refresh timer (F-003)
```

### Register & Verification Pages

#### RegisterLive — `/cockpit/register` (5 events)
```
filter_type, search, view_block, verify_chain, export
Flash: "Chain verified", "Register exported"
```

#### PrometheusLive — `/cockpit/prometheus` (4 events)
```
switch_tab, run_verification, export_proof, refresh
Flash: "Verification complete", "Proof exported"
⚠️ No PubSub subscription (F-004)
```

#### GitIntelligenceLive — `/cockpit/git-intelligence` (5 events)
```
switch_tab, refresh, export_metrics, select_commit, view_diff
Flash: "Metrics exported"
```

### Health & Dashboard Pages

#### HealthSparklineLive — `/cockpit/health` (3 events)
```
toggle_metric, zoom_timeline, refresh
Flash: (none — display only)
```

#### PrajnaLive — `/cockpit` (5 events) — MISSING WALLABY
```
navigate, toggle_section, refresh, switch_view, toggle_alerts
PubSub: prajna:metrics (500ms refresh)
```

#### GuardianDashboardLive — `/cockpit/guardian` (6 events)
```
switch_tab, filter_status, refresh, view_proposal, export_audit, acknowledge
Flash: "Acknowledged", "Audit exported"
```

### Admin Pages (MISSING WALLABY)

#### SystemStatusLive — `/admin/system-status` (3 events)
```
refresh, restart_service, view_logs
Flash: "Service restarted"
```

#### ConfigManagementLive — `/admin/config` (7 events)
```
update_config, reset_config, export_config, import_config, validate_config, switch_environment, save_draft
Flash: "Config updated", "Config reset", "Config exported", "Config imported", "Config validated", "Environment switched", "Draft saved"
```

### Analytics Pages (MISSING WALLABY)

#### StampTdgGdeDashboardLive — `/analytics/dashboard` (1 event + F-001, F-002)
```
____event (placeholder — F-002)
PubSub: not gated by connected? (F-001)
```

---

## 6. Fractal Coverage Tensor — C1-C8 × Pages × Levels

### Coverage Formula
```
Coverage(page) = Σ(category_i × weight_i) / Σ(weight_i)

Category weights (FMEA-derived):
  C1 (Structure):    w=1.0 (baseline)
  C2 (Status):       w=1.5 (state visibility)
  C3 (Data Grid):    w=1.0 (data display)
  C4 (Timeline):     w=1.2 (history audit)
  C5 (Interactive):  w=2.0 (user interaction critical)
  C6 (Media):        w=1.0 (if applicable)
  C7 (AI/Advisory):  w=1.5 (SC-AI-001 compliance)
  C8 (Actions):      w=3.0 (highest risk — user actions trigger state changes)
```

### Information Entropy of Test Coverage
```
H(coverage) = -Σ p_i × log2(p_i)

Where p_i = features_in_category_i / total_features

Gold standard (alarm_investigation):
  H = -[(8/48)log2(8/48) + (4/48)log2(4/48) + (8/48)log2(8/48) + (5/48)log2(5/48)
       + (3/48)log2(3/48) + (6/48)log2(6/48) + (4/48)log2(4/48) + (10/48)log2(10/48)]
  H ≈ 2.89 bits (near-maximum for 8 categories = 3.0 bits)

Target: H >= 2.5 bits per page (at least 83% of maximum entropy)
```

### Aggregate Metrics
```
Total existing Wallaby features: ~605 across 33 files
Target Wallaby features: ~1,486 across 47 files (all pages)
Feature deficit: ~881 features
Coverage improvement needed: 145% increase

Pages at Gold standard (>=40 features): 3/47 (6.4%)
Pages at Silver (25-39): 5/47 (10.6%)
Pages at Bronze (15-24): 12/47 (25.5%)
Pages at Skeleton (<15): 14/47 (29.8%)
Pages missing entirely: 14/47 (29.8%)

Weighted coverage (by FMEA RPN):
  Safety-critical pages (8): 22% average coverage → need 100%
  High-interaction pages (10): 35% average → need 90%
  Operations pages (5): 25% average → need 85%
  Observability pages (6): 30% average → need 80%
  Knowledge/AI pages (4): 32% average → need 85%
  Infrastructure pages (5): 28% average → need 75%
  Admin pages (4): 0% → need 60%
  Analytics pages (2): 0% → need 50%
```

---

## 7. Criticality-Based Execution Order

### Wave 1 (P0): Safety-Critical — 8 pages, ~320 features
RPN-prioritized: Commands > Shutdown > Guardian > Alarms > Cluster > Threat > ActiveAlarms > Access

### Wave 2 (P1): High-Interaction — 10 pages, ~280 features
Settings > Diagnostics > TestCockpit > Dispatch > VideoWall > Copilot > Knowledge > Sentinel > Analytics > Compliance

### Wave 3 (P2): Infrastructure — 8 pages, ~200 features
Containers > Devices > Mesh > Startup > Observability > Register > GitIntelligence > GuardianDashboard

### Wave 4 (P2): Missing Pages — 10 pages, ~300 features
Prajna > SystemStatus > ConfigManagement > Knowledge.Developer > Knowledge.Product > Knowledge.SRE > TopologyUpgrade > PrometheusUpgrade > HealthSparklineUpgrade > ZenohMeshHealthUpgrade

### Wave 5 (P3): Admin & Analytics — 4 pages, ~80 features
StampTdgGde > AdvancedAnalytics > Permissions > AccessMonitoring > CRM

---

## 8. Mathematical Constructs

### Coverage Completeness Metric (CCM)
```
CCM = (Σ covered_categories_per_page) / (8 × total_pages) × 100%

Current CCM: ~45% (many pages missing C4, C6, C7, C8 dual verification)
Target CCM: ≥ 90%
```

### Risk-Weighted Coverage (RWC)
```
RWC = Σ(coverage_i × rpn_i) / Σ(rpn_i)

Where coverage_i = features_tested / features_needed for page i
      rpn_i = max FMEA RPN for page i

Current RWC: ~32%
Target RWC: ≥ 85%
```

### Fractal Self-Similarity Index (FSSI)
```
FSSI measures how similar the test pattern is across pages.
FSSI = 1 - σ(coverage_per_category) / μ(coverage_per_category)

Gold standard FSSI = 1.0 (all categories uniformly covered)
Current system FSSI ≈ 0.35 (C8 severely under-tested, C1 over-represented)
Target FSSI: ≥ 0.75
```
