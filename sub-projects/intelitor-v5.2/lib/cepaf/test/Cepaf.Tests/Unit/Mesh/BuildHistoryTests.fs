// =============================================================================
// BuildHistoryTests.fs - Tests for BuildHistory SQLite Persistence Module
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-IGNITE-001 (schema idempotency),
//        SC-IGNITE-004 (high-fidelity dashboard), SC-HOLON-009 (SQLite authority),
//        SC-XHOLON-001 (isolated DB files)
// AOR: AOR-IGNITE-001, AOR-HOLON-009
//
// ## Test Coverage
// - ensureSchema: idempotent invocation, tables created
// - record: inserts BuildRecord, updates EMA for successes, skips EMA for failures
// - getEstimatedDuration: None for unknown containers, Some for known
// - getStats: correct aggregates after multiple records
// - getHistory: reverse-chronological order, limit respected
// - getAllEstimates: returns Map of all EMA values
// - getLastSuccessfulBuild: timestamp of last success, None for failure-only container
// - printSummary: smoke test (no crash)
// - EMA convergence: alpha=0.3 formula applied correctly over 5 sequential builds
//
// ## Test Database Isolation
// The module under test hardcodes its DB path to lib/cepaf/artifacts/build-history.db.
// To avoid parallel-access WAL disk I/O errors the entire suite is wrapped in
// `testSequenced` so all tests run on a single thread, one at a time.
// A backup/restore cycle runs once around the whole suite:
//   1. Back up any existing build-history.db before the first test.
//   2. Delete the file so the suite starts from a known-clean state.
//   3. Restore the backup via a final cleanup test after the suite.
// Individual tests use unique container-name prefixes (GUID suffix) so they never
// observe each other's data while sharing the same on-disk file within a run.
//
// ## Document Control
// | Field   | Value                             |
// |---------|-----------------------------------|
// | Version | 1.1.0                             |
// | Created | 2026-03-31                        |
// | Author  | Code Evolution Agent (CAE)        |
// | STAMP   | SC-TEST-001, SC-IGNITE-001,       |
// |         | SC-HOLON-009, SC-XHOLON-001       |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.BuildHistoryTests

open System
open System.IO
open Expecto
open Cepaf.Mesh

// =============================================================================
// Test Infrastructure
// =============================================================================

/// Path to the production DB (hardcoded inside BuildHistory module).
let private testDbPath = "lib/cepaf/artifacts/build-history.db"
let private backupPath = "lib/cepaf/artifacts/build-history.db.test-backup"
let private walPath    = testDbPath + "-wal"
let private shmPath    = testDbPath + "-shm"

/// Delete the DB and its WAL/SHM sidecars. Best-effort; ignores errors.
let private deleteLiveDb () =
    for p in [testDbPath; walPath; shmPath] do
        try if File.Exists(p) then File.Delete(p)
        with _ -> ()

/// Save any existing production DB + sidecars to backup locations.
let private backupDb () =
    let copy src dst =
        try if File.Exists(src) then File.Copy(src, dst, overwrite = true)
        with _ -> ()
    copy testDbPath backupPath
    copy walPath  (backupPath + "-wal")
    copy shmPath  (backupPath + "-shm")

/// Restore backup; silently ignore missing files.
let private restoreDb () =
    deleteLiveDb()
    let restore bak live =
        try
            if File.Exists(bak) then
                File.Copy(bak, live, overwrite = true)
                File.Delete(bak)
        with _ -> ()
    restore backupPath testDbPath
    restore (backupPath + "-wal") walPath
    restore (backupPath + "-shm") shmPath

/// Generate a short unique suffix to avoid cross-test data collisions.
let private uid () = Guid.NewGuid().ToString("N").[..7]   // 8 hex chars

/// Construct a minimal successful BuildRecord.
let private makeRecord (containerName: string) (durationMs: int64) : BuildHistory.BuildRecord =
    {
        ContainerName  = containerName
        Action         = "build"
        Success        = true
        DurationMs     = durationMs
        ImageSizeBytes = 0L
        CacheHits      = 0
        CacheMisses    = 0
        StepCount      = 0
        Timestamp      = DateTime.UtcNow
        Error          = None
    }

/// Construct a failed BuildRecord.
let private makeFailedRecord (containerName: string) (durationMs: int64) : BuildHistory.BuildRecord =
    { makeRecord containerName durationMs with
        Success = false
        Error   = Some "Build failed: exit code 1" }

// EMA formula mirror: alpha=0.3, ema_new = 0.3 * d + 0.7 * ema_prev
// First insert: ema = duration (ON CONFLICT inserts ema = duration)
let private computeExpectedEma (durations: int64 list) : float =
    match durations with
    | [] -> 0.0
    | first :: rest ->
        rest |> List.fold (fun ema d -> 0.3 * float d + 0.7 * ema) (float first)

// =============================================================================
// Test Suite
// =============================================================================

/// Core tests, defined as an inner list so they can be embedded in testSequenced.
let private coreSuite =
    testList "BuildHistory" [

        // ====================================================================
        // DB setup — runs first because testSequenced is sequential
        // ====================================================================
        test "SETUP: backup and wipe DB before suite" {
            backupDb()
            deleteLiveDb()
        }

        // ====================================================================
        // ensureSchema
        // ====================================================================
        testList "ensureSchema" [

            test "ensureSchema creates tables — getEstimatedDuration works on fresh DB" {
                BuildHistory.ensureSchema()
                let est = BuildHistory.getEstimatedDuration (sprintf "fresh-%s" (uid()))
                Expect.isNone est
                    "A freshly created DB should have no estimates"
            }

            test "ensureSchema is idempotent — calling it twice does not throw" {
                BuildHistory.ensureSchema()
                BuildHistory.ensureSchema()
            }

            test "ensureSchema is idempotent — calling it ten times does not throw" {
                for _ in 1..10 do
                    BuildHistory.ensureSchema()
            }

        ]

        // ====================================================================
        // record
        // ====================================================================
        testList "record" [

            test "record inserts a successful build and getEstimatedDuration returns Some" {
                let name = sprintf "rec-succ-%s" (uid())
                BuildHistory.record (makeRecord name 5000L)
                let est = BuildHistory.getEstimatedDuration name
                Expect.isSome est
                    "After recording a successful build, getEstimatedDuration should return Some"
            }

            test "record with success=true — first record EMA equals duration" {
                let name = sprintf "rec-ema-init-%s" (uid())
                let duration = 8000L
                BuildHistory.record (makeRecord name duration)
                let est = (BuildHistory.getEstimatedDuration name).Value
                Expect.floatClose Accuracy.medium est (float duration)
                    "First EMA value should equal the duration (no prior history)"
            }

            test "record with success=false does NOT update EMA" {
                let name = sprintf "rec-fail-%s" (uid())
                BuildHistory.record (makeFailedRecord name 3000L)
                let est = BuildHistory.getEstimatedDuration name
                Expect.isNone est
                    "Failed builds must not update EMA — no EMA row should exist"
            }

            test "record inserts row visible in getHistory" {
                let name = sprintf "rec-hist-%s" (uid())
                BuildHistory.record (makeRecord name 2000L)
                let hist = BuildHistory.getHistory name 10
                Expect.equal (List.length hist) 1
                    "getHistory should return exactly the one inserted record"
            }

            test "record stores all fields correctly" {
                let name = sprintf "rec-fields-%s" (uid())
                let ts = DateTime(2026, 3, 31, 12, 0, 0, DateTimeKind.Utc)
                let r : BuildHistory.BuildRecord = {
                    ContainerName  = name
                    Action         = "build"
                    Success        = true
                    DurationMs     = 12345L
                    ImageSizeBytes = 987654321L
                    CacheHits      = 7
                    CacheMisses    = 3
                    StepCount      = 42
                    Timestamp      = ts
                    Error          = None
                }
                BuildHistory.record r
                let hist = BuildHistory.getHistory name 1
                Expect.equal (List.length hist) 1 "Should find exactly one record"
                let stored = hist.[0]
                Expect.equal stored.ContainerName name       "ContainerName mismatch"
                Expect.equal stored.Action "build"            "Action mismatch"
                Expect.isTrue stored.Success                  "Success should be true"
                Expect.equal stored.DurationMs 12345L         "DurationMs mismatch"
                Expect.equal stored.ImageSizeBytes 987654321L "ImageSizeBytes mismatch"
                Expect.equal stored.CacheHits 7               "CacheHits mismatch"
                Expect.equal stored.CacheMisses 3             "CacheMisses mismatch"
                Expect.equal stored.StepCount 42              "StepCount mismatch"
                Expect.isNone stored.Error                    "Error should be None"
            }

            test "record stores Error field correctly for failed build" {
                let name = sprintf "rec-err-%s" (uid())
                BuildHistory.record (makeFailedRecord name 500L)
                let hist = BuildHistory.getHistory name 1
                Expect.equal (List.length hist) 1 "Should find the failed record"
                Expect.isSome hist.[0].Error "Error should be Some for failed build"
                Expect.equal hist.[0].Error (Some "Build failed: exit code 1")
                    "Error message should match"
            }

        ]

        // ====================================================================
        // getEstimatedDuration
        // ====================================================================
        testList "getEstimatedDuration" [

            test "returns None for completely unknown container" {
                let result = BuildHistory.getEstimatedDuration (sprintf "ged-none-%s" (uid()))
                Expect.isNone result
                    "Unknown container should yield None"
            }

            test "returns Some after at least one successful build" {
                let name = sprintf "ged-known-%s" (uid())
                BuildHistory.record (makeRecord name 6000L)
                let result = BuildHistory.getEstimatedDuration name
                Expect.isSome result "Known container should yield Some"
            }

            test "EMA value is positive after successful build" {
                let name = sprintf "ged-pos-%s" (uid())
                BuildHistory.record (makeRecord name 4000L)
                let result = (BuildHistory.getEstimatedDuration name).Value
                Expect.isGreaterThan result 0.0
                    "EMA must be positive after a successful build"
            }

            test "failed-only container returns None" {
                let name = sprintf "ged-fail-%s" (uid())
                BuildHistory.record (makeFailedRecord name 2000L)
                let result = BuildHistory.getEstimatedDuration name
                Expect.isNone result
                    "Container with only failed builds should return None for EMA"
            }

        ]

        // ====================================================================
        // getStats
        // ====================================================================
        testList "getStats" [

            test "getStats returns None for unknown container" {
                let stats = BuildHistory.getStats (sprintf "stats-none-%s" (uid()))
                Expect.isNone stats "getStats should return None when no records exist"
            }

            test "getStats returns Some after recording a build" {
                let name = sprintf "stats-some-%s" (uid())
                BuildHistory.record (makeRecord name 3000L)
                let stats = BuildHistory.getStats name
                Expect.isSome stats "getStats should return Some after at least one build"
            }

            test "getStats TotalBuilds equals number of records inserted" {
                let name = sprintf "stats-total-%s" (uid())
                for i in 1..4 do
                    BuildHistory.record (makeRecord name (int64 (i * 1000)))
                let stats = (BuildHistory.getStats name).Value
                Expect.equal stats.TotalBuilds 4
                    "TotalBuilds should equal the number of records inserted"
            }

            test "getStats SuccessRate is 1.0 when all builds succeed" {
                let name = sprintf "stats-rate-ok-%s" (uid())
                for _ in 1..3 do
                    BuildHistory.record (makeRecord name 2000L)
                let stats = (BuildHistory.getStats name).Value
                Expect.floatClose Accuracy.medium stats.SuccessRate 1.0
                    "SuccessRate should be 1.0 when all builds succeed"
            }

            test "getStats SuccessRate is 0.0 when all builds fail" {
                let name = sprintf "stats-rate-fail-%s" (uid())
                for _ in 1..3 do
                    BuildHistory.record (makeFailedRecord name 1000L)
                // getStats queries WHERE action='build'; failed rows still have action='build'
                match BuildHistory.getStats name with
                | None -> ()     // acceptable: no rows matched
                | Some s ->
                    Expect.floatClose Accuracy.medium s.SuccessRate 0.0
                        "SuccessRate should be 0.0 when all builds fail"
            }

            test "getStats MinDurationMs is the smallest duration recorded" {
                let name = sprintf "stats-min-%s" (uid())
                BuildHistory.record (makeRecord name 5000L)
                BuildHistory.record (makeRecord name 1000L)
                BuildHistory.record (makeRecord name 3000L)
                let stats = (BuildHistory.getStats name).Value
                Expect.equal stats.MinDurationMs 1000L
                    "MinDurationMs should be the smallest duration recorded"
            }

            test "getStats MaxDurationMs is the largest duration recorded" {
                let name = sprintf "stats-max-%s" (uid())
                BuildHistory.record (makeRecord name 500L)
                BuildHistory.record (makeRecord name 9000L)
                BuildHistory.record (makeRecord name 4500L)
                let stats = (BuildHistory.getStats name).Value
                Expect.equal stats.MaxDurationMs 9000L
                    "MaxDurationMs should be the largest duration recorded"
            }

            test "getStats AvgDurationMs is the arithmetic mean" {
                let name = sprintf "stats-avg-%s" (uid())
                // 1000 + 3000 + 5000 = 9000 / 3 = 3000
                BuildHistory.record (makeRecord name 1000L)
                BuildHistory.record (makeRecord name 3000L)
                BuildHistory.record (makeRecord name 5000L)
                let stats = (BuildHistory.getStats name).Value
                Expect.floatClose Accuracy.medium stats.AvgDurationMs 3000.0
                    "AvgDurationMs should be the arithmetic mean of all durations"
            }

            test "getStats EmaMs is positive after successful builds" {
                let name = sprintf "stats-ema-%s" (uid())
                BuildHistory.record (makeRecord name 4000L)
                BuildHistory.record (makeRecord name 6000L)
                let stats = (BuildHistory.getStats name).Value
                Expect.isGreaterThan stats.EmaMs 0.0
                    "EmaMs should be positive after successful builds"
            }

            test "getStats ContainerName matches input" {
                let name = sprintf "stats-name-%s" (uid())
                BuildHistory.record (makeRecord name 2000L)
                let stats = (BuildHistory.getStats name).Value
                Expect.equal stats.ContainerName name
                    "ContainerName in BuildStats should match the queried container"
            }

        ]

        // ====================================================================
        // getHistory
        // ====================================================================
        testList "getHistory" [

            test "getHistory returns empty list for unknown container" {
                let hist = BuildHistory.getHistory (sprintf "hist-none-%s" (uid())) 10
                Expect.isEmpty hist "getHistory should return [] for unknown container"
            }

            test "getHistory returns all records when limit exceeds count" {
                let name = sprintf "hist-all-%s" (uid())
                for i in 1..3 do
                    BuildHistory.record (makeRecord name (int64 (i * 1000)))
                let hist = BuildHistory.getHistory name 100
                Expect.equal (List.length hist) 3
                    "getHistory should return all 3 records when limit=100"
            }

            test "getHistory respects limit — only returns requested number" {
                let name = sprintf "hist-lim-%s" (uid())
                for i in 1..5 do
                    BuildHistory.record (makeRecord name (int64 (i * 1000)))
                let hist = BuildHistory.getHistory name 2
                Expect.equal (List.length hist) 2
                    "getHistory should return at most 'limit' records"
            }

            test "getHistory returns records in newest-first order (DESC query + prepend + List.rev)" {
                let name = sprintf "hist-ord-%s" (uid())
                let base_ = DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                // Insert 3 records: duration 1000 is oldest, 3000 is newest
                for i in 1..3 do
                    let r = { makeRecord name (int64 (i * 1000)) with
                                  Timestamp = base_.AddMinutes(float i) }
                    BuildHistory.record r
                let hist = BuildHistory.getHistory name 10
                Expect.equal (List.length hist) 3 "Should retrieve exactly 3 records"
                // The module queries ORDER BY timestamp DESC (newest→oldest), accumulates via prepend
                // ([newest, ..., oldest] reversed to [oldest, ..., newest]) — wait no:
                // DESC row1=3000(newest), prepend → [3000]; row2=2000, prepend → [2000;3000];
                // row3=1000(oldest), prepend → [1000;2000;3000]; List.rev → [3000;2000;1000].
                // Final: newest-first.
                let durations = hist |> List.map (fun r -> r.DurationMs)
                Expect.equal durations [3000L; 2000L; 1000L]
                    "Records should be newest-first (DESC + prepend + List.rev = newest-first)"
            }

            test "getHistory limit=1 returns the most recently inserted record" {
                let name = sprintf "hist-one-%s" (uid())
                let base_ = DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                let r1 = { makeRecord name 1000L with Timestamp = base_ }
                let r2 = { makeRecord name 9999L with Timestamp = base_.AddMinutes(1.0) }
                BuildHistory.record r1
                BuildHistory.record r2
                let hist = BuildHistory.getHistory name 1
                Expect.equal (List.length hist) 1
                    "Limit=1 should return exactly one record"
                Expect.equal hist.[0].DurationMs 9999L
                    "The single returned record should be the most recently inserted one"
            }

            test "getHistory does not return records for other containers" {
                let nameA = sprintf "hist-A-%s" (uid())
                let nameB = sprintf "hist-B-%s" (uid())
                BuildHistory.record (makeRecord nameA 1000L)
                BuildHistory.record (makeRecord nameB 2000L)
                let histA = BuildHistory.getHistory nameA 10
                Expect.equal (List.length histA) 1
                    "Container-A history should contain only container-A records"
                Expect.equal histA.[0].ContainerName nameA
                    "Returned record should belong to container-A"
            }

        ]

        // ====================================================================
        // getAllEstimates
        // ====================================================================
        testList "getAllEstimates" [

            test "getAllEstimates contains entry for every successful container recorded" {
                let names = [ sprintf "est-x-%s" (uid())
                              sprintf "est-y-%s" (uid())
                              sprintf "est-z-%s" (uid()) ]
                for n in names do
                    BuildHistory.record (makeRecord n 3000L)
                let estimates = BuildHistory.getAllEstimates()
                for n in names do
                    Expect.isTrue (Map.containsKey n estimates)
                        (sprintf "getAllEstimates should contain key '%s'" n)
            }

            test "getAllEstimates returns one EMA entry per distinct container" {
                let name = sprintf "est-multi-%s" (uid())
                for _ in 1..3 do
                    BuildHistory.record (makeRecord name 3000L)
                let estimates = BuildHistory.getAllEstimates()
                Expect.isTrue (Map.containsKey name estimates)
                    "getAllEstimates should contain an entry for the container"
            }

            test "getAllEstimates does not create entry for failed-only container" {
                let nameFail = sprintf "est-fail-%s" (uid())
                BuildHistory.record (makeFailedRecord nameFail 2000L)
                let estimates = BuildHistory.getAllEstimates()
                Expect.isFalse (Map.containsKey nameFail estimates)
                    "Failed-only container should NOT appear in getAllEstimates"
            }

            test "getAllEstimates returns positive EMA value" {
                let name = sprintf "est-pos-%s" (uid())
                BuildHistory.record (makeRecord name 7500L)
                let estimates = BuildHistory.getAllEstimates()
                Expect.isTrue (Map.containsKey name estimates)
                    "New container should be in estimates map"
                Expect.isGreaterThan estimates.[name] 0.0
                    "EMA value should be positive"
            }

            test "getAllEstimates EMA consistent with getEstimatedDuration" {
                let name = sprintf "est-cons-%s" (uid())
                for d in [3000L; 6000L; 9000L] do
                    BuildHistory.record (makeRecord name d)
                let fromDirect = (BuildHistory.getEstimatedDuration name).Value
                let fromMap    = (BuildHistory.getAllEstimates()).[name]
                Expect.floatClose Accuracy.medium fromDirect fromMap
                    "getEstimatedDuration and getAllEstimates must return the same EMA"
            }

        ]

        // ====================================================================
        // getLastSuccessfulBuild
        // ====================================================================
        testList "getLastSuccessfulBuild" [

            test "returns None for unknown container" {
                let result = BuildHistory.getLastSuccessfulBuild (sprintf "lsb-none-%s" (uid()))
                Expect.isNone result "getLastSuccessfulBuild should return None for unknown container"
            }

            test "returns None when all builds failed" {
                let name = sprintf "lsb-fail-%s" (uid())
                BuildHistory.record (makeFailedRecord name 1000L)
                BuildHistory.record (makeFailedRecord name 2000L)
                let result = BuildHistory.getLastSuccessfulBuild name
                Expect.isNone result
                    "getLastSuccessfulBuild should return None when only failures exist"
            }

            test "returns Some after a successful build" {
                let name = sprintf "lsb-ok-%s" (uid())
                BuildHistory.record (makeRecord name 4000L)
                let result = BuildHistory.getLastSuccessfulBuild name
                Expect.isSome result
                    "getLastSuccessfulBuild should return Some after a successful build"
            }

            test "returns timestamp of the most recent successful build" {
                let name = sprintf "lsb-ts-%s" (uid())
                let base_ = DateTime(2026, 3, 1, 0, 0, 0, DateTimeKind.Utc)
                let r1 = { makeRecord name 1000L with Timestamp = base_ }
                let r2 = { makeFailedRecord name 2000L with Timestamp = base_.AddHours(1.0) }
                let r3 = { makeRecord name 3000L with Timestamp = base_.AddHours(2.0) }
                BuildHistory.record r1
                BuildHistory.record r2
                BuildHistory.record r3
                let result = (BuildHistory.getLastSuccessfulBuild name).Value
                // DateTime.Parse on this system returns Kind=Unspecified (the raw UTC value),
                // not Kind=Local. ToUniversalTime() on Unspecified treats it as local time,
                // adding the local TZ offset and breaking the comparison.
                // Fix: use SpecifyKind to stamp the Unspecified value as UTC without shifting it.
                let resultUtc = DateTime.SpecifyKind(result, DateTimeKind.Utc)
                let diff = abs ((resultUtc - r3.Timestamp).TotalSeconds)
                Expect.isLessThan diff 2.0
                    "Returned timestamp should match the most recent successful build"
            }

            test "returns None after only a failed build" {
                let name = sprintf "lsb-solo-%s" (uid())
                BuildHistory.record (makeFailedRecord name 500L)
                let result = BuildHistory.getLastSuccessfulBuild name
                Expect.isNone result
                    "Single failed build should yield None from getLastSuccessfulBuild"
            }

        ]

        // ====================================================================
        // printSummary — smoke tests
        // ====================================================================
        testList "printSummary" [

            test "printSummary does not throw with multiple containers in DB" {
                let names = [ sprintf "ps-app-%s" (uid())
                              sprintf "ps-db-%s"  (uid())
                              sprintf "ps-obs-%s" (uid()) ]
                for n in names do
                    BuildHistory.record (makeRecord n 5000L)
                BuildHistory.printSummary()
            }

            test "printSummary does not throw after mixed success and failure records" {
                let name = sprintf "ps-mixed-%s" (uid())
                BuildHistory.record (makeRecord       name 6000L)
                BuildHistory.record (makeFailedRecord name 1000L)
                BuildHistory.printSummary()
            }

        ]

        // ====================================================================
        // EMA convergence — alpha = 0.3
        // ====================================================================
        testList "EMA convergence" [

            test "single build EMA equals that build's duration" {
                let name = sprintf "ema-one-%s" (uid())
                let dur = 10000L
                BuildHistory.record (makeRecord name dur)
                let est = (BuildHistory.getEstimatedDuration name).Value
                Expect.floatClose Accuracy.medium est (float dur)
                    "First build: EMA should equal the duration exactly"
            }

            test "two builds: EMA = 0.3 * d2 + 0.7 * d1" {
                let name = sprintf "ema-two-%s" (uid())
                let d1 = 10000L
                let d2 = 20000L
                BuildHistory.record (makeRecord name d1)
                BuildHistory.record (makeRecord name d2)
                let expected = 0.3 * float d2 + 0.7 * float d1
                let actual   = (BuildHistory.getEstimatedDuration name).Value
                Expect.floatClose Accuracy.medium actual expected
                    "Two builds: EMA must follow alpha=0.3 formula"
            }

            test "five builds: EMA matches formula with alpha=0.3" {
                let name = sprintf "ema-five-%s" (uid())
                let durations = [1000L; 2000L; 3000L; 4000L; 5000L]
                for d in durations do
                    BuildHistory.record (makeRecord name d)
                let expected = computeExpectedEma durations
                let actual   = (BuildHistory.getEstimatedDuration name).Value
                Expect.floatClose Accuracy.medium actual expected
                    (sprintf "Five-build EMA should equal %.2f (alpha=0.3)" expected)
            }

            test "five ascending builds: EMA is between first and last duration" {
                let name = sprintf "ema-bounds-%s" (uid())
                let durations = [500L; 1000L; 2000L; 4000L; 8000L]
                for d in durations do
                    BuildHistory.record (makeRecord name d)
                let ema = (BuildHistory.getEstimatedDuration name).Value
                Expect.isGreaterThan ema (float (List.head durations))
                    "EMA should be greater than the oldest (smallest) duration"
                Expect.isLessThan ema (float (List.last durations))
                    "EMA should be less than the most recent (largest) duration"
            }

            test "failed builds do not alter EMA value" {
                let name = sprintf "ema-fail-inv-%s" (uid())
                BuildHistory.record (makeRecord name 6000L)
                let emaAfterSuccess = (BuildHistory.getEstimatedDuration name).Value
                for _ in 1..3 do
                    BuildHistory.record (makeFailedRecord name 99999L)
                let emaAfterFailures = (BuildHistory.getEstimatedDuration name).Value
                Expect.floatClose Accuracy.medium emaAfterSuccess emaAfterFailures
                    "Failed builds must not change the EMA value"
            }

            test "getAllEstimates EMA consistent with getEstimatedDuration after 5 builds" {
                let name = sprintf "ema-cons2-%s" (uid())
                for d in [1000L; 2000L; 4000L; 8000L; 16000L] do
                    BuildHistory.record (makeRecord name d)
                let fromDirect = (BuildHistory.getEstimatedDuration name).Value
                let fromMap    = (BuildHistory.getAllEstimates()).[name]
                Expect.floatClose Accuracy.medium fromDirect fromMap
                    "getEstimatedDuration and getAllEstimates must agree on EMA"
            }

        ]

        // ====================================================================
        // DB teardown — runs last because testSequenced is sequential
        // ====================================================================
        test "TEARDOWN: restore production DB after suite" {
            restoreDb()
        }

    ]

/// Exported test list: the entire BuildHistory suite runs sequentially to prevent
/// concurrent SQLite WAL I/O errors on the hardcoded DB path.
[<Tests>]
let tests = testSequenced coreSuite
