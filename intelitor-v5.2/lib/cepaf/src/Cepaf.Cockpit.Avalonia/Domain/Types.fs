// =============================================================================
// Prajna C3I Cockpit - Domain Types
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011, SC-PRAJNA-001 to SC-PRAJNA-007
// Standards: NASA-STD-3000, NUREG-0700, MIL-STD-1472H, IEC 61508
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

/// <summary>
/// Core domain types for the Prajna C3I Cockpit
/// Safety-critical types with immutable design
/// </summary>
module Types =

    // =========================================================================
    // Navigation & Views
    // =========================================================================

    /// Active view/page in the cockpit
    type ActiveView =
        | Dashboard
        | TestEvolution
        | Alarms
        | Devices
        | Video
        | Analytics
        | Compliance
        | AccessControl
        | AiCopilot
        | Guardian
        | Sentinel
        | ImmutableRegister
        | Settings

    // =========================================================================
    // Theme System (SC-THEME-001 to SC-THEME-005)
    // =========================================================================

    type ThemeMode =
        | Dark
        | Light
        | HighContrast
        | Aerospace

    type ColorScheme = {
        Primary: string
        Secondary: string
        Accent: string
        Background: string
        Surface: string
        Error: string
        Warning: string
        Success: string
        Info: string
        OnPrimary: string
        OnBackground: string
        OnSurface: string
    }

    // =========================================================================
    // Health & Status
    // =========================================================================

    type HealthStatus =
        | Healthy
        | Degraded
        | Critical
        | Unknown

    type SystemHealth = {
        Overall: HealthStatus
        CpuUsage: float
        MemoryUsage: float
        DiskUsage: float
        NetworkLatency: int  // milliseconds
        ActiveConnections: int
        ErrorRate: float
        LastUpdated: DateTime
    }

    // =========================================================================
    // OODA Cycle (SC-BIO-001)
    // =========================================================================

    type OodaPhase =
        | Observe
        | Orient
        | Decide
        | Act
        | Complete

    type OodaState = {
        CurrentPhase: OodaPhase
        CycleCount: int
        CycleStartTime: DateTime
        LastCycleDuration: TimeSpan
        ObservationsCount: int
        DecisionsMade: int
        ActionsExecuted: int
    }

    // =========================================================================
    // Test Evolution (SC-TEST-EVO-001 to SC-TEST-EVO-007)
    // =========================================================================

    type TestLevel =
        | TDG
        | FMEA
        | Formal
        | Graph
        | BDD

    type LevelCoverage = {
        Level: TestLevel
        Coverage: float
        TestCount: int
        PassRate: float
        LastRun: DateTime option
    }

    type FitnessMetrics = {
        Coverage: float
        PassRate: float
        MutationScore: float
        Diversity: float
        Combined: float
    }

    type GenomeConfig = {
        MutationRate: float
        CrossoverRate: float
        SelectionPressure: float
        ElitePreservation: float
        DiversityFloor: float
    }

    type TestEvolutionState = {
        Fitness: FitnessMetrics
        Genome: GenomeConfig
        Ooda: OodaState
        LevelCoverages: LevelCoverage list
        ActiveModule: string option
        IsEvolving: bool
        GenerationCount: int
    }

    // =========================================================================
    // Alarms Domain
    // =========================================================================

    type AlarmSeverity =
        | Critical
        | High
        | Medium
        | Low
        | Info

    type AlarmStatus =
        | Active
        | Acknowledged
        | Cleared
        | Escalated

    type Alarm = {
        Id: Guid
        Code: string
        Message: string
        Severity: AlarmSeverity
        Status: AlarmStatus
        Zone: string
        Device: string option
        Timestamp: DateTime
        AcknowledgedBy: string option
        AcknowledgedAt: DateTime option
    }

    type AlarmStorm = {
        IsActive: bool
        AlarmCount: int
        StartTime: DateTime option
        AffectedZones: string list
    }

    type AlarmsState = {
        ActiveAlarms: Alarm list
        RecentAlarms: Alarm list
        Storm: AlarmStorm
        TotalToday: int
        AcknowledgedToday: int
        CorrelationGroups: (string * Alarm list) list
    }

    // =========================================================================
    // Devices Domain
    // =========================================================================

    type DeviceType =
        | Camera
        | Sensor
        | Controller
        | Panel
        | Gateway
        | Unknown

    type DeviceStatus =
        | Online
        | Offline
        | Maintenance
        | Error

    type Device = {
        Id: Guid
        Name: string
        DeviceType: DeviceType
        Status: DeviceStatus
        IpAddress: string option
        MacAddress: string option
        Zone: string
        LastSeen: DateTime
        Uptime: TimeSpan
        FirmwareVersion: string option
    }

    type DevicesState = {
        Devices: Device list
        OnlineCount: int
        OfflineCount: int
        SelectedDevice: Device option
    }

    // =========================================================================
    // Video Domain
    // =========================================================================

    type StreamHealth =
        | Excellent
        | Good
        | Fair
        | Poor
        | NoSignal

    type VideoStream = {
        Id: Guid
        CameraName: string
        RtspUrl: string
        Health: StreamHealth
        Resolution: string
        Fps: int
        Bitrate: int
        IsRecording: bool
    }

    type DetectionEvent = {
        Id: Guid
        StreamId: Guid
        ObjectType: string
        Confidence: float
        BoundingBox: (float * float * float * float)
        Timestamp: DateTime
    }

    type VideoState = {
        Streams: VideoStream list
        RecentDetections: DetectionEvent list
        ActiveLayout: string
        SelectedStream: VideoStream option
    }

    // =========================================================================
    // AI Copilot Domain
    // =========================================================================

    type ChatRole =
        | User
        | Assistant
        | System

    type ChatMessage = {
        Id: Guid
        Role: ChatRole
        Content: string
        Timestamp: DateTime
        IsThinking: bool
    }

    type CopilotState = {
        Messages: ChatMessage list
        CurrentInput: string
        IsProcessing: bool
        LastSuggestion: string option
        ContextSummary: string
    }

    // =========================================================================
    // Guardian Domain (SC-PRAJNA-001)
    // =========================================================================

    type ProposalStatus =
        | Pending
        | Approved
        | Vetoed
        | Expired

    type Proposal = {
        Id: Guid
        Action: string
        Domain: string
        Description: string
        Status: ProposalStatus
        VetoReason: string option
        FallbackAction: string option
        CreatedAt: DateTime
        ResolvedAt: DateTime option
    }

    type GuardianState = {
        Proposals: Proposal list
        TotalApproved: int
        TotalVetoed: int
        IsHealthy: bool
        LastHealthCheck: DateTime
    }

    // =========================================================================
    // Sentinel Domain (SC-PRAJNA-004)
    // =========================================================================

    type ThreatSeverity =
        | Extinction
        | Critical
        | High
        | Medium
        | Low

    type Threat = {
        Id: Guid
        Pattern: string
        Severity: ThreatSeverity
        RpnScore: int
        DetectedAt: DateTime
        Mitigated: bool
        QuarantineStatus: string option
    }

    type SentinelState = {
        HealthScore: float
        ActiveThreats: Threat list
        ThreatTaxonomy: Map<string, int>
        QuarantinedProcesses: int
        LastAssessment: DateTime
    }

    // =========================================================================
    // Immutable Register Domain (SC-PRAJNA-003)
    // =========================================================================

    type RegisterBlock = {
        Index: int64
        Hash: string
        PreviousHash: string
        Content: string
        Signature: string
        Timestamp: DateTime
    }

    type RegisterState = {
        Blocks: RegisterBlock list
        ChainLength: int64
        IsVerified: bool
        LastBlock: RegisterBlock option
        IntegrityStatus: string
    }

    // =========================================================================
    // Analytics & Compliance
    // =========================================================================

    type ReportTemplate = {
        Id: string
        Name: string
        Description: string
        Category: string
    }

    type AnalyticsState = {
        AvailableReports: ReportTemplate list
        RecentReports: string list
        TrendData: (DateTime * float) list
        SelectedReport: ReportTemplate option
    }

    type ComplianceStatus =
        | Compliant
        | NonCompliant
        | Pending
        | Unknown

    type ComplianceItem = {
        Standard: string
        Requirement: string
        Status: ComplianceStatus
        LastAudit: DateTime
        Evidence: string list
    }

    type ComplianceState = {
        Items: ComplianceItem list
        OverallStatus: ComplianceStatus
        AuditTrail: (DateTime * string) list
        PendingActions: string list
    }

    // =========================================================================
    // Connection & Sync State
    // =========================================================================

    type ConnectionStatus =
        | Connected
        | Connecting
        | Disconnected
        | Error of string

    type SyncState = {
        ElixirConnection: ConnectionStatus
        ZenohConnection: ConnectionStatus
        LastSync: DateTime
        PendingMessages: int
    }

    // =========================================================================
    // Application Model
    // =========================================================================

    type Model = {
        // Navigation
        ActiveView: ActiveView
        SidebarExpanded: bool

        // Theme
        Theme: ThemeMode
        Colors: ColorScheme

        // System Status
        SystemHealth: SystemHealth
        SyncState: SyncState

        // Domain States
        TestEvolution: TestEvolutionState
        Alarms: AlarmsState
        Devices: DevicesState
        Video: VideoState
        Copilot: CopilotState
        Guardian: GuardianState
        Sentinel: SentinelState
        Register: RegisterState
        Analytics: AnalyticsState
        Compliance: ComplianceState

        // UI State
        IsLoading: bool
        ErrorMessage: string option
        SuccessMessage: string option
        LastUpdated: DateTime
    }
