// =============================================================================
// DAGTests.fs - TDG-compliant tests for Directed Acyclic Graph
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-BOOT-008 (DAG MUST be acyclic)
// AOR: AOR-BOOT-001 (Topological sort before boot)
//
// ## Test Coverage
// - Unit tests: Topological sort, cycle detection
// - Property tests: DAG acyclicity, topological order validity
// - Edge cases: Empty graph, single node, complex cycles
// - Mathematical properties: Kahn's algorithm O(V+E) complexity
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.1.0 |
// | Created | 2026-01-19 |
// | Updated | 2026-01-19 |
// | Author | Claude Opus 4.5 |
// | FsCheck | 3.x compatible |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.DAGTests

open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf.Mesh

/// Test data generators (FsCheck 3.x compatible)
module Generators =
    /// Generate valid DAG node
    let dagNodeGen : Gen<DagNode> =
        Gen.choose(100, 5000) |> Gen.bind (fun duration ->
            Gen.choose(0, 10) |> Gen.map (fun wave ->
                let id = sprintf "node-%d-%d" duration wave
                DAG.createNode id id [] duration wave Criticality.P0_Critical
            )
        )

    /// Helper: Sequence a list of generators into a generator of list (FsCheck 3.x)
    let rec private sequenceGens (acc: 'a list) (gens: Gen<'a> list) : Gen<'a list> =
        match gens with
        | [] -> Gen.constant (List.rev acc)
        | g :: rest -> g |> Gen.bind (fun x -> sequenceGens (x :: acc) rest)

    /// Generate acyclic DAG (valid dependencies only)
    let acyclicDagGen : Gen<DagNode list> =
        Gen.choose(2, 8) |> Gen.bind (fun nodeCount ->
            let nodeIds = List.init nodeCount (fun i -> sprintf "node-%d" i)

            let genNode i id =
                Gen.choose(100, 2000) |> Gen.bind (fun duration ->
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

    /// Generate cyclic DAG (for negative tests)
    /// Creates a cycle: node-0 -> node-1 -> ... -> node-n -> node-0
    let cyclicDagGen : Gen<DagNode list> =
        Gen.choose(2, 5) |> Gen.map (fun nodeCount ->
            let nodeIds = List.init nodeCount (fun i -> sprintf "node-%d" i)
            let lastNodeId = nodeIds.[nodeCount - 1]

            // Create a cycle: each node depends on previous, and node-0 depends on last node
            nodeIds
            |> List.mapi (fun i id ->
                let deps =
                    if i = 0 then [lastNodeId]  // node-0 depends on last node (creates cycle)
                    else [nodeIds.[i-1]]         // each other node depends on previous
                DAG.createNode id id deps 1000 i Criticality.P0_Critical
            )
        )

/// Unit Tests
[<Tests>]
let unitTests =
    testList "DAG Unit Tests" [

        test "DAG.topologicalSort - Empty graph returns Sorted []" {
            match DAG.topologicalSort [] with
            | Sorted nodes -> Expect.isEmpty nodes "Should be empty"
            | CycleDetected _ -> failtest "Should not detect cycle in empty graph"
        }

        test "DAG.topologicalSort - Single node returns that node" {
            let node = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical

            match DAG.topologicalSort [node] with
            | Sorted nodes ->
                Expect.hasLength nodes 1 "Should have 1 node"
                Expect.equal nodes.[0].Id "A" "Should be node A"
            | CycleDetected _ -> failtest "Should not detect cycle"
        }

        test "DAG.topologicalSort - Linear chain preserves order" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["B"] 1000 2 Criticality.P0_Critical

            match DAG.topologicalSort [nodeA; nodeB; nodeC] with
            | Sorted nodes ->
                Expect.hasLength nodes 3 "Should have 3 nodes"
                let ids = nodes |> List.map (fun n -> n.Id)
                Expect.equal ids ["A"; "B"; "C"] "Should be A -> B -> C"
            | CycleDetected _ -> failtest "Should not detect cycle"
        }

        test "DAG.topologicalSort - Diamond DAG has valid topological order" {
            // A -> B -> D
            //   -> C ->
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            match DAG.topologicalSort [nodeA; nodeB; nodeC; nodeD] with
            | Sorted nodes ->
                Expect.hasLength nodes 4 "Should have 4 nodes"
                let ids = nodes |> List.map (fun n -> n.Id)

                // A must come first
                Expect.equal ids.[0] "A" "A should be first"

                // D must come last
                Expect.equal ids.[3] "D" "D should be last"

                // B and C can be in any order but both after A, before D
                let bIndex = ids |> List.findIndex ((=) "B")
                let cIndex = ids |> List.findIndex ((=) "C")
                Expect.isLessThan bIndex 3 "B before D"
                Expect.isLessThan cIndex 3 "C before D"
            | CycleDetected _ -> failtest "Should not detect cycle"
        }

        test "DAG.topologicalSort - Detects simple 2-node cycle" {
            let nodeA = DAG.createNode "A" "A" ["B"] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 0 Criticality.P0_Critical

            match DAG.topologicalSort [nodeA; nodeB] with
            | CycleDetected cycle ->
                Expect.hasLength cycle 2 "Should detect 2-node cycle"
                Expect.contains cycle "A" "Cycle includes A"
                Expect.contains cycle "B" "Cycle includes B"
            | Sorted _ -> failtest "Should detect cycle"
        }

        test "DAG.topologicalSort - Detects 3-node cycle" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["B"] 1000 2 Criticality.P0_Critical
            let nodeD = DAG.createNode "D" "D" ["C"] 1000 3 Criticality.P0_Critical
            let nodeCyclic = { nodeB with Dependencies = ["A"; "D"] }  // B -> A and D -> C -> B

            match DAG.topologicalSort [nodeA; nodeCyclic; nodeC; nodeD] with
            | CycleDetected cycle ->
                Expect.isGreaterThan cycle.Length 0 "Should detect cycle"
            | Sorted _ -> failtest "Should detect cycle"
        }

        test "DAG.detectCycles - Returns None for acyclic graph" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High

            match DAG.detectCycles [nodeA; nodeB; nodeC] with
            | None -> ()  // Expected
            | Some cycle -> failtest $"Should not detect cycle: {cycle}"
        }

        test "DAG.detectCycles - Detects cycle in cyclic graph" {
            let nodeA = DAG.createNode "A" "A" ["B"] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 0 Criticality.P0_Critical

            match DAG.detectCycles [nodeA; nodeB] with
            | Some cycle ->
                Expect.isGreaterThan cycle.Length 0 "Should find cycle"
                Expect.contains cycle "A" "Cycle includes A"
                Expect.contains cycle "B" "Cycle includes B"
            | None -> failtest "Should detect cycle"
        }

        test "DAG.groupByWave - Groups nodes by wave number" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            let waves = DAG.groupByWave [nodeA; nodeB; nodeC; nodeD]

            Expect.hasLength waves 3 "Should have 3 waves"

            // Wave 0: A
            Expect.hasLength waves.[0] 1 "Wave 0 has 1 node"
            Expect.equal waves.[0].[0].Id "A" "Wave 0 is A"

            // Wave 1: B, C
            Expect.hasLength waves.[1] 2 "Wave 1 has 2 nodes"
            let wave1Ids = waves.[1] |> List.map (fun n -> n.Id) |> Set.ofList
            Expect.equal wave1Ids (Set.ofList ["B"; "C"]) "Wave 1 is B, C"

            // Wave 2: D
            Expect.hasLength waves.[2] 1 "Wave 2 has 1 node"
            Expect.equal waves.[2].[0].Id "D" "Wave 2 is D"
        }

        test "DAG.verifyDependencies - Returns Ok for valid dependencies" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical

            match DAG.verifyDependencies [nodeA; nodeB] with
            | Ok () -> ()  // Expected
            | Error errors -> failtest $"Should not have errors: {errors}"
        }

        test "DAG.verifyDependencies - Returns Error for missing dependencies" {
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical

            match DAG.verifyDependencies [nodeB] with
            | Error errors ->
                Expect.hasLength errors 1 "Should have 1 error"
                Expect.stringContains errors.[0] "missing" "Error mentions missing"
                Expect.stringContains errors.[0] "A" "Error mentions node A"
            | Ok () -> failtest "Should detect missing dependency"
        }

        test "DAG.getDownstream - Returns nodes that depend on target" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"] 1000 2 Criticality.P0_Critical

            let downstream = DAG.getDownstream "A" [nodeA; nodeB; nodeC; nodeD]

            Expect.hasLength downstream 2 "A has 2 downstream nodes"
            let ids = downstream |> List.map (fun n -> n.Id) |> Set.ofList
            Expect.equal ids (Set.ofList ["B"; "C"]) "Downstream are B and C"
        }

        test "DAG.getUpstream - Returns nodes that target depends on" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            let upstream = DAG.getUpstream "D" [nodeA; nodeB; nodeC; nodeD]

            Expect.hasLength upstream 2 "D has 2 upstream nodes"
            let ids = upstream |> List.map (fun n -> n.Id) |> Set.ofList
            Expect.equal ids (Set.ofList ["B"; "C"]) "Upstream are B and C"
        }

        test "DAG.estimateCriticalPathDuration - Returns max finish time" {
            let nodeA = DAG.createNode "A" "A" [] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 3000 1 Criticality.P0_Critical
            let nodeC = DAG.createNode "C" "C" ["A"] 1000 1 Criticality.P1_High
            let nodeD = DAG.createNode "D" "D" ["B"; "C"] 1000 2 Criticality.P0_Critical

            let duration = DAG.estimateCriticalPathDuration [nodeA; nodeB; nodeC; nodeD]

            // Critical path: A (1000) -> B (3000) -> D (1000) = 5000
            Expect.equal duration 5000 "Critical path duration = 5000"
        }

        test "DAG.estimateCriticalPathDuration - Returns -1 for cyclic graph" {
            let nodeA = DAG.createNode "A" "A" ["B"] 1000 0 Criticality.P0_Critical
            let nodeB = DAG.createNode "B" "B" ["A"] 1000 0 Criticality.P0_Critical

            let duration = DAG.estimateCriticalPathDuration [nodeA; nodeB]

            Expect.equal duration -1 "Should return -1 for cycle"
        }
    ]

/// Property-Based Tests (FsCheck 3.x compatible)
[<Tests>]
let propertyTests =
    testList "DAG Property Tests" [

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "Acyclic DAG always produces valid topological sort" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    match DAG.topologicalSort nodes with
                    | Sorted sorted ->
                        // Verify: for every edge (u,v), u comes before v
                        sorted |> List.indexed |> List.forall (fun (i, node) ->
                            node.Dependencies |> List.forall (fun dep ->
                                match sorted |> List.tryFindIndex (fun n -> n.Id = dep) with
                                | Some depIndex -> depIndex < i
                                | None -> true  // Dep not in list, OK
                            )
                        )
                    | CycleDetected _ -> false  // Should not detect cycle in acyclic graph
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "Topological sort preserves all nodes" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    match DAG.topologicalSort nodes with
                    | Sorted sorted ->
                        let originalIds = nodes |> List.map (fun n -> n.Id) |> Set.ofList
                        let sortedIds = sorted |> List.map (fun n -> n.Id) |> Set.ofList
                        originalIds = sortedIds
                    | CycleDetected _ -> true  // Valid outcome
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "Cyclic DAG always detects cycle" <|
            fun () ->
                let arb = Arb.fromGen Generators.cyclicDagGen
                Prop.forAll arb (fun nodes ->
                    match DAG.topologicalSort nodes with
                    | CycleDetected cycle -> cycle.Length > 0
                    | Sorted _ -> false  // Should detect cycle
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "groupByWave preserves all nodes" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    let waves = DAG.groupByWave nodes
                    let grouped = waves |> List.concat
                    let originalIds = nodes |> List.map (fun n -> n.Id) |> List.sort
                    let groupedIds = grouped |> List.map (fun n -> n.Id) |> List.sort
                    originalIds = groupedIds
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "getDownstream + getUpstream are consistent" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    nodes |> List.forall (fun node ->
                        let downstream = DAG.getDownstream node.Id nodes
                        downstream |> List.forall (fun d ->
                            let upstream = DAG.getUpstream d.Id nodes
                            upstream |> List.exists (fun u -> u.Id = node.Id)
                        )
                    )
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "verifyDependencies succeeds when all deps exist" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    match DAG.verifyDependencies nodes with
                    | Ok () -> true
                    | Error _ -> false
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "Critical path duration >= max single task duration" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    if nodes.IsEmpty then true
                    else
                        let cpDuration = DAG.estimateCriticalPathDuration nodes
                        if cpDuration = -1 then true  // Cycle detected
                        else
                            let maxTaskDuration = nodes |> List.map (fun n -> n.EstimatedDuration) |> List.max
                            cpDuration >= maxTaskDuration
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 } "Critical path duration <= sum of all durations" <|
            fun () ->
                let arb = Arb.fromGen Generators.acyclicDagGen
                Prop.forAll arb (fun nodes ->
                    if nodes.IsEmpty then true
                    else
                        let cpDuration = DAG.estimateCriticalPathDuration nodes
                        if cpDuration = -1 then true  // Cycle detected
                        else
                            let totalDuration = nodes |> List.sumBy (fun n -> n.EstimatedDuration)
                            cpDuration <= totalDuration
                )
    ]

/// Integration Tests
[<Tests>]
let integrationTests =
    testList "DAG Integration Tests" [

        test "Real-world: Indrajaal SIL-6 boot sequence DAG" {
            // S0: Preflight
            let s0 = DAG.createNode "S0_PREFLIGHT" "Preflight" [] 2000 0 Criticality.P0_Critical

            // S1: Infrastructure (DB + OBS in parallel)
            let s1_db = DAG.createNode "S1_DB" "Database" ["S0_PREFLIGHT"] 8000 1 Criticality.P0_Critical
            let s1_obs = DAG.createNode "S1_OBS" "Observability" ["S0_PREFLIGHT"] 6000 1 Criticality.P1_High

            // S2: Zenoh Mesh (depends on both DB and OBS)
            let s2 = DAG.createNode "S2_ZENOH" "Zenoh Mesh" ["S1_DB"; "S1_OBS"] 4000 2 Criticality.P0_Critical

            // S3: Cognitive Plane (depends on Zenoh)
            let s3_bridge = DAG.createNode "S3_BRIDGE" "CEPAF Bridge" ["S2_ZENOH"] 3000 3 Criticality.P0_Critical
            let s3_cortex = DAG.createNode "S3_CORTEX" "Cortex AI" ["S2_ZENOH"] 5000 3 Criticality.P1_High

            // S3: App Seed (depends on Zenoh)
            let s3_app = DAG.createNode "S3_APP" "App Seed" ["S2_ZENOH"] 12000 3 Criticality.P0_Critical

            // S4: Homeostasis (depends on App + Cortex)
            let s4 = DAG.createNode "S4_HOMEOSTASIS" "Homeostasis" ["S3_APP"; "S3_CORTEX"] 5000 4 Criticality.P0_Critical

            let nodes = [s0; s1_db; s1_obs; s2; s3_bridge; s3_cortex; s3_app; s4]

            // Verify no cycles
            match DAG.detectCycles nodes with
            | None -> ()  // Expected
            | Some cycle -> failtest $"Boot sequence has cycle: {cycle}"

            // Verify topological sort
            match DAG.topologicalSort nodes with
            | Sorted sorted ->
                Expect.hasLength sorted 8 "Should have 8 stages"

                // S0 must be first
                Expect.equal sorted.[0].Id "S0_PREFLIGHT" "Preflight is first"

                // S4 must be last
                Expect.equal sorted.[7].Id "S4_HOMEOSTASIS" "Homeostasis is last"

                // Verify dependencies are satisfied
                for i, node in sorted |> List.indexed do
                    for dep in node.Dependencies do
                        let depIndex = sorted |> List.findIndex (fun n -> n.Id = dep)
                        Expect.isLessThan depIndex i $"{dep} must come before {node.Id}"

            | CycleDetected cycle -> failtest $"Detected cycle: {cycle}"

            // Verify wave grouping
            let waves = DAG.groupByWave nodes
            Expect.hasLength waves 5 "Should have 5 waves"

            // Wave 0: S0
            Expect.hasLength waves.[0] 1 "Wave 0 has 1 node"

            // Wave 1: DB + OBS (parallel)
            Expect.hasLength waves.[1] 2 "Wave 1 has 2 nodes (parallel)"

            // Critical path estimate
            let cpDuration = DAG.estimateCriticalPathDuration nodes
            Expect.isLessThan cpDuration 60000 "Boot should complete < 60s (SC-BOOT-005)"
            printfn "Boot critical path estimate: %dms (%.1fs)" cpDuration (float cpDuration / 1000.0)
        }
    ]

/// Combined test suite
[<Tests>]
let allTests =
    testList "DAG Complete Test Suite" [
        unitTests
        propertyTests
        integrationTests
    ]
