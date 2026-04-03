/// Cepaf.Cockpit Test Runner
/// Entry point for all Cockpit unit and property tests
module Cepaf.Cockpit.Tests.Program

open Expecto

[<EntryPoint>]
let main argv =
    printfn "============================================================"
    printfn "Cepaf.Cockpit Comprehensive Test Suite"
    printfn "============================================================"
    printfn "Version: 21.2.1-SIL6"
    printfn "Coverage: Unit + Property + Integration"
    printfn ""

    // Configure test runner
    let config =
        { defaultConfig with
            verbosity = Logging.LogLevel.Info
            runInParallel = true
            parallelWorkers = 4 }

    // Collect all test lists
    let allTests =
        testList "Cepaf.Cockpit" [
            // Unit Tests
            SmartMetricTests.metricValueTests
            SmartMetricTests.trendDetectionTests
            SmartMetricTests.healthScoreTests
            SmartMetricTests.sparklineTests
            SmartMetricTests.movingAverageTests

            SignalArrowsTests.filterTests
            SignalArrowsTests.debounceTests
            SignalArrowsTests.throttleTests
            SignalArrowsTests.compositionTests
            SignalArrowsTests.alarmDetectionTests
            SignalArrowsTests.rateOfChangeTests

            DarkCockpitUITests.ansiColorTests
            DarkCockpitUITests.boxDrawingTests
            DarkCockpitUITests.progressBarTests
            DarkCockpitUITests.gaugeTests
            DarkCockpitUITests.spiderChartTests
            DarkCockpitUITests.statusLineTests
            DarkCockpitUITests.alarmDisplayTests
            DarkCockpitUITests.layoutTests

            ZenohIntegrationTests.topicTests
            ZenohIntegrationTests.serializationTests
            ZenohIntegrationTests.healthMessageTests
            ZenohIntegrationTests.alarmMessageTests
            ZenohIntegrationTests.guardianProposalTests
            ZenohIntegrationTests.sentinelThreatTests
            ZenohIntegrationTests.connectionStateTests
            ZenohIntegrationTests.messageQueueTests

            // Property Tests
            PropertyTests.healthScoreProperties
            PropertyTests.sparklineProperties
            PropertyTests.movingAverageProperties
            PropertyTests.messageQueueProperties
            PropertyTests.rpnProperties
            PropertyTests.layoutProperties
            PropertyTests.trendProperties
        ]

    // Run tests
    let result = runTestsWithCLIArgs [] argv allTests

    printfn ""
    printfn "============================================================"
    printfn "Test run complete"
    printfn "============================================================"

    result
