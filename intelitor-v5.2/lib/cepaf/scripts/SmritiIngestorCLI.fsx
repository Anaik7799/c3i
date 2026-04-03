#!/usr/bin/env dotnet fsi
/// SMRITI Ingestor CLI - AI-Powered Document to Zettelkasten Converter
///
/// Usage:
///   dotnet fsi SmritiIngestorCLI.fsx status
///   dotnet fsi SmritiIngestorCLI.fsx ingest <path> [--max N] [--cluster NAME]
///   dotnet fsi SmritiIngestorCLI.fsx search <query> [--limit N]
///   dotnet fsi SmritiIngestorCLI.fsx orphans
///   dotnet fsi SmritiIngestorCLI.fsx stale [--threshold N]
///   dotnet fsi SmritiIngestorCLI.fsx entropy
///
/// Environment Variables:
///   OPENROUTER_API_KEY - API key for Claude AI extraction
///   SMRITI_DB_PATH - Path to smriti.db (default: data/kms/smriti.db)

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
    DocsPath: string
    OpenRouterKey: string
    OpenRouterModel: string
    UseAI: bool
}

let config = {
    SqlitePath =
        Environment.GetEnvironmentVariable("SMRITI_DB_PATH")
        |> Option.ofObj
        |> Option.defaultValue "data/kms/smriti.db"
    DocsPath = "docs"
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

[<CLIMutable>]
type DbClusterCount = {
    cluster: string
    cnt: int64
}

[<CLIMutable>]
type DbSearchResult = {
    holon_uuid: string
    title: string
    entropy: float
    level: string
    cluster: string
}

[<CLIMutable>]
type DbOrphan = {
    holon_uuid: string
    title: string
}

[<CLIMutable>]
type DbStaleHolon = {
    holon_uuid: string
    title: string
    entropy: float
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
// AI Extraction (Simplified for FSX)
// ============================================================================

let extractWithAI (content: string) (filePath: string) : Async<Result<{| Title: string; Summary: string; Tags: string list; Level: string |}, string>> =
    async {
        if not config.UseAI then
            return Error "AI not configured"
        else
            try
                use client = new HttpClient()
                client.Timeout <- TimeSpan.FromSeconds(30.0)
                client.DefaultRequestHeaders.Add("Authorization", $"Bearer {config.OpenRouterKey}")
                client.DefaultRequestHeaders.Add("HTTP-Referer", "https://indrajaal.io")

                let truncated = if content.Length > 6000 then content.Substring(0, 6000) else content

                let prompt = $"""You are an expert knowledge manager. Analyze this document and extract:
1. A clear title (max 80 chars)
2. A 2-sentence summary
3. Up to 5 relevant tags
4. The holon level (atomic/molecular/organism/ecosystem)

Document: {filePath}
Content:
---
{truncated}
---

Respond with ONLY JSON:
{{"title": "...", "summary": "...", "tags": ["..."], "level": "..."}}"""

                let requestBody = JsonSerializer.Serialize({|
                    model = config.OpenRouterModel
                    messages = [| {| role = "user"; content = prompt |} |]
                    max_tokens = 500
                    temperature = 0.3
                |})

                use httpContent = new StringContent(requestBody, Encoding.UTF8, "application/json")
                let! response = client.PostAsync("https://openrouter.ai/api/v1/chat/completions", httpContent) |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    use doc = JsonDocument.Parse(body)
                    let content = doc.RootElement.GetProperty("choices").[0].GetProperty("message").GetProperty("content").GetString()

                    // Parse the JSON response
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

let ingestFile (filePath: string) (cluster: string) : Async<Result<string, string>> =
    async {
        if not (File.Exists filePath) then
            return Error $"File not found: {filePath}"
        else
            let content = File.ReadAllText(filePath)
            let contentHash = computeHash content

            use conn = createConnection()
            conn.Open()

            // Check duplicate
            let exists = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons WHERE content_hash = @hash", {| hash = contentHash |})
            if exists > 0 then
                return Error "Already exists (duplicate hash)"
            else
                // Try AI extraction
                let! aiResult = extractWithAI content filePath

                // Validate and sanitize level
                let sanitizeLevel (l: string) =
                    match l.ToLowerInvariant().Trim() with
                    | "atomic" -> "atomic"
                    | "molecular" -> "molecular"
                    | "organism" -> "organism"
                    | "ecosystem" -> "ecosystem"
                    | l when l.Contains("atom") -> "atomic"
                    | l when l.Contains("molec") -> "molecular"
                    | l when l.Contains("organ") -> "organism"
                    | l when l.Contains("eco") || l.Contains("system") -> "ecosystem"
                    | _ -> if content.Length > 10000 then "organism" elif content.Length > 3000 then "molecular" else "atomic"

                let title, summary, tags, level =
                    match aiResult with
                    | Ok extracted ->
                        printfn "  [AI] Extracted: %s" extracted.Title
                        extracted.Title, extracted.Summary, extracted.Tags, sanitizeLevel extracted.Level
                    | Error msg ->
                        printfn "  [Fallback] %s" msg
                        // Fallback extraction
                        let titleRegex = Regex(@"^#\s+(.+)$", RegexOptions.Multiline)
                        let m = titleRegex.Match(content)
                        let title = if m.Success then m.Groups.[1].Value else Path.GetFileNameWithoutExtension(filePath)
                        let level = if content.Length > 10000 then "organism" elif content.Length > 3000 then "molecular" else "atomic"
                        title, "", [], level

                let holonId = Guid.NewGuid().ToString()
                let now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
                let fileInfo = FileInfo(filePath)
                let age = (DateTime.UtcNow - fileInfo.LastWriteTimeUtc).TotalDays
                let entropy = min 1.0 (age / 180.0)
                let fullContent = if String.IsNullOrEmpty summary then content else $"## Summary\n\n{summary}\n\n---\n\n{content}"

                let sql = """
                    INSERT INTO holons (holon_uuid, title, content, tags, entropy, level, decay_rate, inserted_at, updated_at, content_hash, cluster)
                    VALUES (@uuid, @title, @content, @tags, @entropy, @level, 'medium', @now, @now, @hash, @cluster)
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

let ingestDirectory (path: string) (maxFiles: int) (cluster: string) =
    async {
        let fullPath = if Path.IsPathRooted(path) then path else Path.Combine(config.DocsPath, path)

        if not (Directory.Exists fullPath) then
            printfn "[Error] Directory not found: %s" fullPath
        else
            let files = Directory.GetFiles(fullPath, "*.md", SearchOption.AllDirectories) |> Array.truncate maxFiles

            printfn "\n=== SMRITI Ingestion ==="
            printfn "Database: %s" config.SqlitePath
            printfn "AI Enabled: %b" config.UseAI
            printfn "Files: %d (max %d)" files.Length maxFiles
            printfn "Cluster: %s" cluster
            printfn ""

            let mutable ingested = 0
            let mutable skipped = 0
            let mutable errors = 0

            for file in files do
                printfn "Processing: %s" (Path.GetFileName file)
                let! result = ingestFile file cluster
                match result with
                | Ok uuid ->
                    printfn "  [+] Ingested: %s" (uuid.Substring(0, 8))
                    ingested <- ingested + 1
                | Error msg ->
                    if msg.Contains("duplicate") then
                        printfn "  [~] Skipped: %s" msg
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
// Status & Queries
// ============================================================================

let showStatus () =
    use conn = createConnection()
    conn.Open()

    let total = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons")
    let orphans = conn.ExecuteScalar<int>("""
        SELECT COUNT(*) FROM holons h
        WHERE NOT EXISTS (SELECT 1 FROM holon_edges e WHERE e.source_id = h.holon_uuid OR e.target_id = h.holon_uuid)
    """)
    let stale = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons WHERE entropy > 0.6")

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════╗"
    printfn "║              SMRITI STATUS                                     ║"
    printfn "╠══════════════════════════════════════════════════════════════╣"
    printfn "║  Database:      %-40s   ║" config.SqlitePath
    printfn "║  Total Holons:  %-10d                                   ║" total
    printfn "║  Orphans:       %-10d                                   ║" orphans
    printfn "║  Stale:         %-10d                                   ║" stale
    printfn "║  AI Available:  %-10b                                   ║" config.UseAI
    printfn "╠══════════════════════════════════════════════════════════════╣"
    printfn "║  CLUSTERS                                                    ║"

    let clusters = conn.Query<DbClusterCount>(
        "SELECT cluster, COUNT(*) as cnt FROM holons WHERE cluster IS NOT NULL AND cluster != '' GROUP BY cluster"
    )
    for c in clusters do
        printfn "║    %-20s: %5d holons                            ║" c.cluster (int c.cnt)

    printfn "╚══════════════════════════════════════════════════════════════╝"

let search (query: string) (limit: int) =
    use conn = createConnection()
    conn.Open()

    let sql = """
        SELECT h.holon_uuid, h.title, h.entropy, h.level, h.cluster
        FROM holons h
        JOIN holons_fts fts ON fts.rowid = h.rowid
        WHERE holons_fts MATCH @query
        ORDER BY bm25(holons_fts)
        LIMIT @limit
    """

    let results = conn.Query<DbSearchResult>(sql, {| query = query; limit = limit |})

    printfn "\nSearch results for '%s':" query
    printfn "─────────────────────────────────────────────────────────"
    for r in results do
        printfn "[%s] %-50s (%.2f) %s/%s" (r.holon_uuid.Substring(0, 8)) r.title r.entropy r.cluster r.level

let showOrphans () =
    use conn = createConnection()
    conn.Open()

    let orphans = conn.Query<DbOrphan>("""
        SELECT h.holon_uuid, h.title FROM holons h
        WHERE NOT EXISTS (SELECT 1 FROM holon_edges e WHERE e.source_id = h.holon_uuid OR e.target_id = h.holon_uuid)
        ORDER BY h.updated_at DESC
    """)

    printfn "\nOrphan Holons (no links):"
    printfn "─────────────────────────────────────────────────────────"
    for o in orphans do
        printfn "[%s] %s" (o.holon_uuid.Substring(0, 8)) o.title

let showStale (threshold: float) =
    use conn = createConnection()
    conn.Open()

    let stale = conn.Query<DbStaleHolon>(
        "SELECT holon_uuid, title, entropy FROM holons WHERE entropy >= @t ORDER BY entropy DESC",
        {| t = threshold |}
    )

    printfn "\nStale Holons (entropy >= %.2f):" threshold
    printfn "─────────────────────────────────────────────────────────"
    for s in stale do
        printfn "[%s] %.3f  %s" (s.holon_uuid.Substring(0, 8)) s.entropy s.title

let recalculateEntropy () =
    use conn = createConnection()
    conn.Open()

    let affected = conn.Execute("""
        UPDATE holons
        SET entropy = MIN(1.0, CAST((julianday('now') - julianday(updated_at)) AS REAL) / 180.0)
    """)

    printfn "[Entropy] Updated %d holons" affected

// ============================================================================
// Main
// ============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1

match args with
| [| "status" |] -> showStatus()
| [| "ingest"; path |] -> ingestDirectory path 10 "docs" |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n |] -> ingestDirectory path (int n) "docs" |> Async.RunSynchronously
| [| "ingest"; path; "--max"; n; "--cluster"; c |] -> ingestDirectory path (int n) c |> Async.RunSynchronously
| [| "ingest"; path; "--cluster"; c |] -> ingestDirectory path 10 c |> Async.RunSynchronously
| [| "search"; query |] -> search query 10
| [| "search"; query; "--limit"; n |] -> search query (int n)
| [| "orphans" |] -> showOrphans()
| [| "stale" |] -> showStale 0.6
| [| "stale"; "--threshold"; t |] -> showStale (float t)
| [| "entropy" |] -> recalculateEntropy()
| _ ->
    printfn "SMRITI Ingestor CLI - AI-Powered Document to Zettelkasten Converter"
    printfn ""
    printfn "Usage:"
    printfn "  dotnet fsi SmritiIngestorCLI.fsx status"
    printfn "  dotnet fsi SmritiIngestorCLI.fsx ingest <path> [--max N] [--cluster NAME]"
    printfn "  dotnet fsi SmritiIngestorCLI.fsx search <query> [--limit N]"
    printfn "  dotnet fsi SmritiIngestorCLI.fsx orphans"
    printfn "  dotnet fsi SmritiIngestorCLI.fsx stale [--threshold N]"
    printfn "  dotnet fsi SmritiIngestorCLI.fsx entropy"
    printfn ""
    printfn "Environment Variables:"
    printfn "  OPENROUTER_API_KEY - API key for Claude AI extraction"
    printfn "  SMRITI_DB_PATH       - Path to smriti.db (default: data/kms/smriti.db)"
