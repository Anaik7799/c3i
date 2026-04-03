// =============================================================================
// ConfigBridge.fs - CEPAF Config Synchronisation via Zenoh
// =============================================================================
// STAMP: SC-CONSOL-006 (ConfigBridge syncs F#/Elixir configs),
//        SC-ZENOH-001 (Zenoh NIF loaded), SC-ENV-001
// AOR: AOR-ZENOH-004 (log all connection state changes),
//      AOR-XHOLON-001 (Zenoh for cross-holon access)
//
// Publishes F# configuration sections to Elixir consumers via Zenoh
// key expression `indrajaal/config/{section}`, and subscribes to
// config-change messages originating from Elixir.
//
// Usage:
//   ConfigBridge.syncConfigs session configMap
//   ConfigBridge.onConfigChange session callback
//
// When ZENOH_USE_NATIVE is not set the module falls back to a simulated
// in-process pub/sub so tests do not require a live Zenoh router.
// =============================================================================

namespace Cepaf.Bridge

open System
open System.Text
open System.Text.Json
open System.Text.Json.Serialization
open Cepaf.Zenoh.Core

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A configuration section as a flat string→string map.
type ConfigSection = {
    [<JsonPropertyName("section")>]  Section  : string
    [<JsonPropertyName("values")>]   Values   : Map<string, string>
    [<JsonPropertyName("timestamp")>] Timestamp : string
}

/// Result of a config publish operation.
[<RequireQualifiedAccess>]
type ConfigPublishResult =
    | Published of section: string * bytes: int
    | Simulated of section: string
    | Failed    of section: string * error: string

/// A received config change notification.
type ConfigChange = {
    Section   : string
    NewValues : Map<string, string>
    Source    : string
    Timestamp : DateTimeOffset
}

// ---------------------------------------------------------------------------
// ConfigBridge
// ---------------------------------------------------------------------------

/// Bridges F# and Elixir configuration via Zenoh pub/sub.
/// Key expression pattern: `indrajaal/config/{section}`
module ConfigBridge =

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// True when the native Zenoh library is requested via env var.
    let private useNative () =
        match Environment.GetEnvironmentVariable("ZENOH_USE_NATIVE") with
        | "true" | "1" | "yes" -> true
        | _                    -> false

    /// Build the Zenoh key expression for a config section.
    let private keyFor (section: string) : string =
        sprintf "indrajaal/config/%s" (section.ToLowerInvariant())

    /// Serialise a ConfigSection to a UTF-8 JSON byte array.
    let private serialise (section: string) (values: Map<string, string>) : byte[] =
        let payload : ConfigSection = {
            Section   = section
            Values    = values
            Timestamp = DateTimeOffset.UtcNow.ToString("o")
        }
        JsonSerializer.SerializeToUtf8Bytes(payload)

    /// Deserialise a JSON payload into a ConfigChange.
    let private deserialise (key: string) (raw: string) : Result<ConfigChange, string> =
        try
            let section = key.Split('/') |> Array.last
            use doc     = JsonDocument.Parse(raw)
            let root    = doc.RootElement
            let values  =
                match root.TryGetProperty("values") with
                | (true, vp) ->
                    [ for prop in vp.EnumerateObject() -> (prop.Name, prop.Value.GetString()) ]
                    |> Map.ofList
                | _ -> Map.empty
            let src     =
                match root.TryGetProperty("source") with
                | (true, sp) -> sp.GetString()
                | _          -> "unknown"
            Ok { Section   = section
                 NewValues = values
                 Source    = src
                 Timestamp = DateTimeOffset.UtcNow }
        with ex ->
            Error (sprintf "ConfigBridge.deserialise failed for key '%s': %s" key ex.Message)

    // -----------------------------------------------------------------------
    // Simulated in-process pub/sub (used when ZENOH_USE_NATIVE is not set)
    // -----------------------------------------------------------------------

    /// In-memory topic store for simulated mode.
    let private simulatedStore = System.Collections.Concurrent.ConcurrentDictionary<string, string>()

    let private simulatedPublish (section: string) (payload: byte[]) : ConfigPublishResult =
        let key   = keyFor section
        let json  = Encoding.UTF8.GetString(payload)
        simulatedStore.[key] <- json
        eprintfn "[ConfigBridge/SIM] published key=%s bytes=%d" key payload.Length
        ConfigPublishResult.Simulated section

    let private simulatedPoll (keyPattern: string) : (string * string) list =
        [ for kv in simulatedStore do
            if kv.Key.StartsWith(keyPattern.TrimEnd('*').TrimEnd('/')) then
                yield (kv.Key, kv.Value) ]

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Publishes a single configuration section to Zenoh.
    /// Returns ConfigPublishResult indicating success, simulation, or failure.
    let publishConfig (handle: nativeint) (section: string) (values: Map<string, string>) : ConfigPublishResult =
        if section |> String.IsNullOrWhiteSpace then
            ConfigPublishResult.Failed (section, "Section name must not be empty")
        else
            let payload = serialise section values
            if useNative () && handle <> nativeint 0 then
                match ZenohFfiBridge.publish handle (keyFor section) payload with
                | Ok ()    ->
                    eprintfn "[ConfigBridge] published key=%s bytes=%d" (keyFor section) payload.Length
                    ConfigPublishResult.Published (section, payload.Length)
                | Error e  ->
                    ConfigPublishResult.Failed (section, e.Message)
            else
                simulatedPublish section payload

    /// Subscribes to config-change messages for the given section (or all if "*").
    /// `callback` is invoked for each received change.
    /// Returns a cleanup action (call to unsubscribe).
    let subscribeConfig (handle: nativeint) (section: string) (callback: ConfigChange -> unit) : unit -> unit =
        let keyExpr = keyFor (if section = "*" then "**" else section)

        if useNative () && handle <> nativeint 0 then
            let subHandle = ZenohFfiBridge.subscribe handle keyExpr
            match subHandle with
            | Ok sub ->
                // Polling loop on a background thread
                let cts = new System.Threading.CancellationTokenSource()
                let _task =
                    System.Threading.Tasks.Task.Run(fun () ->
                        while not cts.Token.IsCancellationRequested do
                            match ZenohFfiBridge.poll sub 10 with
                            | Ok messages ->
                                for sample in messages do
                                    let payload = System.Text.Encoding.UTF8.GetString(sample.Payload)
                                    match deserialise sample.KeyExpr payload with
                                    | Ok change  -> callback change
                                    | Error e    -> eprintfn "[ConfigBridge] deserialise error: %s" e
                            | Error e ->
                                eprintfn "[ConfigBridge] poll error: %s" e.Message
                            System.Threading.Thread.Sleep(500)
                    , cts.Token)
                fun () ->
                    cts.Cancel()
                    ZenohFfiBridge.unsubscribe sub
            | Error e ->
                eprintfn "[ConfigBridge] subscribe failed: %s" e.Message
                fun () -> ()
        else
            // Simulated: poll the in-memory store
            let prefix = keyFor (if section = "*" then "" else section)
            let cts = new System.Threading.CancellationTokenSource()
            let _task =
                System.Threading.Tasks.Task.Run(fun () ->
                    while not cts.Token.IsCancellationRequested do
                        for (key, json) in simulatedPoll prefix do
                            match deserialise key json with
                            | Ok change -> callback change
                            | Error e   -> eprintfn "[ConfigBridge/SIM] deserialise error: %s" e
                        System.Threading.Thread.Sleep(500)
                , cts.Token)
            fun () -> cts.Cancel()

    /// Synchronises all sections in `configMap` to Zenoh in one call.
    /// Returns a list of per-section publish results.
    let syncConfigs (handle: nativeint) (configMap: Map<string, Map<string, string>>) : ConfigPublishResult list =
        [ for KeyValue(section, values) in configMap ->
            publishConfig handle section values ]

    /// Registers `callback` to be invoked whenever any config section changes.
    /// Convenience wrapper over `subscribeConfig` with wildcard selector.
    let onConfigChange (handle: nativeint) (callback: ConfigChange -> unit) : unit -> unit =
        subscribeConfig handle "*" callback
