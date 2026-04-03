namespace Cepaf.Podman.Domain

open System

// ============================================================================
// Container Types
// ============================================================================

/// Container runtime status
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

/// Parse container status from string
module ContainerStatus =
    let parse (status: string) : ContainerStatus =
        match status.ToLowerInvariant() with
        | "created" -> ContainerStatus.Created
        | "running" -> ContainerStatus.Running
        | "paused" -> ContainerStatus.Paused
        | "restarting" -> ContainerStatus.Restarting
        | "removing" -> ContainerStatus.Removing
        | "exited" -> ContainerStatus.Exited 0
        | "dead" -> ContainerStatus.Dead "unknown"
        | s -> ContainerStatus.Unknown s

/// Container health check status
[<RequireQualifiedAccess>]
type HealthStatus =
    | Starting
    | Healthy
    | Unhealthy of failingStreak: int
    | NoHealthcheck
    | Unknown of status: string

module HealthStatus =
    let parse (status: string) : HealthStatus =
        match status.ToLowerInvariant() with
        | "starting" -> HealthStatus.Starting
        | "healthy" -> HealthStatus.Healthy
        | "unhealthy" -> HealthStatus.Unhealthy 0
        | "none" | "" -> HealthStatus.NoHealthcheck
        | s -> HealthStatus.Unknown s

/// Port protocol
[<RequireQualifiedAccess>]
type PortProtocol =
    | TCP
    | UDP
    | SCTP

module PortProtocol =
    let parse (protocol: string) : PortProtocol =
        match protocol.ToLowerInvariant() with
        | "udp" -> PortProtocol.UDP
        | "sctp" -> PortProtocol.SCTP
        | _ -> PortProtocol.TCP

    let toString (protocol: PortProtocol) : string =
        match protocol with
        | PortProtocol.TCP -> "tcp"
        | PortProtocol.UDP -> "udp"
        | PortProtocol.SCTP -> "sctp"

/// Port mapping configuration
type PortMapping = {
    ContainerPort: uint16
    HostPort: uint16 option
    HostIP: string option
    Protocol: PortProtocol
    Range: uint16 option
}

module PortMapping =
    let create containerPort = {
        ContainerPort = containerPort
        HostPort = None
        HostIP = None
        Protocol = PortProtocol.TCP
        Range = None
    }

    let withHostPort port mapping = { mapping with HostPort = Some port }
    let withHostIP ip mapping = { mapping with HostIP = Some ip }
    let withProtocol protocol mapping = { mapping with Protocol = protocol }

/// Mount type
[<RequireQualifiedAccess>]
type MountType =
    | Bind
    | Volume
    | Tmpfs
    | Image
    | Devpts

module MountType =
    let parse (t: string) : MountType =
        match t.ToLowerInvariant() with
        | "bind" -> MountType.Bind
        | "volume" -> MountType.Volume
        | "tmpfs" -> MountType.Tmpfs
        | "image" -> MountType.Image
        | "devpts" -> MountType.Devpts
        | _ -> MountType.Bind

    let toString (t: MountType) : string =
        match t with
        | MountType.Bind -> "bind"
        | MountType.Volume -> "volume"
        | MountType.Tmpfs -> "tmpfs"
        | MountType.Image -> "image"
        | MountType.Devpts -> "devpts"

/// Mount configuration
type Mount = {
    Type: MountType
    Source: string
    Target: string
    ReadOnly: bool
    Options: string list
}

module Mount =
    let createBind source target = {
        Type = MountType.Bind
        Source = source
        Target = target
        ReadOnly = false
        Options = []
    }

    let createVolume name target = {
        Type = MountType.Volume
        Source = name
        Target = target
        ReadOnly = false
        Options = []
    }

    let withReadOnly mount = { mount with ReadOnly = true }
    let withOptions opts mount = { mount with Options = opts }

/// Named volume reference
type NamedVolume = {
    Name: string
    Dest: string
    Options: string list
}

/// Health check log entry
type HealthCheckLog = {
    Start: DateTimeOffset
    End: DateTimeOffset
    ExitCode: int
    Output: string
}

/// Health check result
type HealthCheckResult = {
    Status: HealthStatus
    FailingStreak: int
    Log: HealthCheckLog list
}

/// Container state detail
type ContainerStateDetail = {
    Status: ContainerStatus
    Running: bool
    Paused: bool
    Restarting: bool
    OOMKilled: bool
    Dead: bool
    Pid: int
    ExitCode: int
    Error: string option
    StartedAt: DateTimeOffset option
    FinishedAt: DateTimeOffset option
    Health: HealthCheckResult option
}

/// Container summary (from list operation)
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

/// Full container inspection response
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

// ============================================================================
// Pod Types
// ============================================================================

/// Pod state
[<RequireQualifiedAccess>]
type PodStatus =
    | Created
    | Running
    | Paused
    | Stopped
    | Exited
    | Dead
    | Unknown of status: string

module PodStatus =
    let parse (status: string) : PodStatus =
        match status.ToLowerInvariant() with
        | "created" -> PodStatus.Created
        | "running" -> PodStatus.Running
        | "paused" -> PodStatus.Paused
        | "stopped" -> PodStatus.Stopped
        | "exited" -> PodStatus.Exited
        | "dead" -> PodStatus.Dead
        | s -> PodStatus.Unknown s

/// Pod container info
type PodContainerInfo = {
    Id: string
    Name: string
    Status: ContainerStatus
}

/// Pod summary (from list operation)
type PodSummary = {
    Id: string
    Name: string
    Status: PodStatus
    Created: DateTimeOffset
    Labels: Map<string, string>
    Containers: PodContainerInfo list
    InfraId: string option
}

/// Full pod inspection
type PodInspect = {
    Id: string
    Name: string
    Created: DateTimeOffset
    State: PodStatus
    Hostname: string option
    Labels: Map<string, string>
    Containers: PodContainerInfo list
    InfraContainerId: string option
    CgroupParent: string option
    SharedNamespaces: string list
}

// ============================================================================
// Image Types
// ============================================================================

/// Image summary
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

/// Image history layer
type ImageHistoryLayer = {
    Id: string
    Created: DateTimeOffset
    CreatedBy: string
    Size: int64
    Comment: string
}

/// Full image inspection
type ImageInspect = {
    Id: string
    RepoTags: string list
    RepoDigests: string list
    Parent: string option
    Comment: string
    Created: DateTimeOffset
    Author: string
    Architecture: string
    Os: string
    Size: int64
    VirtualSize: int64
    Labels: Map<string, string>
    History: ImageHistoryLayer list
}

// ============================================================================
// Volume Types
// ============================================================================

/// Volume driver
[<RequireQualifiedAccess>]
type VolumeDriver =
    | Local
    | Custom of name: string

module VolumeDriver =
    let parse (driver: string) : VolumeDriver =
        match driver.ToLowerInvariant() with
        | "local" | "" -> VolumeDriver.Local
        | d -> VolumeDriver.Custom d

    let toString (driver: VolumeDriver) : string =
        match driver with
        | VolumeDriver.Local -> "local"
        | VolumeDriver.Custom name -> name

/// Volume information
type Volume = {
    Name: string
    Driver: VolumeDriver
    Mountpoint: string
    CreatedAt: DateTimeOffset
    Labels: Map<string, string>
    Options: Map<string, string>
    Scope: string
}

// ============================================================================
// Network Types
// ============================================================================

/// Network driver
[<RequireQualifiedAccess>]
type NetworkDriver =
    | Bridge
    | Macvlan
    | Ipvlan
    | Host
    | None
    | Custom of name: string

module NetworkDriver =
    let parse (driver: string) : NetworkDriver =
        match driver.ToLowerInvariant() with
        | "bridge" -> NetworkDriver.Bridge
        | "macvlan" -> NetworkDriver.Macvlan
        | "ipvlan" -> NetworkDriver.Ipvlan
        | "host" -> NetworkDriver.Host
        | "none" -> NetworkDriver.None
        | d -> NetworkDriver.Custom d

    let toString (driver: NetworkDriver) : string =
        match driver with
        | NetworkDriver.Bridge -> "bridge"
        | NetworkDriver.Macvlan -> "macvlan"
        | NetworkDriver.Ipvlan -> "ipvlan"
        | NetworkDriver.Host -> "host"
        | NetworkDriver.None -> "none"
        | NetworkDriver.Custom name -> name

/// Network subnet configuration
type Subnet = {
    Subnet: string
    Gateway: string option
}

/// Network information
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

// ============================================================================
// System Types
// ============================================================================

/// Podman version info
type VersionInfo = {
    Version: string
    ApiVersion: string
    GoVersion: string
    GitCommit: string
    Built: DateTimeOffset option
    OsArch: string
}

/// Host info
type HostInfo = {
    Hostname: string
    Os: string
    Arch: string
    Kernel: string
    Uptime: string
    MemTotal: int64
    MemFree: int64
    SwapTotal: int64
    SwapFree: int64
    CpuCount: int
}

/// Storage info
type StorageInfo = {
    Driver: string
    GraphRoot: string
    RunRoot: string
    ImageCount: int
    ContainerCount: int
}

/// Runtime info
type RuntimeInfo = {
    Name: string
    Path: string
    Version: string option
}

/// System info
type SystemInfo = {
    Host: HostInfo
    Storage: StorageInfo
    Runtime: RuntimeInfo
    Version: VersionInfo
}

/// Disk usage for a resource type
type DiskUsageEntry = {
    Type: string
    Total: int
    Active: int
    Size: int64
    Reclaimable: int64
}

/// System disk usage
type DiskUsage = {
    Containers: DiskUsageEntry
    Images: DiskUsageEntry
    Volumes: DiskUsageEntry
}

// ============================================================================
// Client Configuration
// ============================================================================

/// Podman socket type
[<RequireQualifiedAccess>]
type PodmanSocket =
    | Rootful of path: string
    | Rootless of uid: string * path: string

module PodmanSocket =
    let getPath (socket: PodmanSocket) : string =
        match socket with
        | PodmanSocket.Rootful path -> path
        | PodmanSocket.Rootless (_, path) -> path

    let defaultRootful = PodmanSocket.Rootful "/run/podman/podman.sock"

    let defaultRootless uid =
        PodmanSocket.Rootless (uid, sprintf "/run/user/%s/podman/podman.sock" uid)

    let detect () =
        let uid = Environment.GetEnvironmentVariable("UID")
        if String.IsNullOrEmpty(uid) || uid = "0" then
            defaultRootful
        else
            defaultRootless uid

/// Client configuration
type PodmanClientConfig = {
    Socket: PodmanSocket
    ApiVersion: string
    Timeout: TimeSpan
    RetryCount: int
    RetryDelay: TimeSpan
}

module PodmanClientConfig =
    let defaultConfig = {
        Socket = PodmanSocket.detect()
        ApiVersion = "5.7.0"
        Timeout = TimeSpan.FromSeconds(30.0)
        RetryCount = 3
        RetryDelay = TimeSpan.FromSeconds(1.0)
    }

    let withSocket socket config = { config with Socket = socket }
    let withApiVersion version config = { config with ApiVersion = version }
    let withTimeout timeout config = { config with Timeout = timeout }
    let withRetry count delay config = { config with RetryCount = count; RetryDelay = delay }
