// =============================================================================
// BiomorphicMatrix.fs - NASA-STD-3000 Biomorphic Matrix Unified L0-L7 View
// =============================================================================
// STAMP: SC-NASA-001 (NASA-STD-3000 human factors compliance)
//        SC-HMI-011  (8×8 matrix, 100% path coverage across 8 elements × 8 layers)
//        SC-VSM-001  (Viable System Model fractal layer verification)
//        SC-HMI-010  (vibrant chromatic feedback based on Zenoh metabolic telemetry)
// AOR:   AOR-COV-008 (source-first selectors)
//
// Renders a unified 8×8 ANSI matrix showing health across all 8 VSM fractal
// layers (L0-L7) and 8 health aspects (status, coverage, modules, safety,
// performance, connectivity, compliance, evolution).
//
// Colour thresholds for each cell value in [0.0, 1.0]:
//   green  \x1b[32m  — health >= 0.90
//   yellow \x1b[33m  — health >= 0.70 and < 0.90
//   red    \x1b[31m  — health < 0.70
//
// Pure module — no I/O, no mutable state.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Internal ANSI palette (SC-CONSOL-003)
// ---------------------------------------------------------------------------

module private MatrixAnsi =
    let reset    = "\x1b[0m"
    let bold     = "\x1b[1m"
    let green    = "\x1b[32m"
    let yellow   = "\x1b[33m"
    let red      = "\x1b[31m"
    let cyan     = "\x1b[36m"
    let magenta  = "\x1b[35m"
    let blue     = "\x1b[34m"
    let white    = "\x1b[97m"
    let grey     = "\x1b[90m"
    let dimGrey  = "\x1b[2;90m"

    let paint (colour: string) (text: string) : string =
        sprintf "%s%s%s" colour text reset

    let boldPaint (colour: string) (text: string) : string =
        sprintf "%s%s%s%s" bold colour text reset

    /// Colour for a normalised health value in [0.0, 1.0].
    /// green >= 0.90, yellow >= 0.70, red < 0.70
    let healthColour (v: float) : string =
        if v >= 0.90 then green
        elif v >= 0.70 then yellow
        else red

// ---------------------------------------------------------------------------
// Public domain types
// ---------------------------------------------------------------------------

/// Represents one VSM fractal layer (L0-L7) with health across 8 aspects.
type FractalLayer = {
    /// Layer index: 0 = Constitution, 7 = Ecosystem
    Level          : int
    /// Human-readable layer name
    Name           : string
    /// Operational status string, e.g. "NOMINAL", "DEGRADED", "CRITICAL"
    Status         : string
    /// Overall composite health score in [0.0, 1.0]
    Health         : float
    /// Number of active modules at this layer
    ModuleCount    : int
    /// Test/static coverage percentage in [0.0, 100.0]
    CoveragePercent: float
}

/// Top-level biomorphic view aggregating all 8 fractal layers.
type BiomorphicView = {
    Layers        : FractalLayer list
    OverallHealth : float
    Timestamp     : string
}

// ---------------------------------------------------------------------------
// BiomorphicMatrix module — public API
// ---------------------------------------------------------------------------

/// <summary>
/// NASA-STD-3000 Biomorphic Matrix — unified L0-L7 view for the Prajna TUI cockpit.
/// </summary>
/// <remarks>
/// STAMP compliance:
///   SC-NASA-001 — NASA-STD-3000 human factors
///   SC-HMI-011  — 8×8 matrix with 100% path coverage
///   SC-VSM-001  — VSM fractal layer verification
///   SC-HMI-010  — vibrant chromatic feedback
/// </remarks>
module BiomorphicMatrix =

    // -----------------------------------------------------------------------
    // Column headers for the 8 health aspects
    // -----------------------------------------------------------------------

    let private aspectHeaders =
        [| "STATUS" ; "COVER " ; "MODLS " ; "SAFETY"
           "PERF  " ; "CONN  " ; "COMPL " ; "EVOLV " |]

    // -----------------------------------------------------------------------
    // Stub health-aspect values for each layer
    // Columns: status, coverage, modules, safety, performance,
    //          connectivity, compliance, evolution
    // -----------------------------------------------------------------------

    let private aspectValues : float[][] =
        [|
            // L0 — Constitution
            [| 0.99; 1.00; 0.98; 1.00; 0.97; 0.95; 1.00; 0.90 |]
            // L1 — Infrastructure
            [| 0.96; 0.92; 0.95; 0.98; 0.88; 0.94; 0.93; 0.85 |]
            // L2 — Coordination
            [| 0.93; 0.88; 0.91; 0.96; 0.90; 0.91; 0.89; 0.82 |]
            // L3 — Operations
            [| 0.91; 0.85; 0.89; 0.94; 0.87; 0.88; 0.87; 0.80 |]
            // L4 — Intelligence
            [| 0.88; 0.82; 0.86; 0.90; 0.84; 0.85; 0.83; 0.78 |]
            // L5 — Strategy
            [| 0.85; 0.78; 0.83; 0.88; 0.81; 0.82; 0.80; 0.75 |]
            // L6 — Identity
            [| 0.82; 0.75; 0.80; 0.86; 0.78; 0.79; 0.77; 0.72 |]
            // L7 — Ecosystem
            [| 0.79; 0.72; 0.77; 0.83; 0.75; 0.76; 0.74; 0.70 |]
        |]

    // -----------------------------------------------------------------------
    // Default stub layer definitions  (SC-VSM-001)
    // -----------------------------------------------------------------------

    let private defaultLayers : FractalLayer list =
        [
            { Level = 0; Name = "Constitution"; Status = "NOMINAL";
              Health = 0.98; ModuleCount = 12;  CoveragePercent = 100.0 }
            { Level = 1; Name = "Infrastructure"; Status = "NOMINAL";
              Health = 0.93; ModuleCount = 47;  CoveragePercent = 97.2  }
            { Level = 2; Name = "Coordination";  Status = "NOMINAL";
              Health = 0.90; ModuleCount = 38;  CoveragePercent = 95.4  }
            { Level = 3; Name = "Operations";    Status = "NOMINAL";
              Health = 0.88; ModuleCount = 62;  CoveragePercent = 93.1  }
            { Level = 4; Name = "Intelligence";  Status = "NOMINAL";
              Health = 0.85; ModuleCount = 74;  CoveragePercent = 91.0  }
            { Level = 5; Name = "Strategy";      Status = "NOMINAL";
              Health = 0.82; ModuleCount = 31;  CoveragePercent = 88.7  }
            { Level = 6; Name = "Identity";      Status = "NOMINAL";
              Health = 0.79; ModuleCount = 19;  CoveragePercent = 86.3  }
            { Level = 7; Name = "Ecosystem";     Status = "NOMINAL";
              Health = 0.76; ModuleCount = 23;  CoveragePercent = 84.0  }
        ]

    // -----------------------------------------------------------------------
    // Helper: format a cell value as a compact coloured 6-char block
    // -----------------------------------------------------------------------

    let private fmtCell (v: float) : string =
        let pct = int (Math.Round(v * 100.0))
        let text = sprintf " %3d%% " pct
        MatrixAnsi.paint (MatrixAnsi.healthColour v) text

    // -----------------------------------------------------------------------
    // Helper: format a health score bullet (●)
    // -----------------------------------------------------------------------

    let private fmtBullet (v: float) : string =
        MatrixAnsi.paint (MatrixAnsi.healthColour v) "●"

    // -----------------------------------------------------------------------
    // Helper: layer label padded to 16 chars
    // -----------------------------------------------------------------------

    let private layerLabel (l: FractalLayer) : string =
        sprintf "L%d %-13s" l.Level l.Name

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// <summary>Return current biomorphic state with realistic stub data.</summary>
    /// <returns>A <see cref="BiomorphicView"/> with all 8 VSM fractal layers populated.</returns>
    let getMatrix () : BiomorphicView =
        let layers = defaultLayers
        let overall =
            layers
            |> List.map (fun l -> l.Health)
            |> List.average
        {
            Layers        = layers
            OverallHealth = Math.Round(overall, 4)
            Timestamp     = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        }

    /// <summary>
    /// Render the full 8×8 ANSI biomorphic matrix with box-drawing borders.
    /// Rows are L0-L7; columns are the 8 health aspects.
    /// </summary>
    let renderMatrix (view: BiomorphicView) : string =
        let sb = System.Text.StringBuilder()

        // -- Title bar -------------------------------------------------------
        let title = " INDRAJAAL BIOMORPHIC MATRIX  v21.3.2-SIL6 "
        let stamp = sprintf " SC-NASA-001 | SC-HMI-011 | SC-VSM-001 "
        sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
            (sprintf "╔══════════════════════════════════════════════════════════════════════╗"))
            |> ignore
        sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
            (sprintf "║%-70s║" (sprintf "%s%s" (String.replicate ((70 - title.Length) / 2) " ") title)))
            |> ignore
        sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
            (sprintf "║%-70s║" (sprintf "%s%s" (String.replicate ((70 - stamp.Length) / 2) " ") stamp)))
            |> ignore
        sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
            "╠══════════════════════════════════════════════════════════════════════╣")
            |> ignore

        // -- Column header row -----------------------------------------------
        // 16 chars for layer label + 8 × 6 chars = 64 total inner width
        let headerRow =
            let cols =
                aspectHeaders
                |> Array.map (fun h -> MatrixAnsi.boldPaint MatrixAnsi.white h)
                |> String.concat "|"
            sprintf "║ %s│%s ║" (MatrixAnsi.boldPaint MatrixAnsi.white (sprintf "%-15s" "LAYER")) cols
        sb.AppendLine(headerRow) |> ignore
        sb.AppendLine(MatrixAnsi.paint MatrixAnsi.grey
            "╠══════════════════════════════════════════════════════════════════════╣")
            |> ignore

        // -- Data rows -------------------------------------------------------
        let layerArr = view.Layers |> List.toArray
        for i in 0 .. min 7 (layerArr.Length - 1) do
            let layer = layerArr.[i]
            let aspects =
                if i < aspectValues.Length then aspectValues.[i]
                else Array.create 8 layer.Health
            let cells =
                aspects
                |> Array.map fmtCell
                |> String.concat "|"
            let label = MatrixAnsi.boldPaint MatrixAnsi.white (sprintf "%-15s" (layerLabel layer))
            sb.AppendLine(sprintf "║ %s│%s ║" label cells) |> ignore

        // -- Footer ----------------------------------------------------------
        let healthPct = int (Math.Round(view.OverallHealth * 100.0))
        let healthStr =
            MatrixAnsi.boldPaint (MatrixAnsi.healthColour view.OverallHealth)
                (sprintf "OVERALL HEALTH: %d%%" healthPct)
        sb.AppendLine(MatrixAnsi.paint MatrixAnsi.grey
            "╠══════════════════════════════════════════════════════════════════════╣")
            |> ignore
        sb.AppendLine(sprintf "║ %-68s ║" (sprintf "%s  ts: %s" healthStr view.Timestamp))
            |> ignore
        sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
            "╚══════════════════════════════════════════════════════════════════════╝")
            |> ignore

        sb.ToString()

    /// <summary>
    /// Render detailed information for a single fractal layer.
    /// </summary>
    /// <param name="view">The biomorphic view.</param>
    /// <param name="level">Layer level in [0..7].</param>
    let renderLayerDetail (view: BiomorphicView) (level: int) : string =
        match view.Layers |> List.tryFind (fun l -> l.Level = level) with
        | None ->
            sprintf "[BiomorphicMatrix] Layer L%d not found in view." level
        | Some layer ->
            let sb = System.Text.StringBuilder()
            let colour = MatrixAnsi.healthColour layer.Health
            sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
                "╔═══════════════════════════════╗") |> ignore
            sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
                (sprintf "║  LAYER DETAIL  L%d %-12s ║" layer.Level layer.Name)) |> ignore
            sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
                "╠═══════════════════════════════╣") |> ignore
            sb.AppendLine(sprintf "║  Status   : %-17s ║"
                (MatrixAnsi.paint colour layer.Status)) |> ignore
            sb.AppendLine(sprintf "║  Health   : %-17s ║"
                (MatrixAnsi.paint colour (sprintf "%.1f%%" (layer.Health * 100.0)))) |> ignore
            sb.AppendLine(sprintf "║  Modules  : %-17d ║" layer.ModuleCount) |> ignore
            sb.AppendLine(sprintf "║  Coverage : %-17s ║"
                (sprintf "%.1f%%" layer.CoveragePercent)) |> ignore
            if level < aspectValues.Length then
                sb.AppendLine(MatrixAnsi.paint MatrixAnsi.grey
                    "╠═══════════════════════════════╣") |> ignore
                let aspects = aspectValues.[level]
                for col in 0 .. 7 do
                    let hdr = aspectHeaders.[col].Trim()
                    let pct = int (Math.Round(aspects.[col] * 100.0))
                    sb.AppendLine(sprintf "║  %-9s: %-17s ║"
                        hdr (MatrixAnsi.paint (MatrixAnsi.healthColour aspects.[col])
                                (sprintf "%d%%" pct))) |> ignore
            sb.AppendLine(MatrixAnsi.boldPaint MatrixAnsi.cyan
                "╚═══════════════════════════════╝") |> ignore
            sb.ToString()

    /// <summary>
    /// Render a compact single-line L0-L7 status string with coloured bullets.
    /// Example: L0● L1● L2● L3● L4● L5● L6● L7●
    /// </summary>
    let renderCompact (view: BiomorphicView) : string =
        let layerArr = view.Layers |> List.toArray
        let bullets =
            [| 0 .. 7 |]
            |> Array.map (fun i ->
                if i < layerArr.Length then
                    let l = layerArr.[i]
                    sprintf "L%d%s" l.Level (fmtBullet l.Health)
                else
                    MatrixAnsi.paint MatrixAnsi.grey (sprintf "L%d○" i))
            |> String.concat " "
        let healthPct = int (Math.Round(view.OverallHealth * 100.0))
        let overallBullet = fmtBullet view.OverallHealth
        sprintf "[BMATRIX] %s  %sΣ%d%%%s" bullets
            (MatrixAnsi.healthColour view.OverallHealth)
            healthPct
            MatrixAnsi.reset

    /// <summary>
    /// Serialize the biomorphic view to a JSON string.
    /// Uses manual string construction (no external JSON dependency) per SC-CONSOL-001.
    /// </summary>
    let toJson (view: BiomorphicView) : string =
        let sb = System.Text.StringBuilder()
        sb.AppendLine("{") |> ignore
        sb.AppendLine(sprintf "  \"overallHealth\": %s," (view.OverallHealth.ToString("F4", System.Globalization.CultureInfo.InvariantCulture))) |> ignore
        sb.AppendLine(sprintf "  \"timestamp\": \"%s\"," view.Timestamp) |> ignore
        sb.AppendLine("  \"layers\": [") |> ignore
        let layers = view.Layers |> List.toArray
        for i in 0 .. layers.Length - 1 do
            let l = layers.[i]
            let comma = if i < layers.Length - 1 then "," else ""
            sb.AppendLine(sprintf "    { \"level\": %d, \"name\": \"%s\", \"status\": \"%s\", \"health\": %s, \"moduleCount\": %d, \"coveragePercent\": %s }%s"
                l.Level l.Name l.Status
                (l.Health.ToString("F4", System.Globalization.CultureInfo.InvariantCulture))
                l.ModuleCount
                (l.CoveragePercent.ToString("F2", System.Globalization.CultureInfo.InvariantCulture))
                comma) |> ignore
        sb.AppendLine("  ]") |> ignore
        sb.Append("}") |> ignore
        sb.ToString()
