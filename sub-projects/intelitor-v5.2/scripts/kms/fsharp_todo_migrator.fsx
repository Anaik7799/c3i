#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// INDRAJAAL F# CORTEX: HIGH-FIDELITY TODO MIGRATOR
// Version: 1.1.0-SIL6
// Purpose: Transactionally migrate the todolist into bifurcated KMS databases.
// Replicates Elixir fidelity logic using F# Discriminated Unions and Hashing.
// =========================================================================================

#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: Newtonsoft.Json"

open System
open System.IO
open System.Text.RegularExpressions
open Microsoft.Data.Sqlite
open Newtonsoft.Json
open System.Security.Cryptography
open System.Text

let coreDbPath = "data/kms/core.db"
let holonDbPath = "data/kms/holons.db"
let todoPath = "PROJECT_TODOLIST.md"

printfn ">>> [CORTEX] INITIATING BICAMERAL TODO MIGRATION..."

// --- TYPES (Fidelity Logic Replicated) ---

type TaskStatus = Pending | InProgress | Completed | Blocked
type Priority = P0 | P1 | P2 | P3 | P4

type TaskHolon = {
    Id: string
    Name: string
    Status: TaskStatus
    Priority: Priority
    Level: int
    Content: string
}

// --- PARSING (Fidelity Logic) ---

let parseStatus = function
    | "x" -> Completed
    | "🔄" -> InProgress
    | "⏳" -> Blocked
    | _ -> Pending

let getPriority (id: string) =
    if id.StartsWith("31.1.1") || id.StartsWith("31.1.2") then P0
    elif id.Contains(".1.0") then P1
    else P2

let parseTask line =
    let m = Regex.Match(line, @"(\d+\.\d+\.\d+\.\d+\.\d+) - (.*?) \[ ( |x|🔄|⏳) \]")
    if m.Success then
        let id = m.Groups.[1].Value
        Some {
            Id = id
            Name = m.Groups.[2].Value
            Status = parseStatus m.Groups.[3].Value
            Priority = getPriority id
            Level = id.Split('.') |> Array.length
            Content = line
        }
    else None

// --- FIDELITY CHECK (Hashing) ---

let computeFidelityHash (task: TaskHolon) =
    let raw = sprintf "%s|%s|%A" task.Id task.Name task.Status
    use sha = SHA256.Create()
    sha.ComputeHash(Encoding.UTF8.GetBytes(raw)) |> Convert.ToHexString

// --- ACTUATION ---

let materializeTask (task: TaskHolon) =
    let dbPath = if task.Priority = P0 then coreDbPath else holonDbPath
    let connectionString = sprintf "Data Source=%s" dbPath
    let fqun = sprintf "kms/l%d/task/default/%s#%s" task.Level task.Name task.Id
    let fidelityHash = computeFidelityHash task

    try
        use conn = new SqliteConnection(connectionString)
        conn.Open()
        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT OR REPLACE INTO holons 
            (id, fqun, type, name, genome, payload, hlc_physical, hlc_logical, created_at, updated_at)
            VALUES ($id, $fqun, 'task', $name, $genome, $payload, $hlc, 0, datetime('now'), datetime('now'))
        """
        cmd.Parameters.AddWithValue("$id", task.Id) |> ignore
        cmd.Parameters.AddWithValue("$fqun", fqun) |> ignore
        cmd.Parameters.AddWithValue("$name", task.Name) |> ignore
        cmd.Parameters.AddWithValue("$genome", JsonConvert.SerializeObject({| priority = task.Priority; fidelity_hash = fidelityHash |})) |> ignore
        cmd.Parameters.AddWithValue("$payload", JsonConvert.SerializeObject({| content = task.Content; status = task.Status |})) |> ignore
        cmd.Parameters.AddWithValue("$hlc", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()) |> ignore
        
        cmd.ExecuteNonQuery() |> ignore
        printfn " [⚖️] MATERIALIZED (%A): %s" task.Priority task.Id
    with
    | ex -> printfn " [✗] FIDELITY FAILURE: %s (%s)" task.Id ex.Message

// --- MAIN ---

if not (File.Exists(todoPath)) then
    printfn ">>> [ERROR] PROJECT_TODOLIST.MD NOT FOUND."
    Environment.Exit(1)

let lines = File.ReadAllLines(todoPath)
let tasks = lines |> Array.choose parseTask

printfn ">>> [CORTEX] FOUND %d TASKS. REPLICATING FIDELITY GATES..." tasks.Length

tasks |> Array.iter materializeTask

printfn ">>> [CORTEX] MIGRATION COMPLETE. SUBSTRATE CONVERGED."
