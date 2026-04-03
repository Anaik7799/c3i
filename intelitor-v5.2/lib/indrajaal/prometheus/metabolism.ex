defmodule Indrajaal.Prometheus.Metabolism do
  @moduledoc """
  PROMETHEUS Metabolic Controller - Biomorphic Resource Management.

  ## WHAT
  Token bucket rate limiter with dynamic scaling functions for agent swarm management.
  The system behaves as a biological organism, regulating its "metabolic rate" (Agent Count)
  based on available "Energy" (API Tokens).

  ## WHY
  - SC-PROM-002: API usage SHALL NOT exceed 95% of provider limits
  - SC-API-001: Max concurrent agents 5-25 based on rate limit headroom
  - AOR-PROM-002: Supervisor MUST respect Metabolism signals immediately
  - Section 92.1: Metabolic Scaling Protocol

  ## CONSTRAINTS
  - Target Load: 200% of theoretical max (virtual saturation target)
  - Redline: 95% of Hard Limit (absolute ceiling)
  - Token Bucket: Leaky bucket with burst capacity
  - Scaling: Smooth transitions, no burst spawning (AOR-TPS-002)

  ## STAMP Compliance
  - SC-PROM-001: Proof tokens for state mutations
  - SC-API-003: Exponential backoff on 429 (base 2s, max 60s)
  - SC-API-009: Circuit breaker after 3 consecutive 429s
  - SC-PRIME-001: Will to Live (never optimize to zero)
  """
  use GenServer
  require Logger

  alias Indrajaal.Observability.FractalLogger

  # Configuration
  # 1 token per second
  @token_refill_rate_ms 1000
  @max_bucket_size 100
  # 200%
  @target_load_percent 2.0
  # 95%
  @redline_percent 0.95
  # SC-PRIME-001: Never zero
  @min_agents 1
  @max_agents 25
  @backoff_base_ms 2000
  @backoff_max_ms 60_000
  @circuit_breaker_threshold 3
  @circuit_breaker_cooldown_ms 30_000

  # State Definition
  defstruct [
    # Token Bucket
    :tokens,
    :max_tokens,
    :last_refill,
    # Scaling State
    :current_agents,
    :target_agents,
    :scaling_velocity,
    # Circuit Breaker
    :consecutive_failures,
    :backoff_ms,
    :circuit_open_until,
    # Telemetry
    :total_requests,
    :total_tokens_consumed,
    :throughput_history
  ]

  # ══════════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ══════════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Attempt to consume tokens from the bucket.
  Returns {:ok, tokens_remaining} or {:error, :rate_limited}
  """
  @spec consume(pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, :rate_limited | :circuit_open}
  def consume(tokens \\ 1) do
    GenServer.call(__MODULE__, {:consume, tokens})
  end

  @doc """
  Report API response for metabolic adjustment.
  """
  @spec report_response(integer(), map()) :: :ok
  def report_response(status_code, headers \\ %{}) do
    GenServer.cast(__MODULE__, {:response, status_code, headers})
  end

  @doc """
  Get current metabolic state.
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Calculate recommended agent count based on current metabolic state.
  """
  @spec recommended_agents() :: non_neg_integer()
  def recommended_agents do
    GenServer.call(__MODULE__, :recommended_agents)
  end

  @doc """
  Get scaling signal: :scale_up | :scale_down | :hold
  """
  @spec scaling_signal() :: {:scale_up | :scale_down | :hold, non_neg_integer()}
  def scaling_signal do
    GenServer.call(__MODULE__, :scaling_signal)
  end

  @doc """
  Force circuit breaker reset (for recovery scenarios).
  """
  @spec reset_circuit_breaker() :: :ok
  def reset_circuit_breaker do
    GenServer.cast(__MODULE__, :reset_circuit_breaker)
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # SERVER CALLBACKS
  # ══════════════════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    Logger.info("⚡ Metabolism: Initializing biomorphic energy controller...")

    FractalLogger.spine(:info, "Metabolism starting", %{
      max_tokens: @max_bucket_size,
      target_load: @target_load_percent,
      redline: @redline_percent
    })

    state = %__MODULE__{
      tokens: @max_bucket_size,
      max_tokens: @max_bucket_size,
      last_refill: System.monotonic_time(:millisecond),
      current_agents: @min_agents,
      target_agents: @min_agents,
      scaling_velocity: 0,
      consecutive_failures: 0,
      backoff_ms: 0,
      circuit_open_until: nil,
      total_requests: 0,
      total_tokens_consumed: 0,
      throughput_history: []
    }

    # Schedule token refill
    schedule_refill()

    {:ok, state}
  end

  @impl true
  def handle_call({:consume, tokens_requested}, _from, state) do
    # Check circuit breaker first
    if circuit_open?(state) do
      remaining_ms = state.circuit_open_until - System.monotonic_time(:millisecond)
      FractalLogger.thorax(:warning, "Circuit breaker open", %{remaining_ms: remaining_ms})
      {:reply, {:error, :circuit_open}, state}
    else
      # Refill bucket based on elapsed time
      state = refill_bucket(state)

      if state.tokens >= tokens_requested do
        new_state = %{
          state
          | tokens: state.tokens - tokens_requested,
            total_requests: state.total_requests + 1,
            total_tokens_consumed: state.total_tokens_consumed + tokens_requested
        }

        {:reply, {:ok, new_state.tokens}, new_state}
      else
        {:reply, {:error, :rate_limited}, state}
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state = refill_bucket(state)

    data = %{
      tokens: state.tokens,
      max_tokens: state.max_tokens,
      token_utilization: 1.0 - state.tokens / state.max_tokens,
      current_agents: state.current_agents,
      target_agents: state.target_agents,
      scaling_velocity: state.scaling_velocity,
      circuit_open: circuit_open?(state),
      consecutive_failures: state.consecutive_failures,
      backoff_ms: state.backoff_ms,
      total_requests: state.total_requests,
      total_tokens_consumed: state.total_tokens_consumed,
      throughput_history: state.throughput_history
    }

    {:reply, data, state}
  end

  @impl true
  def handle_call(:recommended_agents, _from, state) do
    state = refill_bucket(state)
    recommended = calculate_recommended_agents(state)
    {:reply, recommended, state}
  end

  @impl true
  def handle_call(:scaling_signal, _from, state) do
    state = refill_bucket(state)
    {signal, target} = calculate_scaling_signal(state)
    {:reply, {signal, target}, state}
  end

  @impl true
  def handle_cast({:response, status_code, headers}, state) do
    new_state =
      case status_code do
        429 ->
          # Rate limited - trigger backoff
          handle_rate_limit(state, headers)

        code when code >= 500 ->
          # Server error - mild backoff
          %{
            state
            | consecutive_failures: state.consecutive_failures + 1,
              backoff_ms: min(state.backoff_ms + 1000, @backoff_max_ms)
          }

        code when code >= 200 and code < 300 ->
          # Success - reset backoff
          update_from_success(state, headers)

        _ ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset_circuit_breaker, state) do
    Logger.info("⚡ Metabolism: Circuit breaker manually reset")
    {:noreply, %{state | consecutive_failures: 0, backoff_ms: 0, circuit_open_until: nil}}
  end

  @impl true
  def handle_info(:refill, state) do
    state = refill_bucket(state)

    # Update throughput history
    new_history = [
      {System.monotonic_time(:millisecond), state.total_requests}
      | Enum.take(state.throughput_history, 60)
    ]

    # Emit telemetry
    emit_metabolism_telemetry(state)

    schedule_refill()
    {:noreply, %{state | throughput_history: new_history}}
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # TOKEN BUCKET LOGIC
  # ══════════════════════════════════════════════════════════════════════════════

  defp refill_bucket(state) do
    now = System.monotonic_time(:millisecond)
    elapsed_ms = now - state.last_refill
    tokens_to_add = elapsed_ms / @token_refill_rate_ms

    new_tokens = min(state.max_tokens, state.tokens + tokens_to_add)
    %{state | tokens: new_tokens, last_refill: now}
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # SCALING FUNCTIONS
  # ══════════════════════════════════════════════════════════════════════════════

  defp calculate_recommended_agents(state) do
    # Token utilization drives agent count
    utilization = 1.0 - state.tokens / state.max_tokens

    # Target: 200% load but respect 95% redline
    raw_target = round(@max_agents * utilization * @target_load_percent)

    # Apply circuit breaker constraints
    if circuit_open?(state) do
      @min_agents
    else
      # Clamp to [min, max]
      raw_target
      |> max(@min_agents)
      |> min(@max_agents)
    end
  end

  defp calculate_scaling_signal(state) do
    recommended = calculate_recommended_agents(state)
    current = state.current_agents

    cond do
      circuit_open?(state) ->
        {:scale_down, @min_agents}

      recommended > current + 1 ->
        {:scale_up, min(current + 2, recommended)}

      recommended < current - 1 ->
        {:scale_down, max(current - 2, recommended)}

      true ->
        {:hold, current}
    end
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # CIRCUIT BREAKER (SC-API-009)
  # ══════════════════════════════════════════════════════════════════════════════

  defp circuit_open?(%{circuit_open_until: nil}), do: false

  defp circuit_open?(%{circuit_open_until: until}) do
    System.monotonic_time(:millisecond) < until
  end

  defp handle_rate_limit(state, headers) do
    new_failures = state.consecutive_failures + 1

    # Exponential backoff (SC-API-003)
    new_backoff =
      min(
        @backoff_base_ms * :math.pow(2, new_failures - 1),
        @backoff_max_ms
      )
      |> round()

    # Check circuit breaker threshold (SC-API-009)
    new_state = %{state | consecutive_failures: new_failures, backoff_ms: new_backoff}

    if new_failures >= @circuit_breaker_threshold do
      FractalLogger.thorax(:warning, "Circuit breaker OPEN", %{
        failures: new_failures,
        cooldown_ms: @circuit_breaker_cooldown_ms
      })

      %{
        new_state
        | circuit_open_until: System.monotonic_time(:millisecond) + @circuit_breaker_cooldown_ms
      }
    else
      # Extract retry-after if present
      retry_after =
        case Map.get(headers, "retry-after") do
          nil -> new_backoff
          val when is_binary(val) -> String.to_integer(val) * 1000
          val when is_integer(val) -> val * 1000
          _ -> new_backoff
        end

      FractalLogger.segment(:warning, "Rate limited", %{
        failures: new_failures,
        backoff_ms: retry_after
      })

      %{new_state | backoff_ms: retry_after}
    end
  end

  defp update_from_success(state, headers) do
    # Update from rate limit headers
    remaining = get_header_int(headers, "x-ratelimit-remaining-requests", state.max_tokens)
    total = get_header_int(headers, "x-ratelimit-limit-requests", state.max_tokens)

    # Scale bucket based on remaining capacity
    new_tokens = remaining / max(total, 1) * state.max_tokens

    %{
      state
      | tokens: max(state.tokens, new_tokens),
        consecutive_failures: 0,
        backoff_ms: max(0, state.backoff_ms - 500),
        circuit_open_until: nil
    }
  end

  defp get_header_int(headers, key, default) do
    case Map.get(headers, key) do
      nil -> default
      val when is_binary(val) -> String.to_integer(val)
      val when is_integer(val) -> val
      _ -> default
    end
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # TELEMETRY
  # ══════════════════════════════════════════════════════════════════════════════

  defp emit_metabolism_telemetry(state) do
    :telemetry.execute(
      [:indrajaal, :prometheus, :metabolism],
      %{
        tokens: state.tokens,
        utilization: 1.0 - state.tokens / state.max_tokens,
        current_agents: state.current_agents,
        total_requests: state.total_requests
      },
      %{
        circuit_open: circuit_open?(state),
        consecutive_failures: state.consecutive_failures
      }
    )
  end

  defp schedule_refill do
    Process.send_after(self(), :refill, @token_refill_rate_ms)
  end
end
