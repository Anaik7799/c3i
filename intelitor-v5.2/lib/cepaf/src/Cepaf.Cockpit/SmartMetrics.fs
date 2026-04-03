namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain

// =============================================================================
// SMART METRICS ENGINE
// =============================================================================
// Ported from: lib/indrajaal/cockpit/prajna/smart_metrics.ex
// Compliance: SC-HMI-002, SC-HMI-003
// =============================================================================

module SmartMetrics =

    type MetricsMsg =
        | Update of Id: string * Value: float * Unit: string
        | Get of Id: string * AsyncReplyChannel<SmartMetric option>
        | GetAll of AsyncReplyChannel<Map<string, SmartMetric>>
        | PruneStale of TimeoutSeconds: int
        | GetAnomalies of AsyncReplyChannel<SmartMetric list>

    type MetricsAgent() =
        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop (metrics: Map<string, SmartMetric>) = async {
                try
                    let! msg = inbox.Receive()
                    match msg with
                    | Update (id, value, unit) ->
                        let newMetric =
                            match metrics.TryFind id with
                            | Some existing -> Domain.updateMetric existing value
                            | None -> SmartMetric.Create(id, unit, value)
                        
                        return! loop (metrics.Add(id, newMetric))

                    | Get (id, reply) ->
                        reply.Reply(metrics.TryFind id)
                        return! loop metrics

                    | GetAll reply ->
                        reply.Reply(metrics)
                        return! loop metrics

                    | PruneStale timeout ->
                        let fresh = metrics |> Map.filter (fun _ m -> not (Domain.isStale m timeout))
                        return! loop fresh

                    | GetAnomalies reply ->
                        let anomalies = 
                            metrics 
                            |> Map.values 
                            |> Seq.filter (fun m -> m.Level = Warning || m.Level = Critical)
                            |> Seq.toList
                        reply.Reply(anomalies)
                        return! loop metrics

                with ex ->
                    printfn "🔴 METRICS AGENT CRASHED: %s" ex.Message
                    // Restart with last known state or empty if critical
                    return! loop metrics
            }
            loop Map.empty
        )

        member this.Update(id: string, value: float, unit: string) =
            agent.Post(Update(id, value, unit))

        member this.Get(id: string) =
            agent.PostAndAsyncReply(fun reply -> Get(id, reply))

        member this.GetAll() =
            agent.PostAndAsyncReply(fun reply -> GetAll(reply))

        member this.PruneStale(timeoutSeconds: int) =
            agent.Post(PruneStale(timeoutSeconds))

        member this.GetAnomalies() =
            agent.PostAndAsyncReply(fun reply -> GetAnomalies(reply))
