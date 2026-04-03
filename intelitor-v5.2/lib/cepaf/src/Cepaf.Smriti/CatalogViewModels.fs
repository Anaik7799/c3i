namespace Cepaf.Cockpit.Catalog

open System
open System.Collections.ObjectModel
open ReactiveUI // MVVM Library
open Cepaf.Smriti.Domain

// Run 2: UI Foundation - Catalog View Models

// Represents a single row in the Catalog Grid
type EntityRowViewModel(entity: CatalogEntity) =
    inherit ReactiveObject()
    
    member val Kind = entity.Kind.ToString()
    member val Name = entity.Metadata.Name
    member val Namespace = entity.Metadata.Namespace
    member val Owner = 
        match entity.Spec with
        | Component c -> c.Owner
        | System s -> s.Owner
        | _ -> ""
    member val Lifecycle = 
        match entity.Spec with
        | Component c -> c.Lifecycle.ToString()
        | _ -> ""

// The Main Catalog View Model
type CatalogViewModel() =
    inherit ReactiveObject()

    let mutable searchQuery = ""
    let entities = new ObservableCollection<EntityRowViewModel>()

    // Bindable Properties
    member this.SearchQuery
        with get() = searchQuery
        and set(value) = this.RaiseAndSetIfChanged(&searchQuery, value) |> ignore

    member this.Entities = entities

    // Commands
    member this.Refresh() =
        // Logic to reload from SQLite
        // In a real app, this would be async
        this.Entities.Clear()
        // Mock data
        // this.Entities.Add(new EntityRowViewModel(mockEntity))
        ()

    member this.RegisterComponent() =
        // Open Dialog Logic
        printfn "Opening Register Dialog..."