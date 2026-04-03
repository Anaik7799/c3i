namespace Cepaf.Observability

open System
open Serilog
open Serilog.Events
open Serilog.Sinks.SystemConsole.Themes

/// Console channel implementation for Quadplex observability.
/// Provides color-coded output with progress bar support via Serilog.
/// STAMP Compliance: SC-OBS-069 (dual logging - console component)
module ConsoleChannel =

    /// Map Quadplex LogLevel to Serilog LogEventLevel
    let private toSerilogLevel (level: LogLevel) =
        match level with
        | LogLevel.Trace -> LogEventLevel.Verbose
        | LogLevel.Debug -> LogEventLevel.Debug
        | LogLevel.Info -> LogEventLevel.Information
        | LogLevel.Warning -> LogEventLevel.Warning
        | LogLevel.Error -> LogEventLevel.Error
        | LogLevel.Critical -> LogEventLevel.Fatal
        | _ -> LogEventLevel.Information

    /// ANSI color codes for custom formatting (SC-CONSOL-003: Authoritative source)
    /// All color definitions should be added here, not in local modules
    module AnsiColors =
        // Reset and modifiers
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let dim = "\u001b[2m"
        let italic = "\u001b[3m"
        let underline = "\u001b[4m"

        // Foreground colors
        let black = "\u001b[30m"
        let red = "\u001b[31m"
        let green = "\u001b[32m"
        let yellow = "\u001b[33m"
        let blue = "\u001b[34m"
        let magenta = "\u001b[35m"
        let cyan = "\u001b[36m"
        let white = "\u001b[37m"

        // Bright foreground colors
        let brightRed = "\u001b[91m"
        let brightGreen = "\u001b[92m"
        let brightYellow = "\u001b[93m"
        let brightBlue = "\u001b[94m"
        let brightMagenta = "\u001b[95m"
        let brightCyan = "\u001b[96m"
        let brightWhite = "\u001b[97m"

        // Background colors (SC-CONSOL-003)
        let bgBlack = "\u001b[40m"
        let bgRed = "\u001b[41m"
        let bgGreen = "\u001b[42m"
        let bgYellow = "\u001b[43m"
        let bgBlue = "\u001b[44m"
        let bgMagenta = "\u001b[45m"
        let bgCyan = "\u001b[46m"
        let bgWhite = "\u001b[47m"

    /// Get color for log level
    let private getColorForLevel (level: LogLevel) =
        match level with
        | LogLevel.Trace -> AnsiColors.dim + AnsiColors.white
        | LogLevel.Debug -> AnsiColors.cyan
        | LogLevel.Info -> AnsiColors.green
        | LogLevel.Warning -> AnsiColors.yellow
        | LogLevel.Error -> AnsiColors.red
        | LogLevel.Critical -> AnsiColors.bold + AnsiColors.brightRed
        | _ -> AnsiColors.white

    /// Get level prefix string
    let private getLevelPrefix (level: LogLevel) =
        match level with
        | LogLevel.Trace -> "TRC"
        | LogLevel.Debug -> "DBG"
        | LogLevel.Info -> "INF"
        | LogLevel.Warning -> "WRN"
        | LogLevel.Error -> "ERR"
        | LogLevel.Critical -> "CRT"
        | _ -> "???"

    /// Get category prefix with icon
    let private getCategoryIcon (category: EventCategory) =
        match category with
        | EventCategory.Protocol -> "P"
        | EventCategory.Phase -> ">"
        | EventCategory.Task -> "T"
        | EventCategory.Safety -> "!"
        | EventCategory.Container -> "C"
        | EventCategory.Performance -> "M"
        | EventCategory.Security -> "S"
        | EventCategory.Agent -> "A"
        | EventCategory.OODA -> "O"
        | EventCategory.Phics -> "H"
        | EventCategory.Database -> "D"
        | EventCategory.Network -> "N"
        | EventCategory.Build -> "B"
        | EventCategory.Test -> "X"
        | EventCategory.Verification -> "V"

    /// Render a progress bar
    let renderProgressBar (percent: int) (width: int) =
        let filled = int (float width * float percent / 100.0)
        let empty = width - filled
        let bar = String.replicate filled "=" + String.replicate empty " "
        sprintf "[%s] %3d%%" bar percent

    /// Format timestamp for console output
    let private formatTimestamp (ts: DateTimeOffset) =
        ts.ToString("HH:mm:ss.fff")

    /// Console channel state
    type ConsoleChannelState = {
        Logger: ILogger
        MinLevel: LogLevel
        ColorEnabled: bool
        ProgressBarsEnabled: bool
        LockObj: obj
    }

    /// Create a new console channel
    let create (config: QuadplexConfig) : ConsoleChannelState =
        let minSerilogLevel = toSerilogLevel config.ConsoleMinLevel

        let loggerConfig =
            LoggerConfiguration()
                .MinimumLevel.Is(minSerilogLevel)

        let logger =
            if config.ConsoleColorEnabled then
                loggerConfig
                    .WriteTo.Console(
                        theme = AnsiConsoleTheme.Code,
                        outputTemplate = "[{Timestamp:HH:mm:ss.fff}] [{Level:u3}] {Message:lj}{NewLine}{Exception}"
                    )
                    .CreateLogger()
            else
                loggerConfig
                    .WriteTo.Console(
                        outputTemplate = "[{Timestamp:HH:mm:ss.fff}] [{Level:u3}] {Message:lj}{NewLine}{Exception}"
                    )
                    .CreateLogger()

        {
            Logger = logger
            MinLevel = config.ConsoleMinLevel
            ColorEnabled = config.ConsoleColorEnabled
            ProgressBarsEnabled = config.ConsoleProgressBars
            LockObj = obj()
        }

    /// Check if level is enabled
    let isEnabled (state: ConsoleChannelState) (level: LogLevel) =
        int level >= int state.MinLevel

    /// Format event message with optional coloring
    let private formatMessage (state: ConsoleChannelState) (event: QuadplexEvent) =
        let categoryIcon = getCategoryIcon event.Category
        let baseMessage = sprintf "[%s] %s" categoryIcon event.Message

        // Add progress bar for task updates
        match event.Payload with
        | TelemetryPayload.TaskUpdate task ->
            match task.Status with
            | TaskStatus.InProgress percent ->
                if state.ProgressBarsEnabled then
                    let bar = renderProgressBar percent 20
                    sprintf "%s %s" baseMessage bar
                else
                    sprintf "%s (%d%%)" baseMessage percent
            | _ -> baseMessage
        | _ -> baseMessage

    /// Write event to console using custom formatting for better control
    let writeCustom (state: ConsoleChannelState) (event: QuadplexEvent) =
        if isEnabled state event.Level then
            lock state.LockObj (fun () ->
                let timestamp = formatTimestamp event.Timestamp
                let levelPrefix = getLevelPrefix event.Level
                let message = formatMessage state event

                if state.ColorEnabled then
                    let color = getColorForLevel event.Level
                    let line = sprintf "%s[%s] [%s] %s%s" color timestamp levelPrefix message AnsiColors.reset
                    Console.WriteLine(line)
                else
                    let line = sprintf "[%s] [%s] %s" timestamp levelPrefix message
                    Console.WriteLine(line)

                // Print exception if present
                match event.Exception with
                | Some ex ->
                    if state.ColorEnabled then
                        Console.WriteLine(sprintf "%s%s%s" AnsiColors.red (ex.ToString()) AnsiColors.reset)
                    else
                        Console.WriteLine(ex.ToString())
                | None -> ()
            )

    /// Write event to console via Serilog
    let writeSerilog (state: ConsoleChannelState) (event: QuadplexEvent) =
        if isEnabled state event.Level then
            let serilogLevel = toSerilogLevel event.Level
            let categoryIcon = getCategoryIcon event.Category
            let message = sprintf "[%s] %s" categoryIcon event.Message

            match event.Exception with
            | Some ex ->
                state.Logger.Write(serilogLevel, ex, message)
            | None ->
                state.Logger.Write(serilogLevel, message)

    /// Write event (uses custom formatting for better progress bar support)
    let write (state: ConsoleChannelState) (event: QuadplexEvent) =
        writeCustom state event

    /// Flush console output
    let flush (_state: ConsoleChannelState) =
        Console.Out.Flush()

    /// Dispose resources
    let dispose (state: ConsoleChannelState) =
        match state.Logger with
        | :? IDisposable as d -> d.Dispose()
        | _ -> ()

/// Console channel as ILogChannel implementation
type ConsoleLogChannel(config: QuadplexConfig) =
    let state = ConsoleChannel.create config

    interface ILogChannel with
        member _.Write(event) = ConsoleChannel.write state event
        member _.Flush() = ConsoleChannel.flush state
        member _.IsEnabled(level) = ConsoleChannel.isEnabled state level

    interface IDisposable with
        member _.Dispose() = ConsoleChannel.dispose state
