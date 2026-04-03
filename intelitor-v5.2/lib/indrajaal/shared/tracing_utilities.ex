defmodule Indrajaal.Shared.TracingUtilities do
  @moduledoc """
  Shared tracing utilities to eliminate code duplication between tracing
    modules.

  Extracted from Indrajaal.Changes.TraceOperation and Indrajaal.Tracing.ResourceHelpers
  following Toyota TPS principles to eliminate waste and maintain single
    source of truth.
  """

  require Logger

  @doc """
  Common telemetry emission for operations with standardized metrics.
  """
  @spec emit_operation_telemetry(term(), term(), term(), term()) :: term()
  def emit_operation_telemetry(operation_type, operation_name, metrics, context) do
    event_path = [:indrajaal, operation_type, String.to_atom(operation_name)]

    :telemetry.execute(event_path, metrics, context)
  end

  @doc """
  Extract device ID from changeset with fallback patterns.
  """
  @spec extract_device_id(any()) :: any()
  def extract_device_id(changeset) do
    changeset.data[:id] ||
      changeset.changes[:id] ||
      changeset.changes[:device_id] ||
      changeset.data[:device_id]
  end

  @doc """
  Extract alarm ID from changeset with fallback patterns.
  """
  @spec extract_alarm_id(any()) :: any()
  def extract_alarm_id(changeset) do
    changeset.data[:id] ||
      changeset.changes[:id] ||
      changeset.changes[:alarm_id] ||
      changeset.data[:alarm_id] ||
      Ash.UUID.generate()
  end

  @doc """
  Extract camera ID from changeset with fallback patterns.
  """
  @spec extract_camera_id(any()) :: any()
  def extract_camera_id(changeset) do
    changeset.data[:id] ||
      changeset.changes[:id] ||
      changeset.changes[:camera_id] ||
      changeset.data[:camera_id]
  end

  @doc """
  Extract actor ID from changeset context.
  """
  @spec extract_actor_id(any()) :: any()
  def extract_actor_id(changeset) do
    # Ash 3.x uses .context, not .__context
    case Map.get(changeset, :context, %{})[:actor] do
      %{id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Extract actor ID from context or actor struct.
  """
  def extract_actor_id_from_context(context_or_actor) do
    case context_or_actor do
      %{id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Build device __context from changeset for tracing.
  """
  @spec build_device_context(any()) :: any()
  def build_device_context(changeset) do
    %{
      device_type: changeset.changes[:device_type] || changeset.data[:device_type],
      location:
        changeset.changes[:location_id] || changeset.changes[:location] ||
          changeset.data[:location_id] || changeset.data[:location],
      status: changeset.changes[:status] || changeset.data[:status]
    }
  end

  @doc """
  Build alarm __context from changeset for tracing.
  """
  @spec build_alarm_context(any()) :: any()
  def build_alarm_context(changeset) do
    %{
      incident_type: changeset.changes[:incident_type] || changeset.data[:incident_type],
      priority: changeset.changes[:priority] || changeset.data[:priority],
      source: changeset.changes[:source_id] || changeset.data[:source_id]
    }
  end

  @doc """
  Build video __context from changeset for tracing.
  """
  @spec build_video_context(any()) :: any()
  def build_video_context(changeset) do
    %{
      stream_type: changeset.changes[:stream_type] || changeset.data[:stream_type],
      resolution: changeset.changes[:resolution] || changeset.data[:resolution],
      codec: changeset.changes[:codec] || changeset.data[:codec]
    }
  end

  @doc """
  Build business __context from changeset for tracing.
  """
  @spec build_business_context(term(), term(), term()) :: term()
  def build_business_context(changeset, operation_name, importance \\ :medium) do
    %{
      operation: operation_name,
      importance: importance,
      resource: changeset.resource,
      action: changeset.action.name,
      actor_id: extract_actor_id(changeset)
    }
  end

  @doc """
  Build security context from changeset and context for tracing.
  """
  @spec build_security_context(term(), term(), term(), term()) :: term()
  def build_security_context(changeset, context, operation_name, importance \\ :high) do
    actor = context[:actor]

    %{
      operation: operation_name,
      importance: importance,
      resource: changeset.resource,
      action: changeset.action.name,
      actor_id: Indrajaal.Tracing.extract_actor_id(actor),
      tenant_id: Indrajaal.Tracing.extract_tenant_id(actor),
      ip_address: context[:ip_address],
      user_agent: context[:user_agent],
      session_id: context[:session_id]
    }
  end

  @doc """
  Build authentication context from changeset and context for tracing.
  """
  @spec build_auth_context(term(), term(), term(), term()) :: term()
  def build_auth_context(changeset, context, operation_name, importance \\ :high) do
    actor = context[:actor]

    %{
      operation: operation_name,
      importance: importance,
      resource: changeset.resource,
      action: changeset.action.name,
      user_id: Indrajaal.Tracing.extract_actor_id(actor),
      tenant_id: Indrajaal.Tracing.extract_tenant_id(actor),
      email: changeset.changes[:email] || changeset.data[:email],
      ip_address: context[:ip_address],
      user_agent: context[:user_agent],
      session_id: context[:session_id],
      mfa_method: context[:mfa_method]
    }
  end

  @doc """
  Build audit context from changeset and context for tracing.
  """
  @spec build_audit_context(any(), any()) :: any()
  def build_audit_context(changeset, context) do
    actor = context[:actor]

    %{
      resource: Indrajaal.Tracing.extract_resource_name(changeset.resource),
      action: changeset.action.name,
      actor_id: Indrajaal.Tracing.extract_actor_id(actor),
      tenant_id: Indrajaal.Tracing.extract_tenant_id(actor),
      changes: changeset.changes,
      ip_address: context[:ip_address],
      user_agent: context[:user_agent],
      session_id: context[:session_id]
    }
  end

  # @doc """
  # Convert priority atom / string to numeric level for telemetry.
  # """
  # @spec priority_to_number(any()) :: any()
  # def priority_to_number(:low), do: 1
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number(:medium), do: 2
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number(:high), do: 3
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number(:critical), do: 4
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number("low"), do: 1
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number("medium"), do: 2
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number("high"), do: 3
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number("critical"), do: 4
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec priority_to_number(any()) :: any()
  # def priority_to_number(_), do: 2
  # Claude Agent: EP-076 - Unreachable function clause commented
  # @doc """
  # Convert importance atom to numeric level for telemetry.
  # """
  # @spec importance_to_number(any()) :: any()
  # Worker-5: EP-076 - Duplicate @doc attributes commented out - function implementation below is also commented
  # def importance_to_number(:low), do: 1
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec importance_to_number(any()) :: any()
  # def importance_to_number(:medium), do: 2
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec importance_to_number(any()) :: any()
  # def importance_to_number(:high), do: 3
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec importance_to_number(any()) :: any()
  # def importance_to_number(:critical), do: 4
  # Claude Agent: EP-076 - Unreachable function clause commented  @spec importance_to_number(any()) :: any()
  # def importance_to_number(_), do: 2
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Trace device operation with standardized telemetry emission.
  """
  @spec trace_device_operation_with_telemetry(term(), term(), term()) :: term()
  def trace_device_operation_with_telemetry(changeset, operation_name, trace_fn) do
    device_id = extract_device_id(changeset)
    device_context = build_device_context(changeset)

    trace_fn.(device_id, operation_name, device_context, fn ->
      # Emit standardized device telemetry
      emit_operation_telemetry(
        :device,
        operation_name,
        %{count: 1},
        Map.merge(device_context, %{device_id: device_id})
      )

      changeset
    end)
  end

  @doc """
  Trace alarm operation with standardized telemetry emission.
  """
  @spec trace_alarm_operation_with_telemetry(term(), term(), term()) :: term()
  def trace_alarm_operation_with_telemetry(changeset, operation_name, trace_fn) do
    alarm_id = extract_alarm_id(changeset)
    alarm_context = build_alarm_context(changeset)

    trace_fn.(alarm_id, operation_name, alarm_context, fn ->
      # Emit standardized alarm telemetry
      emit_operation_telemetry(
        :alarm,
        operation_name,
        %{count: 1, priority_level: priority_to_number(alarm_context[:priority])},
        Map.merge(alarm_context, %{alarm_id: alarm_id})
      )

      changeset
    end)
  end

  @doc """
  Trace video operation with standardized telemetry emission.
  """
  @spec trace_video_operation_with_telemetry(term(), term(), term()) :: term()
  def trace_video_operation_with_telemetry(changeset, operation_name, trace_fn) do
    camera_id = extract_camera_id(changeset)
    video_context = build_video_context(changeset)

    trace_fn.(camera_id, operation_name, video_context, fn ->
      # Emit standardized video telemetry
      emit_operation_telemetry(
        :video,
        operation_name,
        %{count: 1},
        Map.merge(video_context, %{camera_id: camera_id})
      )

      changeset
    end)
  end

  @doc """
  Trace business critical operation with standardized telemetry emission.
  """
  @spec trace_business_critical_with_telemetry(term(), term(), term(), term()) :: term()
  def trace_business_critical_with_telemetry(changeset, operation_name, importance, trace_fn) do
    business_context = build_business_context(changeset, operation_name, importance)

    trace_fn.("critical.#{operation_name}", business_context, fn ->
      # Emit standardized business critical telemetry
      emit_operation_telemetry(
        :business,
        :critical,
        %{count: 1, importance_level: importance_to_number(importance)},
        business_context
      )

      changeset
    end)
  end

  @doc """
  Extract resource ID from changeset with fallback patterns.
  """
  @spec extract_resource_id(any()) :: any()
  def extract_resource_id(changeset) do
    changeset.data[:id] || changeset.changes[:id]
  end

  @doc """
  Extract result ID from operation result.
  """
  @spec extract_result_id(any()) :: any()
  def extract_result_id(%{id: id}), do: id
  def extract_result_id(_), do: nil

  @doc """
  Convert priority atom to numeric value for telemetry.
  """
  @spec priority_to_number(atom() | binary() | nil) :: integer()
  def priority_to_number(:critical), do: 4
  def priority_to_number(:high), do: 3
  def priority_to_number(:medium), do: 2
  def priority_to_number(:low), do: 1
  def priority_to_number("critical"), do: 4
  def priority_to_number("high"), do: 3
  def priority_to_number("medium"), do: 2
  def priority_to_number("low"), do: 1
  # Default to medium
  def priority_to_number(_), do: 2

  @doc """
  Convert importance atom to numeric value for telemetry.
  """
  @spec importance_to_number(atom() | binary() | nil) :: integer()
  def importance_to_number(:critical), do: 4
  def importance_to_number(:high), do: 3
  def importance_to_number(:medium), do: 2
  def importance_to_number(:low), do: 1
  def importance_to_number("critical"), do: 4
  def importance_to_number("high"), do: 3
  def importance_to_number("medium"), do: 2
  def importance_to_number("low"), do: 1
  # Default to medium
  def importance_to_number(_), do: 2
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
