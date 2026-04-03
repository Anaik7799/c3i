namespace Cepaf.Cockpit.Web.Pages

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// PRAJNA C3I - Alarms Page
/// =============================================================================
/// STAMP: SC-HMI-001 (MVU), SC-HMI-004 (Two-step commit)
/// =============================================================================

module Alarms =

    type AlarmsFilter =
        | AllAlarms
        | CriticalOnly
        | UnacknowledgedOnly
        | ByCategory of string

    type AlarmsModel = {
        Filter: AlarmsFilter
        SortBy: string
        SortAscending: bool
        SearchQuery: string
    }

    type AlarmsMsg =
        | SetFilter of AlarmsFilter
        | SetSort of string
        | ToggleSortDirection
        | SetSearch of string

    let init () = {
        Filter = AllAlarms
        SortBy = "time"
        SortAscending = false
        SearchQuery = ""
    }

    let update (msg: AlarmsMsg) (model: AlarmsModel) =
        match msg with
        | SetFilter filter -> { model with Filter = filter }
        | SetSort sortBy -> { model with SortBy = sortBy }
        | ToggleSortDirection -> { model with SortAscending = not model.SortAscending }
        | SetSearch query -> { model with SearchQuery = query }

    let private filterAlarms (filter: AlarmsFilter) (alarms: Alarm list) =
        match filter with
        | AllAlarms -> alarms
        | CriticalOnly -> alarms |> List.filter (fun a -> a.Level = AlarmLevel.Critical)
        | UnacknowledgedOnly -> alarms |> List.filter (fun a -> a.AcknowledgedAt.IsNone)
        | ByCategory cat -> alarms |> List.filter (fun a -> a.Category = cat)

    let private sortAlarms (sortBy: string) (ascending: bool) (alarms: Alarm list) =
        let sorted =
            match sortBy with
            | "time" -> alarms |> List.sortBy (fun a -> a.OccurredAt)
            | "level" ->
                alarms |> List.sortBy (fun a ->
                    match a.Level with
                    | AlarmLevel.Critical -> 0
                    | AlarmLevel.Warning -> 1
                    | AlarmLevel.Caution -> 2
                    | AlarmLevel.Advisory -> 3
                    | AlarmLevel.Normal -> 4)
            | _ -> alarms
        if ascending then sorted else List.rev sorted

    let private getLevelColor (level: AlarmLevel) =
        match level with
        | AlarmLevel.Critical -> "#dc2626"
        | AlarmLevel.Warning -> "#f59e0b"
        | AlarmLevel.Caution -> "#fbbf24"
        | AlarmLevel.Advisory -> "#06b6d4"
        | AlarmLevel.Normal -> "#6b7280"

    let private renderAlarmRow (alarm: Alarm) (dispatch: Message -> unit) =
        let levelColor = getLevelColor alarm.Level
        let isAcked = alarm.AcknowledgedAt.IsSome
        let rowStyle = if isAcked then "opacity: 0.6;" else ""

        tr {
            attr.``class`` "alarm-row"
            attr.style rowStyle
            td {
                attr.``class`` "alarm-level"
                attr.style (sprintf "color: %s;" levelColor)
                text (sprintf "%s %s" alarm.Level.Icon alarm.Level.Abbrev)
            }
            td {
                attr.``class`` "alarm-message"
                text alarm.Message
            }
            td {
                attr.``class`` "alarm-category"
                text alarm.Category
            }
            td {
                attr.``class`` "alarm-node"
                text alarm.NodeId
            }
            td {
                attr.``class`` "alarm-time"
                text (alarm.OccurredAt.ToString("yyyy-MM-dd HH:mm:ss"))
            }
            td {
                attr.``class`` "alarm-status"
                if isAcked then
                    span {
                        attr.``class`` "acked"
                        text "Acknowledged"
                    }
                else
                    span {
                        attr.``class`` "unacked"
                        text "Active"
                    }
            }
            td {
                attr.``class`` "alarm-actions"
                if not isAcked then
                    button {
                        attr.``class`` "btn-ack"
                        on.click (fun _ -> dispatch (AlarmAcknowledged alarm.Id))
                        text "Ack"
                    }
                button {
                    attr.``class`` "btn-details"
                    on.click (fun _ -> dispatch (SelectAlarm (Some alarm.Id)))
                    text "Details"
                }
            }
        }

    let private renderFilterButtons (currentFilter: AlarmsFilter) (localDispatch: AlarmsMsg -> unit) =
        div {
            attr.``class`` "filter-buttons"
            button {
                attr.``class`` (if currentFilter = AllAlarms then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter AllAlarms))
                text "All"
            }
            button {
                attr.``class`` (if currentFilter = CriticalOnly then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter CriticalOnly))
                text "Critical"
            }
            button {
                attr.``class`` (if currentFilter = UnacknowledgedOnly then "filter-btn active" else "filter-btn")
                on.click (fun _ -> localDispatch (SetFilter UnacknowledgedOnly))
                text "Unacknowledged"
            }
        }

    let view (appModel: Model.AppModel) (localModel: AlarmsModel) (localDispatch: AlarmsMsg -> unit) (dispatch: Message -> unit) =
        let filteredAlarms =
            appModel.Alarms
            |> filterAlarms localModel.Filter
            |> sortAlarms localModel.SortBy localModel.SortAscending

        let criticalCount = appModel.Alarms |> List.filter (fun a -> a.Level = AlarmLevel.Critical) |> List.length
        let warningCount = appModel.Alarms |> List.filter (fun a -> a.Level = AlarmLevel.Warning) |> List.length
        let unackedCount = appModel.Alarms |> List.filter (fun a -> a.AcknowledgedAt.IsNone) |> List.length

        div {
            attr.``class`` "page-alarms"
            div {
                attr.``class`` "page-header"
                h1 { text "Alarm Center" }
                div {
                    attr.``class`` "alarm-summary"
                    span {
                        attr.``class`` "summary-item critical"
                        text (sprintf "%d Critical" criticalCount)
                    }
                    span {
                        attr.``class`` "summary-item warning"
                        text (sprintf "%d Warning" warningCount)
                    }
                    span {
                        attr.``class`` "summary-item unacked"
                        text (sprintf "%d Unacked" unackedCount)
                    }
                }
            }

            div {
                attr.``class`` "alarm-toolbar"
                renderFilterButtons localModel.Filter localDispatch
                input {
                    attr.``type`` "text"
                    attr.placeholder "Search alarms..."
                    attr.value localModel.SearchQuery
                    on.input (fun e -> localDispatch (SetSearch (e.Value :?> string)))
                }
            }

            div {
                attr.``class`` "alarm-table-container"
                table {
                    attr.``class`` "alarm-table"
                    thead {
                        tr {
                            th { text "Level" }
                            th { text "Message" }
                            th { text "Category" }
                            th { text "Node" }
                            th {
                                on.click (fun _ -> localDispatch (SetSort "time"))
                                text "Time"
                            }
                            th { text "Status" }
                            th { text "Actions" }
                        }
                    }
                    tbody {
                        forEach filteredAlarms (fun alarm -> renderAlarmRow alarm dispatch)
                    }
                }

                if List.isEmpty filteredAlarms then
                    div {
                        attr.``class`` "no-alarms-message"
                        text "No alarms match the current filter"
                    }
            }
        }

type AlarmsComponent() =
    inherit ElmishComponent<Model.AppModel, Message>()

    let mutable localModel = Alarms.init ()

    let localDispatch (msg: Alarms.AlarmsMsg) =
        localModel <- Alarms.update msg localModel

    override this.View model dispatch =
        Alarms.view model localModel localDispatch dispatch
