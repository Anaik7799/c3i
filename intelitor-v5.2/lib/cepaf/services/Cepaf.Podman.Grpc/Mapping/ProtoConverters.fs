namespace Cepaf.Podman.Grpc.Mapping

open System
open Google.Protobuf.WellKnownTypes
open Cepaf.Podman.Domain
open Cepaf.Podman.Health

/// Converters between F# domain types and gRPC proto types
module ProtoConverters =

    // ========================================================================
    // Timestamp Conversions
    // ========================================================================

    let toTimestamp (dto: DateTimeOffset) : Timestamp =
        Timestamp.FromDateTimeOffset(dto)

    let fromTimestamp (ts: Timestamp) : DateTimeOffset =
        ts.ToDateTimeOffset()

    let toOptionalTimestamp (dto: DateTimeOffset option) : Timestamp =
        match dto with
        | Some d -> toTimestamp d
        | None -> Timestamp()

    let toDuration (ts: TimeSpan) : Duration =
        Duration.FromTimeSpan(ts)

    // ========================================================================
    // Enum Conversions
    // ========================================================================

    let toContainerStatusType (status: ContainerStatus) : ContainerStatusType =
        match status with
        | ContainerStatus.Created -> ContainerStatusType.ContainerStatusCreated
        | ContainerStatus.Running -> ContainerStatusType.ContainerStatusRunning
        | ContainerStatus.Paused -> ContainerStatusType.ContainerStatusPaused
        | ContainerStatus.Restarting -> ContainerStatusType.ContainerStatusRestarting
        | ContainerStatus.Removing -> ContainerStatusType.ContainerStatusRemoving
        | ContainerStatus.Exited _ -> ContainerStatusType.ContainerStatusExited
        | ContainerStatus.Dead _ -> ContainerStatusType.ContainerStatusDead
        | ContainerStatus.Unknown _ -> ContainerStatusType.ContainerStatusUnknown

    let fromContainerStatusType (status: ContainerStatusType) : ContainerStatus =
        match status with
        | ContainerStatusType.ContainerStatusCreated -> ContainerStatus.Created
        | ContainerStatusType.ContainerStatusRunning -> ContainerStatus.Running
        | ContainerStatusType.ContainerStatusPaused -> ContainerStatus.Paused
        | ContainerStatusType.ContainerStatusRestarting -> ContainerStatus.Restarting
        | ContainerStatusType.ContainerStatusRemoving -> ContainerStatus.Removing
        | ContainerStatusType.ContainerStatusExited -> ContainerStatus.Exited 0
        | ContainerStatusType.ContainerStatusDead -> ContainerStatus.Dead "unknown"
        | _ -> ContainerStatus.Unknown "unknown"

    let toHealthStatusType (status: HealthStatus) : HealthStatusType =
        match status with
        | HealthStatus.Starting -> HealthStatusType.HealthStatusStarting
        | HealthStatus.Healthy -> HealthStatusType.HealthStatusHealthy
        | HealthStatus.Unhealthy _ -> HealthStatusType.HealthStatusUnhealthy
        | HealthStatus.NoHealthcheck -> HealthStatusType.HealthStatusNoHealthcheck
        | HealthStatus.Unknown _ -> HealthStatusType.HealthStatusUnknown

    let toPortProtocol (protocol: PortProtocol) : Cepaf.Podman.Grpc.PortProtocol =
        match protocol with
        | PortProtocol.TCP -> Cepaf.Podman.Grpc.PortProtocol.Tcp
        | PortProtocol.UDP -> Cepaf.Podman.Grpc.PortProtocol.Udp
        | PortProtocol.SCTP -> Cepaf.Podman.Grpc.PortProtocol.Sctp

    let fromPortProtocol (protocol: Cepaf.Podman.Grpc.PortProtocol) : PortProtocol =
        match protocol with
        | Cepaf.Podman.Grpc.PortProtocol.Udp -> PortProtocol.UDP
        | Cepaf.Podman.Grpc.PortProtocol.Sctp -> PortProtocol.SCTP
        | _ -> PortProtocol.TCP

    let toMountType (mt: MountType) : Cepaf.Podman.Grpc.MountType =
        match mt with
        | MountType.Bind -> Cepaf.Podman.Grpc.MountType.Bind
        | MountType.Volume -> Cepaf.Podman.Grpc.MountType.Volume
        | MountType.Tmpfs -> Cepaf.Podman.Grpc.MountType.Tmpfs
        | MountType.Image -> Cepaf.Podman.Grpc.MountType.Image
        | MountType.Devpts -> Cepaf.Podman.Grpc.MountType.Devpts

    let fromMountType (mt: Cepaf.Podman.Grpc.MountType) : MountType =
        match mt with
        | Cepaf.Podman.Grpc.MountType.Volume -> MountType.Volume
        | Cepaf.Podman.Grpc.MountType.Tmpfs -> MountType.Tmpfs
        | Cepaf.Podman.Grpc.MountType.Image -> MountType.Image
        | Cepaf.Podman.Grpc.MountType.Devpts -> MountType.Devpts
        | _ -> MountType.Bind

    // ========================================================================
    // Complex Type Conversions: Domain -> Proto
    // ========================================================================

    let toKeyValue (key: string) (value: string) : KeyValue =
        let kv = KeyValue()
        kv.Key <- key
        kv.Value <- value
        kv

    let toKeyValueList (map: Map<string, string>) : seq<KeyValue> =
        map |> Map.toSeq |> Seq.map (fun (k, v) -> toKeyValue k v)

    let toPortMappingProto (pm: PortMapping) : Cepaf.Podman.Grpc.PortMapping =
        let proto = Cepaf.Podman.Grpc.PortMapping()
        proto.ContainerPort <- uint32 pm.ContainerPort
        proto.HostPort <- pm.HostPort |> Option.map uint32 |> Option.defaultValue 0u
        proto.HostIp <- pm.HostIP |> Option.defaultValue ""
        proto.Protocol <- toPortProtocol pm.Protocol
        proto.Range <- pm.Range |> Option.map uint32 |> Option.defaultValue 0u
        proto

    let toMountProto (m: Mount) : Cepaf.Podman.Grpc.Mount =
        let proto = Cepaf.Podman.Grpc.Mount()
        proto.Type <- toMountType m.Type
        proto.Source <- m.Source
        proto.Target <- m.Target
        proto.ReadOnly <- m.ReadOnly
        proto.Options.AddRange(m.Options)
        proto

    let toContainerSummaryProto (c: ContainerSummary) : Cepaf.Podman.Grpc.ContainerSummary =
        let proto = Cepaf.Podman.Grpc.ContainerSummary()
        proto.Id <- c.Id
        proto.Names.AddRange(c.Names)
        proto.Image <- c.Image
        proto.ImageId <- c.ImageID
        proto.Command <- c.Command
        proto.Created <- toTimestamp c.Created
        proto.State <- toContainerStatusType c.State
        proto.Status <- c.Status
        proto.Ports.AddRange(c.Ports |> List.map toPortMappingProto)
        proto.Labels.AddRange(toKeyValueList c.Labels)
        proto.Mounts.AddRange(c.Mounts |> List.map toMountProto)
        proto.Networks.AddRange(c.Networks)
        proto

    let toHealthCheckLogProto (log: HealthCheckLog) : Cepaf.Podman.Grpc.HealthCheckLog =
        let proto = Cepaf.Podman.Grpc.HealthCheckLog()
        proto.Start <- toTimestamp log.Start
        proto.End <- toTimestamp log.End
        proto.ExitCode <- log.ExitCode
        proto.Output <- log.Output
        proto

    let toHealthCheckResultProto (hcr: HealthCheckResult) : Cepaf.Podman.Grpc.HealthCheckResult =
        let proto = Cepaf.Podman.Grpc.HealthCheckResult()
        proto.Status <- toHealthStatusType hcr.Status
        proto.FailingStreak <- hcr.FailingStreak
        proto.Log.AddRange(hcr.Log |> List.map toHealthCheckLogProto)
        proto

    let toContainerStateProto (state: ContainerStateDetail) : ContainerState =
        let proto = ContainerState()
        proto.Status <- toContainerStatusType state.Status
        proto.Running <- state.Running
        proto.Paused <- state.Paused
        proto.Restarting <- state.Restarting
        proto.OomKilled <- state.OOMKilled
        proto.Dead <- state.Dead
        proto.Pid <- state.Pid
        proto.ExitCode <- state.ExitCode
        proto.Error <- state.Error |> Option.defaultValue ""
        proto.StartedAt <- toOptionalTimestamp state.StartedAt
        proto.FinishedAt <- toOptionalTimestamp state.FinishedAt
        match state.Health with
        | Some h -> proto.Health <- toHealthCheckResultProto h
        | None -> ()
        proto

    let toContainerInspectProto (c: ContainerInspect) : ContainerInspectResponse =
        let proto = ContainerInspectResponse()
        proto.Id <- c.Id
        proto.Created <- toTimestamp c.Created
        proto.Path <- c.Path
        proto.Args.AddRange(c.Args)
        proto.State <- toContainerStateProto c.State
        proto.Image <- c.Image
        proto.ImageName <- c.ImageName
        proto.Name <- c.Name
        proto.RestartCount <- c.RestartCount
        proto.Platform <- c.Platform
        proto.Mounts.AddRange(c.Mounts |> List.map toMountProto)
        proto.Labels.AddRange(toKeyValueList c.Labels)
        proto.Env.AddRange(toKeyValueList c.Env)
        proto

    let toImageSummaryProto (i: ImageSummary) : Cepaf.Podman.Grpc.ImageSummary =
        let proto = Cepaf.Podman.Grpc.ImageSummary()
        proto.Id <- i.Id
        proto.RepoTags.AddRange(i.RepoTags)
        proto.RepoDigests.AddRange(i.RepoDigests)
        proto.Created <- toTimestamp i.Created
        proto.Size <- i.Size
        proto.VirtualSize <- i.VirtualSize
        proto.Labels.AddRange(toKeyValueList i.Labels)
        proto.Containers <- i.Containers
        proto

    let toImageHistoryLayerProto (layer: ImageHistoryLayer) : Cepaf.Podman.Grpc.ImageHistoryLayer =
        let proto = Cepaf.Podman.Grpc.ImageHistoryLayer()
        proto.Id <- layer.Id
        proto.Created <- toTimestamp layer.Created
        proto.CreatedBy <- layer.CreatedBy
        proto.Size <- layer.Size
        proto.Comment <- layer.Comment
        proto

    let toImageInspectProto (i: ImageInspect) : ImageInspectResponse =
        let proto = ImageInspectResponse()
        proto.Id <- i.Id
        proto.RepoTags.AddRange(i.RepoTags)
        proto.RepoDigests.AddRange(i.RepoDigests)
        proto.Parent <- i.Parent |> Option.defaultValue ""
        proto.Comment <- i.Comment
        proto.Created <- toTimestamp i.Created
        proto.Author <- i.Author
        proto.Architecture <- i.Architecture
        proto.Os <- i.Os
        proto.Size <- i.Size
        proto.VirtualSize <- i.VirtualSize
        proto.Labels.AddRange(toKeyValueList i.Labels)
        proto.History.AddRange(i.History |> List.map toImageHistoryLayerProto)
        proto

    let toProbeResultProto (r: Probes.ProbeResult) : ProbeResult =
        let proto = ProbeResult()
        proto.ContainerId <- r.ContainerId
        proto.ContainerName <- r.ContainerName
        proto.Status <- toHealthStatusType r.Status
        proto.Message <- r.Message |> Option.defaultValue ""
        proto.Timestamp <- toTimestamp r.Timestamp
        proto.Duration <- toDuration r.Duration
        proto

    let toHealthSummaryProto (s: Probes.HealthSummary) : HealthSummaryResponse =
        let proto = HealthSummaryResponse()
        proto.Total <- s.Total
        proto.Healthy <- s.Healthy
        proto.Unhealthy <- s.Unhealthy
        proto.Starting <- s.Starting
        proto.NoHealthcheck <- s.NoHealthCheck
        proto.Timestamp <- toTimestamp s.Timestamp
        proto

    // ========================================================================
    // Complex Type Conversions: Proto -> Domain
    // ========================================================================

    let fromKeyValueList (kvs: seq<KeyValue>) : Map<string, string> =
        kvs |> Seq.map (fun kv -> kv.Key, kv.Value) |> Map.ofSeq

    let fromPortMappingProto (pm: Cepaf.Podman.Grpc.PortMapping) : PortMapping =
        {
            ContainerPort = uint16 pm.ContainerPort
            HostPort = if pm.HostPort > 0u then Some (uint16 pm.HostPort) else None
            HostIP = if String.IsNullOrEmpty(pm.HostIp) then None else Some pm.HostIp
            Protocol = fromPortProtocol pm.Protocol
            Range = if pm.Range > 0u then Some (uint16 pm.Range) else None
        }

    let fromMountProto (m: Cepaf.Podman.Grpc.Mount) : Mount =
        {
            Type = fromMountType m.Type
            Source = m.Source
            Target = m.Target
            ReadOnly = m.ReadOnly
            Options = m.Options |> Seq.toList
        }
