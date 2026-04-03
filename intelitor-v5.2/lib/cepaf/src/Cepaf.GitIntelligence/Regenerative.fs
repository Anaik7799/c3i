// =============================================================================
// Git Intelligence — Regenerative (Self-Healing) Subsystem
// =============================================================================
// Purpose:  Compute vital signs for git repository health (Health/Stress/Energy
//           indices), detect pathological states, and recommend regenerative
//           actions (Recompute, Recalibrate, PurgeHistory, ResetBaseline).
//
// Pattern:  Mirrors Bio/Holon.fs VitalSigns pattern from main Cepaf.
//
// STAMP:    SC-BIO-EXT-009, SC-SAFETY-010
// =============================================================================

module Cepaf.GitIntelligence.Regenerative

open System

// ─────────────────────────────────────────────────────────────────────────────
// Vital Signs Computation
// ─────────────────────────────────────────────────────────────────────────────

/// Compute vital signs from commit history, GHS, and threat density.
let computeVitalSigns
    (commits: ParsedCommit[])
    (currentGhs: float)
    (threatDensity: float)   // 0.0-1.0, from Immune.calculateImmunityScore inverted
    : VitalSigns =

    // Health Index: directly from GHS, clamped to [0, 1]
    let healthIndex = Math.Clamp(currentGhs, 0.0, 1.0)

    // Stress Index: inverse of immunity (high threats = high stress)
    let stressIndex = Math.Clamp(threatDensity, 0.0, 1.0)

    // Energy Index: commit velocity normalized to expected rate
    // Expected: ~3-10 commits/day for healthy project
    let recentCommits =
        let now = DateTimeOffset.UtcNow
        commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 7.0) |> Array.length
    let commitsPerDay = float recentCommits / 7.0
    let energyIndex =
        if commitsPerDay >= 3.0 && commitsPerDay <= 10.0 then 1.0
        elif commitsPerDay >= 1.0 then 0.7
        elif commitsPerDay > 0.0 then 0.4
        else 0.1  // Near-zero: repository stagnant

    { HealthIndex = Math.Round(healthIndex, 4)
      StressIndex = Math.Round(stressIndex, 4)
      EnergyIndex = Math.Round(energyIndex, 4) }

// ─────────────────────────────────────────────────────────────────────────────
// Pathological State Detection
// ─────────────────────────────────────────────────────────────────────────────

/// Check if vital signs indicate a pathological state.
/// Pathological = HealthIndex < 0.2 OR StressIndex > 0.95
let isPathological (vitals: VitalSigns) : bool =
    vitals.HealthIndex < 0.2 || vitals.StressIndex > 0.95

/// Check if repository is stagnant (no recent activity).
let isStagnant (vitals: VitalSigns) : bool =
    vitals.EnergyIndex < 0.2

// ─────────────────────────────────────────────────────────────────────────────
// Diagnosis & Regenerative Actions
// ─────────────────────────────────────────────────────────────────────────────

/// Diagnose vital signs and recommend regenerative actions.
let diagnose (vitals: VitalSigns) (historyEventCount: int) : RegenerativeAction list =
    let mutable actions = []

    // Pathological health → reset baseline + recompute
    if vitals.HealthIndex < 0.2 then
        actions <- RegenerativeAction.ResetBaseline :: RegenerativeAction.Recompute :: actions

    // High stress without low health → recalibrate PID
    elif vitals.StressIndex > 0.7 && vitals.HealthIndex >= 0.3 then
        actions <- RegenerativeAction.Recalibrate :: actions

    // Moderate stress → just recompute to get fresh readings
    elif vitals.StressIndex > 0.5 then
        actions <- RegenerativeAction.Recompute :: actions

    // Stagnant energy → recompute with fresh window
    if vitals.EnergyIndex < 0.2 then
        if not (actions |> List.contains RegenerativeAction.Recompute) then
            actions <- RegenerativeAction.Recompute :: actions

    // Large history → suggest purge of stale events (>90 days)
    if historyEventCount > 10000 then
        actions <- RegenerativeAction.PurgeHistory :: actions

    // If nothing needed, explicitly state NoAction
    if actions.IsEmpty then
        [ RegenerativeAction.NoAction ]
    else
        actions |> List.rev

// ─────────────────────────────────────────────────────────────────────────────
// Formatting
// ─────────────────────────────────────────────────────────────────────────────

/// Format vital signs for display.
let formatVitalSigns (vitals: VitalSigns) (actions: RegenerativeAction list) : string =
    let healthBar count total = String.replicate count "#" + String.replicate (total - count) "."
    let sb = System.Text.StringBuilder()

    let pathological = isPathological vitals
    let stagnant = isStagnant vitals

    let statusTag =
        if pathological then "PATHOLOGICAL"
        elif stagnant then "STAGNANT"
        else "HEALTHY"

    sb.AppendLine($"Status: {statusTag}") |> ignore
    sb.AppendLine($"  Health:  [{healthBar (int (vitals.HealthIndex * 20.0)) 20}] {vitals.HealthIndex:F2}") |> ignore
    sb.AppendLine($"  Stress:  [{healthBar (int (vitals.StressIndex * 20.0)) 20}] {vitals.StressIndex:F2}") |> ignore
    sb.AppendLine($"  Energy:  [{healthBar (int (vitals.EnergyIndex * 20.0)) 20}] {vitals.EnergyIndex:F2}") |> ignore

    if not actions.IsEmpty then
        sb.AppendLine("Actions:") |> ignore
        for action in actions do
            let tag =
                match action with
                | RegenerativeAction.Recompute -> "RECOMPUTE"
                | RegenerativeAction.Recalibrate -> "RECALIBRATE"
                | RegenerativeAction.PurgeHistory -> "PURGE_HISTORY"
                | RegenerativeAction.ResetBaseline -> "RESET_BASELINE"
                | RegenerativeAction.NoAction -> "NO_ACTION"
            sb.AppendLine($"  → {tag}") |> ignore

    sb.ToString()
