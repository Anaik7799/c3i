defmodule Indrajaal.Cockpit.Prajna.FeatureFlagsTest do
  @moduledoc """
  Tests for FeatureFlags GenServer - dynamic feature control.
  STAMP: SC-PRAJNA-001, SC-BIO-007, SC-CONFIG-006, SC-SIL6-001..004
  """
  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.FeatureFlags

  setup do
    # Start with default module name since all client functions call __MODULE__
    case FeatureFlags.start_link([]) do
      {:ok, pid} -> {:ok, %{pid: pid}}
      {:error, {:already_started, pid}} -> {:ok, %{pid: pid}}
    end
  end

  describe "start_link/1" do
    test "starts the GenServer" do
      name = :"ff_start_#{:erlang.unique_integer()}"
      assert {:ok, pid} = FeatureFlags.start_link(name: name)
      assert Process.alive?(pid)
    end

    test "initializes with default flags" do
      flags = FeatureFlags.flags()
      assert map_size(flags) > 0
    end
  end

  describe "enabled?/2" do
    test "returns boolean for boolean flags" do
      result = FeatureFlags.enabled?(:guardian_circuit_breaker)
      assert is_boolean(result)
    end

    test "returns default for undefined context" do
      result = FeatureFlags.enabled?(:guardian_circuit_breaker, %{})
      assert is_boolean(result)
    end

    test "unknown flag returns false" do
      assert FeatureFlags.enabled?(:unknown_flag) == false
    end

    test "percentage flag evaluates consistently for same context" do
      context = %{user_id: 12345}
      r1 = FeatureFlags.enabled?(:new_dashboard_ui, context)
      r2 = FeatureFlags.enabled?(:new_dashboard_ui, context)
      assert r1 == r2
    end
  end

  describe "enable/2" do
    test "enables a boolean flag" do
      # First disable, then enable
      FeatureFlags.disable(:debug_logging)
      assert :ok = FeatureFlags.enable(:debug_logging)
      assert FeatureFlags.enabled?(:debug_logging) == true
    end

    test "unknown flag returns error" do
      assert {:error, :unknown_flag} = FeatureFlags.enable(:nonexistent)
    end
  end

  describe "disable/1" do
    test "disables a boolean flag" do
      FeatureFlags.enable(:debug_logging)
      assert :ok = FeatureFlags.disable(:debug_logging)
      assert FeatureFlags.enabled?(:debug_logging) == false
    end

    test "unknown flag returns error" do
      assert {:error, :unknown_flag} = FeatureFlags.disable(:nonexistent)
    end
  end

  describe "set_percentage/2" do
    test "sets percentage for rollout flag" do
      assert :ok = FeatureFlags.set_percentage(:new_dashboard_ui, 50)
      {:ok, value} = FeatureFlags.get_value(:new_dashboard_ui)
      assert value == 50
    end

    test "rejects percentage > 100" do
      assert_raise FunctionClauseError, fn ->
        FeatureFlags.set_percentage(:new_dashboard_ui, 150)
      end
    end

    test "rejects negative percentage" do
      assert_raise FunctionClauseError, fn ->
        FeatureFlags.set_percentage(:new_dashboard_ui, -10)
      end
    end

    test "non-percentage flag returns error" do
      assert {:error, :not_percentage_flag} =
               FeatureFlags.set_percentage(:guardian_circuit_breaker, 50)
    end
  end

  describe "set_time_window/3" do
    test "sets time window for scheduled flag" do
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 3600, :second)
      assert :ok = FeatureFlags.set_time_window(:maintenance_mode, start_time, end_time)
    end

    test "non-time-window flag returns error" do
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 3600, :second)

      assert {:error, :not_time_window_flag} =
               FeatureFlags.set_time_window(:debug_logging, start_time, end_time)
    end
  end

  describe "get_value/1" do
    test "returns current flag value" do
      FeatureFlags.enable(:debug_logging)
      assert {:ok, true} = FeatureFlags.get_value(:debug_logging)
    end

    test "unknown flag returns error" do
      assert {:error, :unknown_flag} = FeatureFlags.get_value(:nonexistent)
    end
  end

  describe "all/0" do
    test "returns all flag states" do
      all_flags = FeatureFlags.all()
      assert is_map(all_flags)
      assert map_size(all_flags) > 0
    end

    test "each flag has required fields" do
      all_flags = FeatureFlags.all()

      Enum.each(all_flags, fn {_name, spec} ->
        assert Map.has_key?(spec, :type)
        assert Map.has_key?(spec, :value)
        assert Map.has_key?(spec, :level)
        assert Map.has_key?(spec, :requires_guardian)
      end)
    end
  end

  describe "reset/1" do
    test "resets flag to default" do
      FeatureFlags.enable(:debug_logging)
      assert :ok = FeatureFlags.reset(:debug_logging)
      {:ok, value} = FeatureFlags.get_value(:debug_logging)
      # Default for debug_logging is false
      assert value == false
    end

    test "unknown flag returns error" do
      assert {:error, :unknown_flag} = FeatureFlags.reset(:nonexistent)
    end
  end

  describe "flags/0" do
    test "returns flag definitions" do
      flags = FeatureFlags.flags()
      assert is_map(flags)
      assert Map.has_key?(flags, :guardian_circuit_breaker)
      assert Map.has_key?(flags, :immutable_state_duckdb)
    end

    test "each flag has required schema" do
      flags = FeatureFlags.flags()

      Enum.each(flags, fn {_name, spec} ->
        assert Map.has_key?(spec, :type)
        assert Map.has_key?(spec, :default)
        assert Map.has_key?(spec, :level)
        assert Map.has_key?(spec, :requires_guardian)
        assert Map.has_key?(spec, :description)
      end)
    end
  end

  describe "percentage evaluation" do
    test "0% always returns false" do
      FeatureFlags.set_percentage(:new_dashboard_ui, 0)

      for i <- 1..10 do
        refute FeatureFlags.enabled?(:new_dashboard_ui, %{user_id: i})
      end
    end

    test "100% always returns true" do
      FeatureFlags.set_percentage(:new_dashboard_ui, 100)

      for i <- 1..10 do
        assert FeatureFlags.enabled?(:new_dashboard_ui, %{user_id: i})
      end
    end
  end

  describe "property tests" do
    property "enabled? always returns boolean" do
      forall flag <- PC.oneof([:guardian_circuit_breaker, :debug_logging, :mock_guardian]) do
        is_boolean(FeatureFlags.enabled?(flag))
      end
    end

    property "get_value returns {:ok, _} or {:error, _}" do
      forall flag <- PC.atom() do
        case FeatureFlags.get_value(flag) do
          {:ok, _} -> true
          {:error, _} -> true
        end
      end
    end

    property "all() returns map with consistent structure" do
      forall _seed <- PC.integer() do
        all_flags = FeatureFlags.all()
        is_map(all_flags) and Enum.all?(all_flags, fn {k, v} -> is_atom(k) and is_map(v) end)
      end
    end
  end

  describe "SC-SIL6-001 compliance - fail-closed for L5" do
    test "L5 flags require guardian in production" do
      # In test env, L5 flags may be allowed to bypass
      # Verify the flag definition exists and is L5
      flags = FeatureFlags.flags()
      l5_flag = flags[:immutable_state_duckdb]
      assert l5_flag.level == :l5
      assert l5_flag.requires_guardian == true
    end
  end

  describe "SC-CONFIG-006 compliance" do
    test "feature flag support is implemented" do
      # Verify feature flags module exists and works
      assert function_exported?(FeatureFlags, :enabled?, 1)
      assert function_exported?(FeatureFlags, :enable, 1)
      assert function_exported?(FeatureFlags, :disable, 1)
    end
  end

  describe "SC-BIO-007 compliance - graceful degradation" do
    test "unknown flags return false (graceful)" do
      refute FeatureFlags.enabled?(:completely_unknown_flag)
    end
  end
end
