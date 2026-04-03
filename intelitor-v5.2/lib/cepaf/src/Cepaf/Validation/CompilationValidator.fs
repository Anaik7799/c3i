/// CEPAF F# Compilation Validator Module
/// Parses dotnet build output and validates against STAMP constraints.
///
/// WHAT: Parse dotnet build/test output for error/warning extraction
/// WHY: Enables automated compilation validation and quality gate enforcement
/// CONSTRAINTS:
///   - SC-CMP-025: 0 errors mandatory
///   - SC-CMP-026: All files must compile
///   - SC-CMP-028: No interruption during compilation
///   - AOR-QUA-001: Zero warnings mandatory
///
/// STAMP Compliance: SC-CMP-025 to SC-CMP-030, SC-FSH-150 to SC-FSH-155
/// Version: 1.0.0
module Cepaf.Validation.CompilationValidator

open System
open System.Text.RegularExpressions
open System.Diagnostics
open Cepaf.Validation.ErrorPatterns

// ============================================================================
// TYPES
// ============================================================================

/// Compilation result summary
type CompilationSummary = {
    TotalErrors: int
    TotalWarnings: int
    FileCount: int
    Duration: TimeSpan
    Success: bool
    StampCompliant: bool
}

/// Detailed compilation result
type CompilationResult = {
    Summary: CompilationSummary
    Errors: PatternMatch list
    Warnings: PatternMatch list
    StampViolations: PatternMatch list
    RawOutput: string
    Command: string
    ExitCode: int
    StartTime: DateTime
    EndTime: DateTime
}

/// Compilation target type
type BuildTarget =
    | Solution of string      // .sln file
    | Project of string       // .fsproj file
    | Directory of string     // Directory with projects

/// Build configuration
type BuildConfig = {
    Target: BuildTarget
    Configuration: string     // Debug, Release
    Verbosity: string         // quiet, minimal, normal, detailed, diagnostic
    NoRestore: bool
    NoBuild: bool
    MaxCpuCount: int option
    PatientMode: bool         // SC-VAL-001: Patient Mode
}

/// STAMP validation result
type StampValidation = {
    ConstraintId: string
    Status: bool
    Message: string
    Details: Map<string, string>
}

// ============================================================================
// PARSING
// ============================================================================

/// Summary line regex patterns
module SummaryPatterns =
    /// Match "Build succeeded." or "Build FAILED."
    let buildResultPattern = Regex(@"Build\s+(succeeded|FAILED)\.", RegexOptions.Compiled)

    /// Match error count: "0 Error(s)" or "5 Error(s)"
    let errorCountPattern = Regex(@"(\d+)\s+Error\(s\)", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

    /// Match warning count: "51 Warning(s)"
    let warningCountPattern = Regex(@"(\d+)\s+Warning\(s\)", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

    /// Match time elapsed: "Time Elapsed 00:00:02.34"
    let timeElapsedPattern = Regex(@"Time\s+Elapsed\s+(\d+:\d+:\d+\.?\d*)", RegexOptions.Compiled)

    /// Match file compilation: "Compiling file.fs"
    let compilingFilePattern = Regex(@"(?:Compiling|Compiled)\s+(.+\.fs)", RegexOptions.Compiled)

    /// Match dotnet error format: path(line,col): error FS0001: message
    let dotnetErrorPattern = Regex(
        @"^(.+?)\((\d+),(\d+)\):\s+(error|warning)\s+([A-Z]+\d+):\s+(.+)$",
        RegexOptions.Compiled ||| RegexOptions.Multiline)

    /// Match MSBuild error format
    let msbuildErrorPattern = Regex(
        @"^(.+?):\s+(error|warning)\s+([A-Z]+\d+):\s+(.+)$",
        RegexOptions.Compiled ||| RegexOptions.Multiline)

/// Parse a single error/warning line from dotnet output
let parseDotnetLine (line: string) : (string * int * int * string * string * string) option =
    let m = SummaryPatterns.dotnetErrorPattern.Match(line)
    if m.Success then
        Some (
            m.Groups.[1].Value,  // file path
            int m.Groups.[2].Value,  // line
            int m.Groups.[3].Value,  // column
            m.Groups.[4].Value,  // error|warning
            m.Groups.[5].Value,  // error code
            m.Groups.[6].Value   // message
        )
    else
        None

/// Extract error count from summary
let extractErrorCount (output: string) : int =
    let m = SummaryPatterns.errorCountPattern.Match(output)
    if m.Success then int m.Groups.[1].Value else 0

/// Extract warning count from summary
let extractWarningCount (output: string) : int =
    let m = SummaryPatterns.warningCountPattern.Match(output)
    if m.Success then int m.Groups.[1].Value else 0

/// Extract build success status
let extractBuildSuccess (output: string) : bool =
    let m = SummaryPatterns.buildResultPattern.Match(output)
    if m.Success then
        m.Groups.[1].Value.ToLowerInvariant() = "succeeded"
    else
        // If no explicit result, check for absence of errors
        extractErrorCount output = 0

/// Extract elapsed time
let extractElapsedTime (output: string) : TimeSpan option =
    let m = SummaryPatterns.timeElapsedPattern.Match(output)
    if m.Success then
        match TimeSpan.TryParse(m.Groups.[1].Value) with
        | true, ts -> Some ts
        | _ -> None
    else
        None

/// Count compiled files
let countCompiledFiles (output: string) : int =
    let matches = SummaryPatterns.compilingFilePattern.Matches(output)
    matches.Count

// ============================================================================
// COMPILATION EXECUTION
// ============================================================================

/// Default build configuration
let defaultConfig target = {
    Target = target
    Configuration = "Debug"
    Verbosity = "normal"
    NoRestore = false
    NoBuild = false
    MaxCpuCount = Some Environment.ProcessorCount
    PatientMode = true
}

/// Build command from configuration
let buildCommand (config: BuildConfig) : string =
    let targetPath =
        match config.Target with
        | Solution path -> path
        | Project path -> path
        | Directory path -> path

    let parts = [
        "dotnet build"
        sprintf "\"%s\"" targetPath
        sprintf "--configuration %s" config.Configuration
        sprintf "--verbosity %s" config.Verbosity
        if config.NoRestore then "--no-restore"
        if config.NoBuild then "--no-build"
        match config.MaxCpuCount with
        | Some n -> sprintf "-maxcpucount:%d" n
        | None -> ""
    ]

    parts |> List.filter (not << String.IsNullOrEmpty) |> String.concat " "

/// Execute dotnet build command
let executeBuild (config: BuildConfig) : Async<CompilationResult> =
    async {
        let command = buildCommand config
        let startTime = DateTime.UtcNow

        let psi = ProcessStartInfo()
        psi.FileName <- "dotnet"
        psi.Arguments <- command.Substring(7) // Remove "dotnet " prefix
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true

        // Set Patient Mode environment if enabled
        if config.PatientMode then
            psi.Environment.["NO_TIMEOUT"] <- "true"
            psi.Environment.["PATIENT_MODE"] <- "enabled"
            psi.Environment.["INFINITE_PATIENCE"] <- "true"

        use proc = new Process()
        proc.StartInfo <- psi
        proc.Start() |> ignore

        let! output = proc.StandardOutput.ReadToEndAsync() |> Async.AwaitTask
        let! errors = proc.StandardError.ReadToEndAsync() |> Async.AwaitTask
        proc.WaitForExit()

        let endTime = DateTime.UtcNow
        let combinedOutput = output + "\n" + errors

        // Parse the output
        let patternMatches = matchOutput combinedOutput
        let errorMatches = patternMatches |> List.filter (fun m ->
            m.Pattern.Severity = Critical || m.Pattern.Severity = Error)
        let warningMatches = patternMatches |> List.filter (fun m ->
            m.Pattern.Severity = Warning)
        let stampViolations = patternMatches |> List.filter (fun m ->
            m.Pattern.StampConstraint.IsSome)

        let errorCount = max (extractErrorCount combinedOutput) (List.length errorMatches)
        let warningCount = max (extractWarningCount combinedOutput) (List.length warningMatches)
        let success = extractBuildSuccess combinedOutput
        let duration = extractElapsedTime combinedOutput |> Option.defaultValue (endTime - startTime)
        let fileCount = countCompiledFiles combinedOutput

        let summary = {
            TotalErrors = errorCount
            TotalWarnings = warningCount
            FileCount = fileCount
            Duration = duration
            Success = success
            StampCompliant = errorCount = 0 && warningCount = 0
        }

        return {
            Summary = summary
            Errors = errorMatches
            Warnings = warningMatches
            StampViolations = stampViolations
            RawOutput = combinedOutput
            Command = command
            ExitCode = proc.ExitCode
            StartTime = startTime
            EndTime = endTime
        }
    }

// ============================================================================
// STAMP CONSTRAINT VALIDATION
// ============================================================================

/// Validate SC-CMP-025: 0 errors mandatory
let validateSC_CMP_025 (result: CompilationResult) : StampValidation =
    {
        ConstraintId = "SC-CMP-025"
        Status = result.Summary.TotalErrors = 0
        Message =
            if result.Summary.TotalErrors = 0 then
                "Compilation completed with 0 errors"
            else
                sprintf "Compilation has %d errors (must be 0)" result.Summary.TotalErrors
        Details = Map.ofList [
            ("error_count", string result.Summary.TotalErrors)
            ("file_count", string result.Summary.FileCount)
        ]
    }

/// Validate SC-CMP-026: All files must compile
let validateSC_CMP_026 (result: CompilationResult) : StampValidation =
    let criticalErrors = result.Errors |> List.filter (fun e ->
        e.Pattern.Severity = Critical)
    {
        ConstraintId = "SC-CMP-026"
        Status = List.isEmpty criticalErrors
        Message =
            if List.isEmpty criticalErrors then
                sprintf "All %d files compiled successfully" result.Summary.FileCount
            else
                sprintf "%d critical compilation failures" (List.length criticalErrors)
        Details = Map.ofList [
            ("critical_count", string (List.length criticalErrors))
            ("file_count", string result.Summary.FileCount)
        ]
    }

/// Validate AOR-QUA-001: Zero warnings mandatory
let validateAOR_QUA_001 (result: CompilationResult) : StampValidation =
    {
        ConstraintId = "AOR-QUA-001"
        Status = result.Summary.TotalWarnings = 0
        Message =
            if result.Summary.TotalWarnings = 0 then
                "Compilation completed with 0 warnings"
            else
                sprintf "Compilation has %d warnings (should be 0)" result.Summary.TotalWarnings
        Details = Map.ofList [
            ("warning_count", string result.Summary.TotalWarnings)
        ]
    }

/// Validate SC-CEP-004: 30-second boot threshold (compilation time)
let validateSC_CEP_004 (result: CompilationResult) : StampValidation =
    let thresholdSeconds = 30.0
    let withinThreshold = result.Summary.Duration.TotalSeconds <= thresholdSeconds
    {
        ConstraintId = "SC-CEP-004"
        Status = withinThreshold
        Message =
            if withinThreshold then
                sprintf "Compilation completed in %.2fs (within 30s threshold)"
                    result.Summary.Duration.TotalSeconds
            else
                sprintf "Compilation took %.2fs (exceeds 30s threshold)"
                    result.Summary.Duration.TotalSeconds
        Details = Map.ofList [
            ("duration_seconds", sprintf "%.2f" result.Summary.Duration.TotalSeconds)
            ("threshold_seconds", string thresholdSeconds)
        ]
    }

/// Validate SC-NET-001: All projects must use net10.0
let validateSC_NET_001 (result: CompilationResult) : StampValidation =
    let frameworkErrors = result.Errors |> List.filter (fun e ->
        e.Pattern.Id = "EP-070") // Target framework mismatch
    {
        ConstraintId = "SC-NET-001"
        Status = List.isEmpty frameworkErrors
        Message =
            if List.isEmpty frameworkErrors then
                "All projects use net10.0 target framework"
            else
                sprintf "%d target framework issues detected" (List.length frameworkErrors)
        Details = Map.ofList [
            ("framework_errors", string (List.length frameworkErrors))
        ]
    }

/// Run all STAMP validations
let validateStampConstraints (result: CompilationResult) : StampValidation list =
    [
        validateSC_CMP_025 result
        validateSC_CMP_026 result
        validateAOR_QUA_001 result
        validateSC_CEP_004 result
        validateSC_NET_001 result
    ]

/// Get overall STAMP compliance
let isStampCompliant (validations: StampValidation list) : bool =
    validations |> List.forall (fun v -> v.Status)

// ============================================================================
// REPORTING
// ============================================================================

/// Format compilation result for display
let formatResult (result: CompilationResult) : string =
    let status = if result.Summary.Success then "SUCCESS" else "FAILED"
    let stampStatus = if result.Summary.StampCompliant then "COMPLIANT" else "NON-COMPLIANT"

    sprintf """
=== F# Compilation Result ===
Status: %s
STAMP Compliance: %s

Errors: %d
Warnings: %d
Files: %d
Duration: %.2f seconds
Exit Code: %d

Command: %s
"""
        status
        stampStatus
        result.Summary.TotalErrors
        result.Summary.TotalWarnings
        result.Summary.FileCount
        result.Summary.Duration.TotalSeconds
        result.ExitCode
        result.Command

/// Format errors list
let formatErrors (result: CompilationResult) : string list =
    result.Errors
    |> List.map (fun e ->
        sprintf "[%s] %s:%d - %s: %s"
            e.Pattern.Id
            e.FilePath
            e.Line
            e.Pattern.Name
            e.Message)

/// Format warnings list
let formatWarnings (result: CompilationResult) : string list =
    result.Warnings
    |> List.map (fun w ->
        sprintf "[%s] %s:%d - %s"
            w.Pattern.Id
            w.FilePath
            w.Line
            w.Message)

/// Format STAMP validations
let formatStampValidations (validations: StampValidation list) : string =
    validations
    |> List.map (fun v ->
        let status = if v.Status then "✓ PASS" else "✗ FAIL"
        sprintf "  %s %s: %s" status v.ConstraintId v.Message)
    |> String.concat "\n"

// ============================================================================
// HIGH-LEVEL API
// ============================================================================

/// Build and validate a project
let buildAndValidate (projectPath: string) : Async<CompilationResult * StampValidation list> =
    async {
        let config = defaultConfig (Project projectPath)
        let! result = executeBuild config
        let validations = validateStampConstraints result
        return (result, validations)
    }

/// Build and validate a solution
let buildAndValidateSolution (solutionPath: string) : Async<CompilationResult * StampValidation list> =
    async {
        let config = defaultConfig (Solution solutionPath)
        let! result = executeBuild config
        let validations = validateStampConstraints result
        return (result, validations)
    }

/// Quick validation of existing build output
let validateOutput (output: string) : CompilationSummary =
    let patternMatches = matchOutput output
    let errorCount = extractErrorCount output
    let warningCount = extractWarningCount output
    let success = extractBuildSuccess output
    let duration = extractElapsedTime output |> Option.defaultValue TimeSpan.Zero
    let fileCount = countCompiledFiles output

    {
        TotalErrors = errorCount
        TotalWarnings = warningCount
        FileCount = fileCount
        Duration = duration
        Success = success
        StampCompliant = errorCount = 0 && warningCount = 0
    }

/// Parse and analyze build output string
let analyzeOutput (output: string) =
    let matches = matchOutput output
    let analysis = analyzeBuildOutput output

    {|
        Summary = validateOutput output
        PatternMatches = matches
        Analysis = analysis
        StampViolations = matches |> List.filter (fun m -> m.Pattern.StampConstraint.IsSome)
        CriticalIssues = matches |> List.filter (fun m -> m.Pattern.Severity = Critical)
        ErrorsByCategory = matches
            |> List.filter (fun m -> m.Pattern.Severity = Error || m.Pattern.Severity = Critical)
            |> List.groupBy (fun m -> m.Pattern.Category)
    |}
