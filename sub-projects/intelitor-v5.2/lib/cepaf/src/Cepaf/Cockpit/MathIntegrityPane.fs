// =============================================================================
// MathIntegrityPane.fs - CEPAF Cockpit TUI Mathematical Integrity Pane
// =============================================================================
// STAMP: SC-MATH-001 (Discipline health monitored), SC-MATH-002 (Token ratios)
// AOR:   AOR-MATH-001 (Monitor mathematical discipline health continuously)
//
// Pure rendering module — returns ANSI-coloured pane string showing:
//   Hs (Shannon Entropy), ε (Epsilon Divergence), Ds (Discipline Coverage),
//   top-5 RPN-ranked disciplines, and maturity summary.
//
// No side effects. All state passed in via MathIntegrityState record.
//
// ## Constitutional Alignment
// - Ψ₁ (Regeneration): State stored in SQLite/DuckDB; pane reflects live snapshot
// - Ψ₃ (Verification): All metrics numeric and auditable
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Per-discipline health record surfaced in the cockpit pane.
type DisciplineScore = {
    /// Human-readable discipline name (e.g. "Shannon Entropy", "Reed-Solomon")
    Name     : string
    /// Composite health score 0.0–1.0
    Score    : float
    /// Maturity label: "Production" | "Stabilisation" | "Prototype" | "Isolated"
    Maturity : string
    /// FMEA Risk Priority Number (Severity × Occurrence × Detection)
    Rpn      : int
}

/// Full snapshot of mathematical integrity signals for the cockpit pane.
type MathIntegrityState = {
    /// Shannon entropy of the code↔doc constraint distribution (bits).
    /// Target: >= 2.5 bits  (balanced discipline coverage).
    ShannonEntropy    : float
    /// KL-divergence epsilon between code and doc distributions.
    /// Target: < 0.01 (near-parity).
    EpsilonDivergence : float
    /// Total number of monitored disciplines.
    DisciplineCount   : int
    /// Number of disciplines at "Production" maturity.
    ProductionCount   : int
    /// All discipline scores (full list; pane shows top 5 by RPN).
    Disciplines       : DisciplineScore list
    /// Snapshot timestamp.
    Timestamp         : DateTimeOffset
}

// ---------------------------------------------------------------------------
// ANSI colour helpers (inline — avoids Cepaf.Observability dependency)
// ---------------------------------------------------------------------------

module private MiAnsi =
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
    let bMag    = "\u001b[95m"

// ---------------------------------------------------------------------------
// MathIntegrityPane — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders the mathematical integrity cockpit pane.
/// All functions are pure (no I/O). Callers print the returned string.
[<RequireQualifiedAccess>]
module MathIntegrityPane =

    // -----------------------------------------------------------------------
    // Internal colour-selection helpers
    // -----------------------------------------------------------------------

    /// Colour for Shannon entropy: green >= 2.5, yellow >= 2.0, else red.
    let private colourForEntropy (hs: float) : string =
        if hs >= 2.5 then MiAnsi.bGreen
        elif hs >= 2.0 then MiAnsi.bYellow
        else MiAnsi.bRed

    /// Colour for epsilon divergence: green < 0.01, yellow < 0.05, else red.
    let private colourForEpsilon (eps: float) : string =
        if eps < 0.01 then MiAnsi.bGreen
        elif eps < 0.05 then MiAnsi.bYellow
        else MiAnsi.bRed

    /// Colour for discipline coverage fraction: green = 1.0, yellow >= 0.8, else red.
    let private colourForCoverage (prod: int) (total: int) : string =
        if total = 0 then MiAnsi.bRed
        else
            let ratio = float prod / float total
            if ratio >= 1.0 then MiAnsi.bGreen
            elif ratio >= 0.8 then MiAnsi.bYellow
            else MiAnsi.bRed

    /// Colour for an RPN value: green < 50, yellow < 100, else red.
    let private colourForRpn (rpn: int) : string =
        if rpn < 50 then MiAnsi.bGreen
        elif rpn < 100 then MiAnsi.bYellow
        else MiAnsi.bRed

    // -----------------------------------------------------------------------
    // Bar chart helper — produces an ASCII bar scaled to totalWidth chars
    // -----------------------------------------------------------------------

    /// Renders a filled ASCII progress bar for a value in [0, maxVal].
    let private bar (value: float) (maxVal: float) (totalWidth: int) (colour: string) : string =
        let pct    = if maxVal > 0.0 then value / maxVal else 0.0
        let filled = int (pct * float totalWidth) |> max 0 |> min totalWidth
        let empty  = totalWidth - filled
        let b      = String.replicate filled "█" + String.replicate empty "░"
        sprintf "%s%s%s" colour b MiAnsi.reset

    // -----------------------------------------------------------------------
    // Discipline row renderer
    // -----------------------------------------------------------------------

    /// Renders a single discipline row: "  Name           RPN:NNN  Maturity"
    let private disciplineRow (d: DisciplineScore) : string =
        let rpnCol  = colourForRpn d.Rpn
        let nameStr = d.Name.PadRight(20)
        let matCol  =
            match d.Maturity with
            | "Production"    -> MiAnsi.bGreen
            | "Stabilisation" -> MiAnsi.bYellow
            | _               -> MiAnsi.bRed
        sprintf "  %s%s%s  RPN:%s%3d%s  %s%s%s"
            MiAnsi.white nameStr MiAnsi.reset
            rpnCol d.Rpn MiAnsi.reset
            matCol d.Maturity MiAnsi.reset

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders the full mathematical integrity cockpit pane.
    /// Returns a multi-line ANSI-coloured string suitable for Console.Write.
    let renderPane (state: MathIntegrityState) : string =
        let sep = sprintf "%s%s%s" MiAnsi.bMag (String.replicate 60 "─") MiAnsi.reset
        let hdr = sprintf "%s%s MATHEMATICAL INTEGRITY %s%s"
                      MiAnsi.bold MiAnsi.bCyan MiAnsi.reset MiAnsi.reset

        let ts  = state.Timestamp.ToString("yyyy-MM-dd HH:mm:ss zzz")

        // --- Hs (Shannon Entropy) row ---
        let hsCol   = colourForEntropy state.ShannonEntropy
        let hsBar   = bar state.ShannonEntropy 4.0 20 hsCol          // max sensible = 4 bits
        let hsRow   = sprintf "  Hs (entropy)  %s  %s%.3f bits%s  %s(target≥2.5)%s"
                          hsBar
                          hsCol state.ShannonEntropy MiAnsi.reset
                          MiAnsi.dim MiAnsi.reset

        // --- ε (Epsilon Divergence) row ---
        let epsCol  = colourForEpsilon state.EpsilonDivergence
        let epsRow  = sprintf "  ε (divergence)               %s%.4f%s  %s(target<0.01)%s"
                          epsCol state.EpsilonDivergence MiAnsi.reset
                          MiAnsi.dim MiAnsi.reset

        // --- Ds (Discipline Coverage) row ---
        let dsCol   = colourForCoverage state.ProductionCount state.DisciplineCount
        let dsPct   =
            if state.DisciplineCount > 0
            then float state.ProductionCount / float state.DisciplineCount * 100.0
            else 0.0
        let dsRow   = sprintf "  Ds (coverage)                %s%d / %d%s  (%s%.0f%%%s)"
                          dsCol state.ProductionCount state.DisciplineCount MiAnsi.reset
                          dsCol dsPct MiAnsi.reset

        // --- Top-5 disciplines by RPN (descending) ---
        let top5    =
            state.Disciplines
            |> List.sortByDescending (fun d -> d.Rpn)
            |> List.truncate 5

        let top5Hdr = sprintf "  %sTop disciplines by RPN:%s" MiAnsi.dim MiAnsi.reset
        let top5Rows =
            top5 |> List.map disciplineRow |> String.concat "\n"

        // --- Maturity summary row ---
        let matCol  = colourForCoverage state.ProductionCount state.DisciplineCount
        let matRow  = sprintf "  Maturity  Production: %s%d / %d%s"
                          matCol state.ProductionCount state.DisciplineCount MiAnsi.reset

        // --- Timestamp ---
        let timeRow = sprintf "  %sUpdated:%s %s%s%s"
                          MiAnsi.dim MiAnsi.reset MiAnsi.white ts MiAnsi.reset

        // Assemble
        [ ""
          sep
          sprintf "  %s" hdr
          sep
          hsRow
          epsRow
          dsRow
          sep
          top5Hdr
          top5Rows
          sep
          matRow
          sep
          timeRow
          sep
          "" ]
        |> String.concat "\n"

    /// Renders a compact one-liner for embedding in logs or status bars.
    /// Example: "Hs=2.800 ε=0.0071 Ds=17/17 (100%) RPN_max=50"
    let renderCompact (state: MathIntegrityState) : string =
        let maxRpn =
            state.Disciplines
            |> List.map (fun d -> d.Rpn)
            |> (fun xs -> if List.isEmpty xs then 0 else List.max xs)
        let dsPct =
            if state.DisciplineCount > 0
            then float state.ProductionCount / float state.DisciplineCount * 100.0
            else 0.0
        let hsCol  = colourForEntropy state.ShannonEntropy
        let epsCol = colourForEpsilon state.EpsilonDivergence
        let dsCol  = colourForCoverage state.ProductionCount state.DisciplineCount
        let rpnCol = colourForRpn maxRpn
        sprintf "Hs=%s%.3f%s ε=%s%.4f%s Ds=%s%d/%d%s (%.0f%%) RPN_max=%s%d%s"
            hsCol state.ShannonEntropy MiAnsi.reset
            epsCol state.EpsilonDivergence MiAnsi.reset
            dsCol state.ProductionCount state.DisciplineCount MiAnsi.reset dsPct
            rpnCol maxRpn MiAnsi.reset
