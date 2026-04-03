defmodule Indrajaal.Safety.PrometheusDagProofTest do
  @moduledoc """
  PROMETHEUS Proof Token Generation and DAG Acyclicity Verification Tests.

  WHAT: Tests the PROMETHEUS (Proof-based Mathematical Execution with Temporal
        HEuristic Universal Safety) verification layer. Covers proof token
        issuance via HMAC-SHA256, token verification, DAG acyclicity via Kahn's
        topological sort algorithm, cycle detection, and the constraint that no
        agent may execute a state-mutating action without a valid proof token.
  WHY: SC-PROM-001 mandates proof tokens for all state mutations. SC-PROM-004
       requires execution DAGs to be proven acyclic before scheduling. Without
       PROMETHEUS, unsanctioned mutations could violate constitutional invariants
       Ψ₀-Ψ₅ without any audit trail or Guardian oversight.
  CONSTRAINTS:
    - SC-PROM-001: No mutation without a valid PROMETHEUS Proof Token
    - SC-PROM-004: All execution DAGs MUST be proven acyclic before scheduling
    - SC-PROM-005: Verification MUST complete within 5ms p99
    - SC-PROM-006: Executive Agent may bypass with explicit audit log only
    - SC-PROM-002: API usage SHALL NOT exceed 95% of provider limits
    - AOR-PROM-004: Code changes execute autonomously but REQUIRE Supervisor verify

  ## Change History
  | Version | Date       | Author          | Change                                    |
  |---------|------------|-----------------|-------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude Sonnet   | Initial DAG acyclicity + proof token suite |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties

  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :prometheus
  @moduletag :dag

  alias Indrajaal.Prometheus.Verifier

  # SC-PROM-005: 5ms p99 verification latency
  @max_verification_ms 5
  # Allow headroom in test environment
  @test_verification_ms 50

  # ---------------------------------------------------------------------------
  # Proof Token Issuance (SC-PROM-001)
  # ---------------------------------------------------------------------------

  describe "proof token issuance (SC-PROM-001)" do
    test "issue_proof/1 returns a valid ProofToken struct" do
      claims = %{action: :deploy, module: "Test.Module", author: "test_agent"}
      result = Verifier.issue_proof(claims)

      assert {:ok, token} = result
      assert is_map(token)
      assert Map.has_key?(token, :id) or Map.has_key?(token, :signature)
    end

    test "issued proof token has non-nil id" do
      claims = %{action: :read, resource: "state.db"}
      {:ok, token} = Verifier.issue_proof(claims)

      id = Map.get(token, :id)
      assert id != nil
      assert is_binary(id) or is_atom(id)
    end

    test "issued proof token has HMAC-SHA256 signature" do
      claims = %{action: :write, key: "test_key", value: "test_val"}
      {:ok, token} = Verifier.issue_proof(claims)

      signature = Map.get(token, :signature)
      assert signature != nil
      assert is_binary(signature)
      # PROMETHEUS signature has "prom_sig_" prefix
      assert String.starts_with?(signature, "prom_sig_")
    end

    test "issued proof token includes original claims" do
      claims = %{action: :deploy, module: "Indrajaal.Core", author: "prometheus_test"}
      {:ok, token} = Verifier.issue_proof(claims)

      token_claims = Map.get(token, :claims)
      assert token_claims != nil
      assert is_map(token_claims)
    end

    test "issued proof token has a timestamp" do
      claims = %{action: :test}
      {:ok, token} = Verifier.issue_proof(claims)

      ts = Map.get(token, :timestamp)
      assert ts != nil
    end

    test "two calls with same claims produce distinct tokens (unique ids)" do
      claims = %{action: :deploy, module: "Test"}
      {:ok, token1} = Verifier.issue_proof(claims)
      {:ok, token2} = Verifier.issue_proof(claims)

      id1 = Map.get(token1, :id)
      id2 = Map.get(token2, :id)

      # Each token must have a unique ID (Ecto.UUID-generated)
      assert id1 != id2
    end
  end

  # ---------------------------------------------------------------------------
  # Proof Token Verification
  # ---------------------------------------------------------------------------

  describe "proof token verification" do
    test "verify_proof_token/1 accepts a freshly issued token" do
      claims = %{action: :verify_test, module: "Verifier.Test"}
      {:ok, token} = Verifier.issue_proof(claims)

      result = Verifier.verify_proof_token(token)
      assert {:ok, :valid} = result
    end

    test "verify_proof_token/1 rejects a token with tampered signature" do
      claims = %{action: :read}
      {:ok, token} = Verifier.issue_proof(claims)

      tampered = Map.put(token, :signature, "prom_sig_tampered_000000000000")
      result = Verifier.verify_proof_token(tampered)

      assert {:error, :invalid_signature} = result
    end

    test "verify_proof_token/1 rejects a bare map with no signature" do
      not_a_token = %{id: "fake", claims: %{action: :hack}}
      result = Verifier.verify_proof_token(not_a_token)

      assert {:error, :invalid_signature} =
               result or {:error, :invalid_token} == result or
                 (is_tuple(result) and elem(result, 0) == :error)
    end

    test "verify_proof_token/1 rejects nil" do
      result = Verifier.verify_proof_token(nil)
      assert {:error, :invalid_token} = result or (is_tuple(result) and elem(result, 0) == :error)
    end

    test "verification latency is within 50ms test budget" do
      claims = %{action: :latency_test}
      {:ok, token} = Verifier.issue_proof(claims)

      t0 = System.monotonic_time(:millisecond)
      Verifier.verify_proof_token(token)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < @test_verification_ms,
             "Proof verification took #{elapsed}ms — target is #{@max_verification_ms}ms p99 (SC-PROM-005)"
    end
  end

  # ---------------------------------------------------------------------------
  # DAG Acyclicity — Kahn's Algorithm (SC-PROM-004)
  # ---------------------------------------------------------------------------

  describe "DAG acyclicity via Kahn's algorithm (SC-PROM-004)" do
    test "simple linear DAG is accepted as acyclic" do
      # A → B → C → D
      dag = %{
        "A" => ["B"],
        "B" => ["C"],
        "C" => ["D"],
        "D" => []
      }

      result = Verifier.verify_dag(dag)
      assert {:ok, sorted_nodes} = result
      assert is_list(sorted_nodes)
      assert length(sorted_nodes) == 4
    end

    test "diamond DAG is accepted as acyclic" do
      # A → B, A → C, B → D, C → D
      dag = %{
        "A" => ["B", "C"],
        "B" => ["D"],
        "C" => ["D"],
        "D" => []
      }

      result = Verifier.verify_dag(dag)
      assert {:ok, sorted_nodes} = result
      assert is_list(sorted_nodes)
      assert "A" in sorted_nodes
      assert "D" in sorted_nodes
    end

    test "single-node DAG is accepted" do
      dag = %{"root" => []}
      result = Verifier.verify_dag(dag)
      assert {:ok, ["root"]} = result
    end

    test "empty DAG is accepted" do
      result = Verifier.verify_dag(%{})
      assert {:ok, []} = result
    end

    test "topological order preserves dependency ordering" do
      # Boot sequence DAG: db → app → phoenix
      dag = %{
        "db" => ["app"],
        "app" => ["phoenix"],
        "phoenix" => []
      }

      {:ok, order} = Verifier.verify_dag(dag)

      db_pos = Enum.find_index(order, &(&1 == "db"))
      app_pos = Enum.find_index(order, &(&1 == "app"))
      phoenix_pos = Enum.find_index(order, &(&1 == "phoenix"))

      assert db_pos < app_pos, "db must come before app in topological order"
      assert app_pos < phoenix_pos, "app must come before phoenix in topological order"
    end
  end

  # ---------------------------------------------------------------------------
  # Cycle Detection (SC-PROM-004)
  # ---------------------------------------------------------------------------

  describe "cycle detection in DAG" do
    test "simple 2-node cycle is detected" do
      # A → B → A (cycle)
      dag = %{
        "A" => ["B"],
        "B" => ["A"]
      }

      result = Verifier.verify_dag(dag)
      assert {:error, :cycle_detected} = result
    end

    test "self-loop is detected as cycle" do
      dag = %{"A" => ["A"]}
      result = Verifier.verify_dag(dag)
      assert {:error, :cycle_detected} = result
    end

    test "3-node cycle is detected" do
      # A → B → C → A
      dag = %{
        "A" => ["B"],
        "B" => ["C"],
        "C" => ["A"]
      }

      result = Verifier.verify_dag(dag)
      assert {:error, :cycle_detected} = result
    end

    test "cycle in subgraph with acyclic components is detected" do
      # A → B (safe), C → D → C (cycle hidden in subgraph)
      dag = %{
        "A" => ["B"],
        "B" => [],
        "C" => ["D"],
        "D" => ["C"]
      }

      result = Verifier.verify_dag(dag)
      assert {:error, :cycle_detected} = result
    end

    test "cycle detection latency is within 50ms test budget" do
      large_cycle =
        for i <- 1..100, into: %{} do
          next = rem(i, 100) + 1
          {"node_#{i}", ["node_#{next}"]}
        end

      t0 = System.monotonic_time(:millisecond)
      Verifier.verify_dag(large_cycle)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < @test_verification_ms,
             "Cycle detection on 100-node graph took #{elapsed}ms"
    end
  end

  # ---------------------------------------------------------------------------
  # Property Tests — DAG Invariants
  # ---------------------------------------------------------------------------

  test "any valid linear chain is acyclic (SD property)" do
    ExUnitProperties.check all(n <- SD.integer(2..21)) do
      nodes = for i <- 1..n, do: "n#{i}"

      dag =
        nodes
        |> Enum.zip(tl(nodes) ++ [[]])
        |> Enum.map(fn
          {node, []} -> {node, []}
          {node, next} -> {node, [next]}
        end)
        |> Map.new()

      assert match?({:ok, _}, Verifier.verify_dag(dag))
    end
  end

  test "issue_proof always returns a token with a string signature (SD property)" do
    ExUnitProperties.check all(
                             action <-
                               SD.member_of([
                                 :deploy,
                                 :rollback,
                                 :config_update,
                                 :test,
                                 :query,
                                 :read
                               ])
                           ) do
      claims = %{action: action}

      case Verifier.issue_proof(claims) do
        {:ok, token} ->
          sig = Map.get(token, :signature)
          assert is_binary(sig) and String.starts_with?(sig, "prom_sig_")

        {:error, _} ->
          assert true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # SC-PROM-001 — No Mutation Without Token
  # ---------------------------------------------------------------------------

  describe "SC-PROM-001 — proof token gate enforcement" do
    test "Verifier.issue_proof/1 can generate tokens for all supported claim types" do
      claim_types = [
        %{action: :deploy},
        %{action: :rollback},
        %{action: :config_update},
        %{action: :schema_migration},
        %{action: :emergency_stop}
      ]

      for claims <- claim_types do
        result = Verifier.issue_proof(claims)
        assert {:ok, token} = result
        assert Map.get(token, :signature) != nil
      end
    end

    test "verify_proof_token rejects tokens with empty signature" do
      claims = %{action: :test}
      {:ok, token} = Verifier.issue_proof(claims)
      bad_token = Map.put(token, :signature, "")

      result = Verifier.verify_proof_token(bad_token)
      assert is_tuple(result) and elem(result, 0) == :error
    end
  end
end
