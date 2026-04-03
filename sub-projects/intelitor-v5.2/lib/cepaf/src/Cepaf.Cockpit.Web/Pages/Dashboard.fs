namespace Cepaf.Cockpit.Web.Pages

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// PRAJNA C3I - Dashboard Page
/// =============================================================================
/// STAMP: SC-HMI-001 (MVU), SC-COCKPIT-003 (< 50ms response)
/// =============================================================================

module Dashboard =

    type DashboardModel = {
        RefreshInterval: int
        LastRefresh: DateTime
        ExpandedSections: Set<string>
    }

    type DashboardMsg =
        | RefreshData
        | ToggleSection of string
        | UpdateInterval of int

    let init () = {
        RefreshInterval = 1000
        LastRefresh = DateTime.UtcNow
        ExpandedSections = Set.ofList ["health"; "alarms"; "guardian"]
    }

    let update (msg: DashboardMsg) (model: DashboardModel) =
        match msg with
        | RefreshData -> { model with LastRefresh = DateTime.UtcNow }
        | ToggleSection section ->
            let sections =
                if model.ExpandedSections.Contains(section) then model.ExpandedSections.Remove(section)
                else model.ExpandedSections.Add(section)
            { model with ExpandedSections = sections }
        | UpdateInterval interval -> { model with RefreshInterval = interval }

    let private getTrendIcon (trend: Trend) =
        match trend with
        | Rising | RisingFast -> "trend-up"
        | Falling | FallingFast -> "trend-down"
        | Stable -> "trend-stable"

    let private renderHealthSection (health: SystemHealthSummary) (isExpanded: bool) localDispatch =
        let healthClass =
            if health.OverallHealth >= 90.0 then "gauge-excellent"
            elif health.OverallHealth >= 70.0 then "gauge-good"
            elif health.OverallHealth >= 50.0 then "gauge-warning"
            else "gauge-critical"

        div {
            attr.``class`` "dashboard-section health-section"
            div {
                attr.``class`` "section-header"
                on.click (fun _ -> localDispatch (ToggleSection "health"))
                h2 { text "System Health" }
                span {
                    attr.``class`` "health-score"
                    text (sprintf "%.1f%%" health.OverallHealth)
                }
                span {
                    attr.``class`` (if isExpanded then "icon-expanded" else "icon-collapsed")
                    text (if isExpanded then "v" else ">")
                }
            }
            if isExpanded then
                div {
                    attr.``class`` "section-content"
                    div {
                        attr.``class`` "metrics-grid"
                        div {
                            attr.``class`` "metric-card"
                            div {
                                attr.``class`` "metric-label"
                                text "Overall Health"
                            }
                            div {
                                attr.``class`` "metric-value health-gauge"
                                div {
                                    attr.``class`` healthClass
                                    attr.style (sprintf "width: %.1f%%" health.OverallHealth)
                                }
                            }
                        }
                        div {
                            attr.``class`` "metric-card"
                            div {
                                attr.``class`` "metric-label"
                                text "Connected Nodes"
                            }
                            div {
                                attr.``class`` "metric-value"
                                text (sprintf "%d / %d" health.ConnectedNodes health.TotalNodes)
                            }
                        }
                        div {
                            attr.``class`` "metric-card"
                            div {
                                attr.``class`` "metric-label"
                                text "Trend"
                            }
                            div {
                                attr.``class`` "metric-value"
                                span {
                                    attr.``class`` (getTrendIcon health.HealthTrend)
                                    text health.HealthTrend.Icon
                                }
                            }
                        }
                    }
                }
        }

    let private renderAlarmsSection (alarms: Alarm list) (isExpanded: bool) localDispatch dispatch =
        let criticalCount = alarms |> List.filter (fun a -> a.Level = AlarmLevel.Critical) |> List.length
        let warningCount = alarms |> List.filter (fun a -> a.Level = AlarmLevel.Warning) |> List.length

        div {
            attr.``class`` "dashboard-section alarms-section"
            div {
                attr.``class`` "section-header"
                on.click (fun _ -> localDispatch (ToggleSection "alarms"))
                h2 { text "Active Alarms" }
                span {
                    attr.``class`` "alarm-counts"
                    if criticalCount > 0 then
                        span {
                            attr.``class`` "critical-count"
                            text (sprintf "%d Critical" criticalCount)
                        }
                    if warningCount > 0 then
                        span {
                            attr.``class`` "warning-count"
                            text (sprintf "%d Warning" warningCount)
                        }
                }
                span {
                    attr.``class`` (if isExpanded then "icon-expanded" else "icon-collapsed")
                    text (if isExpanded then "v" else ">")
                }
            }
            if isExpanded then
                div {
                    attr.``class`` "section-content"
                    if List.isEmpty alarms then
                        div {
                            attr.``class`` "no-alarms"
                            text "No active alarms"
                        }
                    else
                        forEach (alarms |> List.take (min 5 (List.length alarms))) (fun alarm ->
                            div {
                                attr.``class`` "alarm-item"
                                on.click (fun _ -> dispatch (SelectAlarm (Some alarm.Id)))
                                span {
                                    attr.``class`` (sprintf "alarm-level %s" (alarm.Level.Abbrev.ToLower()))
                                    text alarm.Level.Icon
                                }
                                span {
                                    attr.``class`` "alarm-message"
                                    text alarm.Message
                                }
                                span {
                                    attr.``class`` "alarm-time"
                                    text (alarm.OccurredAt.ToString("HH:mm:ss"))
                                }
                            }
                        )
                        if List.length alarms > 5 then
                            button {
                                attr.``class`` "view-all-btn"
                                on.click (fun _ -> dispatch (NavigateTo Page.Alarms))
                                text (sprintf "View all %d alarms" (List.length alarms))
                            }
                }
        }

    let private renderGuardianSection (proposals: GuardianProposal list) (isExpanded: bool) localDispatch dispatch =
        div {
            attr.``class`` "dashboard-section guardian-section"
            div {
                attr.``class`` "section-header"
                on.click (fun _ -> localDispatch (ToggleSection "guardian"))
                h2 { text "Guardian Proposals" }
                span {
                    attr.``class`` "proposal-count"
                    text (sprintf "%d pending" (List.length proposals))
                }
                span {
                    attr.``class`` (if isExpanded then "icon-expanded" else "icon-collapsed")
                    text (if isExpanded then "v" else ">")
                }
            }
            if isExpanded then
                div {
                    attr.``class`` "section-content"
                    if List.isEmpty proposals then
                        div {
                            attr.``class`` "no-proposals"
                            text "No pending proposals"
                        }
                    else
                        forEach proposals (fun proposal ->
                            div {
                                attr.``class`` "proposal-item"
                                span {
                                    attr.``class`` "proposal-title"
                                    text proposal.Title
                                }
                                span {
                                    attr.``class`` "proposal-votes"
                                    text (sprintf "%d/%d votes" proposal.Votes proposal.RequiredVotes)
                                }
                                div {
                                    attr.``class`` "proposal-actions"
                                    button {
                                        attr.``class`` "approve-btn"
                                        on.click (fun _ -> dispatch (ApproveProposal proposal.Id))
                                        text "Approve"
                                    }
                                    button {
                                        attr.``class`` "veto-btn"
                                        on.click (fun _ -> dispatch (VetoProposal (proposal.Id, "Vetoed from dashboard")))
                                        text "Veto"
                                    }
                                }
                            }
                        )
                }
        }

    let view (appModel: Model.AppModel) (localModel: DashboardModel) (localDispatch: DashboardMsg -> unit) (dispatch: Message -> unit) =
        div {
            attr.``class`` "page-dashboard"
            div {
                attr.``class`` "page-header"
                h1 { text "Dashboard" }
                div {
                    attr.``class`` "page-meta"
                    text (sprintf "Last updated: %s" (localModel.LastRefresh.ToString("HH:mm:ss")))
                }
            }
            div {
                attr.``class`` "dashboard-grid"
                renderHealthSection appModel.Health (localModel.ExpandedSections.Contains "health") localDispatch
                renderAlarmsSection appModel.Alarms (localModel.ExpandedSections.Contains "alarms") localDispatch dispatch
                renderGuardianSection appModel.Proposals (localModel.ExpandedSections.Contains "guardian") localDispatch dispatch
            }
        }

type DashboardComponent() =
    inherit ElmishComponent<Model.AppModel, Message>()

    let mutable localModel = Dashboard.init ()

    let localDispatch (msg: Dashboard.DashboardMsg) =
        localModel <- Dashboard.update msg localModel

    override this.View model dispatch =
        Dashboard.view model localModel localDispatch dispatch
