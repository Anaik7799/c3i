namespace Cepaf.Cockpit.Cortex

open System
open Cepaf.Cockpit
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Safety

// =============================================================================
// Phase6Verification.fs - Immune System Verification Tests
// =============================================================================
// Phase: 6 (The Immune Response)
// Criticality: P1 (HIGH)
// STAMP: SC-IMMUNE-001 (Healing), SC-IMMUNE-004 (DetectPattern), SC-CHAOS-001
// =============================================================================

module Phase6Verification =

    // -------------------------------------------------------------------------
    // TEST RESULT TYPES
    // -------------------------------------------------------------------------

    type VerificationResult =
        | Pass of testName: string * duration: TimeSpan * details: string
        | Fail of testName: string * duration: TimeSpan * error: string
        | Skip of testName: string * reason: string

    type Phase6Report = {
        TotalTests: int
        Passed: int
        Failed: int
        Skipped: int
        Results: VerificationResult list
        Timestamp: DateTime
        OverallStatus: string
    }

    // -------------------------------------------------------------------------
    // MOCK EVENT BUS FOR TESTING
    // -------------------------------------------------------------------------

    let mutable private capturedEvents = []

    let private mockEventBus (event: TelemetryEvent) =
        capturedEvents <- event :: capturedEvents

    let private clearEvents () =
        capturedEvents <- []

    let private getEvents () = capturedEvents

    // -------------------------------------------------------------------------
    // TEST: HEALING REFLEX (SC-IMMUNE-001)
    // -------------------------------------------------------------------------

    /// Test 1: Verify HealingState initializes correctly
    let testHealingStateInitialization () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let config = defaultHaConfig
            let state = createHealingState config

            // Verify HA set contains expected containers
            if not (config.HaSet.Contains "indrajaal-db-prod") then
                failwith "HA set missing indrajaal-db-prod"
            if not (config.HaSet.Contains "zenoh-router") then
                failwith "HA set missing zenoh-router"

            // Verify config defaults
            if config.MaxRestartAttempts <> 3 then
                failwith (sprintf "MaxRestartAttempts expected 3, got %d" config.MaxRestartAttempts)
            if config.RestartCooldownMs <> 5000 then
                failwith (sprintf "RestartCooldownMs expected 5000, got %d" config.RestartCooldownMs)

            // Verify state initialization
            if state.RestartTrackers.Count <> 0 then
                failwith "RestartTrackers should be empty on init"
            if state.AutomationMode <> NormalOps then
                failwith "AutomationMode should be NormalOps on init"

            sw.Stop()
            Pass ("HealingState Initialization", sw.Elapsed, "All defaults verified")
        with ex ->
            sw.Stop()
            Fail ("HealingState Initialization", sw.Elapsed, ex.Message)

    /// Test 2: Verify ContainerHealthEvent discriminated union
    let testContainerHealthEvents () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let now = DateTime.UtcNow

            // Test all event variants
            let events = [
                ContainerStarted ("test-1", now)
                ContainerStopped ("test-2", now, 0)
                ContainerDied ("test-3", now, "OOMKilled")
                ContainerHealthy ("test-4", now)
                ContainerUnhealthy ("test-5", now, "TCP probe failed")
                ContainerRestarted ("test-6", now, 1)
            ]

            if events.Length <> 6 then
                failwith "Expected 6 event types"

            sw.Stop()
            Pass ("ContainerHealthEvent Types", sw.Elapsed, "All 6 event types valid")
        with ex ->
            sw.Stop()
            Fail ("ContainerHealthEvent Types", sw.Elapsed, ex.Message)

    /// Test 3: Verify RestartTracker evolution
    let testRestartTrackerEvolution () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let tracker: RestartTracker = {
                ContainerId = "test-container"
                AttemptCount = 1
                LastAttemptAt = DateTime.UtcNow
                FailureReasons = ["First failure"]
            }

            // Simulate second failure
            let tracker2 = {
                tracker with
                    AttemptCount = tracker.AttemptCount + 1
                    LastAttemptAt = DateTime.UtcNow
                    FailureReasons = "Second failure" :: tracker.FailureReasons
            }

            if tracker2.AttemptCount <> 2 then
                failwith "AttemptCount should be 2"
            if tracker2.FailureReasons.Length <> 2 then
                failwith "FailureReasons should have 2 entries"

            sw.Stop()
            Pass ("RestartTracker Evolution", sw.Elapsed, "Tracker updates correctly")
        with ex ->
            sw.Stop()
            Fail ("RestartTracker Evolution", sw.Elapsed, ex.Message)

    // -------------------------------------------------------------------------
    // TEST: DETECT PATTERN (SC-IMMUNE-004)
    // -------------------------------------------------------------------------

    /// Test 4: Verify PatternDetectionConfig defaults
    let testPatternDetectionConfig () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let config = defaultPatternConfig

            if config.SynthesisThreshold <> 3 then
                failwith (sprintf "SynthesisThreshold expected 3, got %d" config.SynthesisThreshold)
            if config.AntibodyLifetimeMinutes <> 30.0 then
                failwith (sprintf "AntibodyLifetimeMinutes expected 30.0, got %f" config.AntibodyLifetimeMinutes)
            if not config.Enabled then
                failwith "PatternDetection should be enabled by default"

            sw.Stop()
            Pass ("PatternDetection Config", sw.Elapsed, "All defaults verified")
        with ex ->
            sw.Stop()
            Fail ("PatternDetection Config", sw.Elapsed, ex.Message)

    /// Test 5: Verify FailurePattern creation
    let testFailurePatternCreation () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let pattern = createFailurePattern "TestComponent" "ConnectionTimeout" "sig-abc123"

            if pattern.SourceComponent <> "TestComponent" then
                failwith "SourceComponent mismatch"
            if pattern.FailureType <> "ConnectionTimeout" then
                failwith "FailureType mismatch"
            if pattern.OccurrenceCount <> 1 then
                failwith "Initial OccurrenceCount should be 1"
            if pattern.Signatures.Length <> 1 then
                failwith "Initial Signatures should have 1 entry"

            sw.Stop()
            Pass ("FailurePattern Creation", sw.Elapsed, "Pattern created correctly")
        with ex ->
            sw.Stop()
            Fail ("FailurePattern Creation", sw.Elapsed, ex.Message)

    /// Test 6: Verify Antibody structure
    let testAntibodyStructure () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let antibody: Antibody = {
                Id = Guid.NewGuid()
                TargetPattern = "dangerous_command"
                ExpiresAt = DateTime.UtcNow.AddMinutes(30.0)
                Reason = "Auto-generated from recurring failure"
            }

            if String.IsNullOrEmpty(antibody.TargetPattern) then
                failwith "TargetPattern should not be empty"
            if antibody.ExpiresAt <= DateTime.UtcNow then
                failwith "ExpiresAt should be in the future"

            sw.Stop()
            Pass ("Antibody Structure", sw.Elapsed, "Antibody valid")
        with ex ->
            sw.Stop()
            Fail ("Antibody Structure", sw.Elapsed, ex.Message)

    /// Test 7: Verify GuardianAgent initialization
    let testGuardianAgentInit () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            clearEvents ()
            let guardian = GuardianAgent(mockEventBus)

            // Get status should work
            let status = guardian.Status() |> Async.RunSynchronously

            if not (status.Contains "Guardian Active") then
                failwith "Guardian should be active"
            if not (status.Contains "SIL-2") then
                failwith "Guardian should report SIL-2 compliance"

            sw.Stop()
            Pass ("GuardianAgent Init", sw.Elapsed, "Guardian active and responding")
        with ex ->
            sw.Stop()
            Fail ("GuardianAgent Init", sw.Elapsed, ex.Message)

    // -------------------------------------------------------------------------
    // TEST: MARA CHAOS AGENT (SC-CHAOS-001, SC-CHAOS-002)
    // -------------------------------------------------------------------------

    /// Test 8: Verify MaraConfig safety defaults
    let testMaraConfigDefaults () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let config = Chaos.defaultMaraConfig

            // Verify disabled by default (safety)
            if config.Enabled then
                failwith "Mara should be DISABLED by default for safety"

            // Verify protected containers
            if not (config.ProtectedContainers.Contains "indrajaal-db-prod") then
                failwith "Database should be protected"
            if not (config.ProtectedContainers.Contains "zenoh-router") then
                failwith "Zenoh router should be protected"

            // Verify rate limiting
            if config.MaxEventsPerHour < 1 then
                failwith "MaxEventsPerHour should be positive"

            // Verify lease timeout (kill switch)
            if config.LeaseTimeoutSeconds < 60 then
                failwith "LeaseTimeoutSeconds should be at least 60s"

            // Verify guardian approval required
            if not config.RequireGuardianApproval then
                failwith "GuardianApproval should be required by default"

            sw.Stop()
            Pass ("MaraConfig Safety Defaults", sw.Elapsed, "All safety constraints verified")
        with ex ->
            sw.Stop()
            Fail ("MaraConfig Safety Defaults", sw.Elapsed, ex.Message)

    /// Test 9: Verify ChaosAction discriminated union
    let testChaosActionTypes () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let actions: Chaos.ChaosAction list = [
                Chaos.KillContainer "test"
                Chaos.StopContainer "test"
                Chaos.InjectLatency ("target", 100)
                Chaos.CorruptState "holon-1"
                Chaos.SimulateNetworkPartition ("nodeA", "nodeB")
                Chaos.ExhaustMemory ("container", 512)
                Chaos.FillDisk ("container", 1024)
            ]

            if actions.Length <> 7 then
                failwith "Expected 7 chaos action types"

            sw.Stop()
            Pass ("ChaosAction Types", sw.Elapsed, "All 7 chaos actions valid")
        with ex ->
            sw.Stop()
            Fail ("ChaosAction Types", sw.Elapsed, ex.Message)

    /// Test 10: Verify MaraAgent initialization (disabled)
    let testMaraAgentInit () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            clearEvents ()
            let mara = Chaos.MaraAgent(mockEventBus)

            // Get config should show disabled
            let config = mara.Config() |> Async.RunSynchronously

            if config.Enabled then
                failwith "Mara should be disabled on init"

            // Get stats should work
            let stats = mara.Stats() |> Async.RunSynchronously

            if stats.TotalStrikes <> 0 then
                failwith "TotalStrikes should be 0 on init"

            sw.Stop()
            Pass ("MaraAgent Init", sw.Elapsed, "Mara initialized safely (disabled)")
        with ex ->
            sw.Stop()
            Fail ("MaraAgent Init", sw.Elapsed, ex.Message)

    /// Test 11: Verify Mara blocks strikes when disabled
    let testMaraBlocksWhenDisabled () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            clearEvents ()
            let mara = Chaos.MaraAgent(mockEventBus)

            // Attempt a strike while disabled
            let result = mara.Attack(Chaos.KillContainer "test-container") |> Async.RunSynchronously

            // Should fail with disabled message
            if result.Success then
                failwith "Strike should fail when Mara is disabled"

            match result.ErrorMessage with
            | Some msg when msg.Contains "DISABLED" -> ()
            | _ -> failwith "Error should mention DISABLED state"

            sw.Stop()
            Pass ("Mara Blocks When Disabled", sw.Elapsed, "Safety constraint enforced")
        with ex ->
            sw.Stop()
            Fail ("Mara Blocks When Disabled", sw.Elapsed, ex.Message)

    /// Test 12: Verify Mara protects critical containers
    let testMaraProtectsContainers () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            clearEvents ()
            let mara = Chaos.MaraAgent(mockEventBus)

            // Enable Mara
            mara.Enable()

            // Attempt to kill protected container
            let result = mara.Attack(Chaos.KillContainer "indrajaal-db-prod") |> Async.RunSynchronously

            // Should fail with protected message
            if result.Success then
                failwith "Strike on protected container should fail"

            match result.ErrorMessage with
            | Some msg when msg.Contains "PROTECTED" -> ()
            | _ -> failwith "Error should mention PROTECTED container"

            // Disable Mara after test
            mara.Disable()

            sw.Stop()
            Pass ("Mara Protects Containers", sw.Elapsed, "Protected container list enforced")
        with ex ->
            sw.Stop()
            Fail ("Mara Protects Containers", sw.Elapsed, ex.Message)

    // -------------------------------------------------------------------------
    // TEST: INTEGRATION (All Components)
    // -------------------------------------------------------------------------

    /// Test 13: Verify TelemetryEvent integration
    let testTelemetryEventIntegration () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            let events: TelemetryEvent list = [
                MetricLogged ("cpu", 45.0)
                AnomalyDetected ("high latency", "WARNING")
                ContainerHealth (ContainerDied ("test", DateTime.UtcNow, "crash"))
                HealingTriggered ("test", "restart")
                AntibodySynthesized ("abc123", "dangerous_pattern")
            ]

            if events.Length <> 5 then
                failwith "Expected 5 telemetry event types"

            sw.Stop()
            Pass ("TelemetryEvent Integration", sw.Elapsed, "Event bus types integrated")
        with ex ->
            sw.Stop()
            Fail ("TelemetryEvent Integration", sw.Elapsed, ex.Message)

    /// Test 14: Verify Safety envelope validation
    let testSafetyEnvelopeValidation () =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        try
            clearEvents ()
            let guardian = GuardianAgent(mockEventBus)

            // Create a safe proposal
            let safeProposal: Proposal = {
                Id = Guid.NewGuid().ToString()
                Action = ScaleUp 10
                Source = "test"
                Timestamp = DateTime.UtcNow
            }

            let result = guardian.Validate(safeProposal) |> Async.RunSynchronously

            match result with
            | Approved _ -> ()
            | Vetoed (reason, _) -> failwith (sprintf "Safe proposal should be approved: %A" reason)

            // Create an unsafe proposal (exceeds limits)
            let unsafeProposal: Proposal = {
                Id = Guid.NewGuid().ToString()
                Action = ScaleUp 1000  // Way over limit
                Source = "test"
                Timestamp = DateTime.UtcNow
            }

            let result2 = guardian.Validate(unsafeProposal) |> Async.RunSynchronously

            match result2 with
            | Vetoed _ -> ()
            | Approved _ -> failwith "Unsafe proposal should be vetoed"

            sw.Stop()
            Pass ("Safety Envelope Validation", sw.Elapsed, "Guardian correctly validates proposals")
        with ex ->
            sw.Stop()
            Fail ("Safety Envelope Validation", sw.Elapsed, ex.Message)

    // -------------------------------------------------------------------------
    // RUN ALL TESTS
    // -------------------------------------------------------------------------

    let runAll () : Phase6Report =
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════╗"
        printfn "║  PHASE 6: IMMUNE RESPONSE VERIFICATION                       ║"
        printfn "║  SC-IMMUNE-001, SC-IMMUNE-004, SC-CHAOS-001, SC-CHAOS-002    ║"
        printfn "╚══════════════════════════════════════════════════════════════╝"
        printfn ""

        let tests = [
            // Healing Reflex tests (SC-IMMUNE-001)
            testHealingStateInitialization
            testContainerHealthEvents
            testRestartTrackerEvolution

            // DetectPattern tests (SC-IMMUNE-004)
            testPatternDetectionConfig
            testFailurePatternCreation
            testAntibodyStructure
            testGuardianAgentInit

            // Mara Chaos Agent tests (SC-CHAOS-001, SC-CHAOS-002)
            testMaraConfigDefaults
            testChaosActionTypes
            testMaraAgentInit
            testMaraBlocksWhenDisabled
            testMaraProtectsContainers

            // Integration tests
            testTelemetryEventIntegration
            testSafetyEnvelopeValidation
        ]

        let results = tests |> List.map (fun t -> t())

        let passed = results |> List.filter (function Pass _ -> true | _ -> false) |> List.length
        let failed = results |> List.filter (function Fail _ -> true | _ -> false) |> List.length
        let skipped = results |> List.filter (function Skip _ -> true | _ -> false) |> List.length

        printfn ""
        printfn "─────────────────────────────────────────────────────────────────"
        results |> List.iter (function
            | Pass (name, duration, details) ->
                printfn "✅ PASS: %s (%dms) - %s" name (int duration.TotalMilliseconds) details
            | Fail (name, duration, error) ->
                printfn "❌ FAIL: %s (%dms) - %s" name (int duration.TotalMilliseconds) error
            | Skip (name, reason) ->
                printfn "⏭️ SKIP: %s - %s" name reason
        )
        printfn "─────────────────────────────────────────────────────────────────"
        printfn ""

        let overallStatus =
            if failed = 0 then "PASSED ✅"
            else sprintf "FAILED ❌ (%d failures)" failed

        printfn "╔══════════════════════════════════════════════════════════════╗"
        printfn "║  SUMMARY: %d passed, %d failed, %d skipped" passed failed skipped
        printfn "║  STATUS:  %s" overallStatus
        printfn "╚══════════════════════════════════════════════════════════════╝"
        printfn ""

        {
            TotalTests = tests.Length
            Passed = passed
            Failed = failed
            Skipped = skipped
            Results = results
            Timestamp = DateTime.UtcNow
            OverallStatus = overallStatus
        }
