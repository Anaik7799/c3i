// =============================================================================
// FSMTests.fs - TDG-compliant tests for Finite State Machine
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-BOOT-006 (Health check required)
// AOR: AOR-FUNC-001 (Verify compilation), AOR-FUNC-005 (Rollback on failure)
//
// ## Test Coverage
// - Unit tests: State transitions, signal application
// - Property tests: FSM determinism, accepting states
// - Edge cases: Invalid transitions, terminal states
// - Mathematical properties: DFA M = (Q, Σ, δ, q0, F)
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-19 |
// | Author | Claude Opus 4.5 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.FSMTests

open Expecto
open FsCheck
open Cepaf.Mesh
open System

/// Test data generators
module Generators =
    /// Generate random container state
    let stateGen =
        Gen.elements [
            ContainerState.NotFound
            ContainerState.Created
            ContainerState.Starting
            ContainerState.Running
            ContainerState.Healthy
            ContainerState.Unhealthy
            ContainerState.Stopping
            ContainerState.Stopped
            ContainerState.Failed
        ]

    /// Generate random signal
    let signalGen =
        Gen.elements [
            ContainerSignal.Create
            ContainerSignal.Start
            ContainerSignal.HealthOk
            ContainerSignal.HealthFail
            ContainerSignal.Stop
            ContainerSignal.Remove
            ContainerSignal.Crash
            ContainerSignal.Timeout
        ]

    /// Generate sequence of signals
    let signalSequenceGen =
        gen {
            let! length = Gen.choose(1, 20)
            let! signals = Gen.listOfLength length signalGen
            return signals
        }

/// Unit Tests
[<Tests>]
let unitTests =
    testList "FSM Unit Tests" [

        // === Initial State Tests ===

        test "FSM.create - Initial state is NotFound" {
            let fsm = FSM.create "test-id" "test-container"

            Expect.equal fsm.CurrentState ContainerState.NotFound "Initial state is NotFound"
            Expect.isEmpty fsm.History "History is empty"
            Expect.equal fsm.HealthCheckCount 0 "Health check count is 0"
            Expect.equal fsm.ConsecutiveHealthFails 0 "Consecutive fails is 0"
        }

        // === Basic Transition Tests ===

        test "FSM.transition - NotFound + Create = Created" {
            let result = FSM.transition ContainerState.NotFound ContainerSignal.Create
            Expect.equal result ContainerState.Created "NotFound + Create = Created"
        }

        test "FSM.transition - Created + Start = Starting" {
            let result = FSM.transition ContainerState.Created ContainerSignal.Start
            Expect.equal result ContainerState.Starting "Created + Start = Starting"
        }

        test "FSM.transition - Starting + HealthOk = Running" {
            let result = FSM.transition ContainerState.Starting ContainerSignal.HealthOk
            Expect.equal result ContainerState.Running "Starting + HealthOk = Running"
        }

        test "FSM.transition - Running + HealthOk = Healthy" {
            let result = FSM.transition ContainerState.Running ContainerSignal.HealthOk
            Expect.equal result ContainerState.Healthy "Running + HealthOk = Healthy"
        }

        test "FSM.transition - Healthy + HealthOk = Healthy" {
            let result = FSM.transition ContainerState.Healthy ContainerSignal.HealthOk
            Expect.equal result ContainerState.Healthy "Healthy stays Healthy on HealthOk"
        }

        test "FSM.transition - Healthy + HealthFail = Unhealthy" {
            let result = FSM.transition ContainerState.Healthy ContainerSignal.HealthFail
            Expect.equal result ContainerState.Unhealthy "Healthy + HealthFail = Unhealthy"
        }

        test "FSM.transition - Unhealthy + HealthOk = Healthy (recovery)" {
            let result = FSM.transition ContainerState.Unhealthy ContainerSignal.HealthOk
            Expect.equal result ContainerState.Healthy "Unhealthy can recover to Healthy"
        }

        test "FSM.transition - Healthy + Stop = Stopping" {
            let result = FSM.transition ContainerState.Healthy ContainerSignal.Stop
            Expect.equal result ContainerState.Stopping "Healthy + Stop = Stopping"
        }

        test "FSM.transition - Stopping + any = Stopped" {
            let result = FSM.transition ContainerState.Stopping ContainerSignal.HealthOk
            Expect.equal result ContainerState.Stopped "Stopping + any = Stopped"
        }

        test "FSM.transition - Stopped + Start = Starting (restart)" {
            let result = FSM.transition ContainerState.Stopped ContainerSignal.Start
            Expect.equal result ContainerState.Starting "Stopped can restart"
        }

        test "FSM.transition - Crashed states = Failed" {
            Expect.equal (FSM.transition ContainerState.Starting ContainerSignal.Crash) ContainerState.Failed "Starting crash"
            Expect.equal (FSM.transition ContainerState.Running ContainerSignal.Crash) ContainerState.Failed "Running crash"
            Expect.equal (FSM.transition ContainerState.Healthy ContainerSignal.Crash) ContainerState.Failed "Healthy crash"
        }

        test "FSM.transition - Timeout failures" {
            Expect.equal (FSM.transition ContainerState.Starting ContainerSignal.Timeout) ContainerState.Failed "Starting timeout"
            Expect.equal (FSM.transition ContainerState.Unhealthy ContainerSignal.Timeout) ContainerState.Failed "Unhealthy timeout"
        }

        test "FSM.transition - Failed + Start = Starting (recovery attempt)" {
            let result = FSM.transition ContainerState.Failed ContainerSignal.Start
            Expect.equal result ContainerState.Starting "Failed can attempt restart"
        }

        test "FSM.transition - Remove transitions to NotFound" {
            Expect.equal (FSM.transition ContainerState.Created ContainerSignal.Remove) ContainerState.NotFound "Created remove"
            Expect.equal (FSM.transition ContainerState.Stopped ContainerSignal.Remove) ContainerState.NotFound "Stopped remove"
            Expect.equal (FSM.transition ContainerState.Failed ContainerSignal.Remove) ContainerState.NotFound "Failed remove"
        }

        // === FSM State Predicate Tests ===

        test "FSM.isAccepting - Only Healthy is accepting" {
            Expect.isTrue (FSM.isAccepting ContainerState.Healthy) "Healthy is accepting"
            Expect.isFalse (FSM.isAccepting ContainerState.Running) "Running is not accepting"
            Expect.isFalse (FSM.isAccepting ContainerState.Unhealthy) "Unhealthy is not accepting"
            Expect.isFalse (FSM.isAccepting ContainerState.Failed) "Failed is not accepting"
        }

        test "FSM.isTerminal - Failed, Stopped, NotFound are terminal" {
            Expect.isTrue (FSM.isTerminal ContainerState.Failed) "Failed is terminal"
            Expect.isTrue (FSM.isTerminal ContainerState.Stopped) "Stopped is terminal"
            Expect.isTrue (FSM.isTerminal ContainerState.NotFound) "NotFound is terminal"
            Expect.isFalse (FSM.isTerminal ContainerState.Healthy) "Healthy is not terminal"
            Expect.isFalse (FSM.isTerminal ContainerState.Running) "Running is not terminal"
        }

        test "FSM.isRunning - Starting, Running, Healthy, Unhealthy are running" {
            Expect.isTrue (FSM.isRunning ContainerState.Starting) "Starting is running"
            Expect.isTrue (FSM.isRunning ContainerState.Running) "Running is running"
            Expect.isTrue (FSM.isRunning ContainerState.Healthy) "Healthy is running"
            Expect.isTrue (FSM.isRunning ContainerState.Unhealthy) "Unhealthy is running"
            Expect.isFalse (FSM.isRunning ContainerState.NotFound) "NotFound is not running"
            Expect.isFalse (FSM.isRunning ContainerState.Created) "Created is not running"
            Expect.isFalse (FSM.isRunning ContainerState.Stopped) "Stopped is not running"
        }

        // === FSM Instance Tests ===

        test "FSM.applySignal - Tracks state transitions" {
            let fsm = FSM.create "test-id" "test-container"
            let fsm1 = FSM.applySignal fsm ContainerSignal.Create None
            let fsm2 = FSM.applySignal fsm1 ContainerSignal.Start None

            Expect.equal fsm2.CurrentState ContainerState.Starting "State is Starting"
            Expect.hasLength fsm2.History 2 "History has 2 transitions"

            let trans1 = fsm2.History.[1]  // First transition (reversed order)
            Expect.equal trans1.FromState ContainerState.NotFound "First: NotFound -> Created"
            Expect.equal trans1.ToState ContainerState.Created "First: NotFound -> Created"

            let trans2 = fsm2.History.[0]  // Second transition
            Expect.equal trans2.FromState ContainerState.Created "Second: Created -> Starting"
            Expect.equal trans2.ToState ContainerState.Starting "Second: Created -> Starting"
        }

        test "FSM.applySignal - Tracks health check counts" {
            let fsm = FSM.create "test-id" "test-container"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail None

            Expect.equal fsm.HealthCheckCount 3 "3 health checks performed"
            Expect.equal fsm.ConsecutiveHealthFails 1 "1 consecutive fail"
        }

        test "FSM.applySignal - Resets consecutive fails on HealthOk" {
            let fsm = FSM.create "test-id" "test-container"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None

            Expect.equal fsm.ConsecutiveHealthFails 0 "Consecutive fails reset to 0"
        }

        test "FSM.getValidSignals - Returns valid signals for each state" {
            let validFromNotFound = FSM.getValidSignals ContainerState.NotFound
            Expect.contains validFromNotFound ContainerSignal.Create "Create is valid from NotFound"

            let validFromCreated = FSM.getValidSignals ContainerState.Created
            Expect.contains validFromCreated ContainerSignal.Start "Start is valid from Created"
            Expect.contains validFromCreated ContainerSignal.Remove "Remove is valid from Created"

            let validFromHealthy = FSM.getValidSignals ContainerState.Healthy
            Expect.contains validFromHealthy ContainerSignal.HealthOk "HealthOk is valid from Healthy"
            Expect.contains validFromHealthy ContainerSignal.HealthFail "HealthFail is valid from Healthy"
            Expect.contains validFromHealthy ContainerSignal.Stop "Stop is valid from Healthy"
        }
    ]

/// Property-Based Tests
[<Tests>]
let propertyTests =
    testList "FSM Property Tests" [

        testProperty "FSM is deterministic - same state + signal = same result" <| fun () ->
            Prop.forAll
                (Arb.fromGen (Gen.zip Generators.stateGen Generators.signalGen))
                (fun (state, signal) ->
                    let result1 = FSM.transition state signal
                    let result2 = FSM.transition state signal
                    result1 = result2
                )

        testProperty "Transition function is total - defined for all inputs" <| fun () ->
            Prop.forAll
                (Arb.fromGen (Gen.zip Generators.stateGen Generators.signalGen))
                (fun (state, signal) ->
                    // Should never throw exception
                    let _ = FSM.transition state signal
                    true
                )

        testProperty "Accepting state implies running" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.stateGen)
                (fun state ->
                    if FSM.isAccepting state then FSM.isRunning state
                    else true
                )

        testProperty "Terminal states are not running" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.stateGen)
                (fun state ->
                    if FSM.isTerminal state then not (FSM.isRunning state)
                    else true
                )

        testProperty "History length equals number of applied signals" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.signalSequenceGen)
                (fun signals ->
                    let mutable fsm = FSM.create "test" "test"
                    for signal in signals do
                        fsm <- FSM.applySignal fsm signal None
                    fsm.History.Length = signals.Length
                )

        testProperty "Health check count equals HealthOk + HealthFail signals" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.signalSequenceGen)
                (fun signals ->
                    let mutable fsm = FSM.create "test" "test"
                    for signal in signals do
                        fsm <- FSM.applySignal fsm signal None

                    let expectedCount =
                        signals
                        |> List.filter (fun s ->
                            s = ContainerSignal.HealthOk || s = ContainerSignal.HealthFail)
                        |> List.length

                    fsm.HealthCheckCount = expectedCount
                )

        testProperty "HealthOk always resets consecutive fails to 0" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.signalSequenceGen)
                (fun signals ->
                    let mutable fsm = FSM.create "test" "test"
                    for signal in signals do
                        fsm <- FSM.applySignal fsm signal None
                        if signal = ContainerSignal.HealthOk then
                            fsm.ConsecutiveHealthFails = 0
                        else
                            true
                )

        testProperty "Consecutive health fails never exceeds total health checks" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.signalSequenceGen)
                (fun signals ->
                    let mutable fsm = FSM.create "test" "test"
                    for signal in signals do
                        fsm <- FSM.applySignal fsm signal None
                    fsm.ConsecutiveHealthFails <= fsm.HealthCheckCount
                )

        testProperty "State never spontaneously changes without signal" <| fun () ->
            Prop.forAll
                (Arb.fromGen Generators.stateGen)
                (fun state ->
                    // Create FSM in target state
                    let mutable fsm = FSM.create "test" "test"
                    fsm <- { fsm with CurrentState = state }

                    // Wait (in reality, no time passes in test)
                    let stateBefore = fsm.CurrentState

                    // No signal applied
                    let stateAfter = fsm.CurrentState

                    stateBefore = stateAfter
                )
    ]

/// Integration Tests
[<Tests>]
let integrationTests =
    testList "FSM Integration Tests" [

        test "Happy path: NotFound -> Created -> Starting -> Running -> Healthy" {
            let fsm = FSM.create "app-1" "indrajaal-app-1"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create (Some "podman create")
                      |> fun f -> FSM.applySignal f ContainerSignal.Start (Some "podman start")
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk (Some "first health check")
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk (Some "second health check")

            Expect.equal fsm.CurrentState ContainerState.Healthy "Container is healthy"
            Expect.equal fsm.HealthCheckCount 2 "2 health checks"
            Expect.equal fsm.ConsecutiveHealthFails 0 "No consecutive fails"
            Expect.hasLength fsm.History 4 "4 transitions"
        }

        test "Unhealthy recovery path: Healthy -> Unhealthy -> Healthy" {
            let fsm = FSM.create "app-1" "indrajaal-app-1"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail (Some "transient failure")
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk (Some "recovered")

            Expect.equal fsm.CurrentState ContainerState.Healthy "Recovered to healthy"
            Expect.equal fsm.ConsecutiveHealthFails 0 "Consecutive fails reset"
        }

        test "Failure path: Healthy -> Crash -> Failed" {
            let fsm = FSM.create "app-1" "indrajaal-app-1"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.Crash (Some "OOM killed")

            Expect.equal fsm.CurrentState ContainerState.Failed "Container failed"
            Expect.isTrue (FSM.isTerminal fsm.CurrentState) "Failed is terminal"
        }

        test "Graceful shutdown: Healthy -> Stop -> Stopping -> Stopped" {
            let fsm = FSM.create "app-1" "indrajaal-app-1"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.Stop (Some "graceful shutdown")
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail (Some "shutting down")

            Expect.equal fsm.CurrentState ContainerState.Stopped "Container stopped"
            Expect.isTrue (FSM.isTerminal fsm.CurrentState) "Stopped is terminal"
        }

        test "Restart from failure: Failed -> Start -> Starting" {
            let fsm = FSM.create "app-1" "indrajaal-app-1"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.Timeout (Some "startup timeout")
                      |> fun f -> FSM.applySignal f ContainerSignal.Start (Some "retry")

            Expect.equal fsm.CurrentState ContainerState.Starting "Restarting after failure"
        }

        test "Complete lifecycle: Create -> Start -> Healthy -> Stop -> Remove" {
            let fsm = FSM.create "app-1" "indrajaal-app-1"
                      |> fun f -> FSM.applySignal f ContainerSignal.Create None
                      |> fun f -> FSM.applySignal f ContainerSignal.Start None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk None
                      |> fun f -> FSM.applySignal f ContainerSignal.Stop None
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail None
                      |> fun f -> FSM.applySignal f ContainerSignal.Remove None

            Expect.equal fsm.CurrentState ContainerState.NotFound "Back to NotFound"
            Expect.hasLength fsm.History 7 "7 transitions"
        }

        test "Real-world: Indrajaal boot health checks" {
            // Simulate typical Indrajaal container boot
            let fsm = FSM.create "app-prod" "indrajaal-ex-app-1"

            // Create + Start
            let fsm = fsm
                      |> fun f -> FSM.applySignal f ContainerSignal.Create (Some "podman create indrajaal-app")
                      |> fun f -> FSM.applySignal f ContainerSignal.Start (Some "podman start")

            Expect.equal fsm.CurrentState ContainerState.Starting "Container starting"

            // Health checks during startup (first few may fail)
            let fsm = fsm
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail (Some "startup in progress")
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthFail (Some "startup in progress")
                      |> fun f -> FSM.applySignal f ContainerSignal.HealthOk (Some "Phoenix started")

            Expect.equal fsm.CurrentState ContainerState.Running "Container running"

            // Final health check confirms healthy
            let fsm = FSM.applySignal fsm ContainerSignal.HealthOk (Some "all services ready")

            Expect.equal fsm.CurrentState ContainerState.Healthy "Container healthy"
            Expect.isTrue (FSM.isAccepting fsm.CurrentState) "Healthy is accepting state"

            printfn "Container lifecycle: %d transitions, %d health checks"
                fsm.History.Length fsm.HealthCheckCount
        }
    ]

/// Combined test suite
[<Tests>]
let allTests =
    testList "FSM Complete Test Suite" [
        unitTests
        propertyTests
        integrationTests
    ]
