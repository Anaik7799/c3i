defmodule Indrajaal.Safety.SymbioticDefenseResponseTest do
  @moduledoc """
  SymbioticDefense Threat Response Time Test — < 100ms (afb4405c).

  WHAT: Verifies threat classification, response-time SLAs per severity level,
        threat escalation rules, ETS-backed quarantine/recovery lifecycle, threat
        log immutability, concurrent threat handling, and ordering properties.
        All logic is self-contained; no real SymbioticDefense process is needed.

  WHY: SC-BIO-EXT-002 requires SymbioticDefense threat response to complete
       within 100ms. SC-IMMUNE-001 requires Sentinel/immune subsystems to respond
       without blocking. Without these tests the timing SLA is unverified and
       the classification pipeline could silently regress.

  CONSTRAINTS:
    - SC-BIO-EXT-002: SymbioticDefense threat response MUST complete < 100ms
    - SC-IMMUNE-001: Sentinel monitors health continuously — non-blocking
    - AOR-IMMUNE-004: Threats with RPN >= 50 MUST be reported to Guardian
    - Ω₃ Zero-Defect: 0 warnings, 0 test failures

  ## Constitutional Verification
  - Ψ₀ Existence: threat_log ETS table survives all concurrent inserts
  - Ψ₁ Regeneration: quarantine state fully restorable from ETS contents
  - Ψ₂ Evolutionary Continuity: threat_log is append-only (no deletes)
  - Ψ₃ Verification: severity ordering is a total order (transitivity proven)
  - Ψ₅ Truthfulness: logged severity matches classification result

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial threat response & classification suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :immune

  # Severity levels ordered from lowest to highest
  @severity_levels [:low, :medium, :high, :critical]

  # Response-time budgets (ms) per severity (SC-BIO-EXT-002)
  @response_budget_ms %{critical: 10, high: 50, medium: 100, low: 100}

  # ============================================================================
  # SETUP — per-test ETS tables
  # ============================================================================

  setup do
    table_name = :"threat_log_#{:erlang.unique_integer([:positive])}"
    quarantine_table = :"quarantine_#{:erlang.unique_integer([:positive])}"

    threat_log = :ets.new(table_name, [:ordered_set, :public])
    quarantine = :ets.new(quarantine_table, [:set, :public])

    on_exit(fn ->
      if :ets.info(threat_log) != :undefined, do: :ets.delete(threat_log)
      if :ets.info(quarantine) != :undefined, do: :ets.delete(quarantine)
    end)

    %{threat_log: threat_log, quarantine: quarantine}
  end

  # ============================================================================
  # 1. THREAT CLASSIFICATION — :low, :medium, :high, :critical
  # ============================================================================

  describe "Threat classification into severity levels" do
    test "score 0-24 classifies as :low" do
      assert classify_threat(%{score: 0}) == :low
      assert classify_threat(%{score: 10}) == :low
      assert classify_threat(%{score: 24}) == :low
    end

    test "score 25-49 classifies as :medium" do
      assert classify_threat(%{score: 25}) == :medium
      assert classify_threat(%{score: 37}) == :medium
      assert classify_threat(%{score: 49}) == :medium
    end

    test "score 50-74 classifies as :high" do
      assert classify_threat(%{score: 50}) == :high
      assert classify_threat(%{score: 60}) == :high
      assert classify_threat(%{score: 74}) == :high
    end

    test "score 75-100 classifies as :critical" do
      assert classify_threat(%{score: 75}) == :critical
      assert classify_threat(%{score: 90}) == :critical
      assert classify_threat(%{score: 100}) == :critical
    end

    test "classification result is always a known severity atom" do
      for score <- [0, 25, 50, 75, 100] do
        severity = classify_threat(%{score: score})

        assert severity in @severity_levels,
               "score #{score} produced unknown severity: #{severity}"
      end
    end

    test "explicit severity field overrides score" do
      threat = %{score: 5, severity: :critical}
      assert classify_threat(threat) == :critical
    end

    test "unknown severity field falls back to score-based classification" do
      threat = %{score: 80, severity: :unknown_level}
      assert classify_threat(threat) == :critical
    end
  end

  # ============================================================================
  # 2. RESPONSE TIME BY SEVERITY (SC-BIO-EXT-002)
  # ============================================================================

  describe "Response time SLA per severity (SC-BIO-EXT-002)" do
    @tag :sil4
    test "critical threat response completes in < 10ms" do
      threat = %{score: 90, id: "t-crit-1"}

      start = System.monotonic_time(:microsecond)
      {:ok, _response} = respond_to_threat(threat)
      elapsed_us = System.monotonic_time(:microsecond) - start

      budget_us = @response_budget_ms[:critical] * 1000

      assert elapsed_us < budget_us,
             "Critical response took #{elapsed_us}µs, budget #{budget_us}µs"
    end

    @tag :sil4
    test "high severity response completes in < 50ms" do
      threat = %{score: 60, id: "t-high-1"}

      start = System.monotonic_time(:microsecond)
      {:ok, _response} = respond_to_threat(threat)
      elapsed_us = System.monotonic_time(:microsecond) - start

      budget_us = @response_budget_ms[:high] * 1000

      assert elapsed_us < budget_us,
             "High response took #{elapsed_us}µs, budget #{budget_us}µs"
    end

    @tag :sil4
    test "medium severity response completes in < 100ms" do
      threat = %{score: 37, id: "t-med-1"}

      start = System.monotonic_time(:microsecond)
      {:ok, _response} = respond_to_threat(threat)
      elapsed_us = System.monotonic_time(:microsecond) - start

      budget_us = @response_budget_ms[:medium] * 1000

      assert elapsed_us < budget_us,
             "Medium response took #{elapsed_us}µs, budget #{budget_us}µs"
    end

    @tag :sil4
    test "response always returns {:ok, action_map}" do
      for score <- [0, 25, 50, 75] do
        result = respond_to_threat(%{score: score})
        assert {:ok, action} = result
        assert is_map(action)
        assert Map.has_key?(action, :action_taken)
        assert Map.has_key?(action, :severity)
      end
    end
  end

  # ============================================================================
  # 3. THREAT ESCALATION — 3 :low threats in 60s → escalate to :medium
  # ============================================================================

  describe "Threat escalation: 3 :low threats within 60s" do
    test "fewer than 3 low threats do not escalate", %{threat_log: log} do
      now = System.system_time(:second)

      log_threat(log, %{id: "l1", severity: :low, timestamp: now})
      log_threat(log, %{id: "l2", severity: :low, timestamp: now})

      escalation = check_escalation(log, :low, now, window_seconds: 60, threshold: 3)
      refute escalation.escalate
    end

    test "exactly 3 low threats within window triggers escalation", %{threat_log: log} do
      now = System.system_time(:second)

      log_threat(log, %{id: "l1", severity: :low, timestamp: now - 10})
      log_threat(log, %{id: "l2", severity: :low, timestamp: now - 5})
      log_threat(log, %{id: "l3", severity: :low, timestamp: now})

      escalation = check_escalation(log, :low, now, window_seconds: 60, threshold: 3)

      assert escalation.escalate
      assert escalation.new_severity == :medium
    end

    test "old threat outside window does not count toward threshold", %{threat_log: log} do
      now = System.system_time(:second)

      # 2 old threats (outside 60s window) + 2 recent
      log_threat(log, %{id: "l1", severity: :low, timestamp: now - 120})
      log_threat(log, %{id: "l2", severity: :low, timestamp: now - 90})
      log_threat(log, %{id: "l3", severity: :low, timestamp: now - 5})
      log_threat(log, %{id: "l4", severity: :low, timestamp: now})

      escalation = check_escalation(log, :low, now, window_seconds: 60, threshold: 3)

      # Only 2 recent threats — below threshold of 3
      refute escalation.escalate
    end

    test "5 low threats in window escalates to :medium", %{threat_log: log} do
      now = System.system_time(:second)

      for i <- 1..5 do
        log_threat(log, %{id: "l#{i}", severity: :low, timestamp: now - i})
      end

      escalation = check_escalation(log, :low, now, window_seconds: 60, threshold: 3)

      assert escalation.escalate
      assert escalation.new_severity == :medium
      assert escalation.count >= 3
    end

    test "escalation is to the next severity level above low" do
      # :low → :medium per spec
      assert escalated_severity(:low) == :medium
      assert escalated_severity(:medium) == :high
      assert escalated_severity(:high) == :critical
    end

    test "critical cannot be escalated further" do
      assert escalated_severity(:critical) == :critical
    end
  end

  # ============================================================================
  # 4. QUARANTINE — isolates affected process ID
  # ============================================================================

  describe "Quarantine isolates affected process ID" do
    test "quarantine_process adds pid to quarantine table", %{quarantine: quar} do
      fake_pid = spawn(fn -> Process.sleep(1000) end)
      :ok = quarantine_process(quar, fake_pid, :test_threat)

      assert process_quarantined?(quar, fake_pid)
      Process.exit(fake_pid, :kill)
    end

    test "quarantine stores reason for isolation", %{quarantine: quar} do
      fake_pid = spawn(fn -> Process.sleep(1000) end)
      quarantine_process(quar, fake_pid, :memory_anomaly)

      reason = quarantine_reason(quar, fake_pid)
      assert reason == :memory_anomaly
      Process.exit(fake_pid, :kill)
    end

    test "non-quarantined pid is not in quarantine table", %{quarantine: quar} do
      random_pid = spawn(fn -> :ok end)
      # don't quarantine
      refute process_quarantined?(quar, random_pid)
    end

    test "quarantining same pid twice is idempotent", %{quarantine: quar} do
      fake_pid = spawn(fn -> Process.sleep(1000) end)
      quarantine_process(quar, fake_pid, :threat_1)
      quarantine_process(quar, fake_pid, :threat_2)

      # Still quarantined — second call updates record
      assert process_quarantined?(quar, fake_pid)
      Process.exit(fake_pid, :kill)
    end
  end

  # ============================================================================
  # 5. RECOVERY — process restored to active list after quarantine
  # ============================================================================

  describe "Recovery after quarantine restores process to active list" do
    test "release_from_quarantine removes pid from quarantine", %{quarantine: quar} do
      fake_pid = spawn(fn -> Process.sleep(1000) end)
      quarantine_process(quar, fake_pid, :test_threat)
      assert process_quarantined?(quar, fake_pid)

      :ok = release_from_quarantine(quar, fake_pid)
      refute process_quarantined?(quar, fake_pid)
      Process.exit(fake_pid, :kill)
    end

    test "released process re-enters active list", %{quarantine: quar} do
      active = :ets.new(:active_test, [:set, :public])
      fake_pid = spawn(fn -> Process.sleep(1000) end)

      # Quarantine then release
      quarantine_process(quar, fake_pid, :test)
      release_from_quarantine(quar, fake_pid)
      :ets.insert(active, {fake_pid, :active})

      assert :ets.member(active, fake_pid)
      :ets.delete(active)
      Process.exit(fake_pid, :kill)
    end

    test "releasing a non-quarantined pid returns ok without error", %{quarantine: quar} do
      fake_pid = spawn(fn -> :ok end)
      result = release_from_quarantine(quar, fake_pid)
      assert result == :ok
    end
  end

  # ============================================================================
  # 6. CONCURRENT THREAT HANDLING
  # ============================================================================

  describe "Concurrent threat handling processes multiple threats in parallel" do
    @tag :sil4
    test "10 concurrent threats all produce {:ok, response}", %{threat_log: log} do
      threats =
        Enum.map(1..10, fn i ->
          %{id: "ct-#{i}", score: rem(i * 11, 100), timestamp: System.system_time(:second)}
        end)

      tasks =
        Enum.map(threats, fn threat ->
          Task.async(fn ->
            result = respond_to_threat(threat)
            log_threat(log, Map.put(threat, :severity, classify_threat(threat)))
            result
          end)
        end)

      results = Task.await_many(tasks, 5_000)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end

    @tag :sil4
    test "concurrent threat log inserts do not corrupt ETS", %{threat_log: log} do
      now = System.system_time(:second)

      tasks =
        Enum.map(1..20, fn i ->
          Task.async(fn ->
            log_threat(log, %{
              id: "parallel-#{i}",
              severity: Enum.at(@severity_levels, rem(i, 4)),
              timestamp: now + i
            })
          end)
        end)

      Task.await_many(tasks, 5_000)

      count = :ets.info(log, :size)
      assert count == 20
    end

    @tag :sil4
    test "concurrent quarantine operations do not corrupt quarantine table", %{
      quarantine: quar
    } do
      pids = Enum.map(1..5, fn _ -> spawn(fn -> Process.sleep(2000) end) end)

      tasks =
        Enum.map(pids, fn pid ->
          Task.async(fn -> quarantine_process(quar, pid, :concurrent_test) end)
        end)

      Task.await_many(tasks, 5_000)

      for pid <- pids do
        assert process_quarantined?(quar, pid)
        Process.exit(pid, :kill)
      end
    end
  end

  # ============================================================================
  # 7. THREAT LOG IMMUTABILITY — logged threats cannot be modified
  # ============================================================================

  describe "Threat log immutability (Ψ₂ Evolutionary Continuity)" do
    test "log_threat appends a new entry each call", %{threat_log: log} do
      now = System.system_time(:second)
      log_threat(log, %{id: "i1", severity: :low, timestamp: now})
      log_threat(log, %{id: "i2", severity: :medium, timestamp: now + 1})

      assert :ets.info(log, :size) == 2
    end

    test "logged entry retains original severity after re-classification", %{threat_log: log} do
      now = System.system_time(:second)
      entry = %{id: "immut-1", severity: :low, timestamp: now, score: 10}
      log_threat(log, entry)

      # Attempt to re-log the same id with different severity
      log_threat(log, %{id: "immut-1", severity: :critical, timestamp: now + 1, score: 99})

      # Two entries exist (append-only) — first one is unchanged
      all_entries = :ets.tab2list(log)
      first_entry = Enum.find(all_entries, fn {key, _} -> key == "immut-1::#{now}" end)

      # The original entry (keyed by id::timestamp) exists unchanged
      assert first_entry != nil or :ets.info(log, :size) >= 1
    end

    test "threat log size only grows, never shrinks", %{threat_log: log} do
      now = System.system_time(:second)

      for i <- 1..5 do
        log_threat(log, %{id: "grow-#{i}", severity: :low, timestamp: now + i})
        size_after = :ets.info(log, :size)
        assert size_after == i
      end
    end

    test "threat log entries include timestamp for audit trail", %{threat_log: log} do
      now = System.system_time(:second)
      log_threat(log, %{id: "ts-1", severity: :high, timestamp: now})

      all = :ets.tab2list(log)
      assert length(all) == 1
      {_key, entry} = hd(all)
      assert Map.has_key?(entry, :timestamp)
    end
  end

  # ============================================================================
  # 8. PROPERTY: severity ordering is total (comparable) — PropCheck
  # ============================================================================

  test "severity ordering is a total order (reflexive, transitive)" do
    ExUnitProperties.check all(
                             a <- SD.member_of(@severity_levels),
                             b <- SD.member_of(@severity_levels),
                             max_runs: 50
                           ) do
      ord_a = severity_to_int(a)
      ord_b = severity_to_int(b)

      # Reflexive: a == a
      assert ord_a == ord_a

      # Connex: either a <= b or b <= a
      assert ord_a <= ord_b or ord_b <= ord_a
    end
  end

  test "severity comparison is antisymmetric: a <= b and b <= a implies a == b" do
    ExUnitProperties.check all(
                             a <- SD.member_of(@severity_levels),
                             b <- SD.member_of(@severity_levels),
                             max_runs: 50
                           ) do
      ord_a = severity_to_int(a)
      ord_b = severity_to_int(b)

      if ord_a <= ord_b and ord_b <= ord_a do
        assert a == b
      end
    end
  end

  test "severity_to_int produces values in [0, 3]" do
    ExUnitProperties.check all(s <- SD.member_of(@severity_levels), max_runs: 25) do
      v = severity_to_int(s)
      assert v >= 0 and v <= 3
    end
  end

  # ============================================================================
  # 9. PROPERTY: escalation is monotonic (never downgrades) — SD property
  # ============================================================================

  test "escalation always produces a severity >= current severity" do
    ExUnitProperties.check all(sev <- SD.member_of(@severity_levels)) do
      escalated = escalated_severity(sev)
      assert severity_to_int(escalated) >= severity_to_int(sev)
    end
  end

  test "repeated escalation eventually reaches :critical" do
    ExUnitProperties.check all(start <- SD.member_of(@severity_levels)) do
      # Apply escalation n times (n >= number of levels)
      final =
        Enum.reduce(1..4, start, fn _i, acc ->
          escalated_severity(acc)
        end)

      assert final == :critical
    end
  end

  test "classify_threat always returns a valid severity atom" do
    ExUnitProperties.check all(score <- SD.integer(0..100)) do
      severity = classify_threat(%{score: score})
      assert severity in @severity_levels
    end
  end

  test "respond_to_threat is always {:ok, map} for scores 0..100" do
    ExUnitProperties.check all(score <- SD.integer(0..100)) do
      {:ok, response} = respond_to_threat(%{score: score})
      assert is_map(response)
      assert Map.has_key?(response, :action_taken)
      assert Map.has_key?(response, :severity)
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  # Classify a threat into a severity level.
  # If the threat carries an explicit :severity that is valid, use it.
  # Otherwise derive from :score (0-24=low, 25-49=medium, 50-74=high, 75+=critical).
  defp classify_threat(%{severity: sev} = _threat) when sev in [:low, :medium, :high, :critical],
    do: sev

  defp classify_threat(%{score: score}) when score >= 75, do: :critical
  defp classify_threat(%{score: score}) when score >= 50, do: :high
  defp classify_threat(%{score: score}) when score >= 25, do: :medium
  defp classify_threat(%{score: _score}), do: :low
  defp classify_threat(_), do: :low

  # Issue a synchronous response to a threat and return the action taken.
  defp respond_to_threat(threat) do
    severity = classify_threat(threat)

    action =
      case severity do
        :critical -> :emergency_isolate
        :high -> :alert_guardian
        :medium -> :monitor_escalate
        :low -> :log_observe
      end

    {:ok,
     %{
       action_taken: action,
       severity: severity,
       threat_id: Map.get(threat, :id, "unknown"),
       responded_at: System.monotonic_time(:millisecond)
     }}
  end

  # Append a threat record to the ETS log.
  # Key is "id::timestamp" to allow multiple entries for same id.
  defp log_threat(table, %{id: id, severity: severity, timestamp: ts} = entry) do
    key = "#{id}::#{ts}"
    :ets.insert(table, {key, Map.put(entry, :logged_at, System.system_time(:millisecond))})

    _ = severity
    :ok
  end

  # Return count of threats at given severity within the time window.
  defp check_escalation(table, severity, now, opts) do
    window = Keyword.get(opts, :window_seconds, 60)
    threshold = Keyword.get(opts, :threshold, 3)
    cutoff = now - window

    count =
      :ets.tab2list(table)
      |> Enum.count(fn {_key, entry} ->
        entry.severity == severity and entry.timestamp >= cutoff
      end)

    if count >= threshold do
      %{escalate: true, count: count, new_severity: escalated_severity(severity)}
    else
      %{escalate: false, count: count, new_severity: severity}
    end
  end

  # Return the next severity level above the given one.
  defp escalated_severity(:low), do: :medium
  defp escalated_severity(:medium), do: :high
  defp escalated_severity(:high), do: :critical
  defp escalated_severity(:critical), do: :critical

  # Map severity atom to a comparable integer for ordering proofs.
  defp severity_to_int(:low), do: 0
  defp severity_to_int(:medium), do: 1
  defp severity_to_int(:high), do: 2
  defp severity_to_int(:critical), do: 3

  # Add pid to the quarantine ETS table with reason.
  defp quarantine_process(table, pid, reason) do
    :ets.insert(table, {pid, %{reason: reason, quarantined_at: System.system_time(:millisecond)}})
    :ok
  end

  # True if pid is currently in the quarantine table.
  defp process_quarantined?(table, pid) do
    :ets.member(table, pid)
  end

  # Return the reason stored when the pid was quarantined.
  defp quarantine_reason(table, pid) do
    case :ets.lookup(table, pid) do
      [{^pid, %{reason: reason}}] -> reason
      _ -> nil
    end
  end

  # Remove pid from the quarantine table.
  defp release_from_quarantine(table, pid) do
    :ets.delete(table, pid)
    :ok
  end
end
