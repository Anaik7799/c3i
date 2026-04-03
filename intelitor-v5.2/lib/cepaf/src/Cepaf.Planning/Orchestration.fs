// =============================================================================
// Orchestration.fs - Unified Service Coordination Layer
// =============================================================================
// STAMP: SC-ORCH-001 to SC-ORCH-020
// AOR: AOR-ORCH-001 to AOR-ORCH-015
// Criticality: Level 5 (CRITICAL) - Central Nervous System
// =============================================================================
// Provides intelligent coordination between:
// - Cortex: AI/Cognitive processing (OpenRouter, LLM agents)
// - Prajna: C3I Command Cockpit (Guardian, Sentinel, control)
// - Smriti: Knowledge/Memory system (holons, history, learning)
// - CEPAF: Orchestration framework (containers, mesh, deployment)
// - Planning: Task management (PROJECT_TODOLIST.md via F# CLI)
// - Chaya: Digital Twin (standalone operation, mesh distribution)
// =============================================================================

namespace Cepaf.Planning

open System
open System.Collections.Generic

// =============================================================================
// SERVICE TYPES
// =============================================================================

/// Service identity
type ServiceId =
    | Cortex      // AI/Cognitive
    | Prajna      // C3I Cockpit
    | Smriti      // Knowledge/Memory
    | CEPAF       // Orchestration
    | Planning    // Task Management
    | Chaya       // Digital Twin
    | Guardian    // Safety Kernel

/// Service status
type ServiceStatus =
    | Online
    | Offline
    | Degraded
    | Starting
    | Stopping

/// Service health metrics
type ServiceHealth = {
    ServiceId: ServiceId
    Status: ServiceStatus
    LastHeartbeat: DateTime
    HealthScore: float  // 0.0 to 1.0
    ActiveConnections: int
    ErrorCount: int
    LatencyMs: float
}

/// Message priority for inter-service communication
type MessagePriority =
    | Critical   // Guardian, Emergency
    | High       // Task mutations, State changes
    | Normal     // Regular operations
    | Low        // Telemetry, Analytics

/// Inter-service message
type ServiceMessage = {
    Id: Guid
    Source: ServiceId
    Target: ServiceId
    Priority: MessagePriority
    Payload: string
    Timestamp: DateTime
    RequiresAck: bool
    CorrelationId: Guid option
}

/// Coordination event
type CoordinationEvent =
    | TaskCreated of taskId: string * title: string
    | TaskUpdated of taskId: string * field: string * newValue: string
    | TaskCompleted of taskId: string
    | ServiceRegistered of ServiceId
    | ServiceUnregistered of ServiceId
    | HealthCheckFailed of ServiceId * reason: string
    | GuardianAlert of level: string * message: string
    | OODACycleCompleted of duration: float
    | KnowledgeUpdated of holonId: string
    | MeshTopologyChanged of nodeCount: int

// =============================================================================
// SERVICE REGISTRY
// =============================================================================

module ServiceRegistry =

    let private services = Dictionary<ServiceId, ServiceHealth>()
    let private eventLog = ResizeArray<CoordinationEvent>()

    /// Register a service
    let register (serviceId: ServiceId) : unit =
        let health = {
            ServiceId = serviceId
            Status = Starting
            LastHeartbeat = DateTime.UtcNow
            HealthScore = 1.0
            ActiveConnections = 0
            ErrorCount = 0
            LatencyMs = 0.0
        }
        services.[serviceId] <- health
        eventLog.Add(ServiceRegistered serviceId)
        printfn "[Orchestration] Service registered: %A" serviceId

    /// Update service health
    let updateHealth (serviceId: ServiceId) (status: ServiceStatus) (healthScore: float) : unit =
        if services.ContainsKey(serviceId) then
            let current = services.[serviceId]
            let updated =
                { current with
                    Status = status
                    LastHeartbeat = DateTime.UtcNow
                    HealthScore = healthScore }
            services.[serviceId] <- updated

    /// Get service status
    let getStatus (serviceId: ServiceId) : ServiceStatus option =
        if services.ContainsKey(serviceId) then
            Some services.[serviceId].Status
        else
            None

    /// Get all services
    let getAllServices () : ServiceHealth list =
        services.Values |> Seq.toList

    /// Check if service is online
    let isOnline (serviceId: ServiceId) : bool =
        match getStatus serviceId with
        | Some Online -> true
        | _ -> false

    /// Get event log
    let getEventLog () : CoordinationEvent list =
        eventLog |> Seq.toList

    /// Add event to log
    let addEvent (event: CoordinationEvent) : unit =
        eventLog.Add(event)

// =============================================================================
// MESSAGE BUS
// =============================================================================

module MessageBus =

    let private messageQueue = ResizeArray<ServiceMessage>()
    let private subscribers = Dictionary<ServiceId, ServiceMessage -> unit>()

    /// Subscribe to messages
    let subscribe (serviceId: ServiceId) (handler: ServiceMessage -> unit) : unit =
        subscribers.[serviceId] <- handler
        printfn "[MessageBus] %A subscribed" serviceId

    /// Publish message
    let publish (message: ServiceMessage) : unit =
        messageQueue.Add(message)

        // Deliver to target if subscribed
        if subscribers.ContainsKey(message.Target) then
            subscribers.[message.Target] message

        // Log critical messages
        if message.Priority = Critical then
            printfn "[MessageBus] CRITICAL: %A -> %A: %s"
                message.Source message.Target message.Payload

    /// Create message
    let createMessage (source: ServiceId) (target: ServiceId) (priority: MessagePriority) (payload: string) : ServiceMessage =
        {
            Id = Guid.NewGuid()
            Source = source
            Target = target
            Priority = priority
            Payload = payload
            Timestamp = DateTime.UtcNow
            RequiresAck = priority = Critical
            CorrelationId = None
        }

    /// Get pending messages for service
    let getPendingMessages (serviceId: ServiceId) : ServiceMessage list =
        messageQueue
        |> Seq.filter (fun m -> m.Target = serviceId)
        |> Seq.toList

// =============================================================================
// COORDINATION PROTOCOLS
// =============================================================================

module Coordination =

    /// SC-ORCH-001: Task creation coordination
    /// When a task is created, notify all relevant services
    let coordinateTaskCreation (taskId: string) (title: string) (priority: string) : unit =
        // 1. Validate via Guardian (Prajna)
        let payload1 = sprintf """{"action":"validate_task","taskId":"%s","title":"%s"}""" taskId title
        let guardianMsg = MessageBus.createMessage Planning Prajna High payload1
        MessageBus.publish guardianMsg

        // 2. Store in knowledge graph (Smriti)
        let payload2 = sprintf """{"action":"store_task","taskId":"%s","title":"%s"}""" taskId title
        let smritiMsg = MessageBus.createMessage Planning Smriti Normal payload2
        MessageBus.publish smritiMsg

        // 3. Notify Digital Twin (Chaya)
        let payload3 = sprintf """{"action":"task_created","taskId":"%s","priority":"%s"}""" taskId priority
        let chayaMsg = MessageBus.createMessage Planning Chaya Normal payload3
        MessageBus.publish chayaMsg

        // 4. Log event
        ServiceRegistry.addEvent(TaskCreated(taskId, title))
        printfn "[Coordination] Task %s created and coordinated across services" taskId

    /// SC-ORCH-002: Task update coordination
    let coordinateTaskUpdate (taskId: string) (field: string) (newValue: string) : unit =
        // Notify Smriti for history
        let payload1 = sprintf """{"action":"update_history","taskId":"%s","field":"%s","value":"%s"}""" taskId field newValue
        let smritiMsg = MessageBus.createMessage Planning Smriti Normal payload1
        MessageBus.publish smritiMsg

        // Notify Chaya for state sync
        let payload2 = sprintf """{"action":"task_updated","taskId":"%s"}""" taskId
        let chayaMsg = MessageBus.createMessage Planning Chaya Normal payload2
        MessageBus.publish chayaMsg

        ServiceRegistry.addEvent(TaskUpdated(taskId, field, newValue))

    /// SC-ORCH-003: Task completion coordination
    let coordinateTaskCompletion (taskId: string) : unit =
        // 1. Record in Smriti (permanent history)
        let payload1 = sprintf """{"action":"record_completion","taskId":"%s","timestamp":"%s"}""" taskId (DateTime.UtcNow.ToString("o"))
        let smritiMsg = MessageBus.createMessage Planning Smriti High payload1
        MessageBus.publish smritiMsg

        // 2. Update Chaya metrics
        let payload2 = sprintf """{"action":"task_completed","taskId":"%s"}""" taskId
        let chayaMsg = MessageBus.createMessage Planning Chaya Normal payload2
        MessageBus.publish chayaMsg

        // 3. Notify Cortex for learning
        let payload3 = sprintf """{"action":"learn_completion","taskId":"%s"}""" taskId
        let cortexMsg = MessageBus.createMessage Planning Cortex Low payload3
        MessageBus.publish cortexMsg

        ServiceRegistry.addEvent(TaskCompleted taskId)
        printfn "[Coordination] Task %s completion coordinated" taskId

    /// SC-ORCH-004: OODA cycle coordination with Chaya
    let coordinateOODACycle () : float =
        let startTime = DateTime.UtcNow

        // Observe: Get current state from all services
        let services = ServiceRegistry.getAllServices()

        // Orient: Analyze state
        let healthyCount = services |> List.filter (fun s -> s.Status = Online) |> List.length
        let totalCount = services.Length

        // Decide: Determine actions based on health
        let actions =
            if float healthyCount / float totalCount < 0.5 then
                ["alert_degraded"; "scale_healthy"]
            else
                ["continue_normal"]

        // Act: Execute decisions (placeholder)
        for action in actions do
            printfn "[OODA] Action: %s" action

        let duration = (DateTime.UtcNow - startTime).TotalMilliseconds
        ServiceRegistry.addEvent(OODACycleCompleted duration)
        duration

    /// SC-ORCH-005: Guardian integration for safety checks
    let requestGuardianApproval (action: string) (context: string) : bool =
        let payload = sprintf """{"action":"approve","request":"%s","context":"%s"}""" action context
        let msg = MessageBus.createMessage Planning Guardian Critical payload
        MessageBus.publish msg

        // In real implementation, would wait for Guardian response
        // For now, log and return true (allow)
        printfn "[Guardian] Approval requested for: %s" action
        true

    /// SC-ORCH-006: Cortex AI assistance
    let requestCortexAssistance (query: string) : string =
        let payload = sprintf """{"action":"assist","query":"%s"}""" query
        let msg = MessageBus.createMessage Planning Cortex Normal payload
        MessageBus.publish msg

        // Placeholder response
        sprintf "Cortex processing: %s" query

    /// SC-ORCH-007: Smriti knowledge query
    let querySmritiKnowledge (topic: string) : string list =
        let payload = sprintf """{"action":"query","topic":"%s"}""" topic
        let msg = MessageBus.createMessage Planning Smriti Normal payload
        MessageBus.publish msg

        // Placeholder - in real implementation would return holons
        [ sprintf "Knowledge about: %s" topic ]

    /// SC-ORCH-008: Chaya mesh distribution
    let distributeTasks (tasks: string list) (nodeCount: int) : Map<int, string list> =
        // Distribute tasks across Chaya mesh nodes
        tasks
        |> List.mapi (fun i task -> (i % nodeCount, task))
        |> List.groupBy fst
        |> List.map (fun (node, items) -> (node, items |> List.map snd))
        |> Map.ofList

// =============================================================================
// ACCESS CONTROL INTEGRATION
// =============================================================================

module OrchestrationAccessControl =

    open AccessControl

    /// Validate orchestration access
    let validateAccess (agent: string) (operation: string) : bool =
        // Check if agent can perform operation
        let result = validateFileAccess agent operation "PROJECT_TODOLIST.md"
        match result with
        | AccessResult.Allowed -> true
        | AccessResult.Blocked reason ->
            printfn "[AccessControl] Blocked: %s" reason
            false
        | AccessResult.Denied reason ->
            printfn "[AccessControl] Denied: %s" reason
            false
        | AccessResult.Alerted reason ->
            printfn "[AccessControl] Alert: %s" reason
            false

    /// Validate shell command in orchestration context
    let validateOrchestratedCommand (agent: string) (command: string) : bool =
        let result = validateCommand agent command
        match result with
        | AccessResult.Allowed -> true
        | _ -> false

// =============================================================================
// INITIALIZATION
// =============================================================================

module OrchestrationInit =

    /// Initialize all services
    let initialize () : unit =
        printfn ""
        printfn "=============================================="
        printfn "  INDRAJAAL ORCHESTRATION LAYER"
        printfn "  SC-ORCH-001 | Unified Service Coordination"
        printfn "=============================================="
        printfn ""

        // Register all core services
        ServiceRegistry.register Cortex
        ServiceRegistry.register Prajna
        ServiceRegistry.register Smriti
        ServiceRegistry.register CEPAF
        ServiceRegistry.register Planning
        ServiceRegistry.register Chaya
        ServiceRegistry.register Guardian

        // Set all to Online
        ServiceRegistry.updateHealth Cortex Online 1.0
        ServiceRegistry.updateHealth Prajna Online 1.0
        ServiceRegistry.updateHealth Smriti Online 1.0
        ServiceRegistry.updateHealth CEPAF Online 1.0
        ServiceRegistry.updateHealth Planning Online 1.0
        ServiceRegistry.updateHealth Chaya Online 1.0
        ServiceRegistry.updateHealth Guardian Online 1.0

        printfn ""
        printfn "All services registered and online."
        printfn ""

    /// Get orchestration status
    let getStatus () : string =
        let services = ServiceRegistry.getAllServices()
        let online = services |> List.filter (fun s -> s.Status = Online) |> List.length
        sprintf "Orchestration: %d/%d services online" online services.Length

// =============================================================================
// STAMP CONSTRAINTS
// =============================================================================
(*
SC-ORCH-001: Task creation MUST coordinate with Prajna, Smriti, Chaya
SC-ORCH-002: Task updates MUST propagate to Smriti history
SC-ORCH-003: Task completion MUST record in permanent storage
SC-ORCH-004: OODA cycle MUST complete within 100ms
SC-ORCH-005: Critical actions MUST get Guardian approval
SC-ORCH-006: AI assistance MUST go through Cortex
SC-ORCH-007: Knowledge queries MUST use Smriti
SC-ORCH-008: Mesh distribution MUST use Chaya
SC-ORCH-009: All inter-service messages MUST be logged
SC-ORCH-010: Service health MUST be monitored continuously
SC-ORCH-011: Message bus MUST deliver Critical messages first
SC-ORCH-012: Service registration MUST be atomic
SC-ORCH-013: Access control MUST be enforced at orchestration layer
SC-ORCH-014: Event log MUST be append-only
SC-ORCH-015: Coordination MUST be idempotent
*)

// =============================================================================
// AOR RULES
// =============================================================================
(*
AOR-ORCH-001: ALWAYS coordinate task operations across services
AOR-ORCH-002: NEVER bypass Guardian for critical actions
AOR-ORCH-003: ALWAYS record events to Smriti
AOR-ORCH-004: ALWAYS distribute via Chaya for mesh operations
AOR-ORCH-005: ALWAYS check service health before operations
AOR-ORCH-006: NEVER ignore message delivery failures
AOR-ORCH-007: ALWAYS use MessageBus for inter-service communication
AOR-ORCH-008: ALWAYS validate access before operations
AOR-ORCH-009: ALWAYS log coordination events
AOR-ORCH-010: NEVER hard-code service endpoints
AOR-ORCH-011: ALWAYS use priority-based message delivery
AOR-ORCH-012: ALWAYS handle service unavailability gracefully
AOR-ORCH-013: ALWAYS include correlation IDs for tracing
AOR-ORCH-014: NEVER expose internal service details externally
AOR-ORCH-015: ALWAYS validate message payloads
*)
