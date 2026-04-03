defmodule Indrajaal.AI.CostMonitor do
  @moduledoc """
  Real-time cost monitoring and budget enforcement for AI operations.

  ## Features

  - Daily and monthly budget tracking
  - Per-request cost limits
  - Rate limiting (requests/minute, tokens/minute)
  - Budget alerts at configurable thresholds
  - Usage analytics by model and source

  ## STAMP Constraints

  - SC-AI-004: Budget limits enforced before API calls
  - SC-AI-005: Rate limits prevent API exhaustion
  - SC-AI-008: Cost alerts at threshold
  - SC-AI-010: All costs recorded to Zenoh
  - SC-AI-011: Monthly budget rollover

  ## Usage

      # Check before making a request
      :ok = CostMonitor.check_budget_and_rate("anthropic/claude-3.5-sonnet", 0.05)

      # Record usage after request
      CostMonitor.record_usage("anthropic/claude-3.5-sonnet", :cortex, 0.03, 5000)

      # Get usage stats
      CostMonitor.get_daily_usage()
      # => 2.45
  """

  use GenServer

  alias Indrajaal.AI.Simplex.TelemetryFlow

  require Logger

  # Configuration with defaults
  @default_daily_budget 50.0
  @default_monthly_budget 1000.0
  @default_per_request_limit 5.0
  @default_rate_limit_per_minute 100
  @default_tokens_per_minute 500_000

  defstruct [
    # Budget configuration
    daily_budget: @default_daily_budget,
    monthly_budget: @default_monthly_budget,
    per_request_limit: @default_per_request_limit,

    # Current usage
    daily_usage: 0.0,
    monthly_usage: 0.0,
    usage_by_model: %{},
    usage_by_source: %{},

    # Rate limiting
    rate_limit_per_minute: @default_rate_limit_per_minute,
    tokens_per_minute: @default_tokens_per_minute,
    requests_this_minute: 0,
    tokens_this_minute: 0,
    minute_started_at: nil,

    # Alert state
    daily_75_alert_sent: false,
    daily_90_alert_sent: false,
    monthly_75_alert_sent: false,
    monthly_90_alert_sent: false,

    # Reset tracking
    day_started_at: nil,
    month_started_at: nil
  ]

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc """
  Start the CostMonitor GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a request is within budget and rate limits.

  Returns `:ok` if the request can proceed, or `{:error, reason}`.
  """
  @spec check_budget_and_rate(String.t(), float()) :: :ok | {:error, atom()}
  def check_budget_and_rate(model, estimated_cost) do
    case GenServer.whereis(__MODULE__) do
      # Allow if monitor not running
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, {:check, model, estimated_cost})
    end
  end

  @doc """
  Record usage after a successful API call.
  """
  @spec record_usage(String.t(), atom(), float(), non_neg_integer()) :: :ok
  def record_usage(model, source, cost, tokens \\ 0) do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:record, model, source, cost, tokens})
    end
  end

  @doc """
  Get the current daily usage total.
  """
  @spec get_daily_usage() :: float()
  def get_daily_usage do
    case GenServer.whereis(__MODULE__) do
      nil -> 0.0
      _pid -> GenServer.call(__MODULE__, :get_daily)
    end
  end

  @doc """
  Get the current monthly usage total.
  """
  @spec get_monthly_usage() :: float()
  def get_monthly_usage do
    case GenServer.whereis(__MODULE__) do
      nil -> 0.0
      _pid -> GenServer.call(__MODULE__, :get_monthly)
    end
  end

  @doc """
  Get complete usage statistics.
  """
  @spec get_usage_stats() :: map()
  def get_usage_stats do
    case GenServer.whereis(__MODULE__) do
      nil -> %{daily_usage: 0.0, monthly_usage: 0.0}
      _pid -> GenServer.call(__MODULE__, :get_stats)
    end
  end

  @doc """
  Estimate the cost for a model and token count.
  """
  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def estimate_cost(model, input_tokens, output_tokens) do
    Indrajaal.AI.Pricing.estimate_cost(model, input_tokens, output_tokens)
  end

  @doc """
  Get complete statistics (alias for get_usage_stats).
  """
  @spec get_stats() :: map()
  def get_stats do
    case GenServer.whereis(__MODULE__) do
      nil ->
        %{
          daily_usage: 0.0,
          monthly_usage: 0.0,
          daily_budget: @default_daily_budget,
          monthly_budget: @default_monthly_budget,
          usage_by_model: %{},
          usage_by_source: %{},
          rate_limit_per_minute: @default_rate_limit_per_minute
        }

      _pid ->
        GenServer.call(__MODULE__, :get_full_stats)
    end
  end

  @doc """
  Configure budget and rate limits.
  """
  @spec configure(keyword()) :: :ok
  def configure(opts) do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, {:configure, opts})
    end
  end

  @doc """
  Check if rate limit allows another request.
  """
  @spec check_rate_limit() :: :ok | {:error, :rate_limit_exceeded}
  def check_rate_limit do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, :check_rate_limit)
    end
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    config = Application.get_env(:indrajaal, :ai, [])

    state = %__MODULE__{
      daily_budget:
        Keyword.get(opts, :daily_budget, config[:daily_budget] || @default_daily_budget),
      monthly_budget:
        Keyword.get(opts, :monthly_budget, config[:monthly_budget] || @default_monthly_budget),
      per_request_limit:
        Keyword.get(
          opts,
          :per_request_limit,
          config[:per_request_limit] || @default_per_request_limit
        ),
      rate_limit_per_minute:
        Keyword.get(opts, :rate_limit_per_minute, @default_rate_limit_per_minute),
      tokens_per_minute: Keyword.get(opts, :tokens_per_minute, @default_tokens_per_minute),
      day_started_at: Date.utc_today(),
      month_started_at: {Date.utc_today().year, Date.utc_today().month},
      minute_started_at: DateTime.utc_now()
    }

    # Schedule periodic reset checks
    Process.send_after(self(), :check_resets, :timer.minutes(1))

    {:ok, state}
  end

  @impl true
  def handle_call({:check, _model, estimated_cost}, _from, state) do
    state = maybe_reset_minute(state)
    state = maybe_reset_day(state)
    state = maybe_reset_month(state)

    result =
      cond do
        estimated_cost > state.per_request_limit ->
          {:error, :per_request_limit_exceeded}

        state.daily_usage + estimated_cost > state.daily_budget ->
          {:error, :daily_budget_exceeded}

        state.monthly_usage + estimated_cost > state.monthly_budget ->
          {:error, :monthly_budget_exceeded}

        state.requests_this_minute >= state.rate_limit_per_minute ->
          {:error, :rate_limited}

        true ->
          :ok
      end

    new_state =
      if result == :ok do
        %{state | requests_this_minute: state.requests_this_minute + 1}
      else
        state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:get_daily, _from, state) do
    {:reply, state.daily_usage, state}
  end

  @impl true
  def handle_call(:get_monthly, _from, state) do
    {:reply, state.monthly_usage, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      daily_usage: state.daily_usage,
      monthly_usage: state.monthly_usage,
      daily_budget: state.daily_budget,
      monthly_budget: state.monthly_budget,
      daily_remaining: state.daily_budget - state.daily_usage,
      monthly_remaining: state.monthly_budget - state.monthly_usage,
      usage_by_model: state.usage_by_model,
      usage_by_source: state.usage_by_source,
      requests_this_minute: state.requests_this_minute
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_full_stats, _from, state) do
    stats = %{
      daily_usage: state.daily_usage,
      monthly_usage: state.monthly_usage,
      daily_budget: state.daily_budget,
      monthly_budget: state.monthly_budget,
      usage_by_model: state.usage_by_model,
      usage_by_source: state.usage_by_source,
      rate_limit_per_minute: state.rate_limit_per_minute
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:configure, opts}, _from, state) do
    new_state =
      Enum.reduce(opts, state, fn
        {:daily_budget, value}, acc -> %{acc | daily_budget: value}
        {:monthly_budget, value}, acc -> %{acc | monthly_budget: value}
        {:per_request_limit, value}, acc -> %{acc | per_request_limit: value}
        {:rate_limit_per_minute, value}, acc -> %{acc | rate_limit_per_minute: value}
        {:tokens_per_minute, value}, acc -> %{acc | tokens_per_minute: value}
        _, acc -> acc
      end)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:check_rate_limit, _from, state) do
    state = maybe_reset_minute(state)

    if state.requests_this_minute >= state.rate_limit_per_minute do
      {:reply, {:error, :rate_limit_exceeded}, state}
    else
      new_state = %{state | requests_this_minute: state.requests_this_minute + 1}
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_cast({:record, model, source, cost, tokens}, state) do
    # Track model usage with cost, tokens, and request count
    model_usage =
      Map.get(state.usage_by_model, model, %{total_cost: 0.0, total_tokens: 0, request_count: 0})

    updated_model_usage = %{
      total_cost: model_usage.total_cost + cost,
      total_tokens: model_usage.total_tokens + tokens,
      request_count: model_usage.request_count + 1
    }

    new_state = %{
      state
      | daily_usage: state.daily_usage + cost,
        monthly_usage: state.monthly_usage + cost,
        tokens_this_minute: state.tokens_this_minute + tokens,
        usage_by_model: Map.put(state.usage_by_model, model, updated_model_usage),
        usage_by_source: Map.update(state.usage_by_source, source, cost, &(&1 + cost))
    }

    # Emit telemetry
    TelemetryFlow.emit_cost_event(model, source, cost, %{
      daily_usage: new_state.daily_usage,
      monthly_usage: new_state.monthly_usage,
      tokens: tokens
    })

    # Check budget alerts
    new_state = check_budget_alerts(new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_resets, state) do
    state = maybe_reset_minute(state)
    state = maybe_reset_day(state)
    state = maybe_reset_month(state)

    Process.send_after(self(), :check_resets, :timer.minutes(1))
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp maybe_reset_minute(state) do
    now = DateTime.utc_now()
    started = state.minute_started_at || now

    if DateTime.diff(now, started, :second) >= 60 do
      %{state | requests_this_minute: 0, tokens_this_minute: 0, minute_started_at: now}
    else
      state
    end
  end

  defp maybe_reset_day(state) do
    today = Date.utc_today()

    if state.day_started_at != today do
      Logger.info(
        "[CostMonitor] Daily reset - previous usage: $#{Float.round(state.daily_usage, 4)}"
      )

      %{
        state
        | daily_usage: 0.0,
          day_started_at: today,
          daily_75_alert_sent: false,
          daily_90_alert_sent: false
      }
    else
      state
    end
  end

  defp maybe_reset_month(state) do
    today = Date.utc_today()
    current_month = {today.year, today.month}

    if state.month_started_at != current_month do
      Logger.info(
        "[CostMonitor] Monthly reset - previous usage: $#{Float.round(state.monthly_usage, 4)}"
      )

      %{
        state
        | monthly_usage: 0.0,
          month_started_at: current_month,
          monthly_75_alert_sent: false,
          monthly_90_alert_sent: false
      }
    else
      state
    end
  end

  defp check_budget_alerts(state) do
    daily_percent = state.daily_usage / state.daily_budget * 100
    monthly_percent = state.monthly_usage / state.monthly_budget * 100

    state
    |> check_daily_alerts(daily_percent)
    |> check_monthly_alerts(monthly_percent)
  end

  defp check_daily_alerts(state, percent) when percent >= 90 and not state.daily_90_alert_sent do
    TelemetryFlow.emit_budget_alert(:daily_90_percent, state.daily_usage, state.daily_budget)

    Logger.warning(
      "[CostMonitor] Daily budget at 90%: $#{Float.round(state.daily_usage, 2)}/$#{state.daily_budget}"
    )

    %{state | daily_90_alert_sent: true}
  end

  defp check_daily_alerts(state, percent) when percent >= 75 and not state.daily_75_alert_sent do
    TelemetryFlow.emit_budget_alert(:daily_75_percent, state.daily_usage, state.daily_budget)

    Logger.info(
      "[CostMonitor] Daily budget at 75%: $#{Float.round(state.daily_usage, 2)}/$#{state.daily_budget}"
    )

    %{state | daily_75_alert_sent: true}
  end

  defp check_daily_alerts(state, _), do: state

  defp check_monthly_alerts(state, percent)
       when percent >= 90 and not state.monthly_90_alert_sent do
    TelemetryFlow.emit_budget_alert(
      :monthly_90_percent,
      state.monthly_usage,
      state.monthly_budget
    )

    Logger.warning(
      "[CostMonitor] Monthly budget at 90%: $#{Float.round(state.monthly_usage, 2)}/$#{state.monthly_budget}"
    )

    %{state | monthly_90_alert_sent: true}
  end

  defp check_monthly_alerts(state, percent)
       when percent >= 75 and not state.monthly_75_alert_sent do
    TelemetryFlow.emit_budget_alert(
      :monthly_75_percent,
      state.monthly_usage,
      state.monthly_budget
    )

    Logger.info(
      "[CostMonitor] Monthly budget at 75%: $#{Float.round(state.monthly_usage, 2)}/$#{state.monthly_budget}"
    )

    %{state | monthly_75_alert_sent: true}
  end

  defp check_monthly_alerts(state, _), do: state
end
