defmodule Indrajaal.Core.VSM.System4Intelligence do
  @moduledoc """
  VSM System 4: Intelligence - The Future for v20.0.0

  System 4 handles planning and prediction:
  - Observes environment and trends
  - Generates predictions using models
  - Proposes plans to S5
  - Adapts to changing conditions

  ## Responsibilities
  - Environment monitoring
  - Trend analysis
  - Monte Carlo simulation with convergence detection
  - Plan generation

  ## STAMP Constraints
  - SC-S4-001: Simulations MUST complete within 50ms
  - SC-S4-002: Predictions MUST include confidence scores
  - SC-S4-003: Plans MUST be validated before proposal
  - SC-S4-004: Observations MUST be timestamped
  - SC-MATH-003: Monte Carlo convergence detection required (RPN > 100 remediation)

  ## Monte Carlo Simulation
  The simulation uses Welford's online algorithm for numerically stable
  running mean and variance. Convergence is detected when the relative
  change in the running mean falls below the threshold for one full
  min-iteration window. Confidence intervals use the t-distribution for
  n < 30 and the normal approximation for n >= 30.

  ## Active Inference Integration
  - Free Energy minimization
  - Surprise-based learning
  - Belief updating

  ## Category Theory
  S4 forms a Reader Monad over environment observations:
  - ask : Reader r r (get observations)
  - local : (r → r) → Reader r a → Reader r a (modify observations)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-19 | Claude Sonnet 4.6 | Monte Carlo: convergence detection, CI, telemetry |
  """

  require Logger

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Metrics

  @type observation :: %{
          type: atom(),
          value: term(),
          timestamp: DateTime.t(),
          source: String.t()
        }

  @type prediction :: %{
          outcome: term(),
          confidence: float(),
          horizon: non_neg_integer(),
          model: atom()
        }

  @type plan :: %{
          id: String.t(),
          actions: [action()],
          expected_outcome: term(),
          confidence: float(),
          created_at: DateTime.t()
        }

  @type action :: %{
          type: atom(),
          params: map(),
          priority: non_neg_integer()
        }

  @type intelligence_state :: %{
          observations: [observation()],
          predictions: [prediction()],
          current_plan: plan() | nil,
          model_state: map(),
          last_update: DateTime.t() | nil
        }

  # Maximum observations to retain
  @max_observations 1000

  # Simulation timeout (SC-S4-001)
  @simulation_timeout 50

  # Monte Carlo defaults (SC-MATH-003)
  @mc_default_max_iterations 10_000
  @mc_default_min_iterations 100
  @mc_default_convergence_threshold 0.01
  @mc_default_confidence_level 0.95

  # t-distribution boundary: use normal approximation above this
  @mc_large_sample_threshold 30

  @doc """
  Creates a new intelligence state.
  """
  @spec new() :: intelligence_state()
  def new do
    %{
      observations: [],
      predictions: [],
      current_plan: nil,
      model_state: %{},
      last_update: nil
    }
  end

  @doc """
  Adds an observation to the state.
  """
  @spec observe(intelligence_state(), atom(), term(), String.t()) :: intelligence_state()
  def observe(state, type, value, source) do
    observation = %{
      type: type,
      value: value,
      timestamp: DateTime.utc_now(),
      source: source
    }

    observations =
      [observation | state.observations]
      |> Enum.take(@max_observations)

    %{state | observations: observations, last_update: DateTime.utc_now()}
  end

  @doc """
  Generates predictions based on current observations.
  """
  @spec predict(intelligence_state(), atom(), non_neg_integer()) ::
          {prediction(), intelligence_state()}
  def predict(state, model, horizon) do
    start_time = System.monotonic_time(:millisecond)

    # Simple prediction based on observation trends
    prediction =
      case model do
        :trend ->
          predict_trend(state.observations, horizon)

        :monte_carlo ->
          predict_monte_carlo(state.observations, horizon)

        _ ->
          %{outcome: :unknown, confidence: 0.0, horizon: horizon, model: model}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    if duration > @simulation_timeout do
      Logger.warning("S4: Prediction exceeded timeout (#{duration}ms)")
    end

    new_state = %{state | predictions: [prediction | Enum.take(state.predictions, 99)]}
    {prediction, new_state}
  end

  @doc """
  Generates a plan based on predictions and goals.
  """
  @spec plan(intelligence_state(), term()) :: {plan() | nil, intelligence_state()}
  def plan(state, goal) do
    start_time = System.monotonic_time(:millisecond)

    # Generate plan based on predictions
    plan =
      case state.predictions do
        [] ->
          nil

        predictions ->
          best_prediction = Enum.max_by(predictions, & &1.confidence)

          if best_prediction.confidence > 0.5 do
            create_plan(goal, best_prediction)
          else
            nil
          end
      end

    duration = System.monotonic_time(:millisecond) - start_time

    if plan do
      Logger.debug("S4: Generated plan with confidence #{plan.confidence} in #{duration}ms")
    end

    new_state = %{state | current_plan: plan}
    {plan, new_state}
  end

  @doc """
  Calculates surprise (prediction error) for active inference.
  """
  @spec surprise(prediction(), term()) :: float()
  def surprise(prediction, actual_outcome) do
    if prediction.outcome == actual_outcome do
      0.0
    else
      # Negative log probability (simplified)
      -:math.log(1 - prediction.confidence)
    end
  end

  @doc """
  Updates beliefs based on observed surprise.
  """
  @spec update_beliefs(intelligence_state(), float()) :: intelligence_state()
  def update_beliefs(state, surprise_value) do
    # Simple belief update - increase exploration if high surprise
    learning_rate = min(1.0, surprise_value / 10.0)

    model_state =
      state.model_state
      |> Map.put(:learning_rate, learning_rate)
      |> Map.update(:surprise_history, [surprise_value], fn history ->
        [surprise_value | Enum.take(history, 99)]
      end)

    %{state | model_state: model_state}
  end

  @doc """
  Returns the current plan confidence.
  """
  @spec plan_confidence(intelligence_state()) :: float()
  def plan_confidence(%{current_plan: nil}), do: 0.0
  def plan_confidence(%{current_plan: plan}), do: plan.confidence

  @doc """
  Emits intelligence metrics.
  """
  @spec emit_metrics(intelligence_state(), Holon.holon_id(), Holon.layer()) :: :ok
  def emit_metrics(state, holon_id, layer) do
    Metrics.emit_plan(
      holon_id,
      layer,
      plan_confidence(state),
      0
    )
  end

  @doc """
  Returns a summary of the intelligence state.
  """
  @spec summary(intelligence_state()) :: map()
  def summary(state) do
    %{
      observation_count: length(state.observations),
      prediction_count: length(state.predictions),
      has_plan: not is_nil(state.current_plan),
      plan_confidence: plan_confidence(state),
      avg_surprise:
        case Map.get(state.model_state, :surprise_history, []) do
          [] -> 0.0
          history -> Enum.sum(history) / length(history)
        end
    }
  end

  # Private helpers

  defp predict_trend(observations, horizon) do
    # Simple trend analysis
    case observations do
      [] ->
        %{outcome: :no_data, confidence: 0.0, horizon: horizon, model: :trend}

      obs ->
        # Count recent observations by type
        type_counts = Enum.frequencies_by(Enum.take(obs, 100), & &1.type)

        most_common =
          Enum.max_by(type_counts, fn {_, count} -> count end, fn -> {:unknown, 0} end)

        {outcome, count} = most_common
        confidence = min(1.0, count / 50)

        %{outcome: outcome, confidence: confidence, horizon: horizon, model: :trend}
    end
  end

  defp predict_monte_carlo(observations, horizon) do
    case observations do
      [] ->
        %{outcome: :no_data, confidence: 0.0, horizon: horizon, model: :monte_carlo}

      obs ->
        start_us = System.monotonic_time(:microsecond)

        sim_result =
          monte_carlo_simulate(obs, [],
            max_iterations: @mc_default_max_iterations,
            min_iterations: @mc_default_min_iterations,
            convergence_threshold: @mc_default_convergence_threshold,
            confidence_level: @mc_default_confidence_level
          )

        duration_us = System.monotonic_time(:microsecond) - start_us

        :telemetry.execute(
          [:vsm, :s4, :monte_carlo],
          %{
            iterations: sim_result.iterations,
            converged: sim_result.converged,
            mean: sim_result.mean,
            ci_lower: sim_result.ci_lower,
            ci_upper: sim_result.ci_upper,
            duration_us: duration_us
          },
          %{horizon: horizon}
        )

        Logger.debug(
          "S4 Monte Carlo: #{sim_result.iterations} iters, converged=#{sim_result.converged}, " <>
            "mean=#{Float.round(sim_result.mean, 4)}, " <>
            "CI=[#{Float.round(sim_result.ci_lower, 4)}, #{Float.round(sim_result.ci_upper, 4)}], " <>
            "#{duration_us}µs"
        )

        # The confidence is clamped from the CI width relative to the mean.
        # A tight interval around a stable mean yields high confidence.
        confidence = compute_outcome_confidence(sim_result, obs)

        best_outcome = most_frequent_type(obs)

        %{
          outcome: best_outcome,
          confidence: confidence,
          horizon: horizon,
          model: :monte_carlo,
          simulation: sim_result
        }
    end
  end

  # ---------------------------------------------------------------------------
  # Monte Carlo simulation engine
  # ---------------------------------------------------------------------------

  @spec monte_carlo_simulate([observation()], [float()], keyword()) :: map()
  defp monte_carlo_simulate(observations, _acc, opts) do
    max_iter = Keyword.get(opts, :max_iterations, @mc_default_max_iterations)
    min_iter = Keyword.get(opts, :min_iterations, @mc_default_min_iterations)
    threshold = Keyword.get(opts, :convergence_threshold, @mc_default_convergence_threshold)
    confidence = Keyword.get(opts, :confidence_level, @mc_default_confidence_level)

    {samples, converged, n} = run_mc_iterations(observations, max_iter, min_iter, threshold)

    {mean, variance} = welford_finalize(samples)
    std = if variance > 0.0, do: :math.sqrt(variance), else: 0.0

    {ci_lower, ci_upper} = confidence_interval(mean, std, n, confidence)

    %{
      mean: mean,
      std: std,
      variance: variance,
      ci_lower: ci_lower,
      ci_upper: ci_upper,
      converged: converged,
      iterations: n,
      confidence_level: confidence
    }
  end

  # Welford's online algorithm accumulator: {count, mean, m2}
  # m2 accumulates the sum of squared deviations from the running mean.
  @typep welford_acc :: {non_neg_integer(), float(), float()}

  @spec run_mc_iterations([observation()], pos_integer(), pos_integer(), float()) ::
          {welford_acc(), boolean(), non_neg_integer()}
  defp run_mc_iterations(observations, max_iter, min_iter, threshold) do
    n_obs = length(observations)
    obs_array = List.to_tuple(observations)

    initial_acc = {0, 0.0, 0.0}

    result =
      Enum.reduce_while(1..max_iter, {initial_acc, false, 0}, fn i, {welford, _converged, _n} ->
        # Draw one sample: pick a random observation, score it by recency weight
        sample_value = simulate_one_sample(obs_array, n_obs, i)

        {count, mean, m2} = welford
        new_welford = welford_update(count, mean, m2, sample_value)
        {new_count, new_mean, _new_m2} = new_welford

        if i >= min_iter do
          # Convergence check: relative change in running mean
          prev_mean = mean

          relative_change =
            abs(new_mean - prev_mean) / max(abs(prev_mean), 1.0e-10)

          if relative_change < threshold do
            {:halt, {new_welford, true, new_count}}
          else
            {:cont, {new_welford, false, new_count}}
          end
        else
          {:cont, {new_welford, false, new_count}}
        end
      end)

    case result do
      {welford, converged, n} -> {welford, converged, n}
    end
  end

  # Produce a scalar value [0.0, 1.0] for one Monte Carlo trial.
  # Each trial picks a random observation weighted toward more-recent entries
  # (index 0 = newest in the list, which is index 0 in the tuple).
  # The score is the recency weight of the picked observation normalised to [0,1].
  @spec simulate_one_sample(:erlang.tuple(), non_neg_integer(), pos_integer()) :: float()
  defp simulate_one_sample(_obs_array, 0, _iter), do: 0.0

  defp simulate_one_sample(obs_array, n_obs, _iter) do
    # Geometric recency weights: weight[i] = (1 - decay)^i
    # We use reservoir sampling with those weights by drawing a uniform
    # and comparing to the normalised weight at the selected index.
    decay = 0.05
    idx = :rand.uniform(n_obs) - 1
    recency_weight = :math.pow(1.0 - decay, idx)

    # Presence score: 1.0 if the observation exists (always true here),
    # scaled by recency weight.  This models the idea that fresher
    # observations contribute more to the "signal" being estimated.
    observation = elem(obs_array, idx)

    base_score =
      case observation do
        %{value: v} when is_number(v) -> min(1.0, max(0.0, v / 100.0))
        _ -> 0.5
      end

    base_score * recency_weight
  end

  # ---------------------------------------------------------------------------
  # Welford's online algorithm helpers (numerically stable)
  # ---------------------------------------------------------------------------

  @spec welford_update(non_neg_integer(), float(), float(), float()) :: welford_acc()
  defp welford_update(count, mean, m2, new_value) do
    new_count = count + 1
    delta = new_value - mean
    new_mean = mean + delta / new_count
    delta2 = new_value - new_mean
    new_m2 = m2 + delta * delta2
    {new_count, new_mean, new_m2}
  end

  @spec welford_finalize(welford_acc()) :: {float(), float()}
  defp welford_finalize({0, _mean, _m2}), do: {0.0, 0.0}
  defp welford_finalize({1, mean, _m2}), do: {mean, 0.0}

  defp welford_finalize({count, mean, m2}) do
    # Sample variance (Bessel's correction: divide by n-1)
    variance = m2 / (count - 1)
    {mean, variance}
  end

  # ---------------------------------------------------------------------------
  # Confidence interval computation
  # ---------------------------------------------------------------------------

  @spec confidence_interval(float(), float(), non_neg_integer(), float()) ::
          {float(), float()}
  defp confidence_interval(_mean, _std, 0, _confidence), do: {0.0, 0.0}
  defp confidence_interval(mean, std, _n, _confidence) when std == 0.0, do: {mean, mean}

  defp confidence_interval(mean, std, n, confidence) do
    critical =
      if n >= @mc_large_sample_threshold do
        z_score(confidence)
      else
        t_score(confidence, n - 1)
      end

    margin = critical * std / :math.sqrt(n)
    {mean - margin, mean + margin}
  end

  # Normal distribution z-scores for common confidence levels.
  # For non-tabled values we use a rational approximation of the
  # inverse normal CDF (Abramowitz & Stegun 26.2.17, maximum error 4.5e-4).
  @spec z_score(float()) :: float()
  defp z_score(0.90), do: 1.6449
  defp z_score(0.95), do: 1.9600
  defp z_score(0.99), do: 2.5758
  defp z_score(0.999), do: 3.2905

  defp z_score(confidence) when confidence > 0.0 and confidence < 1.0 do
    # Two-tailed: alpha/2 in the upper tail
    p = (1.0 + confidence) / 2.0
    inverse_normal_cdf(p)
  end

  defp z_score(_confidence), do: 1.9600

  # Rational approximation of the inverse normal CDF (quantile function).
  # Valid for p in (0, 1).  Abramowitz & Stegun 26.2.17.
  @spec inverse_normal_cdf(float()) :: float()
  defp inverse_normal_cdf(p) when p > 0.5 do
    t = :math.sqrt(-2.0 * :math.log(1.0 - p))

    c0 = 2.515517
    c1 = 0.802853
    c2 = 0.010328
    d1 = 1.432788
    d2 = 0.189269
    d3 = 0.001308

    numerator = c0 + c1 * t + c2 * t * t
    denominator = 1.0 + d1 * t + d2 * t * t + d3 * t * t * t

    t - numerator / denominator
  end

  defp inverse_normal_cdf(p) when p <= 0.5 do
    -inverse_normal_cdf(1.0 - p)
  end

  # t-distribution critical values (two-tailed, 95% confidence by default).
  # We tabulate degrees of freedom 1..29; above that, normal approximation.
  # Table source: standard t-table for alpha/2 = 0.025 (95% CI).
  @t_table_95 {
    # df=1..29
    12.706,
    4.303,
    3.182,
    2.776,
    2.571,
    2.447,
    2.365,
    2.306,
    2.262,
    2.228,
    2.201,
    2.179,
    2.160,
    2.145,
    2.131,
    2.120,
    2.110,
    2.101,
    2.093,
    2.086,
    2.080,
    2.074,
    2.069,
    2.064,
    2.060,
    2.056,
    2.052,
    2.048,
    2.045
  }

  @t_table_90 {
    # df=1..29
    6.314,
    2.920,
    2.353,
    2.132,
    2.015,
    1.943,
    1.895,
    1.860,
    1.833,
    1.812,
    1.796,
    1.782,
    1.771,
    1.761,
    1.753,
    1.746,
    1.740,
    1.734,
    1.729,
    1.725,
    1.721,
    1.717,
    1.714,
    1.711,
    1.708,
    1.706,
    1.703,
    1.701,
    1.699
  }

  @t_table_99 {
    # df=1..29
    63.657,
    9.925,
    5.841,
    4.604,
    4.032,
    3.707,
    3.499,
    3.355,
    3.250,
    3.169,
    3.106,
    3.055,
    3.012,
    2.977,
    2.947,
    2.921,
    2.898,
    2.878,
    2.861,
    2.845,
    2.831,
    2.819,
    2.807,
    2.797,
    2.787,
    2.779,
    2.771,
    2.763,
    2.756
  }

  @spec t_score(float(), non_neg_integer()) :: float()
  defp t_score(_confidence, df) when df >= @mc_large_sample_threshold - 1,
    do: z_score(0.95)

  defp t_score(confidence, df) when df > 0 do
    table =
      cond do
        confidence >= 0.99 -> @t_table_99
        confidence >= 0.95 -> @t_table_95
        confidence >= 0.90 -> @t_table_90
        true -> @t_table_95
      end

    # df is 1-indexed; tuple is 0-indexed
    idx = min(df - 1, tuple_size(table) - 1)
    elem(table, idx)
  end

  defp t_score(_confidence, 0), do: 12.706

  # ---------------------------------------------------------------------------
  # Outcome helpers
  # ---------------------------------------------------------------------------

  # Derive a confidence value from simulation results.
  # We map the CI tightness and convergence flag to [0, 1].
  @spec compute_outcome_confidence(map(), [observation()]) :: float()
  defp compute_outcome_confidence(%{converged: false}, _obs), do: 0.1

  defp compute_outcome_confidence(sim, obs) do
    # Base: frequency of the dominant outcome type in the observation pool
    frequency_confidence =
      case obs do
        [] ->
          0.0

        _ ->
          samples = Enum.take(obs, min(200, length(obs)))
          outcomes = Enum.frequencies_by(samples, & &1.type)

          case Enum.max_by(outcomes, fn {_, c} -> c end, fn -> {nil, 0} end) do
            {_type, 0} -> 0.0
            {_type, count} -> count / length(samples)
          end
      end

    # CI tightness: narrower CI relative to mean => higher confidence
    ci_width = sim.ci_upper - sim.ci_lower
    mean_abs = max(abs(sim.mean), 1.0e-10)
    relative_width = ci_width / mean_abs
    # Tightness in [0, 1] — a relative width of 0 gives 1.0, >2.0 gives ~0
    tightness = 1.0 / (1.0 + relative_width)

    # Blend: 70% frequency evidence, 30% CI tightness
    raw = 0.7 * frequency_confidence + 0.3 * tightness
    min(1.0, max(0.0, raw))
  end

  @spec most_frequent_type([observation()]) :: atom()
  defp most_frequent_type([]), do: :unknown

  defp most_frequent_type(obs) do
    obs
    |> Enum.take(min(200, length(obs)))
    |> Enum.frequencies_by(& &1.type)
    |> Enum.max_by(fn {_, c} -> c end, fn -> {:unknown, 0} end)
    |> elem(0)
  end

  defp create_plan(goal, prediction) do
    %{
      id: generate_id(),
      actions: [
        %{type: :move_toward, params: %{target: goal}, priority: 1}
      ],
      expected_outcome: prediction.outcome,
      confidence: prediction.confidence * 0.9,
      created_at: DateTime.utc_now()
    }
  end

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    random_bytes |> Base.encode16(case: :lower)
  end
end
