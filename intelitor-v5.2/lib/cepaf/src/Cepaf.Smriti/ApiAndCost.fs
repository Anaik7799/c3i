namespace Cepaf.Smriti

open System
open Cepaf.Smriti.Domain

// Run 3: API & Cost Intelligence

module CostInsights =
    
    // Aggregation Logic for Cost Metrics
    let calculateProjectCost (entities: CatalogEntity list) =
        entities
        |> List.choose (fun e ->
            match e.Spec with
            | CostMetric c -> Some c.DailyCost
            | _ -> None
        )
        |> List.sum

    let generateReport (entities: CatalogEntity list) =
        let total = calculateProjectCost entities
        sprintf "Total Daily Cost: %f" total

module ApiExplorer =

    // Logic to parse/render API Definitions
    
    type ApiDefinition = 
        | OpenAPI of string
        | AsyncAPI of string
        | GraphQL of string
        | Unknown

    let parseDefinition (api: ApiSpec) =
        match api.Type.ToLower() with
        | "openapi" -> OpenAPI api.Definition
        | "asyncapi" -> AsyncAPI api.Definition
        | "graphql" -> GraphQL api.Definition
        | _ -> Unknown

    let render (api: ApiDefinition) =
        match api with
        | OpenAPI def -> sprintf "Rendering Swagger UI for %d chars" def.Length
        | _ -> "Unsupported format"
