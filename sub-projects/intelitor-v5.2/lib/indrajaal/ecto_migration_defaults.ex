defmodule Indrajaal.EctoMigrationDefaults do
  @moduledoc """
  Implementation of EctoMigrationDefault protocol for Indrajaal custom types.

  This module resolves the warnings about complex default values that cannot be
  automatically converted to Ecto migration defaults by the ash_postgres
    library.

  TPS Analysis: Root cause was missing protocol implementations for:
  - Maps (notification preferences, dashboard settings, risk matrices)
  - Lists (notification channels, video codecs, supported protocols)
  - Complex structured __data (schedules, operating hours, performance metrics)
  """

  # Implementation for Map types (most common case)
  defimpl EctoMigrationDefault, for: Map do
    @spec to_default(any()) :: any()
    def to_default(map) when map == %{} do
      "'{}'"
    end

    @spec to_default(any()) :: any()
    def to_default(map) do
      # Convert map to JSON string for __database storage
      json_string = Jason.encode!(map)
      "'#{json_string}'"
    end
  end

  # Implementation for List types
  defimpl EctoMigrationDefault, for: List do
    @spec to_default(any()) :: any()
    def to_default([]) do
      "'[]'"
    end

    @spec to_default(any()) :: any()
    def to_default(list) when is_list(list) do
      # Handle list of atoms (common for notification channels)
      if Enum.all?(list, &is_atom/1) do
        atom_strings = Enum.map(list, &Atom.to_string/1)
        json_string = Jason.encode!(atom_strings)
        "'#{json_string}'"
      else
        # Handle regular lists
        json_string = Jason.encode!(list)
        "'#{json_string}'"
      end
    end
  end

  # Note: Atom implementation exists in ash_postgres, so we don't redefine it
  # The built - in implementation handles atoms correctly

  # Implementation for specific complex types that appear in our domains

  @doc """
  Notification preferences default structure
  """
  def notification_preferences_default do
    %{
      push: true,
      email: true,
      desktop: true,
      sms: false
    }
  end

  @doc """
  Operating hours default structure (Monday - Friday 9 - 5)
  """
  def operating_hours_default do
    %{
      "monday" => %{"open" => "09:00", "close" => "17:00"},
      "tuesday" => %{"open" => "09:00", "close" => "17:00"},
      "wednesday" => %{"open" => "09:00", "close" => "17:00"},
      "thursday" => %{"open" => "09:00", "close" => "17:00"},
      "friday" => %{"open" => "09:00", "close" => "17:00"},
      "saturday" => %{"closed" => true},
      "sunday" => %{"closed" => true}
    }
  end

  @doc """
  Dashboard settings default structure
  """
  def dashboard_settings_default do
    %{
      auto_refresh: true,
      grid: %{columns: 12, rows: 8},
      theme: "light"
    }
  end

  @doc """
  Risk matrix default structure
  """
  def risk_matrix_default do
    %{
      "low" => %{
        "action" => "Monitor",
        "color" => "#green",
        "range" => "1 - 4"
      },
      "medium" => %{
        "action" => "Manage",
        "color" => "#yellow",
        "range" => "5 - 12"
      },
      "high" => %{
        "action" => "Mitigate",
        "color" => "#orange",
        "range" => "13 - 20"
      },
      "critical" => %{
        "action" => "Immediate Action",
        "color" => "#red",
        "range" => "21 - 25"
      }
    }
  end

  @doc """
  Performance metrics default structure
  """
  def performance_metrics_default do
    %{
      cpu_usage_percent: 0,
      memory_usage_mb: 0,
      latency_ms: 0,
      bandwidth_usage_mbps: 0,
      dropped_frames: 0
    }
  end

  @doc """
  Retry configuration default structure
  """
  def retry_config_default do
    %{
      "max_retries" => 3,
      "retry_delay_seconds" => 60,
      "backoff_multiplier" => 2
    }
  end

  @doc """
  Notification channels default list
  """
  def notification_channels_default do
    [:email, :sms, :push, :in_app]
  end

  @doc """
  Video codecs default list
  """
  def video_codecs_default do
    [:h264]
  end

  @doc """
  Supported protocols default list
  """
  def supported_protocols_default do
    [:rtsp]
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
