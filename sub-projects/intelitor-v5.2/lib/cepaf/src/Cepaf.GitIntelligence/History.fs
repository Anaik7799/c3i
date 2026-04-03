// =============================================================================
// Git Intelligence — L3 DuckDB Evolution Log
// =============================================================================
// Purpose:  Append-only evolution event log for git intelligence holon.
//           Records all state transitions (commits, health changes, threats,
//           constitutional checks) in DuckDB for analytics and lineage.
//
// Tables:   evolution_events — append-only event log (NEVER delete/update)
//
// STAMP:    AOR-HOLON-019 (append-only lineage), SC-SMRITI-142 (DuckDB),
//           SC-XHOLON-035 (immutable audit), SC-XHOLON-021 (query < 10ms)
// =============================================================================

module Cepaf.GitIntelligence.History

open System
open System.IO

// ─────────────────────────────────────────────────────────────────────────────
// Database path
// ─────────────────────────────────────────────────────────────────────────────

let mutable private dbPathOverride: string option = None

/// Override the database path (for testing).
let setDbPath (path: string) = dbPathOverride <- Some path

/// Get the effective database path.
let private dbPath () =
    match dbPathOverride with
    | Some p -> p
    | None -> "data/holons/git-intel/history.duckdb"

// ─────────────────────────────────────────────────────────────────────────────
// DuckDB connection — using ADO.NET provider (DuckDB.NET.Data)
// ─────────────────────────────────────────────────────────────────────────────

let private ensureDir () =
    let path = dbPath ()
    let dir = Path.GetDirectoryName(path)
    if not (String.IsNullOrEmpty(dir)) && not (Directory.Exists(dir)) then
        Directory.CreateDirectory(dir) |> ignore

/// Open a DuckDB connection.
let private openDb () =
    ensureDir ()
    let connStr = $"Data Source={dbPath ()}"
    let conn = new DuckDB.NET.Data.DuckDBConnection(connStr)
    conn.Open()
    conn

/// Create the schema if it does not exist.
let private createSchema (conn: DuckDB.NET.Data.DuckDBConnection) =
    use cmd = conn.CreateCommand()
    cmd.CommandText <- """
        CREATE TABLE IF NOT EXISTS evolution_events (
            event_id VARCHAR NOT NULL,
            event_type VARCHAR NOT NULL,
            ghs_before DOUBLE,
            ghs_after DOUBLE,
            delta DOUBLE,
            metadata VARCHAR NOT NULL DEFAULT '{}',
            timestamp TIMESTAMP NOT NULL DEFAULT current_timestamp,
            PRIMARY KEY (event_id)
        );
        
        CREATE TABLE IF NOT EXISTS git_intelligence_corpus (
            event_id VARCHAR NOT NULL,
            diff_summary VARCHAR NOT NULL,
            suggestion VARCHAR NOT NULL,
            model VARCHAR NOT NULL,
            is_valid BOOLEAN NOT NULL,
            timestamp TIMESTAMP NOT NULL DEFAULT current_timestamp,
            PRIMARY KEY (event_id)
        );
    """
    cmd.ExecuteNonQuery() |> ignore

/// Initialize the history database.
let initDb () =
    try
        use conn = openDb ()
        createSchema conn
        Ok ()
    with ex ->
        Error $"Failed to initialize history DB: {ex.Message}"

// ─────────────────────────────────────────────────────────────────────────────
// Append operations (NEVER delete or update — AOR-HOLON-019)
// ─────────────────────────────────────────────────────────────────────────────

/// Append an AI suggestion to the corpus.
let appendSuggestion (diff: string) (suggestion: string) (model: string) (isValid: bool) : Result<string, string> =
    try
        use conn = openDb ()
        createSchema conn
        let eventId = Guid.NewGuid().ToString("D")
        let ts = DateTime.UtcNow

        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO git_intelligence_corpus (event_id, diff_summary, suggestion, model, is_valid, timestamp)
            VALUES ($1, $2, $3, $4, $5, $6)
        """
        let addParam (v: obj) = let p = new DuckDB.NET.Data.DuckDBParameter() in p.Value <- v; cmd.Parameters.Add(p) |> ignore
        addParam (box eventId)
        addParam (box diff)
        addParam (box suggestion)
        addParam (box model)
        addParam (box isValid)
        addParam (box ts)
        cmd.ExecuteNonQuery() |> ignore

        Ok eventId
    with ex ->
        Error $"Failed to append suggestion to corpus: {ex.Message}"

/// Append an evolution event. Returns Ok(eventId) or Error.
let appendEvent
    (eventType: string)
    (ghsBefore: float option)
    (ghsAfter: float option)
    (metadata: string)
    : Result<string, string> =
    try
        use conn = openDb ()
        createSchema conn
        let eventId = Guid.NewGuid().ToString("D")
        let delta =
            match ghsBefore, ghsAfter with
            | Some b, Some a -> Some (a - b)
            | _ -> None
        let ts = DateTime.UtcNow

        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO evolution_events (event_id, event_type, ghs_before, ghs_after, delta, metadata, timestamp)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
        """
        let addParam (v: obj) = let p = new DuckDB.NET.Data.DuckDBParameter() in p.Value <- v; cmd.Parameters.Add(p) |> ignore
        addParam (box eventId)
        addParam (box eventType)
        addParam (match ghsBefore with Some v -> box v | None -> box DBNull.Value)
        addParam (match ghsAfter with Some v -> box v | None -> box DBNull.Value)
        addParam (match delta with Some v -> box v | None -> box DBNull.Value)
        addParam (box metadata)
        addParam (box ts)
        cmd.ExecuteNonQuery() |> ignore

        Ok eventId
    with ex ->
        Error $"Failed to append event: {ex.Message}"

/// Convenience: append a commit event.
let appendCommitEvent (sha: string) (ghsBefore: float option) (ghsAfter: float option) (commitType: string) (filesChanged: int) =
    let meta = $"""{{\"sha\":\"{sha}\",\"type\":\"{commitType}\",\"filesChanged\":{filesChanged}}}"""
    appendEvent "commit" ghsBefore ghsAfter meta

/// Convenience: append a health event.
let appendHealthEvent (ghsBefore: float option) (ghsAfter: float option) (icpAdoption: float) =
    let meta = $"""{{\"icpAdoption\":{sprintf "%.4f" icpAdoption}}}"""
    appendEvent "health" ghsBefore ghsAfter meta

/// Convenience: append a threat event.
let appendThreatEvent (threatLevel: string) (patternCount: int) (ghs: float option) =
    let meta = $"""{{\"threatLevel\":\"{threatLevel}\",\"patternCount\":{patternCount}}}"""
    appendEvent "threat" ghs ghs meta

/// Convenience: append a constitutional check event.
let appendConstitutionalEvent (invariantId: string) (passed: bool) (score: float) =
    let passedStr = if passed then "true" else "false"
    let meta = $"""{{\"invariantId\":\"{invariantId}\",\"passed\":{passedStr},\"score\":{sprintf "%.4f" score}}}"""
    appendEvent "constitutional" None None meta

// ─────────────────────────────────────────────────────────────────────────────
// Query operations (read-only, no mutations)
// ─────────────────────────────────────────────────────────────────────────────

/// Query events by type, ordered by timestamp descending.
let queryByType (eventType: string) (limit: int) : EvolutionEvent list =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- $"""
            SELECT event_id, event_type, ghs_before, ghs_after, delta, metadata, timestamp
            FROM evolution_events
            WHERE event_type = $1
            ORDER BY timestamp DESC
            LIMIT {limit}
        """
        let p = new DuckDB.NET.Data.DuckDBParameter() in p.Value <- box eventType; cmd.Parameters.Add(p) |> ignore
        use reader = cmd.ExecuteReader()
        [ while reader.Read() do
            yield {
                EventId = reader.GetString(0)
                EventType = reader.GetString(1)
                GhsBefore = if reader.IsDBNull(2) then None else Some (reader.GetDouble(2))
                GhsAfter = if reader.IsDBNull(3) then None else Some (reader.GetDouble(3))
                Delta = if reader.IsDBNull(4) then None else Some (reader.GetDouble(4))
                Metadata = reader.GetString(5)
                Timestamp = DateTimeOffset(reader.GetDateTime(6), TimeSpan.Zero)
            }
        ]
    with _ -> []

/// Query events within a date range.
let queryByDateRange (since: DateTimeOffset) (until: DateTimeOffset) : EvolutionEvent list =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            SELECT event_id, event_type, ghs_before, ghs_after, delta, metadata, timestamp
            FROM evolution_events
            WHERE timestamp >= $1 AND timestamp <= $2
            ORDER BY timestamp ASC
        """
        let p1 = new DuckDB.NET.Data.DuckDBParameter() in p1.Value <- box (since.UtcDateTime); cmd.Parameters.Add(p1) |> ignore
        let p2 = new DuckDB.NET.Data.DuckDBParameter() in p2.Value <- box (until.UtcDateTime); cmd.Parameters.Add(p2) |> ignore
        use reader = cmd.ExecuteReader()
        [ while reader.Read() do
            yield {
                EventId = reader.GetString(0)
                EventType = reader.GetString(1)
                GhsBefore = if reader.IsDBNull(2) then None else Some (reader.GetDouble(2))
                GhsAfter = if reader.IsDBNull(3) then None else Some (reader.GetDouble(3))
                Delta = if reader.IsDBNull(4) then None else Some (reader.GetDouble(4))
                Metadata = reader.GetString(5)
                Timestamp = DateTimeOffset(reader.GetDateTime(6), TimeSpan.Zero)
            }
        ]
    with _ -> []

/// Compute GHS velocity (change per day) over recent events.
let computeVelocity (windowDays: int) : float =
    try
        let since = DateTimeOffset.UtcNow.AddDays(float -windowDays)
        let events = queryByDateRange since DateTimeOffset.UtcNow
        let deltas = events |> List.choose (fun e -> e.Delta)
        if deltas.IsEmpty then 0.0
        else
            let totalDelta = deltas |> List.sum
            totalDelta / float windowDays
    with _ -> 0.0

/// Get total event count.
let getEventCount () : int =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT COUNT(*) FROM evolution_events"
        cmd.ExecuteScalar() :?> int64 |> int
    with _ -> 0

/// Export full lineage as a list of events (oldest first).
let exportLineage () : EvolutionEvent list =
    try
        use conn = openDb ()
        createSchema conn
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            SELECT event_id, event_type, ghs_before, ghs_after, delta, metadata, timestamp
            FROM evolution_events
            ORDER BY timestamp ASC
        """
        use reader = cmd.ExecuteReader()
        [ while reader.Read() do
            yield {
                EventId = reader.GetString(0)
                EventType = reader.GetString(1)
                GhsBefore = if reader.IsDBNull(2) then None else Some (reader.GetDouble(2))
                GhsAfter = if reader.IsDBNull(3) then None else Some (reader.GetDouble(3))
                Delta = if reader.IsDBNull(4) then None else Some (reader.GetDouble(4))
                Metadata = reader.GetString(5)
                Timestamp = DateTimeOffset(reader.GetDateTime(6), TimeSpan.Zero)
            }
        ]
    with _ -> []
