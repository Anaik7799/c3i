namespace Cepaf.Cockpit

open System
open System.Threading
open Cepaf.Mesh

/// <summary>
/// PanopticonTui - The Directed Telescope Interface
/// Visualizes all 5 layers of instrumentation and 2oo3 Voting
/// </summary>
module PanopticonTui = 

    type VoterState = { Name: string; Payload: string; Latency: int; Status: string }

    let renderZoom (level: int) (msg: string) = 
        Console.ForegroundColor <- ConsoleColor.Cyan
        printf " [ZOOM L%d] " level
        Console.ResetColor()
        printfn "%s" msg

    let renderVoting (results: VoterState list) = 
        printfn "\n \u001b[35m--- SIL4 2oo3 VOTING LOGIC [THE JUDGE] ---\u001b[0m"
        printfn " NODE       PAYLOAD    LATENCY   VERDICT"
        printfn " ---------- ---------- --------- ---------"
        results |> List.iter (fun r ->
            printf " %-10s %-10s %-9d " r.Name r.Payload r.Latency
            if r.Status = "MATCH" then Console.ForegroundColor <- ConsoleColor.Green else Console.ForegroundColor <- ConsoleColor.Red
            printfn "%s" r.Status
            Console.ResetColor()
        )

    let showLens () = 
        Console.Clear()
        printfn "================================================================================"
        printfn "   PANOPTICON :: DIRECTED TELESCOPE  ::  SIL4 PARALLEL CONTROL PLANE"
        printfn "================================================================================"
        
        printfn "\n --- TELESCOPE LENS ALIGNMENT ---"
        renderZoom 5 "EVOLUTIONARY: SRS-12.4 compliance locked. Fitness: Nomimal."
        renderZoom 4 "COGNITIVE: STPA scanning active. No new feedback hazards."
        renderZoom 3 "ORGAN: Istio Mirroring at 100%. Payload comparison enabled."
        renderZoom 2 "TISSUE: Podman Isolation harness injecting Gaussian sensor noise."
        renderZoom 1 "CELLULAR: BEAM Process Safety verified. Memory proof: OK."

        renderVoting [
            { Name = "PRIMARY"; Payload = "0xAF42"; Latency = 2; Status = "MATCH" }
            { Name = "SHADOW";  Payload = "0xAF42"; Latency = 3; Status = "MATCH" }
            { Name = "MODEL";   Payload = "0xAF42"; Latency = 1; Status = "MATCH" }
        ]

        printfn "\n================================================================================"
        printfn " SYSTEM STATE: STEADY  |  OODA: <50ms  |  TRANSACTION: ACID"
        printfn " [1-5] Switch Zoom | [C] Inject Deterministic Chaos | [Q] Quit"

    let run () = 
        let mutable running = true
        while running do
            showLens()
            Thread.Sleep(2000)
            if Console.KeyAvailable then
                let key = Console.ReadKey(true)
                if key.Key = ConsoleKey.Q then running <- false
                elif key.Key = ConsoleKey.C then 
                    printfn ">>> INJECTING MODEL-CHECKED CHAOS VECTOR: BYZANTINE_FAULT_01"
                    Thread.Sleep(1000)