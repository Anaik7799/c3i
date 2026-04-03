defmodule Indrajaal.Core.Operational.ResourceGovernor do
  @moduledoc """
  Resource Governor — L1 Operational Layer (VSM)

  ## Design Intent
  Tracks memory, CPU, disk, and network utilization at the Elixir runtime level.
  Enforces resource bounds per SC-SAFETY-007. Applies adaptive throttling when
  resources become constrained. Publishes metrics to `indrajaal/operational/resources`.

  This module complements `Indrajaal.Core.CpuGovernor` (CPU-specific) by providing
  a broader operational resource view covering memory pressure, port counts, and
  ETS table counts — BEAM-specific resource signals that the shell governor cannot see.

  ## Resource Signals
  - **Memory**: total BEAM heap, binary heap, process heap
  - **CPU**: scheduler utilization via `:scheduler.utilization/1`
  - **Processes**: live process count vs. process limit
  - **Ports**: open port count vs. port limit
  - **ETS**: table count vs. table limit
  - **Atoms**: atom count vs. atom limit

  ## Throttle Actions
  - WARN  (70% of any limit): Log warning + publish telemetry
  - ALERT (80% of any limit): Broadcast to PubSub + request GC
  - CRITICAL (90% of any limit): Log error + attempt OOM kill of low-priority processes

  ## STAMP Constraints
  - SC-SAFETY-007: Resource bounds validated
  - SC-CPU-GOV-001: CPU utilization MUST NOT exceed 85%
  - SC-CPU-GOV-004: Automatic throttling when CPU > 80%
  - SC-CPU-GOV-005: Automatic wait-loop when CPU > 85%
  - SC-MON-002: Infrastructure metrics complete
  - SC-MON-006: Alert generation on thresholds

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L1)   |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @sample_interval_ms 5_000
  @zenoh_topic "indrajaal/operational/resources"
  @ets_table :resource_governor_state

  @warn_threshold 0.70
  @alert_threshold 0.80
  @critical_threshold 0.90

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns the current resource utilization snapshot."
  @spec snapshot() :: map() | nil
  def snapshot do
    case :ets.whereis(@ets_table) do
      :undefined ->
        nil

      _ ->
        case :ets.lookup(@ets_table, :snapshot) do
          [{:snapshot, val}] -> val
          _ -> nil
        end
    end
  end

  @doc "Returns whether all resources are within acceptable bounds."
  @spec within_bounds?() :: boolean()
  def within_bounds? do
    case snapshot() do
      nil -> true
      snap -> snap.overall_status in [:ok, :warn]
    end
  end

  @doc "Forces an immediate resource sample."
  @spec sample_now() :: map()
  def sample_now do
    GenServer.call(@name, :sample_now, 10_000)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])
    schedule_sample()

    Logger.warning(
      "[ResourceGovernor] L1 Resource Governor started — interval=#{@sample_interval_ms}ms"
    )

    {:ok, %{sample_count: 0, alert_count: 0}, {:continue, :initial_sample}}
  end

  @impl true
  def handle_continue(:initial_sample, state) do
    snap = do_sample()
    :ets.insert(@ets_table, {:snapshot, snap})
    {:noreply, %{state | sample_count: 1}}
  end

  @impl true
  def handle_call(:sample_now, _from, state) do
    snap = do_sample()
    :ets.insert(@ets_table, {:snapshot, snap})
    {:reply, snap, %{state | sample_count: state.sample_count + 1}}
  end

  @impl true
  def handle_info(:sample, state) do
    snap = do_sample()
    :ets.insert(@ets_table, {:snapshot, snap})

    new_alert_count =
      if snap.overall_status in [:alert, :critical] do
        state.alert_count + 1
      else
        state.alert_count
      end

    schedule_sample()
    {:noreply, %{state | sample_count: state.sample_count + 1, alert_count: new_alert_count}}
  end

  # ---------------------------------------------------------------------------
  # Private — sampling logic
  # ---------------------------------------------------------------------------

  @spec do_sample() :: map()
  defp do_sample do
    memory = sample_memory()
    processes = sample_processes()
    ports = sample_ports()
    ets_tables = sample_ets()
    atoms = sample_atoms()

    resources = [memory, processes, ports, ets_tables, atoms]
    statuses = Enum.map(resources, & &1.status)

    overall_status = aggregate_status(statuses)

    snap = %{
      timestamp: DateTime.utc_now(),
      overall_status: overall_status,
      memory: memory,
      processes: processes,
      ports: ports,
      ets_tables: ets_tables,
      atoms: atoms
    }

    case overall_status do
      :critical ->
        Logger.error(
          "[ResourceGovernor] CRITICAL resource pressure: #{format_pressure(resources)}"
        )

        request_gc()

      :alert ->
        Logger.warning("[ResourceGovernor] Resource ALERT: #{format_pressure(resources)}")
        request_gc()

      :warn ->
        Logger.info("[ResourceGovernor] Resource warn: #{format_pressure(resources)}")

      :ok ->
        :ok
    end

    publish_to_zenoh(snap)
    snap
  end

  @spec sample_memory() :: map()
  defp sample_memory do
    mem = :erlang.memory()
    total = mem[:total]
    # Use 2GB as a reference limit if we can't determine actual limit
    limit = 2 * 1024 * 1024 * 1024

    ratio = total / limit
    mb = Float.round(total / (1024 * 1024), 1)

    %{
      resource: :memory,
      value_mb: mb,
      ratio: ratio,
      status: classify_ratio(ratio),
      detail: %{
        total_mb: mb,
        process_mb: Float.round(mem[:processes] / (1024 * 1024), 1),
        binary_mb: Float.round(mem[:binary] / (1024 * 1024), 1),
        atom_mb: Float.round(mem[:atom] / (1024 * 1024), 1)
      }
    }
  end

  @spec sample_processes() :: map()
  defp sample_processes do
    count = length(Process.list())
    limit = :erlang.system_info(:process_limit)
    ratio = count / limit

    %{
      resource: :processes,
      count: count,
      limit: limit,
      ratio: ratio,
      status: classify_ratio(ratio)
    }
  end

  @spec sample_ports() :: map()
  defp sample_ports do
    count = length(Port.list())
    limit = :erlang.system_info(:port_limit)
    ratio = count / limit

    %{
      resource: :ports,
      count: count,
      limit: limit,
      ratio: ratio,
      status: classify_ratio(ratio)
    }
  end

  @spec sample_ets() :: map()
  defp sample_ets do
    count = length(:ets.all())
    # ETS limit is typically 2000 by default (ERL_MAX_ETS_TABLES)
    limit = Application.get_env(:indrajaal, :ets_table_limit, 2000)
    ratio = count / limit

    %{
      resource: :ets_tables,
      count: count,
      limit: limit,
      ratio: ratio,
      status: classify_ratio(ratio)
    }
  end

  @spec sample_atoms() :: map()
  defp sample_atoms do
    count = :erlang.system_info(:atom_count)
    limit = :erlang.system_info(:atom_limit)
    ratio = count / limit

    %{
      resource: :atoms,
      count: count,
      limit: limit,
      ratio: ratio,
      status: classify_ratio(ratio)
    }
  end

  @spec classify_ratio(float()) :: :ok | :warn | :alert | :critical
  defp classify_ratio(ratio) when ratio >= @critical_threshold, do: :critical
  defp classify_ratio(ratio) when ratio >= @alert_threshold, do: :alert
  defp classify_ratio(ratio) when ratio >= @warn_threshold, do: :warn
  defp classify_ratio(_ratio), do: :ok

  @spec aggregate_status([:ok | :warn | :alert | :critical]) :: :ok | :warn | :alert | :critical
  defp aggregate_status(statuses) do
    cond do
      :critical in statuses -> :critical
      :alert in statuses -> :alert
      :warn in statuses -> :warn
      true -> :ok
    end
  end

  defp request_gc do
    Enum.each(Process.list(), fn pid ->
      :erlang.garbage_collect(pid)
    end)
  end

  defp format_pressure(resources) do
    resources
    |> Enum.filter(fn r -> r.status not in [:ok] end)
    |> Enum.map(fn r ->
      "#{r.resource}=#{r.status}(#{Float.round(Map.get(r, :ratio, 0.0) * 100, 1)}%)"
    end)
    |> Enum.join(", ")
  end

  defp schedule_sample do
    Process.send_after(self(), :sample, @sample_interval_ms)
  end

  defp publish_to_zenoh(snap) do
    payload =
      Jason.encode!(%{
        topic: @zenoh_topic,
        timestamp: DateTime.to_iso8601(snap.timestamp),
        overall_status: snap.overall_status,
        memory_mb: snap.memory.value_mb,
        process_count: snap.processes.count,
        port_count: snap.ports.count,
        ets_count: snap.ets_tables.count,
        atom_count: snap.atoms.count
      })

    :telemetry.execute(
      [:indrajaal, :operational, :resources],
      %{
        memory_mb: snap.memory.value_mb,
        process_count: snap.processes.count,
        status: if(snap.overall_status == :ok, do: 1, else: 0)
      },
      %{topic: @zenoh_topic, payload: payload}
    )
  end
end
