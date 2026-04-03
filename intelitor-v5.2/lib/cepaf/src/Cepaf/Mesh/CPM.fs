// =============================================================================
// CPM.fs - Critical Path Method for Boot Time Optimization
// =============================================================================
// STAMP: SC-BOOT-005 (Boot time < 60s), SC-OPT-001
// AOR: AOR-BOOT-002 (Identify and optimize critical path)
//
// ## Purpose
// Implements Critical Path Method (CPM) to identify the longest path through
// the boot dependency graph and optimize boot time.
//
// ## Mathematical Foundation
// Forward Pass: ES(i) = max{EF(j)} for all predecessors j
// Backward Pass: LF(i) = min{LS(j)} for all successors j
// Slack: TF(i) = LS(i) - ES(i) = LF(i) - EF(i)
// Critical Path: All tasks where Slack = 0
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

/// Task with CPM timing attributes
type CpmTask = {
    Id: string
    Duration: int              // milliseconds
    EarliestStart: int         // ES: earliest this task can start
    EarliestFinish: int        // EF: earliest this task can finish (ES + Duration)
    LatestStart: int           // LS: latest this task can start without delaying project
    LatestFinish: int          // LF: latest this task can finish without delaying project
    TotalFloat: int            // TF: how much this task can be delayed (LS - ES)
    FreeFloat: int             // FF: delay without affecting immediate successors
    OnCriticalPath: bool       // True if TotalFloat = 0
}

/// CPM analysis result
type CpmAnalysis = {
    Tasks: CpmTask list
    CriticalPath: CpmTask list
    TotalDuration: int
    CriticalPathDuration: int
    ParallelizationPotential: float  // 0.0 to 1.0
}

/// Critical Path Method operations
module CPM =

    /// Calculate CPM for a set of DAG nodes
    /// Returns: CPM analysis with timing for all tasks
    let calculate (nodes: DagNode list) : Result<CpmAnalysis, string> =
        // Handle empty input
        if nodes.IsEmpty then
            Ok {
                Tasks = []
                TotalDuration = 0
                CriticalPath = []
                CriticalPathDuration = 0
                ParallelizationPotential = 0.0
            }
        else
        // First verify DAG is valid
        match DAG.topologicalSort nodes with
        | CycleDetected cycle ->
            let cycleStr = cycle |> String.concat ", "
            Error $"Cannot calculate CPM: cycle detected involving {cycleStr}"

        | Sorted sortedNodes ->
            let nodeMap = nodes |> List.map (fun n -> n.Id, n) |> Map.ofList

            // FORWARD PASS: Calculate earliest times
            let mutable earliest = Map.empty<string, int * int>  // id -> (ES, EF)

            for node in sortedNodes do
                let maxPredFinish =
                    if node.Dependencies.IsEmpty then 0
                    else
                        node.Dependencies
                        |> List.filter (fun d -> earliest.ContainsKey d)
                        |> List.map (fun d -> snd earliest.[d])  // Get EF of predecessor
                        |> function
                            | [] -> 0
                            | times -> List.max times

                let es = maxPredFinish
                let ef = es + node.EstimatedDuration
                earliest <- earliest |> Map.add node.Id (es, ef)

            let totalDuration =
                earliest
                |> Map.toSeq
                |> Seq.map (fun (_, (_, ef)) -> ef)
                |> Seq.max

            // BACKWARD PASS: Calculate latest times
            let mutable latest = Map.empty<string, int * int>  // id -> (LS, LF)

            for node in sortedNodes |> List.rev do
                let minSuccStart =
                    let successors =
                        sortedNodes
                        |> List.filter (fun n -> n.Dependencies |> List.contains node.Id)

                    if successors.IsEmpty then totalDuration
                    else
                        successors
                        |> List.filter (fun s -> latest.ContainsKey s.Id)
                        |> List.map (fun s -> fst latest.[s.Id])  // Get LS of successor
                        |> function
                            | [] -> totalDuration
                            | times -> List.min times

                let lf = minSuccStart
                let ls = lf - node.EstimatedDuration
                latest <- latest |> Map.add node.Id (ls, lf)

            // BUILD CPM TASKS with float calculations
            let tasks =
                sortedNodes
                |> List.map (fun node ->
                    let (es, ef) = earliest.[node.Id]
                    let (ls, lf) = latest.[node.Id]
                    let totalFloat = ls - es
                    let freeFloat =
                        let successors =
                            sortedNodes
                            |> List.filter (fun n -> n.Dependencies |> List.contains node.Id)
                        if successors.IsEmpty then totalFloat
                        else
                            let minSuccES =
                                successors
                                |> List.map (fun s -> fst earliest.[s.Id])
                                |> List.min
                            minSuccES - ef
                    {
                        Id = node.Id
                        Duration = node.EstimatedDuration
                        EarliestStart = es
                        EarliestFinish = ef
                        LatestStart = ls
                        LatestFinish = lf
                        TotalFloat = totalFloat
                        FreeFloat = freeFloat
                        OnCriticalPath = totalFloat = 0
                    })

            let criticalPath = tasks |> List.filter (fun t -> t.OnCriticalPath)
            let criticalPathDuration = criticalPath |> List.sumBy (fun t -> t.Duration)

            // Calculate parallelization potential
            let totalWork = tasks |> List.sumBy (fun t -> t.Duration)
            let parallelizationPotential =
                if totalDuration > 0 && totalWork > 0 then
                    1.0 - (float criticalPathDuration / float totalWork)
                else 0.0

            Ok {
                Tasks = tasks
                CriticalPath = criticalPath
                TotalDuration = totalDuration
                CriticalPathDuration = criticalPathDuration
                ParallelizationPotential = parallelizationPotential
            }

    /// Get tasks with the most slack (optimization targets)
    let getSlackTasks (analysis: CpmAnalysis) : CpmTask list =
        analysis.Tasks
        |> List.filter (fun t -> not t.OnCriticalPath)
        |> List.sortByDescending (fun t -> t.TotalFloat)

    /// Identify bottleneck tasks (longest on critical path)
    let getBottlenecks (analysis: CpmAnalysis) : CpmTask list =
        analysis.CriticalPath
        |> List.sortByDescending (fun t -> t.Duration)

    /// Simulate effect of reducing a task's duration
    let simulateOptimization (nodes: DagNode list) (taskId: string) (newDuration: int) : Result<int, string> =
        let optimizedNodes =
            nodes
            |> List.map (fun n ->
                if n.Id = taskId then { n with EstimatedDuration = newDuration }
                else n)

        match calculate optimizedNodes with
        | Ok analysis -> Ok analysis.TotalDuration
        | Error e -> Error e

    /// Print CPM analysis report
    let printAnalysis (analysis: CpmAnalysis) : unit =
        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════════════════╗"
        printfn "║                     CRITICAL PATH METHOD ANALYSIS                              ║"
        printfn "╠═══════════════════════════════════════════════════════════════════════════════╣"
        printfn "║ Task          │ Duration │  ES   │  EF   │  LS   │  LF   │ Float │ Critical  ║"
        printfn "╠═══════════════╪══════════╪═══════╪═══════╪═══════╪═══════╪═══════╪═══════════╣"

        for task in analysis.Tasks do
            let critical = if task.OnCriticalPath then "★ YES" else "  no"
            printfn "║ %-13s │ %6dms │ %5d │ %5d │ %5d │ %5d │ %5d │ %9s ║"
                task.Id task.Duration task.EarliestStart task.EarliestFinish
                task.LatestStart task.LatestFinish task.TotalFloat critical

        printfn "╠═══════════════════════════════════════════════════════════════════════════════╣"
        printfn "║ CRITICAL PATH: %-62s ║"
            (analysis.CriticalPath |> List.map (fun t -> t.Id) |> String.concat " → ")
        printfn "╠═══════════════════════════════════════════════════════════════════════════════╣"
        printfn "║ Total Project Duration:       %6d ms (%d.%d seconds)                       ║"
            analysis.TotalDuration (analysis.TotalDuration / 1000) ((analysis.TotalDuration % 1000) / 100)
        printfn "║ Critical Path Duration:       %6d ms                                        ║" analysis.CriticalPathDuration
        printfn "║ Parallelization Potential:    %5.1f%%                                          ║" (analysis.ParallelizationPotential * 100.0)
        printfn "╚═══════════════════════════════════════════════════════════════════════════════╝"
        printfn ""

    /// Print optimization recommendations
    let printOptimizationRecommendations (analysis: CpmAnalysis) : unit =
        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║              OPTIMIZATION RECOMMENDATIONS                          ║"
        printfn "╚═══════════════════════════════════════════════════════════════════╝"

        printfn ""
        printfn "🔥 CRITICAL PATH BOTTLENECKS (optimize these first):"
        for task in getBottlenecks analysis |> List.truncate 3 do
            printfn "   • %s: %dms - reduce duration for biggest impact" task.Id task.Duration

        printfn ""
        printfn "✨ HIGH SLACK TASKS (can be delayed without impact):"
        for task in getSlackTasks analysis |> List.truncate 3 do
            printfn "   • %s: %dms float - can start late or slow down" task.Id task.TotalFloat

        printfn ""
        printfn "📊 SUMMARY:"
        printfn "   • %d tasks on critical path" analysis.CriticalPath.Length
        printfn "   • %d tasks with slack" (analysis.Tasks.Length - analysis.CriticalPath.Length)
        printfn "   • %.1f%% of work can be parallelized" (analysis.ParallelizationPotential * 100.0)
        printfn ""
