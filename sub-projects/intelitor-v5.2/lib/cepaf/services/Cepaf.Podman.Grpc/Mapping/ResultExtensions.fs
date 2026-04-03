namespace Cepaf.Podman.Grpc.Mapping

open System
open System.Threading.Tasks
open Grpc.Core
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Extensions for handling F# Results with gRPC
module ResultExtensions =

    /// Convert PodmanError to gRPC StatusCode
    let toGrpcStatusCode (error: PodmanError) : StatusCode =
        match error with
        | PodmanError.NotFound _ -> StatusCode.NotFound
        | PodmanError.Conflict _ -> StatusCode.AlreadyExists
        | PodmanError.BadRequest _ -> StatusCode.InvalidArgument
        | PodmanError.Unauthorized _ -> StatusCode.Unauthenticated
        | PodmanError.Forbidden _ -> StatusCode.PermissionDenied
        | PodmanError.SocketNotFound _ -> StatusCode.Unavailable
        | PodmanError.SocketError _ -> StatusCode.Unavailable
        | PodmanError.ConnectionFailed _ -> StatusCode.Unavailable
        | PodmanError.Timeout _ -> StatusCode.DeadlineExceeded
        | PodmanError.RegistryNotAllowed _ -> StatusCode.PermissionDenied
        | PodmanError.SafetyConstraintViolation _ -> StatusCode.FailedPrecondition
        | PodmanError.JsonParseError _ -> StatusCode.Internal
        | PodmanError.InternalError _ -> StatusCode.Internal

    /// Convert PodmanError to RpcException
    let toRpcException (error: PodmanError) : RpcException =
        let status = Status(toGrpcStatusCode error, PodmanError.toMessage error)
        RpcException(status)

    /// Handle AsyncPodmanResult and convert to Task, throwing RpcException on error
    let toGrpcTask<'T> (asyncResult: AsyncPodmanResult<'T>) : Task<'T> =
        task {
            let! result = asyncResult |> Async.StartAsTask
            match result with
            | Ok value -> return value
            | Error e -> return raise (toRpcException e)
        }

    /// Handle AsyncPodmanResult with a mapper function
    let toGrpcTaskWith<'T, 'U> (mapper: 'T -> 'U) (asyncResult: AsyncPodmanResult<'T>) : Task<'U> =
        task {
            let! result = asyncResult |> Async.StartAsTask
            match result with
            | Ok value -> return mapper value
            | Error e -> return raise (toRpcException e)
        }

    /// Handle AsyncPodmanResult returning unit
    let toGrpcTaskEmpty (asyncResult: AsyncPodmanResult<unit>) : Task =
        task {
            let! result = asyncResult |> Async.StartAsTask
            match result with
            | Ok () -> return ()
            | Error e -> return raise (toRpcException e)
        }

    /// Wrap a synchronous operation with error handling
    let wrapSync<'T> (operation: unit -> 'T) : Task<'T> =
        task {
            try
                return operation ()
            with ex ->
                let status = Status(StatusCode.Internal, ex.Message)
                return raise (RpcException(status))
        }

    /// Log and rethrow gRPC exceptions with additional context
    let withLogging<'T> (operationName: string) (task: Task<'T>) : Task<'T> =
        task {
            try
                return! task
            with
            | :? RpcException as ex ->
                // Log the error (in production, use proper logging)
                Console.Error.WriteLine($"gRPC Error in {operationName}: {ex.Status.Detail}")
                return raise ex
            | ex ->
                Console.Error.WriteLine($"Unexpected error in {operationName}: {ex.Message}")
                let status = Status(StatusCode.Internal, $"Internal error: {ex.Message}")
                return raise (RpcException(status))
        }
