defmodule Indrajaal.Observability.TriplexLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.TriplexLogger.

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging (terminal + file) for lightweight containers

  ## TPS 5-Level RCA Context
  - L1 Symptom: No file logging in lightweight containers
  - L5 Root Cause: Test runs and minimal deploys lose audit trail
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.TriplexLogger

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TriplexLogger)
    end

    test "start_link/1 exported" do
      assert function_exported?(TriplexLogger, :start_link, 1)
    end

    test "handle_info/2 exported" do
      assert function_exported?(TriplexLogger, :handle_info, 2)
    end

    test "handle_event/2 exported" do
      assert function_exported?(TriplexLogger, :handle_event, 2)
    end
  end

  describe "start_link/1" do
    test "starts without error" do
      name = :"TriplexTest_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised!({TriplexLogger, [name: name]})
      assert is_pid(pid)
    end
  end

  describe "GenServer state" do
    test "init creates log_path in state" do
      name = :"TriplexState_#{System.unique_integer([:positive])}"
      {:ok, pid} = TriplexLogger.start_link(name: name)

      state = :sys.get_state(pid)
      assert Map.has_key?(state, :log_path)
      assert String.contains?(state.log_path, "triplex")

      GenServer.stop(pid)
    end
  end

  describe "handle_info/2" do
    test "processes log messages without crashing" do
      name = :"TriplexHandleInfo_#{System.unique_integer([:positive])}"
      {:ok, pid} = TriplexLogger.start_link(name: name)

      send(pid, {:log, :info, "test triplex message", %{}})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "processes warning messages" do
      name = :"TriplexWarn_#{System.unique_integer([:positive])}"
      {:ok, pid} = TriplexLogger.start_link(name: name)

      send(pid, {:log, :warning, "warning message", %{context: "test"}})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
