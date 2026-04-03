/// Semantic Layer Test Runner
///
/// Expecto test runner for all Semantic Layer tests.
/// Aggregates and executes:
/// - TripleStore tests
/// - VirtualGraph tests
/// - Inference tests
/// - QueryEngine tests
/// - VectorSimilarity tests
/// - Integration tests
///
/// Usage:
///   dotnet run --project Cepaf.Smriti.Semantic.Tests.fsproj
///   dotnet run --project Cepaf.Smriti.Semantic.Tests.fsproj -- --filter TripleStore
///   dotnet run --project Cepaf.Smriti.Semantic.Tests.fsproj -- --summary
///
/// Version: 1.0.0
module Cepaf.Smriti.Semantic.Tests.Program

open Expecto

/// Aggregate all test suites
let allTests =
    testList "Semantic Layer Test Suite" [
        TripleStoreTests.tripleStoreTests
        VirtualGraphTests.virtualGraphTests
        InferenceTests.inferenceTests
        QueryEngineTests.queryEngineTests
        VectorSimilarityTests.vectorSimilarityTests
        IntegrationTests.integrationTests
    ]

/// Test configuration
let config =
    { defaultConfig with
        /// Verbose output
        verbosity = Logging.LogLevel.Info
        /// Fail fast on first error (optional)
        failOnFocusedTests = true
    }

[<EntryPoint>]
let main args =
    printfn """
╔════════════════════════════════════════════════════════════════╗
║  Semantic Layer Test Suite v1.0.0                             ║
║  Comprehensive tests for RDF Triple Store & Semantic Graph    ║
╠════════════════════════════════════════════════════════════════╣
║  Test Modules:                                                 ║
║  - TripleStore: CRUD, pattern matching, indexing              ║
║  - VirtualGraph: SQL-to-RDF mapping, caching                  ║
║  - Inference: RDFS/OWL-RL rules, forward-chaining             ║
║  - QueryEngine: SPARQL-like DSL, execution                    ║
║  - VectorSimilarity: Embeddings, cosine similarity, k-NN      ║
║  - Integration: Full pipeline workflows                       ║
║                                                                 ║
║  STAMP Constraints Verified:                                   ║
║  - SC-SEM-005: Append-only register                           ║
║  - SC-SEM-006: SQLite WAL mode                                ║
║  - SC-SEM-007: Index coverage                                 ║
║  - SC-SEM-010: Virtual graphs read-only                       ║
║  - SC-SEM-011: Cache invalidation                             ║
║  - SC-SEM-012: Query translation < 10ms                       ║
║  - SC-SEM-020: Inference evidence tracking                    ║
║  - SC-SEM-021: Re-inference on rule change                    ║
║  - SC-SEM-022: Inference < 100ms per triple                   ║
║  - SC-SEM-030: Query timeout < 5 seconds                      ║
║  - SC-SEM-031: Result limit enforced                          ║
║  - SC-SEM-032: Explain plan available                         ║
║  - SC-SEM-040: Embeddings stored as float32                   ║
║  - SC-SEM-041: Similarity search < 100ms                      ║
║  - SC-SEM-042: K-NN approximate for large sets                ║
╚════════════════════════════════════════════════════════════════╝
"""

    // Run tests
    let result = runTestsWithCLIArgs [] args allTests

    // Print summary
    printfn """
╔════════════════════════════════════════════════════════════════╗
║  Test Run Complete                                             ║
╚════════════════════════════════════════════════════════════════╝
"""

    result
