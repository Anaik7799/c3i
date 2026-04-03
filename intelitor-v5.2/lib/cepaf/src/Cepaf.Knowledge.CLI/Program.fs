open System
open System.IO
open Cepaf.Knowledge.Schema
open Cepaf.Knowledge.DuckDB
open Cepaf.Knowledge.OpenRouter
open Cepaf.Knowledge.Ingestor
open Cepaf.Knowledge.Gardener

[<EntryPoint>]
let main argv =
    // 1. Initialize Configuration
    let dbPath = Path.Combine("data", "knowledge", "fhkb.duckdb")
    Directory.CreateDirectory(Path.GetDirectoryName(dbPath)) |> ignore
    
    let connectionString = sprintf "DataSource=%s" dbPath
    let store = KnowledgeStore(connectionString)
    store.Initialize()
    
    let apiKey = Environment.GetEnvironmentVariable("OPENROUTER_API_KEY")
    let aiConfig = {
        ApiKey = if String.IsNullOrEmpty(apiKey) then "" else apiKey
        BaseUrl = "https://openrouter.ai/api/v1/"
        DefaultModel = "google/gemini-3-pro-preview"
    }
    let aiClient = OpenRouterClient(aiConfig)
    let ingestor = Ingestor(store, aiClient)
    let gardener = Gardener(store)

    // 2. Command Dispatcher
    let result =
        match argv |> List.ofArray with
        | "ingest" :: root :: _ ->
            printfn "🚀 Starting ingestion from %s..." root
            ingestor.ScanDirectoryAsync(root) |> Async.RunSynchronously
            0
            
        | "status" :: _ ->
            printfn "📊 Indrajaal Knowledge Engine Status"
            printfn "Database: %s" dbPath
            let report = store.GetEntropyReport(0.0)
            printfn "Total Holons Indexed: %d" (Seq.length report)
            0
            
        | "ask" :: query ->
            let fullQuery = String.concat " " query
            printfn "🔮 Consulting the Oracle: \"%s\"" fullQuery
            // In a full implementation, we would retrieve context from the DB here
            let context = "Indrajaal v20.0.0 Architecture Overview..." 
            let response = aiClient.OracleConsultAsync(fullQuery, context) |> Async.AwaitTask |> Async.RunSynchronously
            printfn "\n--- Oracle Response ---\n%s\n" response
            0

        | "generate" :: topic :: outputPath :: _ ->
            printfn "✍️ Generating Artifact: \"%s\" -> %s" topic outputPath
            let context = "Retrieved Context: [Placeholder for Vector Search Results]"
            let template = "Standard Holonic Document Template"
            
            let content = aiClient.GenerateArtifactAsync(topic, context, template) |> Async.AwaitTask |> Async.RunSynchronously
            
            let dir = Path.GetDirectoryName(outputPath)
            if not (String.IsNullOrEmpty(dir)) then Directory.CreateDirectory(dir) |> ignore
            
            File.WriteAllText(outputPath, content)
            printfn "✔ Document saved to %s" outputPath
            
            // Auto-ingest the new file
            ingestor.ProcessFileAsync(outputPath) |> Async.RunSynchronously
            0
            
        | "garden" :: _ ->
            gardener.GardenAsync() |> Async.RunSynchronously
            0

        | "benchmark" :: _ ->
            printfn "🏎️  Running Performance Benchmark (3 Files)..."
            let allFiles = Directory.GetFiles("docs/", "*.md", SearchOption.AllDirectories) |> List.ofArray
            let sample = allFiles |> List.truncate 3
            ingestor.IngestFilesAsync(sample) |> Async.RunSynchronously
            0

        | _ ->
            printfn "Indrajaal Knowledge Engine (IKE) CLI"
            printfn "Usage:"
            printfn "  indrajaal ingest <path>               - Scans and indexes documents"
            printfn "  indrajaal status                      - Shows system health and entropy"
            printfn "  indrajaal ask <query>                 - Consults the Oracle (OpenRouter)"
            printfn "  indrajaal generate <topic> <outfile>  - AI generates and saves a new document"
            printfn "  indrajaal garden                      - Runs maintenance tasks"
            1

    result