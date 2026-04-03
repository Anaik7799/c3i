/// Avalonia GUI Component Tests
/// Tests for Fabulous/Avalonia UI components
module Cepaf.Cockpit.Avalonia.Tests.ComponentTests

open System
open Expecto

// ============================================================================
// Navigation Rail Component Tests
// ============================================================================

type NavigationItem = {
    Icon: string
    Label: string
    Page: string
    Badge: int option
    IsActive: bool
}

let createNavItems activeIndex badges =
    let items = [
        ("dashboard", "Dashboard")
        ("alarm", "Alarms")
        ("shield", "Guardian")
        ("security", "Sentinel")
        ("devices", "Devices")
        ("settings", "Settings")
    ]
    items |> List.mapi (fun i (icon, label) ->
        {
            Icon = icon
            Label = label
            Page = label.ToLower()
            Badge = Map.tryFind label badges
            IsActive = i = activeIndex
        })

let navItemClass (item: NavigationItem) =
    let baseClass = "nav-item"
    let activeClass = if item.IsActive then " active" else ""
    let badgeClass = if item.Badge.IsSome then " has-badge" else ""
    sprintf "%s%s%s" baseClass activeClass badgeClass

[<Tests>]
let navigationRailTests =
    testList "NavigationRail" [
        test "should create correct number of nav items" {
            let items = createNavItems 0 Map.empty
            Expect.equal items.Length 6 "Should have 6 nav items"
        }

        test "should mark active item" {
            let items = createNavItems 2 Map.empty
            Expect.isTrue items.[2].IsActive "Index 2 should be active"
            Expect.isFalse items.[0].IsActive "Index 0 should not be active"
        }

        test "should apply badges" {
            let badges = Map.ofList [("Alarms", 5); ("Guardian", 2)]
            let items = createNavItems 0 badges
            Expect.equal items.[1].Badge (Some 5) "Alarms should have badge 5"
            Expect.equal items.[2].Badge (Some 2) "Guardian should have badge 2"
            Expect.isNone items.[0].Badge "Dashboard has no badge"
        }

        test "should have correct classes" {
            let item = { Icon = "dashboard"; Label = "Dashboard"; Page = "dashboard"; Badge = None; IsActive = true }
            let cls = navItemClass item
            Expect.stringContains cls "active" "Active item has active class"
        }

        test "should have badge class when badge present" {
            let item = { Icon = "alarm"; Label = "Alarms"; Page = "alarms"; Badge = Some 5; IsActive = false }
            let cls = navItemClass item
            Expect.stringContains cls "has-badge" "Badged item has badge class"
        }
    ]

// ============================================================================
// Health Indicator Component Tests
// ============================================================================

type HealthIndicatorState = {
    Score: float
    Trend: string  // "up" | "down" | "stable"
    LastUpdate: DateTime option
}

let healthIndicatorColor (state: HealthIndicatorState) =
    if state.Score >= 90.0 then "#00FF00"  // Green
    elif state.Score >= 70.0 then "#FFA500" // Orange
    elif state.Score >= 50.0 then "#FFFF00" // Yellow
    else "#FF0000"  // Red

let healthIndicatorIcon (state: HealthIndicatorState) =
    match state.Trend with
    | "up" -> "trending_up"
    | "down" -> "trending_down"
    | _ -> "trending_flat"

let isHealthStale (state: HealthIndicatorState) =
    match state.LastUpdate with
    | None -> true
    | Some t -> DateTime.UtcNow - t > TimeSpan.FromSeconds(30.0)

[<Tests>]
let healthIndicatorTests =
    testList "HealthIndicator" [
        test "should return green for excellent health" {
            let state = { Score = 95.0; Trend = "stable"; LastUpdate = Some DateTime.UtcNow }
            Expect.equal (healthIndicatorColor state) "#00FF00" "95% is green"
        }

        test "should return orange for good health" {
            let state = { Score = 75.0; Trend = "stable"; LastUpdate = Some DateTime.UtcNow }
            Expect.equal (healthIndicatorColor state) "#FFA500" "75% is orange"
        }

        test "should return red for poor health" {
            let state = { Score = 30.0; Trend = "down"; LastUpdate = Some DateTime.UtcNow }
            Expect.equal (healthIndicatorColor state) "#FF0000" "30% is red"
        }

        test "should show correct trend icon" {
            let up = { Score = 90.0; Trend = "up"; LastUpdate = None }
            let down = { Score = 90.0; Trend = "down"; LastUpdate = None }
            let stable = { Score = 90.0; Trend = "stable"; LastUpdate = None }

            Expect.equal (healthIndicatorIcon up) "trending_up" "Up trend"
            Expect.equal (healthIndicatorIcon down) "trending_down" "Down trend"
            Expect.equal (healthIndicatorIcon stable) "trending_flat" "Stable trend"
        }

        test "should detect stale data" {
            let fresh = { Score = 90.0; Trend = "stable"; LastUpdate = Some DateTime.UtcNow }
            let stale = { Score = 90.0; Trend = "stable"; LastUpdate = Some (DateTime.UtcNow.AddMinutes(-1.0)) }
            let noData = { Score = 90.0; Trend = "stable"; LastUpdate = None }

            Expect.isFalse (isHealthStale fresh) "Fresh data is not stale"
            Expect.isTrue (isHealthStale stale) "Old data is stale"
            Expect.isTrue (isHealthStale noData) "No data is stale"
        }
    ]

// ============================================================================
// Metrics Card Component Tests
// ============================================================================

type MetricsCardState = {
    Title: string
    Value: string
    Unit: string option
    Change: float option
    Sparkline: float list
}

let metricsCardChangeClass (change: float option) =
    match change with
    | None -> "neutral"
    | Some c when c > 0.0 -> "positive"
    | Some c when c < 0.0 -> "negative"
    | Some _ -> "neutral"

let formatChange (change: float option) =
    match change with
    | None -> ""
    | Some c when c > 0.0 -> sprintf "+%.1f%%" c
    | Some c when c < 0.0 -> sprintf "%.1f%%" c
    | Some _ -> "0.0%"

let normalizeSparkline (values: float list) =
    if values.IsEmpty then []
    else
        let minVal = List.min values
        let maxVal = List.max values
        let range = maxVal - minVal
        if range = 0.0 then List.replicate values.Length 0.5
        else values |> List.map (fun v -> (v - minVal) / range)

[<Tests>]
let metricsCardTests =
    testList "MetricsCard" [
        test "should classify positive change" {
            Expect.equal (metricsCardChangeClass (Some 5.0)) "positive" "Positive change"
        }

        test "should classify negative change" {
            Expect.equal (metricsCardChangeClass (Some -3.0)) "negative" "Negative change"
        }

        test "should classify neutral change" {
            Expect.equal (metricsCardChangeClass (Some 0.0)) "neutral" "Zero change"
            Expect.equal (metricsCardChangeClass None) "neutral" "No change"
        }

        test "should format change with sign" {
            Expect.equal (formatChange (Some 5.2)) "+5.2%" "Positive format"
            Expect.equal (formatChange (Some -3.1)) "-3.1%" "Negative format"
            Expect.equal (formatChange (Some 0.0)) "0.0%" "Zero format"
        }

        test "should normalize sparkline to 0-1" {
            let values = [10.0; 20.0; 30.0; 40.0; 50.0]
            let normalized = normalizeSparkline values
            Expect.equal normalized.[0] 0.0 "Min becomes 0"
            Expect.equal normalized.[4] 1.0 "Max becomes 1"
            Expect.equal normalized.[2] 0.5 "Mid becomes 0.5"
        }

        test "should handle flat sparkline" {
            let values = [50.0; 50.0; 50.0]
            let normalized = normalizeSparkline values
            Expect.all normalized (fun v -> v = 0.5) "Flat becomes all 0.5"
        }
    ]

// ============================================================================
// OODA Status Component Tests
// ============================================================================

type OodaPhase =
    | Observe
    | Orient
    | Decide
    | Act

type OodaStatusState = {
    CurrentPhase: OodaPhase
    CycleTime: TimeSpan
    CyclesCompleted: int
    IsActive: bool
}

let oodaPhaseIndex (phase: OodaPhase) =
    match phase with
    | Observe -> 0
    | Orient -> 1
    | Decide -> 2
    | Act -> 3

let oodaPhaseColor (phase: OodaPhase) (isActive: bool) =
    if not isActive then "#808080"  // Gray
    else
        match phase with
        | Observe -> "#00BFFF"  // Deep Sky Blue
        | Orient -> "#9370DB"   // Medium Purple
        | Decide -> "#FFD700"   // Gold
        | Act -> "#32CD32"      // Lime Green

let oodaCycleMeetsTarget (state: OodaStatusState) =
    state.CycleTime <= TimeSpan.FromMilliseconds(100.0)

[<Tests>]
let oodaStatusTests =
    testList "OodaStatus" [
        test "should have correct phase indices" {
            Expect.equal (oodaPhaseIndex Observe) 0 "Observe is 0"
            Expect.equal (oodaPhaseIndex Orient) 1 "Orient is 1"
            Expect.equal (oodaPhaseIndex Decide) 2 "Decide is 2"
            Expect.equal (oodaPhaseIndex Act) 3 "Act is 3"
        }

        test "should return gray when inactive" {
            Expect.equal (oodaPhaseColor Observe false) "#808080" "Inactive is gray"
        }

        test "should return phase colors when active" {
            Expect.equal (oodaPhaseColor Observe true) "#00BFFF" "Observe is blue"
            Expect.equal (oodaPhaseColor Act true) "#32CD32" "Act is green"
        }

        test "should detect meeting SC-OODA-001 target" {
            let fast = { CurrentPhase = Observe; CycleTime = TimeSpan.FromMilliseconds(50.0); CyclesCompleted = 10; IsActive = true }
            let slow = { CurrentPhase = Observe; CycleTime = TimeSpan.FromMilliseconds(150.0); CyclesCompleted = 10; IsActive = true }

            Expect.isTrue (oodaCycleMeetsTarget fast) "50ms meets target"
            Expect.isFalse (oodaCycleMeetsTarget slow) "150ms exceeds target"
        }
    ]

// ============================================================================
// Fitness Gauge Component Tests
// ============================================================================

type FitnessGaugeState = {
    Fitness: float
    Generation: int
    Label: string
}

let fitnessGaugeAngle (fitness: float) =
    // Maps 0-1 fitness to 0-180 degrees
    fitness * 180.0

let fitnessGaugeColor (fitness: float) =
    if fitness >= 0.8 then "#00FF00"
    elif fitness >= 0.5 then "#FFA500"
    else "#FF0000"

let fitnessGaugeClass (fitness: float) =
    if fitness >= 0.8 then "excellent"
    elif fitness >= 0.5 then "good"
    elif fitness >= 0.3 then "fair"
    else "poor"

[<Tests>]
let fitnessGaugeTests =
    testList "FitnessGauge" [
        test "should calculate correct angle" {
            Expect.equal (fitnessGaugeAngle 0.0) 0.0 "0 fitness = 0 degrees"
            Expect.equal (fitnessGaugeAngle 0.5) 90.0 "0.5 fitness = 90 degrees"
            Expect.equal (fitnessGaugeAngle 1.0) 180.0 "1.0 fitness = 180 degrees"
        }

        test "should return correct colors" {
            Expect.equal (fitnessGaugeColor 0.9) "#00FF00" "High fitness is green"
            Expect.equal (fitnessGaugeColor 0.6) "#FFA500" "Medium fitness is orange"
            Expect.equal (fitnessGaugeColor 0.3) "#FF0000" "Low fitness is red"
        }

        test "should have correct class" {
            Expect.equal (fitnessGaugeClass 0.9) "excellent" "0.9 is excellent"
            Expect.equal (fitnessGaugeClass 0.6) "good" "0.6 is good"
            Expect.equal (fitnessGaugeClass 0.4) "fair" "0.4 is fair"
            Expect.equal (fitnessGaugeClass 0.2) "poor" "0.2 is poor"
        }
    ]

// ============================================================================
// Alert Banner Component Tests
// ============================================================================

type AlertBannerLevel =
    | Information
    | Warning
    | Error
    | Success

type AlertBannerState = {
    Level: AlertBannerLevel
    Message: string
    Dismissable: bool
    AutoDismiss: TimeSpan option
}

let alertBannerIcon (level: AlertBannerLevel) =
    match level with
    | Information -> "info"
    | Warning -> "warning"
    | Error -> "error"
    | Success -> "check_circle"

let alertBannerColor (level: AlertBannerLevel) =
    match level with
    | Information -> "#2196F3"  // Blue
    | Warning -> "#FF9800"      // Orange
    | Error -> "#F44336"        // Red
    | Success -> "#4CAF50"      // Green

let alertBannerShouldAutoDismiss (state: AlertBannerState) =
    state.AutoDismiss.IsSome

[<Tests>]
let alertBannerTests =
    testList "AlertBanner" [
        test "should have correct icons" {
            Expect.equal (alertBannerIcon Information) "info" "Info icon"
            Expect.equal (alertBannerIcon Warning) "warning" "Warning icon"
            Expect.equal (alertBannerIcon Error) "error" "Error icon"
            Expect.equal (alertBannerIcon Success) "check_circle" "Success icon"
        }

        test "should have correct colors" {
            Expect.equal (alertBannerColor Information) "#2196F3" "Info is blue"
            Expect.equal (alertBannerColor Error) "#F44336" "Error is red"
        }

        test "should detect auto-dismiss" {
            let autoDismiss = { Level = Success; Message = "Done"; Dismissable = true; AutoDismiss = Some (TimeSpan.FromSeconds(5.0)) }
            let manual = { Level = Error; Message = "Error"; Dismissable = true; AutoDismiss = None }

            Expect.isTrue (alertBannerShouldAutoDismiss autoDismiss) "Has auto dismiss"
            Expect.isFalse (alertBannerShouldAutoDismiss manual) "No auto dismiss"
        }
    ]
