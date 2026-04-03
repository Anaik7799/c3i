#!/usr/bin/env -S dotnet fsi
// kms-pulse.fsx - Biomorphic State Pacemaker
// Version: 1.0.0
// Target: SQLite KMS Substrate

open System
open System.IO
open System.Threading

let kmsPath = "data/kms/core.db"
let pulseInterval = 30000 // 30s

let rec pacemaker () =
    async {
        try
            if File.Exists(kmsPath) then
                // 1. Metabolic Touch (Update MTime)
                File.SetLastWriteTimeUtc(kmsPath, DateTime.UtcNow)
                
                // 2. Telemetry Emission
                printfn "🫀 [STATE-PLANE] Pulse Registered. MTime: %A" DateTime.UtcNow
            else
                printfn "💔 [STATE-PLANE] ARRHYTHMIA: KMS Core Missing!"
        with
        | ex -> printfn "💔 [STATE-PLANE] FIBRILLATION: %s" ex.Message

        do! Async.Sleep(pulseInterval)
        return! pacemaker()
    }

printfn ">>> [KMS-PULSE] PACEMAKER ACTIVE. TARGET: %s" kmsPath
Async.RunSynchronously(pacemaker())
