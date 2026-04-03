namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain

/// =============================================================================
/// GUARDIAN INTEGRATION - Two-Way Safety Validation for Prajna Commands
/// =============================================================================
///
/// WHAT: Bridges Prajna Cockpit commands to Guardian for safety validation.
/// WHY: SC-PRAJNA-001 requires all Prajna commands pass Guardian pre-approval.
///
/// ## Architecture
///
/// ```
///   Prajna.Command  -->  GuardianIntegration  -->  Guardian.validate
///                              |
///               +-------+------+------+
///               |                     |
///         {:ok, approved}      {:veto, reason, fallback}
///               |                     |
///         Execute command       Execute fallback
/// ```
///
/// STAMP Constraints:
///   - SC-PRAJNA-001: All commands through Guardian pre-approval
///   - SC-PRAJNA-003: State changes via Immutable Register
///   - SC-CONST-007: Guardian has absolute veto
///   - SC-GDE-001: Guardian validation required
///
/// AOR Rules:
///   - AOR-PRAJNA-001: Prajna commands MUST pass Guardian validation
///   - AOR-PRAJNA-003: State mutations MUST be logged to Immutable Register
///
/// Document Control:
///   | Field | Value |
///   |-------|-------|
///   | Version | 21.1.0 |
///   | Created | 2026-01-01 |
///   | Author | Cybernetic Architect |
///   | STAMP | SC-PRAJNA-001, SC-CONST-007 |
///
/// =============================================================================
module GuardianIntegration =

    // =========================================================================
    // TYPE DEFINITIONS
    // =========================================================================

    /// Command type classification for Guardian routing
    type CommandType =
        | Reconfiguration
        | DataMutation
        | SystemAction
        | AiSuggestion
        | UserCommand

    /// Proposal for Guardian validation
    type Proposal = {
        Source: string
        Command: Map<string, obj>
        CommandType: CommandType
        Timestamp: DateTimeOffset
        Context: ProposalContext
        Metadata: ProposalMetadata
    }

    and ProposalContext = {
        SessionId: string
        UserId: string option
        SourceModule: string
    }

    and ProposalMetadata = {
        Priority: string
        Idempotent: bool
        Reversible: bool
    }

    /// Guardian approval result
    type ApprovalResult =
        | Approved of ApprovedCommand
        | Vetoed of VetoResult
        | Error of string

    and ApprovedCommand = {
        Command: Map<string, obj>
        ApprovedAt: DateTimeOffset
        GuardianVersion: string
        ApprovalToken: string
    }

    and VetoResult = {
        Reason: string
        Fallback: FallbackAction
    }

    and FallbackAction = {
        Action: string
        Reason: string
        Message: string
    }

    /// Guardian health status
    type GuardianHealth = {
        Status: string
        LastCheck: DateTimeOffset
        Error: string option
    }

    // =========================================================================
    // PRIVATE STATE
    // =========================================================================

    let mutable private sessionId: string option = None

    let private generateSessionId () =
        let bytes = Array.zeroCreate<byte> 8
        use rng = System.Security.Cryptography.RandomNumberGenerator.Create()
        rng.GetBytes(bytes)
        sessionId <- Some (BitConverter.ToString(bytes).Replace("-", "").ToLower())
        sessionId.Value

    let private getSessionId () =
        match sessionId with
        | Some id -> id
        | None -> generateSessionId ()

    let private generateApprovalToken (command: Map<string, obj>) (timestamp: DateTimeOffset) =
        let data = sprintf "%A%s" command (timestamp.ToString("o"))
        use sha256 = System.Security.Cryptography.SHA256.Create()
        let hash = sha256.ComputeHash(System.Text.Encoding.UTF8.GetBytes(data))
        BitConverter.ToString(hash).Replace("-", "").ToLower().Substring(0, 16)

    // =========================================================================
    // PUBLIC API
    // =========================================================================

    /// Build a proposal from command map
    let buildProposal (command: Map<string, obj>) : Proposal =
        let cmdType =
            match command.TryFind "type" with
            | Some (:? string as t) when t = "reconfiguration" -> Reconfiguration
            | Some (:? string as t) when t = "data_mutation" -> DataMutation
            | Some (:? string as t) when t = "system_action" -> SystemAction
            | Some (:? string as t) when t = "ai_suggestion" -> AiSuggestion
            | _ -> UserCommand

        {
            Source = "prajna_cockpit"
            Command = command
            CommandType = cmdType
            Timestamp = DateTimeOffset.UtcNow
            Context = {
                SessionId = getSessionId ()
                UserId = command.TryFind "user_id" |> Option.bind (fun x -> x :?> string option)
                SourceModule = "Cepaf.Cockpit.GuardianIntegration"
            }
            Metadata = {
                Priority = command.TryFind "priority" |> Option.map (fun x -> x.ToString()) |> Option.defaultValue "normal"
                Idempotent = command.TryFind "idempotent" |> Option.map (fun x -> x :?> bool) |> Option.defaultValue false
                Reversible = command.TryFind "reversible" |> Option.map (fun x -> x :?> bool) |> Option.defaultValue true
            }
        }

    /// Validate a proposal with Guardian
    /// In F#, this simulates the Guardian call - actual call goes to Elixir backend
    let validateWithGuardian (proposal: Proposal) : ApprovalResult =
        // SC-PRAJNA-001: All commands through Guardian pre-approval
        // In production, this calls the Elixir Guardian.validate_proposal/1

        // Simulate Guardian validation logic
        let action = proposal.Command.TryFind "action" |> Option.map (fun x -> x.ToString())

        match action with
        | Some "shutdown" | Some "terminate_all" | Some "self_destruct" ->
            // SC-CONST-007: Guardian has absolute veto for dangerous actions
            Vetoed {
                Reason = "Action blocked by Guardian safety check"
                Fallback = {
                    Action = "no_op"
                    Reason = "guardian_veto"
                    Message = "Command rejected by Guardian safety check"
                }
            }

        | Some "disconnect_holon" ->
            Vetoed {
                Reason = "Would sever symbiotic binding (SC-FOUNDER-004)"
                Fallback = {
                    Action = "graceful_disconnect"
                    Reason = "symbiotic_protection"
                    Message = "Graceful disconnect initiated instead"
                }
            }

        | _ ->
            // Approved by Guardian
            Approved {
                Command = proposal.Command
                ApprovedAt = DateTimeOffset.UtcNow
                GuardianVersion = "21.1.0"
                ApprovalToken = generateApprovalToken proposal.Command proposal.Timestamp
            }

    /// Submit a proposal for Guardian approval (SC-PRAJNA-001)
    let submitProposal (command: Map<string, obj>) : ApprovalResult =
        let startTime = DateTimeOffset.UtcNow
        let proposal = buildProposal command

        let result = validateWithGuardian proposal

        // Log telemetry
        let duration = (DateTimeOffset.UtcNow - startTime).TotalMilliseconds
        printfn "[GuardianIntegration] Proposal completed in %.2fms: %A" duration result

        result

    /// Execute a command with Guardian approval
    let executeWithApproval
        (command: Map<string, obj>)
        (executeFn: ApprovedCommand -> 'T)
        (fallbackFn: FallbackAction -> 'T option)
        : Result<'T, string> =

        match submitProposal command with
        | Approved approved ->
            Result.Ok (executeFn approved)

        | Vetoed veto ->
            match fallbackFn veto.Fallback with
            | Some result -> Result.Ok result
            | None -> Result.Error (sprintf "Vetoed: %s" veto.Reason)

        | Error msg ->
            Result.Error msg

    /// Check if a command type requires Guardian approval
    /// SC-PRAJNA-001: All commands require approval (no exemptions)
    let requiresApproval (_cmdType: CommandType) : bool = true

    /// Get Guardian health status
    let guardianHealth () : GuardianHealth =
        // In production, this calls the Elixir Guardian.health_check/0
        {
            Status = "healthy"
            LastCheck = DateTimeOffset.UtcNow
            Error = None
        }

    /// Default fallback for vetoed commands
    let defaultFallback () : FallbackAction =
        {
            Action = "no_op"
            Reason = "guardian_veto"
            Message = "Command rejected by Guardian safety check"
        }
