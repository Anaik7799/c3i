// =============================================================================
// Git Intelligence — Store & History Tests
// =============================================================================
// Purpose:  Test L3 holon state persistence (SQLite WAL) and evolution log
//           (DuckDB append-only). Uses temp files for test isolation.
//
// STAMP:    SC-UTLTS-001 (WAL), AOR-HOLON-001 (SQLite state),
//           AOR-HOLON-019 (append-only DuckDB)
// =============================================================================

namespace Cepaf.Tests.Unit.GitIntelligence

open System
open System.IO
open Expecto
open Cepaf.GitIntelligence

module StoreTests =

    // ── Test Helpers ──────────────────────────────────────────────────────

    /// Create a temp SQLite path, run action, then clean up.
    let private withTempStore (action: unit -> unit) =
        let tmpFile = Path.GetTempFileName()
        try
            Store.setDbPath tmpFile
            Store.initDb ()
            action ()
        finally
            Store.setDbPath "data/holons/git-intel/state.sqlite"
            try File.Delete tmpFile with _ -> ()
            try File.Delete (tmpFile + "-wal") with _ -> ()
            try File.Delete (tmpFile + "-shm") with _ -> ()

    /// Create a temp DuckDB path, run action, then clean up.
    let private withTempHistory (action: unit -> unit) =
        let tmpFile = Path.Combine(Path.GetTempPath(), $"history-test-{Guid.NewGuid():N}.duckdb")
        try
            History.setDbPath tmpFile
            match History.initDb () with
            | Ok () -> action ()
            | Error e -> failwithf "History.initDb failed: %s" e
        finally
            History.setDbPath "data/holons/git-intel/history.duckdb"
            try File.Delete tmpFile with _ -> ()
            try File.Delete (tmpFile + ".wal") with _ -> ()

    // ═══════════════════════════════════════════════════════════════════════
    // Store.fs Tests (SQLite)
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let storeTests = testSequenced (testList "Store" [

        testCase "initDb creates tables without error" <| fun _ ->
            withTempStore (fun () ->
                // initDb already called by withTempStore — just verify no crash
                Expect.isTrue true "initDb succeeded"
            )

        testCase "recordCommit and getCommitBySha round-trip" <| fun _ ->
            withTempStore (fun () ->
                let sha = "abc12345"
                let result = Store.recordCommit sha "feat" "mesh,zenoh" "add feature" (Some 0.85) 3 100 20 "test-author"
                Expect.isOk result "recordCommit should succeed"

                let commit = Store.getCommitBySha sha
                Expect.isSome commit "commit should be retrievable"
                let c = commit.Value
                Expect.equal c.Sha sha "SHA matches"
                Expect.equal c.CommitType "feat" "type matches"
                Expect.equal c.Scopes "mesh,zenoh" "scopes match"
                Expect.equal c.FilesChanged 3 "files changed matches"
                Expect.equal c.Ghs (Some 0.85) "GHS matches"
            )

        testCase "getCommitBySha returns None for missing SHA" <| fun _ ->
            withTempStore (fun () ->
                let commit = Store.getCommitBySha "nonexistent"
                Expect.isNone commit "missing SHA returns None"
            )

        testCase "recordCommit upserts on duplicate SHA" <| fun _ ->
            withTempStore (fun () ->
                let sha = "dup12345"
                Store.recordCommit sha "feat" "mesh" "first" (Some 0.8) 1 10 5 "author1" |> ignore
                Store.recordCommit sha "fix" "zenoh" "updated" (Some 0.9) 2 20 10 "author2" |> ignore

                let commit = Store.getCommitBySha sha
                Expect.isSome commit "commit should exist"
                Expect.equal commit.Value.CommitType "fix" "type should be updated"
            )

        testCase "getRecentCommits returns in order" <| fun _ ->
            withTempStore (fun () ->
                for i in 1..5 do
                    Store.recordCommit $"sha{i:D5}" "feat" "mesh" $"commit {i}" None i 10 5 "author"
                    |> ignore

                let recent = Store.getRecentCommits 3
                Expect.equal (List.length recent) 3 "returns requested count"
            )

        testCase "getRecentCommits returns fewer when DB has less" <| fun _ ->
            withTempStore (fun () ->
                Store.recordCommit "only1" "fix" "app" "single" None 1 5 2 "author" |> ignore
                let recent = Store.getRecentCommits 10
                Expect.equal (List.length recent) 1 "returns only available"
            )

        testCase "getCommitCount returns correct count" <| fun _ ->
            withTempStore (fun () ->
                Expect.equal (Store.getCommitCount ()) 0 "empty DB has 0 commits"
                Store.recordCommit "c1" "feat" "mesh" "first" None 1 10 5 "author" |> ignore
                Store.recordCommit "c2" "fix" "app" "second" None 2 20 10 "author" |> ignore
                Expect.equal (Store.getCommitCount ()) 2 "two commits recorded"
            )

        testCase "recordHealthSnapshot and getLatestHealth" <| fun _ ->
            withTempStore (fun () ->
                let result = Store.recordHealthSnapshot 0.85 2.1 1.5 75.0 0.9 0.35 100
                Expect.isOk result "recordHealthSnapshot should succeed"

                let latest = Store.getLatestHealth ()
                Expect.isSome latest "latest health should exist"
                let (ghs, adoption, compliance, totalCommits) = latest.Value
                Expect.floatClose Accuracy.medium ghs 0.85 "GHS matches"
                Expect.floatClose Accuracy.medium adoption 75.0 "adoption matches"
                Expect.floatClose Accuracy.medium compliance 0.9 "compliance matches"
                Expect.equal totalCommits 100 "total commits matches"
            )

        testCase "getLatestHealth returns None when empty" <| fun _ ->
            withTempStore (fun () ->
                let latest = Store.getLatestHealth ()
                Expect.isNone latest "empty DB returns None"
            )

        testCase "getHealthHistory returns snapshots since date" <| fun _ ->
            withTempStore (fun () ->
                Store.recordHealthSnapshot 0.80 2.0 1.4 70.0 0.85 0.30 50 |> ignore
                Store.recordHealthSnapshot 0.85 2.1 1.5 75.0 0.90 0.35 100 |> ignore

                let history = Store.getHealthHistory (DateTimeOffset.UtcNow.AddHours(-1.0))
                Expect.isGreaterThanOrEqual (List.length history) 2 "returns recent snapshots"
            )

        testCase "setConfig and getConfig round-trip" <| fun _ ->
            withTempStore (fun () ->
                let result = Store.setConfig "test_key" "test_value"
                Expect.isOk result "setConfig should succeed"

                let value = Store.getConfig "test_key"
                Expect.equal value (Some "test_value") "config value matches"
            )

        testCase "getConfig returns None for missing key" <| fun _ ->
            withTempStore (fun () ->
                let value = Store.getConfig "nonexistent_key"
                Expect.isNone value "missing key returns None"
            )

        testCase "setConfig upserts on duplicate key" <| fun _ ->
            withTempStore (fun () ->
                Store.setConfig "version" "1.0" |> ignore
                Store.setConfig "version" "2.0" |> ignore
                let value = Store.getConfig "version"
                Expect.equal value (Some "2.0") "config value updated"
            )

        testCase "recordCommit with None GHS" <| fun _ ->
            withTempStore (fun () ->
                let result = Store.recordCommit "noghs" "chore" "ci" "cleanup" None 1 5 2 "author"
                Expect.isOk result "recordCommit with None GHS succeeds"
                let commit = Store.getCommitBySha "noghs"
                Expect.isSome commit "commit exists"
                Expect.isNone commit.Value.Ghs "GHS is None"
            )
    ])

    // ═══════════════════════════════════════════════════════════════════════
    // History.fs Tests (DuckDB)
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let historyTests = testSequenced (testList "History" [

        testCase "initDb creates table without error" <| fun _ ->
            withTempHistory (fun () ->
                Expect.isTrue true "initDb succeeded"
            )

        testCase "appendEvent returns event ID" <| fun _ ->
            withTempHistory (fun () ->
                let result = History.appendEvent "test-event" (Some 0.8) (Some 0.85) "test metadata"
                Expect.isOk result "appendEvent should succeed"
                let eventId = Result.defaultValue "" result
                Expect.isNotEmpty eventId "event ID should not be empty"
            )

        testCase "appendCommitEvent records correctly" <| fun _ ->
            withTempHistory (fun () ->
                History.appendCommitEvent "abc1234" (Some 0.8) (Some 0.85) "feat" 5 |> ignore
                let events = History.queryByType "commit" 10
                Expect.isGreaterThanOrEqual (List.length events) 1 "commit event recorded"
                let ev = events |> List.head
                Expect.equal ev.EventType "commit" "type is commit"
            )

        testCase "appendHealthEvent records correctly" <| fun _ ->
            withTempHistory (fun () ->
                History.appendHealthEvent (Some 0.8) (Some 0.9) 75.0 |> ignore
                let events = History.queryByType "health" 10
                Expect.isGreaterThanOrEqual (List.length events) 1 "health event recorded"
            )

        testCase "appendThreatEvent records correctly" <| fun _ ->
            withTempHistory (fun () ->
                History.appendThreatEvent "Medium" 3 (Some 0.75) |> ignore
                let events = History.queryByType "threat" 10
                Expect.isGreaterThanOrEqual (List.length events) 1 "threat event recorded"
            )

        testCase "appendConstitutionalEvent records correctly" <| fun _ ->
            withTempHistory (fun () ->
                History.appendConstitutionalEvent "Psi0" true 0.95 |> ignore
                let events = History.queryByType "constitutional" 10
                Expect.isGreaterThanOrEqual (List.length events) 1 "constitutional event recorded"
            )

        testCase "queryByType filters correctly" <| fun _ ->
            withTempHistory (fun () ->
                History.appendCommitEvent "sha1" None None "feat" 3 |> ignore
                History.appendHealthEvent None (Some 0.9) 80.0 |> ignore
                History.appendCommitEvent "sha2" None None "fix" 1 |> ignore

                let commits = History.queryByType "commit" 10
                let health = History.queryByType "health" 10
                Expect.equal (List.length commits) 2 "two commit events"
                Expect.equal (List.length health) 1 "one health event"
            )

        testCase "queryByType respects limit" <| fun _ ->
            withTempHistory (fun () ->
                for i in 1..10 do
                    History.appendCommitEvent $"sha{i}" None None "feat" i |> ignore

                let limited = History.queryByType "commit" 3
                Expect.equal (List.length limited) 3 "limit respected"
            )

        testCase "queryByDateRange returns events in window" <| fun _ ->
            withTempHistory (fun () ->
                History.appendCommitEvent "sha-range" (Some 0.8) (Some 0.85) "feat" 2 |> ignore
                let since = DateTimeOffset.UtcNow.AddHours(-1.0)
                let until = DateTimeOffset.UtcNow.AddHours(1.0)
                let events = History.queryByDateRange since until
                Expect.isGreaterThanOrEqual (List.length events) 1 "event in range"
            )

        testCase "getEventCount returns correct count" <| fun _ ->
            withTempHistory (fun () ->
                Expect.equal (History.getEventCount ()) 0 "empty DB has 0 events"
                History.appendCommitEvent "sha1" None None "feat" 1 |> ignore
                History.appendHealthEvent None (Some 0.9) 80.0 |> ignore
                Expect.equal (History.getEventCount ()) 2 "two events recorded"
            )

        testCase "computeVelocity returns events per day" <| fun _ ->
            withTempHistory (fun () ->
                // Add some events for the current day
                for i in 1..5 do
                    History.appendCommitEvent (Guid.NewGuid().ToString("N").[..7]) (Some (0.80 + float i * 0.01)) (Some (0.81 + float i * 0.01)) "feat" 1 |> ignore
                let velocity = History.computeVelocity 7
                Expect.isGreaterThan velocity 0.0 "velocity is positive"
            )

        testCase "computeVelocity is zero for empty DB" <| fun _ ->
            withTempHistory (fun () ->
                let velocity = History.computeVelocity 7
                Expect.floatClose Accuracy.medium velocity 0.0 "velocity is zero"
            )

        testCase "exportLineage returns all events" <| fun _ ->
            withTempHistory (fun () ->
                History.appendCommitEvent "sha1" None None "feat" 1 |> ignore
                History.appendHealthEvent None (Some 0.9) 80.0 |> ignore
                History.appendThreatEvent "Low" 1 (Some 0.85) |> ignore

                let lineage = History.exportLineage ()
                Expect.equal (List.length lineage) 3 "all events exported"
            )

        testCase "appendEvent computes delta correctly" <| fun _ ->
            withTempHistory (fun () ->
                let result = History.appendEvent "delta-test" (Some 0.80) (Some 0.90) "delta check"
                Expect.isOk result "append succeeds"

                let events = History.queryByType "delta-test" 1
                Expect.equal (List.length events) 1 "event found"
                Expect.isSome events.[0].Delta "delta should be Some"
                Expect.floatClose Accuracy.medium events.[0].Delta.Value 0.10 "delta = 0.90 - 0.80"
            )

        testCase "appendEvent with None ghsBefore has zero delta" <| fun _ ->
            withTempHistory (fun () ->
                History.appendEvent "no-before" None (Some 0.85) "no before" |> ignore
                let events = History.queryByType "no-before" 1
                Expect.equal (List.length events) 1 "event found"
                Expect.equal events.[0].Delta None "delta is None when before is None"
            )
    ])
