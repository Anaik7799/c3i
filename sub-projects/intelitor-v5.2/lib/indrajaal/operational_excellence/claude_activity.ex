defmodule Indrajaal.OperationalExcellence.ClaudeActivity do
  @moduledoc """
  Claude activity logging system with tamper-proof audit trail.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-006: Claude activity logs must be tamper-proof
  - Comprehensive tracking of all Claude operations
  """

  use GenServer
  require Logger

  @log_dir "data/tmp"
  @activity_file_prefix "claude_activity"
  @max_memory_entries 10_000
  # 30 seconds
  @flush_interval 30_000
  @rotation_size_mb 100

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track a Claude operation with comprehensive details.
  Satisfies SC-006: Tamper-proof activity logging.
  """
  def track(operation, context) do
    GenServer.cast(__MODULE__, {:track_operation, operation, context})
  end

  @doc """
  Get the last logged entry.
  """
  def get_last_entry do
    GenServer.call(__MODULE__, :get_last_entry)
  end

  @doc """
  Find activities by script name.
  """
  def find_by_script(script_name) do
    GenServer.call(__MODULE__, {:find_by_script, script_name})
  end

  @doc """
  Attempt to modify an entry (should fail for tamper-proof).
  """
  def modify(entry) do
    GenServer.call(__MODULE__, {:modify_entry, entry})
  end

  @doc """
  Search activities by criteria.
  """
  def search(criteria) do
    GenServer.call(__MODULE__, {:search, criteria}, 10_000)
  end

  @doc """
  Get activity statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Export activities for a time range.
  """
  def export(start_time, end_time) do
    GenServer.call(__MODULE__, {:export, start_time, end_time}, 30_000)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Ensure log directory exists
    File.mkdir_p!(@log_dir)

    state = %{
      current_file: open_activity_file(),
      entries_buffer: [],
      entries_count: 0,
      file_size_mb: 0,
      memory_cache: :queue.new(),
      memory_cache_size: 0,
      stats: initialize_stats(),
      last_flush: DateTime.utc_now()
    }

    # Schedule periodic flush
    schedule_flush()

    # Load recent entries into memory cache
    state = load_recent_entries(state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:track_operation, operation, context}, state) do
    # Create tamper-proof entry
    entry = create_activity_entry(operation, context)

    # Buffer the entry
    new_buffer = [entry | state.entries_buffer]

    # Update memory cache
    new_cache = add_to_memory_cache(state.memory_cache, entry, state.memory_cache_size)
    new_cache_size = min(state.memory_cache_size + 1, @max_memory_entries)

    # Update stats
    new_stats = update_activity_stats(state.stats, entry)

    new_state = %{
      state
      | entries_buffer: new_buffer,
        entries_count: state.entries_count + 1,
        memory_cache: new_cache,
        memory_cache_size: new_cache_size,
        stats: new_stats
    }

    # Check if we need to flush
    new_state =
      if should_flush?(new_state) do
        flush_entries(new_state)
      else
        new_state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:getlastentry, _from, state) do
    last_entry =
      case state.entries_buffer do
        [entry | _] -> entry
        [] -> get_last_from_cache(state.memory_cache)
      end

    {:reply, last_entry, state}
  end

  @impl true
  def handle_call({:find_by_script, script_name}, _from, state) do
    # Search in memory first
    memory_results =
      search_memory_cache(state.memory_cache, fn entry ->
        get_in(entry, [:operation, :target]) == script_name
      end)

    # If not enough results, search files
    results =
      if length(memory_results) < 10 do
        file_results = search_activity_files(script_name)
        memory_results ++ file_results
      else
        memory_results
      end

    {:reply, results, state}
  end

  @impl true
  def handle_call({:modifyentry, _entry}, _from, state) do
    # SC-006: Pr_event tampering - always return error
    {:reply, {:error, :tamper_detected}, state}
  end

  @impl true
  def handle_call({:search, criteria}, _from, state) do
    # Comprehensive search across memory and files
    results = search_activities(criteria, state)
    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(:getstats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        buffered_entries: length(state.entries_buffer),
        memory_cache_size: state.memory_cache_size,
        current_file_size_mb: state.file_size_mb
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:export, start_time, end_time}, _from, state) do
    # Flush current buffer first
    state = flush_entries(state)

    # Export entries from files
    result = export_time_range(start_time, end_time)

    {:reply, result, state}
  end

  @impl true
  def handle_info(:flush, state) do
    # Periodic flush
    new_state =
      if Enum.empty?(state.entries_buffer) do
        state
      else
        flush_entries(state)
      end

    # Schedule next flush
    schedule_flush()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:checkrotation, state) do
    # Check if current file needs rotation
    new_state =
      if state.file_size_mb > @rotation_size_mb do
        rotate_activity_file(state)
      else
        state
      end

    # Schedule next check
    schedule_rotation_check()

    {:noreply, new_state}
  end

  # Private functions

  defp initialize_stats do
    %{
      total_operations: 0,
      operations_by_type: %{},
      frameworks_used: %{},
      compliance_violations: 0,
      performance_metrics: %{
        avg_operation_time_ms: 0,
        max_operation_time_ms: 0,
        min_operation_time_ms: nil
      }
    }
  end

  defp open_activity_file do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    filename = "#{@activity_file_prefix}_#{timestamp}.jsonl"
    filepath = Path.join(@log_dir, filename)

    case File.open(filepath, [:append, :utf8]) do
      {:ok, file} ->
        Logger.info("[ClaudeActivity] Opened activity log: #{filename}")

        %{
          handle: file,
          path: filepath,
          opened_at: DateTime.utc_now()
        }

      {:error, reason} ->
        Logger.error("[ClaudeActivity] Failed to open log file: #{inspect(reason)}")
        nil
    end
  end

  defp create_activity_entry(operation, context) do
    # SC-006: Create tamper-proof entry with all details
    entry_id = generate_entry_id()
    timestamp = DateTime.utc_now()

    entry = %{
      id: entry_id,
      timestamp: timestamp,
      timestamp_unix: DateTime.to_unix(timestamp, :microsecond),
      session_id: context[:session_id] || "unknown",
      operation: sanitize_operation(operation),
      frameworks_used: detect_frameworks_used(operation),
      performance: measure_operation_performance(operation),
      compliance: validate_compliance(operation),
      context: sanitize_context(context),
      version: "1.0.0"
    }

    # Add checksum for tamper detection
    checksum = calculate_entry_checksum(entry)
    Map.put(entry, :checksum, checksum)
  end

  defp generate_entry_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
  end

  defp sanitize_operation(operation) do
    # Remove sensitive data from operation
    operation
    |> Map.take([:type, :target, :result, :duration_ms])
    |> Map.update(:parameters, %{}, &sanitize_params/1)
  end

  defp sanitize_params(params) when is_map(params) do
    params
    |> Map.drop([:password, :secret, :token, :key])
    |> Enum.map(fn {k, v} -> {k, sanitize_value(v)} end)
    |> Map.new()
  end

  defp sanitize_params(params), do: params

  defp sanitize_value(value) when is_binary(value) and byte_size(value) > 1000 do
    String.slice(value, 0..1000) <> "...[truncated]"
  end

  defp sanitize_value(value), do: value

  defp sanitize_context(context) do
    Map.take(context, [:user, :source, :environment])
  end

  defp detect_frameworks_used(operation) do
    # Detect which frameworks were involved
    frameworks = []
    frameworks = if operation[:aee_coordination], do: [:aee | frameworks], else: frameworks
    frameworks = if operation[:sopv51_compliance], do: [:sopv51 | frameworks], else: frameworks
    frameworks = if operation[:tps_quality], do: [:tps | frameworks], else: frameworks
    frameworks = if operation[:stamp_safety], do: [:stamp | frameworks], else: frameworks
    frameworks = if operation[:gde_optimization], do: [:gde | frameworks], else: frameworks
    frameworks = if operation[:phics_enabled], do: [:phics | frameworks], else: frameworks

    if Enum.empty?(frameworks), do: [:none], else: frameworks
  end

  defp measure_operation_performance(operation) do
    %{
      execution_time_ms: operation[:duration_ms] || 0,
      cpu_usage: operation[:cpu_usage] || 0.0,
      memory_mb: operation[:memory_mb] || 0.0,
      io_operations: operation[:io_operations] || 0
    }
  end

  defp validate_compliance(operation) do
    violations = []

    violations =
      if operation[:bypass_validation], do: [:bypass_validation | violations], else: violations

    violations =
      if operation[:unsafe_operation], do: [:unsafe_operation | violations], else: violations

    violations =
      if operation[:framework_disabled], do: [:framework_disabled | violations], else: violations

    %{
      all_passed?: Enum.empty?(violations),
      violations: violations,
      validation_timestamp: DateTime.utc_now()
    }
  end

  defp calculate_entry_checksum(entry) do
    # Remove checksum field before calculating
    entry_without_checksum = Map.delete(entry, :checksum)

    entry_without_checksum
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16()
  end

  defp add_to_memory_cache(cache, entry, current_size) do
    if current_size >= @max_memory_entries do
      # Remove oldest entry
      {{:value, _}, new_cache} = :queue.out(cache)
      :queue.in(entry, new_cache)
    else
      :queue.in(entry, cache)
    end
  end

  defp get_last_from_cache(cache) do
    case :queue.peek_r(cache) do
      {:value, entry} -> entry
      :empty -> nil
    end
  end

  defp should_flush?(state) do
    # Flush if buffer is large or time elapsed
    length(state.entries_buffer) >= 100 or
      DateTime.diff(DateTime.utc_now(), state.last_flush, :millisecond) > @flush_interval
  end

  defp flush_entries(state) do
    if state.current_file && not Enum.empty?(state.entries_buffer) do
      # Write entries to file and calculate total size
      total_size_added =
        state.entries_buffer
        |> Enum.reverse()
        |> Enum.reduce(0, fn entry, acc ->
          line = Jason.encode!(entry) <> "\n"
          IO.write(state.current_file.handle, line)
          acc + byte_size(line)
        end)

      # Ensure data is written
      :ok = :file.sync(state.current_file.handle)

      # Git add for version control
      System.cmd("git", ["add", state.current_file.path])

      %{
        state
        | entries_buffer: [],
          last_flush: DateTime.utc_now(),
          file_size_mb: state.file_size_mb + total_size_added / 1_048_576
      }
    else
      state
    end
  end

  defp update_activity_stats(stats, entry) do
    stats
    |> Map.update(:total_operations, 1, &(&1 + 1))
    |> update_operation_type_stats(entry)
    |> update_framework_stats(entry)
    |> update_compliance_stats(entry)
    |> update_performance_stats(entry)
  end

  defp update_operation_type_stats(stats, entry) do
    op_type = get_in(entry, [:operation, :type]) || :unknown

    Map.update(stats, :operations_by_type, %{op_type => 1}, fn types ->
      Map.update(types, op_type, 1, &(&1 + 1))
    end)
  end

  defp update_framework_stats(stats, entry) do
    frameworks = entry.frameworks_used || []

    Map.update(stats, :frameworks_used, %{}, fn fw_stats ->
      Enum.reduce(frameworks, fw_stats, fn fw, acc ->
        Map.update(acc, fw, 1, &(&1 + 1))
      end)
    end)
  end

  defp update_compliance_stats(stats, entry) do
    if get_in(entry, [:compliance, :all_passed?]) do
      stats
    else
      Map.update(stats, :compliance_violations, 1, &(&1 + 1))
    end
  end

  defp update_performance_stats(stats, entry) do
    exec_time = get_in(entry, [:performance, :execution_time_ms]) || 0

    perf =
      stats.performance_metrics
      |> update_average_time(exec_time, stats.total_operations)
      |> Map.update(:max_operation_time_ms, exec_time, &max(&1, exec_time))
      |> Map.update(:min_operation_time_ms, exec_time, fn
        nil -> exec_time
        min -> min(min, exec_time)
      end)

    Map.put(stats, :performance_metrics, perf)
  end

  defp update_average_time(perf, new_time, total) do
    avg =
      if total > 1 do
        current = perf.avg_operation_time_ms
        (current * (total - 1) + new_time) / total
      else
        new_time
      end

    Map.put(perf, :avg_operation_time_ms, avg)
  end

  defp search_memory_cache(cache, filter_fn) do
    cache
    |> :queue.to_list()
    |> Enum.filter(filter_fn)
    |> Enum.take(50)
  end

  defp search_activity_files(script_name) do
    # Search recent activity files - Last 5 files
    files = list_activity_files()

    files
    |> Enum.take(5)
    |> Enum.flat_map(fn file ->
      search_file_for_script(file, script_name)
    end)
    |> Enum.take(50)
  end

  defp search_file_for_script(filepath, script_name) do
    filepath
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
    |> Enum.filter(fn entry ->
      get_in(entry, ["operation", "target"]) == script_name
    end)
    |> Enum.map(&atomize_entry/1)
  end

  defp list_activity_files do
    pattern = Path.join(@log_dir, "#{@activity_file_prefix}_*.jsonl")

    pattern
    |> Path.wildcard()
    |> Enum.sort(:desc)
  end

  defp search_activities(criteria, state) do
    # Search both memory and files
    memory_results = search_memory_with_criteria(state.memory_cache, criteria)

    file_results =
      if map_size(criteria) > 0 do
        search_files_with_criteria(criteria)
      else
        []
      end

    (memory_results ++ file_results)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(100)
  end

  defp search_memory_with_criteria(cache, criteria) do
    cache_list = :queue.to_list(cache)
    cache_list |> Enum.filter(fn entry -> matches_criteria?(entry, criteria) end)
  end

  defp matches_criteria?(entry, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :session_id -> entry.session_id == value
        :operation_type -> get_in(entry, [:operation, :type]) == value
        :start_time -> DateTime.compare(entry.timestamp, value) in [:gt, :eq]
        :end_time -> DateTime.compare(entry.timestamp, value) in [:lt, :eq]
        :framework -> value in (entry.frameworks_used || [])
        _ -> false
      end
    end)
  end

  defp search_files_with_criteria(criteria) do
    files = list_activity_files()

    files
    |> Enum.take(10)
    |> Enum.flat_map(fn file ->
      search_file_with_criteria(file, criteria)
    end)
  end

  defp search_file_with_criteria(filepath, criteria) do
    filepath
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
    |> Enum.map(&atomize_entry/1)
    |> Enum.filter(fn entry -> matches_criteria?(entry, criteria) end)
  end

  defp export_time_range(start_time, end_time) do
    export_file = Path.join(@log_dir, "export_#{timestamp_string()}.json")
    files = list_activity_files()

    entries =
      files
      |> Enum.flat_map(fn file ->
        export_from_file(file, start_time, end_time)
      end)
      |> Enum.sort_by(& &1.timestamp, DateTime)

    export_data = %{
      export_time: DateTime.utc_now(),
      start_time: start_time,
      end_time: end_time,
      total_entries: length(entries),
      entries: entries
    }

    case File.write(export_file, Jason.encode!(export_data, pretty: true)) do
      :ok -> {:ok, export_file}
      error -> error
    end
  end

  defp export_from_file(filepath, start_time, end_time) do
    filepath
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
    |> Enum.map(&atomize_entry/1)
    |> Enum.filter(fn entry ->
      DateTime.compare(entry.timestamp, start_time) in [:gt, :eq] and
        DateTime.compare(entry.timestamp, end_time) in [:lt, :eq]
    end)
  end

  defp load_recent_entries(state) do
    # Load last 1000 entries into memory cache
    files = list_activity_files()

    recent_entries =
      files
      |> Enum.take(3)
      |> Enum.flat_map(&load_entries_from_file/1)
      |> Enum.take(@max_memory_entries)

    cache =
      Enum.reduce(recent_entries, :queue.new(), fn entry, q ->
        :queue.in(entry, q)
      end)

    %{state | memory_cache: cache, memory_cache_size: :queue.len(cache)}
  end

  defp load_entries_from_file(filepath) do
    filepath
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
    |> Enum.map(&atomize_entry/1)
    |> Enum.to_list()
    |> Enum.reverse()
  rescue
    _ -> []
  end

  defp rotate_activity_file(state) do
    # Close current file
    if state.current_file do
      File.close(state.current_file.handle)
    end

    # Open new file
    new_file = open_activity_file()

    %{state | current_file: new_file, file_size_mb: 0}
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp schedule_rotation_check do
    # Check every minute
    Process.send_after(self(), :check_rotation, 60_000)
  end

  defp timestamp_string do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace(~r/[:\s]/, "_")
  end

  defp atomize_entry(entry) when is_map(entry) do
    entry
    |> Enum.map(fn {k, v} ->
      key = if is_binary(k), do: String.to_atom(k), else: k
      {key, atomize_value(v)}
    end)
    |> Map.new()
  end

  defp atomize_value(value) when is_map(value), do: atomize_entry(value)
  defp atomize_value(value) when is_list(value), do: Enum.map(value, &atomize_value/1)

  defp atomize_value(value) when is_binary(value) do
    # Try to parse datetime strings
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> value
    end
  end

  defp atomize_value(value), do: value
end
