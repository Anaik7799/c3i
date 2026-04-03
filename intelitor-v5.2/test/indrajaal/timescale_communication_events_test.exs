defmodule TimescaleCommunicationEventsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(TimescaleCommunicationEvents)
  end

  test "setup_hypertables/0 is exported" do
    assert function_exported?(TimescaleCommunicationEvents, :setup_hypertables, 0)
  end

  test "record_event/1 is exported" do
    assert function_exported?(TimescaleCommunicationEvents, :record_event, 1)
  end

  test "query_events/1 is exported" do
    assert function_exported?(TimescaleCommunicationEvents, :query_events, 1)
  end

  test "setup_hypertables/0 returns not implemented error (stub)" do
    assert {:error, _reason} = TimescaleCommunicationEvents.setup_hypertables()
  end

  test "record_event/1 returns not implemented error (stub)" do
    assert {:error, _reason} = TimescaleCommunicationEvents.record_event(%{type: :test})
  end

  test "query_events/1 returns not implemented error (stub)" do
    assert {:error, _reason} = TimescaleCommunicationEvents.query_events(%{})
  end
end
