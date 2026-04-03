/// Z-KMS API Routes
///
/// Defines all HTTP endpoints for the Z-KMS API server
module Cepaf.Smriti.Api.Routes

open System
open Giraffe
open Cepaf.Smriti.Api.Data.KmsRepository
open Cepaf.Smriti.Api.Data.AnalyticsQuery
open Cepaf.Smriti.Api.Handlers

/// Parse GUID from route
let private guidHandler (handler: Guid -> HttpHandler) (id: string) : HttpHandler =
    match Guid.TryParse(id) with
    | true, guid -> handler guid
    | false, _ -> RequestErrors.BAD_REQUEST "Invalid GUID format"

/// Configure all API routes
let webApp (kmsRepo: IKmsRepository) (analyticsRepo: IAnalyticsRepository) : HttpHandler =
    choose [
        // Health check
        GET >=> route "/health" >=> json {| status = "healthy"; service = "smriti-api" |}

        // API endpoints
        subRoute "/api" (
            choose [
                // Zettels
                subRoute "/zettels" (
                    choose [
                        GET >=> route "" >=> ZettelHandler.getAllZettels kmsRepo
                        GET >=> routef "/%s" (guidHandler (ZettelHandler.getZettel kmsRepo))
                        GET >=> routef "/%s/backlinks" (guidHandler (ZettelHandler.getBacklinks kmsRepo))
                        GET >=> routef "/%s/context" (guidHandler (ZettelHandler.getZettelContext kmsRepo))
                    ]
                )

                // Graph
                subRoute "/graph" (
                    choose [
                        GET >=> route "" >=> GraphHandler.getGraph kmsRepo
                        GET >=> routef "/cluster/%s" (GraphHandler.getClusterGraph kmsRepo)
                        GET >=> route "/clusters" >=> GraphHandler.getClusters kmsRepo
                    ]
                )

                // Search
                subRoute "/search" (
                    choose [
                        GET >=> route "" >=> SearchHandler.search kmsRepo
                        POST >=> route "/vector" >=> SearchHandler.vectorSearch kmsRepo
                        GET >=> route "/suggestions" >=> SearchHandler.suggestions kmsRepo
                        GET >=> route "/tags" >=> SearchHandler.getTags kmsRepo
                    ]
                )

                // Metrics
                subRoute "/metrics" (
                    choose [
                        GET >=> route "/entropy" >=> GraphHandler.getEntropyMetrics kmsRepo
                        GET >=> routef "/evolution/%s" (guidHandler (GraphHandler.getEvolutionTimeline analyticsRepo))
                        GET >=> route "/recent" >=> GraphHandler.getRecentEvolution analyticsRepo
                    ]
                )

                // Visualization
                subRoute "/viz" (
                    choose [
                        GET >=> route "/mindmap" >=> GraphHandler.getMindMap analyticsRepo
                    ]
                )
            ]
        )

        // MCP endpoints (Model Context Protocol for AI agents)
        subRoute "/mcp" (
            choose [
                GET >=> route "/tools" >=> McpHandler.listTools
                GET >=> routef "/read_zettel/%s" (guidHandler (McpHandler.readZettel kmsRepo))
                GET >=> route "/search" >=> McpHandler.mcpSearch kmsRepo
                GET >=> route "/context" >=> McpHandler.getContext kmsRepo
                GET >=> routef "/source/%s" (guidHandler (McpHandler.getSource analyticsRepo))
                GET >=> routef "/evolution/%s" (guidHandler (McpHandler.getEvolution analyticsRepo))
            ]
        )

        // Not found
        RequestErrors.NOT_FOUND "Endpoint not found"
    ]
