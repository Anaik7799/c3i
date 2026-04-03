defmodule Indrajaal.Observability.KMSLoggerBackendTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.KMSLoggerBackend.

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging (Terminal + file) must be operational

  ## TPS 5-Level RCA Context
  - L1 Symptom: Fractal execution log missing entries
  - L5 Root Cause: No persistent audit trail for regulatory compliance
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.KMSLoggerBackend

  describe "gen_event behaviour" do
    test "module implements gen_event behaviour" do
      assert Code.ensure_loaded?(Indrajaal.Observability.KMSLoggerBackend)
      behaviors = KMSLoggerBackend.module_info(:attributes)[:behaviour] || []
      assert :gen_event in behaviors
    end

    test "init/1 returns ok tuple" do
      {:ok, state} = KMSLoggerBackend.init([])
      assert is_map(state)
      assert Map.has_key?(state, :path)
    end

    test "init sets the path to kms fractal log" do
      {:ok, state} = KMSLoggerBackend.init([])
      assert String.contains?(state.path, "kms")
    end

    test "handle_event returns ok for valid log event" do
      {:ok, state} = KMSLoggerBackend.init([])

      ts = {{2026, 1, 1}, {12, 0, 0, 0}}
      event = {:info, :undefined, {Logger, "test message", ts, []}}

      result = KMSLoggerBackend.handle_event(event, state)
      assert match?({:ok, _}, result)
    end

    test "handle_event returns ok for unknown events" do
      {:ok, state} = KMSLoggerBackend.init([])
      result = KMSLoggerBackend.handle_event(:some_unknown_event, state)
      assert match?({:ok, _}, result)
    end

    test "handle_call returns ok" do
      {:ok, state} = KMSLoggerBackend.init([])
      result = KMSLoggerBackend.handle_call(:any_call, state)
      assert match?({:ok, :ok, _}, result)
    end

    test "handle_info returns ok" do
      {:ok, state} = KMSLoggerBackend.init([])
      result = KMSLoggerBackend.handle_info(:any_info, state)
      assert match?({:ok, _}, result)
    end

    test "terminate returns ok" do
      {:ok, state} = KMSLoggerBackend.init([])
      result = KMSLoggerBackend.terminate(:normal, state)
      assert result == :ok
    end

    test "code_change returns ok" do
      {:ok, state} = KMSLoggerBackend.init([])
      result = KMSLoggerBackend.code_change(:old, state, [])
      assert match?({:ok, _}, result)
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.KMSLoggerBackend)
    end

    test "init/1 exported" do
      assert function_exported?(KMSLoggerBackend, :init, 1)
    end

    test "handle_event/2 exported" do
      assert function_exported?(KMSLoggerBackend, :handle_event, 2)
    end

    test "handle_call/2 exported" do
      assert function_exported?(KMSLoggerBackend, :handle_call, 2)
    end

    test "terminate/2 exported" do
      assert function_exported?(KMSLoggerBackend, :terminate, 2)
    end
  end
end
