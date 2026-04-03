namespace Cepaf.Sentinel.MCP.Tools

open System
open System.IO
open System.Text.Json
open System.Threading
open Cepaf.Zenoh.Core
open Cepaf.Sentinel.MCP.Protocol

/// MCP tool for CPU Governor — reads /proc/stat, computes adaptive parallelism,
/// publishes utilization metrics to Zenoh key expression indrajaal/cpu/governor/status.
///
/// Actions: check | publish | status | govern
///   check   — Read current CPU %, return raw metrics
///   publish — Read CPU + publish to Zenoh topic (requires open session)
///   status  — Full governor dashboard (mode, schedulers, jobs, nice, history)
///   govern  — Compute adaptive env vars for current CPU load
///
/// STAMP: SC-CPU-GOV-001 (85% hard limit), SC-CPU-GOV-006 (adaptive schedulers)
/// AOR: AOR-CPU-GOV-009 (/proc/stat differential), AOR-CPU-GOV-006 (log utilization)
module CpuGovernorTools =

    // ═══════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════

    let private hardLimit = 85
    let private throttleAt = 80
    let private resumeAt = 75
    let private zenohKey = "indrajaal/cpu/governor/status"

    // ═══════════════════════════════════════════════════════════════════
    // TOOL DEFINITION
    // ═══════════════════════════════════════════════════════════════════

    let toolDefinitions : McpProtocol.ToolDefinition list = [
        { Name = "cpu_governor"
          Description = "CPU Governor: check utilization, publish metrics to Zenoh, compute adaptive parallelism. Hard limit 85%."
          InputSchema =
            {| ``type`` = "object"
               properties = Map.ofList [
                   "action", ({| ``type`` = "string"
                                 description = "Governor action"
                                 ``enum`` = [ "check"; "publish"; "status"; "govern" ] |} :> obj) ]
               required = [ "action" ] |} :> obj }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    type GovernorMode =
        | Full       // < 60%
        | Slight     // 60-70%
        | Moderate   // 70-80%
        | Heavy      // 80-85%
        | Wait       // > 85%

    type CpuSnapshot = {
        User: int64; Nice: int64; System: int64
        Idle: int64; IoWait: int64; Irq: int64; SoftIrq: int64
    }

    type GovernorState = {
        mutable LastCpuPct: int
        mutable LastMode: GovernorMode
        mutable LastPublished: DateTime option
        mutable PublishCount: int64
        mutable CheckCount: int64
        mutable History: (DateTime * int) list  // last 30 readings
    }

    let createState () : GovernorState = {
        LastCpuPct = 0
        LastMode = Full
        LastPublished = None
        PublishCount = 0L
        CheckCount = 0L
        History = []
    }

    // ═══════════════════════════════════════════════════════════════════
    // /proc/stat READER (SC-CPU-GOV-009: /proc/stat differential)
    // ═══════════════════════════════════════════════════════════════════

    let private readProcStat () : CpuSnapshot option =
        try
            let line = File.ReadAllLines("/proc/stat").[0]  // "cpu  user nice sys idle iow irq sirq ..."
            let parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries)
            if parts.Length >= 8 && parts.[0] = "cpu" then
                Some {
                    User = Int64.Parse(parts.[1])
                    Nice = Int64.Parse(parts.[2])
                    System = Int64.Parse(parts.[3])
                    Idle = Int64.Parse(parts.[4])
                    IoWait = Int64.Parse(parts.[5])
                    Irq = Int64.Parse(parts.[6])
                    SoftIrq = Int64.Parse(parts.[7])
                }
            else None
        with _ -> None

    let private cpuPctFromSnapshots (s1: CpuSnapshot) (s2: CpuSnapshot) : int =
        let busy1 = s1.User + s1.Nice + s1.System + s1.IoWait + s1.Irq + s1.SoftIrq
        let busy2 = s2.User + s2.Nice + s2.System + s2.IoWait + s2.Irq + s2.SoftIrq
        let total1 = busy1 + s1.Idle
        let total2 = busy2 + s2.Idle
        let totalDiff = total2 - total1
        let idleDiff = s2.Idle - s1.Idle
        if totalDiff = 0L then 0
        else int ((totalDiff - idleDiff) * 100L / totalDiff)

    /// Read CPU % using 200ms /proc/stat differential (fast, accurate)
    let private readCpuPct () : int =
        match readProcStat() with
        | None -> -1  // /proc/stat not available (not Linux)
        | Some s1 ->
            Thread.Sleep(200)
            match readProcStat() with
            | None -> -1
            | Some s2 -> cpuPctFromSnapshots s1 s2

    // ═══════════════════════════════════════════════════════════════════
    // ADAPTIVE PARALLELISM (SC-CPU-GOV-006, SC-CPU-GOV-007)
    // ═══════════════════════════════════════════════════════════════════

    let private determineMode (cpuPct: int) : GovernorMode =
        if cpuPct < 0 then Full  // Can't read CPU, assume OK
        elif cpuPct < 60 then Full
        elif cpuPct < 70 then Slight
        elif cpuPct < 80 then Moderate
        elif cpuPct <= 85 then Heavy
        else Wait

    let private schedulersForMode (mode: GovernorMode) : int =
        match mode with
        | Full -> 16 | Slight -> 12 | Moderate -> 10 | Heavy -> 6 | Wait -> 4

    let private jobsForMode (mode: GovernorMode) : int =
        match mode with
        | Full -> 16 | Slight -> 12 | Moderate -> 10 | Heavy -> 6 | Wait -> 4

    let private niceForMode (mode: GovernorMode) : int =
        match mode with
        | Full | Slight -> 10 | Moderate -> 15 | Heavy -> 19 | Wait -> 19

    let private modeString (mode: GovernorMode) : string =
        match mode with
        | Full -> "full" | Slight -> "slight" | Moderate -> "moderate"
        | Heavy -> "heavy" | Wait -> "wait"

    // ═══════════════════════════════════════════════════════════════════
    // CORE LOGIC
    // ═══════════════════════════════════════════════════════════════════

    let private updateState (state: GovernorState) (cpuPct: int) : unit =
        state.LastCpuPct <- cpuPct
        state.LastMode <- determineMode cpuPct
        state.CheckCount <- state.CheckCount + 1L
        let now = DateTime.UtcNow
        state.History <- (now, cpuPct) :: (state.History |> List.truncate 29)

    let private buildPayload (state: GovernorState) : string =
        let mode = state.LastMode
        let cores = Environment.ProcessorCount
        JsonSerializer.Serialize(
            {| cpu_pct = state.LastCpuPct
               mode = modeString mode
               schedulers = schedulersForMode mode
               jobs = jobsForMode mode
               nice = niceForMode mode
               hard_limit = hardLimit
               throttle_at = throttleAt
               resume_at = resumeAt
               cores = cores
               checks = state.CheckCount
               publishes = state.PublishCount
               timestamp = DateTime.UtcNow.ToString("o") |})

    // ═══════════════════════════════════════════════════════════════════
    // HANDLER
    // ═══════════════════════════════════════════════════════════════════

    let private handleCpuGovernor
        (state: GovernorState)
        (sessionHandle: nativeint)
        (args: JsonElement option)
        (id: JsonElement option)
        : string =

        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        match action with
        | "check" ->
            let cpuPct = readCpuPct()
            updateState state cpuPct
            let mode = determineMode cpuPct
            let r = {|
                cpu_pct = cpuPct
                mode = modeString mode
                schedulers = schedulersForMode mode
                jobs = jobsForMode mode
                nice = niceForMode mode
                hard_limit = hardLimit
                over_limit = (cpuPct > hardLimit) |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))

        | "publish" ->
            let cpuPct = readCpuPct()
            updateState state cpuPct
            let payload = buildPayload state
            if sessionHandle = nativeint 0 then
                McpProtocol.toolError id "No Zenoh session. Call zenoh_session action=open first."
            else
                match ZenohFfiBridge.publishString sessionHandle zenohKey payload with
                | Ok () ->
                    state.LastPublished <- Some DateTime.UtcNow
                    state.PublishCount <- state.PublishCount + 1L
                    let r = {|
                        published = true
                        key = zenohKey
                        cpu_pct = cpuPct
                        mode = modeString state.LastMode
                        publish_count = state.PublishCount |}
                    McpProtocol.toolResult id (JsonSerializer.Serialize(r))
                | Error err ->
                    McpProtocol.toolError id (sprintf "Zenoh publish failed: %A" err)

        | "status" ->
            let cpuPct = readCpuPct()
            updateState state cpuPct
            let mode = state.LastMode
            let avg =
                if state.History.IsEmpty then 0
                else state.History |> List.averageBy (fun (_, p) -> float p) |> int
            let maxCpu =
                if state.History.IsEmpty then 0
                else state.History |> List.map snd |> List.max
            let r = {|
                cpu_pct = cpuPct
                cpu_avg_30 = avg
                cpu_max_30 = maxCpu
                mode = modeString mode
                schedulers = schedulersForMode mode
                dirty_io = schedulersForMode mode
                jobs = jobsForMode mode
                nice = niceForMode mode
                hard_limit = hardLimit
                throttle_at = throttleAt
                resume_at = resumeAt
                cores = Environment.ProcessorCount
                over_limit = (cpuPct > hardLimit)
                checks = state.CheckCount
                publishes = state.PublishCount
                last_published = (state.LastPublished |> Option.map (fun d -> d.ToString("o")) |> Option.defaultValue "never")
                zenoh_session = (sessionHandle <> nativeint 0)
                history_points = state.History.Length |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))

        | "govern" ->
            let cpuPct = readCpuPct()
            updateState state cpuPct
            let mode = state.LastMode
            let sched = schedulersForMode mode
            let r = {|
                cpu_pct = cpuPct
                mode = modeString mode
                elixir_erl_options = sprintf "+S %d:%d +SDio %d" sched sched sched
                mix_jobs = jobsForMode mode
                nice_level = niceForMode mode
                should_wait = (mode = Wait)
                env_vars = Map.ofList [
                    "ELIXIR_ERL_OPTIONS", sprintf "+S %d:%d +SDio %d" sched sched sched
                    "MIX_JOBS", string (jobsForMode mode)
                ] |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(r))

        | other ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s (expected check|publish|status|govern)" other)

    // ═══════════════════════════════════════════════════════════════════
    // DISPATCH
    // ═══════════════════════════════════════════════════════════════════

    let dispatch (state: GovernorState) (sessionHandle: nativeint) (toolName: string) (args: JsonElement option) (id: JsonElement option) : string option =
        match toolName with
        | "cpu_governor" -> Some (handleCpuGovernor state sessionHandle args id)
        | _ -> None
