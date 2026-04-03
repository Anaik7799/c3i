#!/usr/bin/env dotnet fsi
/// SMRITI Edge Generator
///
/// Generates edges between holons based on:
/// 1. Tag overlap (shared tags)
/// 2. Cluster proximity (same cluster)
/// 3. Title similarity (keyword matching)
/// 4. Content similarity (TF-IDF based)
///
/// Usage:
///   dotnet fsi SmritiEdgeGenerator.fsx [--min-score 0.3] [--max-edges 5]
///
/// STAMP: SC-SMRITI-030 to SC-SMRITI-035

#r "nuget: Microsoft.Data.Sqlite, 9.0.0"
#r "nuget: Dapper, 2.1.35"

open System
open System.IO
open System.Text.RegularExpressions
open Microsoft.Data.Sqlite
open Dapper

// ============================================================================
// Types
// ============================================================================

[<CLIMutable>]
type Holon = {
    holon_uuid: string
    title: string
    content: string
    tags: string
    cluster: string
    level: string
}

[<CLIMutable>]
type EdgeCount = { count: int64 }

// ============================================================================
// Configuration
// ============================================================================

let smritiDbPath =
    Environment.GetEnvironmentVariable("SMRITI_DB_PATH")
    |> Option.ofObj
    |> Option.defaultValue "data/kms/smriti.db"

let args = fsi.CommandLineArgs |> Array.toList

let minScore =
    match args |> List.tryFindIndex ((=) "--min-score") with
    | Some i when i + 1 < args.Length -> float args.[i + 1]
    | _ -> 0.25

let maxEdgesPerHolon =
    match args |> List.tryFindIndex ((=) "--max-edges") with
    | Some i when i + 1 < args.Length -> int args.[i + 1]
    | _ -> 5

// ============================================================================
// Text Processing
// ============================================================================

let stopWords =
    set ["the"; "a"; "an"; "is"; "are"; "was"; "were"; "be"; "been"; "being";
         "have"; "has"; "had"; "do"; "does"; "did"; "will"; "would"; "could";
         "should"; "may"; "might"; "must"; "shall"; "can"; "need"; "dare";
         "ought"; "used"; "to"; "of"; "in"; "for"; "on"; "with"; "at"; "by";
         "from"; "as"; "into"; "through"; "during"; "before"; "after"; "above";
         "below"; "between"; "under"; "again"; "further"; "then"; "once"; "here";
         "there"; "when"; "where"; "why"; "how"; "all"; "each"; "few"; "more";
         "most"; "other"; "some"; "such"; "no"; "nor"; "not"; "only"; "own";
         "same"; "so"; "than"; "too"; "very"; "just"; "and"; "but"; "if"; "or";
         "because"; "until"; "while"; "this"; "that"; "these"; "those"; "it";
         "its"; "also"; "any"; "both"; "which"; "what"; "who"; "whom"; "whose"]

let tokenize (text: string) : string list =
    Regex.Matches(text.ToLowerInvariant(), @"\b[a-z]{3,}\b")
    |> Seq.cast<Match>
    |> Seq.map (fun m -> m.Value)
    |> Seq.filter (fun w -> not (Set.contains w stopWords))
    |> Seq.toList

let extractKeywords (text: string) : Set<string> =
    tokenize text |> Set.ofList

// ============================================================================
// Similarity Scoring
// ============================================================================

let tagSimilarity (tags1: string) (tags2: string) : float =
    if String.IsNullOrWhiteSpace(tags1) || String.IsNullOrWhiteSpace(tags2) then 0.0
    else
        let t1 = tags1.Split([|','; ';'|], StringSplitOptions.RemoveEmptyEntries) |> Array.map (fun s -> s.Trim().ToLower()) |> Set.ofArray
        let t2 = tags2.Split([|','; ';'|], StringSplitOptions.RemoveEmptyEntries) |> Array.map (fun s -> s.Trim().ToLower()) |> Set.ofArray
        if Set.isEmpty t1 || Set.isEmpty t2 then 0.0
        else
            let intersection = Set.intersect t1 t2 |> Set.count |> float
            let union = Set.union t1 t2 |> Set.count |> float
            intersection / union  // Jaccard similarity

let clusterSimilarity (c1: string) (c2: string) : float =
    if String.IsNullOrWhiteSpace(c1) || String.IsNullOrWhiteSpace(c2) then 0.0
    elif c1.ToLower() = c2.ToLower() then 1.0
    else 0.0

let titleSimilarity (t1: string) (t2: string) : float =
    let k1 = extractKeywords t1
    let k2 = extractKeywords t2
    if Set.isEmpty k1 || Set.isEmpty k2 then 0.0
    else
        let intersection = Set.intersect k1 k2 |> Set.count |> float
        let union = Set.union k1 k2 |> Set.count |> float
        intersection / union

let contentSimilarity (c1: string) (c2: string) : float =
    // Sample first 500 chars for performance
    let sample1 = if c1.Length > 500 then c1.Substring(0, 500) else c1
    let sample2 = if c2.Length > 500 then c2.Substring(0, 500) else c2
    let k1 = extractKeywords sample1
    let k2 = extractKeywords sample2
    if Set.isEmpty k1 || Set.isEmpty k2 then 0.0
    else
        let intersection = Set.intersect k1 k2 |> Set.count |> float
        let minSize = min (Set.count k1) (Set.count k2) |> float
        intersection / minSize  // Overlap coefficient

let calculateScore (h1: Holon) (h2: Holon) : float =
    let tagScore = tagSimilarity h1.tags h2.tags * 0.35
    let clusterScore = clusterSimilarity h1.cluster h2.cluster * 0.25
    let titleScore = titleSimilarity h1.title h2.title * 0.25
    let contentScore = contentSimilarity h1.content h2.content * 0.15
    tagScore + clusterScore + titleScore + contentScore

let determineLinkType (score: float) (h1: Holon) (h2: Holon) : string =
    let tagOverlap = tagSimilarity h1.tags h2.tags
    let sameCluster = clusterSimilarity h1.cluster h2.cluster > 0.5

    // Use valid link_type values from schema
    if tagOverlap > 0.5 then "semantic"
    elif sameCluster then "wiki"
    elif score > 0.6 then "semantic"
    else "wiki"

// ============================================================================
// Database Operations
// ============================================================================

let getHolons () : Holon list =
    use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
    conn.Open()
    conn.Query<Holon>("SELECT holon_uuid, title, content, tags, cluster, level FROM holons")
    |> Seq.toList

let getExistingEdgeCount () : int =
    use conn = new SqliteConnection($"Data Source={smritiDbPath};Mode=ReadOnly")
    conn.Open()
    let result = conn.QueryFirstOrDefault<EdgeCount>("SELECT COUNT(*) as count FROM holon_edges")
    if isNull (box result) then 0 else int result.count

let insertEdges (edges: (string * string * string * float) list) : int =
    use conn = new SqliteConnection($"Data Source={smritiDbPath}")
    conn.Open()

    use tx = conn.BeginTransaction()
    let mutable count = 0

    for (source, target, linkType, weight) in edges do
        let sql = """
            INSERT OR IGNORE INTO holon_edges (source_id, target_id, link_type, weight)
            VALUES (@source, @target, @linkType, @weight)
        """
        let affected = conn.Execute(sql, {| source = source; target = target; linkType = linkType; weight = weight |}, tx)
        count <- count + affected

    tx.Commit()
    count

// ============================================================================
// Edge Generation
// ============================================================================

let generateEdges (holons: Holon list) : (string * string * string * float) list =
    printfn "Analyzing %d holons for connections..." holons.Length

    let mutable edges = []
    let mutable processed = 0
    let total = holons.Length

    for i in 0 .. holons.Length - 1 do
        let h1 = holons.[i]
        let mutable candidates = []

        for j in i + 1 .. holons.Length - 1 do
            let h2 = holons.[j]
            let score = calculateScore h1 h2

            if score >= minScore then
                candidates <- (h2.holon_uuid, score, determineLinkType score h1 h2) :: candidates

        // Take top N candidates
        let topCandidates =
            candidates
            |> List.sortByDescending (fun (_, score, _) -> score)
            |> List.truncate maxEdgesPerHolon

        for (targetId, score, edgeType) in topCandidates do
            edges <- (h1.holon_uuid, targetId, edgeType, score) :: edges

        processed <- processed + 1
        if processed % 50 = 0 then
            printfn "  Processed %d/%d holons..." processed total

    edges

// ============================================================================
// Main
// ============================================================================

printfn ""
printfn "╔══════════════════════════════════════════════════════════════╗"
printfn "║   SMRITI EDGE GENERATOR                                        ║"
printfn "╠══════════════════════════════════════════════════════════════╣"
printfn "║  Database: %-49s ║" smritiDbPath
printfn "║  Min Score: %-48.2f ║" minScore
printfn "║  Max Edges/Holon: %-42d ║" maxEdgesPerHolon
printfn "╚══════════════════════════════════════════════════════════════╝"
printfn ""

let existingEdges = getExistingEdgeCount()
printfn "Existing edges: %d" existingEdges

let holons = getHolons()
printfn "Loaded %d holons" holons.Length

if holons.Length < 2 then
    printfn "Not enough holons to generate edges."
    Environment.Exit(0)

let edges = generateEdges holons
printfn ""
printfn "Generated %d potential edges" edges.Length

if edges.Length > 0 then
    let inserted = insertEdges edges
    printfn "Inserted %d new edges" inserted

    let finalCount = getExistingEdgeCount()
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════╗"
    printfn "║   EDGE GENERATION COMPLETE                                   ║"
    printfn "╠══════════════════════════════════════════════════════════════╣"
    printfn "║   Before:  %-49d ║" existingEdges
    printfn "║   Added:   %-49d ║" inserted
    printfn "║   Total:   %-49d ║" finalCount
    printfn "╚══════════════════════════════════════════════════════════════╝"
else
    printfn "No edges above threshold %.2f found." minScore
