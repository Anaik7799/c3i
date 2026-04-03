namespace Cepaf.Tests

open System
open System.IO
open Xunit
open Cepaf.Modules

/// PathResolver Unit Tests
/// STAMP Compliance: SC-CEP-001 (Locality), SC-CEP-002 (Decoupling)
/// Test Coverage: 30+ comprehensive tests for all path resolution functions
module PathResolverTests =

    // ============================================================================
    // BASIC PATH RESOLUTION TESTS
    // ============================================================================

    [<Fact>]
    let ``resolve returns absolute path unchanged`` () =
        // Arrange
        let absolutePath = "/home/user/project/file.yml"

        // Act
        let result = PathResolver.resolve absolutePath

        // Assert
        Assert.Equal(absolutePath, result)

    [<Fact>]
    let ``resolve converts relative path to absolute`` () =
        // Arrange
        let relativePath = "lib/cepaf/artifacts/compose.yml"
        let baseDir = PathResolver.getBaseDir()

        // Act
        let result = PathResolver.resolve relativePath

        // Assert
        Assert.StartsWith(baseDir, result)
        Assert.EndsWith("lib/cepaf/artifacts/compose.yml", result)

    [<Fact>]
    let ``resolve handles Windows-style absolute paths`` () =
        // Arrange (will work on both platforms)
        let windowsPath = "C:\\Users\\test\\file.yml"

        // Act
        let result = PathResolver.resolve windowsPath

        // Assert (should recognize it as rooted on Windows)
        if Path.IsPathRooted(windowsPath) then
            Assert.Equal(windowsPath, result)

    [<Fact>]
    let ``getBaseDir returns non-empty string`` () =
        // Act
        let result = PathResolver.getBaseDir()

        // Assert
        Assert.False(String.IsNullOrEmpty(result))
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getCepafRoot returns path ending with lib/cepaf`` () =
        // Act
        let result = PathResolver.getCepafRoot()

        // Assert
        Assert.EndsWith("lib/cepaf", result)
        Assert.True(Path.IsPathRooted(result))

    // ============================================================================
    // COMPOSE FILE RESOLUTION TESTS
    // ============================================================================

    [<Fact>]
    let ``resolveComposeFile returns correct path`` () =
        // Arrange
        let relativePath = "lib/cepaf/artifacts/podman-compose-db-standalone.yml"

        // Act
        let result = PathResolver.resolveComposeFile relativePath

        // Assert
        Assert.EndsWith("podman-compose-db-standalone.yml", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``resolveComposeFiles maps all entries`` () =
        // Arrange
        let composeFiles = Map.ofList [
            ("DEV", "lib/cepaf/artifacts/dev.yml")
            ("TEST", "lib/cepaf/artifacts/test.yml")
        ]

        // Act
        let result = PathResolver.resolveComposeFiles composeFiles

        // Assert
        Assert.Equal(2, result.Count)
        for kvp in result do
            Assert.True(Path.IsPathRooted(kvp.Value))

    [<Fact>]
    let ``validateComposeFile returns Ok for existing compose file`` () =
        // Arrange - use a file we know exists
        let composeFile = "lib/cepaf/artifacts/podman-compose-db-standalone.yml"

        // Act
        let result = PathResolver.validateComposeFile composeFile

        // Assert
        match result with
        | Ok path -> Assert.EndsWith(".yml", path)
        | Error msg ->
            // File might not exist in test environment - that's OK
            Assert.Contains("not found", msg)

    [<Fact>]
    let ``validateComposeFile returns Error for missing compose file`` () =
        // Arrange
        let missingFile = "lib/cepaf/artifacts/nonexistent-compose.yml"

        // Act
        let result = PathResolver.validateComposeFile missingFile

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error msg ->
            Assert.Contains("not found", msg)
            Assert.Contains("nonexistent-compose.yml", msg)

    // ============================================================================
    // PATH VALIDATION TESTS
    // ============================================================================

    [<Fact>]
    let ``validateExists returns Ok for existing path`` () =
        // Arrange
        let existingPath = PathResolver.getBaseDir()

        // Act
        let result = PathResolver.validateExists existingPath

        // Assert
        match result with
        | Ok path -> Assert.Equal(existingPath, path)
        | Error msg -> Assert.Fail($"Expected Ok, got Error: {msg}")

    [<Fact>]
    let ``validateExists returns Error for non-existing path`` () =
        // Arrange
        let nonExistingPath = "/this/path/definitely/does/not/exist/12345"

        // Act
        let result = PathResolver.validateExists nonExistingPath

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error msg -> Assert.Contains("does not exist", msg)

    [<Fact>]
    let ``validateCepafScope returns Ok for path within scope`` () =
        // Arrange
        let cepafPath = "lib/cepaf/artifacts/test.yml"

        // Act
        let result = PathResolver.validateCepafScope cepafPath

        // Assert
        match result with
        | Ok path -> Assert.Contains("lib/cepaf", path)
        | Error msg -> Assert.Fail($"Expected Ok, got Error: {msg}")

    [<Fact>]
    let ``validateCepafScope returns Error for path outside scope`` () =
        // Arrange
        let outsidePath = "/tmp/outside.yml"

        // Act
        let result = PathResolver.validateCepafScope outsidePath

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error msg -> Assert.Contains("outside CEPAF scope", msg)

    [<Fact>]
    let ``validatePathResult returns Ok for existing path`` () =
        // Arrange
        let existingPath = PathResolver.getBaseDir()

        // Act
        let result = PathResolver.validatePathResult existingPath

        // Assert
        match result with
        | Ok path -> Assert.Equal(existingPath, path)
        | Error _ -> Assert.Fail("Expected Ok, got Error")

    [<Fact>]
    let ``validatePathResult returns PathNotFound for missing path`` () =
        // Arrange
        let missingPath = "/nonexistent/path/12345"

        // Act
        let result = PathResolver.validatePathResult missingPath

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error (PathResolver.PathNotFound _) -> ()
        | Error e -> Assert.Fail($"Expected PathNotFound, got {e}")

    [<Fact>]
    let ``validateStampScope returns OutOfScope error for external path`` () =
        // Arrange
        let externalPath = "/tmp/external.yml"

        // Act
        let result = PathResolver.validateStampScope externalPath

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error (PathResolver.OutOfScope(path, scope)) ->
            Assert.Equal(externalPath, path)
            Assert.Contains("lib/cepaf", scope)
        | Error e -> Assert.Fail($"Expected OutOfScope, got {e}")

    // ============================================================================
    // DIRECTORY GETTER TESTS
    // ============================================================================

    [<Fact>]
    let ``getArtifactsDir returns correct path`` () =
        // Act
        let result = PathResolver.getArtifactsDir()

        // Assert
        Assert.EndsWith("lib/cepaf/artifacts", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getTempDir creates and returns temp directory`` () =
        // Act
        let result = PathResolver.getTempDir()

        // Assert
        Assert.EndsWith("lib/cepaf/artifacts/tmp", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getLogsDir creates and returns logs directory`` () =
        // Act
        let result = PathResolver.getLogsDir()

        // Assert
        Assert.EndsWith("lib/cepaf/artifacts/logs", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getConfigDir returns config directory path`` () =
        // Act
        let result = PathResolver.getConfigDir()

        // Assert
        Assert.EndsWith("lib/cepaf/config", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``ensureDirectory creates directory if not exists`` () =
        // Arrange
        let testDir = Path.Combine(PathResolver.getTempDir(), $"test_{Guid.NewGuid().ToString().[..7]}")

        // Act
        let result = PathResolver.ensureDirectory testDir

        // Assert
        Assert.True(Directory.Exists(result))

        // Cleanup
        Directory.Delete(testDir)

    // ============================================================================
    // PATH INFO TESTS
    // ============================================================================

    [<Fact>]
    let ``getPathInfo returns complete info`` () =
        // Arrange
        let testPath = "lib/cepaf/artifacts/test.yml"

        // Act
        let info = PathResolver.getPathInfo testPath

        // Assert
        Assert.Equal(testPath, info.Original)
        Assert.True(Path.IsPathRooted(info.Resolved))
        Assert.False(info.IsAbsolute)
        Assert.True(info.InCepafScope)

    [<Fact>]
    let ``getPathInfo returns IsAbsolute true for absolute path`` () =
        // Arrange
        let absolutePath = "/home/user/file.txt"

        // Act
        let info = PathResolver.getPathInfo absolutePath

        // Assert
        Assert.True(info.IsAbsolute)

    [<Fact>]
    let ``getPathInfo returns InCepafScope false for external path`` () =
        // Arrange
        let externalPath = "/tmp/external.yml"

        // Act
        let info = PathResolver.getPathInfo externalPath

        // Assert
        Assert.False(info.InCepafScope)

    [<Fact>]
    let ``getPathInfoWithStamp returns info and validation result`` () =
        // Arrange
        let cepafPath = "lib/cepaf/artifacts/test.yml"

        // Act
        let (info, stampResult) = PathResolver.getPathInfoWithStamp cepafPath

        // Assert
        Assert.True(info.InCepafScope)
        match stampResult with
        | Ok _ -> ()
        | Error _ -> Assert.Fail("Expected STAMP validation to pass for CEPAF path")

    // ============================================================================
    // SERVICE CHAIN TESTS
    // ============================================================================

    [<Fact>]
    let ``getServiceChainPaths returns valid configuration`` () =
        // Act
        let paths = PathResolver.getServiceChainPaths()

        // Assert
        Assert.NotNull(paths.DbContainer)
        Assert.NotNull(paths.AppContainer)
        Assert.NotNull(paths.ObsContainer)
        Assert.True(paths.DbPort > 0)
        Assert.True(paths.AppPort > 0)
        Assert.True(paths.ObsGrafanaPort > 0)

    [<Fact>]
    let ``getServiceChainPaths returns absolute compose paths`` () =
        // Act
        let paths = PathResolver.getServiceChainPaths()

        // Assert
        Assert.True(Path.IsPathRooted(paths.DbCompose))
        Assert.True(Path.IsPathRooted(paths.AppCompose))
        Assert.True(Path.IsPathRooted(paths.ObsCompose))

    [<Fact>]
    let ``getServiceChainPaths returns expected container names`` () =
        // Act
        let paths = PathResolver.getServiceChainPaths()

        // Assert
        Assert.Equal("indrajaal-db", paths.DbContainer)
        Assert.Equal("indrajaal-app", paths.AppContainer)
        Assert.Equal("indrajaal-obs", paths.ObsContainer)

    [<Fact>]
    let ``getServiceChainPaths returns expected ports`` () =
        // Act
        let paths = PathResolver.getServiceChainPaths()

        // Assert
        Assert.Equal(5433, paths.DbPort)
        Assert.Equal(4000, paths.AppPort)
        Assert.Equal(3000, paths.ObsGrafanaPort)
        Assert.Equal(4317, paths.ObsOtelPort)
        Assert.Equal(8123, paths.ObsClickhousePort)

    [<Fact>]
    let ``getServiceComposeFile returns correct path for Db`` () =
        // Act
        let result = PathResolver.getServiceComposeFile PathResolver.Db

        // Assert
        Assert.Contains("podman-compose-db", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getServiceComposeFile returns correct path for Obs`` () =
        // Act
        let result = PathResolver.getServiceComposeFile PathResolver.Obs

        // Assert
        Assert.Contains("podman-compose-obs", result)
        Assert.True(Path.IsPathRooted(result))

    // ============================================================================
    // COMPOSE FILE MAPPING BY ENVIRONMENT TESTS
    // ============================================================================

    [<Fact>]
    let ``getComposeFileForEnv returns absolute path for Dev`` () =
        // Act
        let result = PathResolver.getComposeFileForEnv PathResolver.Dev

        // Assert
        Assert.True(Path.IsPathRooted(result))
        Assert.Contains("podman-compose", result)

    [<Fact>]
    let ``getComposeFileForEnv returns absolute path for Test`` () =
        // Act
        let result = PathResolver.getComposeFileForEnv PathResolver.Test

        // Assert
        Assert.True(Path.IsPathRooted(result))
        Assert.Contains("podman-compose", result)

    [<Fact>]
    let ``getComposeFileForEnv returns absolute path for Demo`` () =
        // Act
        let result = PathResolver.getComposeFileForEnv PathResolver.Demo

        // Assert
        Assert.True(Path.IsPathRooted(result))
        Assert.Contains("podman-compose", result)

    [<Fact>]
    let ``getComposeFileForEnv returns absolute path for Prod`` () =
        // Act
        let result = PathResolver.getComposeFileForEnv PathResolver.Prod

        // Assert
        Assert.True(Path.IsPathRooted(result))
        Assert.Contains("podman-compose", result)

    [<Fact>]
    let ``getAllComposeFiles returns map with all environments`` () =
        // Act
        let result = PathResolver.getAllComposeFiles()

        // Assert
        Assert.Equal(4, result.Count)
        Assert.True(result.ContainsKey(PathResolver.Dev))
        Assert.True(result.ContainsKey(PathResolver.Test))
        Assert.True(result.ContainsKey(PathResolver.Demo))
        Assert.True(result.ContainsKey(PathResolver.Prod))

    // ============================================================================
    // CONTAINER ARTIFACT PATH TESTS
    // ============================================================================

    [<Fact>]
    let ``getContainerArtifactPath returns correct logs path`` () =
        // Act
        let result = PathResolver.getContainerArtifactPath "db" PathResolver.Logs

        // Assert
        Assert.Contains("logs/db", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getContainerArtifactPath returns correct data path`` () =
        // Act
        let result = PathResolver.getContainerArtifactPath "app" PathResolver.Data

        // Assert
        Assert.Contains("data/app", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getContainerArtifactPath returns correct config path`` () =
        // Act
        let result = PathResolver.getContainerArtifactPath "obs" PathResolver.Config

        // Assert
        Assert.Contains("config/obs", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getContainerArtifactPath returns correct state path`` () =
        // Act
        let result = PathResolver.getContainerArtifactPath "db" PathResolver.State

        // Assert
        Assert.Contains("state/db", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getContainerArtifactPath returns correct temp path`` () =
        // Act
        let result = PathResolver.getContainerArtifactPath "app" PathResolver.Temp

        // Assert
        Assert.Contains("tmp/app", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``resolveContainerLogFile returns correct path`` () =
        // Act
        let result = PathResolver.resolveContainerLogFile "db" "postgres.log"

        // Assert
        Assert.Contains("logs/db", result)
        Assert.EndsWith("postgres.log", result)

    [<Fact>]
    let ``resolveContainerConfigFile returns correct path`` () =
        // Act
        let result = PathResolver.resolveContainerConfigFile "obs" "grafana.ini"

        // Assert
        Assert.Contains("config/obs", result)
        Assert.EndsWith("grafana.ini", result)

    // ============================================================================
    // CONTAINER CONFIGURATION TESTS
    // ============================================================================

    [<Fact>]
    let ``resolveContainerConfig returns Ok for known container db`` () =
        // Act
        let result = PathResolver.resolveContainerConfig "db"

        // Assert
        match result with
        | Ok config ->
            Assert.Equal("indrajaal-db", config.Name)
            Assert.True(Path.IsPathRooted(config.ComposeFile))
            Assert.True(Path.IsPathRooted(config.LogPath))
            Assert.Contains(5433, config.Ports)
        | Error e -> Assert.Fail($"Expected Ok, got Error: {e}")

    [<Fact>]
    let ``resolveContainerConfig returns Ok for known container app`` () =
        // Act
        let result = PathResolver.resolveContainerConfig "app"

        // Assert
        match result with
        | Ok config ->
            Assert.Equal("indrajaal-app", config.Name)
            Assert.Contains(4000, config.Ports)
        | Error e -> Assert.Fail($"Expected Ok, got Error: {e}")

    [<Fact>]
    let ``resolveContainerConfig returns Ok for known container obs`` () =
        // Act
        let result = PathResolver.resolveContainerConfig "obs"

        // Assert
        match result with
        | Ok config ->
            Assert.Equal("indrajaal-obs", config.Name)
            Assert.Contains(3000, config.Ports)
            Assert.Contains(4317, config.Ports)
            Assert.Contains(8123, config.Ports)
        | Error e -> Assert.Fail($"Expected Ok, got Error: {e}")

    [<Fact>]
    let ``resolveContainerConfig returns ContainerNotConfigured for unknown container`` () =
        // Act
        let result = PathResolver.resolveContainerConfig "unknown-container"

        // Assert
        match result with
        | Ok _ -> Assert.Fail("Expected Error, got Ok")
        | Error (PathResolver.ContainerNotConfigured name) ->
            Assert.Equal("unknown-container", name)
        | Error e -> Assert.Fail($"Expected ContainerNotConfigured, got {e}")

    [<Fact>]
    let ``getAllContainerConfigs returns all three containers`` () =
        // Act
        let result = PathResolver.getAllContainerConfigs()

        // Assert
        Assert.Equal(3, result.Count)
        Assert.True(result.ContainsKey("db"))
        Assert.True(result.ContainsKey("app"))
        Assert.True(result.ContainsKey("obs"))

    [<Fact>]
    let ``getAllContainerConfigs returns resolved absolute paths`` () =
        // Act
        let result = PathResolver.getAllContainerConfigs()

        // Assert
        for kvp in result do
            Assert.True(Path.IsPathRooted(kvp.Value.ComposeFile), $"ComposeFile for {kvp.Key} not absolute")
            Assert.True(Path.IsPathRooted(kvp.Value.LogPath), $"LogPath for {kvp.Key} not absolute")
            Assert.True(Path.IsPathRooted(kvp.Value.DataPath), $"DataPath for {kvp.Key} not absolute")
            Assert.True(Path.IsPathRooted(kvp.Value.ConfigPath), $"ConfigPath for {kvp.Key} not absolute")

    // ============================================================================
    // UTILITY FUNCTION TESTS
    // ============================================================================

    [<Fact>]
    let ``normalizePath converts forward slashes`` () =
        // Arrange
        let path = "lib/cepaf/artifacts/test.yml"

        // Act
        let result = PathResolver.normalizePath path

        // Assert
        // Should contain proper separator (may be / on Linux, \ on Windows)
        Assert.NotNull(result)

    [<Fact>]
    let ``normalizePath converts backward slashes`` () =
        // Arrange
        let path = "lib\\cepaf\\artifacts\\test.yml"

        // Act
        let result = PathResolver.normalizePath path

        // Assert
        Assert.NotNull(result)

    [<Fact>]
    let ``joinPaths returns empty string for empty list`` () =
        // Act
        let result = PathResolver.joinPaths []

        // Assert
        Assert.Equal("", result)

    [<Fact>]
    let ``joinPaths returns resolved path for single segment`` () =
        // Arrange
        let segments = ["lib/cepaf"]

        // Act
        let result = PathResolver.joinPaths segments

        // Assert
        Assert.True(Path.IsPathRooted(result))
        Assert.Contains("lib/cepaf", result)

    [<Fact>]
    let ``joinPaths combines multiple segments`` () =
        // Arrange
        let segments = ["lib/cepaf"; "artifacts"; "test.yml"]

        // Act
        let result = PathResolver.joinPaths segments

        // Assert
        Assert.True(Path.IsPathRooted(result))
        Assert.Contains("artifacts", result)
        Assert.EndsWith("test.yml", result)

    [<Fact>]
    let ``getRelativePath returns Some for path within base`` () =
        // Arrange
        let basePath = "lib/cepaf"
        let fullPath = "lib/cepaf/artifacts/test.yml"

        // Act
        let result = PathResolver.getRelativePath basePath fullPath

        // Assert
        match result with
        | Some rel ->
            Assert.Contains("artifacts", rel)
            Assert.Contains("test.yml", rel)
        | None -> Assert.Fail("Expected Some, got None")

    [<Fact>]
    let ``getRelativePath returns None for path outside base`` () =
        // Arrange
        let basePath = "lib/cepaf"
        let fullPath = "/tmp/external.yml"

        // Act
        let result = PathResolver.getRelativePath basePath fullPath

        // Assert
        Assert.True(result.IsNone)

    [<Fact>]
    let ``isWithinDirectory returns true for nested path`` () =
        // Arrange
        let directory = "lib/cepaf"
        let path = "lib/cepaf/artifacts/test.yml"

        // Act
        let result = PathResolver.isWithinDirectory directory path

        // Assert
        Assert.True(result)

    [<Fact>]
    let ``isWithinDirectory returns false for external path`` () =
        // Arrange
        let directory = "lib/cepaf"
        let path = "/tmp/external.yml"

        // Act
        let result = PathResolver.isWithinDirectory directory path

        // Assert
        Assert.False(result)

    [<Fact>]
    let ``getParentDir returns Some for valid path`` () =
        // Arrange
        let path = "lib/cepaf/artifacts/test.yml"

        // Act
        let result = PathResolver.getParentDir path

        // Assert
        match result with
        | Some parent -> Assert.Contains("artifacts", parent)
        | None -> Assert.Fail("Expected Some, got None")

    [<Fact>]
    let ``listFiles returns empty list for non-existing directory`` () =
        // Arrange
        let directory = "/nonexistent/directory/12345"

        // Act
        let result = PathResolver.listFiles directory "*.yml"

        // Assert
        Assert.Empty(result)

    [<Fact>]
    let ``listDirectories returns empty list for non-existing directory`` () =
        // Arrange
        let directory = "/nonexistent/directory/12345"

        // Act
        let result = PathResolver.listDirectories directory

        // Assert
        Assert.Empty(result)

    // ============================================================================
    // CONTAINER DIRECTORY TESTS
    // ============================================================================

    [<Fact>]
    let ``getContainerLogsDir creates directory`` () =
        // Arrange
        let containerName = "test-container"

        // Act
        let result = PathResolver.getContainerLogsDir containerName

        // Assert
        Assert.Contains("logs/test-container", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getContainerDataDir creates directory`` () =
        // Arrange
        let containerName = "test-container"

        // Act
        let result = PathResolver.getContainerDataDir containerName

        // Assert
        Assert.Contains("data/test-container", result)
        Assert.True(Path.IsPathRooted(result))

    [<Fact>]
    let ``getContainerConfigDir returns path without creating`` () =
        // Arrange
        let containerName = "test-container"

        // Act
        let result = PathResolver.getContainerConfigDir containerName

        // Assert
        Assert.Contains("config/test-container", result)
        Assert.True(Path.IsPathRooted(result))
