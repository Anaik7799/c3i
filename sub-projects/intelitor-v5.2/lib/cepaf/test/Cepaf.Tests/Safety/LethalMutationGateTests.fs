namespace Cepaf.Tests.Safety

open System
open Expecto
open Cepaf.Safety
open Cepaf.Modules.ConstraintValidator

module LethalMutationGateTests =

    [<Tests>]
    let tests =
        testList "Safety/LethalMutationGate" [
            
            test "Survival combined with Survival is Survival" {
                let v1 = LethalMutationGate.MutationVerdict.Survival
                let v2 = LethalMutationGate.MutationVerdict.Survival
                let result = LethalMutationGate.combine v1 v2
                Expect.equal result LethalMutationGate.MutationVerdict.Survival "Should be Survival"
            }

            test "Survival combined with Lethal is Lethal" {
                let violation = { 
                    ConstraintId = "SC-TEST-001"
                    Message = "Test"
                    Severity = Severity.High
                    Timestamp = DateTime.UtcNow
                    Context = Map.empty 
                }
                let v1 = LethalMutationGate.MutationVerdict.Survival
                let v2 = LethalMutationGate.MutationVerdict.Lethal [violation]
                let result = LethalMutationGate.combine v1 v2
                match result with
                | LethalMutationGate.MutationVerdict.Lethal d -> Expect.equal d [violation] "Should contain violation"
                | _ -> failwith "Expected Lethal"
            }

            test "Monoidal accumulation: Lethal + Lethal aggregates violations" {
                let v1_rec = { ConstraintId = "SC-1"; Message = "Err1"; Severity = Severity.Medium; Timestamp = DateTime.UtcNow; Context = Map.empty }
                let v2_rec = { ConstraintId = "SC-2"; Message = "Err2"; Severity = Severity.Medium; Timestamp = DateTime.UtcNow; Context = Map.empty }
                let v1 = LethalMutationGate.MutationVerdict.Lethal [v1_rec]
                let v2 = LethalMutationGate.MutationVerdict.Lethal [v2_rec]
                let result = LethalMutationGate.combine v1 v2
                match result with
                | LethalMutationGate.MutationVerdict.Lethal d -> 
                    Expect.equal d.Length 2 "Should have 2 violations"
                    Expect.contains d v1_rec "Should contain Err1"
                    Expect.contains d v2_rec "Should contain Err2"
                | _ -> failwith "Expected Lethal"
            }

            test "pureEval detects lethal rm -rf command" {
                let mutation = "rm -rf /"
                let result = LethalMutationGate.pureEval mutation 0.1
                match result with
                | LethalMutationGate.MutationVerdict.Lethal d -> 
                    Expect.isTrue (d |> List.exists (fun v -> v.ConstraintId = "SC-GEM-001")) "Should detect SC-GEM-001"
                | _ -> failwith "Expected Lethal for dangerous command"
            }

            test "generateDefectMap aggregates multiple validation results" {
                let results = [
                    Valid
                    Invalid [{ ConstraintId = "SC-A"; Message = "M1"; Severity = Severity.Low; Timestamp = DateTime.UtcNow; Context = Map.empty }]
                    Valid
                    Invalid [{ ConstraintId = "SC-B"; Message = "M2"; Severity = Severity.Low; Timestamp = DateTime.UtcNow; Context = Map.empty }]
                ]
                let result = LethalMutationGate.generateDefectMap results
                match result with
                | LethalMutationGate.MutationVerdict.Lethal d -> 
                    Expect.equal d.Length 2 "Should aggregate both invalid results"
                | _ -> failwith "Expected Lethal"
            }
        ]
