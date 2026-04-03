namespace Cepaf.Dashboard

open System
open System.Collections.Concurrent
open Cepaf.Zenoh

/// Real-time Fractal Log Viewer Component for CEPAF Cockpit GUI
///
/// ## Features
/// - Live log streaming via Zenoh subscription
/// - Level-based filtering (L1-L5)
/// - Domain filtering (Alarms, Devices, etc.)
/// - Search and highlight
/// - Export functionality
///
/// ## STAMP Constraints
/// - SC-GUI-LOG-001: Max 10,000 visible entries
/// - SC-GUI-LOG-002: Auto-scroll with user override
/// - SC-GUI-LOG-003: Color coding by level
module FractalLogView =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Fractal log level
    type FractalLevel =
        | L1  // Atomic/Debug
        | L2  // Component
        | L3  // Transaction
        | L4  // System
        | L5  // Cognitive

    /// Parsed fractal log entry
    type FractalLogEntry = {
        Id: string
        Timestamp: DateTimeOffset
        Level: FractalLevel
        Domain: string
        Module: string option
        Function: string option
        Message: string
        Metadata: Map<string, obj>
        TraceId: string option
        SpanId: string option
        HlcTimestamp: int64 option
    }

    /// View configuration
    type ViewConfig = {
        MaxEntries: int
        AutoScroll: bool
        ShowTimestamp: bool
        ShowLevel: bool
        ShowDomain: bool
        ShowMetadata: bool
    }

    /// Filter configuration
    type FilterConfig = {
        Levels: Set<FractalLevel>
        Domains: Set<string>
        SearchPattern: string option
        TimeRange: (DateTimeOffset * DateTimeOffset) option
    }

    /// View statistics
    type ViewStats = {
        TotalReceived: int64
        TotalDisplayed: int
        TotalFiltered: int64
        BufferSize: int
        LastUpdateAt: DateTimeOffset option
    }

    /// Export format
    type ExportFormat =
        | JSON
        | CSV
        | PlainText

    // ========================================================================
    // CONSTANTS
    // ========================================================================

    /// Level color codes (ANSI)
    let private levelColors = Map.ofList [
        L1, "\x1b[90m"   // Gray - Debug
        L2, "\x1b[36m"   // Cyan - Component
        L3, "\x1b[32m"   // Green - Transaction
        L4, "\x1b[33m"   // Yellow - System
        L5, "\x1b[31m"   // Red - Cognitive
    ]

    let private resetColor = "\x1b[0m"

    // ========================================================================
    // STATE
    // ========================================================================

    let private maxEntries = 10_000
    let private logBuffer = ConcurrentQueue<FractalLogEntry>()
    let mutable private levelFilter = Set.ofList [L1; L2; L3; L4; L5]
    let mutable private domainFilter = Set.empty<string>
    let mutable private searchPattern = ""
    let mutable private autoScroll = true
    let mutable private isPaused = false
    let mutable private subscriptionId: string option = None

    let mutable private stats = {
        TotalReceived = 0L
        TotalDisplayed = 0
        TotalFiltered = 0L
        BufferSize = 0
        LastUpdateAt = None
    }

    // ========================================================================
    // PARSING
    // ========================================================================

    /// Parse level from string
    let private parseLevel (s: string) =
        match s.ToLowerInvariant() with
        | "l1" | "debug" | "atomic" -> L1
        | "l2" | "component" -> L2
        | "l3" | "transaction" | "info" -> L3
        | "l4" | "system" | "warning" -> L4
        | "l5" | "cognitive" | "critical" | "error" -> L5
        | _ -> L3

    /// Try to get a property from JsonElement
    let private tryGetString (elem: System.Text.Json.JsonElement) (name: string) =
        let mutable prop = Unchecked.defaultof<System.Text.Json.JsonElement>
        if elem.TryGetProperty(name, &prop) then
            Some (prop.GetString())
        else
            None

    let private tryGetInt64 (elem: System.Text.Json.JsonElement) (name: string) =
        let mutable prop = Unchecked.defaultof<System.Text.Json.JsonElement>
        if elem.TryGetProperty(name, &prop) then
            Some (prop.GetInt64())
        else
            None

    /// Parse Zenoh message to FractalLogEntry
    let private parseMessage (msg: ZenohSession.ZenohMessage) : FractalLogEntry option =
        try
            let json = System.Text.Encoding.UTF8.GetString(msg.Payload)
            let doc = System.Text.Json.JsonDocument.Parse(json)
            let root = doc.RootElement

            let getId () =
                tryGetString root "id"
                |> Option.defaultWith (fun () -> Guid.NewGuid().ToString("N").[..7])

            let getTimestamp () =
                tryGetString root "timestamp"
                |> Option.map DateTimeOffset.Parse
                |> Option.defaultValue DateTimeOffset.UtcNow

            let getLevel () =
                tryGetString root "level"
                |> Option.map parseLevel
                |> Option.defaultWith (fun () ->
                    // Extract from key path
                    let parts = msg.Key.Split('/')
                    if parts.Length >= 3 then parseLevel parts.[2] else L3)

            let getDomain () =
                tryGetString root "domain"
                |> Option.defaultWith (fun () ->
                    // Extract from key path
                    let parts = msg.Key.Split('/')
                    if parts.Length >= 4 then parts.[3] else "general")

            let getMessage () =
                tryGetString root "message"
                |> Option.defaultValue json

            Some {
                Id = getId ()
                Timestamp = getTimestamp ()
                Level = getLevel ()
                Domain = getDomain ()
                Module = None
                Function = None
                Message = getMessage ()
                Metadata = Map.empty
                TraceId = tryGetString root "traceId"
                SpanId = tryGetString root "spanId"
                HlcTimestamp = tryGetInt64 root "hlc_timestamp"
            }
        with _ ->
            None

    // ========================================================================
    // FILTERING
    // ========================================================================

    /// Check if entry passes filters
    let private passesFilter (entry: FractalLogEntry) =
        let levelOk = levelFilter.Contains(entry.Level)
        let domainOk = domainFilter.IsEmpty || domainFilter.Contains(entry.Domain)
        let searchOk =
            String.IsNullOrEmpty(searchPattern) ||
            entry.Message.Contains(searchPattern, StringComparison.OrdinalIgnoreCase) ||
            entry.Domain.Contains(searchPattern, StringComparison.OrdinalIgnoreCase)

        levelOk && domainOk && searchOk

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    /// Initialize the view and start Zenoh subscription
    let initialize () =
        // Subscribe to all fractal logs
        match ZenohSession.subscribe "indrajaal/fractal/**" (fun msg ->
            if not isPaused then
                match parseMessage msg with
                | Some entry when passesFilter entry ->
                    stats <- { stats with TotalReceived = stats.TotalReceived + 1L }

                    logBuffer.Enqueue(entry)

                    // Trim buffer if exceeded (SC-GUI-LOG-001)
                    while logBuffer.Count > maxEntries do
                        logBuffer.TryDequeue() |> ignore

                    stats <- {
                        stats with
                            TotalDisplayed = logBuffer.Count
                            BufferSize = logBuffer.Count
                            LastUpdateAt = Some DateTimeOffset.UtcNow
                    }
                | Some _ ->
                    stats <- { stats with TotalFiltered = stats.TotalFiltered + 1L }
                | None -> ()
        ) with
        | Ok id ->
            subscriptionId <- Some id
            printfn "[FractalLogView] Initialized, subscribed to indrajaal/fractal/**"
        | Error err ->
            printfn "[FractalLogView] ERROR: Failed to subscribe: %s" err

    /// Get visible entries (for rendering)
    let getVisibleEntries (offset: int) (limit: int) =
        logBuffer
        |> Seq.skip offset
        |> Seq.truncate limit
        |> Seq.toArray

    /// Get all entries
    let getAllEntries () =
        logBuffer |> Seq.toArray

    /// Set level filter
    let setLevelFilter (levels: FractalLevel seq) =
        levelFilter <- Set.ofSeq levels

    /// Set domain filter
    let setDomainFilter (domains: string seq) =
        domainFilter <- Set.ofSeq domains

    /// Set search pattern
    let setSearchPattern (pattern: string) =
        searchPattern <- pattern

    /// Toggle pause state
    let togglePause () =
        isPaused <- not isPaused
        isPaused

    /// Get pause state
    let getPaused () = isPaused

    /// Clear all entries
    let clear () =
        while not (logBuffer.IsEmpty) do
            logBuffer.TryDequeue() |> ignore
        stats <- { stats with TotalDisplayed = 0; BufferSize = 0 }

    /// Get view statistics
    let getStats () = stats

    /// Export logs to file
    let exportAsync (format: ExportFormat) (path: string) = async {
        let entries = logBuffer |> Seq.toArray

        let content =
            match format with
            | JSON ->
                System.Text.Json.JsonSerializer.Serialize(entries, System.Text.Json.JsonSerializerOptions(WriteIndented = true))
            | CSV ->
                let header = "Timestamp,Level,Domain,Message,TraceId"
                let rows =
                    entries
                    |> Array.map (fun e ->
                        sprintf "\"%s\",\"%A\",\"%s\",\"%s\",\"%s\""
                            (e.Timestamp.ToString("o"))
                            e.Level
                            e.Domain
                            (e.Message.Replace("\"", "\"\""))
                            (e.TraceId |> Option.defaultValue "")
                    )
                String.Join("\n", Array.append [|header|] rows)
            | PlainText ->
                entries
                |> Array.map (fun e ->
                    sprintf "[%s] %A | %s | %s"
                        (e.Timestamp.ToString("HH:mm:ss.fff"))
                        e.Level
                        e.Domain
                        e.Message
                )
                |> String.concat "\n"

        do! System.IO.File.WriteAllTextAsync(path, content) |> Async.AwaitTask
        return Ok path
    }

    /// Render single entry for console display
    let renderEntry (entry: FractalLogEntry) =
        let color = levelColors |> Map.tryFind entry.Level |> Option.defaultValue ""
        sprintf "%s[%s] %s%A%s | %s | %s"
            color
            (entry.Timestamp.ToString("HH:mm:ss.fff"))
            color
            entry.Level
            resetColor
            entry.Domain
            entry.Message

    /// Render entries for console display
    let renderEntries (entries: FractalLogEntry seq) =
        entries |> Seq.map renderEntry |> String.concat "\n"

    /// Close the view
    let close () =
        match subscriptionId with
        | Some id ->
            ZenohSession.unsubscribe id |> ignore
            subscriptionId <- None
        | None -> ()
        printfn "[FractalLogView] Closed"
