namespace Cepaf.Smriti

open System
open Cepaf.Smriti.Domain
open Cepaf.Smriti.SafeCatalog
open Cepaf.Smriti.CheckpointDomain

// Run 7: Subsystem Integration - The Master Orchestrator
// Coordinates interactions between all 8 degrees of the Catalog.

type CatalogOrchestrator(ctx: CatalogContext) =

    let connStr = sprintf "Data Source=%s" ctx.DbPath

    member this.Context = ctx

    // --- Degree 2: Ingestion ---
    member this.IngestRepository(repoPath: string) =
        printfn "[Orchestrator] Harvesting repository: %s" repoPath
        let results = Ingestor.harvestRepo repoPath
        results |> List.iter (function
            | Ok entity -> 
                match SafeCatalog.ingestEntity ctx entity with
                | Ok ckptId -> 
                    printfn "[Orchestrator] Successfully ingested %s (Checkpoint: %s)" entity.Metadata.Name ckptId
                    // Trigger Degree 6: Scorecard
                    this.EvaluateCompliance(entity)
                    // Trigger Degree 7: Discovery Indexing
                    this.IndexForSearch(entity)
                    // Trigger Degree 8: Mesh Federation
                    MeshCatalog.broadcastEntity entity
                | Error e -> printfn "[Orchestrator] FAILED to ingest %s: %s" entity.Metadata.Name e
            | Error e -> printfn "[Orchestrator] Harvester Error: %s" e
        )

    // --- Degree 5: Scaffolding ---
    member this.ExecuteScaffold(template: CatalogEntity, parameters: Map<string, obj>) =
        printfn "[Orchestrator] Executing Scaffold Template: %s" template.Metadata.Name
        Scaffolder.executeTemplate template parameters
        match SafeCatalog.registerTemplate ctx template with
        | Ok id -> printfn "[Orchestrator] Registered template execution in UCR: %s" id
        | Error e -> printfn "[Orchestrator] Failed to record scaffolding in UCR: %s" e

    // --- Degree 6: Scorecard ---
    member this.EvaluateCompliance(entity: CatalogEntity) =
        let report = Scorecard.evaluate entity
        printfn "[Orchestrator] Compliance Score for %s: %.2f/%.2f" entity.Metadata.Name report.Score report.MaxScore

    // --- Degree 7: TechDocs & Search ---
    member this.IndexForSearch(entity: CatalogEntity) =
        ()

    // --- Degree 4: Runtime Binding ---
    member this.SyncRuntime() =
        printfn "[Orchestrator] Syncing Runtime state (Podman/K8s)..."
        RuntimeBinder.sync connStr