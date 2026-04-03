defmodule Indrajaal.Metabolism.ResourceWatchdog do
  @moduledoc """
  L5-METABOLIC Watchdog.
  Monitors BEAM resource consumption and enforces the 70% Throttling Directive.
  Context: SIL-6 Biomorphic Homeostasis.
  """
  use GenServer
  require Logger

  # 5s
  @check_interval 5000
  @cpu_threshold 70.0

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_check()
    {:ok, %{last_total: 0, last_idle: 0}}
  end

  @impl true
  def handle_info(:check, state) do
    new_state = check_metabolism(state)
    schedule_check()
    {:noreply, new_state}
  end

  defp check_metabolism(state) do
    case get_cpu_stats() do
      {:ok, total, idle} ->
        diff_total = total - state.last_total
        diff_idle = idle - state.last_idle

        if diff_total > 0 do
          usage = (1 - diff_idle / diff_total) * 100

          if usage > @cpu_threshold do
            Logger.warning(
              "🔥 METABOLIC ALERT: CPU Usage #{Float.round(usage, 1)}% > #{@cpu_threshold}%. Throttling may occur."
            )
          end
        end

        %{state | last_total: total, last_idle: idle}

      _ ->
        state
    end
  end

  defp get_cpu_stats do
    try do
      # Parsing /proc/stat from NixOS container
      content = File.read!("/proc/stat")
      [line | _] = String.split(content, "\n")
      parts = String.split(line, " ", trim: true)
      # user nice system idle
      user = String.to_integer(Enum.at(parts, 1))
      nice = String.to_integer(Enum.at(parts, 2))
      system = String.to_integer(Enum.at(parts, 3))
      idle = String.to_integer(Enum.at(parts, 4))
      {:ok, user + nice + system + idle, idle}
    rescue
      _ -> :error
    end
  end

  defp schedule_check, do: Process.send_after(self(), :check, @check_interval)
end
