namespace Indrajaal.Cortex

open System
open System.Threading
open Microsoft.Extensions.Logging

// Upgrade 4: The Metabolic Throttle (P2)
// Context: Universe 'throttle'

type TokenBucket(capacity: int, refillRate: int, logger: ILogger<TokenBucket> option) =
    
    let mutable tokens = float capacity
    let mutable lastRefill = DateTime.UtcNow
    let lockObj = obj()

    new(capacity: int, refillRate: int) = TokenBucket(capacity, refillRate, None)

    member this.Consume(cost: int) : bool =
        lock lockObj (fun () ->
            let now = DateTime.UtcNow
            let delta = (now - lastRefill).TotalSeconds
            
            // Refill
            tokens <- min (float capacity) (tokens + (delta * float refillRate))
            lastRefill <- now

            let success = 
                if tokens >= float cost then
                    tokens <- tokens - float cost
                    true
                else
                    false
            
            // Telemetry (Log every consumption if logger present, or on failure)
            match logger with
            | Some log -> 
                if not success then
                    log.LogWarning("🔥 Metabolic Throttle: Request for {Cost} tokens DENIED. Level: {Level:F1}/{Capacity}", cost, tokens, capacity)
            | None -> ()

            success
        )

    member this.GetLevel() =
        lock lockObj (fun () -> tokens)