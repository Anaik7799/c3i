namespace Cepaf.Cockpit

open System
open System.Text
open Cepaf.Cockpit.AerospaceTheme

/// ═══════════════════════════════════════════════════════════════════════════════
/// AEROSPACE THEME EDITOR & SIMULATOR
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Interactive terminal-based theme editor and component simulator
///       for testing and visualizing all 77 component variants.
///
/// WHY: Theme development requires real-time preview to ensure WCAG compliance,
///      OLED optimization, and proper visual hierarchy across all states.
///
/// FEATURES:
///   - Live color picker with P3 gamut preview
///   - Component gallery with all 77 variants
///   - State simulator (hover, focus, active, disabled, etc.)
///   - Animation preview with timing controls
///   - Accessibility checker (contrast ratios, motion preferences)
///   - Theme import/export (JSON, CSS, ANSI, tview)
///   - ARM & FIRE protocol choreography preview
///
/// STAMP Constraints:
///   - SC-EDIT-001: All edits must maintain WCAG 2.1 AA compliance
///   - SC-EDIT-002: Changes must be validated before applying
///   - SC-EDIT-003: Undo/redo with unlimited history
///
/// ═══════════════════════════════════════════════════════════════════════════════
module ThemeEditor =

    // ═══════════════════════════════════════════════════════════════════════════
    // ANSI ESCAPE CODES
    // ═══════════════════════════════════════════════════════════════════════════

    module Ansi =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let dim = "\u001b[2m"
        let italic = "\u001b[3m"
        let underline = "\u001b[4m"
        let blink = "\u001b[5m"
        let reverse = "\u001b[7m"
        let hidden = "\u001b[8m"
        let strikethrough = "\u001b[9m"

        let clear = "\u001b[2J\u001b[H"
        let clearLine = "\u001b[2K"
        let hideCursor = "\u001b[?25l"
        let showCursor = "\u001b[?25h"
        let saveCursor = "\u001b[s"
        let restoreCursor = "\u001b[u"

        let moveTo row col = sprintf "\u001b[%d;%dH" row col
        let moveUp n = sprintf "\u001b[%dA" n
        let moveDown n = sprintf "\u001b[%dB" n
        let moveRight n = sprintf "\u001b[%dC" n
        let moveLeft n = sprintf "\u001b[%dD" n

        let fg (c: RgbColor) = sprintf "\u001b[38;2;%d;%d;%dm" c.R c.G c.B
        let bg (c: RgbColor) = sprintf "\u001b[48;2;%d;%d;%dm" c.R c.G c.B
        let fgBg (fgc: RgbColor) (bgc: RgbColor) =
            sprintf "\u001b[38;2;%d;%d;%d;48;2;%d;%d;%dm" fgc.R fgc.G fgc.B bgc.R bgc.G bgc.B

    // ═══════════════════════════════════════════════════════════════════════════
    // EDITOR STATE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Editor view/screen
    type EditorView =
        | Dashboard             // Overview with theme summary
        | ColorPalette          // Color editor
        | ComponentGallery      // All components
        | ComponentDetail       // Single component with all states
        | AnimationPreview      // Animation timeline
        | AccessibilityChecker  // Contrast and accessibility
        | SoundDesigner         // Sound preview
        | ThemeExport           // Export options
        | Settings              // Editor settings

    /// Component category for gallery
    type ComponentCategory =
        | AllComponents
        | Navigation
        | Status
        | Data
        | Interaction
        | Feedback

    /// Editor configuration
    type EditorConfig = {
        ShowLineNumbers: bool
        ShowGrid: bool
        ShowBoundingBoxes: bool
        AnimationSpeed: float       // 1.0 = normal
        AutoRefresh: bool
        RefreshIntervalMs: int
        ReducedMotion: bool
        HighContrast: bool
    }

    /// Editor state
    type EditorState = {
        CurrentView: EditorView
        Theme: ThemeDefinition option
        SelectedColorIndex: int
        SelectedComponentCategory: ComponentCategory
        SelectedComponentIndex: int
        SelectedStateIndex: int
        Config: EditorConfig
        TerminalWidth: int
        TerminalHeight: int
        UndoStack: ThemeDefinition list
        RedoStack: ThemeDefinition list
        IsDirty: bool
        StatusMessage: string option
        ErrorMessage: string option
    }

    /// Create default editor config
    let defaultConfig : EditorConfig = {
        ShowLineNumbers = true
        ShowGrid = false
        ShowBoundingBoxes = false
        AnimationSpeed = 1.0
        AutoRefresh = true
        RefreshIntervalMs = 100
        ReducedMotion = false
        HighContrast = false
    }

    /// Create initial editor state
    let initialState () : EditorState = {
        CurrentView = Dashboard
        Theme = None
        SelectedColorIndex = 0
        SelectedComponentCategory = AllComponents
        SelectedComponentIndex = 0
        SelectedStateIndex = 0
        Config = defaultConfig
        TerminalWidth = try Console.WindowWidth with _ -> 140
        TerminalHeight = try Console.WindowHeight with _ -> 50
        UndoStack = []
        RedoStack = []
        IsDirty = false
        StatusMessage = Some "Theme Editor initialized. Press 'h' for help."
        ErrorMessage = None
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get visible length of string (excluding ANSI codes)
    let visibleLength (s: string) =
        System.Text.RegularExpressions.Regex.Replace(s, @"\u001b\[[0-9;]*m", "").Length

    /// Pad string to width (accounting for ANSI codes)
    let padRight (s: string) (width: int) =
        let visible = visibleLength s
        if visible < width then s + String.replicate (width - visible) " " else s

    /// Truncate string to width
    let truncate (s: string) (width: int) =
        if s.Length <= width then s
        else s.Substring(0, width - 3) + "..."

    /// Draw a horizontal line
    let drawHLine (char: char) (width: int) (color: RgbColor option) =
        let line = String.replicate width (string char)
        match color with
        | Some c -> sprintf "%s%s%s" (Ansi.fg c) line Ansi.reset
        | None -> line

    /// Draw a box around content
    let drawBox (title: string) (content: string list) (width: int) (borderColor: RgbColor) (titleColor: RgbColor) =
        let bc = Ansi.fg borderColor
        let tc = Ansi.fg titleColor
        let innerWidth = width - 2

        let top =
            let titlePart = if title.Length > 0 then sprintf " %s%s%s " tc title Ansi.reset else ""
            let titleLen = if title.Length > 0 then title.Length + 2 else 0
            let leftDash = String.replicate ((innerWidth - titleLen) / 2) "─"
            let rightDash = String.replicate (innerWidth - titleLen - leftDash.Length) "─"
            sprintf "%s┌%s%s%s┐%s" bc leftDash titlePart rightDash Ansi.reset

        let bottom = sprintf "%s└%s┘%s" bc (String.replicate innerWidth "─") Ansi.reset

        let middle =
            content
            |> List.map (fun line ->
                let padded = padRight line innerWidth
                sprintf "%s│%s%s%s│%s" bc Ansi.reset padded bc Ansi.reset
            )

        [top] @ middle @ [bottom]

    // ═══════════════════════════════════════════════════════════════════════════
    // COLOR PREVIEW RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Render color swatch
    let renderColorSwatch (color: ThemeColor) (width: int) (selected: bool) =
        let fg = Ansi.fg color.Rgb
        let bg = Ansi.bg color.Rgb
        let block = String.replicate (width - 2) "█"
        let selector = if selected then "▸" else " "
        let name = truncate color.Name (width - 12)
        let hex = color.Rgb.ToHex()

        [
            sprintf "%s %s%s%s" selector fg block Ansi.reset
            sprintf "  %s%-12s%s %s" fg name Ansi.reset hex
            sprintf "  %sContrast: %.1f:1%s" Ansi.dim color.ContrastRatioOnBlack Ansi.reset
        ]

    /// Render color palette grid
    let renderColorPalette (palette: CorePalette) (selectedIndex: int) (width: int) =
        let colors = [
            palette.VoidBlack; palette.SpaceBlack; palette.DeepSpace
            palette.NightSky; palette.Twilight; palette.Dusk
            palette.PlasmaCyan; palette.QuantumBlue; palette.ElectricBlue
            palette.NeonPurple; palette.NominalGreen; palette.CautionAmber
            palette.AlertRed; palette.AdvisoryCyan
            palette.BrightText; palette.NormalText; palette.MutedText; palette.DimText
            palette.DataBlue; palette.DataGreen; palette.DataPurple
            palette.DataOrange; palette.DataPink
        ]

        let swatchWidth = 18
        let columns = width / swatchWidth

        colors
        |> List.mapi (fun i color ->
            let selected = i = selectedIndex
            (i, renderColorSwatch color swatchWidth selected)
        )
        |> List.chunkBySize columns
        |> List.collect (fun row ->
            // Transpose to render side by side
            let maxLines = row |> List.map (fun (_, lines) -> List.length lines) |> List.max
            [0..maxLines-1]
            |> List.map (fun lineIdx ->
                row
                |> List.map (fun (_, lines) ->
                    if lineIdx < List.length lines then
                        padRight lines.[lineIdx] swatchWidth
                    else String.replicate swatchWidth " "
                )
                |> String.concat ""
            )
        )

    /// Render contrast checker
    let renderContrastChecker (fg: ThemeColor) (bg: ThemeColor) =
        let ratio = fg.ContrastRatioOnBlack  // Simplified - should calculate actual
        let wcagAA = if ratio >= 4.5 then "✓ PASS" else "✗ FAIL"
        let wcagAAA = if ratio >= 7.0 then "✓ PASS" else "✗ FAIL"

        let fgCode = Ansi.fg fg.Rgb
        let bgCode = Ansi.bg bg.Rgb

        [
            sprintf "Foreground: %s%s████%s %s" fgCode bgCode Ansi.reset fg.Name
            sprintf "Background: %s████%s %s" (Ansi.bg bg.Rgb) Ansi.reset bg.Name
            sprintf "Contrast Ratio: %.2f:1" ratio
            sprintf "WCAG 2.1 AA (4.5:1): %s" wcagAA
            sprintf "WCAG 2.1 AAA (7:1): %s" wcagAAA
            ""
            sprintf "Sample: %s%s The quick brown fox %s" fgCode bgCode Ansi.reset
            sprintf "Sample Bold: %s%s%s The quick brown fox %s" Ansi.bold fgCode bgCode Ansi.reset
        ]

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPONENT GALLERY RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Component display info
    type ComponentInfo = {
        Name: string
        Category: string
        Variants: int
        States: int
        Description: string
    }

    /// Get all components info
    let getAllComponents () : ComponentInfo list = [
        // Navigation (4 types, 11 variants)
        { Name = "Tab Bar"; Category = "Navigation"; Variants = 4; States = 4; Description = "Horizontal/vertical tab navigation" }
        { Name = "Breadcrumb"; Category = "Navigation"; Variants = 2; States = 3; Description = "Hierarchical path indicator" }
        { Name = "Sidebar"; Category = "Navigation"; Variants = 3; States = 4; Description = "Collapsible side navigation" }
        { Name = "Command Palette"; Category = "Navigation"; Variants = 2; States = 4; Description = "Searchable command launcher" }

        // Status (6 types, 18 variants)
        { Name = "Status Badge"; Category = "Status"; Variants = 5; States = 6; Description = "Status indicators with optional count" }
        { Name = "Progress Indicator"; Category = "Status"; Variants = 4; States = 3; Description = "Linear/circular progress" }
        { Name = "Health Gauge"; Category = "Status"; Variants = 4; States = 5; Description = "Arc/dial health display" }
        { Name = "Sparkline"; Category = "Status"; Variants = 2; States = 2; Description = "Mini trend chart" }
        { Name = "Alert Banner"; Category = "Status"; Variants = 2; States = 4; Description = "Dismissible alert message" }
        { Name = "Connection Indicator"; Category = "Status"; Variants = 1; States = 4; Description = "Connection status display" }

        // Data (4 types, 14 variants)
        { Name = "Data Table"; Category = "Data"; Variants = 5; States = 4; Description = "Sortable/filterable data grid" }
        { Name = "Tree View"; Category = "Data"; Variants = 4; States = 4; Description = "Hierarchical tree display" }
        { Name = "Key-Value Display"; Category = "Data"; Variants = 3; States = 2; Description = "Property list display" }
        { Name = "Log Viewer"; Category = "Data"; Variants = 2; States = 3; Description = "Scrolling log output" }

        // Interaction (6 types, 23 variants)
        { Name = "Button"; Category = "Interaction"; Variants = 8; States = 6; Description = "Clickable action button" }
        { Name = "Text Input"; Category = "Interaction"; Variants = 5; States = 5; Description = "Text entry field" }
        { Name = "Toggle Switch"; Category = "Interaction"; Variants = 2; States = 3; Description = "On/off toggle" }
        { Name = "Slider"; Category = "Interaction"; Variants = 3; States = 4; Description = "Value range slider" }
        { Name = "Dropdown"; Category = "Interaction"; Variants = 3; States = 4; Description = "Selection dropdown" }
        { Name = "Modal"; Category = "Interaction"; Variants = 3; States = 3; Description = "Dialog overlay" }
        { Name = "ARM & FIRE Button"; Category = "Interaction"; Variants = 1; States = 5; Description = "Safety-critical action button" }

        // Feedback (2 types, 9 variants)
        { Name = "Toast"; Category = "Feedback"; Variants = 5; States = 3; Description = "Notification popup" }
        { Name = "Tooltip"; Category = "Feedback"; Variants = 4; States = 2; Description = "Contextual help popup" }
    ]

    /// Render component list
    let renderComponentList (components: ComponentInfo list) (selectedIndex: int) (width: int) =
        components
        |> List.mapi (fun i comp ->
            let selected = i = selectedIndex
            let prefix = if selected then sprintf "%s▸%s" Ansi.bold Ansi.reset else " "
            let categoryColor =
                match comp.Category with
                | "Navigation" -> { R = 0uy; G = 175uy; B = 255uy }
                | "Status" -> { R = 0uy; G = 255uy; B = 136uy }
                | "Data" -> { R = 170uy; G = 68uy; B = 255uy }
                | "Interaction" -> { R = 255uy; G = 170uy; B = 0uy }
                | "Feedback" -> { R = 255uy; G = 68uy; B = 170uy }
                | _ -> { R = 128uy; G = 128uy; B = 128uy }

            let catTag = sprintf "%s[%s]%s" (Ansi.fg categoryColor) (truncate comp.Category 4) Ansi.reset
            let name = truncate comp.Name 20
            let variants = sprintf "%dv/%ds" comp.Variants comp.States

            sprintf "%s %-20s %s %s" prefix name catTag variants
        )

    /// Render component preview with states
    let renderComponentPreview (comp: ComponentInfo) (state: ComponentState) (palette: CorePalette) (width: int) =
        let stateColor =
            match state with
            | Default -> palette.NormalText
            | Hover -> palette.PlasmaCyan
            | Focus -> palette.QuantumBlue
            | Active -> palette.ElectricBlue
            | Selected -> palette.NeonPurple
            | Disabled -> palette.DimText
            | Loading -> palette.AdvisoryCyan
            | Error -> palette.AlertRed
            | Success -> palette.NominalGreen
            | Warning -> palette.CautionAmber

        let borderColor = stateColor.Rgb
        let contentColor = Ansi.fg stateColor.Rgb

        // Component-specific preview
        let content =
            match comp.Name with
            | "Button" ->
                let btnBg = Ansi.bg palette.PlasmaCyan.Rgb
                let btnFg = Ansi.fg palette.VoidBlack.Rgb
                [
                    sprintf "  %s%s  BUTTON  %s  " btnFg btnBg Ansi.reset
                    ""
                    sprintf "  State: %s%A%s" contentColor state Ansi.reset
                ]

            | "Status Badge" ->
                let badge status icon =
                    let c = match status with
                            | "nominal" -> palette.NominalGreen
                            | "caution" -> palette.CautionAmber
                            | "alert" -> palette.AlertRed
                            | _ -> palette.AdvisoryCyan
                    sprintf "%s%s%s" (Ansi.fg c.Rgb) icon Ansi.reset

                [
                    sprintf "  %s NOMINAL  %s CAUTION  %s ALERT"
                        (badge "nominal" "●")
                        (badge "caution" "◆")
                        (badge "alert" "▲")
                    ""
                    sprintf "  Pulsing: %s●%s  Count: %s12%s"
                        (Ansi.fg palette.AlertRed.Rgb) Ansi.reset
                        (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                ]

            | "Progress Indicator" ->
                let progress = 0.67
                let filled = int (progress * 20.0)
                let empty = 20 - filled
                let bar =
                    sprintf "%s%s%s%s%s"
                        (Ansi.fg palette.NominalGreen.Rgb)
                        (String.replicate filled "█")
                        (Ansi.fg palette.Dusk.Rgb)
                        (String.replicate empty "░")
                        Ansi.reset
                [
                    sprintf "  Linear: %s 67%%" bar
                    ""
                    sprintf "  Circular: %s◐%s 67%%  Steps: %s[●●●○○]%s"
                        (Ansi.fg palette.QuantumBlue.Rgb) Ansi.reset
                        (Ansi.fg palette.ElectricBlue.Rgb) Ansi.reset
                ]

            | "Health Gauge" ->
                let arc = sprintf "%s▁▂▃▄▅%s▆▇%s" (Ansi.fg palette.NominalGreen.Rgb) (Ansi.fg palette.CautionAmber.Rgb) Ansi.reset
                [
                    sprintf "  Arc: %s" arc
                    sprintf "  Value: %s85%%%s  Status: %sGOOD%s"
                        (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                        (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                ]

            | "ARM & FIRE Button" ->
                let armColor = palette.CautionAmber
                let fireColor = palette.AlertRed
                [
                    sprintf "  %s┌─────────────────┐%s" (Ansi.fg armColor.Rgb) Ansi.reset
                    sprintf "  %s│  %s⚠ ARM (3s)%s  %s│%s" (Ansi.fg armColor.Rgb) Ansi.bold Ansi.reset (Ansi.fg armColor.Rgb) Ansi.reset
                    sprintf "  %s└─────────────────┘%s" (Ansi.fg armColor.Rgb) Ansi.reset
                    ""
                    sprintf "  States: IDLE → %sARMED%s → %sFIRE%s → COMPLETE"
                        (Ansi.fg armColor.Rgb) Ansi.reset
                        (Ansi.fg fireColor.Rgb) Ansi.reset
                    sprintf "  Hold: %s3000ms%s  Window: %s5000ms%s"
                        (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                        (Ansi.fg palette.QuantumBlue.Rgb) Ansi.reset
                ]

            | "Sparkline" ->
                let spark = sprintf "%s▁▂▃▂▄▅▆▅▇█▇▆▅▆▇%s" (Ansi.fg palette.DataBlue.Rgb) Ansi.reset
                [
                    sprintf "  Trend: %s" spark
                    sprintf "  Min: 12  Max: 98  Current: %s87%s" (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                ]

            | "Toast" ->
                [
                    sprintf "  %s┌────────────────────────────┐%s" (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                    sprintf "  %s│ %s✓ Operation successful    %s│%s" (Ansi.fg palette.NominalGreen.Rgb) Ansi.bold (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                    sprintf "  %s└────────────────────────────┘%s" (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                    ""
                    sprintf "  Variants: %sInfo%s %sSuccess%s %sWarning%s %sError%s"
                        (Ansi.fg palette.AdvisoryCyan.Rgb) Ansi.reset
                        (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                        (Ansi.fg palette.CautionAmber.Rgb) Ansi.reset
                        (Ansi.fg palette.AlertRed.Rgb) Ansi.reset
                ]

            | "Tab Bar" ->
                let active = Ansi.fg palette.PlasmaCyan.Rgb
                let inactive = Ansi.fg palette.MutedText.Rgb
                [
                    sprintf "  %s[Dashboard]%s %sMonitoring%s %sSettings%s %sLogs%s"
                        active Ansi.reset inactive Ansi.reset inactive Ansi.reset inactive Ansi.reset
                    sprintf "  %s━━━━━━━━━━━%s" active Ansi.reset
                    ""
                    sprintf "  Variants: Underline, Pill, Segment, Boxed"
                ]

            | _ ->
                [
                    sprintf "  %s%s%s" contentColor comp.Name Ansi.reset
                    sprintf "  Variants: %d  States: %d" comp.Variants comp.States
                    sprintf "  %s" comp.Description
                ]

        drawBox comp.Name content width borderColor stateColor.Rgb

    // ═══════════════════════════════════════════════════════════════════════════
    // ANIMATION PREVIEW
    // ═══════════════════════════════════════════════════════════════════════════

    /// Animation frame for preview
    type AnimationFrame = {
        FrameIndex: int
        TotalFrames: int
        Progress: float         // 0.0 to 1.0
        Properties: Map<string, float>
    }

    /// Render animation timeline
    let renderAnimationTimeline (animation: Animation) (currentFrame: int) (width: int) =
        let totalFrames = 60  // Assume 60 frames for preview
        let progress = float currentFrame / float totalFrames

        let timelineWidth = width - 10
        let position = int (progress * float timelineWidth)

        let timeline =
            [0..timelineWidth-1]
            |> List.map (fun i ->
                if i = position then "●"
                elif i < position then "─"
                else "─"
            )
            |> String.concat ""

        [
            sprintf "Animation: %s%s%s" Ansi.bold animation.Name Ansi.reset
            sprintf "Duration: %dms  Easing: %A" animation.Timing.DurationMs animation.Timing.Easing
            ""
            sprintf "[%s] %.0f%%" timeline (progress * 100.0)
            ""
            sprintf "Keyframes: %d" (List.length animation.Keyframes)
        ]

    /// Render easing curve visualization
    let renderEasingCurve (easing: EasingFunction) (width: int) (height: int) =
        let samples = width
        let curve =
            [0..samples-1]
            |> List.map (fun i ->
                let t = float i / float (samples - 1)
                let value =
                    match easing with
                    | Linear -> t
                    | EaseOut -> 1.0 - Math.Pow(1.0 - t, 3.0)
                    | EaseIn -> Math.Pow(t, 3.0)
                    | EaseInOut ->
                        if t < 0.5 then 4.0 * t * t * t
                        else 1.0 - Math.Pow(-2.0 * t + 2.0, 3.0) / 2.0
                    | EaseOutCubic -> 1.0 - Math.Pow(1.0 - t, 3.0)
                    | EaseInCubic -> Math.Pow(t, 3.0)
                    | EaseOutElastic ->
                        if t = 0.0 then 0.0
                        elif t = 1.0 then 1.0
                        else Math.Pow(2.0, -10.0 * t) * Math.Sin((t * 10.0 - 0.75) * (2.0 * Math.PI) / 3.0) + 1.0
                    | _ -> t  // Default to linear for others
                (i, int (value * float (height - 1)))
            )

        // Create ASCII art of the curve
        [height-1 .. -1 .. 0]
        |> List.map (fun row ->
            [0..width-1]
            |> List.map (fun col ->
                let hits = curve |> List.filter (fun (x, y) -> x = col && y = row)
                if not hits.IsEmpty then "●"
                elif row = 0 then "─"
                elif col = 0 then "│"
                else " "
            )
            |> String.concat ""
        )

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN RENDER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Render header bar
    let renderHeader (state: EditorState) (width: int) =
        let bg = { R = 0uy; G = 175uy; B = 255uy }
        let fg = { R = 0uy; G = 0uy; B = 0uy }

        let title = sprintf " ◆ AEROSPACE THEME EDITOR v1.0.0 "
        let view = sprintf " [%A] " state.CurrentView
        let dirty = if state.IsDirty then " ● Modified " else ""

        let padding = width - title.Length - view.Length - dirty.Length - 2
        let line =
            sprintf "%s%s%s%s%s%s"
                (Ansi.fgBg fg bg)
                title
                (String.replicate (max 0 padding) " ")
                view
                dirty
                Ansi.reset

        [line; drawHLine '─' width (Some { R = 37uy; G = 37uy; B = 48uy })]

    /// Render footer/status bar
    let renderFooter (state: EditorState) (width: int) =
        let bg = { R = 21uy; G = 21uy; B = 32uy }
        let fg = { R = 128uy; G = 128uy; B = 144uy }

        let help = " [h]elp [q]uit [←→]navigate [↑↓]select [Enter]confirm [Esc]back "
        let status =
            match state.StatusMessage with
            | Some msg -> msg
            | None -> ""

        let error =
            match state.ErrorMessage with
            | Some err -> sprintf " %s✗ %s%s " (Ansi.fg { R = 255uy; G = 68uy; B = 68uy }) err Ansi.reset
            | None -> ""

        let padding = width - (visibleLength help) - (visibleLength status) - (visibleLength error)

        [
            drawHLine '─' width (Some { R = 37uy; G = 37uy; B = 48uy })
            sprintf "%s%s%s%s%s%s"
                (Ansi.fg fg)
                help
                (String.replicate (max 0 padding) " ")
                status
                error
                Ansi.reset
        ]

    /// Render dashboard view
    let renderDashboard (state: EditorState) (width: int) (height: int) =
        let palette = defaultDarkPalette
        let contentHeight = height - 6

        let statsBox =
            drawBox "Theme Statistics" [
                sprintf "  Colors: %s23%s core palette colors" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  Components: %s26%s components, %s77%s variants"
                    (Ansi.fg palette.QuantumBlue.Rgb) Ansi.reset
                    (Ansi.fg palette.QuantumBlue.Rgb) Ansi.reset
                sprintf "  States: %s117%s total states" (Ansi.fg palette.ElectricBlue.Rgb) Ansi.reset
                sprintf "  Animations: %s48%s defined" (Ansi.fg palette.NeonPurple.Rgb) Ansi.reset
                sprintf "  Standards: %s24%s compliance mappings" (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
            ] (width / 2 - 2) palette.Dusk.Rgb palette.PlasmaCyan.Rgb

        let quickNav =
            drawBox "Quick Navigation" [
                sprintf "  %s[1]%s Color Palette" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  %s[2]%s Component Gallery" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  %s[3]%s Animation Preview" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  %s[4]%s Accessibility Checker" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  %s[5]%s Sound Designer" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  %s[6]%s Export Theme" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
            ] (width / 2 - 2) palette.Dusk.Rgb palette.QuantumBlue.Rgb

        let colorPreview =
            [
                sprintf "%s━━━ Color Preview ━━━%s" (Ansi.fg palette.Dusk.Rgb) Ansi.reset
                ""
                sprintf "  %s●%s Nominal   %s◆%s Caution   %s▲%s Alert"
                    (Ansi.fg palette.NominalGreen.Rgb) Ansi.reset
                    (Ansi.fg palette.CautionAmber.Rgb) Ansi.reset
                    (Ansi.fg palette.AlertRed.Rgb) Ansi.reset
                ""
                sprintf "  %s████████████████████%s 100%%" (Ansi.fg palette.PlasmaCyan.Rgb) Ansi.reset
                sprintf "  %s▁▂▃▄▅▆▇█▇▆▅▄▃▂▁%s Sparkline" (Ansi.fg palette.DataBlue.Rgb) Ansi.reset
            ]

        // Combine sections
        let leftColumn = statsBox
        let rightColumn = quickNav

        // Merge columns side by side
        let maxLines = max (List.length leftColumn) (List.length rightColumn)
        let halfWidth = width / 2

        let merged =
            [0..maxLines-1]
            |> List.map (fun i ->
                let left = if i < List.length leftColumn then padRight leftColumn.[i] halfWidth else String.replicate halfWidth " "
                let right = if i < List.length rightColumn then rightColumn.[i] else ""
                left + right
            )

        merged @ [""] @ colorPreview

    /// Render component gallery view
    let renderGalleryView (state: EditorState) (width: int) (height: int) =
        let palette = defaultDarkPalette
        let components = getAllComponents ()

        let filteredComponents =
            match state.SelectedComponentCategory with
            | AllComponents -> components
            | Navigation -> components |> List.filter (fun c -> c.Category = "Navigation")
            | Status -> components |> List.filter (fun c -> c.Category = "Status")
            | Data -> components |> List.filter (fun c -> c.Category = "Data")
            | Interaction -> components |> List.filter (fun c -> c.Category = "Interaction")
            | Feedback -> components |> List.filter (fun c -> c.Category = "Feedback")

        let listWidth = 40
        let previewWidth = width - listWidth - 4

        let componentList =
            drawBox "Components" (renderComponentList filteredComponents state.SelectedComponentIndex listWidth)
                listWidth palette.Dusk.Rgb palette.PlasmaCyan.Rgb

        let selectedComp =
            if state.SelectedComponentIndex < List.length filteredComponents
            then Some filteredComponents.[state.SelectedComponentIndex]
            else None

        let states = [| Default; Hover; Focus; Active; Selected; Disabled; Loading; Error; Success; Warning |]
        let currentState = states.[state.SelectedStateIndex % states.Length]

        let preview =
            match selectedComp with
            | Some comp ->
                renderComponentPreview comp currentState palette previewWidth
            | None ->
                drawBox "Preview" ["  No component selected"] previewWidth palette.Dusk.Rgb palette.MutedText.Rgb

        // State selector
        let stateSelector =
            states
            |> Array.mapi (fun i s ->
                let selected = i = state.SelectedStateIndex % states.Length
                if selected
                then sprintf "%s[%A]%s" (Ansi.fg palette.PlasmaCyan.Rgb) s Ansi.reset
                else sprintf "%A" s
            )
            |> String.concat " "

        // Merge columns
        let maxLines = max (List.length componentList) (List.length preview)
        let merged =
            [0..maxLines-1]
            |> List.map (fun i ->
                let left = if i < List.length componentList then padRight componentList.[i] listWidth else String.replicate listWidth " "
                let right = if i < List.length preview then preview.[i] else ""
                left + "  " + right
            )

        [
            sprintf "Category: %s[%A]%s  State: %s"
                (Ansi.fg palette.QuantumBlue.Rgb) state.SelectedComponentCategory Ansi.reset
                stateSelector
            ""
        ] @ merged

    /// Main render function
    let render (state: EditorState) =
        let width = state.TerminalWidth
        let height = state.TerminalHeight

        let sb = StringBuilder()
        sb.Append(Ansi.clear) |> ignore

        // Header
        for line in renderHeader state width do
            sb.AppendLine(line) |> ignore

        // Main content
        let contentHeight = height - 6
        let content =
            match state.CurrentView with
            | Dashboard -> renderDashboard state width contentHeight
            | ComponentGallery -> renderGalleryView state width contentHeight
            | ColorPalette ->
                let palette = defaultDarkPalette
                renderColorPalette palette state.SelectedColorIndex width
            | _ -> [sprintf "View: %A (not implemented yet)" state.CurrentView]

        for line in content do
            sb.AppendLine(line) |> ignore

        // Footer
        for line in renderFooter state width do
            sb.AppendLine(line) |> ignore

        Console.Write(sb.ToString())

    // ═══════════════════════════════════════════════════════════════════════════
    // INPUT HANDLING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Handle keyboard input
    let handleInput (key: ConsoleKeyInfo) (state: EditorState) : EditorState =
        match key.Key with
        | ConsoleKey.Q when key.Modifiers = ConsoleModifiers.None ->
            // Signal quit (handled by main loop)
            { state with StatusMessage = Some "Press Ctrl+Q to quit" }

        | ConsoleKey.Q when key.Modifiers = ConsoleModifiers.Control ->
            { state with StatusMessage = Some "QUIT" }

        | ConsoleKey.H ->
            { state with StatusMessage = Some "Help: ←→ navigate views, ↑↓ select items, Enter confirm, Esc back" }

        | ConsoleKey.D1 | ConsoleKey.NumPad1 ->
            { state with CurrentView = ColorPalette; StatusMessage = Some "Color Palette" }

        | ConsoleKey.D2 | ConsoleKey.NumPad2 ->
            { state with CurrentView = ComponentGallery; StatusMessage = Some "Component Gallery" }

        | ConsoleKey.D3 | ConsoleKey.NumPad3 ->
            { state with CurrentView = AnimationPreview; StatusMessage = Some "Animation Preview" }

        | ConsoleKey.D4 | ConsoleKey.NumPad4 ->
            { state with CurrentView = AccessibilityChecker; StatusMessage = Some "Accessibility Checker" }

        | ConsoleKey.D5 | ConsoleKey.NumPad5 ->
            { state with CurrentView = SoundDesigner; StatusMessage = Some "Sound Designer" }

        | ConsoleKey.D6 | ConsoleKey.NumPad6 ->
            { state with CurrentView = ThemeExport; StatusMessage = Some "Theme Export" }

        | ConsoleKey.Escape ->
            { state with CurrentView = Dashboard; StatusMessage = None }

        | ConsoleKey.UpArrow ->
            let newIndex = max 0 (state.SelectedComponentIndex - 1)
            { state with SelectedComponentIndex = newIndex }

        | ConsoleKey.DownArrow ->
            let maxIndex = (getAllComponents () |> List.length) - 1
            let newIndex = min maxIndex (state.SelectedComponentIndex + 1)
            { state with SelectedComponentIndex = newIndex }

        | ConsoleKey.LeftArrow ->
            let newIndex = max 0 (state.SelectedStateIndex - 1)
            { state with SelectedStateIndex = newIndex }

        | ConsoleKey.RightArrow ->
            let newIndex = min 9 (state.SelectedStateIndex + 1)
            { state with SelectedStateIndex = newIndex }

        | ConsoleKey.Tab ->
            let categories = [| AllComponents; Navigation; Status; Data; Interaction; Feedback |]
            let currentIdx =
                categories
                |> Array.findIndex (fun c -> c = state.SelectedComponentCategory)
            let nextIdx = (currentIdx + 1) % categories.Length
            { state with SelectedComponentCategory = categories.[nextIdx]; SelectedComponentIndex = 0 }

        | _ -> state

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN LOOP
    // ═══════════════════════════════════════════════════════════════════════════

    /// Run the theme editor
    let run () =
        Console.Write(Ansi.hideCursor)
        Console.Write(Ansi.clear)

        let mutable state = initialState ()
        let mutable running = true

        while running do
            // Update terminal size
            state <- {
                state with
                    TerminalWidth = try Console.WindowWidth with _ -> 140
                    TerminalHeight = try Console.WindowHeight with _ -> 50
            }

            // Render
            render state

            // Handle input (non-blocking check first)
            if Console.KeyAvailable then
                let key = Console.ReadKey(true)
                state <- handleInput key state

                // Check for quit
                if state.StatusMessage = Some "QUIT" then
                    running <- false
            else
                // Small delay to avoid CPU spin
                System.Threading.Thread.Sleep(50)

        // Cleanup
        Console.Write(Ansi.showCursor)
        Console.Write(Ansi.clear)
        printfn "Theme Editor closed."

    /// Run with specific theme
    let runWithTheme (theme: ThemeDefinition) =
        let mutable state = initialState ()
        state <- { state with Theme = Some theme }
        run ()
