defmodule Indrajaal.Smriti.Immune.SM2Algorithm do
  @moduledoc """
  L1 Immune System: SuperMemo-2 (SM2) Algorithm for Spaced Repetition.

  Determines the next review interval for knowledge Holons to ensure
  long-term retention and "immune" strength against forgetting.

  ## Algorithm
  1. I(1) := 1
  2. I(2) := 6
  3. for n > 2: I(n) := I(n-1) * EF
  where:
  - I(n) is the interval in days
  - EF is the easiness factor (default 2.5)
  - q is the quality of response (0-5)

  ## STAMP Constraints
  - SC-SMRITI-SRS-001: Interval MUST be non-negative
  - SC-SMRITI-SRS-002: EF MUST NOT drop below 1.3
  """

  @default_ef 2.5
  @min_ef 1.3

  @doc """
  Calculate the next interval and EF based on response quality.
  Returns %{interval: days, ef: float, repetition: integer}
  """
  def next_step(quality, repetition, previous_interval, previous_ef \\ @default_ef) do
    # Quality q: 0-5
    # 5: perfect response
    # 4: correct response after a hesitation
    # 3: correct response recalled with serious difficulty
    # 2: incorrect response; where the correct one seemed easy to recall
    # 1: incorrect response; the correct one remembered
    # 0: complete blackout.

    repetition = if quality >= 3, do: repetition + 1, else: 1

    interval =
      case repetition do
        1 -> 1
        2 -> 6
        _n -> round(previous_interval * previous_ef)
      end

    ef = calculate_ef(previous_ef, quality)

    %{
      interval: interval,
      ef: ef,
      repetition: repetition,
      next_review: DateTime.add(DateTime.utc_now(), interval, :day)
    }
  end

  defp calculate_ef(prev_ef, q) do
    # EF' := f(EF, q) = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    new_ef = prev_ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    max(@min_ef, new_ef) |> Float.round(2)
  end
end
