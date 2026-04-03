defmodule Indrajaal.AI.OpenRouterPrometheusTest do
  use ExUnit.Case, async: true

  alias Indrajaal.AI.OpenRouterClient

  describe "PROMETHEUS verify_routing_graph/3" do
    test "approves valid Cortex to OpenRouter route" do
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.95,
          guardian_approved: true
        )

      assert result == {:ok, :verified}
    end

    test "rejects low confidence routes (SC-GVF-004)" do
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.5,
          guardian_approved: true
        )

      assert {:error, {:constraint_violation, :inv_confidence_threshold}} = result
    end

    test "rejects non-Guardian-approved routes (SC-NEURO-001)" do
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.95,
          guardian_approved: false
        )

      assert {:error, {:constraint_violation, :inv_simplex_principle}} = result
    end
  end

  describe "PROMETHEUS check_exclusivity_constraint/2" do
    test "allows proper OpenRouter format (provider/model)" do
      assert :ok =
               OpenRouterClient.check_exclusivity_constraint(
                 :synapse,
                 "anthropic/claude-3.5-sonnet"
               )
    end

    test "rejects direct external AI (SC-GVF-003)" do
      result =
        OpenRouterClient.check_exclusivity_constraint(
          :synapse,
          # No provider prefix
          "gpt-4"
        )

      assert {:error, {:constraint_violation, :inv_openrouter_exclusivity}} = result
    end

    test "non-synapse sources bypass exclusivity check" do
      assert :ok = OpenRouterClient.check_exclusivity_constraint(:cortex, "gpt-4")
      assert :ok = OpenRouterClient.check_exclusivity_constraint(:guardian, "gpt-4")
    end
  end

  describe "PROMETHEUS check_simplex_principle/2" do
    test "Guardian bypasses simplex check" do
      assert :ok = OpenRouterClient.check_simplex_principle(:guardian, false)
    end

    test "GDE bypasses simplex check" do
      assert :ok = OpenRouterClient.check_simplex_principle(:gde, false)
    end

    test "approved routes pass" do
      assert :ok = OpenRouterClient.check_simplex_principle(:cortex, true)
    end

    test "unapproved routes from non-trusted sources fail" do
      result = OpenRouterClient.check_simplex_principle(:cortex, false)
      assert {:error, {:constraint_violation, :inv_simplex_principle}} = result
    end
  end

  describe "PROMETHEUS get_routing_graph_state/0" do
    test "returns valid graph structure" do
      graph = OpenRouterClient.get_routing_graph_state()

      assert is_map(graph)
      assert :cortex in graph.nodes
      assert :synapse in graph.nodes
      assert :openrouter in graph.nodes
      assert :guardian in graph.nodes
      assert :gde in graph.nodes
      assert {:cortex, :synapse} in graph.edges
      assert {:synapse, :openrouter} in graph.edges
    end
  end

  describe "PROMETHEUS validate_routing_proposal/1" do
    test "accepts valid proposals" do
      proposal = %{
        source: :cortex,
        target: :openrouter,
        model: "anthropic/claude-3.5-sonnet",
        confidence: 0.95,
        guardian_approved: true
      }

      assert {:ok, ^proposal} = OpenRouterClient.validate_routing_proposal(proposal)
    end

    test "rejects proposals with missing keys" do
      proposal = %{source: :cortex, model: "anthropic/claude-3.5-sonnet"}

      result = OpenRouterClient.validate_routing_proposal(proposal)
      assert {:error, {:invalid_proposal, :missing_required_keys}} = result
    end
  end
end
