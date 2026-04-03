defmodule Indrajaal.Observability.QuadplexLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.QuadplexLogger.

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging (Terminal + SigNoz/OTEL) mandatory
  - SC-OBS-071: 4 OTEL modules must be operational

  ## TPS 5-Level RCA Context
  - L1 Symptom: Multi-output log handler not functioning
  - L5 Root Cause: Loss of observability across telemetry pipeline
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.QuadplexLogger)
    end

    test "start_link/1 exported" do
      assert function_exported?(Indrajaal.Observability.QuadplexLogger, :start_link, 1)
    end

    test "handle_info/2 exported" do
      assert function_exported?(Indrajaal.Observability.QuadplexLogger, :handle_info, 2)
    end

    test "handle_event/2 exported" do
      assert function_exported?(Indrajaal.Observability.QuadplexLogger, :handle_event, 2)
    end
  end

  describe "start_link/1" do
    test "starts without error with unique name" do
      opts = [name: :"QuadplexTest_#{System.unique_integer([:positive])}"]
      result = start_supervised!({Indrajaal.Observability.QuadplexLogger, opts})
      assert is_pid(result)
    end
  end

  describe "handle_info/2 - log messages" do
    test "processes :log messages without crashing" do
      name = :"QuadplexHandleInfo_#{System.unique_integer([:positive])}"
      {:ok, pid} = Indrajaal.Observability.QuadplexLogger.start_link(name: name)

      send(pid, {:log, :info, "test message", %{}})
      Process.sleep(20)

      # Verify process still alive
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "processes error level messages" do
      name = :"QuadplexError_#{System.unique_integer([:positive])}"
      {:ok, pid} = Indrajaal.Observability.QuadplexLogger.start_link(name: name)

      send(pid, {:log, :error, "error message", %{module: TestModule}})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "GenServer lifecycle" do
    test "init returns ok with log_path state" do
      name = :"QuadplexInit_#{System.unique_integer([:positive])}"
      {:ok, pid} = Indrajaal.Observability.QuadplexLogger.start_link(name: name)

      state = :sys.get_state(pid)
      assert Map.has_key?(state, :log_path)
      assert is_binary(state.log_path)

      GenServer.stop(pid)
    end
  end
end
