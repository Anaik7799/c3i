namespace Cepaf.Bridge.Commands

open System.Text.Json
open Cepaf.Podman.Client
open Cepaf.Podman.Domain
open Cepaf.Podman.Api
open Cepaf.Podman.Health
open Cepaf.Bridge.Protocol

/// Health check commands
module Health =

    /// Handle health.check - run health check on a container
    let handleCheck (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let! result = Probes.check client containerId
            match result with
            | Ok probe ->
                let response : Serialization.HealthCheckResponse = {
                    ContainerId = probe.ContainerId
                    Status = Serialization.healthStatusToString probe.Status
                    Message = probe.Message
                    Timestamp = probe.Timestamp.ToString("o")
                }
                return JsonRpc.successResponse id response
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle health.summary - get health summary of all containers
    let handleSummary (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        let! result = Probes.checkAll client
        match result with
        | Ok probes ->
            let healthy = probes |> List.filter (fun p -> p.Status = HealthStatus.Healthy) |> List.length
            let unhealthy = probes |> List.filter (fun p -> match p.Status with HealthStatus.Unhealthy _ -> true | _ -> false) |> List.length
            let starting = probes |> List.filter (fun p -> p.Status = HealthStatus.Starting) |> List.length
            let noCheck = probes |> List.filter (fun p -> p.Status = HealthStatus.NoHealthcheck) |> List.length

            let containers : Serialization.HealthCheckResponse list =
                probes |> List.map (fun p ->
                    {
                        ContainerId = p.ContainerId
                        Status = Serialization.healthStatusToString p.Status
                        Message = p.Message
                        Timestamp = p.Timestamp.ToString("o")
                    }
                )

            let response : Serialization.HealthSummaryResponse = {
                Total = probes.Length
                Healthy = healthy
                Unhealthy = unhealthy
                Starting = starting
                NoHealthCheck = noCheck
                Containers = containers
            }
            return JsonRpc.successResponse id response
        | Error e ->
            return Serialization.errorToResponse id e
    }

    /// Handle health.liveness - check if container is alive
    let handleLiveness (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let! result = Probes.livenessProbe client containerId
            match result with
            | Ok alive ->
                return JsonRpc.successResponse id {| containerId = containerId; alive = alive |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle health.readiness - check if container is ready
    let handleReadiness (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let! result = Probes.readinessProbe client containerId
            match result with
            | Ok ready ->
                return JsonRpc.successResponse id {| containerId = containerId; ready = ready |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle health.allHealthy - check if all containers are healthy
    let handleAllHealthy (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        let! result = Probes.allHealthy client
        match result with
        | Ok allHealthy ->
            return JsonRpc.successResponse id {| allHealthy = allHealthy |}
        | Error e ->
            return Serialization.errorToResponse id e
    }

    /// Handle health.unhealthy - get list of unhealthy containers
    let handleUnhealthy (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        let! result = Probes.getUnhealthy client
        match result with
        | Ok unhealthy ->
            let containers : Serialization.HealthCheckResponse list =
                unhealthy |> List.map (fun p ->
                    {
                        ContainerId = p.ContainerId
                        Status = Serialization.healthStatusToString p.Status
                        Message = p.Message
                        Timestamp = p.Timestamp.ToString("o")
                    }
                )
            return JsonRpc.successResponse id {| count = unhealthy.Length; containers = containers |}
        | Error e ->
            return Serialization.errorToResponse id e
    }
