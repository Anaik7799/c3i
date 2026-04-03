// =============================================================================
// Git Intelligence — L3 Holon State (SQLite)
// =============================================================================
// Purpose:  Persistent holon state for git intelligence. Records commits,
//           health snapshots, and configuration in SQLite with WAL mode.
//           Mirrors UTLTSReporter.fs pattern: WAL, busy_timeout 5000.
//
// Tables:   commits          — recorded commit history
//           health_snapshots — GHS score timeline
//           config           — key-value holon configuration
//
// STAMP:    SC-UTLTS-001 (WAL), AOR-HOLON-001 (SQLite state),
//           SC-XHOLON-030 (no data loss), SC-XHOLON-031 (ACID)
// =============================================================================

module Cepaf.GitIntelligence.Store

open System
open System.IO
open Microsoft.Data.Sqlite

// ─────────────────────────────────────────────────────────────────────────────
// Database path — relative to project root
// ─────────────────────────────────────────────────────────────────────────────

let mutable private dbPathOverride: string option = None

/// Override the database path (for testing or custom holon paths).
let setDbPath (path: string) = dbPathOverride <- Some path

/// Get the effective database path.
let private dbPath () =
    match dbPathOverride with
    | Some p -> p
    | None -> "data/holons/git-intel/state.sqlite"

// ─────────────────────────────────────────────────────────────────────────────
// Connection management — WAL mode, busy_timeout (SC-UTLTS-001)
// ─────────────────────────────────────────────────────────────────────────────

/// Open SQLite database with WAL mode and busy_timeout.
let private openDb () =
    let path = dbPath ()
    let dir = Path.GetDirectoryName(path)
    if not (String.IsNullOrEmpty(dir)) && not (Directory.Exists(dir)) then
        Directory.CreateDirectory(dir) |> ignore

    let connStr = $"Data Source={path};Mode=ReadWriteCreate"
    let conn = new SqliteConnection(connStr)
    conn.Open()

    // WAL mode for concurrent access (SC-UTLTS-001, SC-XHOLON-030)
    use pragmaCmd = conn.CreateCommand()
    pragmaCmd.CommandText <- "PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000; PRAGMA foreign_keys = ON;"
    pragmaCmd.ExecuteNonQuery() |> ignore

    conn

// ─────────────────────────────────────────────────────────────────────────────
// Schema initialization
// ─────────────────────────────────────────────────────────────────────────────

let private createSchema (conn: SqliteConnection) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        CREATE TABLE IF NOT EXISTS commits (
            sha TEXT PRIMARY KEY,
            commit_type TEXT NOT NULL,
            scopes TEXT NOT NULL DEFAULT '[]',
            message TEXT NOT NULL DEFAULT '',
            ghs REAL,
            files_changed INTEGER NOT NULL DEFAULT 0,
            insertions INTEGER NOT NULL DEFAULT 0,
            deletions INTEGER NOT NULL DEFAULT 0,
            author TEXT NOT NULL DEFAULT '',
            recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS health_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ghs REAL NOT NULL,
            type_entropy REAL NOT NULL DEFAULT 0.0,
            scope_entropy REAL NOT NULL DEFAULT 0.0,
            icp_adoption REAL NOT NULL DEFAULT 0.0,
            scope_compliance REAL NOT NULL DEFAULT 0.0,
            mean_density REAL NOT NULL DEFAULT 0.0,
            total_commits INTEGER NOT NULL DEFAULT 0,
            snapshot_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE INDEX IF NOT EXISTS idx_commits_recorded_at ON commits(recorded_at);
        CREATE INDEX IF NOT EXISTS idx_health_snapshots_at ON health_snapshots(snapshot_at);
    """
    cmd.ExecuteNonQuery() |> ignore

/// Initialize the database (create tables if needed).
let initDb () =
    use conn = openDb ()
    createSchema conn

// ─────────────────────────────────────────────────────────────────────────────
// Commit operations
// ─────────────────────────────────────────────────────────────────────────────

/// Record a commit to the holon state store.
let recordCommit
    (sha: string)
    (commitType: string)
    (scopes: string)
    (message: string)
    (ghs: float option)
    (filesChanged: int)
    (insertions: int)
    (deletions: int)
    (author: string)
    : Result<unit, string> =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT OR REPLACE INTO commits (sha, commit_type, scopes, message, ghs, files_changed, insertions, deletions, author, recorded_at)
            VALUES ($sha, $type, $scopes, $message, $ghs, $files, $ins, $del, $author, $at)
        """
        cmd.Parameters.AddWithValue("$sha", sha) |> ignore
        cmd.Parameters.AddWithValue("$type", commitType) |> ignore
        cmd.Parameters.AddWithValue("$scopes", scopes) |> ignore
        cmd.Parameters.AddWithValue("$message", message) |> ignore
        cmd.Parameters.AddWithValue("$ghs", match ghs with Some g -> box g | None -> box DBNull.Value) |> ignore
        cmd.Parameters.AddWithValue("$files", filesChanged) |> ignore
        cmd.Parameters.AddWithValue("$ins", insertions) |> ignore
        cmd.Parameters.AddWithValue("$del", deletions) |> ignore
        cmd.Parameters.AddWithValue("$author", author) |> ignore
        cmd.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("o")) |> ignore
        cmd.ExecuteNonQuery() |> ignore
        Ok ()
    with ex ->
        Error $"Failed to record commit {sha}: {ex.Message}"

/// Get a commit by SHA.
let getCommitBySha (sha: string) : HolonCommitRecord option =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT sha, commit_type, scopes, ghs, files_changed, recorded_at FROM commits WHERE sha = $sha"
        cmd.Parameters.AddWithValue("$sha", sha) |> ignore
        use reader = cmd.ExecuteReader()
        if reader.Read() then
            Some {
                Sha = reader.GetString(0)
                CommitType = reader.GetString(1)
                Scopes = reader.GetString(2)
                Ghs = if reader.IsDBNull(3) then None else Some (reader.GetDouble(3))
                FilesChanged = reader.GetInt32(4)
                RecordedAt = DateTimeOffset.Parse(reader.GetString(5))
            }
        else
            None
    with _ -> None

/// Get the most recent N commits.
let getRecentCommits (count: int) : HolonCommitRecord list =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT sha, commit_type, scopes, ghs, files_changed, recorded_at FROM commits ORDER BY recorded_at DESC LIMIT $count"
        cmd.Parameters.AddWithValue("$count", count) |> ignore
        use reader = cmd.ExecuteReader()
        [ while reader.Read() do
            yield {
                Sha = reader.GetString(0)
                CommitType = reader.GetString(1)
                Scopes = reader.GetString(2)
                Ghs = if reader.IsDBNull(3) then None else Some (reader.GetDouble(3))
                FilesChanged = reader.GetInt32(4)
                RecordedAt = DateTimeOffset.Parse(reader.GetString(5))
            }
        ]
    with _ -> []

/// Get total commit count.
let getCommitCount () : int =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT COUNT(*) FROM commits"
        cmd.ExecuteScalar() :?> int64 |> int
    with _ -> 0

// ─────────────────────────────────────────────────────────────────────────────
// Health snapshot operations
// ─────────────────────────────────────────────────────────────────────────────

/// Record a health snapshot.
let recordHealthSnapshot
    (ghs: float)
    (typeEntropy: float)
    (scopeEntropy: float)
    (icpAdoption: float)
    (scopeCompliance: float)
    (meanDensity: float)
    (totalCommits: int)
    : Result<unit, string> =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO health_snapshots (ghs, type_entropy, scope_entropy, icp_adoption, scope_compliance, mean_density, total_commits, snapshot_at)
            VALUES ($ghs, $te, $se, $icp, $sc, $md, $tc, $at)
        """
        cmd.Parameters.AddWithValue("$ghs", ghs) |> ignore
        cmd.Parameters.AddWithValue("$te", typeEntropy) |> ignore
        cmd.Parameters.AddWithValue("$se", scopeEntropy) |> ignore
        cmd.Parameters.AddWithValue("$icp", icpAdoption) |> ignore
        cmd.Parameters.AddWithValue("$sc", scopeCompliance) |> ignore
        cmd.Parameters.AddWithValue("$md", meanDensity) |> ignore
        cmd.Parameters.AddWithValue("$tc", totalCommits) |> ignore
        cmd.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("o")) |> ignore
        cmd.ExecuteNonQuery() |> ignore
        Ok ()
    with ex ->
        Error $"Failed to record health snapshot: {ex.Message}"

/// Get the latest health snapshot.
let getLatestHealth () : (float * float * float * int) option =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT ghs, icp_adoption, scope_compliance, total_commits FROM health_snapshots ORDER BY snapshot_at DESC LIMIT 1"
        use reader = cmd.ExecuteReader()
        if reader.Read() then
            Some (reader.GetDouble(0), reader.GetDouble(1), reader.GetDouble(2), reader.GetInt32(3))
        else
            None
    with _ -> None

/// Get health snapshots within a date range.
let getHealthHistory (since: DateTimeOffset) : (DateTimeOffset * float) list =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT snapshot_at, ghs FROM health_snapshots WHERE snapshot_at >= $since ORDER BY snapshot_at ASC"
        cmd.Parameters.AddWithValue("$since", since.ToString("o")) |> ignore
        use reader = cmd.ExecuteReader()
        [ while reader.Read() do
            yield (DateTimeOffset.Parse(reader.GetString(0)), reader.GetDouble(1))
        ]
    with _ -> []

// ─────────────────────────────────────────────────────────────────────────────
// Configuration operations
// ─────────────────────────────────────────────────────────────────────────────

/// Get a configuration value.
let getConfig (key: string) : string option =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT value FROM config WHERE key = $key"
        cmd.Parameters.AddWithValue("$key", key) |> ignore
        use reader = cmd.ExecuteReader()
        if reader.Read() then Some (reader.GetString(0)) else None
    with _ -> None

/// Set a configuration value.
let setConfig (key: string) (value: string) : Result<unit, string> =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT OR REPLACE INTO config (key, value, updated_at)
            VALUES ($key, $value, $at)
        """
        cmd.Parameters.AddWithValue("$key", key) |> ignore
        cmd.Parameters.AddWithValue("$value", value) |> ignore
        cmd.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("o")) |> ignore
        cmd.ExecuteNonQuery() |> ignore
        Ok ()
    with ex ->
        Error $"Failed to set config {key}: {ex.Message}"
