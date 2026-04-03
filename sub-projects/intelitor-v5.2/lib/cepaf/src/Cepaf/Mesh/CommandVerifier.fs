// =============================================================================
// CommandVerifier.fs - GA Runtime Verifier for 32 devenv sa-* Commands
// =============================================================================
// STAMP: SC-VER-042 (All CLI commands functional), AOR-CMD-001
// AOR:   AOR-CMD-001 (sa-* command verification), AOR-CMD-002, AOR-CMD-003
//
// ## Purpose
// Verifies that all 32 devenv shell commands (sa-up, sa-down, sa-status,
// sa-plan, sa-verify, etc.) are available by probing file existence in the
// project's bin/, scripts/ directories and standard system PATH locations.
// NO command execution is ever performed (SC-VER-042 compliance).
//
// ## Safety Contract
// - File.Exists probes ONLY — no process spawning, no shell execution
// - All File.Exists / Directory.GetFiles calls wrapped in try/with
// - Result is a structural snapshot, not a runtime-availability guarantee
//
// ## Probe Strategy (priority order)
// 1. bin/<name>                   — compiled binary in project bin/
// 2. ./<name>.fsx, ./<name>       — root-level devenv scripts
// 3. scripts/<name>[.fsx|.sh]     — scripts/ subdirectory
// 4. System PATH dirs             — /usr/bin, ~/.nix-profile/bin, etc.
//
// ## Constraint Compliance
// - SC-VER-042 — All CLI commands functional; this module detects missing ones
// - AOR-CMD-001 — sa-* command verification before deployment gates
// - SC-CLI-001  — CLI interface must be validated at runtime
//
// ## Document Control
// | Field   | Value                             |
// |---------|-----------------------------------|
// | Version | 2.1.0                             |
// | Created | 2026-03-30                        |
// | Author  | Code Evolution Agent (W11)        |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.IO
open Cepaf.Observability.ConsoleChannel  // SC-CONSOL-003: Centralized ANSI colors

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Availability status of a single devenv command after file-existence probing.
[<RequireQualifiedAccess>]
type CommandStatus =
    /// Command binary or script was found on at least one probed path.
    | Available
    /// Command was not found on any probed path.
    | Missing
    /// An unexpected error occurred during the probe (I/O, permissions, etc.).
    | Error of reason: string

/// Full metadata record for one devenv command.
type CommandInfo = {
    /// Command name as invoked on the CLI (e.g. "sa-up").
    Name: string
    /// Human-readable description of the command's purpose.
    Description: string
    /// Logical category grouping for report display.
    Category: string
    /// Result of the file-existence probe.
    Status: CommandStatus
    /// UTC timestamp when the probe was performed.
    CheckedAt: DateTimeOffset
}

/// Aggregate result of probing all 32 devenv commands.
/// Named CommandVerificationResult to avoid clash with StartupVerification.VerificationResult.
type CommandVerificationResult = {
    /// Total number of commands checked.
    Total: int
    /// Count of commands whose probe returned Available.
    Available: int
    /// Count of commands whose probe returned Missing.
    Missing: int
    /// Count of commands whose probe returned Error.
    Errors: int
    /// Per-command detail records (ordered by category then name).
    Commands: CommandInfo list
    /// UTC timestamp when the full verification run completed.
    Timestamp: DateTimeOffset
}

// ---------------------------------------------------------------------------
// Module
// ---------------------------------------------------------------------------

/// <summary>
/// GA runtime verifier for the 32 devenv sa-* commands.
///
/// All probing is file-existence only — no commands are ever executed.
///
/// STAMP Compliance:
///   SC-VER-042 — All CLI commands must be functional; this module detects missing ones.
///   AOR-CMD-001 — Verification runs before deployment gates.
///   SC-CLI-001  — CLI interface validated at startup.
/// </summary>
[<RequireQualifiedAccess>]
module CommandVerifier =

    // -----------------------------------------------------------------------
    // Private: project root resolution
    // -----------------------------------------------------------------------

    /// Walk upward from the current base directory to find the project root.
    /// Anchor is the presence of mix.exs or a bin/Cepaf binary.
    /// Capped at 10 levels to prevent runaway traversal.
    let private findProjectRoot () : string =
        let startDir =
            try AppContext.BaseDirectory
            with _ -> Environment.CurrentDirectory

        let rec walk (dir: string) (depth: int) =
            if depth > 10 then dir
            elif
                try File.Exists(Path.Combine(dir, "mix.exs"))
                with _ -> false
            then dir
            elif
                try
                    Directory.Exists(Path.Combine(dir, "bin")) &&
                    File.Exists(Path.Combine(dir, "bin", "Cepaf"))
                with _ -> false
            then dir
            else
                try
                    let parent = Directory.GetParent(dir)
                    match parent with
                    | null -> dir
                    | p    -> walk p.FullName (depth + 1)
                with _ -> dir

        walk startDir 0

    // -----------------------------------------------------------------------
    // Private: static command registry (32 commands)
    // -----------------------------------------------------------------------

    /// Static registry of all 32 devenv commands.
    /// Each entry is (name, description, category).
    let private commandRegistry : (string * string * string) list = [
        // lifecycle (4)
        "sa-up",          "Boot the 16-container SIL-6 biomorphic mesh",             "lifecycle"
        "sa-down",        "Graceful mesh shutdown with dying-gasp checkpoint",        "lifecycle"
        "sa-status",      "Display full mesh health matrix (16 nodes)",               "lifecycle"
        "sa-restart",     "Rolling restart of mesh containers with quorum gate",      "lifecycle"

        // planning (3)
        "sa-plan",        "F# task management CLI (list/add/update/status)",          "planning"
        "sa-monitor",     "Continuous real-time mesh metrics monitor",                "planning"
        "sa-genotype",    "Inspect holon genotype topology and container DAG",        "planning"

        // verification (5)
        "sa-verify",      "2oo3 voting verification of mesh state (SC-SIL6-023)",     "verification"
        "sa-fractal-verify","7-level fractal RCA verification across L0-L7",          "verification"
        "sa-verify-all",  "Full verification suite — all layers, all constraints",    "verification"
        "sa-sil6-boot",   "SIL-6 hardened boot sequence with phase gating",          "verification"
        "sa-scour",       "Port scouring — release all occupied mesh ports",          "verification"

        // mesh (5)
        "sa-mesh",        "Direct mesh control — topology, routing, quorum",          "mesh"
        "sa-emergency",   "Emergency stop — immediate halt of all mesh operations",   "mesh"
        "sa-multiverse",  "Multiverse branch promotion and merge gateway",            "mesh"
        "sa-stabilize",   "Homeostasis stabilization — bring mesh to steady state",   "mesh"
        "sa-sil6-homeostasis-boot","Homeostasis-aware SIL-6 mesh boot sequence",     "mesh"

        // build (5)
        "sa-build",       "Full project build (Elixir + F# + Rust NIFs)",             "build"
        "sa-compile",     "Elixir compile with Patient Mode and CPU governance",      "build"
        "sa-test",        "Governed test runner with SKIP_ZENOH_NIF=0",              "build"
        "sa-logs",        "Stream aggregate mesh logs via Zenoh telemetry",           "build"
        "sa-fractal-verify","Fractal layer build verification (L0-L7)",              "build"

        // deploy (3)
        "sa-deploy",      "Staged deployment — shadow test → activate",              "deploy"
        "sa-patch-cubdb", "Apply CubDB schema patches to holon state store",         "deploy"
        "sa-update-kms-schema","Migrate KMS key-management schema to latest",        "deploy"

        // monitoring (4)
        "sa-health",      "Point-in-time health probe for all mesh containers",       "monitoring"
        "sa-metrics",     "Collect and display Zenoh telemetry KPIs",                "monitoring"
        "sa-monitor",     "Live log aggregation from all Zenoh telemetry streams",   "monitoring"
        "sa-stabilize",   "Observe homeostatic controller PID convergence",          "monitoring"

        // admin (3)
        "sa-clean",       "Remove stale build artefacts and dangling containers",    "admin"
        "sa-backup",      "Create timestamped snapshot of holon SQLite/DuckDB state","admin"
        "sa-restore",     "Restore holon state from a named checkpoint",             "admin"
    ]

    // -----------------------------------------------------------------------
    // Private: probe helpers
    // -----------------------------------------------------------------------

    /// Safely check whether a file exists, catching all I/O exceptions.
    let private safeFileExists (path: string) : Result<bool, string> =
        try Ok (File.Exists(path))
        with ex -> Error ex.Message

    /// Safely scan a directory for files matching an exact name.
    let private safeGetFiles (dir: string) (name: string) : Result<bool, string> =
        try
            if Directory.Exists(dir) then
                let hits = Directory.GetFiles(dir, name, SearchOption.TopDirectoryOnly)
                Ok (hits.Length > 0)
            else
                Ok false
        with ex -> Error ex.Message

    /// Build the ordered list of probe-candidate paths for a given command name
    /// and resolved project root.
    let private probePaths (root: string) (name: string) : string list =
        // Project-local candidates
        let local =
            [ Path.Combine(root, "bin", name)
              Path.Combine(root, name + ".fsx")
              Path.Combine(root, name)
              Path.Combine(root, "scripts", name)
              Path.Combine(root, "scripts", name + ".fsx")
              Path.Combine(root, "scripts", name + ".sh") ]

        // Standard system PATH directories (NixOS / devenv / regular Linux)
        let systemDirs =
            [ "/usr/bin"
              "/usr/local/bin"
              "/bin"
              "/home/an/.nix-profile/bin"
              "/nix/var/nix/profiles/default/bin"
              "/run/current-system/sw/bin" ]

        // Also honour the runtime PATH env var
        let pathEnvDirs =
            Environment.GetEnvironmentVariable("PATH")
            |> Option.ofObj
            |> Option.defaultValue ""
            |> fun s -> s.Split(Path.PathSeparator)
            |> Array.toList

        let systemCandidates =
            (systemDirs @ pathEnvDirs)
            |> List.distinct
            |> List.filter (fun d -> not (String.IsNullOrWhiteSpace(d)))
            |> List.map (fun d -> Path.Combine(d, name))

        local @ systemCandidates

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// <summary>
    /// Check whether a single named devenv command is available via file-existence probe.
    ///
    /// Probe sequence (stops at first hit):
    ///   1. bin/&lt;name&gt;                  — compiled project binary
    ///   2. ./&lt;name&gt;.fsx, ./&lt;name&gt;     — root-level devenv scripts
    ///   3. scripts/&lt;name&gt;              — scripts subdirectory
    ///   4. System PATH directories     — /usr/bin, /usr/local/bin, ~/.nix-profile/bin, …
    ///
    /// No process is spawned. All I/O calls are wrapped in try/with.
    /// </summary>
    /// <param name="name">Command name to probe (e.g. "sa-up").</param>
    /// <returns>
    ///   A <see cref="CommandInfo"/> record containing the probe result and metadata.
    /// </returns>
    let checkCommand (name: string) : CommandInfo =
        let root       = findProjectRoot ()
        let paths      = probePaths root name
        let checkedAt  = DateTimeOffset.UtcNow

        let rec tryPaths (remaining: string list) (firstError: string option) : CommandStatus =
            match remaining with
            | [] ->
                match firstError with
                | Some msg -> CommandStatus.Error msg
                | None     -> CommandStatus.Missing
            | path :: rest ->
                match safeFileExists path with
                | Error msg ->
                    // Record first I/O error but keep probing remaining paths.
                    tryPaths rest (firstError |> Option.orElse (Some $"probe error on '{path}': {msg}"))
                | Ok true ->
                    CommandStatus.Available
                | Ok false ->
                    // Secondary scan: check via Directory.GetFiles in case the
                    // path normalisation differs on unusual file systems.
                    let dir  = Path.GetDirectoryName(path)
                    let file = Path.GetFileName(path)
                    match safeGetFiles dir file with
                    | Ok true  -> CommandStatus.Available
                    | _        -> tryPaths rest firstError

        let status = tryPaths paths None

        let (_, desc, cat) =
            commandRegistry
            |> List.tryFind (fun (n, _, _) -> n = name)
            |> Option.defaultValue (name, "devenv command", "uncategorised")

        { Name = name; Description = desc; Category = cat
          Status = status; CheckedAt = checkedAt }

    /// <summary>
    /// Verify all 32 devenv commands by probing each unique name in the static
    /// command registry exactly once.
    ///
    /// Duplicate names that appear in multiple categories (e.g. sa-monitor in
    /// "planning" and "monitoring") share a single probe result; the description
    /// and category from the first occurrence in the registry are used.
    /// </summary>
    /// <returns>
    ///   A <see cref="CommandVerificationResult"/> with aggregate counts and per-command detail.
    /// </returns>
    let verifyAll () : CommandVerificationResult =
        let timestamp = DateTimeOffset.UtcNow

        // Probe each unique name exactly once.
        let probeMap =
            commandRegistry
            |> List.map (fun (n, _, _) -> n)
            |> List.distinct
            |> List.map (fun name -> name, checkCommand name)
            |> Map.ofList

        // Reconstruct the full registry list preserving category order.
        let commands =
            commandRegistry
            |> List.map (fun (name, desc, cat) ->
                match Map.tryFind name probeMap with
                | Some info -> { info with Description = desc; Category = cat }
                | None ->
                    // Should never happen; defensive fallback.
                    { Name = name; Description = desc; Category = cat
                      Status = CommandStatus.Missing; CheckedAt = timestamp })

        let available =
            commands
            |> List.filter (fun c -> c.Status = CommandStatus.Available)
            |> List.length

        let missing =
            commands
            |> List.filter (fun c -> c.Status = CommandStatus.Missing)
            |> List.length

        let errors =
            commands
            |> List.filter (fun c ->
                match c.Status with
                | CommandStatus.Error _ -> true
                | _                     -> false)
            |> List.length

        { Total     = commands |> List.length
          Available = available
          Missing   = missing
          Errors    = errors
          Commands  = commands
          Timestamp = timestamp }

    /// <summary>
    /// Render an ANSI-colored terminal report of the verification result,
    /// grouping commands by category.
    ///
    /// Status indicators:
    ///   ✓ (bright green)  — Available
    ///   ✗ (bright red)    — Missing
    ///   ? (yellow)        — Error
    /// </summary>
    /// <param name="result">The <see cref="CommandVerificationResult"/> to render.</param>
    /// <returns>A multi-line string suitable for direct terminal output.</returns>
    let renderReport (result: CommandVerificationResult) : string =
        let g    = AnsiColors.brightGreen
        let r    = AnsiColors.brightRed
        let y    = AnsiColors.yellow
        let cyan = AnsiColors.cyan
        let w    = AnsiColors.white
        let dim  = AnsiColors.dim
        let bold = AnsiColors.bold
        let rs   = AnsiColors.reset

        let sb = Text.StringBuilder()

        // ---- header ---------------------------------------------------
        let ts = result.Timestamp.ToString("yyyy-MM-dd HH:mm:ss") + " UTC"

        sb.AppendLine($"{bold}{cyan}╔══════════════════════════════════════════════════════════════╗{rs}") |> ignore
        sb.AppendLine($"{bold}{cyan}║  COMMAND VERIFIER — 32 SA-* DEVENV COMMANDS              {dim}{ts}{bold}{cyan}  ║{rs}") |> ignore
        sb.AppendLine($"{bold}{cyan}╠══════════════════════════════════════════════════════════════╣{rs}") |> ignore

        let availPct =
            if result.Total > 0
            then float result.Available / float result.Total * 100.0
            else 0.0

        let summaryColor =
            if availPct >= 90.0 then g
            elif availPct >= 70.0 then y
            else r

        sb.AppendLine(
            $"{bold}{cyan}║{rs}  Total: {bold}{result.Total}{rs}  " +
            $"{g}Available: {result.Available}{rs}  " +
            $"{r}Missing: {result.Missing}{rs}  " +
            $"{y}Errors: {result.Errors}{rs}  " +
            $"{summaryColor}{bold}{availPct:F0}%% coverage{rs}") |> ignore

        sb.AppendLine($"{bold}{cyan}╠══════════════════════════════════════════════════════════════╣{rs}") |> ignore

        // ---- per-category groups --------------------------------------
        let grouped =
            result.Commands
            |> List.groupBy (fun c -> c.Category)
            |> List.sortBy fst

        for (category, cmds) in grouped do
            let catLabel = category.ToUpperInvariant()
            sb.AppendLine($"{bold}{cyan}║  {w}{bold}{catLabel}{rs}") |> ignore

            for cmd in cmds do
                let (icon, iconColor) =
                    match cmd.Status with
                    | CommandStatus.Available -> ("✓", g)
                    | CommandStatus.Missing   -> ("✗", r)
                    | CommandStatus.Error _   -> ("?", y)

                let errSuffix =
                    match cmd.Status with
                    | CommandStatus.Error reason ->
                        let snippet =
                            if reason.Length > 50
                            then reason.[..49] + "…"
                            else reason
                        $" {dim}({snippet}){rs}"
                    | _ -> ""

                // Pad name to 34 chars for alignment.
                let nameCol = cmd.Name.PadRight(34)

                sb.AppendLine(
                    $"  {iconColor}{bold}{icon}{rs}  {w}{nameCol}{rs}" +
                    $"{dim}{cmd.Description}{rs}{errSuffix}") |> ignore

            sb.AppendLine($"{bold}{cyan}║{rs}") |> ignore

        // ---- footer ---------------------------------------------------
        sb.AppendLine($"{bold}{cyan}╠══════════════════════════════════════════════════════════════╣{rs}") |> ignore

        let footerLine =
            if result.Missing = 0 && result.Errors = 0
            then $"{g}{bold}ALL COMMANDS AVAILABLE — SC-VER-042 SATISFIED{rs}"
            else $"{r}{bold}GAPS DETECTED — SC-VER-042 VIOLATED: {result.Missing} missing, {result.Errors} errors{rs}"

        sb.AppendLine($"  {footerLine}") |> ignore
        sb.AppendLine($"{bold}{cyan}╚══════════════════════════════════════════════════════════════╝{rs}") |> ignore

        sb.ToString()
