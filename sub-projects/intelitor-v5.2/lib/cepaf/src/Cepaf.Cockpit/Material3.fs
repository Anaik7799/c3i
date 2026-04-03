namespace Cepaf.Cockpit

open System
open System.Text

/// =============================================================================
/// MATERIAL 3 DESIGN SYSTEM FOR TERMINAL UI
/// =============================================================================
///
/// WHAT: Material 3-like design system adapted for terminal interfaces.
///       Provides consistent tokens, components, and patterns.
///
/// WHY: Material 3's principles (accessible, expressive, personal) apply
///      to terminal UIs. This creates a cohesive design language.
///
/// DESIGN TOKENS:
///   - Color Scheme: Dark theme based on Material 3 palette
///   - Typography: ANSI text styles (bold, dim, italic)
///   - Elevation: Box shadow via Unicode characters
///   - Shape: Consistent corner radii via box drawing
///
/// STAMP Compliance:
///   - SC-HMI-005: Consistent design language
///   - SC-HMI-006: Accessible color contrast ratios
///   - SC-HMI-007: Predictable component behavior
///
/// =============================================================================
module Material3 =

    // =========================================================================
    // DESIGN TOKENS - Colors (Material 3 Dark Theme)
    // =========================================================================

    module Colors =
        // Primary colors
        let primary = "\u001b[38;2;208;188;255m"        // D0BCFF - Light purple
        let onPrimary = "\u001b[38;2;56;30;114m"        // 381E72 - Dark purple
        let primaryContainer = "\u001b[38;2;79;55;139m" // 4F378B - Medium purple
        let onPrimaryContainer = "\u001b[38;2;234;221;255m" // EADDFF

        // Secondary colors
        let secondary = "\u001b[38;2;204;194;220m"      // CCC2DC
        let onSecondary = "\u001b[38;2;51;45;65m"       // 332D41
        let secondaryContainer = "\u001b[38;2;74;68;88m" // 4A4458
        let onSecondaryContainer = "\u001b[38;2;232;222;248m" // E8DEF8

        // Tertiary colors (cyan for PRAJNA advisory)
        let tertiary = "\u001b[38;2;239;184;200m"       // EFB8C8
        let onTertiary = "\u001b[38;2;73;37;50m"        // 492532
        let tertiaryContainer = "\u001b[38;2;99;59;72m" // 633B48
        let onTertiaryContainer = "\u001b[38;2;255;216;228m" // FFD8E4

        // Error colors
        let error = "\u001b[38;2;242;184;181m"          // F2B8B5
        let onError = "\u001b[38;2;96;20;16m"           // 601410
        let errorContainer = "\u001b[38;2;140;29;24m"   // 8C1D18
        let onErrorContainer = "\u001b[38;2;249;222;220m" // F9DEDC

        // Surface colors (Dark theme)
        let surface = "\u001b[38;2;28;27;31m"           // 1C1B1F - Main background
        let onSurface = "\u001b[38;2;230;225;229m"      // E6E1E5
        let surfaceVariant = "\u001b[38;2;73;69;79m"    // 49454F
        let onSurfaceVariant = "\u001b[38;2;202;196;208m" // CAC4D0
        let outline = "\u001b[38;2;147;143;153m"        // 938F99
        let outlineVariant = "\u001b[38;2;73;69;79m"    // 49454F

        // Background colors (ANSI background)
        let bgSurface = "\u001b[48;2;28;27;31m"         // Background
        let bgPrimary = "\u001b[48;2;79;55;139m"
        let bgError = "\u001b[48;2;140;29;24m"
        let bgSecondary = "\u001b[48;2;74;68;88m"

        // Semantic colors (Safety-critical)
        let normal = "\u001b[90m"                       // Gray (Dark Cockpit)
        let advisory = "\u001b[38;2;3;218;198m"         // 03DAC6 - Teal/Cyan
        let caution = "\u001b[38;2;255;179;0m"          // FFB300 - Amber
        let warning = "\u001b[38;2;207;102;121m"        // CF6679 - Red
        let critical = "\u001b[38;2;207;102;121;5m"     // Red + blink

        // Reset
        let reset = "\u001b[0m"

    // =========================================================================
    // DESIGN TOKENS - Typography
    // =========================================================================

    module Typography =
        // Display (large headers)
        let displayLarge = "\u001b[1m"     // Bold
        let displayMedium = "\u001b[1m"
        let displaySmall = "\u001b[1m"

        // Headline
        let headlineLarge = "\u001b[1m"
        let headlineMedium = "\u001b[1m"
        let headlineSmall = "\u001b[1m"

        // Title
        let titleLarge = "\u001b[1m"
        let titleMedium = "\u001b[1m"
        let titleSmall = "\u001b[1m\u001b[3m"  // Bold + Italic

        // Body
        let bodyLarge = ""
        let bodyMedium = ""
        let bodySmall = "\u001b[2m"     // Dim

        // Label
        let labelLarge = ""
        let labelMedium = "\u001b[2m"
        let labelSmall = "\u001b[2m"

        let reset = "\u001b[0m"

    // =========================================================================
    // DESIGN TOKENS - Elevation (via box characters)
    // =========================================================================

    module Elevation =
        // Level 0: No elevation (inline)
        let level0TopLeft = ""
        let level0Horizontal = ""

        // Level 1: Subtle (light box)
        let level1TopLeft = "┌"
        let level1TopRight = "┐"
        let level1BottomLeft = "└"
        let level1BottomRight = "┘"
        let level1Horizontal = "─"
        let level1Vertical = "│"

        // Level 2: Card elevation (rounded)
        let level2TopLeft = "╭"
        let level2TopRight = "╮"
        let level2BottomLeft = "╰"
        let level2BottomRight = "╯"
        let level2Horizontal = "─"
        let level2Vertical = "│"

        // Level 3: Modal elevation (double)
        let level3TopLeft = "╔"
        let level3TopRight = "╗"
        let level3BottomLeft = "╚"
        let level3BottomRight = "╝"
        let level3Horizontal = "═"
        let level3Vertical = "║"

    // =========================================================================
    // DESIGN TOKENS - Shape (Spacing, etc.)
    // =========================================================================

    module Shape =
        let paddingSmall = 1
        let paddingMedium = 2
        let paddingLarge = 4

        let gapSmall = 1
        let gapMedium = 2
        let gapLarge = 4

    // =========================================================================
    // COMPONENT: Button
    // =========================================================================

    type ButtonVariant = Filled | Outlined | Text | Tonal | Elevated

    type Button = {
        Label: string
        Variant: ButtonVariant
        Disabled: bool
        Icon: string option
    }

    let renderButton (btn: Button) =
        let (fg, bg, prefix, suffix) =
            if btn.Disabled then
                (Colors.onSurfaceVariant, "", "[", "]")
            else
                match btn.Variant with
                | Filled -> (Colors.onPrimary, Colors.bgPrimary, "[", "]")
                | Outlined -> (Colors.primary, "", "[", "]")
                | Text -> (Colors.primary, "", " ", " ")
                | Tonal -> (Colors.onSecondaryContainer, Colors.bgSecondary, "[", "]")
                | Elevated -> (Colors.primary, Colors.bgSurface, "⟨", "⟩")

        let icon = btn.Icon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
        sprintf "%s%s%s%s%s%s" fg bg prefix icon btn.Label Colors.reset + suffix

    // =========================================================================
    // COMPONENT: Card
    // =========================================================================

    type CardVariant = Filled | Outlined | Elevated

    type Card = {
        Title: string option
        Subtitle: string option
        Content: string list
        Variant: CardVariant
        Width: int
    }

    // Regex to strip ANSI escape codes for visual width calculation
    let private ansiRegex = System.Text.RegularExpressions.Regex(@"\x1b\[[0-9;]*m")
    let private visualLength (s: string) = ansiRegex.Replace(s, "").Length

    /// Truncate string to maxVisibleChars visible characters, preserving ANSI codes
    let private truncateVisible (s: string) (maxVisibleChars: int) : string =
        let sb = System.Text.StringBuilder()
        let mutable visibleCount = 0
        let mutable i = 0
        while i < s.Length && visibleCount < maxVisibleChars do
            if s.[i] = '\u001b' then
                // Found escape sequence - copy until 'm'
                while i < s.Length && s.[i] <> 'm' do
                    sb.Append(s.[i]) |> ignore
                    i <- i + 1
                if i < s.Length then
                    sb.Append(s.[i]) |> ignore  // append 'm'
                    i <- i + 1
            else
                sb.Append(s.[i]) |> ignore
                visibleCount <- visibleCount + 1
                i <- i + 1
        // Append reset code if we truncated and string had ANSI codes
        if visibleCount >= maxVisibleChars && s.Contains("\u001b[") then
            sb.Append(Colors.reset) |> ignore
        sb.ToString()

    let renderCard (card: Card) : string list =
        let (tl, tr, bl, br, h, v) =
            match card.Variant with
            | Outlined -> (Elevation.level1TopLeft, Elevation.level1TopRight, Elevation.level1BottomLeft, Elevation.level1BottomRight, Elevation.level1Horizontal, Elevation.level1Vertical)
            | Elevated -> (Elevation.level2TopLeft, Elevation.level2TopRight, Elevation.level2BottomLeft, Elevation.level2BottomRight, Elevation.level2Horizontal, Elevation.level2Vertical)
            | Filled -> (Elevation.level2TopLeft, Elevation.level2TopRight, Elevation.level2BottomLeft, Elevation.level2BottomRight, Elevation.level2Horizontal, Elevation.level2Vertical)

        // Pad/truncate based on visual width (excluding ANSI codes)
        let padRight (s: string) w =
            let vlen = visualLength s
            if vlen < w then s + String.replicate (w - vlen) " "
            elif vlen > w then truncateVisible s w
            else s

        let innerWidth = card.Width - 2
        let lines = ResizeArray<string>()

        // Top border
        lines.Add(sprintf "%s%s%s%s%s" Colors.outline tl (String.replicate innerWidth h) tr Colors.reset)

        // Title
        match card.Title with
        | Some title ->
            let titleLine = sprintf " %s%s%s%s" Typography.titleMedium Colors.onSurface title Colors.reset
            lines.Add(sprintf "%s%s%s%s%s%s%s" Colors.outline v Colors.reset (padRight titleLine innerWidth) Colors.outline v Colors.reset)
        | None -> ()

        // Subtitle
        match card.Subtitle with
        | Some sub ->
            let subLine = sprintf " %s%s%s%s" Typography.bodySmall Colors.onSurfaceVariant sub Colors.reset
            lines.Add(sprintf "%s%s%s%s%s%s%s" Colors.outline v Colors.reset (padRight subLine innerWidth) Colors.outline v Colors.reset)
        | None -> ()

        // Content
        for content in card.Content do
            let contentLine = sprintf " %s%s" Colors.onSurface content
            lines.Add(sprintf "%s%s%s%s%s%s%s" Colors.outline v Colors.reset (padRight contentLine innerWidth) Colors.outline v Colors.reset)

        // Bottom border
        lines.Add(sprintf "%s%s%s%s%s" Colors.outline bl (String.replicate innerWidth h) br Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: Chip
    // =========================================================================

    type ChipVariant = Assist | Filter | Input | Suggestion

    type Chip = {
        Label: string
        Variant: ChipVariant
        Selected: bool
        Icon: string option
    }

    let renderChip (chip: Chip) =
        let (fg, bg) =
            if chip.Selected then
                (Colors.onSecondaryContainer, Colors.bgSecondary)
            else
                match chip.Variant with
                | Assist -> (Colors.onSurfaceVariant, "")
                | Filter -> (Colors.primary, "")
                | Input -> (Colors.onSurfaceVariant, "")
                | Suggestion -> (Colors.onSurfaceVariant, "")

        let icon = chip.Icon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
        sprintf "%s%s(%s%s)%s" fg bg icon chip.Label Colors.reset

    // =========================================================================
    // COMPONENT: ListItem
    // =========================================================================

    type ListItem = {
        Headline: string
        SupportingText: string option
        LeadingIcon: string option
        TrailingIcon: string option
        TrailingText: string option
        Selected: bool
    }

    let renderListItem (item: ListItem) (width: int) =
        let leading = item.LeadingIcon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
        let trailing =
            match item.TrailingText, item.TrailingIcon with
            | Some t, Some i -> sprintf "%s %s" t i
            | Some t, None -> t
            | None, Some i -> i
            | None, None -> ""

        let mainWidth = width - String.length leading - String.length trailing - 4
        let headline =
            if item.Headline.Length > mainWidth then
                item.Headline.Substring(0, mainWidth - 3) + "..."
            else
                item.Headline

        let bgColor = if item.Selected then Colors.bgSecondary else ""
        let fgColor = if item.Selected then Colors.onSecondaryContainer else Colors.onSurface

        sprintf "%s%s %s%s%s %s%s"
            bgColor fgColor leading headline
            (String.replicate (mainWidth - headline.Length) " ")
            trailing Colors.reset

    // =========================================================================
    // COMPONENT: ProgressIndicator
    // =========================================================================

    type ProgressType = Linear | Circular | Determinate of float

    let renderProgress (ptype: ProgressType) (width: int) =
        let safeWidth = max 4 width  // Ensure minimum width for indicator
        match ptype with
        | Linear ->
            // Indeterminate - animated
            let frame = int (DateTime.UtcNow.Ticks / 1000000L) % safeWidth
            let before = String.replicate (max 0 frame) "─"
            let indicator = sprintf "%s━━━%s" Colors.primary Colors.reset
            let after = String.replicate (max 0 (safeWidth - frame - 3)) "─"
            sprintf "%s%s%s%s" Colors.outlineVariant before indicator after

        | Circular ->
            let spinners = [|"◐"; "◓"; "◑"; "◒"|]
            let frame = int (DateTime.UtcNow.Ticks / 2000000L) % 4
            sprintf "%s%s%s" Colors.primary spinners.[frame] Colors.reset

        | Determinate pct ->
            let clampedPct = pct |> max 0.0 |> min 1.0
            let filled = int (clampedPct * float safeWidth) |> max 0
            let empty = (safeWidth - filled) |> max 0
            sprintf "%s%s%s%s%s"
                Colors.primary
                (String.replicate filled "█")
                Colors.surfaceVariant
                (String.replicate empty "░")
                Colors.reset

    // =========================================================================
    // COMPONENT: SnackBar
    // =========================================================================

    type SnackBar = {
        Message: string
        Action: string option
        IsError: bool
    }

    let renderSnackBar (snack: SnackBar) (width: int) =
        let bg = if snack.IsError then Colors.bgError else Colors.bgSecondary
        let fg = if snack.IsError then Colors.onErrorContainer else Colors.onSecondaryContainer

        let action =
            snack.Action
            |> Option.map (fun a -> sprintf " [%s%s%s%s]" Colors.primary a Colors.reset fg)
            |> Option.defaultValue ""

        let content = sprintf " %s%s " snack.Message action
        let padding = max 0 (width - content.Length)

        sprintf "%s%s%s%s%s" bg fg content (String.replicate padding " ") Colors.reset

    // =========================================================================
    // COMPONENT: NavigationBar
    // =========================================================================

    type NavItem = {
        Label: string
        Icon: string
        Selected: bool
    }

    let renderNavBar (items: NavItem list) (width: int) =
        let itemWidth = width / (max 1 (List.length items))

        items
        |> List.map (fun item ->
            let (fg, style) =
                if item.Selected then (Colors.primary, Typography.labelLarge)
                else (Colors.onSurfaceVariant, Typography.labelMedium)

            let content = sprintf "%s %s" item.Icon item.Label
            let padding = max 0 ((itemWidth - content.Length) / 2)

            sprintf "%s%s%s%s%s%s"
                fg style (String.replicate padding " ") content (String.replicate padding " ") Colors.reset
        )
        |> String.concat ""

    // =========================================================================
    // COMPONENT: Badge
    // =========================================================================

    type BadgeVariant = Small | Large

    let renderBadge (variant: BadgeVariant) (count: int option) =
        match variant, count with
        | Small, _ -> sprintf "%s●%s" Colors.error Colors.reset
        | Large, Some n when n > 999 -> sprintf "%s(999+)%s" Colors.error Colors.reset
        | Large, Some n -> sprintf "%s(%d)%s" Colors.error n Colors.reset
        | Large, None -> sprintf "%s●%s" Colors.error Colors.reset

    // =========================================================================
    // COMPONENT: Divider
    // =========================================================================

    let renderDivider (width: int) (inset: int) =
        let padding = String.replicate inset " "
        let line = String.replicate (width - inset * 2) "─"
        sprintf "%s%s%s%s%s" padding Colors.outlineVariant line Colors.reset padding

    // =========================================================================
    // COMPONENT: Switch
    // =========================================================================

    let renderSwitch (isOn: bool) =
        if isOn then
            sprintf "%s[%s●  ]%s" Colors.primary Colors.onPrimary Colors.reset
        else
            sprintf "%s[  ○]%s" Colors.outline Colors.reset

    // =========================================================================
    // COMPONENT: TextField
    // =========================================================================

    type TextFieldVariant = FilledField | OutlinedField

    type TextField = {
        Label: string
        Value: string
        Variant: TextFieldVariant
        Focused: bool
        Error: string option
        Width: int
    }

    let renderTextField (tf: TextField) =
        let borderColor =
            match tf.Error, tf.Focused with
            | Some _, _ -> Colors.error
            | None, true -> Colors.primary
            | None, false -> Colors.outline

        let valueDisplay =
            if tf.Value.Length > tf.Width - 4 then
                tf.Value.Substring(tf.Value.Length - tf.Width + 4)
            else
                tf.Value + String.replicate (tf.Width - 4 - tf.Value.Length) " "

        let cursor = if tf.Focused then "│" else " "

        [
            sprintf "%s%s%s%s" Colors.onSurfaceVariant Typography.labelSmall tf.Label Colors.reset
            sprintf "%s┌%s┐%s" borderColor (String.replicate (tf.Width - 2) "─") Colors.reset
            sprintf "%s│%s %s%s%s│%s" borderColor Colors.onSurface valueDisplay cursor borderColor Colors.reset
            sprintf "%s└%s┘%s" borderColor (String.replicate (tf.Width - 2) "─") Colors.reset
        ] @ (
            tf.Error
            |> Option.map (fun e -> [sprintf "%s%s%s" Colors.error e Colors.reset])
            |> Option.defaultValue []
        )

    // =========================================================================
    // COMPONENT: Dialog
    // =========================================================================

    type Dialog = {
        Title: string
        Content: string list
        Actions: Button list
        Width: int
    }

    let renderDialog (dialog: Dialog) : string list =
        let w = dialog.Width
        let inner = w - 2
        let lines = ResizeArray<string>()

        // Scrim effect (darken)
        lines.Add(sprintf "%s%s%s" Colors.bgSurface (String.replicate w " ") Colors.reset)

        // Top border (level 3 elevation)
        lines.Add(sprintf "%s%s%s%s%s" Colors.outline Elevation.level3TopLeft (String.replicate inner Elevation.level3Horizontal) Elevation.level3TopRight Colors.reset)

        // Title
        let titleLine = sprintf " %s%s%s%s" Typography.headlineSmall Colors.onSurface dialog.Title Colors.reset
        let padRight (s: string) (len: int) = if s.Length < len then s + String.replicate (len - s.Length) " " else s
        lines.Add(sprintf "%s%s%s%s%s%s%s" Colors.outline Elevation.level3Vertical Colors.reset (padRight titleLine inner) Colors.outline Elevation.level3Vertical Colors.reset)

        // Divider
        lines.Add(sprintf "%s%s%s%s%s" Colors.outline Elevation.level3Vertical (String.replicate inner " ") Elevation.level3Vertical Colors.reset)

        // Content
        for line in dialog.Content do
            let contentLine = sprintf " %s%s" Colors.onSurfaceVariant line
            lines.Add(sprintf "%s%s%s%s%s%s%s" Colors.outline Elevation.level3Vertical Colors.reset (padRight contentLine inner) Colors.outline Elevation.level3Vertical Colors.reset)

        // Spacer
        lines.Add(sprintf "%s%s%s%s%s" Colors.outline Elevation.level3Vertical (String.replicate inner " ") Elevation.level3Vertical Colors.reset)

        // Actions
        let actionsStr = dialog.Actions |> List.map renderButton |> String.concat "  "
        let actionsLine = sprintf " %s%s" actionsStr (String.replicate (max 0 (inner - actionsStr.Length - 2)) " ")
        lines.Add(sprintf "%s%s%s%s%s%s%s" Colors.outline Elevation.level3Vertical Colors.reset (padRight actionsLine inner) Colors.outline Elevation.level3Vertical Colors.reset)

        // Bottom border
        lines.Add(sprintf "%s%s%s%s%s" Colors.outline Elevation.level3BottomLeft (String.replicate inner Elevation.level3Horizontal) Elevation.level3BottomRight Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: FAB (Floating Action Button)
    // =========================================================================

    type FabSize = FabSmall | FabRegular | FabLarge | FabExtended of string

    let renderFab (icon: string) (size: FabSize) =
        match size with
        | FabSmall ->
            sprintf "%s%s(%s)%s" Colors.bgPrimary Colors.onPrimary icon Colors.reset
        | FabRegular ->
            sprintf "%s%s( %s )%s" Colors.bgPrimary Colors.onPrimary icon Colors.reset
        | FabLarge ->
            sprintf "%s%s(( %s ))%s" Colors.bgPrimary Colors.onPrimary icon Colors.reset
        | FabExtended label ->
            sprintf "%s%s( %s %s )%s" Colors.bgPrimary Colors.onPrimary icon label Colors.reset

    // =========================================================================
    // COMPONENT: Tabs
    // =========================================================================

    type Tab = {
        Label: string
        Icon: string option
        Active: bool
    }

    let renderTabs (tabs: Tab list) =
        tabs
        |> List.map (fun tab ->
            let icon = tab.Icon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
            let (fg, underline) =
                if tab.Active then
                    (Colors.primary, sprintf "%s──%s" Colors.primary Colors.reset)
                else
                    (Colors.onSurfaceVariant, "  ")

            sprintf "%s%s%s%s\n%s" fg icon tab.Label Colors.reset underline
        )
        |> String.concat "  "

    // =========================================================================
    // COMPONENT: Table (Data Table)
    // =========================================================================

    type TableColumn = {
        Header: string
        Width: int
        Align: string  // "left" | "right" | "center"
    }

    type TableRow = {
        Cells: string list
        Selected: bool
    }

    let renderTable (columns: TableColumn list) (rows: TableRow list) =
        let lines = ResizeArray<string>()

        let alignCell (cell: string) (col: TableColumn) =
            let truncated =
                if cell.Length > col.Width then cell.Substring(0, col.Width - 1) + "…"
                else cell
            let padding = col.Width - truncated.Length
            match col.Align with
            | "right" -> String.replicate padding " " + truncated
            | "center" ->
                let left = padding / 2
                let right = padding - left
                String.replicate left " " + truncated + String.replicate right " "
            | _ -> truncated + String.replicate padding " "

        // Header
        let headerCells =
            List.zip columns (columns |> List.map (fun c -> c.Header))
            |> List.map (fun (col, h) -> sprintf "%s%s%s" Typography.titleSmall (alignCell h col) Typography.reset)
            |> String.concat " │ "
        lines.Add(sprintf "%s%s%s" Colors.onSurface headerCells Colors.reset)

        // Divider
        let divider =
            columns
            |> List.map (fun c -> String.replicate c.Width "─")
            |> String.concat "─┼─"
        lines.Add(sprintf "%s%s%s" Colors.outlineVariant divider Colors.reset)

        // Rows
        for row in rows do
            let bg = if row.Selected then Colors.bgSecondary else ""
            let fg = if row.Selected then Colors.onSecondaryContainer else Colors.onSurface
            let cells =
                List.zip columns row.Cells
                |> List.map (fun (col, cell) -> alignCell cell col)
                |> String.concat " │ "
            lines.Add(sprintf "%s%s%s%s" bg fg cells Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // PRAJNA-SPECIFIC COMPONENTS
    // =========================================================================

    /// Metric Card with Material 3 styling
    let renderMetricCard (label: string) (value: string) (trend: string) (level: string) (width: int) =
        let levelColor =
            match level with
            | "critical" -> Colors.critical
            | "warning" -> Colors.warning
            | "caution" -> Colors.caution
            | "advisory" -> Colors.advisory
            | _ -> Colors.onSurface

        renderCard {
            Title = Some label
            Subtitle = None
            Content = [
                sprintf "%s%s%s%s %s" levelColor Typography.displaySmall value Typography.reset trend
            ]
            Variant = Elevated
            Width = width
        }

    /// Status Chip for node status
    let renderStatusChip (status: string) =
        let (icon, color) =
            match status.ToLower() with
            | "connected" -> ("●", Colors.primary)
            | "stale" -> ("◐", Colors.caution)
            | "degraded" -> ("◑", Colors.caution)
            | "disconnected" -> ("○", Colors.error)
            | _ -> ("?", Colors.onSurfaceVariant)

        sprintf "%s%s %s%s" color icon status Colors.reset

    /// Alert Banner
    let renderAlertBanner (level: string) (message: string) (width: int) =
        let (bg, fg, icon) =
            match level with
            | "critical" -> (Colors.bgError, Colors.onErrorContainer, "☢")
            | "warning" -> (Colors.bgError, Colors.onErrorContainer, "⛔")
            | "caution" -> ("\u001b[48;2;255;179;0m", Colors.surface, "⚠")
            | _ -> (Colors.bgSecondary, Colors.onSecondaryContainer, "ℹ")

        let content = sprintf " %s %s " icon message
        let padding = max 0 (width - content.Length)

        sprintf "%s%s%s%s%s" bg fg content (String.replicate padding " ") Colors.reset

    // =========================================================================
    // COMPONENT: IconButton
    // =========================================================================

    type IconButtonVariant = Standard | Filled | FilledTonal | Outlined

    type IconButton = {
        Icon: string
        Variant: IconButtonVariant
        Selected: bool
        Disabled: bool
    }

    let renderIconButton (btn: IconButton) =
        if btn.Disabled then
            // Disabled uses dim outline color with different brackets to distinguish
            sprintf "%s(%s)%s" Colors.outline btn.Icon Colors.reset
        else
            let (fg, bg) =
                match btn.Variant, btn.Selected with
                | Filled, _ -> (Colors.onPrimary, Colors.bgPrimary)
                | FilledTonal, true -> (Colors.onSecondaryContainer, Colors.bgSecondary)
                | FilledTonal, false -> (Colors.onSecondaryContainer, "")  // No background when unselected
                | Outlined, true -> (Colors.primary, Colors.bgSecondary)
                | Outlined, false -> (Colors.onSurfaceVariant, "")
                | Standard, true -> (Colors.primary, "")
                | Standard, false -> (Colors.onSurfaceVariant, "")
            sprintf "%s%s[%s]%s" bg fg btn.Icon Colors.reset

    // =========================================================================
    // COMPONENT: SegmentedButton
    // =========================================================================

    type SegmentedButtonMode = SingleSelect | MultiSelect

    type SegmentedOption = {
        Label: string
        Icon: string option
        Selected: bool
    }

    let renderSegmentedButton (options: SegmentedOption list) (mode: SegmentedButtonMode) =
        let renderOption (opt: SegmentedOption) (isFirst: bool) (isLast: bool) =
            let icon = opt.Icon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
            let checkmark = if opt.Selected then "✓ " else ""
            let (fg, bg) =
                if opt.Selected then (Colors.onSecondaryContainer, Colors.bgSecondary)
                else (Colors.onSurface, "")
            let leftBorder = if isFirst then "⟨" else "|"
            let rightBorder = if isLast then "⟩" else ""
            sprintf "%s%s%s%s%s%s%s" bg fg leftBorder checkmark icon opt.Label Colors.reset + rightBorder

        options
        |> List.mapi (fun i opt -> renderOption opt (i = 0) (i = options.Length - 1))
        |> String.concat ""

    // =========================================================================
    // COMPONENT: SplitButton (M3 Expressive)
    // =========================================================================

    type SplitButton = {
        Label: string
        Icon: string option
        MenuExpanded: bool
    }

    let renderSplitButton (btn: SplitButton) =
        let icon = btn.Icon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
        let menuIcon = if btn.MenuExpanded then "▲" else "▼"
        sprintf "%s%s[%s%s]%s%s[%s]%s"
            Colors.bgPrimary Colors.onPrimary icon btn.Label Colors.reset
            Colors.bgSecondary menuIcon Colors.reset

    // =========================================================================
    // COMPONENT: ButtonGroup (M3 Expressive)
    // =========================================================================

    type ButtonGroupItem = {
        Label: string
        Icon: string option
        Active: bool
    }

    let renderButtonGroup (items: ButtonGroupItem list) =
        let renderItem (item: ButtonGroupItem) =
            let icon = item.Icon |> Option.map (sprintf "%s ") |> Option.defaultValue ""
            let (fg, bg) =
                if item.Active then (Colors.onPrimary, Colors.bgPrimary)
                else (Colors.onSurfaceVariant, "")
            sprintf "%s%s[%s%s]%s" bg fg icon item.Label Colors.reset

        items |> List.map renderItem |> String.concat ""

    // =========================================================================
    // COMPONENT: ToggleButton
    // =========================================================================

    type ToggleButton = {
        Icon: string
        Label: string option
        Toggled: bool
    }

    let renderToggleButton (btn: ToggleButton) =
        let label = btn.Label |> Option.map (sprintf " %s") |> Option.defaultValue ""
        let (fg, bg, border) =
            if btn.Toggled then (Colors.onPrimary, Colors.bgPrimary, "●")
            else (Colors.onSurfaceVariant, "", "○")
        sprintf "%s%s[%s %s%s]%s" bg fg border btn.Icon label Colors.reset

    // =========================================================================
    // COMPONENT: Checkbox
    // =========================================================================

    type CheckboxState = Unchecked | Checked | Indeterminate

    let renderCheckbox (state: CheckboxState) (label: string option) (disabled: bool) =
        let box =
            match state with
            | Checked -> "☑"
            | Unchecked -> "☐"
            | Indeterminate -> "▣"
        let color = if disabled then Colors.onSurfaceVariant else Colors.primary
        let labelText = label |> Option.map (sprintf " %s") |> Option.defaultValue ""
        sprintf "%s%s%s%s%s" color box Colors.onSurface labelText Colors.reset

    // =========================================================================
    // COMPONENT: RadioButton
    // =========================================================================

    let renderRadioButton (selected: bool) (label: string) (disabled: bool) =
        let radio = if selected then "◉" else "○"
        let color = if disabled then Colors.onSurfaceVariant else Colors.primary
        sprintf "%s%s %s%s%s" color radio Colors.onSurface label Colors.reset

    type RadioGroup = {
        Options: (string * bool) list  // (label, selected)
        Orientation: string  // "vertical" | "horizontal"
    }

    let renderRadioGroup (group: RadioGroup) =
        let separator = if group.Orientation = "vertical" then "\n" else "  "
        group.Options
        |> List.map (fun (label, selected) -> renderRadioButton selected label false)
        |> String.concat separator

    // =========================================================================
    // COMPONENT: Slider
    // =========================================================================

    type Slider = {
        Value: float
        Min: float
        Max: float
        Width: int
        ShowValue: bool
        Disabled: bool
    }

    let renderSlider (slider: Slider) =
        let range = slider.Max - slider.Min
        let pct = if range > 0.0 then (slider.Value - slider.Min) / range else 0.0
        let clampedPct = pct |> max 0.0 |> min 1.0
        let trackWidth = slider.Width - 4
        let thumbPos = int (clampedPct * float trackWidth)
        let before = String.replicate (max 0 thumbPos) "━"
        let after = String.replicate (max 0 (trackWidth - thumbPos - 1)) "─"
        let (trackColor, thumbColor) =
            if slider.Disabled then (Colors.onSurfaceVariant, Colors.onSurfaceVariant)
            else (Colors.primary, Colors.primary)
        let valueText =
            if slider.ShowValue then sprintf " %.0f" slider.Value else ""
        sprintf "%s%s%s●%s%s%s%s" trackColor before thumbColor after Colors.onSurface valueText Colors.reset

    // =========================================================================
    // COMPONENT: DatePicker
    // =========================================================================

    type DatePickerMode = Calendar | Input

    type DatePicker = {
        SelectedDate: DateTime option
        Mode: DatePickerMode
        Width: int
    }

    let renderDatePicker (picker: DatePicker) =
        match picker.Mode with
        | Input ->
            let dateStr =
                picker.SelectedDate
                |> Option.map (fun d -> d.ToString("yyyy-MM-dd"))
                |> Option.defaultValue "YYYY-MM-DD"
            [
                sprintf "%s📅 Select Date%s" Colors.onSurfaceVariant Colors.reset
                sprintf "%s┌%s┐%s" Colors.outline (String.replicate (picker.Width - 2) "─") Colors.reset
                sprintf "%s│%s %s %s│%s" Colors.outline Colors.onSurface dateStr (String.replicate (picker.Width - dateStr.Length - 4) " ") Colors.reset
                sprintf "%s└%s┘%s" Colors.outline (String.replicate (picker.Width - 2) "─") Colors.reset
            ]
        | Calendar ->
            let today = picker.SelectedDate |> Option.defaultValue DateTime.Today
            let header = today.ToString("MMMM yyyy")
            [
                sprintf "%s%s%s" Colors.primary header Colors.reset
                sprintf "%sSu Mo Tu We Th Fr Sa%s" Colors.onSurfaceVariant Colors.reset
                sprintf "%s 1  2  3  4  5  6  7%s" Colors.onSurface Colors.reset
                sprintf "%s 8  9 10 11 12 13 14%s" Colors.onSurface Colors.reset
                sprintf "%s15 16 17 18 19 20 21%s" Colors.onSurface Colors.reset
                sprintf "%s22 23 24 %s[25]%s 26 27 28%s" Colors.onSurface Colors.primary Colors.onSurface Colors.reset
                sprintf "%s29 30 31%s" Colors.onSurface Colors.reset
            ]

    // =========================================================================
    // COMPONENT: TimePicker
    // =========================================================================

    type TimePickerMode = Clock | TimeInput

    type TimePicker = {
        SelectedTime: TimeSpan option
        Mode: TimePickerMode
        Is24Hour: bool
    }

    let renderTimePicker (picker: TimePicker) =
        let timeStr =
            picker.SelectedTime
            |> Option.map (fun t ->
                if picker.Is24Hour then sprintf "%02d:%02d" t.Hours t.Minutes
                else
                    let h = if t.Hours > 12 then t.Hours - 12 else (if t.Hours = 0 then 12 else t.Hours)
                    let ampm = if t.Hours >= 12 then "PM" else "AM"
                    sprintf "%02d:%02d %s" h t.Minutes ampm
            )
            |> Option.defaultValue "--:--"

        match picker.Mode with
        | TimeInput ->
            [
                sprintf "%s🕐 Select Time%s" Colors.onSurfaceVariant Colors.reset
                sprintf "%s┌────┬────┐%s" Colors.outline Colors.reset
                sprintf "%s│%s %s %s│%s" Colors.outline Colors.primary timeStr Colors.outline Colors.reset
                sprintf "%s└────┴────┘%s" Colors.outline Colors.reset
            ]
        | Clock ->
            [
                sprintf "%s    12    %s" Colors.onSurface Colors.reset
                sprintf "%s  ┌────┐  %s" Colors.outline Colors.reset
                sprintf "%s9 │%s●─→%s│ 3%s" Colors.onSurface Colors.primary Colors.outline Colors.reset
                sprintf "%s  └────┘  %s" Colors.outline Colors.reset
                sprintf "%s    6     %s" Colors.onSurface Colors.reset
                sprintf "%s   %s   %s" Colors.primary timeStr Colors.reset
            ]

    // =========================================================================
    // COMPONENT: Menu / DropdownMenu
    // =========================================================================

    type MenuItem = {
        Label: string
        Icon: string option
        Shortcut: string option
        Disabled: bool
        Divider: bool
    }

    type Menu = {
        Items: MenuItem list
        Width: int
    }

    let renderMenu (menu: Menu) =
        let lines = ResizeArray<string>()
        lines.Add(sprintf "%s╭%s╮%s" Colors.outline (String.replicate (menu.Width - 2) "─") Colors.reset)

        for item in menu.Items do
            if item.Divider then
                lines.Add(sprintf "%s├%s┤%s" Colors.outline (String.replicate (menu.Width - 2) "─") Colors.reset)
            else
                let icon = item.Icon |> Option.map (sprintf "%s " ) |> Option.defaultValue "  "
                let shortcut = item.Shortcut |> Option.defaultValue ""
                let fg = if item.Disabled then Colors.onSurfaceVariant else Colors.onSurface
                let labelWidth = menu.Width - 4 - icon.Length - shortcut.Length
                let label =
                    if item.Label.Length > labelWidth then item.Label.Substring(0, labelWidth - 1) + "…"
                    else item.Label + String.replicate (labelWidth - item.Label.Length) " "
                lines.Add(sprintf "%s│%s%s%s%s%s│%s"
                    Colors.outline fg icon label Colors.onSurfaceVariant shortcut Colors.reset)

        lines.Add(sprintf "%s╰%s╯%s" Colors.outline (String.replicate (menu.Width - 2) "─") Colors.reset)
        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: ExposedDropdownMenu (Combo Box)
    // =========================================================================

    type ExposedDropdown = {
        Label: string
        SelectedValue: string
        Options: string list
        Expanded: bool
        Width: int
    }

    let renderExposedDropdown (dropdown: ExposedDropdown) =
        let lines = ResizeArray<string>()
        let arrow = if dropdown.Expanded then "▲" else "▼"
        let innerWidth = dropdown.Width - 4
        let value =
            if dropdown.SelectedValue.Length > innerWidth - 2 then
                dropdown.SelectedValue.Substring(0, innerWidth - 3) + "…"
            else dropdown.SelectedValue

        lines.Add(sprintf "%s%s%s" Colors.onSurfaceVariant dropdown.Label Colors.reset)
        lines.Add(sprintf "%s┌%s┐%s" Colors.outline (String.replicate (dropdown.Width - 2) "─") Colors.reset)
        lines.Add(sprintf "%s│%s %s%s %s%s│%s"
            Colors.outline Colors.onSurface value
            (String.replicate (innerWidth - value.Length - 1) " ")
            Colors.primary arrow Colors.reset)
        lines.Add(sprintf "%s└%s┘%s" Colors.outline (String.replicate (dropdown.Width - 2) "─") Colors.reset)

        if dropdown.Expanded then
            for opt in dropdown.Options do
                let isSelected = opt = dropdown.SelectedValue
                let (fg, bg) = if isSelected then (Colors.onSecondaryContainer, Colors.bgSecondary) else (Colors.onSurface, "")
                let optDisplay = if opt.Length > innerWidth then opt.Substring(0, innerWidth - 1) + "…" else opt
                lines.Add(sprintf "%s%s│ %s%s │%s"
                    bg fg optDisplay (String.replicate (innerWidth - optDisplay.Length) " ") Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: BottomSheet
    // =========================================================================

    type BottomSheetVariant = Standard | Modal

    type BottomSheet = {
        Title: string option
        Content: string list
        Variant: BottomSheetVariant
        Width: int
        Height: int
    }

    let renderBottomSheet (sheet: BottomSheet) =
        let lines = ResizeArray<string>()
        let innerWidth = sheet.Width - 2

        // Drag handle
        let handlePadding = (innerWidth - 4) / 2
        lines.Add(sprintf "%s%s────%s%s"
            (String.replicate handlePadding " ") Colors.onSurfaceVariant Colors.reset (String.replicate handlePadding " "))

        // Top border
        lines.Add(sprintf "%s╭%s╮%s" Colors.outline (String.replicate innerWidth "─") Colors.reset)

        // Title
        match sheet.Title with
        | Some title ->
            let titleLine = sprintf " %s%s%s" Typography.titleMedium title Typography.reset
            lines.Add(sprintf "%s│%s%s│%s"
                Colors.outline (titleLine + String.replicate (innerWidth - visualLength titleLine) " ") Colors.outline Colors.reset)
            lines.Add(sprintf "%s├%s┤%s" Colors.outline (String.replicate innerWidth "─") Colors.reset)
        | None -> ()

        // Content
        for line in sheet.Content do
            let contentLine = " " + line
            let padding = max 0 (innerWidth - visualLength contentLine)
            lines.Add(sprintf "%s│%s%s%s│%s"
                Colors.outline Colors.onSurface (contentLine + String.replicate padding " ") Colors.outline Colors.reset)

        // Fill remaining height
        let currentLines = lines.Count
        for _ in currentLines .. sheet.Height - 2 do
            lines.Add(sprintf "%s│%s│%s" Colors.outline (String.replicate innerWidth " ") Colors.reset)

        // Bottom border
        lines.Add(sprintf "%s╰%s╯%s" Colors.outline (String.replicate innerWidth "─") Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: SideSheet
    // =========================================================================

    type SideSheetPosition = Left | Right

    type SideSheet = {
        Title: string
        Content: string list
        Position: SideSheetPosition
        Width: int
        Height: int
    }

    let renderSideSheet (sheet: SideSheet) =
        let lines = ResizeArray<string>()
        let innerWidth = sheet.Width - 2

        // Top border
        lines.Add(sprintf "%s┌%s┐%s" Colors.outline (String.replicate innerWidth "─") Colors.reset)

        // Title with close button
        let closeBtn = "✕"
        let titleWidth = innerWidth - 4
        let title = if sheet.Title.Length > titleWidth then sheet.Title.Substring(0, titleWidth - 1) + "…" else sheet.Title
        lines.Add(sprintf "%s│%s %s%s%s %s%s│%s"
            Colors.outline Colors.onSurface title
            (String.replicate (titleWidth - title.Length) " ")
            Colors.onSurfaceVariant closeBtn Colors.outline Colors.reset)

        lines.Add(sprintf "%s├%s┤%s" Colors.outline (String.replicate innerWidth "─") Colors.reset)

        // Content
        for line in sheet.Content do
            let contentLine = " " + line
            let padding = max 0 (innerWidth - contentLine.Length)
            lines.Add(sprintf "%s│%s%s│%s"
                Colors.outline (contentLine + String.replicate padding " ") Colors.outline Colors.reset)

        // Fill remaining height
        let currentLines = lines.Count
        for _ in currentLines .. sheet.Height - 2 do
            lines.Add(sprintf "%s│%s│%s" Colors.outline (String.replicate innerWidth " ") Colors.reset)

        // Bottom border
        lines.Add(sprintf "%s└%s┘%s" Colors.outline (String.replicate innerWidth "─") Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: Carousel
    // =========================================================================

    type CarouselItem = {
        Content: string
        Width: int
    }

    type Carousel = {
        Items: CarouselItem list
        CurrentIndex: int
        VisibleCount: int
    }

    let renderCarousel (carousel: Carousel) =
        let lines = ResizeArray<string>()

        // Navigation arrows
        let leftArrow = if carousel.CurrentIndex > 0 then sprintf "%s◀%s " Colors.primary Colors.reset else "  "
        let rightArrow = if carousel.CurrentIndex < carousel.Items.Length - carousel.VisibleCount then sprintf " %s▶%s" Colors.primary Colors.reset else "  "

        // Visible items
        let visibleItems =
            carousel.Items
            |> List.skip carousel.CurrentIndex
            |> List.truncate carousel.VisibleCount

        let itemsStr =
            visibleItems
            |> List.map (fun item ->
                let content = if item.Content.Length > item.Width - 2 then item.Content.Substring(0, item.Width - 3) + "…" else item.Content
                sprintf "%s[%s]%s" Colors.outline content Colors.reset
            )
            |> String.concat " "

        lines.Add(sprintf "%s%s%s" leftArrow itemsStr rightArrow)

        // Dots indicator
        let dots =
            carousel.Items
            |> List.mapi (fun i _ ->
                if i = carousel.CurrentIndex then sprintf "%s●%s" Colors.primary Colors.reset
                else sprintf "%s○%s" Colors.onSurfaceVariant Colors.reset
            )
            |> String.concat " "
        lines.Add(sprintf "    %s" dots)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: TopAppBar
    // =========================================================================

    type TopAppBarVariant = CenterAligned | Small | Medium | Large

    type TopAppBar = {
        Title: string
        NavigationIcon: string option
        Actions: string list
        Variant: TopAppBarVariant
        Width: int
    }

    let renderTopAppBar (appBar: TopAppBar) =
        let navIcon = appBar.NavigationIcon |> Option.map (sprintf "%s " ) |> Option.defaultValue ""
        let actions = appBar.Actions |> String.concat " "
        let titleWidth = appBar.Width - navIcon.Length - actions.Length - 4

        match appBar.Variant with
        | CenterAligned ->
            let leftPad = (titleWidth - appBar.Title.Length) / 2
            let rightPad = titleWidth - appBar.Title.Length - leftPad
            [sprintf "%s%s%s%s%s%s %s%s"
                Colors.onSurface navIcon
                (String.replicate leftPad " ") appBar.Title (String.replicate rightPad " ")
                Colors.onSurfaceVariant actions Colors.reset]
        | Small ->
            let title = if appBar.Title.Length > titleWidth then appBar.Title.Substring(0, titleWidth - 1) + "…" else appBar.Title
            [sprintf "%s%s%s%s%s %s%s"
                Colors.onSurface navIcon title (String.replicate (titleWidth - title.Length) " ")
                Colors.onSurfaceVariant actions Colors.reset]
        | Medium ->
            [
                sprintf "%s%s%s%s%s" Colors.onSurface navIcon (String.replicate (appBar.Width - navIcon.Length - actions.Length - 2) " ") actions Colors.reset
                sprintf "%s%s%s%s" Typography.headlineMedium Colors.onSurface appBar.Title Colors.reset
            ]
        | Large ->
            [
                sprintf "%s%s%s%s%s" Colors.onSurface navIcon (String.replicate (appBar.Width - navIcon.Length - actions.Length - 2) " ") actions Colors.reset
                ""
                sprintf "%s%s%s%s" Typography.headlineLarge Colors.onSurface appBar.Title Colors.reset
            ]

    // =========================================================================
    // COMPONENT: BottomAppBar
    // =========================================================================

    type BottomAppBar = {
        Actions: string list
        FabIcon: string option
        Width: int
    }

    let renderBottomAppBar (appBar: BottomAppBar) =
        let actionsStr = appBar.Actions |> String.concat "  "
        let fab =
            appBar.FabIcon
            |> Option.map (fun icon -> sprintf "%s%s( %s )%s" Colors.bgPrimary Colors.onPrimary icon Colors.reset)
            |> Option.defaultValue ""
        let spacing = appBar.Width - visualLength actionsStr - visualLength fab - 4
        sprintf "%s%s%s%s%s"
            Colors.bgSurface
            actionsStr
            (String.replicate (max 0 spacing) " ")
            fab
            Colors.reset

    // =========================================================================
    // COMPONENT: NavigationRail
    // =========================================================================

    type NavigationRailItem = {
        Icon: string
        Label: string
        Selected: bool
        Badge: int option
    }

    type NavigationRail = {
        Items: NavigationRailItem list
        FabIcon: string option
        Alignment: string  // "top" | "center" | "bottom"
    }

    let renderNavigationRail (rail: NavigationRail) =
        let lines = ResizeArray<string>()

        // FAB at top
        match rail.FabIcon with
        | Some icon ->
            lines.Add(sprintf "%s%s( %s )%s" Colors.bgPrimary Colors.onPrimary icon Colors.reset)
            lines.Add("")
        | None -> ()

        // Navigation items
        for item in rail.Items do
            let badge =
                item.Badge
                |> Option.map (fun n -> sprintf "%s%d%s" Colors.error n Colors.reset)
                |> Option.defaultValue ""
            let (fg, indicator) =
                if item.Selected then (Colors.primary, sprintf "%s━━━%s" Colors.primary Colors.reset)
                else (Colors.onSurfaceVariant, "   ")
            lines.Add(sprintf " %s%s%s%s " fg item.Icon badge Colors.reset)
            lines.Add(sprintf " %s%s%s " fg item.Label Colors.reset)
            lines.Add(sprintf " %s " indicator)
            lines.Add("")

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: NavigationDrawer
    // =========================================================================

    type DrawerItem = {
        Icon: string
        Label: string
        Selected: bool
        Badge: string option
    }

    type NavigationDrawer = {
        Header: string option
        Items: DrawerItem list
        Width: int
    }

    let renderNavigationDrawer (drawer: NavigationDrawer) =
        let lines = ResizeArray<string>()
        let innerWidth = drawer.Width - 2

        // Header
        match drawer.Header with
        | Some h ->
            lines.Add(sprintf "%s%s%s%s" Typography.headlineSmall Colors.onSurface h Colors.reset)
            lines.Add(sprintf "%s%s%s" Colors.outlineVariant (String.replicate drawer.Width "─") Colors.reset)
        | None -> ()

        // Items
        for item in drawer.Items do
            let badge = item.Badge |> Option.map (sprintf " %s") |> Option.defaultValue ""
            let (fg, bg, indicator) =
                if item.Selected then
                    (Colors.onSecondaryContainer, Colors.bgSecondary, "●")
                else
                    (Colors.onSurfaceVariant, "", " ")
            let content = sprintf "%s %s %s%s" indicator item.Icon item.Label badge
            let padding = max 0 (innerWidth - content.Length)
            lines.Add(sprintf "%s%s%s%s%s" bg fg content (String.replicate padding " ") Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: SearchBar
    // =========================================================================

    type SearchBar = {
        Query: string
        Placeholder: string
        LeadingIcon: string
        TrailingIcon: string option
        Focused: bool
        Width: int
    }

    let renderSearchBar (search: SearchBar) =
        let borderColor = if search.Focused then Colors.primary else Colors.outline
        let innerWidth = search.Width - 4
        let trailingIcon = search.TrailingIcon |> Option.defaultValue ""
        let queryWidth = innerWidth - search.LeadingIcon.Length - trailingIcon.Length - 2
        let displayQuery =
            if search.Query.Length = 0 then sprintf "%s%s%s" Colors.onSurfaceVariant search.Placeholder Colors.reset
            elif search.Query.Length > queryWidth then search.Query.Substring(search.Query.Length - queryWidth)
            else search.Query
        let padding = max 0 (queryWidth - (if search.Query.Length = 0 then search.Placeholder.Length else search.Query.Length))
        let cursor = if search.Focused then "│" else " "

        [
            sprintf "%s╭%s╮%s" borderColor (String.replicate (search.Width - 2) "─") Colors.reset
            sprintf "%s│%s %s %s%s%s%s %s│%s"
                borderColor Colors.onSurfaceVariant search.LeadingIcon
                Colors.onSurface displayQuery cursor (String.replicate padding " ") trailingIcon Colors.reset
            sprintf "%s╰%s╯%s" borderColor (String.replicate (search.Width - 2) "─") Colors.reset
        ]

    // =========================================================================
    // COMPONENT: FloatingToolbar (M3 Expressive)
    // =========================================================================

    type FloatingToolbarVariant = Docked | Floating

    type FloatingToolbar = {
        Actions: (string * string) list  // (icon, label)
        Variant: FloatingToolbarVariant
        Width: int
    }

    let renderFloatingToolbar (toolbar: FloatingToolbar) =
        let actionsStr =
            toolbar.Actions
            |> List.map (fun (icon, label) ->
                sprintf "%s%s %s%s" Colors.onSurfaceVariant icon label Colors.reset
            )
            |> String.concat "  "

        match toolbar.Variant with
        | Docked ->
            let padding = max 0 ((toolbar.Width - visualLength actionsStr) / 2)
            [
                sprintf "%s%s%s" Colors.outline (String.replicate toolbar.Width "─") Colors.reset
                sprintf "%s%s%s" (String.replicate padding " ") actionsStr (String.replicate padding " ")
            ]
        | Floating ->
            [sprintf "%s╭%s╮%s" Colors.outline actionsStr Colors.reset]

    // =========================================================================
    // COMPONENT: FABMenu (M3 Expressive)
    // =========================================================================

    type FABMenuItem = {
        Icon: string
        Label: string
    }

    type FABMenu = {
        MainIcon: string
        Items: FABMenuItem list
        Expanded: bool
    }

    let renderFABMenu (menu: FABMenu) =
        let lines = ResizeArray<string>()

        if menu.Expanded then
            // Expanded menu items (from bottom to top)
            for item in menu.Items |> List.rev do
                lines.Add(sprintf "%s%s  %s %s%s"
                    Colors.bgSecondary Colors.onSecondaryContainer item.Icon item.Label Colors.reset)
                lines.Add("")

        // Main FAB
        let icon = if menu.Expanded then "✕" else menu.MainIcon
        lines.Add(sprintf "%s%s(( %s ))%s" Colors.bgPrimary Colors.onPrimary icon Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: Tooltip
    // =========================================================================

    type TooltipVariant = Plain | Rich

    type Tooltip = {
        Content: string
        Title: string option
        Variant: TooltipVariant
    }

    let renderTooltip (tooltip: Tooltip) =
        match tooltip.Variant with
        | Plain ->
            sprintf "%s%s %s %s" Colors.bgSurface Colors.onSurface tooltip.Content Colors.reset
        | Rich ->
            let title = tooltip.Title |> Option.map (sprintf "%s%s%s\n" Typography.titleSmall Colors.onSurface) |> Option.defaultValue ""
            sprintf "%s%s%s%s%s" Colors.bgSurface title Colors.onSurfaceVariant tooltip.Content Colors.reset

    // =========================================================================
    // COMPONENT: LoadingIndicator (M3 Expressive)
    // =========================================================================

    type LoadingIndicator = {
        Progress: float option  // None = indeterminate
        Size: string  // "small" | "medium" | "large"
    }

    let renderLoadingIndicator (indicator: LoadingIndicator) =
        let spinner =
            match indicator.Progress with
            | None ->
                // Indeterminate - animated spinner
                let frames = [|"⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏"|]
                let frame = abs (int ((DateTime.UtcNow.Ticks / 1000000L) % 10L))
                frames.[frame]
            | Some pct ->
                // Determinate - arc progress
                let segments = int (pct * 8.0) |> max 0 |> min 8
                match segments with
                | 0 -> "○"
                | 1 -> "◔"
                | 2 -> "◔"
                | 3 -> "◑"
                | 4 -> "◑"
                | 5 -> "◕"
                | 6 -> "◕"
                | 7 -> "◕"
                | _ -> "●"

        let size =
            match indicator.Size with
            | "small" -> spinner
            | "large" -> sprintf " %s %s %s " spinner spinner spinner
            | _ -> sprintf " %s " spinner

        sprintf "%s%s%s" Colors.primary size Colors.reset

    // =========================================================================
    // COMPONENT: SwipeToDismiss
    // =========================================================================

    type SwipeDirection = SwipeLeft | SwipeRight | SwipeBoth

    type SwipeToDismiss = {
        Content: string
        LeftAction: (string * string) option  // (icon, color)
        RightAction: (string * string) option
        SwipeProgress: float  // -1.0 to 1.0
        Width: int
    }

    let renderSwipeToDismiss (swipe: SwipeToDismiss) =
        let progress = swipe.SwipeProgress |> max -1.0 |> min 1.0
        let offset = int (progress * float swipe.Width * 0.3)

        if progress < -0.1 then
            // Swiping left - show right action
            let (icon, color) = swipe.RightAction |> Option.defaultValue ("✕", Colors.error)
            let actionWidth = abs offset
            let contentWidth = swipe.Width - actionWidth
            let content = if swipe.Content.Length > contentWidth then swipe.Content.Substring(0, contentWidth - 1) + "…" else swipe.Content
            sprintf "%s%s%s%s%s"
                content (String.replicate (contentWidth - content.Length) " ")
                color (String.replicate (actionWidth - 1) " " + icon) Colors.reset
        elif progress > 0.1 then
            // Swiping right - show left action
            let (icon, color) = swipe.LeftAction |> Option.defaultValue ("✓", Colors.primary)
            let actionWidth = offset
            let contentWidth = swipe.Width - actionWidth
            let content = if swipe.Content.Length > contentWidth then swipe.Content.Substring(0, contentWidth - 1) + "…" else swipe.Content
            sprintf "%s%s%s%s%s"
                color (icon + String.replicate (actionWidth - 1) " ") Colors.reset
                content (String.replicate (contentWidth - content.Length) " ")
        else
            // Not swiping
            swipe.Content + String.replicate (swipe.Width - swipe.Content.Length) " "

    // =========================================================================
    // COMPONENT: PullToRefresh
    // =========================================================================

    type PullToRefreshState = Idle | Pulling of float | Refreshing | Complete

    let renderPullToRefresh (state: PullToRefreshState) (width: int) =
        let centerPad w content =
            let padding = (width - String.length content) / 2
            String.replicate padding " " + content + String.replicate padding " "

        match state with
        | Idle -> ""
        | Pulling pct ->
            let arrow = if pct > 0.8 then "↻" else "↓"
            centerPad width (sprintf "%s%s Pull to refresh%s" Colors.onSurfaceVariant arrow Colors.reset)
        | Refreshing ->
            let spinner = renderLoadingIndicator { Progress = None; Size = "small" }
            centerPad width (sprintf "%s Refreshing..." spinner)
        | Complete ->
            centerPad width (sprintf "%s✓ Updated%s" Colors.primary Colors.reset)

    // =========================================================================
    // COMPONENT: CircularGauge (Industrial HMI Style)
    // =========================================================================
    // Displays an analog-style circular gauge with needle position
    // Inspired by industrial SCADA/HMI systems

    type GaugeLevel = Normal | Warning | Critical

    type CircularGauge = {
        Value: float          // Current value (0.0 to 1.0)
        Label: string         // Gauge label
        Unit: string          // Unit of measure (e.g., "%", "PSI", "°C")
        MinLabel: string      // Min value label
        MaxLabel: string      // Max value label
        Level: GaugeLevel     // Status level for coloring
    }

    let renderCircularGauge (gauge: CircularGauge) =
        // Unicode gauge segments: ▁▂▃▄▅▆▇█
        let normalized = max 0.0 (min 1.0 gauge.Value)
        let position = int (normalized * 10.0)

        let (color, symbol) =
            match gauge.Level with
            | Normal -> (Colors.primary, "●")
            | Warning -> (Colors.caution, "◉")
            | Critical -> (Colors.error, "⬤")

        // Gauge face with needle position
        let arc = "╭─────╮"
        let needleRow =
            match position with
            | 0 -> "│←    │"
            | p when p <= 2 -> "│ ↙   │"
            | p when p <= 4 -> "│  ↓  │"
            | p when p <= 6 -> "│  ↓  │"
            | p when p <= 8 -> "│   ↘ │"
            | _ -> "│    →│"

        let valueDisplay = sprintf "%.0f%s" (normalized * 100.0) gauge.Unit

        [
            sprintf "%s%s%s" Colors.outline arc Colors.reset
            sprintf "%s%s%s" color needleRow Colors.reset
            sprintf "%s╰─────╯%s" Colors.outline Colors.reset
            sprintf "%s%s%s %s%s%s" Colors.onSurface gauge.MinLabel Colors.reset color valueDisplay Colors.reset
            sprintf "%s%s%s" Colors.onSurfaceVariant gauge.Label Colors.reset
        ]

    // =========================================================================
    // COMPONENT: LinearGauge (Bar-style Gauge)
    // =========================================================================

    type LinearGauge = {
        Value: float
        Label: string
        Width: int
        ShowScale: bool
        Level: GaugeLevel
    }

    let renderLinearGauge (gauge: LinearGauge) =
        let normalized = max 0.0 (min 1.0 gauge.Value)
        let fillWidth = int (normalized * float (gauge.Width - 2))
        let emptyWidth = (gauge.Width - 2) - fillWidth

        let (fillColor, fillChar) =
            match gauge.Level with
            | Normal -> (Colors.primary, "█")
            | Warning -> (Colors.caution, "▓")
            | Critical -> (Colors.error, "█")

        let scale =
            if gauge.ShowScale then
                sprintf "%s0%s%s100%s" Colors.onSurfaceVariant (String.replicate (gauge.Width - 5) " ") Colors.onSurfaceVariant Colors.reset
            else ""

        let bar = sprintf "%s[%s%s%s%s]%s"
                    Colors.outline
                    fillColor (String.replicate fillWidth fillChar)
                    Colors.onSurfaceVariant (String.replicate emptyWidth "░")
                    Colors.reset

        [
            sprintf "%s%s%s" Colors.onSurface gauge.Label Colors.reset
            bar
            scale
        ] |> List.filter (fun s -> s <> "")

    // =========================================================================
    // COMPONENT: TankLevel (Vessel Level Indicator)
    // =========================================================================

    type TankLevel = {
        Level: float          // 0.0 to 1.0
        Label: string
        Height: int           // Height in lines
        ShowPercentage: bool
    }

    let renderTankLevel (tank: TankLevel) =
        let normalized = max 0.0 (min 1.0 tank.Level)
        let fillHeight = int (normalized * float tank.Height)
        let emptyHeight = tank.Height - fillHeight

        let (liquidColor, liquidChar) =
            if normalized > 0.8 then (Colors.caution, "≈")
            elif normalized < 0.2 then (Colors.error, "~")
            else (Colors.primary, "≈")

        let lines = System.Collections.Generic.List<string>()

        // Tank top
        lines.Add(sprintf "%s╭───╮%s" Colors.outline Colors.reset)

        // Empty portion
        for _ in 1..emptyHeight do
            lines.Add(sprintf "%s│   │%s" Colors.outline Colors.reset)

        // Filled portion
        for _ in 1..fillHeight do
            lines.Add(sprintf "%s│%s%s%s%s│%s" Colors.outline liquidColor (String.replicate 3 liquidChar) Colors.reset Colors.outline Colors.reset)

        // Tank bottom
        lines.Add(sprintf "%s╰───╯%s" Colors.outline Colors.reset)

        // Label and percentage
        let pctStr = if tank.ShowPercentage then sprintf " %.0f%%" (normalized * 100.0) else ""
        lines.Add(sprintf "%s%s%s%s" Colors.onSurfaceVariant tank.Label pctStr Colors.reset)

        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: LEDIndicator (Industrial Status LED)
    // =========================================================================

    type LEDState = Off | On | Blinking | Fault

    type LEDIndicator = {
        State: LEDState
        Color: string         // "green" | "red" | "yellow" | "blue"
        Label: string
    }

    let renderLEDIndicator (led: LEDIndicator) =
        let (symbol, color) =
            match led.State, led.Color with
            | Off, _ -> ("○", Colors.onSurfaceVariant)
            | On, "green" -> ("●", "\u001b[38;2;76;175;80m")
            | On, "red" -> ("●", Colors.error)
            | On, "yellow" -> ("●", Colors.caution)
            | On, "blue" -> ("●", Colors.primary)
            | Blinking, c ->
                let sym = if DateTime.UtcNow.Second % 2 = 0 then "●" else "○"
                match c with
                | "green" -> (sym, "\u001b[38;2;76;175;80m")
                | "red" -> (sym, Colors.error)
                | "yellow" -> (sym, Colors.caution)
                | _ -> (sym, Colors.primary)
            | Fault, _ -> ("⊗", Colors.error)
            | _, _ -> ("●", Colors.onSurface)

        sprintf "%s%s%s %s%s%s" color symbol Colors.reset Colors.onSurface led.Label Colors.reset

    // =========================================================================
    // COMPONENT: AltitudeTape (Aviation EFIS-style Vertical Tape)
    // =========================================================================

    type VerticalTape = {
        Value: float
        Unit: string
        Range: float          // How many units visible on tape
        Height: int           // Height in lines
        Label: string
    }

    let renderVerticalTape (tape: VerticalTape) =
        let halfRange = tape.Range / 2.0
        let step = tape.Range / float tape.Height
        let lines = System.Collections.Generic.List<string>()

        for i in 0..tape.Height - 1 do
            let lineValue = tape.Value + halfRange - (float i * step)
            let isCenterLine = i = tape.Height / 2

            let marker =
                if isCenterLine then sprintf "%s▶%.0f%s◀%s" Colors.primary lineValue tape.Unit Colors.reset
                elif int lineValue % 100 = 0 then sprintf " %s%.0f%s" Colors.onSurfaceVariant lineValue Colors.reset
                else sprintf " %s─%s" Colors.outline Colors.reset

            if isCenterLine then
                lines.Add(sprintf "%s═══%s%s" Colors.primary marker Colors.reset)
            else
                lines.Add(sprintf "%s│  %s%s" Colors.outline marker Colors.reset)

        lines.Add(sprintf "%s%s%s" Colors.onSurfaceVariant tape.Label Colors.reset)
        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: HeadingIndicator (Compass Rose)
    // =========================================================================

    type HeadingIndicator = {
        Heading: float        // 0-360 degrees
        Width: int
    }

    let renderHeadingIndicator (hdg: HeadingIndicator) =
        let cardinals = [| "N"; "NE"; "E"; "SE"; "S"; "SW"; "W"; "NW" |]
        let normalized = (hdg.Heading % 360.0 + 360.0) % 360.0
        let segment = int (normalized / 45.0) % 8
        let nextSegment = (segment + 1) % 8

        // Local center padding helper
        let padCenter (w: int) (content: string) =
            let visibleLen = content.Length - 20  // Approximate ANSI code length
            let padding = max 0 ((w - visibleLen) / 2)
            String.replicate padding " " + content + String.replicate padding " "

        // Create compass display
        let arrow = "▲"
        let compassLine = sprintf "  %s%s%s  " Colors.primary arrow Colors.reset
        let headingStr = sprintf "HDG %03.0f°" normalized
        let headingFormatted = sprintf "%s%s%s" Colors.primary headingStr Colors.reset
        let cardinalStr = sprintf "%s%s%s ← → %s%s%s"
                            Colors.onSurfaceVariant cardinals.[segment] Colors.reset
                            Colors.onSurfaceVariant cardinals.[nextSegment] Colors.reset

        [
            sprintf "%s╭%s╮%s" Colors.outline (String.replicate (hdg.Width - 2) "─") Colors.reset
            sprintf "%s│%s│%s" Colors.outline (padCenter (hdg.Width - 2) compassLine) Colors.reset
            sprintf "%s│%s│%s" Colors.outline (padCenter (hdg.Width - 2) headingFormatted) Colors.reset
            sprintf "%s│%s│%s" Colors.outline (padCenter (hdg.Width - 2) cardinalStr) Colors.reset
            sprintf "%s╰%s╯%s" Colors.outline (String.replicate (hdg.Width - 2) "─") Colors.reset
        ]

    // =========================================================================
    // COMPONENT: TrendMiniChart (Scrolling Trend Display)
    // =========================================================================

    type TrendMiniChart = {
        Values: float list    // Historical values (most recent last)
        Width: int
        Height: int
        Label: string
        ShowBounds: bool
    }

    let renderTrendMiniChart (trend: TrendMiniChart) =
        if List.isEmpty trend.Values then
            [ sprintf "%s[No Data]%s" Colors.onSurfaceVariant Colors.reset ]
        else
            let values = trend.Values |> List.rev |> List.truncate trend.Width
            let minVal = List.min values
            let maxVal = List.max values
            let range = max 0.001 (maxVal - minVal)

            // Braille-style blocks: ▁▂▃▄▅▆▇█
            let blocks = [|" "; "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█"|]

            let chart =
                values
                |> List.map (fun v ->
                    let normalized = (v - minVal) / range
                    let idx = min 8 (int (normalized * 8.0))
                    blocks.[idx]
                )
                |> List.rev
                |> String.concat ""

            let boundStr =
                if trend.ShowBounds then
                    sprintf "%s%.1f-%.1f%s" Colors.onSurfaceVariant minVal maxVal Colors.reset
                else ""

            [
                sprintf "%s%s%s" Colors.primary chart Colors.reset
                sprintf "%s%s%s %s" Colors.onSurfaceVariant trend.Label Colors.reset boundStr
            ]

    // =========================================================================
    // COMPONENT: PieChart (ASCII Pie Chart)
    // =========================================================================

    type PieSlice = {
        Label: string
        Value: float
        Color: string         // ANSI color code
    }

    let renderPieChart (slices: PieSlice list) (radius: int) =
        if List.isEmpty slices then
            [ "[No Data]" ]
        else
            let total = slices |> List.sumBy (fun s -> s.Value)
            if total <= 0.0 then [ "[No Data]" ]
            else
                // Simple pie representation using sectors
                let legend =
                    slices
                    |> List.map (fun s ->
                        let pct = s.Value / total * 100.0
                        sprintf "%s█%s %s: %.1f%%" s.Color Colors.reset s.Label pct
                    )

                // Simplified pie using Unicode sectors
                let sectorSymbols = [|"◔"; "◑"; "◕"; "●"|]
                let mainSlice = slices |> List.maxBy (fun s -> s.Value)
                let sectorIdx = min 3 (int (mainSlice.Value / total * 4.0))

                let pieDisplay = sprintf "%s%s%s" mainSlice.Color sectorSymbols.[sectorIdx] Colors.reset

                [ pieDisplay ] @ legend

    // =========================================================================
    // COMPONENT: SystemStatusPanel (Consolidated Status Display)
    // =========================================================================

    type SystemStatus = {
        Name: string
        Status: string        // "ok" | "warning" | "error" | "offline"
        Details: string option
    }

    let renderSystemStatusPanel (systems: SystemStatus list) (width: int) =
        let lines = System.Collections.Generic.List<string>()

        lines.Add(sprintf "%s╭%s System Status %s╮%s"
                    Colors.outline (String.replicate 2 "─")
                    (String.replicate (width - 19) "─") Colors.reset)

        for sys in systems do
            let (icon, color) =
                match sys.Status with
                | "ok" -> ("✓", "\u001b[38;2;76;175;80m")  // Green
                | "warning" -> ("⚠", Colors.caution)
                | "error" -> ("✗", Colors.error)
                | "offline" -> ("○", Colors.onSurfaceVariant)
                | _ -> ("?", Colors.onSurfaceVariant)

            let details = sys.Details |> Option.map (sprintf " - %s") |> Option.defaultValue ""
            let content = sprintf " %s%s%s %s%s" color icon Colors.reset sys.Name details
            let padding = max 0 (width - 2 - content.Length + 11)  // +11 for ANSI codes

            lines.Add(sprintf "%s│%s%s%s│%s"
                        Colors.outline Colors.onSurface content
                        (String.replicate padding " ") Colors.reset)

        lines.Add(sprintf "%s╰%s╯%s" Colors.outline (String.replicate (width - 2) "─") Colors.reset)
        lines |> Seq.toList

    // =========================================================================
    // COMPONENT: BigTextBanner (ASCII Art Large Text)
    // =========================================================================

    /// Renders single character as 3-line tall block text
    let private renderBigChar (c: char) =
        match System.Char.ToUpper(c) with
        | 'A' -> [|"▄█▄"; "█▀█"; "█ █"|]
        | 'B' -> [|"██▄"; "█▀█"; "██▀"|]
        | 'C' -> [|"▄██"; "█  "; "▀██"|]
        | 'D' -> [|"██▄"; "█ █"; "██▀"|]
        | 'E' -> [|"███"; "█▀ "; "███"|]
        | 'F' -> [|"███"; "█▀ "; "█  "|]
        | 'G' -> [|"▄██"; "█ █"; "▀██"|]
        | 'H' -> [|"█ █"; "███"; "█ █"|]
        | 'I' -> [|"███"; " █ "; "███"|]
        | 'J' -> [|"  █"; "  █"; "██▀"|]
        | 'K' -> [|"█▄█"; "██ "; "█ █"|]
        | 'L' -> [|"█  "; "█  "; "███"|]
        | 'M' -> [|"█▄█"; "█▀█"; "█ █"|]
        | 'N' -> [|"█▄█"; "█▀█"; "█ █"|]
        | 'O' -> [|"▄█▄"; "█ █"; "▀█▀"|]
        | 'P' -> [|"██▄"; "█▀▀"; "█  "|]
        | 'Q' -> [|"▄█▄"; "█ █"; "▀█▄"|]
        | 'R' -> [|"██▄"; "██▀"; "█ █"|]
        | 'S' -> [|"▄██"; "▀█▄"; "██▀"|]
        | 'T' -> [|"███"; " █ "; " █ "|]
        | 'U' -> [|"█ █"; "█ █"; "▀█▀"|]
        | 'V' -> [|"█ █"; "█ █"; " ▀ "|]
        | 'W' -> [|"█ █"; "█▄█"; "█▀█"|]
        | 'X' -> [|"█ █"; " █ "; "█ █"|]
        | 'Y' -> [|"█ █"; " █ "; " █ "|]
        | 'Z' -> [|"███"; " ▄▀"; "███"|]
        | '0' -> [|"▄█▄"; "█ █"; "▀█▀"|]
        | '1' -> [|" █ "; " █ "; " █ "|]
        | '2' -> [|"▄█▄"; "▄▀ "; "███"|]
        | '3' -> [|"▄█▄"; " █▄"; "▀█▀"|]
        | '4' -> [|"█ █"; "▀█▀"; "  █"|]
        | '5' -> [|"███"; "▀█▄"; "▄█▀"|]
        | '6' -> [|"▄█ "; "█▀▄"; "▀█▀"|]
        | '7' -> [|"███"; " ▄▀"; " █ "|]
        | '8' -> [|"▄█▄"; "▄█▄"; "▀█▀"|]
        | '9' -> [|"▄█▄"; "▀█▀"; " █ "|]
        | ' ' -> [|"   "; "   "; "   "|]
        | ':' -> [|" ● "; "   "; " ● "|]
        | '-' -> [|"   "; "▄▄▄"; "   "|]
        | _ -> [|"   "; " ? "; "   "|]

    let renderBigText (text: string) (color: string) =
        let chars = text.ToCharArray() |> Array.map renderBigChar
        let lines = [|
            chars |> Array.map (fun a -> a.[0]) |> String.concat " "
            chars |> Array.map (fun a -> a.[1]) |> String.concat " "
            chars |> Array.map (fun a -> a.[2]) |> String.concat " "
        |]
        lines |> Array.map (sprintf "%s%s%s" color Colors.reset) |> Array.toList

    // =========================================================================
    // AVIATION COCKPIT COMPONENTS - Primary Flight Display (PFD)
    // =========================================================================

    // COMPONENT: AttitudeIndicator (Artificial Horizon)
    // Shows aircraft pitch and bank angle relative to horizon
    type AttitudeIndicator = {
        Pitch: float      // Degrees: positive = nose up, negative = nose down
        Bank: float       // Degrees: positive = right bank, negative = left bank
        Width: int
        Height: int
    }

    let renderAttitudeIndicator (ai: AttitudeIndicator) =
        let width = max 15 ai.Width
        let height = max 7 ai.Height
        let centerX = width / 2
        let centerY = height / 2

        // Clamp pitch to reasonable display range
        let pitchOffset = int (ai.Pitch / 10.0) |> max -3 |> min 3
        let horizonY = centerY - pitchOffset

        // Bank indicator characters
        let bankChar =
            if ai.Bank < -20.0 then "╲╲"
            elif ai.Bank < -5.0 then "╲"
            elif ai.Bank > 20.0 then "╱╱"
            elif ai.Bank > 5.0 then "╱"
            else "─"

        // Build components
        let topBorder = sprintf "%s┌%s┐%s" Colors.outline (String.replicate (width - 2) "─") Colors.reset

        let skyLine = String.replicate (width - 2) " "
        let skyLines = [
            for _ in 1 .. max 0 (horizonY - 1) do
                yield sprintf "%s│%s%s%s│%s" Colors.outline Colors.primary skyLine Colors.outline Colors.reset
        ]

        // Horizon line with aircraft symbol
        let leftPad = centerX - 3
        let rightPad = width - 2 - leftPad - 6
        let leftPadStr = String.replicate (max 0 leftPad) "░"
        let rightPadStr = String.replicate (max 0 rightPad) "░"
        let horizonLine = sprintf "%s%s─●─%s%s" leftPadStr bankChar bankChar rightPadStr
        let horizon = sprintf "%s│%s%s%s│%s" Colors.outline Colors.tertiary horizonLine Colors.outline Colors.reset

        let groundLine = String.replicate (width - 2) "░"
        let groundLines = [
            for _ in (horizonY + 1) .. (height - 2) do
                yield sprintf "%s│%s%s%s│%s" Colors.outline Colors.surface groundLine Colors.outline Colors.reset
        ]

        // Bottom border with pitch scale
        let pitchLabel = sprintf "P:%+.0f°" ai.Pitch
        let bankLabel = sprintf "B:%+.0f°" ai.Bank
        let bottomContent = sprintf " %s  %s " pitchLabel bankLabel
        let padNeeded = width - 2 - bottomContent.Length
        let bottomLine = if padNeeded > 0 then bottomContent + String.replicate padNeeded " " else bottomContent.Substring(0, width - 2)
        let bottomBorder = sprintf "%s└%s┘%s" Colors.outline bottomLine Colors.reset

        [topBorder] @ skyLines @ [horizon] @ groundLines @ [bottomBorder]

    // COMPONENT: VerticalSpeedIndicator (VSI)
    // Shows rate of climb or descent in feet per minute
    type VerticalSpeedIndicator = {
        Rate: int         // Feet per minute: positive = climb, negative = descent
        MaxRate: int      // Maximum displayed rate (typically 2000 or 4000)
        Height: int
    }

    let renderVSI (vsi: VerticalSpeedIndicator) =
        let height = max 9 vsi.Height
        let maxRate = max 1000 vsi.MaxRate
        let halfHeight = (height - 3) / 2  // Exclude borders and center

        // Normalize rate to display range
        let clampedRate = vsi.Rate |> max -maxRate |> min maxRate
        let normalizedRate = float clampedRate / float maxRate
        let fillBars = int (abs normalizedRate * float halfHeight)

        let rateColor =
            if abs vsi.Rate > int (float maxRate * 0.8) then Colors.error
            elif abs vsi.Rate > int (float maxRate * 0.5) then Colors.warning
            else Colors.advisory

        // Helper to generate climb/descent line
        let makeClimbLine i =
            let filled = vsi.Rate > 0 && fillBars >= (halfHeight - i + 1)
            let bar = if filled then "████" else "    "
            let marker =
                if i = halfHeight then sprintf "+%d" maxRate
                elif i = halfHeight / 2 then sprintf "+%d" (maxRate / 2)
                else "   "
            sprintf "%s│%s%s%s│%s%s" Colors.outline rateColor bar Colors.outline marker Colors.reset

        let makeDescentLine i =
            let filled = vsi.Rate < 0 && fillBars >= i
            let bar = if filled then "████" else "    "
            let marker =
                if i = halfHeight then sprintf "-%d" maxRate
                elif i = halfHeight / 2 then sprintf "-%d" (maxRate / 2)
                else "   "
            sprintf "%s│%s%s%s│%s%s" Colors.outline rateColor bar Colors.outline marker Colors.reset

        let topLabel = sprintf "%s┌─ VSI ─┐%s" Colors.outline Colors.reset
        let climbLines = [ for i in halfHeight .. -1 .. 1 -> makeClimbLine i ]
        let rateText = sprintf "%+5d" vsi.Rate
        let centerLine = sprintf "%s│%s%s%s│ FPM%s" Colors.outline Colors.onSurface rateText Colors.outline Colors.reset
        let descentLines = [ for i in 1 .. halfHeight -> makeDescentLine i ]
        let bottomBorder = sprintf "%s└───────┘%s" Colors.outline Colors.reset

        [topLabel] @ climbLines @ [centerLine] @ descentLines @ [bottomBorder]

    // COMPONENT: AirspeedIndicator
    // Shows current airspeed with color-coded speed ranges
    type SpeedRange = {
        Min: int
        Max: int
        Color: string
        Label: string
    }

    type AirspeedIndicator = {
        Speed: int            // Current indicated airspeed in knots
        Ranges: SpeedRange list  // Speed ranges (Vso, Vs1, Vfe, Vno, Vne, etc.)
        TrendVector: int      // Speed trend (+/- knots in 6 seconds)
        Height: int
    }

    let defaultSpeedRanges = [
        { Min = 0; Max = 45; Color = Colors.error; Label = "STALL" }
        { Min = 45; Max = 60; Color = Colors.warning; Label = "Vs0" }
        { Min = 60; Max = 85; Color = Colors.advisory; Label = "Vfe" }
        { Min = 85; Max = 130; Color = Colors.advisory; Label = "Vno" }
        { Min = 130; Max = 160; Color = Colors.warning; Label = "Vne" }
        { Min = 160; Max = 999; Color = Colors.error; Label = "OVER" }
    ]

    let renderAirspeedIndicator (asi: AirspeedIndicator) =
        let height = max 11 asi.Height
        let ranges = if asi.Ranges.IsEmpty then defaultSpeedRanges else asi.Ranges

        // Find current speed range
        let currentRange =
            ranges |> List.tryFind (fun r -> asi.Speed >= r.Min && asi.Speed < r.Max)
            |> Option.defaultValue { Min = 0; Max = 999; Color = Colors.onSurface; Label = "" }

        // Calculate tape display (show speeds around current)
        let stepsPerLine = 5  // 5 knots per line
        let visibleLines = height - 4
        let halfVisible = visibleLines / 2

        let trendArrow =
            if asi.TrendVector > 10 then "↑↑"
            elif asi.TrendVector > 0 then "↑"
            elif asi.TrendVector < -10 then "↓↓"
            elif asi.TrendVector < 0 then "↓"
            else "→"

        let lines = [
            // Top border
            sprintf "%s┌─ IAS ──┐%s" Colors.outline Colors.reset
            sprintf "%s│ KIAS   │%s" Colors.outline Colors.reset

            // Speed tape
            for i in halfVisible .. -1 .. -halfVisible do
                let displaySpeed = asi.Speed + (i * stepsPerLine)
                let rangeForSpeed =
                    ranges |> List.tryFind (fun r -> displaySpeed >= r.Min && displaySpeed < r.Max)
                    |> Option.defaultValue currentRange

                let pointer = if i = 0 then "►" else " "
                let speedText = if displaySpeed >= 0 then sprintf "%3d" displaySpeed else "   "
                let bar = if i = 0 then "═══" else "───"
                sprintf "%s│%s%s%s %s%s│%s" Colors.outline rangeForSpeed.Color speedText bar pointer Colors.outline Colors.reset

            // Current speed callout
            sprintf "%s├───────┤%s" Colors.outline Colors.reset
            sprintf "%s│%s %3d %s│%s" Colors.outline currentRange.Color asi.Speed trendArrow Colors.reset
            sprintf "%s└───────┘%s" Colors.outline Colors.reset
        ]
        lines

    // =========================================================================
    // AVIATION COCKPIT COMPONENTS - Engine Instruments (EICAS/ECAM)
    // =========================================================================

    // COMPONENT: EngineGauge (N1, N2, EGT, etc.)
    // Arc-style gauge for engine parameters
    type EngineGauge = {
        Label: string         // "N1", "N2", "EGT", "FF"
        Value: float          // Current value
        Unit: string          // "%", "°C", "PPH"
        Min: float
        Max: float
        RedlineMin: float option   // Below this = danger
        RedlineMax: float option   // Above this = danger
        CautionMin: float option
        CautionMax: float option
    }

    let renderEngineGauge (eg: EngineGauge) =
        let range = eg.Max - eg.Min
        let normalized = (eg.Value - eg.Min) / range |> max 0.0 |> min 1.0
        let arcWidth = 10
        let filled = int (normalized * float arcWidth)

        // Determine color based on limits
        let color =
            match eg.RedlineMin, eg.RedlineMax, eg.CautionMin, eg.CautionMax with
            | Some rmin, _, _, _ when eg.Value < rmin -> Colors.error
            | _, Some rmax, _, _ when eg.Value > rmax -> Colors.error
            | _, _, Some cmin, _ when eg.Value < cmin -> Colors.warning
            | _, _, _, Some cmax when eg.Value > cmax -> Colors.warning
            | _ -> Colors.advisory

        let arcFill = String.replicate filled "█" + String.replicate (arcWidth - filled) "░"

        let lines = [
            sprintf "%s┌─%s─┐%s" Colors.outline (eg.Label.PadRight(3)) Colors.reset
            sprintf "%s│%s%s%s│%s" Colors.outline color arcFill Colors.outline Colors.reset
            sprintf "%s│%s%6.1f%s%s│%s" Colors.outline color eg.Value eg.Unit Colors.outline Colors.reset
            sprintf "%s└──────┘%s" Colors.outline Colors.reset
        ]
        lines

    // COMPONENT: FuelQuantity
    // Tank-style fuel gauges with multiple tanks
    type FuelTank = {
        Name: string      // "L", "C", "R", "AUX"
        Quantity: float   // Current fuel in gallons or lbs
        Capacity: float   // Tank capacity
    }

    type FuelQuantityDisplay = {
        Tanks: FuelTank list
        TotalUsed: float
        FlowRate: float   // Per hour
    }

    let renderFuelQuantity (fq: FuelQuantityDisplay) =
        let tankLines =
            fq.Tanks |> List.collect (fun tank ->
                let pct = tank.Quantity / tank.Capacity
                let color =
                    if pct < 0.15 then Colors.error
                    elif pct < 0.25 then Colors.warning
                    else Colors.advisory
                let barWidth = 8
                let filled = int (pct * float barWidth)
                let bar = String.replicate filled "█" + String.replicate (barWidth - filled) "░"
                [
                    sprintf "%s%s:%s%s%s %4.0f%s" Colors.onSurface tank.Name color bar Colors.reset tank.Quantity Colors.reset
                ]
            )

        let totalFuel = fq.Tanks |> List.sumBy (fun t -> t.Quantity)
        let endurance = if fq.FlowRate > 0.0 then totalFuel / fq.FlowRate else 0.0

        [
            sprintf "%s┌─ FUEL ─────────┐%s" Colors.outline Colors.reset
        ] @ tankLines @ [
            sprintf "%s├────────────────┤%s" Colors.outline Colors.reset
            sprintf "%s│%s TOT: %6.0f   │%s" Colors.outline Colors.advisory totalFuel Colors.reset
            sprintf "%s│%s END: %4.1f hr  │%s" Colors.outline Colors.onSurface endurance Colors.reset
            sprintf "%s└────────────────┘%s" Colors.outline Colors.reset
        ]

    // =========================================================================
    // AVIATION COCKPIT COMPONENTS - Annunciator & Status
    // =========================================================================

    // COMPONENT: GearIndicator
    // Landing gear position with three-light display
    type GearPosition =
        | Up
        | Transit
        | Down
        | Unsafe

    type GearIndicator = {
        Left: GearPosition
        Nose: GearPosition
        Right: GearPosition
    }

    let renderGearIndicator (gi: GearIndicator) =
        let gearLight pos =
            match pos with
            | Up -> sprintf "%s○%s" Colors.surface Colors.reset      // Dark/off
            | Transit -> sprintf "%s◐%s" Colors.warning Colors.reset  // Amber/transit
            | Down -> sprintf "%s●%s" Colors.advisory Colors.reset     // Green/down & locked
            | Unsafe -> sprintf "%s⊗%s" Colors.error Colors.reset     // Red/unsafe

        [
            sprintf "%s┌─ GEAR ─┐%s" Colors.outline Colors.reset
            sprintf "%s│   %s   │%s" Colors.outline (gearLight gi.Nose) Colors.reset
            sprintf "%s│ %s   %s │%s" Colors.outline (gearLight gi.Left) (gearLight gi.Right) Colors.reset
            sprintf "%s│L  N  R│%s" Colors.outline Colors.reset
            sprintf "%s└───────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: FlapsIndicator
    // Flap and slat position indicator
    type FlapsIndicator = {
        CurrentPosition: int   // 0-40 degrees typically
        TargetPosition: int    // Selected position
        Positions: int list    // Detent positions [0;1;5;10;15;25;30;40]
    }

    let renderFlapsIndicator (fi: FlapsIndicator) =
        let maxFlap = fi.Positions |> List.max |> max 1
        let barWidth = 12
        let currentFill = int (float fi.CurrentPosition / float maxFlap * float barWidth)
        let targetFill = int (float fi.TargetPosition / float maxFlap * float barWidth)

        let bar = Array.create barWidth '░'
        for i in 0 .. currentFill - 1 do
            if i < barWidth then bar.[i] <- '█'
        if targetFill < barWidth && targetFill >= 0 then
            bar.[targetFill] <- '▼'

        let color = if fi.CurrentPosition = fi.TargetPosition then Colors.advisory else Colors.warning

        [
            sprintf "%s┌─ FLAPS ────────┐%s" Colors.outline Colors.reset
            sprintf "%s│%s%s%s│%s" Colors.outline color (String(bar)) Colors.outline Colors.reset
            sprintf "%s│ %2d° → %2d°     │%s" Colors.outline fi.CurrentPosition fi.TargetPosition Colors.reset
            sprintf "%s└────────────────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: AnnunciatorPanel
    // Master caution/warning lights panel
    type AnnunciatorLight = {
        Label: string
        Status: bool       // true = illuminated
        Severity: string   // "CAUTION" (amber) or "WARNING" (red) or "ADVISORY" (cyan)
        Acknowledged: bool
    }

    type AnnunciatorPanel = {
        MasterCaution: bool
        MasterWarning: bool
        Lights: AnnunciatorLight list
    }

    let renderAnnunciatorPanel (ap: AnnunciatorPanel) =
        let masterColor status = if status then Colors.error else Colors.surface
        let masterW = if ap.MasterWarning then sprintf "%s[WARNING]%s" Colors.error Colors.reset else sprintf "%s[       ]%s" Colors.surface Colors.reset
        let masterC = if ap.MasterCaution then sprintf "%s[CAUTION]%s" Colors.warning Colors.reset else sprintf "%s[       ]%s" Colors.surface Colors.reset

        let lightLines =
            ap.Lights
            |> List.filter (fun l -> l.Status)
            |> List.map (fun light ->
                let color =
                    match light.Severity with
                    | "WARNING" -> Colors.error
                    | "CAUTION" -> Colors.warning
                    | _ -> Colors.primary
                let ack = if light.Acknowledged then "✓" else "●"
                sprintf "%s│ %s %s%-12s%s│%s" Colors.outline ack color light.Label Colors.outline Colors.reset
            )

        [
            sprintf "%s┌─ ANNUNCIATOR ──────┐%s" Colors.outline Colors.reset
            sprintf "%s│ %s %s │%s" Colors.outline masterW masterC Colors.reset
            sprintf "%s├────────────────────┤%s" Colors.outline Colors.reset
        ] @ (if lightLines.IsEmpty then [sprintf "%s│       ALL OK       │%s" Colors.outline Colors.reset] else lightLines) @ [
            sprintf "%s└────────────────────┘%s" Colors.outline Colors.reset
        ]

    // =========================================================================
    // AVIATION COCKPIT COMPONENTS - Navigation Displays
    // =========================================================================

    // COMPONENT: RadioStack
    // COM/NAV frequency display
    type RadioFrequency = {
        Type: string       // "COM1", "COM2", "NAV1", "NAV2"
        Active: string     // Active frequency "123.45"
        Standby: string    // Standby frequency "121.50"
    }

    type RadioStack = {
        Radios: RadioFrequency list
    }

    let renderRadioStack (rs: RadioStack) =
        let radioLines =
            rs.Radios |> List.collect (fun radio ->
                [
                    sprintf "%s│%s%s%s %s ◄► %s%s │%s"
                        Colors.outline Colors.advisory radio.Type Colors.reset
                        radio.Active radio.Standby Colors.outline Colors.reset
                ]
            )
        [
            sprintf "%s┌─ RADIO ────────────┐%s" Colors.outline Colors.reset
        ] @ radioLines @ [
            sprintf "%s└────────────────────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: FlightModeAnnunciator (FMA)
    // Autopilot mode display
    type FMAColumn = {
        Mode: string       // "SPD", "HDG", "ALT", "VS"
        Armed: string      // Armed mode (smaller/dimmer)
        Engaged: bool
    }

    type FlightModeAnnunciator = {
        Columns: FMAColumn list
        APEngaged: bool
        ATEngaged: bool    // Autothrottle
    }

    let renderFMA (fma: FlightModeAnnunciator) =
        let apStatus = if fma.APEngaged then sprintf "%sAP%s" Colors.advisory Colors.reset else sprintf "%s──%s" Colors.surface Colors.reset
        let atStatus = if fma.ATEngaged then sprintf "%sAT%s" Colors.advisory Colors.reset else sprintf "%s──%s" Colors.surface Colors.reset

        let modeText =
            fma.Columns
            |> List.map (fun col ->
                let color = if col.Engaged then Colors.advisory else Colors.surface
                sprintf "%s%-4s%s" color col.Mode Colors.reset
            )
            |> String.concat " "

        let armedText =
            fma.Columns
            |> List.map (fun col ->
                sprintf "%s%-4s%s" Colors.onSurfaceVariant col.Armed Colors.reset
            )
            |> String.concat " "

        [
            sprintf "%s┌─ FMA ─%s─%s───────────────────┐%s" Colors.outline apStatus atStatus Colors.reset
            sprintf "%s│ %s │%s" Colors.outline modeText Colors.reset
            sprintf "%s│ %s │%s" Colors.outline armedText Colors.reset
            sprintf "%s└───────────────────────────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: HSI (Horizontal Situation Indicator)
    // Shows heading with course needle
    type HSI = {
        Heading: int         // Current magnetic heading 0-359
        Course: int          // Selected course 0-359
        CourseDeviation: float  // Dots: -2.5 to +2.5
        ToFrom: string       // "TO", "FROM", "OFF"
        DME: float option    // Distance in NM
    }

    let renderHSI (hsi: HSI) =
        let width = 21
        let compassWidth = 15

        // Generate compass rose snippet
        let headingLabel hdg =
            match hdg with
            | 0 -> "N"
            | 90 -> "E"
            | 180 -> "S"
            | 270 -> "W"
            | h when h % 30 = 0 -> sprintf "%d" (h / 10)
            | _ -> "·"
        let headings =
            [ for i in -3 .. 3 -> (hsi.Heading + i * 10 + 360) % 360 ]
            |> List.map headingLabel
            |> String.concat " "

        // Course deviation indicator (CDI)
        let cdiDots = 5
        let deviationIdx = int ((hsi.CourseDeviation + 2.5) / 5.0 * float (cdiDots * 2)) |> max 0 |> min (cdiDots * 2)
        let cdi = Array.create (cdiDots * 2 + 1) '·'
        cdi.[cdiDots] <- '│'  // Center
        cdi.[deviationIdx] <- '◆'  // Course needle

        let toFromColor = match hsi.ToFrom with "TO" -> Colors.advisory | "FROM" -> Colors.warning | _ -> Colors.surface
        let dmeText = match hsi.DME with Some d -> sprintf "%.1fNM" d | None -> "---.-"

        [
            sprintf "%s┌─ HSI ─────────────┐%s" Colors.outline Colors.reset
            sprintf "%s│     %3d° MAG      │%s" Colors.outline hsi.Heading Colors.reset
            sprintf "%s│ %s │%s" Colors.outline headings Colors.reset
            sprintf "%s│       ▲           │%s" Colors.outline Colors.reset
            sprintf "%s│     CRS:%3d°      │%s" Colors.outline hsi.Course Colors.reset
            sprintf "%s│   %s   │%s" Colors.outline (String(cdi)) Colors.reset
            sprintf "%s│%s%s%s   DME:%s  │%s" Colors.outline toFromColor hsi.ToFrom Colors.reset dmeText Colors.reset
            sprintf "%s└───────────────────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: Clock/Timer
    // Flight timer and UTC clock
    type FlightClock = {
        UTC: System.TimeSpan
        FlightTime: System.TimeSpan
        TimerRunning: bool
        TimerValue: System.TimeSpan
    }

    let renderFlightClock (fc: FlightClock) =
        let timerColor = if fc.TimerRunning then Colors.advisory else Colors.onSurface
        let timerSymbol = if fc.TimerRunning then "▶" else "■"

        [
            sprintf "%s┌─ CLOCK ─────────┐%s" Colors.outline Colors.reset
            sprintf "%s│ UTC  %02d:%02d:%02d   │%s" Colors.outline fc.UTC.Hours fc.UTC.Minutes fc.UTC.Seconds Colors.reset
            sprintf "%s│ FLT  %02d:%02d:%02d   │%s" Colors.outline fc.FlightTime.Hours fc.FlightTime.Minutes fc.FlightTime.Seconds Colors.reset
            sprintf "%s│%s %s   %02d:%02d:%02d%s   │%s" Colors.outline timerColor timerSymbol fc.TimerValue.Hours fc.TimerValue.Minutes fc.TimerValue.Seconds Colors.outline Colors.reset
            sprintf "%s└─────────────────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: TCAS Display (Traffic)
    // Traffic collision avoidance display
    type TrafficTarget = {
        RelativeBearing: int    // 0-359 relative to aircraft
        Distance: float         // NM
        AltitudeDelta: int      // Hundreds of feet: +10 = 1000ft above
        ThreatLevel: string     // "OTHER", "PROXIMATE", "TA", "RA"
    }

    type TCASDisplay = {
        Targets: TrafficTarget list
        Range: int              // Display range in NM (6, 12, 24)
    }

    let renderTCAS (tcas: TCASDisplay) =
        let size = 11
        let center = size / 2

        // Create empty display grid
        let grid = Array2D.create size size ' '

        // Draw range rings
        let ringChar = '·'
        for i in 0 .. size - 1 do
            grid.[0, i] <- ringChar
            grid.[size-1, i] <- ringChar
            grid.[i, 0] <- ringChar
            grid.[i, size-1] <- ringChar
        grid.[center, center] <- '▲'  // Own aircraft

        // Plot targets
        for target in tcas.Targets do
            let rad = float target.RelativeBearing * System.Math.PI / 180.0
            let dist = target.Distance / float tcas.Range
            let x = center + int (sin rad * dist * float center) |> max 0 |> min (size-1)
            let y = center - int (cos rad * dist * float center) |> max 0 |> min (size-1)

            let symbol =
                match target.ThreatLevel with
                | "RA" -> '◆'      // Resolution Advisory - solid diamond
                | "TA" -> '◇'      // Traffic Advisory - hollow diamond
                | "PROXIMATE" -> '○'
                | _ -> '·'
            grid.[y, x] <- symbol

        let gridLines = [
            for y in 0 .. size - 1 do
                String(grid.[y, *])
        ]

        [
            sprintf "%s┌─ TCAS %2dNM ───┐%s" Colors.outline tcas.Range Colors.reset
        ] @ (gridLines |> List.map (sprintf "%s│%s│%s" Colors.outline Colors.reset)) @ [
            sprintf "%s└───────────────┘%s" Colors.outline Colors.reset
        ]

    // COMPONENT: EFIS Control Panel
    // Range/Mode selector display
    type EFISMode = ND_ARC | ND_ROSE | ND_MAP | ND_PLAN

    type EFISControlPanel = {
        Mode: EFISMode
        Range: int            // NM: 10, 20, 40, 80, 160, 320
        WeatherRadar: bool
        Terrain: bool
        Traffic: bool
        Waypoints: bool
    }

    let renderEFISControl (efis: EFISControlPanel) =
        let modeStr = match efis.Mode with ND_ARC -> "ARC" | ND_ROSE -> "ROSE" | ND_MAP -> "MAP" | ND_PLAN -> "PLAN"
        let onOff b = if b then sprintf "%s●%s" Colors.advisory Colors.reset else sprintf "%s○%s" Colors.surface Colors.reset

        [
            sprintf "%s┌─ EFIS CTL ─────────┐%s" Colors.outline Colors.reset
            sprintf "%s│ MODE: %s%-4s%s RNG:%3d │%s" Colors.outline Colors.primary modeStr Colors.reset efis.Range Colors.reset
            sprintf "%s│ WX:%s TRN:%s TFC:%s WPT:%s │%s" Colors.outline (onOff efis.WeatherRadar) (onOff efis.Terrain) (onOff efis.Traffic) (onOff efis.Waypoints) Colors.reset
            sprintf "%s└────────────────────┘%s" Colors.outline Colors.reset
        ]

    // =========================================================================
    // BUBBLES-INSPIRED COMPONENTS
    // =========================================================================
    // Adapted from charmbracelet/bubbles for Dark Cockpit UI
    // Reference: https://github.com/charmbracelet/bubbles

    // -------------------------------------------------------------------------
    // COMPONENT: Paginator
    // -------------------------------------------------------------------------
    // Handles pagination with visual feedback
    // Supports dot-style (iOS-like) and numeric modes

    type PaginatorStyle = DotStyle | NumericStyle | ArrowStyle

    type Paginator = {
        CurrentPage: int
        TotalPages: int
        Style: PaginatorStyle
        PerPage: int
        TotalItems: int
    }

    let renderPaginator (pag: Paginator) =
        match pag.Style with
        | DotStyle ->
            // iOS-style dot pagination: ○ ○ ● ○ ○
            let dots = [
                for i in 0 .. pag.TotalPages - 1 do
                    if i = pag.CurrentPage then
                        sprintf "%s●%s" Colors.primary Colors.reset
                    else
                        sprintf "%s○%s" Colors.outline Colors.reset
            ]
            String.concat " " dots

        | NumericStyle ->
            // Numeric: « 1 2 [3] 4 5 »
            let pages = [
                if pag.CurrentPage > 0 then
                    sprintf "%s«%s" Colors.outline Colors.reset
                else
                    sprintf "%s«%s" Colors.surfaceVariant Colors.reset

                for i in 0 .. pag.TotalPages - 1 do
                    if i = pag.CurrentPage then
                        sprintf "%s[%d]%s" Colors.primary (i + 1) Colors.reset
                    else
                        sprintf "%s%d%s" Colors.onSurface (i + 1) Colors.reset

                if pag.CurrentPage < pag.TotalPages - 1 then
                    sprintf "%s»%s" Colors.outline Colors.reset
                else
                    sprintf "%s»%s" Colors.surfaceVariant Colors.reset
            ]
            String.concat " " pages

        | ArrowStyle ->
            // Arrow style: ◀ Page 3 of 10 ▶
            let leftArrow = if pag.CurrentPage > 0 then sprintf "%s◀%s" Colors.primary Colors.reset else sprintf "%s◀%s" Colors.surfaceVariant Colors.reset
            let rightArrow = if pag.CurrentPage < pag.TotalPages - 1 then sprintf "%s▶%s" Colors.primary Colors.reset else sprintf "%s▶%s" Colors.surfaceVariant Colors.reset
            sprintf "%s Page %d of %d %s" leftArrow (pag.CurrentPage + 1) pag.TotalPages rightArrow

    // -------------------------------------------------------------------------
    // COMPONENT: Viewport
    // -------------------------------------------------------------------------
    // Scrollable content container with scroll indicators
    // Supports vertical scrolling with position awareness

    type Viewport = {
        Content: string list
        VisibleHeight: int
        ScrollOffset: int
        Width: int
        ShowScrollbar: bool
        HighPerformance: bool   // For alternate screen buffer apps
    }

    let renderViewport (vp: Viewport) =
        let totalLines = vp.Content.Length
        let maxOffset = max 0 (totalLines - vp.VisibleHeight)
        let offset = min vp.ScrollOffset maxOffset

        // Get visible slice
        let visibleContent =
            vp.Content
            |> List.skip offset
            |> List.truncate vp.VisibleHeight
            |> List.map (fun line ->
                if line.Length > vp.Width then line.Substring(0, vp.Width - 1) + "…"
                else line.PadRight(vp.Width)
            )

        // Scrollbar calculation
        let scrollbar =
            if vp.ShowScrollbar && totalLines > vp.VisibleHeight then
                let scrollbarHeight = max 1 (vp.VisibleHeight * vp.VisibleHeight / totalLines)
                let scrollbarPos = if maxOffset > 0 then offset * (vp.VisibleHeight - scrollbarHeight) / maxOffset else 0
                [
                    for i in 0 .. vp.VisibleHeight - 1 do
                        if i >= scrollbarPos && i < scrollbarPos + scrollbarHeight then
                            sprintf "%s█%s" Colors.primary Colors.reset
                        else
                            sprintf "%s░%s" Colors.surfaceVariant Colors.reset
                ]
            else
                List.replicate vp.VisibleHeight " "

        // Scroll position indicator
        let posIndicator =
            if totalLines > vp.VisibleHeight then
                let pct = if maxOffset > 0 then offset * 100 / maxOffset else 0
                sprintf "%s── %d%% ──%s" Colors.outline pct Colors.reset
            else
                ""

        // Combine content with scrollbar
        let lines = [
            for i in 0 .. visibleContent.Length - 1 do
                sprintf "%s%s" visibleContent.[i] scrollbar.[i]
        ]

        if posIndicator <> "" then
            lines @ [posIndicator]
        else
            lines

    // -------------------------------------------------------------------------
    // COMPONENT: FilePicker
    // -------------------------------------------------------------------------
    // Directory and file selection with filtering
    // Supports file type filtering and directory navigation

    type FileType = Directory | File | Symlink | Unknown

    type FileEntry = {
        Name: string
        Path: string
        Type: FileType
        Size: int64 option
        Modified: DateTime option
        Selected: bool
    }

    type FilePicker = {
        CurrentPath: string
        Entries: FileEntry list
        SelectedIndex: int
        ShowHidden: bool
        AllowedExtensions: string list option  // None = all files
        ShowDetails: bool
    }

    let renderFilePicker (fp: FilePicker) =
        let typeIcon entry =
            match entry.Type with
            | Directory -> sprintf "%s📁%s" Colors.advisory Colors.reset
            | File -> sprintf "%s📄%s" Colors.onSurface Colors.reset
            | Symlink -> sprintf "%s🔗%s" Colors.secondary Colors.reset
            | Unknown -> sprintf "%s❓%s" Colors.surfaceVariant Colors.reset

        let sizeStr (size: int64 option) =
            match size with
            | None -> "     "
            | Some s when s < 1024L -> sprintf "%4dB" s
            | Some s when s < 1024L * 1024L -> sprintf "%4dK" (s / 1024L)
            | Some s when s < 1024L * 1024L * 1024L -> sprintf "%4dM" (s / 1024L / 1024L)
            | Some s -> sprintf "%4dG" (s / 1024L / 1024L / 1024L)

        let header = sprintf "%s┌─ %s ─┐%s" Colors.outline fp.CurrentPath Colors.reset

        let entries = [
            // Parent directory
            sprintf "%s│ %s📁 ..%s" Colors.outline Colors.advisory Colors.reset

            // Entries
            for i, entry in fp.Entries |> List.indexed do
                let selected = i = fp.SelectedIndex
                let prefix = if selected then sprintf "%s▶%s" Colors.primary Colors.reset else " "
                let highlight = if selected then Colors.primary else ""
                let nameColor = if entry.Type = Directory then Colors.advisory else Colors.onSurface

                if fp.ShowDetails then
                    let size = sizeStr entry.Size
                    sprintf "%s│%s %s %s%s%-30s%s %s │%s"
                        Colors.outline prefix (typeIcon entry) highlight nameColor entry.Name Colors.reset size Colors.reset
                else
                    sprintf "%s│%s %s %s%s%s%s │%s"
                        Colors.outline prefix (typeIcon entry) highlight nameColor entry.Name Colors.reset Colors.reset
        ]

        let footer = sprintf "%s└─ %d items ─┘%s" Colors.outline fp.Entries.Length Colors.reset

        [header] @ entries @ [footer]

    // -------------------------------------------------------------------------
    // COMPONENT: Timer
    // -------------------------------------------------------------------------
    // Countdown timer with customizable display format
    // Supports pause, reset, and completion callbacks

    type TimerState = Running | Paused | Finished | Idle

    type Timer = {
        Duration: TimeSpan
        Remaining: TimeSpan
        State: TimerState
        ShowMilliseconds: bool
        Label: string option
    }

    let renderTimer (timer: Timer) =
        let formatTime (ts: TimeSpan) showMs =
            if showMs then
                sprintf "%02d:%02d:%02d.%03d" ts.Hours ts.Minutes ts.Seconds ts.Milliseconds
            else
                sprintf "%02d:%02d:%02d" ts.Hours ts.Minutes ts.Seconds

        let timeStr = formatTime timer.Remaining timer.ShowMilliseconds

        let stateIcon =
            match timer.State with
            | Running -> sprintf "%s▶%s" Colors.advisory Colors.reset
            | Paused -> sprintf "%s⏸%s" Colors.caution Colors.reset
            | Finished -> sprintf "%s✓%s" Colors.primary Colors.reset
            | Idle -> sprintf "%s○%s" Colors.outline Colors.reset

        let timeColor =
            match timer.State with
            | Finished -> Colors.primary
            | Running when timer.Remaining < TimeSpan.FromSeconds(10.0) -> Colors.warning
            | Running when timer.Remaining < TimeSpan.FromSeconds(30.0) -> Colors.caution
            | _ -> Colors.onSurface

        // Progress bar
        let progress =
            if timer.Duration.TotalSeconds > 0.0 then
                let pct = timer.Remaining.TotalSeconds / timer.Duration.TotalSeconds
                let filled = int (pct * 20.0)
                let empty = 20 - filled
                sprintf "%s%s%s%s%s"
                    Colors.primary (String.replicate filled "█")
                    Colors.surfaceVariant (String.replicate empty "░")
                    Colors.reset
            else
                String.replicate 20 "░"

        let label = timer.Label |> Option.defaultValue "Timer"

        [
            sprintf "%s┌─ %s ─────────────────────┐%s" Colors.outline label Colors.reset
            sprintf "%s│ %s %s%s%s               │%s" Colors.outline stateIcon timeColor timeStr Colors.reset Colors.reset
            sprintf "%s│ %s │%s" Colors.outline progress Colors.reset
            sprintf "%s└───────────────────────────┘%s" Colors.outline Colors.reset
        ]

    // -------------------------------------------------------------------------
    // COMPONENT: Stopwatch
    // -------------------------------------------------------------------------
    // Elapsed time counter with lap support
    // Tracks running duration with optional lap times

    type StopwatchState = StopwatchRunning | StopwatchStopped | StopwatchReset

    type Stopwatch = {
        Elapsed: TimeSpan
        State: StopwatchState
        Laps: TimeSpan list
        ShowLaps: bool
        ShowMilliseconds: bool
    }

    let renderStopwatch (sw: Stopwatch) =
        let formatTime (ts: TimeSpan) showMs =
            if showMs then
                sprintf "%02d:%02d:%02d.%03d" ts.Hours ts.Minutes ts.Seconds ts.Milliseconds
            else
                sprintf "%02d:%02d:%02d" ts.Hours ts.Minutes ts.Seconds

        let mainTime = formatTime sw.Elapsed sw.ShowMilliseconds

        let stateIcon =
            match sw.State with
            | StopwatchRunning -> sprintf "%s▶%s" Colors.advisory Colors.reset
            | StopwatchStopped -> sprintf "%s⏹%s" Colors.caution Colors.reset
            | StopwatchReset -> sprintf "%s○%s" Colors.outline Colors.reset

        let timeColor =
            match sw.State with
            | StopwatchRunning -> Colors.primary
            | _ -> Colors.onSurface

        let lapLines =
            if sw.ShowLaps && not sw.Laps.IsEmpty then
                [
                    sprintf "%s├───────────────────────────┤%s" Colors.outline Colors.reset
                    sprintf "%s│ Laps:                     │%s" Colors.outline Colors.reset
                ] @ [
                    for i, lap in sw.Laps |> List.indexed |> List.rev |> List.truncate 5 do
                        sprintf "%s│  %2d. %s%s%s          │%s"
                            Colors.outline (i + 1) Colors.secondary (formatTime lap false) Colors.reset Colors.reset
                ]
            else
                []

        [
            sprintf "%s┌─ Stopwatch ────────────────┐%s" Colors.outline Colors.reset
            sprintf "%s│ %s %s%s%s                │%s" Colors.outline stateIcon timeColor mainTime Colors.reset Colors.reset
        ] @ lapLines @ [
            sprintf "%s└────────────────────────────┘%s" Colors.outline Colors.reset
        ]

    // -------------------------------------------------------------------------
    // COMPONENT: Help
    // -------------------------------------------------------------------------
    // Auto-generated help view from keybindings
    // Supports single-line and multi-line modes

    type KeyBinding = {
        Key: string
        Description: string
        Group: string option
    }

    type HelpStyle = SingleLine | MultiLine | Grouped

    type Help = {
        Bindings: KeyBinding list
        Style: HelpStyle
        MaxWidth: int
        Separator: string
    }

    let renderHelp (help: Help) =
        let formatBinding (kb: KeyBinding) =
            sprintf "%s%s%s %s%s%s"
                Colors.primary kb.Key Colors.reset
                Colors.onSurface kb.Description Colors.reset

        match help.Style with
        | SingleLine ->
            // Horizontal: ↑/↓ navigate • enter select • q quit
            let bindings = help.Bindings |> List.map formatBinding
            let line = String.concat (sprintf " %s%s%s " Colors.surfaceVariant help.Separator Colors.reset) bindings
            if line.Length > help.MaxWidth then
                line.Substring(0, help.MaxWidth - 3) + "..."
            else
                line

        | MultiLine ->
            // Vertical list
            [
                for kb in help.Bindings do
                    sprintf "  %s%-10s%s %s%s%s"
                        Colors.primary kb.Key Colors.reset
                        Colors.onSurface kb.Description Colors.reset
            ] |> String.concat "\n"

        | Grouped ->
            // Grouped by category
            let groups =
                help.Bindings
                |> List.groupBy (fun kb -> kb.Group |> Option.defaultValue "General")

            [
                for groupName, bindings in groups do
                    sprintf "%s%s%s" Colors.secondary groupName Colors.reset
                    for kb in bindings do
                        sprintf "  %s%-10s%s %s%s%s"
                            Colors.primary kb.Key Colors.reset
                            Colors.onSurface kb.Description Colors.reset
            ] |> String.concat "\n"

    // -------------------------------------------------------------------------
    // COMPONENT: FuzzyFilter
    // -------------------------------------------------------------------------
    // Fuzzy text filtering for lists (enhancement to List component)
    // Provides ranked search results with highlighting

    type FuzzyMatch = {
        Item: string
        Score: int
        MatchedIndices: int list
    }

    type FuzzyFilter = {
        Query: string
        Items: string list
        Matches: FuzzyMatch list
        MaxResults: int
    }

    let fuzzyScore (query: string) (item: string) =
        // Simple fuzzy matching algorithm
        let queryLower = query.ToLower()
        let itemLower = item.ToLower()

        let mutable score = 0
        let mutable queryIdx = 0
        let mutable matchedIndices = []

        for i in 0 .. itemLower.Length - 1 do
            if queryIdx < queryLower.Length && itemLower.[i] = queryLower.[queryIdx] then
                matchedIndices <- i :: matchedIndices
                score <- score + 10
                // Bonus for consecutive matches
                if matchedIndices.Length > 1 && matchedIndices.[0] = matchedIndices.[1] + 1 then
                    score <- score + 5
                // Bonus for start of word
                if i = 0 || itemLower.[i-1] = ' ' || itemLower.[i-1] = '_' || itemLower.[i-1] = '-' then
                    score <- score + 3
                queryIdx <- queryIdx + 1

        if queryIdx = queryLower.Length then
            Some { Item = item; Score = score; MatchedIndices = List.rev matchedIndices }
        else
            None

    let applyFuzzyFilter (ff: FuzzyFilter) =
        if ff.Query = "" then
            ff.Items |> List.map (fun item -> { Item = item; Score = 0; MatchedIndices = [] })
        else
            ff.Items
            |> List.choose (fuzzyScore ff.Query)
            |> List.sortByDescending (fun m -> m.Score)
            |> List.truncate ff.MaxResults

    let renderFuzzyMatch (fm: FuzzyMatch) =
        // Highlight matched characters
        let chars = fm.Item.ToCharArray()
        let highlighted =
            chars
            |> Array.mapi (fun i c ->
                if List.contains i fm.MatchedIndices then
                    sprintf "%s%c%s" Colors.primary c Colors.reset
                else
                    sprintf "%s%c%s" Colors.onSurface c Colors.reset
            )
        String.concat "" highlighted

    // =========================================================================
    // LAYOUT BOXER - Composable Layout System
    // =========================================================================
    // Inspired by treilik/bubbleboxer for Bubble Tea
    // Reference: https://github.com/treilik/bubbleboxer
    //
    // Provides a tree-based layout system for composing multiple components
    // into complex dashboard layouts with horizontal/vertical splits.

    // -------------------------------------------------------------------------
    // COMPONENT: LayoutBoxer
    // -------------------------------------------------------------------------
    // Tree-based layout composition system

    /// Orientation for split layouts
    type Orientation = Horizontal | Vertical

    /// Sizing strategy for layout nodes
    type SizeStrategy =
        | Fixed of int          // Fixed number of characters/lines
        | Percent of int        // Percentage of parent (0-100)
        | Flex of int           // Flex weight (like CSS flexbox)
        | Auto                  // Size to content

    /// Border style for layout boxes
    type BoxBorder =
        | NoBorder
        | SingleLine
        | DoubleLine
        | RoundedCorners
        | HeavyLine
        | DashedLine

    /// Address for accessing nodes in the layout tree
    type NodeAddress = string list  // e.g., ["root"; "left"; "top"]

    /// Content that can be rendered in a leaf node
    type BoxContent =
        | Text of string list                    // Static text lines
        | Dynamic of (int * int -> string list)  // Function taking (width, height) -> lines
        | Empty                                  // Placeholder

    /// Layout node - can be a leaf or a split container
    type LayoutNode =
        | Leaf of LeafNode
        | Split of SplitNode

    and LeafNode = {
        Address: string
        Content: BoxContent
        Title: string option
        Border: BoxBorder
        Padding: int
        Focused: bool
    }

    and SplitNode = {
        Address: string
        Orientation: Orientation
        Children: (LayoutNode * SizeStrategy) list
        Spacing: int
        Border: BoxBorder
    }

    /// The main LayoutBoxer container
    type LayoutBoxer = {
        Root: LayoutNode
        Width: int
        Height: int
        FocusedAddress: NodeAddress option
    }

    // Helper: Draw box borders
    let private boxChars (border: BoxBorder) =
        match border with
        | NoBorder -> (' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ')  // No visible border
        | SingleLine -> ('┌', '┐', '└', '┘', '─', '│', '├', '┤')
        | DoubleLine -> ('╔', '╗', '╚', '╝', '═', '║', '╠', '╣')
        | RoundedCorners -> ('╭', '╮', '╰', '╯', '─', '│', '├', '┤')
        | HeavyLine -> ('┏', '┓', '┗', '┛', '━', '┃', '┣', '┫')
        | DashedLine -> ('┌', '┐', '└', '┘', '╌', '╎', '├', '┤')

    // Helper: Render a bordered box with content
    let private renderBox (content: string list) (width: int) (height: int)
                          (border: BoxBorder) (title: string option) (focused: bool) (padding: int) =
        let (tl, tr, bl, br, h, v, ml, mr) = boxChars border

        let borderColor = if focused then Colors.primary else Colors.outline
        let titleColor = if focused then Colors.primary else Colors.secondary

        // Calculate inner dimensions
        let hasBorder = border <> NoBorder
        let innerWidth = if hasBorder then width - 2 - (padding * 2) else width - (padding * 2)
        let innerHeight = if hasBorder then height - 2 - (padding * 2) else height - (padding * 2)

        // Pad/truncate content to fit
        let paddedContent =
            content
            |> List.map (fun line ->
                let padded = String.replicate padding " " + line + String.replicate padding " "
                if padded.Length > innerWidth + (padding * 2) then
                    padded.Substring(0, innerWidth + (padding * 2) - 1) + "…"
                else
                    padded.PadRight(innerWidth + (padding * 2))
            )
            |> List.truncate innerHeight
            |> fun lines ->
                let missing = innerHeight - lines.Length
                if missing > 0 then
                    lines @ List.replicate missing (String.replicate (innerWidth + (padding * 2)) " ")
                else
                    lines

        if hasBorder then
            let hStr = string h
            let vStr = string v

            // Top border with optional title
            let topBorder =
                match title with
                | Some t ->
                    let titleStr = sprintf " %s " t
                    let leftLen = 2
                    let rightLen = width - 4 - titleStr.Length
                    if rightLen > 0 then
                        borderColor + string tl + String.replicate leftLen hStr +
                        titleColor + titleStr +
                        borderColor + String.replicate rightLen hStr + string tr + Colors.reset
                    else
                        borderColor + string tl + String.replicate (width - 2) hStr + string tr + Colors.reset
                | None ->
                    borderColor + string tl + String.replicate (width - 2) hStr + string tr + Colors.reset

            // Content lines with side borders
            let contentLines =
                paddedContent
                |> List.map (fun line ->
                    borderColor + vStr + Colors.reset + line + borderColor + vStr + Colors.reset
                )

            // Bottom border
            let bottomBorder =
                borderColor + string bl + String.replicate (width - 2) hStr + string br + Colors.reset

            [topBorder] @ contentLines @ [bottomBorder]
        else
            paddedContent

    // Helper: Calculate actual sizes from size strategies
    let private calculateSizes (strategies: SizeStrategy list) (available: int) (spacing: int) =
        let totalSpacing = spacing * (strategies.Length - 1)
        let availableForContent = available - totalSpacing

        // First pass: allocate fixed and percent
        let fixedAndPercent =
            strategies
            |> List.map (fun s ->
                match s with
                | Fixed n -> Some (min n availableForContent)
                | Percent p -> Some (availableForContent * p / 100)
                | _ -> None
            )

        let usedSpace = fixedAndPercent |> List.choose id |> List.sum
        let remainingSpace = max 0 (availableForContent - usedSpace)

        // Second pass: allocate flex
        let totalFlex =
            strategies
            |> List.sumBy (fun s -> match s with Flex f -> f | _ -> 0)

        strategies
        |> List.mapi (fun i s ->
            match fixedAndPercent.[i] with
            | Some size -> size
            | None ->
                match s with
                | Flex f when totalFlex > 0 -> remainingSpace * f / totalFlex
                | Auto -> 10  // Default auto size
                | _ -> 0
        )

    // Recursive render function for layout nodes
    let rec private renderNode (node: LayoutNode) (width: int) (height: int) (focusedAddr: NodeAddress option) : string list =
        match node with
        | Leaf leaf ->
            let isFocused =
                match focusedAddr with
                | Some addr -> addr = [leaf.Address]
                | None -> leaf.Focused

            let content =
                match leaf.Content with
                | Text lines -> lines
                | Dynamic f -> f (width, height)
                | Empty -> []

            renderBox content width height leaf.Border leaf.Title isFocused leaf.Padding

        | Split split ->
            let childStrategies = split.Children |> List.map snd
            let sizes = calculateSizes childStrategies (if split.Orientation = Horizontal then width else height) split.Spacing

            match split.Orientation with
            | Horizontal ->
                // Render children side by side
                let renderedChildren =
                    split.Children
                    |> List.mapi (fun i (child, _) ->
                        let childWidth = sizes.[i]
                        renderNode child childWidth height focusedAddr
                    )

                // Combine horizontally (zip lines)
                let maxLines = renderedChildren |> List.map List.length |> List.max
                [
                    for lineIdx in 0 .. maxLines - 1 do
                        let lineParts =
                            renderedChildren
                            |> List.mapi (fun i childLines ->
                                let line =
                                    if lineIdx < childLines.Length then childLines.[lineIdx]
                                    else String.replicate sizes.[i] " "
                                let spacing = if i < renderedChildren.Length - 1 then String.replicate split.Spacing " " else ""
                                line + spacing
                            )
                        String.concat "" lineParts
                ]

            | Vertical ->
                // Render children stacked vertically
                split.Children
                |> List.mapi (fun i (child, _) ->
                    let childHeight = sizes.[i]
                    let rendered = renderNode child width childHeight focusedAddr
                    let spacing =
                        if i < split.Children.Length - 1 then
                            List.replicate split.Spacing ""
                        else
                            []
                    rendered @ spacing
                )
                |> List.concat

    /// Render the complete layout
    let renderLayoutBoxer (boxer: LayoutBoxer) : string list =
        renderNode boxer.Root boxer.Width boxer.Height boxer.FocusedAddress

    /// Find a node by address
    let rec findNode (node: LayoutNode) (address: string) : LayoutNode option =
        match node with
        | Leaf leaf when leaf.Address = address -> Some node
        | Split split when split.Address = address -> Some node
        | Split split ->
            split.Children
            |> List.tryPick (fun (child, _) -> findNode child address)
        | _ -> None

    /// Update content of a leaf node by address
    let rec updateLeafContent (node: LayoutNode) (address: string) (newContent: BoxContent) : LayoutNode =
        match node with
        | Leaf leaf when leaf.Address = address ->
            Leaf { leaf with Content = newContent }
        | Split split ->
            Split {
                split with
                    Children =
                        split.Children
                        |> List.map (fun (child, size) ->
                            (updateLeafContent child address newContent, size)
                        )
            }
        | other -> other

    /// Set focus to a specific node
    let setFocus (boxer: LayoutBoxer) (address: string) : LayoutBoxer =
        { boxer with FocusedAddress = Some [address] }

    // -------------------------------------------------------------------------
    // Layout Builder DSL
    // -------------------------------------------------------------------------
    // Fluent API for building layouts

    /// Create a leaf node
    let leaf address content =
        Leaf {
            Address = address
            Content = Text content
            Title = None
            Border = SingleLine
            Padding = 1
            Focused = false
        }

    /// Create a leaf with title
    let leafWithTitle address title content =
        Leaf {
            Address = address
            Content = Text content
            Title = Some title
            Border = SingleLine
            Padding = 1
            Focused = false
        }

    /// Create a dynamic leaf
    let dynamicLeaf address title (render: int * int -> string list) =
        Leaf {
            Address = address
            Content = Dynamic render
            Title = Some title
            Border = SingleLine
            Padding = 1
            Focused = false
        }

    /// Create a horizontal split
    let hsplit address spacing children =
        Split {
            Address = address
            Orientation = Horizontal
            Children = children
            Spacing = spacing
            Border = NoBorder
        }

    /// Create a vertical split
    let vsplit address spacing children =
        Split {
            Address = address
            Orientation = Vertical
            Children = children
            Spacing = spacing
            Border = NoBorder
        }

    /// Create the boxer container
    let boxer width height root =
        {
            Root = root
            Width = width
            Height = height
            FocusedAddress = None
        }

    // -------------------------------------------------------------------------
    // Pre-built Layout Templates
    // -------------------------------------------------------------------------

    /// Classic 3-pane layout: sidebar | main | details
    let threeColumnLayout (sidebarContent: string list) (mainContent: string list) (detailsContent: string list) width height =
        boxer width height (
            hsplit "root" 1 [
                (leafWithTitle "sidebar" "Navigation" sidebarContent, Percent 20)
                (leafWithTitle "main" "Content" mainContent, Flex 1)
                (leafWithTitle "details" "Details" detailsContent, Percent 25)
            ]
        )

    /// Dashboard layout: header, 3 columns, footer
    let dashboardLayout width height =
        boxer width height (
            vsplit "root" 0 [
                (leafWithTitle "header" "PRAJNA C3I COCKPIT" ["System Status: HEALTHY"], Fixed 3)
                (hsplit "body" 1 [
                    (leafWithTitle "nav" "Navigation" ["Dashboard"; "Alarms"; "Commands"], Percent 15)
                    (leafWithTitle "main" "Main View" [], Flex 1)
                    (leafWithTitle "copilot" "AI Copilot" ["Ready..."], Percent 25)
                ], Flex 1)
                (leaf "footer" ["◀ q:quit │ ?:help │ tab:focus ▶"], Fixed 3)
            ]
        )

    /// Split view: left | right
    let splitHorizontal (leftContent: string list) (rightContent: string list) width height =
        boxer width height (
            hsplit "root" 1 [
                (leafWithTitle "left" "Left Panel" leftContent, Percent 50)
                (leafWithTitle "right" "Right Panel" rightContent, Percent 50)
            ]
        )

    /// Stacked view: top / bottom
    let splitVertical (topContent: string list) (bottomContent: string list) width height =
        boxer width height (
            vsplit "root" 1 [
                (leafWithTitle "top" "Top Panel" topContent, Percent 50)
                (leafWithTitle "bottom" "Bottom Panel" bottomContent, Percent 50)
            ]
        )

    // =========================================================================
    // APPLE HIG-INSPIRED DESIGN PRINCIPLES FOR TUI
    // =========================================================================
    //
    // Adapted from Apple Human Interface Guidelines for Terminal UI contexts.
    // Core principles: Clarity, Deference, Depth, Hierarchy, Consistency
    //
    // STAMP Compliance:
    //   - SC-HMI-008: HIG accessibility compliance (contrast, colorblind)
    //   - SC-HMI-009: Feedback timing requirements (100ms, 250ms, 500ms)
    //   - SC-HMI-010: Navigation depth limits (two-keypress access)
    //   - SC-HMI-011: Focus management and visual indication
    //
    // References:
    //   - Apple HIG: developer.apple.com/design/human-interface-guidelines
    //   - WCAG 2.1: www.w3.org/WAI/WCAG21/quickref
    // =========================================================================

    /// Apple HIG: Accessibility Module
    /// Provides contrast checking, colorblind-safe patterns, and screen reader hints
    module Accessibility =

        // -------------------------------------------------------------------------
        // Contrast Ratios (WCAG 2.1 / Apple HIG Compliant)
        // -------------------------------------------------------------------------

        /// Minimum contrast ratio for body text (WCAG AA)
        let minContrastRatioText = 4.5

        /// Minimum contrast ratio for large text (WCAG AA)
        let minContrastRatioLarge = 3.0

        /// Minimum contrast ratio for UI components and graphics
        let minContrastRatioUI = 3.0

        /// Enhanced contrast ratio for high contrast mode (WCAG AAA)
        let enhancedContrastRatio = 7.0

        /// Calculate relative luminance of RGB color (0-255 range)
        let relativeLuminance (r: int) (g: int) (b: int) : float =
            let toLinear c =
                let c' = float c / 255.0
                if c' <= 0.03928 then c' / 12.92
                else ((c' + 0.055) / 1.055) ** 2.4
            0.2126 * toLinear r + 0.7152 * toLinear g + 0.0722 * toLinear b

        /// Calculate contrast ratio between two colors
        let contrastRatio (r1, g1, b1) (r2, g2, b2) : float =
            let l1 = relativeLuminance r1 g1 b1
            let l2 = relativeLuminance r2 g2 b2
            let lighter = max l1 l2
            let darker = min l1 l2
            (lighter + 0.05) / (darker + 0.05)

        /// Check if contrast ratio meets WCAG AA for normal text
        let meetsWCAGAA fg bg = contrastRatio fg bg >= minContrastRatioText

        /// Check if contrast ratio meets WCAG AAA for enhanced contrast
        let meetsWCAGAAA fg bg = contrastRatio fg bg >= enhancedContrastRatio

        // -------------------------------------------------------------------------
        // Colorblind-Safe Patterns (HIG: "Convey info with more than color alone")
        // -------------------------------------------------------------------------

        /// Colorblind-safe status indicators using both color AND shape
        type ColorblindSafeIndicator =
            | SafeSuccess   // ✓ (green + checkmark)
            | SafeWarning   // ⚠ (amber + triangle)
            | SafeError     // ✗ (red + cross)
            | SafeInfo      // ℹ (blue + info circle)
            | SafeNeutral   // ● (gray + filled circle)
            | SafeProgress  // ◐ (cyan + half circle)

        /// Render colorblind-safe indicator with color and shape
        let renderSafeIndicator (indicator: ColorblindSafeIndicator) : string =
            match indicator with
            | SafeSuccess  -> Colors.advisory + "✓" + Colors.reset
            | SafeWarning  -> Colors.caution + "⚠" + Colors.reset
            | SafeError    -> Colors.error + "✗" + Colors.reset
            | SafeInfo     -> Colors.primary + "ℹ" + Colors.reset
            | SafeNeutral  -> Colors.normal + "●" + Colors.reset
            | SafeProgress -> Colors.tertiary + "◐" + Colors.reset

        /// Pattern fills for distinguishing data (colorblind-safe)
        type PatternFill =
            | Solid of char        // ████
            | Horizontal           // ════
            | Vertical             // ║║║║
            | DiagonalRight        // ////
            | DiagonalLeft         // \\\\
            | Cross                // ╬╬╬╬
            | Dots                 // ····
            | Sparse               // · · ·

        /// Render pattern fill string
        let renderPattern (pattern: PatternFill) (width: int) : string =
            let patternStr =
                match pattern with
                | Solid c -> string c
                | Horizontal -> "═"
                | Vertical -> "│"
                | DiagonalRight -> "/"
                | DiagonalLeft -> "\\"
                | Cross -> "╬"
                | Dots -> "·"
                | Sparse -> "· "  // alternating dot-space
            match pattern with
            | Sparse ->
                // Create alternating pattern: · · · ·
                let pairs = width / 2
                let remainder = width % 2
                String.replicate pairs patternStr + (if remainder > 0 then "·" else "")
            | _ -> String.replicate width patternStr

        // -------------------------------------------------------------------------
        // Screen Reader / VoiceOver Hints
        // -------------------------------------------------------------------------

        /// Accessibility role for screen readers
        type AccessibilityRole =
            | ARButton
            | ARLink
            | ARHeading of int  // Level 1-6
            | ARList
            | ARListItem
            | ARAlert
            | ARDialog
            | ARStatus
            | ARProgressBar
            | ARTabList
            | ARTab
            | ARPanel

        /// Generate accessibility hint string (for logging/debugging)
        let accessibilityHint (role: AccessibilityRole) (label: string) (value: string option) : string =
            let roleStr =
                match role with
                | ARButton -> "button"
                | ARLink -> "link"
                | ARHeading n -> sprintf "heading level %d" n
                | ARList -> "list"
                | ARListItem -> "list item"
                | ARAlert -> "alert"
                | ARDialog -> "dialog"
                | ARStatus -> "status"
                | ARProgressBar -> "progress bar"
                | ARTabList -> "tab list"
                | ARTab -> "tab"
                | ARPanel -> "panel"
            match value with
            | Some v -> sprintf "[%s] %s: %s" roleStr label v
            | None -> sprintf "[%s] %s" roleStr label

    /// Apple HIG: Feedback Timing Constants
    /// Response timing requirements for optimal user experience
    module FeedbackTiming =

        // -------------------------------------------------------------------------
        // Response Timing (Apple HIG Research)
        // -------------------------------------------------------------------------

        /// Instant feedback threshold (ms) - visual confirmation required
        let instantFeedback = 100

        /// Perceptible delay threshold (ms) - user notices lag
        let perceptibleDelay = 250

        /// Maximum acceptable delay (ms) - beyond this, show loading indicator
        let maxAcceptableDelay = 500

        /// Animation duration for micro-interactions (ms)
        let microAnimation = 200

        /// Animation duration for transitions (ms)
        let transitionAnimation = 300

        /// Animation duration for complex animations (ms)
        let complexAnimation = 500

        /// Debounce delay for search input (ms)
        let searchDebounce = 300

        /// Auto-dismiss delay for toast notifications (ms)
        let toastAutoDismiss = 3000

        /// Auto-dismiss delay for success feedback (ms)
        let successAutoDismiss = 2000

        /// Blink interval for critical alerts (ms)
        let criticalBlinkInterval = 500

        // -------------------------------------------------------------------------
        // Loading States
        // -------------------------------------------------------------------------

        /// Loading indicator type based on expected duration
        type LoadingIndicator =
            | Spinner           // < 500ms expected
            | ProgressBar       // Known duration
            | Indeterminate     // Unknown duration
            | Skeleton          // Content placeholder

        /// Recommend loading indicator based on expected wait time
        let recommendLoadingIndicator (expectedMs: int) (isDeterminate: bool) : LoadingIndicator =
            if expectedMs < maxAcceptableDelay then Spinner
            elif isDeterminate then ProgressBar
            else Indeterminate

    /// Apple HIG: Navigation Patterns
    /// Two-keypress access and navigation depth limits
    module Navigation =

        // -------------------------------------------------------------------------
        // Navigation Depth (HIG: "Maximum two-tap access to core features")
        // -------------------------------------------------------------------------

        /// Maximum navigation depth for core features
        let maxCoreFeatureDepth = 2

        /// Maximum navigation depth for any feature
        let maxTotalDepth = 4

        /// Breadcrumb separator
        let breadcrumbSeparator = " > "

        /// Navigation path type
        type NavPath = string list

        /// Check if navigation path is within core feature limit
        let isWithinCoreLimit (path: NavPath) : bool =
            path.Length <= maxCoreFeatureDepth

        /// Check if navigation path is within total limit
        let isWithinTotalLimit (path: NavPath) : bool =
            path.Length <= maxTotalDepth

        /// Render breadcrumb trail
        let renderBreadcrumb (path: NavPath) : string =
            path |> String.concat breadcrumbSeparator

        // -------------------------------------------------------------------------
        // Keyboard Navigation (TUI-adapted from HIG)
        // -------------------------------------------------------------------------

        /// Standard keyboard shortcuts (HIG-inspired for TUI)
        type KeyboardShortcut =
            | KSQuit           // q or Ctrl+C
            | KSHelp           // ? or h
            | KSSearch         // / or Ctrl+F
            | KSRefresh        // r or F5
            | KSBack           // Escape or Backspace
            | KSConfirm        // Enter
            | KSCancel         // Escape
            | KSNextTab        // Tab
            | KSPrevTab        // Shift+Tab
            | KSUp             // k or ↑
            | KSDown           // j or ↓
            | KSLeft           // h or ←
            | KSRight          // l or →
            | KSPageUp         // Ctrl+U or PageUp
            | KSPageDown       // Ctrl+D or PageDown
            | KSHome           // g or Home
            | KSEnd            // G or End
            | KSSelect         // Space
            | KSSelectAll      // Ctrl+A
            | KSCopy           // y (vim) or Ctrl+C (when not quit)
            | KSPaste          // p (vim) or Ctrl+V
            | KSUndo           // u or Ctrl+Z
            | KSRedo           // Ctrl+R

        /// Get key hint for shortcut
        let shortcutHint (shortcut: KeyboardShortcut) : string =
            match shortcut with
            | KSQuit -> "q"
            | KSHelp -> "?"
            | KSSearch -> "/"
            | KSRefresh -> "r"
            | KSBack -> "Esc"
            | KSConfirm -> "Enter"
            | KSCancel -> "Esc"
            | KSNextTab -> "Tab"
            | KSPrevTab -> "S-Tab"
            | KSUp -> "↑"
            | KSDown -> "↓"
            | KSLeft -> "←"
            | KSRight -> "→"
            | KSPageUp -> "PgUp"
            | KSPageDown -> "PgDn"
            | KSHome -> "Home"
            | KSEnd -> "End"
            | KSSelect -> "Space"
            | KSSelectAll -> "^A"
            | KSCopy -> "y"
            | KSPaste -> "p"
            | KSUndo -> "u"
            | KSRedo -> "^R"

        /// Render keyboard shortcut legend
        let renderShortcutLegend (shortcuts: (KeyboardShortcut * string) list) : string =
            shortcuts
            |> List.map (fun (sc, desc) -> sprintf "%s:%s" (shortcutHint sc) desc)
            |> String.concat " │ "

    /// Apple HIG: High Contrast Mode
    /// Enhanced contrast for accessibility
    module HighContrast =

        /// High contrast color palette (WCAG AAA compliant)
        module Colors =
            // Pure black and white for maximum contrast
            let background = "\u001b[48;2;0;0;0m"           // Pure black
            let foreground = "\u001b[38;2;255;255;255m"     // Pure white

            // High contrast semantic colors
            let success = "\u001b[38;2;0;255;0m"            // Pure green
            let warning = "\u001b[38;2;255;255;0m"          // Pure yellow
            let error = "\u001b[38;2;255;0;0m"              // Pure red
            let info = "\u001b[38;2;0;255;255m"             // Pure cyan

            // High contrast borders
            let border = "\u001b[38;2;255;255;255m"         // White borders
            let borderFocused = "\u001b[38;2;0;255;255m"    // Cyan for focus

            // Reset
            let reset = "\u001b[0m"

        /// Check if high contrast mode should be used
        /// (In a real implementation, this would check system preferences)
        let mutable isEnabled = false

        /// Toggle high contrast mode
        let toggle () = isEnabled <- not isEnabled

        /// Get appropriate color based on mode
        let adaptColor (normalColor: string) (highContrastColor: string) : string =
            if isEnabled then highContrastColor else normalColor

    /// Apple HIG: Alert Hierarchy
    /// Confirmation patterns and destructive action handling
    module AlertHierarchy =

        // -------------------------------------------------------------------------
        // Alert Levels (HIG-inspired priority system)
        // -------------------------------------------------------------------------

        /// Alert priority level
        type AlertPriority =
            | APCritical    // Requires immediate attention, blocks workflow
            | APHigh        // Important but doesn't block
            | APMedium      // Standard notification
            | APLow         // Informational only
            | APSuccess     // Positive confirmation

        /// Alert action type
        type AlertAction =
            | AADestructive of string   // Red, requires confirmation
            | AAPrimary of string       // Emphasized action
            | AASecondary of string     // Standard action
            | AACancel                  // Always available escape

        /// Confirmation requirement
        type ConfirmationLevel =
            | CLNone                    // No confirmation needed
            | CLSingle                  // Single confirmation (Enter)
            | CLDouble                  // Double confirmation (type word)
            | CLTimed of int            // Timed confirmation (countdown)

        /// Determine confirmation level for action
        let getConfirmationLevel (action: AlertAction) : ConfirmationLevel =
            match action with
            | AADestructive _ -> CLDouble
            | AAPrimary _ -> CLSingle
            | AASecondary _ -> CLNone
            | AACancel -> CLNone

        /// Render alert box with appropriate styling
        let renderAlert (priority: AlertPriority) (title: string) (message: string) (actions: AlertAction list) : string list =
            let (borderColor, icon) =
                match priority with
                | APCritical -> (Colors.critical, "☢")
                | APHigh -> (Colors.warning, "⛔")
                | APMedium -> (Colors.caution, "⚠")
                | APLow -> (Colors.advisory, "ℹ")
                | APSuccess -> (Colors.advisory, "✓")

            let actionLine =
                actions
                |> List.map (fun a ->
                    match a with
                    | AADestructive s -> Colors.error + "[" + s + "]" + Colors.reset
                    | AAPrimary s -> Colors.primary + "[" + s + "]" + Colors.reset
                    | AASecondary s -> Colors.secondary + "[" + s + "]" + Colors.reset
                    | AACancel -> Colors.normal + "[Cancel]" + Colors.reset
                )
                |> String.concat "  "

            [
                borderColor + "┌" + String.replicate 48 "─" + "┐" + Colors.reset
                borderColor + "│" + Colors.reset + " " + icon + " " + Typography.titleMedium + title + Colors.reset + String.replicate (44 - title.Length) " " + borderColor + "│" + Colors.reset
                borderColor + "├" + String.replicate 48 "─" + "┤" + Colors.reset
                borderColor + "│" + Colors.reset + " " + message.PadRight(47) + borderColor + "│" + Colors.reset
                borderColor + "├" + String.replicate 48 "─" + "┤" + Colors.reset
                borderColor + "│" + Colors.reset + " " + actionLine.PadRight(47) + borderColor + "│" + Colors.reset
                borderColor + "└" + String.replicate 48 "─" + "┘" + Colors.reset
            ]

        // -------------------------------------------------------------------------
        // Destructive Action Patterns (HIG Two-Step Commit)
        // -------------------------------------------------------------------------

        /// Destructive action confirmation state
        type DestructiveConfirmState =
            | DCSIdle                       // Not started
            | DCSArmed of DateTime          // First confirmation, waiting for second
            | DCSConfirming of string       // User typing confirmation word
            | DCSExecuting                  // Action in progress
            | DCSComplete of bool           // Success/failure

        /// Time limit for armed state (seconds)
        let armedTimeout = 30

        /// Check if armed state has expired
        let isArmedExpired (armedAt: DateTime) : bool =
            (DateTime.UtcNow - armedAt).TotalSeconds > float armedTimeout

        /// Generate random confirmation word
        let generateConfirmationWord () : string =
            let words = [| "CONFIRM"; "DELETE"; "REMOVE"; "DESTROY"; "PROCEED" |]
            words.[Random().Next(words.Length)]

    /// Apple HIG: Focus Management
    /// Clear visual focus indicators and focus trap patterns
    module FocusManagement =

        // -------------------------------------------------------------------------
        // Focus Indicator Styles
        // -------------------------------------------------------------------------

        /// Focus indicator style
        type FocusStyle =
            | FSOutline         // Border highlight
            | FSBackground      // Background color change
            | FSUnderline       // Underline indicator
            | FSBold            // Bold text
            | FSCombined        // Multiple indicators

        /// Default focus style for TUI
        let defaultFocusStyle = FSOutline

        /// Render focus indicator prefix/suffix
        let renderFocusIndicator (style: FocusStyle) (isFocused: bool) : string * string =
            if not isFocused then ("", "")
            else
                match style with
                | FSOutline -> (Colors.primary + "▶ ", " ◀" + Colors.reset)
                | FSBackground -> (Colors.bgPrimary, Colors.reset)
                | FSUnderline -> ("\u001b[4m", "\u001b[24m")
                | FSBold -> (Typography.titleMedium, Colors.reset)
                | FSCombined -> (Colors.primary + "▶ " + Typography.titleMedium, Colors.reset + " ◀" + Colors.reset)

        // -------------------------------------------------------------------------
        // Focus Trap (Modal dialogs)
        // -------------------------------------------------------------------------

        /// Focus trap for modal contexts
        type FocusTrap = {
            Elements: string list       // Focusable element IDs
            CurrentIndex: int           // Currently focused
            WrapAround: bool            // Wrap at ends
        }

        /// Create new focus trap
        let createFocusTrap (elements: string list) : FocusTrap =
            { Elements = elements; CurrentIndex = 0; WrapAround = true }

        /// Move focus to next element
        let focusNext (trap: FocusTrap) : FocusTrap =
            let nextIdx =
                if trap.CurrentIndex >= trap.Elements.Length - 1 then
                    if trap.WrapAround then 0 else trap.CurrentIndex
                else
                    trap.CurrentIndex + 1
            { trap with CurrentIndex = nextIdx }

        /// Move focus to previous element
        let focusPrev (trap: FocusTrap) : FocusTrap =
            let prevIdx =
                if trap.CurrentIndex <= 0 then
                    if trap.WrapAround then trap.Elements.Length - 1 else 0
                else
                    trap.CurrentIndex - 1
            { trap with CurrentIndex = prevIdx }

        /// Get currently focused element
        let currentFocus (trap: FocusTrap) : string option =
            if trap.CurrentIndex < trap.Elements.Length then
                Some trap.Elements.[trap.CurrentIndex]
            else
                None

    /// Apple HIG: Typography Scale
    /// TUI-appropriate text hierarchy system
    module TypographyScale =

        // -------------------------------------------------------------------------
        // Text Size Scale (TUI-adapted)
        // -------------------------------------------------------------------------

        /// Typography level for hierarchy
        type TextLevel =
            | TLDisplay         // Large display text (ASCII art headers)
            | TLHeadline        // Section headers
            | TLTitle           // Component titles
            | TLBody            // Normal text
            | TLLabel           // Small labels
            | TLCaption         // Smallest text (timestamps, hints)

        /// Line height multiplier (for spacing between lines)
        let lineHeightMultiplier (level: TextLevel) : float =
            match level with
            | TLDisplay -> 1.5
            | TLHeadline -> 1.4
            | TLTitle -> 1.3
            | TLBody -> 1.2
            | TLLabel -> 1.1
            | TLCaption -> 1.0

        /// Recommended line length (characters) per level
        let recommendedLineLength (level: TextLevel) : int =
            match level with
            | TLDisplay -> 80      // Full width
            | TLHeadline -> 60     // Generous
            | TLTitle -> 50        // Comfortable
            | TLBody -> 45         // Optimal reading
            | TLLabel -> 35        // Compact
            | TLCaption -> 30      // Minimal

        /// Get ANSI style for text level
        let getStyle (level: TextLevel) : string =
            match level with
            | TLDisplay -> "\u001b[1;4m"     // Bold + Underline
            | TLHeadline -> "\u001b[1m"      // Bold
            | TLTitle -> "\u001b[1m"         // Bold
            | TLBody -> ""                   // Normal
            | TLLabel -> "\u001b[2m"         // Dim
            | TLCaption -> "\u001b[2;3m"     // Dim + Italic

        /// Apply typography style to text
        let applyStyle (level: TextLevel) (text: string) : string =
            let style = getStyle level
            if String.IsNullOrEmpty style then text
            else style + text + Colors.reset

        // -------------------------------------------------------------------------
        // Text Wrapping
        // -------------------------------------------------------------------------

        /// Wrap text to specified width
        let wrapText (maxWidth: int) (text: string) : string list =
            let words = text.Split([|' '|], StringSplitOptions.RemoveEmptyEntries)
            let rec loop (lines: string list) (currentLine: string) (remaining: string list) =
                match remaining with
                | [] ->
                    if String.IsNullOrEmpty currentLine then lines
                    else lines @ [currentLine]
                | word :: rest ->
                    if String.IsNullOrEmpty currentLine then
                        loop lines word rest
                    elif currentLine.Length + 1 + word.Length <= maxWidth then
                        loop lines (currentLine + " " + word) rest
                    else
                        loop (lines @ [currentLine]) word rest
            loop [] "" (Array.toList words)

    /// Apple HIG: Semantic State Colors
    /// State-based color system with automatic adaptation
    module SemanticStates =

        // -------------------------------------------------------------------------
        // State Types
        // -------------------------------------------------------------------------

        /// Interactive element state
        type InteractiveState =
            | ISDefault         // Normal state
            | ISHover           // Mouse hover (N/A in pure TUI but useful for selection)
            | ISPressed         // Active/pressed
            | ISFocused         // Keyboard focused
            | ISDisabled        // Not interactive
            | ISSelected        // Multi-select selected
            | ISLoading         // Loading/busy

        /// Data state
        type DataState =
            | DSEmpty           // No data
            | DSLoading         // Fetching
            | DSSuccess         // Data loaded
            | DSError of string // Error with message
            | DSStale           // Data may be outdated

        /// Connection state
        type ConnectionState =
            | CSConnected       // Online
            | CSConnecting      // Establishing
            | CSDisconnected    // Offline
            | CSError of string // Connection error

        // -------------------------------------------------------------------------
        // State Rendering
        // -------------------------------------------------------------------------

        /// Get color for interactive state
        let interactiveColor (state: InteractiveState) : string =
            match state with
            | ISDefault -> Colors.onSurface
            | ISHover -> Colors.primary
            | ISPressed -> Colors.primaryContainer
            | ISFocused -> Colors.primary
            | ISDisabled -> Colors.outline
            | ISSelected -> Colors.tertiary
            | ISLoading -> Colors.secondary

        /// Get icon for data state
        let dataStateIcon (state: DataState) : string =
            match state with
            | DSEmpty -> "○"
            | DSLoading -> "◐"
            | DSSuccess -> "●"
            | DSError _ -> "✗"
            | DSStale -> "◌"

        /// Get color for data state
        let dataStateColor (state: DataState) : string =
            match state with
            | DSEmpty -> Colors.normal
            | DSLoading -> Colors.advisory
            | DSSuccess -> Colors.advisory
            | DSError _ -> Colors.error
            | DSStale -> Colors.caution

        /// Render connection status indicator
        let renderConnectionStatus (state: ConnectionState) : string =
            match state with
            | CSConnected -> Colors.advisory + "●" + Colors.reset + " Connected"
            | CSConnecting -> Colors.caution + "◐" + Colors.reset + " Connecting..."
            | CSDisconnected -> Colors.normal + "○" + Colors.reset + " Disconnected"
            | CSError msg -> Colors.error + "✗" + Colors.reset + " " + msg

    /// Apple HIG: Motion and Animation Guidelines
    /// Frame timing and animation patterns for TUI
    module Motion =

        // -------------------------------------------------------------------------
        // Animation Timing
        // -------------------------------------------------------------------------

        /// Standard durations (in frames at 60fps or ms)
        module Duration =
            let instant = 0           // No animation
            let fast = 100            // Micro-interactions
            let normal = 200          // Standard transitions
            let slow = 300            // Complex animations
            let emphasis = 500        // Emphasis animations

        /// Easing functions (conceptual for TUI)
        type Easing =
            | Linear
            | EaseIn
            | EaseOut
            | EaseInOut

        // -------------------------------------------------------------------------
        // Spinner Frames
        // -------------------------------------------------------------------------

        /// Spinner animation frames
        let spinnerFrames = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]

        /// Progress bar animation frames
        let progressBarFrames = [| "▱"; "▰" |]

        /// Pulse animation frames
        let pulseFrames = [| "○"; "◔"; "◑"; "◕"; "●"; "◕"; "◑"; "◔" |]

        /// Get spinner frame by index
        let getSpinnerFrame (frameIndex: int) : string =
            spinnerFrames.[frameIndex % spinnerFrames.Length]

        /// Get pulse frame by index
        let getPulseFrame (frameIndex: int) : string =
            pulseFrames.[frameIndex % pulseFrames.Length]

        // -------------------------------------------------------------------------
        // Transition Patterns
        // -------------------------------------------------------------------------

        /// Transition type
        type TransitionType =
            | TTFade            // Opacity change
            | TTSlideLeft       // Slide from right
            | TTSlideRight      // Slide from left
            | TTSlideUp         // Slide from bottom
            | TTSlideDown       // Slide from top
            | TTExpand          // Grow from center
            | TTCollapse        // Shrink to center

        /// Generate transition frames (simplified for TUI)
        let transitionFrames (transition: TransitionType) (content: string list) (steps: int) : string list list =
            // In TUI, transitions are simplified to progressive reveal
            match transition with
            | TTFade ->
                [for i in 0..steps ->
                    if i = steps then content
                    else content |> List.map (fun line -> String.replicate line.Length " ")]
            | TTSlideLeft ->
                [for i in 0..steps ->
                    let offset = (steps - i) * 10
                    content |> List.map (fun line -> String.replicate offset " " + line)]
            | _ -> [content]  // Default: instant

    /// Apple HIG: Unified Design System Entry Point
    /// Combines all HIG-inspired modules for easy access
    module HIG =

        /// Design system version
        let version = "1.0.0"

        /// Design system name
        let name = "Apple HIG-Inspired TUI Design System"

        /// Core principles
        let principles = [
            "Clarity: Make interfaces legible and precise"
            "Deference: Let content take center stage"
            "Depth: Use hierarchy to convey relationships"
            "Consistency: Use familiar patterns"
            "Feedback: Respond to actions immediately"
            "Accessibility: Support all users"
        ]

        /// Quick reference for minimum requirements
        module Requirements =
            let minContrastRatio = 4.5
            let maxResponseTimeMs = 100
            let maxNavDepth = 2
            let minTouchTarget = 44  // Adapted to: full-width interactive elements

        /// Validate a design element against HIG principles
        let validateContrast fg bg =
            let ratio = Accessibility.contrastRatio fg bg
            if ratio >= Requirements.minContrastRatio then
                Ok (sprintf "Contrast ratio %.2f:1 meets WCAG AA" ratio)
            else
                Error (sprintf "Contrast ratio %.2f:1 is below minimum %.1f:1" ratio Requirements.minContrastRatio)

        /// Get recommended settings summary
        let getRecommendations () : string list =
            [
                "Feedback Timing:"
                sprintf "  - Instant feedback: <%dms" FeedbackTiming.instantFeedback
                sprintf "  - Max delay before loader: %dms" FeedbackTiming.maxAcceptableDelay
                ""
                "Navigation:"
                sprintf "  - Core features: max %d keypresses" Navigation.maxCoreFeatureDepth
                sprintf "  - Any feature: max %d keypresses" Navigation.maxTotalDepth
                ""
                "Accessibility:"
                sprintf "  - Min contrast ratio: %.1f:1" Accessibility.minContrastRatioText
                "  - Use both color AND shape for status"
                "  - Support keyboard navigation"
                ""
                "Focus Management:"
                "  - Clear visual focus indicator"
                "  - Tab order follows reading order"
                "  - Focus trap for modals"
            ]

    // ═══════════════════════════════════════════════════════════════════════════
    // TREE VIEW (tview-inspired hierarchical data display)
    // STAMP: SC-HMI-012 (hierarchical navigation)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Tree node representing hierarchical data
    type TreeNode = {
        Id: string
        Label: string
        Icon: string option
        Children: TreeNode list
        Expanded: bool
        Selected: bool
        Level: int
    }

    /// Tree view configuration
    type TreeView = {
        Nodes: TreeNode list
        ShowLines: bool
        ShowIcons: bool
        IndentSize: int
        MaxHeight: int option
        FocusedId: string option
        OnSelect: (string -> unit) option
        OnToggle: (string -> unit) option
    }

    module TreeView =
        /// Create a new tree node
        let createNode id label children =
            { Id = id
              Label = label
              Icon = None
              Children = children
              Expanded = false
              Selected = false
              Level = 0 }

        /// Create a node with icon
        let createNodeWithIcon id label icon children =
            { createNode id label children with Icon = Some icon }

        /// Set the level of a node and its children recursively
        let rec private setLevels level node =
            { node with
                Level = level
                Children = node.Children |> List.map (setLevels (level + 1)) }

        /// Flatten tree to list for rendering
        let rec private flattenNode (node: TreeNode) : (TreeNode * bool * bool) list =
            let siblings = [(node, node.Children.IsEmpty, true)]
            if node.Expanded then
                let childResults =
                    node.Children
                    |> List.mapi (fun i child ->
                        let isLast = i = node.Children.Length - 1
                        (setLevels (node.Level + 1) child, child.Children.IsEmpty, isLast))
                    |> List.collect (fun (n, isLeaf, isLast) ->
                        flattenNode { n with Level = node.Level + 1 }
                        |> List.map (fun (cn, cl, _) -> (cn, cl, isLast)))
                siblings @ childResults
            else
                siblings

        /// Render tree connector lines
        let private renderConnector (level: int) (indentSize: int) (isLast: bool) (isLeaf: bool) (expanded: bool) (showLines: bool) : string =
            if level = 0 then ""
            else
                let indent = String.replicate ((level - 1) * indentSize) " "
                let connector =
                    if showLines then
                        let branch = if isLast then "└" else "├"
                        let line = String.replicate (indentSize - 2) "─"
                        branch + line
                    else
                        String.replicate indentSize " "
                let toggle =
                    if isLeaf then "─"
                    elif expanded then "▼"
                    else "▶"
                indent + connector + toggle + " "

        /// Render a tree view
        let renderTreeView (tree: TreeView) : string list =
            let allNodes =
                tree.Nodes
                |> List.map (setLevels 0)
                |> List.collect flattenNode

            let renderNode (node: TreeNode, isLeaf: bool, isLast: bool) =
                let connector = renderConnector node.Level tree.IndentSize isLast isLeaf node.Expanded tree.ShowLines
                let icon =
                    if tree.ShowIcons then
                        match node.Icon with
                        | Some i -> i + " "
                        | None -> if isLeaf then "📄 " else "📁 "
                    else ""
                let focusIndicator =
                    match tree.FocusedId with
                    | Some id when id = node.Id -> "● "
                    | _ -> ""
                let selectedStyle = if node.Selected then "\x1b[7m" else ""
                let resetStyle = if node.Selected then "\x1b[0m" else ""
                sprintf "%s%s%s%s%s%s" connector focusIndicator selectedStyle icon node.Label resetStyle

            allNodes
            |> List.map renderNode
            |> (fun lines ->
                match tree.MaxHeight with
                | Some h -> List.truncate h lines
                | None -> lines)

        /// Create default tree view
        let create nodes =
            { Nodes = nodes
              ShowLines = true
              ShowIcons = true
              IndentSize = 3
              MaxHeight = None
              FocusedId = None
              OnSelect = None
              OnToggle = None }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEXT AREA (tview-inspired multi-line text editor)
    // STAMP: SC-HMI-013 (multi-line text input)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Text area configuration
    type TextArea = {
        Content: string list
        CursorRow: int
        CursorCol: int
        SelectionStart: (int * int) option
        SelectionEnd: (int * int) option
        Width: int
        Height: int
        ScrollOffset: int
        ReadOnly: bool
        Placeholder: string option
        Label: string option
        ShowLineNumbers: bool
        WrapLines: bool
        MaxLength: int option
        OnChange: (string list -> unit) option
    }

    module TextArea =
        /// Create a new text area
        let create width height =
            { Content = [""]
              CursorRow = 0
              CursorCol = 0
              SelectionStart = None
              SelectionEnd = None
              Width = width
              Height = height
              ScrollOffset = 0
              ReadOnly = false
              Placeholder = None
              Label = None
              ShowLineNumbers = false
              WrapLines = true
              MaxLength = None
              OnChange = None }

        /// Set content
        let setContent (content: string) (ta: TextArea) =
            { ta with Content = content.Split('\n') |> Array.toList }

        /// Get content as string
        let getContent (ta: TextArea) =
            String.concat "\n" ta.Content

        /// Word wrap a line
        let private wrapLine (width: int) (line: string) : string list =
            if line.Length <= width then [line]
            else
                let rec wrap (acc: string list) (remaining: string) : string list =
                    if remaining.Length <= width then
                        List.rev (remaining :: acc)
                    else
                        let breakPoint =
                            match remaining.Substring(0, width).LastIndexOf(' ') with
                            | -1 -> width
                            | i -> i
                        let chunk = remaining.Substring(0, breakPoint)
                        let rest = remaining.Substring(breakPoint).TrimStart()
                        wrap (chunk :: acc) rest
                wrap [] line

        /// Render text area
        let renderTextArea (ta: TextArea) : string list =
            let borderTop = "┌" + String.replicate (ta.Width - 2) "─" + "┐"
            let borderBottom = "└" + String.replicate (ta.Width - 2) "─" + "┘"

            // Process content with optional line numbers and wrapping
            let lineNumWidth = if ta.ShowLineNumbers then (ta.Content.Length.ToString().Length + 2) else 0
            let contentWidth = ta.Width - 2 - lineNumWidth

            let processedLines =
                ta.Content
                |> List.mapi (fun i line ->
                    let lineNum =
                        if ta.ShowLineNumbers then
                            sprintf "%*d│" (lineNumWidth - 1) (i + 1)
                        else ""

                    let lines =
                        if ta.WrapLines then wrapLine contentWidth line
                        else [if line.Length > contentWidth then line.Substring(0, contentWidth) else line]

                    lines |> List.mapi (fun j l ->
                        let num = if j = 0 then lineNum else String.replicate lineNumWidth " "
                        num + l))
                |> List.collect id

            // Apply scroll offset and height
            let visibleLines =
                processedLines
                |> List.skip (min ta.ScrollOffset (max 0 (processedLines.Length - ta.Height + 2)))
                |> List.truncate (ta.Height - 2)

            // Pad to fill height
            let paddedLines =
                let padding = ta.Height - 2 - visibleLines.Length
                if padding > 0 then
                    visibleLines @ List.replicate padding ""
                else visibleLines

            // Apply placeholder if empty
            let displayLines =
                if ta.Content = [""] && ta.Placeholder.IsSome then
                    let placeholder = ta.Placeholder.Value
                    let placeholderStyle = "\x1b[38;5;240m"
                    let reset = "\x1b[0m"
                    [placeholderStyle + placeholder + reset] @ List.replicate (ta.Height - 3) ""
                else paddedLines

            // Render with border
            let contentLines =
                displayLines
                |> List.map (fun line ->
                    let padded = line.PadRight(ta.Width - 2)
                    let truncated = if padded.Length > ta.Width - 2 then padded.Substring(0, ta.Width - 2) else padded
                    "│" + truncated + "│")

            // Add label if present
            let labelLine =
                match ta.Label with
                | Some label ->
                    let labelText = sprintf " %s " label
                    let topWithLabel = "┌" + labelText + String.replicate (ta.Width - 2 - labelText.Length) "─" + "┐"
                    [topWithLabel]
                | None -> [borderTop]

            labelLine @ contentLines @ [borderBottom]

        /// Calculate visible cursor position
        let getCursorPosition (ta: TextArea) : int * int =
            let row = ta.CursorRow - ta.ScrollOffset + 1  // +1 for border
            let col = ta.CursorCol + 1  // +1 for border
            (row, col)

    // ═══════════════════════════════════════════════════════════════════════════
    // SPLIT VIEW (tview-inspired panel splitter)
    // STAMP: SC-HMI-014 (multi-panel layouts)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Split direction
    type SplitDirection =
        | Horizontal  // panels side by side
        | Vertical    // panels stacked

    /// Split pane configuration
    type SplitPane = {
        Id: string
        Content: string list
        Size: float  // 0.0 to 1.0 proportion
        MinSize: int
        Resizable: bool
    }

    /// Split view configuration
    type SplitView = {
        Direction: SplitDirection
        Panes: SplitPane list
        SplitterChar: char
        ShowBorder: bool
        FocusedPane: string option
    }

    module SplitView =
        /// Create a split pane
        let createPane id content size =
            { Id = id
              Content = content
              Size = size
              MinSize = 3
              Resizable = true }

        /// Create a split view
        let create direction panes =
            { Direction = direction
              Panes = panes
              SplitterChar = '│'
              ShowBorder = true
              FocusedPane = None }

        /// Render horizontal split (side by side)
        let private renderHorizontal (sv: SplitView) (totalWidth: int) (totalHeight: int) : string list =
            let paneCount = sv.Panes.Length
            if paneCount = 0 then List.replicate totalHeight ""
            else
                // Calculate widths based on proportions
                let splitterWidth = if sv.ShowBorder then 1 else 0
                let availableWidth = totalWidth - (splitterWidth * (paneCount - 1))
                let widths =
                    sv.Panes
                    |> List.map (fun p -> max p.MinSize (int (float availableWidth * p.Size)))

                // Render each pane's content
                let renderedPanes =
                    List.zip sv.Panes widths
                    |> List.map (fun (pane, width) ->
                        pane.Content
                        |> List.truncate totalHeight
                        |> List.map (fun line ->
                            let truncated = if line.Length > width then line.Substring(0, width) else line
                            truncated.PadRight(width))
                        |> (fun lines ->
                            let padding = totalHeight - lines.Length
                            if padding > 0 then lines @ List.replicate padding (String.replicate width " ")
                            else lines))

                // Combine panes row by row
                [0 .. totalHeight - 1]
                |> List.map (fun row ->
                    renderedPanes
                    |> List.mapi (fun i pane ->
                        let content = List.item row pane
                        if i < paneCount - 1 && sv.ShowBorder then
                            content + string sv.SplitterChar
                        else content)
                    |> String.concat "")

        /// Render vertical split (stacked)
        let private renderVertical (sv: SplitView) (totalWidth: int) (totalHeight: int) : string list =
            let paneCount = sv.Panes.Length
            if paneCount = 0 then List.replicate totalHeight ""
            else
                // Calculate heights based on proportions
                let splitterHeight = if sv.ShowBorder then 1 else 0
                let availableHeight = totalHeight - (splitterHeight * (paneCount - 1))
                let heights =
                    sv.Panes
                    |> List.map (fun p -> max p.MinSize (int (float availableHeight * p.Size)))

                // Render each pane
                sv.Panes
                |> List.zip heights
                |> List.mapi (fun i (height, pane) ->
                    let content =
                        pane.Content
                        |> List.truncate height
                        |> List.map (fun line ->
                            if line.Length > totalWidth then line.Substring(0, totalWidth)
                            else line.PadRight(totalWidth))
                    let padded =
                        let padding = height - content.Length
                        if padding > 0 then content @ List.replicate padding (String.replicate totalWidth " ")
                        else content
                    if i < paneCount - 1 && sv.ShowBorder then
                        padded @ [String.replicate totalWidth "─"]
                    else padded)
                |> List.collect id

        /// Render split view
        let renderSplitView (sv: SplitView) (width: int) (height: int) : string list =
            match sv.Direction with
            | Horizontal -> renderHorizontal sv width height
            | Vertical -> renderVertical sv width height

    // ═══════════════════════════════════════════════════════════════════════════
    // APPLICATION FRAME (tview-inspired app wrapper)
    // STAMP: SC-HMI-015 (application structure)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Application frame configuration
    type ApplicationFrame = {
        Title: string
        Subtitle: string option
        Width: int
        Height: int
        ShowHeader: bool
        ShowFooter: bool
        ShowBorder: bool
        HeaderContent: string option
        FooterContent: string option
        MainContent: string list
        StatusBar: string option
    }

    module ApplicationFrame =
        /// Create application frame
        let create title width height =
            { Title = title
              Subtitle = None
              Width = width
              Height = height
              ShowHeader = true
              ShowFooter = true
              ShowBorder = true
              HeaderContent = None
              FooterContent = None
              MainContent = []
              StatusBar = None }

        /// Render application frame
        let renderFrame (frame: ApplicationFrame) : string list =
            let w = frame.Width

            // Header
            let header =
                if frame.ShowHeader then
                    let titleText =
                        match frame.Subtitle with
                        | Some sub -> sprintf " %s - %s " frame.Title sub
                        | None -> sprintf " %s " frame.Title
                    let headerLine =
                        if frame.ShowBorder then
                            let padding = w - 2 - titleText.Length
                            "╔" + String.replicate (padding / 2) "═" + titleText + String.replicate (padding - padding / 2) "═" + "╗"
                        else titleText.PadRight(w)

                    match frame.HeaderContent with
                    | Some content ->
                        let contentLine =
                            if frame.ShowBorder then "║" + content.PadRight(w - 2).Substring(0, w - 2) + "║"
                            else content.PadRight(w)
                        let separator =
                            if frame.ShowBorder then "╠" + String.replicate (w - 2) "═" + "╣"
                            else String.replicate w "─"
                        [headerLine; contentLine; separator]
                    | None -> [headerLine]
                else []

            // Footer
            let footer =
                if frame.ShowFooter then
                    let separator =
                        if frame.ShowBorder then "╠" + String.replicate (w - 2) "═" + "╣"
                        else String.replicate w "─"

                    let statusLine =
                        match frame.StatusBar with
                        | Some status ->
                            if frame.ShowBorder then "║" + status.PadRight(w - 2).Substring(0, min (w - 2) status.Length).PadRight(w - 2) + "║"
                            else status.PadRight(w)
                        | None ->
                            if frame.ShowBorder then "║" + String.replicate (w - 2) " " + "║"
                            else String.replicate w " "

                    let bottomBorder =
                        if frame.ShowBorder then "╚" + String.replicate (w - 2) "═" + "╝"
                        else ""

                    match frame.FooterContent with
                    | Some content ->
                        let contentLine =
                            if frame.ShowBorder then "║" + content.PadRight(w - 2).Substring(0, w - 2) + "║"
                            else content.PadRight(w)
                        [separator; contentLine; statusLine; bottomBorder]
                    | None ->
                        if frame.ShowBorder then [separator; statusLine; bottomBorder]
                        else [statusLine]
                else if frame.ShowBorder then ["╚" + String.replicate (w - 2) "═" + "╝"]
                else []

            // Main content
            let headerHeight = header.Length
            let footerHeight = footer.Length
            let contentHeight = frame.Height - headerHeight - footerHeight

            let mainContent =
                frame.MainContent
                |> List.truncate contentHeight
                |> List.map (fun line ->
                    let truncated = if line.Length > w - 2 then line.Substring(0, w - 2) else line
                    if frame.ShowBorder then "║" + truncated.PadRight(w - 2) + "║"
                    else truncated.PadRight(w))
                |> (fun lines ->
                    let padding = contentHeight - lines.Length
                    if padding > 0 then
                        let emptyLine = if frame.ShowBorder then "║" + String.replicate (w - 2) " " + "║" else String.replicate w " "
                        lines @ List.replicate padding emptyLine
                    else lines)

            header @ mainContent @ footer

    // ═══════════════════════════════════════════════════════════════════════════
    // LXZ-INSPIRED DEVOPS COMPONENTS
    // Based on: https://github.com/liangzhaoliang95/lxz
    // Unified DevOps CLI tool for database, container, and infrastructure management
    // STAMP: SC-HMI-016 to SC-HMI-024
    // ═══════════════════════════════════════════════════════════════════════════

    /// Text alignment for columns
    type ColumnAlignment = LeftAlign | RightAlign | CenterAlign

    // ═══════════════════════════════════════════════════════════════════════════
    // DATA BROWSER (lxz-inspired database/redis browser)
    // STAMP: SC-HMI-016 (data exploration interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Column definition for data browser
    type DataColumn = {
        Name: string
        Width: int
        Alignment: ColumnAlignment
        Sortable: bool
        Visible: bool
    }

    /// Data browser configuration
    type DataBrowser = {
        Title: string
        Columns: DataColumn list
        Rows: Map<string, string> list
        SelectedRow: int
        SelectedColumn: int
        ScrollOffset: int
        Width: int
        Height: int
        ShowHeader: bool
        ShowFooter: bool
        ShowRowNumbers: bool
        HighlightRow: bool
        FilterText: string option
        SortColumn: string option
        SortAscending: bool
    }

    module DataBrowser =
        /// Create data browser
        let create title columns width height =
            { Title = title
              Columns = columns
              Rows = []
              SelectedRow = 0
              SelectedColumn = 0
              ScrollOffset = 0
              Width = width
              Height = height
              ShowHeader = true
              ShowFooter = true
              ShowRowNumbers = true
              HighlightRow = true
              FilterText = None
              SortColumn = None
              SortAscending = true }

        /// Add column
        let addColumn name width alignment (browser: DataBrowser) : DataBrowser =
            let col = { Name = name; Width = width; Alignment = alignment; Sortable = true; Visible = true }
            { browser with Columns = browser.Columns @ [col] }

        /// Set rows
        let setRows rows browser = { browser with Rows = rows }

        /// Render header row
        let private renderHeaderRow (browser: DataBrowser) : string =
            let rowNumCol = if browser.ShowRowNumbers then "│ # │" else "│"
            let cols =
                browser.Columns
                |> List.filter (fun c -> c.Visible)
                |> List.map (fun col ->
                    let sortIndicator =
                        match browser.SortColumn with
                        | Some sc when sc = col.Name -> if browser.SortAscending then "↑" else "↓"
                        | _ -> " "
                    let name = col.Name + sortIndicator
                    let padded =
                        match col.Alignment with
                        | LeftAlign -> name.PadRight(col.Width)
                        | RightAlign -> name.PadLeft(col.Width)
                        | CenterAlign ->
                            let pad = col.Width - name.Length
                            String.replicate (pad / 2) " " + name + String.replicate (pad - pad / 2) " "
                    padded.Substring(0, min col.Width padded.Length))
                |> String.concat " │ "
            rowNumCol + cols + " │"

        /// Render data row
        let private renderDataRow (browser: DataBrowser) (rowNum: int) (row: Map<string, string>) (isSelected: bool) : string =
            let rowNumCol = if browser.ShowRowNumbers then sprintf "│%3d│" (rowNum + 1) else "│"
            let cols =
                browser.Columns
                |> List.filter (fun c -> c.Visible)
                |> List.mapi (fun colIdx col ->
                    let value = row |> Map.tryFind col.Name |> Option.defaultValue ""
                    let isCellSelected = isSelected && colIdx = browser.SelectedColumn
                    let padded =
                        match col.Alignment with
                        | LeftAlign -> value.PadRight(col.Width)
                        | RightAlign -> value.PadLeft(col.Width)
                        | CenterAlign ->
                            let pad = col.Width - value.Length
                            String.replicate (pad / 2) " " + value + String.replicate (pad - pad / 2) " "
                    let truncated = padded.Substring(0, min col.Width padded.Length)
                    if isCellSelected then sprintf "\x1b[7m%s\x1b[0m" truncated else truncated)
                |> String.concat " │ "
            let line = rowNumCol + cols + " │"
            if isSelected && browser.HighlightRow then sprintf "\x1b[44m%s\x1b[0m" line else line

        /// Render data browser
        let renderDataBrowser (browser: DataBrowser) : string list =
            let w = browser.Width
            let border = "┌" + String.replicate (w - 2) "─" + "┐"
            let titleLine = "│ " + browser.Title.PadRight(w - 4) + " │"
            let separator = "├" + String.replicate (w - 2) "─" + "┤"
            let bottomBorder = "└" + String.replicate (w - 2) "─" + "┘"

            let header = if browser.ShowHeader then [border; titleLine; separator; renderHeaderRow browser; separator] else [border]

            let visibleRows = browser.Height - header.Length - 2
            let rows =
                browser.Rows
                |> List.skip browser.ScrollOffset
                |> List.truncate visibleRows
                |> List.mapi (fun i row -> renderDataRow browser (browser.ScrollOffset + i) row (browser.ScrollOffset + i = browser.SelectedRow))

            let padding = visibleRows - rows.Length
            let emptyRows = List.replicate padding ("│" + String.replicate (w - 2) " " + "│")

            let footer =
                if browser.ShowFooter then
                    let info = sprintf " Rows: %d | Selected: %d " browser.Rows.Length (browser.SelectedRow + 1)
                    let filterInfo = browser.FilterText |> Option.map (sprintf " Filter: %s") |> Option.defaultValue ""
                    [separator; "│" + (info + filterInfo).PadRight(w - 2).Substring(0, w - 2) + "│"; bottomBorder]
                else [bottomBorder]

            header @ rows @ emptyRows @ footer

    // ═══════════════════════════════════════════════════════════════════════════
    // QUERY PANEL (lxz-inspired SQL/command execution)
    // STAMP: SC-HMI-017 (query interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Query execution status
    type QueryStatus =
        | Idle
        | Executing
        | Completed of duration: float
        | Failed of error: string

    /// Query panel configuration
    type QueryPanel = {
        Title: string
        Query: string
        History: string list
        HistoryIndex: int
        Status: QueryStatus
        Width: int
        Height: int
        CursorPosition: int
        ShowHistory: bool
        MaxHistorySize: int
    }

    module QueryPanel =
        /// Create query panel
        let create title width height =
            { Title = title
              Query = ""
              History = []
              HistoryIndex = -1
              Status = Idle
              Width = width
              Height = height
              CursorPosition = 0
              ShowHistory = false
              MaxHistorySize = 100 }

        /// Set query
        let setQuery query panel = { panel with Query = query; CursorPosition = query.Length }

        /// Add to history
        let addToHistory query panel =
            let newHistory = query :: (panel.History |> List.filter (fun h -> h <> query) |> List.truncate (panel.MaxHistorySize - 1))
            { panel with History = newHistory; HistoryIndex = -1 }

        /// Render query panel
        let renderQueryPanel (panel: QueryPanel) : string list =
            let w = panel.Width
            let border = "┌" + String.replicate (w - 2) "─" + "┐"
            let titleLine = "│ " + panel.Title.PadRight(w - 4) + " │"
            let separator = "├" + String.replicate (w - 2) "─" + "┤"
            let bottomBorder = "└" + String.replicate (w - 2) "─" + "┘"

            // Query input area
            let queryLines =
                let lines = panel.Query.Split('\n') |> Array.toList
                lines |> List.map (fun line ->
                    let truncated = if line.Length > w - 4 then line.Substring(0, w - 4) else line
                    "│ " + truncated.PadRight(w - 4) + " │")

            // Status line
            let statusText =
                match panel.Status with
                | Idle -> "Ready"
                | Executing -> "Executing..."
                | Completed d -> sprintf "Completed in %.2fms" d
                | Failed e -> sprintf "Error: %s" e
            let statusColor =
                match panel.Status with
                | Idle -> "\x1b[90m"
                | Executing -> "\x1b[33m"
                | Completed _ -> "\x1b[32m"
                | Failed _ -> "\x1b[31m"
            let statusLine = sprintf "│ %s%s\x1b[0m%s │" statusColor statusText (String.replicate (w - 4 - statusText.Length) " ")

            // History dropdown
            let historyLines =
                if panel.ShowHistory && panel.History.Length > 0 then
                    let visibleHistory = panel.History |> List.truncate 5
                    separator :: (visibleHistory |> List.mapi (fun i h ->
                        let prefix = if i = panel.HistoryIndex then "→ " else "  "
                        let truncated = if h.Length > w - 6 then h.Substring(0, w - 9) + "..." else h
                        "│" + prefix + truncated.PadRight(w - 4) + "│"))
                else []

            [border; titleLine; separator] @ queryLines @ [separator; statusLine] @ historyLines @ [bottomBorder]

    // ═══════════════════════════════════════════════════════════════════════════
    // LOG VIEWER (lxz-inspired container log viewer)
    // STAMP: SC-HMI-018 (log display interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Log level
    type LogLevel =
        | Trace
        | Debug
        | Info
        | Warning
        | Error
        | Fatal

    /// Log entry
    type LogEntry = {
        Timestamp: System.DateTime
        Level: LogLevel
        Source: string
        Message: string
        Metadata: Map<string, string>
    }

    /// Log viewer configuration
    type LogViewer = {
        Title: string
        Entries: LogEntry list
        Width: int
        Height: int
        ScrollOffset: int
        FilterLevel: LogLevel option
        FilterText: string option
        ShowTimestamp: bool
        ShowSource: bool
        ShowLevel: bool
        AutoScroll: bool
        WrapLines: bool
        HighlightPatterns: (string * string) list  // pattern -> color
    }

    module LogViewer =
        /// Create log viewer
        let create title width height =
            { Title = title
              Entries = []
              Width = width
              Height = height
              ScrollOffset = 0
              FilterLevel = None
              FilterText = None
              ShowTimestamp = true
              ShowSource = true
              ShowLevel = true
              AutoScroll = true
              WrapLines = false
              HighlightPatterns = [("ERROR", "\x1b[31m"); ("WARN", "\x1b[33m"); ("INFO", "\x1b[32m")] }

        /// Add log entry
        let addEntry entry viewer =
            let newEntries = viewer.Entries @ [entry]
            let newOffset = if viewer.AutoScroll then max 0 (newEntries.Length - viewer.Height + 4) else viewer.ScrollOffset
            { viewer with Entries = newEntries; ScrollOffset = newOffset }

        /// Get log level color
        let private levelColor level =
            match level with
            | Trace -> "\x1b[90m"
            | Debug -> "\x1b[36m"
            | Info -> "\x1b[32m"
            | Warning -> "\x1b[33m"
            | Error -> "\x1b[31m"
            | Fatal -> "\x1b[35;1m"

        /// Get log level name
        let private levelName level =
            match level with
            | Trace -> "TRC"
            | Debug -> "DBG"
            | Info -> "INF"
            | Warning -> "WRN"
            | Error -> "ERR"
            | Fatal -> "FTL"

        /// Render log entry
        let private renderEntry (viewer: LogViewer) (entry: LogEntry) : string =
            let parts = []
            let parts = if viewer.ShowTimestamp then parts @ [entry.Timestamp.ToString("HH:mm:ss.fff")] else parts
            let parts = if viewer.ShowLevel then parts @ [sprintf "%s%s\x1b[0m" (levelColor entry.Level) (levelName entry.Level)] else parts
            let parts = if viewer.ShowSource then parts @ [sprintf "[%s]" entry.Source] else parts
            let parts = parts @ [entry.Message]
            String.concat " " parts

        /// Filter entries
        let private filterEntries viewer =
            viewer.Entries
            |> List.filter (fun e ->
                let levelMatch =
                    match viewer.FilterLevel with
                    | Some l -> e.Level >= l
                    | None -> true
                let textMatch =
                    match viewer.FilterText with
                    | Some t -> e.Message.ToLower().Contains(t.ToLower()) || e.Source.ToLower().Contains(t.ToLower())
                    | None -> true
                levelMatch && textMatch)

        /// Render log viewer
        let renderLogViewer (viewer: LogViewer) : string list =
            let w = viewer.Width
            let border = "┌" + String.replicate (w - 2) "─" + "┐"
            let titleLine = "│ " + viewer.Title.PadRight(w - 4) + " │"
            let separator = "├" + String.replicate (w - 2) "─" + "┤"
            let bottomBorder = "└" + String.replicate (w - 2) "─" + "┘"

            let filtered = filterEntries viewer
            let visibleHeight = viewer.Height - 4
            let visibleEntries =
                filtered
                |> List.skip viewer.ScrollOffset
                |> List.truncate visibleHeight

            let logLines =
                visibleEntries
                |> List.map (fun entry ->
                    let line = renderEntry viewer entry
                    let truncated = if line.Length > w - 4 then line.Substring(0, w - 4) else line
                    "│ " + truncated.PadRight(w - 4) + " │")

            let padding = visibleHeight - logLines.Length
            let emptyLines = List.replicate padding ("│" + String.replicate (w - 2) " " + "│")

            let statusLine =
                let total = filtered.Length
                let showing = visibleEntries.Length
                let filterInfo =
                    match viewer.FilterText with
                    | Some t -> sprintf " | Filter: %s" t
                    | None -> ""
                sprintf "│ Showing %d-%d of %d%s%s │" (viewer.ScrollOffset + 1) (viewer.ScrollOffset + showing) total filterInfo (String.replicate (w - 30 - filterInfo.Length) " ")

            [border; titleLine; separator] @ logLines @ emptyLines @ [separator; statusLine; bottomBorder]

    // ═══════════════════════════════════════════════════════════════════════════
    // FILE BROWSER (lxz-inspired file system navigation)
    // STAMP: SC-HMI-019 (file navigation interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Browser file type (extended version for lxz-style file browser)
    type BrowserFileType =
        | BrowserDirectory
        | BrowserRegularFile
        | BrowserSymLink
        | BrowserExecutable
        | BrowserArchive
        | BrowserImage
        | BrowserDocument
        | BrowserCode
        | BrowserUnknown

    /// Browser file entry
    type BrowserFileEntry = {
        Name: string
        Path: string
        EntryType: BrowserFileType
        Size: int64
        Modified: System.DateTime
        Permissions: string
        IsHidden: bool
        IsSelected: bool
    }

    /// File browser configuration
    type FileBrowser = {
        Title: string
        CurrentPath: string
        Entries: BrowserFileEntry list
        SelectedIndex: int
        ScrollOffset: int
        Width: int
        Height: int
        ShowHidden: bool
        ShowDetails: bool
        ShowPreview: bool
        PreviewContent: string list
        SortBy: string
        SortAscending: bool
        MultiSelect: bool
        SelectedFiles: Set<string>
    }

    module FileBrowser =
        /// Create file browser
        let create title path width height =
            { Title = title
              CurrentPath = path
              Entries = []
              SelectedIndex = 0
              ScrollOffset = 0
              Width = width
              Height = height
              ShowHidden = false
              ShowDetails = true
              ShowPreview = false
              PreviewContent = []
              SortBy = "name"
              SortAscending = true
              MultiSelect = false
              SelectedFiles = Set.empty }

        /// Get file type icon
        let private fileTypeIcon ft =
            match ft with
            | BrowserDirectory -> "📁"
            | BrowserRegularFile -> "📄"
            | BrowserSymLink -> "🔗"
            | BrowserExecutable -> "⚙️"
            | BrowserArchive -> "📦"
            | BrowserImage -> "🖼️"
            | BrowserDocument -> "📝"
            | BrowserCode -> "💻"
            | BrowserUnknown -> "❓"

        /// Format file size
        let private formatSize (size: int64) : string =
            if size < 1024L then sprintf "%dB" size
            elif size < 1024L * 1024L then sprintf "%.1fK" (float size / 1024.0)
            elif size < 1024L * 1024L * 1024L then sprintf "%.1fM" (float size / 1024.0 / 1024.0)
            else sprintf "%.1fG" (float size / 1024.0 / 1024.0 / 1024.0)

        /// Render file entry
        let private renderEntry (browser: FileBrowser) (index: int) (entry: BrowserFileEntry) : string =
            let isSelected = index = browser.SelectedIndex
            let isChecked = browser.SelectedFiles.Contains(entry.Path)
            let checkMark = if browser.MultiSelect then (if isChecked then "[✓] " else "[ ] ") else ""
            let icon = fileTypeIcon entry.EntryType
            let name = entry.Name
            let details =
                if browser.ShowDetails then
                    sprintf " %8s  %s" (formatSize entry.Size) (entry.Modified.ToString("yyyy-MM-dd"))
                else ""
            let line = sprintf "%s%s %s%s" checkMark icon name details
            if isSelected then sprintf "\x1b[44;37m%s\x1b[0m" line else line

        /// Render file browser
        let renderFileBrowser (browser: FileBrowser) : string list =
            let w = browser.Width
            let mainWidth = if browser.ShowPreview then w / 2 else w
            let border = "┌" + String.replicate (w - 2) "─" + "┐"
            let pathLine = "│ " + browser.CurrentPath.PadRight(w - 4).Substring(0, w - 4) + " │"
            let separator = "├" + String.replicate (w - 2) "─" + "┤"
            let bottomBorder = "└" + String.replicate (w - 2) "─" + "┘"

            let visibleEntries =
                browser.Entries
                |> List.filter (fun e -> browser.ShowHidden || not e.IsHidden)
                |> List.skip browser.ScrollOffset
                |> List.truncate (browser.Height - 5)

            let fileLines =
                visibleEntries
                |> List.mapi (fun i entry ->
                    let line = renderEntry browser (browser.ScrollOffset + i) entry
                    let truncated = if line.Length > mainWidth - 4 then line.Substring(0, mainWidth - 4) else line
                    if browser.ShowPreview then
                        let previewLine =
                            if i < browser.PreviewContent.Length then
                                browser.PreviewContent.[i].Substring(0, min (w - mainWidth - 3) browser.PreviewContent.[i].Length)
                            else ""
                        "│ " + truncated.PadRight(mainWidth - 4) + " │" + previewLine.PadRight(w - mainWidth - 3) + "│"
                    else
                        "│ " + truncated.PadRight(w - 4) + " │")

            let padding = browser.Height - 5 - fileLines.Length
            let emptyLines = List.replicate padding ("│" + String.replicate (w - 2) " " + "│")

            let statusLine =
                let total = browser.Entries.Length
                let selected = browser.SelectedFiles.Count
                sprintf "│ %d items%s%s │" total (if selected > 0 then sprintf " | %d selected" selected else "") (String.replicate (w - 20) " ")

            [border; pathLine; separator] @ fileLines @ emptyLines @ [separator; statusLine; bottomBorder]

    // ═══════════════════════════════════════════════════════════════════════════
    // CONNECTION MANAGER (lxz-inspired SSH/database connection management)
    // STAMP: SC-HMI-020 (connection interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Connection type
    type ConnectionType =
        | SSH
        | MySQL
        | PostgreSQL
        | Redis
        | MongoDB
        | HTTP
        | Custom of string

    /// Connection status
    type ConnectionStatus =
        | Disconnected
        | Connecting
        | Connected
        | Error of string

    /// Connection entry
    type ConnectionEntry = {
        Id: string
        Name: string
        Type: ConnectionType
        Host: string
        Port: int
        Username: string option
        Status: ConnectionStatus
        LastConnected: System.DateTime option
        Favorite: bool
        Tags: string list
    }

    /// Connection manager configuration
    type ConnectionManager = {
        Title: string
        Connections: ConnectionEntry list
        SelectedIndex: int
        Width: int
        Height: int
        FilterType: ConnectionType option
        FilterText: string option
        ShowDetails: bool
        GroupByType: bool
    }

    module ConnectionManager =
        /// Create connection manager
        let create title width height =
            { Title = title
              Connections = []
              SelectedIndex = 0
              Width = width
              Height = height
              FilterType = None
              FilterText = None
              ShowDetails = true
              GroupByType = false }

        /// Get connection type icon
        let private typeIcon ct =
            match ct with
            | SSH -> "🔐"
            | MySQL -> "🐬"
            | PostgreSQL -> "🐘"
            | Redis -> "📕"
            | MongoDB -> "🍃"
            | HTTP -> "🌐"
            | Custom _ -> "🔌"

        /// Get status indicator
        let private statusIndicator status =
            match status with
            | Disconnected -> "○"
            | Connecting -> "◐"
            | Connected -> "●"
            | Error _ -> "✗"

        /// Get status color
        let private statusColor status =
            match status with
            | Disconnected -> "\x1b[90m"
            | Connecting -> "\x1b[33m"
            | Connected -> "\x1b[32m"
            | Error _ -> "\x1b[31m"

        /// Render connection entry
        let private renderEntry (cm: ConnectionManager) (index: int) (conn: ConnectionEntry) : string =
            let isSelected = index = cm.SelectedIndex
            let icon = typeIcon conn.Type
            let status = sprintf "%s%s\x1b[0m" (statusColor conn.Status) (statusIndicator conn.Status)
            let fav = if conn.Favorite then "★ " else "  "
            let details =
                if cm.ShowDetails then
                    sprintf " (%s:%d)" conn.Host conn.Port
                else ""
            let line = sprintf "%s%s %s %s%s" fav status icon conn.Name details
            if isSelected then sprintf "\x1b[44;37m%s\x1b[0m" line else line

        /// Render connection manager
        let renderConnectionManager (cm: ConnectionManager) : string list =
            let w = cm.Width
            let border = "┌" + String.replicate (w - 2) "─" + "┐"
            let titleLine = "│ " + cm.Title.PadRight(w - 4) + " │"
            let separator = "├" + String.replicate (w - 2) "─" + "┤"
            let bottomBorder = "└" + String.replicate (w - 2) "─" + "┘"

            let filtered =
                cm.Connections
                |> List.filter (fun c ->
                    let typeMatch = cm.FilterType |> Option.map (fun t -> c.Type = t) |> Option.defaultValue true
                    let textMatch = cm.FilterText |> Option.map (fun t -> c.Name.ToLower().Contains(t.ToLower())) |> Option.defaultValue true
                    typeMatch && textMatch)

            let connLines =
                filtered
                |> List.mapi (fun i conn ->
                    let line = renderEntry cm i conn
                    "│ " + line.PadRight(w - 4).Substring(0, w - 4) + " │")

            let padding = cm.Height - 4 - connLines.Length
            let emptyLines = List.replicate (max 0 padding) ("│" + String.replicate (w - 2) " " + "│")

            [border; titleLine; separator] @ connLines @ emptyLines @ [bottomBorder]

    // ═══════════════════════════════════════════════════════════════════════════
    // ACTION PANEL (lxz-inspired keyboard shortcuts display)
    // STAMP: SC-HMI-021 (action interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Action category
    type ActionCategory =
        | Navigation
        | Editing
        | View
        | System
        | Custom of string

    /// Action definition
    type ActionDef = {
        Key: string
        Description: string
        Category: ActionCategory
        Enabled: bool
        Highlighted: bool
    }

    /// Action panel configuration
    type ActionPanel = {
        Title: string
        Actions: ActionDef list
        Width: int
        Columns: int
        ShowCategories: bool
        Compact: bool
    }

    module ActionPanel =
        /// Create action panel
        let create title width =
            { Title = title
              Actions = []
              Width = width
              Columns = 3
              ShowCategories = true
              Compact = false }

        /// Add action
        let addAction key description category (panel: ActionPanel) : ActionPanel =
            let action = { Key = key; Description = description; Category = category; Enabled = true; Highlighted = false }
            { panel with Actions = panel.Actions @ [action] }

        /// Render action panel
        let renderActionPanel (panel: ActionPanel) : string list =
            let w = panel.Width
            let colWidth = w / panel.Columns

            let groupedActions =
                if panel.ShowCategories then
                    panel.Actions
                    |> List.groupBy (fun a -> a.Category)
                    |> List.sortBy (fun (cat, _) ->
                        match cat with
                        | Navigation -> 0
                        | Editing -> 1
                        | View -> 2
                        | System -> 3
                        | Custom _ -> 4)
                else
                    [(Custom "", panel.Actions)]

            let categoryName cat =
                match cat with
                | Navigation -> "Navigation"
                | Editing -> "Editing"
                | View -> "View"
                | System -> "System"
                | Custom s -> s

            let lines = []
            let lines =
                groupedActions
                |> List.collect (fun (cat, actions) ->
                    let header = if panel.ShowCategories then [sprintf "─── %s ───" (categoryName cat)] else []
                    let actionRows =
                        actions
                        |> List.chunkBySize panel.Columns
                        |> List.map (fun chunk ->
                            chunk
                            |> List.map (fun a ->
                                let keyStyle = if a.Enabled then "\x1b[1;36m" else "\x1b[90m"
                                let display = sprintf "%s%s\x1b[0m %s" keyStyle a.Key a.Description
                                if display.Length > colWidth - 1 then display.Substring(0, colWidth - 1) else display.PadRight(colWidth - 1))
                            |> String.concat " ")
                    header @ actionRows)

            let border = String.replicate w "─"
            [border; sprintf " %s " panel.Title] @ lines @ [border]

    // ═══════════════════════════════════════════════════════════════════════════
    // FLASH MESSAGE (lxz-inspired toast notification)
    // STAMP: SC-HMI-022 (notification interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Flash message type
    type FlashType =
        | Success
        | Info
        | Warning
        | Error

    /// Flash message
    type FlashMessage = {
        Id: string
        Type: FlashType
        Title: string
        Message: string
        Duration: int  // milliseconds, 0 = persistent
        Dismissible: bool
        CreatedAt: System.DateTime
        Action: (string * string) option  // (label, action)
    }

    /// Flash container configuration
    type FlashContainer = {
        Messages: FlashMessage list
        Width: int
        MaxVisible: int
        Position: string  // "top-right", "bottom-right", etc.
    }

    module FlashMessage =
        /// Create flash message
        let create msgType title message =
            { Id = System.Guid.NewGuid().ToString()
              Type = msgType
              Title = title
              Message = message
              Duration = 5000
              Dismissible = true
              CreatedAt = System.DateTime.Now
              Action = None }

        /// Get type icon
        let private typeIcon ft =
            match ft with
            | Success -> "✓"
            | Info -> "ℹ"
            | Warning -> "⚠"
            | Error -> "✗"

        /// Get type color
        let private typeColor ft =
            match ft with
            | Success -> "\x1b[32m"
            | Info -> "\x1b[36m"
            | Warning -> "\x1b[33m"
            | Error -> "\x1b[31m"

        /// Render flash message
        let renderFlash (width: int) (flash: FlashMessage) : string list =
            let w = width
            let icon = typeIcon flash.Type
            let color = typeColor flash.Type
            let border = "┌" + String.replicate (w - 2) "─" + "┐"
            let titleLine = sprintf "│ %s%s %s\x1b[0m%s │" color icon flash.Title (String.replicate (w - 6 - flash.Title.Length) " ")
            let msgLine = "│ " + flash.Message.PadRight(w - 4).Substring(0, w - 4) + " │"
            let bottomBorder = "└" + String.replicate (w - 2) "─" + "┘"
            [border; titleLine; msgLine; bottomBorder]

        /// Render flash container
        let renderFlashContainer (container: FlashContainer) : string list =
            container.Messages
            |> List.truncate container.MaxVisible
            |> List.collect (renderFlash container.Width)

    // ═══════════════════════════════════════════════════════════════════════════
    // SPLASH SCREEN (lxz-inspired startup splash)
    // STAMP: SC-HMI-023 (splash interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Splash screen configuration
    type SplashScreen = {
        Logo: string list
        Title: string
        Subtitle: string option
        Version: string
        Width: int
        Height: int
        ShowProgress: bool
        Progress: float
        ProgressMessage: string
        LoadingSteps: (string * bool) list  // (step name, completed)
    }

    module SplashScreen =
        /// Create splash screen
        let create title version width height =
            { Logo = []
              Title = title
              Subtitle = None
              Version = version
              Width = width
              Height = height
              ShowProgress = true
              Progress = 0.0
              ProgressMessage = "Initializing..."
              LoadingSteps = [] }

        /// Set logo
        let setLogo logo splash = { splash with Logo = logo }

        /// Update progress
        let updateProgress progress message splash =
            { splash with Progress = progress; ProgressMessage = message }

        /// Add loading step
        let addStep step completed splash =
            let steps = splash.LoadingSteps @ [(step, completed)]
            { splash with LoadingSteps = steps }

        /// Render progress bar
        let private renderProgressBar (width: int) (progress: float) : string =
            let filled = int (float (width - 2) * progress)
            let empty = width - 2 - filled
            "[" + String.replicate filled "█" + String.replicate empty "░" + "]"

        /// Render splash screen
        let renderSplashScreen (splash: SplashScreen) : string list =
            let w = splash.Width
            let centerLine (text: string) : string =
                let pad = (w - text.Length) / 2
                String.replicate pad " " + text

            let logo = splash.Logo |> List.map centerLine

            let title = centerLine splash.Title
            let subtitle = splash.Subtitle |> Option.map centerLine |> Option.toList
            let version = centerLine (sprintf "v%s" splash.Version)

            let progress =
                if splash.ShowProgress then
                    let bar = renderProgressBar (w / 2) splash.Progress
                    let msg = centerLine splash.ProgressMessage
                    [""; centerLine bar; msg]
                else []

            let steps =
                splash.LoadingSteps
                |> List.map (fun (step, completed) ->
                    let icon = if completed then "\x1b[32m✓\x1b[0m" else "\x1b[33m○\x1b[0m"
                    centerLine (sprintf "%s %s" icon step))

            let padding = splash.Height - logo.Length - 3 - subtitle.Length - progress.Length - steps.Length
            let topPad = List.replicate (padding / 3) ""
            let midPad = List.replicate (padding / 3) ""
            let bottomPad = List.replicate (padding - padding / 3 * 2) ""

            topPad @ logo @ [""] @ [title] @ subtitle @ [version] @ midPad @ progress @ steps @ bottomPad

    // ═══════════════════════════════════════════════════════════════════════════
    // STATUS BAR (lxz-inspired global status display)
    // STAMP: SC-HMI-024 (status interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Status item
    type StatusItem = {
        Key: string
        Value: string
        Color: string option
        Icon: string option
        Priority: int
    }

    /// Status bar configuration
    type StatusBar = {
        Items: StatusItem list
        Width: int
        Separator: string
        ShowTime: bool
        TimeFormat: string
        BackgroundColor: string option
    }

    module StatusBar =
        /// Create status bar
        let create width =
            { Items = []
              Width = width
              Separator = " │ "
              ShowTime = true
              TimeFormat = "HH:mm:ss"
              BackgroundColor = None }

        /// Add status item
        let addItem key value priority (bar: StatusBar) : StatusBar =
            let item = { Key = key; Value = value; Color = None; Icon = None; Priority = priority }
            { bar with Items = bar.Items @ [item] |> List.sortBy (fun i -> i.Priority) }

        /// Render status bar
        let renderStatusBar (bar: StatusBar) : string =
            let items =
                bar.Items
                |> List.map (fun item ->
                    let icon = item.Icon |> Option.map (fun i -> i + " ") |> Option.defaultValue ""
                    let color = item.Color |> Option.defaultValue ""
                    let reset = if item.Color.IsSome then "\x1b[0m" else ""
                    sprintf "%s%s%s: %s%s" color icon item.Key item.Value reset)

            let time =
                if bar.ShowTime then
                    [System.DateTime.Now.ToString(bar.TimeFormat)]
                else []

            let content = (items @ time) |> String.concat bar.Separator
            let bg = bar.BackgroundColor |> Option.defaultValue ""
            let reset = if bar.BackgroundColor.IsSome then "\x1b[0m" else ""
            sprintf "%s%s%s" bg (content.PadRight(bar.Width).Substring(0, bar.Width)) reset

    // ═══════════════════════════════════════════════════════════════════════════
    // COBRA-INSPIRED CLI COMPONENTS
    // Based on: https://github.com/spf13/cobra
    // Modern CLI framework with commands, flags, and auto-help
    // STAMP: SC-HMI-025 to SC-HMI-030
    // ═══════════════════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════════════════
    // CLI FLAG SYSTEM (Cobra-inspired flags)
    // STAMP: SC-HMI-025 (flag interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Flag value type
    type FlagValue =
        | BoolFlag of bool
        | StringFlag of string
        | IntFlag of int
        | FloatFlag of float
        | StringListFlag of string list

    /// CLI flag definition
    type CliFlag = {
        Name: string
        Shorthand: char option
        Description: string
        Value: FlagValue
        DefaultValue: FlagValue
        Required: bool
        Hidden: bool
        Persistent: bool  // Inherited by subcommands
        Deprecated: string option
    }

    module CliFlag =
        /// Create boolean flag
        let createBool name shorthand desc defaultVal =
            { Name = name
              Shorthand = shorthand
              Description = desc
              Value = BoolFlag defaultVal
              DefaultValue = BoolFlag defaultVal
              Required = false
              Hidden = false
              Persistent = false
              Deprecated = None }

        /// Create string flag
        let createString name shorthand desc defaultVal =
            { Name = name
              Shorthand = shorthand
              Description = desc
              Value = StringFlag defaultVal
              DefaultValue = StringFlag defaultVal
              Required = false
              Hidden = false
              Persistent = false
              Deprecated = None }

        /// Create int flag
        let createInt name shorthand desc defaultVal =
            { Name = name
              Shorthand = shorthand
              Description = desc
              Value = IntFlag defaultVal
              DefaultValue = IntFlag defaultVal
              Required = false
              Hidden = false
              Persistent = false
              Deprecated = None }

        /// Render flag usage
        let renderFlagUsage (flag: CliFlag) : string =
            let short = flag.Shorthand |> Option.map (sprintf "-%c, ") |> Option.defaultValue "    "
            let name = sprintf "--%s" flag.Name
            let typeHint =
                match flag.Value with
                | BoolFlag _ -> ""
                | StringFlag _ -> " string"
                | IntFlag _ -> " int"
                | FloatFlag _ -> " float"
                | StringListFlag _ -> " strings"
            let required = if flag.Required then " (required)" else ""
            let deprecated = flag.Deprecated |> Option.map (sprintf " [DEPRECATED: %s]") |> Option.defaultValue ""
            sprintf "%s%s%s%s%s" short name typeHint required deprecated

    // ═══════════════════════════════════════════════════════════════════════════
    // CLI COMMAND SYSTEM (Cobra-inspired commands)
    // STAMP: SC-HMI-026 (command interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Command execution context
    type CommandContext = {
        Args: string list
        Flags: Map<string, FlagValue>
        ParentCommand: string option
        WorkingDirectory: string
    }

    /// CLI command definition
    type CliCommand = {
        Name: string
        Aliases: string list
        Short: string
        Long: string option
        Example: string option
        Flags: CliFlag list
        PersistentFlags: CliFlag list
        SubCommands: CliCommand list
        Hidden: bool
        Deprecated: string option
        Version: string option
        ValidArgs: string list
        ArgValidator: (string list -> bool) option
        PreRun: (CommandContext -> unit) option
        Run: (CommandContext -> int) option
        PostRun: (CommandContext -> unit) option
    }

    module CliCommand =
        /// Create a new command
        let create name short =
            { Name = name
              Aliases = []
              Short = short
              Long = None
              Example = None
              Flags = []
              PersistentFlags = []
              SubCommands = []
              Hidden = false
              Deprecated = None
              Version = None
              ValidArgs = []
              ArgValidator = None
              PreRun = None
              Run = None
              PostRun = None }

        /// Add subcommand
        let addSubCommand sub (cmd: CliCommand) : CliCommand = { cmd with SubCommands = cmd.SubCommands @ [sub] }

        /// Add flag
        let addFlag flag (cmd: CliCommand) : CliCommand = { cmd with Flags = cmd.Flags @ [flag] }

        /// Add persistent flag
        let addPersistentFlag flag (cmd: CliCommand) : CliCommand = { cmd with PersistentFlags = cmd.PersistentFlags @ [flag] }

        /// Render usage line
        let renderUsage (cmd: CliCommand) : string =
            let flags = if cmd.Flags.Length > 0 then " [flags]" else ""
            let subs = if cmd.SubCommands.Length > 0 then " [command]" else ""
            sprintf "Usage: %s%s%s" cmd.Name flags subs

        /// Render help text
        let renderHelp (cmd: CliCommand) (width: int) : string list =
            let lines = []

            // Title
            let title = cmd.Long |> Option.defaultValue cmd.Short
            let lines = lines @ [title; ""]

            // Usage
            let lines = lines @ [renderUsage cmd; ""]

            // Aliases
            let lines =
                if cmd.Aliases.Length > 0 then
                    lines @ [sprintf "Aliases: %s" (String.concat ", " (cmd.Name :: cmd.Aliases)); ""]
                else lines

            // Example
            let lines =
                match cmd.Example with
                | Some ex -> lines @ ["Examples:"; sprintf "  %s" ex; ""]
                | None -> lines

            // Available Commands
            let lines =
                if cmd.SubCommands.Length > 0 then
                    let visible = cmd.SubCommands |> List.filter (fun c -> not c.Hidden)
                    let header = "Available Commands:"
                    let cmds = visible |> List.map (fun c ->
                        let name = c.Name.PadRight(15)
                        sprintf "  %s %s" name c.Short)
                    lines @ [header] @ cmds @ [""]
                else lines

            // Flags
            let lines =
                if cmd.Flags.Length > 0 then
                    let header = "Flags:"
                    let flags = cmd.Flags |> List.filter (fun f -> not f.Hidden) |> List.map (fun f ->
                        let usage = CliFlag.renderFlagUsage f
                        sprintf "  %-30s %s" usage f.Description)
                    lines @ [header] @ flags @ [""]
                else lines

            // Persistent Flags
            let lines =
                if cmd.PersistentFlags.Length > 0 then
                    let header = "Global Flags:"
                    let flags = cmd.PersistentFlags |> List.filter (fun f -> not f.Hidden) |> List.map (fun f ->
                        let usage = CliFlag.renderFlagUsage f
                        sprintf "  %-30s %s" usage f.Description)
                    lines @ [header] @ flags @ [""]
                else lines

            // Footer
            let footer =
                if cmd.SubCommands.Length > 0 then
                    sprintf "Use \"%s [command] --help\" for more information about a command." cmd.Name
                else ""
            let lines = if footer <> "" then lines @ [footer] else lines

            lines

    // ═══════════════════════════════════════════════════════════════════════════
    // CLI COMPLETION SYSTEM (Cobra-inspired)
    // STAMP: SC-HMI-027 (completion interface)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Completion item
    type CompletionItem = {
        Value: string
        Description: string option
        Icon: string option
    }

    /// Completion result
    type CompletionResult = {
        Items: CompletionItem list
        ShellDirective: string option
    }

    module Completion =
        /// Create completion item
        let createItem value desc =
            { Value = value; Description = desc; Icon = None }

        /// Generate completions for command
        let generateCompletions (cmd: CliCommand) (partial: string) : CompletionResult =
            let items =
                // Subcommand completions
                let subCmds =
                    cmd.SubCommands
                    |> List.filter (fun c -> not c.Hidden && c.Name.StartsWith(partial))
                    |> List.map (fun c -> { Value = c.Name; Description = Some c.Short; Icon = Some "📂" })

                // Flag completions
                let flags =
                    cmd.Flags @ cmd.PersistentFlags
                    |> List.filter (fun f -> not f.Hidden && f.Name.StartsWith(partial.TrimStart('-')))
                    |> List.map (fun f -> { Value = sprintf "--%s" f.Name; Description = Some f.Description; Icon = Some "🚩" })

                subCmds @ flags

            { Items = items; ShellDirective = None }

        /// Render completion suggestions
        let renderCompletions (result: CompletionResult) (width: int) : string list =
            result.Items
            |> List.map (fun item ->
                let icon = item.Icon |> Option.defaultValue " "
                let desc = item.Description |> Option.map (sprintf " - %s") |> Option.defaultValue ""
                sprintf "%s %s%s" icon item.Value desc)

    // ═══════════════════════════════════════════════════════════════════════════
    // TCELL-INSPIRED TERMINAL COMPONENTS
    // Based on: https://github.com/gdamore/tcell
    // Low-level terminal abstraction for rendering and events
    // STAMP: SC-HMI-028 to SC-HMI-033
    // ═══════════════════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════════════════
    // TERMINAL COLORS (tcell-inspired)
    // STAMP: SC-HMI-028 (color system)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Terminal color
    type TermColor =
        | ColorDefault
        | ColorBlack
        | ColorRed
        | ColorGreen
        | ColorYellow
        | ColorBlue
        | ColorMagenta
        | ColorCyan
        | ColorWhite
        | Color256 of int  // 0-255
        | ColorRGB of r: int * g: int * b: int  // True color

    /// Text attributes
    type TextAttribute =
        | AttrNone
        | AttrBold
        | AttrDim
        | AttrItalic
        | AttrUnderline
        | AttrBlink
        | AttrReverse
        | AttrStrikethrough

    /// Cell style
    type CellStyle = {
        Foreground: TermColor
        Background: TermColor
        Attributes: TextAttribute list
    }

    module CellStyle =
        /// Default style
        let defaultStyle =
            { Foreground = ColorDefault
              Background = ColorDefault
              Attributes = [] }

        /// Create style with foreground color
        let withForeground fg style = { style with Foreground = fg }

        /// Create style with background color
        let withBackground bg style = { style with Background = bg }

        /// Add attribute
        let withAttribute attr style =
            { style with Attributes = attr :: style.Attributes |> List.distinct }

        /// Convert color to ANSI code
        let colorToAnsi (c: TermColor) (isFg: bool) : string =
            let base_ = if isFg then 30 else 40
            match c with
            | ColorDefault -> if isFg then "39" else "49"
            | ColorBlack -> string base_
            | ColorRed -> string (base_ + 1)
            | ColorGreen -> string (base_ + 2)
            | ColorYellow -> string (base_ + 3)
            | ColorBlue -> string (base_ + 4)
            | ColorMagenta -> string (base_ + 5)
            | ColorCyan -> string (base_ + 6)
            | ColorWhite -> string (base_ + 7)
            | Color256 n -> sprintf "%d;5;%d" (if isFg then 38 else 48) n
            | ColorRGB (r, g, b) -> sprintf "%d;2;%d;%d;%d" (if isFg then 38 else 48) r g b

        /// Convert style to ANSI escape sequence
        let toAnsi (style: CellStyle) : string =
            let fg = colorToAnsi style.Foreground true
            let bg = colorToAnsi style.Background false
            let attrs =
                style.Attributes
                |> List.map (function
                    | AttrNone -> "0"
                    | AttrBold -> "1"
                    | AttrDim -> "2"
                    | AttrItalic -> "3"
                    | AttrUnderline -> "4"
                    | AttrBlink -> "5"
                    | AttrReverse -> "7"
                    | AttrStrikethrough -> "9")
            let codes = [fg; bg] @ attrs |> String.concat ";"
            sprintf "\x1b[%sm" codes

    // ═══════════════════════════════════════════════════════════════════════════
    // TERMINAL CELL (tcell-inspired)
    // STAMP: SC-HMI-029 (cell system)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Screen cell
    type ScreenCell = {
        Rune: char
        Width: int  // 1 for normal, 2 for wide chars
        Style: CellStyle
        Combined: char list  // Combining characters
    }

    module ScreenCell =
        /// Create cell with character
        let create (ch: char) =
            { Rune = ch
              Width = 1
              Style = CellStyle.defaultStyle
              Combined = [] }

        /// Create styled cell
        let createStyled ch style =
            { Rune = ch; Width = 1; Style = style; Combined = [] }

        /// Render cell to string
        let render (cell: ScreenCell) : string =
            let style = CellStyle.toAnsi cell.Style
            let combined = cell.Combined |> List.map string |> String.concat ""
            sprintf "%s%c%s\x1b[0m" style cell.Rune combined

    // ═══════════════════════════════════════════════════════════════════════════
    // TERMINAL EVENTS (tcell-inspired)
    // STAMP: SC-HMI-030 (event system)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Key modifiers
    type KeyModifier =
        | ModNone
        | ModShift
        | ModCtrl
        | ModAlt
        | ModMeta

    /// Special keys
    type SpecialKey =
        | KeyRune of char
        | KeyUp
        | KeyDown
        | KeyLeft
        | KeyRight
        | KeyHome
        | KeyEnd
        | KeyPageUp
        | KeyPageDown
        | KeyInsert
        | KeyDelete
        | KeyBackspace
        | KeyTab
        | KeyEnter
        | KeyEscape
        | KeyF1 | KeyF2 | KeyF3 | KeyF4 | KeyF5 | KeyF6
        | KeyF7 | KeyF8 | KeyF9 | KeyF10 | KeyF11 | KeyF12

    /// Mouse button
    type MouseButton =
        | ButtonNone
        | Button1  // Left
        | Button2  // Middle
        | Button3  // Right
        | WheelUp
        | WheelDown

    /// Terminal event
    type TermEvent =
        | EventKey of key: SpecialKey * modifiers: KeyModifier list
        | EventMouse of x: int * y: int * button: MouseButton * modifiers: KeyModifier list
        | EventResize of width: int * height: int
        | EventPaste of text: string
        | EventError of message: string
        | EventInterrupt

    module TermEvent =
        /// Check if key event matches
        let isKey key ev =
            match ev with
            | EventKey (k, _) -> k = key
            | _ -> false

        /// Check if Ctrl+key
        let isCtrlKey ch ev =
            match ev with
            | EventKey (KeyRune c, mods) -> c = ch && List.contains ModCtrl mods
            | _ -> false

        /// Get key name
        let keyName (key: SpecialKey) : string =
            match key with
            | KeyRune c -> sprintf "'%c'" c
            | KeyUp -> "Up"
            | KeyDown -> "Down"
            | KeyLeft -> "Left"
            | KeyRight -> "Right"
            | KeyHome -> "Home"
            | KeyEnd -> "End"
            | KeyPageUp -> "PageUp"
            | KeyPageDown -> "PageDown"
            | KeyInsert -> "Insert"
            | KeyDelete -> "Delete"
            | KeyBackspace -> "Backspace"
            | KeyTab -> "Tab"
            | KeyEnter -> "Enter"
            | KeyEscape -> "Escape"
            | KeyF1 -> "F1" | KeyF2 -> "F2" | KeyF3 -> "F3" | KeyF4 -> "F4"
            | KeyF5 -> "F5" | KeyF6 -> "F6" | KeyF7 -> "F7" | KeyF8 -> "F8"
            | KeyF9 -> "F9" | KeyF10 -> "F10" | KeyF11 -> "F11" | KeyF12 -> "F12"

    // ═══════════════════════════════════════════════════════════════════════════
    // TERMINAL SCREEN BUFFER (tcell-inspired)
    // STAMP: SC-HMI-031 (screen buffer)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Screen buffer
    type ScreenBuffer = {
        Width: int
        Height: int
        Cells: ScreenCell array array
        CursorX: int
        CursorY: int
        CursorVisible: bool
    }

    module ScreenBuffer =
        /// Create empty buffer
        let create width height =
            let emptyCell = ScreenCell.create ' '
            { Width = width
              Height = height
              Cells = Array.init height (fun _ -> Array.create width emptyCell)
              CursorX = 0
              CursorY = 0
              CursorVisible = true }

        /// Clear buffer
        let clear (buf: ScreenBuffer) =
            let emptyCell = ScreenCell.create ' '
            for y in 0 .. buf.Height - 1 do
                for x in 0 .. buf.Width - 1 do
                    buf.Cells.[y].[x] <- emptyCell
            buf

        /// Set cell
        let setCell x y cell (buf: ScreenBuffer) =
            if x >= 0 && x < buf.Width && y >= 0 && y < buf.Height then
                buf.Cells.[y].[x] <- cell
            buf

        /// Get cell
        let getCell x y (buf: ScreenBuffer) =
            if x >= 0 && x < buf.Width && y >= 0 && y < buf.Height then
                Some buf.Cells.[y].[x]
            else None

        /// Set string at position
        let setString x y (text: string) style (buf: ScreenBuffer) =
            text.ToCharArray()
            |> Array.iteri (fun i ch ->
                if x + i < buf.Width then
                    buf.Cells.[y].[x + i] <- ScreenCell.createStyled ch style)
            buf

        /// Render buffer to string list
        let render (buf: ScreenBuffer) : string list =
            buf.Cells
            |> Array.map (fun row ->
                row
                |> Array.map ScreenCell.render
                |> String.concat "")
            |> Array.toList

    // ═══════════════════════════════════════════════════════════════════════════
    // TERMINAL INPUT HANDLER (tcell-inspired)
    // STAMP: SC-HMI-032 (input handling)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Input state
    type InputState = {
        Buffer: char list
        EscapeSequence: string option
        LastKey: TermEvent option
    }

    module InputHandler =
        /// Create initial state
        let create () =
            { Buffer = []
              EscapeSequence = None
              LastKey = None }

        /// Parse escape sequence
        let parseEscapeSequence (seq: string) : TermEvent option =
            match seq with
            | "[A" -> Some (EventKey (KeyUp, []))
            | "[B" -> Some (EventKey (KeyDown, []))
            | "[C" -> Some (EventKey (KeyRight, []))
            | "[D" -> Some (EventKey (KeyLeft, []))
            | "[H" -> Some (EventKey (KeyHome, []))
            | "[F" -> Some (EventKey (KeyEnd, []))
            | "[5~" -> Some (EventKey (KeyPageUp, []))
            | "[6~" -> Some (EventKey (KeyPageDown, []))
            | "[2~" -> Some (EventKey (KeyInsert, []))
            | "[3~" -> Some (EventKey (KeyDelete, []))
            | "OP" -> Some (EventKey (KeyF1, []))
            | "OQ" -> Some (EventKey (KeyF2, []))
            | "OR" -> Some (EventKey (KeyF3, []))
            | "OS" -> Some (EventKey (KeyF4, []))
            | _ -> None

        /// Process input character
        let processChar (ch: char) (state: InputState) : InputState * TermEvent option =
            match state.EscapeSequence with
            | Some seq ->
                let newSeq = seq + string ch
                match parseEscapeSequence newSeq with
                | Some ev -> ({ state with EscapeSequence = None }, Some ev)
                | None ->
                    if newSeq.Length > 6 then
                        // Sequence too long, discard
                        ({ state with EscapeSequence = None }, None)
                    else
                        ({ state with EscapeSequence = Some newSeq }, None)
            | None ->
                match ch with
                | '\x1b' -> ({ state with EscapeSequence = Some "" }, None)
                | '\r' | '\n' -> (state, Some (EventKey (KeyEnter, [])))
                | '\t' -> (state, Some (EventKey (KeyTab, [])))
                | '\x7f' -> (state, Some (EventKey (KeyBackspace, [])))
                | c when int c < 32 ->
                    let key = char (int c + int 'a' - 1)
                    (state, Some (EventKey (KeyRune key, [ModCtrl])))
                | c -> (state, Some (EventKey (KeyRune c, [])))

    // ═══════════════════════════════════════════════════════════════════════════
    // TERMINAL RENDERER (tcell-inspired)
    // STAMP: SC-HMI-033 (output rendering)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Render diff between two buffers
    type RenderDiff = {
        Changes: (int * int * ScreenCell) list
        CursorMove: (int * int) option
    }

    module TermRenderer =
        /// Calculate diff between buffers
        let diff (oldBuf: ScreenBuffer) (newBuf: ScreenBuffer) : RenderDiff =
            let changes =
                [ for y in 0 .. min oldBuf.Height newBuf.Height - 1 do
                    for x in 0 .. min oldBuf.Width newBuf.Width - 1 do
                        let oldCell = oldBuf.Cells.[y].[x]
                        let newCell = newBuf.Cells.[y].[x]
                        if oldCell <> newCell then
                            yield (x, y, newCell) ]

            let cursorMove =
                if oldBuf.CursorX <> newBuf.CursorX || oldBuf.CursorY <> newBuf.CursorY then
                    Some (newBuf.CursorX, newBuf.CursorY)
                else None

            { Changes = changes; CursorMove = cursorMove }

        /// Generate ANSI commands for diff
        let renderDiff (diff: RenderDiff) : string =
            let moveTo x y = sprintf "\x1b[%d;%dH" (y + 1) (x + 1)

            let changes =
                diff.Changes
                |> List.map (fun (x, y, cell) ->
                    moveTo x y + ScreenCell.render cell)
                |> String.concat ""

            let cursor =
                match diff.CursorMove with
                | Some (x, y) -> moveTo x y
                | None -> ""

            changes + cursor

        /// Clear screen command
        let clearScreen () = "\x1b[2J\x1b[H"

        /// Hide cursor command
        let hideCursor () = "\x1b[?25l"

        /// Show cursor command
        let showCursor () = "\x1b[?25h"

        /// Enter alternate screen
        let enterAltScreen () = "\x1b[?1049h"

        /// Exit alternate screen
        let exitAltScreen () = "\x1b[?1049l"

        /// Enable mouse tracking
        let enableMouse () = "\x1b[?1000h\x1b[?1006h"

        /// Disable mouse tracking
        let disableMouse () = "\x1b[?1000l\x1b[?1006l"

        /// Enable bracketed paste
        let enablePaste () = "\x1b[?2004h"

        /// Disable bracketed paste
        let disablePaste () = "\x1b[?2004l"

    // ============================================================================
    // TVIEW-INSPIRED ADVANCED COMPONENTS (SC-HMI-034 to SC-HMI-042)
    // Based on: https://github.com/rivo/tview
    // ============================================================================

    // ------------------------------------------------------------------------
    // COMPONENT: Grid Layout System (SC-HMI-034)
    // Organized positioning system for components in rows and columns
    // ------------------------------------------------------------------------

    /// Grid cell alignment
    type GridAlignment =
        | AlignStart
        | AlignCenter
        | AlignEnd
        | AlignStretch

    /// Grid cell definition
    type GridCell = {
        Row: int
        Column: int
        RowSpan: int
        ColSpan: int
        Content: string list
        HAlign: GridAlignment
        VAlign: GridAlignment
        MinWidth: int option
        MinHeight: int option
    }

    /// Grid layout configuration
    type Grid = {
        Rows: int
        Columns: int
        Cells: GridCell list
        RowHeights: int list option      // Fixed heights, or None for auto
        ColWidths: int list option       // Fixed widths, or None for auto
        RowGap: int
        ColGap: int
        Border: bool
        Title: string option
    }

    module Grid =
        /// Create an empty grid
        let create rows cols =
            { Rows = rows
              Columns = cols
              Cells = []
              RowHeights = None
              ColWidths = None
              RowGap = 0
              ColGap = 0
              Border = true
              Title = None }

        /// Add a cell to the grid
        let addCell row col content (grid: Grid) =
            let cell = {
                Row = row
                Column = col
                RowSpan = 1
                ColSpan = 1
                Content = content
                HAlign = AlignStart
                VAlign = AlignStart
                MinWidth = None
                MinHeight = None
            }
            { grid with Cells = cell :: grid.Cells }

        /// Add a cell with span
        let addCellWithSpan row col rowSpan colSpan content (grid: Grid) =
            let cell = {
                Row = row
                Column = col
                RowSpan = rowSpan
                ColSpan = colSpan
                Content = content
                HAlign = AlignStart
                VAlign = AlignStart
                MinWidth = None
                MinHeight = None
            }
            { grid with Cells = cell :: grid.Cells }

        /// Calculate column widths based on content
        let private calculateColWidths (grid: Grid) (totalWidth: int) =
            match grid.ColWidths with
            | Some widths -> widths
            | None ->
                let availableWidth = totalWidth - (grid.ColGap * (grid.Columns - 1)) - (if grid.Border then 2 else 0)
                let baseWidth = availableWidth / grid.Columns
                List.init grid.Columns (fun _ -> baseWidth)

        /// Calculate row heights based on content
        let private calculateRowHeights (grid: Grid) (totalHeight: int) =
            match grid.RowHeights with
            | Some heights -> heights
            | None ->
                let availableHeight = totalHeight - (grid.RowGap * (grid.Rows - 1)) - (if grid.Border then 2 else 0)
                let baseHeight = availableHeight / grid.Rows
                List.init grid.Rows (fun _ -> max 1 baseHeight)

        /// Render the grid
        let renderGrid (grid: Grid) (width: int) (height: int) : string list =
            let colWidths = calculateColWidths grid width
            let rowHeights = calculateRowHeights grid height

            let topBorder =
                if grid.Border then
                    let title = grid.Title |> Option.defaultValue ""
                    let inner = String.replicate (width - 2) "─"
                    if title <> "" then
                        let titlePart = sprintf " %s " title
                        let leftPad = (width - 2 - String.length titlePart) / 2
                        let rightPad = width - 2 - leftPad - String.length titlePart
                        [sprintf "┌%s%s%s┐" (String.replicate leftPad "─") titlePart (String.replicate rightPad "─")]
                    else
                        [sprintf "┌%s┐" inner]
                else []

            let bottomBorder =
                if grid.Border then
                    [sprintf "└%s┘" (String.replicate (width - 2) "─")]
                else []

            let contentLines =
                [ for rowIdx in 0 .. grid.Rows - 1 do
                    let rowHeight = if rowIdx < List.length rowHeights then rowHeights.[rowIdx] else 1
                    for lineIdx in 0 .. rowHeight - 1 do
                        let cellContents =
                            [ for colIdx in 0 .. grid.Columns - 1 do
                                let colWidth = if colIdx < List.length colWidths then colWidths.[colIdx] else 10
                                let cell = grid.Cells |> List.tryFind (fun c -> c.Row = rowIdx && c.Column = colIdx)
                                match cell with
                                | Some c when lineIdx < List.length c.Content ->
                                    let content = c.Content.[lineIdx]
                                    let padded =
                                        if String.length content > colWidth then
                                            content.Substring(0, colWidth)
                                        else
                                            content.PadRight(colWidth)
                                    padded
                                | _ -> String.replicate colWidth " "
                            ]
                        let line = String.concat (String.replicate grid.ColGap " ") cellContents
                        if grid.Border then
                            sprintf "│%s│" (line.PadRight(width - 2))
                        else
                            line
                ]

            topBorder @ contentLines @ bottomBorder

    // ------------------------------------------------------------------------
    // COMPONENT: Flexbox Layout System (SC-HMI-035)
    // Flexible box layout model for dynamic sizing
    // ------------------------------------------------------------------------

    /// Flex direction
    type FlexDirection = FlexRow | FlexColumn | FlexRowReverse | FlexColumnReverse

    /// Flex wrap behavior
    type FlexWrap = NoWrap | Wrap | WrapReverse

    /// Flex justify content
    type JustifyContent =
        | JustifyStart
        | JustifyEnd
        | JustifyCenter
        | JustifySpaceBetween
        | JustifySpaceAround
        | JustifySpaceEvenly

    /// Flex align items
    type AlignItems = AlignItemsStart | AlignItemsEnd | AlignItemsCenter | AlignItemsStretch

    /// Flex item
    type FlexItem = {
        Content: string list
        FlexGrow: float
        FlexShrink: float
        FlexBasis: int option    // None = auto
        AlignSelf: AlignItems option
        MinWidth: int
        MaxWidth: int option
    }

    /// Flexbox container
    type Flexbox = {
        Direction: FlexDirection
        Wrap: FlexWrap
        JustifyContent: JustifyContent
        AlignItems: AlignItems
        Gap: int
        Items: FlexItem list
        Border: bool
        Title: string option
    }

    module Flexbox =
        /// Create a flexbox container
        let create direction =
            { Direction = direction
              Wrap = NoWrap
              JustifyContent = JustifyStart
              AlignItems = AlignItemsStretch
              Gap = 1
              Items = []
              Border = false
              Title = None }

        /// Add an item to the flexbox
        let addItem content (flex: Flexbox) =
            let item = {
                Content = content
                FlexGrow = 0.0
                FlexShrink = 1.0
                FlexBasis = None
                AlignSelf = None
                MinWidth = 0
                MaxWidth = None
            }
            { flex with Items = flex.Items @ [item] }

        /// Add an item with flex grow
        let addFlexItem content grow (flex: Flexbox) =
            let item = {
                Content = content
                FlexGrow = grow
                FlexShrink = 1.0
                FlexBasis = None
                AlignSelf = None
                MinWidth = 0
                MaxWidth = None
            }
            { flex with Items = flex.Items @ [item] }

        /// Render the flexbox
        let renderFlexbox (flex: Flexbox) (width: int) (height: int) : string list =
            let innerWidth = if flex.Border then width - 2 else width
            let innerHeight = if flex.Border then height - 2 else height

            match flex.Direction with
            | FlexRow | FlexRowReverse ->
                // Horizontal layout
                let totalGrow = flex.Items |> List.sumBy (fun i -> i.FlexGrow)
                let fixedWidth = flex.Items |> List.sumBy (fun i -> i.FlexBasis |> Option.defaultValue 0)
                let gapTotal = flex.Gap * (List.length flex.Items - 1)
                let flexSpace = innerWidth - fixedWidth - gapTotal

                let itemWidths =
                    flex.Items |> List.map (fun item ->
                        match item.FlexBasis with
                        | Some basis -> basis
                        | None ->
                            if totalGrow > 0.0 then
                                int (float flexSpace * (item.FlexGrow / totalGrow))
                            else
                                let contentWidth = item.Content |> List.map String.length |> List.fold max 0
                                min contentWidth (innerWidth / max 1 (List.length flex.Items))
                    )

                let maxLines = flex.Items |> List.map (fun i -> List.length i.Content) |> List.fold max 1

                let contentLines =
                    [ for lineIdx in 0 .. maxLines - 1 do
                        let parts =
                            List.zip flex.Items itemWidths
                            |> List.map (fun (item, w) ->
                                if lineIdx < List.length item.Content then
                                    let content = item.Content.[lineIdx]
                                    if String.length content > w then content.Substring(0, w)
                                    else content.PadRight(w)
                                else
                                    String.replicate w " "
                            )
                        let items = if flex.Direction = FlexRowReverse then List.rev parts else parts
                        String.concat (String.replicate flex.Gap " ") items
                    ]

                if flex.Border then
                    let title = flex.Title |> Option.defaultValue ""
                    let topBorder =
                        if title <> "" then
                            sprintf "┌─ %s %s┐" title (String.replicate (width - 5 - String.length title) "─")
                        else
                            sprintf "┌%s┐" (String.replicate (width - 2) "─")
                    let bottomBorder = sprintf "└%s┘" (String.replicate (width - 2) "─")
                    [topBorder] @ (contentLines |> List.map (fun l -> sprintf "│%s│" (l.PadRight(width - 2)))) @ [bottomBorder]
                else
                    contentLines

            | FlexColumn | FlexColumnReverse ->
                // Vertical layout
                let allContent =
                    flex.Items
                    |> List.collect (fun item ->
                        item.Content @ (if flex.Gap > 0 then List.replicate flex.Gap "" else [])
                    )
                let lines = if flex.Direction = FlexColumnReverse then List.rev allContent else allContent

                if flex.Border then
                    let title = flex.Title |> Option.defaultValue ""
                    let topBorder =
                        if title <> "" then
                            sprintf "┌─ %s %s┐" title (String.replicate (width - 5 - String.length title) "─")
                        else
                            sprintf "┌%s┐" (String.replicate (width - 2) "─")
                    let bottomBorder = sprintf "└%s┘" (String.replicate (width - 2) "─")
                    [topBorder] @ (lines |> List.map (fun l -> sprintf "│%s│" (l.PadRight(width - 2)))) @ [bottomBorder]
                else
                    lines

    // ------------------------------------------------------------------------
    // COMPONENT: SelectableList (SC-HMI-036)
    // Navigable, selectable list with keyboard support
    // ------------------------------------------------------------------------

    /// List item with selection state
    type SelectableListItem = {
        Id: string
        Text: string
        SecondaryText: string option
        Icon: string option
        Disabled: bool
        Selected: bool
    }

    /// Selectable list configuration
    type SelectableList = {
        Title: string option
        Items: SelectableListItem list
        SelectedIndex: int
        MultiSelect: bool
        ShowIndex: bool
        Border: bool
        MaxVisible: int option
        ScrollOffset: int
        FilterText: string option
    }

    module SelectableList =
        /// Create a selectable list
        let create items =
            { Title = None
              Items = items |> List.mapi (fun i text ->
                  { Id = sprintf "item-%d" i
                    Text = text
                    SecondaryText = None
                    Icon = None
                    Disabled = false
                    Selected = false })
              SelectedIndex = 0
              MultiSelect = false
              ShowIndex = false
              Border = true
              MaxVisible = None
              ScrollOffset = 0
              FilterText = None }

        /// Move selection up
        let moveUp (list: SelectableList) =
            let newIndex = max 0 (list.SelectedIndex - 1)
            { list with SelectedIndex = newIndex }

        /// Move selection down
        let moveDown (list: SelectableList) =
            let newIndex = min (List.length list.Items - 1) (list.SelectedIndex + 1)
            { list with SelectedIndex = newIndex }

        /// Toggle selection (for multi-select)
        let toggleSelect (list: SelectableList) =
            if not list.MultiSelect then list
            else
                let items = list.Items |> List.mapi (fun i item ->
                    if i = list.SelectedIndex then
                        { item with Selected = not item.Selected }
                    else item
                )
                { list with Items = items }

        /// Get selected items
        let getSelected (list: SelectableList) =
            if list.MultiSelect then
                list.Items |> List.filter (fun i -> i.Selected)
            else
                list.Items |> List.tryItem list.SelectedIndex |> Option.toList

        /// Render the selectable list
        let renderList (list: SelectableList) (width: int) : string list =
            let innerWidth = if list.Border then width - 2 else width

            let visibleItems =
                match list.MaxVisible with
                | Some max ->
                    let start = list.ScrollOffset
                    list.Items |> List.skip start |> List.truncate max
                | None -> list.Items

            let filteredItems =
                match list.FilterText with
                | Some filter when filter <> "" ->
                    let filterLower = filter.ToLower()
                    visibleItems |> List.filter (fun i -> i.Text.ToLower().Contains(filterLower))
                | _ -> visibleItems

            let itemLines =
                filteredItems |> List.mapi (fun displayIdx item ->
                    let actualIdx =
                        match list.MaxVisible with
                        | Some _ -> list.ScrollOffset + displayIdx
                        | None -> displayIdx

                    let isSelected = actualIdx = list.SelectedIndex
                    let prefix =
                        if list.MultiSelect then
                            if item.Selected then "[x] " else "[ ] "
                        else if isSelected then "> " else "  "

                    let icon = item.Icon |> Option.map (fun i -> i + " ") |> Option.defaultValue ""
                    let indexStr = if list.ShowIndex then sprintf "%d. " (actualIdx + 1) else ""
                    let secondary = item.SecondaryText |> Option.map (fun s -> sprintf " (%s)" s) |> Option.defaultValue ""

                    let content = sprintf "%s%s%s%s%s" prefix indexStr icon item.Text secondary
                    let padded =
                        if String.length content > innerWidth then
                            content.Substring(0, innerWidth - 1) + "…"
                        else
                            content.PadRight(innerWidth)

                    let styled =
                        if item.Disabled then sprintf "\x1b[2m%s\x1b[0m" padded  // Dim
                        elif isSelected then sprintf "\x1b[7m%s\x1b[0m" padded   // Reverse
                        else padded

                    styled
                )

            let topBorder =
                if list.Border then
                    match list.Title with
                    | Some title ->
                        [sprintf "┌─ %s %s┐" title (String.replicate (width - 5 - String.length title) "─")]
                    | None ->
                        [sprintf "┌%s┐" (String.replicate (width - 2) "─")]
                else []

            let bottomBorder =
                if list.Border then
                    let scrollInfo =
                        match list.MaxVisible with
                        | Some max when List.length list.Items > max ->
                            sprintf " %d/%d " (list.SelectedIndex + 1) (List.length list.Items)
                        | _ -> ""
                    [sprintf "└%s%s┘" (String.replicate (width - 2 - String.length scrollInfo) "─") scrollInfo]
                else []

            let content =
                if list.Border then
                    itemLines |> List.map (fun l -> sprintf "│%s│" l)
                else itemLines

            topBorder @ content @ bottomBorder

    // ------------------------------------------------------------------------
    // COMPONENT: Pages (SC-HMI-037)
    // Multi-page navigation container
    // ------------------------------------------------------------------------

    /// Page definition
    type Page = {
        Id: string
        Title: string
        Content: string list
        Icon: string option
    }

    /// Pages container
    type Pages = {
        Pages: Page list
        CurrentIndex: int
        ShowTabs: bool
        TabPosition: string  // "top" | "bottom"
        Border: bool
    }

    module Pages =
        /// Create a pages container
        let create pages =
            { Pages = pages
              CurrentIndex = 0
              ShowTabs = true
              TabPosition = "top"
              Border = true }

        /// Navigate to next page
        let nextPage (pages: Pages) =
            let newIndex = (pages.CurrentIndex + 1) % List.length pages.Pages
            { pages with CurrentIndex = newIndex }

        /// Navigate to previous page
        let prevPage (pages: Pages) =
            let newIndex =
                if pages.CurrentIndex = 0 then List.length pages.Pages - 1
                else pages.CurrentIndex - 1
            { pages with CurrentIndex = newIndex }

        /// Navigate to specific page
        let goToPage index (pages: Pages) =
            if index >= 0 && index < List.length pages.Pages then
                { pages with CurrentIndex = index }
            else pages

        /// Get current page
        let currentPage (pages: Pages) =
            List.tryItem pages.CurrentIndex pages.Pages

        /// Render the pages
        let renderPages (pages: Pages) (width: int) (height: int) : string list =
            let innerWidth = if pages.Border then width - 2 else width

            let tabs =
                if pages.ShowTabs then
                    let tabItems =
                        pages.Pages |> List.mapi (fun i page ->
                            let icon = page.Icon |> Option.map (fun ic -> ic + " ") |> Option.defaultValue ""
                            let text = sprintf "%s%s" icon page.Title
                            if i = pages.CurrentIndex then
                                sprintf "\x1b[7m %s \x1b[0m" text  // Reverse for active
                            else
                                sprintf " %s " text
                        )
                    [String.concat " │ " tabItems]
                else []

            let currentContent =
                match currentPage pages with
                | Some page -> page.Content
                | None -> ["No pages"]

            let topBorder =
                if pages.Border then
                    [sprintf "┌%s┐" (String.replicate (width - 2) "─")]
                else []

            let bottomBorder =
                if pages.Border then
                    [sprintf "└%s┘" (String.replicate (width - 2) "─")]
                else []

            let formatLine line =
                let padded =
                    if String.length line > innerWidth then
                        line.Substring(0, innerWidth)
                    else
                        line.PadRight(innerWidth)
                if pages.Border then sprintf "│%s│" padded else padded

            match pages.TabPosition with
            | "top" ->
                topBorder @ (tabs |> List.map formatLine) @
                (if pages.ShowTabs then [formatLine (String.replicate innerWidth "─")] else []) @
                (currentContent |> List.map formatLine) @ bottomBorder
            | _ ->
                topBorder @ (currentContent |> List.map formatLine) @
                (if pages.ShowTabs then [formatLine (String.replicate innerWidth "─")] else []) @
                (tabs |> List.map formatLine) @ bottomBorder

    // ------------------------------------------------------------------------
    // COMPONENT: InputField (SC-HMI-038)
    // Single-line text input with cursor
    // ------------------------------------------------------------------------

    /// Input field type
    type InputType = TextInput | PasswordInput | NumberInput | EmailInput

    /// Input field
    type InputField = {
        Label: string option
        Placeholder: string
        Value: string
        CursorPos: int
        InputType: InputType
        MaxLength: int option
        Disabled: bool
        Error: string option
        Width: int
        Focused: bool
    }

    module InputField =
        /// Create an input field
        let create placeholder =
            { Label = None
              Placeholder = placeholder
              Value = ""
              CursorPos = 0
              InputType = TextInput
              MaxLength = None
              Disabled = false
              Error = None
              Width = 30
              Focused = false }

        /// Insert character at cursor
        let insertChar (ch: char) (field: InputField) =
            if field.Disabled then field
            else
                match field.MaxLength with
                | Some max when String.length field.Value >= max -> field
                | _ ->
                    let before = field.Value.Substring(0, field.CursorPos)
                    let after = field.Value.Substring(field.CursorPos)
                    { field with
                        Value = before + string ch + after
                        CursorPos = field.CursorPos + 1 }

        /// Delete character before cursor
        let backspace (field: InputField) =
            if field.Disabled || field.CursorPos = 0 then field
            else
                let before = field.Value.Substring(0, field.CursorPos - 1)
                let after = field.Value.Substring(field.CursorPos)
                { field with
                    Value = before + after
                    CursorPos = field.CursorPos - 1 }

        /// Delete character at cursor
        let delete (field: InputField) =
            if field.Disabled || field.CursorPos >= String.length field.Value then field
            else
                let before = field.Value.Substring(0, field.CursorPos)
                let after = field.Value.Substring(field.CursorPos + 1)
                { field with Value = before + after }

        /// Move cursor left
        let moveLeft (field: InputField) =
            { field with CursorPos = max 0 (field.CursorPos - 1) }

        /// Move cursor right
        let moveRight (field: InputField) =
            { field with CursorPos = min (String.length field.Value) (field.CursorPos + 1) }

        /// Move cursor to start
        let moveToStart (field: InputField) =
            { field with CursorPos = 0 }

        /// Move cursor to end
        let moveToEnd (field: InputField) =
            { field with CursorPos = String.length field.Value }

        /// Render the input field
        let renderInput (field: InputField) : string list =
            let labelLine =
                field.Label |> Option.map (fun l -> [l]) |> Option.defaultValue []

            let displayValue =
                match field.InputType with
                | PasswordInput -> String.replicate (String.length field.Value) "●"
                | _ -> field.Value

            let valueOrPlaceholder =
                if field.Value = "" then
                    sprintf "\x1b[2m%s\x1b[0m" field.Placeholder  // Dim placeholder
                else
                    displayValue

            let inputContent =
                if String.length valueOrPlaceholder < field.Width then
                    valueOrPlaceholder.PadRight(field.Width)
                else
                    valueOrPlaceholder.Substring(0, field.Width)

            let styledInput =
                if field.Focused then
                    // Show cursor
                    let before = inputContent.Substring(0, min field.CursorPos (String.length inputContent))
                    let cursor =
                        if field.CursorPos < String.length inputContent then
                            sprintf "\x1b[7m%c\x1b[0m" inputContent.[field.CursorPos]
                        else
                            "\x1b[7m \x1b[0m"
                    let after =
                        if field.CursorPos + 1 < String.length inputContent then
                            inputContent.Substring(field.CursorPos + 1)
                        else ""
                    before + cursor + after
                else
                    inputContent

            let borderColor =
                if field.Error.IsSome then "\x1b[31m"  // Red
                elif field.Focused then "\x1b[36m"     // Cyan
                else "\x1b[90m"                        // Gray

            let inputLine = sprintf "%s┌%s┐\x1b[0m" borderColor (String.replicate field.Width "─")
            let contentLine = sprintf "%s│\x1b[0m%s%s│\x1b[0m" borderColor styledInput borderColor
            let bottomLine = sprintf "%s└%s┘\x1b[0m" borderColor (String.replicate field.Width "─")

            let errorLine =
                field.Error |> Option.map (fun e -> [sprintf "\x1b[31m%s\x1b[0m" e]) |> Option.defaultValue []

            labelLine @ [inputLine; contentLine; bottomLine] @ errorLine

    // ------------------------------------------------------------------------
    // COMPONENT: Form (SC-HMI-039)
    // Bundling multiple input components
    // ------------------------------------------------------------------------

    /// Form field wrapper
    type FormField =
        | FormInputField of InputField
        | FormCheckbox of label: string * isChecked: bool
        | FormDropdown of label: string * options: string list * selected: int
        | FormTextArea of label: string * content: string

    /// Form configuration
    type Form = {
        Title: string option
        Fields: (string * FormField) list  // (field name, field)
        FocusedField: int
        SubmitLabel: string
        CancelLabel: string option
        Border: bool
        Width: int
    }

    module Form =
        /// Create a form
        let create fields =
            { Title = None
              Fields = fields
              FocusedField = 0
              SubmitLabel = "Submit"
              CancelLabel = Some "Cancel"
              Border = true
              Width = 50 }

        /// Focus next field
        let focusNext (form: Form) =
            let newFocus = (form.FocusedField + 1) % (List.length form.Fields + 2)  // +2 for buttons
            { form with FocusedField = newFocus }

        /// Focus previous field
        let focusPrev (form: Form) =
            let total = List.length form.Fields + 2
            let newFocus = if form.FocusedField = 0 then total - 1 else form.FocusedField - 1
            { form with FocusedField = newFocus }

        /// Get all field values
        let getValues (form: Form) =
            form.Fields |> List.map (fun (name, field) ->
                let value =
                    match field with
                    | FormInputField f -> f.Value
                    | FormCheckbox (_, isChecked) -> if isChecked then "true" else "false"
                    | FormDropdown (_, opts, sel) -> List.tryItem sel opts |> Option.defaultValue ""
                    | FormTextArea (_, content) -> content
                (name, value)
            ) |> Map.ofList

        /// Render the form
        let renderForm (form: Form) : string list =
            let innerWidth = form.Width - 2

            let titleLines =
                form.Title |> Option.map (fun t ->
                    [sprintf "┌─ %s %s┐" t (String.replicate (form.Width - 5 - String.length t) "─")]
                ) |> Option.defaultValue [sprintf "┌%s┐" (String.replicate (form.Width - 2) "─")]

            let fieldLines =
                form.Fields |> List.mapi (fun idx (name, field) ->
                    let isFocused = idx = form.FocusedField
                    let focusIndicator = if isFocused then "▶ " else "  "

                    match field with
                    | FormInputField f ->
                        let label = f.Label |> Option.defaultValue name
                        let displayValue =
                            match f.InputType with
                            | PasswordInput -> String.replicate (String.length f.Value) "●"
                            | _ -> if f.Value = "" then f.Placeholder else f.Value
                        [sprintf "│%s%s: [%s]%s│" focusIndicator label displayValue
                            (String.replicate (innerWidth - String.length focusIndicator - String.length label - 4 - String.length displayValue) " ")]
                    | FormCheckbox (label, isChecked) ->
                        let checkbox = if isChecked then "[x]" else "[ ]"
                        [sprintf "│%s%s %s%s│" focusIndicator checkbox label
                            (String.replicate (innerWidth - String.length focusIndicator - 4 - String.length label) " ")]
                    | FormDropdown (label, opts, sel) ->
                        let selected = List.tryItem sel opts |> Option.defaultValue "---"
                        [sprintf "│%s%s: [%s ▼]%s│" focusIndicator label selected
                            (String.replicate (innerWidth - String.length focusIndicator - String.length label - 6 - String.length selected) " ")]
                    | FormTextArea (label, _) ->
                        [sprintf "│%s%s: [...]%s│" focusIndicator label
                            (String.replicate (innerWidth - String.length focusIndicator - String.length label - 7) " ")]
                ) |> List.concat

            let buttonIdx = List.length form.Fields
            let submitFocused = form.FocusedField = buttonIdx
            let cancelFocused = form.FocusedField = buttonIdx + 1

            let submitBtn =
                if submitFocused then sprintf "\x1b[7m[%s]\x1b[0m" form.SubmitLabel
                else sprintf "[%s]" form.SubmitLabel
            let cancelBtn =
                form.CancelLabel |> Option.map (fun c ->
                    if cancelFocused then sprintf " \x1b[7m[%s]\x1b[0m" c
                    else sprintf " [%s]" c
                ) |> Option.defaultValue ""

            let buttonLine =
                let buttons = submitBtn + cancelBtn
                let padding = innerWidth - String.length buttons - 2  // Rough estimate due to ANSI codes
                sprintf "│  %s%s│" buttons (String.replicate (max 0 padding) " ")

            let bottomLine = sprintf "└%s┘" (String.replicate (form.Width - 2) "─")

            titleLines @ [sprintf "│%s│" (String.replicate innerWidth " ")] @
            fieldLines @
            [sprintf "│%s│" (String.replicate innerWidth " "); buttonLine; bottomLine]

    // ------------------------------------------------------------------------
    // COMPONENT: Image (SC-HMI-040)
    // Terminal image display using various protocols
    // ------------------------------------------------------------------------

    /// Image display protocol
    type ImageProtocol =
        | AsciiArt           // Basic ASCII art rendering
        | Braille            // Unicode braille characters
        | HalfBlock          // Unicode half-block characters
        | Sixel              // Sixel graphics protocol
        | Kitty              // Kitty graphics protocol
        | ITerm2             // iTerm2 inline images

    /// Image display configuration
    type TermImage = {
        Width: int
        Height: int
        Protocol: ImageProtocol
        Alt: string          // Alternative text
        Source: string       // File path or URL
        Cached: string list option  // Cached rendered lines
    }

    module TermImage =
        /// Create an image placeholder
        let create width height alt =
            { Width = width
              Height = height
              Protocol = HalfBlock
              Alt = alt
              Source = ""
              Cached = None }

        /// Render ASCII art placeholder (actual image rendering requires external library)
        let renderPlaceholder (img: TermImage) : string list =
            let topBorder = sprintf "┌%s┐" (String.replicate (img.Width - 2) "─")
            let bottomBorder = sprintf "└%s┘" (String.replicate (img.Width - 2) "─")

            let centerText = sprintf "[ %s ]" img.Alt
            let centerY = img.Height / 2

            [ yield topBorder
              for y in 1 .. img.Height - 2 do
                  if y = centerY then
                      let padding = (img.Width - 2 - String.length centerText) / 2
                      yield sprintf "│%s%s%s│"
                          (String.replicate padding " ")
                          centerText
                          (String.replicate (img.Width - 2 - padding - String.length centerText) " ")
                  else
                      yield sprintf "│%s│" (String.replicate (img.Width - 2) " ")
              yield bottomBorder ]

        /// Generate Sixel escape sequence header
        let sixelHeader () = "\x1bPq"

        /// Generate Sixel escape sequence footer
        let sixelFooter () = "\x1b\\"

        /// Generate Kitty graphics protocol command
        let kittyCommand action payload =
            sprintf "\x1b_G%s;%s\x1b\\" action payload

        /// Generate iTerm2 inline image
        let iterm2Image base64Data width height =
            sprintf "\x1b]1337;File=inline=1;width=%d;height=%d:%s\x07" width height base64Data

    // ------------------------------------------------------------------------
    // COMPONENT: Modal Dialog (SC-HMI-041)
    // Modal message windows with buttons
    // ------------------------------------------------------------------------

    /// Modal button
    type ModalButton = {
        Label: string
        Action: string
        Primary: bool
        Destructive: bool
    }

    /// Modal dialog
    type Modal = {
        Title: string
        Message: string list
        Buttons: ModalButton list
        FocusedButton: int
        Width: int
        Icon: string option
        Dismissible: bool
    }

    module Modal =
        /// Create a modal
        let create title message =
            { Title = title
              Message = message
              Buttons = [{ Label = "OK"; Action = "ok"; Primary = true; Destructive = false }]
              FocusedButton = 0
              Width = 50
              Icon = None
              Dismissible = true }

        /// Create a confirmation modal
        let confirm title message =
            { Title = title
              Message = message
              Buttons = [
                  { Label = "Confirm"; Action = "confirm"; Primary = true; Destructive = false }
                  { Label = "Cancel"; Action = "cancel"; Primary = false; Destructive = false }
              ]
              FocusedButton = 0
              Width = 50
              Icon = Some "?"
              Dismissible = true }

        /// Create a destructive confirmation modal
        let confirmDestructive title message =
            { Title = title
              Message = message
              Buttons = [
                  { Label = "Delete"; Action = "delete"; Primary = false; Destructive = true }
                  { Label = "Cancel"; Action = "cancel"; Primary = true; Destructive = false }
              ]
              FocusedButton = 1  // Default to cancel
              Width = 50
              Icon = Some "⚠"
              Dismissible = true }

        /// Focus next button
        let focusNext (modal: Modal) =
            let newFocus = (modal.FocusedButton + 1) % List.length modal.Buttons
            { modal with FocusedButton = newFocus }

        /// Focus previous button
        let focusPrev (modal: Modal) =
            let newFocus =
                if modal.FocusedButton = 0 then List.length modal.Buttons - 1
                else modal.FocusedButton - 1
            { modal with FocusedButton = newFocus }

        /// Render the modal
        let renderModal (modal: Modal) : string list =
            let innerWidth = modal.Width - 4

            let iconPart = modal.Icon |> Option.map (fun i -> sprintf "%s " i) |> Option.defaultValue ""
            let padding = String.replicate (max 0 (innerWidth - String.length iconPart - String.length modal.Title)) " "
            let titleLine = sprintf "│ %s%s%s │" iconPart modal.Title padding

            let messageLine (line: string) =
                let padded =
                    if String.length line > innerWidth then
                        line.Substring(0, innerWidth - 1) + "…"
                    else
                        line.PadRight(innerWidth)
                sprintf "│ %s │" padded

            let buttonLine =
                let buttons = modal.Buttons |> List.mapi (fun i btn ->
                    let isFocused = i = modal.FocusedButton
                    let style =
                        if btn.Destructive then "\x1b[31m"  // Red
                        elif btn.Primary then "\x1b[36m"     // Cyan
                        else ""
                    let endStyle = if style <> "" then "\x1b[0m" else ""
                    if isFocused then
                        sprintf "%s\x1b[7m[%s]\x1b[0m%s" style btn.Label endStyle
                    else
                        sprintf "%s[%s]%s" style btn.Label endStyle
                )
                let buttonsStr = String.concat "  " buttons
                sprintf "│ %s%s │" buttonsStr (String.replicate (max 0 (innerWidth - String.length buttonsStr - 6)) " ")

            let topBorder = sprintf "╭%s╮" (String.replicate (modal.Width - 2) "─")
            let divider = sprintf "├%s┤" (String.replicate (modal.Width - 2) "─")
            let bottomBorder = sprintf "╰%s╯" (String.replicate (modal.Width - 2) "─")
            let emptyLine = sprintf "│%s│" (String.replicate (modal.Width - 2) " ")

            [topBorder; titleLine; divider] @
            (modal.Message |> List.map messageLine) @
            [emptyLine; buttonLine; bottomBorder]

    // ------------------------------------------------------------------------
    // COMPONENT: Primitives / Box Drawing (SC-HMI-042)
    // Basic primitives for custom drawing
    // ------------------------------------------------------------------------

    module Primitives =
        /// Box drawing style type
        type BoxStyle = {
            TopLeft: char
            TopRight: char
            BottomLeft: char
            BottomRight: char
            Horizontal: char
            Vertical: char
        }

        /// Box drawing characters
        let boxLight = {
            TopLeft = '┌'; TopRight = '┐'
            BottomLeft = '└'; BottomRight = '┘'
            Horizontal = '─'; Vertical = '│'
        }

        let boxHeavy = {
            TopLeft = '┏'; TopRight = '┓'
            BottomLeft = '┗'; BottomRight = '┛'
            Horizontal = '━'; Vertical = '┃'
        }

        let boxDouble = {
            TopLeft = '╔'; TopRight = '╗'
            BottomLeft = '╚'; BottomRight = '╝'
            Horizontal = '═'; Vertical = '║'
        }

        let boxRounded = {
            TopLeft = '╭'; TopRight = '╮'
            BottomLeft = '╰'; BottomRight = '╯'
            Horizontal = '─'; Vertical = '│'
        }

        /// Draw a horizontal line
        let hLine char width = String.replicate width (string char)

        /// Draw a vertical line
        let vLine char height = List.init height (fun _ -> string char)

        /// Draw a filled rectangle
        let filledRect char width height =
            List.init height (fun _ -> String.replicate width (string char))

        /// Draw an empty box
        let box (style: BoxStyle) width height =
            let top = sprintf "%c%s%c" style.TopLeft (hLine style.Horizontal (width - 2)) style.TopRight
            let middle = sprintf "%c%s%c" style.Vertical (String.replicate (width - 2) " ") style.Vertical
            let bottom = sprintf "%c%s%c" style.BottomLeft (hLine style.Horizontal (width - 2)) style.BottomRight
            [top] @ List.init (height - 2) (fun _ -> middle) @ [bottom]

        /// Block characters for drawing
        let blocks = {|
            Full = '█'
            SevenEighths = '▉'
            ThreeQuarters = '▊'
            FiveEighths = '▋'
            Half = '▌'
            ThreeEighths = '▍'
            Quarter = '▎'
            Eighth = '▏'
            UpperHalf = '▀'
            LowerHalf = '▄'
            LeftHalf = '▌'
            RightHalf = '▐'
        |}

        /// Shade characters
        let shades = {|
            Light = '░'
            Medium = '▒'
            Dark = '▓'
        |}

        /// Progress bar with custom characters
        let progressBar width progress fillChar emptyChar =
            let filled = int (float width * progress)
            let empty = width - filled
            String.replicate filled (string fillChar) + String.replicate empty (string emptyChar)

    // ========================================================================
    // PODMAN-TUI INSPIRED COMPONENTS (SC-HMI-043 to SC-HMI-060)
    // Container management TUI components inspired by github.com/containers/podman-tui
    // ========================================================================

    // ------------------------------------------------------------------------
    // COMPONENT: PodmanStyle - Color Palette and Theming (SC-HMI-043)
    // Comprehensive color scheme for container management UIs
    // ------------------------------------------------------------------------

    module PodmanStyle =
        /// ANSI color codes for terminal output
        type TermColor =
            | Default
            | Black | Red | Green | Yellow | Blue | Magenta | Cyan | White
            | BrightBlack | BrightRed | BrightGreen | BrightYellow
            | BrightBlue | BrightMagenta | BrightCyan | BrightWhite
            | RGB of r:int * g:int * b:int

        /// Color palette matching podman-tui style
        let palette = {|
            Foreground = RGB(255, 250, 240)
            Background = RGB(28, 28, 28)
            Border = RGB(135, 135, 175)
            Running = RGB(95, 215, 0)
            Paused = RGB(255, 175, 0)
            Stopped = RGB(128, 128, 128)
            Created = RGB(95, 175, 255)
            Exited = RGB(215, 95, 95)
            Dead = RGB(215, 0, 0)
            MenuHeader = RGB(175, 135, 255)
            Dialog = RGB(38, 38, 38)
            Error = RGB(215, 0, 0)
            Warning = RGB(255, 175, 0)
            Success = RGB(95, 215, 0)
            Info = RGB(95, 175, 255)
            Terminal = RGB(5, 5, 5)
            ProgressBg = RGB(105, 105, 105)
            ProgressOk = RGB(0, 128, 0)
            ProgressWarn = RGB(255, 165, 0)
            ProgressCrit = RGB(255, 0, 0)
        |}

        /// Status symbols
        let symbols = {|
            CheckMark = "✔"
            CrossMark = "✘"
            ProgressCell = "█"
            Running = "▶"
            Paused = "⏸"
            Stopped = "■"
            Created = "○"
            Warning = "⚠"
            Error = "✖"
            Info = "ℹ"
            Container = "⬡"
            Pod = "⬢"
            Image = "📦"
            Volume = "💾"
            Network = "🔗"
            Secret = "🔐"
        |}

        let rgbToAnsi (r, g, b) = sprintf "\x1b[38;2;%d;%d;%dm" r g b
        let resetAnsi = "\x1b[0m"

    // ------------------------------------------------------------------------
    // COMPONENT: InfoBar - System Information Display (SC-HMI-044)
    // ------------------------------------------------------------------------

    module InfoBar =
        type ConnectionStatus =
            | Connected of host:string
            | Disconnected
            | Connecting
            | ConnectionError of message:string

        type SystemInfo = {
            Hostname: string
            OSType: string
            KernelVersion: string
            PodmanVersion: string
            OCIRuntime: string
            Buildah: string
        }

        type ResourceUsage = {
            MemoryUsed: float
            MemoryTotal: string
            SwapUsed: float
            SwapTotal: string
        }

        type InfoBarState = {
            ConnectionStatus: ConnectionStatus
            SystemInfo: SystemInfo option
            ResourceUsage: ResourceUsage option
            Width: int
        }

        let create width = {
            ConnectionStatus = Disconnected
            SystemInfo = None
            ResourceUsage = None
            Width = width
        }

        let formatConnectionStatus status =
            match status with
            | Connected host -> sprintf "%s Connected: %s" PodmanStyle.symbols.CheckMark host
            | Disconnected -> sprintf "%s Disconnected" PodmanStyle.symbols.CrossMark
            | Connecting -> "⟳ Connecting..."
            | ConnectionError msg -> sprintf "%s Error: %s" PodmanStyle.symbols.Error msg

        let render (state: InfoBarState) =
            let width = state.Width
            let border = String.replicate (width - 2) "─"
            let padLine text =
                let content = if String.length text > width - 4 then text.Substring(0, width - 7) + "..." else text
                sprintf "│ %-*s │" (width - 4) content

            let connLine = formatConnectionStatus state.ConnectionStatus |> padLine
            let sysLines =
                match state.SystemInfo with
                | Some sys -> [sprintf "Host: %s  OS: %s  Kernel: %s" sys.Hostname sys.OSType sys.KernelVersion |> padLine]
                | None -> ["System info unavailable" |> padLine]

            [sprintf "┌%s┐" border; connLine] @ sysLines @ [sprintf "└%s┘" border]

    // ------------------------------------------------------------------------
    // COMPONENT: CommandDialog - Command Execution Interface (SC-HMI-045)
    // ------------------------------------------------------------------------

    module CommandDialog =
        type CommandState = Idle | CommandRunning of cmd:string | Completed of exitCode:int | CommandFailed of error:string

        type CommandDialogConfig = {
            Title: string
            Command: string
            Width: int
            Height: int
            OutputLines: string list
            State: CommandState
        }

        let create title command width height = {
            Title = title
            Command = command
            Width = width
            Height = height
            OutputLines = []
            State = Idle
        }

        let render (config: CommandDialogConfig) =
            let width = config.Width
            let innerWidth = width - 4
            let stateIcon =
                match config.State with
                | Idle -> "○"
                | CommandRunning _ -> "◉"
                | Completed code -> if code = 0 then "✔" else "✘"
                | CommandFailed _ -> "✖"
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let cmdLine = sprintf "│ %s $ %-*s│" stateIcon (innerWidth - 5) config.Command
            let outputLines = config.OutputLines |> List.truncate (config.Height - 4) |> List.map (fun l -> sprintf "│ %-*s │" innerWidth (if String.length l > innerWidth then l.Substring(0, innerWidth - 3) + "..." else l))
            [topBorder; cmdLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ outputLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: ConfirmDialog - Yes/No Confirmation (SC-HMI-046)
    // ------------------------------------------------------------------------

    module ConfirmDialog =
        type ConfirmDialogConfig = {
            Title: string
            Message: string list
            YesLabel: string
            NoLabel: string
            Width: int
            IsArmed: bool
            SelectedButton: int
        }

        let create title message = { Title = title; Message = message; YesLabel = "Yes"; NoLabel = "No"; Width = 50; IsArmed = false; SelectedButton = 1 }

        let render (config: ConfirmDialogConfig) =
            let width = config.Width
            let innerWidth = width - 4
            let topBorder = sprintf "╭─ %s %s╮" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let messageLines = config.Message |> List.map (fun line -> sprintf "│ %-*s │" innerWidth line)
            let yesBtn = if config.SelectedButton = 0 then sprintf "[%s]" config.YesLabel else sprintf " %s " config.YesLabel
            let noBtn = if config.SelectedButton = 1 then sprintf "[%s]" config.NoLabel else sprintf " %s " config.NoLabel
            let armedInd = if config.IsArmed then " ◎ ARMED " else ""
            let buttonLine = sprintf "│%s%s  %s%-*s│" armedInd yesBtn noBtn (max 0 (innerWidth - String.length yesBtn - String.length noBtn - String.length armedInd - 2)) ""
            [topBorder] @ messageLines @ [sprintf "├%s┤" (String.replicate (width - 2) "─"); buttonLine; sprintf "╰%s╯" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: ErrorDialog - Error Message Display (SC-HMI-047)
    // ------------------------------------------------------------------------

    module ErrorDialog =
        type ErrorSeverity = Info | Warning | ErrorLevel | Critical

        type ErrorDialogConfig = {
            Severity: ErrorSeverity
            Title: string
            Message: string list
            StackTrace: string list option
            Width: int
        }

        let create severity title message = { Severity = severity; Title = title; Message = message; StackTrace = None; Width = 60 }
        let severityIcon = function Info -> "ℹ" | Warning -> "⚠" | ErrorLevel -> "✖" | Critical -> "☢"

        let render (config: ErrorDialogConfig) =
            let width = config.Width
            let innerWidth = width - 4
            let icon = severityIcon config.Severity
            let topBorder = sprintf "╭─ %s %s %s╮" icon config.Title (String.replicate (max 0 (width - String.length config.Title - 7)) "─")
            let messageLines = config.Message |> List.map (fun l -> sprintf "│ %-*s │" innerWidth (if String.length l > innerWidth then l.Substring(0, innerWidth - 3) + "..." else l))
            [topBorder] @ messageLines @ [sprintf "╰%s╯" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: ProgressDialog - Progress Indicators (SC-HMI-048)
    // ------------------------------------------------------------------------

    module ProgressDialog =
        type ProgressStage = { Name: string; Status: string; Progress: float option }

        type ProgressDialogConfig = {
            Title: string
            Stages: ProgressStage list
            CurrentStage: int
            OverallProgress: float
            Width: int
        }

        let create title stages = { Title = title; Stages = stages; CurrentStage = 0; OverallProgress = 0.0; Width = 60 }
        let stageIcon status = match status with "completed" -> "✔" | "running" -> "◉" | "failed" -> "✖" | _ -> "○"

        let render (config: ProgressDialogConfig) =
            let width = config.Width
            let innerWidth = width - 4
            let barWidth = innerWidth - 10
            let topBorder = sprintf "╭─ %s %s╮" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let overallBar = Primitives.progressBar barWidth config.OverallProgress '█' '░'
            let overallLine = sprintf "│ [%s] %5.1f%% │" overallBar (config.OverallProgress * 100.0)
            let stageLines = config.Stages |> List.mapi (fun i stage -> sprintf "│ %s %s %-*s │" (if i = config.CurrentStage then "→" else " ") (stageIcon stage.Status) (innerWidth - 6) stage.Name)
            [topBorder; overallLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ stageLines @ [sprintf "╰%s╯" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: ContainerView - Container Management UI (SC-HMI-050)
    // ------------------------------------------------------------------------

    module ContainerView =
        type ContainerStatus = Running | Paused | Exited | Created | Dead | Removing

        type Container = {
            Id: string
            Name: string
            Image: string
            Status: ContainerStatus
            Ports: string list
        }

        type ContainerViewConfig = {
            Title: string
            Containers: Container list
            SelectedIndex: int
            Width: int
        }

        let statusIcon = function Running -> "▶" | Paused -> "⏸" | Exited -> "■" | Created -> "○" | Dead -> "✖" | Removing -> "⟳"

        let render (config: ContainerViewConfig) =
            let width = config.Width
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let headerLine = sprintf "│ %-12s %-20s %-20s %-8s │" "ID" "NAME" "IMAGE" "STATUS"
            let containerLines = config.Containers |> List.mapi (fun i c ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let shortId = if String.length c.Id > 12 then c.Id.Substring(0, 12) else c.Id
                let shortName = if String.length c.Name > 20 then c.Name.Substring(0, 17) + "..." else c.Name
                let shortImage = if String.length c.Image > 20 then c.Image.Substring(0, 17) + "..." else c.Image
                sprintf "│%s%s %-12s %-20s %-20s │" sel (statusIcon c.Status) shortId shortName shortImage)
            [topBorder; headerLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ containerLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: PodView - Pod Management UI (SC-HMI-051)
    // ------------------------------------------------------------------------

    module PodView =
        type PodStatus = PodRunning | Degraded | PodStopped | PodCreated | PodDead

        type Pod = {
            Id: string
            Name: string
            Status: PodStatus
            ContainerCount: int
        }

        type PodViewConfig = {
            Title: string
            Pods: Pod list
            SelectedIndex: int
            Width: int
        }

        let podStatusIcon = function PodRunning -> "⬢" | Degraded -> "⬡" | PodStopped -> "○" | PodCreated -> "◇" | PodDead -> "✖"

        let render (config: PodViewConfig) =
            let width = config.Width
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let headerLine = sprintf "│ %-12s %-25s %-8s %-10s │" "ID" "NAME" "STATUS" "CONTAINERS"
            let podLines = config.Pods |> List.mapi (fun i pod ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let shortId = if String.length pod.Id > 12 then pod.Id.Substring(0, 12) else pod.Id
                sprintf "│%s%s %-12s %-25s %-10d │" sel (podStatusIcon pod.Status) shortId pod.Name pod.ContainerCount)
            [topBorder; headerLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ podLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: VolumeView - Volume Management UI (SC-HMI-052)
    // ------------------------------------------------------------------------

    module VolumeView =
        type Volume = { Name: string; Driver: string; MountPoint: string; InUse: bool }

        type VolumeViewConfig = { Title: string; Volumes: Volume list; SelectedIndex: int; Width: int }

        let render (config: VolumeViewConfig) =
            let width = config.Width
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let headerLine = sprintf "│ %-20s %-10s %-6s │" "NAME" "DRIVER" "IN USE"
            let volumeLines = config.Volumes |> List.mapi (fun i vol ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let inUseIcon = if vol.InUse then "●" else "○"
                sprintf "│%s %-20s %-10s %-6s │" sel (if String.length vol.Name > 20 then vol.Name.Substring(0, 17) + "..." else vol.Name) vol.Driver inUseIcon)
            [topBorder; headerLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ volumeLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: ImageView - Container Image Browser (SC-HMI-053)
    // ------------------------------------------------------------------------

    module ImageView =
        type Image = { Id: string; Repository: string; Tag: string; Size: string }

        type ImageViewConfig = { Title: string; Images: Image list; SelectedIndex: int; Width: int }

        let render (config: ImageViewConfig) =
            let width = config.Width
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let headerLine = sprintf "│ %-30s %-15s %-10s │" "REPOSITORY:TAG" "IMAGE ID" "SIZE"
            let imageLines = config.Images |> List.mapi (fun i img ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let repoTag = sprintf "%s:%s" img.Repository img.Tag
                let shortRepoTag = if String.length repoTag > 30 then repoTag.Substring(0, 27) + "..." else repoTag
                let shortId = if String.length img.Id > 15 then img.Id.Substring(0, 12) else img.Id
                sprintf "│%s %-30s %-15s %-10s │" sel shortRepoTag shortId img.Size)
            [topBorder; headerLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ imageLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: NetworkView - Network Configuration UI (SC-HMI-054)
    // ------------------------------------------------------------------------

    module NetworkView =
        type Network = { Name: string; Id: string; Driver: string; Subnet: string option }

        type NetworkViewConfig = { Title: string; Networks: Network list; SelectedIndex: int; Width: int }

        let render (config: NetworkViewConfig) =
            let width = config.Width
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let headerLine = sprintf "│ %-20s %-10s %-18s │" "NAME" "DRIVER" "SUBNET"
            let networkLines = config.Networks |> List.mapi (fun i net ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let subnet = net.Subnet |> Option.defaultValue "-"
                sprintf "│%s %-20s %-10s %-18s │" sel (if String.length net.Name > 20 then net.Name.Substring(0, 17) + "..." else net.Name) net.Driver subnet)
            [topBorder; headerLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ networkLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: SecretsView - Secrets Management UI (SC-HMI-055)
    // ------------------------------------------------------------------------

    module SecretsView =
        type Secret = { Name: string; Id: string; Driver: string; Created: System.DateTime }

        type SecretsViewConfig = { Title: string; Secrets: Secret list; SelectedIndex: int; Width: int }

        let render (config: SecretsViewConfig) =
            let width = config.Width
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let headerLine = sprintf "│ %-20s %-15s %-10s %-15s │" "NAME" "ID" "DRIVER" "CREATED"
            let secretLines = config.Secrets |> List.mapi (fun i secret ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let shortId = if String.length secret.Id > 15 then secret.Id.Substring(0, 12) else secret.Id
                sprintf "│%s %-20s %-15s %-10s %-15s │" sel (if String.length secret.Name > 20 then secret.Name.Substring(0, 17) + "..." else secret.Name) shortId secret.Driver (secret.Created.ToString("yyyy-MM-dd")))
            [topBorder; headerLine; sprintf "├%s┤" (String.replicate (width - 2) "─")] @ secretLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: SystemView - System Status Overview (SC-HMI-056)
    // ------------------------------------------------------------------------

    module SystemView =
        type SystemStats = { ContainersRunning: int; ContainersTotal: int; Images: int; Volumes: int; Networks: int; PodsRunning: int; PodsTotal: int }

        type SystemViewConfig = { Title: string; Stats: SystemStats; Width: int }

        let render (config: SystemViewConfig) =
            let width = config.Width
            let innerWidth = width - 4
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let statsLines = [
                sprintf "│ %-*s │" innerWidth "Resource Summary"
                sprintf "│   Containers: %d running / %d total%-*s│" config.Stats.ContainersRunning config.Stats.ContainersTotal (max 0 (innerWidth - 35)) ""
                sprintf "│   Pods:       %d running / %d total%-*s│" config.Stats.PodsRunning config.Stats.PodsTotal (max 0 (innerWidth - 35)) ""
                sprintf "│   Images:     %-*d│" (innerWidth - 15) config.Stats.Images
                sprintf "│   Volumes:    %-*d│" (innerWidth - 15) config.Stats.Volumes
                sprintf "│   Networks:   %-*d│" (innerWidth - 15) config.Stats.Networks
            ]
            [topBorder] @ statsLines @ [sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ------------------------------------------------------------------------
    // COMPONENT: FunctionKeyBar - Function Key Menu Bar (SC-HMI-058)
    // ------------------------------------------------------------------------

    module FunctionKeyBar =
        type FunctionKey = { Key: string; Label: string; Enabled: bool }

        type FunctionKeyBarConfig = { Keys: FunctionKey list; Width: int }

        let render (config: FunctionKeyBarConfig) =
            let keyPairs = config.Keys |> List.filter (fun k -> k.Enabled) |> List.map (fun k -> sprintf "%s:%s" k.Key k.Label)
            let content = String.concat "  " keyPairs
            content + String.replicate (max 0 (config.Width - String.length content)) " "

        let standardKeys = [
            { Key = "F2"; Label = "System"; Enabled = true }
            { Key = "F3"; Label = "Pods"; Enabled = true }
            { Key = "F4"; Label = "Containers"; Enabled = true }
            { Key = "F5"; Label = "Volumes"; Enabled = true }
            { Key = "F6"; Label = "Images"; Enabled = true }
            { Key = "F7"; Label = "Networks"; Enabled = true }
            { Key = "F8"; Label = "Secrets"; Enabled = true }
            { Key = "F10"; Label = "Quit"; Enabled = true }
        ]

    // ------------------------------------------------------------------------
    // COMPONENT: CommandMenu - Slide-out Command Menu (SC-HMI-059)
    // ------------------------------------------------------------------------

    module CommandMenu =
        type MenuItem = { Key: string; Label: string; Shortcut: string option; Enabled: bool; Dangerous: bool }

        type CommandMenuConfig = { Title: string; Items: MenuItem list; SelectedIndex: int; Width: int; Visible: bool }

        let create title items = { Title = title; Items = items; SelectedIndex = 0; Width = 30; Visible = false }

        let render (config: CommandMenuConfig) =
            if not config.Visible then []
            else
                let width = config.Width
                let innerWidth = width - 4
                let topBorder = sprintf "╭─ %s %s╮" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
                let itemLines = config.Items |> List.mapi (fun i item ->
                    let sel = if i = config.SelectedIndex then ">" else " "
                    let shortcut = item.Shortcut |> Option.map (fun s -> sprintf " (%s)" s) |> Option.defaultValue ""
                    let dangerMark = if item.Dangerous then "!" else " "
                    sprintf "│%s%s %-*s│" sel dangerMark (innerWidth - 2) (item.Label + shortcut))
                [topBorder] @ itemLines @ [sprintf "╰%s╯" (String.replicate (width - 2) "─")]

        let containerCommands = [
            { Key = "start"; Label = "Start"; Shortcut = Some "s"; Enabled = true; Dangerous = false }
            { Key = "stop"; Label = "Stop"; Shortcut = Some "S"; Enabled = true; Dangerous = false }
            { Key = "restart"; Label = "Restart"; Shortcut = Some "r"; Enabled = true; Dangerous = false }
            { Key = "pause"; Label = "Pause"; Shortcut = Some "p"; Enabled = true; Dangerous = false }
            { Key = "unpause"; Label = "Unpause"; Shortcut = Some "P"; Enabled = true; Dangerous = false }
            { Key = "kill"; Label = "Kill"; Shortcut = Some "k"; Enabled = true; Dangerous = true }
            { Key = "remove"; Label = "Remove"; Shortcut = Some "d"; Enabled = true; Dangerous = true }
            { Key = "logs"; Label = "View Logs"; Shortcut = Some "l"; Enabled = true; Dangerous = false }
            { Key = "exec"; Label = "Exec Shell"; Shortcut = Some "e"; Enabled = true; Dangerous = false }
            { Key = "inspect"; Label = "Inspect"; Shortcut = Some "i"; Enabled = true; Dangerous = false }
        ]

    // ------------------------------------------------------------------------
    // COMPONENT: PodmanLogViewer - Container Log Display (SC-HMI-060)
    // Inspired by podman-tui log viewer with follow-tail and filtering
    // ------------------------------------------------------------------------

    module PodmanLogViewer =
        type LogLevel = Debug | LogInfo | LogWarning | LogError | Fatal

        type LogEntry = { Timestamp: System.DateTime; Level: LogLevel option; Source: string option; Message: string }

        type LogViewerConfig = {
            Title: string
            Entries: LogEntry list
            Filter: string option
            FollowTail: bool
            ScrollOffset: int
            Width: int
            Height: int
        }

        let create title width height = { Title = title; Entries = []; Filter = None; FollowTail = true; ScrollOffset = 0; Width = width; Height = height }
        let levelIndicator = function Some Debug -> "D" | Some LogInfo -> "I" | Some LogWarning -> "W" | Some LogError -> "E" | Some Fatal -> "F" | None -> " "

        let render (config: LogViewerConfig) =
            let width = config.Width
            let height = config.Height
            let innerWidth = width - 4
            let contentHeight = height - 4
            let topBorder = sprintf "┌─ %s %s┐" config.Title (String.replicate (max 0 (width - String.length config.Title - 5)) "─")
            let filteredEntries = config.Entries |> List.filter (fun e -> match config.Filter with Some f -> e.Message.Contains(f) | None -> true)
            let visibleEntries = if config.FollowTail then filteredEntries |> List.rev |> List.truncate contentHeight |> List.rev else filteredEntries |> List.skip config.ScrollOffset |> List.truncate contentHeight
            let logLines = visibleEntries |> List.map (fun entry ->
                let level = levelIndicator entry.Level
                let timeStr = entry.Timestamp.ToString("HH:mm:ss.fff")
                let content = sprintf "%s %s %s" timeStr level entry.Message
                sprintf "│ %-*s │" innerWidth (if String.length content > innerWidth then content.Substring(0, innerWidth - 3) + "..." else content))
            let emptyLines = List.init (max 0 (contentHeight - List.length logLines)) (fun _ -> sprintf "│%s│" (String.replicate (width - 2) " "))
            let tailIcon = if config.FollowTail then "◉" else "○"
            let statusLine = sprintf "│ %s Tail%-*s│" tailIcon (innerWidth - 7) ""
            [topBorder] @ logLines @ emptyLines @ [sprintf "├%s┤" (String.replicate (width - 2) "─"); statusLine; sprintf "└%s┘" (String.replicate (width - 2) "─")]

    // ========================================================================
    // PROXMOX VE INTEGRATION COMPONENTS (SC-HMI-061 to SC-HMI-080)
    // Full integration with Proxmox Virtual Environment
    // Commands: pvecm, qm, pct, pvesm, vzdump, ha-manager, pveum, pve-firewall
    // ========================================================================

    // ------------------------------------------------------------------------
    // COMPONENT: ProxmoxStyle - Color Palette & Symbols (SC-HMI-061)
    // Proxmox VE branding and visual language
    // ------------------------------------------------------------------------

    module ProxmoxStyle =
        type RGB = { R: int; G: int; B: int }
        let rgb r g b = { R = r; G = g; B = b }

        let palette = {|
            // Proxmox brand colors
            Primary = rgb 230 111 35         // Proxmox orange
            Secondary = rgb 52 73 94         // Dark blue-gray
            Background = rgb 30 30 30        // Near black
            Surface = rgb 45 45 45           // Dark gray surface
            Border = rgb 68 68 68            // Border gray

            // Status colors
            Running = rgb 92 184 92          // Green
            Stopped = rgb 217 83 79          // Red
            Paused = rgb 240 173 78          // Amber/Yellow
            Template = rgb 91 192 222        // Cyan/Info
            Unknown = rgb 128 128 128        // Gray

            // Resource types
            Qemu = rgb 0 150 136             // Teal for VMs
            Lxc = rgb 156 39 176             // Purple for containers
            Node = rgb 33 150 243            // Blue for nodes
            Storage = rgb 255 152 0          // Orange for storage
            Pool = rgb 103 58 183            // Deep purple for pools

            // Health indicators
            Healthy = rgb 76 175 80          // Green
            Warning = rgb 255 193 7          // Yellow
            Critical = rgb 244 67 54         // Red
            Offline = rgb 158 158 158        // Gray
        |}

        let symbols = {|
            // Resource types
            VM = "🖥"
            Container = "📦"
            Node = "🖧"
            Storage = "💾"
            Network = "🔗"
            Pool = "📁"
            Cluster = "☁"
            Backup = "💿"
            Snapshot = "📸"
            Template = "📋"
            ISO = "💿"

            // Status
            Running = "▶"
            Stopped = "⏹"
            Paused = "⏸"
            Starting = "⏳"
            Stopping = "⏳"
            Migrating = "↔"
            Locked = "🔒"
            HA = "♥"

            // Actions
            Start = "▶"
            Stop = "⏹"
            Restart = "↻"
            Migrate = "↔"
            Clone = "⧉"
            BackupAction = "⤓"
            Restore = "⤒"
            Delete = "✖"
            Console = "⌨"
            SnapshotAction = "📷"

            // Metrics
            CPU = "⚡"
            Memory = "🧠"
            Disk = "💽"
            NetworkMetric = "📶"
            Uptime = "⏱"
        |}

        let ansi (c: RGB) = sprintf "\u001b[38;2;%d;%d;%dm" c.R c.G c.B
        let ansiBg (c: RGB) = sprintf "\u001b[48;2;%d;%d;%dm" c.R c.G c.B
        let reset = "\u001b[0m"

    // ------------------------------------------------------------------------
    // COMPONENT: ClusterView - Cluster Status Dashboard (SC-HMI-062)
    // pvecm status, pvecm nodes visualization
    // ------------------------------------------------------------------------

    module ClusterView =
        type ClusterHealth = Healthy | Degraded | Critical | NoQuorum

        type NodeInfo = {
            Name: string
            Id: int
            Online: bool
            Votes: int
            Local: bool
            IP: string
            CPU: float
            Memory: float
            Uptime: string
        }

        type ClusterConfig = {
            Name: string
            Health: ClusterHealth
            Version: int
            Nodes: NodeInfo list
            QuorumVotes: int
            ExpectedVotes: int
            TotalVotes: int
            HasQDevice: bool
            Width: int
        }

        let create name = {
            Name = name
            Health = Healthy
            Version = 1
            Nodes = []
            QuorumVotes = 0
            ExpectedVotes = 0
            TotalVotes = 0
            HasQDevice = false
            Width = 80
        }

        let healthIcon = function
            | Healthy -> "●"
            | Degraded -> "◐"
            | Critical -> "○"
            | NoQuorum -> "⊘"

        let healthColor = function
            | Healthy -> ProxmoxStyle.ansi ProxmoxStyle.palette.Healthy
            | Degraded -> ProxmoxStyle.ansi ProxmoxStyle.palette.Warning
            | Critical -> ProxmoxStyle.ansi ProxmoxStyle.palette.Critical
            | NoQuorum -> ProxmoxStyle.ansi ProxmoxStyle.palette.Critical

        let render (config: ClusterConfig) =
            let width = config.Width
            let innerWidth = width - 4
            let quorumStatus = if config.TotalVotes >= config.QuorumVotes then "✓ Quorate" else "✗ No Quorum"
            let qdevice = if config.HasQDevice then " +QDevice" else ""

            let header = sprintf "┌─ ☁ CLUSTER: %s %s┐" config.Name (String.replicate (max 0 (width - 16 - String.length config.Name)) "─")
            let statusLine = sprintf "│ %s%s %s%s │ Votes: %d/%d │ %s%s │"
                                (healthColor config.Health) (healthIcon config.Health)
                                (match config.Health with Healthy -> "HEALTHY" | Degraded -> "DEGRADED" | Critical -> "CRITICAL" | NoQuorum -> "NO QUORUM")
                                ProxmoxStyle.reset config.TotalVotes config.ExpectedVotes quorumStatus qdevice

            let nodeHeader = sprintf "│  %-12s %-6s %-8s %-6s %-8s %-8s %-10s │" "NODE" "ID" "STATUS" "VOTES" "CPU" "MEM" "UPTIME"
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let nodeLines = config.Nodes |> List.map (fun n ->
                let status = if n.Online then sprintf "%s● Online%s" (ProxmoxStyle.ansi ProxmoxStyle.palette.Running) ProxmoxStyle.reset
                             else sprintf "%s○ Offline%s" (ProxmoxStyle.ansi ProxmoxStyle.palette.Stopped) ProxmoxStyle.reset
                let local = if n.Local then "*" else " "
                sprintf "│ %s%-11s %-6d %-8s %-6d %5.1f%%   %5.1f%%   %-10s │" local n.Name n.Id status n.Votes n.CPU n.Memory n.Uptime)

            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; statusLine; separator; nodeHeader; separator] @ nodeLines @ [footer]

    // ------------------------------------------------------------------------
    // COMPONENT: NodeView - Node Management (SC-HMI-063)
    // Individual node details and management
    // ------------------------------------------------------------------------

    module NodeView =
        type NodeStatus = Online | Offline | Maintenance | Unknown

        type ServiceStatus = { Name: string; Running: bool; Failed: bool }

        type NodeConfig = {
            Name: string
            Status: NodeStatus
            IP: string
            Kernel: string
            PveVersion: string
            CPU: float
            CPUCores: int
            Memory: float
            MemoryTotal: int64
            MemoryUsed: int64
            RootFS: float
            Swap: float
            Uptime: string
            LoadAvg: float * float * float
            Services: ServiceStatus list
            VMs: int
            Containers: int
            Width: int
        }

        let create name = {
            Name = name; Status = Online; IP = ""; Kernel = ""; PveVersion = ""
            CPU = 0.0; CPUCores = 0; Memory = 0.0; MemoryTotal = 0L; MemoryUsed = 0L
            RootFS = 0.0; Swap = 0.0; Uptime = ""; LoadAvg = (0.0, 0.0, 0.0)
            Services = []; VMs = 0; Containers = 0; Width = 80
        }

        let statusIcon = function Online -> "●" | Offline -> "○" | Maintenance -> "◐" | Unknown -> "?"
        let statusColor = function
            | Online -> ProxmoxStyle.ansi ProxmoxStyle.palette.Running
            | Offline -> ProxmoxStyle.ansi ProxmoxStyle.palette.Stopped
            | Maintenance -> ProxmoxStyle.ansi ProxmoxStyle.palette.Paused
            | Unknown -> ProxmoxStyle.ansi ProxmoxStyle.palette.Unknown

        let progressBar pct width =
            let filled = int (float width * pct / 100.0)
            let empty = width - filled
            sprintf "[%s%s] %5.1f%%" (String.replicate filled "█") (String.replicate empty "░") pct

        let render (config: NodeConfig) =
            let width = config.Width
            let header = sprintf "┌─ 🖧 NODE: %s %s┐" config.Name (String.replicate (max 0 (width - 13 - String.length config.Name)) "─")
            let status = sprintf "│ %s%s %s%s │ %s │ PVE %s │" (statusColor config.Status) (statusIcon config.Status)
                            (match config.Status with Online -> "ONLINE" | Offline -> "OFFLINE" | Maintenance -> "MAINT" | Unknown -> "UNKNOWN")
                            ProxmoxStyle.reset config.IP config.PveVersion

            let (l1, l5, l15) = config.LoadAvg
            let cpuLine = sprintf "│ ⚡ CPU:  %s │ Load: %.2f %.2f %.2f │" (progressBar config.CPU 25) l1 l5 l15
            let memLine = sprintf "│ 🧠 MEM:  %s │ %s/%s │" (progressBar config.Memory 25)
                            (sprintf "%.1fG" (float config.MemoryUsed / 1073741824.0))
                            (sprintf "%.1fG" (float config.MemoryTotal / 1073741824.0))
            let diskLine = sprintf "│ 💽 ROOT: %s │ SWAP: %5.1f%% │" (progressBar config.RootFS 25) config.Swap
            let guestLine = sprintf "│ 🖥 VMs: %-3d │ 📦 Containers: %-3d │ ⏱ Uptime: %s │" config.VMs config.Containers config.Uptime
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; status; sprintf "├%s┤" (String.replicate (width - 2) "─"); cpuLine; memLine; diskLine; guestLine; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: VMView - Virtual Machine Management (SC-HMI-064)
    // qm list, qm status, qm start/stop/migrate
    // ------------------------------------------------------------------------

    module VMView =
        type VMStatus = Running | Stopped | Paused | Suspended | Starting | Stopping | Migrating | Unknown

        type VMInfo = {
            VMID: int
            Name: string
            Status: VMStatus
            Node: string
            CPU: float
            CPUCores: int
            Memory: int64
            MemoryUsed: int64
            Disk: int64
            DiskUsed: int64
            Uptime: string
            HA: bool
            Template: bool
            Lock: string option
            Tags: string list
        }

        type VMViewConfig = {
            VMs: VMInfo list
            SelectedIndex: int
            SortBy: string
            FilterStatus: VMStatus option
            Width: int
            Height: int
        }

        let create () = { VMs = []; SelectedIndex = 0; SortBy = "vmid"; FilterStatus = None; Width = 100; Height = 20 }

        let statusIcon = function
            | Running -> "▶" | Stopped -> "⏹" | Paused -> "⏸" | Suspended -> "💤"
            | Starting -> "⏳" | Stopping -> "⏳" | Migrating -> "↔" | Unknown -> "?"

        let statusColor = function
            | Running -> ProxmoxStyle.ansi ProxmoxStyle.palette.Running
            | Stopped -> ProxmoxStyle.ansi ProxmoxStyle.palette.Stopped
            | Paused -> ProxmoxStyle.ansi ProxmoxStyle.palette.Paused
            | _ -> ProxmoxStyle.ansi ProxmoxStyle.palette.Unknown

        let render (config: VMViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 🖥 VIRTUAL MACHINES (%d) %s┐" (List.length config.VMs) (String.replicate (max 0 (width - 28)) "─")
            let colHeader = sprintf "│  %-6s %-20s %-10s %-8s %-6s %-10s %-12s %-6s │" "VMID" "NAME" "STATUS" "NODE" "CPU" "MEMORY" "DISK" "HA"
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let vmLines = config.VMs |> List.mapi (fun i vm ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let ha = if vm.HA then "♥" else " "
                let lock = match vm.Lock with Some l -> sprintf "🔒%s" l | None -> ""
                let memStr = sprintf "%dMB" (vm.MemoryUsed / 1048576L)
                let diskStr = sprintf "%dGB" (vm.DiskUsed / 1073741824L)
                sprintf "│%s %s%-5d%s %-20s %s%-10s%s %-8s %5.1f%% %-10s %-12s %s %s │"
                    sel (statusColor vm.Status) vm.VMID ProxmoxStyle.reset
                    (if String.length vm.Name > 20 then vm.Name.Substring(0, 17) + "..." else vm.Name)
                    (statusColor vm.Status) (sprintf "%s %s" (statusIcon vm.Status) (match vm.Status with Running -> "running" | Stopped -> "stopped" | Paused -> "paused" | _ -> "unknown"))
                    ProxmoxStyle.reset vm.Node vm.CPU memStr diskStr ha lock)

            let actionBar = sprintf "│ [s]tart [S]top [r]estart [m]igrate [c]lone [b]ackup [d]elete [Enter]console │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; colHeader; separator] @ vmLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: ContainerLxcView - LXC Container Management (SC-HMI-065)
    // pct list, pct status, pct start/stop/migrate
    // ------------------------------------------------------------------------

    module ContainerLxcView =
        type CTStatus = Running | Stopped | Mounted | Starting | Stopping | Unknown

        type CTInfo = {
            CTID: int
            Name: string
            Status: CTStatus
            Node: string
            CPU: float
            Memory: int64
            MemoryUsed: int64
            Swap: int64
            SwapUsed: int64
            Disk: int64
            DiskUsed: int64
            Uptime: string
            HA: bool
            Template: bool
            Unprivileged: bool
            Lock: string option
        }

        type CTViewConfig = {
            Containers: CTInfo list
            SelectedIndex: int
            Width: int
        }

        let create () = { Containers = []; SelectedIndex = 0; Width = 100 }

        let statusIcon = function Running -> "▶" | Stopped -> "⏹" | Mounted -> "📂" | Starting -> "⏳" | Stopping -> "⏳" | Unknown -> "?"

        let render (config: CTViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 📦 LXC CONTAINERS (%d) %s┐" (List.length config.Containers) (String.replicate (max 0 (width - 26)) "─")
            let colHeader = sprintf "│  %-6s %-20s %-10s %-8s %-6s %-10s %-10s %-4s │" "CTID" "NAME" "STATUS" "NODE" "CPU" "MEMORY" "DISK" "HA"
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let ctLines = config.Containers |> List.mapi (fun i ct ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let ha = if ct.HA then "♥" else " "
                let priv = if ct.Unprivileged then "U" else "P"
                sprintf "│%s %-6d %-20s %-10s %-8s %5.1f%% %-10s %-10s %s%s │"
                    sel ct.CTID ct.Name (sprintf "%s %s" (statusIcon ct.Status) (match ct.Status with Running -> "running" | Stopped -> "stopped" | _ -> "unknown"))
                    ct.Node ct.CPU (sprintf "%dMB" (ct.MemoryUsed / 1048576L)) (sprintf "%dGB" (ct.DiskUsed / 1073741824L)) ha priv)

            let actionBar = sprintf "│ [s]tart [S]top [r]eboot [m]igrate [c]lone [b]ackup [e]nter [d]elete │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; colHeader; separator] @ ctLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: StorageView - Storage Management (SC-HMI-066)
    // pvesm status, pvesm list, storage pools
    // ------------------------------------------------------------------------

    module StorageView =
        type StorageType = Dir | LVM | LVMThin | ZFS | ZFSPool | NFS | CIFS | ISCSI | Ceph | CephFS | PBS

        type StorageStatus = Active | Inactive | Unknown

        type StorageInfo = {
            Name: string
            Type: StorageType
            Status: StorageStatus
            Shared: bool
            Total: int64
            Used: int64
            Available: int64
            ContentTypes: string list
            Nodes: string list
        }

        type StorageViewConfig = {
            Storages: StorageInfo list
            SelectedIndex: int
            Width: int
        }

        let create () = { Storages = []; SelectedIndex = 0; Width = 90 }

        let typeIcon = function
            | Dir -> "📁" | LVM -> "▤" | LVMThin -> "▥" | ZFS -> "⬡" | ZFSPool -> "⬢"
            | NFS -> "🌐" | CIFS -> "🪟" | ISCSI -> "🔌" | Ceph -> "🔴" | CephFS -> "🔵" | PBS -> "💾"

        let typeName = function
            | Dir -> "dir" | LVM -> "lvm" | LVMThin -> "lvmthin" | ZFS -> "zfs" | ZFSPool -> "zfspool"
            | NFS -> "nfs" | CIFS -> "cifs" | ISCSI -> "iscsi" | Ceph -> "rbd" | CephFS -> "cephfs" | PBS -> "pbs"

        let render (config: StorageViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 💾 STORAGE POOLS (%d) %s┐" (List.length config.Storages) (String.replicate (max 0 (width - 25)) "─")
            let colHeader = sprintf "│  %-15s %-10s %-8s %-6s %-12s %-12s %-8s │" "NAME" "TYPE" "STATUS" "SHARED" "TOTAL" "USED" "AVAIL"
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let storageLines = config.Storages |> List.mapi (fun i s ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let status = match s.Status with Active -> "●active" | Inactive -> "○inactive" | Unknown -> "?unknown"
                let shared = if s.Shared then "yes" else "no"
                let pct = if s.Total > 0L then float s.Used / float s.Total * 100.0 else 0.0
                sprintf "│%s %s %-13s %-10s %-8s %-6s %10s %10s %7.1f%% │"
                    sel (typeIcon s.Type) s.Name (typeName s.Type) status shared
                    (sprintf "%.1fG" (float s.Total / 1073741824.0))
                    (sprintf "%.1fG" (float s.Used / 1073741824.0)) pct)

            let actionBar = sprintf "│ [a]dd [r]emove [s]can [e]dit [c]ontent [p]rune │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; colHeader; separator] @ storageLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: BackupView - Backup Management (SC-HMI-067)
    // vzdump, backup jobs, restore
    // ------------------------------------------------------------------------

    module BackupView =
        type BackupMode = Snapshot | Stop | Suspend

        type BackupStatus = Running | Completed | Failed | Scheduled | Queued

        type BackupInfo = {
            ID: string
            VMID: int
            Node: string
            Storage: string
            Mode: BackupMode
            Status: BackupStatus
            Size: int64
            StartTime: System.DateTime
            EndTime: System.DateTime option
            Compression: string
            Protected: bool
            Notes: string
        }

        type BackupJobInfo = {
            ID: string
            Schedule: string
            Storage: string
            Mode: BackupMode
            VMIDs: int list
            Enabled: bool
            Retention: string
            NextRun: System.DateTime option
        }

        type BackupViewConfig = {
            Backups: BackupInfo list
            Jobs: BackupJobInfo list
            ActiveTab: int  // 0=Backups, 1=Jobs
            SelectedIndex: int
            Width: int
        }

        let create () = { Backups = []; Jobs = []; ActiveTab = 0; SelectedIndex = 0; Width = 100 }

        let statusIcon = function
            | Running -> "⏳" | Completed -> "✓" | Failed -> "✗" | Scheduled -> "⏰" | Queued -> "⋯"

        let modeStr = function Snapshot -> "snapshot" | Stop -> "stop" | Suspend -> "suspend"

        let render (config: BackupViewConfig) =
            let width = config.Width
            let tabs = sprintf "│ [%s Backups ] [%s Jobs ] │" (if config.ActiveTab = 0 then "●" else "○") (if config.ActiveTab = 1 then "●" else "○")
            let header = sprintf "┌─ 💿 BACKUP MANAGER %s┐" (String.replicate (max 0 (width - 22)) "─")

            let content =
                match config.ActiveTab with
                | 0 ->
                    let colHeader = sprintf "│  %-20s %-6s %-10s %-10s %-10s %-10s %-4s │" "BACKUP" "VMID" "NODE" "STATUS" "SIZE" "DATE" "🔒"
                    let backupLines = config.Backups |> List.mapi (fun i b ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let prot = if b.Protected then "🔒" else " "
                        sprintf "│%s %-20s %-6d %-10s %s%-10s%s %-10s %-10s %s │"
                            sel (if String.length b.ID > 20 then b.ID.Substring(0, 17) + "..." else b.ID)
                            b.VMID b.Node
                            (if b.Status = Failed then ProxmoxStyle.ansi ProxmoxStyle.palette.Critical else "")
                            (sprintf "%s %s" (statusIcon b.Status) (match b.Status with Completed -> "OK" | Failed -> "FAIL" | Running -> "RUN" | _ -> ""))
                            ProxmoxStyle.reset
                            (sprintf "%.1fG" (float b.Size / 1073741824.0))
                            (b.StartTime.ToString("yyyy-MM-dd")) prot)
                    [colHeader] @ backupLines
                | _ ->
                    let colHeader = sprintf "│  %-15s %-15s %-10s %-10s %-8s %-15s │" "JOB ID" "SCHEDULE" "STORAGE" "MODE" "ENABLED" "NEXT RUN"
                    let jobLines = config.Jobs |> List.mapi (fun i j ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let enabled = if j.Enabled then "✓ yes" else "✗ no"
                        let nextRun = match j.NextRun with Some dt -> dt.ToString("MM-dd HH:mm") | None -> "-"
                        sprintf "│%s %-15s %-15s %-10s %-10s %-8s %-15s │" sel j.ID j.Schedule j.Storage (modeStr j.Mode) enabled nextRun)
                    [colHeader] @ jobLines

            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")
            let actionBar = sprintf "│ [b]ackup now [r]estore [d]elete [p]rotect [e]dit job [n]ew job │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; tabs; separator] @ content @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: HAView - High Availability Management (SC-HMI-068)
    // ha-manager status, resources, groups
    // ------------------------------------------------------------------------

    module HAView =
        type HAState = Started | Stopped | Disabled | Ignored | Migrate | Error | Fence | Freeze | Queued | Recovery

        type HAResource = {
            SID: string
            Type: string
            VMID: int
            State: HAState
            Node: string
            RequestState: HAState
            MaxRestart: int
            MaxRelocate: int
            Group: string option
            Failback: bool
        }

        type HAGroup = {
            Name: string
            Nodes: (string * int) list  // (node, priority)
            Restricted: bool
            NoFailback: bool
        }

        type HAViewConfig = {
            Resources: HAResource list
            Groups: HAGroup list
            CRMStatus: string
            LRMStatus: string
            ActiveTab: int
            SelectedIndex: int
            Width: int
        }

        let create () = { Resources = []; Groups = []; CRMStatus = ""; LRMStatus = ""; ActiveTab = 0; SelectedIndex = 0; Width = 90 }

        let stateIcon = function
            | Started -> "▶" | Stopped -> "⏹" | Disabled -> "⊘" | Ignored -> "○"
            | Migrate -> "↔" | Error -> "✗" | Fence -> "⚠" | Freeze -> "❄" | Queued -> "⋯" | Recovery -> "↻"

        let stateColor = function
            | Started -> ProxmoxStyle.ansi ProxmoxStyle.palette.Running
            | Stopped -> ProxmoxStyle.ansi ProxmoxStyle.palette.Stopped
            | Error | Fence -> ProxmoxStyle.ansi ProxmoxStyle.palette.Critical
            | Migrate | Recovery -> ProxmoxStyle.ansi ProxmoxStyle.palette.Paused
            | _ -> ""

        let render (config: HAViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ ♥ HIGH AVAILABILITY %s┐" (String.replicate (max 0 (width - 25)) "─")
            let statusLine = sprintf "│ CRM: %s │ LRM: %s │" config.CRMStatus config.LRMStatus
            let tabs = sprintf "│ [%s Resources ] [%s Groups ] │" (if config.ActiveTab = 0 then "●" else "○") (if config.ActiveTab = 1 then "●" else "○")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let content =
                match config.ActiveTab with
                | 0 ->
                    let colHeader = sprintf "│  %-15s %-6s %-10s %-10s %-10s %-5s %-5s │" "SID" "VMID" "STATE" "REQUEST" "NODE" "RST" "REL"
                    let resLines = config.Resources |> List.mapi (fun i r ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-15s %-6d %s%-10s%s %-10s %-10s %-5d %-5d │"
                            sel r.SID r.VMID (stateColor r.State) (sprintf "%s %s" (stateIcon r.State) (match r.State with Started -> "started" | Stopped -> "stopped" | Error -> "error" | _ -> ""))
                            ProxmoxStyle.reset (match r.RequestState with Started -> "started" | Stopped -> "stopped" | _ -> "") r.Node r.MaxRestart r.MaxRelocate)
                    [colHeader] @ resLines
                | _ ->
                    let colHeader = sprintf "│  %-15s %-30s %-10s %-10s │" "GROUP" "NODES" "RESTRICTED" "NOFAILBACK"
                    let groupLines = config.Groups |> List.mapi (fun i g ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let nodes = g.Nodes |> List.map (fun (n, p) -> sprintf "%s:%d" n p) |> String.concat ","
                        sprintf "│%s %-15s %-30s %-10s %-10s │" sel g.Name nodes (if g.Restricted then "yes" else "no") (if g.NoFailback then "yes" else "no"))
                    [colHeader] @ groupLines

            let actionBar = sprintf "│ [a]dd [r]emove [m]igrate [e]nable [d]isable [s]et state │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; statusLine; tabs; separator] @ content @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: FirewallView - Firewall Management (SC-HMI-069)
    // pve-firewall, cluster/host/VM rules
    // ------------------------------------------------------------------------

    module FirewallView =
        type FirewallLevel = Cluster | Node of string | VM of int | Container of int

        type RuleDirection = In | Out | Forward
        type RuleAction = Accept | Drop | Reject

        type FirewallRule = {
            Pos: int
            Enabled: bool
            Direction: RuleDirection
            Action: RuleAction
            Macro: string option
            Source: string option
            Dest: string option
            Protocol: string option
            DPort: string option
            SPort: string option
            Comment: string option
        }

        type SecurityGroup = {
            Name: string
            Comment: string option
            Rules: FirewallRule list
        }

        type IPSet = {
            Name: string
            Comment: string option
            Entries: string list
        }

        type FirewallViewConfig = {
            Level: FirewallLevel
            Enabled: bool
            PolicyIn: RuleAction
            PolicyOut: RuleAction
            Rules: FirewallRule list
            SecurityGroups: SecurityGroup list
            IPSets: IPSet list
            ActiveTab: int
            SelectedIndex: int
            Width: int
        }

        let create () = {
            Level = Cluster; Enabled = false; PolicyIn = Drop; PolicyOut = Accept
            Rules = []; SecurityGroups = []; IPSets = []; ActiveTab = 0; SelectedIndex = 0; Width = 100
        }

        let dirStr = function In -> "IN" | Out -> "OUT" | Forward -> "FWD"
        let actStr = function Accept -> "ACCEPT" | Drop -> "DROP" | Reject -> "REJECT"
        let actIcon = function Accept -> "✓" | Drop -> "✗" | Reject -> "⊘"

        let render (config: FirewallViewConfig) =
            let width = config.Width
            let levelStr = match config.Level with Cluster -> "CLUSTER" | Node n -> sprintf "NODE: %s" n | VM id -> sprintf "VM: %d" id | Container id -> sprintf "CT: %d" id
            let header = sprintf "┌─ 🛡 FIREWALL: %s %s┐" levelStr (String.replicate (max 0 (width - 18 - String.length levelStr)) "─")
            let statusLine = sprintf "│ Status: %s │ Policy IN: %s │ Policy OUT: %s │"
                                (if config.Enabled then "●ENABLED" else "○DISABLED") (actStr config.PolicyIn) (actStr config.PolicyOut)
            let tabs = sprintf "│ [%s Rules ] [%s Groups ] [%s IPSets ] │"
                        (if config.ActiveTab = 0 then "●" else "○") (if config.ActiveTab = 1 then "●" else "○") (if config.ActiveTab = 2 then "●" else "○")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let content =
                match config.ActiveTab with
                | 0 ->
                    let colHeader = sprintf "│  %-3s %-4s %-6s %-8s %-15s %-15s %-8s %-10s │" "#" "EN" "DIR" "ACTION" "SOURCE" "DEST" "PROTO" "DPORT"
                    let ruleLines = config.Rules |> List.mapi (fun i r ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let en = if r.Enabled then "✓" else "○"
                        sprintf "│%s %-3d %-4s %-6s %s%-8s%s %-15s %-15s %-8s %-10s │"
                            sel r.Pos en (dirStr r.Direction) (if r.Action = Accept then ProxmoxStyle.ansi ProxmoxStyle.palette.Running else ProxmoxStyle.ansi ProxmoxStyle.palette.Stopped)
                            (sprintf "%s %s" (actIcon r.Action) (actStr r.Action)) ProxmoxStyle.reset
                            (defaultArg r.Source "-") (defaultArg r.Dest "-") (defaultArg r.Protocol "-") (defaultArg r.DPort "-"))
                    [colHeader] @ ruleLines
                | 1 ->
                    let groupLines = config.SecurityGroups |> List.mapi (fun i g ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-20s (%d rules) %s │" sel g.Name (List.length g.Rules) (defaultArg g.Comment ""))
                    groupLines
                | _ ->
                    let ipsetLines = config.IPSets |> List.mapi (fun i s ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-20s (%d entries) %s │" sel s.Name (List.length s.Entries) (defaultArg s.Comment ""))
                    ipsetLines

            let actionBar = sprintf "│ [a]dd [e]dit [d]elete [m]ove [t]oggle [c]opy │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; statusLine; tabs; separator] @ content @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: UserView - User & Permission Management (SC-HMI-070)
    // pveum user, group, role, acl
    // ------------------------------------------------------------------------

    module UserView =
        type UserInfo = {
            UserId: string
            Realm: string
            Enabled: bool
            Expire: System.DateTime option
            FirstName: string option
            LastName: string option
            Email: string option
            Groups: string list
            TFAEnabled: bool
            Tokens: int
        }

        type GroupInfo = { Name: string; Members: string list; Comment: string option }
        type RoleInfo = { Name: string; Privileges: string list; Special: bool }
        type ACLInfo = { Path: string; Type: string; UGid: string; Role: string; Propagate: bool }

        type UserViewConfig = {
            Users: UserInfo list
            Groups: GroupInfo list
            Roles: RoleInfo list
            ACLs: ACLInfo list
            ActiveTab: int
            SelectedIndex: int
            Width: int
        }

        let create () = { Users = []; Groups = []; Roles = []; ACLs = []; ActiveTab = 0; SelectedIndex = 0; Width = 100 }

        let render (config: UserViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 👤 USER & PERMISSION MANAGER %s┐" (String.replicate (max 0 (width - 34)) "─")
            let tabs = sprintf "│ [%s Users ] [%s Groups ] [%s Roles ] [%s ACLs ] │"
                        (if config.ActiveTab = 0 then "●" else "○") (if config.ActiveTab = 1 then "●" else "○")
                        (if config.ActiveTab = 2 then "●" else "○") (if config.ActiveTab = 3 then "●" else "○")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let content =
                match config.ActiveTab with
                | 0 ->
                    let colHeader = sprintf "│  %-25s %-10s %-8s %-20s %-6s %-6s │" "USER" "REALM" "ENABLED" "GROUPS" "TFA" "TOKENS"
                    let userLines = config.Users |> List.mapi (fun i u ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let groups = u.Groups |> String.concat "," |> fun s -> if String.length s > 20 then s.Substring(0, 17) + "..." else s
                        sprintf "│%s %-25s %-10s %-8s %-20s %-6s %-6d │" sel u.UserId u.Realm (if u.Enabled then "✓yes" else "✗no") groups (if u.TFAEnabled then "✓" else "○") u.Tokens)
                    [colHeader] @ userLines
                | 1 ->
                    let groupLines = config.Groups |> List.mapi (fun i g ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-20s (%d members) %s │" sel g.Name (List.length g.Members) (defaultArg g.Comment ""))
                    groupLines
                | 2 ->
                    let roleLines = config.Roles |> List.mapi (fun i r ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let special = if r.Special then "[built-in]" else ""
                        sprintf "│%s %-20s (%d privs) %s │" sel r.Name (List.length r.Privileges) special)
                    roleLines
                | _ ->
                    let aclLines = config.ACLs |> List.mapi (fun i a ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-30s %-6s %-20s %-15s %s │" sel a.Path a.Type a.UGid a.Role (if a.Propagate then "↓" else ""))
                    aclLines

            let actionBar = sprintf "│ [a]dd [e]dit [d]elete [p]assword [t]fa [r]efresh │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; tabs; separator] @ content @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: CephView - Ceph Cluster Management (SC-HMI-071)
    // pveceph status, OSD, MON, MDS, pools
    // ------------------------------------------------------------------------

    module CephView =
        type CephHealth = HEALTH_OK | HEALTH_WARN | HEALTH_ERR

        type OSDInfo = { Id: int; Host: string; Status: string; Weight: float; Reweight: float; Size: int64; Used: int64 }
        type MonInfo = { Name: string; Host: string; Address: string; InQuorum: bool }
        type PoolInfo = { Name: string; Size: int; MinSize: int; PGNum: int; UsedBytes: int64; MaxBytes: int64 }

        type CephViewConfig = {
            Health: CephHealth
            HealthDetail: string list
            OSDs: OSDInfo list
            Mons: MonInfo list
            Pools: PoolInfo list
            OSDsUp: int
            OSDsIn: int
            OSDsTotal: int
            ActiveTab: int
            SelectedIndex: int
            Width: int
        }

        let create () = {
            Health = HEALTH_OK; HealthDetail = []; OSDs = []; Mons = []; Pools = []
            OSDsUp = 0; OSDsIn = 0; OSDsTotal = 0; ActiveTab = 0; SelectedIndex = 0; Width = 100
        }

        let healthIcon = function HEALTH_OK -> "●" | HEALTH_WARN -> "◐" | HEALTH_ERR -> "○"
        let healthColor = function
            | HEALTH_OK -> ProxmoxStyle.ansi ProxmoxStyle.palette.Healthy
            | HEALTH_WARN -> ProxmoxStyle.ansi ProxmoxStyle.palette.Warning
            | HEALTH_ERR -> ProxmoxStyle.ansi ProxmoxStyle.palette.Critical

        let render (config: CephViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 🔴 CEPH CLUSTER %s┐" (String.replicate (max 0 (width - 20)) "─")
            let healthStr = match config.Health with HEALTH_OK -> "HEALTH_OK" | HEALTH_WARN -> "HEALTH_WARN" | HEALTH_ERR -> "HEALTH_ERR"
            let statusLine = sprintf "│ %s%s %s%s │ OSDs: %d up, %d in / %d total │ MONs: %d │"
                                (healthColor config.Health) (healthIcon config.Health) healthStr ProxmoxStyle.reset
                                config.OSDsUp config.OSDsIn config.OSDsTotal (List.length config.Mons)
            let tabs = sprintf "│ [%s OSDs ] [%s MONs ] [%s Pools ] │"
                        (if config.ActiveTab = 0 then "●" else "○") (if config.ActiveTab = 1 then "●" else "○") (if config.ActiveTab = 2 then "●" else "○")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let content =
                match config.ActiveTab with
                | 0 ->
                    let colHeader = sprintf "│  %-6s %-12s %-10s %-8s %-10s %-12s %-12s │" "OSD" "HOST" "STATUS" "WEIGHT" "REWEIGHT" "SIZE" "USED"
                    let osdLines = config.OSDs |> List.mapi (fun i o ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s osd.%-3d %-12s %-10s %-8.4f %-10.4f %-12s %-12s │"
                            sel o.Id o.Host o.Status o.Weight o.Reweight
                            (sprintf "%.1fG" (float o.Size / 1073741824.0)) (sprintf "%.1fG" (float o.Used / 1073741824.0)))
                    [colHeader] @ osdLines
                | 1 ->
                    let monLines = config.Mons |> List.mapi (fun i m ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let quorum = if m.InQuorum then "✓ quorum" else "✗ no quorum"
                        sprintf "│%s %-12s %-12s %-20s %-15s │" sel m.Name m.Host m.Address quorum)
                    monLines
                | _ ->
                    let poolLines = config.Pools |> List.mapi (fun i p ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let pct = if p.MaxBytes > 0L then float p.UsedBytes / float p.MaxBytes * 100.0 else 0.0
                        sprintf "│%s %-20s size:%d min:%d pgs:%-5d %-12s %5.1f%% │"
                            sel p.Name p.Size p.MinSize p.PGNum (sprintf "%.1fG" (float p.UsedBytes / 1073741824.0)) pct)
                    poolLines

            let actionBar = sprintf "│ [c]reate [d]estroy [s]et [i]nfo [p]urge [o]sd-in/out │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; statusLine; tabs; separator] @ content @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: NetworkSdnView - SDN Management (SC-HMI-072)
    // VNets, Zones, Controllers, Subnets
    // ------------------------------------------------------------------------

    module NetworkSdnView =
        type ZoneType = Simple | VLAN | QinQ | VXLAN | EVPN

        type ZoneInfo = { Name: string; Type: ZoneType; Nodes: string list; IPAM: string option; DNS: string option }
        type VNetInfo = { Name: string; Zone: string; Tag: int option; Alias: string option; VlanAware: bool }
        type SubnetInfo = { Subnet: string; VNet: string; Gateway: string option; DHCP: bool; DNSZone: string option }

        type SDNViewConfig = {
            Zones: ZoneInfo list
            VNets: VNetInfo list
            Subnets: SubnetInfo list
            ActiveTab: int
            SelectedIndex: int
            Width: int
        }

        let create () = { Zones = []; VNets = []; Subnets = []; ActiveTab = 0; SelectedIndex = 0; Width = 90 }

        let zoneTypeStr = function Simple -> "simple" | VLAN -> "vlan" | QinQ -> "qinq" | VXLAN -> "vxlan" | EVPN -> "evpn"

        let render (config: SDNViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 🔗 SOFTWARE-DEFINED NETWORK %s┐" (String.replicate (max 0 (width - 32)) "─")
            let tabs = sprintf "│ [%s Zones ] [%s VNets ] [%s Subnets ] │"
                        (if config.ActiveTab = 0 then "●" else "○") (if config.ActiveTab = 1 then "●" else "○") (if config.ActiveTab = 2 then "●" else "○")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let content =
                match config.ActiveTab with
                | 0 ->
                    let zoneLines = config.Zones |> List.mapi (fun i z ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-15s %-10s nodes:[%s] ipam:%s │" sel z.Name (zoneTypeStr z.Type) (z.Nodes |> String.concat ",") (defaultArg z.IPAM "-"))
                    zoneLines
                | 1 ->
                    let vnetLines = config.VNets |> List.mapi (fun i v ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        let tag = match v.Tag with Some t -> sprintf "tag:%d" t | None -> ""
                        sprintf "│%s %-15s zone:%-10s %s %s │" sel v.Name v.Zone tag (defaultArg v.Alias ""))
                    vnetLines
                | _ ->
                    let subnetLines = config.Subnets |> List.mapi (fun i s ->
                        let sel = if i = config.SelectedIndex then ">" else " "
                        sprintf "│%s %-20s vnet:%-10s gw:%-15s dhcp:%s │" sel s.Subnet s.VNet (defaultArg s.Gateway "-") (if s.DHCP then "yes" else "no"))
                    subnetLines

            let actionBar = sprintf "│ [a]dd [e]dit [d]elete [r]eload [A]pply │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; tabs; separator] @ content @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: ReplicationView - Storage Replication (SC-HMI-073)
    // Replication jobs and status
    // ------------------------------------------------------------------------

    module ReplicationView =
        type ReplicationState = OK | Error | Syncing | Disabled

        type ReplicationJob = {
            ID: string
            VMID: int
            Type: string
            Target: string
            Schedule: string
            Rate: int option
            Comment: string option
            State: ReplicationState
            LastSync: System.DateTime option
            LastTry: System.DateTime option
            NextSync: System.DateTime option
            Duration: float option
            FailCount: int
        }

        type ReplicationViewConfig = {
            Jobs: ReplicationJob list
            SelectedIndex: int
            Width: int
        }

        let create () = { Jobs = []; SelectedIndex = 0; Width = 100 }

        let stateIcon = function OK -> "✓" | Error -> "✗" | Syncing -> "↻" | Disabled -> "○"
        let stateColor = function
            | OK -> ProxmoxStyle.ansi ProxmoxStyle.palette.Healthy
            | Error -> ProxmoxStyle.ansi ProxmoxStyle.palette.Critical
            | Syncing -> ProxmoxStyle.ansi ProxmoxStyle.palette.Paused
            | Disabled -> ""

        let render (config: ReplicationViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ ↔ STORAGE REPLICATION %s┐" (String.replicate (max 0 (width - 26)) "─")
            let colHeader = sprintf "│  %-15s %-6s %-12s %-15s %-10s %-15s %-6s │" "JOB ID" "VMID" "TARGET" "SCHEDULE" "STATE" "LAST SYNC" "FAIL"
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let jobLines = config.Jobs |> List.mapi (fun i j ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let lastSync = match j.LastSync with Some dt -> dt.ToString("MM-dd HH:mm") | None -> "-"
                sprintf "│%s %-15s %-6d %-12s %-15s %s%-10s%s %-15s %-6d │"
                    sel j.ID j.VMID j.Target j.Schedule
                    (stateColor j.State) (sprintf "%s %s" (stateIcon j.State) (match j.State with OK -> "ok" | Error -> "error" | Syncing -> "sync" | Disabled -> "off"))
                    ProxmoxStyle.reset lastSync j.FailCount)

            let actionBar = sprintf "│ [c]reate [e]dit [d]elete [r]un now [s]chedule log │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; colHeader; separator] @ jobLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: TaskView - Task History (SC-HMI-074)
    // Running and completed tasks
    // ------------------------------------------------------------------------

    module TaskView =
        type TaskState = Running | OK | Warning | Error | Unknown

        type TaskInfo = {
            UPID: string
            Node: string
            PID: int
            StartTime: System.DateTime
            EndTime: System.DateTime option
            Type: string
            ID: string
            User: string
            State: TaskState
            Status: string option
        }

        type TaskViewConfig = {
            Tasks: TaskInfo list
            ShowRunning: bool
            SelectedIndex: int
            Width: int
        }

        let create () = { Tasks = []; ShowRunning = true; SelectedIndex = 0; Width = 100 }

        let stateIcon = function Running -> "⏳" | OK -> "✓" | Warning -> "⚠" | Error -> "✗" | Unknown -> "?"
        let stateColor = function
            | Running -> ProxmoxStyle.ansi ProxmoxStyle.palette.Paused
            | OK -> ProxmoxStyle.ansi ProxmoxStyle.palette.Healthy
            | Warning -> ProxmoxStyle.ansi ProxmoxStyle.palette.Warning
            | Error -> ProxmoxStyle.ansi ProxmoxStyle.palette.Critical
            | Unknown -> ""

        let render (config: TaskViewConfig) =
            let width = config.Width
            let filter = if config.ShowRunning then "Running" else "All"
            let header = sprintf "┌─ 📋 TASK HISTORY (%s) %s┐" filter (String.replicate (max 0 (width - 25 - String.length filter)) "─")
            let colHeader = sprintf "│  %-12s %-15s %-20s %-10s %-8s %-12s │" "NODE" "TYPE" "ID" "USER" "STATE" "START"
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let taskLines = config.Tasks |> List.mapi (fun i t ->
                let sel = if i = config.SelectedIndex then ">" else " "
                sprintf "│%s %-12s %-15s %-20s %-10s %s%-8s%s %-12s │"
                    sel t.Node t.Type (if String.length t.ID > 20 then t.ID.Substring(0, 17) + "..." else t.ID)
                    t.User (stateColor t.State) (sprintf "%s %s" (stateIcon t.State) (match t.State with OK -> "OK" | Error -> "ERR" | Running -> "RUN" | _ -> ""))
                    ProxmoxStyle.reset (t.StartTime.ToString("HH:mm:ss")))

            let actionBar = sprintf "│ [v]iew log [s]top [r]efresh [f]ilter [Enter]details │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; colHeader; separator] @ taskLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: DatacenterView - Datacenter Overview (SC-HMI-075)
    // Datacenter-level summary and navigation
    // ------------------------------------------------------------------------

    module DatacenterView =
        type DCResourceSummary = {
            NodesOnline: int
            NodesTotal: int
            VMsRunning: int
            VMsTotal: int
            CTsRunning: int
            CTsTotal: int
            CPUUsage: float
            MemoryUsage: float
            StorageUsage: float
        }

        type DCViewConfig = {
            Name: string
            Summary: DCResourceSummary
            Nodes: ClusterView.NodeInfo list
            RecentTasks: TaskView.TaskInfo list
            Width: int
        }

        let create name = {
            Name = name
            Summary = { NodesOnline = 0; NodesTotal = 0; VMsRunning = 0; VMsTotal = 0; CTsRunning = 0; CTsTotal = 0; CPUUsage = 0.0; MemoryUsage = 0.0; StorageUsage = 0.0 }
            Nodes = []
            RecentTasks = []
            Width = 100
        }

        let progressBar pct w =
            let filled = int (float w * pct / 100.0)
            sprintf "[%s%s]" (String.replicate filled "█") (String.replicate (w - filled) "░")

        let render (config: DCViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 🏢 DATACENTER: %s %s┐" config.Name (String.replicate (max 0 (width - 17 - String.length config.Name)) "─")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let s = config.Summary
            let summaryLines = [
                sprintf "│ 🖧 Nodes: %d/%d online │ 🖥 VMs: %d/%d running │ 📦 CTs: %d/%d running │"
                    s.NodesOnline s.NodesTotal s.VMsRunning s.VMsTotal s.CTsRunning s.CTsTotal
                sprintf "│ ⚡ CPU:  %s %5.1f%% │" (progressBar s.CPUUsage 30) s.CPUUsage
                sprintf "│ 🧠 MEM:  %s %5.1f%% │" (progressBar s.MemoryUsage 30) s.MemoryUsage
                sprintf "│ 💾 DISK: %s %5.1f%% │" (progressBar s.StorageUsage 30) s.StorageUsage
            ]

            let nodeHeader = "│ NODES:"
            let nodeLines = config.Nodes |> List.map (fun n ->
                let status = if n.Online then "●" else "○"
                sprintf "│  %s %-12s CPU:%5.1f%% MEM:%5.1f%% │" status n.Name n.CPU n.Memory)

            let taskHeader = "│ RECENT TASKS:"
            let taskLines = config.RecentTasks |> List.truncate 5 |> List.map (fun t ->
                sprintf "│  %s %-10s %-15s %s │" (TaskView.stateIcon t.State) t.Node t.Type (t.StartTime.ToString("HH:mm")))

            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header] @ summaryLines @ [separator; nodeHeader] @ nodeLines @ [separator; taskHeader] @ taskLines @ [footer]

    // ------------------------------------------------------------------------
    // COMPONENT: ResourcePoolView - Resource Pool Management (SC-HMI-076)
    // Pool membership and quotas
    // ------------------------------------------------------------------------

    module ResourcePoolView =
        type PoolMember = { Type: string; ID: int; Name: string; Node: string }

        type PoolInfo = {
            Name: string
            Comment: string option
            Members: PoolMember list
        }

        type PoolViewConfig = {
            Pools: PoolInfo list
            SelectedIndex: int
            ExpandedPool: string option
            Width: int
        }

        let create () = { Pools = []; SelectedIndex = 0; ExpandedPool = None; Width = 80 }

        let render (config: PoolViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 📁 RESOURCE POOLS %s┐" (String.replicate (max 0 (width - 22)) "─")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let poolLines = config.Pools |> List.mapi (fun i p ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let expanded = config.ExpandedPool = Some p.Name
                let arrow = if expanded then "▼" else "▶"
                let mainLine = sprintf "│%s %s %-20s (%d members) %s │" sel arrow p.Name (List.length p.Members) (defaultArg p.Comment "")
                if expanded then
                    let memberLines = p.Members |> List.map (fun m ->
                        sprintf "│    ├─ %s %d: %s (%s) │" m.Type m.ID m.Name m.Node)
                    mainLine :: memberLines
                else [mainLine]) |> List.concat

            let actionBar = sprintf "│ [c]reate [e]dit [d]elete [a]dd member [r]emove member │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; separator] @ poolLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: SnapshotManagerView - Snapshot Management (SC-HMI-077)
    // VM/CT snapshots with tree view
    // ------------------------------------------------------------------------

    module SnapshotManagerView =
        type SnapshotInfo = {
            Name: string
            Description: string option
            Parent: string option
            Snaptime: System.DateTime
            VMID: int
            IncludesRAM: bool
        }

        type SnapshotViewConfig = {
            VMID: int
            VMName: string
            Snapshots: SnapshotInfo list
            Current: string
            SelectedIndex: int
            Width: int
        }

        let create vmid name = { VMID = vmid; VMName = name; Snapshots = []; Current = ""; SelectedIndex = 0; Width = 80 }

        let render (config: SnapshotViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 📸 SNAPSHOTS: %d (%s) %s┐" config.VMID config.VMName (String.replicate (max 0 (width - 20 - String.length config.VMName)) "─")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let snapLines = config.Snapshots |> List.mapi (fun i s ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let current = if s.Name = config.Current then " ●" else ""
                let ram = if s.IncludesRAM then "📝" else ""
                sprintf "│%s %-20s%s %-20s %s %s │" sel s.Name current (s.Snaptime.ToString("yyyy-MM-dd HH:mm")) (defaultArg s.Description "") ram)

            let actionBar = sprintf "│ [c]reate [r]ollback [d]elete [e]dit [Enter]details │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; separator] @ snapLines @ [separator; actionBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: MigrationDialog - VM/CT Migration (SC-HMI-078)
    // Live migration, offline migration options
    // ------------------------------------------------------------------------

    module MigrationDialog =
        type MigrationType = Online | Offline | Restart

        type MigrationConfig = {
            VMID: int
            VMName: string
            SourceNode: string
            TargetNode: string option
            AvailableNodes: string list
            Type: MigrationType
            WithLocalDisks: bool
            TargetStorage: string option
            AvailableStorages: string list
            Compressed: bool
            Bandwidth: int option
            Armed: bool
            Width: int
        }

        let create vmid name source = {
            VMID = vmid; VMName = name; SourceNode = source; TargetNode = None
            AvailableNodes = []; Type = Online; WithLocalDisks = false
            TargetStorage = None; AvailableStorages = []; Compressed = true
            Bandwidth = None; Armed = false; Width = 60
        }

        let render (config: MigrationConfig) =
            let width = config.Width
            let header = sprintf "┌─ ↔ MIGRATE: %d (%s) %s┐" config.VMID config.VMName (String.replicate (max 0 (width - 18 - String.length config.VMName)) "─")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let sourceLine = sprintf "│ Source: %-20s │" config.SourceNode
            let targetLine = sprintf "│ Target: [%-20s ▼] │" (defaultArg config.TargetNode "Select node...")
            let typeLine = sprintf "│ Type: %s Online  %s Offline  %s Restart │"
                            (if config.Type = Online then "●" else "○")
                            (if config.Type = Offline then "●" else "○")
                            (if config.Type = Restart then "●" else "○")
            let optionsLine = sprintf "│ [%s] With local disks  [%s] Compressed │"
                                (if config.WithLocalDisks then "✓" else " ")
                                (if config.Compressed then "✓" else " ")
            let storageLine = if config.WithLocalDisks then
                                sprintf "│ Target storage: [%-15s ▼] │" (defaultArg config.TargetStorage "same")
                              else ""
            let bandwidthLine = sprintf "│ Bandwidth limit: [%s] MiB/s │" (match config.Bandwidth with Some b -> string b | None -> "unlimited")

            let armStatus =
                if config.Armed then
                    sprintf "│ %s◎ ARMED%s - Press Enter to confirm migration │" (ProxmoxStyle.ansi ProxmoxStyle.palette.Warning) ProxmoxStyle.reset
                else
                    "│ Press [m] to arm migration │"

            let buttonLine = sprintf "│      [%s MIGRATE ]        [ CANCEL ] │" (if config.Armed then "●" else "○")
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")

            [header; separator; sourceLine; targetLine; separator; typeLine; optionsLine] @
            (if storageLine <> "" then [storageLine] else []) @
            [bandwidthLine; separator; armStatus; buttonLine; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: ConsoleView - VM/CT Console Access (SC-HMI-079)
    // Console terminal, SPICE, VNC options
    // ------------------------------------------------------------------------

    module ConsoleView =
        type ConsoleType = NoVNC | SPICE | XTerm | Serial

        type ConsoleConfig = {
            VMID: int
            VMName: string
            Type: ConsoleType
            Node: string
            Connected: bool
            Width: int
            Height: int
        }

        let create vmid name node = { VMID = vmid; VMName = name; Type = NoVNC; Node = node; Connected = false; Width = 80; Height = 24 }

        let typeStr = function NoVNC -> "noVNC" | SPICE -> "SPICE" | XTerm -> "xterm.js" | Serial -> "Serial"

        let render (config: ConsoleConfig) =
            let width = config.Width
            let height = config.Height
            let connStatus = if config.Connected then sprintf "%s● Connected%s" (ProxmoxStyle.ansi ProxmoxStyle.palette.Running) ProxmoxStyle.reset
                             else sprintf "%s○ Disconnected%s" (ProxmoxStyle.ansi ProxmoxStyle.palette.Stopped) ProxmoxStyle.reset

            let header = sprintf "┌─ ⌨ CONSOLE: %d (%s) [%s] %s %s┐"
                            config.VMID config.VMName (typeStr config.Type) connStatus
                            (String.replicate (max 0 (width - 40 - String.length config.VMName)) "─")

            let terminalLines = List.init (height - 4) (fun _ -> sprintf "│%s│" (String.replicate (width - 2) " "))
            let statusBar = sprintf "│ Ctrl+Alt+Del: Send │ Ctrl+Alt+Shift: Grab │ [noVNC] [SPICE] [xterm] │"
            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")

            [header] @ terminalLines @ [statusBar; footer]

    // ------------------------------------------------------------------------
    // COMPONENT: MetricsView - Metrics & Monitoring (SC-HMI-080)
    // RRD graphs, performance metrics
    // ------------------------------------------------------------------------

    module MetricsView =
        type TimeRange = Hour | Day | Week | Month | Year

        type MetricSample = { Timestamp: System.DateTime; Value: float }

        type MetricSeries = {
            Name: string
            Unit: string
            Current: float
            Average: float
            Max: float
            Samples: MetricSample list
        }

        type MetricsViewConfig = {
            Resource: string
            TimeRange: TimeRange
            Series: MetricSeries list
            SelectedIndex: int
            Width: int
            Height: int
        }

        let create resource = { Resource = resource; TimeRange = Hour; Series = []; SelectedIndex = 0; Width = 80; Height = 20 }

        let timeRangeStr = function Hour -> "1h" | Day -> "1d" | Week -> "1w" | Month -> "1m" | Year -> "1y"

        let sparkline (samples: MetricSample list) width =
            if List.isEmpty samples then String.replicate width " "
            else
                let values = samples |> List.map (fun s -> s.Value)
                let minV = List.min values
                let maxV = List.max values
                let range = if maxV - minV < 0.001 then 1.0 else maxV - minV
                let chars = "▁▂▃▄▅▆▇█"
                let step = range / 7.0
                samples
                |> List.map (fun s ->
                    let idx = min 7 (int ((s.Value - minV) / step))
                    chars.[idx])
                |> List.rev |> List.truncate width |> List.rev
                |> Array.ofList |> System.String

        let render (config: MetricsViewConfig) =
            let width = config.Width
            let header = sprintf "┌─ 📊 METRICS: %s [%s] %s┐" config.Resource (timeRangeStr config.TimeRange) (String.replicate (max 0 (width - 22 - String.length config.Resource)) "─")
            let tabs = sprintf "│ [%s 1h ] [%s 1d ] [%s 1w ] [%s 1m ] [%s 1y ] │"
                        (if config.TimeRange = Hour then "●" else "○")
                        (if config.TimeRange = Day then "●" else "○")
                        (if config.TimeRange = Week then "●" else "○")
                        (if config.TimeRange = Month then "●" else "○")
                        (if config.TimeRange = Year then "●" else "○")
            let separator = sprintf "├%s┤" (String.replicate (width - 2) "─")

            let metricLines = config.Series |> List.mapi (fun i s ->
                let sel = if i = config.SelectedIndex then ">" else " "
                let spark = sparkline s.Samples 30
                sprintf "│%s %-10s %s cur:%-8.2f avg:%-8.2f max:%-8.2f %s │" sel s.Name spark s.Current s.Average s.Max s.Unit)

            let footer = sprintf "└%s┘" (String.replicate (width - 2) "─")
            [header; tabs; separator] @ metricLines @ [footer]

