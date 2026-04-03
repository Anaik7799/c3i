namespace Cepaf.Cockpit

open System
open System.Diagnostics
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Safety

/// ═══════════════════════════════════════════════════════════════════════════════
/// PRAJNA ORCHESTRATOR - Cognitive State Machine with Healing Reflex
/// ═══════════════════════════════════════════════════════════════════════════
///
/// WHAT: The central Agent managing the Cockpit OODA loop, session state,
///       and PHASE 6 Immune System healing reflex.
/// WHY: Replaces Elixir GenServer to eliminate cross-runtime latency.
/// STAMP: SC-THR-002 (Supervised), SC-HMI-004 (Two-Key-Turn), SC-IMMUNE-001 (Healing)
/// Phase: 6 (The Immune Response)
/// ═══════════════════════════════════════════════════════════════════════════

module Orchestrator =

    // -------------------------------------------------------------------------
    // HEALING REFLEX LOGIC (SC-IMMUNE-001)
    // -------------------------------------------------------------------------

    /// Execute container restart via Podman
    let private restartContainer (containerId: string) =
        try
            let psi = ProcessStartInfo(
                FileName = "podman",
                Arguments = sprintf "restart %s" containerId,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            )
            use proc = Process.Start(psi)
            proc.WaitForExit(30000) |> ignore // 30s timeout
            if proc.ExitCode = 0 then
                printfn "🏥 [HEALING] Container '%s' restarted successfully" containerId
                Ok containerId
            else
                let err = proc.StandardError.ReadToEnd()
                printfn "🔴 [HEALING] Failed to restart '%s': %s" containerId err
                Error err
        with ex ->
            printfn "🔴 [HEALING] Exception restarting '%s': %s" containerId ex.Message
            Error ex.Message

    /// Check if container is in HA set and eligible for healing
    let private shouldHeal (healingState: HealingState) (containerId: string) =
        let config = healingState.Config
        if not config.HealingEnabled then
            false
        elif not (config.HaSet.Contains containerId) then
            printfn "⚠️ [HEALING] Container '%s' not in HA set, skipping" containerId
            false
        else
            match healingState.RestartTrackers.TryFind containerId with
            | None -> true
            | Some tracker ->
                if tracker.AttemptCount >= config.MaxRestartAttempts then
                    printfn "🔴 [HEALING] Container '%s' exceeded max restart attempts (%d)" containerId config.MaxRestartAttempts
                    false
                else
                    let elapsed = (DateTime.UtcNow - tracker.LastAttemptAt).TotalMilliseconds
                    if elapsed < float config.RestartCooldownMs then
                        printfn "⏳ [HEALING] Container '%s' in cooldown (%.0fms remaining)" containerId (float config.RestartCooldownMs - elapsed)
                        false
                    else
                        true

    /// Update restart tracker after a healing attempt
    let private updateRestartTracker (healingState: HealingState) (containerId: string) (reason: string) =
        let tracker =
            match healingState.RestartTrackers.TryFind containerId with
            | None ->
                { ContainerId = containerId
                  AttemptCount = 1
                  LastAttemptAt = DateTime.UtcNow
                  FailureReasons = [reason] }
            | Some t ->
                { t with
                    AttemptCount = t.AttemptCount + 1
                    LastAttemptAt = DateTime.UtcNow
                    FailureReasons = reason :: t.FailureReasons |> List.truncate 10 }
        { healingState with
            RestartTrackers = healingState.RestartTrackers.Add(containerId, tracker)
            AutomationMode = AutoHealing
            LastHealingAction = Some DateTime.UtcNow }

    /// Reset tracker on successful container recovery
    let private resetRestartTracker (healingState: HealingState) (containerId: string) =
        { healingState with
            RestartTrackers = healingState.RestartTrackers.Remove containerId
            AutomationMode = NormalOps }

    // -------------------------------------------------------------------------
    // ORCHESTRATOR MESSAGES
    // -------------------------------------------------------------------------

    type OrchestratorMsg =
        | ProcessTelemetry of NodeId * obj
        | ConnectionStatusChanged of ConnectionStatus
        | ProposeAction of Proposal * AsyncReplyChannel<ValidationResult>
        | ArmCommand of CommandId * NodeId * MeshCommand
        | ConfirmCommand of CommandId * string option // Second key
        | GetState of AsyncReplyChannel<CockpitState>
        | Heartbeat
        | Shutdown
        // Phase 6: Immune System Messages
        | ContainerEvent of ContainerHealthEvent
        | GetHealingState of AsyncReplyChannel<HealingState>
        | SetHealingEnabled of bool
        // Phase 7: Federation Messages
        | UpdateFederationHealth of FederationHealth
        // Phase 8: Economic Messages
        | UpdateEconomicHealth of EconomicLedger
        // Phase 10: Git Evolution
        | UpdateRecentCommits of GitCommit list

    type OrchestratorAgent(operatorId: string, guardian: GuardianAgent, ?eventBus: TelemetryEvent -> unit) =
        let initialState = Domain.createCockpitState operatorId
        let initialHealingState = Domain.createHealingState Domain.defaultHaConfig
        let emitEvent = defaultArg eventBus (fun _ -> ())

        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop (state: CockpitState) (healingState: HealingState) = async {
                try
                    let! msg = inbox.Receive()
                    match msg with
                    | ProcessTelemetry (nodeId, data) ->
                        // L2 Reflex: Update metrics and check for anomalies
                        let newState = { state with MessagesReceived = state.MessagesReceived + 1; LastMessageAt = Some DateTime.UtcNow }
                        return! loop newState healingState

                    | ConnectionStatusChanged status ->
                        // Phase 2: Handle Network Partition
                        printfn "[ORCHESTRATOR] Connection Status Changed: %A" status
                        return! loop state healingState

                    | ProposeAction (proposal, reply) ->
                        // L3 Reflex: Delegate to Guardian
                        let! verdict = guardian.Validate(proposal)
                        reply.Reply(verdict)
                        return! loop state healingState

                    | ArmCommand (cmdId, nodeId, cmd) ->
                        let record = {
                            Id = cmdId
                            TargetNodeId = nodeId
                            Command = cmd
                            State = CommandState.Armed
                            ArmedAt = Some DateTime.UtcNow
                            ExecutedAt = None
                            AcknowledgedAt = None
                            ErrorMessage = None
                            RequiresConfirmation = Domain.isCriticalCommand cmd
                        }
                        let newState = { state with PendingCommands = state.PendingCommands.Add(cmdId, record) }
                        return! loop newState healingState

                    | ConfirmCommand (cmdId, secondKey) ->
                        match state.PendingCommands.TryFind cmdId with
                        | Some record when record.State = CommandState.Armed ->
                            // SC-HMI-004: Two-Step Commit Check
                            if record.RequiresConfirmation && secondKey.IsNone then
                                let failed = { record with State = CommandState.Failed; ErrorMessage = Some "Second Key Required" }
                                return! loop { state with PendingCommands = state.PendingCommands.Add(cmdId, failed) } healingState
                            else
                                let executing = { record with State = CommandState.Executing; ExecutedAt = Some DateTime.UtcNow }
                                // Emit to Zenoh here
                                return! loop { state with PendingCommands = state.PendingCommands.Add(cmdId, executing) } healingState
                        | _ -> return! loop state healingState

                    | GetState reply ->
                        reply.Reply(state)
                        return! loop state healingState

                    | Heartbeat ->
                        // SC-THR-002: Pulse check
                        return! loop state healingState

                    | Shutdown ->
                        return ()

                    // ─────────────────────────────────────────────────────────────
                    // PHASE 6: IMMUNE SYSTEM - HEALING REFLEX (SC-IMMUNE-001)
                    // ─────────────────────────────────────────────────────────────

                    | ContainerEvent event ->
                        match event with
                        | ContainerDied (containerId, timestamp, reason) ->
                            printfn "💀 [IMMUNE] Container '%s' died at %s: %s" containerId (timestamp.ToString("HH:mm:ss")) reason
                            emitEvent (ContainerHealth event)

                            if shouldHeal healingState containerId then
                                printfn "🏥 [IMMUNE] Initiating healing reflex for '%s'" containerId
                                emitEvent (HealingTriggered (containerId, "restart"))

                                // Update tracker before attempting restart
                                let newHealingState = updateRestartTracker healingState containerId reason

                                // Attempt restart (fire-and-forget for non-blocking)
                                async {
                                    match restartContainer containerId with
                                    | Ok _ ->
                                        // Report success via Guardian (for antibody learning)
                                        guardian.Inject({
                                            Id = Guid.NewGuid()
                                            TargetPattern = sprintf "container_death:%s" containerId
                                            ExpiresAt = DateTime.UtcNow.AddMinutes(5.0) // Short-lived protective antibody
                                            Reason = sprintf "Auto-healing response to container death: %s" reason
                                        })
                                    | Error _ -> ()
                                } |> Async.Start

                                return! loop state newHealingState
                            else
                                return! loop state healingState

                        | ContainerHealthy (containerId, timestamp) ->
                            printfn "💚 [IMMUNE] Container '%s' recovered at %s" containerId (timestamp.ToString("HH:mm:ss"))
                            emitEvent (ContainerHealth event)
                            // Reset tracker on successful recovery
                            let newHealingState = resetRestartTracker healingState containerId
                            return! loop state newHealingState

                        | ContainerUnhealthy (containerId, timestamp, checkOutput) ->
                            printfn "🟡 [IMMUNE] Container '%s' unhealthy at %s: %s" containerId (timestamp.ToString("HH:mm:ss")) checkOutput
                            emitEvent (ContainerHealth event)
                            return! loop state healingState

                        | ContainerRestarted (containerId, timestamp, attempt) ->
                            printfn "🔄 [IMMUNE] Container '%s' restarted (attempt %d) at %s" containerId attempt (timestamp.ToString("HH:mm:ss"))
                            emitEvent (ContainerHealth event)
                            return! loop state healingState

                        | _ ->
                            emitEvent (ContainerHealth event)
                            return! loop state healingState

                    | GetHealingState reply ->
                        reply.Reply(healingState)
                        return! loop state healingState

                    | SetHealingEnabled enabled ->
                        let newConfig = { healingState.Config with HealingEnabled = enabled }
                        let newHealingState = { healingState with Config = newConfig }
                        printfn "⚙️ [IMMUNE] Healing %s" (if enabled then "ENABLED" else "DISABLED")
                        return! loop state newHealingState

                    | UpdateFederationHealth health ->
                        let newState = { state with Federation = Some health }
                        return! loop newState healingState

                    | UpdateEconomicHealth health ->
                        let newState = { state with Economics = Some health }
                        return! loop newState healingState

                    | UpdateRecentCommits commits ->
                        let newState = { state with RecentCommits = commits }
                        return! loop newState healingState

                with ex ->
                    // AOR-THR-002: Let it crash locally and restart
                    printfn "🔴 ORCHESTRATOR CRASHED: %s" ex.Message
                    return! loop state healingState
            }
            loop initialState initialHealingState
        )

        member this.Propose(proposal) = agent.PostAndAsyncReply(fun reply -> ProposeAction(proposal, reply))
        member this.GetState() = agent.PostAndAsyncReply(GetState)
        member this.Arm(nodeId, cmd) = agent.Post(ArmCommand(Domain.generateId(), nodeId, cmd))
        member this.Confirm(cmdId, key) = agent.Post(ConfirmCommand(cmdId, key))
        member this.ProcessTelemetry(nodeId, data) = agent.Post(ProcessTelemetry(nodeId, data))

        // Phase 6: Immune System Methods (SC-IMMUNE-001)
        member this.ReportContainerEvent(event) = agent.Post(ContainerEvent event)
        member this.GetHealingState() = agent.PostAndAsyncReply(GetHealingState)
        member this.EnableHealing() = agent.Post(SetHealingEnabled true)
        member this.DisableHealing() = agent.Post(SetHealingEnabled false)
        member this.ReportFederationHealth(health) = agent.Post(UpdateFederationHealth health)

        /// Convenience method to report a container death
        member this.ReportContainerDeath(containerId, reason) =
            agent.Post(ContainerEvent (ContainerDied (containerId, DateTime.UtcNow, reason)))

        /// Convenience method to report container recovery
        member this.ReportContainerHealthy(containerId) =
            agent.Post(ContainerEvent (ContainerHealthy (containerId, DateTime.UtcNow)))
