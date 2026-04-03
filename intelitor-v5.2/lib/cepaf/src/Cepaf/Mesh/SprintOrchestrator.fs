// =============================================================================
// SprintOrchestrator.fs - Criticality-Based Sprint Task Controller via Zenoh
// =============================================================================
// STAMP: SC-ZTEST-001 to SC-ZTEST-020, SC-SIL4-001
// AOR: AOR-ZTEST-001 to AOR-ZTEST-015
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-03-09 |
// | Author | Cybernetic Architect |
//
// ## Architecture
// Manages 18 sprint tasks across 6 execution waves with Jidoka quality gates.
// Each task has a 6D state vector: [design, implement, test, integrate, verify, deploy]
// Tasks are controlled and monitored via Zenoh pub/sub messaging.
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Collections.Generic
open System.Text.Json

/// Task priority level (criticality)
[<RequireQualifiedAccess>]
type TaskPriority =
    | P0_Critical
    | P1_High
    | P2_Medium
    | P3_Low

/// Task lifecycle status
[<RequireQualifiedAccess>]
type TaskStatus =
    | Pending
    | Running
    | Completed
    | Failed of reason: string
    | Blocked of by: string list

/// 6-dimensional task state vector
/// [design, implement, test, integrate, verify, deploy]
type TaskStateVector = {
    Design: bool
    Implement: bool
    Test: bool
    Integrate: bool
    Verify: bool
    Deploy: bool
}

/// Sprint task definition
type SprintTask = {
    TaskId: string
    Title: string
    Sprint: int
    TaskKey: string
    CheckpointId: string
    Priority: TaskPriority
    Wave: int
    Dependencies: string list
    Status: TaskStatus
    StateVector: TaskStateVector
    StartedAt: DateTimeOffset option
    CompletedAt: DateTimeOffset option
    DurationMs: int64
}

/// Jidoka gate evaluation result
type GateResult = {
    WaveId: int
    GateId: string
    Compilation: bool
    Tests: bool
    Coverage: float
    FppsConsensus: bool
    FsharpBuild: bool option
    TaskCheckpoints: string list
    Passed: bool
    EvaluatedAt: DateTimeOffset
}

/// Wave execution state
type WaveState = {
    WaveId: int
    Tasks: string list
    GateId: string
    Status: TaskStatus
    StartedAt: DateTimeOffset option
    CompletedAt: DateTimeOffset option
    GateResult: GateResult option
}

/// Sprint orchestrator state (extends DigitalTwin)
type SprintOrchestratorState = {
    Tasks: Map<string, SprintTask>
    Waves: Map<int, WaveState>
    CurrentWave: int
    CompletedTasks: Set<string>
    FailedTasks: Set<string>
    CreatedAt: DateTimeOffset
}

/// Sprint orchestrator operations
module SprintOrchestrator =

    // ========================================================================
    // STATE VECTOR OPERATIONS
    // ========================================================================

    /// Create initial (empty) state vector
    let emptyStateVector () : TaskStateVector =
        { Design = false; Implement = false; Test = false
          Integrate = false; Verify = false; Deploy = false }

    /// Create completed state vector
    let completedStateVector () : TaskStateVector =
        { Design = true; Implement = true; Test = true
          Integrate = true; Verify = true; Deploy = true }

    /// Check if task is complete (all dimensions = true)
    let isTaskComplete (sv: TaskStateVector) : bool =
        sv.Design && sv.Implement && sv.Test && sv.Integrate && sv.Verify && sv.Deploy

    /// Calculate progress percentage from state vector
    let progressPct (sv: TaskStateVector) : float =
        let dims = [sv.Design; sv.Implement; sv.Test; sv.Integrate; sv.Verify; sv.Deploy]
        let completed = dims |> List.filter id |> List.length
        (float completed / 6.0) * 100.0

    /// Format state vector as string [1,0,0,0,0,0]
    let formatStateVector (sv: TaskStateVector) : string =
        let b2i b = if b then "1" else "0"
        sprintf "[%s,%s,%s,%s,%s,%s]"
            (b2i sv.Design) (b2i sv.Implement) (b2i sv.Test)
            (b2i sv.Integrate) (b2i sv.Verify) (b2i sv.Deploy)

    // ========================================================================
    // TASK REGISTRY
    // ========================================================================

    /// Create the full task registry with all 18 tasks
    let private createTaskRegistry () : Map<string, SprintTask> =
        let mkTask id title sprint key cp prio wave deps =
            { TaskId = id; Title = title; Sprint = sprint; TaskKey = key
              CheckpointId = cp; Priority = prio; Wave = wave
              Dependencies = deps; Status = TaskStatus.Pending
              StateVector = emptyStateVector ()
              StartedAt = None; CompletedAt = None; DurationMs = 0L }

        [
            // Wave 0: Foundations (P0)
            mkTask "42.1.0.0.0" "Biological Substrate (L0-L5)" 42 "42-1" "CP-HOLON-01" TaskPriority.P0_Critical 0 []
            mkTask "42.4.0.0.0" "Great Renaming (ZKMS->SMRITI) [complete]" 42 "42-4" "CP-HOLON-04" TaskPriority.P0_Critical 0 []
            mkTask "44.2.0.0.0" "Full Zenoh Implementation" 44 "44-2" "CP-VALD-02" TaskPriority.P0_Critical 0 []
            mkTask "46.1.0.0.0" "Regex Pattern Migration (L1/L2)" 46 "46-1" "CP-FPPS-01" TaskPriority.P0_Critical 0 []
            // Wave 1: Core Logic
            mkTask "43.1.1.0.0" "Core Logic (F#)" 43 "43-1-1" "CP-FVAL-02" TaskPriority.P0_Critical 1 []
            mkTask "46.2.0.0.0" "5-Method Consensus Engine (L3)" 46 "46-2" "CP-FPPS-02" TaskPriority.P0_Critical 1 ["46.1.0.0.0"]
            mkTask "42.2.0.0.0" "Social Organism (L6-L7)" 42 "42-2" "CP-HOLON-02" TaskPriority.P1_High 1 ["42.1.0.0.0"]
            // Wave 2: Integration
            mkTask "43.1.2.0.0" "AI Augmentation (OpenRouter/Cortex)" 43 "43-1-2" "CP-FVAL-03" TaskPriority.P1_High 2 ["43.1.1.0.0"]
            mkTask "43.1.3.0.0" "Orchestration & Supervision (CEPAF)" 43 "43-1-3" "CP-FVAL-04" TaskPriority.P1_High 2 ["43.1.1.0.0"]
            mkTask "43.1.4.0.0" "Telemetry & Observability" 43 "43-1-4" "CP-FVAL-05" TaskPriority.P1_High 2 ["43.1.1.0.0"; "44.2.0.0.0"]
            mkTask "44.1.0.0.0" "Multiline & Context Awareness" 44 "44-1" "CP-VALD-01" TaskPriority.P1_High 2 ["43.1.1.0.0"]
            mkTask "44.3.0.0.0" "Smriti Reality" 44 "44-3" "CP-VALD-03" TaskPriority.P1_High 2 ["42.1.0.0.0"; "42.4.0.0.0"]
            // Wave 3: Higher-Order
            mkTask "45.1.0.0.0" "Scaffolding & Core Logic" 45 "45-1" "CP-PLAN-01" TaskPriority.P1_High 3 ["44.3.0.0.0"]
            mkTask "46.3.0.0.0" "Cognitive Integration (L6/L7)" 46 "46-3" "CP-FPPS-03" TaskPriority.P2_Medium 3 ["46.2.0.0.0"; "43.1.2.0.0"]
            mkTask "42.3.0.0.0" "Cosmic Imperative (L8-L9)" 42 "42-3" "CP-HOLON-03" TaskPriority.P2_Medium 3 ["42.2.0.0.0"]
            // Wave 4: Verification & Cutover
            mkTask "45.2.0.0.0" "Verification & Cutover" 45 "45-2" "CP-PLAN-02" TaskPriority.P2_Medium 4 ["45.1.0.0.0"]
            mkTask "46.4.0.0.0" "FPPS Verification" 46 "46-4" "CP-FPPS-04" TaskPriority.P1_High 4 ["46.1.0.0.0"; "46.2.0.0.0"; "46.3.0.0.0"]
            // Wave 5: Rollup
            mkTask "43.1.0.0.0" "F# Validator Implementation (Parent)" 43 "43-1-0" "CP-FVAL-01" TaskPriority.P0_Critical 5 ["43.1.1.0.0"; "43.1.2.0.0"; "43.1.3.0.0"; "43.1.4.0.0"]
        ]
        |> List.map (fun t -> (t.TaskId, t))
        |> Map.ofList

    /// Create wave definitions
    let private createWaveDefinitions () : Map<int, WaveState> =
        [
            (0, { WaveId = 0; Tasks = ["42.1.0.0.0"; "42.4.0.0.0"; "44.2.0.0.0"; "46.1.0.0.0"]
                  GateId = "CP-WAVE-G0"; Status = TaskStatus.Pending; StartedAt = None; CompletedAt = None; GateResult = None })
            (1, { WaveId = 1; Tasks = ["43.1.1.0.0"; "46.2.0.0.0"; "42.2.0.0.0"]
                  GateId = "CP-WAVE-G1"; Status = TaskStatus.Pending; StartedAt = None; CompletedAt = None; GateResult = None })
            (2, { WaveId = 2; Tasks = ["43.1.2.0.0"; "43.1.3.0.0"; "43.1.4.0.0"; "44.1.0.0.0"; "44.3.0.0.0"]
                  GateId = "CP-WAVE-G2"; Status = TaskStatus.Pending; StartedAt = None; CompletedAt = None; GateResult = None })
            (3, { WaveId = 3; Tasks = ["45.1.0.0.0"; "46.3.0.0.0"; "42.3.0.0.0"]
                  GateId = "CP-WAVE-G3"; Status = TaskStatus.Pending; StartedAt = None; CompletedAt = None; GateResult = None })
            (4, { WaveId = 4; Tasks = ["45.2.0.0.0"; "46.4.0.0.0"]
                  GateId = "CP-WAVE-G4"; Status = TaskStatus.Pending; StartedAt = None; CompletedAt = None; GateResult = None })
            (5, { WaveId = 5; Tasks = ["43.1.0.0.0"]
                  GateId = "CP-WAVE-FINAL"; Status = TaskStatus.Pending; StartedAt = None; CompletedAt = None; GateResult = None })
        ] |> Map.ofList

    // ========================================================================
    // ORCHESTRATOR LIFECYCLE
    // ========================================================================

    /// Create initial orchestrator state
    let create () : SprintOrchestratorState =
        { Tasks = createTaskRegistry ()
          Waves = createWaveDefinitions ()
          CurrentWave = 0
          CompletedTasks = Set.empty
          FailedTasks = Set.empty
          CreatedAt = DateTimeOffset.UtcNow }

    /// Check if dependencies are satisfied for a task
    let dependenciesSatisfied (state: SprintOrchestratorState) (taskId: string) : bool =
        match Map.tryFind taskId state.Tasks with
        | None -> false
        | Some task ->
            task.Dependencies |> List.forall (fun dep -> Set.contains dep state.CompletedTasks)

    /// Get tasks ready to execute in current wave
    let readyTasks (state: SprintOrchestratorState) : SprintTask list =
        match Map.tryFind state.CurrentWave state.Waves with
        | None -> []
        | Some wave ->
            wave.Tasks
            |> List.choose (fun id -> Map.tryFind id state.Tasks)
            |> List.filter (fun t ->
                t.Status = TaskStatus.Pending && dependenciesSatisfied state t.TaskId)

    /// Start a task
    let startTask (state: SprintOrchestratorState) (taskId: string) : SprintOrchestratorState =
        let tasks =
            state.Tasks |> Map.map (fun id t ->
                if id = taskId then
                    { t with Status = TaskStatus.Running; StartedAt = Some DateTimeOffset.UtcNow }
                else t)
        // ZUIP: Publish task start to Zenoh mesh
        ZenohPublish.publish
            "CP-SPRINT-START" "indrajaal/sprint/task/start"
            (sprintf "Task %s started" taskId)
            (sprintf """{"task_id":"%s","status":"running","wave":%d}""" taskId state.CurrentWave)
        { state with Tasks = tasks }

    /// Complete a task
    let completeTask (state: SprintOrchestratorState) (taskId: string) (durationMs: int64) : SprintOrchestratorState =
        let tasks =
            state.Tasks |> Map.map (fun id t ->
                if id = taskId then
                    { t with
                        Status = TaskStatus.Completed
                        StateVector = completedStateVector ()
                        CompletedAt = Some DateTimeOffset.UtcNow
                        DurationMs = durationMs }
                else t)
        // ZUIP: Publish task completion to Zenoh mesh
        ZenohPublish.publish
            "CP-SPRINT-COMPLETE" "indrajaal/sprint/task/complete"
            (sprintf "Task %s completed in %dms" taskId durationMs)
            (sprintf """{"task_id":"%s","status":"completed","duration_ms":%d,"wave":%d}""" taskId durationMs state.CurrentWave)
        { state with
            Tasks = tasks
            CompletedTasks = Set.add taskId state.CompletedTasks }

    /// Fail a task
    let failTask (state: SprintOrchestratorState) (taskId: string) (reason: string) : SprintOrchestratorState =
        let tasks =
            state.Tasks |> Map.map (fun id t ->
                if id = taskId then
                    { t with Status = TaskStatus.Failed reason; CompletedAt = Some DateTimeOffset.UtcNow }
                else t)
        // ZUIP: Publish task failure to Zenoh mesh
        ZenohPublish.publish
            "CP-SPRINT-FAIL" "indrajaal/sprint/task/fail"
            (sprintf "Task %s failed: %s" taskId reason)
            (sprintf """{"task_id":"%s","status":"failed","reason":"%s","wave":%d}""" taskId (reason.Replace("\"", "\\\"")) state.CurrentWave)
        { state with
            Tasks = tasks
            FailedTasks = Set.add taskId state.FailedTasks }

    /// Update task state vector
    let updateStateVector (state: SprintOrchestratorState) (taskId: string) (sv: TaskStateVector) : SprintOrchestratorState =
        let tasks =
            state.Tasks |> Map.map (fun id t ->
                if id = taskId then { t with StateVector = sv }
                else t)
        { state with Tasks = tasks }

    // ========================================================================
    // WAVE & GATE MANAGEMENT
    // ========================================================================

    /// Check if current wave is complete (all tasks completed or failed)
    let isWaveComplete (state: SprintOrchestratorState) : bool =
        match Map.tryFind state.CurrentWave state.Waves with
        | None -> true
        | Some wave ->
            wave.Tasks |> List.forall (fun id ->
                match Map.tryFind id state.Tasks with
                | None -> true
                | Some t ->
                    match t.Status with
                    | TaskStatus.Completed | TaskStatus.Failed _ -> true
                    | _ -> false)

    /// Evaluate Jidoka gate for current wave
    let evaluateGate (state: SprintOrchestratorState) (compilation: bool) (tests: bool) (coverage: float) (fpps: bool) (fsharp: bool option) : GateResult =
        match Map.tryFind state.CurrentWave state.Waves with
        | None ->
            { WaveId = state.CurrentWave; GateId = "CP-WAVE-UNKNOWN"
              Compilation = false; Tests = false; Coverage = 0.0
              FppsConsensus = false; FsharpBuild = None; TaskCheckpoints = []
              Passed = false; EvaluatedAt = DateTimeOffset.UtcNow }
        | Some wave ->
            let checkpoints =
                wave.Tasks
                |> List.choose (fun id -> Map.tryFind id state.Tasks)
                |> List.filter (fun t -> t.Status = TaskStatus.Completed)
                |> List.map (fun t -> t.CheckpointId)

            let passed = compilation && tests && coverage >= 95.0
            { WaveId = wave.WaveId; GateId = wave.GateId
              Compilation = compilation; Tests = tests; Coverage = coverage
              FppsConsensus = fpps; FsharpBuild = fsharp
              TaskCheckpoints = checkpoints; Passed = passed
              EvaluatedAt = DateTimeOffset.UtcNow }

    /// Advance to next wave (only if gate passed)
    let advanceWave (state: SprintOrchestratorState) (gate: GateResult) : SprintOrchestratorState =
        if not gate.Passed then state
        else
            let waves =
                state.Waves |> Map.map (fun id w ->
                    if id = state.CurrentWave then
                        { w with
                            Status = TaskStatus.Completed
                            CompletedAt = Some DateTimeOffset.UtcNow
                            GateResult = Some gate }
                    else w)
            { state with Waves = waves; CurrentWave = state.CurrentWave + 1 }

    // ========================================================================
    // FMEA RISK ANALYSIS
    // ========================================================================

    /// FMEA risk entry
    type FmeaEntry = {
        TaskId: string
        FailureMode: string
        Severity: int
        Occurrence: int
        Detection: int
        Rpn: int
        Mitigation: string
    }

    /// Get FMEA analysis for all tasks
    let fmeaAnalysis () : FmeaEntry list =
        [
            { TaskId = "43.1.1.0.0"; FailureMode = "F# validator false positives"
              Severity = 7; Occurrence = 5; Detection = 4; Rpn = 140
              Mitigation = "Dual PropCheck+FsCheck; golden file comparison" }
            { TaskId = "42.4.0.0.0"; FailureMode = "Incomplete SMRITI rename (resolved)"
              Severity = 9; Occurrence = 4; Detection = 3; Rpn = 108
              Mitigation = "Atomic batch rename; mix compile gate" }
            { TaskId = "46.1.0.0.0"; FailureMode = "Regex migration breaks validation"
              Severity = 7; Occurrence = 5; Detection = 3; Rpn = 105
              Mitigation = "Parallel old+new regex; diff results" }
            { TaskId = "46.2.0.0.0"; FailureMode = "5-method consensus breaks FPPS"
              Severity = 8; Occurrence = 4; Detection = 3; Rpn = 96
              Mitigation = "Parallel run old/new; property tests" }
            { TaskId = "42.1.0.0.0"; FailureMode = "SQLite schema breaks holon state"
              Severity = 8; Occurrence = 3; Detection = 4; Rpn = 96
              Mitigation = "Migration scripts; backup data/holons/" }
            { TaskId = "44.2.0.0.0"; FailureMode = "Zenoh NIF API breaks formatter"
              Severity = 9; Occurrence = 3; Detection = 3; Rpn = 81
              Mitigation = "Shadow testing; backward-compatible API" }
            { TaskId = "43.1.4.0.0"; FailureMode = "Telemetry latency exceeds 10ms"
              Severity = 6; Occurrence = 3; Detection = 4; Rpn = 72
              Mitigation = "Async publish; benchmark before merge" }
            { TaskId = "42.2.0.0.0"; FailureMode = "L6-L7 consensus split-brain"
              Severity = 9; Occurrence = 2; Detection = 3; Rpn = 54
              Mitigation = "2oo3 voting; quorum math; chaos test" }
            { TaskId = "45.2.0.0.0"; FailureMode = "Planning cutover loses state"
              Severity = 8; Occurrence = 2; Detection = 3; Rpn = 48
              Mitigation = "SQLite backup; dual-write transition" }
            { TaskId = "44.3.0.0.0"; FailureMode = "Smriti data loss during migration"
              Severity = 9; Occurrence = 2; Detection = 2; Rpn = 36
              Mitigation = "Export before; DuckDB append-only" }
        ]

    /// Get critical risks (RPN > 100)
    let criticalRisks () : FmeaEntry list =
        fmeaAnalysis () |> List.filter (fun e -> e.Rpn > 100)

    // ========================================================================
    // DASHBOARD & REPORTING
    // ========================================================================

    /// Print sprint dashboard
    let printDashboard (state: SprintOrchestratorState) : unit =
        let totalTasks = state.Tasks.Count
        let completed = Set.count state.CompletedTasks
        let failed = Set.count state.FailedTasks
        let running = state.Tasks |> Map.filter (fun _ t -> t.Status = TaskStatus.Running) |> Map.count
        let pending = totalTasks - completed - failed - running

        printfn ""
        printfn "\x1b[35m\x1b[1m>>> SPRINT TASK ORCHESTRATOR <<<\x1b[0m"
        printfn "\x1b[36mWave: %d/5  |  Tasks: %d/%d  |  Gates: %d passed\x1b[0m"
            state.CurrentWave completed totalTasks
            (state.Waves |> Map.filter (fun _ w -> w.GateResult |> Option.map (fun g -> g.Passed) |> Option.defaultValue false) |> Map.count)
        printfn ""
        printfn "STATUS     TASK ID          PRIORITY  WAVE  STATE VECTOR     TITLE"
        printfn "---------- ---------------- --------- ----- ---------------- --------------------------------"

        for (_, st) in state.Tasks |> Map.toSeq |> Seq.sortBy (fun (_, t) -> (t.Wave, t.TaskId)) do
            let statusStr, color =
                match st.Status with
                | TaskStatus.Pending -> "PENDING", "\x1b[90m"
                | TaskStatus.Running -> "RUNNING", "\x1b[33m"
                | TaskStatus.Completed -> "DONE", "\x1b[32m"
                | TaskStatus.Failed _ -> "FAILED", "\x1b[31m"
                | TaskStatus.Blocked _ -> "BLOCKED", "\x1b[91m"

            let prioStr =
                match st.Priority with
                | TaskPriority.P0_Critical -> "P0"
                | TaskPriority.P1_High -> "P1"
                | TaskPriority.P2_Medium -> "P2"
                | TaskPriority.P3_Low -> "P3"

            let svStr = formatStateVector st.StateVector

            printfn "%s%-10s\x1b[0m %-16s %-9s %-5d %-16s %s"
                color statusStr st.TaskId prioStr st.Wave svStr st.Title

        printfn ""
        printfn "\x1b[36mSummary: %d pending | %d running | \x1b[32m%d completed\x1b[36m | \x1b[31m%d failed\x1b[0m"
            pending running completed failed

        // Print critical risks
        let risks = criticalRisks ()
        if risks.Length > 0 then
            printfn ""
            printfn "\x1b[31m\x1b[1mCRITICAL RISKS (RPN > 100):\x1b[0m"
            for risk in risks do
                printfn "  \x1b[31mRPN=%d\x1b[0m %s: %s" risk.Rpn risk.TaskId risk.FailureMode

    /// Export state as JSON for Zenoh publishing
    let toJson (state: SprintOrchestratorState) : string =
        let summary = {|
            current_wave = state.CurrentWave
            total_tasks = state.Tasks.Count
            completed = Set.count state.CompletedTasks
            failed = Set.count state.FailedTasks
            running = state.Tasks |> Map.filter (fun _ t -> t.Status = TaskStatus.Running) |> Map.count
            tasks = state.Tasks |> Map.map (fun _ t -> {|
                task_id = t.TaskId
                title = t.Title
                wave = t.Wave
                status = match t.Status with
                         | TaskStatus.Pending -> "pending"
                         | TaskStatus.Running -> "running"
                         | TaskStatus.Completed -> "completed"
                         | TaskStatus.Failed r -> sprintf "failed: %s" r
                         | TaskStatus.Blocked _ -> "blocked"
                state_vector = formatStateVector t.StateVector
                checkpoint = t.CheckpointId
            |})
            timestamp = DateTimeOffset.UtcNow.ToString("o")
        |}
        JsonSerializer.Serialize(summary, JsonSerializerOptions(WriteIndented = false))

    /// Get critical path tasks
    let criticalPaths () : string list list =
        [
            ["42.1.0.0.0"; "44.3.0.0.0"; "45.1.0.0.0"; "45.2.0.0.0"]
            ["46.1.0.0.0"; "46.2.0.0.0"; "46.3.0.0.0"; "46.4.0.0.0"]
        ]

    // ========================================================================
    // ZENOH STATE PUBLISHING (SC-ZTEST-008: Dual-write strategy)
    // ========================================================================

    /// Publish sprint state to Zenoh via structured log + JSON for CEPAF bridge
    /// SC-ZTEST-008: Publish sprint state via ZenohPublish dual-write abstraction
    let publishState (state: SprintOrchestratorState) (checkpointId: string) : unit =
        let topic = "indrajaal/sprint/state"
        let completed = Set.count state.CompletedTasks
        let total = state.Tasks.Count
        let message = sprintf "wave_%d_%d_of_%d" state.CurrentWave completed total
        let json = toJson state
        ZenohPublish.publish checkpointId topic message json

    /// Publish task state change event via ZenohPublish
    let publishTaskEvent (taskId: string) (event: string) (details: string) : unit =
        let topic = sprintf "indrajaal/sprint/task/%s" taskId
        let checkpointId = sprintf "CP-TASK-%s" (taskId.Replace(".", "_"))
        let payload = sprintf """{"event":"%s","task_id":"%s","details":"%s"}"""
                        event taskId (details.Replace("\"", "\\\""))
        ZenohPublish.publish checkpointId topic event payload

    /// Publish gate evaluation result via ZenohPublish
    let publishGateResult (gate: GateResult) : unit =
        let topic = sprintf "indrajaal/sprint/gate/%s" gate.GateId
        let status = if gate.Passed then "PASSED" else "FAILED"
        let json =
            sprintf """{"wave":%d,"gate":"%s","compilation":%b,"tests":%b,"coverage":%.1f,"fpps":%b,"passed":%b}"""
                    gate.WaveId gate.GateId gate.Compilation gate.Tests gate.Coverage gate.FppsConsensus gate.Passed
        ZenohPublish.publish gate.GateId topic status json
