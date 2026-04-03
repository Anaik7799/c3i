defmodule Indrajaal.Observability.LoggingEnhanced do
  @moduledoc """
  Enhanced logging module with complete dual-backend support and advanced features.

  This module extends the existing logging functionality with:
  - Structured logging with consistent formatting
  - Dynamic log level management
  - Context propagation and correlation IDs
  - Log sanitization and PII protection
  - Multi-backend support with independent configurations
  - Performance timing and metrics
  - Log querying and analysis capabilities
  - Rate limiting and safety constraints

  ## Usage

      # Set __context for all logs in process
      LoggingEnhanced.set_context(%{_request_id: "_req_123", user_id: 42})

      # Structured logging
      LoggingEnhanced.info("User logged in", %{email: "user@example.com"})

      # Performance timing
      LoggingEnhanced.time("database_query", fn ->
        # Your code here
      end)

      # Multi-backend configuration
      LoggingEnhanced.add_backend(:json, format: :json, path: "/var/log/app.json")
      LoggingEnhanced.add_backend(:console, format: :plain, level: :debug)
  """

  use GenServer
  require Logger

  # State structure
  defstruct [
    :log_level,
    :module_levels,
    :backends,
    :sanitization_rules,
    :rate_limiter,
    :query_buffer,
    :statistics,
    :__context_store
  ]

  # Default configuration
  @default_log_level :info
  @max_message_size 8192
  @max_context_depth 10
  # 1 minute
  @rate_limit_window 60_000
  @rate_limit_max 1000
  @query_buffer_size 10_000

  # Sensitive field patterns
  @sensitive_patterns ~w(password secret token api_key credit_card ssn social_security)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Logs a message at info level with optional metadata.
  """
  def info(message, metadata \\ %{}) do
    log(:info, message, metadata)
  end

  @doc """
  Logs a message at debug level with optional metadata.
  """
  def debug(message, metadata \\ %{}) do
    log(:debug, message, metadata)
  end

  @doc """
  Logs a message at warning level with optional metadata.
  SC-SIL6-001: Use :warning (OTP 28 compatible) instead of deprecated :warn
  """
  def warn(message, metadata \\ %{}) do
    log(:warning, message, metadata)
  end

  @doc """
  Logs a message at error level with optional metadata.
  """
  def error(message, metadata \\ %{}) do
    log(:error, message, metadata)
  end

  @doc """
  Gets the current log level.
  """
  def get_level do
    GenServer.call(__MODULE__, :get_level)
  end

  @doc """
  Sets the global log level.
  SC-SIL6-001: Accept both :warn and :warning for backwards compatibility
  """
  def set_level(level) when level in [:debug, :info, :warn, :warning, :error] do
    # Normalize deprecated :warn to :warning
    normalized = if level == :warn, do: :warning, else: level
    GenServer.call(__MODULE__, {:set_level, normalized})
  end

  @doc """
  Sets log level for a specific module.
  """
  def set_module_level(module, level) do
    GenServer.call(__MODULE__, {:set_module_level, module, level})
  end

  @doc """
  Sets __context metadata for the current process.
  """
  def set_context(context) when is_map(context) do
    Process.put(:logging_context, context)
    :ok
  end

  @doc """
  Executes a function with additional context.
  """
  def with_context(context, fun) when is_map(context) and is_function(fun, 0) do
    current = Process.get(:logging_context, %{})
    Process.put(:logging_context, Map.merge(current, context))

    try do
      fun.()
    after
      Process.put(:logging_context, current)
    end
  end

  @doc """
  Generates a correlation ID.
  """
  def generate_correlation_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    encoded = rand_bytes |> Base.encode16(case: :lower)
    "corr_#{encoded}"
  end

  @doc """
  Executes a function with a correlation ID in context.
  """
  def with_correlation_id(correlation_id, fun) do
    with_context(%{correlation_id: correlation_id}, fun)
  end

  @doc """
  Adds a sanitization rule for a field.
  """
  def add_sanitization_rule(field, sanitizer) when is_function(sanitizer, 1) do
    GenServer.call(__MODULE__, {:add_sanitization_rule, field, sanitizer})
  end

  @doc """
  Adds a logging backend.
  """
  def add_backend(name, opts \\ []) do
    GenServer.call(__MODULE__, {:add_backend, name, opts})
  end

  @doc """
  Removes a logging backend.
  """
  def remove_backend(backend_ref) do
    GenServer.call(__MODULE__, {:remove_backend, backend_ref})
  end

  @doc """
  Checks if a backend received a message.
  """
  def backend_received?(backend_ref, message) do
    GenServer.call(__MODULE__, {:backend_received?, backend_ref, message})
  end

  @doc """
  Gets the output from a backend.
  """
  def get_backend_output(backend_ref) do
    GenServer.call(__MODULE__, {:get_backend_output, backend_ref})
  end

  @doc """
  Gets the status of a backend.
  """
  def backend_status(backend_ref) do
    GenServer.call(__MODULE__, {:backend_status, backend_ref})
  end

  @doc """
  Times an operation and logs the duration.
  """
  def time(operation_name, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:millisecond) - start_time

      info("Timed operation", %{
        operation: operation_name,
        duration_ms: duration,
        status: "success"
      })

      result
    rescue
      error ->
        duration = System.monotonic_time(:millisecond) - start_time

        error("Timed operation failed", %{
          operation: operation_name,
          duration_ms: duration,
          status: "error",
          error: Exception.message(error)
        })

        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Enables query mode to buffer logs for querying.
  """
  def enable_query_mode do
    GenServer.call(__MODULE__, :enable_query_mode)
  end

  @doc """
  Disables query mode.
  """
  def disable_query_mode do
    GenServer.call(__MODULE__, :disable_query_mode)
  end

  @doc """
  Queries buffered logs.
  """
  def query(filters) when is_map(filters) do
    GenServer.call(__MODULE__, {:query, filters})
  end

  @doc """
  Enables statistics collection.
  """
  def enable_statistics do
    GenServer.call(__MODULE__, :enable_statistics)
  end

  @doc """
  Disables statistics collection.
  """
  def disable_statistics do
    GenServer.call(__MODULE__, :disable_statistics)
  end

  @doc """
  Gets logging statistics.
  """
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  ## GenServer callbacks

  def init(opts) do
    state = %__MODULE__{
      log_level: Keyword.get(opts, :log_level, @default_log_level),
      module_levels: %{},
      backends: %{},
      sanitization_rules: build_default_sanitization_rules(),
      rate_limiter: init_rate_limiter(),
      query_buffer: [],
      statistics: init_statistics(),
      __context_store: %{}
    }

    # Initialize default backends
    {:ok, console_ref} = add_backend_internal(state, :console, format: :plain)
    {:ok, json_ref} = add_backend_internal(state, :json, format: :json)

    updated_state = put_in(state.backends[:console], console_ref)
    updated_state = put_in(updated_state.backends[:json], json_ref)

    {:ok, updated_state}
  end

  def handle_call(:getlevel, _from, state) do
    {:reply, state.log_level, state}
  end

  def handle_call({:setlevel, level}, _from, state) do
    {:reply, :ok, %{state | log_level: level}}
  end

  def handle_call({:setmodulelevel, module, level}, _from, state) do
    updated_levels = Map.put(state.module_levels, module, level)
    {:reply, :ok, %{state | module_levels: updated_levels}}
  end

  def handle_call({:addsanitizationrule, field, sanitizer}, _from, state) do
    updated_rules = Map.put(state.sanitization_rules, to_string(field), sanitizer)
    {:reply, :ok, %{state | sanitization_rules: updated_rules}}
  end

  def handle_call({:addbackend, name, opts}, _from, state) do
    case add_backend_internal(state, name, opts) do
      {:ok, ref} ->
        updated_backends =
          Map.put(state.backends, ref, %{
            name: name,
            opts: opts,
            status: :active,
            buffer: []
          })

        {:reply, {:ok, ref}, %{state | backends: updated_backends}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:removebackend, ref}, _from, state) do
    updated_backends = Map.delete(state.backends, ref)
    {:reply, :ok, %{state | backends: updated_backends}}
  end

  def handle_call({:backendreceived?, ref, message}, _from, state) do
    backend = Map.get(state.backends, ref, %{buffer: []})

    received =
      Enum.any?(backend.buffer, fn log ->
        String.contains?(log, message)
      end)

    {:reply, received, state}
  end

  def handle_call({:getbackendoutput, ref}, _from, state) do
    backend = Map.get(state.backends, ref, %{buffer: []})
    output = Enum.join(backend.buffer, "\n")
    {:reply, output, state}
  end

  def handle_call({:backendstatus, ref}, _from, state) do
    backend = Map.get(state.backends, ref)
    status = if backend, do: backend.status, else: :not_found
    {:reply, status, state}
  end

  def handle_call(:enablequery_mode, _from, state) do
    {:reply, :ok, %{state | query_buffer: []}}
  end

  def handle_call(:disable_query_mode, _from, state) do
    {:reply, :ok, %{state | query_buffer: nil}}
  end

  def handle_call({:query_logs, _query, filters}, _from, state) do
    results =
      state.query_buffer
      |> Enum.filter(fn log_entry ->
        Enum.all?(filters, fn {key, value} ->
          Map.get(log_entry.metadata, key) == value
        end)
      end)

    {:reply, results, state}
  end

  def handle_call(:enablestatistics, _from, state) do
    {:reply, :ok, %{state | statistics: init_statistics()}}
  end

  def handle_call(:disablestatistics, _from, state) do
    {:reply, :ok, %{state | statistics: nil}}
  end

  def handle_call(:getstatistics, _from, state) do
    stats =
      if state.statistics do
        %{
          by_level: state.statistics.by_level,
          total: state.statistics.total
        }
      else
        %{by_level: %{}, total: 0}
      end

    {:reply, stats, state}
  end

  def handle_cast({:log, level, message, metadata}, state) do
    # Check rate limiting
    case check_rate_limit(state.rate_limiter) do
      :ok ->
        # Process and dispatch log
        updated_state = process_log(state, level, message, metadata)
        {:noreply, updated_state}

      {:dropped, :rate_limited} ->
        # Notify about rate limiting
        send(self(), {:log_flood_detected, state.rate_limiter.count})
        {:noreply, state}
    end
  end

  ## Private functions

  defp log(level, message, metadata) do
    # Get process __context
    context = Process.get(:logging_context, %{})

    # Add timestamp
    metadata = Map.put(metadata, :timestamp, DateTime.utc_now() |> DateTime.to_iso8601())

    # Merge with __context
    full_metadata = Map.merge(context, metadata)

    # Send to GenServer
    GenServer.cast(__MODULE__, {:log, level, message, full_metadata})
  end

  defp process_log(state, level, message, metadata) do
    # Check if we should log based on level
    if should_log?(state, level, metadata) do
      # Sanitize metadata
      sanitized_metadata = sanitize_metadata(metadata, state.sanitization_rules)

      # Format log entry
      log_entry = %{
        level: level,
        message: message,
        metadata: sanitized_metadata,
        timestamp: metadata.timestamp || DateTime.utc_now()
      }

      # Update statistics
      state = update_statistics(state, level)

      # Buffer for querying
      state = buffer_for_query(state, log_entry)

      # Dispatch to backends
      state = dispatch_to_backends(state, log_entry)

      # Log through Elixir Logger as well (for dual backend)
      formatted = format_for_logger(log_entry)
      Logger.log(level, formatted, sanitized_metadata)

      state
    else
      state
    end
  end

  defp should_log?(state, level, metadata) do
    # Check module-specific level first
    module = metadata[:module]

    effective_level =
      if module && Map.has_key?(state.module_levels, module) do
        state.module_levels[module]
      else
        state.log_level
      end

    level_to_number(level) >= level_to_number(effective_level)
  end

  defp level_to_number(:debug), do: 0
  defp level_to_number(:info), do: 1
  defp level_to_number(:warn), do: 2
  defp level_to_number(:warning), do: 2
  defp level_to_number(:error), do: 3

  defp sanitize_metadata(metadata, rules) do
    metadata
    |> flatten_map()
    |> Enum.map(fn {key, value} ->
      sanitized_value = apply_sanitization(key, value, rules)
      {key, sanitized_value}
    end)
    |> Map.new()
  end

  defp flatten_map(map, prefix \\ "") do
    Enum.flat_map(map, fn {k, v} ->
      key = if prefix == "", do: to_string(k), else: "#{prefix}.#{k}"

      case v do
        %{} = nested when map_size(nested) > 0 ->
          if key |> String.split(".") |> length() < @max_context_depth do
            flatten_map(nested, key)
          else
            [{key, "[MAX_DEPTH_EXCEEDED]"}]
          end

        list when is_list(list) ->
          list
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, idx} ->
            flatten_map(%{idx => item}, key)
          end)

        value ->
          [{key, value}]
      end
    end)
  end

  defp apply_sanitization(key, value, rules) do
    key_str = to_string(key)

    # Check custom rules first
    if Map.has_key?(rules, key_str) do
      rules[key_str].(value)
    else
      # Check against sensitive patterns
      if Enum.any?(@sensitive_patterns, &String.contains?(key_str, &1)) do
        sanitize_value(key_str, value)
      else
        # Truncate large values
        if is_binary(value) && byte_size(value) > @max_message_size do
          "[TRUNCATED: #{byte_size(value)} bytes]"
        else
          value
        end
      end
    end
  end

  defp sanitize_value(key, value) when is_binary(value) do
    cond do
      String.contains?(key, "email") ->
        parts = String.split(value, "@")

        if length(parts) == 2 do
          user = hd(parts)
          "#{user}@[REDACTED]"
        else
          "[REDACTED]"
        end

      String.contains?(key, "credit_card") ->
        "[REDACTED]"

      String.contains?(key, ["ssn", "social_security"]) ->
        "[REDACTED]"

      true ->
        "[REDACTED]"
    end
  end

  defp sanitize_value(_key, _value), do: "[REDACTED]"

  defp update_statistics(state, level) do
    if state.statistics do
      updated_stats = %{
        state.statistics
        | total: state.statistics.total + 1,
          by_level: Map.update(state.statistics.by_level, level, 1, &(&1 + 1))
      }

      %{state | statistics: updated_stats}
    else
      state
    end
  end

  defp buffer_for_query(state, log_entry) do
    if state.query_buffer != nil do
      updated_buffer = [log_entry | state.query_buffer]

      # Limit buffer size
      trimmed_buffer =
        if length(updated_buffer) > @query_buffer_size do
          Enum.take(updated_buffer, @query_buffer_size)
        else
          updated_buffer
        end

      %{state | query_buffer: trimmed_buffer}
    else
      state
    end
  end

  defp dispatch_to_backends(state, log_entry) do
    updated_backends =
      state.backends
      |> Enum.map(fn {ref, backend} ->
        updated_backend =
          try do
            output = format_for_backend(log_entry, backend.opts)
            buffer = [output | backend.buffer]

            # Limit buffer size
            trimmed_buffer = Enum.take(buffer, 100)

            %{backend | buffer: trimmed_buffer, status: :active}
          rescue
            _error ->
              %{backend | status: :failed}
          end

        {ref, updated_backend}
      end)
      |> Map.new()

    %{state | backends: updated_backends}
  end

  defp format_for_backend(log_entry, opts) do
    case Keyword.get(opts, :format, :plain) do
      :json ->
        Jason.encode!(%{
          message: log_entry.message,
          level: log_entry.level,
          timestamp: log_entry.timestamp,
          metadata: log_entry.metadata
        })

      :plain ->
        metadata_str =
          log_entry.metadata
          |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{inspect(v)}" end)

        "#{log_entry.message} #{metadata_str}"
    end
  end

  defp format_for_logger(log_entry) do
    metadata_str =
      log_entry.metadata
      |> Enum.reject(fn {k, _} -> k in [:timestamp] end)
      |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{inspect(v)}" end)

    if metadata_str == "" do
      log_entry.message
    else
      "#{log_entry.message} #{metadata_str}"
    end
  end

  defp build_default_sanitization_rules do
    %{}
  end

  defp init_rate_limiter do
    %{
      window_start: System.monotonic_time(:millisecond),
      count: 0,
      window_size: @rate_limit_window,
      max_count: @rate_limit_max
    }
  end

  defp check_rate_limit(limiter) do
    now = System.monotonic_time(:millisecond)

    if now - limiter.window_start > limiter.window_size do
      # New window
      Process.put(:rate_limiter, %{limiter | window_start: now, count: 1})
      :ok
    else
      # Same window
      if limiter.count >= limiter.max_count do
        {:dropped, :rate_limited}
      else
        Process.put(:rate_limiter, %{limiter | count: limiter.count + 1})
        :ok
      end
    end
  end

  defp init_statistics do
    %{
      total: 0,
      by_level: %{
        debug: 0,
        info: 0,
        warn: 0,
        warning: 0,
        error: 0
      }
    }
  end

  defp add_backend_internal(_state, name, opts) do
    ref = make_ref()

    backend = %{
      ref: ref,
      name: name,
      opts: opts,
      status: :active,
      buffer: []
    }

    {:ok, backend}
  end
end
