namespace Cepaf.Observability

open System
open System.Text

/// ═══════════════════════════════════════════════════════════════════════════════
/// CEPAF CLI Dashboard - Reusable Full-Screen Terminal Dashboard
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Full-screen terminal dashboard with dynamic updates, agent status,
///       telemetry visualization, and interactive user feedback.
///
/// WHY: Provides a unified, reusable UX component for CLI-based system
///      operations including startup, operational monitoring, testing,
///      and shutdown processes.
///
/// STAMP Compliance:
///   - SC-OBS-069: Dual logging (terminal + telemetry)
///   - SC-PRF-050: Response time < 50ms for updates
///   - SC-AGT-017: Agent efficiency > 90%
///
/// ═══════════════════════════════════════════════════════════════════════════════
module Dashboard =

    // ═══════════════════════════════════════════════════════════════════════════
    // ANSI CODES
    // ═══════════════════════════════════════════════════════════════════════════

    module Ansi =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let dim = "\u001b[2m"
        let red = "\u001b[31m"
        let green = "\u001b[32m"
        let yellow = "\u001b[33m"
        let blue = "\u001b[34m"
        let magenta = "\u001b[35m"
        let cyan = "\u001b[36m"
        let white = "\u001b[37m"
        let bgBlue = "\u001b[44m"
        let bgGreen = "\u001b[42m"
        let bgRed = "\u001b[41m"
        let clear = "\u001b[2J\u001b[H"
        let hideCursor = "\u001b[?25l"
        let showCursor = "\u001b[?25h"

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

    module Icons =
        let success = "✓"
        let error = "✗"
        let running = "●"
        let waiting = "○"
        let idle = "◌"
        let arrow = "→"
        let barFull = "█"
        let barEmpty = "░"
        let spinner = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]

    // ═══════════════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    type AgentStatus =
        | Idle
        | Running
        | Success
        | Error
        | Waiting

    type LogLevel =
        | Info
        | Warn
        | Error
        | Success
        | Debug

    type Agent = {
        Id: int
        Name: string
        Role: string
        Status: AgentStatus
        Task: string option
        UpdatedAt: DateTime
    }

    type LogEntry = {
        Level: LogLevel
        Message: string
        Source: string option
        Timestamp: DateTime
    }

    type Progress = {
        Id: string
        Label: string
        Current: int
        Total: int
        Percentage: int
    }

    type Metric = {
        Id: string
        Label: string
        Value: string
        Unit: string
    }

    type DashboardState = {
        Title: string
        Phase: string
        PhaseDescription: string
        Agents: Map<int, Agent>
        Logs: LogEntry list
        Progress: Map<string, Progress>
        Metrics: Map<string, Metric>
        StartedAt: DateTime
        SpinnerFrame: int
        Cols: int
        Rows: int
    }

    type PromptOption = {
        Key: string
        Label: string
        Description: string option
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    let mutable private state: DashboardState option = None

    let private getTerminalSize () =
        try
            let cols = Console.WindowWidth
            let rows = Console.WindowHeight
            (max 100 cols, max 30 rows)
        with _ -> (140, 45)

    let initialize (title: string) =
        let cols, rows = getTerminalSize()
        state <- Some {
            Title = title
            Phase = "INITIALIZING"
            PhaseDescription = "Starting up..."
            Agents = Map.empty
            Logs = []
            Progress = Map.empty
            Metrics = Map.empty
            StartedAt = DateTime.UtcNow
            SpinnerFrame = 0
            Cols = cols
            Rows = rows
        }
        Console.Write(Ansi.hideCursor)

    let shutdown () =
        Console.Write(Ansi.showCursor)
        Console.Write(Ansi.clear)
        printfn "%sDashboard shutdown complete.%s" Ansi.green Ansi.reset
        state <- None

    // ═══════════════════════════════════════════════════════════════════════════
    // UPDATE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    let setPhase (phase: string) (description: string) =
        state <- state |> Option.map (fun s -> { s with Phase = phase; PhaseDescription = description })

    let registerAgent (id: int) (name: string) (role: string) =
        let agent = {
            Id = id
            Name = name
            Role = role
            Status = Idle
            Task = None
            UpdatedAt = DateTime.UtcNow
        }
        state <- state |> Option.map (fun s -> { s with Agents = Map.add id agent s.Agents })

    let updateAgent (id: int) (status: AgentStatus) (task: string option) =
        state <- state |> Option.map (fun s ->
            match Map.tryFind id s.Agents with
            | Some agent ->
                let updated = { agent with Status = status; Task = task; UpdatedAt = DateTime.UtcNow }
                { s with Agents = Map.add id updated s.Agents }
            | None -> s
        )

    let log (level: LogLevel) (message: string) (source: string option) =
        let entry = {
            Level = level
            Message = message
            Source = source
            Timestamp = DateTime.UtcNow
        }
        state <- state |> Option.map (fun s ->
            let logs = entry :: s.Logs |> List.truncate 20
            { s with Logs = logs }
        )

    let progress (id: string) (label: string) (current: int) (total: int) =
        let pct = if total > 0 then (current * 100) / total else 0
        let prog = { Id = id; Label = label; Current = current; Total = total; Percentage = pct }
        state <- state |> Option.map (fun s -> { s with Progress = Map.add id prog s.Progress })

    let metric (id: string) (label: string) (value: string) (unit: string) =
        let m = { Id = id; Label = label; Value = value; Unit = unit }
        state <- state |> Option.map (fun s -> { s with Metrics = Map.add id m s.Metrics })

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    let private statusIcon (status: AgentStatus) =
        match status with
        | AgentStatus.Success -> Icons.success
        | AgentStatus.Error -> Icons.error
        | AgentStatus.Running -> Icons.running
        | AgentStatus.Waiting -> Icons.waiting
        | AgentStatus.Idle -> Icons.idle

    let private statusColor (status: AgentStatus) =
        match status with
        | AgentStatus.Success -> Ansi.green
        | AgentStatus.Error -> Ansi.red
        | AgentStatus.Running -> Ansi.blue
        | AgentStatus.Waiting -> Ansi.yellow
        | AgentStatus.Idle -> Ansi.dim

    let private levelBadge (level: LogLevel) =
        match level with
        | LogLevel.Error -> sprintf "%s%sERR%s" Ansi.bgRed Ansi.white Ansi.reset
        | LogLevel.Warn -> sprintf "%sWRN%s" Ansi.yellow Ansi.reset
        | LogLevel.Info -> sprintf "%sINF%s" Ansi.blue Ansi.reset
        | LogLevel.Success -> sprintf "%sOK %s" Ansi.green Ansi.reset
        | LogLevel.Debug -> sprintf "%sDBG%s" Ansi.dim Ansi.reset

    let private visibleLength (s: string) =
        System.Text.RegularExpressions.Regex.Replace(s, @"\u001b\[[0-9;]*m", "").Length

    let private padRight (s: string) (width: int) =
        let visible = visibleLength s
        if visible < width then s + String.replicate (width - visible) " " else s

    let private formatUptime (startedAt: DateTime) =
        let diff = DateTime.UtcNow - startedAt
        sprintf "%02d:%02d:%02d" (int diff.TotalHours) diff.Minutes diff.Seconds

    let private formatLogTime (startedAt: DateTime) (timestamp: DateTime) =
        let diff = timestamp - startedAt
        sprintf "+%02d:%02d" (int diff.TotalMinutes) diff.Seconds

    // ═══════════════════════════════════════════════════════════════════════════
    // PANEL RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    let private renderHeader (s: DashboardState) =
        let spinner = Icons.spinner.[s.SpinnerFrame % Icons.spinner.Length]
        let uptime = formatUptime s.StartedAt
        let ts = DateTime.UtcNow.ToString("HH:mm:ss")

        let line1 = sprintf "%s%s%s" Box.tl (String.replicate (s.Cols - 2) Box.h) Box.tr

        let title = sprintf "%s%s%s %s %s" Ansi.bold Ansi.bgBlue Ansi.white s.Title Ansi.reset
        let phase = sprintf "%s%s [%s]%s" Ansi.cyan spinner s.Phase Ansi.reset
        let desc = sprintf "%s%s%s" Ansi.dim s.PhaseDescription Ansi.reset
        let right = sprintf "%s%s │ %s%s" Ansi.dim uptime ts Ansi.reset

        let content = sprintf " %s %s %s" title phase desc
        let padding = s.Cols - 4 - visibleLength content - visibleLength right
        let line2 = sprintf "%s%s%s%s %s" Box.v content (String.replicate (max 0 padding) " ") right Box.v

        let line3 = sprintf "%s%s%s" Box.tRight (String.replicate (s.Cols - 2) Box.h) Box.tLeft

        [line1; line2; line3]

    let private renderAgentsPanel (s: DashboardState) (width: int) =
        let header = sprintf "%s%s AGENTS (%d) %s%s%s"
                        Box.v Ansi.bold (Map.count s.Agents) Ansi.reset
                        (String.replicate (width - 16) Box.h) Box.tLeft

        let agentLines =
            s.Agents
            |> Map.toList
            |> List.sortBy fst
            |> List.map (fun (_, a) ->
                let icon = statusIcon a.Status
                let color = statusColor a.Status
                let name = a.Name.PadRight(12)
                let role = sprintf "[%s]" a.Role |> fun r -> r.PadRight(16)
                let task = a.Task |> Option.defaultValue "" |> fun t -> if t.Length > width - 40 then t.Substring(0, width - 43) + "..." else t

                let content = sprintf "%s%s%s %s%s%s %s%s%s %s"
                                color icon Ansi.reset
                                Ansi.bold name Ansi.reset
                                Ansi.dim role Ansi.reset
                                task
                sprintf "%s %s%s%s" Box.v content (String.replicate (max 0 (width - visibleLength content - 3)) " ") Box.v
            )

        header :: agentLines

    let private renderMetricsPanel (s: DashboardState) (width: int) =
        let header = sprintf "%s%s TELEMETRY %s%s%s"
                        Box.tRight Ansi.bold Ansi.reset
                        (String.replicate (width - 14) Box.h) Box.tLeft

        let metricLines =
            s.Metrics
            |> Map.toList
            |> List.truncate 7
            |> List.map (fun (_, m) ->
                let label = m.Label.PadRight(18)
                let content = sprintf "%s%s%s %s%s%s %s%s%s"
                                Ansi.cyan label Ansi.reset
                                Ansi.bold m.Value Ansi.reset
                                Ansi.dim m.Unit Ansi.reset
                sprintf "%s %s%s%s" Box.v content (String.replicate (max 0 (width - visibleLength content - 3)) " ") Box.v
            )

        let emptyCount = 7 - List.length metricLines
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

        header :: metricLines @ emptyLines

    let private renderProgressPanel (s: DashboardState) (width: int) =
        let header = sprintf "%s%s PROGRESS %s%s%s"
                        Box.tRight Ansi.bold Ansi.reset
                        (String.replicate (width - 13) Box.h) Box.tLeft

        let progressLines =
            s.Progress
            |> Map.toList
            |> List.truncate 4
            |> List.map (fun (_, p) ->
                let barWidth = width - 25
                let filled = (p.Percentage * barWidth) / 100
                let empty = barWidth - filled

                let bar = sprintf "%s%s%s%s%s"
                            Ansi.green (String.replicate filled Icons.barFull)
                            Ansi.dim (String.replicate empty Icons.barEmpty) Ansi.reset
                let label = p.Label.PadRight(12)
                let pct = sprintf "%3d%%" p.Percentage

                sprintf "%s %s %s %s %s" Box.v label bar pct Box.v
            )

        let emptyCount = 4 - List.length progressLines
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

        header :: progressLines @ emptyLines

    let private renderLogsPanel (s: DashboardState) (width: int) (height: int) =
        let header = sprintf "%s%s ACTIVITY LOG %s%s%s"
                        Box.tRight Ansi.bold Ansi.reset
                        (String.replicate (width - 17) Box.h) Box.tLeft

        let logLines =
            s.Logs
            |> List.truncate height
            |> List.map (fun l ->
                let time = formatLogTime s.StartedAt l.Timestamp
                let level = levelBadge l.Level
                let source = l.Source |> Option.map (sprintf "[%s] ") |> Option.defaultValue ""
                let msg = if l.Message.Length > width - 30 then l.Message.Substring(0, width - 33) + "..." else l.Message

                let content = sprintf "%s%s%s %s %s%s"
                                Ansi.dim time Ansi.reset level source msg
                sprintf "%s %s%s%s" Box.v content (String.replicate (max 0 (width - visibleLength content - 3)) " ") Box.v
            )

        let emptyCount = height - List.length logLines
        let emptyLines = List.replicate emptyCount (sprintf "%s%s%s" Box.v (String.replicate (width - 2) " ") Box.v)

        header :: logLines @ emptyLines

    let private renderFooter (s: DashboardState) =
        let line1 = sprintf "%s%s%s" Box.bl (String.replicate (s.Cols - 2) Box.h) Box.br
        let status = if Map.exists (fun _ a -> a.Status = AgentStatus.Error) s.Agents
                     then sprintf "%sISSUES%s" Ansi.yellow Ansi.reset
                     else sprintf "%sHEALTHY%s" Ansi.green Ansi.reset
        let line2 = sprintf " %sPress Ctrl+C to exit%s │ Status: %s │ %sF# CEPAF Dashboard%s"
                        Ansi.dim Ansi.reset status Ansi.dim Ansi.reset
        [line1; line2]

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN RENDER
    // ═══════════════════════════════════════════════════════════════════════════

    let render () =
        match state with
        | None -> ()
        | Some s ->
            let cols, rows = getTerminalSize()
            let s = { s with Cols = cols; Rows = rows; SpinnerFrame = s.SpinnerFrame + 1 }
            state <- Some s

            let leftWidth = cols / 2 - 1
            let rightWidth = cols / 2

            let header = renderHeader s
            let agents = renderAgentsPanel s leftWidth
            let metrics = renderMetricsPanel s rightWidth
            let progress = renderProgressPanel s leftWidth
            let logs = renderLogsPanel s rightWidth 10
            let footer = renderFooter s

            let sb = StringBuilder()
            sb.Append(Ansi.clear) |> ignore

            // Header
            for line in header do
                sb.AppendLine(line) |> ignore

            // Side by side panels
            let mergeLines left right =
                let maxLen = max (List.length left) (List.length right)
                [0..maxLen-1]
                |> List.map (fun i ->
                    let l = if i < List.length left then left.[i] else ""
                    let r = if i < List.length right then right.[i] else ""
                    l + r
                )

            let topPanels = mergeLines agents metrics
            let bottomPanels = mergeLines progress logs

            for line in topPanels @ bottomPanels do
                sb.AppendLine(line) |> ignore

            // Footer
            for line in footer do
                sb.AppendLine(line) |> ignore

            Console.Write(sb.ToString())

    // ═══════════════════════════════════════════════════════════════════════════
    // PROMPT
    // ═══════════════════════════════════════════════════════════════════════════

    let prompt (question: string) (options: PromptOption list) (defaultKey: string option) : string =
        render()

        let optStr = options |> List.map (fun o -> o.Key) |> String.concat "/"
        let defStr = defaultKey |> Option.map (sprintf " (default: %s)") |> Option.defaultValue ""

        printfn ""
        printf "%s? %s [%s]%s: %s" Ansi.yellow question optStr defStr Ansi.reset

        let input = Console.ReadLine()
        if String.IsNullOrWhiteSpace(input) then
            defaultKey |> Option.defaultValue (options |> List.head |> fun o -> o.Key)
        else
            input.Trim()

    // ═══════════════════════════════════════════════════════════════════════════
    // DEMO / TEST
    // ═══════════════════════════════════════════════════════════════════════════

    let demo () =
        initialize "CEPAF 5-AGENT ORCHESTRATOR"

        // Register agents
        registerAgent 0 "SUPERVISOR" "Orchestration"
        registerAgent 1 "DASHBOARD" "Visualization"
        registerAgent 2 "CEPAF/GDE" "Automation"
        registerAgent 3 "TEST_RUN" "Testing"
        registerAgent 4 "TELEMETRY" "Monitoring"

        setPhase "STARTUP" "Initializing agents..."
        render()
        System.Threading.Thread.Sleep(500)

        updateAgent 0 AgentStatus.Running (Some "Coordinating startup")
        updateAgent 1 AgentStatus.Running (Some "Initializing dashboard")
        updateAgent 4 AgentStatus.Running (Some "Starting metrics")
        log LogLevel.Info "Agent-0 SUPERVISOR activating" (Some "SUPERVISOR")
        metric "memory" "Memory Usage" "55" "MB"
        metric "processes" "Process Count" "53" ""
        render()
        System.Threading.Thread.Sleep(500)

        updateAgent 1 AgentStatus.Success (Some "Dashboard ready")
        log LogLevel.Success "All agents initialized" (Some "SUPERVISOR")
        render()
        System.Threading.Thread.Sleep(500)

        setPhase "CONTAINERS" "Starting infrastructure..."
        updateAgent 2 AgentStatus.Running (Some "Starting containers")
        progress "containers" "Containers" 0 3
        log LogLevel.Info "Starting 3-container stack" (Some "CEPAF/GDE")
        render()
        System.Threading.Thread.Sleep(300)

        for i in 1..3 do
            progress "containers" "Containers" i 3
            render()
            System.Threading.Thread.Sleep(300)

        updateAgent 2 AgentStatus.Success (Some "Containers running")
        log LogLevel.Success "Containers started" (Some "CEPAF/GDE")
        render()
        System.Threading.Thread.Sleep(500)

        setPhase "COMPILATION" "Compiling with Patient Mode..."
        progress "compile" "Compiling" 0 100
        render()

        for i in 1..10 do
            progress "compile" "Compiling" (i * 10) 100
            metric "memory" "Memory Usage" (sprintf "%d" (55 + i * 5)) "MB"
            render()
            System.Threading.Thread.Sleep(200)

        log LogLevel.Success "Compilation: 0 errors, 0 warnings" (Some "CEPAF/GDE")
        metric "errors" "Errors" "0" ""
        metric "warnings" "Warnings" "0" ""
        render()
        System.Threading.Thread.Sleep(500)

        setPhase "TESTING" "Running test suite..."
        updateAgent 3 AgentStatus.Running (Some "Test execution")
        progress "tests" "Testing" 0 100
        log LogLevel.Info "Starting cluster tests" (Some "TEST_RUN")
        render()

        for i in 1..10 do
            progress "tests" "Testing" (i * 10) 100
            render()
            System.Threading.Thread.Sleep(150)

        updateAgent 3 AgentStatus.Success (Some "345 passed")
        log LogLevel.Success "All 345 tests passed" (Some "TEST_RUN")
        metric "tests_passed" "Tests Passed" "345" ""
        metric "tests_failed" "Tests Failed" "0" ""
        render()
        System.Threading.Thread.Sleep(500)

        setPhase "COMPLETE" "GDE Goal Achieved!"
        updateAgent 0 AgentStatus.Success (Some "Verified")
        updateAgent 4 AgentStatus.Success (Some "Telemetry complete")
        log LogLevel.Success "═══════════════════════════════════════════" (Some "SUPERVISOR")
        log LogLevel.Success "GDE GOAL ACHIEVED: 100% VERIFIED" (Some "SUPERVISOR")
        log LogLevel.Success "═══════════════════════════════════════════" (Some "SUPERVISOR")
        render()

        System.Threading.Thread.Sleep(3000)
        shutdown()
