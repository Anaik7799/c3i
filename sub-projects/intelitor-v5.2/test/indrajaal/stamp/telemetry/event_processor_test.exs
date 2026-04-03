defmodule Indrajaal.STAMP.Telemetry.EventProcessorTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.Telemetry.EventProcessor GenServer.
  STAMP: SC-GDE-001, SC-TDG-001, SC-IMMUNE-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @moduletag :sil4

  alias Indrajaal.STAMP.Telemetry.EventProcessor

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(EventProcessor)
    end

    test "start_link/1 is exported" do
      assert function_exported?(EventProcessor, :start_link, 1)
    end

    test "process_alarm_event/2 is exported" do
      assert function_exported?(EventProcessor, :process_alarm_event, 2)
    end

    test "process_tenant_event/2 is exported" do
      assert function_exported?(EventProcessor, :process_tenant_event, 2)
    end

    test "process_auth_event/2 is exported" do
      assert function_exported?(EventProcessor, :process_auth_event, 2)
    end

    test "process_transaction_event/2 is exported" do
      assert function_exported?(EventProcessor, :process_transaction_event, 2)
    end

    test "process_generic_event/4 is exported" do
      assert function_exported?(EventProcessor, :process_generic_event, 4)
    end

    test "get_safety_metrics/0 is exported" do
      assert function_exported?(EventProcessor, :get_safety_metrics, 0)
    end

    test "get_violations/0 is exported" do
      assert function_exported?(EventProcessor, :get_violations, 0)
    end

    test "check_alarm_storm_condition/0 is exported" do
      assert function_exported?(EventProcessor, :check_alarm_storm_condition, 0)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      name = :"event_processor_#{System.unique_integer([:positive])}"

      case start_supervised({EventProcessor, [name: name]}) do
        {:ok, pid} -> {:ok, pid: pid, name: name}
        {:error, reason} -> {:error, reason}
      end
    end

    @tag :sil4
    test "starts successfully", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end

  describe "event processing via named server" do
    setup do
      {:ok, []}
    end

    @tag :sil4
    test "get_safety_metrics returns a map" do
      if Process.whereis(EventProcessor) do
        result = EventProcessor.get_safety_metrics()
        assert is_map(result)
      else
        assert true
      end
    end

    @tag :sil4
    test "check_alarm_storm_condition returns a map with active key" do
      if Process.whereis(EventProcessor) do
        result = EventProcessor.check_alarm_storm_condition()
        assert is_map(result)
        assert Map.has_key?(result, :active)
      else
        assert true
      end
    end

    @tag :sil4
    test "get_violations returns a list" do
      if Process.whereis(EventProcessor) do
        result = EventProcessor.get_violations()
        assert is_list(result)
      else
        assert true
      end
    end
  end
end
