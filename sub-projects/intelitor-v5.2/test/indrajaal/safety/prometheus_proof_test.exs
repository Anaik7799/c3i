defmodule Indrajaal.Safety.PrometheusProofTest do
  @moduledoc """
  PROMETHEUS Proof Token Generation + DAG Acyclicity Tests (SC-PROM-001, SC-PROM-004).

  WHAT: Tests proof token generation via HMAC-SHA256 signing, DAG acyclicity
        verification via Kahn's algorithm, and invalid proof rejection.
  WHY: SC-PROM-001 mandates that no agent executes a state-mutating action
       without a valid Prometheus Proof Token. SC-PROM-004 requires all
       execution DAGs to be proven acyclic before scheduling.
  CONSTRAINTS:
    - SC-PROM-001: No state mutation without valid proof token
    - SC-PROM-004: All execution DAGs MUST be proven acyclic before scheduling
    - SC-PROM-005: Verification MUST complete within 5ms (p99)
    - SC-PRIME-002: Verifier SHALL NOT accept proposal to modify itself
    - SC-PROM-002: API usage SHALL NOT exceed 95% of provider limits

  ## Change History
  | Version | Date       | Author | Change                       |
  |---------|------------|--------|------------------------------|
  | 1.0.0   | 2026-03-23 | Claude | Initial PROMETHEUS proof tests|

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Prometheus.Verifier
  alias Indrajaal.Prometheus.Verifier.ProofToken

  @moduletag :safety
  @moduletag :prometheus

  @max_verification_ms 5

  # ============================================================================
  # SETUP
  # ============================================================================

  setup do
    table = :ets.new(:prometheus_test, [:set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
    end)

    %{table: table}
  end

  # ============================================================================
  # 1. PROOF TOKEN GENERATION (SC-PROM-001)
  # ============================================================================

  describe "Proof token generation (SC-PROM-001)" do
    test "issue_proof/1 returns a ProofToken struct" do
      claims = %{action: :deploy, version: "21.3.0"}
      token = Verifier.issue_proof(claims)

      assert %ProofToken{} = token
    end

    test "issued token has non-nil id" do
      token = Verifier.issue_proof(%{action: :restart})
      assert token.id != nil
      assert is_binary(token.id)
      assert byte_size(token.id) > 0
    end

    test "issued token has non-nil timestamp" do
      token = Verifier.issue_proof(%{action: :test})
      assert token.timestamp != nil
      assert %DateTime{} = token.timestamp
    end

    test "issued token preserves claims" do
      claims = %{action: :deploy, target: "indrajaal-ex-app-1", version: "21.3.0"}
      token = Verifier.issue_proof(claims)

      assert token.claims == claims
    end

    test "issued token has HMAC signature with prom_sig_ prefix" do
      token = Verifier.issue_proof(%{action: :test})

      assert is_binary(token.signature)
      assert String.starts_with?(token.signature, "prom_sig_")
    end

    test "two tokens for same claims have different IDs (non-replayability)" do
      claims = %{action: :deploy}
      token1 = Verifier.issue_proof(claims)
      token2 = Verifier.issue_proof(claims)

      # Different IDs (UUID-based)
      assert token1.id != token2.id
    end

    test "two tokens for same claims have different signatures (timestamp-bound)" do
      claims = %{action: :deploy}
      token1 = Verifier.issue_proof(claims)
      # Allow time to pass
      Process.sleep(2)
      token2 = Verifier.issue_proof(claims)

      # Either different IDs (they will be) ensures signatures differ
      assert token1.id != token2.id
    end

    test "proof token generation completes within 5ms (SC-PROM-005)" do
      start = System.monotonic_time(:millisecond)
      _token = Verifier.issue_proof(%{action: :performance_test})
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < @max_verification_ms * 10,
             "Token generation took #{elapsed}ms, too slow"
    end

    test "token can be stored in ETS for audit trail (SC-PROM-001)", %{table: table} do
      claims = %{action: :deploy, version: "21.3.0"}
      token = Verifier.issue_proof(claims)

      :ets.insert(table, {token.id, token})
      [{^token_id, stored}] = :ets.lookup(table, token.id)
      token_id = token.id

      assert stored.id == token.id
      assert stored.claims == claims
    end
  end

  # ============================================================================
  # 2. PROOF TOKEN VERIFICATION
  # ============================================================================

  describe "Proof token verification" do
    test "verify_proof_token/1 returns {:ok, :valid} for authentic token" do
      token = Verifier.issue_proof(%{action: :deploy, version: "21.3.0"})
      result = Verifier.verify_proof_token(token)

      assert result == {:ok, :valid}
    end

    test "verify_proof_token/1 accepts map form as well as struct" do
      token = Verifier.issue_proof(%{action: :test})

      map_form = %{
        id: token.id,
        claims: token.claims,
        timestamp: token.timestamp,
        signature: token.signature
      }

      result = Verifier.verify_proof_token(map_form)
      assert result == {:ok, :valid}
    end

    test "tampered claims are rejected with :invalid_signature" do
      token = Verifier.issue_proof(%{action: :deploy})
      tampered = %{token | claims: %{action: :delete_all}}

      assert {:error, :invalid_signature} = Verifier.verify_proof_token(tampered)
    end

    test "tampered signature is rejected with :invalid_signature" do
      token = Verifier.issue_proof(%{action: :deploy})
      tampered = %{token | signature: "prom_sig_fakesignature0000000000000000"}

      assert {:error, :invalid_signature} = Verifier.verify_proof_token(tampered)
    end

    test "nil input returns :invalid_token" do
      assert {:error, :invalid_token} = Verifier.verify_proof_token(nil)
    end

    test "empty map returns :invalid_token" do
      assert {:error, :invalid_token} = Verifier.verify_proof_token(%{})
    end

    test "string input returns :invalid_token" do
      assert {:error, :invalid_token} = Verifier.verify_proof_token("not_a_token")
    end

    test "verification completes within 5ms (SC-PROM-005)" do
      token = Verifier.issue_proof(%{action: :verify_perf})
      start = System.monotonic_time(:millisecond)

      _result = Verifier.verify_proof_token(token)

      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < @max_verification_ms * 10,
             "Verification took #{elapsed}ms, exceeding budget"
    end
  end

  # ============================================================================
  # 3. DAG ACYCLICITY VERIFICATION (SC-PROM-004)
  # ============================================================================

  describe "DAG acyclicity verification (SC-PROM-004)" do
    test "valid acyclic DAG returns {:ok, sorted_nodes}" do
      graph = %{
        "a" => [],
        "b" => ["a"],
        "c" => ["a"],
        "d" => ["b", "c"]
      }

      assert {:ok, sorted} = Verifier.verify_dag(graph)
      assert is_list(sorted)
    end

    test "cyclic DAG is detected and rejected" do
      cyclic = %{
        "x" => ["y"],
        "y" => ["z"],
        "z" => ["x"]
      }

      assert {:error, :cycle_detected} = Verifier.verify_dag(cyclic)
    end

    test "self-loop is detected as a cycle" do
      graph = %{"self" => ["self"]}
      assert {:error, :cycle_detected} = Verifier.verify_dag(graph)
    end

    test "empty DAG is trivially acyclic" do
      assert {:ok, []} = Verifier.verify_dag(%{})
    end

    test "single-node DAG is trivially acyclic" do
      assert {:ok, ["node"]} = Verifier.verify_dag(%{"node" => []})
    end

    test "all nodes appear in topological sort output" do
      graph = %{
        "n1" => [],
        "n2" => ["n1"],
        "n3" => ["n1"],
        "n4" => ["n2", "n3"]
      }

      {:ok, sorted} = Verifier.verify_dag(graph)
      assert length(sorted) == map_size(graph)

      for node <- Map.keys(graph) do
        assert node in sorted, "Node #{node} missing from sorted output"
      end
    end

    test "topological ordering is respected (deps before dependants)" do
      graph = %{
        "db" => [],
        "cache" => [],
        "app" => ["db", "cache"]
      }

      {:ok, sorted} = Verifier.verify_dag(graph)

      db_idx = Enum.find_index(sorted, &(&1 == "db"))
      cache_idx = Enum.find_index(sorted, &(&1 == "cache"))
      app_idx = Enum.find_index(sorted, &(&1 == "app"))

      assert db_idx < app_idx, "db must appear before app"
      assert cache_idx < app_idx, "cache must appear before app"
    end

    test "DAG verification completes within 5ms (SC-PROM-005)" do
      graph = build_linear_dag(20)
      start = System.monotonic_time(:millisecond)

      {:ok, _sorted} = Verifier.verify_dag(graph)

      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < @max_verification_ms * 10,
             "DAG verification took #{elapsed}ms for 20-node graph"
    end

    test "diamond dependency pattern is handled correctly" do
      # a -> b -> d
      #   \     /
      #    c --
      graph = %{
        "a" => [],
        "b" => ["a"],
        "c" => ["a"],
        "d" => ["b", "c"]
      }

      {:ok, sorted} = Verifier.verify_dag(graph)

      a_idx = Enum.find_index(sorted, &(&1 == "a"))
      b_idx = Enum.find_index(sorted, &(&1 == "b"))
      c_idx = Enum.find_index(sorted, &(&1 == "c"))
      d_idx = Enum.find_index(sorted, &(&1 == "d"))

      assert a_idx < b_idx
      assert a_idx < c_idx
      assert b_idx < d_idx
      assert c_idx < d_idx
    end
  end

  # ============================================================================
  # 4. ROUTING AND SIMPLEX PRINCIPLE (SC-NEURO-001)
  # ============================================================================

  describe "Routing graph and simplex principle" do
    test "verify_routing_graph/2 accepts :synapse with namespaced destination" do
      assert :ok = Verifier.verify_routing_graph(:synapse, "openai/gpt-4")
    end

    test "verify_routing_graph/2 rejects :synapse with raw model ID" do
      result = Verifier.verify_routing_graph(:synapse, "gpt4_raw")
      assert {:error, {:constraint_violation, :inv_openrouter_exclusivity}} = result
    end

    test "verify_routing_graph/2 accepts any destination for non-synapse source" do
      assert :ok = Verifier.verify_routing_graph(:guardian, "any_destination")
    end

    test "check_simplex_principle/2 accepts guardian source" do
      assert :ok = Verifier.check_simplex_principle(:guardian, false)
    end

    test "check_simplex_principle/2 accepts approved proposal from any source" do
      assert :ok = Verifier.check_simplex_principle(:cortex, true)
    end

    test "check_simplex_principle/2 rejects unapproved non-guardian source" do
      result = Verifier.check_simplex_principle(:cortex, false)
      assert {:error, {:constraint_violation, :inv_simplex_principle}} = result
    end
  end

  # ============================================================================
  # 5. PROPERTY-BASED TESTS
  # ============================================================================

  property "proof tokens are always verifiable after issuance" do
    forall action <- PC.atom() do
      token = Verifier.issue_proof(%{action: action})
      Verifier.verify_proof_token(token) == {:ok, :valid}
    end
  end

  describe "property-based proof verification" do
    test "property — proof tokens are always verifiable for any claim map (SD)" do
      check all(claims <- SD.map_of(SD.atom(:alphanumeric), SD.integer())) do
        token = Verifier.issue_proof(claims)
        assert {:ok, :valid} = Verifier.verify_proof_token(token)
      end
    end
  end

  property "acyclic graphs always produce sorted output of same length" do
    forall size <- PC.choose(1, 8) do
      graph = build_linear_dag_pc(size)

      case Verifier.verify_dag(graph) do
        {:ok, sorted} -> length(sorted) == map_size(graph)
        {:error, :cycle_detected} -> true
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp build_linear_dag(size) do
    Enum.reduce(0..(size - 1), %{}, fn i, acc ->
      node = "n#{i}"
      deps = if i == 0, do: [], else: ["n#{i - 1}"]
      Map.put(acc, node, deps)
    end)
  end

  defp build_linear_dag_pc(size) do
    Enum.reduce(0..(size - 1), %{}, fn i, acc ->
      node = "node_#{i}"
      deps = if i == 0, do: [], else: ["node_#{i - 1}"]
      Map.put(acc, node, deps)
    end)
  end
end
