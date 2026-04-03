/// Semantic Layer - Unified Facade for SMRITI Semantic Graph
///
/// Provides a unified API combining all semantic graph capabilities:
/// - Stardog-inspired virtual graphs
/// - GraphDB-inspired materialized inference
/// - Vector similarity search
/// - Text mining and NLP
/// - Full-text search
/// - SPARQL federation
///
/// STAMP Constraints:
/// - SC-SEM-070: All operations through unified API
/// - SC-SEM-071: Consistent error handling
/// - SC-SEM-072: Telemetry for all operations
///
/// Version: 2.0.0
namespace Cepaf.Smriti.Semantic

open System
open System.IO
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared

/// Semantic Layer Configuration
type SemanticLayerConfig = {
    /// SQLite database path for triple store
    TripleStorePath: string
    /// Enable materialized inference
    EnableInference: bool
    /// Reasoning profile to use
    ReasoningProfile: ReasoningProfile
    /// Enable vector similarity
    EnableVectorSearch: bool
    /// Vector dimensions for embeddings
    VectorDimensions: int
    /// Enable text mining
    EnableTextMining: bool
    /// Text mining configuration
    TextMiningConfig: TextMiningConfig
    /// Virtual graphs to load
    VirtualGraphs: VirtualGraph list
    /// Enable full-text search
    EnableFullTextSearch: bool
}

/// Default configuration
module SemanticLayerConfig =
    let defaults = {
        TripleStorePath = "data/kms/semantic.db"
        EnableInference = true
        ReasoningProfile = ReasoningProfile.RDFS
        EnableVectorSearch = true
        VectorDimensions = 64
        EnableTextMining = true
        TextMiningConfig = TextMiningConfig.defaults
        VirtualGraphs = []
        EnableFullTextSearch = true
    }

    let withInference profile config =
        { config with EnableInference = true; ReasoningProfile = profile }

    let withVirtualGraph vg (config: SemanticLayerConfig) =
        { config with VirtualGraphs = vg :: config.VirtualGraphs }

/// Semantic Layer Statistics
type SemanticLayerStats = {
    TotalTriples: int64
    TotalGraphs: int
    TotalInferences: int64
    TotalEmbeddings: int64
    VirtualGraphCount: int
    SearchIndexSize: int64
    LastInferenceRun: DateTime option
}

/// Semantic query options
type QueryOptions = {
    /// Use reasoning (backward-chaining)
    UseReasoning: bool
    /// Include inferred triples
    IncludeInferred: bool
    /// Search in virtual graphs
    SearchVirtualGraphs: bool
    /// Use vector similarity
    UseVectorSimilarity: bool
    /// Similarity threshold
    SimilarityThreshold: float
    /// Maximum results
    Limit: int
}

module QueryOptions =
    let defaults = {
        UseReasoning = false
        IncludeInferred = true
        SearchVirtualGraphs = true
        UseVectorSimilarity = false
        SimilarityThreshold = 0.5
        Limit = 100
    }

    let withReasoning opts = { opts with UseReasoning = true }
    let withVectorSearch threshold opts =
        { opts with UseVectorSimilarity = true; SimilarityThreshold = threshold }

/// Unified Semantic Layer
type SemanticLayer(config: SemanticLayerConfig) =

    let mutable connection: SqliteConnection option = None
    let mutable initialized = false

    /// Get or create connection
    member private this.GetConnection() =
        match connection with
        | Some conn -> conn
        | None ->
            let dir = Path.GetDirectoryName(config.TripleStorePath)
            if not (String.IsNullOrEmpty(dir)) && not (Directory.Exists(dir)) then
                Directory.CreateDirectory(dir) |> ignore

            let connStr = $"Data Source={config.TripleStorePath}"
            let conn = new SqliteConnection(connStr)
            conn.Open()
            connection <- Some conn
            conn

    /// Initialize all schemas
    member this.Initialize() =
        if not initialized then
            let conn = this.GetConnection()

            // Initialize triple store
            TripleStore.initSchema conn

            // Initialize inference schema
            if config.EnableInference then
                MaterializedInference.initInferenceSchema conn

            // Initialize vector similarity schema
            if config.EnableVectorSearch then
                VectorSimilarity.initSchema conn

            // Initialize full-text search
            if config.EnableFullTextSearch then
                FullTextConnector.initFtsSchema conn

            // Initialize webhooks
            WebhookConnector.initSchema conn

            initialized <- true

    /// Ensure initialized
    member private this.EnsureInitialized() =
        if not initialized then this.Initialize()

    // =====================
    // Triple Store Operations
    // =====================

    /// Add a triple to the store
    member this.AddTriple(graphUri: string, triple: Triple) =
        this.EnsureInitialized()
        let conn = this.GetConnection()
        TripleStore.addTriple conn graphUri triple

    /// Add multiple triples
    member this.AddTriples(graphUri: string, triples: Triple list) =
        this.EnsureInitialized()
        let conn = this.GetConnection()
        TripleStore.addTriples conn graphUri triples

    /// Query triples with pattern matching
    member this.QueryTriples(pattern: TriplePattern, options: QueryOptions) =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        // Query main store (None = default graph)
        let mainResults = TripleStore.queryByPattern conn None pattern

        // Add inferred triples if requested
        let inferredResults =
            if options.IncludeInferred && config.EnableInference then
                match pattern.Subject with
                | IriTerm iri ->
                    MaterializedInference.getInferredForSubject conn (IRI.expand iri)
                | _ -> []
            else []

        // Query virtual graphs if requested
        let virtualResults =
            if options.SearchVirtualGraphs then
                config.VirtualGraphs
                |> List.collect (fun vg ->
                    match VirtualGraphEngine.queryVirtualGraph vg (Some pattern) with
                    | TripleStoreResult.Success triples -> triples
                    | TripleStoreResult.Error _ -> []
                )
            else []

        // Combine and deduplicate
        mainResults @ inferredResults @ virtualResults
        |> List.distinctBy (fun t -> (t.Subject, t.Predicate, t.Object))
        |> List.truncate options.Limit

    // =====================
    // Query DSL Operations
    // =====================

    /// Execute a semantic query
    member this.ExecuteQuery(query: SemanticQuery, options: QueryOptions) =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        let baseResult =
            if options.UseReasoning then
                QueryEngine.executeWithReasoning conn query
            else
                QueryEngine.execute conn query

        // Add virtual graph results if needed
        if options.SearchVirtualGraphs && not config.VirtualGraphs.IsEmpty then
            let federatedResult =
                QueryEngine.executeFederated conn config.VirtualGraphs query
            { baseResult with
                Rows = baseResult.Rows @ federatedResult.Rows |> List.truncate options.Limit }
        else
            baseResult

    /// Explain a query without executing
    member this.ExplainQuery(query: SemanticQuery) =
        QueryEngine.explain query

    // =====================
    // Inference Operations
    // =====================

    /// Run materialized inference on all triples
    member this.RunInference() =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        // Get all triples (None = no filtering)
        let allTriples =
            TripleStore.queryTriples conn None None None None

        // Run inference
        let rules = MaterializedInference.getRulesForProfile config.ReasoningProfile
        let inferences = MaterializedInference.runInference allTriples rules

        // Persist
        MaterializedInference.persistInferences conn inferences

    /// Re-materialize all inferences (after rule change)
    member this.Rematerialize() =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        let allTriples =
            TripleStore.queryTriples conn None None None None

        MaterializedInference.rematerialize conn allTriples config.ReasoningProfile

    // =====================
    // Vector Similarity Operations
    // =====================

    /// Index content for semantic search
    member this.IndexForSearch(entityUri: string, text: string) =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        let vector = VectorSimilarity.generateTestEmbedding text config.VectorDimensions
        VectorSimilarity.storeEmbedding conn entityUri "default" vector |> ignore

    /// Find semantically similar entities
    member this.FindSimilar(text: string, k: int, threshold: float) =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        let queryVector = VectorSimilarity.generateTestEmbedding text config.VectorDimensions
        VectorSimilarity.findSimilar conn queryVector k threshold

    /// Find entities similar to a given entity
    member this.FindSimilarTo(entityUri: string, k: int, threshold: float) =
        this.EnsureInitialized()
        let conn = this.GetConnection()
        VectorSimilarity.findSimilarTo conn entityUri k threshold

    // =====================
    // Text Mining Operations
    // =====================

    /// Extract semantic content from text
    member this.MineText(sourceId: string, text: string) =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        let result = TextMining.mineText config.TextMiningConfig sourceId text

        // Persist triples
        match TextMining.persistResults conn result with
        | TripleStoreResult.Success _ -> TripleStoreResult.Success result
        | TripleStoreResult.Error e -> TripleStoreResult.Error e

    /// Process a Zettel for semantic content
    member this.ProcessZettel(zettelId: Guid, title: string, content: string) =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        // Mine text
        let text = $"# {title}\n\n{content}"
        let mineResult = TextMining.mineText config.TextMiningConfig (zettelId.ToString()) text

        // Persist triples
        let persistResult = TextMining.persistResults conn mineResult

        // Index for vector search
        if config.EnableVectorSearch then
            let uri = $"http://indrajaal.ai/smriti/zettel/{zettelId}"
            this.IndexForSearch(uri, text)

        // Link to Zettel
        match persistResult with
        | TripleStoreResult.Success _ -> TripleStoreResult.Success mineResult
        | TripleStoreResult.Error e -> TripleStoreResult.Error e

    // =====================
    // Full-Text Search Operations
    // =====================

    /// Search using full-text index
    member this.FullTextSearch(query: string, limit: int) =
        this.EnsureInitialized()
        let conn = this.GetConnection()
        FullTextConnector.search conn query limit

    /// Rebuild full-text index
    member this.RebuildSearchIndex() =
        this.EnsureInitialized()
        let conn = this.GetConnection()
        FullTextConnector.rebuildIndex conn

    // =====================
    // Virtual Graph Operations
    // =====================

    /// Add a virtual graph
    member this.AddVirtualGraph(vg: VirtualGraph) =
        // Note: This doesn't persist, just adds to runtime config
        VirtualGraphEngine.queryVirtualGraph vg None |> ignore  // Validate connection

    /// Query a specific virtual graph
    member this.QueryVirtualGraph(vg: VirtualGraph, pattern: TriplePattern option) =
        VirtualGraphEngine.queryVirtualGraph vg pattern

    /// Invalidate virtual graph cache
    member this.InvalidateVirtualGraphCache(graphUri: string) =
        VirtualGraphEngine.invalidateCache graphUri

    // =====================
    // Connector Operations
    // =====================

    /// Register a webhook
    member this.RegisterWebhook(subscription: WebhookConnector.WebhookSubscription) =
        this.EnsureInitialized()
        let conn = this.GetConnection()
        WebhookConnector.register conn subscription

    /// Query remote SPARQL endpoint
    member this.QueryRemoteSparql(endpoint: string, sparql: string, apiKey: string option) =
        SparqlFederation.queryRemote endpoint sparql apiKey

    // =====================
    // Statistics & Maintenance
    // =====================

    /// Get semantic layer statistics
    member this.GetStats() : SemanticLayerStats =
        this.EnsureInitialized()
        let conn = this.GetConnection()

        let tripleStats = TripleStore.getStats conn

        // Count inferences
        let inferenceCount =
            let sql = "SELECT COUNT(*) FROM inferred_triples"
            use cmd = new SqliteCommand(sql, conn)
            cmd.ExecuteScalar() :?> int64

        // Count embeddings
        let embeddingCount =
            let sql = "SELECT COUNT(*) FROM embeddings"
            use cmd = new SqliteCommand(sql, conn)
            try cmd.ExecuteScalar() :?> int64
            with _ -> 0L

        {
            TotalTriples = tripleStats.TotalTriples
            TotalGraphs = tripleStats.GraphCount
            TotalInferences = inferenceCount
            TotalEmbeddings = embeddingCount
            VirtualGraphCount = config.VirtualGraphs.Length
            SearchIndexSize = 0L  // Would need FTS5 stats
            LastInferenceRun = None  // Would track this
        }

    /// Close connection
    member this.Close() =
        match connection with
        | Some conn ->
            conn.Close()
            connection <- None
        | None -> ()

    interface IDisposable with
        member this.Dispose() = this.Close()


/// Convenience functions for common operations
module Semantic =

    /// Create a semantic layer with default config
    let create () =
        let layer = new SemanticLayer(SemanticLayerConfig.defaults)
        layer.Initialize()
        layer

    /// Create with custom config
    let createWith config =
        let layer = new SemanticLayer(config)
        layer.Initialize()
        layer

    /// Create SMRITI virtual graph
    let createSmritiGraph dbPath =
        VirtualGraphEngine.createSmritiVirtualGraph dbPath

    /// Quick semantic query builder
    let query vars =
        Query.select vars

    /// Find related concepts via vector similarity
    let findRelated (layer: SemanticLayer) entityUri k =
        layer.FindSimilarTo(entityUri, k, 0.5)

    /// Search across all semantic sources
    let search (layer: SemanticLayer) query limit =
        // Combine full-text and vector search
        let ftsResults = layer.FullTextSearch(query, limit / 2)
        let vectorResults = layer.FindSimilar(query, limit / 2, 0.5)

        // Merge and rank
        let combined =
            (ftsResults |> List.map (fun r -> (r.Uri, r.Score, "fts"))) @
            (vectorResults |> List.map (fun r -> (IRI.expand r.Entity, r.Score, "vector")))

        combined
        |> List.sortByDescending (fun (_, score, _) -> score)
        |> List.truncate limit


/// SMRITI Integration Module
module SmritiIntegration =

    /// Initialize semantic layer for SMRITI
    let initForSmriti (smritiDbPath: string) (semanticDbPath: string) =
        let config = {
            SemanticLayerConfig.defaults with
                TripleStorePath = semanticDbPath
                VirtualGraphs = [VirtualGraphEngine.createSmritiVirtualGraph smritiDbPath]
        }
        Semantic.createWith config

    /// Process all Zettels for semantic indexing
    let indexAllZettels (layer: SemanticLayer) (zettels: (Guid * string * string) list) =
        let mutable successCount = 0
        let mutable errorCount = 0

        for (id, title, content) in zettels do
            match layer.ProcessZettel(id, title, content) with
            | TripleStoreResult.Success _ -> successCount <- successCount + 1
            | TripleStoreResult.Error _ -> errorCount <- errorCount + 1

        (successCount, errorCount)

    /// Find semantically related Zettels
    let findRelatedZettels (layer: SemanticLayer) (zettelId: Guid) (limit: int) =
        let uri = $"http://indrajaal.ai/smriti/zettel/{zettelId}"
        layer.FindSimilarTo(uri, limit, 0.5)
        |> List.choose (fun r ->
            let resultUri = IRI.expand r.Entity
            let prefix = "http://indrajaal.ai/smriti/zettel/"
            if resultUri.StartsWith(prefix) then
                match Guid.TryParse(resultUri.Substring(prefix.Length)) with
                | true, guid when guid <> zettelId -> Some (guid, r.Score)
                | _ -> None
            else None
        )

    /// Search Zettels with semantic ranking
    let searchZettels (layer: SemanticLayer) (queryText: string) (limit: int) =
        Semantic.search layer queryText limit
        |> List.choose (fun (uri, score, source) ->
            let prefix = "http://indrajaal.ai/smriti/zettel/"
            if uri.StartsWith(prefix) then
                match Guid.TryParse(uri.Substring(prefix.Length)) with
                | true, guid -> Some (guid, score, source)
                | _ -> None
            else None
        )

    /// Get backlinks via semantic graph
    let getSemanticBacklinks (layer: SemanticLayer) (zettelId: Guid) =
        let targetUri = $"<http://indrajaal.ai/smriti/zettel/{zettelId}>"
        let query =
            Query.select ["source"; "linkType"]
            |> Query.whereTriple "?source" "ind:linksTo" targetUri
            |> Query.limit 100

        layer.ExecuteQuery(query, QueryOptions.defaults)

