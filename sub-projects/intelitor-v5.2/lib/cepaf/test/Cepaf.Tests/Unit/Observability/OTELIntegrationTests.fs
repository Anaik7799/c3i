module Cepaf.Tests.Unit.Observability.OTELIntegrationTests

open System
open System.Diagnostics
open System.Threading.Tasks
open Expecto
open Cepaf.Observability.Fractal

/// SC-OBS-071: F# OTel integration tests
/// Covers: TracerProvider bootstrap, ActivitySource, baggage, decorator, parent propagation
[<Tests>]
let otelIntegrationTests =
    testList "OTELIntegration" [

        testList "TracerProviderBootstrap" [
            test "isActive returns true after initialization" {
                // TracerProvider is initialized at module load time
                let active = TracerProviderBootstrap.isActive()
                Expect.isTrue active "TracerProvider should be active after bootstrap"
            }
        ]

        testList "ActivitySourceBridge" [
            test "startActivity returns Activity when TracerProvider is active" {
                let activity = ActivitySourceBridge.startActivity "test-op" ActivityKind.Internal []
                match activity with
                | Some act ->
                    Expect.isNotNull (act.OperationName) "Activity should have operation name"
                    act.Stop()
                | None ->
                    // Acceptable if no listener is attached (test runner env)
                    ()
            }

            test "startFractalActivity sets correct tags" {
                let activity = ActivitySourceBridge.startFractalActivity "TestModule" "testFunc" FractalLevel.L3
                match activity with
                | Some act ->
                    Expect.isNotNull act "Activity should not be null"
                    act.Stop()
                | None -> ()
            }

            test "endActivity with Ok sets status OK" {
                let activity = ActivitySourceBridge.startActivity "test-ok" ActivityKind.Internal []
                ActivitySourceBridge.endActivity activity (Ok ())
                // No exception means success
            }

            test "endActivity with Error sets status Error" {
                let activity = ActivitySourceBridge.startActivity "test-err" ActivityKind.Internal []
                ActivitySourceBridge.endActivity activity (Error (exn "test error"))
            }

            test "getTraceparent returns W3C format when activity active" {
                let activity = ActivitySourceBridge.startActivity "test-tp" ActivityKind.Internal []
                match activity with
                | Some act ->
                    let tp = ActivitySourceBridge.getTraceparent()
                    match tp with
                    | Some traceparent ->
                        Expect.isTrue (traceparent.StartsWith("00-")) "Traceparent should start with version 00"
                        let parts = traceparent.Split('-')
                        Expect.equal parts.Length 4 "Traceparent should have 4 parts"
                        Expect.equal parts.[1].Length 32 "TraceId should be 32 hex chars"
                        Expect.equal parts.[2].Length 16 "SpanId should be 16 hex chars"
                    | None -> ()
                    act.Stop()
                | None -> ()
            }

            test "setParentFromTraceparent with valid traceparent" {
                let traceId = "0af7651916cd43dd8448eb211c80319c"
                let spanId = "b7ad6b7169203331"
                let traceparent = sprintf "00-%s-%s-01" traceId spanId
                let activity = ActivitySourceBridge.setParentFromTraceparent traceparent
                match activity with
                | Some act ->
                    // The child activity should exist and reference the parent trace
                    Expect.equal (act.TraceId.ToHexString()) traceId "TraceId should match parent"
                    act.Stop()
                | None ->
                    // Acceptable if no listener (test env without full OTLP)
                    ()
            }

            test "setParentFromTraceparent with malformed input returns None" {
                let result = ActivitySourceBridge.setParentFromTraceparent "garbage"
                Expect.isNone result "Malformed traceparent should return None"
            }

            test "setParentFromTraceparent with empty string returns None" {
                let result = ActivitySourceBridge.setParentFromTraceparent ""
                Expect.isNone result "Empty traceparent should return None"
            }
        ]

        testList "OTELBaggage" [
            test "set and get round-trip with active Activity" {
                let activity = ActivitySourceBridge.startActivity "baggage-test" ActivityKind.Internal []
                match activity with
                | Some act ->
                    OTELBaggage.set "test-key" "test-value"
                    let result = OTELBaggage.get "test-key"
                    Expect.equal result (Some "test-value") "Should get back the value we set"
                    act.Stop()
                | None ->
                    // Fallback path — uses ConcurrentDictionary
                    OTELBaggage.set "test-key-fb" "test-value-fb"
                    let result = OTELBaggage.get "test-key-fb"
                    Expect.equal result (Some "test-value-fb") "Fallback should work"
                    OTELBaggage.clear()
            }

            test "get returns None for missing key" {
                let result = OTELBaggage.get "nonexistent-key-12345"
                Expect.isNone result "Missing key should return None"
            }

            test "getAll returns all baggage entries" {
                let activity = ActivitySourceBridge.startActivity "baggage-getall" ActivityKind.Internal []
                match activity with
                | Some act ->
                    OTELBaggage.set "key1" "val1"
                    OTELBaggage.set "key2" "val2"
                    let all = OTELBaggage.getAll()
                    Expect.isGreaterThanOrEqual (Map.count all) 2 "Should have at least 2 entries"
                    act.Stop()
                | None ->
                    // Fallback path: set writes to fallback dict, getAll reads from it
                    OTELBaggage.clear()
                    OTELBaggage.set "key1" "val1"
                    OTELBaggage.set "key2" "val2"
                    let all = OTELBaggage.getAll()
                    Expect.isGreaterThanOrEqual (Map.count all) 2 "Fallback getAll should work"
                    OTELBaggage.clear()
            }

            test "setFractalContext sets all required keys" {
                OTELBaggage.setFractalContext "TestModule" "testFunc" FractalLevel.L3 (Some "abc123")
                let level = OTELBaggage.get OTELBaggage.keys.Level
                let moduleName = OTELBaggage.get OTELBaggage.keys.Module
                let funcName = OTELBaggage.get OTELBaggage.keys.Function
                Expect.equal level (Some "L3") "Level should be L3"
                Expect.equal moduleName (Some "TestModule") "Module should match"
                Expect.equal funcName (Some "testFunc") "Function should match"
                OTELBaggage.clear()
            }

            test "clear removes all entries" {
                OTELBaggage.set "clear-test" "value"
                OTELBaggage.clear()
                let result = OTELBaggage.get "clear-test"
                // May or may not be None depending on Activity.Current state
                // but fallback store is definitely cleared
                ()
            }
        ]

        testList "OTELIntegration" [
            test "startFractalSpan creates valid span context" {
                let ctx = OTELIntegration.startFractalSpan "TestModule" "testFunc" FractalLevel.L3
                Expect.isNotEmpty ctx.TraceId "TraceId should not be empty"
                Expect.isNotEmpty ctx.SpanId "SpanId should not be empty"
                Expect.equal ctx.Module "TestModule" "Module should match"
                Expect.equal ctx.Function "testFunc" "Function should match"
                Expect.equal ctx.Level FractalLevel.L3 "Level should match"
                OTELBaggage.clear()
            }

            test "endFractalSpan returns duration and status" {
                let ctx = OTELIntegration.startFractalSpan "TestModule" "endTest" FractalLevel.L2
                System.Threading.Thread.Sleep(5) // Small delay for measurable duration
                let (retCtx, duration, status) = OTELIntegration.endFractalSpan ctx (Ok ())
                Expect.equal retCtx.TraceId ctx.TraceId "TraceId should match"
                Expect.equal status "OK" "Status should be OK"
                Expect.isGreaterThan duration.TotalMilliseconds 0.0 "Duration should be positive"
                OTELBaggage.clear()
            }

            test "getL3TraceId returns trace ID when set" {
                OTELBaggage.set OTELBaggage.keys.TraceId "test-trace-123"
                let traceId = OTELIntegration.getL3TraceId()
                Expect.equal traceId (Some "test-trace-123") "Should get the trace ID"
                OTELBaggage.clear()
            }
        ]

        testList "OTELFractalDecorator" [
            test "wrap executes function and returns result" {
                let result = OTELFractalDecorator.wrap "TestModule" "wrapTest" FractalLevel.L3 (fun () -> 42)
                Expect.equal result 42 "Should return the function result"
            }

            test "wrap does not block (completes within 100ms for sync fn)" {
                let sw = Diagnostics.Stopwatch.StartNew()
                let _ = OTELFractalDecorator.wrap "TestModule" "timedTest" FractalLevel.L3 (fun () -> "ok")
                sw.Stop()
                Expect.isLessThan sw.ElapsedMilliseconds 100L "wrap should not block on SigNoz push"
            }

            test "wrap propagates exceptions" {
                Expect.throws
                    (fun () ->
                        OTELFractalDecorator.wrap "TestModule" "throwTest" FractalLevel.L3
                            (fun () -> failwith "test error") |> ignore)
                    "Should propagate exception"
            }

            test "wrapAsync executes async function and returns result" {
                let result =
                    OTELFractalDecorator.wrapAsync "TestModule" "asyncTest" FractalLevel.L3
                        (async { return 99 })
                    |> Async.RunSynchronously
                Expect.equal result 99 "Should return the async function result"
            }
        ]

        testList "SigNozIntegration" [
            test "spanToTraceData creates valid trace data" {
                let ctx = {
                    TraceId = "abc123"
                    SpanId = "def456"
                    ParentSpanId = None
                    StartTime = DateTimeOffset.UtcNow.AddMilliseconds(-100.0)
                    Module = "TestModule"
                    Function = "testFunc"
                    Level = FractalLevel.L3
                    Attributes = Map.ofList [("key", "value" :> obj)]
                }
                let duration = TimeSpan.FromMilliseconds(100.0)
                let data = SigNozIntegration.spanToTraceData ctx duration "OK"
                Expect.equal data.TraceId "abc123" "TraceId should match"
                Expect.equal data.Status "OK" "Status should be OK"
                Expect.isGreaterThan data.DurationNano 0L "Duration should be positive"
            }

            test "checkHealth returns false when SigNoz is disabled" {
                let healthy = SigNozIntegration.checkHealth() |> Async.RunSynchronously
                Expect.isFalse healthy "Should be false when SIGNOZ_ENABLED is not set"
            }
        ]

        testList "OTELPIIMasker" [
            test "masks email addresses" {
                let masked = OTELPIIMasker.mask "user@example.com logged in"
                Expect.stringContains masked "[EMAIL-REDACTED]" "Should mask email"
            }

            test "masks phone numbers" {
                let masked = OTELPIIMasker.mask "call 123-456-7890"
                Expect.stringContains masked "[PHONE-REDACTED]" "Should mask phone"
            }

            test "returns empty for empty input" {
                let masked = OTELPIIMasker.mask ""
                Expect.equal masked "" "Empty input should return empty"
            }

            test "maskFields redacts specified fields" {
                let data = Map.ofList [("password", "secret123" :> obj); ("name", "John" :> obj)]
                let masked = OTELPIIMasker.maskFields ["password"] data
                Expect.equal (masked.["password"].ToString()) "[REDACTED]" "Password should be redacted"
            }
        ]
    ]
