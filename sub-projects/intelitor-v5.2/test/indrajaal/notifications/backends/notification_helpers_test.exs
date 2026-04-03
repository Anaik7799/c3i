defmodule Indrajaal.Notifications.Backends.NotificationHelpersTest do
  @moduledoc """
  TDG test suite for NotificationHelpers.

  ## STAMP Safety Integration
  - SC-OBS-067: Real-time alert delivery
  - SC-DOC-001: Module documentation requirements

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alert fields missing on delivery
  - L5 Root Cause: No default value handling for alert fields
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Notifications.Backends.NotificationHelpers

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(NotificationHelpers)
    end

    test "public functions are exported" do
      assert function_exported?(NotificationHelpers, :extract_alert_fields, 1)
      assert function_exported?(NotificationHelpers, :format_timestamp, 1)
      assert function_exported?(NotificationHelpers, :severity_rank, 1)
      assert function_exported?(NotificationHelpers, :severity_to_slack_color, 1)
      assert function_exported?(NotificationHelpers, :severity_to_email_color, 1)
    end
  end

  describe "extract_alert_fields/1" do
    test "extracts all fields from complete alert" do
      alert = %{
        severity: :high,
        title: "High Priority Alert",
        description: "Something went wrong",
        source: "test",
        timestamp: DateTime.utc_now(),
        details: %{code: 500}
      }

      fields = NotificationHelpers.extract_alert_fields(alert)

      assert fields.severity == :high
      assert fields.title == "High Priority Alert"
      assert fields.description == "Something went wrong"
      assert fields.source == "test"
      assert is_map(fields.details)
    end

    test "uses defaults for missing fields" do
      alert = %{}
      fields = NotificationHelpers.extract_alert_fields(alert)

      assert fields.severity == :info
      assert fields.title == "Alert"
      assert fields.description == ""
      assert fields.source == "intelitor"
    end

    test "handles partial alert" do
      alert = %{severity: :critical}
      fields = NotificationHelpers.extract_alert_fields(alert)

      assert fields.severity == :critical
      assert is_binary(fields.title)
    end
  end

  describe "format_timestamp/1" do
    test "formats DateTime to string" do
      dt = ~U[2026-01-15 10:30:00Z]
      result = NotificationHelpers.format_timestamp(dt)

      assert is_binary(result)
      assert String.contains?(result, "2026")
      assert String.contains?(result, "UTC")
    end

    test "passes through binary timestamps" do
      ts = "2026-01-15 10:30:00 UTC"
      result = NotificationHelpers.format_timestamp(ts)
      assert result == ts
    end

    test "handles unknown timestamp format" do
      result = NotificationHelpers.format_timestamp(nil)
      assert result == "Unknown"
    end
  end

  describe "severity_rank/1" do
    test "critical has highest rank" do
      assert NotificationHelpers.severity_rank(:critical) == 5
    end

    test "high rank is 4" do
      assert NotificationHelpers.severity_rank(:high) == 4
    end

    test "medium rank is 3" do
      assert NotificationHelpers.severity_rank(:medium) == 3
    end

    test "low rank is 2" do
      assert NotificationHelpers.severity_rank(:low) == 2
    end

    test "info rank is 1" do
      assert NotificationHelpers.severity_rank(:info) == 1
    end

    test "unknown severity returns 0" do
      assert NotificationHelpers.severity_rank(:unknown) == 0
    end

    test "severity ranks are ordered" do
      assert NotificationHelpers.severity_rank(:critical) >
               NotificationHelpers.severity_rank(:high)

      assert NotificationHelpers.severity_rank(:high) >
               NotificationHelpers.severity_rank(:medium)

      assert NotificationHelpers.severity_rank(:medium) >
               NotificationHelpers.severity_rank(:low)
    end
  end

  describe "severity_to_slack_color/1" do
    test "critical maps to red" do
      assert NotificationHelpers.severity_to_slack_color(:critical) == "#FF0000"
    end

    test "high maps to orange" do
      assert NotificationHelpers.severity_to_slack_color(:high) == "#FF6600"
    end

    test "info maps to blue" do
      assert NotificationHelpers.severity_to_slack_color(:info) == "#0066FF"
    end

    test "all standard severities return hex colors" do
      severities = [:critical, :high, :medium, :low, :info]

      Enum.each(severities, fn sev ->
        color = NotificationHelpers.severity_to_slack_color(sev)
        assert is_binary(color)
        assert String.starts_with?(color, "#")
      end)
    end
  end

  describe "severity_to_email_color/1" do
    test "critical maps to danger red" do
      assert NotificationHelpers.severity_to_email_color(:critical) == "#dc3545"
    end

    test "info maps to cyan" do
      assert NotificationHelpers.severity_to_email_color(:info) == "#17a2b8"
    end

    test "all standard severities return hex colors" do
      severities = [:critical, :high, :medium, :low, :info]

      Enum.each(severities, fn sev ->
        color = NotificationHelpers.severity_to_email_color(sev)
        assert is_binary(color)
        assert String.starts_with?(color, "#")
      end)
    end
  end
end
