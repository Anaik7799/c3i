namespace Cepaf.Bridge.Commands

open System.Text.Json
open Cepaf.Podman.Client
open Cepaf.Podman.Domain
open Cepaf.Podman.Api
open Cepaf.Bridge.Protocol

/// Container management commands
module Container =

    /// Handle container.list - list containers
    let handleList (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        let all = JsonRpc.getBool "all" false params'
        let filters =
            if all then
                { Containers.ListFilters.empty with All = true }
            else
                Containers.ListFilters.empty

        let! result = Containers.list client filters
        match result with
        | Ok containers ->
            let items = containers |> List.map Serialization.containerSummaryToListItem
            return JsonRpc.successResponse id items
        | Error e ->
            return Serialization.errorToResponse id e
    }

    /// Handle container.inspect - get container details
    let handleInspect (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let! result = Containers.inspect client containerId
            match result with
            | Ok container ->
                let response = {|
                    id = container.Id
                    name = container.Name
                    image = container.ImageName
                    created = container.Created.ToString("o")
                    state = Serialization.containerStatusToString container.State.Status
                    running = container.State.Running
                    paused = container.State.Paused
                    pid = container.State.Pid
                    exitCode = container.State.ExitCode
                    startedAt = container.State.StartedAt |> Option.map (fun d -> d.ToString("o"))
                    finishedAt = container.State.FinishedAt |> Option.map (fun d -> d.ToString("o"))
                    restartCount = container.RestartCount
                    platform = container.Platform
                |}
                return JsonRpc.successResponse id response
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.create - create a new container
    let handleCreate (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match Serialization.parseContainerSpec params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok spec ->
            let! result = Containers.create client spec
            match result with
            | Ok containerId ->
                let response : Serialization.ContainerCreateResponse = {
                    ContainerId = containerId
                    Name = spec.Name
                    Status = "created"
                    Warnings = []
                }
                return JsonRpc.successResponse id response
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.start - start a container
    let handleStart (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let! result = Containers.start client containerId
            match result with
            | Ok () ->
                return JsonRpc.successResponse id {| status = "started"; containerId = containerId |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.stop - stop a container
    let handleStop (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let timeout = JsonRpc.getIntOption "timeout" params'
            let! result = Containers.stop client containerId timeout
            match result with
            | Ok () ->
                return JsonRpc.successResponse id {| status = "stopped"; containerId = containerId |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.remove - remove a container
    let handleRemove (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let force = JsonRpc.getBool "force" false params'
            let volumes = JsonRpc.getBool "volumes" false params'
            let! result = Containers.remove client containerId force volumes
            match result with
            | Ok () ->
                return JsonRpc.successResponse id {| status = "removed"; containerId = containerId |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.logs - get container logs
    let handleLogs (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let tail = JsonRpc.getIntOption "tail" params' |> Option.defaultValue 100
            let! result = Containers.logsLast client containerId tail
            match result with
            | Ok logs ->
                return JsonRpc.successResponse id {| containerId = containerId; logs = logs |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.exists - check if container exists
    let handleExists (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "containerId" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok containerId ->
            let! result = Containers.exists client containerId
            match result with
            | Ok exists ->
                return JsonRpc.successResponse id {| exists = exists; containerId = containerId |}
            | Error e ->
                return Serialization.errorToResponse id e
    }

    /// Handle container.findByName - find container by name
    let handleFindByName (client: PodmanClient) (id: string option) (params': JsonElement option) : Async<string> = async {
        match JsonRpc.getString "name" params' with
        | Error e -> return JsonRpc.invalidParamsResponse id e
        | Ok name ->
            let! result = Containers.findByName client name
            match result with
            | Ok (Some container) ->
                let item = Serialization.containerSummaryToListItem container
                return JsonRpc.successResponse id {| found = true; container = item |}
            | Ok None ->
                return JsonRpc.successResponse id {| found = false; container = null |}
            | Error e ->
                return Serialization.errorToResponse id e
    }
