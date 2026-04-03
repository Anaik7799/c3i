namespace Cepaf.Cockpit.Web.Domain

open System
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// PRAJNA C3I WebUI - Application Model & Update Logic
/// =============================================================================
/// Elmish Model and Update functions for the Bolero application.
/// STAMP: SC-HMI-001 (MVU architecture), SC-COCKPIT-003 (< 50ms response)
/// =============================================================================

module Model =

    /// Application state model
    type AppModel = {
        // Navigation
        CurrentPage: Page
        IsNavExpanded: bool

        // Connection
        ConnectionState: WebConnectionState
        LastConnectionAttempt: DateTime option

        // Health & Metrics
        Health: SystemHealthSummary
        Metrics: Map<string, Cepaf.Cockpit.Domain.SmartMetric>

        // Alarms
        Alarms: Cepaf.Cockpit.Domain.Alarm list
        SelectedAlarmId: string option
        AlarmFilter: Cepaf.Cockpit.Domain.AlarmLevel option

        // Guardian
        Proposals: GuardianProposal list
        SelectedProposalId: string option

        // Sentinel
        Threats: SentinelThreat list

        // Copilot
        CopilotHistory: (string * string) list  // (user, assistant) pairs
        CopilotInput: string

        // Settings
        Theme: string
        RefreshRateMs: int
        DarkCockpitEnabled: bool

        // Singularity
        Singularity: SingularityModel

        // Error state
        LastError: string option
        LastErrorTime: DateTime option
    }

    /// Initial model
    let init () =
        {
            CurrentPage = Dashboard
            IsNavExpanded = true

            ConnectionState = Disconnected
            LastConnectionAttempt = None

            Health = emptyHealthSummary
            Metrics = Map.empty

            Alarms = []
            SelectedAlarmId = None
            AlarmFilter = None

            Proposals = []
            SelectedProposalId = None

            Threats = []

            CopilotHistory = []
            CopilotInput = ""
            Theme = "dark-cockpit"
            RefreshRateMs = 1000
            DarkCockpitEnabled = true

            Singularity = {
                Coverage = 100.0
                ActiveVectors = 1242
                LastUpdate = DateTime.UtcNow
            }

            LastError = None

            LastErrorTime = None
        }

    /// Update function (Elmish reducer)
    let update (message: Message) (model: AppModel) : AppModel =
        match message with
        // Navigation
        | NavigateTo page ->
            { model with CurrentPage = page }

        | ToggleNavigation ->
            { model with IsNavExpanded = not model.IsNavExpanded }

        // Connection
        | Connect ->
            { model with
                ConnectionState = Connecting
                LastConnectionAttempt = Some DateTime.UtcNow }

        | Disconnect ->
            { model with ConnectionState = Disconnected }

        | ConnectionStateChanged state ->
            { model with ConnectionState = state }

        | ConnectionError error ->
            { model with
                ConnectionState = Error error
                LastError = Some error
                LastErrorTime = Some DateTime.UtcNow }

        // Health Updates
        | HealthUpdated health ->
            { model with Health = health }

        | MetricUpdated (name, value) ->
            let updated =
                model.Metrics
                |> Map.change name (fun existing ->
                    match existing with
                    | Some m -> Some (Cepaf.Cockpit.Domain.updateMetric m value)
                    | None -> Some (Cepaf.Cockpit.Domain.SmartMetric.Create(name, "", value))
                )
            { model with Metrics = updated }

        | NodeStatusChanged (nodeId, status) ->
            // Update health if node disconnects
            let newHealth =
                if status = Cepaf.Cockpit.Domain.ConnectionStatus.Disconnected then
                    { model.Health with ConnectedNodes = max 0 (model.Health.ConnectedNodes - 1) }
                else
                    model.Health
            { model with Health = newHealth }

        // Alarms
        | AlarmsReceived alarms ->
            { model with Alarms = alarms }

        | AlarmAdded alarm ->
            { model with Alarms = alarm :: model.Alarms }

        | AlarmAcknowledged alarmId ->
            let alarms =
                model.Alarms
                |> List.map (fun a ->
                    if a.Id = alarmId then
                        { a with
                            AcknowledgedAt = Some DateTime.UtcNow
                            AcknowledgedBy = Some "System" }
                    else a
                )
            { model with Alarms = alarms }

        | AlarmCleared _ ->
            // Filter out the alarm or mark it (Shared Alarm record has no ResolvedAt field)
            model

        | FilterAlarms level ->
            { model with AlarmFilter = level }

        | SelectAlarm id ->
            { model with SelectedAlarmId = id }

        // Guardian
        | ProposalsReceived proposals ->
            { model with Proposals = proposals }

        | ProposalAdded proposal ->
            { model with Proposals = proposal :: model.Proposals }

        | ApproveProposal _ -> model // Triggers remoting
        | VetoProposal _ -> model // Triggers remoting
        | ProposalApproved id ->
            let proposals = model.Proposals |> List.filter (fun p -> p.Id <> id)
            { model with Proposals = proposals }
        | ProposalVetoed id ->
            let proposals = model.Proposals |> List.filter (fun p -> p.Id <> id)
            { model with Proposals = proposals }

        // Sentinel
        | ThreatsReceived threats ->
            { model with Threats = threats }

        | ThreatDetected threat ->
            { model with Threats = threat :: model.Threats }

        | ThreatMitigated id ->
            let threats =
                model.Threats
                |> List.map (fun t ->
                    if t.Id = id then { t with Mitigated = true; MitigatedAt = Some DateTime.UtcNow }
                    else t
                )
            { model with Threats = threats }

        | MitigateThreat _ -> model // Triggers remoting

        // Copilot
        | SendCopilotMessage msg ->
            let history = (msg, "Processing...") :: model.CopilotHistory
            { model with
                CopilotHistory = history
                CopilotInput = "" }

        | CopilotResponseReceived response ->
            match model.CopilotHistory with
            | (user, _) :: rest ->
                { model with CopilotHistory = (user, response) :: rest }
            | _ -> model

        | ClearCopilotHistory ->
            { model with CopilotHistory = [] }

        // Settings
        | SetTheme theme ->
            { model with Theme = theme }

        | SetRefreshRate rate ->
            { model with RefreshRateMs = rate }

        | ToggleDarkCockpit ->
            { model with DarkCockpitEnabled = not model.DarkCockpitEnabled }

        | Tick _ -> model

        | ErrorOccurred error ->
            { model with
                LastError = Some error
                LastErrorTime = Some DateTime.UtcNow }

        | ClearError ->
            { model with LastError = None; LastErrorTime = None }

    // Helpers
    let filteredAlarms (model: AppModel) =
        match model.AlarmFilter with
        | Some level -> model.Alarms |> List.filter (fun a -> a.Level = level)
        | None -> model.Alarms

    let activeAlarms (model: AppModel) =
        model.Alarms // (No resolved_at in shared Alarm record)

    let criticalAlarmCount (model: AppModel) =
        model.Alarms |> List.filter (fun a -> a.Level = AlarmLevel.Critical) |> List.length

    let pendingProposalCount (model: AppModel) =
        model.Proposals |> List.filter (fun p -> p.RequiresApproval) |> List.length

    let activeThreatCount (model: AppModel) =
        model.Threats |> List.filter (fun t -> not t.Mitigated) |> List.length
