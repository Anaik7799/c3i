defmodule IndrajaalWeb.PerformanceDashboardLive do
  use IndrajaalWeb, :live_view
  require Logger

  @refresh_interval 5000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, :refresh)
    {:ok, load_metrics(assign(socket, page_title: "Performance Optimization Dashboard"))}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_metrics(socket)}
  end

  defp load_metrics(socket) do
    memory = :erlang.memory()
    {_, io_input} = :erlang.statistics(:io)
    schedulers = :erlang.system_info(:schedulers_online)
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    uptime_ms = :erlang.statistics(:wall_clock) |> elem(0)

    socket
    |> assign(:dashboard_active, true)
    |> assign(:memory_total_mb, Float.round(memory[:total] / 1_048_576, 1))
    |> assign(:memory_processes_mb, Float.round(memory[:processes] / 1_048_576, 1))
    |> assign(:memory_ets_mb, Float.round(memory[:ets] / 1_048_576, 1))
    |> assign(:memory_atom_mb, Float.round(memory[:atom] / 1_048_576, 1))
    |> assign(:schedulers, schedulers)
    |> assign(:process_count, process_count)
    |> assign(:process_limit, process_limit)
    |> assign(:process_pct, Float.round(process_count / process_limit * 100, 1))
    |> assign(:io_bytes, elem(io_input, 1))
    |> assign(:uptime_hours, Float.round(uptime_ms / 3_600_000, 1))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Performance Dashboard page (SC-HMI-001, SC-HMI-008) --%>
    <div class="p-6 bg-surface-primary dark:bg-surface-secondary">
      <h1 class="text-2xl font-bold mb-4 text-content-primary">
        SOPv5.1 Performance Optimization Dashboard
      </h1>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div class="bg-surface-primary dark:bg-surface-secondary shadow rounded-lg p-4 border border-border-theme-primary">
          <h2 class="font-semibold text-lg text-content-primary">BEAM Memory</h2>
          <div class="mt-2 space-y-1">
            <p class="text-content-secondary">
              Total: <span class="font-mono text-blue-400">{@memory_total_mb} MB</span>
            </p>
            <p class="text-content-secondary">
              Processes: <span class="font-mono text-green-400">{@memory_processes_mb} MB</span>
            </p>
            <p class="text-content-secondary">
              ETS: <span class="font-mono text-yellow-400">{@memory_ets_mb} MB</span>
            </p>
            <p class="text-content-secondary">
              Atoms: <span class="font-mono text-purple-400">{@memory_atom_mb} MB</span>
            </p>
          </div>
        </div>
        <div class="bg-surface-primary dark:bg-surface-secondary shadow rounded-lg p-4 border border-border-theme-primary">
          <h2 class="font-semibold text-lg text-content-primary">Schedulers & Processes</h2>
          <div class="mt-2 space-y-1">
            <p class="text-content-secondary">
              Schedulers: <span class="font-mono text-blue-400">{@schedulers}</span>
            </p>
            <p class="text-content-secondary">
              Processes:
              <span class="font-mono text-green-400">{@process_count} / {@process_limit}</span>
            </p>
            <p class="text-content-secondary">
              Utilization:
              <span class={"font-mono " <> if(@process_pct > 80, do: "text-red-400", else: "text-green-400")}>
                {@process_pct}%
              </span>
            </p>
          </div>
        </div>
        <div class="bg-surface-primary dark:bg-surface-secondary shadow rounded-lg p-4 border border-border-theme-primary">
          <h2 class="font-semibold text-lg text-content-primary">System Status</h2>
          <div class="mt-2 space-y-1">
            <p class="text-green-600 dark:text-green-400 font-medium">
              Dashboard Active: {@dashboard_active}
            </p>
            <p class="text-content-secondary">
              Uptime: <span class="font-mono text-blue-400">{@uptime_hours}h</span>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
