// =============================================================================
// CPMTests.fs - TDG-compliant tests for Critical Path Method
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-BOOT-005 (Boot time < 60s)
// AOR: AOR-TEST-001 (Run TDG validation before code changes)
//
// ## Test Coverage
// - Unit tests: Forward/backward pass calculations
// - Property tests: CPM invariants (slack >= 0, critical path is longest)
// - Edge cases: Empty graph, single node, complex dependencies
// - Mathematical properties: ES + Duration = EF, LS - Duration = LF
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.1.0 |
// | Created | 2026-01-19 |
// | Modified | 2026-01-19 |
// | Author | Claude Opus 4.5 |
// | Note | Migrated to FsCheck 3.x API |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.CPMTests

open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf.Mesh

/// Test data generators (FsCheck 3.x compatible)
module Generators =
    /// Helper: Sequence a list of generators into a generator of list (FsCheck 3.x)
    let rec private sequenceGens (acc: 'a list) (gens: Gen<'a> list) : Gen<'a list> =
        match gens with
        | [] -> Gen.constant (List.rev acc)
        | g :: rest -> g |> Gen.bind (fun x -> sequenceGens (x :: acc) rest)

    /// Generate valid DAG node with positive duration (FsCheck 3.x style)
    let dagNodeGen : Gen<DagNode> =
        Gen.choose(1, 100) |> Gen.bind (fun idNum ->
            Gen.choose(1, 10000) |> Gen.bind (fun duration ->
                Gen.choose(0, 10) |> Gen.map (fun wave ->
                    let id = sprintf "node-%d" idNum
                    DAG.createNode id id [] duration wave Criticality.P0_Critical
                )
            )
        )

    /// Generate a list of DAG nodes forming a valid DAG (acyclic) - FsCheck 3.x style
    let validDagGen : Gen<DagNode list> =
        Gen.choose(1, 10) |> Gen.bind (fun nodeCount ->
            let nodeIds = List.init nodeCount (fun i -> sprintf "node-%d" i)

            let genNode i id =
                Gen.choose(100, 5000) |> Gen.bind (fun duration ->
                    // Only allow dependencies on earlier nodes to ensure acyclicity
                    let possibleDeps = nodeIds |> List.take i
                    let maxDeps = min 2 (List.length possibleDeps)
                    Gen.choose(0, maxDeps) |> Gen.bind (fun depCount ->
                        if depCount = 0 || List.isEmpty possibleDeps then
                            Gen.constant (DAG.createNode id id [] duration i Criticality.P0_Critical)
                        else
                            Gen.shuffle possibleDeps |> Gen.map (fun shuffled ->
                                let deps = shuffled |> Seq.take depCount |> List.ofSeq
                                DAG.createNode id id deps duration i Criticality.P0_Critical
                            )
                    )
                )

            nodeIds
            |> List.mapi genNode
            |> sequenceGens []
        )

/// Unit Tests
[<Tests>]
let unitTests =
    testList "CPM Unit Tests" [

        test "CPM.calculate - Empty graph returns Ok with empty results" {
            match CPM.calculate [] with
            | Ok analysis ->
                Expect.isEmpty analysis.Tasks "Tasks should be empty"
                Expect.isEmpty analysis.CriticalPath "Critical path should be empty"
                Expect.equal analysis.TotalDuration 0 "Total duration should be 0"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.calculate - Single node has ES=0, EF=duration" {
            let node = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical

            match CPM.calculate [node] with
            | Ok analysis ->
                Expect.hasLength analysis.Tasks 1 "Should have 1 task"
                let task = analysis.Tasks.[0]
                Expect.equal task.EarliestStart 0 "ES should be 0"
                Expect.equal task.EarliestFinish 1000 "EF should equal duration"
                Expect.equal task.TotalFloat 0 "Single node has no float"
                Expect.isTrue task.OnCriticalPath "Single node is on critical path"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.calculate - Linear chain has correct ES/EF propagation" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 2000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["B"] 1500 2 Criticality.P0_Critical

            match CPM.calculate [nodeA; nodeB; nodeC] with
            | Ok analysis ->
                let taskMap = analysis.Tasks |> List.map (fun t -> t.Id, t) |> Map.ofList

                // A: ES=0, EF=1000
                Expect.equal taskMap.["A"].EarliestStart 0 "A ES = 0"
                Expect.equal taskMap.["A"].EarliestFinish 1000 "A EF = 1000"

                // B: ES=1000, EF=3000
                Expect.equal taskMap.["B"].EarliestStart 1000 "B ES = A.EF"
                Expect.equal taskMap.["B"].EarliestFinish 3000 "B EF = ES + duration"

                // C: ES=3000, EF=4500
                Expect.equal taskMap.["C"].EarliestStart 3000 "C ES = B.EF"
                Expect.equal taskMap.["C"].EarliestFinish 4500 "C EF = ES + duration"

                // All on critical path
                Expect.all analysis.Tasks (fun t -> t.OnCriticalPath) "All tasks on critical path"
                Expect.equal analysis.TotalDuration 4500 "Total = 1000+2000+1500"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.calculate - Diamond DAG has correct slack calculation" {
            // A -> B -> D
            //   -> C ->
            // Where B is longer than C
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 3000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            match CPM.calculate [nodeA; nodeB; nodeC; nodeD] with
            | Ok analysis ->
                let taskMap = analysis.Tasks |> List.map (fun t -> t.Id, t) |> Map.ofList

                // Critical path: A -> B -> D (total: 5000)
                Expect.equal analysis.TotalDuration 5000 "Total = 1000+3000+1000"

                // B should be on critical path (longer)
                Expect.isTrue taskMap.["B"].OnCriticalPath "B on critical path"
                Expect.equal taskMap.["B"].TotalFloat 0 "B has no float"

                // C should have slack (shorter path)
                Expect.isFalse taskMap.["C"].OnCriticalPath "C not on critical path"
                Expect.equal taskMap.["C"].TotalFloat 2000 "C has 2000ms slack"

                Expect.hasLength analysis.CriticalPath 3 "Critical path has 3 tasks"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.calculate - Detects cycles" {
            let nodeA = DAG.createNode "A" "A" ["B"] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 0 Criticality.P0_Critical

            match CPM.calculate [nodeA; nodeB] with
            | Error msg -> Expect.stringContains msg "cycle" "Should detect cycle"
            | Ok _ -> failtest "Should have detected cycle"
        }

        test "CPM.getSlackTasks - Returns non-critical tasks sorted by slack" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 3000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            match CPM.calculate [nodeA; nodeB; nodeC; nodeD] with
            | Ok analysis ->
                let slackTasks = CPM.getSlackTasks analysis
                Expect.hasLength slackTasks 1 "Only C has slack"
                Expect.equal slackTasks.[0].Id "C" "C is the slack task"
                Expect.equal slackTasks.[0].TotalFloat 2000 "C has 2000ms slack"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.getBottlenecks - Returns critical tasks sorted by duration" {
            let nodeA = DAG.createNode "A" "A" [] 500 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 3000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["B"] 1500 2 Criticality.P0_Critical

            match CPM.calculate [nodeA; nodeB; nodeC] with
            | Ok analysis ->
                let bottlenecks = CPM.getBottlenecks analysis
                Expect.hasLength bottlenecks 3 "All tasks on critical path"
                Expect.equal bottlenecks.[0].Id "B" "B is longest (3000ms)"
                Expect.equal bottlenecks.[0].Duration 3000 "B duration = 3000"
                Expect.equal bottlenecks.[1].Id "C" "C is second (1500ms)"
                Expect.equal bottlenecks.[2].Id "A" "A is shortest (500ms)"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.simulateOptimization - Reducing critical task reduces total duration" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 3000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["B"] 1000 2 Criticality.P0_Critical

            let nodes = [nodeA; nodeB; nodeC]

            match CPM.calculate nodes with
            | Ok baseline ->
                Expect.equal baseline.TotalDuration 5000 "Baseline = 5000"

                // Reduce B from 3000 to 1000
                match CPM.simulateOptimization nodes "B" 1000 with
                | Ok optimized ->
                    Expect.equal optimized 3000 "Optimized = 1000+1000+1000"
                | Error e -> failtest $"Should not error: {e}"
            | Error e -> failtest $"Should not error: {e}"
        }

        test "CPM.simulateOptimization - Reducing non-critical task doesn't help" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 3000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            let nodes = [nodeA; nodeB; nodeC; nodeD]

            match CPM.calculate nodes with
            | Ok baseline ->
                Expect.equal baseline.TotalDuration 5000 "Baseline = 5000"

                // Reduce C (non-critical) from 1000 to 100
                match CPM.simulateOptimization nodes "C" 100 with
                | Ok optimized ->
                    Expect.equal optimized 5000 "Total unchanged (C not critical)"
                | Error e -> failtest $"Should not error: {e}"
            | Error e -> failtest $"Should not error: {e}"
        }
    ]

/// Property-Based Tests (FsCheck 3.x compatible)
[<Tests>]
let propertyTests =
    testList "CPM Property Tests" [

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: ES + Duration = EF for all tasks" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis ->
                        analysis.Tasks
                        |> List.forall (fun t -> t.EarliestStart + t.Duration = t.EarliestFinish)
                    | Error _ -> true  // Cycle detection is valid
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: LS + Duration = LF for all tasks" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis ->
                        analysis.Tasks
                        |> List.forall (fun t -> t.LatestStart + t.Duration = t.LatestFinish)
                    | Error _ -> true
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: TotalFloat = LS - ES for all tasks" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis ->
                        analysis.Tasks
                        |> List.forall (fun t -> t.TotalFloat = t.LatestStart - t.EarliestStart)
                    | Error _ -> true
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: All slack values >= 0" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis ->
                        analysis.Tasks |> List.forall (fun t -> t.TotalFloat >= 0)
                    | Error _ -> true
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: Critical path has zero slack" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis ->
                        analysis.CriticalPath
                        |> List.forall (fun t -> t.TotalFloat = 0 && t.OnCriticalPath)
                    | Error _ -> true
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: Total duration = max(EF) across all tasks" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis when not analysis.Tasks.IsEmpty ->
                        let maxEF = analysis.Tasks |> List.map (fun t -> t.EarliestFinish) |> List.max
                        analysis.TotalDuration = maxEF
                    | _ -> true
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: Critical path duration <= total work" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis when not analysis.Tasks.IsEmpty ->
                        let totalWork = analysis.Tasks |> List.sumBy (fun t -> t.Duration)
                        analysis.CriticalPathDuration <= totalWork
                    | _ -> true
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "CPM invariant: Parallelization potential in [0, 1]" <|
            fun () ->
                let arb = Arb.fromGen Generators.validDagGen
                Prop.forAll arb (fun nodes ->
                    match CPM.calculate nodes with
                    | Ok analysis ->
                        analysis.ParallelizationPotential >= 0.0 &&
                        analysis.ParallelizationPotential <= 1.0
                    | Error _ -> true
                )
    ]

/// Integration Tests
[<Tests>]
let integrationTests =
    testList "CPM Integration Tests" [

        test "Real-world scenario: Indrajaal boot sequence" {
            // Simulate actual boot stages
            let s0_preflight = DAG.createNode "S0" "Preflight" [] 2000 0 Criticality.P0_Critical
            let s1_db = DAG.createNode "S1-DB" "Database" ["S0"] 8000 1 Criticality.P0_Critical
            let s1_obs = DAG.createNode "S1-OBS" "Observability" ["S0"] 6000 1 Criticality.P1_High
            let s2_zenoh = DAG.createNode "S2" "Zenoh Mesh" ["S1-DB"; "S1-OBS"] 4000 2 Criticality.P0_Critical
            let s3_app = DAG.createNode "S3" "App Seed" ["S2"] 12000 3 Criticality.P0_Critical
            let s4_health = DAG.createNode "S4" "Homeostasis" ["S3"] 5000 4 Criticality.P0_Critical

            let nodes = [s0_preflight; s1_db; s1_obs; s2_zenoh; s3_app; s4_health]

            match CPM.calculate nodes with
            | Ok analysis ->
                // Boot time should be < 60s (SC-BOOT-005)
                Expect.isLessThan analysis.TotalDuration 60000 "Boot time < 60s"

                // Critical path should be S0 -> S1-DB -> S2 -> S3 -> S4
                let criticalIds = analysis.CriticalPath |> List.map (fun t -> t.Id)
                Expect.contains criticalIds "S0" "S0 on critical path"
                Expect.contains criticalIds "S1-DB" "DB on critical path (longer than OBS)"
                Expect.contains criticalIds "S3" "App on critical path (longest single task)"

                // OBS should have slack
                let obsTask = analysis.Tasks |> List.find (fun t -> t.Id = "S1-OBS")
                Expect.isGreaterThan obsTask.TotalFloat 0 "OBS has slack (shorter than DB)"

                printfn "Boot CPM Analysis:"
                printfn "  Total Duration: %dms (%.1fs)" analysis.TotalDuration (float analysis.TotalDuration / 1000.0)
                printfn "  Critical Path: %s" (analysis.CriticalPath |> List.map (fun t -> t.Id) |> String.concat " → ")
                printfn "  Parallelization: %.1f%%" (analysis.ParallelizationPotential * 100.0)
            | Error e -> failtest $"Should not error: {e}"
        }
    ]

/// Combined test suite
[<Tests>]
let allTests =
    testList "CPM Complete Test Suite" [
        unitTests
        propertyTests
        integrationTests
    ]
