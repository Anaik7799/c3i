#r "nuget: System.Text.Json"
#load "../src/Cepaf.Knowledge/OpenRouter.fs"

open System
open System.IO
open System.Text.RegularExpressions
open System.Text.Json
open System.Text.Json.Serialization
open Cepaf.Knowledge.OpenRouter

// =================================================================================================
// TYPE DEFINITIONS
// =================================================================================================

type ValidationLevel = 
    | Error
    | Warning
    | Info

type ValidationFinding = {
    Level: ValidationLevel
    Type: string
    Message: string
    Line: string
    LineNumber: int option
}

type ValidationResult = {
    Method: string
    Findings: ValidationFinding list
    ErrorCount: int
    WarningCount: int
    Score: float
}

type ConsensusResult = {
    Agreement: bool
    ExactConsensus: bool
    VarianceConsensus: bool
    Results: Map<string, ValidationResult>
}

// =================================================================================================
// PATTERN DEFINITIONS (Ported from Elixir)
// =================================================================================================

let errorPatterns = [
    // Compilation errors
    ("error:", "Compilation Error")
    (@"\*\* \(", "Exception Error")
    ("== Compilation error", "Module Compilation Error")
    ("CompileError", "Compile Error")
    ("SyntaxError", "Syntax Error")
    ("TokenMissingError", "Token Missing")
    ("FunctionClauseError", "Function Clause Error")
    ("BadArityError", "Bad Arity")
    
    // Variable/Function errors
    ("undefined variable", "Undefined Variable")
    ("undefined function", "Undefined Function")
    (@"variable \".+\" does not exist", "Nonexistent Variable")
    (@"variable \".+\" is undefined", "Undefined Variable Specific")
    ("UndefinedFunctionError", "Undefined Function Error")
    ("ArgumentError", "Argument Error")
    ("MatchError", "Match Error")
    
    // Type errors
    ("type specification", "Type Spec Error")
    ("dialyzer:", "Dialyzer Error")
    ("type mismatch", "Type Mismatch")
    
    // Module errors
    ("cannot compile module", "Module Compilation Failure")
    (@"module .+ is not available", "Missing Module")
    ("could not compile dependency", "Dependency Error")
    
    // Critical
    ("failed", "Operation Failed")
    ("Failed to", "Operation Failure")
]

let warningPatterns = [
    ("warning:", "Standard Warning")
    ("Warning", "Capitalized Warning")
    ("is unused", "Unused Variable")
    (@"variable .+ is unused", "Explicit Unused")
    ("deprecated", "Deprecation")
    ("will be removed", "Future Removal")
    ("TODO:", "TODO Marker")
    ("FIXME:", "FIXME Marker")
    (@"this clause cannot match", "Unreachable Clause")
    (@"guard will always fail", "Failing Guard")
]

// =================================================================================================
// VALIDATION METHODS
// =================================================================================================

module Validators = 

    let private findPatterns (content: string) (patterns: (string * string) list) (level: ValidationLevel) = 
        let lines = content.Split('\n')
        patterns 
        |> List.collect (fun (pattern, typeName) ->
            // Use regex for robust matching
            let regex = Regex(pattern, RegexOptions.Compiled)
            lines 
            |> Array.mapi (fun i line -> i, line)
            |> Array.filter (fun (_, line) -> regex.IsMatch(line))
            |> Array.map (fun (i, line) -> 
                { Level = level; Type = typeName; Message = line.Trim(); Line = line; LineNumber = Some (i + 1) }
            )
            |> Array.toList
        )

    // 1. Pattern Match Validator
    let validatePatternMatch (content: string) = 
        let errors = findPatterns content errorPatterns Error
        let warnings = findPatterns content warningPatterns Warning
        
        { Method = "PatternMatch"
          Findings = errors @ warnings
          ErrorCount = errors.Length
          WarningCount = warnings.Length
          Score = 0.95 } // High confidence

    // 2. AST-Like Structure Validator (Parses log structure)
    let validateAstCheck (content: string) = 
        let lines = content.Split('\n')
        let findings = ResizeArray<ValidationFinding>()
        
        // Look for "** (Exception) Message" structure
        let exceptionRegex = Regex(@"\*\* \(([^\)]+)\) (.+)")
        let warningRegex = Regex(@"warning: (.+)")

        for i in 0 .. lines.Length - 1 do
            let line = lines.[i]
            let excMatch = exceptionRegex.Match(line)
            if excMatch.Success then
                findings.Add({
                    Level = Error
                    Type = excMatch.Groups.[1].Value
                    Message = excMatch.Groups.[2].Value
                    Line = line
                    LineNumber = Some (i + 1)
                })
            
            let warnMatch = warningRegex.Match(line)
            if warnMatch.Success then
                findings.Add({
                    Level = Warning
                    Type = "Compiler Warning"
                    Message = warnMatch.Groups.[1].Value
                    Line = line
                    LineNumber = Some (i + 1)
                })

        let errors = findings |> Seq.filter (fun f -> f.Level = Error) |> Seq.length
        let warnings = findings |> Seq.filter (fun f -> f.Level = Warning) |> Seq.length

        { Method = "ASTCheck"
          Findings = findings |> Seq.toList
          ErrorCount = errors
          WarningCount = warnings
          Score = 0.85 }

    // 3. Line-by-Line Analysis
    let validateLineAnalysis (content: string) = 
        // Simple scan without complex regex overhead for speed/redundancy
        let lines = content.Split('\n')
        let findings = ResizeArray<ValidationFinding>()

        for i in 0 .. lines.Length - 1 do
            let line = lines.[i]
            if line.Contains("error:") || line.Contains("** (") then
                findings.Add({ Level = Error; Type = "Line Error"; Message = line.Trim(); Line = line; LineNumber = Some(i+1) })
            else if line.Contains("warning:") || line.Contains("deprecated") then
                findings.Add({ Level = Warning; Type = "Line Warning"; Message = line.Trim(); Line = line; LineNumber = Some(i+1) })

        let errors = findings |> Seq.filter (fun f -> f.Level = Error) |> Seq.length
        let warnings = findings |> Seq.filter (fun f -> f.Level = Warning) |> Seq.length

        { Method = "LineAnalysis"
          Findings = findings |> Seq.toList
          ErrorCount = errors
          WarningCount = warnings
          Score = 0.75 }

    // 4. Binary Scan (Byte sequences)
    let validateBinaryScan (content: string) = 
        // Simulating binary scan by checking raw substrings
        let errorKeywords = ["error:"; "** ("; "ERROR"; "Failed"]
        let warningKeywords = ["warning:"; "deprecated"; "unused"]
        
        let countOccurrences (text: string) (keyword: string) = 
            // Split by keyword to count occurrences - 1
            text.Split([|keyword|], StringSplitOptions.None).Length - 1

        let errorCount = errorKeywords |> List.sumBy (countOccurrences content)
        let warningCount = warningKeywords |> List.sumBy (countOccurrences content)

        // Note: Binary scan doesn't easily give line numbers or messages, just counts
        { Method = "BinaryScan"
          Findings = [] // No detailed findings for this method in this implementation
          ErrorCount = errorCount
          WarningCount = warningCount
          Score = 0.65 }

    // 5. Statistical Analysis
    let validateStatistical (content: string) = 
        let lines = content.Split('\n')
        let totalLines = lines.Length
        
        let errorIndicators = ["error"; "Error"; "ERROR"; "failed"; "Failed"]
        let warningIndicators = ["warning"; "Warning"; "deprecated"]
        
        let countLinesContaining (indicators: string list) = 
            lines |> Array.filter (fun l -> indicators |> List.exists (fun ind -> l.Contains(ind))) |> Array.length

        let errCount = countLinesContaining errorIndicators
        let warnCount = countLinesContaining warningIndicators

        { Method = "Statistical"
          Findings = [] 
          ErrorCount = errCount
          WarningCount = warnCount
          Score = 0.70 }

// =================================================================================================
// CONSENSUS LOGIC
// =================================================================================================

module Consensus = 
    
    let check (results: ValidationResult list) = 
        let errorCounts = results |> List.map (fun r -> r.ErrorCount)
        let warningCounts = results |> List.map (fun r -> r.WarningCount)
        
        let uniqueErrors = errorCounts |> List.distinct
        let uniqueWarnings = warningCounts |> List.distinct
        
        let exactConsensus = uniqueErrors.Length = 1 && uniqueWarnings.Length = 1
        
        // Variance check
        let maxErr = if errorCounts.IsEmpty then 0 else List.max errorCounts
        let minErr = if errorCounts.IsEmpty then 0 else List.min errorCounts
        let errVariance = if maxErr > 0 then float(maxErr - minErr) / float(maxErr) else 0.0
        
        let varianceConsensus = errVariance < 0.10 // 10% tolerance

        { Agreement = exactConsensus || varianceConsensus
          ExactConsensus = exactConsensus
          VarianceConsensus = varianceConsensus
          Results = results |> List.map (fun r -> r.Method, r) |> Map.ofList }

// =================================================================================================
// INTELLIGENT RCA (Gemini)
// =================================================================================================

module GeminiRCA = 
    
    let analyzeAsync (logContent: string) (findings: ValidationFinding list) = 
        task {
            try
                let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
                if String.IsNullOrEmpty(apiKey) then
                    return "RCA Skipped: OPENROUTER_API_KEY not found."
                else
                    let config = { 
                        ApiKey = apiKey
                        BaseUrl = "https://openrouter.ai/api/v1/"
                        DefaultModel = "google/gemini-2.0-flash-exp" 
                    } 
                    
                    let client = new OpenRouterClient(config)
                    
                    // Summarize errors
                    let errorSummary = 
                        findings 
                        |> List.filter (fun f -> f.Level = Error)
                        |> List.truncate 20 // Limit context
                        |> List.map (fun f -> sprintf "- %s: %s" f.Type f.Message)
                        |> String.concat "\n"
                        
                    let prompt = 
                        sprintf 
                            """ANALYSIS REQUEST: Compilation Failure with 7x7 Impact Matrix
                            
                            CONTEXT:
                            The system is failing compilation. Below are the detected errors from the log.
                            
                            ERRORS:
                            %s
                            
                            TASK:
                            Perform a deep "7x7" analysis:
                            
                            PART 1: 7 LEVELS OF ROOT CAUSE ANALYSIS (RCA)
                            1. Atomic: (Syntax/Typo)
                            2. Component: (Logic/Function flow)
                            3. Module: (Contract/API mismatches)
                            4. Subsystem: (Integration/Port binding)
                            5. System: (Architecture/Global State/OTP)
                            6. Environment: (Config/Dependencies/Nix)
                            7. Existential: (Design Flaw/Legacy/Drift)
                            
                            PART 2: 7 DIMENSIONS OF CODE INTERACTION IMPACT
                            1. Local Scope
                            2. Caller Scope
                            3. Module State
                            4. Database Schema (Ash/Ecto)
                            5. Network/API (Zenoh/Phoenix)
                            6. User Experience
                            7. Safety/Security Invariant (STAMP)
                            
                            PART 3: SOLUTION
                            - Suggest a specific code fix.
                            
                            RESPONSE FORMAT:
                            Markdown.
                            """ errorSummary

                    return! client.CompleteAsync(prompt)
            with ex ->
                return sprintf "RCA Failed: %s" ex.Message
        }

// =================================================================================================
// MAIN EXECUTION
// =================================================================================================

let args = Environment.GetCommandLineArgs()
// Simple arg parsing: fsi script.fsx --log <file>
let logFileIdx = Array.IndexOf(args, "--log")
let logFile = 
    if logFileIdx > -1 && logFileIdx + 1 < args.Length then 
        args.[logFileIdx + 1] 
    else 
        "./data/tmp/1-compile.log"

printfn "🛡️  F# Comprehensive Compilation Validator (CEPAF-Integrated)"
printfn "📅  Timestamp: %s" (DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"))

if File.Exists(logFile) then
    printfn "📄  Reading log: %s" logFile
    let content = File.ReadAllText(logFile)
    
    printfn "🔍  Running multi-method validation..."
    
    // Run validators in parallel? (Sequential for simplicity/clarity in script)
    let results = [
        Validators.validatePatternMatch content
        Validators.validateAstCheck content
        Validators.validateLineAnalysis content
        Validators.validateBinaryScan content
        Validators.validateStatistical content
    ]
    
    for r in results do
        printfn "   Running %s validation... Errors: %d, Warnings: %d" r.Method r.ErrorCount r.WarningCount

    let consensus = Consensus.check results
    
    if consensus.Agreement && (consensus.Results.["PatternMatch"].ErrorCount = 0) then
        printfn "✅  Validation PASSED - Consensus Achieved (Errors: 0)"
        exit 0
    else
        printfn "❌  Validation FAILED"
        printfn "📊  Consensus: %b (Exact: %b, Variance: %b)" consensus.Agreement consensus.ExactConsensus consensus.VarianceConsensus
        
        // Get unique findings for RCA
        let allFindings = 
            results 
            |> List.collect (fun r -> r.Findings)
            |> List.distinctBy (fun f -> f.Message)
            
        let errorCount = results |> List.map (fun r -> r.ErrorCount) |> List.max
        
        printfn "📊  Max Errors Detected: %d" errorCount
        
        if errorCount > 0 then
            printfn "🤖  Initiating Gemini RCA via OpenRouter..."
            let rcaTask = GeminiRCA.analyzeAsync content allFindings
            let rca = rcaTask.GetAwaiter().GetResult()
            
            printfn "\n================ [ GEMINI RCA ] ================"
            printfn "%s" rca
            printfn "==============================================="
            
        exit 1
else
    printfn "❌  Log file not found: %s" logFile
    exit 1
