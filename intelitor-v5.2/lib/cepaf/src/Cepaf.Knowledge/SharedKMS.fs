/// Shared KMS Access for F# Cockpit
///
/// WHAT: F# access to shared SQLite/DuckDB databases.
/// WHY: Enable cross-runtime knowledge management.
/// CONSTRAINTS: SC-KMS-002 (cross-runtime access)
///
/// This module provides F# access to the same databases that
/// the Elixir KMS modules use, enabling bidirectional data flow.
module Cepaf.Knowledge.SharedKMS

open System
open System.Data
open Microsoft.Data.Sqlite
open DuckDB.NET.Data
open Dapper
open System.Net.Http
open System.Text
open System.Text.Json
open Cepaf.Knowledge.SharedPaths

// ============================================================================
// Types (compatible with Elixir KMS)
// ============================================================================

/// Oracle response structure
type OracleResponse = {
    Query: string
    Response: string
}

/// API Response wrapper
type ApiResponse<'T> = {
    Status: string
    Data: 'T
    Message: string option
}

/// Holon type enumeration
type HolonType =
    | Knowledge
    | Process
    | Agent
    | Artifact
    | Index

    override this.ToString() =
        match this with
        | Knowledge -> "knowledge"
        | Process -> "process"
        | Agent -> "agent"
        | Artifact -> "artifact"
        | Index -> "index"

    static member Parse(s: string) =
        match s.ToLowerInvariant() with
        | "knowledge" -> Knowledge
        | "process" -> Process
        | "agent" -> Agent
        | "artifact" -> Artifact
        | "index" -> Index
        | _ -> Knowledge

/// Vital signs for bio-inspired health
type VitalSigns = {
    Health: float
    Stress: float
    Energy: float
}

/// Holon record (compatible with Elixir schema)
type Holon = {
    Id: string
    Fqun: string
    Type: string
    Name: string
    ParentId: string option
    Genome: string
    VitalSigns: string
    Membrane: string
    Payload: string
    HlcPhysical: int64
    HlcLogical: int64
    CreatedAt: string
    UpdatedAt: string
}

/// Holon event record
type HolonEvent = {
    Id: int64
    HolonId: string
    EventType: string
    Payload: string
    HlcPhysical: int64
    HlcLogical: int64
    AgentId: string option
    CreatedAt: string
}

// ============================================================================
// SQLite Access (OLTP)
// ============================================================================

/// Get SQLite connection
let private getSqliteConnection () =
    let conn = new SqliteConnection(getSqliteConnectionString())
    conn.Open()
    conn

/// Get a holon by ID
let getHolon (holonId: string) : Holon option =
    use conn = getSqliteConnection()
    let sql = "SELECT * FROM holons WHERE id = @Id"
    let result = conn.QueryFirstOrDefault<Holon>(sql, {| Id = holonId |})
    if isNull (box result) then None else Some result

/// Get a holon by FQUN
let getHolonByFqun (fqun: string) : Holon option =
    use conn = getSqliteConnection()
    let sql = "SELECT * FROM holons WHERE fqun = @Fqun"
    let result = conn.QueryFirstOrDefault<Holon>(sql, {| Fqun = fqun |})
    if isNull (box result) then None else Some result

/// List all holons
let listHolons (holonType: HolonType option) (limit: int) : Holon seq =
    use conn = getSqliteConnection()
    match holonType with
    | Some t ->
        let sql = "SELECT * FROM holons WHERE type = @Type ORDER BY updated_at DESC LIMIT @Limit"
        conn.Query<Holon>(sql, {| Type = t.ToString(); Limit = limit |})
    | None ->
        let sql = "SELECT * FROM holons ORDER BY updated_at DESC LIMIT @Limit"
        conn.Query<Holon>(sql, {| Limit = limit |})

/// Create a new holon
let createHolon (name: string) (holonType: HolonType) (payload: string) (parentId: string option) : Holon =
    use conn = getSqliteConnection()

    let holonId = sprintf "hln_%s" (Guid.NewGuid().ToString("N").Substring(0, 13))
    let now = DateTime.UtcNow.ToString("o")
    let hlcPhysical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L
    let fqun = sprintf "kms/l3/%s/default/%s@fsharp#%s" (holonType.ToString()) name holonId

    let holon = {
        Id = holonId
        Fqun = fqun
        Type = holonType.ToString()
        Name = name
        ParentId = parentId
        Genome = """{"schema_version":"1.0.0"}"""
        VitalSigns = """{"health":1.0,"stress":0.0,"energy":1.0}"""
        Membrane = "{}"
        Payload = payload
        HlcPhysical = hlcPhysical
        HlcLogical = 0L
        CreatedAt = now
        UpdatedAt = now
    }

    let sql = """
        INSERT INTO holons (id, fqun, type, name, parent_id, genome, vital_signs, membrane, payload, hlc_physical, hlc_logical, created_at, updated_at)
        VALUES (@Id, @Fqun, @Type, @Name, @ParentId, @Genome, @VitalSigns, @Membrane, @Payload, @HlcPhysical, @HlcLogical, @CreatedAt, @UpdatedAt)
    """

    conn.Execute(sql, holon) |> ignore
    holon

/// Update holon vital signs
let updateVitalSigns (holonId: string) (vitalSigns: VitalSigns) : bool =
    use conn = getSqliteConnection()
    let now = DateTime.UtcNow.ToString("o")
    let hlcPhysical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L
    let vitalsJson = sprintf """{"health":%f,"stress":%f,"energy":%f}""" vitalSigns.Health vitalSigns.Stress vitalSigns.Energy

    let sql = """
        UPDATE holons
        SET vital_signs = @VitalSigns, hlc_physical = @HlcPhysical, updated_at = @UpdatedAt
        WHERE id = @Id
    """

    let result = conn.Execute(sql, {|
        Id = holonId
        VitalSigns = vitalsJson
        HlcPhysical = hlcPhysical
        UpdatedAt = now
    |})

    result > 0

/// Log an event for a holon
let logEvent (holonId: string) (eventType: string) (payload: string) : unit =
    use conn = getSqliteConnection()
    let hlcPhysical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L

    let sql = """
        INSERT INTO holon_events (holon_id, event_type, payload, hlc_physical, hlc_logical)
        VALUES (@HolonId, @EventType, @Payload, @HlcPhysical, 0)
    """

    conn.Execute(sql, {|
        HolonId = holonId
        EventType = eventType
        Payload = payload
        HlcPhysical = hlcPhysical
    |}) |> ignore

/// Full-text search using FTS5
let search (query: string) (limit: int) : Holon seq =
    use conn = getSqliteConnection()
    // Sanitize query for FTS5
    let safeQuery = query.Replace("\"", "").Replace("'", "")

    let sql = """
        SELECT h.* FROM holons h
        JOIN holons_fts fts ON h.id = fts.id
        WHERE holons_fts MATCH @Query
        ORDER BY rank
        LIMIT @Limit
    """

    conn.Query<Holon>(sql, {| Query = safeQuery; Limit = limit |})

/// Get children of a holon
let getChildren (holonId: string) : Holon seq =
    use conn = getSqliteConnection()
    let sql = "SELECT * FROM holons WHERE parent_id = @ParentId ORDER BY name"
    conn.Query<Holon>(sql, {| ParentId = holonId |})

// ============================================================================
// DuckDB Access (OLAP)
// ============================================================================

/// Get DuckDB connection with SQLite attached
let private getDuckDBConnection () =
    let conn = new DuckDBConnection(getDuckDBConnectionString())
    conn.Open()

    // Attach SQLite database
    let attachSql = $"ATTACH IF NOT EXISTS '{getSqlitePath()}' AS holons_db (TYPE SQLITE, READ_ONLY)"
    use cmd = conn.CreateCommand()
    cmd.CommandText <- attachSql
    cmd.ExecuteNonQuery() |> ignore

    conn

/// Health report summary
type HealthReport = {
    Type: string
    Count: int64
    AvgHealth: float
    AvgStress: float
    AvgEnergy: float
    MinHealth: float
    MaxHealth: float
}

/// Get health report aggregated by type
let getHealthReport () : HealthReport seq =
    use conn = getDuckDBConnection()

    let sql = """
        SELECT
            type,
            COUNT(*) as count,
            AVG(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as avg_health,
            AVG(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE)) as avg_stress,
            AVG(CAST(json_extract(vital_signs, '$.energy') AS DOUBLE)) as avg_energy,
            MIN(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as min_health,
            MAX(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as max_health
        FROM holons_db.holons
        GROUP BY type
        ORDER BY type
    """

    conn.Query<HealthReport>(sql)

/// Entropy report entry
type EntropyEntry = {
    Id: string
    Fqun: string
    Name: string
    Type: string
    Health: float
    Stress: float
    Entropy: float
    UpdatedAt: string
}

/// Get holons with high entropy (stale/degraded)
let getEntropyReport (threshold: float) : EntropyEntry seq =
    use conn = getDuckDBConnection()

    let sql = $"""
        WITH entropy_calc AS (
            SELECT
                id,
                fqun,
                name,
                type,
                CAST(json_extract(vital_signs, '$.health') AS DOUBLE) as health,
                CAST(json_extract(vital_signs, '$.stress') AS DOUBLE) as stress,
                updated_at,
                (1.0 - COALESCE(CAST(json_extract(vital_signs, '$.health') AS DOUBLE), 0.5)) +
                COALESCE(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE), 0.0) +
                LEAST(1.0, (julianday('now') - julianday(updated_at)) / 30.0) as entropy
            FROM holons_db.holons
        )
        SELECT id, fqun, name, type, health, stress, entropy, updated_at
        FROM entropy_calc
        WHERE entropy >= {threshold}
        ORDER BY entropy DESC
        LIMIT 100
    """

    conn.Query<EntropyEntry>(sql)

/// Event statistics entry
type EventStats = {
    Day: string
    EventType: string
    EventCount: int64
}

/// Get event statistics for the last N days
let getEventStats (days: int) : EventStats seq =
    use conn = getDuckDBConnection()
    let cutoff = DateTimeOffset.UtcNow.AddDays(float -days).ToUnixTimeMilliseconds() * 1000L

    let sql = $"""
        SELECT
            strftime(datetime(hlc_physical/1000000, 'unixepoch'), '%%Y-%%m-%%d') as day,
            event_type,
            COUNT(*) as event_count
        FROM holons_db.holon_events
        WHERE hlc_physical > {cutoff}
        GROUP BY day, event_type
        ORDER BY day DESC, event_count DESC
    """

    conn.Query<EventStats>(sql)

// ============================================================================
// Oracle (External AI via OpenRouter)
// ============================================================================

/// Default Oracle model (Free)
let DefaultOracleModel = "google/gemini-2.0-flash-lite-preview-02-05:free"

/// Ask the KMS Oracle a question via the Elixir REST API
let askOracle (query: string) (model: string option) (limit: int option) : Async<Result<string, string>> =
    async {
        try
            use client = new HttpClient()
            let baseUrl = Environment.GetEnvironmentVariable("INDRAJAAL_API_BASE_URL") 
                          |> Option.ofObj 
                          |> Option.defaultValue "http://localhost:4000"
            
            let url = $"{baseUrl}/api/kms/oracle"
            
            let payload = {| 
                query = query
                model = model |> Option.toObj
                limit = limit |> Option.toNullable
            |}
            
            let json = JsonSerializer.Serialize(payload)
            let content = new StringContent(json, Encoding.UTF8, "application/json")
            
            let! response = client.PostAsync(url, content) |> Async.AwaitTask
            let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
            
            if response.IsSuccessStatusCode then
                let options = JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase)
                let apiResponse = JsonSerializer.Deserialize<ApiResponse<OracleResponse>>(body, options)
                return Ok apiResponse.Data.Response
            else
                return Error $"API error ({response.StatusCode}): {body}"
        with
        | ex -> return Error $"Exception: {ex.Message}"
    }

// ============================================================================
// Initialization
// ============================================================================

/// Check if databases exist and are accessible
let checkDatabases () : bool =
    try
        use sqliteConn = getSqliteConnection()
        use duckdbConn = getDuckDBConnection()
        true
    with
    | _ -> false

/// Get database status
let getDatabaseStatus () : Map<string, obj> =
    Map.ofList [
        "sqlite_path", box (getSqlitePath())
        "duckdb_path", box (getDuckDBPath())
        "archive_dir", box (getArchiveDir())
        "initialized", box (areDatabasesInitialized())
        "accessible", box (checkDatabases())
    ]
