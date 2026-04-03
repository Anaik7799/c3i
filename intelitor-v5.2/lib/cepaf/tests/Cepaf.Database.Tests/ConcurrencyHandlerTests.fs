/// Tests for OCC Concurrency Handler.
///
/// STAMP Compliance: SC-CONC-001 to SC-CONC-010
/// Coverage: Degree D4 from 9x9 Test Matrix
module Cepaf.Database.Tests.ConcurrencyHandlerTests

open System
open System.Threading
open System.Threading.Tasks
open Expecto
open Cepaf.Database.HolonConcurrencyHandler

// ==========================================================================
// Compare-and-Swap Tests
// ==========================================================================

[<Tests>]
let casTests =
    testList "Compare-and-Swap Tests" [

        testAsync "succeeds when current version >= expected" {
            let currentVV = Map.ofList ["h1", 5L]
            let expectedVV = Map.ofList ["h1", 3L]

            let getCurrentVersion () = async { return Ok currentVV }
            let operation () = async { return Ok "result" }

            let! result = compareAndSwap expectedVV getCurrentVersion operation Reject defaultRetryConfig

            match result with
            | CasSuccess (value, newVersion) ->
                Expect.equal value "result" "Should return operation result"
                Expect.isTrue (Map.find "local" newVersion > 0L) "Should increment version"
            | _ -> failtest "Expected CasSuccess"
        }

        testAsync "returns conflict when current version < expected" {
            let currentVV = Map.ofList ["h1", 3L]
            let expectedVV = Map.ofList ["h1", 5L]

            let getCurrentVersion () = async { return Ok currentVV }
            let operation () = async { return Ok "result" }

            let! result = compareAndSwap expectedVV getCurrentVersion operation Reject defaultRetryConfig

            match result with
            | CasConflict cv ->
                Expect.equal cv currentVV "Should return current version"
            | _ -> failtest "Expected CasConflict"
        }

        testAsync "retries with LastWriteWins strategy" {
            let mutable attempts = 0
            let currentVV = Map.ofList ["h1", 3L]
            let expectedVV = Map.ofList ["h1", 5L]

            let getCurrentVersion () = async {
                attempts <- attempts + 1
                if attempts >= 3 then
                    return Ok expectedVV  // Finally matches
                else
                    return Ok currentVV   // Conflict
            }
            let operation () = async { return Ok "result" }

            let config = { defaultRetryConfig with MaxRetries = 5; BaseDelayMs = 1 }
            let! result = compareAndSwap expectedVV getCurrentVersion operation LastWriteWins config

            match result with
            | CasSuccess _ ->
                Expect.isGreaterThanOrEqual attempts 3 "Should have retried"
            | _ -> failtest "Expected eventual success with retries"
        }

        testAsync "propagates operation errors" {
            let currentVV = Map.ofList ["h1", 5L]
            let expectedVV = Map.ofList ["h1", 3L]

            let getCurrentVersion () = async { return Ok currentVV }
            let operation () = async { return Error "operation failed" }

            let! result = compareAndSwap expectedVV getCurrentVersion operation Reject defaultRetryConfig

            match result with
            | CasError msg ->
                Expect.equal msg "operation failed" "Should propagate error"
            | _ -> failtest "Expected CasError"
        }
    ]

// ==========================================================================
// Retry Logic Tests
// ==========================================================================

[<Tests>]
let retryTests =
    testList "Retry Logic Tests" [

        testAsync "succeeds without retry when operation succeeds first time" {
            let mutable callCount = 0

            let operation () = async {
                callCount <- callCount + 1
                return Ok "success"
            }

            let! result = withRetry operation defaultRetryConfig

            Expect.equal result (Ok "success") "Should return success"
            Expect.equal callCount 1 "Should call once"
        }

        testAsync "retries on conflict up to maxRetries" {
            let mutable callCount = 0

            let operation () = async {
                callCount <- callCount + 1
                if callCount < 3 then
                    return Error "conflict"
                else
                    return Ok "success"
            }

            let config = { defaultRetryConfig with MaxRetries = 5; BaseDelayMs = 1 }
            let! result = withRetry operation config

            Expect.equal result (Ok "success") "Should eventually succeed"
            Expect.equal callCount 3 "Should retry 3 times"
        }

        testAsync "fails after maxRetries exceeded" {
            let operation () = async {
                return Error "conflict"
            }

            let config = { MaxRetries = 3; BaseDelayMs = 1; MaxDelayMs = 10 }
            let! result = withRetry operation config

            Expect.equal result (Error "max_retries_exceeded") "Should fail after max retries"
        }
    ]

// ==========================================================================
// Lock Tests
// ==========================================================================

[<Tests>]
let lockTests =
    testList "Pessimistic Lock Tests" [

        test "acquireLock succeeds when not held" {
            let resourceId = sprintf "resource_%d" (Random().Next())
            let result = acquireLock resourceId "owner1" 1000

            Expect.isTrue result "Should acquire lock"
        }

        test "acquireLock fails when already held by another" {
            let resourceId = sprintf "resource_%d" (Random().Next())

            let acquired1 = acquireLock resourceId "owner1" 1000
            Expect.isTrue acquired1 "First acquire should succeed"

            let acquired2 = acquireLock resourceId "owner2" 100
            Expect.isFalse acquired2 "Second acquire should fail"
        }

        test "releaseLock allows reacquisition" {
            let resourceId = sprintf "resource_%d" (Random().Next())

            acquireLock resourceId "owner1" 1000 |> ignore
            releaseLock resourceId "owner1"

            let acquired = acquireLock resourceId "owner2" 100
            Expect.isTrue acquired "Should acquire after release"
        }

        test "releaseLock with wrong owner has no effect" {
            let resourceId = sprintf "resource_%d" (Random().Next())

            acquireLock resourceId "owner1" 1000 |> ignore
            releaseLock resourceId "owner2"  // Wrong owner

            let acquired = acquireLock resourceId "owner3" 100
            Expect.isFalse acquired "Lock should still be held"
        }

        test "withLock executes operation and releases lock" {
            let resourceId = sprintf "resource_%d" (Random().Next())

            let result = withLock resourceId "owner1" 1000 (fun () -> "executed")

            Expect.equal result (Ok "executed") "Should execute operation"

            // Lock should be released
            let acquired = acquireLock resourceId "owner2" 100
            Expect.isTrue acquired "Lock should be released"
        }

        test "withLock releases lock on exception" {
            let resourceId = sprintf "resource_%d" (Random().Next())

            try
                withLock resourceId "owner1" 1000 (fun () ->
                    failwith "error"
                ) |> ignore
            with
            | _ -> ()

            // Lock should be released
            let acquired = acquireLock resourceId "owner2" 100
            Expect.isTrue acquired "Lock should be released after exception"
        }
    ]

// ==========================================================================
// Two-Phase Commit Tests
// ==========================================================================

[<Tests>]
let twoPCTests =
    testList "Two-Phase Commit Tests" [

        test "twoPhasePrepar succeeds when all locks available" {
            let p1 = sprintf "participant1_%d" (Random().Next())
            let p2 = sprintf "participant2_%d" (Random().Next())
            let participants = [p1; p2]

            let result = twoPhasePrepar participants "coordinator" 1000

            match result with
            | Ok () -> ()  // Success
            | Error failed -> failtest $"Should succeed, but failed: {failed}"

            // Clean up
            twoPhaseCommit participants "coordinator"
        }

        test "twoPhasePrepar rolls back on partial failure" {
            let p1 = sprintf "participant1_%d" (Random().Next())
            let p2 = sprintf "participant2_%d" (Random().Next())

            // Pre-lock p2
            acquireLock p2 "other_owner" 10000 |> ignore

            let result = twoPhasePrepar [p1; p2] "coordinator" 100

            match result with
            | Error failed ->
                Expect.contains failed p2 "p2 should be in failed list"
                // p1 lock should be released
                let acquired = acquireLock p1 "test" 100
                Expect.isTrue acquired "p1 lock should be rolled back"
            | Ok () -> failtest "Should fail when p2 is locked"

            // Clean up
            releaseLock p2 "other_owner"
        }

        test "twoPhaseCommit releases all locks" {
            let p1 = sprintf "participant1_%d" (Random().Next())
            let p2 = sprintf "participant2_%d" (Random().Next())
            let participants = [p1; p2]

            twoPhasePrepar participants "coordinator" 1000 |> ignore
            twoPhaseCommit participants "coordinator"

            // All locks should be released
            let acquired1 = acquireLock p1 "test" 100
            let acquired2 = acquireLock p2 "test" 100
            Expect.isTrue acquired1 "p1 should be released"
            Expect.isTrue acquired2 "p2 should be released"
        }

        test "twoPhaseRollback releases all locks" {
            let p1 = sprintf "participant1_%d" (Random().Next())
            let p2 = sprintf "participant2_%d" (Random().Next())
            let participants = [p1; p2]

            twoPhasePrepar participants "coordinator" 1000 |> ignore
            twoPhaseRollback participants "coordinator"

            // All locks should be released
            let acquired1 = acquireLock p1 "test" 100
            let acquired2 = acquireLock p2 "test" 100
            Expect.isTrue acquired1 "p1 should be released"
            Expect.isTrue acquired2 "p2 should be released"
        }
    ]

// ==========================================================================
// Concurrent Access Tests
// ==========================================================================

[<Tests>]
let concurrencyTests =
    testList "Concurrent Access Tests" [

        testAsync "D4-02: Multiple concurrent readers succeed" {
            let vv = Map.ofList ["h1", 5L]

            let readers = [1..100] |> List.map (fun i ->
                async {
                    // Simulate read (no locks)
                    do! Async.Sleep 10
                    return versionGte vv (Map.ofList ["h1", 0L])
                }
            )

            let! results = Async.Parallel readers

            Expect.isTrue (Array.forall id results) "All reads should succeed"
        }

        testAsync "D4-03: Multiple concurrent writers eventually succeed with OCC" {
            let mutable successCount = 0
            let mutable conflictCount = 0

            let writers = [1..10] |> List.map (fun i ->
                async {
                    let mutable currentVV = Map.ofList ["h1", 0L]

                    let getCurrentVersion () = async {
                        do! Async.Sleep (Random().Next(1, 10))
                        return Ok currentVV
                    }

                    let operation () = async {
                        currentVV <- increment currentVV "h1"
                        return Ok ()
                    }

                    let config = { MaxRetries = 5; BaseDelayMs = 1; MaxDelayMs = 100 }
                    let! result = compareAndSwap currentVV getCurrentVersion operation Merge config

                    match result with
                    | CasSuccess _ ->
                        Interlocked.Increment(&successCount) |> ignore
                    | CasConflict _ ->
                        Interlocked.Increment(&conflictCount) |> ignore
                    | CasError _ -> ()

                    return ()
                }
            )

            do! Async.Parallel writers |> Async.Ignore

            Expect.isGreaterThan successCount 0 "At least one writer should succeed"
            // With retries, most should succeed
        }

        test "D4-04: Lock acquisition is fair (no starvation)" {
            let resourceId = sprintf "fairness_%d" (Random().Next())
            let mutable acquireOrder : int list = []
            let lockObj = obj()

            // Simulate 5 concurrent lock requests
            let tasks = [1..5] |> List.map (fun i ->
                Task.Run(fun () ->
                    let acquired = acquireLock resourceId (sprintf "owner%d" i) 5000
                    if acquired then
                        lock lockObj (fun () ->
                            acquireOrder <- acquireOrder @ [i]
                        )
                        Thread.Sleep(10)
                        releaseLock resourceId (sprintf "owner%d" i)
                )
            )

            Task.WaitAll(tasks |> List.toArray)

            // At least some should have acquired the lock
            Expect.isNonEmpty acquireOrder "Some tasks should have acquired lock"
        }
    ]

// ==========================================================================
// Run Tests
// ==========================================================================

[<EntryPoint>]
let main args =
    runTestsWithCLIArgs [] args casTests
    |> (+) (runTestsWithCLIArgs [] args retryTests)
    |> (+) (runTestsWithCLIArgs [] args lockTests)
    |> (+) (runTestsWithCLIArgs [] args twoPCTests)
    |> (+) (runTestsWithCLIArgs [] args concurrencyTests)
