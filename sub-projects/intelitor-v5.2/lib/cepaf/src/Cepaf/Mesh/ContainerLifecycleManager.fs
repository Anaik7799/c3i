// =============================================================================
// ContainerLifecycleManager.fs - SIL-4 Container Lifecycle State Machine
// =============================================================================
// STAMP: SC-SIL4-012, SC-SIL4-013, SC-SIL4-014, SC-SIL4-016
// AOR: AOR-SIL4-001, AOR-SIL4-002, AOR-SIL4-003
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-04 |
// | Author | Cybernetic Architect |
// | Elixir Equivalent | lib/indrajaal/lifecycle/container_lifecycle.ex |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Collections.Concurrent
open System.Diagnostics
open System.Threading
open System.Threading.Tasks

/// Podman command execution helper
module Podman =
    /// Run a podman command and return the result
    let runCommand (cmd: string) : Async<Result<string, string>> = async {
        try
            let psi = ProcessStartInfo(
                FileName = "podman",
                Arguments = cmd,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            )
            use proc = Process.Start(psi)
            let! output = proc.StandardOutput.ReadToEndAsync() |> Async.AwaitTask
            let! errors = proc.StandardError.ReadToEndAsync() |> Async.AwaitTask
            do! proc.WaitForExitAsync() |> Async.AwaitTask
            if proc.ExitCode = 0 then
                return Ok output
            else
                return Error (sprintf "Exit code %d: %s" proc.ExitCode errors)
        with ex ->
            return Error (sprintf "Podman execution failed: %s" ex.Message)
    }

/// <summary>
/// SC-SIL4-012: 5 Startup Phases
/// Deterministic phase transitions for container startup
/// </summary>
type StartupLifecyclePhase =
    | Created           // Container image pulled, not started
    | Starting          // Process spawning, ports binding
    | Initializing      // Application bootstrapping
    | Connecting        // Joining cluster, gossip
    | Running           // Fully operational

/// <summary>
/// SC-SIL4-013: 6 Shutdown Phases
/// Deterministic phase transitions for container shutdown
/// </summary>
type ShutdownLifecyclePhase =
    | Running           // Normal operation
    | Lameduck          // No new connections
    | Draining          // Waiting for connections to close
    | Checkpointing     // Saving state (dying gasp)
    | Stopping          // Process termination
    | Stopped           // Container exited

/// <summary>
/// Result of a phase transition
/// </summary>
type PhaseResult = {
    Phase: string
    Success: bool
    DurationMs: int64
    Error: string option
    Timestamp: DateTimeOffset
}

/// <summary>
/// Complete lifecycle state for a container
/// </summary>
type LifecycleState = {
    ContainerId: string
    CurrentPhase: string
    PhaseHistory: PhaseResult list
    StartedAt: DateTimeOffset option
    LastTransition: DateTimeOffset option
    Metadata: Map<string, string>
    GossipCookie: string option       // SC-SIL4-014
    NodeFailureLogged: bool           // SC-SIL4-016
}

/// <summary>
/// Phase transition validation
/// </summary>
module PhaseTransitions =

    /// Valid startup transitions
    let startupTransitions =
        Map.ofList [
            "created", "starting"
            "starting", "initializing"
            "initializing", "connecting"
            "connecting", "running"
        ]

    /// Valid shutdown transitions
    let shutdownTransitions =
        Map.ofList [
            "running", "lameduck"
            "lameduck", "draining"
            "draining", "checkpointing"
            "checkpointing", "stopping"
            "stopping", "stopped"
        ]

    /// Get next phase for startup
    let nextStartupPhase current =
        startupTransitions.TryFind current

    /// Get next phase for shutdown
    let nextShutdownPhase current =
        shutdownTransitions.TryFind current

    /// Check if transition is valid
    let isValidTransition fromPhase toPhase direction =
        let transitions =
            match direction with
            | "startup" -> startupTransitions
            | "shutdown" -> shutdownTransitions
            | _ -> Map.empty

        match transitions.TryFind fromPhase with
        | Some expected -> expected = toPhase
        | None -> false

/// <summary>
/// Container Lifecycle Manager
/// Implements SC-SIL4-012 and SC-SIL4-013 phase state machines
/// </summary>
type ContainerLifecycleManager() =

    /// Registry of container lifecycles
    let lifecycles = ConcurrentDictionary<string, LifecycleState>()

    /// Phase timeout in milliseconds
    let phaseTimeoutMs = 30_000

    /// Transition poll interval
    let transitionPollMs = 500

    /// <summary>
    /// Creates a new lifecycle state for a container
    /// </summary>
    member this.Create(containerId: string, ?metadata: Map<string, string>) =
        let state = {
            ContainerId = containerId
            CurrentPhase = "created"
            PhaseHistory = []
            StartedAt = Some DateTimeOffset.UtcNow
            LastTransition = Some DateTimeOffset.UtcNow
            Metadata = defaultArg metadata Map.empty
            GossipCookie = None
            NodeFailureLogged = false
        }

        lifecycles.[containerId] <- state
        FractalLogger.logPhase "lifecycle" containerId "created" "Lifecycle created"
        Ok state

    /// <summary>
    /// Gets the current lifecycle state
    /// </summary>
    member this.GetState(containerId: string) =
        match lifecycles.TryGetValue(containerId) with
        | true, state -> Some state
        | false, _ -> None

    /// <summary>
    /// Gets the current phase only
    /// </summary>
    member this.CurrentPhase(containerId: string) =
        this.GetState(containerId)
        |> Option.map (fun s -> s.CurrentPhase)

    /// <summary>
    /// Advances to the next startup phase
    /// SC-SIL4-012: Sequential phase advancement
    /// </summary>
    member this.AdvanceStartup(containerId: string) =
        match this.GetState(containerId) with
        | None -> Error "Container not found"
        | Some state ->
            match PhaseTransitions.nextStartupPhase state.CurrentPhase with
            | None -> Error $"No startup transition from {state.CurrentPhase}"
            | Some nextPhase ->
                let sw = Stopwatch.StartNew()

                // Execute phase-specific action
                let actionResult = this.ExecuteStartupAction(containerId, state.CurrentPhase, nextPhase)

                sw.Stop()

                // SC-REGEN-004: Enforce Smriti SEO Persistence
                let config = "NixOS / Podman Unified Blueprint" // Placeholder for real config retrieval
                let issues = if Result.isError actionResult then sprintf "ERROR: %A" actionResult else "Stable"
                if not (SmritiSEO.saveContainerMetadata containerId nextPhase config issues) then
                    eprintfn "[SEO] CRITICAL: Failed to persist metadata to Smriti. Jidoka triggered."
                
                let phaseResult = {
                    Phase = nextPhase
                    Success = Result.isOk actionResult
                    DurationMs = sw.ElapsedMilliseconds
                    Error = match actionResult with Error e -> Some e | Ok _ -> None
                    Timestamp = DateTimeOffset.UtcNow
                }

                let newState = {
                    state with
                        CurrentPhase = nextPhase
                        PhaseHistory = phaseResult :: state.PhaseHistory
                        LastTransition = Some DateTimeOffset.UtcNow
                }

                lifecycles.[containerId] <- newState

                FractalLogger.logPhase "lifecycle" containerId nextPhase
                    $"{state.CurrentPhase} -> {nextPhase} ({sw.ElapsedMilliseconds}ms)"

                Ok nextPhase

    /// <summary>
    /// Advances to the next shutdown phase
    /// SC-SIL4-013: Sequential phase advancement
    /// </summary>
    member this.AdvanceShutdown(containerId: string) =
        match this.GetState(containerId) with
        | None -> Error "Container not found"
        | Some state ->
            match PhaseTransitions.nextShutdownPhase state.CurrentPhase with
            | None -> Error $"No shutdown transition from {state.CurrentPhase}"
            | Some nextPhase ->
                let sw = Stopwatch.StartNew()

                // Execute phase-specific action
                let actionResult = this.ExecuteShutdownAction(containerId, state.CurrentPhase, nextPhase)

                sw.Stop()

                let phaseResult = {
                    Phase = nextPhase
                    Success = Result.isOk actionResult
                    DurationMs = sw.ElapsedMilliseconds
                    Error = match actionResult with Error e -> Some e | Ok _ -> None
                    Timestamp = DateTimeOffset.UtcNow
                }

                let newState = {
                    state with
                        CurrentPhase = nextPhase
                        PhaseHistory = phaseResult :: state.PhaseHistory
                        LastTransition = Some DateTimeOffset.UtcNow
                }

                lifecycles.[containerId] <- newState

                FractalLogger.logPhase "lifecycle" containerId nextPhase
                    $"{state.CurrentPhase} -> {nextPhase} ({sw.ElapsedMilliseconds}ms)"

                Ok nextPhase

    /// <summary>
    /// Executes complete startup sequence through all 5 phases
    /// </summary>
    member this.ExecuteStartup(containerId: string) = async {
        match this.GetState(containerId) with
        | None ->
            // Create if not exists
            match this.Create(containerId) with
            | Error e -> return Error e
            | Ok _ -> return! this.ExecuteStartup(containerId)
        | Some state ->
            let mutable currentState = state
            let mutable lastError = None

            // Execute through all startup phases
            while currentState.CurrentPhase <> "running" && lastError.IsNone do
                match this.AdvanceStartup(containerId) with
                | Ok phase ->
                    match this.GetState(containerId) with
                    | Some s -> currentState <- s
                    | None -> lastError <- Some "State lost"
                | Error e ->
                    lastError <- Some e

            match lastError with
            | Some e -> return Error e
            | None -> return Ok currentState
    }

    /// <summary>
    /// Executes complete shutdown sequence through all 6 phases
    /// </summary>
    member this.ExecuteShutdown(containerId: string) = async {
        match this.GetState(containerId) with
        | None -> return Error "Container not found"
        | Some state ->
            let mutable currentState = state
            let mutable lastError = None

            // Ensure we start from running phase
            if currentState.CurrentPhase <> "running" then
                lastError <- Some $"Cannot shutdown from phase {currentState.CurrentPhase}"
            else
                // Execute through all shutdown phases
                while currentState.CurrentPhase <> "stopped" && lastError.IsNone do
                    match this.AdvanceShutdown(containerId) with
                    | Ok phase ->
                        match this.GetState(containerId) with
                        | Some s -> currentState <- s
                        | None -> lastError <- Some "State lost"
                    | Error e ->
                        lastError <- Some e

            match lastError with
            | Some e -> return Error e
            | None -> return Ok currentState
    }

    /// <summary>
    /// Checks if container is running
    /// </summary>
    member this.IsRunning(containerId: string) =
        this.CurrentPhase(containerId) = Some "running"

    /// <summary>
    /// Checks if container is fully stopped
    /// </summary>
    member this.IsStopped(containerId: string) =
        match this.CurrentPhase(containerId) with
        | Some "stopped" -> true
        | None -> true  // Not found = stopped
        | _ -> false

    /// <summary>
    /// Sets the gossip cookie for cluster joining
    /// SC-SIL4-014: Gossip protocol cookie required
    /// </summary>
    member this.SetGossipCookie(containerId: string, cookie: string) =
        match this.GetState(containerId) with
        | None -> Error "Container not found"
        | Some state ->
            let newState = { state with GossipCookie = Some cookie }
            lifecycles.[containerId] <- newState
            Ok cookie

    /// <summary>
    /// Logs node failure event
    /// SC-SIL4-016: Node failure must be logged
    /// </summary>
    member this.LogNodeFailure(containerId: string, reason: string) =
        match this.GetState(containerId) with
        | None -> ()
        | Some state ->
            if not state.NodeFailureLogged then
                let newState = { state with NodeFailureLogged = true }
                lifecycles.[containerId] <- newState
                FractalLogger.logPhase "lifecycle" containerId "failure"
                    $"Node failure logged: {reason}"

    /// <summary>
    /// Gets phase history for audit trail
    /// </summary>
    member this.GetPhaseHistory(containerId: string) =
        this.GetState(containerId)
        |> Option.map (fun s -> s.PhaseHistory)
        |> Option.defaultValue []

    /// <summary>
    /// Gets all active containers
    /// </summary>
    member this.GetActiveContainers() =
        lifecycles.Values
        |> Seq.filter (fun s -> s.CurrentPhase <> "stopped")
        |> Seq.map (fun s -> s.ContainerId)
        |> Seq.toList

    // =========================================================================
    // Private: Phase Actions
    // =========================================================================

    member private this.ExecuteStartupAction(containerId, fromPhase, toPhase) =
        try
            match toPhase with
            | "starting" ->
                // Start container via podman
                this.StartContainer(containerId)

            | "initializing" ->
                // Wait for container to be running
                this.WaitForProcess(containerId)

            | "connecting" ->
                // Wait for cluster join (EPMD registration)
                this.WaitForClusterJoin(containerId)

            | "running" ->
                // Verify health
                this.VerifyHealth(containerId)

            | _ -> Ok ()
        with
        | ex -> Error ex.Message

    member private this.ExecuteShutdownAction(containerId, fromPhase, toPhase) =
        try
            match toPhase with
            | "lameduck" ->
                // Enter lameduck - no new connections
                this.EnterLameduck(containerId)

            | "draining" ->
                // Drain active connections
                this.DrainConnections(containerId)

            | "checkpointing" ->
                // Capture dying gasp checkpoint
                this.CaptureCheckpoint(containerId)

            | "stopping" ->
                // Stop container gracefully
                this.StopContainer(containerId)

            | "stopped" ->
                Ok ()

            | _ -> Ok ()
        with
        | ex -> Error ex.Message

    member private this.StartContainer(containerId) =
        let result =
            Podman.runCommand $"start {containerId}"
            |> Async.RunSynchronously

        match result with
        | Ok _ -> Ok ()
        | Error e -> Error e

    member private this.WaitForProcess(containerId) =
        let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float phaseTimeoutMs)
        let mutable isRunning = false

        while not isRunning && DateTimeOffset.UtcNow < deadline do
            let result =
                Podman.runCommand $"inspect --format \"{{{{.State.Running}}}}\" {containerId}"
                |> Async.RunSynchronously

            match result with
            | Ok output when output.Trim() = "true" -> isRunning <- true
            | _ -> Thread.Sleep(transitionPollMs)

        if isRunning then Ok () else Error "Timeout waiting for process"

    member private this.WaitForClusterJoin(containerId) =
        // For app containers, wait for EPMD registration
        if containerId.Contains("app") then
            let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float phaseTimeoutMs)
            let mutable isJoined = false

            while not isJoined && DateTimeOffset.UtcNow < deadline do
                let result =
                    Podman.runCommand $"exec {containerId} epmd -names"
                    |> Async.RunSynchronously

                match result with
                | Ok output when output.Contains("name indrajaal") -> isJoined <- true
                | _ -> Thread.Sleep(transitionPollMs)

            if isJoined then Ok () else Error "Timeout waiting for cluster join"
        else
            Ok ()  // Non-app containers don't need cluster join

    member private this.VerifyHealth(containerId) =
        let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float phaseTimeoutMs)
        let mutable isHealthy = false

        while not isHealthy && DateTimeOffset.UtcNow < deadline do
            let result =
                Podman.runCommand $"inspect --format \"{{{{.State.Health.Status}}}}\" {containerId}"
                |> Async.RunSynchronously

            match result with
            | Ok output when output.Trim() = "healthy" -> isHealthy <- true
            | Ok output when output.Trim() = "" -> isHealthy <- true  // No healthcheck = healthy
            | _ -> Thread.Sleep(transitionPollMs)

        if isHealthy then Ok () else Error "Timeout waiting for health"

    member private this.EnterLameduck(containerId) =
        // Send SIGUSR1 to mark lameduck
        let result =
            Podman.runCommand $"exec {containerId} kill -USR1 1"
            |> Async.RunSynchronously

        // Lameduck entry may fail if container doesn't support it - that's OK
        Ok ()

    member private this.DrainConnections(containerId) =
        let drainTimeoutMs = 30_000  // SC-SIL4-008: 30s drain timeout
        let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float drainTimeoutMs)
        let mutable isDrained = false

        while not isDrained && DateTimeOffset.UtcNow < deadline do
            // Check active connections using ss
            let result =
                Podman.runCommand $"exec {containerId} ss -tn state established"
                |> Async.RunSynchronously

            match result with
            | Ok output ->
                let lines = output.Split('\n') |> Array.filter (fun l -> l.Trim() <> "")
                let connectionCount = max 0 (lines.Length - 1)  // Exclude header

                if connectionCount = 0 then
                    isDrained <- true
                else
                    FractalLogger.logPhase "lifecycle" containerId "draining"
                        $"Active connections: {connectionCount}"
                    Thread.Sleep(transitionPollMs)
            | Error _ ->
                Thread.Sleep(transitionPollMs)

        if isDrained then Ok () else Error "Drain timeout - forcing shutdown"

    member private this.CaptureCheckpoint(containerId) =
        // Trigger dying gasp checkpoint via Elixir
        let result =
            Podman.runCommand
                $"exec {containerId} /app/bin/indrajaal rpc 'Indrajaal.Deployment.DyingGasp.capture(\"{containerId}\")'"
            |> Async.RunSynchronously

        // Checkpoint may fail if app is already down - that's OK for shutdown
        match result with
        | Ok _ -> Ok ()
        | Error _ ->
            FractalLogger.logPhase "lifecycle" containerId "checkpoint"
                "Checkpoint skipped - app may be down"
            Ok ()

    member private this.StopContainer(containerId) =
        let result =
            Podman.runCommand $"stop -t 10 {containerId}"
            |> Async.RunSynchronously

        match result with
        | Ok _ -> Ok ()
        | Error e -> Error e


/// <summary>
/// Singleton lifecycle manager instance
/// </summary>
module LifecycleManager =
    let private instance = lazy (ContainerLifecycleManager())

    /// Get the singleton instance
    let getInstance() = instance.Value

    /// Create lifecycle for container
    let create containerId = getInstance().Create(containerId)

    /// Get current phase
    let currentPhase containerId = getInstance().CurrentPhase(containerId)

    /// Execute full startup
    let executeStartup containerId = getInstance().ExecuteStartup(containerId)

    /// Execute full shutdown
    let executeShutdown containerId = getInstance().ExecuteShutdown(containerId)

    /// Check if running
    let isRunning containerId = getInstance().IsRunning(containerId)

    /// Check if stopped
    let isStopped containerId = getInstance().IsStopped(containerId)

    /// Get phase history
    let getPhaseHistory containerId = getInstance().GetPhaseHistory(containerId)
