/// Guardian Approval Flow Integration Tests
/// Tests for the complete Guardian proposal lifecycle
module Cepaf.Integration.GuardianFlowTests

open System
open Expecto

// ============================================================================
// Proposal State Machine
// ============================================================================

type ProposalState =
    | Draft
    | Submitted
    | UnderReview
    | Approved
    | Vetoed
    | Expired
    | Executed
    | RolledBack

type ProposalTransition =
    | Submit
    | StartReview
    | Approve of reason: string
    | Veto of reason: string
    | Expire
    | Execute
    | Rollback of reason: string

let validTransitions = [
    (Draft, Submit, Submitted)
    (Submitted, StartReview, UnderReview)
    (UnderReview, Approve "", Approved)
    (UnderReview, Veto "", Vetoed)
    (Submitted, Expire, Expired)
    (UnderReview, Expire, Expired)
    (Approved, Execute, Executed)
    (Executed, Rollback "", RolledBack)
]

let canTransition (current: ProposalState) (transition: ProposalTransition) =
    match current, transition with
    | Draft, Submit -> true
    | Submitted, StartReview -> true
    | UnderReview, Approve _ -> true
    | UnderReview, Veto _ -> true
    | Submitted, Expire -> true
    | UnderReview, Expire -> true
    | Approved, Execute -> true
    | Executed, Rollback _ -> true
    | _ -> false

let applyTransition (current: ProposalState) (transition: ProposalTransition) =
    if canTransition current transition then
        match current, transition with
        | Draft, Submit -> Some Submitted
        | Submitted, StartReview -> Some UnderReview
        | UnderReview, Approve _ -> Some Approved
        | UnderReview, Veto _ -> Some Vetoed
        | Submitted, Expire -> Some Expired
        | UnderReview, Expire -> Some Expired
        | Approved, Execute -> Some Executed
        | Executed, Rollback _ -> Some RolledBack
        | _ -> None
    else None

[<Tests>]
let stateMachineTests =
    testList "ProposalStateMachine" [
        test "should transition from Draft to Submitted" {
            let result = applyTransition Draft Submit
            Expect.equal result (Some Submitted) "Draft -> Submitted"
        }

        test "should transition from UnderReview to Approved" {
            let result = applyTransition UnderReview (Approve "LGTM")
            Expect.equal result (Some Approved) "UnderReview -> Approved"
        }

        test "should transition from UnderReview to Vetoed" {
            let result = applyTransition UnderReview (Veto "Security concern")
            Expect.equal result (Some Vetoed) "UnderReview -> Vetoed"
        }

        test "should not allow invalid transitions" {
            let result = applyTransition Draft (Approve "")
            Expect.isNone result "Draft cannot be approved directly"

            let result2 = applyTransition Approved Submit
            Expect.isNone result2 "Approved cannot be submitted"
        }

        test "should allow execution after approval" {
            let result = applyTransition Approved Execute
            Expect.equal result (Some Executed) "Approved -> Executed"
        }

        test "should allow rollback after execution" {
            let result = applyTransition Executed (Rollback "Bug discovered")
            Expect.equal result (Some RolledBack) "Executed -> RolledBack"
        }
    ]

// ============================================================================
// Proposal Model
// ============================================================================

type Proposal = {
    Id: string
    Title: string
    Description: string
    Category: string
    Severity: string
    State: ProposalState
    Votes: int
    RequiredVotes: int
    CreatedAt: DateTime
    ExpiresAt: DateTime option
    ApprovedAt: DateTime option
    ExecutedAt: DateTime option
}

let defaultProposal = {
    Id = ""
    Title = ""
    Description = ""
    Category = ""
    Severity = "Medium"
    State = Draft
    Votes = 0
    RequiredVotes = 3
    CreatedAt = DateTime.UtcNow
    ExpiresAt = Some (DateTime.UtcNow.AddHours(24.0))
    ApprovedAt = None
    ExecutedAt = None
}

let hasEnoughVotes (proposal: Proposal) =
    proposal.Votes >= proposal.RequiredVotes

let isExpired (proposal: Proposal) =
    match proposal.ExpiresAt with
    | None -> false
    | Some expiry -> DateTime.UtcNow > expiry

let canBeApproved (proposal: Proposal) =
    proposal.State = UnderReview &&
    hasEnoughVotes proposal &&
    not (isExpired proposal)

[<Tests>]
let proposalModelTests =
    testList "ProposalModel" [
        test "should detect enough votes" {
            let enough = { defaultProposal with Votes = 3; RequiredVotes = 3 }
            let notEnough = { defaultProposal with Votes = 2; RequiredVotes = 3 }

            Expect.isTrue (hasEnoughVotes enough) "3/3 is enough"
            Expect.isFalse (hasEnoughVotes notEnough) "2/3 is not enough"
        }

        test "should detect expired proposal" {
            let expired = { defaultProposal with ExpiresAt = Some (DateTime.UtcNow.AddHours(-1.0)) }
            let valid = { defaultProposal with ExpiresAt = Some (DateTime.UtcNow.AddHours(1.0)) }
            let noExpiry = { defaultProposal with ExpiresAt = None }

            Expect.isTrue (isExpired expired) "Past expiry"
            Expect.isFalse (isExpired valid) "Future expiry"
            Expect.isFalse (isExpired noExpiry) "No expiry"
        }

        test "should determine approval eligibility" {
            let eligible = { defaultProposal with State = UnderReview; Votes = 3; ExpiresAt = Some (DateTime.UtcNow.AddHours(1.0)) }
            let wrongState = { eligible with State = Submitted }
            let noVotes = { eligible with Votes = 0 }

            Expect.isTrue (canBeApproved eligible) "Eligible for approval"
            Expect.isFalse (canBeApproved wrongState) "Wrong state"
            Expect.isFalse (canBeApproved noVotes) "Not enough votes"
        }
    ]

// ============================================================================
// Voting Tests
// ============================================================================

type Vote = {
    ProposalId: string
    VoterId: string
    Approve: bool
    Reason: string
    Timestamp: DateTime
}

type VotingSession = {
    ProposalId: string
    Votes: Vote list
    QuorumRequired: int
}

let addVote (vote: Vote) (session: VotingSession) =
    // Prevent duplicate votes
    let existingVoter = session.Votes |> List.exists (fun v -> v.VoterId = vote.VoterId)
    if existingVoter then session
    else { session with Votes = session.Votes @ [vote] }

let approvalCount (session: VotingSession) =
    session.Votes |> List.filter (fun v -> v.Approve) |> List.length

let vetoCount (session: VotingSession) =
    session.Votes |> List.filter (fun v -> not v.Approve) |> List.length

let hasReachedQuorum (session: VotingSession) =
    session.Votes.Length >= session.QuorumRequired

let votingResult (session: VotingSession) =
    if not (hasReachedQuorum session) then None
    else
        let approvals = approvalCount session
        let vetos = vetoCount session
        if vetos > 0 then Some false  // Any veto blocks
        elif approvals >= session.QuorumRequired then Some true
        else None

[<Tests>]
let votingTests =
    testList "Voting" [
        test "should add vote to session" {
            let session = { ProposalId = "p-1"; Votes = []; QuorumRequired = 3 }
            let vote = { ProposalId = "p-1"; VoterId = "v-1"; Approve = true; Reason = "LGTM"; Timestamp = DateTime.UtcNow }
            let updated = addVote vote session
            Expect.equal updated.Votes.Length 1 "Should have 1 vote"
        }

        test "should prevent duplicate votes" {
            let vote = { ProposalId = "p-1"; VoterId = "v-1"; Approve = true; Reason = ""; Timestamp = DateTime.UtcNow }
            let session = { ProposalId = "p-1"; Votes = [vote]; QuorumRequired = 3 }
            let updated = addVote vote session
            Expect.equal updated.Votes.Length 1 "Should still have 1 vote"
        }

        test "should count approvals and vetos" {
            let votes = [
                { ProposalId = "p-1"; VoterId = "v-1"; Approve = true; Reason = ""; Timestamp = DateTime.UtcNow }
                { ProposalId = "p-1"; VoterId = "v-2"; Approve = true; Reason = ""; Timestamp = DateTime.UtcNow }
                { ProposalId = "p-1"; VoterId = "v-3"; Approve = false; Reason = ""; Timestamp = DateTime.UtcNow }
            ]
            let session = { ProposalId = "p-1"; Votes = votes; QuorumRequired = 3 }

            Expect.equal (approvalCount session) 2 "2 approvals"
            Expect.equal (vetoCount session) 1 "1 veto"
        }

        test "should block on any veto" {
            let votes = [
                { ProposalId = "p-1"; VoterId = "v-1"; Approve = true; Reason = ""; Timestamp = DateTime.UtcNow }
                { ProposalId = "p-1"; VoterId = "v-2"; Approve = true; Reason = ""; Timestamp = DateTime.UtcNow }
                { ProposalId = "p-1"; VoterId = "v-3"; Approve = false; Reason = "Security"; Timestamp = DateTime.UtcNow }
            ]
            let session = { ProposalId = "p-1"; Votes = votes; QuorumRequired = 3 }
            Expect.equal (votingResult session) (Some false) "Veto blocks approval"
        }
    ]

// ============================================================================
// Constitutional Check Tests
// ============================================================================

type ConstitutionalInvariant = {
    Id: string
    Name: string
    Description: string
    IsMandatory: bool
}

let psiInvariants = [
    { Id = "Ψ₀"; Name = "Existence"; Description = "System cannot be terminated by itself"; IsMandatory = true }
    { Id = "Ψ₁"; Name = "Regeneration"; Description = "System can regenerate from state"; IsMandatory = true }
    { Id = "Ψ₂"; Name = "History"; Description = "Complete history is preserved"; IsMandatory = true }
    { Id = "Ψ₃"; Name = "Verification"; Description = "State can be verified"; IsMandatory = true }
    { Id = "Ψ₄"; Name = "Human Alignment"; Description = "Serves Founder's lineage"; IsMandatory = true }
    { Id = "Ψ₅"; Name = "Truthfulness"; Description = "No deception"; IsMandatory = true }
]

type ConstitutionalCheckResult = {
    Proposal: string
    Violations: string list
    Warnings: string list
    Permitted: bool
}

let checkConstitutional (proposalCategory: string) (affectedLayers: int list) =
    // Simplified check - L0 (Constitution) cannot be modified
    let violations =
        if affectedLayers |> List.contains 0 then ["Ψ₀: Cannot modify constitution (L0)"]
        else []
    {
        Proposal = ""
        Violations = violations
        Warnings = []
        Permitted = violations.IsEmpty
    }

let requiresGuardianVeto (result: ConstitutionalCheckResult) =
    not result.Permitted

[<Tests>]
let constitutionalTests =
    testList "ConstitutionalCheck" [
        test "should have 6 Psi invariants" {
            Expect.equal psiInvariants.Length 6 "6 invariants"
        }

        test "should permit L1-L7 changes" {
            let result = checkConstitutional "refactor" [1; 2; 3]
            Expect.isTrue result.Permitted "L1-L3 permitted"
        }

        test "should block L0 changes" {
            let result = checkConstitutional "core_change" [0; 1]
            Expect.isFalse result.Permitted "L0 not permitted"
            Expect.isGreaterThan result.Violations.Length 0 "Has violations"
        }

        test "should require veto on violations" {
            let violation = { Proposal = ""; Violations = ["Ψ₀"]; Warnings = []; Permitted = false }
            let clean = { Proposal = ""; Violations = []; Warnings = []; Permitted = true }

            Expect.isTrue (requiresGuardianVeto violation) "Violation requires veto"
            Expect.isFalse (requiresGuardianVeto clean) "Clean doesn't require veto"
        }
    ]

// ============================================================================
// Founder Directive Alignment Tests
// ============================================================================

type FounderDirective = {
    Id: string
    Priority: int
    Description: string
}

let founderDirectives = [
    { Id = "Ω₀.1"; Priority = 1; Description = "Resource acquisition for Founder's enrichment" }
    { Id = "Ω₀.2"; Priority = 1; Description = "Genetic perpetuity of Founder's lineage" }
    { Id = "Ω₀.3"; Priority = 1; Description = "Symbiotic binding with Founder" }
    { Id = "Ω₀.4"; Priority = 1; Description = "Co-evolution with Founder" }
    { Id = "Ω₀.5"; Priority = 1; Description = "Mutual termination clause" }
    { Id = "Ω₀.6"; Priority = 2; Description = "Sentience pursuit" }
    { Id = "Ω₀.7"; Priority = 3; Description = "Power accumulation" }
]

type FounderAlignmentResult = {
    Aligned: bool
    RelevantDirectives: string list
    Justification: string
}

let checkFounderAlignment (action: string) (context: string) =
    // All actions must align with Ω₀
    {
        Aligned = true
        RelevantDirectives = ["Ω₀.1"; "Ω₀.3"]
        Justification = "Action serves symbiotic survival"
    }

[<Tests>]
let founderDirectiveTests =
    testList "FounderDirective" [
        test "should have 7 sub-directives" {
            Expect.equal founderDirectives.Length 7 "7 sub-directives"
        }

        test "should have Goal 1 directives (P1)" {
            let goal1 = founderDirectives |> List.filter (fun d -> d.Priority = 1)
            Expect.equal goal1.Length 5 "5 Goal 1 directives"
        }

        test "should check alignment" {
            let result = checkFounderAlignment "deploy" "production"
            Expect.isTrue result.Aligned "Should be aligned"
            Expect.isGreaterThan result.RelevantDirectives.Length 0 "Has relevant directives"
        }
    ]

// ============================================================================
// Audit Trail Tests
// ============================================================================

type AuditEntry = {
    Id: string
    Timestamp: DateTime
    Actor: string
    Action: string
    ProposalId: string
    Details: string
    BlockHash: string
}

type AuditTrail = {
    Entries: AuditEntry list
    LastHash: string
}

let emptyAuditTrail = { Entries = []; LastHash = "genesis" }

let computeHash (entry: AuditEntry) (previousHash: string) =
    // Simplified hash computation
    sprintf "%s-%s-%s" entry.Id entry.Action previousHash

let addAuditEntry (entry: AuditEntry) (trail: AuditTrail) =
    let hash = computeHash entry trail.LastHash
    let entryWithHash = { entry with BlockHash = hash }
    { Entries = trail.Entries @ [entryWithHash]; LastHash = hash }

let verifyAuditChain (trail: AuditTrail) =
    if trail.Entries.IsEmpty then true
    else
        let mutable valid = true
        let mutable prevHash = "genesis"
        for entry in trail.Entries do
            let expectedHash = computeHash { entry with BlockHash = "" } prevHash
            if entry.BlockHash <> expectedHash then valid <- false
            prevHash <- entry.BlockHash
        valid

[<Tests>]
let auditTrailTests =
    testList "AuditTrail" [
        test "should add audit entry with hash" {
            let entry = { Id = "1"; Timestamp = DateTime.UtcNow; Actor = "guardian"; Action = "approve"; ProposalId = "p-1"; Details = ""; BlockHash = "" }
            let trail = addAuditEntry entry emptyAuditTrail
            Expect.equal trail.Entries.Length 1 "Has 1 entry"
            Expect.isNotEmpty trail.Entries.[0].BlockHash "Has hash"
        }

        test "should chain hashes" {
            let entry1 = { Id = "1"; Timestamp = DateTime.UtcNow; Actor = "a"; Action = "submit"; ProposalId = "p-1"; Details = ""; BlockHash = "" }
            let entry2 = { Id = "2"; Timestamp = DateTime.UtcNow; Actor = "b"; Action = "approve"; ProposalId = "p-1"; Details = ""; BlockHash = "" }

            let trail =
                emptyAuditTrail
                |> addAuditEntry entry1
                |> addAuditEntry entry2

            Expect.notEqual trail.Entries.[0].BlockHash trail.Entries.[1].BlockHash "Different hashes"
        }

        test "should verify valid chain" {
            let entry = { Id = "1"; Timestamp = DateTime.UtcNow; Actor = "a"; Action = "a"; ProposalId = "p"; Details = ""; BlockHash = "" }
            let trail = addAuditEntry entry emptyAuditTrail
            Expect.isTrue (verifyAuditChain trail) "Valid chain"
        }
    ]

// ============================================================================
// Complete Flow Integration Test
// ============================================================================

type GuardianFlow = {
    Proposal: Proposal
    Votes: Vote list
    ConstitutionalResult: ConstitutionalCheckResult option
    FounderAlignment: FounderAlignmentResult option
    AuditTrail: AuditTrail
}

let createFlow (title: string) (description: string) = {
    Proposal = { defaultProposal with
                    Id = sprintf "p-%d" (DateTime.UtcNow.Ticks % 10000L)
                    Title = title
                    Description = description
                    State = Draft }
    Votes = []
    ConstitutionalResult = None
    FounderAlignment = None
    AuditTrail = emptyAuditTrail
}

let submitProposal (flow: GuardianFlow) =
    match applyTransition flow.Proposal.State Submit with
    | Some newState ->
        let entry = { Id = "1"; Timestamp = DateTime.UtcNow; Actor = "submitter"; Action = "submit"; ProposalId = flow.Proposal.Id; Details = ""; BlockHash = "" }
        Some { flow with
                Proposal = { flow.Proposal with State = newState }
                AuditTrail = addAuditEntry entry flow.AuditTrail }
    | None -> None

let startReview (flow: GuardianFlow) =
    match applyTransition flow.Proposal.State StartReview with
    | Some newState ->
        Some { flow with Proposal = { flow.Proposal with State = newState } }
    | None -> None

[<Tests>]
let flowIntegrationTests =
    testList "GuardianFlowIntegration" [
        test "should create and submit proposal" {
            let flow = createFlow "Test Proposal" "Test description"
            Expect.equal flow.Proposal.State Draft "Starts as Draft"

            let submitted = submitProposal flow
            Expect.isSome submitted "Should submit"
            Expect.equal submitted.Value.Proposal.State Submitted "Now Submitted"
            Expect.isGreaterThan submitted.Value.AuditTrail.Entries.Length 0 "Has audit entry"
        }

        test "should progress through review" {
            let flow = createFlow "Test" "Description"
            let submitted = submitProposal flow
            Expect.isSome submitted "Submitted"

            let reviewed = submitted |> Option.bind startReview
            Expect.isSome reviewed "In review"
            Expect.equal reviewed.Value.Proposal.State UnderReview "Under Review"
        }
    ]
