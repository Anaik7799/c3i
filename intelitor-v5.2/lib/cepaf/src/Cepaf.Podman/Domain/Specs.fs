namespace Cepaf.Podman.Domain

open System

// ============================================================================
// Resource Configuration
// ============================================================================

/// CPU resource limits
type CpuConfig = {
    Shares: uint64 option
    Quota: int64 option
    Period: uint64 option
    Cpus: string option
    Mems: string option
}

module CpuConfig =
    let empty = {
        Shares = None
        Quota = None
        Period = None
        Cpus = None
        Mems = None
    }

    let withShares shares config = { config with Shares = Some shares }
    let withQuota quota config = { config with Quota = Some quota }
    let withCpus cpus config = { config with Cpus = Some cpus }

/// Memory resource limits
type MemoryConfig = {
    Limit: int64 option
    Reservation: int64 option
    Swap: int64 option
    Swappiness: uint64 option
    DisableOOMKiller: bool option
}

module MemoryConfig =
    let empty = {
        Limit = None
        Reservation = None
        Swap = None
        Swappiness = None
        DisableOOMKiller = None
    }

    let withLimit limit config = { config with Limit = Some limit }
    let withReservation res config = { config with Reservation = Some res }
    let withSwap swap config = { config with Swap = Some swap }

    /// Create config with limit in MB
    let withLimitMB mb config = { config with Limit = Some (int64 mb * 1024L * 1024L) }

    /// Create config with limit in GB
    let withLimitGB gb config = { config with Limit = Some (int64 gb * 1024L * 1024L * 1024L) }

/// Combined resource configuration
type ResourceConfig = {
    Cpu: CpuConfig option
    Memory: MemoryConfig option
    PidsLimit: int64 option
}

module ResourceConfig =
    let empty = {
        Cpu = None
        Memory = None
        PidsLimit = None
    }

    let withCpu cpu config = { config with Cpu = Some cpu }
    let withMemory mem config = { config with Memory = Some mem }
    let withPidsLimit limit config = { config with PidsLimit = Some limit }

// ============================================================================
// Health Check Configuration
// ============================================================================

/// Health check test type
[<RequireQualifiedAccess>]
type HealthCheckTest =
    | Cmd of string list
    | CmdShell of string
    | None

module HealthCheckTest =
    let toStringList (test: HealthCheckTest) : string list =
        match test with
        | HealthCheckTest.Cmd args -> "CMD" :: args
        | HealthCheckTest.CmdShell cmd -> ["CMD-SHELL"; cmd]
        | HealthCheckTest.None -> ["NONE"]

/// Health check configuration
type HealthCheckConfig = {
    Test: HealthCheckTest
    Interval: TimeSpan option
    Timeout: TimeSpan option
    StartPeriod: TimeSpan option
    StartInterval: TimeSpan option
    Retries: int option
}

module HealthCheckConfig =
    let create test = {
        Test = test
        Interval = None
        Timeout = None
        StartPeriod = None
        StartInterval = None
        Retries = None
    }

    let withInterval interval config = { config with Interval = Some interval }
    let withTimeout timeout config = { config with Timeout = Some timeout }
    let withStartPeriod period config = { config with StartPeriod = Some period }
    let withRetries retries config = { config with Retries = Some retries }

    /// Create HTTP health check
    let httpCheck url interval retries =
        { Test = HealthCheckTest.CmdShell (sprintf "curl -f %s || exit 1" url)
          Interval = Some interval
          Timeout = Some (TimeSpan.FromSeconds(5.0))
          StartPeriod = Some (TimeSpan.FromSeconds(10.0))
          StartInterval = None
          Retries = Some retries }

    /// Create TCP health check
    let tcpCheck host port interval retries =
        { Test = HealthCheckTest.CmdShell (sprintf "nc -z %s %d || exit 1" host port)
          Interval = Some interval
          Timeout = Some (TimeSpan.FromSeconds(5.0))
          StartPeriod = Some (TimeSpan.FromSeconds(10.0))
          StartInterval = None
          Retries = Some retries }

// ============================================================================
// Security Configuration
// ============================================================================

/// Security configuration
type SecurityConfig = {
    User: string option
    Groups: string list
    CapAdd: string list
    CapDrop: string list
    Privileged: bool
    ReadOnlyRootfs: bool
    NoNewPrivileges: bool
    SeccompPolicy: string option
    SelinuxOpts: string list
}

module SecurityConfig =
    let empty = {
        User = None
        Groups = []
        CapAdd = []
        CapDrop = []
        Privileged = false
        ReadOnlyRootfs = false
        NoNewPrivileges = false
        SeccompPolicy = None
        SelinuxOpts = []
    }

    let withUser user config = { config with User = Some user }
    let withGroups groups config = { config with Groups = groups }
    let addCapability cap config = { config with CapAdd = cap :: config.CapAdd }
    let dropCapability cap config = { config with CapDrop = cap :: config.CapDrop }
    let withPrivileged config = { config with Privileged = true }
    let withReadOnlyRootfs config = { config with ReadOnlyRootfs = true }
    let withNoNewPrivileges config = { config with NoNewPrivileges = true }

    /// Hardened security config (recommended for production)
    let hardened = {
        User = None
        Groups = []
        CapAdd = []
        CapDrop = ["ALL"]
        Privileged = false
        ReadOnlyRootfs = true
        NoNewPrivileges = true
        SeccompPolicy = None
        SelinuxOpts = []
    }

// ============================================================================
// Network Configuration
// ============================================================================

/// Network namespace mode
[<RequireQualifiedAccess>]
type NetworkMode =
    | Default
    | Bridge
    | Host
    | None
    | Container of string
    | Slirp4netns
    | Pasta
    | Private
    | Custom of string

module NetworkMode =
    let toString (mode: NetworkMode) : string =
        match mode with
        | NetworkMode.Default -> ""
        | NetworkMode.Bridge -> "bridge"
        | NetworkMode.Host -> "host"
        | NetworkMode.None -> "none"
        | NetworkMode.Container id -> sprintf "container:%s" id
        | NetworkMode.Slirp4netns -> "slirp4netns"
        | NetworkMode.Pasta -> "pasta"
        | NetworkMode.Private -> "private"
        | NetworkMode.Custom name -> name

/// Per-network options
type PerNetworkOptions = {
    Aliases: string list
    InterfaceName: string option
    StaticIPs: string list
    StaticMAC: string option
}

module PerNetworkOptions =
    let empty = {
        Aliases = []
        InterfaceName = None
        StaticIPs = []
        StaticMAC = None
    }

    let withAlias alias opts = { opts with Aliases = alias :: opts.Aliases }
    let withStaticIP ip opts = { opts with StaticIPs = ip :: opts.StaticIPs }
    let withStaticMAC mac opts = { opts with StaticMAC = Some mac }

/// DNS configuration
type DnsConfig = {
    Servers: string list
    Search: string list
    Options: string list
}

module DnsConfig =
    let empty = { Servers = []; Search = []; Options = [] }
    let withServer server config = { config with Servers = server :: config.Servers }
    let withSearch domain config = { config with Search = domain :: config.Search }

/// Network configuration for container (SC-CONSOL-001)
/// Note: For port/hostname config, use Cepaf.Config.MeshConfig.NetworkConfig
/// This type is for container-level networking (mode, networks, dns)
type ContainerNetworkConfig = {
    Mode: NetworkMode
    Networks: Map<string, PerNetworkOptions>
    Dns: DnsConfig option
    HostsAdd: string list
}

module ContainerNetworkConfig =
    let empty = {
        Mode = NetworkMode.Default
        Networks = Map.empty
        Dns = None
        HostsAdd = []
    }

    let withMode mode config = { config with Mode = mode }
    let addNetwork name opts config =
        { config with Networks = config.Networks |> Map.add name opts }
    let withDns dns config = { config with Dns = Some dns }
    let addHost host config = { config with HostsAdd = host :: config.HostsAdd }

/// DEPRECATED: Alias for backwards compatibility - use ContainerNetworkConfig
type NetworkConfig = ContainerNetworkConfig

// ============================================================================
// Restart Policy
// ============================================================================

/// Restart policy type
[<RequireQualifiedAccess>]
type RestartPolicyType =
    | No
    | Always
    | OnFailure
    | UnlessStopped

module RestartPolicyType =
    let toString (policy: RestartPolicyType) : string =
        match policy with
        | RestartPolicyType.No -> "no"
        | RestartPolicyType.Always -> "always"
        | RestartPolicyType.OnFailure -> "on-failure"
        | RestartPolicyType.UnlessStopped -> "unless-stopped"

/// Restart policy configuration
type RestartPolicy = {
    Policy: RestartPolicyType
    MaxRetries: int option
}

module RestartPolicy =
    let no = { Policy = RestartPolicyType.No; MaxRetries = None }
    let always = { Policy = RestartPolicyType.Always; MaxRetries = None }
    let onFailure retries = { Policy = RestartPolicyType.OnFailure; MaxRetries = Some retries }
    let unlessStopped = { Policy = RestartPolicyType.UnlessStopped; MaxRetries = None }

// ============================================================================
// Container Spec Generator
// ============================================================================

/// Container creation specification
type ContainerSpec = {
    // Identity
    Name: string option
    Image: string

    // Execution
    Command: string list option
    Entrypoint: string list option
    WorkDir: string option
    Env: Map<string, string>
    EnvFile: string list

    // Resources
    Resources: ResourceConfig option

    // Storage
    Mounts: Mount list
    Volumes: NamedVolume list

    // Network
    Network: NetworkConfig option
    PortMappings: PortMapping list

    // Security
    Security: SecurityConfig option

    // Health
    HealthCheck: HealthCheckConfig option

    // Lifecycle
    RestartPolicy: RestartPolicy option
    StopSignal: string option
    StopTimeout: int option
    Remove: bool

    // Labels & Annotations
    Labels: Map<string, string>
    Annotations: Map<string, string>

    // Misc
    Hostname: string option
    Terminal: bool
    Stdin: bool
}

/// Container spec builder
module ContainerSpec =

    /// Create minimal container spec
    let create image = {
        Name = None
        Image = image
        Command = None
        Entrypoint = None
        WorkDir = None
        Env = Map.empty
        EnvFile = []
        Resources = None
        Mounts = []
        Volumes = []
        Network = None
        PortMappings = []
        Security = None
        HealthCheck = None
        RestartPolicy = None
        StopSignal = None
        StopTimeout = None
        Remove = false
        Labels = Map.empty
        Annotations = Map.empty
        Hostname = None
        Terminal = false
        Stdin = false
    }

    // Identity
    let withName name spec = { spec with Name = Some name }

    // Execution
    let withCommand cmd spec = { spec with Command = Some cmd }
    let withEntrypoint ep spec = { spec with Entrypoint = Some ep }
    let withWorkDir dir spec = { spec with WorkDir = Some dir }
    let withEnv key value spec = { spec with Env = spec.Env |> Map.add key value }
    let withEnvMap env spec = { spec with Env = Map.fold (fun m k v -> Map.add k v m) spec.Env env }
    let withEnvFile file spec = { spec with EnvFile = file :: spec.EnvFile }

    // Resources
    let withResources resources spec = { spec with Resources = Some resources }
    let withMemoryLimit bytes spec =
        let mem = MemoryConfig.empty |> MemoryConfig.withLimit bytes
        let res = spec.Resources |> Option.defaultValue ResourceConfig.empty |> ResourceConfig.withMemory mem
        { spec with Resources = Some res }
    let withMemoryLimitMB mb spec = withMemoryLimit (int64 mb * 1024L * 1024L) spec
    let withMemoryLimitGB gb spec = withMemoryLimit (int64 gb * 1024L * 1024L * 1024L) spec

    // Storage
    let withMount mount spec = { spec with Mounts = mount :: spec.Mounts }
    let withBindMount source target spec =
        withMount (Mount.createBind source target) spec
    let withVolume name target spec =
        { spec with Volumes = { Name = name; Dest = target; Options = [] } :: spec.Volumes }

    // Network
    let withNetwork config spec = { spec with Network = Some config }
    let withPort hostPort containerPort spec =
        let port = { PortMapping.create containerPort with HostPort = Some hostPort }
        { spec with PortMappings = port :: spec.PortMappings }
    let withPortTCP hostPort containerPort spec = withPort hostPort containerPort spec
    let withPortUDP hostPort containerPort spec =
        let port = { PortMapping.create containerPort with HostPort = Some hostPort; Protocol = PortProtocol.UDP }
        { spec with PortMappings = port :: spec.PortMappings }

    // Security
    let withSecurity security spec = { spec with Security = Some security }
    let withUser user spec =
        let sec = spec.Security |> Option.defaultValue SecurityConfig.empty |> SecurityConfig.withUser user
        { spec with Security = Some sec }
    let withPrivileged spec =
        let sec = spec.Security |> Option.defaultValue SecurityConfig.empty |> SecurityConfig.withPrivileged
        { spec with Security = Some sec }
    let withReadOnlyRootfs spec =
        let sec = spec.Security |> Option.defaultValue SecurityConfig.empty |> SecurityConfig.withReadOnlyRootfs
        { spec with Security = Some sec }

    // Health
    let withHealthCheck health spec = { spec with HealthCheck = Some health }
    let withHttpHealthCheck url interval retries spec =
        withHealthCheck (HealthCheckConfig.httpCheck url interval retries) spec
    let withTcpHealthCheck host port interval retries spec =
        withHealthCheck (HealthCheckConfig.tcpCheck host port interval retries) spec

    // Lifecycle
    let withRestartPolicy policy spec = { spec with RestartPolicy = Some policy }
    let withRestartAlways spec = withRestartPolicy RestartPolicy.always spec
    let withRestartOnFailure retries spec = withRestartPolicy (RestartPolicy.onFailure retries) spec
    let withStopTimeout seconds spec = { spec with StopTimeout = Some seconds }
    let withAutoRemove spec = { spec with Remove = true }

    // Labels
    let withLabel key value spec = { spec with Labels = spec.Labels |> Map.add key value }
    let withLabels labels spec = { spec with Labels = Map.fold (fun m k v -> Map.add k v m) spec.Labels labels }

    // Misc
    let withHostname hostname spec = { spec with Hostname = Some hostname }
    let withTerminal spec = { spec with Terminal = true }
    let withStdin spec = { spec with Stdin = true }

// ============================================================================
// Pod Spec Generator
// ============================================================================

/// Pod creation specification
type PodSpec = {
    // Identity
    Name: string option
    Hostname: string option

    // Network
    Network: NetworkConfig option
    PortMappings: PortMapping list

    // Infra container
    NoInfra: bool
    InfraImage: string option
    InfraName: string option
    InfraCommand: string list option

    // Resources
    Resources: ResourceConfig option

    // Volumes
    Volumes: NamedVolume list

    // Security
    Userns: string option
    SecurityOpt: string list

    // Labels
    Labels: Map<string, string>

    // Cgroup
    CgroupParent: string option

    // Shared namespaces
    ShareIPC: bool
    ShareNet: bool
    ShareUTS: bool
    SharePID: bool
    ShareCgroup: bool
}

module PodSpec =

    /// Create minimal pod spec
    let create () = {
        Name = None
        Hostname = None
        Network = None
        PortMappings = []
        NoInfra = false
        InfraImage = None
        InfraName = None
        InfraCommand = None
        Resources = None
        Volumes = []
        Userns = None
        SecurityOpt = []
        Labels = Map.empty
        CgroupParent = None
        ShareIPC = true
        ShareNet = true
        ShareUTS = true
        SharePID = false
        ShareCgroup = true
    }

    let withName name spec = { spec with Name = Some name }
    let withHostname hostname spec = { spec with Hostname = Some hostname }
    let withNetwork config spec = { spec with Network = Some config }
    let withPort hostPort containerPort spec =
        let port = { PortMapping.create containerPort with HostPort = Some hostPort }
        { spec with PortMappings = port :: spec.PortMappings }
    let withNoInfra spec = { spec with NoInfra = true }
    let withInfraImage image spec = { spec with InfraImage = Some image }
    let withResources resources spec = { spec with Resources = Some resources }
    let withVolume name target spec =
        { spec with Volumes = { Name = name; Dest = target; Options = [] } :: spec.Volumes }
    let withLabel key value spec = { spec with Labels = spec.Labels |> Map.add key value }
    let withSharePID spec = { spec with SharePID = true }
    let withoutShareNet spec = { spec with ShareNet = false }

// ============================================================================
// Volume Spec
// ============================================================================

/// Volume creation specification
type VolumeSpec = {
    Name: string
    Driver: VolumeDriver
    Labels: Map<string, string>
    Options: Map<string, string>
}

module VolumeSpec =
    let create name = {
        Name = name
        Driver = VolumeDriver.Local
        Labels = Map.empty
        Options = Map.empty
    }

    let withDriver driver spec = { spec with Driver = driver }
    let withLabel key value spec = { spec with Labels = spec.Labels |> Map.add key value }
    let withOption key value spec = { spec with Options = spec.Options |> Map.add key value }

// ============================================================================
// Network Spec
// ============================================================================

/// Network creation specification
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
    let create name = {
        Name = name
        Driver = NetworkDriver.Bridge
        Internal = false
        DnsEnabled = true
        Subnets = []
        Labels = Map.empty
        Options = Map.empty
    }

    let withDriver driver spec = { spec with Driver = driver }
    let withInternal spec = { spec with Internal = true }
    let withoutDns spec = { spec with DnsEnabled = false }
    let withSubnet subnet gateway spec =
        { spec with Subnets = { Subnet = subnet; Gateway = gateway } :: spec.Subnets }
    let withLabel key value spec = { spec with Labels = spec.Labels |> Map.add key value }
    let withOption key value spec = { spec with Options = spec.Options |> Map.add key value }
