namespace Cepaf.Podman.Cortex

open System
open System.Threading.Tasks
open Cepaf.Podman.Safety
open Cepaf.Podman.Transactions
open Cepaf.Podman.Api
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Dynamic Swarm Scaler with Metabolic Integration - SC-CLU-006, SC-ECON-002
type CortexEngine(client: PodmanClient) =
    let sagaMonitor = new SagaMonitor()
    let logger = "CORTEX"
    let runnerPrefix = "indrajaal-ml-runner-"
    let minRunners = 1
    let maxRunners = 100

    // Internal state
    let mutable currentRunnerCount = 1
    let mutable lastScaleAt = DateTime.UtcNow
    let mutable synthesizedAntibodies = Set.empty<string>

    /// Get current runners from Podman
    let getRunningRunners () = async {
        let filters = { Containers.ListFilters.empty with Name = [runnerPrefix] }
        match! Containers.list client filters with
        | Ok containers -> 
            return containers |> List.filter (fun c -> c.State = "running") |> List.length
        | Error _ -> return 0
    }

    /// Scale up the swarm
    let scaleUp () = async {
        if currentRunnerCount < maxRunners then
            let nextId = currentRunnerCount + 1
            let name = sprintf "%s%d" runnerPrefix nextId
            printfn "[%s] SATURATING: Creating runner %s (Target: 80%%)" logger name
            currentRunnerCount <- nextId
            lastScaleAt <- DateTime.UtcNow
            return true
        else
            return false
    }

    /// Scale down the swarm
    let scaleDown () = async {
        if currentRunnerCount > minRunners then
            let name = sprintf "%s%d" runnerPrefix currentRunnerCount
            printfn "[%s] SCALING DOWN: Removing runner %s" logger name
            currentRunnerCount <- currentRunnerCount - 1
            lastScaleAt <- DateTime.UtcNow
            return true
        else
            return false
    }

    /// Synthesize antibodies for recurring anomalies (SC-BIO-EXT-004)
    member this.SynthesizeAntibody(patternId: string) =
        if not (synthesizedAntibodies.Contains patternId) then
            printfn "🧬 [%s] ANTIBODY SYNTHESIZED: Blocking pattern %s" logger patternId
            synthesizedAntibodies <- synthesizedAntibodies.Add patternId
            true
        else
            false

    /// Analyze system load and make scaling decisions with Metabolic feedback
    member this.AnalyzeSystem(cognitiveLoad: float, energyBalance: float) = async {
        printfn "[%s] Analyzing Swarm Topology (Load: %.2f, Energy: %.2f)..." logger cognitiveLoad energyBalance
        
        let now = DateTime.UtcNow
        
        // Metabolic Adjustment: Target 80% saturation (SC-ECON-006)
        let scaleUpThreshold = 
            if energyBalance < 100.0 then 0.98 // Critical starvation
            else 0.40 // Aggressive evolution: scale up if load > 40% to reach 80% saturation target

        // SC-SING-007: Bypass cooldown if significantly below saturation target
        let forceScale = cognitiveLoad > 0.5 && currentRunnerCount < 20

        if forceScale || (now - lastScaleAt).TotalSeconds > 2.0 then
            if cognitiveLoad > scaleUpThreshold then
                let! _ = scaleUp()
                ()
            elif cognitiveLoad < 0.1 then
                let! _ = scaleDown()
                ()
        
        // Check Sagas
        sagaMonitor.DetectAnomalies()
    }

    member this.RunLoop() =
        async {
            while true do
                // Simulate receiving load and energy from Zenoh/Sentinel/Economic Substrate
                let rng = Random()
                let simulatedLoad = rng.NextDouble()
                let simulatedEnergy = rng.NextDouble() * 1000.0
                
                let! _ = this.AnalyzeSystem(simulatedLoad, simulatedEnergy)
                do! Async.Sleep(10000)
        }
