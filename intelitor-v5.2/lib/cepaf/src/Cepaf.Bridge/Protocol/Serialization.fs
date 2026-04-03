namespace Cepaf.Bridge.Protocol

open System
open System.Text.Json
open Cepaf.Podman.Domain

/// Serialization utilities for Bridge protocol
module Serialization =

    // ========================================================================
    // Error Code Mapping
    // ========================================================================

    /// Map PodmanError to JSON-RPC error code
    let errorToCode (error: PodmanError) : int =
        match error with
        | PodmanError.SocketNotFound _ -> JsonRpc.ErrorCode.SocketNotFound
        | PodmanError.ConnectionRefused _ -> JsonRpc.ErrorCode.ConnectionRefused
        | PodmanError.ConnectionTimeout _ -> JsonRpc.ErrorCode.ConnectionTimeout
        | PodmanError.ContainerNotFound _ -> JsonRpc.ErrorCode.ContainerNotFound
        | PodmanError.ContainerAlreadyExists _ -> JsonRpc.ErrorCode.ContainerAlreadyExists
        | PodmanError.ImageNotFound _ -> JsonRpc.ErrorCode.ImageNotFound
        | PodmanError.HealthCheckFailed _ -> JsonRpc.ErrorCode.HealthCheckFailed
        | PodmanError.SafetyConstraintViolation _ -> JsonRpc.ErrorCode.SafetyViolation
        | PodmanError.NetworkNotFound _ -> JsonRpc.ErrorCode.NetworkNotFound
        | PodmanError.VolumeNotFound _ -> JsonRpc.ErrorCode.VolumeNotFound
        | PodmanError.NotFound _ -> JsonRpc.ErrorCode.ContainerNotFound
        | _ -> JsonRpc.ErrorCode.InternalError

    /// Map PodmanError to JSON-RPC error response
    let errorToResponse (id: string option) (error: PodmanError) : string =
        let code = errorToCode error
        let message = PodmanError.toMessage error
        let data =
            match error with
            | PodmanError.ContainerNotFound containerId ->
                Some ({| containerId = containerId |} :> obj)
            | PodmanError.ContainerAlreadyExists name ->
                Some ({| name = name |} :> obj)
            | PodmanError.ImageNotFound reference ->
                Some ({| reference = reference |} :> obj)
            | PodmanError.SafetyConstraintViolation (constraintId, reason) ->
                Some ({| constraintId = constraintId; reason = reason |} :> obj)
            | _ -> None

        JsonRpc.errorResponse id code message data

    // ========================================================================
    // Container Status Serialization
    // ========================================================================

    /// Serialize ContainerStatus to string
    let containerStatusToString (status: ContainerStatus) : string =
        match status with
        | ContainerStatus.Created -> "created"
        | ContainerStatus.Running -> "running"
        | ContainerStatus.Paused -> "paused"
        | ContainerStatus.Restarting -> "restarting"
        | ContainerStatus.Removing -> "removing"
        | ContainerStatus.Exited code -> sprintf "exited:%d" code
        | ContainerStatus.Dead reason -> sprintf "dead:%s" reason
        | ContainerStatus.Unknown s -> s

    /// Serialize HealthStatus to string
    let healthStatusToString (status: HealthStatus) : string =
        match status with
        | HealthStatus.Starting -> "starting"
        | HealthStatus.Healthy -> "healthy"
        | HealthStatus.Unhealthy streak -> sprintf "unhealthy:%d" streak
        | HealthStatus.NoHealthcheck -> "none"
        | HealthStatus.Unknown s -> s

    // ========================================================================
    // Response DTOs
    // ========================================================================

    /// System info response
    type SystemInfoResponse = {
        Version: string
        ApiVersion: string
        Os: string
        Arch: string
        Hostname: string
        ContainerCount: int
        ImageCount: int
    }

    /// Container create response
    type ContainerCreateResponse = {
        ContainerId: string
        Name: string option
        Status: string
        Warnings: string list
    }

    /// Container summary for list operations
    type ContainerListItem = {
        Id: string
        Names: string list
        Image: string
        Status: string
        State: string
        Created: string
        Ports: string list
    }

    /// Health check response
    type HealthCheckResponse = {
        ContainerId: string
        Status: string
        Message: string option
        Timestamp: string
    }

    /// Health summary response
    type HealthSummaryResponse = {
        Total: int
        Healthy: int
        Unhealthy: int
        Starting: int
        NoHealthCheck: int
        Containers: HealthCheckResponse list
    }

    /// Safety validation response
    type ValidationResponse = {
        Valid: bool
        Violations: ValidationViolation list
    }

    and ValidationViolation = {
        Constraint: string
        Resource: string
        Message: string
        Severity: string
    }

    // ========================================================================
    // Request DTOs
    // ========================================================================

    /// Container specification from JSON params
    type ContainerSpecParams = {
        Name: string option
        Image: string
        Command: string list option
        Env: Map<string, string> option
        Ports: PortMappingParams list option
        Volumes: VolumeMappingParams list option
        HealthCheck: HealthCheckParams option
        RestartPolicy: string option
        Labels: Map<string, string> option
    }

    and PortMappingParams = {
        Host: int
        Container: int
        Protocol: string option
    }

    and VolumeMappingParams = {
        Source: string
        Target: string
        ReadOnly: bool option
    }

    and HealthCheckParams = {
        Test: string list
        Interval: string option
        Timeout: string option
        Retries: int option
    }

    // ========================================================================
    // Conversion Functions
    // ========================================================================

    /// Parse ContainerSpec from JSON params
    let parseContainerSpec (params': JsonElement option) : Result<ContainerSpec, string> =
        match params' with
        | None -> Error "Missing params"
        | Some p ->
            match JsonRpc.getString "image" (Some p) with
            | Error e -> Error e
            | Ok image ->
                let spec = ContainerSpec.create image

                let spec =
                    match JsonRpc.getStringOption "name" (Some p) with
                    | Some name -> ContainerSpec.withName name spec
                    | None -> spec

                // Add more parsing as needed...
                Ok spec

    /// Convert ContainerSummary to ListItem
    let containerSummaryToListItem (c: ContainerSummary) : ContainerListItem =
        {
            Id = c.Id
            Names = c.Names
            Image = c.Image
            Status = c.Status
            State = containerStatusToString c.State
            Created = c.Created.ToString("o")
            Ports = c.Ports |> List.map (fun p ->
                sprintf "%s:%d->%d/%s"
                    (p.HostIP |> Option.defaultValue "0.0.0.0")
                    (p.HostPort |> Option.defaultValue 0us |> int)
                    (int p.ContainerPort)
                    (PortProtocol.toString p.Protocol)
            )
        }
