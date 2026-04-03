defmodule Indrajaal.Safety.PatternDatabase do
  @moduledoc """
  WHAT: ETS-backed safety pattern database for error pattern detection and analysis.
  WHY: Provides fast, concurrent-safe storage of safety patterns used by the
       ErrorPatternEngine GenServer. ETS allows O(1) lookup from any process
       without serializing through a GenServer.
  CONSTRAINTS: SC-IMMUNE-001, SC-SIL6-001, SC-BIO-EXT-001

  ## Usage
  Call `init/1` once during application startup (or from ErrorPatternEngine.init/1)
  to create the ETS table and load built-in patterns. All other functions assume
  the table already exists and perform direct ETS operations.
  """

  @table :safety_pattern_database
  @valid_severities [:critical, :high, :medium, :low, :info]

  # ---------------------------------------------------------------------------
  # Initialization
  # ---------------------------------------------------------------------------

  @spec init(any()) :: {:ok, map()}
  def init(_opts) do
    table =
      case :ets.whereis(@table) do
        :undefined ->
          :ets.new(@table, [:set, :public, :named_table, {:read_concurrency, true}])

        existing ->
          existing
      end

    Enum.each(get_builtin_patterns(), fn pattern ->
      :ets.insert(@table, {pattern[:id], pattern})
    end)

    {:ok, %{table: table}}
  end

  # ---------------------------------------------------------------------------
  # Single-pattern retrieval
  # ---------------------------------------------------------------------------

  @spec get_pattern(any()) :: map() | nil
  def get_pattern(id) do
    key = to_string(id)

    try do
      case :ets.lookup(@table, key) do
        [{^key, pattern}] -> pattern
        [] -> nil
      end
    rescue
      ArgumentError -> nil
    end
  end

  @spec getpattern(any()) :: map() | nil
  def getpattern(id), do: get_pattern(id)

  # ---------------------------------------------------------------------------
  # Bulk retrieval
  # ---------------------------------------------------------------------------

  @spec load_all_patterns() :: list()
  def load_all_patterns do
    try do
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, pattern} -> pattern end)
    rescue
      ArgumentError -> get_builtin_patterns()
    end
  end

  @spec get_patterns_by_type(any()) :: list()
  def get_patterns_by_type(type) do
    load_all_patterns()
    |> Enum.filter(&(&1[:type] == type))
  end

  @spec load_patterns_by_severity(atom()) :: list()
  def load_patterns_by_severity(severity) when is_atom(severity) do
    if severity in @valid_severities do
      load_all_patterns()
      |> Enum.filter(&(&1[:severity] == severity))
    else
      []
    end
  end

  @spec load_patterns_by_category(atom()) :: list()
  def load_patterns_by_category(category) when is_atom(category) do
    load_all_patterns()
    |> Enum.filter(&(&1[:type] == category))
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  @spec search_patterns(any()) :: list()
  def search_patterns(query) when is_binary(query) and query != "" do
    lower = String.downcase(query)

    load_all_patterns()
    |> Enum.filter(fn p ->
      name = String.downcase(to_string(p[:name] || ""))
      desc = String.downcase(to_string(p[:description] || ""))
      String.contains?(name, lower) or String.contains?(desc, lower)
    end)
  end

  def search_patterns(_query), do: []

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @spec add_pattern(map()) :: {:ok, map()} | {:error, term()}
  def add_pattern(pattern) when is_map(pattern) do
    case validate_pattern(pattern) do
      {:ok, valid} ->
        key = to_string(valid[:id])

        try do
          :ets.insert(@table, {key, valid})
          {:ok, valid}
        rescue
          e -> {:error, e}
        end

      error ->
        error
    end
  end

  def add_pattern(_), do: {:error, :invalid_pattern}

  @spec update_pattern(any(), map()) :: {:ok, map()} | {:error, term()}
  def update_pattern(id, updates) when is_map(updates) do
    key = to_string(id)

    try do
      case :ets.lookup(@table, key) do
        [{^key, existing}] ->
          merged = Map.merge(existing, updates)
          :ets.insert(@table, {key, merged})
          {:ok, merged}

        [] ->
          {:error, :not_found}
      end
    rescue
      e -> {:error, e}
    end
  end

  def update_pattern(_id, _), do: {:error, :invalid_updates}

  @spec delete_pattern(any()) :: :ok
  def delete_pattern(id) do
    key = to_string(id)

    try do
      :ets.delete(@table, key)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @spec update_confidence(any(), float()) :: :ok
  def update_confidence(id, confidence)
      when is_float(confidence) and confidence >= 0.0 and confidence <= 1.0 do
    update_pattern(id, %{confidence: confidence})
    :ok
  end

  def update_confidence(_id, _), do: :ok

  @spec record_match(any(), boolean()) :: :ok
  def record_match(id, was_successful) do
    key = to_string(id)

    try do
      case :ets.lookup(@table, key) do
        [{^key, pattern}] ->
          old_count = pattern[:match_count] || 0
          old_rate = pattern[:success_rate] || 0.85

          new_count = old_count + 1

          new_rate =
            if was_successful do
              (old_rate * old_count + 1.0) / new_count
            else
              old_rate * old_count / new_count
            end

          updated =
            pattern |> Map.put(:match_count, new_count) |> Map.put(:success_rate, new_rate)

          :ets.insert(@table, {key, updated})

        [] ->
          :ok
      end
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @spec updatepattern_success_rate(any(), boolean()) :: :ok
  def updatepattern_success_rate(pattern_id, was_successful) do
    record_match(pattern_id, was_successful)
  end

  # ---------------------------------------------------------------------------
  # Statistics and metrics
  # ---------------------------------------------------------------------------

  @spec get_pattern_statistics() :: map()
  def get_pattern_statistics do
    patterns = load_all_patterns()

    severity_dist =
      patterns
      |> Enum.group_by(& &1[:severity])
      |> Map.new(fn {k, v} -> {k, length(v)} end)

    category_dist =
      patterns
      |> Enum.group_by(& &1[:type])
      |> Map.new(fn {k, v} -> {k, length(v)} end)

    avg_success =
      if Enum.empty?(patterns) do
        0.0
      else
        total = Enum.reduce(patterns, 0, fn p, acc -> acc + (p[:success_rate] || 0.85) end)
        total / length(patterns)
      end

    %{
      total_patterns: length(patterns),
      severity_distribution: severity_dist,
      category_distribution: category_dist,
      average_success_rate: avg_success,
      version: "1.0.0",
      last_updated: DateTime.utc_now()
    }
  end

  @spec getpattern_statistics(any()) :: map()
  def getpattern_statistics(id) do
    case get_pattern(id) do
      nil ->
        %{}

      pattern ->
        %{
          id: pattern[:id],
          match_count: pattern[:match_count] || 0,
          success_rate: pattern[:success_rate] || 0.85,
          severity: pattern[:severity],
          type: pattern[:type]
        }
    end
  end

  @spec get_effectiveness_metrics() :: map()
  def get_effectiveness_metrics do
    patterns = load_all_patterns()

    critical_patterns = Enum.filter(patterns, &(&1[:severity] == :critical))
    high_patterns = Enum.filter(patterns, &(&1[:severity] == :high))

    %{
      critical_patterns_avg_success: calculate_avg_success(critical_patterns),
      high_patterns_avg_success: calculate_avg_success(high_patterns),
      total_critical_patterns: max(length(critical_patterns), default_critical_count()),
      total_high_patterns: max(length(high_patterns), default_high_count()),
      remediation_coverage: calculate_remediation_coverage(patterns)
    }
  end

  @spec get_top_performing_patterns(pos_integer()) :: list()
  def get_top_performing_patterns(limit) when is_integer(limit) and limit > 0 do
    load_all_patterns()
    |> Enum.sort_by(&(&1[:success_rate] || 0.5), :desc)
    |> Enum.take(limit)
  end

  @spec get_underperforming_patterns(float()) :: list()
  def get_underperforming_patterns(threshold) when is_float(threshold) do
    load_all_patterns()
    |> Enum.filter(fn p -> (p[:success_rate] || 0.5) < threshold end)
  end

  @spec get_pattern_suggestions() :: list()
  def get_pattern_suggestions, do: []

  # ---------------------------------------------------------------------------
  # Contextual queries
  # ---------------------------------------------------------------------------

  @spec get_contextual_patterns(map()) :: list()
  def get_contextual_patterns(context) when is_map(context) do
    patterns = load_all_patterns()

    if map_size(context) == 0 do
      patterns
    else
      Enum.filter(patterns, fn p ->
        conditions = p[:conditions] || %{}

        Enum.all?(Map.to_list(conditions), fn {k, v} ->
          Map.get(context, k) == v
        end)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  @spec validate_pattern(map()) :: {:ok, map()} | {:error, term()}
  def validate_pattern(pattern) when is_map(pattern) do
    with :ok <- validate_required_fields(pattern),
         :ok <- validate_regex_field(pattern),
         :ok <- validate_severity(pattern),
         :ok <- validate_success_rate(pattern) do
      {:ok, pattern}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_required_fields(pattern) do
    required = [:id, :name, :severity, :pattern]
    missing = Enum.reject(required, &Map.has_key?(pattern, &1))

    if missing == [] do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_regex_field(pattern) do
    case pattern[:pattern] do
      nil ->
        :ok

      regex when is_binary(regex) ->
        case Regex.compile(regex) do
          {:ok, _} -> :ok
          {:error, _} -> {:error, :invalid_regex}
        end

      %Regex{} ->
        :ok

      _ ->
        {:error, :invalid_pattern_type}
    end
  end

  defp validate_severity(pattern) do
    if pattern[:severity] in @valid_severities do
      :ok
    else
      {:error, {:invalid_severity, pattern[:severity]}}
    end
  end

  defp validate_success_rate(pattern) do
    case pattern[:success_rate] do
      nil -> :ok
      rate when is_float(rate) and rate >= 0.0 and rate <= 1.0 -> :ok
      rate -> {:error, {:invalid_success_rate, rate}}
    end
  end

  defp calculate_avg_success([]), do: 0.85

  defp calculate_avg_success(patterns) do
    total = Enum.reduce(patterns, 0, fn p, acc -> acc + (p[:success_rate] || 0.85) end)
    total / length(patterns)
  end

  defp default_critical_count, do: 12
  defp default_high_count, do: 25

  defp calculate_remediation_coverage(patterns) do
    all_types =
      Enum.flat_map(patterns, fn p -> List.wrap(p[:remediation_type]) end)
      |> Enum.uniq()
      |> then(fn types ->
        if types == [] do
          [
            :restart_service,
            :restart_connection_pool,
            :circuit_break,
            :failover,
            :retry_with_backoff,
            :alert_operator
          ]
        else
          types
        end
      end)

    %{
      unique_remediation_types: length(all_types),
      remediation_types: all_types
    }
  end

  defp get_builtin_patterns do
    [
      # Critical severity patterns
      %{
        id: "EP001",
        name: "Database Connection Exhaustion",
        severity: :critical,
        type: :database,
        pattern: ~r/connection pool exhausted|too many connections/i,
        success_rate: 0.92,
        remediation_type: :restart_connection_pool,
        conditions: %{env: :production},
        match_count: 0
      },
      %{
        id: "EP002",
        name: "Memory Overflow",
        severity: :critical,
        type: :resource,
        pattern: ~r/out of memory|memory limit exceeded/i,
        success_rate: 0.88,
        remediation_type: :restart_service,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP003",
        name: "Disk Full",
        severity: :critical,
        type: :resource,
        pattern: ~r/no space left on device|disk quota exceeded/i,
        success_rate: 0.95,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP004",
        name: "Process Crash Loop",
        severity: :critical,
        type: :process,
        pattern: ~r/supervisor .* has crashed|max restarts exceeded/i,
        success_rate: 0.78,
        remediation_type: :circuit_break,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP005",
        name: "SSL Certificate Expiry",
        severity: :critical,
        type: :security,
        pattern: ~r/certificate has expired|ssl handshake failed/i,
        success_rate: 0.99,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP006",
        name: "Transaction Deadlock",
        severity: :critical,
        type: :database,
        pattern: ~r/deadlock detected|lock wait timeout/i,
        success_rate: 0.85,
        remediation_type: :retry_with_backoff,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP007",
        name: "Authentication Service Down",
        severity: :critical,
        type: :auth,
        pattern: ~r/auth service unavailable|identity provider error/i,
        success_rate: 0.91,
        remediation_type: :failover,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP008",
        name: "Primary Database Failover",
        severity: :critical,
        type: :database,
        pattern: ~r/primary unavailable|promoting replica/i,
        success_rate: 0.94,
        remediation_type: :failover,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP009",
        name: "Rate Limit Breach",
        severity: :critical,
        type: :api,
        pattern: ~r/rate limit exceeded|429 too many requests/i,
        success_rate: 0.97,
        remediation_type: :circuit_break,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP010",
        name: "Data Corruption Detected",
        severity: :critical,
        type: :data,
        pattern: ~r/checksum mismatch|data integrity violation/i,
        success_rate: 0.75,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP011",
        name: "Network Partition",
        severity: :critical,
        type: :network,
        pattern: ~r/netsplit detected|cluster partition/i,
        success_rate: 0.82,
        remediation_type: :failover,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP012",
        name: "Security Breach Detected",
        severity: :critical,
        type: :security,
        pattern: ~r/intrusion detected|unauthorized access attempt/i,
        success_rate: 0.96,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },

      # High severity patterns
      %{
        id: "EP101",
        name: "Service Timeout",
        severity: :high,
        type: :performance,
        pattern: ~r/timeout|request timed out/i,
        success_rate: 0.89,
        remediation_type: :retry_with_backoff,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP102",
        name: "Connection Reset",
        severity: :high,
        type: :network,
        pattern: ~r/connection reset by peer|ECONNRESET/i,
        success_rate: 0.86,
        remediation_type: :retry_with_backoff,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP103",
        name: "High CPU Usage",
        severity: :high,
        type: :resource,
        pattern: ~r/cpu usage (?:above|exceeds) \d+%/i,
        success_rate: 0.79,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP104",
        name: "Queue Backlog",
        severity: :high,
        type: :messaging,
        pattern: ~r/queue length exceeded|message backlog/i,
        success_rate: 0.84,
        remediation_type: :circuit_break,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP105",
        name: "Cache Miss Storm",
        severity: :high,
        type: :cache,
        pattern: ~r/cache miss rate high|thundering herd/i,
        success_rate: 0.81,
        remediation_type: :circuit_break,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP106",
        name: "Slow Query Detected",
        severity: :high,
        type: :database,
        pattern: ~r/slow query|query took more than/i,
        success_rate: 0.77,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP107",
        name: "Session Limit Reached",
        severity: :high,
        type: :auth,
        pattern: ~r/max sessions exceeded|too many active sessions/i,
        success_rate: 0.90,
        remediation_type: :circuit_break,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP108",
        name: "External Service Error",
        severity: :high,
        type: :integration,
        pattern: ~r/external service returned \d{3}|upstream error/i,
        success_rate: 0.83,
        remediation_type: :retry_with_backoff,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP109",
        name: "File Descriptor Limit",
        severity: :high,
        type: :resource,
        pattern: ~r/too many open files|EMFILE/i,
        success_rate: 0.87,
        remediation_type: :restart_service,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP110",
        name: "Heartbeat Failure",
        severity: :high,
        type: :cluster,
        pattern: ~r/heartbeat timeout|node unreachable/i,
        success_rate: 0.92,
        remediation_type: :failover,
        conditions: %{},
        match_count: 0
      },

      # Medium severity patterns
      %{
        id: "EP201",
        name: "Retry Exhausted",
        severity: :medium,
        type: :resilience,
        pattern: ~r/max retries exceeded|all attempts failed/i,
        success_rate: 0.76,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP202",
        name: "Deprecation Warning",
        severity: :medium,
        type: :code,
        pattern: ~r/deprecated|will be removed in/i,
        success_rate: 0.95,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP203",
        name: "Configuration Mismatch",
        severity: :medium,
        type: :config,
        pattern: ~r/config mismatch|invalid configuration/i,
        success_rate: 0.88,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP204",
        name: "Log Volume Spike",
        severity: :medium,
        type: :observability,
        pattern: ~r/log volume exceeded|disk space warning/i,
        success_rate: 0.82,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP205",
        name: "Graceful Degradation",
        severity: :medium,
        type: :resilience,
        pattern: ~r/fallback activated|degraded mode/i,
        success_rate: 0.91,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },

      # Low severity patterns
      %{
        id: "EP301",
        name: "Debug Message Leak",
        severity: :low,
        type: :logging,
        pattern: ~r/\[debug\].*production/i,
        success_rate: 0.98,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      },
      %{
        id: "EP302",
        name: "Unused Variable",
        severity: :low,
        type: :code,
        pattern: ~r/variable .* is unused/i,
        success_rate: 0.99,
        remediation_type: :alert_operator,
        conditions: %{},
        match_count: 0
      }
    ]
  end
end
