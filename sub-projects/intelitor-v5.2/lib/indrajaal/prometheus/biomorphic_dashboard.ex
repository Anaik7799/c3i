defmodule Indrajaal.Prometheus.BiomorphicDashboard do
  @moduledoc """
  PROMETHEUS Biomorphic Dashboard - Intelligent Agent Orchestration & Monitoring.

  ## WHAT
  Real-time dashboard for biomorphic agent swarm management with fractal observability,
  metabolic scaling, and PROMETHEUS verification integration.

  ## WHY
  - SC-PROM-003: Dashboard MUST refresh every 30s; stale data > 60s triggers Alert
  - SC-API-001: Max concurrent agents 5-25 based on rate limit headroom
  - AOR-PROM-001: Agents MUST report "Thinking" state to Dashboard bus
  - AOR-API-007: Display agent count, API KPIs, rate limit status every 30s

  ## CONSTRAINTS
  - Target Load: 200% of theoretical max (virtual saturation target)
  - Redline: 95% of Hard Limit (absolute ceiling)
  - OODA Loop: 30-second heartbeat
  - Context Compaction: Trigger at 80% usage (AOR-PROM-003)

  ## STAMP Compliance
  - SC-PROM-001: Proof tokens required for state mutations
  - SC-PROM-002: API usage SHALL NOT exceed 95% of limits
  - SC-API-005: Scale down when >70% rate limit used
  - SC-API-006: Scale up when <40% rate limit used
  """
  use GenServer
  require Logger

  alias Indrajaal.Observability.FractalLogger

  # Configuration
  @refresh_interval_ms 30_000
  @stale_threshold_ms 60_000
  @target_load_percent 200
  @redline_percent 95
  @scale_down_threshold 0.70
  @scale_up_threshold 0.40
  @min_agents 1
  @max_agents 25
  @context_compact_threshold 0.80

  # State Definition
  defstruct [
    # Current metrics
    :api_metrics,
    :agent_states,
    :plan_progress,
    :task_queue,
    # Scaling state
    :current_agent_count,
    :target_agent_count,
    :scaling_mode,
    # Timestamps
    :last_refresh,
    :last_api_call,
    # Circuit breaker
    :consecutive_429s,
    :cooldown_until,
    # Predictions
    :estimated_completion,
    :throughput_history
  ]

  # ══════════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ══════════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current dashboard state for rendering"
  @spec get_dashboard_state() :: map()
  def get_dashboard_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Report agent thinking state (AOR-PROM-001)"
  @spec report_agent_thinking(String.t(), String.t(), map()) :: :ok
  def report_agent_thinking(agent_id, thinking_content, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:agent_thinking, agent_id, thinking_content, metadata})
  end

  @doc "Report API metrics from response headers"
  @spec report_api_metrics(map()) :: :ok
  def report_api_metrics(headers) do
    GenServer.cast(__MODULE__, {:api_metrics, headers})
  end

  @doc "Update task progress"
  @spec update_task_progress(String.t(), atom(), map()) :: :ok
  def update_task_progress(task_id, status, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:task_update, task_id, status, metadata})
  end

  @doc "Request agent scaling decision"
  @spec request_scaling() :: {:scale_up | :scale_down | :hold, non_neg_integer()}
  def request_scaling do
    GenServer.call(__MODULE__, :request_scaling)
  end

  @doc "Render dashboard to terminal"
  @spec render() :: :ok
  def render do
    GenServer.cast(__MODULE__, :render)
  end

  @doc "Check if context compaction needed (AOR-PROM-003)"
  @spec should_compact?(float()) :: boolean()
  def should_compact?(context_usage) when is_float(context_usage) do
    context_usage >= @context_compact_threshold
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # SERVER CALLBACKS
  # ══════════════════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    Logger.info("🔮 PROMETHEUS Dashboard: Initializing biomorphic monitoring...")

    FractalLogger.spine(:info, "PROMETHEUS Dashboard starting", %{
      target_load: @target_load_percent,
      redline: @redline_percent,
      refresh_interval: @refresh_interval_ms
    })

    state = %__MODULE__{
      api_metrics: initial_api_metrics(),
      agent_states: %{},
      plan_progress: %{total: 0, completed: 0, in_progress: 0},
      task_queue: [],
      current_agent_count: @min_agents,
      target_agent_count: @min_agents,
      scaling_mode: :hold,
      last_refresh: System.monotonic_time(:millisecond),
      last_api_call: nil,
      consecutive_429s: 0,
      cooldown_until: nil,
      estimated_completion: nil,
      throughput_history: []
    }

    # Schedule periodic refresh
    schedule_refresh()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    dashboard_data = build_dashboard_data(state)
    {:reply, dashboard_data, state}
  end

  @impl true
  def handle_call(:request_scaling, _from, state) do
    {decision, new_target, new_state} = calculate_scaling_decision(state)
    {:reply, {decision, new_target}, new_state}
  end

  @impl true
  def handle_call(:get_scaling_signal, _from, state) do
    {decision, new_target, _new_state} = calculate_scaling_decision(state)
    {:reply, {decision, new_target}, state}
  end

  @impl true
  def handle_call({:should_compact?, ratio}, _from, state) do
    result = ratio >= @context_compact_threshold
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:agent_thinking, agent_id, thinking, metadata}, state) do
    updated_agents =
      Map.put(state.agent_states, agent_id, %{
        thinking: thinking,
        metadata: metadata,
        timestamp: System.monotonic_time(:millisecond)
      })

    thinking_str = if is_binary(thinking), do: thinking, else: ""

    FractalLogger.gossamer(:trace, "Agent thinking", %{
      agent_id: agent_id,
      thinking_preview: String.slice(thinking_str, 0, 50)
    })

    {:noreply, %{state | agent_states: updated_agents}}
  end

  # 3-arity convenience handler (no metadata)
  @impl true
  def handle_cast({:agent_thinking, agent_id, thinking}, state) do
    handle_cast({:agent_thinking, agent_id, thinking, %{}}, state)
  end

  @impl true
  def handle_cast({:api_metrics, headers}, state) do
    metrics = parse_api_headers(headers)
    new_state = update_api_metrics(state, metrics)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:task_update, task_id, status, metadata}, state) do
    new_state = update_task_status(state, task_id, status, metadata)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:render, state) do
    render_dashboard(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:rate_limited, headers}, state) do
    new_429_count = state.consecutive_429s + 1

    # SC-API-009: Circuit breaker after 3 consecutive 429s
    new_state =
      if new_429_count >= 3 do
        cooldown_until = System.monotonic_time(:millisecond) + 30_000

        %{
          state
          | consecutive_429s: new_429_count,
            cooldown_until: cooldown_until,
            scaling_mode: :emergency_scale_down,
            target_agent_count: @min_agents
        }
      else
        %{state | consecutive_429s: new_429_count}
      end

    FractalLogger.segment(:warning, "Rate limited", %{
      consecutive_429s: new_429_count,
      retry_after: Map.get(headers, "retry-after")
    })

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:plan_progress, progress}, state) do
    {:noreply, %{state | plan_progress: progress}}
  end

  @impl true
  def handle_info(:refresh, state) do
    now = System.monotonic_time(:millisecond)
    staleness = now - state.last_refresh

    # SC-PROM-003: Check for stale data
    if staleness > @stale_threshold_ms do
      FractalLogger.thorax(:warning, "Dashboard stale", %{staleness_ms: staleness})
    end

    # Update throughput history for predictions
    new_history = update_throughput_history(state)

    # Calculate estimated completion
    estimated = estimate_completion(state.plan_progress, new_history)

    # Render to terminal
    render_dashboard(state)

    # Emit telemetry
    emit_dashboard_telemetry(state)

    new_state = %{
      state
      | last_refresh: now,
        throughput_history: new_history,
        estimated_completion: estimated
    }

    schedule_refresh()
    {:noreply, new_state}
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # METABOLIC SCALING (Section 92.1)
  # ══════════════════════════════════════════════════════════════════════════════

  defp calculate_scaling_decision(state) do
    # Check cooldown (SC-API-009)
    if in_cooldown?(state) do
      {:hold, state.current_agent_count, state}
    else
      rate_limit_usage = get_rate_limit_usage(state.api_metrics)

      cond do
        # SC-API-009: Circuit breaker triggered
        state.consecutive_429s >= 3 ->
          cooldown_until = System.monotonic_time(:millisecond) + 30_000

          {:scale_down, @min_agents,
           %{
             state
             | target_agent_count: @min_agents,
               scaling_mode: :emergency_scale_down,
               cooldown_until: cooldown_until
           }}

        # SC-API-005: Scale down when >70% rate limit used
        rate_limit_usage > @scale_down_threshold ->
          new_target = max(@min_agents, state.current_agent_count - 2)

          {:scale_down, new_target,
           %{state | target_agent_count: new_target, scaling_mode: :scale_down}}

        # SC-API-006: Scale up when <40% rate limit used
        rate_limit_usage < @scale_up_threshold ->
          new_target = min(@max_agents, state.current_agent_count + 1)

          {:scale_up, new_target,
           %{state | target_agent_count: new_target, scaling_mode: :scale_up}}

        # Hold steady
        true ->
          {:hold, state.current_agent_count, %{state | scaling_mode: :hold}}
      end
    end
  end

  defp in_cooldown?(%{cooldown_until: nil}), do: false

  defp in_cooldown?(%{cooldown_until: until}) do
    System.monotonic_time(:millisecond) < until
  end

  defp get_rate_limit_usage(%{rate_limit_remaining: remaining, rate_limit_total: total})
       when is_integer(remaining) and is_integer(total) and total > 0 do
    1.0 - remaining / total
  end

  # Assume 50% if unknown
  defp get_rate_limit_usage(_), do: 0.5

  # ══════════════════════════════════════════════════════════════════════════════
  # DASHBOARD RENDERING (Section 93.0)
  # ══════════════════════════════════════════════════════════════════════════════

  defp render_dashboard(state) do
    # Clear screen
    IO.write("\e[2J\e[H")

    render_header()
    render_api_kpis(state.api_metrics)
    render_agent_swarm(state)
    render_plan_progress(state)
    render_task_queue(state)
    render_agent_thoughts(state.agent_states)
    render_footer(state)
  end

  defp render_header do
    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  🔮 PROMETHEUS BIOMORPHIC DASHBOARD                                          ║
    ║  ═══════════════════════════════════════                                     ║
    ║  Target: #{@target_load_percent}% | Redline: #{@redline_percent}% | OODA: 30s │ #{DateTime.utc_now() |> DateTime.to_string()}  ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    """)
  end

  defp render_api_kpis(metrics) do
    usage = get_rate_limit_usage(metrics)
    usage_bar = render_progress_bar(usage, 40)

    status_color =
      cond do
        # Red
        usage > 0.95 -> "\e[31m"
        # Yellow
        usage > 0.70 -> "\e[33m"
        # Green
        true -> "\e[32m"
      end

    IO.puts("""
    ║  📊 API KPIs                                                                  ║
    ║  ├─ Rate Limit: #{status_color}#{usage_bar}\e[0m #{Float.round(usage * 100, 1)}%
    ║  ├─ Requests/min: #{Map.get(metrics, :rpm, 0)} / #{Map.get(metrics, :rpm_limit, "?")}
    ║  ├─ Tokens/min: #{Map.get(metrics, :tpm, 0)} / #{Map.get(metrics, :tpm_limit, "?")}
    ║  └─ Error Rate: #{Map.get(metrics, :error_rate, 0.0)}%
    ╠══════════════════════════════════════════════════════════════════════════════╣
    """)
  end

  defp render_agent_swarm(state) do
    agent_bar = render_agent_bar(state.current_agent_count, @max_agents)

    scaling_icon =
      case state.scaling_mode do
        :scale_up -> "📈"
        :scale_down -> "📉"
        :emergency_scale_down -> "🚨"
        :hold -> "⚖️"
      end

    IO.puts("""
    ║  🐝 AGENT SWARM                                                               ║
    ║  ├─ Active: #{state.current_agent_count}/#{@max_agents} #{scaling_icon} #{state.scaling_mode}
    ║  │  #{agent_bar}
    ║  ├─ Target: #{state.target_agent_count}
    ║  └─ Cooldown: #{if in_cooldown?(state), do: "ACTIVE", else: "None"}
    ╠══════════════════════════════════════════════════════════════════════════════╣
    """)
  end

  defp render_plan_progress(state) do
    %{total: total, completed: completed, in_progress: in_progress} = state.plan_progress
    progress = if total > 0, do: completed / total, else: 0.0
    progress_bar = render_progress_bar(progress, 40)

    eta =
      case state.estimated_completion do
        nil -> "Calculating..."
        dt -> format_duration(dt)
      end

    IO.puts("""
    ║  📋 PLAN PROGRESS                                                             ║
    ║  ├─ #{progress_bar} #{Float.round(progress * 100, 1)}%
    ║  ├─ Completed: #{completed}/#{total} | In Progress: #{in_progress}
    ║  └─ ETA: #{eta}
    ╠══════════════════════════════════════════════════════════════════════════════╣
    """)
  end

  defp render_task_queue(state) do
    tasks = Enum.take(state.task_queue, 5)

    task_lines =
      if Enum.empty?(tasks) do
        ["║  └─ (No active tasks)"]
      else
        tasks
        |> Enum.with_index(1)
        |> Enum.map(fn {task, idx} ->
          status_icon =
            case task.status do
              :completed -> "✅"
              :in_progress -> "🔄"
              :pending -> "⏳"
              :failed -> "❌"
              _ -> "❓"
            end

          "║  #{if idx == length(tasks), do: "└─", else: "├─"} #{status_icon} #{task.name}"
        end)
      end

    IO.puts("""
    ║  📝 TASK QUEUE (Top 5)                                                        ║
    #{Enum.join(task_lines, "\n")}
    ╠══════════════════════════════════════════════════════════════════════════════╣
    """)
  end

  defp render_agent_thoughts(agent_states) do
    thoughts =
      agent_states
      |> Enum.take(3)
      |> Enum.map(fn {agent_id, data} ->
        preview = String.slice(data.thinking || "", 0, 60)
        "║  ├─ 💭 #{agent_id}: #{preview}..."
      end)

    thought_lines =
      if Enum.empty?(thoughts) do
        ["║  └─ (Agents idle)"]
      else
        thoughts ++ ["║  └─ ..."]
      end

    IO.puts("""
    ║  🧠 AGENT THOUGHTS (Last 3)                                                   ║
    #{Enum.join(thought_lines, "\n")}
    ╠══════════════════════════════════════════════════════════════════════════════╣
    """)
  end

  defp render_footer(state) do
    staleness = System.monotonic_time(:millisecond) - state.last_refresh
    stale_warning = if staleness > @stale_threshold_ms, do: " ⚠️ STALE", else: ""

    IO.puts("""
    ║  Last Refresh: #{staleness}ms ago#{stale_warning}                                              ║
    ║  Next Refresh: #{@refresh_interval_ms - staleness}ms                                           ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    """)
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # HELPER FUNCTIONS
  # ══════════════════════════════════════════════════════════════════════════════

  defp initial_api_metrics do
    %{
      rate_limit_remaining: 1000,
      rate_limit_total: 1000,
      rpm: 0,
      rpm_limit: 60,
      tpm: 0,
      tpm_limit: 100_000,
      error_rate: 0.0
    }
  end

  defp parse_api_headers(headers) when is_map(headers) do
    # Support both atom keys (test) and string keys (real headers)
    %{
      rate_limit_remaining:
        get_header_int(headers, ["x-ratelimit-remaining-requests", :rate_limit_remaining], 1000),
      rate_limit_total:
        get_header_int(headers, ["x-ratelimit-limit-requests", :rate_limit_total], 1000),
      rpm: get_header_int(headers, ["x-ratelimit-remaining-requests", :rpm], 0),
      tpm: get_header_int(headers, ["x-ratelimit-remaining-tokens", :tpm], 0)
    }
  end

  defp parse_api_headers(_), do: %{}

  defp get_header_int(headers, keys, default) when is_list(keys) do
    Enum.find_value(keys, default, fn key ->
      case Map.get(headers, key) do
        nil -> nil
        val when is_binary(val) -> String.to_integer(val)
        val when is_integer(val) -> val
        _ -> nil
      end
    end)
  end

  defp get_header_int(headers, key, default) do
    case Map.get(headers, key) do
      nil -> default
      val when is_binary(val) -> String.to_integer(val)
      val when is_integer(val) -> val
      _ -> default
    end
  end

  defp update_api_metrics(state, new_metrics) do
    # Check for 429 (via low remaining)
    new_429_count =
      if Map.get(new_metrics, :rate_limit_remaining, 1000) < 5 do
        state.consecutive_429s + 1
      else
        0
      end

    merged = Map.merge(state.api_metrics, new_metrics)

    %{
      state
      | api_metrics: merged,
        consecutive_429s: new_429_count,
        last_api_call: System.monotonic_time(:millisecond)
    }
  end

  defp update_task_status(state, task_id, status, metadata) do
    task = %{
      id: task_id,
      status: status,
      name: Map.get(metadata, :name, task_id),
      updated_at: DateTime.utc_now()
    }

    updated_queue =
      [task | Enum.reject(state.task_queue, &(&1.id == task_id))]
      # Keep max 100 tasks
      |> Enum.take(100)

    # Update plan progress
    completed = Enum.count(updated_queue, &(&1.status == :completed))
    in_progress = Enum.count(updated_queue, &(&1.status == :in_progress))
    total = length(updated_queue)

    %{
      state
      | task_queue: updated_queue,
        plan_progress: %{total: total, completed: completed, in_progress: in_progress}
    }
  end

  defp update_throughput_history(state) do
    current = state.plan_progress.completed
    entry = {System.monotonic_time(:millisecond), current}
    [entry | Enum.take(state.throughput_history, 10)]
  end

  defp estimate_completion(progress, history) when length(history) >= 2 do
    remaining = progress.total - progress.completed

    if remaining <= 0 do
      0
    else
      [{t2, c2}, {t1, c1} | _] = history
      time_delta = t2 - t1
      completed_delta = c2 - c1

      if completed_delta > 0 and time_delta > 0 do
        # tasks per ms
        rate = completed_delta / time_delta
        (remaining / rate) |> round()
      else
        nil
      end
    end
  end

  defp estimate_completion(_, _), do: nil

  defp format_duration(nil), do: "Unknown"

  defp format_duration(ms) when is_number(ms) do
    cond do
      ms < 60_000 -> "#{round(ms / 1000)}s"
      ms < 3_600_000 -> "#{round(ms / 60_000)}m"
      true -> "#{Float.round(ms / 3_600_000, 1)}h"
    end
  end

  defp render_progress_bar(ratio, width) when is_float(ratio) do
    filled = round(ratio * width)
    empty = width - filled
    "[" <> String.duplicate("█", filled) <> String.duplicate("░", empty) <> "]"
  end

  defp render_agent_bar(current, max) do
    Enum.map_join(1..max, "", fn i ->
      if i <= current, do: "🟢", else: "⚪"
    end)
  end

  defp build_dashboard_data(state) do
    %{
      api_metrics: state.api_metrics,
      agent_states: state.agent_states,
      agent_count: state.current_agent_count,
      current_agent_count: state.current_agent_count,
      target_agent_count: state.target_agent_count,
      target_agents: state.target_agent_count,
      scaling_mode: state.scaling_mode,
      plan_progress: state.plan_progress,
      estimated_completion: state.estimated_completion,
      consecutive_429s: state.consecutive_429s,
      cooldown_until: state.cooldown_until,
      cooldown_active: in_cooldown?(state),
      throughput_history: state.throughput_history,
      staleness_ms: System.monotonic_time(:millisecond) - state.last_refresh
    }
  end

  defp emit_dashboard_telemetry(state) do
    :telemetry.execute(
      [:indrajaal, :prometheus, :dashboard, :refresh],
      %{
        agent_count: state.current_agent_count,
        staleness: System.monotonic_time(:millisecond) - state.last_refresh
      },
      %{
        scaling_mode: state.scaling_mode,
        rate_limit_usage: get_rate_limit_usage(state.api_metrics)
      }
    )
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval_ms)
  end
end
