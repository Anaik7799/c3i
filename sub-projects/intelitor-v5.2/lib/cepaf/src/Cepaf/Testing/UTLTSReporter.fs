/// UTLTS Reporter for F# Expecto Tests
///
/// Records Expecto test results to the UTLTS SQLite database,
/// enabling cross-runtime test lifecycle tracking alongside Elixir and Rust.
///
/// ## What
/// Expecto TestPrinter-compatible reporter that writes test results to
/// `data/holons/test/utlts.db` after each test run.
///
/// ## Why
/// - F# has 69+ test files across Cepaf.Tests and Cepaf.IndrajaalTest
/// - No persistent test tracking for F# — results lost after each run
/// - Cross-runtime flaky detection requires unified data store
///
/// ## Constraints
/// - SC-UTLTS-002: All test runs recorded regardless of runtime
/// - SC-UTLTS-005: F# Expecto integration
/// - SC-NET-001: net10.0 target framework
///
/// ## Change History
/// | Version | Date       | Author      | Change                    |
/// |---------|------------|-------------|---------------------------|
/// | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |
///
/// @version "1.0.0"
/// @last_modified "2026-03-09T00:00:00Z"
module Cepaf.Testing.UTLTSReporter

open System
open System.IO
open Microsoft.Data.Sqlite

/// UTLTS database path (relative to project root)
[<Literal>]
let DbPath = "data/holons/test/utlts.db"

/// Test result record
type TestResult = {
    Id: string
    DefinitionId: string
    Status: string        // "passed" | "failed" | "skipped" | "errored"
    DurationUs: int64
    FailureMessage: string option
    StackTrace: string option
    StartedAt: string
    FinishedAt: string
}

/// Run summary
type RunSummary = {
    RunId: string
    ProjectId: string
    Total: int
    Passed: int
    Failed: int
    Skipped: int
    DurationMs: int64
    Status: string
}

/// Generate a UUID-like string
let private generateId () =
    Guid.NewGuid().ToString("D")

/// Get UTC now as ISO 8601
let private utcNow () =
    DateTimeOffset.UtcNow.ToString("o")

/// Get git context with Graceful Metadata Fallback (Detailed Analysis §1489)
let private gitContext () =
    let tryGetEnv var = 
        match Environment.GetEnvironmentVariable(var) with
        | null | "" -> None
        | v -> Some v

    let getGitCmd (args: string) =
        try
            let psi = Diagnostics.ProcessStartInfo("git", args)
            psi.RedirectStandardOutput <- true
            psi.UseShellExecute <- false
            use p = Diagnostics.Process.Start(psi)
            let output = p.StandardOutput.ReadToEnd().Trim()
            p.WaitForExit()
            if p.ExitCode = 0 then Some output else None
        with _ -> None

    let commit = 
        getGitCmd "rev-parse HEAD"
        |> Option.orElse (tryGetEnv "GIT_SHA")
        |> Option.orElse (if File.Exists(".git/HEAD") then Some "LOCAL-COMMIT" else None)

    let branch = 
        getGitCmd "rev-parse --abbrev-ref HEAD"
        |> Option.orElse (tryGetEnv "GIT_BRANCH")
        |> Option.orElse (if File.Exists(".git/HEAD") then Some "LOCAL-BRANCH" else None)

    (commit, branch)

/// Open UTLTS database with WAL mode
let private openDb () =
    let dir = Path.GetDirectoryName(DbPath)
    if not (Directory.Exists(dir)) then
        Directory.CreateDirectory(dir) |> ignore

    let connStr = $"Data Source={DbPath};Mode=ReadWriteCreate"
    let conn = new SqliteConnection(connStr)
    conn.Open()

    // WAL mode for concurrent access (SC-UTLTS-001)
    use pragmaCmd = conn.CreateCommand()
    pragmaCmd.CommandText <- "PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000; PRAGMA foreign_keys = ON;"
    pragmaCmd.ExecuteNonQuery() |> ignore

    conn

/// Capture environment fingerprint
let private captureEnvironment (conn: SqliteConnection) =
    let hostname = Environment.MachineName
    let dotnetVersion = Environment.Version.ToString()
    let fingerprint = $"{hostname}|fsharp|{dotnetVersion}"
    let hash = Security.Cryptography.SHA256.HashData(Text.Encoding.UTF8.GetBytes(fingerprint))
    let envId = BitConverter.ToString(hash).Replace("-", "").ToLower().Substring(0, 32)

    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT OR IGNORE INTO test_environments (id, hostname, os_name, dotnet_version)
        VALUES ($id, $hostname, 'Linux', $dotnet)
    """
    cmd.Parameters.AddWithValue("$id", envId) |> ignore
    cmd.Parameters.AddWithValue("$hostname", hostname) |> ignore
    cmd.Parameters.AddWithValue("$dotnet", dotnetVersion) |> ignore
    cmd.ExecuteNonQuery() |> ignore

    envId

/// Insert a test run record
let private insertRun (conn: SqliteConnection) (runId: string) (projectId: string) (envId: string) =
    let (commit, branch) = gitContext()
    let now = utcNow()

    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO test_runs (id, project_id, environment_id, run_type, status, trigger,
            git_commit, git_branch, started_at, tags)
        VALUES ($id, $project, $env, 'unit', 'running', 'manual', $commit, $branch, $now, '["fsharp","expecto"]')
    """
    cmd.Parameters.AddWithValue("$id", runId) |> ignore
    cmd.Parameters.AddWithValue("$project", projectId) |> ignore
    cmd.Parameters.AddWithValue("$env", envId) |> ignore
    cmd.Parameters.AddWithValue("$commit", commit |> Option.defaultValue "") |> ignore
    cmd.Parameters.AddWithValue("$branch", branch |> Option.defaultValue "") |> ignore
    cmd.Parameters.AddWithValue("$now", now) |> ignore
    cmd.ExecuteNonQuery() |> ignore

/// Ensure test suite exists
let private ensureSuite (conn: SqliteConnection) (projectId: string) (moduleName: string) (filePath: string) =
    // Check if exists
    use checkCmd = conn.CreateCommand()
    checkCmd.CommandText <- "SELECT id FROM test_suites WHERE project_id = $project AND name = $name"
    checkCmd.Parameters.AddWithValue("$project", projectId) |> ignore
    checkCmd.Parameters.AddWithValue("$name", moduleName) |> ignore

    match checkCmd.ExecuteScalar() with
    | null ->
        let id = generateId()
        use insertCmd = conn.CreateCommand()
        insertCmd.CommandText <- """
            INSERT OR IGNORE INTO test_suites (id, project_id, name, file_path, runtime, domain, category)
            VALUES ($id, $project, $name, $path, 'fsharp', 'cepaf', 'unit')
        """
        insertCmd.Parameters.AddWithValue("$id", id) |> ignore
        insertCmd.Parameters.AddWithValue("$project", projectId) |> ignore
        insertCmd.Parameters.AddWithValue("$name", moduleName) |> ignore
        insertCmd.Parameters.AddWithValue("$path", filePath) |> ignore
        insertCmd.ExecuteNonQuery() |> ignore
        id
    | existing -> existing.ToString()

/// Ensure test definition exists
let private ensureDefinition (conn: SqliteConnection) (suiteId: string) (testName: string) (fullName: string) =
    let id = generateId()

    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT OR IGNORE INTO test_definitions (id, suite_id, name, full_name, test_type, framework)
        VALUES ($id, $suite, $name, $fullname, 'test', 'expecto')
    """
    cmd.Parameters.AddWithValue("$id", id) |> ignore
    cmd.Parameters.AddWithValue("$suite", suiteId) |> ignore
    cmd.Parameters.AddWithValue("$name", testName) |> ignore
    cmd.Parameters.AddWithValue("$fullname", fullName) |> ignore
    cmd.ExecuteNonQuery() |> ignore
    id

/// Batch insert test results
let private insertResults (conn: SqliteConnection) (runId: string) (results: TestResult list) =
    use transaction = conn.BeginTransaction()

    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO test_results (id, run_id, definition_id, status, duration_us,
            failure_message, stacktrace, started_at, finished_at)
        VALUES ($id, $run, $def, $status, $duration, $failure, $stack, $start, $finish)
    """
    cmd.Transaction <- transaction

    let pId = cmd.Parameters.Add("$id", SqliteType.Text)
    let pRun = cmd.Parameters.Add("$run", SqliteType.Text)
    let pDef = cmd.Parameters.Add("$def", SqliteType.Text)
    let pStatus = cmd.Parameters.Add("$status", SqliteType.Text)
    let pDuration = cmd.Parameters.Add("$duration", SqliteType.Integer)
    let pFailure = cmd.Parameters.Add("$failure", SqliteType.Text)
    let pStack = cmd.Parameters.Add("$stack", SqliteType.Text)
    let pStart = cmd.Parameters.Add("$start", SqliteType.Text)
    let pFinish = cmd.Parameters.Add("$finish", SqliteType.Text)

    for r in results do
        pId.Value <- r.Id
        pRun.Value <- runId
        pDef.Value <- r.DefinitionId
        pStatus.Value <- r.Status
        pDuration.Value <- r.DurationUs
        pFailure.Value <- r.FailureMessage |> Option.defaultValue "" :> obj
        pStack.Value <- r.StackTrace |> Option.defaultValue "" :> obj
        pStart.Value <- r.StartedAt
        pFinish.Value <- r.FinishedAt
        cmd.ExecuteNonQuery() |> ignore

    transaction.Commit()

/// Finalize run with aggregate stats
let private finalizeRun (conn: SqliteConnection) (summary: RunSummary) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        UPDATE test_runs SET status = $status, finished_at = $now, duration_ms = $duration,
            total_tests = $total, passed = $passed, failed = $failed, skipped = $skipped
        WHERE id = $id
    """
    cmd.Parameters.AddWithValue("$status", summary.Status) |> ignore
    cmd.Parameters.AddWithValue("$now", utcNow()) |> ignore
    cmd.Parameters.AddWithValue("$duration", summary.DurationMs) |> ignore
    cmd.Parameters.AddWithValue("$total", summary.Total) |> ignore
    cmd.Parameters.AddWithValue("$passed", summary.Passed) |> ignore
    cmd.Parameters.AddWithValue("$failed", summary.Failed) |> ignore
    cmd.Parameters.AddWithValue("$skipped", summary.Skipped) |> ignore
    cmd.Parameters.AddWithValue("$id", summary.RunId) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// PUBLIC API
// ============================================================

/// Record an Expecto test run to UTLTS.
///
/// Call this after `runTestsWithCLIArgs` with the test results.
///
/// ## Example
/// ```fsharp
/// open Expecto
/// let tests = testList "MyTests" [ ... ]
/// let exitCode = runTestsWithCLIArgs defaultConfig [||] tests
///
/// // Record to UTLTS
/// UTLTSReporter.recordExpectoResults "proj-fsharp-cepaf" results
/// ```
let recordExpectoRun (projectId: string) (testResults: (string * string * int64 * string option * string option) list) =
    try
        use conn = openDb()
        let runId = generateId()
        let envId = captureEnvironment conn

        insertRun conn runId projectId envId

        // Group by module (first segment of test name before '/')
        let suiteCache = Collections.Generic.Dictionary<string, string>()

        let results =
            testResults
            |> List.map (fun (fullName, status, durationUs, failureMsg, stackTrace) ->
                // Extract module from "Module/TestName" or "Module.SubModule/TestName"
                let parts = fullName.Split([|'/'|], 2)
                let moduleName = if parts.Length > 1 then parts.[0] else "Default"
                let testName = if parts.Length > 1 then parts.[1] else fullName

                let suiteId =
                    if suiteCache.ContainsKey(moduleName) then
                        suiteCache.[moduleName]
                    else
                        let sid = ensureSuite conn projectId moduleName $"lib/cepaf/test/{moduleName}.fs"
                        suiteCache.[moduleName] <- sid
                        sid

                let definitionId = ensureDefinition conn suiteId testName fullName

                {
                    Id = generateId()
                    DefinitionId = definitionId
                    Status = status
                    DurationUs = durationUs
                    FailureMessage = failureMsg
                    StackTrace = stackTrace
                    StartedAt = utcNow()
                    FinishedAt = utcNow()
                }
            )

        insertResults conn runId results

        let passed = results |> List.filter (fun r -> r.Status = "passed") |> List.length
        let failed = results |> List.filter (fun r -> r.Status = "failed") |> List.length
        let skipped = results |> List.filter (fun r -> r.Status = "skipped") |> List.length
        let totalDuration = results |> List.sumBy (fun r -> r.DurationUs)

        let summary = {
            RunId = runId
            ProjectId = projectId
            Total = List.length results
            Passed = passed
            Failed = failed
            Skipped = skipped
            DurationMs = totalDuration / 1000L
            Status = if failed = 0 then "passed" else "failed"
        }

        finalizeRun conn summary

        printfn $"[UTLTS] F# Run {runId}: {passed}P/{failed}F/{skipped}S ({summary.DurationMs}ms)"
        Ok runId
    with ex ->
        eprintfn $"[UTLTS] Error recording F# results: {ex.Message}"
        Error ex.Message

/// Record a single test result (for streaming/real-time recording)
let recordSingleResult (conn: SqliteConnection) (runId: string) (projectId: string) (fullName: string) (status: string) (durationUs: int64) (failureMsg: string option) =
    let parts = fullName.Split([|'/'|], 2)
    let moduleName = if parts.Length > 1 then parts.[0] else "Default"
    let testName = if parts.Length > 1 then parts.[1] else fullName

    let suiteId = ensureSuite conn projectId moduleName $"lib/cepaf/test/{moduleName}.fs"
    let definitionId = ensureDefinition conn suiteId testName fullName

    let result = {
        Id = generateId()
        DefinitionId = definitionId
        Status = status
        DurationUs = durationUs
        FailureMessage = failureMsg
        StackTrace = None
        StartedAt = utcNow()
        FinishedAt = utcNow()
    }

    insertResults conn runId [result]

/// Open a connection for streaming recording
let openConnection () = openDb()

/// Create a new run and return its ID (for streaming)
let startRun (conn: SqliteConnection) (projectId: string) =
    let runId = generateId()
    let envId = captureEnvironment conn
    insertRun conn runId projectId envId
    runId

/// Finalize a streaming run
let finishRun (conn: SqliteConnection) (summary: RunSummary) =
    finalizeRun conn summary
