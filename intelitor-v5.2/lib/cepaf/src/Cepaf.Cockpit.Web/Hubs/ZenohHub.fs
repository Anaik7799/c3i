namespace Cepaf.Cockpit.Web.Hubs

open System
open System.Threading.Tasks
open Microsoft.AspNetCore.SignalR
open Cepaf.Cockpit.Web.Domain.Types

/// =============================================================================
/// PRAJNA C3I WebUI - Zenoh SignalR Hub
/// =============================================================================
/// ASP.NET SignalR hub that bridges Zenoh mesh telemetry to WebUI clients.
/// STAMP: SC-BRIDGE-001 (FIFO ordering), SC-PRF-050 (< 50ms latency)
/// =============================================================================

/// SignalR hub for Zenoh telemetry bridging
type ZenohHub() =
    inherit Hub()

    /// Broadcast health update to all clients
    member this.BroadcastHealthUpdate(health: SystemHealthSummary) =
        this.Clients.All.SendAsync("HealthUpdate", health)

    /// Broadcast alarm to all clients
    member this.BroadcastAlarmUpdate(alarm: Cepaf.Cockpit.Domain.Alarm) =
        this.Clients.All.SendAsync("AlarmUpdate", alarm)

    /// Broadcast proposal to all clients
    member this.BroadcastProposalUpdate(proposal: GuardianProposal) =
        this.Clients.All.SendAsync("ProposalUpdate", proposal)

    /// Broadcast threat to all clients
    member this.BroadcastThreatUpdate(threat: SentinelThreat) =
        this.Clients.All.SendAsync("ThreatUpdate", threat)

    /// Client acknowledges an alarm
    member this.AcknowledgeAlarm(alarmId: string) = task {
        // Forward to Elixir backend via HTTP or Zenoh
        // Then broadcast acknowledgment to all clients
        do! this.Clients.All.SendAsync("AlarmAcknowledged", alarmId)
    }

    /// Client approves a Guardian proposal
    member this.ApproveProposal(proposalId: string) = task {
        // Forward to Guardian for approval
        do! this.Clients.All.SendAsync("ProposalApproved", proposalId)
    }

    /// Client vetoes a Guardian proposal
    member this.VetoProposal(proposalId: string, reason: string) = task {
        // Forward to Guardian for veto
        do! this.Clients.All.SendAsync("ProposalVetoed", proposalId)
    }

    /// Client requests threat mitigation
    member this.MitigateThreat(threatId: string) = task {
        // Forward to Sentinel for mitigation
        do! this.Clients.All.SendAsync("ThreatMitigated", threatId)
    }

    /// Client sends copilot message
    member this.CopilotMessage(message: string) : Task<string> = task {
        // Forward to AI Copilot and return response
        // Placeholder - would integrate with OpenRouter/Cortex
        return $"Copilot received: {message}. Analysis in progress..."
    }

    /// Called when client connects
    override this.OnConnectedAsync() =
        printfn $"Client connected: {this.Context.ConnectionId}"
        base.OnConnectedAsync()

    /// Called when client disconnects
    override this.OnDisconnectedAsync(ex: Exception) =
        printfn $"Client disconnected: {this.Context.ConnectionId}"
        base.OnDisconnectedAsync(ex)
