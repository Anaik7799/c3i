// =============================================================================
// Prajna C3I Cockpit - Guardian View
// =============================================================================
// STAMP: SC-PRAJNA-001, SC-CONST-007, SC-FOUNDER-001
// AOR: AOR-PRAJNA-001 (Guardian Gate)
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module GuardianView =

    let private proposalRow (proposal: Proposal) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto, *, Auto, Auto",
                RowDefinitions = "Auto, Auto, Auto",
                Children = [
                    // Status indicator
                    View.TextBlock(
                        match proposal.Status with
                        | ProposalStatus.Pending -> "⏳"
                        | ProposalStatus.Approved -> "✅"
                        | ProposalStatus.Vetoed -> "❌"
                        | ProposalStatus.Expired -> "⏰"
                    )
                    .fontSize(18.0)
                    .gridRow(0)
                    .gridColumn(0)
                    .margin(0.0, 0.0, 12.0, 0.0)

                    // Proposal info
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 4.0,
                        Children = [
                            View.TextBlock(proposal.Action)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock($"Domain: {proposal.Domain}")
                                .fontSize(12.0)
                                .opacity(0.7)
                        ]
                    )
                    .gridRow(0)
                    .gridColumn(1)

                    // Timestamp
                    View.TextBlock(proposal.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridRow(0)
                        .gridColumn(2)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    // Actions
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            if proposal.Status = Pending then
                                View.Button(View.TextBlock("Approve"))
                                    .onClick(fun _ -> dispatch (Guardian (ApproveProposal proposal.Id)))

                                View.Button(View.TextBlock("Veto"))
                                    .onClick(fun _ -> dispatch (Guardian (VetoProposal proposal.Id)))

                            View.Button(View.TextBlock("Details"))
                                .onClick(fun _ -> dispatch (Guardian (ViewProposalDetails proposal.Id)))
                        ]
                    )
                    .gridRow(0)
                    .gridColumn(3)

                    // Description (full width)
                    View.TextBlock(proposal.Description)
                        .fontSize(12.0)
                        .textWrapping(Avalonia.Media.TextWrapping.Wrap)
                        .opacity(0.9)
                        .gridRow(1)
                        .gridColumn(0)
                        .gridColumnSpan(4)
                        .margin(0.0, 8.0, 0.0, 0.0)

                    // Constitutional check result
                    if proposal.ConstitutionalCheck.IsSome then
                        View.StackPanel(
                            Orientation = Orientation.Horizontal,
                            Spacing = 8.0,
                            Children = [
                                View.TextBlock("Constitutional Check:")
                                    .fontSize(11.0)
                                    .opacity(0.7)

                                for invariant in ["Ψ₀"; "Ψ₁"; "Ψ₂"; "Ψ₃"; "Ψ₄"; "Ψ₅"] do
                                    View.TextBlock(
                                        if proposal.ConstitutionalCheck.Value.Contains(invariant)
                                        then $"✓{invariant}"
                                        else $"✗{invariant}"
                                    )
                                    .fontSize(10.0)
                            ]
                        )
                        .gridRow(2)
                        .gridColumn(0)
                        .gridColumnSpan(4)
                        .margin(0.0, 4.0, 0.0, 0.0)
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)
        .margin(0.0, 4.0)

    let private constraintCard (constraint': StampConstraint) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 4.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                if constraint'.Satisfied then "✅" else "❌"
                            )

                            View.TextBlock(constraint'.Id)
                                .fontSize(12.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock(constraint'.Description)
                        .fontSize(11.0)
                        .opacity(0.9)
                        .textWrapping(Avalonia.Media.TextWrapping.Wrap)
                ]
            )
        )
        .padding(8.0)
        .cornerRadius(4.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let guardian = model.Guardian

        View.Grid(
            ColumnDefinitions = "2*, *",
            RowDefinitions = "Auto, *, Auto",
            Children = [
                // Header
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("GUARDIAN")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.Ellipse()
                            .width(12.0)
                            .height(12.0)
                            .margin(16.0, 0.0, 0.0, 0.0)

                        View.TextBlock(
                            if guardian.IsActive then "Active" else "Inactive"
                        )
                        .fontSize(12.0)
                        .margin(8.0, 0.0, 0.0, 0.0)
                        .verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("Refresh"))
                            .onClick(fun _ -> dispatch (Guardian LoadProposals))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )
                .gridRow(0)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 0.0, 0.0, 16.0)

                // Proposals list
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 12.0,
                        Children = [
                            // Tabs
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Spacing = 8.0,
                                Children = [
                                    View.Button(View.TextBlock("Pending"))
                                        .onClick(fun _ -> dispatch (Guardian (FilterProposals Pending)))

                                    View.Button(View.TextBlock("Approved"))
                                        .onClick(fun _ -> dispatch (Guardian (FilterProposals Approved)))

                                    View.Button(View.TextBlock("Vetoed"))
                                        .onClick(fun _ -> dispatch (Guardian (FilterProposals Vetoed)))

                                    View.Button(View.TextBlock("All"))
                                        .onClick(fun _ -> dispatch (Guardian ShowAllProposals))
                                ]
                            )

                            // Proposal list
                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Children = [
                                        let filtered =
                                            match guardian.Filter with
                                            | Some status -> guardian.Proposals |> List.filter (fun p -> p.Status = status)
                                            | None -> guardian.Proposals

                                        if filtered.IsEmpty then
                                            View.TextBlock("No proposals found")
                                                .fontSize(14.0)
                                                .opacity(0.7)
                                                .horizontalAlignment(HorizontalAlignment.Center)
                                                .margin(0.0, 32.0, 0.0, 0.0)
                                        else
                                            for proposal in filtered do
                                                proposalRow proposal dispatch
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

                // Stats and constraints panel
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 16.0,
                        Children = [
                            // Stats
                            View.TextBlock("STATISTICS")
                                .fontSize(16.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.Grid(
                                ColumnDefinitions = "*, *",
                                RowDefinitions = "Auto, Auto",
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
                                    ).gridRow(0).gridColumn(0)

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
                                    ).gridRow(0).gridColumn(1)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Pending")
                                                .fontSize(12.0)
                                                .opacity(0.7)
                                            View.TextBlock(
                                                string (guardian.Proposals |> List.filter (fun p -> p.Status = Pending) |> List.length)
                                            )
                                            .fontSize(24.0)
                                            .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(1).gridColumn(0)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Approval Rate")
                                                .fontSize(12.0)
                                                .opacity(0.7)

                                            let rate =
                                                if guardian.TotalApproved + guardian.TotalVetoed > 0 then
                                                    float guardian.TotalApproved / float (guardian.TotalApproved + guardian.TotalVetoed) * 100.0
                                                else 0.0

                                            View.TextBlock($"{rate:F1}%%")
                                                .fontSize(24.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(1).gridColumn(1)
                                ]
                            )

                            // Active constraints
                            View.TextBlock("ACTIVE CONSTRAINTS")
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(0.0, 16.0, 0.0, 0.0)

                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Spacing = 4.0,
                                    Children = [
                                        for constraint' in guardian.ActiveConstraints do
                                            constraintCard constraint'
                                    ]
                                )
                            ).height(200.0)
                        ]
                    )
                )
                .padding(16.0)
                .cornerRadius(8.0)
                .gridRow(1)
                .gridColumn(1)
                .margin(16.0, 0.0, 0.0, 0.0)

                // Footer with actions
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Spacing = 8.0,
                    HorizontalAlignment = HorizontalAlignment.Right,
                    Children = [
                        View.Button(View.TextBlock("Export Audit Log"))
                            .onClick(fun _ -> dispatch (Guardian ExportAuditLog))

                        View.Button(View.TextBlock("Verify Constitutional"))
                            .onClick(fun _ -> dispatch (Guardian VerifyConstitutional))
                    ]
                )
                .gridRow(2)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 16.0, 0.0, 0.0)
            ]
        )
        .margin(16.0)
