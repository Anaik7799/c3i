defmodule Indrajaal.Errors.Conflict do
  @moduledoc """
  Resource conflict and concurrency errors.
  """
  defmodule ResourceConflict do
    @moduledoc false
    use Splode.Error,
      fields: [:resource, :id, :field, :conflicting_value, :existing_resource_id],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{resource: resource, field: field, conflictingvalue: value}) do
      "Conflict in #{resource}: #{field} '#{value}' already exists"
    end
  end

  defmodule ConcurrentModification do
    @moduledoc false
    use Splode.Error,
      fields: [:resource, :id, :expected_version, :actual_version, :operation],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{resource: resource, id: id, expectedversion: expected, actualversion: actual}) do
      "Concurrent modification of #{resource} #{id}: expected version #{expected}, actual version #{actual}"
    end
  end

  defmodule StateConflict do
    @moduledoc false
    use Splode.Error,
      fields: [:resource, :id, :current_state, :required_state, :operation],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{
          resource: resource,
          id: id,
          currentstate: current,
          required_state: required,
          operation: op
        }) do
      "State conflict for #{resource} #{id}: #{op} _requires state #{required}, but current state is #{current}"
    end
  end

  defmodule ScheduleConflict do
    @moduledoc false
    use Splode.Error,
      fields: [
        :resource_type,
        :resource_id,
        :conflicting_schedule,
        :existing_schedule_id,
        :time_overlap
      ],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{resourcetype: type, resource_id: id, time_overlap: overlap}) do
      "Schedule conflict for #{type} #{id}: overlapping time period #{overlap}"
    end
  end

  defmodule AssignmentConflict do
    @moduledoc false
    use Splode.Error,
      fields: [
        :assignee_id,
        :assignee_type,
        :resource_type,
        :resource_id,
        :existing_assignment_id
      ],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{
          assigneetype: type,
          assigneeid: assignee,
          resourcetype: resource,
          resourceid: resourceid
        }) do
      "Assignment conflict: #{type} #{assignee} already assigned to #{resource} #{resourceid}"
    end
  end

  defmodule LocationOccupied do
    @moduledoc false
    use Splode.Error,
      fields: [:location_id, :location_type, :occupying_resource, :occupying_resource_id],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{
          locationid: location,
          occupyingresource: resource,
          occupyingresource_id: resourceid
        }) do
      "Location #{location} occupied by #{resource} #{resourceid}"
    end
  end

  defmodule DeviceConflict do
    @moduledoc false
    use Splode.Error,
      fields: [:device_id, :operation, :conflicting_operation, :locked_by, :lock_expires_at],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{deviceid: device, operation: op, conflicting_operation: conflict}) do
      "Device #{device} conflict: cannot perform #{op} while #{conflict} is in progress"
    end
  end

  defmodule AlarmStateConflict do
    @moduledoc false
    use Splode.Error,
      fields: [
        :alarm_id,
        :current_state,
        :_requested_operation,
        :conflicting_actor,
        :locked_until
      ],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{alarmid: alarm, currentstate: state, _requested_operation: op}) do
      "Alarm #{alarm} state conflict: cannot perform #{op} in state #{state}"
    end
  end

  defmodule AccessLevelConflict do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :location_id, :_requested_level, :current_level, :upgraderequired],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{
          user_id: user,
          location_id: location,
          _requested_level: requested,
          current_level: current
        }) do
      "Access level conflict for user #{user} at location #{location}: _requested #{requested}, current #{current}"
    end
  end

  defmodule TenantResourceConflict do
    @moduledoc false
    use Splode.Error,
      fields: [:resource_type, :resource_identifier, :tenant_id, :conflicting_tenant_id],
      class: :conflict

    @spec message(map()) :: String.t()
    def message(%{
          resourcetype: type,
          resource_identifier: id,
          tenant_id: tenant,
          conflicting_tenant_id: conflict
        }) do
      "Tenant resource conflict: #{type} #{id} exists in tenant #{conflict}, cannot proceed in tenant #{tenant}"
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
