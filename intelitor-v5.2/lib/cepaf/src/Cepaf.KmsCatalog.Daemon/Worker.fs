namespace Cepaf.KmsCatalog.Daemon

open System
open System.Threading
open System.Threading.Tasks
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.Logging
open Cepaf.KmsCatalog
open Cepaf.KmsCatalog.SafeCatalog
open Cepaf.KmsCatalog.CheckpointDomain

type Worker(logger: ILogger<Worker>) =
    inherit BackgroundService()

    // Mock Registry for Daemon (In Prod use real persistence)
    let registry = { 
        new ICheckpointRegistry with 
            member _.Commit r = Ok r.Id 
            member _.Verify id = true 
            member _.Rollback id = Ok () 
    }
    
    // Configurable Path
    let dbPath = Environment.GetEnvironmentVariable("KMS_DB_PATH") |> Option.ofObj |> Option.defaultValue "data/kms/holons.db"
    
    let ctx = { Actor = "kms-daemon"; Registry = registry; DbPath = dbPath }
    let orchestrator = CatalogOrchestrator(ctx)

    override this.ExecuteAsync(stoppingToken: CancellationToken) =
        task {
            logger.LogInformation("KMS Catalog Daemon running at: {time}", DateTimeOffset.Now)
            
            // Initial Sync
            try
                // In a real scenario, we might harvest a configured repo list here
                // orchestrator.IngestRepository("./") 
                ()
            with ex ->
                logger.LogError(ex, "Error during initial harvest")

            while not stoppingToken.IsCancellationRequested do
                try
                    logger.LogInformation("Syncing Runtime State...")
                    orchestrator.SyncRuntime()
                    
                    // Future: orchestrator.SyncZenoh()
                with ex ->
                    logger.LogError(ex, "Error during sync cycle")

                // OODA Loop Heartbeat (30s)
                do! Task.Delay(30000, stoppingToken)
        }
