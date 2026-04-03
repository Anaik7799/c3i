namespace Indrajaal.Cortex

open System
open System.Collections.Generic

// Upgrade 2: The Holographic Visualizer (P3)
// Context: Universe 'visual'

type NodeId = string

type TopologyEngine() =
    
    // Adjacency List
    let graph = Dictionary<NodeId, HashSet<NodeId>>()
    
    // GraphBLAS Simulation (Dense Matrix)
    // In a real implementation, we'd use SuiteSparse:GraphBLAS
    let mutable matrix = Array2D.zeroCreate<float> 0 0
    let nodeIndex = Dictionary<NodeId, int>()
    let indexNode = Dictionary<int, NodeId>()

    let resizeMatrix size =
        let newMatrix = Array2D.zeroCreate<float> size size
        // Copy old (naive)
        for r in 0 .. (Array2D.length1 matrix) - 1 do
            for c in 0 .. (Array2D.length2 matrix) - 1 do
                newMatrix.[r, c] <- matrix.[r, c]
        matrix <- newMatrix

    member this.AddNode(id: NodeId) =
        if not (graph.ContainsKey(id)) then
            graph.[id] <- HashSet<NodeId>()
            let idx = graph.Count - 1
            nodeIndex.[id] <- idx
            indexNode.[idx] <- id
            resizeMatrix graph.Count

    member this.AddEdge(source: NodeId, target: NodeId) =
        this.AddNode(source)
        this.AddNode(target)
        if graph.[source].Add(target) then
            // Update Matrix (1.0 = Connected)
            let r = nodeIndex.[source]
            let c = nodeIndex.[target]
            matrix.[r, c] <- 1.0

    member this.GetNeighbors(id: NodeId) =
        if graph.ContainsKey(id) then
            graph.[id] |> Seq.toList
        else
            []
    
    // Matrix Operation: PageRank-ish Centrality
    member this.CalculateEnergy() =
        let size = graph.Count
        if size = 0 then 0.0 else
        let v = Array.create size (1.0 / float size)
        // Mv multiplication (1 iteration)
        let res = Array.zeroCreate<float> size
        for r in 0 .. size - 1 do
            for c in 0 .. size - 1 do
                res.[r] <- res.[r] + (matrix.[r, c] * v.[c])
        Array.max res

    member this.Snapshot() =
        let energy = this.CalculateEnergy()
        let edges = graph.Values |> Seq.sumBy (fun s -> s.Count)
        sprintf "Nodes: %d | Edges: %d | MaxEnergy: %.4f" graph.Count edges energy
