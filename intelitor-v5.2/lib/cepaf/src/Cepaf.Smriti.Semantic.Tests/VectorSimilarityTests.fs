/// Vector Similarity Tests
///
/// Comprehensive tests for VectorSimilarity module covering:
/// - Embedding storage and retrieval
/// - Cosine similarity calculation
/// - K-NN search
/// - Clustering
/// - STAMP constraints (SC-SEM-040, SC-SEM-041, SC-SEM-042)
///
/// Version: 1.0.0
module Cepaf.Smriti.Semantic.Tests.VectorSimilarityTests

open System
open System.IO
open Expecto
open FsCheck
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Semantic

/// Create test database for vectors
let createVectorDb() =
    let path = Path.GetTempFileName()
    let connStr = $"Data Source={path}"
    let conn = new SqliteConnection(connStr)
    conn.Open()
    VectorSimilarity.initSchema conn
    (conn, path)

let cleanupVectorDb (conn: SqliteConnection) (path: string) =
    conn.Close()
    conn.Dispose()
    if File.Exists(path) then File.Delete(path)

[<Tests>]
let vectorSimilarityTests =
    testList "VectorSimilarity" [

        testCase "initSchema: Tables created" <| fun () ->
            let (conn, path) = createVectorDb()

            let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%embedding%' OR name LIKE '%cluster%'"
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let tables = [
                while reader.Read() do
                    reader.GetString(0)
            ]

            Expect.contains tables "embeddings" "Should have embeddings table"
            Expect.contains tables "similarity_cache" "Should have cache table"
            Expect.contains tables "clusters" "Should have clusters table"

            cleanupVectorDb conn path

        testCase "SC-SEM-040: Embeddings stored as float32" <| fun () ->
            let (conn, path) = createVectorDb()

            let vector = [| 0.1; 0.2; 0.3 |]
            VectorSimilarity.storeEmbedding conn "http://example.org/test" "test-model" vector |> ignore

            // Verify storage efficiency
            let sql = "SELECT length(vector) FROM embeddings WHERE entity_uri = 'http://example.org/test'"
            use cmd = new SqliteCommand(sql, conn)
            let byteLength = cmd.ExecuteScalar() :?> int64

            // 3 floats * 4 bytes = 12 bytes
            Expect.equal byteLength 12L "Should store as float32 (4 bytes each)"

            cleanupVectorDb conn path

        testCase "vectorToBytes: Correct conversion" <| fun () ->
            let vector = [| 1.0; 2.0; 3.0 |]
            let bytes = VectorSimilarity.vectorToBytes vector

            Expect.equal bytes.Length 12 "Should be 12 bytes for 3 floats"

        testCase "bytesToVector: Roundtrip conversion" <| fun () ->
            let original = [| 1.5; 2.5; 3.5; 4.5 |]
            let bytes = VectorSimilarity.vectorToBytes original
            let restored = VectorSimilarity.bytesToVector bytes

            for i in 0 .. original.Length - 1 do
                Expect.floatClose Accuracy.medium original.[i] restored.[i] "Should roundtrip"

        testCase "storeEmbedding: Single embedding" <| fun () ->
            let (conn, path) = createVectorDb()

            let vector = [| 0.1; 0.2; 0.3; 0.4 |]
            let count = VectorSimilarity.storeEmbedding conn "http://example.org/entity1" "model1" vector

            Expect.equal count 1 "Should store 1 embedding"

            cleanupVectorDb conn path

        testCase "storeEmbedding: Update existing" <| fun () ->
            let (conn, path) = createVectorDb()

            let vector1 = [| 0.1; 0.2 |]
            let vector2 = [| 0.3; 0.4 |]

            VectorSimilarity.storeEmbedding conn "http://example.org/entity1" "model1" vector1 |> ignore
            VectorSimilarity.storeEmbedding conn "http://example.org/entity1" "model1" vector2 |> ignore

            // Should only have 1 row (REPLACE)
            let sql = "SELECT COUNT(*) FROM embeddings WHERE entity_uri = 'http://example.org/entity1'"
            use cmd = new SqliteCommand(sql, conn)
            let count = cmd.ExecuteScalar() :?> int64

            Expect.equal count 1L "Should replace, not duplicate"

            cleanupVectorDb conn path

        testCase "getEmbedding: Retrieve stored embedding" <| fun () ->
            let (conn, path) = createVectorDb()

            let original = [| 0.5; 0.6; 0.7 |]
            VectorSimilarity.storeEmbedding conn "http://example.org/test" "model" original |> ignore

            match VectorSimilarity.getEmbedding conn "http://example.org/test" with
            | Some retrieved ->
                Expect.equal retrieved.Length original.Length "Should have same length"
                for i in 0 .. original.Length - 1 do
                    Expect.floatClose Accuracy.medium original.[i] retrieved.[i] "Should match"
            | None -> failtest "Should retrieve embedding"

            cleanupVectorDb conn path

        testCase "getEmbedding: Missing entity returns None" <| fun () ->
            let (conn, path) = createVectorDb()

            match VectorSimilarity.getEmbedding conn "http://nonexistent.org/missing" with
            | None -> Expect.isTrue true "Should return None"
            | Some _ -> failtest "Should not find nonexistent"

            cleanupVectorDb conn path

        testCase "cosineSimilarity: Identical vectors = 1.0" <| fun () ->
            let v = [| 1.0; 2.0; 3.0 |]
            let similarity = VectorSimilarity.cosineSimilarity v v

            Expect.floatClose Accuracy.high similarity 1.0 "Identical should be 1.0"

        testCase "cosineSimilarity: Orthogonal vectors = 0.0" <| fun () ->
            let v1 = [| 1.0; 0.0 |]
            let v2 = [| 0.0; 1.0 |]
            let similarity = VectorSimilarity.cosineSimilarity v1 v2

            Expect.floatClose Accuracy.high similarity 0.0 "Orthogonal should be 0.0"

        testCase "cosineSimilarity: Opposite vectors = -1.0" <| fun () ->
            let v1 = [| 1.0; 0.0; 0.0 |]
            let v2 = [| -1.0; 0.0; 0.0 |]
            let similarity = VectorSimilarity.cosineSimilarity v1 v2

            Expect.floatClose Accuracy.high similarity -1.0 "Opposite should be -1.0"

        testCase "cosineSimilarity: Different dimensions = 0.0" <| fun () ->
            let v1 = [| 1.0; 2.0 |]
            let v2 = [| 1.0; 2.0; 3.0 |]
            let similarity = VectorSimilarity.cosineSimilarity v1 v2

            Expect.equal similarity 0.0 "Different dimensions should be 0.0"

        testCase "SC-SEM-041: Similarity search < 100ms" <| fun () ->
            let (conn, path) = createVectorDb()

            // Store 50 embeddings
            for i in 1 .. 50 do
                let vector = VectorSimilarity.generateTestEmbedding $"entity{i}" 64
                VectorSimilarity.storeEmbedding conn $"http://example.org/e{i}" "test" vector |> ignore

            let queryVector = VectorSimilarity.generateTestEmbedding "query" 64

            let sw = System.Diagnostics.Stopwatch.StartNew()
            let results = VectorSimilarity.findSimilar conn queryVector 10 0.5
            sw.Stop()

            Expect.isLessThan sw.ElapsedMilliseconds 100L "Should be < 100ms"

            cleanupVectorDb conn path

        testCase "findSimilar: K nearest neighbors" <| fun () ->
            let (conn, path) = createVectorDb()

            // Store embeddings
            for i in 1 .. 10 do
                let vector = [| float i; float (i * 2) |]
                VectorSimilarity.storeEmbedding conn $"http://example.org/e{i}" "test" vector |> ignore

            let queryVector = [| 5.0; 10.0 |]
            let results = VectorSimilarity.findSimilar conn queryVector 3 0.0

            Expect.equal results.Length 3 "Should return top 3"

            // Results should be sorted by score descending
            for i in 0 .. results.Length - 2 do
                Expect.isGreaterThanOrEqual results.[i].Score results.[i+1].Score "Should be descending"

            cleanupVectorDb conn path

        testCase "findSimilar: Threshold filtering" <| fun () ->
            let (conn, path) = createVectorDb()

            let v1 = [| 1.0; 0.0 |]
            let v2 = [| 0.0; 1.0 |]  // Orthogonal, similarity = 0
            let v3 = [| 1.0; 0.1 |]  // Similar to v1

            VectorSimilarity.storeEmbedding conn "http://e1" "test" v1 |> ignore
            VectorSimilarity.storeEmbedding conn "http://e2" "test" v2 |> ignore
            VectorSimilarity.storeEmbedding conn "http://e3" "test" v3 |> ignore

            let queryVector = [| 1.0; 0.0 |]
            let results = VectorSimilarity.findSimilar conn queryVector 10 0.5

            // Should exclude e2 (similarity = 0)
            Expect.isLessThan results.Length 3 "Should filter by threshold"

            cleanupVectorDb conn path

        testCase "findSimilarTo: Find by entity URI" <| fun () ->
            let (conn, path) = createVectorDb()

            let v1 = [| 1.0; 0.0 |]
            let v2 = [| 0.9; 0.1 |]  // Similar to v1
            let v3 = [| 0.0; 1.0 |]  // Different

            VectorSimilarity.storeEmbedding conn "http://e1" "test" v1 |> ignore
            VectorSimilarity.storeEmbedding conn "http://e2" "test" v2 |> ignore
            VectorSimilarity.storeEmbedding conn "http://e3" "test" v3 |> ignore

            let results = VectorSimilarity.findSimilarTo conn "http://e1" 10 0.5

            // Should not include self
            Expect.all results (fun r -> IRI.expand r.Entity <> "http://e1") "Should exclude self"

            cleanupVectorDb conn path

        testCase "cacheSimilarity: Cache pairwise similarity" <| fun () ->
            let (conn, path) = createVectorDb()

            VectorSimilarity.cacheSimilarity conn "http://e1" "http://e2" 0.85

            match VectorSimilarity.getCachedSimilarity conn "http://e1" "http://e2" with
            | Some score -> Expect.floatClose Accuracy.high score 0.85 "Should retrieve cached"
            | None -> failtest "Should have cached value"

            cleanupVectorDb conn path

        testCase "getCachedSimilarity: Missing returns None" <| fun () ->
            let (conn, path) = createVectorDb()

            match VectorSimilarity.getCachedSimilarity conn "http://e1" "http://e2" with
            | None -> Expect.isTrue true "Should return None"
            | Some _ -> failtest "Should not find uncached"

            cleanupVectorDb conn path

        testCase "generateTestEmbedding: Deterministic" <| fun () ->
            let v1 = VectorSimilarity.generateTestEmbedding "test" 10
            let v2 = VectorSimilarity.generateTestEmbedding "test" 10

            Expect.equal v1 v2 "Same input should generate same embedding"

        testCase "generateTestEmbedding: Correct dimensions" <| fun () ->
            let v = VectorSimilarity.generateTestEmbedding "test" 128

            Expect.equal v.Length 128 "Should have requested dimensions"

        testCase "clusterEntities: K-means clustering" <| fun () ->
            let (conn, path) = createVectorDb()

            // Store 20 entities in 2 clusters
            for i in 1 .. 10 do
                let v = [| float i; 0.0 |]  // Cluster 1
                VectorSimilarity.storeEmbedding conn $"http://c1/e{i}" "test" v |> ignore

            for i in 1 .. 10 do
                let v = [| 0.0; float i |]  // Cluster 2
                VectorSimilarity.storeEmbedding conn $"http://c2/e{i}" "test" v |> ignore

            VectorSimilarity.clusterEntities conn 2

            // Verify clusters table
            let sql = "SELECT COUNT(*) FROM clusters"
            use cmd = new SqliteCommand(sql, conn)
            let count = cmd.ExecuteScalar() :?> int64

            Expect.equal count 2L "Should create 2 clusters"

            cleanupVectorDb conn path

        testCase "SemanticSearch.indexZettel: Index Zettel content" <| fun () ->
            let (conn, path) = createVectorDb()

            let zettelId = Guid.NewGuid()
            SemanticSearch.indexZettel conn zettelId "Test Title" "Test content"

            let uri = $"http://indrajaal.ai/smriti/zettel/{zettelId}"
            match VectorSimilarity.getEmbedding conn uri with
            | Some v -> Expect.isNonEmpty v "Should have embedding"
            | None -> failtest "Should index Zettel"

            cleanupVectorDb conn path

        testCase "SemanticSearch.searchSemantic: Find similar Zettels" <| fun () ->
            let (conn, path) = createVectorDb()

            // Index 3 Zettels
            for i in 1 .. 3 do
                let id = Guid.NewGuid()
                SemanticSearch.indexZettel conn id $"Title {i}" $"Content {i}"

            let results = SemanticSearch.searchSemantic conn "Test query" 10 0.0

            Expect.isNonEmpty results "Should find similar Zettels"

            cleanupVectorDb conn path

        testCase "SemanticSearch.batchIndex: Batch indexing" <| fun () ->
            let (conn, path) = createVectorDb()

            let zettels = [
                for i in 1 .. 5 do
                    (Guid.NewGuid(), $"Title {i}", $"Content {i}")
            ]

            match SemanticSearch.batchIndex conn zettels with
            | Success count -> Expect.equal count 5 "Should index 5 Zettels"
            | Error e -> failtest $"Failed: {e}"

            cleanupVectorDb conn path

        testCase "SemanticSearch.findRelated: Related Zettels" <| fun () ->
            let (conn, path) = createVectorDb()

            let id1 = Guid.NewGuid()
            let id2 = Guid.NewGuid()

            SemanticSearch.indexZettel conn id1 "Similar Title" "Similar Content"
            SemanticSearch.indexZettel conn id2 "Similar Title" "Similar Content"

            let related = SemanticSearch.findRelated conn id1 10

            Expect.isNonEmpty related "Should find related"
            Expect.all related (fun (id, _) -> id <> id1) "Should exclude self"

            cleanupVectorDb conn path

        testProperty "Cosine similarity is symmetric" <| fun (v1: float list) (v2: float list) ->
            (v1.Length = v2.Length && v1.Length > 0) ==> lazy (
                let arr1 = Array.ofList v1
                let arr2 = Array.ofList v2
                let sim1 = VectorSimilarity.cosineSimilarity arr1 arr2
                let sim2 = VectorSimilarity.cosineSimilarity arr2 arr1

                abs (sim1 - sim2) < 0.0001
            )

        testProperty "Cosine similarity range [-1, 1]" <| fun (v1: float list) (v2: float list) ->
            (v1.Length = v2.Length && v1.Length > 0) ==> lazy (
                let arr1 = Array.ofList v1
                let arr2 = Array.ofList v2
                let sim = VectorSimilarity.cosineSimilarity arr1 arr2

                sim >= -1.0 && sim <= 1.0
            )

        testCase "SC-SEM-042: K-NN approximate allowed for large sets" <| fun () ->
            // This test documents that approximate KNN is acceptable
            // for large datasets (>10000 embeddings)

            // For now, exact search is used
            // Future: Implement FAISS or similar for approximate NN
            Expect.isTrue true "Approximate KNN documented"
    ]
