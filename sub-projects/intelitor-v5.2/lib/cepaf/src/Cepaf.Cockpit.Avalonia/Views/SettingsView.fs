// =============================================================================
// Prajna C3I Cockpit - Settings View
// =============================================================================
// STAMP: SC-HMI-001
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module SettingsView =

    let private settingRow (label: string) (value: Widget<'msg>) =
        View.Grid(
            ColumnDefinitions = "200, *",
            Children = [
                View.TextBlock(label)
                    .fontSize(14.0)
                    .verticalAlignment(VerticalAlignment.Center)
                    .gridColumn(0)

                value.gridColumn(1)
            ]
        )

    let private sectionHeader (title: string) =
        View.TextBlock(title)
            .fontSize(16.0)
            .fontWeight(Avalonia.Media.FontWeight.Bold)
            .margin(0.0, 16.0, 0.0, 8.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let settings = model.Settings

        View.ScrollViewer(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    // Header
                    View.TextBlock("SETTINGS")
                        .fontSize(24.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                        .margin(0.0, 0.0, 0.0, 16.0)

                    // General section
                    sectionHeader "GENERAL"

                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                settingRow "Theme" (
                                    View.ComboBox()
                                        .width(200.0)
                                )

                                settingRow "Language" (
                                    View.ComboBox()
                                        .width(200.0)
                                )

                                settingRow "Dashboard Refresh (s)" (
                                    View.StackPanel(
                                        Orientation = Orientation.Horizontal,
                                        Spacing = 8.0,
                                        Children = [
                                            View.Slider()
                                                .minimum(5.0)
                                                .maximum(120.0)
                                                .value(float settings.DashboardRefreshSec)
                                                .width(200.0)

                                            View.TextBlock($"{settings.DashboardRefreshSec}s")
                                                .width(40.0)
                                        ]
                                    )
                                )

                                settingRow "Auto-compact Context" (
                                    View.ToggleSwitch()
                                        .isChecked(settings.AutoCompactContext)
                                )
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // Connection section
                    sectionHeader "CONNECTIONS"

                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                settingRow "Elixir Backend URL" (
                                    View.TextBox()
                                        .text(settings.ElixirUrl)
                                        .width(300.0)
                                )

                                settingRow "Zenoh Router" (
                                    View.TextBox()
                                        .text(settings.ZenohRouter)
                                        .width(300.0)
                                )

                                settingRow "Connection Timeout (ms)" (
                                    View.TextBox()
                                        .text(string settings.ConnectionTimeoutMs)
                                        .width(100.0)
                                )

                                settingRow "Retry Attempts" (
                                    View.TextBox()
                                        .text(string settings.MaxRetries)
                                        .width(100.0)
                                )

                                View.StackPanel(
                                    Orientation = Orientation.Horizontal,
                                    Spacing = 8.0,
                                    Children = [
                                        View.Button(View.TextBlock("Test Connection"))
                                            .onClick(fun _ -> dispatch (Settings TestConnection))

                                        View.TextBlock(
                                            match settings.ConnectionStatus with
                                            | ConnectionTestStatus.Untested -> ""
                                            | ConnectionTestStatus.Testing -> "Testing..."
                                            | ConnectionTestStatus.Success -> "✅ Connected"
                                            | ConnectionTestStatus.Failed msg -> $"❌ {msg}"
                                        )
                                        .fontSize(12.0)
                                        .verticalAlignment(VerticalAlignment.Center)
                                    ]
                                )
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // Safety section
                    sectionHeader "SAFETY & SECURITY"

                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                settingRow "Guardian Timeout (ms)" (
                                    View.TextBox()
                                        .text(string settings.GuardianTimeoutMs)
                                        .width(100.0)
                                )

                                settingRow "Sentinel Sync Interval (ms)" (
                                    View.TextBox()
                                        .text(string settings.SentinelSyncIntervalMs)
                                        .width(100.0)
                                )

                                settingRow "Circuit Breaker Threshold" (
                                    View.TextBox()
                                        .text(string settings.CircuitBreakerThreshold)
                                        .width(100.0)
                                )

                                settingRow "Two-Step Commit" (
                                    View.ToggleSwitch()
                                        .isChecked(settings.TwoStepCommit)
                                )

                                settingRow "Proof Token TTL (ms)" (
                                    View.TextBox()
                                        .text(string settings.ProofTokenTtlMs)
                                        .width(100.0)
                                )
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // OODA section
                    sectionHeader "OODA & EVOLUTION"

                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                settingRow "OODA Cycle (ms)" (
                                    View.TextBox()
                                        .text(string settings.OodaCycleMs)
                                        .width(100.0)
                                )

                                settingRow "Quality Gate Threshold (%)" (
                                    View.StackPanel(
                                        Orientation = Orientation.Horizontal,
                                        Spacing = 8.0,
                                        Children = [
                                            View.Slider()
                                                .minimum(50.0)
                                                .maximum(100.0)
                                                .value(float settings.QualityGateThreshold)
                                                .width(200.0)

                                            View.TextBlock($"{settings.QualityGateThreshold}%%")
                                                .width(40.0)
                                        ]
                                    )
                                )

                                settingRow "Smart Metrics Interval (ms)" (
                                    View.TextBox()
                                        .text(string settings.SmartMetricsIntervalMs)
                                        .width(100.0)
                                )

                                settingRow "Auto-Evolution" (
                                    View.ToggleSwitch()
                                        .isChecked(settings.AutoEvolution)
                                )
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // Telemetry section
                    sectionHeader "TELEMETRY"

                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                settingRow "Enable Telemetry" (
                                    View.ToggleSwitch()
                                        .isChecked(settings.TelemetryEnabled)
                                )

                                settingRow "OTEL Endpoint" (
                                    View.TextBox()
                                        .text(settings.OtelEndpoint)
                                        .width(300.0)
                                )

                                settingRow "Log Level" (
                                    View.ComboBox()
                                        .width(150.0)
                                )

                                settingRow "Metrics Buffer Size" (
                                    View.TextBox()
                                        .text(string settings.MetricsBufferSize)
                                        .width(100.0)
                                )
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // Profile section
                    sectionHeader "CONFIGURATION PROFILE"

                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                View.StackPanel(
                                    Orientation = Orientation.Horizontal,
                                    Spacing = 8.0,
                                    Children = [
                                        View.Button(View.TextBlock("Development"))
                                            .onClick(fun _ -> dispatch (Settings (LoadProfile "development")))

                                        View.Button(View.TextBlock("Test"))
                                            .onClick(fun _ -> dispatch (Settings (LoadProfile "test")))

                                        View.Button(View.TextBlock("Production"))
                                            .onClick(fun _ -> dispatch (Settings (LoadProfile "production")))

                                        View.Button(View.TextBlock("SIL-4"))
                                            .onClick(fun _ -> dispatch (Settings (LoadProfile "sil4")))
                                    ]
                                )

                                View.TextBlock($"Current Profile: {settings.CurrentProfile}")
                                    .fontSize(12.0)
                                    .opacity(0.7)
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // Actions
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = [
                            View.Button(View.TextBlock("Reset to Defaults"))
                                .onClick(fun _ -> dispatch (Settings ResetDefaults))

                            View.Button(View.TextBlock("Export"))
                                .onClick(fun _ -> dispatch (Settings ExportSettings))

                            View.Button(View.TextBlock("Import"))
                                .onClick(fun _ -> dispatch (Settings ImportSettings))

                            View.Button(View.TextBlock("Save"))
                                .onClick(fun _ -> dispatch (Settings SaveSettings))
                        ]
                    )
                    .margin(0.0, 16.0, 0.0, 0.0)
                ]
            )
        )
        .padding(16.0)
