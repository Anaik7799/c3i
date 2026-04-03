namespace Cepaf.Podman.Cli

open System
open System.CommandLine
open System.CommandLine.Invocation
open System.Collections.Generic

/// Main CLI entry point for CepafPort integration
/// Provides commands matching the Elixir CepafPort protocol
module Program =

    // ========================================================================
    // Common Options
    // ========================================================================

    /// Socket path option (global)
    let socketOption =
        let opt = Option<string>(
            aliases = [| "-s"; "--socket" |],
            description = "Path to Podman socket (default: auto-detect)"
        )
        opt.IsRequired <- false
        opt

    /// Format option for JSON output
    let formatOption =
        let opt = Option<string>(
            aliases = [| "-f"; "--format" |],
            description = "Output format: text or json (default: text)"
        )
        opt.SetDefaultValue("text")
        opt

    /// All items option
    let allOption =
        let opt = Option<bool>(
            aliases = [| "-a"; "--all" |],
            description = "Show all items (including stopped/unused)"
        )
        opt.SetDefaultValue(false)
        opt

    /// Verbose output option
    let verboseOption =
        let opt = Option<bool>(
            aliases = [| "-v"; "--verbose" |],
            description = "Enable verbose output"
        )
        opt.SetDefaultValue(false)
        opt

    /// Quiet output option
    let quietOption =
        let opt = Option<bool>(
            aliases = [| "-q"; "--quiet" |],
            description = "Only display IDs"
        )
        opt.SetDefaultValue(false)
        opt

    /// Filter option (can be used multiple times)
    let filterOption =
        let opt = Option<string[]>(
            aliases = [| "--filter" |],
            description = "Filter by label (e.g., label=indrajaal=true)"
        )
        opt.AllowMultipleArgumentsPerToken <- true
        opt

    /// Tail option for logs
    let tailOption =
        let opt = Option<int>(
            aliases = [| "--tail" |],
            description = "Number of lines to show from the end of logs"
        )
        opt

    /// Timestamps option for logs
    let timestampsOption =
        let opt = Option<bool>(
            aliases = [| "--timestamps" |],
            description = "Show timestamps in logs"
        )
        opt.SetDefaultValue(false)
        opt

    /// No stream option for stats
    let noStreamOption =
        let opt = Option<bool>(
            aliases = [| "--no-stream" |],
            description = "Disable streaming (one-shot output)"
        )
        opt.SetDefaultValue(false)
        opt

    // ========================================================================
    // Containers Commands
    // ========================================================================

    /// containers list command
    let createContainersListCommand () =
        let cmd = Command("list", "List containers")
        cmd.AddAlias("ls")
        cmd.AddAlias("ps")

        cmd.AddOption(socketOption)
        cmd.AddOption(formatOption)
        cmd.AddOption(allOption)
        cmd.AddOption(filterOption)

        cmd.SetHandler(
            Action<string, string, bool, string[]>(fun socket format all filters ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let outputFormat = Console.parseOutputFormat format

                // Extract labels from filter options
                let labels =
                    if isNull filters then []
                    else
                        filters
                        |> Array.choose (fun f ->
                            if f.StartsWith("label=") then Some (f.Substring(6))
                            else None)
                        |> Array.toList

                let exitCode = Commands.containersList socketOpt all labels outputFormat
                Environment.ExitCode <- exitCode
            ),
            socketOption, formatOption, allOption, filterOption
        )

        cmd

    /// containers inspect command
    let createContainersInspectCommand () =
        let cmd = Command("inspect", "Display detailed information on a container")

        let containerArg = Argument<string>(
            name = "container",
            description = "Container ID or name"
        )
        containerArg.Arity <- ArgumentArity.ExactlyOne

        cmd.AddArgument(containerArg)
        cmd.AddOption(socketOption)
        cmd.AddOption(formatOption)

        cmd.SetHandler(
            Action<string, string, string>(fun container socket format ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let outputFormat = Console.parseOutputFormat format
                let exitCode = Commands.containersInspect socketOpt container outputFormat
                Environment.ExitCode <- exitCode
            ),
            containerArg, socketOption, formatOption
        )

        cmd

    /// containers logs command
    let createContainersLogsCommand () =
        let cmd = Command("logs", "Fetch the logs of a container")

        let containerArg = Argument<string>(
            name = "container",
            description = "Container ID or name"
        )
        containerArg.Arity <- ArgumentArity.ExactlyOne

        cmd.AddArgument(containerArg)
        cmd.AddOption(socketOption)
        cmd.AddOption(tailOption)
        cmd.AddOption(timestampsOption)

        cmd.SetHandler(
            Action<string, string, int, bool>(fun container socket tail timestamps ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let tailOpt = if tail > 0 then Some tail else None
                let exitCode = Commands.containersLogs socketOpt container tailOpt timestamps
                Environment.ExitCode <- exitCode
            ),
            containerArg, socketOption, tailOption, timestampsOption
        )

        cmd

    /// containers stats command
    let createContainersStatsCommand () =
        let cmd = Command("stats", "Display a live stream of container resource usage statistics")

        let containerArg = Argument<string>(
            name = "container",
            description = "Container ID or name"
        )
        containerArg.Arity <- ArgumentArity.ExactlyOne

        cmd.AddArgument(containerArg)
        cmd.AddOption(socketOption)
        cmd.AddOption(formatOption)
        cmd.AddOption(noStreamOption)

        cmd.SetHandler(
            Action<string, string, string, bool>(fun container socket format _noStream ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let outputFormat = Console.parseOutputFormat format
                // noStream is always true for CLI - we don't support streaming in port mode
                let exitCode = Commands.containersStats socketOpt container outputFormat
                Environment.ExitCode <- exitCode
            ),
            containerArg, socketOption, formatOption, noStreamOption
        )

        cmd

    /// containers command (parent)
    let createContainersCommand () =
        let cmd = Command("containers", "Manage containers")
        cmd.AddAlias("container")

        cmd.AddCommand(createContainersListCommand())
        cmd.AddCommand(createContainersInspectCommand())
        cmd.AddCommand(createContainersLogsCommand())
        cmd.AddCommand(createContainersStatsCommand())

        cmd

    // ========================================================================
    // Health Commands
    // ========================================================================

    /// health summary command
    let createHealthSummaryCommand () =
        let cmd = Command("summary", "Display health summary of all containers")

        cmd.AddOption(socketOption)
        cmd.AddOption(formatOption)

        cmd.SetHandler(
            Action<string, string>(fun socket format ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let outputFormat = Console.parseOutputFormat format
                let exitCode = Commands.healthSummary socketOpt outputFormat
                Environment.ExitCode <- exitCode
            ),
            socketOption, formatOption
        )

        cmd

    /// health check command
    let createHealthCheckCommand () =
        let cmd = Command("check", "Check health of a specific container")

        let containerArg = Argument<string>(
            name = "container",
            description = "Container ID or name"
        )
        containerArg.Arity <- ArgumentArity.ExactlyOne

        cmd.AddArgument(containerArg)
        cmd.AddOption(socketOption)
        cmd.AddOption(formatOption)

        cmd.SetHandler(
            Action<string, string, string>(fun container socket format ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let outputFormat = Console.parseOutputFormat format
                let exitCode = Commands.healthCheck socketOpt container outputFormat
                Environment.ExitCode <- exitCode
            ),
            containerArg, socketOption, formatOption
        )

        cmd

    /// health command (parent)
    let createHealthCommand () =
        let cmd = Command("health", "Container health operations")
        cmd.AddAlias("hc")

        cmd.AddCommand(createHealthSummaryCommand())
        cmd.AddCommand(createHealthCheckCommand())

        cmd

    // ========================================================================
    // System Commands
    // ========================================================================

    /// system info command
    let createSystemInfoCommand () =
        let cmd = Command("info", "Display system information")

        cmd.AddOption(socketOption)
        cmd.AddOption(formatOption)

        cmd.SetHandler(
            Action<string, string>(fun socket format ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let outputFormat = Console.parseOutputFormat format
                let exitCode = Commands.systemInfo socketOpt outputFormat
                Environment.ExitCode <- exitCode
            ),
            socketOption, formatOption
        )

        cmd

    /// system ping command
    let createSystemPingCommand () =
        let cmd = Command("ping", "Ping the Podman service")

        cmd.AddOption(socketOption)

        cmd.SetHandler(
            Action<string>(fun socket ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let exitCode = Commands.systemPing socketOpt
                Environment.ExitCode <- exitCode
            ),
            socketOption
        )

        cmd

    /// system command (parent)
    let createSystemCommand () =
        let cmd = Command("system", "Manage Podman")

        cmd.AddCommand(createSystemInfoCommand())
        cmd.AddCommand(createSystemPingCommand())

        cmd

    // ========================================================================
    // Legacy Commands (for backward compatibility)
    // ========================================================================

    let createLegacyListCommand () =
        let cmd = Command("list", "List containers (legacy)")
        cmd.AddAlias("ls")
        cmd.AddAlias("ps")

        cmd.AddOption(socketOption)
        cmd.AddOption(allOption)
        cmd.AddOption(quietOption)

        cmd.SetHandler(
            Action<string, bool, bool>(fun socket all quiet ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let exitCode = Commands.listContainers socketOpt all quiet
                Environment.ExitCode <- exitCode
            ),
            socketOption, allOption, quietOption
        )

        cmd

    let createLegacyImagesCommand () =
        let cmd = Command("images", "List images")
        cmd.AddAlias("image")
        cmd.AddAlias("img")

        cmd.AddOption(socketOption)
        cmd.AddOption(allOption)
        cmd.AddOption(quietOption)

        cmd.SetHandler(
            Action<string, bool, bool>(fun socket all quiet ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let exitCode = Commands.listImages socketOpt all quiet
                Environment.ExitCode <- exitCode
            ),
            socketOption, allOption, quietOption
        )

        cmd

    let createLegacyValidateCommand () =
        let cmd = Command("validate", "Validate image against STAMP constraints")
        cmd.AddAlias("check")

        let imageArg = Argument<string>(
            name = "image",
            description = "Image reference to validate (e.g., localhost/myimage:v1)"
        )
        imageArg.Arity <- ArgumentArity.ExactlyOne

        cmd.AddArgument(imageArg)
        cmd.AddOption(socketOption)
        cmd.AddOption(verboseOption)

        cmd.SetHandler(
            Action<string, string, bool>(fun image socket verbose ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let exitCode = Commands.validateImage socketOpt image verbose
                Environment.ExitCode <- exitCode
            ),
            imageArg, socketOption, verboseOption
        )

        cmd

    let createLegacyInfoCommand () =
        let cmd = Command("info", "Display system information (legacy)")
        cmd.AddAlias("version")

        cmd.AddOption(socketOption)
        cmd.AddOption(verboseOption)

        cmd.SetHandler(
            Action<string, bool>(fun socket _verbose ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let exitCode = Commands.systemInfo socketOpt Console.OutputFormat.Text
                Environment.ExitCode <- exitCode
            ),
            socketOption, verboseOption
        )

        cmd

    let createLegacyPingCommand () =
        let cmd = Command("ping", "Test connection to Podman daemon (legacy)")

        cmd.AddOption(socketOption)

        cmd.SetHandler(
            Action<string>(fun socket ->
                let socketOpt = if String.IsNullOrEmpty(socket) then None else Some socket
                let exitCode = Commands.ping socketOpt
                Environment.ExitCode <- exitCode
            ),
            socketOption
        )

        cmd

    // ========================================================================
    // Root Command
    // ========================================================================

    let createRootCommand () =
        let rootCommand = RootCommand(
            description = "Cepaf Podman CLI - Container management with STAMP safety constraints\n\nCommands matching CepafPort protocol:\n  containers list/inspect/logs/stats\n  health summary/check\n  system info/ping"
        )

        // Primary commands (matching CepafPort protocol)
        rootCommand.AddCommand(createContainersCommand())
        rootCommand.AddCommand(createHealthCommand())
        rootCommand.AddCommand(createSystemCommand())

        // Legacy commands for backward compatibility and interactive use
        rootCommand.AddCommand(createLegacyListCommand())
        rootCommand.AddCommand(createLegacyImagesCommand())
        rootCommand.AddCommand(createLegacyValidateCommand())
        rootCommand.AddCommand(createLegacyInfoCommand())
        rootCommand.AddCommand(createLegacyPingCommand())

        rootCommand

    // ========================================================================
    // Entry Point
    // ========================================================================

    [<EntryPoint>]
    let main args =
        let rootCommand = createRootCommand()

        // Show banner on help or no args (only for interactive use)
        let isJsonMode = args |> Array.exists (fun a -> a = "--format" || a = "-f")
        if not isJsonMode && (args.Length = 0 || args |> Array.exists (fun a -> a = "-h" || a = "--help")) then
            Console.header "Cepaf Podman CLI v1.0.0"
            Console.dim "Container management with STAMP safety constraints"
            Console.WriteLine("")

        rootCommand.Invoke(args)
