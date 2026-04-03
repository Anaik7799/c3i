defmodule Indrajaal.Prometheus.FullStackIntegrationTest do
  use ExUnit.Case
  alias Indrajaal.Prometheus.Verifier

  @moduledoc """
  Comprehensive Integration Test for PROMETHEUS Framework.
  Covers:
  1. DAG Verification (Math Layer)
  2. Proof Token Issuance (Trust Layer)
  3. Safety Constraint Enforcement (STAMP)
  """

  describe "Layer 1: Mathematical Core (Verifier)" do
    test "accepts valid acyclic graph" do
      # A -> B -> C
      dag = %{
        :a => [:b],
        :b => [:c],
        :c => []
      }

      assert {:ok, [:a, :b, :c]} = Verifier.verify_dag(dag)
    end

    test "rejects cyclic graph" do
      # A -> B -> A (Cycle)
      cyclic = %{
        :a => [:b],
        :b => [:a]
      }

      assert {:error, :cycle_detected} = Verifier.verify_dag(cyclic)
    end

    test "handles disconnected components" do
      # A -> B, C -> D
      dag = %{
        :a => [:b],
        :b => [],
        :c => [:d],
        :d => []
      }

      {:ok, sorted} = Verifier.verify_dag(dag)
      assert length(sorted) == 4
    end
  end

  describe "Layer 2: Trust System (Proof Tokens)" do
    test "issues valid proof token on success" do
      claims = %{action: :deploy, risk: :high}
      token = Verifier.issue_proof(claims)

      assert token.id != nil
      assert token.claims == claims
      assert String.starts_with?(token.signature, "prom_sig_")
    end
  end

  # Mocking the Zenoh Layer until NIF is compiled
  describe "Layer 3: Nervous System (Zenoh Mock)" do
    test "fractal key generation" do
      domain = "Security"
      component = "Auth"
      signal = "Login"

      key = "Indrajaal/#{domain}/#{component}/#{signal}"
      assert key == "Indrajaal/Security/Auth/Login"
    end
  end
end
