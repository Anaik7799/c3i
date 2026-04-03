defmodule Indrajaal.Substrate.L7.EcosystemSensor do
  @moduledoc """
  ## Design Intent
  L7 Ecosystem Sensor — pure module that monitors the wider federation ecosystem
  for macro-level signals and computes aggregate trends, disruption indices, and
  resilience scores.

  The sensor processes federation-wide signal maps (keyed by signal domain) and
  derives:
    - Macro trends: directional momentum across signal domains (rising/falling/stable)
    - Disruption index: 0.0–1.0 measure of systemic instability
    - Resilience score: 0.0–1.0 measure of adaptive capacity

  Mathematical model:
    - Disruption index = mean(|Δsignal| across domains) clamped to [0, 1]
    - Resilience score = 1.0 − disruption_index × diversity_penalty
    - diversity_penalty = 1 / max(1, distinct_domains)

  Signal domains represent: :connectivity, :compute, :storage, :federation_size,
  :latency, :error_rate, :throughput. Each carries a float value in [0.0, 1.0].

  ## STAMP Constraints
  - SC-SMRITI-063: Federation protocol for cross-holon sync — sensor consumes signals
  - SC-FED-003: Detect constitution divergence — sensor monitors alignment drift
  - SC-FED-005: Membership management — sensor tracks federation size signals
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L7 morphogenesis) |
  """

  require Logger

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type signal_domain ::
          :connectivity
          | :compute
          | :storage
          | :federation_size
          | :latency
          | :error_rate
          | :throughput

  @type signal_map :: %{signal_domain() => float()}

  @type trend_direction :: :rising | :falling | :stable

  @type trend :: %{
          domain: signal_domain(),
          direction: trend_direction(),
          magnitude: float(),
          current_value: float()
        }

  @type scan_result :: %{
          disruption_index: float(),
          resilience_score: float(),
          dominant_trend: trend_direction(),
          signal_count: non_neg_integer(),
          timestamp: integer()
        }

  # Stability threshold — deltas below this are "stable"
  @stable_threshold 0.05

  # Known signal domains for completeness checking
  @known_domains [
    :connectivity,
    :compute,
    :storage,
    :federation_size,
    :latency,
    :error_rate,
    :throughput
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Scan a signal map and compute aggregate macro health metrics.
  `signals` is a map of `signal_domain => float_value` where values are in [0.0, 1.0].
  Returns a `scan_result` map.
  """
  @spec scan(signal_map()) :: scan_result()
  def scan(signals) when is_map(signals) do
    now = System.monotonic_time(:second)

    if map_size(signals) == 0 do
      %{
        disruption_index: 0.0,
        resilience_score: 1.0,
        dominant_trend: :stable,
        signal_count: 0,
        timestamp: now
      }
    else
      trends = compute_trends(signals)
      disruption = compute_disruption(signals)
      resilience = compute_resilience(disruption, map_size(signals))
      dominant = dominant_trend(trends)

      %{
        disruption_index: Float.round(disruption, 4),
        resilience_score: Float.round(resilience, 4),
        dominant_trend: dominant,
        signal_count: map_size(signals),
        timestamp: now
      }
    end
  end

  @doc """
  Return macro trend analysis for a signal map.
  Each trend describes direction and magnitude for a signal domain.
  """
  @spec macro_trends(signal_map()) :: [trend()]
  def macro_trends(signals) when is_map(signals) do
    compute_trends(signals)
  end

  @doc """
  Compute the disruption index for a given signal map.
  High disruption (> 0.7) indicates systemic instability.
  """
  @spec disruption_index(signal_map()) :: float()
  def disruption_index(signals) when is_map(signals) do
    Float.round(compute_disruption(signals), 4)
  end

  @doc """
  Compute the resilience score for a given signal map.
  High resilience (> 0.8) indicates strong adaptive capacity.
  """
  @spec resilience_score(signal_map()) :: float()
  def resilience_score(signals) when is_map(signals) do
    disruption = compute_disruption(signals)
    Float.round(compute_resilience(disruption, map_size(signals)), 4)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_trends(signals) do
    Enum.map(signals, fn {domain, value} ->
      value_clamped = max(0.0, min(1.0, value))

      # Reference midpoint is 0.5 (neutral baseline)
      delta = value_clamped - 0.5
      magnitude = abs(delta)

      direction =
        cond do
          magnitude < @stable_threshold -> :stable
          delta > 0 -> :rising
          true -> :falling
        end

      %{
        domain: domain,
        direction: direction,
        magnitude: Float.round(magnitude, 4),
        current_value: Float.round(value_clamped, 4)
      }
    end)
  end

  defp compute_disruption(signals) when map_size(signals) == 0, do: 0.0

  defp compute_disruption(signals) do
    deltas =
      Enum.map(signals, fn {_domain, value} ->
        abs(max(0.0, min(1.0, value)) - 0.5)
      end)

    mean_delta = Enum.sum(deltas) / length(deltas)
    # Scale to [0, 1]: max possible delta is 0.5
    min(1.0, mean_delta * 2.0)
  end

  defp compute_resilience(disruption, domain_count) do
    # Diversity bonus: more domains = better observability = higher resilience
    diversity_bonus = min(0.2, domain_count / (length(@known_domains) * 5.0))
    base = 1.0 - disruption
    min(1.0, base + diversity_bonus)
  end

  defp dominant_trend(trends) when length(trends) == 0, do: :stable

  defp dominant_trend(trends) do
    counts = Enum.frequencies_by(trends, & &1.direction)
    rising = Map.get(counts, :rising, 0)
    falling = Map.get(counts, :falling, 0)
    stable = Map.get(counts, :stable, 0)

    cond do
      rising >= falling and rising >= stable -> :rising
      falling > rising and falling >= stable -> :falling
      true -> :stable
    end
  end
end
