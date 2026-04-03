defmodule Indrajaal.Notifications.Backends.NotificationHelpers do
  @moduledoc """
  Shared helper functions for notification backends.

  Centralizes common functionality used across Slack, Email, Teams, and other
  notification backends to eliminate code duplication.

  WHAT: Common utilities for alert formatting, timestamp handling, and severity mapping.
  WHY: DRY principle - avoid duplicate code across notification backends.
  CONSTRAINTS: Must remain backend-agnostic; backend-specific formatting stays in backends.

  STAMP Compliance:
  - SC-OBS-067: Real-time alert delivery support
  - SC-DOC-001: Module documentation with WHAT/WHY/CONSTRAINTS
  """

  @type severity :: :critical | :high | :medium | :low | :info | atom()
  @type alert :: map()
  @type alert_fields :: %{
          severity: severity(),
          title: String.t(),
          description: String.t(),
          source: String.t(),
          timestamp: DateTime.t(),
          details: map()
        }

  @doc """
  Extracts common alert fields with defaults.

  ## Parameters
    - alert: Alert data map

  ## Returns
    - Map with normalized alert fields: severity, title, description, source, timestamp, details
  """
  @spec extract_alert_fields(alert()) :: alert_fields()
  def extract_alert_fields(alert) when is_map(alert) do
    %{
      severity: Map.get(alert, :severity, :info),
      title: Map.get(alert, :title, "Alert"),
      description: Map.get(alert, :description, ""),
      source: Map.get(alert, :source, "intelitor"),
      timestamp: Map.get(alert, :timestamp, DateTime.utc_now()),
      details: Map.get(alert, :details, %{})
    }
  end

  @doc """
  Formats a DateTime to a standard UTC string.

  ## Parameters
    - dt: DateTime struct or binary string

  ## Returns
    - Formatted string "YYYY-MM-DD HH:MM:SS UTC"
  """
  @spec format_timestamp(DateTime.t() | String.t() | any()) :: String.t()
  def format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_timestamp(ts) when is_binary(ts), do: ts
  def format_timestamp(_), do: "Unknown"

  @doc """
  Returns numeric rank for severity comparison.

  Higher rank = more severe.

  ## Parameters
    - severity: Severity atom

  ## Returns
    - Integer rank (0-5)
  """
  @spec severity_rank(severity()) :: non_neg_integer()
  def severity_rank(:critical), do: 5
  def severity_rank(:high), do: 4
  def severity_rank(:medium), do: 3
  def severity_rank(:low), do: 2
  def severity_rank(:info), do: 1
  def severity_rank(_), do: 0

  @doc """
  Maps severity to hex color for Slack-style notifications.

  ## Parameters
    - severity: Severity atom

  ## Returns
    - Hex color string with # prefix
  """
  @spec severity_to_slack_color(severity()) :: String.t()
  def severity_to_slack_color(:critical), do: "#FF0000"
  def severity_to_slack_color(:high), do: "#FF6600"
  def severity_to_slack_color(:medium), do: "#FFCC00"
  def severity_to_slack_color(:low), do: "#00CC00"
  def severity_to_slack_color(:info), do: "#0066FF"
  def severity_to_slack_color(_), do: "#808_080"

  @doc """
  Maps severity to hex color for Email HTML notifications.

  Uses Bootstrap-style colors.

  ## Parameters
    - severity: Severity atom

  ## Returns
    - Hex color string with # prefix
  """
  @spec severity_to_email_color(severity()) :: String.t()
  def severity_to_email_color(:critical), do: "#dc3545"
  def severity_to_email_color(:high), do: "#fd7e14"
  def severity_to_email_color(:medium), do: "#ffc107"
  def severity_to_email_color(:low), do: "#28a745"
  def severity_to_email_color(:info), do: "#17a2b8"
  def severity_to_email_color(_), do: "#6c757d"

  @doc """
  Maps severity to hex color for Teams notifications.

  Teams uses colors without # prefix.

  ## Parameters
    - severity: Severity atom

  ## Returns
    - Hex color string without # prefix
  """
  @spec severity_to_teams_color(severity()) :: String.t()
  def severity_to_teams_color(:critical), do: "FF0000"
  def severity_to_teams_color(:high), do: "FF6600"
  def severity_to_teams_color(:medium), do: "FFCC00"
  def severity_to_teams_color(:low), do: "00CC00"
  def severity_to_teams_color(:info), do: "0066FF"
  def severity_to_teams_color(_), do: "808_080"

  @doc """
  Maps severity to Slack emoji.

  ## Parameters
    - severity: Severity atom

  ## Returns
    - Slack emoji string
  """
  @spec severity_to_slack_emoji(severity()) :: String.t()
  def severity_to_slack_emoji(:critical), do: ":rotating_light:"
  def severity_to_slack_emoji(:high), do: ":warning:"
  def severity_to_slack_emoji(:medium), do: ":large_orange_diamond:"
  def severity_to_slack_emoji(:low), do: ":information_source:"
  def severity_to_slack_emoji(:info), do: ":speech_balloon:"
  def severity_to_slack_emoji(_), do: ":bell:"

  @doc """
  Maps severity to Unicode emoji for email.

  ## Parameters
    - severity: Severity atom

  ## Returns
    - Unicode emoji string
  """
  @spec severity_to_unicode_emoji(severity()) :: String.t()
  def severity_to_unicode_emoji(:critical), do: "\u{1F6A8}"
  def severity_to_unicode_emoji(:high), do: "\u{26A0}\u{FE0F}"
  def severity_to_unicode_emoji(:medium), do: "\u{1F536}"
  def severity_to_unicode_emoji(:low), do: "\u{2139}\u{FE0F}"
  def severity_to_unicode_emoji(:info), do: "\u{1F4AC}"
  def severity_to_unicode_emoji(_), do: "\u{1F514}"

  @doc """
  Emits telemetry event for notification operations.

  ## Parameters
    - event: Event type atom (:start, :success, :failure)
    - channel: Channel atom for namespacing
    - metadata: Additional metadata map
  """
  @spec emit_telemetry(atom(), atom(), map()) :: :ok
  def emit_telemetry(event, channel, metadata \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :notifications, channel, event],
      %{count: 1, timestamp: System.monotonic_time()},
      metadata
    )
  end
end
