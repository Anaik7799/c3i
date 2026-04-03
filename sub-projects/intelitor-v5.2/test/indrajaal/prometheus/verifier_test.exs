defmodule Indrajaal.Prometheus.VerifierTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Prometheus.Verifier

  @moduledoc """
  Formal Verification Tests for PROMETHEUS.
  Covers SC-PROM-001, SC-PROM-004, SC-GVF-003.
  """

  describe "verify_dag/1 (SC-PROM-004)" do
    test "accepts acyclic graph (linear)" do
      graph = %{
        "A" => ["B"],
        "B" => ["C"],
        "C" => []
      }

      assert {:ok, _sorted} = Verifier.verify_dag(graph)
    end

    test "accepts acyclic graph (diamond)" do
      graph = %{
        "A" => ["B", "C"],
        "B" => ["D"],
        "C" => ["D"],
        "D" => []
      }

      assert {:ok, _sorted} = Verifier.verify_dag(graph)
    end

    test "rejects cyclic graph (immediate cycle)" do
      graph = %{
        "A" => ["B"],
        "B" => ["A"]
      }

      assert {:error, :cycle_detected} = Verifier.verify_dag(graph)
    end

    test "rejects cyclic graph (long cycle)" do
      graph = %{
        "A" => ["B"],
        "B" => ["C"],
        "C" => ["A"]
      }

      assert {:error, :cycle_detected} = Verifier.verify_dag(graph)
    end
  end

  describe "verify_routing_graph/3 (SC-GVF-003)" do
    test "synapse can route to openrouter" do
      assert :ok = Verifier.verify_routing_graph(:synapse, "openai/gpt-4")
    end

    test "synapse cannot route directly to external AI" do
      assert {:error, {:constraint_violation, :inv_openrouter_exclusivity}} =
               Verifier.verify_routing_graph(:synapse, "gpt-4")
    end

    test "other sources are not restricted" do
      assert :ok = Verifier.verify_routing_graph(:admin, "gpt-4")
    end
  end

  describe "check_simplex_principle/2 (SC-NEURO-001)" do
    test "routes from guardian are approved" do
      assert :ok = Verifier.check_simplex_principle(:guardian, false)
    end

    test "routes from gde are approved" do
      assert :ok = Verifier.check_simplex_principle(:gde, false)
    end

    test "routes with guardian_approved flag are approved" do
      assert :ok = Verifier.check_simplex_principle(:synapse, true)
    end

    test "unapproved routes from synapse are rejected" do
      assert {:error, {:constraint_violation, :inv_simplex_principle}} =
               Verifier.check_simplex_principle(:synapse, false)
    end
  end

  describe "proof token issuance" do
    test "issue_proof/1 generates valid token" do
      claims = %{action: :test}
      token = Verifier.issue_proof(claims)

      assert %Verifier.ProofToken{} = token
      assert token.claims == claims
      assert is_binary(token.id)
      assert is_binary(token.signature)
      assert %DateTime{} = token.timestamp
    end
  end
end
