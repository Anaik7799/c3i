// =============================================================================
// Prajna C3I Cockpit - Navigation Rail Component
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-HMI-*, Material Design 3 |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Views.Components

open System
open Fabulous
open Fabulous.Avalonia
open Avalonia.Controls
open Avalonia.Layout
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

/// <summary>
/// Navigation rail component for primary cockpit navigation
/// Implements Material Design 3 navigation rail pattern with AtomUI
/// </summary>
module NavigationRail =

    // =========================================================================
    // Navigation Item Definition
    // =========================================================================

    type NavItem = {
        View: ActiveView
        Label: string
        Icon: string
        Badge: int option
    }

    let navigationItems = [
        { View = Dashboard; Label = "Dashboard"; Icon = "dashboard"; Badge = None }
        { View = TestEvolution; Label = "Test Evolution"; Icon = "science"; Badge = None }
        { View = Alarms; Label = "Alarms"; Icon = "warning"; Badge = Some 5 }
        { View = Devices; Label = "Devices"; Icon = "devices"; Badge = None }
        { View = Video; Label = "Video"; Icon = "videocam"; Badge = None }
        { View = Analytics; Label = "Analytics"; Icon = "analytics"; Badge = None }
        { View = Compliance; Label = "Compliance"; Icon = "verified"; Badge = None }
        { View = AccessControl; Label = "Access"; Icon = "security"; Badge = None }
        { View = AiCopilot; Label = "AI Copilot"; Icon = "smart_toy"; Badge = None }
        { View = Guardian; Label = "Guardian"; Icon = "shield"; Badge = None }
        { View = Sentinel; Label = "Sentinel"; Icon = "radar"; Badge = None }
        { View = ImmutableRegister; Label = "Register"; Icon = "storage"; Badge = None }
        { View = Settings; Label = "Settings"; Icon = "settings"; Badge = None }
    ]

    // =========================================================================
    // View Functions
    // =========================================================================

    let private navItemView (item: NavItem) (isActive: bool) (dispatch: Msg -> unit) =
        View.Button(
            View.StackPanel(
                Orientation = Orientation.Horizontal,
                Spacing = 12.0,
                Children = [
                    View.TextBlock(item.Icon)
                        .fontSize(20.0)

                    View.TextBlock(item.Label)
                        .fontSize(14.0)

                    match item.Badge with
                    | Some count when count > 0 ->
                        View.Border(
                            View.TextBlock(string count)
                                .fontSize(10.0)
                        )
                        .cornerRadius(10.0)
                        .padding(4.0, 2.0)
                    | _ -> ()
                ]
            )
        )
        .onClick(fun _ -> dispatch (Nav (Navigate item.View)))
        .padding(16.0, 12.0)

    let view (activeView: ActiveView) (expanded: bool) (dispatch: Msg -> unit) =
        View.Border(
            View.ScrollViewer(
                View.StackPanel(
                    Orientation = Orientation.Vertical,
                    Spacing = 4.0,
                    Children = [
                        // Header with toggle
                        View.Button(
                            View.TextBlock(if expanded then "◀" else "▶")
                        )
                        .onClick(fun _ -> dispatch (Nav ToggleSidebar))
                        .horizontalAlignment(HorizontalAlignment.Right)
                        .padding(8.0)

                        // Logo/Title
                        if expanded then
                            View.TextBlock("PRAJNA C3I")
                                .fontSize(18.0)
                                .fontWeight(Avalonia.Media.FontWeight.Bold)
                                .margin(16.0, 16.0, 16.0, 24.0)
                                .horizontalAlignment(HorizontalAlignment.Center)

                        // Navigation Items
                        for item in navigationItems do
                            navItemView item (item.View = activeView) dispatch
                    ]
                )
            )
        )
        .width(if expanded then 240.0 else 72.0)
        .padding(8.0)
