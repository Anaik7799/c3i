// =============================================================================
// SseTransport.fs - MCP Server-Sent Events Transport for Remote Access
// =============================================================================
// STAMP: SC-MCP-001 (MCP server integration), SC-HTTP-001 (HTTP transport),
//        SC-API-001 (backoff/rate limiting), SC-SESS-001 (session management)
// AOR: AOR-MCP-001 (authorised MCP tool dispatch),
//      AOR-ENV-001 (environment configuration)
//
// Implements SSE (Server-Sent Events) transport layer for remote MCP access.
// Provides event framing, client registration, and heartbeat management.
//
// All public functions return Result<string, string>:
//   Ok    — formatted SSE frame or JSON acknowledgement
//   Error — human-readable error message
//
// Note: Connection state is tracked in an immutable record; actual I/O
// is the caller's responsibility. This module handles framing only.
// Version: 21.3.1 | 2026-03-28
// =============================================================================

namespace Cepaf.Mcp

open System
open System.Text.Json
open System.Text.Json.Serialization

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Classification of SSE event types sent to remote clients.
[<RequireQualifiedAccess>]
type SseEventKind =
    | Message    // normal MCP message
    | Heartbeat  // keepalive ping
    | Error      // transport-level error
    | Close      // session termination signal

/// Metadata for a registered SSE client session (SC-SESS-001).
[<CLIMutable>]
type SseClient = {
    [<JsonPropertyName("client_id")>]   ClientId    : string
    [<JsonPropertyName("remote_addr")>] RemoteAddr  : string
    [<JsonPropertyName("connected_at")>] ConnectedAt : string
    [<JsonPropertyName("last_ping")>]   LastPing    : string
    [<JsonPropertyName("event_count")>] EventCount  : int64
}

/// A framed SSE event ready for wire transmission.
[<CLIMutable>]
type SseFrame = {
    [<JsonPropertyName("event")>]  Event : string
    [<JsonPropertyName("data")>]   Data  : string
    [<JsonPropertyName("id")>]     Id    : string
    [<JsonPropertyName("retry")>]  Retry : int option
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

module private SseHelpers =

    let eventName (k: SseEventKind) : string =
        match k with
        | SseEventKind.Message   -> "message"
        | SseEventKind.Heartbeat -> "heartbeat"
        | SseEventKind.Error     -> "error"
        | SseEventKind.Close     -> "close"

    /// Format a SseFrame as a raw SSE wire string per RFC 8895.
    let formatFrame (frame: SseFrame) : string =
        let sb = System.Text.StringBuilder()
        sb.Append(sprintf "event: %s\n" frame.Event) |> ignore
        sb.Append(sprintf "id: %s\n"    frame.Id)    |> ignore
        // multi-line data: each line prefixed with "data: "
        frame.Data.Split('\n')
        |> Array.iter (fun line -> sb.Append(sprintf "data: %s\n" line) |> ignore)
        match frame.Retry with
        | Some ms -> sb.Append(sprintf "retry: %d\n" ms) |> ignore
        | None    -> ()
        sb.Append("\n") |> ignore  // blank line terminates event
        sb.ToString()

    let newClientId () : string =
        sprintf "SSE-%s-%s"
            (DateTimeOffset.UtcNow.ToString("yyyyMMddHHmmss"))
            (Guid.NewGuid().ToString("N").[..7])

    let utcNow () : string =
        DateTimeOffset.UtcNow.ToString("o")

    let serialise<'T> (v: 'T) : string =
        JsonSerializer.Serialize(v)

// ---------------------------------------------------------------------------
// SseTransport — MCP SSE transport functions
// ---------------------------------------------------------------------------

/// MCP SSE transport handler for remote client access.
/// Provides event framing, client record construction, and heartbeat generation.
module SseTransport =

    /// Creates a new SSE client registration record.
    ///
    /// Parameters:
    ///   remoteAddr — client IP:port string (e.g. "127.0.0.1:52341")
    ///
    /// Returns: JSON SseClient record with a generated client_id.
    let registerClient (remoteAddr: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace remoteAddr then
            Error "remote_addr must not be empty"
        else
            let client : SseClient = {
                ClientId    = SseHelpers.newClientId ()
                RemoteAddr  = remoteAddr
                ConnectedAt = SseHelpers.utcNow ()
                LastPing    = SseHelpers.utcNow ()
                EventCount  = 0L
            }
            eprintfn "[SseTransport] client registered: %s from %s" client.ClientId remoteAddr
            Ok (SseHelpers.serialise client)

    /// Produces a formatted SSE message frame for the given JSON payload.
    ///
    /// Parameters:
    ///   clientId — the registered client ID
    ///   eventId  — monotonically increasing event sequence number
    ///   payload  — JSON string to embed in the data field
    ///
    /// Returns: SSE wire-format string (ready to write to HTTP response stream).
    let frameMessage
        (clientId : string)
        (eventId  : int64)
        (payload  : string) : Result<string, string> =

        if String.IsNullOrWhiteSpace clientId then
            Error "client_id must not be empty"
        elif String.IsNullOrWhiteSpace payload then
            Error "payload must not be empty"
        else
            let frame : SseFrame = {
                Event = SseHelpers.eventName SseEventKind.Message
                Data  = payload
                Id    = sprintf "%s-%d" clientId eventId
                Retry = Some 3000
            }
            Ok (SseHelpers.formatFrame frame)

    /// Produces a heartbeat SSE frame to keep the connection alive.
    ///
    /// Parameters:
    ///   clientId — the registered client ID
    ///   eventId  — current event sequence number
    ///
    /// Returns: SSE wire-format heartbeat string.
    let frameHeartbeat (clientId: string) (eventId: int64) : Result<string, string> =
        if String.IsNullOrWhiteSpace clientId then
            Error "client_id must not be empty"
        else
            let ts = SseHelpers.utcNow ()
            let frame : SseFrame = {
                Event = SseHelpers.eventName SseEventKind.Heartbeat
                Data  = SseHelpers.serialise {| ts = ts; client_id = clientId |}
                Id    = sprintf "%s-hb-%d" clientId eventId
                Retry = None
            }
            Ok (SseHelpers.formatFrame frame)

    /// Produces a close SSE frame signalling session termination.
    ///
    /// Parameters:
    ///   clientId — the registered client ID
    ///   reason   — human-readable termination reason
    ///
    /// Returns: SSE wire-format close frame.
    let frameClose (clientId: string) (reason: string) : Result<string, string> =
        if String.IsNullOrWhiteSpace clientId then
            Error "client_id must not be empty"
        else
            let frame : SseFrame = {
                Event = SseHelpers.eventName SseEventKind.Close
                Data  = SseHelpers.serialise {| client_id = clientId; reason = reason; ts = SseHelpers.utcNow () |}
                Id    = sprintf "%s-close" clientId
                Retry = None
            }
            Ok (SseHelpers.formatFrame frame)
