#!/usr/bin/env dotnet fsi
// ═══════════════════════════════════════════════════════════════════════════════
// FRACTAL KNOWLEDGE INGESTION COCKPIT v20.0.0
// ═══════════════════════════════════════════════════════════════════════════════
// A Bio-Inspired, Dark Cockpit TUI for Document Processing
// Leveraging Material 3 Design + NASA-STD-3000 HMI Standards
// ═══════════════════════════════════════════════════════════════════════════════

open System
open System.IO
open System.Text
open System.Collections.Concurrent
open System.Diagnostics
open System.Text.RegularExpressions

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI DESIGN SYSTEM (Material 3 Dark + Safety-Critical)
// ═══════════════════════════════════════════════════════════════════════════════

module Theme =
    // Reset
    let reset = "\u001b[0m"
    let bold = "\u001b[1m"
    let dim = "\u001b[2m"
    let italic = "\u001b[3m"
    let blink = "\u001b[5m"

    // Material 3 Dark Primary
    let primary = "\u001b[38;2;208;188;255m"      // D0BCFF - Light purple
    let onPrimary = "\u001b[38;2;56;30;114m"      // 381E72
    let secondary = "\u001b[38;2;204;194;220m"    // CCC2DC
    let tertiary = "\u001b[38;2;3;218;198m"       // 03DAC6 - Teal

    // Safety-Critical (Dark Cockpit)
    let normal = "\u001b[90m"                      // Gray - invisible
    let advisory = "\u001b[38;2;3;218;198m"       // Teal
    let caution = "\u001b[38;2;255;179;0m"        // Amber
    let warning = "\u001b[38;2;207;102;121m"      // Red
    let critical = "\u001b[38;2;207;102;121;5m"   // Red + blink

    // Status
    let connected = "\u001b[32m"
    let stale = "\u001b[90m"
    let disconnected = "\u001b[31m"

    // Surface
    let surface = "\u001b[38;2;28;27;31m"
    let onSurface = "\u001b[38;2;230;225;229m"
    let outline = "\u001b[38;2;147;143;153m"

    // Background
    let bgPrimary = "\u001b[48;2;79;55;139m"
    let bgSecondary = "\u001b[48;2;74;68;88m"
    let bgSurface = "\u001b[48;2;28;27;31m"

    // Control
    let clear = "\u001b[2J\u001b[H"
    let hideCursor = "\u001b[?25l"
    let showCursor = "\u001b[?25h"

// ═══════════════════════════════════════════════════════════════════════════════
// ICONS & BOX DRAWING
// ═══════════════════════════════════════════════════════════════════════════════

module Icons =
    // Status
    let connected = "●"
    let stale = "◐"
    let disconnected = "○"

    // Trend
    let rising = "↑"
    let risingFast = "↑↑"
    let falling = "↓"
    let fallingFast = "↓↓"
    let stable = "→"

    // Alarm
    let normal = "·"
    let advisory = "ℹ"
    let caution = "⚠"
    let warning = "⛔"
    let critical = "☢"

    // Progress
    let barFull = "█"
    let barMid = "▓"
    let barLow = "▒"
    let barEmpty = "░"

    // Sparkline
    let spark = [| "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█" |]

    // Phases
    let phases = [| "◉"; "◎"; "○"; "○"; "○" |]

    // Spinner
    let spinner = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]

    // Brain/Knowledge
    let brain = "🧠"
    let book = "📚"
    let dna = "🧬"
    let crystal = "💎"
    let lightning = "⚡"
    let rocket = "🚀"
    let target = "🎯"
    let check = "✓"
    let cross = "✗"

module Box =
    let tl = "╔"
    let tr = "╗"
    let bl = "╚"
    let br = "╝"
    let h = "═"
    let v = "║"
    let tRight = "╠"
    let tLeft = "╣"
    let tDown = "╦"
    let tUp = "╩"
    let cross = "╬"

    // Rounded (Card style)
    let rtl = "╭"
    let rtr = "╮"
    let rbl = "╰"
    let rbr = "╯"
    let rh = "─"
    let rv = "│"

// ═══════════════════════════════════════════════════════════════════════════════
// DOMAIN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

type FractalLevel = L1 | L2 | L3 | L4 | L5 | L6 | L7

type DocumentCategory =
    | Plan
    | FormalSpec of language: string
    | Journal
    | Architecture
    | Unknown

type PipelinePhase =
    | Discovery
    | Sampling
    | Classification
    | Parsing
    | Transformation
    | Mapping
    | Indexing
    | Complete

type Trend = Rising | RisingFast | Falling | FallingFast | Stable

type DocumentResult = {
    Path: string
    Category: DocumentCategory
    Size: int64
    Lines: int
    Headings: int
    CodeBlocks: int
    Links: int
    Entropy: float
    ProcessingUs: int64
    AsIsPattern: string
    ToBeStructure: string
}

type PipelineMetrics = {
    Phase: PipelinePhase
    DocsProcessed: int
    DocsTotal: int
    BytesProcessed: int64
    ElapsedMs: float
    Throughput: float
    ThroughputHistory: float list
    ErrorCount: int
    Trend: Trend
}

type KnowledgeNode = {
    Structure: string
    DocumentCount: int
    TotalSize: int64
    AvgEntropy: float
    Color: string
}

type CockpitState = {
    Phase: PipelinePhase
    Metrics: PipelineMetrics
    Documents: DocumentResult list
    KnowledgeMap: Map<string, KnowledgeNode>
    RecentLogs: (DateTime * string * FractalLevel) list
    StartTime: DateTime
    TargetMs: float
    SpinnerFrame: int
    Cols: int
    Rows: int
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDERING HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

let ansiRegex = Regex(@"\x1b\[[0-9;]*m")
let visibleLength (s: string) = ansiRegex.Replace(s, "").Length

let padRight (s: string) (width: int) =
    let vlen = visibleLength s
    if vlen < width then s + String.replicate (width - vlen) " "
    elif vlen > width then s.Substring(0, width)
    else s

let truncate (s: string) (maxLen: int) =
    if s.Length <= maxLen then s
    else s.Substring(0, maxLen - 3) + "..."

let formatDuration (ms: float) =
    if ms < 1000.0 then sprintf "%.0fms" ms
    elif ms < 60000.0 then sprintf "%.1fs" (ms / 1000.0)
    else sprintf "%.1fm" (ms / 60000.0)

let phaseIcon (phase: PipelinePhase) =
    match phase with
    | Discovery -> "🔍"
    | Sampling -> "📊"
    | Classification -> "🏷️"
    | Parsing -> "📖"
    | Transformation -> "🔄"
    | Mapping -> "🗺️"
    | Indexing -> "📇"
    | Complete -> "✅"

let phaseColor (phase: PipelinePhase) =
    match phase with
    | Discovery -> Theme.advisory
    | Sampling -> Theme.tertiary
    | Classification -> Theme.primary
    | Parsing -> Theme.secondary
    | Transformation -> Theme.caution
    | Mapping -> Theme.advisory
    | Indexing -> Theme.tertiary
    | Complete -> Theme.connected

let levelPrefix (level: FractalLevel) =
    match level with
    | L1 -> sprintf "%s[L1]%s" Theme.dim Theme.reset
    | L2 -> sprintf "%s[L2]%s" Theme.normal Theme.reset
    | L3 -> sprintf "%s[L3]%s" Theme.advisory Theme.reset
    | L4 -> sprintf "%s[L4]%s" Theme.tertiary Theme.reset
    | L5 -> sprintf "%s[L5]%s" Theme.primary Theme.reset
    | L6 -> sprintf "%s[L6]%s" Theme.caution Theme.reset
    | L7 -> sprintf "%s[L7]%s" Theme.warning Theme.reset

// ═══════════════════════════════════════════════════════════════════════════════
// VISUALIZATION COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Render sparkline
let renderSparkline (values: float list) (width: int) =
    if values.IsEmpty then String.replicate width "·"
    else
        let maxVal = List.max values |> max 1.0
        values
        |> List.rev
        |> List.truncate width
        |> List.rev
        |> List.map (fun v ->
            let idx = int (v / maxVal * 7.0) |> max 0 |> min 7
            Icons.spark.[idx])
        |> String.concat ""
        |> fun s -> if s.Length < width then String.replicate (width - s.Length) "·" + s else s

/// Render progress bar with gradient
let renderProgressBar (value: float) (maxVal: float) (width: int) =
    let pct = value / maxVal |> max 0.0 |> min 1.0
    let filled = int (pct * float width)
    let empty = width - filled

    let fillColor =
        if pct >= 0.9 then Theme.connected
        elif pct >= 0.6 then Theme.advisory
        elif pct >= 0.3 then Theme.caution
        else Theme.warning

    let filledPart = String.replicate filled Icons.barFull
    let emptyPart = String.replicate empty Icons.barEmpty
    sprintf "%s%s%s%s%s" fillColor filledPart Theme.dim emptyPart Theme.reset

/// Render trend arrow
let renderTrend (trend: Trend) =
    match trend with
    | RisingFast -> sprintf "%s%s%s" Theme.connected Icons.risingFast Theme.reset
    | Rising -> sprintf "%s%s%s" Theme.advisory Icons.rising Theme.reset
    | Stable -> sprintf "%s%s%s" Theme.normal Icons.stable Theme.reset
    | Falling -> sprintf "%s%s%s" Theme.caution Icons.falling Theme.reset
    | FallingFast -> sprintf "%s%s%s" Theme.warning Icons.fallingFast Theme.reset

/// Render phase indicator (pipeline progress)
let renderPhaseIndicator (currentPhase: PipelinePhase) =
    let phases = [Discovery; Sampling; Classification; Parsing; Transformation; Mapping; Indexing; Complete]
    let currentIdx = phases |> List.findIndex ((=) currentPhase)

    phases
    |> List.mapi (fun i phase ->
        let icon = phaseIcon phase
        if i < currentIdx then sprintf "%s%s%s" Theme.connected icon Theme.reset
        elif i = currentIdx then sprintf "%s%s%s%s%s" Theme.bold (phaseColor phase) icon Theme.reset Theme.reset
        else sprintf "%s%s%s" Theme.dim icon Theme.reset)
    |> String.concat " → "

/// Render knowledge tree visualization
let renderKnowledgeTree (nodes: KnowledgeNode list) (width: int) =
    let lines = ResizeArray<string>()
    let sorted = nodes |> List.sortByDescending (fun n -> n.DocumentCount)

    lines.Add(sprintf "%s%s KNOWLEDGE STRUCTURE %s%s" Theme.bold Theme.primary Icons.brain Theme.reset)
    lines.Add("")

    for (i, node) in sorted |> List.indexed do
        let prefix = if i = sorted.Length - 1 then "└─" else "├─"
        let bar = renderProgressBar (float node.DocumentCount) (float (sorted |> List.maxBy (fun n -> n.DocumentCount)).DocumentCount) 15
        let entropyIndicator =
            if node.AvgEntropy > 5.0 then sprintf "%s●%s" Theme.caution Theme.reset
            elif node.AvgEntropy > 4.5 then sprintf "%s●%s" Theme.advisory Theme.reset
            else sprintf "%s●%s" Theme.normal Theme.reset

        lines.Add(sprintf " %s%s%s %s %-25s %s%3d%s docs %s"
            Theme.outline prefix Theme.reset
            entropyIndicator
            (truncate node.Structure 25)
            Theme.tertiary node.DocumentCount Theme.reset
            bar)

    lines |> Seq.toList

/// Render AS-IS to TO-BE transformation matrix
let renderTransformationMatrix (docs: DocumentResult list) (width: int) =
    let lines = ResizeArray<string>()
    let grouped = docs |> List.groupBy (fun d -> d.AsIsPattern, d.ToBeStructure)

    lines.Add(sprintf "%s%s AS-IS → TO-BE TRANSFORMATION %s%s" Theme.bold Theme.caution Icons.dna Theme.reset)
    lines.Add("")

    // Header
    lines.Add(sprintf " %s%-18s  %-25s  %s%s"
        Theme.dim "AS-IS Pattern" "TO-BE Structure" "Count" Theme.reset)
    lines.Add(sprintf " %s%s%s" Theme.outline (String.replicate (width - 4) "─") Theme.reset)

    for ((asIs, toBe), items) in grouped |> List.sortByDescending (fun (_, items) -> items.Length) |> List.truncate 6 do
        let count = items.Length
        let pct = float count / float docs.Length * 100.0
        let bar = renderProgressBar pct 100.0 8

        lines.Add(sprintf " %-18s %s→%s %-25s %s%3d%s %s"
            (truncate asIs 18)
            Theme.advisory Theme.reset
            (truncate toBe 25)
            Theme.tertiary count Theme.reset
            bar)

    lines |> Seq.toList

// ═══════════════════════════════════════════════════════════════════════════════
// COCKPIT PANELS
// ═══════════════════════════════════════════════════════════════════════════════

let renderHeader (state: CockpitState) =
    let spinner = Icons.spinner.[state.SpinnerFrame % Icons.spinner.Length]
    let uptime = (DateTime.UtcNow - state.StartTime).TotalSeconds
    let uptimeStr = sprintf "%02d:%02d" (int (uptime / 60.0)) (int uptime % 60)
    let timestamp = DateTime.UtcNow.ToString("HH:mm:ss")

    let lines = ResizeArray<string>()

    // Top border with title
    lines.Add(sprintf "%s%s%s" Box.tl (String.replicate (state.Cols - 2) Box.h) Box.tr)

    // Title bar
    let title = sprintf "%s%s%s FRACTAL KNOWLEDGE COCKPIT %s%s %s%s"
                    Theme.bold Theme.bgPrimary Theme.onSurface Icons.crystal Theme.reset
                    Theme.tertiary spinner
    let phase = sprintf "%s%A%s" (phaseColor state.Phase) state.Phase Theme.reset
    let time = sprintf "%s%s │ %s%s" Theme.dim uptimeStr timestamp Theme.reset

    let content = sprintf " %s %s" title phase
    let padding = state.Cols - 4 - visibleLength content - visibleLength time
    lines.Add(sprintf "%s%s%s%s %s" Box.v content (String.replicate (max 0 padding) " ") time Box.v)

    // Phase progress indicator
    let phaseIndicator = renderPhaseIndicator state.Phase
    let phaseContent = sprintf " %s" phaseIndicator
    lines.Add(sprintf "%s%s%s" Box.v (padRight phaseContent (state.Cols - 2)) Box.v)

    // Divider
    lines.Add(sprintf "%s%s%s" Box.tRight (String.replicate (state.Cols - 2) Box.h) Box.tLeft)

    lines |> Seq.toList

let renderMetricsPanel (state: CockpitState) (width: int) =
    let lines = ResizeArray<string>()
    let m = state.Metrics

    lines.Add(sprintf "%s%s%s PIPELINE METRICS %s%s%s"
        Box.v Theme.bold Icons.lightning Theme.reset
        (String.replicate (width - 22) Box.rh) Box.rv)

    // Progress
    let pct = if m.DocsTotal > 0 then float m.DocsProcessed / float m.DocsTotal * 100.0 else 0.0
    let progressBar = renderProgressBar pct 100.0 20
    let progressLine = sprintf "%s %sProgress:%s %s %s%.0f%%%s (%d/%d) %s" Box.v Theme.dim Theme.reset progressBar Theme.tertiary pct Theme.reset m.DocsProcessed m.DocsTotal Box.rv
    lines.Add(progressLine)

    // Throughput with sparkline
    let sparkline = renderSparkline m.ThroughputHistory 12
    let trend = renderTrend m.Trend
    lines.Add(sprintf "%s %sThroughput:%s %s%.0f%s docs/s %s %s %s"
        Box.v Theme.dim Theme.reset
        Theme.advisory m.Throughput Theme.reset
        sparkline trend Box.rv)

    // Data rate
    let dataRate = if m.ElapsedMs > 0.0 then float m.BytesProcessed / m.ElapsedMs * 1000.0 / 1024.0 / 1024.0 else 0.0
    lines.Add(sprintf "%s %sData Rate:%s %s%.1f%s MB/s %s"
        Box.v Theme.dim Theme.reset
        Theme.tertiary dataRate Theme.reset Box.rv)

    // Elapsed time vs target
    let targetPct = state.TargetMs / max m.ElapsedMs 1.0 * 100.0
    let targetColor = if m.ElapsedMs <= state.TargetMs then Theme.connected else Theme.caution
    lines.Add(sprintf "%s %sTime:%s %s%s%s / %s%.0fms%s target (%s%.0f%%%s) %s"
        Box.v Theme.dim Theme.reset
        targetColor (formatDuration m.ElapsedMs) Theme.reset
        Theme.dim state.TargetMs Theme.reset
        (if targetPct >= 100.0 then Theme.connected else Theme.caution) targetPct Theme.reset
        Box.rv)

    // Errors
    let errorColor = if m.ErrorCount > 0 then Theme.warning else Theme.normal
    lines.Add(sprintf "%s %sErrors:%s %s%d%s %s"
        Box.v Theme.dim Theme.reset
        errorColor m.ErrorCount Theme.reset Box.rv)

    lines |> Seq.toList

let renderLogsPanel (state: CockpitState) (width: int) (height: int) =
    let lines = ResizeArray<string>()

    lines.Add(sprintf "%s%s%s FRACTAL LOG %s%s%s"
        Box.tRight Theme.bold "📜" Theme.reset
        (String.replicate (width - 18) Box.rh) Box.tLeft)

    let logLines =
        state.RecentLogs
        |> List.truncate (height - 2)
        |> List.map (fun (time, msg, level) ->
            let timeStr = time.ToString("HH:mm:ss.fff")
            let prefix = levelPrefix level
            let content = sprintf " %s%s%s %s %s" Theme.dim timeStr Theme.reset prefix msg
            sprintf "%s%s%s" Box.v (padRight content (width - 2)) Box.v)

    lines.AddRange(logLines)

    // Fill empty space
    let emptyCount = height - 2 - logLines.Length
    for _ in 1..emptyCount do
        lines.Add(sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

    lines |> Seq.toList

let renderCategoryBreakdown (state: CockpitState) (width: int) =
    let lines = ResizeArray<string>()

    lines.Add(sprintf "%s%s%s DOCUMENT CATEGORIES %s%s%s"
        Box.tRight Theme.bold Icons.book Theme.reset
        (String.replicate (width - 26) Box.rh) Box.tLeft)

    let grouped = state.Documents |> List.groupBy (fun d -> d.Category)

    for (cat, docs) in grouped |> List.sortByDescending (fun (_, d) -> d.Length) do
        let catName =
            match cat with
            | Plan -> "📋 Plans"
            | FormalSpec lang -> sprintf "📐 Formal (%s)" lang
            | Journal -> "📅 Journal"
            | Architecture -> "🏗️ Architecture"
            | Unknown -> "❓ Unknown"

        let count = docs.Length
        let totalSize = docs |> List.sumBy (fun d -> d.Size)
        let avgEntropy = docs |> List.averageBy (fun d -> d.Entropy)
        let bar = renderProgressBar (float count) (float state.Documents.Length) 10

        let sizeKb = float totalSize / 1024.0
        let content = sprintf " %-18s %s%3d%s %s%5.1f KB%s E:%.1f %s" catName Theme.tertiary count Theme.reset Theme.dim sizeKb Theme.reset avgEntropy bar

        lines.Add(sprintf "%s%s%s" Box.v (padRight content (width - 2)) Box.v)

    // Fill if needed
    let minLines = 6
    let emptyCount = max 0 (minLines - grouped.Length)
    for _ in 1..emptyCount do
        lines.Add(sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

    lines |> Seq.toList

let renderFooter (state: CockpitState) =
    let lines = ResizeArray<string>()

    // Status bar
    let status =
        if state.Phase = Complete then
            sprintf "%s%s TARGET ACHIEVED%s" Theme.connected Icons.target Theme.reset
        elif state.Metrics.ErrorCount > 0 then
            sprintf "%s%s ISSUES%s" Theme.warning Icons.caution Theme.reset
        else
            sprintf "%s%s PROCESSING%s" Theme.advisory Icons.connected Theme.reset

    let controls = sprintf "%s[q]uit [r]efresh [t]heme%s" Theme.dim Theme.reset

    lines.Add(sprintf "%s%s%s" Box.bl (String.replicate (state.Cols - 2) Box.h) Box.br)
    lines.Add(sprintf " %s │ %s │ %sIndrajaal v20.0.0 - Fractal Knowledge Engine%s"
        status controls Theme.dim Theme.reset)

    lines |> Seq.toList

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN RENDER
// ═══════════════════════════════════════════════════════════════════════════════

let render (state: CockpitState) =
    let sb = StringBuilder()
    sb.Append(Theme.clear) |> ignore

    let leftWidth = state.Cols / 2
    let rightWidth = state.Cols - leftWidth

    // Header
    let header = renderHeader state
    for line in header do
        sb.AppendLine(line) |> ignore

    // Top panels side by side
    let metrics = renderMetricsPanel state leftWidth
    let categories = renderCategoryBreakdown state rightWidth

    let maxTopLines = max metrics.Length categories.Length
    for i in 0..maxTopLines-1 do
        let left = if i < metrics.Length then metrics.[i] else String.replicate leftWidth " "
        let right = if i < categories.Length then categories.[i] else String.replicate rightWidth " "
        sb.AppendLine(left + right) |> ignore

    // Middle section - Knowledge Tree
    let knowledgeNodes =
        state.KnowledgeMap
        |> Map.toList
        |> List.map (fun (_, node) -> node)

    if not knowledgeNodes.IsEmpty then
        let tree = renderKnowledgeTree knowledgeNodes (state.Cols - 4)
        for line in tree do
            sb.AppendLine(sprintf "%s %s %s" Box.v (padRight line (state.Cols - 4)) Box.v) |> ignore

    // Transformation Matrix
    if state.Documents.Length > 0 then
        let matrix = renderTransformationMatrix state.Documents (state.Cols - 4)
        for line in matrix do
            sb.AppendLine(sprintf "%s %s %s" Box.v (padRight line (state.Cols - 4)) Box.v) |> ignore

    // Logs panel
    let logs = renderLogsPanel state state.Cols 8
    for line in logs do
        sb.AppendLine(line) |> ignore

    // Footer
    let footer = renderFooter state
    for line in footer do
        sb.AppendLine(line) |> ignore

    Console.Write(sb.ToString())

// ═══════════════════════════════════════════════════════════════════════════════
// DOCUMENT PROCESSING (Same logic, integrated with cockpit)
// ═══════════════════════════════════════════════════════════════════════════════

let mutable currentState: CockpitState = {
    Phase = Discovery
    Metrics = {
        Phase = Discovery
        DocsProcessed = 0
        DocsTotal = 0
        BytesProcessed = 0L
        ElapsedMs = 0.0
        Throughput = 0.0
        ThroughputHistory = []
        ErrorCount = 0
        Trend = Stable
    }
    Documents = []
    KnowledgeMap = Map.empty
    RecentLogs = []
    StartTime = DateTime.UtcNow
    TargetMs = 3000.0
    SpinnerFrame = 0
    Cols = 140
    Rows = 45
}

let log (level: FractalLevel) (msg: string) =
    let entry = (DateTime.UtcNow, msg, level)
    let newLogs = entry :: currentState.RecentLogs |> List.truncate 15
    currentState <- { currentState with RecentLogs = newLogs }

let updateMetrics (phase: PipelinePhase) (processed: int) (total: int) (bytes: int64) (elapsed: float) =
    let throughput = if elapsed > 0.0 then float processed / (elapsed / 1000.0) else 0.0
    let history = throughput :: currentState.Metrics.ThroughputHistory |> List.truncate 20

    let trend =
        if history.Length < 2 then Stable
        else
            let recent = history |> List.head
            let prev = history |> List.skip 1 |> List.head
            let delta = recent - prev
            if delta > 100.0 then RisingFast
            elif delta > 20.0 then Rising
            elif delta < -100.0 then FallingFast
            elif delta < -20.0 then Falling
            else Stable

    let newMetrics = {
        Phase = phase
        DocsProcessed = processed
        DocsTotal = total
        BytesProcessed = bytes
        ElapsedMs = elapsed
        Throughput = throughput
        ThroughputHistory = history
        ErrorCount = currentState.Metrics.ErrorCount
        Trend = trend
    }
    currentState <- { currentState with Phase = phase; Metrics = newMetrics; SpinnerFrame = currentState.SpinnerFrame + 1 }

let classifyDocument (path: string) (content: string) =
    let filename = Path.GetFileName(path).ToLower()
    let textLower = content.ToLower()

    if Regex.IsMatch(filename + textLower, @"implementation.*plan|execution.*plan", RegexOptions.IgnoreCase) then Plan
    elif Regex.IsMatch(filename, @"\.agda$") || textLower.Contains("agda") then FormalSpec "Agda"
    elif Regex.IsMatch(filename, @"\.qnt$") || textLower.Contains("quint") then FormalSpec "Quint"
    elif Regex.IsMatch(filename + textLower, @"journal.*\d{8}|20\d{6}", RegexOptions.IgnoreCase) then Journal
    elif Regex.IsMatch(textLower, @"architecture|5.?level|fractal|holonic", RegexOptions.IgnoreCase) then Architecture
    else Unknown

let parseDocument (path: string) : DocumentResult option =
    try
        let content = File.ReadAllText(path)
        let lines = content.Split('\n')
        let headings = lines |> Array.filter (fun l -> l.TrimStart().StartsWith("#")) |> Array.length
        let codeBlocks = Regex.Matches(content, "```").Count / 2
        let links = Regex.Matches(content, @"\[.*?\]\(.*?\)").Count

        // Entropy
        let freq = content |> Seq.countBy id |> Seq.map snd |> Seq.toArray
        let total = float content.Length
        let entropy =
            freq
            |> Array.map (fun c ->
                let p = float c / total
                if p > 0.0 then -p * Math.Log(p) / Math.Log(2.0) else 0.0)
            |> Array.sum

        let asIsPattern =
            if headings > 10 then "structured-plan"
            elif codeBlocks > 5 then "code-heavy"
            elif links > 20 then "reference-doc"
            elif entropy > 4.5 then "prose-dense"
            else "mixed"

        let category = classifyDocument path content
        let toBeStructure =
            match category with
            | Plan -> "knowledge_graph/plan"
            | FormalSpec lang -> sprintf "formal_specs/%s" (lang.ToLower())
            | Journal -> "knowledge_graph/temporal"
            | Architecture -> "holonic_map/L3"
            | Unknown -> "inbox/unclassified"

        Some {
            Path = path
            Category = category
            Size = int64 (content.Length)
            Lines = lines.Length
            Headings = headings
            CodeBlocks = codeBlocks
            Links = links
            Entropy = entropy
            ProcessingUs = 0L
            AsIsPattern = asIsPattern
            ToBeStructure = toBeStructure
        }
    with _ ->
        currentState <- { currentState with Metrics = { currentState.Metrics with ErrorCount = currentState.Metrics.ErrorCount + 1 }}
        None

let buildKnowledgeMap (docs: DocumentResult list) =
    docs
    |> List.groupBy (fun d -> d.ToBeStructure)
    |> List.map (fun (structure, items) ->
        let totalSize = items |> List.sumBy (fun d -> d.Size)
        let avgEntropy = items |> List.averageBy (fun d -> d.Entropy)
        let color =
            if avgEntropy > 5.0 then Theme.caution
            elif avgEntropy > 4.5 then Theme.advisory
            else Theme.normal

        structure, {
            Structure = structure
            DocumentCount = items.Length
            TotalSize = totalSize
            AvgEntropy = avgEntropy
            Color = color
        })
    |> Map.ofList

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN EXECUTION
// ═══════════════════════════════════════════════════════════════════════════════

let runPipeline () =
    Console.Write(Theme.hideCursor)

    try
        let cols = try Console.WindowWidth with _ -> 140
        let rows = try Console.WindowHeight with _ -> 45
        currentState <- { currentState with Cols = max 100 cols; Rows = max 30 rows; StartTime = DateTime.UtcNow }

        let docPaths = ["docs/plans"; "docs/formal_specs"; "docs/journal"]
        let sw = Stopwatch.StartNew()

        // Phase 1: Discovery
        log L7 "🚀 Initiating fractal document discovery..."
        currentState <- { currentState with Phase = Discovery }
        render currentState

        let allFiles =
            docPaths
            |> List.collect (fun path ->
                if Directory.Exists(path) then
                    Directory.GetFiles(path, "*.md", SearchOption.AllDirectories) |> Array.toList
                else [])

        log L5 (sprintf "📁 Found %d markdown documents" allFiles.Length)
        updateMetrics Discovery 0 allFiles.Length 0L sw.Elapsed.TotalMilliseconds
        render currentState
        Threading.Thread.Sleep(200)

        // Phase 2: Sampling
        currentState <- { currentState with Phase = Sampling }
        log L6 "📊 Statistical sampling (3 files)..."
        render currentState

        let sampleFiles = allFiles |> List.take (min 3 allFiles.Length)
        let sampleDocs = sampleFiles |> List.choose parseDocument

        log L4 (sprintf "📈 Sample analysis: avg entropy %.2f bits" (sampleDocs |> List.averageBy (fun d -> d.Entropy)))
        updateMetrics Sampling 3 allFiles.Length (sampleDocs |> List.sumBy (fun d -> d.Size)) sw.Elapsed.TotalMilliseconds
        render currentState
        Threading.Thread.Sleep(200)

        // Phase 3-5: Full processing
        currentState <- { currentState with Phase = Parsing }
        log L5 "📖 Full parallel document parsing..."
        render currentState

        let mutable processed = 0
        let allDocs =
            allFiles
            |> List.choose (fun path ->
                let doc = parseDocument path
                processed <- processed + 1
                if processed % 50 = 0 then
                    let bytes = currentState.Documents |> List.sumBy (fun d -> d.Size)
                    updateMetrics Parsing processed allFiles.Length bytes sw.Elapsed.TotalMilliseconds
                    render currentState
                doc)

        currentState <- { currentState with Documents = allDocs }
        updateMetrics Transformation allDocs.Length allFiles.Length (allDocs |> List.sumBy (fun d -> d.Size)) sw.Elapsed.TotalMilliseconds

        // Phase 6: Mapping
        currentState <- { currentState with Phase = Mapping }
        log L4 "🗺️ Building knowledge structure map..."
        render currentState

        let knowledgeMap = buildKnowledgeMap allDocs
        currentState <- { currentState with KnowledgeMap = knowledgeMap }

        for (structure, node) in knowledgeMap |> Map.toList do
            log L3 (sprintf "  └─ %s: %d docs" structure node.DocumentCount)

        updateMetrics Mapping allDocs.Length allFiles.Length (allDocs |> List.sumBy (fun d -> d.Size)) sw.Elapsed.TotalMilliseconds
        render currentState
        Threading.Thread.Sleep(200)

        // Phase 7: Complete
        sw.Stop()
        currentState <- { currentState with Phase = Complete }
        updateMetrics Complete allDocs.Length allFiles.Length (allDocs |> List.sumBy (fun d -> d.Size)) sw.Elapsed.TotalMilliseconds

        let status =
            if sw.Elapsed.TotalMilliseconds <= currentState.TargetMs then
                sprintf "🎯 TARGET ACHIEVED: %.0fms (target: %.0fms)" sw.Elapsed.TotalMilliseconds currentState.TargetMs
            else
                sprintf "⚠ Target missed by %.0fms" (sw.Elapsed.TotalMilliseconds - currentState.TargetMs)

        log L7 status
        log L7 (sprintf "📊 Processed %d documents, %.1f KB total" allDocs.Length (float (allDocs |> List.sumBy (fun d -> d.Size)) / 1024.0))

        render currentState

        // Wait for user
        Threading.Thread.Sleep(5000)

    finally
        Console.Write(Theme.showCursor)
        printfn ""
        printfn "%s%sCockpit shutdown complete.%s" Theme.connected Icons.check Theme.reset

// Run
runPipeline ()
