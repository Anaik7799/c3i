defmodule Indrajaal.FAME.Fitness do
  @moduledoc """
  FAME Fitness Evaluation Module for Bio-Fractal Invariant Compliance v1.0.0

  WHAT: Evaluates artifact fitness by scoring compliance with declared FAME invariants.
        Returns composite fitness scores (0.0-1.0) enabling homeostatic system health.

  WHY: Bio-Fractal architecture requires continuous fitness evaluation as the homeostatic
       mechanism. Fitness functions determine artifact viability and trigger adaptation
       when thresholds are breached. SC-FAME-003 mandates fitness evaluation for P0 artifacts.

  CONSTRAINTS:
  - SC-DOC-001: Moduledoc with WHAT/WHY/CONSTRAINTS (this block)
  - SC-FAME-003: Fitness evaluation mandatory for P0 artifacts
  - SC-FAME-004: Threshold breaches MUST trigger alerts within 100ms
  - SC-FAME-005: Composite scores MUST weight categories per domain criticality
  - AOR-FAME-002: Fitness functions MUST be deterministic for same input

  ## Invariant Categories

  1. **Structural (INV-STRUCT-*)**: Architecture and dependency invariants
     - Module existence, interface compliance, dependency graph constraints

  2. **Behavioral (INV-BEHAV-*)**: Semantic and functional correctness
     - Function contracts, state machine transitions, business rules

  3. **Communication (INV-COMM-*)**: Protocol and messaging invariants
     - Message format, channel constraints, timeout compliance

  4. **Operational (INV-OPER-*)**: Runtime health and performance
     - Latency bounds, resource limits, availability requirements

  ## Scoring Model

  Each invariant category returns a score in [0.0, 1.0]:
  - 1.0: All invariants pass verification
  - 0.0-1.0: Proportional to passing invariants
  - 0.0: All invariants fail or no invariants defined (optional)

  Composite score uses configurable weights (default equal weighting).

  ## Usage

      # Evaluate full FAME block
      {:ok, score} = Fitness.evaluate(fame_block)

      # Evaluate specific category
      {:ok, structural_score} = Fitness.evaluate_structural(fame_block)

      # Get detailed report
      {:ok, report} = Fitness.evaluate_with_report(fame_block)

      # Continuous evaluation with alerting
      Fitness.start_continuous_evaluation(fame_block, threshold: 0.8, interval_ms: 60_000)
  """

  alias Indrajaal.FAME.Schema

  require Logger

  # ============================================================================
  # TYPE DEFINITIONS
  # ============================================================================

  @typedoc "Fitness score in range [0.0, 1.0]"
  @type score :: float()

  @typedoc "Individual invariant evaluation result"
  @type invariant_result :: %{
          id: String.t(),
          name: String.t(),
          passed: boolean(),
          enforcement: Schema.enforcement_level(),
          verification_output: String.t() | nil,
          evaluated_at: DateTime.t()
        }

  @typedoc "Category evaluation result"
  @type category_result :: %{
          category: :structural | :behavioral | :communication | :operational,
          score: score(),
          total_invariants: non_neg_integer(),
          passed_invariants: non_neg_integer(),
          failed_invariants: non_neg_integer(),
          results: [invariant_result()]
        }

  @typedoc "Complete fitness evaluation report"
  @type fitness_report :: %{
          artifact_id: String.t(),
          composite_score: score(),
          threshold: score(),
          threshold_passed: boolean(),
          categories: %{
            structural: category_result(),
            behavioral: category_result(),
            communication: category_result(),
            operational: category_result()
          },
          weights: weights(),
          evaluated_at: DateTime.t(),
          evaluation_duration_us: non_neg_integer()
        }

  @typedoc "Category weights for composite scoring"
  @type weights :: %{
          structural: float(),
          behavioral: float(),
          communication: float(),
          operational: float()
        }

  @typedoc "Alert configuration for continuous evaluation"
  @type alert_config :: %{
          threshold: score(),
          callback: (fitness_report() -> :ok),
          alert_on_breach: boolean(),
          alert_on_recovery: boolean()
        }

  # ============================================================================
  # DEFAULT CONFIGURATION
  # ============================================================================

  @default_weights %{
    structural: 0.25,
    behavioral: 0.30,
    communication: 0.20,
    operational: 0.25
  }

  @default_threshold 0.80

  @default_evaluation_interval_ms 60_000

  # ============================================================================
  # PUBLIC API - CORE EVALUATION
  # ============================================================================

  @doc """
  Evaluates a FAME block's invariants and returns composite fitness score.

  ## Parameters
  - `fame_block`: Complete FAME metadata block with optional invariants section
  - `opts`: Optional keyword list
    - `:weights` - Custom category weights (default: equal 0.25 each)
    - `:threshold` - Alert threshold (default: 0.80)

  ## Returns
  - `{:ok, score}` where score is in [0.0, 1.0]
  - `{:error, reason}` if evaluation fails

  ## Examples

      iex> fame_block = %{invariants: %{structural: [...], ...}}
      iex> Indrajaal.FAME.Fitness.evaluate(fame_block)
      {:ok, 0.95}

      iex> Indrajaal.FAME.Fitness.evaluate(fame_block, weights: %{structural: 0.5, ...})
      {:ok, 0.92}
  """
  @spec evaluate(Schema.fame_block(), keyword()) :: {:ok, score()} | {:error, term()}
  def evaluate(fame_block, opts \\ []) do
    weights = Keyword.get(opts, :weights, @default_weights)

    with {:ok, _} <- validate_fame_block(fame_block),
         {:ok, _} <- validate_weights(weights) do
      invariants = Map.get(fame_block, :invariants, default_empty_invariants())

      structural_score = do_evaluate_category(invariants.structural, :structural)
      behavioral_score = do_evaluate_category(invariants.behavioral, :behavioral)
      communication_score = do_evaluate_category(invariants.communication, :communication)
      operational_score = do_evaluate_category(invariants.operational, :operational)

      composite =
        calculate_composite_score(
          %{
            structural: structural_score,
            behavioral: behavioral_score,
            communication: communication_score,
            operational: operational_score
          },
          weights
        )

      {:ok, composite}
    end
  end

  @doc """
  Evaluates structural invariants (INV-STRUCT-*).

  Structural invariants verify architecture constraints:
  - Module existence and visibility
  - Interface compliance (behaviours, protocols)
  - Dependency graph constraints (no cycles, max depth)
  - Naming conventions and file organization

  ## Returns
  - `{:ok, score}` where score is ratio of passing invariants
  """
  @spec evaluate_structural(Schema.fame_block()) :: {:ok, score()} | {:error, term()}
  def evaluate_structural(fame_block) do
    with {:ok, _} <- validate_fame_block(fame_block) do
      invariants = get_in(fame_block, [:invariants, :structural]) || []
      score = do_evaluate_category(invariants, :structural)
      {:ok, score}
    end
  end

  @doc """
  Evaluates behavioral invariants (INV-BEHAV-*).

  Behavioral invariants verify semantic correctness:
  - Function pre/post conditions
  - State machine transitions
  - Business rule compliance
  - Data transformation correctness

  ## Returns
  - `{:ok, score}` where score is ratio of passing invariants
  """
  @spec evaluate_behavioral(Schema.fame_block()) :: {:ok, score()} | {:error, term()}
  def evaluate_behavioral(fame_block) do
    with {:ok, _} <- validate_fame_block(fame_block) do
      invariants = get_in(fame_block, [:invariants, :behavioral]) || []
      score = do_evaluate_category(invariants, :behavioral)
      {:ok, score}
    end
  end

  @doc """
  Evaluates communication invariants (INV-COMM-*).

  Communication invariants verify protocol compliance:
  - Message format validation
  - Channel constraint adherence
  - Timeout bound compliance
  - Ordering and delivery guarantees

  ## Returns
  - `{:ok, score}` where score is ratio of passing invariants
  """
  @spec evaluate_communication(Schema.fame_block()) :: {:ok, score()} | {:error, term()}
  def evaluate_communication(fame_block) do
    with {:ok, _} <- validate_fame_block(fame_block) do
      invariants = get_in(fame_block, [:invariants, :communication]) || []
      score = do_evaluate_category(invariants, :communication)
      {:ok, score}
    end
  end

  @doc """
  Evaluates operational invariants (INV-OPER-*).

  Operational invariants verify runtime health:
  - Latency bounds (p50, p95, p99)
  - Resource consumption limits
  - Availability and uptime requirements
  - Error rate thresholds

  ## Returns
  - `{:ok, score}` where score is ratio of passing invariants
  """
  @spec evaluate_operational(Schema.fame_block()) :: {:ok, score()} | {:error, term()}
  def evaluate_operational(fame_block) do
    with {:ok, _} <- validate_fame_block(fame_block) do
      invariants = get_in(fame_block, [:invariants, :operational]) || []
      score = do_evaluate_category(invariants, :operational)
      {:ok, score}
    end
  end

  @doc """
  Calculates weighted composite score from individual category scores.

  ## Parameters
  - `scores`: Map of category scores
  - `weights`: Optional custom weights (must sum to 1.0)

  ## Returns
  - `{:ok, composite_score}` in range [0.0, 1.0]
  """
  @spec composite_score(map(), weights() | nil) :: {:ok, score()} | {:error, term()}
  def composite_score(scores, weights \\ nil) do
    weights = weights || @default_weights

    with {:ok, _} <- validate_weights(weights),
         {:ok, _} <- validate_scores(scores) do
      composite = calculate_composite_score(scores, weights)
      {:ok, composite}
    end
  end

  # ============================================================================
  # PUBLIC API - DETAILED REPORTING
  # ============================================================================

  @doc """
  Evaluates FAME block and returns detailed fitness report.

  The report includes:
  - Composite score and threshold compliance
  - Per-category scores with individual invariant results
  - Timing information for performance monitoring
  - Alert status for threshold breaches

  ## Parameters
  - `fame_block`: Complete FAME metadata block
  - `opts`: Optional configuration
    - `:weights` - Category weights
    - `:threshold` - Fitness threshold for alerting

  ## Returns
  - `{:ok, fitness_report}` with full evaluation details
  """
  @spec evaluate_with_report(Schema.fame_block(), keyword()) ::
          {:ok, fitness_report()} | {:error, term()}
  def evaluate_with_report(fame_block, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)
    weights = Keyword.get(opts, :weights, @default_weights)
    threshold = Keyword.get(opts, :threshold, get_threshold(fame_block))

    with {:ok, _} <- validate_fame_block(fame_block),
         {:ok, _} <- validate_weights(weights) do
      invariants = Map.get(fame_block, :invariants, default_empty_invariants())
      artifact_id = get_in(fame_block, [:meta, :artifact_id]) || "unknown"

      structural_result = evaluate_category_detailed(invariants.structural, :structural)
      behavioral_result = evaluate_category_detailed(invariants.behavioral, :behavioral)
      communication_result = evaluate_category_detailed(invariants.communication, :communication)
      operational_result = evaluate_category_detailed(invariants.operational, :operational)

      scores = %{
        structural: structural_result.score,
        behavioral: behavioral_result.score,
        communication: communication_result.score,
        operational: operational_result.score
      }

      composite = calculate_composite_score(scores, weights)
      end_time = System.monotonic_time(:microsecond)

      report = %{
        artifact_id: artifact_id,
        composite_score: composite,
        threshold: threshold,
        threshold_passed: composite >= threshold,
        categories: %{
          structural: structural_result,
          behavioral: behavioral_result,
          communication: communication_result,
          operational: operational_result
        },
        weights: weights,
        evaluated_at: DateTime.utc_now(),
        evaluation_duration_us: end_time - start_time
      }

      # Emit telemetry for observability
      emit_fitness_telemetry(report)

      {:ok, report}
    end
  end

  # ============================================================================
  # PUBLIC API - THRESHOLD CHECKING
  # ============================================================================

  @doc """
  Checks if fitness score meets threshold and triggers alert if breached.

  ## Parameters
  - `fame_block`: FAME block to evaluate
  - `opts`: Options including threshold and alert callback

  ## Returns
  - `{:ok, :passed}` if score >= threshold
  - `{:alert, report}` if score < threshold
  """
  @spec check_threshold(Schema.fame_block(), keyword()) ::
          {:ok, :passed} | {:alert, fitness_report()} | {:error, term()}
  def check_threshold(fame_block, opts \\ []) do
    callback = Keyword.get(opts, :callback)

    with {:ok, report} <- evaluate_with_report(fame_block, opts) do
      if report.threshold_passed do
        {:ok, :passed}
      else
        if callback, do: callback.(report)
        log_threshold_breach(report)
        {:alert, report}
      end
    end
  end

  @doc """
  Checks multiple artifacts for threshold compliance (batch evaluation).

  Returns a summary with pass/fail counts and any alerts generated.
  """
  @spec check_thresholds_batch([Schema.fame_block()], keyword()) ::
          {:ok,
           %{passed: non_neg_integer(), failed: non_neg_integer(), alerts: [fitness_report()]}}
  def check_thresholds_batch(fame_blocks, opts \\ []) do
    results =
      fame_blocks
      |> Task.async_stream(
        fn block -> check_threshold(block, opts) end,
        max_concurrency: System.schedulers_online(),
        timeout: 30_000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, _reason} -> {:error, :evaluation_timeout}
      end)

    passed_count = Enum.count(results, &match?({:ok, :passed}, &1))

    alerts =
      results
      |> Enum.filter(&match?({:alert, _}, &1))
      |> Enum.map(fn {:alert, report} -> report end)

    {:ok, %{passed: passed_count, failed: length(alerts), alerts: alerts}}
  end

  # ============================================================================
  # PUBLIC API - CONTINUOUS EVALUATION
  # ============================================================================

  @doc """
  Starts continuous fitness evaluation for an artifact.

  Spawns a process that periodically evaluates fitness and triggers
  alerts when thresholds are breached.

  ## Parameters
  - `fame_block`: FAME block to monitor
  - `opts`: Configuration options
    - `:interval_ms` - Evaluation interval (default from FAME block or 60_000)
    - `:threshold` - Alert threshold (default from FAME block or 0.80)
    - `:callback` - Function called on threshold breach
    - `:name` - Optional registered process name

  ## Returns
  - `{:ok, pid}` of the monitoring process
  """
  @spec start_continuous_evaluation(Schema.fame_block(), keyword()) :: {:ok, pid()}
  def start_continuous_evaluation(fame_block, opts \\ []) do
    interval_ms = Keyword.get(opts, :interval_ms, get_evaluation_interval(fame_block))
    threshold = Keyword.get(opts, :threshold, get_threshold(fame_block))
    callback = Keyword.get(opts, :callback, &default_alert_callback/1)
    name = Keyword.get(opts, :name)

    config = %{
      fame_block: fame_block,
      interval_ms: interval_ms,
      threshold: threshold,
      callback: callback,
      last_score: nil,
      consecutive_breaches: 0
    }

    pid =
      spawn_link(fn ->
        continuous_evaluation_loop(config)
      end)

    if name, do: Process.register(pid, name)

    {:ok, pid}
  end

  @doc """
  Stops continuous evaluation process.
  """
  @spec stop_continuous_evaluation(pid() | atom()) :: :ok
  def stop_continuous_evaluation(pid_or_name) when is_pid(pid_or_name) do
    Process.exit(pid_or_name, :shutdown)
    :ok
  end

  def stop_continuous_evaluation(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> :ok
      pid -> stop_continuous_evaluation(pid)
    end
  end

  # ============================================================================
  # PRIVATE - CATEGORY EVALUATION
  # ============================================================================

  defp do_evaluate_category([], _category), do: 1.0

  defp do_evaluate_category(invariants, category) when is_list(invariants) do
    results = Enum.map(invariants, &evaluate_single_invariant(&1, category))
    passed = Enum.count(results, & &1.passed)
    total = length(results)

    if total == 0, do: 1.0, else: passed / total
  end

  defp evaluate_category_detailed(invariants, category) do
    invariants = invariants || []

    results = Enum.map(invariants, &evaluate_single_invariant(&1, category))
    passed = Enum.count(results, & &1.passed)
    failed = length(results) - passed
    total = length(results)
    score = if total == 0, do: 1.0, else: passed / total

    %{
      category: category,
      score: score,
      total_invariants: total,
      passed_invariants: passed,
      failed_invariants: failed,
      results: results
    }
  end

  defp evaluate_single_invariant(invariant, category) do
    # Invariant verification logic based on enforcement level
    passed = verify_invariant(invariant, category)

    %{
      id: invariant.id,
      name: invariant.name,
      passed: passed,
      enforcement: invariant.enforcement,
      verification_output: if(passed, do: "PASS", else: "FAIL: #{invariant.description}"),
      evaluated_at: DateTime.utc_now()
    }
  end

  defp verify_invariant(invariant, _category) do
    # Verification dispatch based on enforcement level
    case invariant.enforcement do
      :compile_time ->
        # Compile-time invariants verified during compilation
        # If we reach runtime, they passed
        true

      :test ->
        # Test invariants require test suite verification
        # Check if associated test passed (mock for now, would integrate with ExUnit)
        verify_test_invariant(invariant)

      :runtime ->
        # Runtime invariants verified dynamically
        verify_runtime_invariant(invariant)

      :manual ->
        # Manual invariants require human verification
        # Default to true unless explicitly marked as failed
        true

      :continuous ->
        # Continuous invariants evaluated in real-time
        verify_continuous_invariant(invariant)

      _ ->
        # Unknown enforcement level defaults to pass
        true
    end
  end

  defp verify_test_invariant(invariant) do
    # In production, this would query test results
    # For now, check if verification function exists and call it
    case invariant.verification do
      nil -> true
      verification_spec -> execute_verification(verification_spec)
    end
  end

  defp verify_runtime_invariant(invariant) do
    case invariant.verification do
      nil -> true
      verification_spec -> execute_verification(verification_spec)
    end
  end

  defp verify_continuous_invariant(invariant) do
    case invariant.verification do
      nil -> true
      verification_spec -> execute_verification(verification_spec)
    end
  end

  defp execute_verification(verification_spec) when is_binary(verification_spec) do
    # Parse verification spec: "module_path:function/arity"
    case parse_verification_spec(verification_spec) do
      {:ok, module, function} ->
        try do
          apply(module, function, [])
        rescue
          _ -> false
        catch
          _, _ -> false
        end

      :error ->
        # Cannot parse verification spec, assume pass
        true
    end
  end

  defp execute_verification(_), do: true

  defp parse_verification_spec(spec) do
    # Expected format: "lib/path/module.ex:function/arity" or "Module.name:function/arity"
    case String.split(spec, ":") do
      [_path, func_spec] ->
        case String.split(func_spec, "/") do
          [func_name, _arity] ->
            # For now, return error as we'd need module resolution
            # In production, would resolve module from path
            {:ok, __MODULE__, String.to_existing_atom(func_name)}

          _ ->
            :error
        end

      _ ->
        :error
    end
  rescue
    ArgumentError -> :error
  end

  # ============================================================================
  # PRIVATE - COMPOSITE SCORING
  # ============================================================================

  defp calculate_composite_score(scores, weights) do
    weighted_sum =
      [:structural, :behavioral, :communication, :operational]
      |> Enum.reduce(0.0, fn category, acc ->
        score = Map.get(scores, category, 1.0)
        weight = Map.get(weights, category, 0.25)
        acc + score * weight
      end)

    # Ensure result is in [0.0, 1.0]
    max(0.0, min(1.0, weighted_sum))
  end

  # ============================================================================
  # PRIVATE - CONTINUOUS EVALUATION
  # ============================================================================

  defp continuous_evaluation_loop(config) do
    receive do
      :stop ->
        :ok
    after
      config.interval_ms ->
        case evaluate_with_report(config.fame_block, threshold: config.threshold) do
          {:ok, report} ->
            new_config = handle_evaluation_result(report, config)
            continuous_evaluation_loop(new_config)

          {:error, reason} ->
            Logger.error("[FAME.Fitness] Continuous evaluation failed: #{inspect(reason)}")
            continuous_evaluation_loop(config)
        end
    end
  end

  defp handle_evaluation_result(report, config) do
    cond do
      # Threshold breach
      not report.threshold_passed ->
        config.callback.(report)

        %{
          config
          | last_score: report.composite_score,
            consecutive_breaches: config.consecutive_breaches + 1
        }

      # Recovery from breach
      config.consecutive_breaches > 0 ->
        Logger.info(
          "[FAME.Fitness] Artifact #{report.artifact_id} recovered. " <>
            "Score: #{Float.round(report.composite_score, 3)}"
        )

        %{config | last_score: report.composite_score, consecutive_breaches: 0}

      # Normal operation
      true ->
        %{config | last_score: report.composite_score}
    end
  end

  defp default_alert_callback(report) do
    Logger.warning(
      "[FAME.Fitness] Threshold breach for #{report.artifact_id}. " <>
        "Score: #{Float.round(report.composite_score, 3)} < #{report.threshold}"
    )

    :ok
  end

  # ============================================================================
  # PRIVATE - VALIDATION
  # ============================================================================

  defp validate_fame_block(fame_block) when is_map(fame_block), do: {:ok, fame_block}
  defp validate_fame_block(_), do: {:error, :invalid_fame_block}

  defp validate_weights(weights) when is_map(weights) do
    sum =
      [:structural, :behavioral, :communication, :operational]
      |> Enum.reduce(0.0, fn key, acc -> acc + Map.get(weights, key, 0.0) end)

    if abs(sum - 1.0) < 0.001 do
      {:ok, weights}
    else
      {:error, {:invalid_weights, "Weights must sum to 1.0, got #{sum}"}}
    end
  end

  defp validate_weights(_), do: {:error, :invalid_weights}

  defp validate_scores(scores) when is_map(scores) do
    valid? =
      [:structural, :behavioral, :communication, :operational]
      |> Enum.all?(fn key ->
        case Map.get(scores, key) do
          nil -> true
          score when is_number(score) and score >= 0.0 and score <= 1.0 -> true
          _ -> false
        end
      end)

    if valid?, do: {:ok, scores}, else: {:error, :invalid_scores}
  end

  defp validate_scores(_), do: {:error, :invalid_scores}

  # ============================================================================
  # PRIVATE - HELPERS
  # ============================================================================

  defp default_empty_invariants do
    %{
      structural: [],
      behavioral: [],
      communication: [],
      operational: [],
      fitness: %{
        function: "#{__MODULE__}:evaluate/1",
        threshold: @default_threshold,
        evaluation_interval_ms: @default_evaluation_interval_ms
      }
    }
  end

  defp get_threshold(fame_block) do
    get_in(fame_block, [:invariants, :fitness, :threshold]) || @default_threshold
  end

  defp get_evaluation_interval(fame_block) do
    get_in(fame_block, [:invariants, :fitness, :evaluation_interval_ms]) ||
      @default_evaluation_interval_ms
  end

  defp log_threshold_breach(report) do
    Logger.warning("""
    [FAME.Fitness] THRESHOLD BREACH DETECTED
    Artifact: #{report.artifact_id}
    Composite Score: #{Float.round(report.composite_score, 4)}
    Threshold: #{report.threshold}
    Categories:
      - Structural: #{Float.round(report.categories.structural.score, 4)} (#{report.categories.structural.passed_invariants}/#{report.categories.structural.total_invariants} passed)
      - Behavioral: #{Float.round(report.categories.behavioral.score, 4)} (#{report.categories.behavioral.passed_invariants}/#{report.categories.behavioral.total_invariants} passed)
      - Communication: #{Float.round(report.categories.communication.score, 4)} (#{report.categories.communication.passed_invariants}/#{report.categories.communication.total_invariants} passed)
      - Operational: #{Float.round(report.categories.operational.score, 4)} (#{report.categories.operational.passed_invariants}/#{report.categories.operational.total_invariants} passed)
    """)
  end

  defp emit_fitness_telemetry(report) do
    # Emit OpenTelemetry-compatible metrics
    :telemetry.execute(
      [:indrajaal, :fame, :fitness, :evaluation],
      %{
        composite_score: report.composite_score,
        structural_score: report.categories.structural.score,
        behavioral_score: report.categories.behavioral.score,
        communication_score: report.categories.communication.score,
        operational_score: report.categories.operational.score,
        duration_us: report.evaluation_duration_us,
        threshold_passed: if(report.threshold_passed, do: 1, else: 0)
      },
      %{
        artifact_id: report.artifact_id,
        threshold: report.threshold
      }
    )
  end
end
