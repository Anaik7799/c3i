/// Avalonia GUI Domain Tests
/// Tests for domain models, types, and messages
module Cepaf.Cockpit.Avalonia.Tests.DomainTests

open System
open Expecto

// ============================================================================
// Type Definitions (Mirrors Domain/Types.fs)
// ============================================================================

type ConnectionStatus =
    | Connected
    | Connecting
    | Disconnected
    | Error of string

type Page =
    | Dashboard
    | Alarms
    | Guardian
    | Sentinel
    | Devices
    | Video
    | Analytics
    | Compliance
    | AccessControl
    | Settings
    | TestEvolution
    | Copilot
    | Register

type AlarmSeverity = Info | Warning | Critical

type ThreatLevel = Low | Medium | High | Critical

type ProposalStatus =
    | Pending
    | Approved
    | Vetoed
    | Expired

// ============================================================================
// Model State Tests
// ============================================================================

type ModelState = {
    CurrentPage: Page
    ConnectionStatus: ConnectionStatus
    HealthScore: float
    AlarmCount: int
    ThreatCount: int
    PendingProposals: int
    IsLoading: bool
}

let defaultState = {
    CurrentPage = Dashboard
    ConnectionStatus = Disconnected
    HealthScore = 0.0
    AlarmCount = 0
    ThreatCount = 0
    PendingProposals = 0
    IsLoading = true
}

let isConnected state =
    match state.ConnectionStatus with
    | Connected -> true
    | _ -> false

let hasAlerts state =
    state.AlarmCount > 0 || state.ThreatCount > 0

let needsAttention state =
    state.HealthScore < 70.0 ||
    state.AlarmCount > 5 ||
    state.ThreatCount > 0 ||
    state.PendingProposals > 3

[<Tests>]
let modelStateTests =
    testList "ModelState" [
        test "should have default loading state" {
            let state = defaultState
            Expect.isTrue state.IsLoading "Should be loading initially"
            Expect.equal state.CurrentPage Dashboard "Should start on Dashboard"
        }

        test "should detect connected status" {
            let state = { defaultState with ConnectionStatus = Connected }
            Expect.isTrue (isConnected state) "Should be connected"
        }

        test "should detect disconnected status" {
            let state = { defaultState with ConnectionStatus = Disconnected }
            Expect.isFalse (isConnected state) "Should not be connected"
        }

        test "should detect alerts" {
            let state = { defaultState with AlarmCount = 5 }
            Expect.isTrue (hasAlerts state) "Should have alerts"
        }

        test "should detect needs attention" {
            let state = { defaultState with HealthScore = 50.0 }
            Expect.isTrue (needsAttention state) "Low health needs attention"

            let stateAlarms = { defaultState with AlarmCount = 10 }
            Expect.isTrue (needsAttention stateAlarms) "Many alarms need attention"
        }
    ]

// ============================================================================
// Message Tests
// ============================================================================

type Message =
    | Navigate of Page
    | SetConnectionStatus of ConnectionStatus
    | UpdateHealth of float
    | UpdateAlarmCount of int
    | UpdateThreatCount of int
    | UpdateProposalCount of int
    | SetLoading of bool
    | Refresh
    | ApproveProposal of string * string
    | VetoProposal of string * string
    | AcknowledgeAlarm of string
    | MitigateThreat of string

let messageCategory (msg: Message) =
    match msg with
    | Navigate _ -> "Navigation"
    | SetConnectionStatus _ -> "Connection"
    | UpdateHealth _ | UpdateAlarmCount _ | UpdateThreatCount _ | UpdateProposalCount _ -> "Metrics"
    | SetLoading _ | Refresh -> "Loading"
    | ApproveProposal _ | VetoProposal _ -> "Guardian"
    | AcknowledgeAlarm _ -> "Alarms"
    | MitigateThreat _ -> "Sentinel"

let messageRequiresBackend (msg: Message) =
    match msg with
    | ApproveProposal _ | VetoProposal _ | AcknowledgeAlarm _ | MitigateThreat _ -> true
    | Refresh -> true
    | _ -> false

[<Tests>]
let messageTests =
    testList "Message" [
        test "should categorize navigation messages" {
            let msg = Navigate Dashboard
            Expect.equal (messageCategory msg) "Navigation" "Should be Navigation"
        }

        test "should categorize metrics messages" {
            let msg = UpdateHealth 95.0
            Expect.equal (messageCategory msg) "Metrics" "Should be Metrics"
        }

        test "should identify backend-requiring messages" {
            Expect.isTrue (messageRequiresBackend (ApproveProposal ("p-1", "LGTM"))) "Approve requires backend"
            Expect.isTrue (messageRequiresBackend (VetoProposal ("p-2", "Risk"))) "Veto requires backend"
            Expect.isTrue (messageRequiresBackend (AcknowledgeAlarm "a-1")) "Ack requires backend"
            Expect.isTrue (messageRequiresBackend (MitigateThreat "t-1")) "Mitigate requires backend"
        }

        test "should identify non-backend messages" {
            Expect.isFalse (messageRequiresBackend (Navigate Dashboard)) "Navigate is local"
            Expect.isFalse (messageRequiresBackend (SetLoading true)) "SetLoading is local"
        }
    ]

// ============================================================================
// Update Function Tests
// ============================================================================

let update (msg: Message) (state: ModelState) =
    match msg with
    | Navigate page -> { state with CurrentPage = page }
    | SetConnectionStatus status -> { state with ConnectionStatus = status }
    | UpdateHealth score -> { state with HealthScore = score }
    | UpdateAlarmCount count -> { state with AlarmCount = count }
    | UpdateThreatCount count -> { state with ThreatCount = count }
    | UpdateProposalCount count -> { state with PendingProposals = count }
    | SetLoading loading -> { state with IsLoading = loading }
    | Refresh -> { state with IsLoading = true }
    | ApproveProposal _ | VetoProposal _ | AcknowledgeAlarm _ | MitigateThreat _ -> state

[<Tests>]
let updateTests =
    testList "Update" [
        test "should navigate to page" {
            let state = update (Navigate Alarms) defaultState
            Expect.equal state.CurrentPage Alarms "Should be on Alarms"
        }

        test "should update connection status" {
            let state = update (SetConnectionStatus Connected) defaultState
            Expect.equal state.ConnectionStatus Connected "Should be Connected"
        }

        test "should update health score" {
            let state = update (UpdateHealth 95.0) defaultState
            Expect.equal state.HealthScore 95.0 "Should have 95% health"
        }

        test "should set loading on refresh" {
            let state = { defaultState with IsLoading = false }
            let newState = update Refresh state
            Expect.isTrue newState.IsLoading "Should be loading after refresh"
        }

        test "should preserve state for backend operations" {
            let state = { defaultState with AlarmCount = 5 }
            let newState = update (AcknowledgeAlarm "a-1") state
            Expect.equal newState.AlarmCount 5 "Alarm count unchanged until backend responds"
        }
    ]

// ============================================================================
// Page Routing Tests
// ============================================================================

let pageToPath (page: Page) =
    match page with
    | Dashboard -> "/"
    | Alarms -> "/alarms"
    | Guardian -> "/guardian"
    | Sentinel -> "/sentinel"
    | Devices -> "/devices"
    | Video -> "/video"
    | Analytics -> "/analytics"
    | Compliance -> "/compliance"
    | AccessControl -> "/access-control"
    | Settings -> "/settings"
    | TestEvolution -> "/test-evolution"
    | Copilot -> "/copilot"
    | Register -> "/register"

let pathToPage (path: string) =
    match path.ToLower() with
    | "/" | "" -> Some Dashboard
    | "/alarms" -> Some Alarms
    | "/guardian" -> Some Guardian
    | "/sentinel" -> Some Sentinel
    | "/devices" -> Some Devices
    | "/video" -> Some Video
    | "/analytics" -> Some Analytics
    | "/compliance" -> Some Compliance
    | "/access-control" -> Some AccessControl
    | "/settings" -> Some Settings
    | "/test-evolution" -> Some TestEvolution
    | "/copilot" -> Some Copilot
    | "/register" -> Some Register
    | _ -> None

let pageRequiresAuth (page: Page) =
    match page with
    | Guardian | Sentinel | AccessControl | Register -> true
    | _ -> false

[<Tests>]
let pageRoutingTests =
    testList "PageRouting" [
        test "should map pages to paths" {
            Expect.equal (pageToPath Dashboard) "/" "Dashboard is root"
            Expect.equal (pageToPath Guardian) "/guardian" "Guardian path"
            Expect.equal (pageToPath TestEvolution) "/test-evolution" "TestEvolution path"
        }

        test "should parse paths to pages" {
            Expect.equal (pathToPage "/") (Some Dashboard) "Root is Dashboard"
            Expect.equal (pathToPage "/alarms") (Some Alarms) "Alarms path"
            Expect.equal (pathToPage "/unknown") None "Unknown path"
        }

        test "should identify auth-required pages" {
            Expect.isTrue (pageRequiresAuth Guardian) "Guardian requires auth"
            Expect.isTrue (pageRequiresAuth Sentinel) "Sentinel requires auth"
            Expect.isFalse (pageRequiresAuth Dashboard) "Dashboard is public"
        }

        test "should be case insensitive" {
            Expect.equal (pathToPage "/ALARMS") (Some Alarms) "Uppercase"
            Expect.equal (pathToPage "/Guardian") (Some Guardian) "Mixed case"
        }
    ]

// ============================================================================
// Alarm Model Tests
// ============================================================================

type Alarm = {
    Id: string
    Severity: AlarmSeverity
    Message: string
    NodeId: string
    OccurredAt: DateTime
    AcknowledgedAt: DateTime option
}

let alarmPriority (alarm: Alarm) =
    match alarm.Severity with
    | Critical -> 1
    | Warning -> 2
    | Info -> 3

let isUnacknowledged (alarm: Alarm) =
    alarm.AcknowledgedAt.IsNone

let sortAlarms (alarms: Alarm list) =
    alarms
    |> List.sortBy (fun a -> alarmPriority a, a.OccurredAt)

[<Tests>]
let alarmModelTests =
    testList "AlarmModel" [
        test "should prioritize critical alarms" {
            let critical = { Id = "1"; Severity = Critical; Message = ""; NodeId = ""; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            let warning = { Id = "2"; Severity = Warning; Message = ""; NodeId = ""; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            Expect.isLessThan (alarmPriority critical) (alarmPriority warning) "Critical < Warning"
        }

        test "should detect unacknowledged alarms" {
            let alarm = { Id = "1"; Severity = Warning; Message = ""; NodeId = ""; OccurredAt = DateTime.UtcNow; AcknowledgedAt = None }
            Expect.isTrue (isUnacknowledged alarm) "Should be unacknowledged"
        }

        test "should sort alarms by priority then time" {
            let now = DateTime.UtcNow
            let alarms = [
                { Id = "1"; Severity = Info; Message = ""; NodeId = ""; OccurredAt = now; AcknowledgedAt = None }
                { Id = "2"; Severity = Critical; Message = ""; NodeId = ""; OccurredAt = now.AddMinutes(-1.0); AcknowledgedAt = None }
                { Id = "3"; Severity = Warning; Message = ""; NodeId = ""; OccurredAt = now; AcknowledgedAt = None }
            ]
            let sorted = sortAlarms alarms
            Expect.equal sorted.[0].Id "2" "Critical first"
            Expect.equal sorted.[1].Id "3" "Warning second"
            Expect.equal sorted.[2].Id "1" "Info last"
        }
    ]

// ============================================================================
// Threat Model Tests
// ============================================================================

type Threat = {
    Id: string
    Category: string
    Description: string
    Level: ThreatLevel
    RPN: int
    Mitigated: bool
    DetectedAt: DateTime
}

let threatUrgency (threat: Threat) =
    match threat.Level with
    | ThreatLevel.Critical -> 4
    | ThreatLevel.High -> 3
    | ThreatLevel.Medium -> 2
    | ThreatLevel.Low -> 1

let requiresImmediateAction (threat: Threat) =
    threat.RPN >= 100 || threat.Level = ThreatLevel.Critical

[<Tests>]
let threatModelTests =
    testList "ThreatModel" [
        test "should calculate urgency" {
            let threat = { Id = "1"; Category = ""; Description = ""; Level = ThreatLevel.Critical; RPN = 200; Mitigated = false; DetectedAt = DateTime.UtcNow }
            Expect.equal (threatUrgency threat) 4 "Critical is urgency 4"
        }

        test "should detect immediate action required" {
            let highRPN = { Id = "1"; Category = ""; Description = ""; Level = ThreatLevel.High; RPN = 150; Mitigated = false; DetectedAt = DateTime.UtcNow }
            let critical = { Id = "2"; Category = ""; Description = ""; Level = ThreatLevel.Critical; RPN = 50; Mitigated = false; DetectedAt = DateTime.UtcNow }
            let low = { Id = "3"; Category = ""; Description = ""; Level = ThreatLevel.Low; RPN = 25; Mitigated = false; DetectedAt = DateTime.UtcNow }

            Expect.isTrue (requiresImmediateAction highRPN) "High RPN requires action"
            Expect.isTrue (requiresImmediateAction critical) "Critical requires action"
            Expect.isFalse (requiresImmediateAction low) "Low doesn't require immediate action"
        }
    ]

// ============================================================================
// Proposal Model Tests
// ============================================================================

type Proposal = {
    Id: string
    Title: string
    Description: string
    Category: string
    Status: ProposalStatus
    Votes: int
    RequiredVotes: int
    CreatedAt: DateTime
    ExpiresAt: DateTime option
}

let proposalProgress (proposal: Proposal) =
    if proposal.RequiredVotes = 0 then 100.0
    else float proposal.Votes / float proposal.RequiredVotes * 100.0

let canVote (proposal: Proposal) =
    proposal.Status = Pending

let isExpired (proposal: Proposal) =
    match proposal.ExpiresAt with
    | None -> false
    | Some expiry -> DateTime.UtcNow > expiry

[<Tests>]
let proposalModelTests =
    testList "ProposalModel" [
        test "should calculate progress" {
            let proposal = { Id = "1"; Title = ""; Description = ""; Category = ""; Status = Pending; Votes = 2; RequiredVotes = 4; CreatedAt = DateTime.UtcNow; ExpiresAt = None }
            Expect.floatClose Accuracy.medium (proposalProgress proposal) 50.0 "Should be 50%"
        }

        test "should detect votable status" {
            let pending = { Id = "1"; Title = ""; Description = ""; Category = ""; Status = Pending; Votes = 0; RequiredVotes = 3; CreatedAt = DateTime.UtcNow; ExpiresAt = None }
            let approved = { pending with Status = Approved }
            Expect.isTrue (canVote pending) "Pending can be voted"
            Expect.isFalse (canVote approved) "Approved cannot be voted"
        }

        test "should detect expired proposals" {
            let expired = { Id = "1"; Title = ""; Description = ""; Category = ""; Status = Pending; Votes = 0; RequiredVotes = 3; CreatedAt = DateTime.UtcNow.AddDays(-2.0); ExpiresAt = Some (DateTime.UtcNow.AddDays(-1.0)) }
            let valid = { expired with ExpiresAt = Some (DateTime.UtcNow.AddDays(1.0)) }
            Expect.isTrue (isExpired expired) "Past expiry is expired"
            Expect.isFalse (isExpired valid) "Future expiry is valid"
        }
    ]
