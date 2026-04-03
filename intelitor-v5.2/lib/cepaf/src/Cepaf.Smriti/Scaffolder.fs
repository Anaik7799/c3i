namespace Cepaf.Smriti

open System
open System.IO
open System.Collections.Generic
open Scriban
open Cepaf.Smriti.Domain

// Run 5: Expansion Hardening - Scaffolding Engine

module Scaffolder =

    type TemplateAction =
        | FetchTemplate of url: string * target: string
        | PublishGithub of repo: string
        | CatalogRegister of url: string
        | Log of message: string

    // Parse the 'steps' from the Template Entity
    let private parseSteps (spec: Map<string, obj>) : TemplateAction list =
        match spec.TryFind "steps" with
        | Some (:? List<obj> as steps) ->
            steps |> Seq.map (fun s ->
                let stepMap = s :?> Dictionary<obj, obj>
                let action = string stepMap["action"]
                match action with
                | "fetch:template" -> 
                    let input = stepMap["input"] :?> Dictionary<obj, obj>
                    FetchTemplate (string input["url"], "./output")
                | "debug:log" ->
                    let input = stepMap["input"] :?> Dictionary<obj, obj>
                    Log (string input["message"])
                | _ -> Log (sprintf "Unknown action: %s" action)
            ) |> Seq.toList
        | _ -> []

    // Render a single file using Scriban
    let private renderFile (templatePath: string) (targetPath: string) (model: obj) =
        let templateContent = File.ReadAllText(templatePath)
        let template = Template.Parse(templateContent)
        let result = template.Render(model)
        File.WriteAllText(targetPath, result)

    // Execute the scaffolding pipeline
    let executeTemplate (template: CatalogEntity) (parameters: Map<string, obj>) =
        printfn "[Scaffolder] Starting template: %s" template.Metadata.Name
        
        // 1. Extract Steps
        let steps = 
            match template.Spec with
            | Template props -> parseSteps props
            | _ -> []

        // 2. Execute Steps
        steps |> List.iter (fun step ->
            match step with
            | Log msg -> printfn "[Step] %s" msg
            | FetchTemplate (url, target) ->
                printfn "[Step] Fetching %s -> %s" url target
                // Mock implementation of fetch/render loop
                // In reality: git clone -> recurse files -> renderFile -> output
            | _ -> printfn "[Step] Skipped implementation"
        )

        printfn "[Scaffolder] Complete."
