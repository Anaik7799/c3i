#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// CEPAF COCKPIT INTEGRATION (TEST MANAGER + DUCKDB ANALYTICS)
// Version: 2.0.0
// =========================================================================================

#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: Dapper"
#r "nuget: DuckDB.NET.Data.Full"

open System
open System.IO
open Microsoft.Data.Sqlite
open Dapper
open DuckDB.NET.Data

// --- CONFIGURATION ---
let sqlitePath = "data/kms/test_manager.db"
let duckdbPath = "data/kms/telemetry.duckdb"

// --- TYPES ---
type TestRun = {
    Id: string
    Name: string
    Status: string
    StartTime: string
    DurationMs: int64
}

type LogEntry = {
    Timestamp: DateTime
    Level: string
    Component: string
    Message: string
}

// --- DATA ACCESS ---

let getRecentRuns () =
    use conn = new SqliteConnection(sprintf "Data Source=%s" sqlitePath)
    conn.Open()
    conn.Query<TestRun>("""
        SELECT e.Id, d.Name, e.Verdict as Status, e.StartTime, 
               (julianday(e.EndTime) - julianday(e.StartTime)) * 86400000 as DurationMs
        FROM test_executions e
        JOIN test_definitions d ON e.DefId = d.Id
        ORDER BY e.StartTime DESC
        LIMIT 5
    ")

let getRunLogs (runId: string) =
    use conn = new DuckDBConnection(sprintf "Data Source=%s" duckdbPath)
    conn.Open()
    // Querying the proposed DuckDB schema
    // Note: Assuming table exists. Implementation of table creation is in separate script.
    try
        conn.Query<LogEntry>("""
            SELECT ts as Timestamp, level as Level, source_component as Component, log_data as Message
            FROM telemetry_signals 
            WHERE execution_id = $1
            ORDER BY ts ASC
            LIMIT 50
        """, [| runId |])
    with _ -> 
        Seq.empty // Return empty if table doesn't exist yet

// --- TUI COMPONENTS ---

let renderTestPanel () =
    printfn "\n \u001b[36m--- RECENT VERIFICATION RUNS ---[0m"
    printfn " ID             SUITE           STATUS    DURATION"
    printfn " -------------- --------------- --------- --------"
    
    let runs = getRecentRuns()
    for run in runs do
        let color = if run.Status = "pass" then "\u001b[32m" else "\u001b[31m"
        printfn " %-14s %-15s %s%-9s\u001b[0m %dms" 
            (run.Id.Substring(0, 8) + "...") 
            (if run.Name.Length > 15 then run.Name.Substring(0, 12) + "..." else run.Name)
            color run.Status run.DurationMs

// --- INTEGRATION ENTRYPOINT ---

// This script is meant to be called by the main fractal-tui.fsx or run standalone for testing
renderTestPanel()
