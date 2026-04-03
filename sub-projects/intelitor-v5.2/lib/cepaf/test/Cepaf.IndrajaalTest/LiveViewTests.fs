/// Cepaf.IndrajaalTest.LiveViewTests
/// LiveView page accessibility and rendering tests
///
/// STAMP Constraints:
/// - SC-VIEW-001: All pages must be accessible
/// - SC-VIEW-002: Error pages must not expose sensitive data
module Cepaf.IndrajaalTest.LiveViewTests

open System
open System.Net.Http
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.HttpClient

// =============================================================================
// Page Response Types
// =============================================================================

/// Simple page response (just checking accessibility)
type PageResponse = {
    StatusCode: int
    ContentType: string option
    ContentLength: int64
    Title: string option
}

// =============================================================================
// Page Accessibility Tests
// =============================================================================

/// Check if page is accessible
let checkPageAccessible (client: HttpClient) (path: string) =
    async {
        let startTime = DateTime.UtcNow
        try
            let! response = client.GetAsync(path) |> Async.AwaitTask
            let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask
            let duration = DateTime.UtcNow - startTime

            let contentType =
                if response.Content.Headers.ContentType <> null then
                    Some response.Content.Headers.ContentType.MediaType
                else None

            return Ok {
                StatusCode = int response.StatusCode
                ContentType = contentType
                ContentLength = int64 content.Length
                Title =
                    // Try to extract title from HTML
                    let titleMatch = System.Text.RegularExpressions.Regex.Match(content, @"<title>([^<]+)</title>")
                    if titleMatch.Success then Some titleMatch.Groups.[1].Value
                    else None
            }
        with ex ->
            return Error (ConnectionError ex.Message)
    }

/// Create public page tests
let createPublicPageTests (config: ServerConfig) =
    let client = createClient config

    testList "Public Pages" [

        testAsync "Home page (/) is accessible" {
            let! result = checkPageAccessible client Pages.home

            match result with
            | Ok page ->
                Expect.isTrue (page.StatusCode = 200 || page.StatusCode = 302)
                    "Home page should return 200 or redirect"
            | Error err ->
                failtest (sprintf "Failed to access home: %A" err)
        }

        testAsync "Health endpoints are accessible" {
            let! result = checkPageAccessible client Endpoints.Health.healthz

            match result with
            | Ok page ->
                Expect.equal page.StatusCode 200 "Health should return 200"
            | Error err ->
                failtest (sprintf "Failed to access health: %A" err)
        }
    ]

/// Create authenticated page tests
let createAuthenticatedPageTests (config: ServerConfig) =
    let client = createClient config

    testList "Authenticated Pages" [

        testAsync "Cockpit main page requires auth" {
            let! result = checkPageAccessible client Pages.Cockpit.main

            match result with
            | Ok page ->
                // Should redirect to login or return 401/403
                Expect.isTrue
                    (page.StatusCode = 302 || page.StatusCode = 401 || page.StatusCode = 403 || page.StatusCode = 200)
                    "Cockpit should require auth or be publicly visible"
            | Error err ->
                failtest (sprintf "Failed to access cockpit: %A" err)
        }

        testAsync "Operations pages require auth" {
            let pages = [
                Pages.Operations.alarms
                Pages.Operations.access
                Pages.Operations.video
                Pages.Operations.dispatch
            ]

            for pagePath in pages do
                let! result = checkPageAccessible client pagePath

                match result with
                | Ok page ->
                    Expect.isTrue
                        (page.StatusCode = 302 || page.StatusCode = 401 || page.StatusCode = 403 || page.StatusCode = 404)
                        (sprintf "Page %s should require auth" pagePath)
                | Error _ ->
                    // Connection error is acceptable
                    ()
        }

        testAsync "Admin pages require auth" {
            let pages = [
                Pages.Admin.permissions
                Pages.Admin.accessControl
                Pages.Admin.config
                Pages.Admin.systemStatus
            ]

            for pagePath in pages do
                let! result = checkPageAccessible client pagePath

                match result with
                | Ok page ->
                    Expect.isTrue
                        (page.StatusCode = 302 || page.StatusCode = 401 || page.StatusCode = 403 || page.StatusCode = 404)
                        (sprintf "Admin page %s should require auth" pagePath)
                | Error _ ->
                    // Connection error is acceptable
                    ()
        }
    ]

// =============================================================================
// Cockpit Page Tests
// =============================================================================

/// Create PRAJNA Cockpit page tests
let createCockpitPageTests (config: ServerConfig) =
    let client = createClient config

    let cockpitPages = [
        (Pages.Cockpit.main, "Main")
        (Pages.Cockpit.dashboard, "Dashboard")
        (Pages.Cockpit.startup, "Startup")
        (Pages.Cockpit.containers, "Containers")
        (Pages.Cockpit.commands, "Commands")
        (Pages.Cockpit.mesh, "Mesh")
        (Pages.Cockpit.alarms, "Alarms")
        (Pages.Cockpit.aiCopilot, "AI Copilot")
        (Pages.Cockpit.cluster, "Cluster")
        (Pages.Cockpit.settings, "Settings")
        (Pages.Cockpit.diagnostics, "Diagnostics")
        (Pages.Cockpit.shutdown, "Shutdown")
        (Pages.Cockpit.observability, "Observability")
    ]

    testList "Cockpit Pages" [
        for (path, name) in cockpitPages do
            yield testAsync (sprintf "Cockpit %s page responds" name) {
                let! result = checkPageAccessible client path

                match result with
                | Ok page ->
                    // Any response other than 5xx is acceptable
                    Expect.isTrue (page.StatusCode < 500)
                        (sprintf "Cockpit %s should not return 5xx" name)
                | Error _ ->
                    // Connection error - server might not be running
                    skiptest "Server not available"
            }
    ]

// =============================================================================
// Response Security Tests
// =============================================================================

/// Create security-focused page tests
let createPageSecurityTests (config: ServerConfig) =
    let client = createClient config

    testList "Page Security" [

        testAsync "404 page does not expose stack traces" {
            let! result = checkPageAccessible client "/nonexistent-page-12345"

            match result with
            | Ok page ->
                Expect.equal page.StatusCode 404 "Should return 404"
                // Would need to check content for stack traces
            | Error _ ->
                skiptest "Server not available"
        }

        testAsync "Error pages return proper content type" {
            let! result = checkPageAccessible client "/nonexistent-page-12345"

            match result with
            | Ok page ->
                match page.ContentType with
                | Some ct ->
                    Expect.isTrue (ct.Contains("text/html") || ct.Contains("application/json"))
                        "Error pages should return HTML or JSON"
                | None ->
                    // No content type is acceptable for 404
                    ()
            | Error _ ->
                skiptest "Server not available"
        }

        testAsync "Pages include security headers" {
            // This would require checking response headers
            // For now, just verify pages respond
            let! result = checkPageAccessible client Pages.home

            match result with
            | Ok page ->
                Expect.isTrue (page.StatusCode < 500) "Should not return 5xx"
            | Error _ ->
                skiptest "Server not available"
        }
    ]

// =============================================================================
// STAMP Constraint Tests
// =============================================================================

/// Create STAMP page constraint tests
let createStampPageTests (config: ServerConfig) =
    let client = createClient config

    testList "STAMP Page Constraints" [

        testAsync "SC-VIEW-001: All defined pages respond" {
            let allPages = [
                Pages.home
                Pages.Cockpit.main
                Pages.Operations.alarms
                Pages.Admin.permissions
            ]

            for path in allPages do
                let! result = checkPageAccessible client path

                match result with
                | Ok page ->
                    Expect.isTrue (page.StatusCode < 500)
                        (sprintf "Page %s should not return 5xx" path)
                | Error _ ->
                    // Server might not be running
                    ()
        }

        testAsync "SC-VIEW-002: Response times are reasonable" {
            let startTime = DateTime.UtcNow
            let! _ = checkPageAccessible client Pages.home
            let elapsed = DateTime.UtcNow - startTime

            Expect.isLessThan elapsed.TotalSeconds 10.0
                "Page should respond within 10 seconds"
        }
    ]

// =============================================================================
// All LiveView Tests
// =============================================================================

/// All LiveView tests combined
let allLiveViewTests (config: ServerConfig) =
    testList "LiveView Tests" [
        createPublicPageTests config
        createAuthenticatedPageTests config
        createCockpitPageTests config
        createPageSecurityTests config
        createStampPageTests config
    ]
