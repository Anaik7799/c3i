# Cepaf.Modules.Podman - F# Library Architecture Document

**Version**: 1.1.0
**Date**: 2025-12-23
**Status**: DESIGN SPECIFICATION
**Compliance**: SIL-2, SC-POD-*, STAMP Safety Methodology
**Reference**: PODMAN_SYSTEM_ONTOLOGY.md v3.0.0
**API Version**: Podman REST API v5.7

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Design Principles](#3-design-principles)
4. [Module Structure](#4-module-structure)
5. [Core Types & Domain Model](#5-core-types--domain-model)
6. [API Client Layer](#6-api-client-layer)
7. [Lifecycle Management](#7-lifecycle-management)
8. [OODA Control Loop](#8-ooda-control-loop)
9. [Error Handling & Recovery](#9-error-handling--recovery)
10. [Implementation Plan](#10-implementation-plan)
11. [Test Plan](#11-test-plan)
12. [Integration Guide](#12-integration-guide)
13. [Appendices](#13-appendices)

---

## 1. Executive Summary

### 1.1 Purpose

This document specifies the architecture, design, implementation, and test plan for `Cepaf.Modules.Podman` - a comprehensive F# library for managing all aspects of Podman container lifecycle, orchestration, and deployment within the CEPAF# (Cybernetic Execution and Performance Architect) framework.

### 1.2 Scope

The library provides:
- **Complete API Coverage**: Full Podman REST API v5.7 bindings
- **Type-Safe Operations**: F# discriminated unions and result types for safe container operations
- **Lifecycle Management**: Container, Pod, Image, Volume, and Network lifecycle orchestration
- **OODA Integration**: Observe-Orient-Decide-Act control loops for autonomic management
- **STAMP Compliance**: Safety constraints enforcement per SC-POD-* specifications
- **Resilient Operations**: Automatic retry, circuit breaker, and recovery patterns

### 1.3 Goals

| Goal | Metric | Target |
|------|--------|--------|
| API Coverage | Endpoints implemented / Total endpoints | 100% |
| Type Safety | Runtime type errors | 0 |
| Test Coverage | Lines covered / Total lines | > 95% |
| Latency Overhead | Library overhead vs direct API call | < 5ms |
| Recovery Success | Automatic recoveries / Total failures | > 90% |

---

## 2. Architecture Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CEPAF# ORCHESTRATOR                                │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      Cepaf.Modules.Podman                              │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │   OODA      │  │  Lifecycle  │  │   Health    │  │  Recovery   │  │  │
│  │  │  Control    │◄─┤  Manager    │◄─┤   Monitor   │◄─┤   Engine    │  │  │
│  │  │   Loop      │  │             │  │             │  │             │  │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │  │
│  │         │                │                │                │         │  │
│  │  ┌──────▼────────────────▼────────────────▼────────────────▼──────┐  │  │
│  │  │                    API Client Layer                             │  │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │  │  │
│  │  │  │Container │ │   Pod    │ │  Image   │ │ Volume   │ ...       │  │  │
│  │  │  │  Client  │ │  Client  │ │  Client  │ │  Client  │           │  │  │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │  │  │
│  │  └─────────────────────────────┬───────────────────────────────────┘  │  │
│  │                                │                                      │  │
│  │  ┌─────────────────────────────▼───────────────────────────────────┐  │  │
│  │  │                    HTTP Transport Layer                          │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │  │  │
│  │  │  │ Unix Socket  │  │    HTTP/S    │  │  Connection Pool     │  │  │  │
│  │  │  │  Connector   │  │   Connector  │  │  & Circuit Breaker   │  │  │  │
│  │  │  └──────────────┘  └──────────────┘  └──────────────────────┘  │  │  │
│  │  └─────────────────────────────┬───────────────────────────────────┘  │  │
│  └────────────────────────────────┼───────────────────────────────────────┘  │
└───────────────────────────────────┼─────────────────────────────────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │     Podman REST API v5.7      │
                    │  (Unix Socket / HTTP/HTTPS)   │
                    └───────────────────────────────┘
```

### 2.2 Layer Responsibilities

| Layer | Responsibility | Key Components |
|-------|---------------|----------------|
| **OODA Control** | Autonomic decision making | Observer, Orientator, Decider, Actuator |
| **Lifecycle Manager** | Container/Pod state orchestration | StateManager, TransitionExecutor |
| **Health Monitor** | Continuous health probing | HealthChecker, MetricsCollector |
| **Recovery Engine** | Failure detection and remediation | FailureDetector, RecoveryPlanner |
| **API Client** | Type-safe API bindings | ContainerClient, PodClient, etc. |
| **HTTP Transport** | Low-level communication | SocketConnector, HttpClient |

### 2.3 Communication Patterns

```fsharp
// Communication flow types
type CommunicationPattern =
    | UnixSocket of path: string          // Default: /run/podman/podman.sock
    | HttpEndpoint of uri: Uri            // Remote: http://host:port
    | HttpsEndpoint of uri: Uri * cert: X509Certificate2 option

// Connection configuration
type ConnectionConfig = {
    Pattern: CommunicationPattern
    Timeout: TimeSpan
    MaxRetries: int
    RetryDelay: TimeSpan
    CircuitBreakerThreshold: int
    PoolSize: int
}
```

---

## 3. Design Principles

### 3.1 Core Principles

| Principle | Description | Implementation |
|-----------|-------------|----------------|
| **Functional First** | Immutable types, pure functions, explicit effects | `Result<'T, Error>`, `Async<'T>` |
| **Type Safety** | Compile-time guarantees | Discriminated unions, phantom types |
| **Explicit Errors** | No exceptions for control flow | Railway-oriented programming |
| **Composability** | Small, focused functions | Computation expressions |
| **Testability** | Dependency injection, pure core | Interface-based IO boundaries |
| **STAMP Compliance** | Safety constraints as code | Constraint validation interceptors |

### 3.2 F# Idioms

```fsharp
// Railway-oriented programming with Result
module Result =
    let bind f result =
        match result with
        | Ok x -> f x
        | Error e -> Error e

    let map f = bind (f >> Ok)

    let mapError f result =
        match result with
        | Ok x -> Ok x
        | Error e -> Error (f e)

// Computation expression for container operations
type ContainerBuilder() =
    member _.Bind(x, f) = Result.bind f x
    member _.Return(x) = Ok x
    member _.ReturnFrom(x) = x
    member _.Zero() = Ok ()

let container = ContainerBuilder()

// Usage example
let createAndStart spec =
    container {
        let! id = ContainerClient.create spec
        let! _ = ContainerClient.start id
        return id
    }
```

### 3.3 Safety Constraints as Code

```fsharp
// STAMP constraint validation
module SafetyConstraints =

    /// SC-POD-001: Container SHALL validate image before creation
    let validateImageBeforeCreate (spec: SpecGenerator) : Result<SpecGenerator, SafetyViolation> =
        if String.IsNullOrWhiteSpace spec.Image then
            Error { Code = "SC-POD-001"; Message = "Image must be specified" }
        else
            Ok spec

    /// SC-POD-002: Container SHALL have resource limits defined
    let validateResourceLimits (spec: SpecGenerator) : Result<SpecGenerator, SafetyViolation> =
        match spec.ResourceLimits with
        | None -> Error { Code = "SC-POD-002"; Message = "Resource limits required" }
        | Some limits when limits.Memory.IsNone && limits.CPU.IsNone ->
            Error { Code = "SC-POD-002"; Message = "At least one limit required" }
        | Some _ -> Ok spec

    /// Compose all safety validations
    let validateSpec (spec: SpecGenerator) =
        spec
        |> validateImageBeforeCreate
        |> Result.bind validateResourceLimits
        |> Result.bind validateHealthConfig
        // ... additional constraints
```

---

## 4. Module Structure

### 4.1 Project Layout

```
lib/cepaf/src/Cepaf.Modules.Podman/
├── Cepaf.Modules.Podman.fsproj
├── AssemblyInfo.fs
│
├── Domain/                          # Core domain types
│   ├── Types.fs                     # Base types and primitives
│   ├── Container.fs                 # Container domain model
│   ├── Pod.fs                       # Pod domain model
│   ├── Image.fs                     # Image domain model
│   ├── Volume.fs                    # Volume domain model
│   ├── Network.fs                   # Network domain model
│   ├── System.fs                    # System/Engine domain model
│   └── Errors.fs                    # Error types and codes
│
├── Api/                             # REST API bindings
│   ├── HttpClient.fs                # HTTP transport layer
│   ├── SocketConnector.fs           # Unix socket connector
│   ├── Serialization.fs             # JSON serialization
│   ├── Endpoints/
│   │   ├── ContainerEndpoints.fs
│   │   ├── PodEndpoints.fs
│   │   ├── ImageEndpoints.fs
│   │   ├── VolumeEndpoints.fs
│   │   ├── NetworkEndpoints.fs
│   │   ├── SystemEndpoints.fs
│   │   ├── ExecEndpoints.fs
│   │   └── KubeEndpoints.fs
│   └── Clients/
│       ├── ContainerClient.fs
│       ├── PodClient.fs
│       ├── ImageClient.fs
│       ├── VolumeClient.fs
│       ├── NetworkClient.fs
│       ├── SystemClient.fs
│       └── KubeClient.fs
│
├── Lifecycle/                       # Lifecycle management
│   ├── StateMachine.fs              # State machine definitions
│   ├── TransitionExecutor.fs        # State transition logic
│   ├── ContainerLifecycle.fs        # Container lifecycle ops
│   ├── PodLifecycle.fs              # Pod lifecycle ops
│   └── Orchestrator.fs              # Multi-resource orchestration
│
├── Ooda/                            # OODA control loop
│   ├── Observer.fs                  # Observation phase
│   ├── Orientator.fs                # Orientation phase
│   ├── Decider.fs                   # Decision phase
│   ├── Actuator.fs                  # Action phase
│   └── ControlLoop.fs               # Loop orchestration
│
├── Health/                          # Health monitoring
│   ├── HealthChecker.fs             # Health check execution
│   ├── ProbeTypes.fs                # Probe definitions
│   ├── MetricsCollector.fs          # Metrics gathering
│   └── AlertManager.fs              # Alert generation
│
├── Recovery/                        # Error recovery
│   ├── FailureDetector.fs           # Failure detection
│   ├── RecoveryPlanner.fs           # Recovery planning
│   ├── RecoveryExecutor.fs          # Recovery execution
│   └── CircuitBreaker.fs            # Circuit breaker pattern
│
├── Safety/                          # STAMP compliance
│   ├── Constraints.fs               # Safety constraint definitions
│   ├── Validator.fs                 # Constraint validation
│   ├── Interceptor.fs               # Request/response interceptors
│   └── AuditLog.fs                  # Safety audit logging
│
├── Utils/                           # Utilities
│   ├── Async.fs                     # Async helpers
│   ├── Result.fs                    # Result helpers
│   ├── Retry.fs                     # Retry policies
│   └── Logging.fs                   # Structured logging
│
└── PublicApi.fs                     # Public API surface
```

### 4.2 Dependency Graph

```
PublicApi
    │
    ├── Ooda.ControlLoop
    │       ├── Ooda.Observer ──────► Api.Clients.*
    │       ├── Ooda.Orientator ────► Domain.*
    │       ├── Ooda.Decider ───────► Safety.Constraints
    │       └── Ooda.Actuator ──────► Lifecycle.*
    │
    ├── Lifecycle.Orchestrator
    │       ├── Lifecycle.ContainerLifecycle
    │       ├── Lifecycle.PodLifecycle
    │       └── Lifecycle.TransitionExecutor ──► Api.Clients.*
    │
    ├── Health.HealthChecker ──────► Api.Clients.SystemClient
    │
    ├── Recovery.RecoveryExecutor
    │       ├── Recovery.FailureDetector
    │       └── Recovery.RecoveryPlanner
    │
    └── Safety.Validator ──────► Safety.Constraints
```

### 4.3 Namespace Hierarchy

```fsharp
namespace Cepaf.Modules.Podman

// Domain types
namespace Cepaf.Modules.Podman.Domain

// API clients
namespace Cepaf.Modules.Podman.Api
namespace Cepaf.Modules.Podman.Api.Clients
namespace Cepaf.Modules.Podman.Api.Endpoints

// Lifecycle management
namespace Cepaf.Modules.Podman.Lifecycle

// OODA control
namespace Cepaf.Modules.Podman.Ooda

// Health monitoring
namespace Cepaf.Modules.Podman.Health

// Recovery
namespace Cepaf.Modules.Podman.Recovery

// Safety
namespace Cepaf.Modules.Podman.Safety
```

---

## 5. Core Types & Domain Model

### 5.1 Base Types

```fsharp
namespace Cepaf.Modules.Podman.Domain

open System

/// Container identifier (64-character hex string)
[<Struct>]
type ContainerId = ContainerId of string

/// Pod identifier
[<Struct>]
type PodId = PodId of string

/// Image identifier (sha256 digest or tag)
[<Struct>]
type ImageId = ImageId of string

/// Volume name
[<Struct>]
type VolumeName = VolumeName of string

/// Network name
[<Struct>]
type NetworkName = NetworkName of string

/// Unix timestamp
[<Struct>]
type UnixTimestamp = UnixTimestamp of int64

module ContainerId =
    let create (s: string) =
        if String.IsNullOrWhiteSpace s then
            Error "Container ID cannot be empty"
        elif s.Length < 12 then
            Error "Container ID must be at least 12 characters"
        else
            Ok (ContainerId s)

    let value (ContainerId id) = id
    let short (ContainerId id) = id.Substring(0, min 12 id.Length)
```

### 5.2 Container State Machine

```fsharp
/// Container lifecycle states (from ontology)
type ContainerState =
    | Absent          // Container does not exist
    | Created         // Created but not started
    | Running         // Actively executing
    | Paused          // Execution suspended
    | Stopped         // Execution terminated
    | Dead            // Unrecoverable failure
    | Removing        // Being deleted

/// State transition events
type ContainerEvent =
    | Create of SpecGenerator
    | Start
    | Stop of timeout: TimeSpan option
    | Kill of signal: Signal
    | Pause
    | Unpause
    | Restart of timeout: TimeSpan option
    | Remove of force: bool * volumes: bool
    | Die of exitCode: int

/// Transition result
type TransitionResult =
    | Success of newState: ContainerState
    | InvalidTransition of current: ContainerState * event: ContainerEvent
    | TransitionFailed of error: PodmanError

/// State machine definition
module ContainerStateMachine =

    let transitions = Map.ofList [
        (Absent, Create _), Created
        (Created, Start), Running
        (Created, Remove _), Absent
        (Running, Stop _), Stopped
        (Running, Kill _), Stopped
        (Running, Pause), Paused
        (Running, Die _), Dead
        (Paused, Unpause), Running
        (Paused, Stop _), Stopped
        (Paused, Kill _), Stopped
        (Stopped, Start), Running
        (Stopped, Remove _), Absent
        (Stopped, Restart _), Running
        (Dead, Remove _), Absent
    ]

    let canTransition state event =
        transitions |> Map.containsKey (state, event)

    let getNextState state event =
        transitions
        |> Map.tryFind (state, event)
        |> Option.map (fun s -> Success s)
        |> Option.defaultValue (InvalidTransition (state, event))
```

### 5.3 Container Specification

```fsharp
/// Port mapping specification
type PortMapping = {
    ContainerPort: uint16
    HostPort: uint16 option
    HostIP: string option
    Protocol: Protocol
    Range: uint16
}

and Protocol = TCP | UDP | SCTP

/// Resource limits
type ResourceLimits = {
    Memory: int64 option           // Bytes
    MemorySwap: int64 option       // Bytes
    MemorySwappiness: int64 option // 0-100
    CPUShares: uint64 option
    CPUPeriod: uint64 option       // Microseconds
    CPUQuota: int64 option         // Microseconds
    CPUSetCPUs: string option      // "0-3" or "0,1"
    CPUSetMems: string option
    PidsLimit: int64 option
    BlkioWeight: uint16 option     // 10-1000
}

/// Health check configuration
type HealthConfig = {
    Test: string list
    Interval: TimeSpan
    Timeout: TimeSpan
    Retries: int
    StartPeriod: TimeSpan
}

/// Container specification (SpecGenerator equivalent)
type ContainerSpec = {
    Name: string option
    Image: string
    Command: string list option
    Entrypoint: string list option
    WorkDir: string option
    Env: Map<string, string>
    Labels: Map<string, string>
    Annotations: Map<string, string>
    PortMappings: PortMapping list
    ResourceLimits: ResourceLimits option
    HealthConfig: HealthConfig option
    RestartPolicy: RestartPolicy option
    User: string option
    Groups: string list
    Mounts: Mount list
    Volumes: VolumeMount list
    Networks: NetworkAttachment list
    CapAdd: Capability list
    CapDrop: Capability list
    Privileged: bool
    ReadOnly: bool
    SecurityOpt: string list
    Stdin: bool
    Tty: bool
    Remove: bool              // --rm flag
}

and RestartPolicy =
    | No
    | Always
    | OnFailure of maxRetries: int
    | UnlessStopped

and Mount = {
    Type: MountType
    Source: string
    Destination: string
    Options: string list
}

and MountType = Bind | Volume | Tmpfs | Devpts

and VolumeMount = {
    Name: string
    Dest: string
    Options: string list
}

and NetworkAttachment = {
    Name: string
    Aliases: string list
    IPAddress: string option
    MacAddress: string option
}

and Capability =
    | CAP_CHOWN | CAP_DAC_OVERRIDE | CAP_FSETID | CAP_FOWNER
    | CAP_MKNOD | CAP_NET_RAW | CAP_SETGID | CAP_SETUID
    | CAP_SETFCAP | CAP_SETPCAP | CAP_NET_BIND_SERVICE
    | CAP_SYS_CHROOT | CAP_KILL | CAP_AUDIT_WRITE
    // ... additional capabilities
```

### 5.4 Container Info (Runtime State)

```fsharp
/// Container runtime information
type ContainerInfo = {
    Id: ContainerId
    Names: string list
    Image: string
    ImageId: ImageId
    Command: string list
    Created: DateTimeOffset
    State: ContainerState
    Status: string                // Human-readable status
    Ports: PortBinding list
    Labels: Map<string, string>
    Mounts: MountInfo list
    Networks: Map<string, NetworkInfo>
    SizeRw: int64 option
    SizeRootFs: int64 option
    Pod: PodId option
    PodName: string option
    ExitCode: int
    Started: DateTimeOffset option
    Finished: DateTimeOffset option
    Health: HealthStatus option
    Pid: int
    RestartCount: int
}

and PortBinding = {
    ContainerPort: uint16
    Protocol: Protocol
    HostBindings: HostBinding list
}

and HostBinding = {
    HostIP: string
    HostPort: uint16
}

and MountInfo = {
    Type: MountType
    Name: string option
    Source: string
    Destination: string
    Driver: string option
    Mode: string
    RW: bool
    Propagation: string
}

and NetworkInfo = {
    NetworkId: string
    EndpointId: string
    Gateway: string
    IPAddress: string
    IPPrefixLen: int
    MacAddress: string
    Aliases: string list
}

and HealthStatus =
    | Starting
    | Healthy
    | Unhealthy of failingStreak: int * log: HealthLogEntry list
    | NoHealthcheck

and HealthLogEntry = {
    Start: DateTimeOffset
    End: DateTimeOffset
    ExitCode: int
    Output: string
}
```

### 5.5 Pod Types

```fsharp
/// Pod state machine
type PodState =
    | Created
    | Running
    | Paused
    | Stopped
    | Exited
    | Dead

/// Pod specification
type PodSpec = {
    Name: string option
    Hostname: string option
    InfraContainerSpec: ContainerSpec option
    ShareNamespaces: Namespace list
    PortMappings: PortMapping list
    Networks: NetworkAttachment list
    Labels: Map<string, string>
    CgroupParent: string option
    DNSServer: string list
    DNSSearch: string list
    DNSOption: string list
    HostAdd: Map<string, string>  // hostname -> IP
    NoInfra: bool
    PidNS: NamespaceMode option
}

and Namespace = PID | NET | IPC | UTS | USER | CGROUP

and NamespaceMode =
    | Private
    | Host
    | Container of ContainerId
    | Pod

/// Pod runtime info
type PodInfo = {
    Id: PodId
    Name: string
    State: PodState
    Created: DateTimeOffset
    Labels: Map<string, string>
    Containers: ContainerInfo list
    InfraContainerId: ContainerId option
    SharedNamespaces: Namespace list
    NumContainers: int
    CgroupPath: string option
}
```

### 5.6 Error Types

```fsharp
/// Error domain
type PodmanError =
    // Connection errors
    | ConnectionFailed of endpoint: string * inner: exn
    | ConnectionTimeout of endpoint: string * timeout: TimeSpan
    | SocketNotFound of path: string

    // API errors
    | ApiError of statusCode: int * message: string * details: string option
    | NotFound of resourceType: string * id: string
    | Conflict of resourceType: string * id: string * reason: string
    | BadRequest of message: string
    | InternalServerError of message: string

    // Validation errors
    | ValidationError of field: string * message: string
    | SafetyViolation of constraint_: SafetyConstraint

    // State errors
    | InvalidState of current: string * expected: string list
    | TransitionFailed of from: string * to_: string * reason: string

    // Resource errors
    | ImageNotFound of reference: string
    | VolumeInUse of name: string * containers: string list
    | NetworkInUse of name: string * containers: string list

    // Operation errors
    | OperationTimeout of operation: string * timeout: TimeSpan
    | OperationCancelled of operation: string
    | ExecFailed of containerId: string * exitCode: int * stderr: string

and SafetyConstraint = {
    Code: string      // e.g., "SC-POD-001"
    Message: string
    Severity: Severity
}

and Severity = Critical | High | Medium | Low

module PodmanError =
    let isRetryable = function
        | ConnectionFailed _ | ConnectionTimeout _ -> true
        | ApiError (statusCode, _, _) when statusCode >= 500 -> true
        | OperationTimeout _ -> true
        | _ -> false

    let toExitCode = function
        | NotFound _ -> 1
        | ValidationError _ -> 2
        | SafetyViolation _ -> 3
        | ApiError (code, _, _) -> code
        | _ -> 125
```

---

## 6. API Client Layer

### 6.1 HTTP Transport

```fsharp
namespace Cepaf.Modules.Podman.Api

open System
open System.Net
open System.Net.Http
open System.Net.Sockets

/// HTTP client configuration
type HttpClientConfig = {
    BaseUri: Uri
    Timeout: TimeSpan
    MaxConnections: int
    KeepAlive: bool
    UserAgent: string
}

/// Unix socket HTTP handler
type UnixSocketHandler(socketPath: string) =
    inherit HttpMessageHandler()

    let endpoint = UnixDomainSocketEndPoint(socketPath)

    override this.SendAsync(request, cancellationToken) =
        async {
            use socket = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified)
            do! socket.ConnectAsync(endpoint) |> Async.AwaitTask

            use stream = new NetworkStream(socket, true)

            // Send HTTP request
            let! _ = this.WriteRequestAsync(stream, request)

            // Read HTTP response
            return! this.ReadResponseAsync(stream, request)
        } |> Async.StartAsTask

/// Podman HTTP client
type PodmanHttpClient(config: HttpClientConfig, handler: HttpMessageHandler option) =

    let httpClient =
        let h = handler |> Option.defaultWith (fun () -> new HttpClientHandler() :> HttpMessageHandler)
        new HttpClient(h, disposeHandler = true)

    do
        httpClient.BaseAddress <- config.BaseUri
        httpClient.Timeout <- config.Timeout
        httpClient.DefaultRequestHeaders.Add("User-Agent", config.UserAgent)

    member _.GetAsync(path: string) =
        async {
            let! response = httpClient.GetAsync(path) |> Async.AwaitTask
            return! this.ProcessResponse(response)
        }

    member _.PostAsync(path: string, content: HttpContent option) =
        async {
            let! response =
                match content with
                | Some c -> httpClient.PostAsync(path, c)
                | None -> httpClient.PostAsync(path, null)
                |> Async.AwaitTask
            return! this.ProcessResponse(response)
        }

    member _.DeleteAsync(path: string) =
        async {
            let! response = httpClient.DeleteAsync(path) |> Async.AwaitTask
            return! this.ProcessResponse(response)
        }

    member private _.ProcessResponse(response: HttpResponseMessage) =
        async {
            let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            if response.IsSuccessStatusCode then
                return Ok body
            else
                let error =
                    match int response.StatusCode with
                    | 404 -> NotFound ("resource", body)
                    | 409 -> Conflict ("resource", "", body)
                    | 400 -> BadRequest body
                    | code -> ApiError (code, response.ReasonPhrase, Some body)
                return Error error
        }

    interface IDisposable with
        member _.Dispose() = httpClient.Dispose()
```

### 6.2 Container Client

```fsharp
namespace Cepaf.Modules.Podman.Api.Clients

open Cepaf.Modules.Podman.Domain
open Cepaf.Modules.Podman.Api

/// Container API client
type ContainerClient(http: PodmanHttpClient, safety: SafetyValidator) =

    /// List containers
    member _.List(?all: bool, ?filters: Map<string, string list>) : Async<Result<ContainerInfo list, PodmanError>> =
        async {
            let queryParams =
                [ if all = Some true then "all", "true"
                  match filters with
                  | Some f ->
                      for kvp in f do
                          "filters", sprintf """{"$s":[%s]}""" kvp.Key (String.concat "," (kvp.Value |> List.map (sprintf "\"%s\"")))
                  | None -> () ]
                |> List.map (fun (k, v) -> sprintf "%s=%s" k v)
                |> String.concat "&"

            let path = sprintf "/v5.0.0/libpod/containers/json?%s" queryParams
            let! result = http.GetAsync(path)

            return result |> Result.bind Serialization.deserializeList<ContainerInfo>
        }

    /// Inspect container
    member _.Inspect(id: ContainerId, ?size: bool) : Async<Result<ContainerInspect, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let sizeParam = if size = Some true then "?size=true" else ""
            let path = sprintf "/v5.0.0/libpod/containers/%s/json%s" idStr sizeParam

            let! result = http.GetAsync(path)
            return result |> Result.bind Serialization.deserialize<ContainerInspect>
        }

    /// Create container
    member _.Create(spec: ContainerSpec) : Async<Result<ContainerId, PodmanError>> =
        async {
            // Validate safety constraints first
            match safety.Validate(spec) with
            | Error e -> return Error (SafetyViolation e)
            | Ok validSpec ->
                let json = Serialization.serialize validSpec
                let content = new StringContent(json, Encoding.UTF8, "application/json")

                let! result = http.PostAsync("/v5.0.0/libpod/containers/create", Some content)

                return result |> Result.bind (fun body ->
                    Serialization.deserialize<{| Id: string |}>(body)
                    |> Result.map (fun r -> ContainerId r.Id)
                )
        }

    /// Start container
    member _.Start(id: ContainerId, ?detachKeys: string) : Async<Result<unit, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let query =
                match detachKeys with
                | Some k -> sprintf "?detachKeys=%s" k
                | None -> ""

            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/containers/%s/start%s" idStr query, None)
            return result |> Result.map ignore
        }

    /// Stop container
    member _.Stop(id: ContainerId, ?timeout: int) : Async<Result<unit, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let query =
                match timeout with
                | Some t -> sprintf "?timeout=%d" t
                | None -> ""

            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/containers/%s/stop%s" idStr query, None)
            return result |> Result.map ignore
        }

    /// Kill container
    member _.Kill(id: ContainerId, ?signal: Signal) : Async<Result<unit, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let sig = signal |> Option.map Signal.toString |> Option.defaultValue "SIGTERM"

            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/containers/%s/kill?signal=%s" idStr sig, None)
            return result |> Result.map ignore
        }

    /// Remove container
    member _.Remove(id: ContainerId, ?force: bool, ?volumes: bool) : Async<Result<unit, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let query =
                [ if force = Some true then "force", "true"
                  if volumes = Some true then "v", "true" ]
                |> List.map (fun (k, v) -> sprintf "%s=%s" k v)
                |> String.concat "&"
                |> fun q -> if q.Length > 0 then "?" + q else ""

            let! result = http.DeleteAsync(sprintf "/v5.0.0/libpod/containers/%s%s" idStr query)
            return result |> Result.map ignore
        }

    /// Get container logs
    member _.Logs(id: ContainerId, ?follow: bool, ?stdout: bool, ?stderr: bool, ?since: DateTimeOffset, ?until: DateTimeOffset, ?tail: int) : Async<Result<string seq, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let query =
                [ if follow = Some true then "follow", "true"
                  if stdout <> Some false then "stdout", "true"
                  if stderr <> Some false then "stderr", "true"
                  match since with Some s -> "since", s.ToUnixTimeSeconds().ToString() | None -> ()
                  match until with Some u -> "until", u.ToUnixTimeSeconds().ToString() | None -> ()
                  match tail with Some t -> "tail", t.ToString() | None -> () ]
                |> List.map (fun (k, v) -> sprintf "%s=%s" k v)
                |> String.concat "&"

            let! result = http.GetAsync(sprintf "/v5.0.0/libpod/containers/%s/logs?%s" idStr query)
            return result |> Result.map (fun body -> body.Split('\n') |> Seq.ofArray)
        }

    /// Wait for container
    member _.Wait(id: ContainerId, ?condition: WaitCondition) : Async<Result<int, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let cond = condition |> Option.map WaitCondition.toString |> Option.defaultValue "stopped"

            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/containers/%s/wait?condition=%s" idStr cond, None)

            return result |> Result.bind (fun body ->
                Serialization.deserialize<{| StatusCode: int |}>(body)
                |> Result.map (fun r -> r.StatusCode)
            )
        }

    /// Get container stats
    member _.Stats(id: ContainerId, ?stream: bool) : Async<Result<ContainerStats, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let query = if stream = Some true then "?stream=true" else ""

            let! result = http.GetAsync(sprintf "/v5.0.0/libpod/containers/%s/stats%s" idStr query)
            return result |> Result.bind Serialization.deserialize<ContainerStats>
        }

    /// Execute command in container
    member _.Exec(id: ContainerId, config: ExecConfig) : Async<Result<ExecResult, PodmanError>> =
        async {
            let idStr = ContainerId.value id
            let json = Serialization.serialize config
            let content = new StringContent(json, Encoding.UTF8, "application/json")

            // Create exec instance
            let! createResult = http.PostAsync(sprintf "/v5.0.0/libpod/containers/%s/exec" idStr, Some content)

            match createResult with
            | Error e -> return Error e
            | Ok body ->
                let execId = (Serialization.deserialize<{| Id: string |}> body).Id

                // Start exec
                let startConfig = {| Detach = config.Detach; Tty = config.Tty |}
                let startContent = new StringContent(Serialization.serialize startConfig, Encoding.UTF8, "application/json")

                let! startResult = http.PostAsync(sprintf "/v5.0.0/libpod/exec/%s/start" execId, Some startContent)

                return startResult |> Result.map (fun output ->
                    { ExecId = execId; Output = output; ExitCode = 0 }
                )
        }

and WaitCondition =
    | Configured
    | Created
    | Running
    | Stopped
    | Paused
    | Exited
    | Removing
    | Stopping

and ExecConfig = {
    Cmd: string list
    AttachStderr: bool
    AttachStdin: bool
    AttachStdout: bool
    DetachKeys: string option
    Env: Map<string, string>
    Privileged: bool
    Tty: bool
    User: string option
    WorkingDir: string option
    Detach: bool
}

and ExecResult = {
    ExecId: string
    Output: string
    ExitCode: int
}

and ContainerStats = {
    ContainerId: string
    Name: string
    CPUPercentage: float
    MemUsage: int64
    MemLimit: int64
    MemPercentage: float
    NetInput: int64
    NetOutput: int64
    BlockInput: int64
    BlockOutput: int64
    PIDs: int64
}
```

### 6.3 Pod Client

```fsharp
/// Pod API client
type PodClient(http: PodmanHttpClient) =

    /// List pods
    member _.List(?filters: Map<string, string list>) : Async<Result<PodInfo list, PodmanError>> =
        async {
            let path = "/v5.0.0/libpod/pods/json"
            let! result = http.GetAsync(path)
            return result |> Result.bind Serialization.deserializeList<PodInfo>
        }

    /// Create pod
    member _.Create(spec: PodSpec) : Async<Result<PodId, PodmanError>> =
        async {
            let json = Serialization.serialize spec
            let content = new StringContent(json, Encoding.UTF8, "application/json")

            let! result = http.PostAsync("/v5.0.0/libpod/pods/create", Some content)

            return result |> Result.bind (fun body ->
                Serialization.deserialize<{| Id: string |}>(body)
                |> Result.map (fun r -> PodId r.Id)
            )
        }

    /// Start pod
    member _.Start(id: PodId) : Async<Result<unit, PodmanError>> =
        async {
            let (PodId idStr) = id
            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/pods/%s/start" idStr, None)
            return result |> Result.map ignore
        }

    /// Stop pod
    member _.Stop(id: PodId, ?timeout: int) : Async<Result<unit, PodmanError>> =
        async {
            let (PodId idStr) = id
            let query = timeout |> Option.map (sprintf "?t=%d") |> Option.defaultValue ""
            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/pods/%s/stop%s" idStr query, None)
            return result |> Result.map ignore
        }

    /// Remove pod
    member _.Remove(id: PodId, ?force: bool) : Async<Result<unit, PodmanError>> =
        async {
            let (PodId idStr) = id
            let query = if force = Some true then "?force=true" else ""
            let! result = http.DeleteAsync(sprintf "/v5.0.0/libpod/pods/%s%s" idStr query)
            return result |> Result.map ignore
        }

    /// Play Kubernetes YAML
    member _.PlayKube(yaml: string, ?network: string, ?start: bool) : Async<Result<KubePlayReport, PodmanError>> =
        async {
            let query =
                [ match network with Some n -> "network", n | None -> ()
                  if start = Some false then "start", "false" ]
                |> List.map (fun (k, v) -> sprintf "%s=%s" k v)
                |> String.concat "&"
                |> fun q -> if q.Length > 0 then "?" + q else ""

            let content = new StringContent(yaml, Encoding.UTF8, "application/yaml")
            let! result = http.PostAsync(sprintf "/v5.0.0/libpod/play/kube%s" query, Some content)

            return result |> Result.bind Serialization.deserialize<KubePlayReport>
        }

and KubePlayReport = {
    Pods: KubePodReport list
    Volumes: string list
}

and KubePodReport = {
    Id: string
    Containers: string list
    InitContainers: string list
    Logs: string list
}
```

---

## 7. Lifecycle Management

### 7.1 State Machine Executor

```fsharp
namespace Cepaf.Modules.Podman.Lifecycle

open Cepaf.Modules.Podman.Domain
open Cepaf.Modules.Podman.Api.Clients

/// State transition executor
type TransitionExecutor(containerClient: ContainerClient, podClient: PodClient) =

    /// Execute container state transition
    member _.ExecuteContainerTransition(id: ContainerId, event: ContainerEvent) : Async<Result<ContainerState, PodmanError>> =
        async {
            // Get current state
            let! inspectResult = containerClient.Inspect(id)

            match inspectResult with
            | Error e -> return Error e
            | Ok info ->
                let currentState = info.State

                // Validate transition
                match ContainerStateMachine.getNextState currentState event with
                | InvalidTransition (curr, evt) ->
                    return Error (InvalidState (string curr, [string (ContainerStateMachine.getNextState curr evt)]))
                | TransitionFailed e ->
                    return Error e
                | Success expectedState ->
                    // Execute the action
                    let! actionResult =
                        match event with
                        | Create spec ->
                            containerClient.Create(spec)
                            |> Async.map (Result.map (fun _ -> Created))
                        | Start ->
                            containerClient.Start(id)
                            |> Async.map (Result.map (fun _ -> Running))
                        | Stop timeout ->
                            containerClient.Stop(id, ?timeout = Option.map int timeout)
                            |> Async.map (Result.map (fun _ -> Stopped))
                        | Kill signal ->
                            containerClient.Kill(id, signal = signal)
                            |> Async.map (Result.map (fun _ -> Stopped))
                        | Pause ->
                            containerClient.Pause(id)
                            |> Async.map (Result.map (fun _ -> Paused))
                        | Unpause ->
                            containerClient.Unpause(id)
                            |> Async.map (Result.map (fun _ -> Running))
                        | Remove (force, volumes) ->
                            containerClient.Remove(id, force = force, volumes = volumes)
                            |> Async.map (Result.map (fun _ -> Absent))
                        | Restart timeout ->
                            async {
                                let! stopResult = containerClient.Stop(id, ?timeout = Option.map int timeout)
                                match stopResult with
                                | Error e -> return Error e
                                | Ok _ ->
                                    let! startResult = containerClient.Start(id)
                                    return startResult |> Result.map (fun _ -> Running)
                            }
                        | Die exitCode ->
                            async { return Ok Dead }

                    return actionResult
        }

    /// Execute pod state transition
    member _.ExecutePodTransition(id: PodId, event: PodEvent) : Async<Result<PodState, PodmanError>> =
        async {
            match event with
            | PodEvent.Start ->
                let! result = podClient.Start(id)
                return result |> Result.map (fun _ -> PodState.Running)
            | PodEvent.Stop timeout ->
                let! result = podClient.Stop(id, ?timeout = Option.map int timeout)
                return result |> Result.map (fun _ -> PodState.Stopped)
            | PodEvent.Remove force ->
                let! result = podClient.Remove(id, force = force)
                return result |> Result.map (fun _ -> PodState.Exited)
        }
```

### 7.2 Container Lifecycle Manager

```fsharp
/// High-level container lifecycle operations
type ContainerLifecycle(executor: TransitionExecutor, health: HealthChecker) =

    /// Create and start a container
    member _.CreateAndStart(spec: ContainerSpec) : Async<Result<ContainerId * ContainerInfo, PodmanError>> =
        async {
            // Create
            let! createResult = executor.ExecuteContainerTransition(ContainerId "", Create spec)

            match createResult with
            | Error e -> return Error e
            | Ok _ ->
                // Get ID from creation
                let! containers = containerClient.List(all = true, filters = Map.ofList ["name", [spec.Name.Value]])

                match containers with
                | Error e -> return Error e
                | Ok [] -> return Error (NotFound ("container", spec.Name.Value))
                | Ok (container :: _) ->
                    // Start
                    let! startResult = executor.ExecuteContainerTransition(container.Id, Start)

                    match startResult with
                    | Error e -> return Error e
                    | Ok Running ->
                        // Wait for healthy
                        let! healthResult = health.WaitForHealthy(container.Id, TimeSpan.FromMinutes(2.0))

                        match healthResult with
                        | Error e -> return Error e
                        | Ok _ ->
                            let! info = containerClient.Inspect(container.Id)
                            return info |> Result.map (fun i -> (container.Id, i))
                    | Ok state ->
                        return Error (InvalidState (string state, ["Running"]))
        }

    /// Graceful shutdown
    member _.GracefulShutdown(id: ContainerId, ?timeout: TimeSpan) : Async<Result<unit, PodmanError>> =
        async {
            let timeout = timeout |> Option.defaultValue (TimeSpan.FromSeconds(30.0))

            // Send SIGTERM first
            let! stopResult = executor.ExecuteContainerTransition(id, Stop (Some timeout))

            match stopResult with
            | Ok Stopped -> return Ok ()
            | Ok _ -> return Ok ()  // Any stopped state is fine
            | Error e ->
                // If graceful stop failed, force kill
                let! killResult = executor.ExecuteContainerTransition(id, Kill SIGKILL)
                return killResult |> Result.map ignore
        }

    /// Rolling update
    member _.RollingUpdate(oldId: ContainerId, newSpec: ContainerSpec) : Async<Result<ContainerId, PodmanError>> =
        async {
            // Create new container
            let! createResult = this.CreateAndStart(newSpec)

            match createResult with
            | Error e -> return Error e
            | Ok (newId, _) ->
                // Stop old container
                let! stopResult = this.GracefulShutdown(oldId)

                match stopResult with
                | Error e ->
                    // Rollback: stop new container
                    let! _ = this.GracefulShutdown(newId)
                    return Error e
                | Ok _ ->
                    // Remove old container
                    let! removeResult = executor.ExecuteContainerTransition(oldId, Remove (false, false))
                    return removeResult |> Result.map (fun _ -> newId)
        }
```

### 7.3 Orchestrator

```fsharp
/// Multi-resource orchestrator
type Orchestrator(containerLifecycle: ContainerLifecycle, podClient: PodClient, imageClient: ImageClient, volumeClient: VolumeClient, networkClient: NetworkClient) =

    /// Deploy a complete stack from Kubernetes YAML
    member _.DeployKubeStack(yaml: string, ?network: string) : Async<Result<DeploymentResult, PodmanError>> =
        async {
            // Play the YAML
            let! playResult = podClient.PlayKube(yaml, ?network = network)

            match playResult with
            | Error e -> return Error e
            | Ok report ->
                // Wait for all pods to be running
                let! podResults =
                    report.Pods
                    |> List.map (fun p ->
                        async {
                            let podId = PodId p.Id
                            let! info = podClient.Inspect(podId)
                            return (podId, info)
                        })
                    |> Async.Parallel

                let errors =
                    podResults
                    |> Array.choose (function (_, Error e) -> Some e | _ -> None)
                    |> Array.toList

                if not errors.IsEmpty then
                    return Error errors.Head
                else
                    let pods =
                        podResults
                        |> Array.choose (function (id, Ok info) -> Some (id, info) | _ -> None)
                        |> Array.toList

                    return Ok { Pods = pods; Volumes = report.Volumes }
        }

    /// Ensure resources exist
    member _.EnsureResources(resources: ResourceRequirement list) : Async<Result<unit, PodmanError>> =
        async {
            for req in resources do
                let! result =
                    match req with
                    | NetworkRequired (name, config) ->
                        this.EnsureNetwork(name, config)
                    | VolumeRequired (name, config) ->
                        this.EnsureVolume(name, config)
                    | ImageRequired reference ->
                        this.EnsureImage(reference)

                match result with
                | Error e -> return Error e
                | Ok _ -> ()

            return Ok ()
        }

    member private _.EnsureNetwork(name: NetworkName, config: NetworkConfig option) =
        async {
            let! existing = networkClient.Inspect(name)
            match existing with
            | Ok _ -> return Ok ()
            | Error (NotFound _) ->
                let spec = config |> Option.defaultValue NetworkConfig.Default
                return! networkClient.Create({ spec with Name = Some (NetworkName.value name) })
            | Error e -> return Error e
        }

    member private _.EnsureVolume(name: VolumeName, config: VolumeConfig option) =
        async {
            let! existing = volumeClient.Inspect(name)
            match existing with
            | Ok _ -> return Ok ()
            | Error (NotFound _) ->
                let spec = config |> Option.defaultValue VolumeConfig.Default
                return! volumeClient.Create({ spec with Name = Some (VolumeName.value name) })
            | Error e -> return Error e
        }

    member private _.EnsureImage(reference: string) =
        async {
            let! existing = imageClient.Exists(reference)
            match existing with
            | Ok true -> return Ok ()
            | Ok false ->
                return! imageClient.Pull(reference)
            | Error e -> return Error e
        }

and DeploymentResult = {
    Pods: (PodId * PodInfo) list
    Volumes: string list
}

and ResourceRequirement =
    | NetworkRequired of name: NetworkName * config: NetworkConfig option
    | VolumeRequired of name: VolumeName * config: VolumeConfig option
    | ImageRequired of reference: string
```

---

## 8. OODA Control Loop

### 8.1 Observer

```fsharp
namespace Cepaf.Modules.Podman.Ooda

open Cepaf.Modules.Podman.Domain
open Cepaf.Modules.Podman.Api.Clients

/// System observation data
type Observation = {
    Timestamp: DateTimeOffset
    Containers: ContainerInfo list
    Pods: PodInfo list
    SystemInfo: SystemInfo
    DiskUsage: DiskUsage
    Events: PodmanEvent list
}

/// Observer phase
type Observer(containerClient: ContainerClient, podClient: PodClient, systemClient: SystemClient, eventClient: EventClient) =

    let mutable lastEventTime = DateTimeOffset.UtcNow

    /// Observe current system state
    member _.Observe() : Async<Result<Observation, PodmanError>> =
        async {
            // Parallel fetch of all system state
            let! results =
                [ async { return! containerClient.List(all = true) |> Async.map (Result.map ContainersResult) }
                  async { return! podClient.List() |> Async.map (Result.map PodsResult) }
                  async { return! systemClient.Info() |> Async.map (Result.map SystemInfoResult) }
                  async { return! systemClient.DiskUsage() |> Async.map (Result.map DiskUsageResult) }
                  async { return! eventClient.GetSince(lastEventTime) |> Async.map (Result.map EventsResult) } ]
                |> Async.Parallel

            // Collect results
            let errors = results |> Array.choose (function Error e -> Some e | _ -> None)

            if not errors.IsEmpty then
                return Error errors.[0]
            else
                let observation = {
                    Timestamp = DateTimeOffset.UtcNow
                    Containers = results |> Array.pick (function Ok (ContainersResult c) -> Some c | _ -> None)
                    Pods = results |> Array.pick (function Ok (PodsResult p) -> Some p | _ -> None)
                    SystemInfo = results |> Array.pick (function Ok (SystemInfoResult s) -> Some s | _ -> None)
                    DiskUsage = results |> Array.pick (function Ok (DiskUsageResult d) -> Some d | _ -> None)
                    Events = results |> Array.pick (function Ok (EventsResult e) -> Some e | _ -> None)
                }

                lastEventTime <- observation.Timestamp
                return Ok observation
        }

    /// Watch for events
    member _.Watch(handler: PodmanEvent -> unit) : Async<unit> =
        async {
            let! _ = eventClient.Stream(handler)
            return ()
        }

and ObservationResult =
    | ContainersResult of ContainerInfo list
    | PodsResult of PodInfo list
    | SystemInfoResult of SystemInfo
    | DiskUsageResult of DiskUsage
    | EventsResult of PodmanEvent list
```

### 8.2 Orientator

```fsharp
/// Orientation - analyze observation and determine situation
type Orientation = {
    Timestamp: DateTimeOffset
    HealthStatus: Map<ContainerId, HealthAssessment>
    ResourcePressure: ResourcePressure
    Anomalies: Anomaly list
    TrendAnalysis: TrendAnalysis
}

and HealthAssessment =
    | Healthy
    | Degraded of reasons: string list
    | Unhealthy of reasons: string list
    | Unknown

and ResourcePressure = {
    CPUPressure: PressureLevel
    MemoryPressure: PressureLevel
    DiskPressure: PressureLevel
    NetworkPressure: PressureLevel
}

and PressureLevel = Low | Medium | High | Critical

and Anomaly =
    | UnexpectedState of containerId: ContainerId * expected: ContainerState * actual: ContainerState
    | HighRestartCount of containerId: ContainerId * count: int
    | ResourceExhaustion of resource: string * usage: float
    | UnresponsiveContainer of containerId: ContainerId * duration: TimeSpan
    | DiskSpaceWarning of path: string * usedPercent: float

and TrendAnalysis = {
    CPUTrend: Trend
    MemoryTrend: Trend
    RestartTrend: Trend
}

and Trend = Stable | Increasing | Decreasing | Volatile

/// Orientator phase
type Orientator(config: OrientatorConfig) =

    let assessHealth (container: ContainerInfo) =
        match container.Health with
        | Some Healthy -> HealthAssessment.Healthy
        | Some (Unhealthy (streak, _)) when streak > 3 ->
            HealthAssessment.Unhealthy [$"Failed {streak} health checks"]
        | Some (Unhealthy (streak, _)) ->
            HealthAssessment.Degraded [$"Failed {streak} health checks"]
        | None when container.State = Running -> HealthAssessment.Healthy
        | None -> HealthAssessment.Unknown
        | Some Starting -> HealthAssessment.Degraded ["Health check starting"]

    let detectAnomalies (obs: Observation) =
        let restartAnomalies =
            obs.Containers
            |> List.filter (fun c -> c.RestartCount > config.RestartThreshold)
            |> List.map (fun c -> HighRestartCount (c.Id, c.RestartCount))

        let stateAnomalies =
            obs.Containers
            |> List.filter (fun c -> c.State = Dead)
            |> List.map (fun c -> UnexpectedState (c.Id, Running, Dead))

        let diskAnomalies =
            if obs.DiskUsage.UsedPercent > config.DiskThreshold then
                [DiskSpaceWarning ("/", obs.DiskUsage.UsedPercent)]
            else
                []

        restartAnomalies @ stateAnomalies @ diskAnomalies

    let assessResourcePressure (obs: Observation) =
        let cpuPressure =
            let avgCpu = obs.Containers |> List.averageBy (fun c -> c.Stats.CPUPercent)
            if avgCpu > 90.0 then Critical
            elif avgCpu > 70.0 then High
            elif avgCpu > 50.0 then Medium
            else Low

        let memPressure =
            let usedMem = obs.SystemInfo.MemTotal - obs.SystemInfo.MemFree
            let usedPercent = float usedMem / float obs.SystemInfo.MemTotal * 100.0
            if usedPercent > 95.0 then Critical
            elif usedPercent > 85.0 then High
            elif usedPercent > 70.0 then Medium
            else Low

        { CPUPressure = cpuPressure
          MemoryPressure = memPressure
          DiskPressure = if obs.DiskUsage.UsedPercent > 90.0 then Critical else Low
          NetworkPressure = Low }  // TODO: network pressure detection

    /// Orient from observation
    member _.Orient(obs: Observation) : Orientation =
        let healthStatus =
            obs.Containers
            |> List.map (fun c -> (c.Id, assessHealth c))
            |> Map.ofList

        { Timestamp = DateTimeOffset.UtcNow
          HealthStatus = healthStatus
          ResourcePressure = assessResourcePressure obs
          Anomalies = detectAnomalies obs
          TrendAnalysis = analyzeTrends obs }

and OrientatorConfig = {
    RestartThreshold: int
    DiskThreshold: float
    CPUThreshold: float
    MemoryThreshold: float
}
```

### 8.3 Decider

```fsharp
/// Decision - actions to take
type Decision = {
    Timestamp: DateTimeOffset
    Actions: PlannedAction list
    Priority: Priority
    Rationale: string
}

and PlannedAction =
    | RestartContainer of id: ContainerId * reason: string
    | StopContainer of id: ContainerId * reason: string
    | RemoveContainer of id: ContainerId * reason: string
    | PullImage of reference: string * reason: string
    | PruneResources of types: PruneType list
    | ScaleUp of spec: ContainerSpec * count: int
    | ScaleDown of ids: ContainerId list
    | ReconfigureContainer of id: ContainerId * changes: ContainerSpec
    | AlertOperator of severity: Severity * message: string
    | NoAction

and Priority = Immediate | High | Normal | Low | Deferred

and PruneType = Containers | Images | Volumes | Networks | All

/// Decider phase
type Decider(safety: SafetyValidator) =

    let decideSingleAnomaly (anomaly: Anomaly) (orientation: Orientation) : PlannedAction list =
        match anomaly with
        | HighRestartCount (id, count) when count > 10 ->
            [StopContainer (id, $"Excessive restarts: {count}")]
        | HighRestartCount (id, _) ->
            [RestartContainer (id, "High restart count - attempting recovery")]
        | UnexpectedState (id, expected, Dead) ->
            [RestartContainer (id, $"Container died, expected {expected}")]
        | ResourceExhaustion (resource, usage) ->
            [AlertOperator (Critical, $"Resource exhaustion: {resource} at {usage}%")]
        | DiskSpaceWarning (_, usage) when usage > 95.0 ->
            [PruneResources [Images; Containers]
             AlertOperator (High, $"Disk space critical: {usage}%")]
        | DiskSpaceWarning (_, _) ->
            [PruneResources [Images]]
        | _ -> []

    let prioritize (actions: PlannedAction list) (orientation: Orientation) : Priority =
        if orientation.Anomalies |> List.exists (function ResourceExhaustion _ -> true | _ -> false) then
            Immediate
        elif orientation.ResourcePressure.MemoryPressure = Critical then
            Immediate
        elif orientation.Anomalies.Length > 5 then
            High
        elif orientation.Anomalies.Length > 0 then
            Normal
        else
            Low

    /// Decide based on orientation
    member _.Decide(orientation: Orientation) : Decision =
        let actions =
            orientation.Anomalies
            |> List.collect (fun a -> decideSingleAnomaly a orientation)

        // Validate actions against safety constraints
        let validatedActions =
            actions
            |> List.filter (fun action ->
                safety.ValidateAction(action) |> Result.isOk
            )

        { Timestamp = DateTimeOffset.UtcNow
          Actions = validatedActions
          Priority = prioritize validatedActions orientation
          Rationale = $"Responding to {orientation.Anomalies.Length} anomalies" }
```

### 8.4 Actuator

```fsharp
/// Actuator - execute decisions
type Actuator(lifecycle: ContainerLifecycle, orchestrator: Orchestrator, imageClient: ImageClient, systemClient: SystemClient) =

    /// Execute a single action
    member _.Execute(action: PlannedAction) : Async<Result<ActionResult, PodmanError>> =
        async {
            match action with
            | RestartContainer (id, reason) ->
                Logger.info $"Restarting container {ContainerId.short id}: {reason}"
                let! result = lifecycle.Restart(id)
                return result |> Result.map (fun _ -> ActionResult.Success "Container restarted")

            | StopContainer (id, reason) ->
                Logger.info $"Stopping container {ContainerId.short id}: {reason}"
                let! result = lifecycle.GracefulShutdown(id)
                return result |> Result.map (fun _ -> ActionResult.Success "Container stopped")

            | RemoveContainer (id, reason) ->
                Logger.info $"Removing container {ContainerId.short id}: {reason}"
                let! result = lifecycle.Remove(id, force = true)
                return result |> Result.map (fun _ -> ActionResult.Success "Container removed")

            | PullImage (reference, reason) ->
                Logger.info $"Pulling image {reference}: {reason}"
                let! result = imageClient.Pull(reference)
                return result |> Result.map (fun _ -> ActionResult.Success "Image pulled")

            | PruneResources types ->
                Logger.info $"Pruning resources: {types}"
                let! results =
                    types
                    |> List.map (fun t ->
                        match t with
                        | Containers -> systemClient.PruneContainers()
                        | Images -> systemClient.PruneImages()
                        | Volumes -> systemClient.PruneVolumes()
                        | Networks -> systemClient.PruneNetworks()
                        | All -> systemClient.SystemPrune()
                    )
                    |> Async.Parallel

                let errors = results |> Array.choose (function Error e -> Some e | _ -> None)
                if errors.Length > 0 then
                    return Error errors.[0]
                else
                    return Ok (ActionResult.Success "Resources pruned")

            | AlertOperator (severity, message) ->
                Logger.warn $"ALERT [{severity}]: {message}"
                // TODO: send alert to monitoring system
                return Ok (ActionResult.Success "Alert sent")

            | NoAction ->
                return Ok (ActionResult.NoActionNeeded)

            | action ->
                Logger.warn $"Unhandled action: {action}"
                return Ok (ActionResult.NotImplemented)
        }

    /// Execute all actions in a decision
    member _.ExecuteDecision(decision: Decision) : Async<Result<ActionResult list, PodmanError>> =
        async {
            let! results =
                decision.Actions
                |> List.map this.Execute
                |> Async.Sequential

            let errors = results |> List.choose (function Error e -> Some e | _ -> None)
            if not errors.IsEmpty then
                return Error errors.Head
            else
                return Ok (results |> List.choose (function Ok r -> Some r | _ -> None))
        }

and ActionResult =
    | Success of message: string
    | PartialSuccess of succeeded: int * failed: int
    | NoActionNeeded
    | NotImplemented
```

### 8.5 Control Loop

```fsharp
/// OODA control loop coordinator
type OodaControlLoop(observer: Observer, orientator: Orientator, decider: Decider, actuator: Actuator, config: OodaConfig) =

    let mutable running = false
    let mutable lastCycle = DateTimeOffset.MinValue

    /// Single OODA cycle
    member _.RunCycle() : Async<Result<CycleResult, PodmanError>> =
        async {
            let cycleStart = DateTimeOffset.UtcNow

            // OBSERVE
            let! obsResult = observer.Observe()
            match obsResult with
            | Error e -> return Error e
            | Ok observation ->
                // ORIENT
                let orientation = orientator.Orient(observation)

                // DECIDE
                let decision = decider.Decide(orientation)

                // ACT (if needed)
                let! actResult =
                    if decision.Actions.IsEmpty then
                        async { return Ok [] }
                    else
                        actuator.ExecuteDecision(decision)

                match actResult with
                | Error e -> return Error e
                | Ok results ->
                    lastCycle <- DateTimeOffset.UtcNow
                    return Ok {
                        CycleStart = cycleStart
                        CycleEnd = lastCycle
                        Observation = observation
                        Orientation = orientation
                        Decision = decision
                        ActionResults = results
                    }
        }

    /// Start continuous control loop
    member _.Start() : Async<unit> =
        async {
            running <- true
            Logger.info "OODA control loop started"

            while running do
                try
                    let! result = this.RunCycle()
                    match result with
                    | Ok cycle ->
                        Logger.debug $"OODA cycle completed in {(cycle.CycleEnd - cycle.CycleStart).TotalMilliseconds}ms"
                    | Error e ->
                        Logger.error $"OODA cycle failed: {e}"
                with ex ->
                    Logger.error $"OODA cycle exception: {ex.Message}"

                // Wait for next cycle
                do! Async.Sleep(int config.CycleInterval.TotalMilliseconds)
        }

    /// Stop control loop
    member _.Stop() =
        running <- false
        Logger.info "OODA control loop stopped"

and OodaConfig = {
    CycleInterval: TimeSpan
    MaxConcurrentActions: int
    ActionTimeout: TimeSpan
}

and CycleResult = {
    CycleStart: DateTimeOffset
    CycleEnd: DateTimeOffset
    Observation: Observation
    Orientation: Orientation
    Decision: Decision
    ActionResults: ActionResult list
}
```

---

## 9. Error Handling & Recovery

### 9.1 Circuit Breaker

```fsharp
namespace Cepaf.Modules.Podman.Recovery

open System

type CircuitState = Closed | Open | HalfOpen

type CircuitBreaker(config: CircuitBreakerConfig) =

    let mutable state = Closed
    let mutable failureCount = 0
    let mutable lastFailure = DateTimeOffset.MinValue
    let mutable successCount = 0

    member _.State = state

    member _.Execute<'T>(operation: Async<Result<'T, PodmanError>>) : Async<Result<'T, PodmanError>> =
        async {
            match state with
            | Open ->
                // Check if we should try half-open
                if DateTimeOffset.UtcNow - lastFailure > config.ResetTimeout then
                    state <- HalfOpen
                    return! this.ExecuteWithTracking(operation)
                else
                    return Error (ConnectionFailed ("Circuit breaker open", null))

            | HalfOpen ->
                return! this.ExecuteWithTracking(operation)

            | Closed ->
                return! this.ExecuteWithTracking(operation)
        }

    member private _.ExecuteWithTracking(operation: Async<Result<'T, PodmanError>>) =
        async {
            try
                let! result = operation

                match result with
                | Ok value ->
                    this.RecordSuccess()
                    return Ok value
                | Error e when PodmanError.isRetryable e ->
                    this.RecordFailure()
                    return Error e
                | Error e ->
                    // Non-retryable errors don't affect circuit state
                    return Error e
            with ex ->
                this.RecordFailure()
                return Error (ConnectionFailed ("Operation failed", ex))
        }

    member private _.RecordSuccess() =
        match state with
        | HalfOpen ->
            successCount <- successCount + 1
            if successCount >= config.SuccessThreshold then
                state <- Closed
                failureCount <- 0
                successCount <- 0
        | Closed ->
            failureCount <- 0
        | Open -> ()

    member private _.RecordFailure() =
        lastFailure <- DateTimeOffset.UtcNow
        failureCount <- failureCount + 1
        successCount <- 0

        if failureCount >= config.FailureThreshold then
            state <- Open

and CircuitBreakerConfig = {
    FailureThreshold: int
    SuccessThreshold: int
    ResetTimeout: TimeSpan
}
```

### 9.2 Retry Policy

```fsharp
/// Retry policy with exponential backoff
type RetryPolicy(config: RetryConfig) =

    member _.Execute<'T>(operation: Async<Result<'T, PodmanError>>) : Async<Result<'T, PodmanError>> =
        let rec loop attempt =
            async {
                let! result = operation

                match result with
                | Ok value -> return Ok value
                | Error e when PodmanError.isRetryable e && attempt < config.MaxRetries ->
                    let delay = this.CalculateDelay(attempt)
                    Logger.debug $"Retry attempt {attempt + 1}/{config.MaxRetries} after {delay.TotalMilliseconds}ms"
                    do! Async.Sleep(int delay.TotalMilliseconds)
                    return! loop (attempt + 1)
                | Error e -> return Error e
            }

        loop 0

    member private _.CalculateDelay(attempt: int) =
        let baseDelay = config.InitialDelay.TotalMilliseconds
        let exponentialDelay = baseDelay * (2.0 ** float attempt)
        let jitter = Random().NextDouble() * config.JitterFactor * exponentialDelay
        let totalDelay = exponentialDelay + jitter
        let cappedDelay = min totalDelay config.MaxDelay.TotalMilliseconds
        TimeSpan.FromMilliseconds(cappedDelay)

and RetryConfig = {
    MaxRetries: int
    InitialDelay: TimeSpan
    MaxDelay: TimeSpan
    JitterFactor: float
}

module RetryConfig =
    let Default = {
        MaxRetries = 3
        InitialDelay = TimeSpan.FromMilliseconds(100.0)
        MaxDelay = TimeSpan.FromSeconds(30.0)
        JitterFactor = 0.1
    }
```

### 9.3 Recovery Engine

```fsharp
/// Recovery action definitions (from ontology)
type RecoveryAction =
    | RestartContainer of id: ContainerId
    | IncreaseResources of id: ContainerId * memory: int64 option * cpu: float option
    | RecreateContainer of id: ContainerId * spec: ContainerSpec
    | PullImage of reference: string
    | RepairVolume of name: VolumeName
    | ResetNetwork of name: NetworkName
    | EmergencyStop of ids: ContainerId list

/// Failure classification
type FailureClass =
    | Transient       // Retry might help
    | ResourceBound   // Need more resources
    | Configuration   // Fix config and restart
    | Infrastructure  // External issue
    | Permanent       // Needs manual intervention

/// Recovery planner
type RecoveryPlanner() =

    member _.Plan(failure: PodmanError, context: RecoveryContext) : RecoveryPlan =
        let failureClass = this.Classify(failure)
        let actions = this.PlanActions(failureClass, failure, context)

        { Failure = failure
          Classification = failureClass
          Actions = actions
          Timeout = this.EstimateTimeout(actions)
          Fallback = this.PlanFallback(failureClass) }

    member private _.Classify(failure: PodmanError) : FailureClass =
        match failure with
        | ConnectionTimeout _ | OperationTimeout _ -> Transient
        | ApiError (503, _, _) -> Transient
        | ApiError (500, _, _) -> Transient
        | ApiError (507, _, _) -> ResourceBound  // Insufficient storage
        | ImageNotFound _ -> Configuration
        | NotFound _ -> Permanent
        | SafetyViolation _ -> Permanent
        | _ -> Infrastructure

    member private _.PlanActions(classification: FailureClass, failure: PodmanError, context: RecoveryContext) : RecoveryAction list =
        match classification, failure with
        | Transient, _ ->
            []  // Let retry policy handle it
        | ResourceBound, _ ->
            [IncreaseResources (context.ContainerId, Some (context.CurrentMemory * 2L), None)]
        | Configuration, ImageNotFound ref ->
            [PullImage ref]
        | Configuration, _ ->
            [RecreateContainer (context.ContainerId, context.OriginalSpec)]
        | Infrastructure, _ ->
            [RestartContainer context.ContainerId]
        | Permanent, _ ->
            [EmergencyStop [context.ContainerId]]

    member private _.PlanFallback(classification: FailureClass) : RecoveryAction option =
        match classification with
        | Transient | ResourceBound | Configuration -> Some (EmergencyStop [])
        | _ -> None

    member private _.EstimateTimeout(actions: RecoveryAction list) : TimeSpan =
        let perActionTimeout = TimeSpan.FromSeconds(30.0)
        TimeSpan.FromSeconds(float actions.Length * perActionTimeout.TotalSeconds)

and RecoveryContext = {
    ContainerId: ContainerId
    OriginalSpec: ContainerSpec
    CurrentMemory: int64
    RestartCount: int
    LastRecoveryAttempt: DateTimeOffset option
}

and RecoveryPlan = {
    Failure: PodmanError
    Classification: FailureClass
    Actions: RecoveryAction list
    Timeout: TimeSpan
    Fallback: RecoveryAction option
}

/// Recovery executor
type RecoveryExecutor(lifecycle: ContainerLifecycle, orchestrator: Orchestrator, planner: RecoveryPlanner) =

    member _.Execute(plan: RecoveryPlan) : Async<Result<RecoveryResult, PodmanError>> =
        async {
            let mutable results = []
            let mutable success = true

            for action in plan.Actions do
                if success then
                    let! result = this.ExecuteAction(action)
                    results <- result :: results
                    success <- Result.isOk result

            if success then
                return Ok { Actions = List.rev results; Success = true }
            else
                // Try fallback
                match plan.Fallback with
                | Some fallback ->
                    let! fallbackResult = this.ExecuteAction(fallback)
                    return fallbackResult |> Result.map (fun r -> { Actions = List.rev (r :: results); Success = false })
                | None ->
                    return Error (results |> List.choose (function Error e -> Some e | _ -> None) |> List.head)
        }

    member private _.ExecuteAction(action: RecoveryAction) : Async<Result<ActionResult, PodmanError>> =
        async {
            match action with
            | RestartContainer id ->
                return! lifecycle.Restart(id) |> Async.map (Result.map (fun _ -> ActionResult.Success "Restarted"))
            | PullImage reference ->
                return! orchestrator.EnsureImage(reference) |> Async.map (Result.map (fun _ -> ActionResult.Success "Pulled"))
            | RecreateContainer (id, spec) ->
                let! _ = lifecycle.Remove(id, force = true)
                return! lifecycle.CreateAndStart(spec) |> Async.map (Result.map (fun _ -> ActionResult.Success "Recreated"))
            | EmergencyStop ids ->
                let! results = ids |> List.map (fun id -> lifecycle.GracefulShutdown(id)) |> Async.Parallel
                return Ok (ActionResult.Success $"Stopped {results.Length} containers")
            | _ ->
                return Ok ActionResult.NotImplemented
        }

and RecoveryResult = {
    Actions: ActionResult list
    Success: bool
}
```

---

## 10. Implementation Plan

### 10.1 Phase Overview

| Phase | Duration | Focus | Deliverables |
|-------|----------|-------|--------------|
| **Phase 1** | 2 weeks | Foundation | Domain types, HTTP transport, Container client |
| **Phase 2** | 2 weeks | Core Clients | Pod, Image, Volume, Network clients |
| **Phase 3** | 2 weeks | Lifecycle | State machine, TransitionExecutor, Orchestrator |
| **Phase 4** | 2 weeks | OODA & Recovery | Control loop, Health monitoring, Recovery engine |
| **Phase 5** | 1 week | Integration | CEPAF# integration, documentation |

### 10.2 Phase 1: Foundation (Weeks 1-2)

**Goals:**
- Establish project structure
- Implement core domain types
- Build HTTP transport layer
- Create Container client with full API coverage

**Tasks:**

| Task | Est. Hours | Priority | Dependencies |
|------|-----------|----------|--------------|
| Project setup & structure | 4 | P0 | None |
| Domain/Types.fs - Base types | 8 | P0 | None |
| Domain/Container.fs - Container model | 8 | P0 | Types.fs |
| Domain/Errors.fs - Error types | 4 | P0 | Types.fs |
| Api/Serialization.fs - JSON handling | 8 | P0 | Domain/* |
| Api/SocketConnector.fs - Unix socket | 8 | P1 | None |
| Api/HttpClient.fs - HTTP transport | 8 | P1 | SocketConnector |
| Api/Clients/ContainerClient.fs | 16 | P0 | HttpClient, Domain/* |
| Safety/Constraints.fs - Initial constraints | 8 | P1 | Domain/* |
| Unit tests for Phase 1 | 16 | P0 | All above |

**Milestone:** Container CRUD operations working with safety validation

### 10.3 Phase 2: Core Clients (Weeks 3-4)

**Goals:**
- Complete all API clients
- Full test coverage for API layer

**Tasks:**

| Task | Est. Hours | Priority | Dependencies |
|------|-----------|----------|--------------|
| Domain/Pod.fs | 6 | P0 | Types.fs |
| Domain/Image.fs | 4 | P0 | Types.fs |
| Domain/Volume.fs | 4 | P0 | Types.fs |
| Domain/Network.fs | 4 | P0 | Types.fs |
| Domain/System.fs | 4 | P0 | Types.fs |
| Api/Clients/PodClient.fs | 12 | P0 | HttpClient, Pod.fs |
| Api/Clients/ImageClient.fs | 8 | P0 | HttpClient, Image.fs |
| Api/Clients/VolumeClient.fs | 6 | P1 | HttpClient, Volume.fs |
| Api/Clients/NetworkClient.fs | 6 | P1 | HttpClient, Network.fs |
| Api/Clients/SystemClient.fs | 6 | P1 | HttpClient, System.fs |
| Api/Clients/KubeClient.fs | 8 | P1 | HttpClient, Pod.fs |
| Api/Clients/ExecClient.fs | 8 | P2 | HttpClient, Container.fs |
| Integration tests for API | 16 | P0 | All clients |

**Milestone:** All API endpoints accessible with type-safe clients

### 10.4 Phase 3: Lifecycle Management (Weeks 5-6)

**Goals:**
- Implement state machines
- Build lifecycle orchestration
- Add safety interceptors

**Tasks:**

| Task | Est. Hours | Priority | Dependencies |
|------|-----------|----------|--------------|
| Lifecycle/StateMachine.fs | 8 | P0 | Domain/* |
| Lifecycle/TransitionExecutor.fs | 12 | P0 | StateMachine, Clients |
| Lifecycle/ContainerLifecycle.fs | 12 | P0 | TransitionExecutor |
| Lifecycle/PodLifecycle.fs | 8 | P0 | TransitionExecutor |
| Lifecycle/Orchestrator.fs | 16 | P0 | All Lifecycle |
| Safety/Validator.fs | 8 | P0 | Constraints.fs |
| Safety/Interceptor.fs | 8 | P1 | Validator.fs |
| Safety/AuditLog.fs | 6 | P2 | None |
| State machine tests | 12 | P0 | StateMachine |
| Lifecycle integration tests | 16 | P0 | All Lifecycle |

**Milestone:** End-to-end container/pod lifecycle management

### 10.5 Phase 4: OODA & Recovery (Weeks 7-8)

**Goals:**
- Implement OODA control loop
- Build health monitoring
- Create recovery engine

**Tasks:**

| Task | Est. Hours | Priority | Dependencies |
|------|-----------|----------|--------------|
| Health/ProbeTypes.fs | 4 | P0 | Domain/* |
| Health/HealthChecker.fs | 8 | P0 | Clients |
| Health/MetricsCollector.fs | 8 | P1 | Clients |
| Health/AlertManager.fs | 6 | P2 | None |
| Ooda/Observer.fs | 8 | P0 | Clients, Health |
| Ooda/Orientator.fs | 8 | P0 | Observer |
| Ooda/Decider.fs | 8 | P0 | Orientator, Safety |
| Ooda/Actuator.fs | 8 | P0 | Lifecycle |
| Ooda/ControlLoop.fs | 8 | P0 | All OODA |
| Recovery/CircuitBreaker.fs | 6 | P0 | None |
| Recovery/RetryPolicy.fs | 4 | P0 | None |
| Recovery/FailureDetector.fs | 6 | P1 | Health |
| Recovery/RecoveryPlanner.fs | 8 | P1 | FailureDetector |
| Recovery/RecoveryExecutor.fs | 8 | P1 | Lifecycle |
| OODA integration tests | 16 | P0 | All OODA |

**Milestone:** Autonomous container management with self-healing

### 10.6 Phase 5: Integration (Week 9)

**Goals:**
- CEPAF# integration
- Documentation
- Performance optimization

**Tasks:**

| Task | Est. Hours | Priority | Dependencies |
|------|-----------|----------|--------------|
| PublicApi.fs - Public surface | 8 | P0 | All modules |
| CEPAF# integration module | 12 | P0 | PublicApi |
| Performance profiling | 8 | P1 | All |
| Documentation | 8 | P0 | All |
| End-to-end tests | 8 | P0 | All |
| Release preparation | 4 | P0 | All |

**Milestone:** Production-ready library integrated with CEPAF#

---

## 11. Test Plan

### 11.1 Test Strategy

| Level | Purpose | Coverage Target | Tools |
|-------|---------|-----------------|-------|
| **Unit** | Individual functions | 90%+ | Expecto, FsCheck |
| **Property** | Invariant verification | All state machines | FsCheck |
| **Integration** | API interactions | All endpoints | Testcontainers |
| **E2E** | Full workflows | Critical paths | Real Podman |
| **Performance** | Latency, throughput | SLA compliance | BenchmarkDotNet |

### 11.2 Unit Tests

```fsharp
module ContainerIdTests =
    open Expecto
    open Cepaf.Modules.Podman.Domain

    [<Tests>]
    let tests =
        testList "ContainerId" [
            test "create with valid id succeeds" {
                let result = ContainerId.create "abc123def456"
                Expect.isOk result "Should create valid ID"
            }

            test "create with empty string fails" {
                let result = ContainerId.create ""
                Expect.isError result "Should reject empty string"
            }

            test "create with short id fails" {
                let result = ContainerId.create "abc"
                Expect.isError result "Should reject short ID"
            }

            test "short returns first 12 chars" {
                let id = ContainerId "abc123def456789xyz"
                Expect.equal (ContainerId.short id) "abc123def456" "Should truncate to 12"
            }
        ]
```

### 11.3 Property-Based Tests

```fsharp
module StateMachineProperties =
    open FsCheck
    open Expecto
    open Cepaf.Modules.Podman.Domain

    let containerStateGen = Gen.elements [Absent; Created; Running; Paused; Stopped; Dead]

    type StateMachineGenerators =
        static member ContainerState() = Arb.fromGen containerStateGen

    [<Tests>]
    let tests =
        testList "ContainerStateMachine Properties" [
            testProperty "valid transitions always reach expected state" <| fun (state: ContainerState) (event: ContainerEvent) ->
                match ContainerStateMachine.getNextState state event with
                | Success newState ->
                    // New state should be valid
                    List.contains newState [Absent; Created; Running; Paused; Stopped; Dead; Removing]
                | InvalidTransition _ ->
                    // Transition was correctly rejected
                    not (ContainerStateMachine.canTransition state event)
                | TransitionFailed _ ->
                    true  // Error states are valid responses

            testProperty "Dead state only reachable via Die event" <| fun (state: ContainerState) (event: ContainerEvent) ->
                match ContainerStateMachine.getNextState state event with
                | Success Dead ->
                    match event with
                    | Die _ -> true
                    | _ -> false
                | _ -> true

            testProperty "Remove always leads to Absent" <| fun (state: ContainerState) ->
                match ContainerStateMachine.getNextState state (Remove (true, true)) with
                | Success Absent -> true
                | InvalidTransition _ -> state = Absent || state = Running || state = Paused
                | _ -> false
        ]
```

### 11.4 Integration Tests

```fsharp
module ContainerClientIntegrationTests =
    open Expecto
    open Testcontainers.Podman

    let podmanContainer = PodmanBuilder().Build()

    [<Tests>]
    let tests =
        testList "ContainerClient Integration" [
            testAsync "create container succeeds" {
                // Arrange
                do! podmanContainer.StartAsync()
                let client = createClient(podmanContainer.GetConnectionUri())

                let spec = {
                    ContainerSpec.Default with
                        Name = Some "test-container"
                        Image = "docker.io/library/alpine:latest"
                        Command = Some ["sleep"; "3600"]
                }

                // Act
                let! result = client.Create(spec)

                // Assert
                Expect.isOk result "Should create container"

                // Cleanup
                match result with
                | Ok id -> do! client.Remove(id, force = true) |> Async.Ignore
                | _ -> ()

                do! podmanContainer.StopAsync()
            }

            testAsync "lifecycle create-start-stop-remove works" {
                do! podmanContainer.StartAsync()
                let client = createClient(podmanContainer.GetConnectionUri())

                // Create
                let spec = {
                    ContainerSpec.Default with
                        Name = Some "lifecycle-test"
                        Image = "docker.io/library/alpine:latest"
                        Command = Some ["sleep"; "3600"]
                }
                let! createResult = client.Create(spec)
                Expect.isOk createResult "Create should succeed"
                let id = Result.get createResult

                // Start
                let! startResult = client.Start(id)
                Expect.isOk startResult "Start should succeed"

                // Verify running
                let! inspectResult = client.Inspect(id)
                Expect.isOk inspectResult "Inspect should succeed"
                Expect.equal (Result.get inspectResult).State Running "Should be running"

                // Stop
                let! stopResult = client.Stop(id, timeout = 5)
                Expect.isOk stopResult "Stop should succeed"

                // Remove
                let! removeResult = client.Remove(id)
                Expect.isOk removeResult "Remove should succeed"

                do! podmanContainer.StopAsync()
            }
        ]
```

### 11.5 E2E Tests

```fsharp
module OodaE2ETests =
    open Expecto

    [<Tests>]
    let tests =
        testList "OODA E2E" [
            testAsync "control loop detects and recovers from container failure" {
                // Arrange
                let lifecycle = createLifecycle()
                let ooda = createOodaLoop(lifecycle)

                // Create a container that will fail
                let spec = {
                    ContainerSpec.Default with
                        Name = Some "fail-test"
                        Image = "docker.io/library/alpine:latest"
                        Command = Some ["sh"; "-c"; "exit 1"]
                        RestartPolicy = Some (OnFailure 3)
                }

                let! (id, _) = lifecycle.CreateAndStart(spec)

                // Start OODA loop
                let! _ = Async.StartChild(ooda.Start())

                // Wait for failure and recovery
                do! Async.Sleep(10000)

                // Verify container was restarted
                let! info = lifecycle.Inspect(id)
                Expect.isOk info "Should have container info"
                Expect.isGreaterThan (Result.get info).RestartCount 0 "Should have restarted"

                // Cleanup
                ooda.Stop()
                do! lifecycle.Remove(id, force = true) |> Async.Ignore
            }
        ]
```

### 11.6 Performance Tests

```fsharp
module PerformanceBenchmarks =
    open BenchmarkDotNet.Attributes
    open BenchmarkDotNet.Running

    [<MemoryDiagnoser>]
    type ContainerOperationsBenchmark() =
        let mutable client: ContainerClient = Unchecked.defaultof<_>
        let mutable containerId: ContainerId = Unchecked.defaultof<_>

        [<GlobalSetup>]
        member _.Setup() =
            client <- createClient("unix:///run/podman/podman.sock")
            let spec = {
                ContainerSpec.Default with
                    Name = Some "benchmark-container"
                    Image = "docker.io/library/alpine:latest"
                }
            containerId <- client.Create(spec) |> Async.RunSynchronously |> Result.get

        [<GlobalCleanup>]
        member _.Cleanup() =
            client.Remove(containerId, force = true) |> Async.RunSynchronously |> ignore

        [<Benchmark>]
        member _.InspectContainer() =
            client.Inspect(containerId) |> Async.RunSynchronously

        [<Benchmark>]
        member _.ListContainers() =
            client.List() |> Async.RunSynchronously

        [<Benchmark>]
        member _.GetContainerStats() =
            client.Stats(containerId) |> Async.RunSynchronously
```

### 11.7 Test Coverage Matrix

| Component | Unit | Property | Integration | E2E | Performance |
|-----------|------|----------|-------------|-----|-------------|
| Domain Types | 95% | 90% | - | - | - |
| ContainerClient | 90% | - | 85% | 80% | Yes |
| PodClient | 90% | - | 85% | 80% | Yes |
| StateMachine | 95% | 95% | - | 85% | - |
| Lifecycle | 85% | - | 90% | 85% | Yes |
| OODA Loop | 85% | - | 80% | 80% | Yes |
| Recovery | 90% | 85% | 80% | 75% | - |
| Safety | 95% | 90% | - | - | - |

---

## 12. Integration Guide

### 12.1 CEPAF# Integration

```fsharp
namespace Cepaf.Modules.Podman

open Cepaf.Core

/// CEPAF# module interface
type PodmanModule(config: PodmanModuleConfig) =
    inherit CepafModule("Podman", "1.0.0")

    let httpClient = createHttpClient(config.Connection)
    let safety = SafetyValidator(config.SafetyConstraints)

    let containerClient = ContainerClient(httpClient, safety)
    let podClient = PodClient(httpClient)
    let imageClient = ImageClient(httpClient)
    let volumeClient = VolumeClient(httpClient)
    let networkClient = NetworkClient(httpClient)
    let systemClient = SystemClient(httpClient)

    let executor = TransitionExecutor(containerClient, podClient)
    let lifecycle = ContainerLifecycle(executor, HealthChecker(containerClient))
    let orchestrator = Orchestrator(lifecycle, podClient, imageClient, volumeClient, networkClient)

    let observer = Observer(containerClient, podClient, systemClient, EventClient(httpClient))
    let orientator = Orientator(config.Orientator)
    let decider = Decider(safety)
    let actuator = Actuator(lifecycle, orchestrator, imageClient, systemClient)
    let ooda = OodaControlLoop(observer, orientator, decider, actuator, config.Ooda)

    // Public API
    member _.Containers = containerClient
    member _.Pods = podClient
    member _.Images = imageClient
    member _.Volumes = volumeClient
    member _.Networks = networkClient
    member _.System = systemClient
    member _.Lifecycle = lifecycle
    member _.Orchestrator = orchestrator
    member _.OodaLoop = ooda

    /// Module lifecycle
    override _.OnStart() =
        async {
            // Validate connection
            let! infoResult = systemClient.Info()
            match infoResult with
            | Error e -> return Error e
            | Ok info ->
                Logger.info $"Connected to Podman {info.Version}"

                // Start OODA loop if configured
                if config.AutoStartOoda then
                    do! Async.StartChild(ooda.Start()) |> Async.Ignore

                return Ok ()
        }

    override _.OnStop() =
        async {
            ooda.Stop()
            (httpClient :> IDisposable).Dispose()
            return Ok ()
        }

    override _.HealthCheck() =
        async {
            let! pingResult = systemClient.Ping()
            return pingResult |> Result.map (fun _ -> ModuleHealth.Healthy)
        }

and PodmanModuleConfig = {
    Connection: ConnectionConfig
    SafetyConstraints: SafetyConstraint list
    Orientator: OrientatorConfig
    Ooda: OodaConfig
    AutoStartOoda: bool
}

module PodmanModuleConfig =
    let Default = {
        Connection = {
            Pattern = UnixSocket "/run/podman/podman.sock"
            Timeout = TimeSpan.FromSeconds(30.0)
            MaxRetries = 3
            RetryDelay = TimeSpan.FromMilliseconds(100.0)
            CircuitBreakerThreshold = 5
            PoolSize = 10
        }
        SafetyConstraints = SafetyConstraints.AllCore
        Orientator = {
            RestartThreshold = 5
            DiskThreshold = 90.0
            CPUThreshold = 80.0
            MemoryThreshold = 85.0
        }
        Ooda = {
            CycleInterval = TimeSpan.FromSeconds(10.0)
            MaxConcurrentActions = 5
            ActionTimeout = TimeSpan.FromMinutes(2.0)
        }
        AutoStartOoda = true
    }
```

### 12.2 Usage Examples

```fsharp
// Initialize module
let config = { PodmanModuleConfig.Default with AutoStartOoda = false }
let podman = new PodmanModule(config)
do! podman.Start()

// Create a container
let spec = {
    ContainerSpec.Default with
        Name = Some "my-app"
        Image = "myregistry/myapp:latest"
        PortMappings = [{ ContainerPort = 8080us; HostPort = Some 80us; Protocol = TCP; HostIP = None; Range = 1us }]
        ResourceLimits = Some {
            ResourceLimits.Default with
                Memory = Some (512L * 1024L * 1024L)  // 512 MB
                CPUQuota = Some 100000L  // 100% of one CPU
        }
        HealthConfig = Some {
            Test = ["CMD"; "curl"; "-f"; "http://localhost:8080/health"]
            Interval = TimeSpan.FromSeconds(30.0)
            Timeout = TimeSpan.FromSeconds(10.0)
            Retries = 3
            StartPeriod = TimeSpan.FromSeconds(60.0)
        }
}

let! (id, info) = podman.Lifecycle.CreateAndStart(spec)
printfn $"Container {ContainerId.short id} running"

// Deploy Kubernetes YAML
let yaml = File.ReadAllText("deployment.yaml")
let! deployment = podman.Orchestrator.DeployKubeStack(yaml)
printfn $"Deployed {deployment.Pods.Length} pods"

// Start autonomous management
do! Async.StartChild(podman.OodaLoop.Start()) |> Async.Ignore

// Graceful shutdown
do! podman.Lifecycle.GracefulShutdown(id)
do! podman.Stop()
```

---

## 13. Appendices

### 13.1 API Endpoint Coverage

| Endpoint | Client | Status |
|----------|--------|--------|
| `/libpod/containers/json` | ContainerClient.List | Planned |
| `/libpod/containers/create` | ContainerClient.Create | Planned |
| `/libpod/containers/{id}/json` | ContainerClient.Inspect | Planned |
| `/libpod/containers/{id}/start` | ContainerClient.Start | Planned |
| `/libpod/containers/{id}/stop` | ContainerClient.Stop | Planned |
| `/libpod/containers/{id}/kill` | ContainerClient.Kill | Planned |
| `/libpod/containers/{id}/pause` | ContainerClient.Pause | Planned |
| `/libpod/containers/{id}/unpause` | ContainerClient.Unpause | Planned |
| `/libpod/containers/{id}/restart` | ContainerClient.Restart | Planned |
| `/libpod/containers/{id}` | ContainerClient.Remove | Planned |
| `/libpod/containers/{id}/logs` | ContainerClient.Logs | Planned |
| `/libpod/containers/{id}/wait` | ContainerClient.Wait | Planned |
| `/libpod/containers/{id}/stats` | ContainerClient.Stats | Planned |
| `/libpod/containers/{id}/exec` | ContainerClient.Exec | Planned |
| `/libpod/pods/json` | PodClient.List | Planned |
| `/libpod/pods/create` | PodClient.Create | Planned |
| `/libpod/pods/{id}/start` | PodClient.Start | Planned |
| `/libpod/pods/{id}/stop` | PodClient.Stop | Planned |
| `/libpod/pods/{id}` | PodClient.Remove | Planned |
| `/libpod/play/kube` | PodClient.PlayKube | Planned |
| `/libpod/images/json` | ImageClient.List | Planned |
| `/libpod/images/pull` | ImageClient.Pull | Planned |
| `/libpod/images/{id}/json` | ImageClient.Inspect | Planned |
| `/libpod/images/{id}` | ImageClient.Remove | Planned |
| `/libpod/volumes/json` | VolumeClient.List | Planned |
| `/libpod/volumes/create` | VolumeClient.Create | Planned |
| `/libpod/volumes/{name}` | VolumeClient.Remove | Planned |
| `/libpod/networks/json` | NetworkClient.List | Planned |
| `/libpod/networks/create` | NetworkClient.Create | Planned |
| `/libpod/networks/{name}` | NetworkClient.Remove | Planned |
| `/libpod/info` | SystemClient.Info | Planned |
| `/libpod/system/df` | SystemClient.DiskUsage | Planned |
| `/libpod/system/prune` | SystemClient.Prune | Planned |
| `/_ping` | SystemClient.Ping | Planned |

### 13.2 STAMP Safety Constraints Reference

| Constraint | Description | Validation |
|------------|-------------|------------|
| SC-POD-001 | Image must be specified | Pre-create |
| SC-POD-002 | Resource limits required | Pre-create |
| SC-POD-003 | Health check for long-running | Pre-create |
| SC-POD-004 | Restart policy required | Pre-create |
| SC-POD-005 | No privileged unless explicit | Pre-create |
| SC-POD-006 | Read-only rootfs preferred | Pre-create |
| SC-POD-007 | Minimal capabilities | Pre-create |
| SC-POD-008 | Graceful shutdown timeout | Pre-stop |
| SC-POD-009 | Volume backup before remove | Pre-remove |
| SC-POD-010 | Audit log all operations | All |
| SC-ORCH-001 | Image pull before create | Pre-create |
| SC-ORCH-002 | Network exists before attach | Pre-create |
| SC-ORCH-003 | Volume exists before mount | Pre-create |
| SC-ORCH-004 | Probe health after start | Post-start |
| SC-ORCH-005 | Drain before scale-down | Pre-remove |
| SC-DATA-001 | Backup before destroy | Pre-remove |
| SC-DATA-002 | Persist state on checkpoint | Checkpoint |
| SC-DATA-003 | Verify integrity on restore | Restore |

### 13.3 Glossary

| Term | Definition |
|------|------------|
| **Container** | OCI-compliant isolated process |
| **Pod** | Group of containers sharing namespaces |
| **Image** | Immutable container template |
| **Volume** | Persistent storage |
| **Network** | Container connectivity abstraction |
| **OODA** | Observe-Orient-Decide-Act control loop |
| **STAMP** | Systems-Theoretic Accident Model and Processes |
| **SIL-2** | Safety Integrity Level 2 (IEC 61508) |

---

**Document Status**: APPROVED FOR IMPLEMENTATION
**Last Updated**: 2025-12-23 (v1.1.0 - Ontology sync)
**Next Review**: 2026-01-23
**Ontology Reference**: Updated to v3.0.0 with API v5.7 alignment
