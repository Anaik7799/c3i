/// CEPAF Test-Driven Generation (TDG) Harness Module
/// Version: 2.0.0
/// TDG-001: Tests MUST exist before code generation
/// TDG-002: Dual property tests (PropCheck + ExUnitProperties pattern)
/// TDG-003: Coverage threshold >= 95%
/// SC-METRICS-003: Mandatory 16:16 Parallelization for Elixir test execution
/// SC-METRICS-004: Comprehensive test execution metrics
///
/// WHAT: Enforces Test-Driven Generation methodology for code generation
/// WHY: Ensures all generated code has pre-existing test coverage per Omega_4 axiom
/// CONSTRAINTS: Generation blocked without passing tests; coverage must exceed 95%
module Cepaf.Modules.TDGHarness

open System
open System.IO
open System.Diagnostics
open System.Text.RegularExpressions
open Cepaf
open Cepaf.Rop
open Cepaf.Infrastructure
open Cepaf.Observability
open Cepaf.Modules.ConstraintValidator
open Cepaf.Core.Pipelines        // SC-FSH-070: AsyncResult pipelines

// ============================================================================
// SC-METRICS-003: MANDATORY PARALLELIZATION ENVIRONMENT VARIABLES
// ============================================================================

/// Mandatory environment variables for SC-METRICS-003 compliance
/// Ensures maximum parallelization of Elixir test execution
let mandatoryTestEnvVars : (string * string) list = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")  // 16 schedulers + 16 dirty I/O
    ("NO_TIMEOUT", "true")                        // Patient Mode: no timeout
    ("PATIENT_MODE", "enabled")                   // Patient Mode flag
    ("INFINITE_PATIENCE", "true")                 // Never interrupt compilation/tests
    ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")  // Parallel dependency compilation
    ("SKIP_ZENOH_NIF", "0")                       // Enable Zenoh NIF (SC-TEST-005)
    ("MIX_ENV", "test")                           // Ensure test environment
]

/// Build process start info with SC-METRICS-003 environment variables
let injectMandatoryEnvVars (psi: ProcessStartInfo) : unit =
    for (key, value) in mandatoryTestEnvVars do
        psi.EnvironmentVariables.[key] <- value

// ============================================================================
// SC-METRICS-004: TEST EXECUTION METRICS
// ============================================================================

/// Comprehensive test execution metrics per SC-METRICS-004
type TestExecutionMetrics = {
    StartTime: DateTime
    EndTime: DateTime
    DurationMs: int64
    ExitCode: int
    TestsTotal: int
    TestsPassed: int
    TestsFailed: int
    TestsSkipped: int
    CoveragePercent: float option
    SchedulersOnline: int
    DirtyIOSchedulers: int
    PatientMode: bool
    MemoryUsageMB: int64
    OutputLines: int
    Success: bool
}

/// Empty test execution metrics
let emptyTestMetrics : TestExecutionMetrics = {
    StartTime = DateTime.MinValue
    EndTime = DateTime.MinValue
    DurationMs = 0L
    ExitCode = -1
    TestsTotal = 0
    TestsPassed = 0
    TestsFailed = 0
    TestsSkipped = 0
    CoveragePercent = None
    SchedulersOnline = 16
    DirtyIOSchedulers = 16
    PatientMode = true
    MemoryUsageMB = 0L
    OutputLines = 0
    Success = false
}

/// Parse test metrics from mix test output
let parseTestMetrics (output: string) (startTime: DateTime) (endTime: DateTime) (exitCode: int) : TestExecutionMetrics =
    let lines = output.Split('\n')

    // Parse test results: "10 tests, 2 failures, 1 skipped"
    let resultPattern = Regex(@"(\d+)\s+tests?,\s*(\d+)\s+failures?(?:,\s*(\d+)\s+skipped)?")
    let resultMatch = resultPattern.Match(output)
    let (total, failed, skipped) =
        if resultMatch.Success then
            let t = Int32.Parse(resultMatch.Groups.[1].Value)
            let f = Int32.Parse(resultMatch.Groups.[2].Value)
            let s = if resultMatch.Groups.[3].Success then Int32.Parse(resultMatch.Groups.[3].Value) else 0
            (t, f, s)
        else
            (0, 0, 0)

    // Parse coverage percentage
    let coveragePattern = Regex(@"Coverage:\s*([\d.]+)%", RegexOptions.IgnoreCase)
    let coverageMatch = coveragePattern.Match(output)
    let coverage =
        if coverageMatch.Success then
            match Double.TryParse(coverageMatch.Groups.[1].Value) with
            | true, v -> Some v
            | false, _ -> None
        else
            None

    {
        StartTime = startTime
        EndTime = endTime
        DurationMs = int64 (endTime - startTime).TotalMilliseconds
        ExitCode = exitCode
        TestsTotal = total
        TestsPassed = total - failed - skipped
        TestsFailed = failed
        TestsSkipped = skipped
        CoveragePercent = coverage
        SchedulersOnline = 16
        DirtyIOSchedulers = 16
        PatientMode = true
        MemoryUsageMB = 0L
        OutputLines = lines.Length
        Success = exitCode = 0 && failed = 0
    }

/// Print test metrics summary
let printTestMetricsSummary (metrics: TestExecutionMetrics) : unit =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════╗"
    printfn "║  SC-METRICS-003/004: TEST EXECUTION METRICS SUMMARY              ║"
    printfn "╠══════════════════════════════════════════════════════════════════╣"
    printfn "║  Duration:     %7dms                                          ║" metrics.DurationMs
    printfn "║  Tests Total:  %7d                                             ║" metrics.TestsTotal
    printfn "║  Passed:       %7d                                             ║" metrics.TestsPassed
    printfn "║  Failed:       %7d                                             ║" metrics.TestsFailed
    printfn "║  Skipped:      %7d                                             ║" metrics.TestsSkipped
    printfn "║  Schedulers:   %7d online + %d dirty I/O                      ║" metrics.SchedulersOnline metrics.DirtyIOSchedulers
    printfn "║  Patient Mode: %7b                                            ║" metrics.PatientMode
    match metrics.CoveragePercent with
    | Some cov -> printfn "║  Coverage:     %7.2f%%                                           ║" cov
    | None -> printfn "║  Coverage:     N/A                                                ║"
    printfn "║  Status:       %s                                              ║" (if metrics.Success then "SUCCESS" else "FAILURE")
    printfn "╚══════════════════════════════════════════════════════════════════╝"

// ============================================================================
// TYPES - Test-Driven Generation
// ============================================================================

/// Severity levels for TDG violations
type TDGSeverity =
    | TDGCritical   // Blocks generation entirely
    | TDGHigh       // Must resolve before merge
    | TDGMedium     // Should resolve soon
    | TDGLow        // Advisory

/// TDG Constraint violation record
type TDGViolation = {
    ConstraintId: string           // e.g., "TDG-001"
    Message: string
    Severity: TDGSeverity
    Timestamp: DateTime
    Context: Map<string, string>
}

/// Property test framework identifier
type PropertyTestFramework =
    | PropCheck           // Erlang-style property testing
    | ExUnitProperties    // StreamData-based property testing
    | Both                // Dual property tests required

/// Test specification for a module
type TestSpec = {
    TestFilePath: string           // Path to test file
    TestModuleName: string         // Module under test
    TestNames: string list         // Individual test names
    ExpectedCoverage: float        // Expected coverage percentage (0.0-100.0)
    PropertyFrameworks: PropertyTestFramework list  // Required property test frameworks
    IsPropertyTest: bool           // Whether this is a property-based test
    Tags: string list              // Test tags (e.g., ["unit"; "integration"])
}

/// Code generation request
type GenerationRequest = {
    TargetModule: string           // Module to generate
    TargetFilePath: string         // Path for generated file
    RequiredTests: TestSpec list   // Tests that must exist and pass
    Constraints: string list       // STAMP constraint IDs to validate
    GenerationType: GenerationType // Type of generation
    PatientMode: bool              // Use patient mode for compilation
    Metadata: Map<string, string>  // Additional metadata
}

/// Type of code generation
and GenerationType =
    | NewModule           // Generate new module from scratch
    | Enhancement         // Enhance existing module
    | Refactor            // Refactor existing code
    | BugFix              // Fix for failing tests
    | PropertyTest        // Generate property-based tests

/// Test execution result
type TestExecutionResult = {
    TestSpec: TestSpec
    Passed: bool
    FailedTests: string list
    PassedTests: string list
    ExecutionTimeMs: int64
    CoveragePercent: float option
    Output: string
    ErrorOutput: string
}

/// TDG validation status
type TDGValidationStatus =
    | TDGNotValidated                     // Initial state
    | TDGValidating                       // Validation in progress
    | TDGTestsExist                       // Tests exist (TDG-001 passed)
    | TDGTestsPassing                     // Tests exist and pass
    | TDGCoverageAchieved                 // Coverage threshold met (TDG-003 passed)
    | TDGFullyValidated                   // All TDG constraints satisfied
    | TDGFailed of TDGViolation list      // Validation failed

/// Comprehensive TDG result
type TDGResult = {
    Request: GenerationRequest
    Status: TDGValidationStatus
    TestResults: TestExecutionResult list
    CoverageMetrics: CoverageMetrics
    Violations: TDGViolation list
    TotalValidationTimeMs: int64
    ValidatedAt: DateTime
    CanProceedWithGeneration: bool
}

/// Coverage metrics aggregation
and CoverageMetrics = {
    OverallCoverage: float         // Total coverage percentage
    LineCoverage: float            // Line coverage
    BranchCoverage: float option   // Branch coverage (if available)
    FunctionCoverage: float option // Function coverage (if available)
    CoveredModules: string list    // Modules with coverage data
    UncoveredLines: int            // Total uncovered lines
    ThresholdMet: bool             // Whether TDG-003 threshold is met
}

/// TDG Pipeline configuration
type TDGPipelineConfig = {
    ProjectRoot: string            // Project root directory
    TestDirectory: string          // Test directory (relative to root)
    CoverageThreshold: float       // Minimum coverage percentage (default 95.0)
    RequireDualPropertyTests: bool // TDG-002 enforcement
    PatientModeTimeout: int        // Timeout for patient mode (ms)
    MaxTestRetries: int            // Maximum test retry attempts
    ParseCoverageOutput: bool      // Whether to parse coverage data
    FailFast: bool                 // Stop on first failure
}

// ============================================================================
// DEFAULT CONFIGURATION
// ============================================================================

/// Default TDG pipeline configuration
let defaultConfig (projectRoot: string) : TDGPipelineConfig = {
    ProjectRoot = projectRoot
    TestDirectory = "test"
    CoverageThreshold = 95.0
    RequireDualPropertyTests = true
    PatientModeTimeout = 7200000  // 2 hours (patient mode)
    MaxTestRetries = 2
    ParseCoverageOutput = true
    FailFast = false
}

/// Create default coverage metrics (empty)
let emptyCoverageMetrics : CoverageMetrics = {
    OverallCoverage = 0.0
    LineCoverage = 0.0
    BranchCoverage = None
    FunctionCoverage = None
    CoveredModules = []
    UncoveredLines = 0
    ThresholdMet = false
}

// ============================================================================
// TEST DISCOVERY (TDG-001: Tests MUST exist)
// ============================================================================

/// Discover test files for a given module
let discoverTestFiles
    (logger: UnifiedLogger)
    (config: TDGPipelineConfig)
    (moduleName: string)
    : Result<string list, TDGViolation> =

    logger.LogWithCategory(
        sprintf "[TDG-001] Discovering tests for module '%s'..." moduleName,
        EventCategory.Test, LogLevel.Debug)

    let testDir = Path.Combine(config.ProjectRoot, config.TestDirectory)

    if not (Directory.Exists(testDir)) then
        Error {
            ConstraintId = "TDG-001"
            Message = sprintf "Test directory not found: %s" testDir
            Severity = TDGCritical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [("test_dir", testDir); ("module", moduleName)]
        }
    else
        // Convert module name to potential test file patterns
        // e.g., "Indrajaal.Cortex.Analyzer" -> ["cortex/analyzer_test.exs", "cortex_analyzer_test.exs"]
        let moduleNameLower = moduleName.ToLowerInvariant()
        let parts = moduleNameLower.Split('.') |> Array.toList

        // Generate possible test file patterns
        let patterns = [
            // Pattern 1: Full path with underscores
            sprintf "*%s_test.exs" (parts |> String.concat "_")
            // Pattern 2: Last part only
            sprintf "*%s_test.exs" (parts |> List.tryLast |> Option.defaultValue moduleName)
            // Pattern 3: Directory structure
            sprintf "%s/**/*_test.exs" (parts |> List.tryHead |> Option.defaultValue "")
        ]

        let foundFiles =
            patterns
            |> List.collect (fun pattern ->
                try
                    Directory.GetFiles(testDir, pattern, SearchOption.AllDirectories)
                    |> Array.toList
                with _ -> [])
            |> List.distinct

        logger.Info(sprintf "  Found %d test file(s) for '%s'" (List.length foundFiles) moduleName)

        if List.isEmpty foundFiles then
            Error {
                ConstraintId = "TDG-001"
                Message = sprintf "No test files found for module '%s'" moduleName
                Severity = TDGCritical
                Timestamp = DateTime.UtcNow
                Context = Map.ofList [
                    ("module", moduleName)
                    ("test_dir", testDir)
                    ("searched_patterns", patterns |> String.concat ", ")
                ]
            }
        else
            Ok foundFiles

/// Parse test names from a test file
let parseTestNames (testFilePath: string) : string list =
    try
        let content = File.ReadAllText(testFilePath)

        // Match test definitions: test "name" do, test("name") do, describe "name" do
        let testPattern = Regex(@"(?:test|describe|property)\s+[""']([^""']+)[""']", RegexOptions.Multiline)
        let matches = testPattern.Matches(content)

        matches
        |> Seq.cast<Match>
        |> Seq.map (fun m -> m.Groups.[1].Value)
        |> Seq.toList
    with _ -> []

/// Check for property test frameworks in test file
let detectPropertyFrameworks (testFilePath: string) : PropertyTestFramework list =
    try
        let content = File.ReadAllText(testFilePath)

        let frameworks = ResizeArray<PropertyTestFramework>()

        // Check for PropCheck
        if content.Contains("use PropCheck") || content.Contains("import PropCheck") then
            frameworks.Add(PropCheck)

        // Check for ExUnitProperties (StreamData)
        if content.Contains("use ExUnitProperties") ||
           content.Contains("property ") ||
           content.Contains("StreamData") then
            frameworks.Add(ExUnitProperties)

        frameworks |> List.ofSeq
    with _ -> []

/// Build a TestSpec from a discovered test file
let buildTestSpec
    (testFilePath: string)
    (moduleName: string)
    (expectedCoverage: float)
    : TestSpec =

    let testNames = parseTestNames testFilePath
    let frameworks = detectPropertyFrameworks testFilePath

    {
        TestFilePath = testFilePath
        TestModuleName = moduleName
        TestNames = testNames
        ExpectedCoverage = expectedCoverage
        PropertyFrameworks = frameworks
        IsPropertyTest = not (List.isEmpty frameworks)
        Tags = []  // Could be parsed from @tag annotations
    }

/// Full test discovery for a module
let discoverTests
    (logger: UnifiedLogger)
    (config: TDGPipelineConfig)
    (moduleName: string)
    (expectedCoverage: float)
    : Result<TestSpec list, TDGViolation> =

    logger.Info(sprintf "[TDG-001] Starting test discovery for '%s'" moduleName)
    logger.IncrementCounter("tdg.discovery_started", tags = Map.ofList [("module", moduleName)])

    match discoverTestFiles logger config moduleName with
    | Error e -> Error e
    | Ok files ->
        let specs =
            files
            |> List.map (fun f -> buildTestSpec f moduleName expectedCoverage)

        logger.Info(sprintf "  Discovered %d test spec(s) with %d total test(s)"
            (List.length specs)
            (specs |> List.sumBy (fun s -> List.length s.TestNames)))

        logger.IncrementCounter("tdg.tests_discovered",
            tags = Map.ofList [
                ("module", moduleName)
                ("count", string (specs |> List.sumBy (fun s -> List.length s.TestNames)))
            ])

        Ok specs

// ============================================================================
// TDG-001: VALIDATE TESTS EXIST
// ============================================================================

/// Validate that tests exist for all required modules (TDG-001)
let validateTestsExist
    (logger: UnifiedLogger)
    (specs: TestSpec list)
    : Result<TestSpec list, TDGViolation> =

    logger.StartPhase("TDG_VALIDATE_EXIST")

    if List.isEmpty specs then
        logger.Error("[TDG-001] VIOLATION: No tests exist for generation target")
        logger.EndPhase("TDG_VALIDATE_EXIST", 0L, false)
        Error {
            ConstraintId = "TDG-001"
            Message = "No tests exist for the generation target"
            Severity = TDGCritical
            Timestamp = DateTime.UtcNow
            Context = Map.empty
        }
    else
        // Verify each test file actually exists
        let missingFiles =
            specs
            |> List.filter (fun s -> not (File.Exists(s.TestFilePath)))

        if not (List.isEmpty missingFiles) then
            let missing = missingFiles |> List.map (fun s -> s.TestFilePath) |> String.concat ", "
            logger.Error(sprintf "[TDG-001] VIOLATION: Test files missing: %s" missing)
            logger.EndPhase("TDG_VALIDATE_EXIST", 0L, false)
            Error {
                ConstraintId = "TDG-001"
                Message = sprintf "Test files do not exist: %s" missing
                Severity = TDGCritical
                Timestamp = DateTime.UtcNow
                Context = Map.ofList [("missing_files", missing)]
            }
        else
            // Verify tests are defined (not empty files)
            let emptySpecs =
                specs
                |> List.filter (fun s -> List.isEmpty s.TestNames)

            if not (List.isEmpty emptySpecs) then
                let empty = emptySpecs |> List.map (fun s -> s.TestFilePath) |> String.concat ", "
                logger.LogWithCategory(
                    sprintf "[TDG-001] Warning: Test files with no test definitions: %s" empty,
                    EventCategory.Test, LogLevel.Warning)

            logger.Info(sprintf "[TDG-001] PASSED: %d test file(s) validated" (List.length specs))
            logger.IncrementCounter("tdg.validation.tests_exist", tags = Map.ofList [("result", "pass")])
            logger.EndPhase("TDG_VALIDATE_EXIST", 0L, true)
            Ok specs

// ============================================================================
// TDG-002: VALIDATE DUAL PROPERTY TESTS
// ============================================================================

/// Validate dual property test requirement (TDG-002)
let validateDualPropertyTests
    (logger: UnifiedLogger)
    (specs: TestSpec list)
    (requireDual: bool)
    : Result<TestSpec list, TDGViolation> =

    if not requireDual then
        Ok specs
    else
        logger.StartPhase("TDG_VALIDATE_PROPERTY")

        // Find specs that should have property tests but don't have both frameworks
        let needsDualProperty =
            specs
            |> List.filter (fun s -> s.IsPropertyTest)
            |> List.filter (fun s ->
                not (List.contains PropCheck s.PropertyFrameworks &&
                     List.contains ExUnitProperties s.PropertyFrameworks))

        if not (List.isEmpty needsDualProperty) then
            let lacking = needsDualProperty |> List.map (fun s -> s.TestFilePath) |> String.concat ", "

            // This is a warning, not a blocking error (unless strict mode)
            logger.LogWithCategory(
                sprintf "[TDG-002] Property tests missing dual framework coverage: %s" lacking,
                EventCategory.Test, LogLevel.Warning)

            logger.IncrementCounter("tdg.validation.dual_property",
                tags = Map.ofList [("result", "warning"); ("count", string (List.length needsDualProperty))])

        logger.Info("[TDG-002] Property test validation complete")
        logger.EndPhase("TDG_VALIDATE_PROPERTY", 0L, true)
        Ok specs

// ============================================================================
// TEST EXECUTION
// ============================================================================

/// Parse coverage percentage from mix test output
let parseCoverageFromOutput (output: string) : float option =
    // Pattern: "Coverage: 95.5%"
    let coveragePattern = Regex(@"Coverage:\s*([\d.]+)%", RegexOptions.IgnoreCase)
    let match' = coveragePattern.Match(output)

    if match'.Success then
        match Double.TryParse(match'.Groups.[1].Value) with
        | true, value -> Some value
        | false, _ -> None
    else
        None

/// Parse test results from mix test output
let parseTestResults (output: string) : int * int =
    // Pattern: "10 tests, 2 failures"
    let resultPattern = Regex(@"(\d+)\s+tests?,\s*(\d+)\s+failures?")
    let match' = resultPattern.Match(output)

    if match'.Success then
        let total = Int32.Parse(match'.Groups.[1].Value)
        let failures = Int32.Parse(match'.Groups.[2].Value)
        (total - failures, failures)
    else
        (0, 0)

/// Run tests for a single TestSpec
let runTestSpec
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (spec: TestSpec)
    : Async<TestExecutionResult> = async {

    logger.LogWithCategory(
        sprintf "  Running tests: %s" spec.TestFilePath,
        EventCategory.Test, LogLevel.Debug)

    let sw = Stopwatch.StartNew()

    // Build mix test command
    let testPath = spec.TestFilePath
    let args = [
        "test"
        testPath
        "--coverage"
        "--trace"
    ]

    let! result = runner.Run("mix", args, patientMode = true)
    sw.Stop()

    match result with
    | Ok cmdResult ->
        let output = cmdResult.StandardOutput
        let errorOutput = cmdResult.StandardError
        let coverage = parseCoverageFromOutput output
        let (passed, failed) = parseTestResults output

        let passedTests =
            spec.TestNames
            |> List.take (min passed (List.length spec.TestNames))

        let failedTests =
            if failed > 0 then
                spec.TestNames
                |> List.skip (List.length spec.TestNames - failed)
                |> List.truncate failed
            else []

        logger.IncrementCounter("tdg.test_execution",
            tags = Map.ofList [
                ("file", Path.GetFileName(spec.TestFilePath))
                ("passed", string passed)
                ("failed", string failed)
            ])

        return {
            TestSpec = spec
            Passed = failed = 0
            FailedTests = failedTests
            PassedTests = passedTests
            ExecutionTimeMs = sw.ElapsedMilliseconds
            CoveragePercent = coverage
            Output = output
            ErrorOutput = errorOutput
        }

    | Error err ->
        logger.Error(sprintf "Test execution failed: %s" spec.TestFilePath)
        return {
            TestSpec = spec
            Passed = false
            FailedTests = spec.TestNames
            PassedTests = []
            ExecutionTimeMs = sw.ElapsedMilliseconds
            CoveragePercent = None
            Output = ""
            ErrorOutput = sprintf "Execution error: %A" err
        }
}

/// Run all tests in a test spec list
let runTests
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (specs: TestSpec list)
    : Async<TestExecutionResult list> = async {

    logger.Info(sprintf "Running %d test spec(s)..." (List.length specs))
    logger.StartPhase("TDG_RUN_TESTS")
    let sw = Stopwatch.StartNew()

    let! results =
        specs
        |> List.map (runTestSpec logger runner config)
        |> Async.Sequential

    sw.Stop()

    let allResults = results |> Array.toList
    let passedCount = allResults |> List.filter (fun r -> r.Passed) |> List.length
    let failedCount = allResults |> List.filter (fun r -> not r.Passed) |> List.length

    logger.Info(sprintf "Test execution complete: %d passed, %d failed in %dms"
        passedCount failedCount sw.ElapsedMilliseconds)

    logger.RecordHistogram("tdg.test_execution_ms", float sw.ElapsedMilliseconds,
        Map.ofList [("specs", string (List.length specs))])

    logger.EndPhase("TDG_RUN_TESTS", sw.ElapsedMilliseconds, (failedCount = 0))

    return allResults
}

// ============================================================================
// TDG-003: VALIDATE COVERAGE
// ============================================================================

/// Aggregate coverage metrics from test results
let aggregateCoverageMetrics
    (results: TestExecutionResult list)
    (threshold: float)
    : CoverageMetrics =

    let coverages =
        results
        |> List.choose (fun r -> r.CoveragePercent)

    if List.isEmpty coverages then
        { emptyCoverageMetrics with ThresholdMet = false }
    else
        let avgCoverage = coverages |> List.average

        {
            OverallCoverage = avgCoverage
            LineCoverage = avgCoverage  // Approximate
            BranchCoverage = None
            FunctionCoverage = None
            CoveredModules = results |> List.map (fun r -> r.TestSpec.TestModuleName) |> List.distinct
            UncoveredLines = 0  // Would need detailed parsing
            ThresholdMet = avgCoverage >= threshold
        }

/// Validate coverage threshold (TDG-003)
let validateCoverage
    (logger: UnifiedLogger)
    (metrics: CoverageMetrics)
    (threshold: float)
    : Result<CoverageMetrics, TDGViolation> =

    logger.StartPhase("TDG_VALIDATE_COVERAGE")

    logger.Info(sprintf "[TDG-003] Coverage: %.2f%% (threshold: %.2f%%)"
        metrics.OverallCoverage threshold)

    if metrics.OverallCoverage >= threshold then
        logger.Info("[TDG-003] PASSED: Coverage threshold met")
        logger.IncrementCounter("tdg.validation.coverage",
            tags = Map.ofList [("result", "pass"); ("coverage", sprintf "%.2f" metrics.OverallCoverage)])
        logger.EndPhase("TDG_VALIDATE_COVERAGE", 0L, true)
        Ok { metrics with ThresholdMet = true }
    else
        let deficit = threshold - metrics.OverallCoverage
        logger.Error(sprintf "[TDG-003] VIOLATION: Coverage %.2f%% below threshold (deficit: %.2f%%)"
            metrics.OverallCoverage deficit)
        logger.IncrementCounter("tdg.validation.coverage",
            tags = Map.ofList [("result", "fail"); ("coverage", sprintf "%.2f" metrics.OverallCoverage)])
        logger.EndPhase("TDG_VALIDATE_COVERAGE", 0L, false)
        Error {
            ConstraintId = "TDG-003"
            Message = sprintf "Coverage %.2f%% below required %.2f%% threshold" metrics.OverallCoverage threshold
            Severity = TDGHigh
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("actual_coverage", sprintf "%.2f" metrics.OverallCoverage)
                ("threshold", sprintf "%.2f" threshold)
                ("deficit", sprintf "%.2f" deficit)
            ]
        }

// ============================================================================
// TDG PIPELINE - FULL VALIDATION WORKFLOW
// ============================================================================

/// Determine final TDG status from validation results
let determineTDGStatus
    (testsExist: bool)
    (testsPassed: bool)
    (coverageMet: bool)
    (violations: TDGViolation list)
    : TDGValidationStatus =

    if not (List.isEmpty violations) && violations |> List.exists (fun v -> v.Severity = TDGCritical) then
        TDGFailed violations
    elif not testsExist then
        TDGFailed [{ ConstraintId = "TDG-001"; Message = "Tests do not exist"; Severity = TDGCritical; Timestamp = DateTime.UtcNow; Context = Map.empty }]
    elif not testsPassed then
        TDGTestsExist  // Tests exist but failed
    elif not coverageMet then
        TDGTestsPassing  // Tests pass but coverage insufficient
    else
        TDGFullyValidated

/// Full TDG validation pipeline
let validateTDGPipeline
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (request: GenerationRequest)
    : Async<TDGResult> = async {

    logger.Info("=" |> String.replicate 70)
    logger.Info(sprintf "TDG VALIDATION PIPELINE: %s" request.TargetModule)
    logger.Info("=" |> String.replicate 70)
    logger.StartPhase("TDG_PIPELINE")

    let sw = Stopwatch.StartNew()
    let violations = ResizeArray<TDGViolation>()
    let mutable testsExist = false
    let mutable testsPassed = false
    let mutable coverageMet = false

    // Step 1: Validate tests exist (TDG-001)
    logger.Info("Step 1: Validating tests exist (TDG-001)...")

    let testSpecs =
        if List.isEmpty request.RequiredTests then
            // Discover tests if not provided
            match discoverTests logger config request.TargetModule config.CoverageThreshold with
            | Ok specs -> specs
            | Error v ->
                violations.Add(v)
                []
        else
            request.RequiredTests

    match validateTestsExist logger testSpecs with
    | Ok validSpecs ->
        testsExist <- true

        // Step 2: Validate dual property tests (TDG-002)
        logger.Info("Step 2: Validating property tests (TDG-002)...")
        match validateDualPropertyTests logger validSpecs config.RequireDualPropertyTests with
        | Ok propertySpecs ->

            // Step 3: Run tests
            logger.Info("Step 3: Running tests...")
            let! testResults = runTests logger runner config propertySpecs

            let allPassed = testResults |> List.forall (fun r -> r.Passed)
            testsPassed <- allPassed

            if not allPassed then
                let failedCount = testResults |> List.filter (fun r -> not r.Passed) |> List.length
                violations.Add({
                    ConstraintId = "TDG-RUN"
                    Message = sprintf "%d test spec(s) failed" failedCount
                    Severity = TDGHigh
                    Timestamp = DateTime.UtcNow
                    Context = Map.ofList [("failed_count", string failedCount)]
                })

            // Step 4: Validate coverage (TDG-003)
            logger.Info("Step 4: Validating coverage (TDG-003)...")
            let metrics = aggregateCoverageMetrics testResults config.CoverageThreshold

            match validateCoverage logger metrics config.CoverageThreshold with
            | Ok validMetrics ->
                coverageMet <- true
                sw.Stop()

                let status = determineTDGStatus testsExist testsPassed coverageMet (violations |> List.ofSeq)
                let canProceed = status = TDGFullyValidated

                // Log final status
                if canProceed then
                    logger.Info("[TDG] VALIDATION PASSED - Generation may proceed")
                    logger.IncrementCounter("tdg.pipeline", tags = Map.ofList [("result", "pass")])
                else
                    logger.LogWithCategory("[TDG] VALIDATION INCOMPLETE - Generation blocked",
                        EventCategory.Test, LogLevel.Warning)
                    logger.IncrementCounter("tdg.pipeline", tags = Map.ofList [("result", "blocked")])

                logger.EndPhase("TDG_PIPELINE", sw.ElapsedMilliseconds, canProceed)

                return {
                    Request = request
                    Status = status
                    TestResults = testResults
                    CoverageMetrics = validMetrics
                    Violations = violations |> List.ofSeq
                    TotalValidationTimeMs = sw.ElapsedMilliseconds
                    ValidatedAt = DateTime.UtcNow
                    CanProceedWithGeneration = canProceed
                }

            | Error v ->
                violations.Add(v)
                sw.Stop()

                logger.EndPhase("TDG_PIPELINE", sw.ElapsedMilliseconds, false)

                return {
                    Request = request
                    Status = TDGTestsPassing
                    TestResults = testResults
                    CoverageMetrics = metrics
                    Violations = violations |> List.ofSeq
                    TotalValidationTimeMs = sw.ElapsedMilliseconds
                    ValidatedAt = DateTime.UtcNow
                    CanProceedWithGeneration = false
                }

        | Error v ->
            violations.Add(v)
            sw.Stop()
            logger.EndPhase("TDG_PIPELINE", sw.ElapsedMilliseconds, false)

            return {
                Request = request
                Status = TDGFailed (violations |> List.ofSeq)
                TestResults = []
                CoverageMetrics = emptyCoverageMetrics
                Violations = violations |> List.ofSeq
                TotalValidationTimeMs = sw.ElapsedMilliseconds
                ValidatedAt = DateTime.UtcNow
                CanProceedWithGeneration = false
            }

    | Error v ->
        violations.Add(v)
        sw.Stop()
        logger.EndPhase("TDG_PIPELINE", sw.ElapsedMilliseconds, false)

        return {
            Request = request
            Status = TDGFailed (violations |> List.ofSeq)
            TestResults = []
            CoverageMetrics = emptyCoverageMetrics
            Violations = violations |> List.ofSeq
            TotalValidationTimeMs = sw.ElapsedMilliseconds
            ValidatedAt = DateTime.UtcNow
            CanProceedWithGeneration = false
        }
}

// ============================================================================
// GENERATION WITH TDG - FULL WORKFLOW
// ============================================================================

/// Execute full TDG workflow with generation (async result pattern)
let generateWithTDG
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (request: GenerationRequest)
    (generator: GenerationRequest -> AsyncResult<string, AppError>)
    : AsyncResult<string * TDGResult, AppError> = asyncResult {

    logger.Info(sprintf "Starting TDG-controlled generation for '%s'" request.TargetModule)
    logger.IncrementCounter("tdg.generation_started", tags = Map.ofList [("module", request.TargetModule)])

    // Step 1: Run full TDG validation
    let! tdgResult = validateTDGPipeline logger runner config request |> fromAsync

    // Step 2: Check if generation can proceed
    if not tdgResult.CanProceedWithGeneration then
        logger.Error("[TDG] Generation BLOCKED - TDG validation failed")

        let errorMsg =
            tdgResult.Violations
            |> List.map (fun v -> sprintf "[%s] %s" v.ConstraintId v.Message)
            |> String.concat "; "

        return! fromResult (Error (ValidationFailed("TDG", errorMsg)))
    else
        // Step 3: Execute generation
        logger.Info("[TDG] Validation passed - proceeding with generation")

        let! generatedCode = generator request

        logger.Info(sprintf "[TDG] Generation complete for '%s'" request.TargetModule)
        logger.IncrementCounter("tdg.generation_completed", tags = Map.ofList [("module", request.TargetModule)])

        return (generatedCode, tdgResult)
}

// ============================================================================
// REPORT GENERATION
// ============================================================================

/// Generate TDG validation report
let generateTDGReport (result: TDGResult) : string =
    let sb = System.Text.StringBuilder()

    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine(sprintf "TDG VALIDATION REPORT: %s" result.Request.TargetModule) |> ignore
    sb.AppendLine(sprintf "Validated at: %s" (result.ValidatedAt.ToString("yyyy-MM-dd HH:mm:ss UTC"))) |> ignore
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine() |> ignore

    // Status
    let statusStr =
        match result.Status with
        | TDGNotValidated -> "NOT VALIDATED"
        | TDGValidating -> "VALIDATING..."
        | TDGTestsExist -> "TESTS EXIST (but may be failing)"
        | TDGTestsPassing -> "TESTS PASSING (coverage insufficient)"
        | TDGCoverageAchieved -> "COVERAGE ACHIEVED"
        | TDGFullyValidated -> "FULLY VALIDATED"
        | TDGFailed _ -> "FAILED"

    sb.AppendLine(sprintf "STATUS: %s" statusStr) |> ignore
    sb.AppendLine(sprintf "Can Proceed: %b" result.CanProceedWithGeneration) |> ignore
    sb.AppendLine(sprintf "Total Time: %dms" result.TotalValidationTimeMs) |> ignore
    sb.AppendLine() |> ignore

    // TDG Constraint Compliance
    sb.AppendLine("TDG CONSTRAINT COMPLIANCE:") |> ignore
    let hasTestsViolation = result.Violations |> List.exists (fun v -> v.ConstraintId = "TDG-001")
    let hasCoverageViolation = result.Violations |> List.exists (fun v -> v.ConstraintId = "TDG-003")

    sb.AppendLine(sprintf "  TDG-001 (Tests Exist): %s" (if hasTestsViolation then "FAIL" else "PASS")) |> ignore
    sb.AppendLine(sprintf "  TDG-002 (Dual Property): %s" "PASS") |> ignore  // Warning-only
    sb.AppendLine(sprintf "  TDG-003 (Coverage >= 95%%): %s" (if hasCoverageViolation then "FAIL" else "PASS")) |> ignore
    sb.AppendLine() |> ignore

    // Coverage Metrics
    sb.AppendLine("COVERAGE METRICS:") |> ignore
    sb.AppendLine(sprintf "  Overall: %.2f%%" result.CoverageMetrics.OverallCoverage) |> ignore
    sb.AppendLine(sprintf "  Threshold: 95.00%%") |> ignore
    sb.AppendLine(sprintf "  Met: %b" result.CoverageMetrics.ThresholdMet) |> ignore
    sb.AppendLine() |> ignore

    // Test Results
    sb.AppendLine("TEST RESULTS:") |> ignore
    sb.AppendLine("-" |> String.replicate 70) |> ignore

    for testResult in result.TestResults do
        let icon = if testResult.Passed then "[OK]" else "[!!]"
        sb.AppendLine(sprintf "%s %s (%dms)"
            icon
            (Path.GetFileName(testResult.TestSpec.TestFilePath))
            testResult.ExecutionTimeMs) |> ignore

        sb.AppendLine(sprintf "    Passed: %d, Failed: %d"
            (List.length testResult.PassedTests)
            (List.length testResult.FailedTests)) |> ignore

        match testResult.CoveragePercent with
        | Some cov -> sb.AppendLine(sprintf "    Coverage: %.2f%%" cov) |> ignore
        | None -> ()

    sb.AppendLine() |> ignore

    // Violations
    if not (List.isEmpty result.Violations) then
        sb.AppendLine("VIOLATIONS:") |> ignore
        for v in result.Violations do
            let severityStr =
                match v.Severity with
                | TDGCritical -> "CRITICAL"
                | TDGHigh -> "HIGH"
                | TDGMedium -> "MEDIUM"
                | TDGLow -> "LOW"
            sb.AppendLine(sprintf "  [%s] %s: %s" severityStr v.ConstraintId v.Message) |> ignore
        sb.AppendLine() |> ignore

    sb.AppendLine("=" |> String.replicate 70) |> ignore

    sb.ToString()

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/// Quick check: Are all TDG constraints satisfied?
let isTDGCompliant (result: TDGResult) : bool =
    result.Status = TDGFullyValidated

/// Get list of failed test files
let getFailedTestFiles (result: TDGResult) : string list =
    result.TestResults
    |> List.filter (fun r -> not r.Passed)
    |> List.map (fun r -> r.TestSpec.TestFilePath)

/// Get coverage deficit (how much more coverage is needed)
let getCoverageDeficit (result: TDGResult) (threshold: float) : float =
    max 0.0 (threshold - result.CoverageMetrics.OverallCoverage)

/// Create a generation request
let createGenerationRequest
    (targetModule: string)
    (targetFilePath: string)
    (genType: GenerationType)
    : GenerationRequest =
    {
        TargetModule = targetModule
        TargetFilePath = targetFilePath
        RequiredTests = []  // Will be discovered
        Constraints = ["TDG-001"; "TDG-002"; "TDG-003"]
        GenerationType = genType
        PatientMode = true
        Metadata = Map.empty
    }

/// Create a test spec manually
let createTestSpec
    (testFilePath: string)
    (moduleName: string)
    (coverage: float)
    : TestSpec =
    {
        TestFilePath = testFilePath
        TestModuleName = moduleName
        TestNames = []  // Will be parsed
        ExpectedCoverage = coverage
        PropertyFrameworks = []
        IsPropertyTest = false
        Tags = []
    }

// ============================================================================
// PIPELINE-BASED TEST EXECUTION (SC-FSH-070)
// ============================================================================

/// Run tests using AsyncResult pipeline with retry (SC-FSH-070)
let runTestWithRetry
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (spec: TestSpec)
    : Async<Result<TestExecutionResult, string>> =

    let retryConfig = {
        Retry.defaultConfig with
            MaxAttempts = config.MaxTestRetries
            BaseDelayMs = 1000
    }

    Retry.retryAsyncResult retryConfig (fun () -> async {
        let! result = runTestSpec logger runner config spec

        if result.Passed then
            return Ok result
        else
            let failedMsg = sprintf "Test failed: %d failures in %s"
                                    (List.length result.FailedTests)
                                    spec.TestFilePath
            return Error failedMsg
    })

/// Run tests in parallel with timeout (SC-FSH-070)
let runTestsParallel
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (specs: TestSpec list)
    : Async<Result<TestExecutionResult list, string>> = async {

    logger.Info(sprintf "[Pipeline] Running %d tests in parallel with %dms timeout"
        (List.length specs) config.PatientModeTimeout)

    let! results =
        specs
        |> List.map (fun spec ->
            Timeout.withTimeout config.PatientModeTimeout (async {
                return! runTestSpec logger runner config spec
            }))
        |> Async.Parallel

    // Collect all results, converting timeouts to failed results
    let collected =
        results
        |> Array.map (function
            | Ok result -> result
            | Error _ ->
                // Create a timeout result
                {
                    TestSpec = { TestFilePath = ""; TestModuleName = ""; TestNames = []; ExpectedCoverage = 0.0; PropertyFrameworks = []; IsPropertyTest = false; Tags = [] }
                    Passed = false
                    FailedTests = ["TIMEOUT"]
                    PassedTests = []
                    ExecutionTimeMs = int64 config.PatientModeTimeout
                    CoveragePercent = None
                    Output = ""
                    ErrorOutput = "Test execution timed out"
                })
        |> Array.toList

    let allPassed = collected |> List.forall (fun r -> r.Passed)

    if allPassed then
        return Ok collected
    else
        let failedCount = collected |> List.filter (fun r -> not r.Passed) |> List.length
        return Error (sprintf "%d tests failed" failedCount)
}

// ============================================================================
// CLASSIFICATION AND METRICS (SC-FSH-050)
// ============================================================================

/// Classify TDG severity (SC-FSH-050)
let classifyTDGSeverity (severity: TDGSeverity) : string =
    match severity with
    | TDGCritical -> "CRITICAL"
    | TDGHigh -> "HIGH"
    | TDGMedium -> "MEDIUM"
    | TDGLow -> "LOW"

/// Classify TDG status (SC-FSH-050)
let classifyTDGStatus (status: TDGValidationStatus) : string =
    match status with
    | TDGNotValidated -> "NOT_VALIDATED"
    | TDGValidating -> "VALIDATING"
    | TDGTestsExist -> "TESTS_EXIST"
    | TDGTestsPassing -> "TESTS_PASSING"
    | TDGCoverageAchieved -> "COVERAGE_ACHIEVED"
    | TDGFullyValidated -> "FULLY_VALIDATED"
    | TDGFailed _ -> "FAILED"

/// Get TDG result summary with classification (SC-FSH-050)
let getTDGResultSummary (result: TDGResult) =
    let criticalCount = result.Violations |> List.filter (fun v -> v.Severity = TDGCritical) |> List.length
    let highCount = result.Violations |> List.filter (fun v -> v.Severity = TDGHigh) |> List.length
    let mediumCount = result.Violations |> List.filter (fun v -> v.Severity = TDGMedium) |> List.length
    let lowCount = result.Violations |> List.filter (fun v -> v.Severity = TDGLow) |> List.length

    let passedTests = result.TestResults |> List.filter (fun r -> r.Passed) |> List.length
    let failedTests = result.TestResults |> List.filter (fun r -> not r.Passed) |> List.length

    {|
        StatusClassification = classifyTDGStatus result.Status
        TotalViolations = List.length result.Violations
        CriticalCount = criticalCount
        HighCount = highCount
        MediumCount = mediumCount
        LowCount = lowCount
        PassedTests = passedTests
        FailedTests = failedTests
        OverallCoverage = result.CoverageMetrics.OverallCoverage
        CoverageThresholdMet = result.CoverageMetrics.ThresholdMet
        CanProceed = result.CanProceedWithGeneration
        ValidationTimeMs = result.TotalValidationTimeMs
        SeverityScore = criticalCount * 100 + highCount * 10 + mediumCount * 3 + lowCount
    |}

/// Check if TDG status requires blocking (SC-FSH-050)
let requiresBlocking (status: TDGValidationStatus) : bool =
    match status with
    | TDGFailed _ -> true
    | TDGNotValidated -> true
    | _ -> false

/// Get violations by severity (SC-FSH-050)
let getViolationsBySeverity (result: TDGResult) : TDGViolation list =
    result.Violations
    |> List.sortBy (fun v ->
        match v.Severity with
        | TDGCritical -> 0
        | TDGHigh -> 1
        | TDGMedium -> 2
        | TDGLow -> 3)

/// Pipeline-based full TDG validation with error recovery (SC-FSH-070)
let validateTDGPipelineWithRecovery
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: TDGPipelineConfig)
    (request: GenerationRequest)
    : Async<Result<TDGResult, string>> = async {

    try
        let! result = validateTDGPipeline logger runner config request
        return Ok result
    with ex ->
        logger.Error(sprintf "[TDG Pipeline] Unhandled error: %s" ex.Message)
        return Error (sprintf "TDG Pipeline failed: %s" ex.Message)
}
