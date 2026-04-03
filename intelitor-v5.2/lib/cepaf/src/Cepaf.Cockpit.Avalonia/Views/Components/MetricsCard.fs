// =============================================================================
// Prajna C3I Cockpit - Metrics Card Component
// =============================================================================
namespace Cepaf.Cockpit.Avalonia.Views.Components

open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout

module MetricsCard =

    type MetricData = {
        Label: string
        Value: string
        Trend: string option
        Color: string option
    }

    let view (metric: MetricData) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 4.0,
                Children = [
                    View.TextBlock(metric.Label)
                        .fontSize(12.0)
                        .opacity(0.7)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock(metric.Value)
                                .fontSize(24.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            match metric.Trend with
                            | Some trend ->
                                View.TextBlock(trend)
                                    .fontSize(12.0)
                                    .verticalAlignment(VerticalAlignment.Bottom)
                            | None -> ()
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)
