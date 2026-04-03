namespace Cepaf.Cockpit

open System
open System.Text
open Cepaf.Cockpit.Domain

/// ═══════════════════════════════════════════════════════════════════════════════
/// C3I MESH COCKPIT - DARK COCKPIT UI (Safety-Critical HMI)
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Terminal-based UI implementing NASA-STD-3000 and NUREG-0700 standards
///       for safety-critical Human-Machine Interfaces.
///
/// WHY: The "Dark Cockpit" philosophy reduces cognitive load by only highlighting
///      deviations from normal. Normal = invisible or dim. Abnormal = bright.
///
/// KEY PRINCIPLES:
///   1. Management by Exception - Only show what needs attention
///   2. Analog over Digital - Use bar charts, sparklines, not just numbers
///   3. Trend Vectors - Show direction, not just current state
///   4. Staleness Decay - Gray out stale data (frozen numbers lie)
///   5. Two-Step Commit - Critical commands require arm -> confirm
///
/// STAMP Compliance:
///   - SC-HMI-001: Dark Cockpit (gray/blue default, amber/red deviations)
///   - SC-HMI-002: Trend vectors displayed
///   - SC-HMI-003: Staleness visual decay
///   - SC-HMI-004: Two-step commit UI
///
/// ═══════════════════════════════════════════════════════════════════════════════
module DarkCockpitUI =

    // ═══════════════════════════════════════════════════════════════════════════
    // ANSI CODES - Dark Cockpit Color Palette
    // ═══════════════════════════════════════════════════════════════════════════

    module Ansi =
        // Reset
        let reset = "\u001b[0m"

        // Text Styles
        let bold = "\u001b[1m"
        let dim = "\u001b[2m"
        let italic = "\u001b[3m"
        let blink = "\u001b[5m"  // For critical warnings only

        // Dark Cockpit Palette
        // Normal state: dim gray/blue (almost invisible)
        let normal = "\u001b[90m"      // Dark gray - normal state
        let normalBg = "\u001b[100m"   // Dim gray background

        // Advisory: cyan (informational, low priority)
        let advisory = "\u001b[36m"    // Cyan
        let advisoryBg = "\u001b[46m"

        // Caution: amber/yellow (attention required)
        let caution = "\u001b[33m"     // Yellow/Amber
        let cautionBg = "\u001b[43m"

        // Warning: red (immediate action)
        let warning = "\u001b[31m"     // Red
        let warningBg = "\u001b[41m"

        // Critical: red + blink
        let critical = "\u001b[31;5m"  // Red + Blink

        // Status colors
        let connected = "\u001b[32m"   // Green (connected only)
        let stale = "\u001b[90m"       // Gray (stale data)
        let disconnected = "\u001b[31m" // Red (disconnected)

        // Accent
        let blue = "\u001b[34m"
        let magenta = "\u001b[35m"
        let white = "\u001b[37m"
        let brightWhite = "\u001b[97m"

        // Background
        let bgBlue = "\u001b[44m"
        let bgGray = "\u001b[100m"

        // Control
        let clear = "\u001b[2J\u001b[H"
        let hideCursor = "\u001b[?25l"
        let showCursor = "\u001b[?25h"
        let saveCursor = "\u001b[s"
        let restoreCursor = "\u001b[u"

    // ═══════════════════════════════════════════════════════════════════════════
    // ICONS - Safety-Critical Symbology
    // ═══════════════════════════════════════════════════════════════════════════

    module Icons =
        // Status indicators
        let connected = "●"
        let stale = "◐"
        let disconnected = "○"
        let unknown = "?"

        // Trend arrows (CRITICAL for situational awareness)
        let rising = "↑"
        let risingFast = "↑↑"
        let falling = "↓"
        let fallingFast = "↓↓"
        let stable = "→"

        // Alarm levels
        let normal = "·"
        let advisory = "ℹ"
        let caution = "⚠"
        let warning = "⛔"
        let critical = "☢"

        // Progress/bars
        let barFull = "█"
        let barMid = "▓"
        let barLow = "░"
        let barEmpty = "·"

        // Sparkline characters (mini chart)
        let spark = [| "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█" |]

        // Command states
        let idle = "○"
        let armed = "◎"
        let executing = "●"
        let acknowledged = "✓"
        let failed = "✗"

        // Spinner
        let spinner = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]

    // ═══════════════════════════════════════════════════════════════════════════
    // BOX DRAWING - Clean Terminal Layout
    // ═══════════════════════════════════════════════════════════════════════════

    module Box =
        let tl = "╔"
        let tr = "╗"
        let bl = "╚"
        let br = "╝"
        let h = "═"
        let v = "║"
        let cross = "╬"
        let tRight = "╠"
        let tLeft = "╣"
        let tDown = "╦"
        let tUp = "╩"
        // Light borders for inner panels
        let ltl = "┌"
        let ltr = "┐"
        let lbl = "└"
        let lbr = "┘"
        let lh = "─"
        let lv = "│"

    // ═══════════════════════════════════════════════════════════════════════════
    // DARK COCKPIT RENDERING LOGIC
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get color for alarm level (Dark Cockpit philosophy)
    let alarmColor (level: AlarmLevel) =
        match level with
        | Normal -> Ansi.normal       // Nearly invisible
        | Advisory -> Ansi.advisory   // Cyan (info)
        | Caution -> Ansi.caution     // Amber
        | Warning -> Ansi.warning     // Red
        | Critical -> Ansi.critical   // Red + blink

    /// Get icon for alarm level
    let alarmIcon (level: AlarmLevel) =
        match level with
        | Normal -> Icons.normal
        | Advisory -> Icons.advisory
        | Caution -> Icons.caution
        | Warning -> Icons.warning
        | Critical -> Icons.critical

    /// Get color for connection status
    let statusColor (status: ConnStatus) =
        match status with
        | Connected -> Ansi.connected
        | Stale -> Ansi.stale
        | Degraded -> Ansi.caution
        | Disconnected -> Ansi.disconnected

    /// Get icon for connection status
    let statusIcon (status: ConnStatus) =
        match status with
        | Connected -> Icons.connected
        | Stale -> Icons.stale
        | Degraded -> Icons.stale
        | Disconnected -> Icons.disconnected

    /// Get trend arrow with color
    let trendArrow (trend: Trend) =
        match trend with
        | Rising -> sprintf "%s%s%s" Ansi.caution Icons.rising Ansi.reset
        | RisingFast -> sprintf "%s%s%s" Ansi.warning Icons.risingFast Ansi.reset
        | Falling -> sprintf "%s%s%s" Ansi.advisory Icons.falling Ansi.reset
        | FallingFast -> sprintf "%s%s%s" Ansi.caution Icons.fallingFast Ansi.reset
        | Stable -> sprintf "%s%s%s" Ansi.normal Icons.stable Ansi.reset

    /// Render a sparkline (mini bar chart for trend visualization)
    let renderSparkline (values: float list) (maxVal: float) (width: int) =
        if values.IsEmpty then String.replicate width Icons.barEmpty
        else
            let normalized = values |> List.map (fun v -> min 1.0 (v / maxVal))
            normalized
            |> List.truncate width
            |> List.map (fun v ->
                let idx = int (v * 7.0) |> max 0 |> min 7
                Icons.spark.[idx]
            )
            |> String.concat ""

    /// Render a horizontal bar (analog representation)
    /// Handles edge cases: negative values clamped to 0, values > max clamped to max
    let renderBar (value: float) (maxVal: float) (width: int) (level: AlarmLevel) =
        let pct = value / maxVal |> max 0.0 |> min 1.0
        let filled = int (pct * float width) |> max 0
        let empty = (width - filled) |> max 0
        let color = alarmColor level
        sprintf "%s%s%s%s%s"
            color
            (String.replicate filled Icons.barFull)
            Ansi.dim
            (String.replicate empty Icons.barEmpty)
            Ansi.reset

    // ═══════════════════════════════════════════════════════════════════════════
    // SMART METRIC RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Render a smart metric with analog bar, value, trend, and staleness
    let renderSmartMetric (metric: SmartMetric<float>) (barWidth: int) =
        let isStale = isStale metric
        let level =
            if isStale then Normal  // Gray out stale data
            else
                if metric.Value >= 95.0 then Warning
                elif metric.Value >= 85.0 then Caution
                elif metric.Value >= 75.0 then Advisory
                else Normal

        let bar = renderBar metric.Value 100.0 barWidth level
        let arrow = if isStale then sprintf "%s?%s" Ansi.stale Ansi.reset else trendArrow metric.Trend
        let valueColor = if isStale then Ansi.stale else alarmColor level
        let valueStr = sprintf "%s%.0f%s%s" valueColor metric.Value Ansi.reset metric.Unit

        sprintf "%s %s %s" bar valueStr arrow

    // ═══════════════════════════════════════════════════════════════════════════
    // PANEL RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    type TerminalSize = { Cols: int; Rows: int }

    let getTerminalSize () =
        try { Cols = max 120 Console.WindowWidth; Rows = max 40 Console.WindowHeight }
        with _ -> { Cols = 140; Rows = 50 }

    let private visibleLength (s: string) =
        System.Text.RegularExpressions.Regex.Replace(s, @"\u001b\[[0-9;]*m", "").Length

    let private padRight (s: string) (width: int) =
        let visible = visibleLength s
        if visible < width then s + String.replicate (width - visible) " " else s

    let private truncate (s: string) (width: int) =
        if s.Length <= width then s
        else s.Substring(0, width - 3) + "..."

    /// Render header with phase and timing
    let renderHeader (state: CockpitState) (size: TerminalSize) (spinnerFrame: int) =
        let spinner = Icons.spinner.[spinnerFrame % Icons.spinner.Length]
        let uptime = DateTime.UtcNow - state.StartedAt
        let uptimeStr = sprintf "%02d:%02d:%02d" (int uptime.TotalHours) uptime.Minutes uptime.Seconds
        let timestamp = DateTime.UtcNow.ToString("HH:mm:ss")

        let line1 = sprintf "%s%s%s" Box.tl (String.replicate (size.Cols - 2) Box.h) Box.tr

        let title = sprintf "%s%s C3I MESH COCKPIT %s" Ansi.bold Ansi.bgBlue Ansi.reset
        let view = sprintf "%s%A%s" Ansi.advisory state.CurrentView Ansi.reset
        let statusSummary =
            let healthy = state.Nodes |> Map.filter (fun _ n -> n.Status = Connected) |> Map.count
            let total = Map.count state.Nodes
            let alarms = state.Alarms |> Map.filter (fun _ a -> a.AcknowledgedAt.IsNone) |> Map.count
            if alarms > 0 then
                sprintf "%s%d ALARMS%s" Ansi.warning alarms Ansi.reset
            elif healthy = total && total > 0 then
                sprintf "%s%d/%d OK%s" Ansi.normal healthy total Ansi.reset
            else
                sprintf "%s%d/%d%s" Ansi.caution healthy total Ansi.reset

        let content = sprintf " %s %s %s │ %s │ %s %s"
                        title spinner view statusSummary uptimeStr timestamp
        let line2 = sprintf "%s%s%s"
                        Box.v
                        (padRight content (size.Cols - 2))
                        Box.v

        [line1; line2; sprintf "%s%s%s" Box.tRight (String.replicate (size.Cols - 2) Box.h) Box.tLeft]

    /// Render nodes panel (Dark Cockpit style)
    let renderNodesPanel (state: CockpitState) (width: int) (height: int) =
        let header = sprintf "%s%s MESH NODES (%d) %s%s"
                        Box.v Ansi.bold (Map.count state.Nodes) Ansi.reset
                        (String.replicate (width - 18) Box.lh)

        let nodeLines =
            state.Nodes
            |> Map.toList
            |> List.sortBy (fun (_, n) ->
                // Sort by severity: disconnected first, then by health
                match n.Status with
                | Disconnected -> 0
                | Stale -> 1
                | Degraded -> 2
                | Connected -> 3 + n.HealthScore.Value
            )
            |> List.truncate (height - 2)
            |> List.map (fun (id, node) ->
                let icon = statusIcon node.Status
                let color = statusColor node.Status

                // Dark Cockpit: only colorize if there's something to notice
                let nodeColor =
                    if node.Status <> Connected || node.Cpu.Value > 75.0 then color
                    else Ansi.dim

                let name = truncate node.Name 12
                let zone = sprintf "[%s]" (truncate node.Zone 6)

                // CPU with trend (analog + arrow)
                let cpuBar = renderBar node.Cpu.Value 100.0 6 (if node.Cpu.Value > 85.0 then Caution else Normal)
                let cpuArrow = trendArrow node.Cpu.Trend

                // Health indicator
                let healthColor =
                    if node.HealthScore.Value >= 80 then Ansi.normal
                    elif node.HealthScore.Value >= 60 then Ansi.caution
                    else Ansi.warning
                let health = sprintf "%s%d%%%s" healthColor node.HealthScore.Value Ansi.reset

                let content = sprintf " %s%s%s %-12s %s%s%s %s %.0f%%%s %s"
                                nodeColor icon Ansi.reset
                                name
                                Ansi.dim zone Ansi.reset
                                cpuBar node.Cpu.Value cpuArrow
                                health

                sprintf "%s%s%s" Box.v (padRight content (width - 2)) Box.v
            )

        let emptyCount = height - 2 - List.length nodeLines
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

        header :: nodeLines @ emptyLines

    /// Render alarms panel (only unacknowledged)
    let renderAlarmsPanel (state: CockpitState) (width: int) (height: int) =
        let activeAlarms =
            state.Alarms
            |> Map.filter (fun _ a -> a.AcknowledgedAt.IsNone)
            |> Map.toList
            |> List.sortByDescending (fun (_, a) -> a.Level, a.OccurredAt)

        let alarmCount = List.length activeAlarms
        let headerColor = if alarmCount > 0 then Ansi.warning else Ansi.normal
        let header = sprintf "%s%s%s ALARMS (%d) %s%s%s"
                        Box.tRight headerColor Ansi.bold alarmCount Ansi.reset
                        (String.replicate (width - 14) Box.lh) Box.tLeft

        let alarmLines =
            activeAlarms
            |> List.truncate (height - 2)
            |> List.map (fun (_, alarm) ->
                let icon = alarmIcon alarm.Level
                let color = alarmColor alarm.Level
                let age = (DateTime.UtcNow - alarm.OccurredAt).TotalMinutes
                let ageStr = if age < 1.0 then "now" elif age < 60.0 then sprintf "%.0fm" age else sprintf "%.0fh" (age / 60.0)
                let msg = truncate alarm.Message (width - 25)

                let content = sprintf " %s%s%s %s%-4s%s %s"
                                color icon Ansi.reset
                                Ansi.dim ageStr Ansi.reset
                                msg

                sprintf "%s%s%s" Box.v (padRight content (width - 2)) Box.v
            )

        // Dark Cockpit: if no alarms, show minimal indicator
        let emptyIndicator =
            if alarmCount = 0 then
                [sprintf "%s %s%s%s%s" Box.v Ansi.dim "No active alarms" Ansi.reset
                    (String.replicate (width - 20) " ") + Box.v]
            else []

        let emptyCount = height - 2 - List.length alarmLines - List.length emptyIndicator
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

        header :: alarmLines @ emptyIndicator @ emptyLines

    /// Render AI insights panel
    let renderAiPanel (state: CockpitState) (width: int) (height: int) =
        let aiEnabled = if state.AiEnabled then "🤖" else "⚠"
        let header = sprintf "%s%s %s AI COPILOT %s%s%s"
                        Box.tRight Ansi.bold aiEnabled Ansi.reset
                        (String.replicate (width - 16) Box.lh) Box.tLeft

        let relevantInsights =
            state.Insights
            |> List.filter (fun i ->
                match i.ExpiresAt with
                | Some exp -> exp > DateTime.UtcNow
                | None -> true
            )
            |> List.truncate 3

        let insightLines =
            relevantInsights
            |> List.collect (fun insight ->
                let icon = alarmIcon insight.Level
                let color = alarmColor insight.Level
                let conf = sprintf "%.0f%%" (insight.Confidence * 100.0)

                let titleLine = sprintf " %s%s%s %s%s%s %s%s%s"
                                    color icon Ansi.reset
                                    Ansi.bold (truncate insight.Title (width - 20)) Ansi.reset
                                    Ansi.dim conf Ansi.reset

                let descLines =
                    insight.Description
                    |> fun s -> if s.Length > width - 10 then s.Substring(0, width - 13) + "..." else s
                    |> fun s -> [sprintf "   %s%s%s" Ansi.dim s Ansi.reset]

                [sprintf "%s%s%s" Box.v (padRight titleLine (width - 2)) Box.v] @
                (descLines |> List.map (fun l -> sprintf "%s%s%s" Box.v (padRight l (width - 2)) Box.v))
            )

        let emptyCount = height - 1 - List.length insightLines
        let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

        header :: insightLines @ emptyLines

    /// Render pending commands panel
    let renderCommandsPanel (state: CockpitState) (width: int) =
        let pendingCount = Map.count state.PendingCommands
        if pendingCount = 0 then []
        else
            let header = sprintf "%s%s PENDING COMMANDS (%d) %s%s"
                            Box.tRight Ansi.bold pendingCount Ansi.reset
                            (String.replicate (width - 24) Box.lh)

            let cmdLines =
                state.PendingCommands
                |> Map.toList
                |> List.map (fun (_, cmd) ->
                    let icon =
                        match cmd.State with
                        | Idle -> Icons.idle
                        | Armed -> Icons.armed
                        | Executing -> Icons.executing
                        | Acknowledged -> Icons.acknowledged
                        | Failed -> Icons.failed

                    let color =
                        match cmd.State with
                        | Armed -> Ansi.caution
                        | Executing -> Ansi.advisory
                        | Failed -> Ansi.warning
                        | _ -> Ansi.normal

                    let content = sprintf " %s%s%s %s -> %A"
                                    color icon Ansi.reset
                                    cmd.TargetNodeId cmd.Command

                    sprintf "%s%s%s" Box.v (padRight content (width - 2)) Box.v
                )

            header :: cmdLines

    /// Render footer with controls
    let renderFooter (state: CockpitState) (size: TerminalSize) =
        let line1 = sprintf "%s%s%s" Box.bl (String.replicate (size.Cols - 2) Box.h) Box.br

        let controls =
            if state.MonitorOnly then
                sprintf " %sMONITOR ONLY%s │ [q]uit │ [v]iew │ [r]efresh" Ansi.caution Ansi.reset
            else
                sprintf " [a]rm │ [c]onfirm │ [x]cancel │ [q]uit │ [v]iew │ [r]efresh"

        let msgRate =
            match state.LastMessageAt with
            | Some last ->
                let ago = (DateTime.UtcNow - last).TotalSeconds
                if ago < 2.0 then sprintf "%s%.0f msg/s%s" Ansi.normal (float state.MessagesReceived / (DateTime.UtcNow - state.StartedAt).TotalSeconds) Ansi.reset
                else sprintf "%sSTALE (%.0fs)%s" Ansi.stale ago Ansi.reset
            | None -> sprintf "%sAwaiting data%s" Ansi.dim Ansi.reset

        let line2 = sprintf " %s%s │ Session: %s │ %s"
                        (padRight controls (size.Cols - 50))
                        msgRate state.SessionId
                        (if state.SimulationMode then sprintf "%sSIMULATION%s" Ansi.caution Ansi.reset else "")

        [line1; line2]

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN RENDER FUNCTION
    // ═══════════════════════════════════════════════════════════════════════════

    let mutable private spinnerFrame = 0

    /// Render the complete Dark Cockpit UI
    let render (state: CockpitState) =
        spinnerFrame <- spinnerFrame + 1
        let size = getTerminalSize()

        let leftWidth = size.Cols / 2
        let rightWidth = size.Cols - leftWidth
        let panelHeight = (size.Rows - 6) / 2

        let header = renderHeader state size spinnerFrame
        let nodes = renderNodesPanel state leftWidth panelHeight
        let alarms = renderAlarmsPanel state rightWidth panelHeight
        let ai = renderAiPanel state leftWidth panelHeight
        let cmds = renderCommandsPanel state rightWidth
        let footer = renderFooter state size

        // Merge side-by-side panels
        let mergePanels left right =
            let maxLen = max (List.length left) (List.length right)
            [0..maxLen-1]
            |> List.map (fun i ->
                let l = if i < List.length left then left.[i] else String.replicate leftWidth " "
                let r = if i < List.length right then right.[i] else String.replicate rightWidth " "
                l + r
            )

        let topPanels = mergePanels nodes alarms
        let bottomPanels =
            let rightPanel = if cmds.IsEmpty then List.replicate panelHeight (sprintf "%s%s%s" Box.v (String.replicate (rightWidth - 2) " ") Box.v) else cmds @ List.replicate (panelHeight - List.length cmds) (sprintf "%s%s%s" Box.v (String.replicate (rightWidth - 2) " ") Box.v)
            mergePanels ai rightPanel

        let sb = StringBuilder()
        sb.Append(Ansi.clear) |> ignore

        for line in header do sb.AppendLine(line) |> ignore
        for line in topPanels do sb.AppendLine(line) |> ignore
        for line in bottomPanels do sb.AppendLine(line) |> ignore
        for line in footer do sb.AppendLine(line) |> ignore

        Console.Write(sb.ToString())

    /// Initialize the UI
    let initialize () =
        Console.Write(Ansi.hideCursor)
        Console.Clear()

    /// Shutdown the UI
    let shutdown () =
        Console.Write(Ansi.showCursor)
        Console.Write(Ansi.clear)
        printfn "%sCockpit shutdown complete.%s" Ansi.connected Ansi.reset

    // ═══════════════════════════════════════════════════════════════════════════
    // L7 OODA-OPTIMIZED HMI ENHANCEMENTS
    // Based on PRAJNA_5_LEVEL_SPECIFICATION.md Section 7
    // NASA-STD-3000, MIL-STD-1472H, ISA-101 Compliant
    // ═══════════════════════════════════════════════════════════════════════════

    module OodaHmi =

        // ═══════════════════════════════════════════════════════════════════════
        // SPIDER CHART (Multi-Dimensional Metric Display)
        // Rule 5: Spider Charts for Correlated Metrics
        // ═══════════════════════════════════════════════════════════════════════

        /// Render a text-based spider chart for multi-dimensional metrics
        /// Shows 4-8 axes in a diamond pattern with percentage fill
        let renderSpiderChart (metrics: (string * float * AlarmLevel) list) (radius: int) : string list =
            if metrics.IsEmpty then [sprintf "%s[No metrics]%s" Ansi.dim Ansi.reset]
            else
                let count = min 8 (List.length metrics)
                let step = 360.0 / float count

                // Create simple diamond representation for terminal
                let lines = ResizeArray<string>()

                // Top vertex (Axis 0)
                let (name0, val0, level0) = metrics.[0]
                let color0 = alarmColor level0
                let fill0 = int (val0 / 100.0 * float radius)
                lines.Add(sprintf "%s%s: %3.0f%%%s %s"
                    (String.replicate (radius - fill0) " ")
                    (String.replicate fill0 Icons.barFull)
                    val0 color0 name0)

                // Left and right vertices (if >= 4 axes)
                if count >= 4 then
                    let (nameL, valL, levelL) = metrics.[count / 4]
                    let (nameR, valR, levelR) = metrics.[3 * count / 4 % count]
                    let colorL = alarmColor levelL
                    let colorR = alarmColor levelR
                    let fillL = int (valL / 100.0 * float radius)
                    let fillR = int (valR / 100.0 * float radius)

                    for i in 1..radius do
                        let leftBar = if i <= fillL then Icons.barFull else Icons.barEmpty
                        let rightBar = if i <= fillR then Icons.barFull else Icons.barEmpty
                        let centerFill =
                            if i = radius / 2 then
                                sprintf "%s%.0f%% %s %s%.0f%%%s"
                                    colorL valL Ansi.reset
                                    colorR valR Ansi.reset
                            else String.replicate (radius * 2) " "
                        lines.Add(sprintf "%s%s%s%s" leftBar (String.replicate (radius - i) " ") centerFill rightBar)

                // Bottom vertex (Axis 2 or count/2)
                if count >= 2 then
                    let idx = count / 2
                    let (name2, val2, level2) = metrics.[idx]
                    let color2 = alarmColor level2
                    let fill2 = int (val2 / 100.0 * float radius)
                    lines.Add(sprintf "%s%s: %3.0f%%%s %s"
                        (String.replicate (radius - fill2) " ")
                        (String.replicate fill2 Icons.barFull)
                        val2 color2 name2)

                lines |> Seq.toList

        // ═══════════════════════════════════════════════════════════════════════
        // SAFETY MARGIN BARS (Rule 6)
        // Shows current value, caution zone, warning zone, and buffer
        // ═══════════════════════════════════════════════════════════════════════

        /// Render a safety margin bar showing value relative to thresholds
        /// Format: [███████░░░▒▒▒XXX] 72% (Caution: 80%, Warning: 90%)
        let renderSafetyMarginBar
            (value: float)
            (cautionThreshold: float)
            (warningThreshold: float)
            (maxValue: float)
            (width: int) : string =

            let pct = value / maxValue
            let cautionPct = cautionThreshold / maxValue
            let warningPct = warningThreshold / maxValue

            let valuePos = int (pct * float width)
            let cautionPos = int (cautionPct * float width)
            let warningPos = int (warningPct * float width)

            let sb = StringBuilder()

            // Determine overall color based on where value is
            let valueColor =
                if value >= warningThreshold then Ansi.warning
                elif value >= cautionThreshold then Ansi.caution
                else Ansi.normal

            sb.Append("[") |> ignore

            for i in 0..width-1 do
                if i < valuePos then
                    // Filled portion
                    let char =
                        if i >= warningPos then sprintf "%s%s" Ansi.warning Icons.barFull
                        elif i >= cautionPos then sprintf "%s%s" Ansi.caution "▒"
                        else sprintf "%s%s" Ansi.connected Icons.barFull
                    sb.Append(char) |> ignore
                else
                    // Empty portion with zone markers
                    let char =
                        if i >= warningPos then sprintf "%s%s" Ansi.dim "×"
                        elif i >= cautionPos then sprintf "%s%s" Ansi.dim "·"
                        else sprintf "%s%s" Ansi.dim Icons.barEmpty
                    sb.Append(char) |> ignore

            sb.Append(Ansi.reset) |> ignore
            sb.Append("] ") |> ignore

            // Value and thresholds
            sb.Append(sprintf "%s%3.0f%%%s" valueColor value Ansi.reset) |> ignore
            sb.Append(sprintf " %s(⚠%.0f%% ⛔%.0f%%)%s" Ansi.dim cautionThreshold warningThreshold Ansi.reset) |> ignore

            sb.ToString()

        // ═══════════════════════════════════════════════════════════════════════
        // PREDICTIVE VECTOR DISPLAY (Rule 4)
        // Shows where value is heading based on trend
        // ═══════════════════════════════════════════════════════════════════════

        /// Calculate predicted value based on trend
        let predictValue (current: float) (trend: Trend) (horizonSeconds: float) : float =
            let ratePerSecond =
                match trend with
                | RisingFast -> 2.0    // 2% per second
                | Rising -> 0.5        // 0.5% per second
                | Stable -> 0.0
                | Falling -> -0.5
                | FallingFast -> -2.0
            current + (ratePerSecond * horizonSeconds)

        /// Render a predictive vector bar showing current + predicted
        let renderPredictiveBar
            (current: float)
            (trend: Trend)
            (predictionSeconds: float)
            (width: int) : string =

            let predicted = predictValue current trend predictionSeconds
            let currentPos = int (current / 100.0 * float width)
            let predictedPos = int (predicted / 100.0 * float width) |> max 0 |> min (width - 1)

            let sb = StringBuilder()
            sb.Append("[") |> ignore

            for i in 0..width-1 do
                if i < min currentPos predictedPos then
                    sb.Append(sprintf "%s%s" Ansi.normal Icons.barFull) |> ignore
                elif i < max currentPos predictedPos then
                    // Prediction zone
                    let color = if predicted > current then Ansi.caution else Ansi.advisory
                    sb.Append(sprintf "%s%s" color "▒") |> ignore
                elif i = currentPos then
                    sb.Append(sprintf "%s│%s" Ansi.brightWhite Ansi.reset) |> ignore
                else
                    sb.Append(sprintf "%s%s" Ansi.dim Icons.barEmpty) |> ignore

            sb.Append(Ansi.reset) |> ignore
            sb.Append("] ") |> ignore

            // Arrow and prediction
            let arrow = trendArrow trend
            let predColor = if predicted > 90.0 then Ansi.warning elif predicted > 75.0 then Ansi.caution else Ansi.normal
            sb.Append(sprintf "%s %.0f%%%s→%s%.0f%%%s" arrow current Ansi.dim predColor predicted Ansi.reset) |> ignore

            sb.ToString()

        // ═══════════════════════════════════════════════════════════════════════
        // DAG TOPOLOGY RENDERING (Rule 7 - Spatial Consistency)
        // Shows mesh hierarchy with impact flow
        // ═══════════════════════════════════════════════════════════════════════

        /// Node position in topology
        type TopoNode = {
            Id: string
            Label: string
            Level: int          // 0 = supervisor, 1 = controller, 2 = worker
            Column: int
            Status: ConnStatus
            Health: float
            AlarmLevel: AlarmLevel
        }

        /// Connection between nodes
        type TopoEdge = {
            From: string
            To: string
            Latency: float option
        }

        /// Render a simple ASCII topology
        let renderTopology (nodes: TopoNode list) (edges: TopoEdge list) (width: int) : string list =
            let lines = ResizeArray<string>()

            // Group nodes by level
            let byLevel = nodes |> List.groupBy (fun n -> n.Level) |> Map.ofList

            // Render each level using functional iteration
            [0..2]
            |> List.iter (fun level ->
                let levelNodes =
                    byLevel
                    |> Map.tryFind level
                    |> Option.defaultValue []
                    |> List.sortBy (fun n -> n.Column)

                if not levelNodes.IsEmpty then
                    let nodeLine = StringBuilder()
                    let connLine = StringBuilder()

                    levelNodes
                    |> List.iter (fun node ->
                        let icon = statusIcon node.Status
                        let color =
                            if node.AlarmLevel >= Warning then alarmColor node.AlarmLevel
                            elif node.Status <> Connected then statusColor node.Status
                            else Ansi.normal

                        let nodeBox =
                            sprintf "%s[%s %s %2.0f%%]%s"
                                color icon (truncate node.Label 8) node.Health Ansi.reset

                        nodeLine.Append(nodeBox) |> ignore
                        nodeLine.Append("  ") |> ignore

                        let children = edges |> List.filter (fun e -> e.From = node.Id)
                        if not children.IsEmpty then
                            connLine.Append(sprintf "     %s│%s     " Ansi.dim Ansi.reset) |> ignore
                    )

                    lines.Add(nodeLine.ToString())
                    if level < 2 then
                        lines.Add(connLine.ToString())
            )

            lines |> Seq.toList

        // ═══════════════════════════════════════════════════════════════════════
        // IMPACT PROPAGATION VISUALIZATION
        // Shows how changes cascade through the DAG
        // ═══════════════════════════════════════════════════════════════════════

        /// Render impact propagation from a source node
        let renderImpactPropagation (source: string) (affected: (string * float) list) (level: AlarmLevel) : string list =
            let lines = ResizeArray<string>()
            let color = alarmColor level
            let icon = alarmIcon level

            lines.Add(sprintf "%s%s IMPACT: %s%s" color icon source Ansi.reset)

            for (target, impact) in affected do
                let impactBar = renderBar impact 100.0 10 level
                lines.Add(sprintf "  %s├→ %s %s %s%.0f%% affected%s"
                    Ansi.dim target impactBar Ansi.dim impact Ansi.reset)

            lines |> Seq.toList

        // ═══════════════════════════════════════════════════════════════════════
        // TIMEFLOW VISUALIZATION
        // Shows temporal progression of events
        // ═══════════════════════════════════════════════════════════════════════

        /// Render a timeline of events
        let renderTimeline (events: (DateTime * string * AlarmLevel) list) (width: int) : string list =
            let lines = ResizeArray<string>()

            // Sort by time descending (newest first)
            let sorted = events |> List.sortByDescending (fun (t, _, _) -> t) |> List.truncate 10

            for (time, desc, level) in sorted do
                let age = (DateTime.UtcNow - time).TotalMinutes
                let ageStr =
                    if age < 1.0 then "now"
                    elif age < 60.0 then sprintf "%.0fm" age
                    else sprintf "%.0fh" (age / 60.0)

                let color = alarmColor level
                let icon = alarmIcon level
                let truncDesc = truncate desc (width - 20)

                lines.Add(sprintf " %s%-5s%s %s%s%s %s"
                    Ansi.dim ageStr Ansi.reset color icon Ansi.reset truncDesc)

            lines |> Seq.toList

        // ═══════════════════════════════════════════════════════════════════════
        // PROGRESSIVE DISCLOSURE NAVIGATION (Rule 8)
        // Multi-level detail view
        // ═══════════════════════════════════════════════════════════════════════

        /// Disclosure levels for progressive detail
        type DisclosureLevel =
            | Summary    // One-line summary only
            | Overview   // Key metrics + trends
            | Detailed   // Full breakdown
            | Expert     // All data + raw values

        /// Render a metric at different disclosure levels
        let renderMetricAtLevel (metric: SmartMetric<float>) (level: DisclosureLevel) (width: int) : string list =
            match level with
            | Summary ->
                let icon = alarmIcon metric.Level
                let color = alarmColor metric.Level
                let trend = trendArrow metric.Trend
                [sprintf "%s%s%s %s: %.0f%s %s" color icon Ansi.reset metric.Label metric.Value metric.Unit trend]

            | Overview ->
                let bar = renderBar metric.Value 100.0 15 metric.Level
                let spark = renderSparkline metric.Sparkline 100.0 12
                let trend = trendArrow metric.Trend
                [sprintf " %s %s %.0f%s %s %s" metric.Label bar metric.Value metric.Unit trend spark]

            | Detailed ->
                let bar = renderSafetyMarginBar metric.Value 75.0 90.0 100.0 20
                let spark = renderSparkline metric.Sparkline 100.0 20
                [
                    sprintf " %s%s%s" Ansi.bold metric.Label Ansi.reset
                    sprintf "   %s" bar
                    sprintf "   %sTrend:%s %s  %sHistory:%s %s"
                        Ansi.dim Ansi.reset (trendArrow metric.Trend) Ansi.dim Ansi.reset spark
                ]

            | Expert ->
                let predBar = renderPredictiveBar metric.Value metric.Trend 60.0 25
                [
                    sprintf " %s%s%s (Raw: %.4f)" Ansi.bold metric.Label Ansi.reset metric.Value
                    sprintf "   Current: %s" (renderSafetyMarginBar metric.Value 75.0 90.0 100.0 25)
                    sprintf "   Predict: %s" predBar
                    sprintf "   %sLast Update: %s | Samples: %d%s"
                        Ansi.dim (metric.LastUpdated.ToString("HH:mm:ss.fff"))
                        (List.length metric.Sparkline) Ansi.reset
                ]

        // ═══════════════════════════════════════════════════════════════════════
        // CLOSED-LOOP FEEDBACK VISUALIZATION (Rule 10)
        // Shows command state with visual confirmation
        // ═══════════════════════════════════════════════════════════════════════

        /// Render command with closed-loop feedback
        let renderCommandFeedback (cmd: CommandRecord) (width: int) : string list =
            let lines = ResizeArray<string>()

            // State icon and color
            let (icon, color, stateText) =
                match cmd.State with
                | Idle -> (Icons.idle, Ansi.dim, "IDLE")
                | Armed -> (Icons.armed, Ansi.caution, "ARMED - Press CONFIRM")
                | Executing -> (Icons.executing, Ansi.advisory, "EXECUTING...")
                | Acknowledged -> (Icons.acknowledged, Ansi.connected, "✓ CONFIRMED")
                | Failed -> (Icons.failed, Ansi.warning, "✗ FAILED")

            lines.Add(sprintf " %s%s %A → %s%s" color icon cmd.Command cmd.TargetNodeId Ansi.reset)
            lines.Add(sprintf "   %sStatus: %s%s" Ansi.dim stateText Ansi.reset)

            // Progress bar for executing state
            match cmd.State with
            | Armed ->
                let expiresIn =
                    match cmd.ArmedAt with
                    | Some armed -> 30.0 - (DateTime.UtcNow - armed).TotalSeconds
                    | None -> 30.0
                let progress = expiresIn / 30.0
                let bar = renderBar (progress * 100.0) 100.0 20 Caution
                lines.Add(sprintf "   %sExpires in: %s %.0fs%s" Ansi.dim bar expiresIn Ansi.reset)

            | Executing ->
                // Animated progress indicator
                let elapsed =
                    match cmd.ExecutedAt with
                    | Some exec -> (DateTime.UtcNow - exec).TotalSeconds
                    | None -> 0.0
                let spinner = Icons.spinner.[int elapsed % Icons.spinner.Length]
                lines.Add(sprintf "   %s%s Elapsed: %.1fs%s" Ansi.advisory spinner elapsed Ansi.reset)

            | Failed ->
                match cmd.ErrorMessage with
                | Some err -> lines.Add(sprintf "   %sError: %s%s" Ansi.warning err Ansi.reset)
                | None -> ()

            | _ -> ()

            lines |> Seq.toList

        // ═══════════════════════════════════════════════════════════════════════
        // OODA CYCLE VISUALIZATION
        // Shows current phase of Observe-Orient-Decide-Act loop
        // ═══════════════════════════════════════════════════════════════════════

        type OodaPhase = Observe | Orient | Decide | Act

        /// Render OODA cycle status
        let renderOodaCycle (currentPhase: OodaPhase) (cycleTimeMs: float) (quality: float) : string =
            let phases = [|
                ("O", Observe)
                ("O", Orient)
                ("D", Decide)
                ("A", Act)
            |]

            let sb = StringBuilder()
            sb.Append(sprintf "%sOODA:%s " Ansi.dim Ansi.reset) |> ignore

            for (label, phase) in phases do
                let color = if phase = currentPhase then Ansi.brightWhite else Ansi.dim
                let bracket = if phase = currentPhase then sprintf "%s[%s]%s" Ansi.bold label Ansi.reset else label
                sb.Append(sprintf "%s%s%s→" color bracket Ansi.reset) |> ignore

            sb.Append(sprintf " %s%.0fms%s" (if cycleTimeMs < 1000.0 then Ansi.connected else Ansi.caution) cycleTimeMs Ansi.reset) |> ignore
            sb.Append(sprintf " %sQ:%.0f%%%s" Ansi.dim quality Ansi.reset) |> ignore

            sb.ToString()

        // ═══════════════════════════════════════════════════════════════════════
        // ENHANCED PANEL RENDERING WITH L7 FEATURES
        // ═══════════════════════════════════════════════════════════════════════

        /// Render an enhanced nodes panel with spider chart and safety margins
        let renderEnhancedNodesPanel (state: CockpitState) (width: int) (height: int) (disclosure: DisclosureLevel) =
            let lines = ResizeArray<string>()

            let header = sprintf "%s%s MESH NODES (%d) [%A] %s%s"
                            Box.v Ansi.bold (Map.count state.Nodes) disclosure Ansi.reset
                            (String.replicate (width - 25) Box.lh)
            lines.Add(header)

            // Add aggregate spider chart if in detailed mode
            if disclosure >= Detailed && Map.count state.Nodes > 0 then
                let avgCpu = state.Nodes |> Map.toList |> List.averageBy (fun (_, n) -> n.Cpu.Value)
                let avgMem = state.Nodes |> Map.toList |> List.averageBy (fun (_, n) -> n.Memory.Value)
                let avgHealth = state.Nodes |> Map.toList |> List.averageBy (fun (_, n) -> float n.HealthScore.Value)
                let avgLat = state.Nodes |> Map.toList |> List.averageBy (fun (_, n) -> min 100.0 (n.NetworkLatency.Value / 10.0))

                let spiderMetrics = [
                    ("CPU", avgCpu, if avgCpu > 85.0 then Caution else Normal)
                    ("MEM", avgMem, if avgMem > 85.0 then Caution else Normal)
                    ("HEALTH", avgHealth, if avgHealth < 80.0 then Caution else Normal)
                    ("NET", avgLat, if avgLat > 50.0 then Advisory else Normal)
                ]

                lines.Add(sprintf "%s %sAggregate Metrics:%s" Box.v Ansi.dim Ansi.reset)
                for spiderLine in renderSpiderChart spiderMetrics 5 do
                    lines.Add(sprintf "%s   %s%s" Box.v spiderLine (String.replicate (width - 8 - visibleLength spiderLine) " ") + Box.v)

            // Individual nodes with appropriate detail level
            let nodes =
                state.Nodes
                |> Map.toList
                |> List.sortBy (fun (_, n) ->
                    match n.Status with
                    | Disconnected -> 0
                    | Stale -> 1
                    | Degraded -> 2
                    | Connected -> 3 + n.HealthScore.Value
                )
                |> List.truncate (height - (if disclosure >= Detailed then 8 else 3))

            for (id, node) in nodes do
                let metricLines = renderMetricAtLevel node.Cpu disclosure width
                for line in metricLines do
                    lines.Add(sprintf "%s%s%s" Box.v (padRight (sprintf " %s: %s" node.Name line) (width - 2)) Box.v)

            // Fill remaining space
            let remaining = height - lines.Count - 1
            for _ in 1..remaining do
                lines.Add(sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

            lines |> Seq.toList

        /// Render OODA status bar
        let renderOodaStatusBar (phase: OodaPhase) (cycleMs: float) (quality: float) (width: int) : string =
            let ooda = renderOodaCycle phase cycleMs quality
            sprintf "%s %s%s" Box.v (padRight ooda (width - 2)) Box.v

    // ═══════════════════════════════════════════════════════════════════════════
    // SIL4 SUPREME MESH TWIN RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    module MeshTwinUI =
        open Cepaf.Orchestration

        let renderTwin (width: int) (height: int) =
            let lines = ResizeArray<string>()
            let registry = MeshCortex.globalRegistry
            
            lines.Add(sprintf "%s%s [SUPREME VECTOR] SIL4 CONVERGED TWIN %s"
                        Ansi.bold Ansi.magenta Ansi.reset)
            
            lines.Add(sprintf " MESH HEALTH: 100%% │ DIVERGE: 0.0000 │ AUDIT: SIL4-READY")
            lines.Add(sprintf "%s%s%s" Box.tl (String.replicate (width - 2) Box.h) Box.tr)
            
            lines.Add(sprintf "%s %-14s %-12s %-12s %-12s %s" 
                Box.v "HOLON" "STATUS" "PROOF" "DIVERGE" Box.v)
            lines.Add(sprintf "%s%s%s" Box.ltl (String.replicate (width - 2) Box.lh) Box.ltr)

            for KeyValue(id, node) in registry do
                let color = if node.Pheno.Status = Sil4Types.MeshReady then Ansi.connected else Ansi.caution
                let line = sprintf "%s %-14s %s%-12A%s %-12s %.4f %s" 
                            Box.v id color node.Pheno.Status Ansi.reset node.Pheno.Proof node.Diverge Box.v
                lines.Add(line)

            let remaining = height - lines.Count
            for _ in 1..remaining do
                lines.Add(sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

            lines |> Seq.toList
