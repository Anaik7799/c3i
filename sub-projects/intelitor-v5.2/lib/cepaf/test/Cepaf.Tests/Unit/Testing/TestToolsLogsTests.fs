module Cepaf.Tests.Unit.Testing.TestToolsLogsTests

open System
open Expecto
open Cepaf.Sentinel.MCP.Tools
open Cepaf.Testing

[<Tests>]
let tests = testList "TestToolsLogs" [

    testList "Tool Definitions" [
        test "has 5 tool definitions (Phase 4)" {
            Expect.equal TestTools.toolDefinitions.Length 5 "Should have 5 tools"
        }

        test "test_fsharp_logs tool exists" {
            let names = TestTools.toolDefinitions |> List.map (fun t -> t.Name)
            Expect.contains names "test_fsharp_logs" "Should have logs tool"
        }

        test "test_fsharp_logs has description" {
            let tool = TestTools.toolDefinitions |> List.find (fun t -> t.Name = "test_fsharp_logs")
            Expect.isTrue (tool.Description.Length > 10) "Logs tool should have description"
        }
    ]

    testList "Log Buffer" [
        test "createState has empty log buffer" {
            let state = TestTools.createState()
            Expect.equal state.LogBuffer.Count 0 "Buffer should be empty"
        }

        test "addLogEntry adds to buffer" {
            let state = TestTools.createState()
            let entry : TestTools.LogEntry = {
                Timestamp = DateTime.UtcNow
                RunId = "test-run-001"
                Level = 2
                Category = "FAIL"
                Message = "Test assertion failed"
            }
            TestTools.addLogEntry state entry
            Expect.equal state.LogBuffer.Count 1 "Buffer should have 1 entry"
        }

        test "buffer caps at 100 entries" {
            let state = TestTools.createState()
            for i in 1..120 do
                TestTools.addLogEntry state {
                    Timestamp = DateTime.UtcNow
                    RunId = sprintf "run-%d" i
                    Level = 1
                    Category = "FAIL"
                    Message = sprintf "Error %d" i
                }
            Expect.equal state.LogBuffer.Count 100 "Buffer should cap at 100"
            // Most recent should be the last added
            let last = state.LogBuffer.[99]
            Expect.equal last.RunId "run-120" "Last entry should be most recent"
        }

        test "oldest entries are evicted first" {
            let state = TestTools.createState()
            for i in 1..105 do
                TestTools.addLogEntry state {
                    Timestamp = DateTime.UtcNow
                    RunId = sprintf "run-%d" i
                    Level = 1
                    Category = "FAIL"
                    Message = sprintf "Error %d" i
                }
            // First entry should be run-6 (run-1 through run-5 evicted)
            let first = state.LogBuffer.[0]
            Expect.equal first.RunId "run-6" "Oldest retained should be run-6"
        }
    ]

    testList "Dispatch Logs" [
        test "dispatch returns Some for test_fsharp_logs" {
            let state = TestTools.createState()
            let result = TestTools.dispatch state "test_fsharp_logs" None None
            Expect.isSome result "Logs should return Some"
            let json = result.Value
            Expect.stringContains json "count" "Should contain count"
            Expect.stringContains json "logs" "Should contain logs"
            Expect.stringContains json "total_buffered" "Should contain total_buffered"
        }

        test "dispatch logs returns empty when no failures" {
            let state = TestTools.createState()
            let result = TestTools.dispatch state "test_fsharp_logs" None None
            Expect.isSome result "Should return Some"
            let json = result.Value
            // MCP toolResult wraps inner JSON, escaping quotes as \u0022
            Expect.stringContains json "count" "Should contain count field"
            Expect.stringContains json "logs" "Should contain logs array"
        }
    ]

    testList "Buffer Failures" [
        test "bufferFailures extracts failures from RunResult" {
            let state = TestTools.createState()
            let result : RunResult = {
                RunId = "test-buf-001"
                Config = { Levels = [1;2]; TimeoutSeconds = 60; Verbose = false }
                StartTime = DateTime.UtcNow.AddSeconds(-10.0)
                EndTime = DateTime.UtcNow
                DurationMs = 10000L
                ExitCode = 1
                LevelResults = Map.ofList [
                    1, { Level = 1; Status = LevelStatus.Pass; DurationMs = 3000L; Details = "ok" }
                    2, { Level = 2; Status = LevelStatus.Fail "assertion error: expected 1 got 2"; DurationMs = 7000L; Details = "fail details" }
                ]
                StateVector = [| 2; 3; 0; 0; 0 |]
            }
            TestTools.bufferFailures state result
            Expect.equal state.LogBuffer.Count 1 "Should buffer 1 failure"
            Expect.equal state.LogBuffer.[0].Level 2 "Failure should be from level 2"
            // After SC-MCP-TEST-005, bufferFailures uses lr.Details (subprocess output) not DU status string
            Expect.stringContains state.LogBuffer.[0].Message "fail details" "Should contain level Details (subprocess output)"
        }

        test "bufferFailures ignores passing levels" {
            let state = TestTools.createState()
            let result : RunResult = {
                RunId = "test-buf-002"
                Config = { Levels = [1]; TimeoutSeconds = 60; Verbose = false }
                StartTime = DateTime.UtcNow
                EndTime = DateTime.UtcNow
                DurationMs = 1000L
                ExitCode = 0
                LevelResults = Map.ofList [
                    1, { Level = 1; Status = LevelStatus.Pass; DurationMs = 1000L; Details = "all good" }
                ]
                StateVector = [| 2; 0; 0; 0; 0 |]
            }
            TestTools.bufferFailures state result
            Expect.equal state.LogBuffer.Count 0 "Should not buffer any entries for passing results"
        }
    ]
]
