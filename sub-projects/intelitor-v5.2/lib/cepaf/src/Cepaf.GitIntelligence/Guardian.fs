// =============================================================================
// Git Intelligence — L8 Guardian Safety Gate
// =============================================================================
// Purpose:  Standalone Guardian integration for git operations. Validates
//           commits against L6 artifact protection, branch safety, and
//           constitutional invariants before allowing mutations.
//
// Pattern:  Mirrors GuardianIntegration.fs — Proposal → validate → ApprovalResult
//           Self-contained (no ProjectReference to Cepaf).
//
// STAMP:    SC-SAFETY-001 (Guardian pre-approval), SC-PRIME-001 (L6 protection),
//           SC-PRIME-002 (recursion lock), SC-GDE-001 (Guardian required)
// AOR:      AOR-CONST-003 (Guardian supremacy), AOR-NEURO-001 (Guardian check)
// =============================================================================

module Cepaf.GitIntelligence.Guardian

open System

// ─────────────────────────────────────────────────────────────────────────────
// Guardian types
// ─────────────────────────────────────────────────────────────────────────────

/// Proposal for Guardian validation of a git operation.
type Proposal = {
    OperationType: string      // "commit", "branch-op", "force-push", "rebase"
    Description: string
    FilesAffected: string list
    Author: string
    Timestamp: DateTimeOffset
}

/// Guardian approval result.
[<RequireQualifiedAccess>]
type ApprovalResult =
    | Approved of reason: string
    | Vetoed of reason: string
    | Error of message: string

// ─────────────────────────────────────────────────────────────────────────────
// L6 Artifact Protection (SC-PRIME-001, SC-PRIME-002)
// ─────────────────────────────────────────────────────────────────────────────

/// L6 artifacts that cannot be modified without explicit human authorization.
let private l6Artifacts = [
    "CLAUDE.md"
    "GEMINI.md"
    "lib/indrajaal/prometheus/verifier.ex"
    "native/zenoh_nif"
]

/// Check if any file path touches an L6 artifact.
let private touchesL6Artifact (files: string list) : string option =
    files |> List.tryFind (fun f ->
        l6Artifacts |> List.exists (fun artifact ->
            f.Contains(artifact, StringComparison.OrdinalIgnoreCase)
        )
    )

// ─────────────────────────────────────────────────────────────────────────────
// Dangerous branch operations
// ─────────────────────────────────────────────────────────────────────────────

/// Operations that require Guardian approval on protected branches.
let private dangerousBranchOps = [
    "force-push"
    "rebase"
    "reset-hard"
    "branch-delete"
]

/// Branches that are protected from dangerous operations.
let private protectedBranches = [
    "main"
    "master"
    "production"
    "release"
]

/// Check if an operation is dangerous on a protected branch.
let private isDangerousBranchOp (opType: string) (branch: string) : bool =
    let isDangerous = dangerousBranchOps |> List.exists (fun op ->
        opType.Contains(op, StringComparison.OrdinalIgnoreCase))
    let isProtected = protectedBranches |> List.exists (fun b ->
        branch.Equals(b, StringComparison.OrdinalIgnoreCase))
    isDangerous && isProtected

// ─────────────────────────────────────────────────────────────────────────────
// Validation functions
// ─────────────────────────────────────────────────────────────────────────────

/// Validate a commit operation. Returns ApprovalResult.
let validateCommit (proposal: Proposal) : ApprovalResult =
    // SC-PRIME-001: Block modifications to L6 artifacts
    match touchesL6Artifact proposal.FilesAffected with
    | Some artifact ->
        ApprovalResult.Vetoed $"L6 artifact protection: '{artifact}' cannot be modified without human authorization (SC-PRIME-001)"
    | None ->
        ApprovalResult.Approved "Commit does not touch L6 artifacts"

/// Validate a branch operation (force-push, rebase, etc.).
let validateBranchOp (opType: string) (branch: string) : ApprovalResult =
    if isDangerousBranchOp opType branch then
        ApprovalResult.Vetoed $"Dangerous operation '{opType}' on protected branch '{branch}' requires explicit human authorization"
    else
        ApprovalResult.Approved $"Branch operation '{opType}' on '{branch}' is safe"

/// Validate any git operation via Guardian. Dispatches to specific validators.
let validateProposal (proposal: Proposal) : ApprovalResult =
    try
        match proposal.OperationType.ToLowerInvariant() with
        | "commit" ->
            validateCommit proposal
        | "force-push" | "rebase" | "reset-hard" | "branch-delete" ->
            validateBranchOp proposal.OperationType "main"
        | _ ->
            ApprovalResult.Approved $"Operation '{proposal.OperationType}' does not require Guardian approval"
    with ex ->
        ApprovalResult.Error $"Guardian validation failed: {ex.Message}"

// ─────────────────────────────────────────────────────────────────────────────
// Higher-order Guardian wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Wrap a git operation with Guardian pre-approval.
/// If Guardian vetoes, the operation is not executed and the veto reason is returned.
let wrapWithGuardian (proposal: Proposal) (operation: unit -> Result<'T, string>) : Result<'T, string> =
    match validateProposal proposal with
    | ApprovalResult.Approved _ ->
        operation ()
    | ApprovalResult.Vetoed reason ->
        Error $"Guardian VETO: {reason}"
    | ApprovalResult.Error msg ->
        Error $"Guardian ERROR: {msg}"

/// Create a proposal for a commit operation.
let createCommitProposal (files: string list) (author: string) : Proposal =
    {
        OperationType = "commit"
        Description = $"Commit affecting {files.Length} files"
        FilesAffected = files
        Author = author
        Timestamp = DateTimeOffset.UtcNow
    }

/// Create a proposal for a branch operation.
let createBranchProposal (opType: string) (branch: string) (author: string) : Proposal =
    {
        OperationType = opType
        Description = $"{opType} on branch '{branch}'"
        FilesAffected = []
        Author = author
        Timestamp = DateTimeOffset.UtcNow
    }

/// Check if a file list contains any L6 artifacts (utility for callers).
let containsL6Artifacts (files: string list) : bool =
    touchesL6Artifact files |> Option.isSome
