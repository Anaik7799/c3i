namespace Cepaf.Podman.Grpc.Services

open System.Threading.Tasks
open Grpc.Core
open Google.Protobuf.WellKnownTypes
open Cepaf.Podman.Client
open Cepaf.Podman.Health
open Cepaf.Podman.Grpc
open Cepaf.Podman.Grpc.Mapping

/// gRPC Health Service Implementation
/// Delegates operations to Cepaf.Podman.Health.Probes module
type HealthServiceImpl(client: PodmanClient) =
    inherit HealthService.HealthServiceBase()

    /// Check health of all running containers
    override _.CheckAll(request: Empty, context: ServerCallContext) : Task<HealthCheckAllResponse> =
        task {
            let! result = Probes.checkAll client |> Async.StartAsTask

            match result with
            | Ok probeResults ->
                let response = HealthCheckAllResponse()
                response.Results.AddRange(
                    probeResults |> List.map ProtoConverters.toProbeResultProto
                )
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Get health summary
    override _.GetSummary(request: Empty, context: ServerCallContext) : Task<HealthSummaryResponse> =
        task {
            let! result = Probes.getSummary client |> Async.StartAsTask

            match result with
            | Ok summary ->
                return ProtoConverters.toHealthSummaryProto summary
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Check single container health
    override _.CheckContainer(request: CheckContainerRequest, context: ServerCallContext) : Task<ProbeResult> =
        task {
            let! result = Probes.check client request.ContainerId |> Async.StartAsTask

            match result with
            | Ok probe ->
                return ProtoConverters.toProbeResultProto probe
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Liveness probe for a container
    override _.LivenessProbe(request: LivenessProbeRequest, context: ServerCallContext) : Task<ProbeResponse> =
        task {
            let! result = Probes.livenessProbe client request.ContainerId |> Async.StartAsTask

            match result with
            | Ok alive ->
                let response = ProbeResponse()
                response.Alive <- alive
                response.Message <- if alive then "Container is alive" else "Container is not alive"
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Readiness probe for a container
    override _.ReadinessProbe(request: ReadinessProbeRequest, context: ServerCallContext) : Task<ProbeResponse> =
        task {
            let! result = Probes.readinessProbe client request.ContainerId |> Async.StartAsTask

            match result with
            | Ok ready ->
                let response = ProbeResponse()
                response.Alive <- ready
                response.Message <- if ready then "Container is ready" else "Container is not ready"
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }
