namespace Cepaf.Podman.Cli

open System
open System.Text.Json
open System.Text.Json.Serialization

/// Console output utilities with colored output support and JSON serialization
module Console =

    // ========================================================================
    // JSON Serialization Options
    // ========================================================================

    let jsonOptions =
        let opts = JsonSerializerOptions()
        opts.WriteIndented <- true
        opts.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
        opts.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        opts

    /// Output format for CLI responses
    [<RequireQualifiedAccess>]
    type OutputFormat =
        | Text
        | Json

    /// Parse output format from string
    let parseOutputFormat (format: string) : OutputFormat =
        match format.ToLowerInvariant() with
        | "json" -> OutputFormat.Json
        | _ -> OutputFormat.Text

    // ========================================================================
    // JSON Output Helpers
    // ========================================================================

    /// Write JSON to stdout
    let writeJson (value: obj) : unit =
        let json = JsonSerializer.Serialize(value, jsonOptions)
        System.Console.WriteLine(json)

    /// Write error as JSON to stderr
    let writeJsonError (message: string) (code: int) : unit =
        let error = {| error = message; code = code |}
        let json = JsonSerializer.Serialize(error, jsonOptions)
        System.Console.Error.WriteLine(json)

    // ========================================================================
    // ANSI Color Codes
    // ========================================================================

    [<Literal>]
    let private Reset = "\x1b[0m"

    [<Literal>]
    let private Bold = "\x1b[1m"

    [<Literal>]
    let private Dim = "\x1b[2m"

    [<Literal>]
    let private Red = "\x1b[31m"

    [<Literal>]
    let private Green = "\x1b[32m"

    [<Literal>]
    let private Yellow = "\x1b[33m"

    [<Literal>]
    let private Blue = "\x1b[34m"

    [<Literal>]
    let private Magenta = "\x1b[35m"

    [<Literal>]
    let private Cyan = "\x1b[36m"

    [<Literal>]
    let private White = "\x1b[37m"

    [<Literal>]
    let private BrightRed = "\x1b[91m"

    [<Literal>]
    let private BrightGreen = "\x1b[92m"

    [<Literal>]
    let private BrightYellow = "\x1b[93m"

    [<Literal>]
    let private BrightBlue = "\x1b[94m"

    [<Literal>]
    let private BrightCyan = "\x1b[96m"

    // ========================================================================
    // Basic Output Functions
    // ========================================================================

    /// Check if colors are supported
    let private supportsColor =
        let term = Environment.GetEnvironmentVariable("TERM")
        let noColor = Environment.GetEnvironmentVariable("NO_COLOR")
        String.IsNullOrEmpty(noColor) &&
        not (String.IsNullOrEmpty(term)) &&
        term <> "dumb"

    /// Apply color if supported
    let private colorize (color: string) (text: string) : string =
        if supportsColor then
            sprintf "%s%s%s" color text Reset
        else
            text

    /// Print with color
    let printColored (color: string) (text: string) : unit =
        Console.WriteLine(colorize color text)

    /// Print success message (green)
    let success (message: string) : unit =
        printColored BrightGreen message

    /// Print error message (red)
    let error (message: string) : unit =
        Console.Error.WriteLine(colorize BrightRed (sprintf "[ERROR] %s" message))

    /// Print warning message (yellow)
    let warning (message: string) : unit =
        printColored BrightYellow (sprintf "[WARN] %s" message)

    /// Print info message (cyan)
    let info (message: string) : unit =
        printColored BrightCyan message

    /// Print debug/dim message
    let dim (message: string) : unit =
        printColored Dim message

    /// Print header (bold blue)
    let header (title: string) : unit =
        printColored (Bold + BrightBlue) title
        printColored Dim (String.replicate (String.length title) "=")

    /// Print subheader
    let subheader (title: string) : unit =
        printColored (Bold + White) title

    // ========================================================================
    // Status Indicators
    // ========================================================================

    /// Print status with colored indicator
    let printStatus (status: string) (message: string) : unit =
        let indicator =
            match status.ToLowerInvariant() with
            | "running" | "healthy" | "ok" | "valid" ->
                colorize BrightGreen "[OK]"
            | "stopped" | "exited" | "created" ->
                colorize Yellow "[--]"
            | "error" | "unhealthy" | "critical" | "dead" ->
                colorize BrightRed "[!!]"
            | "warning" | "starting" ->
                colorize BrightYellow "[~~]"
            | _ ->
                colorize Dim "[??]"
        Console.WriteLine(sprintf "%s %s" indicator message)

    /// Print container status
    let printContainerStatus (status: string) : string =
        match status.ToLowerInvariant() with
        | "running" -> colorize BrightGreen "Running"
        | "exited" -> colorize Yellow "Exited"
        | "created" -> colorize Blue "Created"
        | "paused" -> colorize Magenta "Paused"
        | "dead" -> colorize BrightRed "Dead"
        | "restarting" -> colorize Cyan "Restarting"
        | s -> s

    /// Print health status
    let printHealthStatus (status: string) : string =
        match status.ToLowerInvariant() with
        | "healthy" -> colorize BrightGreen "Healthy"
        | "unhealthy" -> colorize BrightRed "Unhealthy"
        | "starting" -> colorize Yellow "Starting"
        | "none" | "nohealthcheck" -> colorize Dim "No healthcheck"
        | s -> s

    // ========================================================================
    // Table Formatting
    // ========================================================================

    /// Table column definition
    type Column = {
        Header: string
        Width: int
        Align: Alignment
    }

    and Alignment = Left | Right | Center

    /// Create a column
    let col header width = { Header = header; Width = width; Align = Left }
    let colRight header width = { Header = header; Width = width; Align = Right }
    let colCenter header width = { Header = header; Width = width; Align = Center }

    /// Pad string to width
    let private pad (align: Alignment) (width: int) (text: string) : string =
        let cleanText =
            // Remove ANSI codes for length calculation
            System.Text.RegularExpressions.Regex.Replace(text, @"\x1b\[[0-9;]*m", "")
        let actualLen = cleanText.Length
        let padding = max 0 (width - actualLen)
        match align with
        | Left -> text + String.replicate padding " "
        | Right -> String.replicate padding " " + text
        | Center ->
            let left = padding / 2
            let right = padding - left
            String.replicate left " " + text + String.replicate right " "

    /// Print table header
    let printTableHeader (columns: Column list) : unit =
        let headerLine =
            columns
            |> List.map (fun c -> pad c.Align c.Width c.Header)
            |> String.concat "  "
        printColored (Bold + White) headerLine
        let separator =
            columns
            |> List.map (fun c -> String.replicate c.Width "-")
            |> String.concat "  "
        printColored Dim separator

    /// Print table row
    let printTableRow (columns: Column list) (values: string list) : unit =
        let line =
            List.zip columns values
            |> List.map (fun (c, v) -> pad c.Align c.Width v)
            |> String.concat "  "
        Console.WriteLine(line)

    // ========================================================================
    // Progress and Spinners
    // ========================================================================

    /// Print a spinner frame
    let printSpinner (frame: int) (message: string) : unit =
        let spinnerChars = [| '|'; '/'; '-'; '\\' |]
        let char = spinnerChars.[frame % spinnerChars.Length]
        Console.Write(sprintf "\r%c %s" char message)

    /// Clear the current line
    let clearLine () : unit =
        Console.Write("\r" + String.replicate 80 " " + "\r")

    // ========================================================================
    // Size Formatting
    // ========================================================================

    /// Format bytes as human readable
    let formatBytes (bytes: int64) : string =
        let units = [| "B"; "KB"; "MB"; "GB"; "TB" |]
        let mutable size = float bytes
        let mutable unit = 0
        while size >= 1024.0 && unit < units.Length - 1 do
            size <- size / 1024.0
            unit <- unit + 1
        if unit = 0 then
            sprintf "%d B" bytes
        else
            sprintf "%.1f %s" size units.[unit]

    /// Format duration as human readable
    let formatDuration (ts: TimeSpan) : string =
        if ts.TotalDays >= 1.0 then
            sprintf "%dd %dh" (int ts.TotalDays) ts.Hours
        elif ts.TotalHours >= 1.0 then
            sprintf "%dh %dm" (int ts.TotalHours) ts.Minutes
        elif ts.TotalMinutes >= 1.0 then
            sprintf "%dm %ds" (int ts.TotalMinutes) ts.Seconds
        else
            sprintf "%ds" (int ts.TotalSeconds)

    /// Format timestamp as relative time
    let formatRelativeTime (timestamp: DateTimeOffset) : string =
        let diff = DateTimeOffset.UtcNow - timestamp
        if diff.TotalDays >= 30.0 then
            sprintf "%d months ago" (int (diff.TotalDays / 30.0))
        elif diff.TotalDays >= 1.0 then
            sprintf "%d days ago" (int diff.TotalDays)
        elif diff.TotalHours >= 1.0 then
            sprintf "%d hours ago" (int diff.TotalHours)
        elif diff.TotalMinutes >= 1.0 then
            sprintf "%d minutes ago" (int diff.TotalMinutes)
        else
            "just now"

    // ========================================================================
    // ID Formatting
    // ========================================================================

    /// Truncate ID for display
    let truncateId (id: string) : string =
        if String.length id > 12 then
            id.Substring(0, 12)
        else
            id

    /// Format container names list
    let formatNames (names: string list) : string =
        names
        |> List.map (fun n -> if n.StartsWith("/") then n.Substring(1) else n)
        |> String.concat ", "
