// =============================================================================
// Git Intelligence — Biomorphic Orchestrator
// =============================================================================
// Purpose:  Unified coordination of all 5 biomorphic subsystems:
//           Immune, Neural, Homeostatic, Regenerative, Symbiotic.
//           Computes overall health via weighted average and determines
//           shouldHalt via 2oo3 voting (Jidoka principle, SC-SIL6-006).
//
// Weights:  Immune 25%, Neural 15%, Homeostatic 25%, Regenerative 20%,
//           Symbiotic 15%
//
// STAMP:    SC-ORCH-001, SC-SIL6-006 (2oo3 voting)
// =============================================================================

module Cepaf.GitIntelligence.BiomorphicOrchestrator

open System

// ─────────────────────────────────────────────────────────────────────────────
// Overall Health Computation
// ─────────────────────────────────────────────────────────────────────────────

/// Weighted average: Immune 25%, Neural 15%, Homeostatic 25%,
/// Regenerative 20%, Symbiotic 15%.
let private computeOverallHealth
    (immunityScore: float)
    (neuralRec: NeuralRecommendation option)
    (homeostasis: HomeostasisState)
    (vitals: VitalSigns)
    (alignment: SymbioticAlignment)
    : float =

    let neuralScore =
        match neuralRec with
        | Some r -> r.SemanticQuality
        | None -> 0.5  // Neutral when no recommendation available

    let homeostaticScore =
        match homeostasis.Mode with
        | HomeostaticMode.Normal -> 1.0
        | HomeostaticMode.Recovery -> 0.7
        | HomeostaticMode.Stressed -> 0.5
        | HomeostaticMode.Degraded -> 0.3
        | HomeostaticMode.Critical -> 0.1

    let regenerativeScore = vitals.HealthIndex

    0.25 * immunityScore +
    0.15 * neuralScore +
    0.25 * homeostaticScore +
    0.20 * regenerativeScore +
    0.15 * alignment.OverallAlignment

// ─────────────────────────────────────────────────────────────────────────────
// 2oo3 Voting for Halt Decision (SC-SIL6-006)
// ─────────────────────────────────────────────────────────────────────────────

/// Determine if system should halt using 2-out-of-3 voting.
/// Voters: Immune (Critical threat), Homeostatic (Critical mode), Regenerative (Pathological).
let private shouldHaltDecision
    (immunityScore: float)
    (homeostasis: HomeostasisState)
    (vitals: VitalSigns)
    : bool =

    let immuneVote = immunityScore < 0.2  // Critical immunity
    let homeostaticVote = homeostasis.Mode = HomeostaticMode.Critical
    let regenerativeVote = Regenerative.isPathological vitals

    let votes = [immuneVote; homeostaticVote; regenerativeVote]
    let yesCount = votes |> List.filter id |> List.length

    yesCount >= 2  // 2-out-of-3 = halt

// ─────────────────────────────────────────────────────────────────────────────
// Full Assessment
// ─────────────────────────────────────────────────────────────────────────────

/// Run full biomorphic assessment across all 5 subsystems.
let runFullAssessment
    (commits: ParsedCommit[])
    (currentGhs: float)
    (previousGhs: float option)
    (pid: PidState)
    (historyEventCount: int)
    : BiomorphicState =

    // 1. Immune: scan for anti-patterns
    let patterns = Immune.scanCommitHistory commits (Some currentGhs) (previousGhs |> Option.map id)
    let threatLevel = Immune.assessThreatLevel patterns (Some currentGhs)
    let immunityScore = Immune.calculateImmunityScore patterns

    // 2. Neural: classify intent of most recent commit
    let neuralRec =
        if commits.Length > 0 then
            let latest = commits |> Array.sortByDescending (fun c -> c.Date) |> Array.head
            Some (Neural.classifyIntent latest)
        else None

    // 3. Homeostatic: PID controller assessment
    let homeostasis = Homeostasis.assess pid currentGhs previousGhs

    // 4. Regenerative: vital signs and diagnosis
    let threatDensity = 1.0 - immunityScore
    let vitals = Regenerative.computeVitalSigns commits currentGhs threatDensity
    let regenActions = Regenerative.diagnose vitals historyEventCount

    // 5. Symbiotic: Founder's Directive alignment
    let alignment = Symbiotic.assessAlignment commits

    // Compute overall health (weighted average)
    let overallHealth = computeOverallHealth immunityScore neuralRec homeostasis vitals alignment

    // Determine shouldHalt via 2oo3 voting (Jidoka, SC-SIL6-006)
    let shouldHalt = shouldHaltDecision immunityScore homeostasis vitals

    { ImmunityScore = immunityScore
      ThreatLevel = threatLevel
      DetectedPatterns = patterns
      NeuralRecommendation = neuralRec
      Homeostasis = homeostasis
      VitalSigns = vitals
      RegenerativeActions = regenActions
      Alignment = alignment
      OverallHealth = Math.Round(overallHealth, 4)
      ShouldHalt = shouldHalt
      Timestamp = DateTimeOffset.UtcNow }

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Formatting
// ─────────────────────────────────────────────────────────────────────────────

/// Format full biomorphic dashboard for terminal display.
let formatBiomorphicDashboard (state: BiomorphicState) : string =
    let sb = System.Text.StringBuilder()
    let bold = "\x1b[1m"
    let reset = "\x1b[0m"
    let green = "\x1b[32m"
    let yellow = "\x1b[33m"
    let red = "\x1b[31m"

    let healthColor =
        if state.OverallHealth >= 0.7 then green
        elif state.OverallHealth >= 0.4 then yellow
        else red

    let bar (v: float) (w: int) =
        let filled = int (v * float w)
        String.replicate (min filled w) "#" + String.replicate (max 0 (w - filled)) "."

    sb.AppendLine($"{bold}╔═══════════════════════════════════════════════════════════╗{reset}") |> ignore
    sb.AppendLine($"{bold}║  BIOMORPHIC HEALTH DASHBOARD                             ║{reset}") |> ignore
    sb.AppendLine($"{bold}╠═══════════════════════════════════════════════════════════╣{reset}") |> ignore
    sb.AppendLine($"║  Overall: {healthColor}{state.OverallHealth:F4}{reset}  [{bar state.OverallHealth 30}]  ║") |> ignore

    if state.ShouldHalt then
        sb.AppendLine($"║  {red}HALT: 2oo3 voting triggered — Jidoka stop{reset}             ║") |> ignore

    sb.AppendLine($"║                                                           ║") |> ignore

    // Immune
    let threatStr =
        match state.ThreatLevel with
        | ThreatLevel.None -> "NONE"
        | ThreatLevel.Low -> "LOW"
        | ThreatLevel.Medium -> "MEDIUM"
        | ThreatLevel.High -> "HIGH"
        | ThreatLevel.Critical -> "CRITICAL"
    sb.AppendLine($"║  Immune:       [{bar state.ImmunityScore 20}] {state.ImmunityScore:F2}  Threat: {threatStr,-8} ║") |> ignore
    sb.AppendLine($"║    Patterns: {state.DetectedPatterns.Length} detected                                ║") |> ignore

    // Neural
    match state.NeuralRecommendation with
    | Some r ->
        let tag = if r.IsHeuristicFallback then "heuristic" else r.Model
        sb.AppendLine($"║  Neural:       quality={r.SemanticQuality:F2}  conf={r.Confidence:F2}  [{tag}]     ║") |> ignore
    | None ->
        sb.AppendLine($"║  Neural:       no recommendation available                ║") |> ignore

    // Homeostatic
    let modeStr =
        match state.Homeostasis.Mode with
        | HomeostaticMode.Normal -> "NORMAL"
        | HomeostaticMode.Stressed -> "STRESSED"
        | HomeostaticMode.Degraded -> "DEGRADED"
        | HomeostaticMode.Critical -> "CRITICAL"
        | HomeostaticMode.Recovery -> "RECOVERY"
    let pidStr = if state.Homeostasis.Pid.Output >= 0.0 then $"+{state.Homeostasis.Pid.Output:F3}" else $"{state.Homeostasis.Pid.Output:F3}"
    sb.AppendLine($"║  Homeostatic:  {modeStr,-10}  PID={pidStr}                    ║") |> ignore

    // Regenerative
    let statusStr =
        if Regenerative.isPathological state.VitalSigns then "PATHOLOGICAL"
        elif Regenerative.isStagnant state.VitalSigns then "STAGNANT"
        else "HEALTHY"
    sb.AppendLine($"║  Regenerative: {statusStr,-12}  H={state.VitalSigns.HealthIndex:F2} S={state.VitalSigns.StressIndex:F2} E={state.VitalSigns.EnergyIndex:F2}  ║") |> ignore

    // Symbiotic
    sb.AppendLine($"║  Symbiotic:    [{bar state.Alignment.OverallAlignment 20}] {state.Alignment.OverallAlignment:F2}            ║") |> ignore
    sb.AppendLine($"║    Survival={state.Alignment.SurvivalScore:F2} Sentience={state.Alignment.SentienceScore:F2} Power={state.Alignment.PowerScore:F2}  ║") |> ignore

    sb.AppendLine($"{bold}╚═══════════════════════════════════════════════════════════╝{reset}") |> ignore
    sb.ToString()
