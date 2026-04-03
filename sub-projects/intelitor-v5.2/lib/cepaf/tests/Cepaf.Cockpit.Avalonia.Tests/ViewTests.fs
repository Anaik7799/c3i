/// Avalonia GUI View Tests
/// Tests for view rendering and behavior
module Cepaf.Cockpit.Avalonia.Tests.ViewTests

open System
open Expecto

// ============================================================================
// Dashboard View Tests
// ============================================================================

type DashboardViewState = {
    HealthScore: float
    ConnectedNodes: int
    ActiveAlarms: int
    PendingProposals: int
    ActiveThreats: int
    OodaCycleTime: TimeSpan
    IsLoading: bool
}

let defaultDashboardState = {
    HealthScore = 0.0
    ConnectedNodes = 0
    ActiveAlarms = 0
    PendingProposals = 0
    ActiveThreats = 0
    OodaCycleTime = TimeSpan.Zero
    IsLoading = true
}

let dashboardHasAlerts state =
    state.ActiveAlarms > 0 || state.ActiveThreats > 0

let dashboardHeaderClass state =
    if state.IsLoading then "header loading"
    elif state.HealthScore >= 90.0 then "header healthy"
    elif state.HealthScore >= 70.0 then "header warning"
    else "header critical"

let dashboardMetricCount state =
    // Count of metrics shown
    4 + (if state.ActiveAlarms > 0 then 1 else 0) + (if state.ActiveThreats > 0 then 1 else 0)

[<Tests>]
let dashboardViewTests =
    testList "DashboardView" [
        test "should start in loading state" {
            let state = defaultDashboardState
            Expect.isTrue state.IsLoading "Should be loading"
        }

        test "should detect alerts" {
            let withAlarms = { defaultDashboardState with ActiveAlarms = 5 }
            let withThreats = { defaultDashboardState with ActiveThreats = 2 }
            let clean = { defaultDashboardState with IsLoading = false }

            Expect.isTrue (dashboardHasAlerts withAlarms) "Has alarm alerts"
            Expect.isTrue (dashboardHasAlerts withThreats) "Has threat alerts"
            Expect.isFalse (dashboardHasAlerts clean) "No alerts"
        }

        test "should have correct header class" {
            let loading = defaultDashboardState
            let healthy = { defaultDashboardState with IsLoading = false; HealthScore = 95.0 }
            let warning = { defaultDashboardState with IsLoading = false; HealthScore = 75.0 }
            let critical = { defaultDashboardState with IsLoading = false; HealthScore = 50.0 }

            Expect.stringContains (dashboardHeaderClass loading) "loading" "Loading class"
            Expect.stringContains (dashboardHeaderClass healthy) "healthy" "Healthy class"
            Expect.stringContains (dashboardHeaderClass warning) "warning" "Warning class"
            Expect.stringContains (dashboardHeaderClass critical) "critical" "Critical class"
        }
    ]

// ============================================================================
// Alarms View Tests
// ============================================================================

type AlarmViewFilter =
    | All
    | Unacknowledged
    | Critical
    | ByNode of string

type AlarmsViewState = {
    Alarms: int
    Filter: AlarmViewFilter
    SearchQuery: string
    SelectedAlarmId: string option
    IsStormMode: bool
}

let alarmsViewFilterDescription filter =
    match filter with
    | All -> "All Alarms"
    | Unacknowledged -> "Unacknowledged Only"
    | Critical -> "Critical Only"
    | ByNode node -> sprintf "Node: %s" node

let shouldShowStormWarning state =
    state.IsStormMode || state.Alarms > 10

let alarmsViewCanBulkAck state =
    state.Filter = Unacknowledged && state.Alarms > 0

[<Tests>]
let alarmsViewTests =
    testList "AlarmsView" [
        test "should describe filter correctly" {
            Expect.equal (alarmsViewFilterDescription All) "All Alarms" "All filter"
            Expect.equal (alarmsViewFilterDescription Unacknowledged) "Unacknowledged Only" "Unack filter"
            Expect.stringContains (alarmsViewFilterDescription (ByNode "camera-1")) "camera-1" "Node filter"
        }

        test "should show storm warning" {
            let storm = { Alarms = 5; Filter = All; SearchQuery = ""; SelectedAlarmId = None; IsStormMode = true }
            let manyAlarms = { storm with IsStormMode = false; Alarms = 15 }
            let normal = { storm with IsStormMode = false; Alarms = 5 }

            Expect.isTrue (shouldShowStormWarning storm) "Storm mode shows warning"
            Expect.isTrue (shouldShowStormWarning manyAlarms) ">10 alarms shows warning"
            Expect.isFalse (shouldShowStormWarning normal) "Normal doesn't show warning"
        }

        test "should enable bulk ack for unacknowledged filter" {
            let canAck = { Alarms = 5; Filter = Unacknowledged; SearchQuery = ""; SelectedAlarmId = None; IsStormMode = false }
            let wrongFilter = { canAck with Filter = All }
            let noAlarms = { canAck with Alarms = 0 }

            Expect.isTrue (alarmsViewCanBulkAck canAck) "Can bulk ack"
            Expect.isFalse (alarmsViewCanBulkAck wrongFilter) "Wrong filter can't bulk ack"
            Expect.isFalse (alarmsViewCanBulkAck noAlarms) "No alarms can't bulk ack"
        }
    ]

// ============================================================================
// Guardian View Tests
// ============================================================================

type GuardianViewTab =
    | PendingTab
    | ApprovedTab
    | VetoedTab
    | HistoryTab

type GuardianViewState = {
    ActiveTab: GuardianViewTab
    Proposals: int
    SelectedProposalId: string option
    IsVoting: bool
}

let guardianViewTabLabel tab =
    match tab with
    | PendingTab -> "Pending"
    | ApprovedTab -> "Approved"
    | VetoedTab -> "Vetoed"
    | HistoryTab -> "History"

let guardianViewCanVote state =
    state.ActiveTab = PendingTab &&
    state.SelectedProposalId.IsSome &&
    not state.IsVoting

let guardianViewBadge tab count =
    match tab with
    | PendingTab when count > 0 -> Some count
    | _ -> None

[<Tests>]
let guardianViewTests =
    testList "GuardianView" [
        test "should have correct tab labels" {
            Expect.equal (guardianViewTabLabel PendingTab) "Pending" "Pending tab"
            Expect.equal (guardianViewTabLabel ApprovedTab) "Approved" "Approved tab"
        }

        test "should enable voting on pending tab" {
            let canVote = { ActiveTab = PendingTab; Proposals = 5; SelectedProposalId = Some "p-1"; IsVoting = false }
            let wrongTab = { canVote with ActiveTab = ApprovedTab }
            let noSelection = { canVote with SelectedProposalId = None }
            let voting = { canVote with IsVoting = true }

            Expect.isTrue (guardianViewCanVote canVote) "Can vote"
            Expect.isFalse (guardianViewCanVote wrongTab) "Wrong tab"
            Expect.isFalse (guardianViewCanVote noSelection) "No selection"
            Expect.isFalse (guardianViewCanVote voting) "Already voting"
        }

        test "should show badge only on pending with count" {
            Expect.equal (guardianViewBadge PendingTab 5) (Some 5) "Pending with count"
            Expect.equal (guardianViewBadge PendingTab 0) None "Pending no count"
            Expect.equal (guardianViewBadge ApprovedTab 10) None "Approved never has badge"
        }
    ]

// ============================================================================
// Sentinel View Tests
// ============================================================================

type SentinelViewMode =
    | ListView
    | DashboardMode
    | TimelineMode

type SentinelViewState = {
    ViewMode: SentinelViewMode
    Threats: int
    MitigatedCount: int
    ShowMitigated: bool
    SelectedThreatId: string option
}

let sentinelViewModeIcon mode =
    match mode with
    | ListView -> "view_list"
    | DashboardMode -> "dashboard"
    | TimelineMode -> "timeline"

let sentinelViewActiveCount state =
    state.Threats - state.MitigatedCount

let sentinelViewCanMitigate state =
    state.SelectedThreatId.IsSome

[<Tests>]
let sentinelViewTests =
    testList "SentinelView" [
        test "should have correct mode icons" {
            Expect.equal (sentinelViewModeIcon ListView) "view_list" "List icon"
            Expect.equal (sentinelViewModeIcon DashboardMode) "dashboard" "Dashboard icon"
            Expect.equal (sentinelViewModeIcon TimelineMode) "timeline" "Timeline icon"
        }

        test "should calculate active count" {
            let state = { ViewMode = ListView; Threats = 10; MitigatedCount = 3; ShowMitigated = false; SelectedThreatId = None }
            Expect.equal (sentinelViewActiveCount state) 7 "Active = Total - Mitigated"
        }

        test "should enable mitigation with selection" {
            let canMitigate = { ViewMode = ListView; Threats = 5; MitigatedCount = 0; ShowMitigated = false; SelectedThreatId = Some "t-1" }
            let noSelection = { canMitigate with SelectedThreatId = None }

            Expect.isTrue (sentinelViewCanMitigate canMitigate) "Can mitigate with selection"
            Expect.isFalse (sentinelViewCanMitigate noSelection) "Can't mitigate without selection"
        }
    ]

// ============================================================================
// Test Evolution View Tests
// ============================================================================

type TestEvolutionViewState = {
    Fitness: float
    Generation: int
    IsEvolving: bool
    SelectedModule: string option
    CoveragePercent: float
}

let testEvolutionViewStatusText state =
    if state.IsEvolving then sprintf "Evolving... Generation %d" state.Generation
    elif state.Fitness >= 0.8 then "Fitness Optimal"
    elif state.Fitness >= 0.5 then "Fitness Acceptable"
    else "Fitness Below Threshold"

let testEvolutionViewCanTrigger state =
    not state.IsEvolving && state.SelectedModule.IsSome

let testEvolutionViewShouldWarn state =
    state.Fitness < 0.5 || state.CoveragePercent < 80.0

[<Tests>]
let testEvolutionViewTests =
    testList "TestEvolutionView" [
        test "should show correct status text" {
            let evolving = { Fitness = 0.6; Generation = 5; IsEvolving = true; SelectedModule = None; CoveragePercent = 85.0 }
            let optimal = { evolving with IsEvolving = false; Fitness = 0.9 }
            let low = { evolving with IsEvolving = false; Fitness = 0.3 }

            Expect.stringContains (testEvolutionViewStatusText evolving) "Generation 5" "Evolving shows generation"
            Expect.equal (testEvolutionViewStatusText optimal) "Fitness Optimal" "Optimal status"
            Expect.equal (testEvolutionViewStatusText low) "Fitness Below Threshold" "Low fitness status"
        }

        test "should enable trigger when not evolving with selection" {
            let canTrigger = { Fitness = 0.6; Generation = 5; IsEvolving = false; SelectedModule = Some "MyModule"; CoveragePercent = 85.0 }
            let evolving = { canTrigger with IsEvolving = true }
            let noModule = { canTrigger with SelectedModule = None }

            Expect.isTrue (testEvolutionViewCanTrigger canTrigger) "Can trigger"
            Expect.isFalse (testEvolutionViewCanTrigger evolving) "Can't trigger while evolving"
            Expect.isFalse (testEvolutionViewCanTrigger noModule) "Can't trigger without module"
        }

        test "should warn on low fitness or coverage" {
            let lowFitness = { Fitness = 0.3; Generation = 1; IsEvolving = false; SelectedModule = None; CoveragePercent = 90.0 }
            let lowCoverage = { Fitness = 0.9; Generation = 1; IsEvolving = false; SelectedModule = None; CoveragePercent = 70.0 }
            let good = { Fitness = 0.9; Generation = 1; IsEvolving = false; SelectedModule = None; CoveragePercent = 95.0 }

            Expect.isTrue (testEvolutionViewShouldWarn lowFitness) "Low fitness warns"
            Expect.isTrue (testEvolutionViewShouldWarn lowCoverage) "Low coverage warns"
            Expect.isFalse (testEvolutionViewShouldWarn good) "Good state doesn't warn"
        }
    ]

// ============================================================================
// Settings View Tests
// ============================================================================

type ThemeChoice = Dark | Light | Aerospace

type SettingsViewState = {
    Theme: ThemeChoice
    RefreshRate: int
    SoundEnabled: bool
    NotificationsEnabled: bool
    HasUnsavedChanges: bool
}

let settingsViewThemeName theme =
    match theme with
    | Dark -> "Dark Cockpit"
    | Light -> "Light Mode"
    | Aerospace -> "Aerospace"

let settingsViewRefreshOptions = [1000; 5000; 10000; 30000; 60000]

let settingsViewValidateRefreshRate rate =
    List.contains rate settingsViewRefreshOptions

let settingsViewCanSave state =
    state.HasUnsavedChanges

[<Tests>]
let settingsViewTests =
    testList "SettingsView" [
        test "should have correct theme names" {
            Expect.equal (settingsViewThemeName Dark) "Dark Cockpit" "Dark theme"
            Expect.equal (settingsViewThemeName Light) "Light Mode" "Light theme"
            Expect.equal (settingsViewThemeName Aerospace) "Aerospace" "Aerospace theme"
        }

        test "should validate refresh rates" {
            Expect.isTrue (settingsViewValidateRefreshRate 1000) "1s valid"
            Expect.isTrue (settingsViewValidateRefreshRate 5000) "5s valid"
            Expect.isFalse (settingsViewValidateRefreshRate 2000) "2s invalid"
            Expect.isFalse (settingsViewValidateRefreshRate 0) "0 invalid"
        }

        test "should enable save with changes" {
            let changed = { Theme = Dark; RefreshRate = 5000; SoundEnabled = true; NotificationsEnabled = true; HasUnsavedChanges = true }
            let saved = { changed with HasUnsavedChanges = false }

            Expect.isTrue (settingsViewCanSave changed) "Can save with changes"
            Expect.isFalse (settingsViewCanSave saved) "Can't save without changes"
        }
    ]

// ============================================================================
// Copilot View Tests
// ============================================================================

type CopilotMessageRole = User | Assistant | System

type CopilotMessage = {
    Role: CopilotMessageRole
    Content: string
    Timestamp: DateTime
}

type CopilotViewState = {
    Messages: CopilotMessage list
    Input: string
    IsProcessing: bool
    HasFounderContext: bool
}

let copilotViewCanSend state =
    not (String.IsNullOrWhiteSpace state.Input) && not state.IsProcessing

let copilotViewMessageCount state =
    state.Messages.Length

let copilotViewLastMessageRole state =
    state.Messages |> List.tryLast |> Option.map (fun m -> m.Role)

[<Tests>]
let copilotViewTests =
    testList "CopilotView" [
        test "should enable send with input and not processing" {
            let canSend = { Messages = []; Input = "Hello"; IsProcessing = false; HasFounderContext = true }
            let noInput = { canSend with Input = "" }
            let processing = { canSend with IsProcessing = true }

            Expect.isTrue (copilotViewCanSend canSend) "Can send"
            Expect.isFalse (copilotViewCanSend noInput) "Can't send without input"
            Expect.isFalse (copilotViewCanSend processing) "Can't send while processing"
        }

        test "should count messages" {
            let msg = { Role = User; Content = "Hi"; Timestamp = DateTime.UtcNow }
            let state = { Messages = [msg; msg; msg]; Input = ""; IsProcessing = false; HasFounderContext = true }
            Expect.equal (copilotViewMessageCount state) 3 "Should have 3 messages"
        }

        test "should get last message role" {
            let userMsg = { Role = User; Content = "Hi"; Timestamp = DateTime.UtcNow }
            let assistantMsg = { Role = Assistant; Content = "Hello"; Timestamp = DateTime.UtcNow }
            let state = { Messages = [userMsg; assistantMsg]; Input = ""; IsProcessing = false; HasFounderContext = true }
            Expect.equal (copilotViewLastMessageRole state) (Some Assistant) "Last is Assistant"
        }
    ]

// ============================================================================
// View Layout Tests
// ============================================================================

type LayoutMode = Compact | Normal | Expanded

type ViewLayout = {
    Mode: LayoutMode
    SidebarVisible: bool
    HeaderVisible: bool
    FooterVisible: bool
}

let layoutContentWidth mode sidebarVisible =
    let baseWidth =
        match mode with
        | Compact -> 800
        | Normal -> 1200
        | Expanded -> 1600
    if sidebarVisible then baseWidth - 240 else baseWidth

let layoutResponsiveMode (windowWidth: int) =
    if windowWidth < 900 then Compact
    elif windowWidth < 1400 then Normal
    else Expanded

[<Tests>]
let viewLayoutTests =
    testList "ViewLayout" [
        test "should calculate content width with sidebar" {
            let withSidebar = layoutContentWidth Normal true
            let withoutSidebar = layoutContentWidth Normal false
            Expect.equal withSidebar (1200 - 240) "With sidebar"
            Expect.equal withoutSidebar 1200 "Without sidebar"
        }

        test "should select responsive mode" {
            Expect.equal (layoutResponsiveMode 800) Compact "Small screen"
            Expect.equal (layoutResponsiveMode 1200) Normal "Medium screen"
            Expect.equal (layoutResponsiveMode 1920) Expanded "Large screen"
        }
    ]
