#!/usr/bin/env dotnet fsi
#load "CompilationValidatorCore.fsx"

open System
open System.IO
open System.Text.Json
open Indrajaal.Validation

// ============================================================ 
// CLI Execution Pipeline
// ============================================================ 

let processFile (path: string) = async {
    if not (File.Exists path) then
        printfn "❌ Log file not found: %s" path
        return 1
    else
        printfn "🚀 Starting Smart Validation on %s" path
        
        // Use the new SystemSupervisor for full coordination
        let supervisor = SystemSupervisor()
        let! (stats, issues, consensus) = supervisor.ExecuteFullAudit(path)
        
        printfn "\n📊 FINAL REPORT"
        printfn "================="
        printfn "Total Lines: %d" stats.TotalLines
        printfn "Errors:      %d" stats.ErrorCount
        printfn "Warnings:    %d" stats.WarningCount
        printfn "Nulls:       %d" stats.NullByteCount
        printfn "Consensus:   %b" consensus
        printfn "AI Cost:     $%.6f (est)" (float stats.TotalLines * 0.000001) // Mock est
        
        if stats.ErrorCount > 0 || stats.NullByteCount > 0 then return 1 else return 0
}

let args = fsi.CommandLineArgs |> Array.skip 1
let result = 
    match args with
    | [| "--log"; path |] -> 
        processFile path |> Async.RunSynchronously
    | _ ->
        printfn "Usage: comprehensive_validator.fsx --log <path>"
        // Default fallback for dev
        processFile "1-compile.log" |> Async.RunSynchronously

exit result
