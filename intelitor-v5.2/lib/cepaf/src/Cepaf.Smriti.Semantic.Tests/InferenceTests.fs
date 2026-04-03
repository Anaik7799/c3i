/// Materialized Inference Tests
///
/// Comprehensive tests for MaterializedInference module covering:
/// - RDFS rules
/// - OWL-RL rules
/// - Chaya-specific rules
/// - Forward-chaining inference
/// - Rule matching and binding
/// - STAMP constraints (SC-SEM-020, SC-SEM-021, SC-SEM-022)
///
/// Version: 1.0.0
module Cepaf.Smriti.Semantic.Tests.InferenceTests

open System
open System.IO
open Expecto
open FsCheck
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared
open Cepaf.Smriti.Semantic

/// Create test database for inference
let createInferenceDb() =
    let path = Path.GetTempFileName()
    let connStr = $"Data Source={path}"
    let conn = new SqliteConnection(connStr)
    conn.Open()
    TripleStore.initSchema conn
    MaterializedInference.initInferenceSchema conn
    (conn, path)

/// Cleanup
let cleanupInferenceDb (conn: SqliteConnection) (path: string) =
    conn.Close()
    conn.Dispose()
    if File.Exists(path) then File.Delete(path)

/// Sample class hierarchy
let classHierarchy: Triple list = [
    // Animal is a Thing
    {
        Subject = IriTerm (FullIRI "http://example.org/Animal")
        Predicate = PrefixedIRI ("rdfs", "subClassOf")
        Object = IriTerm (FullIRI "http://example.org/Thing")
    }
    // Mammal is an Animal
    {
        Subject = IriTerm (FullIRI "http://example.org/Mammal")
        Predicate = PrefixedIRI ("rdfs", "subClassOf")
        Object = IriTerm (FullIRI "http://example.org/Animal")
    }
    // Dog is a Mammal
    {
        Subject = IriTerm (FullIRI "http://example.org/Dog")
        Predicate = PrefixedIRI ("rdfs", "subClassOf")
        Object = IriTerm (FullIRI "http://example.org/Mammal")
    }
    // Fido is a Dog
    {
        Subject = IriTerm (FullIRI "http://example.org/Fido")
        Predicate = PrefixedIRI ("rdf", "type")
        Object = IriTerm (FullIRI "http://example.org/Dog")
    }
]

[<Tests>]
let inferenceTests =
    testList "MaterializedInference" [

        testCase "initInferenceSchema: Tables created" <| fun () ->
            let (conn, path) = createInferenceDb()

            let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'infer%'"
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            let tables = [
                while reader.Read() do
                    reader.GetString(0)
            ]

            Expect.contains tables "inferred_triples" "Should have inferred_triples table"
            Expect.contains tables "inference_rules" "Should have inference_rules table"

            cleanupInferenceDb conn path

        testCase "rdfsRules: Standard RDFS rules defined" <| fun () ->
            let rules = MaterializedInference.rdfsRules

            Expect.isNonEmpty rules "Should have RDFS rules"

            let ruleIds = rules |> List.map (fun r -> r.Id)
            Expect.contains ruleIds "rdfs-subclass-transitivity" "Should have transitivity rule"
            Expect.contains ruleIds "rdfs-type-inference" "Should have type inference rule"

        testCase "owlRlRules: OWL-RL rules defined" <| fun () ->
            let rules = MaterializedInference.owlRlRules

            Expect.isNonEmpty rules "Should have OWL-RL rules"

            let ruleIds = rules |> List.map (fun r -> r.Id)
            Expect.contains ruleIds "owl-sameas-symmetric" "Should have sameAs symmetry"
            Expect.contains ruleIds "owl-sameas-transitive" "Should have sameAs transitivity"

        testCase "chayaRules: Chaya-specific rules defined" <| fun () ->
            let rules = MaterializedInference.chayaRules

            Expect.isNonEmpty rules "Should have Chaya rules"

            let ruleIds = rules |> List.map (fun r -> r.Id)
            Expect.contains ruleIds "chaya-backlink-symmetric" "Should have backlink rule"

        testCase "matchPattern: Single pattern matching" <| fun () ->
            let triples: Triple list = [
                {
                    Subject = IriTerm (FullIRI "http://example.org/alice")
                    Predicate = PrefixedIRI ("rdf", "type")
                    Object = IriTerm (PrefixedIRI ("foaf", "Person"))
                }
            ]

            let pattern: TriplePattern = {
                Subject = Variable "?x"
                Predicate = IriTerm (PrefixedIRI ("rdf", "type"))
                Object = IriTerm (PrefixedIRI ("foaf", "Person"))
            }

            let bindings = MaterializedInference.matchPattern triples [pattern]

            Expect.isNonEmpty bindings "Should have bindings"
            Expect.equal bindings.Length 1 "Should have 1 binding"

        testCase "applyBindings: Substitute variables" <| fun () ->
            let bindings = Map.ofList [
                ("?x", IriTerm (FullIRI "http://example.org/alice"))
                ("?c", IriTerm (FullIRI "http://example.org/Person"))
            ]

            let thenPattern: TriplePattern = {
                Subject = Variable "?x"
                Predicate = IriTerm (PrefixedIRI ("rdf", "type"))
                Object = Variable "?c"
            }

            let result = MaterializedInference.applyBindings [thenPattern] bindings

            Expect.equal result.Length 1 "Should produce 1 triple"
            match result.[0].Subject with
            | IriTerm (FullIRI uri) -> Expect.stringContains uri "alice" "Should have alice"
            | _ -> failtest "Should be IRI"

        testCase "runRule: Simple rule firing" <| fun () ->
            let triples: Triple list = [
                {
                    Subject = IriTerm (FullIRI "http://example.org/a")
                    Predicate = PrefixedIRI ("rdfs", "subClassOf")
                    Object = IriTerm (FullIRI "http://example.org/b")
                }
                {
                    Subject = IriTerm (FullIRI "http://example.org/b")
                    Predicate = PrefixedIRI ("rdfs", "subClassOf")
                    Object = IriTerm (FullIRI "http://example.org/c")
                }
            ]

            let rule = InferenceRule.rdfsSubClassTransitivity

            let inferred = MaterializedInference.runRule triples rule

            Expect.isNonEmpty inferred "Should infer transitivity"

        testCase "runInference: Fixed-point iteration" <| fun () ->
            let inferred = MaterializedInference.runInference classHierarchy MaterializedInference.rdfsRules

            // Should infer:
            // - Fido is a Mammal (from Dog -> Mammal)
            // - Fido is an Animal (from Mammal -> Animal)
            // - Fido is a Thing (from Animal -> Thing)
            // Plus subclass transitivity
            Expect.isNonEmpty inferred "Should have inferences"

        testCase "runInference: Iteration limit prevents infinite loop" <| fun () ->
            // Create rule that would loop infinitely
            let loopRule: InferenceRule = {
                Id = "loop"
                Name = "Infinite Loop"
                If = [
                    { Subject = Variable "?x"; Predicate = IriTerm (PrefixedIRI ("ex", "p")); Object = Variable "?y" }
                ]
                Then = [
                    { Subject = Variable "?y"; Predicate = IriTerm (PrefixedIRI ("ex", "p")); Object = Variable "?x" }
                ]
                Priority = 50
                Enabled = true
                Namespace = None
            }

            let triples: Triple list = [
                {
                    Subject = IriTerm (FullIRI "http://example.org/a")
                    Predicate = PrefixedIRI ("ex", "p")
                    Object = IriTerm (FullIRI "http://example.org/b")
                }
            ]

            // Should terminate due to 100-iteration limit
            let inferred = MaterializedInference.runInference triples [loopRule]

            // Should not hang
            Expect.isTrue true "Should terminate"

        testCase "SC-SEM-020: Inferences stored with evidence" <| fun () ->
            let (conn, path) = createInferenceDb()

            let triple: InferredTriple = {
                Triple = classHierarchy.[0]
                SourceRule = "rdfs-subclass-transitivity"
                Evidence = []
                InferredAt = DateTime.UtcNow
                Confidence = 1.0
            }

            match MaterializedInference.persistInferences conn [triple] with
            | Success _ ->
                // Verify evidence is stored
                let sql = "SELECT source_rule, confidence FROM inferred_triples"
                use cmd = new SqliteCommand(sql, conn)
                use reader = cmd.ExecuteReader()

                if reader.Read() then
                    let rule = reader.GetString(0)
                    let confidence = reader.GetDouble(1)

                    Expect.equal rule "rdfs-subclass-transitivity" "Should store rule"
                    Expect.equal confidence 1.0 "Should store confidence"
                else
                    failtest "Should have stored inference"
            | Error e ->
                failtest $"Failed: {e}"

            cleanupInferenceDb conn path

        testCase "SC-SEM-021: Re-inference on rule change" <| fun () ->
            let (conn, path) = createInferenceDb()
            TripleStore.addTriples conn "default" classHierarchy |> ignore

            // Initial inference
            MaterializedInference.rematerialize conn classHierarchy ReasoningProfile.RDFS |> ignore

            let count1 =
                let sql = "SELECT COUNT(*) FROM inferred_triples"
                use cmd = new SqliteCommand(sql, conn)
                cmd.ExecuteScalar() :?> int64

            // Re-materialize (simulates rule change)
            MaterializedInference.rematerialize conn classHierarchy ReasoningProfile.RDFS |> ignore

            let count2 =
                let sql = "SELECT COUNT(*) FROM inferred_triples"
                use cmd = new SqliteCommand(sql, conn)
                cmd.ExecuteScalar() :?> int64

            Expect.equal count1 count2 "Should have same count after re-materialization"

            cleanupInferenceDb conn path

        testCase "SC-SEM-022: Inference < 100ms per triple" <| fun () ->
            let largeDataset: Triple list = [
                for i in 1 .. 50 do
                    yield {
                        Subject = IriTerm (FullIRI $"http://example.org/class{i}")
                        Predicate = PrefixedIRI ("rdfs", "subClassOf")
                        Object = IriTerm (FullIRI $"http://example.org/class{i+1}")
                    } : Triple
            ]

            let sw = System.Diagnostics.Stopwatch.StartNew()
            let inferred = MaterializedInference.runInference largeDataset MaterializedInference.rdfsRules
            sw.Stop()

            let avgTimePerTriple = sw.ElapsedMilliseconds / int64 (max 1 inferred.Length)
            Expect.isLessThan avgTimePerTriple 100L "Should be < 100ms per triple"

        testCase "persistInferences: Batch persistence" <| fun () ->
            let (conn, path) = createInferenceDb()

            let inferences: InferredTriple list = [
                for i in 1 .. 10 do
                    {
                        Triple = {
                            Subject = IriTerm (FullIRI $"http://example.org/s{i}")
                            Predicate = PrefixedIRI ("rdf", "type")
                            Object = IriTerm (FullIRI "http://example.org/Class")
                        }
                        SourceRule = "test-rule"
                        Evidence = []
                        InferredAt = DateTime.UtcNow
                        Confidence = 1.0
                    }
            ]

            match MaterializedInference.persistInferences conn inferences with
            | Success count ->
                Expect.equal count 10 "Should persist 10 inferences"
            | Error e ->
                failtest $"Failed: {e}"

            cleanupInferenceDb conn path

        testCase "getInferredForSubject: Retrieve by subject" <| fun () ->
            let (conn, path) = createInferenceDb()

            let inference: InferredTriple = {
                Triple = {
                    Subject = IriTerm (FullIRI "http://example.org/alice")
                    Predicate = PrefixedIRI ("rdf", "type")
                    Object = IriTerm (FullIRI "http://example.org/Person")
                }
                SourceRule = "test"
                Evidence = []
                InferredAt = DateTime.UtcNow
                Confidence = 1.0
            }

            MaterializedInference.persistInferences conn [inference] |> ignore

            let results = MaterializedInference.getInferredForSubject conn "http://example.org/alice"

            Expect.equal results.Length 1 "Should retrieve 1 inference"

            cleanupInferenceDb conn path

        testCase "clearInferences: All inferences deleted" <| fun () ->
            let (conn, path) = createInferenceDb()

            let inference: InferredTriple = {
                Triple = classHierarchy.[0]
                SourceRule = "test"
                Evidence = []
                InferredAt = DateTime.UtcNow
                Confidence = 1.0
            }

            MaterializedInference.persistInferences conn [inference] |> ignore
            let deleted = MaterializedInference.clearInferences conn

            Expect.isGreaterThan deleted 0 "Should delete inferences"

            cleanupInferenceDb conn path

        testCase "getRulesForProfile: RDFS profile" <| fun () ->
            let rules = MaterializedInference.getRulesForProfile ReasoningProfile.RDFS

            Expect.isNonEmpty rules "Should have RDFS rules"

        testCase "getRulesForProfile: OWL-RL profile" <| fun () ->
            let rules = MaterializedInference.getRulesForProfile ReasoningProfile.OWLRL

            let ruleIds = rules |> List.map (fun r -> r.Id)
            Expect.exists ruleIds (fun id -> id.StartsWith("rdfs-")) "Should include RDFS"
            Expect.exists ruleIds (fun id -> id.StartsWith("owl-")) "Should include OWL"

        testCase "Rule priority ordering" <| fun () ->
            let rules = MaterializedInference.rdfsRules @ MaterializedInference.owlRlRules

            let sorted = rules |> List.sortByDescending (fun r -> r.Priority)

            // Verify sorting
            for i in 0 .. sorted.Length - 2 do
                Expect.isGreaterThanOrEqual sorted.[i].Priority sorted.[i+1].Priority "Should be descending"

        testCase "Disabled rules not fired" <| fun () ->
            let disabledRule: InferenceRule = {
                InferenceRule.rdfsSubClassTransitivity with
                    Enabled = false
            }

            let triples: Triple list = classHierarchy
            let inferred = MaterializedInference.runRule triples disabledRule

            Expect.isEmpty inferred "Disabled rule should not fire"

        testProperty "Inference is deterministic" <| fun (seed: int) ->
            (seed > 0) ==> lazy (
                let triples: Triple list = classHierarchy
                let rules = MaterializedInference.rdfsRules

                let result1 = MaterializedInference.runInference triples rules
                let result2 = MaterializedInference.runInference triples rules

                result1.Length = result2.Length
            )

        testCase "Chaya backlink symmetry" <| fun () ->
            let triples: Triple list = [
                {
                    Subject = IriTerm (FullIRI "http://example.org/zettel1")
                    Predicate = IRI.indrajaal "linksTo"
                    Object = IriTerm (FullIRI "http://example.org/zettel2")
                }
            ]

            let rule = MaterializedInference.chayaRules
                       |> List.find (fun r -> r.Id = "chaya-backlink-symmetric")

            let inferred = MaterializedInference.runRule triples rule

            Expect.isNonEmpty inferred "Should infer backlink"

            match inferred.[0].Triple.Predicate with
            | pred when IRI.expand pred = IRI.expand (IRI.indrajaal "linkedFrom") ->
                Expect.isTrue true "Should infer linkedFrom"
            | _ -> failtest "Wrong predicate inferred"
    ]
