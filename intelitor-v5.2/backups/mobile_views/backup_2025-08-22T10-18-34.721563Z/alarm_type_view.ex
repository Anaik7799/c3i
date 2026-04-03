defmodule IntelitorWeb.Api.Mobile.Config.AlarmTypeView do
  @moduledoc """
  JSON rendering for alarm types in the Mobile API.

  Provides consistent JSON responses with proper metadata,
  pagination support, and API versioning.

  SOPv5.1 Compliance: ✅
  Timestamp: 2025-08-03T22:37:39+02:00
  """

  use IntelitorWeb, :view

  # alias Intelitor.Alarms.AlarmType

  @api_version "v1"

  @spec render(any(), any()) :: any()
  def render("index.json", %{
        alarm_types: alarm_types,
        total: total,
        page: page,
        page_size: page_size
      }) do
    %{
      status: "success",
      data: %{
        alarm_types: render_many(alarm_types, __MODULE__, "alarm_type.json"),
        total: total,
        page: page,
        page_size: page_size,
        total_pages: ceil(total / page_size)
      },
      metadata: render_metadata()
    }
  end

  @spec render(any(), any()) :: any()
  def render("show.json", %{alarm_type: alarm_type}) do
    %{
      status: "success",
      data: %{
        alarm_type: render_one(alarm_type, __MODULE__, "alarm_type.json")
      },
      metadata: render_metadata()
    }
  end

  @spec render(any(), any()) :: any()
  def render("alarm_type.json", %{alarm_type: alarm_type}) do
    %{
      id: alarm_type.id,
      name: alarm_type.name,
      code: alarm_type.code,
      severity: alarm_type.severity,
      category: alarm_type.category,
      description: alarm_type.description,
      default_threshold: alarm_type.default_threshold,
      escalation_time: alarm_type.escalation_time,
      auto_acknowledge: alarm_type.auto_acknowledge,
      metadata: alarm_type.metadata || %{},
      active: alarm_type.active,
      created_at: DateTime.to_iso8601(alarm_type.inserted_at),
      updated_at: DateTime.to_iso8601(alarm_type.updated_at)
    }
  end

  @spec render(any(), any()) :: any()
  def render("error.json", %{changeset: changeset}) do
    %{
      status: "error",
      errors: render_changeset_errors(changeset),
      metadata: render_metadata()
    }
  end

  @spec render_metadata() :: any()
  defp render_metadata do
    %{
      api_version: @api_version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @spec render_changeset_errors(term()) :: term()
  defp render_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
