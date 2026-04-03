// =============================================================================
// Git Intelligence — Domain Types
// =============================================================================
// Purpose:  Domain types for ICP v2.0 commit analysis, validation, generation.
//
// STAMP:    SC-CHG-001 (structured change notes), SC-SYNC-DOC-009
// AOR:      AOR-CHG-001 to AOR-CHG-010
// =============================================================================

namespace Cepaf.GitIntelligence

open System

// ─────────────────────────────────────────────────────────────────────────────
// ICP v2.0 Commit Types (9 types — CLOSED enum, never invent new ones)
// ─────────────────────────────────────────────────────────────────────────────

[<RequireQualifiedAccess>]
type CommitType =
    | Feat
    | Fix
    | Refactor
    | Perf
    | Test
    | Docs
    | Chore
    | Security
    | Evolve

module CommitType =
    let all = [|
        CommitType.Feat; CommitType.Fix; CommitType.Refactor; CommitType.Perf
        CommitType.Test; CommitType.Docs; CommitType.Chore; CommitType.Security
        CommitType.Evolve
    |]

    let toTag = function
        | CommitType.Feat -> "feat"
        | CommitType.Fix -> "fix"
        | CommitType.Refactor -> "refactor"
        | CommitType.Perf -> "perf"
        | CommitType.Test -> "test"
        | CommitType.Docs -> "docs"
        | CommitType.Chore -> "chore"
        | CommitType.Security -> "security"
        | CommitType.Evolve -> "evolve"

    let fromTag (s: string) =
        match s.ToLowerInvariant().Trim() with
        | "feat" -> Some CommitType.Feat
        | "fix" -> Some CommitType.Fix
        | "refactor" -> Some CommitType.Refactor
        | "perf" -> Some CommitType.Perf
        | "test" -> Some CommitType.Test
        | "docs" -> Some CommitType.Docs
        | "chore" -> Some CommitType.Chore
        | "security" -> Some CommitType.Security
        | "evolve" -> Some CommitType.Evolve
        | _ -> None

    let versionBump = function
        | CommitType.Feat -> Some "MINOR"
        | CommitType.Fix | CommitType.Perf -> Some "PATCH"
        | CommitType.Security -> Some "PATCH+"
        | _ -> None

// ─────────────────────────────────────────────────────────────────────────────
// ICP v2.0 Scopes (23-scope taxonomy — CLOSED enum)
// ─────────────────────────────────────────────────────────────────────────────

[<RequireQualifiedAccess>]
type IcpScope =
    // L0
    | Guardian
    // L1-L2
    | App | Db | Kms
    // L3-L4
    | Mesh | Cepaf | Zenoh | Sentinel | Immune | Smriti | Prajna | Cortex | Plan | Obs
    // L5-L6
    | Vsm | Math | Swarm
    // L7
    | Fed | Formal
    // Cross-cutting
    | Test | Ci | Sync | Core

module IcpScope =
    let all = [|
        IcpScope.Guardian
        IcpScope.App; IcpScope.Db; IcpScope.Kms
        IcpScope.Mesh; IcpScope.Cepaf; IcpScope.Zenoh; IcpScope.Sentinel
        IcpScope.Immune; IcpScope.Smriti; IcpScope.Prajna; IcpScope.Cortex
        IcpScope.Plan; IcpScope.Obs
        IcpScope.Vsm; IcpScope.Math; IcpScope.Swarm
        IcpScope.Fed; IcpScope.Formal
        IcpScope.Test; IcpScope.Ci; IcpScope.Sync; IcpScope.Core
    |]

    let toTag = function
        | IcpScope.Guardian -> "guardian"
        | IcpScope.App -> "app"
        | IcpScope.Db -> "db"
        | IcpScope.Kms -> "kms"
        | IcpScope.Mesh -> "mesh"
        | IcpScope.Cepaf -> "cepaf"
        | IcpScope.Zenoh -> "zenoh"
        | IcpScope.Sentinel -> "sentinel"
        | IcpScope.Immune -> "immune"
        | IcpScope.Smriti -> "smriti"
        | IcpScope.Prajna -> "prajna"
        | IcpScope.Cortex -> "cortex"
        | IcpScope.Plan -> "plan"
        | IcpScope.Obs -> "obs"
        | IcpScope.Vsm -> "vsm"
        | IcpScope.Math -> "math"
        | IcpScope.Swarm -> "swarm"
        | IcpScope.Fed -> "fed"
        | IcpScope.Formal -> "formal"
        | IcpScope.Test -> "test"
        | IcpScope.Ci -> "ci"
        | IcpScope.Sync -> "sync"
        | IcpScope.Core -> "core"

    let fromTag (s: string) =
        match s.ToLowerInvariant().Trim() with
        | "guardian" -> Some IcpScope.Guardian
        | "app" -> Some IcpScope.App
        | "db" -> Some IcpScope.Db
        | "kms" -> Some IcpScope.Kms
        | "mesh" -> Some IcpScope.Mesh
        | "cepaf" -> Some IcpScope.Cepaf
        | "zenoh" -> Some IcpScope.Zenoh
        | "sentinel" -> Some IcpScope.Sentinel
        | "immune" -> Some IcpScope.Immune
        | "smriti" -> Some IcpScope.Smriti
        | "prajna" -> Some IcpScope.Prajna
        | "cortex" -> Some IcpScope.Cortex
        | "plan" -> Some IcpScope.Plan
        | "obs" -> Some IcpScope.Obs
        | "vsm" -> Some IcpScope.Vsm
        | "math" -> Some IcpScope.Math
        | "swarm" -> Some IcpScope.Swarm
        | "fed" -> Some IcpScope.Fed
        | "formal" -> Some IcpScope.Formal
        | "test" -> Some IcpScope.Test
        | "ci" -> Some IcpScope.Ci
        | "sync" -> Some IcpScope.Sync
        | "core" -> Some IcpScope.Core
        | _ -> None

    let fractalLayer = function
        | IcpScope.Guardian -> "L0"
        | IcpScope.App | IcpScope.Db | IcpScope.Kms -> "L1-L2"
        | IcpScope.Mesh | IcpScope.Cepaf | IcpScope.Zenoh | IcpScope.Sentinel
        | IcpScope.Immune | IcpScope.Smriti | IcpScope.Prajna | IcpScope.Cortex
        | IcpScope.Plan | IcpScope.Obs -> "L3-L4"
        | IcpScope.Vsm | IcpScope.Math | IcpScope.Swarm -> "L5-L6"
        | IcpScope.Fed | IcpScope.Formal -> "L7"
        | IcpScope.Test | IcpScope.Ci | IcpScope.Sync | IcpScope.Core -> "Cross"

// ─────────────────────────────────────────────────────────────────────────────
// Commit Style Classification (7 historical styles)
// ─────────────────────────────────────────────────────────────────────────────

[<RequireQualifiedAccess>]
type CommitStyle =
    | IcpConventional       // type(scope): action — context
    | ConventionalNoEmDash  // type(scope): action (no em-dash)
    | Emoji                 // 🚀 🎯 ✅ prefixed
    | EvolutionRun          // EVOLUTION RUN N: ...
    | Hyperbolic            // SINGULARITY / TOTAL BIOMORPHIC etc
    | PhaseSop              // PHASE/SOP/SPRINT structured
    | Other                 // unclassified

module CommitStyle =
    let label = function
        | CommitStyle.IcpConventional -> "ICP v2.0"
        | CommitStyle.ConventionalNoEmDash -> "Conventional"
        | CommitStyle.Emoji -> "Emoji"
        | CommitStyle.EvolutionRun -> "EVOLUTION RUN"
        | CommitStyle.Hyperbolic -> "Hyperbolic"
        | CommitStyle.PhaseSop -> "Phase/SOP"
        | CommitStyle.Other -> "Other"

    /// Semantic bits per character for each style (measured from 1-year analysis)
    let semanticDensity = function
        | CommitStyle.IcpConventional -> 0.568
        | CommitStyle.ConventionalNoEmDash -> 0.42
        | CommitStyle.Emoji -> 0.31
        | CommitStyle.EvolutionRun -> 0.064
        | CommitStyle.Hyperbolic -> 0.10
        | CommitStyle.PhaseSop -> 0.28
        | CommitStyle.Other -> 0.25

// ─────────────────────────────────────────────────────────────────────────────
// Parsed Commit Record
// ─────────────────────────────────────────────────────────────────────────────

type ParsedCommit = {
    Hash: string
    ShortHash: string
    Author: string
    Date: DateTimeOffset
    Subject: string
    Body: string
    FilesChanged: int
    Insertions: int
    Deletions: int
    // Classified fields
    Style: CommitStyle
    CommitType: CommitType option
    Scopes: IcpScope list
    RawScopes: string list
    HasEmDash: bool
    SubjectLength: int
    ContextAfterEmDash: string option
}

// ─────────────────────────────────────────────────────────────────────────────
// Analysis Results
// ─────────────────────────────────────────────────────────────────────────────

type StyleDistribution = {
    Style: CommitStyle
    Count: int
    Percentage: float
}

type ScopeCompliance = {
    TotalScopedCommits: int
    ValidScopes: int
    InvalidScopes: int
    ComplianceRate: float
    UniqueScopesUsed: string list
    InvalidScopesList: string list
}

type MonthlyBreakdown = {
    Month: string // YYYY-MM
    CommitCount: int
    IcpCount: int
    IcpRate: float
    MeanSubjectLength: float
    MeanFilesChanged: float
}

type GitHealthScore = {
    /// I_actual / I_potential — overall information utilization
    Score: float
    /// Shannon entropy of type distribution (bits)
    TypeEntropy: float
    /// Shannon entropy of scope distribution (bits)
    ScopeEntropy: float
    /// Fraction of commits following ICP v2.0
    IcpAdoption: float
    /// Mean semantic density (bits/char) across all commits
    MeanSemanticDensity: float
    /// Scope compliance rate (valid / total scoped)
    ScopeCompliance: float
}

type CommitAnalysis = {
    TotalCommits: int
    DateRange: DateTimeOffset * DateTimeOffset
    StyleDistribution: StyleDistribution list
    ScopeCompliance: ScopeCompliance
    MonthlyBreakdown: MonthlyBreakdown list
    HealthScore: GitHealthScore
    MeanSubjectLength: float
    MedianSubjectLength: int
    LongSubjects: int  // > 80 chars
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation Result
// ─────────────────────────────────────────────────────────────────────────────

[<RequireQualifiedAccess>]
type ValidationIssue =
    | MissingType
    | InvalidType of string
    | MissingScope
    | InvalidScope of string
    | SubjectTooLong of int
    | PastTense of string
    | EmojiPrefix
    | EvolutionRunFormat
    | HyperbolicFormat
    | MissingCoAuthor
    | NoImperativeMood

type ValidationResult = {
    IsValid: bool
    Issues: ValidationIssue list
    ParsedType: CommitType option
    ParsedScopes: IcpScope list
    Subject: string
    HasEmDash: bool
}

// ─────────────────────────────────────────────────────────────────────────────
// Commit Generation Input
// ─────────────────────────────────────────────────────────────────────────────

type CommitInput = {
    Type: CommitType
    Scopes: IcpScope list
    Action: string
    Context: string option
    Why: string option
    What: string option
    FilesCreated: int
    FilesModified: int
    Layers: (string * int) list  // e.g. [("L1-CODE", 2); ("L3-SYSTEM", 1)]
    StampRefs: string list
    TaskRef: string option
}
