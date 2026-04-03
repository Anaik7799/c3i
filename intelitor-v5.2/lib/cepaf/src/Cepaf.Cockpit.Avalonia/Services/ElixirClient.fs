// =============================================================================
// Prajna C3I Cockpit - Elixir Backend Client
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011, SC-PRAJNA-001 to SC-PRAJNA-007
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-PRAJNA-*, AOR-PRAJNA-* |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Services

open System
open System.Net.Http
open System.Net.Http.Json
open System.Text.Json
open System.Threading
open System.Threading.Tasks
open Cepaf.Cockpit.Avalonia.Domain.Types

/// <summary>
/// HTTP client for communication with Elixir Phoenix backend
/// Implements circuit breaker, retry logic, and health monitoring
/// </summary>
module ElixirClient =

    // =========================================================================
    // Configuration
    // =========================================================================

    type ClientConfig = {
        BaseUrl: string
        TimeoutMs: int
        MaxRetries: int
        CircuitBreakerThreshold: int
        CircuitBreakerResetMs: int
    }

    let defaultConfig = {
        BaseUrl = "http://localhost:4000"
        TimeoutMs = 5000
        MaxRetries = 3
        CircuitBreakerThreshold = 3
        CircuitBreakerResetMs = 30000
    }

    // =========================================================================
    // Circuit Breaker State
    // =========================================================================

    type CircuitState =
        | Closed
        | Open of DateTime
        | HalfOpen

    type private CircuitBreaker = {
        mutable State: CircuitState
        mutable FailureCount: int
        mutable LastFailure: DateTime
        Threshold: int
        ResetTimeMs: int
    }

    let private createCircuitBreaker threshold resetMs = {
        State = Closed
        FailureCount = 0
        LastFailure = DateTime.MinValue
        Threshold = threshold
        ResetTimeMs = resetMs
    }

    // =========================================================================
    // Client State
    // =========================================================================

    type ClientState = {
        Config: ClientConfig
        HttpClient: HttpClient
        CircuitBreaker: CircuitBreaker
        mutable ConnectionStatus: ConnectionStatus
        mutable LastSync: DateTime
    }

    let create (config: ClientConfig) : ClientState =
        let httpClient = new HttpClient()
        httpClient.BaseAddress <- Uri(config.BaseUrl)
        httpClient.Timeout <- TimeSpan.FromMilliseconds(float config.TimeoutMs)

        {
            Config = config
            HttpClient = httpClient
            CircuitBreaker = createCircuitBreaker config.CircuitBreakerThreshold config.CircuitBreakerResetMs
            ConnectionStatus = Disconnected
            LastSync = DateTime.MinValue
        }

    let createDefault () = create defaultConfig

    // =========================================================================
    // Circuit Breaker Logic
    // =========================================================================

    let private checkCircuit (cb: CircuitBreaker) : bool =
        match cb.State with
        | Closed -> true
        | Open openTime ->
            if (DateTime.UtcNow - openTime).TotalMilliseconds > float cb.ResetTimeMs then
                cb.State <- HalfOpen
                true
            else
                false
        | HalfOpen -> true

    let private recordSuccess (cb: CircuitBreaker) =
        cb.State <- Closed
        cb.FailureCount <- 0

    let private recordFailure (cb: CircuitBreaker) =
        cb.FailureCount <- cb.FailureCount + 1
        cb.LastFailure <- DateTime.UtcNow
        if cb.FailureCount >= cb.Threshold then
            cb.State <- Open DateTime.UtcNow

    // =========================================================================
    // API Endpoints
    // =========================================================================

    type ApiEndpoint =
        | Health
        | SystemHealth
        | Alarms
        | AlarmsActive
        | AlarmAcknowledge of Guid
        | AlarmClear of Guid
        | Devices
        | DeviceById of Guid
        | VideoStreams
        | Proposals
        | ProposalApprove of Guid
        | ProposalVeto of Guid
        | SentinelState
        | SentinelAssess
        | RegisterBlocks
        | RegisterVerify
        | CopilotChat
        | Analytics
        | Compliance
        | TestEvolution
        | OodaState

    let endpointPath = function
        | Health -> "/api/health"
        | SystemHealth -> "/api/prajna/health"
        | Alarms -> "/api/prajna/alarms"
        | AlarmsActive -> "/api/prajna/alarms/active"
        | AlarmAcknowledge id -> $"/api/prajna/alarms/{id}/acknowledge"
        | AlarmClear id -> $"/api/prajna/alarms/{id}/clear"
        | Devices -> "/api/prajna/devices"
        | DeviceById id -> $"/api/prajna/devices/{id}"
        | VideoStreams -> "/api/prajna/video/streams"
        | Proposals -> "/api/prajna/guardian/proposals"
        | ProposalApprove id -> $"/api/prajna/guardian/proposals/{id}/approve"
        | ProposalVeto id -> $"/api/prajna/guardian/proposals/{id}/veto"
        | SentinelState -> "/api/prajna/sentinel/state"
        | SentinelAssess -> "/api/prajna/sentinel/assess"
        | RegisterBlocks -> "/api/prajna/register/blocks"
        | RegisterVerify -> "/api/prajna/register/verify"
        | CopilotChat -> "/api/prajna/copilot/chat"
        | Analytics -> "/api/prajna/analytics"
        | Compliance -> "/api/prajna/compliance"
        | TestEvolution -> "/api/cockpit/test-evolution"
        | OodaState -> "/api/cockpit/ooda"

    // =========================================================================
    // HTTP Operations
    // =========================================================================

    let private executeWithRetry (state: ClientState) (operation: unit -> Task<'T>) : Task<Result<'T, string>> =
        task {
            if not (checkCircuit state.CircuitBreaker) then
                return Error "Circuit breaker is open"
            else
                let mutable lastError = ""
                let mutable attempt = 0
                let mutable success = false
                let mutable result = Unchecked.defaultof<'T>

                while attempt < state.Config.MaxRetries && not success do
                    try
                        let! response = operation()
                        result <- response
                        success <- true
                        recordSuccess state.CircuitBreaker
                        state.ConnectionStatus <- Connected
                    with ex ->
                        lastError <- ex.Message
                        attempt <- attempt + 1
                        if attempt < state.Config.MaxRetries then
                            // Exponential backoff
                            do! Task.Delay(1000 * (pown 2 attempt))

                if success then
                    return Ok result
                else
                    recordFailure state.CircuitBreaker
                    state.ConnectionStatus <- Error lastError
                    return Error lastError
        }

    let get<'T> (state: ClientState) (endpoint: ApiEndpoint) : Task<Result<'T, string>> =
        executeWithRetry state (fun () ->
            task {
                let! response = state.HttpClient.GetAsync(endpointPath endpoint)
                response.EnsureSuccessStatusCode() |> ignore
                let! result = response.Content.ReadFromJsonAsync<'T>()
                return result
            })

    let post<'TRequest, 'TResponse> (state: ClientState) (endpoint: ApiEndpoint) (data: 'TRequest) : Task<Result<'TResponse, string>> =
        executeWithRetry state (fun () ->
            task {
                let! response = state.HttpClient.PostAsJsonAsync(endpointPath endpoint, data)
                response.EnsureSuccessStatusCode() |> ignore
                let! result = response.Content.ReadFromJsonAsync<'TResponse>()
                return result
            })

    let postEmpty<'TResponse> (state: ClientState) (endpoint: ApiEndpoint) : Task<Result<'TResponse, string>> =
        executeWithRetry state (fun () ->
            task {
                let! response = state.HttpClient.PostAsync(endpointPath endpoint, null)
                response.EnsureSuccessStatusCode() |> ignore
                let! result = response.Content.ReadFromJsonAsync<'TResponse>()
                return result
            })

    // =========================================================================
    // Domain-Specific Operations
    // =========================================================================

    let checkHealth (state: ClientState) : Task<Result<bool, string>> =
        task {
            let! result = get<{| status: string |}> state Health
            return result |> Result.map (fun r -> r.status = "ok")
        }

    let getSystemHealth (state: ClientState) : Task<Result<SystemHealth, string>> =
        get<SystemHealth> state SystemHealth

    let getAlarms (state: ClientState) : Task<Result<Alarm list, string>> =
        get<Alarm list> state Alarms

    let getActiveAlarms (state: ClientState) : Task<Result<Alarm list, string>> =
        get<Alarm list> state AlarmsActive

    let acknowledgeAlarm (state: ClientState) (id: Guid) : Task<Result<bool, string>> =
        postEmpty<{| success: bool |}> state (AlarmAcknowledge id)
        |> Task.map (Result.map (fun r -> r.success))

    let clearAlarm (state: ClientState) (id: Guid) : Task<Result<bool, string>> =
        postEmpty<{| success: bool |}> state (AlarmClear id)
        |> Task.map (Result.map (fun r -> r.success))

    let getDevices (state: ClientState) : Task<Result<Device list, string>> =
        get<Device list> state Devices

    let getProposals (state: ClientState) : Task<Result<Proposal list, string>> =
        get<Proposal list> state Proposals

    let approveProposal (state: ClientState) (id: Guid) : Task<Result<bool, string>> =
        postEmpty<{| success: bool |}> state (ProposalApprove id)
        |> Task.map (Result.map (fun r -> r.success))

    let vetoProposal (state: ClientState) (id: Guid) (reason: string) : Task<Result<bool, string>> =
        post<{| reason: string |}, {| success: bool |}> state (ProposalVeto id) {| reason = reason |}
        |> Task.map (Result.map (fun r -> r.success))

    let getSentinelState (state: ClientState) : Task<Result<SentinelState, string>> =
        get<SentinelState> state SentinelState

    let triggerAssessment (state: ClientState) : Task<Result<float, string>> =
        postEmpty<{| health_score: float |}> state SentinelAssess
        |> Task.map (Result.map (fun r -> r.health_score))

    let getRegisterBlocks (state: ClientState) : Task<Result<RegisterBlock list, string>> =
        get<RegisterBlock list> state RegisterBlocks

    let verifyRegister (state: ClientState) : Task<Result<bool, string>> =
        postEmpty<{| verified: bool |}> state RegisterVerify
        |> Task.map (Result.map (fun r -> r.verified))

    type ChatRequest = { message: string; context: string }
    type ChatResponse = { response: string; thinking: bool }

    let sendChatMessage (state: ClientState) (message: string) (context: string) : Task<Result<ChatResponse, string>> =
        post<ChatRequest, ChatResponse> state CopilotChat { message = message; context = context }

    let getTestEvolutionState (state: ClientState) : Task<Result<TestEvolutionState, string>> =
        get<TestEvolutionState> state TestEvolution

    let getOodaState (state: ClientState) : Task<Result<OodaState, string>> =
        get<OodaState> state OodaState

    // =========================================================================
    // Connection Management
    // =========================================================================

    let connect (state: ClientState) : Task<bool> =
        task {
            state.ConnectionStatus <- Connecting
            let! result = checkHealth state
            match result with
            | Ok true ->
                state.ConnectionStatus <- Connected
                state.LastSync <- DateTime.UtcNow
                return true
            | Ok false ->
                state.ConnectionStatus <- Error "Health check failed"
                return false
            | Error err ->
                state.ConnectionStatus <- Error err
                return false
        }

    let disconnect (state: ClientState) =
        state.ConnectionStatus <- Disconnected
        state.HttpClient.CancelPendingRequests()

    let dispose (state: ClientState) =
        disconnect state
        state.HttpClient.Dispose()
