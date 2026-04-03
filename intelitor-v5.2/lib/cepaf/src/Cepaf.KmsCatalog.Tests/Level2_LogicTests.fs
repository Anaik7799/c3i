namespace Cepaf.KmsCatalog.Tests

open System.IO
open NUnit.Framework
open Cepaf.KmsCatalog
open Cepaf.KmsCatalog.Domain

// LEVEL 2: LOGIC & ALGORITHMIC VERIFICATION
// Tests parsing logic, scoring engines, and search algorithms.

[<TestFixture>]
type Level2_LogicTests() =

    // --- Ingestion Logic ---
    
    [<Test>]
    member this.``Ingestor should parse valid YAML catalog-info``() =
        let yaml = """
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: test-component
  namespace: default
spec:
  type: service
  lifecycle: production
  owner: team-a
"""
        let path = Path.GetTempFileName()
        File.WriteAllText(path, yaml)
        
        match Ingestor.parseCatalogFile path with
        | Ok entity ->
            Assert.AreEqual("test-component", entity.Metadata.Name)
            Assert.AreEqual(KindComponent, entity.Kind)
        | Error e -> Assert.Fail(e)
        
        File.Delete(path)

    // --- Scorecard Logic ---

    [<Test>]
    member this.``Scorecard should penalize missing owner``() =
        let entity = {
            ApiVersion = "v1"; Kind = KindComponent;
            Metadata = { Name = "test"; Namespace = "default"; Uid = None; Title = None; Description = Some "desc"; Tags = []; Labels = Map.empty; Annotations = Map.empty; Links = Map.empty };
            Spec = Component { Type = "service"; Lifecycle = Production; Owner = ""; System = None; DependsOn = []; ProvidesApis = []; ConsumesApis = [] }
        }
        
        let report = Scorecard.evaluate entity
        // Weight 1.0 + 0.5 + 2.0 = 3.5 max
        // Missing owner (1.0) -> Pass Description (0.5), Fail Production PagerDuty (2.0)
        // Score = 0.5 / 3.5 ~ 0.14
        
        Assert.Less(report.Score, 3.5)
        Assert.IsTrue(report.Results |> List.exists (fun (n, r) -> n.Contains("owner") && match r with Scorecard.Fail _ -> true | _ -> false))

    // --- Search Logic ---

    [<Test>]
    member this.``Search backend should filter by string``() =
        let backend = Search.InMemoryBackend() :> Search.ISearchBackend
        let e1 = { 
            ApiVersion = "v1"; Kind = KindComponent; 
            Metadata = { Name = "auth-service"; Namespace = "default"; Uid = None; Title = None; Description = Some "Authentication"; Tags = []; Labels = Map.empty; Annotations = Map.empty; Links = Map.empty }; 
            Spec = Generic Map.empty 
        }
        backend.Index(e1)
        
        let results = backend.Query("auth")
        Assert.AreEqual(1, results.Length)
        Assert.AreEqual("auth-service", results[0].Highlight)
