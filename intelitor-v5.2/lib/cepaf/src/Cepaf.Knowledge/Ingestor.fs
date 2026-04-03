module Cepaf.Knowledge.Ingestor

open System
open System.IO
open System.Threading
open System.Threading.Tasks
open System.Threading.Tasks.Dataflow
open System.Collections.Concurrent
open System.Text.RegularExpressions
open YamlDotNet.Serialization
open YamlDotNet.Serialization.NamingConventions
open Cepaf.Knowledge.Schema
open Cepaf.Knowledge.OpenRouter
open Cepaf.Knowledge.FractalLogger
open Cepaf.Knowledge.Topology

// --- Data Types ---
type YamlFrontmatter = {
    Identity: Identity
    FractalStruct: FractalStruct
    Evolution: Evolution
    Semantics: Semantics
    Graph: Actionable
}

type PipelinePayload = {
    Path: string
    Content: string
    Metadata: YamlFrontmatter option
    AsIsPattern: AsIsPattern option
    ToBeStructure: ToBeStructure option
    Duration: int64
}

// --- Helpers ---
module YamlParser =
    let deserializer = 
        DeserializerBuilder()
            .WithNamingConvention(UnderscoredNamingConvention.Instance)
            .IgnoreUnmatchedProperties()
            .Build()

    let parse (text: string) : Result<YamlFrontmatter, string> = 
        try
            let match' = Regex.Match(text, @"^---\s*\n(.*?)\n---\s*\n", RegexOptions.Singleline)
            if match'.Success then
                let yaml = match'.Groups[1].Value
                Ok (deserializer.Deserialize<YamlFrontmatter>(yaml))
            else
                Result.Error "No Frontmatter found"
        with
        | ex -> Result.Error ex.Message

type Ingestor(store: Cepaf.Knowledge.DuckDB.KnowledgeStore, ai: OpenRouterClient) = 
    
    let logger = FractalLogger()    
    // --- The Plasma Engine (TPL Dataflow Pipeline) ---
    member this.IngestFilesAsync(files: string list) : Task<unit> = 
        task {
            logger.Log(Info, "Orchestrator", sprintf "🔥 Igniting Plasma Engine: %d files" files.Length)
            let sw = Diagnostics.Stopwatch.StartNew()
            let processedCount = ref 0

            // 1. Prediction (Simple Heuristic)
            let predictedTime = float files.Length * 50.0 // 50ms per file avg
            logger.Log(Perf, "Prediction", sprintf "Estimated Duration: %0.0f ms" predictedTime)

            // BLOCK 1: Reader (IO Bound)
            let readerOptions = ExecutionDataflowBlockOptions(MaxDegreeOfParallelism = Environment.ProcessorCount * 2)
            let reader = new TransformBlock<string, PipelinePayload>(
                (fun path -> task {
                    let! content = File.ReadAllTextAsync(path)
                    return { Path = path; Content = content; Metadata = None; AsIsPattern = None; ToBeStructure = None; Duration = 0 }
                }), readerOptions
            )

            // BLOCK 2: Parser & Mapper (CPU Bound)
            let parserOptions = ExecutionDataflowBlockOptions(MaxDegreeOfParallelism = Environment.ProcessorCount)
            let parser = new TransformBlock<PipelinePayload, PipelinePayload>(
                (fun payload -> task {
                    // 1. YAML Parse (Explicit Result.Ok/Error to avoid shadowing)
                    let metadata = 
                        match YamlParser.parse(payload.Content) with
                        | Ok meta -> Some meta
                        | Result.Error _ -> None
                    
                    // 2. Topology Mapping
                    let asIs = TopologyMapper.classifyAsIs payload.Path
                    let toBe = TopologyMapper.mapToBe asIs
                    
                    return { payload with Metadata = metadata; AsIsPattern = Some asIs; ToBeStructure = Some toBe }
                }), parserOptions
            )

            // BLOCK 3: Classifier (AI / Network Bound)
            let classifierOptions = ExecutionDataflowBlockOptions(MaxDegreeOfParallelism = 4)
            let classifier = new TransformBlock<PipelinePayload, PipelinePayload>(
                (fun payload -> task {
                    match payload.Metadata with
                    | Some _ -> return payload
                    | None -> return payload // Placeholder for AI
                }), classifierOptions
            )

            // BLOCK 4: Writer (DB Bound)
            let writerOptions = ExecutionDataflowBlockOptions(MaxDegreeOfParallelism = 1, BoundedCapacity = 100)
            
            // Explicit Func<T, Task> to help overload resolution
            let writerFunc = Func<PipelinePayload, Task>(fun payload ->
                task {
                    match payload.Metadata with
                    | Some meta ->
                        let holon = {
                            Identity = meta.Identity
                            FractalStruct = meta.FractalStruct
                            Evolution = meta.Evolution
                            Semantics = meta.Semantics
                            Graph = meta.Graph
                            Content = payload.Content
                        }
                        store.UpsertHolon(holon, payload.Path, "hash")
                    | None -> ()
                    
                    let current = Interlocked.Increment(processedCount)
                    if current % 10 = 0 then
                        logger.Log(Perf, "Optimizer", sprintf "⚡ Processed %d docs. Velocity: %0.2f docs/s" current (float current / sw.Elapsed.TotalSeconds))
                } :> Task)

            let writer = new ActionBlock<PipelinePayload>(writerFunc, writerOptions)

            // Link Pipeline
            let linkOptions = DataflowLinkOptions(PropagateCompletion = true)
            reader.LinkTo(parser, linkOptions) |> ignore
            parser.LinkTo(classifier, linkOptions) |> ignore
            classifier.LinkTo(writer, linkOptions) |> ignore

            // Feed
            for file in files do
                reader.Post(file) |> ignore
            
            reader.Complete()
            do! writer.Completion

            sw.Stop()
            
            let actual = sw.Elapsed.TotalMilliseconds
            let delta = actual - predictedTime
            let color = if actual <= 3000.0 then Perf else Warn
            
            logger.Log(color, "KPI", sprintf "🏁 Complete. Time: %0.0f ms (Goal: 3000ms)" actual)
            logger.Log(Info, "KPI", sprintf "Alignment: %s%0.0f ms vs predicted" (if delta > 0.0 then "+" else "") delta)
        }

    member this.ScanDirectoryAsync(rootPath: string) = 
        let files = Directory.GetFiles(rootPath, "*.md", SearchOption.AllDirectories) |> List.ofArray
        this.IngestFilesAsync(files)
