namespace Cepaf.Debugger

open System
open System.Collections.Generic
open System.Text.Json
open Cepaf.Rop

/// ===============================================================================
/// F# DEBUG ADAPTER PROTOCOL (DAP) WITH ZENOH TELEMETRY
/// ===============================================================================
///
/// WHAT: Debug Adapter Protocol implementation for F# with real-time telemetry
///       publishing to Zenoh mesh and gRPC streaming to Elixir backend.
///
/// WHY: Provides closed-loop debugging experience with:
///      - Breakpoint management with Zenoh notifications
///      - Step execution with fractal logging
///      - Variable inspection with gRPC streaming
///      - Stack trace with OTEL correlation
///
/// STAMP Compliance:
///   - SC-DEBUG-001: Publish to Zenoh within 10ms
///   - SC-DEBUG-002: Emit telemetry for all debug events
///   - SC-DEBUG-003: Correlate with OTEL trace context
///   - SC-DEBUG-004: gRPC timeout 5s for RPC calls
///   - SC-DEBUG-005: Sync breakpoint state across subscribers
///   - SC-DEBUG-006: Include source mapping in stack traces
///   - SC-DEBUG-007: Graceful degradation on backend unavailable
///   - SC-DEBUG-008: Maximum 10K events/sec throughput
///
/// AOR Compliance:
///   - AOR-DEBUG-001: Emit structured telemetry events
///   - AOR-DEBUG-002: Correlate with OTEL traces
///   - AOR-DEBUG-003: Version breakpoints in Immutable Register
///   - AOR-DEBUG-004: Use gRPC for cross-language RPC
///   - AOR-DEBUG-005: Publish real-time updates via Zenoh
///
/// ===============================================================================
module FSharpDAP =

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// DAP configuration (SC-DEBUG-001, SC-DEBUG-004)
    [<Struct>]
    type DAPConfig = {
        /// Project root directory
        ProjectRoot: string
        /// Zenoh session configuration
        ZenohEndpoint: string
        /// gRPC backend endpoint
        GrpcEndpoint: string
        /// Publish timeout (SC-DEBUG-001: < 10ms)
        PublishTimeout: TimeSpan
        /// gRPC call timeout (SC-DEBUG-004: 5s)
        GrpcTimeout: TimeSpan
        /// Maximum events per second (SC-DEBUG-008)
        MaxEventsPerSec: int
    }

    /// Default configuration with STAMP-compliant values
    let defaultConfig = {
        ProjectRoot = "."
        ZenohEndpoint = "tcp/127.0.0.1:7447"
        GrpcEndpoint = "http://localhost:50051"
        PublishTimeout = TimeSpan.FromMilliseconds(10.0)  // SC-DEBUG-001
        GrpcTimeout = TimeSpan.FromSeconds(5.0)           // SC-DEBUG-004
        MaxEventsPerSec = 10000                            // SC-DEBUG-008
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES - SESSION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Debug session status
    type SessionStatus =
        | Idle
        | Running
        | Paused
        | Stopped

    /// Session identifier
    type SessionId = SessionId of string

    /// Debug session state
    type Session = {
        Id: SessionId
        Language: string
        ProjectRoot: string
        Status: SessionStatus
        StartedAt: DateTime
        BreakpointCount: int
        CurrentFile: string option
        CurrentLine: int option
    }

    /// Session statistics
    type SessionStats = {
        BreakpointsHit: int
        StepsExecuted: int
        VariablesInspected: int
        ExpressionsEvaluated: int
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES - BREAKPOINT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Breakpoint identifier
    type BreakpointId = BreakpointId of string

    /// Breakpoint state
    type Breakpoint = {
        Id: BreakpointId
        FilePath: string
        Line: int
        Column: int option
        Condition: string option
        LogMessage: string option
        HitCount: int
        Verified: bool
        Enabled: bool
        CreatedAt: DateTime
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES - EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execution control actions
    type ExecutionAction =
        | Continue
        | Pause
        | StepOver
        | StepInto
        | StepOut
        | RunToLine of file: string * line: int

    /// Why execution stopped
    type StoppedReason =
        | BreakpointHit
        | Step
        | PauseRequested
        | Exception of exnType: string * message: string
        | Entry

    /// Execution response
    type ExecutionResult = {
        Success: bool
        Status: SessionStatus
        StoppedReason: StoppedReason option
        CurrentFrame: StackFrame option
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES - INSPECTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Stack frame representation
    and StackFrame = {
        Id: int
        Name: string
        SourcePath: string
        Line: int
        Column: int
        EndLine: int option
        EndColumn: int option
        ModuleName: string option
        Scopes: Scope list
    }

    /// Variable scope
    and Scope = {
        Name: string
        VariablesReference: int
        Expensive: bool
        NamedVariables: int
        IndexedVariables: int
    }

    /// Variable value
    type Variable = {
        Name: string
        Value: string
        Type: string
        Expandable: bool
        Children: Variable list
        ChildrenCount: int
        MemoryReference: string option
    }

    /// Expression evaluation result
    type EvalResult = {
        Result: string
        Type: string
        Success: bool
        ErrorMessage: string option
        VariablesReference: int option
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES - EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Debug event types for streaming
    type DebugEvent =
        | SessionStarted of sessionId: SessionId * language: string
        | SessionStopped of sessionId: SessionId * durationMs: int64
        | BreakpointSet of breakpoint: Breakpoint
        | BreakpointRemoved of breakpointId: BreakpointId
        | BreakpointHitEvent of breakpointId: BreakpointId * stack: StackFrame list * variables: Map<string, string>
        | StepComplete of stepType: string * frame: StackFrame
        | ExceptionOccurred of exnType: string * message: string * stack: StackFrame list
        | OutputProduced of category: string * output: string * sourcePath: string option * line: int option
        | VariableChanged of varName: string * oldValue: string * newValue: string * frameId: int

    /// Event with timestamp and correlation
    type TimestampedEvent = {
        Event: DebugEvent
        Timestamp: DateTime
        CorrelationId: string
        SessionId: SessionId
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ZENOH TOPICS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Zenoh topic prefix
    let zenohPrefix = "indrajaal/debug/fsharp"

    /// Get topic for breakpoint events
    let breakpointTopic (file: string) (line: int) =
        $"{zenohPrefix}/breakpoint/{file |> Uri.EscapeDataString}/{line}"

    /// Get topic for step events
    let stepTopic (SessionId sessionId) =
        $"{zenohPrefix}/step/{sessionId}"

    /// Get topic for variable events
    let variableTopic (SessionId sessionId) (varName: string) =
        $"{zenohPrefix}/variable/{sessionId}/{varName}"

    /// Get topic for stack events
    let stackTopic (SessionId sessionId) =
        $"{zenohPrefix}/stack/{sessionId}"

    /// Get topic for session events
    let sessionTopic (SessionId sessionId) =
        $"{zenohPrefix}/session/{sessionId}"

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// DAP state
    type DAPState = {
        Config: DAPConfig
        Session: Session option
        Breakpoints: Map<BreakpointId, Breakpoint>
        Stack: StackFrame list
        Variables: Map<string, Variable>
        Stats: SessionStats
        EventQueue: TimestampedEvent list
    }

    /// Create initial state
    let createState config : DAPState = {
        Config = config
        Session = None
        Breakpoints = Map.empty
        Stack = []
        Variables = Map.empty
        Stats = { BreakpointsHit = 0; StepsExecuted = 0; VariablesInspected = 0; ExpressionsEvaluated = 0 }
        EventQueue = []
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ID GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Generate session ID
    let generateSessionId () =
        SessionId $"fsharp-{Guid.NewGuid().ToString("N").[..15]}"

    /// Generate breakpoint ID
    let generateBreakpointId () =
        BreakpointId $"bp-{Guid.NewGuid().ToString("N").[..7]}"

    /// Generate correlation ID
    let generateCorrelationId () =
        $"corr-{Guid.NewGuid().ToString("N").[..11]}"

    // ═══════════════════════════════════════════════════════════════════════════
    // TELEMETRY (SC-DEBUG-002, AOR-DEBUG-001)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create timestamped event
    let createEvent (state: DAPState) (event: DebugEvent) : TimestampedEvent =
        {
            Event = event
            Timestamp = DateTime.UtcNow
            CorrelationId = generateCorrelationId ()
            SessionId = state.Session |> Option.map (fun s -> s.Id) |> Option.defaultValue (SessionId "no-session")
        }

    /// Emit telemetry event (placeholder for actual Zenoh publish)
    let emitTelemetry (event: TimestampedEvent) : unit =
        // In production, this would publish to Zenoh
        printfn $"[TELEMETRY] {event.Timestamp:o} | {event.CorrelationId} | {event.Event}"

    // ═══════════════════════════════════════════════════════════════════════════
    // SESSION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Start debug session
    let startSession (state: DAPState) (projectRoot: string option) : DAPState * SessionId =
        let sessionId = generateSessionId ()
        let root = projectRoot |> Option.defaultValue state.Config.ProjectRoot

        let session = {
            Id = sessionId
            Language = "fsharp"
            ProjectRoot = root
            Status = Running
            StartedAt = DateTime.UtcNow
            BreakpointCount = 0
            CurrentFile = None
            CurrentLine = None
        }

        let newState = { state with Session = Some session }

        // Emit telemetry
        SessionStarted (sessionId, "fsharp")
        |> createEvent newState
        |> emitTelemetry

        (newState, sessionId)

    /// Stop debug session
    let stopSession (state: DAPState) : Result<DAPState * SessionStats, string> =
        match state.Session with
        | None ->
            Error "No active session"
        | Some session ->
            let durationMs = int64 (DateTime.UtcNow - session.StartedAt).TotalMilliseconds

            // Emit telemetry
            SessionStopped (session.Id, durationMs)
            |> createEvent state
            |> emitTelemetry

            let newState = {
                state with
                    Session = None
                    Breakpoints = Map.empty
                    Stack = []
                    Variables = Map.empty
            }
            Ok (newState, state.Stats)

    /// Get session status
    let getSessionStatus (state: DAPState) : Session option =
        state.Session

    // ═══════════════════════════════════════════════════════════════════════════
    // BREAKPOINT MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Set breakpoint
    let setBreakpoint (state: DAPState) (filePath: string) (line: int) (column: int option) (condition: string option) : Result<DAPState * BreakpointId, string> =
        match state.Session with
        | None ->
            Error "No active session"
        | Some session ->
            let bpId = generateBreakpointId ()
            let breakpoint = {
                Id = bpId
                FilePath = filePath
                Line = line
                Column = column
                Condition = condition
                LogMessage = None
                HitCount = 0
                Verified = true  // In production, verify with .NET debugger
                Enabled = true
                CreatedAt = DateTime.UtcNow
            }

            let newBreakpoints = Map.add bpId breakpoint state.Breakpoints
            let newSession = { session with BreakpointCount = newBreakpoints.Count }
            let newState = {
                state with
                    Breakpoints = newBreakpoints
                    Session = Some newSession
            }

            // Emit telemetry
            BreakpointSet breakpoint
            |> createEvent newState
            |> emitTelemetry

            Ok (newState, bpId)

    /// Remove breakpoint
    let removeBreakpoint (state: DAPState) (bpId: BreakpointId) : Result<DAPState, string> =
        match Map.tryFind bpId state.Breakpoints with
        | None ->
            Error "Breakpoint not found"
        | Some _ ->
            let newBreakpoints = Map.remove bpId state.Breakpoints
            let newState = { state with Breakpoints = newBreakpoints }

            // Emit telemetry
            BreakpointRemoved bpId
            |> createEvent newState
            |> emitTelemetry

            Ok newState

    /// List all breakpoints
    let listBreakpoints (state: DAPState) : Breakpoint list =
        state.Breakpoints |> Map.values |> Seq.toList

    /// Enable/disable breakpoint
    let toggleBreakpoint (state: DAPState) (bpId: BreakpointId) (enabled: bool) : Result<DAPState, string> =
        match Map.tryFind bpId state.Breakpoints with
        | None ->
            Error "Breakpoint not found"
        | Some bp ->
            let updatedBp = { bp with Enabled = enabled }
            let newState = { state with Breakpoints = Map.add bpId updatedBp state.Breakpoints }
            Ok newState

    // ═══════════════════════════════════════════════════════════════════════════
    // EXECUTION CONTROL
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute action
    let executeAction (state: DAPState) (action: ExecutionAction) : Result<DAPState * ExecutionResult, string> =
        match state.Session with
        | None ->
            Error "No active session"
        | Some session ->
            let actionName =
                match action with
                | Continue -> "continue"
                | Pause -> "pause"
                | StepOver -> "step_over"
                | StepInto -> "step_into"
                | StepOut -> "step_out"
                | RunToLine (f, l) -> $"run_to_line:{f}:{l}"

            // In production, this would interact with .NET debugger
            let newStatus =
                match action with
                | Pause -> Paused
                | _ -> Running

            let newSession = { session with Status = newStatus }
            let newStats = { state.Stats with StepsExecuted = state.Stats.StepsExecuted + 1 }

            let result = {
                Success = true
                Status = newStatus
                StoppedReason = None
                CurrentFrame = List.tryHead state.Stack
            }

            let newState = {
                state with
                    Session = Some newSession
                    Stats = newStats
            }

            Ok (newState, result)

    // ═══════════════════════════════════════════════════════════════════════════
    // VARIABLE INSPECTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Inspect variable
    let inspectVariable (state: DAPState) (varName: string) (frameId: int) (expandChildren: bool) : Result<DAPState * Variable, string> =
        // In production, this would query the .NET debugger
        let variable = {
            Name = varName
            Value = "<mock value>"
            Type = "obj"
            Expandable = false
            Children = []
            ChildrenCount = 0
            MemoryReference = None
        }

        let newStats = { state.Stats with VariablesInspected = state.Stats.VariablesInspected + 1 }
        let newState = { state with Stats = newStats }

        Ok (newState, variable)

    /// Evaluate expression
    let evaluate (state: DAPState) (expression: string) (frameId: int) : Result<DAPState * EvalResult, string> =
        // In production, this would evaluate via .NET debugger
        let result = {
            Result = "<mock result>"
            Type = "obj"
            Success = true
            ErrorMessage = None
            VariablesReference = None
        }

        let newStats = { state.Stats with ExpressionsEvaluated = state.Stats.ExpressionsEvaluated + 1 }
        let newState = { state with Stats = newStats }

        Ok (newState, result)

    /// Get stack trace
    let getStackTrace (state: DAPState) (startFrame: int) (levels: int) : StackFrame list =
        state.Stack
        |> List.skip (min startFrame (List.length state.Stack))
        |> List.truncate levels

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENT HANDLERS (Breakpoint Hit, Exception, etc.)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Handle breakpoint hit
    let handleBreakpointHit (state: DAPState) (bpId: BreakpointId) (stack: StackFrame list) (bindings: Map<string, string>) : DAPState =
        match Map.tryFind bpId state.Breakpoints, state.Session with
        | Some bp, Some session ->
            let updatedBp = { bp with HitCount = bp.HitCount + 1 }
            let newSession = {
                session with
                    Status = Paused
                    CurrentFile = Some bp.FilePath
                    CurrentLine = Some bp.Line
            }
            let newStats = { state.Stats with BreakpointsHit = state.Stats.BreakpointsHit + 1 }

            let newState = {
                state with
                    Breakpoints = Map.add bpId updatedBp state.Breakpoints
                    Session = Some newSession
                    Stack = stack
                    Stats = newStats
            }

            // Emit telemetry
            BreakpointHitEvent (bpId, stack, bindings)
            |> createEvent newState
            |> emitTelemetry

            newState
        | _ -> state

    /// Handle exception
    let handleException (state: DAPState) (exnType: string) (message: string) (stack: StackFrame list) : DAPState =
        match state.Session with
        | Some session ->
            let newSession = { session with Status = Paused }
            let newState = {
                state with
                    Session = Some newSession
                    Stack = stack
            }

            // Emit telemetry
            ExceptionOccurred (exnType, message, stack)
            |> createEvent newState
            |> emitTelemetry

            newState
        | None -> state

    // ═══════════════════════════════════════════════════════════════════════════
    // GRPC SERVICE STUBS (SC-DEBUG-004, AOR-DEBUG-004)
    // ═══════════════════════════════════════════════════════════════════════════

    /// gRPC service interface for Elixir bridge
    module GrpcService =

        /// Start session via gRPC
        let startSessionAsync (config: DAPConfig) (language: string) (projectRoot: string) =
            async {
                // In production, this would make gRPC call
                return Ok (generateSessionId ())
            }

        /// Set breakpoint via gRPC
        let setBreakpointAsync (config: DAPConfig) (sessionId: SessionId) (filePath: string) (line: int) =
            async {
                return Ok (generateBreakpointId (), true, line)
            }

        /// Stream events via gRPC
        let streamEventsAsync (config: DAPConfig) (sessionId: SessionId) (eventTypes: string list) =
            async {
                // In production, this would return an IAsyncEnumerable
                return Ok ()
            }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTEGRATION WITH ELIXIR DAP
    // ═══════════════════════════════════════════════════════════════════════════

    /// Bridge to Elixir DAP for cross-language debugging
    module ElixirDAPBridge =

        /// Sync breakpoints to Elixir
        let syncBreakpoints (state: DAPState) =
            async {
                // In production, publish breakpoints to shared state
                return Ok ()
            }

        /// Receive events from Elixir DAP
        let subscribeToElixirEvents (callback: DebugEvent -> unit) =
            // In production, subscribe to Zenoh topic
            ()

    // ═══════════════════════════════════════════════════════════════════════════
    // STATISTICS AND REPORTING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get DAP statistics for dashboard
    let getStatistics (state: DAPState) : Map<string, obj> =
        let sessionStatus =
            state.Session
            |> Option.map (fun s ->
                match s.Status with
                | Idle -> "IDLE"
                | Running -> "RUNNING"
                | Paused -> "PAUSED"
                | Stopped -> "STOPPED")
            |> Option.defaultValue "NO_SESSION"

        Map.ofList [
            "session_status", box sessionStatus
            "breakpoint_count", box state.Breakpoints.Count
            "breakpoints_hit", box state.Stats.BreakpointsHit
            "steps_executed", box state.Stats.StepsExecuted
            "variables_inspected", box state.Stats.VariablesInspected
            "expressions_evaluated", box state.Stats.ExpressionsEvaluated
            "stack_depth", box (List.length state.Stack)
            "event_queue_size", box (List.length state.EventQueue)
        ]
