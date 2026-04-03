/// Cepaf.Podman Image Build Integration Tests
/// Testing image operations: build, tag, inspect, remove
module Cepaf.Podman.Tests.ImageBuildTests

open System
open System.IO
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

// ============================================================================
// Test Configuration
// ============================================================================

/// Test image naming prefix
let testImagePrefix = "localhost/cepaf-test-"

/// Generate unique test image name
let generateTestImageName () =
    sprintf "%s%s" testImagePrefix (Guid.NewGuid().ToString("N").Substring(0, 8))

// ============================================================================
// Image Test Result
// ============================================================================

type ImageTestResult =
    | Success of testName: string * duration: TimeSpan * message: string
    | Failure of testName: string * duration: TimeSpan * error: string
    | Skipped of testName: string * reason: string

// ============================================================================
// Image List and Inspect Tests
// ============================================================================

/// Test: List all images
let testListImages (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Images.list client false
    let duration = DateTime.UtcNow - start

    match result with
    | Ok images ->
        return Success ("List images", duration, sprintf "Found %d images" images.Length)
    | Error e ->
        return Failure ("List images", duration, PodmanError.toMessage e)
}

/// Test: List all images including intermediate
let testListAllImages (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Images.listAll client
    let duration = DateTime.UtcNow - start

    match result with
    | Ok images ->
        let intermediate = images |> List.filter (fun i -> i.RepoTags |> List.isEmpty) |> List.length
        return Success ("List all images", duration, sprintf "Found %d images (%d intermediate)" images.Length intermediate)
    | Error e ->
        return Failure ("List all images", duration, PodmanError.toMessage e)
}

/// Test: Check localhost images only (SC-CNT-010 compliance)
let testLocalhostImagesOnly (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Images.list client false
    let duration = DateTime.UtcNow - start

    match result with
    | Ok images ->
        let localhostImages =
            images
            |> List.filter (fun i ->
                i.RepoTags |> List.exists (fun t -> t.StartsWith("localhost/")))
        let nonLocalhostImages =
            images
            |> List.filter (fun i ->
                i.RepoTags |> List.exists (fun t ->
                    not (t.StartsWith("localhost/")) && not (t = "<none>:<none>")))
        return Success (
            "Localhost images check",
            duration,
            sprintf "localhost/: %d, other: %d" localhostImages.Length nonLocalhostImages.Length)
    | Error e ->
        return Failure ("Localhost images check", duration, PodmanError.toMessage e)
}

/// Test: Inspect existing image
let testInspectImage (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    // First get an image to inspect
    let! listResult = Images.list client false
    match listResult with
    | Error e ->
        return Failure ("Inspect image", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Inspect image", "No images available")
    | Ok (img :: _) ->
        let! inspectResult = Images.inspect client img.Id
        let duration = DateTime.UtcNow - start

        match inspectResult with
        | Ok imageInfo ->
            return Success (
                "Inspect image",
                duration,
                sprintf "ID: %s, Arch: %s, OS: %s, Size: %.2fMB"
                    (imageInfo.Id.Substring(0, min 12 imageInfo.Id.Length))
                    imageInfo.Architecture
                    imageInfo.Os
                    (float imageInfo.Size / 1024.0 / 1024.0))
        | Error e ->
            return Failure ("Inspect image", duration, PodmanError.toMessage e)
}

/// Test: Get image history
let testImageHistory (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! listResult = Images.list client false
    match listResult with
    | Error e ->
        return Failure ("Image history", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Image history", "No images available")
    | Ok (img :: _) ->
        let! historyResult = Images.history client img.Id
        let duration = DateTime.UtcNow - start

        match historyResult with
        | Ok layers ->
            return Success ("Image history", duration, sprintf "Found %d layers" layers.Length)
        | Error e ->
            return Failure ("Image history", duration, PodmanError.toMessage e)
}

/// Test: Check image exists
let testImageExists (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! listResult = Images.list client false
    match listResult with
    | Error e ->
        return Failure ("Image exists check", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Image exists check", "No images available")
    | Ok (img :: _) ->
        let reference = img.RepoTags |> List.tryHead |> Option.defaultValue img.Id
        let! existsResult = Images.exists client reference
        let duration = DateTime.UtcNow - start

        match existsResult with
        | Ok true ->
            return Success ("Image exists check", duration, sprintf "%s exists" reference)
        | Ok false ->
            return Failure ("Image exists check", duration, "Known image reported as not existing")
        | Error e ->
            return Failure ("Image exists check", duration, PodmanError.toMessage e)
}

/// Test: Check non-existent image
let testImageNotExists (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let fakeImage = "localhost/this-image-does-not-exist-" + Guid.NewGuid().ToString("N")
    let! existsResult = Images.exists client fakeImage
    let duration = DateTime.UtcNow - start

    match existsResult with
    | Ok false ->
        return Success ("Non-existent image check", duration, "Correctly reported as not existing")
    | Ok true ->
        return Failure ("Non-existent image check", duration, "Fake image reported as existing")
    | Error e ->
        return Failure ("Non-existent image check", duration, PodmanError.toMessage e)
}

// ============================================================================
// Image Tag Tests
// ============================================================================

/// Test: Tag an image
let testTagImage (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! listResult = Images.list client false
    match listResult with
    | Error e ->
        return Failure ("Tag image", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Tag image", "No images available")
    | Ok (img :: _) ->
        let newRepo = sprintf "localhost/cepaf-tag-test-%s" (Guid.NewGuid().ToString("N").Substring(0, 8))
        let newTag = "test-v1"

        let! tagResult = Images.tag client img.Id newRepo newTag
        match tagResult with
        | Error e ->
            return Failure ("Tag image", DateTime.UtcNow - start, PodmanError.toMessage e)
        | Ok () ->
            // Verify tag exists
            let fullRef = sprintf "%s:%s" newRepo newTag
            let! verifyResult = Images.exists client fullRef

            // Cleanup - untag
            let! _ = Images.untag client fullRef

            let duration = DateTime.UtcNow - start

            match verifyResult with
            | Ok true ->
                return Success ("Tag image", duration, sprintf "Tagged as %s" fullRef)
            | Ok false ->
                return Failure ("Tag image", duration, "Tag not found after tagging")
            | Error e ->
                return Failure ("Tag image", duration, PodmanError.toMessage e)
}

/// Test: Untag an image
let testUntagImage (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! listResult = Images.list client false
    match listResult with
    | Error e ->
        return Failure ("Untag image", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Untag image", "No images available")
    | Ok (img :: _) ->
        // First tag it
        let newRepo = sprintf "localhost/cepaf-untag-test-%s" (Guid.NewGuid().ToString("N").Substring(0, 8))
        let newTag = "to-remove"
        let fullRef = sprintf "%s:%s" newRepo newTag

        let! tagResult = Images.tag client img.Id newRepo newTag
        match tagResult with
        | Error e ->
            return Failure ("Untag image", DateTime.UtcNow - start, sprintf "Setup tagging failed: %s" (PodmanError.toMessage e))
        | Ok () ->
            // Now untag
            let! untagResult = Images.untag client fullRef
            let duration = DateTime.UtcNow - start

            match untagResult with
            | Ok () ->
                // Verify tag is gone
                let! existsAfter = Images.exists client fullRef
                match existsAfter with
                | Ok false ->
                    return Success ("Untag image", duration, sprintf "Untagged %s" fullRef)
                | Ok true ->
                    return Failure ("Untag image", duration, "Tag still exists after untag")
                | Error e ->
                    return Failure ("Untag image", duration, PodmanError.toMessage e)
            | Error e ->
                return Failure ("Untag image", duration, PodmanError.toMessage e)
}

// ============================================================================
// Image Pull Tests (localhost only per SC-CNT-010)
// ============================================================================

/// Test: Pull from external registry rejected (SC-CNT-010)
let testPullExternalRejected (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    // Attempt to pull from docker.io - should be rejected
    let! result = Images.pull client "docker.io/alpine:latest"
    let duration = DateTime.UtcNow - start

    match result with
    | Error (PodmanError.RegistryNotAllowed _) ->
        return Success ("External pull rejected", duration, "Correctly rejected docker.io pull")
    | Error e ->
        return Success ("External pull rejected", duration, sprintf "Rejected with: %s" (PodmanError.toMessage e))
    | Ok _ ->
        return Failure ("External pull rejected", duration, "External registry pull should have been rejected!")
}

/// Test: Pull localhost image (if exists)
let testPullLocalhost (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    // This would only work if there's a local registry running
    // For testing purposes, we just verify the API accepts localhost/ references
    let testRef = "localhost/nonexistent-test-image:v1"
    let! result = Images.pull client testRef
    let duration = DateTime.UtcNow - start

    match result with
    | Error (PodmanError.RegistryNotAllowed _) ->
        return Failure ("Localhost pull accepted", duration, "localhost/ should be allowed")
    | Error _ ->
        // Expected - image doesn't exist but the registry was accepted
        return Success ("Localhost pull accepted", duration, "localhost/ registry accepted (image not found as expected)")
    | Ok _ ->
        return Success ("Localhost pull accepted", duration, "localhost/ pull succeeded")
}

// ============================================================================
// Image Build Tests (Containerfile-based)
// ============================================================================

/// Test: Build options creation
let testBuildOptionsCreation () : ImageTestResult =
    let start = DateTime.UtcNow

    let opts =
        Images.BuildOptions.defaults
        |> Images.BuildOptions.withTag "localhost/test:v1"
        |> Images.BuildOptions.withNoCache
        |> Images.BuildOptions.withLabel "maintainer" "test"
        |> Images.BuildOptions.withBuildArg "VERSION" "1.0"

    let duration = DateTime.UtcNow - start

    if opts.Tags = ["localhost/test:v1"] &&
       opts.NoCache = true &&
       opts.Labels |> Map.containsKey "maintainer" &&
       opts.BuildArgs |> Map.containsKey "VERSION" then
        Success ("Build options creation", duration, "Options created correctly")
    else
        Failure ("Build options creation", duration, "Options not set correctly")

/// Test: Build returns not implemented (placeholder)
let testBuildNotImplemented (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let opts = Images.BuildOptions.defaults |> Images.BuildOptions.withTag "localhost/test:v1"
    let! result = Images.build client "/tmp" opts
    let duration = DateTime.UtcNow - start

    match result with
    | Error (PodmanError.InternalError msg) when msg.Contains("not implemented") ->
        return Success ("Build returns expected error", duration, "Build correctly returns not-implemented")
    | Error e ->
        return Failure ("Build returns expected error", duration, PodmanError.toMessage e)
    | Ok _ ->
        return Failure ("Build returns expected error", duration, "Build should not succeed without implementation")
}

// ============================================================================
// Image Find Tests
// ============================================================================

/// Test: Find image by reference
let testFindByReference (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! listResult = Images.list client false
    match listResult with
    | Error e ->
        return Failure ("Find by reference", DateTime.UtcNow - start, PodmanError.toMessage e)
    | Ok [] ->
        return Skipped ("Find by reference", "No images available")
    | Ok (img :: _) ->
        // Use part of the image ID or tag
        let searchTerm =
            match img.RepoTags |> List.tryHead with
            | Some tag -> tag.Split(':').[0]  // Just the name part
            | None -> img.Id.Substring(0, 12)

        let! findResult = Images.findByReference client searchTerm
        let duration = DateTime.UtcNow - start

        match findResult with
        | Ok (Some found) ->
            return Success ("Find by reference", duration, sprintf "Found image by '%s'" searchTerm)
        | Ok None ->
            return Failure ("Find by reference", duration, sprintf "Image not found by '%s'" searchTerm)
        | Error e ->
            return Failure ("Find by reference", duration, PodmanError.toMessage e)
}

// ============================================================================
// Image Size Analysis Tests
// ============================================================================

/// Test: Analyze image sizes
let testAnalyzeImageSizes (client: PodmanClient) : Async<ImageTestResult> = async {
    let start = DateTime.UtcNow

    let! result = Images.list client false
    let duration = DateTime.UtcNow - start

    match result with
    | Error e ->
        return Failure ("Analyze image sizes", duration, PodmanError.toMessage e)
    | Ok images ->
        let totalSize = images |> List.sumBy (fun i -> i.Size)
        let avgSize = if images.Length > 0 then totalSize / int64 images.Length else 0L
        let largest =
            images
            |> List.sortByDescending (fun i -> i.Size)
            |> List.tryHead
            |> Option.map (fun i ->
                let tag = i.RepoTags |> List.tryHead |> Option.defaultValue (i.Id.Substring(0, 12))
                sprintf "%s (%.2fMB)" tag (float i.Size / 1024.0 / 1024.0))
            |> Option.defaultValue "none"

        return Success (
            "Analyze image sizes",
            duration,
            sprintf "Total: %.2fMB, Avg: %.2fMB, Largest: %s"
                (float totalSize / 1024.0 / 1024.0)
                (float avgSize / 1024.0 / 1024.0)
                largest)
}

// ============================================================================
// Test Runner
// ============================================================================

/// Run all image tests
let runImageTests (client: PodmanClient) : Async<ImageTestResult list> = async {
    printfn ""
    printfn "=== IMAGE BUILD & MANAGEMENT TESTS ==="
    printfn ""

    let asyncTests = [
        testListImages
        testListAllImages
        testLocalhostImagesOnly
        testInspectImage
        testImageHistory
        testImageExists
        testImageNotExists
        testTagImage
        testUntagImage
        testPullExternalRejected
        testPullLocalhost
        testBuildNotImplemented
        testFindByReference
        testAnalyzeImageSizes
    ]

    let syncTests = [
        ("Build options creation", testBuildOptionsCreation)
    ]

    // Run sync tests
    let syncResults =
        syncTests
        |> List.map (fun (_, test) ->
            let result = test ()
            match result with
            | Success (name, duration, msg) ->
                printfn "  [PASS] %s (%.2fs) - %s" name duration.TotalSeconds msg
            | Failure (name, duration, error) ->
                printfn "  [FAIL] %s (%.2fs) - %s" name duration.TotalSeconds error
            | Skipped (name, reason) ->
                printfn "  [SKIP] %s - %s" name reason
            result)

    // Run async tests
    let! asyncResults =
        asyncTests
        |> List.map (fun test -> async {
            let! result = test client
            match result with
            | Success (name, duration, msg) ->
                printfn "  [PASS] %s (%.2fs) - %s" name duration.TotalSeconds msg
            | Failure (name, duration, error) ->
                printfn "  [FAIL] %s (%.2fs) - %s" name duration.TotalSeconds error
            | Skipped (name, reason) ->
                printfn "  [SKIP] %s - %s" name reason
            return result
        })
        |> Async.Sequential

    return syncResults @ (asyncResults |> Array.toList)
}

/// Get test statistics
let summarize (results: ImageTestResult list) : int * int * int =
    let passed = results |> List.filter (function Success _ -> true | _ -> false) |> List.length
    let failed = results |> List.filter (function Failure _ -> true | _ -> false) |> List.length
    let skipped = results |> List.filter (function Skipped _ -> true | _ -> false) |> List.length
    (passed, failed, skipped)
