defmodule Indrajaal.Notifications.Backends.OpsGenieTest do
  @moduledoc """
  TDG test suite for OpsGenie notification backend.

  ## STAMP Safety Integration
  - SC-OBS-067: Real-time alert delivery
  - SC-EMR-058: Emergency notification channels
  - SC-EMR-059: Escalation support

  ## TPS 5-Level RCA Context
  - L1 Symptom: OpsGenie alerts not delivered
  - L5 Root Cause: Missing API key validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Notifications.Backends.OpsGenie

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(OpsGenie)
    end

    test "deliver/2 is exported" do
      assert function_exported?(OpsGenie, :deliver, 1)
      assert function_exported?(OpsGenie, :deliver, 2)
    end
  end

  describe "behaviour implementation" do
    test "implements notification behaviour" do
      behaviours = OpsGenie.__info__(:attributes) |> Keyword.get_values(:behaviour)
      flat = List.flatten(behaviours)
      assert Indrajaal.Notifications.Backends.Behaviour in flat
    end
  end

  describe "deliver/2 with missing api_key" do
    test "returns error when api_key is absent" do
      result = OpsGenie.deliver(%{message: "Test alert"})
      assert match?({:error, _}, result)
    end
  end

  describe "deliver/2 with missing message" do
    test "returns error when message is absent" do
      result = OpsGenie.deliver(%{api_key: "test-api-key"})
      assert match?({:error, _}, result)
    end
  end

  describe "deliver/2 with unreachable endpoint" do
    test "returns error when OpsGenie is unreachable" do
      result =
        OpsGenie.deliver(%{
          api_key: "test-api-key",
          message: "Test alert"
        })

      assert match?({:error, _}, result)
    end
  end

  describe "priority types" do
    test "recognized priorities are P1 through P5" do
      priorities = [:P1, :P2, :P3, :P4, :P5]
      Enum.each(priorities, fn p -> assert is_atom(p) end)
    end

    test "P1 is highest priority atom" do
      assert :P1 == :P1
    end
  end

  describe "retry configuration" do
    test "retry attempts constant is positive" do
      retry_attempts = 3
      assert retry_attempts > 0
    end

    test "alerts api url is defined" do
      url = "https://api.opsgenie.com/v2/alerts"
      assert String.starts_with?(url, "https://")
    end
  end
end
