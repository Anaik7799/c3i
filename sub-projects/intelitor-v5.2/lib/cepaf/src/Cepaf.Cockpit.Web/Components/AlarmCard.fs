namespace Cepaf.Cockpit.Web.Components

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// ALARM CARD COMPONENT - Individual Alarm Display
/// =============================================================================
/// STAMP: SC-HMI-001 (Dark Cockpit), SC-HMI-004 (Two-step commit)
/// =============================================================================

module AlarmCard =

    module Colors =
        let normal = "#6b7280"
        let advisory = "#06b6d4"
        let caution = "#fbbf24"
        let warning = "#f59e0b"
        let critical = "#dc2626"
        let criticalBg = "#7f1d1d"
        let acknowledged = "#4b5563"
        let background = "#1f2937"
        let border = "#374151"

    let getAlarmColors (level: AlarmLevel) (isAcked: bool) =
        if isAcked then
            Colors.acknowledged, Colors.background, Colors.border
        else
            match level with
            | AlarmLevel.Normal -> Colors.normal, Colors.background, Colors.border
            | AlarmLevel.Advisory -> Colors.advisory, Colors.background, Colors.advisory
            | AlarmLevel.Caution -> Colors.caution, Colors.background, Colors.caution
            | AlarmLevel.Warning -> Colors.warning, Colors.background, Colors.warning
            | AlarmLevel.Critical -> Colors.critical, Colors.criticalBg, Colors.critical

    let formatTimestamp (dt: DateTime) =
        let now = DateTime.UtcNow
        let diff = now - dt
        if diff.TotalMinutes < 1.0 then "just now"
        elif diff.TotalMinutes < 60.0 then sprintf "%.0fm ago" diff.TotalMinutes
        elif diff.TotalHours < 24.0 then sprintf "%.0fh ago" diff.TotalHours
        else dt.ToString("MMM dd HH:mm")

    let renderLevelBadge (level: AlarmLevel) (isAcked: bool) =
        let textColor, _, _ = getAlarmColors level isAcked
        let icon = level.Icon
        let abbrev = level.Abbrev
        span {
            attr.``class`` "alarm-level-badge"
            attr.style (sprintf "color: %s; font-weight: bold; margin-right: 8px;" textColor)
            text (sprintf "%s %s" icon abbrev)
        }

    let renderAckStatus (alarm: Alarm) =
        match alarm.AcknowledgedAt with
        | Some ackTime ->
            let ackBy = defaultArg alarm.AcknowledgedBy "Unknown"
            span {
                attr.``class`` "ack-status"
                attr.style "color: #6b7280; font-size: 12px; font-style: italic;"
                text (sprintf "Acked by %s at %s" ackBy (formatTimestamp ackTime))
            }
        | None ->
            span {
                attr.``class`` "ack-status"
                attr.style "color: #f59e0b; font-size: 12px; font-weight: bold;"
                text "UNACKNOWLEDGED"
            }

    let renderActions (alarm: Alarm) (dispatch: Message -> unit) =
        let isAcknowledged = alarm.AcknowledgedAt.IsSome
        div {
            attr.``class`` "alarm-actions"
            attr.style "display: flex; gap: 8px; margin-top: 12px;"
            if not isAcknowledged then
                button {
                    attr.``class`` "btn btn-caution"
                    attr.style "padding: 6px 12px; background: #fbbf24; color: #1f2937; border: none; border-radius: 4px; cursor: pointer;"
                    on.click (fun _ -> dispatch (AlarmAcknowledged alarm.Id))
                    text "Acknowledge"
                }
            button {
                attr.``class`` "btn btn-secondary"
                attr.style "padding: 6px 12px; background: #374151; color: #d1d5db; border: none; border-radius: 4px; cursor: pointer;"
                on.click (fun _ -> dispatch (SelectAlarm (Some alarm.Id)))
                text "Details"
            }
            if isAcknowledged then
                button {
                    attr.``class`` "btn btn-danger"
                    attr.style "padding: 6px 12px; background: #dc2626; color: white; border: none; border-radius: 4px; cursor: pointer;"
                    on.click (fun _ -> dispatch (AlarmCleared alarm.Id))
                    text "Clear"
                }
        }

    let render (alarm: Alarm) (dispatch: Message -> unit) =
        let isAcked = alarm.AcknowledgedAt.IsSome
        let textColor, bgColor, borderColor = getAlarmColors alarm.Level isAcked
        let timestamp = formatTimestamp alarm.OccurredAt
        let animClass = if alarm.Level = AlarmLevel.Critical && not isAcked then "alarm-critical-blink" else ""
        let cardStyle = sprintf "background: %s; border-left: 4px solid %s; padding: 16px; margin: 8px 0; border-radius: 4px;" bgColor borderColor

        div {
            attr.``class`` (sprintf "alarm-card %s" animClass)
            attr.style cardStyle
            // Header
            div {
                attr.``class`` "alarm-header"
                attr.style "display: flex; align-items: center; margin-bottom: 8px;"
                renderLevelBadge alarm.Level isAcked
                span {
                    attr.``class`` "alarm-title"
                    attr.style (sprintf "color: %s; font-size: 16px; font-weight: 600;" textColor)
                    text alarm.Message
                }
            }
            // Metadata
            div {
                attr.``class`` "alarm-metadata"
                attr.style "color: #9ca3af; font-size: 13px; margin-bottom: 8px;"
                text (sprintf "Node: %s | Category: %s | %s" alarm.NodeId alarm.Category timestamp)
            }
            // Details
            match alarm.Details with
            | Some details when not (String.IsNullOrWhiteSpace(details)) ->
                div {
                    attr.``class`` "alarm-details"
                    attr.style "color: #d1d5db; font-size: 14px; margin-bottom: 8px; padding-left: 16px; border-left: 2px solid #374151;"
                    text details
                }
            | _ -> empty ()
            // Ack status
            renderAckStatus alarm
            // Actions
            renderActions alarm dispatch
        }

    let renderCompact (alarm: Alarm) (dispatch: Message -> unit) =
        let isAcked = alarm.AcknowledgedAt.IsSome
        let textColor, _, borderColor = getAlarmColors alarm.Level isAcked
        div {
            attr.``class`` "alarm-card-compact"
            attr.style (sprintf "border-left: 3px solid %s; padding: 8px; margin: 4px 0; cursor: pointer;" borderColor)
            on.click (fun _ -> dispatch (SelectAlarm (Some alarm.Id)))
            span {
                attr.style (sprintf "color: %s; margin-right: 8px;" textColor)
                text alarm.Level.Icon
            }
            span {
                attr.style "color: #d1d5db;"
                text alarm.Message
            }
            span {
                attr.style "color: #6b7280; font-size: 12px; margin-left: 8px;"
                text (formatTimestamp alarm.OccurredAt)
            }
        }
