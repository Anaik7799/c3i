defmodule Indrajaal.Errors.NotFound do
  @moduledoc """
  Resource not found errors.
  """

  # Main NotFound error struct for generic not found errors
  defexception [:message, :resource, :id, :context, :details, :tenant_id]

  @impl true
  def exception(message) when is_binary(message) do
    %__MODULE__{
      message: message,
      resource: nil,
      id: nil,
      context: %{},
      details: %{},
      tenant_id: nil
    }
  end

  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "Resource not found")
    resource = Keyword.get(opts, :resource)
    id = Keyword.get(opts, :id)
    context = Keyword.get(opts, :context, %{})
    details = Keyword.get(opts, :details, %{})
    tenant_id = Keyword.get(opts, :tenant_id)

    %__MODULE__{
      message: message,
      resource: resource,
      id: id,
      context: context,
      details: details,
      tenant_id: tenant_id
    }
  end

  @impl true
  def message(%__MODULE__{message: nil}), do: "Resource not found"
  def message(%__MODULE__{message: message}), do: message

  defmodule ResourceNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:resource, :id, :search_criteria],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{resource: resource, id: id}) when not is_nil(id) do
      "#{resource} with id #{id} not found"
    end

    @spec message(map()) :: String.t()
    def message(%{resource: resource, searchcriteria: criteria}) do
      "#{resource} not found with criteria: #{inspect(criteria)}"
    end

    @spec message(map()) :: String.t()
    def message(%{resource: resource}) do
      "#{resource} not found"
    end
  end

  defmodule EndpointNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:_request_path, :method, :available_routes],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{_requestpath: path, method: method}) do
      "Endpoint not found: #{method} #{path}"
    end
  end

  defmodule FileNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:file_path, :operation, :expected_location],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{filepath: path, operation: operation}) do
      "File not found during #{operation}: #{path}"
    end
  end

  defmodule ConfigurationNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:config_key, :scope, :environment],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{configkey: key, scope: scope}) do
      "Configuration not found: #{key} in scope #{scope}"
    end
  end

  defmodule DeviceNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:device_id, :device_type, :location, :last_seen],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{deviceid: id, device_type: type}) do
      "Device not found: #{type} with id #{id}"
    end
  end

  defmodule UserNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:identifier, :identifier_type, :tenant_id],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{identifier: id, identifiertype: type}) do
      "User not found: #{type} #{id}"
    end
  end

  defmodule OrganizationNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:identifier, :identifier_type],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{identifier: id, identifiertype: type}) do
      "Organization not found: #{type} #{id}"
    end
  end

  defmodule LocationNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:location_id, :location_type, :site_id, :coordinates],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{locationid: id, locationtype: type}) do
      "Location not found: #{type} with id #{id}"
    end
  end

  defmodule AlarmNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:alarm_id, :incident_type, :device_id, :created_at_range],
      class: :not_found

    @spec message(any()) :: any()
    def message(%{alarmid: id}) do
      "Alarm not found with id #{id}"
    end
  end

  defmodule RecordingNotFound do
    @moduledoc false
    use Splode.Error,
      fields: [:recording_id, :camera_id, :time_range, :storage_location],
      class: :not_found

    @spec message(map()) :: String.t()
    def message(%{recordingid: id, cameraid: camera}) do
      "Recording #{id} not found for camera #{camera}"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
