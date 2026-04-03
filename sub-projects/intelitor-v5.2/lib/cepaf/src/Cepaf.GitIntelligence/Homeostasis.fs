// =============================================================================
// Git Intelligence — Homeostatic Quality PID Controller
// =============================================================================
// Purpose:  Maintain GHS at setpoint (0.85) using a PID controller.
//           Assesses homeostatic mode (Normal/Stressed/Degraded/Critical/Recovery)
//           and generates actionable guidance based on mode + PID output.
//
// PID:      Mirrors HomeostaticGovernor from RegressionRunner.fs
//           Setpoint: 0.85, Kp=0.5, Ki=0.1, Kd=0.05
//           Integral clamped to [-10, 10] to prevent windup
//
// STAMP:    SC-OODA-001 (< 30ms), SC-BIO-EXT-009
// =============================================================================

module Cepaf.GitIntelligence.Homeostasis

open System

// ─────────────────────────────────────────────────────────────────────────────
// PID Controller
// ─────────────────────────────────────────────────────────────────────────────

/// Default PID controller state.
let createPid () : PidState =
    { Setpoint = 0.85
      Kp = 0.5
      Ki = 0.1
      Kd = 0.05
      Integral = 0.0
      PreviousError = 0.0
      Output = 0.0
      LastUpdate = DateTimeOffset.UtcNow }

/// Update PID controller with current GHS measurement.
/// Returns new PidState with updated integral, derivative, and output.
let updatePid (pid: PidState) (currentGhs: float) (now: DateTimeOffset) : PidState =
    let dt =
        let elapsed = (now - pid.LastUpdate).TotalSeconds
        if elapsed <= 0.0 then 1.0 else elapsed

    let error = pid.Setpoint - currentGhs

    // Integral with anti-windup clamping [-10, 10]
    let integral = Math.Clamp(pid.Integral + error * dt, -10.0, 10.0)

    // Derivative (rate of error change)
    let derivative = (error - pid.PreviousError) / dt

    // PID output
    let output = pid.Kp * error + pid.Ki * integral + pid.Kd * derivative

    { pid with
        Integral = integral
        PreviousError = error
        Output = output
        LastUpdate = now }

// ─────────────────────────────────────────────────────────────────────────────
// Mode Assessment
// ─────────────────────────────────────────────────────────────────────────────

/// Assess homeostatic mode based on GHS relative to setpoint.
let assessMode (currentGhs: float) (setpoint: float) (previousGhs: float option) : HomeostaticMode =
    let deviation = setpoint - currentGhs
    let deviationPct = if setpoint = 0.0 then 0.0 else deviation / setpoint

    // Check if recovering (improving from degraded/critical)
    let isRecovering =
        match previousGhs with
        | Some prev when prev < currentGhs && deviationPct > 0.05 -> true
        | _ -> false

    if isRecovering && deviationPct > 0.15 then HomeostaticMode.Recovery
    elif deviationPct > 0.30 then HomeostaticMode.Critical
    elif deviationPct > 0.15 then HomeostaticMode.Degraded
    elif deviationPct > 0.05 then HomeostaticMode.Stressed
    else HomeostaticMode.Normal

// ─────────────────────────────────────────────────────────────────────────────
// Guidance Generation
// ─────────────────────────────────────────────────────────────────────────────

/// Generate actionable guidance based on mode and PID output.
let generateGuidance (mode: HomeostaticMode) (pidOutput: float) (currentGhs: float) : string list =
    let baseGuidance =
        match mode with
        | HomeostaticMode.Normal ->
            [ "GHS within normal range — maintain current practices" ]
        | HomeostaticMode.Stressed ->
            [ "GHS slightly below setpoint"
              "Consider increasing ICP v2.0 adoption rate"
              "Review scope usage diversity" ]
        | HomeostaticMode.Degraded ->
            [ "GHS significantly degraded — corrective action needed"
              "Prioritize ICP-compliant commits"
              "Reduce commit message truncation"
              "Diversify commit types (avoid monoculture)" ]
        | HomeostaticMode.Critical ->
            [ "CRITICAL: GHS dangerously low"
              "HALT non-essential commits until quality improves"
              "Run full commit history review"
              "Reset baseline if sustained degradation"
              "Consider recalibrating PID setpoint" ]
        | HomeostaticMode.Recovery ->
            [ "GHS recovering — positive trend detected"
              "Continue current improvement trajectory"
              "Monitor for regression in next 48h" ]

    let pidGuidance =
        if pidOutput > 0.3 then
            [ $"PID: Strong corrective signal ({pidOutput:F2}) — quality uplift urgently needed" ]
        elif pidOutput > 0.1 then
            [ $"PID: Moderate corrective signal ({pidOutput:F2}) — gradual improvement recommended" ]
        elif pidOutput < -0.1 then
            [ $"PID: Overshoot detected ({pidOutput:F2}) — may relax quality constraints slightly" ]
        else
            []

    baseGuidance @ pidGuidance

// ─────────────────────────────────────────────────────────────────────────────
// Full Assessment
// ─────────────────────────────────────────────────────────────────────────────

/// Run full homeostatic assessment: update PID, assess mode, generate guidance.
let assess (pid: PidState) (currentGhs: float) (previousGhs: float option) : HomeostasisState =
    let now = DateTimeOffset.UtcNow
    let updatedPid = updatePid pid currentGhs now
    let mode = assessMode currentGhs pid.Setpoint previousGhs
    let guidance = generateGuidance mode updatedPid.Output currentGhs

    { Mode = mode
      Pid = updatedPid
      CurrentGhs = currentGhs
      TargetGhs = pid.Setpoint
      Guidance = guidance }

/// Check if homeostatic mode is critical (for Jidoka halt decision).
let isCritical (state: HomeostasisState) : bool =
    state.Mode = HomeostaticMode.Critical

/// Format homeostasis report.
let formatReport (state: HomeostasisState) : string =
    let modeStr =
        match state.Mode with
        | HomeostaticMode.Normal -> "NORMAL"
        | HomeostaticMode.Stressed -> "STRESSED"
        | HomeostaticMode.Degraded -> "DEGRADED"
        | HomeostaticMode.Critical -> "CRITICAL"
        | HomeostaticMode.Recovery -> "RECOVERY"

    let sb = System.Text.StringBuilder()
    sb.AppendLine($"Mode: {modeStr}  |  GHS: {state.CurrentGhs:F4}  |  Target: {state.TargetGhs:F4}") |> ignore
    sb.AppendLine($"PID: output={state.Pid.Output:F4}  integral={state.Pid.Integral:F4}  error={state.Pid.PreviousError:F4}") |> ignore
    sb.AppendLine("Guidance:") |> ignore
    for g in state.Guidance do
        sb.AppendLine($"  • {g}") |> ignore
    sb.ToString()
