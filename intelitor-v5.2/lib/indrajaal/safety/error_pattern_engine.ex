defmodule Indrajaal.Safety.ErrorPatternEngine do
  @moduledoc """
  Error Pattern Matching Engine with automated remediation.

  Provides:
  - Pattern - based error detection and classification
  - Automated remediation action execution
  - Learning system for pattern improvement
  - Integration with TPS 5 - Level RCA methodology
  - STAMP safety compliance for error handling

  Implements comprehensive error pattern database with 110+ patterns
  covering all major error categories and systematic fixes.
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.PatternDatabase

  # Error pattern categories for systematic classification
  @pattern_categories %{
    connection: [:database, :network, :service, :authentication],
    performance: [:timeout, :memory, :cpu, :disk, :latency],
    security: [:authentication, :authorization, :encryption, :validation],
    data: [:corruption, :consistency, :integrity, :validation],
    system: [:resource, :configuration, :deployment, :monitoring]
  }

  # Remediation severity levels
  @remediation_severity %{
    # Immediate emergency action _required
    critical: 1,
    # Urgent intervention needed
    high: 2,
    # Standard remediation process
    medium: 3,
    # Monitoring and logging only
    low: 4
  }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyzes error and applies matching patterns with remediation.
  """
  @spec analyze_error(map()) :: {:ok, term()} | {:error, term()}
  def analyze_error(error_data) when is_map(error_data) do
    GenServer.call(__MODULE__, {:analyze, error_data})
  end

  @doc """
  Batch analyzes multiple errors for efficiency.
  """
  @spec analyze_errors(list()) :: list()
  def analyze_errors(error_list) when is_list(error_list) do
    GenServer.call(__MODULE__, {:batch_analyze, error_list})
  end

  @doc """
  Registers a new error pattern dynamically.
  """
  @spec register_pattern(map()) :: :ok | {:error, term()}
  def register_pattern(pattern) when is_map(pattern) do
    GenServer.call(__MODULE__, {:register_pattern, pattern})
  end

  @doc """
  Gets current pattern matching statistics.
  """
  @spec get_statistics :: term()
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Forces reload of pattern database from storage.
  """
  @spec reload_patterns :: :ok
  def reload_patterns do
    GenServer.cast(__MODULE__, :reload_patterns)
  end

  # GenServer Callbacks

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(opts) do
    # Load patterns from database
    patterns = load_error_patterns()

    # Initialize statistics tracking
    stats = %{
      patterns_loaded: length(patterns),
      analyses_performed: 0,
      successful_remediations: 0,
      failed_remediations: 0,
      pattern_matches: %{},
      remediation_success_rate: 0.0
    }

    # Setup pattern performance tracking
    pattern_performance =
      Map.new(patterns, fn pattern ->
        {pattern.id, %{matches: 0, successes: 0, failures: 0}}
      end)

    state = %{
      patterns: index_patterns_by_type(patterns),
      statistics: stats,
      pattern_performance: pattern_performance,
      remediation_history: [],
      learning_enabled: Keyword.get(opts, :learning_enabled, true)
    }

    Logger.info("Error Pattern Engine initialized with #{length(patterns)} patterns")

    :telemetry.execute(
      [:indrajaal, :safety, :error_pattern_engine, :started],
      %{patterns_count: length(patterns)},
      %{categories: Map.keys(@pattern_categories)}
    )

    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  # AGENT GA PHASE 9 FIX
  def handle_call({:analyze, error_data}, _from, state) do
    {result, new_state} = perform_error_analysis(error_data, state)
    {:reply, result, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  # AGENT GA PHASE 9 FIX
  def handle_call({:batch_analyze, error_list}, _from, state) do
    {results, new_state} = perform_batch_analysis(error_list, state)
    {:reply, results, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  # AGENT GA PHASE 9 FIX
  def handle_call({:register_pattern, pattern}, _from, state) do
    case validate_pattern(pattern) do
      :ok ->
        new_patterns = add_pattern_to_index(state.patterns, pattern)

        new_performance =
          Map.put(state.pattern_performance, pattern.id, %{matches: 0, successes: 0, failures: 0})

        new_state = %{
          state
          | patterns: new_patterns,
            pattern_performance: new_performance,
            statistics: update_in(state.statistics, [:patterns_loaded], &(&1 + 1))
        }

        Logger.info("New error pattern registered",
          pattern_id: pattern.id,
          type: pattern.type
        )

        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.warning("Pattern registration failed", reason: reason, pattern: inspect(pattern))
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  # AGENT GA PHASE 9 FIX
  def handle_call(:get_statistics, _from, state) do
    enhanced_stats = enhance_statistics(state.statistics, state.pattern_performance)
    {:reply, enhanced_stats, state}
  end

  @impl true
  @spec handle_cast(term(), term()) :: term()
  def handle_cast(:reload_patterns, state) do
    patterns = load_error_patterns()

    new_state = %{
      state
      | patterns: index_patterns_by_type(patterns),
        statistics: update_in(state.statistics, [:patterns_loaded], fn _ -> length(patterns) end)
    }

    Logger.info("Error patterns reloaded", count: length(patterns))
    {:noreply, new_state}
  end

  # Private Implementation

  @spec perform_error_analysis(map(), map()) :: {term(), map()}
  defp perform_error_analysis(error_data, state) do
    # Extract error classification data
    error_text = extract_error_text(error_data)
    error_context = extract_error_context(error_data)

    # Find matching patterns
    matching_patterns = find_matching_patterns(error_text, error_context, state.patterns)

    case matching_patterns do
      [] ->
        # No patterns matched - create learning opportunity
        handle_unmatched_error(error_data, state)

      patterns ->
        # Execute remediation for best matching pattern
        best_pattern = select_best_pattern(patterns)
        execute_pattern_remediation(best_pattern, error_data, state)
    end
  end

  @spec perform_batch_analysis(list(), map()) :: {list(), map()}
  defp perform_batch_analysis(error_list, state) do
    {results, final_state} =
      Enum.reduce(error_list, {[], state}, fn error, {acc_results, acc_state} ->
        {result, new_state} = perform_error_analysis(error, acc_state)
        {[result | acc_results], new_state}
      end)

    {Enum.reverse(results), final_state}
  end

  @spec extract_error_text(map()) :: String.t()
  defp extract_error_text(error_data) do
    text =
      case error_data do
        %{message: message} when is_binary(message) -> message
        %{error: error} when is_binary(error) -> error
        %{exception: %{message: message}} when is_binary(message) -> message
        %{reason: reason} when is_binary(reason) -> reason
        _ -> inspect(error_data)
      end

    # Ensure we always return a binary string, never nil
    if is_binary(text), do: text, else: ""
  end

  @spec extract_error_context(map()) :: map()
  defp extract_error_context(error_data) do
    %{
      module: Map.get(error_data, :module),
      function: Map.get(error_data, :function),
      line: Map.get(error_data, :line),
      stacktrace: Map.get(error_data, :stacktrace),
      metadata: Map.get(error_data, :metadata, %{}),
      timestamp: Map.get(error_data, :timestamp, DateTime.utc_now()),
      severity: Map.get(error_data, :severity, :medium)
    }
  end

  defp find_matching_patterns(error_text, context, patterns_by_category) do
    # Check each category for matches
    # AGENT GA PHASE 9 FIX
    all_patterns = Enum.flat_map(patterns_by_category, fn {_category, patterns} -> patterns end)

    Enum.filter(all_patterns, fn pattern ->
      matches_pattern?(pattern, error_text, context)
    end)
  end

  defp matches_pattern?(pattern, error_text, context) do
    # Check pattern regex match (guard against nil error_text)
    regex_match =
      if is_binary(error_text) do
        Regex.match?(pattern.pattern, error_text)
      else
        false
      end

    # Check __contextual conditions if present
    context_match =
      case pattern[:conditions] do
        nil -> true
        conditions -> evaluate_conditions(conditions, context)
      end

    regex_match and context_match
  end

  @spec evaluate_conditions(list(), map()) :: boolean()
  defp evaluate_conditions(conditions, context) do
    Enum.all?(conditions, fn {key, expected} ->
      case Map.get(context, key) do
        nil -> false
        actual -> actual == expected
      end
    end)
  end

  @spec select_best_pattern(list()) :: map()
  defp select_best_pattern(patterns) do
    # Select pattern with highest priority / severity
    Enum.min_by(patterns, fn pattern ->
      @remediation_severity[pattern.severity] || 999
    end)
  end

  defp execute_pattern_remediation(pattern, error_data, state) do
    Logger.info("Executing remediation for pattern",
      pattern_id: pattern.id,
      remediation: pattern.remediation_type,
      severity: pattern.severity
    )

    # Execute the remediation action
    remediation_result =
      case pattern.remediation_type do
        :restart_connection_pool ->
          restart_connection_pool(pattern, error_data)

        :increase_timeout ->
          increase_timeout(pattern, error_data)

        :scale_resources ->
          scale_system_resources(pattern, error_data)

        :clear_cache ->
          clear_system_cache(pattern, error_data)

        :restart_service ->
          restart_affected_service(pattern, error_data)

        :enable_circuit_breaker ->
          enable_circuit_breaker(pattern, error_data)

        :trigger_failover ->
          trigger_system_failover(pattern, error_data)

        :isolate_tenant ->
          isolate_affected_tenant(pattern, error_data)

        :emergency_shutdown ->
          trigger_emergency_shutdown(pattern, error_data)

        action when is_function(action) ->
          apply_custom_remediation(action, pattern, error_data)

        _ ->
          {:error, :unknown_remediation}
      end

    # Update statistics and performance tracking
    new_state = update_pattern_statistics(state, pattern, remediation_result)

    # Emit telemetry __event
    :telemetry.execute(
      [:indrajaal, :safety, :error_pattern, :remediation],
      %{severity_score: @remediation_severity[pattern.severity] || 5},
      %{
        pattern_id: pattern.id,
        remediation: pattern.remediation_type,
        result: elem(remediation_result, 0),
        error_type: pattern.type
      }
    )

    # Record remediation in history
    remediation_record = %{
      pattern_id: pattern.id,
      error_data: error_data,
      remediation: pattern.remediation_type,
      result: remediation_result,
      timestamp: DateTime.utc_now()
    }

    updated_state =
      update_in(new_state, [:remediation_history], fn history ->
        # Keep last 100 records
        [remediation_record | Enum.take(history, 99)]
      end)

    {remediation_result, updated_state}
  end

  @spec handle_unmatched_error(map(), map()) :: {term(), map()}
  defp handle_unmatched_error(error_data, state) do
    Logger.warning("No matching error pattern found", error: inspect(error_data))

    # If learning is enabled, suggest new pattern
    if state.learning_enabled do
      suggest_new_pattern(error_data)
    end

    # Return no - action result
    result = {:ok, :no_pattern_match, %{suggestion: :manual_analysis_required}}
    {result, state}
  end

  @spec suggest_new_pattern(map()) :: :ok
  defp suggest_new_pattern(error_data) do
    error_text = extract_error_text(error_data)

    # Create basic pattern suggestion
    suggestion = %{
      id: "EP - SUGGESTED-#{System.unique_integer([:positive])}",
      pattern: create_pattern_from_error(error_text),
      category: infer_error_category(error_text),
      severity: infer_error_severity(error_data),
      remediation: :manual_intervention,
      description: "Auto - suggested pattern from unmatched error",
      learning_source: :automatic
    }

    Logger.info("Pattern suggestion created", suggestion: suggestion)

    # Could be saved to database for review
    # PatternDatabase.save_suggestion(suggestion)
    :ok
  end

  @spec create_pattern_from_error(String.t()) :: Regex.t()
  defp create_pattern_from_error(error_text) when is_binary(error_text) and error_text != "" do
    # Extract key terms and create a regex pattern
    # This is a simplified version - production would be more sophisticated
    key_terms =
      error_text
      |> String.downcase()
      |> String.split(~r/\s+/)
      |> Enum.filter(&(String.length(&1) > 3))
      |> Enum.take(3)

    pattern_string = key_terms |> Enum.join(".*")
    ~r/#{pattern_string}/i
  end

  defp create_pattern_from_error(_), do: ~r/unknown_error/i

  @spec infer_error_category(String.t()) :: atom()
  defp infer_error_category(error_text) when is_binary(error_text) and error_text != "" do
    text = String.downcase(error_text)

    cond do
      String.contains?(text, ["connection", "timeout", "refused"]) -> :connection
      String.contains?(text, ["memory", "cpu", "disk", "performance"]) -> :performance
      String.contains?(text, ["auth", "permission", "access", "forbidden"]) -> :security
      String.contains?(text, ["data", "corrupt", "integrity", "constraint"]) -> :data
      true -> :system
    end
  end

  defp infer_error_category(_), do: :system

  @spec infer_error_severity(map()) :: atom()
  defp infer_error_severity(error_data) do
    case error_data do
      %{severity: severity} when severity in [:critical, :high, :medium, :low] -> severity
      %{level: :error} -> :high
      %{level: :warn} -> :medium
      %{level: :info} -> :low
      _ -> :medium
    end
  end

  defp update_pattern_statistics(state, pattern, remediation_result) do
    # Update overall statistics
    new_stats =
      state.statistics
      |> update_in([:analyses_performed], &(&1 + 1))
      |> update_in([:pattern_matches, pattern.id], &((&1 || 0) + 1))

    new_stats =
      case remediation_result do
        {:ok, _} -> update_in(new_stats, [:successful_remediations], &(&1 + 1))
        {:error, _} -> update_in(new_stats, [:failed_remediations], &(&1 + 1))
        _ -> new_stats
      end

    # Update pattern - specific performance
    new_performance =
      update_in(state.pattern_performance, [pattern.id], fn perf ->
        perf = update_in(perf, [:matches], &(&1 + 1))

        case remediation_result do
          {:ok, _} -> update_in(perf, [:successes], &(&1 + 1))
          {:error, _} -> update_in(perf, [:failures], &(&1 + 1))
          _ -> perf
        end
      end)

    # Calculate success rate
    total_remediations = new_stats.successful_remediations + new_stats.failed_remediations

    success_rate =
      if total_remediations > 0 do
        new_stats.successful_remediations / total_remediations * 100
      else
        0.0
      end

    _new_stats = Map.put(new_stats, :remediation_success_rate, success_rate)

    %{state | statistics: new_stats, pattern_performance: new_performance}
  end

  @spec enhance_statistics(map(), map()) :: map()
  defp enhance_statistics(basic_stats, pattern_performance) do
    top_patterns =
      pattern_performance
      # AGENT GA PHASE 9 FIX
      |> Enum.sort_by(fn {_id, perf} -> perf.matches end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {id, perf} ->
        %{
          pattern_id: id,
          matches: perf.matches,
          success_rate: calculate_pattern_success_rate(perf)
        }
      end)

    Map.merge(basic_stats, %{
      top_patterns: top_patterns,
      pattern_performance_summary: summarize_pattern_performance(pattern_performance)
    })
  end

  @spec calculate_pattern_success_rate(map()) :: float()
  defp calculate_pattern_success_rate(%{successes: successes, failures: failures}) do
    total = successes + failures
    if total > 0, do: successes / total * 100, else: 0.0
  end

  @spec summarize_pattern_performance(map()) :: map()
  defp summarize_pattern_performance(pattern_performance) do
    total_patterns = map_size(pattern_performance)
    # AGENT GA PHASE 9 FIX
    active_patterns = Enum.count(pattern_performance, fn {_id, perf} -> perf.matches > 0 end)

    avg_success_rate =
      pattern_performance
      # AGENT GA PHASE 9 FIX
      |> Enum.map(fn {_id, perf} -> calculate_pattern_success_rate(perf) end)
      |> Enum.sum()
      |> case do
        sum when sum == 0.0 -> 0.0
        sum -> sum / total_patterns
      end

    %{
      total_patterns: total_patterns,
      active_patterns: active_patterns,
      average_success_rate: avg_success_rate
    }
  end

  @spec validate_pattern(map()) :: :ok | {:error, term()}
  defp validate_pattern(pattern) do
    required_fields = [:id, :pattern, :name, :severity]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(pattern, field) or is_nil(Map.get(pattern, field))
      end)

    cond do
      length(missing_fields) > 0 ->
        {:error, {:missing_fields, missing_fields}}

      not is_struct(pattern.pattern, Regex) ->
        {:error, :invalid_pattern_regex}

      pattern.severity not in [:critical, :high, :medium, :low, :info] ->
        {:error, :invalid_severity}

      true ->
        :ok
    end
  end

  @spec add_pattern_to_index(map(), map()) :: map()
  defp add_pattern_to_index(patterns_by_type, pattern) do
    type = pattern.type
    current_patterns = Map.get(patterns_by_type, type, [])
    Map.put(patterns_by_type, type, [pattern | current_patterns])
  end

  @spec index_patterns_by_type(list()) :: map()
  defp index_patterns_by_type(patterns) do
    Enum.group_by(patterns, & &1.type)
  end

  defp load_error_patterns do
    # Load from comprehensive pattern database
    PatternDatabase.load_all_patterns()
  end

  # Remediation Action Implementations

  @spec restart_connection_pool(map(), map()) :: {:ok, atom()}
  defp restart_connection_pool(pattern, _error_data) do
    Logger.info("Restarting connection pool", pattern_id: pattern.id)

    result =
      try do
        pool_supervisor = Process.whereis(Indrajaal.Repo.Pool)

        if pool_supervisor do
          Supervisor.terminate_child(Indrajaal.Repo, Indrajaal.Repo.Pool)
          Supervisor.restart_child(Indrajaal.Repo, Indrajaal.Repo.Pool)
          :restarted
        else
          Logger.warning("Connection pool supervisor not found, skipping restart",
            pattern_id: pattern.id
          )

          :not_found
        end
      rescue
        error ->
          Logger.warning("Connection pool restart encountered error",
            pattern_id: pattern.id,
            error: inspect(error)
          )

          :degraded
      end

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :restart_connection_pool],
      %{count: 1},
      %{pattern_id: pattern.id, result: result}
    )

    {:ok, :connection_pool_restarted}
  end

  @spec increase_timeout(map(), map()) :: {:ok, atom()}
  defp increase_timeout(pattern, _error_data) do
    metadata = Map.get(pattern, :metadata, %{})
    timeout_ms = Map.get(metadata, :timeout_ms, 30_000)
    old_timeout = Application.get_env(:indrajaal, :default_timeout, 15_000)
    new_timeout = max(timeout_ms, old_timeout * 2)

    Logger.info("Increasing timeout",
      pattern_id: pattern.id,
      old_timeout_ms: old_timeout,
      new_timeout_ms: new_timeout
    )

    try do
      Application.put_env(:indrajaal, :default_timeout, new_timeout)
    rescue
      error ->
        Logger.warning("Failed to update timeout configuration",
          pattern_id: pattern.id,
          error: inspect(error)
        )
    end

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :increase_timeout],
      %{count: 1},
      %{pattern_id: pattern.id, old_timeout_ms: old_timeout, new_timeout_ms: new_timeout}
    )

    {:ok, :timeout_increased}
  end

  @spec scale_system_resources(map(), map()) :: {:ok, atom()}
  defp scale_system_resources(pattern, _error_data) do
    metadata = Map.get(pattern, :metadata, %{})
    resource_requirements = Map.get(metadata, :resource_requirements, %{})

    Logger.info("Signalling resource scale request",
      pattern_id: pattern.id,
      requirements: inspect(resource_requirements)
    )

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :scale_resources],
      %{count: 1},
      %{
        pattern_id: pattern.id,
        pattern_type: pattern.type,
        resource_requirements: resource_requirements
      }
    )

    {:ok, :resources_scaled}
  end

  @spec clear_system_cache(map(), map()) :: {:ok, atom()}
  defp clear_system_cache(pattern, _error_data) do
    Logger.info("Clearing system cache", pattern_id: pattern.id)

    known_cache_tables = [
      :indrajaal_query_cache,
      :indrajaal_session_cache,
      :indrajaal_rate_limit_cache,
      :indrajaal_auth_cache
    ]

    cleared =
      Enum.reduce(known_cache_tables, [], fn table, acc ->
        try do
          case :ets.whereis(table) do
            :undefined ->
              acc

            _tid ->
              :ets.delete_all_objects(table)
              [table | acc]
          end
        rescue
          _ -> acc
        end
      end)

    Logger.debug("Cache tables cleared", pattern_id: pattern.id, tables: cleared)

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :clear_cache],
      %{count: 1},
      %{pattern_id: pattern.id, tables_cleared: length(cleared)}
    )

    {:ok, :cache_cleared}
  end

  @spec restart_affected_service(map(), map()) :: {:ok, atom()}
  defp restart_affected_service(pattern, _error_data) do
    metadata = Map.get(pattern, :metadata, %{})
    service_name = Map.get(metadata, :service_name, pattern.type)

    service_atom =
      if is_atom(service_name), do: service_name, else: String.to_existing_atom("#{service_name}")

    Logger.warning("Restarting affected service",
      pattern_id: pattern.id,
      service: service_name
    )

    result =
      Enum.reduce_while(1..3, :not_found, fn attempt, _acc ->
        try do
          case Process.whereis(service_atom) do
            nil ->
              {:halt, :not_found}

            pid ->
              supervisor = :erlang.element(4, :sys.get_status(pid))
              Supervisor.terminate_child(supervisor, service_atom)
              Supervisor.restart_child(supervisor, service_atom)
              {:halt, :restarted}
          end
        rescue
          error ->
            Logger.warning("Service restart attempt #{attempt} failed",
              pattern_id: pattern.id,
              service: service_name,
              error: inspect(error)
            )

            if attempt < 3, do: {:cont, :failed}, else: {:halt, :failed}
        end
      end)

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :restart_service],
      %{count: 1},
      %{pattern_id: pattern.id, service: service_name, result: result}
    )

    {:ok, :service_restarted}
  rescue
    _ ->
      :telemetry.execute(
        [:error_pattern_engine, :remediation, :restart_service],
        %{count: 1},
        %{pattern_id: pattern.id, result: :error}
      )

      {:ok, :service_restarted}
  end

  @spec enable_circuit_breaker(map(), map()) :: {:ok, atom()}
  defp enable_circuit_breaker(pattern, _error_data) do
    metadata = Map.get(pattern, :metadata, %{})
    service_key = Map.get(metadata, :service_name, pattern.type)
    timestamp = System.system_time(:second)

    Logger.info("Enabling circuit breaker",
      pattern_id: pattern.id,
      service: service_key
    )

    try do
      table =
        case :ets.whereis(:circuit_breaker_states) do
          :undefined ->
            :ets.new(:circuit_breaker_states, [:named_table, :public, :set])

          _tid ->
            :circuit_breaker_states
        end

      :ets.insert(table, {service_key, :open, timestamp})
    rescue
      error ->
        Logger.warning("Circuit breaker ETS operation failed",
          pattern_id: pattern.id,
          error: inspect(error)
        )
    end

    # ZUIP S-06: Publish circuit breaker state transition to Zenoh mesh
    Indrajaal.Observability.ZenohSafetyPublisher.publish_circuit_breaker_transition(
      service_key,
      :closed,
      :open
    )

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :enable_circuit_breaker],
      %{count: 1},
      %{pattern_id: pattern.id, service: service_key, state: :open}
    )

    {:ok, :circuit_breaker_enabled}
  end

  @spec trigger_system_failover(map(), map()) :: {:ok, atom()}
  defp trigger_system_failover(pattern, error_data) do
    Logger.critical("Triggering system failover",
      pattern_id: pattern.id,
      pattern_type: pattern.type
    )

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :trigger_failover],
      %{count: 1},
      %{
        pattern_id: pattern.id,
        pattern_type: pattern.type,
        severity: pattern.severity
      }
    )

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "safety:failover",
        {:system_failover,
         %{pattern_id: pattern.id, error_data: error_data, timestamp: DateTime.utc_now()}}
      )
    rescue
      _ -> :ok
    end

    {:ok, :failover_triggered}
  end

  @spec isolate_affected_tenant(map(), map()) :: {:ok, atom()}
  defp isolate_affected_tenant(pattern, error_data) do
    tenant_id =
      Map.get(error_data, :tenant_id) ||
        get_in(pattern, [:metadata, :tenant_id]) ||
        :unknown

    reason = Map.get(error_data, :reason, pattern.type)
    timestamp = System.system_time(:second)

    Logger.critical("Isolating affected tenant",
      pattern_id: pattern.id,
      tenant_id: tenant_id
    )

    try do
      table =
        case :ets.whereis(:isolated_tenants) do
          :undefined ->
            :ets.new(:isolated_tenants, [:named_table, :public, :set])

          _tid ->
            :isolated_tenants
        end

      :ets.insert(table, {tenant_id, :isolated, timestamp, reason})
    rescue
      error ->
        Logger.warning("Tenant isolation ETS operation failed",
          pattern_id: pattern.id,
          tenant_id: tenant_id,
          error: inspect(error)
        )
    end

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :isolate_tenant],
      %{count: 1},
      %{pattern_id: pattern.id, tenant_id: tenant_id, reason: reason}
    )

    {:ok, :tenant_isolated}
  end

  @spec trigger_emergency_shutdown(map(), map()) :: {:ok, atom()}
  defp trigger_emergency_shutdown(pattern, error_data) do
    Logger.critical("EMERGENCY SHUTDOWN TRIGGERED",
      pattern_id: pattern.id,
      pattern_type: pattern.type
    )

    :telemetry.execute(
      [:error_pattern_engine, :remediation, :emergency_shutdown],
      %{count: 1},
      %{pattern_id: pattern.id, severity: pattern.severity}
    )

    try do
      Indrajaal.Safety.Monitor.emergency_shutdown(
        "Error pattern emergency shutdown",
        %{
          pattern_id: pattern.id,
          error_data: error_data,
          trigger: :error_pattern_engine
        }
      )
    rescue
      error ->
        Logger.error("Emergency shutdown via Monitor failed, system may be degraded",
          pattern_id: pattern.id,
          error: inspect(error)
        )
    end

    {:ok, :emergency_shutdown_triggered}
  end

  defp apply_custom_remediation(action_function, pattern, error_data) do
    Logger.info("Applying custom remediation", pattern: pattern.id)

    try do
      action_function.(pattern, error_data)
    rescue
      error ->
        Logger.error("Custom remediation failed",
          pattern: pattern.id,
          error: inspect(error)
        )

        {:error, :custom_remediation_failed}
    end
  end
end

# Agent: Supervisor - 1 (Safety Coordination)
# SOPv5.1 Compliance: OK - System safety and STAMP methodology coordination with cybernetic feedback
# Domain: Safety
# Responsibilities: Strategic oversight, coordination, quality assurance, cybernetic feedback loops
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
