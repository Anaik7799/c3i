namespace Cepaf.Planning

/// SIL-6 Startup System Optimization Plan
/// Version: 21.2.3-SIL6
/// Timestamp: 2026-01-18T14:30:00Z
/// STAMP: SC-OPT-001 to SC-OPT-010, SC-CONSOL-001 to SC-CONSOL-010
/// AOR: AOR-OPT-001 to AOR-OPT-010, AOR-CONSOL-001 to AOR-CONSOL-010
module StartupOptimizationPlan =

    open System

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 1: PLAN METADATA
    // ═══════════════════════════════════════════════════════════════════

    [<Literal>]
    let Version = "21.2.3-SIL6"

    [<Literal>]
    let Timestamp = "2026-01-18T14:30:00Z"

    [<Literal>]
    let Author = "Claude Opus 4.5"

    type PlanMode =
        | Jidoka      // 自働化 - Stop on defect
        | TPS         // Toyota Production System
        | FastOODA    // 30s cycles

    let activeModes = [ Jidoka; TPS; FastOODA ]

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 2: EXPECTED IMPACT SUMMARY
    // ═══════════════════════════════════════════════════════════════════

    type ImpactMetric = {
        Name: string
        Current: string
        Target: string
        Improvement: string
    }

    let expectedImpact = [
        { Name = "Boot Time"; Current = "60-120s"; Target = "29-39s"; Improvement = "50-70% faster" }
        { Name = "Smoke Tests"; Current = "44"; Target = "100+"; Improvement = "127% more" }
        { Name = "Config Duplicates"; Current = "~200"; Target = "0"; Improvement = "100% reduction" }
        { Name = "Code Lines (Orchestrators)"; Current = "4,030"; Target = "2,500"; Improvement = "38% reduction" }
        { Name = "NetworkConfig Definitions"; Current = "3"; Target = "1"; Improvement = "67% reduction" }
        { Name = "ANSI Color Sources"; Current = "6+"; Target = "1"; Improvement = "83% reduction" }
        { Name = "Containers (Swarm)"; Current = "4"; Target = "14"; Improvement = "250% more" }
        { Name = "Zenoh Quorum"; Current = "1/1"; Target = "2oo3"; Improvement = "Fault tolerant" }
        { Name = "BDD Scenarios"; Current = "138"; Target = "178+"; Improvement = "29% more" }
        { Name = "Test Categories"; Current = "4"; Target = "11"; Improvement = "175% more" }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 3: 7-LEVEL RCA ANALYSIS
    // ═══════════════════════════════════════════════════════════════════

    type RCALevel =
        | L1_Symptom
        | L2_Local
        | L3_Logic
        | L4_Module
        | L5_System
        | L6_Design
        | L7_Architecture

    type RCAFinding = {
        Level: RCALevel
        Finding: string
        Impact: string
    }

    /// Startup Time Optimization RCA
    let startupTimeRCA = [
        { Level = L1_Symptom; Finding = "Boot time 60-120s (target <60s)"; Impact = "User experience, deployment speed" }
        { Level = L2_Local; Finding = "Wave 4 (App) takes 20s, DB health 50s worst case"; Impact = "Sequential blocking" }
        { Level = L3_Logic; Finding = "Migration gate between W2 and W3 adds 5-10s"; Impact = "Unnecessary delay" }
        { Level = L4_Module; Finding = "500ms poll × 30 retries = 15s per container"; Impact = "Slow health checks" }
        { Level = L5_System; Finding = "appStartPeriod = 900s (15 min!) should be 60s"; Impact = "Over-conservative timeouts" }
        { Level = L6_Design; Finding = "Two boot models (5-stage vs 7-gate) cause confusion"; Impact = "Maintenance burden" }
        { Level = L7_Architecture; Finding = "Elixir compilation at boot (30-60s) - move to image"; Impact = "CRITICAL bottleneck" }
    ]

    /// Configuration Centralization RCA
    let configCentralizationRCA = [
        { Level = L1_Symptom; Finding = "~200 duplicate config references across 40+ files"; Impact = "Maintenance nightmare" }
        { Level = L2_Local; Finding = "Port 4000 in 29 files, Port 5433 in 22 files"; Impact = "Change propagation" }
        { Level = L3_Logic; Finding = "No cross-runtime bridge between F# and Elixir"; Impact = "Config drift" }
        { Level = L4_Module; Finding = "ANSI colors defined in 6+ locations"; Impact = "Inconsistent styling" }
        { Level = L5_System; Finding = "16 compose files with hardcoded values"; Impact = "Manual maintenance" }
        { Level = L6_Design; Finding = "ConfigValidation exists but not called at startup"; Impact = "Runtime failures" }
        { Level = L7_Architecture; Finding = "Two authoritative sources (MeshConfig.fs, config.exs)"; Impact = "No single truth" }
    ]

    /// Orchestrator Consolidation RCA
    let orchestratorConsolidationRCA = [
        { Level = L1_Symptom; Finding = "3 overlapping scripts: 4,030 lines, ~500 redundant"; Impact = "Code bloat" }
        { Level = L2_Local; Finding = "Telemetry 100×2, Colors 80×3, Health 120×2"; Impact = "Duplication" }
        { Level = L3_Logic; Finding = "Different boot models (S0-S4, G0-G7, Phases)"; Impact = "Confusion" }
        { Level = L4_Module; Finding = "Inconsistent type naming (BootStage vs BootGate)"; Impact = "Type mismatch" }
        { Level = L5_System; Finding = "No shared core library - forced duplication"; Impact = "Isolation" }
        { Level = L6_Design; Finding = "Missing modular architecture (Mesh.Core.fs etc)"; Impact = "No reuse" }
        { Level = L7_Architecture; Finding = "Script vs module tension - need hybrid"; Impact = "Structural issue" }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 4: OPTIMIZATION PLAN
    // ═══════════════════════════════════════════════════════════════════

    type OptimizationTier =
        | QuickWins     // 15-30s reduction
        | MediumTerm    // 30-45s reduction
        | LongTerm      // 30-60s reduction

    type Optimization = {
        Tier: OptimizationTier
        Name: string
        TimeSavings: string
        Priority: string
    }

    let optimizations = [
        // Quick Wins
        { Tier = QuickWins; Name = "Tune DB health timeout: 50s → 30s"; TimeSavings = "0-20s"; Priority = "P0" }
        { Tier = QuickWins; Name = "Move migration gate to W4"; TimeSavings = "5-10s"; Priority = "P0" }
        { Tier = QuickWins; Name = "2oo3 early exit when quorum achieved"; TimeSavings = "3-5s"; Priority = "P0" }
        { Tier = QuickWins; Name = "App health early return on 200"; TimeSavings = "2-5s"; Priority = "P0" }
        { Tier = QuickWins; Name = "Reduce poll intervals (parallel)"; TimeSavings = "5-10s"; Priority = "P1" }

        // Medium-Term
        { Tier = MediumTerm; Name = "Parallel W2+W3 (remove dependency)"; TimeSavings = "8s"; Priority = "P0" }
        { Tier = MediumTerm; Name = "Exponential backoff health checks"; TimeSavings = "5-10s"; Priority = "P1" }
        { Tier = MediumTerm; Name = "Pre-warm DNS/network"; TimeSavings = "2-3s"; Priority = "P2" }
        { Tier = MediumTerm; Name = "Lazy container start (on-demand)"; TimeSavings = "10-15s"; Priority = "P2" }

        // Long-Term
        { Tier = LongTerm; Name = "Pre-compiled Elixir in image"; TimeSavings = "30-60s"; Priority = "P0" }
        { Tier = LongTerm; Name = "Cached BEAM files in volume"; TimeSavings = "10-20s"; Priority = "P1" }
        { Tier = LongTerm; Name = "Container image layering"; TimeSavings = "5-10s"; Priority = "P2" }
    ]

    let bootTimeProjection = {|
        Current = "60-120s"
        AfterQuickWins = "45-90s (-25%)"
        AfterMedium = "30-60s (-50%)"
        AfterLongTerm = "29-39s (-67%)"
    |}

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 5: STAMP CONSTRAINTS
    // ═══════════════════════════════════════════════════════════════════

    type Severity = Critical | High | Medium | Low

    type StampConstraint = {
        Id: string
        Constraint: string
        Severity: Severity
        Category: string
    }

    let optimizationConstraints = [
        { Id = "SC-OPT-001"; Constraint = "Boot time MUST be < 60s"; Severity = Critical; Category = "Optimization" }
        { Id = "SC-OPT-002"; Constraint = "Health check poll MUST use exponential backoff"; Severity = High; Category = "Optimization" }
        { Id = "SC-OPT-003"; Constraint = "2oo3 quorum MUST early-exit when achieved"; Severity = High; Category = "Optimization" }
        { Id = "SC-OPT-004"; Constraint = "Migration gate MUST NOT block W2→W3"; Severity = High; Category = "Optimization" }
        { Id = "SC-OPT-005"; Constraint = "App container MUST have pre-compiled BEAM"; Severity = Critical; Category = "Optimization" }
        { Id = "SC-OPT-006"; Constraint = "Wave parallelization MUST be enabled for independent waves"; Severity = High; Category = "Optimization" }
        { Id = "SC-OPT-007"; Constraint = "Timeout configurations MUST be tuned (not over-conservative)"; Severity = Medium; Category = "Optimization" }
        { Id = "SC-OPT-008"; Constraint = "Boot metrics MUST be published to Zenoh"; Severity = Medium; Category = "Optimization" }
        { Id = "SC-OPT-009"; Constraint = "Boot bottlenecks MUST trigger 7-Level RCA"; Severity = High; Category = "Optimization" }
        { Id = "SC-OPT-010"; Constraint = "Boot time regression > 10% MUST block deployment"; Severity = Critical; Category = "Optimization" }
    ]

    let consolidationConstraints = [
        { Id = "SC-CONSOL-001"; Constraint = "NetworkConfig MUST have single definition"; Severity = Critical; Category = "Consolidation" }
        { Id = "SC-CONSOL-002"; Constraint = "All ports MUST come from MeshConfig.Ports"; Severity = Critical; Category = "Consolidation" }
        { Id = "SC-CONSOL-003"; Constraint = "All ANSI colors MUST come from ConsoleChannel.AnsiColors"; Severity = High; Category = "Consolidation" }
        { Id = "SC-CONSOL-004"; Constraint = "Compose files MUST be generated from config"; Severity = High; Category = "Consolidation" }
        { Id = "SC-CONSOL-005"; Constraint = "Config validation MUST run at boot"; Severity = Critical; Category = "Consolidation" }
        { Id = "SC-CONSOL-006"; Constraint = "ConfigBridge MUST sync F#/Elixir configs"; Severity = High; Category = "Consolidation" }
        { Id = "SC-CONSOL-007"; Constraint = "Orchestrator code MUST use Mesh.Core.fs"; Severity = High; Category = "Consolidation" }
        { Id = "SC-CONSOL-008"; Constraint = "Boot model MUST be unified (single phase enum)"; Severity = High; Category = "Consolidation" }
        { Id = "SC-CONSOL-009"; Constraint = "Health check code MUST use Mesh.Health.fs"; Severity = High; Category = "Consolidation" }
        { Id = "SC-CONSOL-010"; Constraint = "Telemetry code MUST use Mesh.Telemetry.fs"; Severity = Medium; Category = "Consolidation" }
    ]

    let allConstraints = optimizationConstraints @ consolidationConstraints

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 6: AOR RULES
    // ═══════════════════════════════════════════════════════════════════

    type AorRule = {
        Id: string
        Rule: string
        Category: string
    }

    let optimizationRules = [
        { Id = "AOR-OPT-001"; Rule = "TUNE timeouts before adding new containers"; Category = "Optimization" }
        { Id = "AOR-OPT-002"; Rule = "MEASURE boot time after every orchestrator change"; Category = "Optimization" }
        { Id = "AOR-OPT-003"; Rule = "PROFILE wave execution to find bottlenecks"; Category = "Optimization" }
        { Id = "AOR-OPT-004"; Rule = "PARALLELIZE waves that have no dependencies"; Category = "Optimization" }
        { Id = "AOR-OPT-005"; Rule = "CACHE BEAM files in Docker image build"; Category = "Optimization" }
        { Id = "AOR-OPT-006"; Rule = "EARLY-EXIT health checks on success"; Category = "Optimization" }
        { Id = "AOR-OPT-007"; Rule = "USE exponential backoff (100ms → 3200ms)"; Category = "Optimization" }
        { Id = "AOR-OPT-008"; Rule = "DOCUMENT boot time impact for new features"; Category = "Optimization" }
        { Id = "AOR-OPT-009"; Rule = "RUN 7-Level RCA on boot time regression"; Category = "Optimization" }
        { Id = "AOR-OPT-010"; Rule = "BLOCK deployment if boot > 60s"; Category = "Optimization" }
    ]

    let consolidationRules = [
        { Id = "AOR-CONSOL-001"; Rule = "REMOVE duplicate type definitions immediately"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-002"; Rule = "IMPORT from MeshConfig, never redefine"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-003"; Rule = "GENERATE compose files, never edit manually"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-004"; Rule = "VALIDATE config at startup, fail fast"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-005"; Rule = "USE Mesh.Core.fs for all orchestrator code"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-006"; Rule = "SYNC ConfigBridge after any config change"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-007"; Rule = "REFERENCE ConsoleChannel.AnsiColors for colors"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-008"; Rule = "DOCUMENT any new config parameters"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-009"; Rule = "TEST config validation in CI"; Category = "Consolidation" }
        { Id = "AOR-CONSOL-010"; Rule = "ALERT on config drift between F#/Elixir"; Category = "Consolidation" }
    ]

    let allRules = optimizationRules @ consolidationRules

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 7: IMPLEMENTATION PHASES
    // ═══════════════════════════════════════════════════════════════════

    type PhaseStatus = Pending | InProgress | Completed | Blocked

    type ImplementationPhase = {
        Number: int
        Name: string
        Day: string
        Tasks: string list
        Status: PhaseStatus
        ExpectedImpact: string
    }

    let phases = [
        { Number = 0
          Name = "Optimization Quick Wins"
          Day = "Day 0"
          Tasks = [
              "Tune DB health timeout: 50s → 30s"
              "Move migration gate to W4"
              "Enable 2oo3 early exit"
              "Reduce app health poll interval"
          ]
          Status = Completed
          ExpectedImpact = "15-30s boot time reduction" }

        { Number = 1
          Name = "Configuration Consolidation"
          Day = "Day 1"
          Tasks = [
              "Remove duplicate NetworkConfig from Specs.fs"
              "Remove duplicate NetworkConfig from StandaloneChain.fs"
              "Create centralized ANSI colors in ConsoleChannel.fs"
              "Update 6+ files to reference centralized colors"
              "Add ConfigValidation at startup"
          ]
          Status = Completed
          ExpectedImpact = "100% config duplicate elimination" }

        { Number = 2
          Name = "Orchestrator Consolidation"
          Day = "Day 2"
          Tasks = [
              "Create Mesh.Core.fs with shared types"
              "Create Mesh.Health.fs with health checks"
              "Create Mesh.Telemetry.fs with logging"
              "Unify boot model (single BootPhase enum)"
              "Single CLI entry point"
          ]
          Status = Completed
          ExpectedImpact = "38% code reduction (4,030 → 2,500 lines)" }

        { Number = 3
          Name = "Enhanced Smoke Tests"
          Day = "Day 3"
          Tasks = [
              "Add API endpoint tests (10 tests)"
              "Add database consistency tests (8 tests)"
              "Add cross-node communication tests (8 tests)"
              "Add performance baseline tests (8 tests)"
              "Add security validation tests (6 tests)"
              "Add resilience tests (8 tests)"
              "Add integration tests (8 tests)"
          ]
          Status = Completed
          ExpectedImpact = "127% more smoke tests (44 → 100+)" }

        { Number = 4
          Name = "Full Swarm Orchestrator"
          Day = "Day 4"
          Tasks = [
              "Create EnhancedSwarmOrchestrator.fsx"
              "Add all 15 containers to DAG"
              "Implement 5-stage boot with 2oo3 verification"
              "Add biomorphic health checks"
              "Integrate 7-Level RCA on failure"
          ]
          Status = Pending
          ExpectedImpact = "250% more containers (4 → 14)" }

        { Number = 5
          Name = "Enhanced Logging"
          Day = "Day 5"
          Tasks = [
              "Implement EnhancedTestResult type"
              "Add verbosity levels to output"
              "Add metrics capture for all tests"
              "Add evidence collection for failures"
          ]
          Status = Pending
          ExpectedImpact = "Linux-boot-style transparency" }

        { Number = 6
          Name = "BDD Features"
          Day = "Day 6"
          Tasks = [
              "Create 5 new feature files"
              "Add 40+ new scenarios"
              "Integrate with existing test infrastructure"
          ]
          Status = Pending
          ExpectedImpact = "29% more BDD scenarios (138 → 178+)" }

        { Number = 7
          Name = "Long-Term Optimization"
          Day = "Week 2"
          Tasks = [
              "Pre-compile Elixir in Docker image"
              "Wave parallelization"
              "ComposeGenerator implementation"
              "ConfigBridge F#↔Elixir sync"
          ]
          Status = Pending
          ExpectedImpact = "50-70% boot time reduction" }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 8: CRITICAL FILES
    // ═══════════════════════════════════════════════════════════════════

    type FileAction = AddNew | Modify | Remove

    type CriticalFile = {
        Path: string
        Action: FileAction
        Priority: string
        Description: string
    }

    let criticalFiles = [
        { Path = "lib/cepaf/src/Cepaf.Config/MeshConfig.fs"; Action = Modify; Priority = "P0"; Description = "Add Ports module, tune timeouts" }
        { Path = "lib/cepaf/src/Cepaf/Mesh/Core.fs"; Action = AddNew; Priority = "P0"; Description = "Shared types, utilities, colors" }
        { Path = "lib/cepaf/src/Cepaf/Mesh/Health.fs"; Action = AddNew; Priority = "P0"; Description = "All health checks" }
        { Path = "lib/cepaf/src/Cepaf.Podman/Domain/Specs.fs"; Action = Modify; Priority = "P0"; Description = "Remove duplicate NetworkConfig" }
        { Path = "lib/cepaf/src/Cepaf/ServiceChains/StandaloneChain.fs"; Action = Modify; Priority = "P0"; Description = "Remove duplicate NetworkConfig" }
        { Path = "lib/cepaf/scripts/ComprehensiveStartupOrchestrator.fsx"; Action = Modify; Priority = "P0"; Description = "Add 56 new smoke tests" }
        { Path = "lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx"; Action = AddNew; Priority = "P0"; Description = "15 containers orchestration" }
        { Path = "lib/cepaf/src/Cepaf/Observability/ConsoleChannel.fs"; Action = Modify; Priority = "P1"; Description = "Add centralized AnsiColors" }
        { Path = "lib/cepaf/src/Cepaf.Config/ComposeGenerator.fs"; Action = AddNew; Priority = "P1"; Description = "Generate compose files" }
        { Path = "lib/cepaf/src/Cepaf.Config/ConfigBridge.fs"; Action = AddNew; Priority = "P1"; Description = "F#↔Elixir config sync" }
        { Path = "test/features/startup/full_swarm_boot.feature"; Action = AddNew; Priority = "P1"; Description = "15 containers, 3oo4 quorum" }
        { Path = "test/features/startup/biomorphic_integration.feature"; Action = AddNew; Priority = "P1"; Description = "Sentinel, PatternHunter, SymbioticDefense" }
        { Path = "test/features/startup/crash_recovery.feature"; Action = AddNew; Priority = "P1"; Description = "App crash, DB loss, Zenoh failure" }
        { Path = "test/features/startup/security_validation.feature"; Action = AddNew; Priority = "P1"; Description = "TLS, auth, headers, secrets" }
        { Path = "test/features/startup/comprehensive_smoke_tests.feature"; Action = AddNew; Priority = "P1"; Description = "All 7 test categories" }
        { Path = "devenv.nix"; Action = Modify; Priority = "P1"; Description = "Add sa-swarm-* commands" }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 9: UNIFIED BOOT MODEL
    // ═══════════════════════════════════════════════════════════════════

    /// Unified boot phase enum (replaces S0-S4, G0-G7, Phase1-3)
    type BootPhase =
        | Preflight     // Environment validation
        | Foundation    // DB + OBS
        | Mesh          // Zenoh routers (2oo3)
        | Cognitive     // Bridge + Cortex
        | Application   // App nodes
        | Homeostasis   // Health verification
        | Swarm         // HA replicas + satellites

    let phaseOrder = [
        Preflight
        Foundation
        Mesh
        Cognitive
        Application
        Homeostasis
        Swarm
    ]

    /// Exponential backoff intervals for health checks (ms)
    let backoffIntervals = [ 100; 200; 400; 800; 1600; 3200 ]

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 10: HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// Get all STAMP constraints
    let getStampConstraints () = allConstraints

    /// Get all AOR rules
    let getAorRules () = allRules

    /// Get all phases
    let getPhases () = phases

    /// Get critical files by priority
    let getCriticalFilesByPriority (priority: string) =
        criticalFiles |> List.filter (fun f -> f.Priority = priority)

    /// Get expected boot time after phase
    let getBootTimeAfterPhase (phase: int) =
        match phase with
        | 0 -> "45-90s (-25%)"
        | 1 | 2 -> "30-60s (-50%)"
        | 7 -> "29-39s (-67%)"
        | _ -> "Varies"

    /// Print plan summary to console
    let printSummary () =
        printfn "═══════════════════════════════════════════════════════════════"
        printfn " STARTUP OPTIMIZATION PLAN v%s" Version
        printfn " Timestamp: %s" Timestamp
        printfn "═══════════════════════════════════════════════════════════════"
        printfn ""
        printfn "EXPECTED IMPACT:"
        for impact in expectedImpact do
            printfn "  %-30s %s → %s (%s)" impact.Name impact.Current impact.Target impact.Improvement
        printfn ""
        printfn "PHASES: %d total" (List.length phases)
        for phase in phases do
            let status = match phase.Status with Completed -> "✅" | InProgress -> "🔄" | Pending -> "🔲" | Blocked -> "🚫"
            printfn "  %s Phase %d: %s (%s) - %s" status phase.Number phase.Name phase.Day phase.ExpectedImpact
        printfn ""
        printfn "STAMP CONSTRAINTS: %d" (List.length allConstraints)
        printfn "AOR RULES: %d" (List.length allRules)
        printfn "CRITICAL FILES: %d" (List.length criticalFiles)
        printfn "═══════════════════════════════════════════════════════════════"

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 11: DETAILED TASK BREAKDOWNS (5-Level Planning)
    // ═══════════════════════════════════════════════════════════════════

    /// Task with hierarchical ID, dependencies, and estimates
    type PlanTask = {
        Id: string              // e.g., "4.1.0", "4.1.1"
        Description: string
        EstimatedHours: float
        Dependencies: string list
        Phase: int
        Status: PhaseStatus
    }

    /// Phase 4 Tasks: Full Swarm Orchestrator
    let phase4Tasks = [
        { Id = "4.1.0"; Description = "Create EnhancedSwarmOrchestrator.fsx skeleton"; EstimatedHours = 2.0; Dependencies = []; Phase = 4; Status = Pending }
        { Id = "4.1.1"; Description = "Define 16-container DAG"; EstimatedHours = 1.0; Dependencies = ["4.1.0"]; Phase = 4; Status = Pending }
        { Id = "4.1.2"; Description = "Implement Wave 1 boot (DB)"; EstimatedHours = 1.0; Dependencies = ["4.1.1"]; Phase = 4; Status = Pending }
        { Id = "4.1.3"; Description = "Implement Wave 2 boot (OBS+Zenoh)"; EstimatedHours = 2.0; Dependencies = ["4.1.2"]; Phase = 4; Status = Pending }
        { Id = "4.1.4"; Description = "Implement Wave 3 boot (Cognitive)"; EstimatedHours = 1.0; Dependencies = ["4.1.3"]; Phase = 4; Status = Pending }
        { Id = "4.1.5"; Description = "Implement Wave 4 boot (App)"; EstimatedHours = 1.0; Dependencies = ["4.1.4"]; Phase = 4; Status = Pending }
        { Id = "4.1.6"; Description = "Implement Wave 5 boot (HA+Satellites)"; EstimatedHours = 2.0; Dependencies = ["4.1.5"]; Phase = 4; Status = Pending }
        { Id = "4.2.0"; Description = "Implement verifyZenohQuorum()"; EstimatedHours = 2.0; Dependencies = ["4.1.3"]; Phase = 4; Status = Pending }
        { Id = "4.2.1"; Description = "Add 2oo3 early exit logic"; EstimatedHours = 1.0; Dependencies = ["4.2.0"]; Phase = 4; Status = Pending }
        { Id = "4.3.0"; Description = "Implement verifyBiomorphicSystems()"; EstimatedHours = 2.0; Dependencies = ["4.1.6"]; Phase = 4; Status = Pending }
        { Id = "4.3.1"; Description = "Add Sentinel health check"; EstimatedHours = 1.0; Dependencies = ["4.3.0"]; Phase = 4; Status = Pending }
        { Id = "4.3.2"; Description = "Add PatternHunter check"; EstimatedHours = 1.0; Dependencies = ["4.3.1"]; Phase = 4; Status = Pending }
        { Id = "4.3.3"; Description = "Add SymbioticDefense check"; EstimatedHours = 1.0; Dependencies = ["4.3.2"]; Phase = 4; Status = Pending }
        { Id = "4.4.0"; Description = "Integrate 7-Level RCA on failure"; EstimatedHours = 2.0; Dependencies = ["4.1.6"]; Phase = 4; Status = Pending }
        { Id = "4.5.0"; Description = "Create podman-compose-swarm-14.yml"; EstimatedHours = 2.0; Dependencies = ["4.1.1"]; Phase = 4; Status = Pending }
        { Id = "4.6.0"; Description = "Add devenv.nix commands"; EstimatedHours = 1.0; Dependencies = ["4.1.0"]; Phase = 4; Status = Pending }
    ]

    /// Phase 5 Tasks: Enhanced Logging
    let phase5Tasks = [
        { Id = "5.1.0"; Description = "Add VerbosityLevel to Core.fs"; EstimatedHours = 1.0; Dependencies = []; Phase = 5; Status = Pending }
        { Id = "5.1.1"; Description = "Add TestEvidence type"; EstimatedHours = 1.0; Dependencies = ["5.1.0"]; Phase = 5; Status = Pending }
        { Id = "5.2.0"; Description = "Implement minimal output formatter"; EstimatedHours = 1.0; Dependencies = ["5.1.0"]; Phase = 5; Status = Pending }
        { Id = "5.2.1"; Description = "Implement standard output formatter"; EstimatedHours = 1.0; Dependencies = ["5.2.0"]; Phase = 5; Status = Pending }
        { Id = "5.2.2"; Description = "Implement verbose output formatter"; EstimatedHours = 1.0; Dependencies = ["5.2.1"]; Phase = 5; Status = Pending }
        { Id = "5.2.3"; Description = "Implement debug output formatter"; EstimatedHours = 1.0; Dependencies = ["5.2.2"]; Phase = 5; Status = Pending }
        { Id = "5.3.0"; Description = "Add --verbosity CLI flag"; EstimatedHours = 1.0; Dependencies = ["5.2.3"]; Phase = 5; Status = Pending }
        { Id = "5.4.0"; Description = "Implement metrics capture"; EstimatedHours = 2.0; Dependencies = ["5.1.0"]; Phase = 5; Status = Pending }
        { Id = "5.5.0"; Description = "Implement evidence collection"; EstimatedHours = 2.0; Dependencies = ["5.1.1"]; Phase = 5; Status = Pending }
        { Id = "5.5.1"; Description = "Save evidence to JSON files"; EstimatedHours = 1.0; Dependencies = ["5.5.0"]; Phase = 5; Status = Pending }
    ]

    /// Phase 6 Tasks: BDD Feature Files
    let phase6Tasks = [
        { Id = "6.1.0"; Description = "Create full_swarm_boot.feature"; EstimatedHours = 2.0; Dependencies = ["4.1.6"]; Phase = 6; Status = Pending }
        { Id = "6.1.1"; Description = "Write 8 swarm boot scenarios"; EstimatedHours = 2.0; Dependencies = ["6.1.0"]; Phase = 6; Status = Pending }
        { Id = "6.2.0"; Description = "Create biomorphic_integration.feature"; EstimatedHours = 2.0; Dependencies = ["4.3.3"]; Phase = 6; Status = Pending }
        { Id = "6.2.1"; Description = "Write 6 biomorphic scenarios"; EstimatedHours = 2.0; Dependencies = ["6.2.0"]; Phase = 6; Status = Pending }
        { Id = "6.3.0"; Description = "Create crash_recovery.feature"; EstimatedHours = 2.0; Dependencies = ["4.4.0"]; Phase = 6; Status = Pending }
        { Id = "6.3.1"; Description = "Write 8 crash recovery scenarios"; EstimatedHours = 2.0; Dependencies = ["6.3.0"]; Phase = 6; Status = Pending }
        { Id = "6.4.0"; Description = "Create security_validation.feature"; EstimatedHours = 1.0; Dependencies = []; Phase = 6; Status = Pending }
        { Id = "6.4.1"; Description = "Write 6 security scenarios"; EstimatedHours = 2.0; Dependencies = ["6.4.0"]; Phase = 6; Status = Pending }
        { Id = "6.5.0"; Description = "Create comprehensive_smoke_tests.feature"; EstimatedHours = 2.0; Dependencies = []; Phase = 6; Status = Pending }
        { Id = "6.5.1"; Description = "Write 12 comprehensive scenarios"; EstimatedHours = 3.0; Dependencies = ["6.5.0"]; Phase = 6; Status = Pending }
        { Id = "6.6.0"; Description = "Create step definitions"; EstimatedHours = 4.0; Dependencies = ["6.1.1"; "6.2.1"; "6.3.1"; "6.4.1"; "6.5.1"]; Phase = 6; Status = Pending }
    ]

    /// Phase 7 Tasks: Long-Term Optimization
    let phase7Tasks = [
        { Id = "7.1.0"; Description = "Create Dockerfile.precompiled"; EstimatedHours = 4.0; Dependencies = []; Phase = 7; Status = Pending }
        { Id = "7.1.1"; Description = "Build precompiled image"; EstimatedHours = 2.0; Dependencies = ["7.1.0"]; Phase = 7; Status = Pending }
        { Id = "7.1.2"; Description = "Update compose to use precompiled"; EstimatedHours = 1.0; Dependencies = ["7.1.1"]; Phase = 7; Status = Pending }
        { Id = "7.1.3"; Description = "Verify boot time reduction"; EstimatedHours = 1.0; Dependencies = ["7.1.2"]; Phase = 7; Status = Pending }
        { Id = "7.2.0"; Description = "Implement wave parallelization"; EstimatedHours = 4.0; Dependencies = ["4.1.6"]; Phase = 7; Status = Pending }
        { Id = "7.2.1"; Description = "Parallelize W2+W3 (OBS+Cognitive)"; EstimatedHours = 2.0; Dependencies = ["7.2.0"]; Phase = 7; Status = Pending }
        { Id = "7.2.2"; Description = "Add parallel health monitoring"; EstimatedHours = 2.0; Dependencies = ["7.2.1"]; Phase = 7; Status = Pending }
        { Id = "7.3.0"; Description = "Create ComposeGenerator.fs"; EstimatedHours = 4.0; Dependencies = []; Phase = 7; Status = Pending }
        { Id = "7.3.1"; Description = "Implement generateFromConfig"; EstimatedHours = 2.0; Dependencies = ["7.3.0"]; Phase = 7; Status = Pending }
        { Id = "7.3.2"; Description = "Implement validateCompose"; EstimatedHours = 2.0; Dependencies = ["7.3.1"]; Phase = 7; Status = Pending }
        { Id = "7.3.3"; Description = "Regenerate all 16 compose files"; EstimatedHours = 2.0; Dependencies = ["7.3.2"]; Phase = 7; Status = Pending }
        { Id = "7.4.0"; Description = "Create ConfigBridge.fs"; EstimatedHours = 4.0; Dependencies = []; Phase = 7; Status = Pending }
        { Id = "7.4.1"; Description = "Implement exportToElixir"; EstimatedHours = 2.0; Dependencies = ["7.4.0"]; Phase = 7; Status = Pending }
        { Id = "7.4.2"; Description = "Implement publishToZenoh"; EstimatedHours = 2.0; Dependencies = ["7.4.1"]; Phase = 7; Status = Pending }
        { Id = "7.4.3"; Description = "Implement detectDrift"; EstimatedHours = 2.0; Dependencies = ["7.4.2"]; Phase = 7; Status = Pending }
        { Id = "7.5.0"; Description = "Add BEAM volume caching"; EstimatedHours = 2.0; Dependencies = ["7.1.2"]; Phase = 7; Status = Pending }
    ]

    /// All tasks across phases 4-7
    let allTasks = phase4Tasks @ phase5Tasks @ phase6Tasks @ phase7Tasks

    /// Get tasks by phase
    let getTasksByPhase (phase: int) =
        allTasks |> List.filter (fun t -> t.Phase = phase)

    /// Get total estimated hours for a phase
    let getPhaseEstimate (phase: int) =
        getTasksByPhase phase |> List.sumBy (fun t -> t.EstimatedHours)

    /// Get tasks ready to start (all dependencies completed)
    let getReadyTasks (completedIds: Set<string>) =
        allTasks
        |> List.filter (fun t ->
            t.Status = Pending &&
            t.Dependencies |> List.forall (fun d -> completedIds.Contains d))

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 12: MATHEMATICAL OPTIMIZATION (Graph Theory, CPM, DFA)
    // ═══════════════════════════════════════════════════════════════════

    /// Graph-based representation of task dependencies (DAG)
    module TaskGraph =
        open System.Collections.Generic

        /// Build adjacency list from tasks
        let buildAdjacencyList (tasks: PlanTask list) : Map<string, string list> =
            tasks
            |> List.map (fun t -> t.Id, t.Dependencies)
            |> Map.ofList

        /// Topological sort using Kahn's algorithm (for startup order)
        let topologicalSort (tasks: PlanTask list) : Result<string list, string> =
            let adj = buildAdjacencyList tasks
            let inDegree = Dictionary<string, int>()

            // Initialize in-degrees
            for task in tasks do
                if not (inDegree.ContainsKey task.Id) then
                    inDegree.[task.Id] <- 0

            for task in tasks do
                for dep in task.Dependencies do
                    if inDegree.ContainsKey task.Id then
                        inDegree.[task.Id] <- inDegree.[task.Id] + 1

            // Find all nodes with in-degree 0
            let queue = Queue<string>()
            for kvp in inDegree do
                if kvp.Value = 0 then queue.Enqueue(kvp.Key)

            let result = ResizeArray<string>()
            while queue.Count > 0 do
                let node = queue.Dequeue()
                result.Add(node)

                // Find successors
                for task in tasks do
                    if task.Dependencies |> List.contains node then
                        inDegree.[task.Id] <- inDegree.[task.Id] - 1
                        if inDegree.[task.Id] = 0 then
                            queue.Enqueue(task.Id)

            if result.Count = tasks.Length then
                Ok (result |> Seq.toList)
            else
                Error "Cycle detected in task dependencies"

        /// Detect cycles in dependency graph
        let hasCycle (tasks: PlanTask list) : bool =
            match topologicalSort tasks with
            | Ok _ -> false
            | Error _ -> true

    /// Critical Path Method (CPM) for boot time optimization
    module CriticalPath =

        type TaskTiming = {
            Id: string
            Duration: float
            EarliestStart: float
            EarliestFinish: float
            LatestStart: float
            LatestFinish: float
            Slack: float
        }

        /// Calculate critical path for tasks
        let calculateCriticalPath (tasks: PlanTask list) : TaskTiming list =
            let taskMap = tasks |> List.map (fun t -> t.Id, t) |> Map.ofList

            // Forward pass (earliest times)
            let rec earliestFinish (taskId: string) (memo: Map<string, float>) : float * Map<string, float> =
                if memo.ContainsKey taskId then
                    memo.[taskId], memo
                else
                    match Map.tryFind taskId taskMap with
                    | Some task ->
                        let depFinishes, memo' =
                            task.Dependencies
                            |> List.fold (fun (times: float list, m: Map<string, float>) dep ->
                                let t, m' = earliestFinish dep m
                                (t :: times, m')) ([], memo)
                        let es = if List.isEmpty depFinishes then 0.0 else List.max depFinishes
                        let ef = es + task.EstimatedHours
                        ef, Map.add taskId ef memo'
                    | None -> 0.0, memo

            let efMemo =
                tasks
                |> List.fold (fun (m: Map<string, float>) task -> snd (earliestFinish task.Id m)) Map.empty

            let maxEF = efMemo |> Map.toSeq |> Seq.map snd |> Seq.max

            // Calculate timing for each task
            tasks |> List.map (fun task ->
                let ef = Map.find task.Id efMemo
                let es = ef - task.EstimatedHours
                // Simplified - full CPM needs backward pass
                { Id = task.Id
                  Duration = task.EstimatedHours
                  EarliestStart = es
                  EarliestFinish = ef
                  LatestStart = es  // Simplified
                  LatestFinish = ef // Simplified
                  Slack = 0.0 })

        /// Get tasks on critical path (zero slack)
        let getCriticalTasks (timings: TaskTiming list) : string list =
            timings
            |> List.filter (fun t -> t.Slack = 0.0)
            |> List.map (fun t -> t.Id)

        /// Get total project duration
        let getTotalDuration (timings: TaskTiming list) : float =
            timings |> List.map (fun t -> t.EarliestFinish) |> List.max

    /// Finite State Automaton for container lifecycle
    module ContainerDFA =

        /// Container states
        type ContainerState =
            | NotCreated
            | Created
            | Starting
            | Running
            | Healthy
            | Unhealthy
            | Stopping
            | Stopped
            | Failed

        /// Transition events
        type ContainerEvent =
            | Create
            | Start
            | HealthPass
            | HealthFail
            | Stop
            | Kill
            | Remove
            | Crash

        /// DFA transition function
        let transition (state: ContainerState) (event: ContainerEvent) : ContainerState =
            match state, event with
            | NotCreated, Create -> Created
            | Created, Start -> Starting
            | Created, Remove -> NotCreated
            | Starting, HealthPass -> Healthy
            | Starting, HealthFail -> Unhealthy
            | Starting, Crash -> Failed
            | Running, HealthPass -> Healthy
            | Running, HealthFail -> Unhealthy
            | Running, Stop -> Stopping
            | Running, Kill -> Stopped
            | Running, Crash -> Failed
            | Healthy, HealthFail -> Unhealthy
            | Healthy, Stop -> Stopping
            | Healthy, Kill -> Stopped
            | Healthy, Crash -> Failed
            | Unhealthy, HealthPass -> Healthy
            | Unhealthy, Stop -> Stopping
            | Unhealthy, Kill -> Stopped
            | Unhealthy, Crash -> Failed
            | Stopping, _ -> Stopped
            | Stopped, Start -> Starting
            | Stopped, Remove -> NotCreated
            | Failed, Remove -> NotCreated
            | Failed, Start -> Starting
            | s, _ -> s // Invalid transition, stay in current state

        /// Check if state is accepting (system operational)
        let isAccepting (state: ContainerState) : bool =
            match state with
            | Healthy | Running -> true
            | _ -> false

        /// Get valid events from current state
        let validEvents (state: ContainerState) : ContainerEvent list =
            [ Create; Start; HealthPass; HealthFail; Stop; Kill; Remove; Crash ]
            |> List.filter (fun e -> transition state e <> state)

    /// Set theory for configuration management
    module ConfigSets =

        /// Configuration item
        type ConfigItem = {
            Key: string
            Source: string
            Value: string
        }

        /// Find duplicates across sources
        let findDuplicates (items: ConfigItem list) : Map<string, ConfigItem list> =
            items
            |> List.groupBy (fun i -> i.Key)
            |> List.filter (fun (_, items) -> items.Length > 1)
            |> Map.ofList

        /// Find config items only in source A (A \ B)
        let difference (a: ConfigItem list) (b: ConfigItem list) : ConfigItem list =
            let bKeys = b |> List.map (fun i -> i.Key) |> Set.ofList
            a |> List.filter (fun i -> not (bKeys.Contains i.Key))

        /// Find config items in both sources (A ∩ B)
        let intersection (a: ConfigItem list) (b: ConfigItem list) : ConfigItem list =
            let bKeys = b |> List.map (fun i -> i.Key) |> Set.ofList
            a |> List.filter (fun i -> bKeys.Contains i.Key)

        /// Merge configs (B overrides A)
        let merge (a: ConfigItem list) (b: ConfigItem list) : ConfigItem list =
            let bMap = b |> List.map (fun i -> i.Key, i) |> Map.ofList
            let updated =
                a
                |> List.map (fun i ->
                    match Map.tryFind i.Key bMap with
                    | Some bi -> bi
                    | None -> i)
            updated @ (difference b a)

    // ═══════════════════════════════════════════════════════════════════
    // SECTION 13: PLANNING SYSTEM INTEGRATION
    // ═══════════════════════════════════════════════════════════════════

    /// Add all pending tasks to the F# planning system
    let registerPendingTasks (addTaskFn: string option -> string -> string option -> unit) =
        for task in allTasks do
            if task.Status = Pending then
                let priority = if task.Phase = 4 then Some "P0" else Some "P1"
                addTaskFn None (sprintf "[%s] %s" task.Id task.Description) priority
        printfn "Registered %d pending tasks" (allTasks |> List.filter (fun t -> t.Status = Pending) |> List.length)

    /// Get next recommended task based on dependencies and critical path
    let getNextRecommendedTask (completedIds: Set<string>) : PlanTask option =
        let ready = getReadyTasks completedIds
        match ready with
        | [] -> None
        | tasks ->
            // Prioritize by phase, then by critical path (most dependencies depending on it)
            let dependencyCount taskId =
                allTasks |> List.filter (fun t -> t.Dependencies |> List.contains taskId) |> List.length
            tasks
            |> List.sortByDescending (fun t -> dependencyCount t.Id)
            |> List.tryHead

    /// Print execution order for Phase 4
    let printPhase4ExecutionOrder () =
        match TaskGraph.topologicalSort phase4Tasks with
        | Ok order ->
            printfn "Phase 4 Execution Order:"
            order |> List.iteri (fun i id ->
                let task = phase4Tasks |> List.find (fun t -> t.Id = id)
                printfn "  %d. [%s] %s (%.1fh)" (i+1) id task.Description task.EstimatedHours)
            printfn "Total: %.1f hours" (getPhaseEstimate 4)
        | Error msg ->
            printfn "Error: %s" msg

    /// Print full planning summary with mathematical analysis
    let printPlanningAnalysis () =
        printfn "═══════════════════════════════════════════════════════════════"
        printfn " STARTUP OPTIMIZATION: MATHEMATICAL ANALYSIS"
        printfn "═══════════════════════════════════════════════════════════════"
        printfn ""
        printfn "PHASE ESTIMATES:"
        for phase in [4; 5; 6; 7] do
            let hours = getPhaseEstimate phase
            let tasks = getTasksByPhase phase |> List.length
            printfn "  Phase %d: %d tasks, %.1f hours" phase tasks hours
        printfn ""
        printfn "TOTAL: %d tasks, %.1f hours" (List.length allTasks) (allTasks |> List.sumBy (fun t -> t.EstimatedHours))
        printfn ""
        printfn "DEPENDENCY GRAPH:"
        printfn "  Cycle detection: %s" (if TaskGraph.hasCycle allTasks then "CYCLES FOUND" else "ACYCLIC ✓")
        printfn ""
        printfn "CRITICAL PATH (Phase 4):"
        let timings = CriticalPath.calculateCriticalPath phase4Tasks
        let critical = CriticalPath.getCriticalTasks timings
        for id in critical |> List.take (min 5 critical.Length) do
            printfn "  → %s" id
        printfn "  Total duration: %.1f hours" (CriticalPath.getTotalDuration timings)
        printfn "═══════════════════════════════════════════════════════════════"
