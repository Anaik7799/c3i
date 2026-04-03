// =============================================================================
// Prajna C3I Cockpit - Analytics View
// =============================================================================
// STAMP: SC-HMI-001, SC-OBS-069
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module AnalyticsView =

    let private reportCard (report: AnalyticsReport) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                match report.Type with
                                | ReportType.Alarms -> "🚨"
                                | ReportType.Performance -> "📈"
                                | ReportType.Compliance -> "📋"
                                | ReportType.Security -> "🔒"
                                | ReportType.Trends -> "📊"
                            )

                            View.TextBlock(report.Name)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock(report.Description)
                        .fontSize(12.0)
                        .opacity(0.8)
                        .textWrapping(Avalonia.Media.TextWrapping.Wrap)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock($"Generated: {report.GeneratedAt.ToString(\"MM-dd HH:mm\")}")
                                .fontSize(11.0)
                                .opacity(0.7)

                            View.TextBlock($"Period: {report.Period}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = [
                            View.Button(View.TextBlock("View"))
                                .onClick(fun _ -> dispatch (Analytics (ViewReport report.Id)))

                            View.Button(View.TextBlock("Export"))
                                .onClick(fun _ -> dispatch (Analytics (ExportReport report.Id)))

                            View.Button(View.TextBlock("Schedule"))
                                .onClick(fun _ -> dispatch (Analytics (ScheduleReport report.Id)))
                        ]
                    )
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let private metricCard (metric: SystemMetric) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 4.0,
                Children = [
                    View.TextBlock(metric.Name)
                        .fontSize(12.0)
                        .opacity(0.7)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 4.0,
                        Children = [
                            View.TextBlock($"{metric.Value:F1}")
                                .fontSize(24.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock(metric.Unit)
                                .fontSize(12.0)
                                .opacity(0.7)
                                .verticalAlignment(VerticalAlignment.Bottom)
                                .margin(0.0, 0.0, 0.0, 4.0)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 4.0,
                        Children = [
                            View.TextBlock(
                                if metric.Trend > 0.0 then "↑" elif metric.Trend < 0.0 then "↓" else "→"
                            )

                            View.TextBlock($"{abs metric.Trend:F1}%%")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    )
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let analytics = model.Analytics

        View.ScrollViewer(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 16.0,
                Children = [
                    // Header
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock("ANALYTICS")
                                .fontSize(24.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.Button(View.TextBlock("New Report"))
                                .onClick(fun _ -> dispatch (Analytics CreateReport))
                                .horizontalAlignment(HorizontalAlignment.Right)
                        ]
                    )

                    // Key metrics grid
                    View.TextBlock("KEY METRICS")
                        .fontSize(16.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.WrapPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            for metric in analytics.KeyMetrics do
                                metricCard metric
                        ]
                    )

                    // Query builder
                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 12.0,
                            Children = [
                                View.TextBlock("QUERY BUILDER")
                                    .fontSize(16.0)
                                    .fontWeight(Avalonia.Media.FontWeight.Bold)

                                View.Grid(
                                    ColumnDefinitions = "*, Auto, Auto",
                                    Children = [
                                        View.TextBox()
                                            .text(analytics.QueryText)
                                            .watermark("Enter DuckDB query...")
                                            .gridColumn(0)

                                        View.ComboBox()
                                            .gridColumn(1)
                                            .margin(8.0, 0.0, 0.0, 0.0)

                                        View.Button(View.TextBlock("Execute"))
                                            .onClick(fun _ -> dispatch (Analytics ExecuteQuery))
                                            .gridColumn(2)
                                            .margin(8.0, 0.0, 0.0, 0.0)
                                    ]
                                )

                                if analytics.QueryResult.IsSome then
                                    View.Border(
                                        View.TextBlock(analytics.QueryResult.Value)
                                            .fontSize(12.0)
                                            .fontFamily("Consolas")
                                    )
                                    .padding(12.0)
                                    .cornerRadius(4.0)
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)

                    // Reports
                    View.TextBlock("REPORTS")
                        .fontSize(16.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                    View.WrapPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            for report in analytics.Reports do
                                reportCard report dispatch
                        ]
                    )

                    // Trend charts placeholder
                    View.Border(
                        View.StackPanel(
                            Orientation = Orientation.Vertical,
                            Spacing = 8.0,
                            Children = [
                                View.TextBlock("TREND ANALYSIS")
                                    .fontSize(16.0)
                                    .fontWeight(Avalonia.Media.FontWeight.Bold)

                                View.Border(
                                    View.TextBlock("📊 Chart visualization area")
                                        .horizontalAlignment(HorizontalAlignment.Center)
                                        .verticalAlignment(VerticalAlignment.Center)
                                )
                                .height(200.0)
                                .cornerRadius(4.0)
                            ]
                        )
                    )
                    .padding(16.0)
                    .cornerRadius(8.0)
                ]
            )
        )
        .padding(16.0)
