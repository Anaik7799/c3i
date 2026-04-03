/// Semantic Connector - GraphDB-Inspired Search Integration
///
/// Provides connectors to external search engines and services
/// similar to GraphDB's Elasticsearch and Lucene connectors.
///
/// Key Features:
/// - Full-text search index integration
/// - External SPARQL endpoint federation
/// - Webhook notifications on changes
/// - Batch sync capabilities
///
/// STAMP Constraints:
/// - SC-SEM-060: Connector health check < 5s
/// - SC-SEM-061: Batch sync size configurable
/// - SC-SEM-062: Retry with exponential backoff
///
/// Version: 2.0.0
namespace Cepaf.Smriti.Semantic

open System
open System.Collections.Generic
open System.Net.Http
open System.Text
open System.Text.Json
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared

/// Connector configuration
type ConnectorConfig = {
    /// Connector name
    Name: string
    /// Connector type
    Type: ConnectorType
    /// Endpoint URL
    Endpoint: string
    /// API key or credentials
    ApiKey: string option
    /// Batch size for sync
    BatchSize: int
    /// Retry attempts
    MaxRetries: int
    /// Retry delay in milliseconds
    RetryDelayMs: int
    /// Enabled flag
    Enabled: bool
}

/// Connector status
type ConnectorStatus =
    | Connected
    | Disconnected
    | Error of string
    | Syncing of progress: float

/// Search result from external connector
type ExternalSearchResult = {
    Uri: string
    Score: float
    Snippet: string option
    Metadata: Map<string, string>
}

/// Sync event for webhooks
type SyncEvent = {
    EventType: string  // "created", "updated", "deleted"
    TripleId: int64
    Subject: string
    Predicate: string
    Object: string
    Timestamp: DateTime
}

/// Full-Text Search Connector (Elasticsearch/Lucene style)
module FullTextConnector =

    /// Initialize full-text search schema in SQLite
    /// Uses SQLite FTS5 as a lightweight alternative to external search
    let initFtsSchema (conn: SqliteConnection) =
        let sql = """
            -- FTS5 virtual table for full-text search
            CREATE VIRTUAL TABLE IF NOT EXISTS triples_fts USING fts5(
                subject,
                predicate,
                object,
                content='triples',
                content_rowid='id'
            );

            -- Triggers to keep FTS in sync
            CREATE TRIGGER IF NOT EXISTS triples_fts_insert AFTER INSERT ON triples BEGIN
                INSERT INTO triples_fts(rowid, subject, predicate, object)
                VALUES (new.id, new.subject, new.predicate, new.object);
            END;

            CREATE TRIGGER IF NOT EXISTS triples_fts_delete AFTER DELETE ON triples BEGIN
                INSERT INTO triples_fts(triples_fts, rowid, subject, predicate, object)
                VALUES ('delete', old.id, old.subject, old.predicate, old.object);
            END;

            CREATE TRIGGER IF NOT EXISTS triples_fts_update AFTER UPDATE ON triples BEGIN
                INSERT INTO triples_fts(triples_fts, rowid, subject, predicate, object)
                VALUES ('delete', old.id, old.subject, old.predicate, old.object);
                INSERT INTO triples_fts(rowid, subject, predicate, object)
                VALUES (new.id, new.subject, new.predicate, new.object);
            END;

            -- Search history for analytics
            CREATE TABLE IF NOT EXISTS search_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                query TEXT NOT NULL,
                results_count INTEGER,
                execution_time_ms INTEGER,
                searched_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery() |> ignore

    /// Perform full-text search
    let search (conn: SqliteConnection) (query: string) (limit: int) : ExternalSearchResult list =
        let stopwatch = System.Diagnostics.Stopwatch.StartNew()

        let sql = """
            SELECT t.id, t.subject, t.predicate, t.object,
                   bm25(triples_fts) as score,
                   snippet(triples_fts, 2, '<mark>', '</mark>', '...', 32) as snippet
            FROM triples_fts
            INNER JOIN triples t ON triples_fts.rowid = t.id
            WHERE triples_fts MATCH @query
            ORDER BY bm25(triples_fts)
            LIMIT @limit
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@query", query) |> ignore
        cmd.Parameters.AddWithValue("@limit", limit) |> ignore

        use reader = cmd.ExecuteReader()
        let results = ResizeArray<ExternalSearchResult>()

        while reader.Read() do
            results.Add({
                Uri = reader.GetString(1)  // subject as URI
                Score = reader.GetDouble(4)
                Snippet =
                    if reader.IsDBNull(5) then None
                    else Some (reader.GetString(5))
                Metadata = Map.ofList [
                    ("predicate", reader.GetString(2))
                    ("object", reader.GetString(3))
                ]
            })

        stopwatch.Stop()

        // Log search for analytics
        let logSql = "INSERT INTO search_history (query, results_count, execution_time_ms) VALUES (@q, @c, @t)"
        use logCmd = new SqliteCommand(logSql, conn)
        logCmd.Parameters.AddWithValue("@q", query) |> ignore
        logCmd.Parameters.AddWithValue("@c", results.Count) |> ignore
        logCmd.Parameters.AddWithValue("@t", stopwatch.ElapsedMilliseconds) |> ignore
        logCmd.ExecuteNonQuery() |> ignore

        results |> Seq.toList

    /// Rebuild FTS index (for maintenance)
    let rebuildIndex (conn: SqliteConnection) =
        let sql = """
            INSERT INTO triples_fts(triples_fts) VALUES('rebuild');
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery()


/// External SPARQL Endpoint Federation
module SparqlFederation =

    /// Execute SPARQL query against remote endpoint
    let queryRemote (endpoint: string) (sparql: string) (apiKey: string option) =
        async {
            use client = new HttpClient()

            // Set headers
            client.DefaultRequestHeaders.Add("Accept", "application/sparql-results+json")
            match apiKey with
            | Some key -> client.DefaultRequestHeaders.Add("Authorization", $"Bearer {key}")
            | None -> ()

            // Build request
            let content = new FormUrlEncodedContent([
                KeyValuePair("query", sparql)
            ])

            try
                let! response = client.PostAsync(endpoint, content) |> Async.AwaitTask
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                if response.IsSuccessStatusCode then
                    return Result.Ok body
                else
                    return Result.Error $"SPARQL endpoint returned {response.StatusCode}: {body}"
            with ex ->
                return Result.Error $"Failed to query SPARQL endpoint: {ex.Message}"
        }

    /// Parse SPARQL JSON results into bindings
    let parseResults (json: string) : Map<string, string> list =
        try
            use doc = JsonDocument.Parse(json)
            let root = doc.RootElement

            let bindings = root.GetProperty("results").GetProperty("bindings")

            bindings.EnumerateArray()
            |> Seq.map (fun binding ->
                binding.EnumerateObject()
                |> Seq.map (fun prop ->
                    let value = prop.Value.GetProperty("value").GetString()
                    (prop.Name, value)
                )
                |> Map.ofSeq
            )
            |> Seq.toList
        with _ ->
            []

    /// Convert remote bindings to local triples
    let bindingsToTriples (bindings: Map<string, string> list) : Triple list =
        bindings
        |> List.choose (fun binding ->
            match Map.tryFind "s" binding, Map.tryFind "p" binding, Map.tryFind "o" binding with
            | Some s, Some p, Some o ->
                Some {
                    Subject = IriTerm (FullIRI s)
                    Predicate = FullIRI p
                    Object =
                        if o.StartsWith("http://") || o.StartsWith("https://") then
                            IriTerm (FullIRI o)
                        else
                            LiteralTerm { Value = o; Language = None; Datatype = None }
                }
            | _ -> None
        )


/// Webhook Notification System
module WebhookConnector =

    /// Webhook subscription
    type WebhookSubscription = {
        Id: string
        Url: string
        Events: string list  // ["created", "updated", "deleted"]
        Secret: string option
        Enabled: bool
        CreatedAt: DateTime
    }

    /// Initialize webhook schema
    let initSchema (conn: SqliteConnection) =
        let sql = """
            CREATE TABLE IF NOT EXISTS webhooks (
                id TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                events TEXT NOT NULL,  -- JSON array
                secret TEXT,
                enabled INTEGER DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                last_triggered TEXT,
                failure_count INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS webhook_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                webhook_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                response_code INTEGER,
                response_body TEXT,
                triggered_at TEXT NOT NULL DEFAULT (datetime('now')),

                FOREIGN KEY (webhook_id) REFERENCES webhooks(id)
            );
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery() |> ignore

    /// Register a webhook
    let register (conn: SqliteConnection) (subscription: WebhookSubscription) =
        let sql = """
            INSERT INTO webhooks (id, url, events, secret, enabled)
            VALUES (@id, @url, @events, @secret, @enabled)
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@id", subscription.Id) |> ignore
        cmd.Parameters.AddWithValue("@url", subscription.Url) |> ignore
        cmd.Parameters.AddWithValue("@events", JsonSerializer.Serialize(subscription.Events)) |> ignore
        cmd.Parameters.AddWithValue("@secret", subscription.Secret |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("@enabled", if subscription.Enabled then 1 else 0) |> ignore
        cmd.ExecuteNonQuery()

    /// Trigger webhook for an event
    let trigger (conn: SqliteConnection) (event: SyncEvent) =
        async {
            // Get matching webhooks
            let sql = "SELECT id, url, secret FROM webhooks WHERE enabled = 1"
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let webhooks = ResizeArray<string * string * string option>()
            while reader.Read() do
                let secret = if reader.IsDBNull(2) then None else Some (reader.GetString(2))
                webhooks.Add((reader.GetString(0), reader.GetString(1), secret))

            // Send to each webhook
            use client = new HttpClient()
            let payload = JsonSerializer.Serialize(event)

            for (webhookId, url, secret) in webhooks do
                try
                    let content = new StringContent(payload, Encoding.UTF8, "application/json")

                    // Add signature if secret exists
                    match secret with
                    | Some s when not (String.IsNullOrEmpty(s)) ->
                        let hmac = System.Security.Cryptography.HMACSHA256.HashData(
                            Encoding.UTF8.GetBytes(s),
                            Encoding.UTF8.GetBytes(payload)
                        )
                        let signature = Convert.ToBase64String(hmac)
                        content.Headers.Add("X-Webhook-Signature", signature)
                    | _ -> ()

                    let! response = client.PostAsync(url, content) |> Async.AwaitTask
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                    // Log result
                    let logSql = """
                        INSERT INTO webhook_log (webhook_id, event_type, payload, response_code, response_body)
                        VALUES (@wid, @event, @payload, @code, @body)
                    """
                    use logCmd = new SqliteCommand(logSql, conn)
                    logCmd.Parameters.AddWithValue("@wid", webhookId) |> ignore
                    logCmd.Parameters.AddWithValue("@event", event.EventType) |> ignore
                    logCmd.Parameters.AddWithValue("@payload", payload) |> ignore
                    logCmd.Parameters.AddWithValue("@code", int response.StatusCode) |> ignore
                    logCmd.Parameters.AddWithValue("@body", body) |> ignore
                    logCmd.ExecuteNonQuery() |> ignore
                with _ -> ()
        }


/// Connector Manager
module ConnectorManager =

    /// All registered connectors
    let private connectors = System.Collections.Generic.Dictionary<string, ConnectorConfig>()

    /// Register a connector
    let register (config: ConnectorConfig) =
        connectors.[config.Name] <- config

    /// Get connector status
    let getStatus (name: string) : ConnectorStatus =
        match connectors.TryGetValue(name) with
        | true, config when not config.Enabled -> Disconnected
        | true, config ->
            // Simple health check based on type
            try
                match config.Type with
                | ConnectorType.Elasticsearch
                | ConnectorType.Lucene ->
                    // Would do actual health check here
                    Connected
                | ConnectorType.SparqlEndpoint ->
                    Connected
                | ConnectorType.Webhook ->
                    Connected
                | _ -> Disconnected
            with ex ->
                Error ex.Message
        | false, _ -> Disconnected

    /// List all connectors
    let listConnectors () =
        connectors
        |> Seq.map (fun kv -> (kv.Key, getStatus kv.Key))
        |> Seq.toList

    /// Execute retry with exponential backoff
    let retryWithBackoff (config: ConnectorConfig) (action: unit -> Async<Result<'T, string>>) =
        async {
            let mutable attempt = 0
            let mutable result = Result.Error "Not attempted"

            while attempt < config.MaxRetries do
                match! action () with
                | Result.Ok value ->
                    result <- Result.Ok value
                    attempt <- config.MaxRetries  // Exit loop
                | Result.Error e ->
                    attempt <- attempt + 1
                    if attempt < config.MaxRetries then
                        let delay = config.RetryDelayMs * (pown 2 attempt)
                        do! Async.Sleep delay
                    result <- Result.Error e

            return result
        }


/// OntoRefine-style Data Transformation (GraphDB-inspired)
module DataTransformer =

    /// Transformation rule
    type TransformRule = {
        SourcePattern: string  // Regex pattern
        TargetTemplate: string // IRI template
        Transformations: (string * (string -> string)) list  // Column transforms
    }

    /// Apply transformation to text data
    let transform (rules: TransformRule list) (data: string list list) (headers: string list) : Triple list =
        let triples = ResizeArray<Triple>()

        for row in data do
            // Build row dictionary
            let rowDict =
                List.zip headers row
                |> Map.ofList

            for rule in rules do
                // Check if pattern matches
                let re = System.Text.RegularExpressions.Regex(rule.SourcePattern)
                let allCols = String.Join(" ", row)

                if re.IsMatch(allCols) then
                    // Apply transformations
                    let mutable template = rule.TargetTemplate
                    for (colName, transform) in rule.Transformations do
                        match Map.tryFind colName rowDict with
                        | Some value ->
                            let transformed = transform value
                            template <- template.Replace($"{{{colName}}}", transformed)
                        | None -> ()

                    // Generate triple
                    let parts = template.Split([|' '|], StringSplitOptions.RemoveEmptyEntries)
                    if parts.Length >= 3 then
                        triples.Add({
                            Subject = IriTerm (FullIRI parts.[0])
                            Predicate = FullIRI parts.[1]
                            Object =
                                if parts.[2].StartsWith("http") then
                                    IriTerm (FullIRI parts.[2])
                                else
                                    LiteralTerm { Value = parts.[2]; Language = None; Datatype = None }
                        })

        triples |> Seq.toList

    /// Import CSV and transform to triples
    let importCsv (csvPath: string) (rules: TransformRule list) : Triple list =
        let lines = System.IO.File.ReadAllLines(csvPath)
        if lines.Length < 2 then []
        else
            let headers = lines.[0].Split(',') |> Array.toList
            let data =
                lines.[1..]
                |> Array.map (fun line -> line.Split(',') |> Array.toList)
                |> Array.toList
            transform rules data headers

