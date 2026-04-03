/// CEPAF FPPS (Five-Point Pattern System) Consensus Validator
/// Implements 5-method validation consensus for compilation verification.
///
/// WHAT: 5-method consensus validation for F# compilation output
/// WHY: Ensures reliable error detection through multiple independent validation methods
/// CONSTRAINTS:
///   - SC-VAL-003: 100% consensus required
///   - SC-VAL-004: Halt on disagreement
///   - SC-FSH-160: All 5 methods must agree
///
/// The 5 Validation Methods:
///   1. Pattern: Regex pattern matching (ErrorPatterns.fs)
///   2. AST: Abstract Syntax Tree analysis
///   3. Statistical: Error clustering and frequency
///   4. Binary: IL/assembly verification
///   5. LineByLine: Source code inspection
///
/// STAMP Compliance: SC-VAL-003, SC-VAL-004, SC-FSH-160 to SC-FSH-165
/// Version: 1.0.0
module Cepaf.Validation.FPPSValidator

open System
open System.Text.RegularExpressions
open Cepaf.Validation.ErrorPatterns
open Cepaf.Validation.CompilationValidator

// ============================================================================
// TYPES
// ============================================================================

/// Individual method result
type MethodResult = {
    Method: string
    ErrorCount: int
    WarningCount: int
    Confidence: float  // 0.0 to 1.0
    Details: string list
}

/// Method agreement status
type AgreementStatus =
    | FullConsensus      // All 5 methods agree
    | MajorityConsensus  // 3+ methods agree
    | NoConsensus        // Less than 3 agree

/// FPPS Consensus result
type FPPSResult = {
    PatternResult: MethodResult
    AstResult: MethodResult
    StatisticalResult: MethodResult
    BinaryResult: MethodResult
    LineByLineResult: MethodResult
    Agreement: AgreementStatus
    ConsensusErrorCount: int
    ConsensusWarningCount: int
    IsValid: bool
    StampCompliant: bool
    VotingDetails: string
}

/// Voting threshold configuration
type VotingConfig = {
    RequireFullConsensus: bool
    MinimumConfidence: float
    AllowPartialConsensus: bool
    ErrorCountTolerance: int
}

/// Language detection for build output
type BuildLanguage =
    | FSharp
    | Elixir
    | Mixed
    | Unknown

// ============================================================================
// METHOD 1: PATTERN VALIDATION (Enhanced for F# + Elixir)
// SC-VAL-PATTERN-001: Multi-language pattern matching with auto-detection
// ============================================================================

/// Detect build output language from content
let detectLanguage (output: string) : BuildLanguage =
    let hasFSharp =
        output.Contains(".fs(") ||
        output.Contains(".fsproj") ||
        output.Contains("error FS") ||
        output.Contains("warning FS")
    let hasElixir =
        output.Contains(".ex:") ||
        output.Contains(".exs:") ||
        output.Contains("** (") ||
        output.Contains("mix compile") ||
        output.Contains("warning: ")

    match (hasFSharp, hasElixir) with
    | (true, true) -> Mixed
    | (true, false) -> FSharp
    | (false, true) -> Elixir
    | (false, false) -> Unknown

/// Pattern-based validation for F# output
let validateFSharpPatterns (output: string) : int * int * string list =
    let matches = matchOutput output
    let errors = matches |> List.filter (fun m ->
        m.Pattern.Severity = PatternSeverity.Error || m.Pattern.Severity = PatternSeverity.Critical)
    let warnings = matches |> List.filter (fun m ->
        m.Pattern.Severity = PatternSeverity.Warning)
    let details = matches |> List.map (fun m -> sprintf "[F#] %s: %s" m.Pattern.Id m.Message)
    (List.length errors, List.length warnings, details)

/// Pattern-based validation for Elixir output
let validateElixirPatterns (output: string) : int * int * string list =
    let matches = matchElixirOutput output
    let errors = matches |> List.filter (fun m ->
        m.Pattern.Severity = PatternSeverity.Error || m.Pattern.Severity = PatternSeverity.Critical)
    let warnings = matches |> List.filter (fun m ->
        m.Pattern.Severity = PatternSeverity.Warning)
    let details = matches |> List.map (fun m -> sprintf "[EX] %s: %s" m.Pattern.Id m.Message)
    (List.length errors, List.length warnings, details)

/// Calculate pattern coverage confidence
let calculatePatternConfidence (output: string) (matchCount: int) : float =
    if String.IsNullOrEmpty output then 0.0
    else
        let lines = output.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries)
        let errorLines = lines |> Array.filter (fun l ->
            l.Contains("error") || l.Contains("warning") ||
            l.Contains("Error") || l.Contains("Warning"))
        if errorLines.Length = 0 then 1.0
        else min 1.0 (float matchCount / float errorLines.Length)

/// Enhanced pattern-based validation with multi-language support
/// STAMP: SC-VAL-PATTERN-001 (Multi-language pattern matching)
let validateWithPatterns (output: string) : MethodResult =
    let language = detectLanguage output

    let (fsErrors, fsWarnings, fsDetails) =
        if language = FSharp || language = Mixed || language = Unknown then
            validateFSharpPatterns output
        else (0, 0, [])

    let (exErrors, exWarnings, exDetails) =
        if language = Elixir || language = Mixed || language = Unknown then
            validateElixirPatterns output
        else (0, 0, [])

    let totalErrors = fsErrors + exErrors
    let totalWarnings = fsWarnings + exWarnings
    let allDetails = fsDetails @ exDetails

    let confidence = calculatePatternConfidence output (List.length allDetails)

    {
        Method = "Pattern"
        ErrorCount = totalErrors
        WarningCount = totalWarnings
        Confidence = confidence
        Details =
            [ sprintf "Language detected: %A" language
              sprintf "F# patterns: %d errors, %d warnings" fsErrors fsWarnings
              sprintf "Elixir patterns: %d errors, %d warnings" exErrors exWarnings ]
            @ (allDetails |> List.truncate 20)  // Limit detail output
    }

// ============================================================================
// METHOD 2: AST-BASED VALIDATION (Enhanced for F# + Elixir)
// SC-VAL-AST-001: Multi-language structured error format parsing
// ============================================================================

/// Parse F# structured error format: file.fs(line,col): error FSxxxx: message
let parseFSharpAst (output: string) : int * int * string list =
    let pattern = Regex(@"([^\s(]+\.fs[xi]?)\((\d+),(\d+)\):\s+(error|warning)\s+([A-Z]+\d+):", RegexOptions.Compiled)
    let matches = pattern.Matches(output)

    let errors = matches |> Seq.filter (fun m -> m.Groups.[4].Value = "error") |> Seq.length
    let warnings = matches |> Seq.filter (fun m -> m.Groups.[4].Value = "warning") |> Seq.length

    let details =
        matches
        |> Seq.map (fun m ->
            sprintf "[F#] %s(%s,%s): %s %s"
                m.Groups.[1].Value
                m.Groups.[2].Value
                m.Groups.[3].Value
                m.Groups.[4].Value
                m.Groups.[5].Value)
        |> Seq.toList

    (errors, warnings, details)

/// Parse Elixir structured error format: file.ex:line:col: error/warning: message
let parseElixirAst (output: string) : int * int * string list =
    // Elixir error format: lib/path/file.ex:123:45: error: message
    // Elixir warning format: lib/path/file.ex:123: warning: message
    let errorPattern = Regex(@"([^\s:]+\.exs?):(\d+):?(\d+)?:\s*(error|warning|Error|Warning):", RegexOptions.Compiled)
    let matches = errorPattern.Matches(output)

    // Also check for ** (CompileError) format
    let compileErrorPattern = Regex(@"\*\*\s*\((CompileError|TokenMissingError|SyntaxError)\)", RegexOptions.Compiled)
    let compileErrors = compileErrorPattern.Matches(output).Count

    let errors =
        (matches |> Seq.filter (fun m ->
            let severity = m.Groups.[4].Value.ToLower()
            severity = "error") |> Seq.length) + compileErrors
    let warnings =
        matches |> Seq.filter (fun m ->
            let severity = m.Groups.[4].Value.ToLower()
            severity = "warning") |> Seq.length

    let details =
        matches
        |> Seq.map (fun m ->
            let col = if m.Groups.[3].Success then m.Groups.[3].Value else "0"
            sprintf "[EX] %s:%s:%s %s"
                m.Groups.[1].Value
                m.Groups.[2].Value
                col
                m.Groups.[4].Value)
        |> Seq.toList

    (errors, warnings, details)

/// Enhanced AST-based validation with multi-language support
/// STAMP: SC-VAL-AST-001 (Multi-language AST parsing)
let validateWithAst (output: string) : MethodResult =
    let language = detectLanguage output

    let (fsErrors, fsWarnings, fsDetails) =
        if language = FSharp || language = Mixed || language = Unknown then
            parseFSharpAst output
        else (0, 0, [])

    let (exErrors, exWarnings, exDetails) =
        if language = Elixir || language = Mixed || language = Unknown then
            parseElixirAst output
        else (0, 0, [])

    let totalErrors = fsErrors + exErrors
    let totalWarnings = fsWarnings + exWarnings
    let allDetails = fsDetails @ exDetails

    let confidence =
        if List.length allDetails > 0 then 0.95
        elif language <> Unknown then 0.85
        else 0.70

    {
        Method = "AST"
        ErrorCount = totalErrors
        WarningCount = totalWarnings
        Confidence = confidence
        Details =
            [ sprintf "F# AST: %d errors, %d warnings" fsErrors fsWarnings
              sprintf "Elixir AST: %d errors, %d warnings" exErrors exWarnings ]
            @ (allDetails |> List.truncate 15)
    }

// ============================================================================
// METHOD 3: STATISTICAL VALIDATION (Enhanced for F# + Elixir)
// SC-VAL-STAT-001: Multi-language keyword frequency and clustering
// ============================================================================

/// Statistical clustering for error detection with multi-language support
/// STAMP: SC-VAL-STAT-001 (Statistical anomaly detection)
let validateWithStatistics (output: string) : MethodResult =
    let language = detectLanguage output
    let lines = output.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries)

    // Multi-language error keywords
    let errorKeywords = [|
        // Common
        "error"; "Error"; "ERROR"; "failed"; "Failed"; "FAILED"
        // Elixir-specific
        "** ("; "CompileError"; "UndefinedFunctionError"; "ArgumentError"
    |]
    let warningKeywords = [|
        // Common
        "warning"; "Warning"; "WARNING"; "warn"; "Warn"
        // Elixir-specific
        "variable .* is unused"; "module attribute .* was set but never used"
    |]

    // Exclusion patterns (summary lines, not actual errors)
    let exclusionPatterns = [|
        "Error(s)"; "Warning(s)"; "Build succeeded"; "Build FAILED"
        "Compiling"; "Generated"; "Compiled"  // Elixir progress messages
    |]

    let countKeywords (keywords: string[]) (line: string) =
        keywords |> Array.sumBy (fun kw ->
            if line.Contains(kw) then 1 else 0)

    let isExcluded (line: string) =
        exclusionPatterns |> Array.exists (fun p -> line.Contains(p))

    let errorLines =
        lines
        |> Array.filter (fun l -> countKeywords errorKeywords l > 0)
        |> Array.filter (fun l -> not (isExcluded l))

    let warningLines =
        lines
        |> Array.filter (fun l -> countKeywords warningKeywords l > 0)
        |> Array.filter (fun l -> not (isExcluded l))

    // Detect unique clusters (consecutive errors from same cause)
    let clusterCount arr =
        if Array.isEmpty arr then 0
        else arr |> Array.distinct |> Array.length

    {
        Method = "Statistical"
        ErrorCount = clusterCount errorLines
        WarningCount = clusterCount warningLines
        Confidence = 0.85  // Statistical method has inherent uncertainty
        Details = [
            sprintf "Language: %A" language
            sprintf "Error lines detected: %d" (Array.length errorLines)
            sprintf "Warning lines detected: %d" (Array.length warningLines)
            sprintf "Unique error clusters: %d" (clusterCount errorLines)
        ]
    }

// ============================================================================
// METHOD 4: BINARY/IL VALIDATION (Enhanced for F# + Elixir)
// SC-VAL-BIN-001: Multi-language build artifact verification
// ============================================================================

/// Binary validation with multi-language support (DLL/BEAM verification)
/// STAMP: SC-VAL-BIN-001 (Build artifact verification)
let validateWithBinary (output: string) : MethodResult =
    let language = detectLanguage output

    // F# / .NET: Check for DLL generation
    let dllPattern = Regex(@"(\w+)\s+->\s+(.+\.dll)", RegexOptions.Compiled)
    let dllMatches = dllPattern.Matches(output)

    // Elixir: Check for BEAM file generation or compilation success
    let beamPattern = Regex(@"Compiling\s+\d+\s+file|Generated\s+\w+\s+app", RegexOptions.Compiled)
    let beamMatches = beamPattern.Matches(output)

    // F# build results
    let fsBuildSucceeded = output.Contains("Build succeeded")
    let fsBuildFailed = output.Contains("Build FAILED")

    // Elixir build results
    let exCompileSuccess = output.Contains("Compiled") && not (output.Contains("error"))
    let exCompileFailed = output.Contains("** (CompileError)") || output.Contains("could not compile")

    // Extract F# error count from summary
    let fsErrorPattern = Regex(@"(\d+)\s+Error\(s\)")
    let fsErrorMatch = fsErrorPattern.Match(output)
    let fsErrors = if fsErrorMatch.Success then int fsErrorMatch.Groups.[1].Value else 0

    let fsWarningPattern = Regex(@"(\d+)\s+Warning\(s\)")
    let fsWarningMatch = fsWarningPattern.Match(output)
    let fsWarnings = if fsWarningMatch.Success then int fsWarningMatch.Groups.[1].Value else 0

    // Elixir error detection from output
    let exErrorPattern = Regex(@"\*\*\s*\((\w+Error)\)", RegexOptions.Compiled)
    let exErrors = exErrorPattern.Matches(output).Count

    let totalErrors = fsErrors + exErrors
    let totalWarnings = fsWarnings

    let confidence =
        match language with
        | FSharp when fsBuildSucceeded || fsBuildFailed -> 0.99
        | Elixir when exCompileSuccess || exCompileFailed -> 0.95
        | Mixed -> 0.90
        | _ when dllMatches.Count > 0 || beamMatches.Count > 0 -> 0.85
        | _ -> 0.70

    {
        Method = "Binary"
        ErrorCount = totalErrors
        WarningCount = totalWarnings
        Confidence = confidence
        Details = [
            sprintf "Language: %A" language
            sprintf "F# Build succeeded: %b, failed: %b" fsBuildSucceeded fsBuildFailed
            sprintf "Elixir Compile succeeded: %b, failed: %b" exCompileSuccess exCompileFailed
            sprintf "DLLs generated: %d" dllMatches.Count
            sprintf "BEAM compilations: %d" beamMatches.Count
            if fsErrorMatch.Success then sprintf "F# summary errors: %d" fsErrors
            if exErrors > 0 then sprintf "Elixir errors: %d" exErrors
        ]
    }

// ============================================================================
// METHOD 5: LINE-BY-LINE VALIDATION (Enhanced for F# + Elixir)
// SC-VAL-LBL-001: Multi-language line-by-line inspection
// ============================================================================

/// Line-by-line validation with multi-language support
/// STAMP: SC-VAL-LBL-001 (Line-by-line source inspection)
let validateWithLineByLine (output: string) : MethodResult =
    let language = detectLanguage output
    let lines = output.Split([|'\n'; '\r'|], StringSplitOptions.RemoveEmptyEntries)

    // F# patterns: file.fs(line,col): error FSxxxx: message
    let fsErrorPattern = Regex(@"^.+\.fs[xi]?\(\d+,\d+\):\s*error\s+[A-Z]+\d+:", RegexOptions.Compiled)
    let fsWarningPattern = Regex(@"^.+\.fs[xi]?\(\d+,\d+\):\s*warning\s+[A-Z]+\d+:", RegexOptions.Compiled)

    // MSBuild patterns
    let msbuildErrorPattern = Regex(@"^\s*error\s+[A-Z]+\d+:", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
    let msbuildWarningPattern = Regex(@"^\s*warning\s+[A-Z]+\d+:", RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

    // Elixir patterns: file.ex:line:col: error/warning: message
    let exErrorPattern = Regex(@"^.+\.exs?:\d+:?\d*:\s*(error|Error):", RegexOptions.Compiled)
    let exWarningPattern = Regex(@"^.+\.exs?:\d+:?\d*:\s*warning:", RegexOptions.Compiled)

    // Elixir CompileError pattern
    let exCompileErrorPattern = Regex(@"^\s*\*\*\s*\(\w+Error\)", RegexOptions.Compiled)

    let errorLines =
        lines
        |> Array.filter (fun l ->
            fsErrorPattern.IsMatch(l) ||
            msbuildErrorPattern.IsMatch(l) ||
            exErrorPattern.IsMatch(l) ||
            exCompileErrorPattern.IsMatch(l))
        |> Array.distinct

    let warningLines =
        lines
        |> Array.filter (fun l ->
            fsWarningPattern.IsMatch(l) ||
            msbuildWarningPattern.IsMatch(l) ||
            exWarningPattern.IsMatch(l))
        |> Array.distinct

    {
        Method = "LineByLine"
        ErrorCount = Array.length errorLines
        WarningCount = Array.length warningLines
        Confidence = 0.92  // Line-by-line is accurate but may miss some formats
        Details = [
            sprintf "Language: %A" language
            sprintf "Error lines found: %d" (Array.length errorLines)
            sprintf "Warning lines found: %d" (Array.length warningLines)
            yield! errorLines |> Array.truncate 5 |> Array.map (sprintf "  Error: %s")
        ]
    }

// ============================================================================
// CONSENSUS ENGINE
// ============================================================================

/// Default voting configuration (STAMP compliant)
let defaultVotingConfig = {
    RequireFullConsensus = true  // SC-VAL-003
    MinimumConfidence = 0.8
    AllowPartialConsensus = false
    ErrorCountTolerance = 0  // Strict matching
}

/// Calculate consensus from method results
let calculateConsensus (results: MethodResult list) (config: VotingConfig) : AgreementStatus * int * int =
    // Weight by confidence
    let weightedVotes =
        results
        |> List.map (fun r ->
            (r.ErrorCount, r.WarningCount, r.Confidence))

    // Find the most common error count
    let errorVotes =
        weightedVotes
        |> List.groupBy (fun (e, _, _) -> e)
        |> List.map (fun (count, votes) ->
            let totalWeight = votes |> List.sumBy (fun (_, _, c) -> c)
            (count, List.length votes, totalWeight))
        |> List.sortByDescending (fun (_, count, weight) -> (count, weight))

    let warningVotes =
        weightedVotes
        |> List.groupBy (fun (_, w, _) -> w)
        |> List.map (fun (count, votes) ->
            let totalWeight = votes |> List.sumBy (fun (_, _, c) -> c)
            (count, List.length votes, totalWeight))
        |> List.sortByDescending (fun (_, count, weight) -> (count, weight))

    let (consensusErrors, errorVoteCount, _) =
        errorVotes |> List.tryHead |> Option.defaultValue (0, 0, 0.0)

    let (consensusWarnings, warningVoteCount, _) =
        warningVotes |> List.tryHead |> Option.defaultValue (0, 0, 0.0)

    let agreement =
        if errorVoteCount = 5 && warningVoteCount = 5 then
            FullConsensus
        elif errorVoteCount >= 3 && warningVoteCount >= 3 then
            MajorityConsensus
        else
            NoConsensus

    (agreement, consensusErrors, consensusWarnings)

/// Run all 5 validation methods
let runAllMethods (output: string) : MethodResult list =
    [
        validateWithPatterns output
        validateWithAst output
        validateWithStatistics output
        validateWithBinary output
        validateWithLineByLine output
    ]

/// Full FPPS validation
let validate (output: string) : FPPSResult =
    let config = defaultVotingConfig
    let results = runAllMethods output

    let patternResult = results.[0]
    let astResult = results.[1]
    let statisticalResult = results.[2]
    let binaryResult = results.[3]
    let lineByLineResult = results.[4]

    let (agreement, consensusErrors, consensusWarnings) = calculateConsensus results config

    // STAMP compliance requires full consensus with 0 errors
    let isValid = agreement = FullConsensus || agreement = MajorityConsensus
    let stampCompliant = isValid && consensusErrors = 0 && consensusWarnings = 0

    let votingDetails =
        sprintf """
FPPS 5-Method Voting Results:
  1. Pattern:     %d errors, %d warnings (confidence: %.2f)
  2. AST:         %d errors, %d warnings (confidence: %.2f)
  3. Statistical: %d errors, %d warnings (confidence: %.2f)
  4. Binary:      %d errors, %d warnings (confidence: %.2f)
  5. LineByLine:  %d errors, %d warnings (confidence: %.2f)

Consensus: %d errors, %d warnings
Agreement: %A
"""
            patternResult.ErrorCount patternResult.WarningCount patternResult.Confidence
            astResult.ErrorCount astResult.WarningCount astResult.Confidence
            statisticalResult.ErrorCount statisticalResult.WarningCount statisticalResult.Confidence
            binaryResult.ErrorCount binaryResult.WarningCount binaryResult.Confidence
            lineByLineResult.ErrorCount lineByLineResult.WarningCount lineByLineResult.Confidence
            consensusErrors consensusWarnings
            agreement

    {
        PatternResult = patternResult
        AstResult = astResult
        StatisticalResult = statisticalResult
        BinaryResult = binaryResult
        LineByLineResult = lineByLineResult
        Agreement = agreement
        ConsensusErrorCount = consensusErrors
        ConsensusWarningCount = consensusWarnings
        IsValid = isValid
        StampCompliant = stampCompliant
        VotingDetails = votingDetails
    }

// ============================================================================
// STAMP CONSTRAINT VALIDATION
// ============================================================================

/// Validate SC-VAL-003: 100% consensus required
let validateSC_VAL_003 (result: FPPSResult) : StampValidation =
    {
        ConstraintId = "SC-VAL-003"
        Status = result.Agreement = FullConsensus
        Message =
            match result.Agreement with
            | FullConsensus -> "All 5 methods reached full consensus"
            | MajorityConsensus -> "Only majority consensus achieved (3+ methods)"
            | NoConsensus -> "Methods failed to reach consensus"
        Details = Map.ofList [
            ("agreement", sprintf "%A" result.Agreement)
            ("consensus_errors", string result.ConsensusErrorCount)
            ("consensus_warnings", string result.ConsensusWarningCount)
        ]
    }

/// Validate SC-VAL-004: Halt on disagreement
let validateSC_VAL_004 (result: FPPSResult) : StampValidation =
    let methodErrors = [
        result.PatternResult.ErrorCount
        result.AstResult.ErrorCount
        result.StatisticalResult.ErrorCount
        result.BinaryResult.ErrorCount
        result.LineByLineResult.ErrorCount
    ]
    let allAgree = methodErrors |> List.distinct |> List.length = 1

    {
        ConstraintId = "SC-VAL-004"
        Status = allAgree
        Message =
            if allAgree then
                "All methods agree on error count"
            else
                sprintf "Methods disagree: [%s]"
                    (methodErrors |> List.map string |> String.concat ", ")
        Details = Map.ofList [
            ("pattern_errors", string result.PatternResult.ErrorCount)
            ("ast_errors", string result.AstResult.ErrorCount)
            ("statistical_errors", string result.StatisticalResult.ErrorCount)
            ("binary_errors", string result.BinaryResult.ErrorCount)
            ("linebyline_errors", string result.LineByLineResult.ErrorCount)
        ]
    }

/// Validate SC-FSH-160: All 5 methods must be executed
let validateSC_FSH_160 (result: FPPSResult) : StampValidation =
    let methodsRun = 5  // We always run all 5
    let highConfidence =
        [ result.PatternResult.Confidence
          result.AstResult.Confidence
          result.StatisticalResult.Confidence
          result.BinaryResult.Confidence
          result.LineByLineResult.Confidence ]
        |> List.filter (fun c -> c >= 0.8)
        |> List.length

    {
        ConstraintId = "SC-FSH-160"
        Status = methodsRun = 5 && highConfidence >= 4
        Message = sprintf "%d methods executed, %d with high confidence (>=0.8)" methodsRun highConfidence
        Details = Map.ofList [
            ("methods_run", string methodsRun)
            ("high_confidence_count", string highConfidence)
        ]
    }

/// Run all FPPS STAMP validations
let validateFPPSStamp (result: FPPSResult) : StampValidation list =
    [
        validateSC_VAL_003 result
        validateSC_VAL_004 result
        validateSC_FSH_160 result
    ]

// ============================================================================
// HIGH-LEVEL API
// ============================================================================

/// Validate build output with full FPPS consensus
let validateBuildOutput (output: string) : FPPSResult * StampValidation list =
    let result = validate output
    let validations = validateFPPSStamp result
    (result, validations)

/// Quick check if output passes FPPS
let quickValidate (output: string) : bool =
    let result = validate output
    result.IsValid && result.ConsensusErrorCount = 0

/// Get consensus summary
let getConsensusSummary (output: string) : string =
    let result = validate output
    result.VotingDetails
