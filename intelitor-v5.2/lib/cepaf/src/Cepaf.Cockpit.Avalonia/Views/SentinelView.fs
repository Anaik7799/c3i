// =============================================================================
// Prajna C3I Cockpit - Sentinel View
// =============================================================================
// STAMP: SC-IMMUNE-001 to SC-IMMUNE-008, SC-PRAJNA-004
// AOR: AOR-IMMUNE-001 to AOR-IMMUNE-004
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module SentinelView =

    let private threatRow (threat: ActiveThreat) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto, *, Auto, Auto, Auto",
                Children = [
                    // Severity indicator
                    View.TextBlock(
                        match threat.Severity with
                        | ThreatSeverity.Extinction -> "💀"
                        | ThreatSeverity.Critical -> "🔴"
                        | ThreatSeverity.High -> "🟠"
                        | ThreatSeverity.Medium -> "🟡"
                        | ThreatSeverity.Low -> "🟢"
                    )
                    .fontSize(18.0)
                    .gridColumn(0)
                    .margin(0.0, 0.0, 12.0, 0.0)

                    // Threat info
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 2.0,
                        Children = [
                            View.TextBlock(threat.Name)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock(threat.Description)
                                .fontSize(12.0)
                                .opacity(0.8)
                                .textWrapping(Avalonia.Media.TextWrapping.Wrap)

                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Spacing = 8.0,
                                Children = [
                                    View.TextBlock($"Category: {threat.Category}")
                                        .fontSize(11.0)
                                        .opacity(0.7)

                                    View.TextBlock($"RPN: {threat.RPN}")
                                        .fontSize(11.0)
                                        .opacity(0.7)
                                ]
                            )
                        ]
                    ).gridColumn(1)

                    // Status
                    View.TextBlock(
                        match threat.Status with
                        | ThreatStatus.Detected -> "DETECTED"
                        | ThreatStatus.Mitigating -> "MITIGATING"
                        | ThreatStatus.Contained -> "CONTAINED"
                        | ThreatStatus.Resolved -> "RESOLVED"
                    )
                    .fontSize(11.0)
                    .gridColumn(2)
                    .margin(0.0, 0.0, 16.0, 0.0)

                    // Detected time
                    View.TextBlock(threat.DetectedAt.ToString("HH:mm:ss"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(3)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    // Actions
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            if threat.Status = ThreatStatus.Detected then
                                View.Button(View.TextBlock("Mitigate"))
                                    .onClick(fun _ -> dispatch (Sentinel (MitigateThreat threat.Id)))

                            if threat.Status = ThreatStatus.Contained then
                                View.Button(View.TextBlock("Resolve"))
                                    .onClick(fun _ -> dispatch (Sentinel (ResolveThreat threat.Id)))

                            View.Button(View.TextBlock("Details"))
                                .onClick(fun _ -> dispatch (Sentinel (ViewThreatDetails threat.Id)))
                        ]
                    ).gridColumn(4)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)
        .margin(0.0, 4.0)

    let private patternCard (pattern: DetectedPattern) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 4.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                match pattern.Type with
                                | PatternType.MemoryLeak -> "🧠"
                                | PatternType.CpuSpike -> "⚡"
                                | PatternType.NetworkAnomaly -> "🌐"
                                | PatternType.ProcessCrash -> "💥"
                                | PatternType.ResourceExhaustion -> "📉"
                            )

                            View.TextBlock(pattern.Name)
                                .fontSize(12.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock($"Confidence: {pattern.Confidence * 100.0:F0}%%")
                        .fontSize(11.0)
                        .opacity(0.7)

                    View.TextBlock($"Samples: {pattern.SampleCount}")
                        .fontSize(11.0)
                        .opacity(0.7)
                ]
            )
        )
        .padding(8.0)
        .cornerRadius(4.0)

    let private quarantineRow (process: QuarantinedProcess) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "*, Auto, Auto",
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Children = [
                            View.TextBlock(process.Name)
                                .fontSize(12.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock($"PID: {process.Pid} | Reason: {process.Reason}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    ).gridColumn(0)

                    View.TextBlock(process.QuarantinedAt.ToString("HH:mm:ss"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(1)
                        .margin(0.0, 0.0, 8.0, 0.0)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 4.0,
                        Children = [
                            View.Button(View.TextBlock("Release"))
                                .onClick(fun _ -> dispatch (Sentinel (ReleaseFromQuarantine process.Pid)))

                            View.Button(View.TextBlock("Terminate"))
                                .onClick(fun _ -> dispatch (Sentinel (TerminateQuarantined process.Pid)))
                        ]
                    ).gridColumn(2)
                ]
            )
        )
        .padding(8.0)
        .cornerRadius(4.0)
        .margin(0.0, 2.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let sentinel = model.Sentinel

        View.Grid(
            ColumnDefinitions = "2*, *",
            RowDefinitions = "Auto, *, Auto, Auto",
            Children = [
                // Header with health score
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("SENTINEL")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.StackPanel(
                            Orientation = Orientation.Horizontal,
                            Spacing = 8.0,
                            Children = [
                                View.TextBlock("Health:")
                                    .fontSize(14.0)
                                    .margin(16.0, 0.0, 0.0, 0.0)

                                View.TextBlock($"{sentinel.HealthScore * 100.0:F1}%%")
                                    .fontSize(18.0)
                                    .fontWeight(Avalonia.Media.FontWeight.Bold)

                                View.ProgressBar()
                                    .value(sentinel.HealthScore * 100.0)
                                    .maximum(100.0)
                                    .width(100.0)
                                    .height(8.0)
                            ]
                        ).verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("Assess Now"))
                            .onClick(fun _ -> dispatch (Sentinel AssessHealth))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )
                .gridRow(0)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 0.0, 0.0, 16.0)

                // Active threats
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 12.0,
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Children = [
                                    View.TextBlock("ACTIVE THREATS")
                                        .fontSize(16.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.TextBlock($"({sentinel.ActiveThreats.Length})")
                                        .fontSize(14.0)
                                        .opacity(0.7)
                                        .margin(8.0, 0.0, 0.0, 0.0)
                                ]
                            )

                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Children = [
                                        if sentinel.ActiveThreats.IsEmpty then
                                            View.TextBlock("No active threats detected")
                                                .fontSize(14.0)
                                                .opacity(0.7)
                                                .horizontalAlignment(HorizontalAlignment.Center)
                                                .margin(0.0, 32.0, 0.0, 0.0)
                                        else
                                            for threat in sentinel.ActiveThreats do
                                                threatRow threat dispatch
                                    ]
                                )
                            )
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(1)
                .gridColumn(0)

                // Right panel: Patterns and Quarantine
                View.StackPanel(
                    Orientation = Orientation.Vertical,
                    Spacing = 16.0,
                    Children = [
                        // Pattern Hunter results
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 8.0,
                                Children = [
                                    View.TextBlock("PATTERN HUNTER")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.ScrollViewer(
                                        View.WrapPanel(
                                            Orientation = Orientation.Horizontal,
                                            Children = [
                                                for pattern in sentinel.DetectedPatterns do
                                                    patternCard pattern
                                            ]
                                        )
                                    ).height(120.0)
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)

                        // Quarantine
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 8.0,
                                Children = [
                                    View.StackPanel(
                                        Orientation = Orientation.Horizontal,
                                        Children = [
                                            View.TextBlock("QUARANTINE")
                                                .fontSize(14.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                                            View.TextBlock($"({sentinel.QuarantinedProcesses})")
                                                .fontSize(12.0)
                                                .opacity(0.7)
                                                .margin(8.0, 0.0, 0.0, 0.0)
                                        ]
                                    )

                                    View.ScrollViewer(
                                        View.StackPanel(
                                            Orientation = Orientation.Vertical,
                                            Children = [
                                                for proc in sentinel.Quarantined do
                                                    quarantineRow proc dispatch
                                            ]
                                        )
                                    ).height(100.0)
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)

                        // Stats
                        View.Border(
                            View.Grid(
                                ColumnDefinitions = "*, *",
                                RowDefinitions = "Auto, Auto",
                                Children = [
                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Threats Resolved")
                                                .fontSize(11.0).opacity(0.7)
                                            View.TextBlock(string sentinel.ThreatsResolved)
                                                .fontSize(18.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(0).gridColumn(0)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Patterns Detected")
                                                .fontSize(11.0).opacity(0.7)
                                            View.TextBlock(string sentinel.DetectedPatterns.Length)
                                                .fontSize(18.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(0).gridColumn(1)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Last Scan")
                                                .fontSize(11.0).opacity(0.7)
                                            View.TextBlock(sentinel.LastScan.ToString("HH:mm:ss"))
                                                .fontSize(14.0)
                                        ]
                                    ).gridRow(1).gridColumn(0)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Scan Interval")
                                                .fontSize(11.0).opacity(0.7)
                                            View.TextBlock($"{sentinel.ScanIntervalMs}ms")
                                                .fontSize(14.0)
                                        ]
                                    ).gridRow(1).gridColumn(1)
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)
                    ]
                )
                .gridRow(1)
                .gridColumn(1)
                .margin(16.0, 0.0, 0.0, 0.0)

                // Symbiotic Defense status
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock("SYMBIOTIC DEFENSE")
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock(
                                if sentinel.SymbioticDefenseActive then "🛡️ Active" else "⏸️ Standby"
                            )
                            .fontSize(12.0)

                            View.TextBlock($"Response Targets: Extinction={sentinel.ResponseTimes.Extinction}ms, Critical={sentinel.ResponseTimes.Critical}ms")
                                .fontSize(11.0)
                                .opacity(0.7)

                            View.Button(
                                View.TextBlock(if sentinel.SymbioticDefenseActive then "Disable" else "Enable")
                            )
                            .onClick(fun _ -> dispatch (Sentinel ToggleSymbioticDefense))
                            .horizontalAlignment(HorizontalAlignment.Right)
                        ]
                    )
                )
                .padding(12.0)
                .cornerRadius(8.0)
                .gridRow(2)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 16.0, 0.0, 0.0)

                // Footer actions
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Spacing = 8.0,
                    HorizontalAlignment = HorizontalAlignment.Right,
                    Children = [
                        View.Button(View.TextBlock("Export Report"))
                            .onClick(fun _ -> dispatch (Sentinel ExportReport))

                        View.Button(View.TextBlock("Run Full Scan"))
                            .onClick(fun _ -> dispatch (Sentinel RunFullScan))
                    ]
                )
                .gridRow(3)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 16.0, 0.0, 0.0)
            ]
        )
        .margin(16.0)
