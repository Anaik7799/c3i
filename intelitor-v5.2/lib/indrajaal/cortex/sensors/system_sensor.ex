defmodule Indrajaal.Cortex.Sensors.SystemSensor do
  @moduledoc """
  System-level sensor for BEAM VM and OS metrics.

  Measures:
  - Memory usage (system, process, ETS, binary)
  - CPU/scheduler utilization
  - Process counts and run queue depth
  - IO metrics
  - GC statistics

  STAMP Compliance:
  - SC-CTX-002: Sensor redundancy
  - SC-OBS-070: System observability
  """

  use GenServer

  require Logger

  @measure_interval :timer.seconds(5)

  ## Client API

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current system metrics snapshot.
  """
  @spec measure() :: map()
  def measure do
    GenServer.call(__MODULE__, :measure)
  end

  @doc """
  Get historical measurements.
  """
  @spec history(non_neg_integer()) :: list(map())
  def history(count \\ 10) do
    GenServer.call(__MODULE__, {:history, count})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("📊 SystemSensor: Initializing system metrics sensor")

    state = %{
      current: nil,
      history: [],
      max_history: 100,
      started_at: DateTime.utc_now()
    }

    # Take initial measurement
    send(self(), :measure)
    schedule_measurement()

    {:ok, state}
  end

  @impl true
  def handle_call(:measure, _from, state) do
    metrics = take_measurement()
    {:reply, metrics, %{state | current: metrics}}
  end

  @impl true
  def handle_call({:history, count}, _from, state) do
    {:reply, Enum.take(state.history, count), state}
  end

  @impl true
  def handle_info(:measure, state) do
    metrics = take_measurement()

    new_history =
      [metrics | state.history]
      |> Enum.take(state.max_history)

    schedule_measurement()
    {:noreply, %{state | current: metrics, history: new_history}}
  end

  ## Private Functions

  defp schedule_measurement do
    Process.send_after(self(), :measure, @measure_interval)
  end

  defp take_measurement do
    memory = :erlang.memory()
    system_info = get_system_info()
    scheduler_util = get_scheduler_utilization()

    %{
      # Memory metrics (normalized to 0-1 scale)
      memory_usage: calculate_memory_usage(memory),
      memory_total: memory[:total],
      memory_processes: memory[:processes],
      memory_ets: memory[:ets],
      memory_binary: memory[:binary],
      memory_atom: memory[:atom],

      # CPU/Scheduler metrics
      cpu_usage: scheduler_util,
      schedulers: system_info.schedulers,
      schedulers_online: system_info.schedulers_online,

      # Process metrics
      process_count: system_info.process_count,
      process_limit: system_info.process_limit,
      run_queue: system_info.run_queue,

      # Port metrics
      port_count: system_info.port_count,
      port_limit: system_info.port_limit,

      # Atom metrics
      atom_count: system_info.atom_count,
      atom_limit: system_info.atom_limit,

      # IO metrics
      io_input: get_io_stats(:input),
      io_output: get_io_stats(:output),

      # GC stats
      gc_stats: get_gc_stats(),

      # Timestamp
      measured_at: DateTime.utc_now()
    }
  end

  defp calculate_memory_usage(memory) do
    total = memory[:total]
    # Estimate system memory limit (this is approximate)
    # In production, this should come from system configuration
    system_limit = get_memory_limit()

    if system_limit > 0 do
      min(total / system_limit, 1.0)
    else
      # Default to medium if we can't determine limit
      0.5
    end
  end

  defp get_memory_limit do
    # Try to get from system
    case :os.type() do
      {:unix, _} ->
        try do
          {result, 0} = System.cmd("grep", ["MemTotal", "/proc/meminfo"])
          [_, kb_str | _] = String.split(result)
          String.to_integer(kb_str) * 1024
        rescue
          # Fallback estimate
          _ -> :erlang.memory(:total) * 2
        end

      _ ->
        # Fallback for other OS
        :erlang.memory(:total) * 2
    end
  end

  defp get_system_info do
    %{
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      run_queue: :erlang.statistics(:run_queue),
      port_count: :erlang.system_info(:port_count),
      port_limit: :erlang.system_info(:port_limit),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit)
    }
  end

  defp get_scheduler_utilization do
    # Simple approximation based on run queue
    schedulers = :erlang.system_info(:schedulers_online)
    run_queue = :erlang.statistics(:run_queue)

    # Normalize: run_queue / schedulers, capped at 1.0
    min(run_queue / max(schedulers, 1), 1.0)
  end

  defp get_io_stats(direction) do
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)

    case direction do
      :input -> input
      :output -> output
    end
  end

  defp get_gc_stats do
    # Get GC statistics if available
    try do
      {gcs, words_reclaimed, _} = :erlang.statistics(:garbage_collection)
      %{collections: gcs, words_reclaimed: words_reclaimed}
    rescue
      _ -> %{collections: 0, words_reclaimed: 0}
    end
  end
end
