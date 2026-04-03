// =============================================================================
// Prajna C3I Cockpit - Dashboard View
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011, SC-PRAJNA-001 to SC-PRAJNA-007
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-HMI-*, SC-PRAJNA-* |
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

/// <summary>
/// Main dashboard view for Prajna C3I Cockpit
/// Provides system-wide health overview and quick access to key metrics
/// </summary>
module DashboardView =

    // =========================================================================
    // Section: System Health Overview
    // =========================================================================

    let private systemHealthSection (health: SystemHealth) (sync: SyncState) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 16.0,
                Children = [
                    View.TextBlock("SYSTEM HEALTH")
                        .fontSize(16.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    HealthIndicator.view health

                    View.Grid(
                        ColumnDefinitions = "*, *",
                        RowDefinitions = "Auto, Auto",
                        Children = [
                            View.TextBlock("Elixir:")
                                .gridRow(0).gridColumn(0)
                            View.TextBlock(
                                match sync.ElixirConnection with
                                | Connected -> "Connected"
                                | Connecting -> "Connecting..."
                                | Disconnected -> "Disconnected"
                                | Error e -> $"Error: {e}"
                            )
                            .gridRow(0).gridColumn(1)

                            View.TextBlock("Zenoh:")
                                .gridRow(1).gridColumn(0)
                            View.TextBlock(
                                match sync.ZenohConnection with
                                | Connected -> "Connected"
                                | Connecting -> "Connecting..."
                                | Disconnected -> "Disconnected"
                                | Error e -> $"Error: {e}"
                            )
                            .gridRow(1).gridColumn(1)
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    // =========================================================================
    // Section: Test Evolution Status
    // =========================================================================

    let private testEvolutionSection (te: TestEvolutionState) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 16.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("TEST EVOLUTION")
                                .fontSize(16.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.Button(
                                View.TextBlock("View →")
                            )
                            .onClick(fun _ -> dispatch (Nav (Navigate TestEvolution)))
                            .horizontalAlignment(HorizontalAlignment.Right)
                        ]
                    )

                    OodaStatus.view te.Ooda
                    FitnessGauge.view te.Fitness

                    View.TextBlock($"Generation: #{te.GenerationCount}")
                        .fontSize(12.0)
                        .horizontalAlignment(HorizontalAlignment.Center)
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    // =========================================================================
    // Section: Active Alarms Summary
    // =========================================================================

    let private alarmsSection (alarms: AlarmsState) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("ACTIVE ALARMS")
                                .fontSize(16.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock($"({alarms.ActiveAlarms.Length})")
                                .fontSize(14.0)
                                .opacity(0.7)
                                .margin(8.0, 0.0, 0.0, 0.0)

                            View.Button(
                                View.TextBlock("View All →")
                            )
                            .onClick(fun _ -> dispatch (Nav (Navigate Alarms)))
                            .horizontalAlignment(HorizontalAlignment.Right)
                        ]
                    )

                    if alarms.Storm.IsActive then
                        View.Border(
                            View.TextBlock($"⚠ ALARM STORM: {alarms.Storm.AlarmCount} alarms")
                                .fontSize(14.0)
                        )
                        .padding(8.0)
                        .cornerRadius(4.0)

                    for alarm in alarms.ActiveAlarms |> List.truncate 5 do
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Spacing = 8.0,
                                Children = [
                                    View.TextBlock(
                                        match alarm.Severity with
                                        | AlarmSeverity.Critical -> "🔴"
                                        | AlarmSeverity.High -> "🟠"
                                        | AlarmSeverity.Medium -> "🟡"
                                        | AlarmSeverity.Low -> "🔵"
                                        | AlarmSeverity.Info -> "⚪"
                                    )

                                    View.TextBlock(alarm.Code)
                                        .fontSize(12.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.TextBlock(alarm.Message)
                                        .fontSize(12.0)
                                ]
                            )
                        )
                        .padding(8.0)
                        .cornerRadius(4.0)
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    // =========================================================================
    // Section: Guardian Status
    // =========================================================================

    let private guardianSection (guardian: GuardianState) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("GUARDIAN")
                                .fontSize(16.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.Ellipse()
                                .width(12.0)
                                .height(12.0)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.Grid(
                        ColumnDefinitions = "*, *",
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Approved")
                                        .fontSize(12.0)
                                        .opacity(0.7)
                                    View.TextBlock(string guardian.TotalApproved)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(0)

                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("Vetoed")
                                        .fontSize(12.0)
                                        .opacity(0.7)
                                    View.TextBlock(string guardian.TotalVetoed)
                                        .fontSize(24.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(1)
                        ]
                    )

                    View.TextBlock($"Pending: {guardian.Proposals |> List.filter (fun p -> p.Status = Pending) |> List.length}")
                        .fontSize(12.0)
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    // =========================================================================
    // Section: Sentinel Status
    // =========================================================================

    let private sentinelSection (sentinel: SentinelState) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 12.0,
                Children = [
                    View.TextBlock("SENTINEL")
                        .fontSize(16.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock("Health Score:")
                                .fontSize(14.0)
                            View.TextBlock($"{sentinel.HealthScore * 100.0:F1}%%")
                                .fontSize(18.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                        ]
                    )

                    View.TextBlock($"Active Threats: {sentinel.ActiveThreats.Length}")
                        .fontSize(12.0)

                    View.TextBlock($"Quarantined: {sentinel.QuarantinedProcesses}")
                        .fontSize(12.0)
                ]
            )
        )
        .padding(16.0)
        .cornerRadius(8.0)

    // =========================================================================
    // Main Dashboard View
    // =========================================================================

    let view (model: Model) (dispatch: Msg -> unit) =
        View.ScrollViewer(
            KeyboardNavigation.TabNavigation = Avalonia.Input.TabNavigation.Cycle,
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 16.0,
                Children = [
                    // Header
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("PRAJNA C3I COCKPIT")
                                .fontSize(24.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock($"Last Updated: {model.LastUpdated:HH:mm:ss}")
                                .fontSize(12.0)
                                .opacity(0.7)
                                .horizontalAlignment(HorizontalAlignment.Right)
                                .verticalAlignment(VerticalAlignment.Center)
                        ]
                    )

                    // Error/Success banners
                    match model.ErrorMessage with
                    | Some msg ->
                        AlertBanner.errorBanner msg (fun () -> dispatch (System ClearError))
                    | None -> ()

                    match model.SuccessMessage with
                    | Some msg ->
                        AlertBanner.successBanner msg (fun () -> dispatch (System ClearSuccess))
                    | None -> ()

                    // Main grid layout
                    View.Grid(
                        ColumnDefinitions = "*, *",
                        RowDefinitions = "Auto, Auto, Auto",
                        Children = [
                            // Row 0
                            (systemHealthSection model.SystemHealth model.SyncState)
                                .gridRow(0).gridColumn(0)

                            (testEvolutionSection model.TestEvolution dispatch)
                                .gridRow(0).gridColumn(1)

                            // Row 1
                            (alarmsSection model.Alarms dispatch)
                                .gridRow(1).gridColumn(0)

                            (guardianSection model.Guardian dispatch)
                                .gridRow(1).gridColumn(1)

                            // Row 2
                            (sentinelSection model.Sentinel dispatch)
                                .gridRow(2).gridColumn(0)
                        ]
                    )
                ]
            )
        )
        .padding(16.0)
