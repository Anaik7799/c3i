module Cepaf.Tests.Unit.Testing.TestToolsTests

open Expecto
open Cepaf.Sentinel.MCP.Tools

[<Tests>]
let tests = testList "TestTools" [

    testList "Tool Definitions" [
        test "has 5 tool definitions" {
            Expect.equal TestTools.toolDefinitions.Length 5 "Should have 5 tools"
        }

        test "tool names follow convention" {
            let names = TestTools.toolDefinitions |> List.map (fun t -> t.Name)
            Expect.contains names "test_fsharp_start" "Should have start"
            Expect.contains names "test_fsharp_stop" "Should have stop"
            Expect.contains names "test_fsharp_status" "Should have status"
            Expect.contains names "test_fsharp_results" "Should have results"
        }

        test "all tools have descriptions" {
            for tool in TestTools.toolDefinitions do
                Expect.isTrue (tool.Description.Length > 10) (sprintf "Tool %s should have description" tool.Name)
        }

        test "all tools have input schemas" {
            for tool in TestTools.toolDefinitions do
                Expect.isNotNull (box tool.InputSchema) (sprintf "Tool %s should have schema" tool.Name)
        }
    ]

    testList "State Management" [
        test "createState returns valid state" {
            let state = TestTools.createState()
            Expect.isNotNull (box state.Agent) "Agent should not be null"
        }
    ]

    testList "Dispatch" [
        test "dispatch returns None for unknown tool" {
            let state = TestTools.createState()
            let result = TestTools.dispatch state "unknown_tool" None None
            Expect.isNone result "Unknown tool should return None"
        }

        test "dispatch returns Some for test_fsharp_status" {
            let state = TestTools.createState()
            let result = TestTools.dispatch state "test_fsharp_status" None None
            Expect.isSome result "Status should return Some"
            let json = result.Value
            Expect.stringContains json "idle" "Initial status should be idle"
        }

        test "dispatch returns Some for test_fsharp_results" {
            let state = TestTools.createState()
            let result = TestTools.dispatch state "test_fsharp_results" None None
            Expect.isSome result "Results should return Some"
            let json = result.Value
            // MCP toolResult wraps inner JSON inside a "text" field, escaping quotes
            Expect.stringContains json "count" "Should contain count field"
            Expect.stringContains json "results" "Should contain results field"
        }

        test "dispatch test_fsharp_stop when idle returns error" {
            let state = TestTools.createState()
            let result = TestTools.dispatch state "test_fsharp_stop" None None
            Expect.isSome result "Stop should return Some"
            let json = result.Value
            Expect.stringContains json "isError" "Should contain isError flag"
        }
    ]
]
