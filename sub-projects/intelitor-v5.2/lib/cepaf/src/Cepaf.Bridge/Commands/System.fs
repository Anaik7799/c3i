namespace Cepaf.Bridge.Commands

open Cepaf.Podman.Client
open Cepaf.Podman.Api
open Cepaf.Bridge.Protocol

/// System-level commands
module System =

    /// Handle system.ping - check if bridge and Podman are responsive
    let handlePing (client: PodmanClient) (id: string option) : Async<string> = async {
        let! result = HttpClient.ping client
        match result with
        | Ok true ->
            let response = {|
                status = "ok"
                timestamp = System.DateTimeOffset.UtcNow.ToString("o")
            |}
            return JsonRpc.successResponse id response
        | Ok false ->
            return JsonRpc.errorResponse id JsonRpc.ErrorCode.ConnectionRefused "Podman not responding" None
        | Error e ->
            return Serialization.errorToResponse id e
    }

    /// Handle system.info - get system information
    let handleInfo (client: PodmanClient) (id: string option) : Async<string> = async {
        let! result = Cepaf.Podman.Api.System.info client
        match result with
        | Ok (info: Cepaf.Podman.Domain.SystemInfo) ->
            let response : Serialization.SystemInfoResponse = {
                Version = info.Version.Version
                ApiVersion = info.Version.ApiVersion
                Os = info.Host.Os
                Arch = info.Host.Arch
                Hostname = info.Host.Hostname
                ContainerCount = info.Storage.ContainerCount
                ImageCount = info.Storage.ImageCount
            }
            return JsonRpc.successResponse id response
        | Error e ->
            return Serialization.errorToResponse id e
    }

    /// Handle system.version - get version info
    let handleVersion (client: PodmanClient) (id: string option) : Async<string> = async {
        let! result = HttpClient.version client
        match result with
        | Ok version ->
            let response = {|
                version = version.Version
                apiVersion = version.ApiVersion
                goVersion = version.GoVersion
                gitCommit = version.GitCommit
                osArch = version.OsArch
            |}
            return JsonRpc.successResponse id response
        | Error e ->
            return Serialization.errorToResponse id e
    }
