// =============================================================================
// HealthBars.fs - TUI ANSI Dashboard Container Status Health Bars L4
// =============================================================================
// STAMP: SC-HMI-010 (vibrant chromatic feedback based on Zenoh metabolic telemetry)
//        SC-HMI-011 (8x8 matrix, 100% path coverage across 8 elements x 8 layers)
//        SC-VDP-001 (visual data plane — cluster visualization)
// AOR:   AOR-COV-008 (source-first selectors)
//
// Renders ANSI-coloured horizontal health bars for the Prajna TUI cockpit.
// Covers container health, CPU, memory, and disk utilization at L4 (System).
//
// Bar legend:
//   █  — filled block (used / healthy portion)
//   ░  — empty block  (unused / degraded portion)
//
// Colour thresholds (CPU / generic):
//   green  \x1b[32m  — utilization < 60%
//   yellow \x1b[33m  — utilization 60–79%
//   red    \x1b[31m  — utilization ≥ 80%
//
// Pure module — no I/O, no mutable state.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// ANSI palette (shared with ZettelView / ConsoleChannel — SC-CONSOL-003)
// ---------------------------------------------------------------------------

module private HealthAnsi =
    let reset   = "\x1b[0m"
    let bold    = "\x1b[1m"
    let green   = "\x1b[32m"
    let yellow  = "\x1b[33m"
    let red     = "\x1b[31m"
    let cyan    = "\x1b[36m"
    let grey    = "\x1b[90m"
    let white   = "\x1b[97m"

    let paint (colour: string) (text: string) : string =
        sprintf "%s%s%s" colour text reset

    let boldPaint (colour: string) (text: string) : string =
        sprintf "%s%s%s%s" bold colour text reset

// ---------------------------------------------------------------------------
// Domain type
// ---------------------------------------------------------------------------

/// Represents a single container entry for the health-bar dashboard.
type ContainerBar = {
    /// Display name of the container (e.g. "zenoh-router")
    Name      : string
    /// Health percentage in [0.0 .. 100.0]
    HealthPct : float
    /// Runtime state string (e.g. "running", "stopped", "unhealthy")
    State     : string
    /// Exposed host ports
    Ports     : int list
}

// ---------------------------------------------------------------------------
// HealthBars module
// ---------------------------------------------------------------------------

/// <summary>
/// TUI ANSI dashboard health bars for L4 container and resource visualization.
/// </summary>
/// <remarks>
/// STAMP compliance:
///   SC-HMI-010 — vibrant chromatic feedback
///   SC-HMI-011 — 8x8 matrix path coverage
///   SC-VDP-001 — visual data plane
/// </remarks>
module HealthBars =

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// Maximum bar width in characters (SC-HMI-011 8x8 matrix).
    [<Literal>]
    let MaxBarWidth = 40

    /// Filled block character.
    [<Literal>]
    let FilledChar = "█"

    /// Empty block character.
    [<Literal>]
    let EmptyChar = "░"

    /// Choose bar colour based on a 0–100 percentage value.
    /// green < 60%, yellow < 80%, red ≥ 80%  (SC-HMI-010)
    let private colourForPct (pct: float) : string =
        if pct < 60.0 then HealthAnsi.green
        elif pct < 80.0 then HealthAnsi.yellow
        else HealthAnsi.red

    /// Choose bar colour for container health (inverted — higher is better).
    /// green ≥ 80%, yellow ≥ 50%, red < 50%
    let private colourForHealth (pct: float) : string =
        if pct >= 80.0 then HealthAnsi.green
        elif pct >= 50.0 then HealthAnsi.yellow
        else HealthAnsi.red

    /// Choose state colour for container state strings.
    let private colourForState (state: string) : string =
        match state.ToLowerInvariant() with
        | "running"   -> HealthAnsi.green
        | "unhealthy" -> HealthAnsi.red
        | "exited"
        | "stopped"   -> HealthAnsi.red
        | "paused"    -> HealthAnsi.yellow
        | _           -> HealthAnsi.grey

    /// Clamp a value to [0.0 .. 100.0].
    let private clamp100 (v: float) : float = Math.Clamp(v, 0.0, 100.0)

    /// Build the raw filled/empty bar string (no colour applied).
    let private buildBarChars (value: float) (maxWidth: int) : string =
        let width    = Math.Clamp(maxWidth, 1, MaxBarWidth)
        let pct      = clamp100 value
        let filled   = int (Math.Round(pct / 100.0 * float width))
        let empty    = width - filled
        String.replicate filled FilledChar + String.replicate empty EmptyChar

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// <summary>
    /// Render a single horizontal ANSI bar with a label.
    /// </summary>
    /// <param name="label">Label displayed to the left of the bar.</param>
    /// <param name="value">Current value in [0.0 .. 100.0].</param>
    /// <param name="maxWidth">Width of the bar in characters (capped at MaxBarWidth=40).</param>
    /// <returns>ANSI-formatted single-line string.</returns>
    let renderBar (label: string) (value: float) (maxWidth: int) : string =
        let pct      = clamp100 value
        let colour   = colourForPct pct
        let bar      = buildBarChars pct maxWidth
        let pctStr   = sprintf "%5.1f%%" pct
        sprintf "%s%-20s%s %s%s" HealthAnsi.white label HealthAnsi.reset
                                  (HealthAnsi.paint colour bar) pctStr

    /// <summary>
    /// Render all container health bars stacked vertically.
    /// </summary>
    /// <param name="containers">List of ContainerBar records.</param>
    /// <returns>Multi-line ANSI-formatted string ready for terminal output.</returns>
    let renderContainerBars (containers: ContainerBar list) : string =
        if containers.IsEmpty then
            HealthAnsi.paint HealthAnsi.grey "  (no containers)"
        else
            let header =
                sprintf "%s%s  %-20s %-40s %6s  %s%s"
                    HealthAnsi.bold HealthAnsi.cyan
                    "CONTAINER" "HEALTH" "PCT" "STATE"
                    HealthAnsi.reset

            let separator =
                HealthAnsi.paint HealthAnsi.grey (String.replicate 80 "─")

            let rows =
                containers
                |> List.map (fun c ->
                    let pct       = clamp100 c.HealthPct
                    let barColour = colourForHealth pct
                    let bar       = buildBarChars pct MaxBarWidth
                    let stateClr  = colourForState c.State
                    let portsStr  =
                        if c.Ports.IsEmpty then ""
                        else
                            c.Ports
                            |> List.map string
                            |> String.concat ","
                            |> sprintf " [%s]"
                    sprintf "  %s%-20s%s %s %s%5.1f%%%s  %s%s%s%s"
                        HealthAnsi.white c.Name HealthAnsi.reset
                        (HealthAnsi.paint barColour bar)
                        HealthAnsi.grey pct HealthAnsi.reset
                        stateClr c.State HealthAnsi.reset
                        portsStr)

            header :: separator :: rows
            |> String.concat "\n"

    /// <summary>
    /// Render a CPU usage bar with adaptive ANSI colouring.
    /// </summary>
    /// <param name="cpuPct">CPU utilization percentage (0.0 – 100.0).</param>
    /// <returns>Single-line ANSI string: label + bar + percentage.</returns>
    /// <remarks>
    /// Colour thresholds (SC-HMI-010):
    ///   green  — cpuPct &lt; 60%
    ///   yellow — cpuPct &lt; 80%
    ///   red    — cpuPct ≥ 80%
    /// </remarks>
    let renderCpuBar (cpuPct: float) : string =
        let pct    = clamp100 cpuPct
        let colour = colourForPct pct
        let bar    = buildBarChars pct MaxBarWidth
        let label  = "CPU"
        sprintf "%s%-20s%s %s %s%5.1f%%%s"
            HealthAnsi.white label HealthAnsi.reset
            (HealthAnsi.paint colour bar)
            HealthAnsi.grey pct HealthAnsi.reset

    /// <summary>
    /// Render a memory usage bar showing used vs. total MB.
    /// </summary>
    /// <param name="usedMb">Memory currently in use (MiB).</param>
    /// <param name="totalMb">Total available memory (MiB). Must be &gt; 0.</param>
    /// <returns>Single-line ANSI string: label + bar + MB detail.</returns>
    let renderMemoryBar (usedMb: int) (totalMb: int) : string =
        let total  = max 1 totalMb
        let used   = Math.Clamp(usedMb, 0, total)
        let pct    = float used / float total * 100.0
        let colour = colourForPct pct
        let bar    = buildBarChars pct MaxBarWidth
        let label  = "MEM"
        let detail = sprintf "%d/%d MiB" used total
        sprintf "%s%-20s%s %s %s%s%s"
            HealthAnsi.white label HealthAnsi.reset
            (HealthAnsi.paint colour bar)
            HealthAnsi.grey detail HealthAnsi.reset

    /// <summary>
    /// Render a disk usage bar.
    /// </summary>
    /// <param name="usedPct">Disk utilization percentage (0.0 – 100.0).</param>
    /// <returns>Single-line ANSI string: label + bar + percentage.</returns>
    let renderDiskBar (usedPct: float) : string =
        let pct    = clamp100 usedPct
        let colour = colourForPct pct
        let bar    = buildBarChars pct MaxBarWidth
        let label  = "DISK"
        sprintf "%s%-20s%s %s %s%5.1f%%%s"
            HealthAnsi.white label HealthAnsi.reset
            (HealthAnsi.paint colour bar)
            HealthAnsi.grey pct HealthAnsi.reset
