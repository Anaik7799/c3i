namespace Cepaf.Podman.Grpc.Services

open System.Threading.Tasks
open Grpc.Core
open Google.Protobuf.WellKnownTypes
open Cepaf.Podman.Client
open Cepaf.Podman.Api
open Cepaf.Podman.Grpc
open Cepaf.Podman.Grpc.Mapping

/// gRPC Image Service Implementation
/// Delegates operations to Cepaf.Podman.Api.Images module
type ImageServiceImpl(client: PodmanClient) =
    inherit ImageService.ImageServiceBase()

    /// List images
    override _.List(request: ListImagesRequest, context: ServerCallContext) : Task<ListImagesResponse> =
        task {
            let! result = Images.list client request.All |> Async.StartAsTask

            match result with
            | Ok images ->
                let response = ListImagesResponse()
                response.Images.AddRange(
                    images |> List.map ProtoConverters.toImageSummaryProto
                )
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Pull image from registry
    /// SAFETY: Only localhost/ registry allowed per SC-CNT-010
    override _.Pull(request: PullImageRequest, context: ServerCallContext) : Task<PullImageResponse> =
        task {
            // Validate localhost registry constraint
            if not (request.Reference.StartsWith("localhost/")) then
                let status = Status(StatusCode.PermissionDenied, "Only localhost/ registry allowed (SC-CNT-010)")
                return raise (RpcException(status))

            let! result = Images.pull client request.Reference |> Async.StartAsTask

            match result with
            | Ok id ->
                let response = PullImageResponse()
                response.Id <- id
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Inspect an image
    override _.Inspect(request: InspectImageRequest, context: ServerCallContext) : Task<ImageInspectResponse> =
        task {
            let! result = Images.inspect client request.Reference |> Async.StartAsTask

            match result with
            | Ok image ->
                return ProtoConverters.toImageInspectProto image
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Check if image exists
    override _.Exists(request: ImageExistsRequest, context: ServerCallContext) : Task<ImageExistsResponse> =
        task {
            let! result = Images.exists client request.Reference |> Async.StartAsTask

            match result with
            | Ok exists ->
                let response = ImageExistsResponse()
                response.Exists <- exists
                return response
            | Error e ->
                return raise (ResultExtensions.toRpcException e)
        }

    /// Remove an image
    override _.Remove(request: RemoveImageRequest, context: ServerCallContext) : Task<Empty> =
        task {
            let! result = Images.remove client request.Reference request.Force |> Async.StartAsTask

            match result with
            | Ok () -> return Empty()
            | Error e -> return raise (ResultExtensions.toRpcException e)
        }
