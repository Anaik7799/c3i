//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/lustre/planning_dashboard</module>
////     <fsharp-lineage>Cepaf.UI.Bolero.PlanningDashboard</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L3_TRANSACTION</layer>
////     <mesh-domain>Planning 8-Panel SIL-6 Cockpit</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009, SC-AGUI-001, SC-AGUI-011, SC-AGUI-014, SC-A2UI-001</stamp-controls>
////   </compliance>
//// </c3i-module>
////
//// Planning Dashboard - 8-Panel SIL-6 Agentic Cockpit Model
//// AG-UI protocol integration: events drive all 8 panels via SSE/WebSocket.
//// A2UI generative slots: agents can propose dynamic widgets per panel.
//// Lustre server component: OTP-supervised, WebSocket DOM patches to browser.
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009, SC-AGUI-001..017, SC-A2UI-001..005
////
//// ## Human-Specified Intent
//// <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
//// <!-- END HUMAN-ONLY -->

import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}

// =============================================================================
// Type Definitions — 8-Panel Dashboard
// =============================================================================

pub type CockpitMode {
  Dark
  Dim
  Normal
  Bright
  EmergencyMode
}

pub type PanelId {
  TaskBoard
  OodaCycle
  SafetyKernel
  EnforcerShield
  GraphVerify
  OrchMesh
  ChayaTwin
  StartupOptim
}

pub type TaskCard {
  TaskCard(
    id: String,
    title: String,
    status: String,
    priority: String,
    assignee: Option(String),
  )
}

pub type OodaPhase {
  ObservePhase
  OrientPhase
  DecidePhase
  ActPhase
  Idle
}

pub type SafetyCheckResult {
  CheckPass(name: String)
  CheckFail(name: String, reason: String)
  CheckWarn(name: String)
  CheckNotRun(name: String)
}

pub type ServiceNode {
  ServiceNode(name: String, status: String, health: Float)
}

pub type SyncPhaseResult {
  SyncPhaseResult(phase: String, success: Bool, count: Int, errors: Int)
}

pub type ContainerWave {
  ContainerWave(wave: Int, containers: List(String), duration_ms: Int)
}

pub type ChatMessage {
  UserMsg(text: String)
  AgentMsg(text: String)
  ToolCallMsg(tool: String, args: String)
  EventMsg(event_type: String, data: String)
}

pub type DashboardModel {
  DashboardModel(
    // Panel 1: Tasks
    tasks: List(TaskCard),
    task_filter: String,
    selected_task: Option(String),
    // Panel 2: OODA
    ooda_phase: OodaPhase,
    ooda_cycle_count: Int,
    last_cycle_ms: Int,
    ooda_pattern: String,
    ooda_decision: String,
    // Panel 3: Safety
    safety_active: Bool,
    threat_level: Float,
    guardian_healthy: Bool,
    safety_checks: List(SafetyCheckResult),
    quarantined: List(String),
    // Panel 4: Enforcer
    total_violations: Int,
    open_circuits: List(String),
    recent_violations: List(String),
    // Panel 5: Graph
    graph_node_count: Int,
    graph_edge_count: Int,
    graph_checks: List(SafetyCheckResult),
    graph_dot: String,
    // Panel 6: Orchestration
    services: List(ServiceNode),
    quorum: Bool,
    distribution_strategy: String,
    // Panel 7: Chaya
    sync_phases: List(SyncPhaseResult),
    orphan_count: Int,
    mismatch_count: Int,
    last_sync: String,
    // Panel 8: Startup
    waves: List(ContainerWave),
    critical_path: List(String),
    total_startup_ms: Int,
    // UI state
    active_panel: PanelId,
    cockpit_mode: CockpitMode,
    ag_ui_connected: Bool,
    chat_messages: List(ChatMessage),
  )
}

pub type DashboardMsg {
  // Task messages
  SetTaskFilter(String)
  SelectTask(String)
  TasksLoaded(List(TaskCard))
  TaskStatusChanged(String, String)
  // OODA messages
  OodaPhaseChanged(OodaPhase)
  OodaCycleCompleted(Int, String, String)
  // Safety messages
  SafetyChecksLoaded(List(SafetyCheckResult))
  ThreatLevelChanged(Float)
  AgentQuarantined(String)
  // Enforcer messages
  ViolationRecorded(String)
  CircuitOpened(String)
  CircuitClosed(String)
  // Graph messages
  GraphLoaded(Int, Int, String)
  GraphChecksRan(List(SafetyCheckResult))
  // Orchestration messages
  ServicesUpdated(List(ServiceNode))
  QuorumChanged(Bool)
  SetDistributionStrategy(String)
  // Chaya messages
  SyncStarted
  SyncPhaseCompleted(SyncPhaseResult)
  SyncFinished(Int, Int)
  // Startup messages
  WavesComputed(List(ContainerWave))
  CriticalPathFound(List(String), Int)
  // UI messages
  SetActivePanel(PanelId)
  CockpitModeChanged(CockpitMode)
  AgUiConnected(Bool)
  ChatMessageReceived(ChatMessage)
  RefreshAll
  // --- AG-UI Protocol Events (SC-AGUI-001) ---
  AgUiRunStarted(thread_id: String, run_id: String)
  AgUiRunFinished(thread_id: String, run_id: String)
  AgUiRunError(message: String, code: String)
  AgUiStepStarted(step_name: String)
  AgUiStepFinished(step_name: String)
  AgUiTextContent(message_id: String, delta: String)
  AgUiStateSnapshot(snapshot: json.Json)
  AgUiStateDelta(patches: json.Json)
  AgUiToolCallStart(tool_call_id: String, tool_name: String)
  AgUiToolCallEnd(tool_call_id: String)
  AgUiToolCallResult(tool_call_id: String, content: String)
  AgUiReasoningContent(message_id: String, delta: String)
  // --- HITL (Human-in-the-Loop) (SC-AGUI-004) ---
  HitlApprovalRequested(request_id: String, description: String)
  HitlUserApproved(request_id: String)
  HitlUserRejected(request_id: String)
  // --- A2UI Generative UI (SC-A2UI-001) ---
  A2uiComponentProposed(panel: PanelId, component_json: json.Json)
  // --- Drag-Drop Kanban (SC-HMI-010) ---
  DragTaskStarted(task_id: String)
  DragTaskOver(column: String)
  DragTaskDropped(task_id: String, new_status: String)
}

// =============================================================================
// Init — Dark cockpit, empty lists, nominal defaults
// =============================================================================

pub fn init() -> DashboardModel {
  DashboardModel(
    tasks: [],
    task_filter: "all",
    selected_task: None,
    ooda_phase: Idle,
    ooda_cycle_count: 0,
    last_cycle_ms: 0,
    ooda_pattern: "",
    ooda_decision: "",
    safety_active: True,
    threat_level: 0.0,
    guardian_healthy: True,
    safety_checks: [],
    quarantined: [],
    total_violations: 0,
    open_circuits: [],
    recent_violations: [],
    graph_node_count: 0,
    graph_edge_count: 0,
    graph_checks: [],
    graph_dot: "",
    services: [],
    quorum: False,
    distribution_strategy: "round_robin",
    sync_phases: [],
    orphan_count: 0,
    mismatch_count: 0,
    last_sync: "",
    waves: [],
    critical_path: [],
    total_startup_ms: 0,
    active_panel: TaskBoard,
    cockpit_mode: Dark,
    ag_ui_connected: False,
    chat_messages: [],
  )
}

// =============================================================================
// Update — Exhaustive pattern matching on all DashboardMsg variants
// =============================================================================

pub fn update(model: DashboardModel, msg: DashboardMsg) -> DashboardModel {
  case msg {
    // --- Task messages ---
    SetTaskFilter(filter) -> DashboardModel(..model, task_filter: filter)

    SelectTask(id) -> DashboardModel(..model, selected_task: Some(id))

    TasksLoaded(tasks) -> DashboardModel(..model, tasks: tasks)

    TaskStatusChanged(id, new_status) -> {
      let updated_tasks =
        list.map(model.tasks, fn(t: TaskCard) {
          case t.id == id {
            True -> TaskCard(..t, status: new_status)
            False -> t
          }
        })
      DashboardModel(..model, tasks: updated_tasks)
    }

    // --- OODA messages ---
    OodaPhaseChanged(phase) -> DashboardModel(..model, ooda_phase: phase)

    OodaCycleCompleted(cycle_ms, pattern, decision) ->
      DashboardModel(
        ..model,
        ooda_cycle_count: model.ooda_cycle_count + 1,
        last_cycle_ms: cycle_ms,
        ooda_pattern: pattern,
        ooda_decision: decision,
        ooda_phase: Idle,
      )

    // --- Safety messages ---
    SafetyChecksLoaded(checks) -> DashboardModel(..model, safety_checks: checks)

    ThreatLevelChanged(level) -> DashboardModel(..model, threat_level: level)

    AgentQuarantined(agent_id) ->
      DashboardModel(..model, quarantined: [agent_id, ..model.quarantined])

    // --- Enforcer messages ---
    ViolationRecorded(description) ->
      DashboardModel(
        ..model,
        total_violations: model.total_violations + 1,
        recent_violations: case list.length(model.recent_violations) >= 50 {
          True -> [description, ..list.take(model.recent_violations, 49)]
          False -> [description, ..model.recent_violations]
        },
      )

    CircuitOpened(agent_id) ->
      DashboardModel(
        ..model,
        open_circuits: case list.contains(model.open_circuits, agent_id) {
          True -> model.open_circuits
          False -> [agent_id, ..model.open_circuits]
        },
      )

    CircuitClosed(agent_id) ->
      DashboardModel(
        ..model,
        open_circuits: list.filter(model.open_circuits, fn(a) { a != agent_id }),
      )

    // --- Graph messages ---
    GraphLoaded(nodes, edges, dot) ->
      DashboardModel(
        ..model,
        graph_node_count: nodes,
        graph_edge_count: edges,
        graph_dot: dot,
      )

    GraphChecksRan(checks) -> DashboardModel(..model, graph_checks: checks)

    // --- Orchestration messages ---
    ServicesUpdated(services) -> DashboardModel(..model, services: services)

    QuorumChanged(q) -> DashboardModel(..model, quorum: q)

    SetDistributionStrategy(strategy) ->
      DashboardModel(..model, distribution_strategy: strategy)

    // --- Chaya messages ---
    SyncStarted -> DashboardModel(..model, sync_phases: [])

    SyncPhaseCompleted(phase_result) ->
      DashboardModel(
        ..model,
        sync_phases: list.append(model.sync_phases, [phase_result]),
      )

    SyncFinished(orphans, mismatches) ->
      DashboardModel(
        ..model,
        orphan_count: orphans,
        mismatch_count: mismatches,
        last_sync: "completed",
      )

    // --- Startup messages ---
    WavesComputed(waves) -> DashboardModel(..model, waves: waves)

    CriticalPathFound(path, total_ms) ->
      DashboardModel(..model, critical_path: path, total_startup_ms: total_ms)

    // --- UI messages ---
    SetActivePanel(panel) -> DashboardModel(..model, active_panel: panel)

    CockpitModeChanged(mode) -> DashboardModel(..model, cockpit_mode: mode)

    AgUiConnected(connected) ->
      DashboardModel(..model, ag_ui_connected: connected)

    ChatMessageReceived(chat_msg) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [chat_msg]),
      )

    RefreshAll -> model

    // --- AG-UI Protocol Event Handlers (SC-AGUI-001) ---
    AgUiRunStarted(_, run_id) ->
      DashboardModel(
        ..model,
        ag_ui_connected: True,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("RUN_STARTED", run_id),
        ]),
      )

    AgUiRunFinished(_, run_id) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("RUN_FINISHED", run_id),
        ]),
      )

    AgUiRunError(message, code) ->
      DashboardModel(
        ..model,
        cockpit_mode: Bright,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("RUN_ERROR", message <> " [" <> code <> "]"),
        ]),
      )

    AgUiStepStarted(step_name) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("STEP_STARTED", step_name),
        ]),
      )

    AgUiStepFinished(step_name) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("STEP_FINISHED", step_name),
        ]),
      )

    AgUiTextContent(_, delta) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          AgentMsg(delta),
        ]),
      )

    AgUiStateSnapshot(_snapshot) ->
      // Full state replacement — apply to dashboard
      // In production, deserialize snapshot JSON and rebuild model
      model

    AgUiStateDelta(_patches) ->
      // Incremental RFC 6902 patches — apply to model fields
      // In production, use agui/state.gleam patch operations
      model

    AgUiToolCallStart(tool_call_id, tool_name) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          ToolCallMsg(tool_name, tool_call_id),
        ]),
      )

    AgUiToolCallEnd(_) -> model

    AgUiToolCallResult(tool_call_id, content) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("TOOL_RESULT", tool_call_id <> ": " <> content),
        ]),
      )

    AgUiReasoningContent(_, delta) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("REASONING", delta),
        ]),
      )

    // --- HITL Handlers (SC-AGUI-004) ---
    HitlApprovalRequested(request_id, description) ->
      DashboardModel(
        ..model,
        cockpit_mode: Normal,
        chat_messages: list.append(model.chat_messages, [
          EventMsg("HITL_REQUEST", request_id <> ": " <> description),
        ]),
      )

    HitlUserApproved(request_id) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          UserMsg("Approved: " <> request_id),
        ]),
      )

    HitlUserRejected(request_id) ->
      DashboardModel(
        ..model,
        chat_messages: list.append(model.chat_messages, [
          UserMsg("Rejected: " <> request_id),
        ]),
      )

    // --- A2UI Generative UI (SC-A2UI-001) ---
    A2uiComponentProposed(_, _component_json) ->
      // Agent proposed a dynamic widget — render via A2UI catalog
      // In production, validate against catalog + render in target panel
      model

    // --- Drag-Drop Kanban ---
    DragTaskStarted(_task_id) -> model
    // Visual only — no model change on drag start
    DragTaskOver(_column) -> model
    // Visual only — highlight target column
    DragTaskDropped(task_id, new_status) -> {
      let updated_tasks =
        list.map(model.tasks, fn(t: TaskCard) {
          case t.id == task_id {
            True -> TaskCard(..t, status: new_status)
            False -> t
          }
        })
      DashboardModel(..model, tasks: updated_tasks)
    }
  }
}

// =============================================================================
// Health Score — Composite from safety + enforcer + services
// =============================================================================

pub fn health_score(model: DashboardModel) -> Float {
  // Safety component (0.0 to 1.0) — weight 40%
  let safety_score = case model.safety_active, model.guardian_healthy {
    True, True -> 1.0 -. float.min(model.threat_level, 1.0)
    True, False -> 0.3
    False, _ -> 0.0
  }

  // Enforcer component (0.0 to 1.0) — weight 30%
  let enforcer_score = case model.total_violations {
    0 -> 1.0
    n if n < 5 -> 0.7
    n if n < 20 -> 0.4
    _ -> 0.1
  }
  let circuit_count = list.length(model.open_circuits)
  let enforcer_circuit_penalty = case circuit_count {
    0 -> 0.0
    n if n < 3 -> 0.2
    _ -> 0.5
  }
  let enforcer_final =
    float.max(enforcer_score -. enforcer_circuit_penalty, 0.0)

  // Services component (0.0 to 1.0) — weight 30%
  let service_count = list.length(model.services)
  let services_score = case service_count {
    0 -> 0.5
    _ -> {
      let healthy_count =
        list.count(model.services, fn(s: ServiceNode) { s.health >=. 0.8 })
      int.to_float(healthy_count) /. int.to_float(service_count)
    }
  }

  // Weighted composite
  let composite =
    { safety_score *. 0.4 }
    +. { enforcer_final *. 0.3 }
    +. { services_score *. 0.3 }

  // Clamp to [0.0, 1.0]
  float.min(float.max(composite, 0.0), 1.0)
}

// =============================================================================
// Determine Cockpit Mode — Based on health score thresholds
// =============================================================================

pub fn determine_cockpit_mode(model: DashboardModel) -> CockpitMode {
  let score = health_score(model)
  case score >=. 0.9 {
    True -> Dark
    False ->
      case score >=. 0.7 {
        True -> Dim
        False ->
          case score >=. 0.5 {
            True -> Normal
            False ->
              case score >=. 0.3 {
                True -> Bright
                False -> EmergencyMode
              }
          }
      }
  }
}

// =============================================================================
// Task Queries
// =============================================================================

pub fn pending_tasks(model: DashboardModel) -> List(TaskCard) {
  list.filter(model.tasks, fn(t: TaskCard) { t.status == "pending" })
}

pub fn completed_tasks(model: DashboardModel) -> List(TaskCard) {
  list.filter(model.tasks, fn(t: TaskCard) { t.status == "completed" })
}

pub fn blocked_tasks(model: DashboardModel) -> List(TaskCard) {
  list.filter(model.tasks, fn(t: TaskCard) { t.status == "blocked" })
}

// =============================================================================
// Safety Queries
// =============================================================================

pub fn is_safe(model: DashboardModel) -> Bool {
  model.safety_active
  && model.guardian_healthy
  && model.threat_level <. 0.5
  && list.is_empty(model.quarantined)
}

pub fn all_checks_pass(model: DashboardModel) -> Bool {
  case list.is_empty(model.safety_checks) {
    True -> True
    False ->
      list.all(model.safety_checks, fn(c: SafetyCheckResult) {
        case c {
          CheckPass(_) -> True
          CheckFail(_, _) -> False
          CheckWarn(_) -> True
          CheckNotRun(_) -> True
        }
      })
  }
}

// =============================================================================
// JSON Serialization — Full dashboard state (SC-GLM-UI-003)
// =============================================================================

pub fn dashboard_to_json(model: DashboardModel) -> json.Json {
  json.object([
    // Panel 1: Tasks
    #("tasks", json.array(model.tasks, task_card_to_json)),
    #("task_filter", json.string(model.task_filter)),
    #("selected_task", case model.selected_task {
      Some(id) -> json.string(id)
      None -> json.null()
    }),
    // Panel 2: OODA
    #("ooda_phase", json.string(ooda_phase_to_string(model.ooda_phase))),
    #("ooda_cycle_count", json.int(model.ooda_cycle_count)),
    #("last_cycle_ms", json.int(model.last_cycle_ms)),
    #("ooda_pattern", json.string(model.ooda_pattern)),
    #("ooda_decision", json.string(model.ooda_decision)),
    // Panel 3: Safety
    #("safety_active", json.bool(model.safety_active)),
    #("threat_level", json.float(model.threat_level)),
    #("guardian_healthy", json.bool(model.guardian_healthy)),
    #(
      "safety_checks",
      json.array(model.safety_checks, safety_check_result_to_json),
    ),
    #("quarantined", json.array(model.quarantined, json.string)),
    // Panel 4: Enforcer
    #("total_violations", json.int(model.total_violations)),
    #("open_circuits", json.array(model.open_circuits, json.string)),
    #("recent_violations", json.array(model.recent_violations, json.string)),
    // Panel 5: Graph
    #("graph_node_count", json.int(model.graph_node_count)),
    #("graph_edge_count", json.int(model.graph_edge_count)),
    #(
      "graph_checks",
      json.array(model.graph_checks, safety_check_result_to_json),
    ),
    #("graph_dot", json.string(model.graph_dot)),
    // Panel 6: Orchestration
    #("services", json.array(model.services, service_node_to_json)),
    #("quorum", json.bool(model.quorum)),
    #("distribution_strategy", json.string(model.distribution_strategy)),
    // Panel 7: Chaya
    #("sync_phases", json.array(model.sync_phases, sync_phase_result_to_json)),
    #("orphan_count", json.int(model.orphan_count)),
    #("mismatch_count", json.int(model.mismatch_count)),
    #("last_sync", json.string(model.last_sync)),
    // Panel 8: Startup
    #("waves", json.array(model.waves, container_wave_to_json)),
    #("critical_path", json.array(model.critical_path, json.string)),
    #("total_startup_ms", json.int(model.total_startup_ms)),
    // UI state
    #("active_panel", json.string(panel_id_to_string(model.active_panel))),
    #("cockpit_mode", json.string(cockpit_mode_to_string(model.cockpit_mode))),
    #("ag_ui_connected", json.bool(model.ag_ui_connected)),
    #("chat_messages", json.array(model.chat_messages, chat_message_to_json)),
    // Computed
    #("health_score", json.float(health_score(model))),
    #("is_safe", json.bool(is_safe(model))),
    #("all_checks_pass", json.bool(all_checks_pass(model))),
    #("pending_count", json.int(list.length(pending_tasks(model)))),
    #("completed_count", json.int(list.length(completed_tasks(model)))),
    #("blocked_count", json.int(list.length(blocked_tasks(model)))),
  ])
}

// =============================================================================
// Internal JSON helpers
// =============================================================================

fn task_card_to_json(card: TaskCard) -> json.Json {
  json.object([
    #("id", json.string(card.id)),
    #("title", json.string(card.title)),
    #("status", json.string(card.status)),
    #("priority", json.string(card.priority)),
    #("assignee", case card.assignee {
      Some(a) -> json.string(a)
      None -> json.null()
    }),
  ])
}

fn service_node_to_json(node: ServiceNode) -> json.Json {
  json.object([
    #("name", json.string(node.name)),
    #("status", json.string(node.status)),
    #("health", json.float(node.health)),
  ])
}

fn sync_phase_result_to_json(phase: SyncPhaseResult) -> json.Json {
  json.object([
    #("phase", json.string(phase.phase)),
    #("success", json.bool(phase.success)),
    #("count", json.int(phase.count)),
    #("errors", json.int(phase.errors)),
  ])
}

fn container_wave_to_json(wave: ContainerWave) -> json.Json {
  json.object([
    #("wave", json.int(wave.wave)),
    #("containers", json.array(wave.containers, json.string)),
    #("duration_ms", json.int(wave.duration_ms)),
  ])
}

fn safety_check_result_to_json(check: SafetyCheckResult) -> json.Json {
  case check {
    CheckPass(name) ->
      json.object([
        #("status", json.string("pass")),
        #("name", json.string(name)),
      ])
    CheckFail(name, reason) ->
      json.object([
        #("status", json.string("fail")),
        #("name", json.string(name)),
        #("reason", json.string(reason)),
      ])
    CheckWarn(name) ->
      json.object([
        #("status", json.string("warn")),
        #("name", json.string(name)),
      ])
    CheckNotRun(name) ->
      json.object([
        #("status", json.string("not_run")),
        #("name", json.string(name)),
      ])
  }
}

fn chat_message_to_json(msg: ChatMessage) -> json.Json {
  case msg {
    UserMsg(text) ->
      json.object([
        #("type", json.string("user")),
        #("text", json.string(text)),
      ])
    AgentMsg(text) ->
      json.object([
        #("type", json.string("agent")),
        #("text", json.string(text)),
      ])
    ToolCallMsg(tool, args) ->
      json.object([
        #("type", json.string("tool_call")),
        #("tool", json.string(tool)),
        #("args", json.string(args)),
      ])
    EventMsg(event_type, data) ->
      json.object([
        #("type", json.string("event")),
        #("event_type", json.string(event_type)),
        #("data", json.string(data)),
      ])
  }
}

fn ooda_phase_to_string(phase: OodaPhase) -> String {
  case phase {
    ObservePhase -> "observe"
    OrientPhase -> "orient"
    DecidePhase -> "decide"
    ActPhase -> "act"
    Idle -> "idle"
  }
}

fn panel_id_to_string(panel: PanelId) -> String {
  case panel {
    TaskBoard -> "task_board"
    OodaCycle -> "ooda_cycle"
    SafetyKernel -> "safety_kernel"
    EnforcerShield -> "enforcer_shield"
    GraphVerify -> "graph_verify"
    OrchMesh -> "orch_mesh"
    ChayaTwin -> "chaya_twin"
    StartupOptim -> "startup_optim"
  }
}

fn cockpit_mode_to_string(mode: CockpitMode) -> String {
  case mode {
    Dark -> "dark"
    Dim -> "dim"
    Normal -> "normal"
    Bright -> "bright"
    EmergencyMode -> "emergency"
  }
}
