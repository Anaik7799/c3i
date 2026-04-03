/// Cepaf.Integration Test Runner
/// Entry point for all integration tests
module Cepaf.Integration.Program

open Expecto

[<EntryPoint>]
let main argv =
    // Collect all integration test lists
    let allTests = testList "Cepaf.Integration.Tests" [
        // Elixir Bridge Tests (F#↔Elixir HTTP)
        ElixirBridgeTests.healthEndpointTests
        ElixirBridgeTests.metricsEndpointTests
        ElixirBridgeTests.guardianEndpointTests
        ElixirBridgeTests.sentinelEndpointTests
        ElixirBridgeTests.founderEndpointTests
        ElixirBridgeTests.registerEndpointTests
        ElixirBridgeTests.constitutionalEndpointTests
        ElixirBridgeTests.prometheusEndpointTests
        ElixirBridgeTests.errorHandlingTests
        ElixirBridgeTests.authenticationTests
        ElixirBridgeTests.circuitBreakerTests

        // Zenoh Mesh Tests (Pub/Sub)
        ZenohMeshTests.topicPatternTests
        ZenohMeshTests.messageTypeTests
        ZenohMeshTests.fifoQueueTests
        ZenohMeshTests.connectionStateTests
        ZenohMeshTests.subscriptionTests
        ZenohMeshTests.latencyBudgetTests
        ZenohMeshTests.quorumVotingTests
        ZenohMeshTests.meshHealthTests

        // Guardian Flow Tests (Approval Workflow)
        GuardianFlowTests.proposalValidationTests
        GuardianFlowTests.stateTransitionTests
        GuardianFlowTests.votingMechanismTests
        GuardianFlowTests.constitutionalCheckTests
        GuardianFlowTests.founderDirectiveTests
        GuardianFlowTests.auditTrailTests
        GuardianFlowTests.timeoutTests
        GuardianFlowTests.emergencyOverrideTests

        // Sentinel Sync Tests (Threat Detection)
        SentinelSyncTests.rpnTests
        SentinelSyncTests.threatStateMachineTests
        SentinelSyncTests.patternHunterTests
        SentinelSyncTests.symbioticDefenseTests
        SentinelSyncTests.sentinelHealthTests
        SentinelSyncTests.threatTimelineTests
        SentinelSyncTests.correlationTests

        // Cross-Interface Consistency Tests (TUI/GUI/WebUI)
        CrossInterfaceTests.healthScoreConsistencyTests
        CrossInterfaceTests.alarmListConsistencyTests
        CrossInterfaceTests.proposalStatusConsistencyTests
        CrossInterfaceTests.threatRPNConsistencyTests
        CrossInterfaceTests.connectionStatusConsistencyTests
        CrossInterfaceTests.metricTrendConsistencyTests
        CrossInterfaceTests.dataStalenessTests
        CrossInterfaceTests.themeConsistencyTests
        CrossInterfaceTests.navigationConsistencyTests
        CrossInterfaceTests.fullVerificationTests
    ]

    // Configure Expecto
    let config =
        { defaultConfig with
            verbosity = Logging.LogLevel.Verbose
            parallel = true
            parallelWorkers = 4
            stress = None
            stressTimeout = System.TimeSpan.FromMinutes(5.0)
            stressMemoryLimit = 100.0
            printer = Expecto.Impl.TestPrinters.summaryPrinter config.printer }

    // Run tests
    runTestsWithCLIArgs config argv allTests
