namespace Cepaf.Smriti.CLI

open System
open System.CommandLine
open System.CommandLine.Invocation
open Cepaf.Smriti.Domain
open Cepaf.Smriti.Ingestor
open Cepaf.Smriti.HolonMapper

// Run 1: CLI Foundation - The 'sa-catalog' Command

module CatalogCLI =

    // Helper to print entities nicely
    let private printEntity (e: CatalogEntity) =
        let kind = e.Kind.ToString().ToUpper()
        let name = e.Metadata.Name
        let owner = 
            match e.Spec with
            | Component c -> c.Owner
            | _ -> "N/A"
        printfn "[%s] %s (Owner: %s)" kind name owner

    // Command: sa-catalog list
    let listCommand (dbPath: string) =
        let cmd = new Command("list", "List all entities in the catalog")
        cmd.SetHandler(fun () ->
            // Real implementation would query SQLite via HolonMapper
            // Mocking for SIL-6 generation step
            printfn "Listing entities from %s..." dbPath
            // e.g., HolonMapper.listHolons dbPath |> List.iter printEntity
        )
        cmd

    // Command: sa-catalog show <ref>
    let showCommand (dbPath: string) =
        let cmd = new Command("show", "Show details of an entity")
        let argRef = new Argument<string>("ref", "Entity reference (e.g., component:default/name)")
        cmd.AddArgument(argRef)
        
        cmd.SetHandler(fun (ref: string) ->
            printfn "Fetching details for: %s" ref
            // HolonMapper.getHolon dbPath ref |> printEntity
        , argRef)
        cmd

    // Command: sa-catalog register <url>
    let registerCommand (dbPath: string) =
        let cmd = new Command("register", "Register a new component from a URL")
        let argUrl = new Argument<string>("url", "URL to catalog-info.yaml")
        cmd.AddArgument(argUrl)

        cmd.SetHandler(fun (url: string) ->
            printfn "Registering from: %s" url
            // Ingestor.ingestUrl url
        , argUrl)
        cmd

    // Root Command
    let buildRoot (dbPath: string) =
        let root = new Command("sa-catalog", "Manage the Software Catalog")
        root.AddCommand(listCommand dbPath)
        root.AddCommand(showCommand dbPath)
        root.AddCommand(registerCommand dbPath)
        root

// Entry point helper
module Program =
    let main (args: string[]) =
        let dbPath = "data/kms/holons.db"
        let root = CatalogCLI.buildRoot dbPath
        root.Invoke(args)
