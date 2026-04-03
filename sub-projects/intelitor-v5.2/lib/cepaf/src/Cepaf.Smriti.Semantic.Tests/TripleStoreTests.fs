/// Triple Store Tests
///
/// Comprehensive tests for TripleStore module covering:
/// - CRUD operations
/// - Pattern matching
/// - Graph operations
/// - Zettel linking
/// - STAMP constraints (SC-SEM-005, SC-SEM-006, SC-SEM-007)
///
/// Version: 1.0.0
module Cepaf.Smriti.Semantic.Tests.TripleStoreTests

open System
open System.IO
open Expecto
open FsCheck
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Semantic

/// Test database helper
let createTestDb() =
    let path = Path.GetTempFileName()
    let config = { TripleStore.defaultConfig with DatabasePath = path }
    match TripleStore.openStore config with
    | Success conn -> conn
    | Error e -> failwith $"Failed to create test DB: {e}"

/// Cleanup test database
let cleanupTestDb (conn: SqliteConnection) =
    let path = conn.DataSource.Replace("Data Source=", "")
    conn.Close()
    conn.Dispose()
    if File.Exists(path) then File.Delete(path)

/// Sample triples for testing
let sampleTriples: Triple list = [
    {
        Subject = IriTerm (FullIRI "http://example.org/alice")
        Predicate = PrefixedIRI ("rdf", "type")
        Object = IriTerm (PrefixedIRI ("foaf", "Person"))
    }
    {
        Subject = IriTerm (FullIRI "http://example.org/alice")
        Predicate = PrefixedIRI ("foaf", "name")
        Object = LiteralTerm { Value = "Alice"; Language = None; Datatype = None }
    }
    {
        Subject = IriTerm (FullIRI "http://example.org/alice")
        Predicate = PrefixedIRI ("foaf", "age")
        Object = LiteralTerm { Value = "30"; Language = None; Datatype = Some (PrefixedIRI ("xsd", "integer")) }
    }
]

[<Tests>]
let tripleStoreTests =
    testList "TripleStore" [

        testCase "SC-SEM-006: Database opens with WAL mode" <| fun () ->
            let conn = createTestDb()

            // Verify WAL mode
            use cmd = new SqliteCommand("PRAGMA journal_mode", conn)
            let mode = cmd.ExecuteScalar() :?> string
            Expect.equal mode "wal" "Should use WAL mode"

            cleanupTestDb conn

        testCase "SC-SEM-007: All required indexes exist" <| fun () ->
            let conn = createTestDb()

            let sql = "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='triples'"
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let indexes = [
                while reader.Read() do
                    reader.GetString(0)
            ]

            Expect.contains indexes "idx_triples_spo" "SPO index should exist"
            Expect.contains indexes "idx_triples_pos" "POS index should exist"
            Expect.contains indexes "idx_triples_osp" "OSP index should exist"
            Expect.contains indexes "idx_triples_graph" "Graph index should exist"

            cleanupTestDb conn

        testCase "addTriple: Single triple insertion" <| fun () ->
            let conn = createTestDb()

            let triple = sampleTriples.[0]
            let count = TripleStore.addTriple conn "default" triple

            Expect.equal count 1 "Should insert 1 triple"

            cleanupTestDb conn

        testCase "addTriples: Bulk insertion with transaction" <| fun () ->
            let conn = createTestDb()

            match TripleStore.addTriples conn "default" sampleTriples with
            | Success count ->
                Expect.equal count 3 "Should insert 3 triples"
            | Error e ->
                failtest $"Failed to add triples: {e}"

            cleanupTestDb conn

        testCase "queryTriples: Query all triples" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let results = TripleStore.queryTriples conn None None None None

            Expect.equal results.Length 3 "Should retrieve 3 triples"

            cleanupTestDb conn

        testCase "queryTriples: Query by subject" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let results = TripleStore.queryTriples conn None (Some "http://example.org/alice") None None

            Expect.equal results.Length 3 "Should retrieve 3 triples for Alice"

            cleanupTestDb conn

        testCase "queryTriples: Query by predicate" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let predUri = IRI.expand (PrefixedIRI ("foaf", "name"))
            let results = TripleStore.queryTriples conn None None (Some predUri) None

            Expect.equal results.Length 1 "Should retrieve 1 triple with foaf:name"

            cleanupTestDb conn

        testCase "queryTriples: Query by object literal" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let results = TripleStore.queryTriples conn None None None (Some "Alice")

            Expect.equal results.Length 1 "Should retrieve triple with Alice literal"

            cleanupTestDb conn

        testCase "queryByPattern: Variable subject matches all" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let pattern: TriplePattern = {
                Subject = Variable "?x"
                Predicate = IriTerm (PrefixedIRI ("rdf", "type"))
                Object = IriTerm (PrefixedIRI ("foaf", "Person"))
            }

            let results = TripleStore.queryByPattern conn None pattern

            Expect.equal results.Length 1 "Should match 1 person"

            cleanupTestDb conn

        testCase "deleteTriples: Delete by pattern" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let deleted = TripleStore.deleteTriples conn None (Some "http://example.org/alice") None None

            Expect.equal deleted 3 "Should delete 3 triples"

            let remaining = TripleStore.queryTriples conn None None None None
            Expect.isEmpty remaining "No triples should remain"

            cleanupTestDb conn

        testCase "deleteTriples: Safety - no delete without conditions" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let deleted = TripleStore.deleteTriples conn None None None None

            Expect.equal deleted 0 "Should not delete without conditions"

            cleanupTestDb conn

        testCase "getSubjectTriples: Get all triples for subject" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let results = TripleStore.getSubjectTriples conn "http://example.org/alice"

            Expect.equal results.Length 3 "Should get 3 triples for Alice"

            cleanupTestDb conn

        testCase "getStats: Statistics reporting" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let stats = TripleStore.getStats conn

            Expect.equal stats.TotalTriples 3L "Should have 3 triples"
            Expect.equal stats.GraphCount 1 "Should have 1 graph"
            Expect.isGreaterThan stats.SubjectCount 0L "Should have subjects"
            Expect.isGreaterThan stats.PredicateCount 0L "Should have predicates"

            cleanupTestDb conn

        testCase "linkZettelToTriple: Link Zettel to triple" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let zettelId = Guid.NewGuid()
            let result = TripleStore.linkZettelToTriple conn zettelId 1L "subject"

            Expect.equal result 1 "Should link 1 Zettel"

            cleanupTestDb conn

        testCase "getZettelTriples: Get triples for Zettel" <| fun () ->
            let conn = createTestDb()
            TripleStore.addTriples conn "default" sampleTriples |> ignore

            let zettelId = Guid.NewGuid()
            TripleStore.linkZettelToTriple conn zettelId 1L "subject" |> ignore

            let triples = TripleStore.getZettelTriples conn zettelId

            Expect.isNonEmpty triples "Should retrieve linked triples"

            cleanupTestDb conn

        testCase "Named graph: Separate graphs" <| fun () ->
            let conn = createTestDb()

            TripleStore.addTriple conn "graph1" sampleTriples.[0] |> ignore
            TripleStore.addTriple conn "graph2" sampleTriples.[1] |> ignore

            let g1 = TripleStore.queryTriples conn (Some "graph1") None None None
            let g2 = TripleStore.queryTriples conn (Some "graph2") None None None

            Expect.equal g1.Length 1 "Graph 1 should have 1 triple"
            Expect.equal g2.Length 1 "Graph 2 should have 1 triple"

            cleanupTestDb conn

        testProperty "Roundtrip: Serialize/deserialize RdfTerm" <| fun (value: string) ->
            let term = LiteralTerm { Value = value; Language = None; Datatype = None }
            let (serialized, termType, lang, datatype) = TripleStore.serializeTerm term
            let deserialized = TripleStore.deserializeTerm serialized termType lang datatype

            deserialized = term

        testProperty "Triple uniqueness: Duplicate triples not inserted" <| fun (subject: string) ->
            (subject <> null && subject.Length > 0) ==> lazy (
                let conn = createTestDb()

                let triple: Triple = {
                    Subject = IriTerm (FullIRI $"http://example.org/{subject}")
                    Predicate = PrefixedIRI ("rdf", "type")
                    Object = IriTerm (PrefixedIRI ("foaf", "Person"))
                }

                TripleStore.addTriple conn "default" triple |> ignore
                let count2 = TripleStore.addTriple conn "default" triple

                cleanupTestDb conn
                count2 = 0 // Second insert should be ignored
            )

        testCase "SC-SEM-022: Large dataset performance < 100ms per triple" <| fun () ->
            let conn = createTestDb()

            let largeDataset: Triple list = [
                for i in 1 .. 100 do
                    {
                        Subject = IriTerm (FullIRI $"http://example.org/person{i}")
                        Predicate = PrefixedIRI ("rdf", "type")
                        Object = IriTerm (PrefixedIRI ("foaf", "Person"))
                    } : Triple
            ]

            let sw = System.Diagnostics.Stopwatch.StartNew()
            match TripleStore.addTriples conn "default" largeDataset with
            | Success _ -> ()
            | Error e -> failtest $"Failed: {e}"
            sw.Stop()

            let avgTimePerTriple = sw.ElapsedMilliseconds / 100L
            Expect.isLessThan avgTimePerTriple 100L "Should be < 100ms per triple"

            cleanupTestDb conn

        testCase "Literal datatype preservation" <| fun () ->
            let conn = createTestDb()

            let triple: Triple = {
                Subject = IriTerm (FullIRI "http://example.org/x")
                Predicate = PrefixedIRI ("ex", "value")
                Object = LiteralTerm {
                    Value = "42"
                    Language = None
                    Datatype = Some (PrefixedIRI ("xsd", "integer"))
                }
            }

            TripleStore.addTriple conn "default" triple |> ignore
            let results = TripleStore.queryTriples conn None (Some "http://example.org/x") None None

            match results.[0].Object with
            | LiteralTerm lit ->
                Expect.equal lit.Value "42" "Value should be preserved"
                Expect.isSome lit.Datatype "Datatype should be preserved"
            | _ -> failtest "Should be literal"

            cleanupTestDb conn

        testCase "Blank node handling" <| fun () ->
            let conn = createTestDb()

            let triple: Triple = {
                Subject = BlankNode "b1"
                Predicate = PrefixedIRI ("rdf", "type")
                Object = IriTerm (PrefixedIRI ("foaf", "Person"))
            }

            TripleStore.addTriple conn "default" triple |> ignore
            let results = TripleStore.queryTriples conn None (Some "_:b1") None None

            Expect.equal results.Length 1 "Should retrieve blank node triple"

            cleanupTestDb conn
    ]
