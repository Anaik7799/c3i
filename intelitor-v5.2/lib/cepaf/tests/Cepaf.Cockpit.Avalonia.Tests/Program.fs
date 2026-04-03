/// Avalonia GUI Test Runner Entry Point
module Cepaf.Cockpit.Avalonia.Tests.Program

open Expecto

[<EntryPoint>]
let main argv =
    // Collect all test lists
    let allTests = testList "Cepaf.Cockpit.Avalonia.Tests" [
        // Domain Tests
        DomainTests.modelStateTests
        DomainTests.messageTests
        DomainTests.updateTests
        DomainTests.pageRoutingTests
        DomainTests.alarmModelTests
        DomainTests.threatModelTests
        DomainTests.proposalModelTests

        // Component Tests
        ComponentTests.navigationRailTests
        ComponentTests.healthIndicatorTests
        ComponentTests.metricsCardTests
        ComponentTests.oodaStatusTests
        ComponentTests.fitnessGaugeTests
        ComponentTests.alertBannerTests

        // View Tests
        ViewTests.dashboardViewTests
        ViewTests.alarmsViewTests
        ViewTests.guardianViewTests
        ViewTests.sentinelViewTests
        ViewTests.testEvolutionViewTests
        ViewTests.settingsViewTests
        ViewTests.copilotViewTests
        ViewTests.viewLayoutTests

        // Theme Tests
        ThemeTests.darkCockpitTests
        ThemeTests.lightCockpitTests
        ThemeTests.aerospaceTests
        ThemeTests.contrastTests
        ThemeTests.consistencyTests
        ThemeTests.themeSwitchingTests
        ThemeTests.statusColorTests

        // Service Tests
        ServiceTests.elixirClientTests
        ServiceTests.zenohSubscriberTests
        ServiceTests.guardianBridgeTests
        ServiceTests.sentinelBridgeTests
        ServiceTests.serializationTests
        ServiceTests.connectionHealthTests
        ServiceTests.cacheServiceTests

        // Headless UI Tests
        HeadlessTests.elementQueryTests
        HeadlessTests.inputSimulationTests
        HeadlessTests.renderVerificationTests
        HeadlessTests.userJourneyTests
        HeadlessTests.accessibilityTests
        HeadlessTests.performanceTests
    ]

    // Run with configuration
    let config = {
        defaultConfig with
            verbosity = Logging.Info
            parallel = true
            parallelWorkers = 4
    }

    runTestsWithCLIArgs config argv allTests
