namespace Cepaf.Podman.Transactions

open System
open System.Collections.Generic

// L3 Cortex Saga Monitor
// Observes Sagas via Zenoh (mocked here via internal state for simplicity)
// and ensures L0/L1 consistency.

type SagaState = 
    | Pending
    | Committed
    | RolledBack
    | Failed

type Saga = {
    Id: Guid
    Name: string
    Status: SagaState
    StartTime: DateTime
}

type SagaMonitor() =
    let sagas = new Dictionary<Guid, Saga>()

    member this.RegisterSaga(id: Guid, name: string) =
        let saga = { Id = id; Name = name; Status = Pending; StartTime = DateTime.UtcNow }
        sagas.Add(id, saga)
        printfn "[Cortex] Monitoring Saga: %s (%A)" name id
        // L6: Publish to Zenoh (Mocked)
        printfn "[Zenoh] PUB indrajaal/saga/status {'id': '%A', 'status': 'Pending'}" id

    member this.UpdateStatus(id: Guid, status: SagaState) =
        if sagas.ContainsKey(id) then
            let saga = sagas.[id]
            sagas.[id] <- { saga with Status = status }
            printfn "[Cortex] Saga Update: %s -> %A" saga.Name status
            // L6: Publish to Zenoh (Mocked)
            printfn "[Zenoh] PUB indrajaal/saga/status {'id': '%A', 'status': '%A'}" id status

    member this.DetectAnomalies() =
        // L3: Cognitive Anomaly Detection
        // Check for Sagas stuck in Pending for > 5 minutes
        let now = DateTime.UtcNow
        let stuckSagas = 
            sagas.Values 
            |> Seq.filter (fun s -> s.Status = Pending && (now - s.StartTime).TotalMinutes > 5.0)
            |> Seq.toList
        
        if not (List.isEmpty stuckSagas) then
            printfn "⚠️ [Cortex] ANOMALY DETECTED: %d stuck sagas" stuckSagas.Length
            // In real impl, would trigger alert via Zenoh
        else
            printfn "[Cortex] No anomalies detected."

    member this.GetActiveSagas() =
        sagas.Values |> Seq.filter (fun s -> s.Status = Pending)