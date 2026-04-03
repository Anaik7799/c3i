namespace Cepaf.Cockpit.Web.Components

open System
open Bolero
open Bolero.Html
open Cepaf.Cockpit.Web.Domain.Types
open Cepaf.Cockpit.Web.Domain.Messages

/// =============================================================================
/// NAVIGATION RAIL COMPONENT - Side Navigation Bar
/// =============================================================================
/// STAMP: SC-HMI-001 (Dark Cockpit), SC-COCKPIT-003 (< 50ms response)
/// =============================================================================

module NavigationRail =

    module Colors =
        let background = "#111827"
        let surface = "#1f2937"
        let primary = "#3b82f6"
        let secondary = "#6b7280"
        let hover = "#374151"
        let textColor = "#d1d5db"
        let textDim = "#9ca3af"
        let border = "#374151"
        let critical = "#dc2626"
        let caution = "#fbbf24"

    type NavItem = {
        Page: Page
        Icon: string
        Label: string
        Badge: int option
    }

    let getNavItems (activeAlarms: int) (pendingProposals: int) (activeThreats: int) : NavItem list =
        [
            { Page = Dashboard; Icon = "D"; Label = "Dashboard"; Badge = None }
            { Page = Alarms; Icon = "A"; Label = "Alarms"; Badge = if activeAlarms > 0 then Some activeAlarms else None }
            { Page = Guardian; Icon = "G"; Label = "Guardian"; Badge = if pendingProposals > 0 then Some pendingProposals else None }
            { Page = Sentinel; Icon = "S"; Label = "Sentinel"; Badge = if activeThreats > 0 then Some activeThreats else None }
            { Page = Video; Icon = "V"; Label = "Video"; Badge = None }
            { Page = Devices; Icon = "D"; Label = "Devices"; Badge = None }
            { Page = AccessControl; Icon = "A"; Label = "Access"; Badge = None }
            { Page = Analytics; Icon = "Y"; Label = "Analytics"; Badge = None }
            { Page = Compliance; Icon = "C"; Label = "Compliance"; Badge = None }
            { Page = Copilot; Icon = "I"; Label = "AI Copilot"; Badge = None }
            { Page = Register; Icon = "R"; Label = "Register"; Badge = None }
            { Page = TestEvolution; Icon = "T"; Label = "Tests"; Badge = None }
            { Page = Settings; Icon = "S"; Label = "Settings"; Badge = None }
        ]

    let renderBadge (count: int option) =
        match count with
        | Some n when n > 0 ->
            let badgeColor = if n >= 5 then Colors.critical else Colors.caution
            let badgeText = if n > 99 then "99+" else string n
            span {
                attr.``class`` "nav-badge"
                attr.style (sprintf "position: absolute; top: 4px; right: 4px; background: %s; color: white; font-size: 10px; font-weight: bold; padding: 2px 6px; border-radius: 10px; min-width: 18px; text-align: center;" badgeColor)
                text badgeText
            }
        | _ -> empty ()

    let renderNavItem (item: NavItem) (isActive: bool) (isExpanded: bool) (dispatch: Message -> unit) =
        let bgColor = if isActive then Colors.primary else "transparent"
        let txtColor = if isActive then "white" else Colors.textDim
        let flexDir = if isExpanded then "row" else "column"
        let paddingVal = if isExpanded then "12px 16px" else "12px 8px"
        let iconSize = if isExpanded then "24px" else "28px"

        button {
            attr.``class`` (if isActive then "nav-item active" else "nav-item")
            attr.style (sprintf "position: relative; display: flex; flex-direction: %s; align-items: center; justify-content: center; gap: 4px; padding: %s; margin: 4px 8px; background: %s; color: %s; border: none; border-radius: 12px; cursor: pointer; transition: all 0.2s; width: calc(100%% - 16px);" flexDir paddingVal bgColor txtColor)
            on.click (fun _ -> dispatch (NavigateTo item.Page))
            attr.title item.Label
            span {
                attr.``class`` "nav-icon"
                attr.style (sprintf "font-size: %s; font-weight: bold;" iconSize)
                text item.Icon
            }
            if isExpanded then
                span {
                    attr.``class`` "nav-label"
                    attr.style "font-size: 14px; font-weight: 500; white-space: nowrap;"
                    text item.Label
                }
            else
                span {
                    attr.``class`` "nav-label-compact"
                    attr.style "font-size: 10px; margin-top: -2px;"
                    text (item.Label.Substring(0, Math.Min(4, item.Label.Length)))
                }
            renderBadge item.Badge
        }

    let renderToggleButton (isExpanded: bool) (dispatch: Message -> unit) =
        let icon = if isExpanded then "<" else ">"
        button {
            attr.``class`` "nav-toggle"
            attr.style (sprintf "position: absolute; bottom: 16px; left: 50%%; transform: translateX(-50%%); background: %s; color: %s; border: 1px solid %s; border-radius: 8px; padding: 8px; cursor: pointer; transition: all 0.2s;" Colors.surface Colors.textColor Colors.border)
            on.click (fun _ -> dispatch ToggleNavigation)
            attr.title (if isExpanded then "Collapse" else "Expand")
            text icon
        }

    let renderBranding (isExpanded: bool) =
        div {
            attr.``class`` "nav-branding"
            attr.style (sprintf "padding: 16px; text-align: center; border-bottom: 1px solid %s; margin-bottom: 8px;" Colors.border)
            if isExpanded then
                div {
                    div {
                        attr.style "color: #3b82f6; font-size: 24px; font-weight: bold;"
                        text "PRAJNA"
                    }
                    div {
                        attr.style "color: #6b7280; font-size: 11px; margin-top: 2px;"
                        text "C3I Mesh Cockpit"
                    }
                }
            else
                div {
                    attr.style "color: #3b82f6; font-size: 28px; font-weight: bold;"
                    text "P"
                }
        }

    let render (currentPage: Page) (isExpanded: bool) (activeAlarms: int) (pendingProposals: int) (activeThreats: int) (dispatch: Message -> unit) =
        let width = if isExpanded then "240px" else "80px"
        let navItems = getNavItems activeAlarms pendingProposals activeThreats
        let railClass = if isExpanded then "navigation-rail expanded" else "navigation-rail collapsed"

        nav {
            attr.``class`` railClass
            attr.style (sprintf "position: fixed; left: 0; top: 0; bottom: 0; width: %s; background: %s; border-right: 1px solid %s; display: flex; flex-direction: column; transition: width 0.3s ease; z-index: 1000;" width Colors.background Colors.border)
            renderBranding isExpanded
            div {
                attr.``class`` "nav-items"
                attr.style "flex: 1; overflow-y: auto; overflow-x: hidden; padding-bottom: 60px;"
                forEach navItems (fun item -> renderNavItem item (item.Page = currentPage) isExpanded dispatch)
            }
            renderToggleButton isExpanded dispatch
        }
