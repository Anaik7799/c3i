# Cepaf.Podman API Documentation

**Version**: 1.0.0
**Target Framework**: .NET 8.0
**F# Version**: 8.0+

This document provides comprehensive API documentation for the Cepaf.Podman F# library, a type-safe, functional wrapper around the Podman REST API.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Domain Types](#2-domain-types)
3. [Client Module](#3-client-module)
4. [API Modules](#4-api-modules)
5. [Events Module](#5-events-module)
6. [Compose Module](#6-compose-module)
7. [Health Module](#7-health-module)
8. [Safety Module](#8-safety-module)
9. [Error Handling](#9-error-handling)
10. [Async Workflow Patterns](#10-async-workflow-patterns)

---

## 1. Overview

The Cepaf.Podman library provides a functional, type-safe interface to the Podman container runtime via its REST API over Unix domain sockets. Key features include:

- **Type-safe domain modeling** with discriminated unions
- **Async workflows** using F# async computation expressions
- **Result-based error handling** with comprehensive error types
- **STAMP safety constraints** for enterprise compliance
- **Fluent builder patterns** for configuration specs

### Namespace Structure

```
Cepaf.Podman
    Domain      - Core types, errors, specs, events
    Client      - HTTP client, Unix socket, serialization
    Api         - Containers, Images, Pods, Volumes, Networks, System
    Events      - Event streaming
    Compose     - YAML parsing for compose files
    Health      - Health probes and monitoring
    Safety      - STAMP constraint validation
```

### Quick Start Example

```fsharp
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

// Create client
let client =
    match HttpClient.createDefault() with
    | Ok c -> c
    | Error e -> failwith (PodmanError.toMessage e)

// List running containers
async {
    let! result = Containers.listRunning client
    match result with
    | Ok containers ->
        for c in containers do
            printfn "Container: %s (%s)" c.Names.[0] c.Status
    | Error e ->
        printfn "Error: %s" (PodmanError.toMessage e)
} |> Async.RunSynchronously
```

---

## 2. Domain Types

### 2.1 Cepaf.Podman.Domain.Types

#### Container Status

```fsharp
[<RequireQualifiedAccess>]
type ContainerStatus =
    | Created
    | Running
    | Paused
    | Restarting
    | Removing
    | Exited of exitCode: int
    | Dead of reason: string
    | Unknown of status: string

module ContainerStatus =
    val parse: string -> ContainerStatus
```

#### Health Status

```fsharp
[<RequireQualifiedAccess>]
type HealthStatus =
    | Starting
    | Healthy
    | Unhealthy of failingStreak: int
    | NoHealthcheck
    | Unknown of status: string

module HealthStatus =
    val parse: string -> HealthStatus
```

#### Port Mapping

```fsharp
type PortMapping = {
    ContainerPort: uint16
    HostPort: uint16 option
    HostIP: string option
    Protocol: PortProtocol
    Range: uint16 option
}

module PortMapping =
    val create: uint16 -> PortMapping
    val withHostPort: uint16 -> PortMapping -> PortMapping
    val withHostIP: string -> PortMapping -> PortMapping
    val withProtocol: PortProtocol -> PortMapping -> PortMapping
```

**Example:**
```fsharp
let port =
    PortMapping.create 80us
    |> PortMapping.withHostPort 8080us
    |> PortMapping.withProtocol PortProtocol.TCP
```

#### Mount Configuration

```fsharp
type Mount = {
    Type: MountType
    Source: string
    Target: string
    ReadOnly: bool
    Options: string list
}

module Mount =
    val createBind: source: string -> target: string -> Mount
    val createVolume: name: string -> target: string -> Mount
    val withReadOnly: Mount -> Mount
    val withOptions: string list -> Mount -> Mount
```

#### Container Summary (List Response)

```fsharp
type ContainerSummary = {
    Id: string
    Names: string list
    Image: string
    ImageID: string
    Command: string
    Created: DateTimeOffset
    State: ContainerStatus
    Status: string
    Ports: PortMapping list
    Labels: Map<string, string>
    Mounts: Mount list
    Networks: string list
}
```

#### Container Inspect (Full Details)

```fsharp
type ContainerInspect = {
    Id: string
    Created: DateTimeOffset
    Path: string
    Args: string list
    State: ContainerStateDetail
    Image: string
    ImageName: string
    Name: string
    RestartCount: int
    Platform: string
    MountLabel: string
    ProcessLabel: string
    Mounts: Mount list
    Labels: Map<string, string>
    Env: Map<string, string>
}
```

#### Pod Types

```fsharp
[<RequireQualifiedAccess>]
type PodStatus =
    | Created | Running | Paused | Stopped | Exited | Dead
    | Unknown of status: string

type PodSummary = {
    Id: string
    Name: string
    Status: PodStatus
    Created: DateTimeOffset
    Labels: Map<string, string>
    Containers: PodContainerInfo list
    InfraId: string option
}
```

#### Image Types

```fsharp
type ImageSummary = {
    Id: string
    RepoTags: string list
    RepoDigests: string list
    Created: DateTimeOffset
    Size: int64
    VirtualSize: int64
    Labels: Map<string, string>
    Containers: int
}
```

#### Volume and Network Types

```fsharp
type Volume = {
    Name: string
    Driver: VolumeDriver
    Mountpoint: string
    CreatedAt: DateTimeOffset
    Labels: Map<string, string>
    Options: Map<string, string>
    Scope: string
}

type Network = {
    Name: string
    Id: string
    Driver: NetworkDriver
    Created: DateTimeOffset
    Subnets: Subnet list
    Internal: bool
    DnsEnabled: bool
    Labels: Map<string, string>
    Options: Map<string, string>
}
```

#### System Types

```fsharp
type SystemInfo = {
    Host: HostInfo
    Storage: StorageInfo
    Runtime: RuntimeInfo
    Version: VersionInfo
}

type VersionInfo = {
    Version: string
    ApiVersion: string
    GoVersion: string
    GitCommit: string
    Built: DateTimeOffset option
    OsArch: string
}
```

---

### 2.2 Cepaf.Podman.Domain.Specs

Specification types for creating resources with fluent builder patterns.

#### Container Spec

```fsharp
type ContainerSpec = {
    Name: string option
    Image: string
    Command: string list option
    Entrypoint: string list option
    WorkDir: string option
    Env: Map<string, string>
    EnvFile: string list
    Resources: ResourceConfig option
    Mounts: Mount list
    Volumes: NamedVolume list
    Network: NetworkConfig option
    PortMappings: PortMapping list
    Security: SecurityConfig option
    HealthCheck: HealthCheckConfig option
    RestartPolicy: RestartPolicy option
    StopSignal: string option
    StopTimeout: int option
    Remove: bool
    Labels: Map<string, string>
    Annotations: Map<string, string>
    Hostname: string option
    Terminal: bool
    Stdin: bool
}

module ContainerSpec =
    // Creation
    val create: image: string -> ContainerSpec

    // Identity
    val withName: string -> ContainerSpec -> ContainerSpec

    // Execution
    val withCommand: string list -> ContainerSpec -> ContainerSpec
    val withEntrypoint: string list -> ContainerSpec -> ContainerSpec
    val withWorkDir: string -> ContainerSpec -> ContainerSpec
    val withEnv: key: string -> value: string -> ContainerSpec -> ContainerSpec
    val withEnvMap: Map<string, string> -> ContainerSpec -> ContainerSpec

    // Resources
    val withResources: ResourceConfig -> ContainerSpec -> ContainerSpec
    val withMemoryLimit: bytes: int64 -> ContainerSpec -> ContainerSpec
    val withMemoryLimitMB: int -> ContainerSpec -> ContainerSpec
    val withMemoryLimitGB: int -> ContainerSpec -> ContainerSpec

    // Storage
    val withMount: Mount -> ContainerSpec -> ContainerSpec
    val withBindMount: source: string -> target: string -> ContainerSpec -> ContainerSpec
    val withVolume: name: string -> target: string -> ContainerSpec -> ContainerSpec

    // Network
    val withNetwork: NetworkConfig -> ContainerSpec -> ContainerSpec
    val withPort: hostPort: uint16 -> containerPort: uint16 -> ContainerSpec -> ContainerSpec
    val withPortTCP: hostPort: uint16 -> containerPort: uint16 -> ContainerSpec -> ContainerSpec
    val withPortUDP: hostPort: uint16 -> containerPort: uint16 -> ContainerSpec -> ContainerSpec

    // Security
    val withSecurity: SecurityConfig -> ContainerSpec -> ContainerSpec
    val withUser: string -> ContainerSpec -> ContainerSpec
    val withPrivileged: ContainerSpec -> ContainerSpec
    val withReadOnlyRootfs: ContainerSpec -> ContainerSpec

    // Health
    val withHealthCheck: HealthCheckConfig -> ContainerSpec -> ContainerSpec
    val withHttpHealthCheck: url: string -> interval: TimeSpan -> retries: int -> ContainerSpec -> ContainerSpec
    val withTcpHealthCheck: host: string -> port: int -> interval: TimeSpan -> retries: int -> ContainerSpec -> ContainerSpec

    // Lifecycle
    val withRestartPolicy: RestartPolicy -> ContainerSpec -> ContainerSpec
    val withRestartAlways: ContainerSpec -> ContainerSpec
    val withRestartOnFailure: retries: int -> ContainerSpec -> ContainerSpec
    val withStopTimeout: seconds: int -> ContainerSpec -> ContainerSpec
    val withAutoRemove: ContainerSpec -> ContainerSpec

    // Labels
    val withLabel: key: string -> value: string -> ContainerSpec -> ContainerSpec
    val withLabels: Map<string, string> -> ContainerSpec -> ContainerSpec
```

**Example:**
```fsharp
let spec =
    ContainerSpec.create "localhost/myapp:1.0.0"
    |> ContainerSpec.withName "myapp-server"
    |> ContainerSpec.withEnv "DATABASE_URL" "postgresql://localhost/db"
    |> ContainerSpec.withPort 8080us 80us
    |> ContainerSpec.withMemoryLimitMB 512
    |> ContainerSpec.withHttpHealthCheck "http://localhost:80/health" (TimeSpan.FromSeconds(30.0)) 3
    |> ContainerSpec.withRestartAlways
    |> ContainerSpec.withLabel "app" "myapp"
    |> ContainerSpec.withLabel "env" "production"
```

#### Pod Spec

```fsharp
type PodSpec = {
    Name: string option
    Hostname: string option
    Network: NetworkConfig option
    PortMappings: PortMapping list
    NoInfra: bool
    InfraImage: string option
    InfraName: string option
    InfraCommand: string list option
    Resources: ResourceConfig option
    Volumes: NamedVolume list
    Userns: string option
    SecurityOpt: string list
    Labels: Map<string, string>
    CgroupParent: string option
    ShareIPC: bool
    ShareNet: bool
    ShareUTS: bool
    SharePID: bool
    ShareCgroup: bool
}

module PodSpec =
    val create: unit -> PodSpec
    val withName: string -> PodSpec -> PodSpec
    val withHostname: string -> PodSpec -> PodSpec
    val withNetwork: NetworkConfig -> PodSpec -> PodSpec
    val withPort: hostPort: uint16 -> containerPort: uint16 -> PodSpec -> PodSpec
    val withNoInfra: PodSpec -> PodSpec
    val withInfraImage: string -> PodSpec -> PodSpec
    val withResources: ResourceConfig -> PodSpec -> PodSpec
    val withVolume: name: string -> target: string -> PodSpec -> PodSpec
    val withLabel: key: string -> value: string -> PodSpec -> PodSpec
    val withSharePID: PodSpec -> PodSpec
    val withoutShareNet: PodSpec -> PodSpec
```

#### Volume Spec

```fsharp
type VolumeSpec = {
    Name: string
    Driver: VolumeDriver
    Labels: Map<string, string>
    Options: Map<string, string>
}

module VolumeSpec =
    val create: name: string -> VolumeSpec
    val withDriver: VolumeDriver -> VolumeSpec -> VolumeSpec
    val withLabel: key: string -> value: string -> VolumeSpec -> VolumeSpec
    val withOption: key: string -> value: string -> VolumeSpec -> VolumeSpec
```

#### Network Spec

```fsharp
type NetworkSpec = {
    Name: string
    Driver: NetworkDriver
    Internal: bool
    DnsEnabled: bool
    Subnets: Subnet list
    Labels: Map<string, string>
    Options: Map<string, string>
}

module NetworkSpec =
    val create: name: string -> NetworkSpec
    val withDriver: NetworkDriver -> NetworkSpec -> NetworkSpec
    val withInternal: NetworkSpec -> NetworkSpec
    val withoutDns: NetworkSpec -> NetworkSpec
    val withSubnet: subnet: string -> gateway: string option -> NetworkSpec -> NetworkSpec
    val withLabel: key: string -> value: string -> NetworkSpec -> NetworkSpec
    val withOption: key: string -> value: string -> NetworkSpec -> NetworkSpec
```

---

### 2.3 Cepaf.Podman.Domain.Errors

#### Error Types

```fsharp
[<RequireQualifiedAccess>]
type PodmanError =
    // Connection errors
    | SocketNotFound of path: string
    | ConnectionRefused of endpoint: string
    | ConnectionTimeout of operation: string * durationMs: int64

    // API errors
    | ApiError of statusCode: int * message: string
    | NotFound of resourceType: string * id: string
    | Conflict of resourceType: string * reason: string
    | InvalidParameter of param: string * reason: string
    | BadRequest of message: string

    // Container errors
    | ContainerNotRunning of id: string
    | ContainerNotFound of id: string
    | ContainerAlreadyExists of name: string
    | ContainerAlreadyStopped of id: string
    | ContainerStartFailed of id: string * reason: string

    // Pod errors
    | PodNotFound of name: string
    | PodAlreadyExists of name: string

    // Image errors
    | ImageNotFound of reference: string
    | ImagePullFailed of reference: string * reason: string
    | ImageBuildFailed of reason: string
    | RegistryNotAllowed of registry: string

    // Volume errors
    | VolumeNotFound of name: string
    | VolumeInUse of name: string * containers: string list
    | VolumeAlreadyExists of name: string

    // Network errors
    | NetworkNotFound of name: string
    | NetworkInUse of name: string * containers: string list
    | NetworkAlreadyExists of name: string

    // Health errors
    | HealthCheckFailed of container: string * output: string
    | HealthCheckTimeout of container: string * timeoutMs: int64
    | HealthCheckNotConfigured of container: string

    // Safety errors
    | SafetyConstraintViolation of constraintId: string * reason: string
    | ValidationFailed of errors: string list

    // System errors
    | JsonParseError of message: string
    | JsonSerializeError of message: string
    | UnexpectedResponse of statusCode: int * body: string
    | InternalError of message: string
    | OperationCancelled

module PodmanError =
    val toMessage: PodmanError -> string
    val isRetryable: PodmanError -> bool
    val getSeverity: PodmanError -> string  // "CRITICAL", "HIGH", "MEDIUM", "LOW"
```

#### Result Types

```fsharp
type PodmanResult<'T> = Result<'T, PodmanError>
type AsyncPodmanResult<'T> = Async<PodmanResult<'T>>
```

#### Result Operators

```fsharp
[<AutoOpen>]
module ResultOperators =
    val (>>=): Result<'a, 'e> -> ('a -> Result<'b, 'e>) -> Result<'b, 'e>
    val (>>|): Result<'a, 'e> -> ('a -> 'b) -> Result<'b, 'e>
    val ok: 'a -> Result<'a, 'e>
    val error: 'e -> Result<'a, 'e>

module AsyncResult =
    val map: ('a -> 'b) -> AsyncPodmanResult<'a> -> AsyncPodmanResult<'b>
    val bind: ('a -> AsyncPodmanResult<'b>) -> AsyncPodmanResult<'a> -> AsyncPodmanResult<'b>
    val retn: 'a -> AsyncPodmanResult<'a>
    val error: PodmanError -> AsyncPodmanResult<'a>
    val catch: (exn -> PodmanError) -> Async<'a> -> AsyncPodmanResult<'a>
```

---

### 2.4 Cepaf.Podman.Domain.Events

#### Event Types

```fsharp
[<RequireQualifiedAccess>]
type EventType =
    | Container | Image | Pod | Volume | Network | System
    | Unknown of string

[<RequireQualifiedAccess>]
type ContainerAction =
    | Attach | Checkpoint | Cleanup | Commit | Create | Exec | ExecDied
    | Export | Import | Init | Kill | Mount | Pause | Prune | Remove
    | Rename | Restart | Restore | Start | Stop | Sync | Unmount | Unpause | Update
    | Unknown of string

type EventActor = {
    ID: string
    Attributes: Map<string, string>
}

type PodmanEvent = {
    Type: EventType
    Action: string
    Actor: EventActor
    Time: int64
    TimeNano: int64
    Status: string option
}

module PodmanEvent =
    val getTimestamp: PodmanEvent -> DateTimeOffset
    val isForContainer: containerId: string -> PodmanEvent -> bool
    val isAction: action: string -> PodmanEvent -> bool
    val getContainerAction: PodmanEvent -> ContainerAction option
```

#### Event Filters

```fsharp
type EventFilter = {
    Containers: string list
    Events: string list
    Images: string list
    Pods: string list
    Volumes: string list
    Types: EventType list
    Since: DateTimeOffset option
    Until: DateTimeOffset option
}

module EventFilter =
    val empty: EventFilter
    val forContainer: id: string -> EventFilter -> EventFilter
    val forContainers: ids: string list -> EventFilter -> EventFilter
    val forEvents: events: string list -> EventFilter -> EventFilter
    val forTypes: types: EventType list -> EventFilter -> EventFilter
    val containerEvents: EventFilter -> EventFilter
    val imageEvents: EventFilter -> EventFilter
    val podEvents: EventFilter -> EventFilter
    val forImage: id: string -> EventFilter -> EventFilter
    val forPod: name: string -> EventFilter -> EventFilter
    val forVolume: name: string -> EventFilter -> EventFilter
    val since: DateTimeOffset -> EventFilter -> EventFilter
    val until: DateTimeOffset -> EventFilter -> EventFilter
    val toQueryString: EventFilter -> string
```

---

## 3. Client Module

### 3.1 Cepaf.Podman.Client.UnixSocket

```fsharp
module UnixSocket =
    val exists: path: string -> bool
    val verify: path: string -> PodmanResult<unit>
    val createHttpClient: socketPath: string -> timeout: TimeSpan -> HttpClient
    val getDefaultPath: unit -> string
    val getPath: PodmanSocket -> string
    val autoDetect: unit -> PodmanResult<PodmanSocket>
```

### 3.2 Cepaf.Podman.Client.HttpClient

```fsharp
type PodmanClient = {
    HttpClient: HttpClient
    Config: PodmanClientConfig
    BasePath: string
}

type PodmanClientConfig = {
    Socket: PodmanSocket
    ApiVersion: string
    Timeout: TimeSpan
    RetryCount: int
    RetryDelay: TimeSpan
}

module PodmanClientConfig =
    val defaultConfig: PodmanClientConfig
    val withSocket: PodmanSocket -> PodmanClientConfig -> PodmanClientConfig
    val withApiVersion: string -> PodmanClientConfig -> PodmanClientConfig
    val withTimeout: TimeSpan -> PodmanClientConfig -> PodmanClientConfig
    val withRetry: count: int -> delay: TimeSpan -> PodmanClientConfig -> PodmanClientConfig

module HttpClient =
    // Client creation
    val create: PodmanClientConfig -> PodmanResult<PodmanClient>
    val createDefault: unit -> PodmanResult<PodmanClient>
    val createWithSocket: socketPath: string -> PodmanResult<PodmanClient>
    val dispose: PodmanClient -> unit

    // HTTP operations
    val getRaw: PodmanClient -> endpoint: string -> AsyncPodmanResult<string>
    val get<'T>: PodmanClient -> endpoint: string -> (string -> PodmanResult<'T>) -> AsyncPodmanResult<'T>
    val post: PodmanClient -> endpoint: string -> body: string option -> AsyncPodmanResult<string>
    val postEmpty: PodmanClient -> endpoint: string -> AsyncPodmanResult<string>
    val postJson: PodmanClient -> endpoint: string -> json: string -> AsyncPodmanResult<string>
    val delete: PodmanClient -> endpoint: string -> AsyncPodmanResult<unit>
    val put: PodmanClient -> endpoint: string -> json: string -> AsyncPodmanResult<string>

    // Streaming
    val getStream: PodmanClient -> endpoint: string -> CancellationToken -> IAsyncEnumerable<PodmanResult<string>>

    // Utilities
    val ping: PodmanClient -> AsyncPodmanResult<bool>
    val version: PodmanClient -> AsyncPodmanResult<VersionInfo>
    val withRetry: PodmanClient -> (unit -> AsyncPodmanResult<'T>) -> AsyncPodmanResult<'T>
```

**Example: Custom Client Configuration**
```fsharp
let config =
    PodmanClientConfig.defaultConfig
    |> PodmanClientConfig.withSocket (PodmanSocket.Rootless ("1000", "/run/user/1000/podman/podman.sock"))
    |> PodmanClientConfig.withTimeout (TimeSpan.FromSeconds(60.0))
    |> PodmanClientConfig.withRetry 5 (TimeSpan.FromSeconds(2.0))

match HttpClient.create config with
| Ok client -> // use client
| Error e -> // handle error
```

---

## 4. API Modules

### 4.1 Cepaf.Podman.Api.Containers

```fsharp
module Containers =

    // List Filters
    type ListFilters = {
        All: bool
        Limit: int option
        Status: ContainerStatus list
        Label: string list
        Name: string list
        Id: string list
    }

    module ListFilters =
        val empty: ListFilters
        val all: ListFilters -> ListFilters
        val withLimit: int -> ListFilters -> ListFilters
        val withStatus: ContainerStatus -> ListFilters -> ListFilters
        val withLabel: string -> ListFilters -> ListFilters
        val withName: string -> ListFilters -> ListFilters
        val withId: string -> ListFilters -> ListFilters

    // List Operations
    val list: PodmanClient -> ListFilters -> AsyncPodmanResult<ContainerSummary list>
    val listAll: PodmanClient -> AsyncPodmanResult<ContainerSummary list>
    val listRunning: PodmanClient -> AsyncPodmanResult<ContainerSummary list>
    val exists: PodmanClient -> id: string -> AsyncPodmanResult<bool>

    // Inspect Operations
    val inspect: PodmanClient -> id: string -> AsyncPodmanResult<ContainerInspect>
    val getState: PodmanClient -> id: string -> AsyncPodmanResult<ContainerStatus>
    val isRunning: PodmanClient -> id: string -> AsyncPodmanResult<bool>

    // Lifecycle Operations
    val create: PodmanClient -> ContainerSpec -> AsyncPodmanResult<string>
    val start: PodmanClient -> id: string -> AsyncPodmanResult<unit>
    val stop: PodmanClient -> id: string -> timeout: int option -> AsyncPodmanResult<unit>
    val restart: PodmanClient -> id: string -> timeout: int option -> AsyncPodmanResult<unit>
    val kill: PodmanClient -> id: string -> signal: string option -> AsyncPodmanResult<unit>
    val pause: PodmanClient -> id: string -> AsyncPodmanResult<unit>
    val unpause: PodmanClient -> id: string -> AsyncPodmanResult<unit>
    val remove: PodmanClient -> id: string -> force: bool -> volumes: bool -> AsyncPodmanResult<unit>
    val rename: PodmanClient -> id: string -> newName: string -> AsyncPodmanResult<unit>

    // Wait Operations
    type WaitCondition = NotRunning | NextExit | Removed | Stopped
    val wait: PodmanClient -> id: string -> WaitCondition -> AsyncPodmanResult<int>
    val waitForStop: PodmanClient -> id: string -> AsyncPodmanResult<int>

    // Logs Operations
    type LogOptions = {
        Follow: bool
        Stdout: bool
        Stderr: bool
        Timestamps: bool
        Tail: int option
        Since: DateTimeOffset option
        Until: DateTimeOffset option
    }
    val logs: PodmanClient -> id: string -> LogOptions -> AsyncPodmanResult<string>
    val logsLast: PodmanClient -> id: string -> lines: int -> AsyncPodmanResult<string>

    // Exec Operations
    val exec: PodmanClient -> id: string -> cmd: string list -> detach: bool -> AsyncPodmanResult<string>
    val execWait: PodmanClient -> id: string -> cmd: string list -> AsyncPodmanResult<string>
    val execDetached: PodmanClient -> id: string -> cmd: string list -> AsyncPodmanResult<unit>

    // Stats Operations
    type ContainerStats = {
        Id: string
        Name: string
        CpuPercent: float
        MemoryUsage: int64
        MemoryLimit: int64
        MemoryPercent: float
        NetworkRx: int64
        NetworkTx: int64
        BlockRead: int64
        BlockWrite: int64
        Pids: int
    }
    val stats: PodmanClient -> id: string -> AsyncPodmanResult<ContainerStats>

    // Health Check Operations
    val healthCheck: PodmanClient -> id: string -> AsyncPodmanResult<HealthStatus>

    // Convenience Operations
    val createAndStart: PodmanClient -> ContainerSpec -> AsyncPodmanResult<string>
    val stopAndRemove: PodmanClient -> id: string -> timeout: int -> AsyncPodmanResult<unit>
    val findByName: PodmanClient -> name: string -> AsyncPodmanResult<ContainerSummary option>
```

**Example: Container Lifecycle**
```fsharp
async {
    let spec =
        ContainerSpec.create "localhost/nginx:1.24"
        |> ContainerSpec.withName "web-server"
        |> ContainerSpec.withPort 8080us 80us
        |> ContainerSpec.withRestartAlways

    // Create and start
    let! result = Containers.createAndStart client spec
    match result with
    | Ok containerId ->
        printfn "Started container: %s" containerId

        // Wait for it to be ready
        do! Async.Sleep 2000

        // Check health
        let! health = Containers.healthCheck client containerId

        // Get logs
        let! logs = Containers.logsLast client containerId 100

        // Execute command
        let! execResult = Containers.execWait client containerId ["nginx", "-v"]

        // Stop and remove
        let! _ = Containers.stopAndRemove client containerId 10
        ()
    | Error e ->
        printfn "Failed: %s" (PodmanError.toMessage e)
}
```

---

### 4.2 Cepaf.Podman.Api.Images

```fsharp
module Images =

    // List Operations
    val list: PodmanClient -> all: bool -> AsyncPodmanResult<ImageSummary list>
    val listAll: PodmanClient -> AsyncPodmanResult<ImageSummary list>
    val exists: PodmanClient -> reference: string -> AsyncPodmanResult<bool>

    // Inspect Operations
    val inspect: PodmanClient -> reference: string -> AsyncPodmanResult<ImageInspect>
    val history: PodmanClient -> reference: string -> AsyncPodmanResult<ImageHistoryLayer list>

    // Pull Operations (localhost/ registry only - SC-CNT-010)
    val pull: PodmanClient -> reference: string -> AsyncPodmanResult<string>
    val pullWithPolicy: PodmanClient -> reference: string -> policy: string -> AsyncPodmanResult<string>

    // Push Operations (localhost/ registry only - SC-CNT-010)
    val push: PodmanClient -> reference: string -> destination: string option -> AsyncPodmanResult<unit>

    // Tag Operations
    val tag: PodmanClient -> reference: string -> repo: string -> tag: string -> AsyncPodmanResult<unit>
    val untag: PodmanClient -> reference: string -> AsyncPodmanResult<unit>

    // Remove Operations
    val remove: PodmanClient -> reference: string -> force: bool -> AsyncPodmanResult<unit>
    val prune: PodmanClient -> all: bool -> AsyncPodmanResult<string list>

    // Build Options
    type BuildOptions = {
        Dockerfile: string
        Tags: string list
        NoCache: bool
        Pull: bool
        Squash: bool
        Labels: Map<string, string>
        BuildArgs: Map<string, string>
    }

    // Search
    type SearchResult = {
        Name: string
        Description: string
        Stars: int
        Official: bool
        Automated: bool
    }
    val search: PodmanClient -> term: string -> limit: int option -> AsyncPodmanResult<SearchResult list>

    // Convenience Operations
    val findByReference: PodmanClient -> reference: string -> AsyncPodmanResult<ImageSummary option>
    val ensureExists: PodmanClient -> reference: string -> AsyncPodmanResult<string>
```

---

### 4.3 Cepaf.Podman.Api.Pods

```fsharp
module Pods =

    // List Operations
    val list: PodmanClient -> all: bool -> AsyncPodmanResult<PodSummary list>
    val listAll: PodmanClient -> AsyncPodmanResult<PodSummary list>
    val exists: PodmanClient -> name: string -> AsyncPodmanResult<bool>

    // Inspect Operations
    val inspect: PodmanClient -> name: string -> AsyncPodmanResult<PodInspect>

    // Lifecycle Operations
    val create: PodmanClient -> PodSpec -> AsyncPodmanResult<string>
    val start: PodmanClient -> name: string -> AsyncPodmanResult<unit>
    val stop: PodmanClient -> name: string -> timeout: int option -> AsyncPodmanResult<unit>
    val restart: PodmanClient -> name: string -> AsyncPodmanResult<unit>
    val pause: PodmanClient -> name: string -> AsyncPodmanResult<unit>
    val unpause: PodmanClient -> name: string -> AsyncPodmanResult<unit>
    val kill: PodmanClient -> name: string -> signal: string option -> AsyncPodmanResult<unit>
    val remove: PodmanClient -> name: string -> force: bool -> AsyncPodmanResult<unit>

    // Process Operations
    val top: PodmanClient -> name: string -> AsyncPodmanResult<string>

    // Stats
    type PodStats = {
        Name: string
        Id: string
        CpuPercent: float
        MemoryUsage: int64
        MemoryLimit: int64
        ContainerCount: int
    }
    val stats: PodmanClient -> name: string -> AsyncPodmanResult<PodStats>

    // Convenience Operations
    val createAndStart: PodmanClient -> PodSpec -> AsyncPodmanResult<string>
    val stopAndRemove: PodmanClient -> name: string -> timeout: int -> AsyncPodmanResult<unit>
    val findByName: PodmanClient -> name: string -> AsyncPodmanResult<PodSummary option>
```

---

### 4.4 Cepaf.Podman.Api.Volumes

```fsharp
module Volumes =

    // List Operations
    val list: PodmanClient -> AsyncPodmanResult<Volume list>
    val exists: PodmanClient -> name: string -> AsyncPodmanResult<bool>

    // Inspect Operations
    val inspect: PodmanClient -> name: string -> AsyncPodmanResult<Volume>

    // Lifecycle Operations
    val create: PodmanClient -> VolumeSpec -> AsyncPodmanResult<Volume>
    val createNamed: PodmanClient -> name: string -> AsyncPodmanResult<Volume>
    val remove: PodmanClient -> name: string -> force: bool -> AsyncPodmanResult<unit>
    val prune: PodmanClient -> AsyncPodmanResult<string list>

    // Usage
    type VolumeUsage = {
        Name: string
        Size: int64
        RefCount: int
        Links: string list
    }
    val usage: PodmanClient -> name: string -> AsyncPodmanResult<VolumeUsage>

    // Convenience Operations
    val findByName: PodmanClient -> name: string -> AsyncPodmanResult<Volume option>
    val ensureExists: PodmanClient -> name: string -> AsyncPodmanResult<Volume>
    val createWithDriver: PodmanClient -> name: string -> driver: string -> options: Map<string, string> -> AsyncPodmanResult<Volume>
    val createTmpfs: PodmanClient -> name: string -> size: string -> AsyncPodmanResult<Volume>
    val removeIfExists: PodmanClient -> name: string -> AsyncPodmanResult<unit>
    val listWithLabel: PodmanClient -> label: string -> AsyncPodmanResult<Volume list>
    val listNames: PodmanClient -> AsyncPodmanResult<string list>
```

---

### 4.5 Cepaf.Podman.Api.Networks

```fsharp
module Networks =

    // List Operations
    val list: PodmanClient -> AsyncPodmanResult<Network list>
    val exists: PodmanClient -> name: string -> AsyncPodmanResult<bool>

    // Inspect Operations
    val inspect: PodmanClient -> name: string -> AsyncPodmanResult<Network>

    // Lifecycle Operations
    val create: PodmanClient -> NetworkSpec -> AsyncPodmanResult<Network>
    val createNamed: PodmanClient -> name: string -> AsyncPodmanResult<Network>
    val remove: PodmanClient -> name: string -> force: bool -> AsyncPodmanResult<unit>
    val prune: PodmanClient -> AsyncPodmanResult<string list>

    // Connect/Disconnect
    type ConnectOptions = {
        Container: string
        Aliases: string list
        IPv4Address: string option
        IPv6Address: string option
    }
    val connect: PodmanClient -> networkName: string -> ConnectOptions -> AsyncPodmanResult<unit>
    val connectContainer: PodmanClient -> networkName: string -> containerName: string -> AsyncPodmanResult<unit>
    val disconnect: PodmanClient -> networkName: string -> containerName: string -> force: bool -> AsyncPodmanResult<unit>

    // Convenience Operations
    val findByName: PodmanClient -> name: string -> AsyncPodmanResult<Network option>
    val ensureExists: PodmanClient -> name: string -> AsyncPodmanResult<Network>
    val createBridge: PodmanClient -> name: string -> subnet: string option -> AsyncPodmanResult<Network>
    val createMacvlan: PodmanClient -> name: string -> parent: string -> subnet: string -> AsyncPodmanResult<Network>
    val removeIfExists: PodmanClient -> name: string -> AsyncPodmanResult<unit>
    val listWithLabel: PodmanClient -> label: string -> AsyncPodmanResult<Network list>
    val listNames: PodmanClient -> AsyncPodmanResult<string list>
    val getDefault: PodmanClient -> AsyncPodmanResult<Network option>
```

---

### 4.6 Cepaf.Podman.Api.System

```fsharp
module System =

    // Info Operations
    val info: PodmanClient -> AsyncPodmanResult<SystemInfo>
    val version: PodmanClient -> AsyncPodmanResult<VersionInfo>
    val ping: PodmanClient -> AsyncPodmanResult<bool>

    // Disk Usage
    val diskUsage: PodmanClient -> AsyncPodmanResult<DiskUsage>

    // Prune Operations
    val pruneContainers: PodmanClient -> AsyncPodmanResult<string list>
    val pruneImages: PodmanClient -> all: bool -> AsyncPodmanResult<string list>
    val pruneVolumes: PodmanClient -> AsyncPodmanResult<string list>
    val pruneNetworks: PodmanClient -> AsyncPodmanResult<string list>
    val pruneAll: PodmanClient -> volumes: bool -> AsyncPodmanResult<unit>
```

---

## 5. Events Module

### 5.1 Cepaf.Podman.Events.Stream

```fsharp
module Stream =

    // Event Streaming
    val stream: PodmanClient -> EventFilter -> CancellationToken -> IAsyncEnumerable<PodmanResult<PodmanEvent>>
    val streamAll: PodmanClient -> CancellationToken -> IAsyncEnumerable<PodmanResult<PodmanEvent>>
    val streamContainers: PodmanClient -> CancellationToken -> IAsyncEnumerable<PodmanEvent>>
    val streamPods: PodmanClient -> CancellationToken -> IAsyncEnumerable<PodmanResult<PodmanEvent>>
    val streamImages: PodmanClient -> CancellationToken -> IAsyncEnumerable<PodmanResult<PodmanEvent>>

    // One-Shot Query
    val getEvents: PodmanClient -> since: DateTimeOffset -> until: DateTimeOffset -> AsyncPodmanResult<PodmanEvent list>
    val getRecentEvents: PodmanClient -> seconds: int -> AsyncPodmanResult<PodmanEvent list>

    // Subscriptions
    type StreamEventHandler = PodmanEvent -> unit

    type EventSubscription = {
        Id: Guid
        Handler: StreamEventHandler
        Filter: EventFilter
        CancellationTokenSource: CancellationTokenSource
    }

    val subscribe: PodmanClient -> handler: StreamEventHandler -> filter: EventFilter -> EventSubscription
    val unsubscribe: EventSubscription -> unit
    val onContainerStart: PodmanClient -> (PodmanEvent -> unit) -> EventSubscription
    val onContainerStop: PodmanClient -> (PodmanEvent -> unit) -> EventSubscription
    val onContainerDie: PodmanClient -> (PodmanEvent -> unit) -> EventSubscription
```

**Example: Event Streaming**
```fsharp
// Subscribe to container start events
let subscription =
    Stream.onContainerStart client (fun event ->
        let name = EventActor.getName event.Actor |> Option.defaultValue "unknown"
        printfn "Container started: %s" name
    )

// Later, unsubscribe
Stream.unsubscribe subscription

// Or use IAsyncEnumerable directly
async {
    use cts = new CancellationTokenSource()
    let events = Stream.streamContainers client cts.Token

    // Process events using TaskSeq or manual iteration
    let enumerator = events.GetAsyncEnumerator(cts.Token)
    while! enumerator.MoveNextAsync() do
        match enumerator.Current with
        | Ok event -> printfn "Event: %s %s" event.Action event.Actor.ID
        | Error e -> printfn "Error: %s" (PodmanError.toMessage e)
}
```

---

## 6. Compose Module

### 6.1 Cepaf.Podman.Compose.Parser

```fsharp
module Parser =

    // Compose File Types
    type ComposeVersion = V2 | V3 | V3_8 | Unknown of string

    type ComposeService = {
        Name: string
        Image: string option
        Build: ComposeBuild option
        Command: string list
        Entrypoint: string list
        Environment: ComposeEnv list
        Ports: ComposePort list
        Volumes: ComposeVolume list
        Networks: Map<string, ComposeServiceNetwork>
        DependsOn: string list
        HealthCheck: ComposeHealthCheck option
        Deploy: ComposeDeploy option
        Restart: string option
        Labels: Map<string, string>
        WorkingDir: string option
        User: string option
        Privileged: bool
        CapAdd: string list
        CapDrop: string list
        SecurityOpt: string list
    }

    type ComposeFile = {
        Version: ComposeVersion
        Services: Map<string, ComposeService>
        Networks: Map<string, ComposeNetwork>
        Volumes: Map<string, ComposeVolumeConfig>
    }

    // Parsing
    val parse: yaml: string -> PodmanResult<ComposeFile>
    val parseFile: path: string -> PodmanResult<ComposeFile>
    val findComposeFile: directory: string -> string option

    // Helper Functions
    val parseDuration: string -> TimeSpan option   // "30s", "1m", "2h"
    val parseMemory: string -> int64 option        // "512M", "2G"
    val parsePort: string -> ComposePort option    // "8080:80/tcp"
    val parseVolume: string -> ComposeVolume option // "./data:/app/data:ro"

    // Conversion to Domain Types
    val toContainerSpec: ComposeService -> ContainerSpec option
    val toNetworkSpec: ComposeNetwork -> NetworkSpec
    val toVolumeSpec: ComposeVolumeConfig -> VolumeSpec
    val getDeploymentOrder: ComposeFile -> string list  // Topological sort
```

**Example: Deploy Compose File**
```fsharp
async {
    match Parser.parseFile "/app/podman-compose.yml" with
    | Error e -> printfn "Parse error: %s" (PodmanError.toMessage e)
    | Ok compose ->
        // Get deployment order (respects depends_on)
        let order = Parser.getDeploymentOrder compose

        // Create networks first
        for (name, net) in compose.Networks |> Map.toList do
            let spec = Parser.toNetworkSpec net
            let! _ = Networks.create client spec
            ()

        // Create volumes
        for (name, vol) in compose.Volumes |> Map.toList do
            let spec = Parser.toVolumeSpec vol
            let! _ = Volumes.create client spec
            ()

        // Deploy services in order
        for serviceName in order do
            match compose.Services |> Map.tryFind serviceName with
            | None -> ()
            | Some service ->
                match Parser.toContainerSpec service with
                | None -> printfn "No image for service: %s" serviceName
                | Some spec ->
                    let! result = Containers.createAndStart client spec
                    match result with
                    | Ok id -> printfn "Started %s: %s" serviceName id
                    | Error e -> printfn "Failed %s: %s" serviceName (PodmanError.toMessage e)
}
```

---

## 7. Health Module

### 7.1 Cepaf.Podman.Health.Probes

```fsharp
module Probes =

    // Probe Types
    type ProbeResult = {
        ContainerId: string
        ContainerName: string
        Status: HealthStatus
        Message: string option
        Timestamp: DateTimeOffset
        Duration: TimeSpan
    }

    type ProbeConfig = {
        Interval: TimeSpan
        Timeout: TimeSpan
        Retries: int
        StartPeriod: TimeSpan
    }

    module ProbeConfig =
        val defaults: ProbeConfig
        val withInterval: TimeSpan -> ProbeConfig -> ProbeConfig
        val withTimeout: TimeSpan -> ProbeConfig -> ProbeConfig
        val withRetries: int -> ProbeConfig -> ProbeConfig
        val withStartPeriod: TimeSpan -> ProbeConfig -> ProbeConfig

    // Single Health Check
    val check: PodmanClient -> containerId: string -> AsyncPodmanResult<ProbeResult>
    val checkAll: PodmanClient -> AsyncPodmanResult<ProbeResult list>
    val checkByLabel: PodmanClient -> label: string -> AsyncPodmanResult<ProbeResult list>

    // Health Monitoring
    type MonitorState = {
        Running: bool
        LastCheck: DateTimeOffset option
        Results: Map<string, ProbeResult>
        Failures: Map<string, int>
    }

    type HealthMonitor = {
        Client: PodmanClient
        Config: ProbeConfig
        CancellationTokenSource: CancellationTokenSource
        mutable State: MonitorState
        OnHealthChange: (ProbeResult -> unit) option
        OnUnhealthy: (ProbeResult -> unit) option
    }

    val createMonitor: PodmanClient -> ProbeConfig -> HealthMonitor
    val onHealthChange: (ProbeResult -> unit) -> HealthMonitor -> HealthMonitor
    val onUnhealthy: (ProbeResult -> unit) -> HealthMonitor -> HealthMonitor
    val startMonitor: HealthMonitor -> unit
    val stopMonitor: HealthMonitor -> unit
    val getMonitorState: HealthMonitor -> MonitorState
    val disposeMonitor: HealthMonitor -> unit

    // Kubernetes-style Probes
    val livenessProbe: PodmanClient -> containerId: string -> AsyncPodmanResult<bool>
    val readinessProbe: PodmanClient -> containerId: string -> AsyncPodmanResult<bool>
    val startupProbe: PodmanClient -> containerId: string -> timeout: TimeSpan -> AsyncPodmanResult<bool>

    // Health Summary
    type HealthSummary = {
        Total: int
        Healthy: int
        Unhealthy: int
        Starting: int
        NoHealthCheck: int
        Timestamp: DateTimeOffset
    }

    val getSummary: PodmanClient -> AsyncPodmanResult<HealthSummary>
    val allHealthy: PodmanClient -> AsyncPodmanResult<bool>
    val getUnhealthy: PodmanClient -> AsyncPodmanResult<ProbeResult list>
```

**Example: Health Monitoring**
```fsharp
// Create monitor with custom config
let config =
    ProbeConfig.defaults
    |> ProbeConfig.withInterval (TimeSpan.FromSeconds(15.0))
    |> ProbeConfig.withRetries 3

let monitor =
    Probes.createMonitor client config
    |> Probes.onHealthChange (fun result ->
        printfn "Health changed: %s -> %A" result.ContainerName result.Status
    )
    |> Probes.onUnhealthy (fun result ->
        // Alert or restart container
        printfn "UNHEALTHY: %s" result.ContainerName
    )

// Start monitoring
Probes.startMonitor monitor

// Later, check state
let state = Probes.getMonitorState monitor
printfn "Last check: %A, Healthy: %d" state.LastCheck (state.Results |> Map.filter (fun _ r -> r.Status = HealthStatus.Healthy) |> Map.count)

// Cleanup
Probes.disposeMonitor monitor
```

---

## 8. Safety Module

See separate document: [SAFETY.md](./SAFETY.md)

---

## 9. Error Handling

### Pattern Matching on Errors

```fsharp
async {
    let! result = Containers.start client "mycontainer"
    match result with
    | Ok () ->
        printfn "Container started"
    | Error (PodmanError.ContainerNotFound id) ->
        printfn "Container not found: %s" id
    | Error (PodmanError.ContainerNotRunning id) ->
        printfn "Container not running: %s" id
    | Error (PodmanError.ConnectionTimeout (op, ms)) ->
        printfn "Timeout after %dms during: %s" ms op
    | Error e ->
        printfn "Other error: %s (Severity: %s)" (PodmanError.toMessage e) (PodmanError.getSeverity e)
}
```

### Retry with Exponential Backoff

```fsharp
let rec retryWithBackoff (maxRetries: int) (delay: TimeSpan) (op: unit -> AsyncPodmanResult<'T>) = async {
    let! result = op()
    match result with
    | Ok v -> return Ok v
    | Error e when PodmanError.isRetryable e && maxRetries > 0 ->
        do! Async.Sleep (int delay.TotalMilliseconds)
        return! retryWithBackoff (maxRetries - 1) (delay.Add(delay)) op
    | Error e -> return Error e
}

// Usage
async {
    let! result = retryWithBackoff 3 (TimeSpan.FromSeconds(1.0)) (fun () ->
        Containers.start client "mycontainer"
    )
    // ...
}
```

### Combining Multiple Results

```fsharp
async {
    let! containers = Containers.listRunning client
    let! images = Images.list client false
    let! networks = Networks.list client

    match containers, images, networks with
    | Ok c, Ok i, Ok n ->
        printfn "Containers: %d, Images: %d, Networks: %d" c.Length i.Length n.Length
    | Error e, _, _ | _, Error e, _ | _, _, Error e ->
        printfn "Error: %s" (PodmanError.toMessage e)
}
```

---

## 10. Async Workflow Patterns

### Sequential Operations

```fsharp
async {
    let! imageResult = Images.ensureExists client "localhost/myapp:1.0"
    match imageResult with
    | Error e -> return Error e
    | Ok _ ->
        let spec = ContainerSpec.create "localhost/myapp:1.0" |> ContainerSpec.withName "myapp"
        let! createResult = Containers.create client spec
        match createResult with
        | Error e -> return Error e
        | Ok id ->
            let! startResult = Containers.start client id
            return startResult |> Result.map (fun () -> id)
}
```

### Using AsyncResult Module

```fsharp
// Chain operations with bind
let deployContainer (client: PodmanClient) (imageName: string) (containerName: string) =
    Images.ensureExists client imageName
    |> AsyncResult.bind (fun _ ->
        let spec = ContainerSpec.create imageName |> ContainerSpec.withName containerName
        Containers.create client spec
    )
    |> AsyncResult.bind (fun id ->
        Containers.start client id
        |> AsyncResult.map (fun () -> id)
    )
```

### Parallel Operations

```fsharp
async {
    let containerIds = ["app", "db", "cache"]

    // Start all containers in parallel
    let! results =
        containerIds
        |> List.map (fun id -> Containers.start client id)
        |> Async.Parallel

    // Check all succeeded
    let failures =
        results
        |> Array.choose (function Error e -> Some e | Ok _ -> None)

    if failures.Length > 0 then
        printfn "Some containers failed to start"
    else
        printfn "All containers started successfully"
}
```

### Timeout Handling

```fsharp
let withTimeout (timeout: TimeSpan) (operation: AsyncPodmanResult<'T>) : AsyncPodmanResult<'T> = async {
    let! completed =
        Async.Choice [
            async {
                let! result = operation
                return Some result
            }
            async {
                do! Async.Sleep (int timeout.TotalMilliseconds)
                return None
            }
        ]
    match completed with
    | Some result -> return result
    | None -> return Error (PodmanError.ConnectionTimeout ("operation", int64 timeout.TotalMilliseconds))
}

// Usage
async {
    let! result =
        Containers.start client "mycontainer"
        |> withTimeout (TimeSpan.FromSeconds(30.0))
    // ...
}
```

### Cleanup Pattern (try/finally)

```fsharp
async {
    let! createResult = Containers.create client spec
    match createResult with
    | Error e -> return Error e
    | Ok containerId ->
        try
            let! startResult = Containers.start client containerId
            match startResult with
            | Error e -> return Error e
            | Ok () ->
                // Do work with running container
                let! output = Containers.execWait client containerId ["some-command"]
                return output
        finally
            // Always cleanup
            Containers.remove client containerId true false
            |> Async.RunSynchronously
            |> ignore
}
```

---

## Appendix: Module Index

| Module | Namespace | Purpose |
|--------|-----------|---------|
| Types | Cepaf.Podman.Domain | Core type definitions |
| Errors | Cepaf.Podman.Domain | Error types and handlers |
| Specs | Cepaf.Podman.Domain | Resource specification builders |
| Events | Cepaf.Podman.Domain | Event type definitions |
| UnixSocket | Cepaf.Podman.Client | Unix socket connection |
| HttpClient | Cepaf.Podman.Client | HTTP operations |
| Serialization | Cepaf.Podman.Client | JSON parsing/serialization |
| Containers | Cepaf.Podman.Api | Container management |
| Images | Cepaf.Podman.Api | Image management |
| Pods | Cepaf.Podman.Api | Pod management |
| Volumes | Cepaf.Podman.Api | Volume management |
| Networks | Cepaf.Podman.Api | Network management |
| System | Cepaf.Podman.Api | System operations |
| Stream | Cepaf.Podman.Events | Event streaming |
| Parser | Cepaf.Podman.Compose | Compose file parsing |
| Probes | Cepaf.Podman.Health | Health probing |
| Constraints | Cepaf.Podman.Safety | Safety validation |

---

*Generated from Cepaf.Podman source code. Last updated: 2025-12-23*
