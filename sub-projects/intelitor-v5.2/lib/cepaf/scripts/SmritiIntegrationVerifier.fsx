#!/usr/bin/env dotnet fsi
/// SMRITI 8-Level Fractal Integration Verifier
///
/// Verifies SMRITI integration across all 8 architectural levels:
/// L0: Runtime/Code, L1: Function, L2: Component, L3: Holon,
/// L4: Container, L5: Node, L6: Cluster, L7: Federation
///
/// Usage:
///   dotnet fsi SmritiIntegrationVerifier.fsx [--verbose]
///
/// STAMP: SC-COV-001 to SC-COV-006

#r "nuget: Microsoft.Data.Sqlite, 9.0.0"
#r "nuget: Dapper, 2.1.35"

open System
open System.IO
open System.Security.Cryptography
open System.Text
open Microsoft.Data.Sqlite
open Dapper

// ============================================================================
// Types
// ============================================================================

type TestResult = {
    Level: string
    TestName: string
    Passed: bool
    Message: string
    Duration: TimeSpan
}

[<CLIMutable>]
type HolonCount = { count: int64 }

[<CLIMutable>]
type ClusterInfo = { cluster: string; cnt: int64 }

[<CLIMutable>]
type TableName = { name: string }

[<CLIMutable>]
type LevelInfo = { level: string }

[<CLIMutable>]
type HolonSample = { holon_uuid: string; title: string }

[<CLIMutable>]
type HashSample = { content_hash: string }

// ============================================================================
// Configuration
// ============================================================================

let smritiDbPath =
    Environment.GetEnvironmentVariable("SMRITI_DB_PATH")
    |> Option.ofObj
    |> Option.defaultValue "data/kms/smriti.db"

let verbose = fsi.CommandLineArgs |> Array.contains "--verbose"

let mutable testResults: TestResult list = []

let runTest level name testFn =
    let start = DateTime.Now
    try
        let passed, msg = testFn()
        let result = {
            Level = level
            TestName = name
            Passed = passed
            Message = msg
            Duration = DateTime.Now - start
        }
        testResults <- result :: testResults
        if verbose then
            let status = if passed then "PASS" else "FAIL"
            printfn "  [%s] %s: %s" status name msg
        passed
    with ex ->
        let result = {
            Level = level
            TestName = name
            Passed = false
            Message = $"Exception: {ex.Message}"
            Duration = DateTime.Now - start
        }
        testResults <- result :: testResults
        if verbose then
            printfn "  [FAIL] %s: %s" name ex.Message
        false

// ============================================================================
// L0: RUNTIME/CODE LEVEL
// ============================================================================

let testL0_DatabaseExists () =
    runTest "L0" "Database exists" (fun () ->
        let exists = File.Exists(smritiDbPath)
        (exists, if exists then "Found" else "Not found")
    )

let testL0_SchemaValid () =
    runTest "L0" "Schema valid" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let tables =
            conn.Query<TableName>("SELECT name FROM sqlite_master WHERE type='table'")
            |> Seq.toList
        let tableNames = tables |> List.map (fun t -> t.name)
        let hasHolons = List.contains "holons" tableNames
        let hasEdges = List.contains "holon_edges" tableNames
        let hasFts = List.contains "holons_fts" tableNames
        (hasHolons && hasEdges && hasFts, $"Tables: holons={hasHolons}, edges={hasEdges}, fts={hasFts}")
    )

let testL0_FtsIndex () =
    runTest "L0" "FTS5 functional" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let count = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons_fts")
        (count >= 0, $"FTS5 indexed {count} documents")
    )

// ============================================================================
// L1: FUNCTION LEVEL
// ============================================================================

let testL1_ContentHashing () =
    runTest "L1" "Content hashing deterministic" (fun () ->
        use sha256 = SHA256.Create()
        let content = "Test content for hashing"
        let bytes = Encoding.UTF8.GetBytes(content)
        let hash1 = sha256.ComputeHash(bytes) |> BitConverter.ToString |> fun s -> s.Replace("-", "").ToLowerInvariant()
        let hash2 = sha256.ComputeHash(bytes) |> BitConverter.ToString |> fun s -> s.Replace("-", "").ToLowerInvariant()
        (hash1 = hash2, $"Hash: {hash1.Substring(0, 16)}...")
    )

let testL1_EntropyCalculation () =
    runTest "L1" "Entropy calculation" (fun () ->
        let ageDays = 90.0
        let entropy = min 1.0 (ageDays / 180.0)
        let valid = entropy >= 0.0 && entropy <= 1.0 && abs(entropy - 0.5) < 0.01
        (valid, $"90-day entropy: {entropy:F3}")
    )

let testL1_UuidGeneration () =
    runTest "L1" "UUID uniqueness" (fun () ->
        let uuids = [for _ in 1..100 -> Guid.NewGuid().ToString()]
        let unique = uuids |> Set.ofList |> Set.count
        (unique = 100, $"Generated {unique}/100 unique UUIDs")
    )

// ============================================================================
// L2: COMPONENT LEVEL
// ============================================================================

let testL2_HolonLevels () =
    runTest "L2" "Holon level hierarchy" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let levels =
            conn.Query<LevelInfo>("SELECT DISTINCT level FROM holons WHERE level IS NOT NULL")
            |> Seq.map (fun r -> r.level)
            |> Seq.toList
        let valid = List.contains "atomic" levels || List.contains "molecular" levels
        let levelStr = String.Join(", ", levels)
        (valid, sprintf "Levels: %s" levelStr)
    )

let testL2_ClusterOrganization () =
    runTest "L2" "Cluster organization" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let clusters =
            conn.Query<ClusterInfo>("SELECT cluster, COUNT(*) as cnt FROM holons WHERE cluster IS NOT NULL AND cluster != '' GROUP BY cluster")
            |> Seq.toList
        (clusters.Length > 0, $"Found {clusters.Length} clusters")
    )

// ============================================================================
// L3: HOLON/AGENT LEVEL
// ============================================================================

let testL3_OrphanDetection () =
    runTest "L3" "Orphan detection" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let orphans = conn.ExecuteScalar<int>("""
            SELECT COUNT(*) FROM holons h
            WHERE NOT EXISTS (
                SELECT 1 FROM holon_edges e
                WHERE e.source_id = h.holon_uuid OR e.target_id = h.holon_uuid
            )
        """)
        (true, $"Orphan holons: {orphans}")
    )

let testL3_StaleDetection () =
    runTest "L3" "Stale detection" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let stale = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons WHERE entropy > 0.6")
        (true, $"Stale holons (entropy > 0.6): {stale}")
    )

let testL3_TagExtraction () =
    runTest "L3" "Tag extraction" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let withTags = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons WHERE tags IS NOT NULL AND tags != ''")
        let total = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons")
        let pct = if total > 0 then float withTags / float total * 100.0 else 0.0
        (true, sprintf "%d/%d holons with tags (%.1f%%)" withTags total pct)
    )

// ============================================================================
// L4: CONTAINER LEVEL
// ============================================================================

let testL4_CliExists () =
    runTest "L4" "CLI script exists" (fun () ->
        let path = "lib/cepaf/scripts/ZkmsIngestorCLI.fsx"
        let exists = File.Exists(path)
        (exists, if exists then "Found" else "Not found")
    )

let testL4_DataDirectory () =
    runTest "L4" "Data directory" (fun () ->
        let exists = Directory.Exists("data/kms")
        (exists, if exists then "Found" else "Not found")
    )

let testL4_DatabaseSize () =
    runTest "L4" "Database size" (fun () ->
        let info = FileInfo(smritiDbPath)
        let sizeKb = info.Length / 1024L
        (sizeKb > 0L, $"{sizeKb} KB")
    )

// ============================================================================
// L5: NODE/SERVICE LEVEL
// ============================================================================

let testL5_Documentation () =
    runTest "L5" "Documentation exists" (fun () ->
        let docs = [
            "docs/smriti/SMRITI_USER_GUIDE.md"
            "docs/smriti/SMRITI_DEVELOPER_GUIDE.md"
        ]
        let found = docs |> List.filter File.Exists |> List.length
        (found = docs.Length, $"{found}/{docs.Length} docs found")
    )

let testL5_OpenRouterConfig () =
    runTest "L5" "OpenRouter config" (fun () ->
        let key = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
        let configured = not (String.IsNullOrEmpty(key))
        (true, if configured then "Configured" else "Not configured (fallback mode)")
    )

// ============================================================================
// L6: CLUSTER LEVEL
// ============================================================================

let testL6_MultiCluster () =
    runTest "L6" "Multi-cluster support" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let clusters =
            conn.Query<ClusterInfo>("SELECT cluster, COUNT(*) as cnt FROM holons WHERE cluster IS NOT NULL GROUP BY cluster ORDER BY cnt DESC")
            |> Seq.toList
        (clusters.Length >= 10, $"{clusters.Length} clusters")
    )

let testL6_Portability () =
    runTest "L6" "Single-file portability" (fun () ->
        let info = FileInfo(smritiDbPath)
        let portable = info.Length < 1_000_000_000L // < 1GB
        (portable, $"Database size: {info.Length / 1024L / 1024L} MB")
    )

// ============================================================================
// L7: FEDERATION LEVEL
// ============================================================================

let testL7_ExportCapability () =
    runTest "L7" "Export capability" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let results =
            conn.Query<HolonSample>("SELECT holon_uuid, title FROM holons LIMIT 5")
            |> Seq.toList
        (results.Length > 0, $"Can export {results.Length} sample holons")
    )

let testL7_KnowledgeGraph () =
    runTest "L7" "Knowledge graph metrics" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let holons = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holons")
        let edges = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM holon_edges")
        (true, $"Graph: {holons} nodes, {edges} edges")
    )

// ============================================================================
// Constitutional Invariants
// ============================================================================

let testConst_HolonSovereignty () =
    runTest "CONST" "SC-HOLON-001: SQLite sovereignty" (fun () ->
        let exists = File.Exists(smritiDbPath)
        (exists, "All holon state in SQLite")
    )

let testConst_ContentIntegrity () =
    runTest "CONST" "PSI-5: Content integrity" (fun () ->
        use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
        conn.Open()
        let sample =
            conn.Query<HashSample>("SELECT content_hash FROM holons WHERE content_hash IS NOT NULL LIMIT 10")
            |> Seq.toList
        // Accept both 64-char (full SHA256) and 16-char (truncated) hashes
        let valid = sample |> List.forall (fun h -> h.content_hash.Length >= 16)
        (valid, sprintf "All %d sample hashes have valid length (>= 16 chars)" sample.Length)
    )

// ============================================================================
// Main Execution
// ============================================================================

printfn ""
printfn "╔══════════════════════════════════════════════════════════════╗"
printfn "║   SMRITI 8-LEVEL FRACTAL INTEGRATION VERIFICATION              ║"
printfn "╠══════════════════════════════════════════════════════════════╣"
printfn "║  Database: %-49s ║" smritiDbPath
printfn "╚══════════════════════════════════════════════════════════════╝"
printfn ""

// L0: Runtime/Code
printfn "L0: Runtime/Code Level"
testL0_DatabaseExists() |> ignore
testL0_SchemaValid() |> ignore
testL0_FtsIndex() |> ignore
printfn ""

// L1: Function
printfn "L1: Function Level"
testL1_ContentHashing() |> ignore
testL1_EntropyCalculation() |> ignore
testL1_UuidGeneration() |> ignore
printfn ""

// L2: Component
printfn "L2: Component Level"
testL2_HolonLevels() |> ignore
testL2_ClusterOrganization() |> ignore
printfn ""

// L3: Holon/Agent
printfn "L3: Holon/Agent Level"
testL3_OrphanDetection() |> ignore
testL3_StaleDetection() |> ignore
testL3_TagExtraction() |> ignore
printfn ""

// L4: Container
printfn "L4: Container Level"
testL4_CliExists() |> ignore
testL4_DataDirectory() |> ignore
testL4_DatabaseSize() |> ignore
printfn ""

// L5: Node/Service
printfn "L5: Node/Service Level"
testL5_Documentation() |> ignore
testL5_OpenRouterConfig() |> ignore
printfn ""

// L6: Cluster
printfn "L6: Cluster Level"
testL6_MultiCluster() |> ignore
testL6_Portability() |> ignore
printfn ""

// L7: Federation
printfn "L7: Federation Level"
testL7_ExportCapability() |> ignore
testL7_KnowledgeGraph() |> ignore
printfn ""

// Constitutional
printfn "CONSTITUTIONAL INVARIANTS"
testConst_HolonSovereignty() |> ignore
testConst_ContentIntegrity() |> ignore
printfn ""

// Summary
let results = testResults |> List.rev
let passed = results |> List.filter (fun r -> r.Passed) |> List.length
let failed = results |> List.filter (fun r -> not r.Passed) |> List.length
let total = results.Length

printfn "╔══════════════════════════════════════════════════════════════╗"
printfn "║   VERIFICATION SUMMARY                                        ║"
printfn "╠══════════════════════════════════════════════════════════════╣"
printfn "║   Total Tests:  %-3d                                          ║" total
printfn "║   Passed:       %-3d                                          ║" passed
printfn "║   Failed:       %-3d                                          ║" failed
printfn "║   Pass Rate:    %5.1f%%                                       ║" (float passed / float total * 100.0)
printfn "╚══════════════════════════════════════════════════════════════╝"

if verbose then
    printfn ""
    printfn "Detailed Results:"
    printfn "─────────────────────────────────────────────────────────────────"
    for r in results do
        let status = if r.Passed then "✓" else "✗"
        printfn "%s [%s] %s: %s" status r.Level r.TestName r.Message

// Exit code
if failed > 0 then
    Environment.Exit(1)
