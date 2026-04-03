namespace Cepaf.Cockpit.Runtime

open System
open System.Collections.ObjectModel
open ReactiveUI
open Cepaf.Smriti.Domain

// Run 5: Runtime Dashboard - Live Status Monitoring

// Represents a running Pod/Container
type ResourceStatusViewModel(id: string, state: string, source: string) =
    inherit ReactiveObject()
    
    member val Id = id
    member val State = state // "Running", "Failed", "Pending"
    member val Source = source // "K8s", "Podman"
    
    // Calculated visual property (Green/Red)
    member this.StatusColor =
        match state.ToLower() with
        | "running" -> "Green"
        | "failed" | "crashloopbackoff" -> "Red"
        | _ -> "Yellow"

// The Runtime Dashboard VM
type RuntimeDashboardViewModel() =
    inherit ReactiveObject()

    let resources = new ObservableCollection<ResourceStatusViewModel>()

    member this.Resources = resources

    member this.StartPolling() =
        // Logic to poll RuntimeBinder every N seconds
        // async {
        //     while true do
        //         let! data = RuntimeBinder.getSnaphot()
        //         // Update 'resources'
        //         do! Async.Sleep 5000
        // }
        ()
