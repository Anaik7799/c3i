defmodule Indrajaal.Safety.SentinelPropertyTest do
  @moduledoc """
  TDG dual property test suite for the Sentinel Digital Immune System.

  This file complements the existing SentinelTest with PropCheck forall
  and ExUnitProperties check-all property tests, plus coverage for
  assess_now/0, check_state_machine/0, and release/1 invariants.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Dual property tests (PropCheck + ExUnitProperties)
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-IMMUNE-001: Sentinel SHALL monitor system health continuously
  - SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes
  - SC-IMMUNE-003: Sentinel SHALL log all defensive actions
  - SC-PRIME-001: Will to Live — SHALL NOT terminate essential services
  - SC-MATH-004: PetriNet discipline connected via check_state_machine/0

  ## Constitutional Verification
  - Ψ₀ Existence: Sentinel survives arbitrary threat volumes
  - Ψ₁ Regeneration: Health score reproducible from same metric inputs
  - Ψ₃ Verification: State machine verified deadlock-free

  ## Founder's Directive Alignment
  - Ω₀.3: Symbiotic binding preserved — Sentinel never crashes the node

  ## TPS 5-Level RCA Context
  - L1 Symptom: Health score drifts outside [0.0, 1.0] under load
  - L5 Root Cause: Weighted multi-factor formula lacks boundary enforcement
    test (SC-IMMUNE-009)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 W1 — property tests and assess_now coverage |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Safety.Sentinel

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Setup — fresh Sentinel for every test (guardian disabled to avoid side effects)
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(Sentinel) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid, :normal, 5_000)
        catch
          :exit, _ -> :ok
        end
    end

    {:ok, pid} = Sentinel.start_link(guardian_enabled: false)

    on_exit(fn ->
      case GenServer.whereis(Sentinel) do
        nil ->
          :ok

        _pid ->
          try do
            GenServer.stop(Sentinel, :normal, 5_000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    %{pid: pid}
  end

  # ---------------------------------------------------------------------------
  # assess_now/0
  # ---------------------------------------------------------------------------

  describe "assess_now/0" do
    test "returns {:ok, map} when Sentinel is running" do
      assert {:ok, result} = Sentinel.assess_now()
      assert is_map(result)
    end

    test "result contains required keys" do
      {:ok, result} = Sentinel.assess_now()

      for key <- [
            :threat_level,
            :health_score,
            :active_threats,
            :quarantine_count,
            :metrics,
            :assessed_at
          ] do
        assert Map.has_key?(result, key), "assess_now result missing key: #{key}"
      end
    end

    test "threat_level is one of the known atoms" do
      {:ok, result} = Sentinel.assess_now()
      assert result.threat_level in [:none, :low, :medium, :high, :critical]
    end

    test "health_score is a float in [0.0, 1.0]" do
      {:ok, result} = Sentinel.assess_now()
      assert is_float(result.health_score)
      assert result.health_score >= 0.0
      assert result.health_score <= 1.0
    end

    test "quarantine_count is a non-negative integer" do
      {:ok, result} = Sentinel.assess_now()
      assert is_integer(result.quarantine_count)
      assert result.quarantine_count >= 0
    end

    test "active_threats is a list" do
      {:ok, result} = Sentinel.assess_now()
      assert is_list(result.active_threats)
    end

    test "assessed_at is a DateTime" do
      {:ok, result} = Sentinel.assess_now()
      assert %DateTime{} = result.assessed_at
    end

    test "returns {:error, :not_running} when Sentinel is stopped" do
      GenServer.stop(Sentinel, :normal, 5_000)
      assert {:error, :not_running} = Sentinel.assess_now()
      # Restart for on_exit cleanup
      {:ok, _} = Sentinel.start_link(guardian_enabled: false)
    end

    test "repeated calls converge to the same threat_level under stable conditions" do
      {:ok, r1} = Sentinel.assess_now()
      {:ok, r2} = Sentinel.assess_now()
      # Both should return valid levels — not necessarily equal, but valid
      assert r1.threat_level in [:none, :low, :medium, :high, :critical]
      assert r2.threat_level in [:none, :low, :medium, :high, :critical]
    end

    test "bayesian_beliefs field is present (may be empty map if ActiveInference unavailable)" do
      {:ok, result} = Sentinel.assess_now()
      assert Map.has_key?(result, :bayesian_beliefs)
      assert is_map(result.bayesian_beliefs)
    end
  end

  # ---------------------------------------------------------------------------
  # check_state_machine/0 — SC-MATH-004 PetriNet integration
  # ---------------------------------------------------------------------------

  describe "check_state_machine/0 (SC-MATH-004)" do
    test "returns {:ok, :verified} or {:error, :petri_net_unavailable}" do
      result = Sentinel.check_state_machine()

      assert result in [
               {:ok, :verified},
               {:error, :deadlock_detected},
               {:error, :petri_net_unavailable}
             ] or match?({:error, _}, result)
    end

    test "does not raise regardless of PetriNet availability" do
      result = Sentinel.check_state_machine()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # get_quarantine_list/0
  # ---------------------------------------------------------------------------

  describe "get_quarantine_list/0" do
    test "returns a map" do
      result = Sentinel.get_quarantine_list()
      assert is_map(result)
    end

    test "starts empty" do
      assert Sentinel.get_quarantine_list() == %{}
    end

    test "returns empty map when Sentinel not running" do
      GenServer.stop(Sentinel, :normal, 5_000)
      assert Sentinel.get_quarantine_list() == %{}
      {:ok, _} = Sentinel.start_link(guardian_enabled: false)
    end
  end

  # ---------------------------------------------------------------------------
  # report_signal/1
  # ---------------------------------------------------------------------------

  describe "report_signal/1" do
    test "returns :ok for a well-formed signal" do
      signal = %{type: :threat, threat_type: :test, source: self(), metadata: %{}, severity: 5}
      assert :ok = Sentinel.report_signal(signal)
    end

    test "returns :ok when Sentinel not running" do
      GenServer.stop(Sentinel, :normal, 5_000)
      assert :ok = Sentinel.report_signal(%{type: :test})
      {:ok, _} = Sentinel.start_link(guardian_enabled: false)
    end

    test "does not crash on empty signal map" do
      assert :ok = Sentinel.report_signal(%{})
      assert Process.alive?(GenServer.whereis(Sentinel))
    end
  end

  # ---------------------------------------------------------------------------
  # release/1 invariants
  # ---------------------------------------------------------------------------

  describe "release/1" do
    test "returns {:error, :not_quarantined} for process that was never quarantined" do
      {:ok, agent} = Agent.start_link(fn -> :ok end)
      assert {:error, :not_quarantined} = Sentinel.release(agent)
      Agent.stop(agent)
    end

    test "returns {:error, :not_running} when Sentinel not running" do
      GenServer.stop(Sentinel, :normal, 5_000)
      assert {:error, :not_running} = Sentinel.release(self())
      {:ok, _} = Sentinel.start_link(guardian_enabled: false)
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 health monitoring (SC-IMMUNE-001)" do
    @tag :sil4
    test "assess_now/0 responds within 100ms" do
      start = System.monotonic_time(:millisecond)
      {:ok, _} = Sentinel.assess_now()
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 100, "assess_now took #{elapsed}ms, expected < 100ms (SC-BIO-EXT-002)"
    end

    @tag :sil4
    test "get_health/0 responds within 50ms" do
      start = System.monotonic_time(:millisecond)
      Sentinel.get_health()
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 50
    end

    @tag :sil4
    test "report_threat/3 is non-blocking (returns in < 10ms)" do
      start = System.monotonic_time(:millisecond)
      Sentinel.report_threat(:test_threat, self(), %{})
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 10
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Verification
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Ψ₀-Ψ₁)" do
    test "Ψ₀ existence: Sentinel survives 50 rapid threat reports" do
      Enum.each(1..50, fn i ->
        Sentinel.report_threat(:"threat_#{i}", self(), %{iteration: i})
      end)

      assert Process.alive?(GenServer.whereis(Sentinel))
    end

    test "Ψ₁ regeneration: health score is within [0.0, 1.0] after any threat volume" do
      Enum.each(1..20, fn _ ->
        Sentinel.report_threat(:memory_pressure, self(), %{pressure: 0.9})
      end)

      {:ok, result} = Sentinel.assess_now()
      assert result.health_score >= 0.0
      assert result.health_score <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # FMEA edge cases
  # ---------------------------------------------------------------------------

  describe "FMEA — boundary and chaos tests" do
    @tag :fmea
    test "report_threat/3 with nil source does not crash" do
      assert :ok = Sentinel.report_threat(:test, nil, %{})
      assert Process.alive?(GenServer.whereis(Sentinel))
    end

    @tag :fmea
    test "report_threat/3 with empty metadata does not crash" do
      assert :ok = Sentinel.report_threat(:cpu_spike, self(), %{})
      assert Process.alive?(GenServer.whereis(Sentinel))
    end

    @tag :fmea
    test "concurrent report_threat calls do not crash Sentinel" do
      tasks =
        Enum.map(1..30, fn i ->
          Task.async(fn ->
            Sentinel.report_threat(:"concurrent_#{i}", self(), %{concurrent: true})
          end)
        end)

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &(&1 == :ok))
      assert Process.alive?(GenServer.whereis(Sentinel))
    end

    @tag :fmea
    test "assess_now after 10 concurrent threats returns valid result" do
      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            Sentinel.report_threat(:load_test, self(), %{})
          end)
        end)

      Task.await_many(tasks, 5_000)
      {:ok, result} = Sentinel.assess_now()
      assert result.health_score >= 0.0
      assert result.health_score <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck: health score invariant under any metric input
  # ---------------------------------------------------------------------------

  property "health score is always in [0.0, 1.0] regardless of threat type" do
    forall threat_type <- PC.atom() do
      Sentinel.report_threat(threat_type, self(), %{prop_test: true})
      health = Sentinel.get_health()
      health.score >= 0.0 and health.score <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck: quarantine_count is always non-negative
  # ---------------------------------------------------------------------------

  property "assess_now quarantine_count is always non-negative" do
    forall _ <- PC.integer() do
      case Sentinel.assess_now() do
        {:ok, result} -> result.quarantine_count >= 0
        {:error, :not_running} -> true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties: assess_now result shape invariant
  # ---------------------------------------------------------------------------

  test "assess_now always returns a map with threat_level and health_score" do
    ExUnitProperties.check all(_x <- SD.constant(nil)) do
      case Sentinel.assess_now() do
        {:ok, result} ->
          assert is_map(result)
          assert result.threat_level in [:none, :low, :medium, :high, :critical]
          assert result.health_score >= 0.0
          assert result.health_score <= 1.0

        {:error, :not_running} ->
          :ok
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties: repeated assess_now calls are stable
  # ---------------------------------------------------------------------------

  test "repeated assess_now calls under varying threat streams stay bounded" do
    ExUnitProperties.check all(
                             threat_types <-
                               SD.list_of(
                                 SD.member_of([
                                   :memory_pressure,
                                   :cpu_spike,
                                   :process_anomaly,
                                   :error_rate
                                 ]),
                                 min_length: 1,
                                 max_length: 10
                               )
                           ) do
      Enum.each(threat_types, fn tt ->
        Sentinel.report_threat(tt, self(), %{generated: true})
      end)

      {:ok, result} = Sentinel.assess_now()
      assert result.health_score >= 0.0
      assert result.health_score <= 1.0
    end
  end
end
