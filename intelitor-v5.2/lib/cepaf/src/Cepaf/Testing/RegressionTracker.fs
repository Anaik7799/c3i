/// Regression Tracker - SQLite Data Access Layer
///
/// Records 5-level regression test results to the existing
/// `data/regression/regression_tracker.db` schema (7 tables).
///
/// ## What
/// SQLite DAL that creates run records, inserts per-level results
/// (compile, test suites, quality gates, system health), and
/// writes aggregate run_summary rows.
///
/// ## Why
/// - Persistent regression tracking across F# and Elixir runtimes
/// - Enables trend analysis and historical comparison
/// - SQLite WAL mode for safe concurrent access
///
/// ## Constraints
/// - SC-METRICS-003: Parallelization mandatory for compilation
/// - SC-NET-001: net10.0 target framework
/// - AOR-DBLOCAL-001: WAL mode for all SQLite databases
///
/// ## Change History
/// | Version | Date       | Author      | Change                    |
/// |---------|------------|-------------|---------------------------|
/// | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |
///
/// @version "1.0.0"
/// @last_modified "2026-03-09T00:00:00Z"
module Cepaf.Testing.RegressionTracker

open System
open System.Diagnostics
open System.IO
open Microsoft.Data.Sqlite

// ============================================================
// TYPES
// ============================================================

/// Compile result for a single environment (dev, warnings-as-errors)
type CompileResult = {
    Env: string
    Status: string
    FileCount: int
    WarningCount: int
    ErrorCount: int
    DurationS: float
}

/// Test suite result from `mix test`
type TestSuiteResult = {
    SuiteName: string
    SuitePath: string
    Total: int
    Passed: int
    Failed: int
    Skipped: int
    Excluded: int
    Properties: int
    DurationS: float
    Status: string
}

/// Quality gate result (format, credo, dialyzer, sobelow)
type QualityResult = {
    GateName: string
    Status: string
    IssueCount: int
    DurationS: float
    OutputExcerpt: string
}

/// System health check (ports, git, DB, F# build)
type SystemHealthCheck = {
    CheckName: string
    Status: string
    Details: string
}

/// Aggregate run summary
type RunSummary = {
    RunId: string
    OverallStatus: string
    CompileStatus: string
    FullTestStatus: string
    Sil6TestStatus: string
    QualityStatus: string
    SystemStatus: string
    TotalTests: int
    TotalPassed: int
    TotalFailed: int
    TotalSkipped: int
    TotalExcluded: int
    TotalProperties: int
    TotalDurationS: float
    Sil6Tests: int
    Sil6Passed: int
    Sil6Failed: int
    Sil6Properties: int
    ElixirModules: int
}

/// Previous run for comparison
type PreviousRun = {
    RunId: string
    Timestamp: string
    OverallStatus: string
    TotalTests: int
    TotalFailed: int
    TotalDurationS: float
}

// ============================================================
// DATABASE PATH
// ============================================================

/// Regression tracker database path (relative to project root)
[<Literal>]
let DbPath = "data/regression/regression_tracker.db"

// ============================================================
// PRIVATE HELPERS
// ============================================================

/// Get UTC now as ISO 8601
let private utcNow () =
    DateTimeOffset.UtcNow.ToString("o")

/// Get git context (sha, branch)
let private gitContext () =
    try
        let runGit (gitArgs: string) =
            let psi = ProcessStartInfo("git", gitArgs)
            psi.RedirectStandardOutput <- true
            psi.UseShellExecute <- false
            let p = Process.Start(psi)
            let output = p.StandardOutput.ReadToEnd().Trim()
            p.WaitForExit()
            output
        let commit = runGit "rev-parse --short HEAD"
        let branch = runGit "rev-parse --abbrev-ref HEAD"
        (commit, branch)
    with _ -> ("unknown", "unknown")

/// Get Elixir version
let private elixirVersion () =
    try
        let psi = ProcessStartInfo("elixir", "--version")
        psi.RedirectStandardOutput <- true
        psi.UseShellExecute <- false
        let p = Process.Start(psi)
        let output = p.StandardOutput.ReadToEnd()
        p.WaitForExit()
        // Parse "Elixir 1.19.4 ..." line
        let lines = output.Split('\n')
        let elixirLine = lines |> Array.tryFind (fun l -> l.Contains("Elixir"))
        let otpLine = lines |> Array.tryFind (fun l -> l.Contains("OTP"))
        let elixir =
            match elixirLine with
            | Some l ->
                let parts = l.Split(' ')
                if parts.Length >= 2 then parts.[1].Trim() else "unknown"
            | None -> "unknown"
        let otp =
            match otpLine with
            | Some l ->
                let parts = l.Split(' ')
                if parts.Length >= 2 then parts.[1].Trim() else "unknown"
            | None -> "unknown"
        (elixir, otp)
    with _ -> ("unknown", "unknown")

/// Open regression tracker database with WAL mode
let openDb () =
    let dir = Path.GetDirectoryName(DbPath)
    if not (Directory.Exists(dir)) then
        Directory.CreateDirectory(dir) |> ignore

    let connStr = $"Data Source={DbPath};Mode=ReadWriteCreate"
    let conn = new SqliteConnection(connStr)
    conn.Open()

    use pragmaCmd = conn.CreateCommand()
    pragmaCmd.CommandText <- "PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000; PRAGMA foreign_keys = ON;"
    pragmaCmd.ExecuteNonQuery() |> ignore

    conn

// ============================================================
// RUN MANAGEMENT
// ============================================================

/// Generate run ID: REG-YYYYMMDD-HHMMSS-{git_sha}
let generateRunId () =
    let now = DateTime.UtcNow
    let (sha, _) = gitContext()
    $"REG-{now:yyyyMMdd}-{now:HHmmss}-{sha}"

/// Create a new regression run record
let createRun (conn: SqliteConnection) (runId: string) =
    let (sha, branch) = gitContext()
    let (elixir, otp) = elixirVersion()
    let hostname = Environment.MachineName
    let now = utcNow()

    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO regression_runs (run_id, timestamp, git_sha, git_branch, elixir_version, otp_version, hostname)
        VALUES ($runId, $ts, $sha, $branch, $elixir, $otp, $host)
    """
    cmd.Parameters.AddWithValue("$runId", runId) |> ignore
    cmd.Parameters.AddWithValue("$ts", now) |> ignore
    cmd.Parameters.AddWithValue("$sha", sha) |> ignore
    cmd.Parameters.AddWithValue("$branch", branch) |> ignore
    cmd.Parameters.AddWithValue("$elixir", elixir) |> ignore
    cmd.Parameters.AddWithValue("$otp", otp) |> ignore
    cmd.Parameters.AddWithValue("$host", hostname) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// COMPILE RESULTS
// ============================================================

/// Record a compile result
let recordCompileResult (conn: SqliteConnection) (runId: string) (result: CompileResult) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO compile_results (run_id, env, status, file_count, warning_count, error_count, duration_s)
        VALUES ($runId, $env, $status, $files, $warnings, $errors, $duration)
    """
    cmd.Parameters.AddWithValue("$runId", runId) |> ignore
    cmd.Parameters.AddWithValue("$env", result.Env) |> ignore
    cmd.Parameters.AddWithValue("$status", result.Status) |> ignore
    cmd.Parameters.AddWithValue("$files", result.FileCount) |> ignore
    cmd.Parameters.AddWithValue("$warnings", result.WarningCount) |> ignore
    cmd.Parameters.AddWithValue("$errors", result.ErrorCount) |> ignore
    cmd.Parameters.AddWithValue("$duration", result.DurationS) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// TEST SUITE RESULTS
// ============================================================

/// Record a test suite result
let recordTestSuite (conn: SqliteConnection) (runId: string) (result: TestSuiteResult) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO test_suites (run_id, suite_name, suite_path, total_tests, passed, failed, skipped, excluded, properties, duration_s, status)
        VALUES ($runId, $name, $path, $total, $passed, $failed, $skipped, $excluded, $props, $duration, $status)
    """
    cmd.Parameters.AddWithValue("$runId", runId) |> ignore
    cmd.Parameters.AddWithValue("$name", result.SuiteName) |> ignore
    cmd.Parameters.AddWithValue("$path", result.SuitePath) |> ignore
    cmd.Parameters.AddWithValue("$total", result.Total) |> ignore
    cmd.Parameters.AddWithValue("$passed", result.Passed) |> ignore
    cmd.Parameters.AddWithValue("$failed", result.Failed) |> ignore
    cmd.Parameters.AddWithValue("$skipped", result.Skipped) |> ignore
    cmd.Parameters.AddWithValue("$excluded", result.Excluded) |> ignore
    cmd.Parameters.AddWithValue("$props", result.Properties) |> ignore
    cmd.Parameters.AddWithValue("$duration", result.DurationS) |> ignore
    cmd.Parameters.AddWithValue("$status", result.Status) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// QUALITY RESULTS
// ============================================================

/// Record a quality gate result
let recordQualityResult (conn: SqliteConnection) (runId: string) (result: QualityResult) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO quality_results (run_id, gate_name, status, issue_count, duration_s, output_excerpt)
        VALUES ($runId, $gate, $status, $issues, $duration, $excerpt)
    """
    cmd.Parameters.AddWithValue("$runId", runId) |> ignore
    cmd.Parameters.AddWithValue("$gate", result.GateName) |> ignore
    cmd.Parameters.AddWithValue("$status", result.Status) |> ignore
    cmd.Parameters.AddWithValue("$issues", result.IssueCount) |> ignore
    cmd.Parameters.AddWithValue("$duration", result.DurationS) |> ignore
    cmd.Parameters.AddWithValue("$excerpt", result.OutputExcerpt) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// SYSTEM HEALTH
// ============================================================

/// Record a system health check
let recordHealthCheck (conn: SqliteConnection) (runId: string) (check: SystemHealthCheck) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT INTO system_health (run_id, check_name, status, details)
        VALUES ($runId, $name, $status, $details)
    """
    cmd.Parameters.AddWithValue("$runId", runId) |> ignore
    cmd.Parameters.AddWithValue("$name", check.CheckName) |> ignore
    cmd.Parameters.AddWithValue("$status", check.Status) |> ignore
    cmd.Parameters.AddWithValue("$details", check.Details) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// RUN SUMMARY
// ============================================================

/// Write aggregate run summary
let recordRunSummary (conn: SqliteConnection) (summary: RunSummary) =
    let now = utcNow()

    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        INSERT OR REPLACE INTO run_summary
            (run_id, overall_status, compile_status, full_test_status, sil6_test_status,
             quality_status, system_status, total_tests, total_passed, total_failed,
             total_skipped, total_excluded, total_properties, total_duration_s,
             sil6_tests, sil6_passed, sil6_failed, sil6_properties, elixir_modules, recorded_at)
        VALUES ($runId, $overall, $compile, $fullTest, $sil6Test,
                $quality, $system, $totalTests, $totalPassed, $totalFailed,
                $totalSkipped, $totalExcluded, $totalProps, $totalDuration,
                $sil6Tests, $sil6Passed, $sil6Failed, $sil6Props, $modules, $now)
    """
    cmd.Parameters.AddWithValue("$runId", summary.RunId) |> ignore
    cmd.Parameters.AddWithValue("$overall", summary.OverallStatus) |> ignore
    cmd.Parameters.AddWithValue("$compile", summary.CompileStatus) |> ignore
    cmd.Parameters.AddWithValue("$fullTest", summary.FullTestStatus) |> ignore
    cmd.Parameters.AddWithValue("$sil6Test", summary.Sil6TestStatus) |> ignore
    cmd.Parameters.AddWithValue("$quality", summary.QualityStatus) |> ignore
    cmd.Parameters.AddWithValue("$system", summary.SystemStatus) |> ignore
    cmd.Parameters.AddWithValue("$totalTests", summary.TotalTests) |> ignore
    cmd.Parameters.AddWithValue("$totalPassed", summary.TotalPassed) |> ignore
    cmd.Parameters.AddWithValue("$totalFailed", summary.TotalFailed) |> ignore
    cmd.Parameters.AddWithValue("$totalSkipped", summary.TotalSkipped) |> ignore
    cmd.Parameters.AddWithValue("$totalExcluded", summary.TotalExcluded) |> ignore
    cmd.Parameters.AddWithValue("$totalProps", summary.TotalProperties) |> ignore
    cmd.Parameters.AddWithValue("$totalDuration", summary.TotalDurationS) |> ignore
    cmd.Parameters.AddWithValue("$sil6Tests", summary.Sil6Tests) |> ignore
    cmd.Parameters.AddWithValue("$sil6Passed", summary.Sil6Passed) |> ignore
    cmd.Parameters.AddWithValue("$sil6Failed", summary.Sil6Failed) |> ignore
    cmd.Parameters.AddWithValue("$sil6Props", summary.Sil6Properties) |> ignore
    cmd.Parameters.AddWithValue("$modules", summary.ElixirModules) |> ignore
    cmd.Parameters.AddWithValue("$now", now) |> ignore
    cmd.ExecuteNonQuery() |> ignore

// ============================================================
// QUERIES
// ============================================================

/// Get previous run for comparison
let getPreviousRun (conn: SqliteConnection) : PreviousRun option =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        SELECT r.run_id, r.timestamp, s.overall_status, s.total_tests, s.total_failed, s.total_duration_s
        FROM regression_runs r
        JOIN run_summary s ON r.run_id = s.run_id
        ORDER BY r.timestamp DESC
        LIMIT 1
    """
    use reader = cmd.ExecuteReader()
    if reader.Read() then
        Some {
            RunId = reader.GetString(0)
            Timestamp = reader.GetString(1)
            OverallStatus = reader.GetString(2)
            TotalTests = reader.GetInt32(3)
            TotalFailed = reader.GetInt32(4)
            TotalDurationS = reader.GetDouble(5)
        }
    else
        None

/// Get latest run summary for report display
let getLatestRunSummary (conn: SqliteConnection) : (string * RunSummary) option =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        SELECT r.run_id, r.timestamp, r.git_sha, r.git_branch,
               s.overall_status, s.compile_status, s.full_test_status, s.sil6_test_status,
               s.quality_status, s.system_status, s.total_tests, s.total_passed,
               s.total_failed, s.total_skipped, s.total_excluded, s.total_properties,
               s.total_duration_s, s.sil6_tests, s.sil6_passed, s.sil6_failed,
               s.sil6_properties, s.elixir_modules
        FROM regression_runs r
        JOIN run_summary s ON r.run_id = s.run_id
        ORDER BY r.timestamp DESC
        LIMIT 1
    """
    use reader = cmd.ExecuteReader()
    if reader.Read() then
        let timestamp = reader.GetString(1)
        let summary = {
            RunId = reader.GetString(0)
            OverallStatus = reader.GetString(4)
            CompileStatus = if reader.IsDBNull(5) then "N/A" else reader.GetString(5)
            FullTestStatus = if reader.IsDBNull(6) then "N/A" else reader.GetString(6)
            Sil6TestStatus = if reader.IsDBNull(7) then "N/A" else reader.GetString(7)
            QualityStatus = if reader.IsDBNull(8) then "N/A" else reader.GetString(8)
            SystemStatus = if reader.IsDBNull(9) then "N/A" else reader.GetString(9)
            TotalTests = if reader.IsDBNull(10) then 0 else reader.GetInt32(10)
            TotalPassed = if reader.IsDBNull(11) then 0 else reader.GetInt32(11)
            TotalFailed = if reader.IsDBNull(12) then 0 else reader.GetInt32(12)
            TotalSkipped = if reader.IsDBNull(13) then 0 else reader.GetInt32(13)
            TotalExcluded = if reader.IsDBNull(14) then 0 else reader.GetInt32(14)
            TotalProperties = if reader.IsDBNull(15) then 0 else reader.GetInt32(15)
            TotalDurationS = if reader.IsDBNull(16) then 0.0 else reader.GetDouble(16)
            Sil6Tests = if reader.IsDBNull(17) then 0 else reader.GetInt32(17)
            Sil6Passed = if reader.IsDBNull(18) then 0 else reader.GetInt32(18)
            Sil6Failed = if reader.IsDBNull(19) then 0 else reader.GetInt32(19)
            Sil6Properties = if reader.IsDBNull(20) then 0 else reader.GetInt32(20)
            ElixirModules = if reader.IsDBNull(21) then 0 else reader.GetInt32(21)
        }
        Some (timestamp, summary)
    else
        None
