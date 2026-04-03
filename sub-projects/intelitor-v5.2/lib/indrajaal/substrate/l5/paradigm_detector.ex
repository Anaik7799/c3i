defmodule Indrajaal.Substrate.L5.ParadigmDetector do
  @moduledoc """
  L5 Paradigm Detector — Paradigm shift detection for strategic anticipation.

  Maintains a belief model about the current operating paradigm and detects
  when accumulated evidence suggests a paradigm shift is underway. Uses a
  Bayesian update rule to adjust paradigm belief with each new signal.

  Algorithm:
  - Belief update: posterior = likelihood × prior / evidence (simplified)
  - Shift signal: Kullback-Leibler divergence from initial belief distribution
  - Transition state: :stable, :shifting, :shifted

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy identity — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @shift_threshold 0.30
  @shifted_threshold 0.60
  @epsilon 1.0e-9

  @type transition :: :stable | :shifting | :shifted

  @type t :: %__MODULE__{
          paradigm: String.t(),
          initial_belief: float(),
          current_belief: float(),
          kl_divergence: float(),
          transition: transition(),
          signal_count: non_neg_integer()
        }

  defstruct paradigm: "default",
            initial_belief: 1.0,
            current_belief: 1.0,
            kl_divergence: 0.0,
            transition: :stable,
            signal_count: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    paradigm = Keyword.get(opts, :paradigm, "default")
    initial = Keyword.get(opts, :initial_belief, 1.0)

    cond do
      not is_binary(paradigm) ->
        {:error, "paradigm must be a string"}

      not is_number(initial) ->
        {:error, "initial_belief must be numeric"}

      initial <= 0.0 or initial > 1.0 ->
        {:error, "initial_belief must be in (0.0, 1.0]"}

      true ->
        start = initial / 1.0

        {:ok,
         %__MODULE__{
           paradigm: paradigm,
           initial_belief: start,
           current_belief: start
         }}
    end
  end

  @spec update(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def update(%__MODULE__{} = state, likelihood) when is_number(likelihood) do
    cond do
      likelihood < 0.0 or likelihood > 1.0 ->
        {:error, "likelihood must be in [0.0, 1.0]"}

      true ->
        # Bayesian update: posterior proportional to likelihood × prior
        raw = likelihood / 1.0 * state.current_belief
        new_belief = Float.round(max(@epsilon, min(1.0, raw)), 6)

        kl = kl_divergence(state.initial_belief, new_belief)

        transition =
          cond do
            kl >= @shifted_threshold -> :shifted
            kl >= @shift_threshold -> :shifting
            true -> :stable
          end

        {:ok,
         %{
           state
           | current_belief: new_belief,
             kl_divergence: kl,
             transition: transition,
             signal_count: state.signal_count + 1
         }}
    end
  end

  @spec shifting?(t()) :: boolean()
  def shifting?(%__MODULE__{transition: t}), do: t in [:shifting, :shifted]

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      paradigm: state.paradigm,
      initial_belief: state.initial_belief,
      current_belief: state.current_belief,
      kl_divergence: state.kl_divergence,
      transition: state.transition,
      signal_count: state.signal_count
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp kl_divergence(p, q) do
    p_safe = max(p, @epsilon)
    q_safe = max(q, @epsilon)
    Float.round(abs(p_safe * :math.log(p_safe / q_safe)), 6)
  end
end
