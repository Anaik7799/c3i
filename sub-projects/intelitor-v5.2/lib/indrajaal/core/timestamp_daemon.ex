defmodule Indrajaal.Core.TimestampDaemon do
  @moduledoc """
  Elixir wrapper for the Rust Timestamp Sync Daemon.

  This module provides an interface to start, stop, and query the 
  background timestamp synchronization daemon written in Rust.

  ## Usage

  ```elixir
  # Start the daemon
  {:ok, pid} = TimestampDaemon.start()

  # Query status
  status = TimestampDaemon.status()

  # Stop the daemon
  :ok = TimestampDaemon.stop()
  ```
  """

  use GenServer
  require Logger

  @name __MODULE__

  @daemon_path :indrajaal
               |> Application.app_dir(
                 "../../../native/timestamp_daemon/target/release/timestamp_daemon"
               )
               |> Path.expand()

  # ═══════════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Start the timestamp sync daemon as a background process.
  """
  def start do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @doc """
  Stop the timestamp sync daemon.
  """
  def stop do
    GenServer.stop(@name, :normal, 5000)
  end

  @doc """
  Get the current status from the daemon's state file.
  """
  def status do
    state_path = state_file_path()

    if File.exists?(state_path) do
      state_path
      |> File.read!()
      |> Jason.decode!(keys: :atoms!)
    else
      %{
        last_sync: nil,
        drift_level: :unknown,
        sync_count: 0
      }
    end
  rescue
    _ ->
      %{
        last_sync: nil,
        drift_level: :unknown,
        sync_count: 0
      }
  end

  @doc """
  Get the current drift in seconds.
  """
  def drift do
    Map.get(status(), :system_to_model_drift, 0)
  end

  @doc """
  Get the current drift level.
  """
  def drift_level do
    Map.get(status(), :drift_level, :unknown)
  end

  @doc """
  Check if the daemon is running.
  """
  def running? do
    pid_file = pid_file_path()

    if File.exists?(pid_file) do
      case File.read(pid_file) do
        {:ok, pid_str} ->
          pid = String.trim(pid_str) |> String.to_integer()
          # Check if process exists
          Process.info(pid) != nil

        _ ->
          false
      end
    else
      false
    end
  end

  @doc """
  Force an immediate sync (updates state file, daemon will pick it up).
  """
  def force_sync do
    system_ts = System.system_time(:second)

    state = %{
      last_sync: system_ts,
      last_sync_iso: DateTime.utc_now() |> DateTime.to_iso8601(),
      opencode_session_start: system_ts,
      model_timestamp: system_ts,
      system_to_model_drift: 0,
      sync_count: 0,
      sync_source: "Elixir Force Sync",
      drift_level: "nominal"
    }

    :ok = write_state(state)
    Logger.info("[TimestampDaemon] Force sync executed")
    {:ok, state}
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # SERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    Logger.info("[TimestampDaemon] Initializing Rust daemon wrapper")

    # Start the Rust daemon process
    daemon_pid = start_daemon_process()

    state = %{
      daemon_pid: daemon_pid,
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("[TimestampDaemon] Terminating")

    if state.daemon_pid && Process.alive?(state.daemon_pid) do
      Process.exit(state.daemon_pid, :normal)
    end

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # PRIVATE
  # ═══════════════════════════════════════════════════════════════════════════════

  defp start_daemon_process do
    # Find the daemon binary
    daemon = find_daemon_binary()

    if daemon && File.exists?(daemon) do
      Logger.info("[TimestampDaemon] Starting Rust daemon: #{daemon}")

      opts = [
        :stream,
        :binary,
        :exit_status,
        [:stderr, :stdout]
      ]

      port = Port.open({:spawn_executable, daemon}, opts)

      # Log output from daemon
      spawn_link(fn -> log_daemon_output(port) end)

      port
    else
      Logger.warning("[TimestampDaemon] Daemon binary not found, using Elixir fallback")
      nil
    end
  end

  defp find_daemon_binary do
    # Try multiple paths
    paths = [
      Path.expand("../native/timestamp_daemon/target/release/timestamp_daemon"),
      Path.expand("../../native/timestamp_daemon/target/release/timestamp_daemon"),
      @daemon_path,
      System.find_executable("timestamp_daemon")
    ]

    Enum.find(paths, &(&1 && File.exists?(&1)))
  end

  defp log_daemon_output(port) do
    receive do
      {^port, {:data, data}} ->
        data
        |> String.trim()
        |> String.split("\n")
        |> Enum.each(&Logger.debug("[TimestampDaemon] #{&1}"))

        log_daemon_output(port)

      {^port, {:exit_status, status}} ->
        Logger.info("[TimestampDaemon] Daemon exited with status: #{status}")
    end
  end

  defp state_file_path do
    Path.expand("../../data/state/timestamp-state.json")
  end

  defp pid_file_path do
    data_dir = :indrajaal |> Application.app_dir() |> Path.expand() |> Path.join("..")
    Path.join([data_dir, "timestamp-daemon.pid"])
  end

  defp write_state(state) do
    state_path = state_file_path()

    state_path
    |> Path.dirname()
    |> File.mkdir_p!()

    state
    |> Jason.encode!(pretty: true)
    |> File.write!(state_path)
  end
end
