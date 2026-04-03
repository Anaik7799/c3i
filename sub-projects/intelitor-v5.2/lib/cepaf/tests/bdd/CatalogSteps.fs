namespace Cepaf.Cockpit.Tests.BDD

open System
open TickSpec // Requires Nuget: TickSpec
open NUnit.Framework
open Cepaf.Cockpit.Catalog
open Cepaf.KmsCatalog.Domain

// Run 2: Step Definitions - Catalog Explorer

type CatalogExplorerSteps() =
    
    // Mock State
    let vm = CatalogViewModel()
    let mutable currentScreen = ""
    
    [<Given>]
    member this.``I am on the "(.*)" screen`` (screen: string) =
        currentScreen <- screen
        // In reality, verify Router state

    [<Given>]
    member this.``the catalog contains the following entities:`` (table: Table) =
        // Parse TickSpec table and populate VM
        for row in table.Rows do
            let kind = row.["kind"]
            let name = row.["name"]
            // vm.Entities.Add(...)
            ()

    [<When>]
    member this.``I select "(.*)" from the "(.*)" filter`` (value: string, filter: string) =
        match filter with
        | "Kind" -> vm.SelectedKind <- value
        | _ -> ()

    [<Then>]
    member this.``I should see "(.*)" in the table`` (name: string) =
        let exists = vm.Entities |> Seq.exists (fun e -> e.Name = name)
        Assert.True(exists, sprintf "Entity %s not found" name)

    [<Then>]
    member this.``I should NOT see "(.*)" in the table`` (name: string) =
        let exists = vm.Entities |> Seq.exists (fun e -> e.Name = name)
        Assert.False(exists, sprintf "Entity %s should be hidden" name)

    [<When>]
    member this.``I search for "(.*)"`` (query: string) =
        vm.SearchQuery <- query

    [<Then>]
    member this.``the "Owner" column should show "(.*)"`` (owner: string) =
        // Verify visible rows
        ()
