namespace Cepaf.Mesh

open System
open Cepaf.Zenoh.Core

/// Unified Zenoh publishing abstraction with SC-ZTEST-008 triple-write pattern.
///
/// All F# publishers MUST use this module to ensure:
/// 1. Log fallback is written FIRST (guaranteed durability) — SC-ZTEST-008
/// 2. Real Zenoh publish via FFI (when available) — SC-ZTEST-003
/// 3. Structured JSON output for CEPAF bridge consumption
///
/// STAMP: SC-ZTEST-008 (log-based fallback), SC-ZTEST-003 (publish latency < 10ms)
/// STAMP: SC-ZENOH-FFI-016 (dual-write preserved with native)
/// AOR: AOR-ZTEST-008 (log fallback first), AOR-ZTEST-004 (async publishing)
/// AOR: AOR-FFI-006 (SC-ZTEST-008 dual-write preserved)
module ZenohPublish =

    /// Mutable global session handle for real Zenoh publishing.
    /// Set via setNativeSession when a native session is opened.
    let mutable private nativeSessionHandle : nativeint = nativeint 0

    /// Controls whether Step 3 (stdout JSON) is written.
    /// Disable during tests to prevent pipe buffer deadlock when throughput
    /// tests call publish 1000+ times (each write = 1 stdout line → 64KB pipe fills → deadlock).
    /// Default: false (off). The CEPAF bridge enables this when connected.
    let mutable private stdoutJsonEnabled : bool = false

    /// Enable stdout JSON output (Step 3 of triple-write).
    /// Called by CEPAF bridge when connected.
    let enableStdoutJson () = stdoutJsonEnabled <- true

    /// Disable stdout JSON output to prevent pipe buffer deadlock.
    let disableStdoutJson () = stdoutJsonEnabled <- false

    /// Set the native session handle for real Zenoh publishing.
    /// Call this when a NativeSession is opened.
    let setNativeSession (handle: nativeint) =
        nativeSessionHandle <- handle

    /// Clear the native session handle (on session close).
    let clearNativeSession () =
        nativeSessionHandle <- nativeint 0

    /// Write the SC-ZTEST-008 log fallback line. This MUST be called before any Zenoh attempt.
    let private writeLogFallback (checkpointId: string) (topic: string) (message: string) (stateVector: string option) =
        let timestamp = DateTimeOffset.UtcNow.ToString("o")
        let svPart = match stateVector with Some sv -> sprintf " state_vector=%s" sv | None -> ""
        eprintfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=%s%s timestamp=%s"
            checkpointId topic message svPart timestamp

    /// Attempt real Zenoh publish via FFI (best-effort, log fallback already written).
    let private tryNativePublish (topic: string) (jsonPayload: string) =
        if nativeSessionHandle <> nativeint 0 then
            let payload = System.Text.Encoding.UTF8.GetBytes(jsonPayload)
            match ZenohFfiBridge.publish nativeSessionHandle topic payload with
            | Ok () -> ()
            | Error e ->
                eprintfn "[ZenohPublish] Native publish failed for '%s': %s (log fallback already written)" topic e.Message

    /// Write structured JSON to stdout for CEPAF bridge consumption.
    /// Only writes when stdoutJsonEnabled = true (off by default to prevent pipe deadlock).
    let private writeStructuredJson (checkpointId: string) (topic: string) (payload: string) =
        if stdoutJsonEnabled then
            let timestamp = DateTimeOffset.UtcNow.ToString("o")
            printfn """{"zenoh_publish":{"checkpoint":"%s","topic":"%s","timestamp":"%s","payload":%s}}"""
                checkpointId topic timestamp payload

    /// <summary>
    /// Publish a checkpoint message using SC-ZTEST-008 triple-write pattern.
    /// 1. Writes [ZTEST-CHECKPOINT] log line to stderr (guaranteed durability)
    /// 2. Publishes to real Zenoh via FFI (best-effort, when available)
    /// 3. Writes structured JSON to stdout (CEPAF bridge consumption)
    /// Returns Ok() on success, Error(reason) on failure.
    /// </summary>
    let tryPublish (checkpointId: string) (topic: string) (message: string) (jsonPayload: string) : Result<unit, string> =
        try
            // Step 1: Log fallback FIRST per SC-ZTEST-008 (ALWAYS)
            writeLogFallback checkpointId topic message None
            // Step 2: Real Zenoh publish via FFI (best-effort)
            tryNativePublish topic jsonPayload
            // Step 3: Structured JSON for bridge (ALWAYS)
            writeStructuredJson checkpointId topic jsonPayload
            Ok ()
        with ex ->
            Error (sprintf "Publish failed for %s: %s" checkpointId ex.Message)

    /// Publish with state vector (for boot checkpoints that include state vector per SC-ZTEST-006).
    let tryPublishWithStateVector (checkpointId: string) (topic: string) (message: string) (stateVector: string) (jsonPayload: string) : Result<unit, string> =
        try
            writeLogFallback checkpointId topic message (Some stateVector)
            tryNativePublish topic jsonPayload
            writeStructuredJson checkpointId topic jsonPayload
            Ok ()
        with ex ->
            Error (sprintf "Publish failed for %s: %s" checkpointId ex.Message)

    /// Fire-and-forget publish (logs errors but doesn't propagate).
    let publish (checkpointId: string) (topic: string) (message: string) (jsonPayload: string) =
        tryPublish checkpointId topic message jsonPayload |> ignore

    /// Fire-and-forget publish with state vector.
    let publishWithStateVector (checkpointId: string) (topic: string) (message: string) (stateVector: string) (jsonPayload: string) =
        tryPublishWithStateVector checkpointId topic message stateVector jsonPayload |> ignore
