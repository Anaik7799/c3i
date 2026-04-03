namespace Cepaf.AI

open Cepaf.Bio
open System

/// High-Level Intelligence Services for the Cockpit
/// Synchronized with Elixir PRAJNA logic
module Intelligence =
    
    let private getClient () =
        let config = Config.load()
        new OpenRouterClient(config)

    /// Generate a narrative explanation for a Holon's state
    /// Uses same prompt pattern as Elixir Spine
    let explainStateAsync (holon: VitalSigns) : Async<Result<string, string>> =
        async {
            let client = getClient()
            let context = "system_observer"
            let prompt = sprintf "Analyze system signal: Node %A { Health: %.2f, Stress: %.2f, Intent: '%s' }. Recommend Action." 
                            holon.Id holon.HealthIndex holon.StressIndex holon.Intent
            
            let! result = client.ChatAsync(prompt, context) |> Async.AwaitTask
            return result
        }

    /// Analyze a Vetoed Command to explain WHY it was unsafe
    let explainVetoAsync (command: string) (reason: string) : Async<Result<string, string>> =
        async {
            let client = getClient()
            let context = "safety_officer"
            let prompt = sprintf "Analyze safety veto: Command '%s' was blocked by Simplex Kernel. Reason: '%s'. Explain risks and suggest safe alternative." 
                            command reason
            
            let! result = client.ChatAsync(prompt, context) |> Async.AwaitTask
            return result
        }