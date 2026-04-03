namespace Cepaf.Cockpit.Web.Pages

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// PRAJNA C3I - Sentinel Page (Digital Immune System)
/// =============================================================================
/// STAMP: SC-IMMUNE-001 (Sentinel monitoring), SC-IMMUNE-004 (PatternHunter)
/// =============================================================================

module Sentinel =

    type SentinelFilter =
        | AllThreats
        | ActiveOnly
        | MitigatedOnly
        | BySeverity of AlarmLevel

    type SentinelModel = {
        Filter: SentinelFilter
        SelectedThreat: string option
    }

    type SentinelMsg =
        | SetFilter of SentinelFilter
        | SelectThreat of string option

    let init () = {
        Filter = ActiveOnly
        SelectedThreat = None
    }

    let update (msg: SentinelMsg) (model: SentinelModel) =
        match msg with
        | SetFilter filter -> { model with Filter = filter }
        | SelectThreat id -> { model with SelectedThreat = id }

    let private getSeverityColor (severity: AlarmLevel) =
        match severity with
        | AlarmLevel.Critical -> "#dc2626"
        | AlarmLevel.Warning -> "#f59e0b"
        | AlarmLevel.Caution -> "#fbbf24"
        | AlarmLevel.Advisory -> "#06b6d4"
        | AlarmLevel.Normal -> "#6b7280"

    let private filterThreats (filter: SentinelFilter) (threats: SentinelThreat list) =
        match filter with
        | AllThreats -> threats
        | ActiveOnly -> threats |> List.filter (fun t -> not t.Mitigated)
        | MitigatedOnly -> threats |> List.filter (fun t -> t.Mitigated)
        | BySeverity level -> threats |> List.filter (fun t -> t.Severity = level)

    let private renderThreatCard (threat: SentinelThreat) (isSelected: bool) (localDispatch: SentinelMsg -> unit) (dispatch: Message -> unit) =
        let severityColor = getSeverityColor threat.Severity
        let cardClass = if isSelected then "threat-card selected" else "threat-card"
        let mitigatedStyle = if threat.Mitigated then "opacity: 0.6;" else ""

        div {
            attr.``class`` cardClass
            attr.style (sprintf "border-left: 4px solid %s; %s" severityColor mitigatedStyle)
            on.click (fun _ -> localDispatch (SelectThreat (Some threat.Id)))
            div {
                attr.``class`` "threat-header"
                span {
                    attr.``class`` "threat-severity"
                    attr.style (sprintf "color: %s;" severityColor)
                    text (sprintf "%s" threat.Severity.Abbrev)
                }
                span {
                    attr.``class`` "threat-category"
                    text threat.Category
                }
                if threat.Mitigated then
                    span {
                        attr.``class`` "threat-status mitigated"
                        text "MITIGATED"
                    }
                else
                    span {
                        attr.``class`` "threat-status active"
                        text "ACTIVE"
                    }
            }
            div {
                attr.``class`` "threat-description"
                text threat.Description
            }
            div {
                attr.``class`` "threat-meta"
                span {
                    attr.``class`` "threat-source"
                    text (sprintf "Source: %s" threat.Source)
                }
                span {
                    attr.``class`` "threat-time"
                    text (threat.DetectedAt.ToString("yyyy-MM-dd HH:mm:ss"))
                }
            }
            if not threat.Mitigated then
                div {
                    attr.``class`` "threat-actions"
                    button {
                        attr.``class`` "btn-mitigate"
                        on.click (fun _ -> dispatch (MitigateThreat threat.Id))
                        text "Mitigate"
                    }
                    button {
                        attr.``class`` "btn-investigate"
                        on.click (fun _ -> localDispatch (SelectThreat (Some threat.Id)))
                        text "Investigate"
                    }
                }
        }

    let private renderThreatDetails (threat: SentinelThreat) (localDispatch: SentinelMsg -> unit) =
        div {
            attr.``class`` "threat-details-panel"
            div {
                attr.``class`` "panel-header"
                h3 { text "Threat Details" }
                button {
                    attr.``class`` "btn-close"
                    on.click (fun _ -> localDispatch (SelectThreat None))
                    text "X"
                }
            }
            div {
                attr.``class`` "panel-content"
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "ID:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text threat.Id
                    }
                }
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Category:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text threat.Category
                    }
                }
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Severity:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        attr.style (sprintf "color: %s;" (getSeverityColor threat.Severity))
                        text threat.Severity.Abbrev
                    }
                }
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Source:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text threat.Source
                    }
                }
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Detected:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text (threat.DetectedAt.ToString("yyyy-MM-dd HH:mm:ss"))
                    }
                }
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Description:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text threat.Description
                    }
                }
                match threat.MitigatedAt with
                | Some mitigatedAt ->
                    div {
                        attr.``class`` "detail-row"
                        span {
                            attr.``class`` "detail-label"
                            text "Mitigated:"
                        }
                        span {
                            attr.``class`` "detail-value"
                            text (mitigatedAt.ToString("yyyy-MM-dd HH:mm:ss"))
                        }
                    }
                | None -> empty ()
            }
        }

    let private renderFilterButtons (currentFilter: SentinelFilter) (localDispatch: SentinelMsg -> unit) =
        div {
            attr.``class`` "filter-buttons"
            button {
                attr.``class`` (if currentFilter = AllThreats then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter AllThreats))
                text "All"
            }
            button {
                attr.``class`` (if currentFilter = ActiveOnly then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter ActiveOnly))
                text "Active"
            }
            button {
                attr.``class`` (if currentFilter = MitigatedOnly then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter MitigatedOnly))
                text "Mitigated"
            }
        }

    let view (appModel: Model.AppModel) (localModel: SentinelModel) (localDispatch: SentinelMsg -> unit) (dispatch: Message -> unit) =
        let filteredThreats = filterThreats localModel.Filter appModel.Threats

        let activeCount = appModel.Threats |> List.filter (fun t -> not t.Mitigated) |> List.length
        let criticalCount = appModel.Threats |> List.filter (fun t -> t.Severity = AlarmLevel.Critical && not t.Mitigated) |> List.length

        div {
            attr.``class`` "page-sentinel"
            div {
                attr.``class`` "page-header"
                h1 { text "Sentinel - Digital Immune System" }
                div {
                    attr.``class`` "sentinel-summary"
                    span {
                        attr.``class`` "summary-item active"
                        text (sprintf "%d Active Threats" activeCount)
                    }
                    if criticalCount > 0 then
                        span {
                            attr.``class`` "summary-item critical"
                            text (sprintf "%d Critical" criticalCount)
                        }
                }
            }

            div {
                attr.``class`` "sentinel-toolbar"
                renderFilterButtons localModel.Filter localDispatch
            }

            div {
                attr.``class`` "sentinel-content"
                div {
                    attr.``class`` "threats-grid"
                    if List.isEmpty filteredThreats then
                        div {
                            attr.``class`` "no-threats"
                            text "No threats match the current filter"
                        }
                    else
                        forEach filteredThreats (fun threat ->
                            let isSelected = localModel.SelectedThreat = Some threat.Id
                            renderThreatCard threat isSelected localDispatch dispatch
                        )
                }

                match localModel.SelectedThreat with
                | Some threatId ->
                    match appModel.Threats |> List.tryFind (fun t -> t.Id = threatId) with
                    | Some threat -> renderThreatDetails threat localDispatch
                    | None -> empty ()
                | None -> empty ()
            }
        }

type SentinelComponent() =
    inherit ElmishComponent<Model.AppModel, Message>()

    let mutable localModel = Sentinel.init ()

    let localDispatch (msg: Sentinel.SentinelMsg) =
        localModel <- Sentinel.update msg localModel

    override this.View model dispatch =
        Sentinel.view model localModel localDispatch dispatch
