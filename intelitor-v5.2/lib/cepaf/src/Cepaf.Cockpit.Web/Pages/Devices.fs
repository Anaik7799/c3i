namespace Cepaf.Cockpit.Web.Pages

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Web.Domain
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain.Messages
open Cepaf.Cockpit.Domain

/// =============================================================================
/// PRAJNA C3I - Devices Page
/// =============================================================================
/// Device/node status grid with health visualization.
/// STAMP: SC-HMI-001 (MVU), SC-MESH-004 (Zenoh telemetry)
/// Standards: IEC 61850 (Device communication), EN 50131
/// =============================================================================

module Devices =

    /// Simplified device info for UI display
    type DeviceInfo = {
        Id: string
        Name: string
        Status: ConnectionStatus
        Health: float
        LastSeen: DateTime
        Metrics: Map<string, SmartMetric>
    }

    type DevicesModel = {
        ViewMode: ViewMode
        SelectedNode: DeviceInfo option
        FilterStatus: ConnectionStatus option
        SearchQuery: string
        SortBy: SortField
    }

    and ViewMode =
        | GridView
        | ListView
        | TopologyView

    and SortField =
        | ByName
        | ByStatus
        | ByHealth
        | ByLastSeen

    type DevicesMsg =
        | SetViewMode of ViewMode
        | SelectNode of DeviceInfo option
        | FilterByStatus of ConnectionStatus option
        | SetSearchQuery of string
        | SetSortBy of SortField
        | RefreshNode of string

    let init () =
        {
            ViewMode = GridView
            SelectedNode = None
            FilterStatus = None
            SearchQuery = ""
            SortBy = ByHealth
        }

    let update (msg: DevicesMsg) (model: DevicesModel) =
        match msg with
        | SetViewMode mode ->
            { model with ViewMode = mode }
        | SelectNode node ->
            { model with SelectedNode = node }
        | FilterByStatus status ->
            { model with FilterStatus = status }
        | SetSearchQuery query ->
            { model with SearchQuery = query }
        | SetSortBy field ->
            { model with SortBy = field }
        | RefreshNode _ ->
            model

    /// Get mock nodes for UI display
    let private getMockNodes () : DeviceInfo list =
        [
            { Id = "node-1"; Name = "indrajaal-ex-app-1"; Status = ConnectionStatus.Connected; Health = 95.0; LastSeen = DateTime.UtcNow; Metrics = Map.empty }
            { Id = "node-2"; Name = "indrajaal-ex-app-2"; Status = ConnectionStatus.Connected; Health = 92.0; LastSeen = DateTime.UtcNow.AddSeconds(-10.0); Metrics = Map.empty }
            { Id = "node-3"; Name = "indrajaal-db-prod"; Status = ConnectionStatus.Connected; Health = 98.0; LastSeen = DateTime.UtcNow.AddSeconds(-5.0); Metrics = Map.empty }
            { Id = "node-4"; Name = "indrajaal-obs-prod"; Status = ConnectionStatus.Connected; Health = 88.0; LastSeen = DateTime.UtcNow.AddSeconds(-15.0); Metrics = Map.empty }
            { Id = "node-5"; Name = "zenoh-router-1"; Status = ConnectionStatus.Connected; Health = 100.0; LastSeen = DateTime.UtcNow.AddSeconds(-2.0); Metrics = Map.empty }
            { Id = "node-6"; Name = "backup-node-1"; Status = ConnectionStatus.Disconnected; Health = 0.0; LastSeen = DateTime.UtcNow.AddMinutes(-30.0); Metrics = Map.empty }
        ]

    /// Filter and sort nodes
    let private processNodes (nodes: DeviceInfo list) (model: DevicesModel) =
        nodes
        |> List.filter (fun n ->
            match model.FilterStatus with
            | None -> true
            | Some status -> n.Status = status
        )
        |> List.filter (fun n ->
            if String.IsNullOrWhiteSpace(model.SearchQuery) then true
            else
                n.Name.Contains(model.SearchQuery, StringComparison.OrdinalIgnoreCase) ||
                n.Id.Contains(model.SearchQuery, StringComparison.OrdinalIgnoreCase)
        )
        |> List.sortWith (fun a b ->
            match model.SortBy with
            | ByName -> compare a.Name b.Name
            | ByStatus -> compare a.Status b.Status
            | ByHealth -> compare b.Health a.Health
            | ByLastSeen -> compare b.LastSeen a.LastSeen
        )

    /// Get device statistics
    let private getStatistics (nodes: DeviceInfo list) =
        [
            ("Total Nodes", nodes.Length)
            ("Connected", nodes |> List.filter (fun n -> n.Status = ConnectionStatus.Connected) |> List.length)
            ("Disconnected", nodes |> List.filter (fun n -> n.Status = ConnectionStatus.Disconnected) |> List.length)
            ("Healthy (>90%)", nodes |> List.filter (fun n -> n.Health >= 90.0) |> List.length)
        ]

    /// Render statistics bar
    let private renderStatistics (stats: (string * int) list) =
        div {
            attr.``class`` "devices-statistics"
            forEach stats <| fun (label, count) ->
                div {
                    attr.``class`` "stat-card"
                    div {
                        attr.``class`` "stat-label"
                        text label
                    }
                    div {
                        attr.``class`` "stat-value"
                        text (string count)
                    }
                }
        }

    /// Render view mode selector
    let private renderViewModeSelector (currentMode: ViewMode) dispatch =
        div {
            attr.``class`` "view-mode-selector"
            button {
                attr.``class`` (if currentMode = GridView then "mode-btn active" else "mode-btn")
                on.click (fun _ -> dispatch (SetViewMode GridView))
                attr.title "Grid View"
                text "⊞"
            }

            button {
                attr.``class`` (if currentMode = ListView then "mode-btn active" else "mode-btn")
                on.click (fun _ -> dispatch (SetViewMode ListView))
                attr.title "List View"
                text "☰"
            }

            button {
                attr.``class`` (if currentMode = TopologyView then "mode-btn active" else "mode-btn")
                on.click (fun _ -> dispatch (SetViewMode TopologyView))
                attr.title "Topology View"
                text "◇"
            }
        }

    /// Render filter controls
    let private renderFilters (model: DevicesModel) dispatch =
        div {
            attr.``class`` "devices-filters"
            div {
                attr.``class`` "filter-group"
                input {
                    attr.``type`` "text"
                    attr.placeholder "Search devices..."
                    attr.value model.SearchQuery
                    on.input (fun e -> dispatch (SetSearchQuery (e.Value :?> string)))
                }
            }

            div {
                attr.``class`` "filter-group"
                label { text "Status:" }
                select {
                    on.change (fun e ->
                        let status =
                            match e.Value :?> string with
                            | "All" -> None
                            | "Connected" -> Some ConnectionStatus.Connected
                            | "Disconnected" -> Some ConnectionStatus.Disconnected
                            | "Stale" -> Some ConnectionStatus.Stale
                            | _ -> None
                        dispatch (FilterByStatus status)
                    )
                    option { attr.value "All"; text "All" }
                    option { attr.value "Connected"; text "Connected" }
                    option { attr.value "Disconnected"; text "Disconnected" }
                    option { attr.value "Stale"; text "Stale" }
                }
            }

            div {
                attr.``class`` "filter-group"
                label { text "Sort by:" }
                select {
                    on.change (fun e ->
                        let field =
                            match e.Value :?> string with
                            | "Name" -> ByName
                            | "Status" -> ByStatus
                            | "Health" -> ByHealth
                            | "LastSeen" -> ByLastSeen
                            | _ -> ByName
                        dispatch (SetSortBy field)
                    )
                    option { attr.value "Health"; attr.selected true; text "Health" }
                    option { attr.value "Name"; text "Name" }
                    option { attr.value "Status"; text "Status" }
                    option { attr.value "LastSeen"; text "Last Seen" }
                }
            }
        }

    /// Render single device card (grid view)
    let private renderDeviceCard (node: DeviceInfo) dispatch =
        div {
            attr.``class`` (sprintf "device-card %s"
                (match node.Status with
                 | ConnectionStatus.Connected -> "status-connected"
                 | ConnectionStatus.Disconnected -> "status-disconnected"
                 | ConnectionStatus.Stale -> "status-reconnecting"
                 | _ -> "status-unknown"))
            on.click (fun _ -> dispatch (SelectNode (Some node)))
            div {
                attr.``class`` "device-header"
                span {
                    attr.``class`` "device-status-indicator"
                    text (match node.Status with
                          | ConnectionStatus.Connected -> "●"
                          | ConnectionStatus.Disconnected -> "○"
                          | ConnectionStatus.Stale -> "◐"
                          | _ -> "?")
                }
                span {
                    attr.``class`` "device-name"
                    text node.Name
                }
            }

            div {
                attr.``class`` "device-health"
                div {
                    attr.``class`` "health-label"
                    text "Health"
                }
                div {
                    attr.``class`` "health-gauge"
                    div {
                        attr.``class`` (
                            if node.Health >= 90.0 then "gauge-excellent"
                            elif node.Health >= 70.0 then "gauge-good"
                            elif node.Health >= 50.0 then "gauge-warning"
                            else "gauge-critical"
                        )
                        attr.style (sprintf "width: %.0f%%" node.Health)
                    }
                }
                div {
                    attr.``class`` "health-value"
                    text (sprintf "%.0f%%" node.Health)
                }
            }

            div {
                attr.``class`` "device-footer"
                span {
                    attr.``class`` "last-seen"
                    let elapsed = DateTime.UtcNow - node.LastSeen
                    text (
                        if elapsed.TotalSeconds < 60.0 then
                            sprintf "%.0fs ago" elapsed.TotalSeconds
                        elif elapsed.TotalMinutes < 60.0 then
                            sprintf "%.0fm ago" elapsed.TotalMinutes
                        else
                            sprintf "%.0fh ago" elapsed.TotalHours
                    )
                }
            }
        }

    /// Render device row (list view)
    let private renderDeviceRow (node: DeviceInfo) dispatch =
        div {
            attr.``class`` (sprintf "device-row %s"
                (match node.Status with
                 | ConnectionStatus.Connected -> "status-connected"
                 | ConnectionStatus.Disconnected -> "status-disconnected"
                 | ConnectionStatus.Stale -> "status-reconnecting"
                 | _ -> "status-unknown"))
            on.click (fun _ -> dispatch (SelectNode (Some node)))
            span {
                attr.``class`` "device-status-col"
                text (match node.Status with
                      | ConnectionStatus.Connected -> "● Connected"
                      | ConnectionStatus.Disconnected -> "○ Disconnected"
                      | ConnectionStatus.Stale -> "◐ Stale"
                      | _ -> "? Unknown")
            }
            span {
                attr.``class`` "device-name-col"
                text node.Name
            }
            span {
                attr.``class`` "device-health-col"
                text (sprintf "%.0f%%" node.Health)
            }
            span {
                attr.``class`` "device-lastseen-col"
                text (node.LastSeen.ToString("HH:mm:ss"))
            }
        }

    /// Render device details panel
    let private renderDeviceDetails (node: DeviceInfo) dispatch =
        div {
            attr.``class`` "device-details"
            div {
                attr.``class`` "details-header"
                h2 { text node.Name }
                button {
                    attr.``class`` "btn-close"
                    on.click (fun _ -> dispatch (SelectNode None))
                    text "✕"
                }
            }

            div {
                attr.``class`` "details-body"
                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "ID:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text node.Id
                    }
                }

                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Status:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text (string node.Status)
                    }
                }

                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Health:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text (sprintf "%.1f%%" node.Health)
                    }
                }

                div {
                    attr.``class`` "detail-row"
                    span {
                        attr.``class`` "detail-label"
                        text "Last Seen:"
                    }
                    span {
                        attr.``class`` "detail-value"
                        text (node.LastSeen.ToString("yyyy-MM-dd HH:mm:ss"))
                    }
                }

                div {
                    attr.``class`` "detail-section"
                    h3 { text "Metrics" }
                    cond (node.Metrics.IsEmpty) <| function
                    | true ->
                        p { text "No metrics available" }
                    | false ->
                        div {
                            attr.``class`` "metrics-list"
                            forEach (node.Metrics |> Map.toList) <| fun (key, metric) ->
                                div {
                                    attr.``class`` "metric-row"
                                    span {
                                        attr.``class`` "metric-name"
                                        text metric.Label
                                    }
                                    span {
                                        attr.``class`` "metric-value"
                                        text (sprintf "%.2f" metric.Value)
                                    }
                                }
                        }
                }
            }

            div {
                attr.``class`` "details-actions"
                button {
                    attr.``class`` "btn-refresh"
                    on.click (fun _ -> dispatch (RefreshNode node.Id))
                    text "Refresh"
                }
            }
        }

    /// Main view
    let view (appModel: Model.AppModel) (localModel: DevicesModel) (localDispatch: DevicesMsg -> unit) =
        let nodes = getMockNodes ()
        let filteredNodes = processNodes nodes localModel
        let stats = getStatistics nodes

        div {
            attr.``class`` "page-devices"
            div {
                attr.``class`` "page-header"
                h1 { text "Device Status" }
                div {
                    attr.``class`` "page-controls"
                    renderViewModeSelector localModel.ViewMode localDispatch
                }
            }

            renderStatistics stats
            renderFilters localModel localDispatch

            div {
                attr.``class`` "devices-content"
                div {
                    attr.``class`` "devices-display"
                    match localModel.ViewMode with
                    | GridView ->
                        div {
                            attr.``class`` "devices-grid"
                            forEach filteredNodes <| fun node ->
                                renderDeviceCard node localDispatch
                        }
                    | ListView ->
                        div {
                            attr.``class`` "devices-list"
                            div {
                                attr.``class`` "list-header"
                                span { text "Status" }
                                span { text "Name" }
                                span { text "Health" }
                                span { text "Last Seen" }
                            }
                            forEach filteredNodes <| fun node ->
                                renderDeviceRow node localDispatch
                        }
                    | TopologyView ->
                        div {
                            attr.``class`` "topology-view"
                            p { text "Topology visualization would be rendered here" }
                        }
                }

                div {
                    attr.``class`` "device-detail-panel"
                    cond localModel.SelectedNode <| function
                    | Some node ->
                        renderDeviceDetails node localDispatch
                    | None ->
                        div {
                            attr.``class`` "no-selection"
                            text "← Select a device to view details"
                        }
                }
            }
        }

type DevicesComponent() =
    inherit ElmishComponent<Model.AppModel, Message>()

    let mutable localModel = Devices.init ()

    let localDispatch (msg: Devices.DevicesMsg) =
        localModel <- Devices.update msg localModel

    override this.View model dispatch =
        Devices.view model localModel localDispatch
