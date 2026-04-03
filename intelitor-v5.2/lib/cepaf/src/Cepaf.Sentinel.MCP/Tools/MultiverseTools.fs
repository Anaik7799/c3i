namespace Cepaf.Sentinel.MCP.Tools

open System
open System.Text.Json
open Cepaf.Sentinel.MCP.Protocol
open System.Diagnostics

/// MCP tool definitions for Multiverse and Unified Checkpoint operations.
///
/// Integrated with Zenoh control plane signals.
module MultiverseTools =

    // ═══════════════════════════════════════════════════════════════════
    // SCHEMA HELPERS
    // ═══════════════════════════════════════════════════════════════════

    let private mkSchema (props: (string * obj) list) (required: string list) : obj =
        {| ``type`` = "object"
           properties = props |> Map.ofList
           required = required |}

    let private stringProp desc : obj =
        {| ``type`` = "string"; description = desc |} :> obj

    let private enumProp desc (values: string list) : obj =
        {| ``type`` = "string"; description = desc; ``enum`` = values |} :> obj

    // ═══════════════════════════════════════════════════════════════════
    // TOOL DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════

    let toolDefinitions : McpProtocol.ToolDefinition list = [
        { Name = "multiverse_op"
          Description = "Manage shadow universes: fork, verify, promote, prune, or list."
          InputSchema = mkSchema
            [ "action", enumProp "Multiverse action" [ "fork"; "verify"; "promote"; "prune"; "list" ]
              "name", stringProp "Universe name (required for all except list)" ]
            [ "action" ] }

        { Name = "checkpoint_op"
          Description = "Manage unified checkpoints: capture full or quick snapshots."
          InputSchema = mkSchema
            [ "action", enumProp "Checkpoint action" [ "full"; "quick"; "verify" ]
              "archive_path", stringProp "Path to archive (for verify only)" ]
            [ "action" ] }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    type MultiverseState = {
        mutable LastOperation: string
    }

    let createState () = { LastOperation = "none" }

    // ═══════════════════════════════════════════════════════════════════
    // HANDLERS
    // ═══════════════════════════════════════════════════════════════════

    let private execFsi script args =
        let psi = new ProcessStartInfo("dotnet", sprintf "fsi %s %s" script args)
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        try
            let p = Process.Start(psi)
            let stdout = p.StandardOutput.ReadToEnd()
            let stderr = p.StandardError.ReadToEnd()
            p.WaitForExit()
            {| exit_code = p.ExitCode; stdout = stdout; stderr = stderr |}
        with ex ->
            {| exit_code = -1; stdout = ""; stderr = ex.Message |}

    let private handleMultiverse (state: MultiverseState) (args: JsonElement option) (id: JsonElement option) : string =
        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        let name = McpProtocol.getArgOpt "name" args |> Option.defaultValue ""
        
        match action with
        | "list" ->
            let res = execFsi "sa-multiverse.fsx" "list"
            McpProtocol.toolResult id (JsonSerializer.Serialize(res))
        | "fork" | "verify" | "promote" | "prune" ->
            if String.IsNullOrEmpty(name) then
                McpProtocol.toolError id "Name is required for this action"
            else
                let arg = sprintf "%s %s" action name
                let res = execFsi "sa-multiverse.fsx" arg
                McpProtocol.toolResult id (JsonSerializer.Serialize(res))
        | _ ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s" action)

    let private handleCheckpoint (state: MultiverseState) (args: JsonElement option) (id: JsonElement option) : string =
        let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
        let path = McpProtocol.getArgOpt "archive_path" args |> Option.defaultValue ""
        
        match action with
        | "full" ->
            let res = execFsi "scripts/infrastructure/mesh-checkpoint-unified.fsx" "--full"
            McpProtocol.toolResult id (JsonSerializer.Serialize(res))
        | "quick" ->
            let res = execFsi "scripts/infrastructure/mesh-checkpoint-unified.fsx" "--create"
            McpProtocol.toolResult id (JsonSerializer.Serialize(res))
        | "verify" ->
            if String.IsNullOrEmpty(path) then
                McpProtocol.toolError id "archive_path is required for verify"
            else
                let arg = sprintf "--verify-shadow %s" path
                let res = execFsi "scripts/infrastructure/mesh-checkpoint-unified.fsx" arg
                McpProtocol.toolResult id (JsonSerializer.Serialize(res))
        | _ ->
            McpProtocol.invalidParams id (sprintf "Unknown action: %s" action)

    let dispatch (state: MultiverseState) (toolName: string) (args: JsonElement option) (id: JsonElement option) : string option =
        match toolName with
        | "multiverse_op" -> Some (handleMultiverse state args id)
        | "checkpoint_op" -> Some (handleCheckpoint state args id)
        | _ -> None
