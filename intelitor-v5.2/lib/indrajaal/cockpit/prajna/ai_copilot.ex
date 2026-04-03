defmodule Indrajaal.Cockpit.Prajna.AiCopilot do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - AI Copilot (LLM Integration)

  WHAT: AI-powered intelligence enhancement for the cockpit operator.
        Provides anomaly detection, predictions, recommendations, and summaries.

  WHY: Humans excel at judgment; machines excel at pattern recognition.
       The AI Copilot augments human capabilities without replacing them.

  CONSTRAINTS:
    - SC-AI-001: AI suggestions are ADVISORY only (human in the loop)
    - SC-AI-002: Confidence scores MUST be displayed
    - SC-AI-003: AI recommendations logged for audit
    - SC-AI-004: Graceful degradation if AI unavailable

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                    AI COPILOT ENGINE                         │
  ├─────────────────────────────────────────────────────────────┤
  │  ┌─────────────────────────────────────────────────────┐    │
  │  │              LOCAL ANALYTICS (Always On)              │    │
  │  │  - Heuristic anomaly detection                        │    │
  │  │  - Trend-based predictions                            │    │
  │  │  - Pattern correlation                                │    │
  │  │  - Statistical baselines                              │    │
  │  └─────────────────────────────────────────────────────┘    │
  │                           ↓                                  │
  │  ┌─────────────────────────────────────────────────────┐    │
  │  │              LLM ENHANCEMENT (Optional)               │    │
  │  │  - Deep analysis via OpenRouter                       │    │
  │  │  - Natural language explanations                      │    │
  │  │  - Action recommendations                             │    │
  │  │  - Root cause analysis                                │    │
  │  └─────────────────────────────────────────────────────┘    │
  │                           ↓                                  │
  │  ┌─────────────────────────────────────────────────────┐    │
  │  │              INSIGHT AGGREGATOR                        │    │
  │  │  - Merge local + LLM insights                         │    │
  │  │  - Deduplicate and rank                               │    │
  │  │  - Apply confidence scoring                           │    │
  │  │  - Publish to cockpit                                 │    │
  │  └─────────────────────────────────────────────────────┘    │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AI-001 to SC-AI-004, SC-HITL-001 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.Domain
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Cockpit.Prajna.AiCopilotFounder

  @insight_ttl_seconds 300
  @analysis_interval_ms 10_000
  @max_insights 50

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current AI insights"
  @spec insights() :: list(Domain.ai_insight())
  def insights do
    GenServer.call(__MODULE__, :get_insights)
  end

  @doc "Get insights filtered by type"
  @spec insights_by_type(Domain.insight_type()) :: list(Domain.ai_insight())
  def insights_by_type(type) do
    insights() |> Enum.filter(&(&1.type == type))
  end

  @doc "Get insights above a confidence threshold"
  @spec high_confidence_insights(float()) :: list(Domain.ai_insight())
  def high_confidence_insights(threshold \\ 0.8) do
    insights() |> Enum.filter(&(&1.confidence >= threshold))
  end

  @doc "Request immediate AI analysis"
  @spec analyze_now() :: :ok
  def analyze_now do
    GenServer.cast(__MODULE__, :analyze_now)
  end

  @doc "Request analysis for specific focus area"
  @spec analyze_focus(String.t()) :: :ok
  def analyze_focus(focus_area) do
    GenServer.cast(__MODULE__, {:analyze_focus, focus_area})
  end

  @doc "Get quick status summary (local analytics only)"
  @spec quick_summary() :: Domain.ai_insight()
  def quick_summary do
    GenServer.call(__MODULE__, :quick_summary)
  end

  @doc "Enable/disable LLM integration"
  @spec set_llm_enabled(boolean()) :: :ok
  def set_llm_enabled(enabled) do
    GenServer.cast(__MODULE__, {:set_llm_enabled, enabled})
  end

  @doc "Check if LLM is available and enabled"
  @spec llm_available?() :: boolean()
  def llm_available? do
    GenServer.call(__MODULE__, :llm_available?)
  end

  @doc """
  Generate actionable recommendations based on current system context.

  Accepts an optional context map with keys like `:focus`, `:severity_filter`,
  `:max_items`. Returns a list of recommendation maps with `:action`, `:priority`,
  `:rationale`, and `:confidence` fields.

  Always runs local analytics (no LLM required). Validates against Founder's
  Directive (Ω₀) before returning.
  """
  @spec generate_recommendations(map()) :: {:ok, list(map())}
  def generate_recommendations(context \\ %{}) do
    GenServer.call(__MODULE__, {:generate_recommendations, context})
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl GenServer
  def init(opts) do
    llm_enabled = Keyword.get(opts, :llm_enabled, true)
    auto_analyze = Keyword.get(opts, :auto_analyze, true)

    if auto_analyze do
      schedule_analysis()
    end

    Logger.info("[Prajna.AiCopilot] Initialized (LLM: #{llm_enabled})")

    {:ok,
     %{
       insights: [],
       llm_enabled: llm_enabled,
       last_analysis: nil,
       analysis_count: 0,
       llm_calls: 0
     }}
  end

  @impl GenServer
  def handle_call(:get_insights, _from, state) do
    # Filter expired insights
    now = DateTime.utc_now()

    active_insights =
      state.insights
      |> Enum.reject(fn i ->
        i.expires_at && DateTime.compare(i.expires_at, now) == :lt
      end)

    {:reply, active_insights, %{state | insights: active_insights}}
  end

  @impl GenServer
  def handle_call(:quick_summary, _from, state) do
    summary = generate_local_summary()
    {:reply, summary, state}
  end

  @impl GenServer
  def handle_call(:llm_available?, _from, state) do
    available = state.llm_enabled && llm_configured?()
    {:reply, available, state}
  end

  @impl GenServer
  def handle_call({:generate_recommendations, context}, _from, state) do
    recommendations = build_recommendations(context)
    {:reply, {:ok, recommendations}, state}
  end

  @impl GenServer
  def handle_cast(:analyze_now, state) do
    new_state = perform_analysis(state, nil)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:analyze_focus, focus_area}, state) do
    new_state = perform_analysis(state, focus_area)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:set_llm_enabled, enabled}, state) do
    Logger.info("[Prajna.AiCopilot] LLM #{if enabled, do: "enabled", else: "disabled"}")
    {:noreply, %{state | llm_enabled: enabled}}
  end

  @impl GenServer
  def handle_info(:scheduled_analysis, state) do
    new_state = perform_analysis(state, nil)
    schedule_analysis()
    {:noreply, new_state}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # LOCAL ANALYTICS (No LLM Required)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Detect anomalies using local heuristics"
  def detect_local_anomalies do
    metrics = SmartMetrics.all()
    anomalies = []

    # Check for high CPU metrics
    cpu_anomalies =
      metrics
      |> Enum.filter(fn {id, _} -> String.contains?(id, "cpu") end)
      |> Enum.flat_map(fn {id, metric} ->
        cond do
          metric.value > 90 ->
            insight =
              Domain.create_insight(
                :anomaly,
                :warning,
                "High CPU on #{id}",
                "CPU at #{Float.round(metric.value, 1)}% with trend #{metric.trend}",
                0.95
              )

            [
              Map.merge(insight, %{
                related_nodes: [id],
                action_items: [
                  "Consider scaling or load balancing",
                  "Check for runaway processes"
                ]
              })
            ]

          metric.value > 75 and metric.trend in [:rising, :rising_fast] ->
            insight =
              Domain.create_insight(
                :prediction,
                :caution,
                "CPU Rising on #{id}",
                "CPU trending up rapidly (#{Float.round(metric.value, 1)}% #{Domain.trend_icon(metric.trend)})",
                0.80
              )

            [
              Map.merge(insight, %{
                related_nodes: [id],
                action_items: ["Monitor closely", "Prepare scaling action"]
              })
            ]

          true ->
            []
        end
      end)

    # Check for stale metrics
    stale_metrics = SmartMetrics.stale_metrics()

    stale_anomalies =
      if length(stale_metrics) > 0 do
        node_ids = Enum.map(stale_metrics, fn {id, _} -> id end)

        insight =
          Domain.create_insight(
            :anomaly,
            if(length(stale_metrics) > 2, do: :warning, else: :caution),
            "#{length(stale_metrics)} Metric(s) Stale",
            "Metrics without recent updates: #{Enum.join(node_ids, ", ")}",
            0.99
          )

        [
          Map.merge(insight, %{
            related_nodes: node_ids,
            action_items: [
              "Check network connectivity",
              "Verify data sources",
              "Restart collectors if needed"
            ]
          })
        ]
      else
        []
      end

    # Check for alarmed metrics
    alarmed = SmartMetrics.alarmed_metrics()

    alarm_anomalies =
      alarmed
      |> Enum.filter(fn {_, m} -> m.level in [:warning, :critical] end)
      |> Enum.take(3)
      |> Enum.map(fn {id, metric} ->
        insight =
          Domain.create_insight(
            :anomaly,
            metric.level,
            "Alert: #{metric.label}",
            "#{id}: #{Float.round(metric.value, 1)}#{metric.unit} exceeds threshold",
            0.90
          )

        Map.merge(insight, %{related_nodes: [id]})
      end)

    anomalies ++ cpu_anomalies ++ stale_anomalies ++ alarm_anomalies
  end

  @doc "Generate a quick summary without LLM"
  def generate_local_summary do
    health = SmartMetrics.health_summary()

    level =
      case health.status do
        :critical -> :warning
        :warning -> :warning
        :caution -> :caution
        _ -> :normal
      end

    insight =
      Domain.create_insight(
        :summary,
        level,
        "System Status: #{String.upcase(to_string(health.status))}",
        "Metrics: #{health.total_metrics} | Stale: #{health.stale_count} | Alarmed: #{health.alarmed_count} | Health: #{health.health_score}%",
        1.0
      )

    Map.merge(insight, %{
      expires_at: DateTime.add(DateTime.utc_now(), 30, :second)
    })
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # RECOMMENDATION ENGINE
  # ═══════════════════════════════════════════════════════════════════════════

  defp build_recommendations(context) do
    health = SmartMetrics.health_summary()
    metrics = SmartMetrics.all()
    anomalies = detect_local_anomalies()
    max_items = Map.get(context, :max_items, 10)
    severity_filter = Map.get(context, :severity_filter, nil)

    recommendations = []

    # Health-based recommendations
    recommendations =
      case health.status do
        :critical ->
          [
            %{
              action: "Initiate emergency capacity expansion",
              priority: :critical,
              rationale: "System health at #{health.health_score}% — below critical threshold",
              confidence: 0.95,
              category: :capacity
            },
            %{
              action: "Review and restart stale metric collectors",
              priority: :high,
              rationale: "#{health.stale_count} metrics stale — may indicate node failure",
              confidence: 0.90,
              category: :observability
            }
            | recommendations
          ]

        :warning ->
          [
            %{
              action: "Scale monitoring and prepare capacity buffer",
              priority: :high,
              rationale: "System health degraded to #{health.health_score}%",
              confidence: 0.85,
              category: :capacity
            }
            | recommendations
          ]

        _ ->
          recommendations
      end

    # Process utilization recommendations
    recommendations =
      metrics
      |> Enum.filter(fn {id, _} -> String.contains?(id, "process") end)
      |> Enum.reduce(recommendations, fn {_id, metric}, acc ->
        cond do
          metric.value > 80 ->
            [
              %{
                action:
                  "Audit long-running processes — utilization at #{Float.round(metric.value, 1)}%",
                priority: :high,
                rationale: "Process count approaching system limit",
                confidence: 0.88,
                category: :resources
              }
              | acc
            ]

          metric.value > 60 and metric.trend in [:rising, :rising_fast] ->
            [
              %{
                action:
                  "Monitor process growth trend — currently #{Float.round(metric.value, 1)}% and rising",
                priority: :medium,
                rationale: "Process count trending upward, may hit limits",
                confidence: 0.75,
                category: :resources
              }
              | acc
            ]

          true ->
            acc
        end
      end)

    # Memory recommendations
    total_mem_mb =
      try do
        :erlang.memory(:total) / 1_048_576
      rescue
        _ -> 0.0
      end

    recommendations =
      cond do
        total_mem_mb > 1024 ->
          [
            %{
              action:
                "Investigate memory consumption — #{Float.round(total_mem_mb, 0)} MB in use",
              priority: :high,
              rationale: "Memory exceeds 1 GB, risk of OOM under load spikes",
              confidence: 0.85,
              category: :resources
            }
            | recommendations
          ]

        total_mem_mb > 512 ->
          [
            %{
              action: "Review ETS table sizes and process heaps",
              priority: :medium,
              rationale:
                "Memory at #{Float.round(total_mem_mb, 0)} MB — proactive review advised",
              confidence: 0.70,
              category: :resources
            }
            | recommendations
          ]

        true ->
          recommendations
      end

    # Anomaly-driven recommendations
    recommendations =
      Enum.reduce(anomalies, recommendations, fn anomaly, acc ->
        case anomaly do
          %{type: :anomaly, level: level} when level in [:warning, :critical] ->
            actions = Map.get(anomaly, :action_items, [])

            Enum.map(actions, fn action_text ->
              %{
                action: action_text,
                priority: if(level == :critical, do: :critical, else: :high),
                rationale: Map.get(anomaly, :description, "Anomaly detected"),
                confidence: Map.get(anomaly, :confidence, 0.8),
                category: :anomaly
              }
            end) ++ acc

          _ ->
            acc
        end
      end)

    # Stale metrics recommendation
    recommendations =
      if health.stale_count > 0 do
        [
          %{
            action: "Investigate #{health.stale_count} stale metric source(s)",
            priority: if(health.stale_count > 3, do: :high, else: :medium),
            rationale: "Stale metrics reduce observability coverage",
            confidence: 0.92,
            category: :observability
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Homeostasis recommendation if stress is available
    recommendations =
      try do
        stress = Indrajaal.Cortex.Homeostasis.stress_level()

        if stress > 0.7 do
          [
            %{
              action:
                "Homeostasis stress at #{Float.round(stress * 100, 1)}% — consider workload shedding",
              priority: :high,
              rationale: "System stress exceeds optimal band (30-60%)",
              confidence: 0.90,
              category: :homeostasis
            }
            | recommendations
          ]
        else
          recommendations
        end
      rescue
        _ -> recommendations
      catch
        :exit, _ -> recommendations
      end

    # Filter, deduplicate, and sort
    recommendations
    |> Enum.uniq_by(& &1.action)
    |> maybe_filter_severity(severity_filter)
    |> Enum.sort_by(&priority_rank(&1.priority))
    |> Enum.take(max_items)
    |> Enum.map(fn rec ->
      # Validate each recommendation against Founder's Directive (Ω₀)
      case AiCopilotFounder.validate_recommendation(rec) do
        :ok -> rec
        {:reject, _reason} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp maybe_filter_severity(recs, nil), do: recs

  defp maybe_filter_severity(recs, filter) do
    Enum.filter(recs, &(&1.priority == filter))
  end

  defp priority_rank(:critical), do: 0
  defp priority_rank(:high), do: 1
  defp priority_rank(:medium), do: 2
  defp priority_rank(:low), do: 3
  defp priority_rank(_), do: 4

  # ═══════════════════════════════════════════════════════════════════════════
  # LLM INTEGRATION
  # ═══════════════════════════════════════════════════════════════════════════

  defp perform_analysis(state, focus_area) do
    # Always run local analytics
    local_anomalies = detect_local_anomalies()
    local_summary = generate_local_summary()

    # Try LLM analysis if enabled
    llm_insight =
      if state.llm_enabled and llm_configured?() do
        try do
          context = generate_context(focus_area)
          request_llm_analysis(context)
        rescue
          e ->
            Logger.warning("[Prajna.AiCopilot] LLM analysis failed: #{inspect(e)}")
            nil
        end
      else
        nil
      end

    # Combine insights
    new_insights =
      [local_summary | local_anomalies]
      |> maybe_add_llm_insight(llm_insight)
      |> Enum.take(@max_insights)

    # Publish insights (if PubSub is available)
    safe_broadcast("prajna:insights", {:insights_updated, new_insights})

    # Log for audit (SC-AI-003)
    Logger.info(
      "[Prajna.AiCopilot] Analysis complete: #{length(new_insights)} insights (LLM: #{llm_insight != nil})"
    )

    %{
      state
      | insights: new_insights,
        last_analysis: DateTime.utc_now(),
        analysis_count: state.analysis_count + 1,
        llm_calls: if(llm_insight, do: state.llm_calls + 1, else: state.llm_calls)
    }
  end

  defp generate_context(focus_area) do
    health = SmartMetrics.health_summary()
    metrics = SmartMetrics.all() |> Enum.take(20)

    metrics_lines =
      Enum.map(metrics, fn {id, m} ->
        trend = Domain.trend_icon(m.trend)
        "  #{id}: #{Float.round(m.value, 1)}#{m.unit} #{trend} [#{m.level}]"
      end)

    metrics_summary = Enum.join(metrics_lines, "\n")

    focus_text = if focus_area, do: "\nFOCUS AREA: #{focus_area}\n", else: ""

    """
    SYSTEM STATUS SNAPSHOT
    ======================
    Time: #{DateTime.utc_now() |> DateTime.to_string()}
    Total Metrics: #{health.total_metrics}
    Health Score: #{health.health_score}%
    Stale: #{health.stale_count} | Alarmed: #{health.alarmed_count}
    #{focus_text}
    METRICS:
    #{metrics_summary}

    Please analyze this system state and provide:
    1. Any anomalies or concerns
    2. Predicted issues based on trends
    3. Recommended actions (if any)
    4. Brief status summary

    Be concise and focus on actionable insights.
    """
  end

  defp request_llm_analysis(context) do
    messages = [
      %{
        role: "system",
        content:
          "You are PRAJNA, an AI copilot for a safety-critical distributed control system. Provide concise, actionable insights. Always express uncertainty when appropriate. Your suggestions are ADVISORY only - a human operator makes final decisions."
      },
      %{role: "user", content: context}
    ]

    case OpenRouterClient.chat(messages, model: "anthropic/claude-3.5-sonnet", max_tokens: 300) do
      {:ok, response} ->
        parse_llm_response(response)

      {:error, reason} ->
        Logger.warning("[Prajna.AiCopilot] LLM request failed: #{inspect(reason)}")
        nil
    end
  end

  defp parse_llm_response(response) do
    content =
      response["choices"] |> List.first() |> Map.get("message", %{}) |> Map.get("content", "")

    has_anomaly =
      String.contains?(String.downcase(content), "anomal") or
        String.contains?(String.downcase(content), "concern")

    has_warning =
      String.contains?(String.downcase(content), "warning") or
        String.contains?(String.downcase(content), "critical")

    has_prediction =
      String.contains?(String.downcase(content), "predict") or
        String.contains?(String.downcase(content), "trend")

    type =
      cond do
        has_anomaly -> :anomaly
        has_prediction -> :prediction
        true -> :summary
      end

    level =
      cond do
        has_warning -> :caution
        has_anomaly -> :advisory
        true -> :normal
      end

    title =
      cond do
        has_anomaly -> "Anomaly Detected"
        has_prediction -> "Trend Analysis"
        true -> "AI Status Summary"
      end

    # Extract action items (lines starting with - or * or numbered)
    action_items =
      content
      |> String.split("\n")
      |> Enum.filter(fn line ->
        trimmed = String.trim(line)

        String.starts_with?(trimmed, "- ") or
          String.starts_with?(trimmed, "* ") or
          Regex.match?(~r/^\d+\./, trimmed)
      end)
      |> Enum.map(&String.trim(&1, "- *0_123_456_789."))
      |> Enum.take(5)

    insight =
      Domain.create_insight(
        type,
        level,
        title,
        content,
        if(has_anomaly or has_warning, do: 0.85, else: 0.75)
      )

    insight_with_actions =
      Map.merge(insight, %{
        action_items: action_items,
        expires_at: DateTime.add(DateTime.utc_now(), @insight_ttl_seconds, :second)
      })

    # SC-FOUNDER-001: Validate against Founder's Directive (Ω₀)
    case AiCopilotFounder.validate_recommendation(insight_with_actions) do
      :ok ->
        insight_with_actions

      {:reject, reason} ->
        Logger.warning("🛑 [Prajna.AiCopilot] Founder Directive VETO: #{reason}")

        # ZUIP: Publish Guardian veto to Zenoh mesh
        safe_publish(:publish_guardian_veto, [insight_with_actions, reason])

        # Transform into a rejection alert for transparency
        Domain.create_insight(
          :anomaly,
          :warning,
          "Ω₀ Directive Veto",
          "AI recommendation blocked by Founder's Directive: #{reason}",
          1.0
        )
    end
  end

  defp maybe_add_llm_insight(insights, nil), do: insights
  defp maybe_add_llm_insight(insights, llm_insight), do: [llm_insight | insights]

  defp llm_configured? do
    case Application.get_env(:indrajaal, :openrouter_api_key) do
      nil -> System.get_env("OPENROUTER_API_KEY") != nil
      key -> key != nil and key != ""
    end
  end

  defp schedule_analysis do
    Process.send_after(self(), :scheduled_analysis, @analysis_interval_ms)
  end

  defp safe_broadcast(topic, message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, topic, message)
    rescue
      ArgumentError -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp safe_publish(function, args) do
    try do
      case Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher) do
        {:module, mod} -> apply(mod, function, args)
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end
end
