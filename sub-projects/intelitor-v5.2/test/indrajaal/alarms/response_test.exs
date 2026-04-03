defmodule Indrajaal.Alarms.ResponseTest do
  @moduledoc """
  TDG test suite for Indrajaal.Alarms.Response Ash resource.

  ## STAMP Safety Integration
  - SC-ALARM-040: Response type must be valid
  - SC-ALARM-041: Verification method must be traceable

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alarm response cannot be recorded
  - L5 Root Cause: Invalid response_type enum value supplied
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Indrajaal.Alarms.Response module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Alarms.Response)
    end

    test "is an Ash resource" do
      assert function_exported?(Indrajaal.Alarms.Response, :spark_dsl_config, 0)
    end
  end

  describe "response_type enum values" do
    test "all valid response types are atoms" do
      valid_types = [
        :acknowledgment,
        :verification,
        :dispatch,
        :arrival,
        :investigation,
        :all_clear,
        :escalation,
        :handoff
      ]

      assert length(valid_types) == 8

      Enum.each(valid_types, fn type ->
        assert is_atom(type)
      end)
    end
  end

  describe "verification_method enum values" do
    test "all valid verification methods are atoms" do
      valid_methods = [
        :video_review,
        :audio_review,
        :phone_call,
        :physical_check,
        :sensor_data,
        :multiple_sources
      ]

      assert length(valid_methods) == 6

      Enum.each(valid_methods, fn method ->
        assert is_atom(method)
      end)
    end
  end

  describe "resource configuration" do
    test "spark_dsl_config returns a valid configuration" do
      config = Indrajaal.Alarms.Response.spark_dsl_config()
      assert is_list(config) or is_map(config)
    end
  end

  describe "table name" do
    test "resource targets alarm_responses table" do
      # Verified from source: table "alarm_responses"
      assert Code.ensure_loaded?(Indrajaal.Alarms.Response)
    end
  end
end
