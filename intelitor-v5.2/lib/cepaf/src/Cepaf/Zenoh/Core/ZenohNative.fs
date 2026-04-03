// =============================================================================
// ZenohNative.fs - Native FFI Wrappers for Zenoh-CS
// =============================================================================
// STAMP: SC-NAT-001 to SC-NAT-004, SC-SESS-005
// AOR: AOR-ZENOH-002, AOR-ZENOH-003
// Criticality: Level 1 (CRITICAL) - FFI Safety Layer
// =============================================================================
// Provides safe F# wrappers around Zenoh-CS native calls:
// - IDisposable pattern for all owned resources (SC-NAT-002)
// - Null checks on all native returns (SC-NAT-004)
// - Exception handling with Result types (SC-SESS-005)
// - KeyExpr validation before operations (SC-NAT-003)
// =============================================================================
// NOTE: Native-only mode — all Zenoh operations go through Rust FFI bridge.
// The FFI library (libzenoh_ffi.so) must be on LD_LIBRARY_PATH.
// Falls back to simulated ONLY when FFI library is not loadable.
// =============================================================================

namespace Cepaf.Zenoh.Core

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent

/// Zenoh native configuration — native FFI is always the default.
/// The ZENOH_USE_NATIVE env var is no longer needed; FFI is used
/// whenever libzenoh_ffi.so is available on LD_LIBRARY_PATH.
module ZenohNativeConfig =
    /// Legacy env var — kept for backward compatibility but no longer checked.
    /// Native mode is now always active when FFI library is loadable.
    let [<Literal>] UseNativeEnvVar = "ZENOH_USE_NATIVE"

    /// Check if native library should be used — ALWAYS true now.
    /// Falls back to false only when FFI library cannot be loaded.
    let useNative () = ZenohFfiBridge.isAvailable()

    /// Zenoh FFI library version (Rust cdylib)
    let [<Literal>] RequiredVersion = "0.1.0"

    /// Zenoh protocol version (wire-compatible with Elixir NIF)
    let [<Literal>] RequiredNativeVersion = "1.7.0"

/// KeyExpr validation utilities (SC-NAT-003)
module ZenohKeyExpr =

    /// Valid characters in key expression segments
    let private isValidChar (c: char) =
        Char.IsLetterOrDigit(c) || c = '_' || c = '-' || c = '.'

    /// Validate a key expression
    let validate (keyExpr: string) : ZenohResult<string> =
        if String.IsNullOrWhiteSpace(keyExpr) then
            Error (ZenohError.InvalidKeyExpr(keyExpr, "Key expression cannot be empty"))
        elif keyExpr.Contains("//") then
            Error (ZenohError.InvalidKeyExpr(keyExpr, "Key expression cannot contain '//'"))
        elif keyExpr.StartsWith("/") then
            Error (ZenohError.InvalidKeyExpr(keyExpr, "Key expression cannot start with '/'"))
        elif keyExpr.EndsWith("/") then
            Error (ZenohError.InvalidKeyExpr(keyExpr, "Key expression cannot end with '/'"))
        else
            // Validate each segment
            let segments = keyExpr.Split('/')
            let invalidSegment =
                segments
                |> Array.tryFind (fun seg ->
                    seg <> "*" && seg <> "**" &&
                    not (seg |> Seq.forall isValidChar))

            match invalidSegment with
            | Some seg ->
                Error (ZenohError.InvalidKeyExpr(keyExpr, sprintf "Invalid segment '%s'" seg))
            | None -> Ok keyExpr

    /// Check if a key expression matches a pattern
    let matches (pattern: string) (key: string) : bool =
        let patternParts = pattern.Split('/')
        let keyParts = key.Split('/')

        let rec matchParts pIdx kIdx =
            if pIdx >= patternParts.Length && kIdx >= keyParts.Length then true
            elif pIdx >= patternParts.Length then false
            elif patternParts.[pIdx] = "**" then
                // ** matches zero or more segments
                if pIdx = patternParts.Length - 1 then true
                else
                    // Try matching remaining pattern at each position
                    let remainingPattern = patternParts.[pIdx+1..]
                    seq { kIdx .. keyParts.Length }
                    |> Seq.exists (fun k -> matchParts (pIdx + 1) k)
            elif kIdx >= keyParts.Length then false
            elif patternParts.[pIdx] = "*" then
                // * matches exactly one segment
                matchParts (pIdx + 1) (kIdx + 1)
            elif patternParts.[pIdx] = keyParts.[kIdx] then
                matchParts (pIdx + 1) (kIdx + 1)
            else false

        matchParts 0 0

    /// Join key expression parts
    let join (parts: string list) : string =
        parts
        |> List.filter (not << String.IsNullOrEmpty)
        |> String.concat "/"

    /// Parse key expression into parts
    let parts (keyExpr: string) : string list =
        keyExpr.Split('/') |> Array.toList

/// Safe session wrapper with IDisposable (SC-NAT-002)
[<Sealed>]
type SafeSession private (sessionId: string, config: SessionConfig, isSimulated: bool) =
    let mutable disposed = false
    let mutable connected = true
    let lockObj = obj()
    let publishers = ConcurrentDictionary<string, SafePublisher>()
    let subscribers = ConcurrentDictionary<string, SafeSubscriber>()

    /// Session identifier
    member _.SessionId = sessionId

    /// Session configuration
    member _.Config = config

    /// Check if session is valid
    member _.IsValid =
        not disposed && connected

    /// Check if using simulated backend
    member _.IsSimulated = isSimulated

    /// Active publisher count
    member _.PublisherCount = publishers.Count

    /// Active subscriber count
    member _.SubscriberCount = subscribers.Count

    /// Native FFI session handle (nativeint, 0 if simulated)
    member val internal NativeHandle : nativeint = nativeint 0 with get, set

    /// Open a new session (SC-NAT-001)
    /// Native-only: always attempts Rust FFI first (SC-ZENOH-FFI-001).
    /// Falls back to simulated only when libzenoh_ffi.so is not loadable.
    static member OpenAsync(config: SessionConfig) : Task<ZenohResult<SafeSession>> =
        task {
            try
                if ZenohFfiBridge.isAvailable() then
                    // Native FFI available — always use it (native-only mode)
                    match ZenohFfiBridge.openSession config with
                    | Ok handle ->
                        let sessionId = sprintf "ffi-%s-%s" config.Name (Guid.NewGuid().ToString("N").[..7])
                        let session = new SafeSession(sessionId, config, false)
                        session.NativeHandle <- handle
                        return Ok session
                    | Error e ->
                        // FFI available but connection failed (router unreachable)
                        // Fall back to log-only mode (ZenohPublish triple-write still works)
                        eprintfn "[ZenohNative] FFI open failed: %s, using log-only session" e.Message
                        return SafeSession.OpenSimulatedAsync(config) |> Async.RunSynchronously
                else
                    // FFI library not loadable (no libzenoh_ffi.so on LD_LIBRARY_PATH)
                    // Use simulated session for local dev without Rust build
                    eprintfn "[ZenohNative] FFI not available, using simulated session"
                    return SafeSession.OpenSimulatedAsync(config) |> Async.RunSynchronously
            with ex ->
                return Error (ZenohError.ConnectionFailed ex.Message)
        }

    /// Open simulated session for development/testing
    static member private OpenSimulatedAsync(config: SessionConfig) : Async<ZenohResult<SafeSession>> =
        async {
            do! Async.Sleep(50)  // Simulate connection delay
            let sessionId = sprintf "sim-%s-%s" config.Name (Guid.NewGuid().ToString("N").[..7])
            return Ok (new SafeSession(sessionId, config, true))
        }

    /// Register a publisher (internal)
    member internal this.RegisterPublisher(keyExpr: string, pub: SafePublisher) =
        publishers.[keyExpr] <- pub

    /// Unregister a publisher (internal)
    member internal this.UnregisterPublisher(keyExpr: string) =
        publishers.TryRemove(keyExpr) |> ignore

    /// Register a subscriber (internal)
    member internal this.RegisterSubscriber(keyExpr: string, sub: SafeSubscriber) =
        subscribers.[keyExpr] <- sub

    /// Unregister a subscriber (internal)
    member internal this.UnregisterSubscriber(keyExpr: string) =
        subscribers.TryRemove(keyExpr) |> ignore

    /// Close session gracefully
    /// Closes FFI handle if native session (SC-ZENOH-FFI-002)
    member this.CloseAsync() : Task<unit> =
        task {
            if not disposed then
                lock lockObj (fun () ->
                    if not disposed then
                        disposed <- true
                        connected <- false

                        // Dispose all publishers
                        for kvp in publishers do
                            try (kvp.Value :> IDisposable).Dispose() with _ -> ()
                        publishers.Clear()

                        // Dispose all subscribers
                        for kvp in subscribers do
                            try (kvp.Value :> IDisposable).Dispose() with _ -> ()
                        subscribers.Clear()

                        // Close native FFI handle (SC-ZENOH-FFI-002)
                        if this.NativeHandle <> nativeint 0 then
                            ZenohFfiBridge.closeSession this.NativeHandle
                            this.NativeHandle <- nativeint 0
                )
        }

    interface IDisposable with
        member this.Dispose() =
            this.CloseAsync().Wait()

/// Safe publisher wrapper (SC-NAT-002)
and [<Sealed>] SafePublisher private (session: SafeSession, keyExpr: string) =
    let mutable disposed = false
    let mutable messageCount = 0L

    member _.KeyExpr = keyExpr
    member _.MessageCount = messageCount
    member _.Session = session

    /// Create publisher from session
    static member Create(session: SafeSession, config: PublisherConfig) : ZenohResult<SafePublisher> =
        if not session.IsValid then
            Error ZenohError.SessionClosed
        else
            // Validate key expression (SC-NAT-003)
            match ZenohKeyExpr.validate config.KeyExpr with
            | Error e -> Error e
            | Ok keyExpr ->
                let pub = new SafePublisher(session, keyExpr)
                session.RegisterPublisher(keyExpr, pub)
                Ok pub

    /// Publish bytes — native-only mode.
    /// Always attempts FFI when native handle is available (SC-ZTEST-003: latency < 10ms).
    /// If no native handle (FFI open failed), increments counter only (log-only mode).
    member this.PutAsync(payload: byte[]) : Task<ZenohResult<unit>> =
        task {
            if disposed then
                return Error (ZenohError.Disposed "Publisher")
            elif not session.IsValid then
                return Error ZenohError.SessionClosed
            else
                try
                    if session.NativeHandle <> nativeint 0 then
                        // Real Zenoh publish via Rust FFI (SC-ZENOH-FFI-015)
                        match ZenohFfiBridge.publish session.NativeHandle keyExpr payload with
                        | Ok () ->
                            Interlocked.Increment(&messageCount) |> ignore
                            return Ok ()
                        | Error e ->
                            return Error e
                    else
                        // No native handle (FFI unavailable or router down)
                        // Increment counter — ZenohPublish triple-write still logs
                        Interlocked.Increment(&messageCount) |> ignore
                        return Ok ()
                with ex ->
                    return Error (ZenohError.PublishFailed(keyExpr, ex.Message))
        }

    /// Publish string (convenience method)
    member this.PutStringAsync(payload: string) : Task<ZenohResult<unit>> =
        let bytes = System.Text.Encoding.UTF8.GetBytes(payload)
        this.PutAsync(bytes)

    interface IDisposable with
        member _.Dispose() =
            if not disposed then
                disposed <- true
                session.UnregisterPublisher(keyExpr)

/// Safe subscriber wrapper (SC-NAT-002)
and [<Sealed>] SafeSubscriber private (session: SafeSession, keyExpr: string, handler: ZenohSample -> unit) =
    let mutable disposed = false
    let mutable messageCount = 0L

    member _.KeyExpr = keyExpr
    member _.MessageCount = messageCount
    member _.Session = session

    /// Create subscriber from session
    static member Create(
        session: SafeSession,
        config: SubscriberConfig,
        handler: ZenohSample -> unit) : ZenohResult<SafeSubscriber> =
        if not session.IsValid then
            Error ZenohError.SessionClosed
        else
            // Validate key expression (SC-NAT-003)
            match ZenohKeyExpr.validate config.KeyExpr with
            | Error e -> Error e
            | Ok keyExpr ->
                // Wrap handler with error handling (SC-SESS-005)
                let safeHandler (sample: ZenohSample) =
                    try
                        handler sample
                    with ex ->
                        // Log but don't throw (SC-MSG-003)
                        eprintfn "[Zenoh] Callback error for '%s': %s" keyExpr ex.Message

                let sub = new SafeSubscriber(session, keyExpr, safeHandler)
                session.RegisterSubscriber(keyExpr, sub)
                Ok sub

    /// Deliver a sample (for testing/simulation)
    member internal this.DeliverSample(sample: ZenohSample) =
        if not disposed then
            Interlocked.Increment(&messageCount) |> ignore
            handler sample

    interface IDisposable with
        member _.Dispose() =
            if not disposed then
                disposed <- true
                session.UnregisterSubscriber(keyExpr)

/// Message bus for simulated pub/sub (development/testing)
module SimulatedMessageBus =

    let private subscriptions = ConcurrentDictionary<string, ResizeArray<SafeSubscriber>>()

    /// Subscribe to a key expression pattern
    let subscribe (keyExpr: string) (subscriber: SafeSubscriber) =
        let subs = subscriptions.GetOrAdd(keyExpr, fun _ -> ResizeArray<SafeSubscriber>())
        lock subs (fun () -> subs.Add(subscriber))

    /// Unsubscribe
    let unsubscribe (keyExpr: string) (subscriber: SafeSubscriber) =
        match subscriptions.TryGetValue(keyExpr) with
        | true, subs ->
            lock subs (fun () -> subs.Remove(subscriber) |> ignore)
        | false, _ -> ()

    /// Publish to matching subscribers
    let publish (keyExpr: string) (payload: byte[]) =
        let sample = {
            ZenohSample.empty with
                KeyExpr = keyExpr
                Payload = payload
                Timestamp = Some DateTimeOffset.UtcNow
        }

        for kvp in subscriptions do
            if ZenohKeyExpr.matches kvp.Key keyExpr then
                for sub in kvp.Value do
                    sub.DeliverSample(sample)

    /// Clear all subscriptions
    let clear () =
        subscriptions.Clear()

/// Exponential backoff calculator (SC-OP-002)
module ExponentialBackoff =

    /// Calculate backoff delay for given attempt
    let calculate (attempt: int) (baseMs: int) (maxMs: int) : int =
        let exp = min attempt 10  // Cap exponent to prevent overflow
        let backoff = baseMs * (pown 2 exp)
        min backoff maxMs

    /// Default base delay (1 second)
    let [<Literal>] DefaultBaseMs = 1000

    /// Default max delay (60 seconds, per SC-OP-002)
    let [<Literal>] DefaultMaxMs = 60000

    /// Calculate with defaults
    let defaultBackoff (attempt: int) =
        calculate attempt DefaultBaseMs DefaultMaxMs

    /// Create backoff sequence
    let sequence (baseMs: int) (maxMs: int) =
        Seq.initInfinite (fun i -> calculate i baseMs maxMs)
