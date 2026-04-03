/// Core types for the Zenoh Database Bridge
/// SC-DBPROXY-001: Type-safe database access
module Cepaf.Database.Types

open System

/// Database type enumeration
type DbType =
    | DuckDB
    | SQLite

/// Query operation types
type QueryType =
    | Select
    | Insert
    | Update
    | Delete
    | Open
    | Close
    | BeginTxn
    | CommitTxn
    | RollbackTxn
    | Savepoint
    | ReleaseSavepoint

/// Transaction isolation levels (SC-TXN-004)
type IsolationLevel =
    | ReadUncommitted
    | ReadCommitted
    | RepeatableRead
    | Serializable

/// Transaction state machine (SC-TXN-001)
type TransactionState =
    | Pending
    | Active
    | Committed
    | RolledBack
    | Failed

/// Database request from Elixir client (SC-BRIDGE-001: FIFO ordering)
type DatabaseRequest = {
    RequestId: string
    DbType: DbType
    QueryType: QueryType
    Sql: string
    Params: obj list
    TransactionId: string option
    Timestamp: DateTime
}

/// Database response to Elixir client (SC-BRIDGE-006: correlation)
type DatabaseResponse = {
    RequestId: string
    Success: bool
    Result: obj option
    Error: string option
    RowsAffected: int option
    Timestamp: DateTime
}

/// Transaction record (SC-TXN-001: ACID)
type Transaction = {
    TxnId: string
    State: TransactionState
    IsolationLevel: IsolationLevel
    Operations: DatabaseRequest list
    StartTime: DateTime
    ConnectionId: string option
    Savepoints: string list
}

/// Connection pool configuration (SC-CONC-002)
type PoolConfig = {
    MaxConnections: int
    MinConnections: int
    AcquireTimeout: TimeSpan
    IdleTimeout: TimeSpan
    ValidationQuery: string option
}

/// Default pool configurations
module PoolDefaults =
    let duckDBPool = {
        MaxConnections = 10
        MinConnections = 2
        AcquireTimeout = TimeSpan.FromSeconds(5.0)
        IdleTimeout = TimeSpan.FromMinutes(5.0)
        ValidationQuery = Some "SELECT 1"
    }

    let sqlitePool = {
        MaxConnections = 5
        MinConnections = 1
        AcquireTimeout = TimeSpan.FromSeconds(5.0)
        IdleTimeout = TimeSpan.FromMinutes(5.0)
        ValidationQuery = Some "SELECT 1"
    }

/// Service configuration
type DatabaseServiceConfig = {
    DuckDBPath: string
    SQLitePath: string
    DuckDBPoolConfig: PoolConfig
    SQLitePoolConfig: PoolConfig
    ZenohEndpoint: string
    RequestTopic: string
    ResponseTopic: string
}

/// Default service configuration
/// SC-DBNAME-001: UHI-based paths for all databases
module ServiceDefaults =
    // UHI: ex:l3:kms:srv:main
    let config = {
        DuckDBPath = "data/holons/ex/l3/kms/main/analytics.duckdb"  // ex:l3:kms:srv:main:analytics
        SQLitePath = "data/holons/ex/l3/kms/main/state.sqlite"     // ex:l3:kms:srv:main:state
        DuckDBPoolConfig = PoolDefaults.duckDBPool
        SQLitePoolConfig = PoolDefaults.sqlitePool
        ZenohEndpoint = "tcp/localhost:7447"
        RequestTopic = "indrajaal/db/+/request"
        ResponseTopic = "indrajaal/db/+/response"
    }

/// Telemetry event types
type TelemetryEvent =
    | RequestReceived of DatabaseRequest
    | RequestCompleted of DatabaseResponse * TimeSpan
    | ConnectionAcquired of DbType * TimeSpan
    | ConnectionReleased of DbType
    | TransactionStarted of string * IsolationLevel
    | TransactionCompleted of string * TransactionState
    | PoolExhausted of DbType
    | LockContention of string * TimeSpan
    | ErrorOccurred of exn

/// Result type for operations
type DbResult<'T> = Result<'T, string>

/// Parse request from JSON
module RequestParser =
    open System.Text.Json

    let parseDbType (s: string) =
        match s.ToLower() with
        | "duckdb" -> Some DuckDB
        | "sqlite" -> Some SQLite
        | _ -> None

    let parseQueryType (s: string) =
        match s.ToLower() with
        | "select" | "query" -> Some Select
        | "insert" -> Some Insert
        | "update" -> Some Update
        | "delete" -> Some Delete
        | "open" -> Some Open
        | "close" -> Some Close
        | "begin" | "begintxn" -> Some BeginTxn
        | "commit" | "committxn" -> Some CommitTxn
        | "rollback" | "rollbacktxn" -> Some RollbackTxn
        | "savepoint" -> Some Savepoint
        | "release" | "releasesavepoint" -> Some ReleaseSavepoint
        | _ -> None

    let parseIsolationLevel (s: string) =
        match s.ToLower() with
        | "readuncommitted" | "read_uncommitted" -> ReadUncommitted
        | "readcommitted" | "read_committed" -> ReadCommitted
        | "repeatableread" | "repeatable_read" -> RepeatableRead
        | "serializable" -> Serializable
        | _ -> Serializable // Default to strictest

    let parseRequest (json: string) : DbResult<DatabaseRequest> =
        try
            let doc = JsonDocument.Parse(json)
            let root = doc.RootElement

            let mutable propEl = Unchecked.defaultof<JsonElement>

            let requestId =
                if root.TryGetProperty("request_id", &propEl) then
                    root.GetProperty("request_id").GetString()
                else
                    Guid.NewGuid().ToString("N")

            let dbType =
                root.GetProperty("db_type").GetString()
                |> parseDbType
                |> Option.defaultValue DuckDB

            let queryType =
                root.GetProperty("type").GetString()
                |> parseQueryType
                |> Option.defaultValue Select

            let sql =
                if root.TryGetProperty("sql", &propEl) then
                    root.GetProperty("sql").GetString()
                else
                    ""

            let txnId =
                if root.TryGetProperty("transaction_id", &propEl) then
                    Some (root.GetProperty("transaction_id").GetString())
                else
                    None

            Ok {
                RequestId = requestId
                DbType = dbType
                QueryType = queryType
                Sql = sql
                Params = []
                TransactionId = txnId
                Timestamp = DateTime.UtcNow
            }
        with ex ->
            Error $"Failed to parse request: {ex.Message}"

/// Serialize response to JSON
module ResponseSerializer =
    open System.Text.Json

    let serialize (response: DatabaseResponse) : string =
        let options = JsonSerializerOptions(WriteIndented = false)
        let status = if response.Success then "ok" else "error"

        let result =
            match response.Result with
            | Some r -> JsonSerializer.Serialize(r, options)
            | None -> "null"

        let error =
            match response.Error with
            | Some e -> $"\"{e}\""
            | None -> "null"

        $"""{{
            "request_id": "{response.RequestId}",
            "status": "{status}",
            "result": {result},
            "error": {error},
            "rows_affected": {response.RowsAffected |> Option.defaultValue 0},
            "timestamp": "{response.Timestamp:O}"
        }}"""
