// =============================================================================
// Git Intelligence — Analysis Engine
// =============================================================================
// Purpose:  Compute Git Health Score (GHS), Shannon entropy, style distributions,
//           scope compliance, monthly breakdowns, information-theoretic metrics.
//
// Math:     H(X) = -Σ p(x) log₂ p(x)  (Shannon entropy)
//           GHS  = I_actual / I_potential  (information utilization ratio)
//           ρ    = bits / characters  (semantic density)
//
// STAMP:    SC-CHG-001, SC-CHG-002
// =============================================================================

module Cepaf.GitIntelligence.Analysis

open System

// ─────────────────────────────────────────────────────────────────────────────
// Information Theory
// ─────────────────────────────────────────────────────────────────────────────

/// Shannon entropy: H(X) = -Σ p(x) log₂ p(x)
let shannonEntropy (counts: int[]) : float =
    let total = float (Array.sum counts)
    if total = 0.0 then 0.0
    else
        counts
        |> Array.filter (fun c -> c > 0)
        |> Array.sumBy (fun c ->
            let p = float c / total
            -p * Math.Log(p, 2.0))

/// Maximum possible entropy for N categories: log₂(N)
let maxEntropy (n: int) : float =
    if n <= 1 then 0.0
    else Math.Log(float n, 2.0)

// ─────────────────────────────────────────────────────────────────────────────
// Style Distribution
// ─────────────────────────────────────────────────────────────────────────────

let computeStyleDistribution (commits: ParsedCommit[]) : StyleDistribution list =
    let total = float commits.Length
    if total = 0.0 then []
    else
        commits
        |> Array.groupBy (fun c -> c.Style)
        |> Array.map (fun (style, group) ->
            { Style = style
              Count = group.Length
              Percentage = float group.Length / total * 100.0 })
        |> Array.sortByDescending (fun d -> d.Count)
        |> Array.toList

// ─────────────────────────────────────────────────────────────────────────────
// Scope Compliance
// ─────────────────────────────────────────────────────────────────────────────

let computeScopeCompliance (commits: ParsedCommit[]) : ScopeCompliance =
    // Only consider commits that have any scope at all
    let scoped = commits |> Array.filter (fun c -> not c.RawScopes.IsEmpty)
    let totalScoped = scoped.Length

    let allRawScopes =
        scoped
        |> Array.collect (fun c -> c.RawScopes |> List.toArray)
        |> Array.filter (fun s -> s <> "")

    let isValidOrMapped s =
        IcpScope.fromTag s <> None || Parser.mapHistoricalScope s <> None
    let valid = allRawScopes |> Array.filter isValidOrMapped
    let invalid = allRawScopes |> Array.filter (fun s -> not (isValidOrMapped s))

    let uniqueUsed = allRawScopes |> Array.distinct |> Array.sort |> Array.toList
    let invalidList = invalid |> Array.distinct |> Array.sort |> Array.toList

    { TotalScopedCommits = totalScoped
      ValidScopes = valid.Length
      InvalidScopes = invalid.Length
      ComplianceRate = if allRawScopes.Length = 0 then 0.0
                       else float valid.Length / float allRawScopes.Length * 100.0
      UniqueScopesUsed = uniqueUsed
      InvalidScopesList = invalidList }

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Breakdown
// ─────────────────────────────────────────────────────────────────────────────

let computeMonthlyBreakdown (commits: ParsedCommit[]) : MonthlyBreakdown list =
    commits
    |> Array.groupBy (fun c -> c.Date.ToString("yyyy-MM"))
    |> Array.sortBy fst
    |> Array.map (fun (month, group) ->
        let icpCount =
            group |> Array.filter (fun c ->
                c.Style = CommitStyle.IcpConventional || c.Style = CommitStyle.ConventionalNoEmDash)
            |> Array.length
        let meanSubject =
            if group.Length = 0 then 0.0
            else group |> Array.averageBy (fun c -> float c.SubjectLength)
        let meanFiles =
            if group.Length = 0 then 0.0
            else group |> Array.averageBy (fun c -> float c.FilesChanged)
        { Month = month
          CommitCount = group.Length
          IcpCount = icpCount
          IcpRate = if group.Length = 0 then 0.0 else float icpCount / float group.Length * 100.0
          MeanSubjectLength = meanSubject
          MeanFilesChanged = meanFiles })
    |> Array.toList

// ─────────────────────────────────────────────────────────────────────────────
// Git Health Score (GHS)
// ─────────────────────────────────────────────────────────────────────────────
//
// GHS = weighted combination of:
//   - Type entropy utilization (actual / max)
//   - Scope compliance rate
//   - ICP adoption rate
//   - Mean semantic density normalized
//
// GHS ∈ [0, 1] where 1.0 = perfect ICP v2.0 compliance
// ─────────────────────────────────────────────────────────────────────────────

let computeHealthScore (commits: ParsedCommit[]) (scopeCompliance: ScopeCompliance) : GitHealthScore =
    if commits.Length = 0 then
        { Score = 0.0; TypeEntropy = 0.0; ScopeEntropy = 0.0
          IcpAdoption = 0.0; MeanSemanticDensity = 0.0; ScopeCompliance = 0.0 }
    else
        // Type entropy
        let typeCounts =
            CommitType.all
            |> Array.map (fun t ->
                commits |> Array.filter (fun c -> c.CommitType = Some t) |> Array.length)
        let typeH = shannonEntropy typeCounts
        let typeMaxH = maxEntropy CommitType.all.Length  // log₂(9) ≈ 3.17
        let typeUtilization = if typeMaxH = 0.0 then 0.0 else typeH / typeMaxH

        // Scope entropy (over 23-scope taxonomy)
        let scopeCounts =
            IcpScope.all
            |> Array.map (fun s ->
                commits |> Array.filter (fun c -> c.Scopes |> List.contains s) |> Array.length)
        let scopeH = shannonEntropy scopeCounts
        let scopeMaxH = maxEntropy IcpScope.all.Length  // log₂(23) ≈ 4.52
        let scopeUtilization = if scopeMaxH = 0.0 then 0.0 else scopeH / scopeMaxH

        // ICP adoption rate
        let icpCount =
            commits |> Array.filter (fun c ->
                c.Style = CommitStyle.IcpConventional || c.Style = CommitStyle.ConventionalNoEmDash)
            |> Array.length
        let icpAdoption = float icpCount / float commits.Length

        // Mean semantic density
        let meanDensity =
            commits |> Array.averageBy (fun c -> CommitStyle.semanticDensity c.Style)
        // Normalize to [0, 1] — max theoretical density is ICP at 0.568
        let normalizedDensity = Math.Min(meanDensity / 0.568, 1.0)

        let scopeComplianceRate = scopeCompliance.ComplianceRate / 100.0

        // Weighted GHS: type(20%) + scope(20%) + adoption(30%) + density(15%) + compliance(15%)
        let ghs =
            0.20 * typeUtilization +
            0.20 * scopeUtilization +
            0.30 * icpAdoption +
            0.15 * normalizedDensity +
            0.15 * scopeComplianceRate

        { Score = Math.Round(ghs, 4)
          TypeEntropy = Math.Round(typeH, 3)
          ScopeEntropy = Math.Round(scopeH, 3)
          IcpAdoption = Math.Round(icpAdoption, 4)
          MeanSemanticDensity = Math.Round(meanDensity, 4)
          ScopeCompliance = Math.Round(scopeComplianceRate, 4) }

// ─────────────────────────────────────────────────────────────────────────────
// Full Analysis
// ─────────────────────────────────────────────────────────────────────────────

let analyze (commits: ParsedCommit[]) : CommitAnalysis =
    let styleDist = computeStyleDistribution commits
    let scopeComp = computeScopeCompliance commits
    let monthly = computeMonthlyBreakdown commits
    let healthScore = computeHealthScore commits scopeComp

    let subjectLengths = commits |> Array.map (fun c -> c.SubjectLength) |> Array.sort
    let meanLength =
        if commits.Length = 0 then 0.0
        else commits |> Array.averageBy (fun c -> float c.SubjectLength)
    let medianLength =
        if subjectLengths.Length = 0 then 0
        else subjectLengths.[subjectLengths.Length / 2]
    let longCount = commits |> Array.filter (fun c -> c.SubjectLength > 80) |> Array.length

    let dateRange =
        if commits.Length = 0 then (DateTimeOffset.MinValue, DateTimeOffset.MinValue)
        else
            let sorted = commits |> Array.sortBy (fun c -> c.Date)
            (sorted.[0].Date, sorted.[sorted.Length - 1].Date)

    { TotalCommits = commits.Length
      DateRange = dateRange
      StyleDistribution = styleDist
      ScopeCompliance = scopeComp
      MonthlyBreakdown = monthly
      HealthScore = healthScore
      MeanSubjectLength = Math.Round(meanLength, 1)
      MedianSubjectLength = medianLength
      LongSubjects = longCount }

// ─────────────────────────────────────────────────────────────────────────────
// JSON Output (using System.Text.Json.JsonDocument pattern)
// ─────────────────────────────────────────────────────────────────────────────

let analysisToJson (a: CommitAnalysis) : string =
    let sb = System.Text.StringBuilder()
    sb.AppendLine("{") |> ignore
    sb.AppendLine(sprintf "  \"totalCommits\": %d," a.TotalCommits) |> ignore

    let (dStart, dEnd) = a.DateRange
    sb.AppendLine(sprintf "  \"dateRange\": { \"from\": \"%s\", \"to\": \"%s\" },"
        (dStart.ToString("yyyy-MM-dd")) (dEnd.ToString("yyyy-MM-dd"))) |> ignore

    // Health Score
    let h = a.HealthScore
    sb.AppendLine("  \"healthScore\": {") |> ignore
    sb.AppendLine(sprintf "    \"ghs\": %.4f," h.Score) |> ignore
    sb.AppendLine(sprintf "    \"typeEntropy\": %.3f," h.TypeEntropy) |> ignore
    sb.AppendLine(sprintf "    \"scopeEntropy\": %.3f," h.ScopeEntropy) |> ignore
    sb.AppendLine(sprintf "    \"icpAdoption\": %.4f," h.IcpAdoption) |> ignore
    sb.AppendLine(sprintf "    \"meanSemanticDensity\": %.4f," h.MeanSemanticDensity) |> ignore
    sb.AppendLine(sprintf "    \"scopeCompliance\": %.4f" h.ScopeCompliance) |> ignore
    sb.AppendLine("  },") |> ignore

    // Style Distribution
    sb.AppendLine("  \"styleDistribution\": [") |> ignore
    let styles = a.StyleDistribution
    for i in 0 .. styles.Length - 1 do
        let s = styles.[i]
        let comma = if i < styles.Length - 1 then "," else ""
        sb.AppendLine(sprintf "    { \"style\": \"%s\", \"count\": %d, \"percentage\": %.1f }%s"
            (CommitStyle.label s.Style) s.Count s.Percentage comma) |> ignore
    sb.AppendLine("  ],") |> ignore

    // Scope Compliance
    let sc = a.ScopeCompliance
    sb.AppendLine("  \"scopeCompliance\": {") |> ignore
    sb.AppendLine(sprintf "    \"totalScoped\": %d," sc.TotalScopedCommits) |> ignore
    sb.AppendLine(sprintf "    \"valid\": %d," sc.ValidScopes) |> ignore
    sb.AppendLine(sprintf "    \"invalid\": %d," sc.InvalidScopes) |> ignore
    sb.AppendLine(sprintf "    \"rate\": %.1f," sc.ComplianceRate) |> ignore
    sb.AppendLine(sprintf "    \"uniqueScopes\": %d," sc.UniqueScopesUsed.Length) |> ignore
    sb.AppendLine(sprintf "    \"invalidScopes\": [%s]"
        (sc.InvalidScopesList |> List.map (sprintf "\"%s\"") |> String.concat ", ")) |> ignore
    sb.AppendLine("  },") |> ignore

    // Monthly
    sb.AppendLine("  \"monthly\": [") |> ignore
    let months = a.MonthlyBreakdown
    for i in 0 .. months.Length - 1 do
        let m = months.[i]
        let comma = if i < months.Length - 1 then "," else ""
        sb.AppendLine(sprintf "    { \"month\": \"%s\", \"commits\": %d, \"icpRate\": %.1f }%s"
            m.Month m.CommitCount m.IcpRate comma) |> ignore
    sb.AppendLine("  ],") |> ignore

    // Subject stats
    sb.AppendLine(sprintf "  \"meanSubjectLength\": %.1f," a.MeanSubjectLength) |> ignore
    sb.AppendLine(sprintf "  \"medianSubjectLength\": %d," a.MedianSubjectLength) |> ignore
    sb.AppendLine(sprintf "  \"longSubjects\": %d" a.LongSubjects) |> ignore

    sb.AppendLine("}") |> ignore
    sb.ToString()

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard (ANSI terminal output)
// ─────────────────────────────────────────────────────────────────────────────

let private bar (value: float) (max: float) (width: int) : string =
    let filled = int (value / max * float width)
    let filled = Math.Min(filled, width)
    String.replicate filled "\u2588" + String.replicate (width - filled) "\u2591"

let printDashboard (a: CommitAnalysis) =
    let h = a.HealthScore
    let ghsColor =
        if h.Score >= 0.85 then "\x1b[32m"   // green
        elif h.Score >= 0.50 then "\x1b[33m" // yellow
        else "\x1b[31m"                       // red
    let reset = "\x1b[0m"
    let bold = "\x1b[1m"
    let dim = "\x1b[2m"

    let (dStart, dEnd) = a.DateRange

    printfn ""
    printfn "%s╔═══════════════════════════════════════════════════════════════╗%s" bold reset
    printfn "%s║  GIT INTELLIGENCE — ICP v2.0 Health Dashboard               ║%s" bold reset
    printfn "%s╠═══════════════════════════════════════════════════════════════╣%s" bold reset
    printfn   "║  Commits: %-6d  Range: %s → %s  ║"
        a.TotalCommits (dStart.ToString("yyyy-MM-dd")) (dEnd.ToString("yyyy-MM-dd"))
    printfn "%s╠═══════════════════════════════════════════════════════════════╣%s" bold reset
    printfn   "║                                                               ║"
    printfn   "║  %sGit Health Score (GHS)%s                                      ║" bold reset
    printfn   "║  %s%s %.4f%s  %s  ║"
        ghsColor bold h.Score reset (bar h.Score 1.0 30)
    printfn   "║                                                               ║"
    printfn   "║  Components:                                                   ║"
    printfn   "║    Type Entropy:    %s %.3f / %.3f bits%s         ║"
        dim h.TypeEntropy (maxEntropy CommitType.all.Length) reset
    printfn   "║    Scope Entropy:   %s %.3f / %.3f bits%s         ║"
        dim h.ScopeEntropy (maxEntropy IcpScope.all.Length) reset
    printfn   "║    ICP Adoption:    %s %.1f%%%s                              ║"
        dim (h.IcpAdoption * 100.0) reset
    printfn   "║    Semantic ρ:      %s %.4f bits/char%s                 ║"
        dim h.MeanSemanticDensity reset
    printfn   "║    Scope Comply:    %s %.1f%%%s                              ║"
        dim (h.ScopeCompliance * 100.0) reset
    printfn   "║                                                               ║"
    printfn "%s╠═══════════════════════════════════════════════════════════════╣%s" bold reset
    printfn   "║  %sStyle Distribution%s                                          ║" bold reset

    for s in a.StyleDistribution do
        let label = sprintf "%-20s" (CommitStyle.label s.Style)
        printfn "║    %s %4d (%5.1f%%)  %s  ║" label s.Count s.Percentage (bar s.Percentage 100.0 14)

    printfn   "║                                                               ║"
    printfn "%s╠═══════════════════════════════════════════════════════════════╣%s" bold reset
    printfn   "║  %sScope Compliance%s                                             ║" bold reset
    printfn   "║    Valid: %d / %d scopes (%.1f%%)                            ║"
        a.ScopeCompliance.ValidScopes
        (a.ScopeCompliance.ValidScopes + a.ScopeCompliance.InvalidScopes)
        a.ScopeCompliance.ComplianceRate

    if not a.ScopeCompliance.InvalidScopesList.IsEmpty then
        printfn "║    %sInvalid:%s %s ║"
            dim reset
            (a.ScopeCompliance.InvalidScopesList |> List.truncate 8 |> String.concat ", "
             |> fun s -> if s.Length > 45 then s.Substring(0, 42) + "..." else s)

    printfn   "║                                                               ║"
    printfn "%s╠═══════════════════════════════════════════════════════════════╣%s" bold reset
    printfn   "║  %sMonthly Trend%s                                                ║" bold reset

    for m in a.MonthlyBreakdown do
        printfn "║    %s  %3d commits  ICP: %5.1f%%  %s  ║"
            m.Month m.CommitCount m.IcpRate (bar m.IcpRate 100.0 14)

    printfn   "║                                                               ║"
    printfn "%s╠═══════════════════════════════════════════════════════════════╣%s" bold reset
    printfn   "║  Subject: mean=%.1f  median=%d  >80chars=%d                  ║"
        a.MeanSubjectLength a.MedianSubjectLength a.LongSubjects
    printfn "%s╚═══════════════════════════════════════════════════════════════╝%s" bold reset
    printfn ""
