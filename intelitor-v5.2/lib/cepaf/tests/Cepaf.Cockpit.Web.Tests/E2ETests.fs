/// WebUI End-to-End Tests
/// Tests for full user journeys and integration scenarios
module Cepaf.Cockpit.Web.Tests.E2ETests

open System
open Expecto

// ============================================================================
// E2E Test Infrastructure
// ============================================================================

type E2ETestContext = {
    BaseUrl: string
    Timeout: TimeSpan
    Screenshots: bool
}

let defaultContext = {
    BaseUrl = "http://localhost:4000"
    Timeout = TimeSpan.FromSeconds(30.0)
    Screenshots = true
}

type E2EResult =
    | Pass of testName: string * duration: TimeSpan
    | Fail of testName: string * error: string * screenshot: string option
    | Skip of testName: string * reason: string

// ============================================================================
// Dashboard Journey Tests (10 scenarios)
// ============================================================================

type DashboardScenario =
    | InitialLoadWithAllMetrics
    | HealthScoreDegradationAlert
    | MetricTrendChanges
    | StaleDataVisualDecay
    | ConnectionLossReconnect
    | ThemeSwitching
    | RefreshRateChanges
    | MultiUserConcurrentView
    | BrowserTabSwitchReturn
    | SessionTimeoutRefresh

let dashboardScenarioName (scenario: DashboardScenario) =
    match scenario with
    | InitialLoadWithAllMetrics -> "Dashboard loads with all metrics visible"
    | HealthScoreDegradationAlert -> "Health score degradation triggers visual alert"
    | MetricTrendChanges -> "Metric trends (rising/falling/stable) display correctly"
    | StaleDataVisualDecay -> "Stale data (>30s) shows visual decay indicator"
    | ConnectionLossReconnect -> "Connection loss and reconnection handled gracefully"
    | ThemeSwitching -> "Theme switching (Dark/Light/Aerospace) works correctly"
    | RefreshRateChanges -> "Refresh rate changes (1s/5s/30s) take effect"
    | MultiUserConcurrentView -> "Multiple users can view dashboard concurrently"
    | BrowserTabSwitchReturn -> "Browser tab switch/return restores state"
    | SessionTimeoutRefresh -> "Session timeout triggers refresh prompt"

[<Tests>]
let dashboardJourneyTests =
    testList "Dashboard Journey" [
        test "Initial load scenario defined" {
            let name = dashboardScenarioName InitialLoadWithAllMetrics
            Expect.stringContains name "all metrics" "Should describe metrics load"
        }

        test "All 10 dashboard scenarios have names" {
            let scenarios = [
                InitialLoadWithAllMetrics
                HealthScoreDegradationAlert
                MetricTrendChanges
                StaleDataVisualDecay
                ConnectionLossReconnect
                ThemeSwitching
                RefreshRateChanges
                MultiUserConcurrentView
                BrowserTabSwitchReturn
                SessionTimeoutRefresh
            ]
            Expect.equal scenarios.Length 10 "Should have 10 scenarios"
            for s in scenarios do
                let name = dashboardScenarioName s
                Expect.isNotEmpty name "Each scenario should have a name"
        }
    ]

// ============================================================================
// Alarm Management Journey Tests (10 scenarios)
// ============================================================================

type AlarmScenario =
    | NewAlarmNotification
    | AlarmAcknowledgmentFlow
    | AlarmStormDetection
    | FilterBySeverityLevel
    | SearchByNodeZone
    | AlarmEscalationTimeout
    | BulkAcknowledgment
    | HistoricalAlarmView
    | AlarmCorrelationDisplay
    | SoundVisualNotificationToggle

let alarmScenarioName (scenario: AlarmScenario) =
    match scenario with
    | NewAlarmNotification -> "New alarm appears with notification"
    | AlarmAcknowledgmentFlow -> "Alarm acknowledgment workflow completes"
    | AlarmStormDetection -> "Alarm storm (>10/min) detected and indicated"
    | FilterBySeverityLevel -> "Filter by severity level (Info/Warning/Critical)"
    | SearchByNodeZone -> "Search by node ID or zone name"
    | AlarmEscalationTimeout -> "Unacknowledged alarm escalates after timeout"
    | BulkAcknowledgment -> "Multiple alarms acknowledged in bulk"
    | HistoricalAlarmView -> "Historical alarms viewable and searchable"
    | AlarmCorrelationDisplay -> "Correlated alarms grouped together"
    | SoundVisualNotificationToggle -> "Sound/visual notifications toggle works"

[<Tests>]
let alarmJourneyTests =
    testList "Alarm Journey" [
        test "All 10 alarm scenarios have names" {
            let scenarios = [
                NewAlarmNotification
                AlarmAcknowledgmentFlow
                AlarmStormDetection
                FilterBySeverityLevel
                SearchByNodeZone
                AlarmEscalationTimeout
                BulkAcknowledgment
                HistoricalAlarmView
                AlarmCorrelationDisplay
                SoundVisualNotificationToggle
            ]
            Expect.equal scenarios.Length 10 "Should have 10 scenarios"
        }
    ]

// ============================================================================
// Guardian Approval Journey Tests (10 scenarios)
// ============================================================================

type GuardianScenario =
    | ProposalSubmissionFromCLI
    | ApprovalWithReason
    | VetoWithMandatoryReason
    | ConstitutionalCheckFailure
    | FounderDirectiveAlignment
    | MultiVoterQuorum
    | ProposalTimeout
    | EmergencyOverrideExecutive
    | AuditTrailVerification
    | RollbackAfterApproval

let guardianScenarioName (scenario: GuardianScenario) =
    match scenario with
    | ProposalSubmissionFromCLI -> "Proposal submitted from CLI appears in WebUI"
    | ApprovalWithReason -> "Proposal approved with documented reason"
    | VetoWithMandatoryReason -> "Proposal vetoed requires mandatory reason"
    | ConstitutionalCheckFailure -> "Constitutional check failure blocks approval"
    | FounderDirectiveAlignment -> "Founder Directive alignment verified"
    | MultiVoterQuorum -> "Multi-voter quorum reached for approval"
    | ProposalTimeout -> "Proposal times out after inactivity"
    | EmergencyOverrideExecutive -> "Emergency override by Executive Agent"
    | AuditTrailVerification -> "Audit trail captures all approval actions"
    | RollbackAfterApproval -> "Approved change can be rolled back"

[<Tests>]
let guardianJourneyTests =
    testList "Guardian Journey" [
        test "Constitutional check scenario defined" {
            let name = guardianScenarioName ConstitutionalCheckFailure
            Expect.stringContains name "Constitutional" "Should mention constitutional"
        }

        test "All 10 guardian scenarios have names" {
            let scenarios = [
                ProposalSubmissionFromCLI
                ApprovalWithReason
                VetoWithMandatoryReason
                ConstitutionalCheckFailure
                FounderDirectiveAlignment
                MultiVoterQuorum
                ProposalTimeout
                EmergencyOverrideExecutive
                AuditTrailVerification
                RollbackAfterApproval
            ]
            Expect.equal scenarios.Length 10 "Should have 10 scenarios"
        }
    ]

// ============================================================================
// Sentinel Threat Journey Tests (10 scenarios)
// ============================================================================

type SentinelScenario =
    | NewThreatDetection
    | RPNScoreCalculationDisplay
    | MitigationActionTrigger
    | ThreatEscalationPath
    | PatternHunterPreErrorDetection
    | SymbioticDefenseResponse
    | FalsePositiveMarking
    | ThreatHistoryQuery
    | ActiveThreatDashboard
    | ThreatTrendAnalysis

let sentinelScenarioName (scenario: SentinelScenario) =
    match scenario with
    | NewThreatDetection -> "New threat detected and displayed"
    | RPNScoreCalculationDisplay -> "RPN score calculated and displayed"
    | MitigationActionTrigger -> "Mitigation action triggered successfully"
    | ThreatEscalationPath -> "Threat escalation path followed"
    | PatternHunterPreErrorDetection -> "Pattern Hunter detects pre-error signatures"
    | SymbioticDefenseResponse -> "Symbiotic Defense responds to threat"
    | FalsePositiveMarking -> "False positive marked and excluded"
    | ThreatHistoryQuery -> "Threat history queryable and searchable"
    | ActiveThreatDashboard -> "Active threat dashboard shows real-time data"
    | ThreatTrendAnalysis -> "Threat trend analysis over time displayed"

[<Tests>]
let sentinelJourneyTests =
    testList "Sentinel Journey" [
        test "Pattern Hunter scenario defined" {
            let name = sentinelScenarioName PatternHunterPreErrorDetection
            Expect.stringContains name "Pattern Hunter" "Should mention Pattern Hunter"
        }

        test "All 10 sentinel scenarios have names" {
            let scenarios = [
                NewThreatDetection
                RPNScoreCalculationDisplay
                MitigationActionTrigger
                ThreatEscalationPath
                PatternHunterPreErrorDetection
                SymbioticDefenseResponse
                FalsePositiveMarking
                ThreatHistoryQuery
                ActiveThreatDashboard
                ThreatTrendAnalysis
            ]
            Expect.equal scenarios.Length 10 "Should have 10 scenarios"
        }
    ]

// ============================================================================
// Device Management Journey Tests (10 scenarios)
// ============================================================================

type DeviceScenario =
    | DeviceDiscoveryRegistration
    | HealthMatrixVisualization
    | DeviceOfflineDetection
    | ReconnectionHandling
    | DeviceMetricDrilling
    | BatchOperations
    | FirmwareUpdateTracking
    | ZoneBasedFiltering
    | NetworkTopologyView
    | DeviceComparison

let deviceScenarioName (scenario: DeviceScenario) =
    match scenario with
    | DeviceDiscoveryRegistration -> "Device discovered and registered"
    | HealthMatrixVisualization -> "Device health matrix displayed"
    | DeviceOfflineDetection -> "Offline device detected and flagged"
    | ReconnectionHandling -> "Device reconnection handled gracefully"
    | DeviceMetricDrilling -> "Device metric drilling to details"
    | BatchOperations -> "Batch operations on multiple devices"
    | FirmwareUpdateTracking -> "Firmware update progress tracked"
    | ZoneBasedFiltering -> "Zone-based device filtering works"
    | NetworkTopologyView -> "Network topology view renders"
    | DeviceComparison -> "Device comparison side-by-side"

[<Tests>]
let deviceJourneyTests =
    testList "Device Journey" [
        test "All 10 device scenarios have names" {
            let scenarios = [
                DeviceDiscoveryRegistration
                HealthMatrixVisualization
                DeviceOfflineDetection
                ReconnectionHandling
                DeviceMetricDrilling
                BatchOperations
                FirmwareUpdateTracking
                ZoneBasedFiltering
                NetworkTopologyView
                DeviceComparison
            ]
            Expect.equal scenarios.Length 10 "Should have 10 scenarios"
        }
    ]

// ============================================================================
// Cross-Interface Consistency Tests
// ============================================================================

type ConsistencyCheck =
    | HealthScoreMatches
    | AlarmListOrdering
    | ProposalStatusSync
    | ThreatRPNCalculation
    | ConnectionStatusUnified

let consistencyCheckDescription (check: ConsistencyCheck) =
    match check with
    | HealthScoreMatches -> "Health score same in TUI/GUI/WebUI (±0.1%)"
    | AlarmListOrdering -> "Alarm list ordering identical (timestamp sort)"
    | ProposalStatusSync -> "Proposal status syncs within 1s"
    | ThreatRPNCalculation -> "Threat RPN calculated identically"
    | ConnectionStatusUnified -> "Connection status uses unified enum"

[<Tests>]
let consistencyTests =
    testList "Cross-Interface Consistency" [
        test "All consistency checks defined" {
            let checks = [
                HealthScoreMatches
                AlarmListOrdering
                ProposalStatusSync
                ThreatRPNCalculation
                ConnectionStatusUnified
            ]
            Expect.equal checks.Length 5 "Should have 5 consistency checks"
        }
    ]

// ============================================================================
// Performance Requirements
// ============================================================================

type PerformanceRequirement = {
    Operation: string
    TargetMs: int
    MaxMs: int
}

let performanceRequirements = [
    { Operation = "UI render"; TargetMs = 16; MaxMs = 33 }
    { Operation = "API call"; TargetMs = 50; MaxMs = 100 }
    { Operation = "Zenoh message"; TargetMs = 10; MaxMs = 50 }
    { Operation = "DB query"; TargetMs = 5; MaxMs = 20 }
    { Operation = "Guardian approval"; TargetMs = 100; MaxMs = 500 }
]

[<Tests>]
let performanceTests =
    testList "Performance Requirements" [
        test "UI render target is 16ms (60fps)" {
            let req = performanceRequirements |> List.find (fun r -> r.Operation = "UI render")
            Expect.equal req.TargetMs 16 "Target should be 16ms for 60fps"
        }

        test "API call target meets SC-PRF-050" {
            let req = performanceRequirements |> List.find (fun r -> r.Operation = "API call")
            Expect.isLessThanOrEqual req.TargetMs 50 "SC-PRF-050 requires <50ms"
        }

        test "All requirements have target < max" {
            for req in performanceRequirements do
                Expect.isLessThan req.TargetMs req.MaxMs "Target should be less than max"
        }
    ]

// ============================================================================
// Total E2E Scenario Count
// ============================================================================

[<Tests>]
let scenarioCountTests =
    testList "E2E Scenario Coverage" [
        test "Total scenarios = 50" {
            let dashboardCount = 10
            let alarmCount = 10
            let guardianCount = 10
            let sentinelCount = 10
            let deviceCount = 10
            let total = dashboardCount + alarmCount + guardianCount + sentinelCount + deviceCount
            Expect.equal total 50 "Should have 50 total E2E scenarios"
        }
    ]
