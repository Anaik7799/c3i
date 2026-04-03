namespace Cepaf.Modules

open System
open System.IO

/// Centralized path resolution for CEPAF
/// STAMP Compliance: SC-CEP-001 (Locality), SC-CEP-002 (Decoupling)
///
/// All compose files, artifacts, and config paths MUST be resolved through this module
/// to ensure consistent absolute path handling across all phases.
module PathResolver =

    // ============================================================================
    // CORE PATH TYPES
    // ============================================================================

    /// Container type in the 3-container service chain
    type ServiceContainer =
        | Db
        | App
        | Obs

    /// Environment type for compose file mapping
    type DeploymentEnv =
        | Dev
        | Test
        | Demo
        | Prod

    /// Container artifact type
    type ArtifactType =
        | Logs
        | Data
        | Config
        | State
        | Temp

    /// Service chain path configuration
    type ServiceChainPaths = {
        DbCompose: string
        AppCompose: string
        ObsCompose: string
        DbContainer: string
        AppContainer: string
        ObsContainer: string
        DbPort: int
        AppPort: int
        ObsGrafanaPort: int
        ObsOtelPort: int
        ObsClickhousePort: int
    }

    /// Container configuration
    type ContainerConfig = {
        Name: string
        Image: string
        ComposeFile: string
        LogPath: string
        DataPath: string
        ConfigPath: string
        Ports: int list
        HealthCheckCmd: string option
    }

    /// Path resolution result with detailed info
    type PathResult<'T> = Result<'T, PathError>
    and PathError =
        | PathNotFound of path: string
        | OutOfScope of path: string * scope: string
        | InvalidPath of path: string * reason: string
        | ComposeNotFound of env: string * path: string
        | ContainerNotConfigured of container: string

    // ============================================================================
    // BASE PATH RESOLUTION
    // ============================================================================

    /// Get the base directory (current working directory)
    let getBaseDir () = Directory.GetCurrentDirectory()

    /// Resolve a relative path to absolute path
    /// If path is already absolute, returns as-is
    let resolve (relativePath: string) : string =
        if Path.IsPathRooted(relativePath) then
            relativePath
        else
            let baseDir = getBaseDir()
            Path.Combine(baseDir, relativePath)

    /// Get the CEPAF root directory
    let getCepafRoot () = resolve "lib/cepaf"

    /// Resolve a compose file path from the registry
    let resolveComposeFile (relativePath: string) : string =
        resolve relativePath

    /// Resolve an artifact path (logs, state, etc.)
    let resolveArtifact (relativePath: string) : string =
        resolve relativePath

    // ============================================================================
    // VALIDATION FUNCTIONS
    // ============================================================================

    /// Validate that a path exists
    let validateExists (path: string) : Result<string, string> =
        let absolutePath = resolve path
        if File.Exists(absolutePath) || Directory.Exists(absolutePath) then
            Ok absolutePath
        else
            Error (sprintf "Path does not exist: %s" absolutePath)

    /// Validate that a compose file exists
    let validateComposeFile (relativePath: string) : Result<string, string> =
        let absolutePath = resolveComposeFile relativePath
        if File.Exists(absolutePath) then
            Ok absolutePath
        else
            Error (sprintf "Compose file not found: %s (resolved from: %s)" absolutePath relativePath)

    /// Get all compose files from registry with absolute paths
    let resolveComposeFiles (composeFiles: Map<'TEnv, string>) : Map<'TEnv, string> =
        composeFiles
        |> Map.map (fun _ relativePath -> resolveComposeFile relativePath)

    /// Ensure a directory exists, creating it if necessary
    let ensureDirectory (path: string) : string =
        let absolutePath = resolve path
        if not (Directory.Exists(absolutePath)) then
            Directory.CreateDirectory(absolutePath) |> ignore
        absolutePath

    /// Validate that path is within CEPAF scope (SC-CEP-001)
    let validateCepafScope (path: string) : Result<string, string> =
        let absolutePath = resolve path
        let cepafRoot = resolve "lib/cepaf"
        if absolutePath.StartsWith(cepafRoot) then
            Ok absolutePath
        else
            Error (sprintf "Path outside CEPAF scope: %s (must be within %s)" absolutePath cepafRoot)

    /// Validate path with detailed error type
    let validatePathResult (path: string) : PathResult<string> =
        let absolutePath = resolve path
        if File.Exists(absolutePath) || Directory.Exists(absolutePath) then
            Ok absolutePath
        else
            Error (PathNotFound absolutePath)

    /// Validate STAMP scope constraint (SC-CEP-001)
    let validateStampScope (path: string) : PathResult<string> =
        let absolutePath = resolve path
        let cepafRoot = resolve "lib/cepaf"
        if absolutePath.StartsWith(cepafRoot) then
            Ok absolutePath
        else
            Error (OutOfScope(absolutePath, cepafRoot))

    // ============================================================================
    // DIRECTORY GETTERS
    // ============================================================================

    /// Get the CEPAF artifacts directory
    let getArtifactsDir () : string =
        resolve "lib/cepaf/artifacts"

    /// Get the CEPAF temp directory
    let getTempDir () : string =
        ensureDirectory "lib/cepaf/artifacts/tmp"

    /// Get the CEPAF logs directory
    let getLogsDir () : string =
        ensureDirectory "lib/cepaf/artifacts/logs"

    /// Get the CEPAF config directory
    let getConfigDir () : string =
        resolve "lib/cepaf/config"

    /// Get container-specific logs directory
    let getContainerLogsDir (containerName: string) : string =
        ensureDirectory (sprintf "lib/cepaf/artifacts/logs/%s" containerName)

    /// Get container-specific data directory
    let getContainerDataDir (containerName: string) : string =
        ensureDirectory (sprintf "lib/cepaf/artifacts/data/%s" containerName)

    /// Get container-specific config directory
    let getContainerConfigDir (containerName: string) : string =
        resolve (sprintf "lib/cepaf/config/%s" containerName)

    // ============================================================================
    // SERVICE CHAIN PATH RESOLUTION
    // ============================================================================

    /// Default container names for the 3-container chain
    let private defaultContainerNames = Map.ofList [
        (Db, "indrajaal-db")
        (App, "indrajaal-app")
        (Obs, "indrajaal-obs")
    ]

    /// Default ports for the 3-container chain
    let private defaultPorts = Map.ofList [
        ("db", 5433)
        ("app", 4000)
        ("obs-grafana", 3000)
        ("obs-otel", 4317)
        ("obs-clickhouse", 8123)
    ]

    /// Get service chain paths for the 3-container topology
    let getServiceChainPaths () : ServiceChainPaths =
        let artifactsDir = getArtifactsDir()
        {
            DbCompose = Path.Combine(artifactsDir, "podman-compose-db-standalone.yml")
            AppCompose = Path.Combine(artifactsDir, "podman-compose-app.yml")
            ObsCompose = Path.Combine(artifactsDir, "podman-compose-obs-standalone.yml")
            DbContainer = defaultContainerNames.[Db]
            AppContainer = defaultContainerNames.[App]
            ObsContainer = defaultContainerNames.[Obs]
            DbPort = defaultPorts.["db"]
            AppPort = defaultPorts.["app"]
            ObsGrafanaPort = defaultPorts.["obs-grafana"]
            ObsOtelPort = defaultPorts.["obs-otel"]
            ObsClickhousePort = defaultPorts.["obs-clickhouse"]
        }

    /// Get compose file path for a specific container in the chain
    let getServiceComposeFile (container: ServiceContainer) : string =
        let paths = getServiceChainPaths()
        match container with
        | Db -> paths.DbCompose
        | App -> paths.AppCompose
        | Obs -> paths.ObsCompose

    /// Validate service chain compose files exist
    let validateServiceChainFiles () : Result<ServiceChainPaths, string list> =
        let paths = getServiceChainPaths()
        let errors =
            [ (paths.DbCompose, "db")
              (paths.AppCompose, "app")
              (paths.ObsCompose, "obs") ]
            |> List.choose (fun (path, name) ->
                if not (File.Exists(path)) then
                    Some (sprintf "Missing %s compose file: %s" name path)
                else None)
        if errors.IsEmpty then Ok paths
        else Error errors

    // ============================================================================
    // COMPOSE FILE MAPPING BY ENVIRONMENT
    // ============================================================================

    /// Default compose file paths by environment
    let private defaultComposeFiles = Map.ofList [
        (Dev, "podman-compose-3container.yml")
        (Test, "podman-compose-testing.yml")
        (Demo, "podman-compose.yml")
        (Prod, "podman-compose-secure.yml")
    ]

    /// Get compose file path for a deployment environment
    let getComposeFileForEnv (env: DeploymentEnv) : string =
        let relativePath = defaultComposeFiles.[env]
        resolve relativePath

    /// Get all compose file paths by environment
    let getAllComposeFiles () : Map<DeploymentEnv, string> =
        defaultComposeFiles
        |> Map.map (fun _ relativePath -> resolve relativePath)

    /// Validate compose file exists for environment
    let validateComposeForEnv (env: DeploymentEnv) : PathResult<string> =
        let path = getComposeFileForEnv env
        if File.Exists(path) then
            Ok path
        else
            Error (ComposeNotFound(sprintf "%A" env, path))

    /// Validate all environment compose files
    let validateAllComposeFiles () : Result<Map<DeploymentEnv, string>, (DeploymentEnv * string) list> =
        let results =
            [Dev; Test; Demo; Prod]
            |> List.map (fun env ->
                let path = getComposeFileForEnv env
                if File.Exists(path) then Ok (env, path)
                else Error (env, path))
        let errors = results |> List.choose (function Error e -> Some e | _ -> None)
        if errors.IsEmpty then
            Ok (results |> List.choose (function Ok p -> Some p | _ -> None) |> Map.ofList)
        else
            Error errors

    // ============================================================================
    // CONTAINER ARTIFACT PATHS
    // ============================================================================

    /// Get artifact path for a specific container and artifact type
    let getContainerArtifactPath (containerName: string) (artifactType: ArtifactType) : string =
        match artifactType with
        | Logs -> getContainerLogsDir containerName
        | Data -> getContainerDataDir containerName
        | Config -> getContainerConfigDir containerName
        | State -> ensureDirectory (sprintf "lib/cepaf/artifacts/state/%s" containerName)
        | Temp -> ensureDirectory (sprintf "lib/cepaf/artifacts/tmp/%s" containerName)

    /// Resolve container-specific log file
    let resolveContainerLogFile (containerName: string) (logFileName: string) : string =
        let logsDir = getContainerLogsDir containerName
        Path.Combine(logsDir, logFileName)

    /// Resolve container-specific config file
    let resolveContainerConfigFile (containerName: string) (configFileName: string) : string =
        let configDir = getContainerConfigDir containerName
        Path.Combine(configDir, configFileName)

    // ============================================================================
    // CONTAINER CONFIGURATION RESOLUTION
    // ============================================================================

    /// Default container configurations
    let private containerConfigs = Map.ofList [
        ("db", {
            Name = "indrajaal-db"
            Image = "localhost/indrajaal-timescaledb-demo:nixos-devenv"
            ComposeFile = "lib/cepaf/artifacts/podman-compose-db-standalone.yml"
            LogPath = "lib/cepaf/artifacts/logs/db"
            DataPath = "lib/cepaf/artifacts/data/db"
            ConfigPath = "lib/cepaf/config/db"
            Ports = [5433]
            HealthCheckCmd = Some "pg_isready -U postgres -d indrajaal_test -p 5433"
        })
        ("app", {
            Name = "indrajaal-app"
            Image = "localhost/indrajaal-app:dev"
            ComposeFile = "lib/cepaf/artifacts/podman-compose-app.yml"
            LogPath = "lib/cepaf/artifacts/logs/app"
            DataPath = "lib/cepaf/artifacts/data/app"
            ConfigPath = "lib/cepaf/config/app"
            Ports = [4000]
            HealthCheckCmd = Some "curl -sf http://localhost:4000/health || exit 1"
        })
        ("obs", {
            Name = "indrajaal-obs"
            Image = "localhost/indrajaal-obs-unified:dev"
            ComposeFile = "lib/cepaf/artifacts/podman-compose-obs-standalone.yml"
            LogPath = "lib/cepaf/artifacts/logs/obs"
            DataPath = "lib/cepaf/artifacts/data/obs"
            ConfigPath = "lib/cepaf/config/obs"
            Ports = [3000; 4317; 8123]
            HealthCheckCmd = Some "curl -sf http://localhost:3000/api/health || exit 1"
        })
    ]

    /// Resolve container configuration by name
    let resolveContainerConfig (containerName: string) : PathResult<ContainerConfig> =
        match containerConfigs.TryFind(containerName) with
        | Some config ->
            Ok {
                config with
                    ComposeFile = resolve config.ComposeFile
                    LogPath = resolve config.LogPath
                    DataPath = resolve config.DataPath
                    ConfigPath = resolve config.ConfigPath
            }
        | None ->
            Error (ContainerNotConfigured containerName)

    /// Get all configured containers
    let getAllContainerConfigs () : Map<string, ContainerConfig> =
        containerConfigs
        |> Map.map (fun _ config ->
            { config with
                ComposeFile = resolve config.ComposeFile
                LogPath = resolve config.LogPath
                DataPath = resolve config.DataPath
                ConfigPath = resolve config.ConfigPath
            })

    /// Validate container configuration exists and paths are accessible
    let validateContainerConfig (containerName: string) : PathResult<ContainerConfig> =
        match resolveContainerConfig containerName with
        | Ok config ->
            // Validate compose file exists
            if not (File.Exists(config.ComposeFile)) then
                Error (PathNotFound config.ComposeFile)
            else
                Ok config
        | Error e -> Error e

    // ============================================================================
    // PATH INFO AND DEBUGGING
    // ============================================================================

    /// Path info for logging/debugging
    type PathInfo = {
        Original: string
        Resolved: string
        Exists: bool
        IsAbsolute: bool
        InCepafScope: bool
    }

    /// Get detailed path info
    let getPathInfo (path: string) : PathInfo =
        let resolved = resolve path
        let cepafRoot = resolve "lib/cepaf"
        {
            Original = path
            Resolved = resolved
            Exists = File.Exists(resolved) || Directory.Exists(resolved)
            IsAbsolute = Path.IsPathRooted(path)
            InCepafScope = resolved.StartsWith(cepafRoot)
        }

    /// Get path info with STAMP validation
    let getPathInfoWithStamp (path: string) : PathInfo * PathResult<string> =
        let info = getPathInfo path
        let stampResult = validateStampScope path
        (info, stampResult)

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /// Normalize path separators for cross-platform compatibility
    let normalizePath (path: string) : string =
        path.Replace('\\', Path.DirectorySeparatorChar).Replace('/', Path.DirectorySeparatorChar)

    /// Join path segments safely
    let joinPaths (segments: string list) : string =
        match segments with
        | [] -> ""
        | [single] -> resolve single
        | head :: tail ->
            tail |> List.fold (fun acc segment -> Path.Combine(acc, segment)) (resolve head)

    /// Get relative path from base
    let getRelativePath (basePath: string) (fullPath: string) : string option =
        let baseAbs = resolve basePath
        let fullAbs = resolve fullPath
        if fullAbs.StartsWith(baseAbs) then
            Some (fullAbs.Substring(baseAbs.Length).TrimStart(Path.DirectorySeparatorChar))
        else
            None

    /// Check if path is within directory
    let isWithinDirectory (directory: string) (path: string) : bool =
        let dirAbs = resolve directory
        let pathAbs = resolve path
        pathAbs.StartsWith(dirAbs)

    /// Get parent directory
    let getParentDir (path: string) : string option =
        let resolved = resolve path
        let parent = Path.GetDirectoryName(resolved)
        if String.IsNullOrEmpty(parent) then None else Some parent

    /// List files in directory with pattern
    let listFiles (directory: string) (pattern: string) : string list =
        let absDir = resolve directory
        if Directory.Exists(absDir) then
            Directory.GetFiles(absDir, pattern) |> Array.toList
        else
            []

    /// List subdirectories
    let listDirectories (directory: string) : string list =
        let absDir = resolve directory
        if Directory.Exists(absDir) then
            Directory.GetDirectories(absDir) |> Array.toList
        else
            []
