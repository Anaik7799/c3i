defmodule Indrajaal.Substrate.L4.OpportunityDetector do
  @moduledoc """
  L4 Opportunity Detector — Identifies growth and optimization opportunities.

  Scans system metrics for patterns indicating untapped potential:
  - Underutilized resources (CPU < 30%, memory < 40%)
  - Idle connections that could serve more traffic
  - Cache miss rates suggesting optimization potential
  - Federation peers offering complementary capabilities

  ## STAMP Constraints
  - SC-S4-001: S4 environmental scanning
  - SC-S4-002: Opportunity assessment
  """

  @type opportunity :: %{
          id: String.t(),
          category: :resource | :performance | :federation | :knowledge,
          description: String.t(),
          potential_gain: float(),
          effort: :low | :medium | :high,
          detected_at: DateTime.t()
        }

  @spec scan(map()) :: [opportunity()]
  def scan(metrics) do
    []
    |> scan_resources(metrics)
    |> scan_performance(metrics)
    |> scan_federation(metrics)
    |> Enum.sort_by(& &1.potential_gain, :desc)
  end

  @spec roi_score(opportunity()) :: float()
  def roi_score(opp) do
    effort_factor =
      case opp.effort do
        :low -> 1.0
        :medium -> 0.5
        :high -> 0.25
      end

    Float.round(opp.potential_gain * effort_factor, 3)
  end

  @spec top_opportunities(map(), non_neg_integer()) :: [opportunity()]
  def top_opportunities(metrics, n \\ 5) do
    scan(metrics)
    |> Enum.sort_by(&roi_score/1, :desc)
    |> Enum.take(n)
  end

  # ── Scanners ─────────────────────────────────────────────────────────

  defp scan_resources(opps, metrics) do
    cpu = Map.get(metrics, :cpu_pct, 50)
    mem = Map.get(metrics, :memory_pct, 50)

    opps
    |> maybe_add(cpu < 30, %{
      category: :resource,
      description: "CPU utilization at #{cpu}% — capacity for additional workloads",
      potential_gain: (30 - cpu) / 100,
      effort: :low
    })
    |> maybe_add(mem < 40, %{
      category: :resource,
      description: "Memory utilization at #{mem}% — room for in-memory caching",
      potential_gain: (40 - mem) / 100,
      effort: :medium
    })
  end

  defp scan_performance(opps, metrics) do
    cache_miss = Map.get(metrics, :cache_miss_rate, 0.0)
    avg_latency = Map.get(metrics, :avg_latency_ms, 0)

    opps
    |> maybe_add(cache_miss > 0.3, %{
      category: :performance,
      description:
        "Cache miss rate #{Float.round(cache_miss * 100, 1)}% — caching optimization possible",
      potential_gain: cache_miss * 0.5,
      effort: :medium
    })
    |> maybe_add(avg_latency > 100, %{
      category: :performance,
      description: "Average latency #{avg_latency}ms — optimization could reduce by 30-50%",
      potential_gain: min(0.5, avg_latency / 500),
      effort: :high
    })
  end

  defp scan_federation(opps, metrics) do
    peer_count = Map.get(metrics, :federation_peers, 0)
    idle_peers = Map.get(metrics, :idle_peers, 0)

    opps
    |> maybe_add(idle_peers > 0, %{
      category: :federation,
      description: "#{idle_peers} idle federation peers — distributed workload possible",
      potential_gain: idle_peers * 0.1,
      effort: :medium
    })
    |> maybe_add(peer_count == 0, %{
      category: :federation,
      description: "No federation peers — standalone mode limits resilience",
      potential_gain: 0.3,
      effort: :high
    })
  end

  defp maybe_add(opps, true, attrs) do
    id = :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
    opp = Map.merge(attrs, %{id: id, detected_at: DateTime.utc_now()})
    [opp | opps]
  end

  defp maybe_add(opps, false, _attrs), do: opps
end
