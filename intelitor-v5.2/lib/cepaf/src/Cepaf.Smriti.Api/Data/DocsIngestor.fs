/// DocsIngestor - AI-Powered Markdown to Zettelkasten Ingestor
///
/// STAMP Constraints:
/// - SC-HOLON-001: SQLite is authoritative holon state
/// - SC-HOLON-017: SHA-256 checksum MUST exist
/// - SC-REG-001: All state changes via append-only register
module Cepaf.Smriti.Api.Data.DocsIngestor

open System
open System.IO
open System.Security.Cryptography
open System.Text
open System.Text.RegularExpressions
open Microsoft.Data.Sqlite
open Dapper
module AI = Cepaf.Smriti.Api.AI.OpenRouterClient

/// Ingestor configuration
type IngestorConfig = {
    SqlitePath: string
    DocsPath: string
    DefaultCluster: string
    UseAI: bool
    AIConfig: AI.OpenRouterConfig option
}

/// Ingestion result
type IngestResult =
    | Success of holon_uuid: string * title: string * aiUsed: bool
    | Skipped of reason: string
    | Error of message: string

/// Default configuration
let defaultConfig () : IngestorConfig =
    let sqlitePath =
        Environment.GetEnvironmentVariable("SMRITI_DB_PATH")
        |> Option.ofObj
        |> Option.defaultValue "data/kms/smriti.db"
    {
        SqlitePath = sqlitePath
        DocsPath = "docs"
        DefaultCluster = "architecture"
        UseAI = true
        AIConfig = Some (AI.defaultConfig())
    }

/// Compute SHA-256 hash of content
let computeHash (content: string) : string =
    use sha256 = SHA256.Create()
    let bytes = Encoding.UTF8.GetBytes(content)
    let hashBytes = sha256.ComputeHash(bytes)
    BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant()

/// Calculate entropy based on file age
let calculateEntropy (fileAge: TimeSpan) : float =
    let maxAgeDays = 180.0
    min 1.0 (fileAge.TotalDays / maxAgeDays)

/// Determine decay rate based on document type
let determineDecayRate (filePath: string) : string =
    let lowerPath = filePath.ToLowerInvariant()
    if lowerPath.Contains("spec") || lowerPath.Contains("standard") then "slow"
    elif lowerPath.Contains("architecture") || lowerPath.Contains("master") then "medium"
    else "fast"

/// Database holon type
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

/// Create database connection
let private createConnection (config: IngestorConfig) =
    let connStr = sprintf "Data Source=%s;Mode=ReadWrite" config.SqlitePath
    new SqliteConnection(connStr)

/// Check if holon exists by content hash
let private holonExists (conn: SqliteConnection) (contentHash: string) : bool =
    let sql = "SELECT COUNT(*) FROM holons WHERE content_hash = @hash"
    let count = conn.ExecuteScalar<int>(sql, {| hash = contentHash |})
    count > 0

/// Ingest a single file
let ingestFile (config: IngestorConfig) (filePath: string) : Async<IngestResult> =
    async {
        if not (File.Exists filePath) then
            return Error (sprintf "File not found: %s" filePath)
        else
            try
                let content = File.ReadAllText(filePath)
                let contentHash = computeHash content
                let fileInfo = FileInfo(filePath)
                let fileAge = DateTime.UtcNow - fileInfo.LastWriteTimeUtc

                use conn = createConnection config
                conn.Open()

                if holonExists conn contentHash then
                    return Skipped "Already exists (duplicate hash)"
                else
                    // Try AI extraction if enabled
                    let! extractResult =
                        if config.UseAI && config.AIConfig.IsSome then
                            AI.extractWithAI config.AIConfig.Value content filePath
                        else
                            async { return Ok (AI.extractFallback content filePath, false) }

                    match extractResult with
                    | Result.Ok (extracted, aiUsed) ->
                        let holonUuid = Guid.NewGuid().ToString()
                        let now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
                        let entropy = calculateEntropy fileAge
                        let tags = String.Join(",", extracted.Tags @ extracted.KeyConcepts)

                        let fullContent =
                            if String.IsNullOrEmpty extracted.Summary then content
                            else sprintf "## Summary\n\n%s\n\n---\n\n%s" extracted.Summary content

                        let sql = "INSERT INTO holons (holon_uuid, title, content, tags, entropy, level, decay_rate, inserted_at, updated_at, content_hash, cluster) VALUES (@uuid, @title, @content, @tags, @entropy, @level, @decay_rate, @inserted_at, @updated_at, @hash, @cluster)"

                        conn.Execute(sql, {|
                            uuid = holonUuid
                            title = extracted.Title
                            content = fullContent
                            tags = tags
                            entropy = entropy
                            level = extracted.Level
                            decay_rate = determineDecayRate filePath
                            inserted_at = now
                            updated_at = now
                            hash = contentHash
                            cluster = config.DefaultCluster
                        |}) |> ignore

                        return Success (holonUuid, extracted.Title, aiUsed)

                    | Result.Error msg ->
                        return Error msg
            with ex ->
                return Error (sprintf "Ingestion failed: %s" ex.Message)
    }

/// Ingest multiple files
let ingestFiles (config: IngestorConfig) (files: string list) : Async<IngestResult list> =
    async {
        let results = ResizeArray<IngestResult>()
        for file in files do
            let! result = ingestFile config file
            results.Add(result)
        return results |> Seq.toList
    }

/// Print ingestion summary
let printSummary (results: IngestResult list) =
    let successes = results |> List.filter (function Success _ -> true | _ -> false)
    let aiSuccesses = results |> List.filter (function Success (_, _, true) -> true | _ -> false)
    let skipped = results |> List.filter (function Skipped _ -> true | _ -> false)
    let errors = results |> List.filter (function Error _ -> true | _ -> false)

    printfn "\n=== Ingestion Summary ==="
    printfn "Ingested: %d (%d via AI)" (List.length successes) (List.length aiSuccesses)
    printfn "Skipped:  %d" (List.length skipped)
    printfn "Errors:   %d" (List.length errors)

    if not (List.isEmpty successes) then
        printfn "\nIngested holons:"
        successes |> List.iter (function
            | Success (uuid, title, ai) ->
                let marker = if ai then "[AI]" else "[  ]"
                printfn "  %s [+] %s - %s" marker (uuid.Substring(0, 8)) title
            | _ -> ())

    if not (List.isEmpty errors) then
        printfn "\nErrors:"
        errors |> List.iter (function
            | Error msg -> printfn "  [!] %s" msg
            | _ -> ())
