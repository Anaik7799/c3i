namespace Cepaf.Cockpit.Web.Services

open System
open System.Threading
open System.Threading.Tasks
open Microsoft.AspNetCore.SignalR.Client
open Cepaf.Cockpit.Web.Domain.Types

/// =============================================================================
/// SignalR Client - Real-time Communication Bridge
/// =============================================================================
/// Manages WebSocket connection to the Elixir backend for real-time updates.
/// STAMP: SC-BRIDGE-001 (Message ordering), SC-BRIDGE-003 (50ms latency)
/// =============================================================================

module SignalRClient =

    /// SignalR connection wrapper
    type SignalRConnection(hubUrl: string) =
        let mutable connection: HubConnection option = None
        let mutable connectionState = WebConnectionState.Disconnected

        let buildConnection () =
            HubConnectionBuilder()
                .WithUrl(hubUrl)
                .WithAutomaticReconnect()
                .Build()

        /// Current connection state
        member this.State = connectionState

        /// Connect to SignalR hub
        member this.ConnectAsync(ct: CancellationToken) : Task<Result<unit, string>> = task {
            try
                connectionState <- WebConnectionState.Connecting
                let conn = buildConnection()
                do! conn.StartAsync(ct)
                connection <- Some conn
                connectionState <- WebConnectionState.Connected
                return Ok ()
            with ex ->
                connectionState <- WebConnectionState.Error ex.Message
                return Result.Error ex.Message
        }

        /// Disconnect from SignalR hub
        member this.DisconnectAsync(ct: CancellationToken) : Task<Result<unit, string>> = task {
            match connection with
            | Some conn ->
                try
                    do! conn.StopAsync(ct)
                    connection <- None
                    connectionState <- WebConnectionState.Disconnected
                    return Ok ()
                with ex ->
                    return Result.Error ex.Message
            | None ->
                return Ok ()
        }

        /// Subscribe to health updates
        member this.OnHealthUpdate(handler: SystemHealthSummary -> unit) =
            match connection with
            | Some conn ->
                conn.On<SystemHealthSummary>("HealthUpdate", handler) |> ignore
            | None -> ()

        /// Subscribe to alarm updates
        member this.OnAlarmUpdate(handler: Cepaf.Cockpit.Domain.Alarm -> unit) =
            match connection with
            | Some conn ->
                conn.On<Cepaf.Cockpit.Domain.Alarm>("AlarmUpdate", handler) |> ignore
            | None -> ()

        /// Subscribe to proposal updates
        member this.OnProposalUpdate(handler: GuardianProposal -> unit) =
            match connection with
            | Some conn ->
                conn.On<GuardianProposal>("ProposalUpdate", handler) |> ignore
            | None -> ()

        /// Subscribe to threat updates
        member this.OnThreatUpdate(handler: SentinelThreat -> unit) =
            match connection with
            | Some conn ->
                conn.On<SentinelThreat>("ThreatUpdate", handler) |> ignore
            | None -> ()

        /// Send acknowledge alarm
        member this.AcknowledgeAlarmAsync(alarmId: string, ct: CancellationToken) : Task<Result<unit, string>> = task {
            match connection with
            | Some conn ->
                try
                    do! conn.InvokeAsync("AcknowledgeAlarm", alarmId, ct)
                    return Ok ()
                with ex ->
                    return Result.Error ex.Message
            | None ->
                return Result.Error "Not connected"
        }

        /// Send approve proposal
        member this.ApproveProposalAsync(proposalId: string, ct: CancellationToken) : Task<Result<unit, string>> = task {
            match connection with
            | Some conn ->
                try
                    do! conn.InvokeAsync("ApproveProposal", proposalId, ct)
                    return Ok ()
                with ex ->
                    return Result.Error ex.Message
            | None ->
                return Result.Error "Not connected"
        }

        /// Send veto proposal
        member this.VetoProposalAsync(proposalId: string, reason: string, ct: CancellationToken) : Task<Result<unit, string>> = task {
            match connection with
            | Some conn ->
                try
                    do! conn.InvokeAsync("VetoProposal", proposalId, reason, ct)
                    return Ok ()
                with ex ->
                    return Result.Error ex.Message
            | None ->
                return Result.Error "Not connected"
        }

        /// Send mitigate threat
        member this.MitigateThreatAsync(threatId: string, ct: CancellationToken) : Task<Result<unit, string>> = task {
            match connection with
            | Some conn ->
                try
                    do! conn.InvokeAsync("MitigateThreat", threatId, ct)
                    return Ok ()
                with ex ->
                    return Result.Error ex.Message
            | None ->
                return Result.Error "Not connected"
        }

        interface IDisposable with
            member this.Dispose() =
                match connection with
                | Some conn -> conn.DisposeAsync().AsTask().Wait()
                | None -> ()

    /// Factory for creating SignalR client
    let createClient () =
        let url =
            match Environment.GetEnvironmentVariable("SIGNALR_HUB_URL") with
            | null | "" -> "http://localhost:5000/zenoh-hub"
            | url -> url
        new SignalRConnection(url)
