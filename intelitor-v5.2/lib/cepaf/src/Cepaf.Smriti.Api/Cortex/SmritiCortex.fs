/// SMRITI Cortex Integration - Knowledge Management for F# Cockpit
///
/// STAMP Constraints:
/// - SC-MESH-006: DigitalTwin.fs is authoritative state
/// - SC-SYNC-009: Zenoh for real-time telemetry
/// - SC-SYNC-010: DuckDB for shared history
module Cepaf.Smriti.Api.Cortex.SmritiCortex

open System
open System.IO
open Cepaf.Smriti.Shared

module DocsIngestor = Cepaf.Smriti.Api.Data.DocsIngestor
module SmritiLifecycle = Cepaf.Smriti.Api.Data.SmritiLifecycle
module OpenRouterClient = Cepaf.Smriti.Api.AI.OpenRouterClient

/// SMRITI Cortex configuration
type CortexConfig = {
    SmritiConfig: SmritiLifecycle.SmritiConfig
    IngestorConfig: DocsIngestor.IngestorConfig
    EnableAI: bool
    EnableTelemetry: bool
    DocsBasePath: string
}

/// Cortex operation result
type CortexResult<'T> =
    | Success of 'T
    | Warning of 'T * message: string
    | Failure of message: string

/// Cortex status for dashboard
type CortexStatus = {
    TotalHolons: int
    OrphanCount: int
    StaleCount: int
    ClusterStats: Map<string, int * float>
    LastIngestion: DateTime option
    AIAvailable: bool
}

/// Ingestion batch result
type BatchResult = {
    TotalFiles: int
    Ingested: int
    Skipped: int
    Errors: int
    AIUsed: int
    Duration: TimeSpan
}

/// Default configuration
let defaultConfig () : CortexConfig =
    let smritiConfig = SmritiLifecycle.defaultConfig()
    let ingestorConfig = DocsIngestor.defaultConfig()
    {
        SmritiConfig = smritiConfig
        IngestorConfig = ingestorConfig
        EnableAI = true
        EnableTelemetry = true
        DocsBasePath = "docs"
    }

/// Get current SMRITI cortex status
let getStatus (config: CortexConfig) : CortexResult<CortexStatus> =
    try
        let holonResult = SmritiLifecycle.list config.SmritiConfig 1 1 None None
        let orphanResult = SmritiLifecycle.findOrphans config.SmritiConfig
        let staleResult = SmritiLifecycle.findStale config.SmritiConfig 0.6
        let clusterResult = SmritiLifecycle.getClusterStats config.SmritiConfig

        let totalHolons =
            match holonResult with
            | SmritiLifecycle.Ok (_, total) -> total
            | _ -> 0

        let orphanCount =
            match orphanResult with
            | SmritiLifecycle.Ok orphans -> List.length orphans
            | _ -> 0

        let staleCount =
            match staleResult with
            | SmritiLifecycle.Ok stale -> List.length stale
            | _ -> 0

        let clusterStats =
            match clusterResult with
            | SmritiLifecycle.Ok stats -> stats
            | _ -> Map.empty

        let aiAvailable =
            let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
            not (String.IsNullOrEmpty apiKey)

        Success {
            TotalHolons = totalHolons
            OrphanCount = orphanCount
            StaleCount = staleCount
            ClusterStats = clusterStats
            LastIngestion = None
            AIAvailable = aiAvailable
        }
    with ex ->
        Failure (sprintf "Failed to get status: %s" ex.Message)

/// Print dashboard to console
let printDashboard (status: CortexStatus) =
    printfn ""
    printfn "======================================================================"
    printfn "              SMRITI CORTEX DASHBOARD"
    printfn "======================================================================"
    printfn "  Total Holons:    %-10d" status.TotalHolons
    printfn "  Orphans:         %-10d  (no links)" status.OrphanCount
    printfn "  Stale:           %-10d  (entropy > 0.6)" status.StaleCount
    printfn "  AI Available:    %-10b" status.AIAvailable
    printfn "----------------------------------------------------------------------"
    printfn "  CLUSTERS"
    printfn "----------------------------------------------------------------------"

    status.ClusterStats
    |> Map.iter (fun cluster (count, avgEntropy) ->
        let bar = String.replicate (min 20 count) "#"
        printfn "  %-15s %3d holons [%-20s] entropy: %.2f" cluster count bar avgEntropy
    )

    printfn "======================================================================"
    printfn ""

/// Ingest documents from a directory
let ingestDirectory (config: CortexConfig) (path: string) (maxFiles: int) (cluster: string) : Async<CortexResult<BatchResult>> =
    async {
        let startTime = DateTime.UtcNow

        let fullPath =
            if Path.IsPathRooted(path) then path
            else Path.Combine(config.DocsBasePath, path)

        if not (Directory.Exists fullPath) then
            return Failure (sprintf "Directory not found: %s" fullPath)
        else
            let files =
                Directory.GetFiles(fullPath, "*.md", SearchOption.AllDirectories)
                |> Array.truncate maxFiles
                |> Array.toList

            printfn "Found %d markdown files in %s" files.Length fullPath

            let ingestConfig = {
                config.IngestorConfig with
                    DefaultCluster = cluster
                    UseAI = config.EnableAI
            }

            let! results = DocsIngestor.ingestFiles ingestConfig files

            let ingested = results |> List.filter (function DocsIngestor.Success _ -> true | _ -> false) |> List.length
            let aiUsed = results |> List.filter (function DocsIngestor.Success (_, _, true) -> true | _ -> false) |> List.length
            let skipped = results |> List.filter (function DocsIngestor.Skipped _ -> true | _ -> false) |> List.length
            let errors = results |> List.filter (function DocsIngestor.Error _ -> true | _ -> false) |> List.length

            DocsIngestor.printSummary results

            let duration = DateTime.UtcNow - startTime

            return Success {
                TotalFiles = files.Length
                Ingested = ingested
                Skipped = skipped
                Errors = errors
                AIUsed = aiUsed
                Duration = duration
            }
    }

/// Create a new zettel
let createZettel (config: CortexConfig) (title: string) (content: string) (tags: string list) (level: HolonLevel) (cluster: string) : CortexResult<Guid> =
    match SmritiLifecycle.create config.SmritiConfig title content tags level (Some cluster) with
    | SmritiLifecycle.Ok id -> Success id
    | SmritiLifecycle.NotFound msg -> Failure msg
    | SmritiLifecycle.Conflict msg -> Failure msg
    | SmritiLifecycle.Error msg -> Failure msg

/// Get a zettel by ID
let getZettel (config: CortexConfig) (id: Guid) : CortexResult<Zettel> =
    match SmritiLifecycle.get config.SmritiConfig id with
    | SmritiLifecycle.Ok zettel -> Success zettel
    | SmritiLifecycle.NotFound msg -> Failure msg
    | SmritiLifecycle.Conflict msg -> Failure msg
    | SmritiLifecycle.Error msg -> Failure msg

/// Search zettels
let searchZettels (config: CortexConfig) (query: string) (limit: int) : CortexResult<Zettel list> =
    match SmritiLifecycle.search config.SmritiConfig query limit with
    | SmritiLifecycle.Ok zettels -> Success zettels
    | SmritiLifecycle.NotFound msg -> Failure msg
    | SmritiLifecycle.Conflict msg -> Failure msg
    | SmritiLifecycle.Error msg -> Failure msg

/// Update a zettel
let updateZettel (config: CortexConfig) (id: Guid) (req: SmritiLifecycle.UpdateRequest) : CortexResult<unit> =
    match SmritiLifecycle.update config.SmritiConfig id req with
    | SmritiLifecycle.Ok () -> Success ()
    | SmritiLifecycle.NotFound msg -> Failure msg
    | SmritiLifecycle.Conflict msg -> Failure msg
    | SmritiLifecycle.Error msg -> Failure msg

/// Create a link between zettels
let linkZettels (config: CortexConfig) (sourceId: Guid) (targetId: Guid) (linkType: LinkType) : CortexResult<unit> =
    let req : SmritiLifecycle.LinkRequest = {
        SourceId = sourceId
        TargetId = targetId
        LinkType = linkType
        Weight = Some 1.0
    }
    match SmritiLifecycle.createLink config.SmritiConfig req with
    | SmritiLifecycle.Ok _ -> Success ()
    | SmritiLifecycle.NotFound msg -> Failure msg
    | SmritiLifecycle.Conflict msg -> Failure msg
    | SmritiLifecycle.Error msg -> Failure msg

/// Delete a zettel
let deleteZettel (config: CortexConfig) (id: Guid) : CortexResult<unit> =
    match SmritiLifecycle.delete config.SmritiConfig id true with
    | SmritiLifecycle.Ok () -> Success ()
    | SmritiLifecycle.NotFound msg -> Failure msg
    | SmritiLifecycle.Conflict msg -> Failure msg
    | SmritiLifecycle.Error msg -> Failure msg

/// Find and report orphan zettels
let findOrphans (config: CortexConfig) : CortexResult<Zettel list> =
    match SmritiLifecycle.findOrphans config.SmritiConfig with
    | SmritiLifecycle.Ok orphans ->
        if List.isEmpty orphans then Success orphans
        else Warning (orphans, sprintf "Found %d orphan zettels" (List.length orphans))
    | SmritiLifecycle.Error msg -> Failure msg
    | _ -> Failure "Unexpected result"

/// Find and report stale zettels
let findStale (config: CortexConfig) (threshold: float) : CortexResult<Zettel list> =
    match SmritiLifecycle.findStale config.SmritiConfig threshold with
    | SmritiLifecycle.Ok stale ->
        if List.isEmpty stale then Success stale
        else Warning (stale, sprintf "Found %d stale zettels (entropy > %.2f)" (List.length stale) threshold)
    | SmritiLifecycle.Error msg -> Failure msg
    | _ -> Failure "Unexpected result"

/// Recalculate entropy for all zettels
let recalculateEntropy (config: CortexConfig) : CortexResult<int> =
    match SmritiLifecycle.recalculateEntropy config.SmritiConfig with
    | SmritiLifecycle.Ok count -> Success count
    | SmritiLifecycle.Error msg -> Failure msg
    | _ -> Failure "Unexpected result"

/// Available SMRITI commands
type SmritiCommand =
    | Status
    | Ingest of path: string * maxFiles: int * cluster: string
    | Search of query: string * limit: int
    | Get of id: Guid
    | Create of title: string * content: string * cluster: string
    | Link of source: Guid * target: Guid * linkType: string
    | Delete of id: Guid
    | Orphans
    | Stale of threshold: float
    | Entropy

/// Execute a SMRITI command
let executeCommand (config: CortexConfig) (cmd: SmritiCommand) : Async<unit> =
    async {
        match cmd with
        | Status ->
            match getStatus config with
            | Success status -> printDashboard status
            | Warning (status, msg) ->
                printDashboard status
                printfn "[Warning] %s" msg
            | Failure msg -> printfn "[Error] %s" msg

        | Ingest (path, maxFiles, cluster) ->
            let! result = ingestDirectory config path maxFiles cluster
            match result with
            | Success batch ->
                printfn "\n[Ingestion Complete]"
                printfn "  Files: %d | Ingested: %d | Skipped: %d | Errors: %d"
                    batch.TotalFiles batch.Ingested batch.Skipped batch.Errors
                printfn "  AI Used: %d | Duration: %.2fs" batch.AIUsed batch.Duration.TotalSeconds
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()

        | Search (query, limit) ->
            match searchZettels config query limit with
            | Success zettels ->
                printfn "\nSearch results for '%s':" query
                for z in zettels do
                    printfn "  [%s] %s (entropy: %.2f)" (z.Id.ToString().Substring(0,8)) z.Title z.Entropy
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()

        | Get id ->
            match getZettel config id with
            | Success z ->
                printfn "\n=== %s ===" z.Title
                printfn "ID: %s" (z.Id.ToString())
                printfn "Level: %A | Entropy: %.2f | Decay: %A" z.Level z.Entropy z.DecayRate
                printfn "Tags: %s" (String.Join(", ", z.Tags))
                printfn "\n%s" z.Content
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()

        | Create (title, content, cluster) ->
            match createZettel config title content [] HolonLevel.Atomic cluster with
            | Success id -> printfn "[Created] %s - %s" (id.ToString()) title
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()

        | Link (source, target, ltStr) ->
            let linkType =
                match ltStr.ToLower() with
                | "wiki" -> LinkType.WikiLink
                | "semantic" -> LinkType.SemanticSimilar
                | "code" -> LinkType.CodeReference
                | "backlink" -> LinkType.Backlink
                | _ -> LinkType.WikiLink
            match linkZettels config source target linkType with
            | Success () -> printfn "[Linked] %s -> %s (%s)" (source.ToString().Substring(0,8)) (target.ToString().Substring(0,8)) ltStr
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()

        | Delete id ->
            match deleteZettel config id with
            | Success () -> printfn "[Deleted] %s" (id.ToString())
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()

        | Orphans ->
            match findOrphans config with
            | Success orphans ->
                printfn "\nOrphan Zettels (%d):" (List.length orphans)
                for z in orphans do
                    printfn "  [%s] %s" (z.Id.ToString().Substring(0,8)) z.Title
            | Warning (orphans, msg) ->
                printfn "[Warning] %s" msg
                for z in orphans do
                    printfn "  [%s] %s" (z.Id.ToString().Substring(0,8)) z.Title
            | Failure msg -> printfn "[Error] %s" msg

        | Stale threshold ->
            match findStale config threshold with
            | Success stale ->
                printfn "\nStale Zettels (entropy > %.2f):" threshold
                for z in stale do
                    printfn "  [%s] %s (entropy: %.2f)" (z.Id.ToString().Substring(0,8)) z.Title z.Entropy
            | Warning (stale, msg) ->
                printfn "[Warning] %s" msg
                for z in stale do
                    printfn "  [%s] %s (entropy: %.2f)" (z.Id.ToString().Substring(0,8)) z.Title z.Entropy
            | Failure msg -> printfn "[Error] %s" msg

        | Entropy ->
            match recalculateEntropy config with
            | Success count -> printfn "[Entropy] Updated %d holons" count
            | Failure msg -> printfn "[Error] %s" msg
            | _ -> ()
    }
