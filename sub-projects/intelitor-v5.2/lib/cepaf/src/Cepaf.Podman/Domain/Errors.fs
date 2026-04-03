namespace Cepaf.Podman.Domain

open System

/// All possible Podman operation errors
[<RequireQualifiedAccess>]
type PodmanError =
    // Connection errors
    | SocketNotFound of path: string
    | ConnectionRefused of endpoint: string
    | ConnectionTimeout of operation: string * durationMs: int64

    // API errors
    | ApiError of statusCode: int * message: string
    | NotFound of resourceType: string * id: string
    | Conflict of resourceType: string * reason: string
    | InvalidParameter of param: string * reason: string
    | BadRequest of message: string

    // Container errors
    | ContainerNotRunning of id: string
    | ContainerNotFound of id: string
    | ContainerAlreadyExists of name: string
    | ContainerAlreadyStopped of id: string
    | ContainerStartFailed of id: string * reason: string

    // Pod errors
    | PodNotFound of name: string
    | PodAlreadyExists of name: string

    // Image errors
    | ImageNotFound of reference: string
    | ImagePullFailed of reference: string * reason: string
    | ImageBuildFailed of reason: string
    | RegistryNotAllowed of registry: string

    // Volume errors
    | VolumeNotFound of name: string
    | VolumeInUse of name: string * containers: string list
    | VolumeAlreadyExists of name: string

    // Network errors
    | NetworkNotFound of name: string
    | NetworkInUse of name: string * containers: string list
    | NetworkAlreadyExists of name: string

    // Health errors
    | HealthCheckFailed of container: string * output: string
    | HealthCheckTimeout of container: string * timeoutMs: int64
    | HealthCheckNotConfigured of container: string

    // Safety errors
    | SafetyConstraintViolation of constraintId: string * reason: string
    | ValidationFailed of errors: string list

    // System errors
    | JsonParseError of message: string
    | JsonSerializeError of message: string
    | UnexpectedResponse of statusCode: int * body: string
    | InternalError of message: string
    | OperationCancelled

/// Error helper functions
module PodmanError =

    /// Convert error to human-readable message
    let toMessage (error: PodmanError) : string =
        match error with
        | PodmanError.SocketNotFound path ->
            sprintf "Podman socket not found at: %s" path
        | PodmanError.ConnectionRefused endpoint ->
            sprintf "Connection refused to: %s" endpoint
        | PodmanError.ConnectionTimeout (op, ms) ->
            sprintf "Connection timeout after %dms during: %s" ms op
        | PodmanError.ApiError (code, msg) ->
            sprintf "API error %d: %s" code msg
        | PodmanError.NotFound (t, id) ->
            sprintf "%s not found: %s" t id
        | PodmanError.Conflict (t, reason) ->
            sprintf "%s conflict: %s" t reason
        | PodmanError.InvalidParameter (param, reason) ->
            sprintf "Invalid parameter '%s': %s" param reason
        | PodmanError.BadRequest msg ->
            sprintf "Bad request: %s" msg
        | PodmanError.ContainerNotRunning id ->
            sprintf "Container not running: %s" id
        | PodmanError.ContainerNotFound id ->
            sprintf "Container not found: %s" id
        | PodmanError.ContainerAlreadyExists name ->
            sprintf "Container already exists: %s" name
        | PodmanError.ContainerAlreadyStopped id ->
            sprintf "Container already stopped: %s" id
        | PodmanError.ContainerStartFailed (id, reason) ->
            sprintf "Container start failed %s: %s" id reason
        | PodmanError.PodNotFound name ->
            sprintf "Pod not found: %s" name
        | PodmanError.PodAlreadyExists name ->
            sprintf "Pod already exists: %s" name
        | PodmanError.ImageNotFound ref ->
            sprintf "Image not found: %s" ref
        | PodmanError.ImagePullFailed (ref, reason) ->
            sprintf "Image pull failed %s: %s" ref reason
        | PodmanError.ImageBuildFailed reason ->
            sprintf "Image build failed: %s" reason
        | PodmanError.RegistryNotAllowed registry ->
            sprintf "Registry not allowed: %s (only localhost/ permitted)" registry
        | PodmanError.VolumeNotFound name ->
            sprintf "Volume not found: %s" name
        | PodmanError.VolumeInUse (name, containers) ->
            sprintf "Volume %s in use by: %s" name (String.concat ", " containers)
        | PodmanError.VolumeAlreadyExists name ->
            sprintf "Volume already exists: %s" name
        | PodmanError.NetworkNotFound name ->
            sprintf "Network not found: %s" name
        | PodmanError.NetworkInUse (name, containers) ->
            sprintf "Network %s in use by: %s" name (String.concat ", " containers)
        | PodmanError.NetworkAlreadyExists name ->
            sprintf "Network already exists: %s" name
        | PodmanError.HealthCheckFailed (container, output) ->
            sprintf "Health check failed for %s: %s" container output
        | PodmanError.HealthCheckTimeout (container, ms) ->
            sprintf "Health check timeout for %s after %dms" container ms
        | PodmanError.HealthCheckNotConfigured container ->
            sprintf "Health check not configured for: %s" container
        | PodmanError.SafetyConstraintViolation (id, reason) ->
            sprintf "Safety constraint %s violated: %s" id reason
        | PodmanError.ValidationFailed errors ->
            sprintf "Validation failed: %s" (String.concat "; " errors)
        | PodmanError.JsonParseError msg ->
            sprintf "JSON parse error: %s" msg
        | PodmanError.JsonSerializeError msg ->
            sprintf "JSON serialize error: %s" msg
        | PodmanError.UnexpectedResponse (code, body) ->
            sprintf "Unexpected response %d: %s" code body
        | PodmanError.InternalError msg ->
            sprintf "Internal error: %s" msg
        | PodmanError.OperationCancelled ->
            "Operation was cancelled"

    /// Check if error is retryable
    let isRetryable (error: PodmanError) : bool =
        match error with
        | PodmanError.ConnectionTimeout _ -> true
        | PodmanError.ConnectionRefused _ -> true
        | PodmanError.ApiError (code, _) when code >= 500 -> true
        | _ -> false

    /// Get error severity level
    let getSeverity (error: PodmanError) : string =
        match error with
        | PodmanError.SafetyConstraintViolation _ -> "CRITICAL"
        | PodmanError.HealthCheckFailed _ -> "HIGH"
        | PodmanError.ContainerStartFailed _ -> "HIGH"
        | PodmanError.ImagePullFailed _ -> "HIGH"
        | PodmanError.ApiError (code, _) when code >= 500 -> "HIGH"
        | PodmanError.NotFound _ -> "MEDIUM"
        | PodmanError.Conflict _ -> "MEDIUM"
        | PodmanError.InvalidParameter _ -> "LOW"
        | _ -> "MEDIUM"

/// Result type alias for Podman operations
type PodmanResult<'T> = Result<'T, PodmanError>

/// Async result for I/O operations
type AsyncPodmanResult<'T> = Async<PodmanResult<'T>>

/// Result computation expression helpers
[<AutoOpen>]
module ResultOperators =

    /// Bind operator for Result
    let (>>=) result f = Result.bind f result

    /// Map operator for Result
    let (>>|) result f = Result.map f result

    /// Apply function to Ok value or return Error
    let inline ok value = Ok value

    /// Create Error result
    let inline error err = Error err

/// Async Result helpers
module AsyncResult =

    /// Map over async result
    let map f asyncResult = async {
        let! result = asyncResult
        return Result.map f result
    }

    /// Bind over async result
    let bind f asyncResult = async {
        let! result = asyncResult
        match result with
        | Ok value -> return! f value
        | Error e -> return Error e
    }

    /// Return value as async ok result
    let retn value = async { return Ok value }

    /// Return error as async result
    let error err = async { return Error err }

    /// Catch exceptions and convert to error
    let catch (makeError: exn -> PodmanError) (asyncOp: Async<'T>) : AsyncPodmanResult<'T> = async {
        try
            let! result = asyncOp
            return Ok result
        with ex ->
            return Error (makeError ex)
    }
