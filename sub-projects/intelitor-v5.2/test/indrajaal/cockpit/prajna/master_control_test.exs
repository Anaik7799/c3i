defmodule Indrajaal.Cockpit.Prajna.MasterControlTest do
  @moduledoc """
  TDG test suite for MasterControl.

  ## STAMP Safety Integration
  - SC-CTRL-001: All commands through Guardian pre-approval
  - SC-CTRL-002: 5-order effects tracked for all actions

  ## TPS 5-Level RCA Context
  - L1 Symptom: Domain status returns :unknown health
  - L5 Root Cause: Health scoring computation defect
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.Prajna.MasterControl

  @moduletag :zenoh_nif

  @all_domains [
    :access_control,
    :accounts,
    :alarms,
    :analytics,
    :authentication,
    :authorization,
    :billing,
    :cluster,
    :cockpit,
    :communication,
    :compliance,
    :coordination,
    :cortex,
    :cybernetic,
    :devices,
    :dispatch,
    :distributed,
    :flame,
    :identity,
    :integration,
    :knowledge,
    :maintenance,
    :mesh,
    :observability,
    :policy,
    :safety,
    :security,
    :sites,
    :validation,
    :video
  ]

  # ============================================================================
  # domain_status/1 guard clause
  # ============================================================================

  describe "domain_status/1 guard" do
    test "rejects unknown domain atom with FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        MasterControl.domain_status(:not_a_real_domain)
      end
    end
  end

  # ============================================================================
  # GenServer lifecycle
  # ============================================================================

  describe "start_link/1" do
    test "starts under module name" do
      if pid = Process.whereis(MasterControl) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = MasterControl.start_link([])
      assert Process.alive?(pid)
      assert Process.whereis(MasterControl) == pid
      GenServer.stop(pid)
    end
  end

  describe "system_status/0" do
    setup do
      if pid = Process.whereis(MasterControl) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = MasterControl.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns :ok tuple" do
      assert {:ok, _status} = MasterControl.system_status()
    end

    test "status map contains domains key" do
      {:ok, status} = MasterControl.system_status()
      assert Map.has_key?(status, :domains)
    end

    test "domains key contains all 30 domains" do
      {:ok, status} = MasterControl.system_status()
      domain_keys = Map.keys(status.domains)

      Enum.each(@all_domains, fn domain ->
        assert domain in domain_keys, "Expected #{domain} in domains map"
      end)
    end

    test "status has circuit_breakers key" do
      {:ok, status} = MasterControl.system_status()
      assert Map.has_key?(status, :circuit_breakers)
    end

    test "circuit_breakers contains all domains" do
      {:ok, status} = MasterControl.system_status()

      Enum.each(@all_domains, fn domain ->
        assert Map.has_key?(status.circuit_breakers, domain)
      end)
    end

    test "circuit breakers start in closed state" do
      {:ok, status} = MasterControl.system_status()

      Enum.each(status.circuit_breakers, fn {_domain, breaker} ->
        assert breaker.state == :closed
      end)
    end

    test "status includes health_summary" do
      {:ok, status} = MasterControl.system_status()
      assert Map.has_key?(status, :health_summary)
    end

    test "health_summary has total field" do
      {:ok, status} = MasterControl.system_status()
      assert Map.has_key?(status.health_summary, :total)
    end

    test "status has :running system status" do
      {:ok, status} = MasterControl.system_status()
      assert status.status == :running
    end

    test "each domain has module_count" do
      {:ok, status} = MasterControl.system_status()

      Enum.each(status.domains, fn {_domain, info} ->
        assert Map.has_key?(info, :module_count)
        assert is_integer(info.module_count)
        assert info.module_count > 0
      end)
    end

    test "alarms domain has expected module count" do
      {:ok, status} = MasterControl.system_status()
      alarms_info = status.domains[:alarms]
      assert alarms_info.module_count == 23
    end
  end

  describe "domain_status/1" do
    setup do
      if pid = Process.whereis(MasterControl) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = MasterControl.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns :ok tuple for valid domain :alarms" do
      assert {:ok, _info} = MasterControl.domain_status(:alarms)
    end

    test "returns domain key in response" do
      {:ok, info} = MasterControl.domain_status(:alarms)
      assert info.domain == :alarms
    end

    test "returns info field with module_count" do
      {:ok, info} = MasterControl.domain_status(:alarms)
      assert Map.has_key?(info, :info)
      assert Map.has_key?(info.info, :module_count)
    end

    test "returns health field" do
      {:ok, info} = MasterControl.domain_status(:alarms)
      assert Map.has_key?(info, :health)
    end

    test "returns modules list" do
      {:ok, info} = MasterControl.domain_status(:alarms)
      assert Map.has_key?(info, :modules)
    end

    test "returns genservers list" do
      {:ok, info} = MasterControl.domain_status(:alarms)
      assert Map.has_key?(info, :genservers)
    end

    test "returns telemetry data" do
      {:ok, info} = MasterControl.domain_status(:alarms)
      assert Map.has_key?(info, :telemetry)
    end

    test "analytics domain has module_count 32" do
      {:ok, info} = MasterControl.domain_status(:analytics)
      assert info.info.module_count == 32
    end
  end

  describe "analyze_effects/3" do
    setup do
      if pid = Process.whereis(MasterControl) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = MasterControl.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns :ok tuple" do
      assert {:ok, _effects} = MasterControl.analyze_effects(:alarms, :process, %{})
    end

    test "accepts empty params" do
      assert {:ok, _} = MasterControl.analyze_effects(:alarms, :process)
    end

    test "returns effects map" do
      {:ok, effects} = MasterControl.analyze_effects(:alarms, :process, %{})
      assert is_map(effects)
    end
  end

  describe "circuit_breaker_status/0" do
    setup do
      if pid = Process.whereis(MasterControl) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = MasterControl.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a map" do
      result = MasterControl.circuit_breaker_status()
      assert is_map(result)
    end

    test "all domains have circuit breaker entries" do
      result = MasterControl.circuit_breaker_status()

      Enum.each(@all_domains, fn domain ->
        assert Map.has_key?(result, domain)
      end)
    end

    test "each breaker has state, failures, and last_failure fields" do
      result = MasterControl.circuit_breaker_status()

      Enum.each(result, fn {_domain, breaker} ->
        assert Map.has_key?(breaker, :state)
        assert Map.has_key?(breaker, :failures)
        assert Map.has_key?(breaker, :last_failure)
      end)
    end

    test "initial failure count is 0" do
      result = MasterControl.circuit_breaker_status()

      Enum.each(result, fn {_domain, breaker} ->
        assert breaker.failures == 0
      end)
    end
  end
end
