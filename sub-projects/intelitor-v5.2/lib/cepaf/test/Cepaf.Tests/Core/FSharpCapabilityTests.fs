/// CEPAF F# Capability Tests
/// Validates all F# language capability enhancements.
///
/// WHAT: Tests for Active Patterns, Units of Measure, Composition utilities
/// WHY: Ensures STAMP/TDG/AOR rules for F# capabilities are enforced
/// CONSTRAINTS: SC-FSH-030 (Property-Based Tests Required), SC-FSH-033 (Expecto Framework)
///
/// STAMP Compliance: SC-FSH-*, TDG-FSH-*, AOR-FSH-*
/// Version: 1.0.0
module Cepaf.Tests.Core.FSharpCapabilityTests

open System
open Expecto
open Cepaf.Core
open Cepaf.Core.ActivePatterns
open Cepaf.Podman.Domain

// ============================================================================
// UNITS OF MEASURE TESTS (SC-FSH-004)
// ============================================================================

[<Tests>]
let unitsOfMeasureTests =
    testList "SC-FSH-004: Units of Measure" [

        testList "Time Conversions" [
            test "milliseconds to seconds" {
                let ms = 1500.0<ms>
                let sec = Time.msToSec ms
                Expect.floatClose Accuracy.high (float sec) 1.5 "1500ms = 1.5s"
            }

            test "seconds to milliseconds" {
                let sec = 2.5<sec>
                let ms = Time.secToMs sec
                Expect.floatClose Accuracy.high (float ms) 2500.0 "2.5s = 2500ms"
            }

            test "minutes to seconds" {
                let mins = 1.5<minute>
                let sec = Time.minToSec mins
                Expect.floatClose Accuracy.high (float sec) 90.0 "1.5min = 90s"
            }

            test "milliseconds to TimeSpan" {
                let ms = 1000.0<ms>
                let ts = Time.msToTimeSpan ms
                Expect.equal ts.TotalMilliseconds 1000.0 "TimeSpan conversion"
            }

            test "TimeSpan to milliseconds" {
                let ts = TimeSpan.FromSeconds(2.0)
                let ms = Time.timeSpanToMs ts
                Expect.floatClose Accuracy.high (float ms) 2000.0 "TimeSpan to ms"
            }
        ]

        testList "Data Size Conversions" [
            test "bytes to kilobytes" {
                let bytes = 2048.0<bytes>
                let kb = DataSize.bytesToKB bytes
                Expect.floatClose Accuracy.high (float kb) 2.0 "2048B = 2KB"
            }

            test "kilobytes to megabytes" {
                let kb = 1024.0<KB>
                let mb = DataSize.kbToMB kb
                Expect.floatClose Accuracy.high (float mb) 1.0 "1024KB = 1MB"
            }

            test "megabytes to gigabytes" {
                let mb = 2048.0<MB>
                let gb = DataSize.mbToGB mb
                Expect.floatClose Accuracy.high (float gb) 2.0 "2048MB = 2GB"
            }

            test "data size formatting" {
                let bytes1 = 512.0<bytes>
                let bytes2 = 1536.0<bytes>
                let bytes3 = 1572864.0<bytes>
                let bytes4 = 2147483648.0<bytes>

                Expect.equal (DataSize.format bytes1) "512 B" "Bytes format"
                Expect.equal (DataSize.format bytes2) "1.50 KB" "KB format"
                Expect.equal (DataSize.format bytes3) "1.50 MB" "MB format"
                Expect.equal (DataSize.format bytes4) "2.00 GB" "GB format"
            }
        ]

        testList "Percentage Conversions" [
            test "ratio to percentage" {
                let ratio = 0.75<ratio>
                let percent = Percentage.ratioToPercent ratio
                Expect.floatClose Accuracy.high (float percent) 75.0 "0.75 = 75%"
            }

            test "percentage to ratio" {
                let percent = 50.0<percent>
                let ratio = Percentage.percentToRatio percent
                Expect.floatClose Accuracy.high (float ratio) 0.5 "50% = 0.5"
            }

            test "percentage clamping" {
                let over = 150.0<percent>
                let under = -50.0<percent>
                Expect.equal (Percentage.clamp over) 100.0<percent> "Clamp upper bound"
                Expect.equal (Percentage.clamp under) 0.0<percent> "Clamp lower bound"
            }
        ]

        testList "Safe Wrapper Types" [
            test "Timeout from milliseconds" {
                let timeout = Timeout.fromMs 5000.0<ms>
                Expect.equal (Timeout.toRawMs timeout) 5000 "Timeout value"
            }

            test "Timeout from seconds" {
                let timeout = Timeout.fromSec 3.0<sec>
                Expect.equal (Timeout.toRawMs timeout) 3000 "Timeout from seconds"
            }

            test "Timeout expiration check" {
                let timeout = Timeout.fromRawMs 100
                let startTime = DateTimeOffset.UtcNow.AddMilliseconds(-200.0)
                Expect.isTrue (Timeout.hasExpired startTime timeout) "Should be expired"
            }

            test "Port creation with validation" {
                Expect.isSome (Port.create 8080) "Valid port"
                Expect.isNone (Port.create 0) "Invalid port 0"
                Expect.isNone (Port.create 70000) "Invalid port > 65535"
            }

            test "Port privileged check" {
                Expect.isTrue (Port.isPrivileged (Port.createUnsafe 80)) "Port 80 is privileged"
                Expect.isFalse (Port.isPrivileged (Port.createUnsafe 8080)) "Port 8080 not privileged"
            }

            test "MemorySize formatting" {
                let size = MemorySize.fromMB 512.0<MB>
                Expect.equal (MemorySize.format size) "512.00 MB" "Memory size format"
            }
        ]

        testList "Duration Helpers" [
            test "duration literals" {
                let msVal = Duration.ms 100.0
                let secVal = Duration.sec 5.0
                let minsVal = Duration.mins 2.0
                let hrVal = Duration.hr 1.0

                Expect.equal msVal 100.0<ms> "ms literal"
                Expect.equal secVal 5.0<sec> "sec literal"
                Expect.equal minsVal 2.0<minute> "min literal"
                Expect.equal hrVal 1.0<hr> "hr literal"
            }
        ]
    ]

// ============================================================================
// ACTIVE PATTERNS TESTS (SC-FSH-003)
// ============================================================================

[<Tests>]
let activePatternsTests =
    testList "SC-FSH-003: Active Patterns" [

        testList "Error Recoverability Classification" [
            test "connection timeout is transient" {
                let error = PodmanError.ConnectionTimeout ("test", 5000L)
                match error with
                | ErrorRecoverability.Transient -> ()
                | _ -> failtest "Expected Transient"
            }

            test "safety violation is fatal" {
                let error = PodmanError.SafetyConstraintViolation ("SC-CNT-001", "Docker detected")
                match error with
                | ErrorRecoverability.Fatal -> ()
                | _ -> failtest "Expected Fatal"
            }

            test "container not found is recoverable" {
                let error = PodmanError.ContainerNotFound "abc123"
                match error with
                | ErrorRecoverability.Recoverable -> ()
                | _ -> failtest "Expected Recoverable"
            }

            test "validation failed is fatal" {
                let error = PodmanError.ValidationFailed ["Error 1"; "Error 2"]
                match error with
                | ErrorRecoverability.Fatal -> ()
                | _ -> failtest "Expected Fatal"
            }
        ]

        testList "Error Domain Classification" [
            test "socket not found is network error" {
                let error = PodmanError.SocketNotFound "/var/run/podman.sock"
                match error with
                | ErrorDomain.NetworkError -> ()
                | _ -> failtest "Expected NetworkError"
            }

            test "image not found is resource error" {
                let error = PodmanError.ImageNotFound "localhost/myimage:latest"
                match error with
                | ErrorDomain.ResourceError -> ()
                | _ -> failtest "Expected ResourceError"
            }

            test "health check failed is safety error" {
                let error = PodmanError.HealthCheckFailed ("container1", "unhealthy")
                match error with
                | ErrorDomain.SafetyError -> ()
                | _ -> failtest "Expected SafetyError"
            }

            test "invalid parameter is config error" {
                let error = PodmanError.InvalidParameter ("port", "must be positive")
                match error with
                | ErrorDomain.ConfigError -> ()
                | _ -> failtest "Expected ConfigError"
            }
        ]

        testList "Error Severity Classification" [
            test "safety violation is critical" {
                let error = PodmanError.SafetyConstraintViolation ("SC-TEST", "test")
                match error with
                | ErrorSeverity.CriticalError -> ()
                | _ -> failtest "Expected CriticalError"
            }

            test "container start failed is high" {
                let error = PodmanError.ContainerStartFailed ("abc", "reason")
                match error with
                | ErrorSeverity.HighError -> ()
                | _ -> failtest "Expected HighError"
            }

            test "container not found is medium" {
                let error = PodmanError.ContainerNotFound "xyz"
                match error with
                | ErrorSeverity.MediumError -> ()
                | _ -> failtest "Expected MediumError"
            }
        ]

        testList "Health Status Classification" [
            test "healthy is operational" {
                match HealthStatus.Healthy with
                | HealthClassification.Operational -> ()
                | _ -> failtest "Expected Operational"
            }

            test "starting is degraded" {
                match HealthStatus.Starting with
                | HealthClassification.Degraded -> ()
                | _ -> failtest "Expected Degraded"
            }

            test "unhealthy is failed" {
                match HealthStatus.Unhealthy 3 with  // 3 = failing streak count
                | HealthClassification.Failed -> ()
                | _ -> failtest "Expected Failed"
            }
        ]

        testList "Container State Classification" [
            test "running status" {
                match ContainerStatus.Running with
                | ContainerState.Running -> ()
                | _ -> failtest "Expected Running"
            }

            test "exited is stopped" {
                match ContainerStatus.Exited 0 with
                | ContainerState.Stopped -> ()
                | _ -> failtest "Expected Stopped"
            }

            test "restarting is transitioning" {
                match ContainerStatus.Restarting with
                | ContainerState.Transitioning -> ()
                | _ -> failtest "Expected Transitioning"
            }
        ]

        testList "String Parsing Patterns" [
            test "parse integer" {
                match "42" with
                | StringParsing.Int n -> Expect.equal n 42 "Parsed int"
                | _ -> failtest "Expected Int"
            }

            test "parse float" {
                match "3.14" with
                | StringParsing.Float f -> Expect.floatClose Accuracy.high f 3.14 "Parsed float"
                | _ -> failtest "Expected Float"
            }

            test "parse boolean" {
                match "true" with
                | StringParsing.Bool b -> Expect.isTrue b "Parsed bool"
                | _ -> failtest "Expected Bool"
            }

            test "non-empty string" {
                match "hello" with
                | StringParsing.NonEmpty s -> Expect.equal s "hello" "Non-empty string"
                | _ -> failtest "Expected NonEmpty"
            }

            test "empty string" {
                match "" with
                | StringParsing.NullOrEmpty -> ()
                | _ -> failtest "Expected NullOrEmpty"
            }
        ]

        testList "HTTP Status Patterns" [
            test "200 is success" {
                match 200 with
                | HttpStatus.Success -> ()
                | _ -> failtest "Expected Success"
            }

            test "404 is client error" {
                match 404 with
                | HttpStatus.ClientError -> ()
                | _ -> failtest "Expected ClientError"
            }

            test "500 is server error" {
                match 500 with
                | HttpStatus.ServerError -> ()
                | _ -> failtest "Expected ServerError"
            }

            test "specific status codes" {
                match 404 with
                | HttpStatus.NotFound -> ()
                | _ -> failtest "Expected NotFound"

                match 409 with
                | HttpStatus.Conflict -> ()
                | _ -> failtest "Expected Conflict"
            }
        ]

        testList "Error Classification Helper" [
            test "classifyError returns complete classification" {
                let error = PodmanError.ConnectionTimeout ("test", 1000L)
                let classification = classifyError error

                Expect.equal classification.Recoverability "Transient" "Recoverability"
                Expect.equal classification.Domain "Network" "Domain"
                Expect.equal classification.Severity "High" "Severity"
                Expect.isTrue classification.IsRetryable "Is retryable"
            }

            test "getRecommendedAction for fatal error" {
                let error = PodmanError.SafetyConstraintViolation ("SC-TEST", "violation")
                let action = getRecommendedAction error
                Expect.stringContains action "HALT" "Should recommend halt"
            }

            test "getRecommendedAction for transient error" {
                let error = PodmanError.ConnectionRefused "localhost:8000"
                let action = getRecommendedAction error
                Expect.stringContains action "RETRY" "Should recommend retry"
            }
        ]
    ]

// ============================================================================
// COMPOSITION TESTS (SC-FSH-010, SC-FSH-011)
// ============================================================================

[<Tests>]
let compositionTests =
    testList "SC-FSH-010/011: Function Composition" [

        testList "Standard Combinators" [
            test "identity function" {
                Expect.equal (id 42) 42 "id returns input"
                Expect.equal (id "hello") "hello" "id works for strings"
            }

            test "constant function" {
                // Use separate calls to avoid F# type inference locking 'a to a single type
                Expect.equal (konst 42 "ignored") 42 "konst ignores string arg"
                Expect.equal (konst 42 999) 42 "konst ignores int arg"
                Expect.equal (konst "hello" 3.14) "hello" "konst with string value"
            }

            test "flip function" {
                let subtract x y = x - y
                Expect.equal (subtract 10 3) 7 "Original order"
                Expect.equal (flip subtract 10 3) (3 - 10) "Flipped order"
            }
        ]

        testList "Composition Operators" [
            test "forward composition (>>)" {
                let addOne x = x + 1
                let double x = x * 2
                let addOneThenDouble = addOne >> double
                Expect.equal (addOneThenDouble 5) 12 "(5+1)*2 = 12"
            }

            test "backward composition (<<)" {
                let addOne x = x + 1
                let double x = x * 2
                let doubleFirst = addOne << double
                Expect.equal (doubleFirst 5) 11 "(5*2)+1 = 11"
            }

            test "Kleisli composition for Result (>=>)" {
                let parse (s: string) =
                    match Int32.TryParse s with
                    | true, n -> Ok n
                    | false, _ -> Error "Not a number"

                let validate n =
                    if n > 0 then Ok n else Error "Must be positive"

                let parseAndValidate = parse >=> validate

                Expect.equal (parseAndValidate "42") (Ok 42) "Valid input"
                Expect.equal (parseAndValidate "abc") (Error "Not a number") "Parse error"
                Expect.equal (parseAndValidate "-5") (Error "Must be positive") "Validation error"
            }
        ]

        testList "Tap Functions" [
            test "tap executes side effect" {
                let mutable called = false
                let result = 42 |> tap (fun x -> called <- true; ignore x)
                Expect.isTrue called "Side effect executed"
                Expect.equal result 42 "Value unchanged"
            }

            test "tapOk only executes on success" {
                let mutable okCalled = false
                let mutable errorCalled = false

                Ok 42 |> tapOk (fun _ -> okCalled <- true) |> ignore
                Error "fail" |> tapOk (fun _ -> errorCalled <- true) |> ignore

                Expect.isTrue okCalled "Ok side effect executed"
                Expect.isFalse errorCalled "Error side effect not executed"
            }

            test "tapError only executes on failure" {
                let mutable errorCalled = false

                Error "fail" |> tapError (fun _ -> errorCalled <- true) |> ignore

                Expect.isTrue errorCalled "Error side effect executed"
            }
        ]

        testList "Conditional Application" [
            test "applyIf applies when true" {
                let result = 5 |> applyIf true (fun x -> x * 2)
                Expect.equal result 10 "Applied function"
            }

            test "applyIf skips when false" {
                let result = 5 |> applyIf false (fun x -> x * 2)
                Expect.equal result 5 "Skipped function"
            }

            test "applyWhen with predicate" {
                let doubleIfEven = applyWhen (fun x -> x % 2 = 0) (fun x -> x * 2)
                Expect.equal (doubleIfEven 4) 8 "Applied to even"
                Expect.equal (doubleIfEven 5) 5 "Skipped for odd"
            }

            test "applyN applies n times" {
                let double x = x * 2
                Expect.equal (applyN 3 double 1) 8 "1*2*2*2 = 8"
                Expect.equal (applyN 0 double 5) 5 "0 times returns input"
            }
        ]

        testList "Memoization" [
            test "memoize caches results" {
                let mutable callCount = 0
                let expensiveFn x =
                    callCount <- callCount + 1
                    x * 2

                let memoizedFn = memoize expensiveFn

                let r1 = memoizedFn 5
                let r2 = memoizedFn 5
                let r3 = memoizedFn 5

                Expect.equal r1 10 "Correct result"
                Expect.equal r2 10 "Same result from cache"
                Expect.equal r3 10 "Still cached"
                Expect.equal callCount 1 "Function called only once"
            }
        ]

        testList "Tuple Utilities" [
            test "mapFst transforms first element" {
                Expect.equal (mapFst ((+) 1) (5, "a")) (6, "a") "First element transformed"
            }

            test "mapSnd transforms second element" {
                Expect.equal (mapSnd String.length ("a", "hello")) ("a", 5) "Second element transformed"
            }

            test "swap exchanges elements" {
                Expect.equal (swap (1, 2)) (2, 1) "Elements swapped"
            }

            test "dup duplicates value" {
                Expect.equal (dup 42) (42, 42) "Value duplicated"
            }

            test "curry and uncurry" {
                let add (x, y) = x + y
                let curriedAdd = curry add
                Expect.equal (curriedAdd 3 5) 8 "Curried function works"

                let multiply x y = x * y
                let uncurriedMultiply = uncurry multiply
                Expect.equal (uncurriedMultiply (4, 5)) 20 "Uncurried function works"
            }
        ]

        testList "Option Utilities" [
            test "optionZip combines options" {
                Expect.equal (optionZip (Some 1) (Some 2)) (Some (1, 2)) "Both Some"
                Expect.isNone (optionZip None (Some 2)) "First None"
                Expect.isNone (optionZip (Some 1) None) "Second None"
            }

            test "optionFilter filters by predicate" {
                let isPositive x = x > 0
                Expect.equal (optionFilter isPositive (Some 5)) (Some 5) "Passes filter"
                Expect.isNone (optionFilter isPositive (Some -5)) "Fails filter"
                Expect.isNone (optionFilter isPositive None) "None stays None"
            }

            test "optionFlatten flattens nested option" {
                Expect.equal (optionFlatten (Some (Some 42))) (Some 42) "Flattened"
                Expect.isNone (optionFlatten (Some None)) "Inner None"
                Expect.isNone (optionFlatten None) "Outer None"
            }
        ]

        testList "Result Utilities" [
            test "resultZip combines results" {
                Expect.equal (resultZip (Ok 1) (Ok 2)) (Ok (1, 2)) "Both Ok"
                Expect.equal (resultZip (Error "e1") (Ok 2)) (Error "e1") "First Error"
                Expect.equal (resultZip (Ok 1) (Error "e2")) (Error "e2") "Second Error"
            }

            test "optionToResult converts" {
                Expect.equal (optionToResult "not found" (Some 42)) (Ok 42) "Some to Ok"
                Expect.equal (optionToResult "not found" None) (Error "not found") "None to Error"
            }

            test "resultToOption converts" {
                Expect.equal (resultToOption (Ok 42)) (Some 42) "Ok to Some"
                Expect.isNone (resultToOption (Error "err")) "Error to None"
            }
        ]

        testList "List Utilities" [
            test "interleave lists" {
                Expect.equal (interleave [1;2;3] [4;5;6]) [1;4;2;5;3;6] "Equal length lists"
                Expect.equal (interleave [1;2] [3;4;5;6]) [1;3;2;4;5;6] "Unequal length"
            }

            test "splitWhen splits at predicate" {
                let (before, after) = splitWhen (fun x -> x > 5) [1;2;3;6;7;8]
                Expect.equal before [1;2;3] "Before split"
                Expect.equal after [6;7;8] "After split (including match)"
            }
        ]

        testList "String Utilities" [
            test "joinWith joins strings" {
                Expect.equal (joinWith ", " ["a";"b";"c"]) "a, b, c" "Joined with comma"
            }

            test "splitOn splits string" {
                Expect.equal (splitOn "/" "a/b/c") ["a";"b";"c"] "Split by slash"
            }

            test "cleanLines removes empty and trims" {
                let input = "  line1  \n\n  line2  \n  \n  line3  "
                let result = cleanLines input
                Expect.equal result ["line1"; "line2"; "line3"] "Cleaned lines"
            }
        ]
    ]

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

[<Tests>]
let integrationTests =
    testList "F# Capability Integration" [

        test "compose units with active patterns" {
            let timeout = Timeout.fromSec 5.0<sec>
            let timeoutMs = Timeout.toMs timeout

            // Use string parsing pattern with units
            match "5000" with
            | StringParsing.Int n ->
                let parsedMs = Duration.ms (float n)
                Expect.floatClose Accuracy.high (float parsedMs) (float timeoutMs) "Timeout matches"
            | _ -> failtest "Should parse"
        }

        test "compose error handling with composition" {
            let errors = [
                PodmanError.ConnectionTimeout ("test", 1000L)
                PodmanError.SafetyConstraintViolation ("SC-001", "test")
                PodmanError.ContainerNotFound "abc"
            ]

            // Use composition to classify and filter
            let fatalErrors =
                errors
                |> List.filter (fun e ->
                    match e with
                    | ErrorRecoverability.Fatal -> true
                    | _ -> false)

            Expect.hasLength fatalErrors 1 "One fatal error"
        }

        test "pipeline with tap for debugging" {
            let mutable debugLog = []

            let result =
                42
                |> tap (fun x -> debugLog <- sprintf "Initial: %d" x :: debugLog)
                |> (fun x -> x * 2)
                |> tap (fun x -> debugLog <- sprintf "After double: %d" x :: debugLog)
                |> (fun x -> x + 10)
                |> tap (fun x -> debugLog <- sprintf "Final: %d" x :: debugLog)

            Expect.equal result 94 "Correct result"
            Expect.hasLength debugLog 3 "All taps executed"
        }
    ]

// Tests are run from Program.fs which registers all test lists
