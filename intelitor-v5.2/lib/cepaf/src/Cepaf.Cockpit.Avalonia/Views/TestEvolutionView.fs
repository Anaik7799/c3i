// =============================================================================
// Prajna C3I Cockpit - Test Evolution View
// =============================================================================
// STAMP: SC-TEST-EVO-001 to SC-TEST-EVO-007
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages
open Cepaf.Cockpit.Avalonia.Views.Components

module TestEvolutionView =

    let private levelCard (coverage: LevelCoverage) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.TextBlock(
                        match coverage.Level with
                        | TDG -> "TDG (Property)"
                        | FMEA -> "FMEA (Failure)"
                        | Formal -> "FORMAL (Proofs)"
                        | Graph -> "GRAPH (Paths)"
                        | BDD -> "BDD (Gherkin)"
                    )
                    .fontSize(14.0)
                    .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.ProgressBar()
                        .value(coverage.Coverage * 100.0)
                        .maximum(100.0)
                        .height(8.0)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock($"{coverage.Coverage * 100.0:F1}%%")
                                .fontSize(12.0)

                            View.TextBlock($"{coverage.TestCount} tests")
                                .fontSize(12.0)

                            View.TextBlock($"{coverage.PassRate * 100.0:F0}%% pass")
                                .fontSize(12.0)
                        ]
                    )

                    View.Button(
                        View.TextBlock("Generate")
                    )
                    .onClick(fun _ -> dispatch (TestEvo (GenerateTests coverage.Level)))
                    .horizontalAlignment(HorizontalAlignment.Right)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let private genomePanel (genome: GenomeConfig) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.TextBlock("GENOME CONFIGURATION")
                        .fontSize(16.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock("Mutation Rate:")
                                .width(120.0)
                            View.Slider()
                                .minimum(0.0)
                                .maximum(1.0)
                                .value(genome.MutationRate)
                            View.TextBlock($"{genome.MutationRate:F2}")
                                .width(40.0)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock("Crossover Rate:")
                                .width(120.0)
                            View.Slider()
                                .minimum(0.0)
                                .maximum(1.0)
                                .value(genome.CrossoverRate)
                            View.TextBlock($"{genome.CrossoverRate:F2}")
                                .width(40.0)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock("Selection:")
                                .width(120.0)
                            View.Slider()
                                .minimum(0.0)
                                .maximum(1.0)
                                .value(genome.SelectionPressure)
                            View.TextBlock($"{genome.SelectionPressure:F2}")
                                .width(40.0)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.Button(View.TextBlock("Reset"))
                                .onClick(fun _ -> dispatch (TestEvo ResetGenome))

                            View.Button(View.TextBlock("Evolve"))
                                .onClick(fun _ -> dispatch (TestEvo TriggerEvolution))
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let te = model.TestEvolution

        View.ScrollViewer(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 16.0,
                Children = [
                    View.TextBlock("TEST EVOLUTION")
                        .fontSize(24.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.Grid(
                        ColumnDefinitions = "*, *",
                        Children = [
                            OodaStatus.view te.Ooda
                                |> fun v -> v.gridColumn(0)

                            FitnessGauge.view te.Fitness
                                |> fun v -> v.gridColumn(1)
                        ]
                    )

                    View.TextBlock("5-LEVEL COVERAGE MATRIX")
                        .fontSize(18.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.WrapPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            for coverage in te.LevelCoverages do
                                levelCard coverage dispatch
                        ]
                    )

                    genomePanel te.Genome dispatch

                    if te.IsEvolving then
                        View.StackPanel(
                            Orientation = Orientation.Horizontal,
                            HorizontalAlignment = HorizontalAlignment.Center,
                            Spacing = 8.0,
                            Children = [
                                View.ProgressBar()
                                    .isIndeterminate(true)
                                    .width(200.0)

                                View.TextBlock($"Generation #{te.GenerationCount}")
                                    .fontSize(14.0)

                                View.Button(View.TextBlock("Stop"))
                                    .onClick(fun _ -> dispatch (TestEvo StopEvolution))
                            ]
                        )
                ]
            )
        )
        .padding(16.0)
