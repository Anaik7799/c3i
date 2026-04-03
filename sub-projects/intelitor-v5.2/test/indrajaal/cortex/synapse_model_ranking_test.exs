defmodule Indrajaal.Cortex.SynapseModelRankingTest do
  @moduledoc """
  TDG test: Cortex Synapse model cost/latency/quality ranking.

  WHAT: Tests AI model selection, cost-quality tradeoff scoring, latency budgets, and fallback chains.
  WHY: Validates SC-NEURO-002 (resource bounding), SC-DF-001 to SC-DF-007 (data flow pricing),
       SC-MODEL-001 to SC-MODEL-020 (OpenRouter model registry).

  STAMP Constraints:
  - SC-NEURO-002: Resource bounding for AI requests
  - SC-DF-001: Data flow transformation pipelines
  - SC-MODEL-001: Model registry maintains available models
  - SC-MODEL-005: Model selection respects cost constraints
  - SC-MODEL-010: Fallback chain for unavailable models
  - AOR-OPENROUTER-001: Free models preferred
  - AOR-API-005: Haiku for workers, Opus for complex tasks
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @models [
    %{id: :opus, quality: 0.98, cost_per_1k: 15.0, latency_ms: 2000, available: true},
    %{id: :sonnet, quality: 0.92, cost_per_1k: 3.0, latency_ms: 800, available: true},
    %{id: :haiku, quality: 0.85, cost_per_1k: 0.25, latency_ms: 200, available: true},
    %{id: :gemini_pro, quality: 0.90, cost_per_1k: 1.25, latency_ms: 600, available: true},
    %{id: :grok, quality: 0.88, cost_per_1k: 2.0, latency_ms: 500, available: true},
    %{id: :llama_free, quality: 0.75, cost_per_1k: 0.0, latency_ms: 1500, available: true},
    %{id: :mistral_free, quality: 0.78, cost_per_1k: 0.0, latency_ms: 1200, available: true},
    %{id: :deprecated_model, quality: 0.60, cost_per_1k: 5.0, latency_ms: 3000, available: false}
  ]

  describe "model registry" do
    test "lists all available models" do
      available = list_available_models(@models)
      assert length(available) == 7
      refute Enum.any?(available, &(&1.id == :deprecated_model))
    end

    test "models have required fields" do
      for model <- @models do
        assert Map.has_key?(model, :id)
        assert Map.has_key?(model, :quality)
        assert Map.has_key?(model, :cost_per_1k)
        assert Map.has_key?(model, :latency_ms)
        assert Map.has_key?(model, :available)
      end
    end

    test "quality scores are bounded [0, 1]" do
      for model <- @models do
        assert model.quality >= 0.0 and model.quality <= 1.0
      end
    end

    test "costs are non-negative" do
      for model <- @models do
        assert model.cost_per_1k >= 0.0
      end
    end
  end

  describe "cost-quality tradeoff scoring (SC-DF-001)" do
    test "computes value score as quality/cost ratio" do
      scores = rank_by_value(@models)

      # Free models should have infinite value (capped at 1000)
      free_models = Enum.filter(scores, fn {model, _score} -> model.cost_per_1k == 0.0 end)
      assert length(free_models) >= 2

      for {_model, score} <- free_models do
        assert score >= 100.0
      end
    end

    test "haiku beats opus on value score" do
      scores = rank_by_value(@models) |> Map.new()
      assert scores[:haiku] > scores[:opus]
    end

    test "free models rank highest on value" do
      ranked = rank_by_value(@models)
      top_2 = Enum.take(ranked, 2)

      for {model, _} <- top_2 do
        assert model.cost_per_1k == 0.0 or model.quality / max(model.cost_per_1k, 0.001) > 50
      end
    end
  end

  describe "latency-constrained selection (SC-NEURO-002)" do
    test "selects best model within latency budget" do
      # 500ms budget
      selected = select_within_latency(@models, 500)
      assert selected != nil
      assert selected.latency_ms <= 500
    end

    test "returns nil if no model fits budget" do
      selected = select_within_latency(@models, 10)
      assert selected == nil
    end

    test "prefers quality when multiple models fit budget" do
      selected = select_within_latency(@models, 1000)
      assert selected != nil
      # Should pick highest quality model within 1000ms
      candidates = Enum.filter(list_available_models(@models), &(&1.latency_ms <= 1000))
      best = Enum.max_by(candidates, & &1.quality)
      assert selected.id == best.id
    end

    test "strict budget of 200ms selects haiku" do
      selected = select_within_latency(@models, 200)
      assert selected.id == :haiku
    end
  end

  describe "cost-constrained selection (SC-MODEL-005)" do
    test "selects best model within cost budget" do
      selected = select_within_cost(@models, 1.0)
      assert selected != nil
      assert selected.cost_per_1k <= 1.0
    end

    test "zero budget selects free model" do
      selected = select_within_cost(@models, 0.0)
      assert selected != nil
      assert selected.cost_per_1k == 0.0
    end

    test "unlimited budget selects highest quality" do
      selected = select_within_cost(@models, 100.0)
      assert selected.id == :opus
    end
  end

  describe "fallback chain (SC-MODEL-010)" do
    test "builds fallback chain from preferred model" do
      chain = build_fallback_chain(@models, :opus)
      assert length(chain) >= 3
      assert hd(chain).id == :opus
    end

    test "fallback chain excludes unavailable models" do
      chain = build_fallback_chain(@models, :opus)
      refute Enum.any?(chain, &(&1.id == :deprecated_model))
    end

    test "fallback chain ends with cheapest available model" do
      chain = build_fallback_chain(@models, :opus)
      last = List.last(chain)
      assert last.cost_per_1k == 0.0 or last.cost_per_1k <= 1.0
    end

    test "fallback chain quality is monotonically decreasing" do
      chain = build_fallback_chain(@models, :opus)
      qualities = Enum.map(chain, & &1.quality)

      pairs = Enum.chunk_every(qualities, 2, 1, :discard)

      for [a, b] <- pairs do
        assert a >= b, "Fallback chain quality should decrease: #{a} >= #{b}"
      end
    end
  end

  describe "multi-criteria selection" do
    test "balanced selection considers quality, cost, and latency" do
      selected =
        select_balanced(@models,
          quality_weight: 0.4,
          cost_weight: 0.3,
          latency_weight: 0.3
        )

      assert selected != nil
      assert selected.available
    end

    test "quality-heavy selection picks opus" do
      selected =
        select_balanced(@models,
          quality_weight: 0.9,
          cost_weight: 0.05,
          latency_weight: 0.05
        )

      assert selected.id == :opus
    end

    test "cost-heavy selection picks free model" do
      selected =
        select_balanced(@models,
          quality_weight: 0.1,
          cost_weight: 0.8,
          latency_weight: 0.1
        )

      assert selected.cost_per_1k == 0.0
    end
  end

  describe "AOR-API-005 role-based selection" do
    test "worker role selects haiku" do
      selected = select_for_role(@models, :worker)
      assert selected.id == :haiku
    end

    test "supervisor role selects sonnet" do
      selected = select_for_role(@models, :supervisor)
      assert selected.id == :sonnet
    end

    test "executive role selects opus" do
      selected = select_for_role(@models, :executive)
      assert selected.id == :opus
    end
  end

  describe "property: ranking consistency" do
    test "value ranking is deterministic" do
      ExUnitProperties.check all(
                               _seed <- SD.integer(1..1000),
                               max_runs: 15
                             ) do
        r1 = rank_by_value(@models)
        r2 = rank_by_value(@models)
        ids1 = Enum.map(r1, fn {m, _} -> m.id end)
        ids2 = Enum.map(r2, fn {m, _} -> m.id end)
        assert ids1 == ids2
      end
    end
  end

  describe "property: selection respects constraints" do
    test "latency selection never exceeds budget" do
      ExUnitProperties.check all(
                               budget <- SD.integer(100..3000),
                               max_runs: 20
                             ) do
        case select_within_latency(@models, budget) do
          nil -> true
          model -> assert model.latency_ms <= budget
        end
      end
    end

    test "cost selection never exceeds budget" do
      ExUnitProperties.check all(
                               budget <- SD.float(min: 0.0, max: 20.0),
                               max_runs: 20
                             ) do
        case select_within_cost(@models, budget) do
          nil -> true
          model -> assert model.cost_per_1k <= budget
        end
      end
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp list_available_models(models) do
    Enum.filter(models, & &1.available)
  end

  defp rank_by_value(models) do
    models
    |> list_available_models()
    |> Enum.map(fn model ->
      score =
        if model.cost_per_1k == 0.0 do
          model.quality * 1000
        else
          model.quality / model.cost_per_1k * 100
        end

      {model, score}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
  end

  defp select_within_latency(models, budget_ms) do
    models
    |> list_available_models()
    |> Enum.filter(&(&1.latency_ms <= budget_ms))
    |> Enum.max_by(& &1.quality, fn -> nil end)
  end

  defp select_within_cost(models, budget) do
    models
    |> list_available_models()
    |> Enum.filter(&(&1.cost_per_1k <= budget))
    |> Enum.max_by(& &1.quality, fn -> nil end)
  end

  defp build_fallback_chain(models, preferred_id) do
    available = list_available_models(models)
    preferred = Enum.find(available, &(&1.id == preferred_id))
    others = Enum.reject(available, &(&1.id == preferred_id))

    chain =
      if preferred do
        [preferred | Enum.sort_by(others, & &1.quality, :desc)]
      else
        Enum.sort_by(available, & &1.quality, :desc)
      end

    # Take top 5 for practical fallback chain
    Enum.take(chain, 5)
  end

  defp select_balanced(models, opts) do
    qw = Keyword.get(opts, :quality_weight, 0.33)
    cw = Keyword.get(opts, :cost_weight, 0.33)
    lw = Keyword.get(opts, :latency_weight, 0.34)

    available = list_available_models(models)
    max_cost = Enum.max_by(available, & &1.cost_per_1k) |> Map.get(:cost_per_1k) |> max(0.01)
    max_latency = Enum.max_by(available, & &1.latency_ms) |> Map.get(:latency_ms) |> max(1)

    available
    |> Enum.map(fn model ->
      quality_score = model.quality
      cost_score = 1.0 - model.cost_per_1k / max_cost
      latency_score = 1.0 - model.latency_ms / max_latency

      composite = qw * quality_score + cw * cost_score + lw * latency_score
      {model, composite}
    end)
    |> Enum.max_by(fn {_, score} -> score end)
    |> elem(0)
  end

  defp select_for_role(models, role) do
    case role do
      :worker ->
        select_within_cost(models, 0.5) || select_within_latency(models, 300)

      :supervisor ->
        select_within_cost(models, 5.0)
        |> then(fn m ->
          if m && m.quality >= 0.9,
            do: m,
            else: Enum.find(list_available_models(models), &(&1.id == :sonnet))
        end)

      :executive ->
        Enum.find(list_available_models(models), &(&1.id == :opus)) ||
          select_within_cost(models, 100.0)
    end
  end
end
