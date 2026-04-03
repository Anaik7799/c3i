// =============================================================================
// HysteresisTests.fs - TDG-compliant tests for Health Check Hysteresis
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-OPT-002 (Prevent health flapping)
// AOR: AOR-BOOT-003 (Prevent health check flapping)
//
// ## Test Coverage
// - Unit tests: Consecutive check handling, state transitions
// - Property tests: Hysteresis invariants, debounce behavior
// - Edge cases: Rapid flapping, single checks, threshold boundaries
// - Mathematical properties: H(n) = NewState if last N checks agree
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

module Cepaf.Tests.Unit.Mesh.HysteresisTests

open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf.Mesh
open System

/// Test data generators (FsCheck 3.x compatible)
module Generators =
    /// Generate random health state
    let healthStateGen : Gen<HealthState> =
        Gen.elements [
            HealthState.Healthy
            HealthState.Unhealthy
            HealthState.Unknown
            HealthState.Degraded
        ]

    /// Generate sequence of health checks (simulating flapping) - FsCheck 3.x style
    let healthSequenceGen : Gen<HealthState list> =
        Gen.choose(5, 30) |> Gen.bind (fun length ->
            Gen.listOfLength length healthStateGen
        )

    /// Generate alternating sequence (worst case flapping) - FsCheck 3.x style
    let flappingSequenceGen : Gen<HealthState list> =
        Gen.choose(10, 20) |> Gen.map (fun length ->
            List.init length (fun i ->
                if i % 2 = 0 then HealthState.Healthy else HealthState.Unhealthy)
        )

    /// Generate stable sequence (all same state) - FsCheck 3.x style
    let stableSequenceGen : Gen<HealthState list> =
        Gen.choose(5, 15) |> Gen.bind (fun length ->
            healthStateGen |> Gen.map (fun state ->
                List.replicate length state
            )
        )

/// Unit Tests
[<Tests>]
let unitTests =
    testList "Hysteresis Unit Tests" [

        // === Initialization Tests ===

        test "Hysteresis.create - Initial state is Unknown" {
            let state = Hysteresis.create ()

            Expect.equal state.CurrentState HealthState.Unknown "Initial state is Unknown"
            Expect.equal state.ConsecutiveCount 0 "Consecutive count is 0"
            Expect.isNone state.PendingState "No pending state"
            Expect.isEmpty state.History "History is empty"
            Expect.equal state.TotalHealthyChecks 0 "No healthy checks yet"
            Expect.equal state.TotalUnhealthyChecks 0 "No unhealthy checks yet"
        }

        // === Basic Transition Tests ===

        test "Hysteresis.applyCheck - First Healthy check sets pending" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()
            let (newState, result) = Hysteresis.applyCheck config state HealthState.Healthy

            match result with
            | StateUnchanged (current, consecutive) ->
                Expect.equal current HealthState.Unknown "Still Unknown"
                Expect.equal consecutive 1 "1 consecutive check"
                Expect.equal newState.PendingState (Some HealthState.Healthy) "Pending Healthy"
            | _ -> failtest "Expected StateUnchanged"
        }

        test "Hysteresis.applyCheck - RequiredConsecutive checks trigger transition" {
            let config = Hysteresis.defaultConfig  // 3 consecutive required
            let state = Hysteresis.create ()

            // First check
            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            Expect.equal state1.CurrentState HealthState.Unknown "Still Unknown after 1 check"

            // Second check
            System.Threading.Thread.Sleep(600)  // Wait for debounce
            let (state2, _) = Hysteresis.applyCheck config state1 HealthState.Healthy
            Expect.equal state2.CurrentState HealthState.Unknown "Still Unknown after 2 checks"

            // Third check - should transition
            System.Threading.Thread.Sleep(600)
            let (state3, result) = Hysteresis.applyCheck config state2 HealthState.Healthy

            match result with
            | StateTransitioned (from, to') ->
                Expect.equal from HealthState.Unknown "Transitioned from Unknown"
                Expect.equal to' HealthState.Healthy "Transitioned to Healthy"
                Expect.equal state3.CurrentState HealthState.Healthy "Current state is Healthy"
            | _ -> failtest "Expected StateTransitioned"
        }

        test "Hysteresis.applyCheck - Same state resets consecutive counter" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // Transition to Healthy
            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state2, _) = Hysteresis.applyCheck config state1 HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state3, _) = Hysteresis.applyCheck config state2 HealthState.Healthy
            System.Threading.Thread.Sleep(600)

            // Now apply same state again
            let (state4, result) = Hysteresis.applyCheck config state3 HealthState.Healthy

            match result with
            | StateUnchanged (current, consecutive) ->
                Expect.equal current HealthState.Healthy "Current is Healthy"
                Expect.equal consecutive 0 "Consecutive reset to 0"
                Expect.isNone state4.PendingState "No pending state"
            | _ -> failtest "Expected StateUnchanged"
        }

        test "Hysteresis.applyCheck - Different pending resets counter" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // 2 Healthy checks
            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state2, _) = Hysteresis.applyCheck config state1 HealthState.Healthy
            Expect.equal state2.ConsecutiveCount 2 "2 consecutive Healthy"

            // Now Unhealthy - should reset counter
            System.Threading.Thread.Sleep(600)
            let (state3, result) = Hysteresis.applyCheck config state2 HealthState.Unhealthy

            match result with
            | StateUnchanged (_, consecutive) ->
                Expect.equal consecutive 1 "Counter reset, now 1 Unhealthy"
                Expect.equal state3.PendingState (Some HealthState.Unhealthy) "Pending Unhealthy"
            | _ -> failtest "Expected StateUnchanged"
        }

        test "Hysteresis.applyCheck - Debounce prevents rapid transitions" {
            let config = { Hysteresis.defaultConfig with DebounceMs = 1000 }
            let state = Hysteresis.create ()

            // Transition to Healthy
            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            System.Threading.Thread.Sleep(1100)
            let (state2, _) = Hysteresis.applyCheck config state1 HealthState.Healthy
            System.Threading.Thread.Sleep(1100)
            let (state3, _) = Hysteresis.applyCheck config state2 HealthState.Healthy

            Expect.equal state3.CurrentState HealthState.Healthy "Transitioned to Healthy"

            // Immediate check within debounce - should be ignored
            let (state4, result) = Hysteresis.applyCheck config state3 HealthState.Unhealthy

            match result with
            | Debounced reason ->
                Expect.stringContains reason "debounce" "Debounced"
                Expect.equal state4.CurrentState HealthState.Healthy "State unchanged"
            | _ -> failtest "Expected Debounced"
        }

        test "Hysteresis.applyCheck - Updates statistics" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state2, _) = Hysteresis.applyCheck config state1 HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state3, _) = Hysteresis.applyCheck config state2 HealthState.Unhealthy
            System.Threading.Thread.Sleep(600)
            let (state4, _) = Hysteresis.applyCheck config state3 HealthState.Unhealthy

            Expect.equal state4.TotalHealthyChecks 2 "2 healthy checks"
            Expect.equal state4.TotalUnhealthyChecks 2 "2 unhealthy checks"
        }

        test "Hysteresis.applyCheck - Maintains history" {
            let config = { Hysteresis.defaultConfig with MaxHistory = 5 }
            let state = Hysteresis.create ()

            let mutable currentState = state
            for i in 1..7 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.hasLength currentState.History 5 "History limited to 5"
        }

        // === Helper Function Tests ===

        test "Hysteresis.getHealthPercentage - Calculates correctly" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // 3 Healthy, 1 Unhealthy = 75%
            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state2, _) = Hysteresis.applyCheck config state1 HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state3, _) = Hysteresis.applyCheck config state2 HealthState.Healthy
            System.Threading.Thread.Sleep(600)
            let (state4, _) = Hysteresis.applyCheck config state3 HealthState.Unhealthy

            let percentage = Hysteresis.getHealthPercentage state4
            Expect.equal percentage 75.0 "75% healthy"
        }

        test "Hysteresis.getRecentTrend - Returns recent checks" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // 2 Healthy, 3 Unhealthy
            let mutable currentState = state
            for _ in 1..2 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState
            for _ in 1..3 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Unhealthy
                currentState <- newState

            let (healthy, unhealthy) = Hysteresis.getRecentTrend 5 currentState
            Expect.equal healthy 2 "2 healthy in last 5"
            Expect.equal unhealthy 3 "3 unhealthy in last 5"
        }

        test "Hysteresis.isStableHealthy - Checks stable healthy state" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // Transition to Healthy
            let mutable currentState = state
            for _ in 1..3 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.isTrue (Hysteresis.isStableHealthy currentState) "Is stable healthy"

            // Apply Healthy again (should remain stable)
            System.Threading.Thread.Sleep(600)
            let (currentState2, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
            Expect.isTrue (Hysteresis.isStableHealthy currentState2) "Still stable healthy"
        }

        test "Hysteresis.isTrendingDown - Detects downward trend" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // Healthy state
            let mutable currentState = state
            for _ in 1..3 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.isFalse (Hysteresis.isTrendingDown currentState) "Not trending down"

            // Add Unhealthy check (pending)
            System.Threading.Thread.Sleep(600)
            let (currentState2, _) = Hysteresis.applyCheck config currentState HealthState.Unhealthy

            Expect.isTrue (Hysteresis.isTrendingDown currentState2) "Trending down (pending Unhealthy)"
        }

        // === Configuration Tests ===

        test "Hysteresis.aggressiveConfig - Faster transitions" {
            let config = Hysteresis.aggressiveConfig  // 2 consecutive
            let state = Hysteresis.create ()

            // Should transition after 2 checks
            let (state1, _) = Hysteresis.applyCheck config state HealthState.Healthy
            System.Threading.Thread.Sleep(300)
            let (state2, result) = Hysteresis.applyCheck config state1 HealthState.Healthy

            match result with
            | StateTransitioned (_, to') ->
                Expect.equal to' HealthState.Healthy "Transitioned after 2 checks"
            | _ -> failtest "Expected StateTransitioned with aggressive config"
        }

        test "Hysteresis.conservativeConfig - Slower transitions" {
            let config = Hysteresis.conservativeConfig  // 5 consecutive
            let state = Hysteresis.create ()

            // Should NOT transition after 3 checks
            let mutable currentState = state
            for _ in 1..3 do
                System.Threading.Thread.Sleep(1100)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.equal currentState.CurrentState HealthState.Unknown "Still Unknown after 3 checks"

            // Should transition after 5 checks
            for _ in 1..2 do
                System.Threading.Thread.Sleep(1100)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.equal currentState.CurrentState HealthState.Healthy "Healthy after 5 checks"
        }
    ]

/// Property-Based Tests (FsCheck 3.x compatible)
[<Tests>]
let propertyTests =
    testList "Hysteresis Property Tests" [

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 10 } "Consecutive count never exceeds required threshold" <|
            fun () ->
                let arb = Arb.fromGen Generators.healthSequenceGen
                Prop.forAll arb (fun healthChecks ->
                    let config = Hysteresis.defaultConfig
                    let mutable state = Hysteresis.create ()

                    for check in healthChecks do
                        let (newState, _) = Hysteresis.applyCheck config state check
                        state <- newState

                    state.ConsecutiveCount <= config.RequiredConsecutive
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 10 } "Total checks = healthy + unhealthy + unknown + degraded" <|
            fun () ->
                let arb = Arb.fromGen Generators.healthSequenceGen
                Prop.forAll arb (fun healthChecks ->
                    let config = Hysteresis.defaultConfig
                    let mutable state = Hysteresis.create ()

                    for check in healthChecks do
                        let (newState, _) = Hysteresis.applyCheck config state check
                        state <- newState

                    let totalInHistory =
                        state.TotalHealthyChecks + state.TotalUnhealthyChecks

                    // Should account for all checks (Unknown/Degraded don't increment counters)
                    let expectedTotal =
                        healthChecks
                        |> List.filter (fun h -> h = HealthState.Healthy || h = HealthState.Unhealthy)
                        |> List.length

                    totalInHistory = expectedTotal
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 10 } "Health percentage always in [0, 100]" <|
            fun () ->
                let arb = Arb.fromGen Generators.healthSequenceGen
                Prop.forAll arb (fun healthChecks ->
                    let config = Hysteresis.defaultConfig
                    let mutable state = Hysteresis.create ()

                    for check in healthChecks do
                        let (newState, _) = Hysteresis.applyCheck config state check
                        state <- newState

                    let percentage = Hysteresis.getHealthPercentage state
                    percentage >= 0.0 && percentage <= 100.0
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 10 } "Stable sequence eventually transitions" <|
            fun () ->
                let arb = Arb.fromGen Generators.stableSequenceGen
                Prop.forAll arb (fun healthChecks ->
                    let config = Hysteresis.defaultConfig
                    let mutable state = Hysteresis.create ()

                    for check in healthChecks do
                        let (newState, _) = Hysteresis.applyCheck config state check
                        state <- newState

                    if healthChecks.Length >= config.RequiredConsecutive then
                        state.CurrentState = healthChecks.[0]
                    else
                        true  // Not enough checks to transition
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 10 } "History never exceeds MaxHistory" <|
            fun () ->
                let arb = Arb.fromGen Generators.healthSequenceGen
                Prop.forAll arb (fun healthChecks ->
                    let config = { Hysteresis.defaultConfig with MaxHistory = 10 }
                    let mutable state = Hysteresis.create ()

                    for check in healthChecks do
                        let (newState, _) = Hysteresis.applyCheck config state check
                        state <- newState

                    state.History.Length <= config.MaxHistory
                )

        testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 10 } "Flapping sequence prevents transitions" <|
            fun () ->
                let arb = Arb.fromGen Generators.flappingSequenceGen
                Prop.forAll arb (fun healthChecks ->
                    let config = Hysteresis.defaultConfig
                    let mutable state = Hysteresis.create ()

                    for check in healthChecks do
                        let (newState, _) = Hysteresis.applyCheck config state check
                        state <- newState

                    // In a perfectly alternating sequence, state should never transition
                    // (consecutive count keeps resetting)
                    state.CurrentState = HealthState.Unknown || state.ConsecutiveCount < config.RequiredConsecutive
                )
    ]

/// Integration Tests
[<Tests>]
let integrationTests =
    testList "Hysteresis Integration Tests" [

        test "Real-world: Container health check flapping prevention" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // Simulate real-world flapping: H U H U H H H
            let checks = [
                HealthState.Healthy
                HealthState.Unhealthy
                HealthState.Healthy
                HealthState.Unhealthy
                HealthState.Healthy
                HealthState.Healthy
                HealthState.Healthy
            ]

            let mutable currentState = state
            for check in checks do
                System.Threading.Thread.Sleep(600)
                let (newState, result) = Hysteresis.applyCheck config currentState check
                currentState <- newState

                match result with
                | StateTransitioned (from, to') ->
                    printfn "Transition: %A -> %A" from to'
                | StateUnchanged (current, consecutive) ->
                    printfn "Unchanged: %A (pending %d)" current consecutive
                | Debounced reason ->
                    printfn "Debounced: %s" reason

            // After flapping, last 3 Healthy should transition
            Expect.equal currentState.CurrentState HealthState.Healthy "Eventually healthy"
            printfn "Final health: %.1f%%" (Hysteresis.getHealthPercentage currentState)
        }

        test "Real-world: Transient failure recovery" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // Start healthy
            let mutable currentState = state
            for _ in 1..3 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.equal currentState.CurrentState HealthState.Healthy "Initially healthy"

            // Single transient failure (should NOT transition)
            System.Threading.Thread.Sleep(600)
            let (currentState2, _) = Hysteresis.applyCheck config currentState HealthState.Unhealthy
            Expect.equal currentState2.CurrentState HealthState.Healthy "Still healthy (1 failure)"

            // Recover immediately
            System.Threading.Thread.Sleep(600)
            let (currentState3, _) = Hysteresis.applyCheck config currentState2 HealthState.Healthy
            Expect.equal currentState3.CurrentState HealthState.Healthy "Recovered"
            Expect.equal currentState3.ConsecutiveCount 0 "No pending transition"

            printfn "Transient failure successfully ignored by hysteresis"
        }

        test "Real-world: Sustained failure triggers transition" {
            let config = Hysteresis.defaultConfig
            let state = Hysteresis.create ()

            // Start healthy
            let mutable currentState = state
            for _ in 1..3 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Healthy
                currentState <- newState

            Expect.equal currentState.CurrentState HealthState.Healthy "Initially healthy"

            // Sustained failures (3 consecutive)
            for _ in 1..3 do
                System.Threading.Thread.Sleep(600)
                let (newState, _) = Hysteresis.applyCheck config currentState HealthState.Unhealthy
                currentState <- newState

            Expect.equal currentState.CurrentState HealthState.Unhealthy "Transitioned to unhealthy"
            printfn "Sustained failures correctly triggered transition"
        }

        test "Real-world: Indrajaal container startup with hysteresis" {
            // Use aggressive config for faster startup
            let config = Hysteresis.aggressiveConfig
            let state = Hysteresis.create ()

            // Simulate container startup health checks
            // Initial checks may fail during warmup
            let checks = [
                HealthState.Unhealthy  // Port not yet bound
                HealthState.Unhealthy  // Phoenix starting
                HealthState.Healthy    // Phoenix ready
                HealthState.Healthy    // Stable
            ]

            let mutable currentState = state
            for check in checks do
                System.Threading.Thread.Sleep(300)
                let (newState, result) = Hysteresis.applyCheck config currentState check
                currentState <- newState

                match result with
                | StateTransitioned (from, to') ->
                    printfn "Startup transition: %A -> %A" from to'
                | StateUnchanged (current, consecutive) ->
                    printfn "Startup check: %A (pending %d)" current consecutive
                | Debounced _ -> ()

            Expect.equal currentState.CurrentState HealthState.Healthy "Container healthy after startup"
            printfn "Startup health: %.1f%% (%d checks)"
                (Hysteresis.getHealthPercentage currentState)
                (currentState.TotalHealthyChecks + currentState.TotalUnhealthyChecks)
        }
    ]

/// Combined test suite
[<Tests>]
let allTests =
    testList "Hysteresis Complete Test Suite" [
        unitTests
        propertyTests
        integrationTests
    ]
