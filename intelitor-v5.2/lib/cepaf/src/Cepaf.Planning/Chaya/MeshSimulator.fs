// =============================================================================
// MeshSimulator.fs - Local Mesh Simulation for Standalone Chaya
// =============================================================================
// STAMP: SC-CHAYA-002, SC-MESH-001
// AOR: AOR-CHAYA-002
// Criticality: Level 4 (REQUIRED) - Standalone Operation
// =============================================================================
// Enables Chaya to simulate mesh topology and task distribution
// without requiring actual network connectivity or external services.
// =============================================================================

namespace Cepaf.Planning.Chaya

open System
open System.Collections.Generic

/// Simulated node in the mesh
type SimulatedNode = {
    Id: string
    Name: string
    Role: string              // "primary", "seed", "satellite", "worker"
    Health: string            // "healthy", "unhealthy", "starting", "stopping"
    Capacity: float           // 0.0 - 1.0
    AssignedTasks: string list
    LastHeartbeat: DateTimeOffset
}

/// Simulated mesh state
type SimulatedMesh = {
    Nodes: Map<string, SimulatedNode>
    QuorumSize: int
    IsHealthy: bool
    CreatedAt: DateTimeOffset
}

/// Mesh simulation for standalone operation
module MeshSimulator =

    /// Default mesh topology for simulation
    let createDefaultMesh () : SimulatedMesh =
        let now = DateTimeOffset.UtcNow
        let nodes =
            [
                "node-1", {
                    Id = "node-1"
                    Name = "chaya-primary"
                    Role = "primary"
                    Health = "healthy"
                    Capacity = 0.8
                    AssignedTasks = []
                    LastHeartbeat = now
                }
                "node-2", {
                    Id = "node-2"
                    Name = "chaya-seed"
                    Role = "seed"
                    Health = "healthy"
                    Capacity = 0.9
                    AssignedTasks = []
                    LastHeartbeat = now
                }
                "node-3", {
                    Id = "node-3"
                    Name = "chaya-worker-1"
                    Role = "worker"
                    Health = "healthy"
                    Capacity = 1.0
                    AssignedTasks = []
                    LastHeartbeat = now
                }
            ] |> Map.ofList

        {
            Nodes = nodes
            QuorumSize = 2
            IsHealthy = true
            CreatedAt = now
        }

    /// Add a node to the mesh
    let addNode (node: SimulatedNode) (mesh: SimulatedMesh) : SimulatedMesh =
        { mesh with Nodes = mesh.Nodes |> Map.add node.Id node }

    /// Remove a node from the mesh
    let removeNode (nodeId: string) (mesh: SimulatedMesh) : SimulatedMesh =
        { mesh with Nodes = mesh.Nodes |> Map.remove nodeId }

    /// Update node health
    let updateNodeHealth (nodeId: string) (health: string) (mesh: SimulatedMesh) : SimulatedMesh =
        match mesh.Nodes |> Map.tryFind nodeId with
        | Some node ->
            let updated = { node with Health = health; LastHeartbeat = DateTimeOffset.UtcNow }
            { mesh with Nodes = mesh.Nodes |> Map.add nodeId updated }
        | None -> mesh

    /// Get healthy nodes
    let getHealthyNodes (mesh: SimulatedMesh) : SimulatedNode list =
        mesh.Nodes
        |> Map.toList
        |> List.map snd
        |> List.filter (fun n -> n.Health = "healthy")

    /// Get available capacity
    let getTotalCapacity (mesh: SimulatedMesh) : float =
        getHealthyNodes mesh
        |> List.sumBy (fun n -> n.Capacity)

    /// Check if quorum is achieved
    let hasQuorum (mesh: SimulatedMesh) : bool =
        let healthyCount = getHealthyNodes mesh |> List.length
        healthyCount >= mesh.QuorumSize

    /// Recalculate mesh health based on node states
    let recalculateHealth (mesh: SimulatedMesh) : SimulatedMesh =
        let isHealthy = hasQuorum mesh && getTotalCapacity mesh > 0.5
        { mesh with IsHealthy = isHealthy }

/// Task distribution simulation
module TaskDistributionSimulator =

    /// Distribution strategy
    type Strategy =
        | RoundRobin
        | LeastLoaded
        | PriorityBased
        | Random

    /// Distribute tasks to nodes
    let distribute (strategy: Strategy) (tasks: ChayaTask list) (mesh: SimulatedMesh) : Map<string, ChayaTask list> =
        let healthyNodes = MeshSimulator.getHealthyNodes mesh

        if healthyNodes.IsEmpty then
            Map.empty
        else
            match strategy with
            | RoundRobin ->
                tasks
                |> List.mapi (fun i task ->
                    let nodeIndex = i % healthyNodes.Length
                    let node = healthyNodes.[nodeIndex]
                    node.Id, task)
                |> List.groupBy fst
                |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                |> Map.ofList

            | LeastLoaded ->
                let mutable capacities =
                    healthyNodes
                    |> List.map (fun n -> n.Id, n.Capacity)
                    |> Map.ofList

                let mutable distribution = Map.empty<string, ChayaTask list>

                for task in tasks do
                    let bestNode =
                        capacities
                        |> Map.toList
                        |> List.sortByDescending snd
                        |> List.head
                        |> fst

                    let existing = distribution |> Map.tryFind bestNode |> Option.defaultValue []
                    distribution <- distribution |> Map.add bestNode (task :: existing)

                    // Reduce capacity
                    let currentCap = capacities.[bestNode]
                    capacities <- capacities |> Map.add bestNode (currentCap - 0.1)

                distribution

            | PriorityBased ->
                let (highPri, normalPri) =
                    tasks |> List.partition (fun t -> t.Priority = "P0" || t.Priority = "P1")

                let primaryNodes = healthyNodes |> List.filter (fun n -> n.Role = "primary" || n.Role = "seed")
                let workerNodes = healthyNodes |> List.filter (fun n -> n.Role = "worker" || n.Role = "satellite")

                let highDist =
                    if primaryNodes.IsEmpty then Map.empty
                    else
                        highPri
                        |> List.mapi (fun i t -> primaryNodes.[i % primaryNodes.Length].Id, t)
                        |> List.groupBy fst
                        |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                        |> Map.ofList

                let nodes = if workerNodes.IsEmpty then healthyNodes else workerNodes
                let normalDist =
                    normalPri
                    |> List.mapi (fun i t -> nodes.[i % nodes.Length].Id, t)
                    |> List.groupBy fst
                    |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                    |> Map.ofList

                // Merge
                let keys = Set.union (Set.ofSeq (Map.keys highDist)) (Set.ofSeq (Map.keys normalDist))
                keys
                |> Set.toList
                |> List.map (fun k ->
                    let h = highDist |> Map.tryFind k |> Option.defaultValue []
                    let n = normalDist |> Map.tryFind k |> Option.defaultValue []
                    k, h @ n)
                |> Map.ofList

            | Random ->
                let rnd = System.Random()
                tasks
                |> List.map (fun task ->
                    let nodeIndex = rnd.Next(healthyNodes.Length)
                    let node = healthyNodes[nodeIndex]
                    node.Id, task)
                |> List.groupBy fst
                |> List.map (fun (id, pairs) -> id, pairs |> List.map snd)
                |> Map.ofList

/// OODA cycle with mesh awareness
module MeshAwareOODA =

    /// Gather observations from simulated mesh
    let gatherMeshObservations (mesh: SimulatedMesh) : string list =
        let nodes = MeshSimulator.getHealthyNodes mesh
        let observations = [
            sprintf "Mesh has %d healthy nodes out of %d total" nodes.Length (mesh.Nodes.Count)
            sprintf "Total capacity: %.0f%%" (MeshSimulator.getTotalCapacity mesh * 100.0)
            sprintf "Quorum: %s" (if MeshSimulator.hasQuorum mesh then "ACHIEVED" else "NOT ACHIEVED")
            sprintf "Mesh status: %s" (if mesh.IsHealthy then "HEALTHY" else "DEGRADED")
        ]

        // Add per-node observations
        let nodeObs =
            nodes
            |> List.map (fun n ->
                sprintf "Node %s (%s): %s, %.0f%% capacity" n.Name n.Role n.Health (n.Capacity * 100.0))

        observations @ nodeObs

    /// Run mesh-aware OODA cycle
    let runMeshAwareCycle (config: ChayaConfig) (mesh: SimulatedMesh) (contextObservations: string list) : ChayaOODACycle =
        let meshObs = gatherMeshObservations mesh
        let allObs = contextObservations @ meshObs

        let selectAction observations =
            if not mesh.IsHealthy then
                "ALERT: Mesh degraded - investigate node health"
            elif MeshSimulator.getTotalCapacity mesh < 0.3 then
                "SCALE: Add more worker nodes"
            else
                "PROCEED: System healthy, continue normal operations"

        ChayaOODAEngine.runFastCycle config allObs selectAction

/// Chaya with mesh simulation capabilities
type MeshAwareChaya(config: ChayaConfig) =
    inherit StandaloneChaya(config)

    let mutable mesh = MeshSimulator.createDefaultMesh()

    /// Get current mesh state
    member _.Mesh = mesh

    /// Update mesh
    member _.UpdateMesh(newMesh: SimulatedMesh) =
        mesh <- newMesh

    /// Add a simulated node
    member _.AddNode(node: SimulatedNode) =
        mesh <- MeshSimulator.addNode node mesh

    /// Remove a simulated node
    member _.RemoveNode(nodeId: string) =
        mesh <- MeshSimulator.removeNode nodeId mesh

    /// Update node health
    member _.UpdateNodeHealth(nodeId: string, health: string) =
        mesh <- MeshSimulator.updateNodeHealth nodeId health mesh
        mesh <- MeshSimulator.recalculateHealth mesh

    /// Distribute tasks across mesh
    member _.DistributeTasks(strategy: TaskDistributionSimulator.Strategy) =
        let tasks = base.GetAllTasks() |> List.filter (fun t -> t.Status = "todo")
        TaskDistributionSimulator.distribute strategy tasks mesh

    /// Run mesh-aware OODA cycle
    member _.RunMeshAwareOODACycle(contextObservations: string list) =
        MeshAwareOODA.runMeshAwareCycle config mesh contextObservations

    /// Get mesh health summary
    member _.GetMeshHealthSummary() =
        let nodes = MeshSimulator.getHealthyNodes mesh
        {|
            TotalNodes = mesh.Nodes.Count
            HealthyNodes = nodes.Length
            TotalCapacity = MeshSimulator.getTotalCapacity mesh
            HasQuorum = MeshSimulator.hasQuorum mesh
            IsHealthy = mesh.IsHealthy
        |}

/// Factory for mesh-aware Chaya
module MeshAwareChayaFactory =

    /// Create with default configuration and mesh
    let createDefault () =
        let config = ChayaConfig.defaultConfig()
        let chaya = MeshAwareChaya(config)
        chaya.Initialize()
        chaya

    /// Create with custom configuration
    let create (config: ChayaConfig) =
        let chaya = MeshAwareChaya(config)
        chaya.Initialize()
        chaya
