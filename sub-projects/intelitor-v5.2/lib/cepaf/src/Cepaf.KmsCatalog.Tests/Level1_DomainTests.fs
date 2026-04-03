namespace Cepaf.KmsCatalog.Tests

open NUnit.Framework
open Cepaf.KmsCatalog.Domain

// LEVEL 1: DOMAIN & TYPE SYSTEM VERIFICATION
// Ensures strict F# types correctly model the Backstage Entity specification.

[<TestFixture>]
type Level1_DomainTests() =

    [<Test>]
    member this.``EntityKind should serialize to string correctly``() =
        let kind = KindComponent
        Assert.AreEqual("Component", kind.ToString().Replace("Kind", ""))

    [<Test>]
    member this.``EntityRef helper should format canonical references``() =
        let entity = {
            ApiVersion = "v1"
            Kind = KindComponent
            Metadata = {
                Name = "my-service"
                Namespace = "default"
                Uid = None
                Title = None
                Description = None
                Tags = []
                Labels = Map.empty
                Annotations = Map.empty
                Links = Map.empty
            }
            Spec = Generic Map.empty
        }
        let ref = EntityHelper.getRef entity
        Assert.AreEqual("KindComponent:default/my-service", ref)

    [<Test>]
    member this.``Discriminated Union Spec should enforce type safety``() =
        let spec = Component {
            Type = "service"
            Lifecycle = Production
            Owner = "team-a"
            System = None
            DependsOn = []
            ProvidesApis = []
            ConsumesApis = []
        }
        
        match spec with
        | Component c -> Assert.AreEqual("team-a", c.Owner)
        | _ -> Assert.Fail("Spec should be Component")

    [<Test>]
    member this.``EntityHelper isProduction should correctly identify prod components``() =
        let entity = {
            ApiVersion = "v1"
            Kind = KindComponent
            Metadata = { Name = "a"; Namespace = "b"; Uid = None; Title = None; Description = None; Tags = []; Labels = Map.empty; Annotations = Map.empty; Links = Map.empty }
            Spec = Component { Type = ""; Lifecycle = Production; Owner = ""; System = None; DependsOn = []; ProvidesApis = []; ConsumesApis = [] }
        }
        Assert.True(EntityHelper.isProduction entity)
