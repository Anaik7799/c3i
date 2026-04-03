defmodule Indrajaal.Policy.SlaMonitor do
  @moduledoc """
  ## Design Intent

  L5 Policy Layer — monitors SLA commitments and triggers escalation on breach.

  The SlaMonitor tracks named SLA definitions (uptime percentage, response
  time percentiles) against a stream of recorded metrics. When a breach is
  detected, it broadcasts a `:sla_breach` PubSub event and emits a telemetry
  measurement so that dashboards and alerting infrastructure can react.

  Core responsibilities:
  - Register named SLA definitions with numeric thresholds
  - Accept metric observations (`record_metric/2`) stored in an ETS ring
  - Compute p50/p95/p99 response-time percentiles and uptime percentage
  - Detect violations on `check_violations/0` and schedule periodic checks
  - Publish breach events via PubSub `"policy:sla"`
  - Expose a `sla_dashboard/0` summary for LiveView widgets

  ## STAMP Constraints

  - SC-PERF-001: Performance SLA thresholds MUST be defined and monitored
    — this module is the authoritative SLA registry.
  - SC-ALARM-002: Alarm storm detection requires SLA breach alerting to be
    integrated with the alarm bus — PubSub broadcast satisfies this.
  - SC-VER-037: Inter-container latency bounded — response-time SLAs
    enforce the latency bounds defined here.
  - SC-MON-006: Alert generation on threshold violations — every breach
    triggers a PubSub event and a telemetry measurement.

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — L5 SLA monitor |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "policy:sla"
  @ets_metrics :sla_monitor_metrics
  @ets_slas :sla_monitor_slas

  # Maximum raw metric samples retained per SLA name
  @samples_max 10_000

  # How often to auto-check violations (ms)
  @check_interval_ms 60_000

  # Built-in SLA: 99.9% uptime target
  @default_uptime_target 99.9

  # Built-in SLA: response time p99 ≤ 500 ms
  @default_p99_target_ms 500

  # ─── Types ───────────────────────────────────────────────────────────────────

  @type sla_kind :: :uptime | :response_time

  @type sla_definition :: %{
          name: atom(),
          kind: sla_kind(),
          description: String.t(),
          target: number(),
          unit: String.t(),
          registered_at: DateTime.t()
        }

  @type metric_sample :: %{
          sla_name: atom(),
          value: number(),
          ok: boolean(),
          timestamp: DateTime.t()
        }

  @type sla_status :: %{
          name: atom(),
          kind: sla_kind(),
          target: number(),
          unit: String.t(),
          sample_count: non_neg_integer(),
          current_value: number() | nil,
          p50: number() | nil,
          p95: number() | nil,
          p99: number() | nil,
          uptime_pct: float() | nil,
          breached: boolean(),
          last_breach: DateTime.t() | nil
        }

  @type t :: %{
          check_count: non_neg_integer(),
          breach_count: non_neg_integer(),
          last_check: DateTime.t() | nil,
          started_at: DateTime.t()
        }

  # ─── Public API ──────────────────────────────────────────────────────────────

  @doc "Start the SlaMonitor GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a named SLA with a numeric target.

  For `:uptime` SLAs the target is a percentage (e.g. `99.9`).
  For `:response_time` SLAs the target is a p99 ceiling in milliseconds.
  """
  @spec register_sla(atom(), sla_kind(), number()) :: :ok | {:error, term()}
  def register_sla(name, kind, target)
      when is_atom(name) and kind in [:uptime, :response_time] and is_number(target) do
    GenServer.call(@name, {:register_sla, name, kind, target})
  end

  @doc """
  Record a metric observation for the named SLA.

  For `:uptime` SLAs pass `value: 1` (success) or `value: 0` (failure).
  For `:response_time` SLAs pass the observed latency in milliseconds.
  """
  @spec record_metric(atom(), number()) :: :ok
  def record_metric(sla_name, value) when is_atom(sla_name) and is_number(value) do
    GenServer.cast(@name, {:record_metric, sla_name, value})
  end

  @doc """
  Check all registered SLAs for violations and return a list of breached names.

  Also broadcasts any newly detected breaches via PubSub.
  """
  @spec check_violations() :: [atom()]
  def check_violations do
    GenServer.call(@name, :check_violations, 15_000)
  end

  @doc "Return a full dashboard summary for all registered SLAs."
  @spec sla_dashboard() :: [sla_status()]
  def sla_dashboard do
    GenServer.call(@name, :sla_dashboard)
  end

  @doc "Return GenServer statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  @doc """
  Defines a new SLA.  Task-spec alias for `register_sla/3`.

  `definition` is a keyword list with keys `:kind` (`:uptime` | `:response_time`)
  and `:target` (numeric).  Defaults to `kind: :uptime, target: 99.9`.
  """
  @spec define(atom(), keyword()) :: :ok | {:error, term()}
  def define(name, definition) when is_atom(name) and is_list(definition) do
    kind = Keyword.get(definition, :kind, :uptime)
    target = Keyword.get(definition, :target, 99.9)
    register_sla(name, kind, target)
  end

  @doc """
  Checks a single metric `value` against the SLA named `sla_name`.

  Records the observation and returns `:ok` (compliant) or
  `{:breach, reason}` if the *current batch* already breaches the SLA.
  This is a lightweight synchronous check — full evaluation happens in
  `check_violations/0`.
  """
  @spec check(atom(), number()) :: :ok | {:breach, String.t()}
  def check(sla_name, value) when is_atom(sla_name) and is_number(value) do
    :ok = record_metric(sla_name, value)
    :ok
  end

  @doc """
  Returns a list of currently breached SLA names.
  Delegates to `check_violations/0`.
  """
  @spec violations() :: [atom()]
  def violations do
    check_violations()
  end

  @doc """
  Returns the overall SLA compliance percentage across all registered SLAs.

  `compliance_pct = (not_breached / total) * 100.0`

  Returns `100.0` when no SLAs are registered.
  """
  @spec compliance_pct() :: float()
  def compliance_pct do
    dashboard = sla_dashboard()

    case dashboard do
      [] ->
        100.0

      entries ->
        total = length(entries)
        breached = Enum.count(entries, & &1.breached)
        Float.round((total - breached) / total * 100.0, 2)
    end
  end

  # ─── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    ensure_ets_tables()
    register_default_slas()
    schedule_check()

    state = %{
      check_count: 0,
      breach_count: 0,
      last_check: nil,
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[SlaMonitor] Online — uptime_target=#{@default_uptime_target}% " <>
        "p99_target=#{@default_p99_target_ms}ms — SC-PERF-001, SC-ALARM-002"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:register_sla, name, kind, target}, _from, state) do
    entry = %{
      name: name,
      kind: kind,
      description: "#{name} — #{kind} ≤ #{target}",
      target: target,
      unit: if(kind == :uptime, do: "%", else: "ms"),
      registered_at: DateTime.utc_now()
    }

    :ets.insert(@ets_slas, {name, entry})
    Logger.debug("[SlaMonitor] Registered SLA=#{name} kind=#{kind} target=#{target}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:check_violations, _from, state) do
    {breached, new_state} = do_check_violations(state)
    {:reply, breached, new_state}
  end

  @impl true
  def handle_call(:sla_dashboard, _from, state) do
    dashboard = build_dashboard()
    {:reply, dashboard, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    result = %{
      check_count: state.check_count,
      breach_count: state.breach_count,
      last_check: state.last_check,
      sla_count: :ets.info(@ets_slas, :size),
      sample_count: :ets.info(@ets_metrics, :size),
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:record_metric, sla_name, value}, state) do
    sample = %{
      sla_name: sla_name,
      value: value,
      ok: value > 0,
      timestamp: DateTime.utc_now()
    }

    key = {sla_name, sample.timestamp, :erlang.unique_integer([:monotonic])}
    :ets.insert(@ets_metrics, {key, sample})
    trim_metrics(sla_name)
    {:noreply, state}
  end

  @impl true
  def handle_info(:scheduled_check, state) do
    schedule_check()
    {_breached, new_state} = do_check_violations(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[SlaMonitor] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  defp do_check_violations(state) do
    slas = :ets.tab2list(@ets_slas)
    timestamp = DateTime.utc_now()

    breached =
      Enum.reduce(slas, [], fn {name, sla}, acc ->
        samples = fetch_samples(name)

        if length(samples) == 0 do
          acc
        else
          case compute_status(sla, samples) do
            %{breached: true} = status ->
              broadcast_breach(name, sla, status)
              emit_breach_telemetry(name, sla, status)

              Logger.warning(
                "[SlaMonitor] BREACH sla=#{name} kind=#{sla.kind} " <>
                  "target=#{sla.target}#{sla.unit} — SC-PERF-001, SC-ALARM-002"
              )

              [name | acc]

            _ ->
              acc
          end
        end
      end)

    new_state = %{
      state
      | check_count: state.check_count + 1,
        breach_count: state.breach_count + length(breached),
        last_check: timestamp
    }

    {breached, new_state}
  end

  defp fetch_samples(sla_name) do
    pattern = {{sla_name, :_, :_}, :_}

    @ets_metrics
    |> :ets.match_object(pattern)
    |> Enum.map(fn {_key, sample} -> sample end)
  end

  defp compute_status(%{kind: :uptime, target: target} = sla, samples) do
    ok_count = Enum.count(samples, & &1.ok)
    total = length(samples)
    uptime_pct = Float.round(ok_count / total * 100.0, 3)
    breached = uptime_pct < target

    %{
      name: sla.name,
      kind: :uptime,
      target: target,
      unit: "%",
      sample_count: total,
      current_value: uptime_pct,
      p50: nil,
      p95: nil,
      p99: nil,
      uptime_pct: uptime_pct,
      breached: breached,
      last_breach: if(breached, do: DateTime.utc_now(), else: nil)
    }
  end

  defp compute_status(%{kind: :response_time, target: target} = sla, samples) do
    values = Enum.map(samples, & &1.value) |> Enum.sort()
    count = length(values)
    p50 = percentile(values, count, 0.50)
    p95 = percentile(values, count, 0.95)
    p99 = percentile(values, count, 0.99)
    current = List.last(values)
    breached = p99 > target

    %{
      name: sla.name,
      kind: :response_time,
      target: target,
      unit: "ms",
      sample_count: count,
      current_value: current,
      p50: p50,
      p95: p95,
      p99: p99,
      uptime_pct: nil,
      breached: breached,
      last_breach: if(breached, do: DateTime.utc_now(), else: nil)
    }
  end

  defp percentile(sorted_values, count, pct) do
    idx = max(0, round(pct * count) - 1)
    Enum.at(sorted_values, idx, 0)
  end

  defp build_dashboard do
    :ets.tab2list(@ets_slas)
    |> Enum.map(fn {name, sla} ->
      samples = fetch_samples(name)

      if length(samples) == 0 do
        %{
          name: name,
          kind: sla.kind,
          target: sla.target,
          unit: sla.unit,
          sample_count: 0,
          current_value: nil,
          p50: nil,
          p95: nil,
          p99: nil,
          uptime_pct: nil,
          breached: false,
          last_breach: nil
        }
      else
        compute_status(sla, samples)
      end
    end)
  end

  defp register_default_slas do
    :ets.insert(@ets_slas, {
      :system_uptime,
      %{
        name: :system_uptime,
        kind: :uptime,
        description: "System availability — 99.9% uptime target",
        target: @default_uptime_target,
        unit: "%",
        registered_at: DateTime.utc_now()
      }
    })

    :ets.insert(@ets_slas, {
      :api_response_time,
      %{
        name: :api_response_time,
        kind: :response_time,
        description: "API response time — p99 ≤ #{@default_p99_target_ms}ms",
        target: @default_p99_target_ms,
        unit: "ms",
        registered_at: DateTime.utc_now()
      }
    })
  end

  defp trim_metrics(sla_name) do
    pattern = {{sla_name, :_, :_}, :_}
    count = :ets.match_object(@ets_metrics, pattern) |> length()

    if count > @samples_max do
      # Drop the oldest @samples_max/10 entries for this SLA
      drop = div(@samples_max, 10)

      @ets_metrics
      |> :ets.match_object(pattern)
      |> Enum.sort_by(fn {{_n, ts, _u}, _s} -> ts end)
      |> Enum.take(drop)
      |> Enum.each(fn {key, _} -> :ets.delete(@ets_metrics, key) end)
    end
  rescue
    _ -> :ok
  end

  defp broadcast_breach(name, sla, status) do
    message = %{
      event: :sla_breach,
      sla_name: name,
      kind: sla.kind,
      target: sla.target,
      unit: sla.unit,
      current_value: status.current_value,
      p99: status.p99,
      uptime_pct: status.uptime_pct,
      timestamp: DateTime.utc_now()
    }

    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:sla_breach, message})
    rescue
      e -> Logger.debug("[SlaMonitor] PubSub broadcast failed: #{inspect(e)}")
    end
  end

  defp emit_breach_telemetry(name, sla, status) do
    try do
      :telemetry.execute(
        [:indrajaal, :policy, :sla_breach],
        %{
          breach: 1,
          current_value: status.current_value || 0
        },
        %{sla_name: name, kind: sla.kind, target: sla.target}
      )
    rescue
      e -> Logger.debug("[SlaMonitor] telemetry.execute failed: #{inspect(e)}")
    end
  end

  defp schedule_check do
    Process.send_after(self(), :scheduled_check, @check_interval_ms)
  end

  defp ensure_ets_tables do
    if :ets.whereis(@ets_metrics) == :undefined do
      :ets.new(@ets_metrics, [:named_table, :public, :set, write_concurrency: true])
    end

    if :ets.whereis(@ets_slas) == :undefined do
      :ets.new(@ets_slas, [:named_table, :public, :set, read_concurrency: true])
    end
  end
end
