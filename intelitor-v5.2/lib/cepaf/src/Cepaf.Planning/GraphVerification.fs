namespace Cepaf.Planning

open System
open System.Collections.Generic
open System.Text

/// <summary>
/// Graph-based access control verification using formal graph algorithms.
///
/// WHAT: Implements graph-based verification of permission structures to prove
///       security properties using formal graph theory.
///
/// WHY: Access control verification requires proving no unauthorized paths exist.
///      Graph algorithms provide formal, verifiable proofs of permission soundness.
///
/// CONSTRAINTS:
/// - SC-GRAPH-001: Graph must be DAG for permissions
/// - SC-GRAPH-002: All agents must have decision paths
/// - SC-GRAPH-003: No forbidden paths exist
/// - SC-GRAPH-004: Graph verification < 100ms
/// - SC-GRAPH-005: Critical services fully connected
///
/// AOR:
/// - AOR-GRAPH-001: Verify graph on every permission change
/// - AOR-GRAPH-002: Log all verification results
/// - AOR-GRAPH-003: Alert on forbidden path detection
/// </summary>
module GraphVerification =

    /// Node types in the access control graph
    type NodeType =
        | Agent of string       // AI agent (Claude, Gemini, etc.)
        | Method of string      // Access method (Read, Write, Execute)
        | File of string        // File path
        | Decision of string    // Decision point (Guardian approval, etc.)

    /// Node in the graph with unique identifier
    type Node = {
        Id: int
        Type: NodeType
        Label: string
    }

    /// Edge types representing permissions
    type EdgeType =
        | Allowed               // Explicit allow
        | Denied                // Explicit deny
        | Conditional of string // Conditional on some condition

    /// Edge connecting two nodes with permission type
    type Edge = {
        From: int
        To: int
        Type: EdgeType
        Weight: float
    }

    /// Access control graph structure
    type Graph = {
        Nodes: Map<int, Node>
        Edges: Edge list
        AdjacencyList: Map<int, int list>
        ReverseAdjacencyList: Map<int, int list>
    }

    /// Verification result with proof path
    type VerificationResult =
        | Valid of string
        | Invalid of string * int list  // Message + proof path

    /// Graph statistics for analysis
    type GraphStats = {
        NodeCount: int
        EdgeCount: int
        Density: float
        MaxDegree: int
        AverageDegree: float
        HasCycles: bool
        StronglyConnectedComponents: int
    }

    // ==================== GRAPH CONSTRUCTION ====================

    /// Create an empty graph
    let emptyGraph: Graph = {
        Nodes = Map.empty
        Edges = []
        AdjacencyList = Map.empty
        ReverseAdjacencyList = Map.empty
    }

    /// Add a node to the graph
    let addNode (node: Node) (graph: Graph): Graph =
        { graph with
            Nodes = graph.Nodes |> Map.add node.Id node
            AdjacencyList = graph.AdjacencyList |> Map.add node.Id []
            ReverseAdjacencyList = graph.ReverseAdjacencyList |> Map.add node.Id []
        }

    /// Add an edge to the graph
    let addEdge (edge: Edge) (graph: Graph): Graph =
        let updateAdjList nodeId targetId adjList =
            match Map.tryFind nodeId adjList with
            | Some neighbors -> Map.add nodeId (targetId :: neighbors) adjList
            | None -> Map.add nodeId [targetId] adjList

        { graph with
            Edges = edge :: graph.Edges
            AdjacencyList = updateAdjList edge.From edge.To graph.AdjacencyList
            ReverseAdjacencyList = updateAdjList edge.To edge.From graph.ReverseAdjacencyList
        }

    /// Build graph from configuration
    let buildGraphFromConfig (agents: string list) (methods: string list) (files: string list): Graph =
        let mutable nodeId = 0
        let mutable graph = emptyGraph

        // Add agent nodes
        for agent in agents do
            let node = { Id = nodeId; Type = Agent agent; Label = agent }
            graph <- addNode node graph
            nodeId <- nodeId + 1

        // Add method nodes
        for method in methods do
            let node = { Id = nodeId; Type = Method method; Label = method }
            graph <- addNode node graph
            nodeId <- nodeId + 1

        // Add file nodes
        for file in files do
            let node = { Id = nodeId; Type = File file; Label = file }
            graph <- addNode node graph
            nodeId <- nodeId + 1

        graph

    // ==================== GRAPH ALGORITHMS ====================

    /// Depth-First Search from a starting node
    let rec dfs (nodeId: int) (visited: Set<int>) (graph: Graph): Set<int> =
        if Set.contains nodeId visited then
            visited
        else
            let newVisited = Set.add nodeId visited
            match Map.tryFind nodeId graph.AdjacencyList with
            | Some neighbors ->
                neighbors |> List.fold (fun acc neighbor -> dfs neighbor acc graph) newVisited
            | None -> newVisited

    /// Breadth-First Search to find shortest path
    let bfs (startId: int) (targetId: int) (graph: Graph): int list option =
        let queue = Queue<int * int list>()
        queue.Enqueue((startId, [startId]))
        let mutable visited = Set.singleton startId
        let mutable result = None

        while queue.Count > 0 && result.IsNone do
            let (current, path) = queue.Dequeue()

            if current = targetId then
                result <- Some (List.rev path)
            else
                match Map.tryFind current graph.AdjacencyList with
                | Some neighbors ->
                    for neighbor in neighbors do
                        if not (Set.contains neighbor visited) then
                            visited <- Set.add neighbor visited
                            queue.Enqueue((neighbor, neighbor :: path))
                | None -> ()

        result

    /// Detect cycles using DFS and recursion stack
    let detectCycles (graph: Graph): bool =
        let mutable visited = Set.empty
        let mutable recStack = Set.empty
        let mutable hasCycle = false

        let rec dfsVisit nodeId =
            if not hasCycle then
                visited <- Set.add nodeId visited
                recStack <- Set.add nodeId recStack

                match Map.tryFind nodeId graph.AdjacencyList with
                | Some neighbors ->
                    for neighbor in neighbors do
                        if not (Set.contains neighbor visited) then
                            dfsVisit neighbor
                        elif Set.contains neighbor recStack then
                            hasCycle <- true
                | None -> ()

                recStack <- Set.remove nodeId recStack

        for node in graph.Nodes.Keys do
            if not (Set.contains node visited) && not hasCycle then
                dfsVisit node

        hasCycle

    /// Check reachability between two nodes
    let isReachable (fromId: int) (toId: int) (graph: Graph): bool =
        let reachable = dfs fromId Set.empty graph
        Set.contains toId reachable

    /// Find all paths between two nodes (limited depth to prevent explosion)
    let findAllPaths (startId: int) (targetId: int) (maxDepth: int) (graph: Graph): int list list =
        let rec findPathsRec current path depth =
            if depth > maxDepth then
                []
            elif current = targetId then
                [List.rev (current :: path)]
            else
                match Map.tryFind current graph.AdjacencyList with
                | Some neighbors ->
                    if List.contains current path then
                        [] // Cycle detected, stop
                    else
                        neighbors
                        |> List.collect (fun neighbor -> findPathsRec neighbor (current :: path) (depth + 1))
                | None -> []

        findPathsRec startId [] 0

    /// Tarjan's algorithm for strongly connected components
    let findStronglyConnectedComponents (graph: Graph): int list list =
        let mutable index = 0
        let mutable stack = []
        let mutable indices = Map.empty
        let mutable lowLinks = Map.empty
        let mutable onStack = Set.empty
        let mutable components = []

        let rec strongConnect v =
            indices <- Map.add v index indices
            lowLinks <- Map.add v index lowLinks
            index <- index + 1
            stack <- v :: stack
            onStack <- Set.add v onStack

            match Map.tryFind v graph.AdjacencyList with
            | Some neighbors ->
                for w in neighbors do
                    if not (Map.containsKey w indices) then
                        strongConnect w
                        let vLow = Map.find v lowLinks
                        let wLow = Map.find w lowLinks
                        lowLinks <- Map.add v (min vLow wLow) lowLinks
                    elif Set.contains w onStack then
                        let vLow = Map.find v lowLinks
                        let wIndex = Map.find w indices
                        lowLinks <- Map.add v (min vLow wIndex) lowLinks
            | None -> ()

            if Map.find v lowLinks = Map.find v indices then
                let mutable sccComponent = []
                let mutable w = -1
                while w <> v do
                    w <- List.head stack
                    stack <- List.tail stack
                    onStack <- Set.remove w onStack
                    sccComponent <- w :: sccComponent
                components <- sccComponent :: components

        for node in graph.Nodes.Keys do
            if not (Map.containsKey node indices) then
                strongConnect node

        components

    /// Calculate node degree (in + out)
    let nodeDegree (nodeId: int) (graph: Graph): int =
        let outDegree =
            match Map.tryFind nodeId graph.AdjacencyList with
            | Some neighbors -> List.length neighbors
            | None -> 0

        let inDegree =
            match Map.tryFind nodeId graph.ReverseAdjacencyList with
            | Some neighbors -> List.length neighbors
            | None -> 0

        outDegree + inDegree

    /// Calculate betweenness centrality (simplified)
    let betweennessCentrality (nodeId: int) (graph: Graph): float =
        // Count how many shortest paths pass through this node
        let mutable pathCount = 0.0
        let mutable totalPaths = 0.0

        for source in graph.Nodes.Keys do
            for target in graph.Nodes.Keys do
                if source <> target && source <> nodeId && target <> nodeId then
                    let paths = findAllPaths source target 10 graph
                    totalPaths <- totalPaths + float (List.length paths)
                    let pathsThrough = paths |> List.filter (List.contains nodeId)
                    pathCount <- pathCount + float (List.length pathsThrough)

        if totalPaths > 0.0 then pathCount / totalPaths else 0.0

    // ==================== VERIFICATION FUNCTIONS ====================

    /// Verify no forbidden path exists from agent to file without proper method
    let verifyNoForbiddenPath (agentId: int) (fileId: int) (requiredMethod: int option) (graph: Graph): VerificationResult =
        let startTime = DateTime.UtcNow

        match bfs agentId fileId graph with
        | None ->
            Valid "No path exists from agent to file (access correctly denied)"
        | Some path ->
            // Check if required method is in path
            match requiredMethod with
            | None ->
                Invalid ("Direct path exists without any method check", path)
            | Some methodId ->
                if List.contains methodId path then
                    Valid "Path includes required method verification"
                else
                    Invalid ("Path exists but bypasses required method", path)
        |> fun result ->
            let elapsed = (DateTime.UtcNow - startTime).TotalMilliseconds
            if elapsed > 100.0 then
                printfn "WARNING: SC-GRAPH-004 violation - verification took %.2fms" elapsed
            result

    /// Verify all agents have decision paths (SC-GRAPH-002)
    let verifyCompleteness (graph: Graph): VerificationResult =
        let agents = graph.Nodes |> Map.toList |> List.filter (fun (_, node) -> match node.Type with Agent _ -> true | _ -> false)
        let decisions = graph.Nodes |> Map.toList |> List.filter (fun (_, node) -> match node.Type with Decision _ -> true | _ -> false)

        if List.isEmpty decisions then
            Invalid ("No decision nodes found in graph", [])
        else
            let agentsWithoutDecisions =
                agents
                |> List.filter (fun (agentId, _) ->
                    decisions |> List.forall (fun (decId, _) -> not (isReachable agentId decId graph)))
                |> List.map fst

            if List.isEmpty agentsWithoutDecisions then
                Valid "All agents have decision paths"
            else
                Invalid ($"Agents without decision paths: {agentsWithoutDecisions}", agentsWithoutDecisions)

    /// Verify soundness - no path allows unauthorized access
    let verifySoundness (forbiddenPairs: (int * int) list) (graph: Graph): VerificationResult =
        let violations =
            forbiddenPairs
            |> List.choose (fun (fromId, toId) ->
                match bfs fromId toId graph with
                | Some path -> Some (fromId, toId, path)
                | None -> None)

        if List.isEmpty violations then
            Valid "No forbidden paths exist (SC-GRAPH-003)"
        else
            let (fromId, toId, path) = List.head violations
            Invalid ($"Forbidden path found from {fromId} to {toId}", path)

    /// Verify no deadlocks (circular blocking)
    let verifyDeadlockFree (graph: Graph): VerificationResult =
        if detectCycles graph then
            Invalid ("Circular dependency detected in permissions (SC-GRAPH-001)", [])
        else
            Valid "Graph is DAG - no circular dependencies"

    /// Verify all critical services are reachable
    let verifyServiceConnectivity (serviceIds: int list) (graph: Graph): VerificationResult =
        let unreachablePairs =
            serviceIds
            |> List.allPairs serviceIds
            |> List.filter (fun (a, b) -> a <> b && not (isReachable a b graph))

        if List.isEmpty unreachablePairs then
            Valid "All critical services are connected (SC-GRAPH-005)"
        else
            let (fromId, toId) = List.head unreachablePairs
            Invalid ($"Service {fromId} cannot reach service {toId}", [fromId; toId])

    // ==================== GRAPH ANALYSIS ====================

    /// Calculate graph statistics
    let calculateStats (graph: Graph): GraphStats =
        let nodeCount = Map.count graph.Nodes
        let edgeCount = List.length graph.Edges

        let density =
            if nodeCount > 1 then
                float edgeCount / float (nodeCount * (nodeCount - 1))
            else
                0.0

        let degrees = graph.Nodes.Keys |> Seq.map (fun id -> nodeDegree id graph) |> Seq.toList
        let maxDegree = if List.isEmpty degrees then 0 else List.max degrees
        let avgDegree = if List.isEmpty degrees then 0.0 else float (List.sum degrees) / float (List.length degrees)

        let hasCycles = detectCycles graph
        let sccs = findStronglyConnectedComponents graph

        {
            NodeCount = nodeCount
            EdgeCount = edgeCount
            Density = density
            MaxDegree = maxDegree
            AverageDegree = avgDegree
            HasCycles = hasCycles
            StronglyConnectedComponents = List.length sccs
        }

    /// Find minimum cut (critical permission points)
    let findMinimumCut (sourceId: int) (sinkId: int) (graph: Graph): int list =
        // Simplified min-cut: find nodes whose removal disconnects source from sink
        let mutable criticalNodes = []

        for nodeId in graph.Nodes.Keys do
            if nodeId <> sourceId && nodeId <> sinkId then
                // Remove node temporarily
                let tempGraph = {
                    graph with
                        AdjacencyList = graph.AdjacencyList |> Map.remove nodeId
                        ReverseAdjacencyList = graph.ReverseAdjacencyList |> Map.remove nodeId
                }

                // Check if source can still reach sink
                if not (isReachable sourceId sinkId tempGraph) then
                    criticalNodes <- nodeId :: criticalNodes

        criticalNodes

    /// Identify high-centrality nodes (critical agents/resources)
    let findCriticalNodes (threshold: float) (graph: Graph): (int * float) list =
        graph.Nodes.Keys
        |> Seq.map (fun nodeId -> (nodeId, betweennessCentrality nodeId graph))
        |> Seq.filter (fun (_, centrality) -> centrality >= threshold)
        |> Seq.sortByDescending snd
        |> Seq.toList

    // ==================== DOT EXPORT ====================

    /// Generate DOT format for visualization
    let toDot (graph: Graph): string =
        let sb = StringBuilder()
        sb.AppendLine("digraph AccessControl {") |> ignore
        sb.AppendLine("  rankdir=LR;") |> ignore
        sb.AppendLine("  node [shape=box];") |> ignore

        // Add nodes with colors based on type
        for (nodeId, node) in Map.toList graph.Nodes do
            let color =
                match node.Type with
                | Agent _ -> "lightblue"
                | Method _ -> "lightgreen"
                | File _ -> "lightyellow"
                | Decision _ -> "lightcoral"

            let shape =
                match node.Type with
                | Decision _ -> "diamond"
                | _ -> "box"

            sb.AppendLine($"  {nodeId} [label=\"{node.Label}\", fillcolor=\"{color}\", style=filled, shape={shape}];") |> ignore

        // Add edges with colors based on type
        for edge in graph.Edges do
            let (color, style) =
                match edge.Type with
                | Allowed -> ("green", "solid")
                | Denied -> ("red", "dashed")
                | Conditional c -> ("orange", "dotted")

            sb.AppendLine($"  {edge.From} -> {edge.To} [color=\"{color}\", style={style}];") |> ignore

        sb.AppendLine("}") |> ignore
        sb.ToString()

    // ==================== RUNTIME VERIFICATION ====================

    /// Build graph from current runtime state
    let buildRuntimeGraph (agents: string list) (methods: string list) (files: string list)
                         (permissions: (string * string * string * EdgeType) list): Graph =
        let mutable graph = buildGraphFromConfig agents methods files

        // Create node lookup by label
        let nodesByLabel =
            graph.Nodes
            |> Map.toList
            |> List.map (fun (id, node) -> (node.Label, id))
            |> Map.ofList

        // Add permission edges
        for (agentLabel, methodLabel, fileLabel, edgeType) in permissions do
            match Map.tryFind agentLabel nodesByLabel, Map.tryFind methodLabel nodesByLabel, Map.tryFind fileLabel nodesByLabel with
            | Some agentId, Some methodId, Some fileId ->
                // Agent -> Method -> File
                graph <- addEdge { From = agentId; To = methodId; Type = edgeType; Weight = 1.0 } graph
                graph <- addEdge { From = methodId; To = fileId; Type = edgeType; Weight = 1.0 } graph
            | _ ->
                printfn "WARNING: Permission references unknown node: %s/%s/%s" agentLabel methodLabel fileLabel

        graph

    /// Run comprehensive verification suite
    let runVerificationSuite (graph: Graph) (criticalServices: int list) (forbiddenPairs: (int * int) list): VerificationResult list =
        let startTime = DateTime.UtcNow

        let results = [
            verifyDeadlockFree graph
            verifyCompleteness graph
            verifySoundness forbiddenPairs graph
            verifyServiceConnectivity criticalServices graph
        ]

        let elapsed = (DateTime.UtcNow - startTime).TotalMilliseconds
        printfn "Graph verification suite completed in %.2fms" elapsed

        if elapsed > 100.0 then
            printfn "WARNING: SC-GRAPH-004 violation - total verification time exceeded 100ms"

        // AOR-GRAPH-002: Log all verification results
        for result in results do
            match result with
            | Valid msg -> printfn "✓ %s" msg
            | Invalid (msg, path) ->
                printfn "✗ %s" msg
                if not (List.isEmpty path) then
                    printfn "  Proof path: %A" path
                // AOR-GRAPH-003: Alert on forbidden path detection
                printfn "ALERT: Forbidden path detected in access control graph!"

        results

    /// Generate verification report
    let generateReport (graph: Graph) (results: VerificationResult list) (stats: GraphStats): string =
        let sb = StringBuilder()
        sb.AppendLine("=== ACCESS CONTROL GRAPH VERIFICATION REPORT ===") |> ignore
        sb.AppendLine() |> ignore

        sb.AppendLine("Graph Statistics:") |> ignore
        sb.AppendLine($"  Nodes: {stats.NodeCount}") |> ignore
        sb.AppendLine($"  Edges: {stats.EdgeCount}") |> ignore
        sb.AppendLine($"  Density: {stats.Density:F4}") |> ignore
        sb.AppendLine($"  Max Degree: {stats.MaxDegree}") |> ignore
        sb.AppendLine($"  Avg Degree: {stats.AverageDegree:F2}") |> ignore
        sb.AppendLine($"  Has Cycles: {stats.HasCycles}") |> ignore
        sb.AppendLine($"  SCCs: {stats.StronglyConnectedComponents}") |> ignore
        sb.AppendLine() |> ignore

        sb.AppendLine("Verification Results:") |> ignore
        let validCount = results |> List.filter (function Valid _ -> true | _ -> false) |> List.length
        let invalidCount = results |> List.filter (function Invalid _ -> true | _ -> false) |> List.length
        sb.AppendLine($"  Passed: {validCount}/{List.length results}") |> ignore
        sb.AppendLine($"  Failed: {invalidCount}/{List.length results}") |> ignore
        sb.AppendLine() |> ignore

        for result in results do
            match result with
            | Valid msg -> sb.AppendLine($"  ✓ {msg}") |> ignore
            | Invalid (msg, path) ->
                sb.AppendLine($"  ✗ {msg}") |> ignore
                if not (List.isEmpty path) then
                    sb.AppendLine($"    Path: {path}") |> ignore

        sb.ToString()
