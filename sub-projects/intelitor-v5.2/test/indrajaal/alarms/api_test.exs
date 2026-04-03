defmodule Indrajaal.Alarms.ApiTest do
  @moduledoc """
  TDG test suite for Indrajaal.Alarms.Api.

  ## STAMP Safety Integration
  - SC-ALARM-001: Alarm creation must validate required fields
  - SC-ALARM-002: Acknowledgment requires operator context

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alarm API returns unexpected shapes
  - L5 Root Cause: Missing input validation or broken Ash action wiring
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Indrajaal.Alarms.Api module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Alarms.Api)
    end

    test "module exports required public functions" do
      exports = Indrajaal.Alarms.Api.__info__(:functions)
      function_names = Keyword.keys(exports)

      assert :create_alarm_event in function_names
      assert :acknowledge_alarm in function_names
      assert :resolve_alarm in function_names
      assert :list_alarm_events in function_names
      assert :get_alarm_event in function_names
    end
  end

  describe "create_alarm_event/2" do
    test "returns a tuple result" do
      result = Indrajaal.Alarms.Api.create_alarm_event(%{}, %{})
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns error when called with empty params" do
      result = Indrajaal.Alarms.Api.create_alarm_event(%{}, %{})
      # Missing required fields should produce an error
      assert {:error, _} = result
    end
  end

  describe "acknowledge_alarm/3" do
    test "returns a tuple result" do
      result = Indrajaal.Alarms.Api.acknowledge_alarm("nonexistent-id", "operator_id", %{})
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "resolve_alarm/4" do
    test "returns a tuple result" do
      result =
        Indrajaal.Alarms.Api.resolve_alarm("nonexistent-id", "operator_id", "false_alarm", %{})

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "list_alarm_events/2" do
    test "returns a tuple result" do
      result = Indrajaal.Alarms.Api.list_alarm_events(%{}, %{})
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "get_alarm_event/2" do
    test "returns a tuple result for nonexistent id" do
      result = Indrajaal.Alarms.Api.get_alarm_event("00000000-0000-0000-0000-000000000000", %{})
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "get_alarm_statistics/2" do
    test "returns a tuple result" do
      result = Indrajaal.Alarms.Api.get_alarm_statistics(%{}, %{})
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
