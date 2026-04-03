// =============================================================================
// ChayaIntegration.fs - Digital Twin Integration for Planning System
// =============================================================================
// STAMP: SC-PLAN-070, SC-SIL4-001, SC-HOLON-001
// AOR: AOR-PLAN-070, AOR-HOLON-001
// Criticality: Level 4 (REQUIRED) - Integration
// =============================================================================
// Integrates Planning System with Chaya (Digital Twin) for:
// - Real-time system state awareness
// - Container-aware task scheduling
// - Holonic task distribution
// - Mesh topology-aware planning
// =============================================================================

namespace Cepaf.Planning.Integration

open System
open Cepaf.Planning.Core
open Cepaf.Planning.Core.Ids
open Cepaf.Planning.Domain
open Cepaf.Mesh

/// Planning-aware view of a holon
type PlanningHolon = {
    Id: HolonId
    Name: string
    Role: ContainerRole
    Health: ContainerHealth
    IsAvailable: bool
    Capacity: float           // 0.0 - 1.0 available capacity
    AssignedTasks: TaskId list
    ActiveOODACycles: OODACycleId list
    LastHeartbeat: Timestamp option
}

/// System state for planning decisions
type PlanningSystemState = {
    Holons: Map<string, PlanningHolon>
    MeshHealthy: bool
    AvailableCapacity: float
    ActiveTaskCount: int
    ActiveCycleCount: int
    LastUpdate: Timestamp
}

/// Chaya integration service
module ChayaIntegration =

    /// Convert DigitalTwin holon to PlanningHolon
    let private toPlanningHolon (genotype: HolonGenotype) (phenotype: HolonPhenotype) : PlanningHolon =
        let isAvailable =
            match phenotype.Health with
            | ContainerHealth.Healthy -> true
            | _ -> false

        let capacity =
            match phenotype.Health with
            | ContainerHealth.Healthy -> 1.0 - (float phenotype.ActiveConnections / 100.0)
            | ContainerHealth.Starting -> 0.0
            | ContainerHealth.Lameduck -> 0.1
            | _ -> 0.0

        {
            Id = HolonId genotype.Id
            Name = genotype.Name
            Role = genotype.Role
            Health = phenotype.Health
            IsAvailable = isAvailable
            Capacity = max 0.0 (min 1.0 capacity)
            AssignedTasks = []
            ActiveOODACycles = []
            LastHeartbeat = phenotype.LastHeartbeat
        }

    /// Get planning state from Digital Twin
    let getSystemState (twin: DigitalTwin) : PlanningSystemState =
        let holons =
            twin.Genotypes
            |> Map.map (fun id genotype ->
                let phenotype = twin.Phenotypes.[id]
                toPlanningHolon genotype phenotype)

        let availableHolons =
            holons |> Map.filter (fun _ h -> h.IsAvailable)

        let totalCapacity =
            if availableHolons.IsEmpty then 0.0
            else
                let sum = availableHolons |> Map.fold (fun acc _ h -> acc + h.Capacity) 0.0
                sum / float availableHolons.Count

        {
            Holons = holons
            MeshHealthy = DigitalTwin.allHealthy twin
            AvailableCapacity = totalCapacity
            ActiveTaskCount = 0
            ActiveCycleCount = 0
            LastUpdate = DateTimeOffset.UtcNow
        }

    /// Check if system is ready for planning operations
    let isSystemReady (state: PlanningSystemState) : bool =
        state.MeshHealthy && state.AvailableCapacity > 0.2

    /// Get holons suitable for task execution
    let getAvailableHolons (state: PlanningSystemState) : PlanningHolon list =
        state.Holons
        |> Map.toList
        |> List.map snd
        |> List.filter (fun h -> h.IsAvailable && h.Capacity > 0.1)
        |> List.sortByDescending (fun h -> h.Capacity)

    /// Get holons by role
    let getHolonsByRole (role: ContainerRole) (state: PlanningSystemState) : PlanningHolon list =
        state.Holons
        |> Map.toList
        |> List.map snd
        |> List.filter (fun h -> h.Role = role)

    /// Select best holon for task execution
    let selectHolonForTask (priority: Priority) (state: PlanningSystemState) : PlanningHolon option =
        let available = getAvailableHolons state
        match priority with
        | Priority.P0_Critical | Priority.P1_High ->
            // High priority: prefer seed/primary nodes
            available
            |> List.tryFind (fun h -> h.Role = Seed || h.Role = Primary)
            |> Option.orElse (List.tryHead available)
        | _ ->
            // Normal priority: any available node with capacity
            available
            |> List.tryFind (fun h -> h.Role = Satellite || h.Role = Worker)
            |> Option.orElse (List.tryHead available)

    /// Calculate system load factor
    let getLoadFactor (state: PlanningSystemState) : float =
        1.0 - state.AvailableCapacity

    /// Check if system is overloaded
    let isOverloaded (threshold: float) (state: PlanningSystemState) : bool =
        getLoadFactor state > threshold

/// Task distribution across mesh
module TaskDistributor =

    /// Distribution strategy
    type DistributionStrategy =
        | RoundRobin
        | LeastLoaded
        | PriorityBased
        | AffinityBased of holon: HolonId

    /// Distribute tasks to holons
    let distribute
        (strategy: DistributionStrategy)
        (tasks: Task list)
        (state: PlanningSystemState)
        : Map<HolonId, Task list> =

        let available = ChayaIntegration.getAvailableHolons state

        if available.IsEmpty then
            Map.empty
        else
            match strategy with
            | RoundRobin ->
                tasks
                |> List.mapi (fun i task ->
                    let holonIndex = i % available.Length
                    let holon = available.[holonIndex]
                    holon.Id, task)
                |> List.groupBy fst
                |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                |> Map.ofList

            | LeastLoaded ->
                // Distribute to holons with most capacity
                let mutable distribution = Map.empty<HolonId, Task list>
                let mutable capacities =
                    available
                    |> List.map (fun h -> h.Id, h.Capacity)
                    |> Map.ofList

                for task in tasks do
                    let bestHolon =
                        capacities
                        |> Map.toList
                        |> List.sortByDescending snd
                        |> List.head
                        |> fst

                    let existing = distribution |> Map.tryFind bestHolon |> Option.defaultValue []
                    distribution <- distribution |> Map.add bestHolon (task :: existing)

                    // Reduce capacity
                    let currentCap = capacities.[bestHolon]
                    capacities <- capacities |> Map.add bestHolon (currentCap - 0.1)

                distribution

            | PriorityBased ->
                // High priority tasks go to primary/seed nodes
                let (highPri, normalPri) =
                    tasks |> List.partition (fun t ->
                        match t.Priority with
                        | Priority.P0_Critical | Priority.P1_High -> true
                        | _ -> false)

                let primaryNodes = available |> List.filter (fun h -> h.Role = Seed || h.Role = Primary)
                let otherNodes = available |> List.filter (fun h -> h.Role <> Seed && h.Role <> Primary)

                let highPriDist =
                    if primaryNodes.IsEmpty then Map.empty
                    else
                        highPri
                        |> List.mapi (fun i t -> primaryNodes.[i % primaryNodes.Length].Id, t)
                        |> List.groupBy fst
                        |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                        |> Map.ofList

                let normalPriDist =
                    let nodes = if otherNodes.IsEmpty then available else otherNodes
                    normalPri
                    |> List.mapi (fun i t -> nodes.[i % nodes.Length].Id, t)
                    |> List.groupBy fst
                    |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                    |> Map.ofList

                // Merge distributions
                let keys = Set.union (Set.ofSeq (Map.keys highPriDist)) (Set.ofSeq (Map.keys normalPriDist))
                keys
                |> Set.toList
                |> List.map (fun k ->
                    let h = highPriDist |> Map.tryFind k |> Option.defaultValue []
                    let n = normalPriDist |> Map.tryFind k |> Option.defaultValue []
                    k, h @ n)
                |> Map.ofList

            | AffinityBased holonId ->
                // Send all tasks to specific holon
                Map.ofList [holonId, tasks]

/// OODA cycle mesh coordination
module OODAMeshCoordinator =
    // Use module alias to access Observation.create without conflict
    module PlanningObs = Cepaf.Planning.Domain.Observation

    /// Distributed observation gathering
    let gatherObservations (state: PlanningSystemState) : Cepaf.Planning.Domain.Observation list =
        state.Holons
        |> Map.toList
        |> List.map (fun (id, holon) ->
            let healthStr =
                match holon.Health with
                | ContainerHealth.Healthy -> "healthy"
                | ContainerHealth.Unhealthy -> "unhealthy"
                | ContainerHealth.Starting -> "starting"
                | ContainerHealth.Stopping -> "stopping"
                | ContainerHealth.Stopped -> "stopped"
                | ContainerHealth.Lameduck -> "lameduck"
                | ContainerHealth.Failed reason -> sprintf "failed: %s" reason
                | ContainerHealth.Unknown -> "unknown"

            PlanningObs.create
                (sprintf "holon:%s" id)
                (sprintf "Holon %s is %s with %.0f%% capacity" holon.Name healthStr (holon.Capacity * 100.0))
                (if holon.IsAvailable then 0.9 else 0.3))

    /// Start OODA cycle with mesh awareness
    let startMeshAwareCycle (contextType: string) (contextId: string) (state: PlanningSystemState) : OODACycle =
        let cycle = OODACycle.create contextType contextId

        // Add mesh observations
        let observations = gatherObservations state
        let cycle' =
            observations
            |> List.fold (fun c obs ->
                OODACycle.observe obs.Source obs.Content obs.Confidence c) cycle

        // Add system-level observation
        let availableCount = ChayaIntegration.getAvailableHolons state |> List.length
        let systemObs =
            if state.MeshHealthy then
                sprintf "System mesh is healthy with %d available nodes" availableCount
            else
                "System mesh is degraded - some holons unavailable"

        OODACycle.observe "system:mesh" systemObs (if state.MeshHealthy then 0.95 else 0.4) cycle'

/// Planning state projection from Digital Twin
module PlanningProjection =

    /// Project task workload per holon
    type HolonWorkload = {
        HolonId: HolonId
        TaskCount: int
        TotalEstimatedMinutes: int
        HighPriorityCount: int
        OverdueCount: int
    }

    /// Calculate workload for a holon
    let calculateWorkload (holonId: HolonId) (tasks: Task list) : HolonWorkload =
        let holonTasks = tasks // In real impl, would filter by assigned holon
        {
            HolonId = holonId
            TaskCount = holonTasks.Length
            TotalEstimatedMinutes = holonTasks |> List.sumBy (fun t -> t.EstimatedMinutes |> Option.defaultValue 0)
            HighPriorityCount = holonTasks |> List.filter (fun t -> t.Priority = Priority.P0_Critical || t.Priority = Priority.P1_High) |> List.length
            OverdueCount = holonTasks |> List.filter Task.isOverdue |> List.length
        }

    /// Get dashboard data for Prajna cockpit
    type PlanningDashboard = {
        TotalTasks: int
        TodoCount: int
        InProgressCount: int
        DoneCount: int
        BlockedCount: int
        OverdueCount: int
        HighPriorityCount: int
        MeshStatus: string
        AvailableHolons: int
        SystemCapacity: float
    }

    let getDashboard (tasks: Task list) (state: PlanningSystemState) : PlanningDashboard =
        let statusCounts = TaskList.countByStatus tasks
        {
            TotalTasks = tasks.Length
            TodoCount = statusCounts |> Map.tryFind "todo" |> Option.defaultValue 0
            InProgressCount = statusCounts |> Map.tryFind "in_progress" |> Option.defaultValue 0
            DoneCount = statusCounts |> Map.tryFind "done" |> Option.defaultValue 0
            BlockedCount = tasks |> List.filter Task.isBlocked |> List.length
            OverdueCount = tasks |> List.filter Task.isOverdue |> List.length
            HighPriorityCount = tasks |> List.filter (fun t -> t.Priority = Priority.P0_Critical || t.Priority = Priority.P1_High) |> List.length
            MeshStatus = if state.MeshHealthy then "HEALTHY" else "DEGRADED"
            AvailableHolons = ChayaIntegration.getAvailableHolons state |> List.length
            SystemCapacity = state.AvailableCapacity * 100.0
        }
