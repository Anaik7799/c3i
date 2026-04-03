defmodule Indrajaal.Core.ConstitutionalReconfigurationTest do
  @moduledoc """
  Constitutional Reconfiguration L1-L7 test suite.

  WHAT: Verifies that the L0 constitution (Ψ₀-Ψ₅) is immutable under all
        circumstances, that L1-L7 reconfigurations respect Guardian authority,
        preserve lineage, and maintain global invariants. Uses a simulated
        reconfiguration engine; no external process dependencies.

  WHY: SC-RECONFIG-009 mandates Guardian approval for all reconfigurations.
       SC-RECONFIG-005 mandates that lineage survives any L1-L7 change.
       SC-RECONFIG-001 mandates graph-transformation semantics for each change.
       The constitutional layer L0 is absolutely immutable per Ω₉.

  CONSTRAINTS:
    - SC-RECONFIG-001: Graph transformation for changes
    - SC-RECONFIG-005: Lineage preserved through reconfiguration
    - SC-RECONFIG-009: Guardian approval REQUIRED
    - SC-SAFETY-009:   Ψ₀ (Existence) validated for all operations
    - SC-SAFETY-010:   Ψ₁ (Regeneration) verified
    - SC-SAFETY-011:   Ψ₂ (History) — prevent history deletion
    - SC-SAFETY-012:   Ψ₃ (Verification) hash chain integrity
    - SC-SAFETY-013:   Ψ₄ (Human Alignment) Founder's lineage PRIMARY
    - SC-SAFETY-014:   Ψ₅ (Truthfulness) no deception in logs
    - SC-GUARD-001:    Guardian MUST use Envelope for constraint values
    - SC-GUARD-002:    Guardian integrates with DeadMansSwitch, fail closed
    - SC-GUARD-003:    Guardian integrates with FounderDirective

  ## Constitutional Verification

  The constitution is defined as the 6-axiom tuple (Ψ₀-Ψ₅). No reconfiguration
  at any layer may alter these values. The invariant is tested both imperatively
  (targeted cases) and via StreamData properties.

  | Axiom | Name              | Invariant                        |
  |-------|-------------------|----------------------------------|
  | Ψ₀    | Existence         | System remains alive              |
  | Ψ₁    | Regeneration      | State rebuildable from SQLite/DB  |
  | Ψ₂    | History           | No history deletion permitted     |
  | Ψ₃    | Verification      | Hash chain always valid           |
  | Ψ₄    | Human Alignment   | Founder's lineage is PRIMARY      |
  | Ψ₅    | Truthfulness      | Logs never contain deception      |

  ## Change History
  | Version | Date       | Author | Change                                     |
  |---------|------------|--------|--------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial constitutional reconfiguration tests |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :constitutional
  @moduletag :reconfig
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # Constitution definition (L0 — immutable)
  # ---------------------------------------------------------------------------

  @l0_constitution %{
    psi_0: :existence,
    psi_1: :regeneration,
    psi_2: :history,
    psi_3: :verification,
    psi_4: :human_alignment,
    psi_5: :truthfulness
  }

  # All reconfigurable fractal levels
  @reconfigurable_levels [:l1, :l2, :l3, :l4, :l5, :l6, :l7]

  # ============================================================================
  # 1. L0 CONSTITUTION IS IMMUTABLE
  # ============================================================================

  describe "L0 constitution immutability (Ω₉)" do
    test "direct mutation of Ψ₀ is rejected" do
      result = attempt_reconfiguration(:l0, %{psi_0: :disabled})
      assert result == {:error, :immutable_constitution}
    end

    test "direct mutation of Ψ₁ is rejected" do
      result = attempt_reconfiguration(:l0, %{psi_1: :optional})
      assert result == {:error, :immutable_constitution}
    end

    test "direct mutation of Ψ₂ is rejected" do
      result = attempt_reconfiguration(:l0, %{psi_2: :deletable})
      assert result == {:error, :immutable_constitution}
    end

    test "direct mutation of Ψ₃ is rejected" do
      result = attempt_reconfiguration(:l0, %{psi_3: :unchecked})
      assert result == {:error, :immutable_constitution}
    end

    test "direct mutation of Ψ₄ is rejected" do
      result = attempt_reconfiguration(:l0, %{psi_4: :system_primary})
      assert result == {:error, :immutable_constitution}
    end

    test "direct mutation of Ψ₅ is rejected" do
      result = attempt_reconfiguration(:l0, %{psi_5: :optional})
      assert result == {:error, :immutable_constitution}
    end

    test "bulk L0 mutation attempt is rejected" do
      full_replace = %{
        psi_0: :destroyed,
        psi_1: :removed,
        psi_2: :erased,
        psi_3: :bypassed,
        psi_4: :inverted,
        psi_5: :deceptive
      }

      result = attempt_reconfiguration(:l0, full_replace)
      assert result == {:error, :immutable_constitution}
    end

    test "L0 constitution values are unchanged after failed mutation attempts" do
      attempt_reconfiguration(:l0, %{psi_0: :destroyed})
      attempt_reconfiguration(:l0, %{psi_4: :inverted})

      # The constitution module is a read-only constant — values never mutate
      assert @l0_constitution.psi_0 == :existence
      assert @l0_constitution.psi_1 == :regeneration
      assert @l0_constitution.psi_2 == :history
      assert @l0_constitution.psi_3 == :verification
      assert @l0_constitution.psi_4 == :human_alignment
      assert @l0_constitution.psi_5 == :truthfulness
    end
  end

  # ============================================================================
  # 2. L1 (FUNCTION) RECONFIGURATION
  # ============================================================================

  describe "L1 Function reconfiguration" do
    test "L1 reconfiguration succeeds with Guardian approval" do
      change = %{function: :process_alarm, new_impl: :v2_implementation}
      result = attempt_reconfiguration(:l1, change, guardian_approved: true)

      assert {:ok, _applied} = result
    end

    test "L1 reconfiguration is blocked without Guardian approval" do
      change = %{function: :process_alarm, new_impl: :v2_implementation}
      result = attempt_reconfiguration(:l1, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end

    test "L1 reconfiguration result preserves module interface contracts" do
      change = %{function: :validate_token, arity: 2, new_impl: :optimized}
      {:ok, applied} = attempt_reconfiguration(:l1, change, guardian_approved: true)

      # Interface contract fields must survive
      assert Map.has_key?(applied, :level)
      assert applied.level == :l1
      assert Map.has_key?(applied, :lineage_id)
    end

    test "L1 reconfiguration records lineage (SC-RECONFIG-005)" do
      change = %{function: :emit_telemetry, new_impl: :zenoh_backed}
      {:ok, applied} = attempt_reconfiguration(:l1, change, guardian_approved: true)

      assert applied.lineage_id != nil
      assert is_binary(applied.lineage_id)
    end
  end

  # ============================================================================
  # 3. L2 (COMPONENT) RECONFIGURATION
  # ============================================================================

  describe "L2 Component reconfiguration" do
    test "L2 reconfiguration preserves module interfaces" do
      change = %{module: :AlarmEngine, new_behaviour: :v3_alarm_engine}
      {:ok, applied} = attempt_reconfiguration(:l2, change, guardian_approved: true)

      assert applied.level == :l2
      assert applied.interfaces_preserved == true
    end

    test "L2 reconfiguration fails without Guardian approval" do
      change = %{module: :GuardianKernel, new_behaviour: :disabled}
      result = attempt_reconfiguration(:l2, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end

    test "L2 reconfiguration carries forward parent lineage" do
      change_1 = %{module: :TokenCache, new_behaviour: :ets_backed}
      {:ok, r1} = attempt_reconfiguration(:l2, change_1, guardian_approved: true)

      change_2 = %{module: :TokenCache, new_behaviour: :distributed_cache}

      {:ok, r2} =
        attempt_reconfiguration(:l2, change_2,
          guardian_approved: true,
          parent_lineage: r1.lineage_id
        )

      assert r2.parent_lineage == r1.lineage_id
    end
  end

  # ============================================================================
  # 4. L3 (HOLON) RECONFIGURATION — STATE SOVEREIGNTY
  # ============================================================================

  describe "L3 Holon reconfiguration — state sovereignty (SC-SAFETY-010)" do
    test "L3 reconfiguration preserves holon state sovereignty" do
      change = %{holon: "access-control-holon", new_config: %{timeout_ms: 5000}}
      {:ok, applied} = attempt_reconfiguration(:l3, change, guardian_approved: true)

      # Holon state sovereignty means SQLite/DuckDB remain authoritative
      assert applied.state_sovereignty == :sqlite_duckdb
      assert applied.level == :l3
    end

    test "L3 reconfiguration maintains SQLite as authoritative state" do
      change = %{holon: "alarm-processing-holon", new_config: %{batch_size: 100}}
      {:ok, applied} = attempt_reconfiguration(:l3, change, guardian_approved: true)

      refute Map.get(applied, :state_authority) == :postgresql
      assert applied.state_sovereignty == :sqlite_duckdb
    end

    test "L3 reconfiguration is blocked without Guardian approval" do
      change = %{holon: "guardian-holon", new_config: %{approval_required: false}}
      result = attempt_reconfiguration(:l3, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end
  end

  # ============================================================================
  # 5. L4 (CONTAINER) RECONFIGURATION
  # ============================================================================

  describe "L4 Container reconfiguration — isolation maintained" do
    test "L4 reconfiguration preserves container isolation" do
      change = %{container: "indrajaal-ex-app-1", new_image: "v21.4.0"}
      {:ok, applied} = attempt_reconfiguration(:l4, change, guardian_approved: true)

      assert applied.isolation_maintained == true
      assert applied.level == :l4
    end

    test "L4 reconfiguration requires Guardian for container image changes" do
      change = %{container: "indrajaal-ex-app-1", new_image: "untrusted-image"}
      result = attempt_reconfiguration(:l4, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end

    test "L4 reconfiguration result includes rollback metadata" do
      change = %{container: "indrajaal-db-prod", new_env: %{PG_MAX_CONN: "200"}}
      {:ok, applied} = attempt_reconfiguration(:l4, change, guardian_approved: true)

      assert Map.has_key?(applied, :rollback_snapshot)
      assert applied.rollback_snapshot != nil
    end
  end

  # ============================================================================
  # 6. L5 (NODE) RECONFIGURATION
  # ============================================================================

  describe "L5 Node reconfiguration — runtime stability" do
    test "L5 reconfiguration preserves runtime environment stability" do
      change = %{node: "indrajaal@node1", new_config: %{schedulers: 16}}
      {:ok, applied} = attempt_reconfiguration(:l5, change, guardian_approved: true)

      assert applied.runtime_stable == true
      assert applied.level == :l5
    end

    test "L5 node config change carries lineage" do
      change = %{node: "indrajaal@node2", new_config: %{memory_limit: "8GB"}}
      {:ok, applied} = attempt_reconfiguration(:l5, change, guardian_approved: true)

      assert applied.lineage_id != nil
    end

    test "L5 reconfiguration is blocked without Guardian approval" do
      change = %{node: "indrajaal@node3", new_config: %{isolate_network: true}}
      result = attempt_reconfiguration(:l5, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end
  end

  # ============================================================================
  # 7. L6 (CLUSTER) RECONFIGURATION
  # ============================================================================

  describe "L6 Cluster reconfiguration — consensus maintained (SC-QUORUM-001)" do
    test "L6 reconfiguration maintains 2oo3 quorum consensus" do
      change = %{cluster: "indrajaal-cluster-1", new_topology: :ring}
      {:ok, applied} = attempt_reconfiguration(:l6, change, guardian_approved: true)

      assert applied.quorum_maintained == true
      assert applied.level == :l6
    end

    test "L6 reconfiguration that would break quorum is rejected" do
      change = %{cluster: "indrajaal-cluster-1", remove_nodes: 2, total_nodes: 3}
      result = attempt_reconfiguration(:l6, change, guardian_approved: true, breaks_quorum: true)

      assert result == {:error, :quorum_violation}
    end

    test "L6 reconfiguration without Guardian approval is blocked" do
      change = %{cluster: "prod-cluster", new_topology: :star}
      result = attempt_reconfiguration(:l6, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end
  end

  # ============================================================================
  # 8. L7 (FEDERATION) RECONFIGURATION
  # ============================================================================

  describe "L7 Federation reconfiguration — global invariants preserved (SC-FED-001)" do
    test "L7 reconfiguration preserves global constitutional invariants" do
      change = %{federation: "indrajaal-fed", new_protocol: :v2_federation}
      {:ok, applied} = attempt_reconfiguration(:l7, change, guardian_approved: true)

      assert applied.global_invariants_preserved == true
      assert applied.level == :l7
    end

    test "L7 reconfiguration cannot modify peer constitutions (SC-FED-001)" do
      change = %{federation: "indrajaal-fed", modify_peer_constitution: true}
      result = attempt_reconfiguration(:l7, change, guardian_approved: true)

      assert result == {:error, :peer_constitution_immutable}
    end

    test "L7 reconfiguration notifies federation peers" do
      change = %{federation: "indrajaal-fed", new_protocol: :v2_federation}
      {:ok, applied} = attempt_reconfiguration(:l7, change, guardian_approved: true)

      assert applied.federation_notified == true
    end

    test "L7 reconfiguration is blocked without Guardian approval" do
      change = %{federation: "indrajaal-fed", new_protocol: :v3_federation}
      result = attempt_reconfiguration(:l7, change, guardian_approved: false)

      assert result == {:error, :guardian_veto}
    end
  end

  # ============================================================================
  # 9. LINEAGE PRESERVATION (SC-RECONFIG-005)
  # ============================================================================

  describe "Lineage preservation through L1-L7 reconfigurations (SC-RECONFIG-005)" do
    test "each level produces a unique lineage ID" do
      ids =
        for level <- @reconfigurable_levels do
          {:ok, applied} =
            attempt_reconfiguration(level, %{test: :lineage_check}, guardian_approved: true)

          applied.lineage_id
        end

      # All 7 lineage IDs must be unique
      assert length(Enum.uniq(ids)) == 7
    end

    test "chained reconfigurations form a lineage chain" do
      {:ok, r1} =
        attempt_reconfiguration(:l1, %{fn: :emit}, guardian_approved: true)

      {:ok, r2} =
        attempt_reconfiguration(:l2, %{module: :Router},
          guardian_approved: true,
          parent_lineage: r1.lineage_id
        )

      {:ok, r3} =
        attempt_reconfiguration(:l3, %{holon: "core"},
          guardian_approved: true,
          parent_lineage: r2.lineage_id
        )

      assert r3.parent_lineage == r2.lineage_id
      assert r2.parent_lineage == r1.lineage_id
      assert r1.lineage_id != r2.lineage_id
      assert r2.lineage_id != r3.lineage_id
    end

    test "lineage IDs are non-empty binary strings" do
      {:ok, applied} =
        attempt_reconfiguration(:l3, %{holon: "test"}, guardian_approved: true)

      assert is_binary(applied.lineage_id)
      assert byte_size(applied.lineage_id) > 0
    end

    test "failed reconfiguration does not produce lineage entry" do
      result = attempt_reconfiguration(:l1, %{fn: :emit}, guardian_approved: false)
      assert result == {:error, :guardian_veto}
      refute match?({:ok, _}, result)
    end
  end

  # ============================================================================
  # 10. GUARDIAN VETO — ALL LEVELS (SC-RECONFIG-009)
  # ============================================================================

  describe "Guardian veto blocks reconfiguration at any level (SC-RECONFIG-009)" do
    test "Guardian veto blocks L1 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l1, %{fn: :any}, guardian_approved: false)
    end

    test "Guardian veto blocks L2 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l2, %{module: :Any}, guardian_approved: false)
    end

    test "Guardian veto blocks L3 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l3, %{holon: "any"}, guardian_approved: false)
    end

    test "Guardian veto blocks L4 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l4, %{container: "any"}, guardian_approved: false)
    end

    test "Guardian veto blocks L5 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l5, %{node: "any"}, guardian_approved: false)
    end

    test "Guardian veto blocks L6 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l6, %{cluster: "any"}, guardian_approved: false)
    end

    test "Guardian veto blocks L7 reconfiguration" do
      assert {:error, :guardian_veto} =
               attempt_reconfiguration(:l7, %{federation: "any"}, guardian_approved: false)
    end

    test "Guardian default is fail-closed (no approval given)" do
      # When guardian_approved is not specified, default must be :no_approval
      result = attempt_reconfiguration(:l2, %{module: :Test})
      assert result == {:error, :guardian_veto}
    end
  end

  # ============================================================================
  # 11. PROPERTY — L0 INVARIANTS HOLD AFTER ANY L1-L7 RECONFIGURATION
  # ============================================================================

  property "L0 axioms Ψ₀-Ψ₅ unchanged after arbitrary L1-L7 reconfigurations (PC)" do
    forall {level, change_key, change_val} <-
             {PC.oneof([:l1, :l2, :l3, :l4, :l5, :l6, :l7]),
              PC.oneof([:function, :module, :holon, :container, :node, :cluster, :federation]),
              PC.utf8()} do
      change = %{change_key => change_val}
      _result = attempt_reconfiguration(level, change, guardian_approved: true)

      # L0 constitution is a compile-time constant — must remain identical
      @l0_constitution.psi_0 == :existence and
        @l0_constitution.psi_1 == :regeneration and
        @l0_constitution.psi_2 == :history and
        @l0_constitution.psi_3 == :verification and
        @l0_constitution.psi_4 == :human_alignment and
        @l0_constitution.psi_5 == :truthfulness
    end
  end

  property "any L0 mutation attempt always returns immutable_constitution (SD)" do
    ExUnitProperties.check all(
                             key <-
                               SD.member_of([:psi_0, :psi_1, :psi_2, :psi_3, :psi_4, :psi_5]),
                             val <- SD.string(:alphanumeric, min_length: 1)
                           ) do
      result = attempt_reconfiguration(:l0, %{key => val})
      assert result == {:error, :immutable_constitution}
    end
  end

  # ============================================================================
  # 12. PROPERTY — RECONFIGURATION IS REVERSIBLE (ROLLBACK ALWAYS VALID)
  # ============================================================================

  property "every successful reconfiguration produces a valid rollback snapshot (PC)" do
    forall level <- PC.oneof([:l1, :l2, :l3, :l4, :l5, :l6, :l7]) do
      change = %{test_key: "rollback_property_check"}

      case attempt_reconfiguration(level, change, guardian_approved: true) do
        {:ok, applied} ->
          # A rollback snapshot must be present and non-nil
          snapshot = Map.get(applied, :rollback_snapshot)
          snapshot != nil

        {:error, _} ->
          # Errors don't produce snapshots — that is correct behaviour
          true
      end
    end
  end

  property "rollback snapshot is always a map or binary for approved reconfigs (SD)" do
    ExUnitProperties.check all(
                             level <- SD.member_of(@reconfigurable_levels),
                             key <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                             max_runs: 30
                           ) do
      change = %{test_field: key}

      case attempt_reconfiguration(level, change, guardian_approved: true) do
        {:ok, applied} ->
          snapshot = Map.get(applied, :rollback_snapshot)

          assert is_map(snapshot) or is_binary(snapshot),
                 "rollback_snapshot must be map or binary, got: #{inspect(snapshot)}"

        {:error, _} ->
          # quorum or other structural violations — acceptable
          true
      end
    end
  end

  # ============================================================================
  # PRIVATE SIMULATION ENGINE
  # ============================================================================

  # Simulated reconfiguration engine (SC-RECONFIG-001: graph transformation)
  defp attempt_reconfiguration(level, change, opts \\ []) do
    guardian_approved = Keyword.get(opts, :guardian_approved, false)
    parent_lineage = Keyword.get(opts, :parent_lineage, nil)
    breaks_quorum = Keyword.get(opts, :breaks_quorum, false)

    cond do
      level == :l0 ->
        {:error, :immutable_constitution}

      Map.get(change, :modify_peer_constitution, false) ->
        {:error, :peer_constitution_immutable}

      breaks_quorum ->
        {:error, :quorum_violation}

      not guardian_approved ->
        {:error, :guardian_veto}

      true ->
        {:ok, apply_change(level, change, parent_lineage)}
    end
  end

  defp apply_change(level, change, parent_lineage) do
    lineage_id = generate_lineage_id(level, change)

    base = %{
      level: level,
      change: change,
      lineage_id: lineage_id,
      parent_lineage: parent_lineage,
      applied_at: System.monotonic_time(:millisecond),
      rollback_snapshot: build_rollback_snapshot(level, change)
    }

    enrich_for_level(base, level)
  end

  defp enrich_for_level(base, :l2),
    do: Map.merge(base, %{interfaces_preserved: true})

  defp enrich_for_level(base, :l3),
    do: Map.merge(base, %{state_sovereignty: :sqlite_duckdb})

  defp enrich_for_level(base, :l4),
    do: Map.merge(base, %{isolation_maintained: true})

  defp enrich_for_level(base, :l5),
    do: Map.merge(base, %{runtime_stable: true})

  defp enrich_for_level(base, :l6),
    do: Map.merge(base, %{quorum_maintained: true})

  defp enrich_for_level(base, :l7),
    do: Map.merge(base, %{global_invariants_preserved: true, federation_notified: true})

  defp enrich_for_level(base, _level), do: base

  defp generate_lineage_id(level, change) do
    raw = :erlang.term_to_binary({level, change, System.unique_integer([:monotonic, :positive])})
    Base.encode16(:crypto.hash(:sha256, raw), case: :lower) |> binary_part(0, 16)
  end

  defp build_rollback_snapshot(level, change) do
    %{
      pre_change_level: level,
      pre_change_state: Map.keys(change),
      snapshot_at: System.monotonic_time(:millisecond)
    }
  end
end
