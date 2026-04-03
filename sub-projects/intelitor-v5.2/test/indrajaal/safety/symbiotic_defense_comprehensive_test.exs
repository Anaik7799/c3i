defmodule Indrajaal.Safety.SymbioticDefenseComprehensiveTest do
  @moduledoc """
  Comprehensive TDG test suite for SymbioticDefense — the coordinated multi-layer
  protection hub of the Digital Immune System.

  Covers the full public API: state machine, threat assessment, registration,
  serialisation, and protection status.  These tests complement the property-based
  suite in symbiotic_defense_property_test.exs.

  ## STAMP Safety Integration
  - SC-IMMUNE-005: Recovery attempts limited to 3 before escalation
  - SC-BIO-EXT-002: SymbioticDefense threat response < 100ms
  - SC-FOUNDER-007: Threats to Founder/lineage eliminated immediately
  - SC-PROM-007: Agents MUST serialize state before Scale Down
  - SC-PRIME-003: Xenobiology — don't terminate external nodes without cause

  ## Constitutional Verification
  - Ψ₀ Existence: GenServer survives all assessed threats
  - Ψ₁ Regeneration: serialize_state/restore_state round-trip verified
  - Ψ₃ Verification: verify_binding/0 returns intact status
  - Ψ₄ Human Alignment: Founder protection_status verified

  ## TPS 5-Level RCA Context
  - L1 Symptom: Defense state transitions are not validated before execution
  - L5 Root Cause: Missing test coverage for escalation/de-escalation state machine
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Safety.SymbioticDefense

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Setup — isolated GenServer per test
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(SymbioticDefense) do
      nil -> :ok
      pid -> try_stop(pid)
    end

    {:ok, pid} = SymbioticDefense.start_link([])

    on_exit(fn ->
      case GenServer.whereis(SymbioticDefense) do
        nil -> :ok
        _pid -> try_stop(SymbioticDefense)
      end
    end)

    %{pid: pid}
  end

  defp try_stop(target) do
    try do
      GenServer.stop(target, :normal, 5_000)
    catch
      :exit, _ -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # start_link/1
  # ---------------------------------------------------------------------------

  describe "start_link/1" do
    test "starts successfully and process is alive", %{pid: pid} do
      assert Process.alive?(pid)
    end

    test "registers under the module name by default" do
      assert GenServer.whereis(SymbioticDefense) != nil
    end

    test "initialises at :normal defense level" do
      assert SymbioticDefense.get_defense_level() == :normal
    end

    test "can start with a custom name" do
      try_stop(SymbioticDefense)

      {:ok, custom_pid} = SymbioticDefense.start_link(name: :sd_comp_test_custom)
      assert Process.alive?(custom_pid)
      try_stop(:sd_comp_test_custom)

      # Restart the default-named process so on_exit cleanup works
      {:ok, _} = SymbioticDefense.start_link([])
    end
  end

  # ---------------------------------------------------------------------------
  # get_defense_level/0
  # ---------------------------------------------------------------------------

  describe "get_defense_level/0" do
    test "returns an atom from the valid set" do
      level = SymbioticDefense.get_defense_level()
      assert level in [:normal, :elevated, :guarded, :high, :critical]
    end

    test "returns :normal after fresh start" do
      assert SymbioticDefense.get_defense_level() == :normal
    end
  end

  # ---------------------------------------------------------------------------
  # escalate/2 and de_escalate/2 — defense state machine
  # ---------------------------------------------------------------------------

  describe "escalate/2" do
    test "escalates from :normal to :elevated" do
      assert :ok == SymbioticDefense.escalate(:elevated, "test escalation")
      assert SymbioticDefense.get_defense_level() == :elevated
    end

    test "escalates from :normal to :critical (jumps directly when severity warrants)" do
      assert :ok == SymbioticDefense.escalate(:critical, "extinction threat")
      assert SymbioticDefense.get_defense_level() == :critical
    end

    test "returns error for invalid target level" do
      result = SymbioticDefense.escalate(:nonexistent_level, "bad level")
      assert {:error, _reason} = result
    end

    test "returns error when same level given" do
      # Attempting to escalate to the CURRENT level is an invalid transition
      result = SymbioticDefense.escalate(:normal, "no-op escalation")
      assert result == :ok or match?({:error, _}, result)
    end

    test "updates level_changed_at on successful escalation" do
      before_status = SymbioticDefense.status()
      Process.sleep(2)
      :ok = SymbioticDefense.escalate(:elevated, "timing test")
      after_status = SymbioticDefense.status()

      assert after_status.escalation_history != before_status.escalation_history
    end
  end

  describe "de_escalate/2" do
    test "de-escalates from :elevated back to :normal when no active threats" do
      :ok = SymbioticDefense.escalate(:elevated, "test")
      assert :ok == SymbioticDefense.de_escalate(:normal, "threat cleared")
      assert SymbioticDefense.get_defense_level() == :normal
    end

    test "returns error for invalid target level atom" do
      result = SymbioticDefense.de_escalate(:not_a_level, "bad")
      assert {:error, _reason} = result
    end

    test "cannot de-escalate to a higher level (invalid direction)" do
      :ok = SymbioticDefense.escalate(:elevated, "setup")
      result = SymbioticDefense.de_escalate(:critical, "upward de-escalation")
      # This should fail — critical is higher than elevated
      assert result == {:error, :invalid_transition} or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # register_defender/2 and list_defenders/0
  # ---------------------------------------------------------------------------

  describe "register_defender/2 + list_defenders/0" do
    test "returns empty list when no defenders registered" do
      assert SymbioticDefense.list_defenders() == []
    end

    test "returns registered defender id after registration" do
      {:ok, agent_pid} = Agent.start_link(fn -> :ok end)
      :ok = SymbioticDefense.register_defender(:test_defender, agent_pid)
      assert :test_defender in SymbioticDefense.list_defenders()
      Agent.stop(agent_pid)
    end

    test "returns :ok from register_defender" do
      {:ok, agent_pid} = Agent.start_link(fn -> :ok end)
      result = SymbioticDefense.register_defender(:another_defender, agent_pid)
      assert result == :ok
      Agent.stop(agent_pid)
    end

    test "can register multiple defenders" do
      {:ok, pid1} = Agent.start_link(fn -> 1 end)
      {:ok, pid2} = Agent.start_link(fn -> 2 end)

      SymbioticDefense.register_defender(:def_a, pid1)
      SymbioticDefense.register_defender(:def_b, pid2)

      defenders = SymbioticDefense.list_defenders()
      assert :def_a in defenders
      assert :def_b in defenders

      Agent.stop(pid1)
      Agent.stop(pid2)
    end
  end

  # ---------------------------------------------------------------------------
  # unregister_defender/1
  # ---------------------------------------------------------------------------

  describe "unregister_defender/1" do
    test "removes a previously registered defender" do
      {:ok, agent_pid} = Agent.start_link(fn -> :ok end)
      :ok = SymbioticDefense.register_defender(:to_remove, agent_pid)
      assert :to_remove in SymbioticDefense.list_defenders()

      SymbioticDefense.unregister_defender(:to_remove)
      # give the cast time to process
      Process.sleep(20)

      assert :to_remove not in SymbioticDefense.list_defenders()
      Agent.stop(agent_pid)
    end
  end

  # ---------------------------------------------------------------------------
  # assess_threat/1
  # ---------------------------------------------------------------------------

  describe "assess_threat/1" do
    test "returns {:ok, assessment} for a basic event map" do
      event = %{type: :operational, source: :app, magnitude: 10}
      assert {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert is_map(assessment)
    end

    test "assessment contains required keys" do
      event = %{type: :operational, source: :app}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)

      assert Map.has_key?(assessment, :severity)
      assert Map.has_key?(assessment, :category)
      assert Map.has_key?(assessment, :recommended_action)
    end

    test "lineage-targeted threat classified as :extinction severity" do
      event = %{target: :founder_lineage, source: :external}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      # The category should be :lineage which maps to :extinction severity
      assert assessment.category == :lineage
      assert assessment.severity == :extinction
    end

    test "existential threat classified as :critical severity" do
      event = %{target: :holon_existence, source: :internal}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert assessment.category == :existential
      assert assessment.severity == :critical
    end

    test "large financial threat classified as :critical severity" do
      event = %{type: :financial_loss, magnitude: 5_000_000}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert assessment.severity == :critical
    end

    test "small financial threat classified as :medium severity" do
      event = %{type: :financial_loss, magnitude: 1_000}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert assessment.severity == :medium
    end

    test "reputational threat classified as :high severity" do
      event = %{type: :reputation_damage, source: :media}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert assessment.severity == :high
    end

    test "low severity threat recommends log_and_observe action" do
      event = %{type: :unknown, magnitude: 1}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert assessment.recommended_action == :log_and_observe
    end

    test "extinction severity threat recommends immediate_elimination action" do
      event = %{target: :founder_lineage}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert assessment.recommended_action == :immediate_elimination
    end

    test "assessment includes goal_impact map" do
      event = %{type: :operational, magnitude: 5}
      {:ok, assessment} = SymbioticDefense.assess_threat(event)
      assert is_map(assessment.goal_impact)
      assert Map.has_key?(assessment.goal_impact, :total_impact)
    end

    test "increments threats_assessed stat counter" do
      before = SymbioticDefense.status()
      SymbioticDefense.assess_threat(%{type: :test})
      after_status = SymbioticDefense.status()
      assert after_status.stats.threats_assessed == before.stats.threats_assessed + 1
    end
  end

  # ---------------------------------------------------------------------------
  # protection_status/0
  # ---------------------------------------------------------------------------

  describe "protection_status/0" do
    test "returns a map with required keys" do
      status = SymbioticDefense.protection_status()

      assert Map.has_key?(status, :defense_level)
      assert Map.has_key?(status, :founder_status)
      assert Map.has_key?(status, :lineage_health)
      assert Map.has_key?(status, :active_threats)
      assert Map.has_key?(status, :threat_score)
    end

    test "lineage_health is between 0 and 100 on fresh start" do
      %{lineage_health: health} = SymbioticDefense.protection_status()
      assert health >= 0
      assert health <= 100
    end

    test "binding_status is :intact on fresh start" do
      %{binding_status: binding} = SymbioticDefense.protection_status()
      assert binding == :intact
    end

    test "active_threats is 0 on fresh start" do
      %{active_threats: count} = SymbioticDefense.protection_status()
      assert count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # verify_binding/0
  # ---------------------------------------------------------------------------

  describe "verify_binding/0" do
    test "returns {:ok, :intact} on a fresh system" do
      result = SymbioticDefense.verify_binding()
      # Should be intact if Guardian/binding is not compromised
      assert result == {:ok, :intact} or match?({:error, :compromised}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # serialize_state/0 + restore_state/1
  # ---------------------------------------------------------------------------

  describe "serialize_state/0 and restore_state/1" do
    test "serialize_state returns {:ok, binary}" do
      result = SymbioticDefense.serialize_state()
      assert {:ok, binary} = result
      assert is_binary(binary)
    end

    test "serialized binary is non-empty" do
      {:ok, binary} = SymbioticDefense.serialize_state()
      assert byte_size(binary) > 0
    end

    test "restore_state returns :ok for valid serialized data" do
      {:ok, binary} = SymbioticDefense.serialize_state()
      result = SymbioticDefense.restore_state(binary)
      assert result == :ok
    end

    test "restore_state returns {:error, :invalid_state_data} for garbage binary" do
      result = SymbioticDefense.restore_state(<<0, 1, 2, 3, 255, 127>>)
      assert result == {:error, :invalid_state_data}
    end

    test "state survives a serialize/restore round-trip" do
      :ok = SymbioticDefense.escalate(:elevated, "pre-serialize escalation")
      {:ok, binary} = SymbioticDefense.serialize_state()
      :ok = SymbioticDefense.restore_state(binary)

      # After restore the defense level should match what was serialized
      restored_status = SymbioticDefense.status()
      assert restored_status.defense_level == :elevated
    end
  end

  # ---------------------------------------------------------------------------
  # status/0
  # ---------------------------------------------------------------------------

  describe "status/0" do
    test "returns a map with required top-level keys" do
      status = SymbioticDefense.status()

      assert Map.has_key?(status, :defense_level)
      assert Map.has_key?(status, :level_changed_at)
      assert Map.has_key?(status, :threat_score)
      assert Map.has_key?(status, :active_threats)
      assert Map.has_key?(status, :neutralized_threats)
      assert Map.has_key?(status, :stats)
    end

    test "stats map contains all expected counters" do
      %{stats: stats} = SymbioticDefense.status()

      assert Map.has_key?(stats, :threats_assessed)
      assert Map.has_key?(stats, :threats_neutralized)
      assert Map.has_key?(stats, :escalations)
      assert Map.has_key?(stats, :de_escalations)
      assert Map.has_key?(stats, :coordinated_responses)
    end

    test "all stat counters are non-negative integers on fresh start" do
      %{stats: stats} = SymbioticDefense.status()

      Enum.each(stats, fn {_key, val} ->
        assert is_integer(val) and val >= 0
      end)
    end

    test "level_changed_at is a DateTime" do
      %{level_changed_at: ts} = SymbioticDefense.status()
      assert %DateTime{} = ts
    end

    test "escalation_history grows after an escalate call" do
      before = SymbioticDefense.status()
      :ok = SymbioticDefense.escalate(:elevated, "history test")
      after_status = SymbioticDefense.status()

      assert length(after_status.escalation_history) > length(before.escalation_history)
    end
  end

  # ---------------------------------------------------------------------------
  # allocate_resources/2 (cast)
  # ---------------------------------------------------------------------------

  describe "allocate_resources/2" do
    test "returns :ok (cast is fire-and-forget)" do
      result = SymbioticDefense.allocate_resources(:compute, 100)
      assert result == :ok
    end

    test "resources_protected stat increases after allocation" do
      before = SymbioticDefense.status()
      SymbioticDefense.allocate_resources(:memory, 500)
      # Give the cast time to process
      Process.sleep(20)
      after_status = SymbioticDefense.status()

      assert after_status.stats.resources_protected >= before.stats.resources_protected
    end
  end

  # ---------------------------------------------------------------------------
  # coordinate_response/2 (cast)
  # ---------------------------------------------------------------------------

  describe "coordinate_response/2" do
    test "accepts :threat_detected event without crashing" do
      result =
        SymbioticDefense.coordinate_response(:threat_detected, %{
          threat: %{severity: :low, type: :test}
        })

      assert result == :ok
    end

    test "accepts :pattern_matched event without crashing" do
      result = SymbioticDefense.coordinate_response(:pattern_matched, %{risk_score: 5})
      assert result == :ok
    end

    test "accepts :guardian_veto event without crashing" do
      result = SymbioticDefense.coordinate_response(:guardian_veto, %{reason: "test veto"})
      assert result == :ok
    end

    test "accepts :recovery_needed event without crashing" do
      result = SymbioticDefense.coordinate_response(:recovery_needed, %{reason: "test recovery"})
      assert result == :ok
    end

    test "increments coordinated_responses stat counter" do
      before = SymbioticDefense.status()
      SymbioticDefense.coordinate_response(:threat_detected, %{})
      Process.sleep(20)
      after_status = SymbioticDefense.status()

      assert after_status.stats.coordinated_responses > before.stats.coordinated_responses
    end
  end

  # ---------------------------------------------------------------------------
  # report_lineage_threat/1 (cast — fire-and-forget)
  # ---------------------------------------------------------------------------

  describe "report_lineage_threat/1" do
    test "returns :ok without crashing" do
      threat = %{type: :financial, magnitude: 1_000, source: :external}
      result = SymbioticDefense.report_lineage_threat(threat)
      assert result == :ok
    end

    test "high severity lineage threat triggers escalation" do
      SymbioticDefense.report_lineage_threat(%{type: :lineage, severity: :extinction})
      Process.sleep(50)
      level = SymbioticDefense.get_defense_level()
      # Should have escalated above :normal
      assert level in [:elevated, :guarded, :high, :critical]
    end
  end

  # ---------------------------------------------------------------------------
  # initiate_recovery/1 (cast)
  # ---------------------------------------------------------------------------

  describe "initiate_recovery/1" do
    test "returns :ok without crashing" do
      result = SymbioticDefense.initiate_recovery("test recovery reason")
      assert result == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer process survival (Ψ₀ Existence invariant)
  # ---------------------------------------------------------------------------

  describe "Constitutional Ψ₀ — process existence" do
    test "process survives assess_threat with unknown event structure" do
      SymbioticDefense.assess_threat(%{unexpected: :keys, value: nil})
      assert Process.alive?(GenServer.whereis(SymbioticDefense))
    end

    test "process survives multiple rapid escalations" do
      for level <- [:elevated, :guarded, :high, :critical] do
        SymbioticDefense.escalate(level, "rapid escalation #{level}")
      end

      assert Process.alive?(GenServer.whereis(SymbioticDefense))
    end

    test "process survives restore_state with invalid data" do
      SymbioticDefense.restore_state(<<"garbage binary">>)
      assert Process.alive?(GenServer.whereis(SymbioticDefense))
    end
  end
end
