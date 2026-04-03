// =============================================================================
// Sparkline.fs - Unicode Sparkline Renderer for CPU/Memory Metrics
// =============================================================================
// STAMP: SC-HMI-010 (vibrant chromatic feedback based on Zenoh metabolic telemetry),
//        SC-VDP-001 (Visual Data Plane — cluster visualization)
// AOR: AOR-HMI-001 (real-time cockpit telemetry display)
//
// Renders ASCII/Unicode sparklines for CPU and memory metric history in the
// Prajna TUI cockpit (L4 substrate).
//
// Module layout:
//   Sparkline           — pure renderer (no I/O, no mutable state)
//   SparklineMetrics    — impure sampler that reads /proc/stat and /proc/meminfo,
//                         degrades to deterministic demo data when /proc is absent
//
// Unicode sparkline characters: U+2581..U+2588 (▁▂▃▄▅▆▇█)
// ANSI coloring: green (<60%), yellow (60-80%), red (>80%)
//
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System
open System.IO
open System.Threading

// ---------------------------------------------------------------------------
// Internal ANSI palette (subset of ConsoleChannel.AnsiColors — SC-CONSOL-003)
// ---------------------------------------------------------------------------

module private SparklineAnsi =
    let reset    = "\x1b[0m"
    let bold     = "\x1b[1m"
    let green    = "\x1b[32m"
    let yellow   = "\x1b[33m"
    let red      = "\x1b[31m"
    let cyan     = "\x1b[36m"
    let white    = "\x1b[97m"
    let grey     = "\x1b[90m"
    let dimGrey  = "\x1b[2;90m"

    let paint (colour: string) (text: string) : string =
        sprintf "%s%s%s" colour text reset

    /// Select ANSI colour for a normalised value in [0.0, 1.0].
    /// green < 0.60, yellow 0.60–0.80, red > 0.80
    let valueColour (v: float) : string =
        if v < 0.60 then green
        elif v < 0.80 then yellow
        else red

// ---------------------------------------------------------------------------
// Sparkline module — public API
// ---------------------------------------------------------------------------

/// <summary>
/// Pure TUI sparkline renderer for L4 CPU/Memory metric history.
/// Compliance: SC-HMI-010, SC-VDP-001
/// </summary>
module Sparkline =

    // Unicode block characters U+2581–U+2588
    let private blocks = [| '▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█' |]

    /// Default display width in characters.
    let defaultWidth = 30

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// Clamp a float to [lo, hi].
    let private clamp (lo: float) (hi: float) (v: float) : float =
        Math.Min(hi, Math.Max(lo, v))

    /// Normalise a list of values to [0.0, 1.0] using min/max scaling.
    /// If all values are identical the list is treated as all-zero (flat line).
    let private normalise (values: float list) : float list =
        match values with
        | [] -> []
        | vs ->
            let mn = List.min vs
            let mx = List.max vs
            let range = mx - mn
            if range < 1e-9 then
                List.map (fun _ -> 0.0) vs
            else
                List.map (fun v -> clamp 0.0 1.0 ((v - mn) / range)) vs

    /// Map a single normalised value to a block character.
    let private blockChar (v: float) : char =
        let i = int (clamp 0.0 0.9999 v * float blocks.Length)
        blocks.[i]

    /// Trim or pad a list of values to exactly `width` entries (take from the end).
    let private fitToWidth (width: int) (values: float list) : float list =
        let n = List.length values
        if n >= width then
            values |> List.skip (n - width)
        else
            List.replicate (width - n) 0.0 @ values

    // -----------------------------------------------------------------------
    // Public functions
    // -----------------------------------------------------------------------

    /// <summary>
    /// Render a plain Unicode sparkline string from a list of data points.
    /// Values are auto-normalised (min/max scaling); no ANSI colouring.
    /// </summary>
    /// <param name="values">Raw metric history (any float range).</param>
    /// <param name="width">Desired character width (default 30).</param>
    /// <returns>A string of Unicode block characters, length = width.</returns>
    let render (values: float list) (width: int) : string =
        let w = if width <= 0 then defaultWidth else width
        values
        |> fitToWidth w
        |> normalise
        |> List.map blockChar
        |> Array.ofList
        |> String

    /// <summary>
    /// Render a labeled sparkline showing label, sparkline, min/max/current.
    /// Format:  LABEL  ▁▂▃▄▅▆▇█  min=0.0 max=1.0 cur=0.8 UNIT
    /// ANSI-coloured current value.
    /// </summary>
    /// <param name="label">Metric label (e.g., "CPU").</param>
    /// <param name="values">Raw metric history.</param>
    /// <param name="width">Sparkline character width.</param>
    /// <param name="unit">Unit string appended after current value (e.g., "%").</param>
    /// <returns>Formatted one-line string ready for terminal output.</returns>
    let renderLabeled (label: string) (values: float list) (width: int) (unit: string) : string =
        let w = if width <= 0 then defaultWidth else width
        let sparkStr = render values w
        match values with
        | [] ->
            sprintf "%s%s%s  %s  (no data)%s"
                SparklineAnsi.bold label SparklineAnsi.reset
                sparkStr
                SparklineAnsi.reset
        | vs ->
            let mn  = List.min vs
            let mx  = List.max vs
            let cur = List.last vs
            let normCur = if mx - mn < 1e-9 then 0.0 else clamp 0.0 1.0 ((cur - mn) / (mx - mn))
            let col = SparklineAnsi.valueColour normCur
            sprintf "%s%-6s%s  %s  min=%.1f max=%.1f cur=%s%.1f%s%s"
                SparklineAnsi.bold label SparklineAnsi.reset
                sparkStr
                mn mx
                col cur SparklineAnsi.reset
                unit

    /// <summary>
    /// Render a CPU sparkline with ANSI colouring on each block character.
    /// Values should be in [0.0, 100.0] (percent).
    /// Default width: 30 characters.
    /// </summary>
    /// <param name="history">CPU utilisation history in percent.</param>
    /// <returns>ANSI-coloured sparkline string.</returns>
    let renderCpuSparkline (history: float list) : string =
        let w = defaultWidth
        let fitted  = fitToWidth w history
        let normed  = normalise fitted
        let coloured =
            List.map2
                (fun normV rawV ->
                    let col = SparklineAnsi.valueColour normV
                    sprintf "%s%c%s" col (blockChar normV) SparklineAnsi.reset)
                normed
                fitted
        let sparkStr = String.concat "" coloured
        sprintf "%sCPU%s  %s  %s%.1f%%%s"
            SparklineAnsi.bold SparklineAnsi.reset
            sparkStr
            (SparklineAnsi.valueColour (match history with [] -> 0.0 | vs -> (List.last vs) / 100.0))
            (match history with [] -> 0.0 | vs -> List.last vs)
            SparklineAnsi.reset

    /// <summary>
    /// Render a memory sparkline with ANSI colouring.
    /// Values should be in [0.0, 100.0] (percent).
    /// Default width: 30 characters.
    /// </summary>
    /// <param name="history">Memory utilisation history in percent.</param>
    /// <returns>ANSI-coloured sparkline string.</returns>
    let renderMemorySparkline (history: float list) : string =
        let w = defaultWidth
        let fitted  = fitToWidth w history
        let normed  = normalise fitted
        let coloured =
            List.map2
                (fun normV _rawV ->
                    let col = SparklineAnsi.valueColour normV
                    sprintf "%s%c%s" col (blockChar normV) SparklineAnsi.reset)
                normed
                fitted
        let sparkStr = String.concat "" coloured
        sprintf "%sMEM%s  %s  %s%.1f%%%s"
            SparklineAnsi.bold SparklineAnsi.reset
            sparkStr
            (SparklineAnsi.valueColour (match history with [] -> 0.0 | vs -> (List.last vs) / 100.0))
            (match history with [] -> 0.0 | vs -> List.last vs)
            SparklineAnsi.reset

    /// <summary>
    /// Render multiple named sparklines aligned in a single multi-line block.
    /// Each sparkline occupies one output line, labels are padded to the same
    /// width so all sparklines line up horizontally.
    /// </summary>
    /// <param name="lines">List of (label, values) pairs.</param>
    /// <param name="width">Sparkline character width.</param>
    /// <returns>Multi-line string (lines joined with '\n').</returns>
    let renderMulti (lines: (string * float list) list) (width: int) : string =
        let w = if width <= 0 then defaultWidth else width
        match lines with
        | [] -> ""
        | ls ->
            let maxLabelLen =
                ls |> List.map (fun (lbl, _) -> lbl.Length) |> List.max
            ls
            |> List.map (fun (lbl, vs) ->
                let padded = lbl.PadRight(maxLabelLen)
                let sparkStr = render vs w
                let cur =
                    match vs with
                    | [] -> ""
                    | vals ->
                        let mn = List.min vals
                        let mx = List.max vals
                        let v  = List.last vals
                        let normV = if mx - mn < 1e-9 then 0.0 else clamp 0.0 1.0 ((v - mn) / (mx - mn))
                        let col = SparklineAnsi.valueColour normV
                        sprintf "  %s%.1f%s" col v SparklineAnsi.reset
                sprintf "%s%s%s  %s%s"
                    SparklineAnsi.bold padded SparklineAnsi.reset
                    sparkStr cur)
            |> String.concat "\n"

// ---------------------------------------------------------------------------
// SparklineMetrics — real /proc sampler with graceful fallback
// ---------------------------------------------------------------------------

/// <summary>
/// Samples real CPU and memory utilisation from the Linux /proc pseudo-filesystem
/// and produces float lists suitable for feeding into <see cref="Sparkline"/>.
///
/// When /proc is not available (e.g., macOS, Windows, or containerised environments
/// that do not expose /proc) every function falls back to deterministic demo data
/// so the TUI remains operational without crashing.
///
/// Compliance: SC-HMI-010 (real metabolic telemetry), SC-VDP-001 (cluster visualisation),
///             SC-CPU-GOV-009 (/proc/stat differential measurement).
/// </summary>
module SparklineMetrics =

    // -------------------------------------------------------------------
    // Private: /proc/stat CPU reader
    // -------------------------------------------------------------------

    /// Represents one snapshot of the aggregate CPU line from /proc/stat.
    /// Fields match the kernel's cpu_times struct (jiffies).
    [<Struct>]
    type private CpuSnapshot =
        { User: int64; Nice: int64; System: int64; Idle: int64
          Iowait: int64; Irq: int64; Softirq: int64 }

    /// Read the first 'cpu ' line from /proc/stat and return a CpuSnapshot.
    /// Returns None on any parse / IO error.
    let private readCpuSnapshot () : CpuSnapshot option =
        try
            let line =
                File.ReadLines("/proc/stat")
                |> Seq.tryFind (fun l -> l.StartsWith("cpu ", StringComparison.Ordinal))
            match line with
            | None -> None
            | Some l ->
                // "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
                let parts =
                    l.Split([| ' '; '\t' |], StringSplitOptions.RemoveEmptyEntries)
                if parts.Length < 8 then None
                else
                    Some {
                        User    = int64 parts.[1]
                        Nice    = int64 parts.[2]
                        System  = int64 parts.[3]
                        Idle    = int64 parts.[4]
                        Iowait  = int64 parts.[5]
                        Irq     = int64 parts.[6]
                        Softirq = int64 parts.[7]
                    }
        with _ -> None

    /// Compute CPU utilisation percent between two consecutive snapshots.
    /// Returns a value in [0.0, 100.0].
    let private cpuPctBetween (a: CpuSnapshot) (b: CpuSnapshot) : float =
        let idleDelta  = float (b.Idle + b.Iowait - a.Idle - a.Iowait)
        let totalDelta =
            float (  b.User + b.Nice + b.System + b.Idle + b.Iowait + b.Irq + b.Softirq
                   - a.User - a.Nice - a.System - a.Idle - a.Iowait - a.Irq - a.Softirq )
        if totalDelta < 1.0 then 0.0
        else Math.Round(Math.Max(0.0, Math.Min(100.0, (1.0 - idleDelta / totalDelta) * 100.0)), 2)

    // -------------------------------------------------------------------
    // Private: /proc/meminfo reader
    // -------------------------------------------------------------------

    /// Parse a single numeric kB field from /proc/meminfo by key.
    let private memField (key: string) (lines: string seq) : int64 option =
        lines
        |> Seq.tryFind (fun l -> l.StartsWith(key + ":", StringComparison.Ordinal))
        |> Option.bind (fun l ->
            let parts = l.Split([| ' '; '\t'; ':' |], StringSplitOptions.RemoveEmptyEntries)
            if parts.Length >= 2 then
                match System.Int64.TryParse(parts.[parts.Length - 2]) with
                | true, v -> Some v
                | _       -> None
            else None)

    /// Sample instantaneous memory utilisation percent from /proc/meminfo.
    /// Returns a value in [0.0, 100.0], or None on error.
    let private readMemPct () : float option =
        try
            let lines = File.ReadAllLines("/proc/meminfo") :> string seq
            match memField "MemTotal" lines, memField "MemAvailable" lines with
            | Some total, Some avail when total > 0L ->
                let usedPct = (1.0 - float avail / float total) * 100.0
                Some (Math.Round(Math.Max(0.0, Math.Min(100.0, usedPct)), 2))
            | _ -> None
        with _ -> None

    // -------------------------------------------------------------------
    // Private: demo (fallback) data generators
    // -------------------------------------------------------------------

    /// Generate N sinusoidal demo CPU samples (40–75% wave) without I/O.
    let private demoCpuSamples (n: int) : float list =
        [ for i in 0 .. n - 1 ->
            let t = float i / float (max 1 (n - 1))
            Math.Round(55.0 + 18.0 * Math.Sin(t * Math.PI * 2.0), 1) ]

    /// Generate N sinusoidal demo memory samples (50–70% wave) without I/O.
    let private demoMemSamples (n: int) : float list =
        [ for i in 0 .. n - 1 ->
            let t = float i / float (max 1 (n - 1))
            Math.Round(60.0 + 10.0 * Math.Sin(t * Math.PI * 1.5 + 1.0), 1) ]

    // -------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------

    /// <summary>
    /// Take a single instantaneous CPU utilisation reading from /proc/stat.
    /// Uses two reads 100 ms apart for accuracy (matches SC-CPU-GOV-009 method).
    /// Returns a value in [0.0, 100.0], or 50.0 as a safe demo fallback.
    /// </summary>
    let sampleCpuPct () : float =
        match readCpuSnapshot () with
        | None -> 50.0          // graceful degradation: /proc not available
        | Some snap1 ->
            Thread.Sleep(100)
            match readCpuSnapshot () with
            | None    -> 50.0
            | Some snap2 -> cpuPctBetween snap1 snap2

    /// <summary>
    /// Take a single instantaneous memory utilisation reading from /proc/meminfo.
    /// Returns a value in [0.0, 100.0], or 60.0 as a safe demo fallback.
    /// </summary>
    let sampleMemPct () : float =
        readMemPct () |> Option.defaultValue 60.0

    /// <summary>
    /// Collect <paramref name="n"/> CPU utilisation samples, each separated by
    /// <paramref name="intervalMs"/> milliseconds.  The function degrades to
    /// deterministic demo data if /proc/stat is unavailable on the first call.
    ///
    /// Returns a float list of length n, values in [0.0, 100.0].
    /// </summary>
    /// <param name="n">Number of samples (minimum 1).</param>
    /// <param name="intervalMs">Milliseconds between samples (minimum 100).</param>
    let collectCpuHistory (n: int) (intervalMs: int) : float list =
        let count    = max 1 n
        let interval = max 100 intervalMs
        // Probe /proc availability on first snapshot before committing to loop.
        match readCpuSnapshot () with
        | None ->
            // /proc not available — return deterministic demo data immediately.
            demoCpuSamples count
        | Some first ->
            // We already paid one 100ms wait inside sampleCpuPct — skip it here
            // to avoid doubling the first interval.  Collect the remainder live.
            let results = System.Collections.Generic.List<float>(count)
            let mutable prev = first
            for i in 1 .. count do
                if i > 1 then
                    Thread.Sleep(interval)
                match readCpuSnapshot () with
                | None ->
                    // /proc disappeared mid-run — fill remainder with last good value.
                    let last = if results.Count > 0 then results.[results.Count - 1] else 50.0
                    results.Add(last)
                | Some curr ->
                    let pct = cpuPctBetween prev curr
                    results.Add(pct)
                    prev <- curr
            results |> Seq.toList

    /// <summary>
    /// Collect <paramref name="n"/> memory utilisation samples, each separated by
    /// <paramref name="intervalMs"/> milliseconds.  Degrades to deterministic demo
    /// data if /proc/meminfo is unavailable.
    ///
    /// Returns a float list of length n, values in [0.0, 100.0].
    /// </summary>
    /// <param name="n">Number of samples (minimum 1).</param>
    /// <param name="intervalMs">Milliseconds between samples (minimum 0).</param>
    let collectMemHistory (n: int) (intervalMs: int) : float list =
        let count    = max 1 n
        let interval = max 0 intervalMs
        // Probe /proc availability once.
        match readMemPct () with
        | None ->
            demoMemSamples count
        | Some firstPct ->
            let results = System.Collections.Generic.List<float>(count)
            results.Add(firstPct)
            for _ in 2 .. count do
                if interval > 0 then Thread.Sleep(interval)
                let pct = readMemPct () |> Option.defaultValue firstPct
                results.Add(pct)
            results |> Seq.toList

    /// <summary>
    /// Convenience: produce a ready-to-render CPU sparkline string by sampling
    /// /proc/stat over <paramref name="n"/> intervals and passing the result to
    /// <see cref="Sparkline.renderCpuSparkline"/>.
    /// </summary>
    let liveCpuSparkline (n: int) (intervalMs: int) : string =
        collectCpuHistory n intervalMs
        |> Sparkline.renderCpuSparkline

    /// <summary>
    /// Convenience: produce a ready-to-render memory sparkline string by sampling
    /// /proc/meminfo over <paramref name="n"/> intervals and passing the result to
    /// <see cref="Sparkline.renderMemorySparkline"/>.
    /// </summary>
    let liveMemSparkline (n: int) (intervalMs: int) : string =
        collectMemHistory n intervalMs
        |> Sparkline.renderMemorySparkline
