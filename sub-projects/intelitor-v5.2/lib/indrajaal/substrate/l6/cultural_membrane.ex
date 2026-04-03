defmodule Indrajaal.Substrate.L6.CulturalMembrane do
  @moduledoc """
  ## Design Intent
  L6 Cultural Membrane — pure module controlling what information crosses the holon
  boundary based on trust level and content relevance. Implements acceptance/rejection
  filters that enforce information sovereignty.

  The membrane operates as a biological semipermeable barrier:
    - :impermeable — nothing crosses (trust < 0.3)
    - :selective   — only high-relevance content crosses (0.3 ≤ trust < 0.7)
    - :permeable   — all relevant content crosses (trust ≥ 0.7)
    - :open        — all content crosses (trust ≥ 0.95, for trusted allies)

  Rejection log is maintained in an ETS table (module-level, bounded to 1000 entries)
  for post-mortem analysis. The log is read-only from outside the module.

  Content is evaluated by relevance tags: content with relevance in the local interest
  set is admitted even at lower permeability; irrelevant content is rejected.

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions — membrane is read-only filter
  - SC-FED-002: Maintain node autonomy — inbound filtering preserves autonomy
  - SC-FED-003: Detect constitution divergence — constitution-critical content always passes
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L6 morphogenesis) |
  """

  require Logger

  # ETS table for rejection log (created lazily on first use)
  @rejection_log_table :cultural_membrane_rejections

  # Max rejection log entries
  @max_rejections 1_000

  # Relevance tags that are always admitted (constitutional content)
  @always_admit_tags [:constitution, :safety, :emergency, :guardian]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type permeability_level :: :impermeable | :selective | :permeable | :open

  @type content_item :: %{
          source_id: String.t(),
          category: atom(),
          relevance_tags: [atom()],
          sensitivity: :public | :internal | :confidential | :secret,
          payload: map()
        }

  @type filter_decision :: :accept | :reject

  @type rejection_entry :: %{
          content_id: String.t(),
          source_id: String.t(),
          reason: atom(),
          trust_score: float(),
          timestamp: integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Filter a content item based on trust_score and local interest tags.
  Returns `{:accept, item}` or `{:reject, reason}`.
  `local_interests` is the set of relevance tags this holon cares about.
  """
  @spec filter(content_item(), float()) :: {:accept, content_item()} | {:reject, atom()}
  def filter(item, trust_score)
      when is_map(item) and is_float(trust_score) do
    trust_clamped = max(0.0, min(1.0, trust_score))
    level = permeability_level(trust_clamped)

    decision = evaluate(item, level)

    case decision do
      :reject ->
        log_rejection(item, trust_clamped, :membrane_filtered)
        {:reject, :membrane_filtered}

      :accept ->
        {:accept, item}
    end
  end

  @doc """
  Return the permeability level configuration with thresholds.
  """
  @spec permeability() :: map()
  def permeability do
    %{
      impermeable: %{min_trust: 0.0, max_trust: 0.299, description: "Nothing crosses"},
      selective: %{min_trust: 0.3, max_trust: 0.699, description: "High-relevance only"},
      permeable: %{min_trust: 0.7, max_trust: 0.949, description: "All relevant content"},
      open: %{min_trust: 0.95, max_trust: 1.0, description: "All content (trusted ally)"},
      always_admit_tags: @always_admit_tags
    }
  end

  @doc """
  Determine whether a content item would be accepted at the given trust level,
  without logging the decision.
  """
  @spec accept?(content_item(), float()) :: boolean()
  def accept?(item, trust_score) when is_map(item) and is_float(trust_score) do
    trust_clamped = max(0.0, min(1.0, trust_score))
    level = permeability_level(trust_clamped)
    evaluate(item, level) == :accept
  end

  @doc """
  Return the bounded rejection log (up to 1000 most recent entries).
  """
  @spec rejected_log() :: [rejection_entry()]
  def rejected_log do
    ensure_table()

    :ets.tab2list(@rejection_log_table)
    |> Enum.map(fn {_id, entry} -> entry end)
    |> Enum.sort_by(& &1.timestamp, :desc)
    |> Enum.take(@max_rejections)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec permeability_level(float()) :: permeability_level()
  defp permeability_level(trust) do
    cond do
      trust >= 0.95 -> :open
      trust >= 0.7 -> :permeable
      trust >= 0.3 -> :selective
      true -> :impermeable
    end
  end

  @spec evaluate(content_item(), permeability_level()) :: filter_decision()
  defp evaluate(item, level) do
    tags = Map.get(item, :relevance_tags, [])

    # Always admit constitutional/safety content
    if Enum.any?(tags, &(&1 in @always_admit_tags)) do
      :accept
    else
      do_evaluate(item, level)
    end
  end

  defp do_evaluate(_item, :impermeable), do: :reject

  defp do_evaluate(item, :selective) do
    # Only admit if item has at least one high-relevance tag
    tags = Map.get(item, :relevance_tags, [])
    sensitivity = Map.get(item, :sensitivity, :public)

    cond do
      sensitivity in [:confidential, :secret] -> :reject
      length(tags) > 0 -> :accept
      true -> :reject
    end
  end

  defp do_evaluate(item, :permeable) do
    sensitivity = Map.get(item, :sensitivity, :public)

    if sensitivity == :secret do
      :reject
    else
      :accept
    end
  end

  defp do_evaluate(_item, :open), do: :accept

  defp log_rejection(item, trust_score, reason) do
    ensure_table()

    id = :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
    now = System.monotonic_time(:second)

    entry = %{
      content_id: id,
      source_id: Map.get(item, :source_id, "unknown"),
      reason: reason,
      trust_score: trust_score,
      timestamp: now
    }

    # Bounded log — prune if too large
    size = :ets.info(@rejection_log_table, :size)

    if size >= @max_rejections do
      # Remove oldest entry
      oldest =
        :ets.tab2list(@rejection_log_table)
        |> Enum.min_by(fn {_id, e} -> e.timestamp end, fn -> nil end)

      case oldest do
        {old_id, _} -> :ets.delete(@rejection_log_table, old_id)
        _ -> :ok
      end
    end

    :ets.insert(@rejection_log_table, {id, entry})
  end

  defp ensure_table do
    if :ets.whereis(@rejection_log_table) == :undefined do
      :ets.new(@rejection_log_table, [:set, :public, :named_table, read_concurrency: true])
    end
  end
end
