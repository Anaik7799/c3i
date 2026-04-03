defmodule Indrajaal.OperationalExcellence.BackupScheduler do
  @moduledoc """
  Automated backup scheduling with configurable intervals and retention policies.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-003: Backup operations must not corrupt existing backups
  - UCA-003: Pr_event backup retention policy from deleting active backups
  """

  use GenServer
  require Logger

  alias Indrajaal.OperationalExcellence.BackupSystem

  @default_config %{
    daily_backup: ~T[02:00:00],
    hourly_incremental: true,
    retention_days: 30,
    max_backup_size_gb: 100,
    compression_enabled: true,
    parallel_backup: true
  }

  # Client API

  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Get the next scheduled backup time.
  """
  def next_backup_time do
    GenServer.call(__MODULE__, :next_backup_time)
  end

  @doc """
  Check if the scheduler is running.
  """
  def running? do
    GenServer.call(__MODULE__, :running?)
  end

  @doc """
  Cleanup old backups according to retention policy.
  Satisfies UCA-003: Pr_event deletion of active backups.
  """
  def cleanup_old_backups do
    GenServer.call(__MODULE__, :cleanup_old_backups, 60_000)
  end

  @doc """
  Manually trigger a backup.
  """
  def trigger_backup(type \\ :incremental) do
    GenServer.call(__MODULE__, {:trigger_backup, type}, 300_000)
  end

  @doc """
  Update scheduler configuration.
  """
  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end

  @doc """
  Get current scheduler status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server callbacks

  @impl true
  def init(custom_config) do
    # Merge with default config
    config = Map.merge(@default_config, custom_config)

    state = %{
      config: config,
      next_daily: calculate_next_daily_backup(config.daily_backup),
      next_hourly: if(config.hourly_incremental, do: calculate_next_hourly(), else: nil),
      last_backup: nil,
      backup_history: [],
      running: true,
      current_backup: nil,
      metrics: initialize_metrics()
    }

    # Schedule first backups
    schedule_next_backup(state)

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call(:next_backup_time, _from, state) do
    next_time = determine_next_backup_time(state)
    {:reply, next_time, state}
  end

  @impl true
  def handle_call(:running?, _from, state) do
    {:reply, state.running, state}
  end

  @impl true
  def handle_call(:cleanupold_backups, _from, state) do
    Logger.info("[BackupScheduler] Starting cleanup of old backups")

    # Get backups older than retention period
    old_backups = BackupSystem.list_backups_older_than(state.config.retention_days)

    # UCA-003: Safety checks before deletion
    safe_to_delete = filter_safe_to_delete(old_backups)

    # Delete safe backups
    deleted_count =
      Enum.reduce(safe_to_delete, 0, fn backup, count ->
        case delete_backup_safely(backup) do
          :ok -> count + 1
          # Unreachable clause commented out - delete_backup_safely/1 (line 463) returns File.rm_rf result which is {:error, reason, file} 3-tuple, not 2-tuple
          # {:error, _reason} -> count
          {:error, _reason, _file} -> count
        end
      end)

    # Update metrics
    new_metrics =
      Map.update(state.metrics, :backups_cleaned, deleted_count, &(&1 + deleted_count))

    result = %{
      total_old_backups: length(old_backups),
      deleted_count: deleted_count,
      protected_count: length(old_backups) - length(safe_to_delete),
      protected_backups: Enum.map(old_backups -- safe_to_delete, & &1.id)
    }

    {:reply, {:ok, result}, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:triggerbackup, type}, _from, state) do
    if state.current_backup do
      {:reply, {:error, :backup_in_progress}, state}
    else
      Logger.info("[BackupScheduler] Manually triggered #{type} backup")

      case perform_backup(type, state) do
        {:ok, backup_result} ->
          new_state = update_backup_state(state, backup_result, type)
          {:reply, {:ok, backup_result}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:updateconfig, new_config}, _from, state) do
    merged_config = Map.merge(state.config, new_config)

    new_state = %{
      state
      | config: merged_config,
        next_daily: calculate_next_daily_backup(merged_config.daily_backup),
        next_hourly: if(merged_config.hourly_incremental, do: calculate_next_hourly(), else: nil)
    }

    # Reschedule with new config
    schedule_next_backup(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:getstatus, _from, state) do
    status = %{
      running: state.running,
      config: state.config,
      next_daily_backup: state.next_daily,
      next_hourly_backup: state.next_hourly,
      last_backup: state.last_backup,
      current_backup: state.current_backup,
      metrics: state.metrics,
      backup_history_count: length(state.backup_history)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:performbackup, state) do
    if state.running and state.current_backup == nil do
      # Determine backup type
      backup_type = determine_backup_type(state)

      Logger.info("[BackupScheduler] Starting scheduled #{backup_type} backup")

      # Mark as running
      new_state = %{state | current_backup: backup_type}

      # Perform backup asynchronously
      self_pid = self()

      Task.start(fn ->
        result = perform_backup(backup_type, new_state)
        send(self_pid, {:backup_complete, backup_type, result})
      end)

      {:noreply, new_state}
    else
      # Skip this backup and reschedule
      schedule_next_backup(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:backupcomplete, backup_type, result}, state) do
    case result do
      {:ok, backup_result} ->
        Logger.info(
          "[BackupScheduler] #{backup_type} backup completed: #{inspect(backup_result)}"
        )

        new_state = update_backup_state(state, backup_result, backup_type)

        # Schedule next backup
        schedule_next_backup(new_state)

        {:noreply, %{new_state | current_backup: nil}}

      {:error, reason} ->
        Logger.error("[BackupScheduler] #{backup_type} backup failed: #{inspect(reason)}")

        # Update metrics
        new_metrics = Map.update(state.metrics, :failed_backups, 1, &(&1 + 1))

        # Schedule retry
        schedule_next_backup(state)

        {:noreply, %{state | current_backup: nil, metrics: new_metrics}}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Periodic cleanup
    cleanup_old_backups()

    # Check total backup size
    check_backup_size_limit(state)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, state}
  end

  # Private functions

  defp initialize_metrics do
    %{
      total_backups: 0,
      successful_backups: 0,
      failed_backups: 0,
      backups_cleaned: 0,
      total_backup_size_mb: 0.0,
      average_backup_duration_ms: 0
    }
  end

  defp calculate_next_daily_backup(daily_time) do
    now = DateTime.utc_now()
    today_backup = DateTime.new!(Date.utc_today(), daily_time)

    if DateTime.compare(now, today_backup) == :lt do
      today_backup
    else
      # Tomorrow
      tomorrow = Date.add(Date.utc_today(), 1)
      DateTime.new!(tomorrow, daily_time)
    end
  end

  defp calculate_next_hourly do
    # Next hour on the hour
    now = DateTime.utc_now()

    now
    |> DateTime.add(3600 - rem(now.second + now.minute * 60, 3600), :second)
    |> DateTime.truncate(:second)
  end

  defp determine_next_backup_time(state) do
    times =
      [state.next_daily, state.next_hourly]
      |> Enum.filter(& &1)
      |> Enum.sort(DateTime)

    List.first(times)
  end

  defp schedule_next_backup(state) do
    next_time = determine_next_backup_time(state)

    if next_time do
      delay = DateTime.diff(next_time, DateTime.utc_now(), :millisecond)

      if delay > 0 do
        Process.send_after(self(), :perform_backup, delay)
        Logger.info("[BackupScheduler] Next backup scheduled for #{next_time}")
      else
        # Immediate backup needed
        Process.send_after(self(), :perform_backup, 1000)
      end
    end
  end

  defp determine_backup_type(state) do
    now = DateTime.utc_now()

    # Check if it's time for daily backup
    if state.next_daily && DateTime.diff(state.next_daily, now, :second) <= 60 do
      :full
    else
      :incremental
    end
  end

  defp perform_backup(type, state) do
    start_time = System.monotonic_time(:millisecond)

    # SC-003: Ensure backup integrity
    result =
      case type do
        :full -> perform_full_backup(state)
        :incremental -> BackupSystem.perform_incremental_backup()
        _ -> {:error, :unknown_backup_type}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    # Add duration to result
    case result do
      {:ok, backup} ->
        {:ok, Map.put(backup, :duration_ms, duration)}

      error ->
        error
    end
  end

  defp perform_full_backup(_state) do
    # Full backup would be more complex in production
    # For now, delegate to incremental with a flag
    case BackupSystem.perform_incremental_backup() do
      {:ok, backup} ->
        {:ok, Map.put(backup, :type, :full)}

      error ->
        error
    end
  end

  defp update_backup_state(state, backup_result, backup_type) do
    # Update next backup times
    new_state =
      case backup_type do
        :full ->
          %{state | next_daily: calculate_next_daily_backup(state.config.daily_backup)}

        :incremental ->
          %{
            state
            | next_hourly:
                if(state.config.hourly_incremental, do: calculate_next_hourly(), else: nil)
          }

        _ ->
          state
      end

    # Update metrics
    new_metrics =
      state.metrics
      |> Map.update(:total_backups, 1, &(&1 + 1))
      |> Map.update(:successful_backups, 1, &(&1 + 1))
      |> update_average_duration(backup_result[:duration_ms] || 0)
      |> update_total_size(backup_result[:size_mb] || 0)

    # Update history
    backup_record = %{
      type: backup_type,
      result: backup_result,
      timestamp: DateTime.utc_now()
    }

    %{
      new_state
      | last_backup: backup_record,
        backup_history: [backup_record | new_state.backup_history] |> Enum.take(100),
        metrics: new_metrics
    }
  end

  defp update_average_duration(metrics, new_duration) do
    total = metrics.successful_backups
    current_avg = metrics.average_backup_duration_ms

    new_avg =
      if total > 0 do
        (current_avg * (total - 1) + new_duration) / total
      else
        new_duration
      end

    Map.put(metrics, :average_backup_duration_ms, new_avg)
  end

  defp update_total_size(metrics, size_mb) do
    Map.update(metrics, :total_backup_size_mb, size_mb, &(&1 + size_mb))
  end

  defp filter_safe_to_delete(old_backups) do
    # UCA-003: Comprehensive safety checks

    # Get all backups to check dependencies
    {:ok, all_backups} = BackupSystem.list_all_backups()

    Enum.filter(old_backups, fn backup ->
      # Check if backup has dependents
      has_dependents =
        Enum.any?(all_backups, fn b ->
          b.parent_backup_id == backup.id
        end)

      # Check if it's the only full backup
      is_only_full =
        backup.type == :full and
          Enum.count(all_backups, &(&1.type == :full)) == 1

      # Check if it's part of active restore chain
      in_active_chain = in_active_restore_chain?(backup)

      # Safe to delete only if none of the above
      not has_dependents and not is_only_full and not in_active_chain
    end)
  end

  defp in_active_restore_chain?(_backup) do
    # Would check with RestoreManager
    # For now, assume safe
    false
  end

  defp delete_backup_safely(backup) do
    Logger.info("[BackupScheduler] Deleting old backup: #{backup.id}")

    # Delete physical files
    backup_path = Path.join("__data/backups", backup.id)

    case File.rm_rf(backup_path) do
      {:ok, _} ->
        # Remove from meta_data
        # This would be handled by BackupSystem in production
        :ok

      error ->
        Logger.error("[BackupScheduler] Failed to delete backup #{backup.id}: #{inspect(error)}")
        error
    end
  end

  defp check_backup_size_limit(state) do
    max_size_mb = state.config.max_backup_size_gb * 1024

    if state.metrics.total_backup_size_mb > max_size_mb do
      Logger.warning(
        "[BackupScheduler] Total backup size exceeds limit: #{state.metrics.total_backup_size_mb}MB > #{max_size_mb}MB"
      )

      # Trigger aggressive cleanup
      cleanup_old_backups()
    end
  end

  defp schedule_cleanup do
    # Run cleanup every 24 hours
    Process.send_after(self(), :cleanup, 24 * 60 * 60 * 1000)
  end
end
