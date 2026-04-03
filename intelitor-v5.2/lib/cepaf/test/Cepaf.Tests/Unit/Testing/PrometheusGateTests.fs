module Cepaf.Tests.Unit.Testing.PrometheusGateTests

open Expecto
open Cepaf.Testing

[<Tests>]
let tests = testList "PrometheusGate" [

    testList "Proof Token" [
        test "createToken generates valid token" {
            let token = PrometheusGate.createToken "test_fsharp_start" "levels=[1;2];timeout=900"
            Expect.isTrue (token.TokenId.StartsWith("PT-")) "Token ID should start with PT-"
            Expect.equal token.Action "test_fsharp_start" "Action should match"
            Expect.isTrue (token.Hash.Length = 64) "HMAC-SHA256 hex hash should be 64 chars"
        }

        test "createToken produces unique IDs" {
            let t1 = PrometheusGate.createToken "test" "a"
            let t2 = PrometheusGate.createToken "test" "a"
            Expect.notEqual t1.TokenId t2.TokenId "Token IDs should be unique"
        }

        test "createToken hash differs for different configs" {
            let t1 = PrometheusGate.createToken "test" "levels=[1]"
            let t2 = PrometheusGate.createToken "test" "levels=[1;2]"
            Expect.notEqual t1.Hash t2.Hash "Different configs should produce different hashes"
        }

        test "createToken IssuedAt is recent" {
            let before = System.DateTime.UtcNow
            let token = PrometheusGate.createToken "test" "x"
            let after = System.DateTime.UtcNow
            Expect.isTrue (token.IssuedAt >= before && token.IssuedAt <= after) "IssuedAt should be within test window"
        }
    ]

    testList "DAG Verification" [
        test "empty levels is acyclic" {
            let result = PrometheusGate.verifyDagAcyclic []
            Expect.isOk result "Empty levels should be OK"
            Expect.equal (Result.defaultValue [] result) [] "Should return empty sorted list"
        }

        test "single level is acyclic" {
            let result = PrometheusGate.verifyDagAcyclic [3]
            Expect.isOk result "Single level should be OK"
        }

        test "all levels 1-5 are acyclic" {
            let result = PrometheusGate.verifyDagAcyclic [1;2;3;4;5]
            Expect.isOk result "Standard 1-5 levels should be acyclic"
        }

        test "sorted order respects dependencies" {
            let result = PrometheusGate.verifyDagAcyclic [1;2;3;4;5]
            match result with
            | Ok sorted ->
                let indexOf l = sorted |> List.findIndex ((=) l)
                // L1 before L2, L2 before L3, L1 before L4, L3 before L5, L4 before L5
                Expect.isTrue (indexOf 1 < indexOf 2) "L1 should come before L2"
                Expect.isTrue (indexOf 2 < indexOf 3) "L2 should come before L3"
                Expect.isTrue (indexOf 1 < indexOf 4) "L1 should come before L4"
                Expect.isTrue (indexOf 3 < indexOf 5) "L3 should come before L5"
                Expect.isTrue (indexOf 4 < indexOf 5) "L4 should come before L5"
            | Error e -> failwithf "Expected Ok, got Error: %s" e
        }

        test "subset levels are acyclic" {
            let result = PrometheusGate.verifyDagAcyclic [1;4]
            Expect.isOk result "Subset [1;4] should be acyclic"
            match result with
            | Ok sorted ->
                let indexOf l = sorted |> List.findIndex ((=) l)
                Expect.isTrue (indexOf 1 < indexOf 4) "L1 should come before L4"
            | Error e -> failwithf "Expected Ok, got Error: %s" e
        }

        test "non-connected levels are acyclic" {
            let result = PrometheusGate.verifyDagAcyclic [2;4]
            Expect.isOk result "Non-connected levels [2;4] should be acyclic"
        }
    ]

    testList "Config Validation" [
        test "valid config returns proof token" {
            let result = PrometheusGate.verifyTestStart [1;2;3;4;5] 900 false false
            Expect.isOk result "Valid config should return Ok"
            match result with
            | Ok token ->
                Expect.equal token.Action "test_fsharp_start" "Action should be test_fsharp_start"
                Expect.isTrue (token.Hash.Length > 0) "Hash should not be empty"
            | Error _ -> ()
        }

        test "concurrent run returns error" {
            let result = PrometheusGate.verifyTestStart [1;2] 900 false true
            Expect.isError result "Concurrent run should return Error"
            match result with
            | Error msg -> Expect.stringContains msg "concurrent run" "Should mention concurrent run"
            | Ok _ -> ()
        }

        test "invalid level returns error" {
            let result = PrometheusGate.verifyTestStart [0;1;6] 900 false false
            Expect.isError result "Invalid levels should return Error"
            match result with
            | Error msg -> Expect.stringContains msg "invalid levels" "Should mention invalid levels"
            | Ok _ -> ()
        }

        test "zero timeout returns error" {
            let result = PrometheusGate.verifyTestStart [1] 0 false false
            Expect.isError result "Zero timeout should return Error"
            match result with
            | Error msg -> Expect.stringContains msg "timeout" "Should mention timeout"
            | Ok _ -> ()
        }

        test "negative timeout returns error" {
            let result = PrometheusGate.verifyTestStart [1] -5 false false
            Expect.isError result "Negative timeout should return Error"
        }

        test "excessive timeout returns error" {
            let result = PrometheusGate.verifyTestStart [1] 10000 false false
            Expect.isError result "Excessive timeout should return Error"
            match result with
            | Error msg -> Expect.stringContains msg "7200" "Should mention max timeout"
            | Ok _ -> ()
        }

        test "single valid level returns proof token" {
            let result = PrometheusGate.verifyTestStart [3] 60 true false
            Expect.isOk result "Single valid level should return Ok"
        }

        test "boundary timeout 7200 is valid" {
            let result = PrometheusGate.verifyTestStart [1] 7200 false false
            Expect.isOk result "Timeout 7200 should be valid (boundary)"
        }

        test "boundary timeout 7201 is invalid" {
            let result = PrometheusGate.verifyTestStart [1] 7201 false false
            Expect.isError result "Timeout 7201 should be invalid"
        }
    ]

    testList "Integration with TestAgent" [
        test "TestAgent start passes through PrometheusGate" {
            let agent = TestAgent.create(None)
            let config : TestConfig = {
                Levels = [1; 2]
                TimeoutSeconds = 60
                Verbose = false
            }
            let result = TestAgent.start agent config
            // Should succeed (gate passes for valid config)
            Expect.isOk result "Start with valid config should pass PROMETHEUS gate"
        }

        test "TestAgent blocks concurrent start via PrometheusGate" {
            let agent = TestAgent.create(None)
            let config : TestConfig = {
                Levels = [1]
                TimeoutSeconds = 60
                Verbose = false
            }
            let r1 = TestAgent.start agent config
            Expect.isOk r1 "First start should succeed"
            // Second start should fail via PrometheusGate
            let r2 = TestAgent.start agent config
            Expect.isError r2 "Second concurrent start should fail"
            match r2 with
            | Error msg -> Expect.stringContains msg "concurrent" "Should mention concurrent run"
            | Ok _ -> ()
        }
    ]
]
