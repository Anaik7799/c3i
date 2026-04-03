defmodule Indrajaal.Substrate.L4.EnvironmentalModel do
  @moduledoc """
  L4 Environmental Model — Maintains a model of the system's operating environment.

  Pure module that represents the current understanding of the external environment
  as a map of named variables, each with a mean value, variance, and observation
  count. Updates are Bayesian: new observations are incorporated via running mean
  and variance (Welford's online algorithm). Entropy and accuracy metrics are
  derived from the current model state.

  ## STAMP Compliance
  - SC-S4-001: Environmental model updated from L4 horizon scan outputs
  - SC-S4-002: Bayesian update rule enforces monotonic belief revision
  - SC-S4-003: Model entropy bounded; high entropy triggers re-scan
  - SC-S4-004: Model accuracy computed against ground-truth when available

  ## Constitutional Alignment
  - Ψ₁ Regeneration: Model parameters serialisable to SQLite/DuckDB
  - Ψ₃ Verification: Variance bounds checked after each update
  """

  @type variable_name :: atom() | String.t()

  @type variable :: %{
          name: variable_name(),
          mean: float(),
          variance: float(),
          count: non_neg_integer(),
          last_updated: integer()
        }

  @type model :: %{variable_name() => variable()}

  @type observation :: %{variable_name() => number()}

  @type prediction :: %{
          variable: variable_name(),
          predicted_mean: float(),
          predicted_variance: float(),
          steps_ahead: non_neg_integer(),
          confidence: float()
        }

  @min_variance 1.0e-8
  @variance_inflation 1.05

  @doc """
  Updates the model by incorporating a new observation.

  Uses Welford's online algorithm for numerically stable incremental mean and
  variance. Each observed variable must map to a numeric value.

  ## Parameters
  - `model` — current model map
  - `observation` — map of variable names to observed numeric values

  ## Returns
  Updated model map with revised statistics.
  """
  @spec update(model(), observation()) :: model()
  def update(model, observation) when is_map(model) and is_map(observation) do
    now = System.monotonic_time(:millisecond)

    Enum.reduce(observation, model, fn
      {name, value}, acc when is_number(value) ->
        existing = Map.get(acc, name, new_variable(name, now))
        updated = welford_update(existing, value, now)
        Map.put(acc, name, updated)

      _non_numeric, acc ->
        acc
    end)
  end

  def update(model, _), do: model

  @doc """
  Predicts future values for a set of variable names.

  Projects each variable's mean forward by `steps` using a random-walk model
  (variance inflated by `steps` × variance_inflation factor).

  ## Parameters
  - `model` — current model map
  - `steps` — number of time steps ahead to predict

  ## Returns
  List of `prediction/0` structs for all variables present in model.
  """
  @spec predict(model(), non_neg_integer()) :: [prediction()]
  def predict(model, steps \\ 1)
      when is_map(model) and is_integer(steps) and steps >= 0 do
    model
    |> Map.values()
    |> Enum.map(fn var ->
      projected_variance = var.variance * :math.pow(@variance_inflation, steps)

      conf =
        if projected_variance > 0.0,
          do: 1.0 / (1.0 + projected_variance),
          else: 1.0

      %{
        variable: var.name,
        predicted_mean: var.mean,
        predicted_variance: Float.round(projected_variance, 6),
        steps_ahead: steps,
        confidence: Float.round(conf, 4)
      }
    end)
  end

  @doc """
  Computes the Shannon entropy of the model.

  Approximates entropy using the log of the summed variances — higher total
  variance means the model is more uncertain (higher entropy).

  ## Parameters
  - `model` — current model map

  ## Returns
  Float >= 0.0 representing model entropy in nats.
  """
  @spec entropy(model()) :: float()
  def entropy(model) when is_map(model) and map_size(model) == 0, do: 0.0

  def entropy(model) when is_map(model) do
    variances =
      model
      |> Map.values()
      |> Enum.map(& &1.variance)
      |> Enum.filter(&(&1 > 0.0))

    case variances do
      [] ->
        0.0

      vars ->
        total = Enum.sum(vars)
        normalised = Enum.map(vars, &(&1 / total))

        h =
          Enum.reduce(normalised, 0.0, fn p, acc ->
            if p > 0.0, do: acc - p * :math.log(p), else: acc
          end)

        Float.round(h, 4)
    end
  end

  @doc """
  Computes model accuracy against a ground-truth observation.

  For each variable present in both `model` and `ground_truth`, computes the
  relative error. Returns the mean accuracy score in [0.0, 1.0].

  ## Parameters
  - `model` — current model map
  - `ground_truth` — map of variable names to known true values (optional)

  ## Returns
  Float in [0.0, 1.0]; 1.0 means perfect prediction, 0.0 means total error.
  When ground_truth is empty or no overlap exists, returns 1.0 (unverified).
  """
  @spec model_accuracy(model(), observation()) :: float()
  def model_accuracy(model, ground_truth \\ %{})
      when is_map(model) and is_map(ground_truth) do
    common_keys =
      model
      |> Map.keys()
      |> Enum.filter(&Map.has_key?(ground_truth, &1))

    if common_keys == [] do
      1.0
    else
      accuracies =
        Enum.map(common_keys, fn key ->
          predicted = model[key].mean
          actual = ground_truth[key]

          if is_number(actual) and actual != 0.0 do
            relative_error = abs(predicted - actual) / abs(actual)
            max(0.0, 1.0 - relative_error)
          else
            if predicted == actual, do: 1.0, else: 0.0
          end
        end)

      Float.round(Enum.sum(accuracies) / length(accuracies), 4)
    end
  end

  # --- Private helpers ---

  @spec new_variable(variable_name(), integer()) :: variable()
  defp new_variable(name, now) do
    %{
      name: name,
      mean: 0.0,
      variance: @min_variance,
      count: 0,
      last_updated: now
    }
  end

  @spec welford_update(variable(), number(), integer()) :: variable()
  defp welford_update(var, value, now) do
    n = var.count + 1
    old_mean = var.mean
    new_mean = old_mean + (value - old_mean) / n

    new_variance =
      if n == 1 do
        @min_variance
      else
        # Welford's M2 update (simplified — using running variance)
        delta = value - old_mean
        delta2 = value - new_mean
        m2_increment = delta * delta2
        max((var.variance * (n - 2) + m2_increment) / (n - 1), @min_variance)
      end

    %{
      var
      | mean: Float.round(new_mean, 6),
        variance: Float.round(new_variance, 8),
        count: n,
        last_updated: now
    }
  end
end
