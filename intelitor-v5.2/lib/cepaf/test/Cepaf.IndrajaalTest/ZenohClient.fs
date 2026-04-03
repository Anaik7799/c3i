/// Cepaf.IndrajaalTest.ZenohClient
/// Zenoh connectivity for fractal logging and telemetry
///
/// STAMP Constraints:
/// - SC-ZENOH-001: Zenoh connection must be resilient
/// - SC-ZENOH-002: Subscriptions must handle backpressure
/// - SC-ZENOH-003: Telemetry must be validated
module Cepaf.IndrajaalTest.ZenohClient

open System
open System.Collections.Concurrent
open System.Net.Http
open System.Text
open System.Text.Json
open System.Threading
open System.Threading.Tasks

// =============================================================================
// Zenoh Configuration
// =============================================================================

/// Zenoh connection configuration
type ZenohConfig = {
    /// Zenoh router endpoint (REST API)
    RouterEndpoint: string
    /// Zenoh WebSocket endpoint for pub/sub
    WebSocketEndpoint: string
    /// Connection timeout
    Timeout: TimeSpan
    /// Reconnection delay
    ReconnectDelay: TimeSpan
    /// Maximum reconnection attempts
    MaxReconnectAttempts: int
}

/// Default Zenoh configuration for local development
let defaultZenohConfig: ZenohConfig = {
    RouterEndpoint = "http://localhost:8000"
    WebSocketEndpoint = "ws://localhost:8000"
    Timeout = TimeSpan.FromSeconds(10.0)
    ReconnectDelay = TimeSpan.FromSeconds(2.0)
    MaxReconnectAttempts = 5
}

/// Load Zenoh configuration from environment
let zenohConfigFromEnvironment () : ZenohConfig =
    let routerEndpoint =
        Environment.GetEnvironmentVariable("ZENOH_ROUTER")
        |> Option.ofObj
        |> Option.defaultValue "http://localhost:8000"
    let wsEndpoint =
        Environment.GetEnvironmentVariable("ZENOH_WS")
        |> Option.ofObj
        |> Option.defaultValue "ws://localhost:8000"
    {
        RouterEndpoint = routerEndpoint
        WebSocketEndpoint = wsEndpoint
        Timeout = TimeSpan.FromSeconds(10.0)
        ReconnectDelay = TimeSpan.FromSeconds(2.0)
        MaxReconnectAttempts = 5
    }

// =============================================================================
// Fractal Logging Key Expressions
// =============================================================================

/// Fractal logging key expression patterns
/// Based on Indrajaal's fractal logging 5-level hierarchy
module FractalKeyExpressions =
    /// Root namespace for Indrajaal
    let root = "indrajaal"

    /// Level 1: System-wide logs
    let system = sprintf "%s/system/**" root

    /// Level 2: Node-specific logs
    let node nodeId = sprintf "%s/node/%s/**" root nodeId

    /// Level 3: Domain-specific logs
    let domain domainName = sprintf "%s/domain/%s/**" root domainName

    /// Level 4: Component logs
    let componentLogs compName = sprintf "%s/component/%s/**" root compName

    /// Level 5: Detailed trace logs
    let trace = sprintf "%s/trace/**" root

    /// Telemetry metrics
    let metrics = sprintf "%s/metrics/**" root

    /// KPI dashboard data
    let kpi = sprintf "%s/kpi/**" root

    /// Alarms and alerts
    let alarms = sprintf "%s/alarms/**" root

    /// Device telemetry
    let devices = sprintf "%s/devices/**" root

    /// All Indrajaal logs
    let all = sprintf "%s/**" root

// =============================================================================
// Zenoh Message Types
// =============================================================================

/// Log level enumeration
type LogLevel =
    | Trace = 0
    | Debug = 1
    | Info = 2
    | Warning = 3
    | Error = 4
    | Critical = 5

/// Fractal log message
type FractalLogMessage = {
    Timestamp: DateTime
    Level: LogLevel
    Source: string
    Message: string
    KeyExpression: string
    Metadata: Map<string, string>
}

/// Telemetry metric
type TelemetryMetric = {
    Name: string
    Value: float
    Unit: string
    Timestamp: DateTime
    Tags: Map<string, string>
}

/// KPI data point
type KpiDataPoint = {
    Name: string
    Value: float
    Target: float option
    Status: string
    Timestamp: DateTime
}

/// Zenoh message wrapper
type ZenohMessage =
    | LogMessage of FractalLogMessage
    | Metric of TelemetryMetric
    | Kpi of KpiDataPoint
    | RawData of string * byte[]

// =============================================================================
// Zenoh Client
// =============================================================================

/// Zenoh connection state
type ConnectionState =
    | Disconnected
    | Connecting
    | Connected
    | Reconnecting
    | Failed of string

/// Zenoh client for fractal logging and telemetry
type ZenohClient(config: ZenohConfig) =
    let mutable state = Disconnected
    let mutable reconnectAttempts = 0
    let messageQueue = ConcurrentQueue<ZenohMessage>()
    let subscribers = ConcurrentDictionary<string, ZenohMessage -> unit>()
    let httpClient = new HttpClient()

    let jsonOptions =
        let opts = JsonSerializerOptions()
        opts.PropertyNamingPolicy <- JsonNamingPolicy.SnakeCaseLower
        opts.PropertyNameCaseInsensitive <- true
        opts

    /// Current connection state
    member _.State = state

    /// Messages received
    member _.MessageCount = messageQueue.Count

    /// Connect to Zenoh router
    member this.ConnectAsync() = async {
        try
            state <- Connecting
            printfn "Connecting to Zenoh at %s..." config.RouterEndpoint

            // Check Zenoh router health
            let! response =
                httpClient.GetAsync(config.RouterEndpoint + "/@/router/local")
                |> Async.AwaitTask

            if response.IsSuccessStatusCode then
                state <- Connected
                reconnectAttempts <- 0
                printfn "Connected to Zenoh router"
                return true
            else
                state <- Disconnected
                printfn "Zenoh router not responding (status: %d)" (int response.StatusCode)
                return false
        with
        | ex ->
            state <- Failed ex.Message
            printfn "Failed to connect to Zenoh: %s" ex.Message
            return false
    }

    /// Subscribe to a key expression
    member this.Subscribe(keyExpr: string, handler: ZenohMessage -> unit) =
        subscribers.TryAdd(keyExpr, handler) |> ignore
        printfn "Subscribed to: %s" keyExpr

    /// Unsubscribe from a key expression
    member this.Unsubscribe(keyExpr: string) =
        subscribers.TryRemove(keyExpr) |> ignore
        printfn "Unsubscribed from: %s" keyExpr

    /// Query a key expression (GET)
    member this.GetAsync(keyExpr: string) = async {
        try
            let url = sprintf "%s/%s" config.RouterEndpoint keyExpr
            let! response = httpClient.GetAsync(url) |> Async.AwaitTask

            if response.IsSuccessStatusCode then
                let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                return Some content
            else
                return None
        with
        | ex ->
            printfn "Zenoh GET failed: %s" ex.Message
            return None
    }

    /// Put data to a key expression
    member this.PutAsync(keyExpr: string, data: string) = async {
        try
            let url = sprintf "%s/%s" config.RouterEndpoint keyExpr
            let content = new StringContent(data, Encoding.UTF8, "application/json")
            let! response = httpClient.PutAsync(url, content) |> Async.AwaitTask

            return response.IsSuccessStatusCode
        with
        | ex ->
            printfn "Zenoh PUT failed: %s" ex.Message
            return false
    }

    /// Get fractal logs for a key expression
    member this.GetLogsAsync(keyExpr: string) = async {
        let! result = this.GetAsync(keyExpr)
        match result with
        | Some json ->
            try
                let logs = JsonSerializer.Deserialize<FractalLogMessage list>(json, jsonOptions)
                return logs
            with
            | _ -> return []
        | None -> return []
    }

    /// Get telemetry metrics
    member this.GetMetricsAsync() = async {
        let! result = this.GetAsync(FractalKeyExpressions.metrics)
        match result with
        | Some json ->
            try
                let metrics = JsonSerializer.Deserialize<TelemetryMetric list>(json, jsonOptions)
                return metrics
            with
            | _ -> return []
        | None -> return []
    }

    /// Get KPI dashboard data
    member this.GetKpiAsync() = async {
        let! result = this.GetAsync(FractalKeyExpressions.kpi)
        match result with
        | Some json ->
            try
                let kpis = JsonSerializer.Deserialize<KpiDataPoint list>(json, jsonOptions)
                return kpis
            with
            | _ -> return []
        | None -> return []
    }

    /// Check if Zenoh router is healthy
    member this.IsHealthy() = async {
        try
            let! response =
                httpClient.GetAsync(config.RouterEndpoint + "/@/router/local")
                |> Async.AwaitTask
            return response.IsSuccessStatusCode
        with
        | _ -> return false
    }

    /// Disconnect from Zenoh
    member this.Disconnect() =
        subscribers.Clear()
        state <- Disconnected
        printfn "Disconnected from Zenoh"

    interface IDisposable with
        member this.Dispose() =
            this.Disconnect()
            httpClient.Dispose()

// =============================================================================
// Fractal Logging Subscriber
// =============================================================================

/// Fractal logging subscriber for real-time log streaming
type FractalLogSubscriber(client: ZenohClient) =
    let logs = ConcurrentQueue<FractalLogMessage>()
    let mutable isRunning = false

    /// Start subscribing to fractal logs
    member this.Start() =
        isRunning <- true

        // Subscribe to all log levels
        client.Subscribe(FractalKeyExpressions.system, fun msg ->
            match msg with
            | LogMessage log -> logs.Enqueue(log)
            | _ -> ())

        client.Subscribe(FractalKeyExpressions.trace, fun msg ->
            match msg with
            | LogMessage log -> logs.Enqueue(log)
            | _ -> ())

    /// Stop subscribing
    member this.Stop() =
        isRunning <- false
        client.Unsubscribe(FractalKeyExpressions.system)
        client.Unsubscribe(FractalKeyExpressions.trace)

    /// Get all collected logs
    member _.GetLogs() =
        logs.ToArray() |> Array.toList

    /// Get logs by level
    member _.GetLogsByLevel(level: LogLevel) =
        logs.ToArray()
        |> Array.filter (fun l -> l.Level = level)
        |> Array.toList

    /// Clear collected logs
    member _.Clear() =
        while not logs.IsEmpty do
            logs.TryDequeue() |> ignore

// =============================================================================
// Telemetry Collector
// =============================================================================

/// Telemetry collector for metrics and KPIs
type TelemetryCollector(client: ZenohClient) =
    let metrics = ConcurrentDictionary<string, TelemetryMetric>()
    let kpis = ConcurrentDictionary<string, KpiDataPoint>()

    /// Collect current metrics
    member this.CollectMetricsAsync() = async {
        let! result = client.GetMetricsAsync()
        for metric in result do
            metrics.AddOrUpdate(metric.Name, metric, fun _ _ -> metric) |> ignore
        return result
    }

    /// Collect current KPIs
    member this.CollectKpiAsync() = async {
        let! result = client.GetKpiAsync()
        for kpi in result do
            kpis.AddOrUpdate(kpi.Name, kpi, fun _ _ -> kpi) |> ignore
        return result
    }

    /// Get latest metric value
    member _.GetMetric(name: string) =
        match metrics.TryGetValue(name) with
        | true, m -> Some m
        | _ -> None

    /// Get latest KPI value
    member _.GetKpi(name: string) =
        match kpis.TryGetValue(name) with
        | true, k -> Some k
        | _ -> None

    /// Get all metrics
    member _.AllMetrics = metrics.Values |> Seq.toList

    /// Get all KPIs
    member _.AllKpis = kpis.Values |> Seq.toList

// =============================================================================
// Helper Functions
// =============================================================================

/// Create a Zenoh client with default configuration
let createZenohClient () =
    new ZenohClient(defaultZenohConfig)

/// Create a Zenoh client from environment
let createZenohClientFromEnv () =
    new ZenohClient(zenohConfigFromEnvironment ())

/// Check Zenoh connectivity
let checkZenohConnectivity (config: ZenohConfig) = async {
    use client = new ZenohClient(config)
    return! client.IsHealthy()
}
