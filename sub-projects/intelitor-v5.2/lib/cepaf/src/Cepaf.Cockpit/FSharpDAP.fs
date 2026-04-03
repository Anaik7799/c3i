namespace Cepaf.Cockpit

open System
open System.Text.Json

// =============================================================================
// F# DEBUG ADAPTER PROTOCOL (DAP) — GRPC Service Layer
// =============================================================================
// WHAT: Debug Adapter Protocol server for F# debugging sessions (L3 domain)
// WHY:  Enables IDE debugger integration (VS Code, Rider) for Cepaf.Cockpit
// CONSTRAINTS: SC-CLI-001 (CLI interface), SC-DEBUG-001 (debug telemetry)
//
// Protocol reference: https://microsoft.github.io/debug-adapter-protocol/
// All handlers return protocol-correct stub responses (not wired to real debugger)
// =============================================================================

/// <summary>
/// F# Debug Adapter Protocol implementation.
/// Provides DAP wire-protocol types and session state management.
/// SC-CLI-001: CLI interface compliance
/// SC-DEBUG-001: Debug telemetry integration
/// </summary>
module FSharpDAP =

    // =========================================================================
    // DAP COMMANDS — exhaustive DU per spec §5.3
    // =========================================================================

    /// All supported DAP request commands.
    [<RequireQualifiedAccess>]
    type DapCommand =
        | Initialize
        | Launch
        | Attach
        | SetBreakpoints
        | Continue
        | StepOver
        | StepIn
        | StepOut
        | Evaluate
        | Disconnect

    // =========================================================================
    // WIRE TYPES
    // =========================================================================

    /// Incoming DAP request from IDE client.
    type DapRequest = {
        /// Sequence number (monotonically increasing, IDE-assigned)
        Seq: int
        /// The command to execute
        Command: DapCommand
        /// JSON-encoded arguments (command-specific, may be absent)
        Arguments: string option
    }

    /// Outgoing DAP response to IDE client.
    type DapResponse = {
        /// Mirrors the Seq of the originating request
        RequestSeq: int
        /// true if the command succeeded
        Success: bool
        /// Name of the command that produced this response
        Command: string
        /// JSON-encoded response body (command-specific, may be absent)
        Body: string option
        /// Human-readable error message when Success = false
        Message: string option
    }

    /// Asynchronous event pushed from adapter to client (not request-driven).
    type DapEvent = {
        /// Event type name (e.g. "stopped", "terminated", "output")
        Event: string
        /// JSON-encoded event body (event-specific, may be absent)
        Body: string option
        /// Adapter-assigned sequence number
        Seq: int
    }

    // =========================================================================
    // SESSION DOMAIN TYPES
    // =========================================================================

    /// Represents a single source breakpoint with its verification state.
    type BreakpointInfo = {
        /// Adapter-assigned breakpoint identifier
        Id: int
        /// true if the runtime confirmed the breakpoint location is valid
        Verified: bool
        /// 1-based line number in source
        Line: int
        /// Absolute path to source file
        Source: string
    }

    /// A frame in the call stack at the current suspension point.
    type StackFrame = {
        /// Adapter-assigned frame identifier (used in scopes/variables requests)
        Id: int
        /// Human-readable frame label (function name)
        Name: string
        /// Absolute path to source file
        Source: string
        /// 1-based line number
        Line: int
        /// 1-based column number
        Column: int
    }

    /// Mutable state for a single DAP debug session.
    type DapSession = {
        /// Unique session identifier (UUID)
        SessionId: string
        /// true after Initialize handshake is complete
        Initialized: bool
        /// true after Launch/Attach request completes
        Launched: bool
        /// All currently active breakpoints
        Breakpoints: BreakpointInfo list
        /// The topmost stack frame when the process is suspended, absent otherwise
        CurrentFrame: StackFrame option
    }

    // =========================================================================
    // DAP CAPABILITIES (SC-DEBUG-001)
    // Capabilities are advertised during Initialize handshake.
    // =========================================================================

    /// Capability flags returned in the InitializeResponse body.
    [<RequireQualifiedAccess>]
    module Capabilities =
        let supportsBreakpoints   = true
        let supportsEvaluate      = true
        let supportsStepOver      = true

        /// Serialize capabilities to JSON for the Initialize response body.
        let toJson () : string =
            sprintf
                """{"supportsBreakpoints":%b,"supportsEvaluateForHovers":%b,"supportsStepIn":%b}"""
                supportsBreakpoints
                supportsEvaluate
                supportsStepOver

    // =========================================================================
    // SESSION FACTORY
    // =========================================================================

    /// Initialize a fresh DAP session with defaults.
    /// Returns a DapSession ready to receive an Initialize request.
    let createSession () : DapSession =
        {
            SessionId    = Guid.NewGuid().ToString("N")
            Initialized  = false
            Launched     = false
            Breakpoints  = []
            CurrentFrame = None
        }

    // =========================================================================
    // INDIVIDUAL HANDLERS
    // All return (updated session, response) — pure, no side effects.
    // =========================================================================

    /// Handle Initialize request: advertise adapter capabilities.
    /// SC-DEBUG-001: capabilities include breakpoints, evaluate, stepOver.
    let handleInitialize (session: DapSession) : DapSession * DapResponse =
        let updated = { session with Initialized = true }
        let response = {
            RequestSeq = 0   // caller will set from DapRequest.Seq
            Success    = true
            Command    = "initialize"
            Body       = Some (Capabilities.toJson ())
            Message    = None
        }
        updated, response

    /// Handle Launch request: mark session as launched.
    /// Args: JSON string with "program" and optional "args" fields.
    let handleLaunch (session: DapSession) (args: string option) : DapSession * DapResponse =
        let updated = { session with Launched = true }
        let response = {
            RequestSeq = 0
            Success    = true
            Command    = "launch"
            Body       = None
            Message    = None
        }
        updated, response

    /// Handle SetBreakpoints request: register breakpoints for a source file.
    /// Args: JSON string with "source" and "breakpoints" array fields.
    let handleSetBreakpoints (session: DapSession) (args: string option) : DapSession * DapResponse =
        // Parse source path and line numbers from args (stub: accept everything)
        let newBreakpoints =
            match args with
            | None -> []
            | Some json ->
                // Minimal extraction: look for "line" values in the JSON payload.
                // A full implementation would use a proper JSON deserializer.
                try
                    use doc = JsonDocument.Parse(json)
                    let root = doc.RootElement
                    let sourcePath =
                        if root.TryGetProperty("source", ref Unchecked.defaultof<_>) then
                            let src = root.GetProperty("source")
                            if src.TryGetProperty("path", ref Unchecked.defaultof<_>) then
                                src.GetProperty("path").GetString()
                            else "<unknown>"
                        else "<unknown>"
                    if root.TryGetProperty("breakpoints", ref Unchecked.defaultof<_>) then
                        root.GetProperty("breakpoints").EnumerateArray()
                        |> Seq.mapi (fun idx bp ->
                            let line =
                                if bp.TryGetProperty("line", ref Unchecked.defaultof<_>) then
                                    bp.GetProperty("line").GetInt32()
                                else 1
                            { Id       = session.Breakpoints.Length + idx + 1
                              Verified = true
                              Line     = line
                              Source   = sourcePath })
                        |> Seq.toList
                    else []
                with _ -> []

        let allBreakpoints = session.Breakpoints @ newBreakpoints

        // Build response body: array of verified breakpoint objects
        let bpJson =
            newBreakpoints
            |> List.map (fun bp ->
                sprintf """{"id":%d,"verified":%b,"line":%d}""" bp.Id bp.Verified bp.Line)
            |> String.concat ","
            |> sprintf """{"breakpoints":[%s]}"""

        let updated = { session with Breakpoints = allBreakpoints }
        let response = {
            RequestSeq = 0
            Success    = true
            Command    = "setBreakpoints"
            Body       = Some bpJson
            Message    = None
        }
        updated, response

    /// Handle Evaluate request: evaluate an expression in the current context.
    /// Returns a stub result — not wired to a real F# REPL.
    let handleEvaluate (session: DapSession) (expr: string) : DapSession * DapResponse =
        let resultBody =
            sprintf """{"result":"<stub: %s>","type":"string","variablesReference":0}"""
                (expr.Replace("\"", "\\\""))
        let response = {
            RequestSeq = 0
            Success    = true
            Command    = "evaluate"
            Body       = Some resultBody
            Message    = None
        }
        session, response    // evaluate does not change session state

    // =========================================================================
    // DISPATCH — route DapRequest to the correct handler
    // =========================================================================

    /// Dispatch a DapRequest to the appropriate handler.
    /// Returns (updated session, response) with RequestSeq populated.
    let handleRequest (session: DapSession) (request: DapRequest) : DapSession * DapResponse =
        let (updatedSession, rawResponse) =
            match request.Command with
            | DapCommand.Initialize ->
                handleInitialize session

            | DapCommand.Launch ->
                handleLaunch session request.Arguments

            | DapCommand.Attach ->
                // Attach is handled identically to Launch for stub purposes
                handleLaunch session request.Arguments

            | DapCommand.SetBreakpoints ->
                handleSetBreakpoints session request.Arguments

            | DapCommand.Continue ->
                let response = {
                    RequestSeq = 0
                    Success    = true
                    Command    = "continue"
                    Body       = Some """{"allThreadsContinued":true}"""
                    Message    = None
                }
                session, response

            | DapCommand.StepOver ->
                let response = {
                    RequestSeq = 0
                    Success    = true
                    Command    = "next"
                    Body       = None
                    Message    = None
                }
                session, response

            | DapCommand.StepIn ->
                let response = {
                    RequestSeq = 0
                    Success    = true
                    Command    = "stepIn"
                    Body       = None
                    Message    = None
                }
                session, response

            | DapCommand.StepOut ->
                let response = {
                    RequestSeq = 0
                    Success    = true
                    Command    = "stepOut"
                    Body       = None
                    Message    = None
                }
                session, response

            | DapCommand.Evaluate ->
                let expr =
                    match request.Arguments with
                    | Some json ->
                        try
                            use doc = JsonDocument.Parse(json)
                            let root = doc.RootElement
                            if root.TryGetProperty("expression", ref Unchecked.defaultof<_>) then
                                root.GetProperty("expression").GetString()
                            else json
                        with _ -> json
                    | None -> "<empty>"
                handleEvaluate session expr

            | DapCommand.Disconnect ->
                let updated = { session with Launched = false; Initialized = false }
                let response = {
                    RequestSeq = 0
                    Success    = true
                    Command    = "disconnect"
                    Body       = None
                    Message    = None
                }
                updated, response

        // Stamp the request seq onto the response
        let finalResponse = { rawResponse with RequestSeq = request.Seq }
        updatedSession, finalResponse

    // =========================================================================
    // SERIALIZATION
    // =========================================================================

    /// Serialize a DapResponse to a JSON string suitable for DAP transport.
    let toJson (response: DapResponse) : string =
        let successStr  = if response.Success then "true" else "false"
        let commandJson = JsonSerializer.Serialize(response.Command)
        let bodyJson    =
            match response.Body with
            | Some b -> sprintf ""","body":%s""" b
            | None   -> ""
        let messageJson =
            match response.Message with
            | Some m -> sprintf ""","message":%s""" (JsonSerializer.Serialize(m))
            | None   -> ""
        sprintf
            """{"type":"response","request_seq":%d,"success":%s,"command":%s%s%s}"""
            response.RequestSeq
            successStr
            commandJson
            bodyJson
            messageJson

    // =========================================================================
    // PARSING
    // =========================================================================

    /// Map a raw command string to a DapCommand DU case.
    /// Returns Error if the command is unrecognised.
    [<RequireQualifiedAccess>]
    module private CommandParser =
        let fromString (s: string) : Result<DapCommand, string> =
            match s.ToLowerInvariant() with
            | "initialize"     -> Ok DapCommand.Initialize
            | "launch"         -> Ok DapCommand.Launch
            | "attach"         -> Ok DapCommand.Attach
            | "setbreakpoints" -> Ok DapCommand.SetBreakpoints
            | "continue"       -> Ok DapCommand.Continue
            | "next"
            | "stepover"       -> Ok DapCommand.StepOver
            | "stepin"         -> Ok DapCommand.StepIn
            | "stepout"        -> Ok DapCommand.StepOut
            | "evaluate"       -> Ok DapCommand.Evaluate
            | "disconnect"     -> Ok DapCommand.Disconnect
            | unknown          -> Error (sprintf "Unknown DAP command: '%s'" unknown)

    /// Parse a raw JSON string (DAP wire format) into a DapRequest.
    /// Returns Error with a descriptive message if parsing fails.
    let parseRequest (json: string) : Result<DapRequest, string> =
        if String.IsNullOrWhiteSpace(json) then
            Error "Empty request payload"
        else
            try
                use doc = JsonDocument.Parse(json)
                let root = doc.RootElement

                let seqResult =
                    if root.TryGetProperty("seq", ref Unchecked.defaultof<_>) then
                        Ok (root.GetProperty("seq").GetInt32())
                    else
                        Error "Missing 'seq' field in DAP request"

                let commandResult =
                    if root.TryGetProperty("command", ref Unchecked.defaultof<_>) then
                        let rawCmd = root.GetProperty("command").GetString()
                        CommandParser.fromString rawCmd
                    else
                        Error "Missing 'command' field in DAP request"

                let argsOption =
                    if root.TryGetProperty("arguments", ref Unchecked.defaultof<_>) then
                        let argsProp = root.GetProperty("arguments")
                        if argsProp.ValueKind <> JsonValueKind.Null then
                            Some (argsProp.GetRawText())
                        else None
                    else None

                match seqResult, commandResult with
                | Ok seq, Ok cmd ->
                    Ok { Seq = seq; Command = cmd; Arguments = argsOption }
                | Error e, _ -> Error e
                | _, Error e -> Error e

            with ex ->
                Error (sprintf "JSON parse error: %s" ex.Message)
