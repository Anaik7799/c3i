/// Shared Database Paths for KMS
///
/// WHAT: Centralized paths for SQLite and DuckDB databases using UHI naming.
/// WHY: Both Elixir and F# must access the same database files.
/// CONSTRAINTS:
///   - SC-KMS-002 (cross-runtime access)
///   - SC-DBNAME-001 (UHI naming system)
///   - SC-DBNAME-002 (deterministic path resolution)
///
/// UHI for KMS: ex:l3:kms:srv:{instance}
/// Database paths follow:
///   - data/holons/ex/l3/kms/{instance}/state.sqlite (OLTP)
///   - data/holons/ex/l3/kms/{instance}/analytics.duckdb (OLAP)
///   - data/holons/ex/l3/kms/{instance}/history.duckdb (History)
module Cepaf.Knowledge.SharedPaths

open System
open System.IO
open Cepaf.Holon.DatabasePath

/// Default KMS UHI components
let private kmsUHI =
    createUHI Elixir L3 Kms Srv "main"

/// Get the KMS data directory using UHI-based path
let getDataDir () =
    // SC-DBNAME-001: Use UHI-based path resolution
    let dir = holonDir kmsUHI

    // Check for environment override (cluster node isolation)
    let dataDir =
        match Environment.GetEnvironmentVariable("KMS_DATA_DIR") with
        | null | "" -> dir
        | customDir -> customDir

    if not (Directory.Exists(dataDir)) then
        Directory.CreateDirectory(dataDir) |> ignore

    dataDir

/// SQLite database path for OLTP operations (state.sqlite)
let getSqlitePath () =
    // SC-DBNAME-001: Use FQDN resolution
    let fqdn = createFQDN kmsUHI State
    resolve fqdn

/// DuckDB database path for OLAP analytics (analytics.duckdb)
let getDuckDBPath () =
    // SC-DBNAME-001: Use FQDN resolution
    let fqdn = createFQDN kmsUHI Analytics
    resolve fqdn

/// DuckDB database path for history (history.duckdb)
let getHistoryPath () =
    let fqdn = createFQDN kmsUHI History
    resolve fqdn

/// Archive directory for Parquet files
let getArchiveDir () =
    let archiveDir = Path.Combine(getDataDir(), "archive")
    if not (Directory.Exists(archiveDir)) then
        Directory.CreateDirectory(archiveDir) |> ignore
    archiveDir

/// SQLite connection string
let getSqliteConnectionString () =
    $"Data Source={getSqlitePath()}"

/// DuckDB connection string
let getDuckDBConnectionString () =
    $"Data Source={getDuckDBPath()}"

/// Check if databases are initialized
let areDatabasesInitialized () =
    File.Exists(getSqlitePath()) && File.Exists(getDuckDBPath())

/// STAMP Constraints for cross-runtime access
module StampConstraints =
    [<Literal>]
    let SC_KMS_001 = "SQLite + DuckDB only - no ETS/DETS/Khepri"

    [<Literal>]
    let SC_KMS_002 = "Cross-runtime access - Elixir and F# share databases"

    [<Literal>]
    let SC_KMS_003 = "Portable holons - directory copy = full backup"

    [<Literal>]
    let SC_KMS_004 = "OODA cycle <100ms on SQLite hot path"
