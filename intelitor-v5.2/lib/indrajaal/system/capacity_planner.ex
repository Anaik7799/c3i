defmodule Indrajaal.System.CapacityPlanner do
  @moduledoc """
  Capacity Planner — L5 Policy Layer (System Subsystem)

  ## Design Intent
  Plans system capacity by tracking resource utilization trends and projecting
  future needs. Uses linear regression on historical utilization data to predict
  when resources will be exhausted, enabling proactive scaling decisions.

  ## STAMP Constraints
  - SC-PERF-002: Resource utilization tracked
  - SC-PRED-001: Predictive modeling available
  - SC-ALARM-003: Capacity alerts generated

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :capacity_history
  @max_samples 1_000
  @check_interval_ms 60_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type resource :: :cpu | :memory | :disk | :connections | :ets_tables | atom()
  @type utilization :: float()

  @type projection :: %{
          resource: resource(),
          current_pct: utilization(),
          trend_per_hour: float(),
          exhaustion_hours: float() | :stable,
          recommendation: :ok | :warn | :critical | :scale_now
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Record current utilization for a resource."
  @spec record(resource(), utilization()) :: :ok
  def record(resource, pct) when is_float(pct) or is_integer(pct) do
    GenServer.call(@name, {:record, resource, pct / 1})
  end

  @doc "Get projection for a specific resource."
  @spec project(resource()) :: projection()
  def project(resource) do
    GenServer.call(@name, {:project, resource})
  end

  @doc "Get projections for all tracked resources."
  @spec project_all() :: [projection()]
  def project_all do
    GenServer.call(@name, :project_all)
  end

  @doc "Get capacity planning dashboard data."
  @spec dashboard() :: map()
  def dashboard do
    GenServer.call(@name, :dashboard)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :check_interval_ms, @check_interval_ms)

    :ets.new(@table, [:named_table, :public, :bag])

    schedule_check(interval)

    Logger.info("[CapacityPlanner] Started — interval=#{interval}ms [SC-PERF-002]")

    {:ok, %{check_interval: interval, checks: 0}}
  end

  @impl true
  def handle_call({:record, resource, pct}, _from, state) do
    ts = System.system_time(:millisecond)
    :ets.insert(@table, {resource, ts, pct})
    prune_old(resource)

    emit_telemetry(:recorded, %{resource: resource, pct: pct})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:project, resource}, _from, state) do
    result = compute_projection(resource)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:project_all, _from, state) do
    resources =
      :ets.tab2list(@table)
      |> Enum.map(fn {r, _, _} -> r end)
      |> Enum.uniq()

    projections = Enum.map(resources, &compute_projection/1)
    {:reply, projections, state}
  end

  @impl true
  def handle_call(:dashboard, _from, state) do
    resources =
      :ets.tab2list(@table)
      |> Enum.map(fn {r, _, _} -> r end)
      |> Enum.uniq()

    projections = Enum.map(resources, &compute_projection/1)

    critical = Enum.count(projections, &(&1.recommendation == :critical))
    warnings = Enum.count(projections, &(&1.recommendation == :warn))

    {:reply,
     %{
       resource_count: length(resources),
       projections: projections,
       critical_count: critical,
       warning_count: warnings,
       overall_health:
         cond do
           critical > 0 -> :critical
           warnings > 0 -> :degraded
           true -> :healthy
         end,
       checks: state.checks
     }, state}
  end

  @impl true
  def handle_info(:check, state) do
    # Auto-record system metrics
    record_system_metrics()
    schedule_check(state.check_interval)
    {:noreply, %{state | checks: state.checks + 1}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private — Projection Engine
  # ---------------------------------------------------------------------------

  defp compute_projection(resource) do
    samples =
      :ets.lookup(@table, resource)
      |> Enum.map(fn {_, ts, pct} -> {ts, pct} end)
      |> Enum.sort_by(fn {ts, _} -> ts end)

    current_pct =
      case List.last(samples) do
        {_, pct} -> pct
        nil -> 0.0
      end

    trend = linear_regression_slope(samples)
    # Convert from per-ms to per-hour
    trend_per_hour = trend * 3_600_000

    exhaustion =
      cond do
        trend_per_hour <= 0 -> :stable
        current_pct >= 100.0 -> 0.0
        true -> (100.0 - current_pct) / trend_per_hour
      end

    recommendation =
      cond do
        current_pct >= 90 -> :scale_now
        current_pct >= 80 -> :critical
        exhaustion != :stable and is_number(exhaustion) and exhaustion < 24 -> :warn
        true -> :ok
      end

    %{
      resource: resource,
      current_pct: Float.round(current_pct * 1.0, 2),
      trend_per_hour: Float.round(trend_per_hour, 4),
      exhaustion_hours:
        if(is_number(exhaustion), do: Float.round(exhaustion * 1.0, 1), else: exhaustion),
      recommendation: recommendation
    }
  end

  defp linear_regression_slope([]), do: 0.0
  defp linear_regression_slope([_]), do: 0.0

  defp linear_regression_slope(samples) do
    n = length(samples)

    {sum_x, sum_y, sum_xy, sum_x2} =
      Enum.reduce(samples, {0.0, 0.0, 0.0, 0.0}, fn {x, y}, {sx, sy, sxy, sx2} ->
        xf = x / 1.0
        yf = y / 1.0
        {sx + xf, sy + yf, sxy + xf * yf, sx2 + xf * xf}
      end)

    denominator = n * sum_x2 - sum_x * sum_x

    if abs(denominator) < 1.0e-10 do
      0.0
    else
      (n * sum_xy - sum_x * sum_y) / denominator
    end
  end

  # ---------------------------------------------------------------------------
  # Private — System Metrics
  # ---------------------------------------------------------------------------

  defp record_system_metrics do
    # Memory utilization
    mem = :erlang.memory(:total)
    # Approximate 8GB system memory
    mem_pct = mem / (8 * 1_073_741_824) * 100
    ts = System.system_time(:millisecond)
    :ets.insert(@table, {:memory, ts, min(mem_pct, 100.0)})

    # Process count (relative to limit)
    procs = :erlang.system_info(:process_count)
    proc_limit = :erlang.system_info(:process_limit)
    proc_pct = procs / proc_limit * 100
    :ets.insert(@table, {:processes, ts, proc_pct})

    # ETS table count
    ets_count = length(:ets.all())
    ets_pct = ets_count / 1000 * 100
    :ets.insert(@table, {:ets_tables, ts, min(ets_pct, 100.0)})
  rescue
    _ -> :ok
  end

  defp prune_old(resource) do
    entries = :ets.lookup(@table, resource)

    if length(entries) > @max_samples do
      sorted = Enum.sort_by(entries, fn {_, ts, _} -> ts end)
      to_delete = Enum.take(sorted, length(entries) - @max_samples)

      Enum.each(to_delete, fn entry ->
        :ets.delete_object(@table, entry)
      end)
    end
  rescue
    _ -> :ok
  end

  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end

  defp emit_telemetry(event, meta) do
    :telemetry.execute(
      [:indrajaal, :system, :capacity, event],
      %{timestamp: System.system_time(:millisecond)},
      meta
    )
  rescue
    _ -> :ok
  end
end
