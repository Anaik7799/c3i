// =============================================================================
// Prajna C3I Cockpit - Health Indicator Component
// =============================================================================
// STAMP: SC-HMI-001, SC-HMI-003
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views.Components

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Themes.AerospaceTheme

module HealthIndicator =

    let private statusLabel (status: HealthStatus) =
        match status with
        | Healthy -> "HEALTHY"
        | Degraded -> "DEGRADED"
        | Critical -> "CRITICAL"
        | Unknown -> "UNKNOWN"

    let view (health: SystemHealth) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.Ellipse()
                                .width(12.0)
                                .height(12.0)

                            View.TextBlock(statusLabel health.Overall)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                        ]
                    )

                    View.TextBlock($"CPU: {health.CpuUsage:F1}%%")
                        .fontSize(12.0)

                    View.TextBlock($"Memory: {health.MemoryUsage:F1}%%")
                        .fontSize(12.0)

                    View.TextBlock($"Latency: {health.NetworkLatency}ms")
                        .fontSize(12.0)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)
