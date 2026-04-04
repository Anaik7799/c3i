defmodule Indrajaal.Core.TimestampSync do
  @moduledoc """
  Timestamp Synchronization Module

  Coordinates between:
  - Elixir GenServer (30-min interval sync)
  - Rust Daemon (background long-running process)
  - Shell Script (one-shot sync)

  The GenServer handles in-VM telemetry, while the Rust daemon
  runs independently and persists state to disk.
  """

  alias Indrajaal.Core.TimestampDaemon

  @doc """
  Sync now - delegates to Rust daemon if available, otherwise performs Elixir sync.
  """
  def sync_now do
    case TimestampDaemon.running?() do
      true ->
        # Daemon is running, force sync
        {:ok, _} = TimestampDaemon.force_sync()
        :ok

      false ->
        # Fall back to Elixir-only sync
        perform_elixir_sync()
    end
  end

  @doc """
  Get current drift status.
  """
  def drift_status do
    case TimestampDaemon.running?() do
      true ->
        status = TimestampDaemon.status()

        %{
          last_sync: status.last_sync,
          last_drift: Map.get(status, :system_to_model_drift, 0),
          sync_count: status.sync_count || 0,
          drift_level: String.to_atom(status.drift_level || "unknown"),
          source: :daemon
        }

      false ->
        perform_elixir_sync()
    end
  end

  @doc """
  Check if the daemon is running.
  """
  def daemon_running? do
    TimestampDaemon.running?()
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # PRIVATE
  # ═══════════════════════════════════════════════════════════════════════════════

  defp perform_elixir_sync do
    system_ts = System.system_time(:second)
    model_ts = get_model_timestamp()
    drift = system_ts - model_ts

    %{
      last_sync: DateTime.utc_now(),
      last_drift: drift,
      sync_count: 0,
      drift_level: classify_drift(abs(drift)),
      source: :elixir
    }
  end

  defp get_model_timestamp do
    case Application.get_env(:indrajaal, :model_session_start) do
      nil -> System.system_time(:second)
      ts -> ts
    end
  end

  defp classify_drift(abs_drift) when abs_drift <= 2, do: :nominal
  defp classify_drift(abs_drift) when abs_drift <= 5, do: :minor
  defp classify_drift(abs_drift) when abs_drift <= 10, do: :warning
  defp classify_drift(_), do: :critical
end
