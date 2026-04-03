defmodule Indrajaal.Cockpit.Prajna.PrometheusVerifierTest do
  @moduledoc """
  Tests for PROMETHEUS Verification Layer.

  STAMP Constraints:
  - SC-PROM-001: Proof token required for state mutations
  - SC-PROM-004: DAG acyclicity verification

  TDG Compliance:
  - Unit tests for all public functions
  - Property tests for DAG verification
  - Boundary condition testing
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Cockpit.Prajna.PrometheusVerifier

  # ============================================================
  # UNIT TESTS: require_proof_token/3
  # ============================================================

  describe "require_proof_token/3" do
    test "returns ok with valid proof token for allowed action" do
      result = PrometheusVerifier.require_proof_token(:reconfigure, :sentinel)

      assert {:ok, token} = result
      assert Map.has_key?(token, :token_id)
      assert Map.has_key?(token, :action)
      assert Map.has_key?(token, :timestamp)
      assert Map.has_key?(token, :expires_at)
      assert Map.has_key?(token, :signature)
      assert token.action == :reconfigure
    end

    test "returns error for prohibited actions" do
      assert {:error, :action_prohibited} =
               PrometheusVerifier.require_proof_token(:self_destruct, :system)

      assert {:error, :action_prohibited} =
               PrometheusVerifier.require_proof_token(:disable_guardian, :guardian)

      assert {:error, :action_prohibited} =
               PrometheusVerifier.require_proof_token(:bypass_verification, :prometheus)
    end

    test "token_id is a 32-character hex string" do
      {:ok, token} = PrometheusVerifier.require_proof_token(:scale, :workers)
      assert String.length(token.token_id) == 32
      assert Regex.match?(~r/^[0-9a-f]+$/, token.token_id)
    end

    test "expires_at is 5 minutes after timestamp" do
      {:ok, token} = PrometheusVerifier.require_proof_token(:update, :config)

      diff = DateTime.diff(token.expires_at, token.timestamp, :second)
      assert diff == 300
    end

    test "different actions produce different token_ids" do
      {:ok, token1} = PrometheusVerifier.require_proof_token(:action1, :target)
      {:ok, token2} = PrometheusVerifier.require_proof_token(:action2, :target)

      assert token1.token_id != token2.token_id
    end

    test "skip_budget_check option works" do
      result =
        PrometheusVerifier.require_proof_token(:action, :target, skip_budget_check: true)

      assert {:ok, _token} = result
    end
  end

  # ============================================================
  # UNIT TESTS: verify_token/1
  # ============================================================

  describe "verify_token/1" do
    test "returns ok for valid non-expired token" do
      {:ok, token} = PrometheusVerifier.require_proof_token(:test, :target)
      result = PrometheusVerifier.verify_token(token)

      assert {:ok, :valid} = result
    end

    test "returns error for expired token" do
      # Create a token that's already expired
      expired_token = %{
        token_id: "test123",
        action: :test,
        target: :target,
        timestamp: DateTime.add(DateTime.utc_now(), -600, :second),
        expires_at: DateTime.add(DateTime.utc_now(), -300, :second),
        signature: "invalid"
      }

      assert {:error, :expired_token} = PrometheusVerifier.verify_token(expired_token)
    end

    test "returns error for invalid token format" do
      assert {:error, :invalid_token} = PrometheusVerifier.verify_token(nil)
      assert {:error, :invalid_token} = PrometheusVerifier.verify_token("not a map")
      assert {:error, :invalid_token} = PrometheusVerifier.verify_token(%{})
    end

    test "returns error for tampered signature" do
      {:ok, token} = PrometheusVerifier.require_proof_token(:test, :target)
      tampered = %{token | signature: "tampered_signature"}

      assert {:error, :invalid_signature} = PrometheusVerifier.verify_token(tampered)
    end
  end

  # ============================================================
  # UNIT TESTS: verify_dag_acyclic/1
  # ============================================================

  describe "verify_dag_acyclic/1" do
    test "returns ok for acyclic DAG" do
      nodes = [
        %{id: "a", action: :init, dependencies: []},
        %{id: "b", action: :process, dependencies: ["a"]},
        %{id: "c", action: :finalize, dependencies: ["b"]}
      ]

      result = PrometheusVerifier.verify_dag_acyclic(nodes)

      assert {:ok, sorted} = result
      assert sorted == ["a", "b", "c"]
    end

    test "returns ok for DAG with multiple roots" do
      nodes = [
        %{id: "a", action: :init_a, dependencies: []},
        %{id: "b", action: :init_b, dependencies: []},
        %{id: "c", action: :merge, dependencies: ["a", "b"]}
      ]

      result = PrometheusVerifier.verify_dag_acyclic(nodes)

      assert {:ok, sorted} = result
      assert "c" == List.last(sorted)
      assert "a" in sorted
      assert "b" in sorted
    end

    test "returns error for cyclic graph" do
      nodes = [
        %{id: "a", action: :step1, dependencies: ["c"]},
        %{id: "b", action: :step2, dependencies: ["a"]},
        %{id: "c", action: :step3, dependencies: ["b"]}
      ]

      result = PrometheusVerifier.verify_dag_acyclic(nodes)

      assert {:error, :cyclic_graph} = result
    end

    test "returns error for self-referencing node" do
      nodes = [
        %{id: "a", action: :self_ref, dependencies: ["a"]}
      ]

      result = PrometheusVerifier.verify_dag_acyclic(nodes)

      assert {:error, :cyclic_graph} = result
    end

    test "handles empty DAG" do
      result = PrometheusVerifier.verify_dag_acyclic([])

      assert {:ok, []} = result
    end

    test "handles single node DAG" do
      nodes = [%{id: "only", action: :single, dependencies: []}]

      result = PrometheusVerifier.verify_dag_acyclic(nodes)

      assert {:ok, ["only"]} = result
    end

    test "returns error for invalid input" do
      assert {:error, :invalid_input} = PrometheusVerifier.verify_dag_acyclic("not a list")
    end
  end

  # ============================================================
  # UNIT TESTS: check_api_budget/0
  # ============================================================

  describe "check_api_budget/0" do
    test "returns ok with usage percentage when under budget" do
      result = PrometheusVerifier.check_api_budget()

      assert {:ok, usage} = result
      assert is_float(usage)
      assert usage >= 0.0 and usage < 0.95
    end
  end

  # ============================================================
  # UNIT TESTS: get_stats/0
  # ============================================================

  describe "get_stats/0" do
    test "returns statistics map" do
      stats = PrometheusVerifier.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :tokens_issued)
      assert Map.has_key?(stats, :tokens_verified)
      assert Map.has_key?(stats, :dag_checks)
      assert Map.has_key?(stats, :budget_checks)
      assert Map.has_key?(stats, :verification_failures)
    end

    test "counters are non-negative integers" do
      stats = PrometheusVerifier.get_stats()

      assert is_integer(stats.tokens_issued) and stats.tokens_issued >= 0
      assert is_integer(stats.tokens_verified) and stats.tokens_verified >= 0
      assert is_integer(stats.dag_checks) and stats.dag_checks >= 0
    end
  end

  # ============================================================
  # PROPERTY TESTS: DAG Verification (PropCheck)
  # ============================================================

  property "linear DAG is always acyclic" do
    forall n <- PC.pos_integer() do
      n = min(n, 100)

      nodes =
        Enum.map(0..(n - 1), fn i ->
          deps = if i == 0, do: [], else: [Integer.to_string(i - 1)]
          %{id: Integer.to_string(i), action: :step, dependencies: deps}
        end)

      case PrometheusVerifier.verify_dag_acyclic(nodes) do
        {:ok, sorted} ->
          # Verify topological order
          length(sorted) == n

        {:error, _} ->
          false
      end
    end
  end

  property "DAG with no edges is always acyclic" do
    forall n <- PC.pos_integer() do
      n = min(n, 50)

      nodes =
        Enum.map(1..n, fn i ->
          %{id: "node_#{i}", action: :independent, dependencies: []}
        end)

      case PrometheusVerifier.verify_dag_acyclic(nodes) do
        {:ok, sorted} -> length(sorted) == n
        {:error, _} -> false
      end
    end
  end

  property "token_id is deterministic for same action+target but includes randomness" do
    forall {action, target} <- {PC.atom(), PC.atom()} do
      {:ok, token1} = PrometheusVerifier.require_proof_token(action, target)
      {:ok, token2} = PrometheusVerifier.require_proof_token(action, target)

      # Tokens should be different due to nonce
      token1.token_id != token2.token_id
    end
  end

  # ============================================================
  # STAMP CONSTRAINT VERIFICATION
  # ============================================================

  describe "SC-PROM-001: Proof token required" do
    test "state mutation requires proof token" do
      result = PrometheusVerifier.require_proof_token(:mutate_state, :holon)

      assert {:ok, token} = result
      assert token.action == :mutate_state
    end
  end

  describe "SC-PROM-004: DAG acyclicity verification" do
    test "cyclic graph is rejected" do
      cyclic_nodes = [
        %{id: "1", action: :a, dependencies: ["2"]},
        %{id: "2", action: :b, dependencies: ["1"]}
      ]

      assert {:error, :cyclic_graph} = PrometheusVerifier.verify_dag_acyclic(cyclic_nodes)
    end

    test "acyclic graph is accepted" do
      acyclic_nodes = [
        %{id: "1", action: :a, dependencies: []},
        %{id: "2", action: :b, dependencies: ["1"]}
      ]

      assert {:ok, _sorted} = PrometheusVerifier.verify_dag_acyclic(acyclic_nodes)
    end
  end

  describe "SC-PROM-002: API budget threshold" do
    test "budget check returns usage percentage" do
      {:ok, usage} = PrometheusVerifier.check_api_budget()
      assert usage < 0.95
    end
  end

  # ============================================================
  # UNIT TESTS: validate_dag_acyclic/1 (SC-PROM-004)
  # ============================================================

  describe "validate_dag_acyclic/1" do
    test "returns proof token for valid acyclic DAG" do
      nodes = [
        %{id: "init", action: :initialize, dependencies: []},
        %{id: "process", action: :process, dependencies: ["init"]},
        %{id: "finalize", action: :finalize, dependencies: ["process"]}
      ]

      result = PrometheusVerifier.validate_dag_acyclic(nodes)

      assert {:ok, proof_token} = result
      assert Map.has_key?(proof_token, :token_id)
      assert Map.has_key?(proof_token, :graph_hash)
      assert Map.has_key?(proof_token, :topological_order)
      assert Map.has_key?(proof_token, :signature)
      assert proof_token.topological_order == ["init", "process", "finalize"]
    end

    test "returns cycle info for cyclic graph" do
      nodes = [
        %{id: "a", action: :step1, dependencies: ["c"]},
        %{id: "b", action: :step2, dependencies: ["a"]},
        %{id: "c", action: :step3, dependencies: ["b"]}
      ]

      result = PrometheusVerifier.validate_dag_acyclic(nodes)

      assert {:error, :cyclic_graph, cycle_info} = result
      assert Map.has_key?(cycle_info, :cycle_nodes)
      assert Map.has_key?(cycle_info, :entry_point)
      assert is_list(cycle_info.cycle_nodes)
    end

    test "returns cycle info for self-referencing node" do
      nodes = [
        %{id: "self", action: :self_ref, dependencies: ["self"]}
      ]

      result = PrometheusVerifier.validate_dag_acyclic(nodes)

      assert {:error, :cyclic_graph, cycle_info} = result
      assert cycle_info.entry_point == "self"
    end

    test "handles empty DAG" do
      result = PrometheusVerifier.validate_dag_acyclic([])

      assert {:ok, proof_token} = result
      assert proof_token.topological_order == []
    end

    test "handles diamond dependency pattern" do
      # A diamond pattern: a -> b, a -> c, b -> d, c -> d
      nodes = [
        %{id: "a", action: :start, dependencies: []},
        %{id: "b", action: :path1, dependencies: ["a"]},
        %{id: "c", action: :path2, dependencies: ["a"]},
        %{id: "d", action: :merge, dependencies: ["b", "c"]}
      ]

      result = PrometheusVerifier.validate_dag_acyclic(nodes)

      assert {:ok, proof_token} = result
      order = proof_token.topological_order
      # a must come before b, c; b and c must come before d
      assert Enum.find_index(order, &(&1 == "a")) < Enum.find_index(order, &(&1 == "b"))
      assert Enum.find_index(order, &(&1 == "a")) < Enum.find_index(order, &(&1 == "c"))
      assert Enum.find_index(order, &(&1 == "b")) < Enum.find_index(order, &(&1 == "d"))
      assert Enum.find_index(order, &(&1 == "c")) < Enum.find_index(order, &(&1 == "d"))
    end

    test "proof token includes graph hash for integrity verification" do
      nodes = [
        %{id: "x", action: :test, dependencies: []}
      ]

      {:ok, proof_token} = PrometheusVerifier.validate_dag_acyclic(nodes)

      assert is_binary(proof_token.graph_hash)
      assert String.length(proof_token.graph_hash) == 16
    end

    test "returns error for invalid input" do
      assert {:error, :invalid_input} = PrometheusVerifier.validate_dag_acyclic("not a list")
      assert {:error, :invalid_input} = PrometheusVerifier.validate_dag_acyclic(nil)
    end
  end

  # ============================================================
  # UNIT TESTS: validate_execution_graph/1
  # ============================================================

  describe "validate_execution_graph/1" do
    test "returns proof token and execution plan for valid graph" do
      graph = %{
        nodes: [
          %{id: "fetch", action: :fetch, dependencies: []},
          %{id: "transform", action: :transform, dependencies: ["fetch"]},
          %{id: "store", action: :store, dependencies: ["transform"]}
        ],
        edges: [{"fetch", "transform"}, {"transform", "store"}],
        metadata: %{name: "data_pipeline", version: 1}
      }

      result = PrometheusVerifier.validate_execution_graph(graph)

      assert {:ok, proof_token, execution_plan} = result
      assert execution_plan == ["fetch", "transform", "store"]
      assert proof_token.topological_order == execution_plan
    end

    test "allows simplified graph without edges/metadata" do
      graph = %{
        nodes: [
          %{id: "a", action: :step, dependencies: []},
          %{id: "b", action: :step, dependencies: ["a"]}
        ]
      }

      result = PrometheusVerifier.validate_execution_graph(graph)

      assert {:ok, _proof_token, execution_plan} = result
      assert execution_plan == ["a", "b"]
    end

    test "returns error for cyclic execution graph" do
      graph = %{
        nodes: [
          %{id: "a", action: :x, dependencies: ["b"]},
          %{id: "b", action: :y, dependencies: ["a"]}
        ],
        edges: [],
        metadata: %{}
      }

      result = PrometheusVerifier.validate_execution_graph(graph)

      assert {:error, :cyclic_graph} = result
    end

    test "returns error for invalid graph format" do
      assert {:error, :invalid_graph_format} = PrometheusVerifier.validate_execution_graph(%{})

      assert {:error, :invalid_graph_format} =
               PrometheusVerifier.validate_execution_graph("not a map")
    end
  end

  # ============================================================
  # UNIT TESTS: verify_dag_proof_token/1
  # ============================================================

  describe "verify_dag_proof_token/1" do
    test "returns ok for valid non-expired DAG proof token" do
      nodes = [%{id: "test", action: :test, dependencies: []}]
      {:ok, proof_token} = PrometheusVerifier.validate_dag_acyclic(nodes)

      result = PrometheusVerifier.verify_dag_proof_token(proof_token)

      assert {:ok, :valid} = result
    end

    test "returns error for expired DAG proof token" do
      expired_token = %{
        token_id: "test123",
        graph_hash: "abcd1234abcd1234",
        topological_order: ["a", "b"],
        timestamp: DateTime.add(DateTime.utc_now(), -600, :second),
        expires_at: DateTime.add(DateTime.utc_now(), -300, :second),
        signature: "invalid"
      }

      result = PrometheusVerifier.verify_dag_proof_token(expired_token)

      assert {:error, :expired_token} = result
    end

    test "returns error for invalid token format" do
      assert {:error, :invalid_token} = PrometheusVerifier.verify_dag_proof_token(nil)
      assert {:error, :invalid_token} = PrometheusVerifier.verify_dag_proof_token(%{})
      assert {:error, :invalid_token} = PrometheusVerifier.verify_dag_proof_token("string")
    end

    test "returns error for tampered signature" do
      nodes = [%{id: "test", action: :test, dependencies: []}]
      {:ok, proof_token} = PrometheusVerifier.validate_dag_acyclic(nodes)
      tampered = %{proof_token | signature: "tampered_signature"}

      result = PrometheusVerifier.verify_dag_proof_token(tampered)

      assert {:error, :invalid_signature} = result
    end
  end

  # ============================================================
  # PROPERTY TESTS: DAG Validation (PropCheck)
  # ============================================================

  property "diamond DAG pattern is always acyclic" do
    forall n <- PC.range(2, 20) do
      # Create a diamond: one root, n middle nodes, one sink
      middle_nodes =
        Enum.map(1..n, fn i ->
          %{id: "mid_#{i}", action: :middle, dependencies: ["root"]}
        end)

      all_middle_ids = Enum.map(1..n, fn i -> "mid_#{i}" end)

      nodes =
        [%{id: "root", action: :start, dependencies: []}] ++
          middle_nodes ++
          [%{id: "sink", action: :finish, dependencies: all_middle_ids}]

      case PrometheusVerifier.validate_dag_acyclic(nodes) do
        {:ok, proof_token} ->
          # Root first, sink last
          order = proof_token.topological_order
          hd(order) == "root" and List.last(order) == "sink"

        {:error, _, _} ->
          false
      end
    end
  end

  property "cycle detection finds all cycles" do
    forall n <- PC.range(2, 10) do
      # Create a simple cycle: 1 -> 2 -> 3 -> ... -> n -> 1
      nodes =
        Enum.map(1..n, fn i ->
          next = if i == n, do: "1", else: Integer.to_string(i + 1)
          %{id: Integer.to_string(i), action: :step, dependencies: [next]}
        end)

      case PrometheusVerifier.validate_dag_acyclic(nodes) do
        {:error, :cyclic_graph, cycle_info} ->
          # Cycle should be detected with valid info
          is_map(cycle_info) and
            Map.has_key?(cycle_info, :entry_point) and
            Map.has_key?(cycle_info, :cycle_nodes)

        {:ok, _} ->
          false
      end
    end
  end

  property "proof token graph hash is deterministic" do
    forall n <- PC.range(1, 10) do
      nodes =
        Enum.map(0..(n - 1), fn i ->
          deps = if i == 0, do: [], else: [Integer.to_string(i - 1)]
          %{id: Integer.to_string(i), action: :step, dependencies: deps}
        end)

      {:ok, token1} = PrometheusVerifier.validate_dag_acyclic(nodes)
      {:ok, token2} = PrometheusVerifier.validate_dag_acyclic(nodes)

      # Same graph produces same hash
      token1.graph_hash == token2.graph_hash
    end
  end
end
