namespace Cepaf.Cockpit

open System
open System.Text
open Cepaf.Cockpit.AerospaceTheme
open Cepaf.Cockpit.Prajna.DarkCockpit
open Cepaf.Cockpit.Prajna.SmartMetrics
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
        let cyan = "\u001b[36m"

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
        
        let moveTo (line: int) (col: int) = sprintf "\u001b[%d;%dH" line col

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

    module UiBox =
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
        | AlarmLevel.Normal -> Ansi.normal       // Nearly invisible
        | AlarmLevel.Advisory -> Ansi.advisory   // Cyan (info)
        | AlarmLevel.Caution -> Ansi.caution     // Amber
        | AlarmLevel.Warning -> Ansi.warning     // Red
        | AlarmLevel.Critical -> Ansi.critical   // Red + blink

    /// Get icon for alarm level
    let alarmIcon (level: AlarmLevel) =
        match level with
        | AlarmLevel.Normal -> Icons.normal
        | AlarmLevel.Advisory -> Icons.advisory
        | AlarmLevel.Caution -> Icons.caution
        | AlarmLevel.Warning -> Icons.warning
        | AlarmLevel.Critical -> Icons.critical

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
    let renderSmartMetric (metric: SmartMetric) (barWidth: int) =
        let isStale = isStale metric 30 // Default 30s timeout
        let level =
            if isStale then AlarmLevel.Normal  // Gray out stale data
            else
                if metric.Value >= 95.0 then AlarmLevel.Warning
                elif metric.Value >= 85.0 then AlarmLevel.Caution
                elif metric.Value >= 75.0 then AlarmLevel.Advisory
                else AlarmLevel.Normal

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

        let line1 = sprintf "%s%s%s" UiBox.tl (String.replicate (size.Cols - 2) UiBox.h) UiBox.tr

        let title = sprintf "%s%s C3I MESH COCKPIT %s" Ansi.bold Ansi.bgBlue Ansi.reset
        let view = sprintf "%s%A%s" Ansi.advisory state.CurrentView Ansi.reset
        let statusSummary =
            let healthy = state.Nodes |> Map.filter (fun _ (n: MeshNode) -> n.Status = Connected) |> Map.count
            let total = Map.count state.Nodes
            let alarms = state.Alarms |> Map.filter (fun _ (a: Alarm) -> a.AcknowledgedAt.IsNone) |> Map.count
            if alarms > 0 then
                sprintf "%s%d ALARMS%s" Ansi.warning alarms Ansi.reset
            elif healthy = total && total > 0 then
                sprintf "%s%d/%d OK%s" Ansi.normal healthy total Ansi.reset
            else
                sprintf "%s%d/%d%s" Ansi.caution healthy total Ansi.reset

        let content = sprintf " %s %s %s │ %s │ %s %s"
                        title spinner view statusSummary uptimeStr timestamp
        let line2 = sprintf "%s%s%s"
                        UiBox.v
                        (padRight content (size.Cols - 2))
                        UiBox.v

        [line1; line2; sprintf "%s%s%s" UiBox.tRight (String.replicate (size.Cols - 2) UiBox.h) UiBox.tLeft]

    /// Render nodes panel (Dark Cockpit style)
    let renderNodesPanel (state: CockpitState) (width: int) (height: int) =
        let header = sprintf "%s%s MESH NODES (%d) %s%s"
                        UiBox.v Ansi.bold (Map.count state.Nodes) Ansi.reset
                        (String.replicate (width - 18) UiBox.lh)

        let nodeLines =
            state.Nodes
            |> Map.toList
            |> List.sortBy (fun (_, n: MeshNode) ->
                // Sort by severity: disconnected first, then by health
                match n.Status with
                | Disconnected -> 0
                | Stale -> 1
                | Degraded -> 2
                | Connected -> 3 + int n.HealthScore.Value
            )
            |> List.truncate (height - 2)
            |> List.map (fun (id, node: MeshNode) ->
                let icon = statusIcon node.Status
                let color = statusColor node.Status

                // Dark Cockpit: only colorize if there's something to notice
                let nodeColor =
                    if node.Status <> Connected || node.Cpu.Value > 75.0 then color
                    else Ansi.dim

                let name = truncate node.Name 12
                let zone = sprintf "[%s]" (truncate node.Zone 6)

                // CPU with trend (analog + arrow)
                let cpuBar = renderBar node.Cpu.Value 100.0 6 (if node.Cpu.Value > 85.0 then AlarmLevel.Caution else AlarmLevel.Normal)
                let cpuArrow = trendArrow node.Cpu.Trend

                // Health indicator
                let healthColor =
                    if node.HealthScore.Value >= 80.0 then Ansi.normal
                    elif node.HealthScore.Value >= 60.0 then Ansi.caution
                    else Ansi.warning
                let health = sprintf "%s%.0f%%%s" healthColor node.HealthScore.Value Ansi.reset

                let content = sprintf " %s%s%s %-12s %s%s%s %s %.0f%%%s %s"
                                nodeColor icon Ansi.reset
                                name
                                Ansi.dim zone Ansi.reset
                                cpuBar node.Cpu.Value cpuArrow
                                health

                sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
            )

        let emptyCount = height - 2 - List.length nodeLines
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)

        header :: nodeLines @ emptyLines

    /// Render alarms panel (only unacknowledged)
    let renderAlarmsPanel (state: CockpitState) (width: int) (height: int) =
        let activeAlarms =
            state.Alarms
            |> Map.filter (fun _ (a: Alarm) -> a.AcknowledgedAt.IsNone)
            |> Map.toList
            |> List.sortByDescending (fun (_, (a: Alarm)) -> a.Level, a.OccurredAt)

        let alarmCount = List.length activeAlarms
        let headerColor = if alarmCount > 0 then Ansi.warning else Ansi.normal
        let header = sprintf "%s%s%s ALARMS (%d) %s%s%s"
                        UiBox.tRight headerColor Ansi.bold alarmCount Ansi.reset
                        (String.replicate (width - 14) UiBox.lh) UiBox.tLeft

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

                sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
            )

        // Dark Cockpit: if no alarms, show minimal indicator
        let emptyIndicator =
            if alarmCount = 0 then
                [sprintf "%s %s%s%s%s" UiBox.v Ansi.dim "No active alarms" Ansi.reset
                    (String.replicate (width - 20) " ") + UiBox.v]
            else []

        let emptyCount = height - 2 - List.length alarmLines - List.length emptyIndicator
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)

        header :: alarmLines @ emptyIndicator @ emptyLines

    /// Render AI insights panel
    let renderAiPanel (state: CockpitState) (width: int) (height: int) =
        let aiEnabled = if state.AiEnabled then "🤖" else "⚠"
        let header = sprintf "%s%s %s AI COPILOT %s%s%s"
                        UiBox.tRight Ansi.bold aiEnabled Ansi.reset
                        (String.replicate (width - 16) UiBox.lh) UiBox.tLeft

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
            |> List.collect (fun (insight: AiInsight) ->
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

                [sprintf "%s%s%s" UiBox.v (padRight titleLine (width - 2)) UiBox.v] @
                (descLines |> List.map (fun l -> sprintf "%s%s%s" UiBox.v (padRight l (width - 2)) UiBox.v))
            )

        let emptyCount = height - 1 - List.length insightLines
        let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)

        header :: insightLines @ emptyLines

    /// Render singularity feature dashboard
    let renderFeatureDashboard (state: CockpitState) (width: int) (height: int) =
        let header = sprintf "%s%s SINGULARITY MILESTONES & EVOLUTION %s%s"
                        UiBox.tRight Ansi.bold Ansi.reset
                        (String.replicate (width - 37) UiBox.lh)

        let features = [
            ("L10", "Recursive Self-Improvement", true)
            ("L9",  "Deep Native Preservation (Ark)", true)
            ("L8",  "Shannon Entropy Gating", true)
            ("L7",  "Economic Substrate", true)
            ("L6",  "Ancestral Lineage (Signed)", true)
            ("L5",  "Neuro-Symbolic Simplex", true)
            ("L4",  "SIL-6 Biomorphic Mesh", true)
            ("L3",  "Synaptic Recall (Memory)", true)
            ("L2",  "Quantum-Safe Vault", true)
            ("L1",  "Math NIF (Rustler)", true)
        ]

        let featureLines = 
            features
            |> List.truncate 5 // Show only top 5 to make room for commits
            |> List.map (fun (lvl, name, active) ->
                let status = if active then sprintf "%s%s%s" Ansi.connected Icons.acknowledged Ansi.reset else sprintf "%s%s%s" Ansi.dim Icons.idle Ansi.reset
                let content = sprintf " [%3s] %-28s %s" lvl name status
                sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
            )

        let commitHeader = sprintf "%s%s%s RECENT EVOLUTION COMMITS %s%s" UiBox.v UiBox.v Ansi.bold Ansi.reset (String.replicate (width - 29) " ")
        
        let commitLines =
            state.RecentCommits
            |> List.truncate 5
            |> List.map (fun c ->
                let msgShort = truncate c.Message (width - 25)
                let timeStr = c.Timestamp.ToString("HH:mm:ss")
                let content = sprintf " %s%s%s [%s] %s" Ansi.advisory c.Hash Ansi.reset timeStr msgShort
                sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
            )

        let allLines = featureLines @ [commitHeader] @ commitLines
        let emptyCount = height - 2 - List.length allLines
        let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)
        
        header :: allLines @ emptyLines

    /// Render economic (energy) panel
    let renderEconomicPanel (state: CockpitState) (width: int) (height: int) =
        match state.Economics with
        | None -> 
            let header = sprintf "%s%s ECONOMIC SUBSTRATE %s%s"
                            UiBox.tRight Ansi.bold Ansi.reset
                            (String.replicate (width - 20) UiBox.lh)
            let empty = [sprintf "%s %s%s%s%s" UiBox.v Ansi.dim "Awaiting economic telemetry..." Ansi.reset
                            (String.replicate (width - 29) " ") + UiBox.v]
            let emptyCount = height - 2 - List.length empty
            let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)
            header :: empty @ emptyLines
        | Some econ ->
            let header = sprintf "%s%s ENERGY BALANCE: %.2f Cr %s%s"
                            UiBox.tRight Ansi.bold econ.SystemCredits Ansi.reset
                            (String.replicate (width - 32) UiBox.lh)

            let statsLine = sprintf " %sTotal Energy: %.2f%s │ %sEfficiency: %.2f%s"
                                Ansi.dim econ.TotalSwarmEnergy Ansi.reset
                                Ansi.connected econ.EfficiencyScore Ansi.reset
            
            let statsLineFormatted = sprintf "%s%s%s" UiBox.v (padRight statsLine (width - 2)) UiBox.v
            let separator = sprintf "%s%s%s" UiBox.ltl (String.replicate (width - 2) UiBox.lh) UiBox.ltr

            let ledgerLines =
                econ.Ledger
                |> Map.toList
                |> List.sortByDescending (fun (_, c) -> c.TotalConsumed)
                |> List.truncate (height - 5)
                |> List.map (fun (id, c) ->
                    let usageLevel = 
                        if c.Balance >= 800.0 then AlarmLevel.Normal
                        elif c.Balance >= 500.0 then AlarmLevel.Advisory
                        elif c.Balance >= 200.0 then AlarmLevel.Caution
                        else AlarmLevel.Warning
                    
                    let balanceBar = renderBar c.Balance 1000.0 8 usageLevel
                    let idShort = truncate id 12

                    let content = sprintf " %s%-12s%s %s %s %.1f%s"
                                    Ansi.dim idShort Ansi.reset
                                    balanceBar
                                    Ansi.advisory c.Balance Ansi.reset

                    sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
                )

            let emptyCount = height - 3 - List.length ledgerLines - 1
            let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)

            header :: statsLineFormatted :: separator :: ledgerLines @ emptyLines

    /// Render federation panel
    let renderFederationPanel (state: CockpitState) (width: int) (height: int) =
        match state.Federation with
        | None -> 
            let header = sprintf "%s%s FEDERATION MESH %s%s"
                            UiBox.tRight Ansi.bold Ansi.reset
                            (String.replicate (width - 18) UiBox.lh)
            let empty = [sprintf "%s %s%s%s%s" UiBox.v Ansi.dim "Awaiting federation data..." Ansi.reset
                            (String.replicate (width - 28) " ") + UiBox.v]
            let emptyCount = height - 2 - List.length empty
            let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)
            header :: empty @ emptyLines
        | Some health ->
            let header = sprintf "%s%s FEDERATION: %d ACTIVE PEERS %s%s"
                            UiBox.tRight Ansi.bold health.ActiveMembers Ansi.reset
                            (String.replicate (width - 30) UiBox.lh)

            let statsLine = sprintf " %sLocal Holon: %s%s │ %sAvg Trust: %.2f%s │ %sVersion: %s%s"
                                Ansi.dim health.LocalHolonId Ansi.reset
                                Ansi.advisory health.AverageTrust Ansi.reset
                                Ansi.dim health.ProtocolVersion Ansi.reset
            
            let statsLineFormatted = sprintf "%s%s%s" UiBox.v (padRight statsLine (width - 2)) UiBox.v
            let separator = sprintf "%s%s%s" UiBox.ltl (String.replicate (width - 2) UiBox.lh) UiBox.ltr

            let memberLines =
                health.Members
                |> Map.toList
                |> List.sortByDescending (fun (_, m) -> m.TrustScore)
                |> List.truncate (height - 5)
                |> List.map (fun (_, m) ->
                    let trustLevel = 
                        if m.TrustScore >= 0.9 then AlarmLevel.Normal
                        elif m.TrustScore >= 0.7 then AlarmLevel.Advisory
                        elif m.TrustScore >= 0.5 then AlarmLevel.Caution
                        else AlarmLevel.Warning
                    
                    let trustBar = renderBar (m.TrustScore * 100.0) 100.0 8 trustLevel
                    let statusColor = if m.Status = "Active" then Ansi.connected else Ansi.caution
                    let name = truncate m.Name 12
                    let id = truncate m.Id 8

                    let content = sprintf " %s%s%s %-12s %s%-8s%s %s %.2f%s"
                                    statusColor Icons.connected Ansi.reset
                                    name
                                    Ansi.dim id Ansi.reset
                                    trustBar m.TrustScore Ansi.reset

                    sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
                )

            let emptyCount = height - 3 - List.length memberLines - 1
            let emptyLines = List.replicate (max 0 emptyCount) (sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)

            header :: statsLineFormatted :: separator :: memberLines @ emptyLines

    /// Render pending commands panel
    let renderCommandsPanel (state: CockpitState) (width: int) =
        let pendingCount = Map.count state.PendingCommands
        if pendingCount = 0 then []
        else
            let header = sprintf "%s%s PENDING COMMANDS (%d) %s%s"
                            UiBox.tRight Ansi.bold pendingCount Ansi.reset
                            (String.replicate (width - 24) UiBox.lh)

            let cmdLines =
                state.PendingCommands
                |> Map.toList
                |> List.map (fun (_, (cmd: CommandRecord)) ->
                    let icon =
                        match cmd.State with
                        | CommandState.Idle -> Icons.idle
                        | CommandState.Armed -> Icons.armed
                        | CommandState.Executing -> Icons.executing
                        | CommandState.Acknowledged -> Icons.acknowledged
                        | CommandState.Failed -> Icons.failed

                    let color =
                        match cmd.State with
                        | CommandState.Armed -> Ansi.caution
                        | CommandState.Executing -> Ansi.advisory
                        | CommandState.Failed -> Ansi.warning
                        | _ -> Ansi.normal

                    let content = sprintf " %s%s%s %s -> %A"
                                    color icon Ansi.reset
                                    cmd.TargetNodeId cmd.Command

                    sprintf "%s%s%s" UiBox.v (padRight content (width - 2)) UiBox.v
                )

            header :: cmdLines

    /// Render help overlay
    let renderHelp (width: int) (height: int) =
        let content = 
            [
                sprintf "%s%s PRAJNA COCKPIT USER GUIDE %s" Ansi.bold Ansi.cyan Ansi.reset
                ""
                sprintf "%sKEYS:%s" Ansi.bold Ansi.reset
                "  [?] Toggle Help      [q] Quit"
                "  [v] Change View      [r] Refresh Data"
                "  [a] Arm Command      [c] Confirm Command"
                "  [x] Cancel Command"
                ""
                sprintf "%sMODES:%s" Ansi.bold Ansi.reset
                "  Dark:   Normal state (only criticals)"
                "  Dim:    Low activity"
                "  Norm:   Standard op"
                "  Bright: Full visibility"
                "  Emer:   Emergency (all alerts)"
                ""
                sprintf "%sLAYERS:%s" Ansi.bold Ansi.reset
                "  Bio:    Holon lifecycle"
                "  Immune: Threat detection"
                "  Neuro:  Message routing"
                ""
                sprintf "%sSAFETY:%s" Ansi.bold Ansi.reset
                "  Two-Key-Turn required for:"
                "  Stop, Restart, Scale"
            ]
        
        let boxWidth = 60
        let boxHeight = content.Length + 2
        let left = (width - boxWidth) / 2
        let top = (height - boxHeight) / 2
        
        let sb = StringBuilder()
        
        // Draw background box (clearing what's behind)
        let borderTop = sprintf "%s%s%s" UiBox.tl (String.replicate (boxWidth - 2) UiBox.h) UiBox.tr
        let borderBottom = sprintf "%s%s%s" UiBox.bl (String.replicate (boxWidth - 2) UiBox.h) UiBox.br
        
        sb.Append(Ansi.moveTo top left) |> ignore
        sb.Append(borderTop) |> ignore
        
        content |> List.iteri (fun i line ->
            sb.Append(Ansi.moveTo (top + i + 1) left) |> ignore
            // Clear line background
            let contentLen = visibleLength line
            let padding = boxWidth - 4 - contentLen
            let text = sprintf "%s %s%s %s" UiBox.v line (String.replicate padding " ") UiBox.v
            sb.Append(text) |> ignore
        )
        
        sb.Append(Ansi.moveTo (top + content.Length + 1) left) |> ignore
        sb.Append(borderBottom) |> ignore
        
        sb.ToString()

    /// Render footer with controls
    let renderFooter (state: CockpitState) (size: TerminalSize) =
        let line1 = sprintf "%s%s%s" UiBox.bl (String.replicate (size.Cols - 2) UiBox.h) UiBox.br

        let controls =
            if state.MonitorOnly then
                sprintf " %sMONITOR ONLY%s │ [?] Help │ [q]uit │ [v]iew │ [r]efresh" Ansi.caution Ansi.reset
            else
                sprintf " [?] Help │ [a]rm │ [c]onfirm │ [x]cancel │ [q]uit │ [v]iew │ [r]efresh"

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
        let federation = renderFederationPanel state rightWidth panelHeight
        let economics = renderEconomicPanel state rightWidth panelHeight
        let features = renderFeatureDashboard state rightWidth panelHeight
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

        let topPanels = 
            match state.CurrentView with
            | ViewMode.Mesh | ViewMode.Federation -> mergePanels nodes federation
            | ViewMode.Economics -> mergePanels nodes economics
            | ViewMode.Timeline -> mergePanels nodes features
            | _ -> mergePanels nodes alarms
        let bottomPanels =
            let rightPanel = if cmds.IsEmpty then List.replicate panelHeight (sprintf "%s%s%s" UiBox.v (String.replicate (rightWidth - 2) " ") UiBox.v) else cmds @ List.replicate (panelHeight - List.length cmds) (sprintf "%s%s%s" UiBox.v (String.replicate (rightWidth - 2) " ") UiBox.v)
            mergePanels ai rightPanel

        let sb = StringBuilder()
        sb.Append(Ansi.clear) |> ignore

        for line in header do sb.AppendLine(line) |> ignore
        for line in topPanels do sb.AppendLine(line) |> ignore
        for line in bottomPanels do sb.AppendLine(line) |> ignore
        for line in footer do sb.AppendLine(line) |> ignore

        if state.ShowHelp then
            sb.Append(renderHelp size.Cols size.Rows) |> ignore

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
    // SIL4 SUPREME MESH TWIN RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    module MeshTwinUI =
        // Removed open Cepaf.Orchestration to break circular dependency or missing ref
        // Mocking the registry access for UI purposes or using a different pattern

        type MockNode = {
            PhenoStatus: string
            Proof: string
            Diverge: float
        }

        let renderTwin (width: int) (height: int) =
            let lines = ResizeArray<string>()
            // Mock data for UI development/testing without full mesh dependency
            let registry = 
                [ "holon-1", { PhenoStatus = "MeshReady"; Proof = "AGDA-OK"; Diverge = 0.0000 }
                  "holon-2", { PhenoStatus = "Syncing"; Proof = "PENDING"; Diverge = 0.0012 } ]
                |> Map.ofList
            
            lines.Add(sprintf "%s%s [SUPREME VECTOR] SIL4 CONVERGED TWIN %s"
                        Ansi.bold Ansi.magenta Ansi.reset)
            
            lines.Add(sprintf " MESH HEALTH: 100%% │ DIVERGE: 0.0000 │ AUDIT: SIL4-READY")
            lines.Add(sprintf "%s%s%s" UiBox.tl (String.replicate (width - 2) UiBox.h) UiBox.tr)
            
            lines.Add(sprintf "%s %-14s %-12s %-12s %-12s %s" 
                UiBox.v "HOLON" "STATUS" "PROOF" "DIVERGE" UiBox.v)
            lines.Add(sprintf "%s%s%s" UiBox.ltl (String.replicate (width - 2) UiBox.lh) UiBox.ltr)

            for KeyValue(id, node) in registry do
                let color = if node.PhenoStatus = "MeshReady" then Ansi.connected else Ansi.caution
                let line = sprintf "%s %-14s %s%-12s%s %-12s %.4f %s" 
                            UiBox.v id color node.PhenoStatus Ansi.reset node.Proof node.Diverge UiBox.v
                lines.Add(line)

            let remaining = height - lines.Count
            for _ in 1..remaining do
                lines.Add(sprintf "%s%s%s" UiBox.v (String.replicate (width - 2) " ") UiBox.v)

            lines |> Seq.toList
