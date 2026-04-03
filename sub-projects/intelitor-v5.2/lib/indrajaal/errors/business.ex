defmodule Indrajaal.Errors.Business do
  @moduledoc """
  Business logic and domain - specific errors.
  """

  # Main Business error struct for generic business errors
  defexception [:message, :code, :context, :details]

  @impl true
  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, code: nil, context: %{}, details: %{}}
  end

  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "A business logic error occurred")
    code = Keyword.get(opts, :code)
    context = Keyword.get(opts, :context, %{})
    details = Keyword.get(opts, :details, %{})
    %__MODULE__{message: message, code: code, context: context, details: details}
  end

  @impl true
  def message(%__MODULE__{message: nil}), do: "A business logic error occurred"
  def message(%__MODULE__{message: message}), do: message

  # Device - related errors
  defmodule DeviceOffline do
    @moduledoc false
    use Splode.Error,
      fields: [:device_id, :device_name, :last_heartbeat, :expected_interval],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{devicename: name, lastheartbeat: last_heartbeat}) do
      "Device '#{name}' is offline (last heartbeat: #{last_heartbeat})"
    end
  end

  defmodule DeviceMaintenanceRequired do
    @moduledoc false
    use Splode.Error,
      fields: [:device_id, :maintenance_type, :last_service_date, :next_due_date],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{deviceid: id, maintenance_type: type}) do
      "Device #{id} _requires #{type} maintenance"
    end
  end

  # Alarm - related errors
  defmodule AlarmStateTransitionInvalid do
    @moduledoc false
    use Splode.Error,
      fields: [:alarm_id, :current_state, :_requested_state, :valid_transitions],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{alarmid: id, currentstate: current, _requested_state: requested}) do
      "Invalid alarm state transition for alarm #{id}: cannot transition from #{current} to #{requested}"
    end
  end

  defmodule AlarmResolutionTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:alarm_id, :incident_type, :elapsed_time, :sla_timeout],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{alarmid: id, incidenttype: type, elapsedtime: elapsed, slatimeout: sla}) do
      "Alarm #{id} (#{type}) has exceeded SLA timeout: #{elapsed}ms > #{sla}ms"
    end
  end

  # Access Control errors
  defmodule AccessScheduleViolation do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :location_id, :attempted_time, :allowed_schedule],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{userid: user_id, location_id: location, attempted_time: time}) do
      "Access attempt by user #{user_id} to location #{location} at #{time} violates schedule"
    end
  end

  defmodule DuplicateAccessAttempt do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :location_id, :previous_attempt_time, :anti_passback_rule],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{userid: userid, locationid: location}) do
      "Duplicate access attempt by user #{userid} at location #{location} violates anti - passback rule"
    end
  end

  # Video - related errors
  defmodule RecordingStorageFull do
    @moduledoc false
    use Splode.Error,
      fields: [:camera_id, :storage_used, :storage_limit, :retention_policy],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{cameraid: id, storageused: used, storagelimit: limit}) do
      "Recording storage full for camera #{id}: #{used}/#{limit} bytes used"
    end
  end

  defmodule StreamUnavailable do
    @moduledoc false
    use Splode.Error,
      fields: [:camera_id, :stream_type, :reason, :last_available],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{cameraid: id, streamtype: type, reason: reason}) do
      "Stream #{type} unavailable for camera #{id}: #{reason}"
    end
  end

  # Billing - related errors
  defmodule SubscriptionExpired do
    @moduledoc false
    use Splode.Error,
      fields: [:subscription_id, :organization_id, :expired_date, :grace_period],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{subscriptionid: id, expireddate: date}) do
      "Subscription #{id} expired on #{date}"
    end
  end

  defmodule UsageLimitExceeded do
    @moduledoc false
    use Splode.Error,
      fields: [:organization_id, :resource_type, :current_usage, :limit, :billing_period],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{resourcetype: type, currentusage: usage, limit: limit}) do
      "Usage limit exceeded for #{type}: #{usage}/#{limit}"
    end
  end

  # Compliance errors
  defmodule ComplianceViolation do
    @moduledoc false
    use Splode.Error,
      fields: [:framework, :_requirement_id, :violation_type, :resource, :severity],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{framework: framework, _requirementid: req, violationtype: type}) do
      "Compliance violation in #{framework} _requirement #{req}: #{type}"
    end
  end

  # Guard tour errors
  defmodule CheckpointMissed do
    @moduledoc false
    use Splode.Error,
      fields: [:tour_id, :checkpoint_id, :guard_id, :scheduled_time, :missed_duration],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{tourid: tour, checkpoint_id: checkpoint, guard_id: guard}) do
      "Checkpoint #{checkpoint} missed by guard #{guard} during tour #{tour}"
    end
  end

  defmodule TourRouteDeviation do
    @moduledoc false
    use Splode.Error,
      fields: [:tour_id, :guard_id, :expected_checkpoint, :actual_checkpoint, :deviation_distance],
      class: :business

    @spec message(map()) :: String.t()
    def message(%{
          tour_id: tour,
          guard_id: guard,
          expected_checkpoint: expected,
          actual_checkpoint: actual
        }) do
      "Tour route deviation in tour #{tour} by guard #{guard}: expected #{expected}, actual #{actual}"
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
