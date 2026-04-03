namespace Cepaf.Cockpit.Web.Domain

open System

/// =============================================================================
/// PRAJNA C3I WebUI - Domain Types
/// =============================================================================
/// Re-exports and extends the shared domain model for web-specific needs.
/// STAMP: SC-COCKPIT-001 (All UI interfaces MUST share domain model)
/// =============================================================================

module Types =

    // Re-export core types from shared domain
    type Alarm = Cepaf.Cockpit.Domain.Alarm
    type AlarmLevel = Cepaf.Cockpit.Domain.AlarmLevel
    type ConnectionStatus = Cepaf.Cockpit.Domain.ConnectionStatus
    type Trend = Cepaf.Cockpit.Domain.Trend
    type SmartMetric = Cepaf.Cockpit.Domain.SmartMetric
    type MeshNode = Cepaf.Cockpit.Domain.MeshNode
    type AiInsight = Cepaf.Cockpit.Domain.AiInsight

    /// WebUI-specific page enumeration
    type Page =
        | Dashboard
        | Alarms
        | Guardian
        | Sentinel
        | TestEvolution
        | Video
        | AccessControl
        | Analytics
        | Compliance
        | Copilot
        | Register
        | Devices
        | Settings
        | Singularity

    /// Connection state for SignalR/Zenoh
    type WebConnectionState =
        | Connecting
        | Connected
        | Reconnecting
        | Disconnected
        | Error of string

    /// System health summary for dashboard
    type SystemHealthSummary = {
        OverallHealth: float
        HealthTrend: Trend
        ActiveAlarms: int
        CriticalAlarms: int
        ConnectedNodes: int
        TotalNodes: int
        PendingProposals: int
        ThreatLevel: AlarmLevel
        LastUpdate: DateTime
        ConnectionState: WebConnectionState
    }

    /// Guardian proposal for approval workflow
    type GuardianProposal = {
        Id: string
        Title: string
        Description: string
        Category: string
        Severity: AlarmLevel
        ProposedBy: string
        ProposedAt: DateTime
        RequiresApproval: bool
        Votes: int
        RequiredVotes: int
    }

    /// Sentinel threat for security monitoring
    type SentinelThreat = {
        Id: string
        Category: string
        Severity: AlarmLevel
        Description: string
        Source: string
        DetectedAt: DateTime
        Mitigated: bool
        MitigatedAt: DateTime option
    }

    /// Create initial health summary
    let emptyHealthSummary = {
        OverallHealth = 100.0
        HealthTrend = Trend.Stable
        ActiveAlarms = 0
        CriticalAlarms = 0
        ConnectedNodes = 0
        TotalNodes = 0
        PendingProposals = 0
        ThreatLevel = AlarmLevel.Normal
        LastUpdate = DateTime.UtcNow
        ConnectionState = Disconnected
    }

    /// Command record for audit/replay
    type CommandRecord = {
        Id: string
        Command: string
        ExecutedAt: DateTime
        ExecutedBy: string
        Status: string
    }

    /// Singularity coverage state
    type SingularityModel = {
        Coverage: float
        ActiveVectors: int
        LastUpdate: DateTime
    }
