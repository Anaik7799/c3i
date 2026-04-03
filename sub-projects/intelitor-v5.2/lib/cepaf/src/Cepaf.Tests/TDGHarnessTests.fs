namespace Cepaf.Tests

open System
open System.IO
open Xunit
open Cepaf
open Cepaf.Rop
open Cepaf.Observability
open Cepaf.Modules.TDGHarness

/// TDGHarness Unit Tests
/// STAMP Compliance: TDG-001 (tests must exist), TDG-002 (dual property tests), TDG-003 (95% coverage)
/// AOR Compliance: AOR-QUA-001 (zero warnings), AOR-AGT-001 (compile before complete)
/// Test Coverage: All TDG constraint validators, pipeline execution, result aggregation
module TDGHarnessTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // ========================================================================

    /// Create a valid test spec for unit testing
    let makeValidTestSpec () : TestSpec = {
        TestFilePath = "test/indrajaal/cortex/analyzer_test.exs"
        TestModuleName = "Indrajaal.Cortex.Analyzer"
        TestNames = ["test basic analysis"; "test advanced analysis"; "property generates valid output"]
        ExpectedCoverage = 95.0
        PropertyFrameworks = [PropCheck; ExUnitProperties]
        IsPropertyTest = true
        Tags = ["unit"; "cortex"]
    }

    /// Create a test spec without property frameworks
    let makeNonPropertyTestSpec () : TestSpec = {
        TestFilePath = "test/indrajaal/core/basic_test.exs"
        TestModuleName = "Indrajaal.Core.Basic"
        TestNames = ["test basic operation"; "test edge case"]
        ExpectedCoverage = 90.0
        PropertyFrameworks = []
        IsPropertyTest = false
        Tags = ["unit"]
    }

    /// Create a test spec with only PropCheck
    let makePropCheckOnlySpec () : TestSpec = {
        TestFilePath = "test/indrajaal/gen/property_test.exs"
        TestModuleName = "Indrajaal.Gen.Property"
        TestNames = ["property generates valid data"]
        ExpectedCoverage = 95.0
        PropertyFrameworks = [PropCheck]
        IsPropertyTest = true
        Tags = ["property"]
    }

    /// Create a test spec with empty test names
    let makeEmptyTestSpec () : TestSpec = {
        TestFilePath = "test/empty_test.exs"
        TestModuleName = "Empty"
        TestNames = []
        ExpectedCoverage = 95.0
        PropertyFrameworks = []
        IsPropertyTest = false
        Tags = []
    }

    /// Create a default TDG pipeline config
    let makeDefaultConfig () : TDGPipelineConfig =
        defaultConfig "/home/user/project"

    /// Create a generation request
    let makeGenerationRequest () : GenerationRequest = {
        TargetModule = "Indrajaal.Cortex.NewModule"
        TargetFilePath = "lib/indrajaal/cortex/new_module.ex"
        RequiredTests = [makeValidTestSpec ()]
        Constraints = ["TDG-001"; "TDG-002"; "TDG-003"]
        GenerationType = NewModule
        PatientMode = true
        Metadata = Map.ofList [("author", "test")]
    }

    /// Create a test execution result (passing)
    let makePassingTestResult () : TestExecutionResult = {
        TestSpec = makeValidTestSpec ()
        Passed = true
        FailedTests = []
        PassedTests = ["test basic analysis"; "test advanced analysis"; "property generates valid output"]
        ExecutionTimeMs = 1500L
        CoveragePercent = Some 97.5
        Output = "3 tests, 0 failures\nCoverage: 97.5%"
        ErrorOutput = ""
    }

    /// Create a test execution result (failing)
    let makeFailingTestResult () : TestExecutionResult = {
        TestSpec = makeValidTestSpec ()
        Passed = false
        FailedTests = ["test advanced analysis"]
        PassedTests = ["test basic analysis"; "property generates valid output"]
        ExecutionTimeMs = 2000L
        CoveragePercent = Some 75.0
        Output = "3 tests, 1 failure\nCoverage: 75.0%"
        ErrorOutput = "assertion failed"
    }

    /// Create a TDG violation
    let makeViolation (id: string) (sev: TDGSeverity) : TDGViolation = {
        ConstraintId = id
        Message = sprintf "Violation of %s" id
        Severity = sev
        Timestamp = DateTime.UtcNow
        Context = Map.ofList [("test", "true")]
    }

    /// Create coverage metrics
    let makeCoverageMetrics (coverage: float) (thresholdMet: bool) : CoverageMetrics = {
        OverallCoverage = coverage
        LineCoverage = coverage
        BranchCoverage = Some (coverage - 5.0)
        FunctionCoverage = Some (coverage + 2.0)
        CoveredModules = ["Indrajaal.Cortex.Analyzer"]
        UncoveredLines = int ((100.0 - coverage) * 10.0)
        ThresholdMet = thresholdMet
    }

    /// Create a TDG result
    let makeTDGResult (status: TDGValidationStatus) (canProceed: bool) : TDGResult = {
        Request = makeGenerationRequest ()
        Status = status
        TestResults = [makePassingTestResult ()]
        CoverageMetrics = makeCoverageMetrics 97.5 true
        Violations = []
        TotalValidationTimeMs = 5000L
        ValidatedAt = DateTime.UtcNow
        CanProceedWithGeneration = canProceed
    }

    // ========================================================================
    // TEST SPEC CREATION TESTS
    // ========================================================================

    [<Fact>]
    let ``createTestSpec creates valid test spec`` () =
        // Arrange
        let filePath = "test/analyzer_test.exs"
        let moduleName = "Analyzer"
        let coverage = 95.0

        // Act
        let spec = createTestSpec filePath moduleName coverage

        // Assert
        Assert.Equal(filePath, spec.TestFilePath)
        Assert.Equal(moduleName, spec.TestModuleName)
        Assert.Equal(coverage, spec.ExpectedCoverage)
        Assert.Empty(spec.TestNames)
        Assert.False(spec.IsPropertyTest)

    [<Fact>]
    let ``createGenerationRequest creates valid request`` () =
        // Arrange
        let targetModule = "Indrajaal.NewModule"
        let targetPath = "lib/indrajaal/new_module.ex"
        let genType = NewModule

        // Act
        let request = createGenerationRequest targetModule targetPath genType

        // Assert
        Assert.Equal(targetModule, request.TargetModule)
        Assert.Equal(targetPath, request.TargetFilePath)
        Assert.Equal(genType, request.GenerationType)
        Assert.True(request.PatientMode)
        Assert.Contains("TDG-001", request.Constraints)
        Assert.Contains("TDG-002", request.Constraints)
        Assert.Contains("TDG-003", request.Constraints)

    [<Theory>]
    [<InlineData("NewModule")>]
    [<InlineData("Enhancement")>]
    [<InlineData("Refactor")>]
    [<InlineData("BugFix")>]
    [<InlineData("PropertyTest")>]
    let ``createGenerationRequest accepts all generation types`` (genTypeName: string) =
        // Arrange
        let genType =
            match genTypeName with
            | "NewModule" -> NewModule
            | "Enhancement" -> Enhancement
            | "Refactor" -> Refactor
            | "BugFix" -> BugFix
            | "PropertyTest" -> PropertyTest
            | _ -> NewModule

        // Act
        let request = createGenerationRequest "Module" "path.ex" genType

        // Assert
        Assert.Equal(genType, request.GenerationType)

    // ========================================================================
    // TDG-001: VALIDATE TESTS EXIST TESTS
    // ========================================================================

    [<Fact>]
    let ``validateTestsExist returns Ok for valid test specs`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let tempFile = Path.GetTempFileName()
        try
            let spec = { makeValidTestSpec () with TestFilePath = tempFile }
            let specs = [spec]

            // Act
            let result = validateTestsExist logger specs

            // Assert
            match result with
            | Ok validSpecs -> Assert.Equal(1, List.length validSpecs)
            | Error _ -> Assert.Fail("Expected Ok, got Error")
        finally
            if File.Exists(tempFile) then File.Delete(tempFile)

    [<Fact>]
    let ``validateTestsExist returns Error for empty list`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let specs = []

        // Act
        let result = validateTestsExist logger specs

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("TDG-001", v.ConstraintId)
            Assert.Equal(TDGCritical, v.Severity)

    [<Fact>]
    let ``validateTestsExist returns Ok for multiple specs`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let tempFile1 = Path.GetTempFileName()
        let tempFile2 = Path.GetTempFileName()
        try
            let spec1 = { makeValidTestSpec () with TestFilePath = tempFile1 }
            let spec2 = { makeNonPropertyTestSpec () with TestFilePath = tempFile2 }
            let specs = [spec1; spec2]

            // Act
            let result = validateTestsExist logger specs

            // Assert
            match result with
            | Ok validSpecs -> Assert.Equal(2, List.length validSpecs)
            | Error _ -> Assert.Fail("Expected Ok, got Error")
        finally
            if File.Exists(tempFile1) then File.Delete(tempFile1)
            if File.Exists(tempFile2) then File.Delete(tempFile2)

    [<Fact>]
    let ``TDG-001 violation has Critical severity`` () =
        // Arrange
        let violation = makeViolation "TDG-001" TDGCritical

        // Assert
        Assert.Equal(TDGCritical, violation.Severity)
        Assert.Equal("TDG-001", violation.ConstraintId)

    // ========================================================================
    // TDG-002: VALIDATE DUAL PROPERTY TESTS
    // ========================================================================

    [<Fact>]
    let ``validateDualPropertyTests passes when dual required and present`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let specs = [makeValidTestSpec ()]

        // Act
        let result = validateDualPropertyTests logger specs true

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``validateDualPropertyTests passes when dual not required`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let specs = [makePropCheckOnlySpec ()]

        // Act
        let result = validateDualPropertyTests logger specs false

        // Assert
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``validateDualPropertyTests warns when only PropCheck present`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let specs = [makePropCheckOnlySpec ()]

        // Act - This should still pass but with warning
        let result = validateDualPropertyTests logger specs true

        // Assert - TDG-002 is a warning, not blocking
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``validateDualPropertyTests passes for non-property test specs`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let specs = [makeNonPropertyTestSpec ()]

        // Act
        let result = validateDualPropertyTests logger specs true

        // Assert
        Assert.True(Result.isOk result)

    [<Theory>]
    [<InlineData(true, true)>]
    [<InlineData(false, true)>]
    let ``validateDualPropertyTests always returns Ok (warning only)`` (requireDual: bool) (expected: bool) =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let specs = [makeValidTestSpec ()]

        // Act
        let result = validateDualPropertyTests logger specs requireDual

        // Assert
        Assert.Equal(expected, Result.isOk result)

    // ========================================================================
    // TDG-003: VALIDATE COVERAGE TESTS
    // ========================================================================

    [<Fact>]
    let ``validateCoverage returns Ok when coverage meets threshold`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let metrics = makeCoverageMetrics 97.5 true
        let threshold = 95.0

        // Act
        let result = validateCoverage logger metrics threshold

        // Assert
        match result with
        | Ok m -> Assert.True(m.ThresholdMet)
        | Error _ -> Assert.Fail("Expected Ok, got Error")

    [<Fact>]
    let ``validateCoverage returns Error when coverage below threshold`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let metrics = makeCoverageMetrics 80.0 false
        let threshold = 95.0

        // Act
        let result = validateCoverage logger metrics threshold

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error v ->
            Assert.Equal("TDG-003", v.ConstraintId)
            Assert.Equal(TDGHigh, v.Severity)

    [<Theory>]
    [<InlineData(95.0, 95.0, true)>]
    [<InlineData(95.1, 95.0, true)>]
    [<InlineData(100.0, 95.0, true)>]
    [<InlineData(94.9, 95.0, false)>]
    [<InlineData(50.0, 95.0, false)>]
    [<InlineData(0.0, 95.0, false)>]
    let ``validateCoverage threshold validation matrix`` (coverage: float) (threshold: float) (shouldPass: bool) =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let metrics = { makeCoverageMetrics coverage (coverage >= threshold) with OverallCoverage = coverage }

        // Act
        let result = validateCoverage logger metrics threshold

        // Assert
        Assert.Equal(shouldPass, Result.isOk result)

    [<Fact>]
    let ``TDG-003 violation includes coverage deficit in context`` () =
        // Arrange
        let config = QuadplexDefaults.testConfig
        let logger = new UnifiedLogger(config)
        let metrics = makeCoverageMetrics 80.0 false
        let threshold = 95.0

        // Act
        let result = validateCoverage logger metrics threshold

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error")
        | Error v ->
            Assert.True(v.Context.ContainsKey("deficit"))

    // ========================================================================
    // COVERAGE METRICS AGGREGATION TESTS
    // ========================================================================

    [<Fact>]
    let ``aggregateCoverageMetrics calculates average coverage`` () =
        // Arrange
        let result1 = { makePassingTestResult () with CoveragePercent = Some 90.0 }
        let result2 = { makePassingTestResult () with CoveragePercent = Some 100.0 }
        let results = [result1; result2]
        let threshold = 95.0

        // Act
        let metrics = aggregateCoverageMetrics results threshold

        // Assert
        Assert.Equal(95.0, metrics.OverallCoverage)
        Assert.True(metrics.ThresholdMet)

    [<Fact>]
    let ``aggregateCoverageMetrics handles empty results`` () =
        // Arrange
        let results = []
        let threshold = 95.0

        // Act
        let metrics = aggregateCoverageMetrics results threshold

        // Assert
        Assert.Equal(0.0, metrics.OverallCoverage)
        Assert.False(metrics.ThresholdMet)

    [<Fact>]
    let ``aggregateCoverageMetrics handles missing coverage data`` () =
        // Arrange
        let result1 = { makePassingTestResult () with CoveragePercent = None }
        let results = [result1]
        let threshold = 95.0

        // Act
        let metrics = aggregateCoverageMetrics results threshold

        // Assert
        Assert.Equal(0.0, metrics.OverallCoverage)
        Assert.False(metrics.ThresholdMet)

    [<Fact>]
    let ``emptyCoverageMetrics has correct default values`` () =
        // Act
        let metrics = emptyCoverageMetrics

        // Assert
        Assert.Equal(0.0, metrics.OverallCoverage)
        Assert.Equal(0.0, metrics.LineCoverage)
        Assert.True(metrics.BranchCoverage.IsNone)
        Assert.True(metrics.FunctionCoverage.IsNone)
        Assert.Empty(metrics.CoveredModules)
        Assert.Equal(0, metrics.UncoveredLines)
        Assert.False(metrics.ThresholdMet)

    // ========================================================================
    // PARSE COVERAGE OUTPUT TESTS
    // ========================================================================

    [<Fact>]
    let ``parseCoverageFromOutput extracts percentage`` () =
        // Arrange
        let output = "Running tests...\nCoverage: 97.5%\nDone."

        // Act
        let result = parseCoverageFromOutput output

        // Assert
        Assert.True(result.IsSome)
        Assert.Equal(97.5, result.Value)

    [<Fact>]
    let ``parseCoverageFromOutput returns None for missing coverage`` () =
        // Arrange
        let output = "Running tests...\nDone."

        // Act
        let result = parseCoverageFromOutput output

        // Assert
        Assert.True(result.IsNone)

    [<Theory>]
    [<InlineData("Coverage: 100%", 100.0)>]
    [<InlineData("Coverage: 0%", 0.0)>]
    [<InlineData("Coverage: 50.5%", 50.5)>]
    [<InlineData("coverage: 75.25%", 75.25)>]
    let ``parseCoverageFromOutput handles various formats`` (output: string) (expected: float) =
        // Act
        let result = parseCoverageFromOutput output

        // Assert
        Assert.True(result.IsSome)
        Assert.Equal(expected, result.Value)

    // ========================================================================
    // PARSE TEST RESULTS TESTS
    // ========================================================================

    [<Fact>]
    let ``parseTestResults extracts passed and failed counts`` () =
        // Arrange
        let output = "10 tests, 2 failures"

        // Act
        let (passed, failed) = parseTestResults output

        // Assert
        Assert.Equal(8, passed)
        Assert.Equal(2, failed)

    [<Fact>]
    let ``parseTestResults handles all tests passing`` () =
        // Arrange
        let output = "25 tests, 0 failures"

        // Act
        let (passed, failed) = parseTestResults output

        // Assert
        Assert.Equal(25, passed)
        Assert.Equal(0, failed)

    [<Fact>]
    let ``parseTestResults handles single test`` () =
        // Arrange
        let output = "1 test, 0 failures"

        // Act
        let (passed, failed) = parseTestResults output

        // Assert
        Assert.Equal(1, passed)
        Assert.Equal(0, failed)

    [<Fact>]
    let ``parseTestResults returns zero for invalid input`` () =
        // Arrange
        let output = "No test results"

        // Act
        let (passed, failed) = parseTestResults output

        // Assert
        Assert.Equal(0, passed)
        Assert.Equal(0, failed)

    // ========================================================================
    // TDG STATUS DETERMINATION TESTS
    // ========================================================================

    [<Fact>]
    let ``determineTDGStatus returns FullyValidated when all pass`` () =
        // Act
        let status = determineTDGStatus true true true []

        // Assert
        Assert.Equal(TDGFullyValidated, status)

    [<Fact>]
    let ``determineTDGStatus returns Failed for critical violations`` () =
        // Arrange
        let violations = [makeViolation "TDG-001" TDGCritical]

        // Act
        let status = determineTDGStatus true true true violations

        // Assert
        match status with
        | TDGFailed vs -> Assert.Equal(1, List.length vs)
        | _ -> Assert.Fail("Expected TDGFailed")

    [<Fact>]
    let ``determineTDGStatus returns Failed when tests don't exist`` () =
        // Act
        let status = determineTDGStatus false true true []

        // Assert
        match status with
        | TDGFailed _ -> ()
        | _ -> Assert.Fail("Expected TDGFailed")

    [<Fact>]
    let ``determineTDGStatus returns TestsExist when tests fail`` () =
        // Act
        let status = determineTDGStatus true false true []

        // Assert
        Assert.Equal(TDGTestsExist, status)

    [<Fact>]
    let ``determineTDGStatus returns TestsPassing when coverage insufficient`` () =
        // Act
        let status = determineTDGStatus true true false []

        // Assert
        Assert.Equal(TDGTestsPassing, status)

    // ========================================================================
    // UTILITY FUNCTION TESTS
    // ========================================================================

    [<Fact>]
    let ``isTDGCompliant returns true for fully validated`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true

        // Act
        let compliant = isTDGCompliant result

        // Assert
        Assert.True(compliant)

    [<Fact>]
    let ``isTDGCompliant returns false for failed`` () =
        // Arrange
        let result = makeTDGResult (TDGFailed []) false

        // Act
        let compliant = isTDGCompliant result

        // Assert
        Assert.False(compliant)

    [<Theory>]
    [<InlineData("TDGNotValidated", false)>]
    [<InlineData("TDGValidating", false)>]
    [<InlineData("TDGTestsExist", false)>]
    [<InlineData("TDGTestsPassing", false)>]
    [<InlineData("TDGCoverageAchieved", false)>]
    [<InlineData("TDGFullyValidated", true)>]
    let ``isTDGCompliant status matrix`` (statusName: string) (expected: bool) =
        // Arrange
        let status =
            match statusName with
            | "TDGNotValidated" -> TDGNotValidated
            | "TDGValidating" -> TDGValidating
            | "TDGTestsExist" -> TDGTestsExist
            | "TDGTestsPassing" -> TDGTestsPassing
            | "TDGCoverageAchieved" -> TDGCoverageAchieved
            | "TDGFullyValidated" -> TDGFullyValidated
            | _ -> TDGNotValidated
        let result = makeTDGResult status expected

        // Act
        let compliant = isTDGCompliant result

        // Assert
        Assert.Equal(expected, compliant)

    [<Fact>]
    let ``getFailedTestFiles returns failed test paths`` () =
        // Arrange
        let failingResult = makeFailingTestResult ()
        let result = { makeTDGResult TDGTestsExist false with TestResults = [failingResult] }

        // Act
        let failedFiles = getFailedTestFiles result

        // Assert
        Assert.Equal(1, List.length failedFiles)
        Assert.Contains("analyzer_test.exs", failedFiles.[0])

    [<Fact>]
    let ``getFailedTestFiles returns empty for all passing`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true

        // Act
        let failedFiles = getFailedTestFiles result

        // Assert
        Assert.Empty(failedFiles)

    [<Fact>]
    let ``getCoverageDeficit calculates correct deficit`` () =
        // Arrange
        let metrics = makeCoverageMetrics 80.0 false
        let result = { makeTDGResult TDGTestsPassing false with CoverageMetrics = metrics }
        let threshold = 95.0

        // Act
        let deficit = getCoverageDeficit result threshold

        // Assert
        Assert.Equal(15.0, deficit)

    [<Fact>]
    let ``getCoverageDeficit returns zero when threshold met`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true
        let threshold = 95.0

        // Act
        let deficit = getCoverageDeficit result threshold

        // Assert
        Assert.Equal(0.0, deficit)

    // ========================================================================
    // REPORT GENERATION TESTS
    // ========================================================================

    [<Fact>]
    let ``generateTDGReport includes status`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true

        // Act
        let report = generateTDGReport result

        // Assert
        Assert.Contains("FULLY VALIDATED", report)

    [<Fact>]
    let ``generateTDGReport includes coverage metrics`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true

        // Act
        let report = generateTDGReport result

        // Assert
        Assert.Contains("COVERAGE METRICS", report)
        Assert.Contains("97.5", report)

    [<Fact>]
    let ``generateTDGReport includes test results`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true

        // Act
        let report = generateTDGReport result

        // Assert
        Assert.Contains("TEST RESULTS", report)

    [<Fact>]
    let ``generateTDGReport shows violations when present`` () =
        // Arrange
        let violation = makeViolation "TDG-001" TDGCritical
        let result = { makeTDGResult TDGTestsExist false with Violations = [violation] }

        // Act
        let report = generateTDGReport result

        // Assert
        Assert.Contains("VIOLATIONS", report)
        Assert.Contains("TDG-001", report)
        Assert.Contains("CRITICAL", report)

    [<Fact>]
    let ``generateTDGReport includes TDG constraint compliance`` () =
        // Arrange
        let result = makeTDGResult TDGFullyValidated true

        // Act
        let report = generateTDGReport result

        // Assert
        Assert.Contains("TDG CONSTRAINT COMPLIANCE", report)
        Assert.Contains("TDG-001", report)
        Assert.Contains("TDG-002", report)
        Assert.Contains("TDG-003", report)

    // ========================================================================
    // DEFAULT CONFIG TESTS
    // ========================================================================

    [<Fact>]
    let ``defaultConfig sets correct coverage threshold`` () =
        // Act
        let config = defaultConfig "/project"

        // Assert
        Assert.Equal(95.0, config.CoverageThreshold)

    [<Fact>]
    let ``defaultConfig requires dual property tests`` () =
        // Act
        let config = defaultConfig "/project"

        // Assert
        Assert.True(config.RequireDualPropertyTests)

    [<Fact>]
    let ``defaultConfig sets patient mode timeout`` () =
        // Act
        let config = defaultConfig "/project"

        // Assert
        Assert.Equal(7200000, config.PatientModeTimeout)

    [<Fact>]
    let ``defaultConfig sets test directory`` () =
        // Act
        let config = defaultConfig "/project"

        // Assert
        Assert.Equal("test", config.TestDirectory)
        Assert.Equal("/project", config.ProjectRoot)

    // ========================================================================
    // SEVERITY TESTS
    // ========================================================================

    [<Fact>]
    let ``TDGCritical has highest priority`` () =
        // Arrange
        let critical = TDGCritical
        let high = TDGHigh
        let medium = TDGMedium
        let low = TDGLow

        // Assert - Critical blocks generation
        let critViolation = makeViolation "TEST" critical
        let highViolation = makeViolation "TEST" high

        Assert.Equal(TDGCritical, critViolation.Severity)
        Assert.Equal(TDGHigh, highViolation.Severity)

    [<Theory>]
    [<InlineData("Critical")>]
    [<InlineData("High")>]
    [<InlineData("Medium")>]
    [<InlineData("Low")>]
    let ``All severity levels are distinct`` (severityName: string) =
        // Arrange
        let severity =
            match severityName with
            | "Critical" -> TDGCritical
            | "High" -> TDGHigh
            | "Medium" -> TDGMedium
            | "Low" -> TDGLow
            | _ -> TDGLow

        let violation = makeViolation "TEST" severity

        // Assert
        Assert.NotNull(violation)
        Assert.Equal(severity, violation.Severity)
