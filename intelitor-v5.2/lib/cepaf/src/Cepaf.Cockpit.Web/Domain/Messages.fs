namespace Cepaf.Cockpit.Web.Domain

open System
open Cepaf.Cockpit.Web.Domain.Types

/// =============================================================================
/// PRAJNA C3I WebUI - Elmish Messages
/// =============================================================================
/// MVU (Model-View-Update) messages for the Bolero application.
/// STAMP: SC-HMI-001 (MVU architecture for predictable state)
/// =============================================================================

module Messages =

    /// All application messages (Elmish union type)
    type Message =
        // Navigation
        | NavigateTo of Page
        | ToggleNavigation

        // Connection Management
        | Connect
        | Disconnect
        | ConnectionStateChanged of WebConnectionState
        | ConnectionError of string

        // Health Updates (from SignalR/Zenoh)
        | HealthUpdated of SystemHealthSummary
        | MetricUpdated of string * float
        | NodeStatusChanged of string * Cepaf.Cockpit.Domain.ConnectionStatus

        // Alarms
        | AlarmsReceived of Cepaf.Cockpit.Domain.Alarm list
        | AlarmAdded of Cepaf.Cockpit.Domain.Alarm
        | AlarmAcknowledged of string
        | AlarmCleared of string
        | FilterAlarms of Cepaf.Cockpit.Domain.AlarmLevel option
        | SelectAlarm of string option

        // Guardian
        | ProposalsReceived of GuardianProposal list
        | ProposalAdded of GuardianProposal
        | ApproveProposal of string
        | VetoProposal of string * string  // id, reason
        | ProposalApproved of string
        | ProposalVetoed of string

        // Sentinel
        | ThreatsReceived of SentinelThreat list
        | ThreatDetected of SentinelThreat
        | ThreatMitigated of string
        | MitigateThreat of string

        // AI Copilot
        | SendCopilotMessage of string
        | CopilotResponseReceived of string
        | ClearCopilotHistory

        // Settings
        | SetTheme of string
        | SetRefreshRate of int
        | ToggleDarkCockpit

        // Error Handling
        | ErrorOccurred of string
        | ClearError

        // Tick (for periodic updates)
        | Tick of DateTime
