#!/usr/bin/env dotnet fsi
/// ============================================================================
/// Cortex Capability Benchmarks (F# / SIL-6 Biomorphic Edition)
/// ============================================================================
/// 
/// PURPOSE:
///   Measure the cognitive capability of the tiered model strategy.
///   Verify fallback chains and cost optimization.
///
/// USAGE:
///   dotnet fsi CortexBenchmarks.fsx --mode comprehensive

#load "CompilationValidatorCore.fsx"

open System
open System.Diagnostics
open Indrajaal.Validation

// ============================================================ 
// 1. Benchmark Scenarios
// ============================================================ 

type Scenario = {
    Name: string
    Input: LogIssue
    ExpectedTier: Cortex.ModelTier
    FailMistral: bool
    FailGemini: bool
}

let scenarios = [
    {
        Name = "Simple Syntax Error"
        Input = { Type = SyntaxError; Severity = Low; Message = "syntax error: missing token"; LineNumber = 10; RawLine = "syntax error"; Count = 1 }
        ExpectedTier = Cortex.Free // Should be skipped or handled by local/free
        FailMistral = false
        FailGemini = false
    }
    {
        Name = "Complex Critical Error"
        Input = { Type = CompilationError; Severity = Critical; Message = "** (CompileError) Critical failure"; LineNumber = 50; RawLine = "** (CompileError) Critical failure"; Count = 1 }
        ExpectedTier = Cortex.High // Should escalate to Claude
        FailMistral = true // Simulate Mistral failure
        FailGemini = true  // Simulate Gemini failure
    }
    {
        Name = "Mistral Service Outage"
        Input = { Type = UndefinedFunction; Severity = High; Message = "undefined function foo/0"; LineNumber = 20; RawLine = "undefined function"; Count = 1 }
        ExpectedTier = Cortex.Free // Should be handled by Gemini (Free tier backup)
        FailMistral = true
        FailGemini = false
    }
]

// ============================================================ 
// 2. Execution Engine
// ============================================================ 

let runBenchmark (scenario: Scenario) = async {
    printfn "\n🧪 Running Scenario: %s" scenario.Name
    
    // Inject Faults
    Environment.SetEnvironmentVariable("SIM_FAIL_MISTRAL", if scenario.FailMistral then "true" else "false")
    Environment.SetEnvironmentVariable("SIM_FAIL_GEMINI", if scenario.FailGemini then "true" else "false")
    
    let sw = Stopwatch.StartNew()
    let! result = Cortex.analyzeError scenario.Input
    sw.Stop()
    
    printfn "   Result: %s" result
    printfn "   Time: %dms" sw.ElapsedMilliseconds
    
    // Reset Faults
    Environment.SetEnvironmentVariable("SIM_FAIL_MISTRAL", "false")
    Environment.SetEnvironmentVariable("SIM_FAIL_GEMINI", "false")
}

// ============================================================ 
// 3. Main
// ============================================================ 

let main() = async {
    printfn "🚀 Starting Cortex Benchmarks..."
    
    for scenario in scenarios do
        do! runBenchmark scenario
        
    printfn "\n✅ Benchmarks Complete"
}

main() |> Async.RunSynchronously