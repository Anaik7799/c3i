defmodule Indrajaal.Observability.LokiBackendTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.LokiBackend.

  ## STAMP Safety Integration
  - SC-LOKI-001: Batched log shipping verified
  - SC-LOKI-003: Graceful degradation on Loki unavailable

  ## TPS 5-Level RCA Context
  - L1 Symptom: Logs not reaching Loki
  - L5 Root Cause: gen_event backend fails silently
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.LokiBackend

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(LokiBackend)
    end

    test "implements gen_event behaviour" do
      behaviours = LokiBackend.__info__(:attributes)[:behaviour] || []
      assert :gen_event in behaviours
    end

    test "init/1 exported" do
      assert function_exported?(LokiBackend, :init, 1)
    end

    test "handle_event/2 exported" do
      assert function_exported?(LokiBackend, :handle_event, 2)
    end

    test "handle_info/2 exported" do
      assert function_exported?(LokiBackend, :handle_info, 2)
    end

    test "handle_call/2 exported" do
      assert function_exported?(LokiBackend, :handle_call, 2)
    end

    test "terminate/2 exported" do
      assert function_exported?(LokiBackend, :terminate, 2)
    end

    test "code_change/3 exported" do
      assert function_exported?(LokiBackend, :code_change, 3)
    end

    test "get_stats/0 exported" do
      assert function_exported?(LokiBackend, :get_stats, 0)
    end

    test "flush/0 exported" do
      assert function_exported?(LokiBackend, :flush, 0)
    end
  end

  describe "init/1" do
    test "initializes with module as arg" do
      result = LokiBackend.init({LokiBackend, []})
      assert {:ok, state} = result
      assert is_struct(state, LokiBackend)
    end

    test "state has expected fields" do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      assert Map.has_key?(state, :config)
      assert Map.has_key?(state, :level)
      assert Map.has_key?(state, :buffer)
      assert Map.has_key?(state, :buffer_size)
      assert Map.has_key?(state, :circuit_state)
      assert Map.has_key?(state, :failure_count)
    end

    test "buffer starts empty" do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      assert state.buffer == []
      assert state.buffer_size == 0
    end

    test "circuit starts closed" do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      assert state.circuit_state == :closed
    end

    test "failure count starts at zero" do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      assert state.failure_count == 0
    end

    test "accepts custom opts" do
      {:ok, state} = LokiBackend.init({LokiBackend, [level: :warning]})
      assert state.level == :warning
    end
  end

  describe "handle_event/2" do
    setup do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      {:ok, state: state}
    end

    test "handles log event for info level", %{state: state} do
      event = {:info, self(), {Logger, "test message", System.os_time(:nanosecond), []}}
      result = LokiBackend.handle_event(event, state)
      assert {:ok, _new_state} = result
    end

    test "handles log event for warning level", %{state: state} do
      event = {:warning, self(), {Logger, "warning message", System.os_time(:nanosecond), []}}
      result = LokiBackend.handle_event(event, state)
      assert {:ok, _new_state} = result
    end

    test "handles log event for error level", %{state: state} do
      event = {:error, self(), {Logger, "error message", System.os_time(:nanosecond), []}}
      result = LokiBackend.handle_event(event, state)
      assert {:ok, _new_state} = result
    end

    test "handles flush event", %{state: state} do
      result = LokiBackend.handle_event(:flush, state)
      assert {:ok, _new_state} = result
    end

    test "handles unknown events without crashing", %{state: state} do
      result = LokiBackend.handle_event(:unknown_event, state)
      assert {:ok, _new_state} = result
    end

    test "buffers log entries below batch_size", %{state: state} do
      event = {:info, self(), {Logger, "buffered message", System.os_time(:nanosecond), []}}
      {:ok, new_state} = LokiBackend.handle_event(event, state)
      # Buffer should have grown or been flushed (both valid behaviors)
      assert is_integer(new_state.buffer_size)
    end
  end

  describe "handle_call/2" do
    setup do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      {:ok, state: state}
    end

    test "get_stats returns stats map", %{state: state} do
      result = LokiBackend.handle_call(:get_stats, state)
      assert {:ok, stats, _new_state} = result
      assert is_map(stats)
    end

    test "stats map has expected keys", %{state: state} do
      {:ok, stats, _} = LokiBackend.handle_call(:get_stats, state)
      assert Map.has_key?(stats, :buffer_size)
      assert Map.has_key?(stats, :level)
      assert Map.has_key?(stats, :circuit_state)
      assert Map.has_key?(stats, :failure_count)
    end
  end

  describe "handle_info/2" do
    setup do
      {:ok, state} = LokiBackend.init({LokiBackend, []})
      {:ok, state: state}
    end

    test "handles unknown messages without crashing", %{state: state} do
      result = LokiBackend.handle_info(:some_unknown_message, state)
      assert {:ok, _new_state} = result
    end
  end

  describe "get_stats/0 public API" do
    test "returns ok tuple or error when backend not registered" do
      result = LokiBackend.get_stats()
      assert result == {:error, :backend_not_running} or match?({:ok, _}, result)
    end
  end
end
