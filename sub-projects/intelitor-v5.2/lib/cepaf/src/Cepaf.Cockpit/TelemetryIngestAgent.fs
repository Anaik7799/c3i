namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Zenoh.Session

/// ═══════════════════════════════════════════════════════════════════════════════
/// TELEMETRY INGEST AGENT
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// WHAT: Agent responsible for subscribing to Zenoh telemetry topics and 
///       forwarding normalized data to the Orchestrator.
/// WHY: Decouples network ingestion from cognitive processing.
/// STAMP: SC-ZEN-002 (Read-Only Telemetry)
/// ═══════════════════════════════════════════════════════════════════════════════

module TelemetryIngest =

    type IngestMsg =
        | Start of IZenohService
        | Stop
        | SubscribeToNode of string
        | UnsubscribeFromNode of string

    type TelemetryIngestAgent(orchestrator: Orchestrator.OrchestratorAgent) =
        
        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop (service: IZenohService option) (subs: Map<string, IDisposable>) = async {
                let! msg = inbox.Receive()
                match msg with
                | Start svc ->
                    printfn "[TelemetryIngest] Starting ingestion service"
                    // Auto-subscribe to wildcard if supported, or wait for specific node subs
                    return! loop (Some svc) subs

                | Stop ->
                    printfn "[TelemetryIngest] Stopping ingestion"
                    subs |> Map.iter (fun _ sub -> sub.Dispose())
                    return! loop None Map.empty

                | SubscribeToNode nodeId ->
                    match service with
                    | Some svc ->
                        if subs.ContainsKey nodeId then
                            return! loop service subs
                        else
                            // Forward telemetry to Orchestrator
                            let callback metric = 
                                orchestrator.ProcessTelemetry(nodeId, metric)
                            
                            let task = svc.SubscribeToTelemetry nodeId callback
                            let! sub = Async.AwaitTask task
                            
                            printfn "[TelemetryIngest] Subscribed to node: %s" nodeId
                            return! loop service (subs.Add(nodeId, sub))
                    | None ->
                        printfn "[TelemetryIngest] Service not started, ignoring subscription for %s" nodeId
                        return! loop service subs

                | UnsubscribeFromNode nodeId ->
                    match subs.TryFind nodeId with
                    | Some sub ->
                        sub.Dispose()
                        return! loop service (subs.Remove nodeId)
                    | None ->
                        return! loop service subs
            }
            loop None Map.empty
        )

        member this.Start(service: IZenohService) = agent.Post(Start service)
        member this.Stop() = agent.Post(Stop)
        member this.MonitorNode(nodeId: string) = agent.Post(SubscribeToNode nodeId)
