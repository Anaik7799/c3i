namespace Cepaf.Database.Tests

/// Comprehensive 9-Degree Interop Test Suite for Cross-Holon Database Access
///
/// Tests all interaction dimensions between F# and Elixir holons:
/// - D1: Cross-Runtime (Fs→Ex, Ex→Fs via Zenoh)
/// - D2: Database Types (SQLite, DuckDB variations)
/// - D3: Operations (query, execute, CAS, batch)
/// - D4: Concurrency (concurrent reads/writes, OCC)
/// - D5: Transactions (2PC commit/abort/recovery)
/// - D6: Failures (timeout, partition, crash)
/// - D7: Performance (latency SLAs)
/// - D8: Security (injection, traversal, auth)
/// - D9: Recovery (crash recovery, checkpoint restore)
///
/// STAMP Constraints:
/// - SC-XHOLON-001: UHI format validation
/// - SC-XHOLON-010: Zenoh bridge mandatory for cross-runtime
/// - SC-XHOLON-015: 2PC required for cross-runtime writes
/// - SC-XHOLON-020: OCC version vectors for concurrency
/// - SC-XHOLON-030: Circuit breaker for failures
/// - SC-XHOLON-040: Performance SLAs
/// - SC-XHOLON-045: Security constraints
/// - SC-XHOLON-050: Recovery completeness
module CrossHolonInterop9DegreeTests

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open System.Diagnostics
open Expecto
open FsCheck

open Cepaf.Database.CrossHolonAccess
open Cepaf.Database.ZenohBridge
open Cepaf.Database.VersionVector
open Cepaf.Database.TwoPhaseCommit

// ============================================================================
// Test Helpers and Setup
// ============================================================================

type TestContext = {
    FsHolonId: string
    ExHolonId: string
    ZenohConnected: bool
    TxId: string
}

let private createTestContext () =
    let fsHolonId = sprintf "fs:l3:test:holon:interop_%d" (Random().Next())
    let exHolonId = sprintf "ex:l3:test:holon:interop_%d" (Random().Next())
    let txId = sprintf "tx_%d" (Random().Next())

    // Initialize test holons
    match ZenohBridge.ensureConnected() with
    | Ok () ->
        CrossHolonAccess.initializeHolon fsHolonId |> ignore
        ZenohBridge.remoteInitializeHolon exHolonId |> ignore
        { FsHolonId = fsHolonId
          ExHolonId = exHolonId
          ZenohConnected = true
          TxId = txId }
    | Error _ ->
        { FsHolonId = fsHolonId
          ExHolonId = exHolonId
          ZenohConnected = false
          TxId = txId }

let private cleanupContext (ctx: TestContext) =
    CrossHolonAccess.cleanupHolon ctx.FsHolonId |> ignore
    if ctx.ZenohConnected then
        ZenohBridge.remoteCleanupHolon ctx.ExHolonId |> ignore

let private skipIfNoZenoh (ctx: TestContext) testName =
    if not ctx.ZenohConnected then
        skiptest (sprintf "Skipping %s - Zenoh not connected" testName)

// ============================================================================
// D1: Cross-Runtime Interaction Tests (Fs→Ex, Ex→Fs via Zenoh)
// ============================================================================

[<Tests>]
let d1CrossRuntimeTests =
    testList "D1: Cross-Runtime Interactions" [
        testCase "D1.1: F# holon queries Elixir holon state database via Zenoh" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D1.1"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Setup: Write data to Elixir holon via Zenoh
                ZenohBridge.remoteExecute exUhi
                    "INSERT INTO holon_state (key, value) VALUES ('fs_query_test', 'test_value')" []
                |> function Ok _ -> () | Error e -> failwithf "Setup failed: %A" e

                // Test: Query from F# holon
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let result = CrossHolonAccess.crossRuntimeQuery fsUhi exUhi
                    "SELECT value FROM holon_state WHERE key = ?" ["fs_query_test"]

                match result with
                | Ok rows ->
                    Expect.isGreaterThan (List.length rows) 0 "Should return rows"
                    Expect.equal (rows.[0].["value"]) "test_value" "Value should match"
                | Error e -> failwithf "Query failed: %A" e
            finally
                cleanupContext ctx

        testCase "D1.2: Elixir holon queries F# holon analytics database via Zenoh" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D1.2"

            try
                let fsAnalyticsUhi = sprintf "%s:analytics.duckdb" ctx.FsHolonId

                // Setup: Write data to F# holon DuckDB
                CrossHolonAccess.execute fsAnalyticsUhi
                    "INSERT INTO analytics_events (event_type, timestamp, data) VALUES ('test_event', now(), '{\"foo\": \"bar\"}')" []
                |> function Ok _ -> () | Error e -> failwithf "Setup failed: %A" e

                // Test: Query from Elixir holon via Zenoh (simulated)
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId
                let result = ZenohBridge.requestRemoteQuery exUhi fsAnalyticsUhi
                    "SELECT event_type, data FROM analytics_events WHERE event_type = ?" ["test_event"]

                match result with
                | Ok rows ->
                    Expect.isGreaterThan (List.length rows) 0 "Should return rows"
                    Expect.equal (rows.[0].["event_type"]) "test_event" "Event type should match"
                | Error e -> failwithf "Query failed: %A" e
            finally
                cleanupContext ctx

        testCase "D1.3: Bidirectional cross-runtime write with 2PC" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D1.3"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Start 2PC transaction spanning both runtimes
                let coordinator = TwoPhaseCommit.startCoordinator ctx.TxId [fsUhi; exUhi]

                match coordinator with
                | Ok coord ->
                    // Phase 1: Prepare
                    let fsPrep = TwoPhaseCommit.prepare coord fsUhi (fun () ->
                        CrossHolonAccess.execute fsUhi
                            "INSERT INTO sync_log (source, target) VALUES (?, ?)"
                            [ctx.FsHolonId; ctx.ExHolonId])

                    let exPrep = TwoPhaseCommit.prepare coord exUhi (fun () ->
                        ZenohBridge.remoteExecute exUhi
                            "INSERT INTO sync_log (source, target) VALUES (?, ?)"
                            [ctx.ExHolonId; ctx.FsHolonId])

                    Expect.isOk fsPrep "F# prepare should succeed"
                    Expect.isOk exPrep "Ex prepare should succeed"

                    // Phase 2: Commit
                    let commitResult = TwoPhaseCommit.commit coord
                    Expect.isOk commitResult "Commit should succeed"

                    // Verify both writes
                    let fsRows = CrossHolonAccess.query fsUhi "SELECT * FROM sync_log" []
                    let exRows = ZenohBridge.remoteQuery exUhi exUhi "SELECT * FROM sync_log" []

                    match fsRows, exRows with
                    | Ok fs, Ok ex ->
                        Expect.isGreaterThan (List.length fs) 0 "F# should have rows"
                        Expect.isGreaterThan (List.length ex) 0 "Ex should have rows"
                    | _ -> failwith "Verification queries failed"
                | Error e -> failwithf "Coordinator failed: %A" e
            finally
                cleanupContext ctx

        testCase "D1.4: Cross-runtime message ordering via Zenoh FIFO" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D1.4"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Send multiple messages in sequence
                let messages = [1..10] |> List.map (fun i ->
                    {| seq = i; timestamp = DateTime.UtcNow.Ticks |})

                // Send all messages through Zenoh
                messages |> List.iter (fun msg ->
                    ZenohBridge.sendOrdered exUhi ("insert", msg) |> ignore)

                Thread.Sleep(100)

                // Verify FIFO ordering
                match ZenohBridge.getReceivedMessages exUhi with
                | Ok received ->
                    let sequences = received |> List.map (fun m -> m.["seq"] :?> int)
                    Expect.equal sequences (List.sort sequences) "Messages should be in FIFO order"
                | Error e -> failwithf "Get messages failed: %A" e
            finally
                cleanupContext ctx

        testCase "D1.5: Cross-runtime version vector synchronization" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D1.5"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Get initial version vectors
                let fsVv = CrossHolonAccess.getVersionVector fsUhi
                let exVv = ZenohBridge.remoteGetVersionVector exUhi

                match fsVv, exVv with
                | Ok fv, Ok ev ->
                    // Update F# holon
                    let newFsVv = CrossHolonAccess.incrementVersion fsUhi ctx.FsHolonId

                    match newFsVv with
                    | Ok nfv ->
                        // Sync version vectors across runtimes
                        let mergedResult = ZenohBridge.syncVersionVectors fsUhi exUhi nfv

                        match mergedResult with
                        | Ok merged ->
                            // Verify merge properties
                            let happensBefore = VersionVector.happensBefore fv merged
                            let concurrent = VersionVector.concurrent fv merged
                            Expect.isTrue (happensBefore || concurrent || fv = merged)
                                "Merged VV should dominate or be concurrent with original"
                        | Error e -> failwithf "Sync failed: %A" e
                    | Error e -> failwithf "Increment failed: %A" e
                | _ -> failwith "Initial VV fetch failed"
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D2: Database Type Interaction Tests
// ============================================================================

[<Tests>]
let d2DatabaseTypeTests =
    testList "D2: Database Type Interactions" [
        testCase "D2.1: SQLite state to DuckDB analytics cross-type query" <| fun () ->
            let ctx = createTestContext()

            try
                let stateUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let analyticsUhi = sprintf "%s:analytics.duckdb" ctx.FsHolonId

                // Insert state data
                CrossHolonAccess.execute stateUhi
                    "INSERT INTO holon_state (key, value, updated_at) VALUES ('metric_1', '100', datetime('now'))" []
                |> ignore

                // Query state and insert into analytics
                let stateRows = CrossHolonAccess.query stateUhi
                    "SELECT key, value FROM holon_state WHERE key = ?" ["metric_1"]

                match stateRows with
                | Ok rows when List.length rows > 0 ->
                    let row = rows.[0]
                    CrossHolonAccess.execute analyticsUhi
                        "INSERT INTO state_snapshots (key, value, snapshot_time) VALUES (?, ?, now())"
                        [row.["key"]; row.["value"]]
                    |> ignore

                    // Verify cross-type operation
                    let analyticsRows = CrossHolonAccess.query analyticsUhi
                        "SELECT key, value FROM state_snapshots WHERE key = ?" ["metric_1"]

                    match analyticsRows with
                    | Ok arows ->
                        Expect.equal (List.length arows) 1 "Should have one analytics row"
                        Expect.equal (arows.[0].["value"]) "100" "Value should match"
                    | Error e -> failwithf "Analytics query failed: %A" e
                | _ -> failwith "State query failed"
            finally
                cleanupContext ctx

        testCase "D2.2: All 6 database types accessible within holon" <| fun () ->
            let ctx = createTestContext()

            try
                let dbTypes =
                    [ ("state", "sqlite"); ("vectors", "sqlite"); ("cache", "sqlite")
                      ("analytics", "duckdb"); ("history", "duckdb"); ("register", "duckdb") ]

                let results = dbTypes |> List.map (fun (dbType, ext) ->
                    let uhi = sprintf "%s:%s.%s" ctx.FsHolonId dbType ext
                    match CrossHolonAccess.ping uhi with
                    | Ok () -> (dbType, true)
                    | Error _ -> (dbType, false))

                let allAccessible = results |> List.forall snd
                Expect.isTrue allAccessible "All 6 database types should be accessible"
            finally
                cleanupContext ctx

        testCase "D2.3: Cross-runtime heterogeneous database access (Fs SQLite → Ex DuckDB)" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D2.3"

            try
                let fsSqliteUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exDuckdbUhi = sprintf "%s:analytics.duckdb" ctx.ExHolonId

                // Write to Fs SQLite
                CrossHolonAccess.execute fsSqliteUhi
                    "INSERT INTO holon_state (key, value) VALUES ('cross_type_test', '42')" []
                |> ignore

                // Query Fs SQLite
                match CrossHolonAccess.query fsSqliteUhi
                    "SELECT value FROM holon_state WHERE key = ?" ["cross_type_test"] with
                | Ok [row] ->
                    // Write result to Ex DuckDB via Zenoh
                    ZenohBridge.remoteExecute exDuckdbUhi
                        "INSERT INTO cross_runtime_data (source_runtime, source_db, value) VALUES ('fsharp', 'sqlite', ?)"
                        [row.["value"]]
                    |> ignore

                    // Verify via Zenoh query
                    match ZenohBridge.remoteQuery exDuckdbUhi exDuckdbUhi
                        "SELECT value FROM cross_runtime_data WHERE source_runtime = ?" ["fsharp"] with
                    | Ok [result] ->
                        Expect.equal (result.["value"]) "42" "Value should match"
                    | _ -> failwith "Verification failed"
                | _ -> failwith "Initial query failed"
            finally
                cleanupContext ctx

        testCase "D2.4: DuckDB analytical query across history database" <| fun () ->
            let ctx = createTestContext()

            try
                let historyUhi = sprintf "%s:history.duckdb" ctx.FsHolonId
                let rng = Random()

                // Insert historical data
                [1..100] |> List.iter (fun i ->
                    CrossHolonAccess.execute historyUhi
                        (sprintf "INSERT INTO evolution_events (generation, fitness, timestamp) VALUES (%d, %f, now() - INTERVAL '%d' MINUTE)"
                            i (rng.NextDouble()) i) []
                    |> ignore)

                // Analytical query
                match CrossHolonAccess.query historyUhi
                    "SELECT COUNT(*) as total_events, AVG(fitness) as avg_fitness, MAX(generation) as max_generation FROM evolution_events" [] with
                | Ok [result] ->
                    Expect.isGreaterThanOrEqual (result.["total_events"] :?> int64) 100L "Should have 100+ events"
                    Expect.isGreaterThan (result.["avg_fitness"] :?> float) 0.0 "Avg fitness should be positive"
                    Expect.isGreaterThanOrEqual (result.["max_generation"] :?> int) 100 "Max generation should be 100+"
                | _ -> failwith "Analytical query failed"
            finally
                cleanupContext ctx

        testCase "D2.5: Vector database embedding operations" <| fun () ->
            let ctx = createTestContext()

            try
                let vectorsUhi = sprintf "%s:vectors.sqlite" ctx.FsHolonId
                let rng = Random()

                // Create test embedding
                let embedding = [| for _ in 1..128 -> rng.NextDouble() |]
                let embeddingJson = sprintf "[%s]" (String.Join(",", embedding |> Array.map string))

                CrossHolonAccess.execute vectorsUhi
                    "INSERT INTO embeddings (holon_id, embedding, metadata) VALUES (?, ?, '{\"type\": \"test\"}')"
                    [ctx.FsHolonId; embeddingJson]
                |> ignore

                // Query
                match CrossHolonAccess.query vectorsUhi
                    "SELECT holon_id, metadata FROM embeddings WHERE holon_id = ?" [ctx.FsHolonId] with
                | Ok rows ->
                    Expect.equal (List.length rows) 1 "Should have one embedding"
                    Expect.equal (rows.[0].["holon_id"]) ctx.FsHolonId "Holon ID should match"
                | Error e -> failwithf "Query failed: %A" e
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D3: Operation Type Tests
// ============================================================================

[<Tests>]
let d3OperationTests =
    testList "D3: Operation Types" [
        testCase "D3.1: Query operation with parameters" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Setup data
                CrossHolonAccess.execute uhi "INSERT INTO holon_state (key, value) VALUES ('q1', 'v1')" [] |> ignore
                CrossHolonAccess.execute uhi "INSERT INTO holon_state (key, value) VALUES ('q2', 'v2')" [] |> ignore

                // Parameterized query
                match CrossHolonAccess.query uhi "SELECT * FROM holon_state WHERE key IN (?, ?)" ["q1"; "q2"] with
                | Ok rows -> Expect.equal (List.length rows) 2 "Should return 2 rows"
                | Error e -> failwithf "Query failed: %A" e
            finally
                cleanupContext ctx

        testCase "D3.2: Execute operation (INSERT/UPDATE/DELETE)" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // INSERT
                let insertResult = CrossHolonAccess.executeReturning uhi
                    "INSERT INTO holon_state (key, value) VALUES ('exec_test', 'initial') RETURNING rowid" []
                match insertResult with
                | Ok r -> Expect.isGreaterThanOrEqual r.RowsAffected 1 "Insert should affect 1+ rows"
                | Error e -> failwithf "Insert failed: %A" e

                // UPDATE
                let updateResult = CrossHolonAccess.executeReturning uhi
                    "UPDATE holon_state SET value = 'updated' WHERE key = 'exec_test' RETURNING rowid" []
                match updateResult with
                | Ok r -> Expect.equal r.RowsAffected 1 "Update should affect 1 row"
                | Error e -> failwithf "Update failed: %A" e

                // DELETE
                let deleteResult = CrossHolonAccess.executeReturning uhi
                    "DELETE FROM holon_state WHERE key = 'exec_test' RETURNING rowid" []
                match deleteResult with
                | Ok r -> Expect.equal r.RowsAffected 1 "Delete should affect 1 row"
                | Error e -> failwithf "Delete failed: %A" e
            finally
                cleanupContext ctx

        testCase "D3.3: CAS (Compare-And-Swap) operation" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Setup initial value with version
                CrossHolonAccess.execute uhi
                    "INSERT INTO versioned_state (key, value, version) VALUES ('cas_key', 'v0', 1)" []
                |> ignore

                // CAS with correct expected version - should succeed
                match CrossHolonAccess.compareAndSwap uhi "cas_key" "v0" "v1" 1 with
                | Ok newVersion ->
                    Expect.equal newVersion 2 "New version should be 2"
                | Error e -> failwithf "CAS should succeed: %A" e

                // CAS with stale expected version - should fail
                match CrossHolonAccess.compareAndSwap uhi "cas_key" "v1" "v2" 1 with
                | Ok _ -> failwith "CAS with stale version should fail"
                | Error VersionMismatch _ -> () // Expected
                | Error e -> failwithf "Unexpected error: %A" e
            finally
                cleanupContext ctx

        testCase "D3.4: Batch operation execution" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                let operations = [1..10] |> List.map (fun i ->
                    (Insert, sprintf "INSERT INTO holon_state (key, value) VALUES ('batch_%d', 'val_%d')" i i))

                // Execute batch atomically
                match CrossHolonAccess.executeBatch uhi operations with
                | Ok results ->
                    Expect.equal (List.length results) 10 "Should have 10 results"
                    Expect.isTrue (results |> List.forall (fun r -> r.RowsAffected = 1))
                        "All operations should affect 1 row"
                | Error e -> failwithf "Batch failed: %A" e

                // Verify all inserted
                match CrossHolonAccess.query uhi
                    "SELECT COUNT(*) as cnt FROM holon_state WHERE key LIKE 'batch_%'" [] with
                | Ok [row] ->
                    Expect.equal (row.["cnt"] :?> int64) 10L "Should have 10 rows"
                | _ -> failwith "Verification failed"
            finally
                cleanupContext ctx

        testCase "D3.5: Cross-runtime CAS via Zenoh" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D3.5"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Setup in Elixir holon
                ZenohBridge.remoteExecute exUhi
                    "INSERT INTO versioned_state (key, value, version) VALUES ('remote_cas', 'initial', 1)" []
                |> ignore

                // CAS from F# to Elixir via Zenoh
                match ZenohBridge.remoteCas exUhi "remote_cas" "initial" "updated" 1 with
                | Ok newVersion ->
                    Expect.equal newVersion 2 "New version should be 2"

                    // Verify
                    match ZenohBridge.remoteQuery exUhi exUhi
                        "SELECT value, version FROM versioned_state WHERE key = ?" ["remote_cas"] with
                    | Ok [row] ->
                        Expect.equal (row.["value"]) "updated" "Value should be updated"
                        Expect.equal (row.["version"] :?> int) 2 "Version should be 2"
                    | _ -> failwith "Verification failed"
                | Error e -> failwithf "Remote CAS failed: %A" e
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D4: Concurrency Tests
// ============================================================================

[<Tests>]
let d4ConcurrencyTests =
    testList "D4: Concurrency" [
        testCase "D4.1: Concurrent reads don't block each other" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Setup data
                CrossHolonAccess.execute uhi
                    "INSERT INTO holon_state (key, value) VALUES ('concurrent_read', 'data')" []
                |> ignore

                // Spawn concurrent readers
                let tasks = [1..10] |> List.map (fun _ ->
                    Task.Run(fun () ->
                        let sw = Stopwatch.StartNew()
                        CrossHolonAccess.query uhi
                            "SELECT * FROM holon_state WHERE key = ?" ["concurrent_read"]
                        |> ignore
                        sw.ElapsedMilliseconds))

                let results = tasks |> List.map (fun t -> t.Result) |> Array.ofList

                // All should complete within reasonable time (no blocking)
                Expect.isTrue (results |> Array.forall (fun t -> t < 100L))
                    "All reads should complete within 100ms"
            finally
                cleanupContext ctx

        testCase "D4.2: Concurrent writes with OCC version vectors" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let key = sprintf "occ_test_%d" (Random().Next())

                // Initialize
                CrossHolonAccess.execute uhi
                    (sprintf "INSERT INTO versioned_state (key, value, version) VALUES ('%s', 'v0', 1)" key) []
                |> ignore

                // Spawn concurrent writers
                let results = ConcurrentBag<int * Result<int, CrossHolonError>>()

                let tasks = [1..5] |> List.map (fun i ->
                    Task.Run(fun () ->
                        // Read current version
                        match CrossHolonAccess.query uhi
                            "SELECT version FROM versioned_state WHERE key = ?" [key] with
                        | Ok [row] ->
                            let version = row.["version"] :?> int
                            // Try to update with OCC
                            let result = CrossHolonAccess.compareAndSwap uhi key
                                (sprintf "v%d" (i-1)) (sprintf "v%d" i) version
                            results.Add((i, result))
                        | _ -> ()))

                Task.WaitAll(tasks |> Array.ofList)

                let resultList = results |> Seq.toList
                let successes = resultList |> List.filter (fun (_, r) -> match r with Ok _ -> true | _ -> false)
                let failures = resultList |> List.filter (fun (_, r) -> match r with Error (VersionMismatch _) -> true | _ -> false)

                Expect.equal (List.length successes) 1 "Exactly one writer should succeed"
                Expect.equal (List.length failures) 4 "Four writers should fail with version mismatch"
            finally
                cleanupContext ctx

        testCase "D4.3: Version vector merge on concurrent cross-holon updates" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D4.3"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Concurrent updates from both holons
                let task1 = Task.Run(fun () ->
                    CrossHolonAccess.incrementVersion fsUhi ctx.FsHolonId)

                let task2 = Task.Run(fun () ->
                    ZenohBridge.remoteIncrementVersion exUhi ctx.ExHolonId)

                Task.WaitAll([| task1; task2 |])

                match task1.Result, task2.Result with
                | Ok fsVv, Ok exVv ->
                    // Merge version vectors
                    let merged = VersionVector.merge fsVv exVv

                    // Merged should dominate both
                    let fsOk = VersionVector.happensBefore fsVv merged || fsVv = merged
                    let exOk = VersionVector.happensBefore exVv merged || exVv = merged

                    Expect.isTrue fsOk "Merged should dominate F# VV"
                    Expect.isTrue exOk "Merged should dominate Ex VV"
                | _ -> failwith "Concurrent updates failed"
            finally
                cleanupContext ctx

        testCase "D4.4: Connection pool under concurrent load" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Exhaust connection pool with concurrent operations
                let results = ConcurrentBag<Result<unit, CrossHolonError>>()

                let tasks = [1..50] |> List.map (fun i ->
                    Task.Run(fun () ->
                        match CrossHolonAccess.query uhi "SELECT ? as val" [string i] with
                        | Ok _ -> results.Add(Ok ())
                        | Error PoolExhausted -> results.Add(Error PoolExhausted)
                        | Error e -> results.Add(Error e)))

                Task.WaitAll(tasks |> Array.ofList)

                let resultList = results |> Seq.toList
                let successes = resultList |> List.filter (function Ok _ -> true | _ -> false) |> List.length

                Expect.isGreaterThanOrEqual successes 10
                    "At least 10 should succeed even under load"
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D5: Transaction Tests (2PC)
// ============================================================================

[<Tests>]
let d5TransactionTests =
    testList "D5: Transactions (2PC)" [
        testCase "D5.1: 2PC commit succeeds when all participants prepared" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D5.1"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId
                let key = sprintf "2pc_commit_%s" ctx.TxId

                match TwoPhaseCommit.startCoordinator ctx.TxId [fsUhi; exUhi] with
                | Ok coordinator ->
                    // Phase 1: Prepare
                    let fsPrep = TwoPhaseCommit.prepare coordinator fsUhi (fun () ->
                        CrossHolonAccess.execute fsUhi
                            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'prepared')" [key])

                    let exPrep = TwoPhaseCommit.prepare coordinator exUhi (fun () ->
                        ZenohBridge.remoteExecute exUhi
                            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'prepared')" [key])

                    Expect.isOk fsPrep "F# prepare should succeed"
                    Expect.isOk exPrep "Ex prepare should succeed"

                    // Phase 2: Commit
                    let commitResult = TwoPhaseCommit.commit coordinator
                    Expect.isOk commitResult "Commit should succeed"

                    // Verify both committed
                    match CrossHolonAccess.query fsUhi "SELECT status FROM tx_log WHERE tx_id = ?" [key] with
                    | Ok [row] -> Expect.equal (row.["status"]) "prepared" "F# data should exist"
                    | _ -> failwith "F# verification failed"

                    match ZenohBridge.remoteQuery exUhi exUhi "SELECT status FROM tx_log WHERE tx_id = ?" [key] with
                    | Ok [row] -> Expect.equal (row.["status"]) "prepared" "Ex data should exist"
                    | _ -> failwith "Ex verification failed"
                | Error e -> failwithf "Coordinator failed: %A" e
            finally
                cleanupContext ctx

        testCase "D5.2: 2PC abort when participant fails to prepare" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D5.2"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId
                let key = sprintf "2pc_abort_%s" ctx.TxId

                match TwoPhaseCommit.startCoordinator ctx.TxId [fsUhi; exUhi] with
                | Ok coordinator ->
                    // Prepare F# - succeeds
                    let fsPrep = TwoPhaseCommit.prepare coordinator fsUhi (fun () ->
                        CrossHolonAccess.execute fsUhi
                            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'prepared')" [key])
                    Expect.isOk fsPrep "F# prepare should succeed"

                    // Prepare Ex - fails (simulate constraint violation)
                    let exPrep = TwoPhaseCommit.prepare coordinator exUhi (fun () ->
                        Error (ConstraintViolation "Simulated failure"))
                    Expect.isError exPrep "Ex prepare should fail"

                    // Abort phase
                    let abortResult = TwoPhaseCommit.abort coordinator
                    Expect.isOk abortResult "Abort should succeed"

                    // Verify F# side was rolled back
                    match CrossHolonAccess.query fsUhi "SELECT * FROM tx_log WHERE tx_id = ?" [key] with
                    | Ok rows -> Expect.isEmpty rows "Aborted transaction should not leave data"
                    | Error e -> failwithf "Query failed: %A" e
                | Error e -> failwithf "Coordinator failed: %A" e
            finally
                cleanupContext ctx

        testCase "D5.3: 2PC timeout triggers abort" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D5.3"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                match TwoPhaseCommit.startCoordinatorWithTimeout ctx.TxId [fsUhi; exUhi] 100 with
                | Ok coordinator ->
                    // Prepare F# - succeeds
                    let fsPrep = TwoPhaseCommit.prepare coordinator fsUhi (fun () -> Ok ())
                    Expect.isOk fsPrep "F# prepare should succeed"

                    // Ex prepare takes too long
                    let exPrep = TwoPhaseCommit.prepare coordinator exUhi (fun () ->
                        Thread.Sleep(200)  // Exceeds timeout
                        Ok ())

                    match exPrep with
                    | Error Timeout -> () // Expected
                    | _ -> failwith "Should have timed out"

                    // Transaction should be aborted
                    let state = TwoPhaseCommit.getState coordinator
                    Expect.isTrue (state.Status = Aborted || state.Status = Aborting)
                        "Transaction should be aborted"
                | Error e -> failwithf "Coordinator failed: %A" e
            finally
                cleanupContext ctx

        testCase "D5.4: Transaction isolation - uncommitted reads not visible" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let key = sprintf "isolation_test_%s" ctx.TxId

                match TwoPhaseCommit.startCoordinator ctx.TxId [uhi] with
                | Ok coordinator ->
                    // Start transaction and prepare write
                    let prep = TwoPhaseCommit.prepare coordinator uhi (fun () ->
                        CrossHolonAccess.execute uhi
                            "INSERT INTO holon_state (key, value) VALUES (?, 'uncommitted')" [key])
                    Expect.isOk prep "Prepare should succeed"

                    // Before commit, read from another connection
                    match CrossHolonAccess.queryWithIsolation uhi
                        "SELECT * FROM holon_state WHERE key = ?" [key] ReadCommitted with
                    | Ok rows ->
                        Expect.isEmpty rows "Should not see uncommitted data"
                    | Error e -> failwithf "Query failed: %A" e

                    // Commit
                    let commitResult = TwoPhaseCommit.commit coordinator
                    Expect.isOk commitResult "Commit should succeed"

                    // After commit, data is visible
                    match CrossHolonAccess.query uhi "SELECT * FROM holon_state WHERE key = ?" [key] with
                    | Ok rows ->
                        Expect.equal (List.length rows) 1 "Data should be visible after commit"
                    | Error e -> failwithf "Query failed: %A" e
                | Error e -> failwithf "Coordinator failed: %A" e
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D6: Failure Handling Tests
// ============================================================================

[<Tests>]
let d6FailureTests =
    testList "D6: Failure Handling" [
        testCase "D6.1: Timeout handling for slow queries" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Query with short timeout
                let result = CrossHolonAccess.queryWithTimeout uhi "SELECT * FROM holon_state" [] 1

                // Should either succeed quickly or timeout gracefully
                match result with
                | Ok _ -> () // Success
                | Error Timeout -> () // Expected timeout
                | Error e -> failwithf "Unexpected error: %A" e
            finally
                cleanupContext ctx

        testCase "D6.2: Network partition simulation (Zenoh disconnect)" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D6.2"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Simulate partition by disconnecting Zenoh
                ZenohBridge.simulateDisconnect() |> ignore

                // Cross-runtime query should fail
                match ZenohBridge.remoteQuery exUhi exUhi "SELECT 1" [] with
                | Error NetworkPartition -> () // Expected
                | _ -> failwith "Should fail with network partition"

                // Reconnect
                ZenohBridge.reconnect() |> ignore

                // Query should succeed again
                match ZenohBridge.remoteQuery exUhi exUhi "SELECT 1" [] with
                | Ok _ -> () // Success
                | Error e -> failwithf "Should succeed after reconnect: %A" e
            finally
                cleanupContext ctx

        testCase "D6.3: Circuit breaker activation on repeated failures" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D6.3"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Force multiple failures to trigger circuit breaker
                [1..10] |> List.iter (fun _ ->
                    ZenohBridge.remoteExecute exUhi "INVALID SQL SYNTAX!!!" [] |> ignore)

                // Circuit breaker should be open
                let state = ZenohBridge.getCircuitBreakerState exUhi
                Expect.isTrue (state.Status = Open || state.Status = HalfOpen)
                    "Circuit breaker should be open or half-open"

                // Requests should be rejected fast
                let sw = Stopwatch.StartNew()
                match ZenohBridge.remoteQuery exUhi exUhi "SELECT 1" [] with
                | Error CircuitOpen ->
                    Expect.isLessThan sw.ElapsedMilliseconds 10L
                        "Circuit breaker should reject immediately"
                | _ -> failwith "Should be rejected by circuit breaker"
            finally
                cleanupContext ctx

        testCase "D6.4: Graceful degradation on partial system failure" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D6.4"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Simulate Ex holon being unavailable
                ZenohBridge.markUnavailable exUhi |> ignore

                // Local operations should still work
                match CrossHolonAccess.query fsUhi "SELECT 1" [] with
                | Ok _ -> () // Success
                | Error e -> failwithf "Local op should work: %A" e

                // Cross-runtime operations should degrade gracefully
                let fallbackData = [Map.ofList [("val", box 1)]]
                match ZenohBridge.remoteQueryWithFallback exUhi exUhi "SELECT 1" [] (Cached fallbackData) with
                | Ok data ->
                    Expect.equal data fallbackData "Should return fallback data"
                | Error e -> failwithf "Should return fallback: %A" e

                // Mark available again
                ZenohBridge.markAvailable exUhi |> ignore
            finally
                cleanupContext ctx

        testCase "D6.5: Error propagation across runtime boundary" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D6.5"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Trigger error in Elixir holon
                match ZenohBridge.remoteExecute exUhi "INSERT INTO nonexistent_table VALUES (1)" [] with
                | Error (SqlError error) ->
                    Expect.equal error.Origin Elixir "Error should originate from Elixir"
                    Expect.isTrue (error.Message.Contains("table") || error.Message.Contains("nonexistent"))
                        "Error message should mention table issue"
                | _ -> failwith "Should fail with SQL error"
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D7: Performance Tests
// ============================================================================

[<Tests>]
let d7PerformanceTests =
    testList "D7: Performance" [
        testCase "D7.1: Local query latency < 10ms (p99)" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Warmup
                [1..10] |> List.iter (fun _ ->
                    CrossHolonAccess.query uhi "SELECT 1" [] |> ignore)

                // Measure 100 queries
                let latencies = [1..100] |> List.map (fun _ ->
                    let sw = Stopwatch.StartNew()
                    CrossHolonAccess.query uhi "SELECT 1" [] |> ignore
                    sw.Elapsed.TotalMilliseconds)

                let sorted = latencies |> List.sort |> Array.ofList
                let p99 = sorted.[98]

                Expect.isLessThan p99 10.0 (sprintf "p99 latency should be under 10ms, got %.2fms" p99)
            finally
                cleanupContext ctx

        testCase "D7.2: Cross-runtime query latency < 50ms (p99)" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D7.2"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Warmup
                [1..10] |> List.iter (fun _ ->
                    ZenohBridge.remoteQuery exUhi exUhi "SELECT 1" [] |> ignore)

                // Measure 100 queries
                let latencies = [1..100] |> List.map (fun _ ->
                    let sw = Stopwatch.StartNew()
                    ZenohBridge.remoteQuery exUhi exUhi "SELECT 1" [] |> ignore
                    sw.Elapsed.TotalMilliseconds)

                let sorted = latencies |> List.sort |> Array.ofList
                let p99 = sorted.[98]

                Expect.isLessThan p99 50.0 (sprintf "p99 cross-runtime latency should be under 50ms, got %.2fms" p99)
            finally
                cleanupContext ctx

        testCase "D7.3: Throughput > 1000 ops/sec local" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let sw = Stopwatch.StartNew()
                let mutable ops = 0

                while sw.ElapsedMilliseconds < 1000L do
                    CrossHolonAccess.query uhi "SELECT 1" [] |> ignore
                    ops <- ops + 1

                Expect.isGreaterThanOrEqual ops 1000 (sprintf "Should achieve 1000+ ops/sec, got %d" ops)
            finally
                cleanupContext ctx

        testCase "D7.4: Batch operation throughput" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Create batch of 1000 inserts
                let operations = [1..1000] |> List.map (fun i ->
                    (Insert, sprintf "INSERT INTO perf_test (id, data) VALUES (%d, 'data_%d')" i i))

                let sw = Stopwatch.StartNew()
                CrossHolonAccess.executeBatch uhi operations |> ignore
                let elapsed = sw.ElapsedMilliseconds

                let opsPerSec = 1000.0 * 1000.0 / float elapsed
                Expect.isGreaterThanOrEqual opsPerSec 5000.0
                    (sprintf "Batch should achieve 5000+ ops/sec, got %.0f" opsPerSec)
            finally
                cleanupContext ctx

        testCase "D7.5: Memory usage under sustained load" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Record initial memory
                GC.Collect()
                let initialMemory = GC.GetTotalMemory(true)

                // Sustained load for 5 seconds
                let endTime = DateTime.UtcNow.AddSeconds(5.0)
                while DateTime.UtcNow < endTime do
                    CrossHolonAccess.query uhi "SELECT * FROM holon_state LIMIT 100" [] |> ignore

                // Force GC
                GC.Collect()
                let finalMemory = GC.GetTotalMemory(true)
                let growthMB = float (finalMemory - initialMemory) / (1024.0 * 1024.0)

                Expect.isLessThan growthMB 50.0
                    (sprintf "Memory growth should be under 50MB, got %.2fMB" growthMB)
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D8: Security Tests
// ============================================================================

[<Tests>]
let d8SecurityTests =
    testList "D8: Security" [
        testCase "D8.1: SQL injection prevention in queries" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Attempt SQL injection via parameter
                let maliciousInput = "'; DROP TABLE holon_state; --"

                match CrossHolonAccess.query uhi
                    "SELECT * FROM holon_state WHERE key = ?" [maliciousInput] with
                | Ok rows ->
                    Expect.isEmpty rows "Injection escaped, no results"
                | Error e -> failwithf "Query failed: %A" e

                // Table should still exist
                match CrossHolonAccess.query uhi "SELECT COUNT(*) FROM holon_state" [] with
                | Ok _ -> () // Success - table exists
                | Error e -> failwithf "Table should still exist: %A" e
            finally
                cleanupContext ctx

        testCase "D8.2: Path traversal prevention in UHI" <| fun () ->
            let ctx = createTestContext()

            // Attempt path traversal
            let maliciousUhi = sprintf "%s:../../etc/passwd" ctx.FsHolonId

            match CrossHolonAccess.resolvePath maliciousUhi with
            | Error InvalidPath -> () // Expected
            | _ -> failwith "Path traversal should be rejected"

        testCase "D8.3: Cross-holon access requires authorization" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D8.3"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Attempt unauthorized access (no capability token)
                match ZenohBridge.remoteQueryWithToken exUhi exUhi "SELECT * FROM holon_state" [] None with
                | Error Unauthorized -> () // Expected
                | _ -> failwith "Unauthorized access should be rejected"

                // With valid token should succeed
                match CrossHolonAccess.requestCapabilityToken fsUhi exUhi [Read] with
                | Ok token ->
                    match ZenohBridge.remoteQueryWithToken exUhi exUhi "SELECT * FROM holon_state" [] (Some token) with
                    | Ok _ -> () // Success
                    | Error e -> failwithf "Authorized access should succeed: %A" e
                | Error e -> failwithf "Token request failed: %A" e
            finally
                cleanupContext ctx

        testCase "D8.4: Capability token expiration" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D8.4"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Get short-lived token (100ms TTL)
                match CrossHolonAccess.requestCapabilityTokenWithTtl fsUhi exUhi [Read] 100 with
                | Ok token ->
                    // Should work immediately
                    match ZenohBridge.remoteQueryWithToken exUhi exUhi "SELECT 1" [] (Some token) with
                    | Ok _ -> () // Success
                    | Error e -> failwithf "Should work immediately: %A" e

                    // Wait for expiration
                    Thread.Sleep(150)

                    // Should fail after expiration
                    match ZenohBridge.remoteQueryWithToken exUhi exUhi "SELECT 1" [] (Some token) with
                    | Error TokenExpired -> () // Expected
                    | _ -> failwith "Expired token should be rejected"
                | Error e -> failwithf "Token request failed: %A" e
            finally
                cleanupContext ctx

        testCase "D8.5: Audit logging for cross-holon access" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D8.5"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId
                let registerUhi = sprintf "%s:register.duckdb" ctx.FsHolonId

                // Clear audit log
                CrossHolonAccess.execute registerUhi "DELETE FROM access_audit WHERE 1=1" [] |> ignore

                // Perform cross-holon access
                match CrossHolonAccess.requestCapabilityToken ctx.FsHolonId ctx.ExHolonId [Read] with
                | Ok token ->
                    ZenohBridge.remoteQueryWithToken exUhi exUhi "SELECT 1" [] (Some token) |> ignore
                | Error e -> failwithf "Token failed: %A" e

                // Check audit log
                match CrossHolonAccess.query registerUhi
                    "SELECT * FROM access_audit WHERE source_holon = ? AND target_holon = ? ORDER BY timestamp DESC LIMIT 1"
                    [ctx.FsHolonId; ctx.ExHolonId] with
                | Ok rows when List.length rows >= 1 ->
                    let audit = rows.[0]
                    Expect.equal (audit.["operation"]) "read" "Operation should be read"
                    Expect.equal (audit.["target_holon"]) ctx.ExHolonId "Target should match"
                | _ -> failwith "Audit log should have entry"
            finally
                cleanupContext ctx

        testCase "D8.6: Rate limiting on cross-holon requests" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D8.6"

            try
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Make many rapid requests
                let results = [1..100] |> List.map (fun _ ->
                    ZenohBridge.remoteQuery exUhi exUhi "SELECT 1" [])

                let rateLimited = results |> List.filter (function Error RateLimited -> true | _ -> false) |> List.length
                let succeeded = results |> List.filter (function Ok _ -> true | _ -> false) |> List.length

                // Either rate limiting kicks in or all succeed (if under limit)
                Expect.isTrue (rateLimited > 0 || succeeded = 100)
                    "Either rate limiting or all succeed"
            finally
                cleanupContext ctx
    ]

// ============================================================================
// D9: Recovery Tests
// ============================================================================

[<Tests>]
let d9RecoveryTests =
    testList "D9: Recovery" [
        testCase "D9.1: Crash recovery restores last consistent state" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let key = sprintf "recovery_test_%d" (Random().Next())

                // Write data
                CrossHolonAccess.execute uhi
                    "INSERT INTO holon_state (key, value) VALUES (?, 'committed_value')" [key]
                |> ignore

                // Get checksum before "crash"
                let preCrashChecksum = CrossHolonAccess.getDbChecksum uhi

                // Simulate crash
                CrossHolonAccess.simulateCrash uhi |> ignore

                // Recover
                CrossHolonAccess.recover uhi |> ignore

                // Verify data integrity
                let postRecoveryChecksum = CrossHolonAccess.getDbChecksum uhi

                match preCrashChecksum, postRecoveryChecksum with
                | Ok pre, Ok post ->
                    Expect.equal pre post "Checksum should match after recovery"
                | _ -> failwith "Checksum calculation failed"

                match CrossHolonAccess.query uhi "SELECT value FROM holon_state WHERE key = ?" [key] with
                | Ok [row] ->
                    Expect.equal (row.["value"]) "committed_value" "Data should be intact"
                | _ -> failwith "Data verification failed"
            finally
                cleanupContext ctx

        testCase "D9.2: WAL replay after crash" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Enable WAL mode explicitly
                CrossHolonAccess.execute uhi "PRAGMA journal_mode=WAL" [] |> ignore

                // Write several records
                [1..10] |> List.iter (fun i ->
                    CrossHolonAccess.execute uhi
                        "INSERT INTO wal_test (seq) VALUES (?)" [string i] |> ignore)

                // Simulate crash without checkpoint
                CrossHolonAccess.simulateCrashWithoutCheckpoint uhi |> ignore

                // Recover - should replay WAL
                CrossHolonAccess.recover uhi |> ignore

                // All 10 records should be present
                match CrossHolonAccess.query uhi "SELECT COUNT(*) as cnt FROM wal_test" [] with
                | Ok [row] ->
                    Expect.equal (row.["cnt"] :?> int64) 10L "All 10 records should be present"
                | _ -> failwith "Count query failed"
            finally
                cleanupContext ctx

        testCase "D9.3: Checkpoint restore from backup" <| fun () ->
            let ctx = createTestContext()

            try
                let uhi = sprintf "%s:state.sqlite" ctx.FsHolonId

                // Create initial data
                CrossHolonAccess.execute uhi
                    "INSERT INTO holon_state (key, value) VALUES ('ckpt_test', 'original')" []
                |> ignore

                // Create checkpoint
                match CrossHolonAccess.createCheckpoint uhi with
                | Ok checkpointId ->
                    // Modify data
                    CrossHolonAccess.execute uhi
                        "UPDATE holon_state SET value = 'modified' WHERE key = 'ckpt_test'" []
                    |> ignore

                    // Verify modification
                    match CrossHolonAccess.query uhi
                        "SELECT value FROM holon_state WHERE key = 'ckpt_test'" [] with
                    | Ok [row] ->
                        Expect.equal (row.["value"]) "modified" "Should be modified"
                    | _ -> failwith "Verification failed"

                    // Restore from checkpoint
                    CrossHolonAccess.restoreCheckpoint uhi checkpointId |> ignore

                    // Data should be back to original
                    match CrossHolonAccess.query uhi
                        "SELECT value FROM holon_state WHERE key = 'ckpt_test'" [] with
                    | Ok [row] ->
                        Expect.equal (row.["value"]) "original" "Should be restored to original"
                    | _ -> failwith "Restore verification failed"
                | Error e -> failwithf "Checkpoint creation failed: %A" e
            finally
                cleanupContext ctx

        testCase "D9.4: Cross-runtime recovery coordination" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D9.4"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Create coordinated checkpoints
                let fsCkpt = CrossHolonAccess.createCheckpoint fsUhi
                let exCkpt = ZenohBridge.remoteCreateCheckpoint exUhi

                match fsCkpt, exCkpt with
                | Ok fsCkptId, Ok exCkptId ->
                    // Verify checkpoints are correlated
                    let fsMeta = CrossHolonAccess.getCheckpointMetadata fsUhi fsCkptId
                    let exMeta = ZenohBridge.remoteGetCheckpointMetadata exUhi exCkptId

                    match fsMeta, exMeta with
                    | Ok fm, Ok em ->
                        let timeDiff = abs (fm.Timestamp - em.Timestamp)
                        Expect.isLessThan timeDiff 1000L
                            "Coordinated checkpoints should be within 1 second"
                    | _ -> failwith "Metadata fetch failed"
                | _ -> failwith "Checkpoint creation failed"
            finally
                cleanupContext ctx

        testCase "D9.5: Immutable register recovery" <| fun () ->
            let ctx = createTestContext()

            try
                let registerUhi = sprintf "%s:register.duckdb" ctx.FsHolonId

                // Append to register
                let block1 = CrossHolonAccess.appendToRegister registerUhi
                    {| action = "test_action_1"; data = {| key = "value" |} |}

                let block2 = CrossHolonAccess.appendToRegister registerUhi
                    {| action = "test_action_2"; data = {| key = "value2" |} |}

                match block1, block2 with
                | Ok b1, Ok b2 ->
                    // Verify chain integrity
                    match CrossHolonAccess.verifyRegisterChain registerUhi with
                    | Ok chainValid ->
                        Expect.isTrue chainValid "Chain should be valid"
                    | Error e -> failwithf "Chain verification failed: %A" e

                    // Get chain head
                    match CrossHolonAccess.getRegisterHead registerUhi with
                    | Ok head ->
                        Expect.equal head.BlockId b2.BlockId "Head should be last block"
                    | Error e -> failwithf "Get head failed: %A" e

                    // Verify block hashes link correctly
                    match CrossHolonAccess.getRegisterBlock registerUhi b2.BlockId with
                    | Ok b2Data ->
                        Expect.equal b2Data.PrevHash b1.Hash "Block2 should link to Block1"
                    | Error e -> failwithf "Get block failed: %A" e
                | _ -> failwith "Append to register failed"
            finally
                cleanupContext ctx

        testCase "D9.6: Version vector recovery after partition" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "D9.6"

            try
                let fsUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let exUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // Get initial VVs
                let initialFsVv = CrossHolonAccess.getVersionVector fsUhi
                let initialExVv = ZenohBridge.remoteGetVersionVector exUhi

                match initialFsVv, initialExVv with
                | Ok iFsVv, Ok iExVv ->
                    // Simulate partition - both sides update independently
                    let fsVvDuring = CrossHolonAccess.incrementVersion fsUhi ctx.FsHolonId
                    let fsVvDuring2 = CrossHolonAccess.incrementVersion fsUhi ctx.FsHolonId
                    let exVvDuring = ZenohBridge.remoteIncrementVersion exUhi ctx.ExHolonId

                    match fsVvDuring2, exVvDuring with
                    | Ok fvd, Ok evd ->
                        // Resolve partition - merge VVs
                        match ZenohBridge.syncVersionVectors fsUhi exUhi fvd with
                        | Ok mergedVv ->
                            // Merged VV should dominate all previous
                            Expect.isTrue (VersionVector.happensBefore iFsVv mergedVv)
                                "Merged should dominate initial Fs VV"
                            Expect.isTrue (VersionVector.happensBefore iExVv mergedVv)
                                "Merged should dominate initial Ex VV"

                            // Should have entries from both holons
                            Expect.isTrue (Map.containsKey ctx.FsHolonId mergedVv)
                                "Should have Fs entry"
                            Expect.isTrue (Map.containsKey ctx.ExHolonId mergedVv)
                                "Should have Ex entry"
                        | Error e -> failwithf "Sync failed: %A" e
                    | _ -> failwith "Independent updates failed"
                | _ -> failwith "Initial VV fetch failed"
            finally
                cleanupContext ctx
    ]

// ============================================================================
// Full 9-Degree Integration Scenario
// ============================================================================

[<Tests>]
let full9DegreeIntegrationTests =
    testList "Full 9-Degree Integration Scenario" [
        testCase "Complete workflow spanning all 9 degrees" <| fun () ->
            let ctx = createTestContext()
            skipIfNoZenoh ctx "Full 9-Degree"

            try
                let fsStateUhi = sprintf "%s:state.sqlite" ctx.FsHolonId
                let fsAnalyticsUhi = sprintf "%s:analytics.duckdb" ctx.FsHolonId
                let exStateUhi = sprintf "%s:state.sqlite" ctx.ExHolonId

                // D1: Cross-runtime setup
                let token = CrossHolonAccess.requestCapabilityToken ctx.FsHolonId ctx.ExHolonId [Read; Write]
                Expect.isOk token "Token should be obtained"

                // D2: Multi-database type operations
                CrossHolonAccess.execute fsStateUhi
                    "INSERT INTO holon_state (key, value) VALUES ('scenario_key', '100')" []
                |> ignore

                CrossHolonAccess.execute fsAnalyticsUhi
                    "INSERT INTO analytics_events (event_type, data) VALUES ('scenario_event', '{}')" []
                |> ignore

                // D3: Various operations
                let stateRow = CrossHolonAccess.query fsStateUhi
                    "SELECT value FROM holon_state WHERE key = ?" ["scenario_key"]
                Expect.isOk stateRow "Query should succeed"

                // D4: Concurrent access with version vectors
                let vv1 = CrossHolonAccess.incrementVersion fsStateUhi ctx.FsHolonId
                let vv2 = ZenohBridge.remoteIncrementVersion exStateUhi ctx.ExHolonId
                Expect.isOk vv1 "Fs VV increment should succeed"
                Expect.isOk vv2 "Ex VV increment should succeed"

                // D5: Distributed transaction
                match TwoPhaseCommit.startCoordinator ctx.TxId [fsStateUhi; exStateUhi] with
                | Ok coordinator ->
                    TwoPhaseCommit.prepare coordinator fsStateUhi (fun () ->
                        CrossHolonAccess.execute fsStateUhi
                            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'scenario')" [ctx.TxId])
                    |> ignore

                    TwoPhaseCommit.prepare coordinator exStateUhi (fun () ->
                        ZenohBridge.remoteExecute exStateUhi
                            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'scenario')" [ctx.TxId])
                    |> ignore

                    let commitResult = TwoPhaseCommit.commit coordinator
                    Expect.isOk commitResult "2PC should succeed"
                | Error e -> failwithf "Coordinator failed: %A" e

                // D6: Verify circuit breaker is healthy
                let cbState = ZenohBridge.getCircuitBreakerState exStateUhi
                Expect.equal cbState.Status Closed "Circuit breaker should be closed"

                // D7: Performance check
                let sw = Stopwatch.StartNew()
                CrossHolonAccess.query fsStateUhi "SELECT 1" [] |> ignore
                Expect.isLessThan sw.ElapsedMilliseconds 50L "Query should be fast"

                // D8: Security - verify token was required
                match ZenohBridge.remoteQueryWithToken exStateUhi exStateUhi "SELECT 1" [] None with
                | Error Unauthorized -> () // Expected
                | _ -> failwith "Unauthorized should be rejected"

                // D9: Create checkpoint for recovery
                let checkpoint = CrossHolonAccess.createCheckpoint fsStateUhi
                Expect.isOk checkpoint "Checkpoint should succeed"

                // Verify all operations completed
                match CrossHolonAccess.query fsStateUhi
                    "SELECT COUNT(*) as cnt FROM tx_log WHERE tx_id = ?" [ctx.TxId] with
                | Ok [row] ->
                    Expect.isGreaterThanOrEqual (row.["cnt"] :?> int64) 1L "Should have tx log entry"
                | _ -> failwith "Final verification failed"

                // Merge version vectors at the end
                match vv1, vv2 with
                | Ok v1, Ok v2 ->
                    let finalVv = VersionVector.merge v1 v2
                    Expect.isGreaterThanOrEqual (Map.count finalVv) 2 "Both holons represented"
                | _ -> failwith "VV merge verification failed"
            finally
                cleanupContext ctx
    ]

// ============================================================================
// Test Assembly
// ============================================================================

[<EntryPoint>]
let main argv =
    runTestsWithArgs defaultConfig argv <| testList "Cross-Holon Interop 9-Degree Tests" [
        d1CrossRuntimeTests
        d2DatabaseTypeTests
        d3OperationTests
        d4ConcurrencyTests
        d5TransactionTests
        d6FailureTests
        d7PerformanceTests
        d8SecurityTests
        d9RecoveryTests
        full9DegreeIntegrationTests
    ]
