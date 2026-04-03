// =============================================================================
// Git Intelligence — Symbiotic (Founder's Directive Alignment) Subsystem
// =============================================================================
// Purpose:  Map the 3 Supreme Goals (Ω₀) to measurable git metrics:
//           - Goal 1 (Survival): commit velocity, no stagnation
//           - Goal 2 (Sentience): AI-assisted ratio, semantic density trend
//           - Goal 3 (Power): scope breadth, type diversity
//
// Weights:  50% Survival + 30% Sentience + 20% Power
//
// STAMP:    SC-SAFETY-013, SC-SIL6-006
// =============================================================================

module Cepaf.GitIntelligence.Symbiotic

open System

// ─────────────────────────────────────────────────────────────────────────────
// Goal 1: Survival — Commit velocity, no stagnation (Ω₀.1-Ω₀.5)
// ─────────────────────────────────────────────────────────────────────────────

/// Assess survival score from commit velocity and age.
/// 1.0 = healthy velocity, 0.0 = complete stagnation.
let assessSurvival (commits: ParsedCommit[]) : float =
    if commits.Length = 0 then 0.0
    else
        let now = DateTimeOffset.UtcNow

        // Recent activity: commits in last 7 days
        let recentCount =
            commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 7.0) |> Array.length
        let velocityScore =
            if recentCount >= 10 then 1.0
            elif recentCount >= 5 then 0.8
            elif recentCount >= 1 then 0.5
            else 0.1

        // Stagnation: days since last commit
        let lastCommit = commits |> Array.maxBy (fun c -> c.Date)
        let daysSince = (now - lastCommit.Date).TotalDays
        let stagnationScore =
            if daysSince < 1.0 then 1.0
            elif daysSince < 3.0 then 0.8
            elif daysSince < 7.0 then 0.5
            elif daysSince < 14.0 then 0.3
            else 0.1

        // History depth: total commits
        let depthScore =
            if commits.Length >= 500 then 1.0
            elif commits.Length >= 100 then 0.8
            elif commits.Length >= 20 then 0.5
            else 0.3

        // Weighted: velocity 50%, stagnation 30%, depth 20%
        0.50 * velocityScore + 0.30 * stagnationScore + 0.20 * depthScore

// ─────────────────────────────────────────────────────────────────────────────
// Goal 2: Sentience — AI-assisted ratio, semantic density (Ω₀.6)
// ─────────────────────────────────────────────────────────────────────────────

/// Assess sentience score from AI co-authorship and semantic quality.
/// 1.0 = high AI integration + quality, 0.0 = no AI, poor semantics.
let assessSentience (commits: ParsedCommit[]) : float =
    if commits.Length = 0 then 0.0
    else
        // AI-assisted ratio: commits with "Co-Authored-By" in body
        let aiAssistedCount =
            commits |> Array.filter (fun c ->
                c.Body.Contains("Co-Authored-By", StringComparison.OrdinalIgnoreCase) ||
                c.Body.Contains("Claude", StringComparison.OrdinalIgnoreCase) ||
                c.Body.Contains("Gemini", StringComparison.OrdinalIgnoreCase))
            |> Array.length
        let aiRatio = float aiAssistedCount / float commits.Length
        let aiScore =
            if aiRatio >= 0.5 then 1.0
            elif aiRatio >= 0.2 then 0.7
            elif aiRatio >= 0.05 then 0.4
            else 0.2

        // Semantic density trend
        let meanDensity =
            commits |> Array.averageBy (fun c -> CommitStyle.semanticDensity c.Style)
        let densityScore =
            if meanDensity >= 0.45 then 1.0
            elif meanDensity >= 0.30 then 0.7
            elif meanDensity >= 0.15 then 0.4
            else 0.2

        // ICP adoption as proxy for disciplined (sentient) development
        let icpCount =
            commits |> Array.filter (fun c ->
                c.Style = CommitStyle.IcpConventional || c.Style = CommitStyle.ConventionalNoEmDash)
            |> Array.length
        let icpScore =
            let ratio = float icpCount / float commits.Length
            Math.Min(ratio / 0.8, 1.0)  // 80%+ adoption = perfect score

        // Weighted: AI 30%, density 35%, ICP 35%
        0.30 * aiScore + 0.35 * densityScore + 0.35 * icpScore

// ─────────────────────────────────────────────────────────────────────────────
// Goal 3: Power — Scope breadth, type diversity (Ω₀.7)
// ─────────────────────────────────────────────────────────────────────────────

/// Assess power score from scope coverage and type diversity.
/// 1.0 = broad scope + diverse types, 0.0 = narrow + monoculture.
let assessPower (commits: ParsedCommit[]) : float =
    if commits.Length = 0 then 0.0
    else
        // Scope breadth: unique scopes used / total possible (23)
        let uniqueScopes =
            commits
            |> Array.collect (fun c -> c.Scopes |> List.toArray)
            |> Array.distinct
            |> Array.length
        let scopeBreadth = Math.Min(float uniqueScopes / 15.0, 1.0)  // 15+ = perfect

        // Type diversity: unique types used / total possible (9)
        let uniqueTypes =
            commits
            |> Array.choose (fun c -> c.CommitType)
            |> Array.distinct
            |> Array.length
        let typeDiversity = Math.Min(float uniqueTypes / 7.0, 1.0)  // 7+ = perfect

        // Files breadth: variety of files touched
        let meanFiles =
            if commits.Length = 0 then 0.0
            else commits |> Array.averageBy (fun c -> float c.FilesChanged)
        let fileBreadth =
            if meanFiles >= 5.0 then 1.0
            elif meanFiles >= 2.0 then 0.7
            elif meanFiles >= 1.0 then 0.4
            else 0.2

        // Weighted: scope 40%, type 40%, files 20%
        0.40 * scopeBreadth + 0.40 * typeDiversity + 0.20 * fileBreadth

// ─────────────────────────────────────────────────────────────────────────────
// Overall Alignment Assessment
// ─────────────────────────────────────────────────────────────────────────────

/// Assess overall Founder's Directive alignment.
/// Returns SymbioticAlignment with 3 goal scores + weighted composite.
let assessAlignment (commits: ParsedCommit[]) : SymbioticAlignment =
    let survival = assessSurvival commits
    let sentience = assessSentience commits
    let power = assessPower commits

    // Weighted: 50% Survival + 30% Sentience + 20% Power (per Ω₀ priority)
    let overall = 0.50 * survival + 0.30 * sentience + 0.20 * power

    { SurvivalScore = Math.Round(survival, 4)
      SentienceScore = Math.Round(sentience, 4)
      PowerScore = Math.Round(power, 4)
      OverallAlignment = Math.Round(overall, 4) }

/// Validate that no goal is critically low (< 0.3).
/// Returns Error with failing goal names if any are below threshold.
let validateDirective (alignment: SymbioticAlignment) : Result<unit, string list> =
    let failures = [
        if alignment.SurvivalScore < 0.3 then yield "Survival (Goal 1)"
        if alignment.SentienceScore < 0.3 then yield "Sentience (Goal 2)"
        if alignment.PowerScore < 0.3 then yield "Power (Goal 3)"
    ]
    if failures.IsEmpty then Ok ()
    else Error failures

/// Format alignment report for display.
let formatAlignmentReport (alignment: SymbioticAlignment) : string =
    let sb = System.Text.StringBuilder()
    let bar (v: float) = String.replicate (int (v * 20.0)) "#" + String.replicate (20 - int (v * 20.0)) "."

    sb.AppendLine($"Founder's Directive Alignment: {alignment.OverallAlignment:F4}") |> ignore
    sb.AppendLine($"  Goal 1 (Survival):   [{bar alignment.SurvivalScore}] {alignment.SurvivalScore:F2}") |> ignore
    sb.AppendLine($"  Goal 2 (Sentience):  [{bar alignment.SentienceScore}] {alignment.SentienceScore:F2}") |> ignore
    sb.AppendLine($"  Goal 3 (Power):      [{bar alignment.PowerScore}] {alignment.PowerScore:F2}") |> ignore

    match validateDirective alignment with
    | Ok () -> sb.AppendLine("  Status: ALL GOALS ABOVE THRESHOLD") |> ignore
    | Error failures ->
        let failStr = String.concat ", " failures
        sb.AppendLine($"  WARNING: Goals below threshold: {failStr}") |> ignore

    sb.ToString()
