# C3I Dashboard — 7-Level Fractal BDD Flow Analysis

**Scope**: All 15 Page components (Dashboard, Planning, Immune, Knowledge, Zenoh, Cockpit, Verification, Substrate, Metabolic, Podman, Mcp, Kms, Telemetry, Federation, HealthGrid)
**Fractal Levels**: L0 (Constitutional) through L7 (Federation)
**Generated**: 2026-04-04

---

## 1. DASHBOARD (L5_COGNITIVE)

**Source**: `lustre/app.gleam` (97L), `wisp/router.gleam` (1033L), `tui/` (via cockpit_view)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `init()` called | `selected_page = Dashboard`, `dark_cockpit = True`, `health = Unknown`, `zenoh_connected = False` | O(1), no allocation | Unit: `batch2_ui_lustre_test.gleam:app_init_defaults_test` |
| L0-2 | Any model state | `Tick` msg dispatched | Model unchanged (idempotent) | O(1), zero-copy | Unit: `batch2_ui_lustre_test.gleam:app_update_tick_noop_test` |
| L0-3 | System in any state | `health_class(Healthy)` | Returns `"health-ok"` CSS class | O(1), pattern match | Unit: `batch2_ui_lustre_test.gleam:health_class_healthy_test` |
| L0-4 | System in any state | `health_class(Critical(_))` | Returns `"health-critical"` CSS class | O(1) | Unit: `batch2_ui_lustre_test.gleam:health_class_critical_test` |

**Invariant**: `Tick` is always a no-op — no state mutation on heartbeat alone.
**KPI**: `init()` must complete in < 1ms.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with `selected_page = Dashboard` | `NavigateTo(Planning)` | `selected_page = Planning`, context preserved | O(1), record update | Unit: `batch2_ui_lustre_test.gleam:app_update_navigate_to_test` |
| L1-2 | Model with empty telemetry | `TelemetryReceived("cpu", 0.75, 1000, "%")` | Telemetry list length = 1, newest first | O(1), cons | Unit: `batch2_ui_lustre_test.gleam:app_update_telemetry_received_test` |
| L1-3 | Model with health = Unknown | `HealthUpdated(Degraded("high load"))` | `context.health = Degraded("high load")` | O(1) | Unit: `batch2_ui_lustre_test.gleam:app_update_health_degraded_test` |
| L1-4 | Model with `zenoh_connected = False` | `ZenohConnectionChanged(True)` | `context.zenoh_connected = True` | O(1) | Unit: `batch2_ui_lustre_test.gleam:app_update_zenoh_connection_changed_test` |
| L1-5 | Model with `dark_cockpit = True` | `ToggleDarkCockpit` | `dark_cockpit = False` | O(1), bool flip | Unit: `batch2_ui_lustre_test.gleam:app_update_toggle_dark_cockpit_test` |

**Gap**: No test for `TelemetryReceived` prepending order (exists: `app_update_telemetry_prepends_test`).

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Model with 2 telemetry points | `TelemetryReceived` 3rd point | Telemetry list = 3, newest at head | O(1) cons, O(n) render | Unit: `batch2_ui_lustre_test.gleam:app_update_telemetry_prepends_test` |
| L2-2 | Model with `dark_cockpit = True` | `ToggleDarkCockpit` then `ToggleDarkCockpit` | `dark_cockpit = True` (double-toggle identity) | O(1) | Unit: `batch2_ui_lustre_test.gleam:app_update_toggle_dark_cockpit_test` |

**Gap**: No test verifying `context` fields are preserved across `NavigateTo`.

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Fresh model | NavigateTo(Planning) → TelemetryReceived → HealthUpdated(Healthy) | `selected_page = Planning`, telemetry = 1 point, health = Healthy | O(1) per step | E2E: Wallaby |
| L3-2 | Fresh model | ZenohConnectionChanged(True) → ZenohConnectionChanged(False) | `zenoh_connected = False` | O(1) per step | Unit: `batch2_ui_lustre_test.gleam:app_update_zenoh_disconnect_test` |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/v1/dashboard` | Valid JSON with `"page": "Dashboard"`, `"status": "active"` | O(1), static JSON | Unit: `webui_full_coverage_test.gleam:route_api_v1_dashboard_test` |
| L4-2 | Wisp router running | GET `/api/v1/pages` | All 13 pages listed with paths and labels | O(n) page enumeration | Unit: `webui_full_coverage_test.gleam:route_pages_contains_all_13_pages_test` |
| L4-3 | Wisp router running | GET `/health` | `{"status": "ok", "interface": "wisp", "port": 4100}` | O(1) | Unit: `webui_full_coverage_test.gleam:route_health_contains_status_ok_test` |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Dashboard displaying Unknown health | Zenoh connects, health updates to Healthy | TUI shows green "HEALTHY", Lustre shows "health-ok" class | O(1) state transition | E2E: Wallaby |
| L5-2 | Dashboard in Dark Cockpit mode | Health becomes Critical | TUI renders anomaly prominently, normal nodes hidden | O(n) filter | Integration: TUI render test |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Zenoh mesh connected | Telemetry point published to `indrajaal/agui/telemetry` | Dashboard receives `TelemetryReceived` via SSE | Network latency + O(1) | E2E: Zenoh + SSE |
| L6-2 | Multiple mesh nodes | Health status changes propagate | Dashboard reflects aggregate health | O(n) aggregation | Integration: mesh probe |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Federation peer joins | Dashboard receives updated peer list | Peer count increments, TUI shows new peer | O(n) peer render | E2E: federation_triple_test |

**Coverage Gaps**: No explicit Dashboard TUI test file. Dashboard uses shared cockpit_view TUI.

---

## 2. PLANNING (L3_TRANSACTION)

**Source**: `lustre/planning.gleam` (66L), `wisp/planning_api.gleam` (53L), `wisp/router.gleam`, `tui/planning_view.gleam` (53L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `planning.init()` | `tasks = []`, `filter = AllTasks`, `selected_id = None` | O(1) | Unit: `batch2_ui_lustre_test.gleam:planning_init_defaults_test` |
| L0-2 | Any model state | `RefreshTasks` msg | Model unchanged (stub — no backend wiring) | O(1) | Unit: `batch2_ui_lustre_test.gleam:planning_update_refresh_noop_test` |

**Invariant**: `RefreshTasks` is a no-op until backend wiring (NYI).

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with AllTasks filter | `SetFilter(PendingOnly)` | `filter = PendingOnly` | O(1) | Unit: `batch2_ui_lustre_test.gleam:planning_update_set_filter_test` |
| L1-2 | Model with empty selection | `SelectTask("t-1")` | `selected_id = Some("t-1")` | O(1) | Unit: `batch2_ui_lustre_test.gleam:planning_update_select_task_test` |
| L1-3 | Model with empty tasks | `TasksLoaded([task])` | `tasks = [task]` | O(1) | Unit: `batch2_ui_lustre_test.gleam:planning_update_tasks_loaded_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Model with 3 tasks (2 pending, 1 completed) | Filter = PendingOnly | `filtered_tasks` returns 2 tasks | O(n) filter | Unit: `batch2_ui_lustre_test.gleam:planning_filtered_tasks_pending_only_test` |
| L2-2 | Model with tasks in all 5 statuses | Each filter variant applied | Correct subset returned for AllTasks, PendingOnly, InProgressOnly, CompletedOnly, BlockedOnly | O(n) per filter | Unit: batch2 × 5 filter tests |
| L2-3 | Model with tasks | `task_count_by_status(tasks, "pending")` | Returns correct count | O(n) scan | Unit: `batch2_ui_lustre_test.gleam:planning_task_count_by_status_test` |

**Gap**: No test for `BlockedOnly` filter with zero results.

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with 3 tasks | SelectTask("2") → SetFilter(InProgressOnly) | `selected_id = Some("2")`, visible tasks filtered | O(1) + O(n) | E2E: Wallaby |
| L3-2 | Model with tasks | TasksLoaded(new_tasks) → SetFilter(CompletedOnly) | Tasks replaced, filter applied to new set | O(n) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/v1/planning` | JSON with 6 tasks, summary (total=25, completed=25, pending=0) | O(1), static | Unit: `webui_full_coverage_test.gleam:route_planning_contains_tasks_test` |
| L4-2 | Wisp router running | GET `/api/planning/tasks` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_planning_tasks_test` |
| L4-3 | Planning API | `list_tasks_json([tasks])` | Valid JSON with plane="planning", count, tasks array | O(n) encode | Unit: planning_api.gleam functions |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Planning with blocked tasks | Agent detects dependency resolution | Tasks transition from blocked → pending (via TasksLoaded) | O(n) reload | Integration: Chaya sync |
| L5-2 | Planning with tasks | OODA loop completes cycle | Task statuses reflect current execution state | O(n) | E2E |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Chaya planning system | `/api/chaya/sync` called | Planning tasks synchronized (25 tasks, 0 orphans, 0 mismatches) | O(n) sync | Unit: `webui_full_coverage_test.gleam` (chaya route) |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Multiple planning instances | Tasks updated on peer A | Peer B receives updated task list via Zenoh | Network + O(n) | E2E: federation |

**Coverage Gaps**: No TUI-specific test for `planning_view.gleam`. No test for `planning_api.gleam` functions directly.

---

## 3. IMMUNE (L0_CONSTITUTIONAL)

**Source**: `lustre/immune.gleam` (56L), `wisp/immune_api.gleam` (75L), `tui/immune_view.gleam` (74L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `immune.init()` | `antibodies = []`, `recent_events = []`, `active_attacks = []`, `mara_running = False` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_init_defaults_test` |
| L0-2 | Any model state | `RefreshImmune` msg | Model unchanged (stub) | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_refresh_noop_test` |
| L0-3 | Any model state | `AttackResolved(_)` | Model unchanged (stub — no removal logic) | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_attack_resolved_noop_test` |

**Invariant**: `AttackResolved` is a no-op — attacks are never removed from `active_attacks`. This is a **design gap** — resolved attacks accumulate forever.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty antibodies | `AntibodyAdded(ab)` | `antibodies = [ab]` (prepended) | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_antibody_added_test` |
| L1-2 | Model with empty events | `EventReceived(evt)` | `recent_events = [evt]` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_event_received_test` |
| L1-3 | Model with empty attacks | `AttackDetected(atk)` | `active_attacks = [atk]` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_attack_detected_test` |
| L1-4 | Model with `mara_running = False` | `ToggleMara` | `mara_running = True` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_toggle_mara_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 0 active attacks | `threat_level()` | Returns `"nominal"` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_threat_level_nominal_test` |
| L2-2 | 1 active attack | `threat_level()` | Returns `"elevated"` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_threat_level_elevated_one_attack_test` |
| L2-3 | 2 active attacks | `threat_level()` | Returns `"elevated"` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_threat_level_elevated_two_attacks_test` |
| L2-4 | 3+ active attacks | `threat_level()` | Returns `"critical"` | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_threat_level_critical_three_attacks_test` |
| L2-5 | Model with antibodies + events | TUI `render()` | Color-coded output: threat level, antibody list, events | O(n) render | Integration: TUI |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Fresh model | AttackDetected → AttackDetected → AttackDetected | 3 attacks, threat = "critical" | O(1) × 3 | Unit: `batch2_ui_lustre_test.gleam:immune_threat_level_critical_three_attacks_test` |
| L3-2 | Mara inactive | ToggleMara → ToggleMara | Mara back to inactive (double-toggle identity) | O(1) | Unit: `batch2_ui_lustre_test.gleam:immune_update_toggle_mara_test` |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/v1/immune` | JSON with plane="immune", threat_level="nominal", antibodies_deployed=0 | O(1) | Unit: `webui_full_coverage_test.gleam:route_immune_contains_threat_level_test` |
| L4-2 | Immune API | `immune_status_json([], [], False)` | Valid JSON with threat_level="nominal" | O(1) | Unit: immune_api.gleam |
| L4-3 | Immune API | `events_json([events])` | JSON with event types: antibody_synthesized, attack_blocked, safety_violation, rollback_initiated | O(n) encode | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | 3+ active attacks | System evaluates threat | TUI renders "CRITICAL" in red, Mara activation suggested | O(n) render | E2E: Wallaby |
| L5-2 | Safety violation detected | Immune system synthesizes antibody | `AntibodySynthesized` event logged, antibody added | O(1) | Integration |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Chaos attack on container | Immune detects via Zenoh telemetry | `AttackDetected` msg, threat level recalculated | Network + O(1) | E2E: chaos + immune |
| L6-2 | Mara running | Continuous chaos attacks | Antibodies auto-synthesized, attacks blocked | O(n) per cycle | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Attack detected on peer A | Immune state shared via federation | Peer B deploys matching antibody | Network + O(1) | E2E: federation |

**Coverage Gaps**: `AttackResolved` is a no-op — needs implementation or explicit documentation. No TUI-specific test for `immune_view.gleam`. No `immune_api.gleam` direct unit tests.

---

## 4. KNOWLEDGE (L5_COGNITIVE)

**Source**: `lustre/knowledge.gleam` (61L), `wisp/knowledge_api.gleam` (49L), `tui/knowledge_view.gleam` (55L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `knowledge.init()` | `nodes = []`, `links = []`, `selected_node = None`, `filter_level = None`, `search_query = ""` | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_init_defaults_test` |
| L0-2 | Any model state | `RefreshKnowledge` msg | Model unchanged (stub) | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_update_refresh_noop_test` |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty selection | `SelectNode("kn-1")` | `selected_node = Some("kn-1")` | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_update_select_node_test` |
| L1-2 | Model with no filter | `SetLevelFilter(Some(Atomic))` | `filter_level = Some(Atomic)` | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_update_set_level_filter_test` |
| L1-3 | Model with filter set | `SetLevelFilter(None)` | `filter_level = None` (clear filter) | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_update_set_level_filter_none_test` |
| L1-4 | Model with empty query | `SetSearch("zenoh")` | `search_query = "zenoh"` | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_update_set_search_test` |
| L1-5 | Model with empty data | `NodesLoaded([node], [link])` | `nodes = [node]`, `links = [link]` | O(1) | Unit: `batch2_ui_lustre_test.gleam:knowledge_update_nodes_loaded_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 3 nodes (2 Atomic, 1 Ecosystem), filter=None | `filtered_nodes()` | Returns all 3 nodes | O(n) | Unit: `batch2_ui_lustre_test.gleam:knowledge_filtered_nodes_no_filter_test` |
| L2-2 | 3 nodes (2 Atomic, 1 Ecosystem), filter=Some(Atomic) | `filtered_nodes()` | Returns 2 Atomic nodes | O(n) | Unit: `batch2_ui_lustre_test.gleam:knowledge_filtered_nodes_with_filter_test` |
| L2-3 | 1 Atomic node, filter=Some(Organism) | `filtered_nodes()` | Returns `[]` | O(n) | Unit: `batch2_ui_lustre_test.gleam:knowledge_filtered_nodes_empty_result_test` |
| L2-4 | 4 nodes across levels | `node_count_by_level(nodes, Atomic)` | Returns 2 | O(n) | Unit: `batch2_ui_lustre_test.gleam:knowledge_node_count_by_level_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with nodes | SelectNode("a") → SetLevelFilter(Some(Atomic)) | Selected node preserved, filter applied | O(1) + O(n) | E2E |
| L3-2 | Model with nodes | SetSearch("zenoh") → NodesLoaded(new_nodes, new_links) | Search query preserved, data replaced | O(n) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/v1/knowledge` | JSON with nodes=42, links=87, levels breakdown | O(1), static | Unit: `webui_full_coverage_test.gleam:route_knowledge_contains_nodes_and_links_test` |
| L4-2 | Knowledge API | `knowledge_graph_json(nodes, links)` | Valid JSON with node_count, link_count, nodes array, links array | O(n) encode | Integration |
| L4-3 | Knowledge API | `node_detail_json(node)` | JSON with id, title, level, rhetorical, entropy, drift, tags | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Knowledge graph with entropy data | TUI renders nodes | Each node shows entropy bar (0-10 chars), H= value | O(n) render | Integration: TUI |
| L5-2 | Nodes with drift > 0 | System evaluates knowledge freshness | High-drift nodes flagged for review | O(n) drift calc | Integration |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Knowledge graph updated | Zenoh pubsub broadcasts | All connected clients receive NodesLoaded | Network + O(n) | E2E |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A adds knowledge node | Federation sync | Peer B receives node via version vector | Network + O(1) | E2E: federation |

**Coverage Gaps**: `search_query` field is set but never used in `filtered_nodes()` — **functional gap**. No TUI-specific test for `knowledge_view.gleam`. No `knowledge_api.gleam` direct unit tests.

---

## 5. ZENOH (L6_ECOSYSTEM)

**Source**: `lustre/zenoh_mesh.gleam` (68L), `wisp/zenoh_api.gleam` (40L), `tui/zenoh_view.gleam` (50L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `zenoh_mesh.init()` | `health = empty_health()`, `lifecycle = Uninitialized`, `subscriptions = []`, `message_log = []` | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_init_defaults_test` |
| L0-2 | Any model state | `RefreshZenoh` msg | Model unchanged (stub) | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_update_refresh_noop_test` |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty health | `HealthUpdated(ZenohHealth{status=Connected, ...})` | `health.status = Connected`, session_id set | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_update_health_updated_test` |
| L1-2 | Model with Uninitialized lifecycle | `LifecycleChanged(Running(42))` | `lifecycle = Running(connected_at=42)` | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_update_lifecycle_changed_test` |
| L1-3 | Model with empty message_log | `MessageReceived("sensor/temp", 128, 1000)` | `message_log` length = 1 | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_update_message_received_test` |
| L1-4 | Model with empty subscriptions | `SubscriptionAdded("sensor/**")` | `subscriptions = ["sensor/**"]` | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_update_subscription_added_test` |
| L1-5 | Model with 1 subscription | `SubscriptionRemoved("sensor/**")` | `subscriptions = []` | O(n) filter | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_update_subscription_removed_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Model with empty health | `is_connected()` | Returns `False` | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_is_connected_false_by_default_test` |
| L2-2 | Model with Connected health | `is_connected()` | Returns `True` | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_is_connected_true_when_connected_test` |
| L2-3 | Model with Connecting health | `is_connected()` | Returns `False` (only Connected = true) | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_is_connected_false_when_connecting_test` |
| L2-4 | Model with empty health | `message_rate()` | Returns 0 | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_message_rate_zero_by_default_test` |
| L2-5 | Model with pub=42, recv=58 | `message_rate()` | Returns 100 | O(1) | Unit: `batch2_ui_lustre_test.gleam:zenoh_mesh_message_rate_sums_pub_and_recv_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Fresh model | SubscriptionAdded("a") → SubscriptionAdded("b") → SubscriptionRemoved("a") | subscriptions = ["b"] | O(1) + O(1) + O(n) | Unit: combination test |
| L3-2 | Fresh model | HealthUpdated(Connected) → LifecycleChanged(Running) → MessageReceived | Connected, Running, 1 message logged | O(1) × 3 | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/v1/zenoh` | JSON with routers=3, connected=True, topics_active=12, router_endpoints | O(1), static | Unit: `webui_full_coverage_test.gleam:route_zenoh_contains_routers_test` |
| L4-2 | Zenoh API | `zenoh_health_json(health)` | JSON with status, session_id, connected_at, pub/recv counts, errors | O(1) | Integration |
| L4-3 | Zenoh API | `subscriptions_json(topics)` | JSON with subscription_count, topics array | O(n) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Zenoh disconnected | Reconnection attempt | Lifecycle transitions: Uninitialized → Connecting → Running | O(1) per transition | E2E |
| L5-2 | High error count | System evaluates mesh health | TUI shows "ERROR: msg" in red | O(1) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Zenoh router cluster (3 routers) | Router 1 fails | Health shows reconnect_count increment, status = Connecting | Network + O(1) | E2E: chaos |
| L6-2 | Multiple topics subscribed | Messages published to each | Message log grows, message_rate increases | O(1) per message | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Federation peers connected | Zenoh session established across peers | Each peer shows Connected status, message exchange | Network + O(1) | E2E: federation |

**Coverage Gaps**: No test for `LifecycleChanged` with non-Running states (e.g., Stopped). No TUI-specific test for `zenoh_view.gleam`. No `zenoh_api.gleam` direct unit tests.

---

## 6. COCKPIT (L5_COGNITIVE)

**Source**: `lustre/cockpit_view.gleam` (89L), `wisp/cockpit_api.gleam` (69L), `tui/cockpit_view.gleam` (116L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `cockpit_view.init()` | `nodes = []`, `alarms = []`, `view_mode = Overview`, `dark_cockpit = True`, `selected_node = None` | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_init_defaults_test` |
| L0-2 | Any model state | `RefreshCockpit` msg | Model unchanged (stub) | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_update_refresh_noop_test` |
| L0-3 | Any model state | `AcknowledgeAlarm(_)` | Model unchanged (stub) | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_update_acknowledge_alarm_noop_test` |

**Invariant**: `AcknowledgeAlarm` is a no-op — alarms are never acknowledged. **Design gap**.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with Overview mode | `SetViewMode(Alarms)` | `view_mode = Alarms` | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_update_set_view_mode_test` |
| L1-2 | Model with no selection | `SelectNode("node-1")` | `selected_node = Some("node-1")` | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_update_select_node_test` |
| L1-3 | Model with `dark_cockpit = True` | `ToggleDarkCockpit` | `dark_cockpit = False` | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_update_toggle_dark_cockpit_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 3 nodes (1 Connected, 1 Degraded, 1 Disconnected), dark_cockpit=True | `visible_nodes()` | Returns 2 nodes (Degraded + Disconnected) | O(n) filter | Unit: `batch2_ui_lustre_test.gleam:cockpit_visible_nodes_dark_cockpit_filters_connected_test` |
| L2-2 | 2 nodes, dark_cockpit=False | `visible_nodes()` | Returns all 2 nodes | O(n) | Unit: `batch2_ui_lustre_test.gleam:cockpit_visible_nodes_normal_mode_shows_all_test` |
| L2-3 | Empty model | `visible_nodes()` | Returns `[]` | O(1) | Unit: `batch2_ui_lustre_test.gleam:cockpit_visible_nodes_empty_test` |
| L2-4 | 3 alarms (Advisory, Critical, Warning) | `active_alarms()` | Returns 3, sorted Critical first | O(n log n) sort | Unit: `batch2_ui_lustre_test.gleam:cockpit_active_alarms_sorted_critical_first_test` |
| L2-5 | 2 Normal alarms | `active_alarms()` | Returns `[]` (Normal filtered out) | O(n) filter | Unit: `batch2_ui_lustre_test.gleam:cockpit_active_alarms_empty_when_all_normal_test` |
| L2-6 | Alarm severity ranking | `alarm_severity_rank(Critical)` = 5, `Warning` = 4, `Caution` = 3, `Advisory` = 2, `Normal` = 1 | Correct numeric ranking | O(1) | Implicit in sort tests |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with nodes | NodesUpdated(new_nodes) → SelectNode("n1") | Nodes replaced, selection preserved | O(n) + O(1) | E2E |
| L3-2 | Model with alarms | AlarmsUpdated(new_alarms) → ToggleDarkCockpit | Alarms replaced, dark mode toggled | O(n) + O(1) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/cockpit/nodes` | JSON with 6 nodes (zenoh routers, db, obs, cortex), dark_cockpit=True, empty alarms | O(1), static | Unit: `webui_full_coverage_test.gleam:route_cockpit_contains_nodes_test` |
| L4-2 | Cockpit API | `nodes_json(nodes)` | JSON with node_count, nodes array (id, name, zone, status, cpu, memory, health_score) | O(n) encode | Integration |
| L4-3 | Cockpit API | `alarms_json(alarms)` | JSON with alarm_count, alarms array (id, node_id, level, category, message, occurred_at) | O(n) encode | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Dark Cockpit mode, all nodes Connected | `visible_nodes()` | Empty list — nothing to show (dark cockpit principle) | O(n) filter | Unit: dark cockpit filter |
| L5-2 | Critical alarm present | TUI renders | Red "[CRIT]" badge, node_id, message | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Mesh node goes Degraded | Zenoh telemetry update | Cockpit receives NodesUpdated, Degraded node appears in dark cockpit | Network + O(n) | E2E |
| L6-2 | New critical alarm | Alarm system broadcasts | AlarmsUpdated received, alarm sorted to top | Network + O(n log n) | E2E |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A detects node failure | Federation shares alarm state | Peer B cockpit displays same alarm | Network + O(n) | E2E: federation |

**Coverage Gaps**: `AcknowledgeAlarm` is a no-op — needs implementation. No test for `NodesUpdated` or `AlarmsUpdated` msg handlers. No TUI-specific test for `cockpit_view.gleam`. No `cockpit_api.gleam` direct unit tests.

---

## 7. VERIFICATION (L0_CONSTITUTIONAL)

**Source**: `lustre/verification.gleam` (127L), `wisp/verification_api.gleam` (120L), `tui/verification_view.gleam` (169L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `verification.init()` | `last_report = None`, `running = False`, `history = []`, `latest_proof = None`, `graph_checks = []`, `dag_node_count = 0`, `dag_edge_count = 0`, `proof_history = []` | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_init_defaults_test` |

**Invariant**: Verification starts in clean state — no prior reports, no proofs, no history.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with `running = False` | `StartVerification` | `running = True` | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_update_start_test` |
| L1-2 | Model with `running = True` | `ReportReceived(report)` | `running = False`, `last_report = Some(report)`, `history` gains 1 entry | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_update_report_received_test` |
| L1-3 | Model with no proof | `ProofGenerated(proof)` | `latest_proof = Some(proof)`, `proof_history` gains 1 entry | O(1) | Unit: verification.gleam |
| L1-4 | Model with no checks | `GraphChecksCompleted(checks)` | `graph_checks = checks` | O(1) | Unit: verification.gleam |
| L1-5 | Model with DAG stats = 0 | `DagUpdated(42, 87)` | `dag_node_count = 42`, `dag_edge_count = 87` | O(1) | Unit: verification.gleam |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Report: 15/15 healthy | `compliance_percent(report)` | Returns 100.0 | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_compliance_percent_all_healthy_test` |
| L2-2 | Report: 12/15 healthy | `compliance_percent(report)` | Returns 80.0 | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_compliance_percent_partial_test` |
| L2-3 | Report: 0/0 (empty) | `compliance_percent(report)` | Returns 0.0 (division by zero guard) | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_compliance_percent_zero_total_test` |
| L2-4 | Report: 0/10 healthy | `compliance_percent(report)` | Returns 0.0 | O(1) | Unit: `batch2_ui_lustre_test.gleam:verification_compliance_percent_none_healthy_test` |
| L2-5 | Model with all checks passed | `all_checks_passed(model)` | Returns `True` | O(n) | Unit: verification.gleam |
| L2-6 | Model with Verified proof | `latest_proof_verified(model)` | Returns `True` | O(1) | Unit: verification.gleam |
| L2-7 | Model with Rejected proof | `latest_proof_verified(model)` | Returns `False` | O(1) | Unit: verification.gleam |
| L2-8 | Model with Inconclusive proof | `latest_proof_verified(model)` | Returns `False` | O(1) | Unit: verification.gleam |
| L2-9 | Model with no proof | `latest_proof_verified(model)` | Returns `False` | O(1) | Unit: verification.gleam |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model idle | StartVerification → ReportReceived → ProofGenerated | running=True → False, report stored, proof stored | O(1) × 3 | Unit: `batch2_ui_lustre_test.gleam:verification_update_report_received_test` |
| L3-2 | Model with checks | GraphChecksCompleted → DagUpdated | Checks stored, DAG stats updated | O(1) × 2 | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/v1/verification` | JSON with sil_level="SIL-6", tests_total=266, compliance=100.0, fractal_layers_verified=8 | O(1), static | Unit: `webui_full_coverage_test.gleam:route_verification_contains_sil6_test` |
| L4-2 | Verification API | `swarm_report_json(report)` | JSON with healthy_containers, total_containers, ooda metrics, fractal_layers | O(n) encode | Integration |
| L4-3 | Verification API | `proof_token_json(proof)` | JSON with dag_hash, path, verified_at, constraints_checked, result | O(n) encode | Integration |
| L4-4 | Verification API | `graph_checks_json(checks)` | JSON with checks array, all_passed, passed_count, total_count | O(n) encode | Integration |
| L4-5 | Verification API | `dag_status_json(nodes, edges, acyclic)` | JSON with node_count, edge_count, is_acyclic | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Verification run completes | TUI renders | Progress bar, container health %, OODA compliance status, layer-by-layer status | O(n) render | Integration: TUI |
| L5-2 | Proof token generated | TUI renders | DAG hash, path, result color (green=Verified, red=Rejected, yellow=Inconclusive) | O(1) render | Integration: TUI |
| L5-3 | Graph checks completed | TUI renders | [PASS]/[FAIL] badges, summary "X/Y checks passed" | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Swarm verification triggered | All 8 fractal layers checked | SwarmReport generated, compliance calculated | O(n) per layer | E2E |
| L6-2 | OODA metrics collected | Verification evaluates | Agent latency, intelligence latency, compliance boolean | O(1) | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A runs verification | Proof token shared via federation | Peer B receives and validates proof | Network + O(1) | E2E: federation |

**Coverage Gaps**: No tests for `ProofGenerated`, `GraphChecksCompleted`, `DagUpdated`, `all_checks_passed`, `latest_proof_verified`, `proof_result_string` msg handlers. No TUI-specific test for `verification_view.gleam`. No `verification_api.gleam` direct unit tests.

---

## 8. SUBSTRATE (L3_TRANSACTION)

**Source**: `lustre/substrate.gleam` (52L), `wisp/substrate_api.gleam` (60L), `tui/substrate_view.gleam` (81L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `substrate.init()` | `governor_action = None`, `db_connections = []`, `file_ops = []` | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_init_defaults_test` |
| L0-2 | Any model state | `RefreshSubstrate` msg | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_update_refresh_noop_test` |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with no governor action | `GovernorUpdated(action)` | `governor_action = Some(action)` | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_update_governor_updated_test` |
| L1-2 | Model with empty connections | `DbStatsReceived([conn])` | `db_connections = [conn]` | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_update_db_stats_received_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 3 connections (2 active, 1 idle) | `active_connections()` | Returns 2 active connections | O(n) filter | Unit: `webui_full_coverage_test.gleam:substrate_active_connections_test` |
| L2-2 | Model with no connections | `active_connections()` | Returns `[]` | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_active_connections_empty_test` |
| L2-3 | Model with 2 connections | `connection_count()` | Returns 2 | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_connection_count_test` |
| L2-4 | Model with no connections | `connection_count()` | Returns 0 | O(1) | Unit: `webui_full_coverage_test.gleam:substrate_connection_count_zero_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with governor action | GovernorUpdated(new_action) → DbStatsReceived(conns) | Governor updated, connections loaded | O(1) × 2 | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/substrate/status` | JSON with governor_action="Maintain", db_type="SQLite", file_system_status="nominal", wal_mode=True | O(1), static | Unit: `webui_full_coverage_test.gleam:route_substrate_contains_governor_test` |
| L4-2 | Wisp router running | GET `/api/v1/substrate` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_v1_substrate_test` |
| L4-3 | Substrate API | `status_json(metrics, action, db_type, fs_status)` | JSON with governor_action, resource_metrics, db_type, file_system_status | O(1) | Integration |
| L4-4 | Substrate API | `health_json(action, fs_healthy)` | Compact JSON: governor_action, file_system_healthy, status (critical/stressed/nominal) | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Governor action = EmergencyHalt | TUI renders | Red "EmergencyHalt: reason" displayed | O(1) render | Integration: TUI |
| L5-2 | DB connections with varying latency | TUI renders | Color-coded: green=active, yellow=idle, red=other, latency in ms | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | CPU governor detects overload | Governor action = Contract | Substrate status shows "stressed" | O(1) | Integration |
| L6-2 | DB connection fails | Connection status changes to "error" | TUI shows red badge | O(n) filter | E2E |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Governor action on peer A | Federation shares substrate state | Peer B sees same governor action | Network + O(1) | E2E: federation |

**Coverage Gaps**: No test for `file_ops` field (never populated via Msg). No TUI-specific test for `substrate_view.gleam`. No `substrate_api.gleam` direct unit tests.

---

## 9. METABOLIC (L1_ATOMIC_DEBUG)

**Source**: `lustre/metabolic.gleam` (44L), `wisp/metabolic_api.gleam` (53L), `tui/metabolic_view.gleam` (52L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `metabolic.init()` | `set_point = 0.5`, `energy = 1.0`, `cpu_load = 0.0`, `health = Healthy` | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_init_defaults_test` |
| L0-2 | Any model state | `RefreshMetabolic` msg | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_update_refresh_noop_test` |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with set_point=0.5 | `SetPointUpdated(0.8)` | `set_point = 0.8` | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_update_set_point_test` |
| L1-2 | Model with energy=1.0 | `EnergyChanged(0.75)` | `energy = 0.75` | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_update_energy_changed_test` |
| L1-3 | Model with health=Healthy | `HealthChanged(Degraded("high cpu"))` | `health = Degraded("high cpu")` | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_update_health_changed_test` |
| L1-4 | Model with health=Healthy | `HealthChanged(Critical("memory overflow"))` | `health = Critical("memory overflow")` | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_update_health_to_critical_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | energy=1.0, set_point=0.5 | `energy_ratio()` | Returns 2.0 (1.0 / 0.5) | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_energy_ratio_normal_test` |
| L2-2 | energy=1.0, set_point=1.0 | `energy_ratio()` | Returns 1.0 | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_energy_ratio_equal_test` |
| L2-3 | set_point=0.0 | `energy_ratio()` | Returns 0.0 (division by zero guard) | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_energy_ratio_zero_set_point_test` |
| L2-4 | cpu_load=0.0 | `is_overloaded()` | Returns `False` | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_is_overloaded_false_test` |
| L2-5 | cpu_load=0.95 | `is_overloaded()` | Returns `True` (0.95 > 0.9) | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_is_overloaded_true_test` |
| L2-6 | cpu_load=0.9 | `is_overloaded()` | Returns `False` (0.9 NOT > 0.9, strict inequality) | O(1) | Unit: `webui_full_coverage_test.gleam:metabolic_is_overloaded_at_threshold_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Fresh model | SetPointUpdated(0.8) → EnergyChanged(0.6) → HealthChanged(Degraded) | set_point=0.8, energy=0.6, health=Degraded | O(1) × 3 | Integration |
| L3-2 | Model with energy=1.0, set_point=0.5 | EnergyChanged(0.3) → energy_ratio() | Returns 0.6 (0.3 / 0.5) | O(1) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/metabolic/status` | JSON with set_point=80.0, energy=100.0, cpu_load=32.5, health_status="Healthy" | O(1), static | Unit: `webui_full_coverage_test.gleam:route_metabolic_contains_set_point_test` |
| L4-2 | Wisp router running | GET `/api/v1/metabolic` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_v1_metabolic_test` |
| L4-3 | Metabolic API | `status_json(state)` | JSON with set_point, energy, cpu_load, memory, latency, tps, error_rate, health_status | O(1) | Integration |
| L4-4 | Metabolic API | `health_summary_json(set_point, cpu_load, health)` | Compact JSON: set_point, cpu_load, health_status | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | cpu_load > 0.9 | TUI renders | Red CPU bar, "CRITICAL" health status | O(1) render | Integration: TUI |
| L5-2 | Energy below set_point | TUI renders | Energy ratio bar shows < 1.0x, yellow warning | O(1) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | CPU governor adjusts set_point | Metabolic receives SetPointUpdated | Energy ratio recalculated, health re-evaluated | O(1) | Integration |
| L6-2 | Memory pressure increases | cpu_load crosses 0.9 threshold | `is_overloaded()` returns True, health changes to Critical | O(1) | E2E |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A metabolic state changes | Federation shares | Peer B receives updated metabolic metrics | Network + O(1) | E2E: federation |

**Coverage Gaps**: No TUI-specific test for `metabolic_view.gleam`. No `metabolic_api.gleam` direct unit tests.

---

## 10. PODMAN (L4_SYSTEM)

**Source**: `lustre/podman.gleam` (63L), `wisp/podman_api.gleam` (68L), `tui/podman_view.gleam` (97L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `podman.init()` | `containers = []`, `images = []`, `volumes = []`, `networks = []` | O(1) | Unit: `webui_full_coverage_test.gleam:podman_init_defaults_test` |
| L0-2 | Any model state | `RefreshPodman` msg | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:podman_update_refresh_noop_test` |
| L0-3 | Any model state | `StartContainer(_)` | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:podman_update_start_container_noop_test` |
| L0-4 | Any model state | `StopContainer(_)` | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:podman_update_stop_container_noop_test` |

**Invariant**: `StartContainer` and `StopContainer` are no-ops — container lifecycle not wired. **Design gap**.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty containers | `ContainersLoaded([container])` | `containers = [container]` | O(1) | Unit: `webui_full_coverage_test.gleam:podman_update_containers_loaded_test` |
| L1-2 | Model with empty images | `ImagesLoaded([image])` | `images = [image]` | O(1) | Unit: `webui_full_coverage_test.gleam:podman_update_images_loaded_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 3 containers (2 running, 1 exited) | `running_containers()` | Returns 2 running containers | O(n) filter | Unit: `webui_full_coverage_test.gleam:podman_running_containers_test` |
| L2-2 | Model with no containers | `running_containers()` | Returns `[]` | O(1) | Unit: `webui_full_coverage_test.gleam:podman_running_containers_empty_test` |
| L2-3 | Model with 2 containers | `container_count()` | Returns 2 | O(1) | Unit: `webui_full_coverage_test.gleam:podman_container_count_test` |
| L2-4 | Model with no containers | `container_count()` | Returns 0 | O(1) | Unit: `webui_full_coverage_test.gleam:podman_container_count_zero_test` |
| L2-5 | 3 containers (2 running, 1 exited) | `running_count()` | Returns 2 | O(n) | Unit: `webui_full_coverage_test.gleam:podman_running_count_test` |
| L2-6 | Model with no containers | `running_count()` | Returns 0 | O(1) | Unit: `webui_full_coverage_test.gleam:podman_running_count_zero_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with containers | ContainersLoaded(new_containers) → ImagesLoaded(new_images) | Both containers and images replaced | O(1) × 2 | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/podman/containers` | JSON with 5 containers (zenoh routers, db, obs), system_info, disk_usage_mb | O(1), static | Unit: `webui_full_coverage_test.gleam:route_podman_contains_containers_test` |
| L4-2 | Wisp router running | GET `/api/v1/podman` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_v1_podman_test` |
| L4-3 | Podman API | `containers_json(containers)` | JSON with container_count, containers array (id, name, image, status, ports) | O(n) encode | Integration |
| L4-4 | Podman API | `system_info_json(api_version, rootless, disk_usage_mb, container_count)` | JSON with api_version, rootless, disk_usage_mb, container_count | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Container exited | TUI renders | Red "[exited]" badge, name, image | O(n) render | Integration: TUI |
| L5-2 | Mixed container states | TUI renders | Green=running, red=exited, yellow=created, blue=other | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Container crashes | Podman API detects | ContainersLoaded with updated status, TUI shows red | O(n) reload | E2E |
| L6-2 | New image pulled | ImagesLoaded with new image | TUI shows image repository:tag (size_mb) | O(n) render | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A container state changes | Federation shares | Peer B receives updated container list | Network + O(n) | E2E: federation |

**Coverage Gaps**: `StartContainer` and `StopContainer` are no-ops. No test for `volumes` or `networks` fields. No TUI-specific test for `podman_view.gleam`. No `podman_api.gleam` direct unit tests.

---

## 11. MCP (L6_ECOSYSTEM)

**Source**: `lustre/mcp.gleam` (60L), `wisp/mcp_api.gleam` (39L), `tui/mcp_view.gleam` (69L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `mcp.init()` | `tools = []`, `active_sessions = []`, `server_status = Stopped` | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_init_defaults_test` |
| L0-2 | Any model state | `RefreshMcp` msg | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_update_refresh_noop_test` |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty tools | `ToolsLoaded([tool])` | `tools = [tool]` | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_update_tools_loaded_test` |
| L1-2 | Model with empty sessions | `SessionStarted(session)` | `active_sessions = [session]` (prepended) | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_update_session_started_test` |
| L1-3 | Model with session "s1" | `SessionEnded("s1")` | `active_sessions = []` | O(n) filter | Unit: `webui_full_coverage_test.gleam:mcp_update_session_ended_test` |
| L1-4 | Model with no sessions | `SessionEnded("nonexistent")` | `active_sessions = []` (no-op for missing) | O(n) filter | Unit: `webui_full_coverage_test.gleam:mcp_update_session_ended_nonexistent_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 3 tools (2 enabled, 1 disabled) | `enabled_tools()` | Returns 2 enabled tools | O(n) filter | Unit: `webui_full_coverage_test.gleam:mcp_enabled_tools_test` |
| L2-2 | All tools disabled | `enabled_tools()` | Returns `[]` | O(n) filter | Unit: `webui_full_coverage_test.gleam:mcp_enabled_tools_none_enabled_test` |
| L2-3 | Model with no tools | `enabled_tools()` | Returns `[]` | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_enabled_tools_empty_test` |
| L2-4 | Model with 2 sessions | `session_count()` | Returns 2 | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_session_count_test` |
| L2-5 | Model with no sessions | `session_count()` | Returns 0 | O(1) | Unit: `webui_full_coverage_test.gleam:mcp_session_count_zero_test` |
| L2-6 | SessionStarted(s1) → SessionStarted(s2) | `active_sessions` | [s2, s1] (newest first) | O(1) × 2 | Unit: `webui_full_coverage_test.gleam:mcp_update_session_started_prepends_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with tools | ToolsLoaded(tools) → SessionStarted(session) | Tools loaded, session active | O(1) × 2 | Integration |
| L3-2 | Model with 2 sessions | SessionEnded("s1") → SessionEnded("s2") | Both sessions removed | O(n) × 2 | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/mcp/status` | JSON with server_status="running", active_sessions=2, 5 tools, tool_count=5 | O(1), static | Unit: `webui_full_coverage_test.gleam:route_mcp_contains_tools_test` |
| L4-2 | Wisp router running | GET `/api/v1/mcp` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_v1_mcp_test` |
| L4-3 | MCP API | `status_json(server_status, tools, active_sessions)` | JSON with server_status, active_sessions, tool_count, tools array | O(n) encode | Integration |
| L4-4 | MCP API | `tools_json(tools)` | Compact JSON with tool_count, tools array | O(n) encode | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Server status = Errored("connection refused") | TUI renders | Red "ERROR: connection refused" | O(1) render | Integration: TUI |
| L5-2 | Mixed tool states | TUI renders | Green [ON] for enabled, red [OFF] for disabled | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | MCP server starts | Server status transitions: Stopped → Starting → Running | TUI reflects each state with appropriate color | O(1) per transition | E2E |
| L6-2 | Client connects | SessionStarted | Session count increments, TUI shows session details | O(1) | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A MCP tool invoked | Federation shares tool execution result | Peer B receives result | Network + O(1) | E2E: federation |

**Coverage Gaps**: No test for `ServerStatus` variants (Running, Starting, Errored) in update logic. No TUI-specific test for `mcp_view.gleam`. No `mcp_api.gleam` direct unit tests.

---

## 12. KMS (L0_CONSTITUTIONAL)

**Source**: `lustre/kms.gleam` (38L), `wisp/kms_api.gleam` (55L), `tui/kms_view.gleam` (49L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `kms.init()` | `checkpoints = []`, `total_keys = 0`, `active_keys = 0` | O(1) | Unit: `webui_full_coverage_test.gleam:kms_init_defaults_test` |
| L0-2 | Any model state | `RefreshKms` msg | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:kms_update_refresh_noop_test` |
| L0-3 | Any model state | `KeyRotated(_)` | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:kms_update_key_rotated_noop_test` |

**Invariant**: `KeyRotated` is a no-op — key rotation not tracked in model. **Design gap**.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty checkpoints | `CheckpointsLoaded([cp])` | `checkpoints = [cp]` | O(1) | Unit: `webui_full_coverage_test.gleam:kms_update_checkpoints_loaded_test` |
| L1-2 | Model with empty checkpoints | `CheckpointsLoaded([cp1, cp2])` | `checkpoints = [cp1, cp2]` | O(1) | Unit: `webui_full_coverage_test.gleam:kms_update_checkpoints_loaded_multiple_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Model with no checkpoints | `latest_checkpoint()` | Returns `Error(Nil)` | O(1) | Unit: `webui_full_coverage_test.gleam:kms_latest_checkpoint_empty_test` |
| L2-2 | Model with 2 checkpoints | `latest_checkpoint()` | Returns `Ok(cp1)` (first in list) | O(1) | Unit: `webui_full_coverage_test.gleam:kms_latest_checkpoint_returns_first_test` |
| L2-3 | Model with 3 checkpoints | `checkpoint_count()` | Returns 3 | O(1) | Unit: `webui_full_coverage_test.gleam:kms_checkpoint_count_test` |
| L2-4 | Model with no checkpoints | `checkpoint_count()` | Returns 0 | O(1) | Unit: `webui_full_coverage_test.gleam:kms_checkpoint_count_zero_test` |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with checkpoints | CheckpointsLoaded(new_checkpoints) → latest_checkpoint() | Returns first of new set | O(1) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/kms/catalog` | JSON with total_keys=12, active_keys=10, 4 checkpoints (mesh-root, zenoh-session, db-encryption, holon-signing) | O(1), static | Unit: `webui_full_coverage_test.gleam:route_kms_contains_checkpoints_test` |
| L4-2 | Wisp router running | GET `/api/v1/kms` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_v1_kms_test` |
| L4-3 | KMS API | `catalog_json(checkpoints, total_keys, active_keys)` | JSON with total_keys, active_keys, checkpoint_count, checkpoints array | O(n) encode | Integration |
| L4-4 | KMS API | `checkpoint_detail_json(cp, status, rotation_policy)` | JSON with key, hash, timestamp, status, rotation_policy, metadata | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | active_keys = 0 | TUI renders | Red "Active: 0" warning | O(1) render | Integration: TUI |
| L5-2 | Checkpoints with varying key counts | TUI renders | Each checkpoint shows id, label, key_count, timestamp | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Key rotation triggered | KMS updates checkpoint | CheckpointsLoaded with new checkpoint | O(n) reload | E2E |
| L6-2 | Key expires | active_keys decrements | TUI shows reduced active count | O(1) | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A rotates key | Federation shares KMS state | Peer B receives updated checkpoint | Network + O(1) | E2E: federation |

**Coverage Gaps**: `KeyRotated` is a no-op. `total_keys` and `active_keys` are never updated via Msg (only via CheckpointsLoaded which replaces checkpoints list). No TUI-specific test for `kms_view.gleam`. No `kms_api.gleam` direct unit tests.

---

## 13. TELEMETRY (L1_ATOMIC_DEBUG)

**Source**: `lustre/telemetry.gleam` (75L), `wisp/telemetry_api.gleam` (45L), `tui/telemetry_view.gleam` (71L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `telemetry.init()` | `spans = []`, `metrics = []`, `log_level = Info`, `active_traces = 0` | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_init_defaults_test` |
| L0-2 | Any model state | `RefreshTelemetry` msg | Model unchanged (stub) | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_update_refresh_noop_test` |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty spans | `SpanReceived(span)` | `spans = [span]` (prepended) | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_update_span_received_test` |
| L1-2 | Model with empty metrics | `MetricUpdated(metric)` | `metrics = [metric]` (prepended) | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_update_metric_updated_test` |
| L1-3 | Model with log_level=Info | `SetLogLevel(Debug)` | `log_level = Debug` | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_update_set_log_level_test` |
| L1-4 | Model with log_level=Info | `SetLogLevel(Warning)` | `log_level = Warning` | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_update_set_log_level_warning_test` |
| L1-5 | Model with log_level=Info | `SetLogLevel(Error)` | `log_level = Error` | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_update_set_log_level_error_test` |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Model with 3 spans | `recent_spans(model, 2)` | Returns 2 spans (most recent first) | O(n) take | Unit: `webui_full_coverage_test.gleam:telemetry_recent_spans_takes_n_test` |
| L2-2 | Model with no spans | `recent_spans(model, 5)` | Returns `[]` | O(1) | Unit: `webui_full_coverage_test.gleam:telemetry_recent_spans_empty_test` |
| L2-3 | Model with 3 spans, request 10 | `recent_spans(model, 10)` | Returns all 3 spans | O(n) | Unit: `webui_full_coverage_test.gleam:telemetry_recent_spans_takes_n_test` |
| L2-4 | Model with 2 metrics | `metric_by_name(model, "cpu_percent")` | Returns `Ok(metric)` with value=32.5 | O(n) find | Unit: `webui_full_coverage_test.gleam:telemetry_metric_by_name_found_test` |
| L2-5 | Model with no matching metric | `metric_by_name(model, "nonexistent")` | Returns `Error(Nil)` | O(n) find | Unit: `webui_full_coverage_test.gleam:telemetry_metric_by_name_not_found_test` |
| L2-6 | All 4 log levels | `log_level_to_string()` | "DEBUG", "INFO", "WARNING", "ERROR" | O(1) | Unit: 4 × log_level_to_string tests |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with spans | SpanReceived(sp1) → SpanReceived(sp2) → recent_spans(1) | Returns [sp2] (most recent) | O(1) × 2 + O(n) | Unit: `webui_full_coverage_test.gleam:telemetry_update_span_prepends_test` |
| L3-2 | Model with metrics | MetricUpdated(m1) → MetricUpdated(m2) → metric_by_name("cpu_percent") | Returns correct metric | O(1) × 2 + O(n) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/telemetry/status` | JSON with active_traces=8, total_spans=1247, metrics (cpu, memory, network), log_level="info" | O(1), static | Unit: `webui_full_coverage_test.gleam:route_telemetry_contains_otel_test` |
| L4-2 | Wisp router running | GET `/api/v1/telemetry` | Same as above (alias route) | O(1) | Unit: `webui_full_coverage_test.gleam:route_api_v1_telemetry_test` |
| L4-3 | Telemetry API | `status_json(active_traces, total_spans, cpu_percent, memory_mb, network_bytes_sec, log_level)` | JSON with all fields | O(1) | Integration |
| L4-4 | Telemetry API | `metrics_json(cpu_percent, memory_mb, network_bytes_sec)` | Compact JSON with 3 metrics | O(1) | Integration |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Span with status="error" | TUI renders | Red "[error]" badge, name, duration_us, trace_id | O(n) render | Integration: TUI |
| L5-2 | Multiple metrics | TUI renders | Cyan metric name, value, unit | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | OTel collector running | Spans published to `indrajaal/agui/telemetry` | Telemetry receives SpanReceived | Network + O(1) | E2E |
| L6-2 | Log level changed to Error | Only Error-level spans displayed | Filtered view | O(n) filter | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A generates span | Federation shares telemetry | Peer B receives SpanReceived | Network + O(1) | E2E: federation |

**Coverage Gaps**: `active_traces` field is never updated via Msg (always 0). No TUI-specific test for `telemetry_view.gleam`. No `telemetry_api.gleam` direct unit tests.

---

## 14. FEDERATION (L7_FEDERATION)

**Source**: `lustre/federation.gleam` (111L), `wisp/federation_api.gleam` (96L), `tui/federation_view.gleam` (113L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `federation.init()` | `state = None`, `loading = False`, `error = None` | O(1) | Unit: federation.gleam |
| L0-2 | Any model state | `ErrorReceived(err)` | `error = Some(err)`, `loading = False` | O(1) | Unit: federation.gleam |

**Invariant**: Federation starts with no state — must be loaded from backend.

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with no state | `StateReceived(state)` | `state = Some(state)`, `loading = False`, `error = None` | O(1) | Unit: federation.gleam |
| L1-2 | Model with state | `PeerAdded(peer)` | State updated with new peer via `add_peer(s, peer)` | O(1) | Unit: federation.gleam |
| L1-3 | Model with no state | `PeerAdded(peer)` | Model unchanged (guard: None → model) | O(1) | Unit: federation.gleam |
| L1-4 | Model with state | `PeerRemoved(id)` | State updated with peer removed via `remove_peer(s, id)` | O(n) | Unit: federation.gleam |
| L1-5 | Model with no state | `PeerRemoved(id)` | Model unchanged (guard: None → model) | O(1) | Unit: federation.gleam |
| L1-6 | Model with state | `VersionIncremented` | State version incremented via `increment_version(s)` | O(1) | Unit: federation.gleam |
| L1-7 | Model with no state | `VersionIncremented` | Model unchanged (guard: None → model) | O(1) | Unit: federation.gleam |
| L1-8 | Model with no loading | `RefreshFederation` | `loading = True` | O(1) | Unit: federation.gleam |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | Model with no state | `connected_count()` | Returns 0 | O(1) | Unit: federation.gleam |
| L2-2 | Model with state (3 peers, 2 connected) | `connected_count()` | Returns 2 | O(n) | Unit: federation.gleam |
| L2-3 | Model with no state | `all_attested_check()` | Returns `False` | O(1) | Unit: federation.gleam |
| L2-4 | Model with state (all attested) | `all_attested_check()` | Returns `True` | O(n) | Unit: federation.gleam |
| L2-5 | Model with state (3 peers) | `total_peer_count()` | Returns 3 | O(1) | Unit: federation.gleam |
| L2-6 | Model with no state | `total_peer_count()` | Returns 0 | O(1) | Unit: federation.gleam |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with state | PeerAdded(peer1) → PeerAdded(peer2) → connected_count() | Count = previous + 2 | O(1) × 2 + O(n) | Integration |
| L3-2 | Model with state | RefreshFederation → StateReceived(new_state) | loading=True → loading=False, state updated | O(1) × 2 | Integration |
| L3-3 | Model with state | PeerAdded → PeerRemoved(same_id) → connected_count() | Count unchanged (add then remove) | O(1) + O(n) + O(n) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/federation/status` | JSON with local_id, peer_count, connected_count, all_attested, peers array, version_vector | O(1), via sample_state() | Unit: federation_api.gleam |
| L4-2 | Federation API | `federation_status_json(state)` | JSON with plane, local_id, peer_count, connected_count, all_attested, peers, version_vector | O(n) encode | Integration |
| L4-3 | Federation API | `peer_list_json(peers)` | JSON with peer_count, peers array | O(n) encode | Integration |
| L4-4 | Federation API | `sample_state()` | FederationState with 3 peers (2 connected + attested, 1 suspected + not attested) | O(1) | Unit: federation_api.gleam |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Peer status = PeerSuspected, attestation_valid=False | TUI renders | Yellow "[suspected]" badge, red "att:NO" | O(n) render | Integration: TUI |
| L5-2 | All peers attested | TUI renders | Green "ALL ATTESTED" | O(1) render | Integration: TUI |
| L5-3 | Attestation incomplete | TUI renders | Red "ATTESTATION INCOMPLETE" | O(1) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | New peer discovered | Federation receives StateReceived | Peer count increments, TUI updates | O(n) | E2E |
| L6-2 | Peer connection lost | Peer status changes to PeerDisconnected | TUI shows red "[disconnected]" | O(n) render | E2E |
| L6-3 | Version vector updated | VersionIncremented | Local version clock increments | O(1) | Integration |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | 3 federation peers | All peers connected and attested | `all_attested_check()` = True, TUI shows green | O(n) check | E2E: federation_triple_test |
| L7-2 | Peer goes offline | Federation detects via heartbeat timeout | Peer status = PeerSuspected, attestation invalidated | O(n) | E2E |
| L7-3 | Cross-system state sync | Version vectors compared | Conflicts detected and resolved | O(n × m) | E2E |

**Coverage Gaps**: No explicit unit test file for `federation.gleam` Lustre module (only `federation_triple_test.gleam` exists). No TUI-specific test for `federation_view.gleam`.

---

## 15. HEALTHGRID (L4_SYSTEM)

**Source**: `lustre/health_grid.gleam` (170L), `wisp/health_api.gleam` (44L), `tui/health_view.gleam` (73L)

### L0 — Constitutional
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L0-1 | System initialized | `health_grid.init()` | `devices = []`, `selected_id = None`, `filter = AllDevices` | O(1) | Unit: health_grid.gleam |
| L0-2 | Any model state | `Refresh` msg | Model unchanged (stub) | O(1) | Unit: health_grid.gleam |

### L1 — Atomic
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L1-1 | Model with empty selection | `SelectDevice("cam-001")` | `selected_id = Some("cam-001")` | O(1) | Unit: health_grid.gleam |
| L1-2 | Model with AllDevices filter | `SetFilter(HealthyOnly)` | `filter = HealthyOnly` | O(1) | Unit: health_grid.gleam |
| L1-3 | Model with empty devices | `DevicesLoaded([device])` | `devices = [device]` | O(1) | Unit: health_grid.gleam |

### L2 — Component
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L2-1 | 5 devices (scores: 0.95, 0.72, 0.98, 0.45, 0.88), filter=AllDevices | `view(model)` renders grid | All 5 devices shown | O(n) render | Unit: health_grid.gleam (render test) |
| L2-2 | Same 5 devices, filter=HealthyOnly (>0.8) | Filtered grid | 3 devices (0.95, 0.98, 0.88) | O(n) filter | Unit: health_grid.gleam |
| L2-3 | Same 5 devices, filter=DegradedOnly (0.5-0.8) | Filtered grid | 1 device (0.72) | O(n) filter | Unit: health_grid.gleam |
| L2-4 | Same 5 devices, filter=CriticalOnly (<=0.5) | Filtered grid | 1 device (0.45) | O(n) filter | Unit: health_grid.gleam |
| L2-5 | Device selected | `render_details(model)` | Shows device id, type, status, health_score, last_seen | O(n) find | Unit: health_grid.gleam |
| L2-6 | No device selected | `render_details(model)` | Shows "Select a device for details" | O(1) | Unit: health_grid.gleam |
| L2-7 | Selected device not in list | `render_details(model)` | Shows "Device not found" | O(n) find → Error | Unit: health_grid.gleam |

### L3 — Transaction
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L3-1 | Model with devices | SelectDevice("cam-001") → SetFilter(CriticalOnly) | Selected device preserved, grid shows only critical devices | O(1) + O(n) | E2E |
| L3-2 | Model with devices | DevicesLoaded(new_devices) → SelectDevice("new-id") | Devices replaced, new device selected | O(n) + O(1) | Integration |

### L4 — System
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L4-1 | Wisp router running | GET `/api/health` (shared endpoint) | JSON with status="ok", interface="wisp", port=4100 | O(1) | Unit: `webui_full_coverage_test.gleam:route_health_test` |
| L4-2 | Health API | `health_grid_json(devices)` | JSON with plane="health_grid", device_count, devices array | O(n) encode | Integration |
| L4-3 | Health API | `mock_devices()` | Returns 5 devices (cam-001, cam-002, reader-001, panel-001, sensor-001) | O(1) | Unit: health_api.gleam |

### L5 — Cognitive
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L5-1 | Device health_score <= 0.5 | TUI renders | Red health bar, low percentage | O(n) render | Integration: TUI |
| L5-2 | Device status = Maintenance | TUI renders | Yellow "[MAINT]" badge | O(n) render | Integration: TUI |
| L5-3 | Device status = Offline | TUI renders | Red "[OFF]" badge | O(n) render | Integration: TUI |

### L6 — Ecosystem
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L6-1 | Device health degrades | Zenoh telemetry update | DevicesLoaded with updated health_score, filter re-applied | Network + O(n) | E2E |
| L6-2 | Device goes offline | Status changes to Offline | TUI shows red "[OFF]", health grid updates | O(n) reload | E2E |

### L7 — Federation
| # | Given | When | Then | Runtime | Verification |
|---|-------|------|------|---------|-------------|
| L7-1 | Peer A device status changes | Federation shares health grid | Peer B receives updated device list | Network + O(n) | E2E: federation |

**Coverage Gaps**: No explicit unit test file for `health_grid.gleam` Lustre module. No TUI-specific test for `health_view.gleam`. No `health_api.gleam` direct unit tests. The HealthGrid has the most complete Lustre implementation (170L with full view rendering) but the least test coverage.

---

## CROSS-CUTTING ANALYSIS

### Coverage Summary by Tab

| Tab | Fractal Layer | Lustre Lines | Wisp Lines | TUI Lines | Unit Tests | TUI Tests | API Tests | Gaps |
|-----|--------------|-------------|-----------|-----------|-----------|-----------|-----------|------|
| Dashboard | L5 | 97 | (router) | (shared) | 18 | 0 | 0 | No dedicated TUI test |
| Planning | L3 | 66 | 53 | 53 | 13 | 0 | 0 | No TUI/API tests |
| Immune | L0 | 56 | 75 | 74 | 11 | 0 | 0 | AttackResolved no-op |
| Knowledge | L5 | 61 | 49 | 55 | 10 | 0 | 0 | search_query unused |
| Zenoh | L6 | 68 | 40 | 50 | 11 | 0 | 0 | No TUI/API tests |
| Cockpit | L5 | 89 | 69 | 116 | 12 | 0 | 0 | AcknowledgeAlarm no-op |
| Verification | L0 | 127 | 120 | 169 | 7 | 0 | 0 | Missing 4 msg handler tests |
| Substrate | L3 | 52 | 60 | 81 | 8 | 0 | 0 | file_ops never populated |
| Metabolic | L1 | 44 | 53 | 52 | 13 | 0 | 0 | No TUI/API tests |
| Podman | L4 | 63 | 68 | 97 | 11 | 0 | 0 | Start/Stop no-ops |
| Mcp | L6 | 60 | 39 | 69 | 11 | 0 | 0 | No TUI/API tests |
| Kms | L0 | 38 | 55 | 49 | 8 | 0 | 0 | KeyRotated no-op |
| Telemetry | L1 | 75 | 45 | 71 | 13 | 0 | 0 | active_traces never updated |
| Federation | L7 | 111 | 96 | 113 | 0 | 0 | 0 | No Lustre unit tests |
| HealthGrid | L4 | 170 | 44 | 73 | 0 | 0 | 0 | No Lustre/TUI/API tests |

### Systemic Gaps Identified

1. **No TUI-specific tests**: Zero test files target `ui/tui/*.gleam` modules directly. TUI rendering logic (ANSI color coding, progress bars, truncation) is untested.

2. **No Wisp API-specific tests**: Zero test files target `ui/wisp/*_api.gleam` modules directly. JSON encoding logic is untested.

3. **Stub Msg handlers**: 10 Msg variants across tabs are no-ops:
   - `RefreshTasks`, `RefreshImmune`, `RefreshKnowledge`, `RefreshZenoh`, `RefreshCockpit`, `RefreshSubstrate`, `RefreshMetabolic`, `RefreshPodman`, `RefreshMcp`, `RefreshKms`, `RefreshTelemetry`, `Refresh`
   - `AttackResolved`, `AcknowledgeAlarm`, `KeyRotated`
   - `StartContainer`, `StopContainer`

4. **Unused fields**: `search_query` (Knowledge), `file_ops` (Substrate), `active_traces` (Telemetry) are set but never used in queries.

5. **Federation & HealthGrid**: The two most complex modules (111L + 170L Lustre) have zero unit tests.

### Recommended Test Priority

| Priority | Tab | Action | Estimated Tests |
|----------|-----|--------|----------------|
| P0 | Federation | Add Lustre unit tests for all 8 Msg handlers + 6 query functions | 14 |
| P0 | HealthGrid | Add Lustre unit tests for all 4 Msg handlers + 7 filter/render functions | 11 |
| P1 | Verification | Add tests for ProofGenerated, GraphChecksCompleted, DagUpdated, all_checks_passed, latest_proof_verified | 8 |
| P1 | All tabs | Add TUI render tests (snapshot or structural) | 15 |
| P2 | All tabs | Add Wisp API JSON encoding tests | 15 |
| P2 | Cockpit | Add tests for NodesUpdated, AlarmsUpdated handlers | 2 |
| P3 | Substrate | Add tests for file_ops (or remove field) | 2 |
| P3 | Knowledge | Implement search_query filtering or remove field | 1 |

### KPI Definitions per Element

| KPI | Target | Measured By |
|-----|--------|-------------|
| `init()` latency | < 1ms | Unit test benchmark |
| `update()` latency | < 0.1ms per msg | Unit test benchmark |
| TUI render latency | < 10ms for 100 items | Integration test |
| Wisp JSON encode latency | < 1ms for 100 items | Integration test |
| Filter function correctness | 100% | Unit test (all filter variants) |
| No-op handler coverage | 100% documented | Code audit |
| Cross-interface type consistency | 100% shared types | `gleam check` |
| Zero-warning compilation | 0 warnings | `gleam build` |

### Monitoring Strategy

| Layer | What to Monitor | How |
|-------|----------------|-----|
| L0-L1 | Model init correctness, msg handler coverage | Unit test pass rate |
| L2-L3 | Filter/query correctness, state transition integrity | Unit + integration tests |
| L4 | Wisp endpoint availability, JSON validity | Health check + route tests |
| L5 | TUI render correctness, Dark Cockpit filtering | Integration tests |
| L6 | Zenoh connectivity, message throughput | E2E tests + mesh probes |
| L7 | Federation peer count, attestation status | E2E federation tests |