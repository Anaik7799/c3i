namespace Cepaf.Tests

open Expecto
open Cepaf

module ProgramTests =
    [<Tests>]
    let tests =
        testList "TopologicalSort" [
            testCase "Sorts simple dependency" <| fun _ ->
                let nodes = [
                    { Operations.Node.Name = "app"; Operations.Node.Dependencies = ["db"] }
                    { Operations.Node.Name = "db"; Operations.Node.Dependencies = [] }
                ]
                let res = Operations.topoSort nodes
                match res with
                | Ok sorted -> 
                    let names = sorted |> List.map (fun n -> n.Name)
                    Expect.equal names ["db"; "app"] "db must come before app"
                | Error e -> failwithf "Sort failed: %A" e

            testCase "Detects cycles" <| fun _ ->
                let nodes = [
                    { Operations.Node.Name = "a"; Operations.Node.Dependencies = ["b"] }
                    { Operations.Node.Name = "b"; Operations.Node.Dependencies = ["a"] }
                ]
                let res = Operations.topoSort nodes
                match res with
                | Error (DependencyCycleDetected _) -> ()
                | _ -> failwith "Failed to detect cycle"
        ]

    [<EntryPoint>]
    let main args =
        runTestsWithCLIArgs [] args (testList "All Tests" [
            tests
            RopTests.tests
            OodaTests.tests
            OodaControllerTests.allTests
            ConstraintsTests.allTests
            PhicsTests.allTests
            CyberneticAgentsTests.allTests
            Cepaf.Tests.Safety.LethalMutationGateTests.tests
            Cepaf.Tests.BuilderTests.tests
            Cepaf.Tests.OrchestratorTests.tests
            Cepaf.Tests.CockpitTUITests.allCockpitTests
            // TEMPORARILY EXCLUDED: Module refactoring needed
            // Cepaf.Tests.CockpitUIComponentTests.allUIComponentTests
            // Cepaf.Tests.ComprehensiveTestFramework.allComprehensiveTests
            Cepaf.Tests.FormalVerificationTests.allFormalVerificationTests
            // TEMPORARILY EXCLUDED: PrajnaTests - module refactoring needed
            // Unit Tests (L1) - Zenoh FFI Bridge
            // STAMP: SC-ZENOH-FFI-001 to SC-ZENOH-FFI-025
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.availabilityTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.keyExprTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.keyExprMatchTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.nullSafetyTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.disposableTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.backoffTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.simulatedBusTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.tripleWriteTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.safeSessionTests
            // Metrics & Formal Invariant Verification
            // STAMP: SC-ZENOH-FFI-040, SC-ZENOH-FFI-050, INV-1 to INV-7
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.metricsTests
            Cepaf.Tests.Unit.Core.ZenohFfiBridgeTests.verifyTests
            // Unit Tests (L1) - Native Lifecycle (SafeSession, SafePublisher, SafeSubscriber)
            // STAMP: SC-NAT-001 to SC-NAT-004, SC-SESS-005, SC-ZENOH-FFI-002
            Cepaf.Tests.Unit.Core.ZenohNativeLifecycleTests.sessionLifecycleTests
            Cepaf.Tests.Unit.Core.ZenohNativeLifecycleTests.publisherLifecycleTests
            Cepaf.Tests.Unit.Core.ZenohNativeLifecycleTests.subscriberLifecycleTests
            Cepaf.Tests.Unit.Core.ZenohNativeLifecycleTests.simulatedPubSubTests
            Cepaf.Tests.Unit.Core.ZenohNativeLifecycleTests.typeUtilityTests
            Cepaf.Tests.Unit.Core.ZenohNativeLifecycleTests.concurrencyTests
            // Performance Tests (L4) - FFI Performance Benchmarks
            // STAMP: SC-ZTEST-003 (publish latency < 10ms)
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.ffiAvailabilityPerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.keyExprValidationPerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.nullHandlePerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.simulatedPublishPerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.tripleWritePerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.backoffPerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.sessionOpenClosePerf
            Cepaf.Tests.Unit.Core.ZenohFfiPerformanceTests.memoryTests
            // Unit Tests (L1)
            Cepaf.Tests.Unit.Observability.HLCTests.hlcTests
            // Cepaf.Tests.Unit.Cockpit.ThemeSystemTests.themeSystemTests
            // Biomorphic UI Component Tests (SC-HMI-001..080, SC-PRAJNA-001..007)
            Cepaf.Tests.Unit.Cockpit.BiomorphicUIComponentTests.allBiomorphicTests
            // Mesh Tests (L1) - SIL-6 Boot Infrastructure
            // STAMP: SC-BOOT-008 (DAG acyclic), SC-BOOT-014 (FSM states), SC-BOOT-005 (CPM), SC-OPT-002 (Hysteresis)
            Cepaf.Tests.Unit.Mesh.DAGTests.allTests
            Cepaf.Tests.Unit.Mesh.FSMTests.allTests
            Cepaf.Tests.Unit.Mesh.CPMTests.allTests
            Cepaf.Tests.Unit.Mesh.HysteresisTests.allTests
            // Mathematical System Monitor Tests (SC-AI-003, SC-PROM-001)
            Cepaf.Tests.Unit.Mesh.MathematicalSystemMonitorTests.tests
            // BuildHistory: SQLite persistent build timing & EMA tests (SC-IGNITE-001, SC-HOLON-009)
            Cepaf.Tests.Unit.Mesh.BuildHistoryTests.tests
            // Module Tests (L2)
            Cepaf.Tests.Module.ZenohChannelTests.zenohChannelTests
            // Integration Tests (L3)
            Cepaf.Tests.Integration.ZenohElixirIntegrationTests.zenohElixirIntegrationTests
            // Performance Tests (L4)
            Cepaf.Tests.Performance.ZenohPerformanceTests.zenohPerformanceTests
            // Core F# Capability Tests (SC-FSH-*, TDG-FSH-*, AOR-FSH-*)
            Cepaf.Tests.Core.FSharpCapabilityTests.unitsOfMeasureTests
            Cepaf.Tests.Core.FSharpCapabilityTests.activePatternsTests
            Cepaf.Tests.Core.FSharpCapabilityTests.compositionTests
            Cepaf.Tests.Core.FSharpCapabilityTests.integrationTests
            // TEMPORARILY EXCLUDED: Fractal module refactoring needed
            // Cepaf.Tests.FractalRuntimeTestPlan.fractalRuntimeTests
            // BDD Tests (Level 5: Gherkin-style SpecFlow)
            // STAMP: SC-COV-004, SC-TEST-EVO-003, SC-TEST-EVO-005
            Cepaf.Tests.BDD.TestEvolutionSteps.testEvolutionBddTests
            // Planning ↔ Chaya Sync Tests (SC-SYNC-PLAN-001 to SC-SYNC-PLAN-020)
            Cepaf.Tests.Unit.Planning.PlanningSyncTests.allPlanningSyncTests
            // TestAgent + TestTools MCP integration tests (SC-MCP-TEST-001 to SC-MCP-TEST-004)
            Cepaf.Tests.Unit.Testing.TestAgentTests.tests
            Cepaf.Tests.Unit.Testing.TestToolsTests.tests
            // RegressionRunner async + CancellationToken tests (SC-MCP-TEST-002)
            Cepaf.Tests.Unit.Testing.RegressionRunnerAsyncTests.tests
            // TestTools logs + buffer tests (Phase 4: SC-ZTEST-003, SC-ZTEST-008)
            Cepaf.Tests.Unit.Testing.TestToolsLogsTests.tests
            // PrometheusGate proof token + DAG tests (Phase 5: SC-PROM-001, SC-PROM-004)
            Cepaf.Tests.Unit.Testing.PrometheusGateTests.tests
            // OTel Integration Tests (SC-OBS-071, SC-LOG-001, SC-OTEL-MATH-009)
            Cepaf.Tests.Unit.Observability.OTELIntegrationTests.otelIntegrationTests
            // 7-Level Fractal Verification Tests (SC-VER-001 to SC-VER-080)
            // STAMP: SC-VER-*, AOR-VER-*, FMEA for all 7 levels
            Cepaf.Tests.Verification.ExpectoTests.verificationTests
            // Git Intelligence Tests (SC-CHG-001, SC-SYNC-DOC-009)
            Cepaf.Tests.Unit.GitIntelligence.TypesTests.commitTypeTests
            Cepaf.Tests.Unit.GitIntelligence.TypesTests.icpScopeTests
            Cepaf.Tests.Unit.GitIntelligence.TypesTests.commitStyleTests
            Cepaf.Tests.Unit.GitIntelligence.ParserTests.classifyStyleTests
            Cepaf.Tests.Unit.GitIntelligence.ParserTests.parseIcpSubjectTests
            Cepaf.Tests.Unit.GitIntelligence.ParserTests.validateTests
            Cepaf.Tests.Unit.GitIntelligence.ParserTests.generateMessageTests
            Cepaf.Tests.Unit.GitIntelligence.ParserTests.mapHistoricalScopeTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.shannonEntropyTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.maxEntropyTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.styleDistributionTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.scopeComplianceTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.healthScoreTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.fullAnalysisTests
            Cepaf.Tests.Unit.GitIntelligence.AnalysisTests.jsonOutputTests
            Cepaf.Tests.Unit.GitIntelligence.PropertyTests.entropyPropertyTests
            Cepaf.Tests.Unit.GitIntelligence.PropertyTests.typeRoundtripPropertyTests
            Cepaf.Tests.Unit.GitIntelligence.PropertyTests.validationPropertyTests
            // Biomorphic Subsystem Tests (SC-ORCH-001, SC-SIL6-006, SC-BIO-EXT-001)
            Cepaf.Tests.Unit.GitIntelligence.ImmuneTests.immuneTests
            Cepaf.Tests.Unit.GitIntelligence.NeuralTests.neuralTests
            Cepaf.Tests.Unit.GitIntelligence.HomeostaticTests.homeostaticTests
            Cepaf.Tests.Unit.GitIntelligence.RegenerativeTests.regenerativeTests
            Cepaf.Tests.Unit.GitIntelligence.SymbioticTests.symbioticTests
            Cepaf.Tests.Unit.GitIntelligence.TrendTests.trendTests
            Cepaf.Tests.Unit.GitIntelligence.OrchestratorTests.orchestratorTests
            Cepaf.Tests.Unit.GitIntelligence.BiomorphicPropertyTests.propertyTests
            // L3 Holon State Tests (SC-UTLTS-001, AOR-HOLON-001, AOR-HOLON-019)
            Cepaf.Tests.Unit.GitIntelligence.StoreTests.storeTests
            Cepaf.Tests.Unit.GitIntelligence.StoreTests.historyTests
            // L5 Advanced Tests (SC-BIO-EXT-009, SC-OODA-001)
            Cepaf.Tests.Unit.GitIntelligence.AdvancedTrendTests.trendTests
            Cepaf.Tests.Unit.GitIntelligence.AdvancedHomeostaticTests.tests
            // L8 Safety Tests (SC-SAFETY-001, SC-PRIME-001/002, SC-SAFETY-009 to SC-SAFETY-015)
            Cepaf.Tests.Unit.GitIntelligence.SafetyTests.tests
            // Mesh Module Tests (W20 Sprint — ConfigBridge, CLI Envelope, Health, CRM Audit)
            // STAMP: SC-SYNC-001, SC-HEALTH-001, SC-ZENOH-007, SC-AUDIT-001
            Cepaf.Tests.Unit.Mesh.ConfigBridgeTests.tests
            Cepaf.Tests.Unit.Mesh.CliEnvelopeTests.tests
            Cepaf.Tests.Unit.Mesh.CliHealthScoreTests.tests
            Cepaf.Tests.Unit.Mesh.CommandVerifierTests.tests
            Cepaf.Tests.Unit.Mesh.CrmAuditLogTests.tests
            // Cockpit TUI/Dashboard Tests (W20 Sprint — Health Bars, Sparklines, Evolution, Math, DAP)
            // STAMP: SC-HMI-010, SC-HMI-011, SC-COCKPIT-002, SC-EFFECT-001
            Cepaf.Tests.Unit.Cockpit.TuiDashboardTests.allTuiDashboardTests
            Cepaf.Tests.Unit.Cockpit.HealthBarsTests.allHealthBarsTests
            Cepaf.Tests.Unit.Cockpit.SparklineTests.allSparklineTests
            Cepaf.Tests.Unit.Cockpit.EvolutionVectorViewTests.allEvolutionVectorViewTests
            Cepaf.Tests.Unit.Cockpit.MathIntegrityPaneTests.allMathIntegrityPaneTests
            Cepaf.Tests.Unit.Cockpit.HomeostasisControlsTests.allHomeostasisControlsTests
            Cepaf.Tests.Unit.Cockpit.BiomorphicMatrixTests.allBiomorphicMatrixTests
            Cepaf.Tests.Unit.Cockpit.GraphViewTests.allGraphViewTests
            Cepaf.Tests.Unit.Cockpit.FSharpDAPTests.allFSharpDAPTests
            Cepaf.Tests.Unit.Cockpit.BicameralDashboardTests.allBicameralDashboardTests
            // MCP Server Dispatch Tests (W20 Sprint — 18-tool routing hub)
            // STAMP: SC-MCP-001, SC-MCP-002, SC-GUARD-001, SC-SESS-001
            Cepaf.Tests.Unit.Mcp.ServerDispatchTests.tests
            // Swarm Verification Tools Tests (7 actions × 16 containers × 8 layers)
            // STAMP: SC-SWARM-VERIFY-001 to SC-SWARM-VERIFY-064, SC-OODA-001 to SC-OODA-009
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.toolDefinitionTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.stateTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.dispatchTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.oodaTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.observabilityTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.controlTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.agentProbeTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.fractalTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.injectTraceTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.fullTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.genomeTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.coverageMatrixTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.fractalCompletenessTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.safetyTests
            Cepaf.Tests.Unit.Tools.SwarmVerificationToolsTests.integrationTests
        ])
