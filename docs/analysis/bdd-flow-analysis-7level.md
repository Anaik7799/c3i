# C3I Dashboard — 7-Level BDD Flow Analysis (All 15 Tabs)

## Master Index

| # | Tab | Fractal Layer | Lustre | Wisp | TUI | Tests |
|---|-----|--------------|--------|------|-----|-------|
| 1 | Dashboard | L5 Cognitive | `app.gleam` | `router.gleam` | N/A (uses cockpit_view) | `webui_full_coverage_test.gleam` |
| 2 | Planning | L3 Transaction | `planning.gleam` | `planning_api.gleam` | `planning_view.gleam` | `planning_dashboard_test.gleam`, `planning_wiring_test.gleam` |
| 3 | Immune | L0 Constitutional | `immune.gleam` | `immune_api.gleam` | `immune_view.gleam` | None specific |
| 4 | Knowledge | L5 Cognitive | `knowledge.gleam` | `knowledge_api.gleam` | `knowledge_view.gleam` | None specific |
| 5 | Zenoh | L6 Ecosystem | `zenoh_mesh.gleam` | `zenoh_api.gleam` | `zenoh_view.gleam` | None specific |
| 6 | Cockpit | L5 Cognitive | `cockpit_view.gleam` | `cockpit_api.gleam` | `cockpit_view.gleam` | None specific |
| 7 | Verification | L0 Constitutional | `verification.gleam` | `verification_api.gleam` | `verification_view.gleam` | `verification_prometheus_test.gleam`, `verification_wiring_test.gleam` |
| 8 | Substrate | L3 Transaction | `substrate.gleam` | `substrate_api.gleam` | `substrate_view.gleam` | None specific |
| 9 | Metabolic | L1 Atomic Debug | `metabolic.gleam` | `metabolic_api.gleam` | `metabolic_view.gleam` | `metabolic_test.gleam`, `metabolic_zenoh_integration_test.gleam` |
| 10 | Podman | L4 System | `podman.gleam` | `podman_api.gleam` | `podman_view.gleam` | None specific |
| 11 | Mcp | L6 Ecosystem | `mcp.gleam` | `mcp_api.gleam` | `mcp_view.gleam` | None specific |
| 12 | Kms | L0 Constitutional | `kms.gleam` | `kms_api.gleam` | `kms_view.gleam` | `kms_catalog_test.gleam`, `kms_invariants_test.gleam` |
| 13 | Telemetry | L1 Atomic Debug | `telemetry.gleam` | `telemetry_api.gleam` | `telemetry_view.gleam` | None specific |
| 14 | Federation | L7 Federation | `federation.gleam` | `federation_api.gleam` | `federation_view.gleam` | `federation_triple_test.gleam` |
| 15 | HealthGrid | L4 System | `health_grid.gleam` | `health_api.gleam` | `health_view.gleam` | None specific |

---

## 1. DASHBOARD (L5 Cognitive)

### L0 — Constitutional
- **Given**: Application initialized with `init()` returning `Model(context: RenderContext(page: Dashboard, health: Unknown, telemetry: [], zenoh_connected: False), dark_cockpit: True, selected_page: Dashboard)`
- **When**: System starts
- **Then**: Default page is Dashboard, dark cockpit enabled, health is Unknown, Zenoh disconnected
- **Runtime**: O(1) init, zero allocations beyond Model struct
- **Verification**: Unit test — `init()` returns correct Model variant

### L1 — Atomic
- **Given**: Model with `dark_cockpit: True` and `health: Healthy`
- **When**: `health_class(Healthy)` called
- **Then**: Returns `"health-ok"`; `health_class(Critical(_))` returns `"health-critical"`
- **Runtime**: O(1) pattern match
- **Verification**: Unit test — all 4 HealthStatus → CSS class mappings

### L2 — Component
- **Given**: Model with `selected_page: Dashboard`
- **When**: `NavigateTo(Planning)` message dispatched
- **Then**: `model.selected_page == Planning`, `model.context.page` unchanged (Dashboard)
- **Runtime**: O(1) record update, immutable copy
- **Verification**: Unit test — `update(model, NavigateTo(Planning))` returns correct model

### L3 — Transaction
- **Given**: Model with empty telemetry list
- **When**: Sequence: `TelemetryReceived(point1)` → `TelemetryReceived(point2)`
- **Then**: `model.context.telemetry == [point2, point1]` (LIFO order)
- **Runtime**: O(n) list prepend per message, n = telemetry count
- **Verification**: Unit test — sequential telemetry accumulation

### L4 — System
- **Given**: Model with `zenoh_connected: False`
- **When**: `ZenohConnectionChanged(True)` → `HealthUpdated(Healthy)` → `Tick`
- **Then**: Zenoh connected, health Healthy, Tick is no-op (model unchanged)
- **Runtime**: O(1) per message; Tick is identity function
- **Verification**: Integration test — multi-message state transition chain

### L5 — Cognitive
- **Given**: Model with `dark_cockpit: True`
- **When**: `ToggleDarkCockpit` → `ToggleDarkCockpit`
- **Then**: Dark cockpit returns to True (double toggle = identity)
- **Runtime**: O(1) boolean flip
- **Verification**: Unit test — ToggleDarkCockpit idempotency

### L6 — Ecosystem
- **Given**: Zenoh connected with active subscriptions
- **When**: `ZenohConnectionChanged(False)` (mesh disconnect)
- **Then**: `model.context.zenoh_connected == False`, telemetry continues accumulating but source is stale
- **Runtime**: O(1) flag update; downstream consumers must handle stale data
- **Verification**: Integration test — connection loss recovery

### L7 — Federation
- **Given**: Dashboard as central cognitive hub
- **When**: All 14 other tabs report health via shared `RenderContext`
- **Then**: Dashboard aggregates health into single `HealthStatus` (worst-of-all)
- **Runtime**: O(n) aggregation where n = active tabs; must be bounded
- **Verification**: E2E test — cross-tab health propagation

---

## 2. PLANNING (L3 Transaction)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `PlanningModel(tasks: [], filter: AllTasks, selected_id: None)` — empty, no filter, no selection
- **Runtime**: O(1)
- **Verification**: Unit test — `init()` returns correct PlanningModel

### L1 — Atomic
- **Given**: `PlanningTask(id: "1", title: "T1", status: "pending", priority: "P0", owner: None)`
- **When**: `task_count_by_status([task], "pending")` called
- **Then**: Returns `1`; `task_count_by_status([task], "completed")` returns `0`
- **Runtime**: O(n) list filter + length
- **Verification**: Unit test — count accuracy for each status

### L2 — Component
- **Given**: Model with tasks in mixed statuses
- **When**: `SetFilter(PendingOnly)`
- **Then**: `filtered_tasks(model)` returns only tasks with `status == "pending"`
- **Runtime**: O(n) filter; n = total tasks
- **Verification**: Unit test — each filter variant produces correct subset

### L3 — Transaction
- **Given**: Model with 5 tasks, 2 pending, 1 in_progress, 1 completed, 1 blocked
- **When**: `TasksLoaded(new_tasks)` with 3 tasks → `SetFilter(BlockedOnly)` → `SelectTask("x")`
- **Then**: Tasks replaced, filter shows blocked only, selected_id = Some("x")
- **Runtime**: O(n) replace + O(m) filter where m = new task count
- **Verification**: Unit test — multi-step state transition

### L4 — System
- **Given**: Planning API returns JSON via `planning_json()` in router
- **When**: Wisp route `/api/v1/planning` hit
- **Then**: Returns typed JSON with page, status, tasks array (6 sample tasks), summary
- **Runtime**: O(1) stub response; production would be O(n) DB query
- **Verification**: Integration test — Wisp endpoint returns valid JSON

### L5 — Cognitive
- **Given**: Model with tasks loaded
- **When**: `RefreshTasks` (no-op in current implementation)
- **Then**: Model unchanged; signals need for backend fetch integration
- **Runtime**: O(1) identity
- **Verification**: Unit test — RefreshTasks is no-op (documented gap)

### L6 — Ecosystem
- **Given**: Planning tasks synced from F# Chaya via `/api/chaya/sync`
- **When**: Chaya reports 25 tasks, 0 orphans, 0 mismatches
- **Then**: Planning dashboard shows all 25 tasks with correct status
- **Runtime**: O(n) sync + O(n) render; n = task count
- **Verification**: E2E test — Chaya ↔ Planning consistency

### L7 — Federation
- **Given**: Multiple planning instances across federation peers
- **When**: Peer A creates task → Peer B receives via federation sync
- **Then**: Both peers show consistent task list (eventual consistency via version vectors)
- **Runtime**: O(n) diff + merge; network latency bounded by Zenoh mesh
- **Verification**: E2E test — cross-peer task consistency

---

## 3. IMMUNE (L0 Constitutional)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `ImmuneModel(antibodies: [], recent_events: [], active_attacks: [], mara_running: False)`
- **Invariant**: Empty state = safe state; no false positives on startup
- **Runtime**: O(1)
- **Verification**: Unit test — init returns empty safe state

### L1 — Atomic
- **Given**: Model with 0 active attacks
- **When**: `threat_level(model)` called
- **Then**: Returns `"nominal"`; with 2 attacks → `"elevated"`; with 3+ → `"critical"`
- **Runtime**: O(1) length check
- **Verification**: Unit test — threat level thresholds (0, 1-2, 3+)

### L2 — Component
- **Given**: Model with empty antibodies
- **When**: `AntibodyAdded(ab)` → `EventReceived(evt)`
- **Then**: Antibodies = [ab], events = [evt] (both prepended)
- **Runtime**: O(1) list prepend each
- **Verification**: Unit test — antibody and event accumulation

### L3 — Transaction
- **Given**: Model with 2 active attacks
- **When**: `AttackDetected(atk3)` → `AttackResolved(id1)` → `ToggleMara`
- **Then**: 3 attacks detected, mara_running toggled; AttackResolved is currently no-op
- **Runtime**: O(1) for detection/toggle; O(n) for resolve (currently no-op — gap)
- **Verification**: Unit test — attack lifecycle; **GAP**: AttackResolved doesn't remove

### L4 — System
- **Given**: Immune API endpoint `/api/immune/status`
- **When**: Wisp route hit
- **Then**: Returns JSON with plane, status, threat_level, antibodies_deployed, chaos_attacks_blocked, last_scan
- **Runtime**: O(1) stub response
- **Verification**: Integration test — immune_api encodes correct JSON structure

### L5 — Cognitive
- **Given**: Mara (autonomous response agent) running
- **When**: `AttackDetected(atk)` while `mara_running: True`
- **Then**: System should auto-generate antibody (current implementation doesn't — gap)
- **Runtime**: O(1) detection; antibody generation would be O(n) pattern match
- **Verification**: Integration test — Mara auto-response loop

### L6 — Ecosystem
- **Given**: Zenoh mesh with immune event subscriptions
- **When**: `SafetyViolationDetected(reason)` event received via Zenoh
- **Then**: Event appears in `recent_events`, threat level recalculated
- **Runtime**: O(1) event receipt + O(1) threat recalculation
- **Verification**: Integration test — Zenoh → Immune event pipeline

### L7 — Federation
- **Given**: Multiple immune systems across federation
- **When**: Peer A detects attack → broadcasts antibody pattern
- **Then**: Peer B synthesizes matching antibody (cross-peer immune memory)
- **Runtime**: O(n) antibody broadcast + O(m) pattern match at receiver
- **Verification**: E2E test — federated immune response

---

## 4. KNOWLEDGE (L5 Cognitive)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `KnowledgeModel(nodes: [], links: [], selected_node: None, filter_level: None, search_query: "")`
- **Invariant**: Empty knowledge graph is valid; no errors on empty state
- **Runtime**: O(1)
- **Verification**: Unit test — init returns valid empty model

### L1 — Atomic
- **Given**: Model with nodes at different HolonLevels
- **When**: `node_count_by_level(nodes, Atomic)` called
- **Then**: Returns count of nodes where `n.level == Atomic`
- **Runtime**: O(n) filter + length
- **Verification**: Unit test — count per level for all 4 levels

### L2 — Component
- **Given**: Model with 10 nodes, 5 links, filter_level = None
- **When**: `SetLevelFilter(Some(Molecular))`
- **Then**: `filtered_nodes(model)` returns only Molecular-level nodes
- **Runtime**: O(n) filter
- **Verification**: Unit test — level filter correctness

### L3 — Transaction
- **Given**: Model with nodes containing titles
- **When**: `SetSearch("test")` → `NodesLoaded(nodes, links)` → `SelectNode("n1")`
- **Then**: Search query set, nodes/links replaced, selected_node = Some("n1")
- **Runtime**: O(1) search set + O(n) load + O(1) select
- **Verification**: Unit test — multi-operation state transition

### L4 — System
- **Given**: Knowledge API endpoint `/api/v1/knowledge`
- **When**: Wisp route hit
- **Then**: Returns JSON with 42 nodes, 87 links, level breakdown (A:12, M:15, O:10, E:5)
- **Runtime**: O(1) stub; production O(n) graph query
- **Verification**: Integration test — knowledge_api JSON encoding

### L5 — Cognitive
- **Given**: Knowledge graph with entropy values per node
- **When**: Nodes loaded with varying entropy (0.0–1.0)
- **Then**: TUI renders progress bars proportional to entropy; high-entropy nodes flagged
- **Runtime**: O(n) render; progress bar is O(k) where k = bar width
- **Verification**: Unit test — entropy visualization correctness

### L6 — Ecosystem
- **Given**: Knowledge nodes linked across fractal layers
- **When**: Node at L2 references node at L5
- **Then**: Link appears in `links` list with correct source_id, target_id, relation_type
- **Runtime**: O(n) link traversal
- **Verification**: Integration test — cross-layer knowledge links

### L7 — Federation
- **Given**: Knowledge graphs on multiple federation peers
- **When**: Peer A adds node → version vector incremented
- **Then**: Peer B receives node via sync, merges without conflict
- **Runtime**: O(n + m) merge where n, m = node counts
- **Verification**: E2E test — federated knowledge graph consistency

---

## 5. ZENOH (L6 Ecosystem)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `ZenohModel(health: empty_health(), lifecycle: Uninitialized, subscriptions: [], message_log: [])`
- **Invariant**: Uninitialized state is safe; no messages processed before connection
- **Runtime**: O(1)
- **Verification**: Unit test — init returns safe uninitialized state

### L1 — Atomic
- **Given**: Model with health status = Connected
- **When**: `is_connected(model)` called
- **Then**: Returns `True`; with Disconnected → `False`
- **Runtime**: O(1) field access + equality
- **Verification**: Unit test — is_connected for all 3 ConnectionStatus variants

### L2 — Component
- **Given**: Model with empty subscriptions
- **When**: `SubscriptionAdded("topic/a")` → `SubscriptionAdded("topic/b")` → `SubscriptionRemoved("topic/a")`
- **Then**: Subscriptions = ["topic/b"]
- **Runtime**: O(1) prepend + O(n) filter on remove
- **Verification**: Unit test — subscription lifecycle

### L3 — Transaction
- **Given**: Model with empty message_log
- **When**: `MessageReceived("k1", 100, 1000)` → `MessageReceived("k2", 200, 2000)` → `HealthUpdated(new_health)`
- **Then**: message_log = [entry2, entry1], health updated
- **Runtime**: O(1) per message prepend; O(1) health update
- **Verification**: Unit test — message accumulation + health update

### L4 — System
- **Given**: Zenoh API endpoint `/api/v1/zenoh`
- **When**: Wisp route hit
- **Then**: Returns JSON with 3 routers, connected=True, 12 topics_active, router endpoints
- **Runtime**: O(1) stub; production O(n) router health check
- **Verification**: Integration test — zenoh_api JSON structure

### L5 — Cognitive
- **Given**: Model with message history
- **When**: `message_rate(model)` called
- **Then**: Returns `messages_published + messages_received` from health struct
- **Runtime**: O(1) addition
- **Verification**: Unit test — message rate calculation

### L6 — Ecosystem
- **Given**: Zenoh mesh with 3 routers (ports 7447, 7448, 7449)
- **When**: Router 1 fails → `LifecycleChanged(Reconnecting)` → `HealthUpdated(degraded_health)`
- **Then**: Health reflects degraded state, reconnect_count incremented
- **Runtime**: O(1) state update; reconnect logic external
- **Verification**: Integration test — router failure detection and recovery

### L7 — Federation
- **Given**: Zenoh mesh spanning multiple federation peers
- **When**: Cross-peer message published → received on local mesh
- **Then**: Message appears in message_log with correct key, size, timestamp
- **Runtime**: O(1) log prepend; network latency bounded by mesh RTT
- **Verification**: E2E test — cross-peer Zenoh message delivery

---

## 6. COCKPIT (L5 Cognitive)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `CockpitModel(nodes: [], alarms: [], view_mode: Overview, dark_cockpit: True, selected_node: None)`
- **Invariant**: Dark cockpit ON by default; no alarms on startup
- **Runtime**: O(1)
- **Verification**: Unit test — init returns correct CockpitModel

### L1 — Atomic
- **Given**: Alarm with level Critical
- **When**: `alarm_severity_rank(Critical)` called
- **Then**: Returns 5; Warning→4, Caution→3, Advisory→2, Normal→1
- **Runtime**: O(1) pattern match
- **Verification**: Unit test — all 5 severity ranks

### L2 — Component
- **Given**: Model with `dark_cockpit: True` and nodes including Connected and Degraded
- **When**: `visible_nodes(model)` called
- **Then**: Returns only non-Connected nodes (Degraded, Stale, Disconnected)
- **Runtime**: O(n) filter
- **Verification**: Unit test — dark cockpit filtering

### L3 — Transaction
- **Given**: Model with 3 alarms (Critical, Warning, Advisory)
- **When**: `AlarmsUpdated([new_alarms])` → `AcknowledgeAlarm(id)` → `active_alarms(model)`
- **Then**: Alarms replaced, acknowledged alarm filtered, remaining sorted by severity (Critical first)
- **Runtime**: O(n) replace + O(n log n) sort; AcknowledgeAlarm is currently no-op (gap)
- **Verification**: Unit test — alarm sort order; **GAP**: AcknowledgeAlarm doesn't remove

### L4 — System
- **Given**: Cockpit API endpoint `/api/cockpit/nodes`
- **When**: Wisp route hit
- **Then**: Returns JSON with 6 mesh nodes (zenoh-router-1/2/3, db-prod, obs-prod, cortex), each with cpu/memory
- **Runtime**: O(1) stub; production O(n) node polling
- **Verification**: Integration test — cockpit_api JSON encoding

### L5 — Cognitive
- **Given**: Model with mixed node statuses
- **When**: `SetViewMode(Detail)` → `SelectNode("zenoh-router-1")`
- **Then**: View mode changed, selected_node = Some("zenoh-router-1")
- **Runtime**: O(1) per update
- **Verification**: Unit test — view mode + node selection

### L6 — Ecosystem
- **Given**: Cockpit monitoring Zenoh mesh nodes
- **When**: Node cpu exceeds threshold → alarm generated
- **Then**: Alarm appears in `alarms` list with correct node_id, level, message
- **Runtime**: O(1) alarm creation + O(n) list prepend
- **Verification**: Integration test — node health → alarm pipeline

### L7 — Federation
- **Given**: Cockpit instances on multiple federation peers
- **When**: Peer A acknowledges alarm → broadcast to federation
- **Then**: Peer B shows alarm as acknowledged (cross-peer alarm sync)
- **Runtime**: O(n) alarm sync + O(1) local update
- **Verification**: E2E test — federated alarm acknowledgment

---

## 7. VERIFICATION (L0 Constitutional)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `VerificationModel(last_report: None, running: False, history: [], latest_proof: None, graph_checks: [], dag_node_count: 0, dag_edge_count: 0, proof_history: [])`
- **Invariant**: No verification run = no proof = safe default
- **Runtime**: O(1)
- **Verification**: Unit test — init returns clean verification state

### L1 — Atomic
- **Given**: SwarmReport with healthy=8, total=10
- **When**: `compliance_percent(report)` called
- **Then**: Returns 80.0
- **Runtime**: O(1) arithmetic
- **Verification**: Unit test — compliance calculation (including divide-by-zero guard)

### L2 — Component
- **Given**: Model with empty graph_checks
- **When**: `GraphChecksCompleted([check1, check2])`
- **Then**: `all_checks_passed(model)` returns True only if both checks.passed
- **Runtime**: O(n) list.all
- **Verification**: Unit test — all_checks_passed with mixed pass/fail

### L3 — Transaction
- **Given**: Model with running=False
- **When**: `StartVerification` → `ReportReceived(report)` → `ProofGenerated(proof)`
- **Then**: running=False (reset), last_report=Some(report), latest_proof=Some(proof), history has 1 entry
- **Runtime**: O(1) per step; history prepend O(1)
- **Verification**: Unit test — full verification run lifecycle

### L4 — System
- **Given**: Verification API endpoint `/api/v1/verification`
- **When**: Wisp route hit
- **Then**: Returns JSON with SIL-6, 266 tests, 100% compliance, 900 MSTS directives, 8 fractal layers
- **Runtime**: O(1) stub; production O(n) test suite execution
- **Verification**: Integration test — verification_api JSON structure

### L5 — Cognitive
- **Given**: Model with proof token carrying `result: Verified`
- **When**: `latest_proof_verified(model)` called
- **Then**: Returns True; with Rejected(_) → False; with Inconclusive → False
- **Runtime**: O(1) pattern match
- **Verification**: Unit test — proof result interpretation

### L6 — Ecosystem
- **Given**: Verification DAG with nodes and edges
- **When**: `DagUpdated(15, 30)` → `GraphChecksCompleted(checks)`
- **Then**: dag_node_count=15, dag_edge_count=30, graph_checks populated
- **Runtime**: O(1) update + O(n) checks
- **Verification**: Integration test — DAG topology + graph check pipeline

### L7 — Federation
- **Given**: Verification running across federation peers
- **When**: Peer A generates proof token → Peer B validates
- **Then**: Both peers have consistent proof_history; cross-verification passes
- **Runtime**: O(n) proof sync + O(1) local validation
- **Verification**: E2E test — federated proof token validation

---

## 8. SUBSTRATE (L3 Transaction)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `SubstrateModel(governor_action: None, db_connections: [], file_ops: [])`
- **Invariant**: No governor action = maintain state; no DB connections = safe
- **Runtime**: O(1)
- **Verification**: Unit test — init returns safe substrate state

### L1 — Atomic
- **Given**: Model with 3 DB connections (2 active, 1 idle)
- **When**: `active_connections(model)` called
- **Then**: Returns 2 connections with status == "active"
- **Runtime**: O(n) filter
- **Verification**: Unit test — active connection filtering

### L2 — Component
- **Given**: Model with no governor action
- **When**: `GovernorUpdated(GovernorAction("ScaleUp", "executing", 1000))`
- **Then**: governor_action = Some(action with correct fields)
- **Runtime**: O(1) option wrap
- **Verification**: Unit test — governor action update

### L3 — Transaction
- **Given**: Model with 2 DB connections
- **When**: `DbStatsReceived([new_conns])` → `GovernorUpdated(action)`
- **Then**: DB connections replaced, governor action set
- **Runtime**: O(n) replace + O(1) update
- **Verification**: Unit test — DB stats + governor update sequence

### L4 — System
- **Given**: Substrate API endpoint `/api/v1/substrate`
- **When**: Wisp route hit
- **Then**: Returns JSON with governor_action="Maintain", resource_metrics, db_type="SQLite", fs_status="nominal", wal_mode=True
- **Runtime**: O(1) stub; production O(n) resource polling
- **Verification**: Integration test — substrate_api JSON structure

### L5 — Cognitive
- **Given**: Governor action = EmergencyHalt
- **When**: Substrate health check
- **Then**: System recognizes critical state; no further mutations permitted
- **Runtime**: O(1) status check
- **Verification**: Unit test — EmergencyHalt blocks mutations

### L6 — Ecosystem
- **Given**: Substrate monitoring multiple DB connections
- **When**: Connection latency spikes → governor triggers Contract action
- **Then**: GovernorAction updated, resource_metrics reflect new state
- **Runtime**: O(1) governor decision + O(n) metrics update
- **Verification**: Integration test — governor auto-response to latency

### L7 — Federation
- **Given**: Substrate across federation peers with shared DB
- **When**: Peer A executes governor action → broadcast
- **Then**: Peer B acknowledges, applies consistent governor policy
- **Runtime**: O(1) broadcast + O(n) peer sync
- **Verification**: E2E test — federated governor coordination

---

## 9. METABOLIC (L1 Atomic Debug)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `MetabolicModel(set_point: 0.5, energy: 1.0, cpu_load: 0.0, health: Healthy)`
- **Invariant**: Energy > set_point on startup = healthy baseline
- **Runtime**: O(1)
- **Verification**: Unit test — init returns healthy metabolic state

### L1 — Atomic
- **Given**: Model with cpu_load = 0.95
- **When**: `is_overloaded(model)` called
- **Then**: Returns True; with cpu_load = 0.8 → False
- **Runtime**: O(1) float comparison
- **Verification**: Unit test — overload threshold (0.9)

### L2 — Component
- **Given**: Model with set_point = 0.5, energy = 1.0
- **When**: `energy_ratio(model)` called
- **Then**: Returns 2.0 (1.0 / 0.5)
- **Runtime**: O(1) division
- **Verification**: Unit test — energy ratio calculation (including zero set_point guard)

### L3 — Transaction
- **Given**: Model with initial values
- **When**: `SetPointUpdated(0.8)` → `EnergyChanged(0.6)` → `HealthChanged(Degraded("low energy"))`
- **Then**: set_point=0.8, energy=0.6, health=Degraded, energy_ratio = 0.75
- **Runtime**: O(1) per update
- **Verification**: Unit test — multi-parameter metabolic transition

### L4 — System
- **Given**: Metabolic API endpoint `/api/v1/metabolic`
- **When**: Wisp route hit
- **Then**: Returns JSON with set_point=80.0, energy=100.0, cpu_load=32.5, health_status="Healthy", tps=1250.0
- **Runtime**: O(1) stub; production O(n) sensor polling
- **Verification**: Integration test — metabolic_api JSON encoding

### L5 — Cognitive
- **Given**: Model with cpu_load approaching 0.9
- **When**: CPU load crosses 0.9 threshold
- **Then**: `is_overloaded` flips to True; health should transition to Degraded
- **Runtime**: O(1) threshold check
- **Verification**: Unit test — overload detection triggers health change

### L6 — Ecosystem
- **Given**: Metabolic monitoring via Zenoh telemetry
- **When**: Zenoh publishes cpu_load update → `EnergyChanged(new_value)`
- **Then**: Model updated, energy_ratio recalculated
- **Runtime**: O(1) update + O(1) ratio calc
- **Verification**: Integration test — Zenoh → Metabolic telemetry pipeline

### L7 — Federation
- **Given**: Metabolic state across federation peers
- **When**: Peer A detects overload → broadcasts to federation
- **Then**: Peer B adjusts set_point to balance load (federated load balancing)
- **Runtime**: O(1) broadcast + O(1) local adjustment
- **Verification**: E2E test — federated metabolic load balancing

---

## 10. PODMAN (L4 System)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `PodmanModel(containers: [], images: [], volumes: [], networks: [])`
- **Invariant**: Empty container state = no running processes = safe
- **Runtime**: O(1)
- **Verification**: Unit test — init returns empty PodmanModel

### L1 — Atomic
- **Given**: Model with 3 containers (2 running, 1 exited)
- **When**: `running_containers(model)` called
- **Then**: Returns 2 containers with status == "running"
- **Runtime**: O(n) filter
- **Verification**: Unit test — running container filtering

### L2 — Component
- **Given**: Model with empty containers
- **When**: `ContainersLoaded([c1, c2])` → `ImagesLoaded([img1])`
- **Then**: containers = [c1, c2], images = [img1]
- **Runtime**: O(1) replace each
- **Verification**: Unit test — container and image loading

### L3 — Transaction
- **Given**: Model with 2 running containers
- **When**: `StartContainer("new")` → `StopContainer("c1")` → `RefreshPodman`
- **Then**: StartContainer and StopContainer are currently no-ops (gaps); RefreshPodman is no-op
- **Runtime**: O(1) no-ops; **GAP**: No actual container lifecycle management
- **Verification**: Unit test — **GAP IDENTIFIED**: Start/Stop/Refresh are all no-ops

### L4 — System
- **Given**: Podman API endpoint `/api/v1/podman`
- **When**: Wisp route hit
- **Then**: Returns JSON with 5 containers (zenoh-router-1/2/3, db-prod, obs-prod), system_info, disk_usage
- **Runtime**: O(1) stub; production O(n) Podman API call
- **Verification**: Integration test — podman_api JSON structure

### L5 — Cognitive
- **Given**: Model with containers in various states
- **When**: Container count changes between refreshes
- **Then**: Model reflects new state; discrepancy detection needed
- **Runtime**: O(n) diff
- **Verification**: Integration test — container state drift detection

### L6 — Ecosystem
- **Given**: Podman managing mesh containers (zenoh, db, obs)
- **When**: Container crashes → Podman detects exited state
- **Then**: Container status changes to "exited", TUI shows red badge
- **Runtime**: O(n) status poll + O(1) update
- **Verification**: Integration test — container crash detection

### L7 — Federation
- **Given**: Podman across federation peers
- **When**: Peer A starts container → federation sync
- **Then**: Peer B aware of new container; container registry consistent
- **Runtime**: O(n) container sync + O(1) local update
- **Verification**: E2E test — federated container registry

---

## 11. MCP (L6 Ecosystem)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `McpModel(tools: [], active_sessions: [], server_status: Stopped)`
- **Invariant**: Stopped by default; no tools or sessions until explicitly loaded
- **Runtime**: O(1)
- **Verification**: Unit test — init returns safe stopped state

### L1 — Atomic
- **Given**: Model with 3 tools (2 enabled, 1 disabled)
- **When**: `enabled_tools(model)` called
- **Then**: Returns 2 tools with enabled == True
- **Runtime**: O(n) filter
- **Verification**: Unit test — enabled tool filtering

### L2 — Component
- **Given**: Model with empty sessions
- **When**: `SessionStarted(session1)` → `SessionStarted(session2)` → `SessionEnded(session1.id)`
- **Then**: active_sessions = [session2]
- **Runtime**: O(1) prepend + O(n) filter on end
- **Verification**: Unit test — session lifecycle

### L3 — Transaction
- **Given**: Model with Stopped server
- **When**: `ToolsLoaded([tool1, tool2])` → `SessionStarted(s1)` → `RefreshMcp`
- **Then**: Tools loaded, session active; RefreshMcp is no-op (gap)
- **Runtime**: O(1) per step; **GAP**: RefreshMcp doesn't reload
- **Verification**: Unit test — tool load + session start sequence

### L4 — System
- **Given**: MCP API endpoint `/api/v1/mcp`
- **When**: Wisp route hit
- **Then**: Returns JSON with server_status="running", 5 tools (planning_query, knowledge_search, verification_run, read_file, todo_status), 2 active sessions
- **Runtime**: O(1) stub; production O(n) MCP server query
- **Verification**: Integration test — mcp_api JSON structure

### L5 — Cognitive
- **Given**: MCP server with Errored(reason) status
- **When**: Error detected → TUI renders "ERROR: {reason}" in red
- **Then**: Operator can see error reason and session count
- **Runtime**: O(1) status check + O(n) tool render
- **Verification**: Unit test — error state rendering

### L6 — Ecosystem
- **Given**: MCP tools connected to Zenoh mesh
- **When**: Tool invoked → Zenoh message published
- **Then**: Tool execution tracked, session updated
- **Runtime**: O(1) tool dispatch + O(n) session update
- **Verification**: Integration test — MCP tool → Zenoh pipeline

### L7 — Federation
- **Given**: MCP servers across federation peers
- **When**: Peer A registers new tool → federation broadcast
- **Then**: Peer B discovers tool, adds to available tools list
- **Runtime**: O(n) tool sync + O(1) local registration
- **Verification**: E2E test — federated MCP tool discovery

---

## 12. KMS (L0 Constitutional)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `KmsModel(checkpoints: [], total_keys: 0, active_keys: 0)`
- **Invariant**: Zero keys = no cryptographic material exposed = safe
- **Runtime**: O(1)
- **Verification**: Unit test — init returns safe empty KMS state

### L1 — Atomic
- **Given**: Model with 3 checkpoints
- **When**: `latest_checkpoint(model)` called
- **Then**: Returns Ok(first checkpoint); with empty list → Error(Nil)
- **Runtime**: O(1) list.first
- **Verification**: Unit test — latest_checkpoint with/without checkpoints

### L2 — Component
- **Given**: Model with empty checkpoints
- **When**: `CheckpointsLoaded([cp1, cp2, cp3])`
- **Then**: checkpoints = [cp1, cp2, cp3], checkpoint_count = 3
- **Runtime**: O(1) replace + O(1) length
- **Verification**: Unit test — checkpoint loading

### L3 — Transaction
- **Given**: Model with 2 checkpoints, total_keys=5, active_keys=4
- **When**: `KeyRotated("key-001")` → `RefreshKms`
- **Then**: KeyRotated is currently no-op (gap); RefreshKms is no-op (gap)
- **Runtime**: O(1) no-ops; **GAP IDENTIFIED**: KeyRotated doesn't update state
- **Verification**: Unit test — **GAP**: Key rotation not implemented

### L4 — System
- **Given**: KMS API endpoint `/api/v1/kms`
- **When**: Wisp route hit
- **Then**: Returns JSON with total_keys=12, active_keys=10, 4 checkpoints with rotation policies
- **Runtime**: O(1) stub; production O(n) KMS query
- **Verification**: Integration test — kms_api JSON encoding

### L5 — Cognitive
- **Given**: Model with checkpoints having rotation policies (30d, 90d, 180d)
- **When**: Checkpoint age exceeds rotation policy
- **Then**: Key should be flagged for rotation (current implementation doesn't — gap)
- **Runtime**: O(n) age check
- **Verification**: Integration test — rotation policy enforcement

### L6 — Ecosystem
- **Given**: KMS integrated with Zenoh mesh for key distribution
- **When**: New key generated → distributed via Zenoh
- **Then**: Checkpoint created, total_keys incremented
- **Runtime**: O(1) key gen + O(n) checkpoint update
- **Verification**: Integration test — Zenoh → KMS key distribution

### L7 — Federation
- **Given**: KMS across federation peers with shared key catalog
- **When**: Peer A rotates key → version vector incremented
- **Then**: Peer B receives rotated key, updates checkpoint
- **Runtime**: O(n) key sync + O(1) checkpoint update
- **Verification**: E2E test — federated key rotation

---

## 13. TELEMETRY (L1 Atomic Debug)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `TelemetryModel(spans: [], metrics: [], log_level: Info, active_traces: 0)`
- **Invariant**: Info log level by default = balanced visibility
- **Runtime**: O(1)
- **Verification**: Unit test — init returns correct TelemetryModel

### L1 — Atomic
- **Given**: Model with log_level = Warning
- **When**: `log_level_to_string(Warning)` called
- **Then**: Returns "WARNING"; Debug→"DEBUG", Info→"INFO", Error→"ERROR"
- **Runtime**: O(1) pattern match
- **Verification**: Unit test — all 4 log level string conversions

### L2 — Component
- **Given**: Model with empty spans
- **When**: `SpanReceived(span1)` → `SpanReceived(span2)`
- **Then**: spans = [span2, span1] (LIFO order)
- **Runtime**: O(1) prepend each
- **Verification**: Unit test — span accumulation order

### L3 — Transaction
- **Given**: Model with 2 spans, 1 metric
- **When**: `MetricUpdated(metric2)` → `SetLogLevel(Error)` → `RefreshTelemetry`
- **Then**: metrics = [metric2, metric1], log_level = Error; RefreshTelemetry is no-op
- **Runtime**: O(1) per step; **GAP**: RefreshTelemetry doesn't reload
- **Verification**: Unit test — metric update + log level change

### L4 — System
- **Given**: Telemetry API endpoint `/api/v1/telemetry`
- **When**: Wisp route hit
- **Then**: Returns JSON with active_traces=8, total_spans=1247, metrics (cpu, memory, network), log_level="info"
- **Runtime**: O(1) stub; production O(n) OTel collector query
- **Verification**: Integration test — telemetry_api JSON structure

### L5 — Cognitive
- **Given**: Model with spans of varying durations
- **When**: `recent_spans(model, 5)` called
- **Then**: Returns first 5 spans (most recent, since LIFO)
- **Runtime**: O(k) where k = requested count
- **Verification**: Unit test — recent spans pagination

### L6 — Ecosystem
- **Given**: Telemetry pipeline from Zenoh → OTel collector → UI
- **When**: Span received via Zenoh → `SpanReceived(span)`
- **Then**: Span appears in model, TUI renders with status-colored badge
- **Runtime**: O(1) span receipt + O(n) render
- **Verification**: Integration test — Zenoh → Telemetry span pipeline

### L7 — Federation
- **Given**: Telemetry across federation peers
- **When**: Peer A generates span → federated trace
- **Then**: Peer B receives span with matching trace_id, reconstructs distributed trace
- **Runtime**: O(n) trace reconstruction
- **Verification**: E2E test — federated distributed tracing

---

## 14. FEDERATION (L7 Federation)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `FederationModel(state: None, loading: False, error: None)`
- **Invariant**: No state loaded = no federation activity = safe default
- **Runtime**: O(1)
- **Verification**: Unit test — init returns empty federation state

### L1 — Atomic
- **Given**: Model with state containing 3 peers (2 connected, 1 suspected)
- **When**: `connected_count(model)` called
- **Then**: Returns 2; `total_peer_count(model)` returns 3
- **Runtime**: O(n) peer count via list_length
- **Verification**: Unit test — peer counting functions

### L2 — Component
- **Given**: Model with state containing 2 attested peers
- **When**: `all_attested_check(model)` called
- **Then**: Returns True; with 1 unattested → False
- **Runtime**: O(n) all_attested check
- **Verification**: Unit test — attestation check

### L3 — Transaction
- **Given**: Model with state containing 1 peer
- **When**: `PeerAdded(peer2)` → `VersionIncremented` → `PeerRemoved(peer1.id)`
- **Then**: State has peer2 only, version incremented twice
- **Runtime**: O(1) add + O(1) increment + O(n) remove
- **Verification**: Unit test — full peer lifecycle

### L4 — System
- **Given**: Federation API endpoint `/api/v1/federation`
- **When**: Wisp route hit
- **Then**: Returns JSON with sample state (3 peers: indrajaal-ex-app-2, indrajaal-ex-app-3, indrajaal-chaya), version vectors, attestation status
- **Runtime**: O(1) sample state generation
- **Verification**: Integration test — federation_api JSON structure

### L5 — Cognitive
- **Given**: Model with error state
- **When**: `ErrorReceived("connection timeout")` → `RefreshFederation`
- **Then**: Error set, loading=True on refresh
- **Runtime**: O(1) per update
- **Verification**: Unit test — error handling and retry

### L6 — Ecosystem
- **Given**: Federation with 3 peers across mesh
- **When**: Peer status changes (Connected → Suspected → Disconnected)
- **Then**: TUI renders status with correct colors (green → yellow → red)
- **Runtime**: O(n) peer render + O(1) status color lookup
- **Verification**: Integration test — peer status visualization

### L7 — Federation
- **Given**: Federation state with version vectors
- **When**: Local version incremented → state serialized → sent to peer
- **Then**: Peer receives state, merges version vectors, detects conflicts
- **Runtime**: O(n + m) version vector merge
- **Verification**: E2E test — version vector conflict resolution

---

## 15. HEALTHGRID (L4 System)

### L0 — Constitutional
- **Given**: `init()` called
- **Then**: `HealthGridModel(devices: [], selected_id: None, filter: AllDevices)`
- **Invariant**: Empty device list = no devices to monitor = safe
- **Runtime**: O(1)
- **Verification**: Unit test — init returns empty HealthGridModel

### L1 — Atomic
- **Given**: DeviceHealth with health_score = 0.95
- **When**: Health grid cell rendered
- **Then**: Color class = "healthy" (>0.8); 0.6 → "degraded" (0.5-0.8); 0.4 → "critical" (<=0.5)
- **Runtime**: O(1) float comparison
- **Verification**: Unit test — health score thresholds

### L2 — Component
- **Given**: Model with 5 devices (3 healthy, 1 degraded, 1 critical)
- **When**: `SetFilter(HealthyOnly)`
- **Then**: Grid shows only devices with health_score > 0.8
- **Runtime**: O(n) filter
- **Verification**: Unit test — all 4 filter variants

### L3 — Transaction
- **Given**: Model with 5 devices
- **When**: `DevicesLoaded(new_devices)` → `SelectDevice("cam-001")` → `SetFilter(CriticalOnly)`
- **Then**: Devices replaced, device selected, filter shows critical only
- **Runtime**: O(1) replace + O(1) select + O(n) filter
- **Verification**: Unit test — device load + select + filter chain

### L4 — System
- **Given**: Health API endpoint
- **When**: Wisp route hit (via `health_api.mock_devices()`)
- **Then**: Returns JSON with 5 devices (cam-001/002, reader-001, panel-001, sensor-001) with health scores
- **Runtime**: O(1) mock data
- **Verification**: Integration test — health_api JSON encoding

### L5 — Cognitive
- **Given**: Model with selected device
- **When**: Device selected → details panel rendered
- **Then**: Shows device id, type, status, health score, last_seen
- **Runtime**: O(n) find + O(1) render
- **Verification**: Unit test — device detail rendering

### L6 — Ecosystem
- **Given**: Health grid receiving device data via Zenoh
- **When**: Device goes offline → health_score drops
- **Then**: Cell color changes from green to red, summary counts updated
- **Runtime**: O(1) update + O(n) re-render
- **Verification**: Integration test — Zenoh → HealthGrid device status

### L7 — Federation
- **Given**: Health grids on multiple federation peers
- **When**: Peer A reports device health → broadcast
- **Then**: Peer B merges device data, shows unified health view
- **Runtime**: O(n + m) device merge
- **Verification**: E2E test — federated device health aggregation

---

## Coverage Gap Summary

| Gap ID | Tab | Level | Description | Severity |
|--------|-----|-------|-------------|----------|
| GAP-001 | Immune | L3 | `AttackResolved` is no-op — doesn't remove attack from list | HIGH |
| GAP-002 | Cockpit | L3 | `AcknowledgeAlarm` is no-op — doesn't remove alarm | HIGH |
| GAP-003 | Planning | L5 | `RefreshTasks` is no-op — no backend fetch | MEDIUM |
| GAP-004 | Podman | L3 | `StartContainer`, `StopContainer`, `RefreshPodman` all no-ops | HIGH |
| GAP-005 | Kms | L3 | `KeyRotated` and `RefreshKms` are no-ops | HIGH |
| GAP-006 | Telemetry | L3 | `RefreshTelemetry` is no-op | MEDIUM |
| GAP-007 | Immune | L5 | Mara auto-response doesn't generate antibodies | MEDIUM |
| GAP-008 | Kms | L5 | Rotation policy enforcement not implemented | MEDIUM |
| GAP-009 | All tabs | L6-L7 | No actual Zenoh integration in Lustre update functions | HIGH |
| GAP-010 | All tabs | L4 | Wisp endpoints return stub data, not live backend data | MEDIUM |

## Test Generation Priority

| Priority | Tabs | Rationale |
|----------|------|-----------|
| P0 | Immune, Verification, Kms | L0 Constitutional — safety-critical invariants |
| P1 | Federation, Zenoh, Cockpit | L6/L7 — mesh integrity and situational awareness |
| P2 | Podman, Metabolic, HealthGrid | L4 System — infrastructure health |
| P3 | Planning, Substrate, Knowledge | L3/L5 — operational workflow |
| P4 | Mcp, Telemetry, Dashboard | L6/L5 — auxiliary monitoring |

## KPI Definitions Per Tab

| Tab | KPI | Target | Measurement |
|-----|-----|--------|-------------|
| Dashboard | Init correctness | 100% | Unit test pass rate |
| Dashboard | Health class accuracy | 100% | Pattern match coverage |
| Planning | Filter accuracy | 100% | filtered_tasks correctness |
| Planning | Task count accuracy | 100% | task_count_by_status |
| Immune | Threat level thresholds | 100% | 0→nominal, 1-2→elevated, 3+→critical |
| Immune | Attack resolution | 0% → 100% | GAP-001 fix |
| Knowledge | Node filtering | 100% | filtered_nodes + level filter |
| Knowledge | Graph integrity | 100% | nodes/links consistency |
| Zenoh | Connection detection | 100% | is_connected accuracy |
| Zenoh | Subscription lifecycle | 100% | add/remove correctness |
| Cockpit | Dark cockpit filtering | 100% | visible_nodes accuracy |
| Cockpit | Alarm severity sort | 100% | active_alarms order |
| Verification | Compliance calculation | 100% | compliance_percent accuracy |
| Verification | Proof validation | 100% | latest_proof_verified |
| Substrate | Active connection count | 100% | active_connections accuracy |
| Metabolic | Overload detection | 100% | is_overloaded at 0.9 threshold |
| Metabolic | Energy ratio | 100% | energy_ratio with zero guard |
| Podman | Running container count | 100% | running_count accuracy |
| Mcp | Session lifecycle | 100% | start/end correctness |
| Kms | Latest checkpoint | 100% | latest_checkpoint with empty guard |
| Telemetry | Log level mapping | 100% | log_level_to_string |
| Telemetry | Recent spans | 100% | recent_spans pagination |
| Federation | Peer counting | 100% | connected_count, total_peer_count |
| Federation | Attestation check | 100% | all_attested_check |
| HealthGrid | Health score thresholds | 100% | >0.8, 0.5-0.8, <=0.5 |
| HealthGrid | Filter accuracy | 100% | All 4 DeviceFilter variants |
