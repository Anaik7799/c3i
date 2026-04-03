namespace Cepaf.Cockpit.Web

open System
open Bolero
open Bolero.Html
open Bolero.Remoting.Client
open Elmish
open Microsoft.AspNetCore.Components
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain.Messages
open Cepaf.Cockpit.Web.Domain.Model
open Cepaf.Cockpit.Web.Pages

/// =============================================================================
/// PRAJNA C3I WebUI - Main Application
/// =============================================================================
/// Bolero (F# Blazor) application with Elmish MVU architecture.
/// STAMP: SC-COCKPIT-002 (WebUI MUST be F#), SC-HMI-001 (Dark Cockpit)
/// =============================================================================

module App =

    /// Router for page navigation
    let router = Router.infer NavigateTo (fun m -> m.CurrentPage)

    /// View for navigation rail
    let navRail (model: AppModel) dispatch =
        nav {
            attr.``class`` "nav-rail"
            div {
                attr.``class`` "nav-logo"
                span {
                    attr.``class`` "logo-text"
                    text "PRAJNA"
                }
            }
            ul {
                attr.``class`` "nav-items"
                li {
                    attr.``class`` (if model.CurrentPage = Dashboard then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Dashboard))
                    text "Dashboard"
                }
                li {
                    attr.``class`` (if model.CurrentPage = Alarms then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Alarms))
                    text "Alarms"
                    if criticalAlarmCount model > 0 then
                        span {
                            attr.``class`` "badge critical"
                            text (string (criticalAlarmCount model))
                        }
                }
                li {
                    attr.``class`` (if model.CurrentPage = Guardian then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Guardian))
                    text "Guardian"
                    if pendingProposalCount model > 0 then
                        span {
                            attr.``class`` "badge warning"
                            text (string (pendingProposalCount model))
                        }
                }
                li {
                    attr.``class`` (if model.CurrentPage = Sentinel then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Sentinel))
                    text "Sentinel"
                    if activeThreatCount model > 0 then
                        span {
                            attr.``class`` "badge critical"
                            text (string (activeThreatCount model))
                        }
                }
                li {
                    attr.``class`` (if model.CurrentPage = Devices then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Devices))
                    text "Devices"
                }
                li {
                    attr.``class`` (if model.CurrentPage = Settings then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Settings))
                    text "Settings"
                }
                li {
                    attr.``class`` (if model.CurrentPage = Singularity then "active" else "")
                    on.click (fun _ -> dispatch (NavigateTo Singularity))
                    text "Singularity"
                }
            }
            div {
                attr.``class`` "nav-footer"
                div {
                    attr.``class`` "connection-status"
                    span {
                        attr.``class`` (
                            match model.ConnectionState with
                            | Connected -> "status-dot connected"
                            | Connecting | Reconnecting -> "status-dot connecting"
                            | _ -> "status-dot disconnected"
                        )
                    }
                    text (
                        match model.ConnectionState with
                        | Connected -> "Connected"
                        | Connecting -> "Connecting..."
                        | Reconnecting -> "Reconnecting..."
                        | Disconnected -> "Disconnected"
                        | Error e -> $"Error: {e}"
                    )
                }
            }
        }

    /// Dashboard page view
    let dashboardView (model: AppModel) dispatch =
        div {
            attr.``class`` "page dashboard"
            h1 { text "System Dashboard" }
            div {
                attr.``class`` "health-section"
                div {
                    attr.``class`` "health-gauge"
                    div {
                        attr.``class`` "gauge-value"
                        text (sprintf "%.0f%%" model.Health.OverallHealth)
                    }
                    div {
                        attr.``class`` "gauge-label"
                        text "System Health"
                    }
                }
                div {
                    attr.``class`` "health-stats"
                    div {
                        attr.``class`` "stat"
                        span {
                            attr.``class`` "stat-value"
                            text (string model.Health.ConnectedNodes)
                        }
                        span {
                            attr.``class`` "stat-label"
                            text "Nodes"
                        }
                    }
                    div {
                        attr.``class`` "stat"
                        span {
                            attr.``class`` "stat-value"
                            text (string model.Health.ActiveAlarms)
                        }
                        span {
                            attr.``class`` "stat-label"
                            text "Alarms"
                        }
                    }
                    div {
                        attr.``class`` "stat"
                        span {
                            attr.``class`` "stat-value"
                            text (string model.Health.PendingProposals)
                        }
                        span {
                            attr.``class`` "stat-label"
                            text "Proposals"
                        }
                    }
                }
            }
            div {
                attr.``class`` "quick-actions"
                h2 { text "Quick Status" }
                div {
                    attr.``class`` "status-grid"
                    forEach (model.Alarms |> List.take (min 5 model.Alarms.Length)) <| fun alarm ->
                        div {
                            attr.``class`` $"alarm-card {alarm.Level.ToString().ToLower()}"
                            span {
                                attr.``class`` "alarm-level"
                                text alarm.Level.Abbrev
                            }
                            span {
                                attr.``class`` "alarm-message"
                                text alarm.Message
                            }
                        }
                }
            }
        }

    /// Alarms page view
    let alarmsView (model: AppModel) dispatch =
        div {
            attr.``class`` "page alarms"
            h1 { text "Alarm Management" }
            div {
                attr.``class`` "alarm-filters"
                button {
                    attr.``class`` (if model.AlarmFilter.IsNone then "active" else "")
                    on.click (fun _ -> dispatch (FilterAlarms None))
                    text "All"
                }
                button {
                    attr.``class`` (if model.AlarmFilter = Some Cepaf.Cockpit.Domain.AlarmLevel.Critical then "active" else "")
                    on.click (fun _ -> dispatch (FilterAlarms (Some Cepaf.Cockpit.Domain.AlarmLevel.Critical)))
                    text "Critical"
                }
                button {
                    attr.``class`` (if model.AlarmFilter = Some Cepaf.Cockpit.Domain.AlarmLevel.Warning then "active" else "")
                    on.click (fun _ -> dispatch (FilterAlarms (Some Cepaf.Cockpit.Domain.AlarmLevel.Warning)))
                    text "Warning"
                }
            }
            div {
                attr.``class`` "alarm-list"
                forEach (filteredAlarms model) <| fun alarm ->
                    div {
                        attr.``class`` $"alarm-row {alarm.Level.ToString().ToLower()}"
                        on.click (fun _ -> dispatch (SelectAlarm (Some alarm.Id)))
                        span {
                            attr.``class`` "alarm-level"
                            text alarm.Level.Abbrev
                        }
                        span {
                            attr.``class`` "alarm-node"
                            text alarm.NodeId
                        }
                        span {
                            attr.``class`` "alarm-message"
                            text alarm.Message
                        }
                        span {
                            attr.``class`` "alarm-time"
                            text (alarm.OccurredAt.ToString("HH:mm:ss"))
                        }
                        if alarm.AcknowledgedAt.IsNone then
                            button {
                                attr.``class`` "btn-ack"
                                on.click (fun _ -> dispatch (AlarmAcknowledged alarm.Id))
                                text "ACK"
                            }
                    }
            }
        }

    /// Guardian page view
    let guardianView (model: AppModel) dispatch =
        div {
            attr.``class`` "page guardian"
            h1 { text "Guardian Safety Proposals" }
            div {
                attr.``class`` "proposal-list"
                forEach model.Proposals <| fun proposal ->
                    div {
                        attr.``class`` $"proposal-card {proposal.Severity.ToString().ToLower()}"
                        div {
                            attr.``class`` "proposal-header"
                            span {
                                attr.``class`` "proposal-title"
                                text proposal.Title
                            }
                            span {
                                attr.``class`` "proposal-category"
                                text proposal.Category
                            }
                        }
                        div {
                            attr.``class`` "proposal-body"
                            p { text proposal.Description }
                        }
                        div {
                            attr.``class`` "proposal-actions"
                            button {
                                attr.``class`` "btn-approve"
                                on.click (fun _ -> dispatch (ApproveProposal proposal.Id))
                                text "APPROVE"
                            }
                            button {
                                attr.``class`` "btn-veto"
                                on.click (fun _ -> dispatch (VetoProposal (proposal.Id, "Manual veto")))
                                text "VETO"
                            }
                        }
                        div {
                            attr.``class`` "proposal-votes"
                            text $"Votes: {proposal.Votes}/{proposal.RequiredVotes}"
                        }
                    }
            }
        }

    /// Sentinel page view
    let sentinelView (model: AppModel) dispatch =
        div {
            attr.``class`` "page sentinel"
            h1 { text "Sentinel Threat Monitor" }
            div {
                attr.``class`` "threat-list"
                forEach model.Threats <| fun threat ->
                    let cardClass = if threat.Mitigated then "mitigated" else threat.Severity.ToString().ToLower()
                    div {
                        attr.``class`` ("threat-card " + cardClass)
                        div {
                            attr.``class`` "threat-header"
                            span {
                                attr.``class`` "threat-category"
                                text threat.Category
                            }
                            span {
                                attr.``class`` "threat-severity"
                                text (threat.Severity.ToString())
                            }
                        }
                        div {
                            attr.``class`` "threat-body"
                            p { text threat.Description }
                            span {
                                attr.``class`` "threat-source"
                                text $"Source: {threat.Source}"
                            }
                        }
                        if not threat.Mitigated then
                            button {
                                attr.``class`` "btn-mitigate"
                                on.click (fun _ -> dispatch (MitigateThreat threat.Id))
                                text "MITIGATE"
                            }
                        else
                            span {
                                attr.``class`` "mitigated-badge"
                                text "MITIGATED"
                            }
                    }
            }
        }

    /// Devices page view
    let devicesView (model: AppModel) dispatch =
        div {
            attr.``class`` "page devices"
            h1 { text "Device Status" }
            div {
                attr.``class`` "device-grid"
                text "Device grid placeholder - implement with real device data"
            }
        }

    /// Settings page view
    let settingsView (model: AppModel) dispatch =
        div {
            attr.``class`` "page settings"
            h1 { text "Settings" }
            div {
                attr.``class`` "settings-section"
                h2 { text "Display" }
                div {
                    attr.``class`` "setting-row"
                    label { text "Dark Cockpit Mode" }
                    input {
                        attr.``type`` "checkbox"
                        attr.``checked`` model.DarkCockpitEnabled
                        on.change (fun _ -> dispatch ToggleDarkCockpit)
                    }
                }
                div {
                    attr.``class`` "setting-row"
                    label { text "Refresh Rate (ms)" }
                    input {
                        attr.``type`` "number"
                        attr.value (string model.RefreshRateMs)
                        on.change (fun e ->
                            match Int32.TryParse(e.Value.ToString()) with
                            | true, v -> dispatch (SetRefreshRate v)
                            | _ -> ()
                        )
                    }
                }
            }
        }

    /// Singularity page view
    let singularityView (model: AppModel) dispatch =
        div {
            attr.``class`` "page singularity"
            Singularity.view model.Singularity
        }

    /// Main view router
    let view (model: AppModel) dispatch =
        div {
            attr.``class`` $"app {model.Theme}"
            navRail model dispatch
            main {
                attr.``class`` "main-content"
                match model.CurrentPage with
                | Dashboard -> dashboardView model dispatch
                | Alarms -> alarmsView model dispatch
                | Guardian -> guardianView model dispatch
                | Sentinel -> sentinelView model dispatch
                | Devices -> devicesView model dispatch
                | Settings -> settingsView model dispatch
                | Singularity -> singularityView model dispatch
                | _ -> dashboardView model dispatch  // Fallback

                // Error banner
                match model.LastError with
                | Some error ->
                    div {
                        attr.``class`` "error-banner"
                        span { text error }
                        button {
                            on.click (fun _ -> dispatch ClearError)
                            text "×"
                        }
                    }
                | None -> empty ()
            }
        }

    /// Elmish program
    type PrajnaApp() =
        inherit ProgramComponent<AppModel, Message>()

        override this.Program =
            Program.mkSimple (fun _ -> init()) update view
