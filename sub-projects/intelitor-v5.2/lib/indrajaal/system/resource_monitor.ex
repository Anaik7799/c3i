defmodule Indrajaal.System.ResourceMonitor do
  @moduledoc """
  Monitors system resources (CPU, Memory) and reports metrics.
  Operates as a GenServer to periodically poll system state.
  """
  use GenServer
  require Logger

  # 5 seconds
  @interval 5000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    # Return placeholder metrics for now, or actual state if we had it
    # For simulation, return a random CPU value to trigger OODA logic
    cpu = :rand.uniform(100)
    mem = :rand.uniform(100)
    {:reply, %{cpu: cpu, memory: mem}, state}
  end

  @impl true
  def handle_info(:check_resources, state) do
    # Placeholder for actual resource checking logic (e.g., using :os_mon)
    # cpu = :cpu_sup.util()
    # mem = :memsup.get_system_memory_data()
    # Logger.info("System Resources: CPU load and Memory usage checked.")

    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_resources, @interval)
  end
end
