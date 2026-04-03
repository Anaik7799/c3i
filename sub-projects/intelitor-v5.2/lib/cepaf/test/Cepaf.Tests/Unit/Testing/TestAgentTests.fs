module Cepaf.Tests.Unit.Testing.TestAgentTests

open Expecto
open Cepaf.Testing

[<Tests>]
let tests = testList "TestAgent" [

    testList "Types" [
        test "TestConfig has expected fields" {
            let config : TestConfig = {
                Levels = [1; 2; 3]
                TimeoutSeconds = 900
                Verbose = false
            }
            Expect.equal config.Levels [1; 2; 3] "Levels should match"
            Expect.equal config.TimeoutSeconds 900 "Timeout should match"
            Expect.isFalse config.Verbose "Verbose should be false"
        }

        test "TestConfig default all levels" {
            let config : TestConfig = {
                Levels = [1; 2; 3; 4; 5]
                TimeoutSeconds = 900
                Verbose = false
            }
            Expect.equal config.Levels.Length 5 "Should have all 5 levels"
        }

        test "LevelStatus DU has all variants" {
            let pending = LevelStatus.Pending
            let running = LevelStatus.Run
            let pass = LevelStatus.Pass
            let fail = LevelStatus.Fail "some error"
            let skip = LevelStatus.Skip "reason"
            Expect.isTrue (match pending with LevelStatus.Pending -> true | _ -> false) "Pending"
            Expect.isTrue (match running with LevelStatus.Run -> true | _ -> false) "Running"
            Expect.isTrue (match pass with LevelStatus.Pass -> true | _ -> false) "Pass"
            Expect.isTrue (match skip with LevelStatus.Skip _ -> true | _ -> false) "Skip"
            match fail with
            | LevelStatus.Fail msg -> Expect.equal msg "some error" "Fail msg"
            | _ -> failtest "Expected Fail"
        }

        test "TestStatus DU has all variants" {
            let idle = TestStatus.Idle
            let failed = TestStatus.Failed ("rid", "err")
            Expect.isTrue (match idle with TestStatus.Idle -> true | _ -> false) "Idle"
            match failed with
            | TestStatus.Failed (rid, msg) -> 
                Expect.equal rid "rid" "Failed rid"
                Expect.equal msg "err" "Failed msg"
            | _ -> failtest "Expected Failed"
        }
    ]

    testList "Agent Lifecycle" [
        test "create returns agent handle" {
            let agent = TestAgent.create(None)
            Expect.isNotNull (box agent) "Agent should not be null"
        }

        test "initial status is Idle" {
            let agent = TestAgent.create(None)
            let s = TestAgent.status agent
            Expect.equal s TestStatus.Idle "Initial status should be Idle"
        }

        test "results empty initially" {
            let agent = TestAgent.create(None)
            let r = TestAgent.results agent 10
            Expect.isEmpty r "No results initially"
        }

        test "stop when idle returns error" {
            let agent = TestAgent.create(None)
            let result = TestAgent.stop agent ""
            match result with
            | Error msg -> Expect.stringContains msg "No matching run in progress" "Should report no run"
            | Ok _ -> failtest "Expected error when stopping idle agent"
        }
    ]

    testList "Checkpoint IDs" [
        test "checkpoint IDs follow CP-AGENT format" {
            Expect.equal TestAgent.Checkpoints.AGENT_START "CP-AGENT-START" "Start checkpoint"
            Expect.equal TestAgent.Checkpoints.AGENT_RUNNING "CP-AGENT-RUNNING" "Running checkpoint"
            Expect.equal TestAgent.Checkpoints.AGENT_DONE "CP-AGENT-DONE" "Done checkpoint"
            Expect.equal TestAgent.Checkpoints.AGENT_STOP "CP-AGENT-STOP" "Stop checkpoint"
            Expect.equal TestAgent.Checkpoints.AGENT_ERROR "CP-AGENT-ERROR" "Error checkpoint"
        }

        test "topic start follows indrajaal convention" {
            let topic = TestAgent.Checkpoints.topicStart "run-123"
            Expect.stringStarts topic "indrajaal/agent/test/run-123/start" "Topic should match"
        }

        test "all topic functions produce valid paths" {
            let runId = "run-test-001"
            let topics = [
                TestAgent.Checkpoints.topicStart runId
                TestAgent.Checkpoints.topicStatus runId
                TestAgent.Checkpoints.topicDone runId
                TestAgent.Checkpoints.topicError runId
            ]
            for t in topics do
                Expect.isTrue (t.Split('/').Length <= 6) (sprintf "Topic depth <= 6: %s" t)
        }
    ]

    testList "JSON Serialization" [
        test "statusToJson Idle" {
            let json = TestAgent.statusToJson TestStatus.Idle
            Expect.stringContains json "\"idle\"" "Should contain idle"
        }

        test "statusToJson Failed" {
            let json = TestAgent.statusToJson (TestStatus.Failed ("rid", "test error"))
            Expect.stringContains json "\"failed\"" "Should contain failed"
            Expect.stringContains json "test error" "Should contain error message"
        }

        test "statusToJson Completed" {
            let result : RunResult = {
                RunId = "run-test"
                Config = { Levels = [1;2]; TimeoutSeconds = 60; Verbose = false }
                StartTime = System.DateTime.UtcNow
                EndTime = System.DateTime.UtcNow
                DurationMs = 1234L
                ExitCode = 0
                LevelResults = Map.empty
                StateVector = [|2; 2; 0; 0; 0|]
            }
            let json = TestAgent.statusToJson (TestStatus.Completed ("run-test", result))
            Expect.stringContains json "\"completed\"" "Should contain completed"
            Expect.stringContains json "run-test" "Should contain run_id"
        }

        test "resultToJson formats correctly" {
            let result : RunResult = {
                RunId = "run-json-test"
                Config = { Levels = [1]; TimeoutSeconds = 60; Verbose = false }
                StartTime = System.DateTime.UtcNow
                EndTime = System.DateTime.UtcNow
                DurationMs = 500L
                ExitCode = 0
                LevelResults = Map.ofList [
                    1, { Level = 1; Status = LevelStatus.Pass; DurationMs = 500L; Details = "ok" }
                ]
                StateVector = [|2; 0; 0; 0; 0|]
            }
            let json = TestAgent.resultToJson result
            Expect.stringContains json "run-json-test" "Should contain run_id"
            Expect.stringContains json "\"PASS\"" "Should contain level status"
        }
    ]
]
