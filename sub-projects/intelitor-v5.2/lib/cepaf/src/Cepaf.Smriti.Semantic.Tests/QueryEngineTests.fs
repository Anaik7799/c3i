/// Query Engine Tests
///
/// Comprehensive tests for QueryEngine module covering:
/// - Query DSL building
/// - Pattern execution
/// - LIMIT/OFFSET
/// - Reasoning integration
/// - STAMP constraints (SC-SEM-030, SC-SEM-031, SC-SEM-032)
///
/// Version: 1.0.0
module Cepaf.Smriti.Semantic.Tests.QueryEngineTests

open System
open System.IO
open Expecto
open FsCheck
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Semantic

/// Create test database with data
let createQueryDb() =
    let path = Path.GetTempFileName()
    let connStr = $"Data Source={path}"
    let conn = new SqliteConnection(connStr)
    conn.Open()
    TripleStore.initSchema conn
    MaterializedInference.initInferenceSchema conn

    // Add test data
    let triples : Triple list = [
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
            Subject = IriTerm (FullIRI "http://example.org/bob")
            Predicate = PrefixedIRI ("rdf", "type")
            Object = IriTerm (PrefixedIRI ("foaf", "Person"))
        }
        {
            Subject = IriTerm (FullIRI "http://example.org/bob")
            Predicate = PrefixedIRI ("foaf", "name")
            Object = LiteralTerm { Value = "Bob"; Language = None; Datatype = None }
        }
    ]

    TripleStore.addTriples conn "default" triples |> ignore

    (conn, path)

let cleanupQueryDb (conn: SqliteConnection) (path: string) =
    conn.Close()
    conn.Dispose()
    if File.Exists(path) then File.Delete(path)

[<Tests>]
let queryEngineTests =
    testList "QueryEngine" [

        testCase "Query.select: Basic select query" <| fun () ->
            let query = Query.select ["?x"; "?name"]

            Expect.equal query.Type QueryType.Select "Should be SELECT query"
            Expect.equal query.Select.Length 2 "Should select 2 variables"

        testCase "Query.where: Add triple pattern" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "foaf:Person"

            match query.Where with
            | BasicGraphPattern patterns ->
                Expect.equal patterns.Length 1 "Should have 1 pattern"
            | _ -> failtest "Should be BGP"

        testCase "Query.whereTriple: Parse variable" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "foaf:Person"

            match query.Where with
            | BasicGraphPattern [pattern] ->
                match pattern.Subject with
                | Variable v -> Expect.equal v "x" "Should parse variable"
                | _ -> failtest "Should be variable"
            | _ -> failtest "Should have pattern"

        testCase "Query.whereTriple: Parse IRI" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "<http://example.org/Person>"

            match query.Where with
            | BasicGraphPattern [pattern] ->
                match pattern.Object with
                | IriTerm (FullIRI uri) -> Expect.stringContains uri "Person" "Should parse IRI"
                | _ -> failtest "Should be IRI"
            | _ -> failtest "Should have pattern"

        testCase "Query.whereTriple: Parse literal" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "foaf:name" "Alice"

            match query.Where with
            | BasicGraphPattern [pattern] ->
                match pattern.Object with
                | LiteralTerm lit -> Expect.equal lit.Value "Alice" "Should parse literal"
                | _ -> failtest "Should be literal"
            | _ -> failtest "Should have pattern"

        testCase "Query.limit: Set limit" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.limit 10

            Expect.equal query.Limit (Some 10) "Should have limit"

        testCase "Query.offset: Set offset" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.offset 5

            Expect.equal query.Offset (Some 5) "Should have offset"

        testCase "Query.orderBy: Ascending order" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.orderBy "name"

            Expect.equal query.OrderBy.Length 1 "Should have 1 order"
            let (var, asc) = query.OrderBy.[0]
            Expect.equal var "name" "Should order by name"
            Expect.isTrue asc "Should be ascending"

        testCase "Query.orderByDesc: Descending order" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.orderByDesc "age"

            let (_, asc) = query.OrderBy.[0]
            Expect.isFalse asc "Should be descending"

        testCase "Query.withReasoning: Enable reasoning" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.withReasoning

            Expect.isTrue query.Reasoning "Should enable reasoning"

        testCase "Query.from: Add graph" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.from "http://example.org/graph1"

            Expect.equal query.From.Length 1 "Should have 1 graph"

        testCase "Query.ask: ASK query" <| fun () ->
            let pattern = BasicGraphPattern []
            let query = Query.ask pattern

            Expect.equal query.Type QueryType.Ask "Should be ASK query"

        testCase "Query.construct: CONSTRUCT query" <| fun () ->
            let template = []
            let where = BasicGraphPattern []
            let query = Query.construct template where

            Expect.equal query.Type QueryType.Construct "Should be CONSTRUCT query"

        testCase "QueryEngine.execute: Basic query execution" <| fun () ->
            let (conn, path) = createQueryDb()

            let query =
                Query.select ["subject"; "object"]
                |> Query.whereTriple "?subject" "foaf:name" "?object"

            let result = QueryEngine.execute conn query

            Expect.equal result.Rows.Length 2 "Should return 2 results"
            Expect.isGreaterThan result.ExecutionTimeMs 0L "Should record execution time"

            cleanupQueryDb conn path

        testCase "SC-SEM-030: Query timeout < 5 seconds" <| fun () ->
            let (conn, path) = createQueryDb()

            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "foaf:Person"

            let sw = System.Diagnostics.Stopwatch.StartNew()
            let result = QueryEngine.execute conn query
            sw.Stop()

            Expect.isLessThan sw.ElapsedMilliseconds 5000L "Should complete < 5 seconds"

            cleanupQueryDb conn path

        testCase "SC-SEM-031: Result limit enforced" <| fun () ->
            let (conn, path) = createQueryDb()

            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "foaf:Person"
                |> Query.limit 1

            let result = QueryEngine.execute conn query

            Expect.isLessThanOrEqual result.Rows.Length 1 "Should respect limit"

            cleanupQueryDb conn path

        testCase "SC-SEM-032: Explain plan available" <| fun () ->
            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "foaf:Person"
                |> Query.limit 100

            let explanation = QueryEngine.explain query

            Expect.isGreaterThan explanation.EstimatedRows 0 "Should estimate rows"
            Expect.isGreaterThan explanation.EstimatedCost 0.0 "Should estimate cost"

        testCase "QueryEngine.executeWithReasoning: Include inferred" <| fun () ->
            let (conn, path) = createQueryDb()

            // Add inference
            let innerTriple: Triple = {
                Subject = IriTerm (FullIRI "http://example.org/alice")
                Predicate = PrefixedIRI ("rdf", "type")
                Object = IriTerm (FullIRI "http://example.org/Agent")
            }
            let inference : InferredTriple = {
                Triple = innerTriple
                SourceRule = "test"
                Evidence = []
                InferredAt = DateTime.UtcNow
                Confidence = 1.0
            }
            MaterializedInference.persistInferences conn [inference] |> ignore

            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "?type"
                |> Query.withReasoning

            let result = QueryEngine.executeWithReasoning conn query

            Expect.isTrue result.ReasoningApplied "Should apply reasoning"
            Expect.isGreaterThan result.InferencesUsed 0 "Should use inferences"

            cleanupQueryDb conn path

        testCase "Pattern.var: Create variable" <| fun () ->
            let term = Pattern.var "x"

            match term with
            | Variable v -> Expect.equal v "x" "Should create variable"
            | _ -> failtest "Should be variable"

        testCase "Pattern.iri: Create IRI" <| fun () ->
            let term = Pattern.iri "http://example.org/test"

            match term with
            | IriTerm (FullIRI uri) -> Expect.equal uri "http://example.org/test" "Should create IRI"
            | _ -> failtest "Should be IRI"

        testCase "Pattern.prefixed: Create prefixed IRI" <| fun () ->
            let term = Pattern.prefixed "foaf" "Person"

            match term with
            | IriTerm (PrefixedIRI (prefix, local)) ->
                Expect.equal prefix "foaf" "Should have prefix"
                Expect.equal local "Person" "Should have local"
            | _ -> failtest "Should be prefixed IRI"

        testCase "Pattern.lit: Create literal" <| fun () ->
            let term = Pattern.lit "test"

            match term with
            | LiteralTerm lit -> Expect.equal lit.Value "test" "Should create literal"
            | _ -> failtest "Should be literal"

        testCase "Pattern.typedLit: Create typed literal" <| fun () ->
            let term = Pattern.typedLit "42" (PrefixedIRI ("xsd", "integer"))

            match term with
            | LiteralTerm lit ->
                Expect.equal lit.Value "42" "Should have value"
                Expect.isSome lit.Datatype "Should have datatype"
            | _ -> failtest "Should be literal"

        testCase "Pattern.langLit: Create language-tagged literal" <| fun () ->
            let term = Pattern.langLit "Hello" "en"

            match term with
            | LiteralTerm lit ->
                Expect.equal lit.Value "Hello" "Should have value"
                Expect.equal lit.Language (Some "en") "Should have language"
            | _ -> failtest "Should be literal"

        testCase "Pattern.triple: Create triple pattern" <| fun () ->
            let pattern = Pattern.triple (Pattern.var "x") (Pattern.iri "http://example.org/pred") (Pattern.lit "value")

            match pattern.Subject with
            | Variable _ -> Expect.isTrue true "Subject is variable"
            | _ -> failtest "Subject should be variable"

        testCase "Pattern.bgp: Create basic graph pattern" <| fun () ->
            let pattern1 = Pattern.triple (Pattern.var "x") (Pattern.iri "http://p1") (Pattern.var "y")
            let pattern2 = Pattern.triple (Pattern.var "y") (Pattern.iri "http://p2") (Pattern.lit "z")

            let bgp = Pattern.bgp [pattern1; pattern2]

            match bgp with
            | BasicGraphPattern patterns -> Expect.equal patterns.Length 2 "Should have 2 patterns"
            | _ -> failtest "Should be BGP"

        testCase "ExampleQueries.allZettels: Query structure" <| fun () ->
            let query = ExampleQueries.allZettels

            Expect.equal query.Type QueryType.Select "Should be SELECT"
            Expect.equal query.Limit (Some 100) "Should have limit"

        testCase "ExampleQueries.freshZettels: Filter and order" <| fun () ->
            let query = ExampleQueries.freshZettels

            match query.Where with
            | GraphPattern.Filter (expr, _) ->
                Expect.stringContains expr "entropy" "Should filter on entropy"
            | _ -> failtest "Should have filter"

            Expect.isNonEmpty query.OrderBy "Should have order"

        testCase "ExampleQueries.backlinksTo: Parameterized query" <| fun () ->
            let zettelId = Guid.NewGuid()
            let query = ExampleQueries.backlinksTo zettelId

            match query.Where with
            | BasicGraphPattern patterns ->
                Expect.isGreaterThan patterns.Length 0 "Should have patterns"
            | _ -> failtest "Should have BGP"

        testCase "ExampleQueries.relatedConcepts: With reasoning" <| fun () ->
            let query = ExampleQueries.relatedConcepts "http://example.org/concept"

            Expect.isTrue query.Reasoning "Should use reasoning"
            Expect.equal query.Limit (Some 50) "Should have limit"

        testProperty "Query limit is always positive" <| fun (n: int) ->
            (n > 0 && n < 10000) ==> lazy (
                let query = Query.select ["?x"] |> Query.limit n
                query.Limit = Some n
            )

        testCase "Multiple WHERE patterns ANDed" <| fun () ->
            let (conn, path) = createQueryDb()

            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "rdf:type" "foaf:Person"
                |> Query.whereTriple "?x" "foaf:name" "Alice"

            let result = QueryEngine.execute conn query

            Expect.equal result.Rows.Length 1 "Should match both patterns"

            cleanupQueryDb conn path

        testCase "Empty result set" <| fun () ->
            let (conn, path) = createQueryDb()

            let query =
                Query.select ["?x"]
                |> Query.whereTriple "?x" "nonexistent:predicate" "?y"

            let result = QueryEngine.execute conn query

            Expect.isEmpty result.Rows "Should return empty result"

            cleanupQueryDb conn path
    ]
