// =============================================================================
// ZenohService.fs - High-Level Nervous System Facade
// =============================================================================
// Phase 2: Connectivity (Connecting the Brain to the Body)
// STAMP: SC-ZEN-001, SC-ZEN-002, SC-ZEN-003
// =============================================================================

namespace Cepaf.Cockpit.Zenoh.Session

open System
open System.Threading.Tasks
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Session
open Cepaf.Cockpit.Domain

/// Service interface for the Nervous System
type IZenohService =
    inherit IDisposable
    abstract member StartAsync: unit -> Task<unit>
    abstract member PublishTelemetryAsync: nodeId: string -> metric: SmartMetric -> Task<unit>
    abstract member PublishCommandAsync: targetId: string -> command: CommandRecord -> Task<unit>
    abstract member SubscribeToTelemetry: nodeId: string -> (SmartMetric -> unit) -> Task<IDisposable>
    abstract member SubscribeToCommands: nodeId: string -> (CommandRecord -> unit) -> Task<IDisposable>
    abstract member IsConnected: bool

/// Implementation of the Nervous System Facade
type ZenohService(nodeId: string, lifecycle: ZenohLifecycle) =
    
    // SC-ZEN-003: Dead Man's Switch / Heartbeat
    // Heartbeat logic is handled by ZenohLifecycle's health check, but we can expose it here.

    member val Lifecycle = lifecycle

    interface IZenohService with
        member this.IsConnected = lifecycle.IsOperational

        member this.StartAsync() =
            task {
                let! result = lifecycle.InitializeAsync()
                match result with
                | Ok _ -> printfn "[ZenohService] Started successfully for node %s" nodeId
                | Error e -> printfn "[ZenohService] Failed to start: %s" e.Message
            }

        member this.PublishTelemetryAsync (nodeId: string) (metric: SmartMetric) =
            task {
                match lifecycle.Session with
                | Some session ->
                    // SC-ZEN-002: Telemetry streams must be read-only for Cockpit (Ingest only typically)
                    // But here we might be simulating a node or the Cockpit publishing its own stats.
                    // Topic: indrajaal/telemetry/{node_id}/{metric_name}
                    let topic = sprintf "indrajaal/telemetry/%s/%s" nodeId metric.Label
                    // Serialization would happen here (using JSON/MsgPack)
                    match ZenohSerializer.serializeToString metric with
                    | Ok payload ->
                        // Actually, let's use the session to create a publisher and send.
                        // Ideally we cache this.
                        let pubResult = SafePublisher.Create(session, PublisherConfig.create topic)
                        match pubResult with
                        | Ok p ->
                            try
                                let! _ = p.PutStringAsync(payload)
                                ()
                            finally
                                (p :> IDisposable).Dispose()
                        | Error _ -> ()
                    | Error e -> printfn "[ZenohService] Telemetry serialization error: %s" e.Message
                | None -> ()
            }

        member this.PublishCommandAsync (targetId: string) (command: CommandRecord) =
            task {
                match lifecycle.Session with
                | Some session ->
                    // SC-ZEN-001: Command messages MUST be cryptographically signed.
                    // Signing logic would be injected here.
                    let topic = sprintf "indrajaal/command/%s" targetId
                    
                    match ZenohSerializer.serializeToString command with
                    | Ok payload ->
                        let pubResult = SafePublisher.Create(session, PublisherConfig.create topic)
                        match pubResult with
                        | Ok p ->
                            try
                                let! _ = p.PutStringAsync(payload)
                                ()
                            finally
                                (p :> IDisposable).Dispose()
                        | Error _ -> ()
                    | Error e -> printfn "[ZenohService] Command serialization error: %s" e.Message
                | None -> ()
            }

        member this.SubscribeToTelemetry (nodeId: string) (handler: SmartMetric -> unit) =
            task {
                match lifecycle.Session with
                | Some session ->
                    let topic = sprintf "indrajaal/telemetry/%s/**" nodeId
                    let callback (sample: ZenohSample) =
                        match ZenohSerializer.deserializeFromString<SmartMetric> (ZenohSample.payloadString sample) with
                        | Ok metric -> handler metric
                        | Error e -> () // Log error
                    
                    let config = SubscriberConfig.create topic
                    let result = SafeSubscriber.Create(session, config, callback)
                    match result with
                    | Ok sub -> return sub :> IDisposable
                    | Error _ -> return { new IDisposable with member _.Dispose() = () }
                | None -> return { new IDisposable with member _.Dispose() = () }
            }

        member this.SubscribeToCommands (nodeId: string) (handler: CommandRecord -> unit) =
            task {
                // Subscribe to commands targeted at this node
                match lifecycle.Session with
                | Some session ->
                    let topic = sprintf "indrajaal/command/%s" nodeId
                    let callback (sample: ZenohSample) =
                        match ZenohSerializer.deserializeFromString<CommandRecord> (ZenohSample.payloadString sample) with
                        | Ok cmd -> handler cmd
                        | Error e -> ()
                    
                    let config = SubscriberConfig.create topic
                    let result = SafeSubscriber.Create(session, config, callback)
                    match result with
                    | Ok sub -> return sub :> IDisposable
                    | Error _ -> return { new IDisposable with member _.Dispose() = () }
                | None -> return { new IDisposable with member _.Dispose() = () }
            }

        member this.Dispose() =
            (lifecycle :> IDisposable).Dispose()

module ZenohServiceFactory =
    let create (nodeId: string) =
        let lifecycle = ZenohLifecycleFactory.create nodeId
        new ZenohService(nodeId, lifecycle)
