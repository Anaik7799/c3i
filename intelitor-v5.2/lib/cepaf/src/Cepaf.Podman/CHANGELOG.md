# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-23

### Added

#### Domain Layer
- `PodmanError` discriminated union with comprehensive error types for all API operations
- `PodmanResult<'T>` and `AsyncPodmanResult<'T>` type aliases for consistent error handling
- `AsyncResult` module with map, bind, and catch helpers
- Container types: `ContainerStatus`, `HealthStatus`, `ContainerSummary`, `ContainerInspect`, `ContainerStateDetail`
- Pod types: `PodStatus`, `PodSummary`, `PodInspect`, `PodContainerInfo`
- Image types: `ImageSummary`, `ImageInspect`, `ImageHistoryLayer`
- Volume types: `Volume`, `VolumeDriver`
- Network types: `Network`, `NetworkDriver`, `Subnet`
- System types: `SystemInfo`, `VersionInfo`, `HostInfo`, `StorageInfo`, `DiskUsage`
- Configuration types: `PortMapping`, `Mount`, `MountType`

#### Specification Builders
- `ContainerSpec` with fluent builder API for container creation
- `PodSpec` with fluent builder API for pod creation
- `VolumeSpec` for volume creation
- `NetworkSpec` for network creation
- `ResourceConfig` for CPU/memory limits
- `HealthCheckConfig` with HTTP and TCP probe helpers
- `SecurityConfig` with hardened security preset
- `NetworkConfig` with DNS and host configuration
- `RestartPolicy` with common presets (always, on-failure, unless-stopped)

#### Client Layer
- `PodmanClient` for managing connections to Podman socket
- `PodmanClientConfig` with configurable timeout, retry, and API version
- `PodmanSocket` type with rootless/rootful auto-detection
- `UnixSocket` module for low-level socket communication
- `HttpClient` module for REST API communication over Unix socket
- `Serialization` module for JSON parsing and generation

#### API Modules
- `Containers` module: list, inspect, create, start, stop, restart, kill, pause, unpause, remove, rename, wait, logs, exec, stats, healthCheck
- `Pods` module: list, inspect, create, start, stop, restart, kill, pause, unpause, remove
- `Images` module: list, inspect, pull, remove, exists, history
- `Volumes` module: list, inspect, create, remove, exists, prune
- `Networks` module: list, inspect, create, remove, exists, connect, disconnect
- `System` module: info, version, ping, diskUsage

#### Feature Modules
- `Events.Stream` module with reactive event streaming via `System.Reactive`
- `Health.Probes` module with HTTP, TCP, and command probes
- `Compose.Parser` module for parsing podman-compose YAML files

#### Safety Module
- `Constraints` module implementing STAMP safety constraints
- Constraint identifiers: SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-POD-001 through SC-POD-008, SC-PRF-050, SC-PRF-055, SC-EMR-057, SC-EMR-060
- `ValidationResult` type with Valid/Invalid states
- `Violation` type with Critical/Warning/Info severity levels
- Pre-validated safe operations: `safeCreateContainer`, `safeCreateAndStart`, `safePullImage`, `safeCreatePod`
- Emergency operations: `emergencyStop`, `emergencyRemove`, `emergencyStopAll`
- Runtime validation: `validateRootless`, `validateContainerHealth`, `validateAllContainers`

### Dependencies
- System.Text.Json 8.0.5
- YamlDotNet 16.3.0
- System.Reactive 6.0.1

### Technical Details
- Target framework: .NET 8.0
- Unix socket communication for Podman API
- Async-first design with F# async workflows
- Immutable record types with builder pattern
- Comprehensive XML documentation

[1.0.0]: https://github.com/indrajaal/cepaf/releases/tag/v1.0.0
