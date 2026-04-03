/// CEPAF Service Chain DAG (Directed Acyclic Graph) Module
/// SC-CEP-003: Consensus-based health verification
/// SC-CEP-004: 30-second boot threshold via topological ordering
/// SC-AGT-018: Deadlock prevention through cycle detection
///
/// WHAT: Manages container dependency graph for boot sequencing
/// WHY: Ensures correct startup order and detects circular dependencies
/// CONSTRAINTS: DAG must be acyclic (SC-AGT-018), boot order must respect dependencies
module Cepaf.Modules.ServiceDAG

open System
open System.Collections.Generic

// ============================================================================
// TYPES
// ============================================================================

/// Health states for containers (matches Domain.fs ContainerState)
type HealthState =
    | Absent      // Container does not exist
    | Created     // Container created but not started
    | Starting    // Container is starting up
    | Healthy     // Container is healthy and ready
    | Degraded    // Container is running but with issues
    | Failed      // Container has failed

/// Dependency type for edges
type DependencyType =
    | Mandatory   // Must be healthy for dependent to start
    | Optional    // Can degrade gracefully if unhealthy

/// Container definition for DAG building
type ContainerDef = {
    Name: string
    Image: string
    DependsOn: string list
    DependencyTypes: Map<string, DependencyType>  // Map dependency name to type
    Layer: int option                              // Optional predefined layer
}

/// Node in the service DAG
type DAGNode = {
    Id: string
    Container: ContainerDef
    Dependencies: string list
    Dependents: string list         // Nodes that depend on this one
    Layer: int
    HealthState: HealthState
    BootOrder: int option           // Calculated boot order position
}

/// Directed Acyclic Graph for services
type ServiceDAG = {
    Nodes: Map<string, DAGNode>
    Edges: (string * string * DependencyType) list   // (from, to, type) = dependency edge
    Layers: Map<int, string list>                    // Layer -> node IDs
    BootSequence: string list                        // Ordered list for startup
    IsValid: bool                                    // False if cycles detected
}

/// Boot sequence result
type BootSequence = {
    Order: string list
    EstimatedTimeMs: int64
    Layers: Map<int, string list>
}

/// Cycle detection result
type CycleResult =
    | NoCycle
    | CycleDetected of nodes: string list

// ============================================================================
// DAG CONSTRUCTION
// ============================================================================

/// Create an empty DAG
let empty : ServiceDAG = {
    Nodes = Map.empty
    Edges = []
    Layers = Map.empty
    BootSequence = []
    IsValid = true
}

/// Build DAG from container definitions
let buildDAG (containers: ContainerDef list) : ServiceDAG =
    // Create nodes
    let nodes =
        containers
        |> List.map (fun c ->
            c.Name, {
                Id = c.Name
                Container = c
                Dependencies = c.DependsOn
                Dependents = []  // Will be calculated
                Layer = 0        // Will be calculated
                HealthState = Absent
                BootOrder = None
            })
        |> Map.ofList

    // Create edges with dependency types
    let edges =
        containers
        |> List.collect (fun c ->
            c.DependsOn
            |> List.map (fun dep ->
                let depType =
                    c.DependencyTypes
                    |> Map.tryFind dep
                    |> Option.defaultValue Mandatory
                (dep, c.Name, depType)))

    // Calculate dependents for each node
    let dependentsMap =
        edges
        |> List.groupBy (fun (from, _, _) -> from)
        |> List.map (fun (from, edges) -> from, edges |> List.map (fun (_, to_, _) -> to_))
        |> Map.ofList

    let nodesWithDependents =
        nodes
        |> Map.map (fun id node ->
            { node with
                Dependents = dependentsMap |> Map.tryFind id |> Option.defaultValue [] })

    { empty with
        Nodes = nodesWithDependents
        Edges = edges }

/// Add a node to an existing DAG
let addNode (container: ContainerDef) (dag: ServiceDAG) : ServiceDAG =
    let node = {
        Id = container.Name
        Container = container
        Dependencies = container.DependsOn
        Dependents = []
        Layer = 0
        HealthState = Absent
        BootOrder = None
    }

    let newEdges =
        container.DependsOn
        |> List.map (fun dep ->
            let depType =
                container.DependencyTypes
                |> Map.tryFind dep
                |> Option.defaultValue Mandatory
            (dep, container.Name, depType))

    { dag with
        Nodes = dag.Nodes |> Map.add container.Name node
        Edges = dag.Edges @ newEdges }

/// Remove a node from the DAG
let removeNode (nodeId: string) (dag: ServiceDAG) : ServiceDAG =
    { dag with
        Nodes = dag.Nodes |> Map.remove nodeId
        Edges = dag.Edges |> List.filter (fun (from, to_, _) -> from <> nodeId && to_ <> nodeId) }

// ============================================================================
// CYCLE DETECTION (Kahn's Algorithm)
// ============================================================================

/// Detect cycles in DAG using Kahn's algorithm
/// Returns CycleDetected with involved nodes if cycle exists
let detectCycles (dag: ServiceDAG) : CycleResult =
    let inDegree = Dictionary<string, int>()
    let queue = Queue<string>()
    let sorted = ResizeArray<string>()

    // Initialize in-degrees to 0
    dag.Nodes |> Map.iter (fun id _ -> inDegree.[id] <- 0)

    // Calculate in-degrees (count incoming edges)
    dag.Edges |> List.iter (fun (_, to_, _) ->
        if inDegree.ContainsKey(to_) then
            inDegree.[to_] <- inDegree.[to_] + 1)

    // Enqueue nodes with no incoming edges (in-degree = 0)
    dag.Nodes
    |> Map.iter (fun id _ ->
        if inDegree.ContainsKey(id) && inDegree.[id] = 0 then
            queue.Enqueue(id))

    // Process queue using BFS
    while queue.Count > 0 do
        let node = queue.Dequeue()
        sorted.Add(node)

        // For each outgoing edge, reduce in-degree of target
        dag.Edges
        |> List.filter (fun (from, _, _) -> from = node)
        |> List.iter (fun (_, to_, _) ->
            if inDegree.ContainsKey(to_) then
                inDegree.[to_] <- inDegree.[to_] - 1
                if inDegree.[to_] = 0 then
                    queue.Enqueue(to_))

    // If we processed all nodes, no cycle exists
    if sorted.Count = dag.Nodes.Count then
        NoCycle
    else
        // Nodes not in sorted list are part of cycle(s)
        let cycleNodes =
            dag.Nodes
            |> Map.toList
            |> List.map fst
            |> List.filter (fun id -> not (sorted.Contains(id)))
        CycleDetected cycleNodes

/// Check if DAG has cycles (convenience function)
let hasCycles (dag: ServiceDAG) : bool =
    match detectCycles dag with
    | NoCycle -> false
    | CycleDetected _ -> true

// ============================================================================
// TOPOLOGICAL SORT
// ============================================================================

/// Perform topological sort on DAG
/// Returns Ok with sorted node IDs or Error with cycle information
let topologicalSort (dag: ServiceDAG) : Result<string list, string> =
    match detectCycles dag with
    | CycleDetected nodes ->
        Error (sprintf "Cycle detected involving nodes: %s" (String.concat ", " nodes))
    | NoCycle ->
        // Use DFS-based topological sort for deterministic ordering
        let visited = HashSet<string>()
        let recStack = HashSet<string>()  // For cycle detection during DFS
        let result = Stack<string>()

        let rec dfs (nodeId: string) : bool =
            if recStack.Contains(nodeId) then
                false  // Cycle detected
            elif visited.Contains(nodeId) then
                true   // Already processed
            else
                visited.Add(nodeId) |> ignore
                recStack.Add(nodeId) |> ignore

                // Visit all dependencies first
                let node = dag.Nodes |> Map.tryFind nodeId
                let deps =
                    match node with
                    | Some n -> n.Dependencies
                    | None -> []

                let allDepsOk =
                    deps
                    |> List.filter (fun d -> dag.Nodes.ContainsKey(d))
                    |> List.forall dfs

                recStack.Remove(nodeId) |> ignore

                if allDepsOk then
                    result.Push(nodeId)
                    true
                else
                    false

        // Start DFS from all nodes
        let allOk =
            dag.Nodes
            |> Map.toList
            |> List.map fst
            |> List.forall dfs

        if allOk then
            // Stack is LIFO, so reverse to get dependencies before dependents
            Ok (result |> List.ofSeq |> List.rev)
        else
            Error "Cycle detected during topological sort"

/// Get boot order (topological sort result)
let getBootOrder (dag: ServiceDAG) : string list =
    match topologicalSort dag with
    | Ok order -> order
    | Error _ -> []

// ============================================================================
// LAYER ASSIGNMENT
// ============================================================================

/// Assign layers based on dependency depth
/// Layer 0 = no dependencies, Layer N = max(dependency layers) + 1
let assignLayers (dag: ServiceDAG) : ServiceDAG =
    match topologicalSort dag with
    | Error _ -> { dag with IsValid = false }  // Return unchanged if cycle
    | Ok sorted ->
        let layerMap = Dictionary<string, int>()

        // Process in topological order (dependencies first)
        sorted |> List.iter (fun nodeId ->
            match dag.Nodes |> Map.tryFind nodeId with
            | None -> ()
            | Some node ->
                let maxDepLayer =
                    node.Dependencies
                    |> List.choose (fun dep ->
                        if layerMap.ContainsKey(dep) then Some (layerMap.[dep] + 1)
                        else None)
                    |> function
                        | [] -> 0
                        | layers -> List.max layers
                layerMap.[nodeId] <- maxDepLayer)

        // Update nodes with calculated layers
        let updatedNodes =
            dag.Nodes
            |> Map.map (fun id node ->
                let layer = if layerMap.ContainsKey(id) then layerMap.[id] else 0
                { node with Layer = layer })

        // Group nodes by layer
        let layers =
            updatedNodes
            |> Map.toList
            |> List.groupBy (fun (_, node) -> node.Layer)
            |> List.map (fun (layer, nodes) -> (layer, nodes |> List.map fst))
            |> Map.ofList

        { dag with
            Nodes = updatedNodes
            Layers = layers
            IsValid = true }

/// Get nodes at a specific layer
let getNodesAtLayer (layer: int) (dag: ServiceDAG) : string list =
    dag.Layers
    |> Map.tryFind layer
    |> Option.defaultValue []

/// Get maximum layer number
let getMaxLayer (dag: ServiceDAG) : int =
    if Map.isEmpty dag.Layers then 0
    else dag.Layers |> Map.toList |> List.map fst |> List.max

// ============================================================================
// DEPENDENCY RESOLUTION
// ============================================================================

/// Get all dependencies of a node (direct only)
let getDependencies (nodeId: string) (dag: ServiceDAG) : string list =
    dag.Nodes
    |> Map.tryFind nodeId
    |> Option.map (fun n -> n.Dependencies)
    |> Option.defaultValue []

/// Get all dependents of a node (nodes that depend on this one)
let getDependents (nodeId: string) (dag: ServiceDAG) : string list =
    dag.Edges
    |> List.filter (fun (from, _, _) -> from = nodeId)
    |> List.map (fun (_, to_, _) -> to_)

/// Get all transitive dependencies (recursive)
let getTransitiveDependencies (nodeId: string) (dag: ServiceDAG) : string list =
    let visited = HashSet<string>()

    let rec collect (id: string) =
        if visited.Contains(id) then []
        else
            visited.Add(id) |> ignore
            let directDeps = getDependencies id dag
            let transitiveDeps = directDeps |> List.collect collect
            directDeps @ transitiveDeps

    collect nodeId |> List.distinct

/// Get all transitive dependents (recursive)
let getTransitiveDependents (nodeId: string) (dag: ServiceDAG) : string list =
    let visited = HashSet<string>()

    let rec collect (id: string) =
        if visited.Contains(id) then []
        else
            visited.Add(id) |> ignore
            let directDeps = getDependents id dag
            let transitiveDeps = directDeps |> List.collect collect
            directDeps @ transitiveDeps

    collect nodeId |> List.distinct

/// Check if nodeA depends on nodeB (directly or transitively)
let dependsOn (nodeA: string) (nodeB: string) (dag: ServiceDAG) : bool =
    let deps = getTransitiveDependencies nodeA dag
    List.contains nodeB deps

/// Get dependency type between two nodes
let getDependencyType (from: string) (to_: string) (dag: ServiceDAG) : DependencyType option =
    dag.Edges
    |> List.tryFind (fun (f, t, _) -> f = from && t = to_)
    |> Option.map (fun (_, _, depType) -> depType)

// ============================================================================
// BOOT SEQUENCE CALCULATION
// ============================================================================

/// Calculate boot sequence with timing estimates
let calculateBootSequence (dag: ServiceDAG) : BootSequence =
    let layeredDag = assignLayers dag

    match topologicalSort layeredDag with
    | Error _ ->
        { Order = []; EstimatedTimeMs = 0L; Layers = Map.empty }
    | Ok order ->
        // Estimate: 5s per layer (parallel within layer)
        let maxLayer = getMaxLayer layeredDag
        let estimatedTimeMs = int64 ((maxLayer + 1) * 5000)

        { Order = order
          EstimatedTimeMs = estimatedTimeMs
          Layers = layeredDag.Layers }

/// Get nodes that can start immediately (no unstarted dependencies)
let getReadyToStart (startedNodes: Set<string>) (dag: ServiceDAG) : string list =
    dag.Nodes
    |> Map.toList
    |> List.filter (fun (id, node) ->
        // Not already started
        not (Set.contains id startedNodes) &&
        // All dependencies are started
        node.Dependencies |> List.forall (fun dep -> Set.contains dep startedNodes))
    |> List.map fst

/// Get nodes that must start before a given node
let getMustStartBefore (nodeId: string) (dag: ServiceDAG) : string list =
    getTransitiveDependencies nodeId dag

/// Get nodes that must start after a given node
let getMustStartAfter (nodeId: string) (dag: ServiceDAG) : string list =
    getTransitiveDependents nodeId dag

// ============================================================================
// HEALTH STATE MANAGEMENT
// ============================================================================

/// Update health state of a node
let updateHealthState (nodeId: string) (state: HealthState) (dag: ServiceDAG) : ServiceDAG =
    match dag.Nodes |> Map.tryFind nodeId with
    | None -> dag
    | Some node ->
        let updatedNode = { node with HealthState = state }
        { dag with Nodes = dag.Nodes |> Map.add nodeId updatedNode }

/// Get health state of a node
let getHealthState (nodeId: string) (dag: ServiceDAG) : HealthState option =
    dag.Nodes
    |> Map.tryFind nodeId
    |> Option.map (fun n -> n.HealthState)

/// Check if all mandatory dependencies are healthy
let areMandatoryDepsHealthy (nodeId: string) (dag: ServiceDAG) : bool =
    match dag.Nodes |> Map.tryFind nodeId with
    | None -> false
    | Some node ->
        node.Dependencies
        |> List.forall (fun depId ->
            let depType = getDependencyType depId nodeId dag |> Option.defaultValue Mandatory
            match depType with
            | Optional -> true  // Optional deps don't block
            | Mandatory ->
                match getHealthState depId dag with
                | Some Healthy -> true
                | _ -> false)

/// Get all healthy nodes
let getHealthyNodes (dag: ServiceDAG) : string list =
    dag.Nodes
    |> Map.toList
    |> List.filter (fun (_, node) -> node.HealthState = Healthy)
    |> List.map fst

/// Get all failed nodes
let getFailedNodes (dag: ServiceDAG) : string list =
    dag.Nodes
    |> Map.toList
    |> List.filter (fun (_, node) -> node.HealthState = Failed)
    |> List.map fst

// ============================================================================
// VALIDATION & QUERIES
// ============================================================================

/// Validate the DAG structure
let validate (dag: ServiceDAG) : Result<ServiceDAG, string list> =
    let errors = ResizeArray<string>()

    // Check for cycles
    match detectCycles dag with
    | CycleDetected nodes ->
        errors.Add(sprintf "Circular dependency detected: %s" (String.concat " -> " nodes))
    | NoCycle -> ()

    // Check for missing dependencies
    dag.Nodes
    |> Map.iter (fun _ node ->
        node.Dependencies
        |> List.iter (fun dep ->
            if not (dag.Nodes.ContainsKey(dep)) then
                errors.Add(sprintf "Node '%s' depends on non-existent node '%s'" node.Id dep)))

    // Check for self-dependencies
    dag.Nodes
    |> Map.iter (fun id node ->
        if List.contains id node.Dependencies then
            errors.Add(sprintf "Node '%s' depends on itself" id))

    if errors.Count = 0 then
        Ok (assignLayers dag)
    else
        Error (errors |> List.ofSeq)

/// Get node count
let nodeCount (dag: ServiceDAG) : int =
    dag.Nodes.Count

/// Get edge count
let edgeCount (dag: ServiceDAG) : int =
    dag.Edges.Length

/// Check if a node exists
let hasNode (nodeId: string) (dag: ServiceDAG) : bool =
    dag.Nodes.ContainsKey(nodeId)

/// Get all node IDs
let getAllNodeIds (dag: ServiceDAG) : string list =
    dag.Nodes |> Map.toList |> List.map fst

/// Get a node by ID
let getNode (nodeId: string) (dag: ServiceDAG) : DAGNode option =
    dag.Nodes |> Map.tryFind nodeId

// ============================================================================
// VISUALIZATION HELPERS
// ============================================================================

/// Format DAG as a simple text representation
let formatAsText (dag: ServiceDAG) : string =
    let sb = System.Text.StringBuilder()
    sb.AppendLine("Service DAG:") |> ignore
    sb.AppendLine(sprintf "  Nodes: %d" (nodeCount dag)) |> ignore
    sb.AppendLine(sprintf "  Edges: %d" (edgeCount dag)) |> ignore
    sb.AppendLine(sprintf "  Valid: %b" dag.IsValid) |> ignore
    sb.AppendLine("  Layers:") |> ignore

    dag.Layers
    |> Map.toList
    |> List.sortBy fst
    |> List.iter (fun (layer, nodes) ->
        sb.AppendLine(sprintf "    L%d: %s" layer (String.concat ", " nodes)) |> ignore)

    sb.AppendLine("  Boot Order:") |> ignore
    match topologicalSort dag with
    | Ok order ->
        order |> List.iteri (fun i node ->
            sb.AppendLine(sprintf "    %d. %s" (i + 1) node) |> ignore)
    | Error msg ->
        sb.AppendLine(sprintf "    Error: %s" msg) |> ignore

    sb.ToString()

/// Format DAG edges for debugging
let formatEdges (dag: ServiceDAG) : string list =
    dag.Edges
    |> List.map (fun (from, to_, depType) ->
        let typeStr = match depType with Mandatory -> "M" | Optional -> "O"
        sprintf "%s -[%s]-> %s" from typeStr to_)
