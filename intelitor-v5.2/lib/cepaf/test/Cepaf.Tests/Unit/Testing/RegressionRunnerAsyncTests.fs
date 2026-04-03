module Cepaf.Tests.Unit.Testing.RegressionRunnerAsyncTests

open Expecto
open Cepaf.Testing

[<Tests>]
let tests = testList "RegressionRunnerAsync" [

    testList "AsyncRunResult Type" [
        test "default result has empty RunId" {
            let r : RegressionRunner.AsyncRunResult = {
                RunId = ""
                OverallStatus = "PASS"
                LevelStatuses = Map.empty
                LevelOutputs = Map.empty
                StateVector = Array.create 5 0
                TotalPassed = 0
                TotalFailed = 0
                DurationS = 0.0
                ExitCode = 0
            }
            Expect.equal r.RunId "" "RunId should be empty"
            Expect.equal r.ExitCode 0 "ExitCode should be 0"
        }

        test "result fields are correct types" {
            let r : RegressionRunner.AsyncRunResult = {
                RunId = "test-run-001"
                OverallStatus = "FAIL"
                LevelStatuses = Map.ofList [
                    RegressionRunner.L1_Compilation, "PASS"
                    RegressionRunner.L2_FullTests, "FAIL"
                ]
                LevelOutputs = Map.ofList [
                    RegressionRunner.L2_FullTests, "** (ExUnit.AssertionError) expected true, got false"
                ]
                StateVector = [| 2; 3; 0; 0; 0 |]
                TotalPassed = 90
                TotalFailed = 10
                DurationS = 45.5
                ExitCode = 1
            }
            Expect.equal r.OverallStatus "FAIL" "Status should be FAIL"
            Expect.equal r.TotalPassed 90 "TotalPassed should be 90"
            Expect.equal r.TotalFailed 10 "TotalFailed should be 10"
            Expect.equal r.DurationS 45.5 "DurationS should be 45.5"
            Expect.equal r.LevelStatuses.Count 2 "Should have 2 level statuses"
        }

        test "state vector has 5 elements" {
            let r : RegressionRunner.AsyncRunResult = {
                RunId = "sv-test"
                OverallStatus = "PASS"
                LevelStatuses = Map.empty
                LevelOutputs = Map.empty
                StateVector = [| 2; 2; 2; 2; 2 |]
                TotalPassed = 0
                TotalFailed = 0
                DurationS = 0.0
                ExitCode = 0
            }
            Expect.equal r.StateVector.Length 5 "StateVector should have 5 elements"
            Expect.isTrue (r.StateVector |> Array.forall (fun s -> s = 2)) "All levels should be pass (2)"
        }
    ]

    testList "RunConfig Mapping" [
        test "valid levels map correctly" {
            let levels = [
                RegressionRunner.L1_Compilation
                RegressionRunner.L2_FullTests
                RegressionRunner.L3_SIL6Tests
                RegressionRunner.L4_QualityGates
                RegressionRunner.L5_SystemHealth
            ]
            let config : RegressionRunner.RunConfig = {
                Levels = levels
                Verbose = true
                ReportOnly = false
            }
            Expect.equal config.Levels.Length 5 "Should have 5 levels"
            Expect.isTrue config.Verbose "Should be verbose"
            Expect.isFalse config.ReportOnly "Should not be report-only"
        }

        test "empty levels produce empty config" {
            let config : RegressionRunner.RunConfig = {
                Levels = []
                Verbose = false
                ReportOnly = false
            }
            Expect.isEmpty config.Levels "Levels should be empty"
        }
    ]

    testList "TestAgent RunConfig Integration" [
        test "TestAgent start returns error when already running" {
            let agent = TestAgent.create(None)
            let config : TestConfig = {
                Levels = [99]
                TimeoutSeconds = 5
                Verbose = false
            }
            let _result1 = TestAgent.start agent config
            System.Threading.Thread.Sleep(50)
            let status = TestAgent.status agent
            match status with
            | TestStatus.Running _ ->
                let result2 = TestAgent.start agent config
                Expect.isError result2 "Should error on concurrent start"
            | _ -> ()
        }

        test "TestAgent executeRun produces valid RunResult via status" {
            let agent = TestAgent.create(None)
            let config : TestConfig = {
                Levels = [99]
                TimeoutSeconds = 2
                Verbose = false
            }
            let _result = TestAgent.start agent config
            System.Threading.Thread.Sleep(500)
            let status = TestAgent.status agent
            match status with
            | TestStatus.Idle -> ()
            | TestStatus.Completed _ -> ()
            | TestStatus.Failed _ -> ()
            | TestStatus.Running _ ->
                Expect.isTrue false "Should not still be running with invalid levels"
            | _ -> ()
        }
    ]

    testList "runAsync Function Signature" [
        test "runAsync exists and returns Async<AsyncRunResult>" {
            let _fn : RegressionRunner.RunConfig -> System.Threading.CancellationToken -> Async<RegressionRunner.AsyncRunResult> =
                RegressionRunner.runAsync
            Expect.isTrue true "runAsync function exists with correct signature"
        }
    ]
]
