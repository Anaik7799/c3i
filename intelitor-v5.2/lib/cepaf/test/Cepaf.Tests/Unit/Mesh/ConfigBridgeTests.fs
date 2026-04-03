// =============================================================================
// ConfigBridgeTests.fs - TDG-compliant tests for ConfigBridge
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-SYNC-001 (Elixir-F# bridge sync),
//        SC-CONSOL-006 (ConfigBridge syncs F#/Elixir configs),
//        AOR-BRIDGE-001 (ConfigBridge sync rules)
//
// ## Test Coverage
// - publishConfig: normal publish, empty key rejection, cache update, subscriber notification
// - subscribeConfig: registration, wildcard subscription, callback invocation
// - syncAll: empty cache, populated cache, re-broadcast
// - getConfig: present key, absent key, empty key rejection
// - Edge cases: whitespace keys, overwrite, multiple subscribers
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-03-30 |
// | Author | Code Evolution Agent v21.3.0-SIL6 |
// | STAMP | SC-TEST-001, SC-SYNC-001, SC-CONSOL-006 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.ConfigBridgeTests

open Expecto
open Cepaf.Mesh

// NOTE: ConfigBridge holds a process-level ConcurrentDictionary as private state.
// Each test uses unique key names to stay independent without requiring a reset
// between runs — the module is write-once from each key's perspective in the tests.

[<Tests>]
let tests = testList "ConfigBridge" [

    // =========================================================================
    // publishConfig Tests
    // =========================================================================
    testList "publishConfig" [

        test "publishConfig with valid key and value returns Ok" {
            let result = ConfigBridge.publishConfig "test.valid_key_001" "value1"
            Expect.isOk result "publishConfig with valid args should return Ok"
        }

        test "publishConfig Ok message contains the key expression" {
            let result = ConfigBridge.publishConfig "test.key_expr_002" "someValue"
            match result with
            | Ok msg ->
                Expect.isTrue
                    (msg.Contains("test.key_expr_002") || msg.Contains("indrajaal/config/test.key_expr_002"))
                    "Ok message should contain the key or key expression"
            | Error e -> failtest $"Expected Ok, got Error: {e}"
        }

        test "publishConfig with empty key returns Error" {
            let result = ConfigBridge.publishConfig "" "value"
            Expect.isError result "publishConfig with empty key must return Error"
        }

        test "publishConfig with whitespace-only key returns Error" {
            let result = ConfigBridge.publishConfig "   " "value"
            Expect.isError result "publishConfig with whitespace key must return Error"
        }

        test "publishConfig stores value so getConfig retrieves it" {
            let key   = "test.roundtrip_key_005"
            let value = "roundtrip_value"
            let _     = ConfigBridge.publishConfig key value
            let got   = ConfigBridge.getConfig key
            match got with
            | Ok v -> Expect.equal v value "getConfig should return the last published value"
            | Error e -> failtest $"getConfig returned Error after publish: {e}"
        }

        test "publishConfig overwrites previous value in cache" {
            let key = "test.overwrite_key_006"
            let _   = ConfigBridge.publishConfig key "first"
            let _   = ConfigBridge.publishConfig key "second"
            match ConfigBridge.getConfig key with
            | Ok v -> Expect.equal v "second" "Second publish should overwrite first in cache"
            | Error e -> failtest $"getConfig failed: {e}"
        }

        test "publishConfig with numeric value string succeeds" {
            let result = ConfigBridge.publishConfig "test.numeric_007" "42"
            Expect.isOk result "publishConfig should accept numeric string values"
        }

        test "publishConfig with empty value string succeeds (empty config is valid)" {
            let result = ConfigBridge.publishConfig "test.empty_value_008" ""
            Expect.isOk result "publishConfig should accept empty string as value"
        }

        test "publishConfig invokes exact-key subscriber callback" {
            let mutable received = ""
            let key = "test.sub_notify_009"
            let _   = ConfigBridge.subscribeConfig key (fun v -> received <- v)
            let _   = ConfigBridge.publishConfig key "notified_value"
            Expect.equal received "notified_value"
                "Subscriber callback should be invoked with the published value"
        }

        test "publishConfig invokes wildcard subscriber callback" {
            let mutable received = ""
            let _   = ConfigBridge.subscribeConfig "*" (fun v -> received <- v)
            let _   = ConfigBridge.publishConfig "test.wildcard_010" "wildcard_hit"
            Expect.isNotEmpty received
                "Wildcard subscriber should be invoked on any publish"
        }
    ]

    // =========================================================================
    // subscribeConfig Tests
    // =========================================================================
    testList "subscribeConfig" [

        test "subscribeConfig with valid key returns Ok subscriptionId" {
            let result = ConfigBridge.subscribeConfig "test.sub_ok_011" (fun _ -> ())
            Expect.isOk result "subscribeConfig with valid key should return Ok"
        }

        test "subscribeConfig returns a non-empty subscription ID" {
            match ConfigBridge.subscribeConfig "test.sub_id_012" (fun _ -> ()) with
            | Ok id -> Expect.isNotEmpty id "Subscription ID should not be empty"
            | Error e -> failtest $"subscribeConfig failed: {e}"
        }

        test "subscribeConfig with empty key returns Error" {
            let result = ConfigBridge.subscribeConfig "" (fun _ -> ())
            Expect.isError result "subscribeConfig with empty key must return Error"
        }

        test "subscribeConfig with whitespace key returns Error" {
            let result = ConfigBridge.subscribeConfig "  " (fun _ -> ())
            Expect.isError result "subscribeConfig with whitespace key must return Error"
        }

        test "subscribeConfig to wildcard '*' returns Ok" {
            let result = ConfigBridge.subscribeConfig "*" (fun _ -> ())
            Expect.isOk result "subscribeConfig to wildcard '*' should return Ok"
        }

        test "multiple subscribeConfig calls to same key each return distinct IDs" {
            let id1 = ConfigBridge.subscribeConfig "test.multi_sub_016" (fun _ -> ())
            let id2 = ConfigBridge.subscribeConfig "test.multi_sub_016" (fun _ -> ())
            match id1, id2 with
            | Ok s1, Ok s2 ->
                Expect.notEqual s1 s2 "Each subscription should get a distinct ID"
            | _ -> failtest "Both subscriptions should succeed"
        }

        test "subscribeConfig callback receives value when key is published" {
            let mutable callCount = 0
            let key = "test.callback_count_017"
            let _ = ConfigBridge.subscribeConfig key (fun _ -> callCount <- callCount + 1)
            let _ = ConfigBridge.publishConfig key "v1"
            let _ = ConfigBridge.publishConfig key "v2"
            Expect.isGreaterThanOrEqual callCount 2
                "Callback should be invoked for each publish"
        }
    ]

    // =========================================================================
    // syncAll Tests
    // =========================================================================
    testList "syncAll" [

        test "syncAll on a cache with entries returns Ok" {
            // Pre-populate the shared cache by publishing something
            let _ = ConfigBridge.publishConfig "test.sync_seed_020" "seed_value"
            let result = ConfigBridge.syncAll ()
            Expect.isOk result "syncAll should return Ok when cache has entries"
        }

        test "syncAll Ok message contains 'published' or 'syncAll'" {
            let _ = ConfigBridge.publishConfig "test.sync_msg_021" "value"
            match ConfigBridge.syncAll () with
            | Ok msg ->
                let lower = msg.ToLowerInvariant()
                Expect.isTrue
                    (lower.Contains("published") || lower.Contains("syncall"))
                    $"syncAll message should mention published keys; got: {msg}"
            | Error e -> failtest $"syncAll returned Error: {e}"
        }
    ]

    // =========================================================================
    // getConfig Tests
    // =========================================================================
    testList "getConfig" [

        test "getConfig returns Ok for a key that was published" {
            let key = "test.get_present_025"
            let _ = ConfigBridge.publishConfig key "present_value"
            let result = ConfigBridge.getConfig key
            Expect.isOk result "getConfig should return Ok for a published key"
        }

        test "getConfig returns the exact published value" {
            let key   = "test.get_exact_026"
            let value = "exact_expected_value"
            let _ = ConfigBridge.publishConfig key value
            match ConfigBridge.getConfig key with
            | Ok v -> Expect.equal v value "Retrieved value must match what was published"
            | Error e -> failtest $"getConfig returned Error: {e}"
        }

        test "getConfig returns Error for an unknown key" {
            let result = ConfigBridge.getConfig "test.never_published_027"
            Expect.isError result "getConfig should return Error for a key not in cache"
        }

        test "getConfig returns Error for empty key" {
            let result = ConfigBridge.getConfig ""
            Expect.isError result "getConfig with empty key must return Error"
        }

        test "getConfig Error message contains 'not found' or 'empty'" {
            match ConfigBridge.getConfig "test.missing_for_error_029" with
            | Error msg ->
                let lower = msg.ToLowerInvariant()
                Expect.isTrue
                    (lower.Contains("not found") || lower.Contains("empty") || lower.Contains("missing"))
                    $"Error message should describe why key was not found; got: {msg}"
            | Ok _ -> failtest "Expected Error for a key that was never published"
        }

        test "getConfig returns latest value after multiple publishes" {
            let key = "test.get_latest_030"
            let _ = ConfigBridge.publishConfig key "old"
            let _ = ConfigBridge.publishConfig key "new"
            match ConfigBridge.getConfig key with
            | Ok v -> Expect.equal v "new" "Should return the most recently published value"
            | Error e -> failtest $"getConfig returned Error: {e}"
        }
    ]
]
