namespace Cepaf.Cockpit.Web.Components

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Domain

/// =============================================================================
/// HEALTH GAUGE COMPONENT - SVG Circular Gauge (0-100%)
/// =============================================================================
/// WHAT: SVG-based health gauge with Dark Cockpit color scheme
/// WHY: Analog visualization reduces cognitive load vs raw numbers
/// CONSTRAINTS: SC-HMI-001 (Dark Cockpit), SC-HMI-002 (Trend vectors)
/// =============================================================================

module HealthGauge =

    /// Dark Cockpit color palette
    module Colors =
        let critical = "#dc2626"
        let warning = "#f59e0b"
        let caution = "#fbbf24"
        let normal = "#6b7280"
        let optimal = "#10b981"
        let background = "#1f2937"
        let dimGray = "#4b5563"

    /// Get color based on health percentage
    let getHealthColor (health: float) : string =
        match health with
        | h when h >= 95.0 -> Colors.optimal
        | h when h >= 85.0 -> Colors.normal
        | h when h >= 70.0 -> Colors.caution
        | h when h >= 50.0 -> Colors.warning
        | _ -> Colors.critical

    /// Get arc path for gauge
    let getArcPath (percentage: float) (radius: float) (strokeWidth: float) : string =
        let clampedPercentage = Math.Max(0.0, Math.Min(100.0, percentage))
        let angle = (clampedPercentage / 100.0) * 270.0
        let startAngle = 135.0
        let endAngle = startAngle + angle
        let centerX = 60.0
        let centerY = 60.0
        let innerRadius = radius - strokeWidth / 2.0
        let startRad = startAngle * Math.PI / 180.0
        let endRad = endAngle * Math.PI / 180.0
        let x1 = centerX + innerRadius * Math.Cos(startRad)
        let y1 = centerY + innerRadius * Math.Sin(startRad)
        let x2 = centerX + innerRadius * Math.Cos(endRad)
        let y2 = centerY + innerRadius * Math.Sin(endRad)
        let largeArcFlag = if angle > 180.0 then 1 else 0
        sprintf "M %.2f %.2f A %.2f %.2f 0 %d 1 %.2f %.2f" x1 y1 innerRadius innerRadius largeArcFlag x2 y2

    /// Render trend indicator
    let renderTrend (trend: Trend) =
        let icon, color =
            match trend with
            | RisingFast -> "^^", Colors.warning
            | Rising -> "^", Colors.caution
            | Stable -> "-", Colors.dimGray
            | Falling -> "v", Colors.caution
            | FallingFast -> "vv", Colors.critical
        let styleAttr = sprintf "fill: %s; font-size: 12px; text-anchor: middle;" color
        elt "text" {
            "x" => "60"
            "y" => "85"
            attr.``class`` "trend-indicator"
            attr.style styleAttr
            text icon
        }

    /// Main gauge component
    let render (health: float) (trend: Trend) (label: string) =
        let color = getHealthColor health
        let arcPath = getArcPath health 45.0 8.0
        let healthText = sprintf "%.0f%%" health
        let valueStyle = sprintf "fill: %s; font-size: 20px; font-weight: bold; text-anchor: middle;" color
        let labelStyle = sprintf "fill: %s; font-size: 10px; text-anchor: middle;" Colors.dimGray

        div {
            attr.``class`` "health-gauge"
            attr.style "display: inline-block; margin: 8px;"
            elt "svg" {
                "width" => "120"
                "height" => "120"
                "viewBox" => "0 0 120 120"
                // Background arc
                elt "path" {
                    "d" => getArcPath 100.0 45.0 8.0
                    "fill" => "none"
                    "stroke" => Colors.background
                    "stroke-width" => "8"
                    "stroke-linecap" => "round"
                }
                // Foreground arc
                elt "path" {
                    "d" => arcPath
                    "fill" => "none"
                    "stroke" => color
                    "stroke-width" => "8"
                    "stroke-linecap" => "round"
                }
                // Center text
                elt "text" {
                    "x" => "60"
                    "y" => "55"
                    attr.``class`` "health-value"
                    attr.style valueStyle
                    text healthText
                }
                // Label
                elt "text" {
                    "x" => "60"
                    "y" => "70"
                    attr.``class`` "health-label"
                    attr.style labelStyle
                    text label
                }
                // Trend
                renderTrend trend
            }
        }

    /// Render with default trend
    let renderSimple (health: float) (label: string) =
        render health Trend.Stable label
