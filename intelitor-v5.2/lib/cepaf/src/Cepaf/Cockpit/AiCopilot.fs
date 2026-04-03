namespace Cepaf.Cockpit

open System
open System.Net.Http
open System.Text
open Cepaf.Cockpit.Domain

/// ═══════════════════════════════════════════════════════════════════════════════
/// C3I MESH COCKPIT - AI COPILOT (LLM Integration)
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: AI-powered intelligence enhancement for the cockpit operator.
///       Provides anomaly detection, predictions, recommendations, and summaries.
///
/// WHY: Humans excel at judgment; machines excel at pattern recognition.
///      The AI Copilot augments human capabilities without replacing them.
///
/// STAMP Compliance:
///   - SC-AI-001: AI suggestions are ADVISORY only (human in the loop)
///   - SC-AI-002: Confidence scores must be displayed
///   - SC-AI-003: AI recommendations logged for audit
///   - SC-AI-004: Graceful degradation if AI unavailable
///
/// ═══════════════════════════════════════════════════════════════════════════════
module AiCopilot =

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════

    type AiConfig = {
        Enabled: bool
        ApiEndpoint: string option       // OpenRouter, Anthropic, etc.
        ApiKey: string option
        Model: string
        MaxTokens: int
        Temperature: float
        TimeoutMs: int
    }

    let defaultConfig = {
        Enabled = true
        ApiEndpoint = None  // Will use OpenRouter via Elixir bridge
        ApiKey = None
        Model = "anthropic/claude-3.5-sonnet"
        MaxTokens = 500
        Temperature = 0.3  // Low temperature for consistent analysis
        TimeoutMs = 10000
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONTEXT GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Generate analysis context from cockpit state
    let generateContext (state: CockpitState) (focusArea: string option) : string =
        let nodesSummary =
            state.Nodes
            |> Map.toList
            |> List.map (fun (id, node) ->
                let status =
                    match node.Status with
                    | Connected -> "OK"
                    | Stale -> "STALE"
                    | Degraded -> "DEGRADED"
                    | Disconnected -> "OFFLINE"
                let trend =
                    match node.Cpu.Trend with
                    | Rising | RisingFast -> "↑"
                    | Falling | FallingFast -> "↓"
                    | Stable -> "→"
                sprintf "  %s (%s): CPU=%.0f%%%s MEM=%.0f%% HEALTH=%d%%"
                    id status node.Cpu.Value trend node.Memory.Value node.HealthScore.Value
            )
            |> String.concat "\n"

        let alarmsSummary =
            state.Alarms
            |> Map.toList
            |> List.filter (fun (_, a) -> a.AcknowledgedAt.IsNone)
            |> List.map (fun (_, a) ->
                sprintf "  [%A] %s: %s" a.Level a.NodeId a.Message
            )
            |> String.concat "\n"

        let focusText =
            match focusArea with
            | Some area -> sprintf "\nFOCUS AREA: %s\n" area
            | None -> ""

        let time = DateTime.UtcNow.ToString("HH:mm:ss")
        let nodeCount = Map.count state.Nodes
        let alarmCount = state.Alarms |> Map.filter (fun _ a -> a.AcknowledgedAt.IsNone) |> Map.count
        let msgCount = int state.MessagesReceived
        let nodesStr = if String.IsNullOrEmpty nodesSummary then "  (none)" else nodesSummary
        let alarmsStr = if String.IsNullOrEmpty alarmsSummary then "  (none)" else alarmsSummary

        String.Format("""
SYSTEM STATUS SNAPSHOT
======================
Time: {0}
Active Nodes: {1}
Active Alarms: {2}
Messages Received: {3}
{4}
NODES:
{5}

ACTIVE ALARMS:
{6}

Please analyze this system state and provide:
1. Any anomalies or concerns
2. Predicted issues based on trends
3. Recommended actions (if any)
4. Brief status summary

Be concise and focus on actionable insights.
""", time, nodeCount, alarmCount, msgCount, focusText, nodesStr, alarmsStr)

    // ═══════════════════════════════════════════════════════════════════════════
    // INSIGHT PARSING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Parse AI response into structured insight
    let parseAiResponse (response: string) : AiInsight =
        // Extract key information from response
        let hasAnomaly = response.Contains("anomal", StringComparison.OrdinalIgnoreCase) ||
                         response.Contains("concern", StringComparison.OrdinalIgnoreCase)
        let hasWarning = response.Contains("warning", StringComparison.OrdinalIgnoreCase) ||
                         response.Contains("critical", StringComparison.OrdinalIgnoreCase)
        let hasPrediction = response.Contains("predict", StringComparison.OrdinalIgnoreCase) ||
                            response.Contains("trend", StringComparison.OrdinalIgnoreCase)

        let insightType =
            if hasAnomaly then Anomaly
            elif hasPrediction then Prediction
            else Summary

        let level =
            if hasWarning then Caution
            elif hasAnomaly then Advisory
            else Normal

        // Extract action items (lines starting with "- " or "* " or numbered)
        let actionItems =
            response.Split('\n')
            |> Array.filter (fun line ->
                let trimmed = line.Trim()
                trimmed.StartsWith("- ") ||
                trimmed.StartsWith("* ") ||
                (trimmed.Length > 2 && Char.IsDigit(trimmed.[0]) && trimmed.[1] = '.')
            )
            |> Array.map (fun line -> line.TrimStart('-', '*', ' ', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '.'))
            |> Array.toList

        {
            Id = Guid.NewGuid().ToString("N").[..7]
            Type = insightType
            Level = level
            Title = if hasAnomaly then "Anomaly Detected" elif hasPrediction then "Trend Analysis" else "Status Summary"
            Description = response
            RelatedNodes = []
            RelatedAlarms = []
            Confidence = if hasAnomaly || hasWarning then 0.85 else 0.75
            GeneratedAt = DateTime.UtcNow
            ExpiresAt = Some (DateTime.UtcNow.AddMinutes(5.0))
            ActionItems = actionItems
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // LOCAL ANALYTICS (No LLM required)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Detect anomalies using local heuristics
    let detectLocalAnomalies (state: CockpitState) : AiInsight list =
        let anomalies = ResizeArray<AiInsight>()

        // Check for nodes with high CPU
        state.Nodes
        |> Map.iter (fun id node ->
            if node.Cpu.Value > 90.0 then
                anomalies.Add {
                    Id = sprintf "local-cpu-%s" id
                    Type = Anomaly
                    Level = Warning
                    Title = sprintf "High CPU on %s" id
                    Description = sprintf "Node %s CPU at %.0f%% with trend %A" id node.Cpu.Value node.Cpu.Trend
                    RelatedNodes = [id]
                    RelatedAlarms = []
                    Confidence = 0.95
                    GeneratedAt = DateTime.UtcNow
                    ExpiresAt = None
                    ActionItems = ["Consider scaling or load balancing"; "Check for runaway processes"]
                }
            elif node.Cpu.Value > 75.0 && node.Cpu.Trend = RisingFast then
                anomalies.Add {
                    Id = sprintf "local-cpu-trend-%s" id
                    Type = Prediction
                    Level = Caution
                    Title = sprintf "CPU Rising on %s" id
                    Description = sprintf "Node %s CPU trending up rapidly (%.0f%% ↑↑)" id node.Cpu.Value
                    RelatedNodes = [id]
                    RelatedAlarms = []
                    Confidence = 0.80
                    GeneratedAt = DateTime.UtcNow
                    ExpiresAt = Some (DateTime.UtcNow.AddMinutes(2.0))
                    ActionItems = ["Monitor closely"; "Prepare scaling action"]
                }
        )

        // Check for stale nodes
        let staleNodes =
            state.Nodes
            |> Map.filter (fun _ n -> n.Status = Stale || n.Status = Disconnected)
            |> Map.toList

        if staleNodes.Length > 0 then
            anomalies.Add {
                Id = "local-connectivity"
                Type = Anomaly
                Level = if staleNodes.Length > 2 then Warning else Caution
                Title = sprintf "%d Node(s) Unresponsive" staleNodes.Length
                Description =
                    sprintf "Nodes without recent telemetry: %s"
                        (staleNodes |> List.map fst |> String.concat ", ")
                RelatedNodes = staleNodes |> List.map fst
                RelatedAlarms = []
                Confidence = 0.99
                GeneratedAt = DateTime.UtcNow
                ExpiresAt = None
                ActionItems = ["Check network connectivity"; "Verify node health"; "Consider restart if unrecoverable"]
            }

        anomalies |> Seq.toList

    /// Generate a quick summary without LLM
    let generateLocalSummary (state: CockpitState) : AiInsight =
        let totalNodes = Map.count state.Nodes
        let healthyNodes = state.Nodes |> Map.filter (fun _ n -> n.Status = Connected && n.HealthScore.Value >= 80) |> Map.count
        let activeAlarms = state.Alarms |> Map.filter (fun _ a -> a.AcknowledgedAt.IsNone) |> Map.count

        let avgCpu =
            if totalNodes > 0 then
                (state.Nodes |> Map.toList |> List.sumBy (fun (_, n) -> n.Cpu.Value)) / float totalNodes
            else 0.0

        let overallHealth =
            if totalNodes = 0 then "UNKNOWN"
            elif healthyNodes = totalNodes && activeAlarms = 0 then "HEALTHY"
            elif float healthyNodes / float totalNodes >= 0.9 && activeAlarms < 3 then "GOOD"
            elif float healthyNodes / float totalNodes >= 0.7 then "DEGRADED"
            else "CRITICAL"

        {
            Id = "local-summary"
            Type = Summary
            Level = if overallHealth = "CRITICAL" then Warning elif overallHealth = "DEGRADED" then Caution else Normal
            Title = sprintf "System Status: %s" overallHealth
            Description =
                sprintf "Nodes: %d/%d healthy | Avg CPU: %.0f%% | Active Alarms: %d"
                    healthyNodes totalNodes avgCpu activeAlarms
            RelatedNodes = []
            RelatedAlarms = []
            Confidence = 1.0  // Local analysis is deterministic
            GeneratedAt = DateTime.UtcNow
            ExpiresAt = Some (DateTime.UtcNow.AddSeconds(30.0))
            ActionItems = []
        }

    // ═══════════════════════════════════════════════════════════════════════════
    // AI SERVICE (LLM Integration)
    // ═══════════════════════════════════════════════════════════════════════════

    type AiService(config: AiConfig) =
        let httpClient = new HttpClient()

        /// Request analysis from LLM
        member _.AnalyzeAsync(context: string) : Async<AiInsight option> = async {
            if not config.Enabled then
                return None
            else
                match config.ApiEndpoint, config.ApiKey with
                | Some endpoint, Some key ->
                    try
                        let serializedContext = System.Text.Json.JsonSerializer.Serialize(context)
                        let requestBody =
                            sprintf """{"model": "%s", "messages": [{"role": "user", "content": %s}], "max_tokens": %d, "temperature": %f}"""
                                config.Model serializedContext config.MaxTokens config.Temperature

                        httpClient.DefaultRequestHeaders.Clear()
                        httpClient.DefaultRequestHeaders.Add("Authorization", sprintf "Bearer %s" key)
                        httpClient.Timeout <- TimeSpan.FromMilliseconds(float config.TimeoutMs)

                        let content = new StringContent(requestBody, Encoding.UTF8, "application/json")
                        let! response = httpClient.PostAsync(endpoint, content) |> Async.AwaitTask

                        if response.IsSuccessStatusCode then
                            let! responseBody = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                            // Parse response (simplified - would use proper JSON parsing)
                            return Some (parseAiResponse responseBody)
                        else
                            return None
                    with _ ->
                        return None
                | _ ->
                    return None
        }

        /// Analyze with fallback to local analytics
        member this.AnalyzeWithFallback(state: CockpitState) : Async<AiInsight list> = async {
            // Always run local analytics
            let localAnomalies = detectLocalAnomalies state
            let localSummary = generateLocalSummary state

            // Try LLM analysis if enabled
            let! llmInsight =
                if config.Enabled && config.ApiEndpoint.IsSome then
                    let context = generateContext state None
                    this.AnalyzeAsync(context)
                else
                    async { return None }

            match llmInsight with
            | Some insight ->
                return localSummary :: insight :: localAnomalies
            | None ->
                return localSummary :: localAnomalies
        }

        interface IDisposable with
            member _.Dispose() = httpClient.Dispose()

    // ═══════════════════════════════════════════════════════════════════════════
    // COPILOT INTERFACE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create the AI Copilot request function for the Bridge Agent
    let createAiRequestFunction (config: AiConfig) : string -> Async<AiInsight option> =
        use service = new AiService(config)
        fun context -> service.AnalyzeAsync(context)

    /// Get quick insights without external API
    let getQuickInsights (state: CockpitState) : AiInsight list =
        let summary = generateLocalSummary state
        let anomalies = detectLocalAnomalies state
        summary :: anomalies
