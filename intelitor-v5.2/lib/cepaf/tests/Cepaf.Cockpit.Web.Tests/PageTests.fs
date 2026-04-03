/// WebUI Page Tests
/// Tests for page rendering, navigation, and state management
module Cepaf.Cockpit.Web.Tests.PageTests

open System
open Expecto

// ============================================================================
// Page Type Definitions
// ============================================================================

type Page =
    | Dashboard
    | Alarms
    | Guardian
    | Sentinel
    | Devices
    | Settings

// ============================================================================
// Dashboard Page Tests
// ============================================================================

type DashboardState = {
    OverallHealth: float
    ConnectedNodes: int
    ActiveAlarms: int
    PendingProposals: int
    IsLoading: bool
    LastUpdate: DateTime option
}

let defaultDashboardState = {
    OverallHealth = 0.0
    ConnectedNodes = 0
    ActiveAlarms = 0
    PendingProposals = 0
    IsLoading = true
    LastUpdate = None
}

let dashboardIsStale (state: DashboardState) (threshold: TimeSpan) =
    match state.LastUpdate with
    | None -> true
    | Some lastUpdate -> DateTime.UtcNow - lastUpdate > threshold

let dashboardHealthClass (state: DashboardState) =
    if state.OverallHealth >= 90.0 then "health-excellent"
    elif state.OverallHealth >= 70.0 then "health-good"
    elif state.OverallHealth >= 50.0 then "health-fair"
    else "health-poor"

[<Tests>]
let dashboardPageTests =
    testList "DashboardPage" [
        test "should have default loading state" {
            let state = defaultDashboardState
            Expect.isTrue state.IsLoading "Should be loading initially"
            Expect.isNone state.LastUpdate "Should have no update time"
        }

        test "should detect stale data" {
            let state = {
                defaultDashboardState with
                    LastUpdate = Some (DateTime.UtcNow.AddMinutes(-5.0))
                    IsLoading = false
            }
            let isStale = dashboardIsStale state (TimeSpan.FromMinutes(1.0))
            Expect.isTrue isStale "Should be stale after 1 minute threshold"
        }

        test "should not be stale within threshold" {
            let state = {
                defaultDashboardState with
                    LastUpdate = Some DateTime.UtcNow
                    IsLoading = false
            }
            let isStale = dashboardIsStale state (TimeSpan.FromMinutes(1.0))
            Expect.isFalse isStale "Should not be stale"
        }

        test "should have correct health class" {
            let excellent = { defaultDashboardState with OverallHealth = 95.0 }
            let good = { defaultDashboardState with OverallHealth = 75.0 }
            let fair = { defaultDashboardState with OverallHealth = 55.0 }
            let poor = { defaultDashboardState with OverallHealth = 30.0 }

            Expect.equal (dashboardHealthClass excellent) "health-excellent" "95% is excellent"
            Expect.equal (dashboardHealthClass good) "health-good" "75% is good"
            Expect.equal (dashboardHealthClass fair) "health-fair" "55% is fair"
            Expect.equal (dashboardHealthClass poor) "health-poor" "30% is poor"
        }
    ]

// ============================================================================
// Alarms Page Tests
// ============================================================================

type AlarmLevel =
    | Info
    | Warning
    | Critical

type Alarm = {
    Id: string
    Level: AlarmLevel
    Message: string
    NodeId: string
    OccurredAt: DateTime
    AcknowledgedAt: DateTime option
}

type AlarmsPageState = {
    Alarms: Alarm list
    Filter: AlarmLevel option
    SearchQuery: string
    SelectedAlarmId: string option
    IsLoading: bool
}

let filterAlarms (state: AlarmsPageState) =
    let filtered =
        match state.Filter with
        | Some level -> state.Alarms |> List.filter (fun a -> a.Level = level)
        | None -> state.Alarms

    if String.IsNullOrWhiteSpace state.SearchQuery then
        filtered
    else
        let query = state.SearchQuery.ToLower()
        filtered |> List.filter (fun a ->
            a.Message.ToLower().Contains(query) ||
            a.NodeId.ToLower().Contains(query))

let criticalAlarmCount (state: AlarmsPageState) =
    state.Alarms |> List.filter (fun a -> a.Level = Critical) |> List.length

let unacknowledgedCount (state: AlarmsPageState) =
    state.Alarms |> List.filter (fun a -> a.AcknowledgedAt.IsNone) |> List.length

[<Tests>]
let alarmsPageTests =
    testList "AlarmsPage" [
        test "should filter alarms by level" {
            let alarms = [
                { Id = "1"; Level = Critical; Message = "Error"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
                { Id = "2"; Level = Warning; Message = "Warning"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
                { Id = "3"; Level = Info; Message = "Info"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            ]
            let state = { Alarms = alarms; Filter = Some Critical; SearchQuery = ""; SelectedAlarmId = None; IsLoading = false }
            let filtered = filterAlarms state
            Expect.equal filtered.Length 1 "Should have 1 critical alarm"
            Expect.equal filtered.[0].Level Critical "Should be critical"
        }

        test "should filter alarms by search query" {
            let alarms = [
                { Id = "1"; Level = Warning; Message = "CPU overload"; NodeId = "node-1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
                { Id = "2"; Level = Warning; Message = "Memory high"; NodeId = "node-2"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            ]
            let state = { Alarms = alarms; Filter = None; SearchQuery = "CPU"; SelectedAlarmId = None; IsLoading = false }
            let filtered = filterAlarms state
            Expect.equal filtered.Length 1 "Should find 1 alarm with CPU"
        }

        test "should count critical alarms" {
            let alarms = [
                { Id = "1"; Level = Critical; Message = "Error 1"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
                { Id = "2"; Level = Critical; Message = "Error 2"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
                { Id = "3"; Level = Warning; Message = "Warning"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            ]
            let state = { Alarms = alarms; Filter = None; SearchQuery = ""; SelectedAlarmId = None; IsLoading = false }
            Expect.equal (criticalAlarmCount state) 2 "Should have 2 critical alarms"
        }

        test "should count unacknowledged alarms" {
            let alarms = [
                { Id = "1"; Level = Warning; Message = "W1"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
                { Id = "2"; Level = Warning; Message = "W2"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = Some DateTime.UtcNow }
                { Id = "3"; Level = Info; Message = "I1"; NodeId = "n1"; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            ]
            let state = { Alarms = alarms; Filter = None; SearchQuery = ""; SelectedAlarmId = None; IsLoading = false }
            Expect.equal (unacknowledgedCount state) 2 "Should have 2 unacknowledged"
        }
    ]

// ============================================================================
// Guardian Page Tests
// ============================================================================

type ProposalSeverity =
    | Low
    | Medium
    | High
    | Critical

type Proposal = {
    Id: string
    Title: string
    Description: string
    Category: string
    Severity: ProposalSeverity
    Votes: int
    RequiredVotes: int
    CreatedAt: DateTime
}

type GuardianPageState = {
    Proposals: Proposal list
    SelectedProposalId: string option
    IsLoading: bool
}

let pendingProposals (state: GuardianPageState) =
    state.Proposals |> List.filter (fun p -> p.Votes < p.RequiredVotes)

let approvedProposals (state: GuardianPageState) =
    state.Proposals |> List.filter (fun p -> p.Votes >= p.RequiredVotes)

[<Tests>]
let guardianPageTests =
    testList "GuardianPage" [
        test "should list pending proposals" {
            let proposals = [
                { Id = "1"; Title = "P1"; Description = ""; Category = ""; Severity = Medium; Votes = 1; RequiredVotes = 3; CreatedAt = DateTime.UtcNow }
                { Id = "2"; Title = "P2"; Description = ""; Category = ""; Severity = Low; Votes = 3; RequiredVotes = 3; CreatedAt = DateTime.UtcNow }
            ]
            let state = { Proposals = proposals; SelectedProposalId = None; IsLoading = false }
            Expect.equal (pendingProposals state).Length 1 "Should have 1 pending"
        }

        test "should list approved proposals" {
            let proposals = [
                { Id = "1"; Title = "P1"; Description = ""; Category = ""; Severity = Medium; Votes = 3; RequiredVotes = 3; CreatedAt = DateTime.UtcNow }
                { Id = "2"; Title = "P2"; Description = ""; Category = ""; Severity = Low; Votes = 4; RequiredVotes = 3; CreatedAt = DateTime.UtcNow }
            ]
            let state = { Proposals = proposals; SelectedProposalId = None; IsLoading = false }
            Expect.equal (approvedProposals state).Length 2 "Should have 2 approved"
        }
    ]

// ============================================================================
// Sentinel Page Tests
// ============================================================================

type ThreatSeverity =
    | Low
    | Medium
    | High
    | Critical

type Threat = {
    Id: string
    Category: string
    Description: string
    Source: string
    Severity: ThreatSeverity
    Mitigated: bool
    DetectedAt: DateTime
}

type SentinelPageState = {
    Threats: Threat list
    Filter: ThreatSeverity option
    ShowMitigated: bool
    IsLoading: bool
}

let filterThreats (state: SentinelPageState) =
    let filtered =
        match state.Filter with
        | Some sev -> state.Threats |> List.filter (fun t -> t.Severity = sev)
        | None -> state.Threats

    if state.ShowMitigated then
        filtered
    else
        filtered |> List.filter (fun t -> not t.Mitigated)

let activeThreats (state: SentinelPageState) =
    state.Threats |> List.filter (fun t -> not t.Mitigated)

[<Tests>]
let sentinelPageTests =
    testList "SentinelPage" [
        test "should filter by severity" {
            let threats = [
                { Id = "1"; Category = ""; Description = ""; Source = ""; Severity = Critical; Mitigated = false; DetectedAt = DateTime.UtcNow }
                { Id = "2"; Category = ""; Description = ""; Source = ""; Severity = Low; Mitigated = false; DetectedAt = DateTime.UtcNow }
            ]
            let state = { Threats = threats; Filter = Some Critical; ShowMitigated = true; IsLoading = false }
            Expect.equal (filterThreats state).Length 1 "Should have 1 critical"
        }

        test "should hide mitigated threats by default" {
            let threats = [
                { Id = "1"; Category = ""; Description = ""; Source = ""; Severity = High; Mitigated = true; DetectedAt = DateTime.UtcNow }
                { Id = "2"; Category = ""; Description = ""; Source = ""; Severity = High; Mitigated = false; DetectedAt = DateTime.UtcNow }
            ]
            let state = { Threats = threats; Filter = None; ShowMitigated = false; IsLoading = false }
            Expect.equal (filterThreats state).Length 1 "Should hide mitigated"
        }

        test "should count active threats" {
            let threats = [
                { Id = "1"; Category = ""; Description = ""; Source = ""; Severity = High; Mitigated = false; DetectedAt = DateTime.UtcNow }
                { Id = "2"; Category = ""; Description = ""; Source = ""; Severity = Medium; Mitigated = true; DetectedAt = DateTime.UtcNow }
                { Id = "3"; Category = ""; Description = ""; Source = ""; Severity = Low; Mitigated = false; DetectedAt = DateTime.UtcNow }
            ]
            let state = { Threats = threats; Filter = None; ShowMitigated = true; IsLoading = false }
            Expect.equal (activeThreats state).Length 2 "Should have 2 active"
        }
    ]

// ============================================================================
// Navigation Tests
// ============================================================================

let pageToRoute (page: Page) =
    match page with
    | Dashboard -> "/"
    | Alarms -> "/alarms"
    | Guardian -> "/guardian"
    | Sentinel -> "/sentinel"
    | Devices -> "/devices"
    | Settings -> "/settings"

let routeToPage (route: string) =
    match route.ToLower() with
    | "/" | "" -> Some Dashboard
    | "/alarms" -> Some Alarms
    | "/guardian" -> Some Guardian
    | "/sentinel" -> Some Sentinel
    | "/devices" -> Some Devices
    | "/settings" -> Some Settings
    | _ -> None

[<Tests>]
let navigationTests =
    testList "Navigation" [
        test "should convert page to route" {
            Expect.equal (pageToRoute Dashboard) "/" "Dashboard route"
            Expect.equal (pageToRoute Alarms) "/alarms" "Alarms route"
            Expect.equal (pageToRoute Guardian) "/guardian" "Guardian route"
        }

        test "should convert route to page" {
            Expect.equal (routeToPage "/") (Some Dashboard) "Root is Dashboard"
            Expect.equal (routeToPage "/alarms") (Some Alarms) "Alarms route"
            Expect.equal (routeToPage "/unknown") None "Unknown route"
        }

        test "should handle case insensitive routes" {
            Expect.equal (routeToPage "/ALARMS") (Some Alarms) "Case insensitive"
            Expect.equal (routeToPage "/Guardian") (Some Guardian) "Mixed case"
        }
    ]

// ============================================================================
// Settings Page Tests
// ============================================================================

type Theme = Dark | Light | Aerospace

type SettingsState = {
    DarkCockpitEnabled: bool
    Theme: Theme
    RefreshRateMs: int
    SoundEnabled: bool
}

let defaultSettings = {
    DarkCockpitEnabled = true
    Theme = Dark
    RefreshRateMs = 5000
    SoundEnabled = true
}

let validateRefreshRate (rate: int) =
    rate >= 1000 && rate <= 60000

[<Tests>]
let settingsPageTests =
    testList "SettingsPage" [
        test "should have sensible defaults" {
            let settings = defaultSettings
            Expect.isTrue settings.DarkCockpitEnabled "Dark cockpit default"
            Expect.equal settings.Theme Dark "Dark theme default"
            Expect.equal settings.RefreshRateMs 5000 "5s refresh default"
        }

        test "should validate refresh rate bounds" {
            Expect.isTrue (validateRefreshRate 1000) "1s is valid"
            Expect.isTrue (validateRefreshRate 60000) "60s is valid"
            Expect.isFalse (validateRefreshRate 500) "500ms is too fast"
            Expect.isFalse (validateRefreshRate 120000) "120s is too slow"
        }
    ]
