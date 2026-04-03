# Cepaf.Podman

[![Cepaf.Podman CI](https://github.com/indrajaal/cepaf/actions/workflows/cepaf-podman.yml/badge.svg)](https://github.com/indrajaal/cepaf/actions/workflows/cepaf-podman.yml)
[![NuGet](https://img.shields.io/nuget/v/Cepaf.Podman.svg)](https://www.nuget.org/packages/Cepaf.Podman/)
[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4)](https://dotnet.microsoft.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![F#](https://img.shields.io/badge/F%23-378BBA?logo=fsharp&logoColor=fff)](https://fsharp.org/)

A type-safe F# library for Podman container lifecycle management via the Unix socket API.

## Features

- **Container Management**: Create, start, stop, restart, remove, inspect containers
- **Pod Management**: Create and manage multi-container pods
- **Image Operations**: Pull, list, inspect, and remove images
- **Volume Management**: Create, list, and remove named volumes
- **Network Management**: Create and configure container networks
- **Health Probes**: Built-in health check support with HTTP and TCP probes
- **Event Streaming**: Reactive event stream for container lifecycle events
- **Compose Parser**: Parse and deploy from compose YAML files
- **STAMP Safety Constraints**: Built-in validation for safety-critical deployments

## Installation

```bash
dotnet add package Cepaf.Podman
```

## Quick Start

```fsharp
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

// Create a client (auto-detects rootless/rootful socket)
let client = PodmanClient.create PodmanClientConfig.defaultConfig

// Create a container spec
let spec =
    ContainerSpec.create "localhost/myapp:1.0.0"
    |> ContainerSpec.withName "my-container"
    |> ContainerSpec.withPort 8080us 80us
    |> ContainerSpec.withEnv "ENV" "production"
    |> ContainerSpec.withMemoryLimitMB 512
    |> ContainerSpec.withRestartAlways
    |> ContainerSpec.withHttpHealthCheck "http://localhost/health"
        (TimeSpan.FromSeconds 30.0) 3

// Create and start the container
async {
    match! Containers.createAndStart client spec with
    | Ok containerId ->
        printfn "Container started: %s" containerId
    | Error err ->
        printfn "Error: %s" (PodmanError.toMessage err)
}
|> Async.RunSynchronously
```

## API Summary

### Container Operations

```fsharp
// List running containers
Containers.listRunning client

// List all containers
Containers.listAll client

// Inspect container
Containers.inspect client "container-id"

// Start/Stop/Restart
Containers.start client "container-id"
Containers.stop client "container-id" (Some 10)
Containers.restart client "container-id" None

// Execute command in container
Containers.execWait client "container-id" ["ls"; "-la"]

// Get logs
Containers.logsLast client "container-id" 100

// Health check
Containers.healthCheck client "container-id"
```

### Pod Operations

```fsharp
open Cepaf.Podman.Api.Pods

// Create a pod
let podSpec =
    PodSpec.create()
    |> PodSpec.withName "my-pod"
    |> PodSpec.withPort 8080us 80us

Pods.create client podSpec
Pods.start client "pod-id"
Pods.stop client "pod-id" (Some 10)
```

### Image Operations

```fsharp
open Cepaf.Podman.Api.Images

Images.list client
Images.pull client "localhost/myimage:1.0.0"
Images.inspect client "image-id"
Images.remove client "image-id" false
```

### Volume Operations

```fsharp
open Cepaf.Podman.Api.Volumes

let volumeSpec = VolumeSpec.create "my-volume"
Volumes.create client volumeSpec
Volumes.list client
Volumes.remove client "my-volume" false
```

### Network Operations

```fsharp
open Cepaf.Podman.Api.Networks

let networkSpec =
    NetworkSpec.create "my-network"
    |> NetworkSpec.withSubnet "10.89.0.0/24" (Some "10.89.0.1")

Networks.create client networkSpec
Networks.list client
Networks.remove client "my-network"
```

## STAMP Safety Constraints

The library includes built-in STAMP (Systems-Theoretic Accident Model and Processes) safety constraint validation:

```fsharp
open Cepaf.Podman.Safety.Constraints

// Validate container spec before creation
match validateContainerSpec spec with
| Valid ->
    printfn "All constraints passed"
| Invalid violations ->
    for v in violations do
        printfn "%s" (formatViolation v)

// Safe operations (with automatic validation)
Constraints.safeCreateContainer client spec
Constraints.safePullImage client "localhost/myimage:1.0.0"
Constraints.safeCreatePod client podSpec

// Emergency operations
Constraints.emergencyStop client "container-id" 5
Constraints.emergencyStopAll client
```

### Safety Constraints Enforced

| Constraint | Description |
|------------|-------------|
| SC-CNT-009 | NixOS/Podman only |
| SC-CNT-010 | Localhost registry only |
| SC-CNT-012 | Rootless mode |
| SC-POD-001 | Pod naming convention |
| SC-POD-002 | Resource limits required |
| SC-POD-003 | Health check required |
| SC-POD-005 | Image source validation |
| SC-POD-007 | Volume mount validation |
| SC-POD-008 | Security context required |
| SC-PRF-050 | Response latency < 50ms |
| SC-EMR-057 | Stop < 5s |
| SC-EMR-060 | Rollback capability |

## Error Handling

All operations return `AsyncPodmanResult<'T>` which is `Async<Result<'T, PodmanError>>`:

```fsharp
async {
    match! Containers.start client "container-id" with
    | Ok () ->
        printfn "Started successfully"
    | Error (PodmanError.ContainerNotFound id) ->
        printfn "Container %s not found" id
    | Error (PodmanError.ContainerAlreadyRunning id) ->
        printfn "Container %s is already running" id
    | Error err ->
        printfn "Error: %s" (PodmanError.toMessage err)
        if PodmanError.isRetryable err then
            printfn "This error is retryable"
}
```

## Requirements

- .NET 8.0 or later
- Podman 4.0+ with API socket enabled
- Linux (Unix socket communication)

### Enable Podman Socket

```bash
# Rootless (user socket)
systemctl --user enable --now podman.socket

# Rootful (system socket)
sudo systemctl enable --now podman.socket
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please ensure all changes maintain the STAMP safety constraints and include appropriate tests.
