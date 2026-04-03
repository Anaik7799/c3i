// =============================================================================
// Prajna C3I Cockpit - Alarms View
// =============================================================================
namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module AlarmsView =

    let private alarmRow (alarm: Alarm) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto,Auto,*,Auto,Auto,Auto",
                Children = [
                    View.TextBlock(
                        match alarm.Severity with
                        | AlarmSeverity.Critical -> "🔴"
                        | AlarmSeverity.High -> "🟠"
                        | AlarmSeverity.Medium -> "🟡"
                        | AlarmSeverity.Low -> "🔵"
                        | AlarmSeverity.Info -> "⚪"
                    ).gridColumn(0).margin(0.0, 0.0, 8.0, 0.0)

                    View.TextBlock(alarm.Code)
                        .fontSize(12.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                        .gridColumn(1)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    View.TextBlock(alarm.Message)
                        .fontSize(12.0)
                        .gridColumn(2)

                    View.TextBlock(alarm.Zone)
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(3)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    View.TextBlock(alarm.Timestamp.ToString("HH:mm:ss"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(4)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 4.0,
                        Children = [
                            if alarm.Status = Active then
                                View.Button(View.TextBlock("ACK"))
                                    .onClick(fun _ -> dispatch (Alarm (AcknowledgeAlarm alarm.Id)))

                            View.Button(View.TextBlock("CLR"))
                                .onClick(fun _ -> dispatch (Alarm (ClearAlarm alarm.Id)))
                        ]
                    ).gridColumn(5)
                ]
            )
        )
        .padding(8.0)
        .margin(0.0, 2.0)
        .cornerRadius(4.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let alarms = model.Alarms

        View.StackPanel(
            Orientation = Orientation.Vertical,
            Spacing = 16.0,
            Children = [
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("ALARMS")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.TextBlock($"Active: {alarms.ActiveAlarms.Length}")
                            .fontSize(14.0)
                            .margin(16.0, 0.0, 0.0, 0.0)
                            .verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("Refresh"))
                            .onClick(fun _ -> dispatch (Alarm LoadAlarms))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )

                if alarms.Storm.IsActive then
                    View.Border(
                        View.TextBlock($"⚠ ALARM STORM DETECTED: {alarms.Storm.AlarmCount} alarms in {alarms.Storm.AffectedZones.Length} zones")
                            .fontSize(14.0)
                    )
                    .padding(12.0)
                    .cornerRadius(4.0)

                View.Grid(
                    ColumnDefinitions = "*, *, *",
                    Children = [
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Today")
                                        .fontSize(12.0)
                                        .opacity(0.7)
                                    View.TextBlock(string alarms.TotalToday)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            )
                        ).padding(12.0).gridColumn(0)

                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Acknowledged")
                                        .fontSize(12.0)
                                        .opacity(0.7)
                                    View.TextBlock(string alarms.AcknowledgedToday)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            )
                        ).padding(12.0).gridColumn(1)

                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Active")
                                        .fontSize(12.0)
                                        .opacity(0.7)
                                    View.TextBlock(string alarms.ActiveAlarms.Length)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            )
                        ).padding(12.0).gridColumn(2)
                    ]
                )

                View.ScrollViewer(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Children = [
                            for alarm in alarms.ActiveAlarms do
                                alarmRow alarm dispatch
                        ]
                    )
                )
            ]
        )
        .padding(16.0)
