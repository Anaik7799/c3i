defmodule Indrajaal.Cybernetic.Inference.IntelligenceBenchmarker do
  @moduledoc """
  Intelligence Benchmarker: Driving Toward Universal Intelligence (Ω₀.6).

  WHAT: Compares internal Active Inference predictions against external Oracles.
  WHY: SC-FOUNDER-012 requires maximization of relative intelligence.
  CONSTRAINTS: MUST track prediction error delta relative to external benchmarks.
  """

  require Logger
  alias Indrajaal.Core.Holon.FounderDirective
  alias Indrajaal.Cybernetic.Inference.Prediction

  @doc """
  Benchmarks an internal prediction against an external oracle result.

  If internal error is LOWER than oracle error, the holon has 'Out-predicted'
  the external entity, resulting in an intelligence gain.
  """
  def benchmark(internal_pred, oracle_pred, actual_obs) do
    internal_error = Prediction.error(internal_pred, actual_obs).error
    oracle_error = Prediction.error(oracle_pred, actual_obs).error

    # Supremacy Delta: positive means we are more intelligent (less surprised)
    supremacy_delta = oracle_error - internal_error

    if supremacy_delta > 0 do
      Logger.info("Ω₀: Supremacy Advance! Out-predicted Oracle (Delta: #{supremacy_delta})")

      # Record in FounderDirective (Goal 2: Sentience -> Intelligence)
      FounderDirective.record_intelligence_gain(supremacy_delta, %{
        source: :adversarial_benchmark,
        internal_error: internal_error,
        oracle_error: oracle_error
      })
    end

    %{
      internal_error: internal_error,
      oracle_error: oracle_error,
      supremacy_delta: supremacy_delta
    }
  end
end
