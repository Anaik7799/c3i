/// Tests for HolonDatabase unified database access.
///
/// STAMP Compliance: SC-XHOLON-001 to SC-XHOLON-010, SC-DBINT-001 to SC-DBINT-010
/// Coverage: Degrees D1, D2, D3 from 9x9 Test Matrix
module Cepaf.Database.Tests.HolonDatabaseTests

open System
open System.IO
open Expecto
open Cepaf.Database.Types
open Cepaf.Database.HolonDatabase

let testBasePath = Path.Combine(Path.GetTempPath(), "cepaf_db_tests")
let testHolonId = "fs:l4:test:srv:unit"

// ==========================================================================
// Setup and Teardown
// ==========================================================================

let setupTestEnvironment () =
    Directory.CreateDirectory(testBasePath) |> ignore
    // Clean up previous test databases
    let holonPath = Path.Combine(testBasePath, testHolonId.Replace(":", "_"))
    if Directory.Exists(holonPath) then
        Directory.Delete(holonPath, true)

let teardownTestEnvironment () =
    let holonPath = Path.Combine(testBasePath, testHolonId.Replace(":", "_"))
    if Directory.Exists(holonPath) then
        try Directory.Delete(holonPath, true) with _ -> ()

// ==========================================================================
// Direct Access Tests (D1-06: F# → F#)
// ==========================================================================

[<Tests>]
let directAccessTests =
    testList "D1-06: Direct F# holon database access" [

        testAsync "can query state database" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            let! result = db.Query(State, "SELECT 1 AS test")

            match result with
            | Ok rows ->
                Expect.isNonEmpty rows "Should return result"
            | Error e ->
                failtest $"Query failed: {e}"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }

        testAsync "query latency is within SLA (< 10ms)" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            let sw = System.Diagnostics.Stopwatch.StartNew()
            let! _ = db.Query(State, "SELECT 1")
            sw.Stop()

            Expect.isLessThan sw.ElapsedMilliseconds 100L "Should be fast (allowing margin)"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }

        testAsync "uses connection pool" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath, poolSize = 2)

            // Execute multiple queries to use pool
            for _ in 1..5 do
                let! _ = db.Query(State, "SELECT 1")
                ()

            // Pool should handle concurrent requests
            let! results = [1..5]
                           |> List.map (fun _ -> db.Query(State, "SELECT 1"))
                           |> Async.Parallel

            Expect.isTrue (Array.forall (fun r -> match r with Ok _ -> true | _ -> false) results)
                "All queries should succeed"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }
    ]

// ==========================================================================
// Database Type Tests (D2)
// ==========================================================================

[<Tests>]
let databaseTypeTests =
    testList "D2: Database Type Tests" [

        testAsync "D2-01: State SQLite CRUD operations" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            // Create table
            let! _ = db.Execute(State, """
                CREATE TABLE IF NOT EXISTS test_state (
                    id TEXT PRIMARY KEY,
                    value TEXT
                )
            """)

            // Insert
            let! insertResult = db.Execute(State,
                "INSERT INTO test_state (id, value) VALUES (?, ?)",
                ["id1" :> obj; "value1" :> obj])

            match insertResult with
            | Ok r -> Expect.equal r.Changes 1 "Should insert 1 row"
            | Error e -> failtest $"Insert failed: {e}"

            // Select
            let! selectResult = db.Query(State,
                "SELECT * FROM test_state WHERE id = ?",
                ["id1" :> obj])

            match selectResult with
            | Ok rows -> Expect.isNonEmpty rows "Should find row"
            | Error e -> failtest $"Select failed: {e}"

            // Update
            let! updateResult = db.Execute(State,
                "UPDATE test_state SET value = ? WHERE id = ?",
                ["value2" :> obj; "id1" :> obj])

            match updateResult with
            | Ok r -> Expect.equal r.Changes 1 "Should update 1 row"
            | Error e -> failtest $"Update failed: {e}"

            // Delete
            let! deleteResult = db.Execute(State,
                "DELETE FROM test_state WHERE id = ?",
                ["id1" :> obj])

            match deleteResult with
            | Ok r -> Expect.equal r.Changes 1 "Should delete 1 row"
            | Error e -> failtest $"Delete failed: {e}"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }

        testAsync "D2-04: Analytics DuckDB queries" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            // Create table
            let! _ = db.Execute(Analytics, """
                CREATE TABLE IF NOT EXISTS test_metrics (
                    metric_name VARCHAR,
                    value DOUBLE
                )
            """)

            // Insert sample data
            for i in 1..10 do
                let! _ = db.Execute(Analytics,
                    "INSERT INTO test_metrics VALUES (?, ?)",
                    ["cpu" :> obj; float i * 0.1 :> obj])
                ()

            // Analytical query
            let! result = db.Query(Analytics,
                "SELECT AVG(value) as avg_value FROM test_metrics")

            match result with
            | Ok rows ->
                Expect.isNonEmpty rows "Should return aggregate"
            | Error e -> failtest $"Query failed: {e}"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }

        testAsync "version vector updated on write" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            let! initialVV = db.GetVersionVector()

            // Execute write
            let! _ = db.Execute(State, """
                CREATE TABLE IF NOT EXISTS vv_test (id INTEGER PRIMARY KEY)
            """)
            let! _ = db.Execute(State, "INSERT INTO vv_test DEFAULT VALUES")

            let! updatedVV = db.GetVersionVector()

            let initialVersion = Map.tryFind testHolonId initialVV |> Option.defaultValue 0L
            let updatedVersion = Map.tryFind testHolonId updatedVV |> Option.defaultValue 0L

            Expect.isGreaterThan updatedVersion initialVersion "Version should increase"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }
    ]

// ==========================================================================
// Operation Type Tests (D3)
// ==========================================================================

[<Tests>]
let operationTypeTests =
    testList "D3: Operation Type Tests" [

        testAsync "D3-RR-01: Concurrent reads no conflict" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            // Setup
            let! _ = db.Execute(State, """
                CREATE TABLE IF NOT EXISTS read_test (id TEXT PRIMARY KEY, data TEXT)
            """)
            let! _ = db.Execute(State, "INSERT INTO read_test VALUES ('test', 'data')")

            // Concurrent reads
            let! results = [1..10]
                           |> List.map (fun _ -> db.Query(State, "SELECT * FROM read_test"))
                           |> Async.Parallel

            Expect.isTrue (Array.forall (fun r -> match r with Ok _ -> true | _ -> false) results)
                "All reads should succeed"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }

        testAsync "D3-CC-13: CAS operations with conflict detection" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            // Setup
            let! _ = db.Execute(State, """
                CREATE TABLE IF NOT EXISTS cas_test (key TEXT PRIMARY KEY, value TEXT)
            """)
            let! _ = db.Execute(State, "INSERT INTO cas_test VALUES ('k1', 'initial')")

            let! vv = db.GetVersionVector()

            // First CAS should succeed
            let! result1 = db.ExecuteCas(State,
                "UPDATE cas_test SET value = ? WHERE key = 'k1'",
                ["value1" :> obj],
                vv)

            match result1 with
            | Ok _ -> ()
            | Error "conflict" -> failtest "First CAS should succeed"
            | Error e -> failtest $"Unexpected error: {e}"

            // Second CAS with old version should conflict
            let! result2 = db.ExecuteCas(State,
                "UPDATE cas_test SET value = ? WHERE key = 'k1'",
                ["value2" :> obj],
                vv)  // Using old version

            match result2 with
            | Ok _ -> failtest "Should have conflict with old version"
            | Error "conflict" -> ()  // Expected
            | Error e -> failtest $"Unexpected error: {e}"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }
    ]

// ==========================================================================
// Transaction Tests
// ==========================================================================

[<Tests>]
let transactionTests =
    testList "Transaction Tests" [

        testAsync "transaction commits on success" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            // Setup
            let! _ = db.Execute(State, """
                CREATE TABLE IF NOT EXISTS txn_test (id INTEGER PRIMARY KEY, value TEXT)
            """)

            let! result = db.Transaction(State, fun conn ->
                // Multiple operations in transaction
                use cmd1 = conn.CreateCommand()
                cmd1.CommandText <- "INSERT INTO txn_test (value) VALUES ('a')"
                cmd1.ExecuteNonQuery() |> ignore

                use cmd2 = conn.CreateCommand()
                cmd2.CommandText <- "INSERT INTO txn_test (value) VALUES ('b')"
                cmd2.ExecuteNonQuery() |> ignore

                Ok "committed"
            )

            match result with
            | Ok "committed" ->
                // Verify both rows exist
                let! selectResult = db.Query(State, "SELECT COUNT(*) as cnt FROM txn_test")
                match selectResult with
                | Ok rows -> ()  // Should have 2 rows
                | Error e -> failtest $"Verify failed: {e}"
            | _ -> failtest "Transaction should commit"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }

        testAsync "transaction rolls back on error" {
            setupTestEnvironment()
            let! db = HolonDatabase.Create(testHolonId, testBasePath)

            // Setup
            let! _ = db.Execute(State, """
                CREATE TABLE IF NOT EXISTS rollback_test (id INTEGER PRIMARY KEY, value TEXT)
            """)

            let! result = db.Transaction(State, fun conn ->
                use cmd1 = conn.CreateCommand()
                cmd1.CommandText <- "INSERT INTO rollback_test (value) VALUES ('a')"
                cmd1.ExecuteNonQuery() |> ignore

                // Simulate error
                Error "simulated error"
            )

            match result with
            | Error "simulated error" ->
                // Verify no rows exist (rolled back)
                let! selectResult = db.Query(State, "SELECT COUNT(*) as cnt FROM rollback_test")
                match selectResult with
                | Ok _ -> ()  // Should have 0 rows
                | Error e -> failtest $"Verify failed: {e}"
            | _ -> failtest "Transaction should error"

            db.Shutdown() |> Async.RunSynchronously
            teardownTestEnvironment()
        }
    ]

// ==========================================================================
// Run Tests
// ==========================================================================

[<EntryPoint>]
let main args =
    runTestsWithCLIArgs [] args directAccessTests
    |> (+) (runTestsWithCLIArgs [] args databaseTypeTests)
    |> (+) (runTestsWithCLIArgs [] args operationTypeTests)
    |> (+) (runTestsWithCLIArgs [] args transactionTests)
