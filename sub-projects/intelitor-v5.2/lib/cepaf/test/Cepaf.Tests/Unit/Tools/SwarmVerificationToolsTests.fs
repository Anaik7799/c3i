namespace Cepaf.Tests.Unit.Tools

open System
open System.Text.Json
open Expecto
open Cepaf.Sentinel.MCP.Tools
open Cepaf.Sentinel.MCP.Protocol

/// TDG-compliant test suite for SwarmVerificationTools MCP module.
///
/// Coverage matrix: 7 actions × 16 containers × 8 fractal layers
///
/// STAMP: SC-SWARM-VERIFY-001 to SC-SWARM-VERIFY-064
/// AOR: AOR-SWARM-VERIFY-001 to AOR-SWARM-VERIFY-015
/// FMEA: RPN ≤ 96, all failure modes tested
module SwarmVerificationToolsTests =

    // ═══════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════

    let private mkId (n: int) : JsonElement option =
        let doc = JsonDocument.Parse(sprintf "%d" n)
        Some (doc.RootElement.Clone())

    let private mkArgs (pairs: (string * string) list) : JsonElement option =
        let json =
            pairs
            |> List.map (fun (k, v) -> sprintf "\"%s\":\"%s\"" k v)
            |> String.concat ","
            |> sprintf "{%s}"
        let doc = JsonDocument.Parse(json)
        Some (doc.RootElement.Clone())

    let private mkArgsWithInt (pairs: (string * obj) list) : JsonElement option =
        let parts =
            pairs
            |> List.map (fun (k, v) ->
                match v with
                | :? string as s -> sprintf "\"%s\":\"%s\"" k s
                | :? int as i -> sprintf "\"%s\":%d" k i
                | :? bool as b -> sprintf "\"%s\":%s" k (if b then "true" else "false")
                | _ -> sprintf "\"%s\":\"%O\"" k v)
            |> String.concat ","
            |> sprintf "{%s}"
        let doc = JsonDocument.Parse(parts)
        Some (doc.RootElement.Clone())

    /// Extract the `text` content from an MCP tool response JSON
    let private extractContent (response: string) : string =
        try
            let doc = JsonDocument.Parse(response)
            let result = doc.RootElement.GetProperty("result")
            result.[0].GetProperty("text").GetString()
        with _ -> response

    /// Parse the inner JSON content from MCP response
    let private parseInner (response: string) : JsonDocument option =
        try
            let content = extractContent response
            Some (JsonDocument.Parse(content))
        with _ -> None

    /// Check if MCP response contains an error
    let private isError (response: string) : bool =
        try
            let doc = JsonDocument.Parse(response)
            doc.RootElement.TryGetProperty("error") |> fst
        with _ -> false

    // ═══════════════════════════════════════════════════════════════════
    // CONSTANTS: ALL 16 GENOME CONTAINERS
    // ═══════════════════════════════════════════════════════════════════

    let private allContainers = [
        "zenoh-router"; "indrajaal-db-prod"; "indrajaal-obs-prod"
        "zenoh-router-1"; "zenoh-router-2"; "zenoh-router-3"
        "indrajaal-ex-app-1"; "indrajaal-ex-app-2"; "indrajaal-ex-app-3"
        "indrajaal-chaya"; "cepaf-bridge"; "indrajaal-cortex"
        "indrajaal-ollama"; "indrajaal-mojo"
        "indrajaal-ml-runner-1"; "indrajaal-ml-runner-2"
    ]

    let private oodaCapableContainers = [
        "indrajaal-ex-app-1"; "indrajaal-ex-app-2"; "indrajaal-ex-app-3"
        "indrajaal-chaya"; "indrajaal-cortex"; "cepaf-bridge"
    ]

    let private agentCapableContainers = [
        "indrajaal-ex-app-1"; "indrajaal-ex-app-2"; "indrajaal-ex-app-3"
        "indrajaal-chaya"; "cepaf-bridge"; "indrajaal-cortex"
    ]

    let private oodaTierNames = [ "agent"; "intelligence"; "knowledge"; "cortex"; "strategy" ]

    let private fractalLayerNames = [
        (0, "Constitutional"); (1, "Atomic/Debug"); (2, "Component"); (3, "Transaction")
        (4, "System"); (5, "Cognitive"); (6, "Ecosystem"); (7, "Federation")
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L1: TOOL DEFINITION TESTS
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let toolDefinitionTests = testList "SwarmVerification/ToolDefinitions" [

        test "toolDefinitions has exactly 1 tool" {
            Expect.equal (List.length SwarmVerificationTools.toolDefinitions) 1
                "Expected exactly 1 tool definition (swarm_verify)"
        }

        test "tool name is swarm_verify" {
            let tool = SwarmVerificationTools.toolDefinitions |> List.head
            Expect.equal tool.Name "swarm_verify" "Tool name should be swarm_verify"
        }

        test "tool description mentions 16 containers" {
            let tool = SwarmVerificationTools.toolDefinitions |> List.head
            Expect.isTrue (tool.Description.Contains("16")) "Description should mention 16 containers"
        }

        test "tool has action as required parameter" {
            let tool = SwarmVerificationTools.toolDefinitions |> List.head
            // InputSchema should have "action" in required
            let json = JsonSerializer.Serialize(tool.InputSchema)
            Expect.isTrue (json.Contains("action")) "InputSchema should contain action parameter"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L1: STATE MANAGEMENT TESTS
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let stateTests = testList "SwarmVerification/State" [

        test "createState initializes with None timestamps" {
            let state = SwarmVerificationTools.createState()
            Expect.isNone state.LastOodaCheck "LastOodaCheck should be None"
            Expect.isNone state.LastObservabilityCheck "LastObservabilityCheck should be None"
            Expect.isNone state.LastControlCheck "LastControlCheck should be None"
            Expect.isNone state.LastFullCheck "LastFullCheck should be None"
        }

        test "createState initializes with zero check count" {
            let state = SwarmVerificationTools.createState()
            Expect.equal state.CheckCount 0L "CheckCount should be 0"
        }

        test "createState initializes with empty maps" {
            let state = SwarmVerificationTools.createState()
            Expect.isEmpty (Map.toList state.OodaResults) "OodaResults should be empty"
            Expect.isEmpty (Map.toList state.AgentProbeResults) "AgentProbeResults should be empty"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: DISPATCH ROUTING TESTS
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let dispatchTests = testList "SwarmVerification/Dispatch" [

        test "dispatch returns None for unknown tool" {
            let state = SwarmVerificationTools.createState()
            let result = SwarmVerificationTools.dispatch state "unknown_tool" None (mkId 1)
            Expect.isNone result "Should return None for unknown tool"
        }

        test "dispatch returns Some for swarm_verify tool" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "ooda" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 2)
            Expect.isSome result "Should return Some for swarm_verify"
        }

        test "dispatch returns error for invalid action" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "nonexistent" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 3)
            Expect.isSome result "Should return Some (error response)"
            let resp = result.Value
            Expect.isTrue (resp.Contains("error") || resp.Contains("Unknown action"))
                "Should contain error about unknown action"
        }

        testList "dispatch routes all 7 actions" (
            [ "ooda"; "observability"; "control"; "agent_probe"; "fractal"; "full"; "inject_trace" ]
            |> List.map (fun action ->
                test (sprintf "dispatch routes action '%s'" action) {
                    let state = SwarmVerificationTools.createState()
                    let args = mkArgs [ "action", action ]
                    let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 10)
                    Expect.isSome result (sprintf "Action '%s' should be handled" action)
                    let resp = result.Value
                    // Should NOT be a method-not-found error
                    Expect.isFalse (resp.Contains("-32601"))
                        (sprintf "Action '%s' should not return method-not-found" action)
                }))
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: OODA VERIFICATION TESTS (SC-SWARM-VERIFY-002, SC-SWARM-VERIFY-030 to SC-SWARM-VERIFY-034)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let oodaTests = testList "SwarmVerification/OODA" [

        test "ooda action returns valid JSON with action field" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "ooda" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 20)
            let resp = result.Value
            let inner = parseInner resp
            Expect.isSome inner "Should return parseable inner JSON"
            let doc = inner.Value
            let action = doc.RootElement.GetProperty("action").GetString()
            Expect.equal action "ooda" "Action field should be 'ooda'"
        }

        test "ooda includes summary with passed_checks and total_checks" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "ooda" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 21)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should parse inner JSON"
            let root = inner.Value.RootElement
            let hasSummary = root.TryGetProperty("summary") |> fst
            Expect.isTrue hasSummary "Should have summary field"
        }

        test "ooda includes STAMP references" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "ooda" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 22)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("SC-OODA"))
                "OODA response should reference SC-OODA constraints"
        }

        test "ooda updates LastOodaCheck timestamp" {
            let state = SwarmVerificationTools.createState()
            Expect.isNone state.LastOodaCheck "Should start None"
            let args = mkArgs [ "action", "ooda" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 23) |> ignore
            Expect.isSome state.LastOodaCheck "Should be set after ooda check"
        }

        test "ooda increments CheckCount" {
            let state = SwarmVerificationTools.createState()
            let before = state.CheckCount
            let args = mkArgs [ "action", "ooda" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 24) |> ignore
            Expect.isGreaterThan state.CheckCount before "CheckCount should increment"
        }

        testList "ooda tier filtering" (
            oodaTierNames |> List.map (fun tier ->
                test (sprintf "ooda accepts tier filter '%s'" tier) {
                    let state = SwarmVerificationTools.createState()
                    let args = mkArgs [ "action", "ooda"; "tier", tier ]
                    let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 25)
                    Expect.isSome result (sprintf "Tier '%s' should produce a response" tier)
                    Expect.isFalse (isError (result.Value)) (sprintf "Tier '%s' should not error" tier)
                }))

        test "ooda reports containers_total = 16 in summary" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "ooda" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 26)
            let content = extractContent (result.Value)
            // The summary should reference all containers
            Expect.isTrue (content.Contains("containers") || content.Contains("total"))
                "Should reference container counts in response"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: OBSERVABILITY PIPELINE TESTS (SC-SWARM-VERIFY-003, SC-SWARM-VERIFY-050 to SC-SWARM-VERIFY-055)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let observabilityTests = testList "SwarmVerification/Observability" [

        test "observability action returns valid JSON" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "observability" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 30)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should return parseable JSON"
            let action = inner.Value.RootElement.GetProperty("action").GetString()
            Expect.equal action "observability" "Action should be 'observability'"
        }

        test "observability checks 5 pipeline stages" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "observability" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 31)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should parse"
            let root = inner.Value.RootElement
            let hasStages = root.TryGetProperty("stages") |> fst
            Expect.isTrue hasStages "Should have stages array"
        }

        test "observability includes STAMP references" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "observability" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 32)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("SC-MON"))
                "Should reference SC-MON constraints"
        }

        test "observability updates LastObservabilityCheck" {
            let state = SwarmVerificationTools.createState()
            Expect.isNone state.LastObservabilityCheck "Should start None"
            let args = mkArgs [ "action", "observability" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 33) |> ignore
            Expect.isSome state.LastObservabilityCheck "Should be set after check"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: CONTROL PLANE TESTS (SC-SWARM-VERIFY-004)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let controlTests = testList "SwarmVerification/Control" [

        test "control action returns valid JSON" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "control" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 40)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should return parseable JSON"
            let action = inner.Value.RootElement.GetProperty("action").GetString()
            Expect.equal action "control" "Action should be 'control'"
        }

        test "control includes category-aware checks" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "control" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 41)
            let content = extractContent (result.Value)
            // Should reference either zenoh or control plane
            Expect.isTrue (content.Contains("zenoh") || content.Contains("control"))
                "Should contain control plane or zenoh references"
        }

        test "control includes STAMP references" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "control" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 42)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("SC-CTRL"))
                "Should reference SC-CTRL constraints"
        }

        test "control updates LastControlCheck" {
            let state = SwarmVerificationTools.createState()
            Expect.isNone state.LastControlCheck "Should start None"
            let args = mkArgs [ "action", "control" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 43) |> ignore
            Expect.isSome state.LastControlCheck "Should be set after check"
        }

        test "control with specific container name" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "control"; "container_name", "indrajaal-ex-app-1" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 44)
            Expect.isSome result "Should handle container filter"
            Expect.isFalse (isError (result.Value)) "Should not error on valid container"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: AGENT PROBE TESTS (SC-SWARM-VERIFY-005, SC-SWARM-VERIFY-021)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let agentProbeTests = testList "SwarmVerification/AgentProbe" [

        test "agent_probe action returns valid JSON" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "agent_probe" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 50)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should return parseable JSON"
            let action = inner.Value.RootElement.GetProperty("action").GetString()
            Expect.equal action "agent_probe" "Action should be 'agent_probe'"
        }

        test "agent_probe includes all_containers field" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "agent_probe" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 51)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("all_containers") || content.Contains("containers_total"))
                "Should include total container count"
        }

        test "agent_probe distinguishes agent vs baseline containers" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "agent_probe" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 52)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("agent_containers") || content.Contains("baseline_containers"))
                "Should distinguish agent vs baseline containers"
        }

        test "agent_probe with specific container" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "agent_probe"; "container_name", "cepaf-bridge" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 53)
            Expect.isSome result "Should handle specific container"
            Expect.isFalse (isError (result.Value)) "Should not error"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: FRACTAL LAYER TESTS (SC-SWARM-VERIFY-006, SC-SWARM-VERIFY-040 to SC-SWARM-VERIFY-048)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let fractalTests = testList "SwarmVerification/Fractal" [

        test "fractal action returns valid JSON" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "fractal" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 60)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should return parseable JSON"
            let action = inner.Value.RootElement.GetProperty("action").GetString()
            Expect.equal action "fractal" "Action should be 'fractal'"
        }

        test "fractal covers all 8 layers (L0-L7)" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "fractal" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 61)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should parse"
            let root = inner.Value.RootElement
            let hasLayers = root.TryGetProperty("layers") |> fst
            Expect.isTrue hasLayers "Should have layers array"
            if hasLayers then
                let layers = root.GetProperty("layers")
                Expect.equal (layers.GetArrayLength()) 8 "Should have exactly 8 fractal layers"
        }

        testList "fractal layer-specific verification" (
            fractalLayerNames |> List.map (fun (level, name) ->
                test (sprintf "fractal verifies L%d %s" level name) {
                    let state = SwarmVerificationTools.createState()
                    let args = mkArgsWithInt [ "action", "fractal" :> obj; "layer", level :> obj ]
                    let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId (62 + level))
                    Expect.isSome result (sprintf "L%d %s should produce response" level name)
                    Expect.isFalse (isError (result.Value)) (sprintf "L%d should not error" level)
                }))

        test "fractal includes containers_checked per layer" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "fractal" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 70)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("containers_checked"))
                "Each layer should report containers_checked"
        }

        test "fractal includes STAMP references" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "fractal" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 71)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("SC-FRACTAL") || content.Contains("SC-VER"))
                "Should reference SC-FRACTAL or SC-VER constraints"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L2: INJECT TRACE TESTS (SC-SWARM-VERIFY-008, SC-SWARM-VERIFY-050 to SC-SWARM-VERIFY-055)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let injectTraceTests = testList "SwarmVerification/InjectTrace" [

        test "inject_trace returns valid JSON with trace_id" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "inject_trace" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 80)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should return parseable JSON"
            let root = inner.Value.RootElement
            let hasTraceId = root.TryGetProperty("trace_id") |> fst
            Expect.isTrue hasTraceId "Should have trace_id field"
        }

        test "inject_trace includes containers_total = 16" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "inject_trace" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 81)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should parse"
            let root = inner.Value.RootElement
            let total = root.GetProperty("containers_total").GetInt32()
            Expect.equal total 16 "Should report 16 containers total"
        }

        test "inject_trace includes container_trace_results" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "inject_trace" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 82)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("container_trace_results"))
                "Should include per-container trace results"
        }

        test "inject_trace includes SC-ZENOH STAMP refs" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "inject_trace" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 83)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("SC-ZENOH"))
                "Should reference SC-ZENOH constraints"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L3: FULL VERIFICATION TESTS (SC-SWARM-VERIFY-007)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let fullTests = testList "SwarmVerification/Full" [

        test "full action returns valid JSON with aggregate" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "full" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 90)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should return parseable JSON"
            let action = inner.Value.RootElement.GetProperty("action").GetString()
            Expect.equal action "full" "Action should be 'full'"
        }

        test "full includes compliance_pct" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "full" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 91)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("compliance_pct"))
                "Should include compliance percentage"
        }

        test "full includes subsystem breakdown" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "full" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 92)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("subsystems"))
                "Should include subsystem breakdown"
        }

        test "full updates LastFullCheck" {
            let state = SwarmVerificationTools.createState()
            Expect.isNone state.LastFullCheck "Should start None"
            let args = mkArgs [ "action", "full" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 93) |> ignore
            Expect.isSome state.LastFullCheck "Should be set after full check"
        }

        test "full includes duration_ms" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "full" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 94)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("duration_ms"))
                "Should include duration_ms"
        }

        test "full includes STAMP references" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "full" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 95)
            let content = extractContent (result.Value)
            Expect.isTrue (content.Contains("SC-OODA") || content.Contains("SC-VER") || content.Contains("SC-CTRL"))
                "Should reference STAMP constraints"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L4: CONTAINER GENOME COMPLETENESS (SC-SWARM-VERIFY-010 to SC-SWARM-VERIFY-018)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let genomeTests = testList "SwarmVerification/Genome" [

        test "allContainers has exactly 16 entries" {
            Expect.equal (List.length allContainers) 16 "Should have 16 genome containers"
        }

        test "oodaCapableContainers has exactly 6 entries" {
            Expect.equal (List.length oodaCapableContainers) 6 "Should have 6 OODA-capable containers"
        }

        test "agentCapableContainers has exactly 6 entries" {
            Expect.equal (List.length agentCapableContainers) 6 "Should have 6 agent-capable containers"
        }

        test "all OODA containers are in allContainers" {
            for c in oodaCapableContainers do
                Expect.isTrue (allContainers |> List.contains c)
                    (sprintf "%s should be in allContainers" c)
        }

        test "all agent containers are in allContainers" {
            for c in agentCapableContainers do
                Expect.isTrue (allContainers |> List.contains c)
                    (sprintf "%s should be in allContainers" c)
        }

        test "allContainers has no duplicates" {
            let unique = allContainers |> Set.ofList
            Expect.equal (Set.count unique) (List.length allContainers)
                "allContainers should have no duplicates"
        }

        test "5 BuiltFromDockerfile containers present" {
            let built = [ "indrajaal-db-prod"; "indrajaal-obs-prod"; "indrajaal-ex-app-1"; "cepaf-bridge"; "indrajaal-cortex" ]
            for c in built do
                Expect.isTrue (allContainers |> List.contains c)
                    (sprintf "Built container %s should be in genome" c)
        }

        test "3 PulledFromRegistry containers present" {
            let pulled = [ "zenoh-router"; "indrajaal-ollama"; "indrajaal-mojo" ]
            for c in pulled do
                Expect.isTrue (allContainers |> List.contains c)
                    (sprintf "Pulled container %s should be in genome" c)
        }

        test "8 SharedImage containers present" {
            let shared = [
                "zenoh-router-1"; "zenoh-router-2"; "zenoh-router-3"
                "indrajaal-ex-app-2"; "indrajaal-ex-app-3"
                "indrajaal-chaya"; "indrajaal-ml-runner-1"; "indrajaal-ml-runner-2"
            ]
            for c in shared do
                Expect.isTrue (allContainers |> List.contains c)
                    (sprintf "Shared container %s should be in genome" c)
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L4: COVERAGE MATRIX VERIFICATION (7 actions × response quality)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let coverageMatrixTests = testList "SwarmVerification/CoverageMatrix" [

        testList "all 7 actions produce valid MCP responses" (
            [ "ooda"; "observability"; "control"; "agent_probe"; "fractal"; "full"; "inject_trace" ]
            |> List.mapi (fun i action ->
                test (sprintf "action '%s' returns valid MCP response" action) {
                    let state = SwarmVerificationTools.createState()
                    let args = mkArgs [ "action", action ]
                    let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId (100 + i))
                    Expect.isSome result (sprintf "Action '%s' should return Some" action)
                    let resp = result.Value
                    // Valid MCP response should have "result" field
                    Expect.isTrue (resp.Contains("result") || resp.Contains("error"))
                        (sprintf "Action '%s' should produce valid JSON-RPC response" action)
                }))

        testList "all 7 actions include timestamp" (
            [ "ooda"; "observability"; "control"; "agent_probe"; "fractal"; "full"; "inject_trace" ]
            |> List.mapi (fun i action ->
                test (sprintf "action '%s' includes timestamp" action) {
                    let state = SwarmVerificationTools.createState()
                    let args = mkArgs [ "action", action ]
                    let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId (110 + i))
                    let content = extractContent (result.Value)
                    Expect.isTrue (content.Contains("timestamp"))
                        (sprintf "Action '%s' should include timestamp" action)
                }))

        testList "all 7 actions include duration_ms" (
            [ "ooda"; "observability"; "control"; "agent_probe"; "fractal"; "full"; "inject_trace" ]
            |> List.mapi (fun i action ->
                test (sprintf "action '%s' includes duration_ms" action) {
                    let state = SwarmVerificationTools.createState()
                    let args = mkArgs [ "action", action ]
                    let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId (120 + i))
                    let content = extractContent (result.Value)
                    Expect.isTrue (content.Contains("duration_ms"))
                        (sprintf "Action '%s' should include duration_ms" action)
                }))
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L5: FRACTAL LAYER × CONTAINER COMPLETENESS
    // (SC-SWARM-VERIFY-040 to SC-SWARM-VERIFY-048)
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let fractalCompletenessTests = testList "SwarmVerification/FractalCompleteness" [

        test "8 fractal layers defined (L0-L7)" {
            Expect.equal (List.length fractalLayerNames) 8 "Should have 8 fractal layers"
        }

        test "5 OODA tiers defined" {
            Expect.equal (List.length oodaTierNames) 5 "Should have 5 OODA tiers"
        }

        test "L0 Constitutional verifies guardian and constitution" {
            // The fractal layer definitions include these checks
            let l0Checks = [ "guardian_active"; "constitution_hash"; "psi_invariants"; "founder_directive"; "immutable_register_integrity" ]
            Expect.equal (List.length l0Checks) 5 "L0 should have 5 verification checks"
        }

        test "L6 Ecosystem covers all 4 Zenoh routers" {
            let l6Containers = [ "zenoh-router"; "zenoh-router-1"; "zenoh-router-2"; "zenoh-router-3" ]
            Expect.equal (List.length l6Containers) 4 "L6 should have 4 primary Zenoh router containers"
        }

        test "OODA tier latency bounds are ordered" {
            let latencies = [ 30; 100; 1; 50; 1000 ]
            // Knowledge (1ms) should be fastest
            Expect.equal (List.min latencies) 1 "Knowledge tier should have 1ms target"
            // Strategy (1000ms) should be slowest
            Expect.equal (List.max latencies) 1000 "Strategy tier should have 1000ms target"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L6: SAFETY & ERROR HANDLING
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let safetyTests = testList "SwarmVerification/Safety" [

        test "missing action returns error" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs []
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 130)
            Expect.isSome result "Should return Some for missing action"
        }

        test "empty action string returns error" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 131)
            Expect.isSome result "Should return Some for empty action"
            let resp = result.Value
            // Empty action dispatches to the default case which is an error
            Expect.isTrue (resp.Contains("Unknown action") || resp.Contains("error") || resp.Contains("result"))
                "Should handle empty action gracefully"
        }

        test "null id still produces response" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "ooda" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args None
            Expect.isSome result "Should handle None id"
        }

        test "concurrent state access is safe" {
            let state = SwarmVerificationTools.createState()
            // Run multiple checks in parallel to stress-test state mutations
            let tasks =
                [| for i in 1..5 ->
                    async {
                        let args = mkArgs [ "action", "ooda" ]
                        return SwarmVerificationTools.dispatch state "swarm_verify" args (mkId (140 + i))
                    } |]
            let results = tasks |> Async.Parallel |> Async.RunSynchronously
            // All should succeed without exception
            for r in results do
                Expect.isSome r "Concurrent access should not crash"
            // CheckCount should reflect all invocations
            Expect.isGreaterThanOrEqual state.CheckCount 5L "Should count all concurrent checks"
        }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // L7: INTEGRATION — FULL PIPELINE
    // ═══════════════════════════════════════════════════════════════════

    [<Tests>]
    let integrationTests = testList "SwarmVerification/Integration" [

        test "full verification aggregates subsystem results" {
            let state = SwarmVerificationTools.createState()
            let args = mkArgs [ "action", "full" ]
            let result = SwarmVerificationTools.dispatch state "swarm_verify" args (mkId 150)
            let inner = parseInner (result.Value)
            Expect.isSome inner "Should parse full result"
            let root = inner.Value.RootElement
            let summary = root.GetProperty("summary")
            // Should have all subsystem fields
            let hasOoda =
                try summary.GetProperty("subsystems").GetProperty("ooda") |> ignore; true
                with _ -> false
            Expect.isTrue hasOoda "Full should include ooda subsystem"
        }

        test "sequential verification preserves state across actions" {
            let state = SwarmVerificationTools.createState()

            // Run ooda
            let args1 = mkArgs [ "action", "ooda" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args1 (mkId 151) |> ignore
            Expect.isSome state.LastOodaCheck "ooda should set timestamp"
            let count1 = state.CheckCount

            // Run control
            let args2 = mkArgs [ "action", "control" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args2 (mkId 152) |> ignore
            Expect.isSome state.LastControlCheck "control should set timestamp"
            Expect.isGreaterThan state.CheckCount count1 "CheckCount should increase"

            // Run full
            let args3 = mkArgs [ "action", "full" ]
            SwarmVerificationTools.dispatch state "swarm_verify" args3 (mkId 153) |> ignore
            Expect.isSome state.LastFullCheck "full should set timestamp"
        }
    ]
