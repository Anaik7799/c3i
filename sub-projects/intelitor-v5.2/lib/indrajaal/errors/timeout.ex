defmodule Indrajaal.Errors.Timeout do
  @moduledoc """
  Timeout - related errors.
  """
  defmodule OperationTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:operation, :timeout_ms, :elapsed_ms, :resource],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{operation: operation, timeoutms: timeout, elapsed_ms: elapsed}) do
      "Operation timeout: #{operation} took #{elapsed}ms, limit was #{timeout}ms"
    end
  end

  defmodule DatabaseTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:query, :timeout_ms, :table, :operation_type],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{operationtype: op, table: table, timeoutms: timeout}) do
      "Database timeout: #{op} on #{table} exceeded #{timeout}ms"
    end
  end

  defmodule ExternalServiceTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:service_name, :endpoint, :timeout_ms, :operation],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{service_name: service, endpoint: endpoint, timeout_ms: timeout}) do
      "External service timeout: #{service} at #{endpoint} exceeded #{timeout}ms"
    end
  end

  defmodule ResponseTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:alarm_id, :incident_type, :response_time_ms, :sla_timeout_ms],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{
          alarm_id: alarm,
          incident_type: type,
          response_time_ms: response,
          sla_timeout_ms: sla
        }) do
      "Response timeout for alarm #{alarm} (#{type}): #{response}ms exceeded SLA timeout of #{sla}ms"
    end
  end

  defmodule DeviceHeartbeatTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:device_id, :device_type, :last_heartbeat, :timeout_ms],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{
          device_id: device,
          device_type: type,
          last_heartbeat: last,
          timeout_ms: timeout
        }) do
      "Device heartbeat timeout: #{type} #{device} last seen #{last}, timeout #{timeout}ms"
    end
  end

  defmodule StreamTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:camera_id, :stream_type, :timeout_ms, :last_frame_time],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{cameraid: camera, streamtype: type, timeoutms: timeout}) do
      "Stream timeout: #{type} stream from camera #{camera} exceeded #{timeout}ms"
    end
  end

  defmodule ProcessingTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:job_id, :job_type, :processing_time_ms, :timeout_ms, :progress_percentage],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{jobid: job, job_type: type, processing_time_ms: time, timeout_ms: timeout}) do
      "Processing timeout: #{type} job #{job} took #{time}ms, limit was #{timeout}ms"
    end
  end

  defmodule LockTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:resource_type, :resource_id, :lock_type, :timeout_ms, :lock_holder],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{resourcetype: type, resourceid: id, locktype: lock, timeoutms: timeout}) do
      "Lock timeout: could not acquire #{lock} lock on #{type} #{id} within #{timeout}ms"
    end
  end

  defmodule UserActionTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:user_id, :action_type, :timeout_ms, :context],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{userid: user, action_type: action, timeout_ms: timeout}) do
      "User action timeout: #{action} by user #{user} exceeded #{timeout}ms"
    end
  end

  defmodule BackupTimeout do
    @moduledoc false
    use Splode.Error,
      fields: [:backup_id, :backup_type, :__data_size_bytes, :timeout_ms, :progress_bytes],
      class: :timeout

    @spec message(map()) :: String.t()
    def message(%{backupid: backup, backuptype: type, timeoutms: timeout}) do
      "Backup timeout: #{type} backup #{backup} exceeded #{timeout}ms"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cybernetic
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
