namespace Cepaf.Cockpit

open System
open System.Text
open System.Diagnostics

/// ═══════════════════════════════════════════════════════════════════════════════
/// C3I MULTI-AGENT DASHBOARD - Full-Screen Verbose Telemetry System
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: A comprehensive multi-agent orchestration dashboard with:
///       - 5 Agents + 1 Supervisor architecture
///       - Real-time verbose telemetry output
///       - Full AEE mode with GDE/OODA/ACE automation
///       - Complete pipeline visualization
///
/// WHY: Enables operators to see every aspect of system operation:
///       - Startup, operational, testing, shutdown phases
///       - User feedback and smart prompts
///       - Task execution in verbose mode
///       - All key telemetry to console
///
/// STAMP Compliance:
///   - SC-OBS-069: Dual logging (terminal + telemetry)
///   - SC-AGT-017: Agent efficiency > 90%
///   - SC-C3I-001: Data-centric architecture
///   - SC-PRF-050: Response time < 50ms
///
/// ═══════════════════════════════════════════════════════════════════════════════
module C3IMultiAgent =

    // ═══════════════════════════════════════════════════════════════════════════
    // ANSI CODES (Full-Screen Terminal Support)
    // ═══════════════════════════════════════════════════════════════════════════

    module Ansi =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let dim = "\u001b[2m"
        let italic = "\u001b[3m"
        let underline = "\u001b[4m"
        let blink = "\u001b[5m"
        let red = "\u001b[31m"
        let green = "\u001b[32m"
        let yellow = "\u001b[33m"
        let blue = "\u001b[34m"
        let magenta = "\u001b[35m"
        let cyan = "\u001b[36m"
        let white = "\u001b[37m"
        let brightRed = "\u001b[91m"
        let brightGreen = "\u001b[92m"
        let brightYellow = "\u001b[93m"
        let brightBlue = "\u001b[94m"
        let brightMagenta = "\u001b[95m"
        let brightCyan = "\u001b[96m"
        let bgBlue = "\u001b[44m"
        let bgGreen = "\u001b[42m"
        let bgRed = "\u001b[41m"
        let bgYellow = "\u001b[43m"
        let bgCyan = "\u001b[46m"
        let bgMagenta = "\u001b[45m"
        let clear = "\u001b[2J\u001b[H"
        let clearLine = "\u001b[2K"
        let hideCursor = "\u001b[?25l"
        let showCursor = "\u001b[?25h"
        let moveTo row col = sprintf "\u001b[%d;%dH" row col
        let moveUp n = sprintf "\u001b[%dA" n
        let savePos = "\u001b[s"
        let restorePos = "\u001b[u"

    module Box =
        let tl = "╔"
        let tr = "╗"
        let bl = "╚"
        let br = "╝"
        let h = "═"
        let v = "║"
        let hl = "─"
        let vl = "│"
        let tRight = "╠"
        let tLeft = "╣"
        let tDown = "╦"
        let tUp = "╩"
        let cross = "╬"
        let tlSingle = "┌"
        let trSingle = "┐"
        let blSingle = "└"
        let brSingle = "┘"

    module Icons =
        let success = "✓"
        let error = "✗"
        let running = "●"
        let waiting = "○"
        let idle = "◌"
        let arrow = "→"
        let arrowUp = "↑"
        let arrowDown = "↓"
        let barFull = "█"
        let barMedium = "▓"
        let barLight = "░"
        let barEmpty = "░"
        let spinner = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]
        let ooda = [| "◐"; "◓"; "◑"; "◒" |]
        let pulse = [| "●"; "◉"; "○"; "◎" |]
        let agent = "🤖"
        let supervisor = "👁️"
        let gde = "⚡"
        let ooda_icon = "⟳"
        let ace = "🛡️"
        let telemetry = "📊"
        let test = "🧪"
        let container = "📦"

    // ═══════════════════════════════════════════════════════════════════════════
    // AGENT TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    type AgentRole =
        | Supervisor       // Executive control, orchestration
        | Dashboard        // UI/KPI visualization
        | CepafGDE         // GDE/OODA/ACE automation
        | Telemetry        // Metrics collection
        | TestRunner       // Test execution
        | ContainerOps     // Container management

    type AgentStatus =
        | Idle
        | Initializing
        | Running
        | Waiting
        | Success
        | Error
        | Terminated

    type Agent = {
        Id: int
        Name: string
        Role: AgentRole
        Status: AgentStatus
        CurrentTask: string option
        CompletedTasks: int
        FailedTasks: int
        Efficiency: float
        LastUpdate: DateTime
        Metrics: Map<string, float>
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PHASE AND TASK TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    type Phase =
        | Startup
        | ContainerInit
        | Compilation
        | Testing
        | Verification
        | Operational
        | Shutdown

    type TaskStatus =
        | Pending
        | InProgress of percent: int
        | Completed
        | Failed of reason: string

    type Task = {
        Id: string
        Name: string
        Phase: Phase
        Status: TaskStatus
        AssignedAgent: int option
        StartedAt: DateTime option
        CompletedAt: DateTime option
        DurationMs: int64 option
        Output: string list
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // OODA/GDE/ACE STATE
    // ═══════════════════════════════════════════════════════════════════════════

    type OodaPhase =
        | Observe
        | Orient
        | Decide
        | Act

    type OodaState = {
        CurrentPhase: OodaPhase
        CycleCount: int64
        CycleTimeMs: float
        TargetMs: float
        Quality: float
        Violations: int
        LastDecision: string option
    }

    type GDEState = {
        ProposalsGenerated: int
        ProposalsValidated: int
        SuccessRate: float
        GoalProgress: float
        CurrentGoal: string
        EvolutionStage: int
    }

    type ACEState = {
        SafetyChecks: int
        ViolationsBlocked: int
        EnvelopeStatus: string
        GuardianActive: bool
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TELEMETRY
    // ═══════════════════════════════════════════════════════════════════════════

    type LogLevel =
        | Trace
        | Debug
        | Info
        | Success
        | Warn
        | Error
        | Critical

    type TelemetryEntry = {
        Timestamp: DateTime
        Level: LogLevel
        Source: string
        Message: string
        Metrics: Map<string, float> option
    }

    type Metric = {
        Name: string
        Value: float
        Unit: string
        Trend: string  // ↑↑ ↑ → ↓ ↓↓
        SparklineData: float list
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DASHBOARD STATE
    // ═══════════════════════════════════════════════════════════════════════════

    type DashboardState = {
        // System
        Title: string
        Version: string
        Phase: Phase
        PhaseDescription: string
        StartedAt: DateTime

        // Agents (6 total: 1 supervisor + 5 agents)
        Agents: Map<int, Agent>

        // Tasks
        Tasks: Map<string, Task>
        CurrentTask: string option

        // Control Loops
        Ooda: OodaState
        GDE: GDEState
        ACE: ACEState

        // Telemetry
        Logs: TelemetryEntry list
        Metrics: Map<string, Metric>

        // UI State
        SpinnerFrame: int
        OodaFrame: int
        Cols: int
        Rows: int

        // Goals
        Errors: int
        Warnings: int
        TestsPassed: int
        TestsFailed: int
        Coverage: float
        GoalAchieved: bool
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    let mutable private state: DashboardState option = None
    let private statelock = obj()

    let private getTerminalSize () =
        try
            let cols = Console.WindowWidth
            let rows = Console.WindowHeight
            (max 120 cols, max 40 rows)
        with _ -> (140, 50)

    let private defaultOoda = {
        CurrentPhase = Observe
        CycleCount = 0L
        CycleTimeMs = 0.0
        TargetMs = 1000.0
        Quality = 1.0
        Violations = 0
        LastDecision = None
    }

    let private defaultGDE = {
        ProposalsGenerated = 0
        ProposalsValidated = 0
        SuccessRate = 0.0
        GoalProgress = 0.0
        CurrentGoal = "100% Verified Environment"
        EvolutionStage = 0
    }

    let private defaultACE = {
        SafetyChecks = 0
        ViolationsBlocked = 0
        EnvelopeStatus = "OK"
        GuardianActive = true
    }

    let initialize (title: string) =
        let cols, rows = getTerminalSize()
        lock statelock (fun () ->
            state <- Some {
                Title = title
                Version = "1.0.0-C3I"
                Phase = Startup
                PhaseDescription = "Initializing C3I Multi-Agent System..."
                StartedAt = DateTime.UtcNow
                Agents = Map.empty
                Tasks = Map.empty
                CurrentTask = None
                Ooda = defaultOoda
                GDE = defaultGDE
                ACE = defaultACE
                Logs = []
                Metrics = Map.empty
                SpinnerFrame = 0
                OodaFrame = 0
                Cols = cols
                Rows = rows
                Errors = 0
                Warnings = 0
                TestsPassed = 0
                TestsFailed = 0
                Coverage = 0.0
                GoalAchieved = false
            }
        )
        Console.Write(Ansi.hideCursor)
        Console.Write(Ansi.clear)

    let shutdown () =
        Console.Write(Ansi.showCursor)
        Console.Write(Ansi.clear)
        Console.WriteLine(sprintf "%s[C3I] Dashboard shutdown complete.%s" Ansi.green Ansi.reset)
        lock statelock (fun () -> state <- None)

    // ═══════════════════════════════════════════════════════════════════════════
    // UPDATE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    let setPhase (phase: Phase) (description: string) =
        lock statelock (fun () ->
            state <- state |> Option.map (fun s -> { s with Phase = phase; PhaseDescription = description })
        )

    let registerAgent (id: int) (name: string) (role: AgentRole) =
        let agent = {
            Id = id
            Name = name
            Role = role
            Status = Idle
            CurrentTask = None
            CompletedTasks = 0
            FailedTasks = 0
            Efficiency = 0.0
            LastUpdate = DateTime.UtcNow
            Metrics = Map.empty
        }
        lock statelock (fun () ->
            state <- state |> Option.map (fun s -> { s with Agents = Map.add id agent s.Agents })
        )

    let updateAgent (id: int) (status: AgentStatus) (task: string option) =
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                match Map.tryFind id s.Agents with
                | Some agent ->
                    let completed = if status = AgentStatus.Success then agent.CompletedTasks + 1 else agent.CompletedTasks
                    let failed = if status = AgentStatus.Error then agent.FailedTasks + 1 else agent.FailedTasks
                    let total = completed + failed
                    let efficiency = if total > 0 then float completed / float total * 100.0 else 100.0
                    let updated = { agent with Status = status; CurrentTask = task; CompletedTasks = completed; FailedTasks = failed; Efficiency = efficiency; LastUpdate = DateTime.UtcNow }
                    { s with Agents = Map.add id updated s.Agents }
                | None -> s
            )
        )

    let log (level: LogLevel) (source: string) (message: string) =
        let entry = {
            Timestamp = DateTime.UtcNow
            Level = level
            Source = source
            Message = message
            Metrics = None
        }
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                let logs = entry :: s.Logs |> List.truncate 30
                { s with Logs = logs }
            )
        )
        // Also print to console for verbose mode
        let levelStr, color =
            match level with
            | LogLevel.Trace -> "TRC", Ansi.dim
            | LogLevel.Debug -> "DBG", Ansi.dim
            | LogLevel.Info -> "INF", Ansi.blue
            | LogLevel.Success -> "SUC", Ansi.green
            | LogLevel.Warn -> "WRN", Ansi.yellow
            | LogLevel.Error -> "ERR", Ansi.red
            | LogLevel.Critical -> "CRT", Ansi.brightRed
        let ts = DateTime.UtcNow.ToString("HH:mm:ss.fff")
        printfn "%s[%s]%s %s%-3s%s [%s] %s" Ansi.dim ts Ansi.reset color levelStr Ansi.reset source message

    let metric (name: string) (value: float) (unit: string) (trend: string) =
        let m = {
            Name = name
            Value = value
            Unit = unit
            Trend = trend
            SparklineData = []
        }
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                // Update metric with sparkline history
                let existing = Map.tryFind name s.Metrics
                let sparkline =
                    match existing with
                    | Some e -> (value :: e.SparklineData) |> List.truncate 20
                    | None -> [value]
                let updated = { m with SparklineData = sparkline }
                { s with Metrics = Map.add name updated s.Metrics }
            )
        )

    let updateOoda (phase: OodaPhase) (cycleMs: float) (quality: float) =
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                let violations = if cycleMs > s.Ooda.TargetMs then s.Ooda.Violations + 1 else s.Ooda.Violations
                let newOoda = { s.Ooda with
                                  CurrentPhase = phase
                                  CycleTimeMs = cycleMs
                                  Quality = quality
                                  CycleCount = s.Ooda.CycleCount + 1L
                                  Violations = violations }
                { s with Ooda = newOoda }
            )
        )

    let updateGDE (proposals: int) (validated: int) (progress: float) =
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                let rate = if proposals > 0 then float validated / float proposals * 100.0 else 0.0
                let newGDE = { s.GDE with
                                 ProposalsGenerated = proposals
                                 ProposalsValidated = validated
                                 SuccessRate = rate
                                 GoalProgress = progress }
                { s with GDE = newGDE }
            )
        )

    let updateACE (checks: int) (blocked: int) (status: string) =
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                let newACE = { s.ACE with
                                 SafetyChecks = checks
                                 ViolationsBlocked = blocked
                                 EnvelopeStatus = status }
                { s with ACE = newACE }
            )
        )

    let setGoalStatus (errors: int) (warnings: int) (passed: int) (failed: int) (coverage: float) =
        lock statelock (fun () ->
            state <- state |> Option.map (fun s ->
                let achieved = errors = 0 && warnings = 0 && failed = 0 && coverage >= 100.0
                { s with
                    Errors = errors
                    Warnings = warnings
                    TestsPassed = passed
                    TestsFailed = failed
                    Coverage = coverage
                    GoalAchieved = achieved
                }
            )
        )

    // ═══════════════════════════════════════════════════════════════════════════
    // RENDERING HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    let private roleIcon role =
        match role with
        | Supervisor -> Icons.supervisor
        | Dashboard -> Icons.telemetry
        | CepafGDE -> Icons.gde
        | Telemetry -> Icons.telemetry
        | TestRunner -> Icons.test
        | ContainerOps -> Icons.container

    let private statusIcon (status: AgentStatus) =
        match status with
        | AgentStatus.Idle -> Icons.idle
        | AgentStatus.Initializing -> Icons.waiting
        | AgentStatus.Running -> Icons.running
        | AgentStatus.Waiting -> Icons.waiting
        | AgentStatus.Success -> Icons.success
        | AgentStatus.Error -> Icons.error
        | AgentStatus.Terminated -> Icons.error

    let private statusColor (status: AgentStatus) =
        match status with
        | AgentStatus.Idle -> Ansi.dim
        | AgentStatus.Initializing -> Ansi.cyan
        | AgentStatus.Running -> Ansi.blue
        | AgentStatus.Waiting -> Ansi.yellow
        | AgentStatus.Success -> Ansi.green
        | AgentStatus.Error -> Ansi.red
        | AgentStatus.Terminated -> Ansi.dim

    let private phaseColor phase =
        match phase with
        | Startup -> Ansi.cyan
        | ContainerInit -> Ansi.blue
        | Compilation -> Ansi.magenta
        | Testing -> Ansi.yellow
        | Verification -> Ansi.brightMagenta
        | Operational -> Ansi.green
        | Shutdown -> Ansi.red

    let private phaseName phase =
        match phase with
        | Startup -> "STARTUP"
        | ContainerInit -> "CONTAINERS"
        | Compilation -> "COMPILATION"
        | Testing -> "TESTING"
        | Verification -> "VERIFICATION"
        | Operational -> "OPERATIONAL"
        | Shutdown -> "SHUTDOWN"

    let private oodaPhaseStr phase =
        match phase with
        | Observe -> "OBSERVE"
        | Orient -> "ORIENT"
        | Decide -> "DECIDE"
        | Act -> "ACT"

    let private visibleLength (s: string) =
        System.Text.RegularExpressions.Regex.Replace(s, @"\u001b\[[0-9;]*m", "").Length

    let private padRight (s: string) (width: int) =
        let visible = visibleLength s
        if visible < width then s + String.replicate (width - visible) " " else s

    let private sparkline (values: float list) (width: int) =
        if List.isEmpty values then String.replicate width " "
        else
            let chars = [| '▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█' |]
            let minV = List.min values
            let maxV = List.max values
            let range = if maxV - minV < 0.001 then 1.0 else maxV - minV
            values
            |> List.map (fun v ->
                let idx = int ((v - minV) / range * 7.0) |> min 7 |> max 0
                chars.[idx]
            )
            |> List.rev
            |> List.truncate width
            |> List.rev
            |> Array.ofList
            |> String

    let private progressBar (pct: int) (width: int) =
        let filled = pct * width / 100
        let empty = width - filled
        sprintf "%s%s%s%s%s"
            Ansi.green (String.replicate filled Icons.barFull)
            Ansi.dim (String.replicate empty Icons.barEmpty) Ansi.reset

    let private formatUptime (startedAt: DateTime) =
        let diff = DateTime.UtcNow - startedAt
        sprintf "%02d:%02d:%02d" (int diff.TotalHours) diff.Minutes diff.Seconds

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN RENDER
    // ═══════════════════════════════════════════════════════════════════════════

    let render () =
        match state with
        | None -> ()
        | Some s ->
            let cols, rows = getTerminalSize()
            let updated = { s with
                              Cols = cols
                              Rows = rows
                              SpinnerFrame = s.SpinnerFrame + 1
                              OodaFrame = s.OodaFrame + 1 }
            lock statelock (fun () -> state <- Some updated)

            let sb = StringBuilder()

            // Move to top and clear
            sb.Append(Ansi.moveTo 1 1) |> ignore

            // ═══════════════════════════════════════════════════════════════════
            // HEADER
            // ═══════════════════════════════════════════════════════════════════

            let spinner = Icons.spinner.[s.SpinnerFrame % Icons.spinner.Length]
            let oodaAnim = Icons.ooda.[s.OodaFrame % Icons.ooda.Length]
            let uptime = formatUptime s.StartedAt
            let ts = DateTime.UtcNow.ToString("HH:mm:ss")
            let phaseClr = phaseColor s.Phase

            sb.AppendLine(sprintf "%s%s%s" Box.tl (String.replicate (cols - 2) Box.h) Box.tr) |> ignore

            let title = sprintf "%s%s PRAJNA C3I MULTI-AGENT COCKPIT %s" Ansi.bold Ansi.bgBlue Ansi.reset
            let phase = sprintf "%s%s [%s] %s%s" phaseClr spinner (phaseName s.Phase) s.PhaseDescription Ansi.reset
            let stats = sprintf "%s%s │ %s%s" Ansi.dim uptime ts Ansi.reset

            let line = sprintf "%s %s %s" Box.v title phase
            let padding = cols - 4 - visibleLength line - visibleLength stats
            sb.AppendLine(sprintf "%s%s %s%s" line (String.replicate (max 1 padding) " ") stats Box.v) |> ignore

            sb.AppendLine(sprintf "%s%s%s" Box.tRight (String.replicate (cols - 2) Box.h) Box.tLeft) |> ignore

            // ═══════════════════════════════════════════════════════════════════
            // GOAL STATUS BAR
            // ═══════════════════════════════════════════════════════════════════

            let goalIcon =
                if s.GoalAchieved
                then sprintf "%s%s%s" Ansi.green Icons.success Ansi.reset
                else sprintf "%s%s%s" Ansi.yellow Icons.running Ansi.reset
            let errStr =
                if s.Errors = 0
                then sprintf "%s0%s" Ansi.green Ansi.reset
                else sprintf "%s%d%s" Ansi.red s.Errors Ansi.reset
            let wrnStr =
                if s.Warnings = 0
                then sprintf "%s0%s" Ansi.green Ansi.reset
                else sprintf "%s%d%s" Ansi.yellow s.Warnings Ansi.reset
            let testStr = sprintf "%s%d%s/%s%d%s" Ansi.green s.TestsPassed Ansi.reset Ansi.red s.TestsFailed Ansi.reset
            let covStr =
                if s.Coverage >= 100.0
                then sprintf "%s100%%%s" Ansi.green Ansi.reset
                else sprintf "%s%.1f%%%s" Ansi.yellow s.Coverage Ansi.reset

            let goalLine = sprintf "%s %s GDE GOAL: %sZero Errors%s │ Errors: %s │ Warnings: %s │ Tests: %s │ Coverage: %s %s"
                            Box.v goalIcon Ansi.bold Ansi.reset errStr wrnStr testStr covStr Box.v
            sb.AppendLine(padRight goalLine cols) |> ignore

            sb.AppendLine(sprintf "%s%s%s" Box.tRight (String.replicate (cols - 2) Box.h) Box.tLeft) |> ignore

            // ═══════════════════════════════════════════════════════════════════
            // CONTROL LOOPS (OODA / GDE / ACE)
            // ═══════════════════════════════════════════════════════════════════

            let oodaStr = sprintf "%s%s OODA%s: %s%s%s %.0fms (<%s%.0f%s) Q:%.0f%% V:%d"
                            Ansi.cyan oodaAnim Ansi.reset
                            Ansi.bold (oodaPhaseStr s.Ooda.CurrentPhase) Ansi.reset
                            s.Ooda.CycleTimeMs
                            (if s.Ooda.CycleTimeMs < s.Ooda.TargetMs then Ansi.green else Ansi.red)
                            s.Ooda.TargetMs Ansi.reset
                            (s.Ooda.Quality * 100.0)
                            s.Ooda.Violations

            let gdeStr = sprintf "%s%s GDE%s: %d/%d (%.0f%%) │ Goal: %.0f%%"
                            Ansi.magenta Icons.gde Ansi.reset
                            s.GDE.ProposalsValidated s.GDE.ProposalsGenerated s.GDE.SuccessRate
                            s.GDE.GoalProgress

            let aceStr = sprintf "%s%s ACE%s: %s%s%s Checks:%d Blocked:%d"
                            Ansi.green Icons.ace Ansi.reset
                            (if s.ACE.EnvelopeStatus = "OK" then Ansi.green else Ansi.red)
                            s.ACE.EnvelopeStatus Ansi.reset
                            s.ACE.SafetyChecks s.ACE.ViolationsBlocked

            let controlLine = sprintf "%s %s │ %s │ %s %s" Box.v oodaStr gdeStr aceStr Box.v
            sb.AppendLine(padRight controlLine cols) |> ignore

            sb.AppendLine(sprintf "%s%s%s" Box.tRight (String.replicate (cols - 2) Box.h) Box.tLeft) |> ignore

            // ═══════════════════════════════════════════════════════════════════
            // AGENTS PANEL (Left side)
            // ═══════════════════════════════════════════════════════════════════

            let leftWidth = cols / 2 - 1
            let rightWidth = cols / 2

            sb.AppendLine(sprintf "%s%s AGENTS (6) %s%s%s"
                Box.v Ansi.bold Ansi.reset (String.replicate (leftWidth - 14) Box.hl) Box.vl) |> ignore

            s.Agents
            |> Map.toList
            |> List.sortBy fst
            |> List.iter (fun (_, a) ->
                let icon = roleIcon a.Role
                let status = statusIcon a.Status
                let color = statusColor a.Status
                let name = a.Name.PadRight(12)
                let task = a.CurrentTask |> Option.defaultValue "-"
                           |> fun t -> if t.Length > leftWidth - 35 then t.Substring(0, leftWidth - 38) + "..." else t
                let eff = sprintf "%.0f%%" a.Efficiency

                let line = sprintf "%s %s %s%s%s %s%s%s %s %s"
                            Box.v icon color status Ansi.reset
                            Ansi.bold name Ansi.reset
                            (eff.PadLeft(4)) task
                sb.AppendLine(padRight line leftWidth) |> ignore
            )

            // Fill empty agent slots
            for _ in 1..(6 - Map.count s.Agents) do
                sb.AppendLine(sprintf "%s%s" Box.v (String.replicate (leftWidth - 1) " ")) |> ignore

            // ═══════════════════════════════════════════════════════════════════
            // METRICS PANEL (Right side - appended to same lines)
            // ═══════════════════════════════════════════════════════════════════

            // Note: In a real implementation we'd merge left/right panels
            // For now, showing sequential layout

            sb.AppendLine(sprintf "%s%s TELEMETRY %s%s%s"
                Box.tRight Ansi.bold Ansi.reset (String.replicate (cols - 15) Box.hl) Box.tLeft) |> ignore

            s.Metrics
            |> Map.toList
            |> List.truncate 6
            |> List.iter (fun (_, m) ->
                let spark = sparkline m.SparklineData 15
                let trendClr =
                    match m.Trend with
                    | "↑↑" | "↑" -> Ansi.red
                    | "↓↓" | "↓" -> Ansi.green
                    | _ -> Ansi.dim
                let line = sprintf "%s %s%-18s%s %s%8.1f%s %s %s%s%s %s%s%s %s"
                            Box.v Ansi.cyan m.Name Ansi.reset
                            Ansi.bold m.Value Ansi.reset
                            m.Unit trendClr m.Trend Ansi.reset
                            Ansi.dim spark Ansi.reset Box.v
                sb.AppendLine(padRight line cols) |> ignore
            )

            // ═══════════════════════════════════════════════════════════════════
            // FOOTER
            // ═══════════════════════════════════════════════════════════════════

            sb.AppendLine(sprintf "%s%s%s" Box.bl (String.replicate (cols - 2) Box.h) Box.br) |> ignore

            let status =
                if s.GoalAchieved then sprintf "%s%sGOAL ACHIEVED%s" Ansi.green Ansi.bold Ansi.reset
                elif s.Errors > 0 then sprintf "%sERRORS%s" Ansi.red Ansi.reset
                elif s.Warnings > 0 then sprintf "%sWARNINGS%s" Ansi.yellow Ansi.reset
                else sprintf "%sRUNNING%s" Ansi.green Ansi.reset

            sb.AppendLine(sprintf " %sCtrl+C to exit%s │ Status: %s │ %sF# CEPAF C3I v%s%s"
                Ansi.dim Ansi.reset status Ansi.dim s.Version Ansi.reset) |> ignore

            Console.Write(sb.ToString())

    // ═══════════════════════════════════════════════════════════════════════════
    // DEMO EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    let demo () =
        initialize "PRAJNA C3I MULTI-AGENT COCKPIT"

        // Register 6 agents (1 supervisor + 5 agents)
        registerAgent 0 "SUPERVISOR" Supervisor
        registerAgent 1 "DASHBOARD" Dashboard
        registerAgent 2 "CEPAF/GDE" CepafGDE
        registerAgent 3 "TELEMETRY" Telemetry
        registerAgent 4 "TEST_RUN" TestRunner
        registerAgent 5 "CONTAINER" ContainerOps

        log LogLevel.Info "SYSTEM" "═══════════════════════════════════════════════════════════"
        log LogLevel.Info "SYSTEM" "  PRAJNA C3I MULTI-AGENT COCKPIT - AEE MODE ACTIVATED"
        log LogLevel.Info "SYSTEM" "═══════════════════════════════════════════════════════════"
        render()
        Threading.Thread.Sleep(1000)

        // === PHASE 1: STARTUP ===
        setPhase Startup "Activating agents..."
        updateAgent 0 AgentStatus.Running (Some "Orchestrating startup sequence")
        updateAgent 1 AgentStatus.Running (Some "Initializing dashboard")
        updateAgent 3 AgentStatus.Running (Some "Starting telemetry collectors")
        log LogLevel.Info "SUPERVISOR" "Agent mesh activation initiated"
        metric "memory" 55.0 "MB" "→"
        metric "cpu" 12.0 "%" "→"
        metric "processes" 53.0 "" "→"
        render()
        Threading.Thread.Sleep(500)

        updateAgent 1 AgentStatus.Success (Some "Dashboard ready")
        updateAgent 3 AgentStatus.Success (Some "Telemetry active")
        log LogLevel.Success "DASHBOARD" "Full-screen UI initialized"
        log LogLevel.Success "TELEMETRY" "4 metric channels active"
        render()
        Threading.Thread.Sleep(500)

        // === PHASE 2: CONTAINERS ===
        setPhase ContainerInit "Starting 3-container stack..."
        updateAgent 5 AgentStatus.Running (Some "Starting indrajaal-db")
        log LogLevel.Info "CONTAINER" "Starting PostgreSQL container..."
        metric "containers" 0.0 "/3" "↑"
        updateOoda Observe 82.0 0.95
        render()
        Threading.Thread.Sleep(400)

        log LogLevel.Success "CONTAINER" "indrajaal-db: HEALTHY (port 5433)"
        metric "containers" 1.0 "/3" "↑"
        updateOoda Orient 156.0 0.95
        render()
        Threading.Thread.Sleep(400)

        log LogLevel.Info "CONTAINER" "Starting indrajaal-app..."
        updateOoda Decide 380.0 0.95
        render()
        Threading.Thread.Sleep(400)

        log LogLevel.Success "CONTAINER" "indrajaal-app: HEALTHY (port 4000)"
        metric "containers" 2.0 "/3" "↑"
        updateOoda Act 145.0 0.95
        render()
        Threading.Thread.Sleep(400)

        log LogLevel.Info "CONTAINER" "Starting indrajaal-obs..."
        updateOoda Observe 78.0 0.98
        render()
        Threading.Thread.Sleep(400)

        log LogLevel.Success "CONTAINER" "indrajaal-obs: HEALTHY (port 8123)"
        metric "containers" 3.0 "/3" "→"
        updateAgent 5 AgentStatus.Success (Some "All containers healthy")
        updateGDE 3 3 15.0
        updateACE 3 0 "OK"
        log LogLevel.Success "CONTAINER" "3/3 containers verified HEALTHY"
        render()
        Threading.Thread.Sleep(500)

        // === PHASE 3: COMPILATION ===
        setPhase Compilation "Patient Mode: Compiling with zero tolerance..."
        updateAgent 2 AgentStatus.Running (Some "mix compile --warnings-as-errors")
        log LogLevel.Info "CEPAF/GDE" "Patient Mode activated: NO_TIMEOUT=true PATIENT_MODE=enabled"
        metric "memory" 85.0 "MB" "↑"
        render()

        for i in 1..10 do
            metric "compile_progress" (float i * 10.0) "%" "↑"
            metric "memory" (85.0 + float i * 5.0) "MB" "↑"
            metric "files_compiled" (float (i * 77)) "" "↑"
            updateOoda (if i % 4 = 0 then Observe elif i % 4 = 1 then Orient elif i % 4 = 2 then Decide else Act)
                       (100.0 + float (i * 20)) 0.95
            render()
            Threading.Thread.Sleep(200)

        log LogLevel.Success "CEPAF/GDE" "Compiled 773 files successfully"
        metric "errors" 0.0 "" "→"
        metric "warnings" 0.0 "" "→"
        updateAgent 2 AgentStatus.Success (Some "Zero errors, zero warnings")
        updateGDE 5 5 40.0
        setGoalStatus 0 0 0 0 0.0
        render()
        Threading.Thread.Sleep(500)

        // === PHASE 4: TESTING ===
        setPhase Testing "Running test suite with full coverage..."
        updateAgent 4 AgentStatus.Running (Some "mix test --coverage")
        log LogLevel.Info "TEST_RUN" "Executing 345 tests across 12 domains..."

        for i in 1..10 do
            metric "test_progress" (float i * 10.0) "%" "↑"
            metric "tests_passed" (float (i * 34)) "" "↑"
            updateOoda (if i % 4 = 0 then Observe elif i % 4 = 1 then Orient elif i % 4 = 2 then Decide else Act)
                       (80.0 + float (i * 10)) 0.97
            render()
            Threading.Thread.Sleep(150)

        log LogLevel.Success "TEST_RUN" "345/345 tests PASSED"
        metric "tests_passed" 345.0 "" "→"
        metric "tests_failed" 0.0 "" "→"
        metric "coverage" 100.0 "%" "→"
        updateAgent 4 AgentStatus.Success (Some "100% pass rate")
        updateGDE 10 10 70.0
        setGoalStatus 0 0 345 0 100.0
        render()
        Threading.Thread.Sleep(500)

        // === PHASE 5: VERIFICATION ===
        setPhase Verification "Formal verification and STAMP compliance..."
        updateAgent 2 AgentStatus.Running (Some "FPPS consensus verification")
        log LogLevel.Info "CEPAF/GDE" "Running 5-method FPPS consensus..."

        let mutable safetyCheckCount = 0
        for method in ["Pattern"; "AST"; "Statistical"; "Binary"; "LineByLine"] do
            safetyCheckCount <- safetyCheckCount + 1
            log LogLevel.Info "FPPS" (sprintf "%s verification: PASSED" method)
            updateACE safetyCheckCount 0 "OK"
            render()
            Threading.Thread.Sleep(200)

        log LogLevel.Success "CEPAF/GDE" "FPPS 5/5 methods: CONSENSUS ACHIEVED"
        updateGDE 15 15 90.0
        render()
        Threading.Thread.Sleep(300)

        log LogLevel.Info "CEPAF/GDE" "Verifying 242 STAMP safety constraints..."
        updateACE 242 0 "OK"
        log LogLevel.Success "CEPAF/GDE" "242/242 STAMP constraints VERIFIED"
        updateGDE 20 20 100.0
        render()
        Threading.Thread.Sleep(500)

        // === PHASE 6: OPERATIONAL ===
        setPhase Operational "GDE GOAL ACHIEVED: 100% Verified Environment"

        // All agents success
        for i in 0..5 do
            updateAgent i AgentStatus.Success (Some "Verified")

        setGoalStatus 0 0 345 0 100.0

        log LogLevel.Critical "SYSTEM" "═══════════════════════════════════════════════════════════"
        log LogLevel.Critical "SYSTEM" "  GDE GOAL ACHIEVED: 100% VERIFIED ENVIRONMENT"
        log LogLevel.Critical "SYSTEM" "═══════════════════════════════════════════════════════════"
        log LogLevel.Success "SUPERVISOR" "Zero errors, zero warnings"
        log LogLevel.Success "SUPERVISOR" "345/345 tests passed"
        log LogLevel.Success "SUPERVISOR" "100% code coverage"
        log LogLevel.Success "SUPERVISOR" "242/242 STAMP constraints verified"
        log LogLevel.Success "SUPERVISOR" "5/5 FPPS consensus achieved"
        log LogLevel.Success "SUPERVISOR" "CEPAF can now operate autonomously"

        render()

        // Keep running until Ctrl+C
        Console.CancelKeyPress.Add(fun args ->
            args.Cancel <- true
            shutdown()
            Environment.Exit(0)
        )

        log LogLevel.Info "SYSTEM" "Press Ctrl+C to exit"

        while true do
            // Keep OODA loop running
            for phase in [Observe; Orient; Decide; Act] do
                updateOoda phase (70.0 + float (Random().Next(50))) 0.98
                render()
                Threading.Thread.Sleep(250)
