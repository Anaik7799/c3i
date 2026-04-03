# Podman System Ontology & Specification
## Domain: infra-f#-cepa (CEPAF# Module)
**Version**: 3.0.0 (API v5.7 Aligned)
**Classification**: INFRASTRUCTURE BLUEPRINT
**Updated**: 2025-12-23
**Compliance**: SOPv5.11 + STAMP Safety Framework
**Library Target**: Cepaf.Podman (F# Native Bindings)

---

## 1.0 Architectural Ontology

This ontology maps the data and runtime aspects of the Podman system for the CEPAF# Functional Orchestrator.

### 1.1 Core Entities (Classes)

| Entity | Functional Definition | Attributes | API Endpoint |
|:-------|:---------------------|:-----------|:-------------|
| **Engine** | The daemonless `libpod` runtime | `Version`, `Runtime (crun/runc)`, `NetworkBackend`, `GraphRoot`, `RunRoot` | `/info`, `/version` |
| **Node** | The host server (NixOS) | `UID`, `XDG_RUNTIME_DIR`, `StorageDriver`, `Hostname`, `Kernel` | `/system/info` |
| **Blueprint** | A static OCI image | `Id`, `RepoTag`, `LayerCount`, `Size`, `Digest`, `Created`, `Labels` | `/images/*` |
| **Organism** | A group of containers (Pod) | `Id`, `Name`, `State`, `InfraContainerID`, `Containers[]`, `CgroupParent` | `/pods/*` |
| **Cell** | An active container | `Id`, `Name`, `Pid`, `ExitCode`, `HealthStatus`, `Mounts[]`, `Ports[]` | `/containers/*` |
| **Pulse** | A discrete lifecycle signal (Event) | `Type`, `Action`, `Actor`, `Timestamp`, `Attributes` | `/events` |
| **Volume** | Persistent storage unit | `Name`, `Driver`, `Mountpoint`, `Labels`, `Options`, `CreatedAt` | `/volumes/*` |
| **Network** | Container networking config | `Name`, `Id`, `Driver`, `Subnets[]`, `Internal`, `DNSEnabled` | `/networks/*` |
| **Manifest** | Multi-arch image list | `Name`, `Images[]`, `SchemaVersion`, `MediaType` | `/manifests/*` |
| **Secret** | Sensitive data storage | `ID`, `Name`, `Driver`, `CreatedAt`, `UpdatedAt` | `/secrets/*` |

### 1.2 Entity Relationships (Graph)

```
                    ┌─────────────┐
                    │   Engine    │
                    │  (libpod)   │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │Blueprint │    │ Organism │    │ Network  │
    │ (Image)  │    │  (Pod)   │    │          │
    └────┬─────┘    └────┬─────┘    └────┬─────┘
         │               │               │
         │               │               │
         ▼               ▼               │
    ┌──────────┐    ┌──────────┐        │
    │   Cell   │◄───│   Cell   │◄───────┘
    │(Container)│   │(Container)│
    └────┬─────┘    └────┬─────┘
         │               │
         ▼               ▼
    ┌──────────┐    ┌──────────┐
    │  Volume  │    │  Pulse   │
    │          │    │ (Event)  │
    └──────────┘    └──────────┘
```

### 1.3 Runtime State Machine (Cell/Container)

CEPAF# transitions cells through the following cybernetic states:

```
                     ┌──────────┐
                     │  Absent  │  (No trace of container metadata)
                     └────┬─────┘
                          │ create
                          ▼
                     ┌──────────┐
              ┌──────│ Created  │  (Metadata exists, process not forked)
              │      └────┬─────┘
              │           │ start
              │           ▼
              │      ┌──────────┐
              │      │ Running  │◄─────────────┐
              │      └────┬─────┘              │
              │           │                    │
              │     ┌─────┴─────┐              │
              │     │           │              │
              │  pause       stop           unpause
              │     │           │              │
              │     ▼           ▼              │
              │ ┌──────┐   ┌──────────┐       │
              │ │Paused│   │ Stopped  │       │
              │ └──┬───┘   └────┬─────┘       │
              │    │            │             │
              │ unpause      start            │
              │    │            │             │
              │    └────────────┴─────────────┘
              │
              │ kill (OOM/Error)
              ▼
         ┌──────────┐
         │   Dead   │  (Container in invalid state or OOMKilled)
         └──────────┘
```

**State Definitions**:
| State | Description | Transitions |
|:------|:------------|:------------|
| **Absent** | No trace of container metadata | → Created (via `create`) |
| **Created** | Metadata exists, process not yet forked | → Running (via `start`), → Dead (on error) |
| **Running** | `conmon` monitoring the active process | → Paused, → Stopped, → Dead |
| **Paused** | Process execution suspended via cgroups | → Running (via `unpause`) |
| **Stopped** | Process exited, `conmon` holding exit code | → Running (via `start`), → Absent (via `rm`) |
| **Dead** | Container in invalid state or OOMKilled | → Absent (via `rm --force`) |

### 1.4 Pod State Machine (Organism)

```
    ┌──────────┐
    │ Created  │  (Infra container only)
    └────┬─────┘
         │ start
         ▼
    ┌──────────┐
    │ Running  │◄────────────────┐
    └────┬─────┘                 │
         │                       │
    ┌────┴────┐                  │
    │         │                  │
 pause     stop              unpause/start
    │         │                  │
    ▼         ▼                  │
┌──────┐ ┌──────────┐           │
│Paused│ │ Stopped  │           │
│      │ │ /Exited  │           │
└──┬───┘ └────┬─────┘           │
   │          │                 │
   └──────────┴─────────────────┘
```

---

## 2.0 REST API Specification (v5.7)

### 2.1 Unix Domain Socket (UDS) Endpoints

CEPAF# interacts with the REST API using the following locality mandates:

| Mode | Socket Path | Permissions |
|:-----|:------------|:------------|
| **Rootful** | `unix:///run/podman/podman.sock` | root only |
| **Rootless** | `unix:///run/user/${UID}/podman/podman.sock` | user only |

**API Base**: `http://d/v5.7.0/libpod/`

### 2.1.1 API Compatibility Layers

Podman exposes two parallel API interfaces:

| Layer | Base Path | Purpose | Use Case |
|:------|:----------|:--------|:---------|
| **Docker Compat** | `/v5.7.0/` | Docker API compatible | Drop-in Docker replacement |
| **libpod Native** | `/v5.7.0/libpod/` | Full Podman features | CEPAF# primary interface |

**Key Differences**:
- Native endpoints expose pod operations, checkpoint/restore, and mount operations
- Native endpoints return richer response schemas with libpod-specific fields
- Compat endpoints accept Docker Compose files without modification

**CEPAF# Strategy**: Use `/libpod/` endpoints exclusively for full control.

### 2.2 Container Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/containers/json` | GET | List containers | `all`, `filters`, `limit`, `size` |
| `/containers/create` | POST | Create container | `name`, SpecGenerator body |
| `/containers/{id}/start` | POST | Start container | `detachKeys` |
| `/containers/{id}/stop` | POST | Stop container | `timeout`, `Ignore` |
| `/containers/{id}/restart` | POST | Restart container | `timeout` |
| `/containers/{id}/kill` | POST | Kill container | `signal` (default SIGTERM) |
| `/containers/{id}/pause` | POST | Pause container | - |
| `/containers/{id}/unpause` | POST | Unpause container | - |
| `/containers/{id}/wait` | POST | Wait for container exit | `condition` |
| `/containers/{id}/logs` | GET | Get container logs | `follow`, `stdout`, `stderr`, `timestamps` |
| `/containers/{id}/stats` | GET | Container stats | `stream`, `one-shot` |
| `/containers/{id}/top` | GET | Process listing | `ps_args` |
| `/containers/{id}/attach` | POST | Attach to container | `detachKeys`, `logs`, `stream` |
| `/containers/{id}/exec` | POST | Create exec instance | ExecConfig body |
| `/containers/{id}/export` | GET | Export container filesystem | - |
| `/containers/{id}/checkpoint` | POST | Checkpoint container (CRIU) | `keep`, `leaveRunning`, `tcpEstablished` |
| `/containers/{id}/restore` | POST | Restore container (CRIU) | `keep`, `tcpEstablished` |
| `/containers/{id}/update` | POST | Update container resources | UpdateConfig body |
| `/containers/{id}/rename` | POST | Rename container | `name` |
| `/containers/{id}` | DELETE | Delete container | `force`, `v` (volumes) |
| `/containers/prune` | POST | Prune stopped containers | `filters` |

### 2.3 Pod Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/pods/json` | GET | List pods | `filters` |
| `/pods/create` | POST | Create pod | PodSpecGenerator body |
| `/pods/{id}/start` | POST | Start pod | - |
| `/pods/{id}/stop` | POST | Stop pod | `timeout` |
| `/pods/{id}/restart` | POST | Restart pod | - |
| `/pods/{id}/kill` | POST | Kill pod | `signal` |
| `/pods/{id}/pause` | POST | Pause pod | - |
| `/pods/{id}/unpause` | POST | Unpause pod | - |
| `/pods/{id}/top` | GET | Process listing | `ps_args` |
| `/pods/{id}/stats` | GET | Pod stats | `all`, `namesOrIDs[]` |
| `/pods/{id}` | DELETE | Delete pod | `force` |
| `/pods/prune` | POST | Prune stopped pods | - |

### 2.4 Image Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/images/json` | GET | List images | `all`, `filters` |
| `/images/pull` | POST | Pull image | `reference`, `policy`, `tlsVerify` |
| `/images/build` | POST | Build image | Dockerfile context, `t`, `nocache` |
| `/images/{id}/push` | POST | Push image | `destination`, `tlsVerify` |
| `/images/{id}/tag` | POST | Tag image | `repo`, `tag` |
| `/images/{id}/untag` | POST | Untag image | `repo`, `tag` |
| `/images/{id}/history` | GET | Image history | - |
| `/images/{id}/tree` | GET | Image layer tree | - |
| `/images/{id}/exists` | GET | Check image exists | - |
| `/images/{id}` | GET | Inspect image | - |
| `/images/{id}` | DELETE | Delete image | `force`, `noprune` |
| `/images/prune` | POST | Prune unused images | `filters`, `all` |
| `/images/import` | POST | Import tarball | `changes`, `message`, `reference` |
| `/images/{id}/get` | GET | Export image | `format` (oci-archive, docker-archive) |
| `/images/load` | POST | Load image archive | - |

### 2.5 Volume Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/volumes/json` | GET | List volumes | `filters` |
| `/volumes/create` | POST | Create volume | VolumeCreateOptions body |
| `/volumes/{name}` | GET | Inspect volume | - |
| `/volumes/{name}/exists` | GET | Check volume exists | - |
| `/volumes/{name}` | DELETE | Delete volume | `force` |
| `/volumes/prune` | POST | Prune unused volumes | `filters` |

### 2.6 Network Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/networks/json` | GET | List networks | `filters` |
| `/networks/create` | POST | Create network | NetworkCreateOptions body |
| `/networks/{name}` | GET | Inspect network | - |
| `/networks/{name}/exists` | GET | Check network exists | - |
| `/networks/{name}/connect` | POST | Connect container | `container`, `aliases[]` |
| `/networks/{name}/disconnect` | POST | Disconnect container | `container`, `force` |
| `/networks/{name}` | DELETE | Delete network | `force` |
| `/networks/prune` | POST | Prune unused networks | `filters` |

### 2.7 System Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/info` | GET | System information | - |
| `/version` | GET | Version information | - |
| `/_ping` | GET | Health check | - |
| `/events` | GET | Stream events | `since`, `until`, `filters` |
| `/system/df` | GET | Disk usage | - |
| `/system/prune` | POST | System prune | `all`, `volumes`, `filters` |

### 2.8 Exec Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/exec/{id}/start` | POST | Start exec instance | ExecStartConfig body |
| `/exec/{id}/resize` | POST | Resize exec TTY | `h`, `w` |
| `/exec/{id}/json` | GET | Inspect exec instance | - |

### 2.9 Kubernetes Integration

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/play/kube` | POST | Play Kubernetes YAML | YAML body, `network`, `tlsVerify` |
| `/kube/down` | DELETE | Tear down Kubernetes YAML | `force` |
| `/generate/kube` | GET | Generate Kubernetes YAML | `names[]`, `service` |
| `/generate/systemd` | GET | Generate systemd units | `name`, `new`, `restartPolicy` |

### 2.10 Manifest Operations

| Endpoint | Method | Description | Key Parameters |
|:---------|:-------|:------------|:---------------|
| `/manifests/create` | POST | Create manifest list | `name`, `images[]` |
| `/manifests/{name}` | GET | Inspect manifest | - |
| `/manifests/{name}/exists` | GET | Check manifest exists | - |
| `/manifests/{name}/add` | PUT | Add to manifest | ManifestAddOptions body |
| `/manifests/{name}` | DELETE | Delete manifest | - |
| `/manifests/{name}/push` | POST | Push manifest | `destination`, `all` |

---

## 3.0 CLI Command Reference

### 3.1 Global Options

| Option | Description | Environment Variable |
|:-------|:------------|:--------------------|
| `--connection` | Connection URI | `CONTAINER_CONNECTION` |
| `--context` | Context name | - |
| `--help` | Show help | - |
| `--identity` | SSH identity file | - |
| `--log-level` | Log level (debug/info/warn/error) | `CONTAINERS_LOG_LEVEL` |
| `--out` | Output destination | - |
| `--remote` | Use remote Podman | `CONTAINER_HOST` |
| `--root` | Storage root | `CONTAINERS_STORAGE_ROOT` |
| `--runroot` | Runtime root | - |
| `--runtime` | OCI runtime | `CONTAINERS_RUNTIME` |
| `--storage-driver` | Storage driver | `CONTAINERS_STORAGE_DRIVER` |
| `--storage-opt` | Storage options | `CONTAINERS_STORAGE_OPTS` |
| `--syslog` | Log to syslog | - |
| `--tmpdir` | Temp directory | `TMPDIR` |
| `--url` | Remote socket URL | `CONTAINER_HOST` |
| `--version` | Show version | - |

### 3.2 Environment Variables

| Variable | Description |
|:---------|:------------|
| `CONTAINERS_CONF` | Path to containers.conf |
| `CONTAINERS_REGISTRIES_CONF` | Path to registries.conf |
| `CONTAINERS_STORAGE_CONF` | Path to storage.conf |
| `CONTAINER_HOST` | Remote Podman socket URL |
| `CONTAINER_CONNECTION` | Active connection name |
| `CONTAINER_SSHKEY` | SSH key for remote |
| `REGISTRY_AUTH_FILE` | Registry auth file path |
| `XDG_RUNTIME_DIR` | User runtime directory |

### 3.3 Command Categories

| Category | Commands |
|:---------|:---------|
| **Container** | `attach`, `commit`, `cp`, `create`, `diff`, `exec`, `export`, `init`, `inspect`, `kill`, `logs`, `mount`, `pause`, `port`, `prune`, `ps`, `rename`, `restart`, `rm`, `run`, `start`, `stats`, `stop`, `top`, `unmount`, `unpause`, `update`, `wait` |
| **Pod** | `create`, `clone`, `exists`, `inspect`, `kill`, `logs`, `pause`, `prune`, `ps`, `restart`, `rm`, `start`, `stats`, `stop`, `top`, `unpause` |
| **Image** | `build`, `diff`, `exists`, `history`, `import`, `inspect`, `list`, `load`, `mount`, `prune`, `pull`, `push`, `rm`, `save`, `scp`, `search`, `sign`, `tag`, `tree`, `trust`, `unmount`, `untag` |
| **Volume** | `create`, `exists`, `export`, `import`, `inspect`, `ls`, `prune`, `reload`, `rm` |
| **Network** | `connect`, `create`, `disconnect`, `exists`, `inspect`, `ls`, `prune`, `reload`, `rm`, `update` |
| **System** | `connection`, `df`, `events`, `info`, `migrate`, `prune`, `renumber`, `reset`, `service`, `version` |
| **Kube** | `apply`, `down`, `generate`, `play` |
| **Machine** | `info`, `init`, `inspect`, `list`, `os`, `reset`, `rm`, `set`, `ssh`, `start`, `stop` |
| **Compose** | `build`, `config`, `create`, `down`, `events`, `exec`, `images`, `kill`, `logs`, `ls`, `pause`, `port`, `ps`, `pull`, `push`, `restart`, `rm`, `run`, `start`, `stats`, `stop`, `top`, `unpause`, `up`, `version`, `wait` |

---

## 4.0 SpecGenerator Models (F# Type Mappings)

### 4.1 ContainerSpecGenerator (SpecGenerator)

```fsharp
type SpecGenerator = {
    // Identity
    Name: string option
    Image: string

    // Execution
    Command: string list option
    Entrypoint: string list option
    WorkDir: string option
    Env: Map<string, string> option
    EnvHost: bool option

    // Resources
    ResourceLimits: LinuxResources option
    CpuPeriod: uint64 option
    CpuQuota: int64 option
    CpuShares: uint64 option
    Memory: int64 option
    MemorySwap: int64 option

    // Mounts & Storage
    Mounts: Mount list option
    Volumes: NamedVolume list option
    Devices: LinuxDevice list option

    // Network
    NetNS: Namespace option
    Networks: Map<string, PerNetworkOptions> option
    PortMappings: PortMapping list option
    DNSServers: string list option
    DNSSearch: string list option
    DNSOptions: string list option
    HostAdd: string list option

    // Security
    User: string option
    Groups: string list option
    CapAdd: string list option
    CapDrop: string list option
    Privileged: bool option
    ReadOnlyFilesystem: bool option
    SeccompPolicy: string option
    SelinuxOpts: string list option

    // Health
    HealthConfig: Schema2HealthConfig option

    // Lifecycle
    RestartPolicy: string option
    RestartRetries: uint option
    Remove: bool option
    StopSignal: string option
    StopTimeout: uint option
    Timeout: uint option

    // Labels & Annotations
    Labels: Map<string, string> option
    Annotations: Map<string, string> option

    // Misc
    Terminal: bool option
    Stdin: bool option
    PodmanOnly: bool option
}
```

### 4.2 PodSpecGenerator

```fsharp
type PodSpecGenerator = {
    // Identity
    Name: string option
    Hostname: string option

    // Network
    NetNS: Namespace option
    Networks: Map<string, PerNetworkOptions> option
    PortMappings: PortMapping list option
    DNSServers: string list option
    DNSSearch: string list option
    DNSOptions: string list option
    HostAdd: string list option
    NoInfra: bool option
    InfraImage: string option
    InfraName: string option
    InfraCommand: string list option

    // Resource Limits
    ResourceLimits: LinuxResources option
    CpuPeriod: uint64 option
    CpuQuota: int64 option

    // Security
    Userns: Namespace option
    SecurityOpt: string list option

    // Volumes
    Volumes: NamedVolume list option
    VolumesFrom: string list option

    // Labels
    Labels: Map<string, string> option

    // Cgroup
    CgroupParent: string option

    // Infra Container
    InfraContainerSpec: SpecGenerator option
}
```

### 4.3 Supporting Types

```fsharp
/// Linux resource constraints
type LinuxResources = {
    CPU: LinuxCPU option
    Memory: LinuxMemory option
    BlockIO: LinuxBlockIO option
    Pids: LinuxPids option
    Devices: LinuxDeviceCgroup list option
}

type LinuxCPU = {
    Shares: uint64 option
    Quota: int64 option
    Period: uint64 option
    RealtimeRuntime: int64 option
    RealtimePeriod: uint64 option
    Cpus: string option
    Mems: string option
}

type LinuxMemory = {
    Limit: int64 option
    Reservation: int64 option
    Swap: int64 option
    Swappiness: uint64 option
    DisableOOMKiller: bool option
}

/// Mount configuration for volumes and binds
type Mount = {
    Type: MountType
    Source: string
    Target: string
    ReadOnly: bool option
    Consistency: string option
    BindOptions: BindOptions option
    VolumeOptions: VolumeOptions option
    TmpfsOptions: TmpfsOptions option
}

type MountType =
    | Bind
    | Volume
    | Tmpfs
    | Image
    | Devpts

type BindOptions = {
    Propagation: string option  // "private", "rprivate", "shared", "rshared", "slave", "rslave"
    NonRecursive: bool option
    CreateMountpoint: bool option
    SELinuxRelabel: string option  // "z" or "Z"
}

/// Port mapping configuration
type PortMapping = {
    ContainerPort: uint16
    HostPort: uint16 option  // Auto-assigned if None
    HostIP: string option    // Default "0.0.0.0"
    Protocol: PortProtocol
    Range: uint16 option     // Port range count
}

type PortProtocol =
    | TCP
    | UDP
    | SCTP

/// Health check configuration
type Schema2HealthConfig = {
    Test: string list         // ["CMD", "arg1", "arg2"] or ["CMD-SHELL", "cmd"] or ["NONE"]
    Interval: int64 option    // Nanoseconds between checks
    Timeout: int64 option     // Nanoseconds before timeout
    StartPeriod: int64 option // Grace period before first check
    StartInterval: int64 option
    Retries: int option       // Failures before unhealthy
}

/// Named volume reference
type NamedVolume = {
    Name: string
    Dest: string
    Options: string list option
    IsAnonymous: bool option
    SubPath: string option
}

/// Network namespace configuration
type Namespace = {
    NSMode: NamespaceMode
    Value: string option
}

type NamespaceMode =
    | Default
    | Host
    | Path of string
    | Container of string
    | Private
    | NoNetwork
    | Bridge
    | Slirp4netns
    | Pasta

/// Per-network connection options
type PerNetworkOptions = {
    Aliases: string list option
    InterfaceName: string option
    StaticIPs: string list option
    StaticMAC: string option
}

/// Container inspect response (partial)
type ContainerInspectResponse = {
    Id: string
    Created: string
    Path: string
    Args: string list
    State: ContainerState
    Image: string
    ImageName: string
    Name: string
    RestartCount: int
    Driver: string
    Platform: string
    MountLabel: string
    ProcessLabel: string
    AppArmorProfile: string
    HostConfig: HostConfig
    Mounts: MountPoint list
    Config: ContainerConfig
    NetworkSettings: NetworkSettings
}

type ContainerState = {
    Status: string
    Running: bool
    Paused: bool
    Restarting: bool
    OOMKilled: bool
    Dead: bool
    Pid: int
    ExitCode: int
    Error: string
    StartedAt: string
    FinishedAt: string
    Health: HealthState option
}

type HealthState = {
    Status: string  // "starting", "healthy", "unhealthy", "none"
    FailingStreak: int
    Log: HealthCheckLog list option
}

type HealthCheckLog = {
    Start: string
    End: string
    ExitCode: int
    Output: string
}
```

### 4.4 Event Types

```fsharp
/// Podman event from event stream
type PodmanEvent = {
    Type: EventType
    Action: string
    Actor: EventActor
    Time: int64
    TimeNano: int64
    Status: string option
}

type EventType =
    | ContainerEvent
    | ImageEvent
    | PodEvent
    | VolumeEvent
    | NetworkEvent
    | SystemEvent

type EventActor = {
    ID: string
    Attributes: Map<string, string>
}

/// Event filter for streaming
type EventFilter = {
    Container: string list option
    Event: string list option
    Image: string list option
    Pod: string list option
    Volume: string list option
    Type: EventType list option
}
```

---

## 5.0 OODA Probing & Forensics

### 5.1 OODA Loop Integration

| Phase | Podman Operation | Purpose |
|:------|:-----------------|:--------|
| **Observe** | `podman events --format json` | Real-time state tracking |
| **Orient** | `podman inspect` | JSON schema provides "Living Graph" data |
| **Decide** | Analysis of inspect data | Determine corrective actions |
| **Act** | `podman system service --time=0` | Ensure API cell is alive |

### 5.2 Health Probing Commands

```bash
# API liveness
curl --unix-socket /run/user/${UID}/podman/podman.sock http://d/v5.7.0/_ping

# Container health
podman healthcheck run <container>

# System readiness
podman system connection list
podman info --format json

# Event stream
podman events --filter event=start --filter event=die --format json
```

### 5.3 Forensic Inspection Queries

```bash
# Container state
podman inspect --format '{{.State.Status}}' <container>

# Exit code
podman inspect --format '{{.State.ExitCode}}' <container>

# OOM killed
podman inspect --format '{{.State.OOMKilled}}' <container>

# Start time
podman inspect --format '{{.State.StartedAt}}' <container>

# Pod containers
podman pod inspect --format '{{.Containers}}' <pod>

# Resource usage
podman stats --no-stream --format json <container>
```

---

## 6.0 Debugging & Error Patterns (EP)

### 6.1 Exit Codes

| Exit Code | Source | Description | Recovery Action |
|:----------|:-------|:------------|:----------------|
| **0** | Container | Normal exit | None required |
| **125** | Podman | Podman-internal defect (no disk space, permission) | Check system resources |
| **126** | OCI Runtime | Execution failure (permission denied) | Check container config |
| **127** | Container | Missing command in `$PATH` | Verify entrypoint/cmd |
| **137** | Kernel | SIGKILL (often OOM) | Increase memory limits |
| **139** | Container | SIGSEGV (segmentation fault) | Debug application |
| **143** | Container | SIGTERM (graceful stop) | Expected behavior |

### 6.2 Error Pattern Detection

| Pattern ID | Pattern | Detection Method | Severity |
|:-----------|:--------|:-----------------|:---------|
| **EP-POD-001** | Container won't start | `State.Error` in inspect | HIGH |
| **EP-POD-002** | OOMKilled | `State.OOMKilled == true` | CRITICAL |
| **EP-POD-003** | Network unreachable | DNS resolution failure | HIGH |
| **EP-POD-004** | Volume mount failure | `Mounts[].Source` not found | HIGH |
| **EP-POD-005** | Image pull failure | 401/404 from registry | MEDIUM |
| **EP-POD-006** | Resource exhaustion | Exit code 137 + OOMKilled | CRITICAL |
| **EP-POD-007** | Socket permission denied | EACCES on socket | CRITICAL |
| **EP-POD-008** | Storage driver error | `storage.conf` misconfigured | HIGH |

### 6.3 Recovery Procedures

```fsharp
type RecoveryAction =
    | RestartContainer
    | IncreaseResources of memory: int64 * cpu: float
    | RecreateContainer
    | PullImage of reference: string
    | RepairVolume of name: string
    | ResetNetwork
    | EmergencyStop

let determineRecovery (error: ErrorPattern) : RecoveryAction =
    match error with
    | EP_POD_001 -> RecreateContainer
    | EP_POD_002 -> IncreaseResources(512L * 1024L * 1024L, 1.0)
    | EP_POD_003 -> ResetNetwork
    | EP_POD_004 -> RepairVolume error.VolumeName
    | EP_POD_005 -> PullImage error.ImageRef
    | EP_POD_006 -> IncreaseResources(1024L * 1024L * 1024L, 2.0)
    | EP_POD_007 -> EmergencyStop
    | EP_POD_008 -> EmergencyStop
    | _ -> RestartContainer
```

---

## 7.0 STAMP Safety Constraints

### 7.1 Core Safety Constraints (SC-POD)

| ID | Constraint | Rationale | Verification |
|:---|:-----------|:----------|:-------------|
| **SC-POD-001** | Orchestrator SHALL use `crun` for sub-10ms container startup | Performance requirement | `podman info --format '{{.Host.OCIRuntime.Name}}'` |
| **SC-POD-002** | Rootless containers SHALL NOT possess capabilities beyond user UID | Security isolation | `podman inspect --format '{{.HostConfig.CapAdd}}'` |
| **SC-POD-003** | API socket MUST be verified for permissions before binding | Access control | `stat /run/user/${UID}/podman/podman.sock` |
| **SC-POD-004** | Containers SHALL have memory limits defined | Resource protection | `podman inspect --format '{{.HostConfig.Memory}}'` |
| **SC-POD-005** | Images SHALL be pulled from localhost/ registry only | Supply chain security | Check image reference prefix |
| **SC-POD-006** | Health checks SHALL be defined for all long-running containers | Availability | `podman inspect --format '{{.Config.Healthcheck}}'` |
| **SC-POD-007** | Volumes MUST be mounted with appropriate SELinux labels | Security context | Check `:z` or `:Z` suffix |
| **SC-POD-008** | Network isolation SHALL be enforced for sensitive workloads | Network security | Verify network mode |
| **SC-POD-009** | Container restarts SHALL be limited to prevent restart loops | Stability | `RestartRetries <= 5` |
| **SC-POD-010** | Checkpoint/restore operations SHALL preserve TCP connections | State continuity | `--tcp-established` flag |

### 7.2 Orchestrator Safety Constraints (SC-ORCH)

| ID | Constraint | Rationale |
|:---|:-----------|:----------|
| **SC-ORCH-001** | CEPAF# SHALL verify API socket availability before operations | Prevent blind operations |
| **SC-ORCH-002** | Container creation SHALL validate SpecGenerator schema | Prevent malformed requests |
| **SC-ORCH-003** | Pod operations SHALL verify infra container health first | Dependency ordering |
| **SC-ORCH-004** | Event stream SHALL be monitored for unexpected container deaths | Real-time awareness |
| **SC-ORCH-005** | Resource limits SHALL be enforced at orchestration time | Proactive protection |

### 7.3 Data Integrity Constraints (SC-DATA)

| ID | Constraint | Rationale |
|:---|:-----------|:----------|
| **SC-DATA-001** | Volumes SHALL be backed up before destructive operations | Data protection |
| **SC-DATA-002** | Checkpoint data SHALL be encrypted at rest | Security |
| **SC-DATA-003** | Event logs SHALL be persisted to durable storage | Audit trail |

---

## 8.0 LTL Safety Properties

### 8.1 Container Safety Properties

```
LTL-POD-S1: □(ContainerRunning ⟹ MemoryLimitDefined)
LTL-POD-S2: □(ContainerCreated ⟹ ◇(ContainerStarted ∨ ContainerRemoved))
LTL-POD-S3: □(OOMKilled ⟹ ◇(MemoryIncreased ∨ ContainerRemoved))
LTL-POD-S4: □¬(RootlessContainer ∧ CapSysAdmin)
LTL-POD-S5: □(HealthCheckFailed ⟹ ◇(ContainerRestarted ∨ AlertRaised))
```

### 8.2 Orchestration Liveness Properties

```
LTL-POD-L1: □(CreateRequest ⟹ ◇(ContainerCreated ∨ ErrorReported))
LTL-POD-L2: □(StopRequest ⟹ ◇(ContainerStopped))
LTL-POD-L3: □(PodStartRequest ⟹ ◇(AllContainersRunning ∨ ErrorReported))
LTL-POD-L4: □(EventOccurred ⟹ ◇EventProcessed)
```

---

## 9.0 Checkpoint/Restore (CRIU) Integration

### 9.1 Checkpoint Operations

| Option | Description | Use Case |
|:-------|:------------|:---------|
| `--keep` | Keep checkpoint data after restore | Debugging |
| `--leave-running` | Don't stop container after checkpoint | Live migration prep |
| `--tcp-established` | Checkpoint TCP connections | Stateful migration |
| `--file-locks` | Checkpoint file locks | Database containers |
| `--export` | Export checkpoint to tar archive | Cross-host migration |
| `--compress` | Compress checkpoint archive | Storage efficiency |

### 9.2 Restore Operations

| Option | Description | Use Case |
|:-------|:------------|:---------|
| `--import` | Import from tar archive | Cross-host restore |
| `--name` | New container name | Clone container |
| `--tcp-established` | Restore TCP connections | Stateful restore |
| `--ignore-rootfs` | Ignore rootfs changes | Fast restore |
| `--ignore-volumes` | Don't restore volume data | Selective restore |

### 9.3 Migration Workflow

```
Source Host                          Destination Host
     │                                      │
     ▼                                      │
┌─────────────────┐                         │
│ podman checkpoint│                        │
│ --export=ckpt.tar│                        │
│ --tcp-established│                        │
└────────┬────────┘                         │
         │                                  │
         │ Transfer ckpt.tar                │
         │──────────────────────────────────▶
         │                                  │
         │                          ┌───────▼────────┐
         │                          │ podman restore │
         │                          │ --import=ckpt  │
         │                          │ --tcp-established
         │                          └────────────────┘
```

---

## 10.0 Systemd Integration

### 10.1 Generated Unit Types

| Type | Command | Use Case |
|:-----|:--------|:---------|
| Container | `podman generate systemd --name <container>` | Single container service |
| Pod | `podman generate systemd --name <pod>` | Pod with all containers |
| New | `podman generate systemd --new` | Recreate on start (immutable) |

### 10.2 Quadlet Integration (Podman 4.4+)

| Unit Type | Extension | Description |
|:----------|:----------|:------------|
| Container | `.container` | Container definition |
| Pod | `.pod` | Pod definition |
| Volume | `.volume` | Volume definition |
| Network | `.network` | Network definition |
| Image | `.image` | Image pull definition |
| Build | `.build` | Image build definition |
| Kube | `.kube` | Kubernetes YAML |

**Quadlet Location**: `~/.config/containers/systemd/` (rootless) or `/etc/containers/systemd/` (rootful)

---

## 11.0 Security Hardening

### 11.1 Rootless Best Practices

| Practice | Implementation |
|:---------|:---------------|
| User namespace | Enabled by default |
| UID/GID mapping | `/etc/subuid`, `/etc/subgid` |
| No capabilities | `--cap-drop=ALL` |
| Read-only rootfs | `--read-only` |
| No new privileges | `--security-opt=no-new-privileges` |
| Seccomp profile | `--security-opt seccomp=profile.json` |

### 11.2 SELinux Labels

| Label | Usage |
|:------|:------|
| `:z` | Shared between containers |
| `:Z` | Private to container (relabel) |
| `:U` | Use UID/GID from container |

### 11.3 Network Isolation

| Mode | Security Level | Use Case |
|:-----|:---------------|:---------|
| `none` | Maximum | Air-gapped containers |
| `host` | Minimum | Performance testing only |
| `bridge` | Standard | Default isolation |
| `pasta` | Enhanced | Rootless with port mapping |
| `slirp4netns` | Enhanced | Legacy rootless |

---

## 12.0 Metrics & Observability

### 12.1 Stats Endpoints

| Metric | Source | Format |
|:-------|:-------|:-------|
| CPU % | `/containers/{id}/stats` | `cpu_stats.cpu_usage.total_usage` |
| Memory | `/containers/{id}/stats` | `memory_stats.usage` |
| Memory Limit | `/containers/{id}/stats` | `memory_stats.limit` |
| Network I/O | `/containers/{id}/stats` | `networks.*.rx_bytes`, `tx_bytes` |
| Block I/O | `/containers/{id}/stats` | `blkio_stats` |
| PIDs | `/containers/{id}/stats` | `pids_stats.current` |

### 12.2 Event Types

| Type | Actions |
|:-----|:--------|
| container | `attach`, `checkpoint`, `cleanup`, `commit`, `create`, `exec`, `export`, `import`, `init`, `kill`, `mount`, `pause`, `prune`, `remove`, `rename`, `restart`, `restore`, `start`, `stop`, `sync`, `unmount`, `unpause`, `update` |
| image | `build`, `import`, `load`, `pull`, `push`, `remove`, `save`, `tag`, `untag` |
| pod | `create`, `kill`, `pause`, `remove`, `start`, `stop`, `unpause` |
| volume | `create`, `prune`, `remove` |
| network | `connect`, `create`, `disconnect`, `remove` |
| system | `refresh`, `renumber` |

---

## 13.0 Reference Documents

| Document | URL |
|:---------|:----|
| Podman Documentation | https://podman.io/docs |
| Podman Installation | https://podman.io/docs/installation |
| Podman Checkpoint | https://podman.io/docs/checkpoint |
| Podman Tutorials | https://docs.podman.io/en/latest/Tutorials.html |
| Podman GitHub | https://github.com/containers/podman |
| Podman Commands | https://docs.podman.io/en/latest/Commands.html |
| REST API v5.7 | https://docs.podman.io/en/latest/_static/api.html?version=v5.7 |
| API Swagger YAML | https://storage.googleapis.com/libpod-master-releases/swagger-v5.7.yaml |

---

## 14.0 Advanced Features (v5.x)

### 14.1 Artifact Management

OCI Artifacts allow storing non-container data in registries:

| Command | Description |
|:--------|:------------|
| `podman artifact add` | Add file to local artifact store |
| `podman artifact inspect` | Display artifact metadata |
| `podman artifact ls` | List local artifacts |
| `podman artifact pull` | Pull artifact from registry |
| `podman artifact push` | Push artifact to registry |
| `podman artifact rm` | Remove local artifact |

### 14.2 Farm (Distributed Builds)

Build images on remote machines:

| Command | Description |
|:--------|:------------|
| `podman farm build` | Build on farm nodes |
| `podman farm create` | Create a farm |
| `podman farm list` | List farms |
| `podman farm remove` | Remove a farm |
| `podman farm update` | Update farm configuration |

### 14.3 Compose Integration

| Command | Description |
|:--------|:------------|
| `podman compose up` | Create and start containers |
| `podman compose down` | Stop and remove containers |
| `podman compose ps` | List containers |
| `podman compose logs` | View output from containers |
| `podman compose build` | Build or rebuild services |
| `podman compose pull` | Pull service images |
| `podman compose exec` | Execute command in container |

### 14.4 Machine Management (Podman Desktop)

| Command | Description |
|:--------|:------------|
| `podman machine init` | Initialize a VM |
| `podman machine start` | Start a VM |
| `podman machine stop` | Stop a VM |
| `podman machine ssh` | SSH into VM |
| `podman machine rm` | Remove a VM |
| `podman machine list` | List VMs |

---

## 15.0 F# Library Module Structure

```
Cepaf.Podman/
├── Domain.fs           # Core types (ontology types)
├── Client.fs           # HTTP client for Unix socket
├── Api/
│   ├── Containers.fs   # Container operations
│   ├── Pods.fs         # Pod operations
│   ├── Images.fs       # Image operations
│   ├── Volumes.fs      # Volume operations
│   ├── Networks.fs     # Network operations
│   └── System.fs       # System operations
├── Compose/
│   ├── Parser.fs       # YAML parsing
│   └── Orchestrator.fs # Compose operations
├── Events/
│   ├── Stream.fs       # Event streaming
│   └── Handler.fs      # Event processing
├── Health/
│   ├── Probes.fs       # Health check execution
│   └── Recovery.fs     # Auto-recovery actions
└── Safety/
    ├── Constraints.fs  # STAMP constraints
    └── Validators.fs   # Pre-flight validation
```

---

**Certified By**: Claude Code (Opus 4.5)
**Target Component**: CEPAF# Podman Module (`Cepaf.Podman`)
**Status**: FORMALIZED (v3.0.0)
