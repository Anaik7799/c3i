// =============================================================================
// MathematicalStartupOptimization.fs - Formal Mathematical Models for Startup
// =============================================================================
// VERSION: 21.2.4-SIL6 | 2026-01-18T16:00:00Z
// STAMP: SC-MATH-001 to SC-MATH-050
// AOR: AOR-MATH-001 to AOR-MATH-020
// Criticality: Level 0 (CRITICAL) - Mathematical Foundation
// =============================================================================
// Implements formal mathematical techniques for distributed system startup:
// 1. Graph Theory (DAG, Topological Sort, Cycle Detection, Transitive Reduction)
// 2. Critical Path Method (CPM) with ES/EF/LS/LF/Slack calculations
// 3. Resource Constrained Project Scheduling (RCPSP)
// 4. Finite State Automata (DFA) for container lifecycle
// 5. Set Theory for configuration management
// =============================================================================

namespace Cepaf.Planning.Mathematical

open System
open System.Collections.Generic

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 1: 10-DEGREE FRACTAL ANALYSIS FRAMEWORK
// ═══════════════════════════════════════════════════════════════════════════════

/// The 7 Fractal Layers (L0-L7) of the system
type FractalLayer =
    | L0_Runtime        // System compiles and boots
    | L1_Function       // I/O contracts valid
    | L2_Component      // Module cohesion
    | L3_Holon          // Agent logic sound
    | L4_Container      // Isolation maintained
    | L5_Node           // Runtime stable
    | L6_Cluster        // Consensus holds
    | L7_Federation     // Global invariants

/// The 10 Interaction Degrees for comprehensive analysis
type InteractionDegree =
    | D1_Immediate      // Direct action occurs (0-100ms)
    | D2_Adjacent       // Adjacent systems react (100ms-1s)
    | D3_Integration    // System integration effects (1-10s)
    | D4_Operational    // Capabilities unlock (10-60s)
    | D5_Ecosystem      // Ecosystem effects (1-5min)
    | D6_Behavioral     // Behavioral patterns emerge (5-30min)
    | D7_Adaptive       // Adaptive responses (30min-2h)
    | D8_Evolutionary   // Evolutionary changes (2-24h)
    | D9_Generational   // Generational learning (days-weeks)
    | D10_Existential   // Existential impact (weeks-months)

/// Utility functions for fractal analysis types
module FractalUtils =
    /// Convert FractalLayer to int for indexing
    let fractalLayerToInt (layer: FractalLayer) : int =
        match layer with
        | L0_Runtime -> 0 | L1_Function -> 1 | L2_Component -> 2 | L3_Holon -> 3
        | L4_Container -> 4 | L5_Node -> 5 | L6_Cluster -> 6 | L7_Federation -> 7

    /// Convert InteractionDegree to int for indexing
    let interactionDegreeToInt (degree: InteractionDegree) : int =
        match degree with
        | D1_Immediate -> 1 | D2_Adjacent -> 2 | D3_Integration -> 3 | D4_Operational -> 4
        | D5_Ecosystem -> 5 | D6_Behavioral -> 6 | D7_Adaptive -> 7 | D8_Evolutionary -> 8
        | D9_Generational -> 9 | D10_Existential -> 10

/// Mathematical technique categories
type MathematicalTechnique =
    | GraphTheory           // DAG, Topological Sort, Cycle Detection
    | CriticalPathMethod    // CPM, ES/EF/LS/LF, Slack
    | RCPSP                 // Resource Constrained Scheduling
    | FiniteStateAutomata   // DFA, State Transitions
    | SetTheory             // Configuration Operations

/// The 7x10x5 Fractal-Interaction-Math Matrix Cell
type FractalInteractionCell = {
    Layer: FractalLayer
    Degree: InteractionDegree
    Technique: MathematicalTechnique
    Constraint: string          // SC-* constraint
    Rule: string                // AOR-* rule
    Implementation: string      // F# function/module
    Verified: bool
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 2: GRAPH THEORY (SC-GRAPH-001 to SC-GRAPH-010)
// ═══════════════════════════════════════════════════════════════════════════════

/// Directed Acyclic Graph for startup dependencies
module DirectedGraph =

    /// Vertex in the DAG representing a service/container
    type Vertex<'T> = {
        Id: string
        Data: 'T
        Criticality: int        // 0 = highest, 3 = lowest
        EstimatedDurationMs: int
    }

    /// Edge representing a dependency relationship
    type Edge = {
        From: string            // Dependency
        To: string              // Dependent
        Weight: float           // Strength of dependency (1.0 = hard, 0.5 = soft)
        EdgeType: EdgeType
    }
    and EdgeType =
        | Requires              // Hard dependency (must succeed)
        | After                 // Soft dependency (wait if available)
        | Wants                 // Optional (nice to have)

    /// The complete directed graph
    type Graph<'T> = {
        Vertices: Map<string, Vertex<'T>>
        Edges: Edge list
        AdjacencyList: Map<string, string list>         // Forward edges
        ReverseAdjacencyList: Map<string, string list>  // Backward edges
    }

    /// Build adjacency lists from edges
    let buildAdjacencyLists (vertices: Map<string, Vertex<'T>>) (edges: Edge list) =
        let forward =
            edges
            |> List.groupBy (fun e -> e.From)
            |> List.map (fun (from, es) -> from, es |> List.map (fun e -> e.To))
            |> Map.ofList
        let reverse =
            edges
            |> List.groupBy (fun e -> e.To)
            |> List.map (fun (to_, es) -> to_, es |> List.map (fun e -> e.From))
            |> Map.ofList
        forward, reverse

    /// Create a graph from vertices and edges
    let create (vertices: Vertex<'T> list) (edges: Edge list) : Graph<'T> =
        let vertexMap = vertices |> List.map (fun v -> v.Id, v) |> Map.ofList
        let forward, reverse = buildAdjacencyLists vertexMap edges
        {
            Vertices = vertexMap
            Edges = edges
            AdjacencyList = forward
            ReverseAdjacencyList = reverse
        }

    /// Get all vertices with no incoming edges (roots/Gen-0)
    let getRoots (graph: Graph<'T>) : string list =
        graph.Vertices
        |> Map.toList
        |> List.map fst
        |> List.filter (fun id ->
            not (Map.containsKey id graph.ReverseAdjacencyList) ||
            (Map.find id graph.ReverseAdjacencyList).IsEmpty)

    /// Get successors of a vertex
    let getSuccessors (graph: Graph<'T>) (vertexId: string) : string list =
        graph.AdjacencyList
        |> Map.tryFind vertexId
        |> Option.defaultValue []

    /// Get predecessors of a vertex
    let getPredecessors (graph: Graph<'T>) (vertexId: string) : string list =
        graph.ReverseAdjacencyList
        |> Map.tryFind vertexId
        |> Option.defaultValue []

/// Topological Sort using Kahn's Algorithm (SC-GRAPH-001)
module TopologicalSort =

    open DirectedGraph

    /// Result of topological sort - either sorted order or cycle info
    type SortResult =
        | Sorted of generations: string list list   // List of generations (waves)
        | CycleDetected of cycle: string list       // Cycle path

    /// Kahn's algorithm for topological sort with generation grouping
    /// Returns List of "Generations" where Gen-N depends only on Gen-0..Gen-(N-1)
    let kahnSort (graph: Graph<'T>) : SortResult =
        let inDegree = Dictionary<string, int>()

        // Initialize in-degrees
        for kvp in graph.Vertices do
            inDegree.[kvp.Key] <- 0

        for edge in graph.Edges do
            if inDegree.ContainsKey edge.To then
                inDegree.[edge.To] <- inDegree.[edge.To] + 1

        // Find all Gen-0 (no dependencies)
        let mutable queue = Queue<string>()
        let mutable generations = []
        let mutable currentGen = []

        for kvp in inDegree do
            if kvp.Value = 0 then
                currentGen <- kvp.Key :: currentGen

        if currentGen.IsEmpty then
            CycleDetected ["All vertices have dependencies - cycle exists"]
        else
            generations <- [currentGen]
            currentGen |> List.iter queue.Enqueue

            let mutable processedCount = currentGen.Length
            currentGen <- []
            let mutable nextGen = []

            while queue.Count > 0 do
                let node = queue.Dequeue()

                // Reduce in-degree of successors
                for successor in getSuccessors graph node do
                    if inDegree.ContainsKey successor then
                        inDegree.[successor] <- inDegree.[successor] - 1
                        if inDegree.[successor] = 0 then
                            nextGen <- successor :: nextGen

                // Check if current generation is complete
                if queue.Count = 0 && not nextGen.IsEmpty then
                    generations <- generations @ [nextGen]
                    processedCount <- processedCount + nextGen.Length
                    nextGen |> List.iter queue.Enqueue
                    nextGen <- []

            if processedCount <> graph.Vertices.Count then
                // Not all vertices processed - cycle exists
                let remaining =
                    inDegree
                    |> Seq.filter (fun kvp -> kvp.Value > 0)
                    |> Seq.map (fun kvp -> kvp.Key)
                    |> Seq.toList
                CycleDetected remaining
            else
                Sorted generations

    /// Flatten generations to linear order
    let flattenGenerations (generations: string list list) : string list =
        generations |> List.concat

/// Cycle Detection using DFS (SC-GRAPH-002)
module CycleDetection =

    open DirectedGraph

    type CycleResult =
        | NoCycle
        | HasCycle of path: string list

    /// Detect cycles using DFS with color marking
    /// White = unvisited, Gray = in progress, Black = complete
    let detectCycle (graph: Graph<'T>) : CycleResult =
        let color = Dictionary<string, int>()  // 0=white, 1=gray, 2=black
        let parent = Dictionary<string, string option>()

        for kvp in graph.Vertices do
            color.[kvp.Key] <- 0
            parent.[kvp.Key] <- None

        let rec dfs (node: string) (path: string list) : CycleResult =
            color.[node] <- 1  // Mark gray (in progress)

            let successors = getSuccessors graph node
            let mutable result = NoCycle

            for successor in successors do
                if result = NoCycle then
                    match color.TryGetValue(successor) with
                    | true, 1 ->
                        // Found back edge - cycle detected
                        let cyclePath = node :: path |> List.rev
                        result <- HasCycle (cyclePath @ [successor])
                    | true, 0 ->
                        // Unvisited - recurse
                        parent.[successor] <- Some node
                        result <- dfs successor (node :: path)
                    | _ -> ()  // Already complete (black)

            color.[node] <- 2  // Mark black (complete)
            result

        // Start DFS from each unvisited vertex
        let mutable finalResult = NoCycle
        for kvp in graph.Vertices do
            if finalResult = NoCycle && color.[kvp.Key] = 0 then
                finalResult <- dfs kvp.Key []

        finalResult

/// Transitive Reduction (SC-GRAPH-003)
module TransitiveReduction =

    open DirectedGraph

    /// Remove edges that are implied by other paths
    /// If A → B and B → C, then A → C is redundant
    let reduce (graph: Graph<'T>) : Edge list =
        let reachable = Dictionary<string, Set<string>>()

        // Compute transitive closure using Floyd-Warshall style
        let rec computeReachable (node: string) : Set<string> =
            if reachable.ContainsKey node then
                reachable.[node]
            else
                let successors = getSuccessors graph node
                let directReach = Set.ofList successors
                let transitiveReach =
                    successors
                    |> List.map computeReachable
                    |> List.fold Set.union directReach
                reachable.[node] <- transitiveReach
                transitiveReach

        for kvp in graph.Vertices do
            computeReachable kvp.Key |> ignore

        // Keep only edges that are not transitively implied
        graph.Edges
        |> List.filter (fun edge ->
            let otherSuccessors =
                getSuccessors graph edge.From
                |> List.filter (fun s -> s <> edge.To)

            // Edge A→B is redundant if B is reachable from any other successor of A
            not (otherSuccessors |> List.exists (fun s ->
                reachable.ContainsKey s && Set.contains edge.To reachable.[s])))

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 3: CRITICAL PATH METHOD (SC-CPM-001 to SC-CPM-010)
// ═══════════════════════════════════════════════════════════════════════════════

/// Critical Path Method for boot time optimization
module CriticalPathMethod =

    open DirectedGraph

    /// Timing information for a task
    type TaskTiming = {
        TaskId: string
        Duration: int               // Duration in milliseconds
        EarliestStart: int          // ES = max(EF of predecessors)
        EarliestFinish: int         // EF = ES + Duration
        LatestStart: int            // LS = LF - Duration
        LatestFinish: int           // LF = min(LS of successors)
        Slack: int                  // Slack = LS - ES = LF - EF
        IsCritical: bool            // Slack = 0
    }

    /// CPM calculation result
    type CPMResult = {
        Timings: Map<string, TaskTiming>
        CriticalPath: string list   // Tasks with zero slack
        TotalDuration: int          // Makespan
        BottleneckTask: string      // Longest single task on critical path
        ParallelismFactor: float    // Sum(durations) / TotalDuration
    }

    /// Forward pass: Calculate ES and EF
    let forwardPass (graph: Graph<'T>) (durations: Map<string, int>) : Map<string, int * int> =
        let timing = Dictionary<string, int * int>()  // (ES, EF)

        // Process in topological order
        match TopologicalSort.kahnSort graph with
        | TopologicalSort.CycleDetected _ -> Map.empty
        | TopologicalSort.Sorted generations ->
            for gen in generations do
                for taskId in gen do
                    let predecessors = getPredecessors graph taskId
                    let es =
                        if predecessors.IsEmpty then 0
                        else
                            predecessors
                            |> List.map (fun p ->
                                match timing.TryGetValue(p) with
                                | true, (_, ef) -> ef
                                | _ -> 0)
                            |> List.max
                    let duration = durations |> Map.tryFind taskId |> Option.defaultValue 0
                    let ef = es + duration
                    timing.[taskId] <- (es, ef)

            timing |> Seq.map (fun kvp -> kvp.Key, kvp.Value) |> Map.ofSeq

    /// Backward pass: Calculate LS and LF
    let backwardPass (graph: Graph<'T>) (durations: Map<string, int>)
                     (forwardTimings: Map<string, int * int>) : Map<string, int * int> =
        let timing = Dictionary<string, int * int>()  // (LS, LF)

        // Find project end time
        let projectEnd =
            forwardTimings
            |> Map.toSeq
            |> Seq.map (fun (_, (_, ef)) -> ef)
            |> Seq.max

        // Process in reverse topological order
        match TopologicalSort.kahnSort graph with
        | TopologicalSort.CycleDetected _ -> Map.empty
        | TopologicalSort.Sorted generations ->
            let reversed = generations |> List.rev
            for gen in reversed do
                for taskId in gen do
                    let successors = getSuccessors graph taskId
                    let lf =
                        if successors.IsEmpty then projectEnd
                        else
                            successors
                            |> List.map (fun s ->
                                match timing.TryGetValue(s) with
                                | true, (ls, _) -> ls
                                | _ -> projectEnd)
                            |> List.min
                    let duration = durations |> Map.tryFind taskId |> Option.defaultValue 0
                    let ls = lf - duration
                    timing.[taskId] <- (ls, lf)

            timing |> Seq.map (fun kvp -> kvp.Key, kvp.Value) |> Map.ofSeq

    /// Calculate full CPM analysis
    let calculate (graph: Graph<'T>) (durations: Map<string, int>) : CPMResult =
        let forward = forwardPass graph durations
        let backward = backwardPass graph durations forward

        let timings =
            graph.Vertices
            |> Map.toList
            |> List.map (fun (id, _) ->
                let duration = durations |> Map.tryFind id |> Option.defaultValue 0
                let (es, ef) = forward |> Map.tryFind id |> Option.defaultValue (0, 0)
                let (ls, lf) = backward |> Map.tryFind id |> Option.defaultValue (0, 0)
                let slack = ls - es
                id, {
                    TaskId = id
                    Duration = duration
                    EarliestStart = es
                    EarliestFinish = ef
                    LatestStart = ls
                    LatestFinish = lf
                    Slack = slack
                    IsCritical = slack = 0
                })
            |> Map.ofList

        let criticalPath =
            timings
            |> Map.toList
            |> List.filter (fun (_, t) -> t.IsCritical)
            |> List.sortBy (fun (_, t) -> t.EarliestStart)
            |> List.map fst

        let totalDuration = forward |> Map.toSeq |> Seq.map (fun (_, (_, ef)) -> ef) |> Seq.max
        let totalWork = durations |> Map.toSeq |> Seq.sumBy snd

        let bottleneck =
            criticalPath
            |> List.map (fun id -> id, durations |> Map.tryFind id |> Option.defaultValue 0)
            |> List.maxBy snd
            |> fst

        {
            Timings = timings
            CriticalPath = criticalPath
            TotalDuration = totalDuration
            BottleneckTask = bottleneck
            ParallelismFactor = float totalWork / float totalDuration
        }

    /// Get optimization recommendations
    let getOptimizationRecommendations (result: CPMResult) : string list =
        [
            sprintf "Critical path: %s" (String.concat " → " result.CriticalPath)
            sprintf "Bottleneck task: %s (optimize this for 1:1 improvement)" result.BottleneckTask
            sprintf "Parallelism factor: %.2f (higher = more parallel work)" result.ParallelismFactor

            // Identify non-critical tasks
            let nonCritical =
                result.Timings
                |> Map.toList
                |> List.filter (fun (_, t) -> not t.IsCritical)
                |> List.sortByDescending (fun (_, t) -> t.Slack)

            if not nonCritical.IsEmpty then
                let (id, timing) = nonCritical.Head
                sprintf "Most slack: %s (%dms slack - optimizing this yields 0 improvement)" id timing.Slack
        ]

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 4: RESOURCE CONSTRAINED PROJECT SCHEDULING (SC-RCPSP-001 to SC-RCPSP-010)
// ═══════════════════════════════════════════════════════════════════════════════

/// Resource Constrained Project Scheduling Problem solver
module RCPSP =

    open DirectedGraph

    /// Resource type with capacity
    type Resource = {
        Id: string
        Name: string
        Capacity: int           // Available units
        Unit: string            // MB, cores, IOPS, etc.
    }

    /// Resource requirement for a task
    type ResourceRequirement = {
        TaskId: string
        ResourceId: string
        Amount: int             // Required units
    }

    /// Scheduled task with timing
    type ScheduledTask = {
        TaskId: string
        StartTime: int
        EndTime: int
        Resources: Map<string, int>   // Resource allocations
    }

    /// Resource usage at a point in time
    type ResourceUsage = {
        Time: int
        Usage: Map<string, int>       // ResourceId -> amount used
    }

    /// RCPSP schedule result
    type ScheduleResult = {
        Schedule: ScheduledTask list
        Makespan: int
        ResourceUtilization: Map<string, float>   // ResourceId -> utilization %
        BottleneckResource: string option
        Conflicts: (string * string * int) list   // (task1, task2, time) conflicts
    }

    /// Check if resources are available at time t
    let resourcesAvailable (resources: Resource list)
                           (requirements: Map<string, int>)
                           (currentUsage: Map<string, int>) : bool =
        requirements
        |> Map.forall (fun resId amount ->
            let capacity =
                resources
                |> List.tryFind (fun r -> r.Id = resId)
                |> Option.map (fun r -> r.Capacity)
                |> Option.defaultValue 0
            let used = currentUsage |> Map.tryFind resId |> Option.defaultValue 0
            used + amount <= capacity)

    /// List scheduling heuristic for RCPSP
    let listSchedule (graph: Graph<'T>)
                     (durations: Map<string, int>)
                     (resources: Resource list)
                     (requirements: ResourceRequirement list) : ScheduleResult =

        let reqByTask =
            requirements
            |> List.groupBy (fun r -> r.TaskId)
            |> List.map (fun (tid, reqs) ->
                tid, reqs |> List.map (fun r -> r.ResourceId, r.Amount) |> Map.ofList)
            |> Map.ofList

        let schedule = ResizeArray<ScheduledTask>()
        let resourceTimeline = Dictionary<int, Map<string, int>>()  // time -> usage

        let getUsageAtTime t =
            if resourceTimeline.ContainsKey t then resourceTimeline.[t]
            else Map.empty

        let updateUsage startTime endTime taskReqs =
            for t in startTime .. endTime - 1 do
                let current = getUsageAtTime t
                let updated =
                    taskReqs
                    |> Map.fold (fun acc resId amount ->
                        let cur = acc |> Map.tryFind resId |> Option.defaultValue 0
                        Map.add resId (cur + amount) acc) current
                resourceTimeline.[t] <- updated

        // Process in topological order
        match TopologicalSort.kahnSort graph with
        | TopologicalSort.CycleDetected _ ->
            { Schedule = []; Makespan = 0; ResourceUtilization = Map.empty
              BottleneckResource = None; Conflicts = [] }
        | TopologicalSort.Sorted generations ->
            for gen in generations do
                for taskId in gen do
                    let duration = durations |> Map.tryFind taskId |> Option.defaultValue 0
                    let taskReqs = reqByTask |> Map.tryFind taskId |> Option.defaultValue Map.empty

                    // Find earliest feasible start time
                    let predecessorEnd =
                        getPredecessors graph taskId
                        |> List.map (fun p ->
                            schedule
                            |> Seq.tryFind (fun s -> s.TaskId = p)
                            |> Option.map (fun s -> s.EndTime)
                            |> Option.defaultValue 0)
                        |> function [] -> 0 | xs -> List.max xs

                    // Find first time slot where resources are available
                    let mutable startTime = predecessorEnd
                    let mutable found = false
                    while not found && startTime < 1000000 do  // Safety limit
                        let canSchedule =
                            [startTime .. startTime + duration - 1]
                            |> List.forall (fun t ->
                                resourcesAvailable resources taskReqs (getUsageAtTime t))
                        if canSchedule then
                            found <- true
                        else
                            startTime <- startTime + 1

                    let endTime = startTime + duration
                    updateUsage startTime endTime taskReqs

                    schedule.Add({
                        TaskId = taskId
                        StartTime = startTime
                        EndTime = endTime
                        Resources = taskReqs
                    })

            let makespan =
                schedule
                |> Seq.map (fun s -> s.EndTime)
                |> Seq.max

            // Calculate resource utilization
            let utilization =
                resources
                |> List.map (fun res ->
                    let totalUsed =
                        [0 .. makespan]
                        |> List.sumBy (fun t ->
                            getUsageAtTime t
                            |> Map.tryFind res.Id
                            |> Option.defaultValue 0)
                    let maxPossible = res.Capacity * makespan
                    res.Id, if maxPossible > 0 then float totalUsed / float maxPossible else 0.0)
                |> Map.ofList

            let bottleneck =
                utilization
                |> Map.toList
                |> List.maxBy snd
                |> fun (id, util) -> if util > 0.8 then Some id else None

            {
                Schedule = schedule |> Seq.toList
                Makespan = makespan
                ResourceUtilization = utilization
                BottleneckResource = bottleneck
                Conflicts = []
            }

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 5: FINITE STATE AUTOMATA (SC-DFA-001 to SC-DFA-010)
// ═══════════════════════════════════════════════════════════════════════════════

/// Deterministic Finite Automaton for container lifecycle
module ContainerDFA =

    /// Container lifecycle states (Q)
    type State =
        | NotCreated        // Initial state
        | Created           // Image pulled, container exists
        | Starting          // Process spawning
        | Running           // Process running but not verified
        | Healthy           // Health checks passing
        | Unhealthy         // Health checks failing
        | Degraded          // Partial functionality
        | Lameduck          // No new connections (graceful shutdown)
        | Draining          // Waiting for connections to close
        | Checkpointing     // Saving state
        | Stopping          // Process terminating
        | Stopped           // Container exited cleanly
        | Failed            // Container crashed/error
        | Removed           // Container deleted

    /// Input events/alphabet (Σ)
    type Event =
        | Create            // Create container from image
        | Start             // Start container
        | HealthPass        // Health check succeeded
        | HealthFail        // Health check failed
        | Degrade           // Partial failure detected
        | Recover           // Recovery from degraded
        | InitiateShutdown  // Begin graceful shutdown
        | DrainComplete     // All connections closed
        | CheckpointDone    // State saved
        | Stop              // Stop container
        | Kill              // Force stop container
        | Crash             // Unexpected failure
        | Remove            // Delete container
        | Restart           // Restart sequence

    /// The DFA: (Q, Σ, δ, q₀, F)
    type DFA = {
        States: Set<State>
        Alphabet: Set<Event>
        Transition: State -> Event -> State
        InitialState: State
        AcceptingStates: Set<State>   // Operational states
    }

    /// State transition function δ: Q × Σ → Q
    let transition (state: State) (event: Event) : State =
        match state, event with
        // Creation transitions
        | NotCreated, Create -> Created
        | Created, Start -> Starting
        | Created, Remove -> NotCreated

        // Startup transitions
        | Starting, HealthPass -> Healthy
        | Starting, HealthFail -> Unhealthy
        | Starting, Crash -> Failed
        | Starting, Kill -> Stopped

        // Running state transitions
        | Running, HealthPass -> Healthy
        | Running, HealthFail -> Unhealthy
        | Running, Degrade -> Degraded
        | Running, InitiateShutdown -> Lameduck
        | Running, Stop -> Stopping
        | Running, Kill -> Stopped
        | Running, Crash -> Failed

        // Healthy state transitions
        | Healthy, HealthFail -> Unhealthy
        | Healthy, Degrade -> Degraded
        | Healthy, InitiateShutdown -> Lameduck
        | Healthy, Stop -> Stopping
        | Healthy, Kill -> Stopped
        | Healthy, Crash -> Failed

        // Unhealthy state transitions
        | Unhealthy, HealthPass -> Healthy
        | Unhealthy, HealthFail -> Unhealthy  // Stay unhealthy
        | Unhealthy, Crash -> Failed
        | Unhealthy, Stop -> Stopping
        | Unhealthy, Kill -> Stopped

        // Degraded state transitions
        | Degraded, Recover -> Healthy
        | Degraded, HealthFail -> Unhealthy
        | Degraded, Crash -> Failed
        | Degraded, Stop -> Stopping

        // Graceful shutdown sequence
        | Lameduck, DrainComplete -> Draining
        | Lameduck, Kill -> Stopped
        | Lameduck, Crash -> Failed
        | Draining, CheckpointDone -> Checkpointing
        | Draining, Kill -> Stopped
        | Checkpointing, Stop -> Stopping
        | Checkpointing, Kill -> Stopped
        | Stopping, _ -> Stopped

        // Stopped state transitions
        | Stopped, Start -> Starting
        | Stopped, Remove -> Removed
        | Stopped, Restart -> Starting

        // Failed state transitions
        | Failed, Remove -> Removed
        | Failed, Restart -> Starting
        | Failed, Start -> Starting

        // Removed is terminal
        | Removed, Create -> Created

        // Invalid transition - stay in current state
        | s, _ -> s

    /// Check if transition is valid (not a self-loop)
    let isValidTransition (from: State) (event: Event) : bool =
        transition from event <> from

    /// Get all valid events from a state
    let validEvents (state: State) : Event list =
        [Create; Start; HealthPass; HealthFail; Degrade; Recover;
         InitiateShutdown; DrainComplete; CheckpointDone; Stop; Kill; Crash; Remove; Restart]
        |> List.filter (fun e -> isValidTransition state e)

    /// Check if state is accepting (operational)
    let isAccepting (state: State) : bool =
        match state with
        | Healthy | Running | Degraded -> true
        | _ -> false

    /// The complete DFA definition
    let containerDFA : DFA = {
        States = Set.ofList [
            NotCreated; Created; Starting; Running; Healthy; Unhealthy;
            Degraded; Lameduck; Draining; Checkpointing; Stopping; Stopped; Failed; Removed
        ]
        Alphabet = Set.ofList [
            Create; Start; HealthPass; HealthFail; Degrade; Recover;
            InitiateShutdown; DrainComplete; CheckpointDone; Stop; Kill; Crash; Remove; Restart
        ]
        Transition = transition
        InitialState = NotCreated
        AcceptingStates = Set.ofList [Healthy; Running; Degraded]
    }

    /// Simulate a sequence of events
    let simulate (events: Event list) : State list =
        events
        |> List.scan (fun state event -> transition state event) NotCreated

    /// Check if an event sequence leads to an accepting state
    let accepts (events: Event list) : bool =
        let finalState = events |> List.fold transition NotCreated
        isAccepting finalState

    /// Find shortest path from current state to target state
    let findPath (from: State) (target: State) : Event list option =
        let visited = HashSet<State>()
        let queue = Queue<State * Event list>()
        queue.Enqueue((from, []))

        let mutable result = None
        while queue.Count > 0 && result.IsNone do
            let (state, path) = queue.Dequeue()
            if state = target then
                result <- Some (List.rev path)
            elif not (visited.Contains state) then
                visited.Add(state) |> ignore
                for event in validEvents state do
                    let nextState = transition state event
                    if not (visited.Contains nextState) then
                        queue.Enqueue((nextState, event :: path))
        result

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 6: SET THEORY FOR CONFIGURATION (SC-SET-001 to SC-SET-010)
// ═══════════════════════════════════════════════════════════════════════════════

/// Set-theoretic operations for configuration management
module ConfigurationSets =

    /// Configuration item with source tracking
    type ConfigItem = {
        Key: string
        Value: string
        Source: string          // File/env/default
        Priority: int           // Higher = override lower
        Timestamp: DateTimeOffset
    }

    /// Configuration set from a source
    type ConfigSet = {
        Source: string
        Items: Map<string, ConfigItem>
    }

    /// Create config set from items
    let fromItems (source: string) (items: (string * string) list) : ConfigSet =
        let now = DateTimeOffset.UtcNow
        {
            Source = source
            Items =
                items
                |> List.mapi (fun i (k, v) ->
                    k, { Key = k; Value = v; Source = source; Priority = i; Timestamp = now })
                |> Map.ofList
        }

    /// Set Union: A ∪ B (B overrides A on key collision)
    let union (a: ConfigSet) (b: ConfigSet) : ConfigSet =
        let merged =
            Map.fold (fun acc key item ->
                match Map.tryFind key acc with
                | Some existing when existing.Priority >= item.Priority -> acc
                | _ -> Map.add key { item with Source = sprintf "%s+%s" a.Source b.Source } acc
            ) a.Items b.Items
        { Source = sprintf "(%s ∪ %s)" a.Source b.Source; Items = merged }

    /// Set Intersection: A ∩ B (keys present in both)
    let intersection (a: ConfigSet) (b: ConfigSet) : ConfigSet =
        let common =
            a.Items
            |> Map.filter (fun key _ -> Map.containsKey key b.Items)
        { Source = sprintf "(%s ∩ %s)" a.Source b.Source; Items = common }

    /// Set Difference: A \ B (keys only in A)
    let difference (a: ConfigSet) (b: ConfigSet) : ConfigSet =
        let diff =
            a.Items
            |> Map.filter (fun key _ -> not (Map.containsKey key b.Items))
        { Source = sprintf "(%s \\ %s)" a.Source b.Source; Items = diff }

    /// Symmetric Difference: A Δ B (keys in either but not both)
    let symmetricDifference (a: ConfigSet) (b: ConfigSet) : ConfigSet =
        let aOnly = difference a b
        let bOnly = difference b a
        union aOnly bOnly

    /// Detect configuration drift between expected and actual
    type DriftReport = {
        Missing: ConfigItem list        // In expected, not in actual
        Extra: ConfigItem list          // In actual, not in expected
        Changed: (ConfigItem * ConfigItem) list  // Key exists but value differs
        Identical: ConfigItem list      // Perfect matches
    }

    let detectDrift (expected: ConfigSet) (actual: ConfigSet) : DriftReport =
        let missing = difference expected actual
        let extra = difference actual expected
        let common = intersection expected actual

        let (changed, identical) =
            common.Items
            |> Map.toList
            |> List.partition (fun (key, expItem) ->
                match Map.tryFind key actual.Items with
                | Some actItem -> expItem.Value <> actItem.Value
                | None -> false)

        {
            Missing = missing.Items |> Map.toList |> List.map snd
            Extra = extra.Items |> Map.toList |> List.map snd
            Changed =
                changed
                |> List.map (fun (key, expItem) ->
                    expItem, Map.find key actual.Items)
            Identical = identical |> List.map snd
        }

    /// Merge multiple config sets with priority ordering
    let mergeWithPriority (configs: ConfigSet list) : ConfigSet =
        configs
        |> List.sortBy (fun c -> c.Source)  // Deterministic ordering
        |> List.fold union { Source = "empty"; Items = Map.empty }

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 7: FRACTAL ANALYSIS MATRIX (7 Layers × 10 Degrees × 5 Techniques)
// ═══════════════════════════════════════════════════════════════════════════════

/// Complete 7×10×5 Fractal-Interaction-Math analysis matrix
module FractalAnalysisMatrix =

    /// Analysis cell with full context
    type AnalysisCell = {
        Layer: FractalLayer
        Degree: InteractionDegree
        Technique: MathematicalTechnique
        Description: string
        StampConstraint: string
        AorRule: string
        FSharpModule: string
        Verified: bool
        ImpactScore: float         // 0.0 - 1.0
        ImplementationStatus: ImplementationStatus
    }
    and ImplementationStatus =
        | NotStarted
        | InProgress
        | Implemented
        | Verified

    /// Generate the full analysis matrix (7 × 10 × 5 = 350 cells)
    let generateMatrix () : AnalysisCell list =
        let layers = [L0_Runtime; L1_Function; L2_Component; L3_Holon;
                      L4_Container; L5_Node; L6_Cluster; L7_Federation]
        let degrees = [D1_Immediate; D2_Adjacent; D3_Integration; D4_Operational;
                       D5_Ecosystem; D6_Behavioral; D7_Adaptive; D8_Evolutionary;
                       D9_Generational; D10_Existential]
        let techniques = [GraphTheory; CriticalPathMethod; RCPSP;
                          FiniteStateAutomata; SetTheory]

        [
            for layer in layers do
                for degree in degrees do
                    for technique in techniques do
                        let (desc, stamp, aor, module_, impact, status) =
                            match layer, degree, technique with
                            // L0 Runtime × D1 Immediate × GraphTheory
                            | L0_Runtime, D1_Immediate, GraphTheory ->
                                ("Dependency validation at compile",
                                 "SC-GRAPH-001", "AOR-GRAPH-001",
                                 "TopologicalSort.kahnSort", 1.0, Implemented)

                            // L4 Container × D2 Adjacent × DFA
                            | L4_Container, D2_Adjacent, FiniteStateAutomata ->
                                ("Container state machine transitions",
                                 "SC-DFA-001", "AOR-DFA-001",
                                 "ContainerDFA.transition", 0.95, Implemented)

                            // L5 Node × D4 Operational × CPM
                            | L5_Node, D4_Operational, CriticalPathMethod ->
                                ("Boot time optimization via CPM",
                                 "SC-CPM-001", "AOR-CPM-001",
                                 "CriticalPathMethod.calculate", 0.9, Implemented)

                            // L6 Cluster × D3 Integration × RCPSP
                            | L6_Cluster, D3_Integration, RCPSP ->
                                ("Resource scheduling across cluster",
                                 "SC-RCPSP-001", "AOR-RCPSP-001",
                                 "RCPSP.listSchedule", 0.85, Implemented)

                            // L7 Federation × D5 Ecosystem × SetTheory
                            | L7_Federation, D5_Ecosystem, SetTheory ->
                                ("Config drift detection across federation",
                                 "SC-SET-001", "AOR-SET-001",
                                 "ConfigurationSets.detectDrift", 0.8, InProgress)

                            // Default for unspecified combinations
                            | _ ->
                                let layerStr = sprintf "%A" layer
                                let degreeStr = sprintf "%A" degree
                                let techStr = sprintf "%A" technique
                                let layerIdx = FractalUtils.fractalLayerToInt layer
                                let degreeIdx = FractalUtils.interactionDegreeToInt degree
                                (sprintf "%s × %s × %s" layerStr degreeStr techStr,
                                 sprintf "SC-%s-%d%d" (techStr.Substring(0,3).ToUpper())
                                         layerIdx degreeIdx,
                                 sprintf "AOR-%s-%d%d" (techStr.Substring(0,3).ToUpper())
                                         layerIdx degreeIdx,
                                 "TBD",
                                 0.5 - (float layerIdx * 0.05),
                                 NotStarted)

                        yield {
                            Layer = layer
                            Degree = degree
                            Technique = technique
                            Description = desc
                            StampConstraint = stamp
                            AorRule = aor
                            FSharpModule = module_
                            Verified = status = Verified
                            ImpactScore = impact
                            ImplementationStatus = status
                        }
        ]

    /// Get high-impact cells (impact > 0.8)
    let getHighImpactCells () : AnalysisCell list =
        generateMatrix ()
        |> List.filter (fun c -> c.ImpactScore > 0.8)

    /// Get cells by technique
    let getCellsByTechnique (tech: MathematicalTechnique) : AnalysisCell list =
        generateMatrix ()
        |> List.filter (fun c -> c.Technique = tech)

    /// Calculate implementation coverage
    let getImplementationCoverage () : Map<MathematicalTechnique, float> =
        let matrix = generateMatrix ()
        let techniques = [GraphTheory; CriticalPathMethod; RCPSP;
                          FiniteStateAutomata; SetTheory]

        techniques
        |> List.map (fun tech ->
            let cells = matrix |> List.filter (fun c -> c.Technique = tech)
            let implemented =
                cells
                |> List.filter (fun c ->
                    c.ImplementationStatus = Implemented ||
                    c.ImplementationStatus = Verified)
            tech, float implemented.Length / float cells.Length)
        |> Map.ofList

    /// Print matrix summary
    let printSummary () =
        let matrix = generateMatrix ()
        let coverage = getImplementationCoverage ()

        printfn "═══════════════════════════════════════════════════════════════"
        printfn " FRACTAL ANALYSIS MATRIX: 7 Layers × 10 Degrees × 5 Techniques"
        printfn "═══════════════════════════════════════════════════════════════"
        printfn ""
        printfn "Total Cells: %d" matrix.Length
        printfn ""
        printfn "Implementation Coverage by Technique:"
        for kvp in coverage do
            printfn "  %A: %.1f%%" kvp.Key (kvp.Value * 100.0)
        printfn ""
        printfn "High-Impact Cells (> 0.8):"
        for cell in getHighImpactCells () do
            printfn "  [%A × %A] %s" cell.Layer cell.Degree cell.Description
        printfn "═══════════════════════════════════════════════════════════════"

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 8: INTEGRATED STARTUP OPTIMIZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Integrates all mathematical techniques for optimal startup
module StartupOptimizer =

    open DirectedGraph

    /// Container definition for optimization
    type ContainerDef = {
        Id: string
        Name: string
        Criticality: int            // 0 = P0, 3 = P3
        DurationMs: int             // Expected boot time
        MemoryMB: int               // Memory requirement
        CPUCores: float             // CPU requirement
        Dependencies: string list   // Required containers
        OptionalDeps: string list   // Nice-to-have containers
    }

    /// Optimization result
    type OptimizationResult = {
        ExecutionOrder: string list list    // Waves/generations
        CriticalPath: string list
        EstimatedMakespan: int              // Total boot time in ms
        ResourceSchedule: RCPSP.ScheduledTask list
        BottleneckContainer: string
        OptimizationAdvice: string list
        StateTransitions: Map<string, ContainerDFA.Event list>
    }

    /// Run full optimization
    let optimize (containers: ContainerDef list)
                 (resources: RCPSP.Resource list) : OptimizationResult =

        // Step 1: Build DAG
        let vertices =
            containers
            |> List.map (fun c -> {
                Id = c.Id
                Data = c
                Criticality = c.Criticality
                EstimatedDurationMs = c.DurationMs
            })

        let edges =
            containers
            |> List.collect (fun c ->
                let hard = c.Dependencies |> List.map (fun d ->
                    { From = d; To = c.Id; Weight = 1.0; EdgeType = Requires })
                let soft = c.OptionalDeps |> List.map (fun d ->
                    { From = d; To = c.Id; Weight = 0.5; EdgeType = After })
                hard @ soft)

        let graph = create vertices edges

        // Step 2: Check for cycles
        match CycleDetection.detectCycle graph with
        | CycleDetection.HasCycle path ->
            failwithf "Cycle detected in dependencies: %s" (String.concat " → " path)
        | CycleDetection.NoCycle -> ()

        // Step 3: Topological sort for execution order
        let execOrder =
            match TopologicalSort.kahnSort graph with
            | TopologicalSort.Sorted gens -> gens
            | TopologicalSort.CycleDetected _ -> []

        // Step 4: CPM analysis
        let durations = containers |> List.map (fun c -> c.Id, c.DurationMs) |> Map.ofList
        let cpmResult = CriticalPathMethod.calculate graph durations

        // Step 5: RCPSP scheduling
        let requirements =
            containers
            |> List.collect (fun c -> [
                { RCPSP.ResourceRequirement.TaskId = c.Id; RCPSP.ResourceRequirement.ResourceId = "memory"; RCPSP.ResourceRequirement.Amount = c.MemoryMB }
                { RCPSP.ResourceRequirement.TaskId = c.Id; RCPSP.ResourceRequirement.ResourceId = "cpu"; RCPSP.ResourceRequirement.Amount = int (c.CPUCores * 100.0) }
            ])

        let rcpspResult = RCPSP.listSchedule graph durations resources requirements

        // Step 6: State transitions for each container
        let stateTransitions =
            containers
            |> List.map (fun c ->
                // Standard startup sequence
                c.Id, [ContainerDFA.Create; ContainerDFA.Start; ContainerDFA.HealthPass])
            |> Map.ofList

        // Step 7: Generate advice
        let advice = CriticalPathMethod.getOptimizationRecommendations cpmResult

        {
            ExecutionOrder = execOrder
            CriticalPath = cpmResult.CriticalPath
            EstimatedMakespan = cpmResult.TotalDuration
            ResourceSchedule = rcpspResult.Schedule
            BottleneckContainer = cpmResult.BottleneckTask
            OptimizationAdvice = advice
            StateTransitions = stateTransitions
        }

    /// Print optimization report
    let printReport (result: OptimizationResult) =
        printfn "═══════════════════════════════════════════════════════════════"
        printfn " STARTUP OPTIMIZATION REPORT"
        printfn "═══════════════════════════════════════════════════════════════"
        printfn ""
        printfn "EXECUTION ORDER (Waves):"
        result.ExecutionOrder |> List.iteri (fun i wave ->
            printfn "  Wave %d: %s" (i+1) (String.concat ", " wave))
        printfn ""
        printfn "CRITICAL PATH:"
        printfn "  %s" (String.concat " → " result.CriticalPath)
        printfn ""
        printfn "ESTIMATED MAKESPAN: %dms (%.1fs)"
                result.EstimatedMakespan
                (float result.EstimatedMakespan / 1000.0)
        printfn ""
        printfn "BOTTLENECK: %s" result.BottleneckContainer
        printfn ""
        printfn "OPTIMIZATION ADVICE:"
        for advice in result.OptimizationAdvice do
            printfn "  • %s" advice
        printfn "═══════════════════════════════════════════════════════════════"
