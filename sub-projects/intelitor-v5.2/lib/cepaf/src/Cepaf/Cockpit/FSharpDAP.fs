// =============================================================================
// FSharpDAP.fs - CEPAF Cockpit Debug Adapter Protocol Model
// =============================================================================
// STAMP: SC-DEBUG-001, SC-HMI-010
// AOR: AOR-DEBUG-001
// Version: 21.3.2 | 2026-03-30
//
// MODEL layer — defines DAP message types and pure rendering functions for
// the Prajna Cockpit F# debugger panel. No I/O, no side effects, no actual
// protocol handlers. All state is passed in; all output is a returned string.
//
// ## Constitutional Alignment
// - Ψ₃ (Verification): Breakpoints, call-stack frames, and variable values
//   are all auditable, time-stamped data structures — not opaque handles.
//
// ## STAMP Compliance
// - SC-DEBUG-001: Telemetry bus / debug probe model — pure, composable
// - SC-HMI-010: Vibrant chromatic feedback — ANSI colours per DAP state
//
// ## Design Notes
// DapSession is a value type — callers mutate by constructing a new record.
// All collections are immutable F# lists. DateTimeOffset is used throughout
// so that rendered timestamps show local offset, aiding crash correlation.
// =============================================================================

namespace Cepaf.Cockpit

open System
open System.Collections.Generic

// ---------------------------------------------------------------------------
// ANSI colour helpers (inline — avoids Cepaf.Observability dependency)
// Mirrors palette used in HealthDashboard.fs and ContainerHealthBars.fs
// ---------------------------------------------------------------------------

[<RequireQualifiedAccess>]
module private DapAnsi =
    let reset    = "\u001b[0m"
    let bold     = "\u001b[1m"
    let dim      = "\u001b[2m"
    let italic   = "\u001b[3m"
    let green    = "\u001b[32m"
    let yellow   = "\u001b[33m"
    let red      = "\u001b[31m"
    let blue     = "\u001b[34m"
    let magenta  = "\u001b[35m"
    let cyan     = "\u001b[36m"
    let white    = "\u001b[37m"
    let bGreen   = "\u001b[92m"
    let bYellow  = "\u001b[93m"
    let bRed     = "\u001b[91m"
    let bBlue    = "\u001b[94m"
    let bMagenta = "\u001b[95m"
    let bCyan    = "\u001b[96m"
    let bWhite   = "\u001b[97m"
    // Background colours for highlighted rows
    let bgDark   = "\u001b[48;5;235m"
    let bgMid    = "\u001b[48;5;238m"

// ---------------------------------------------------------------------------
// Discriminated union types
// ---------------------------------------------------------------------------

/// Classifies a DAP wire message by its flow direction and purpose.
[<RequireQualifiedAccess>]
type DapMessageKind =
    /// IDE → adapter (e.g. "setBreakpoints", "stackTrace", "continue")
    | Request
    /// Adapter → IDE in response to a Request
    | Response
    /// Adapter → IDE unsolicited notification (e.g. "stopped", "output")
    | Event
    /// Adapter → IDE request (e.g. "runInTerminal") — adapter-initiated call
    | ReverseRequest

/// Lifecycle state of a DAP debug session as seen by the adapter.
[<RequireQualifiedAccess>]
type DapState =
    /// InitializeRequest not yet received; adapter not ready.
    | Uninitialized
    /// InitializeRequest acknowledged; launch/attach not yet issued.
    | Initialized
    /// Program executing; no pending stop.
    | Running
    /// Program suspended at a breakpoint, step, or exception.
    | Stopped
    /// Program exited; session may still be queried but cannot be resumed.
    | Terminated

/// Reason the debuggee transitioned to the Stopped state.
[<RequireQualifiedAccess>]
type StopReason =
    /// Paused at a user-defined breakpoint (line or conditional).
    | Breakpoint
    /// Paused after a single-step (step-over, step-in, step-out).
    | Step
    /// Paused due to an unhandled or user-configured exception.
    | Exception
    /// Paused in response to an explicit pause/suspend request from the IDE.
    | Pause
    /// Paused at the entry point of the program on first launch.
    | Entry
    /// Paused after a "goto" instruction redirected execution.
    | Goto

// ---------------------------------------------------------------------------
// Record types
// ---------------------------------------------------------------------------

/// Metadata for a single source breakpoint, as returned by SetBreakpointsResponse.
type BreakpointInfo = {
    /// Unique identity assigned by the adapter (positive integer).
    Id       : int
    /// True once the adapter has confirmed the runtime can honour this location.
    Verified : bool
    /// Absolute or workspace-relative file path.
    FilePath : string
    /// 1-based line number of the breakpoint.
    Line     : int
    /// Optional 1-based column number within the line.
    Column   : int option
    /// Optional conditional expression; breakpoint fires only when this is truthy.
    Condition : string option
}

/// One frame in a thread's call stack, as returned by StackTraceResponse.
type StackFrame = {
    /// Unique frame identity for this pause session (assigned by the adapter).
    Id     : int
    /// Human-readable name — usually the function or method name.
    Name   : string
    /// Display path of the source file (may be a relative path or URI).
    Source : string
    /// 1-based line number of the instruction pointer within the frame.
    Line   : int
    /// 1-based column of the instruction pointer.
    Column : int
}

/// One variable in a scope, as returned by VariablesResponse.
type Variable = {
    /// Variable name as it appears in source code.
    Name               : string
    /// Formatted value suitable for display (the adapter chooses the format).
    Value              : string
    /// Type annotation — language-level type name (may be empty string).
    Type               : string
    /// Non-zero when this variable is itself structured; use as handle for
    /// a further VariablesRequest to enumerate children.
    VariablesReference : int
}

/// Full snapshot of a DAP debug session.  Immutable — mutations yield new records.
type DapSession = {
    /// Opaque identifier provided by the IDE at launch/attach time.
    SessionId     : string
    /// Current lifecycle state of the session.
    State         : DapState
    /// All breakpoints known to this session (including unverified ones).
    Breakpoints   : BreakpointInfo list
    /// Call stack of the active thread at the most recent stop, top-of-stack first.
    CallStack     : StackFrame list
    /// OS thread ID that owns the current stop event (0 when not stopped).
    ActiveThread  : int
    /// Wall-clock time of the last state transition.
    Timestamp     : DateTimeOffset
}

// ---------------------------------------------------------------------------
// FSharpDAP — pure rendering functions
// ---------------------------------------------------------------------------

/// Model layer for the DAP debug panel in the Prajna Cockpit.
/// All functions are pure — they consume typed F# values and return ANSI strings.
[<RequireQualifiedAccess>]
module FSharpDAP =

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Box-drawing characters used for panel borders.
    let private borderTop    = "╔══════════════════════════════════════════════════════════╗"
    let private borderBottom = "╚══════════════════════════════════════════════════════════╝"
    let private borderMid    = "╠══════════════════════════════════════════════════════════╣"
    let private borderSide   = "║"

    /// Pads or truncates `s` to exactly `n` characters, left-aligned, ASCII-safe.
    /// ANSI escape sequences are not counted — this operates on visible characters only.
    let private padTo (n: int) (s: string) : string =
        if s.Length >= n then s.Substring(0, n)
        else s.PadRight(n)

    /// Renders a single border row whose visible content is `content` (62 visible chars wide).
    let private boxLine (content: string) : string =
        sprintf "%s %s%s" borderSide (padTo 60 content) borderSide

    /// Converts a StopReason to a compact display label.
    let private stopReasonLabel (reason: StopReason) : string =
        match reason with
        | StopReason.Breakpoint -> "BREAKPOINT"
        | StopReason.Step       -> "STEP"
        | StopReason.Exception  -> "EXCEPTION"
        | StopReason.Pause      -> "PAUSE"
        | StopReason.Entry      -> "ENTRY"
        | StopReason.Goto       -> "GOTO"

    /// Returns a short label for a DapMessageKind.
    let private messageKindLabel (kind: DapMessageKind) : string =
        match kind with
        | DapMessageKind.Request        -> "REQ"
        | DapMessageKind.Response       -> "RSP"
        | DapMessageKind.Event          -> "EVT"
        | DapMessageKind.ReverseRequest -> "RREQ"

    /// Formats an optional int as "col N" or empty string.
    let private fmtCol (col: int option) : string =
        match col with
        | None   -> ""
        | Some c -> sprintf " col:%d" c

    /// Formats an optional condition as "(cond: …)" or empty string, truncated to 24 chars.
    let private fmtCond (cond: string option) : string =
        match cond with
        | None   -> ""
        | Some c ->
            let display = if c.Length > 22 then c.Substring(0, 19) + "..." else c
            sprintf " [%s]" display

    /// Truncates a file path to a displayable suffix of at most `maxLen` characters.
    /// Prefers keeping the filename and immediately-enclosing directory.
    let private shortPath (maxLen: int) (path: string) : string =
        if path.Length <= maxLen then path
        else
            let sep = if path.Contains('/') then '/' else '\\'
            let parts = path.Split(sep)
            match parts.Length with
            | 0 -> path.Substring(path.Length - maxLen)
            | 1 -> path.Substring(path.Length - maxLen)
            | _ ->
                let candidate = String.concat (string sep) (Array.skip (parts.Length - 2) parts)
                if candidate.Length <= maxLen then "…" + string sep + candidate
                else "…" + string sep + (Array.last parts)

    // -----------------------------------------------------------------------
    // Public — state colour
    // -----------------------------------------------------------------------

    /// Returns the ANSI colour escape for rendering a DapState label.
    /// Colours follow SC-HMI-010 (Color Rich): green = safe, yellow = transitional,
    /// red = terminated/error, cyan = active/running, blue = initialized-but-idle.
    let stateColour (state: DapState) : string =
        match state with
        | DapState.Uninitialized -> DapAnsi.dim
        | DapState.Initialized   -> DapAnsi.bBlue
        | DapState.Running       -> DapAnsi.bGreen
        | DapState.Stopped       -> DapAnsi.bYellow
        | DapState.Terminated    -> DapAnsi.bRed

    // -----------------------------------------------------------------------
    // Public — individual component renderers
    // -----------------------------------------------------------------------

    /// Renders a single breakpoint as an ANSI-coloured one-line string.
    ///
    /// Format:
    ///   [ID] ● path/file.fs:LINE COLINFO CONDINFO  — verified | UNVERIFIED
    ///
    /// Verified breakpoints render in green; unverified in yellow.
    let renderBreakpoint (bp: BreakpointInfo) : string =
        let (stateGlyph, stateCol) =
            if bp.Verified
            then ("●", DapAnsi.bGreen)
            else ("○", DapAnsi.bYellow)

        let path  = shortPath 36 bp.FilePath
        let loc   = sprintf "%s:%d%s" path bp.Line (fmtCol bp.Column)
        let cond  = fmtCond bp.Condition

        sprintf "  %s[%3d]%s %s%s%s  %s%-36s%s%s"
            DapAnsi.dim bp.Id DapAnsi.reset
            stateCol stateGlyph DapAnsi.reset
            DapAnsi.white loc DapAnsi.reset
            (sprintf "%s%s%s" DapAnsi.dim cond DapAnsi.reset)

    /// Renders the call stack as a multi-line ANSI string.
    ///
    /// The top-most frame (index 0) is highlighted as the active frame.
    /// Each subsequent frame is dimmed to reduce visual noise.
    ///
    /// Format per line:
    ///   #N  FunctionName          source/file.fs:LINE:COL
    let renderCallStack (frames: StackFrame list) : string =
        if List.isEmpty frames then
            sprintf "  %s(no call stack)%s" DapAnsi.dim DapAnsi.reset
        else
            frames
            |> List.mapi (fun i frame ->
                let (numCol, nameCol, locCol) =
                    if i = 0 then
                        (DapAnsi.bCyan, DapAnsi.bWhite, DapAnsi.cyan)
                    else
                        (DapAnsi.dim, DapAnsi.white, DapAnsi.dim)

                let name    = padTo 28 frame.Name
                let path    = shortPath 24 frame.Source
                let loc     = sprintf "%s:%d:%d" path frame.Line frame.Column

                sprintf "  %s#%-2d%s %s%s%s %s%s%s"
                    numCol i DapAnsi.reset
                    nameCol name DapAnsi.reset
                    locCol loc DapAnsi.reset)
            |> String.concat "\n"

    /// Renders the variable watch panel as a multi-line ANSI string.
    ///
    /// Variables with a non-zero VariablesReference (structured values) are
    /// marked with a ▶ prefix indicating they can be expanded.
    ///
    /// Format per line:
    ///   NAME         : TYPE = VALUE   [▶ expandable]
    let renderVariables (vars: Variable list) : string =
        if List.isEmpty vars then
            sprintf "  %s(no variables)%s" DapAnsi.dim DapAnsi.reset
        else
            vars
            |> List.map (fun v ->
                let expandable =
                    if v.VariablesReference > 0
                    then sprintf " %s▶%s" DapAnsi.bCyan DapAnsi.reset
                    else ""

                let typeHint =
                    if String.IsNullOrEmpty(v.Type) then ""
                    else sprintf "%s%s%s " DapAnsi.dim v.Type DapAnsi.reset

                sprintf "  %s%-20s%s %s: %s= %s%s%s%s"
                    DapAnsi.bCyan v.Name DapAnsi.reset
                    typeHint
                    DapAnsi.dim DapAnsi.reset
                    DapAnsi.bWhite v.Value DapAnsi.reset
                    + expandable)
            |> String.concat "\n"

    /// Renders a compact ANSI debug session view suitable for the Prajna Cockpit panel.
    ///
    /// Sections rendered:
    ///   1. Header  — session ID, state badge, active thread, timestamp
    ///   2. Breakpoints — all known breakpoints (verified and unverified)
    ///   3. Call Stack  — frames of the active thread at the most recent stop
    ///
    /// Returns a multi-line string terminated with a trailing newline.
    let renderSession (session: DapSession) : string =
        let sb = System.Text.StringBuilder()

        // Helper: append a line with trailing newline
        let line (s: string) = sb.AppendLine(s) |> ignore

        let stateLabel =
            match session.State with
            | DapState.Uninitialized -> "UNINITIALIZED"
            | DapState.Initialized   -> "INITIALIZED"
            | DapState.Running       -> "RUNNING"
            | DapState.Stopped       -> "STOPPED"
            | DapState.Terminated    -> "TERMINATED"

        let stateCol   = stateColour session.State
        let tsDisplay  = session.Timestamp.ToString("HH:mm:ss.fff zzz")
        let sessionShort = if session.SessionId.Length > 16 then session.SessionId.Substring(0, 16) + "…" else session.SessionId

        // ── Header ──────────────────────────────────────────────────────────
        line (sprintf "%s%s%s" DapAnsi.bCyan borderTop DapAnsi.reset)

        let headerContent =
            sprintf "%sF# DAP%s  session:%s%s%s  thread:%s%d%s  %s%s"
                DapAnsi.bold DapAnsi.reset
                DapAnsi.bWhite sessionShort DapAnsi.reset
                DapAnsi.bMagenta session.ActiveThread DapAnsi.reset
                DapAnsi.dim tsDisplay

        line (boxLine headerContent)

        let stateContent =
            sprintf "State: %s%-13s%s  bp:%s%d%s  frames:%s%d%s"
                stateCol stateLabel DapAnsi.reset
                DapAnsi.bWhite (List.length session.Breakpoints) DapAnsi.reset
                DapAnsi.bWhite (List.length session.CallStack) DapAnsi.reset

        line (boxLine stateContent)

        // ── Breakpoints section ──────────────────────────────────────────────
        line (sprintf "%s%s%s" DapAnsi.dim borderMid DapAnsi.reset)

        let bpHeader = sprintf "%sBREAKPOINTS%s  (%d)" DapAnsi.bold DapAnsi.reset (List.length session.Breakpoints)
        line (boxLine bpHeader)

        if List.isEmpty session.Breakpoints then
            line (boxLine (sprintf "%s  (none)%s" DapAnsi.dim DapAnsi.reset))
        else
            session.Breakpoints
            |> List.iter (fun bp -> line (renderBreakpoint bp))

        // ── Call stack section ───────────────────────────────────────────────
        line (sprintf "%s%s%s" DapAnsi.dim borderMid DapAnsi.reset)

        let csHeader = sprintf "%sCALL STACK%s  (%d frames)" DapAnsi.bold DapAnsi.reset (List.length session.CallStack)
        line (boxLine csHeader)

        if List.isEmpty session.CallStack then
            line (boxLine (sprintf "%s  (no frames — not stopped)%s" DapAnsi.dim DapAnsi.reset))
        else
            let stackText = renderCallStack session.CallStack
            stackText.Split('\n')
            |> Array.iter (fun stackLine -> line stackLine)

        // ── Footer ──────────────────────────────────────────────────────────
        line (sprintf "%s%s%s" DapAnsi.bCyan borderBottom DapAnsi.reset)

        sb.ToString()

    // -----------------------------------------------------------------------
    // Public — mock default session
    // -----------------------------------------------------------------------

    /// Returns a mock DapSession populated with realistic sample data.
    ///
    /// Useful for cockpit panel rendering during design-time and unit tests.
    /// The session is Stopped at a conditional breakpoint with a three-frame
    /// call stack and a handful of primitive and structured variables.
    let defaultSession () : DapSession =
        {
            SessionId    = "dap-fsharp-dev-42"
            State        = DapState.Stopped
            ActiveThread = 1
            Timestamp    = DateTimeOffset(2026, 3, 30, 12, 0, 0, TimeSpan.Zero)
            Breakpoints  =
                [
                    {
                        Id        = 1
                        Verified  = true
                        FilePath  = "lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs"
                        Line      = 318
                        Column    = Some 9
                        Condition = Some "health.Rp > 200"
                    }
                    {
                        Id        = 2
                        Verified  = true
                        FilePath  = "lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs"
                        Line      = 402
                        Column    = None
                        Condition = None
                    }
                    {
                        Id        = 3
                        Verified  = false
                        FilePath  = "lib/cepaf/src/Cepaf/Cockpit/SentinelBridge.fs"
                        Line      = 77
                        Column    = Some 13
                        Condition = None
                    }
                ]
            CallStack    =
                [
                    {
                        Id     = 0
                        Name   = "computeDisciplineHealth"
                        Source = "lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs"
                        Line   = 318
                        Column = 9
                    }
                    {
                        Id     = 1
                        Name   = "assessAllDisciplines"
                        Source = "lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs"
                        Line   = 445
                        Column = 5
                    }
                    {
                        Id     = 2
                        Name   = "publishHealthMetrics"
                        Source = "lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs"
                        Line   = 512
                        Column = 5
                    }
                ]
        }
