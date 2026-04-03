// =============================================================================
// Prajna C3I Cockpit - Fitness Gauge Component
// =============================================================================
namespace Cepaf.Cockpit.Avalonia.Views.Components

open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types

module FitnessGauge =

    let private gaugeBar (label: string) (value: float) =
        View.StackPanel(
            Orientation = Orientation.Vertical,
            Spacing = 4.0,
            Children = [
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock(label)
                            .fontSize(12.0)

                        View.TextBlock($"{value * 100.0:F1}%%")
                            .fontSize(12.0)
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )

                View.ProgressBar()
                    .value(value * 100.0)
                    .maximum(100.0)
                    .height(8.0)
            ]
        )

    let view (fitness: FitnessMetrics) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.TextBlock("FITNESS METRICS")
                        .fontSize(14.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    gaugeBar "Coverage" fitness.Coverage
                    gaugeBar "Pass Rate" fitness.PassRate
                    gaugeBar "Mutation" fitness.MutationScore
                    gaugeBar "Diversity" fitness.Diversity

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        HorizontalAlignment = HorizontalAlignment.Center,
                        Children = [
                            View.TextBlock("Combined: ")
                                .fontSize(16.0)

                            View.TextBlock($"{fitness.Combined * 100.0:F1}%%")
                                .fontSize(20.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)
