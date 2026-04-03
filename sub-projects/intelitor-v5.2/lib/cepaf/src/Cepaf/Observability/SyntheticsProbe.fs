module Cepaf.Observability.SyntheticsProbe

open System
open System.Net.Http
open System.Diagnostics
open System.Threading

type ProbeResult = {
    Url: string
    Status: int
    LatencyMs: int64
    Timestamp: DateTimeOffset
}

let runProbe (url: string) (intervalMs: int) =
    async {
        use client = new HttpClient()
        let sw = Stopwatch()
        let mutable history = []
        let mutable currentInterval = intervalMs
        
        while true do
            try
                sw.Restart()
                let! response = client.GetAsync(url) |> Async.AwaitTask
                sw.Stop()
                
                let latency = sw.ElapsedMilliseconds
                history <- (latency :: history) |> List.truncate 10
                
                // Adaptive Sampling: Calculate Variance
                let variance = 
                    if history.Length > 1 then
                        let avg = history |> List.averageBy float
                        history |> List.sumBy (fun x -> (float x - avg) ** 2.0) / float history.Length
                    else 0.0
                
                currentInterval <- if variance > 100.0 then intervalMs / 2 else intervalMs

                let result = {
                    Url = url
                    Status = int response.StatusCode
                    LatencyMs = latency
                    Timestamp = DateTimeOffset.UtcNow
                }
                
                printfn "🔬 [SYNTHETICS] %s: %d (%dms) Var: %.2f Int: %dms" url result.Status latency variance currentInterval
                // In real implementation: Emit to Zenoh
            with
            | ex -> 
                printfn "💔 [SYNTHETICS] Probe Failed: %s" ex.Message
                
            do! Async.Sleep(currentInterval)
    }
