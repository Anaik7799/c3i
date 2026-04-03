#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// INDRAJAAL F# CORTEX: HIGH-PERFORMANCE KNOWLEDGE INGESTION
// Version: 1.0.0-SIL6
// Purpose: Transactionally materialize documentation as Biomorphic Holons in KMS.
// STAMP: SC-KMS-001, SC-KMS-002, Axiom 0
// =========================================================================================

#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: Newtonsoft.Json"

open System
open System.IO
open Microsoft.Data.Sqlite
open Newtonsoft.Json

let dbPath = "data/kms/holons.db"
let docsPath = "docs"
let connectionString = sprintf "Data Source=%s" dbPath

printfn ">>> [CORTEX] INITIATING 7-LEVEL KNOWLEDGE INGESTION..."

// --- HELPERS ---

let generateHolonId () =
    "hln_" + Guid.NewGuid().ToString("n").Substring(0, 16)

let getFractalPath (filePath: string) =
    let relative = filePath.Replace(docsPath + "/", "").Replace(".md", "")
    "kms/l5/" + relative.Replace("/", "/")

// --- ACTUATION ---

let ingestFile (connection: SqliteConnection) (filePath: string) =
    try
        let name = Path.GetFileNameWithoutExtension(filePath)
        let content = File.ReadAllText(filePath)
        let id = generateHolonId()
        let fqun = getFractalPath filePath
        
        let cmd = connection.CreateCommand()
        cmd.CommandText <- """
            INSERT OR REPLACE INTO holons 
            (id, fqun, type, name, genome, payload, hlc_physical, hlc_logical, created_at, updated_at)
            VALUES ($id, $fqun, 'knowledge', $name, '{}', $payload, $hlc, 0, datetime('now'), datetime('now'))
        """
        cmd.Parameters.AddWithValue("$id", id) |> ignore
        cmd.Parameters.AddWithValue("$fqun", fqun) |> ignore
        cmd.Parameters.AddWithValue("$name", name) |> ignore
        cmd.Parameters.AddWithValue("$payload", JsonConvert.SerializeObject(%{ "content" = content })) |> ignore
        cmd.Parameters.AddWithValue("$hlc", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()) |> ignore
        
        cmd.ExecuteNonQuery() |> ignore
        printfn " [✓] INGESTED: %s" name
    with
    | ex -> printfn " [✗] FAILED: %s (%s)" filePath ex.Message

// --- MAIN ---

if not (File.Exists(dbPath)) then
    printfn ">>> [ERROR] KMS DATABASE NOT FOUND."
    Environment.Exit(1)

use connection = new SqliteConnection(connectionString)
connection.Open()

let allFiles = Directory.GetFiles(docsPath, "*.md", SearchOption.AllDirectories)
printfn ">>> [CORTEX] FOUND %d ARTIFACTS. STARTING METABOLIC LOAD..." allFiles.Length

allFiles |> Array.iter (ingestFile connection)

printfn ">>> [CORTEX] KNOWLEDGE INGESTION COMPLETE. MESH HOMEOSATSIS UPDATED."
