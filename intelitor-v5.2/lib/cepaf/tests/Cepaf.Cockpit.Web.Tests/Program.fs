/// WebUI Test Runner Entry Point
module Cepaf.Cockpit.Web.Tests.Program

open Expecto

[<EntryPoint>]
let main argv =
    // Collect all test lists
    let allTests = testList "Cepaf.Cockpit.Web.Tests" [
        // Component Tests
        ComponentTests.healthGaugeTests
        ComponentTests.alarmCardTests
        ComponentTests.proposalCardTests
        ComponentTests.threatCardTests
        ComponentTests.deviceCardTests
        ComponentTests.badgeTests

        // Page Tests
        PageTests.dashboardPageTests
        PageTests.alarmsPageTests
        PageTests.guardianPageTests
        PageTests.sentinelPageTests
        PageTests.navigationTests
        PageTests.settingsPageTests

        // Service Tests
        ServiceTests.httpClientTests
        ServiceTests.healthApiTests
        ServiceTests.guardianApiTests
        ServiceTests.sentinelApiTests
        ServiceTests.zenohBridgeTests
        ServiceTests.signalRHubTests
        ServiceTests.retryPolicyTests
        ServiceTests.cacheServiceTests

        // E2E Tests
        E2ETests.dashboardJourneyTests
        E2ETests.alarmJourneyTests
        E2ETests.guardianJourneyTests
        E2ETests.sentinelJourneyTests
        E2ETests.deviceJourneyTests
        E2ETests.consistencyTests
        E2ETests.performanceTests
        E2ETests.scenarioCountTests
    ]

    // Run with configuration
    let config = {
        defaultConfig with
            verbosity = Logging.LogLevel.Info
            runInParallel = true
            parallelWorkers = 4
    }

    runTestsWithCLIArgs [] argv allTests
