// =============================================================================
// ContainerHealthBars.fs - CEPAF Cockpit TUI Per-Container Health Bars
// =============================================================================
// STAMP: SC-HMI-010 (Color Rich), SC-VER-031 (All containers healthy), SC-CNT-001
// AOR: AOR-MON-004 (30s refresh), AOR-BIO-004
//
// Pure rendering module — returns ANSI-coloured strings for individual container
// status bars and the full container grid. No I/O, no side effects.
//
// ## Constitutional Alignment
// - Ψ₀ (Existence): Per-container health directly tracks system survival
// - Ψ₃ (Verification): CPU/memory values are numeric, auditable
//
// ## STAMP Compliance
// - SC-HMI-010: Vibrant chromatic feedback per container state
// - SC-VER-031: All containers healthy — non-green bars signal violations
// - SC-CNT-001: Container lifecycle compliance visible at a glance
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Domain types — ContainerState DU and ContainerStatus record
// ---------------------------------------------------------------------------

/// Discrete lifecycle state of a mesh container.
[<RequireQualifiedAccess>]
type ContainerState =
    | Running
    | Stopped
    | Unhealthy
    | Creating
    | Unknown

/// Full health snapshot for a single container.
type ContainerStatus = {
    /// Container name, e.g. "zenoh-router", "indrajaal-db-prod"
    Name        : string
    /// Lifecycle state
    Status      : ContainerState
    /// CPU utilisation percentage (0.0–100.0)
    CpuPercent  : float
    /// Resident memory in megabytes
    MemoryMb    : int
    /// Running time (None when not yet started)
    Uptime      : TimeSpan option
    /// Exposed host ports
    Ports       : int list
}

// ---------------------------------------------------------------------------
// ANSI colour helpers (inline — avoids Cepaf.Observability dependency)
// Mirrors the palette already used in HealthDashboard.fs
// ---------------------------------------------------------------------------

[<RequireQualifiedAccess>]
module private ContainerAnsi =
    let reset   = "\u001b[0m"
    let bold    = "\u001b[1m"
    let dim     = "\u001b[2m"
    let green   = "\u001b[32m"
    let yellow  = "\u001b[33m"
    let red     = "\u001b[31m"
    let cyan    = "\u001b[36m"
    let white   = "\u001b[37m"
    let bGreen  = "\u001b[92m"
    let bYellow = "\u001b[93m"
    let bRed    = "\u001b[91m"
    let bCyan   = "\u001b[96m"
    let bWhite  = "\u001b[97m"
    let magenta = "\u001b[35m"
    let bMagenta = "\u001b[95m"

// ---------------------------------------------------------------------------
// ContainerHealthBars — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders per-container ANSI health bars for the TUI cockpit dashboard.
/// All functions are pure — they accept data and return strings; no I/O.
[<RequireQualifiedAccess>]
module ContainerHealthBars =

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Colour and indicator glyph for a container state.
    let private stateDisplay (state: ContainerState) : string * string =
        match state with
        | ContainerState.Running   -> ContainerAnsi.bGreen,   "● RUN  "
        | ContainerState.Stopped   -> ContainerAnsi.bRed,     "■ STOP "
        | ContainerState.Unhealthy -> ContainerAnsi.bRed,     "▲ SICK "
        | ContainerState.Creating  -> ContainerAnsi.bYellow,  "◌ INIT "
        | ContainerState.Unknown   -> ContainerAnsi.dim,      "? UNK  "

    /// Colour for a CPU percentage value.
    let private cpuColour (pct: float) : string =
        if pct < 60.0      then ContainerAnsi.bGreen
        elif pct < 80.0    then ContainerAnsi.bYellow
        else                    ContainerAnsi.bRed

    /// Colour for memory megabytes (thresholds: 512 MB / 1024 MB).
    let private memColour (mb: int) : string =
        if mb < 512        then ContainerAnsi.bGreen
        elif mb < 1024     then ContainerAnsi.bYellow
        else                    ContainerAnsi.bRed

    /// ASCII bar of `width` chars, filled to `pct` (0–100), coloured.
    let private bar (pct: float) (width: int) (colour: string) : string =
        let filled = int (pct / 100.0 * float width) |> max 0 |> min width
        let empty  = width - filled
        sprintf "%s%s%s%s" colour (String.replicate filled "█") ContainerAnsi.reset (String.replicate empty "░")

    /// Human-readable uptime string from a TimeSpan.
    let private formatUptime (ts: TimeSpan) : string =
        if ts.TotalSeconds < 60.0      then sprintf "%.0fs"     ts.TotalSeconds
        elif ts.TotalMinutes < 60.0    then sprintf "%.0fm%.0fs" (floor ts.TotalMinutes) (ts.Seconds |> float)
        elif ts.TotalHours < 24.0      then sprintf "%.0fh%.0fm" (floor ts.TotalHours)   (ts.Minutes |> float)
        else                                sprintf "%.0fd%.0fh" (floor ts.TotalDays)    (ts.Hours |> float)

    /// Comma-separated port list string, truncated to 3 entries.
    let private formatPorts (ports: int list) : string =
        match ports with
        | []  -> "—"
        | lst ->
            let shown = lst |> List.truncate 3 |> List.map string |> String.concat ","
            if lst.Length > 3 then shown + ",…" else shown

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders a single container's health bar row.
    ///
    /// Format:
    ///   [STATE] NAME             CPU ████░░░░░░ nn.n%  MEM nnnnMB  UP nnh nmm  PORTS p,p
    ///
    /// Returns an ANSI-coloured single-line string (no trailing newline).
    let renderContainerBar (status: ContainerStatus) : string =
        let (stateCol, stateGlyph) = stateDisplay status.Status

        // Pad name to 24 chars so columns align across containers
        let namePadded = status.Name.PadRight(24)

        // CPU sub-bar (12 chars wide)
        let cpuCol = cpuColour status.CpuPercent
        let cpuBar = bar status.CpuPercent 12 cpuCol
        let cpuPct = sprintf "%s%5.1f%%%s" cpuCol status.CpuPercent ContainerAnsi.reset

        // Memory
        let memCol  = memColour status.MemoryMb
        let memStr  = sprintf "%s%5dMB%s" memCol status.MemoryMb ContainerAnsi.reset

        // Uptime
        let uptimeStr =
            match status.Uptime with
            | None    -> sprintf "%s  —%s    " ContainerAnsi.dim ContainerAnsi.reset
            | Some ts -> sprintf "%s%-7s%s" ContainerAnsi.white (formatUptime ts) ContainerAnsi.reset

        // Ports
        let portsStr = sprintf "%s%s%s" ContainerAnsi.cyan (formatPorts status.Ports) ContainerAnsi.reset

        let nameField = sprintf "%s%s%s" ContainerAnsi.bWhite namePadded ContainerAnsi.reset
        sprintf "  %s%s%s  %s  CPU %s %s  MEM %s  UP %s  PORTS %s"
            stateCol stateGlyph ContainerAnsi.reset
            nameField
            cpuBar cpuPct
            memStr
            uptimeStr
            portsStr

    /// Renders the full container grid, sorted alphabetically by name.
    ///
    /// Includes a header and a footer summary line.
    /// Returns a multi-line ANSI-coloured string (ready for Console.Write).
    let renderContainerGrid (containers: ContainerStatus list) : string =
        let sep = sprintf "%s%s%s" ContainerAnsi.cyan (String.replicate 90 "─") ContainerAnsi.reset
        let hdr = sprintf "  %s%sCONTAINER HEALTH GRID%s%s"
                      ContainerAnsi.bold ContainerAnsi.bCyan ContainerAnsi.reset ContainerAnsi.reset

        let sorted = containers |> List.sortBy (fun c -> c.Name)

        let rows =
            sorted
            |> List.map renderContainerBar

        // Summary counts
        let running   = containers |> List.filter (fun c -> c.Status = ContainerState.Running)   |> List.length
        let unhealthy = containers |> List.filter (fun c -> c.Status = ContainerState.Unhealthy) |> List.length
        let stopped   = containers |> List.filter (fun c -> c.Status = ContainerState.Stopped)   |> List.length
        let total     = containers |> List.length

        let summaryCol =
            if unhealthy > 0 || stopped > 0 then ContainerAnsi.bRed
            elif running = total             then ContainerAnsi.bGreen
            else                                  ContainerAnsi.bYellow

        let summary =
            sprintf "  %s%d/%d running%s  unhealthy:%s%d%s  stopped:%s%d%s"
                summaryCol running total ContainerAnsi.reset
                (if unhealthy > 0 then ContainerAnsi.bRed else ContainerAnsi.dim) unhealthy ContainerAnsi.reset
                (if stopped   > 0 then ContainerAnsi.bRed else ContainerAnsi.dim) stopped   ContainerAnsi.reset

        [ ""
          sep
          hdr
          sep ]
        @ rows
        @ [ sep
            summary
            sep
            "" ]
        |> String.concat "\n"

    /// Renders a compact one-line summary of all containers.
    ///
    /// Format: "4/4 up | CPU avg 23% | Mem 1.2 GB"
    ///
    /// Returns a single ANSI-coloured line (no trailing newline).
    let renderCompactSummary (containers: ContainerStatus list) : string =
        let total   = containers |> List.length
        let running = containers |> List.filter (fun c -> c.Status = ContainerState.Running) |> List.length

        let (upCol, upStr) =
            if running = total && total > 0 then ContainerAnsi.bGreen, sprintf "%d/%d up" running total
            elif running > 0               then ContainerAnsi.bYellow, sprintf "%d/%d up" running total
            else                                ContainerAnsi.bRed,    sprintf "%d/%d up" running total

        let avgCpu =
            if containers.IsEmpty then 0.0
            else containers |> List.averageBy (fun c -> c.CpuPercent)

        let cpuCol = if avgCpu < 60.0 then ContainerAnsi.bGreen elif avgCpu < 80.0 then ContainerAnsi.bYellow else ContainerAnsi.bRed

        let totalMemMb = containers |> List.sumBy (fun c -> c.MemoryMb)
        let memGb      = float totalMemMb / 1024.0
        let memStr     = if memGb >= 1.0 then sprintf "%.1f GB" memGb else sprintf "%d MB" totalMemMb
        let memCol     = if totalMemMb < 4096 then ContainerAnsi.bGreen elif totalMemMb < 8192 then ContainerAnsi.bYellow else ContainerAnsi.bRed

        sprintf "%s%s%s | CPU avg %s%.0f%%%s | Mem %s%s%s"
            upCol  upStr  ContainerAnsi.reset
            cpuCol avgCpu ContainerAnsi.reset
            memCol memStr ContainerAnsi.reset
