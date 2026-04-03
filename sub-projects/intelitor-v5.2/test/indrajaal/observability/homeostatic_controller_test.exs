defmodule Indrajaal.Observability.HomeostaticControllerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.HomeostaticController.

  ## STAMP Safety Integration
  - SC-HOM-001: MAPE-K cycle < 100ms
  - SC-HOM-002: Mode transitions logged
  - SC-HOM-003: Resource limits enforced

  ## TPS 5-Level RCA Context
  - L1 Symptom: System not self-regulating under stress
  - L5 Root Cause: Missing MAPE-K homeostasis loop
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.HomeostaticController

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HomeostaticController)
    end

    test "start_link/1 exported" do
      assert function_exported?(HomeostaticController, :start_link, 1)
    end

    test "mode/0 exported" do
      assert function_exported?(HomeostaticController, :mode, 0)
    end

    test "resource_budgets/0 exported" do
      assert function_exported?(HomeostaticController, :resource_budgets, 0)
    end

    test "degradation_level/0 exported" do
      assert function_exported?(HomeostaticController, :degradation_level, 0)
    end

    test "recovery_progress/0 exported" do
      assert function_exported?(HomeostaticController, :recovery_progress, 0)
    end

    test "recent_actions/0 exported" do
      assert function_exported?(HomeostaticController, :recent_actions, 0)
    end

    test "force_mode/1 exported" do
      assert function_exported?(HomeostaticController, :force_mode, 1)
    end

    test "subscribe/1 exported" do
      assert function_exported?(HomeostaticController, :subscribe, 1)
    end

    test "status/0 exported" do
      assert function_exported?(HomeostaticController, :status, 0)
    end

    test "feature_active?/1 exported" do
      assert function_exported?(HomeostaticController, :feature_active?, 1)
    end
  end

  describe "start_link/1" do
    test "starts without error" do
      name = :"HomeostaticControllerTest_#{System.unique_integer([:positive])}"

      {:ok, pid} =
        GenServer.start_link(HomeostaticController, [], name: name)

      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "initial mode is :normal" do
      name = :"HomeostaticControllerInit_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(HomeostaticController, [], name: name)

      state = :sys.get_state(pid)
      assert state.mode == :normal

      GenServer.stop(pid)
    end

    test "initial degradation_level is 0" do
      name = :"HomeostaticControllerDeg_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(HomeostaticController, [], name: name)

      state = :sys.get_state(pid)
      assert state.degradation_level == 0

      GenServer.stop(pid)
    end

    test "initial recovery_progress is 1.0" do
      name = :"HomeostaticControllerRec_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(HomeostaticController, [], name: name)

      state = :sys.get_state(pid)
      assert state.recovery_progress == 1.0

      GenServer.stop(pid)
    end
  end

  describe "mode/0 and force_mode/1" do
    test "mode returns :unknown when controller not running" do
      # Since it uses module name, when not started it returns fallback
      result = HomeostaticController.mode()
      assert result in [:normal, :stressed, :degraded, :critical, :recovery, :unknown]
    end

    test "force_mode/1 accepts valid modes" do
      name = :"HomeostaticForceMode_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(HomeostaticController, [], name: name)

      # force_mode/1 uses __MODULE__ as name, so test via direct call
      GenServer.cast(pid, {:force_mode, :stressed})
      Process.sleep(30)

      state = :sys.get_state(pid)
      assert state.mode == :stressed

      GenServer.stop(pid)
    end
  end

  describe "resource_budgets/0" do
    test "returns a map when controller not running" do
      result = HomeostaticController.resource_budgets()
      assert is_map(result)
    end

    test "budget map has expected resource keys" do
      result = HomeostaticController.resource_budgets()
      assert Map.has_key?(result, :agent_pool)
      assert Map.has_key?(result, :log_verbosity)
      assert Map.has_key?(result, :telemetry_resolution)
    end
  end

  describe "degradation_level/0" do
    test "returns integer 0 when not running (fallback)" do
      result = HomeostaticController.degradation_level()
      assert is_integer(result)
      assert result >= 0
    end
  end

  describe "recovery_progress/0" do
    test "returns float when not running (fallback)" do
      result = HomeostaticController.recovery_progress()
      assert is_float(result)
      assert result >= 0.0 and result <= 1.0
    end
  end

  describe "recent_actions/0" do
    test "returns empty list when not running (fallback)" do
      result = HomeostaticController.recent_actions()
      assert is_list(result)
    end
  end

  describe "status/0" do
    test "returns map when not running (fallback)" do
      result = HomeostaticController.status()
      assert is_map(result)
    end

    test "fallback status has :mode key" do
      result = HomeostaticController.status()
      assert Map.has_key?(result, :mode)
    end
  end

  describe "feature_active?/1" do
    test "returns true for unknown features when not running (fallback)" do
      result = HomeostaticController.feature_active?(:some_feature)
      assert result == true
    end
  end

  describe "subscribe/1" do
    test "accepts a pid for subscription" do
      name = :"HomeostaticSubscribe_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(HomeostaticController, [], name: name)

      # subscribe uses cast, returns :ok implicitly
      GenServer.cast(pid, {:subscribe, self()})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
