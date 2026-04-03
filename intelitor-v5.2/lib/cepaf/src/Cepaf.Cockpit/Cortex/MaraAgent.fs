namespace Cepaf.Cockpit.Cortex

open System
open System.Diagnostics
open System.Threading
open Cepaf.Cockpit.Domain

// =============================================================================
// MaraAgent.fs - The Chaos Engineering Agent (ENHANCED WITH REAL PODMAN FFI)
// =============================================================================
// Phase: 6 (The Immune Response)
// Criticality: P0 (CRITICAL)
// STAMP: SC-CHAOS-001 (Controlled Chaos), SC-CHAOS-002 (Kill Switch)
// =============================================================================

module Chaos =

    // -------------------------------------------------------------------------
    // CHAOS TYPES
    // -------------------------------------------------------------------------

    type ChaosAction =
        | KillContainer of containerName: string
        | StopContainer of containerName: string
        | InjectLatency of target: string * ms: int
        | CorruptState of holonId: string
        | SimulateNetworkPartition of nodeA: string * nodeB: string
        | ExhaustMemory of containerName: string * mbToConsume: int
        | FillDisk of containerName: string * mbToFill: int

    type ChaosResult = {
        Action: ChaosAction
        Timestamp: DateTime
        Success: bool
        ImpactScore: float
        ExecutionTimeMs: int64
        ErrorMessage: string option
    }

    /// Safety configuration for Mara (SC-CHAOS-002: Kill Switch)
    type MaraConfig = {
        /// Containers that can NEVER be targeted
        ProtectedContainers: Set<string>
        /// Maximum chaos events per hour (rate limiting)
        MaxEventsPerHour: int
        /// Lease timeout - Mara auto-stops after this many seconds
        LeaseTimeoutSeconds: int
        /// Whether Mara is currently allowed to strike
        Enabled: bool
        /// Require Guardian approval before each strike
        RequireGuardianApproval: bool
    }

    let defaultMaraConfig = {
        ProtectedContainers = Set.ofList [
            "indrajaal-db-prod"  // NEVER kill database
            "zenoh-router"       // NEVER kill control plane
        ]
        MaxEventsPerHour = 10
        LeaseTimeoutSeconds = 300  // 5 minute lease
        Enabled = false           // DISABLED by default for safety
        RequireGuardianApproval = true
    }

    // -------------------------------------------------------------------------
    // PODMAN FFI EXECUTION (REAL CONTAINER OPERATIONS)
    // -------------------------------------------------------------------------

    /// Execute a podman command and return result
    let private execPodman (args: string) : Result<string, string> =
        try
            let psi = ProcessStartInfo(
                FileName = "podman",
                Arguments = args,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            )
            use proc = Process.Start(psi)
            proc.WaitForExit(30000) |> ignore
            if proc.ExitCode = 0 then
                Ok (proc.StandardOutput.ReadToEnd().Trim())
            else
                Error (proc.StandardError.ReadToEnd().Trim())
        with ex ->
            Error ex.Message

    /// Kill a container (SIGKILL - immediate termination)
    let private killContainer (name: string) =
        printfn "💀 [MARA] Executing KILL on container: %s" name
        execPodman (sprintf "kill %s" name)

    /// Stop a container (SIGTERM - graceful shutdown)
    let private stopContainer (name: string) =
        printfn "🛑 [MARA] Executing STOP on container: %s" name
        execPodman (sprintf "stop -t 5 %s" name)

    /// Check if a container exists and is running
    let private isContainerRunning (name: string) =
        match execPodman (sprintf "inspect -f '{{.State.Running}}' %s" name) with
        | Ok output -> output.Contains("true")
        | Error _ -> false

    // -------------------------------------------------------------------------
    // CHAOS EXECUTION ENGINE
    // -------------------------------------------------------------------------

    type MaraMsg =
        | Strike of ChaosAction * AsyncReplyChannel<ChaosResult>
        | StrikeNoWait of ChaosAction
        | StartAutonomicMode of intervalMs: int
        | StopAutonomicMode
        | GetStrikeHistory of AsyncReplyChannel<ChaosResult list>
        | GetConfig of AsyncReplyChannel<MaraConfig>
        | UpdateConfig of MaraConfig
        | Enable
        | Disable
        | GetStats of AsyncReplyChannel<{| TotalStrikes: int; SuccessRate: float; LastStrike: DateTime option |}>

    type MaraAgent(eventBus: TelemetryEvent -> unit, ?config: MaraConfig) =
        let mutable currentConfig = defaultArg config defaultMaraConfig
        let history = ResizeArray<ChaosResult>()
        let mutable autonomicTimer: Timer = null
        let leaseStartTime = ref DateTime.UtcNow
        let strikesThisHour = ref 0
        let lastHourReset = ref DateTime.UtcNow

        /// Check if strike is allowed by safety rules
        let canStrike (action: ChaosAction) =
            if not currentConfig.Enabled then
                Error "Mara is DISABLED. Enable with .Enable() before striking."
            else
                // Check lease timeout (SC-CHAOS-002)
                let elapsed = (DateTime.UtcNow - !leaseStartTime).TotalSeconds
                if elapsed > float currentConfig.LeaseTimeoutSeconds then
                    currentConfig <- { currentConfig with Enabled = false }
                    Error (sprintf "Lease expired after %d seconds. Mara auto-disabled." currentConfig.LeaseTimeoutSeconds)
                else
                    // Check rate limiting
                    if (DateTime.UtcNow - !lastHourReset).TotalHours >= 1.0 then
                        strikesThisHour := 0
                        lastHourReset := DateTime.UtcNow

                    if !strikesThisHour >= currentConfig.MaxEventsPerHour then
                        Error (sprintf "Rate limit exceeded: %d/%d events this hour" !strikesThisHour currentConfig.MaxEventsPerHour)
                    else
                        // Check protected containers
                        match action with
                        | KillContainer name | StopContainer name ->
                            if currentConfig.ProtectedContainers.Contains name then
                                Error (sprintf "Container '%s' is PROTECTED and cannot be targeted" name)
                            else
                                Ok ()
                        | _ -> Ok ()

        /// Execute a chaos action
        let execute (action: ChaosAction) : ChaosResult =
            let sw = Stopwatch.StartNew()

            match canStrike action with
            | Error reason ->
                printfn "🚫 [MARA] Strike BLOCKED: %s" reason
                {
                    Action = action
                    Timestamp = DateTime.UtcNow
                    Success = false
                    ImpactScore = 0.0
                    ExecutionTimeMs = sw.ElapsedMilliseconds
                    ErrorMessage = Some reason
                }
            | Ok () ->
                strikesThisHour := !strikesThisHour + 1
                printfn "⚡ [MARA] STRIKE INITIATED: %A" action

                let (success, errorMsg, impact) =
                    match action with
                    | KillContainer name ->
                        if isContainerRunning name then
                            match killContainer name with
                            | Ok _ ->
                                eventBus (ContainerHealth (ContainerDied (name, DateTime.UtcNow, "Killed by Mara chaos agent")))
                                eventBus (AnomalyDetected (sprintf "Container '%s' killed by chaos agent" name, "CRITICAL"))
                                (true, None, 0.9)
                            | Error e ->
                                (false, Some e, 0.0)
                        else
                            (false, Some (sprintf "Container '%s' is not running" name), 0.0)

                    | StopContainer name ->
                        if isContainerRunning name then
                            match stopContainer name with
                            | Ok _ ->
                                eventBus (ContainerHealth (ContainerStopped (name, DateTime.UtcNow, 0)))
                                eventBus (AnomalyDetected (sprintf "Container '%s' stopped by chaos agent" name, "WARNING"))
                                (true, None, 0.7)
                            | Error e ->
                                (false, Some e, 0.0)
                        else
                            (false, Some (sprintf "Container '%s' is not running" name), 0.0)

                    | InjectLatency (target, ms) ->
                        printfn "⏱️ [MARA] Simulating %dms latency on %s" ms target
                        eventBus (MetricLogged (sprintf "Latency:%s" target, float ms))
                        (true, None, 0.5)

                    | CorruptState holonId ->
                        printfn "🔥 [MARA] Simulating state corruption for holon: %s" holonId
                        eventBus (AnomalyDetected (sprintf "State corruption simulated for holon '%s'" holonId, "WARNING"))
                        (true, None, 0.6)

                    | SimulateNetworkPartition (nodeA, nodeB) ->
                        printfn "🔌 [MARA] Simulating network partition between %s and %s" nodeA nodeB
                        eventBus (AnomalyDetected (sprintf "Network partition between '%s' and '%s'" nodeA nodeB, "CRITICAL"))
                        (true, None, 0.8)

                    | ExhaustMemory (name, mb) ->
                        printfn "💾 [MARA] Simulating memory exhaustion (%dMB) on %s" mb name
                        eventBus (AnomalyDetected (sprintf "Memory pressure on '%s' (simulated)" name, "WARNING"))
                        (true, None, 0.4)

                    | FillDisk (name, mb) ->
                        printfn "💿 [MARA] Simulating disk fill (%dMB) on %s" mb name
                        eventBus (AnomalyDetected (sprintf "Disk pressure on '%s' (simulated)" name, "WARNING"))
                        (true, None, 0.3)

                sw.Stop()
                let result = {
                    Action = action
                    Timestamp = DateTime.UtcNow
                    Success = success
                    ImpactScore = impact
                    ExecutionTimeMs = sw.ElapsedMilliseconds
                    ErrorMessage = errorMsg
                }
                history.Add(result)

                if success then
                    printfn "✅ [MARA] Strike completed in %dms (Impact: %.2f)" sw.ElapsedMilliseconds impact
                else
                    printfn "❌ [MARA] Strike failed: %s" (Option.defaultValue "Unknown error" errorMsg)

                result

        let agentRef : MailboxProcessor<MaraMsg> ref = ref Unchecked.defaultof<_>
        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop () = async {
                let! msg = inbox.Receive()
                match msg with
                | Strike (action, reply) ->
                    let result = execute action
                    reply.Reply(result)
                    return! loop ()

                | StrikeNoWait action ->
                    let _ = execute action
                    return! loop ()

                | StartAutonomicMode interval ->
                    printfn "🤖 [MARA] Autonomic Chaos Mode ENABLED (Interval: %dms)" interval
                    if autonomicTimer <> null then autonomicTimer.Dispose()

                    let rng = Random()
                    autonomicTimer <- new Timer((fun _ ->
                        let targetList = ["indrajaal-ex-app-1"; "indrajaal-ex-app-2"; "indrajaal-ex-app-3"; "indrajaal-chaya"; "indrajaal-cortex"]
                        let target = targetList.[rng.Next(targetList.Length)]
                        let action =
                            match rng.Next(3) with
                            | 0 -> KillContainer target
                            | 1 -> StopContainer target
                            | _ -> InjectLatency (target, rng.Next(100, 1000))

                        (!agentRef).Post(StrikeNoWait action)
                    ), null, interval, interval)
                    return! loop ()

                | StopAutonomicMode ->
                    printfn "🤖 [MARA] Autonomic Chaos Mode DISABLED"
                    if autonomicTimer <> null then autonomicTimer.Dispose()
                    autonomicTimer <- null
                    return! loop ()

                | GetStrikeHistory reply ->
                    reply.Reply(history |> Seq.toList)
                    return! loop ()

                | GetConfig reply ->
                    reply.Reply(currentConfig)
                    return! loop ()

                | UpdateConfig newConfig ->
                    currentConfig <- newConfig
                    printfn "⚙️ [MARA] Configuration updated"
                    return! loop ()

                | Enable ->
                    currentConfig <- { currentConfig with Enabled = true }
                    leaseStartTime := DateTime.UtcNow
                    printfn "🟢 [MARA] ENABLED (Lease: %ds)" currentConfig.LeaseTimeoutSeconds
                    return! loop ()

                | Disable ->
                    currentConfig <- { currentConfig with Enabled = false }
                    printfn "🔴 [MARA] DISABLED"
                    return! loop ()

                | GetStats reply ->
                    let total = history.Count
                    let successful = history |> Seq.filter (fun r -> r.Success) |> Seq.length
                    let rate = if total > 0 then float successful / float total else 0.0
                    let last = if history.Count > 0 then Some history.[history.Count - 1].Timestamp else None
                    reply.Reply({| TotalStrikes = total; SuccessRate = rate; LastStrike = last |})
                    return! loop ()
            }
            loop ()
        )
        do agentRef.Value <- agent

        // Public API
        member this.Attack(action) = agent.PostAndAsyncReply(fun reply -> Strike(action, reply))
        member this.AttackNoWait(action) = agent.Post(StrikeNoWait action)
        member this.StartAutonomic(intervalMs) = agent.Post(StartAutonomicMode intervalMs)
        member this.StopAutonomic() = agent.Post(StopAutonomicMode)
        member this.History() = agent.PostAndAsyncReply(GetStrikeHistory)
        member this.Config() = agent.PostAndAsyncReply(GetConfig)
        member this.Enable() = agent.Post(Enable)
        member this.Disable() = agent.Post(Disable)
        member this.Stats() = agent.PostAndAsyncReply(GetStats)

        /// Convenience method to kill a container (with safety checks)
        member this.Kill(containerName) = this.Attack(KillContainer containerName)

        /// Convenience method to stop a container (with safety checks)
        member this.Stop(containerName) = this.Attack(StopContainer containerName)
