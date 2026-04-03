namespace Cepaf.Bridge

open Cepaf.Bio
open Cepaf.Safety
open System
open System.Text.Json
open System.Text.Json.Serialization

/// Interop Layer for Elixir <-> F# Communication
module PortHandler =

    type CommandRequest = {
        Command: string
        TargetId: Guid
        Context: Map<string, string>
    }

    type CommandResponse = {
        Status: string // "ok" | "veto"
        Reason: string option
    }

    /// Process an incoming JSON command string from Elixir
    /// Returns a JSON response string
    let handleMessage (json: string) (systemState: Map<HolonId, VitalSigns>) : string =
        try
            let options = JsonSerializerOptions(PropertyNameCaseInsensitive = true)
            let req = JsonSerializer.Deserialize<CommandRequest>(json, options)
            
            // Invoke the Safety Kernel
            let verdict = SimplexKernel.evaluate req.Command req.TargetId systemState

            let response = 
                match verdict with
                | Approved -> { Status = "ok"; Reason = None }
                | Vetoed reason -> { Status = "veto"; Reason = Some reason }
                | Modified _ -> { Status = "ok"; Reason = Some "Plan modified for safety" }

            JsonSerializer.Serialize(response, options)
        with
        | ex -> 
            let err = { Status = "error"; Reason = Some ex.Message }
            JsonSerializer.Serialize(err)
