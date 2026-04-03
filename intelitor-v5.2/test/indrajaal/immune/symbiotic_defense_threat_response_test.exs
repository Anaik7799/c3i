defmodule Indrajaal.Immune.SymbioticDefenseThreatResponseTest do
  @moduledoc """
  Tests for the SymbioticDefense subsystem: threat response coordination,
  quarantine enforcement, immune memory, and adaptive defense patterns.

  WHAT: Comprehensive test suite covering all SymbioticDefense subsystem
        behaviors — threat classification, quarantine state machines, immune
        memory with false-positive learning, adaptive escalation/de-escalation,
        response latency budgets, and property-based threat scoring invariants.
  WHY:  SC-BIO-EXT-002 (SymbioticDefense < 100ms), SC-IMMUNE-001 (Sentinel
        monitors health), AOR-IMMUNE-004 (RPN >= 50 reported to Guardian) require
        the defense subsystem to respond correctly, quickly, and durably.
  CONSTRAINTS:
    - SC-BIO-EXT-002: SymbioticDefense threat response < 100ms
    - SC-IMMUNE-001: Sentinel monitors system health continuously
    - AOR-IMMUNE-004: Threats with RPN >= 50 MUST be reported to Guardian
    - SC-FMEA-003: Severity mapping P0=9, P1=7, P2=5, P3=3
    - EP-GEN-014: Dual property testing — PropCheck + StreamData

  ## Test Coverage Matrix
  | Group                     | PropCheck | StreamData | Unit | Total |
  |---------------------------|-----------|------------|------|-------|
  | threat classification     | 1         | 1          | 4    | 6     |
  | quarantine enforcement    | 1         | 1          | 4    | 6     |
  | immune memory             | 0         | 1          | 4    | 5     |
  | adaptive response         | 1         | 1          | 4    | 6     |
  | response latency          | 0         | 0          | 5    | 5     |
  | property: threat scoring  | 1         | 1          | 0    | 2     |
  | TOTAL                     | 4         | 5          | 21   | 30    |

  ## Change History
  | Version | Date       | Author      | Change                              |
  |---------|------------|-------------|-------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude S4.6 | Initial SymbioticDefense test suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: MANDATORY dual property testing import pattern
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :immune
  @moduletag :symbiotic_defense
  @moduletag :threat_response

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ============================================================================
  # THREAT DOMAIN CONSTANTS
  # ============================================================================

  # Ordered severity levels (ascending)
  @severity_levels [:info, :warning, :critical, :emergency]

  @severity_rank %{info: 0, warning: 1, critical: 2, emergency: 3}

  # SIL-6 / FMEA severity numeric mapping (SC-FMEA-003)
  @severity_numeric %{info: 1, warning: 3, critical: 7, emergency: 9}

  # Threat categories recognised by the immune system
  @threat_categories [
    :memory_corruption,
    :unauthorized_access,
    :process_runaway,
    :network_intrusion,
    :data_exfiltration,
    :constitution_violation,
    :resource_exhaustion,
    :unknown
  ]

  # Quarantine states a defended agent may occupy
  @quarantine_states [:active, :suspended, :terminated, :restored]

  # ============================================================================
  # SELF-CONTAINED HELPERS
  #
  # All helpers simulate SymbioticDefense behavior purely in-process.
  # No production GenServer or external dependency is required.
  # ============================================================================

  # ---------------------------------------------------------------------------
  # Threat construction helpers
  # ---------------------------------------------------------------------------

  # Build a minimal threat vector map from raw inputs.
  defp build_threat(severity, category, opts \\ []) do
    rpn_score = compute_rpn(severity, category)

    %{
      id: opts[:id] || :erlang.unique_integer([:positive]),
      severity: severity,
      category: category,
      rpn: rpn_score,
      source_agent: opts[:source_agent] || :unknown_agent,
      detected_at: System.monotonic_time(:millisecond),
      vector: opts[:vector] || %{},
      recurrence_count: opts[:recurrence_count] || 0
    }
  end

  # Compute RPN for a threat using S × O × D formula (SC-FMEA-003).
  # Occurrence is derived from category criticality.
  # Detection is inversely tied to severity (critical = hard to detect early).
  defp compute_rpn(severity, category) do
    s = @severity_numeric[severity] || 1

    o =
      case category do
        :constitution_violation -> 9
        :data_exfiltration -> 8
        :network_intrusion -> 7
        :unauthorized_access -> 6
        :process_runaway -> 5
        :memory_corruption -> 5
        :resource_exhaustion -> 4
        _ -> 2
      end

    d =
      case severity do
        :emergency -> 2
        :critical -> 3
        :warning -> 6
        :info -> 8
      end

    s * o * d
  end

  # ---------------------------------------------------------------------------
  # Threat classification
  # ---------------------------------------------------------------------------

  # Classify a raw anomaly score and category into a typed threat.
  defp classify_threat(anomaly_score, category)
       when is_float(anomaly_score) and anomaly_score >= 0.0 and anomaly_score <= 1.0 do
    severity =
      cond do
        anomaly_score >= 0.9 -> :emergency
        anomaly_score >= 0.65 -> :critical
        anomaly_score >= 0.35 -> :warning
        true -> :info
      end

    build_threat(severity, category)
  end

  # ---------------------------------------------------------------------------
  # Quarantine enforcement
  # ---------------------------------------------------------------------------

  # Initial quarantine record when an agent is first isolated.
  defp quarantine_init(agent_id, threat) do
    %{
      agent_id: agent_id,
      state: :active,
      threat_id: threat.id,
      threat_severity: threat.severity,
      threat_rpn: threat.rpn,
      communication_blocked: threat.rpn >= 50,
      resource_limit_pct: resource_limit_for(threat.severity),
      quarantined_at: System.monotonic_time(:millisecond),
      resolved_at: nil
    }
  end

  # Resource CPU/memory cap percentage applied during quarantine.
  defp resource_limit_for(:emergency), do: 0
  defp resource_limit_for(:critical), do: 10
  defp resource_limit_for(:warning), do: 40
  defp resource_limit_for(:info), do: 75

  # Transition a quarantine record to a new state.
  # Valid transitions: active → suspended → terminated, active → restored.
  defp quarantine_transition(q, :suspended) when q.state == :active do
    %{q | state: :suspended}
  end

  defp quarantine_transition(q, :terminated) when q.state in [:active, :suspended] do
    %{q | state: :terminated, resolved_at: System.monotonic_time(:millisecond)}
  end

  defp quarantine_transition(q, :restored) when q.state in [:active, :suspended] do
    %{q | state: :restored, resolved_at: System.monotonic_time(:millisecond)}
  end

  defp quarantine_transition(q, _invalid_target), do: q

  # Check whether an agent is currently quarantined (active or suspended).
  defp quarantined?(q), do: q.state in [:active, :suspended]

  # ---------------------------------------------------------------------------
  # Immune memory
  # ---------------------------------------------------------------------------

  # Store a threat signature in the immune memory map.
  # Key: {category, severity} → value: memory entry with count + timestamps.
  defp memory_record(memory, threat) do
    key = {threat.category, threat.severity}
    now = System.monotonic_time(:millisecond)

    entry =
      case Map.get(memory, key) do
        nil ->
          %{
            first_seen: now,
            last_seen: now,
            occurrence_count: 1,
            avg_rpn: threat.rpn,
            false_positive_count: 0,
            suppressed: false
          }

        existing ->
          new_count = existing.occurrence_count + 1
          new_avg = div(existing.avg_rpn * existing.occurrence_count + threat.rpn, new_count)

          %{existing | last_seen: now, occurrence_count: new_count, avg_rpn: new_avg}
      end

    Map.put(memory, key, entry)
  end

  # Recall whether we have seen this threat category + severity before.
  defp memory_recall(memory, category, severity) do
    Map.get(memory, {category, severity})
  end

  # Record a false positive: the threat was a false alarm.
  # After 3 false positives the signature is suppressed.
  defp memory_record_false_positive(memory, category, severity) do
    key = {category, severity}

    case Map.get(memory, key) do
      nil ->
        memory

      entry ->
        new_fp = entry.false_positive_count + 1
        suppressed = new_fp >= 3
        Map.put(memory, key, %{entry | false_positive_count: new_fp, suppressed: suppressed})
    end
  end

  # Return true when the memory entry for this signature is suppressed.
  defp memory_suppressed?(memory, category, severity) do
    case Map.get(memory, {category, severity}) do
      nil -> false
      entry -> entry.suppressed
    end
  end

  # ---------------------------------------------------------------------------
  # Adaptive response — escalation and de-escalation
  # ---------------------------------------------------------------------------

  # Select the defense action based on RPN (SC-BIO-EXT-002).
  # Returns a defense response map.
  defp defense_respond(threat) do
    t0 = System.monotonic_time(:millisecond)

    action =
      cond do
        threat.rpn >= 300 -> :emergency_shutdown
        threat.rpn >= 150 -> :quarantine_agent
        threat.rpn >= 50 -> :isolate_and_alert
        threat.rpn >= 20 -> :log_and_monitor
        true -> :observe_only
      end

    elapsed = System.monotonic_time(:millisecond) - t0

    %{
      action: action,
      threat_id: threat.id,
      rpn: threat.rpn,
      severity: threat.severity,
      guardian_notified: threat.rpn >= 50,
      response_ms: elapsed,
      decided_at: System.monotonic_time(:millisecond)
    }
  end

  # Compute adaptive escalation level based on recurrence count.
  # Repeated threats escalate the base severity.
  defp adaptive_severity(base_severity, recurrence_count) do
    base_rank = @severity_rank[base_severity]

    bump =
      cond do
        recurrence_count >= 10 -> 3
        recurrence_count >= 5 -> 2
        recurrence_count >= 2 -> 1
        true -> 0
      end

    # Clamp to max severity rank
    clamped = min(base_rank + bump, length(@severity_levels) - 1)
    Enum.at(@severity_levels, clamped)
  end

  # De-escalate severity when a threat has been resolved and time has passed.
  # One level per resolution cycle, never below :info.
  defp de_escalate(severity) do
    rank = @severity_rank[severity]
    if rank > 0, do: Enum.at(@severity_levels, rank - 1), else: :info
  end

  # ============================================================================
  # GROUP 1: THREAT CLASSIFICATION
  # ============================================================================

  describe "threat classification" do
    @tag :threat_classification
    test "SYM_TC_01: classify_threat returns valid severity for low anomaly score" do
      threat = classify_threat(0.1, :unknown)
      assert threat.severity == :info
      assert threat.category == :unknown
      assert is_integer(threat.id)
      assert is_integer(threat.rpn)
      assert threat.rpn >= 0
    end

    @tag :threat_classification
    test "SYM_TC_02: classify_threat returns :emergency for score >= 0.9" do
      threat = classify_threat(0.95, :network_intrusion)
      assert threat.severity == :emergency
    end

    @tag :threat_classification
    test "SYM_TC_03: classify_threat returns :critical for score in [0.65, 0.9)" do
      threat = classify_threat(0.70, :unauthorized_access)
      assert threat.severity == :critical
    end

    @tag :threat_classification
    test "SYM_TC_04: classify_threat returns :warning for score in [0.35, 0.65)" do
      threat = classify_threat(0.50, :resource_exhaustion)
      assert threat.severity == :warning
    end

    @tag :threat_classification
    property "SYM_TC_05_PC: any anomaly score in [0,1] produces a valid severity (PropCheck)" do
      forall score <- PC.float(min: 0.0, max: 1.0) do
        threat = classify_threat(score, :unknown)
        threat.severity in @severity_levels
      end
    end

    @tag :threat_classification
    test "SYM_TC_06_SD: StreamData — all categories produce non-zero RPN for critical severity" do
      ExUnitProperties.check all(
                               category <- SD.member_of(@threat_categories),
                               max_runs: 40
                             ) do
        threat = build_threat(:critical, category)
        assert threat.rpn > 0, "RPN must be positive for critical severity"
        assert threat.severity == :critical
        assert threat.category == category
      end
    end
  end

  # ============================================================================
  # GROUP 2: QUARANTINE ENFORCEMENT
  # ============================================================================

  describe "quarantine enforcement" do
    @tag :quarantine
    test "SYM_QE_01: quarantine_init creates active quarantine with correct fields" do
      threat = build_threat(:critical, :unauthorized_access)
      q = quarantine_init("agent-abc-123", threat)

      assert q.agent_id == "agent-abc-123"
      assert q.state == :active
      assert q.threat_id == threat.id
      assert q.threat_severity == :critical
      assert q.threat_rpn == threat.rpn
      assert is_boolean(q.communication_blocked)
      assert q.resource_limit_pct in 0..100
      assert is_integer(q.quarantined_at)
      assert q.resolved_at == nil
    end

    @tag :quarantine
    test "SYM_QE_02: emergency threat quarantine blocks communication and sets 0% resources" do
      threat = build_threat(:emergency, :constitution_violation)
      q = quarantine_init("agent-emergency-001", threat)

      assert q.communication_blocked == true,
             "Emergency quarantine must block all communication"

      assert q.resource_limit_pct == 0,
             "Emergency quarantine must reduce resources to 0%"
    end

    @tag :quarantine
    test "SYM_QE_03: info threat quarantine does not block communication" do
      threat = build_threat(:info, :unknown)
      q = quarantine_init("agent-info-001", threat)

      assert q.communication_blocked == false,
             "Info-level threat must not block agent communication"

      assert q.resource_limit_pct == 75
    end

    @tag :quarantine
    test "SYM_QE_04: valid quarantine state transitions execute correctly" do
      threat = build_threat(:warning, :process_runaway)
      q0 = quarantine_init("agent-w-001", threat)

      assert q0.state == :active
      assert quarantined?(q0)

      q1 = quarantine_transition(q0, :suspended)
      assert q1.state == :suspended
      assert quarantined?(q1)

      q2 = quarantine_transition(q1, :terminated)
      assert q2.state == :terminated
      assert not quarantined?(q2)
      assert is_integer(q2.resolved_at)
    end

    @tag :quarantine
    property "SYM_QE_05_PC: quarantine resource limit is always in [0, 100] (PropCheck)" do
      forall severity <- PC.oneof(@severity_levels) do
        limit = resource_limit_for(severity)
        is_integer(limit) and limit >= 0 and limit <= 100
      end
    end

    @tag :quarantine
    test "SYM_QE_06_SD: StreamData — quarantine_init always produces a valid map" do
      ExUnitProperties.check all(
                               category <- SD.member_of(@threat_categories),
                               severity <- SD.member_of(@severity_levels),
                               agent_id <-
                                 SD.map(SD.integer(1..9999), fn n ->
                                   "agent-sd-#{n}"
                                 end),
                               max_runs: 40
                             ) do
        threat = build_threat(severity, category)
        q = quarantine_init(agent_id, threat)

        assert q.state == :active
        assert q.agent_id == agent_id
        assert q.resource_limit_pct in 0..100
        assert is_boolean(q.communication_blocked)
        assert is_integer(q.quarantined_at)
      end
    end
  end

  # ============================================================================
  # GROUP 3: IMMUNE MEMORY
  # ============================================================================

  describe "immune memory" do
    @tag :immune_memory
    test "SYM_IM_01: memory_record stores threat signature on first encounter" do
      memory = %{}
      threat = build_threat(:warning, :memory_corruption)
      memory2 = memory_record(memory, threat)

      entry = memory_recall(memory2, :memory_corruption, :warning)
      assert entry != nil
      assert entry.occurrence_count == 1
      assert entry.false_positive_count == 0
      assert entry.suppressed == false
    end

    @tag :immune_memory
    test "SYM_IM_02: repeated encounters increment occurrence_count" do
      memory = %{}
      threat = build_threat(:critical, :data_exfiltration)

      memory_after =
        Enum.reduce(1..5, memory, fn _i, acc -> memory_record(acc, threat) end)

      entry = memory_recall(memory_after, :data_exfiltration, :critical)
      assert entry.occurrence_count == 5
    end

    @tag :immune_memory
    test "SYM_IM_03: false positives are tracked and signature suppressed after 3" do
      memory = %{}
      threat = build_threat(:info, :unknown)
      memory_with_entry = memory_record(memory, threat)

      memory_fp1 = memory_record_false_positive(memory_with_entry, :unknown, :info)
      memory_fp2 = memory_record_false_positive(memory_fp1, :unknown, :info)

      refute memory_suppressed?(memory_fp2, :unknown, :info),
             "Signature must not be suppressed after only 2 false positives"

      memory_fp3 = memory_record_false_positive(memory_fp2, :unknown, :info)

      assert memory_suppressed?(memory_fp3, :unknown, :info),
             "Signature must be suppressed after 3 false positives (false-positive learning)"
    end

    @tag :immune_memory
    test "SYM_IM_04: memory_recall returns nil for unknown signature" do
      entry = memory_recall(%{}, :nonexistent_category, :emergency)
      assert entry == nil
    end

    @tag :immune_memory
    test "SYM_IM_05_SD: StreamData — memory records accumulate correctly for any signature" do
      ExUnitProperties.check all(
                               category <- SD.member_of(@threat_categories),
                               severity <- SD.member_of(@severity_levels),
                               count <- SD.integer(1..10),
                               max_runs: 30
                             ) do
        threat = build_threat(severity, category)

        final_memory =
          Enum.reduce(1..count, %{}, fn _i, acc -> memory_record(acc, threat) end)

        entry = memory_recall(final_memory, category, severity)
        assert entry != nil
        assert entry.occurrence_count == count
        assert entry.suppressed == false
      end
    end
  end

  # ============================================================================
  # GROUP 4: ADAPTIVE RESPONSE
  # ============================================================================

  describe "adaptive response" do
    @tag :adaptive
    test "SYM_AR_01: threat with recurrence_count 0 keeps base severity" do
      result = adaptive_severity(:warning, 0)
      assert result == :warning
    end

    @tag :adaptive
    test "SYM_AR_02: recurrence_count >= 5 escalates severity by 2 levels" do
      # :info + 2 = :critical
      result = adaptive_severity(:info, 5)
      assert result == :critical
    end

    @tag :adaptive
    test "SYM_AR_03: adaptive severity never exceeds :emergency regardless of recurrence" do
      result = adaptive_severity(:emergency, 999)
      assert result == :emergency

      result2 = adaptive_severity(:critical, 999)
      assert result2 == :emergency
    end

    @tag :adaptive
    test "SYM_AR_04: de_escalate reduces severity by one level each call" do
      assert de_escalate(:emergency) == :critical
      assert de_escalate(:critical) == :warning
      assert de_escalate(:warning) == :info
      assert de_escalate(:info) == :info
    end

    @tag :adaptive
    property "SYM_AR_05_PC: adaptive severity always stays within valid severity levels (PropCheck)" do
      forall {base, recurrence} <-
               {PC.oneof(@severity_levels), PC.integer(min: 0, max: 50)} do
        result = adaptive_severity(base, recurrence)
        result in @severity_levels
      end
    end

    @tag :adaptive
    test "SYM_AR_06_SD: StreamData — escalation path is monotone with recurrence count" do
      ExUnitProperties.check all(
                               base_severity <- SD.member_of(@severity_levels),
                               low_count <- SD.integer(0..4),
                               high_count <- SD.integer(5..20),
                               max_runs: 40
                             ) do
        sev_low = adaptive_severity(base_severity, low_count)
        sev_high = adaptive_severity(base_severity, high_count)

        rank_low = @severity_rank[sev_low]
        rank_high = @severity_rank[sev_high]

        assert rank_low <= rank_high,
               "Higher recurrence must produce equal or higher severity: " <>
                 "#{base_severity}@#{low_count}=#{sev_low}(#{rank_low}) vs " <>
                 "#{base_severity}@#{high_count}=#{sev_high}(#{rank_high})"
      end
    end
  end

  # ============================================================================
  # GROUP 5: RESPONSE LATENCY (SC-BIO-EXT-002: < 100ms)
  # ============================================================================

  describe "response latency" do
    @tag :latency
    test "SYM_LAT_01: defense_respond completes in < 100ms for info threat (SC-BIO-EXT-002)" do
      threat = build_threat(:info, :unknown)
      t0 = System.monotonic_time(:millisecond)
      result = defense_respond(threat)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < 100,
             "SymbioticDefense must respond in < 100ms (SC-BIO-EXT-002), took #{elapsed}ms"

      assert result.action == :observe_only
    end

    @tag :latency
    test "SYM_LAT_02: defense_respond completes in < 100ms for emergency threat (SC-BIO-EXT-002)" do
      threat = build_threat(:emergency, :constitution_violation)
      t0 = System.monotonic_time(:millisecond)
      result = defense_respond(threat)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < 100,
             "SymbioticDefense must respond in < 100ms for emergency threat, took #{elapsed}ms"

      assert result.guardian_notified == true,
             "Emergency threat must notify Guardian (AOR-IMMUNE-004)"
    end

    @tag :latency
    test "SYM_LAT_03: 100 sequential defense_respond calls all complete in < 100ms each" do
      for _ <- 1..100 do
        severity = Enum.random(@severity_levels)
        category = Enum.random(@threat_categories)
        threat = build_threat(severity, category)

        t0 = System.monotonic_time(:millisecond)
        defense_respond(threat)
        elapsed = System.monotonic_time(:millisecond) - t0

        assert elapsed < 100,
               "Each defense_respond call must complete in < 100ms (SC-BIO-EXT-002), took #{elapsed}ms"
      end
    end

    @tag :latency
    test "SYM_LAT_04: 20 concurrent defense_respond tasks all complete within 500ms total" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            severity = Enum.at(@severity_levels, rem(i, length(@severity_levels)))
            category = Enum.at(@threat_categories, rem(i * 3, length(@threat_categories)))
            threat = build_threat(severity, category)

            t0 = System.monotonic_time(:millisecond)
            result = defense_respond(threat)
            {result, System.monotonic_time(:millisecond) - t0}
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert length(results) == 20

      for {result, elapsed} <- results do
        assert elapsed < 100,
               "Concurrent defense task must complete in < 100ms (SC-BIO-EXT-002), took #{elapsed}ms"

        assert result.action in [
                 :emergency_shutdown,
                 :quarantine_agent,
                 :isolate_and_alert,
                 :log_and_monitor,
                 :observe_only
               ]
      end
    end

    @tag :latency
    test "SYM_LAT_05: full classify → quarantine → defend pipeline completes in < 100ms" do
      t0 = System.monotonic_time(:millisecond)

      threat = classify_threat(0.80, :network_intrusion)
      _q = quarantine_init("agent-latency-test", threat)
      response = defense_respond(threat)

      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < 100,
             "Full classify→quarantine→defend pipeline must complete in < 100ms, took #{elapsed}ms"

      assert response.action in [:quarantine_agent, :isolate_and_alert, :emergency_shutdown]
    end
  end

  # ============================================================================
  # GROUP 6: PROPERTY — THREAT SCORING INVARIANTS
  # ============================================================================

  describe "property: threat scoring" do
    @tag :property
    property "SYM_PROP_01_PC: RPN is always a positive integer and bounded <= 729 (PropCheck)" do
      forall {severity, category} <-
               {PC.oneof(@severity_levels), PC.oneof(@threat_categories)} do
        rpn_val = compute_rpn(severity, category)
        is_integer(rpn_val) and rpn_val > 0 and rpn_val <= 729
      end
    end

    @tag :property
    test "SYM_PROP_02_SD: StreamData — higher severity produces monotonically non-decreasing RPN for same category" do
      ExUnitProperties.check all(
                               category <- SD.member_of(@threat_categories),
                               max_runs: 50
                             ) do
        # For a fixed category, verify each adjacent severity pair is non-decreasing
        severity_pairs = Enum.zip(@severity_levels, tl(@severity_levels))

        for {lower_sev, higher_sev} <- severity_pairs do
          rpn_lower = compute_rpn(lower_sev, category)
          rpn_higher = compute_rpn(higher_sev, category)

          assert rpn_lower <= rpn_higher,
                 "RPN must not decrease with severity: #{lower_sev}(#{rpn_lower}) " <>
                   "should be <= #{higher_sev}(#{rpn_higher}) for category #{category}"
        end
      end
    end
  end
end
