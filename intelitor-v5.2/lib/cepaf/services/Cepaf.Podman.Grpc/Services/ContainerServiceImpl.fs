namespace Cepaf.Podman.Grpc.Services

open System.Threading.Tasks
open Grpc.Core
open Google.Protobuf.WellKnownTypes
open Cepaf.Podman.Client
open Cepaf.Podman.Api
open Cepaf.Podman.Domain
open Cepaf.Podman.Grpc
open Cepaf.Podman.Grpc.Mapping

/// gRPC Container Service Implementation
/// Delegates operations to Cepaf.Podman.Api.Containers module
type ContainerServiceImpl(client: PodmanClient) =
    inherit ContainerService.ContainerServiceBase()

    /// List containers with optional filters
    override _.List(request: ListContainersRequest, context: ServerCallContext) : Task<ListContainersResponse> =
        task {
            let filters =
                { Containers.ListFilters.empty with
                    All = request.All
                    Limit = if request.Limit > 0 then Some request.Limit else None
                    Label = request.LabelFilter |> Seq.toList
                    Name = request.NameFilter |> Seq.toList
                }

            let! result = Containers.list client filters |> Async.StartAsTask

            match result with
            | Ok containers ->
                let response = ListContainersResponse()
                response.Containers.AddRange(
                    containers |> List.map ProtoConverters.toContainerSummaryProto
                )
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Inspect a container
    override _.Inspect(request: InspectContainerRequest, context: ServerCallContext) : Task<ContainerInspectResponse> =
        task {
            let! result = Containers.inspect client request.Id |> Async.StartAsTask

            match result with
            | Ok container ->
                return ProtoConverters.toContainerInspectProto container
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Create a new container
    override _.Create(request: CreateContainerRequest, context: ServerCallContext) : Task<CreateContainerResponse> =
        task {
            // Build container spec from request using the builder pattern
            let mutable spec = ContainerSpec.create request.Image

            // Set name if provided
            if not (System.String.IsNullOrEmpty(request.Name)) then
                spec <- ContainerSpec.withName request.Name spec

            // Set command if provided
            if request.Command.Count > 0 then
                spec <- ContainerSpec.withCommand (request.Command |> Seq.toList) spec

            // Set entrypoint if provided
            if request.Entrypoint.Count > 0 then
                spec <- ContainerSpec.withEntrypoint (request.Entrypoint |> Seq.toList) spec

            // Set environment variables
            for kv in request.Env do
                spec <- ContainerSpec.withEnv kv.Key kv.Value spec

            // Set labels
            for kv in request.Labels do
                spec <- ContainerSpec.withLabel kv.Key kv.Value spec

            // Set port mappings
            for pm in request.Ports do
                let port = ProtoConverters.fromPortMappingProto pm
                spec <- { spec with PortMappings = port :: spec.PortMappings }

            // Set mounts
            for m in request.Mounts do
                let mount = ProtoConverters.fromMountProto m
                spec <- ContainerSpec.withMount mount spec

            // Set hostname if provided
            if not (System.String.IsNullOrEmpty(request.Hostname)) then
                spec <- ContainerSpec.withHostname request.Hostname spec

            // Set user if provided
            if not (System.String.IsNullOrEmpty(request.User)) then
                spec <- ContainerSpec.withUser request.User spec

            // Set working directory if provided
            if not (System.String.IsNullOrEmpty(request.WorkingDir)) then
                spec <- ContainerSpec.withWorkDir request.WorkingDir spec

            // Set terminal and stdin options
            if request.Tty then
                spec <- ContainerSpec.withTerminal spec
            if request.StdinOpen then
                spec <- ContainerSpec.withStdin spec

            // Set memory limit if provided
            if request.MemoryLimit > 0L then
                spec <- ContainerSpec.withMemoryLimit request.MemoryLimit spec

            let! result = Containers.create client spec |> Async.StartAsTask

            match result with
            | Ok id ->
                let response = CreateContainerResponse()
                response.Id <- id
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Start a container
    override _.Start(request: StartContainerRequest, context: ServerCallContext) : Task<Empty> =
        task {
            let! result = Containers.start client request.Id |> Async.StartAsTask

            match result with
            | Ok () -> return Empty()
            | Error e -> return raise (ResultExtensions.toRpcException e)
        }

    /// Stop a container
    override _.Stop(request: StopContainerRequest, context: ServerCallContext) : Task<Empty> =
        task {
            let timeout = if request.Timeout > 0 then Some request.Timeout else None
            let! result = Containers.stop client request.Id timeout |> Async.StartAsTask

            match result with
            | Ok () -> return Empty()
            | Error e -> return raise (ResultExtensions.toRpcException e)
        }

    /// Remove a container
    override _.Remove(request: RemoveContainerRequest, context: ServerCallContext) : Task<Empty> =
        task {
            let! result = Containers.remove client request.Id request.Force request.Volumes |> Async.StartAsTask

            match result with
            | Ok () -> return Empty()
            | Error e -> return raise (ResultExtensions.toRpcException e)
        }

    /// Check if container exists
    override _.Exists(request: ContainerExistsRequest, context: ServerCallContext) : Task<ContainerExistsResponse> =
        task {
            let! result = Containers.exists client request.Id |> Async.StartAsTask

            match result with
            | Ok exists ->
                let response = ContainerExistsResponse()
                response.Exists <- exists
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Get container logs
    override _.Logs(request: ContainerLogsRequest, context: ServerCallContext) : Task<ContainerLogsResponse> =
        task {
            let options = {
                Containers.LogOptions.defaults with
                    Follow = request.Follow
                    Stdout = request.Stdout
                    Stderr = request.Stderr
                    Timestamps = request.Timestamps
                    Tail = if request.Tail > 0 then Some request.Tail else None
                    Since =
                        if request.Since <> null && request.Since <> Timestamp() then
                            Some (request.Since.ToDateTimeOffset())
                        else None
            }

            let! result = Containers.logs client request.Id options |> Async.StartAsTask

            match result with
            | Ok logs ->
                let response = ContainerLogsResponse()
                response.Logs <- logs
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }
