#!/usr/bin/env dotnet fsi
/// SMRITI Code Ingestor - AI-Powered Code to Zettelkasten Converter
///
/// Ingests Elixir (.ex) and F# (.fs, .fsx) code files into SMRITI
///
/// Usage:
///   dotnet fsi SmritiCodeIngestor.fsx ingest <path> [--max N] [--cluster NAME] [--ext ex|fs]
///   dotnet fsi SmritiCodeIngestor.fsx status
///
/// STAMP: SC-SMRITI-CODE-001 to SC-SMRITI-CODE-020

#r "nuget: Microsoft.Data.Sqlite, 9.0.0"
#r "nuget: Dapper, 2.1.35"

open System
open System.IO
open System.Net.Http
open System.Text
open System.Text.Json
open System.Security.Cryptography
open System.Text.RegularExpressions
open Microsoft.Data.Sqlite
open Dapper

// ============================================================================
// Configuration
// ============================================================================

type Config = {
    SqlitePath: string
    OpenRouterKey: string
    OpenRouterModel: string
    UseAI: bool
}

let config = {
    SqlitePath =
        Environment.GetEnvironmentVariable("SMRITI_DB_PATH")
        |> Option.ofObj
        |> Option.defaultValue "data/kms/smriti.db"
    OpenRouterKey =
        Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        |> Option.ofObj
        |> Option.defaultValue ""
    OpenRouterModel = "anthropic/claude-3-haiku"
    UseAI = not (String.IsNullOrEmpty(Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")))
}

// ============================================================================
// Database Types
// ============================================================================

[<CLIMutable>]
type DbHolon = {
    holon_uuid: string
    title: string
    content: string
    tags: string
    entropy: float
    level: string
    decay_rate: string
    inserted_at: string
    updated_at: string
    content_hash: string
    cluster: string
}

// ============================================================================
// Utilities
// ============================================================================

let computeHash (content: string) : string =
    use sha256 = SHA256.Create()
    let bytes = Encoding.UTF8.GetBytes(content)
    let hashBytes = sha256.ComputeHash(bytes)
    BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant()

let createConnection () =
    let connStr = $"Data Source={config.SqlitePath};Mode=ReadWrite"
    new SqliteConnection(connStr)

// ============================================================================
// Code Analysis (Non-AI)
// ============================================================================

let extractElixirModule (content: string) : string option =
    let m = Regex.Match(content, @"defmodule\s+([\w\.]+)")
    if m.Success then Some m.Groups.[1].Value else None

let extractFSharpModule (content: string) : string option =
    let m = Regex.Match(content, @"module\s+([\w\.]+)")
    if m.Success then Some m.Groups.[1].Value else None

let extractElixirFunctions (content: string) : string list =
    Regex.Matches(content, @"def\s+(\w+)")
    |> Seq.cast<Match>
    |> Seq.map (fun m -> m.Groups.[1].Value)
    |> Seq.distinct
    |> Seq.truncate 10
    |> Seq.toList

let extractFSharpFunctions (content: string) : string list =
    Regex.Matches(content, @"let\s+(\w+)")
    |> Seq.cast<Match>
    |> Seq.map (fun m -> m.Groups.[1].Value)
    |> Seq.filter (fun f -> not (f.StartsWith("_")))
    |> Seq.distinct
    |> Seq.truncate 10
    |> Seq.toList

let extractModuleDoc (content: string) : string option =
    // Elixir @moduledoc - look for doc strings
    let elixirDocPattern = "@moduledoc\\s+\"\"\""
    let elixirDoc = Regex.Match(content, elixirDocPattern)
    if elixirDoc.Success then
        // Extract text after @moduledoc """
        let startIdx = elixirDoc.Index + elixirDoc.Length
        let endIdx = content.IndexOf("\"\"\"", startIdx)
        if endIdx > startIdx then
            let docText = content.Substring(startIdx, min (endIdx - startIdx) 200).Trim()
            Some docText
        else None
    else
        // F# /// comments at top
        let lines = content.Split('\n') |> Array.filter (fun l -> l.TrimStart().StartsWith("///"))
        if lines.Length > 0 then
            let docText = lines |> Array.map (fun l -> l.Replace("///", "").Trim()) |> String.concat " "
            Some (docText.Substring(0, min 200 docText.Length))
        else
            None

let detectCodeTags (content: string) (ext: string) : string list =
    let baseTags =
        match ext with
        | ".ex" | ".exs" -> ["elixir"; "beam"]
        | ".fs" | ".fsx" -> ["fsharp"; "dotnet"]
        | _ -> []

    let domainTags =
        [
            if content.Contains("defmodule Indrajaal.Alarms") || content.Contains("Alarms") then "alarms"
            if content.Contains("defmodule Indrajaal.Access") || content.Contains("Access") then "access_control"
            if content.Contains("defmodule Indrajaal.Devices") || content.Contains("Devices") then "devices"
            if content.Contains("GenServer") || content.Contains("Agent") then "otp"
            if content.Contains("LiveView") || content.Contains("LiveComponent") then "liveview"
            if content.Contains("Ash.Resource") || content.Contains("Ash.Domain") then "ash"
            if content.Contains("Ecto") || content.Contains("changeset") then "ecto"
            if content.Contains("Zenoh") || content.Contains("zenoh") then "zenoh"
            if content.Contains("Telemetry") || content.Contains("telemetry") then "telemetry"
            if content.Contains("Guardian") || content.Contains("guardian") then "guardian"
            if content.Contains("Sentinel") || content.Contains("sentinel") then "sentinel"
            if content.Contains("Prajna") || content.Contains("prajna") then "prajna"
            if content.Contains("test") || content.Contains("Test") then "testing"
            if content.Contains("STAMP") || content.Contains("SC-") then "safety"
        ]

    baseTags @ domainTags |> List.distinct

let classifyCodeLevel (content: string) (functions: string list) : string =
    let lineCount = content.Split('\n').Length
    let funcCount = functions.Length

    if lineCount < 50 && funcCount <= 3 then "atomic"
    elif lineCount < 200 && funcCount <= 10 then "molecular"
    elif lineCount < 500 then "organism"
    else "ecosystem"

// ============================================================================
// AI Extraction for Code
// ============================================================================

let extractCodeWithAI (content: string) (filePath: string) (ext: string) : Async<Result<{| Title: string; Summary: string; Tags: string list; Level: string |}, string>> =
    async {
        if not config.UseAI then
            return Error "AI not configured"
        else
            try
                use client = new HttpClient()
                client.Timeout <- TimeSpan.FromSeconds(30.0)
                client.DefaultRequestHeaders.Add("Authorization", $"Bearer {config.OpenRouterKey}")
                client.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.io")

                let truncated = if content.Length > 4000 then content.Substring(0, 4000) else content
                let lang = match ext with | ".ex" | ".exs" -> "Elixir" | ".fs" | ".fsx" -> "F#" | _ -> "Code"

                let prompt = $"""You are a code analysis expert. Analyze this {lang} code and extract:
1. A semantic title describing what this module/file does (max 80 chars)
2. A 1-2 sentence summary of the code's purpose
3. 3-5 relevant tags (from: elixir, fsharp, ash, phoenix, liveview, ecto, genserver, otp, zenoh, telemetry, testing, safety, access_control, alarms, devices, infrastructure, agents, prajna, sentinel, guardian)
4. The complexity level: atomic (single function/small), molecular (module with few functions), organism (complex module), ecosystem (system-wide)

File: {filePath}
Code:
---
{truncated}
---

Respond with ONLY JSON:
{{"title": "...", "summary": "...", "tags": ["..."], "level": "..."}}"""

                let requestBody = JsonSerializer.Serialize({|
                    model = config.OpenRouterModel
                    messages = [| {| role = "user"; content = prompt |} |]
                    max_tokens = 400
                    temperature = 0.2
                |})

                use httpContent = new StringContent(requestBody, Encoding.UTF8, "application/json")
                let! response = client.PostAsync("https://openrouter.ai/api/v1/chat/completions", httpContent) |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    use doc = JsonDocument.Parse(body)
                    let content = doc.RootElement.GetProperty("choices").[0].GetProperty("message").GetProperty("content").GetString()

                    let cleaned = content.Replace("```json", "").Replace("```", "").Trim()
                    use parsed = JsonDocument.Parse(cleaned)
                    let root = parsed.RootElement

                    let title = root.GetProperty("title").GetString()
                    let summary = root.GetProperty("summary").GetString()
                    let level = root.GetProperty("level").GetString()
                    let tags =
                        root.GetProperty("tags").EnumerateArray()
                        |> Seq.map (fun e -> e.GetString())
                        |> Seq.toList

                    return Ok {| Title = title; Summary = summary; Tags = tags; Level = level |}
                else
                    return Error $"API error: {response.StatusCode}"
            with ex ->
                return Error $"Exception: {ex.Message}"
    }

// ============================================================================
// Ingestion
// ============================================================================

let sanitizeLevel (l: string) (content: string) =
    match l.ToLowerInvariant().Trim() with
    | "atomic" -> "atomic"
    | "molecular" -> "molecular"
    | "organism" -> "organism"
    | "ecosystem" -> "ecosystem"
    | l when l.Contains("atom") -> "atomic"
    | l when l.Contains("molec") -> "molecular"
    | l when l.Contains("organ") -> "organism"
    | l when l.Contains("eco") || l.Contains("system") -> "ecosystem"
    | _ ->
        let lineCount = content.Split('\n').Length
        if lineCount < 50 then "atomic"
        elif lineCount < 200 then "molecular"
        elif lineCount < 500 then "organism"
        else "ecosystem"

let ingestCodeFile (filePath: string) (cluster: string) : Async<Result<string, string>> =
    async {
        if not (File.Exists filePath) then
            return Error $"File not found: {filePath}"
        else
            let content = File.ReadAllText(filePath)
            let contentHash = computeHash content
            let ext = Path.GetExtension(filePath).ToLower()

            use conn = createConnection()
            conn.Open()

            // Check duplicate
            let exists = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons WHERE content_hash = @hash", {| hash = contentHash |})
            if exists > 0 then
                return Error "Already exists (duplicate hash)"
            else
                // Try AI extraction first
                let! aiResult = extractCodeWithAI content filePath ext

                let title, summary, tags, level =
                    match aiResult with
                    | Ok extracted ->
                        printfn "  [AI] %s" extracted.Title
                        extracted.Title, extracted.Summary, extracted.Tags, sanitizeLevel extracted.Level content
                    | Error msg ->
                        printfn "  [Fallback] %s" msg
                        // Fallback to regex extraction
                        let moduleName =
                            match ext with
                            | ".ex" | ".exs" -> extractElixirModule content
                            | ".fs" | ".fsx" -> extractFSharpModule content
                            | _ -> None
                            |> Option.defaultValue (Path.GetFileNameWithoutExtension(filePath))

                        let functions =
                            match ext with
                            | ".ex" | ".exs" -> extractElixirFunctions content
                            | ".fs" | ".fsx" -> extractFSharpFunctions content
                            | _ -> []

                        let detectedTags = detectCodeTags content ext
                        let detectedLevel = classifyCodeLevel content functions
                        let doc = extractModuleDoc content |> Option.defaultValue ""

                        moduleName, doc, detectedTags, detectedLevel

                let holonId = Guid.NewGuid().ToString()
                let now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
                let fileInfo = FileInfo(filePath)
                let age = (DateTime.UtcNow - fileInfo.LastWriteTimeUtc).TotalDays
                let entropy = min 1.0 (age / 365.0)  // Code ages slower than docs
                let fullContent = if String.IsNullOrEmpty summary then content else $"## Summary\n\n{summary}\n\n---\n\n```{ext.TrimStart('.')}\n{content}\n```"

                let sql = """
                    INSERT INTO holons (holon_uuid, title, content, tags, entropy, level, decay_rate, inserted_at, updated_at, content_hash, cluster)
                    VALUES (@uuid, @title, @content, @tags, @entropy, @level, 'slow', @now, @now, @hash, @cluster)
                """

                conn.Execute(sql, {|
                    uuid = holonId
                    title = title
                    content = fullContent
                    tags = String.Join(",", tags)
                    entropy = entropy
                    level = level
                    now = now
                    hash = contentHash
                    cluster = cluster
                |}) |> ignore

                return Ok holonId
    }

let ingestCodeDirectory (path: string) (maxFiles: int) (cluster: string) (extensions: string list) =
    async {
        let fullPath = if Path.IsPathRooted(path) then path else Path.Combine(Environment.CurrentDirectory, path)

        if not (Directory.Exists fullPath) then
            printfn "[Error] Directory not found: %s" fullPath
        else
            let files =
                extensions
                |> List.collect (fun ext ->
                    Directory.GetFiles(fullPath, $"*{ext}", SearchOption.AllDirectories) |> Array.toList)
                |> List.truncate maxFiles

            printfn "\n=== SMRITI Code Ingestion ==="
            printfn "Database: %s" config.SqlitePath
            printfn "AI Enabled: %b" config.UseAI
            printfn "Files: %d (max %d)" files.Length maxFiles
            printfn "Extensions: %s" (String.Join(", ", extensions))
            printfn "Cluster: %s" cluster
            printfn ""

            let mutable ingested = 0
            let mutable skipped = 0
            let mutable errors = 0

            for file in files do
                let relativePath = file.Replace(fullPath, "").TrimStart('/', '\\')
                printfn "Processing: %s" relativePath
                let! result = ingestCodeFile file cluster
                match result with
                | Ok uuid ->
                    printfn "  [+] Ingested: %s" (uuid.Substring(0, 8))
                    ingested <- ingested + 1
                | Error msg ->
                    if msg.Contains("duplicate") then
                        printfn "  [~] Skipped: duplicate"
                        skipped <- skipped + 1
                    else
                        printfn "  [!] Error: %s" msg
                        errors <- errors + 1

            printfn "\n=== Summary ==="
            printfn "Ingested: %d" ingested
            printfn "Skipped:  %d" skipped
            printfn "Errors:   %d" errors
    }

// ============================================================================
// Status
// ============================================================================

let showStatus () =
    use conn = createConnection()
    conn.Open()

    let total = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons")
    let codeHolons = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons WHERE tags LIKE '%elixir%' OR tags LIKE '%fsharp%'")

    printfn "\n=== SMRITI Code Status ==="
    printfn "Database: %s" config.SqlitePath
    printfn "Total Holons: %d" total
    printfn "Code Holons: %d" codeHolons
    printfn "AI Available: %b" config.UseAI

// ============================================================================
// Main
// ============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1

match args with
| [| "status" |] -> showStatus()
| [| "ingest"; path |] -> ingestCodeDirectory path 50 "code" [".ex"; ".exs"] |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n |] -> ingestCodeDirectory path (int n) "code" [".ex"; ".exs"] |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n; "--cluster"; c |] -> ingestCodeDirectory path (int n) c [".ex"; ".exs"] |> Async.RunSynchronously
| [| "ingest"; path; "--cluster"; c |] -> ingestCodeDirectory path 50 c [".ex"; ".exs"] |> Async.RunSynchronously
| [| "ingest"; path; "--ext"; "fs" |] -> ingestCodeDirectory path 50 "fsharp" [".fs"; ".fsx"] |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n; "--ext"; "fs" |] -> ingestCodeDirectory path (int n) "fsharp" [".fs"; ".fsx"] |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n; "--cluster"; c; "--ext"; "fs" |] -> ingestCodeDirectory path (int n) c [".fs"; ".fsx"] |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n; "--ext"; "ex" |] -> ingestCodeDirectory path (int n) "elixir" [".ex"; ".exs"] |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n; "--cluster"; c; "--ext"; "ex" |] -> ingestCodeDirectory path (int n) c [".ex"; ".exs"] |> Async.RunSynchronously
| _ ->
    printfn "SMRITI Code Ingestor - AI-Powered Code to Zettelkasten Converter"
    printfn ""
    printfn "Usage:"
    printfn "  dotnet fsi SmritiCodeIngestor.fsx status"
    printfn "  dotnet fsi SmritiCodeIngestor.fsx ingest <path> [--max N] [--cluster NAME] [--ext ex|fs]"
    printfn ""
    printfn "Examples:"
    printfn "  dotnet fsi SmritiCodeIngestor.fsx ingest lib/indrajaal --max 100 --cluster elixir-core"
    printfn "  dotnet fsi SmritiCodeIngestor.fsx ingest lib/cepaf --max 50 --cluster fsharp --ext fs"
