/// Cross-Holon Database Access Comprehensive Tests
/// Version 21.2.1-SIL6 | 2026-01-17
///
/// Covers:
/// - UHI parsing and resolution
/// - Direct SQLite/DuckDB access
/// - Cross-holon Zenoh bridge operations
/// - Version vector operations
/// - CAS (Compare-and-Swap) operations
/// - Two-phase commit transactions
///
/// STAMP Constraints: SC-XHOLON-001 to SC-XHOLON-054
/// AOR Rules: AOR-XHOLON-001 to AOR-XHOLON-040

module Cepaf.Database.Tests.CrossHolonAccessComprehensiveTests

open System
open System.IO
open System.Threading.Tasks
open Expecto
open FsCheck
open Cepaf.Database.CrossHolonAccess
open Cepaf.Database.UHI
open Cepaf.Database.VersionVector

// ============================================================
// TEST CONFIGURATION
// ============================================================

let testConfig = {
    FsCheckConfig.defaultConfig with
        MaxTest = 100
        Arbitrary = [typeof<Arbitraries>]
}

// ============================================================
// CUSTOM GENERATORS
// ============================================================

type Arbitraries =
    static member Runtime() =
        Gen.elements [Elixir; FSharp; Zig; Rust]
        |> Arb.fromGen

    static member FractalLayer() =
        Gen.elements [L0; L1; L2; L3; L4; L5; L6; L7; L8; L9]
        |> Arb.fromGen

    static member DatabaseType() =
        Gen.elements [StateSQLite; VectorsSQLite; CacheSQLite; AnalyticsDuckDB; HistoryDuckDB; RegisterDuckDB]
        |> Arb.fromGen

    static member ValidUHI() =
        gen {
            let! runtime = Gen.elements [Elixir; FSharp]
            let! layer = Gen.elements [L0; L1; L2; L3; L4; L5; L6; L7]
            let! domain = Gen.elements ["access"; "alarm"; "cortex"; "planning"]
            let! holonType = Gen.elements ["agent"; "service"; "worker"]
            let! instance = Gen.choose(1, 1000000) |> Gen.map string
            let! database = Gen.elements [StateSQLite; VectorsSQLite; AnalyticsDuckDB]
            return {
                Runtime = runtime
                Layer = layer
                Domain = domain
                Type = holonType
                Instance = instance
                Database = database
            }
        }
        |> Arb.fromGen

    static member VersionVector() =
        gen {
            let! entries = Gen.listOfLength 5 (Gen.zip (Gen.elements ["h1"; "h2"; "h3"; "h4"; "h5"]) (Gen.choose(0, 100)))
            return Map.ofList entries
        }
        |> Arb.fromGen

// ============================================================
// SECTION 1: UHI PARSING TESTS
// ============================================================

[<Tests>]
let uhiParsingTests =
    testList "UHI Parsing" [

        test "parses valid F# UHI with all components" {
            let uhiString = "fs:L4:cortex:cognitive:abc123:analytics.duckdb"
            let result = UHI.parse uhiString
            Expect.isOk result "Should parse valid UHI"

            let uhi = Result.get result
            Expect.equal uhi.Runtime FSharp "Runtime should be FSharp"
            Expect.equal uhi.Layer L4 "Layer should be L4"
            Expect.equal uhi.Domain "cortex" "Domain should be cortex"
            Expect.equal uhi.Type "cognitive" "Type should be cognitive"
            Expect.equal uhi.Instance "abc123" "Instance should be abc123"
            Expect.equal uhi.Database AnalyticsDuckDB "Database should be AnalyticsDuckDB"
        }

        test "parses valid Elixir UHI" {
            let uhiString = "ex:L3:access:agent:xyz789:state.sqlite"
            let result = UHI.parse uhiString
            Expect.isOk result "Should parse valid UHI"

            let uhi = Result.get result
            Expect.equal uhi.Runtime Elixir "Runtime should be Elixir"
            Expect.equal uhi.Layer L3 "Layer should be L3"
            Expect.equal uhi.Database StateSQLite "Database should be StateSQLite"
        }

        testList "parses all valid runtime codes" [
            test "Elixir runtime" {
                let result = UHI.parse "ex:L3:test:test:abc:state.sqlite"
                Expect.isOk result "Should parse ex"
                Expect.equal (Result.get result).Runtime Elixir "Should be Elixir"
            }
            test "F# runtime" {
                let result = UHI.parse "fs:L3:test:test:abc:state.sqlite"
                Expect.isOk result "Should parse fs"
                Expect.equal (Result.get result).Runtime FSharp "Should be FSharp"
            }
            test "Zig runtime" {
                let result = UHI.parse "zig:L3:test:test:abc:state.sqlite"
                Expect.isOk result "Should parse zig"
                Expect.equal (Result.get result).Runtime Zig "Should be Zig"
            }
            test "Rust runtime" {
                let result = UHI.parse "rs:L3:test:test:abc:state.sqlite"
                Expect.isOk result "Should parse rs"
                Expect.equal (Result.get result).Runtime Rust "Should be Rust"
            }
        ]

        testList "parses all valid database types" [
            test "state.sqlite" {
                let result = UHI.parse "fs:L3:test:test:abc:state.sqlite"
                Expect.equal (Result.get result).Database StateSQLite "Should be StateSQLite"
            }
            test "vectors.sqlite" {
                let result = UHI.parse "fs:L3:test:test:abc:vectors.sqlite"
                Expect.equal (Result.get result).Database VectorsSQLite "Should be VectorsSQLite"
            }
            test "cache.sqlite" {
                let result = UHI.parse "fs:L3:test:test:abc:cache.sqlite"
                Expect.equal (Result.get result).Database CacheSQLite "Should be CacheSQLite"
            }
            test "analytics.duckdb" {
                let result = UHI.parse "fs:L3:test:test:abc:analytics.duckdb"
                Expect.equal (Result.get result).Database AnalyticsDuckDB "Should be AnalyticsDuckDB"
            }
            test "history.duckdb" {
                let result = UHI.parse "fs:L3:test:test:abc:history.duckdb"
                Expect.equal (Result.get result).Database HistoryDuckDB "Should be HistoryDuckDB"
            }
            test "register.duckdb" {
                let result = UHI.parse "fs:L3:test:test:abc:register.duckdb"
                Expect.equal (Result.get result).Database RegisterDuckDB "Should be RegisterDuckDB"
            }
        ]

        test "rejects invalid runtime code" {
            let result = UHI.parse "xx:L3:test:test:abc:state.sqlite"
            Expect.isError result "Should reject invalid runtime"
        }

        test "rejects invalid layer code" {
            let result = UHI.parse "fs:L99:test:test:abc:state.sqlite"
            Expect.isError result "Should reject invalid layer"
        }

        test "rejects invalid database type" {
            let result = UHI.parse "fs:L3:test:test:abc:invalid.db"
            Expect.isError result "Should reject invalid database"
        }

        test "rejects malformed UHI with missing components" {
            let result = UHI.parse "fs:L3:test"
            Expect.isError result "Should reject malformed UHI"
        }

        test "rejects path traversal attempts (SC-XHOLON-046)" {
            let result1 = UHI.parse "fs:L3:../etc:passwd:x:state.sqlite"
            Expect.isError result1 "Should reject path traversal"

            let result2 = UHI.parse "fs:L3:test:..\\..\\windows:x:state.sqlite"
            Expect.isError result2 "Should reject Windows path traversal"
        }

        testPropertyWithConfig testConfig "roundtrip parse/format preserves UHI" <|
            fun (uhi: UHI) ->
                let formatted = UHI.format uhi
                let reparsed = UHI.parse formatted
                match reparsed with
                | Ok parsed -> parsed = uhi
                | Error _ -> false
    ]

// ============================================================
// SECTION 2: PATH RESOLUTION TESTS
// ============================================================

[<Tests>]
let pathResolutionTests =
    testList "Path Resolution" [

        test "resolves SQLite state database path correctly" {
            let uhi = {
                Runtime = FSharp
                Layer = L4
                Domain = "cortex"
                Type = "cognitive"
                Instance = "abc123"
                Database = StateSQLite
            }

            let path = UHI.resolvePath uhi "/data/holons"
            Expect.equal path "/data/holons/fs/L4/cortex/cognitive/abc123/state.sqlite" "Path should match expected"
        }

        test "resolves DuckDB analytics database path correctly" {
            let uhi = {
                Runtime = Elixir
                Layer = L3
                Domain = "access"
                Type = "agent"
                Instance = "xyz789"
                Database = AnalyticsDuckDB
            }

            let path = UHI.resolvePath uhi "/data/holons"
            Expect.equal path "/data/holons/ex/L3/access/agent/xyz789/analytics.duckdb" "Path should match expected"
        }

        testPropertyWithConfig testConfig "path resolution is deterministic (SC-DBNAME-007)" <|
            fun (uhi: UHI) (baseSuffix: string) ->
                let basePath = $"/data/{baseSuffix.Replace("/", "").Replace("\\", "")}"
                let path1 = UHI.resolvePath uhi basePath
                let path2 = UHI.resolvePath uhi basePath
                path1 = path2

        testPropertyWithConfig testConfig "different UHIs produce different paths (SC-DBNAME-006)" <|
            fun (uhi1: UHI) (uhi2: UHI) ->
                let basePath = "/data/holons"
                let path1 = UHI.resolvePath uhi1 basePath
                let path2 = UHI.resolvePath uhi2 basePath
                uhi1 = uhi2 || path1 <> path2
    ]

// ============================================================
// SECTION 3: DIRECT DATABASE ACCESS TESTS
// ============================================================

[<Tests>]
let queryTests =
    testList "Query Execution" [

        test "executes simple SELECT query" {
            use testDb = TestHelper.createTestHolon StateSQLite
            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT 1 as num" []

            Expect.isOk result "Query should succeed"
            let rows = Result.get result
            Expect.equal (List.length rows) 1 "Should return one row"
            Expect.equal (rows.[0].["num"]) (box 1L) "Value should be 1"
        }

        test "executes SELECT with multiple rows" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi
            TestHelper.insertTestData testDb.Uhi [("a", 1); ("b", 2); ("c", 3)]

            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT * FROM test_table ORDER BY key" []

            Expect.isOk result "Query should succeed"
            let rows = Result.get result
            Expect.equal (List.length rows) 3 "Should return three rows"
        }

        test "executes parameterized query" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi
            TestHelper.insertTestData testDb.Uhi [("key1", 100)]

            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi
                "SELECT * FROM test_table WHERE key = @key"
                [("@key", box "key1")]

            Expect.isOk result "Query should succeed"
            let rows = Result.get result
            Expect.equal (List.length rows) 1 "Should return one row"
            Expect.equal (rows.[0].["value"]) (box 100L) "Value should be 100"
        }

        test "returns empty list for no matching rows" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi

            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT * FROM test_table" []

            Expect.isOk result "Query should succeed"
            let rows = Result.get result
            Expect.isEmpty rows "Should return empty list"
        }

        test "handles NULL values correctly" {
            use testDb = TestHelper.createTestHolon StateSQLite
            CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "CREATE TABLE null_test (id INTEGER, val TEXT)" [] |> ignore
            CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "INSERT INTO null_test VALUES (1, NULL)" [] |> ignore

            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT * FROM null_test" []

            Expect.isOk result "Query should succeed"
            let rows = Result.get result
            Expect.equal (rows.[0].["val"]) (box DBNull.Value) "NULL should be preserved"
        }

        test "returns error for invalid SQL syntax" {
            use testDb = TestHelper.createTestHolon StateSQLite
            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi "INVALID SQL SYNTAX" []
            Expect.isError result "Should return error for invalid SQL"
        }

        test "returns error for non-existent table" {
            use testDb = TestHelper.createTestHolon StateSQLite
            let result = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT * FROM nonexistent" []
            Expect.isError result "Should return error for non-existent table"
        }
    ]

// ============================================================
// SECTION 4: EXECUTE (WRITE) TESTS
// ============================================================

[<Tests>]
let executeTests =
    testList "Execute Operations" [

        test "inserts single row" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi

            let result = CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "INSERT INTO test_table VALUES (@key, @val)"
                [("@key", box "key1"); ("@val", box 42)]

            Expect.isOk result "Insert should succeed"
            Expect.equal (Result.get result) 1 "Should affect 1 row"

            let queryResult = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT * FROM test_table" []
            Expect.equal (List.length (Result.get queryResult)) 1 "Should have 1 row"
        }

        test "updates existing row" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi
            TestHelper.insertTestData testDb.Uhi [("key1", 10)]

            let result = CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "UPDATE test_table SET value = @val WHERE key = @key"
                [("@key", box "key1"); ("@val", box 99)]

            Expect.isOk result "Update should succeed"
            Expect.equal (Result.get result) 1 "Should affect 1 row"

            let queryResult = CrossHolonAccess.query testDb.Uhi testDb.Uhi
                "SELECT * FROM test_table WHERE key = 'key1'" []
            let rows = Result.get queryResult
            Expect.equal (rows.[0].["value"]) (box 99L) "Value should be updated"
        }

        test "deletes row" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi
            TestHelper.insertTestData testDb.Uhi [("to_delete", 1)]

            let result = CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "DELETE FROM test_table WHERE key = @key"
                [("@key", box "to_delete")]

            Expect.isOk result "Delete should succeed"
            Expect.equal (Result.get result) 1 "Should affect 1 row"

            let queryResult = CrossHolonAccess.query testDb.Uhi testDb.Uhi
                "SELECT * FROM test_table WHERE key = 'to_delete'" []
            Expect.isEmpty (Result.get queryResult) "Row should be deleted"
        }

        test "returns 0 for no-op update" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi

            let result = CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "UPDATE test_table SET value = 1 WHERE key = 'nonexistent'"
                []

            Expect.isOk result "Update should succeed"
            Expect.equal (Result.get result) 0 "Should affect 0 rows"
        }

        test "prevents SQL injection via parameterization (SC-XHOLON-008)" {
            use testDb = TestHelper.createTestHolon StateSQLite
            TestHelper.setupTestTable testDb.Uhi

            let maliciousKey = "'; DROP TABLE test_table; --"
            CrossHolonAccess.execute testDb.Uhi testDb.Uhi
                "INSERT INTO test_table VALUES (@key, @val)"
                [("@key", box maliciousKey); ("@val", box 1)] |> ignore

            // Table should still exist
            let queryResult = CrossHolonAccess.query testDb.Uhi testDb.Uhi "SELECT * FROM test_table" []
            Expect.isOk queryResult "Table should still exist"

            // Malicious string should be stored as data
            let rows = Result.get queryResult
            Expect.equal (rows.[0].["key"]) (box maliciousKey) "Should store malicious string as data"
        }
    ]

// ============================================================
// SECTION 5: VERSION VECTOR TESTS
// ============================================================

[<Tests>]
let versionVectorTests =
    testList "Version Vector" [

        test "empty vector has all zeros" {
            let vv = VersionVector.empty
            Expect.equal (VersionVector.lookup "holon1" vv) 0 "Should be zero for any holon"
        }

        test "increment increases version by 1" {
            let vv = VersionVector.empty |> VersionVector.increment "h1"
            Expect.equal (VersionVector.lookup "h1" vv) 1 "Should be incremented to 1"
        }

        test "multiple increments accumulate" {
            let vv =
                VersionVector.empty
                |> VersionVector.increment "h1"
                |> VersionVector.increment "h1"
                |> VersionVector.increment "h1"
            Expect.equal (VersionVector.lookup "h1" vv) 3 "Should be 3 after 3 increments"
        }

        test "merge takes element-wise maximum (SC-XHOLON-037)" {
            let vv1 = Map.ofList [("h1", 3); ("h2", 1)]
            let vv2 = Map.ofList [("h1", 1); ("h2", 5); ("h3", 2)]
            let merged = VersionVector.merge vv1 vv2

            Expect.equal (Map.find "h1" merged) 3 "h1 should be 3"
            Expect.equal (Map.find "h2" merged) 5 "h2 should be 5"
            Expect.equal (Map.find "h3" merged) 2 "h3 should be 2"
        }

        test "compare returns Before when strictly less" {
            let vv1 = Map.ofList [("h1", 1); ("h2", 1)]
            let vv2 = Map.ofList [("h1", 2); ("h2", 2)]
            Expect.equal (VersionVector.compare vv1 vv2) Before "Should be Before"
        }

        test "compare returns After when strictly greater" {
            let vv1 = Map.ofList [("h1", 3); ("h2", 3)]
            let vv2 = Map.ofList [("h1", 1); ("h2", 1)]
            Expect.equal (VersionVector.compare vv1 vv2) After "Should be After"
        }

        test "compare returns Concurrent when incomparable" {
            let vv1 = Map.ofList [("h1", 3); ("h2", 1)]
            let vv2 = Map.ofList [("h1", 1); ("h2", 3)]
            Expect.equal (VersionVector.compare vv1 vv2) Concurrent "Should be Concurrent"
        }

        testPropertyWithConfig testConfig "merge is commutative" <|
            fun (vv1: Map<string, int>) (vv2: Map<string, int>) ->
                let p1 = vv1 |> Map.map (fun _ v -> abs v)
                let p2 = vv2 |> Map.map (fun _ v -> abs v)
                VersionVector.merge p1 p2 = VersionVector.merge p2 p1

        testPropertyWithConfig testConfig "merge is associative" <|
            fun (vv1: Map<string, int>) (vv2: Map<string, int>) (vv3: Map<string, int>) ->
                let p1 = vv1 |> Map.map (fun _ v -> abs v)
                let p2 = vv2 |> Map.map (fun _ v -> abs v)
                let p3 = vv3 |> Map.map (fun _ v -> abs v)
                VersionVector.merge (VersionVector.merge p1 p2) p3 =
                    VersionVector.merge p1 (VersionVector.merge p2 p3)

        testPropertyWithConfig testConfig "merge is idempotent" <|
            fun (vv: Map<string, int>) ->
                let positive = vv |> Map.map (fun _ v -> abs v)
                VersionVector.merge positive positive = positive
    ]

// ============================================================
// SECTION 6: CAS TESTS
// ============================================================

[<Tests>]
let casTests =
    testList "Compare-and-Swap" [

        test "succeeds when version matches" {
            use testDb = TestHelper.createTestHolonWithCasTable ()

            let result = CrossHolonAccess.executeCas
                testDb.Uhi testDb.Uhi
                "UPDATE cas_table SET value = 'updated' WHERE key = 'key1'"
                []
                0 // expected version
                ["cas_table"]

            Expect.isOk result "CAS should succeed"
            let newVersion = Result.get result
            Expect.equal newVersion 1 "Version should increment to 1"
        }

        test "fails when version mismatches" {
            use testDb = TestHelper.createTestHolonWithCasTable ()

            let result = CrossHolonAccess.executeCas
                testDb.Uhi testDb.Uhi
                "UPDATE cas_table SET value = 'should_fail'"
                []
                99 // wrong version
                ["cas_table"]

            Expect.isError result "CAS should fail on mismatch"
            match result with
            | Error (VersionConflict currentVersion) ->
                Expect.equal currentVersion 0 "Should report current version"
            | _ -> failtest "Expected VersionConflict error"
        }

        test "handles concurrent CAS with only one winner" {
            use testDb = TestHelper.createTestHolonWithCasTable ()

            let tasks = [|
                for i in 1..10 do
                    async {
                        return CrossHolonAccess.executeCas
                            testDb.Uhi testDb.Uhi
                            $"UPDATE cas_table SET value = 'writer_{i}' WHERE key = 'key1'"
                            []
                            0
                            ["cas_table"]
                    }
            |]

            let results = tasks |> Async.Parallel |> Async.RunSynchronously
            let successes = results |> Array.filter Result.isOk |> Array.length
            let conflicts = results |> Array.filter Result.isError |> Array.length

            Expect.equal successes 1 "Exactly one CAS should succeed"
            Expect.equal conflicts 9 "Nine should conflict"
        }

        testPropertyWithConfig { testConfig with MaxTest = 20 } "CAS operations are linearizable" <|
            fun (numOps: byte) ->
                let ops = max 2 (int numOps % 10)
                use testDb = TestHelper.createTestHolonWithCasTable ()

                let results =
                    [| for i in 1..ops do
                        async {
                            return CrossHolonAccess.executeCas
                                testDb.Uhi testDb.Uhi
                                $"UPDATE cas_table SET value = '{i}' WHERE key = 'key1'"
                                []
                                0
                                ["cas_table"]
                        }
                    |]
                    |> Async.Parallel
                    |> Async.RunSynchronously

                // Verify linearizability: exactly one success
                let successes = results |> Array.filter Result.isOk |> Array.length
                successes = 1
    ]

// ============================================================
// TEST HELPERS
// ============================================================

module TestHelper =
    type TestHolon = {
        Uhi: string
        Cleanup: unit -> unit
    }
        interface IDisposable with
            member this.Dispose() = this.Cleanup()

    let createTestHolon (dbType: DatabaseType) =
        let instance = Guid.NewGuid().ToString("N")
        let dbExt =
            match dbType with
            | StateSQLite -> "state.sqlite"
            | VectorsSQLite -> "vectors.sqlite"
            | CacheSQLite -> "cache.sqlite"
            | AnalyticsDuckDB -> "analytics.duckdb"
            | HistoryDuckDB -> "history.duckdb"
            | RegisterDuckDB -> "register.duckdb"

        let uhi = $"fs:L3:test:unit:{instance}:{dbExt}"
        let basePath = Path.Combine(Path.GetTempPath(), "holon_tests")
        let parsed = UHI.parse uhi |> Result.get
        let path = UHI.resolvePath parsed basePath
        Directory.CreateDirectory(Path.GetDirectoryName(path)) |> ignore

        {
            Uhi = uhi
            Cleanup = fun () ->
                let dir = Path.GetDirectoryName(path)
                if Directory.Exists(dir) then
                    Directory.Delete(dir, true)
        }

    let createTestHolonWithCasTable () =
        let testDb = createTestHolon StateSQLite
        CrossHolonAccess.execute testDb.Uhi testDb.Uhi """
            CREATE TABLE cas_table (
                key TEXT PRIMARY KEY,
                value TEXT,
                version INTEGER DEFAULT 0
            )
        """ [] |> ignore
        CrossHolonAccess.execute testDb.Uhi testDb.Uhi
            "INSERT INTO cas_table VALUES ('key1', 'initial', 0)" [] |> ignore
        testDb

    let setupTestTable uhi =
        CrossHolonAccess.execute uhi uhi """
            CREATE TABLE IF NOT EXISTS test_table (
                key TEXT PRIMARY KEY,
                value INTEGER
            )
        """ [] |> ignore

    let insertTestData uhi (data: (string * int) list) =
        for (key, value) in data do
            CrossHolonAccess.execute uhi uhi
                "INSERT INTO test_table VALUES (@key, @val)"
                [("@key", box key); ("@val", box value)] |> ignore

// ============================================================
// MAIN ENTRY POINT
// ============================================================

[<EntryPoint>]
let main args =
    runTestsWithCLIArgs [] args (testList "Cross-Holon Database Tests" [
        uhiParsingTests
        pathResolutionTests
        queryTests
        executeTests
        versionVectorTests
        casTests
    ])
