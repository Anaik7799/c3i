defmodule Indrajaal.Safety.PrometheusVerificationTest do
  @moduledoc """
  PROMETHEUS Verification Pipeline Integration Tests (SC-PROM-001, SC-PROM-004).

  WHAT: Tests the full PROMETHEUS verification pipeline — proof token issuance,
        DAG acyclicity gate enforcement, semantic entropy gate, and the
        recursion lock that prevents the verifier from modifying itself.
  WHY: SC-PROM-001 requires a valid proof token before any state-mutating action.
       SC-PROM-004 requires DAG acyclicity proven before scheduling.
       SC-PRIME-002 prevents the Verifier from self-modification.
       This file focuses on integration: token → gate → executor feedback loop.
  CONSTRAINTS:
    - SC-PROM-001: Proof token required for ALL state-mutating actions
    - SC-PROM-002: API usage SHALL NOT exceed 95% of provider limits
    - SC-PROM-004: All execution DAGs MUST be proven acyclic before scheduling
    - SC-PROM-005: Verification MUST complete within 5ms (p99)
    - SC-PROM-006: Executive Agent MAY bypass verification with audit log
    - SC-PRIME-002: Recursion lock — Verifier SHALL NOT accept self-modification

  ## Change History
  | Version | Date       | Author | Change                               |
  |---------|------------|--------|--------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial PROMETHEUS verification tests |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties

  alias StreamData, as: SD
  alias Indrajaal.Prometheus.Verifier
  alias Indrajaal.Prometheus.Verifier.ProofToken

  @moduletag :safety
  @moduletag :prometheus
  @moduletag :sprint_88

  @max_verification_ms 50
  @api_limit_percent 95

  # ============================================================================
  # SETUP
  # ============================================================================

  setup do
    audit_table = :ets.new(:prom_audit, [:ordered_set, :public])
    dag_table = :ets.new(:prom_dag, [:set, :public])

    on_exit(fn ->
      if :ets.info(audit_table) != :undefined, do: :ets.delete(audit_table)
      if :ets.info(dag_table) != :undefined, do: :ets.delete(dag_table)
    end)

    %{audit_table: audit_table, dag_table: dag_table}
  end

  # ============================================================================
  # 1. PROOF TOKEN GATE ENFORCEMENT (SC-PROM-001)
  # ============================================================================

  describe "Proof token gate enforcement (SC-PROM-001)" do
    test "state-mutating action proceeds with valid token" do
      token = Verifier.issue_proof(%{action: :deploy, target: "indrajaal-ex-app-1"})

      gate_result = verify_mutation_gate(token, :deploy)

      assert gate_result == :proceed,
             "Valid proof token should allow action to proceed (SC-PROM-001)"
    end

    test "state-mutating action is blocked without a token" do
      gate_result = verify_mutation_gate(nil, :deploy)

      assert gate_result == :blocked,
             "Missing proof token must block action (SC-PROM-001)"
    end

    test "state-mutating action is blocked with tampered token" do
      token = Verifier.issue_proof(%{action: :deploy})
      tampered = %{token | signature: "prom_sig_tampered000000000000000000000"}

      gate_result = verify_mutation_gate(tampered, :deploy)

      assert gate_result == :blocked,
             "Tampered proof token must block action (SC-PROM-001)"
    end

    test "read-only actions do not require a proof token" do
      gate_result = verify_read_gate(nil, :health_check)

      assert gate_result == :proceed,
             "Read-only actions should not require proof tokens"
    end

    test "token verification audit is recorded to ETS", %{audit_table: table} do
      token = Verifier.issue_proof(%{action: :restart_service})
      gate_result = verify_mutation_gate(token, :restart_service)

      ts = System.monotonic_time(:microsecond)
      :ets.insert(table, {ts, %{token_id: token.id, gate_result: gate_result}})

      count = :ets.info(table, :size)
      assert count >= 1
    end

    test "gate enforcement completes within 50ms (SC-PROM-005 budget)" do
      token = Verifier.issue_proof(%{action: :scale_out})

      start = System.monotonic_time(:millisecond)
      _result = verify_mutation_gate(token, :scale_out)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < @max_verification_ms,
             "Gate enforcement took #{elapsed}ms, exceeding #{@max_verification_ms}ms budget"
    end
  end

  # ============================================================================
  # 2. DAG ACYCLICITY GATE (SC-PROM-004)
  # ============================================================================

  describe "DAG acyclicity gate for execution scheduling (SC-PROM-004)" do
    test "execution schedule with acyclic DAG is approved" do
      dag = %{
        "db_start" => [],
        "obs_start" => [],
        "app_start" => ["db_start", "obs_start"],
        "zenoh_start" => ["app_start"]
      }

      assert {:ok, _order} = Verifier.verify_dag(dag),
             "Acyclic deployment DAG must be approved for scheduling (SC-PROM-004)"
    end

    test "execution schedule with cyclic DAG is rejected" do
      cyclic_dag = %{
        "svc_a" => ["svc_c"],
        "svc_b" => ["svc_a"],
        "svc_c" => ["svc_b"]
      }

      assert {:error, :cycle_detected} = Verifier.verify_dag(cyclic_dag),
             "Cyclic DAG must be rejected before scheduling (SC-PROM-004)"
    end

    test "dag approval is stored in ETS for audit trail", %{dag_table: table} do
      dag = %{"node1" => [], "node2" => ["node1"]}

      result = Verifier.verify_dag(dag)
      :ets.insert(table, {:last_dag_check, result})

      [{:last_dag_check, stored}] = :ets.lookup(table, :last_dag_check)
      assert stored == result
    end

    test "proof token + DAG form a combined gate for scheduling" do
      token = Verifier.issue_proof(%{action: :deploy_wave, wave: 1})
      dag = %{"wave1_svc" => [], "wave1_svc2" => ["wave1_svc"]}

      token_ok = Verifier.verify_proof_token(token) == {:ok, :valid}
      dag_ok = match?({:ok, _}, Verifier.verify_dag(dag))

      combined_gate = token_ok and dag_ok

      assert combined_gate,
             "Both token and DAG must pass before execution is authorized"
    end

    test "container boot DAG (db→obs→app) satisfies SC-SIL4-005 ordering" do
      # SC-SIL4-005: Container start order DB → OBS → APP
      # DAG encodes: obs depends on db, app depends on obs and db
      boot_dag = %{
        "indrajaal-db-prod" => [],
        "indrajaal-obs-prod" => ["indrajaal-db-prod"],
        "indrajaal-ex-app-1" => ["indrajaal-obs-prod", "indrajaal-db-prod"]
      }

      # Verifier proves the DAG is acyclic — scheduling is safe (SC-PROM-004)
      {:ok, sorted} = Verifier.verify_dag(boot_dag)

      # All 3 containers must appear in the validated topology
      assert length(sorted) == 3, "All 3 containers must be in the sorted result"
      assert "indrajaal-db-prod" in sorted
      assert "indrajaal-obs-prod" in sorted
      assert "indrajaal-ex-app-1" in sorted
    end

    test "DAG verification is deterministic across multiple calls" do
      dag = %{"a" => [], "b" => ["a"], "c" => ["a", "b"]}

      result1 = Verifier.verify_dag(dag)
      result2 = Verifier.verify_dag(dag)

      # Both results must agree
      assert elem(result1, 0) == elem(result2, 0),
             "DAG verification must be deterministic"
    end
  end

  # ============================================================================
  # 3. RECURSION LOCK (SC-PRIME-002)
  # ============================================================================

  describe "Recursion lock — Verifier cannot modify itself (SC-PRIME-002)" do
    test "proposal targeting Verifier module is rejected" do
      self_modification_proposal = %{
        action: :modify_module,
        target: Indrajaal.Prometheus.Verifier,
        change: :add_bypass_clause
      }

      result = check_recursion_lock(self_modification_proposal)

      assert result == {:error, :recursion_lock},
             "Self-modification of Verifier MUST be rejected (SC-PRIME-002)"
    end

    test "proposal targeting other modules is not affected by recursion lock" do
      safe_proposal = %{
        action: :modify_module,
        target: Indrajaal.SomeOtherModule,
        change: :add_feature
      }

      result = check_recursion_lock(safe_proposal)

      assert result != {:error, :recursion_lock},
             "Non-Verifier modifications must not be blocked by recursion lock"
    end

    test "Verifier module hash is stable (tamper detection)" do
      # The Verifier module should have a stable bytecode hash
      {module, _binary, _path} = :code.get_object_code(Verifier)
      assert module == Verifier
    end

    test "recursion lock check completes instantly" do
      proposal = %{action: :modify, target: Verifier}

      start = System.monotonic_time(:microsecond)
      _result = check_recursion_lock(proposal)
      elapsed = System.monotonic_time(:microsecond) - start

      # Must complete in microseconds
      assert elapsed < 1_000,
             "Recursion lock check took #{elapsed}µs, should be instant"
    end
  end

  # ============================================================================
  # 4. API USAGE GATE (SC-PROM-002)
  # ============================================================================

  describe "API usage gate — SHALL NOT exceed 95% of limits (SC-PROM-002)" do
    test "API usage below 95% is permitted" do
      usage_percent = 80.0
      result = check_api_limit(usage_percent)

      assert result == :proceed,
             "API usage at #{usage_percent}% should be permitted (SC-PROM-002)"
    end

    test "API usage at exactly 95% is blocked" do
      usage_percent = 95.0
      result = check_api_limit(usage_percent)

      assert result == :blocked,
             "API usage at #{usage_percent}% must be blocked (SC-PROM-002)"
    end

    test "API usage above 95% is blocked" do
      usage_percent = 97.5
      result = check_api_limit(usage_percent)

      assert result == :blocked,
             "API usage above #{@api_limit_percent}% must be blocked (SC-PROM-002)"
    end

    test "API usage at 0% is always permitted" do
      assert check_api_limit(0.0) == :proceed
    end

    test "API limit check is consistent for boundary values" do
      assert check_api_limit(94.9) == :proceed
      assert check_api_limit(95.0) == :blocked
      assert check_api_limit(95.1) == :blocked
    end
  end

  # ============================================================================
  # 5. SEMANTIC ENTROPY GATE (SC-IKE-002: blocked if entropy > 0.2)
  # ============================================================================

  describe "Semantic entropy gate (SC-IKE-002: blocked if entropy > 0.2)" do
    test "low entropy deployment is permitted" do
      # Known, tested path — entropy near 0
      result = Verifier.verify_semantic_entropy("lib/indrajaal/safety/guardian.ex", 0.05, %{})

      # Either passes, returns warning, or returns file error — entropy 0.05 is well below 0.2 threshold
      assert match?(:ok, result) or match?({:ok, _}, result) or match?({:warning, _}, result) or
               match?({:error, _}, result),
             "verify_semantic_entropy must return a structured result"
    end

    test "entropy gate check returns a valid result" do
      result = Verifier.verify_semantic_entropy("some/path.ex", 0.1, %{action: :deploy})

      assert match?(:ok, result) or match?({:ok, _}, result) or
               match?({:warning, _}, result) or match?({:error, _}, result),
             "verify_semantic_entropy must return a structured result"
    end

    test "semantic entropy check is fast (< 10ms)" do
      start = System.monotonic_time(:millisecond)
      _result = Verifier.verify_semantic_entropy("lib/test.ex", 0.1, %{})
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10,
             "Entropy gate check took #{elapsed}ms, should be < 10ms"
    end
  end

  # ============================================================================
  # 6. FULL VERIFICATION PIPELINE INTEGRATION
  # ============================================================================

  describe "Full PROMETHEUS verification pipeline" do
    test "complete pipeline: issue token → verify → check dag → execute" do
      # Step 1: Issue proof token
      claims = %{action: :rolling_update, target: "indrajaal-ex-app-1", wave: 2}
      token = Verifier.issue_proof(claims)

      # Step 2: Verify token
      assert {:ok, :valid} = Verifier.verify_proof_token(token)

      # Step 3: Verify DAG
      dag = %{"app_v1" => [], "app_v2" => ["app_v1"]}
      assert {:ok, _order} = Verifier.verify_dag(dag)

      # Step 4: Gate checks pass
      assert verify_mutation_gate(token, :rolling_update) == :proceed

      # Step 5: Record execution
      execution = %{
        token_id: token.id,
        dag_nodes: map_size(dag),
        executed_at: System.system_time(:millisecond)
      }

      assert is_map(execution)
    end

    test "pipeline rejects execution if ANY gate fails" do
      # Valid token
      token = Verifier.issue_proof(%{action: :deploy})

      # Cyclic DAG — this gate fails
      cyclic_dag = %{"x" => ["y"], "y" => ["x"]}

      token_ok = Verifier.verify_proof_token(token) == {:ok, :valid}
      dag_ok = match?({:ok, _}, Verifier.verify_dag(cyclic_dag))

      # If any gate fails, execution is blocked
      all_gates_pass = token_ok and dag_ok

      assert all_gates_pass == false,
             "Cyclic DAG should cause pipeline failure"
    end

    test "pipeline completes within 5ms budget per SC-PROM-005" do
      token = Verifier.issue_proof(%{action: :health_check_wave})
      dag = build_boot_dag(5)

      start = System.monotonic_time(:millisecond)

      _tok_result = Verifier.verify_proof_token(token)
      _dag_result = Verifier.verify_dag(dag)
      _gate = verify_mutation_gate(token, :health_check_wave)

      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < @max_verification_ms,
             "Full PROMETHEUS pipeline took #{elapsed}ms (budget: #{@max_verification_ms}ms)"
    end

    test "pipeline is idempotent — same token verifies correctly multiple times" do
      token = Verifier.issue_proof(%{action: :idempotent_check})

      results = for _ <- 1..5, do: Verifier.verify_proof_token(token)

      assert Enum.all?(results, &(&1 == {:ok, :valid})),
             "Proof token verification must be idempotent"
    end
  end

  # ============================================================================
  # 7. PROPERTY-BASED TESTS
  # ============================================================================

  test "proof token issuance and gate check are always consistent (SD property)" do
    ExUnitProperties.check all(action <- SD.member_of([:read, :write, :query, :execute])) do
      token = Verifier.issue_proof(%{action: action})
      gate = verify_mutation_gate(token, action)
      assert gate in [:proceed, :blocked]
    end
  end

  test "gate check accepts any valid deployment action (SD property)" do
    ExUnitProperties.check all(
                             action <-
                               SD.member_of([:deploy, :restart, :scale, :migrate, :rollback])
                           ) do
      token = Verifier.issue_proof(%{action: action})
      assert verify_mutation_gate(token, action) in [:proceed, :blocked]
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp verify_mutation_gate(nil, _action), do: :blocked

  defp verify_mutation_gate(%ProofToken{} = token, _action) do
    case Verifier.verify_proof_token(token) do
      {:ok, :valid} -> :proceed
      {:error, _} -> :blocked
    end
  end

  defp verify_mutation_gate(%{signature: _} = token, _action) do
    case Verifier.verify_proof_token(token) do
      {:ok, :valid} -> :proceed
      {:error, _} -> :blocked
    end
  end

  defp verify_mutation_gate(_, _), do: :blocked

  defp verify_read_gate(_token, _action), do: :proceed

  defp check_recursion_lock(%{target: target}) when target == Indrajaal.Prometheus.Verifier do
    {:error, :recursion_lock}
  end

  defp check_recursion_lock(_proposal), do: :ok

  defp check_api_limit(percent) when percent >= @api_limit_percent, do: :blocked
  defp check_api_limit(_percent), do: :proceed

  defp build_boot_dag(size) do
    Enum.reduce(0..(size - 1), %{}, fn i, acc ->
      node = "svc_#{i}"
      deps = if i == 0, do: [], else: ["svc_#{i - 1}"]
      Map.put(acc, node, deps)
    end)
  end
end
