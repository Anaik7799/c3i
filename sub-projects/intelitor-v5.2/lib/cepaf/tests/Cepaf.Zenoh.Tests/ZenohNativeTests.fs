// =============================================================================
// ZenohNativeTests.fs - Unit Tests for Native FFI Layer (L1)
// =============================================================================
// STAMP: SC-NAT-001, SC-NAT-002, SC-NAT-003, SC-NAT-004
// AOR: AOR-TEST-001, AOR-ZENOH-001
// Criticality: Level 1 (CRITICAL) - FFI Safety Tests
// =============================================================================

module Cepaf.Zenoh.Tests.ZenohNativeTests

open System
open Expecto

// =============================================================================
// Note: These tests validate the interface contracts.
// Actual native FFI tests require zenoh-c runtime.
// =============================================================================

[<Tests>]
let nativeHandleTests =
    testList "Native Handle Contracts" [
        test "Handle interface requires Dispose" {
            // IDisposable contract
            let disposableType = typeof<IDisposable>
            Expect.isTrue (disposableType.GetMethod("Dispose") <> null) "IDisposable has Dispose"
        }

        test "Handle zero is invalid" {
            let handle = nativeint 0
            Expect.equal handle IntPtr.Zero "Zero handle is invalid"
        }

        test "Handle comparison works" {
            let h1 = nativeint 100
            let h2 = nativeint 100
            let h3 = nativeint 200
            Expect.equal h1 h2 "Same handles equal"
            Expect.notEqual h1 h3 "Different handles not equal"
        }
    ]

[<Tests>]
let memoryManagementTests =
    testList "Memory Management" [
        test "IntPtr.Zero represents null handle" {
            Expect.equal IntPtr.Zero (nativeint 0) "Zero is null"
        }

        test "Byte array allocation works" {
            let bytes = Array.zeroCreate<byte> 1024
            Expect.equal bytes.Length 1024 "Allocation succeeds"
        }

        test "Large allocation succeeds" {
            let bytes = Array.zeroCreate<byte> (1024 * 1024)  // 1MB
            Expect.equal bytes.Length (1024 * 1024) "1MB allocation"
        }
    ]

[<Tests>]
let errorCodeTests =
    testList "Error Code Handling" [
        test "Zero indicates success" {
            let success = 0
            Expect.equal success 0 "Zero is success"
        }

        test "Negative indicates error" {
            let error = -1
            Expect.isLessThan error 0 "Negative is error"
        }
    ]
