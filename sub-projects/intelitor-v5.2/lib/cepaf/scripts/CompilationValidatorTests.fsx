#!/usr/bin/env dotnet fsi
#r "nuget: Expecto, 10.1.0"
#load "CompilationValidatorCore.fsx"

open Expecto
open Indrajaal.Validation

let tests =
  testList "CompilationValidator Tests" [
    test "Pattern Matching: Critical Error" {
      let line = "== Compilation error in file lib/foo.ex =="
      match line with
      | Patterns.IsCritical _ -> ()
      | _ -> failwith "Failed to match critical error"
    }

    test "Pattern Matching: Standard Error" {
      let line = "error: undefined function"
      match line with
      | Patterns.IsError _ -> ()
      | _ -> failwith "Failed to match standard error"
    }

    test "Pattern Matching: Warning" {
      let line = "warning: variable unused"
      match line with
      | Patterns.IsWarning _ -> ()
      | _ -> failwith "Failed to match warning"
    }

    test "BatchSupervisor: Aggregation" {
      let supervisor = BatchSupervisor(1)
      supervisor.Process(1, "error: function undefined")
      supervisor.Process(2, "warning: unused")
      supervisor.Flush()
      
      let (stats, issues, consensus, cost) = supervisor.GetReport()
      
      Expect.equal stats.ErrorCount 1 "Should count 1 error"
      Expect.equal stats.WarningCount 1 "Should count 1 warning"
      Expect.isFalse consensus "Consensus should be false due to errors"
    }

    test "BatchSupervisor: Binary Scan" {
      let supervisor = BatchSupervisor(1)
      supervisor.Process(1, "Normal line")
      supervisor.Process(2, "Corrupt \u0000 Line")
      supervisor.Flush()
      
      let (stats, _, _, _) = supervisor.GetReport()
      Expect.equal stats.NullByteCount 1 "Should detect 1 null byte line"
    }
  ]

runTestsWithCLIArgs [] [||] tests