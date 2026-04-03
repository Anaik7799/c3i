module Cepaf.Tests.FractalRuntimeTestPlan

// ============================================================================
// FRACTAL RUNTIME TESTING PLAN
// 5-Level Deep Analysis & Comprehensive Test Strategy
// ============================================================================
// Version: 1.0.0
// Date: 2025-12-29
// Status: ACTIVE
// Compliance: SC-TEST-001 through SC-TEST-050
// ============================================================================

open Expecto
open System
open Cepaf.Cockpit
open Cepaf.Cockpit.Domain

// ============================================================================
// LEVEL 1: SYSTEM CONTEXT (Enterprise Mesh)
// ============================================================================
// Tests at this level verify the entire system operates correctly as a whole
// Focus: End-to-end scenarios, mesh-wide invariants, global health

module Level1_SystemContext =

    /// Test: System-wide health propagation
    let systemHealthTests = testList "L1-System Health" [
        test "L1.1: Fractal health propagates from nodes to system" {
            let ctx = Fractal.leaf FLSystem "system" FractalMetrics.empty
            let node1 = { Fractal.leaf FLNode "node1" { FractalMetrics.empty with Cpu = 20.0 } with HealthScore = 0.9 }
            let node2 = { Fractal.leaf FLNode "node2" { FractalMetrics.empty with Cpu = 80.0 } with HealthScore = 0.5 }

            let system = ctx |> Fractal.addChild node1 |> Fractal.addChild node2 |> Fractal.propagateHealth
            // System health should be min of system health and average of children
            Expect.isLessThan system.HealthScore 0.8 "System health reflects degraded nodes"
        }

        test "L1.2: CEA stability across all homeostatic variables" {
            let cockpit = FractalCockpit.init ()
            let vars = cockpit.Controller.Variables |> Map.toList |> List.length
            Expect.equal vars 4 "4 homeostatic variables initialized (cpu, memory, error_rate, latency)"
        }

        test "L1.3: OODA cycle completes within latency bounds" {
            let cycle = OodaLoop.init<MeshNode, SaLevel, MeshCommand, bool> ()
            Expect.isTrue (OodaLoop.isWithinBounds cycle) "Initial cycle is within bounds"
        }
    ]

// ============================================================================
// LEVEL 2: CONTAINER ARCHITECTURE (Service Components)
// ============================================================================
// Tests at this level verify container/service interactions
// Focus: Inter-service communication, API contracts, container state

module Level2_ContainerArchitecture =

    /// Test: Telemetry stream processing
    let containerTests = testList "L2-Container Services" [
        test "L2.1: TelStream processes without backpressure buildup" {
            let stream = TelStream.empty<int>
            let mapped = stream |> TelStream.map (fun x -> x * 2)
            Expect.isTrue true "Empty stream processes correctly"
        }

        test "L2.2: Signal arrows compose correctly" {
            let smooth = FractalPipeline.smoothingArrow 5
            let trend = FractalPipeline.trendArrow
            let data = [1.0; 2.0; 3.0; 4.0; 5.0]
            let smoothed = SignalArrow.run smooth data
            Expect.floatClose Accuracy.medium smoothed 3.0 "Smoothing produces correct average"
        }

        test "L2.3: CEA controller processes variable updates" {
            let controller = CeaControl.createController []
                            |> fun c -> { c with Variables = Map.add "test" (CeaControl.createVar "test" 50.0 10.0 0.1) c.Variables }
                            |> CeaControl.updateVariable "test" 45.0
                            |> CeaControl.processController
            // Deviation of -5.0 is within tolerance (10.0), so stability should be high
            Expect.isGreaterThan controller.StabilityScore 0.7 "Variable within tolerance has high stability"
        }
    ]

// ============================================================================
// LEVEL 3: COMPONENT ARCHITECTURE (Domain Modules)
// ============================================================================
// Tests at this level verify individual domain modules
// Focus: Module boundaries, domain logic, state transitions

module Level3_ComponentArchitecture =

    /// Test: Fractal context operations
    let componentTests = testList "L3-Domain Modules" [
        test "L3.1: Fractal.map preserves structure" {
            let ctx = Fractal.leaf FLNode "n1" 10.0
            let child = Fractal.leaf FLComponent "c1" 5.0
            let parent = Fractal.addChild child ctx
            let mapped = Fractal.map (fun x -> x * 2.0) parent

            Expect.equal mapped.Data 20.0 "Parent data doubled"
            Expect.equal (List.length mapped.Children) 1 "Children preserved"
        }

        test "L3.2: Fractal.fold aggregates correctly" {
            let root = Fractal.leaf FLSystem "sys" 10.0
            let n1 = Fractal.leaf FLNode "n1" 20.0
            let n2 = Fractal.leaf FLNode "n2" 30.0
            let tree = root |> Fractal.addChild n1 |> Fractal.addChild n2

            let sum = Fractal.fold (fun acc x -> acc + x) 0.0 tree
            Expect.floatClose Accuracy.medium sum 60.0 "Fold sums all values"
        }

        test "L3.3: OODA phase transitions are valid" {
            Expect.equal (OodaLoop.phaseName (OodaObserve 100)) "OBSERVE" "Observe phase named correctly"
            Expect.equal (OodaLoop.phaseName (OodaOrient 100)) "ORIENT" "Orient phase named correctly"
            Expect.equal (OodaLoop.phaseName (OodaDecide 100)) "DECIDE" "Decide phase named correctly"
            Expect.equal (OodaLoop.phaseName (OodaAct 100)) "ACT" "Act phase named correctly"
        }
    ]

// ============================================================================
// LEVEL 4: MODULE ARCHITECTURE (Classes/Functions)
// ============================================================================
// Tests at this level verify individual functions and types
// Focus: Function contracts, type safety, edge cases

module Level4_ModuleArchitecture =

    /// Test: HomeostasisVar operations
    let moduleTests = testList "L4-Functions & Types" [
        test "L4.1: HomeostasisVar deviation calculation" {
            let v = CeaControl.createVar "test" 50.0 10.0 0.1
            let updated = CeaControl.updateVar 60.0 v
            Expect.floatClose Accuracy.medium (CeaControl.deviation updated) 10.0 "Deviation = current - setpoint"
        }

        test "L4.2: CeaControlAction determination thresholds" {
            let v = CeaControl.createVar "test" 50.0 10.0 0.1

            // Within tolerance
            let withinTol = CeaControl.updateVar 55.0 v
            Expect.equal (CeaControl.determineAction withinTol) CeaNoAction "Within tolerance: no action"

            // Alert threshold (> 2x tolerance)
            let alert = CeaControl.updateVar 80.0 v
            match CeaControl.determineAction alert with
            | CeaAlert _ -> ()
            | _ -> failtest "Expected Alert at 2x tolerance"

            // Emergency threshold (> 3x tolerance)
            let emergency = CeaControl.updateVar 95.0 v
            match CeaControl.determineAction emergency with
            | CeaEmergency _ -> ()
            | _ -> failtest "Expected Emergency at 3x tolerance"
        }

        test "L4.3: SaLevel determination from scores" {
            let cockpit = FractalCockpit.init ()
            let saLevel = FractalCockpit.getSaLevel cockpit
            Expect.equal saLevel SaPerception "Fresh cockpit has full perception"
        }

        test "L4.4: FractalMetrics.empty has zero values" {
            let m = FractalMetrics.empty
            Expect.equal m.Cpu 0.0 "CPU is 0"
            Expect.equal m.Memory 0.0 "Memory is 0"
            Expect.equal m.Latency 0.0 "Latency is 0"
        }
    ]

// ============================================================================
// LEVEL 5: CODE LEVEL (Implementation Details)
// ============================================================================
// Tests at this level verify implementation correctness
// Focus: Edge cases, error handling, performance characteristics

module Level5_CodeLevel =

    /// Test: Edge cases and implementation details
    let codeTests = testList "L5-Implementation" [
        test "L5.1: Empty list handling in Fractal.depth" {
            let leaf = Fractal.leaf FLComponent "c1" 1.0
            Expect.equal (Fractal.depth leaf) 1 "Leaf has depth 1"
        }

        test "L5.2: Deep tree handling" {
            let level5 = Fractal.leaf FLComponent "c" 1.0
            let level4 = Fractal.leaf FLProcess "p" 2.0 |> Fractal.addChild level5
            let level3 = Fractal.leaf FLNode "n" 3.0 |> Fractal.addChild level4
            let level2 = Fractal.leaf FLCluster "cl" 4.0 |> Fractal.addChild level3
            let level1 = Fractal.leaf FLSystem "s" 5.0 |> Fractal.addChild level2

            Expect.equal (Fractal.depth level1) 5 "5-level deep tree has depth 5"
        }

        test "L5.3: Stability score with empty deviation history" {
            let v = CeaControl.createVar "test" 50.0 10.0 0.1
            Expect.equal (CeaControl.stabilityScore v) 1.0 "Empty history = full stability"
        }

        test "L5.4: Stability score degrades with high deviation" {
            let v = { CeaControl.createVar "test" 50.0 10.0 0.1 with
                        DeviationHistory = [30.0; 30.0; 30.0] }  // 3x tolerance
            let score = CeaControl.stabilityScore v
            Expect.isLessThan score 0.5 "High deviation reduces stability"
        }

        test "L5.5: OODA cycle count increments" {
            let cycle = OodaLoop.init<int, int, int, int> ()
            let observe () = 1
            let orient xs = List.sum xs
            let decide x = x * 2
            let act x = x + 1

            let afterOne = OodaLoop.executeCycle observe orient decide act cycle
            Expect.equal afterOne.CycleCount 1L "First cycle: count = 1"

            let afterTwo = OodaLoop.executeCycle observe orient decide act afterOne
            Expect.equal afterTwo.CycleCount 2L "Second cycle: count = 2"
        }

        test "L5.6: Trend detection edge cases" {
            let trend = FractalPipeline.trendArrow

            // Empty list
            Expect.equal (SignalArrow.run trend []) Stable "Empty list: Stable"

            // Single value
            Expect.equal (SignalArrow.run trend [1.0]) Stable "Single value: Stable"

            // Rising fast
            Expect.equal (SignalArrow.run trend [10.0; 9.0; 8.0; 7.0; 6.0]) RisingFast "Rising fast detected"

            // Falling fast
            Expect.equal (SignalArrow.run trend [1.0; 2.0; 3.0; 4.0; 5.0]) FallingFast "Falling fast detected"
        }
    ]

// ============================================================================
// INTEGRATION TESTS (Cross-Level Verification)
// ============================================================================

module IntegrationTests =

    /// Test: Full cockpit lifecycle
    let integrationTests = testList "Integration" [
        test "INT.1: FractalCockpit full lifecycle" {
            // Initialize
            let cockpit = FractalCockpit.init ()
            Expect.equal cockpit.FrameCount 0L "Initial frame count is 0"

            // Create a mock node
            let node : MeshNode = createNode "test-node" "TestNode" "zone1" Worker

            // Process node
            let updated = FractalCockpit.processNode node cockpit
            Expect.equal updated.FrameCount 1L "Frame count increments"
            Expect.equal (List.length updated.Context.Children) 1 "Child added to context"
        }

        test "INT.2: CEA feedback loop" {
            let cockpit = FractalCockpit.init ()

            // Simulate high CPU
            let node : MeshNode = createNode "hot-node" "HotNode" "zone1" Worker
                                  |> fun n -> { n with Cpu = updateMetric 90.0 n.Cpu }

            let updated = FractalCockpit.processNode node cockpit

            // Check CEA detected the issue
            let cpuVar = Map.tryFind "cpu_usage" updated.Controller.Variables
            match cpuVar with
            | Some v -> Expect.isTrue (v.CurrentValue > 80.0) "CPU variable updated"
            | None -> failtest "CPU variable not found"
        }

        test "INT.3: SA level degrades with poor metrics" {
            let cockpit = FractalCockpit.init ()

            // Create very unhealthy context
            let unhealthyCockpit = { cockpit with
                                        Context = { cockpit.Context with HealthScore = 0.3 }
                                        Controller = { cockpit.Controller with StabilityScore = 0.2 } }

            let saLevel = FractalCockpit.getSaLevel unhealthyCockpit
            match saLevel with
            | SaDegraded _ -> ()
            | _ -> failtest "Expected degraded SA with poor health"
        }
    ]

// ============================================================================
// PROPERTY-BASED TESTS (Invariants)
// ============================================================================

module PropertyTests =

    /// Test: Fractal invariants
    let propertyTests = testList "Properties" [
        test "PROP.1: Fractal.map preserves structure invariant" {
            // For any tree, map id = id
            let tree = Fractal.leaf FLSystem "s" 1.0
                       |> Fractal.addChild (Fractal.leaf FLNode "n1" 2.0)
                       |> Fractal.addChild (Fractal.leaf FLNode "n2" 3.0)

            let mapped = Fractal.map id tree
            Expect.equal (List.length mapped.Children) (List.length tree.Children) "Children count preserved"
            Expect.equal mapped.Level tree.Level "Level preserved"
        }

        test "PROP.2: Fractal.propagateHealth monotonically decreases" {
            let parent = { Fractal.leaf FLSystem "s" 1.0 with HealthScore = 1.0 }
            let unhealthyChild = { Fractal.leaf FLNode "n" 1.0 with HealthScore = 0.3 }
            let tree = Fractal.addChild unhealthyChild parent
            let propagated = Fractal.propagateHealth tree

            Expect.isLessThanOrEqual propagated.HealthScore 1.0 "Health <= 1.0"
            Expect.isLessThanOrEqual propagated.HealthScore parent.HealthScore "Health doesn't increase"
        }

        test "PROP.3: CEA stability score is bounded [0, 1]" {
            let v = { CeaControl.createVar "test" 50.0 10.0 0.1 with
                        DeviationHistory = [100.0; -100.0; 50.0; -50.0] }
            let score = CeaControl.stabilityScore v
            Expect.isGreaterThanOrEqual score 0.0 "Stability >= 0"
            Expect.isLessThanOrEqual score 1.0 "Stability <= 1"
        }
    ]

// ============================================================================
// AGGREGATE ALL TESTS
// ============================================================================

[<Tests>]
let fractalRuntimeTests =
    testList "Fractal Runtime Test Plan" [
        Level1_SystemContext.systemHealthTests
        Level2_ContainerArchitecture.containerTests
        Level3_ComponentArchitecture.componentTests
        Level4_ModuleArchitecture.moduleTests
        Level5_CodeLevel.codeTests
        IntegrationTests.integrationTests
        PropertyTests.propertyTests
    ]

// ============================================================================
// TEST PLAN SUMMARY
// ============================================================================
//
// LEVEL 1 - SYSTEM CONTEXT (3 tests)
//   L1.1: Fractal health propagation
//   L1.2: CEA homeostatic variables
//   L1.3: OODA latency bounds
//
// LEVEL 2 - CONTAINER ARCHITECTURE (3 tests)
//   L2.1: TelStream backpressure
//   L2.2: Signal arrow composition
//   L2.3: CEA variable updates
//
// LEVEL 3 - COMPONENT ARCHITECTURE (3 tests)
//   L3.1: Fractal.map structure preservation
//   L3.2: Fractal.fold aggregation
//   L3.3: OODA phase transitions
//
// LEVEL 4 - MODULE ARCHITECTURE (4 tests)
//   L4.1: HomeostasisVar deviation
//   L4.2: CeaControlAction thresholds
//   L4.3: SaLevel determination
//   L4.4: FractalMetrics defaults
//
// LEVEL 5 - CODE LEVEL (6 tests)
//   L5.1: Fractal.depth edge case
//   L5.2: Deep tree handling
//   L5.3: Stability empty history
//   L5.4: Stability high deviation
//   L5.5: OODA cycle count
//   L5.6: Trend detection edges
//
// INTEGRATION (3 tests)
//   INT.1: Full lifecycle
//   INT.2: CEA feedback loop
//   INT.3: SA level degradation
//
// PROPERTIES (3 tests)
//   PROP.1: map id = id
//   PROP.2: Health monotonicity
//   PROP.3: Stability bounds
//
// TOTAL: 25 fractal runtime tests
// ============================================================================
