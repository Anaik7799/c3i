namespace Cepaf

open System.IO
open Cepaf.Rop

module Operations =

    type Node = {
        Name: string
        Dependencies: string list
    }

    type OodaAction =
        | ApplyPatch of oldStr: string * newStr: string
        | WaitAndRetry of reason: string
        | AbortPipeline of reason: string

    // OODA Orient: Identify failure patterns
    let classifyError (stderr: string) =
        if stderr.Contains("RUNN") then Some (ApplyPatch ("RUNN", "RUN"))
        elif stderr.Contains("address already in use") then Some (AbortPipeline "Port conflict")
        elif stderr.Contains("database system is starting up") then Some (WaitAndRetry "DB initializing")
        else None

    // Topological Sort for Container DAG
    let topoSort nodes =
        let mutable sorted = []
        let mutable visited = Set.empty
        let mutable visiting = Set.empty
        let mutable cycleFound = None

        let rec visit node =
            if cycleFound.IsSome then
                cycleFound.Value
            elif visiting.Contains(node.Name) then
                let cycle = DependencyCycleDetected (visiting |> Set.toList)
                cycleFound <- Some (Error cycle)
                Error cycle
            elif not (visited.Contains(node.Name)) then
                visiting <- visiting.Add(node.Name)
                let depResults =
                    node.Dependencies
                    |> List.choose (fun depName ->
                        nodes |> List.tryFind (fun n -> n.Name = depName))
                    |> List.map visit
                let hasError = depResults |> List.exists Result.isError
                if hasError then
                    match depResults |> List.tryFind Result.isError with
                    | Some err -> err
                    | None -> Error (DependencyCycleDetected [])
                else
                    visiting <- visiting.Remove(node.Name)
                    visited <- visited.Add(node.Name)
                    sorted <- node :: sorted
                    Ok ()
            else Ok ()

        let results = nodes |> List.map visit
        if results |> List.exists (function Error _ -> true | _ -> false) then
            match results |> List.tryFind Result.isError with
            | Some (Error e) -> Error e
            | _ -> Error (DependencyCycleDetected [])
        else
            Ok (List.rev sorted)

    // OODA Act: File patching
    let patchFile path (oldStr: string) (newStr: string) =
        try
            let content = File.ReadAllText(path)
            if content.Contains(oldStr) then
                File.WriteAllText(path, content.Replace(oldStr, newStr))
                Ok ()
            else
                Error (ValidationFailed("Patch", sprintf "String '%s' not found in %s" oldStr path))
        with ex ->
            Error (FileIOError(path, ex.Message))

    // Helper to bridge to AsyncResult
    let patchFileAsync path oldStr newStr : AsyncResult<unit, AppError> =
        async { return patchFile path oldStr newStr }