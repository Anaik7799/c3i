#!/usr/bin/env dotnet fsi
// ============================================================================
// FRACTAL DOCUMENT INGESTION PIPELINE v20.0.0
// ============================================================================
// Target: 3-second document ingestion with full fractal logging
// Architecture: 7-Layer Fractal Holonic Pipeline
// STAMP Compliance: SC-IKE-001 through SC-IKE-008
// ============================================================================

open System
open System.IO
open System.Collections.Concurrent
open System.Threading.Tasks
open System.Diagnostics
open System.Text.RegularExpressions

// ============================================================================
// Level 1: Type System (The DNA)
// ============================================================================

type FractalLevel =
    | L1_Function  // Atomic operations
    | L2_Module    // Grouped functions
    | L3_Service   // Business logic
    | L4_Domain    // Domain boundary
    | L5_System    // System-wide
    | L6_Node      // Container/VM level
    | L7_Federation // Distributed cluster

type DocumentCategory =
    | Plan of priority: int
    | FormalSpec of language: string
    | Journal of date: DateTime
    | Architecture of layer: int
    | Unknown

type ClassificationPattern =
    { Name: string
      Regex: string
      Category: DocumentCategory
      Weight: float }

type PipelineStage =
    | Discovery
    | Classification
    | Parsing
    | Transformation
    | Mapping
    | Indexing
    | Validation

type StageMetrics =
    { Stage: PipelineStage
      StartTime: DateTime
      EndTime: DateTime option
      ItemsProcessed: int
      BytesProcessed: int64
      Errors: string list
      Throughput: float }

type DocumentResult =
    { Path: string
      Category: DocumentCategory
      Size: int64
      Lines: int
      HeadingCount: int
      CodeBlockCount: int
      LinkCount: int
      Entropy: float
      ProcessingMs: float
      AS_IS_Pattern: string
      TO_BE_Structure: string }

type PipelineState =
    { Documents: ConcurrentDictionary<string, DocumentResult>
      Metrics: ConcurrentDictionary<PipelineStage, StageMetrics>
      TotalStartTime: DateTime
      Errors: ConcurrentBag<string>
      OptimizationRuns: int
      SamplingComplete: bool }

// ============================================================================
// Level 2: Fractal Logging Infrastructure
// ============================================================================

module FractalLogger =
    let mutable verboseMode = true

    let private levelPrefix level =
        match level with
        | L1_Function -> "  [L1:FN]"
        | L2_Module -> " [L2:MOD]"
        | L3_Service -> "[L3:SVC]"
        | L4_Domain -> "[L4:DOM]"
        | L5_System -> "[L5:SYS]"
        | L6_Node -> "[L6:NOD]"
        | L7_Federation -> "[L7:FED]"

    let log (level: FractalLevel) (stage: PipelineStage) (message: string) =
        if verboseMode then
            let timestamp = DateTime.Now.ToString("HH:mm:ss.fff")
            let prefix = levelPrefix level
            let stageStr = sprintf "[%A]" stage
            printfn "%s %s %-15s %s" timestamp prefix stageStr message

    let metric (name: string) (value: float) (unit: string) =
        printfn "           KPI: %s = %.2f %s" name value unit

    let progress (current: int) (total: int) (item: string) =
        let pct = float current / float total * 100.0
        printfn "           Progress: %d/%d (%.1f%%) - %s" current total pct item

// ============================================================================
// Level 3: Classification Patterns (AS-IS Detection)
// ============================================================================

let classificationPatterns = [
    { Name = "Implementation Plan"
      Regex = @"implementation.*plan|execution.*plan"
      Category = Plan(priority = 1)
      Weight = 0.9 }
    { Name = "Formal Agda Spec"
      Regex = @"\.agda$|agda.*proof"
      Category = FormalSpec(language = "Agda")
      Weight = 0.95 }
    { Name = "Formal Quint Spec"
      Regex = @"\.qnt$|quint.*model"
      Category = FormalSpec(language = "Quint")
      Weight = 0.95 }
    { Name = "Journal Entry"
      Regex = @"journal.*\d{8}|20\d{6}"
      Category = Journal(date = DateTime.Now)
      Weight = 0.8 }
    { Name = "Architecture Doc"
      Regex = @"architecture|5.?level|fractal|holonic"
      Category = Architecture(layer = 3)
      Weight = 0.85 }
]

// TO-BE Knowledge Structures
let tOBeStructures = [
    ("holon", "Holonic Fractal Unit")
    ("vsm", "Viable System Model Component")
    ("stamp", "STAMP Safety Constraint")
    ("tdg", "Test-Driven Generation Artifact")
    ("ooda", "OODA Loop Integration Point")
    ("active_inference", "Active Inference Node")
    ("knowledge_graph", "Knowledge Graph Entry")
]

// ============================================================================
// Level 4: Pipeline Stages (Massively Parallel)
// ============================================================================

module Pipeline =
    let mutable state: PipelineState =
        { Documents = ConcurrentDictionary<string, DocumentResult>()
          Metrics = ConcurrentDictionary<PipelineStage, StageMetrics>()
          TotalStartTime = DateTime.Now
          Errors = ConcurrentBag<string>()
          OptimizationRuns = 0
          SamplingComplete = false }

    let startStage (stage: PipelineStage) =
        let metric = { Stage = stage; StartTime = DateTime.Now; EndTime = None
                       ItemsProcessed = 0; BytesProcessed = 0L; Errors = []
                       Throughput = 0.0 }
        state.Metrics.[stage] <- metric
        FractalLogger.log L3_Service stage $"Starting stage"

    let endStage (stage: PipelineStage) (items: int) (bytes: int64) =
        match state.Metrics.TryGetValue(stage) with
        | true, m ->
            let endTime = DateTime.Now
            let duration = (endTime - m.StartTime).TotalMilliseconds
            let throughput = if duration > 0.0 then float items / (duration / 1000.0) else 0.0
            state.Metrics.[stage] <- { m with EndTime = Some endTime
                                              ItemsProcessed = items
                                              BytesProcessed = bytes
                                              Throughput = throughput }
            FractalLogger.log L3_Service stage $"Completed: {items} items, {bytes} bytes"
            FractalLogger.metric "Throughput" throughput "items/sec"
            FractalLogger.metric "Duration" duration "ms"
        | false, _ -> ()

    // Stage 1: Discovery (Parallel file enumeration)
    let discover (paths: string list) : string[] =
        startStage Discovery
        let sw = Stopwatch.StartNew()

        let files =
            paths
            |> List.toArray
            |> Array.Parallel.collect (fun path ->
                if Directory.Exists(path) then
                    Directory.GetFiles(path, "*.md", SearchOption.AllDirectories)
                elif File.Exists(path) then [| path |]
                else [||])

        FractalLogger.log L2_Module Discovery $"Found {files.Length} markdown files"
        endStage Discovery files.Length 0L
        files

    // Stage 2: Classification (Pattern matching)
    let classifyDocument (path: string) : DocumentCategory =
        let filename = Path.GetFileName(path).ToLower()
        let content =
            try File.ReadAllText(path) |> Some
            with _ -> None

        match content with
        | None -> Unknown
        | Some text ->
            let textLower = text.ToLower()
            classificationPatterns
            |> List.tryFind (fun p ->
                System.Text.RegularExpressions.Regex.IsMatch(filename + " " + textLower, p.Regex, Text.RegularExpressions.RegexOptions.IgnoreCase))
            |> Option.map (fun p -> p.Category)
            |> Option.defaultValue Unknown

    // Stage 3: Parsing (Extract structure)
    let parseDocument (path: string) : DocumentResult option =
        try
            let sw = Stopwatch.StartNew()
            let content = File.ReadAllText(path)
            let lines = content.Split('\n')
            let headings = lines |> Array.filter (fun l -> l.TrimStart().StartsWith("#")) |> Array.length
            let codeBlocks = System.Text.RegularExpressions.Regex.Matches(content, "```").Count / 2
            let links = System.Text.RegularExpressions.Regex.Matches(content, @"\[.*?\]\(.*?\)").Count

            // Calculate Shannon entropy
            let freq = content |> Seq.countBy id |> Seq.map snd |> Seq.toArray
            let total = float content.Length
            let entropy =
                freq
                |> Array.map (fun c ->
                    let p = float c / total
                    if p > 0.0 then -p * log(p) / log(2.0) else 0.0)
                |> Array.sum

            // Determine AS-IS pattern
            let asIsPattern =
                if headings > 10 then "structured-plan"
                elif codeBlocks > 5 then "code-heavy"
                elif links > 20 then "reference-doc"
                elif entropy > 4.5 then "prose-dense"
                else "mixed"

            // Map to TO-BE structure
            let toBeStructure =
                match classifyDocument path with
                | Plan _ -> "knowledge_graph/plan"
                | FormalSpec lang -> $"formal_specs/{lang.ToLower()}"
                | Journal _ -> "knowledge_graph/temporal"
                | Architecture layer -> $"holonic_map/L{layer}"
                | Unknown -> "inbox/unclassified"

            sw.Stop()
            Some {
                Path = path
                Category = classifyDocument path
                Size = FileInfo(path).Length
                Lines = lines.Length
                HeadingCount = headings
                CodeBlockCount = codeBlocks
                LinkCount = links
                Entropy = entropy
                ProcessingMs = sw.Elapsed.TotalMilliseconds
                AS_IS_Pattern = asIsPattern
                TO_BE_Structure = toBeStructure
            }
        with ex ->
            state.Errors.Add($"Parse error {path}: {ex.Message}")
            None

    // Stage 4: Parallel Transformation
    let transformBatch (files: string[]) : DocumentResult[] =
        startStage Transformation

        let results =
            files
            |> Array.Parallel.choose parseDocument

        let totalBytes = results |> Array.sumBy (fun r -> r.Size)
        endStage Transformation results.Length totalBytes

        results

    // Stage 5: Knowledge Mapping
    let mapToKnowledgeGraph (results: DocumentResult[]) =
        startStage Mapping

        // Group by TO-BE structure
        let grouped = results |> Array.groupBy (fun r -> r.TO_BE_Structure)

        FractalLogger.log L4_Domain Mapping "Knowledge structure mapping:"
        for (structure, docs) in grouped do
            FractalLogger.log L2_Module Mapping $"  {structure}: {docs.Length} documents"

        endStage Mapping results.Length 0L
        grouped

// ============================================================================
// Level 5: KPI Dashboard
// ============================================================================

module Dashboard =
    let showPipelineMetrics (state: PipelineState) =
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════════╗"
        printfn "║                    PIPELINE METRICS                              ║"
        printfn "╠══════════════════════════════════════════════════════════════════╣"
        printfn "║ %-15s │ %-12s │ %-8s │ %-10s │ %-12s ║" "Stage" "Duration(ms)" "Items" "Bytes" "Throughput"
        printfn "╠══════════════════════════════════════════════════════════════════╣"

        for kvp in state.Metrics do
            let m = kvp.Value
            let duration =
                match m.EndTime with
                | Some e -> (e - m.StartTime).TotalMilliseconds
                | None -> (DateTime.Now - m.StartTime).TotalMilliseconds
            let status = if m.EndTime.IsSome then "✓" else "⏳"
            printfn "║ %-15A │ %12.2f │ %8d │ %10d │ %10.1f/s %s ║" m.Stage duration m.ItemsProcessed m.BytesProcessed m.Throughput status

        printfn "╚══════════════════════════════════════════════════════════════════╝"

    let showDocumentSummary (results: DocumentResult[]) =
        printfn ""
        printfn "═══ Document Categories ═══"
        let byCategory = results |> Array.groupBy (fun r -> sprintf "%A" r.Category)
        for (cat, docs) in byCategory do
            let totalSize = docs |> Array.sumBy (fun d -> d.Size)
            let avgEntropy = docs |> Array.averageBy (fun d -> d.Entropy)
            printfn "  %-15s: %d docs, %d KB, entropy: %.2f" cat docs.Length (totalSize / 1024L) avgEntropy

    let showASISToTOBE (results: DocumentResult[]) =
        printfn ""
        printfn "═══ AS-IS → TO-BE Transformation ═══"
        let grouped = results |> Array.groupBy (fun r -> r.AS_IS_Pattern)
        for (pattern, docs) in grouped do
            let primaryToBeStructure =
                docs
                |> Array.countBy (fun d -> d.TO_BE_Structure)
                |> Array.maxBy snd
                |> fst
            let confidence = float (docs |> Array.filter (fun d -> d.TO_BE_Structure = primaryToBeStructure) |> Array.length) / float docs.Length * 100.0
            printfn "  %-18s (%d) → %s [%.0f%% confidence]" pattern docs.Length primaryToBeStructure confidence

    let showPerformanceAnalysis (totalMs: float) (docCount: int) (target: float) =
        printfn ""
        printfn "═══ Performance vs Target (%.0f ms) ═══" target
        let docsPerSec = float docCount / (totalMs / 1000.0)
        let pctOfTarget = (target / totalMs) * 100.0
        let status = if totalMs <= target then "✓ ACHIEVED" else "✗ MISSED"

        printfn "  Total Time:     %.2f ms %s" totalMs status
        printfn "  Target Time:    %.0f ms" target
        printfn "  %% of Target:    %.1f%%" pctOfTarget
        printfn "  Throughput:     %.1f docs/sec" docsPerSec
        printfn "  Avg per Doc:    %.2f ms" (totalMs / float docCount)

// ============================================================================
// Level 6: Statistical Sampling
// ============================================================================

module Sampling =
    let sampleFiles (files: string[]) (sampleSize: int) =
        let rng = Random()
        files
        |> Array.sortBy (fun _ -> rng.Next())
        |> Array.take (min sampleSize files.Length)

    let analyzeSample (sample: DocumentResult[]) =
        FractalLogger.log L5_System Discovery "Statistical sample analysis:"

        let avgSize = sample |> Array.averageBy (fun r -> float r.Size)
        let avgLines = sample |> Array.averageBy (fun r -> float r.Lines)
        let avgEntropy = sample |> Array.averageBy (fun r -> r.Entropy)
        let avgProcessingMs = sample |> Array.averageBy (fun r -> r.ProcessingMs)

        FractalLogger.metric "Avg Size" (avgSize / 1024.0) "KB"
        FractalLogger.metric "Avg Lines" avgLines "lines"
        FractalLogger.metric "Avg Entropy" avgEntropy "bits"
        FractalLogger.metric "Avg Processing" avgProcessingMs "ms"

        // Predict full pipeline time
        (avgProcessingMs, avgSize)

// ============================================================================
// Level 7: Main Execution (Federation Level)
// ============================================================================

let main argv =
    printfn """
███████╗██████╗  █████╗  ██████╗████████╗ █████╗ ██╗
██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██║
█████╗  ██████╔╝███████║██║        ██║   ███████║██║
██╔══╝  ██╔══██╗██╔══██║██║        ██║   ██╔══██║██║
██║     ██║  ██║██║  ██║╚██████╗   ██║   ██║  ██║███████╗
╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
"""
    printfn "Indrajaal v20.0.0 - Knowledge Engine Document Processor"
    printfn "Target: 3-second ingestion with full fractal logging"
    printfn ""

    let targetMs = 3000.0
    let docPaths = [
        "docs/plans"
        "docs/formal_specs"
        "docs/journal"
    ]

    let totalSw = Stopwatch.StartNew()

    // Phase 1: Discovery
    FractalLogger.log L7_Federation Discovery "Initiating fractal document discovery..."
    let allFiles = Pipeline.discover docPaths

    if allFiles.Length = 0 then
        printfn "No documents found!"
        1
    else
        // Phase 2: Sample 3 files for benchmarking
        printfn ""
        printfn "══════════════════════════════════════════════════════════════════"
        printfn "PHASE 1: Benchmarking (3 Sample Files)"
        printfn "══════════════════════════════════════════════════════════════════"

        let sampleFiles = Sampling.sampleFiles allFiles 3
        FractalLogger.log L6_Node Classification $"Benchmarking with {sampleFiles.Length} sample files"

        let sampleResults = Pipeline.transformBatch sampleFiles
        let (avgMs, _avgBytes) = Sampling.analyzeSample sampleResults

        // Predict full run time
        let predictedMs = avgMs * float allFiles.Length
        FractalLogger.log L5_System Validation $"Predicted full run: {predictedMs:F0} ms for {allFiles.Length} files"

        let parallelFactor = if predictedMs > targetMs then predictedMs / targetMs else 1.0
        FractalLogger.log L5_System Validation $"Required parallelization factor: {parallelFactor:F1}x"

        // Phase 3: Full parallel ingestion
        printfn ""
        printfn "══════════════════════════════════════════════════════════════════"
        printfn "PHASE 2: Full Parallel Ingestion"
        printfn "══════════════════════════════════════════════════════════════════"

        let fullSw = Stopwatch.StartNew()
        let allResults = Pipeline.transformBatch allFiles
        fullSw.Stop()

        // Phase 4: Knowledge mapping
        let knowledgeMap = Pipeline.mapToKnowledgeGraph allResults

        totalSw.Stop()

        // Phase 5: Dashboard
        printfn ""
        printfn "══════════════════════════════════════════════════════════════════"
        printfn "PIPELINE METRICS"
        printfn "══════════════════════════════════════════════════════════════════"
        Dashboard.showPipelineMetrics Pipeline.state
        Dashboard.showDocumentSummary allResults
        Dashboard.showASISToTOBE allResults
        Dashboard.showPerformanceAnalysis totalSw.Elapsed.TotalMilliseconds allResults.Length targetMs

        // Prediction accuracy
        printfn ""
        printfn "═══ Prediction vs Actual ═══"
        let actualMs = fullSw.Elapsed.TotalMilliseconds
        let predictionError = abs(predictedMs - actualMs) / max actualMs 0.001 * 100.0
        printfn "  Predicted: %.0f ms" predictedMs
        printfn "  Actual:    %.0f ms" actualMs
        printfn "  Error:     %.1f%%" predictionError

        // Final status
        printfn ""
        if totalSw.Elapsed.TotalMilliseconds <= targetMs then
            printfn "🎯 TARGET ACHIEVED: Document ingestion completed within 3 seconds!"
            0
        else
            printfn "⚠ Target missed by %.0f ms - optimization recommended" (totalSw.Elapsed.TotalMilliseconds - targetMs)
            1

// Run when executed as script
main [||] |> ignore
