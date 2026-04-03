// =============================================================================
// SupervisorHierarchy.fs - 3-Level Supervisor Hierarchy for SIL-6 Boot Sequence
// =============================================================================
// STAMP: SC-SUP-001, SC-SUP-002, SC-SUP-003, SC-BOOT-009
// AOR: AOR-MESH-001, AOR-MESH-007, AOR-BIO-001
//
// ## 3-Level Supervisor Hierarchy
// | Level | Name | Count | Responsibility |
// |-------|------|-------|----------------|
// | L1 | Executive | 1 | Master OODA orchestrator, veto authority |
// | L2 | Domain | 4 | Stage supervisors (INFRA, ZENOH, APP, VERIFY) |
// | L3 | Worker | 12 | Container workers, task execution |
//
// ## OODA Loop Integration
// - 30s cycle time (SC-OODA-001)
// - Observe: 5s, Orient: 5s, Decide: 5s, Act: 15s
// - State vector verification at each phase
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-17 |
// | Author | Claude Opus 4.5 |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Collections.Generic
open Cepaf.Config

/// Supervisor hierarchy levels
type SupervisorLevel =
    /// L1: Master OODA orchestrator with veto authority (1 agent)
    | L1_Executive
    /// L2: Stage supervisors for boot phases (4 agents)
    | L2_Domain
    /// L3: Container workers for task execution (12 agents)
    | L3_Worker

/// Supervisor operational status
type SupervisorStatus =
    /// Supervisor is idle, waiting for work
    | Idle
    /// Supervisor is actively processing
    | Active
    /// Supervisor is in OODA observe phase
    | Observing
    /// Supervisor is in OODA orient phase
    | Orienting
    /// Supervisor is in OODA decide phase
    | Deciding
    /// Supervisor is in OODA act phase
    | Acting
    /// Supervisor has failed
    | Failed of string
    /// Supervisor has been terminated
    | Terminated

/// Domain supervisor specialization
type DomainType =
    /// Infrastructure stage supervisor (S1)
    | SUP_INFRA
    /// Zenoh mesh stage supervisor (S2)
    | SUP_ZENOH
    /// Application stage supervisor (S3)
    | SUP_APP
    /// Verification stage supervisor (S4)
    | SUP_VERIFY

/// Worker specialization
type WorkerType =
    /// Database boot worker
    | WRK_DB
    /// Observability stack worker
    | WRK_OBS
    /// Zenoh router worker (1-3)
    | WRK_ZENOH of int
    /// Application worker (1-2)
    | WRK_APP of int
    /// Health check worker
    | WRK_HEALTH
    /// Quorum verification worker
    | WRK_QUORUM
    /// Pattern validation worker
    | WRK_PATTERN
    /// AST validation worker
    | WRK_AST
    /// End-to-end test worker
    | WRK_E2E

/// OODA loop phase
type OODAPhase =
    | Observe
    | Orient
    | Decide
    | Act

/// OODA loop state
type OODAState = {
    /// Current phase
    Phase: OODAPhase
    /// Phase start time
    PhaseStartTime: DateTime
    /// Observations collected
    Observations: Map<string, obj>
    /// Orientation analysis
    Orientations: string list
    /// Decisions made
    Decisions: string list
    /// Actions taken
    Actions: string list
    /// Cycle count
    CycleCount: int
}

/// Single supervisor in the hierarchy
type Supervisor = {
    /// Unique supervisor ID
    Id: string
    /// Supervisor level
    Level: SupervisorLevel
    /// Associated boot stage (for L2 domain supervisors)
    Stage: BootStage option
    /// Current operational status
    Status: SupervisorStatus
    /// Child supervisor IDs
    Children: string list
    /// Parent supervisor ID (None for executive)
    Parent: string option
    /// OODA loop state
    OODAState: OODAState option
    /// Last heartbeat time
    LastHeartbeat: DateTime
    /// Metrics
    Metrics: Map<string, float>
}

/// Complete supervisor tree
type SupervisorTree = {
    /// L1 Executive supervisor
    Executive: Supervisor
    /// L2 Domain supervisors (4)
    DomainSupervisors: Supervisor list
    /// L3 Worker supervisors (12)
    Workers: Supervisor list
    /// Tree creation time
    CreatedAt: DateTime
    /// Global OODA cycle count
    GlobalCycleCount: int
}

/// Supervisor command
type SupervisorCommand =
    | StartOODA
    | StopOODA
    | Veto of string
    | Approve of string
    | AssignTask of string * string
    | ReportStatus
    | Heartbeat
    | Terminate

/// Supervisor event
type SupervisorEvent = {
    /// Event timestamp
    Timestamp: DateTime
    /// Source supervisor ID
    SourceId: string
    /// Event type
    EventType: string
    /// Event data
    Data: Map<string, obj>
}

module SupervisorHierarchy =

    /// Initialize empty OODA state
    let initOODAState () : OODAState =
        {
            Phase = Observe
            PhaseStartTime = DateTime.UtcNow
            Observations = Map.empty
            Orientations = []
            Decisions = []
            Actions = []
            CycleCount = 0
        }

    /// Create a supervisor with given parameters
    let createSupervisor (id: string) (level: SupervisorLevel) (stage: BootStage option) (parent: string option) (children: string list) : Supervisor =
        {
            Id = id
            Level = level
            Stage = stage
            Status = Idle
            Children = children
            Parent = parent
            OODAState = if level = L1_Executive then Some (initOODAState ()) else None
            LastHeartbeat = DateTime.UtcNow
            Metrics = Map.empty
        }

    /// Create worker IDs for a domain
    let createWorkerIds (domain: DomainType) : string list =
        match domain with
        | SUP_INFRA -> ["WRK-01-DB"; "WRK-02-OBS"]
        | SUP_ZENOH -> ["WRK-03-ZENOH1"; "WRK-04-ZENOH2"; "WRK-05-ZENOH3"]
        | SUP_APP -> ["WRK-06-APP1"; "WRK-07-APP2"; "WRK-08-HEALTH"]
        | SUP_VERIFY -> ["WRK-09-QUORUM"; "WRK-10-PATTERN"; "WRK-11-AST"; "WRK-12-E2E"]

    /// Build the complete 3-level supervisor hierarchy
    let buildHierarchy () : SupervisorTree =
        // L2 Domain supervisor IDs
        let domainIds = ["SUP-INFRA"; "SUP-ZENOH"; "SUP-APP"; "SUP-VERIFY"]

        // Create L1 Executive
        let executive = createSupervisor "EXEC-001" L1_Executive None None domainIds

        // Create L2 Domain supervisors with their worker children
        let domainSupervisors = [
            let infraWorkers = createWorkerIds SUP_INFRA
            createSupervisor "SUP-INFRA" L2_Domain (Some S1_Infrastructure) (Some "EXEC-001") infraWorkers

            let zenohWorkers = createWorkerIds SUP_ZENOH
            createSupervisor "SUP-ZENOH" L2_Domain (Some S2_ZenohMesh) (Some "EXEC-001") zenohWorkers

            let appWorkers = createWorkerIds SUP_APP
            createSupervisor "SUP-APP" L2_Domain (Some S3_AppSeed) (Some "EXEC-001") appWorkers

            let verifyWorkers = createWorkerIds SUP_VERIFY
            createSupervisor "SUP-VERIFY" L2_Domain (Some S4_Homeostasis) (Some "EXEC-001") verifyWorkers
        ]

        // Create L3 Workers
        let workers = [
            // Infrastructure workers
            createSupervisor "WRK-01-DB" L3_Worker None (Some "SUP-INFRA") []
            createSupervisor "WRK-02-OBS" L3_Worker None (Some "SUP-INFRA") []

            // Zenoh workers
            createSupervisor "WRK-03-ZENOH1" L3_Worker None (Some "SUP-ZENOH") []
            createSupervisor "WRK-04-ZENOH2" L3_Worker None (Some "SUP-ZENOH") []
            createSupervisor "WRK-05-ZENOH3" L3_Worker None (Some "SUP-ZENOH") []

            // App workers
            createSupervisor "WRK-06-APP1" L3_Worker None (Some "SUP-APP") []
            createSupervisor "WRK-07-APP2" L3_Worker None (Some "SUP-APP") []
            createSupervisor "WRK-08-HEALTH" L3_Worker None (Some "SUP-APP") []

            // Verify workers
            createSupervisor "WRK-09-QUORUM" L3_Worker None (Some "SUP-VERIFY") []
            createSupervisor "WRK-10-PATTERN" L3_Worker None (Some "SUP-VERIFY") []
            createSupervisor "WRK-11-AST" L3_Worker None (Some "SUP-VERIFY") []
            createSupervisor "WRK-12-E2E" L3_Worker None (Some "SUP-VERIFY") []
        ]

        {
            Executive = executive
            DomainSupervisors = domainSupervisors
            Workers = workers
            CreatedAt = DateTime.UtcNow
            GlobalCycleCount = 0
        }

    /// Get supervisor by ID from tree
    let findSupervisor (id: string) (tree: SupervisorTree) : Supervisor option =
        if tree.Executive.Id = id then
            Some tree.Executive
        else
            match tree.DomainSupervisors |> List.tryFind (fun s -> s.Id = id) with
            | Some s -> Some s
            | None -> tree.Workers |> List.tryFind (fun s -> s.Id = id)

    /// Count supervisors by status
    let countByStatus (status: SupervisorStatus) (tree: SupervisorTree) : int =
        let execCount = if tree.Executive.Status = status then 1 else 0
        let domainCount = tree.DomainSupervisors |> List.filter (fun s -> s.Status = status) |> List.length
        let workerCount = tree.Workers |> List.filter (fun s -> s.Status = status) |> List.length
        execCount + domainCount + workerCount

    /// Get total supervisor count
    let totalCount (tree: SupervisorTree) : int =
        1 + List.length tree.DomainSupervisors + List.length tree.Workers

    /// Update supervisor status
    let updateStatus (id: string) (status: SupervisorStatus) (tree: SupervisorTree) : SupervisorTree =
        if tree.Executive.Id = id then
            { tree with Executive = { tree.Executive with Status = status; LastHeartbeat = DateTime.UtcNow } }
        else
            let domainUpdated =
                tree.DomainSupervisors
                |> List.map (fun s -> if s.Id = id then { s with Status = status; LastHeartbeat = DateTime.UtcNow } else s)
            let workersUpdated =
                tree.Workers
                |> List.map (fun s -> if s.Id = id then { s with Status = status; LastHeartbeat = DateTime.UtcNow } else s)
            { tree with DomainSupervisors = domainUpdated; Workers = workersUpdated }

    /// Advance OODA phase
    let advanceOODAPhase (state: OODAState) : OODAState =
        let nextPhase =
            match state.Phase with
            | Observe -> Orient
            | Orient -> Decide
            | Decide -> Act
            | Act -> Observe  // Cycle back
        let newCycleCount = if nextPhase = Observe then state.CycleCount + 1 else state.CycleCount
        { state with
            Phase = nextPhase
            PhaseStartTime = DateTime.UtcNow
            CycleCount = newCycleCount
            // Clear state on new cycle
            Observations = if nextPhase = Observe then Map.empty else state.Observations
            Orientations = if nextPhase = Observe then [] else state.Orientations
            Decisions = if nextPhase = Observe then [] else state.Decisions
            Actions = if nextPhase = Observe then [] else state.Actions
        }

    /// Get OODA phase duration in milliseconds
    let getOODAPhaseDuration (phase: OODAPhase) : int =
        match phase with
        | Observe -> AnimationConfig.OodaLoop.observeMs
        | Orient -> AnimationConfig.OodaLoop.orientMs
        | Decide -> AnimationConfig.OodaLoop.decideMs
        | Act -> AnimationConfig.OodaLoop.actMs

    /// Check if current OODA phase has timed out
    let isOODAPhaseExpired (state: OODAState) : bool =
        let elapsed = (DateTime.UtcNow - state.PhaseStartTime).TotalMilliseconds
        let duration = getOODAPhaseDuration state.Phase |> float
        elapsed >= duration

    /// Run single OODA observe phase
    let runObserve (tree: SupervisorTree) (stateVector: StateVector) : Map<string, obj> =
        Map.ofList [
            "stateVector", box stateVector
            "supervisorCount", box (totalCount tree)
            "activeCount", box (countByStatus Active tree)
            "failedCount", box (countByStatus (Failed "") tree)
            "timestamp", box DateTime.UtcNow
        ]

    /// Run single OODA orient phase
    let runOrient (observations: Map<string, obj>) : string list =
        let stateVector = observations.TryFind "stateVector" |> Option.map unbox<StateVector>
        let failedCount = observations.TryFind "failedCount" |> Option.map unbox<int> |> Option.defaultValue 0

        [
            if failedCount > 0 then
                sprintf "ALERT: %d supervisors failed" failedCount
            match stateVector with
            | Some sv ->
                if not sv.Compile then "Compilation not verified"
                if not sv.Migrations then "Migrations not applied"
                if not sv.Containers then "Containers not healthy"
                if not sv.Zenoh then "Zenoh mesh not formed"
                if not sv.Health then "App health check failed"
                if not sv.Quorum then "Quorum not achieved"
            | None -> "State vector unavailable"
        ]

    /// Run single OODA decide phase
    let runDecide (orientations: string list) : string list =
        orientations |> List.collect (fun o ->
            if o.Contains("failed") then
                ["RestartFailedSupervisors"; "AlertOperator"]
            elif o.Contains("not verified") || o.Contains("not applied") then
                ["BlockStageTransition"; "RunVerification"]
            elif o.Contains("not healthy") || o.Contains("not formed") then
                ["RetryHealthCheck"; "ExtendTimeout"]
            elif o.Contains("not achieved") then
                ["WaitForQuorum"; "CheckZenohRouters"]
            else
                []
        )

    /// Run single OODA act phase
    let runAct (decisions: string list) : string list =
        decisions |> List.map (fun d ->
            sprintf "Executed: %s at %s" d (DateTime.UtcNow.ToString("HH:mm:ss.fff"))
        )

    /// Print hierarchy status with ANSI colors
    let printHierarchy (tree: SupervisorTree) : unit =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let cyan = "\u001b[36m"
        let green = "\u001b[32m"
        let yellow = "\u001b[33m"
        let magenta = "\u001b[35m"

        printfn ""
        printfn "%s%s╔═══════════════════════════════════════════════════════════════════════════════╗%s" magenta bold reset
        printfn "%s%s║  3-LEVEL SUPERVISOR HIERARCHY                                                 ║%s" magenta bold reset
        printfn "%s%s╚═══════════════════════════════════════════════════════════════════════════════╝%s" magenta bold reset
        printfn ""

        // L1 Executive
        printfn "%s%sL1 EXECUTIVE (1 Agent)%s" cyan bold reset
        printfn "  └─ %s [%A]" tree.Executive.Id tree.Executive.Status
        match tree.Executive.OODAState with
        | Some ooda -> printfn "     OODA: %A (Cycle %d)" ooda.Phase ooda.CycleCount
        | None -> ()
        printfn ""

        // L2 Domain Supervisors
        printfn "%s%sL2 DOMAIN SUPERVISORS (4 Agents)%s" yellow bold reset
        for sup in tree.DomainSupervisors do
            let stageStr = sup.Stage |> Option.map (sprintf "%A") |> Option.defaultValue "N/A"
            printfn "  ├─ %s [%A] → Stage: %s" sup.Id sup.Status stageStr
        printfn ""

        // L3 Workers
        printfn "%s%sL3 WORKERS (12 Agents)%s" green bold reset
        for worker in tree.Workers do
            let parentStr = worker.Parent |> Option.defaultValue "N/A"
            printfn "  ├─ %s [%A] → Parent: %s" worker.Id worker.Status parentStr
        printfn ""

        // Summary
        printfn "%sSummary:%s Total=%d, Active=%d, Idle=%d, Failed=%d"
            cyan reset
            (totalCount tree)
            (countByStatus Active tree)
            (countByStatus Idle tree)
            (countByStatus (Failed "") tree)
        printfn ""

    /// Print OODA cycle status
    let printOODAStatus (state: OODAState) : unit =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let cyan = "\u001b[36m"

        let elapsed = (DateTime.UtcNow - state.PhaseStartTime).TotalMilliseconds |> int
        let duration = getOODAPhaseDuration state.Phase
        let progress = min 100 (elapsed * 100 / duration)

        printfn "%sOODA Cycle %d - Phase: %A%s" cyan state.CycleCount state.Phase reset
        printfn "  Progress: [%s%s] %d%%"
            (String.replicate (progress / 5) "█")
            (String.replicate ((100 - progress) / 5) "░")
            progress
        printfn "  Observations: %d, Orientations: %d, Decisions: %d, Actions: %d"
            state.Observations.Count
            state.Orientations.Length
            state.Decisions.Length
            state.Actions.Length

