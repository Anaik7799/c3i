namespace Cepaf.Cockpit

open System
open System.Collections.Generic
open Cepaf.Cockpit.Domain

// =============================================================================
// SAFETY GUARDIAN (High Assurance Kernel) - ENHANCED
// =============================================================================
// Ported from: lib/indrajaal/safety/guardian.ex
// Compliance: SIL-2, SC-SEC-001, SC-FOUNDER-001
// Phase 6: The Immune Response (Antibodies)
// =============================================================================

module Safety =

    // -------------------------------------------------------------------------
    // SAFETY ENVELOPE (Limits)
    // -------------------------------------------------------------------------

    type Envelope = {
        MaxFlameNodes: int
        MaxRamMB: int
        MaxDbConnections: int
        ForbiddenOperations: string list
        WhitelistedNetworkDestinations: string list
    }

    let defaultEnvelope = {
        MaxFlameNodes = 50
        MaxRamMB = 16384 // 16GB
        MaxDbConnections = 100
        ForbiddenOperations = ["rm_rf"; "chmod_777"; "exec_unverified"]
        WhitelistedNetworkDestinations = ["localhost"; "127.0.0.1"; "indrajaal-db"; "indrajaal-obs"]
    }

    // -------------------------------------------------------------------------
    // TYPES
    // -------------------------------------------------------------------------

    type ProposalAction =
        | ScaleUp of Quantity: int
        | AllocateMemory of MB: int
        | OpenConnections of Count: int
        | ExecCode of Code: string
        | ExecCommand of Command: string
        | OpenLock of SensorData: Map<string, obj>
        | Energize of VoltageDeviation: float
        | NetworkCall of Destination: string
        | Custom of Name: string * Payload: obj

    type Proposal = {
        Id: string
        Action: ProposalAction
        Source: string
        Timestamp: DateTime
    }

    type ViolationReason =
        | ResourceLimitExceeded of string
        | ForbiddenOperation of string
        | DangerousPattern of string
        | UnsafePhysicalState of string
        | NetworkDestinationBlocked of string
        | FounderDirectiveViolation of string
        | AntibodyBlock of string // Phase 6: Immune system rejection
        | UnknownViolation of string

    type ValidationResult =
        | Approved of Proposal
        | Vetoed of Reason: ViolationReason * SafeFallback: Proposal

    /// Phase 6: Dynamic safety rule generated from experience
    type Antibody = {
        Id: Guid
        TargetPattern: string
        ExpiresAt: DateTime
        Reason: string
    }

    // -------------------------------------------------------------------------
    // LOGIC (Pure Functions)
    // -------------------------------------------------------------------------

    let private checkResourceBounds (envelope: Envelope) (action: ProposalAction) =
        match action with
        | ScaleUp q when q > envelope.MaxFlameNodes ->
            Error (ResourceLimitExceeded (sprintf "Max Flame Nodes: %d" envelope.MaxFlameNodes))
        | AllocateMemory mb when mb > envelope.MaxRamMB ->
            Error (ResourceLimitExceeded (sprintf "Max RAM: %d MB" envelope.MaxRamMB))
        | OpenConnections c when c > envelope.MaxDbConnections ->
            Error (ResourceLimitExceeded (sprintf "Max DB Connections: %d" envelope.MaxDbConnections))
        | _ -> Ok ()

    let private checkSecurity (envelope: Envelope) (action: ProposalAction) =
        match action with
        | ExecCommand cmd ->
            if List.contains cmd envelope.ForbiddenOperations then
                Error (ForbiddenOperation cmd)
            elif cmd.Contains("rm -rf") || cmd.Contains("chmod 777") then
                Error (DangerousPattern cmd)
            else Ok ()
        | _ -> Ok ()

    let private checkNetwork (envelope: Envelope) (action: ProposalAction) =
        match action with
        | NetworkCall dest ->
            if List.contains dest envelope.WhitelistedNetworkDestinations then Ok ()
            else Error (NetworkDestinationBlocked dest)
        | _ -> Ok ()

    let private checkPhysical (action: ProposalAction) =
        match action with
        | Energize deviation when abs(deviation) > 0.1 ->
            Error (UnsafePhysicalState (sprintf "Voltage deviation %.2f exceeds 0.1" deviation))
        | _ -> Ok ()

    /// Phase 6: Immune system check
    let private checkAntibodies (antibodies: Antibody list) (action: ProposalAction) =
        match action with
        | ExecCommand cmd ->
            antibodies 
            |> List.tryFind (fun a -> cmd.Contains(a.TargetPattern) && a.ExpiresAt > DateTime.UtcNow)
            |> Option.map (fun a -> Error (AntibodyBlock (sprintf "Blocked by Antibody %s: %s" (a.Id.ToString().Substring(0,8)) a.Reason)))
            |> Option.defaultValue (Ok ())
        | _ -> Ok ()

    let private generateFallback (envelope: Envelope) (proposal: Proposal) (reason: ViolationReason) =
        let fallbackAction =
            match proposal.Action with
            | ScaleUp _ -> ScaleUp envelope.MaxFlameNodes
            | AllocateMemory _ -> AllocateMemory envelope.MaxRamMB
            | OpenConnections _ -> OpenConnections envelope.MaxDbConnections
            | ExecCode _ -> ExecCommand "log_error 'Code execution vetoed'"
            | ExecCommand _ -> ExecCommand "log_error 'Command execution vetoed'"
            | NetworkCall _ -> ExecCommand "log_error 'Network call blocked'"
            | _ -> Custom ("NoOp", box "SafetyFallback")

        { proposal with Action = fallbackAction }

    /// The Atomic Gatekeeper Logic
    let validate (envelope: Envelope) (antibodies: Antibody list) (proposal: Proposal) : ValidationResult =
        let checks = [
            checkResourceBounds envelope proposal.Action
            checkSecurity envelope proposal.Action
            checkNetwork envelope proposal.Action
            checkPhysical proposal.Action
            checkAntibodies antibodies proposal.Action
        ]

        let firstError = checks |> List.tryPick (function Error e -> Some e | _ -> None)

        match firstError with
        | Some reason ->
            let fallback = generateFallback envelope proposal reason
            Vetoed (reason, fallback)
        | None ->
            Approved proposal

    // -------------------------------------------------------------------------
    // PHASE 6: DETECT PATTERN LOGIC (SC-IMMUNE-004)
    // -------------------------------------------------------------------------

    /// Configuration for pattern detection
    type PatternDetectionConfig = {
        /// How many occurrences trigger antibody synthesis
        SynthesisThreshold: int
        /// How long antibodies last (minutes)
        AntibodyLifetimeMinutes: float
        /// Maximum patterns to track
        MaxPatternsTracked: int
        /// Whether pattern detection is enabled
        Enabled: bool
    }

    let defaultPatternConfig = {
        SynthesisThreshold = 3
        AntibodyLifetimeMinutes = 30.0
        MaxPatternsTracked = 100
        Enabled = true
    }

    /// Failure event for pattern detection
    type FailureEvent = {
        SourceComponent: string
        FailureType: string
        Signature: string
        Timestamp: DateTime
        Details: string option
    }

    /// Internal pattern tracker state
    type PatternTrackerState = {
        Patterns: Map<string, FailurePattern>
        Config: PatternDetectionConfig
        TotalFailuresProcessed: int
        AntibodiesSynthesized: int
    }

    /// Generate pattern key from failure event
    let private patternKey (event: FailureEvent) =
        sprintf "%s:%s" event.SourceComponent event.FailureType

    /// Check if pattern should trigger antibody synthesis
    let private shouldSynthesizeAntibody (config: PatternDetectionConfig) (pattern: FailurePattern) =
        config.Enabled && pattern.OccurrenceCount >= config.SynthesisThreshold

    /// Create antibody from detected pattern
    let private synthesizeAntibody (config: PatternDetectionConfig) (pattern: FailurePattern) : Antibody =
        {
            Id = Guid.NewGuid()
            TargetPattern = pattern.FailureType
            ExpiresAt = DateTime.UtcNow.AddMinutes(config.AntibodyLifetimeMinutes)
            Reason = sprintf "Auto-generated from %d occurrences of '%s' in '%s'"
                        pattern.OccurrenceCount pattern.FailureType pattern.SourceComponent
        }

    /// Process a failure event and update patterns
    let private processFailureEvent (state: PatternTrackerState) (event: FailureEvent) : PatternTrackerState * Antibody option =
        let key = patternKey event

        let updatedPattern =
            match state.Patterns.TryFind key with
            | None ->
                // New pattern
                {
                    PatternId = Guid.NewGuid()
                    SourceComponent = event.SourceComponent
                    FailureType = event.FailureType
                    OccurrenceCount = 1
                    FirstSeen = event.Timestamp
                    LastSeen = event.Timestamp
                    Signatures = [event.Signature]
                }
            | Some existing ->
                // Update existing pattern
                {
                    existing with
                        OccurrenceCount = existing.OccurrenceCount + 1
                        LastSeen = event.Timestamp
                        Signatures = (event.Signature :: existing.Signatures) |> List.distinct |> List.truncate 10
                }

        let patterns = state.Patterns.Add(key, updatedPattern)

        // Check if this update triggers antibody synthesis
        let antibody =
            if shouldSynthesizeAntibody state.Config updatedPattern &&
               updatedPattern.OccurrenceCount = state.Config.SynthesisThreshold then
                // Only synthesize on threshold crossing, not every time after
                printfn "🧬 [PATTERN] Threshold reached for '%s' (%d occurrences) - synthesizing antibody"
                    key updatedPattern.OccurrenceCount
                Some (synthesizeAntibody state.Config updatedPattern)
            else
                None

        let newState = {
            state with
                Patterns = patterns
                TotalFailuresProcessed = state.TotalFailuresProcessed + 1
                AntibodiesSynthesized = state.AntibodiesSynthesized + (if antibody.IsSome then 1 else 0)
        }

        (newState, antibody)

    /// Prune expired antibodies
    let private pruneExpiredAntibodies (antibodies: Antibody list) =
        let now = DateTime.UtcNow
        antibodies |> List.filter (fun a -> a.ExpiresAt > now)

    // -------------------------------------------------------------------------
    // AGENT (Thread-Based)
    // -------------------------------------------------------------------------

    type GuardianMsg =
        | ValidateProposal of Proposal * AsyncReplyChannel<ValidationResult>
        | UpdateEnvelope of Envelope
        | InjectAntibody of Antibody // Phase 6
        | GetStatus of AsyncReplyChannel<string>
        // Phase 6: Pattern Detection Messages
        | ReportFailure of FailureEvent
        | GetPatternStats of AsyncReplyChannel<PatternTrackerState>
        | SetPatternDetectionEnabled of bool
        | PruneExpired

    type GuardianAgent(?eventBus: TelemetryEvent -> unit) =
        let emitEvent = defaultArg eventBus (fun _ -> ())
        let initialPatternState = {
            Patterns = Map.empty
            Config = defaultPatternConfig
            TotalFailuresProcessed = 0
            AntibodiesSynthesized = 0
        }

        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop (envelope: Envelope) (antibodies: Antibody list) (patternState: PatternTrackerState) = async {
                try
                    let! msg = inbox.Receive()
                    match msg with
                    | ValidateProposal (proposal, reply) ->
                        let result = validate envelope antibodies proposal
                        reply.Reply(result)
                        return! loop envelope antibodies patternState

                    | UpdateEnvelope newEnvelope ->
                        return! loop newEnvelope antibodies patternState

                    | InjectAntibody antibody ->
                        printfn "🧬 [GUARDIAN] New Antibody Synthesized: %s (Blocks: '%s')" (antibody.Id.ToString().Substring(0,8)) antibody.TargetPattern
                        emitEvent (AntibodySynthesized (antibody.Id.ToString().Substring(0,8), antibody.TargetPattern))
                        return! loop envelope (antibody :: antibodies) patternState

                    | GetStatus reply ->
                        let prunedAntibodies = pruneExpiredAntibodies antibodies
                        reply.Reply(sprintf "Guardian Active (SIL-2) - Active Antibodies: %d, Patterns Tracked: %d, Total Failures: %d"
                            prunedAntibodies.Length patternState.Patterns.Count patternState.TotalFailuresProcessed)
                        return! loop envelope prunedAntibodies patternState

                    // ─────────────────────────────────────────────────────────────
                    // PHASE 6: PATTERN DETECTION (SC-IMMUNE-004)
                    // ─────────────────────────────────────────────────────────────

                    | ReportFailure event ->
                        printfn "📊 [PATTERN] Recording failure: %s:%s - '%s'" event.SourceComponent event.FailureType event.Signature
                        let (newPatternState, maybeAntibody) = processFailureEvent patternState event

                        // If antibody was synthesized, inject it
                        match maybeAntibody with
                        | Some antibody ->
                            printfn "🧬 [PATTERN] Auto-synthesizing antibody for pattern '%s:%s'" event.SourceComponent event.FailureType
                            emitEvent (AntibodySynthesized (antibody.Id.ToString().Substring(0,8), antibody.TargetPattern))
                            return! loop envelope (antibody :: antibodies) newPatternState
                        | None ->
                            return! loop envelope antibodies newPatternState

                    | GetPatternStats reply ->
                        reply.Reply(patternState)
                        return! loop envelope antibodies patternState

                    | SetPatternDetectionEnabled enabled ->
                        let newConfig = { patternState.Config with Enabled = enabled }
                        let newPatternState = { patternState with Config = newConfig }
                        printfn "⚙️ [PATTERN] Pattern detection %s" (if enabled then "ENABLED" else "DISABLED")
                        return! loop envelope antibodies newPatternState

                    | PruneExpired ->
                        let prunedAntibodies = pruneExpiredAntibodies antibodies
                        let pruned = antibodies.Length - prunedAntibodies.Length
                        if pruned > 0 then
                            printfn "🧹 [GUARDIAN] Pruned %d expired antibodies" pruned
                        return! loop envelope prunedAntibodies patternState

                with ex ->
                    printfn "🔴 GUARDIAN CRASHED: %s" ex.Message
                    // Restart with default envelope
                    return! loop envelope antibodies patternState
            }
            loop defaultEnvelope [] initialPatternState
        )

        member this.Validate(proposal: Proposal) =
            agent.PostAndAsyncReply(fun reply -> ValidateProposal(proposal, reply))

        member this.Status() =
            agent.PostAndAsyncReply(fun reply -> GetStatus(reply))

        member this.Inject(antibody) =
            agent.Post(InjectAntibody antibody)

        // Phase 6: Pattern Detection Methods (SC-IMMUNE-004)
        member this.ReportFailure(source, failureType, signature, ?details) =
            agent.Post(ReportFailure {
                SourceComponent = source
                FailureType = failureType
                Signature = signature
                Timestamp = DateTime.UtcNow
                Details = details
            })

        member this.GetPatternStats() =
            agent.PostAndAsyncReply(GetPatternStats)

        member this.EnablePatternDetection() =
            agent.Post(SetPatternDetectionEnabled true)

        member this.DisablePatternDetection() =
            agent.Post(SetPatternDetectionEnabled false)

        member this.PruneExpiredAntibodies() =
            agent.Post(PruneExpired)