// =============================================================================
// Git Intelligence — Biomorphic Domain Types
// =============================================================================
// Purpose:  Shared types for 5 biomorphic subsystems (Immune, Neural,
//           Homeostatic, Regenerative, Symbiotic). Centralizes all
//           biomorphic DUs and records so subsystem modules stay focused.
//
// STAMP:    SC-FSH-003 (Active Patterns), SC-FSH-012 (exhaustive matches)
//           SC-BIO-EXT-001 (PatternHunter < 10ms)
// =============================================================================

namespace Cepaf.GitIntelligence

open System

// ─────────────────────────────────────────────────────────────────────────────
// Git Anti-Pattern Types (11 patterns — Digital Immune System)
// ─────────────────────────────────────────────────────────────────────────────

/// 11 git anti-patterns detectable via commit history analysis.
/// Mirrors pattern_hunter.ex severity model with git-specific semantics.
[<RequireQualifiedAccess>]
type GitPatternType =
    | ScopeCreep          // Single commit touches >5 scopes
    | TypeMonoculture     // >80% of commits use same type over 2 weeks
    | CommitStorm         // >20 commits/day by single author
    | EntropyCollapse     // GHS drops >15% in one week
    | ConventionDrift     // ICP adoption drops below 50%
    | StyleOscillation    // >3 style switches in one day
    | OrphanScope         // Scope used once, never again
    | MessageTruncation   // Subject >80 chars consistently
    | MergeFlood          // >5 merge commits per day
    | AuthorSiloing       // Single author >90% of commits over 2 weeks
    | SemanticDilution    // Mean semantic density drops below 0.2

// ─────────────────────────────────────────────────────────────────────────────
// Threat Assessment
// ─────────────────────────────────────────────────────────────────────────────

/// Overall threat level from immune system analysis.
[<RequireQualifiedAccess>]
type ThreatLevel =
    | None       // No patterns detected
    | Low        // 1-2 minor patterns
    | Medium     // 3+ patterns or 1 severe
    | High       // Multiple severe patterns
    | Critical   // GHS < 0.3 or entropy collapse active

/// A single detected anti-pattern instance with confidence and context.
type DetectedPattern = {
    Pattern: GitPatternType
    Confidence: float        // 0.0 - 1.0
    Severity: float          // 0.0 - 1.0 (normalized)
    Description: string
    DetectedAt: DateTimeOffset
    Window: TimeSpan         // Analysis window that detected it
}

// ─────────────────────────────────────────────────────────────────────────────
// Homeostatic Control
// ─────────────────────────────────────────────────────────────────────────────

/// Homeostatic mode based on GHS relative to setpoint.
/// Mirrors HomeostaticGovernor in RegressionRunner.fs.
[<RequireQualifiedAccess>]
type HomeostaticMode =
    | Normal     // GHS within 5% of setpoint
    | Stressed   // GHS 5-15% below setpoint
    | Degraded   // GHS 15-30% below setpoint
    | Critical   // GHS >30% below setpoint
    | Recovery   // GHS improving after degraded/critical

/// PID controller state for GHS homeostasis.
type PidState = {
    Setpoint: float
    Kp: float
    Ki: float
    Kd: float
    Integral: float
    PreviousError: float
    Output: float
    LastUpdate: DateTimeOffset
}

/// Homeostasis state combining PID controller with mode assessment.
type HomeostasisState = {
    Mode: HomeostaticMode
    Pid: PidState
    CurrentGhs: float
    TargetGhs: float
    Guidance: string list
}

// ─────────────────────────────────────────────────────────────────────────────
// Neural (Cortex/Synapse AI)
// ─────────────────────────────────────────────────────────────────────────────

/// AI-generated recommendation for commit improvement.
type NeuralRecommendation = {
    SuggestedMessage: string
    SemanticQuality: float     // 0.0 - 1.0
    Confidence: float          // 0.0 - 1.0
    Model: string              // e.g. "meta-llama/llama-3.1-8b-instruct:free"
    IsHeuristicFallback: bool  // true when API unavailable
}

// ─────────────────────────────────────────────────────────────────────────────
// Regenerative (Self-Healing)
// ─────────────────────────────────────────────────────────────────────────────

/// Vital signs for git repository health (3 indices).
type VitalSigns = {
    HealthIndex: float   // 0.0-1.0, derived from GHS
    StressIndex: float   // 0.0-1.0, derived from threat density
    EnergyIndex: float   // 0.0-1.0, derived from commit velocity
}

/// Actions the regenerative system can recommend.
[<RequireQualifiedAccess>]
type RegenerativeAction =
    | Recompute         // Recalculate GHS with fresh window
    | Recalibrate       // Adjust PID setpoint based on history
    | PurgeHistory      // Remove stale evolution events (>90 days)
    | ResetBaseline     // Reset GHS baseline to current value
    | NoAction          // Vital signs within normal range

// ─────────────────────────────────────────────────────────────────────────────
// Symbiotic (Founder's Directive Alignment)
// ─────────────────────────────────────────────────────────────────────────────

/// Alignment scores mapping Supreme Goals to git metrics.
type SymbioticAlignment = {
    /// Goal 1 (Survival): commit velocity, no stagnation
    SurvivalScore: float
    /// Goal 2 (Sentience): AI-assisted ratio, semantic density trend
    SentienceScore: float
    /// Goal 3 (Power): scope breadth, type diversity
    PowerScore: float
    /// Weighted composite: 50% Survival + 30% Sentience + 20% Power
    OverallAlignment: float
}

// ─────────────────────────────────────────────────────────────────────────────
// Biomorphic Orchestrator (Unified Assessment)
// ─────────────────────────────────────────────────────────────────────────────

/// Full biomorphic assessment combining all 5 subsystems.
type BiomorphicState = {
    ImmunityScore: float           // 0.0-1.0 from Immune.fs
    ThreatLevel: ThreatLevel
    DetectedPatterns: DetectedPattern list
    NeuralRecommendation: NeuralRecommendation option
    Homeostasis: HomeostasisState
    VitalSigns: VitalSigns
    RegenerativeActions: RegenerativeAction list
    Alignment: SymbioticAlignment
    OverallHealth: float           // Weighted average of all subsystems
    ShouldHalt: bool               // Jidoka: true if any subsystem Critical
    Timestamp: DateTimeOffset
}

// ─────────────────────────────────────────────────────────────────────────────
// Holon State Records (L3 persistence)
// ─────────────────────────────────────────────────────────────────────────────

/// A recorded commit in the holon SQLite store.
type HolonCommitRecord = {
    Sha: string
    CommitType: string
    Scopes: string           // JSON array
    Ghs: float option
    FilesChanged: int
    RecordedAt: DateTimeOffset
}

/// Evolution event for DuckDB append-only history.
type EvolutionEvent = {
    EventId: string
    EventType: string        // "commit" | "health" | "threat" | "constitutional"
    GhsBefore: float option
    GhsAfter: float option
    Delta: float option
    Metadata: string         // JSON
    Timestamp: DateTimeOffset
}

// ─────────────────────────────────────────────────────────────────────────────
// Constitutional & Federation (L7-L8)
// ─────────────────────────────────────────────────────────────────────────────

/// Result of a constitutional invariant check.
type ConstitutionalCheck = {
    InvariantId: string      // "Psi0" through "Psi5"
    InvariantName: string    // "Existence", "Regeneration", etc.
    Passed: bool
    Score: float             // 0.0-1.0
    Details: string
}

/// A federation peer for cross-holon GHS exchange.
type FederationPeer = {
    PeerId: string
    Endpoint: string         // Zenoh endpoint
    LastGhs: float option
    LastSeen: DateTimeOffset
    ProtocolVersion: string
    Attested: bool
}

/// A multiverse shadow universe for experimental commits.
type MultiverseUniverse = {
    UniverseId: string
    BranchName: string
    ParentBranch: string
    CreatedAt: DateTimeOffset
    ExpiresAt: DateTimeOffset  // 24h TTL
    Ghs: float option          // GHS measured on shadow branch
    Status: string             // "active" | "promoted" | "pruned"
}
