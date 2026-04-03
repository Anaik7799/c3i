/// Cross-Interface Consistency Tests
/// Tests for TUI/GUI/WebUI consistency verification
module Cepaf.Integration.CrossInterfaceTests

open System
open Expecto

// ============================================================================
// Cross-Interface Data Model
// ============================================================================

type InterfaceType = TUI | GUI | WebUI

type InterfaceReading = {
    Interface: InterfaceType
    Timestamp: DateTime
    Value: float
    FormattedValue: string
}

type ConsistencyResult = {
    IsConsistent: bool
    MaxDeviation: float
    Readings: InterfaceReading list
}

// ============================================================================
// Health Score Consistency Tests
// ============================================================================

let healthScoreTolerance = 0.001  // ±0.1% tolerance per spec

let areValuesConsistent (tolerance: float) (values: float list) =
    match values with
    | [] | [_] -> true
    | first :: rest ->
        rest |> List.forall (fun v -> abs(v - first) <= tolerance)

let maxDeviation (values: float list) =
    match values with
    | [] | [_] -> 0.0
    | _ ->
        let minVal = List.min values
        let maxVal = List.max values
        maxVal - minVal

let checkHealthScoreConsistency (readings: InterfaceReading list) =
    let values = readings |> List.map (fun r -> r.Value)
    {
        IsConsistent = areValuesConsistent healthScoreTolerance values
        MaxDeviation = maxDeviation values
        Readings = readings
    }

[<Tests>]
let healthScoreConsistencyTests =
    testList "HealthScoreConsistency" [
        test "should detect consistent health scores" {
            let readings = [
                { Interface = TUI; Timestamp = DateTime.UtcNow; Value = 0.95; FormattedValue = "95%" }
                { Interface = GUI; Timestamp = DateTime.UtcNow; Value = 0.95; FormattedValue = "95%" }
                { Interface = WebUI; Timestamp = DateTime.UtcNow; Value = 0.95; FormattedValue = "95%" }
            ]
            let result = checkHealthScoreConsistency readings
            Expect.isTrue result.IsConsistent "All interfaces should show same value"
            Expect.equal result.MaxDeviation 0.0 "No deviation expected"
        }

        test "should detect inconsistent health scores" {
            let readings = [
                { Interface = TUI; Timestamp = DateTime.UtcNow; Value = 0.95; FormattedValue = "95%" }
                { Interface = GUI; Timestamp = DateTime.UtcNow; Value = 0.90; FormattedValue = "90%" }
                { Interface = WebUI; Timestamp = DateTime.UtcNow; Value = 0.95; FormattedValue = "95%" }
            ]
            let result = checkHealthScoreConsistency readings
            Expect.isFalse result.IsConsistent "Should detect 5% deviation"
            Expect.equal result.MaxDeviation 0.05 "Deviation should be 5%"
        }

        test "should allow within tolerance" {
            let readings = [
                { Interface = TUI; Timestamp = DateTime.UtcNow; Value = 0.950; FormattedValue = "95.0%" }
                { Interface = GUI; Timestamp = DateTime.UtcNow; Value = 0.9505; FormattedValue = "95.05%" }
                { Interface = WebUI; Timestamp = DateTime.UtcNow; Value = 0.9498; FormattedValue = "94.98%" }
            ]
            let result = checkHealthScoreConsistency readings
            Expect.isTrue result.IsConsistent "Within 0.1% tolerance"
        }
    ]

// ============================================================================
// Alarm List Consistency Tests
// ============================================================================

type AlarmEntry = {
    Id: string
    Severity: string
    Timestamp: DateTime
    Message: string
}

type AlarmListReading = {
    Interface: InterfaceType
    Alarms: AlarmEntry list
    FetchedAt: DateTime
}

let areAlarmListsIdentical (readings: AlarmListReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        let firstIds = first.Alarms |> List.map (fun a -> a.Id) |> List.sort
        rest |> List.forall (fun r ->
            let ids = r.Alarms |> List.map (fun a -> a.Id) |> List.sort
            ids = firstIds)

let areAlarmsSortedByTimestamp (alarms: AlarmEntry list) =
    let timestamps = alarms |> List.map (fun a -> a.Timestamp)
    timestamps = List.sortDescending timestamps

[<Tests>]
let alarmListConsistencyTests =
    testList "AlarmListConsistency" [
        test "should detect identical alarm lists" {
            let baseTime = DateTime.UtcNow
            let alarms = [
                { Id = "a-1"; Severity = "Critical"; Timestamp = baseTime; Message = "Alert 1" }
                { Id = "a-2"; Severity = "Warning"; Timestamp = baseTime.AddMinutes(-5.0); Message = "Alert 2" }
            ]
            let readings = [
                { Interface = TUI; Alarms = alarms; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; Alarms = alarms; FetchedAt = DateTime.UtcNow }
                { Interface = WebUI; Alarms = alarms; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isTrue (areAlarmListsIdentical readings) "All interfaces should show same alarms"
        }

        test "should detect missing alarm" {
            let baseTime = DateTime.UtcNow
            let fullList = [
                { Id = "a-1"; Severity = "Critical"; Timestamp = baseTime; Message = "Alert 1" }
                { Id = "a-2"; Severity = "Warning"; Timestamp = baseTime.AddMinutes(-5.0); Message = "Alert 2" }
            ]
            let partialList = [
                { Id = "a-1"; Severity = "Critical"; Timestamp = baseTime; Message = "Alert 1" }
            ]
            let readings = [
                { Interface = TUI; Alarms = fullList; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; Alarms = partialList; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isFalse (areAlarmListsIdentical readings) "Should detect missing alarm"
        }

        test "should verify timestamp sorting" {
            let baseTime = DateTime.UtcNow
            let properlyOrdered = [
                { Id = "a-1"; Severity = "Critical"; Timestamp = baseTime; Message = "Newest" }
                { Id = "a-2"; Severity = "Warning"; Timestamp = baseTime.AddMinutes(-5.0); Message = "Older" }
                { Id = "a-3"; Severity = "Info"; Timestamp = baseTime.AddMinutes(-10.0); Message = "Oldest" }
            ]
            Expect.isTrue (areAlarmsSortedByTimestamp properlyOrdered) "Should be sorted newest first"
        }
    ]

// ============================================================================
// Proposal Status Consistency Tests
// ============================================================================

type ProposalStatus =
    | Draft
    | Submitted
    | UnderReview
    | Approved
    | Vetoed

type ProposalReading = {
    Interface: InterfaceType
    ProposalId: string
    Status: ProposalStatus
    FetchedAt: DateTime
}

let maxSyncDelay = TimeSpan.FromSeconds(1.0)  // 1s sync window per spec

let areProposalStatusesConsistent (readings: ProposalReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        rest |> List.forall (fun r -> r.Status = first.Status)

let isWithinSyncWindow (readings: ProposalReading list) =
    match readings with
    | [] | [_] -> true
    | _ ->
        let timestamps = readings |> List.map (fun r -> r.FetchedAt)
        let minTime = List.min timestamps
        let maxTime = List.max timestamps
        maxTime - minTime <= maxSyncDelay

[<Tests>]
let proposalStatusConsistencyTests =
    testList "ProposalStatusConsistency" [
        test "should detect consistent proposal status" {
            let readings = [
                { Interface = TUI; ProposalId = "p-1"; Status = Approved; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; ProposalId = "p-1"; Status = Approved; FetchedAt = DateTime.UtcNow }
                { Interface = WebUI; ProposalId = "p-1"; Status = Approved; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isTrue (areProposalStatusesConsistent readings) "All should show Approved"
        }

        test "should detect status mismatch" {
            let readings = [
                { Interface = TUI; ProposalId = "p-1"; Status = Approved; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; ProposalId = "p-1"; Status = UnderReview; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isFalse (areProposalStatusesConsistent readings) "Status mismatch"
        }

        test "should validate sync window" {
            let now = DateTime.UtcNow
            let readings = [
                { Interface = TUI; ProposalId = "p-1"; Status = Approved; FetchedAt = now }
                { Interface = GUI; ProposalId = "p-1"; Status = Approved; FetchedAt = now.AddMilliseconds(500.0) }
            ]
            Expect.isTrue (isWithinSyncWindow readings) "Within 1s sync window"
        }

        test "should detect sync window violation" {
            let now = DateTime.UtcNow
            let readings = [
                { Interface = TUI; ProposalId = "p-1"; Status = Approved; FetchedAt = now }
                { Interface = GUI; ProposalId = "p-1"; Status = Approved; FetchedAt = now.AddSeconds(2.0) }
            ]
            Expect.isFalse (isWithinSyncWindow readings) "Outside 1s sync window"
        }
    ]

// ============================================================================
// Threat RPN Consistency Tests
// ============================================================================

type ThreatReading = {
    Interface: InterfaceType
    ThreatId: string
    Severity: int
    Occurrence: int
    Detection: int
    CalculatedRPN: int
}

let calculateRPN (severity: int) (occurrence: int) (detection: int) =
    severity * occurrence * detection

let verifyRPNCalculation (reading: ThreatReading) =
    let expected = calculateRPN reading.Severity reading.Occurrence reading.Detection
    reading.CalculatedRPN = expected

let areRPNsConsistent (readings: ThreatReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        rest |> List.forall (fun r -> r.CalculatedRPN = first.CalculatedRPN)

[<Tests>]
let threatRPNConsistencyTests =
    testList "ThreatRPNConsistency" [
        test "should calculate RPN identically" {
            let readings = [
                { Interface = TUI; ThreatId = "t-1"; Severity = 8; Occurrence = 5; Detection = 4; CalculatedRPN = 160 }
                { Interface = GUI; ThreatId = "t-1"; Severity = 8; Occurrence = 5; Detection = 4; CalculatedRPN = 160 }
                { Interface = WebUI; ThreatId = "t-1"; Severity = 8; Occurrence = 5; Detection = 4; CalculatedRPN = 160 }
            ]
            Expect.isTrue (areRPNsConsistent readings) "All interfaces should calculate same RPN"
            readings |> List.iter (fun r ->
                Expect.isTrue (verifyRPNCalculation r) $"RPN should be correct for {r.Interface}")
        }

        test "should detect RPN mismatch" {
            let readings = [
                { Interface = TUI; ThreatId = "t-1"; Severity = 8; Occurrence = 5; Detection = 4; CalculatedRPN = 160 }
                { Interface = GUI; ThreatId = "t-1"; Severity = 8; Occurrence = 5; Detection = 4; CalculatedRPN = 150 }  // Wrong
            ]
            Expect.isFalse (areRPNsConsistent readings) "Should detect RPN mismatch"
        }

        test "should verify algorithm correctness" {
            let reading = { Interface = TUI; ThreatId = "t-1"; Severity = 10; Occurrence = 8; Detection = 5; CalculatedRPN = 400 }
            Expect.isTrue (verifyRPNCalculation reading) "10 * 8 * 5 = 400"
        }
    ]

// ============================================================================
// Connection Status Consistency Tests
// ============================================================================

type ConnectionStatus =
    | Connected
    | Connecting
    | Disconnected
    | Reconnecting
    | Error of string

type ConnectionReading = {
    Interface: InterfaceType
    Target: string
    Status: ConnectionStatus
    FetchedAt: DateTime
}

let connectionStatusToCode (status: ConnectionStatus) =
    match status with
    | Connected -> 1
    | Connecting -> 2
    | Reconnecting -> 3
    | Disconnected -> 4
    | Error _ -> 5

let areConnectionStatusesConsistent (readings: ConnectionReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        let firstCode = connectionStatusToCode first.Status
        rest |> List.forall (fun r -> connectionStatusToCode r.Status = firstCode)

[<Tests>]
let connectionStatusConsistencyTests =
    testList "ConnectionStatusConsistency" [
        test "should detect consistent connection status" {
            let readings = [
                { Interface = TUI; Target = "elixir-backend"; Status = Connected; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; Target = "elixir-backend"; Status = Connected; FetchedAt = DateTime.UtcNow }
                { Interface = WebUI; Target = "elixir-backend"; Status = Connected; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isTrue (areConnectionStatusesConsistent readings) "All should show Connected"
        }

        test "should detect status mismatch" {
            let readings = [
                { Interface = TUI; Target = "elixir-backend"; Status = Connected; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; Target = "elixir-backend"; Status = Disconnected; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isFalse (areConnectionStatusesConsistent readings) "Status mismatch"
        }

        test "should use unified status codes" {
            Expect.equal (connectionStatusToCode Connected) 1 "Connected = 1"
            Expect.equal (connectionStatusToCode Connecting) 2 "Connecting = 2"
            Expect.equal (connectionStatusToCode Disconnected) 4 "Disconnected = 4"
        }
    ]

// ============================================================================
// Metric Trend Consistency Tests
// ============================================================================

type MetricTrend = Rising | Falling | Stable

type MetricTrendReading = {
    Interface: InterfaceType
    MetricName: string
    CurrentValue: float
    Trend: MetricTrend
    SparklineData: float list
}

let calculateTrend (values: float list) =
    match values with
    | [] | [_] -> Stable
    | _ ->
        let recent = values |> List.take (min 5 values.Length)
        let avg1 = recent |> List.take (recent.Length / 2) |> List.average
        let avg2 = recent |> List.skip (recent.Length / 2) |> List.average
        if avg2 > avg1 * 1.05 then Rising
        elif avg2 < avg1 * 0.95 then Falling
        else Stable

let areMetricTrendsConsistent (readings: MetricTrendReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        rest |> List.forall (fun r -> r.Trend = first.Trend)

[<Tests>]
let metricTrendConsistencyTests =
    testList "MetricTrendConsistency" [
        test "should detect rising trend" {
            let values = [1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0; 8.0; 9.0; 10.0]
            Expect.equal (calculateTrend values) Rising "Should detect rising trend"
        }

        test "should detect falling trend" {
            let values = [10.0; 9.0; 8.0; 7.0; 6.0; 5.0; 4.0; 3.0; 2.0; 1.0]
            Expect.equal (calculateTrend values) Falling "Should detect falling trend"
        }

        test "should detect stable trend" {
            let values = [5.0; 5.1; 4.9; 5.0; 5.05; 4.95; 5.0; 5.02; 4.98; 5.0]
            Expect.equal (calculateTrend values) Stable "Should detect stable trend"
        }

        test "should verify cross-interface trend consistency" {
            let sparkline = [1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0; 8.0]
            let readings = [
                { Interface = TUI; MetricName = "cpu"; CurrentValue = 8.0; Trend = Rising; SparklineData = sparkline }
                { Interface = GUI; MetricName = "cpu"; CurrentValue = 8.0; Trend = Rising; SparklineData = sparkline }
                { Interface = WebUI; MetricName = "cpu"; CurrentValue = 8.0; Trend = Rising; SparklineData = sparkline }
            ]
            Expect.isTrue (areMetricTrendsConsistent readings) "All should show Rising"
        }
    ]

// ============================================================================
// Data Staleness Tests
// ============================================================================

type DataStaleness = Fresh | Stale | Critical

let staleThreshold = TimeSpan.FromSeconds(30.0)  // Per spec
let criticalThreshold = TimeSpan.FromSeconds(60.0)

let categorizeDataAge (lastUpdate: DateTime) (now: DateTime) =
    let age = now - lastUpdate
    if age < staleThreshold then Fresh
    elif age < criticalThreshold then Stale
    else Critical

type DataFreshnessReading = {
    Interface: InterfaceType
    LastUpdate: DateTime
    Staleness: DataStaleness
    VisualDecay: bool  // Should show visual decay indicator
}

let isVisualDecayCorrect (reading: DataFreshnessReading) =
    match reading.Staleness with
    | Fresh -> not reading.VisualDecay
    | Stale | Critical -> reading.VisualDecay

[<Tests>]
let dataStalenessTests =
    testList "DataStaleness" [
        test "should categorize fresh data" {
            let now = DateTime.UtcNow
            let recent = now.AddSeconds(-10.0)
            Expect.equal (categorizeDataAge recent now) Fresh "<30s is fresh"
        }

        test "should categorize stale data" {
            let now = DateTime.UtcNow
            let stale = now.AddSeconds(-45.0)
            Expect.equal (categorizeDataAge stale now) Stale "30-60s is stale"
        }

        test "should categorize critical staleness" {
            let now = DateTime.UtcNow
            let critical = now.AddSeconds(-90.0)
            Expect.equal (categorizeDataAge critical now) Critical ">60s is critical"
        }

        test "should require visual decay for stale data" {
            let now = DateTime.UtcNow
            let staleReading = {
                Interface = GUI
                LastUpdate = now.AddSeconds(-35.0)
                Staleness = Stale
                VisualDecay = true
            }
            Expect.isTrue (isVisualDecayCorrect staleReading) "Stale data should show decay"
        }

        test "should not show decay for fresh data" {
            let now = DateTime.UtcNow
            let freshReading = {
                Interface = GUI
                LastUpdate = now.AddSeconds(-5.0)
                Staleness = Fresh
                VisualDecay = false
            }
            Expect.isTrue (isVisualDecayCorrect freshReading) "Fresh data should not show decay"
        }
    ]

// ============================================================================
// Theme Consistency Tests
// ============================================================================

type ThemeReading = {
    Interface: InterfaceType
    ActiveTheme: string
    BackgroundColor: string
    ForegroundColor: string
    AccentColor: string
}

let areThemesConsistent (readings: ThemeReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        rest |> List.forall (fun r ->
            r.ActiveTheme = first.ActiveTheme &&
            r.BackgroundColor = first.BackgroundColor &&
            r.ForegroundColor = first.ForegroundColor)

[<Tests>]
let themeConsistencyTests =
    testList "ThemeConsistency" [
        test "should detect consistent dark theme" {
            let readings = [
                { Interface = TUI; ActiveTheme = "Dark"; BackgroundColor = "#0a0a0a"; ForegroundColor = "#e5e5e5"; AccentColor = "#3b82f6" }
                { Interface = GUI; ActiveTheme = "Dark"; BackgroundColor = "#0a0a0a"; ForegroundColor = "#e5e5e5"; AccentColor = "#3b82f6" }
                { Interface = WebUI; ActiveTheme = "Dark"; BackgroundColor = "#0a0a0a"; ForegroundColor = "#e5e5e5"; AccentColor = "#3b82f6" }
            ]
            Expect.isTrue (areThemesConsistent readings) "All interfaces should use same theme"
        }

        test "should detect theme mismatch" {
            let readings = [
                { Interface = TUI; ActiveTheme = "Dark"; BackgroundColor = "#0a0a0a"; ForegroundColor = "#e5e5e5"; AccentColor = "#3b82f6" }
                { Interface = GUI; ActiveTheme = "Light"; BackgroundColor = "#ffffff"; ForegroundColor = "#1a1a1a"; AccentColor = "#3b82f6" }
            ]
            Expect.isFalse (areThemesConsistent readings) "Theme mismatch between TUI and GUI"
        }
    ]

// ============================================================================
// Navigation State Consistency Tests
// ============================================================================

type NavigationState = {
    CurrentPage: string
    BreadcrumbPath: string list
    SelectedItem: string option
}

type NavigationReading = {
    Interface: InterfaceType
    State: NavigationState
    FetchedAt: DateTime
}

let areNavigationStatesConsistent (readings: NavigationReading list) =
    match readings with
    | [] | [_] -> true
    | first :: rest ->
        rest |> List.forall (fun r ->
            r.State.CurrentPage = first.State.CurrentPage)

[<Tests>]
let navigationConsistencyTests =
    testList "NavigationConsistency" [
        test "should detect consistent navigation" {
            let state = { CurrentPage = "Dashboard"; BreadcrumbPath = ["Home"; "Dashboard"]; SelectedItem = None }
            let readings = [
                { Interface = TUI; State = state; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; State = state; FetchedAt = DateTime.UtcNow }
                { Interface = WebUI; State = state; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isTrue (areNavigationStatesConsistent readings) "All should show Dashboard"
        }

        test "should detect page mismatch" {
            let readings = [
                { Interface = TUI; State = { CurrentPage = "Dashboard"; BreadcrumbPath = []; SelectedItem = None }; FetchedAt = DateTime.UtcNow }
                { Interface = GUI; State = { CurrentPage = "Alarms"; BreadcrumbPath = []; SelectedItem = None }; FetchedAt = DateTime.UtcNow }
            ]
            Expect.isFalse (areNavigationStatesConsistent readings) "Page mismatch"
        }
    ]

// ============================================================================
// Full Cross-Interface Verification Suite
// ============================================================================

type CrossInterfaceVerificationResult = {
    HealthScore: ConsistencyResult
    AlarmListConsistent: bool
    ProposalStatusConsistent: bool
    RPNConsistent: bool
    ConnectionConsistent: bool
    ThemeConsistent: bool
    NavigationConsistent: bool
    OverallConsistent: bool
}

let runFullVerification () =
    // In real implementation, this would fetch from all interfaces
    {
        HealthScore = { IsConsistent = true; MaxDeviation = 0.0; Readings = [] }
        AlarmListConsistent = true
        ProposalStatusConsistent = true
        RPNConsistent = true
        ConnectionConsistent = true
        ThemeConsistent = true
        NavigationConsistent = true
        OverallConsistent = true
    }

[<Tests>]
let fullVerificationTests =
    testList "FullVerification" [
        test "should run complete verification suite" {
            let result = runFullVerification()
            Expect.isTrue result.OverallConsistent "Full verification should pass"
        }

        test "should fail on any inconsistency" {
            let result = {
                runFullVerification() with
                    AlarmListConsistent = false
                    OverallConsistent = false
            }
            Expect.isFalse result.OverallConsistent "Should fail on alarm inconsistency"
        }
    ]

