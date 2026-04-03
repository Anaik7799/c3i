namespace Cepaf.Smriti.CLI

open System
open System.CommandLine
open System.CommandLine.Invocation
open Cepaf.Smriti.Domain

// Run 2: CLI Expansion - The Full 100% Verb Set

module AdvancedCLI =

    // --- Sub-Command Builders ---

    let buildScaffoldCommand (dbPath: string) =
        let cmd = new Command("sa-scaffold", "Create new components")
        
        // sa-scaffold run <template> --params <json>
        let run = new Command("run", "Execute a template")
        let argTemplate = new Argument<string>("template", "Template Name")
        let optParams = new Option<string>("--params", "JSON Parameters")
        run.AddArgument(argTemplate)
        run.AddOption(optParams)
        
        run.SetHandler(fun (t: string) (p: string) ->
            printfn "Scaffolding %s with params %s" t p
            // Scaffolder.execute ...
        , argTemplate, optParams)
        
        cmd.AddCommand(run)
        cmd

    let buildDocsCommand (dbPath: string) =
        let cmd = new Command("sa-docs", "Read and search documentation")
        
        // sa-docs search <query>
        let search = new Command("search", "Search across all docs")
        let argQuery = new Argument<string>("query", "Search term")
        search.AddArgument(argQuery)
        
        search.SetHandler(fun (q: string) ->
            printfn "Searching docs for: %s" q
            // TechDocs.search ...
        , argQuery)
        
        cmd.AddCommand(search)
        cmd

    let buildApiCommand (dbPath: string) =
        let cmd = new Command("sa-api", "Inspect API definitions")
        
        // sa-api show <ref>
        let show = new Command("show", "Show API Spec")
        let argRef = new Argument<string>("ref", "API Entity Reference")
        show.AddArgument(argRef)
        
        show.SetHandler(fun (r: string) ->
            printfn "Fetching API Definition for: %s" r
            // ApiExplorer.render ...
        , argRef)
        
        cmd.AddCommand(show)
        cmd

    let buildK8sCommand (dbPath: string) =
        let cmd = new Command("sa-k8s", "Kubernetes Operations")
        
        // sa-k8s pods --entity <ref>
        let pods = new Command("pods", "List pods for an entity")
        let optEntity = new Option<string>("--entity", "Entity Reference")
        pods.AddOption(optEntity)
        
        pods.SetHandler(fun (e: string) ->
            printfn "Listing pods for entity: %s" e
            // KubernetesBridge.getPods ...
        , optEntity)
        
        cmd.AddCommand(pods)
        cmd

    let buildCostCommand (dbPath: string) =
        let cmd = new Command("sa-cost", "Cost Insights")
        
        // sa-cost show <ref>
        let show = new Command("show", "Show cost for entity")
        let argRef = new Argument<string>("ref", "Entity Reference")
        show.AddArgument(argRef)
        
        show.SetHandler(fun (r: string) ->
            printfn "Calculating costs for: %s" r
            // CostInsights.calculate ...
        , argRef)
        
        cmd.AddCommand(show)
        cmd

    // --- Main Composition ---

    let attachToRoot (root: Command) (dbPath: string) =
        root.AddCommand(buildScaffoldCommand dbPath)
        root.AddCommand(buildDocsCommand dbPath)
        root.AddCommand(buildApiCommand dbPath)
        root.AddCommand(buildK8sCommand dbPath)
        root.AddCommand(buildCostCommand dbPath)
