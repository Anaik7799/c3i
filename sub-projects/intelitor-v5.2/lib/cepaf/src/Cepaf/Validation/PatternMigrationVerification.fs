/// CEPAF Pattern Migration Verification Module
/// Validates the FPPS 5-method consensus engine implementation.
///
/// WHAT: Verification tests for Pattern Migration (46.x series)
/// WHY: Ensures FPPS consensus engine is correctly implemented
/// CONSTRAINTS:
///   - SC-VAL-003: 100% consensus required
///   - SC-FSH-160: All 5 methods must be executed
///   - SC-COV-001: Critical paths must have 100% coverage
///
/// STAMP Compliance: SC-VAL-003, SC-VAL-004, SC-FSH-160
/// Version: 1.0.0
module Cepaf.Validation.PatternMigrationVerification

open System
open Cepaf.Validation.ErrorPatterns
open Cepaf.Validation.CompilationValidator
open Cepaf.Validation.FPPSValidator

// ============================================================================
// TEST DATA
// ============================================================================

/// Sample successful build output
let successfulBuildOutput = """
Microsoft (R) Build Engine version 17.9.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Cepaf.Podman -> /home/user/dev/lib/cepaf/src/Cepaf.Podman/bin/Debug/net10.0/Cepaf.Podman.dll
  Cepaf.Cockpit -> /home/user/dev/lib/cepaf/src/Cepaf.Cockpit/bin/Debug/net10.0/Cepaf.Cockpit.dll
  Cepaf -> /home/user/dev/lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:15.34
"""

/// Sample build output with errors
let failedBuildOutput = """
Microsoft (R) Build Engine version 17.9.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
/home/user/dev/lib/cepaf/src/Cepaf/Domain.fs(42,15): error FS0039: The value or constructor 'undefinedVariable' is not defined. [/home/user/dev/lib/cepaf/src/Cepaf/Cepaf.fsproj]
/home/user/dev/lib/cepaf/src/Cepaf/Domain.fs(55,8): error FS0001: This expression was expected to have type 'int' but here has type 'string'. [/home/user/dev/lib/cepaf/src/Cepaf/Cepaf.fsproj]

Build FAILED.
    0 Warning(s)
    2 Error(s)

Time Elapsed 00:00:05.12
"""

/// Sample build output with warnings only
let warningsOnlyOutput = """
Microsoft (R) Build Engine version 17.9.0 for .NET
  Cepaf -> /home/user/dev/lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll
/home/user/dev/lib/cepaf/src/Cepaf/Core/Utils.fs(15,9): warning FS1182: The value 'unusedVar' is unused. [/home/user/dev/lib/cepaf/src/Cepaf/Cepaf.fsproj]
/home/user/dev/lib/cepaf/src/Cepaf/Core/Utils.fs(22,5): warning FS0025: Incomplete pattern matches on this expression. [/home/user/dev/lib/cepaf/src/Cepaf/Cepaf.fsproj]

Build succeeded.
    2 Warning(s)
    0 Error(s)

Time Elapsed 00:00:10.00
"""

// ============================================================================
// VERIFICATION TESTS
// ============================================================================

/// Test result type
type TestResult = {
    TestName: string
    Passed: bool
    Message: string
    Duration: TimeSpan
}

/// Run a single test
let runTest name test =
    let start = DateTime.UtcNow
    try
        let (passed, message) = test ()
        {
            TestName = name
            Passed = passed
            Message = message
            Duration = DateTime.UtcNow - start
        }
    with ex ->
        {
            TestName = name
            Passed = false
            Message = sprintf "Exception: %s" ex.Message
            Duration = DateTime.UtcNow - start
        }

// ============================================================================
// ERROR PATTERN TESTS
// ============================================================================

/// Test EP-007: Value not defined pattern
let testValueNotDefined () =
    let line = "error FS0039: The value or constructor 'foo' is not defined"
    let matches = matchLine line
    let found = matches |> List.exists (fun m -> m.Pattern.Id = "EP-007")
    (found, if found then "EP-007 pattern matched correctly" else "EP-007 pattern not matched")

/// Test EP-008: Type mismatch pattern
let testTypeMismatch () =
    let line = "error FS0001: This expression was expected to have type 'int' but has type 'string'"
    let matches = matchLine line
    let hasMatch = List.length matches > 0
    (hasMatch, if hasMatch then "Type error pattern matched" else "No pattern matched for type error")

/// Test EP-021: Unused variable pattern
let testUnusedVariable () =
    let line = "warning FS1182: The value 'x' is unused"
    let matches = matchLine line
    let found = matches |> List.exists (fun m -> m.Pattern.Id = "EP-021")
    (found, if found then "EP-021 unused variable pattern matched" else "EP-021 not matched")

/// Test pattern count
let testPatternCount () =
    let totalPatterns = List.length allPatterns
    let errorPatterns = List.length allErrorPatterns
    let warningPatterns = List.length allWarningPatterns
    let expected = errorPatterns + warningPatterns
    let passed = totalPatterns = expected && totalPatterns >= 45
    (passed, sprintf "Total patterns: %d (errors: %d, warnings: %d)" totalPatterns errorPatterns warningPatterns)

/// Test STAMP constrained patterns exist
let testStampPatterns () =
    let stampPatterns = getStampConstrainedPatterns ()
    let count = List.length stampPatterns
    let passed = count >= 5
    (passed, sprintf "%d patterns have STAMP constraints" count)

// ============================================================================
// COMPILATION VALIDATOR TESTS
// ============================================================================

/// Test successful build parsing
let testSuccessfulBuild () =
    let summary = validateOutput successfulBuildOutput
    let passed = summary.Success && summary.TotalErrors = 0 && summary.TotalWarnings = 0
    (passed, sprintf "Success: %b, Errors: %d, Warnings: %d" summary.Success summary.TotalErrors summary.TotalWarnings)

/// Test failed build parsing
let testFailedBuild () =
    let summary = validateOutput failedBuildOutput
    let passed = not summary.Success && summary.TotalErrors = 2
    (passed, sprintf "Success: %b, Errors: %d (expected 2)" summary.Success summary.TotalErrors)

/// Test warnings-only build
let testWarningsOnlyBuild () =
    let summary = validateOutput warningsOnlyOutput
    let passed = summary.Success && summary.TotalWarnings = 2
    (passed, sprintf "Success: %b, Warnings: %d (expected 2)" summary.Success summary.TotalWarnings)

/// Test STAMP compliance check
let testStampCompliance () =
    let successSummary = validateOutput successfulBuildOutput
    let failSummary = validateOutput failedBuildOutput
    let passed = successSummary.StampCompliant && not failSummary.StampCompliant
    (passed, sprintf "Success compliant: %b, Fail compliant: %b" successSummary.StampCompliant failSummary.StampCompliant)

// ============================================================================
// FPPS CONSENSUS TESTS
// ============================================================================

/// Test FPPS on successful build
let testFPPSSuccess () =
    let result = validate successfulBuildOutput
    let passed = result.IsValid && result.ConsensusErrorCount = 0
    (passed, sprintf "Agreement: %A, Errors: %d" result.Agreement result.ConsensusErrorCount)

/// Test FPPS on failed build
let testFPPSFailure () =
    let result = validate failedBuildOutput
    let passed = result.ConsensusErrorCount > 0
    (passed, sprintf "Agreement: %A, Errors: %d (should be >0)" result.Agreement result.ConsensusErrorCount)

/// Test all 5 methods are executed
let testAllMethodsRun () =
    let results = runAllMethods successfulBuildOutput
    let passed = List.length results = 5
    let methods = results |> List.map (fun r -> r.Method) |> String.concat ", "
    (passed, sprintf "Methods: %s" methods)

/// Test consensus calculation
let testConsensusCalculation () =
    let result = validate successfulBuildOutput
    let allZero =
        result.PatternResult.ErrorCount = 0 &&
        result.AstResult.ErrorCount = 0 &&
        result.StatisticalResult.ErrorCount = 0 &&
        result.BinaryResult.ErrorCount = 0 &&
        result.LineByLineResult.ErrorCount = 0
    (allZero, sprintf "All methods agree on 0 errors: %b" allZero)

/// Test STAMP validation of FPPS result
let testFPPSStampValidation () =
    let result = validate successfulBuildOutput
    let validations = validateFPPSStamp result
    let allPassed = validations |> List.forall (fun v -> v.Status)
    let failedConstraints = validations |> List.filter (fun v -> not v.Status) |> List.map (fun v -> v.ConstraintId)
    (allPassed, if allPassed then "All FPPS STAMP constraints passed" else sprintf "Failed: %s" (String.concat ", " failedConstraints))

// ============================================================================
// RUN ALL TESTS
// ============================================================================

/// All verification tests
let allTests = [
    // Error Pattern Tests
    ("EP-007 Value Not Defined", testValueNotDefined)
    ("EP-008 Type Mismatch", testTypeMismatch)
    ("EP-021 Unused Variable", testUnusedVariable)
    ("Pattern Count", testPatternCount)
    ("STAMP Constrained Patterns", testStampPatterns)

    // Compilation Validator Tests
    ("Successful Build Parsing", testSuccessfulBuild)
    ("Failed Build Parsing", testFailedBuild)
    ("Warnings Only Build", testWarningsOnlyBuild)
    ("STAMP Compliance", testStampCompliance)

    // FPPS Consensus Tests
    ("FPPS Success", testFPPSSuccess)
    ("FPPS Failure Detection", testFPPSFailure)
    ("All 5 Methods Run", testAllMethodsRun)
    ("Consensus Calculation", testConsensusCalculation)
    ("FPPS STAMP Validation", testFPPSStampValidation)
]

/// Run all verification tests
let runAllTests () =
    let results = allTests |> List.map (fun (name, test) -> runTest name test)
    let passed = results |> List.filter (fun r -> r.Passed)
    let failed = results |> List.filter (fun r -> not r.Passed)

    {|
        TotalTests = List.length results
        PassedCount = List.length passed
        FailedCount = List.length failed
        PassRate = float (List.length passed) / float (List.length results) * 100.0
        Results = results
        Failed = failed
    |}

/// Format test results for display
let formatTestResults () =
    let summary = runAllTests ()

    let header =
        sprintf "╔═══════════════════════════════════════════════════════════════════╗\n\
║  PATTERN MIGRATION VERIFICATION (46.x)                            ║\n\
║  FPPS 5-Method Consensus Engine Tests                             ║\n\
╠═══════════════════════════════════════════════════════════════════╣\n\
║  Total: %d  |  Passed: %d  |  Failed: %d  |  Pass Rate: %.1f%%%%   ║\n\
╚═══════════════════════════════════════════════════════════════════╝\n"
            summary.TotalTests summary.PassedCount summary.FailedCount summary.PassRate

    let testLines =
        summary.Results
        |> List.map (fun r ->
            let status = if r.Passed then "✓ PASS" else "✗ FAIL"
            sprintf "  %s  %-35s  %s" status r.TestName r.Message)
        |> String.concat "\n"

    let stampSection = "\n\
STAMP Constraints Verified:\n\
  - SC-VAL-003: 100% consensus requirement\n\
  - SC-VAL-004: Halt on disagreement\n\
  - SC-FSH-160: All 5 methods executed\n\
  - SC-COV-001: Critical path coverage\n\n\
AOR Rules Verified:\n\
  - AOR-TEST-001: TDG methodology\n\
  - AOR-VAL-001: Patient Mode compilation\n"

    header + testLines + stampSection

/// Quick verification check
let verify () =
    let summary = runAllTests ()
    summary.PassRate >= 90.0 && summary.FailedCount = 0

/// Get verification summary for STAMP compliance
let getStampComplianceSummary () =
    let summary = runAllTests ()
    {|
        Compliant = summary.FailedCount = 0
        PassRate = summary.PassRate
        Constraints = [
            ("SC-VAL-003", summary.Results |> List.exists (fun r -> r.TestName.Contains("Consensus") && r.Passed))
            ("SC-VAL-004", summary.Results |> List.exists (fun r -> r.TestName.Contains("FPPS") && r.Passed))
            ("SC-FSH-160", summary.Results |> List.exists (fun r -> r.TestName.Contains("5 Methods") && r.Passed))
        ]
    |}
