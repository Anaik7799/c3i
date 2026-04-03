#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// INDRAJAAL BIOMORPHIC EVOLUTION: KMS SUBSTRATE RE-MATERIALIZATION
// Version: 1.1.0-SIL6
// Purpose: Transactionally upgrade schema to support 'task' type across all substrates
// =========================================================================================

#r "nuget: Microsoft.Data.Sqlite"

open Microsoft.Data.Sqlite
open System.IO

let upgradeDb dbPath =
    printfn ">>> [CORTEX] UPGRADING SUBSTRATE: %s" dbPath
    if not (File.Exists(dbPath)) then
        printfn " [!] WARNING: Substrate not found at %s. Skipping." dbPath
    else
        let connectionString = sprintf "Data Source=%s" dbPath
        use connection = new SqliteConnection(connectionString)
        connection.Open()
        
        use transaction = connection.BeginTransaction()
        try
            let sql = """
                PRAGMA foreign_keys=OFF;
                ALTER TABLE holons RENAME TO holons_old;
                CREATE TABLE holons (
                  id TEXT PRIMARY KEY,
                  fqun TEXT UNIQUE NOT NULL,
                  type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index','task')),
                  name TEXT NOT NULL,
                  parent_id TEXT REFERENCES holons(id),
                  genome TEXT NOT NULL DEFAULT '{}',
                  vital_signs TEXT DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
                  membrane TEXT DEFAULT '{}',
                  payload TEXT NOT NULL DEFAULT '{}',
                  hlc_physical INTEGER NOT NULL,
                  hlc_logical INTEGER NOT NULL,
                  created_at TEXT DEFAULT (datetime('now')),
                  updated_at TEXT DEFAULT (datetime('now'))
                );
                INSERT INTO holons SELECT * FROM holons_old;
                DROP TABLE holons_old;
            """
            let cmd = connection.CreateCommand()
            cmd.CommandText <- sql
            cmd.Transaction <- transaction
            cmd.ExecuteNonQuery() |> ignore
            
            transaction.Commit()
            printfn " [✓] SUBSTRATE RE-MATERIALIZED: %s" dbPath
        with
        | ex ->
            transaction.Rollback()
            printfn " [✗] FATAL ERROR ON %s: %s" dbPath ex.Message

// --- MAIN ---

let substrates = [ "data/kms/core.db"; "data/kms/holons.db" ]
substrates |> List.iter upgradeDb

printfn ">>> [CORTEX] UNIVERSAL SUBSTRATE REALIGNMENT COMPLETE."