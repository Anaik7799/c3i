// =============================================================================
// Prajna C3I Cockpit - Guardian Bridge
// =============================================================================
// STAMP: SC-PRAJNA-001, SC-PRAJNA-005, SC-PRAJNA-006, SC-CONST-007
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-PRAJNA-*, AOR-PRAJNA-* |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Services

open System
open System.Threading.Tasks
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

/// <summary>
/// Bridge to Guardian for command validation and approval
/// All Prajna commands MUST pass Guardian validation before execution (SC-PRAJNA-001)
/// </summary>
module GuardianBridge =

    // =========================================================================
    // Guardian Request/Response Types
    // =========================================================================

    type GuardianRequest = {
        Id: Guid
        Action: string
        Domain: string
        Description: string
        ProofToken: string option
        RequestedAt: DateTime
    }

    type GuardianResponse =
        | Approved of {| proposal_id: Guid; approved_at: DateTime |}
        | Vetoed of {| proposal_id: Guid; reason: string; fallback: string option |}
        | Pending of {| proposal_id: Guid; timeout: TimeSpan |}
        | Error of string

    // =========================================================================
    // Configuration
    // =========================================================================

    type GuardianConfig = {
        TimeoutMs: int
        MaxRetries: int
        CircuitBreakerThreshold: int
        CircuitBreakerResetMs: int
        RequireProofToken: bool
    }

    let defaultConfig = {
        TimeoutMs = 5000
        MaxRetries = 3
        CircuitBreakerThreshold = 3
        CircuitBreakerResetMs = 30000
        RequireProofToken = true
    }

    // =========================================================================
    // Bridge State
    // =========================================================================

    type BridgeState = {
        Config: GuardianConfig
        ElixirClient: ElixirClient.ClientState
        mutable IsHealthy: bool
        mutable LastHealthCheck: DateTime
        mutable FailureCount: int
        mutable PendingProposals: Map<Guid, GuardianRequest>
    }

    let create (config: GuardianConfig) (elixirClient: ElixirClient.ClientState) : BridgeState = {
        Config = config
        ElixirClient = elixirClient
        IsHealthy = true
        LastHealthCheck = DateTime.MinValue
        FailureCount = 0
        PendingProposals = Map.empty
    }

    // =========================================================================
    // Proof Token Generation (SC-PRAJNA-005)
    // =========================================================================

    let private generateProofToken (action: string) (domain: string) : string =
        let timestamp = DateTime.UtcNow.Ticks
        let payload = $"{action}:{domain}:{timestamp}"
        // In production, use Ed25519 signature
        Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(payload))

    // =========================================================================
    // Guardian API Calls
    // =========================================================================

    let private submitProposal (state: BridgeState) (request: GuardianRequest) : Task<Result<Proposal, string>> =
        task {
            let proposalData = {|
                action = request.Action
                domain = request.Domain
                description = request.Description
                proof_token = request.ProofToken
            |}

            let! result = ElixirClient.post<_, Proposal>
                state.ElixirClient
                ElixirClient.Proposals
                proposalData

            return result
        }

    let private checkProposalStatus (state: BridgeState) (proposalId: Guid) : Task<Result<Proposal, string>> =
        task {
            // Poll for proposal status
            let! result = ElixirClient.get<Proposal>
                state.ElixirClient
                (ElixirClient.Proposals)

            return result
        }

    // =========================================================================
    // Command Validation (SC-PRAJNA-001)
    // =========================================================================

    type ValidatedCommand = {
        ProposalId: Guid
        Action: string
        Domain: string
        ApprovedAt: DateTime
    }

    /// Submit command for Guardian approval
    /// Returns ValidatedCommand if approved, Error if vetoed
    let validateCommand (state: BridgeState) (action: string) (domain: string) (description: string) : Task<Result<ValidatedCommand, string>> =
        task {
            // Check Guardian health first
            if not state.IsHealthy then
                return Error "Guardian is not healthy"
            else
                // Generate proof token if required (SC-PRAJNA-005)
                let proofToken =
                    if state.Config.RequireProofToken then
                        Some (generateProofToken action domain)
                    else
                        None

                let request = {
                    Id = Guid.NewGuid()
                    Action = action
                    Domain = domain
                    Description = description
                    ProofToken = proofToken
                    RequestedAt = DateTime.UtcNow
                }

                // Add to pending
                state.PendingProposals <- Map.add request.Id request state.PendingProposals

                // Submit to Guardian
                let! result = submitProposal state request

                match result with
                | Ok proposal ->
                    // Remove from pending
                    state.PendingProposals <- Map.remove request.Id state.PendingProposals

                    match proposal.Status with
                    | Approved ->
                        return Ok {
                            ProposalId = proposal.Id
                            Action = action
                            Domain = domain
                            ApprovedAt = proposal.ResolvedAt |> Option.defaultValue DateTime.UtcNow
                        }
                    | Vetoed ->
                        let reason = proposal.VetoReason |> Option.defaultValue "Unknown reason"
                        return Error $"Command vetoed: {reason}"
                    | Pending ->
                        // Wait for resolution or timeout
                        return Error "Proposal pending - timeout"
                    | Expired ->
                        return Error "Proposal expired"

                | Error err ->
                    state.FailureCount <- state.FailureCount + 1
                    if state.FailureCount >= state.Config.CircuitBreakerThreshold then
                        state.IsHealthy <- false
                    return Error err
        }

    // =========================================================================
    // Constitutional Check (SC-PRAJNA-006)
    // =========================================================================

    type ConstitutionalResult =
        | ConstitutionallyValid
        | ConstitutionallyInvalid of string

    /// Verify command doesn't violate constitutional invariants
    let checkConstitutional (state: BridgeState) (action: string) (domain: string) : Task<ConstitutionalResult> =
        task {
            // Check against Ψ₀-Ψ₅ invariants
            // In production, this calls the Guardian's constitutional verifier

            // Ψ₀: Existence preservation
            if action = "terminate_all" || action = "shutdown_system" then
                return ConstitutionallyInvalid "Ψ₀ Existence: Cannot terminate holon existence"

            // Ψ₁: Regeneration completeness
            elif action = "delete_state" && domain = "holon" then
                return ConstitutionallyInvalid "Ψ₁ Regeneration: Cannot delete regenerative state"

            // Ψ₂: Evolution continuity
            elif action = "truncate_history" then
                return ConstitutionallyInvalid "Ψ₂ Evolution: Cannot truncate evolution history"

            // Ψ₃: Verification capability
            elif action = "disable_verification" then
                return ConstitutionallyInvalid "Ψ₃ Verification: Cannot disable verification"

            // Ψ₄: Human alignment (Founder primary)
            elif action = "bypass_founder" || action = "override_directive" then
                return ConstitutionallyInvalid "Ψ₄ Alignment: Cannot bypass Founder's Directive"

            // Ψ₅: Truthfulness
            elif action = "falsify_logs" || action = "tamper_register" then
                return ConstitutionallyInvalid "Ψ₅ Truthfulness: Cannot falsify records"

            else
                return ConstitutionallyValid
        }

    // =========================================================================
    // Two-Step Commit (SC-PRAJNA-007)
    // =========================================================================

    type CommitPhase =
        | Phase1Prepare
        | Phase2Commit
        | Rollback

    type TwoStepCommit = {
        Id: Guid
        Phase: CommitPhase
        Command: ValidatedCommand
        PreparedAt: DateTime option
        CommittedAt: DateTime option
    }

    /// Prepare phase of two-step commit for destructive actions
    let prepareCommit (state: BridgeState) (command: ValidatedCommand) : Task<Result<TwoStepCommit, string>> =
        task {
            // Prepare the commit
            let commit = {
                Id = Guid.NewGuid()
                Phase = Phase1Prepare
                Command = command
                PreparedAt = Some DateTime.UtcNow
                CommittedAt = None
            }

            // Log to immutable register
            // In production, this calls ImmutableRegister.record

            return Ok commit
        }

    /// Commit phase of two-step commit
    let executeCommit (state: BridgeState) (commit: TwoStepCommit) : Task<Result<TwoStepCommit, string>> =
        task {
            if commit.Phase <> Phase1Prepare then
                return Error "Invalid commit phase"
            else
                // Execute the commit
                let committed = { commit with
                    Phase = Phase2Commit
                    CommittedAt = Some DateTime.UtcNow
                }

                return Ok committed
        }

    /// Rollback a prepared commit
    let rollbackCommit (state: BridgeState) (commit: TwoStepCommit) : Task<Result<unit, string>> =
        task {
            // Log rollback to immutable register
            return Ok ()
        }

    // =========================================================================
    // Health Check
    // =========================================================================

    let checkHealth (state: BridgeState) : Task<bool> =
        task {
            let! result = ElixirClient.checkHealth state.ElixirClient

            match result with
            | Ok isHealthy ->
                state.IsHealthy <- isHealthy
                state.LastHealthCheck <- DateTime.UtcNow
                if isHealthy then
                    state.FailureCount <- 0
                return isHealthy
            | Error _ ->
                state.IsHealthy <- false
                return false
        }

    let getHealthStatus (state: BridgeState) : GuardianState =
        {
            Proposals = state.PendingProposals |> Map.values |> Seq.toList |> List.map (fun r ->
                {
                    Id = r.Id
                    Action = r.Action
                    Domain = r.Domain
                    Description = r.Description
                    Status = Pending
                    VetoReason = None
                    FallbackAction = None
                    CreatedAt = r.RequestedAt
                    ResolvedAt = None
                })
            TotalApproved = 0
            TotalVetoed = 0
            IsHealthy = state.IsHealthy
            LastHealthCheck = state.LastHealthCheck
        }
