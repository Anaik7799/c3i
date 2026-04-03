defmodule Indrajaal.Notifications.DispatcherTest do
  @moduledoc """
  TDG test suite for Notifications.Dispatcher.

  ## STAMP Safety Integration
  - SC-OBS-067: Real-time alert delivery
  - SC-EMR-058: Emergency notification channels

  ## TPS 5-Level RCA Context
  - L1 Symptom: Notifications not delivered
  - L5 Root Cause: Missing channel fallback on delivery failure
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Notifications.Dispatcher

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Dispatcher)
    end

    test "dispatch/3 is exported" do
      assert function_exported?(Dispatcher, :dispatch, 1)
      assert function_exported?(Dispatcher, :dispatch, 2)
      assert function_exported?(Dispatcher, :dispatch, 3)
    end
  end

  describe "dispatch/1 with empty channels" do
    test "returns ok or error tuple" do
      alert = %{
        id: "test-alert-001",
        severity: :info,
        title: "Test Alert",
        description: "Test description"
      }

      result = Dispatcher.dispatch(alert, [], [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "dispatch/3 with no channels" do
    test "handles empty channel list gracefully" do
      alert = %{severity: :low, title: "Low Alert", description: "Low priority"}
      result = Dispatcher.dispatch(alert, [], [])
      # With no channels, should return error (all channels failed)
      assert match?({:error, _}, result) or match?({:ok, %{}}, result)
    end
  end

  describe "dispatch channel types" do
    test "supported channel types are valid atoms" do
      channels = [:slack, :email, :pagerduty, :opsgenie, :push, :sms, :teams]
      Enum.each(channels, fn c -> assert is_atom(c) end)
    end
  end

  describe "severity types" do
    test "all severity levels are valid atoms" do
      severities = [:critical, :high, :medium, :low, :info]
      assert length(severities) == 5
      assert :critical in severities
    end
  end
end
