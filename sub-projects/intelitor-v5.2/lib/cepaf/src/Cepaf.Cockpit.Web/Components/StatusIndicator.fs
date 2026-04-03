namespace Cepaf.Cockpit.Web.Components

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Web.Domain.Types

/// =============================================================================
/// STATUS INDICATOR COMPONENT - Connection Status Display
/// =============================================================================
/// STAMP: SC-HMI-001 (Dark Cockpit), SC-HMI-003 (Staleness decay)
/// =============================================================================

module StatusIndicator =

    module Colors =
        let connected = "#10b981"
        let stale = "#6b7280"
        let disconnected = "#dc2626"
        let connecting = "#fbbf24"
        let error = "#dc2626"

    let getConnectionDisplay (status: ConnectionStatus) =
        match status with
        | ConnectionStatus.Connected -> Colors.connected, "●", "Connected"
        | ConnectionStatus.Stale -> Colors.stale, "◐", "Stale"
        | ConnectionStatus.Degraded -> Colors.stale, "◐", "Degraded"
        | ConnectionStatus.Disconnected -> Colors.disconnected, "○", "Disconnected"

    let getWebConnectionDisplay (state: WebConnectionState) =
        match state with
        | WebConnectionState.Connected -> Colors.connected, "●", "Connected", false
        | WebConnectionState.Connecting -> Colors.connecting, "◎", "Connecting...", true
        | WebConnectionState.Reconnecting -> Colors.connecting, "◎", "Reconnecting...", true
        | WebConnectionState.Disconnected -> Colors.disconnected, "○", "Disconnected", false
        | WebConnectionState.Error msg -> Colors.error, "✗", sprintf "Error: %s" msg, false

    let renderConnection (status: ConnectionStatus) (label: string option) =
        let color, icon, statusText = getConnectionDisplay status
        span {
            attr.``class`` "status-indicator"
            attr.style "display: inline-flex; align-items: center; gap: 6px;"
            span {
                attr.``class`` "status-icon"
                attr.style (sprintf "color: %s; font-size: 16px;" color)
                text icon
            }
            match label with
            | Some lbl ->
                span {
                    attr.``class`` "status-label"
                    attr.style "color: #d1d5db; font-size: 14px;"
                    text (sprintf "%s: %s" lbl statusText)
                }
            | None ->
                span {
                    attr.``class`` "status-text"
                    attr.style "color: #9ca3af; font-size: 13px;"
                    text statusText
                }
        }

    let renderWebConnection (state: WebConnectionState) (showLabel: bool) =
        let color, icon, statusText, _ = getWebConnectionDisplay state
        span {
            attr.``class`` "status-indicator"
            attr.style "display: inline-flex; align-items: center; gap: 6px;"
            span {
                attr.``class`` "status-icon"
                attr.style (sprintf "color: %s; font-size: 16px;" color)
                text icon
            }
            if showLabel then
                span {
                    attr.``class`` "status-text"
                    attr.style "color: #d1d5db; font-size: 14px;"
                    text statusText
                }
        }

    let renderBadge (status: ConnectionStatus) (nodeCount: string option) =
        let color, icon, statusText = getConnectionDisplay status
        div {
            attr.``class`` "status-badge"
            attr.style (sprintf "background: %s; color: white; padding: 8px 16px; border-radius: 6px; display: inline-flex; align-items: center; gap: 8px;" color)
            span {
                attr.style "font-size: 20px;"
                text icon
            }
            span {
                attr.style "font-weight: 600;"
                text statusText
            }
            match nodeCount with
            | Some count ->
                span {
                    attr.style "font-size: 12px; opacity: 0.8;"
                    text (sprintf "(%s)" count)
                }
            | None -> empty ()
        }

    let renderDot (status: ConnectionStatus) =
        let color, icon, _ = getConnectionDisplay status
        span {
            attr.``class`` "status-dot"
            attr.style (sprintf "color: %s; font-size: 12px;" color)
            attr.title (sprintf "Status: %A" status)
            text icon
        }

    let renderWithTimestamp (status: ConnectionStatus) (lastUpdate: DateTime) =
        let color, icon, statusText = getConnectionDisplay status
        let now = DateTime.UtcNow
        let diff = now - lastUpdate
        let isStale = diff.TotalSeconds > 60.0
        let timeText =
            if diff.TotalSeconds < 60.0 then sprintf "%.0fs ago" diff.TotalSeconds
            elif diff.TotalMinutes < 60.0 then sprintf "%.0fm ago" diff.TotalMinutes
            else sprintf "%.1fh ago" diff.TotalHours

        div {
            attr.``class`` "status-with-time"
            attr.style "display: flex; flex-direction: column; gap: 2px;"
            span {
                attr.``class`` "status-indicator"
                attr.style "display: inline-flex; align-items: center; gap: 6px;"
                span {
                    attr.style (sprintf "color: %s; font-size: 16px;" color)
                    text icon
                }
                span {
                    attr.style "color: #d1d5db; font-size: 14px;"
                    text statusText
                }
            }
            span {
                attr.``class`` "status-timestamp"
                attr.style (sprintf "color: %s; font-size: 11px; font-style: italic; padding-left: 22px;" (if isStale then Colors.stale else "#9ca3af"))
                text (sprintf "Last update: %s" timeText)
            }
        }

    let renderList (statuses: (string * ConnectionStatus) list) =
        ul {
            attr.``class`` "status-list"
            attr.style "list-style: none; padding: 0; margin: 0;"
            forEach statuses (fun (nodeName, status) ->
                li {
                    attr.style "padding: 4px 0; display: flex; justify-content: space-between; align-items: center;"
                    span {
                        attr.style "color: #d1d5db; font-size: 13px;"
                        text nodeName
                    }
                    renderDot status
                }
            )
        }
