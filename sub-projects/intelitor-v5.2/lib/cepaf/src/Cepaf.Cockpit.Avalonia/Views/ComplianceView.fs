// =============================================================================
// Prajna C3I Cockpit - Compliance View
// =============================================================================
// STAMP: SC-HMI-001, SC-SEC-044
// Standards: IEC 61508, ISO 27001, GDPR, EN 50131
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module ComplianceView =

    let private standardCard (standard: ComplianceStandard) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                if standard.Compliant then "✅" else "⚠️"
                            )

                            View.TextBlock(standard.Name)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock(standard.Description)
                        .fontSize(12.0)
                        .opacity(0.8)

                    View.ProgressBar()
                        .value(standard.ComplianceScore * 100.0)
                        .maximum(100.0)
                        .height(8.0)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 16.0,
                        Children = [
                            View.TextBlock($"Score: {standard.ComplianceScore * 100.0:F0}%%")
                                .fontSize(11.0)

                            View.TextBlock($"Controls: {standard.ControlsPassed}/{standard.TotalControls}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    )

                    View.Button(View.TextBlock("View Details"))
                        .onClick(fun _ -> dispatch (Compliance (ViewStandardDetails standard.Id)))
                        .horizontalAlignment(HorizontalAlignment.Right)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let private auditRow (audit: AuditEntry) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto, Auto, *, Auto, Auto",
                Children = [
                    View.TextBlock(
                        match audit.Severity with
                        | AuditSeverity.Critical -> "🔴"
                        | AuditSeverity.High -> "🟠"
                        | AuditSeverity.Medium -> "🟡"
                        | AuditSeverity.Low -> "🟢"
                        | AuditSeverity.Info -> "ℹ️"
                    )
                    .gridColumn(0)
                    .margin(0.0, 0.0, 8.0, 0.0)

                    View.TextBlock(audit.Category)
                        .fontSize(12.0)
                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                        .gridColumn(1)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    View.TextBlock(audit.Description)
                        .fontSize(12.0)
                        .gridColumn(2)

                    View.TextBlock(audit.User)
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(3)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    View.TextBlock(audit.Timestamp.ToString("MM-dd HH:mm:ss"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(4)
                ]
            )
        )
        .padding(8.0, 4.0)

    let private evidenceCard (evidence: ComplianceEvidence) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Horizontal,
                Spacing = 8.0,
                Children = [
                    View.TextBlock(
                        match evidence.Type with
                        | EvidenceType.Document -> "📄"
                        | EvidenceType.Screenshot -> "🖼️"
                        | EvidenceType.Log -> "📋"
                        | EvidenceType.Config -> "⚙️"
                    )

                    View.TextBlock(evidence.Name)
                        .fontSize(12.0)

                    View.TextBlock(evidence.CollectedAt.ToString("MM-dd"))
                        .fontSize(11.0)
                        .opacity(0.7)

                    View.Button(View.TextBlock("View"))
                        .onClick(fun _ -> dispatch (Compliance (ViewEvidence evidence.Id)))
                ]
            )
        )
        .padding(8.0, 4.0)
        .cornerRadius(4.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let compliance = model.Compliance

        View.Grid(
            ColumnDefinitions = "2*, *",
            RowDefinitions = "Auto, Auto, *, Auto",
            Children = [
                // Header
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("COMPLIANCE")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.TextBlock(
                            if compliance.OverallCompliant then "✅ Compliant" else "⚠️ Issues Found"
                        )
                        .fontSize(14.0)
                        .margin(16.0, 0.0, 0.0, 0.0)
                        .verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("Run Audit"))
                            .onClick(fun _ -> dispatch (Compliance RunAudit))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )
                .gridRow(0)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 0.0, 0.0, 16.0)

                // Standards grid
                View.StackPanel(
                    Orientation = Orientation.Vertical,
                    Spacing = 12.0,
                    Children = [
                        View.TextBlock("COMPLIANCE STANDARDS")
                            .fontSize(16.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.WrapPanel(
                            Orientation = Orientation.Horizontal,
                            Children = [
                                for standard in compliance.Standards do
                                    standardCard standard dispatch
                            ]
                        )
                    ]
                )
                .gridRow(1)
                .gridColumn(0)
                .gridColumnSpan(2)

                // Audit trail
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 8.0,
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Children = [
                                    View.TextBlock("AUDIT TRAIL")
                                        .fontSize(16.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.Button(View.TextBlock("Export"))
                                        .onClick(fun _ -> dispatch (Compliance ExportAuditTrail))
                                        .horizontalAlignment(HorizontalAlignment.Right)
                                ]
                            )

                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Children = [
                                        for entry in compliance.AuditTrail |> List.truncate 50 do
                                            auditRow entry
                                    ]
                                )
                            ).height(300.0)
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(2)
                .gridColumn(0)
                .margin(0.0, 16.0, 0.0, 0.0)

                // Evidence collection
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 8.0,
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Children = [
                                    View.TextBlock("EVIDENCE")
                                        .fontSize(16.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.Button(View.TextBlock("Collect"))
                                        .onClick(fun _ -> dispatch (Compliance CollectEvidence))
                                        .horizontalAlignment(HorizontalAlignment.Right)
                                ]
                            )

                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Spacing = 4.0,
                                    Children = [
                                        for evidence in compliance.Evidence do
                                            evidenceCard evidence dispatch
                                    ]
                                )
                            ).height(250.0)

                            // Collection status
                            View.TextBlock($"Last Collection: {compliance.LastEvidenceCollection.ToString(\"MM-dd HH:mm\")}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(2)
                .gridColumn(1)
                .margin(16.0, 16.0, 0.0, 0.0)

                // Footer with summary
                View.Border(
                    View.Grid(
                        ColumnDefinitions = "*, *, *, *",
                        Children = [
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("IEC 61508").fontSize(12.0).opacity(0.7)
                                    View.TextBlock(if compliance.IEC61508Compliant then "✅ SIL-2" else "❌")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(0)

                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("ISO 27001").fontSize(12.0).opacity(0.7)
                                    View.TextBlock(if compliance.ISO27001Compliant then "✅" else "❌")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(1)

                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("GDPR").fontSize(12.0).opacity(0.7)
                                    View.TextBlock(if compliance.GDPRCompliant then "✅" else "❌")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(2)

                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Children = [
                                    View.TextBlock("EN 50131").fontSize(12.0).opacity(0.7)
                                    View.TextBlock(if compliance.EN50131Compliant then "✅" else "❌")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)
                                ]
                            ).gridColumn(3)
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(3)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 16.0, 0.0, 0.0)
            ]
        )
        .margin(16.0)
