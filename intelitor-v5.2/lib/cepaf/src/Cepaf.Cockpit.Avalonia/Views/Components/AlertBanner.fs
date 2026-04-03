// =============================================================================
// Prajna C3I Cockpit - Alert Banner Component
// =============================================================================
namespace Cepaf.Cockpit.Avalonia.Views.Components

open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Messages

module AlertBanner =

    type AlertType =
        | Success
        | Warning
        | Error
        | Info

    let view (alertType: AlertType) (message: string) (onDismiss: unit -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto,*,Auto",
                Children = [
                    View.TextBlock(
                        match alertType with
                        | Success -> "✓"
                        | Warning -> "⚠"
                        | Error -> "✕"
                        | Info -> "ℹ"
                    )
                    .fontSize(18.0)
                    .margin(0.0, 0.0, 12.0, 0.0)
                    .gridColumn(0)

                    View.TextBlock(message)
                        .fontSize(14.0)
                        .verticalAlignment(VerticalAlignment.Center)
                        .gridColumn(1)

                    View.Button(
                        View.TextBlock("×")
                            .fontSize(18.0)
                    )
                    .onClick(fun _ -> onDismiss())
                    .gridColumn(2)
                ]
            )
        )
        .padding(12.0, 8.0)
        .cornerRadius(4.0)

    let successBanner message onDismiss = view Success message onDismiss
    let warningBanner message onDismiss = view Warning message onDismiss
    let errorBanner message onDismiss = view Error message onDismiss
    let infoBanner message onDismiss = view Info message onDismiss
