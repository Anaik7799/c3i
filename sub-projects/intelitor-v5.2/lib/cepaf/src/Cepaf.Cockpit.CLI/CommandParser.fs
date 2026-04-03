// =============================================================================
// CommandParser.fs - CLI Argument Parsing for Cockpit
// =============================================================================
// STAMP: SC-CLI-001, SC-COCKPIT-001
// AOR: AOR-CLI-001
// Criticality: Level 4 (REQUIRED) - Command-Line Interface
//
// Provides command-line argument parsing for the Cockpit CLI, supporting:
// - Interactive TUI mode (monitor)
// - Quick status checks (status, health)
// - Verbosity and output format options
// =============================================================================

namespace Cepaf.Cockpit.CLI

open System

/// Verbosity levels for output control
type Verbosity =
    | Minimal   // Only critical information
    | Standard  // Normal operational output
    | Verbose   // Detailed output with metrics
    | Debug     // Full debug information

/// Output format
type OutputFormat =
    | Human     // Human-readable text
    | Json      // Machine-readable JSON

/// Parsed CLI options
type CliOptions = {
    Command: string
    SubCommand: string option
    Verbosity: Verbosity
    OutputFormat: OutputFormat
    Args: string list
    ShowHelp: bool
    ShowVersion: bool
}

module CommandParser =

    /// Default options
    let defaultOptions = {
        Command = "monitor"
        SubCommand = None
        Verbosity = Standard
        OutputFormat = Human
        Args = []
        ShowHelp = false
        ShowVersion = false
    }

    /// Parse verbosity from string
    let parseVerbosity (s: string) =
        match s.ToLowerInvariant() with
        | "minimal" | "min" | "q" | "quiet" -> Minimal
        | "standard" | "std" | "normal" -> Standard
        | "verbose" | "v" -> Verbose
        | "debug" | "d" -> Debug
        | _ -> Standard

    /// Parse command-line arguments
    let parse (argv: string array) : CliOptions =
        let rec parseArgs opts args =
            match args with
            | [] -> opts

            // Help flags
            | "-h" :: rest | "--help" :: rest | "help" :: rest ->
                parseArgs { opts with ShowHelp = true } rest

            // Version flags
            | "-V" :: rest | "--version" :: rest | "version" :: rest ->
                parseArgs { opts with ShowVersion = true } rest

            // Verbosity flags
            | "-v" :: rest | "--verbose" :: rest ->
                parseArgs { opts with Verbosity = Verbose } rest
            | "-q" :: rest | "--quiet" :: rest ->
                parseArgs { opts with Verbosity = Minimal } rest
            | "-d" :: rest | "--debug" :: rest ->
                parseArgs { opts with Verbosity = Debug } rest
            | "--verbosity" :: level :: rest ->
                parseArgs { opts with Verbosity = parseVerbosity level } rest

            // Output format flags
            | "--json" :: rest ->
                parseArgs { opts with OutputFormat = Json } rest
            | "--human" :: rest ->
                parseArgs { opts with OutputFormat = Human } rest

            // Commands
            | "monitor" :: rest ->
                parseArgs { opts with Command = "monitor"; Args = rest } []
            | "tui" :: rest ->
                parseArgs { opts with Command = "monitor"; Args = rest } []
            | "status" :: rest ->
                parseArgs { opts with Command = "status"; Args = rest } []
            | "health" :: rest ->
                parseArgs { opts with Command = "health"; Args = rest } []
            | "nodes" :: rest ->
                parseArgs { opts with Command = "nodes"; Args = rest } []
            | "alarms" :: rest ->
                parseArgs { opts with Command = "alarms"; Args = rest } []
            | "zenoh" :: rest ->
                parseArgs { opts with Command = "zenoh"; Args = rest } []
            | "verify" :: rest ->
                parseArgs { opts with Command = "verify"; Args = rest } []

            // Unknown argument - treat as remaining args
            | arg :: rest ->
                if opts.Command = "monitor" && not (arg.StartsWith("-")) then
                    parseArgs { opts with Command = arg } rest
                else
                    parseArgs { opts with Args = opts.Args @ [arg] } rest

        parseArgs defaultOptions (Array.toList argv)
