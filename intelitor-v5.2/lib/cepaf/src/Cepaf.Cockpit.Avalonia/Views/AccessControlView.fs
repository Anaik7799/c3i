// =============================================================================
// Prajna C3I Cockpit - Access Control View
// =============================================================================
// STAMP: SC-HMI-001, SC-SEC-044 to SC-SEC-047
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

module AccessControlView =

    let private grantRow (grant: AccessGrant) (dispatch: Msg -> unit) =
        View.Border(
            View.Grid(
                ColumnDefinitions = "Auto, *, Auto, Auto, Auto, Auto",
                Children = [
                    View.TextBlock(
                        if grant.Active then "🟢" else "🔴"
                    )
                    .gridColumn(0)
                    .margin(0.0, 0.0, 12.0, 0.0)

                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Children = [
                            View.TextBlock(grant.Principal)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                            View.TextBlock($"Zone: {grant.Zone}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    ).gridColumn(1)

                    View.TextBlock(
                        match grant.Permission with
                        | Permission.Read -> "👁️ Read"
                        | Permission.Write -> "✏️ Write"
                        | Permission.Admin -> "👑 Admin"
                        | Permission.Operator -> "🔧 Operator"
                    )
                    .fontSize(12.0)
                    .gridColumn(2)
                    .margin(0.0, 0.0, 16.0, 0.0)

                    View.TextBlock(grant.GrantedAt.ToString("MM-dd HH:mm"))
                        .fontSize(11.0)
                        .opacity(0.7)
                        .gridColumn(3)
                        .margin(0.0, 0.0, 16.0, 0.0)

                    View.TextBlock(
                        match grant.ExpiresAt with
                        | Some exp -> exp.ToString("MM-dd HH:mm")
                        | None -> "Never"
                    )
                    .fontSize(11.0)
                    .opacity(0.7)
                    .gridColumn(4)
                    .margin(0.0, 0.0, 16.0, 0.0)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 4.0,
                        Children = [
                            if grant.Active then
                                View.Button(View.TextBlock("Revoke"))
                                    .onClick(fun _ -> dispatch (AccessControl (RevokeGrant grant.Id)))
                            else
                                View.Button(View.TextBlock("Restore"))
                                    .onClick(fun _ -> dispatch (AccessControl (RestoreGrant grant.Id)))

                            View.Button(View.TextBlock("Details"))
                                .onClick(fun _ -> dispatch (AccessControl (ViewGrantDetails grant.Id)))
                        ]
                    ).gridColumn(5)
                ]
            )
        )
        .padding(12.0, 8.0)
        .cornerRadius(4.0)
        .margin(0.0, 2.0)

    let private policyCard (policy: AccessPolicy) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 8.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(if policy.Enabled then "✅" else "⏸️")

                            View.TextBlock(policy.Name)
                                .fontSize(14.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock(policy.Description)
                        .fontSize(12.0)
                        .opacity(0.8)
                        .textWrapping(Avalonia.Media.TextWrapping.Wrap)

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        Children = [
                            View.TextBlock($"Rules: {policy.RuleCount}")
                                .fontSize(11.0)
                                .opacity(0.7)

                            View.TextBlock($"Applied: {policy.AppliedCount}")
                                .fontSize(11.0)
                                .opacity(0.7)
                        ]
                    )

                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Spacing = 8.0,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = [
                            View.Button(
                                View.TextBlock(if policy.Enabled then "Disable" else "Enable")
                            )
                            .onClick(fun _ -> dispatch (AccessControl (TogglePolicy policy.Id)))

                            View.Button(View.TextBlock("Edit"))
                                .onClick(fun _ -> dispatch (AccessControl (EditPolicy policy.Id)))
                        ]
                    )
                ]
            )
        )
        .padding(12.0)
        .cornerRadius(8.0)

    let private zoneCard (zone: AccessZone) (dispatch: Msg -> unit) =
        View.Border(
            View.StackPanel(
                Orientation = Orientation.Vertical,
                Spacing = 4.0,
                Children = [
                    View.StackPanel(
                        Orientation = Orientation.Horizontal,
                        Children = [
                            View.TextBlock(
                                match zone.SecurityLevel with
                                | SecurityLevel.Public -> "🟢"
                                | SecurityLevel.Internal -> "🟡"
                                | SecurityLevel.Confidential -> "🟠"
                                | SecurityLevel.Restricted -> "🔴"
                            )

                            View.TextBlock(zone.Name)
                                .fontSize(12.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(8.0, 0.0, 0.0, 0.0)
                        ]
                    )

                    View.TextBlock($"Devices: {zone.DeviceCount} | Users: {zone.UserCount}")
                        .fontSize(11.0)
                        .opacity(0.7)

                    View.Button(View.TextBlock("Manage"))
                        .onClick(fun _ -> dispatch (AccessControl (ManageZone zone.Id)))
                ]
            )
        )
        .padding(8.0)
        .cornerRadius(4.0)

    let view (model: Model) (dispatch: Msg -> unit) =
        let ac = model.AccessControl

        View.Grid(
            ColumnDefinitions = "2*, *",
            RowDefinitions = "Auto, *, Auto",
            Children = [
                // Header
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Children = [
                        View.TextBlock("ACCESS CONTROL")
                            .fontSize(24.0)
                            .fontWeight(Avalonia.Media.FontWeight.Bold)

                        View.TextBlock($"Active Grants: {ac.ActiveGrants}")
                            .fontSize(14.0)
                            .opacity(0.7)
                            .margin(16.0, 0.0, 0.0, 0.0)
                            .verticalAlignment(VerticalAlignment.Center)

                        View.Button(View.TextBlock("New Grant"))
                            .onClick(fun _ -> dispatch (AccessControl CreateGrant))
                            .horizontalAlignment(HorizontalAlignment.Right)
                    ]
                )
                .gridRow(0)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 0.0, 0.0, 16.0)

                // Main content - Grants list
                View.Border(
                    View.StackPanel(
                        Orientation = Orientation.Vertical,
                        Spacing = 12.0,
                        Children = [
                            // Filter tabs
                            View.StackPanel(
                                Orientation = Orientation.Horizontal,
                                Spacing = 8.0,
                                Children = [
                                    View.Button(View.TextBlock("All"))
                                        .onClick(fun _ -> dispatch (AccessControl ShowAllGrants))

                                    View.Button(View.TextBlock("Active"))
                                        .onClick(fun _ -> dispatch (AccessControl (FilterGrants true)))

                                    View.Button(View.TextBlock("Revoked"))
                                        .onClick(fun _ -> dispatch (AccessControl (FilterGrants false)))

                                    View.TextBox()
                                        .watermark("Search...")
                                        .width(200.0)
                                        .horizontalAlignment(HorizontalAlignment.Right)
                                ]
                            )

                            // Grants table
                            View.ScrollViewer(
                                View.StackPanel(
                                    Orientation = Orientation.Vertical,
                                    Children = [
                                        // Header row
                                        View.Border(
                                            View.Grid(
                                                ColumnDefinitions = "Auto, *, Auto, Auto, Auto, Auto",
                                                Children = [
                                                    View.TextBlock("").gridColumn(0).width(24.0)
                                                    View.TextBlock("Principal").fontSize(11.0).fontWeight(Avalonia.Media.FontWeight.Bold).gridColumn(1)
                                                    View.TextBlock("Permission").fontSize(11.0).fontWeight(Avalonia.Media.FontWeight.Bold).gridColumn(2)
                                                    View.TextBlock("Granted").fontSize(11.0).fontWeight(Avalonia.Media.FontWeight.Bold).gridColumn(3)
                                                    View.TextBlock("Expires").fontSize(11.0).fontWeight(Avalonia.Media.FontWeight.Bold).gridColumn(4)
                                                    View.TextBlock("Actions").fontSize(11.0).fontWeight(Avalonia.Media.FontWeight.Bold).gridColumn(5)
                                                ]
                                            )
                                        )
                                        .padding(12.0, 8.0)
                                        .opacity(0.7)

                                        for grant in ac.Grants do
                                            grantRow grant dispatch
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

                // Right panel - Policies and Zones
                View.StackPanel(
                    Orientation = Orientation.Vertical,
                    Spacing = 16.0,
                    Children = [
                        // Policies
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 8.0,
                                Children = [
                                    View.StackPanel(
                                        Orientation = Orientation.Horizontal,
                                        Children = [
                                            View.TextBlock("POLICIES")
                                                .fontSize(14.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)

                                            View.Button(View.TextBlock("+"))
                                                .onClick(fun _ -> dispatch (AccessControl CreatePolicy))
                                                .horizontalAlignment(HorizontalAlignment.Right)
                                        ]
                                    )

                                    View.ScrollViewer(
                                        View.StackPanel(
                                            Orientation = Orientation.Vertical,
                                            Spacing = 8.0,
                                            Children = [
                                                for policy in ac.Policies do
                                                    policyCard policy dispatch
                                            ]
                                        )
                                    ).height(200.0)
                                ]
                            )
                        )
                        .padding(12.0)
                        .cornerRadius(8.0)

                        // Zones
                        View.Border(
                            View.StackPanel(
                                Orientation = Orientation.Vertical,
                                Spacing = 8.0,
                                Children = [
                                    View.TextBlock("SECURITY ZONES")
                                        .fontSize(14.0)
                                        .fontWeight(Avalonia.Media.FontWeight.Bold)

                                    View.WrapPanel(
                                        Orientation = Orientation.Horizontal,
                                        Children = [
                                            for zone in ac.Zones do
                                                zoneCard zone dispatch
                                        ]
                                    )
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
                                            View.TextBlock("Active Policies").fontSize(11.0).opacity(0.7)
                                            View.TextBlock(string (ac.Policies |> List.filter (fun p -> p.Enabled) |> List.length))
                                                .fontSize(18.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(0).gridColumn(0)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Total Zones").fontSize(11.0).opacity(0.7)
                                            View.TextBlock(string ac.Zones.Length)
                                                .fontSize(18.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(0).gridColumn(1)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Denials Today").fontSize(11.0).opacity(0.7)
                                            View.TextBlock(string ac.DenialsToday)
                                                .fontSize(18.0)
                                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                        ]
                                    ).gridRow(1).gridColumn(0)

                                    View.StackPanel(
                                        Orientation = Orientation.Vertical,
                                        Children = [
                                            View.TextBlock("Last Audit").fontSize(11.0).opacity(0.7)
                                            View.TextBlock(ac.LastAudit.ToString("HH:mm"))
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

                // Footer
                View.StackPanel(
                    Orientation = Orientation.Horizontal,
                    Spacing = 8.0,
                    HorizontalAlignment = HorizontalAlignment.Right,
                    Children = [
                        View.Button(View.TextBlock("Export Audit"))
                            .onClick(fun _ -> dispatch (AccessControl ExportAudit))

                        View.Button(View.TextBlock("Run Audit"))
                            .onClick(fun _ -> dispatch (AccessControl RunAudit))
                    ]
                )
                .gridRow(2)
                .gridColumn(0)
                .gridColumnSpan(2)
                .margin(0.0, 16.0, 0.0, 0.0)
            ]
        )
        .margin(16.0)
