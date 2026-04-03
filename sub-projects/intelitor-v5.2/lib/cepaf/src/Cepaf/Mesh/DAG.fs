// =============================================================================
// DAG.fs - Directed Acyclic Graph for Dependency Resolution
// =============================================================================
// STAMP: SC-BOOT-008 (DAG MUST be acyclic), SC-CONFIG-001
// AOR: AOR-BOOT-001 (Topological sort before boot)
//
// ## Purpose
// Implements Kahn's algorithm for topological sorting of container dependencies.
// Ensures deterministic boot order and detects dependency cycles.
//
// ## Mathematical Foundation
// DAG G = (V, E) where V = containers, E = dependencies
// Kahn's Algorithm: O(V + E) complexity
// Topological order: For every edge (u,v), u comes before v
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-18 |
// | Author | Claude Opus 4.5 |
// | Reference | 20260118-1615-sil6-biomorphic-startup-master-specification.md |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Collections.Generic

/// Container criticality levels
type Criticality =
    | P0_Critical   // Must boot, boot fails if this fails
    | P1_High       // Should boot, degraded operation if fails
    | P2_Medium     // Nice to have, skip if fails
    | P3_Low        // Optional, skip without warning

/// Node in the dependency DAG
type DagNode = {
    Id: string
    Container: string
    Dependencies: string list
    EstimatedDuration: int  // milliseconds
    Wave: int
    Criticality: Criticality
}

/// Result of topological sort
type SortResult =
    | Sorted of DagNode list
    | CycleDetected of string list

/// DAG operations module
module DAG =

    /// Create a DAG node
    let createNode id container deps duration wave criticality = {
        Id = id
        Container = container
        Dependencies = deps
        EstimatedDuration = duration
        Wave = wave
        Criticality = criticality
    }

    /// Topological sort using Kahn's algorithm
    /// Complexity: O(V + E) where V = nodes, E = edges
    /// Returns: Sorted nodes or detected cycle
    let topologicalSort (nodes: DagNode list) : SortResult =
        if nodes.IsEmpty then
            Sorted []
        else
            // Build in-degree map and adjacency list
            let nodeMap = nodes |> List.map (fun n -> n.Id, n) |> Map.ofList
            let mutable inDegree = nodes |> List.map (fun n -> n.Id, n.Dependencies.Length) |> Map.ofList
            let mutable adjacency = nodes |> List.map (fun n -> n.Id, ResizeArray<string>()) |> Map.ofList

            // Build reverse adjacency (who depends on me?)
            for node in nodes do
                for dep in node.Dependencies do
                    if adjacency.ContainsKey dep then
                        adjacency.[dep].Add(node.Id)

            // Find all nodes with no dependencies (in-degree = 0)
            let queue = Queue<string>()
            for node in nodes do
                if node.Dependencies.IsEmpty then
                    queue.Enqueue(node.Id)

            let sorted = ResizeArray<string>()

            while queue.Count > 0 do
                let current = queue.Dequeue()
                sorted.Add(current)

                // For each dependent, reduce in-degree
                if adjacency.ContainsKey current then
                    for dependent in adjacency.[current] do
                        let newDegree = inDegree.[dependent] - 1
                        inDegree <- inDegree |> Map.add dependent newDegree
                        if newDegree = 0 then
                            queue.Enqueue(dependent)

            // Check for cycles
            if sorted.Count <> nodes.Length then
                let cycleNodes =
                    nodes
                    |> List.filter (fun n -> inDegree.[n.Id] > 0)
                    |> List.map (fun n -> n.Id)
                CycleDetected cycleNodes
            else
                let sortedNodes = sorted |> Seq.map (fun id -> nodeMap.[id]) |> Seq.toList
                Sorted sortedNodes

    /// Cycle detection using DFS with coloring
    /// White (0): not visited, Gray (1): in current path, Black (2): completed
    let detectCycles (nodes: DagNode list) : string list option =
        if nodes.IsEmpty then
            None
        else
            let nodeMap = nodes |> List.map (fun n -> n.Id, n) |> Map.ofList
            let colors = Dictionary<string, int>()
            let parent = Dictionary<string, string>()

            for node in nodes do
                colors.[node.Id] <- 0  // White

            let rec dfs nodeId =
                colors.[nodeId] <- 1  // Gray - in current path

                let node = nodeMap.[nodeId]
                let mutable cycle = None

                for dep in node.Dependencies do
                    if nodeMap.ContainsKey dep then
                        match colors.[dep] with
                        | 1 ->
                            // Back edge - cycle detected
                            cycle <- Some [dep; nodeId]
                        | 0 ->
                            parent.[dep] <- nodeId
                            match dfs dep with
                            | Some c -> cycle <- Some (nodeId :: c)
                            | None -> ()
                        | _ -> ()

                colors.[nodeId] <- 2  // Black - completed
                cycle

            nodes
            |> List.tryPick (fun n ->
                if colors.[n.Id] = 0 then dfs n.Id
                else None)

    /// Group nodes by wave for parallel execution
    let groupByWave (nodes: DagNode list) : DagNode list list =
        nodes
        |> List.groupBy (fun n -> n.Wave)
        |> List.sortBy fst
        |> List.map snd

    /// Verify all dependencies exist
    let verifyDependencies (nodes: DagNode list) : Result<unit, string list> =
        let nodeIds = nodes |> List.map (fun n -> n.Id) |> Set.ofList
        let missing =
            nodes
            |> List.collect (fun n ->
                n.Dependencies
                |> List.filter (fun dep -> not (Set.contains dep nodeIds))
                |> List.map (fun dep -> sprintf "%s depends on missing node %s" n.Id dep))

        if missing.IsEmpty then Ok ()
        else Error missing

    /// Get all nodes that depend on a given node (downstream)
    let getDownstream (nodeId: string) (nodes: DagNode list) : DagNode list =
        nodes |> List.filter (fun n -> n.Dependencies |> List.contains nodeId)

    /// Get all nodes that a given node depends on (upstream)
    let getUpstream (nodeId: string) (nodes: DagNode list) : DagNode list =
        match nodes |> List.tryFind (fun n -> n.Id = nodeId) with
        | Some node ->
            nodes |> List.filter (fun n -> node.Dependencies |> List.contains n.Id)
        | None -> []

    /// Calculate total estimated duration for critical path
    let estimateCriticalPathDuration (nodes: DagNode list) : int =
        match topologicalSort nodes with
        | CycleDetected _ -> -1
        | Sorted sorted ->
            let mutable earliest = Map.empty<string, int>

            for node in sorted do
                let maxPredFinish =
                    if node.Dependencies.IsEmpty then 0
                    else
                        node.Dependencies
                        |> List.filter (fun d -> earliest.ContainsKey d)
                        |> List.map (fun d -> earliest.[d])
                        |> function
                            | [] -> 0
                            | times -> List.max times

                earliest <- earliest |> Map.add node.Id (maxPredFinish + node.EstimatedDuration)

            earliest |> Map.toSeq |> Seq.map snd |> Seq.max

    /// Print DAG for debugging
    let printDAG (nodes: DagNode list) : unit =
        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║                    DEPENDENCY DAG                                  ║"
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║ Node          │ Wave │ Dependencies                               ║"
        printfn "╠═══════════════╪══════╪════════════════════════════════════════════╣"
        for node in nodes do
            let deps = if node.Dependencies.IsEmpty then "(root)"
                       else String.Join(", ", node.Dependencies)
            printfn "║ %-13s │  %d   │ %-43s ║" node.Id node.Wave deps
        printfn "╚═══════════════════════════════════════════════════════════════════╝"

        match detectCycles nodes with
        | Some cycle -> printfn "⚠️  CYCLE DETECTED: %s" (String.Join(" → ", cycle))
        | None -> printfn "✓ No cycles detected"

        printfn "  Estimated critical path: %d ms" (estimateCriticalPathDuration nodes)
        printfn ""
