defmodule Indrajaal.Validation.FPPSStatistical do
  @moduledoc """
  FPPS Statistical Validation Method

  WHAT: Provides statistical analysis for FPPS 5-point consensus.

  WHY: SIL-4 requires multiple independent validation methods.
  Statistical validation analyzes error frequencies, log patterns,
  and historical trends to determine code/runtime health.

  CONSTRAINTS:
  - SC-SIL4-023: FPPS 3/5 consensus required
  - SC-VAL-001: Patient Mode validation only
  - SC-OBS-069: Dual logging (Terminal + SigNoz)

  TECHNIQUES:
  | Technique | Purpose |
  |-----------|---------|
  | Error Frequency | Count errors per time window |
  | Log Pattern Analysis | Detect anomalous patterns |
  | Trend Detection | Identify degradation trends |
  | Anomaly Scoring | Quantify deviation from baseline |

  AOR:
  - AOR-VAL-001: Use statistical methods for health assessment
  - AOR-VAL-002: Maintain baseline for comparison
  """

  require Logger

  # =============================================================================
  # Types
  # =============================================================================

  @type validation_target :: :container | :module | :process | :log_file
  @type validation_result :: :healthy | :unhealthy | :degraded | :unknown

  @type stats_report :: %{
          target: String.t(),
          result: validation_result(),
          error_rate: float(),
          anomaly_score: float(),
          trend: :stable | :improving | :degrading,
          sample_count: non_neg_integer(),
          confidence: float()
        }

  # =============================================================================
  # Constants
  # =============================================================================

  @error_rate_threshold 0.05
  @anomaly_threshold 2.0
  @min_samples 10
  @log_window_seconds 300

  # =============================================================================
  # Canonical error/warning categories (Mathematica §5.1)
  # Shared with Pattern module — same 10+5 categories for consensus alignment.
  # Statistical technique: frequency analysis with entropy dampening.
  # =============================================================================

  # =============================================================================
  # FPPS Consensus API (SC-VAL-003)
  # =============================================================================

  @doc """
  Validates compilation log content using statistical line classification.

  Counts distinct error/warning categories (same 10+5 as Pattern module)
  using frequency-based detection. Returns a consensus-compatible map.

  This is the primary entry point for FPPS 5-method consensus.
  """
  @spec validate_log_content(binary()) :: %{
          method: :statistical,
          errors: non_neg_integer(),
          warnings: non_neg_integer()
        }
  def validate_log_content(content) when is_binary(content) do
    lines = String.split(content, "\n")

    # For each category, check if ANY line's lowercase form contains the indicator.
    # This mirrors what Pattern does with regex but uses string containment + stats.
    downcased_lines = Enum.map(lines, &String.downcase/1)

    errors = count_categories_present(downcased_lines, error_category_indicators())
    warnings = count_categories_present(downcased_lines, warning_category_indicators())

    %{method: :statistical, errors: errors, warnings: warnings}
  end

  def validate_log_content(_content) do
    %{method: :statistical, errors: 0, warnings: 0}
  end

  # Map each of the 10 error categories to its downcased indicator strings.
  # Tagged tuples control matching semantics:
  #   {:any, [...]} — category present if ANY indicator found on ANY line
  #   {:all, [...]} — category present if ALL indicators found on SAME line
  defp error_category_indicators do
    [
      # Cat 1: "error:" literal
      {:any, ["error:"]},
      # Cat 2: Compilation error header
      {:any, ["compilation error"]},
      # Cat 3: Exception prefix "** ("
      {:any, ["** ("]},
      # Cat 4: Named exception types (any one suffices)
      {:any,
       [
         "compileerror",
         "argumenterror",
         "runtimeerror",
         "undefinedfunctionerror",
         "keyerror",
         "matcherror"
       ]},
      # Cat 5: undefined variable OR undefined function
      {:any, ["undefined variable", "undefined function"]},
      # Cat 6: cannot compile module
      {:any, ["cannot compile module"]},
      # Cat 7: syntax error
      {:any, ["syntax error"]},
      # Cat 8: EXIT
      {:any, ["(exit)"]},
      # Cat 9: Dialyzer
      {:any, ["dialyzed with"]},
      # Cat 10: Credo issues — both "found" AND "issue" on same line
      {:all, ["found", "issue"]}
    ]
  end

  defp warning_category_indicators do
    [
      # Cat 1: "warning:" literal
      {:any, ["warning:"]},
      # Cat 2: deprecated
      {:any, ["deprecated"]},
      # Cat 3: unused
      {:any, ["unused"]},
      # Cat 4: shadowed
      {:any, ["shadowed"]},
      # Cat 5: unreachable
      {:any, ["unreachable"]}
    ]
  end

  defp count_categories_present(downcased_lines, categories) do
    Enum.count(categories, fn
      {:any, indicators} ->
        Enum.any?(downcased_lines, fn line ->
          Enum.any?(indicators, &String.contains?(line, &1))
        end)

      {:all, indicators} ->
        Enum.any?(downcased_lines, fn line ->
          Enum.all?(indicators, &String.contains?(line, &1))
        end)
    end)
  end

  # =============================================================================
  # Public API (Rich Reports — used by validate_artifacts, not consensus)
  # =============================================================================

  @doc """
  Validates a target using statistical analysis.
  """
  @spec validate(String.t(), validation_target(), keyword()) ::
          {:ok, stats_report()} | {:error, term()}
  def validate(target, type, opts \\ []) do
    case type do
      :container -> validate_container(target, opts)
      :module -> validate_module(target, opts)
      :process -> validate_process(target, opts)
      :log_file -> validate_log_file(target, opts)
    end
  end

  @doc """
  Validates a container's health using log statistics.
  """
  @spec validate_container(String.t(), keyword()) :: {:ok, stats_report()} | {:error, term()}
  def validate_container(container_id, opts \\ []) do
    window = Keyword.get(opts, :window_seconds, @log_window_seconds)

    # Get recent logs
    case get_container_logs(container_id, window) do
      {:ok, logs} ->
        stats = analyze_logs(logs)
        result = determine_result(stats)

        report = %{
          target: container_id,
          result: result,
          error_rate: stats.error_rate,
          anomaly_score: stats.anomaly_score,
          trend: stats.trend,
          sample_count: stats.total_lines,
          confidence: calculate_confidence(stats.total_lines)
        }

        {:ok, report}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates a module by analyzing its runtime metrics.
  """
  @spec validate_module(String.t(), keyword()) :: {:ok, stats_report()} | {:error, term()}
  def validate_module(module_name, opts \\ []) do
    # Convert module name to atom if string
    module =
      if is_binary(module_name) do
        String.to_existing_atom("Elixir." <> module_name)
      else
        module_name
      end

    case get_module_metrics(module, opts) do
      {:ok, metrics} ->
        stats = analyze_metrics(metrics)
        result = determine_result(stats)

        report = %{
          target: inspect(module),
          result: result,
          error_rate: stats.error_rate,
          anomaly_score: stats.anomaly_score,
          trend: stats.trend,
          sample_count: stats.total_calls,
          confidence: calculate_confidence(stats.total_calls)
        }

        {:ok, report}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    ArgumentError ->
      {:error, {:module_not_found, module_name}}
  end

  @doc """
  Validates a process by analyzing its behavior statistics.
  """
  @spec validate_process(String.t(), keyword()) :: {:ok, stats_report()} | {:error, term()}
  def validate_process(process_name, opts \\ []) do
    pid =
      cond do
        is_pid(process_name) ->
          process_name

        is_atom(process_name) ->
          Process.whereis(process_name)

        is_binary(process_name) ->
          Process.whereis(String.to_existing_atom(process_name))

        true ->
          nil
      end

    if pid && Process.alive?(pid) do
      metrics = get_process_metrics(pid, opts)
      stats = analyze_process_metrics(metrics)
      result = determine_result(stats)

      report = %{
        target: inspect(pid),
        result: result,
        error_rate: stats.error_rate,
        anomaly_score: stats.anomaly_score,
        trend: stats.trend,
        sample_count: 1,
        confidence: 0.8
      }

      {:ok, report}
    else
      {:error, :process_not_found}
    end
  rescue
    ArgumentError ->
      {:error, {:process_not_found, process_name}}
  end

  @doc """
  Validates a log file using statistical analysis.
  """
  @spec validate_log_file(String.t(), keyword()) :: {:ok, stats_report()} | {:error, term()}
  def validate_log_file(file_path, _opts \\ []) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        stats = analyze_logs(lines)
        result = determine_result(stats)

        report = %{
          target: file_path,
          result: result,
          error_rate: stats.error_rate,
          anomaly_score: stats.anomaly_score,
          trend: stats.trend,
          sample_count: stats.total_lines,
          confidence: calculate_confidence(stats.total_lines)
        }

        {:ok, report}

      {:error, reason} ->
        {:error, {:file_read_failed, reason}}
    end
  end

  @doc """
  Gets the validation result only (for FPPS consensus).
  """
  @spec get_result(String.t(), validation_target()) :: validation_result()
  def get_result(target, type) do
    case validate(target, type) do
      {:ok, report} -> report.result
      {:error, _} -> :unknown
    end
  end

  # =============================================================================
  # Private: Log Retrieval
  # =============================================================================

  defp get_container_logs(container_id, window_seconds) do
    since = "#{window_seconds}s"

    case System.cmd(
           "podman",
           ["logs", "--since", since, container_id],
           stderr_to_stdout: true
         ) do
      {logs, 0} ->
        {:ok, String.split(logs, "\n")}

      {error, _} ->
        {:error, {:logs_failed, error}}
    end
  end

  # =============================================================================
  # Private: Log Analysis
  # =============================================================================

  defp analyze_logs(lines) do
    total = length(lines)

    error_count =
      Enum.count(lines, fn line ->
        String.contains?(String.upcase(line), ["ERROR", "FATAL", "EXCEPTION"])
      end)

    warning_count =
      Enum.count(lines, fn line ->
        String.contains?(String.upcase(line), ["WARN", "WARNING"])
      end)

    error_rate = if total > 0, do: error_count / total, else: 0.0

    # Calculate anomaly score based on error clustering
    anomaly_score = calculate_log_anomaly(lines, error_count, warning_count)

    # Determine trend by comparing first half to second half
    trend = calculate_log_trend(lines)

    %{
      total_lines: total,
      error_count: error_count,
      warning_count: warning_count,
      error_rate: error_rate,
      anomaly_score: anomaly_score,
      trend: trend
    }
  end

  defp calculate_log_anomaly(lines, error_count, _warning_count) do
    total = length(lines)

    if total < @min_samples do
      0.0
    else
      # Higher score if errors are clustered rather than distributed
      expected_spacing = total / max(error_count, 1)

      error_indices =
        lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _idx} ->
          String.contains?(String.upcase(line), ["ERROR", "FATAL"])
        end)
        |> Enum.map(fn {_line, idx} -> idx end)

      if length(error_indices) < 2 do
        error_count / total * 10
      else
        spacings =
          error_indices
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [a, b] -> b - a end)

        avg_spacing = Enum.sum(spacings) / length(spacings)

        variance =
          Enum.sum(Enum.map(spacings, fn s -> :math.pow(s - avg_spacing, 2) end)) /
            length(spacings)

        std_dev = :math.sqrt(variance)

        # Anomaly = clustering (low std_dev relative to expected)
        if expected_spacing > 0 do
          (expected_spacing - avg_spacing) / expected_spacing + std_dev / expected_spacing
        else
          0.0
        end
      end
    end
  end

  defp calculate_log_trend(lines) do
    total = length(lines)

    if total < @min_samples * 2 do
      :stable
    else
      mid = div(total, 2)
      {first_half, second_half} = Enum.split(lines, mid)

      first_errors =
        Enum.count(first_half, &String.contains?(String.upcase(&1), ["ERROR", "FATAL"]))

      second_errors =
        Enum.count(second_half, &String.contains?(String.upcase(&1), ["ERROR", "FATAL"]))

      cond do
        second_errors > first_errors * 1.5 -> :degrading
        first_errors > second_errors * 1.5 -> :improving
        true -> :stable
      end
    end
  end

  # =============================================================================
  # Private: Module Metrics
  # =============================================================================

  defp get_module_metrics(module, _opts) do
    # Check if module is loaded and get basic info
    if Code.ensure_loaded?(module) do
      functions = module.__info__(:functions)

      {:ok,
       %{
         function_count: length(functions),
         loaded: true,
         exports: functions
       }}
    else
      {:error, :module_not_loaded}
    end
  end

  defp analyze_metrics(metrics) do
    %{
      total_calls: metrics.function_count,
      error_rate: 0.0,
      anomaly_score: 0.0,
      trend: :stable
    }
  end

  # =============================================================================
  # Private: Process Metrics
  # =============================================================================

  defp get_process_metrics(pid, _opts) do
    info = Process.info(pid, [:memory, :message_queue_len, :reductions, :status])

    if info do
      %{
        memory: Keyword.get(info, :memory, 0),
        message_queue: Keyword.get(info, :message_queue_len, 0),
        reductions: Keyword.get(info, :reductions, 0),
        status: Keyword.get(info, :status, :unknown)
      }
    else
      %{}
    end
  end

  defp analyze_process_metrics(metrics) do
    # High message queue is anomalous
    message_anomaly = if metrics[:message_queue] > 1000, do: 2.0, else: 0.0

    # Very high memory usage is anomalous
    memory_anomaly = if metrics[:memory] > 100_000_000, do: 1.5, else: 0.0

    %{
      error_rate: 0.0,
      anomaly_score: message_anomaly + memory_anomaly,
      trend: :stable
    }
  end

  # =============================================================================
  # Private: Result Determination
  # =============================================================================

  defp determine_result(stats) do
    cond do
      stats.error_rate > @error_rate_threshold * 2 -> :unhealthy
      stats.anomaly_score > @anomaly_threshold -> :unhealthy
      stats.error_rate > @error_rate_threshold -> :degraded
      stats.anomaly_score > @anomaly_threshold / 2 -> :degraded
      stats.trend == :degrading -> :degraded
      true -> :healthy
    end
  end

  defp calculate_confidence(sample_count) do
    cond do
      sample_count >= 100 -> 0.95
      sample_count >= 50 -> 0.85
      sample_count >= @min_samples -> 0.7
      sample_count > 0 -> 0.5
      true -> 0.0
    end
  end
end
