module Cepaf.Mesh.HeartbeatMonitor

open System
open System.IO
open System.Threading

type PulseStatus = 
    | Healthy 
    | Arrhythmia of latencyMs: float 
    | Asystole of latencyMs: float

let checkKmsPulse (kmsPath: string) (thresholdMs: float) =
    try
        if File.Exists(kmsPath) then
            let lastWrite = File.GetLastWriteTimeUtc(kmsPath)
            let latency = (DateTime.UtcNow - lastWrite).TotalMilliseconds
            
            if latency > (thresholdMs * 3.0) then
                Asystole latency
            elif latency > thresholdMs then
                Arrhythmia latency
            else
                Healthy
        else
            Asystole Double.MaxValue // File missing = Dead
    with
    | ex -> Asystole Double.MaxValue // IO Error = Dead

let rec monitorLoop (kmsPath: string) (interval: int) =
    async {
        let status = checkKmsPulse kmsPath 30000.0 // 30s threshold
        
        match status with
        | Healthy -> 
            // Silent is good (Sinus Rhythm)
            () 
        | Arrhythmia ms -> 
            printfn "⚠️ [CORTEX] KMS Arrhythmia: %.0fms" ms
        | Asystole ms -> 
            printfn "💔 [CORTEX] KMS ASYSTOLE: %.0fms" ms
            
        do! Async.Sleep(interval)
        return! monitorLoop kmsPath interval
    }
