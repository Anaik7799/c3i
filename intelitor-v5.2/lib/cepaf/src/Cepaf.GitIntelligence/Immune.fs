// =============================================================================
// Git Intelligence — Digital Immune System
// =============================================================================
// Purpose:  Detect 11 git anti-patterns via sliding window commit history
//           analysis. Returns detected patterns with confidence scores and
//           computes aggregate immunity/threat levels.
//
// Patterns: ScopeCreep, TypeMonoculture, CommitStorm, EntropyCollapse,
//           ConventionDrift, StyleOscillation, OrphanScope, MessageTruncation,
//           MergeFlood, AuthorSiloing, SemanticDilution
//
// Perf:     scanCommitHistory must complete < 10ms per SC-BIO-EXT-001
//
// STAMP:    SC-IMMUNE-001, SC-IMMUNE-004, SC-BIO-EXT-001
// AOR:      AOR-IMMUNE-001 (Sentinel health check before critical ops)
// =============================================================================

module Cepaf.GitIntelligence.Immune

open System

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

let private maxHistorySize = 1000  // Cap to keep scan < 10ms

// ─────────────────────────────────────────────────────────────────────────────
// Individual pattern detectors (each returns DetectedPattern option)
// ─────────────────────────────────────────────────────────────────────────────

/// ScopeCreep: Single commit touches >5 scopes
let private detectScopeCreep (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern list =
    commits
    |> Array.filter (fun c -> c.Scopes.Length > 5)
    |> Array.map (fun c ->
        { Pattern = GitPatternType.ScopeCreep
          Confidence = min 1.0 (float c.Scopes.Length / 10.0)
          Severity = min 1.0 (float (c.Scopes.Length - 5) / 5.0)
          Description = $"Commit {c.ShortHash} touches {c.Scopes.Length} scopes (max recommended: 5)"
          DetectedAt = now
          Window = TimeSpan.Zero })
    |> Array.toList

/// TypeMonoculture: >80% of commits use same type over 2-week window
let private detectTypeMonoculture (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let window = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 14.0)
    if window.Length < 10 then None
    else
        let typeCounts =
            window
            |> Array.choose (fun c -> c.CommitType)
            |> Array.countBy id
            |> Array.sortByDescending snd
        match typeCounts with
        | [||] -> None
        | _ ->
            let (topType, topCount) = typeCounts.[0]
            let ratio = float topCount / float window.Length
            if ratio > 0.80 then
                Some { Pattern = GitPatternType.TypeMonoculture
                       Confidence = min 1.0 ((ratio - 0.80) / 0.20 + 0.5)
                       Severity = min 1.0 ((ratio - 0.80) * 5.0)
                       Description = $"Type monoculture: {CommitType.toTag topType} used {ratio * 100.0:F0}%% of last 2 weeks ({topCount}/{window.Length})"
                       DetectedAt = now
                       Window = TimeSpan.FromDays(14.0) }
            else None

/// CommitStorm: >20 commits/day by single author
let private detectCommitStorm (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern list =
    let today = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 1.0)
    today
    |> Array.groupBy (fun c -> c.Author)
    |> Array.choose (fun (author, authorCommits) ->
        if authorCommits.Length > 20 then
            Some { Pattern = GitPatternType.CommitStorm
                   Confidence = min 1.0 (float authorCommits.Length / 40.0)
                   Severity = min 1.0 (float (authorCommits.Length - 20) / 20.0)
                   Description = $"Commit storm: {author} made {authorCommits.Length} commits in 24h"
                   DetectedAt = now
                   Window = TimeSpan.FromDays(1.0) }
        else None)
    |> Array.toList

/// EntropyCollapse: GHS drops >15% in one week (requires two health snapshots)
let private detectEntropyCollapse (currentGhs: float option) (previousGhs: float option) (now: DateTimeOffset) : DetectedPattern option =
    match currentGhs, previousGhs with
    | Some current, Some previous when previous > 0.0 ->
        let drop = (previous - current) / previous
        if drop > 0.15 then
            Some { Pattern = GitPatternType.EntropyCollapse
                   Confidence = min 1.0 (drop / 0.30)
                   Severity = min 1.0 (drop / 0.30)
                   Description = $"Entropy collapse: GHS dropped {drop * 100.0:F1}%% ({previous:F4} → {current:F4})"
                   DetectedAt = now
                   Window = TimeSpan.FromDays(7.0) }
        else None
    | _ -> None

/// ConventionDrift: ICP adoption drops below 50%
let private detectConventionDrift (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let window = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 14.0)
    if window.Length < 5 then None
    else
        let icpCount =
            window |> Array.filter (fun c ->
                c.Style = CommitStyle.IcpConventional || c.Style = CommitStyle.ConventionalNoEmDash)
            |> Array.length
        let adoption = float icpCount / float window.Length
        if adoption < 0.50 then
            Some { Pattern = GitPatternType.ConventionDrift
                   Confidence = min 1.0 ((0.50 - adoption) / 0.30 + 0.5)
                   Severity = min 1.0 ((0.50 - adoption) * 3.0)
                   Description = $"Convention drift: ICP adoption at {adoption * 100.0:F0}%% (threshold: 50%%)"
                   DetectedAt = now
                   Window = TimeSpan.FromDays(14.0) }
        else None

/// StyleOscillation: >3 style switches in one day
let private detectStyleOscillation (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let today =
        commits
        |> Array.filter (fun c -> (now - c.Date).TotalDays <= 1.0)
        |> Array.sortBy (fun c -> c.Date)
    if today.Length < 4 then None
    else
        let switches =
            today
            |> Array.pairwise
            |> Array.filter (fun (a, b) -> a.Style <> b.Style)
            |> Array.length
        if switches > 3 then
            Some { Pattern = GitPatternType.StyleOscillation
                   Confidence = min 1.0 (float switches / 8.0)
                   Severity = min 1.0 (float (switches - 3) / 5.0)
                   Description = $"Style oscillation: {switches} style switches in 24h"
                   DetectedAt = now
                   Window = TimeSpan.FromDays(1.0) }
        else None

/// OrphanScope: Scope used exactly once across entire history
let private detectOrphanScope (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern list =
    commits
    |> Array.collect (fun c -> c.RawScopes |> List.toArray)
    |> Array.filter (fun s -> s <> "")
    |> Array.countBy id
    |> Array.filter (fun (_, count) -> count = 1)
    |> Array.map (fun (scope, _) ->
        { Pattern = GitPatternType.OrphanScope
          Confidence = 0.6
          Severity = 0.2  // Low severity — informational
          Description = $"Orphan scope '{scope}' used only once"
          DetectedAt = now
          Window = TimeSpan.Zero })
    |> Array.toList

/// MessageTruncation: Subject >80 chars in >30% of recent commits
let private detectMessageTruncation (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let window = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 14.0)
    if window.Length < 5 then None
    else
        let longCount = window |> Array.filter (fun c -> c.SubjectLength > 80) |> Array.length
        let ratio = float longCount / float window.Length
        if ratio > 0.30 then
            Some { Pattern = GitPatternType.MessageTruncation
                   Confidence = min 1.0 (ratio / 0.60 + 0.3)
                   Severity = min 1.0 ((ratio - 0.30) * 3.0)
                   Description = $"Message truncation: {longCount}/{window.Length} ({ratio * 100.0:F0}%%) subjects >80 chars"
                   DetectedAt = now
                   Window = TimeSpan.FromDays(14.0) }
        else None

/// MergeFlood: >5 merge commits per day
let private detectMergeFlood (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let today = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 1.0)
    let mergeCount =
        today |> Array.filter (fun c ->
            c.Subject.StartsWith("Merge", StringComparison.OrdinalIgnoreCase))
        |> Array.length
    if mergeCount > 5 then
        Some { Pattern = GitPatternType.MergeFlood
               Confidence = min 1.0 (float mergeCount / 10.0)
               Severity = min 1.0 (float (mergeCount - 5) / 10.0)
               Description = $"Merge flood: {mergeCount} merge commits in 24h"
               DetectedAt = now
               Window = TimeSpan.FromDays(1.0) }
    else None

/// AuthorSiloing: Single author >90% of commits over 2 weeks
let private detectAuthorSiloing (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let window = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 14.0)
    if window.Length < 10 then None
    else
        let authorCounts = window |> Array.countBy (fun c -> c.Author) |> Array.sortByDescending snd
        match authorCounts with
        | [||] -> None
        | _ ->
            let (topAuthor, topCount) = authorCounts.[0]
            let ratio = float topCount / float window.Length
            if ratio > 0.90 && authorCounts.Length > 1 then
                Some { Pattern = GitPatternType.AuthorSiloing
                       Confidence = min 1.0 ((ratio - 0.90) / 0.10 + 0.5)
                       Severity = min 1.0 ((ratio - 0.90) * 10.0)
                       Description = $"Author siloing: {topAuthor} authored {ratio * 100.0:F0}%% of commits ({topCount}/{window.Length})"
                       DetectedAt = now
                       Window = TimeSpan.FromDays(14.0) }
            else None

/// SemanticDilution: Mean semantic density drops below 0.2
let private detectSemanticDilution (commits: ParsedCommit[]) (now: DateTimeOffset) : DetectedPattern option =
    let window = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 14.0)
    if window.Length < 5 then None
    else
        let meanDensity =
            window |> Array.averageBy (fun c -> CommitStyle.semanticDensity c.Style)
        if meanDensity < 0.20 then
            Some { Pattern = GitPatternType.SemanticDilution
                   Confidence = min 1.0 ((0.20 - meanDensity) / 0.15 + 0.5)
                   Severity = min 1.0 ((0.20 - meanDensity) * 5.0)
                   Description = $"Semantic dilution: mean density {meanDensity:F4} (threshold: 0.20)"
                   DetectedAt = now
                   Window = TimeSpan.FromDays(14.0) }
        else None

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Scan commit history for all 11 anti-patterns. Returns detected patterns.
/// Caps input to 1000 commits to stay under 10ms (SC-BIO-EXT-001).
let scanCommitHistory
    (commits: ParsedCommit[])
    (currentGhs: float option)
    (previousGhs: float option)
    : DetectedPattern list =

    let now = DateTimeOffset.UtcNow
    let capped =
        if commits.Length > maxHistorySize then
            commits |> Array.sortByDescending (fun c -> c.Date) |> Array.take maxHistorySize
        else commits

    [
        yield! detectScopeCreep capped now
        yield! Option.toList (detectTypeMonoculture capped now)
        yield! detectCommitStorm capped now
        yield! Option.toList (detectEntropyCollapse currentGhs previousGhs now)
        yield! Option.toList (detectConventionDrift capped now)
        yield! Option.toList (detectStyleOscillation capped now)
        yield! detectOrphanScope capped now
        yield! Option.toList (detectMessageTruncation capped now)
        yield! Option.toList (detectMergeFlood capped now)
        yield! Option.toList (detectAuthorSiloing capped now)
        yield! Option.toList (detectSemanticDilution capped now)
    ]

/// Assess overall threat level from detected patterns.
let assessThreatLevel (patterns: DetectedPattern list) (currentGhs: float option) : ThreatLevel =
    let severePatterns =
        patterns |> List.filter (fun p -> p.Severity >= 0.6) |> List.length
    let totalPatterns = patterns.Length
    let hasEntropyCollapse =
        patterns |> List.exists (fun p -> p.Pattern = GitPatternType.EntropyCollapse)
    let ghsCritical =
        match currentGhs with
        | Some g when g < 0.3 -> true
        | _ -> false

    if ghsCritical || hasEntropyCollapse then ThreatLevel.Critical
    elif severePatterns >= 2 then ThreatLevel.High
    elif totalPatterns >= 3 || severePatterns >= 1 then ThreatLevel.Medium
    elif totalPatterns >= 1 then ThreatLevel.Low
    else ThreatLevel.None

/// Calculate immunity score: 1.0 = no threats, 0.0 = critical threats.
/// Inverse of normalized threat density.
let calculateImmunityScore (patterns: DetectedPattern list) : float =
    if patterns.IsEmpty then 1.0
    else
        let totalSeverity = patterns |> List.sumBy (fun p -> p.Severity)
        let maxPossible = float patterns.Length  // each could be 1.0
        max 0.0 (1.0 - totalSeverity / max 1.0 maxPossible)

/// Format threat report for display.
let formatThreatReport (patterns: DetectedPattern list) (threatLevel: ThreatLevel) (immunityScore: float) : string =
    let sb = System.Text.StringBuilder()
    let threatStr =
        match threatLevel with
        | ThreatLevel.None -> "NONE"
        | ThreatLevel.Low -> "LOW"
        | ThreatLevel.Medium -> "MEDIUM"
        | ThreatLevel.High -> "HIGH"
        | ThreatLevel.Critical -> "CRITICAL"

    sb.AppendLine($"Threat Level: {threatStr}  |  Immunity: {immunityScore:F2}  |  Patterns: {patterns.Length}") |> ignore

    for p in patterns |> List.sortByDescending (fun p -> p.Severity) do
        let patternTag =
            match p.Pattern with
            | GitPatternType.ScopeCreep -> "SCOPE_CREEP"
            | GitPatternType.TypeMonoculture -> "TYPE_MONO"
            | GitPatternType.CommitStorm -> "COMMIT_STORM"
            | GitPatternType.EntropyCollapse -> "ENTROPY_COLLAPSE"
            | GitPatternType.ConventionDrift -> "CONVENTION_DRIFT"
            | GitPatternType.StyleOscillation -> "STYLE_OSCILLATION"
            | GitPatternType.OrphanScope -> "ORPHAN_SCOPE"
            | GitPatternType.MessageTruncation -> "MSG_TRUNCATION"
            | GitPatternType.MergeFlood -> "MERGE_FLOOD"
            | GitPatternType.AuthorSiloing -> "AUTHOR_SILO"
            | GitPatternType.SemanticDilution -> "SEMANTIC_DILUTION"
        sb.AppendLine($"  [{patternTag}] sev={p.Severity:F2} conf={p.Confidence:F2} — {p.Description}") |> ignore

    if patterns.IsEmpty then
        sb.AppendLine("  No anti-patterns detected.") |> ignore

    sb.ToString()
