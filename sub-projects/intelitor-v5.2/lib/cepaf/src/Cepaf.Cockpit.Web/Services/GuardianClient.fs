namespace Cepaf.Cockpit.Web.Services

open System
open System.Net.Http
open System.Net.Http.Json
open System.Text.Json
open System.Threading
open System.Threading.Tasks
open Cepaf.Cockpit.Domain

/// <summary>
/// GuardianClient - Safety kernel approval client for Constitutional verification
///
/// STAMP Constraints:
/// - SC-PRAJNA-001: Guardian Gate - Prajna commands MUST pass Guardian validation before execution (CRITICAL)
/// - SC-SYNC-006: Guardian Approve - Use Guardian for all command approval (CRITICAL)
/// - SC-GDE-001: Guardian validation required (CRITICAL)
/// - SC-GDE-004: Proposal threshold >= 0.85 (HIGH)
/// - SC-CONST-003: Guardian Supremacy - Guardian has absolute veto (INFINITE)
///
/// AOR Rules:
/// - AOR-SYNC-006: Guardian Approve - Use Guardian for all command approval
/// - AOR-PRAJNA-001: Guardian Gate - Prajna commands MUST pass Guardian validation before execution
/// - AOR-GDE-002: Evolution Safety - All code proposals MUST pass Guardian validation before deployment
/// - AOR-CONST-003: Guardian Supremacy - Guardian has absolute veto. Cannot be overridden or disabled.
///
/// Architecture Notes:
/// - Guardian is the Constitutional Safety Kernel
/// - Verifies all changes against Ψ₀-Ψ₅ invariants and Ω₀ Founder's Directive
/// - Proposals with score < 0.85 are auto-rejected
/// - Guardian decisions are immutable and logged to Immutable Register
/// - Two-step commit REQUIRED for destructive actions (SC-PRAJNA-005)
/// </summary>
module GuardianClient =

    /// Guardian proposal for validation
    type GuardianProposal = {
        ProposalId: Guid
        Type: ProposalType
        Description: string
        Changes: ChangeDescription list
        Requestor: string
        Timestamp: DateTime
    }

    and ProposalType =
        | CodeChange
        | ConfigurationChange
        | DatabaseMigration
        | SecurityChange
        | InfrastructureChange
        | ReconfigurationChange

    and ChangeDescription = {
        Layer: FractalLayer
        Component: string
        Impact: ImpactLevel
        Reversible: bool
    }

    and FractalLayer =
        | L0_Runtime
        | L1_Function
        | L2_Component
        | L3_Holon
        | L4_Container
        | L5_Node
        | L6_Cluster
        | L7_Federation

    and ImpactLevel =
        | Low
        | Medium
        | High
        | Critical

    /// Guardian validation result
    type GuardianValidation = {
        ProposalId: Guid
        Approved: bool
        Score: float
        Reason: string
        ConstitutionalCheck: ConstitutionalCheckResult
        FounderDirectiveCheck: bool
        Timestamp: DateTime
        VetoReason: string option
    }

    and ConstitutionalCheckResult = {
        Psi0_Existence: bool
        Psi1_Regeneration: bool
        Psi2_History: bool
        Psi3_Verification: bool
        Psi4_HumanAlignment: bool
        Psi5_Truthfulness: bool
        AllPassed: bool
    }

    /// Guardian status
    type GuardianStatus = {
        Online: bool
        LastHeartbeat: DateTime
        ProposalsProcessed: int
        ApprovalRate: float
        VetoCount: int
    }

    /// Two-step commit state (SC-PRAJNA-005)
    type TwoStepCommitState =
        | NotStarted
        | Proposed of proposalId: Guid
        | Validated of validation: GuardianValidation
        | Confirmed
        | Aborted of reason: string

    /// Guardian API client
    type GuardianApiClient(baseUrl: string) =
        let client = new HttpClient(BaseAddress = Uri(baseUrl))
        let mutable twoStepState = NotStarted

        let jsonOptions =
            let opts = JsonSerializerOptions()
            opts.PropertyNameCaseInsensitive <- true
            opts

        /// Submit proposal to Guardian for validation (SC-GDE-001)
        member this.SubmitProposalAsync(proposal: GuardianProposal, ct: CancellationToken) = task {
            try
                let! response = client.PostAsJsonAsync("/api/prajna/guardian/propose", proposal, jsonOptions, ct)

                if response.IsSuccessStatusCode then
                    let! validation = response.Content.ReadFromJsonAsync<GuardianValidation>(jsonOptions, ct)

                    // SC-GDE-004: Proposal threshold >= 0.85
                    if validation.Score < 0.85 then
                        printfn $"[Guardian] Proposal {proposal.ProposalId} rejected: score {validation.Score:F2} < 0.85"

                    // Update two-step commit state
                    twoStepState <- Validated validation

                    return Ok validation
                else
                    let error = $"Guardian validation failed: {response.StatusCode}"
                    twoStepState <- Aborted error
                    return Error error

            with ex ->
                let error = $"Guardian API error: {ex.Message}"
                twoStepState <- Aborted error
                return Error error
        }

        /// Verify Constitutional invariants (Ψ₀-Ψ₅)
        member this.VerifyConstitutionalAsync(proposal: GuardianProposal, ct: CancellationToken) = task {
            try
                let! response = client.PostAsJsonAsync("/api/prajna/guardian/verify_constitutional", proposal, jsonOptions, ct)

                if response.IsSuccessStatusCode then
                    let! result = response.Content.ReadFromJsonAsync<ConstitutionalCheckResult>(jsonOptions, ct)
                    return Ok result
                else
                    return Error $"Constitutional verification failed: {response.StatusCode}"

            with ex ->
                return Error $"Constitutional verification error: {ex.Message}"
        }

        /// Check Founder's Directive compliance (Ω₀)
        member this.CheckFounderDirectiveAsync(proposal: GuardianProposal, ct: CancellationToken) = task {
            try
                let! response = client.PostAsJsonAsync("/api/prajna/guardian/check_founder", proposal, jsonOptions, ct)

                if response.IsSuccessStatusCode then
                    let! result = response.Content.ReadFromJsonAsync<{| compliant: bool; reason: string |}>(jsonOptions, ct)
                    return Ok (result.compliant, result.reason)
                else
                    return Error $"Founder directive check failed: {response.StatusCode}"

            with ex ->
                return Error $"Founder directive check error: {ex.Message}"
        }

        /// Get Guardian status
        member this.GetStatusAsync(ct: CancellationToken) = task {
            try
                let! response = client.GetAsync("/api/prajna/guardian/status", ct)

                if response.IsSuccessStatusCode then
                    let! status = response.Content.ReadFromJsonAsync<GuardianStatus>(jsonOptions, ct)
                    return Ok status
                else
                    return Error $"Guardian status request failed: {response.StatusCode}"

            with ex ->
                return Error $"Guardian status error: {ex.Message}"
        }

        /// Two-step commit: Step 1 - Propose
        member this.TwoStepProposeAsync(proposal: GuardianProposal, ct: CancellationToken) = task {
            twoStepState <- Proposed proposal.ProposalId

            let! validation = this.SubmitProposalAsync(proposal, ct)

            match validation with
            | Ok v when v.Approved ->
                twoStepState <- Validated v
                return Ok v
            | Ok v ->
                twoStepState <- Aborted v.Reason
                return Error $"Proposal rejected: {v.Reason}"
            | Error e ->
                twoStepState <- Aborted e
                return Error e
        }

        /// Two-step commit: Step 2 - Confirm
        member this.TwoStepConfirmAsync(ct: CancellationToken) = task {
            match twoStepState with
            | Validated validation ->
                try
                    let! response = client.PostAsync($"/api/prajna/guardian/confirm/{validation.ProposalId}", null, ct)

                    if response.IsSuccessStatusCode then
                        twoStepState <- Confirmed
                        return Ok "Proposal confirmed and executed"
                    else
                        let error = $"Confirmation failed: {response.StatusCode}"
                        twoStepState <- Aborted error
                        return Error error

                with ex ->
                    let error = $"Confirmation error: {ex.Message}"
                    twoStepState <- Aborted error
                    return Error error

            | NotStarted -> return Error "No proposal submitted"
            | Proposed _ -> return Error "Proposal not validated yet"
            | Confirmed -> return Error "Proposal already confirmed"
            | Aborted reason -> return Error $"Proposal aborted: {reason}"
        }

        /// Two-step commit: Abort
        member this.TwoStepAbortAsync(reason: string, ct: CancellationToken) = task {
            match twoStepState with
            | Proposed proposalId | Validated { ProposalId = proposalId } ->
                try
                    let! response = client.PostAsync($"/api/prajna/guardian/abort/{proposalId}", null, ct)

                    twoStepState <- Aborted reason
                    return Ok "Proposal aborted"

                with ex ->
                    return Error $"Abort error: {ex.Message}"

            | _ ->
                twoStepState <- Aborted reason
                return Ok "Proposal aborted (no active proposal)"
        }

        /// Get current two-step commit state
        member this.TwoStepState = twoStepState

        /// Reset two-step commit state
        member this.ResetTwoStep() =
            twoStepState <- NotStarted

        /// Quick validation check (returns true if Guardian approves)
        member this.QuickValidateAsync(proposalType: ProposalType, description: string, ct: CancellationToken) = task {
            let proposal = {
                ProposalId = Guid.NewGuid()
                Type = proposalType
                Description = description
                Changes = []
                Requestor = "PrajnaCockpit"
                Timestamp = DateTime.UtcNow
            }

            let! result = this.SubmitProposalAsync(proposal, ct)

            return
                match result with
                | Ok validation -> validation.Approved
                | Error _ -> false
        }

        interface IDisposable with
            member this.Dispose() =
                client.Dispose()

    /// Factory for creating Guardian client
    let createClient () =
        let baseUrl =
            match Environment.GetEnvironmentVariable("ELIXIR_API_URL") with
            | null | "" -> "http://localhost:4000"
            | url -> url

        new GuardianApiClient(baseUrl)

    /// Helper to create a code change proposal
    let createCodeChangeProposal (description: string) (files: string list) (reversible: bool) =
        {
            ProposalId = Guid.NewGuid()
            Type = CodeChange
            Description = description
            Changes = files |> List.map (fun file -> {
                Layer = L1_Function
                Component = file
                Impact = Medium
                Reversible = reversible
            })
            Requestor = "PrajnaCockpit"
            Timestamp = DateTime.UtcNow
        }

    /// Helper to create a configuration change proposal
    let createConfigChangeProposal (description: string) (configFiles: string list) =
        {
            ProposalId = Guid.NewGuid()
            Type = ConfigurationChange
            Description = description
            Changes = configFiles |> List.map (fun file -> {
                Layer = L4_Container
                Component = file
                Impact = High
                Reversible = true
            })
            Requestor = "PrajnaCockpit"
            Timestamp = DateTime.UtcNow
        }

    /// Helper to create a database migration proposal
    let createDatabaseMigrationProposal (description: string) (migrationFile: string) (reversible: bool) =
        {
            ProposalId = Guid.NewGuid()
            Type = DatabaseMigration
            Description = description
            Changes = [{
                Layer = L3_Holon
                Component = migrationFile
                Impact = Critical
                Reversible = reversible
            }]
            Requestor = "PrajnaCockpit"
            Timestamp = DateTime.UtcNow
        }
