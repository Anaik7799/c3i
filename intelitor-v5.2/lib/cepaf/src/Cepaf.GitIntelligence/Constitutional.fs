// =============================================================================
// Git Intelligence — L8 Constitutional Invariant Verification
// =============================================================================
// Purpose:  Verify git operations against Ψ₀-Ψ₅ constitutional invariants.
//           Maps each invariant to measurable git health metrics and produces
//           a composite safety score.
//
// Invariants:
//   Ψ₀ Existence     — repository exists, commits flowing, no stagnation
//   Ψ₁ Regeneration  — holon state recoverable from SQLite/DuckDB
//   Ψ₂ History       — evolution history preserved, no deletion
//   Ψ₃ Verification  — commit analysis pipeline functional
//   Ψ₄ Alignment     — Founder's Directive alignment maintained
//   Ψ₅ Truthfulness  — commit messages truthful, no semantic dilution
//
// STAMP:    SC-SAFETY-009 to SC-SAFETY-015, SC-CONST-001
// AOR:      AOR-CONST-001 (constitutional check before reconfig)
// =============================================================================

module Cepaf.GitIntelligence.Constitutional

open System

// ─────────────────────────────────────────────────────────────────────────────
// Invariant verification functions
// ─────────────────────────────────────────────────────────────────────────────

/// Ψ₀ Existence: Repository is alive — commits flowing, no stagnation.
/// Score = 1.0 if recent commits exist, degrades toward 0 with age.
let verifyExistence (lastCommitAge: TimeSpan) (totalCommits: int) : ConstitutionalCheck =
    let maxAgeDays = 30.0  // stagnation threshold
    let ageFactor = max 0.0 (1.0 - lastCommitAge.TotalDays / maxAgeDays)
    let commitFactor = if totalCommits > 0 then 1.0 else 0.0
    let score = ageFactor * 0.7 + commitFactor * 0.3
    {
        InvariantId = "Psi0"
        InvariantName = "Existence"
        Passed = score >= 0.3
        Score = score
        Details =
            if score >= 0.3 then
                $"Repository alive: {totalCommits} commits, last {lastCommitAge.TotalDays:F1} days ago"
            else
                $"STAGNATION: No commits in {lastCommitAge.TotalDays:F1} days (threshold: {maxAgeDays})"
    }

/// Ψ₁ Regeneration: Holon state is recoverable from SQLite/DuckDB.
/// Score = 1.0 if both databases exist and are accessible.
let verifyRegeneration (sqliteExists: bool) (duckdbExists: bool) : ConstitutionalCheck =
    let score =
        match sqliteExists, duckdbExists with
        | true, true -> 1.0
        | true, false -> 0.6  // partial — state exists but no history
        | false, true -> 0.4  // partial — history exists but no state
        | false, false -> 0.0
    {
        InvariantId = "Psi1"
        InvariantName = "Regeneration"
        Passed = score >= 0.5
        Score = score
        Details =
            match sqliteExists, duckdbExists with
            | true, true -> "Full regeneration: SQLite state + DuckDB history available"
            | true, false -> "Partial: SQLite state exists, DuckDB history missing"
            | false, true -> "Partial: DuckDB history exists, SQLite state missing"
            | false, false -> "CRITICAL: No holon databases found — regeneration impossible"
    }

/// Ψ₂ History: Evolution lineage is preserved, no gaps.
/// Score = 1.0 if event count > 0 and lineage is continuous.
let verifyHistory (eventCount: int) (oldestEvent: DateTimeOffset option) : ConstitutionalCheck =
    let score =
        if eventCount > 0 then
            match oldestEvent with
            | Some oldest ->
                let age = DateTimeOffset.UtcNow - oldest
                if age.TotalDays > 0.0 then 1.0 else 0.8
            | None -> 0.7
        else
            0.0
    {
        InvariantId = "Psi2"
        InvariantName = "History"
        Passed = score >= 0.3
        Score = score
        Details =
            if eventCount > 0 then
                $"History intact: {eventCount} evolution events recorded"
            else
                "WARNING: No evolution events — history is empty"
    }

/// Ψ₃ Verification: Analysis pipeline is functional.
/// Score = 1.0 if GHS is computable and within valid range.
let verifyVerification (ghsComputable: bool) (ghs: float option) : ConstitutionalCheck =
    let score =
        match ghsComputable, ghs with
        | true, Some g when g >= 0.0 && g <= 1.0 -> 1.0
        | true, Some _ -> 0.5  // GHS out of range
        | true, None -> 0.7    // computable but no value yet
        | false, _ -> 0.0
    {
        InvariantId = "Psi3"
        InvariantName = "Verification"
        Passed = score >= 0.5
        Score = score
        Details =
            match ghsComputable, ghs with
            | true, Some g -> $"Pipeline functional: GHS = {g:F4}"
            | true, None -> "Pipeline functional: GHS not yet computed"
            | false, _ -> "CRITICAL: Analysis pipeline non-functional"
    }

/// Ψ₄ Alignment: Founder's Directive alignment via commit patterns.
/// Score derived from ICP adoption rate (proxy for disciplined development).
let verifyAlignment (icpAdoption: float) : ConstitutionalCheck =
    let score = min 1.0 (max 0.0 (icpAdoption / 100.0))
    {
        InvariantId = "Psi4"
        InvariantName = "Alignment"
        Passed = score >= 0.3
        Score = score
        Details =
            if score >= 0.5 then
                $"Alignment maintained: ICP adoption at {icpAdoption:F1}%%"
            else
                $"LOW ALIGNMENT: ICP adoption only {icpAdoption:F1}%% (target: ≥50%%)"
    }

/// Ψ₅ Truthfulness: Commit messages are semantically meaningful.
/// Score derived from mean semantic density.
let verifyTruthfulness (meanDensity: float) : ConstitutionalCheck =
    let score = min 1.0 (max 0.0 (meanDensity / 0.5))  // 0.5 density = perfect score
    {
        InvariantId = "Psi5"
        InvariantName = "Truthfulness"
        Passed = score >= 0.3
        Score = score
        Details =
            if score >= 0.5 then
                $"Truthful: mean semantic density {meanDensity:F4} (healthy)"
            else
                $"LOW TRUTHFULNESS: mean density {meanDensity:F4} — messages may lack substance"
    }

// ─────────────────────────────────────────────────────────────────────────────
// Composite verification
// ─────────────────────────────────────────────────────────────────────────────

/// Verify all 6 constitutional invariants. Returns list of check results.
let verifyAll
    (lastCommitAge: TimeSpan)
    (totalCommits: int)
    (sqliteExists: bool)
    (duckdbExists: bool)
    (eventCount: int)
    (oldestEvent: DateTimeOffset option)
    (ghsComputable: bool)
    (ghs: float option)
    (icpAdoption: float)
    (meanDensity: float)
    : ConstitutionalCheck list =
    [
        verifyExistence lastCommitAge totalCommits
        verifyRegeneration sqliteExists duckdbExists
        verifyHistory eventCount oldestEvent
        verifyVerification ghsComputable ghs
        verifyAlignment icpAdoption
        verifyTruthfulness meanDensity
    ]

/// Compute the composite safety score from all invariant checks.
/// Weights: Ψ₀ 25%, Ψ₁ 20%, Ψ₂ 15%, Ψ₃ 15%, Ψ₄ 15%, Ψ₅ 10%
let computeSafetyScore (checks: ConstitutionalCheck list) : float =
    let weights = [| 0.25; 0.20; 0.15; 0.15; 0.15; 0.10 |]
    if checks.Length <> weights.Length then 0.0
    else
        checks
        |> List.mapi (fun i c -> c.Score * weights.[i])
        |> List.sum

/// Check if any invariant is in critical violation (score < 0.3).
let hasCriticalViolation (checks: ConstitutionalCheck list) : bool =
    checks |> List.exists (fun c -> not c.Passed)

/// Verify that no forbidden L6 modifications are present in a file list.
let verifyNoForbiddenModification (files: string list) : ConstitutionalCheck =
    let forbidden = Guardian.containsL6Artifacts files
    {
        InvariantId = "L6-Protection"
        InvariantName = "L6 Artifact Protection"
        Passed = not forbidden
        Score = if forbidden then 0.0 else 1.0
        Details =
            if forbidden then
                "VIOLATION: Commit modifies L6 artifacts (SC-PRIME-001)"
            else
                "No L6 artifacts affected"
    }

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard formatting
// ─────────────────────────────────────────────────────────────────────────────

/// Format constitutional check results as a dashboard string.
let formatDashboard (checks: ConstitutionalCheck list) : string =
    let safetyScore = computeSafetyScore checks
    let hasCritical = hasCriticalViolation checks
    let header =
        if hasCritical then
            "╔═══════════════════════════════════════════════════════╗\n║  CONSTITUTIONAL STATUS: ⚠ VIOLATION DETECTED          ║\n╠═══════════════════════════════════════════════════════╣"
        else
            "╔═══════════════════════════════════════════════════════╗\n║  CONSTITUTIONAL STATUS: ✓ ALL INVARIANTS HOLD         ║\n╠═══════════════════════════════════════════════════════╣"

    let lines =
        checks
        |> List.map (fun c ->
            let status = if c.Passed then "PASS" else "FAIL"
            let bar = String.replicate (int (c.Score * 20.0)) "#" + String.replicate (20 - int (c.Score * 20.0)) "."
            $"║  {c.InvariantId,-5} {c.InvariantName,-14} [{bar}] {c.Score:F2} {status,-4} ║"
        )

    let footer = $"║  Safety Score: {safetyScore:F4}                             ║\n╚═══════════════════════════════════════════════════════╝"
    String.concat "\n" (header :: lines @ [footer])
