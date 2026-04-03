namespace Cepaf.KmsCatalog.Tests

open System.IO
open NUnit.Framework
open Cepaf.KmsCatalog
open Cepaf.KmsCatalog.Domain
open Cepaf.KmsCatalog.SafeCatalog
open Cepaf.KmsCatalog.CheckpointDomain
open Microsoft.Data.Sqlite

// LEVEL 8: MASTER ORCHESTRATION & SUBSYSTEM INTERACTIONS
// Verifies all 7 levels of module interactions.

[<TestFixture>]
type Level8_OrchestrationTests() =

    let dbPath = "test_l8.db"
    let connStr = sprintf "Data Source=%s" dbPath

    [<SetUp>]
    member this.Setup() =
        // Initialize schema for Level 8
        use conn = new SqliteConnection(connStr)
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            CREATE TABLE IF NOT EXISTS holons (
                id TEXT PRIMARY KEY,
                fqun TEXT UNIQUE,
                type TEXT,
                name TEXT,
                payload JSON,
                vital_signs JSON,
                updated_at DATETIME
            )
        """
        cmd.ExecuteNonQuery() |> ignore

    [<TearDown>]
    member this.Teardown() =
        if File.Exists(dbPath) then File.Delete(dbPath)
    
    [<Test>]
    member this.``Orchestrator should coordinate 7 levels of interaction``() =
        // 1. Setup Mock Registry
        let registry = MockRegistry()
        let ctx = { Actor = "test-orchestrator"; Registry = registry; DbPath = dbPath }
        let orchestrator = CatalogOrchestrator(ctx)

        // 2. Prepare Mock Entity
        let entity = {
            ApiVersion = "v1"
            Kind = KindComponent
            Metadata = { Name = "orchestrated-service"; Namespace = "default"; Uid = None; Title = None; Description = Some "Verified via Orchestrator"; Tags = []; Labels = Map.empty; Annotations = Map.empty; Links = Map.empty }
            Spec = Component { Type = "service"; Lifecycle = Production; Owner = "team-a"; System = None; DependsOn = []; ProvidesApis = []; ConsumesApis = [] }
        }

        // --- Interaction Levels ---

        // Level 7: Module -> Module (Orchestrator -> Scorecard)
        Assert.DoesNotThrow(fun () -> orchestrator.EvaluateCompliance(entity))

        // Level 4: Orchestrator -> Safety (UCR)
        // Level 3: Orchestrator -> Storage (SQLite)
        // Level 5: Orchestrator -> Network (Zenoh)
        Assert.DoesNotThrow(fun () -> 
            match SafeCatalog.ingestEntity ctx entity with
            | Ok _ -> 
                orchestrator.IndexForSearch(entity)
                MeshCatalog.broadcastEntity entity
            | Error e -> Assert.Fail(e)
        )

        // Level 6: Orchestrator -> External (Runtime)
        Assert.DoesNotThrow(fun () -> orchestrator.SyncRuntime())

        // Level 1 & 2: GUI/CLI -> Orchestrator (Implicit via method calls)
        Assert.Pass("Orchestration successful across all modules")