namespace Cepaf.Cockpit.Operations

open System
open System.Collections.ObjectModel
open ReactiveUI
open Cepaf.Smriti.Domain

// Run 4: UI Operations - SRE Dashboards

// --- K8s Dashboard ---

type PodViewModel(name: string, status: string, restarts: int) =
    inherit ReactiveObject()
    member val Name = name
    member val Status = status
    member val Restarts = restarts

type K8sDashboardViewModel() =
    inherit ReactiveObject()
    
    let pods = new ObservableCollection<PodViewModel>()
    member this.Pods = pods
    
    member this.Refresh(entityRef: string) =
        // Mock data fetch
        pods.Clear()
        pods.Add(new PodViewModel("pod-abc-1", "Running", 0))
        pods.Add(new PodViewModel("pod-abc-2", "CrashLoopBackOff", 5))

// --- CI/CD Dashboard ---

type PipelineRunViewModel(id: string, status: string, duration: string) =
    inherit ReactiveObject()
    member val Id = id
    member val Status = status
    member val Duration = duration

type CiCdViewModel() =
    inherit ReactiveObject()
    
    let runs = new ObservableCollection<PipelineRunViewModel>()
    member this.Runs = runs
    
    member this.LoadRuns(entityRef: string) =
        runs.Clear()
        runs.Add(new PipelineRunViewModel("#101", "Success", "2m 30s"))
        runs.Add(new PipelineRunViewModel("#102", "Failed", "1m 15s"))

// --- Cost Dashboard ---

type CostItemViewModel(date: string, amount: float) =
    inherit ReactiveObject()
    member val Date = date
    member val Amount = amount

type CostChartViewModel() =
    inherit ReactiveObject()
    
    let costs = new ObservableCollection<CostItemViewModel>()
    member this.Costs = costs
    
    member this.LoadData(entityRef: string) =
        costs.Clear()
        costs.Add(new CostItemViewModel("2023-10-01", 12.50))
        costs.Add(new CostItemViewModel("2023-10-02", 13.10))
