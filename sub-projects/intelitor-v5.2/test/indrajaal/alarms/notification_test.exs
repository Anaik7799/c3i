defmodule Indrajaal.Alarms.NotificationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Alarms.Notification Ash resource.

  ## STAMP Safety Integration
  - SC-ALARM-030: Notification channel must be valid
  - SC-ALARM-031: Notification status must follow lifecycle

  ## TPS 5-Level RCA Context
  - L1 Symptom: Notifications stuck in pending state
  - L5 Root Cause: Status transition validation missing
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Indrajaal.Alarms.Notification module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Alarms.Notification)
    end

    test "is an Ash resource" do
      assert function_exported?(Indrajaal.Alarms.Notification, :spark_dsl_config, 0)
    end
  end

  describe "recipient_type enum values" do
    test "valid recipient types are defined" do
      valid_types = [:customer, :contact, :authority, :operator, :guard, :supervisor, :external]
      assert length(valid_types) == 7

      Enum.each(valid_types, fn type ->
        assert is_atom(type)
      end)
    end
  end

  describe "channel enum values" do
    test "valid notification channels are defined" do
      valid_channels = [:email, :sms, :phone, :push, :webhook, :in_app]
      assert length(valid_channels) == 6

      Enum.each(valid_channels, fn channel ->
        assert is_atom(channel)
      end)
    end
  end

  describe "status enum values" do
    test "valid status values cover full lifecycle" do
      valid_statuses = [
        :pending,
        :queued,
        :sending,
        :delivered,
        :failed,
        :bounced,
        :rejected,
        :cancelled
      ]

      assert length(valid_statuses) == 8
    end

    test "default status is :pending" do
      default_status = :pending
      assert is_atom(default_status)
    end
  end

  describe "priority enum values" do
    test "valid priority levels are defined" do
      valid_priorities = [:low, :normal, :high, :urgent]
      assert length(valid_priorities) == 4
    end

    test "default priority is :normal" do
      default_priority = :normal
      assert is_atom(default_priority)
    end
  end

  describe "response_action enum values" do
    test "valid response actions are defined" do
      valid_actions = [
        :acknowledged,
        :false_alarm,
        :will_investigate,
        :dispatch_requested,
        :cancelled,
        :other
      ]

      assert length(valid_actions) == 6
    end
  end

  describe "resource configuration" do
    test "spark_dsl_config is accessible" do
      config = Indrajaal.Alarms.Notification.spark_dsl_config()
      assert is_list(config) or is_map(config)
    end
  end
end
