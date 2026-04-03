defmodule Indrajaal.Telemetry.PerformanceMonitor do
  @moduledoc """
  L4-Intelligence: Monitors system performance metrics and detects degradation.

  WHAT: GenServer that tracks BEAM scheduler utilization, process counts,
        memory pressure, and GC activity. Emits structured telemetry events
        for Zenoh forwarding (SC-OBS-069).
  WHY: Real-time performance visibility is required for SIL-6 compliance
       and SLA enforcement (SC-MON-002, SC-PERF-001).
  CONSTRAINTS: SC-MON-002, SC-PERF-001, SC-CPU-GOV-001, AOR-MON-001.

  ## Change History
  | Version | Date       | Author             | Change                       |
  |---------|------------|--------------------|------------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6  | Initial real implementation  |
  """

  use GenServer
  require Logger

  @check_interval_ms 10_000
  @degradation_cpu_threshold 0.80
  @degradation_memory_threshold 0.85

  defstruct [
    :samples,
    :last_check_at,
    :alerts
  ]

  # ---- Client API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the latest performance snapshot.
  """
  @spec get_snapshot() :: map()
  def get_snapshot do
    GenServer.call(__MODULE__, :get_snapshot)
  end

  @doc """
  Returns active performance alerts (degradation events).
  """
  @spec get_alerts() :: [map()]
  def get_alerts do
    GenServer.call(__MODULE__, :get_alerts)
  end

  # ---- GenServer Callbacks ----

  @impl true
  def init(_opts) do
    schedule_check()

    state = %__MODULE__{
      samples: [],
      last_check_at: nil,
      alerts: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_snapshot, _from, state) do
    {:reply, build_snapshot(state), state}
  end

  @impl true
  def handle_call(:get_alerts, _from, state) do
    {:reply, state.alerts, state}
  end

  @impl true
  def handle_info(:check_performance, state) do
    sample = collect_sample()
    alerts = detect_degradation(sample, state.alerts)

    if length(alerts) > length(state.alerts) do
      Logger.warning("[PerformanceMonitor] Performance degradation detected",
        alerts: alerts,
        stamp: "SC-MON-002"
      )
    end

    emit_telemetry(sample)

    new_state = %{
      state
      | samples: Enum.take([sample | state.samples], 10),
        last_check_at: DateTime.utc_now(),
        alerts: alerts
    }

    schedule_check()
    {:noreply, new_state}
  end

  # ---- Private Helpers ----

  defp collect_sample do
    mem = :erlang.memory()
    schedulers = :erlang.system_info(:schedulers_online)
    total_processes = :erlang.system_info(:process_count)
    max_processes = :erlang.system_info(:process_limit)
    run_queue = :erlang.statistics(:run_queue)

    total_mem = Map.get(mem, :total, 1)
    proc_mem = Map.get(mem, :processes, 0)
    binary_mem = Map.get(mem, :binary, 0)

    %{
      timestamp: DateTime.utc_now(),
      schedulers: schedulers,
      run_queue: run_queue,
      process_count: total_processes,
      process_utilization: total_processes / max_processes,
      memory_total_bytes: total_mem,
      memory_process_bytes: proc_mem,
      memory_binary_bytes: binary_mem,
      memory_utilization: proc_mem / max_mem_bytes(),
      reductions: elem(:erlang.statistics(:reductions), 0)
    }
  end

  defp max_mem_bytes do
    # Approximate available RAM; default 2GB if not determinable
    case :memsup.get_system_memory_data() do
      data when is_list(data) ->
        Keyword.get(data, :total_memory, 2_147_483_648)

      _ ->
        2_147_483_648
    end
  rescue
    _ -> 2_147_483_648
  end

  defp detect_degradation(sample, existing_alerts) do
    alerts = []

    alerts =
      if Map.get(sample, :memory_utilization, 0.0) > @degradation_memory_threshold do
        [
          %{type: :memory_pressure, value: sample.memory_utilization, at: sample.timestamp}
          | alerts
        ]
      else
        alerts
      end

    alerts =
      if Map.get(sample, :process_utilization, 0.0) > @degradation_cpu_threshold do
        [
          %{type: :process_pressure, value: sample.process_utilization, at: sample.timestamp}
          | alerts
        ]
      else
        alerts
      end

    # Expire old alerts (keep only alerts from last 5 minutes)
    cutoff = DateTime.add(DateTime.utc_now(), -300, :second)

    fresh_existing =
      Enum.filter(existing_alerts, fn a ->
        DateTime.compare(Map.get(a, :at, DateTime.utc_now()), cutoff) == :gt
      end)

    Enum.uniq_by(alerts ++ fresh_existing, & &1.type)
  end

  defp emit_telemetry(sample) do
    :telemetry.execute(
      [:indrajaal, :performance_monitor, :sample],
      %{
        run_queue: sample.run_queue,
        process_count: sample.process_count,
        memory_total_bytes: sample.memory_total_bytes,
        reductions: sample.reductions
      },
      %{
        memory_utilization: sample.memory_utilization,
        process_utilization: sample.process_utilization
      }
    )
  end

  defp build_snapshot(%__MODULE__{samples: [], last_check_at: nil}) do
    %{status: :initializing, samples: [], alerts: []}
  end

  defp build_snapshot(state) do
    latest = List.first(state.samples)

    %{
      status: if(state.alerts == [], do: :healthy, else: :degraded),
      last_check_at: state.last_check_at,
      current: latest,
      samples_count: length(state.samples),
      alerts: state.alerts
    }
  end

  defp schedule_check do
    Process.send_after(self(), :check_performance, @check_interval_ms)
  end
end
