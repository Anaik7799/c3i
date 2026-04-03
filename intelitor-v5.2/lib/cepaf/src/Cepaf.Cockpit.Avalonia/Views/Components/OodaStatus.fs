// =============================================================================
// Prajna C3I Cockpit - OODA Status Component
// =============================================================================
namespace Cepaf.Cockpit.Avalonia.Views.Components

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types

module OodaStatus =

    let private phaseLabel (phase: OodaPhase) =
        match phase with
        | Observe -> "OBSERVE"
        | Orient -> "ORIENT"
        | Decide -> "DECIDE"
        | Act -> "ACT"
        | Complete -> "COMPLETE"

    let private phaseProgress (phase: OodaPhase) : float =
        match phase with
        | Observe -> 0.25
        | Orient -> 0.50
        | Decide -> 0.75
        | Act -> 1.0
        | Complete -> 1.0

    let view (ooda: OodaState) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.TextBlock("OODA CYCLE")
                        .fontSize(14.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        HorizontalAlignment = HorizontalAlignment.Center,
                        Spacing = 16.0,
                        Children = [
                            for phase in [Observe; Orient; Decide; Act] do
                                let isActive = ooda.CurrentPhase = phase
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Spacing = 4.0,
                                    Children = [
                                        View.Ellipse()
                                            .width(24.0)
                                            .height(24.0)
                                            .opacity(if isActive then 1.0 else 0.4)

                                        View.TextBlock(phaseLabel phase)
                                            .fontSize(10.0)
                                            .horizontalAlignment(HorizontalAlignment.Center)
                                    ]
                                )
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock($"Cycle #{ooda.CycleCount}")
                                .fontSize(12.0)

                            View.TextBlock($"{ooda.LastCycleDuration.TotalMilliseconds:F0}ms")
                                .fontSize(12.0)
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)
