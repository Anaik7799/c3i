namespace Cepaf.Cockpit.Scaffolder

#nowarn "3261" // Suppress nullness warnings for ReactiveUI/UI framework interop

open System
open System.Collections.Generic
open System.Collections.ObjectModel
open ReactiveUI
open Cepaf.Smriti.Domain

// Run 3: Scaffolder Wizard - Dynamic Form Generation
// Note: This file uses #nowarn "3261" because ReactiveUI property binding
// inherently deals with nullable values from the UI framework.

// Represents a field in the Wizard (Text, Select, Boolean)
type FormFieldViewModel(key: string, schema: Map<string, obj>) =
    inherit ReactiveObject()

    // ReactiveUI properties interact with WPF/Avalonia binding which can be null.
    // We initialize with a safe default boxed empty string.
    let mutable internalValue : obj = box ""

    member val Key = key
    member val Title =
        match schema.TryFind "title" with
        | Some v -> string v
        | None -> key

    member val Description =
        match schema.TryFind "description" with
        | Some v -> string v
        | None -> ""

    member this.Value
        with get() = internalValue
        and set(v) =
            if internalValue <> v then
                internalValue <- v
                this.RaisePropertyChanged(nameof(this.Value))

// The Wizard Page VM
type ScaffolderWizardViewModel(template: CatalogEntity) =
    inherit ReactiveObject()

    let fields = new ObservableCollection<FormFieldViewModel>()

    // Initialize fields from Template Spec
    do
        match template.Spec with
        | Template props ->
            // Parse 'parameters' from template properties map
            match props.TryFind "parameters" with
            | Some parameters ->
                match parameters with
                | :? Map<string, obj> as paramMap ->
                    for kvp in paramMap do
                        let fieldSchema =
                            match kvp.Value with
                            | :? Map<string, obj> as schema -> schema
                            | _ -> Map.empty
                        fields.Add(FormFieldViewModel(kvp.Key, fieldSchema))
                | _ -> ()
            | None -> ()
        | _ -> ()

    member this.Fields = fields
    member val TemplateName = template.Metadata.Name

    member this.Execute() =
        // Collect values and call Scaffolder.execute
        let paramsMap = 
            this.Fields 
            |> Seq.map (fun f -> f.Key, f.Value) 
            |> Map.ofSeq
        
        // Scaffolder.executeTemplate template paramsMap
        printfn "Executing template with params: %A" paramsMap