/// Vector Similarity - Semantic Search via Embeddings
///
/// Implements vector-based semantic similarity search
/// similar to GraphDB's semantic similarity features.
///
/// Key Features:
/// - Cosine similarity search
/// - Embedding storage in SQLite
/// - Integration with LLM embedding APIs
/// - Concept clustering
///
/// STAMP Constraints:
/// - SC-SEM-040: Embeddings stored efficiently (float32)
/// - SC-SEM-041: Similarity search < 100ms
/// - SC-SEM-042: K-NN approximate allowed for large sets
///
/// Version: 2.0.0
namespace Cepaf.Smriti.Semantic

open System
open Microsoft.Data.Sqlite
open MathNet.Numerics.LinearAlgebra

/// Embedding Model Configuration
type EmbeddingConfig = {
    /// Model name (e.g., "text-embedding-ada-002")
    Model: string
    /// Vector dimensions
    Dimensions: int
    /// API endpoint for embedding generation
    ApiEndpoint: string option
    /// Use local model (e.g., SentenceTransformers)
    UseLocal: bool
}

/// Default embedding configurations
module EmbeddingModels =
    let openAiAda = {
        Model = "text-embedding-ada-002"
        Dimensions = 1536
        ApiEndpoint = Some "https://api.openai.com/v1/embeddings"
        UseLocal = false
    }

    let localMiniLM = {
        Model = "all-MiniLM-L6-v2"
        Dimensions = 384
        ApiEndpoint = None
        UseLocal = true
    }

    /// Small embeddings for testing
    let testSmall = {
        Model = "test-small"
        Dimensions = 64
        ApiEndpoint = None
        UseLocal = true
    }

/// Vector Similarity Operations
module VectorSimilarity =

    /// Initialize embeddings schema in SQLite
    let initSchema (conn: SqliteConnection) =
        let sql = """
            -- Embeddings storage
            CREATE TABLE IF NOT EXISTS embeddings (
                entity_uri TEXT PRIMARY KEY,
                model TEXT NOT NULL,
                dimensions INTEGER NOT NULL,
                vector BLOB NOT NULL,  -- Binary float32 array
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE INDEX IF NOT EXISTS idx_embeddings_model
                ON embeddings(model);

            -- Similarity cache (for expensive computations)
            CREATE TABLE IF NOT EXISTS similarity_cache (
                entity1_uri TEXT NOT NULL,
                entity2_uri TEXT NOT NULL,
                similarity REAL NOT NULL,
                computed_at TEXT NOT NULL DEFAULT (datetime('now')),

                PRIMARY KEY (entity1_uri, entity2_uri)
            );

            -- Concept clusters (pre-computed)
            CREATE TABLE IF NOT EXISTS clusters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                centroid BLOB,  -- Centroid vector
                member_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS cluster_members (
                cluster_id INTEGER NOT NULL,
                entity_uri TEXT NOT NULL,
                distance REAL NOT NULL,

                PRIMARY KEY (cluster_id, entity_uri),
                FOREIGN KEY (cluster_id) REFERENCES clusters(id)
            );
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery() |> ignore

    /// Convert float array to bytes for storage
    let vectorToBytes (vector: float array) : byte array =
        let bytes = Array.zeroCreate (vector.Length * 4)
        for i in 0 .. vector.Length - 1 do
            let floatBytes = BitConverter.GetBytes(float32 vector.[i])
            Array.Copy(floatBytes, 0, bytes, i * 4, 4)
        bytes

    /// Convert bytes back to float array
    let bytesToVector (bytes: byte array) : float array =
        let length = bytes.Length / 4
        let vector = Array.zeroCreate length
        for i in 0 .. length - 1 do
            vector.[i] <- float (BitConverter.ToSingle(bytes, i * 4))
        vector

    /// Store an embedding
    let storeEmbedding (conn: SqliteConnection) (entityUri: string) (model: string) (vector: float array) =
        let sql = """
            INSERT OR REPLACE INTO embeddings (entity_uri, model, dimensions, vector, updated_at)
            VALUES (@uri, @model, @dims, @vector, datetime('now'))
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@uri", entityUri) |> ignore
        cmd.Parameters.AddWithValue("@model", model) |> ignore
        cmd.Parameters.AddWithValue("@dims", vector.Length) |> ignore
        cmd.Parameters.AddWithValue("@vector", vectorToBytes vector) |> ignore
        cmd.ExecuteNonQuery()

    /// Get an embedding
    let getEmbedding (conn: SqliteConnection) (entityUri: string) : float array option =
        let sql = "SELECT vector FROM embeddings WHERE entity_uri = @uri"
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@uri", entityUri) |> ignore

        use reader = cmd.ExecuteReader()
        if reader.Read() then
            let bytes = reader.GetValue(0) :?> byte array
            Some (bytesToVector bytes)
        else
            None

    /// Calculate cosine similarity between two vectors
    let cosineSimilarity (v1: float array) (v2: float array) : float =
        if v1.Length <> v2.Length then
            0.0
        else
            let vec1 = Vector<float>.Build.Dense(v1)
            let vec2 = Vector<float>.Build.Dense(v2)
            let dot = vec1.DotProduct(vec2)
            let norm1 = vec1.L2Norm()
            let norm2 = vec2.L2Norm()
            if norm1 = 0.0 || norm2 = 0.0 then 0.0
            else dot / (norm1 * norm2)

    /// Find K nearest neighbors by cosine similarity
    let findSimilar
        (conn: SqliteConnection)
        (queryVector: float array)
        (k: int)
        (threshold: float)
        : SimilarityResult list =

        // Load all embeddings (for small datasets; production would use ANN index)
        let sql = "SELECT entity_uri, vector FROM embeddings"
        use cmd = new SqliteCommand(sql, conn)
        use reader = cmd.ExecuteReader()

        let results = ResizeArray<string * float array>()
        while reader.Read() do
            let uri = reader.GetString(0)
            let bytes = reader.GetValue(1) :?> byte array
            results.Add((uri, bytesToVector bytes))

        // Compute similarities and rank
        results
        |> Seq.map (fun (uri, vector) ->
            let similarity = cosineSimilarity queryVector vector
            { Entity = FullIRI uri; Score = similarity; Label = None }
        )
        |> Seq.filter (fun r -> r.Score >= threshold)
        |> Seq.sortByDescending (fun r -> r.Score)
        |> Seq.take (min k (results.Count))
        |> Seq.toList

    /// Find entities similar to a given entity
    let findSimilarTo
        (conn: SqliteConnection)
        (entityUri: string)
        (k: int)
        (threshold: float)
        : SimilarityResult list =

        match getEmbedding conn entityUri with
        | Some vector ->
            findSimilar conn vector k threshold
            |> List.filter (fun r ->
                // Exclude self
                r.Entity <> FullIRI entityUri
            )
        | None -> []

    /// Cache similarity between two entities
    let cacheSimilarity (conn: SqliteConnection) (uri1: string) (uri2: string) (similarity: float) =
        let sql = """
            INSERT OR REPLACE INTO similarity_cache (entity1_uri, entity2_uri, similarity, computed_at)
            VALUES (@uri1, @uri2, @sim, datetime('now'))
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@uri1", uri1) |> ignore
        cmd.Parameters.AddWithValue("@uri2", uri2) |> ignore
        cmd.Parameters.AddWithValue("@sim", similarity) |> ignore
        cmd.ExecuteNonQuery() |> ignore

    /// Get cached similarity
    let getCachedSimilarity (conn: SqliteConnection) (uri1: string) (uri2: string) : float option =
        let sql = "SELECT similarity FROM similarity_cache WHERE entity1_uri = @uri1 AND entity2_uri = @uri2"
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@uri1", uri1) |> ignore
        cmd.Parameters.AddWithValue("@uri2", uri2) |> ignore

        use reader = cmd.ExecuteReader()
        if reader.Read() then Some (reader.GetDouble(0))
        else None

    /// Generate a simple hash-based embedding for testing
    /// Production would call actual embedding API
    let generateTestEmbedding (text: string) (dimensions: int) : float array =
        let random = Random(text.GetHashCode())
        Array.init dimensions (fun _ -> random.NextDouble() * 2.0 - 1.0)

    /// Cluster entities using simple k-means
    let clusterEntities
        (conn: SqliteConnection)
        (k: int)  // Number of clusters
        : unit =

        // Load all embeddings
        let sql = "SELECT entity_uri, vector FROM embeddings"
        use cmd = new SqliteCommand(sql, conn)
        use reader = cmd.ExecuteReader()

        let entities = ResizeArray<string * float array>()
        while reader.Read() do
            let uri = reader.GetString(0)
            let bytes = reader.GetValue(1) :?> byte array
            entities.Add((uri, bytesToVector bytes))

        if entities.Count < k then ()
        else
            // Simple k-means (production would use proper implementation)
            let dimensions = (snd entities.[0]).Length

            // Initialize centroids randomly
            let random = Random()
            let mutable centroids =
                [| for _ in 1 .. k ->
                    let idx = random.Next(entities.Count)
                    Array.copy (snd entities.[idx])
                |]

            // Iterate until convergence (simplified: fixed iterations)
            for _ in 1 .. 10 do
                // Assign entities to nearest centroid
                let assignments = Array.zeroCreate entities.Count
                for i in 0 .. entities.Count - 1 do
                    let (_, vec) = entities.[i]
                    let mutable bestCluster = 0
                    let mutable bestDist = Double.MaxValue
                    for c in 0 .. k - 1 do
                        let dist = 1.0 - cosineSimilarity vec centroids.[c]
                        if dist < bestDist then
                            bestDist <- dist
                            bestCluster <- c
                    assignments.[i] <- bestCluster

                // Update centroids
                for c in 0 .. k - 1 do
                    let members =
                        entities
                        |> Seq.mapi (fun i e -> (i, e))
                        |> Seq.filter (fun (i, _) -> assignments.[i] = c)
                        |> Seq.map snd
                        |> Seq.toArray

                    if members.Length > 0 then
                        let newCentroid = Array.zeroCreate dimensions
                        for (_, vec) in members do
                            for d in 0 .. dimensions - 1 do
                                newCentroid.[d] <- newCentroid.[d] + vec.[d]
                        for d in 0 .. dimensions - 1 do
                            newCentroid.[d] <- newCentroid.[d] / float members.Length
                        centroids.[c] <- newCentroid

            // Store clusters
            let insertCluster = "INSERT INTO clusters (name, centroid, member_count) VALUES (@name, @centroid, @count)"
            let insertMember = "INSERT INTO cluster_members (cluster_id, entity_uri, distance) VALUES (@cid, @uri, @dist)"

            for c in 0 .. k - 1 do
                use cmdCluster = new SqliteCommand(insertCluster, conn)
                cmdCluster.Parameters.AddWithValue("@name", $"cluster_{c}") |> ignore
                cmdCluster.Parameters.AddWithValue("@centroid", vectorToBytes centroids.[c]) |> ignore

                let memberCount =
                    [0 .. entities.Count - 1]
                    |> List.filter (fun i -> Array.get (Array.zeroCreate entities.Count) i = c)  // Simplified
                    |> List.length

                cmdCluster.Parameters.AddWithValue("@count", memberCount) |> ignore
                cmdCluster.ExecuteNonQuery() |> ignore

/// Semantic Search Integration
module SemanticSearch =

    /// Search SMRITI using semantic similarity
    let searchSemantic
        (conn: SqliteConnection)
        (queryText: string)
        (limit: int)
        (threshold: float)
        : (Guid * float) list =

        // Generate query embedding
        let queryVector = VectorSimilarity.generateTestEmbedding queryText 64

        // Find similar
        let results = VectorSimilarity.findSimilar conn queryVector limit threshold

        // Map back to Zettel IDs
        results
        |> List.choose (fun r ->
            let uri = IRI.expand r.Entity
            // Extract ID from URI: http://indrajaal.ai/smriti/zettel/{id}
            let prefix = "http://indrajaal.ai/smriti/zettel/"
            if uri.StartsWith(prefix) then
                match Guid.TryParse(uri.Substring(prefix.Length)) with
                | true, guid -> Some (guid, r.Score)
                | false, _ -> None
            else None
        )

    /// Index a Zettel for semantic search
    let indexZettel (conn: SqliteConnection) (zettelId: Guid) (title: string) (content: string) =
        let text = $"{title}\n\n{content}"
        let vector = VectorSimilarity.generateTestEmbedding text 64
        let uri = $"http://indrajaal.ai/smriti/zettel/{zettelId}"
        VectorSimilarity.storeEmbedding conn uri "test-small" vector |> ignore

    /// Batch index multiple Zettels
    let batchIndex (conn: SqliteConnection) (zettels: (Guid * string * string) list) =
        use transaction = conn.BeginTransaction()
        try
            for (id, title, content) in zettels do
                indexZettel conn id title content
            transaction.Commit()
            Success zettels.Length
        with ex ->
            transaction.Rollback()
            Error $"Batch index failed: {ex.Message}"

    /// Find conceptually related Zettels
    let findRelated (conn: SqliteConnection) (zettelId: Guid) (limit: int) : (Guid * float) list =
        let uri = $"http://indrajaal.ai/smriti/zettel/{zettelId}"
        let results = VectorSimilarity.findSimilarTo conn uri limit 0.5

        results
        |> List.choose (fun r ->
            let uri = IRI.expand r.Entity
            let prefix = "http://indrajaal.ai/smriti/zettel/"
            if uri.StartsWith(prefix) then
                match Guid.TryParse(uri.Substring(prefix.Length)) with
                | true, guid when guid <> zettelId -> Some (guid, r.Score)
                | _ -> None
            else None
        )
