// =============================================================================
// Prajna C3I Cockpit - Messages (MVU Commands)
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011, SC-PRAJNA-001 to SC-PRAJNA-007
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-PRAJNA-*, AOR-PRAJNA-* |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Domain

open System
open Types

/// <summary>
/// MVU Messages for the Prajna C3I Cockpit
/// All user actions and system events are modeled as messages
/// </summary>
module Messages =

    // =========================================================================
    // Navigation Messages
    // =========================================================================

    type NavigationMsg =
        | Navigate of ActiveView
        | ToggleSidebar
        | GoBack
        | GoHome

    // =========================================================================
    // Theme Messages
    // =========================================================================

    type ThemeMsg =
        | SetTheme of ThemeMode
        | ToggleDarkMode
        | SetCustomColor of string * string  // key, value

    // =========================================================================
    // System Messages
    // =========================================================================

    type SystemMsg =
        | RefreshAll
        | HealthUpdated of SystemHealth
        | ConnectionStatusChanged of ConnectionStatus
        | SyncCompleted of DateTime
        | ErrorOccurred of string
        | ClearError
        | ShowSuccess of string
        | ClearSuccess

    // =========================================================================
    // Test Evolution Messages (SC-TEST-EVO-*)
    // =========================================================================

    type TestEvolutionMsg =
        | SetActiveModule of string
        | ClearActiveModule
        | GenerateTests of TestLevel
        | GenerateAllLevels
        | TestsGenerated of Result<FitnessMetrics, string>
        | TriggerEvolution
        | EvolutionCompleted of TestEvolutionState
        | UpdateGenomeConfig of GenomeConfig
        | SetMutationRate of float
        | SetCrossoverRate of float
        | SetSelectionPressure of float
        | OodaCycleCompleted of OodaState
        | FitnessUpdated of FitnessMetrics
        | LevelCoverageUpdated of LevelCoverage list
        | StartEvolution
        | StopEvolution
        | ResetGenome

    // =========================================================================
    // Alarms Messages
    // =========================================================================

    type AlarmsMsg =
        | LoadAlarms
        | AlarmsLoaded of Alarm list
        | NewAlarmReceived of Alarm
        | AcknowledgeAlarm of Guid
        | AlarmAcknowledged of Guid
        | ClearAlarm of Guid
        | AlarmCleared of Guid
        | FilterBySeverity of AlarmSeverity option
        | FilterByZone of string option
        | SortAlarms of string  // field name
        | StormDetected of AlarmStorm
        | StormCleared
        | ExportAlarms

    // =========================================================================
    // Devices Messages
    // =========================================================================

    type DevicesMsg =
        | LoadDevices
        | DevicesLoaded of Device list
        | SelectDevice of Device
        | DeselectDevice
        | DeviceStatusChanged of Guid * DeviceStatus
        | FilterByStatus of DeviceStatus option
        | FilterByZone of string option
        | RefreshDevice of Guid
        | RestartDevice of Guid
        | ExportDeviceList

    // =========================================================================
    // Video Messages
    // =========================================================================

    type VideoMsg =
        | LoadStreams
        | StreamsLoaded of VideoStream list
        | SelectStream of VideoStream
        | DeselectStream
        | StreamHealthChanged of Guid * StreamHealth
        | DetectionReceived of DetectionEvent
        | SetLayout of string
        | ToggleRecording of Guid
        | TakeSnapshot of Guid
        | SnapshotSaved of string

    // =========================================================================
    // AI Copilot Messages
    // =========================================================================

    type CopilotMsg =
        | SetInput of string
        | SendMessage
        | MessageSent of ChatMessage
        | ResponseReceived of ChatMessage
        | ClearChat
        | LoadContext
        | ContextLoaded of string
        | RequestSuggestion
        | SuggestionReceived of string

    // =========================================================================
    // Guardian Messages (SC-PRAJNA-001)
    // =========================================================================

    type GuardianMsg =
        | LoadProposals
        | ProposalsLoaded of Proposal list
        | NewProposal of Proposal
        | ApproveProposal of Guid
        | ProposalApproved of Guid
        | VetoProposal of Guid * string  // id, reason
        | ProposalVetoed of Guid
        | RefreshGuardianHealth
        | GuardianHealthUpdated of bool

    // =========================================================================
    // Sentinel Messages (SC-PRAJNA-004)
    // =========================================================================

    type SentinelMsg =
        | LoadSentinelState
        | SentinelStateLoaded of SentinelState
        | ThreatDetected of Threat
        | ThreatMitigated of Guid
        | RefreshHealthScore
        | HealthScoreUpdated of float
        | QuarantineProcess of string
        | ReleaseProcess of string
        | RunAssessment

    // =========================================================================
    // Immutable Register Messages (SC-PRAJNA-003)
    // =========================================================================

    type RegisterMsg =
        | LoadBlocks
        | BlocksLoaded of RegisterBlock list
        | NewBlockAdded of RegisterBlock
        | VerifyChain
        | ChainVerified of bool
        | ExportChain
        | SearchBlocks of string

    // =========================================================================
    // Analytics Messages
    // =========================================================================

    type AnalyticsMsg =
        | LoadReports
        | ReportsLoaded of ReportTemplate list
        | SelectReport of ReportTemplate
        | GenerateReport
        | ReportGenerated of string
        | LoadTrends
        | TrendsLoaded of (DateTime * float) list
        | SetDateRange of DateTime * DateTime

    // =========================================================================
    // Compliance Messages
    // =========================================================================

    type ComplianceMsg =
        | LoadComplianceItems
        | ComplianceItemsLoaded of ComplianceItem list
        | UpdateItemStatus of string * ComplianceStatus
        | AddEvidence of string * string
        | RunAudit
        | AuditCompleted of (DateTime * string) list

    // =========================================================================
    // Root Message Type
    // =========================================================================

    type Msg =
        // Navigation
        | Nav of NavigationMsg
        | Theme of ThemeMsg

        // System
        | System of SystemMsg

        // Domain Messages
        | TestEvo of TestEvolutionMsg
        | Alarm of AlarmsMsg
        | Device of DevicesMsg
        | Video of VideoMsg
        | Copilot of CopilotMsg
        | Guard of GuardianMsg
        | Sent of SentinelMsg
        | Reg of RegisterMsg
        | Analytics of AnalyticsMsg
        | Compliance of ComplianceMsg

        // Lifecycle
        | Initialize
        | Tick of DateTime
        | Dispose

    // =========================================================================
    // Command Helpers
    // =========================================================================

    /// Create a navigation message
    let navigate view = Nav (Navigate view)

    /// Create a system error message
    let error msg = System (ErrorOccurred msg)

    /// Create a success message
    let success msg = System (ShowSuccess msg)

    /// Create a test generation message
    let generateTests level = TestEvo (GenerateTests level)

    /// Create an alarm acknowledgment message
    let acknowledgeAlarm id = Alarm (AcknowledgeAlarm id)

    /// Create a copilot message send
    let sendCopilotMessage = Copilot SendMessage
