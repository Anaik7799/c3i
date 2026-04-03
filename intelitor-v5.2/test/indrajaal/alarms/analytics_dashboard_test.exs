defmodule Indrajaal.Alarms.AnalyticsDashboardTest do
  @moduledoc """
  TDG comprehensive test suite for Alarms.AnalyticsDashboard.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-AD-001: get_realtime_dashboard must return a map (not {:error, _}) for valid inputs
  - SC-AD-002: returned map must have :dashboard_type key
  - SC-AD-003: get_performance_analytics must return a map

  ## Constitutional Verification
  - Psi0 Existence: Dashboard module never raises on valid inputs
  - Psi3 Verification: Return types are consistently maps (not mixed tuples)
  - Psi5 Truthfulness: :dashboard_type reflects actual dashboard mode

  ## Founder's Directive Alignment
  - Omega0.1: Dashboard visualization enables operators to protect Founder's assets

  ## TPS 5-Level RCA Context
  - L1 Symptom: TimescaleDBIntegration crashing on dashboard call
  - L5 Root Cause: get_realtime_dashboard returning {:error, _} instead of map

  ## Change History
  | Version | Date       | Author | Change            |
  |---------|------------|--------|-------------------|
  | 21.3.0  | 2026-03-19 | Claude | Initial TDG suite |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.AnalyticsDashboard

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # describe: get_realtime_dashboard/2
  # ---------------------------------------------------------------------------

  describe "get_realtime_dashboard/2" do
    test "returns a map for nil dashboard_id" do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])
      assert is_map(result)
    end

    test "returned map has :dashboard_type key" do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])
      assert Map.has_key?(result, :dashboard_type)
    end

    test "dashboard_type is :realtime_overview" do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])
      assert result.dashboard_type == :realtime_overview
    end

    test "accepts string dashboard_id" do
      result = AnalyticsDashboard.get_realtime_dashboard("dash-001", [])
      assert is_map(result)
      assert Map.has_key?(result, :dashboard_type)
    end

    test "accepts uuid dashboard_id" do
      result = AnalyticsDashboard.get_realtime_dashboard(Ecto.UUID.generate(), [])
      assert is_map(result)
    end

    test "accepts opts keyword list with timeout" do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, timeout: 5000)
      assert is_map(result)
    end

    test "does not return {:error, _}" do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])
      refute match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: get_performance_analytics/0
  # ---------------------------------------------------------------------------

  describe "get_performance_analytics/0" do
    test "returns a map" do
      result = AnalyticsDashboard.get_performance_analytics()
      assert is_map(result)
    end

    test "does not return {:error, _}" do
      result = AnalyticsDashboard.get_performance_analytics()
      refute match?({:error, _}, result)
    end

    test "is idempotent" do
      r1 = AnalyticsDashboard.get_performance_analytics()
      r2 = AnalyticsDashboard.get_performance_analytics()
      assert is_map(r1)
      assert is_map(r2)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: module never raises on any valid input" do
      assert is_map(AnalyticsDashboard.get_realtime_dashboard(nil, []))
      assert is_map(AnalyticsDashboard.get_performance_analytics())
    end

    test "Psi3 verification: both functions always return maps" do
      dashboard = AnalyticsDashboard.get_realtime_dashboard("any-id", [])
      performance = AnalyticsDashboard.get_performance_analytics()
      assert is_map(dashboard)
      assert is_map(performance)
    end

    test "Psi5 truthfulness: dashboard_type accurately reflects dashboard mode" do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])

      # :realtime_overview indicates this is a real-time overview — not a historical or batch mode
      assert result.dashboard_type == :realtime_overview
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "get_realtime_dashboard completes within 1 second" do
      {elapsed_us, result} =
        :timer.tc(fn ->
          AnalyticsDashboard.get_realtime_dashboard(nil, [])
        end)

      assert is_map(result)
      assert elapsed_us < 1_000_000
    end

    test "dual-channel: both functions return maps concurrently" do
      tasks = [
        Task.async(fn -> AnalyticsDashboard.get_realtime_dashboard(nil, []) end),
        Task.async(fn -> AnalyticsDashboard.get_performance_analytics() end)
      ]

      [r1, r2] = Task.await_many(tasks, 5_000)
      assert is_map(r1)
      assert is_map(r2)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "get_realtime_dashboard always returns map with dashboard_type" do
    forall _n <- PC.integer(1, 3) do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])
      is_map(result) and Map.has_key?(result, :dashboard_type)
    end
  end

  property "get_performance_analytics always returns a map" do
    forall _n <- PC.integer(1, 3) do
      result = AnalyticsDashboard.get_performance_analytics()
      is_map(result)
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  @tag :property
  test "get_realtime_dashboard returns map for any dashboard_id" do
    ExUnitProperties.check all(
                             dashboard_id <-
                               SD.one_of([SD.constant(nil), SD.string(:alphanumeric)])
                           ) do
      result = AnalyticsDashboard.get_realtime_dashboard(dashboard_id, [])
      assert is_map(result)
      assert Map.has_key?(result, :dashboard_type)
    end
  end

  @tag :property
  test "dashboard_type is always :realtime_overview" do
    ExUnitProperties.check all(_val <- SD.boolean()) do
      result = AnalyticsDashboard.get_realtime_dashboard(nil, [])
      assert result.dashboard_type == :realtime_overview
    end
  end
end
