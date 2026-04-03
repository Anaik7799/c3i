module Cepaf.Observability.FractalProfiler

open System
open System.Diagnostics

let profile (name: string) (action: unit -> 'a) : 'a =
    let sw = Stopwatch.StartNew()
    let result = action()
    sw.Stop()
    
    // Emit to Console (Fractal Logger will pick this up)
    let durationNs = sw.ElapsedTicks * 1_000_000_000L / Stopwatch.Frequency
    printfn "⏱️ [PROFILER] %s: %d ns" name durationNs
    
    // In real implementation: Emit to Zenoh
    result
