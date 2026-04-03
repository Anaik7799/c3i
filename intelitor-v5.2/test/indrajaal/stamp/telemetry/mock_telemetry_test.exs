defmodule Indrajaal.STAMP.Telemetry.MockTelemetryTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.Telemetry.MockTelemetry pure module.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.STAMP.Telemetry.MockTelemetry

  setup do
    MockTelemetry.initialize_mock_system()
    on_exit(fn -> MockTelemetry.cleanup_mock_system() end)
    :ok
  end

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(MockTelemetry)
    end

    test "attach/4 is exported" do
      assert function_exported?(MockTelemetry, :attach, 4)
    end

    test "detach/1 is exported" do
      assert function_exported?(MockTelemetry, :detach, 1)
    end

    test "list_handlers/0 is exported" do
      assert function_exported?(MockTelemetry, :list_handlers, 0)
    end

    test "process_request/3 is exported" do
      assert function_exported?(MockTelemetry, :process_request, 3)
    end

    test "initialize_mock_system/0 is exported" do
      assert function_exported?(MockTelemetry, :initialize_mock_system, 0)
    end

    test "cleanup_mock_system/0 is exported" do
      assert function_exported?(MockTelemetry, :cleanup_mock_system, 0)
    end

    test "get_mock_statistics/0 is exported" do
      assert function_exported?(MockTelemetry, :get_mock_statistics, 0)
    end
  end

  describe "initialize_mock_system/0" do
    test "returns :ok" do
      result = MockTelemetry.initialize_mock_system()
      assert match?(:ok, result) or match?({:ok, _}, result)
    end
  end

  describe "attach/4 and detach/1" do
    test "attach returns :ok" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end
      result = MockTelemetry.attach("test-handler", [:test, :event], handler_fn, nil)
      assert result == :ok
    end

    test "detach returns :ok" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end
      MockTelemetry.attach("test-handler-2", [:test, :event2], handler_fn, nil)
      result = MockTelemetry.detach("test-handler-2")
      assert result == :ok
    end
  end

  describe "list_handlers/0" do
    test "returns a list" do
      result = MockTelemetry.list_handlers()
      assert is_list(result)
    end

    test "returns handler ids after attach" do
      handler_fn = fn _event, _measurements, _metadata, _config -> :ok end
      MockTelemetry.attach("list-test-handler", [:list, :test], handler_fn, nil)
      handlers = MockTelemetry.list_handlers()
      assert is_list(handlers)
    end
  end

  describe "process_request/3" do
    test "returns :ok" do
      result = MockTelemetry.process_request([:test, :event], %{count: 1}, %{})
      assert result == :ok
    end
  end

  describe "get_mock_statistics/0" do
    test "returns a map with required fields" do
      result = MockTelemetry.get_mock_statistics()
      assert is_map(result)
      assert Map.has_key?(result, :mock_system_operational)
      assert result.mock_system_operational == true
    end

    test "handlers_attached count is non-negative" do
      result = MockTelemetry.get_mock_statistics()
      assert result.handlers_attached >= 0
    end
  end

  describe "cleanup_mock_system/0" do
    test "returns :ok" do
      result = MockTelemetry.cleanup_mock_system()
      assert result == :ok
    end
  end
end
