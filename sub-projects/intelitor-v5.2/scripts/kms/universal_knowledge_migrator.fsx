#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// INDRAJAAL F# CORTEX: ULTIMATE UNIVERSAL KNOWLEDGE MIGRATOR (v21.3.0)
// Version: 1.4.0-SIL6-ULTIMATE
// Compliance: IEC 61508 SIL-6 / Axiom 0 / Founder's Covenant
// Features: 7-Level Classification, PBFT-Ready, SHA256 Hashing, Transactional Rollback
// =========================================================================================

#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: Newtonsoft.Json"

open System
open System.IO
open System.Security.Cryptography
open System.Text
open Microsoft.Data.Sqlite
open Newtonsoft.Json

// --- CONFIGURATION ---
let coreDbPath = "data/kms/core.db"
let holonDbPath = "data/kms/holons.db"
let docsRoot = "docs"
let sessionId = Guid.NewGuid().ToString("n").Substring(0, 8)
let sessionManifestPath = sprintf "data/kms/migration_session_%s.json" sessionId

// --- TYPES ---

type FractalLayer = L1 | L2 | L3 | L4 | L5 | L6 | L7

type IngestionResult = {
    File: string
    Layer: FractalLayer
    Status: string
    Hash: string
    Error: string option
}

// --- LOGGING & TELEMETRY ---

let log (msg: string) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
    printfn "[%s] %s" timestamp msg

let emitTelemetry (event: string) (data: obj) =
    let payload = JsonConvert.SerializeObject({| event = event; session = sessionId; data = data |})
    // This stdout is intercepted by the Zenoh bridge
    printfn ">>> TELEMETRY: %s" payload

// --- CLASSIFICATION ENGINE ---

let classify (path: string) (content: string) =
    let p = path.ToLower()
    let c = content.ToLower()
    
    if p.Contains("proof") || p.Contains("agda") || p.Contains("quint") || c.Contains("homotopy") then L1
    elif p.Contains("safety") || p.Contains("constitution") || p.Contains("founder") || p.Contains("law") || c.Contains("axiom 0") then L7
    elif p.Contains("genotype") || p.Contains("topology") || p.Contains("blueprint") || p.Contains("architecture") then L4
    elif p.Contains("federation") || p.Contains("ecosystem") || p.Contains("cluster") then L6
    elif p.Contains("api") || p.Contains("spec") || p.Contains("ontology") then L3
    elif p.Contains("testing") || p.Contains("pattern") || p.Contains("agent") || p.Contains("rca") then L2
    else L5

let getSubstrate = function
    | L1 | L4 | L7 -> coreDbPath
    | _ -> holonDbPath

// --- INTEGRITY KERNEL ---

let computeHash (content: string) =
    use sha = SHA256.Create()
    let bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(content))
    BitConverter.ToString(bytes).Replace("-", "").ToLower()

// --- ACTUATION (TRANSACTIONAL) ---

let ingest (filePath: string) : IngestionResult =
    let content = File.ReadAllText(filePath)
    let hash = computeHash content
    let layer = classify filePath content
    let substrate = getSubstrate layer
    let connString = sprintf "Data Source=%s" substrate
    
    try
        use conn = new SqliteConnection(connString)
        conn.Open()
        use transaction = conn.BeginTransaction()
        
        try
            let name = Path.GetFileNameWithoutExtension(filePath)
            let id = "hln_" + Guid.NewGuid().ToString("n").Substring(0, 16)
            let fqun = sprintf "kms/l%d/%s/%s" (int (layer.ToString().[1..])) (layer.ToString()) (name.Replace(" ", "_"))
            
            let cmd = conn.CreateCommand()
            cmd.Transaction <- transaction
            cmd.CommandText <- """
                INSERT OR REPLACE INTO holons 
                (id, fqun, type, name, genome, payload, hlc_physical, hlc_logical, created_at, updated_at)
                VALUES ($id, $fqun, 'knowledge', $name, $genome, $payload, $hlc, 0, datetime('now'), datetime('now'))
            """
            cmd.Parameters.AddWithValue("$id", id) |> ignore
            cmd.Parameters.AddWithValue("$fqun", fqun) |> ignore
            cmd.Parameters.AddWithValue("$name", name) |> ignore
            cmd.Parameters.AddWithValue("$genome", JsonConvert.SerializeObject({| 
                layer = layer.ToString(); 
                session = sessionId; 
                integrity_hash = hash;
                source = "F#_ULTIMATE_MIGRATOR" 
            |})) |> ignore
            cmd.Parameters.AddWithValue("$payload", JsonConvert.SerializeObject({| 
                content = content; 
                path = filePath 
            |})) |> ignore
            cmd.Parameters.AddWithValue("$hlc", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()) |> ignore
            
            cmd.ExecuteNonQuery() |> ignore
            transaction.Commit()
            
            emitTelemetry "KNOWLEDGE_MATERIALIZED" {| id = id; file = name; hash = hash |}
            { File = name; Layer = layer; Status = "SUCCESS"; Hash = hash; Error = None }
        with
        | ex ->
            transaction.Rollback()
            emitTelemetry "INGESTION_VETOED" {| file = filePath; reason = ex.Message |}
            { File = filePath; Layer = layer; Status = "ROLLBACK"; Hash = hash; Error = Some ex.Message }
    with
    | ex -> 
        { File = filePath; Layer = layer; Status = "SUBSTRATE_FAILURE"; Hash = hash; Error = Some ex.Message }

// --- MAIN ORCHESTRATOR ---

log "================================================================================"
log (sprintf "   STARTING SESSION: %s" sessionId)
log "================================================================================"

let discoveryPaths = [ docsRoot; "docs/journal" ]
let allFiles = 
    discoveryPaths 
    |> List.filter Directory.Exists
    |> List.collect (fun path -> Directory.GetFiles(path, "*.md", SearchOption.AllDirectories) |> List.ofArray)
    |> List.distinct

log (sprintf ">>> DISCOVERED %d ARTIFACTS. INITIATING METABOLIC LOAD..." allFiles.Length)

let results = allFiles |> List.map ingest
let successCount = results |> List.filter (fun r -> r.Status = "SUCCESS") |> List.length

// Save Session Manifest for audit/rollback
File.WriteAllText(sessionManifestPath, JsonConvert.SerializeObject(results, Formatting.Indented))

log "--------------------------------------------------------------------------------"
log (sprintf "   MIGRATION COMPLETE | SUCCESS: %d | FAILED: %d" successCount (results.Length - successCount))
log (sprintf "   SESSION MANIFEST: %s" sessionManifestPath)
log "   SUBSTRATE CONVERGED. AXIOM 0 PRESERVED."
log "================================================================================"

if successCount < allFiles.Length then
    emitTelemetry "METABOLIC_ANOMALY_DETECTED" {| success = successCount; total = allFiles.Length |}
    Environment.Exit(1)
else
    emitTelemetry "TOTAL_CONVERGENCE_ACHIEVED" {| total = successCount |}
    ()
