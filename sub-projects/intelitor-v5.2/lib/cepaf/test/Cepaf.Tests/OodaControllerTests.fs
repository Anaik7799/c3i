module OodaControllerTests

open System
open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf
open Cepaf.OodaController
open Cepaf.Podman.Domain

/// TDG: Property-based tests for OODA Controller
/// Reference: GEMINI.md Section 4.0 - TDG Methodology
module Properties =

    /// All observations must have valid timestamps
    let observationTimestampValid (obs: Observation) =
        obs.Timestamp <= DateTimeOffset.UtcNow.AddMinutes(1.0) &&
        obs.Timestamp >= DateTimeOffset.MinValue

    /// All orientations must produce at least one action
    let orientationProducesActions (obs: Observation) =
        let orientation = Orient.orient obs
        orientation.RecommendedActions.Length >= 1

    /// Decide must return one of the recommended actions or NoAction
    let decideSelectsValidAction (orientation: Orientation) =
        let state = initialState
        let action = Decide.decide orientation state
        match action with
        | NoAction _ -> true
        | _ -> List.exists ((=) action) orientation.RecommendedActions || orientation.RecommendedActions.IsEmpty

/// Unit tests for OODA phases
[<Tests>]
let observeTests =
    testList "Observe Phase" [
        testCase "fromHealthCheck creates Info severity for Healthy status" <| fun _ ->
            let obs = Observe.fromHealthCheck "test-container" HealthStatus.Healthy
            Expect.equal obs.Severity Info "Healthy should be Info"

        testCase "fromHealthCheck creates Critical severity for Unhealthy status" <| fun _ ->
            let obs = Observe.fromHealthCheck "test-container" (HealthStatus.Unhealthy 3)
            Expect.equal obs.Severity Critical "Unhealthy should be Critical"

        testCase "fromHealthCheck creates Warning severity for NoHealthcheck" <| fun _ ->
            let obs = Observe.fromHealthCheck "test-container" HealthStatus.NoHealthcheck
            Expect.equal obs.Severity Warning "NoHealthcheck should be Warning"

        testCase "fromMetric creates Warning when above threshold" <| fun _ ->
            let obs = Observe.fromMetric "cpu" 95.0 90.0
            Expect.equal obs.Severity Warning "Above threshold should be Warning"

        testCase "fromMetric creates Info when below threshold" <| fun _ ->
            let obs = Observe.fromMetric "cpu" 50.0 90.0
            Expect.equal obs.Severity Info "Below threshold should be Info"
    ]

[<Tests>]
let orientTests =
    testList "Orient Phase" [
        testCase "classifyError identifies ResourceExhaustion" <| fun _ ->
            let pattern = Orient.classifyError "out of memory error occurred"
            Expect.equal pattern ResourceExhaustion "Should identify out of memory"

        testCase "classifyError identifies NetworkIssue for address in use" <| fun _ ->
            let pattern = Orient.classifyError "bind: address already in use"
            Expect.equal pattern NetworkIssue "Should identify port conflict"

        testCase "classifyError identifies DependencyFailure for DB startup" <| fun _ ->
            let pattern = Orient.classifyError "the database system is starting up"
            Expect.equal pattern DependencyFailure "Should identify DB startup"

        testCase "classifyError identifies SecurityViolation" <| fun _ ->
            let pattern = Orient.classifyError "permission denied accessing /etc/passwd"
            Expect.equal pattern SecurityViolation "Should identify permission denied"

        testCase "classifyError returns UnknownPattern for unknown errors" <| fun _ ->
            let pattern = Orient.classifyError "some random error message"
            Expect.equal pattern UnknownPattern "Should return Unknown for unrecognized"

        testCase "orient produces HealthDegradation for Unhealthy status" <| fun _ ->
            let obs = Observe.fromHealthCheck "test" (HealthStatus.Unhealthy 5)
            let orientation = Orient.orient obs
            Expect.equal orientation.Pattern HealthDegradation "Should identify health degradation"

        testCase "orient sets correct impact scope for container failures" <| fun _ ->
            let obs = Observe.fromHealthCheck "test" (HealthStatus.Unhealthy 1)
            let orientation = Orient.orient obs
            Expect.equal orientation.Impact.Scope SingleContainer "Container failure is single container scope"
    ]

[<Tests>]
let decideTests =
    testList "Decide Phase" [
        testCase "decide returns NoAction when no recommendations" <| fun _ ->
            let orientation = {
                Pattern = UnknownPattern
                RootCause = None
                Impact = { Scope = SingleContainer; ServicesAffected = []; EstimatedRecoveryMs = 0L }
                RecommendedActions = []
            }
            let action = Decide.decide orientation initialState
            match action with
            | NoAction _ -> ()
            | _ -> failtest "Should return NoAction for empty recommendations"

        testCase "decide returns single action when only one recommendation" <| fun _ ->
            let expectedAction = HealthCheck "test-container"
            let orientation = {
                Pattern = ContainerStartup
                RootCause = None
                Impact = { Scope = SingleContainer; ServicesAffected = []; EstimatedRecoveryMs = 5000L }
                RecommendedActions = [expectedAction]
            }
            let action = Decide.decide orientation initialState
            Expect.equal action expectedAction "Should return the single recommendation"

        testCase "decide prioritizes EmergencyStop over other actions" <| fun _ ->
            let orientation = {
                Pattern = ContainerFailure
                RootCause = Some "Critical failure"
                Impact = { Scope = System; ServicesAffected = ["app"]; EstimatedRecoveryMs = 60000L }
                RecommendedActions = [
                    RestartContainer "test"
                    EmergencyStop ("test", 5)
                    AlertHuman ("Alert", Warning)
                ]
            }
            let action = Decide.decide orientation initialState
            match action with
            | EmergencyStop _ -> ()
            | _ -> failtest "Should prioritize EmergencyStop"
    ]

[<Tests>]
let stateTests =
    testList "OODA State Management" [
        testCase "initialState has zero loop count" <| fun _ ->
            Expect.equal initialState.LoopCount 0L "Initial loop count should be 0"

        testCase "initialState is healthy" <| fun _ ->
            Expect.isTrue initialState.IsHealthy "Initial state should be healthy"

        testCase "initialState has no observations" <| fun _ ->
            Expect.isNone initialState.LastObservation "Initial state should have no observations"

        testCase "getMetrics returns correct loop count" <| fun _ ->
            let state = { initialState with LoopCount = 42L }
            let metrics = getMetrics state
            Expect.equal metrics.LoopCount 42L "Metrics should reflect loop count"
    ]

[<Tests>]
let allTests =
    testList "OodaController" [
        observeTests
        orientTests
        decideTests
        stateTests
    ]
