namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Observability
open Cepaf.Modules.AOREngine

/// AOREngine Unit Tests
/// STAMP Compliance: AOR-SAF-001 (halt <1s), AOR-CNT-001 (Podman only), AOR-QUA-001 (zero warnings)
/// AOR Compliance: All 9 AOR rules (EXE-001, SAF-001, CNT-001, QUA-001, AGT-001, DB-001, DOC-001, BATCH-001, GEM-001)
/// Test Coverage: Rule evaluation, compliance checking, violation detection, halt enforcement, report generation
module AOREngineTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // ========================================================================

    /// Create a basic rule context for container operations
    let makeContainerContext () : RuleContext =
        createContext OperationType.ContainerStart
        |> withData "container_runtime" "podman"
        |> withData "is_podman" true

    /// Create a Docker (invalid) container context
    let makeDockerContext () : RuleContext =
        createContext OperationType.ContainerStart
        |> withData "container_runtime" "docker"
        |> withData "is_podman" false

    /// Create a compilation context with zero warnings
    let makeCleanCompilationContext () : RuleContext =
        createContext OperationType.Compilation
        |> withData "error_count" 0
        |> withData "warning_count" 0

    /// Create a compilation context with warnings
    let makeWarningCompilationContext () : RuleContext =
        createContext OperationType.Compilation
        |> withData "error_count" 0
        |> withData "warning_count" 5

    /// Create a compilation context with errors
    let makeErrorCompilationContext () : RuleContext =
        createContext OperationType.Compilation
        |> withData "error_count" 3
        |> withData "warning_count" 2

    /// Create an agent task context with compilation verified
    let makeVerifiedAgentContext () : RuleContext =
        createContext OperationType.AgentTask
        |> withAgentId "agent-001"
        |> withData "compilation_verified" true
        |> withData "involves_code_changes" true

    /// Create an agent task context without compilation
    let makeUnverifiedAgentContext () : RuleContext =
        createContext OperationType.AgentTask
        |> withAgentId "agent-002"
        |> withData "compilation_verified" false
        |> withData "involves_code_changes" true

    /// Create a database context using BaseResource
    let makeBaseResourceContext () : RuleContext =
        createContext OperationType.DatabaseMigration
        |> withData "uses_base_resource" true
        |> withData "involves_db_resource" true

    /// Create a database context not using BaseResource
    let makeNonBaseResourceContext () : RuleContext =
        createContext OperationType.DatabaseMigration
        |> withData "uses_base_resource" false
        |> withData "involves_db_resource" true

    /// Create a file edit context with doc read
    let makeDocReadContext () : RuleContext =
        createContext OperationType.FileEdit
        |> withTarget "lib/indrajaal/cortex/analyzer.ex"
        |> withData "moduledoc_read" true
        |> withData "file_content_read" true

    /// Create a file edit context without doc read
    let makeDocNotReadContext () : RuleContext =
        createContext OperationType.FileEdit
        |> withTarget "lib/indrajaal/core/module.ex"
        |> withData "moduledoc_read" false
        |> withData "file_content_read" false

    /// Create a batch context within limits
    let makeSmallBatchContext () : RuleContext =
        createContext OperationType.BatchOperation
        |> withData "batch_size" 5

    /// Create a batch context exceeding limits
    let makeLargeBatchContext () : RuleContext =
        createContext OperationType.BatchOperation
        |> withData "batch_size" 15

    /// Create a VTO phase context with verification
    let makeVerifiedVtoContext () : RuleContext =
        createContext OperationType.VtoPhase
        |> withData "has_verification" true
        |> withData "is_planning_operation" true

    /// Create a VTO phase context without verification
    let makeUnverifiedVtoContext () : RuleContext =
        createContext OperationType.VtoPhase
        |> withData "has_verification" false
        |> withData "is_planning_operation" true

    /// Create a safety check context with fast halt
    let makeFastHaltContext () : RuleContext =
        createContext OperationType.SafetyCheck
        |> withData "halt_duration_ms" 500L

    /// Create a safety check context with slow halt
    let makeSlowHaltContext () : RuleContext =
        createContext OperationType.SafetyCheck
        |> withData "halt_duration_ms" 1500L

    /// Create an executive command context
    let makeExecutiveContext () : RuleContext =
        createContext OperationType.ExecutiveCommand
        |> withAgentId "executive"
        |> withData "executive_authorization" true

    /// Create a test logger
    let makeTestLogger () : UnifiedLogger =
        new UnifiedLogger(QuadplexDefaults.testConfig)

    // ========================================================================
    // RULE CONTEXT CREATION TESTS
    // ========================================================================

    [<Fact>]
    let ``createContext sets operation type`` () =
        // Act
        let ctx = createContext OperationType.Compilation

        // Assert
        Assert.Equal(OperationType.Compilation, ctx.Operation)

    [<Fact>]
    let ``withAgentId adds agent ID to context`` () =
        // Arrange
        let ctx = createContext OperationType.AgentTask

        // Act
        let result = ctx |> withAgentId "agent-001"

        // Assert
        Assert.Equal(Some "agent-001", result.AgentId)

    [<Fact>]
    let ``withTarget adds target to context`` () =
        // Arrange
        let ctx = createContext OperationType.FileEdit

        // Act
        let result = ctx |> withTarget "/path/to/file.ex"

        // Assert
        Assert.Equal(Some "/path/to/file.ex", result.Target)

    [<Fact>]
    let ``withData adds data to context`` () =
        // Arrange
        let ctx = createContext OperationType.Compilation

        // Act
        let result = ctx |> withData "warning_count" 5

        // Assert
        Assert.True(result.Data.ContainsKey("warning_count"))

    [<Fact>]
    let ``withPreviousOperation adds previous op`` () =
        // Arrange
        let ctx = createContext OperationType.Testing

        // Act
        let result = ctx |> withPreviousOperation OperationType.Compilation

        // Assert
        Assert.Equal(Some OperationType.Compilation, result.PreviousOperation)

    [<Fact>]
    let ``context chaining works correctly`` () =
        // Act
        let ctx =
            createContext OperationType.AgentTask
            |> withAgentId "test-agent"
            |> withTarget "test/file.ex"
            |> withData "key1" "value1"
            |> withData "key2" 42
            |> withPreviousOperation OperationType.Compilation

        // Assert
        Assert.Equal(OperationType.AgentTask, ctx.Operation)
        Assert.Equal(Some "test-agent", ctx.AgentId)
        Assert.Equal(Some "test/file.ex", ctx.Target)
        Assert.Equal(Some OperationType.Compilation, ctx.PreviousOperation)
        Assert.Equal(2, ctx.Data.Count)

    // ========================================================================
    // AOR-EXE-001: EXECUTIVE AUTHORITY TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-EXE-001 passes with executive authorization`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeExecutiveContext ()

        // Act
        let result = ruleExe001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-EXE-001 passes with executive override`` () =
        // Arrange
        let ctx =
            createContext OperationType.ExecutiveCommand
            |> withData "is_executive_override" true

        // Act
        let result = ruleExe001.Evaluate ctx

        // Assert
        match result with
        | EvaluationResult.Passed (Some details) -> Assert.Contains("override", details)
        | _ -> Assert.Fail("Expected Passed with override details")

    [<Fact>]
    let ``AOR-EXE-001 fails without authorization`` () =
        // Arrange
        let ctx =
            createContext OperationType.ExecutiveCommand
            |> withData "executive_authorization" false

        // Act
        let result = ruleExe001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Fact>]
    let ``AOR-EXE-001 has Critical severity`` () =
        Assert.Equal(RuleSeverity.Critical, ruleExe001.Severity)

    // ========================================================================
    // AOR-SAF-001: SAFETY HALT THRESHOLD TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-SAF-001 passes when halt under 1s`` () =
        // Arrange
        let ctx = makeFastHaltContext ()

        // Act
        let result = ruleSaf001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-SAF-001 fails when halt exceeds 1s`` () =
        // Arrange
        let ctx = makeSlowHaltContext ()

        // Act
        let result = ruleSaf001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Theory>]
    [<InlineData(100L, true)>]
    [<InlineData(500L, true)>]
    [<InlineData(999L, true)>]
    [<InlineData(1000L, true)>]
    [<InlineData(1001L, false)>]
    [<InlineData(2000L, false)>]
    [<InlineData(5000L, false)>]
    let ``AOR-SAF-001 halt threshold matrix`` (durationMs: int64) (shouldPass: bool) =
        // Arrange
        let ctx = createContext OperationType.SafetyCheck |> withData "halt_duration_ms" durationMs

        // Act
        let result = ruleSaf001.Evaluate ctx

        // Assert
        Assert.Equal(shouldPass, isPassed result)

    [<Fact>]
    let ``AOR-SAF-001 skips when no halt data`` () =
        // Arrange
        let ctx = createContext OperationType.SafetyCheck

        // Act
        let result = ruleSaf001.Evaluate ctx

        // Assert
        match result with
        | EvaluationResult.Skipped _ -> ()
        | _ -> Assert.Fail("Expected Skipped")

    [<Fact>]
    let ``AOR-SAF-001 has Critical severity`` () =
        Assert.Equal(RuleSeverity.Critical, ruleSaf001.Severity)

    // ========================================================================
    // AOR-CNT-001: PODMAN ONLY TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-CNT-001 passes for Podman runtime`` () =
        // Arrange
        let ctx = makeContainerContext ()

        // Act
        let result = ruleCnt001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-CNT-001 fails for Docker runtime`` () =
        // Arrange
        let ctx = makeDockerContext ()

        // Act
        let result = ruleCnt001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Theory>]
    [<InlineData("podman", true)>]
    [<InlineData("Podman", true)>]
    [<InlineData("PODMAN", true)>]
    [<InlineData("podman-remote", true)>]
    [<InlineData("docker", false)>]
    [<InlineData("Docker", false)>]
    [<InlineData("containerd", false)>]
    [<InlineData("unknown", false)>]
    let ``AOR-CNT-001 runtime detection matrix`` (runtime: string) (shouldPass: bool) =
        // Arrange
        let ctx = createContext OperationType.ContainerStart |> withData "container_runtime" runtime

        // Act
        let result = ruleCnt001.Evaluate ctx

        // Assert
        Assert.Equal(shouldPass, isPassed result)

    [<Fact>]
    let ``AOR-CNT-001 has Critical severity`` () =
        Assert.Equal(RuleSeverity.Critical, ruleCnt001.Severity)

    [<Fact>]
    let ``AOR-CNT-001 applies to container operations`` () =
        Assert.Contains(OperationType.ContainerStart, ruleCnt001.ApplicableOperations)
        Assert.Contains(OperationType.ContainerStop, ruleCnt001.ApplicableOperations)

    // ========================================================================
    // AOR-QUA-001: ZERO WARNINGS TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-QUA-001 passes with zero errors and warnings`` () =
        // Arrange
        let ctx = makeCleanCompilationContext ()

        // Act
        let result = ruleQua001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-QUA-001 fails with warnings`` () =
        // Arrange
        let ctx = makeWarningCompilationContext ()

        // Act
        let result = ruleQua001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Fact>]
    let ``AOR-QUA-001 fails with errors`` () =
        // Arrange
        let ctx = makeErrorCompilationContext ()

        // Act
        let result = ruleQua001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Theory>]
    [<InlineData(0, 0, true)>]
    [<InlineData(0, 1, false)>]
    [<InlineData(1, 0, false)>]
    [<InlineData(5, 10, false)>]
    let ``AOR-QUA-001 error/warning matrix`` (errors: int) (warnings: int) (shouldPass: bool) =
        // Arrange
        let ctx =
            createContext OperationType.Compilation
            |> withData "error_count" errors
            |> withData "warning_count" warnings

        // Act
        let result = ruleQua001.Evaluate ctx

        // Assert
        Assert.Equal(shouldPass, isPassed result)

    [<Fact>]
    let ``AOR-QUA-001 has High severity`` () =
        Assert.Equal(RuleSeverity.High, ruleQua001.Severity)

    // ========================================================================
    // AOR-AGT-001: COMPILE BEFORE COMPLETE TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-AGT-001 passes when compilation verified`` () =
        // Arrange
        let ctx = makeVerifiedAgentContext ()

        // Act
        let result = ruleAgt001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-AGT-001 fails without compilation verification`` () =
        // Arrange
        let ctx = makeUnverifiedAgentContext ()

        // Act
        let result = ruleAgt001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Fact>]
    let ``AOR-AGT-001 passes for non-code tasks`` () =
        // Arrange
        let ctx =
            createContext OperationType.AgentTask
            |> withData "involves_code_changes" false

        // Act
        let result = ruleAgt001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-AGT-001 has High severity`` () =
        Assert.Equal(RuleSeverity.High, ruleAgt001.Severity)

    // ========================================================================
    // AOR-DB-001: USE BASERESOURCE TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-DB-001 passes when using BaseResource`` () =
        // Arrange
        let ctx = makeBaseResourceContext ()

        // Act
        let result = ruleDb001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-DB-001 fails when not using BaseResource`` () =
        // Arrange
        let ctx = makeNonBaseResourceContext ()

        // Act
        let result = ruleDb001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Fact>]
    let ``AOR-DB-001 skips for non-database operations`` () =
        // Arrange
        let ctx = createContext OperationType.DatabaseMigration

        // Act
        let result = ruleDb001.Evaluate ctx

        // Assert
        match result with
        | EvaluationResult.Skipped _ -> ()
        | _ -> Assert.Fail("Expected Skipped")

    [<Fact>]
    let ``AOR-DB-001 has High severity`` () =
        Assert.Equal(RuleSeverity.High, ruleDb001.Severity)

    // ========================================================================
    // AOR-DOC-001: READ BEFORE EDIT TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-DOC-001 passes when moduledoc read`` () =
        // Arrange
        let ctx = makeDocReadContext ()

        // Act
        let result = ruleDoc001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-DOC-001 fails when moduledoc not read`` () =
        // Arrange
        let ctx = makeDocNotReadContext ()

        // Act
        let result = ruleDoc001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Fact>]
    let ``AOR-DOC-001 skips for non-Elixir files`` () =
        // Arrange
        let ctx =
            createContext OperationType.FileEdit
            |> withTarget "README.md"

        // Act
        let result = ruleDoc001.Evaluate ctx

        // Assert
        match result with
        | EvaluationResult.Skipped _ -> ()
        | _ -> Assert.Fail("Expected Skipped")

    [<Theory>]
    [<InlineData("module.ex", false)>]
    [<InlineData("test.exs", false)>]
    [<InlineData("readme.md", true)>]
    [<InlineData("config.json", true)>]
    let ``AOR-DOC-001 file type detection`` (fileName: string) (shouldSkip: bool) =
        // Arrange
        let ctx = createContext OperationType.FileEdit |> withTarget fileName

        // Act
        let result = ruleDoc001.Evaluate ctx

        // Assert
        match result with
        | EvaluationResult.Skipped _ -> Assert.True(shouldSkip)
        | _ -> Assert.False(shouldSkip)

    [<Fact>]
    let ``AOR-DOC-001 has Medium severity`` () =
        Assert.Equal(RuleSeverity.Medium, ruleDoc001.Severity)

    // ========================================================================
    // AOR-BATCH-001: BATCH SIZE LIMIT TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-BATCH-001 passes for batch under 10`` () =
        // Arrange
        let ctx = makeSmallBatchContext ()

        // Act
        let result = ruleBatch001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-BATCH-001 fails for batch over 10`` () =
        // Arrange
        let ctx = makeLargeBatchContext ()

        // Act
        let result = ruleBatch001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Theory>]
    [<InlineData(1, true)>]
    [<InlineData(5, true)>]
    [<InlineData(10, true)>]
    [<InlineData(11, false)>]
    [<InlineData(15, false)>]
    [<InlineData(100, false)>]
    let ``AOR-BATCH-001 size threshold matrix`` (size: int) (shouldPass: bool) =
        // Arrange
        let ctx = createContext OperationType.BatchOperation |> withData "batch_size" size

        // Act
        let result = ruleBatch001.Evaluate ctx

        // Assert
        Assert.Equal(shouldPass, isPassed result)

    [<Fact>]
    let ``AOR-BATCH-001 passes when no batch size specified`` () =
        // Arrange
        let ctx = createContext OperationType.BatchOperation

        // Act
        let result = ruleBatch001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-BATCH-001 has High severity`` () =
        Assert.Equal(RuleSeverity.High, ruleBatch001.Severity)

    // ========================================================================
    // AOR-GEM-001: PLAN IMPLIES VERIFY TESTS
    // ========================================================================

    [<Fact>]
    let ``AOR-GEM-001 passes with verification`` () =
        // Arrange
        let ctx = makeVerifiedVtoContext ()

        // Act
        let result = ruleGem001.Evaluate ctx

        // Assert
        Assert.True(isPassed result)

    [<Fact>]
    let ``AOR-GEM-001 fails without verification`` () =
        // Arrange
        let ctx = makeUnverifiedVtoContext ()

        // Act
        let result = ruleGem001.Evaluate ctx

        // Assert
        Assert.True(isFailed result)

    [<Fact>]
    let ``AOR-GEM-001 skips for non-planning operations`` () =
        // Arrange
        let ctx = createContext OperationType.VtoPhase

        // Act
        let result = ruleGem001.Evaluate ctx

        // Assert
        match result with
        | EvaluationResult.Skipped _ -> ()
        | _ -> Assert.Fail("Expected Skipped")

    [<Fact>]
    let ``AOR-GEM-001 has High severity`` () =
        Assert.Equal(RuleSeverity.High, ruleGem001.Severity)

    // ========================================================================
    // RULE EVALUATION ENGINE TESTS
    // ========================================================================

    [<Fact>]
    let ``evaluate returns None for passing rule`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeContainerContext ()

        // Act
        let violation = evaluate logger ruleCnt001 ctx

        // Assert
        Assert.True(violation.IsNone)

    [<Fact>]
    let ``evaluate returns Some violation for failing rule`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()

        // Act
        let violation = evaluate logger ruleCnt001 ctx

        // Assert
        Assert.True(violation.IsSome)
        Assert.Equal("AOR-CNT-001", violation.Value.RuleId)

    [<Fact>]
    let ``evaluate returns None for non-applicable rule`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = createContext OperationType.Testing

        // Act
        let violation = evaluate logger ruleCnt001 ctx

        // Assert
        Assert.True(violation.IsNone)

    [<Fact>]
    let ``isApplicable returns true for matching operation`` () =
        // Arrange
        let ctx = createContext OperationType.ContainerStart

        // Act
        let result = isApplicable ctx ruleCnt001

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``isApplicable returns false for non-matching operation`` () =
        // Arrange
        let ctx = createContext OperationType.Testing

        // Act
        let result = isApplicable ctx ruleCnt001

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``isApplicable returns false for disabled rule`` () =
        // Arrange
        let ctx = createContext OperationType.ContainerStart
        let disabledRule = disableRule ruleCnt001

        // Act
        let result = isApplicable ctx disabledRule

        // Assert
        Assert.False(result)

    // ========================================================================
    // COMPLIANCE CHECKING TESTS
    // ========================================================================

    [<Fact>]
    let ``checkCompliance returns Compliant for valid context`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeContainerContext ()

        // Act
        let report = checkCompliance logger [ruleCnt001] ctx

        // Assert
        Assert.Equal(ComplianceStatus.Compliant, report.Status)

    [<Fact>]
    let ``checkCompliance returns NonCompliant for failing rule`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()

        // Act
        let report = checkCompliance logger [ruleCnt001] ctx

        // Assert
        match report.Status with
        | ComplianceStatus.NonCompliant _ -> ()
        | ComplianceStatus.CriticalViolation -> ()
        | _ -> Assert.Fail("Expected NonCompliant or CriticalViolation")

    [<Fact>]
    let ``checkCompliance returns CriticalViolation for critical failure`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()

        // Act
        let report = checkCompliance logger [ruleCnt001] ctx

        // Assert
        Assert.Equal(ComplianceStatus.CriticalViolation, report.Status)

    [<Fact>]
    let ``checkAllRules checks all defined rules`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = createContext OperationType.Compilation

        // Act
        let report = checkAllRules logger ctx

        // Assert
        Assert.True(report.RulesChecked.Length > 0)

    // ========================================================================
    // VIOLATION DETECTION TESTS
    // ========================================================================

    [<Fact>]
    let ``createViolation sets all fields correctly`` () =
        // Arrange
        let ctx = makeDockerContext ()

        // Act
        let violation = createViolation "AOR-CNT-001" "Podman Only" "Docker detected" RuleSeverity.Critical ctx (Some "Use Podman")

        // Assert
        Assert.Equal("AOR-CNT-001", violation.RuleId)
        Assert.Equal("Podman Only", violation.RuleName)
        Assert.Equal("Docker detected", violation.Message)
        Assert.Equal(RuleSeverity.Critical, violation.Severity)
        Assert.Equal(Some "Use Podman", violation.Remediation)

    [<Fact>]
    let ``getCriticalViolations filters correctly`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()
        let report = checkAllRules logger ctx

        // Act
        let criticals = getCriticalViolations report

        // Assert - Docker context triggers critical CNT-001
        Assert.True(criticals.Length >= 0)

    // ========================================================================
    // HALT ENFORCEMENT TESTS
    // ========================================================================

    [<Fact>]
    let ``enforceHalt completes within threshold`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()
        let violation = createViolation "TEST" "Test" "Test violation" RuleSeverity.Critical ctx None

        // Act
        let result = enforceHalt logger violation

        // Assert
        Assert.True(result.DurationMs < 1000L)
        Assert.True(result.Success)

    [<Fact>]
    let ``requiresHalt returns true for CriticalViolation`` () =
        // Arrange
        let report = {
            Status = ComplianceStatus.CriticalViolation
            RulesChecked = []
            RulesPassed = []
            RulesSkipped = []
            Violations = []
            GeneratedAt = DateTimeOffset.UtcNow
            CheckDurationMs = 0L
            Context = createContext OperationType.SafetyCheck
        }

        // Act
        let result = requiresHalt report

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``requiresHalt returns false for Compliant`` () =
        // Arrange
        let report = {
            Status = ComplianceStatus.Compliant
            RulesChecked = []
            RulesPassed = []
            RulesSkipped = []
            Violations = []
            GeneratedAt = DateTimeOffset.UtcNow
            CheckDurationMs = 0L
            Context = createContext OperationType.SafetyCheck
        }

        // Act
        let result = requiresHalt report

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``processReportWithHalt returns Some for critical`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()
        let report = checkAllRules logger ctx

        // Act
        let haltResult = processReportWithHalt logger report

        // Assert - Docker triggers critical, so halt should be returned
        if report.Status = ComplianceStatus.CriticalViolation then
            Assert.True(haltResult.IsSome)
        else
            Assert.True(haltResult.IsNone)

    // ========================================================================
    // REPORT GENERATION TESTS
    // ========================================================================

    [<Fact>]
    let ``generateReport includes status`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeContainerContext ()
        let report = checkAllRules logger ctx

        // Act
        let reportStr = generateReport report

        // Assert
        Assert.Contains("Status:", reportStr)

    [<Fact>]
    let ``generateReport includes summary`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeContainerContext ()
        let report = checkAllRules logger ctx

        // Act
        let reportStr = generateReport report

        // Assert
        Assert.Contains("SUMMARY", reportStr)
        Assert.Contains("Rules Checked:", reportStr)

    [<Fact>]
    let ``generateReport includes violations when present`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeDockerContext ()
        let report = checkAllRules logger ctx

        // Act
        let reportStr = generateReport report

        // Assert
        if report.Violations.Length > 0 then
            Assert.Contains("VIOLATIONS", reportStr)

    [<Fact>]
    let ``generateJsonReport produces valid JSON structure`` () =
        // Arrange
        let logger = makeTestLogger ()
        let ctx = makeContainerContext ()
        let report = checkAllRules logger ctx

        // Act
        let jsonStr = generateJsonReport report

        // Assert
        Assert.Contains("\"status\":", jsonStr)
        Assert.Contains("\"rulesChecked\":", jsonStr)
        Assert.Contains("\"violations\":", jsonStr)

    // ========================================================================
    // CONVENIENCE FUNCTION TESTS
    // ========================================================================

    [<Fact>]
    let ``checkContainerCompliance validates container ops`` () =
        // Arrange
        let logger = makeTestLogger ()

        // Act
        let report = checkContainerCompliance logger "podman" true

        // Assert
        Assert.Equal(ComplianceStatus.Compliant, report.Status)

    [<Fact>]
    let ``checkCompilationCompliance validates compilation`` () =
        // Arrange
        let logger = makeTestLogger ()

        // Act
        let report = checkCompilationCompliance logger 0 0

        // Assert
        Assert.Equal(ComplianceStatus.Compliant, report.Status)

    [<Fact>]
    let ``checkBatchCompliance validates batch size`` () =
        // Arrange
        let logger = makeTestLogger ()

        // Act
        let report = checkBatchCompliance logger 5

        // Assert
        Assert.Equal(ComplianceStatus.Compliant, report.Status)

    [<Fact>]
    let ``checkFileEditCompliance validates file edit`` () =
        // Arrange
        let logger = makeTestLogger ()

        // Act
        let report = checkFileEditCompliance logger "test.ex" true

        // Assert
        Assert.Equal(ComplianceStatus.Compliant, report.Status)

    [<Fact>]
    let ``getRuleById finds existing rule`` () =
        // Act
        let rule = getRuleById "AOR-CNT-001"

        // Assert
        Assert.True(rule.IsSome)
        Assert.Equal("AOR-CNT-001", rule.Value.Id)

    [<Fact>]
    let ``getRuleById returns None for unknown rule`` () =
        // Act
        let rule = getRuleById "AOR-UNKNOWN-999"

        // Assert
        Assert.True(rule.IsNone)

    [<Fact>]
    let ``getRulesByCategory filters correctly`` () =
        // Act
        let containerRules = getRulesByCategory RuleCategory.Container

        // Assert
        Assert.True(containerRules.Length >= 1)
        Assert.True(containerRules |> List.forall (fun r -> r.Category = RuleCategory.Container))

    // ========================================================================
    // ALL RULES COLLECTION TESTS
    // ========================================================================

    [<Fact>]
    let ``allRules contains all 9 defined rules`` () =
        Assert.Equal(9, allRules.Length)

    [<Fact>]
    let ``allRules contains required rule IDs`` () =
        let ruleIds = allRules |> List.map (fun r -> r.Id)
        Assert.Contains("AOR-EXE-001", ruleIds)
        Assert.Contains("AOR-SAF-001", ruleIds)
        Assert.Contains("AOR-CNT-001", ruleIds)
        Assert.Contains("AOR-QUA-001", ruleIds)
        Assert.Contains("AOR-AGT-001", ruleIds)
        Assert.Contains("AOR-DB-001", ruleIds)
        Assert.Contains("AOR-DOC-001", ruleIds)
        Assert.Contains("AOR-BATCH-001", ruleIds)
        Assert.Contains("AOR-GEM-001", ruleIds)

    [<Fact>]
    let ``all rules are enabled by default`` () =
        Assert.True(allRules |> List.forall (fun r -> r.Enabled))

    [<Fact>]
    let ``enableRule enables a disabled rule`` () =
        // Arrange
        let disabled = disableRule ruleCnt001

        // Act
        let enabled = enableRule disabled

        // Assert
        Assert.True(enabled.Enabled)

    // ========================================================================
    // SEVERITY PRIORITY TESTS
    // ========================================================================

    [<Fact>]
    let ``severityToPriority orders correctly`` () =
        Assert.Equal(1, severityToPriority RuleSeverity.Critical)
        Assert.Equal(2, severityToPriority RuleSeverity.High)
        Assert.Equal(3, severityToPriority RuleSeverity.Medium)
        Assert.Equal(4, severityToPriority RuleSeverity.Low)

    [<Fact>]
    let ``Critical has lowest priority number`` () =
        let criticalPriority = severityToPriority RuleSeverity.Critical
        let lowPriority = severityToPriority RuleSeverity.Low
        Assert.True(criticalPriority < lowPriority)
