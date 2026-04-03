// =============================================================================
// Prajna C3I Cockpit - Devices View
// =============================================================================
namespace Cepaf.Cockpit.Avalonia.Views

open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module DevicesView =
    let view (model: Model) (dispatch: Msg -> unit) =
        View.StackPanel(
            Orientation = Orientation.Vertical,
            Spacing = 16.0,
            Children = [
                View.TextBlock("DEVICES")
                    .fontSize(24.0)
                    .fontWeight(Avalonia.Media.FontWeight.Bold)

                View.TextBlock($"Online: {model.Devices.OnlineCount} | Offline: {model.Devices.OfflineCount}")
                    .fontSize(14.0)

                View.ScrollViewer(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Children = [
                            for device in model.Devices.Devices do
                                View.Border(
                                    View.StackPanel(
                                        Orientation = Orientation.Horizontal,
                                        Spacing = 16.0,
                                        Children = [
                                            View.TextBlock(if device.Status = Online then "🟢" else "🔴")
                                            View.TextBlock(device.Name).fontWeight(Avalonia.Media.FontWeight.Bold)
                                            View.TextBlock(device.Zone)
                                        ]
                                    )
                                ).padding(12.0).margin(0.0, 4.0)
                        ]
                    )
                )
            ]
        ).padding(16.0)
