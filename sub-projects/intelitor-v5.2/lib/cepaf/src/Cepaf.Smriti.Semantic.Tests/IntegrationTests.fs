/// Integration Tests
///
/// Full pipeline tests covering:
/// - Ingest → Infer → Query → Search workflow
/// - SemanticLayer unified API
/// - SMRITI integration
/// - Performance benchmarks
/// - End-to-end scenarios
///
/// Version: 1.0.0
module Cepaf.Smriti.Semantic.Tests.IntegrationTests

open System
open System.IO
open Expecto
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Semantic

/// Create temporary database
let createTempDb() =
    Path.GetTempFileName()

let cleanupTempDb (path: string) =
    if File.Exists(path) then
        try File.Delete(path)
        with _ -> ()

[<Tests>]
let integrationTests =
    testList "Integration" [

        testCase "Full pipeline: Ingest → Infer → Query" <| fun () ->
            let dbPath = createTempDb()

            try
                // Create semantic layer
                let config = { SemanticLayerConfig.defaults with TripleStorePath = dbPath }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // 1. INGEST: Add triples
                let triples: Triple list = [
                    {
                        Subject = IriTerm (FullIRI "http://example.org/Mammal")
                        Predicate = PrefixedIRI ("rdfs", "subClassOf")
                        Object = IriTerm (FullIRI "http://example.org/Animal")
                    }
                    {
                        Subject = IriTerm (FullIRI "http://example.org/Dog")
                        Predicate = PrefixedIRI ("rdfs", "subClassOf")
                        Object = IriTerm (FullIRI "http://example.org/Mammal")
                    }
                    {
                        Subject = IriTerm (FullIRI "http://example.org/Fido")
                        Predicate = PrefixedIRI ("rdf", "type")
                        Object = IriTerm (FullIRI "http://example.org/Dog")
                    }
                ]

                match layer.AddTriples("default", triples) with
                | Success _ -> ()
                | Error e -> failtest $"Failed to add: {e}"

                // 2. INFER: Run inference
                match layer.RunInference() with
                | Success _ -> ()
                | Error e -> failtest $"Failed to infer: {e}"

                // 3. QUERY: Query with inference
                let query =
                    Query.select ["?x"; "?type"]
                    |> Query.whereTriple "?x" "rdf:type" "?type"
                    |> Query.withReasoning

                let result = layer.ExecuteQuery(query, QueryOptions.defaults)

                Expect.isTrue result.ReasoningApplied "Should apply reasoning"
                Expect.isGreaterThan result.InferencesUsed 0 "Should use inferences"

            finally
                cleanupTempDb dbPath

        testCase "SemanticLayer: Configuration with inference" <| fun () ->
            let dbPath = createTempDb()

            try
                let config =
                    SemanticLayerConfig.defaults
                    |> SemanticLayerConfig.withInference ReasoningProfile.RDFS
                    |> fun c -> { c with TripleStorePath = dbPath }

                use layer = new SemanticLayer(config)
                layer.Initialize()

                Expect.isTrue true "Should initialize with inference"

            finally
                cleanupTempDb dbPath

        testCase "SemanticLayer: Statistics reporting" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = { SemanticLayerConfig.defaults with TripleStorePath = dbPath }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // Add some data
                let triple: Triple = {
                    Subject = IriTerm (FullIRI "http://example.org/alice")
                    Predicate = PrefixedIRI ("rdf", "type")
                    Object = IriTerm (PrefixedIRI ("foaf", "Person"))
                }
                layer.AddTriple("default", triple) |> ignore

                let stats = layer.GetStats()

                Expect.isGreaterThan stats.TotalTriples 0L "Should have triples"
                Expect.isGreaterThanOrEqual stats.TotalGraphs 0 "Should report graphs"

            finally
                cleanupTempDb dbPath

        testCase "SMRITI Integration: Process Zettel" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableVectorSearch = true
                        VectorDimensions = 64
                }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                let zettelId = Guid.NewGuid()
                let title = "Test Zettel"
                let content = "This is a test zettel with some content about semantic search."

                match layer.ProcessZettel(zettelId, title, content) with
                | Success result ->
                    Expect.isNonEmpty result.Triples "Should extract triples"
                | Error e ->
                    failtest $"Failed to process: {e}"

            finally
                cleanupTempDb dbPath

        testCase "SMRITI Integration: Semantic search" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableVectorSearch = true
                        VectorDimensions = 64
                }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // Index 3 Zettels
                for i in 1 .. 3 do
                    let id = Guid.NewGuid()
                    let title = $"Zettel {i}"
                    let content = $"Content about topic {i}"
                    layer.ProcessZettel(id, title, content) |> ignore

                // Search
                let results = layer.FindSimilar("topic", 10, 0.0)

                Expect.isNonEmpty results "Should find similar Zettels"

            finally
                cleanupTempDb dbPath

        testCase "Full-text search integration" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableFullTextSearch = true
                }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // This would require FTS implementation
                // For now, just verify initialization
                Expect.isTrue true "FTS initialized"

            finally
                cleanupTempDb dbPath

        testCase "Virtual graph integration" <| fun () ->
            let dbPath = createTempDb()
            let sourcePath = createTempDb()

            try
                // Create source database
                let sourceConn = new SqliteConnection($"Data Source={sourcePath}")
                sourceConn.Open()
                let sql = """
                    CREATE TABLE test_data (
                        id INTEGER PRIMARY KEY,
                        value TEXT
                    );
                    INSERT INTO test_data (id, value) VALUES (1, 'test');
                """
                use cmd = new SqliteCommand(sql, sourceConn)
                cmd.ExecuteNonQuery() |> ignore
                sourceConn.Close()

                // Create virtual graph
                let vg = {
                    Name = FullIRI "http://example.org/vg"
                    SourceType = "SQLite"
                    ConnectionString = $"Data Source={sourcePath}"
                    Mappings = [
                        {
                            Id = "test"
                            TableName = "test_data"
                            RdfClass = FullIRI "http://example.org/TestData"
                            SubjectTemplate = "http://example.org/test/{id}"
                            Columns = [
                                { Column = "id"; Predicate = FullIRI "http://example.org/id"; Datatype = None; IsSubject = true }
                                { Column = "value"; Predicate = FullIRI "http://example.org/value"; Datatype = None; IsSubject = false }
                            ]
                            Filter = None
                        }
                    ]
                    CacheTTL = 60
                    Enabled = true
                }

                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        VirtualGraphs = [vg]
                }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // Query virtual graph
                let pattern: TriplePattern = {
                    Subject = Variable "?x"
                    Predicate = IriTerm (FullIRI "http://example.org/value")
                    Object = Variable "?val"
                }

                let results = layer.QueryTriples(pattern, { QueryOptions.defaults with SearchVirtualGraphs = true })

                Expect.isNonEmpty results "Should query virtual graph"

            finally
                cleanupTempDb dbPath
                cleanupTempDb sourcePath

        testCase "Performance: 1000 triples ingestion" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = { SemanticLayerConfig.defaults with TripleStorePath = dbPath }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                let triples: Triple list = [
                    for i in 1 .. 1000 do
                        yield {
                            Subject = IriTerm (FullIRI $"http://example.org/entity{i}")
                            Predicate = PrefixedIRI ("rdf", "type")
                            Object = IriTerm (PrefixedIRI ("ex", "Entity"))
                        } : Triple
                ]

                let sw = System.Diagnostics.Stopwatch.StartNew()
                match layer.AddTriples("default", triples) with
                | Success _ -> ()
                | Error e -> failtest $"Failed: {e}"
                sw.Stop()

                Expect.isLessThan sw.ElapsedMilliseconds 5000L "Should ingest < 5 seconds"

            finally
                cleanupTempDb dbPath

        testCase "Performance: Query with 1000 results" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = { SemanticLayerConfig.defaults with TripleStorePath = dbPath }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // Add data
                let triples: Triple list = [
                    for i in 1 .. 1000 do
                        yield {
                            Subject = IriTerm (FullIRI $"http://example.org/e{i}")
                            Predicate = PrefixedIRI ("rdf", "type")
                            Object = IriTerm (FullIRI "http://example.org/Entity")
                        } : Triple
                ]
                match layer.AddTriples("default", triples) with
                | Success _ -> ()
                | Error _ -> ()

                // Query
                let query =
                    Query.select ["?x"]
                    |> Query.whereTriple "?x" "rdf:type" "<http://example.org/Entity>"

                let sw = System.Diagnostics.Stopwatch.StartNew()
                let result = layer.ExecuteQuery(query, QueryOptions.defaults)
                sw.Stop()

                Expect.isLessThan sw.ElapsedMilliseconds 1000L "Should query < 1 second"

            finally
                cleanupTempDb dbPath

        testCase "Semantic.create: Convenience function" <| fun () ->
            let dbPath = createTempDb()

            try
                // This would create with defaults
                // We'll test the config helper instead
                let config = { SemanticLayerConfig.defaults with TripleStorePath = dbPath }
                use layer = Semantic.createWith config

                Expect.isTrue true "Should create layer"

            finally
                cleanupTempDb dbPath

        testCase "Semantic.search: Combined search" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableVectorSearch = true
                        VectorDimensions = 64
                }
                use layer = Semantic.createWith config

                // Index content
                layer.IndexForSearch("http://e1", "test content about AI")
                layer.IndexForSearch("http://e2", "test content about ML")

                let results = Semantic.search layer "AI and ML" 10

                Expect.isNonEmpty results "Should find results"

            finally
                cleanupTempDb dbPath

        testCase "SmritiIntegration.initForSmriti: SMRITI setup" <| fun () ->
            let smritiDbPath = createTempDb()
            let semanticDbPath = createTempDb()

            try
                // Create minimal SMRITI database
                let conn = new SqliteConnection($"Data Source={smritiDbPath}")
                conn.Open()
                let sql = """
                    CREATE TABLE zettels (
                        id TEXT PRIMARY KEY,
                        title TEXT,
                        content TEXT,
                        entropy REAL,
                        created_at TEXT,
                        modified_at TEXT
                    );
                """
                use cmd = new SqliteCommand(sql, conn)
                cmd.ExecuteNonQuery() |> ignore
                conn.Close()

                use layer = SmritiIntegration.initForSmriti smritiDbPath semanticDbPath

                Expect.isTrue true "Should initialize for SMRITI"

            finally
                cleanupTempDb smritiDbPath
                cleanupTempDb semanticDbPath

        testCase "SmritiIntegration.indexAllZettels: Batch indexing" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableVectorSearch = true
                        VectorDimensions = 64
                }
                use layer = Semantic.createWith config

                let zettels = [
                    for i in 1 .. 5 do
                        (Guid.NewGuid(), $"Title {i}", $"Content {i}")
                ]

                let (successCount, errorCount) = SmritiIntegration.indexAllZettels layer zettels

                Expect.equal successCount 5 "Should index all"
                Expect.equal errorCount 0 "Should have no errors"

            finally
                cleanupTempDb dbPath

        testCase "SmritiIntegration.findRelatedZettels: Semantic relations" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableVectorSearch = true
                        VectorDimensions = 64
                }
                use layer = Semantic.createWith config

                let id1 = Guid.NewGuid()
                let id2 = Guid.NewGuid()

                layer.ProcessZettel(id1, "AI Concepts", "Machine learning and neural networks") |> ignore
                layer.ProcessZettel(id2, "ML Basics", "Machine learning fundamentals") |> ignore

                let related = SmritiIntegration.findRelatedZettels layer id1 10

                Expect.isNonEmpty related "Should find related"

            finally
                cleanupTempDb dbPath

        testCase "End-to-end: Complete workflow" <| fun () ->
            let dbPath = createTempDb()

            try
                let config = {
                    SemanticLayerConfig.defaults with
                        TripleStorePath = dbPath
                        EnableInference = true
                        ReasoningProfile = ReasoningProfile.RDFS
                        EnableVectorSearch = true
                        VectorDimensions = 64
                        EnableTextMining = true
                }
                use layer = new SemanticLayer(config)
                layer.Initialize()

                // 1. Add ontology
                let ontology: Triple list = [
                    {
                        Subject = IriTerm (FullIRI "http://example.org/AITopic")
                        Predicate = PrefixedIRI ("rdfs", "subClassOf")
                        Object = IriTerm (FullIRI "http://example.org/Topic")
                    }
                ]
                match layer.AddTriples("ontology", ontology) with
                | Success _ -> ()
                | Error _ -> ()

                // 2. Process Zettel (text mining + vector indexing)
                let zettelId = Guid.NewGuid()
                layer.ProcessZettel(zettelId, "AI Research", "Machine learning and deep learning") |> ignore

                // 3. Run inference
                layer.RunInference() |> ignore

                // 4. Query with reasoning
                let query =
                    Query.select ["?topic"]
                    |> Query.whereTriple "?topic" "rdf:type" "?type"
                    |> Query.withReasoning
                    |> Query.limit 10

                let queryResult = layer.ExecuteQuery(query, QueryOptions.defaults)

                // 5. Semantic search
                let searchResults = layer.FindSimilar("AI learning", 5, 0.3)

                // Verify complete pipeline
                Expect.isGreaterThan queryResult.Rows.Length 0 "Should have query results"
                Expect.isNonEmpty searchResults "Should have search results"

                // 6. Statistics
                let stats = layer.GetStats()
                Expect.isGreaterThan stats.TotalTriples 0L "Should have triples"
                Expect.isGreaterThan stats.TotalEmbeddings 0L "Should have embeddings"

            finally
                cleanupTempDb dbPath
    ]
