defmodule Indrajaal.Cockpit.Prajna.InfraIntegrationTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Prajna.InfraIntegration.

  ## STAMP Safety Integration
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-INFRA-INTEG-001: 100ms detection of process death

  ## TPS 5-Level RCA Context
  - L1 Symptom: Infrastructure metrics not surfaced to cockpit
  - L5 Root Cause: GenServer integration missing or stale
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.InfraIntegration

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      test_name = :"infra_integ_#{System.unique_integer()}"
      assert {:ok, pid} = start_supervised({InfraIntegration, [name: test_name]})
      assert Process.alive?(pid)
    end
  end

  describe "initial state" do
    test "children_status starts empty" do
      test_name = :"infra_children_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({InfraIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert state.children_status == %{}
    end

    test "total_restarts starts at zero" do
      test_name = :"infra_restarts_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({InfraIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert state.total_restarts == 0
    end

    test "last_sync starts as nil" do
      test_name = :"infra_sync_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({InfraIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert is_nil(state.last_sync)
    end

    test "state is a struct with required fields" do
      test_name = :"infra_struct_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({InfraIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert Map.has_key?(state, :children_status)
      assert Map.has_key?(state, :total_restarts)
      assert Map.has_key?(state, :last_sync)
    end
  end

  describe "get_status/0" do
    test "get_status/0 is exported" do
      assert function_exported?(InfraIntegration, :get_status, 0)
    end
  end

  describe "GenServer behaviour" do
    test "implements GenServer" do
      behaviours = InfraIntegration.__info__(:attributes)[:behaviour] || []
      assert GenServer in behaviours
    end

    test "process stays alive after init" do
      test_name = :"infra_alive_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({InfraIntegration, [name: test_name]})

      :timer.sleep(10)
      assert Process.alive?(pid)
    end
  end
end
